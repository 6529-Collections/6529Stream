"""Replay complete finite genesis registration coverage from original RPC bytes.

No registrations, network reads or old-package rewrites occur here. The native
source reader owns graph/definition checks. This wrapper retains the frozen
intended plan and the independently pinned original source inputs together.
"""
import argparse
from pathlib import Path

from . import genesis_registry_plan_v1 as plan
from .bagit import read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require
from .object_dossier import Assembly, _bounded, _ref
from .public_history_rpc import PublicReplayTransport
from .repository_exchange import _publish

PROFILE = 'STREAM_MUSEUM_GENESIS_REGISTRY_COVERAGE_V1'
CLAIMS = {'originalInputsRetained': True, 'completeFixedPlanReplayed': True,
    'registrationPerformed': False, 'globalRegistryInventory': False,
    'governanceExecutionVerified': False, 'sourceOriginAuthenticated': False,
    'completeObjectDossier': False, 'semanticConformance': False,
    'institutionalAcceptance': False, 'networkFetch': False}
QUALIFICATION = ('Coverage of the exact frozen 29-schema/22-support registration plan at one '
    'externally pinned Core state. Absent, conflicting and retired definitions remain explicit. '
    'Matching bytes do not prove governance execution, semantic conformance, release readiness, '
    'global Registry completeness, consensus or institutional acceptance. Provenance is an '
    'explicit caller admission; retained RPC responses do not authenticate their origin.')
PROFILE_BYTES = dumps({'name': PROFILE, 'version': '1', 'planProfileHash': plan.PROFILE_HASH,
    'retention': 'Unchanged fixed plan package below plan/; original source anchor and transcript below source/.',
    'verification': 'Concrete native reader replay and deterministic reconstruction of every output byte.',
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _assemble(plan_files, plan_hash, anchor_raw, anchor_hash, transcript_raw, transcript_hash,
        *, provenance, disclosure):
    require(disclosure == 'public', 'genesis coverage public disclosure required before reads')
    from .genesis_registry_source_v1 import GenesisRegistrySource, PROFILE_BYTES as SOURCE_PROFILE
    intended = plan.admit(plan_files, plan_hash)
    require(type(anchor_raw) is bytes and len(anchor_raw) <= 65536
        and type(transcript_raw) is bytes and len(transcript_raw) <= 64 * 1024 * 1024,
        'genesis coverage original source byte bound')
    require(keccak256(anchor_raw) == anchor_hash and keccak256(transcript_raw) == transcript_hash,
        'genesis coverage original source commitment differs')
    transport = PublicReplayTransport(transcript_raw, transcript_hash)
    source = GenesisRegistrySource(anchor_raw, transport, plan_files=dict(intended.files),
        plan_hash=intended.manifest_hash, provenance=provenance)
    snapshot_raw = source.snapshot()
    transport.finish()
    require(source.transcript() == transcript_raw, 'genesis coverage original transcript differs')
    snapshot = loads(snapshot_raw, maximum=64 * 1024 * 1024, canonical=True)
    inputs = {'planManifestHash': plan_hash, 'anchorHash': anchor_hash,
        'transcriptHash': transcript_hash, 'provenance': provenance, 'disclosure': disclosure}
    report = {'profile': PROFILE, 'profileHash': PROFILE_HASH, 'inputs': inputs,
        'nativeSource': snapshot, 'claims': CLAIMS, 'qualification': QUALIFICATION}
    files = {'plan/' + path: raw for path, raw in intended.files}
    files.update({'source/anchor.json': anchor_raw, 'source/transcript.json': transcript_raw,
        'source/snapshot.json': snapshot_raw, 'definitions/coverage-profile.json': PROFILE_BYTES,
        'definitions/source-profile.json': SOURCE_PROFILE, 'report.json': dumps(report)})
    _bounded(files)
    manifest = dumps({'profile': PROFILE, 'profileHash': PROFILE_HASH, 'inputs': inputs,
        'files': [_ref(path, raw) for path, raw in sorted(files.items())],
        'claims': CLAIMS, 'qualification': QUALIFICATION})
    files['manifest.json'] = manifest
    _bounded(files)
    return Assembly(tuple(sorted(files.items())), manifest, report)


def assemble(plan_files, plan_hash, anchor_raw, anchor_hash, transcript_raw, transcript_hash,
        *, provenance, disclosure):
    try:
        return _assemble(plan_files, plan_hash, anchor_raw, anchor_hash, transcript_raw,
            transcript_hash, provenance=provenance, disclosure=disclosure)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed genesis registry coverage') from exc


def verify(files, expected_hash):
    try:
        _bounded(files)
        require(keccak256(files['manifest.json']) == expected_hash,
            'genesis coverage external manifest commitment differs')
        manifest = loads(files['manifest.json'], maximum=1048576, canonical=True)
        inputs = manifest['inputs']
        intended = {path.removeprefix('plan/'): raw for path, raw in files.items() if path.startswith('plan/')}
        result = assemble(intended, inputs['planManifestHash'], files['source/anchor.json'], inputs['anchorHash'],
            files['source/transcript.json'], inputs['transcriptHash'], provenance=inputs['provenance'],
            disclosure=inputs['disclosure'])
        require(dict(result.files) == files, 'genesis coverage deterministic reconstruction differs')
        return result
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed genesis registry coverage package') from exc


def observation(files, expected_hash):
    """Concrete verified RPC observation for the existing canonical source join.

    The Registry has no token scope. Missing token/collection fields remain
    absent here; the canonical join compares its actual common anchor fields.
    """
    result = verify(files, expected_hash)
    originals = dict(result.files)
    transcript = loads(originals['source/transcript.json'], maximum=64 * 1024 * 1024, canonical=True)
    pins = {row['params'][0]: keccak256(hex_bytes(row['result']))
        for row in transcript['calls'] if row['method'] == 'eth_getCode'}
    return {'kind': 'rpc', 'name': 'genesis-registry-v1',
        'anchor': loads(originals['source/anchor.json'], maximum=65536, canonical=True),
        'transcript': transcript, 'runtimePins': pins,
        'provenance': result.report['inputs']['provenance']}


def _read(path, maximum):
    path = Path(path)
    require(path.stat().st_size <= maximum, 'genesis coverage input file bound')
    with path.open('rb') as file:
        raw = file.read(maximum + 1)
    require(len(raw) <= maximum, 'genesis coverage input file grew past bound')
    return raw


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    prepare = commands.add_parser('prepare-plan')
    prepare.add_argument('--output', type=Path, required=True)
    build = commands.add_parser('assemble')
    for name in ('plan', 'anchor', 'transcript', 'output'):
        build.add_argument('--' + name, type=Path, required=True)
    for name in ('plan-hash', 'anchor-hash', 'transcript-hash'):
        build.add_argument('--' + name, required=True)
    build.add_argument('--provenance', choices=('synthetic_fixture', 'trusted_rpc'), required=True)
    build.add_argument('--disclosure', choices=('public',), required=True)
    check = commands.add_parser('verify')
    check.add_argument('directory', type=Path)
    check.add_argument('--manifest-hash', required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == 'prepare-plan':
            result = plan.prepare()
            _publish(dict(result.files), args.output, [])
        elif args.command == 'assemble':
            result = assemble(read_tree(args.plan), args.plan_hash, _read(args.anchor, 65536), args.anchor_hash,
                _read(args.transcript, 64 * 1024 * 1024), args.transcript_hash,
                provenance=args.provenance, disclosure=args.disclosure)
            _publish(dict(result.files), args.output, [args.plan, args.anchor, args.transcript])
        else:
            result = verify(read_tree(args.directory), args.manifest_hash)
        summary = result.report
        if 'nativeSource' in summary:
            summary = {'profile': PROFILE, 'inputs': summary['inputs'],
                'coverage': summary['nativeSource']['coverage'],
                'claims': CLAIMS, 'qualification': QUALIFICATION}
        print(dumps({'manifestHash': result.manifest_hash, 'report': summary}).decode('utf-8'))
    except (MuseumError, OSError) as exc:
        parser.exit(2, 'genesis registry coverage: ' + str(exc) + '\n')


if __name__ == '__main__':
    main()
