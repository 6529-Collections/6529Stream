"""Supplied original scoped factory V2 snapshot/reference commitments.

No RPC, execution, current authority, archive liveness or complete rendering is
proved here. Original full Policy rows do not reveal their configuration-hash
preimage; terminal admission is independently retained as a commitment.
"""
from hashlib import sha256

from .canonical import hex_bytes, keccak256, schema_id, subject_id
from .chain_abi import encode, decode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require
from .native_finality_wire import from_json, _hash
from .scoped_static_snapshot_wire import _uri, membership_hash, selection_id, _descriptor, scope_subject, _scope
from .public_prospective_reference_source import environment_bytes
from .scoped_policy_preservation_types_v2 import *
from . import scoped_policy_content_wire_v2 as content_wire

from .policy_preservation_wire_v2 import (_closed, _n, _addr, _deps, policy_plan,
    policy_component, policy_chain, _lock, _coverage, _readiness)

SNAPSHOT_KEYS = ('core', 'metadata', 'schemas', 'store', 'router', 'scopeMembership',
                 'staticSelection', 'policyContent', 'outputManifest', 'artifacts', 'entropySourceSet')
REFERENCE_KEYS = ('core', 'metadata', 'schemas', 'store', 'router', 'policySnapshot', 'externalCoverage')
POLICY_KEYS = ('core', 'metadata', 'scopeMembership', 'coordinatorInventory')
SNAPSHOT_HASHES = tuple(keccak256(v) for v in (SNAPSHOT_SCHEMA_BYTES, SNAPSHOT_PROFILE_BYTES, SNAPSHOT_CANON_BYTES))
REFERENCE_HASHES = tuple(keccak256(v) for v in (REFERENCE_SCHEMA_BYTES, REFERENCE_PROFILE_BYTES, REFERENCE_CANON_BYTES))
SOURCE_SET_PROFILE = schema_id('6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2')
QUALIFICATION = [
    'Exact supplied scoped factory V2 publication, receipt, canonical payload, history and lock commitments are checked; no source authentication or historical execution is proved.',
    'Full original policy/status fields are retained. Policy configuration and terminal-program-admission preimages remain hash-only unless separately evidenced.',
    'Original HTML and environment bytes are retained; complete token JSON, tokenData, renderer/source bytes, browser execution and ZIP membership are not reconstructed.',
    'Saved external object/coverage identities are checked; historical or current fixity, archive liveness and consensus are not proved.',
    'Current head and immutable selected original are distinct; current requireCurrent or current grants never replace original records.',
    'The standalone preservation groups check scoped root state/route commitments; the root record hash and historical aggregate require the separately validated complete content group.',
    'Original scoped factory V2 TOKEN/RELEASE/SEASON only. COLLECTION, V1, CurrentAuthority factory and VIEW need their own codecs.',
]


def definitions():
    rows = []
    for prefix, label in (('SNAPSHOT', 'SNAPSHOT'), ('REFERENCE', 'REFERENCE')):
        for suffix, kind, name in (('SCHEMA', 0, 'STREAM_SCOPED_POLICY_' + label + '_ABI_V2'),
                                  ('PROFILE', 2, 'STREAM_SCOPED_POLICY_' + label + '_PROFILE_V2'),
                                  ('CANON', 1, 'STREAM_ABI_SCOPED_POLICY_' + label + '_V2')):
            raw = globals()[prefix + '_' + suffix + '_BYTES']
            rows.append({'name': name, 'id': schema_id(name), 'kind': kind, 'hash': keccak256(raw), 'bytes': raw})
    for name, kind in (('STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1',0), ('STREAM_REFERENCE_PNG_OBJECT_V1',0),
                       ('STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1',0), ('STREAM_REFERENCE_NATIVE_FORMATS_V1',2)):
        raw = globals()[name + '_BYTES']
        rows.append({'name':name, 'id':schema_id(name), 'kind':kind, 'hash':keccak256(raw), 'bytes':raw})
    return tuple(rows)


def source_hash(source, dependencies, context, graph):
    return _hash('6529STREAM_SCOPED_POLICY_SNAPSHOT_SOURCES_V2',
        ('uint256', 'address', ADDRESS11, HASH11, SNAPSHOT_SOURCE),
        (_n(context['chainId']), _addr(graph, 'policySnapshot'), dependencies[0], dependencies[1], source))


def snapshot_payload(p, r, source, dependencies, context, graph):
    p, r = list(p), list(r)
    p[6] = ZERO
    for i in (0, 4, 5): r[i] = ZERO
    for i in (6, 13): r[i] = 0
    return encode(SNAPSHOT_ENVELOPE, (schema_id('6529STREAM_SCOPED_POLICY_SNAPSHOT_PAYLOAD_V2'),
        _n(context['chainId']), _addr(graph, 'policySnapshot'), dependencies[0], dependencies[1], tuple(p), tuple(r), source))


def snapshot_hash(p, r, context, graph):
    r = list(r); r[0] = r[4] = ZERO
    return _hash('6529STREAM_SCOPED_POLICY_SNAPSHOT_RECORD_V2',
        ('uint256', 'address', 'address', 'address', SNAPSHOT_PUBLICATION, SNAPSHOT_RECEIPT),
        (_n(context['chainId']), _addr(graph, 'policySnapshot'), context['core'], _addr(graph, 'metadata'), p, tuple(r)))


def snapshot_chain(scope, previous, r, context, graph):
    return _hash('6529STREAM_SCOPED_POLICY_SNAPSHOT_CHAIN_V2',
        ('uint256', 'address', 'address', SCOPE, 'bytes32', 'uint64', 'bytes32'),
        (_n(context['chainId']), _addr(graph, 'policySnapshot'), context['core'], scope, previous, r[3], r[0]))


def source_set_commitments(source, dependencies, graph):
    source = from_json(SNAPSHOT_SOURCE,source)
    d = from_json(POLICY_DEPS,dependencies)
    inventory,pin = _addr(graph,'tokenInventory'),graph['tokenInventory']['runtimeHash']
    e = source[9]
    return {'moduleVersion': SOURCE_SET_PROFILE,
            'manifestHash': keccak256(encode(('bytes32',POLICY_DEPS,'address','bytes32'),
                (SOURCE_SET_PROFILE,d,inventory,pin))),
            'dataHash': keccak256(encode(('bytes32',SCOPE,'bytes32','bytes32','bytes32',MEMBERSHIP_FACTS,'address','bytes32'),
                (SOURCE_SET_PROFILE,source[0],e[0],e[1],e[2],source[1],inventory,pin)))}


def reference_component(receipt, lock, scope, context, graph):
    receipt,lock = from_json(REFERENCE_RECEIPT,receipt),from_json(REFERENCE_LOCK,lock)
    return {'moduleVersion':schema_id('STREAM_SCOPED_POLICY_REFERENCE_RENDER_IMPLEMENTATION_V2'),
            'manifestHash':REFERENCE_HASHES[1],
            'dataHash':_hash('6529STREAM_LOCKED_SCOPED_POLICY_REFERENCE_COMPONENT_V2',
                ('uint256','address','address',SCOPE,REFERENCE_RECEIPT,REFERENCE_LOCK),
                (_n(context['chainId']),_addr(graph,'policyReference'),context['core'],scope,receipt,lock))}


def _policies(source, dependencies, context):
    scope, facts, e = source[0], source[1], source[9]
    require(e[0] == policy_plan(scope, facts, dependencies, context) and e[1] != ZERO
            and e[3] == len(e[5]) and 0 < e[3] <= min(MAX_POLICIES, facts[3]) and e[4],
            'policy complete original coordinator denominator')
    seen, previous = set(), -1
    for index, row in enumerate(e[5]):
        require(row[0] != ZERO_ADDRESS and row[0] not in seen and row[1] != ZERO and row[3]
                and (row[2] == 0 if index == 0 else row[2] > previous) and row[2] < facts[3]
                and all(row[i] != ZERO for i in (4, 5, 6, 7, 8, 12)), 'policy original row/order')
        seen.add(row[0]); previous = row[2]
        p = row[14]
        if row[13]:
            require(p[:3] == (True, True, True) and p[3] <= 2 and p[4] <= 1 and p[5] <= 1
                    and p[6] > 0 and p[8] == row[8] and p[10] != ZERO and p[11] != ZERO
                    and p[9] == _hash('6529STREAM_ENTROPY_CONFIGURATION_V1', ('bytes32', 'bool'), (p[8], p[2]))
                    and row[9:12] == (ZERO_ADDRESS, 0, ZERO), 'policy explicit V2 fields')
        else:
            require(p == (False, False, False, 0, 0, 0, 0, 0, ZERO, ZERO, ZERO, ZERO)
                    and row[9] != ZERO_ADDRESS and row[10] > 0 and row[11] != ZERO,
                    'policy legacy branch has no fabricated explicit fields')
        require(row[12] == policy_component(row, scope, context), 'policy component preimage')
    require(e[2] == policy_chain(e, scope, dependencies, context), 'policy full V2 chain hash')


def _source(source, deps, policy_deps, context, graph, recorded_at, content_result):
    scope, facts, artist, selection, content, outputs, factory, factory_hash, factory_deps_hash, entropy = source
    _scope(scope, context)
    require(facts[0] == scope_subject(scope, context) and 0 < facts[3] <= 818
            and facts[6:] == (0, ZERO)
            and facts[5] == membership_hash(facts, scope, context, graph), 'policy scoped membership')
    if scope[0] == 1:
        require(facts[1:3] == (ZERO, ZERO) and facts[3] == 1
                and facts[4] == keccak256(encode(('uint256',), (scope[2],))), 'policy TOKEN membership')
    else:
        require(all(facts[i] != ZERO for i in (1, 2, 4)), 'policy RELEASE/SEASON original membership')
    require((factory, factory_hash) == (_addr(graph, 'sourceFactory'), graph['sourceFactory']['runtimeHash'])
            and factory_deps_hash == keccak256(encode((POLICY_DEPS,), (policy_deps,))),
            'policy original factory identity/dependencies')
    require(artist[0] and artist[1] != ZERO_ADDRESS and artist[6] != ZERO_ADDRESS
            and all(artist[i] != ZERO for i in (2, 3, 5, 7, 8, 11)) and artist[4] > 0
            and 0 < artist[9] <= artist[10] <= recorded_at, 'policy original locked Artist')
    require(artist[1:3] == (_addr(graph,'artist'),graph['artist']['runtimeHash']), 'policy original Artist runtime graph')
    require(selection[0] == content[4] == outputs[11] == scope and selection[1] == facts[5]
            and selection[2] != ZERO and selection[5] != ZERO
            and selection[3] == selection[4] == content[5] == content[6] == outputs[12] == facts[3],
            'policy complete original selection/output counts')
    require(content[0] == selection_id(selection, context, graph)
            and content[1] == keccak256(encode((SELECTION_PLAN,), (selection,)))
            and content[7] != ZERO and content[8:10] == outputs[8:10]
            and outputs[1] == keccak256(encode((CONTENT_PLAN,), (content,)))
            and outputs[2] == deps[0][10] and outputs[7] == artist[3]
            and all(outputs[i] != ZERO for i in (0, 1, 3, 4, 5, 6, 8, 9, 10))
            and outputs[13] == 576 + 640 * facts[3], 'policy content/output source commitments')
    _policies(source, policy_deps, context)
    require(content[2:4] == outputs[3:5] == entropy[1:3], 'policy source-set commitment join')
    if content_result is not None:
        for key, value in (('contentPlan', content), ('outputManifest', outputs), ('selectionPlan', selection)):
            require(content_result[key] == json_values(value), 'policy verified content ' + key)
        rows = content_result.get('selectionRows')
        if rows is not None:
            observed = {}
            for index, raw in enumerate(rows):
                row = from_json(SELECTION_ROW, raw)
                require(row[6][3] not in observed or observed[row[6][3]][0] == row[7][3], 'policy repeated coordinator runtime')
                observed.setdefault(row[6][3], (row[7][3], index))
            require([(p[0], p[1], p[2]) for p in entropy[5]] ==
                    [(a, pin, i) for a, (pin, i) in observed.items()], 'policy first-occurrence coordinator/selection join')
        outputs = content_result.get('outputs')
        require(rows is not None and outputs is not None and len(rows) == len(outputs) == facts[3],
                'policy complete selection/output rows missing')
        from .scoped_policy_content_types_v2 import OUTPUT
        policies = {row[0]:row for row in entropy[5]}
        for raw_row,raw_output in zip(rows,outputs):
            row,output = from_json(SELECTION_ROW,raw_row),from_json(OUTPUT,raw_output)
            require(output[4][0] == row[6][3] and output[4][1] == row[7][3]
                    and output[4][0] in policies, 'policy output original coordinator')
            _readiness(output[4],policies[output[4][0]],output[5])


def validate_snapshot(bundle, context, graph, content_result=None):
    s = _closed(bundle, ('dependencies', 'entropyDependencies', 'publication', 'receipt', 'source',
                        'payload', 'lock', 'head', 'history'), 'policy snapshot')
    require(_addr(graph, 'core') == context['core'], 'policy Core identity')
    d = _deps(s['dependencies'], SNAPSHOT_DEPS, SNAPSHOT_KEYS, context, graph)
    require(d[4] <= (1 << 32)-1, 'policy snapshot source gas bound')
    pd = _deps(s['entropyDependencies'], POLICY_DEPS, POLICY_KEYS, context, graph)
    p, r, source = (from_json(k, s[key]) for k, key in (
        (SNAPSHOT_PUBLICATION, 'publication'), (SNAPSHOT_RECEIPT, 'receipt'), (SNAPSHOT_SOURCE, 'source')))
    scope = _scope(p[0], context)
    _source(source, d, pd, context, graph, r[13], content_result)
    require(p[5:7] == (source[9][0], r[7]) and p[4] != ZERO and source[0] == scope
            and r[7] == source_hash(source, d, context, graph), 'policy snapshot original source selection')
    if content_result is not None:
        require(p[4] == content_result['manifestRecordHash'], 'policy snapshot actual output record')
    raw = hex_bytes(s['payload'])
    require(0 < len(raw) <= MAX_PAYLOAD and raw == snapshot_payload(p, r, source, d, context, graph)
            and r[5:7] == (keccak256(raw), len(raw)), 'policy snapshot exact payload/hash')
    require(type(s['history']) is list and 0 < len(s['history']) <= MAX_HISTORY, 'policy snapshot history bound')
    previous, chain, when, ids, selected = ZERO, ZERO, 0, set(), False
    for index, entry in enumerate(s['history']):
        _closed(entry, ('publication', 'receipt'), 'policy snapshot history row')
        hp, hr = from_json(SNAPSHOT_PUBLICATION, entry['publication']), from_json(SNAPSHOT_RECEIPT, entry['receipt'])
        require(hp[0] == scope and hp[1] != ZERO and hp[1] not in ids and hp[2:4] == (previous, index)
                and all(hp[i] != ZERO for i in (4, 5, 6, 9)) and 0 < hp[8] <= hr[13],
                'policy snapshot publication lineage/time')
        _uri(hp[7]); ids.add(hp[1])
        require(hr[1:4] == (scope_subject(scope, context), previous, index+1) and hr[8] != ZERO_ADDRESS
                and hr[9] in (7, 8) and hr[10] > 0 and hr[11] in (7, 8) and hr[12] > 0
                and 0 < hr[6] <= MAX_PAYLOAD and hr[5] != ZERO and hr[7] == hp[6]
                and when <= hr[13] <= _n(context['timestamp']) and hr[13] > 0 and hr[14:] == SNAPSHOT_HASHES,
                'policy snapshot original receipt authority/time/definitions')
        require(hr[0] == snapshot_hash(hp, hr, context, graph)
                and hr[4] == snapshot_chain(scope, chain, hr, context, graph), 'policy snapshot record/chain')
        if hr[0] == r[0]:
            require((hp, hr) == (p, r), 'policy selected original snapshot equality'); selected = True
        previous, chain, when = hr[0], hr[4], hr[13]
    require(selected and s['head'] == previous, 'policy snapshot selected original/current head')
    lock = _lock(s['lock'], s['head'], r[0], r[3], r[13], context, 'snapshot')
    return {'publication': json_values(p), 'receipt': json_values(r), 'source': json_values(source),
            'lock': json_values(lock), 'head': s['head'], 'membership': json_values(source[1]),
            'entropy': json_values(source[9]),
            'sourceSet': d[0][10], 'sourceSetCodeHash': d[1][10], 'sourceSetProfile': SOURCE_SET_PROFILE}


def reference_source_hash(source, dependencies, context, graph):
    return _hash('6529STREAM_SCOPED_POLICY_REFERENCE_SOURCES_V2',
        ('uint256', 'address', ADDRESS7, HASH7, REFERENCE_SOURCE),
        (_n(context['chainId']), _addr(graph, 'policyReference'), dependencies[0], dependencies[1], source))


def reference_payload(p, r, source, environment, context, graph):
    observation, record = list(p[1]), list(r[1]); observation[6] = ZERO
    for i in (0, 1, 6): record[i] = ZERO
    for i in (7, 15): record[i] = 0
    return encode(REFERENCE_ENVELOPE, (schema_id('6529STREAM_SCOPED_POLICY_REFERENCE_PAYLOAD_V2'),
        _n(context['chainId']), _addr(graph, 'policyReference'), (p[0], tuple(observation)),
        (r[0], tuple(record)), source, environment))


def reference_hash(p, r, context, graph):
    record = list(r[1]); record[0] = record[1] = ZERO
    return _hash('6529STREAM_SCOPED_POLICY_REFERENCE_RECORD_V2',
        ('uint256', 'address', 'address', 'address', REFERENCE_PUBLICATION, REFERENCE_RECEIPT),
        (_n(context['chainId']), _addr(graph, 'policyReference'), context['core'], _addr(graph, 'metadata'), p, (r[0], tuple(record))))


def reference_chain(previous, r, context, graph):
    return _hash('6529STREAM_SCOPED_POLICY_REFERENCE_CHAIN_V2',
        ('uint256', 'address', 'address', 'bytes32', 'bytes32', 'uint64', 'bytes32'),
        (_n(context['chainId']), _addr(graph, 'policyReference'), context['core'], r[0], previous, r[1][5], r[1][0]))


def _samples(p, r, source, objects, context, graph, content_result):
    captures, environment, samples = p[1][7], p[1][8], source[7]
    count, artist = source[2][1][3], source[2][2][3]
    require(len(captures) == len(samples) == (1 if count == 1 else 2), 'policy exact first/last sample count')
    _coverage(source[6], objects[source[6][1]], context, graph, artist, 'zip')
    require(source[6][:2] == (environment[1], environment[0]), 'policy environment coverage selection')
    used = {source[6][1]}
    policies = {row[0]: row for row in source[2][9][5]}
    for index, (capture, sample) in enumerate(zip(captures, samples)):
        ordinal, facts, row, entropy, terminal_hash = sample
        require(ordinal == (0 if index == 0 else count-1) and facts[0] == capture[0] == row[0] > 0
                and facts[1] == capture[1] > 0 and facts[2] == row[6][3] == entropy[0]
                and row[7][3] == entropy[1] and entropy[0] in policies, 'policy sample identity/ordinal/coordinator')
        policy = policies[entropy[0]]
        _readiness(entropy,policy,terminal_hash)
        require(facts[3] == entropy[9] and facts[5] <= 16384 and facts[4] != ZERO
                and facts[6:9] == (capture[2], capture[3], capture[4])
                and 0 < len(capture[5]) == capture[4] <= 40960 and keccak256(capture[5]) == capture[3]
                and '0x' + sha256(capture[5]).hexdigest() == capture[8]
                and capture[9][0] != ZERO and capture[9][0] == capture[9][1]
                and capture[10] == environment[2] and 0 < capture[11] <= r[1][15], 'policy original sample byte commitments')
        require(facts[9][:2] == (capture[7], capture[6]) and facts[9][4] == capture[9][0], 'policy sample capture coverage')
        _coverage(facts[9], objects[facts[9][1]], context, graph, artist, 'png'); used.add(facts[9][1])
        require(row[5][0] != ZERO_ADDRESS and row[5][3] != ZERO_ADDRESS
                and all(v != ZERO for i, v in enumerate(row[5]) if i not in (0, 3)), 'policy immutable STATIC renderer selection')
        if content_result is not None:
            require(content_result['tokenIds'][ordinal] == str(capture[0]), 'policy sample complete membership join')
            output_rows = content_result.get('outputs')
            require(output_rows is not None, 'policy verified complete outputs required for reference samples')
            from .scoped_policy_content_types_v2 import OUTPUT
            output = from_json(OUTPUT, output_rows[ordinal])
            require(output[0][0] == capture[0] and output[0][1] == capture[2]
                    and output[0][3] == capture[3] == output[3] and output[0][5] == facts[4]
                    and output[4] == entropy and output[5] == terminal_hash
                    and output[1] == _hash('6529STREAM_STATIC_SELECTION_ROW_V1',
                        ('uint256', 'address', 'address', SELECTION_ROW),
                        (_n(context['chainId']), context['core'], _addr(graph, 'router'), row)), 'policy sample complete output join')
    require(set(objects) == used, 'policy archive object denominator')


def _root(source, snapshot_result, context, graph, content_result, recorded_at):
    scope, facts, artist, _, _, outputs, factory, factory_hash, factory_deps, entropy = source[2]
    receipt = from_json(SNAPSHOT_RECEIPT, snapshot_result['receipt'])
    root, binding = source[4:6]
    require(source[3] != ZERO and root[0][0] == scope and root[0][2:4] == (receipt[0], receipt[3])
            and root[1:5] == (_addr(graph,'policySnapshot'),graph['policySnapshot']['runtimeHash'],receipt[5],receipt[7])
            and root[5:11] == (outputs[8],facts[3],outputs[10],artist[3],artist[4],artist[5])
            and root[11] != ZERO_ADDRESS and root[12] in (7,8) and root[13] > 0
            and all(root[i] != ZERO for i in (14,15,16))
            and receipt[13] <= root[17] <= recorded_at, 'policy reference original scoped root/snapshot/Artist')
    expected = (content_wire.ROOT_PROFILE,
        _addr(graph,'outputManifest'),graph['outputManifest']['runtimeHash'],
        _addr(graph,'policyContent'),graph['policyContent']['runtimeHash'], outputs[0], outputs[1],
        _addr(graph,'entropySourceSet'),graph['entropySourceSet']['runtimeHash'],entropy[1],entropy[2],outputs[9],
        *(d['hash'] for d in content_wire.definitions()), factory,factory_hash,factory_deps,*SNAPSHOT_HASHES)
    require(binding == expected, 'policy scoped root interpretation/factory binding')
    require(root[15] == content_wire.root_state_hash(_n(context['chainId']),_addr(graph,'router'),context['core'],root,binding)
            and root[14] == content_wire.route_hash(_n(context['chainId']),graph,scope), 'policy scoped root state/route')
    if content_result is not None:
        require(content_result['selectedRoot'] == json_values(root)
                and content_result['selectedBinding'] == json_values(binding)
                and content_result['selectedRootHash'] == source[3], 'policy reference verified selected root')


def validate_reference(bundle, context, graph, snapshot_result, content_result=None):
    s = _closed(bundle, ('dependencies', 'publication', 'receipt', 'source', 'payload', 'environment',
                        'lock', 'head', 'history', 'objects'), 'policy reference')
    d = _deps(s['dependencies'], REFERENCE_DEPS, REFERENCE_KEYS, context, graph)
    p, r, source = (from_json(k, s[key]) for k, key in (
        (REFERENCE_PUBLICATION, 'publication'), (REFERENCE_RECEIPT, 'receipt'), (REFERENCE_SOURCE, 'source')))
    scope = _scope(p[0], context); o, record = p[1], r[1]
    require(r[0] == source[0] == scope_subject(scope, context) and source[1] == from_json(SNAPSHOT_RECEIPT, snapshot_result['receipt'])
            and source[2] == from_json(SNAPSHOT_SOURCE, snapshot_result['source'])
            and o[4:6] == (source[1][0], source[1][3]) and source[1][13] <= record[15],
            'policy reference original snapshot/root join')
    _root(source, snapshot_result, context, graph, content_result, record[15])
    require(record[8] == o[6] == reference_source_hash(source, d, context, graph), 'policy reference source hash')
    environment = hex_bytes(s['environment'])
    require(environment == environment_bytes(o[8]) and (keccak256(environment), len(environment)) == o[8][2:4],
            'policy original environment bytes')
    objects = {}
    require(type(s['objects']) is list and 1 <= len(s['objects']) <= 3, 'policy reference object bound')
    for value in s['objects']:
        _closed(value, ('objectHash', 'identity'), 'policy reference object')
        require(value['objectHash'] not in objects, 'policy duplicate object')
        objects[value['objectHash']] = from_json(EXTERNAL_OBJECT, value['identity'])
    needed = [source[6][1], *(sample[1][9][1] for sample in source[7])]
    require(all(value in objects for value in needed), 'policy missing original object')
    _samples(p, r, source, objects, context, graph, content_result)
    raw = hex_bytes(s['payload'])
    require(0 < len(raw) <= MAX_PAYLOAD and raw == reference_payload(p, r, source, environment, context, graph)
            and record[6:8] == (keccak256(raw), len(raw)), 'policy reference exact payload/hash')
    require(type(s['history']) is list and 0 < len(s['history']) <= MAX_HISTORY, 'policy reference history bound')
    previous, chain, when, ids, selected = ZERO, ZERO, 0, set(), False
    for index, entry in enumerate(s['history']):
        _closed(entry, ('publication', 'receipt'), 'policy reference history row')
        hp, hr = from_json(REFERENCE_PUBLICATION, entry['publication']), from_json(REFERENCE_RECEIPT, entry['receipt'])
        ho, rr = hp[1], hr[1]
        require(hp[0] == scope and hr[0] == scope_subject(scope, context) and ho[0] == scope[1]
                and ho[1] != ZERO and ho[1] not in ids and ho[2:4] == (previous, index)
                and ho[4] != ZERO and ho[5] > 0 and ho[6] != ZERO and ho[11] != ZERO
                and 0 < ho[10] <= rr[15], 'policy reference original publication')
        _uri(ho[9]); ids.add(ho[1])
        require(rr[2:6] == (scope[1], ho[1], previous, index+1) and rr[6] != ZERO
                and 0 < rr[7] <= MAX_PAYLOAD and rr[8:11] == (ho[6], ho[4], ho[5])
                and rr[11] != ZERO_ADDRESS and rr[12] in (3, 8) and rr[13] > 0
                and rr[14] == ho[10] and when <= rr[15] <= _n(context['timestamp']) and rr[15] > 0
                and rr[16] == ho[11] and rr[17:] == REFERENCE_HASHES, 'policy reference original receipt authority/time/definitions')
        require(rr[0] == reference_hash(hp, hr, context, graph)
                and rr[1] == reference_chain(chain, hr, context, graph), 'policy reference record/chain')
        if rr[0] == record[0]:
            require((hp, hr) == (p, r), 'policy selected original reference equality'); selected = True
        previous, chain, when = rr[0], rr[1], rr[15]
    require(selected and s['head'] == previous, 'policy reference selected original/current head')
    lock = _lock(s['lock'], s['head'], record[0], record[5], record[15], context, 'reference')
    return {'publication': json_values(p), 'receipt': json_values(r), 'source': json_values(source),
            'lock': json_values(lock), 'head': s['head'], 'samples': json_values(source[7]), 'rootHash': source[3]}


def validate(bundle, context, graph, statement, content_result=None):
    """Check the two real V2 groups, preserving full native arrays for parent joins."""
    snapshot = validate_snapshot(bundle['snapshot'], context, graph, content_result)
    reference = validate_reference(bundle['reference'], context, graph, snapshot, content_result)
    if statement is not None:
        require(_scope(statement[0], context) == from_json(SCOPE, snapshot['publication'][0]), 'policy finality scope join')
        s, r = snapshot['receipt'], reference['receipt'][1]
        require(statement[7][0:3] == [reference['rootHash'], s[0], r[0]]
                or tuple(statement[7][0:3]) == (reference['rootHash'], s[0], r[0]), 'policy finality original input hashes')
        require(statement[5:7] == [s[5], r[6]] or tuple(statement[5:7]) == (s[5], r[6]), 'policy finality manifest hashes')
        from .scoped_policy_content_types_v2 import LEAF_SCHEMA
        source = from_json(SNAPSHOT_SOURCE,snapshot['source'])
        require(statement[2] == source[5][8] and _n(statement[3]) == source[1][3]
                and statement[4] == LEAF_SCHEMA, 'policy finality V2 content interpretation')
    return {'snapshot': snapshot, 'reference': reference, 'source': snapshot['source'],
            'entropy': snapshot['entropy'], 'samples': reference['samples'],
            'sourceSet': snapshot['sourceSet'], 'sourceSetCodeHash': snapshot['sourceSetCodeHash'],
            'sourceSetProfile': SOURCE_SET_PROFILE, 'snapshotProfileHash': SNAPSHOT_HASHES[1],
            'referenceProfileHash': REFERENCE_HASHES[1],
            'componentCommitments': {
                'entropy':source_set_commitments(snapshot['source'],bundle['snapshot']['entropyDependencies'],graph),
                'reference':reference_component(reference['receipt'],reference['lock'],
                    from_json(SCOPE,snapshot['publication'][0]),context,graph)},
            'qualification': list(QUALIFICATION),
            'claims': {'suppliedCommitmentsVerified': True, 'sourceAuthenticated': False,
                'historicalExecutionVerified': False, 'currentnessVerified': False,
                'completeOutputRowsJoined': content_result is not None, 'terminalAdmissionPreimageVerified': False,
                'policyConfigurationPreimageVerified': False, 'fullRenderedBytesReconstructed': False,
                'archiveLivenessVerified': False, 'browserExecutionVerified': False}}


def expected_events(bundle, context, graph, statement=None):
    """Original payload descriptors; caller must join receipt/header order and time."""
    rows = []
    for label, host_key, pub_type, receipt_type, event in (
            ('snapshot', 'policySnapshot', SNAPSHOT_PUBLICATION, SNAPSHOT_RECEIPT, 'ScopedPolicySnapshotPublished'),
            ('reference', 'policyReference', REFERENCE_PUBLICATION, REFERENCE_RECEIPT, 'ScopedPolicyReferencePublished')):
        group = bundle[label]; host = _addr(graph, host_key)
        for entry in group['history']:
            p, r = from_json(pub_type, entry['publication']), from_json(receipt_type, entry['receipt'])
            if label == 'snapshot':
                rows.append(_descriptor('policy_snapshot_published', host, event,
                    ('uint16', 'bytes32', 'bytes32', 'bytes32', pub_type, receipt_type),
                    [r[1], p[1], r[0]], ('uint16', pub_type, receipt_type), (2, p, r)))
            else:
                rows.append(_descriptor('policy_reference_published', host, event,
                    ('uint16', 'bytes32', 'bytes32', 'bytes32', receipt_type, 'string'),
                    [r[0], p[1][1], r[1][0]], ('uint16', receipt_type, 'string'), (2, r, p[1][9])))
        lock = from_json(SNAPSHOT_LOCK, group['lock'])
        if lock[2] != ZERO:
            rows.append(_descriptor('policy_' + label + '_locked', host,
                'ScopedPolicySnapshotLocked' if label == 'snapshot' else 'ScopedPolicyReferenceLocked',
                ('uint16', 'bytes32', SNAPSHOT_LOCK), [scope_subject(from_json(SCOPE, group['publication'][0]), context)], ('uint16', SNAPSHOT_LOCK), (2, lock)))
    return rows
