"""Check retained exact VIEW locator/Archive correspondence and media bytes offline."""
import argparse
from hashlib import sha256
from pathlib import Path
import sys

from . import native_view_preservation_wire_v1 as preservation
from . import view_policy_adoption_types_v2 as adoption
from . import view_preservation_bundle_wire_v1 as archive
from . import view_preservation_inventory_types_v1 as types
from . import view_preservation_locator_wire_v1 as wire
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .chain_abi import decode, encode
from .independent_wire import json_values, require

MAX_INPUT = 128 * 1024 * 1024
MAX_SOURCE = 64 * 1024 * 1024
MAX_MEDIA = 16 * 1024 * 1024
GRAPH_KEYS = tuple(dict.fromkeys((*preservation.GRAPH_KEYS, *archive.DEPENDENCY_ROLES)))
CLAIMS = {
    'completeOriginalPreservationProofChecked': True,
    'adoptedImageURIAndSourceRecordChecked': True,
    'originalArchiveAdmissionPreimagesChecked': True,
    'exactSamePairLocatorChecked': True,
    'completeMediaBytesChecked': True,
    'rpcProvenanceAuthenticated': False,
    'historicalSignaturesVerified': False,
    'historicalAuthorityReauthorized': False,
    'archiveConsensusVerified': False,
    'currentLivenessVerified': False,
    'nativeExecutionProven': False,
    'completeRenderCriticalInventoryChecked': False,
    'browserExecutionProven': False,
    'finalityProven': False,
}
PROFILE_BYTES = dumps({
    'name': 'STREAM_MUSEUM_VIEW_EXACT_LOCATOR_CORRESPONDENCE_V1', 'version': '1',
    'locatorSourceRevision': wire.SOURCE_REVISION, 'locatorSourceBlobs': wire.SOURCE_BLOBS,
    'preservationSourceRevision': preservation.SOURCE_REVISION,
    'originalArchiveConsumerRevision': archive.SOURCE_REVISION,
    'graphRoles': GRAPH_KEYS,
    'source': 'Complete original adoption, membership, output commitments, snapshot, root and events. '
        'The image URI and declaration record are derived from the selected adopted payload. '
        'Retained source carriers, policies, Registry targets and Archive dependencies share one runtime map.',
    'locator': 'Exact institutional HTTPS receipt or canonical ar:// transaction receipt, '
        'using the original same-pair external Archive admission. The URI is never a file digest.',
    'media': 'Complete supplied bytes must match original object Keccak, SHA256 and nonzero size.',
    'trust': 'Supplied retained native observations only; originals do not authenticate their own '
        'RPC provenance, signatures, historical writer authority or current receipt-pair eligibility.',
    'exclusions': ['origin-to-mirror resolution', 'redirects', 'Arweave subpaths',
        'general retrieval witnesses', 'sanction catalog registration', 'full inventory acceptance'],
    'bounds': {'inputBytes': str(MAX_INPUT), 'sourceProofBytes': str(MAX_SOURCE),
        'mediaBytes': str(MAX_MEDIA), 'archiveOriginalBytes': str(archive.MAX_TOTAL),
        'gasPerSourceRead': str(archive.MAX_GAS)},
    'claims': CLAIMS,
})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def verify(raw):
    """Accept one closed canonical envelope; never fetch a URI or execute code."""
    try:
        return _verify(raw)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, StopIteration, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed retained VIEW locator evidence') from exc


def _source_pins(bundle, checked, originals):
    """Join independently validated source groups to the Archive runtime map."""
    pending = [bundle]
    while pending:
        value = pending.pop()
        if type(value) is dict:
            if 'pointer' in value and 'runtime' in value:
                digest = keccak256(hex_bytes(value['runtime']))
                require('codeHash' not in value or value['codeHash'] == digest,
                    'VIEW locator source carrier runtime differs')
                originals.pin(value['pointer'], digest)
            pending.extend(value.values())
        elif type(value) is list:
            pending.extend(value)
    for policy in checked['membership']['policies']:
        originals.pin(policy[0], policy[1])
    for target in checked['adoption']['preservation']['registry']['targets']:
        originals.pin(target[0], target[1])


def _verify(raw):
    value = loads(raw, maximum=MAX_INPUT, canonical=True)
    archive._closed(value, ('profileHash', 'context', 'graph', 'sourceProof', 'dependencies',
        'item', 'admission', 'sourceEvidence', 'sourceBindings', 'mediaBytes'), 'locator envelope')
    require(value['profileHash'] == PROFILE_HASH, 'VIEW locator consumer profile')
    context, graph = value['context'], value['graph']
    require(type(graph) is dict and set(graph) == set(GRAPH_KEYS), 'VIEW locator exact graph roles')
    for row in graph.values():
        archive._closed(row, ('address', 'runtimeHash'), 'locator graph pin')
    originals = archive._Originals(context, graph)
    dependencies = archive._v(types.BUNDLE_DEPENDENCIES, value['dependencies'])
    encode((types.BUNDLE_DEPENDENCIES,), (dependencies,))
    require(dependencies[0] == tuple(graph[role]['address'] for role in archive.DEPENDENCY_ROLES)
        and dependencies[1] == tuple(graph[role]['runtimeHash'] for role in archive.DEPENDENCY_ROLES)
        and dependencies[2] == uint(context['chainId'])
        and 50000 <= dependencies[3] <= dependencies[4] <= archive.MAX_GAS,
        'VIEW locator original dependencies and gas bounds')
    proof = value['sourceProof']
    archive._closed(proof, ('bundle', 'events'), 'locator original preservation proof')
    require(len(dumps(proof)) <= MAX_SOURCE, 'VIEW locator complete source byte bound')
    source_graph = {role: graph[role] for role in preservation.GRAPH_KEYS}
    source = preservation.validate_bundle(proof['bundle'], context, source_graph)
    preservation.validate_event_join(proof['bundle'], context, source_graph, proof['events'])
    _source_pins(proof['bundle'], source, originals)
    adopted = proof['bundle']['adoption']
    chosen = next(row for row in adopted['history'] if row['record'][3] == adopted['selectedRecordHash'])
    record = archive._v(adoption.RECORD, chosen['record'])
    payload = decode((adoption.PAYLOAD,), hex_bytes(chosen['declaration']['viewPayload']),
        maximum=adoption.MAX_PAYLOAD)[0]
    expected = wire.media(record[1][0][16][0], record[0][2], payload[3])
    item = archive._v(types.ITEM, value['item'])
    require(expected[1] == wire.LOCATOR_ROLE and item == expected,
        'VIEW locator item must derive from the original adopted image URI')
    artist = source['snapshot']['source'][2][3]
    admission = archive._v(types.ADMISSION, value['admission'])
    result = wire.validate_admission(item, admission, value['sourceEvidence'], dependencies, artist, originals)
    obj = archive._v(archive.OBJECT, value['sourceEvidence']['object'])
    require(type(value['mediaBytes']) is str and len(value['mediaBytes']) <= MAX_MEDIA * 2 + 2,
        'VIEW locator media byte bound')
    media = hex_bytes(value['mediaBytes'])
    require(0 < len(media) == obj[6] and keccak256(media) == obj[3]
        and '0x' + sha256(media).hexdigest() == obj[4], 'VIEW locator complete media bytes differ')
    bindings = value['sourceBindings']
    archive._closed(bindings, ('blockHash', 'provenance', 'calls'), 'locator original dependency reads')
    require(bindings['blockHash'] == context['blockHash']
        and bindings['provenance'] in ('synthetic_fixture', 'externally_admitted_rpc')
        and bindings['calls'] == originals.calls, 'VIEW locator exact retained dependency getter evidence')
    return json_values({
        'profileHash': PROFILE_HASH, 'inputHash': keccak256(raw),
        'sourceRevision': wire.SOURCE_REVISION, 'scope': proof['bundle']['scope'],
        'adoptionRecordHash': adopted['selectedRecordHash'], 'sourceRecordHash': record[0][2],
        'snapshotRecordHash': proof['bundle']['snapshot']['selectedRecordHash'],
        'rootRecordHash': proof['bundle']['root']['selectedRecordHash'],
        'itemHash': archive.item_hash(item), 'uri': item[8], 'locator': result,
        'media': {'keccak256': obj[3], 'sha256': obj[4], 'byteSize': str(obj[6])},
        'dependencyHash': archive._hash((types.BUNDLE_DEPENDENCIES,), (dependencies,)),
        'sourceProvenance': bindings['provenance'], 'claims': CLAIMS,
        'qualification': 'Original adopted locator, same-pair Archive commitments and supplied media '
            'bytes correspond. Source and coverage observations remain externally admitted; no '
            'current availability, historical signature authority, general retrieval or finality is proven.',
    })


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
            require(len(raw) <= MAX_INPUT, 'VIEW locator input byte bound')
            result = verify(raw)
        print(dumps(result).decode('utf-8'))
        return 0
    except (MuseumError, OSError) as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
