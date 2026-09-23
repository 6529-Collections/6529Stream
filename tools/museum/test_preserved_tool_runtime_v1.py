"""Bounded real local runtime relocation plus fail-closed recipe controls."""
from copy import deepcopy
import json
import os
from pathlib import Path
import subprocess
import struct
import sys
from tempfile import TemporaryDirectory
import unittest

from . import preserved_tool_runtime_v1 as r


class RuntimeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if os.name != 'nt' or not (Path(sys.base_prefix)/'conda-meta'/f'python-{r.PYTHON_VERSION}-{r.PYTHON_BUILD}.json').is_file():
            raise unittest.SkipTest('exact locally preserved Windows CPython installation unavailable')
        cls.raw = r.plan(sys.base_prefix,Path(sys.prefix)/'Lib/site-packages')
        cls.digest = r.sha(cls.raw); cls.value = json.loads(cls.raw)
        cls.temporary = TemporaryDirectory(prefix='stream-runtime-tests-')
        cls.root = Path(cls.temporary.name); cls.runtime = cls.root/'runtime'
        cls.report = r.materialize(cls.raw,cls.digest,cls.runtime)

    @classmethod
    def tearDownClass(cls): cls.temporary.cleanup()

    def recipe(self, mutate):
        value = deepcopy(self.value); mutate(value)
        raw = r.canonical(value); return raw,r.sha(raw)

    def test_real_runtime_relocation_has_no_base_installation_dependency(self):
        code = """import sys,json,hashlib,ctypes,sqlite3,bz2,lzma,ssl
import jsonschema,rfc8785,blake3,lxml.etree
from Crypto.Hash import keccak
from pyld import jsonld
assert jsonschema.Draft202012Validator({'type':'integer'}).is_valid(1)
assert rfc8785.dumps({'x':1})==b'{"x":1}'
assert blake3.blake3(b'abc').hexdigest()=='6437b3ac38465133ffb63b75273a8db548c558465d79db03fd359c6cd5bd9d85'
assert keccak.new(digest_bits=256).hexdigest()=='c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470'
assert lxml.etree.fromstring(b'<x/>').tag=='x'
print(json.dumps({'version':sys.version_info[:3],'prefix':sys.prefix,'base':sys.base_prefix,'executable':sys.executable,'paths':sys.path,'isolated':sys.flags.isolated,'no_site':sys.flags.no_site}))"""
        env = {k:os.environ[k] for k in ('SystemRoot','TEMP','TMP') if k in os.environ}
        env.update(PYTHONHOME='Z:/unavailable-python',PYTHONPATH='Z:/unavailable-source',PATH='')
        completed = subprocess.run([str(self.runtime/'python.exe'),'-I','-S','-B','-c',code],
            cwd=self.root,env=env,capture_output=True,text=True,timeout=30,check=True)
        result = json.loads(completed.stdout)
        self.assertEqual(result['version'],[3,13,13]); self.assertEqual(Path(result['prefix']),self.runtime)
        self.assertEqual(Path(result['base']),self.runtime); self.assertEqual(result['isolated'],1); self.assertEqual(result['no_site'],1)
        self.assertTrue(all(Path(p).is_relative_to(self.root) for p in result['paths']))
        self.assertEqual(r.validate_tree(self.runtime,self.raw,self.digest),self.report)
        self.assertFalse(self.report['qualification']['operatingSystemIncluded'])

    def test_exact_recipe_is_deterministic_and_contains_licenses_without_pip(self):
        self.assertEqual(r.plan(sys.base_prefix,Path(sys.prefix)/'Lib/site-packages'),self.raw)
        self.assertEqual(self.runtime.joinpath('python313._pth').read_bytes(),r.PTH)
        self.assertEqual({d['name'] for d in self.value['distributions']},set(r.DISTRIBUTIONS))
        self.assertTrue(all(d['licenses'] for d in self.value['distributions']))
        self.assertTrue(all(p['licenseFilesAvailable'] and p['licenseFiles'] for p in self.value['sourcePackages']))
        self.assertFalse(self.report['qualification']['redistributionPermissionEstablished'])
        self.assertFalse(any('/pip/' in row['path'] or '__pycache__' in row['path'] for row in self.value['files']))
        self.assertLess(self.report['bytes'],r.MAX_BYTES)

    def test_external_pin_and_modified_member_rejected(self):
        with self.assertRaisesRegex(ValueError,'external recipe pin'): r.validate_tree(self.runtime,self.raw,'0'*64)
        path = self.runtime/'Lib/json/__init__.py'; before = path.read_bytes()
        try:
            path.write_bytes(before+b'\n# modified\n')
            with self.assertRaisesRegex(ValueError,'byte pin'): r.validate_tree(self.runtime,self.raw,self.digest)
        finally: path.write_bytes(before)

    def test_missing_extra_and_symlink_members_rejected(self):
        extra = self.runtime/'unexpected.txt'; extra.write_bytes(b'extra')
        try:
            with self.assertRaisesRegex(ValueError,'unexpected tree'): r.validate_tree(self.runtime,self.raw,self.digest)
        finally: extra.unlink()
        path = self.runtime/'Lib/json/__init__.py'; before = path.read_bytes(); path.unlink()
        try:
            with self.assertRaisesRegex(ValueError,'file missing'): r.validate_tree(self.runtime,self.raw,self.digest)
        finally: path.write_bytes(before)

    def test_rehashed_path_alias_size_and_path_configuration_controls(self):
        mutations = [lambda v:v['files'][0].update(path='../escape'),
            lambda v:v['files'].append(deepcopy(v['files'][0])),
            lambda v:v['files'][0].update(bytes=True),
            lambda v:v['files'][0].update(bytes=r.MAX_FILE+1),
            lambda v:next(row for row in v['files'] if row['path']=='python313._pth').update(generated=b'import site\n'.hex()),
            lambda v:v['distributions'].pop(),
            lambda v:v['externalLibraries'].append('unknown-arbitrary.dll')]
        for mutation in mutations:
            with self.subTest(mutation=mutation),self.assertRaises(ValueError):
                raw,digest = self.recipe(mutation); r._recipe(raw,digest)

    def test_removed_native_dependency_is_not_a_complete_tree(self):
        rows = deepcopy(self.value); rows['files'] = [row for row in rows['files'] if row['path'].lower()!='ffi.dll']
        raw = r.canonical(rows); digest = r.sha(raw); path = self.runtime/'ffi.dll'; before = path.read_bytes(); path.unlink()
        try:
            with self.assertRaisesRegex(ValueError,'native dependency absent ffi.dll'): r.validate_tree(self.runtime,raw,digest)
        finally:path.write_bytes(before)

    def test_path_configuration_cannot_be_recast_as_a_source_file(self):
        def relabel(value):
            row = next(row for row in value['files'] if row['path']=='python313._pth')
            row.update(sourceRoot='base',sourcePath='Lib/os.py',category='python',generated=None,
                bytes=12,sha256=r.sha(b'import site\n'))
        raw,digest = self.recipe(relabel)
        with self.assertRaisesRegex(ValueError,'isolated path configuration'):r._recipe(raw,digest)
        for name in ('python._pth','pyvenv.cfg'):
            def extra(value):
                row=deepcopy(value['files'][0]);row['path']=name;value['files'].append(row);value['files'].sort(key=lambda r:r['path'])
            raw,digest=self.recipe(extra)
            with self.subTest(name=name),self.assertRaisesRegex(ValueError,'alternate Python path'):r._recipe(raw,digest)

    def test_rehashed_distribution_inventory_cannot_drop_original_record_member(self):
        value=deepcopy(self.value); d=next(d for d in value['distributions'] if d['name']=='rfc8785')
        name=next(p for p in d['files'] if p.endswith('/py.typed'))
        value['files']=[row for row in value['files'] if row['path']!=name];d['files'].remove(name)
        raw=r.canonical(value);digest=r.sha(raw);path=self.runtime/name;before=path.read_bytes();path.unlink()
        try:
            with self.assertRaisesRegex(ValueError,'RECORD member missing'):r.validate_tree(self.runtime,raw,digest)
        finally:path.write_bytes(before)

    def test_rehashed_stdlib_inventory_cannot_drop_original_python_member(self):
        value=deepcopy(self.value);name='Lib/json/decoder.py'
        value['files']=[row for row in value['files'] if row['path']!=name]
        raw=r.canonical(value);digest=r.sha(raw);path=self.runtime/name;before=path.read_bytes();path.unlink()
        try:
            with self.assertRaisesRegex(ValueError,'CPython file denominator'):r.validate_tree(self.runtime,raw,digest)
        finally:path.write_bytes(before)

    def test_input_changes_and_existing_output_do_not_publish(self):
        with self.assertRaisesRegex(ValueError,'must be new'): r.materialize(self.raw,self.digest,self.runtime)
        raw,digest = self.recipe(lambda v:v['files'][0].update(sha256='0'*64))
        target = self.root/'failed'
        with self.assertRaisesRegex(ValueError,'original file changed'): r.materialize(raw,digest,target)
        self.assertFalse(target.exists())
        with self.assertRaisesRegex(ValueError,'overlap'):
            r.materialize(self.raw,self.digest,Path(sys.base_prefix)/'forbidden-runtime-output')

    def test_venv_launcher_and_truncated_pe_are_not_interpreters(self):
        launcher = Path(sys.executable).read_bytes()
        self.assertNotIn('python313.dll',r.pe_imports(launcher))
        for raw in (b'',b'MZ'+bytes(70),(self.runtime/'python.exe').read_bytes()[:100]):
            with self.subTest(length=len(raw)),self.assertRaises(ValueError): r.pe_imports(raw)

    def test_pe_import_directory_must_fit_declared_sections(self):
        original = (self.runtime/'python.exe').read_bytes()
        pe, = struct.unpack_from('<I',original,60)
        for width in (0,4,0xffffffff):
            raw = bytearray(original); struct.pack_into('<I',raw,pe+24+124,width)
            with self.subTest(width=width),self.assertRaises(ValueError):r.pe_imports(bytes(raw))

    def test_real_symlink_root_rejected(self):
        link = self.root/'linked-runtime'
        try: link.symlink_to(self.runtime,target_is_directory=True)
        except OSError as exc: self.skipTest('Windows symlink privilege unavailable: '+str(exc.winerror))
        try:
            with self.assertRaisesRegex(ValueError,'link or junction'): r.validate_tree(link,self.raw,self.digest)
        finally: link.unlink()


if __name__ == '__main__': unittest.main()
