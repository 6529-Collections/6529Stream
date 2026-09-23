"""Cached exact-roster TEST dispatch from a prepared native execution view.

The compiler substitute answers version queries and rejects every compilation.
Script/helper entrypoints can be prepared but cannot be executed by this runner.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

from tools.build.current_graph_owners import strict_json
from tools.build.current_native_execution_view import file_hash, recheck, require
from tools.build.scoped_standard_json import canonical, VERSION
from tools.development.run_current_acceptance import validate_filters, test_results


def clean_environment(profile: str, chain_id: int) -> dict:
    require(re.fullmatch(r'[A-Za-z0-9_-]+', profile), 'Invalid Foundry profile')
    env = {k: v for k, v in os.environ.items() if not k.upper().startswith(('FOUNDRY_', 'DAPP_'))}
    require(type(chain_id) is int and chain_id == 31337, 'Explicit local chain ID 31337 required')
    env['FOUNDRY_PROFILE'] = profile
    env['FOUNDRY_CHAIN_ID'] = str(chain_id)
    return env


def validate_local_config(config: dict, chain_id: int):
    require(not config.get('eth_rpc_url') and not config.get('fork_url')
            and config.get('fork_block_number') is None and config.get('fork_block_hash') is None,
            'RPC/fork configuration is not local native execution evidence')
    require(chain_id == 31337 and config.get('chain_id') in (31337, 'anvil-hardhat'),
            'Effective chain ID differs from explicit local chain 31337')
    require(config.get('isolate') is False, 'Original non-isolated test mode required')


def deny_compiler(folder: Path) -> Path:
    script = folder / 'deny_compiler.py'
    script.write_text('import json,sys\nfrom pathlib import Path\n'
                      'if sys.argv[1:] == ["--version"]:\n'
                      f' sys.stdout.write({("solc, the solidity compiler commandline interface\nVersion: " + VERSION + ".Windows.msvc\n")!r});sys.exit(0)\n'
                      'with Path(__file__).with_suffix(".attempts.jsonl").open("a",encoding="utf-8") as f:\n'
                      ' f.write(json.dumps(sys.argv[1:])+"\\n")\n'
                      'sys.stderr.write("Native execution view refuses compilation\\n");sys.exit(91)\n', encoding='utf-8')
    if os.name == 'nt':
        wrapper = folder / 'deny_compiler.cmd'
        require('"' not in str(sys.executable) + str(script) and '%' not in str(sys.executable) + str(script), 'Unsafe compiler wrapper path')
        wrapper.write_bytes(f'@echo off\r\n"{sys.executable}" -B "{script}" %*\r\n'.encode())
    else:
        wrapper = folder / 'deny_compiler'
        require("'" not in str(sys.executable) + str(script), 'Unsafe compiler wrapper path')
        wrapper.write_text(f"#!/bin/sh\nexec '{sys.executable}' -B '{script}' \"$@\"\n", encoding='utf-8')
        wrapper.chmod(0o700)
    return wrapper


def invoke(command: list[str], folder: Path, project: Path, env: dict, timeout: int) -> dict:
    """Retain an attempt before launch and terminate only this exact process tree."""
    folder.mkdir(exist_ok=False)
    (folder / 'attempt.json').write_bytes(canonical({'command': command, 'cwd': str(project), 'timeoutSeconds': timeout}))
    start = time.monotonic(); process = None; status = 'COMPLETE'; code = None
    with (folder / 'stdout').open('wb') as stdout, (folder / 'stderr').open('wb') as stderr:
        try:
            process = subprocess.Popen(command, cwd=project, env=env, stdout=stdout, stderr=stderr)
            (folder / 'process-start.json').write_bytes(canonical({'pid': process.pid}))
            code = process.wait(timeout=timeout)
        except BaseException as exc:
            status = 'TIMEOUT' if isinstance(exc, subprocess.TimeoutExpired) else 'INTERRUPTED'
            if process is not None and process.poll() is None:
                if os.name == 'nt':
                    subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], capture_output=True, check=False)
                else:
                    process.kill()
                code = process.wait(timeout=15)
            raise
        finally:
            result = {'status': status, 'exitCode': code, 'seconds': time.monotonic() - start,
                      'stdoutSha256': file_hash(folder / 'stdout'), 'stderrSha256': file_hash(folder / 'stderr')}
            (folder / 'process-result.json').write_bytes(canonical(result))
    return result


def validate_listing(data: dict, coordinate: str, cases: list[str]):
    source, name = coordinate.split(':')
    require(set(data) == {source} and set(data[source]) == {name}, 'Discovered test host inventory differs')
    expected = [case.partition('(')[0] for case in cases]
    require(len(expected) == len(set(expected)), 'Overloaded test names unsupported by Forge list inventory')
    require(sorted(data[source][name]) == sorted(expected), 'Discovered test cases differ from complete native ABI')


def commands(forge: Path, project: Path, view: Path, compiler: Path, coord: str, *, list_only: bool, verbosity: int = 0) -> list[str]:
    require(verbosity in (0, 3, 4, 5), 'Unsupported trace verbosity')
    source, name = coord.split(':')
    command = [str(forge), 'test', '--root', str(project), '--use', str(compiler), '--offline',
               '--out', str(view / 'out'), '--cache-path', str(view / 'cache'), '--extra-output', 'storageLayout',
               '--match-path', source, '--match-contract', '^' + re.escape(name) + '$', '--json']
    if list_only:
        command += ['--list']
    else:
        command += ['--fuzz-runs', '256', '--fuzz-seed', '0x6529']
        if verbosity:
            command += ['-' + 'v' * verbosity]
    return command


def run(view_file: Path, expected_hash: str, forge: Path, forge_sha256: str, destination: Path,
        *, profile: str = 'current', list_only: bool = True, timeout: int = 600, verbosity: int = 0, chain_id: int | None = None) -> dict:
    require(file_hash(view_file) == expected_hash, 'Execution-view proof hash differs')
    require(file_hash(forge) == forge_sha256, 'Forge binary changed')
    snapshot = strict_json(view_file.read_bytes())
    require(snapshot['version'] == 1 and snapshot['status'] == 'PREPARED_EXECUTION_VIEW', 'Unknown execution view')
    require(snapshot['expectedCases'], 'No test entrypoint: helper/script execution is unsupported')
    require(0 < timeout <= 3600, 'Expected bounded process timeout')
    # Helpers may exist as dependencies, but are never silently counted as executed cases.
    cases = snapshot['expectedCases']; project = Path(snapshot.get('executionProject', snapshot['project']))
    view = Path(snapshot['view'])
    require(not destination.exists(), 'Dispatch destination must be new')
    require(not destination.resolve().is_relative_to(view / 'out')
            and not destination.resolve().is_relative_to(view / 'cache')
            and not destination.resolve().is_relative_to(project),
            'Dispatch cannot overwrite routing or execution project evidence')
    from tools.build.current_native_execution_view import require_disjoint
    require_disjoint(destination, [Path(p) for p in snapshot['protectedDirectories']]
                     + [Path(p) for p in snapshot['inputFiles']] + [view_file])
    recheck(snapshot)
    destination.mkdir(parents=True); compiler = deny_compiler(destination)
    tool_hashes = {str(p.resolve()): file_hash(p) for p in (forge, compiler, destination / 'deny_compiler.py', Path(__file__))}
    env = clean_environment(profile, chain_id)
    result = {'status': 'STARTED', 'executionViewSha256': expected_hash, 'forgeSha256': forge_sha256,
              'listOnly': list_only, 'profile': profile, 'verbosity': verbosity, 'chainId': chain_id, 'expectedCases': cases, 'tools': tool_hashes, 'runs': {}}
    (destination / 'dispatch.json').write_bytes(canonical(result))
    try:
        config_command = [str(forge), 'config', '--root', str(project), '--use', str(compiler), '--offline',
                          '--out', str(view / 'out'), '--cache-path', str(view / 'cache'), '--extra-output', 'storageLayout', '--json']
        config_run = invoke(config_command, destination / 'config', project, env, min(timeout, 60))
        require(config_run['exitCode'] == 0, 'Forge config failed')
        config = strict_json((destination / 'config/stdout').read_bytes()); validate_filters(config)
        validate_local_config(config, chain_id)
        result['effectiveChainId'] = config['chain_id']
        require(config['via_ir'] is True and config['evm_version'] == 'paris' and config['optimizer'] is True
                and config['optimizer_runs'] == 200 and config['bytecode_hash'].lower() == 'none'
                and config['cbor_metadata'] is False and not config['libraries'], 'Execution compiler profile differs')
        if not list_only:
            require(config['gas_limit'] == 10000000000 and config['memory_limit'] == 1073741824
                    and config['code_size_limit'] == 2000000, 'Original current test limits required')
        result['configSha256'] = file_hash(destination / 'config/stdout')
        for index, (coord, expected) in enumerate(sorted(cases.items())):
            recheck(snapshot)
            folder = destination / f'host-{index:03d}'
            executed = invoke(commands(forge, project, view, compiler, coord, list_only=list_only, verbosity=verbosity), folder, project, env, timeout)
            result['runs'][coord] = executed
            data = strict_json((folder / 'stdout').read_bytes())
            if list_only:
                validate_listing(data, coord, expected)
                require(executed['exitCode'] == 0, 'Cached Forge listing failed')
            else:
                counts = test_results(data, (tuple(coord.split(':')),), {coord: expected})
                for case in expected:
                    if not case.endswith('()') and not case.startswith('invariant_'):
                        require(data[coord]['test_results'][case].get('kind', {}).get('Fuzz', {}).get('runs', 0) >= 256,
                                f'Native ABI fuzz case lacks complete fuzz evidence: {coord}:{case}')
                executed['cases'] = counts
                require(executed['exitCode'] == 0 and counts['failed'] == 0 and counts['skipped'] == 0, 'Test suite failed or skipped')
            result['runs'][coord] = executed
            recheck(snapshot)
        result['status'] = 'PASS_CACHED_LIST_ONLY' if list_only else 'PASS_EXACT_TEST_ROSTER'
    except BaseException as exc:
        result['status'] = 'FAILED'; result['error'] = str(exc)
        raise
    finally:
        errors = []
        try:
            recheck(snapshot)
            require(file_hash(view_file) == expected_hash, 'Execution-view proof changed')
            require(all(file_hash(Path(p)) == digest for p, digest in tool_hashes.items()), 'Dispatch tool changed')
            require(not (destination / 'deny_compiler.attempts.jsonl').exists(), 'Forge attempted compilation')
        except (ValueError, OSError) as exc:
            errors.append(str(exc)); result['status'] = 'FAILED'
        result['integrityErrors'] = errors
        result['qualification'] = ('Only exact TEST entrypoints are dispatched. List-only does not execute EVM or prove getCode at runtime. '
                                   'No Forge script support; constructor/deployment/trace acceptance remains separate.')
        (destination / 'result.json').write_bytes(canonical(result))
        if errors:
            raise ValueError('; '.join(errors))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--view', required=True, type=Path)
    parser.add_argument('--view-sha256', required=True)
    parser.add_argument('--forge', required=True, type=Path)
    parser.add_argument('--forge-sha256', required=True)
    parser.add_argument('--destination', required=True, type=Path)
    parser.add_argument('--chain-id', type=int, required=True, help='Explicit pinned local chain ID; currently 31337 only')
    parser.add_argument('--profile', default='current')
    parser.add_argument('--timeout', type=int, default=600)
    parser.add_argument('--verbosity', type=int, choices=(0,3,4,5), default=0,
                        help='Explicit campaign trace verbosity; 4/5 retain successful test/setup traces')
    parser.add_argument('--execute', action='store_true', help='Run EVM tests; omission only lists exact cases')
    args = parser.parse_args()
    print(json.dumps(run(args.view, args.view_sha256, args.forge, args.forge_sha256, args.destination,
                         profile=args.profile, list_only=not args.execute, timeout=args.timeout, verbosity=args.verbosity, chain_id=args.chain_id)))


if __name__ == '__main__':
    main()
