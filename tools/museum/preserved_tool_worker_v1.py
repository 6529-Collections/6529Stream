"""Fixed child entrypoint for reviewed, externally pinned Museum tool archives.

The audit guard prevents accidental Python network/process use and writes outside
the disposable result tree. It is not a security sandbox for hostile native code.
This file is copied verbatim into each replay receipt.
"""
import hashlib
import json
import os
from pathlib import Path
import sys


def main():
    root = Path(sys.argv[1]).resolve()
    source, runtime, output = root / 'source', root / 'runtime', root / 'result'
    sys.dont_write_bytecode = True
    output.mkdir()
    allowed_reads = (source, runtime, output, root / 'worker.py')
    read_paths = set()

    def inside(path, roots):
        if isinstance(path, int):
            return True
        try:
            value = Path(os.fsdecode(path)).resolve()
            return any(value == item or value.is_relative_to(item) for item in roots)
        except (TypeError, ValueError, OSError):
            return False

    def guard(event, args):
        if (event.startswith('socket.') or event.startswith('subprocess.')
                or event in ('os.system', 'os.posix_spawn', 'os.fork', 'os.forkpty',
                    'os.exec', 'os.spawn', 'os.startfile', 'os.startfile/2')):
            raise RuntimeError('preserved replay forbids network and child processes')
        if event == 'open':
            mode, flags = args[1], args[2]
            writing = (isinstance(mode, str) and any(c in mode for c in 'wax+')) or (
                isinstance(flags, int) and bool(flags & (os.O_WRONLY | os.O_RDWR | os.O_CREAT | os.O_TRUNC)))
            if not inside(args[0], (output,) if writing else allowed_reads):
                raise RuntimeError('preserved replay file outside admitted roots')
            if not writing and not isinstance(args[0], int):
                path = Path(os.fsdecode(args[0])).resolve()
                if not path.is_relative_to(output):
                    read_paths.add(path)
        if event in ('os.remove', 'os.rmdir', 'os.mkdir', 'os.chmod', 'os.utime', 'os.truncate'):
            if not inside(args[0], (output,)):
                raise RuntimeError('preserved replay mutation outside result')
        if event in ('os.rename', 'os.link', 'os.symlink'):
            if event != 'os.rename' or not all(inside(p, (output,)) for p in args[:2]):
                raise RuntimeError('preserved replay link or rename refused')

    sys.addaudithook(guard)
    from tools.museum import acquisition_canonical_v10 as packet
    from tools.museum import canonical_object_dossier_v3 as dossier
    from tools.museum.bagit import read_tree, write_tree
    from tools.museum.canonical import dumps, keccak256, loads

    descriptor = loads((source / 'vectors/replay-vectors.json').read_bytes(), maximum=1 << 20, canonical=True)
    results = []
    for case in descriptor['cases']:
        original = read_tree(source / 'vectors' / case['root'])
        module = packet if case['kind'] == 'packet_v10' else dossier
        checked = module.verify(original, case['manifestHash'])
        rebuilt = dict(checked.files)
        if rebuilt != original:
            raise RuntimeError('archived replay changed an original member')
        write_tree(checked.files, output / case['id'])
        path = packet.PACKET_PATH if case['kind'] == 'packet_v10' else dossier.DOSSIER_PATH
        requirements = checked.report['items'] if case['kind'] == 'packet_v10' else {
            'packet': checked.report['packetRequirements'], 'dossier': checked.report['dossierRequirements']}
        results.append({'id': case['id'], 'kind': case['kind'], 'manifestHash': checked.manifest_hash,
            'exportHash': keccak256(rebuilt[path]), 'files': len(rebuilt),
            'bytes': sum(map(len, rebuilt.values())), 'requirements': requirements})
    modules = []
    for name, module in sorted(sys.modules.items()):
        filename = getattr(module, '__file__', None)
        if not filename or filename.startswith('<'):
            continue
        path = Path(filename).resolve()
        if not inside(path, (source, runtime, root / 'worker.py')):
            raise RuntimeError('module loaded outside preserved source/runtime: ' + name)
        modules.append({'module': name, 'path': path.relative_to(root).as_posix(),
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    reads = [{'path': path.relative_to(root).as_posix(),
        'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
        for path in sorted(tuple(read_paths)) if path.is_file()]
    reads.sort(key=lambda row: row['path'])
    report = {'schema': 'STREAM_PRESERVED_TOOL_CHILD_RESULT_V1', 'cases': results,
        'modules': modules, 'readFiles': reads, 'python': sys.version, 'implementation': sys.implementation.name,
        'isolation': {'isolated': bool(sys.flags.isolated), 'noSite': bool(sys.flags.no_site),
            'noUserSite': bool(sys.flags.no_user_site), 'ignoreEnvironment': bool(sys.flags.ignore_environment)},
        'auditGuard': 'python_network_process_and_path_guard_v1', 'osSandbox': False}
    (output / 'child-report.json').write_bytes(dumps(report))
    print(json.dumps({'cases': len(results), 'status': 'replayed'}, sort_keys=True))


if __name__ == '__main__':
    main()
