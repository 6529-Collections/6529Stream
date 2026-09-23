"""Complete synthetic VIEW originals for exact HTTPS/Arweave locator joins.

No renderer, archive verifier, signature recovery, node or native contract runs
here. Source histories and signed observations are synthetic retained inputs;
the new consumer must independently recheck every commitment.
"""
from copy import deepcopy
from hashlib import sha256
import base64

from .canonical import dumps, hex_bytes, keccak256 as K, schema_id as D
from .chain_abi import encode, decode
from .independent_wire import ZERO as Z, generic_hash, json_values
from .native_finality_wire import from_json
from . import native_view_preservation_wire_v1 as preservation
from . import view_policy_adoption_types_v2 as at
from . import view_preservation_adoption_wire_v1 as adoption
from . import view_policy_membership_v2 as membership
from . import view_preservation_bundle_wire_v1 as archive
from . import view_preservation_inventory_types_v1 as inventory_types
from .view_preservation_inventory_fixture_v1 import reference_inputs, _source_events
from .test_view_preservation_adoption_wire_v1 import _bind_original_registry
from .test_view_preservation_output_wire_v1 import reseal as seal_output
from .test_view_preservation_snapshot_wire_v1 import supplied as snapshot
from .test_view_preservation_root_wire_v1 import supplied as root
from .test_view_preservation_bundle_wire_v1 import checkpoint, zero


MEDIA_BYTES = b'original synthetic locator media bytes; not a renderer execution'
HTTPS_URI = 'https://example.invalid/master.png'
AR_TRANSACTION = D('synthetic VIEW locator transaction')
AR_URI = 'ar://' + base64.urlsafe_b64encode(hex_bytes(AR_TRANSACTION)).decode().rstrip('=')


def H(label): return D('synthetic VIEW locator ' + label)
def A(number): return '0x' + format(number, '040x')
def _hash(types, values): return K(encode(types, values))


def _replace_uri(row, context, graph, uri):
    declaration = row['declaration']; record = row['record']; source = record[1]
    payload = list(decode((at.PAYLOAD,), hex_bytes(declaration['viewPayload']))[0]); payload[3] = uri
    raw = encode((at.PAYLOAD,), (tuple(payload),))
    declaration['viewPayload'] = '0x' + raw.hex(); declaration['manifest'][3] = K(raw)
    manifest = encode(('uint256', 'uint64', 'bytes32', at.VIEW_MANIFEST),
        (int(context['collectionId']), int(declaration['receipt'][2]), declaration['receipt'][3],
         from_json(at.VIEW_MANIFEST, declaration['manifest'])))
    declaration['manifestPayload'] = '0x' + manifest.hex()
    declaration['manifestCarrier'].update(runtime='0x' + (b'\0' + manifest).hex(), codeHash=K(b'\0' + manifest))
    declaration['record'][2][1] = K(manifest)
    record[0][2] = generic_hash(int(context['chainId']), graph['views']['address'], context['core'],
        int(context['collectionId']), declaration['receipt'][4], from_json(at.COLLECTION_RECORD, declaration['record']))
    source[6], source[8], source[9] = K(manifest), K(raw), str(len(raw))
    parts = [raw[index:index+8192] for index in range(0, len(raw), 8192)]
    assert len(parts) == len(declaration['payloadChunks'])
    for index, (part, carrier) in enumerate(zip(parts, declaration['payloadChunks'])):
        carrier.update(runtime='0x' + (b'\0' + part).hex(), codeHash=K(b'\0' + part))
        source[11][index] = K(part)


def source_proof(uri=HTTPS_URI, *, count=1, mode='disabled', burned=False):
    """Reseal actual original payload→adoption→output→snapshot→root→events."""
    value, context, complete_graph, _, _, _, _ = reference_inputs(count, mode, burned)
    bundle = value['history'][0]['sourceProof']['bundle']
    graph = {key: complete_graph[key] for key in dict.fromkeys((*preservation.GRAPH_KEYS, *archive.DEPENDENCY_ROLES))}
    native_graph = {key: graph[key] for key in preservation.GRAPH_KEYS}
    adopted = bundle['adoption']
    for row in adopted['history']:
        if row['profile'] == at.V2_PROFILE: _replace_uri(row, context, graph, uri)
    registry = adopted['preservation']['registry']
    _bind_original_registry(adopted, context, native_graph, registry['version'][4], registry['version'][5])
    admitted = adoption.validate(adopted, context, native_graph)
    members = membership.validate(bundle['membership'], context, native_graph, admitted['policyBinding'])
    admitted.update(tokenIds=members['tokenIds'], policies=members['policies'])
    for row in bundle['output']['checkpoint']['outputs']:
        raw = dumps({'name': 'Original synthetic token ' + row[1], 'image': uri})
        row[8], row[10] = K(raw), str(len(raw))
    seal_output(bundle['output'], context, native_graph, admitted, coverage_timestamp=106)
    bundle['snapshot'], _, _ = snapshot(context=context, graph=native_graph, output_value=bundle['output'],
        adoption=admitted, membership=members, recorded_at=107)
    bundle['root'], *_ = root(context=context, graph=native_graph, snapshot_value=bundle['snapshot'],
        output_value=bundle['output'], published_at=109)
    events = _source_events(bundle, context, graph)
    result = preservation.validate_bundle(bundle, context, native_graph)
    preservation.validate_event_join(bundle, context, native_graph, events)
    return {'bundle': bundle, 'events': events}, context, graph, result


def bind_archive(value, *, receipt_uri=None, transaction_id=None):
    """Replace complete original pair before validation, including all hashes.

    A different receipt_uri yields a valid generic archival pair for another
    locator, useful for proving that locator correspondence adds a real check.
    """
    from . import view_preservation_locator_wire_v1 as locator
    context, graph = value['context'], value['graph']
    item = from_json(inventory_types.ITEM, value['item']); uri = item[8]
    kind, tx = locator.locator(uri)
    transaction_id = transaction_id or (tx if kind == 2 else AR_TRANSACTION)
    proof = value['sourceProof']['bundle']
    selected = next(row for row in proof['snapshot']['history'] if row['receipt'][0] == proof['snapshot']['selectedRecordHash'])
    artist = selected['source'][2][3]
    raw = hex_bytes(value['mediaBytes']); digest = '0x' + sha256(raw).hexdigest()
    host = graph['externalCoverage']['address']; chain = int(context['chainId'])
    obj = (artist, H('media schema'), D('RAW_BYTES'), K(raw), digest, H('Arweave data root'),
        len(raw), H('media format'), H('format catalogue'), H('format catalogue bytes'))
    object_key = archive.external_object_hash(obj, chain, host, context['core'])
    families = (H('endowed original family'), H('institutional original family'))
    native_key = H('native checkpoint ' + object_key)
    receipts, fixities, rkeys, fkeys, hashes = [], [], [], [], []
    receipt_uri = receipt_uri if receipt_uri is not None else (uri if kind == 1 else HTTPS_URI)
    locators = (hex_bytes(transaction_id), receipt_uri.encode('utf-8'))
    for index, (family, location) in enumerate(zip(families, locators)):
        record = (object_key, family, K(location), D('CONTENT_ADDRESSED_INCLUSION' if index == 0 else 'ATTESTED_POSSESSION'),
            H('proof profile'), native_key if index == 0 else H('institutional proof'),
            A(89000 + index), 110, index, 200)
        key = archive._domain('6529STREAM_EXTERNAL_RECEIPT_V1', ('uint256', 'address', archive.RECEIPT),
            (chain, host, record)); rkeys.append(key)
        raw_record = encode((archive.RECEIPT, 'bytes', 'bytes'), (record, location, b'synthetic original signature'))
        receipts.append('0x' + raw_record.hex()); hashes.append(_hash(('bytes32', 'bytes'), (key, raw_record)))
        fixity = (key, object_key, family, K(location), H('fixity profile'), digest, digest, obj[3], obj[3],
            obj[5], obj[5], obj[6], obj[6], 111, 1, H('fixity report'), Z, Z, A(89100 + index), index, 200)
        key = archive._domain('6529STREAM_EXTERNAL_FIXITY_V1', ('uint256', 'address', archive.EXTERNAL_FIXITY),
            (chain, host, fixity)); fkeys.append(key)
        fixities.append('0x' + encode((archive.EXTERNAL_FIXITY, 'bytes'), (fixity, b'synthetic fixity signature')).hex())
    for key, body in zip(fkeys, fixities): hashes.append(_hash(('bytes32', 'bytes'), (key, hex_bytes(body))))
    native, native_hash = checkpoint(native_key, True, transaction_id=transaction_id,
        data_root=obj[5], data_size=obj[6], payload_digest=digest, content_hash=obj[3])
    hashes.append(native_hash)
    coverage = (Z, object_key, artist, *obj[3:7], *families, *rkeys, *fkeys,
        native_key, D('STREAM_EXTERNAL_ARTIFACT_COVERAGE_V1'))
    coverage = (archive.external_coverage_hash(coverage, chain, host), *coverage[1:])
    commitment = _hash(('address', 'bytes32', inventory_types.ADMISSION[3], ('bytes32',) * 5),
        (host, graph['externalCoverage']['runtimeHash'], coverage, tuple(hashes)))
    value['admission'] = json_values(((1, coverage[0], object_key), commitment, Z, coverage, zero(inventory_types.ADMISSION[4])))
    value['sourceEvidence'] = {'object': json_values(obj), 'receipts': receipts, 'fixities': fixities, 'checkpoint': native}
    originals = archive._Originals(context, graph)
    # The getter evidence is derived by the unchanged generic original reader.
    materialized = list(item); materialized[5] = 1; materialized[7] = hex_bytes(obj[3]); materialized[9] = obj[6]
    archive._admission(tuple(materialized), from_json(inventory_types.ADMISSION, value['admission']),
        value['sourceEvidence'], from_json(inventory_types.BUNDLE_DEPENDENCIES, value['dependencies']), artist, originals)
    value['sourceBindings'] = {'blockHash': context['blockHash'], 'provenance': 'synthetic_fixture', 'calls': originals.calls}
    return value


def supplied(uri=HTTPS_URI, *, count=1, mode='disabled', burned=False):
    from . import view_preservation_locator_v1 as consumer
    from . import view_preservation_locator_wire_v1 as locator
    proof, context, graph, _ = source_proof(uri, count=count, mode=mode, burned=burned)
    adopted = proof['bundle']['adoption']
    selected = next(row for row in adopted['history'] if row['record'][3] == adopted['selectedRecordHash'])
    dependencies = (tuple(graph[key]['address'] for key in archive.DEPENDENCY_ROLES),
        tuple(graph[key]['runtimeHash'] for key in archive.DEPENDENCY_ROLES), int(context['chainId']), 100000, 8000000)
    value = {'profileHash': consumer.PROFILE_HASH, 'context': context, 'graph': graph,
        'sourceProof': proof, 'dependencies': json_values(dependencies),
        'item': json_values(locator.media(graph['views']['address'], selected['record'][0][2], uri)),
        'mediaBytes': '0x' + MEDIA_BYTES.hex(), 'admission': None, 'sourceEvidence': None, 'sourceBindings': None}
    bind_archive(value)
    consumer.verify(dumps(value))
    return value
