"""Verify exact retained VIEW retrieval evidence and complete received media."""
import argparse
from hashlib import sha256
from pathlib import Path
import sys

from . import view_preservation_inventory_wire_v1 as original_inventory
from . import view_preservation_retrieval_types_v1 as types
from . import view_preservation_retrieval_wire_v1 as wire
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require
from .native_finality_wire import from_json

MAX_INPUT = 256 * 1024 * 1024
MAX_MEDIA = 16 * 1024 * 1024
MAX_MEDIA_TOTAL = 64 * 1024 * 1024
GRAPH_KEYS = original_inventory.GRAPH_KEYS
CLAIMS = {
    'completeOriginalPreservationProofChecked': True,
    'retrievalEnabledInventoryReconstructed': True,
    'immutableCompanionAndDedicatedItemBindingsChecked': True,
    'retainedWitnessPreimagesAndEventsChecked': True,
    'currentSourceArtistArchiveAndScopeEpochJoined': True,
    'completeReceivedMediaBytesChecked': True,
    'rpcProvenanceAuthenticated': False,
    'historicalSignatureReauthorized': False,
    'completeGlobalWitnessHistoryProven': False,
    'networkRetrievalPerformed': False,
    'manifestPathInterpretationProven': False,
    'currentLivenessVerified': False,
    'completeArchiveBundleChecked': False,
    'nativeExecutionProven': False,
    'browserExecutionProven': False,
    'finalityProven': False,
    'profileRegistered': False,
}
QUALIFICATION = (
    'Complete source and retrieval-enabled inventory inputs are replayed before the exact witness '
    'preimages, operative source/Artist/Archive observations, dedicated item bindings and received '
    'media bytes are joined. Every original route and manifest occurrence remains attributed '
    'evidence. Source observations are caller-admitted at the captured block; this is not network '
    'retrieval, historical signature reauthorization, full archive-bundle coverage, native execution '
    'or finality. Retained witness history is an explicit subset, not a global denominator.')
PROFILE_BYTES = dumps({
    'name': 'STREAM_MUSEUM_VIEW_ATTRIBUTED_RETRIEVAL_EVIDENCE_V1', 'version': '1',
    'sourceRevision': types.SOURCE_REVISION,
    'rootIntegrationRevision': types.ROOT_INTEGRATION_REVISION,
    'sourceBlobs': types.SOURCE_BLOBS,
    'witnessProfile': types.PROFILE, 'inventoryProfile': types.INVENTORY_PROFILE,
    'graphRoles': GRAPH_KEYS,
    'source': 'Complete original preservation proof and exact new retrieval-enabled inventory. '
        'No old inventory profile is relabeled, no generic Proof is used as a witness ID.',
    'media': 'Exactly one complete byte string for every operative retained witness, matching '
        'the original external object Keccak-256, SHA-256 and byte size.',
    'routes': 'Native URI/redirect/mirror/path rules and ordered admitted manifest bytes. '
        'Each Arweave root joins its own original first receipt and checkpoint.',
    'currentness': 'Complete Source including checkpoint context, locked full Artist presentation, '
        'actual original Archive pair/family observations, immutable witness/runtime and '
        'scope-keyed revocation epoch at the captured block.',
    'history': 'Retained records and revocations are checked as a subset. Historical expiry '
        'and source drift remain distinct from operative acceptance.',
    'bounds': {'inputBytes': str(MAX_INPUT), 'mediaBytes': str(MAX_MEDIA),
        'totalMediaBytes': str(MAX_MEDIA_TOTAL), 'witnessPayloadBytes': str(types.MAX_BYTES),
        'signatureBytes': str(types.MAX_SIGNATURE), 'uriBytes': str(types.MAX_URI),
        'routeSteps': str(types.MAX_STEPS)},
    'claims': CLAIMS, 'qualification': QUALIFICATION,
})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _verify(raw):
    value = loads(raw, maximum=MAX_INPUT, canonical=True)
    require(type(value) is dict and set(value) == {'profileHash', 'context', 'graph',
        'sourceProof', 'inventory', 'retrieval', 'materials'}, 'VIEW retrieval envelope shape')
    require(value['profileHash'] == PROFILE_HASH, 'VIEW retrieval consumer profile')
    graph = value['graph']
    require(type(graph) is dict and set(graph) == set(GRAPH_KEYS), 'VIEW retrieval exact graph roles')
    for row in graph.values():
        require(type(row) is dict and set(row) == {'address', 'runtimeHash'},
            'VIEW retrieval graph identity shape')
    result = wire.validate(value['retrieval'], value['context'], graph,
        value['inventory'], value['sourceProof'])
    provenance = value['retrieval']['sourceBindings']['provenance']
    require(provenance == value['inventory']['value']['recordedSource']['provenance']
        == value['inventory']['binding']['sourceBindings']['provenance'],
        'VIEW retrieval source provenance labels differ')
    resolved = {row['recordHash']: row for row in result['resolvedAdmissions']}
    require(len(resolved) == len(result['resolvedAdmissions']) > 0,
        'VIEW retrieval operative record denominator')
    materials = value['materials']
    require(type(materials) is list and len(materials) == len(resolved),
        'VIEW retrieval complete media denominator')
    seen, total, media_report = set(), 0, []
    for row in materials:
        require(type(row) is dict and set(row) == {'recordHash', 'mediaBytes'}
            and row['recordHash'] in resolved and row['recordHash'] not in seen,
            'VIEW retrieval material record identity')
        seen.add(row['recordHash'])
        encoded = row['mediaBytes']
        require(type(encoded) is str and len(encoded) <= 2 + 2 * MAX_MEDIA,
            'VIEW retrieval media byte bound')
        media = hex_bytes(encoded)
        total += len(media)
        require(total <= MAX_MEDIA_TOTAL, 'VIEW retrieval total media bound')
        admission = from_json(types.ADMISSION, resolved[row['recordHash']]['admission'])
        coverage = admission[3]
        require(admission[0][0] == 1 and 0 < len(media) == coverage[6]
            and keccak256(media) == coverage[3] and '0x' + sha256(media).hexdigest() == coverage[4],
            'VIEW retrieval complete media bytes differ')
        media_report.append({'recordHash': row['recordHash'], 'objectHash': coverage[1],
            'coverageHash': coverage[0], 'keccak256': coverage[3], 'sha256': coverage[4],
            'byteSize': str(len(media)), 'route': resolved[row['recordHash']]['route']})
    require(seen == set(resolved), 'VIEW retrieval missing operative media')
    calls = result['expectedCalls']
    summary = {key: val for key, val in result.items() if key not in ('expectedCalls', 'resolvedAdmissions')}
    summary['bindings'] = [{key: val for key, val in row.items() if key != 'calls'}
        for row in result['bindings']]
    return {'profileHash': PROFILE_HASH, 'inputHash': keccak256(raw),
        'sourceRevision': types.SOURCE_REVISION, 'sourceProvenance': provenance,
        'sourceProofHash': keccak256(dumps(value['sourceProof'])),
        'inventoryInputHash': keccak256(dumps(value['inventory'])),
        'retainedGetterCount': str(len(calls)), 'retainedGetterHash': keccak256(dumps(calls)),
        'retrieval': summary, 'media': media_report, 'claims': CLAIMS, 'qualification': QUALIFICATION}


def verify(raw):
    """Verify one closed canonical envelope without network access or execution."""
    try:
        return _verify(raw)
    except MuseumError:
        raise
    except (KeyError, IndexError, TypeError, ValueError, OverflowError, UnicodeError, RecursionError) as exc:
        raise MuseumError('malformed retained VIEW retrieval evidence') from exc


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('profiles')
    check = commands.add_parser('verify')
    check.add_argument('input', type=Path)
    args = parser.parse_args(argv)
    try:
        if args.command == 'profiles':
            result = {'profileHash': PROFILE_HASH, 'profile': loads(PROFILE_BYTES, maximum=len(PROFILE_BYTES))}
        else:
            with args.input.open('rb') as stream:
                raw = stream.read(MAX_INPUT + 1)
            require(len(raw) <= MAX_INPUT, 'VIEW retrieval input byte bound')
            result = verify(raw)
        print(dumps(result).decode('utf-8'))
        return 0
    except (MuseumError, OSError) as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
