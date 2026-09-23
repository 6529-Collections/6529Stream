"""Fresh shared-state synthetic VIEW/PNG originals for native format tests.

This fixture changes construction inputs before any commitment is made. It
does not relabel a retained envelope, mock a production verifier, execute a
renderer, or authenticate the synthetic Archive observations. The matching
Title fixture must install the supplied Core runtime before its own capture.
"""
from copy import deepcopy
from contextlib import ExitStack
from unittest.mock import patch

from .canonical import dumps, keccak256
from .independent_wire import require
from .test_public_chain_history import PublicHistoryFixture
from .test_current_rights_source import A
from .view_preservation_fixture_v1 import ViewPreservationFixtureV1
from . import view_preservation_retrieval_fixture_v1 as retrieval_fixture
from . import test_view_preservation_reference_wire_v1 as reference_fixture
from . import view_reference_semantic_receipt_fixture_v1 as receipts
from . import view_preservation_retrieval_v1 as retrieval
from . import test_view_policy_adoption_wire_v2 as adoption_rows_fixture
from . import test_view_preservation_adoption_wire_v1 as adoption_fixture
from . import test_view_preservation_snapshot_wire_v1 as snapshot_fixture
from . import test_view_preservation_root_wire_v1 as root_fixture
from . import test_view_preservation_output_wire_v1 as output_fixture
from . import view_preservation_inventory_fixture_v1 as original_inventory_fixture
from . import test_view_preservation_retrieval_inventory_v1 as inventory_fixture
from . import test_view_preservation_inventory_stages_v1 as stage_fixture
from . import test_view_preservation_bundle_wire_v1 as archive_fixture


CORE_RUNTIME = b'synthetic VIEW core'
TIME_OFFSET = 1779999905
BLOCK_OFFSET = 5
STATE_KEYS = ('chainId', 'blockNumber', 'blockHash', 'stateRoot', 'timestamp',
    'environment', 'deploymentEvidenceHash', 'core', 'collectionId', 'tokenId')


class _SharedView(ViewPreservationFixtureV1):
    """Version-local constructor using unchanged native event descriptors."""

    def __init__(self, context, source_header, core_runtime, token_serial, *,
                 count=1, mode='disabled', burned=False, later_adoption=False):
        from . import native_view_preservation_wire_v1 as wire
        from . import view_policy_membership_v2 as membership
        from . import view_preservation_adoption_wire_v1 as adoption
        from .test_view_policy_membership_v2 import supplied as members
        from .test_view_preservation_adoption_wire_v1 import supplied as adopted
        from .test_view_preservation_output_wire_v1 import supplied as output, reseal
        from .test_view_preservation_snapshot_wire_v1 import supplied as snapshot
        from .test_view_preservation_root_wire_v1 import supplied as root

        require(count == 1 and mode == 'disabled' and not burned and not later_adoption,
            'shared VIEW fixture supports one original live disabled-policy token')
        self.context = deepcopy(context)
        self._source_header = deepcopy(source_header)
        PublicHistoryFixture.__init__(self, end=int(context['blockNumber']))
        self.anchor = {key: context[key] for key in STATE_KEYS[:5]}
        self.codes, self.pins, self.responses, self.graph = {}, {}, {}, {}
        for index, role in enumerate(wire.GRAPH_KEYS):
            address = context['core'] if role == 'core' else A(73000 + index)
            runtime = core_runtime if role == 'core' else ('synthetic VIEW ' + role).encode()
            require(address not in self.codes, 'shared VIEW fixture graph address collision')
            self.codes[address] = runtime
            self.pins[address] = keccak256(runtime)
            self.graph[role] = {'address': address, 'runtimeHash': self.pins[address]}

        self.member_value, _, _, self.binding = members(count, modes=(mode,),
            context=self.context, graph=self.graph, recorded_at=_time(101))
        for index, identity in enumerate(self.member_value['membership']['identities']):
            identity[2] = str(token_serial + index)
        if burned:
            self.member_value['membership']['identities'][0][3] = True
            self.member_value['membership']['lifecycles'][0] = '3'
        self.adoption_value, _, _ = adopted(context=self.context, graph=self.graph,
            policy_binding=self.binding, adopted_at=_time(103),
            later_head=later_adoption, later_adopted_at=_time(110))
        admitted = adoption.validate(self.adoption_value, self.context, self.graph)
        member_result = membership.validate(self.member_value, self.context,
            self.graph, self.binding)
        combined = {**admitted, 'tokenIds': member_result['tokenIds'],
            'policies': member_result['policies']}
        self.output_value, _, _, _ = output(count, mode=mode, burned=burned,
            context=self.context, graph=self.graph, adoption=combined,
            serving_configuration_hash=admitted['preservation']['configurationHash'],
            coverage_timestamp=_time(106))
        for index, row in enumerate(self.output_value['checkpoint']['outputs']):
            row[2] = str(token_serial + index)
        reseal(self.output_value, self.context, self.graph, combined,
            coverage_timestamp=_time(106))
        self.snapshot_value, _, _ = snapshot(context=self.context, graph=self.graph,
            adoption=combined, membership=member_result, output_value=self.output_value,
            recorded_at=_time(107), locked=True)
        self.root_value, *_ = root(context=self.context, graph=self.graph,
            snapshot_value=self.snapshot_value, output_value=self.output_value,
            published_at=_time(109))
        self.bundle = {'scope': deepcopy(self.binding[7]), 'adoption': self.adoption_value,
            'membership': self.member_value, 'output': self.output_value,
            'snapshot': self.snapshot_value, 'root': self.root_value}
        wire.validate_bundle(self.bundle, self.context, self.graph)
        self._events()

    def header(self, number):
        if number == int(self.context['blockNumber']):
            key = self._source_header['hash']
            if key not in self.blocks:
                self.blocks[key] = deepcopy(self._source_header)
            return self.blocks[key]
        require(6 <= number <= 41, 'shared VIEW fixture historical range overlaps Title')
        header = PublicHistoryFixture.header(self, number)
        header['timestamp'] = hex(1780000000 + number)
        return header

    def _events(self):
        """Generate original coordinates from already-shifted native records."""
        from . import native_view_preservation_wire_v1 as wire
        from .canonical import schema_id
        descriptors = list(wire.expected_events(self.bundle, self.context, self.graph))
        self.event_descriptors, self.view_events = descriptors, []
        priorities = {kind: index for index, kind in enumerate((
            'membership_recorded', 'membership_admitted', 'membership_progressed',
            'membership_sealed', 'source_set_prepared', 'view_adopted',
            'view_checkpoint_started', 'view_checkpoint_appended', 'view_checkpoint_sealed',
            'view_coverage_completed', 'view_part_prepared', 'view_manifest_started',
            'view_manifest_advanced', 'view_manifest_verified', 'preservation_registered',
            'view_snapshot_published', 'view_snapshot_locked', 'view_root_published',
            'view_root_binding_published'))}
        priorities['view_root_binding_published'] = priorities['view_root_published']
        adoptions = {row['record'][3]: row for row in self.adoption_value['history']}
        snapshots = {row['receipt'][0]: row for row in self.snapshot_value['history']}
        roots = {row['recordHash']: row for row in self.root_value['history']}

        def block(descriptor):
            kind = descriptor['kind']
            if kind.startswith('membership_'): return 6
            if kind == 'source_set_prepared': return 7
            if kind == 'view_adopted': return int(adoptions[descriptor['topics'][3]]['record'][10]) - 1780000000
            if kind.startswith('view_checkpoint_'): return 10
            if kind == 'preservation_registered': return 9
            if kind == 'view_snapshot_published': return int(snapshots[descriptor['topics'][3]]['receipt'][13]) - 1780000000
            if kind == 'view_snapshot_locked': return int(self.snapshot_value['lock'][3]) - 1780000000
            if kind in ('view_root_published', 'view_root_binding_published'):
                return int(roots[descriptor['topics'][3]]['record'][17]) - 1780000000
            return 11

        ordered = sorted(enumerate(descriptors), key=lambda item:
            (block(item[1]), priorities[item[1]['kind']], item[0]))
        for _, descriptor in ordered:
            number = block(descriptor)
            topics = [topic if topic is not None else schema_id(
                'synthetic VIEW coverage plan ' + descriptor['topics'][1])
                for topic in descriptor['topics']]
            log = PublicHistoryFixture.add(self, number, address=descriptor['address'],
                topics=topics, same_transaction=bool(self.header(number)['transactions']))
            log['data'] = descriptor['data']
            stamp = str(1780000000 + number)
            self.view_events.append({'log': log, 'timestamp': stamp})
            if descriptor['kind'] == 'view_adopted':
                adoptions[descriptor['topics'][3]]['event'][6:] = [str(number),
                    log['blockHash'], log['transactionHash'], str(int(log['transactionIndex'], 16)),
                    str(int(log['logIndex'], 16)), stamp]
        wire.validate_bundle(self.bundle, self.context, self.graph)
        wire.validate_event_join(self.bundle, self.context, self.graph, self.view_events)


def _time(value):
    return value + TIME_OFFSET


def _block_hash(number):
    return '0x' + format(100000000 + number, '064x')


def _timestamp_argument(function, name):
    def construct(*args, **kwargs):
        if name in kwargs and int(kwargs[name]) < 1000:
            kwargs[name] = _time(int(kwargs[name]))
        return function(*args, **kwargs)
    return construct


_seal_output = _timestamp_argument(output_fixture.reseal, 'coverage_timestamp')
_root = _timestamp_argument(root_fixture.supplied, 'published_at')


def _snapshot_at(*args, **kwargs):
    if 'recorded_at' in kwargs and int(kwargs['recorded_at']) < 1000:
        kwargs['recorded_at'] = _time(int(kwargs['recorded_at']))
    return _snapshot(*args, **kwargs)


def _source_events(bundle, context, graph):
    # This copy needs no RPC source header: only historical event coordinates
    # are returned. The outer constructor separately checks the supplied tip.
    fixture = _SharedView.__new__(_SharedView)
    fixture.context = deepcopy(context)
    fixture._source_header = {'hash': context['blockHash'],
        'number': hex(int(context['blockNumber'])), 'stateRoot': context['stateRoot'],
        'timestamp': hex(int(context['timestamp'])), 'transactions': []}
    PublicHistoryFixture.__init__(fixture, end=int(context['blockNumber']))
    fixture.graph = {key: graph[key] for key in adoption_fixture.t.GRAPH_KEYS}
    fixture.bundle = bundle
    fixture.adoption_value, fixture.member_value = bundle['adoption'], bundle['membership']
    fixture.output_value, fixture.snapshot_value = bundle['output'], bundle['snapshot']
    fixture.root_value = bundle['root']
    fixture._events()
    return fixture.view_events


def supplied_raw_for(context, source_header, *, core_runtime, token_serial=3):
    """Build and concretely verify one received PNG at the supplied exact state.

    Historical VIEW operations occupy blocks 6..41 (timestamps 1780000006..
    1780000041), after the shared Title token's native mint in block 3.
    The caller owns the later source header and any independent Title history.
    Source headers are checked construction inputs; the closed retrieval
    envelope itself retains its native context, getter observations and events.
    """
    require(isinstance(context, dict) and set(context) == set(STATE_KEYS),
        'shared VIEW fixture requires exact original source state')
    require(isinstance(source_header, dict)
        and source_header.get('hash') == context['blockHash']
        and source_header.get('stateRoot') == context['stateRoot']
        and source_header.get('number') == hex(int(context['blockNumber']))
        and source_header.get('timestamp') == hex(int(context['timestamp']))
        and isinstance(source_header.get('transactions'), list),
        'shared VIEW fixture source header differs')
    require(int(context['blockNumber']) > 41 and int(context['timestamp']) > _time(136),
        'shared VIEW fixture source must follow original VIEW operations')
    require(type(core_runtime) is bytes and core_runtime == CORE_RUNTIME,
        'shared VIEW fixture requires the original synthetic Core runtime preimage')
    require(type(token_serial) is int and token_serial > 0,
        'shared VIEW fixture collection serial must be positive')

    def factory(**options):
        return _SharedView(context, source_header, core_runtime, token_serial, **options)

    png = receipts.received_bytes('png')
    with ExitStack() as stack:
        replacements = (
            (reference_fixture, 'ViewPreservationFixtureV1', factory),
            (adoption_fixture, 'adoption_supplied', _adoption_rows),
            (snapshot_fixture, 'supplied', _snapshot),
            (original_inventory_fixture, 'reference_inputs', _reference_inputs),
            (original_inventory_fixture, '_source_events', _source_events),
            (inventory_fixture, '_uri', _inventory_uri),
            (inventory_fixture, 'reseal', _inventory_reseal),
            (inventory_fixture, 'build_fixed_stages', _fixed_stages),
            (receipts, '_ORIGINAL_ARCHIVE', _archive_original),
            (retrieval_fixture, 'supplied', _retrieval),
            (retrieval_fixture, 'MEDIA_BYTES', png),
            (retrieval_fixture, 'inventory_supplied',
                lambda uri, **options: receipts._inventory('png', uri, **options)),
            (retrieval_fixture, '_archive',
                lambda c, g, s, media: receipts._archive('png', c, g, s, media)))
        for module, name, value in replacements:
            stack.enter_context(patch.object(module, name, value))
        value = receipts.complete_envelope()
    require(value['context'] == context, 'shared VIEW fixture changed the source state')
    require(value['graph']['core'] == {'address': context['core'],
        'runtimeHash': keccak256(core_runtime)}, 'shared VIEW fixture changed Core binding')
    raw = dumps(value)
    report = retrieval.verify(raw)
    require(report['inputHash'] == keccak256(raw)
        and report['claims']['completeReceivedMediaBytesChecked'],
        'shared VIEW fixture did not verify received PNG bytes')
    return raw


# Explicit original factory copies. No verifier or runtime code generation.
# Construction copy of tools.museum.test_view_policy_adoption_wire_v2.supplied; only chronology/dependency aliases differ.
def _adoption_rows(*, context=None, graph=None, policy_binding=None, later_head=True, include_v1=True, adopted_at=103, foreign_v1_core=False):
    external_binding = policy_binding is not None
    context = adoption_rows_fixture.deepcopy(context) if context is not None else {'chainId': '31337', 'core': adoption_rows_fixture.A(1), 'collectionId': '7', 'tokenId': '41', 'timestamp': '120', 'blockNumber': '20', 'blockHash': adoption_rows_fixture.H('source block'), 'stateRoot': adoption_rows_fixture.H('state'), 'environment': 'local_evm_fixture', 'deploymentEvidenceHash': adoption_rows_fixture.H('deployment')}
    graph = adoption_rows_fixture.deepcopy(graph) if graph is not None else adoption_rows_fixture._graph(context)
    if policy_binding is None:
        _, _, _, binding_json = adoption_rows_fixture.membership_supplied(3, context=context, graph=graph, recorded_at=101)
    else:
        binding_json = adoption_rows_fixture.deepcopy(policy_binding)
    binding = adoption_rows_fixture.w._v(adoption_rows_fixture.t.POLICY_BINDING, binding_json)
    chain, cid, router, core = (int(context['chainId']), int(context['collectionId']), graph['router']['address'], graph['core']['address'])
    route = (*((graph[k]['address'], graph[k]['runtimeHash']) for k in ('core', 'router', 'artist', 'finality', 'provider', 'metadata', 'schemas', 'store')),)
    route = tuple((v for pair in route for v in pair)) + ((graph['views']['address'], graph['views']['runtimeHash'], graph['scopeMembership']['address'], graph['scopeMembership']['runtimeHash'], 100000, 1000000),)
    rows = []
    aggregate_chain = adoption_rows_fixture.ZERO
    heads = {}
    revisions = {}
    declaration_heads = {}
    declaration_revisions = {}

    def add(profile, scope_id, view_id, timestamp, block, tx, log):
        nonlocal aggregate_chain
        scope = (4, cid, 0, scope_id)
        key = tuple(scope)
        previous = heads.get(key, adoption_rows_fixture.ZERO)
        policy = binding if profile == adoption_rows_fixture.t.V2_PROFILE else None
        row_route = route
        if profile == adoption_rows_fixture.ZERO and foreign_v1_core:
            row_route = (adoption_rows_fixture.A(7998), adoption_rows_fixture.H('foreign historical core'), *route[2:])
        row_core = row_route[0]
        payload = adoption_rows_fixture.encode((adoption_rows_fixture.t.PAYLOAD,), ((adoption_rows_fixture.t.V1_CONTEXT if profile == adoption_rows_fixture.ZERO else adoption_rows_fixture.t.V2_CONTEXT, 'Example view', 'Synthetic retained bytes', 'ipfs://image', b'window.example=true;'),))
        declaration_previous = declaration_heads.get(view_id, adoption_rows_fixture.ZERO)
        declaration_revision = declaration_revisions.get(view_id, 0) + 1
        manifest, manifest_raw = adoption_rows_fixture._manifest(profile, cid, view_id, declaration_revision, declaration_previous, payload)
        receipt = (cid, view_id, declaration_revision, declaration_previous, adoption_rows_fixture.A(8000), 7, cid, 1, timestamp - 1, len(rows), adoption_rows_fixture.H('declaration chain ' + str(len(rows))), adoption_rows_fixture.keccak256(adoption_rows_fixture.w.V1_PAYLOAD_SCHEMA_BYTES if profile == adoption_rows_fixture.ZERO else adoption_rows_fixture.w.V2_PAYLOAD_SCHEMA_BYTES), adoption_rows_fixture.keccak256(adoption_rows_fixture.w.MANIFEST_SCHEMA_BYTES), adoption_rows_fixture.keccak256(adoption_rows_fixture.w.RAW_DEFINITION_BYTES))
        original = (adoption_rows_fixture.w.DISPLAY_VIEW_MANIFEST, adoption_rows_fixture.w.scope_subject(chain, row_core, scope), (1, adoption_rows_fixture.hex_bytes(adoption_rows_fixture.keccak256(manifest_raw)), adoption_rows_fixture.w.RAW_BYTES), manifest[2], adoption_rows_fixture.schema_id('STREAM_COLLECTION_VIEW_MANIFEST_ABI_V1'), adoption_rows_fixture.ZERO, (0, b'', adoption_rows_fixture.ZERO), 0)
        declaration_hash = adoption_rows_fixture.generic_hash(chain, graph['views']['address'], row_core, cid, receipt[4], original)
        registry = (adoption_rows_fixture.A(7301), adoption_rows_fixture.H('legacy registry')) if profile == adoption_rows_fixture.ZERO else (graph['rendererRegistry']['address'], graph['rendererRegistry']['runtimeHash'])
        renderer = (adoption_rows_fixture.A(7300), adoption_rows_fixture.keccak256(adoption_rows_fixture.LEGACY_RENDERER_RUNTIME)) if profile == adoption_rows_fixture.ZERO else (graph['renderer']['address'], graph['renderer']['runtimeHash'])
        selected_manifest = (registry[0], registry[1], adoption_rows_fixture.ZERO, renderer[0], renderer[1], adoption_rows_fixture.ZERO, adoption_rows_fixture.ZERO, adoption_rows_fixture.t.V1_CONTEXT if profile == adoption_rows_fixture.ZERO else adoption_rows_fixture.t.V2_CONTEXT, adoption_rows_fixture.ZERO, adoption_rows_fixture.H('read set'), adoption_rows_fixture.H('registration'))
        renderer_info = adoption_rows_fixture._renderer(profile, graph, binding)
        if profile == adoption_rows_fixture.ZERO and foreign_v1_core:
            renderer_info['sourceTargets'][0] = row_core
            renderer_info['sourcePins'][0] = row_route[1]
        rm = adoption_rows_fixture.w._v(adoption_rows_fixture.t.RENDERER_MANIFEST, renderer_info['manifest'])
        version_key = adoption_rows_fixture.keccak256(adoption_rows_fixture.encode(('bytes32', 'bytes32', 'bytes32'), (adoption_rows_fixture.w.VERSION_DOMAIN, rm[0], rm[1])))
        selected_manifest = (*selected_manifest[:2], version_key, *selected_manifest[3:5], rm[0], rm[1], rm[2], rm[4], selected_manifest[9], selected_manifest[10])
        chunks = [payload[i:i + 8192] for i in range(0, len(payload), 8192)]
        pointers = tuple((adoption_rows_fixture.A(9000 + len(rows) * 10 + i) for i in range(len(chunks))))
        padded_pointers = pointers + (adoption_rows_fixture.ZERO_ADDRESS,) * (adoption_rows_fixture.t.MAX_CHUNKS - len(chunks))
        padded_hashes = tuple((adoption_rows_fixture.keccak256(part) for part in chunks)) + (adoption_rows_fixture.ZERO,) * (adoption_rows_fixture.t.MAX_CHUNKS - len(chunks))
        membership = list(binding[8])
        membership[0] = adoption_rows_fixture.w.scope_subject(chain, row_core, scope)
        source = (row_route, tuple(membership), selected_manifest, receipt[11], receipt[12], receipt[13], adoption_rows_fixture.keccak256(manifest_raw), adoption_rows_fixture.keccak256(adoption_rows_fixture.encode((adoption_rows_fixture.t.VIEW_RECEIPT,), (receipt,))), adoption_rows_fixture.keccak256(payload), len(payload), padded_pointers, padded_hashes)
        input_ = [scope, view_id, declaration_hash, previous, registry[0], version_key, adoption_rows_fixture.ZERO]
        record = [tuple(input_), source, adoption_rows_fixture.ZERO, adoption_rows_fixture.ZERO, 0, adoption_rows_fixture.A(8100), 7, cid, 1, adoption_rows_fixture.H('artist consent ' + str(len(rows))), timestamp, (0, adoption_rows_fixture.ZERO)]
        source_value = adoption_rows_fixture.w.source_hash(profile, chain, router, tuple(record), policy)
        input_[6] = source_value
        record[0] = tuple(input_)
        record[2] = source_value
        revision = revisions.get(key, 0) + 1
        record[4] = revision
        aggregate_revision = len(rows) + 1
        aggregate_chain = adoption_rows_fixture.w.next_aggregate(profile, chain, router, row_core, cid, aggregate_chain, aggregate_revision, adoption_rows_fixture.w.scope_subject(chain, core, scope), previous, adoption_rows_fixture.w.prepared_hash(profile, tuple(record)))
        record[11] = (aggregate_revision, aggregate_chain)
        record[3] = adoption_rows_fixture.w.record_hash(profile, chain, router, row_core, tuple(record))
        record = tuple(record)
        encoded = adoption_rows_fixture.encode((adoption_rows_fixture.t.RECORD,), (record,))
        declaration = {'manifest': adoption_rows_fixture.json_values(manifest), 'receipt': adoption_rows_fixture.json_values(receipt), 'record': adoption_rows_fixture.json_values(original), 'manifestPayload': '0x' + manifest_raw.hex(), 'manifestCarrier': {'pointer': adoption_rows_fixture.A(9500 + len(rows)), 'codeHash': adoption_rows_fixture.keccak256(b'\x00' + manifest_raw), 'runtime': '0x' + (b'\x00' + manifest_raw).hex()}, 'viewPayload': '0x' + payload.hex(), 'payloadChunks': [{'pointer': pointers[i], 'codeHash': adoption_rows_fixture.keccak256(b'\x00' + part), 'runtime': '0x' + (b'\x00' + part).hex()} for i, part in enumerate(chunks)], 'renderer': renderer_info}
        event = (1 if profile == adoption_rows_fixture.ZERO else 2, profile, cid, adoption_rows_fixture.w.scope_subject(chain, row_core, scope), record[3], record, block, adoption_rows_fixture.H('block ' + str(block)), adoption_rows_fixture.H('tx ' + str(block) + ':' + str(tx)), tx, log, timestamp)
        rows.append({'profile': profile, 'record': adoption_rows_fixture.json_values(record), 'encoded': '0x' + encoded.hex(), 'carrier': {'pointer': adoption_rows_fixture.A(9800 + len(rows)), 'codeHash': adoption_rows_fixture.keccak256(b'\x00' + encoded), 'runtime': '0x' + (b'\x00' + encoded).hex()}, 'event': adoption_rows_fixture.json_values(event), 'declaration': declaration, 'policyBinding': None if policy is None else adoption_rows_fixture.json_values(policy)})
        heads[key], revisions[key] = (record[3], revision)
        declaration_heads[view_id], declaration_revisions[view_id] = (declaration_hash, declaration_revision)
        return record[3]
    target_scope_id = binding[7][3]
    if include_v1:
        add(adoption_rows_fixture.ZERO, adoption_rows_fixture.H('other scope'), adoption_rows_fixture.H('legacy view'), _time(102), 7, 0, 0)
    selected = add(adoption_rows_fixture.t.V2_PROFILE, target_scope_id, adoption_rows_fixture.H('target view'), adopted_at, 8, 0, 0)
    if later_head:
        add(adoption_rows_fixture.t.V2_PROFILE, target_scope_id, adoption_rows_fixture.H('target view'), _time(106), 11, 0, 0)
    serving_binding = (core, graph['core']['runtimeHash'], router, graph['router']['runtimeHash'], chain, 100000)
    serving_hash = adoption_rows_fixture.w.serving_configuration_hash(chain, graph['serving']['address'], serving_binding, graph['servingWorker']['address'], graph['servingWorker']['runtimeHash'])
    value = {'version': '1', 'chainId': str(chain), 'router': router, 'routerRuntimeHash': graph['router']['runtimeHash'], 'scope': adoption_rows_fixture.json_values(binding[7]), 'selectedRecordHash': selected, 'head': heads[tuple(binding[7])], 'aggregate': adoption_rows_fixture.json_values((len(rows), aggregate_chain)), 'history': rows, 'serving': {'binding': adoption_rows_fixture.json_values(serving_binding), 'worker': graph['servingWorker']['address'], 'workerRuntimeHash': graph['servingWorker']['runtimeHash'], 'configurationHash': serving_hash}}
    return value if external_binding else (value, context, graph)

# Construction copy of tools.museum.test_view_preservation_snapshot_wire_v1.supplied; only chronology/dependency aliases differ.
def _snapshot(count=3, *, context=None, graph=None, output_value=None, adoption=None, membership=None, recorded_at=107, locked=True):
    """Return (snapshot,context,graph); external actual output/member joins supported."""
    if output_value is None:
        output_value, context, graph, adoption, membership = snapshot_fixture.base(count, context=context, graph=graph)
    else:
        context, graph = (snapshot_fixture.deepcopy(context), snapshot_fixture.deepcopy(graph))
    source = output_value['checkpoint']['source']
    scope = source[0][0][0]
    facts = source[1][8]
    artist = [True, graph['artist']['address'], graph['artist']['runtimeHash'], output_value['manifest']['plan'][1][2], '1', snapshot_fixture.H('Artist binding'), snapshot_fixture.A(78900), snapshot_fixture.H('identity'), snapshot_fixture.H('acceptance'), str(_time(102)), str(_time(104)), snapshot_fixture.H('Artist presentation snapshot')]
    entropy = membership['evidence']
    s = [scope, facts, artist, source, output_value['checkpoint']['plan'], output_value['manifest']['plan'], entropy]
    d = [[graph[k]['address'] for k in snapshot_fixture.t.DEPENDENCY_ROLES], [graph[k]['runtimeHash'] for k in snapshot_fixture.t.DEPENDENCY_ROLES], context['chainId'], '100000', '8000000', '8000000']
    p = [scope, snapshot_fixture.H('snapshot ID'), snapshot_fixture.ZERO, '0', output_value['manifest']['recordHash'], source[0][3], snapshot_fixture.ZERO, 'ipfs://original-view-snapshot', str(recorded_at), snapshot_fixture.H('reason')]
    r = [snapshot_fixture.ZERO, facts[0], snapshot_fixture.ZERO, '1', snapshot_fixture.ZERO, snapshot_fixture.ZERO, '0', snapshot_fixture.ZERO, snapshot_fixture.A(78901), '7', '1', '8', '2', str(recorded_at), snapshot_fixture.w.SCHEMA_HASH, snapshot_fixture.w.PROFILE_HASH, snapshot_fixture.w.CANON_HASH]
    value = {'dependencies': d, 'selectedRecordHash': snapshot_fixture.ZERO, 'current': r, 'history': [{'publication': p, 'receipt': r, 'source': snapshot_fixture.deepcopy(s), 'payload': '0x', 'chunks': []}], 'lock': [snapshot_fixture.ZERO, '0', snapshot_fixture.H('class2 lock action') if locked else snapshot_fixture.ZERO, str(recorded_at + 1) if locked else '0']}
    snapshot_fixture.reseal(value, context, graph)
    return (value, context, graph)

# Construction copy of tools.museum.test_view_preservation_reference_wire_v1.supplied; only chronology/dependency aliases differ.
def _reference(count=3, mode='disabled', burned=False, locked=True, foreign_later=False, later_adoption=False):
    from . import view_preservation_adoption_wire_v1 as adoption
    from . import view_policy_membership_v2 as membership
    fixture = reference_fixture.ViewPreservationFixtureV1(count=count, mode=mode, burned=burned, later_adoption=later_adoption)
    c, g = (fixture.context, fixture.graph)
    if foreign_later:
        from .test_view_preservation_adoption_wire_v1 import _bind_original_registry
        history = fixture.adoption_value['history']
        foreign = history.pop(0)
        foreign['record'][10] = '115'
        foreign['event'][6] = '15'
        foreign['event'][11] = '115'
        foreign['event'][7] = reference_fixture.H('foreign later block')
        foreign['event'][8] = reference_fixture.H('foreign later tx')
        history.append(foreign)
        version = fixture.adoption_value['preservation']['registry']['version']
        _bind_original_registry(fixture.adoption_value, c, g, version[4], version[5])
    a = adoption.validate(fixture.adoption_value, c, g)
    m = membership.validate(fixture.member_value, c, g, fixture.binding)
    a = {**a, 'tokenIds': m['tokenIds'], 'policies': m['policies']}
    html = {}
    for row in fixture.output_value['checkpoint']['outputs']:
        body = ('<html>original synthetic token ' + row[1] + '</html>').encode()
        html[row[1]] = body
        row[9] = reference_fixture.keccak256(body)
        row[11] = str(len(body))
    _seal_output(fixture.output_value, c, g, a, coverage_timestamp=106)
    fixture.snapshot_value, _, _ = _snapshot_at(context=c, graph=g, output_value=fixture.output_value, adoption=a, membership=m, recorded_at=107)
    fixture.root_value, *_ = _root(context=c, graph=g, snapshot_value=fixture.snapshot_value, output_value=fixture.output_value, published_at=109)
    fixture.bundle.update(output=fixture.output_value, snapshot=fixture.snapshot_value, root=fixture.root_value)
    fixture._events()
    proof = {'bundle': reference_fixture.deepcopy(fixture.bundle), 'events': reference_fixture.deepcopy(fixture.view_events)}
    g = {**g, 'viewReference': {'address': reference_fixture.A(79001), 'runtimeHash': reference_fixture.H('reference runtime')}, 'externalCoverage': {'address': reference_fixture.A(79002), 'runtimeHash': reference_fixture.H('external coverage runtime')}}
    sr = fixture.snapshot_value['history'][0]
    rr = fixture.root_value['history'][-1]
    artist = sr['source'][2][3]
    objects = []
    defs = reference_fixture.t.definitions()
    named = {row['name']: row for row in defs}

    def coverage(label, role, png=None):
        spec = named['STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1' if role == 'zip' else 'STREAM_REFERENCE_PNG_OBJECT_V1']
        fmt = named['STREAM_REFERENCE_NATIVE_FORMATS_V1']
        obj = (artist, spec['id'], reference_fixture.schema_id('RAW_BYTES'), reference_fixture.H(label + ' bytes'), png or reference_fixture.H(label + ' sha'), reference_fixture.H(label + ' arweave'), 99, reference_fixture.schema_id('IANA:application/zip' if role == 'zip' else 'IANA:image/png'), fmt['id'], fmt['hash'])
        key = reference_fixture.w._hash('6529STREAM_EXTERNAL_OBJECT_V1', ('uint256', 'address', 'address', reference_fixture.t.OBJECT), (int(c['chainId']), g['externalCoverage']['address'], c['core'], obj))
        cov = (reference_fixture.ZERO, key, artist, *obj[3:7], *(reference_fixture.H(label + ' evidence ' + str(i)) for i in range(7)), reference_fixture.schema_id('STREAM_EXTERNAL_ARTIFACT_COVERAGE_V1'))
        cov = (reference_fixture.w._hash('6529STREAM_EXTERNAL_COVERAGE_V1', ('uint256', 'address', reference_fixture.t.COVERAGE), (int(c['chainId']), g['externalCoverage']['address'], cov)), *cov[1:])
        objects.append({'objectHash': key, 'identity': reference_fixture.json_values(obj)})
        return cov
    env_cov = coverage('environment', 'zip')
    env = (env_cov[1], env_cov[0], reference_fixture.ZERO, 0, 'Synthetic engine', '1', reference_fixture.H('engine'), 'Synthetic tool', '1', reference_fixture.H('tool'), 'engine.exe', 'tool.py', (('engine.exe', 1, reference_fixture.H('engine')), ('tool.py', 1, reference_fixture.H('tool'))), (('C:/Windows/synthetic.dll', 1, reference_fixture.H('platform')),), 'Windows', 'synthetic', 'AMD64', 800, 600, 1, 'srgb', True, reference_fixture.schema_id('STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1'), 'No browser execution claim')
    env_raw = reference_fixture.w.environment_bytes(env)
    env = (*env[:2], reference_fixture.keccak256(env_raw), len(env_raw), *env[4:])
    captures, samples = ([], [])
    for index in [0] if count == 1 else [0, count - 1]:
        output = reference_fixture.w._v(reference_fixture.t.OUTPUT, fixture.output_value['checkpoint']['outputs'][index])
        body = html[str(output[1])]
        png = reference_fixture.H('PNG ' + str(index))
        cov = coverage('capture' + str(index), 'png', png)
        captures.append((output[1], output[2], output[8], output[9], len(body), body, cov[1], cov[0], '0x' + reference_fixture.sha256(body).hexdigest(), (png, png), env[2], _time(120)))
        samples.append((index, output, cov))
    p = (reference_fixture.w._v(reference_fixture.t.SCOPE, fixture.bundle['scope']), (int(c['collectionId']), reference_fixture.H('reference ID'), reference_fixture.ZERO, 0, sr['receipt'][0], 1, reference_fixture.ZERO, tuple(captures), env, 'ipfs://original-reference', _time(125), reference_fixture.H('reason')))
    r = (sr['receipt'][1], (reference_fixture.ZERO, reference_fixture.ZERO, int(c['collectionId']), p[1][1], reference_fixture.ZERO, 1, reference_fixture.ZERO, 0, reference_fixture.ZERO, p[1][4], 1, reference_fixture.A(79003), 3, 1, _time(125), _time(130), p[1][11], reference_fixture.t.SCHEMA_HASH, reference_fixture.t.PROFILE_HASH, reference_fixture.t.CANON_HASH))
    f = (r[0], reference_fixture.w._v(reference_fixture.snapshot_types.RECEIPT, sr['receipt']), reference_fixture.w._v(reference_fixture.snapshot_types.SOURCE, sr['source']), rr['recordHash'], reference_fixture.w._v(reference_fixture.snapshot_types.ROOT_RECORD, rr['record']), reference_fixture.w._v(reference_fixture.snapshot_types.ROOT_BINDING, rr['binding']), env_cov, tuple(samples))
    value = {'sourceRevision': reference_fixture.t.SOURCE_REVISION, 'dependencies': reference_fixture.json_values((tuple((g[k]['address'] for k in reference_fixture.w.DEPENDENCY_ROLES)), tuple((g[k]['runtimeHash'] for k in reference_fixture.w.DEPENDENCY_ROLES)), int(c['chainId']), 100000, 500000, 1000000, 100000)), 'definitions': [{'id': d['id'], 'kind': str(d['kind']), 'status': '1', 'hash': d['hash'], 'bytes': '0x' + d['bytes'].hex()} for d in defs], 'scope': reference_fixture.json_values(p[0]), 'selectedRecordHash': reference_fixture.ZERO, 'current': reference_fixture.json_values(r), 'history': [{'publication': reference_fixture.json_values(p), 'receipt': reference_fixture.json_values(r), 'source': reference_fixture.json_values(f), 'recordReturn': '0x', 'sourceReturn': '0x', 'payload': '0x', 'environment': '0x' + env_raw.hex(), 'objects': objects, 'fileInventories': {'package': reference_fixture.inventory(env[12], True, c, g), 'platform': reference_fixture.inventory(env[13], False, c, g)}, 'sourceProof': proof}], 'lock': [reference_fixture.ZERO, '1', reference_fixture.H('class2 reference lock'), str(_time(132))] if locked else [reference_fixture.ZERO, '0', reference_fixture.ZERO, '0'], 'events': []}
    reference_fixture.reseal(value, c, g)
    for i, desc in enumerate(reference_fixture.w.expected_events(value, c, g)):
        number = 35 if i == 0 else 37
        value['events'].append({'timestamp': str(1780000000 + number), 'log': {'address': desc['address'], 'topics': list(desc['topics']), 'data': desc['data'], 'blockNumber': hex(number), 'blockHash': _block_hash(number), 'transactionHash': reference_fixture.H('reference tx ' + str(number)), 'transactionIndex': '0x0', 'logIndex': '0x0', 'removed': False}})
    return (value, c, g)

# Construction copy of tools.museum.view_preservation_inventory_fixture_v1.reference_inputs; only chronology/dependency aliases differ.
def _reference_inputs(count=1, mode='disabled', burned=False):
    """Return reference/context/graph and all original byte preimages."""
    value, context, graph = _reference(count, mode, burned)
    documents = {row['id']: original_inventory_fixture.document(row['bytes'], row['kind']) for row in original_inventory_fixture.t.definitions()}
    proof = value['history'][0]['sourceProof']
    bundle = proof['bundle']
    adopted = bundle['adoption']
    for row in adopted['history']:
        if row['profile'] == original_inventory_fixture.vt.V2_PROFILE:
            original_inventory_fixture._empty_image(row, context, graph)
    registration = original_inventory_fixture._registration(adopted, context, graph, documents)
    a = original_inventory_fixture.aw.validate(adopted, context, {k: graph[k] for k in original_inventory_fixture.at.GRAPH_KEYS})
    chosen = next((row for row in adopted['history'] if row['record'][3] == adopted['selectedRecordHash']))
    m = original_inventory_fixture.mw.validate(bundle['membership'], context, graph, chosen['policyBinding'])
    a.update(tokenIds=m['tokenIds'], policies=m['policies'])
    members = []
    for output in bundle['output']['checkpoint']['outputs']:
        token = output[1]
        data = original_inventory_fixture.dumps({'tokenId': token, 'kind': 'synthetic exact token data'})
        js = original_inventory_fixture.dumps({'name': 'Original synthetic token ' + token, 'image': ''})
        html = ('<html>original synthetic token ' + token + '</html>').encode()
        output[6] = original_inventory_fixture.keccak256(data)
        output[8:12] = [original_inventory_fixture.keccak256(js), original_inventory_fixture.keccak256(html), str(len(js)), str(len(html))]
        members.append({'outputReturn': '0x' + original_inventory_fixture.encode((original_inventory_fixture.rt.OUTPUT,), (original_inventory_fixture.from_json(original_inventory_fixture.rt.OUTPUT, output),)).hex(), 'tokenData': '0x' + data.hex(), 'json': '0x' + js.hex(), 'html': '0x' + html.hex()})
    _seal_output(bundle['output'], context, graph, a, coverage_timestamp=106)
    bundle['snapshot'], _, _ = _snapshot_at(context=context, graph=graph, output_value=bundle['output'], adoption=a, membership=m, recorded_at=107)
    bundle['root'], *_ = _root(context=context, graph=graph, snapshot_value=bundle['snapshot'], output_value=bundle['output'], published_at=109)
    proof['events'] = _source_events(bundle, context, graph)
    row = value['history'][0]
    snap = bundle['snapshot']['history'][0]
    root = bundle['root']['history'][-1]
    row['publication'][1][4] = snap['receipt'][0]
    row['receipt'][1][9] = snap['receipt'][0]
    row['source'][1:6] = original_inventory_fixture.deepcopy([snap['receipt'], snap['source'], root['recordHash'], root['record'], root['binding']])
    for sample, capture in zip(row['source'][7], row['publication'][1][7]):
        index = int(sample[0])
        sample[1] = original_inventory_fixture.deepcopy(bundle['output']['checkpoint']['outputs'][index])
        body = original_inventory_fixture.hex_bytes(members[index]['html'])
        output = sample[1]
        capture[2:6] = [output[8], output[9], str(len(body)), '0x' + body.hex()]
        capture[8] = '0x' + original_inventory_fixture.sha256(body).hexdigest()
    original_inventory_fixture.seal_reference(value, context, graph)
    original_inventory_fixture.rw.validate(value, context, graph)
    runtimes = {}
    for role, pair in graph.items():
        labels = ('synthetic VIEW ' + role, 'synthetic VIEW ' + ('reference runtime' if role == 'viewReference' else 'external coverage runtime'))
        raw = next((label.encode() for label in labels if original_inventory_fixture.keccak256(label.encode()) == pair['runtimeHash']), None)
        if raw is None:
            raise AssertionError('fixture runtime preimage ' + role)
        runtimes[pair['address']] = '0x' + raw.hex()
    for index, policy in enumerate(m['policies']):
        raw = ('VIEW membership test coordinator code' + str(index)).encode()
        assert original_inventory_fixture.keccak256(raw) == policy[1]
        runtimes[policy[0]] = '0x' + raw.hex()
    for index, role in enumerate(original_inventory_fixture.w.GRAPH_KEYS):
        if role not in graph:
            raw = ('synthetic complete VIEW inventory ' + role).encode()
            address = original_inventory_fixture.A(81000 + index)
            graph[role] = {'address': address, 'runtimeHash': original_inventory_fixture.keccak256(raw)}
            runtimes[address] = '0x' + raw.hex()
    return (value, context, graph, members, registration, runtimes, documents)

# Construction copy of tools.museum.test_view_preservation_retrieval_inventory_v1._uri; only chronology/dependency aliases differ.
def _inventory_uri(value, context, graph, uri):
    row, bundle, _, _ = inventory_fixture.sources.selected(value['reference'])
    adopted = bundle['adoption']
    for entry in adopted['history']:
        if entry['profile'] == inventory_fixture.at.V2_PROFILE:
            inventory_fixture._replace_uri(entry, context, graph, uri)
    version = adopted['preservation']['registry']['version']
    inventory_fixture._bind_original_registry(adopted, context, graph, version[4], version[5])
    admitted = inventory_fixture.adoption.validate(adopted, context, {key: graph[key] for key in inventory_fixture.adoption.t.GRAPH_KEYS})
    members = inventory_fixture.membership.validate(bundle['membership'], context, graph, admitted['policyBinding'])
    admitted.update(tokenIds=members['tokenIds'], policies=members['policies'])
    for output, member in zip(bundle['output']['checkpoint']['outputs'], value['members']):
        js = inventory_fixture.dumps({'name': 'Original synthetic token ' + output[1], 'image': uri})
        output[8], output[10] = (inventory_fixture.K(js), str(len(js)))
        member['json'] = '0x' + js.hex()
        member['outputReturn'] = '0x' + inventory_fixture.encode((inventory_fixture.rt.OUTPUT,), (inventory_fixture.from_json(inventory_fixture.rt.OUTPUT, output),)).hex()
    _seal_output(bundle['output'], context, graph, admitted, coverage_timestamp=106)
    bundle['snapshot'], _, _ = _snapshot_at(context=context, graph=graph, output_value=bundle['output'], adoption=admitted, membership=members, recorded_at=107)
    bundle['root'], *_ = _root(context=context, graph=graph, snapshot_value=bundle['snapshot'], output_value=bundle['output'], published_at=109)
    row['sourceProof']['events'] = inventory_fixture.fixture._source_events(bundle, context, graph)
    sr = bundle['snapshot']['history'][0]
    rr = bundle['root']['history'][-1]
    row['publication'][1][4] = row['receipt'][1][9] = sr['receipt'][0]
    row['source'][1:6] = inventory_fixture.deepcopy([sr['receipt'], sr['source'], rr['recordHash'], rr['record'], rr['binding']])
    for sample, capture in zip(row['source'][7], row['publication'][1][7]):
        output = bundle['output']['checkpoint']['outputs'][int(sample[0])]
        sample[1] = inventory_fixture.deepcopy(output)
        capture[2:4] = output[8:10]
    inventory_fixture.seal_reference(value['reference'], context, graph)

# Construction copy of tools.museum.test_view_preservation_retrieval_inventory_v1.reseal; only chronology/dependency aliases differ.
def _inventory_reseal(value, context, graph):
    """Rehash outer plan/segments/events without correcting source-derived rows."""
    c = inventory_fixture.from_json(inventory_fixture.it.CONTEXT, value['context'])
    d = inventory_fixture.from_json(inventory_fixture.it.DEPENDENCIES, value['dependencies'])
    identifier = inventory_fixture.old.plan_id(d[6], graph['inventory']['address'], value['dependencyHash'], c)
    chain = inventory_fixture.Z
    segments = []
    for index, entry in enumerate(value['segments']):
        segment = inventory_fixture.reconstruct_segment(inventory_fixture.old.segment_key(identifier, index), entry['segment'][3], tuple((inventory_fixture.from_json(inventory_fixture.it.ITEM, row) for row in entry['items'])))
        entry['segment'] = inventory_fixture.json_values(segment)
        segments.append(segment)
        chain = inventory_fixture.append_segment(chain, index, segment)
    count = sum((len(row['items']) for row in value['segments']))
    original = (c[9], c[3][0], c[4][1][0], c[6][0][0] if c[6][0][1] == 0 else inventory_fixture.Z, c[6][0][0] if c[6][0][1] == 1 else inventory_fixture.Z, c[7], c[5][2], c[5][1])
    context_hash = inventory_fixture.K(inventory_fixture.encode((inventory_fixture.it.CONTEXT,), (c,)))
    body = (identifier, c[0][1], c[1], c[2], original, context_hash, c[10], c[20], len(segments), count, chain, inventory_fixture.Z)
    digest = inventory_fixture.old.evidence_hash(d[6], graph['inventory']['address'], value['dependencyHash'], (c[0], body))
    e = (c[0], (*body[:-1], digest))
    progress = (c[0][1], c[1], c[2], context_hash, c[20], c[20], len(segments), count, chain, 11, digest)
    native_count = sum((len(x['items']) for x in value['segments'] if x['stage'] == '0'))
    ref_count = sum((len(x['items']) for x in value['segments'] if x['stage'] == '1'))
    p = (c[0], progress, native_count, native_count, ref_count, ref_count)
    value.update(plan=inventory_fixture.json_values(p), evidence=inventory_fixture.json_values(e))
    value['recordedSource'] = {'blockHash': context['blockHash'], 'provenance': 'synthetic_fixture', 'calls': inventory_fixture.w.expected_reads(value, context, graph, c, d, p, e, segments)}
    value['events'] = [{'timestamp': str(_time(135)), 'log': {'address': desc['address'], 'topics': list(desc['topics']), 'data': desc['data'], 'blockNumber': '0x28', 'blockHash': _block_hash(40), 'transactionHash': inventory_fixture.H('retrieval inventory tx35'), 'transactionIndex': '0x0', 'logIndex': hex(index), 'removed': False}} for index, desc in enumerate(inventory_fixture.old.expected_events(value, context, graph))]

# Construction copy of tools.museum.test_view_preservation_inventory_stages_v1._original_source; only chronology/dependency aliases differ.
def _fixed_original(context, deps, subject, payload, index, authority_class, record_type, schema_name, profile_name):
    definitions = {row['name']: row for row in stage_fixture.types.definitions()}
    record = (stage_fixture.schema_id(record_type), subject, (1, stage_fixture.hex_bytes(stage_fixture.keccak256(payload)), stage_fixture.schema_id('RFC8785_JCS')), '', stage_fixture.schema_id(schema_name), stage_fixture.ZERO, (0, b'', stage_fixture.ZERO), _time(100) + index)
    receipt = (int(context['collectionId']), stage_fixture.A(84000 + index), authority_class, _time(101) + index, 0, stage_fixture.H(record_type + ' chain'), definitions[schema_name]['hash'], '0xbc33af15c6b6374052871a5fdfa255f900f56fa594f650b2d0814c681fdb35a9' if record_type == 'WORK_DESCRIPTION' else definitions[profile_name]['hash'], stage_fixture.H(record_type + ' authorization') if authority_class == 1 else stage_fixture.ZERO)
    record_hash = stage_fixture.generic_hash(int(context['chainId']), deps[0][1], deps[0][0], int(context['collectionId']), receipt[1], record)
    source = {'record': record, 'receipt': receipt, 'recordHashAt': record_hash, 'derivedRecordHash': record_hash, 'payloadHex': '0x' + payload.hex(), 'pointer': stage_fixture.A(84100 + index), 'pointerRuntime': '0x' + (b'\x00' + payload).hex()}
    return (record_hash, source, receipt)

# Construction copy of tools.museum.test_view_preservation_inventory_stages_v1._artist_source; only chronology/dependency aliases differ.
def _fixed_artist(context, deps, suite, subject, artist_id, binding_hash, generation, original_record, original_source, label):
    record, receipt = (original_source['record'], original_source['receipt'])
    signer = receipt[1]
    publication = (deps[0][1], signer, receipt[0], record[1], record[0], record[4], record[2][2], record[2][0], '0x' + record[2][1].hex(), stage_fixture.keccak256(record[3].encode()), record[7], original_record)
    statement = stage_fixture.encode(('uint16', stage_fixture.artist.PUBLICATION), (1, publication))
    attestation = (int(context['collectionId']), 7, subject, original_record, stage_fixture.schema_id('6529STREAM_ARTIST_RECORD_PUBLICATION_V1'), stage_fixture.keccak256(statement), '')
    effective = (11 + generation, _time(105), b'')
    record_hash = stage_fixture.keccak256(stage_fixture.artist.attestation_preimage(int(context['chainId']), deps[2][0], deps[0][0], attestation, artist_id, signer, 1, effective[0], effective[1]))
    evidence = (record_hash, artist_id, binding_hash, generation, signer, 1, 2, effective[1], stage_fixture.keccak256(stage_fixture.encode((stage_fixture.artist.PUBLICATION,), (publication,))))
    binding = (artist_id, stage_fixture.A(84320), stage_fixture.H(label + ' identity'), binding_hash, generation, 1, 2, 3, stage_fixture.A(84321), True)
    authority = (artist_id, signer, 1, 1)
    _, _, digest = stage_fixture.artist.signed_preimage(int(context['chainId']), deps[2][0], deps[0][0], attestation, effective[0], effective[1])
    payload = (binding, attestation, effective, statement, (signer, digest, True), effective, authority, publication, deps[1][1])
    tail = stage_fixture.encode((stage_fixture.artist.ORDINARY_PAYLOAD,), (payload,))[32:]
    snapshots = (stage_fixture.zero(stage_fixture.artist.SNAPSHOT),) * 7
    envelope = (1, stage_fixture.H('fixture coordinator config'), 24, signer, record_hash, snapshots, snapshots, tail)
    raw = stage_fixture.encode((stage_fixture.artist.ARCHIVE,), (envelope,))[32:]
    source = {'actor': signer, 'suite': suite, 'coordinatorConfigurationHash': stage_fixture.H('fixture coordinator config'), 'archiveRegistry': deps[2][0], 'archiveCoordinator': deps[2][1], 'evidenceHex': '0x' + raw.hex(), 'evidenceMetadata': (stage_fixture.keccak256(raw), stage_fixture.A(84322), len(raw), _time(106)), 'pointerRuntime': '0x' + (b'\x00' + raw).hex(), 'savedPublication': (publication, evidence, deps[1][1])}
    return (evidence, source)

# Construction copy of tools.museum.test_view_preservation_inventory_stages_v1.build_fixed_stages; only chronology/dependency aliases differ.
def _fixed_stages(value, context, graph):
    """Build exact original stages 2--6 for the complete inventory fixture."""
    from . import view_preservation_inventory_fixture_v1 as fixture
    deps = stage_fixture.from_json(stage_fixture.types.DEPENDENCIES, value['dependencies'])
    reference_row, _, _, _ = stage_fixture.inventory_sources.selected(value['reference'])
    reference_source = stage_fixture.from_json(stage_fixture.reference_types.SOURCE, reference_row['source'])
    subject = reference_source[0]
    artist_id = reference_source[2][2][3]
    association_source = reference_source[2][2]
    generation, binding_hash = (association_source[4], association_source[5])
    identity_record_hash = association_source[7]
    suite = stage_fixture._suite(deps)
    work_witness = list(stage_fixture.zero(stage_fixture.types.WORK))
    work_witness[0], work_witness[1], work_witness[3] = (subject, stage_fixture.keccak256(stage_fixture.dumps(stage_fixture.work_profile.profile())), 1)
    work_witness[5] = ('Original description unavailable', 20260921)
    work_witness = tuple(work_witness)
    work_payload = stage_fixture.references.serialize_work(work_witness)
    work_hash, work_original, work_receipt = _fixed_original(context, deps, subject, work_payload, 1, 7, 'WORK_DESCRIPTION', 'STREAM_WORK_DESCRIPTION_V1', 'STREAM_WORK_DESCRIPTION_JSON_PROFILE_V1')
    doc = (False, '', stage_fixture.ZERO)
    grant = (0, (0, '', doc), '')
    rights_witness = (subject, stage_fixture.keccak256(stage_fixture.dumps(stage_fixture.rights_profile.profile())), 0, (0, artist_id, '', stage_fixture.ZERO_ADDRESS, stage_fixture.ZERO), (grant,) * 6, 20260101, 0, True, doc, False, 0, stage_fixture.ZERO)
    rights_payload = stage_fixture.references.serialize_rights(rights_witness)
    rights_hash, rights_original, _ = _fixed_original(context, deps, subject, rights_payload, 2, 7, 'RIGHTS', 'STREAM_RIGHTS_V1', 'STREAM_RIGHTS_JSON_PROFILE_V1')
    ref = (1, stage_fixture.schema_id('RAW_BYTES'), stage_fixture.hex_bytes(stage_fixture.H('fixture statement')), 'https://example.invalid/fixture-statement')
    empty_interview_record = stage_fixture.zero(stage_fixture.conservation_source.RECORD_EVIDENCE)
    typed_empty_record = stage_fixture.zero(stage_fixture.types._witness_type('CONSERVATION_InterviewRecord'))
    waiver_witness = (subject, stage_fixture.keccak256(stage_fixture.dumps(stage_fixture.conservation_profile.profile(stage_fixture.conservation_profile.WAIVER))), stage_fixture.ZERO, (artist_id, generation, binding_hash, 0), ref, (1, typed_empty_record, ref))
    waiver_payload = stage_fixture.references.serialize_waiver(waiver_witness)
    waiver_hash, waiver_original, waiver_receipt = _fixed_original(context, deps, subject, waiver_payload, 3, 1, 'ARTIST_INTENT_WAIVER', 'STREAM_ARTIST_INTENT_WAIVER_V1', 'STREAM_ARTIST_INTENT_WAIVER_JSON_PROFILE_V1')
    publication, artist_source = _fixed_artist(context, deps, suite, subject, artist_id, binding_hash, generation, waiver_hash, waiver_original, 'fixture ARTIST_INTENT_WAIVER')
    selected_work = stage_fixture.work_selection(deps, reference_source[2][0], subject, work_hash, stage_fixture.keccak256(work_payload), work_receipt)
    descriptions = (subject, work_hash, rights_hash, stage_fixture.keccak256(work_payload), stage_fixture.keccak256(rights_payload), selected_work[21], stage_fixture.H('fixture rights selection'), 1, 1)
    record_evidence = (waiver_hash, 1, stage_fixture.keccak256(waiver_payload), waiver_receipt[1], waiver_receipt[3], waiver_receipt[2], waiver_receipt[5], stage_fixture.H('fixture waiver receipt'), publication, stage_fixture.keccak256(stage_fixture.encode((stage_fixture.artist.EVIDENCE,), (publication,))))
    association = (artist_id, binding_hash, generation, identity_record_hash)
    interview_hash = stage_fixture.H('fixture explicit interview waiver')
    conservation = (record_evidence, association, 0, 1, empty_interview_record, stage_fixture.H('fixture waiver archive reference'), 0, stage_fixture.ZERO, stage_fixture.A(84400), 1, _time(104), stage_fixture.ZERO, stage_fixture.H('fixture conservation selection'))
    _, reference_bundle, _, _ = stage_fixture.inventory_sources.selected(value['reference'])
    root_bundle = reference_bundle['root']
    root_entry = next((row for row in root_bundle['history'] if row['recordHash'] == root_bundle['selectedRecordHash']))
    root = stage_fixture.from_json(stage_fixture.stages.ROOT_RECORD, root_entry['record'])
    aggregate = stage_fixture.from_json(stage_fixture.stages.AGGREGATE, root_entry['aggregate'])
    legacy = stage_fixture.H('fixture original root family')
    signed_family = stage_fixture.keccak256(stage_fixture.encode(('bytes32', 'uint256', 'address', 'address', 'uint256', 'bytes32', stage_fixture.stages.AGGREGATE), (stage_fixture.schema_id('6529STREAM_CONTENT_ROOT_FAMILY_WITH_SCOPES_V1'), deps[6], deps[0][4], deps[0][0], int(context['collectionId']), legacy, aggregate)))
    terms = (int(context['collectionId']), deps[0][4], stage_fixture.schema_id('CONTENT_ROOT'), signed_family)
    observed = min(root[17], _time(108))
    authorization = (31, max(root[17], observed), b'')
    actor = stage_fixture.A(84401)
    approval = (actor, stage_fixture.stages._consent_digest(deps[6], deps[2][0], deps[0][0], terms, authorization), True)
    consent = stage_fixture.stages._consent_record(deps[6], deps[2][0], deps[0][0], terms, root[8], actor, 1, authorization[0], observed)
    fixture.bind_root_consent(value, context, graph, consent)
    root_entry = next((row for row in root_bundle['history'] if row['recordHash'] == root_bundle['selectedRecordHash']))
    root = stage_fixture.from_json(stage_fixture.stages.ROOT_RECORD, root_entry['record'])
    binding = (root[8], stage_fixture.A(84402), stage_fixture.H('fixture root identity'), root[10], root[9], 1, 2, 3, stage_fixture.A(84403), True)
    content_tail = stage_fixture.encode((stage_fixture.stages.CONTENT_PAYLOAD,), ((binding, terms, authorization, approval, stage_fixture.H('fixture prior content root state')),))[32:]
    snapshots = (stage_fixture.zero(stage_fixture.artist.SNAPSHOT),) * 7
    envelope = (1, stage_fixture.H('fixture coordinator config'), 17, actor, consent, snapshots, snapshots, content_tail)
    evidence = stage_fixture.encode((stage_fixture.artist.ARCHIVE,), (envelope,))[32:]
    root_source = {'rootRecord': root, 'aggregate': aggregate, 'legacyFamilyHash': legacy, 'actor': actor, 'observedAt': str(observed), 'suite': suite, 'coordinatorConfigurationHash': stage_fixture.H('fixture coordinator config'), 'archiveRegistry': deps[2][0], 'archiveCoordinator': deps[2][1], 'evidenceHex': '0x' + evidence.hex(), 'evidenceMetadata': (stage_fixture.keccak256(evidence), stage_fixture.A(84404), len(evidence), root[17]), 'pointerRuntime': '0x' + (b'\x00' + evidence).hex(), 'savedConsent': (consent, root[8], root[9], terms, 1)}
    fixture.set_context(value, descriptions, conservation, interview_hash)
    native_context = stage_fixture.from_json(stage_fixture.types.CONTEXT, value['context'])
    sources = ({'original': work_original, 'typedWitness': work_witness, 'selection': selected_work, 'artist': None}, {'original': rights_original, 'typedWitness': rights_witness}, {'original': waiver_original, 'typedWitness': waiver_witness, 'artist': artist_source}, None, root_source)
    entries = []
    for stage, source in enumerate(sources, 2):
        if stage < 6:
            rows, witness = stage_fixture.stages._typed_stage(stage, native_context, deps, source, value['documents'])
        else:
            rows = (stage_fixture.stages._root_authorization(native_context, deps, source),)
            witness = native_context[9]
        entries.append({'stage': str(stage), 'index': '0', 'items': stage_fixture.json_values(rows), 'sourceWitnessHash': witness, 'source': stage_fixture._json(source) if source is not None else None})
    return {'descriptions': stage_fixture.json_values(descriptions), 'conservation': stage_fixture.json_values(conservation), 'interviewHash': interview_hash, 'entries': entries}

# Construction copy of tools.museum.test_view_preservation_bundle_wire_v1.checkpoint; only chronology/dependency aliases differ.
def _archive_checkpoint(key, external, *, transaction_id=None, data_root=None, data_size=3, payload_digest=None, content_hash=None):
    cp = (archive_fixture.D('ARWEAVE_MAINNET'), b'block', 1, archive_fixture.D('txroot'), max(99, data_size), transaction_id or archive_fixture.D('tx'), data_root or archive_fixture.D('root'), data_size, 0, data_size, _time(80), archive_fixture.D('config'))
    record = (key, cp, archive_fixture.D('first'), archive_fixture.D('last'), b'transaction', b'data', b'last', ((archive_fixture.A(901), b'certificate'),), _time(90)) if external else (key, cp, payload_digest or archive_fixture.D('payload'), content_hash or archive_fixture.D('content'), b'transaction', b'data', ((archive_fixture.A(901), b'certificate'),), _time(90))
    value = {'verifier': archive_fixture.A(900), 'runtimeHash': archive_fixture.D('verifier runtime'), 'record': archive_fixture.raw((archive_fixture.w.EXTERNAL_NATIVE if external else archive_fixture.w.ARCHIVE_NATIVE,), (record,))}
    digest = archive_fixture.H(('address', 'bytes32', 'bytes32', 'bytes'), (value['verifier'], value['runtimeHash'], key, archive_fixture.hex_bytes(value['record'])))
    return (value, digest)

# Construction copy of tools.museum.view_preservation_retrieval_fixture_v1._archive; only chronology/dependency aliases differ.
def _archive_original(context, graph, source, media_bytes):
    artist = source[10]
    host = graph['externalCoverage']['address']
    chain = int(context['chainId'])
    digest = '0x' + retrieval_fixture.sha256(media_bytes).hexdigest()
    obj = (artist, retrieval_fixture.D('media schema'), retrieval_fixture.H('RAW_BYTES'), retrieval_fixture.K(media_bytes), digest, retrieval_fixture.D('Arweave data root'), len(media_bytes), retrieval_fixture.D('media format'), retrieval_fixture.D('format catalogue'), retrieval_fixture.D('format catalogue bytes'))
    object_key = retrieval_fixture.archive.external_object_hash(obj, chain, host, context['core'])
    writer = retrieval_fixture.A(99102)
    family = (retrieval_fixture.D('institutional family id'), retrieval_fixture.D('institutional network'), retrieval_fixture.D('institutional protocol'), retrieval_fixture.D('institutional addressing'), retrieval_fixture.D('institutional custodian'), retrieval_fixture.D('institutional funding'), retrieval_fixture.D('institutional retrieval'), retrieval_fixture.D('institutional jurisdiction'), 2, writer, retrieval_fixture.H('STREAM_INSTITUTIONAL_EXTERNAL_OBJECT_POSSESSION_V1'))
    families = (retrieval_fixture.D('endowed original family'), retrieval_fixture.archive._domain('6529STREAM_EXTERNAL_ARCHIVE_FAMILY_V1', ('uint256', 'address', retrieval_fixture.t.ARCHIVE_FAMILY), (chain, host, family)))
    native_key = retrieval_fixture.D('native checkpoint ' + object_key)
    transaction = retrieval_fixture._transaction(media_bytes)
    uri = source[9]
    locators = (retrieval_fixture.hex_bytes(transaction), uri.encode('utf-8'))
    receipts, fixities, receipt_keys, fixity_keys, hashes = ([], [], [], [], [])
    for index, (family_key, location) in enumerate(zip(families, locators)):
        receipt = (object_key, family_key, retrieval_fixture.K(location), retrieval_fixture.H('CONTENT_ADDRESSED_INCLUSION' if index == 0 else 'ATTESTED_POSSESSION'), retrieval_fixture.D('endowed proof') if index == 0 else retrieval_fixture.H('STREAM_INSTITUTIONAL_EXTERNAL_OBJECT_POSSESSION_V1'), native_key if index == 0 else retrieval_fixture.D('institutional proof'), retrieval_fixture.A(99101) if index == 0 else writer, _time(110), index, int(context['timestamp']) + 100)
        key = retrieval_fixture.archive._domain('6529STREAM_EXTERNAL_RECEIPT_V1', ('uint256', 'address', retrieval_fixture.archive.RECEIPT), (chain, host, receipt))
        receipt_keys.append(key)
        raw = retrieval_fixture.encode((retrieval_fixture.archive.RECEIPT, 'bytes', 'bytes'), (receipt, location, b'synthetic retained receipt signature'))
        receipts.append('0x' + raw.hex())
        hashes.append(retrieval_fixture._hash(('bytes32', 'bytes'), (key, raw)))
        fixity = (key, object_key, family_key, retrieval_fixture.K(location), retrieval_fixture.D('fixity profile'), digest, digest, obj[3], obj[3], obj[5], obj[5], obj[6], obj[6], _time(111), 1, retrieval_fixture.D('fixity report'), retrieval_fixture.Z, retrieval_fixture.Z, retrieval_fixture.A(99200 + index), index, int(context['timestamp']) + 100)
        fkey = retrieval_fixture.archive._domain('6529STREAM_EXTERNAL_FIXITY_V1', ('uint256', 'address', retrieval_fixture.archive.EXTERNAL_FIXITY), (chain, host, fixity))
        fixity_keys.append(fkey)
        body = retrieval_fixture.encode((retrieval_fixture.archive.EXTERNAL_FIXITY, 'bytes'), (fixity, b'synthetic retained fixity signature'))
        fixities.append('0x' + body.hex())
    for key, body in zip(fixity_keys, fixities):
        hashes.append(retrieval_fixture._hash(('bytes32', 'bytes'), (key, retrieval_fixture.hex_bytes(body))))
    native, native_hash = _archive_checkpoint(native_key, True, transaction_id=transaction, data_root=obj[5], data_size=obj[6], payload_digest=digest, content_hash=obj[3])
    hashes.append(native_hash)
    coverage = (retrieval_fixture.Z, object_key, artist, *obj[3:7], *families, *receipt_keys, *fixity_keys, native_key, retrieval_fixture.archive.EXTERNAL_PROFILE)
    coverage = (retrieval_fixture.archive.external_coverage_hash(coverage, chain, host), *coverage[1:])
    commitment = retrieval_fixture._hash(('address', 'bytes32', retrieval_fixture.it.ADMISSION[3], ('bytes32',) * 5), (host, graph['externalCoverage']['runtimeHash'], coverage, tuple(hashes)))
    admission = ((1, coverage[0], object_key), commitment, retrieval_fixture.Z, coverage, retrieval_fixture.zero(retrieval_fixture.it.ADMISSION[4]))
    evidence = {'object': retrieval_fixture.json_values(obj), 'receipts': receipts, 'fixities': fixities, 'checkpoint': native}
    pair = (*coverage[1:11], coverage[11], coverage[12], *coverage[13:])
    return (obj, admission, evidence, pair, family, transaction)

# Construction copy of tools.museum.view_preservation_retrieval_fixture_v1.supplied; only chronology/dependency aliases differ.
def _retrieval(*, count=1, burned=False, route='direct'):
    """Return a complete direct-HTTPS retrieval fixture and exact parent inputs."""
    require_route = route in ('direct', 'redirect', 'mirror', 'manifest')
    if not require_route:
        raise ValueError('unsupported retrieval fixture route')
    primary_transaction = retrieval_fixture._transaction(retrieval_fixture.MEDIA_BYTES)
    manifest_transaction = retrieval_fixture._transaction(retrieval_fixture.MANIFEST_BYTES)
    requested_uri = 'https://example.invalid/master.png' if route == 'direct' else 'https://origin.invalid/master.png' if route in ('redirect', 'mirror') else retrieval_fixture._ar(manifest_transaction) + '/master.png'
    inventory, context, graph, witness, configuration = retrieval_fixture.inventory_supplied(requested_uri, count=count, burned=burned)
    shared = retrieval_fixture.archive._Originals(context, graph)
    _, inventory_result = retrieval_fixture.inventory_wire.validate(inventory, context, graph, witness, configuration, originals=shared)
    source = retrieval_fixture.from_json(retrieval_fixture.t.SOURCE, inventory_result['retrievalSource'])
    source_row, source_bundle, _, snapshot_row = retrieval_fixture.sources.selected(inventory['value']['reference'])
    source_proof = retrieval_fixture.deepcopy(source_row['sourceProof'])
    obj, admission, evidence, pair, family, _ = retrieval_fixture._archive(context, graph, source, retrieval_fixture.MEDIA_BYTES)
    resolved_uri = requested_uri
    steps, manifest_evidence = ((), [])
    if route in ('redirect', 'mirror'):
        resolved_uri = retrieval_fixture._ar(primary_transaction)
        steps = ((1 if route == 'redirect' else 2, requested_uri, resolved_uri, 302 if route == 'redirect' else 0, retrieval_fixture.Z, retrieval_fixture.Z, b''),)
    elif route == 'manifest':
        resolved_uri = retrieval_fixture._ar(primary_transaction)
        manifest_obj, manifest_admission, manifest_source, manifest_pair, manifest_family, _ = retrieval_fixture._archive(context, graph, source, retrieval_fixture.MANIFEST_BYTES)
        steps = ((3, requested_uri, resolved_uri, 0, manifest_admission[3][1], manifest_admission[3][0], retrieval_fixture.MANIFEST_BYTES),)
        manifest_evidence = [{'admission': retrieval_fixture.json_values(manifest_admission), 'sourceEvidence': manifest_source, 'currentPair': retrieval_fixture.json_values(manifest_pair), 'secondFamily': {'family': retrieval_fixture.json_values(manifest_family), 'status': '1', 'revision': '1'}}]
    second = retrieval_fixture.decode((retrieval_fixture.archive.RECEIPT, 'bytes', 'bytes'), retrieval_fixture.hex_bytes(evidence['receipts'][1]), maximum=65536)[0]
    observed_at, deadline, nonce = (_time(120), _time(139), 17)
    observation = (source, obj, admission[3], steps, resolved_uri, second[6], observed_at, nonce, deadline)
    raw = retrieval_fixture.encode((retrieval_fixture.t.OBSERVATION, 'bytes'), (observation, b'synthetic historical Safe signature'))
    receipt = [retrieval_fixture.Z, retrieval_fixture.wire.source_key(source), retrieval_fixture.wire.observation_hash(configuration, witness['address'], observation), admission[3][1], admission[3][0], second[6], _time(136), retrieval_fixture.K(raw), len(raw)]
    receipt[0] = retrieval_fixture.wire.record_hash(configuration, witness['address'], receipt)
    log = {'address': witness['address'], 'topics': [retrieval_fixture.t.RECORDED_TOPIC, receipt[0], receipt[1], '0x' + retrieval_fixture.encode(('address',), (receipt[5],)).hex()], 'data': '0x' + retrieval_fixture.encode((retrieval_fixture.t.RECEIPT,), (tuple(receipt),)).hex(), 'blockNumber': '0x29', 'blockHash': _block_hash(41), 'transactionHash': retrieval_fixture.D('transaction36'), 'transactionIndex': '0x0', 'logIndex': '0x0', 'removed': False}
    current = {'checkpointSource': retrieval_fixture.deepcopy(source_bundle['output']['checkpoint']['source']), 'artistPresentation': retrieval_fixture.deepcopy(snapshot_row['source'][2]), 'admission': retrieval_fixture.json_values(admission), 'sourceEvidence': evidence, 'currentPair': retrieval_fixture.json_values(pair), 'secondFamily': {'family': retrieval_fixture.json_values(family), 'status': '1', 'revision': '1'}, 'manifestEvidence': manifest_evidence}
    record = {'recordHash': receipt[0], 'receipt': retrieval_fixture.json_values(tuple(receipt)), 'payloadHex': '0x' + raw.hex(), 'publication': {'log': log, 'timestamp': str(_time(136))}, 'revocation': None, 'current': current, 'status': 'operative', 'nativeState': {'revoked': False, 'nonceUsed': True}}
    dependencies = (tuple((graph[key]['address'] for key in retrieval_fixture.archive.DEPENDENCY_ROLES)), tuple((graph[key]['runtimeHash'] for key in retrieval_fixture.archive.DEPENDENCY_ROLES)), int(context['chainId']), 100000, 8000000)
    retrieval = {'sourceRevision': retrieval_fixture.t.SOURCE_REVISION, 'profile': retrieval_fixture.t.PROFILE, 'witness': witness, 'configuration': retrieval_fixture.json_values(configuration), 'configurationHash': retrieval_fixture.wire.configuration_hash(configuration), 'bundleDependencies': retrieval_fixture.json_values(dependencies), 'records': [record], 'scopeEpochs': [{'scope': retrieval_fixture.json_values(source[0]), 'epoch': '0'}], 'itemBindings': [], 'historyCoverage': {'retainedRecordCount': 1, 'retainedRevocationCount': 0, 'eventHistoryCompleteness': 'bounded_retained_rows'}, 'sourceBindings': None}
    retrieval_fixture.wire._record_call(shared, witness['address'], 'record(bytes32)', ('bytes32',), (receipt[0],), (retrieval_fixture.t.RECEIPT,), (tuple(receipt),))
    retrieval_fixture.wire._record_call(shared, witness['address'], 'encoded(bytes32)', ('bytes32',), (receipt[0],), ('bytes',), (raw,))
    retrieval_fixture.wire._record_call(shared, witness['address'], 'revoked(bytes32)', ('bytes32',), (receipt[0],), ('bool',), (False,))
    retrieval_fixture.wire._record_call(shared, witness['address'], 'nonceUsed(bytes32)', ('bytes32',), (retrieval_fixture.wire.nonce_key(receipt[5], nonce),), ('bool',), (True,))
    retrieval_fixture.wire._record_call(shared, configuration[4], 'currentSource((uint8,uint256,uint256,bytes32))', (retrieval_fixture.t.SCOPE,), (source[0],), (retrieval_fixture.wire.output_types.SOURCE,), (retrieval_fixture.from_json(retrieval_fixture.wire.output_types.SOURCE, current['checkpointSource']),))
    artist = retrieval_fixture.from_json(retrieval_fixture.t.ARTIST_PRESENTATION, current['artistPresentation'])
    retrieval_fixture.wire._record_call(shared, configuration[2], 'artistPresentation(uint256)', ('uint256',), (source[0][1],), (retrieval_fixture.t.ARTIST_PRESENTATION,), (artist,))
    actual, transformed, current_observation, route = retrieval_fixture.wire._archive_current(current, observation, context, graph, dependencies, tuple(receipt), witness, configuration, retrieval['configurationHash'], shared)
    retrieval_fixture.wire._record_call(shared, witness['address'], 'requireCorrespondence(bytes32)', ('bytes32',), (receipt[0],), (retrieval_fixture.t.SOURCE, retrieval_fixture.t.RECEIPT, retrieval_fixture.it.ADMISSION), (source, tuple(receipt), actual))
    retrieval_fixture.wire._record_call(shared, witness['address'], 'revocationEpoch((uint8,uint256,uint256,bytes32))', (retrieval_fixture.t.SCOPE,), (source[0],), ('uint64',), (0,))
    operative = {'source': source, 'receipt': tuple(receipt), 'admission': actual, 'transformed': transformed, 'currentObservation': current_observation, 'route': route}
    item = retrieval_fixture.wire.obligation_item(source)
    index = next((i for i, row in enumerate(inventory_result['items']) if row == item))
    artifact_environment = (retrieval_fixture.D('onchain environment'), 1)
    external_environment = (retrieval_fixture.D('external environment'), 1)
    original_environment = retrieval_fixture.archive.environment_hash(dependencies, *artifact_environment, *external_environment)
    saved = (actual[0], transformed, *actual[2:])
    binding = {'planId': inventory_result['planId'], 'index': str(index), 'item': retrieval_fixture.json_values(item), 'witnessRecordHash': receipt[0], 'savedAdmission': retrieval_fixture.json_values(saved), 'originalEnvironment': original_environment, 'environmentHash': retrieval_fixture.wire.environment_hash(original_environment, witness['address'], witness['runtimeHash'], source[0], 0), 'currentObservation': current_observation, 'environment': {'dependencies': retrieval_fixture.json_values(dependencies), 'artifact': retrieval_fixture.json_values(artifact_environment), 'external': retrieval_fixture.json_values(external_environment)}, 'sourceBindings': None}
    calls = retrieval_fixture.inventory_wire.item_binding_reads(binding, inventory_result, context, graph, witness, 0)
    binding['sourceBindings'] = {'blockHash': context['blockHash'], 'provenance': inventory_result['provenance'], 'calls': calls}
    retrieval_fixture.inventory_wire.validate_item_binding(binding, inventory_result, context, graph, witness, configuration, operative, 0, originals=shared)
    retrieval['itemBindings'] = [binding]
    retrieval['sourceBindings'] = {'blockHash': context['blockHash'], 'provenance': inventory_result['provenance'], 'calls': retrieval_fixture.deepcopy(shared.calls)}
    return {'retrieval': retrieval, 'context': context, 'graph': graph, 'inventory': inventory, 'sourceProof': source_proof, 'mediaBytesByRecord': {receipt[0]: '0x' + retrieval_fixture.MEDIA_BYTES.hex()}, '_shared': shared, '_inventoryResult': inventory_result, '_admission': admission, '_observation': observation, '_receipt': tuple(receipt)}
