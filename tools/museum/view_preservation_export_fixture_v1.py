"""Synthetic local source-export bytes paired with complete frozen inventory.

This is test construction, not a second production exporter. Every retained
member and original publication is copied from the validated complete fixture.
Additional admission commitments are synthetic; they prove no deployed fixture,
original provider configuration, governance execution, or RPC provenance.
"""
from hashlib import sha256
import json
from pathlib import Path

from . import view_preservation_inventory_v1 as consumer
from . import view_preservation_inventory_types_v1 as inventory_types
from . import view_preservation_inventory_sources_v1 as sources
from . import view_preservation_reference_types_v1 as reference_types
from . import view_preservation_snapshot_types_v1 as snapshot_types
from . import view_preservation_output_types_v1 as output_types
from . import view_policy_adoption_types_v2 as adoption_types
from .canonical import dumps, hex_bytes, keccak256, schema_id
from .chain_abi import encode, decode
from .native_finality_wire import from_json
from .view_preservation_bundle_fixture_v1 import supplied as complete_fixture


SOURCE_SCHEMA = 'STREAM_VIEW_CEREMONY_SOURCE_EXPORT_V1'
SYNTHETIC_REVISION = '0x' + 'ab' * 20
GRAPH_ROLES = (
    ('CORE', 'core'), ('METADATA', 'metadata'), ('ROUTER', 'router'),
    ('FINALITY', 'finality'), ('PROVIDER', 'provider'), ('DISCOVERY', None),
    ('ARTIST_REGISTRY', 'artist'), ('SCHEMAS', 'schemas'), ('STORE', 'store'),
    ('DECLARATIONS', 'views'), ('VIEW_REGISTRY', 'rendererRegistry'),
    ('VIEW_RENDERER', 'renderer'), ('VIEW_SOURCE_SET', 'entropySourceSet'),
    ('PRESERVATION_RENDERER', 'preservationRenderer'), ('CHECKPOINT', 'checkpoint'),
    ('OUTPUT_MANIFEST', 'outputManifest'), ('SNAPSHOT', 'viewSnapshot'),
    ('REFERENCE', 'viewReference'), ('INVENTORY', 'inventory'), ('BUNDLE', 'bundleCoverage'),
    ('ARTIFACT_COVERAGE', 'coverage'), ('EXTERNAL_COVERAGE', 'externalCoverage'),
    ('SCOPE_MEMBERSHIP', 'scopeMembership'), ('GOVERNANCE_EXECUTOR', 'authority'),
    ('ROLE_REGISTRY', None), ('ARCHIVE', 'artistArchive'), ('SNAPSHOT_AUTHORITY', 'authority'),
    ('ROOT_SAFE', None), ('ARTIST_SAFE', None),
)
CONFIGURATION = ('address', 'bytes32', 'uint256', 'address', 'bytes32', 'address', 'bytes32')
BASIC_RECEIPT = ('bytes32', CONFIGURATION, adoption_types.ROUTE_BINDING,
    snapshot_types.DEPENDENCIES, 'bytes32', 'bytes32', 'bytes32', 'uint64', 'bytes32')
COMPLETE_SELECTION = ('address', 'bytes32') * 3
COMPLETE_RECEIPT = (COMPLETE_SELECTION,) + ('bytes32',) * 5 + ('uint64', 'bytes32')


def A(number):
    return '0x' + format(number, '040x')


def H(label):
    return schema_id('synthetic source-export fixture ' + label)


def compact(value):
    """Match original emitted property order; Museum sorted JSON is different."""
    return json.dumps(value, ensure_ascii=False, separators=(',', ':'), allow_nan=False).encode('utf-8')


def reseal_source(source):
    """Make a coherent external-pin before-image after a test mutation."""
    source.pop('sourceHash', None)
    source['sourceHash'] = keccak256(compact(source))
    return compact(source)


def _abi(kind, value):
    return '0x' + encode((kind,), (value,)).hex()


def _hash(types, values):
    return keccak256(encode(types, values))


def _bindings(inventory, bundle, context, graph, adopted, snapshot):
    """Build exact native test-only receipt preimages from retained dependencies."""
    chain = int(context['chainId']); provider = graph['provider']['address']
    deps = from_json(snapshot_types.DEPENDENCIES, snapshot['dependencies'])
    declaration = from_json(adoption_types.RECORD, adopted['record'])[1][0][16]
    configuration = (graph['viewSnapshot']['address'], graph['viewSnapshot']['runtimeHash'], 16000000,
        graph['checkpoint']['address'], graph['checkpoint']['runtimeHash'],
        graph['outputManifest']['address'], graph['outputManifest']['runtimeHash'])
    workers = [A(90010)] + [graph[role]['address'] for role in
        ('checkpointSourceWorker', 'checkpointTokenWorker', 'manifestReadWorker', 'manifestEncodingWorker')]
    pins = [H('snapshot source worker')] + [graph[role]['runtimeHash'] for role in
        ('checkpointSourceWorker', 'checkpointTokenWorker', 'manifestReadWorker', 'manifestEncodingWorker')]
    # The frozen envelope has no original provider-configuration preimage or
    # snapshot source-library row. These are explicit synthetic commitments.
    capability = _hash(('bytes32', 'uint256', 'address', 'address', 'bytes32', 'bytes32'),
        (schema_id('6529STREAM_FINALITY_VIEW_PRESERVATION_BINDING_V1'), chain, provider,
         graph['authority']['address'], graph['authority']['runtimeHash'], H('original provider configuration')))
    basic = (capability, configuration, declaration, deps, _hash((snapshot_types.DEPENDENCIES,), (deps,)),
        _hash((('address',) * 5, ('bytes32',) * 5), (tuple(workers), tuple(pins))),
        H('original class2 action'), 100, H('unsealed basic'))
    proposal = _hash(('bytes32',) + BASIC_RECEIPT[:6],
        (schema_id('6529STREAM_FINALITY_VIEW_PRESERVATION_PROPOSAL_V1'), *basic[:6]))
    basic = (*basic[:-1], _hash(('bytes32', 'bytes32', 'bytes32', 'uint64'),
        (schema_id('6529STREAM_FINALITY_VIEW_PRESERVATION_RECEIPT_V1'), proposal, basic[6], basic[7])))
    selection = tuple(part for role in ('viewReference', 'inventory', 'bundleCoverage')
        for part in (graph[role]['address'], graph[role]['runtimeHash']))
    complete = (selection,
        _hash((reference_types.DEPENDENCIES,), (from_json(reference_types.DEPENDENCIES, inventory['reference']['dependencies']),)),
        _hash((inventory_types.DEPENDENCIES,), (from_json(inventory_types.DEPENDENCIES, inventory['dependencies']),)),
        _hash((inventory_types.BUNDLE_DEPENDENCIES,), (from_json(inventory_types.BUNDLE_DEPENDENCIES, bundle['dependencies']),)),
        basic[-1], basic[6], basic[7], H('unsealed complete'))
    complete = (*complete[:-1], _hash(('bytes32', 'uint256', 'address') + COMPLETE_RECEIPT[:-1],
        (schema_id('6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_RECEIPT_V1'), chain, provider, *complete[:-1])))
    assert len(encode((BASIC_RECEIPT,), (basic,))) == 1376
    assert len(encode((COMPLETE_RECEIPT,), (complete,))) == 416
    return basic, complete


def supplied(count=1, mode='disabled', burned=False):
    """Return exact export files and independently pinned full inventory bytes."""
    inventory, coverage, context, graph = complete_fixture(count, mode, burned)
    envelope = {'profileHash': consumer.PROFILE_HASH, 'context': context, 'graph': graph,
        'inventory': inventory, 'bundle': coverage}
    inventory_raw = dumps(envelope)
    consumer.verify(inventory_raw)
    row, proof, adopted, snap = sources.selected(inventory['reference'])
    original = from_json(reference_types.SOURCE, row['source'])
    scope = original[2][0]
    basic, complete = _bindings(inventory, coverage, context, graph, adopted, proof['snapshot'])
    c = from_json(inventory_types.CONTEXT, inventory['context'])
    publication = {
        'viewId': c[14], 'adoptionRecord': c[13], 'checkpoint': c[11], 'outputManifest': c[12],
        'snapshotRecord': c[3][0], 'rootRecord': c[9],
        'basicBindingRecord': basic[-1], 'completeBindingRecord': complete[-1],
        'adoptionABI': _abi(adoption_types.RECORD, from_json(adoption_types.RECORD, adopted['record'])),
        'checkpointABI': _abi(output_types.CHECKPOINT_PLAN, original[2][4]),
        'outputManifestABI': _abi(output_types.MANIFEST_PLAN, original[2][5]),
        'snapshotReceiptABI': _abi(snapshot_types.RECEIPT, original[1]),
        'basicBindingABI': _abi(BASIC_RECEIPT, basic), 'completeBindingABI': _abi(COMPLETE_RECEIPT, complete),
        'referenceDependenciesABI': _abi(reference_types.DEPENDENCIES,
            from_json(reference_types.DEPENDENCIES, inventory['reference']['dependencies'])),
        'inventoryDependenciesABI': _abi(inventory_types.DEPENDENCIES,
            from_json(inventory_types.DEPENDENCIES, inventory['dependencies'])),
        'bundleDependenciesABI': _abi(inventory_types.BUNDLE_DEPENDENCIES,
            from_json(inventory_types.BUNDLE_DEPENDENCIES, coverage['dependencies'])),
        'rootRecordABI': _abi(snapshot_types.ROOT_RECORD, original[4]),
        'rootBindingABI': _abi(snapshot_types.ROOT_BINDING, original[5]),
    }
    export_graph = []
    for index, (role, key) in enumerate(GRAPH_ROLES):
        pair = graph[key] if key else {'address': A(90100 + index), 'runtimeHash': H('export role ' + role)}
        if role == 'ROOT_SAFE': pair = {**pair, 'address': adopted['record'][5]}
        if role == 'ARTIST_SAFE': pair = {**pair, 'address': original[2][2][6]}
        export_graph.append({'role': role, 'target': pair['address'], 'runtimeHash': pair['runtimeHash']})
    files = {}; members = []
    for index, member in enumerate(inventory['members']):
        native = decode((output_types.OUTPUT,), hex_bytes(member['outputReturn']), maximum=992)[0]
        exported = {'index': str(index), 'tokenId': str(native[1]), 'collectionSerial': str(native[2])}
        for key, extension in (('json', '.json'), ('html', '.html'),
                ('outputReturn', '.output.abi'), ('tokenData', '.token-data.bin')):
            name = f'member-{index:020d}' + extension; raw = hex_bytes(member[key]); files[name] = raw
            exported[key] = {'path': name, 'keccak256': keccak256(raw),
                'sha256': '0x' + sha256(raw).hexdigest(), 'byteLength': str(len(raw))}
        members.append(exported)
    source = {'schema': SOURCE_SCHEMA, 'schemaVersion': 1,
        'fixture': {'host': A(90001), 'runtimeHash': H('fixture runtime'),
            'sourceRevision': SYNTHETIC_REVISION, 'chainId': context['chainId'],
            'initialBlockNumber': '0', 'initialTimestamp': '100',
            'deploymentHash': context['deploymentEvidenceHash']},
        'scope': {'scopeType': scope[0], 'collectionId': str(scope[1]), 'tokenId': str(scope[2]), 'scopeId': scope[3]},
        'graph': export_graph, 'publication': publication, 'members': members}
    files['source.json'] = reseal_source(source)
    return {'files': files, 'inventoryRaw': inventory_raw, 'source': source, 'envelope': envelope,
        'sourceSHA256': sha256(files['source.json']).hexdigest(),
        'inventorySHA256': sha256(inventory_raw).hexdigest(), 'sourceRevision': SYNTHETIC_REVISION}


def write_export(directory, value):
    """Write the test export to a new directory without overwriting old bytes."""
    directory = Path(directory)
    directory.mkdir(parents=False, exist_ok=False)
    for name, raw in value['files'].items():
        with (directory / name).open('xb') as stream:
            stream.write(raw)
    return directory
