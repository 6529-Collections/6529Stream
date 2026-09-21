"""Regenerate every declared V10/V3 vector with preserved reviewed code/runtime.

Execution is an explicit operation. Inspection alone never authenticates an old
execution claim. The caller must trust the selected source and native runtime;
hash checks and the Python audit guard do not make hostile code safe.
"""
import argparse
from hashlib import sha256
import os
from pathlib import Path
import re
import subprocess
from tempfile import TemporaryDirectory
import time

from . import acquisition_canonical_v10 as packet
from . import canonical_object_dossier_v3 as dossier
from . import object_dossier as assembly
from .bagit import MAX_BYTES, read_tree, write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require
from .repository_exchange import _destination, _publish

NAME = 'STREAM_PRESERVED_TOOL_REPLAY_V1'
VECTOR_SCHEMA = 'STREAM_PRESERVED_TOOL_REPLAY_VECTORS_V1'
MAX_CASES = 16
MAX_VECTOR_BYTES = 96 * 1024 * 1024
MAX_LOG_BYTES = 1024 * 1024
CLAIMS = {'allDeclaredVectorsRegenerated': True, 'allOriginalOutputBytesEqual': True,
    'operatorServiceUsed': False, 'networkFetch': False, 'archivedCodeExecuted': True,
    'compiledBuildReproduced': False, 'fullGenesisReconstructionProven': False,
    'zeroOperatorCanonicalCompletion': False, 'osSandbox': False,
    'sourceAuthorityProven': False, 'institutionalAcceptance': False}
QUALIFICATION = ('Executed regeneration of all declared V10 packet and V3 dossier vectors from '
    'explicitly pinned preserved source and a preserved prebuilt CPython/dependency environment. '
    'Original source observations are replayed offline; this does not retrieve missing chain state, '
    'prove consensus, reproduce a compiler build, render works, authenticate earlier executions, '
    'prove a complete LTA-RECON client, or establish institutional/release acceptance. '
    'The selected code and native runtime require caller trust. Python audit restrictions are '
    'defence against accidental access, not an OS sandbox. Windows remains an external prerequisite.')


def vector_inputs(cases):
    """Preserve exact input packages; no caller-supplied expected output claims."""
    require(type(cases) is list and 0 < len(cases) <= MAX_CASES, 'replay case count bound')
    files, rows = {}, []
    for case in cases:
        require(type(case) is dict and set(case) == {'id', 'kind', 'files', 'manifestHash'},
            'replay case fields differ')
        identifier, kind = case['id'], case['kind']
        require(isinstance(identifier, str) and re.fullmatch(r'[a-z][a-z0-9-]{0,47}', identifier),
            'replay case id differs')
        require(kind in ('packet_v10', 'dossier_v3'), 'unsupported replay kind')
        require(identifier not in [r['id'] for r in rows], 'duplicate replay case id')
        original = dict(case['files'])
        assembly._bounded(original)
        require(keccak256(original.get('manifest.json', b'')) == case['manifestHash']
            and any(hex_bytes(case['manifestHash'], 32)), 'replay vector manifest pin differs')
        root = 'cases/' + identifier
        files.update({root + '/' + path: raw for path, raw in original.items()})
        rows.append({'id': identifier, 'kind': kind, 'root': root, 'manifestHash': case['manifestHash']})
    files['replay-vectors.json'] = dumps({'schema': VECTOR_SCHEMA, 'cases': sorted(rows, key=lambda r: r['id'])})
    require(sum(map(len, files.values())) <= MAX_VECTOR_BYTES, 'replay vector byte bound')
    return files


def admit_vectors(source):
    files = {p.removeprefix('vectors/'): raw for p, raw in source.items() if p.startswith('vectors/')}
    descriptor = loads(files.get('replay-vectors.json', b''), maximum=1 << 20, canonical=True)
    require(type(descriptor) is dict and set(descriptor) == {'schema', 'cases'}
        and descriptor['schema'] == VECTOR_SCHEMA and type(descriptor['cases']) is list
        and 0 < len(descriptor['cases']) <= MAX_CASES, 'replay vector descriptor differs')
    cases, expected = [], {'replay-vectors.json'}
    for row in descriptor['cases']:
        require(type(row) is dict and set(row) == {'id', 'kind', 'root', 'manifestHash'},
            'replay vector row fields differ')
        identifier = row['id']
        require(isinstance(identifier, str) and re.fullmatch(r'[a-z][a-z0-9-]{0,47}', identifier)
            and row['root'] == 'cases/' + identifier, 'replay vector path differs')
        prefix = row['root'] + '/'
        original = {p.removeprefix(prefix): raw for p, raw in files.items() if p.startswith(prefix)}
        cases.append({'id': identifier, 'kind': row['kind'], 'files': original, 'manifestHash': row['manifestHash']})
        expected.update(prefix + p for p in original)
    require(set(files) == expected and vector_inputs(cases) == files,
        'replay vectors contain ignored, unordered or conflicting occurrences')
    return cases


def _expected(cases):
    results = []
    for case in cases:
        module = packet if case['kind'] == 'packet_v10' else dossier
        checked = module.verify(case['files'], case['manifestHash'])
        original = dict(checked.files)
        path = packet.PACKET_PATH if case['kind'] == 'packet_v10' else dossier.DOSSIER_PATH
        requirements = checked.report['items'] if case['kind'] == 'packet_v10' else {
            'packet': checked.report['packetRequirements'], 'dossier': checked.report['dossierRequirements']}
        require(len(checked.report['items'] if case['kind'] == 'packet_v10'
            else checked.report['packetRequirements']) == 19, 'replay lost packet requirements')
        if case['kind'] == 'dossier_v3':
            require(checked.report['dossierRequirements']['counts']['total'] == 49
                and len(checked.report['dossierRequirements']['results']) == 49,
                'replay lost dossier requirements')
        results.append({'id': case['id'], 'kind': case['kind'], 'manifestHash': checked.manifest_hash,
            'exportHash': keccak256(original[path]), 'files': len(original),
            'bytes': sum(map(len, original.values())), 'requirements': requirements})
    return results


def validate_toolchain(source_manifest, runtime_files, recipe, runtime_pin, recipe_pin):
    """Join chosen runtime inputs to the pins inside the selected source archive."""
    pins = {row['name']: row for row in source_manifest['externalPins']}
    prerequisites = source_manifest['prerequisites']
    python = [row for row in prerequisites if row['name'] == 'CPython']
    require(len(python) == 1, 'preserved replay CPython prerequisite denominator')
    declared = pins.get(python[0]['pin'])
    parts = runtime_files['parts.json']
    require(declared is not None and declared['role'] == 'runtime'
        and declared['sha256'] == runtime_pin == sha256(parts).hexdigest()
        and declared['bytes'] == len(parts),
        'preserved replay runtime is not the source-declared package manifest')
    require(sha256(recipe).hexdigest() == recipe_pin and any(row['sha256'] == recipe_pin
        and row['bytes'] == len(recipe) and row['role'] in ('runtime', 'system') for row in pins.values()),
        'preserved replay recipe is not source-declared')
    value = loads(recipe, maximum=2 << 20, canonical=True)
    require(python[0]['version'] == value['pythonVersion'], 'preserved replay source/runtime Python version differs')


def _child(executable, worker, root, timeout):
    require(type(timeout) is int and 1 <= timeout <= 1800, 'replay timeout bound')
    # No inherited tokens, proxy settings, user profile, HOME, PYTHONPATH or PATH.
    environment = {'SystemRoot': os.environ.get('SystemRoot', r'C:\Windows'),
        'WINDIR': os.environ.get('SystemRoot', r'C:\Windows'),
        'TEMP': str(root / 'result'), 'TMP': str(root / 'result')}
    stdout, stderr = root / 'stdout.log', root / 'stderr.log'
    with stdout.open('wb') as out, stderr.open('wb') as err:
        process = subprocess.Popen([str(executable), '-I', '-S', '-B', str(worker), str(root)],
            cwd=root, env=environment, stdin=subprocess.DEVNULL, stdout=out, stderr=err,
            creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        deadline = time.monotonic() + timeout
        try:
            while process.poll() is None:
                require(time.monotonic() < deadline, 'preserved replay timed out')
                require(stdout.stat().st_size + stderr.stat().st_size <= MAX_LOG_BYTES,
                    'preserved replay output bound')
                time.sleep(0.05)
        except BaseException:
            process.kill()
            process.wait()
            raise
    require(stdout.stat().st_size + stderr.stat().st_size <= MAX_LOG_BYTES,
        'preserved replay output bound')
    require(process.returncode == 0, 'preserved replay child failed: '
        + stderr.read_bytes()[-4096:].decode('utf-8', errors='replace'))
    return stdout.read_bytes(), stderr.read_bytes()


def validate_child(child, expected, source_files, runtime_recipe, worker_raw):
    """Check receipt consistency; these hashes do not authenticate execution."""
    require(type(child) is dict and set(child) == {'schema', 'cases', 'modules', 'readFiles', 'python',
        'implementation', 'isolation', 'auditGuard', 'osSandbox'}
        and child['schema'] == 'STREAM_PRESERVED_TOOL_CHILD_RESULT_V1'
        and child['cases'] == expected and child['implementation'] == 'cpython'
        and child['isolation'] == {'isolated': True, 'noSite': True, 'noUserSite': True,
            'ignoreEnvironment': True} and child['osSandbox'] is False
        and child['auditGuard'] == 'python_network_process_and_path_guard_v1',
        'preserved replay child result differs')
    recipe = loads(runtime_recipe, maximum=2 << 20, canonical=True)
    require(type(child['python']) is str and child['python'].startswith(recipe['pythonVersion'] + ' '),
        'preserved replay recorded Python version differs')
    pins = {'source/' + p: sha256(raw).hexdigest() for p, raw in source_files.items()}
    pins.update({'runtime/' + row['path']: row['sha256'] for row in recipe['files']})
    pins['worker.py'] = sha256(worker_raw).hexdigest()
    require(type(child['modules']) is list and 1 <= len(child['modules']) <= 8192,
        'preserved replay module inventory bound')
    names = []
    for row in child['modules']:
        require(type(row) is dict and set(row) == {'module', 'path', 'sha256'}
            and type(row['module']) is str and row['module']
            and type(row['path']) is str and type(row['sha256']) is str
            and row['path'] in pins and row['sha256'] == pins[row['path']],
            'preserved replay module byte pin differs')
        names.append(row['module'])
    require(names == sorted(set(names)) and {'__main__', 'tools.museum.acquisition_canonical_v10',
        'tools.museum.canonical_object_dossier_v3'} <= set(names),
        'preserved replay module denominator differs')
    require(type(child['readFiles']) is list and 1 <= len(child['readFiles']) <= 16384,
        'preserved replay read inventory bound')
    paths = []
    for row in child['readFiles']:
        require(type(row) is dict and set(row) == {'path', 'sha256'}
            and type(row['path']) is str and row['path'] in pins and row['sha256'] == pins[row['path']],
            'preserved replay file read pin differs')
        paths.append(row['path'])
    require(paths == sorted(set(paths)) and {row['path'] for row in child['modules']} <= set(paths),
        'preserved replay read inventory denominator differs')


def run(source_package, source_parts_sha256, runtime_package, runtime_parts_sha256,
        runtime_recipe, runtime_recipe_sha256, *, output, timeout=900):
    """Explicitly execute the exact selected reviewed archives, without fetch/install."""
    require(os.name == 'nt', 'preserved runtime currently requires Windows x86_64')
    from . import preserved_tool_source_v1 as source_tool
    from . import preserved_tool_runtime_v1 as runtime_tool
    sources = [Path(source_package), Path(runtime_package)]
    _destination(output, sources)
    # Generic transport verifier validates every byte before extraction. The
    # separate runtime recipe then authenticates interpreter/dependency closure.
    with TemporaryDirectory(prefix='stream-preserved-replay-') as temporary:
        root = Path(temporary)
        source_archive = source_tool.restore_verified(Path(source_package), source_parts_sha256, root / 'source')
        runtime_archive = source_tool.restore_transport(Path(runtime_package), runtime_parts_sha256, root / 'runtime')
        validate_toolchain(source_archive.source_manifest, dict(runtime_archive.files),
            runtime_recipe, runtime_parts_sha256, runtime_recipe_sha256)
        runtime_report = runtime_tool.validate_tree(root / 'runtime', runtime_recipe, runtime_recipe_sha256)
        source_files = read_tree(root / 'source')
        cases = admit_vectors(source_files)
        worker_raw = Path(__file__).with_name('preserved_tool_worker_v1.py').read_bytes()
        worker = root / 'worker.py'
        worker.write_bytes(worker_raw)
        out, err = _child(root / 'runtime/python.exe', worker, root, timeout)
        result = read_tree(root / 'result')
        child = loads(result.pop('child-report.json', b''), maximum=8 << 20, canonical=True)
        expected = _expected(cases)
        validate_child(child, expected, source_files, runtime_recipe, worker_raw)
        expected_files = {case['id'] + '/' + p: raw for case in cases for p, raw in case['files'].items()}
        require(result == expected_files, 'preserved replay full output reconstruction differs')
        require(read_tree(root / 'source') == source_files, 'preserved source changed during replay')
        runtime_tool.validate_tree(root / 'runtime', runtime_recipe, runtime_recipe_sha256)
        # Read the accepted package again to detect concurrent replacement.
        source_tool.verify(Path(source_package), source_parts_sha256)
        source_tool.verify_transport(Path(runtime_package), runtime_parts_sha256)
        report = {'schema': NAME, 'sourcePartsSha256': source_parts_sha256,
            'runtimePartsSha256': runtime_parts_sha256, 'runtimeRecipeSha256': runtime_recipe_sha256,
            'workerSha256': sha256(worker_raw).hexdigest(), 'cases': expected,
            'child': child, 'runtime': runtime_report, 'claims': CLAIMS,
            'qualification': QUALIFICATION}
        files = {'report.json': dumps(report), 'worker.py': worker_raw,
            'runtime-recipe.json': runtime_recipe, 'vectors.json': source_files['vectors/replay-vectors.json'],
            'stdout.log': out, 'stderr.log': err}
        manifest = dumps({'schema': NAME, 'files': [assembly._ref(p, raw) for p, raw in sorted(files.items())],
            'qualification': QUALIFICATION})
        files['manifest.json'] = manifest
        _publish(files, output, sources)
        return assembly.Assembly(tuple(sorted(files.items())), manifest, report)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-package', required=True, type=Path)
    parser.add_argument('--source-sha256', required=True)
    parser.add_argument('--runtime-package', required=True, type=Path)
    parser.add_argument('--runtime-sha256', required=True)
    parser.add_argument('--runtime-recipe', required=True, type=Path)
    parser.add_argument('--runtime-recipe-sha256', required=True)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--timeout', type=int, default=900)
    args = parser.parse_args(argv)
    try:
        result = run(args.source_package, args.source_sha256, args.runtime_package, args.runtime_sha256,
            args.runtime_recipe.read_bytes(), args.runtime_recipe_sha256, output=args.output, timeout=args.timeout)
        print(dumps({'manifestHash': result.manifest_hash, 'cases': len(result.report['cases'])}).decode())
    except (MuseumError, OSError) as exc:
        parser.exit(2, str(exc) + '\n')


if __name__ == '__main__':
    main()
