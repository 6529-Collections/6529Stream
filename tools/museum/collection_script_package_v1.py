"""Offline collection script/dependency preservation from exact RPC outcomes.

The source reader owns native interpretation. This package retains its exact
inputs and independently supplied runtime bridge, then reconstructs every output
byte during verification. It never fetches a URI or executes JavaScript.
"""
import argparse
from pathlib import Path

from . import script_dependency_rpc_v1 as rpc
from .bagit import read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require
from .object_dossier import Assembly, _bounded, _ref
from .repository_exchange import _publish

PROFILE = 'STREAM_MUSEUM_COLLECTION_SCRIPT_PACKAGE_V1'
MAX_ANCHOR = 65536
MAX_BRIDGE = 16 * 1024 * 1024
MAX_SNAPSHOT = 32 * 1024 * 1024
CLAIMS = {'originalInputsRetained': True, 'nativeSourceReplayed': True,
    'unavailableOutcomesPreserved': True, 'runtimeBridgeContentsVerified': False,
    'sourceOriginAuthenticated': False, 'consensusVerified': False,
    'historicalSelectionsComplete': False, 'javascriptExecuted': False,
    'uriResourcesRetrieved': False, 'physicalStorageCarriersProven': False,
    'completeObjectDossier': False, 'institutionalAcceptance': False, 'networkFetch': False}
QUALIFICATION = ('A finite collection script/dependency observation at one externally pinned block. '
    'Current manifest selection, raw saved bundle selection, inline source and original versioned '
    'dependency reads retain distinct meanings. Unavailable calls are not absence or native rejection. '
    'The retained runtime bridge is an externally admitted artifact whose contents are not verified '
    'by this package. Replay verifies internal correspondence, not provider origin, consensus, '
    'complete history, JavaScript execution, URI delivery, physical storage carriers, a complete '
    'object dossier or institutional acceptance.')
PROFILE_BYTES = dumps({'name': PROFILE, 'version': '1',
    'retention': 'Exact anchor, ordered transcript and opaque external runtime bridge below source/. '
        'Exact source, wire and transport profiles below definitions/.',
    'verification': 'Native source replay, full transcript consumption and byte-for-byte package reconstruction.',
    'bounds': {'anchorBytes': str(MAX_ANCHOR), 'runtimeBridgeBytes': str(MAX_BRIDGE),
        'transcriptBytes': str(rpc.MAX_TRANSCRIPT), 'snapshotBytes': str(MAX_SNAPSHOT)},
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _input(raw, digest, maximum, label):
    require(type(raw) is bytes and 0 < len(raw) <= maximum,
        'collection script ' + label + ' byte bound')
    require(keccak256(raw) == digest, 'collection script ' + label + ' external commitment differs')


def _payloads(snapshot):
    files, rows = {}, []
    for index, occurrence in enumerate(snapshot['interpretations']):
        basis = occurrence['basis']
        require(basis in ('current_manifest', 'raw_saved_bundle'),
            'collection script interpretation basis')
        report = occurrence['report']
        row = {key: occurrence[key] for key in ('basis', 'host', 'manifestHash')}
        row['wireCompleteness'] = {key: report[key] for key in
            ('completeScriptBytes', 'completeDependencyBytes')}
        for role in ('script', 'dependency'):
            payload = report[role].get('payloadHex')
            row[role] = None
            if payload is not None:
                require(report[role]['payloadStatus'] == 'complete',
                    'collection script incomplete payload projection')
                path = 'payloads/' + str(index).zfill(3) + '-' + basis + '/' + role + '.bin'
                files[path] = hex_bytes(payload)
                row[role] = _ref(path, files[path])
        rows.append(row)
    return files, rows


def _assemble(anchor_raw, anchor_hash, transcript_raw, transcript_hash,
        runtime_bridge_raw, runtime_bridge_hash, *, provenance, disclosure):
    require(disclosure == 'public', 'collection script public disclosure required before reads')
    _input(anchor_raw, anchor_hash, MAX_ANCHOR, 'anchor')
    _input(transcript_raw, transcript_hash, rpc.MAX_TRANSCRIPT, 'transcript')
    _input(runtime_bridge_raw, runtime_bridge_hash, MAX_BRIDGE, 'runtime bridge')
    # Disclosure and byte bounds precede source or runtime interpretation.
    from . import collection_script_source_v1 as native
    from . import collection_script_wire_v1 as wire
    anchor = loads(anchor_raw, maximum=MAX_ANCHOR, canonical=True)
    require(anchor['runtimeAdmission']['artifactHash'] == runtime_bridge_hash,
        'collection script retained runtime bridge differs from admission')
    transport = rpc.ReplayTransport(transcript_raw, transcript_hash)
    source = native.CollectionScriptSource(anchor_raw, transport, provenance=provenance)
    snapshot_raw = source.snapshot()
    transport.finish()
    require(source.transcript() == transcript_raw, 'collection script original transcript differs')
    snapshot = loads(snapshot_raw, maximum=MAX_SNAPSHOT, canonical=True)
    payload_files, payload_rows = _payloads(snapshot)
    inputs = {'anchorHash': anchor_hash, 'transcriptHash': transcript_hash,
        'runtimeBridgeHash': runtime_bridge_hash, 'sourceProfileHash': native.PROFILE_HASH,
        'wireProfileHash': wire.PROFILE_HASH, 'transportProfileHash': rpc.PROFILE_HASH,
        'provenance': provenance, 'disclosure': disclosure}
    report = {'profile': PROFILE, 'profileHash': PROFILE_HASH, 'inputs': inputs,
        'sourceSnapshot': _ref('source/snapshot.json', snapshot_raw),
        'sourceState': {key: anchor[key] for key in native.COMMON},
        'availability': snapshot['availability'], 'payloads': payload_rows,
        'claims': CLAIMS, 'qualification': QUALIFICATION}
    files = {'source/anchor.json': anchor_raw, 'source/transcript.json': transcript_raw,
        'source/runtime-bridge.bin': runtime_bridge_raw, 'source/snapshot.json': snapshot_raw,
        'definitions/package-profile.json': PROFILE_BYTES,
        'definitions/source-profile.json': native.PROFILE_BYTES,
        'definitions/wire-profile.json': wire.PROFILE_BYTES,
        'definitions/transport-profile.json': rpc.PROFILE_BYTES,
        'report.json': dumps(report)}
    files.update(payload_files)
    _bounded(files)
    manifest = dumps({'profile': PROFILE, 'profileHash': PROFILE_HASH, 'inputs': inputs,
        'files': [_ref(path, raw) for path, raw in sorted(files.items())],
        'claims': CLAIMS, 'qualification': QUALIFICATION})
    files['manifest.json'] = manifest
    _bounded(files)
    return Assembly(tuple(sorted(files.items())), manifest, report)


def assemble(anchor_raw, anchor_hash, transcript_raw, transcript_hash,
        runtime_bridge_raw, runtime_bridge_hash, *, provenance, disclosure):
    try:
        return _assemble(anchor_raw, anchor_hash, transcript_raw, transcript_hash,
            runtime_bridge_raw, runtime_bridge_hash, provenance=provenance, disclosure=disclosure)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed collection script package') from exc


def verify(files, expected_hash):
    try:
        _bounded(files)
        require(keccak256(files['manifest.json']) == expected_hash,
            'collection script external manifest commitment differs')
        manifest = loads(files['manifest.json'], maximum=1048576, canonical=True)
        inputs = manifest['inputs']
        result = assemble(files['source/anchor.json'], inputs['anchorHash'],
            files['source/transcript.json'], inputs['transcriptHash'],
            files['source/runtime-bridge.bin'], inputs['runtimeBridgeHash'],
            provenance=inputs['provenance'], disclosure=inputs['disclosure'])
        require(dict(result.files) == files, 'collection script deterministic reconstruction differs')
        return result
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed collection script package') from exc


def _read(path, maximum):
    path = Path(path)
    require(path.stat().st_size <= maximum, 'collection script input file bound')
    with path.open('rb') as handle:
        raw = handle.read(maximum + 1)
    require(len(raw) <= maximum, 'collection script input file grew past bound')
    return raw


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    build = commands.add_parser('assemble')
    for name in ('anchor', 'transcript', 'runtime-bridge', 'output'):
        build.add_argument('--' + name, type=Path, required=True)
    for name in ('anchor-hash', 'transcript-hash', 'runtime-bridge-hash'):
        build.add_argument('--' + name, required=True)
    build.add_argument('--provenance', choices=('synthetic_fixture', 'trusted_rpc'), required=True)
    build.add_argument('--disclosure', choices=('public',), required=True)
    check = commands.add_parser('verify')
    check.add_argument('directory', type=Path)
    check.add_argument('--manifest-hash', required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == 'assemble':
            result = assemble(_read(args.anchor, MAX_ANCHOR), args.anchor_hash,
                _read(args.transcript, rpc.MAX_TRANSCRIPT), args.transcript_hash,
                _read(args.runtime_bridge, MAX_BRIDGE), args.runtime_bridge_hash,
                provenance=args.provenance, disclosure=args.disclosure)
            _publish(dict(result.files), args.output, [args.anchor, args.transcript, args.runtime_bridge])
        else:
            result = verify(read_tree(args.directory), args.manifest_hash)
        print(dumps({'manifestHash': result.manifest_hash, 'report': result.report}).decode('utf-8'))
    except (MuseumError, OSError) as exc:
        parser.exit(2, 'collection script package: ' + str(exc) + '\n')


if __name__ == '__main__':
    main()
