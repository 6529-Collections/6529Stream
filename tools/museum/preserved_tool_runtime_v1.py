"""Explicit local CPython 3.13 Windows runtime recipe; no fetch or execution.

The recipe pins observed installation bytes, not their publisher's identity.
Windows and its system DLLs remain external prerequisites. Only named CPython
and Museum distributions are read; unrelated base site-packages are excluded.
"""
from __future__ import annotations

import base64
import csv
from email.parser import BytesParser
import hashlib
import importlib.metadata
import io
import json
import os
from pathlib import Path
import struct
import tempfile

from tools.preservation.reference_package import canonical, safe_name, sha

PROFILE = 'STREAM_PRESERVED_TOOL_RUNTIME_V1'
PYTHON_VERSION = '3.13.13'
PYTHON_BUILD = 'h39c999c_100_cp313'
MAX_FILES = 4096
MAX_BYTES = 128 * 1024 * 1024
MAX_FILE = 32 * 1024 * 1024
MAX_RECIPE = 2 * 1024 * 1024
PTH = b'.\nLib\nDLLs\nLib/site-packages\n../source\n'
DISTRIBUTIONS = {
    'attrs': '26.1.0', 'blake3': '1.0.9', 'cachetools': '7.1.8',
    'frozendict': '2.4.7', 'jsonschema': '4.25.1',
    'jsonschema-specifications': '2025.9.1', 'lxml': '6.1.3',
    'pycryptodome': '3.23.0', 'pyld': '3.3.0', 'referencing': '0.37.0',
    'rfc3339-validator': '0.1.4', 'rfc3986-validator': '0.1.1',
    'rfc8785': '0.1.4', 'rpds-py': '2026.6.3', 'six': '1.17.0',
    'typing-extensions': '4.16.0',
}
SYSTEM_DLLS = frozenset(('advapi32.dll','bcrypt.dll','bcryptprimitives.dll','crypt32.dll','gdi32.dll',
    'iphlpapi.dll','kernel32.dll','msvcrt.dll','ntdll.dll','ole32.dll',
    'oleaut32.dll','propsys.dll','rpcrt4.dll','secur32.dll','shell32.dll',
    'shlwapi.dll','user32.dll','userenv.dll','ucrtbase.dll','version.dll',
    'winmm.dll','ws2_32.dll','wtsapi32.dll'))
QUALIFICATION = {
    'localInstalledBytesPinned': True, 'nativeImportClosureChecked': True,
    'publisherAuthenticationProven': False, 'signedDistributionVerified': False,
    'redistributionPermissionEstablished': False,
    'operatingSystemIncluded': False, 'allPythonApplicationsSupported': False,
    'archivedCodeExecuted': False, 'networkUsed': False,
    'limits': 'Windows x86_64 with API-set/UCRT/system DLL prerequisites; GUI, test, pip and virtual-environment creation tooling excluded. Static PE imports do not prove all dynamically requested libraries or OS behavior. Replay execution requires separately recorded evidence.',
}


def _require(ok, message):
    if not ok: raise ValueError(message)


def _hash(value):
    _require(type(value) is str and len(value) == 64
        and all(c in '0123456789abcdef' for c in value), 'runtime SHA256 syntax')


def _closed(value, keys, message):
    _require(type(value) is dict and set(value) == set(keys.split()), message)


def _no_links(path):
    path = Path(path).absolute()
    for p in (path, *path.parents):
        _require(not p.is_symlink() and not p.is_junction(), 'runtime path traverses link or junction')
    return path


def _read(path, maximum=MAX_FILE):
    path = _no_links(path)
    _require(path.is_file() and path.stat().st_size <= maximum, 'runtime source file/bound')
    raw = path.read_bytes()
    _require(len(raw) <= maximum, 'runtime source grew beyond bound')
    return raw


def _system(name):
    return name in SYSTEM_DLLS or (name.startswith(('api-ms-win-', 'ext-ms-win-')) and name.endswith('.dll'))


def pe_imports(raw):
    """Read ordinary and RVA-based delayed PE64 imports without loading a DLL."""
    _require(type(raw) is bytes and 64 <= len(raw) <= MAX_FILE and raw[:2] == b'MZ', 'runtime PE header')
    try:
        pe, = struct.unpack_from('<I', raw, 60)
        _require(raw[pe:pe+4] == b'PE\0\0', 'runtime PE signature')
        machine, count = struct.unpack_from('<HH', raw, pe+4)
        size, = struct.unpack_from('<H', raw, pe+20)
        opt = pe+24
        _require(machine == 0x8664 and 1 <= count <= 96 and size >= 240
            and struct.unpack_from('<I', raw, opt+108)[0] >= 14
            and struct.unpack_from('<H', raw, opt)[0] == 0x20b, 'runtime PE x86_64 required')
        sections = [struct.unpack_from('<IIII', raw, opt+size+i*40+8) for i in range(count)]
        def offset(rva, length=1):
            for virtual_size, virtual, width, start in sections:
                if virtual <= rva < virtual+max(virtual_size, width):
                    at = start+rva-virtual
                    _require(rva-virtual+length <= width and at+length <= len(raw), 'runtime PE RVA bound')
                    return at
            raise ValueError('runtime PE unmapped RVA')
        def name(rva):
            at = offset(rva); end = raw.find(b'\0', at, min(at+256, len(raw)))
            _require(end > at, 'runtime PE import name bound')
            value = raw[at:end].decode('ascii').lower()
            _require(safe_name(value) == value and '/' not in value and value.endswith('.dll'), 'runtime PE import name')
            return value
        result = set()
        for index, words, name_index in ((1,5,3),(13,8,1)):
            rva, width = struct.unpack_from('<II', raw, opt+112+8*index)
            if not rva:
                _require(width == 0, 'runtime PE empty import directory'); continue
            _require(width >= words*4, 'runtime PE import directory bound')
            at = offset(rva, width)
            for i in range(min(1024,width//(words*4))):
                values = struct.unpack_from('<'+'I'*words, raw, at+i*words*4)
                if not any(values): break
                if index == 13: _require(values[0] == 1, 'runtime PE delay imports require RVA form')
                result.add(name(values[name_index]))
            else: raise ValueError('runtime PE import count bound')
        return sorted(result)
    except (struct.error, UnicodeError, IndexError) as exc:
        raise ValueError('runtime malformed PE imports') from exc


def _normal(name): return name.lower().replace('_','-').replace('.','-')


def _python_file(name):
    if name in ('python.exe','python3.dll','python313.dll','LICENSE_PYTHON.txt'): return True
    if name.startswith('Lib/'):
        parts = name.split('/')
        return parts[1] not in ('site-packages','test','tkinter','turtledemo','idlelib','ensurepip','venv') \
            and '__pycache__' not in parts and not name.endswith('.pyc') and name != 'Lib/turtle.py'
    return name.startswith('DLLs/') and name.endswith('.pyd') and not Path(name).name.startswith(('_test','_ctypes_test','xx','_tkinter'))


def plan(base_prefix, site_packages):
    """Observe only explicit installed runtime/distribution roots; return pinned recipe bytes."""
    base, site = (_no_links(p).resolve(strict=True) for p in (base_prefix,site_packages))
    _require(base.is_dir() and site.is_dir() and base != site, 'runtime explicit source directories')
    conda_path = base/'conda-meta'/f'python-{PYTHON_VERSION}-{PYTHON_BUILD}.json'
    conda_raw = _read(conda_path, MAX_RECIPE); package = json.loads(conda_raw)
    _require(package['name'] == 'python' and package['version'] == PYTHON_VERSION
        and package['build'] == PYTHON_BUILD, 'runtime exact CPython package')
    rows, raw_by_target, source_packages = {}, {}, []
    def add(target, root, relative, category, raw=None):
        safe_name(target)
        if raw is None:
            safe_name(relative); raw = _read((base if root == 'base' else site)/relative)
        _require(len(raw) <= MAX_FILE, 'runtime file size bound')
        row = {'path':target,'sourceRoot':root,'sourcePath':relative,'bytes':len(raw),'sha256':sha(raw),
            'generated':raw.hex() if root is None else None,'category':category}
        alias = target.casefold()
        _require(alias not in rows or rows[alias] == row, 'runtime duplicate or case alias')
        rows[alias] = row; raw_by_target[target] = raw
        _require(len(rows) <= MAX_FILES and sum(r['bytes'] for r in rows.values()) <= MAX_BYTES, 'runtime aggregate bound')
    for name in package['files']:
        name = name.replace('\\','/')
        if _python_file(name): add(name,'base',name,'python')
    _require('python313.dll' in pe_imports(raw_by_target['python.exe']), 'runtime entrypoint is not standalone CPython')
    add('python313._pth',None,None,'path_configuration',PTH)
    # Retain original package metadata/licenses as provenance, not authentication.
    def retain_package(value, path):
        add('provenance/conda/'+path.name,'base',path.relative_to(base).as_posix(),'package_metadata')
        entry = {k:value[k] for k in ('name','version','build','url','sha256')}
        entry.update(license=value.get('license'),licenseFamily=value.get('license_family'),licenseFiles=[])
        archive_name = '-'.join(str(value[k]) for k in ('name','version','build'))
        safe_name(archive_name)
        license_root = _no_links(base/'pkgs'/archive_name/'info/licenses')
        if license_root.is_dir():
            for license_path in sorted(license_root.rglob('*')):
                _no_links(license_path)
                if not license_path.is_file(): continue
                target = 'provenance/licenses/'+archive_name+'/'+license_path.relative_to(license_root).as_posix()
                add(target,'base',license_path.relative_to(base).as_posix(),'package_license'); entry['licenseFiles'].append(target)
        entry['licenseFilesAvailable'] = bool(entry['licenseFiles'])
        source_packages.append(entry)
    retain_package(package,conda_path)
    seen, distributions = set(), []
    for distribution in importlib.metadata.distributions(path=[str(site)]):
        normalized = _normal(distribution.metadata['Name'])
        if normalized not in DISTRIBUTIONS: continue
        _require(normalized not in seen and distribution.version == DISTRIBUTIONS[normalized], 'runtime distribution version/duplicate')
        seen.add(normalized); record_raw = distribution.read_text('RECORD')
        _require(record_raw is not None, 'runtime installed RECORD missing')
        files, licenses = [], []
        for relative, digest, length in csv.reader(io.StringIO(record_raw)):
            if relative.startswith('../'):
                _require(relative.startswith('../../Scripts/'), 'runtime unexpected distribution external path'); continue
            safe_name(relative)
            if '__pycache__' in relative.split('/') or relative.endswith('.pyc'): continue
            raw = _read(site/relative)
            if digest:
                _require(digest.startswith('sha256=') and digest[7:] == base64.urlsafe_b64encode(hashlib.sha256(raw).digest()).decode().rstrip('='), 'runtime distribution RECORD hash differs')
                _require(length.isdecimal() and int(length) == len(raw), 'runtime distribution RECORD size differs')
            else: _require(relative.endswith('.dist-info/RECORD') and not length, 'runtime unhashed distribution member')
            target = 'Lib/site-packages/'+relative
            add(target,'site',relative,'distribution'); files.append(target)
            if any(word in Path(relative).name.lower() for word in ('license','copying','notice')): licenses.append(target)
        _require(files and licenses, 'runtime distribution files/license provenance missing')
        distributions.append({'name':normalized,'version':distribution.version,'files':sorted(files),'licenses':sorted(licenses),
            'licenseExpression':distribution.metadata.get('License-Expression'), 'license':distribution.metadata.get('License')})
    _require(seen == set(DISTRIBUTIONS), 'runtime complete pinned dependency set missing')
    external = set(); queue = [p for p in raw_by_target if p.lower().endswith(('.exe','.dll','.pyd'))]; checked = set()
    native_sources = set()
    while queue:
        target = queue.pop()
        if target in checked: continue
        checked.add(target)
        for name in pe_imports(raw_by_target[target]):
            if _system(name): external.add(name); continue
            existing = [p for p in raw_by_target if '/' not in p and p.lower() == name]
            if existing: queue.extend(existing); continue
            candidates = [directory/name for directory in (base,base/'DLLs',base/'Library/bin') if (directory/name).is_file()]
            _require(candidates, 'runtime unresolved native import '+name)
            data = [_read(p) for p in candidates]
            _require(all(raw == data[0] for raw in data), 'runtime ambiguous native dependency '+name)
            relative = candidates[0].relative_to(base).as_posix(); native_sources.add(relative)
            add(name,'base',relative,'native_dependency'); queue.append(name)
    # Collect only package manifests that own the named DLLs, and their license files.
    for path in sorted((base/'conda-meta').glob('*.json')):
        raw = _read(path,MAX_RECIPE); value = json.loads(raw)
        owned = {p.replace('\\','/').lower():p.replace('\\','/') for p in value.get('files',[])}
        if not any(p.lower() in owned for p in native_sources): continue
        retain_package(value,path)
    value = {'profile':PROFILE,'pythonVersion':PYTHON_VERSION,'architecture':'AMD64','platform':'Windows',
        'entrypoint':'python.exe','pathConfiguration':'python313._pth','sourceRoots':{'base':str(base),'site':str(site)},
        'distributions':sorted(distributions,key=lambda d:d['name']),'sourcePackages':sorted(source_packages,key=lambda d:d['name']),
        'files':sorted(rows.values(),key=lambda r:r['path']),'externalLibraries':sorted(external),'qualification':QUALIFICATION}
    raw = canonical(value); _recipe(raw,sha(raw)); return raw


def _recipe(raw, expected_sha256):
    _hash(expected_sha256)
    _require(type(raw) is bytes and len(raw) <= MAX_RECIPE and sha(raw) == expected_sha256, 'runtime external recipe pin differs')
    value = json.loads(raw)
    _require(canonical(value) == raw, 'runtime recipe canonical bytes')
    _closed(value,'profile pythonVersion architecture platform entrypoint pathConfiguration sourceRoots distributions sourcePackages files externalLibraries qualification','runtime recipe keys')
    _require(value['profile'] == PROFILE and value['pythonVersion'] == PYTHON_VERSION and value['architecture'] == 'AMD64'
        and value['platform'] == 'Windows' and value['entrypoint'] == 'python.exe' and value['pathConfiguration'] == 'python313._pth'
        and value['qualification'] == QUALIFICATION,'runtime profile/entrypoint/qualification')
    _closed(value['sourceRoots'],'base site','runtime source roots')
    _require(all(type(p) is str and Path(p).is_absolute() for p in value['sourceRoots'].values()), 'runtime absolute source roots')
    files = value['files']; _require(type(files) is list and 1 <= len(files) <= MAX_FILES, 'runtime file count bound')
    names, total = [], 0
    for row in files:
        _closed(row,'path sourceRoot sourcePath bytes sha256 generated category','runtime file row')
        names.append(safe_name(row['path'])); _hash(row['sha256'])
        _require(not (row['path'].lower().endswith('._pth') and row['path'] != 'python313._pth')
            and row['path'].lower() != 'pyvenv.cfg', 'runtime alternate Python path configuration forbidden')
        _require(type(row['bytes']) is int and 0 <= row['bytes'] <= MAX_FILE, 'runtime member bound'); total += row['bytes']
        if row['path'] == 'python313._pth' or row['sourceRoot'] is None:
            _require(row['path'] == 'python313._pth' and row['sourcePath'] is None and row['category'] == 'path_configuration'
                and row['sourceRoot'] is None
                and row['generated'] == PTH.hex() and row['sha256'] == sha(PTH) and row['bytes'] == len(PTH),'runtime isolated path configuration')
        else:
            _require(row['sourceRoot'] in ('base','site') and row['generated'] is None
                and row['category'] in ('python','distribution','native_dependency','package_metadata','package_license'),'runtime source row')
            safe_name(row['sourcePath'])
    _require(total <= MAX_BYTES and names == sorted(names) and len({n.casefold() for n in names}) == len(names), 'runtime total/order/aliases')
    _require({'python.exe','python313.dll','python3.dll','python313._pth','Lib/encodings/__init__.py','Lib/importlib/__init__.py','LICENSE_PYTHON.txt'} <= set(names),'runtime essential files absent')
    _require(type(value['distributions']) is list and {d['name']:d['version'] for d in value['distributions']} == DISTRIBUTIONS
        and len(value['distributions']) == len(DISTRIBUTIONS),'runtime pinned distribution denominator')
    distribution_files = set()
    for d in value['distributions']:
        _closed(d,'name version files licenses licenseExpression license','runtime distribution row')
        _require(type(d['files']) is list and d['files'] == sorted(set(d['files'])) and d['licenses']
            and set(d['licenses']) <= set(d['files']) <= set(names),'runtime distribution file/license inventory')
        _require(not distribution_files.intersection(d['files']), 'runtime overlapping distributions'); distribution_files.update(d['files'])
    _require(distribution_files == {r['path'] for r in files if r['category']=='distribution'}, 'runtime distribution inventory mismatch')
    _require(type(value['sourcePackages']) is list and 1 <= len(value['sourcePackages']) <= 64, 'runtime source package bound')
    package_names = []
    for p in value['sourcePackages']:
        _closed(p,'name version build url sha256 license licenseFamily licenseFiles licenseFilesAvailable','runtime source package row')
        _require(all(type(p[k]) is str and p[k] for k in ('name','version','build','url')), 'runtime package identity')
        _hash(p['sha256']); package_names.append(p['name'])
        _require(type(p['licenseFiles']) is list and p['licenseFiles'] == sorted(set(p['licenseFiles']))
            and set(p['licenseFiles']) <= set(names) and type(p['licenseFilesAvailable']) is bool
            and p['licenseFilesAvailable'] == bool(p['licenseFiles']), 'runtime package license inventory')
    _require(package_names == sorted(set(package_names)), 'runtime source package order/duplicates')
    _require(value['externalLibraries'] == sorted(set(value['externalLibraries'])) and all(_system(n) for n in value['externalLibraries']), 'runtime external Windows prerequisites')
    return value


def _report(value, digest):
    return {'profile':PROFILE,'recipeSha256':digest,'entrypoint':'python.exe','pythonVersion':PYTHON_VERSION,
        'fileCount':len(value['files']),'bytes':sum(r['bytes'] for r in value['files']),
        'externalLibraries':value['externalLibraries'],'distributions':{d['name']:d['version'] for d in value['distributions']},
        'qualification':dict(QUALIFICATION)}


def _closure(raw_files, external):
    observed = set()
    for path, raw in raw_files.items():
        if not path.lower().endswith(('.exe','.pyd','.dll')): continue
        imports = pe_imports(raw)
        if path == 'python.exe': _require('python313.dll' in imports, 'runtime venv launcher forbidden')
        for name in imports:
            if _system(name): observed.add(name)
            else: _require(any('/' not in p and p.lower()==name for p in raw_files), 'runtime native dependency absent '+name)
    _require(sorted(observed) == external, 'runtime external prerequisite inventory differs')


def _distribution_closure(raw_files, distributions):
    """The unchanged installed RECORD, not caller row lists, defines each package."""
    for d in distributions:
        records = [p for p in d['files'] if p.endswith('.dist-info/RECORD')]
        _require(len(records) == 1, 'runtime distribution original RECORD denominator')
        parent = records[0].removesuffix('RECORD'); metadata = parent+'METADATA'
        _require(metadata in d['files'], 'runtime distribution METADATA missing')
        fields = BytesParser().parsebytes(raw_files[metadata])
        _require(_normal(fields['Name']) == d['name'] and fields['Version'] == d['version']
            and fields.get('License-Expression') == d['licenseExpression'] and fields.get('License') == d['license'],
            'runtime distribution original metadata differs')
        expected, licenses = set(), []
        for relative,digest,length in csv.reader(io.StringIO(raw_files[records[0]].decode('utf-8'))):
            if relative.startswith('../'):
                _require(relative.startswith('../../Scripts/'), 'runtime distribution external RECORD member'); continue
            safe_name(relative)
            if '__pycache__' in relative.split('/') or relative.endswith('.pyc'): continue
            path = 'Lib/site-packages/'+relative
            _require(path not in expected and path in raw_files, 'runtime distribution retained RECORD member missing/duplicate')
            expected.add(path); raw = raw_files[path]
            if digest:
                _require(digest.startswith('sha256=') and digest[7:] == base64.urlsafe_b64encode(hashlib.sha256(raw).digest()).decode().rstrip('=')
                    and length.isdecimal() and int(length) == len(raw), 'runtime distribution retained RECORD byte pin')
            else: _require(path == records[0] and not length, 'runtime distribution unexpected unhashed file')
            if any(word in Path(relative).name.lower() for word in ('license','copying','notice')): licenses.append(path)
        _require(expected == set(d['files']) and sorted(licenses) == d['licenses'], 'runtime distribution exact original RECORD inventory')


def _python_closure(raw_files, value):
    path = 'provenance/conda/'+f'python-{PYTHON_VERSION}-{PYTHON_BUILD}.json'
    _require(path in raw_files, 'runtime original CPython manifest missing')
    package = json.loads(raw_files[path])
    _require(package['name'] == 'python' and package['version'] == PYTHON_VERSION
        and package['build'] == PYTHON_BUILD, 'runtime retained CPython identity')
    expected = {p.replace('\\','/') for p in package['files'] if _python_file(p.replace('\\','/'))}
    actual = {r['path'] for r in value['files'] if r['category']=='python'}
    _require(expected == actual and all(r['sourceRoot']=='base' and r['sourcePath']==r['path']
        for r in value['files'] if r['category']=='python'), 'runtime original CPython file denominator differs')


def validate_tree(output, recipe_raw, expected_sha256):
    """Check exact restored bytes and native import closure; never execute them."""
    value = _recipe(recipe_raw,expected_sha256); root = _no_links(output)
    _require(root.is_dir(), 'runtime tree missing')
    expected = {r['path']:r for r in value['files']}; retained = {}; count = 0
    for path in root.rglob('*'):
        _no_links(path)
        if path.is_dir(): continue
        count += 1; _require(count <= MAX_FILES, 'runtime tree file bound')
        name = safe_name(path.relative_to(root).as_posix()); _require(name in expected, 'runtime unexpected tree member')
        row = expected[name]; raw = _read(path)
        _require((len(raw),sha(raw)) == (row['bytes'],row['sha256']), 'runtime tree byte pin differs')
        retained[name] = raw
    _require(set(retained)==set(expected), 'runtime tree file missing')
    _closure(retained,value['externalLibraries'])
    _distribution_closure(retained,value['distributions'])
    _python_closure(retained,value)
    return _report(value,expected_sha256)


def materialize(recipe_raw, expected_sha256, output):
    """Copy explicit pinned source files to a new tree by atomic no-replace rename."""
    value = _recipe(recipe_raw,expected_sha256); root = _no_links(output)
    _require(not root.exists() and root.parent.is_dir(), 'runtime output must be new with existing parent')
    for source in value['sourceRoots'].values():
        source = _no_links(source).resolve(strict=True)
        _require(not root.resolve().is_relative_to(source) and not source.is_relative_to(root.resolve()), 'runtime output/source overlap')
    with tempfile.TemporaryDirectory(prefix='.runtime-',dir=root.parent) as temporary:
        staged = Path(temporary)/'runtime'; staged.mkdir()
        for row in value['files']:
            raw = bytes.fromhex(row['generated']) if row['sourceRoot'] is None else _read(Path(value['sourceRoots'][row['sourceRoot']])/row['sourcePath'])
            _require((len(raw),sha(raw)) == (row['bytes'],row['sha256']), 'runtime original file changed')
            target = staged/row['path']; target.parent.mkdir(parents=True,exist_ok=True); target.write_bytes(raw)
        report = validate_tree(staged,recipe_raw,expected_sha256)
        _no_links(root); _require(not root.exists(),'runtime output already exists')
        _require(os.name == 'nt','runtime atomic publication currently requires Windows')
        os.rename(staged,root)
    return report
