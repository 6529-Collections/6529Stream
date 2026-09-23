"""Original sealed VIEW membership and immutable full policy-source evidence.

Exact e0b4 native formats; this is not a VIEW snapshot or finality profile.
No current policy, eligibility or serving read replaces the saved source set.
"""
from .canonical import hex_bytes, keccak256, schema_id, subject_id, uint
from .chain_abi import Array, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, generic_hash, json_values, require
from .native_finality_wire import from_json, _hash
from . import scoped_static_snapshot_wire as neutral
from .scoped_static_source_reads import ScopedStaticSourceReads, _json
from .scoped_static_types import (SCOPE, MEMBERSHIP_FACTS, MEMBERSHIP_PUBLICATION,
    MEMBERSHIP_PROGRESS, MEMBERSHIP_MANIFEST, METADATA_RECEIPT)
from .policy_preservation_types_v2 import POLICY, POLICY_ROW, POLICY_DEPS
from .policy_preservation_wire_v2 import policy_plan, policy_component, policy_chain

SOURCE_REVISION = 'e0b4d17bc548f778a379773234caee545658bcdc'
MAX_MEMBERS = 16384
POLICY_EVIDENCE = ('bytes32', 'bytes32', 'bytes32', 'uint256', 'bool', Array(POLICY_ROW, MAX_MEMBERS))
VIEW_BINDING = ('address', 'bytes32', 'address', 'bytes32', 'address', 'bytes32',
    'uint256', SCOPE, MEMBERSHIP_FACTS, 'bytes32', 'bytes32', 'bytes32', 'uint256')
SOURCE_SET_PROFILE = schema_id('6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2')
FACTORY_PROFILE = schema_id('6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2')
POLICY_KEYS = ('core', 'metadata', 'scopeMembership', 'coordinatorInventory')
METADATA_RECORD = neutral.METADATA_RECORD
MEMBERSHIP_KEYS = ('facts', 'publication', 'progress', 'metadataRecord', 'manifestBytes',
    'parts', 'tokens', 'identities', 'lifecycles', 'inventoryTokens', 'progressHistory')
QUALIFICATION = [
    'Original sealed VIEW membership and immutable source-set policy commitments are reconstructed; no VIEW snapshot, reference receipt or finality authority is implied.',
    'Core identities, lifecycle and coordinatorAtMint are source-block observations; later burns do not rewrite original membership or coordinator commitments.',
    'Full original policies and indexed coordinator runtimes are retained; current coordinator code, entropy status, policy eligibility and rendering are not revalidated.',
    'The historical admission of native policy and membership execution remains trusted to the separately authenticated source; these supplied checks do not prove signature authorization, EVM execution or consensus.',
]


def definitions():
    return tuple(row for row in neutral.definitions() if row['name'] in
        ('STREAM_SCOPE_MEMBERSHIP_V1', 'STREAM_SCOPE_MEMBERSHIP_ABI_V1'))


def _closed(value, keys, label):
    require(type(value) is dict and set(value) == set(keys), 'VIEW ' + label + ' fields')
    return value


def _n(value):
    return uint(value) if isinstance(value, str) else from_json('uint256', value)


def _address(graph, role):
    return neutral._address(graph, role)


def scope_value(value, context):
    scope = from_json(SCOPE, value)
    require(scope[0] == 4 and scope[1] == _n(context['collectionId']) > 0
            and scope[2] == 0 and scope[3] != ZERO, 'VIEW membership scope')
    require(from_json('address', context['core']) != ZERO_ADDRESS, 'VIEW Core address')
    return scope


def scope_subject(scope, context):
    scope = scope_value(scope, context)
    return subject_id('scope', str(_n(context['chainId'])), context['core'], str(scope[1]),
                      scope_type='4', scope_id=scope[3])


def membership_hash(facts, scope, context, graph):
    # This neutral hash has no STATIC scope interpretation.
    return neutral.membership_hash(facts, scope, context, graph)


def validate_membership(value, context, graph, scope, original_facts=None):
    _closed(value, MEMBERSHIP_KEYS, 'membership')
    scope = scope_value(scope, context)
    require(_address(graph, 'core') == context['core'], 'VIEW membership Core graph')
    facts = from_json(MEMBERSHIP_FACTS, value['facts'])
    require(type(value['tokens']) is list and 0 < len(value['tokens']) <= MAX_MEMBERS,
            'VIEW membership token bound')
    tokens = tuple(_n(v) for v in value['tokens'])
    require(list(tokens) == sorted(set(tokens)) and tokens[0] > 0, 'VIEW membership token ordering')
    require(facts[0] == scope_subject(scope, context) and facts[3] == len(tokens)
            and facts[6:] == (0, ZERO), 'VIEW membership facts/count')
    if original_facts is not None:
        require(facts == from_json(MEMBERSHIP_FACTS, original_facts), 'VIEW original membership differs')
    for key in ('identities', 'lifecycles', 'inventoryTokens'):
        require(type(value[key]) is list and len(value[key]) == len(tokens), 'VIEW identity denominator')
    serials, observations = set(), []
    for index, (token, identity, lifecycle) in enumerate(zip(tokens, value['identities'], value['lifecycles'])):
        identity = from_json(('bool', 'uint256', 'uint256', 'bool'), identity)
        lifecycle = from_json('uint8', lifecycle)
        require(identity[0] and identity[1] == scope[1] and identity[2] > 0
                and identity[2] not in serials and (lifecycle, identity[3]) in ((2, False), (3, True)),
                'VIEW membership Core identity/lifecycle')
        serials.add(identity[2])
        require(_n(value['inventoryTokens'][index]) == token, 'VIEW membership inventory serial')
        observations.append({'tokenId': str(token), 'collectionId': str(identity[1]),
            'collectionSerial': str(identity[2]), 'lifecycle': str(lifecycle), 'burned': identity[3]})
    if 'tokenId' in context:
        require(_n(context['tokenId']) in tokens, 'VIEW target outside membership')
    raw = hex_bytes(value['manifestBytes'])
    require(0 < len(raw) <= 2336, 'VIEW membership manifest byte bound')
    manifest = decode(MEMBERSHIP_MANIFEST, raw, maximum=2336)
    p = from_json(MEMBERSHIP_PUBLICATION, value['publication'])
    progress = from_json(MEMBERSHIP_PROGRESS, value['progress'])
    record = from_json(METADATA_RECORD, value['metadataRecord'])
    count = (len(tokens) * 32 + 8191) // 8192
    require(type(value['parts']) is list and len(value['parts']) == count
            and manifest[:6] == (1, _n(context['chainId']), context['core'], scope[1], 4, len(tokens))
            and len(manifest[7]) == count, 'VIEW membership manifest fields')
    whole = encode(('uint256',) * len(tokens), tokens)
    require(manifest[6] == facts[4] == keccak256(whole), 'VIEW whole token list hash')
    for index, part in enumerate(value['parts']):
        body = whole[8192*index:8192*(index+1)]
        neutral._carrier(part, body)
        require(keccak256(body) == manifest[7][index], 'VIEW membership chunk hash')
    require(facts[1:3] == (keccak256(raw), p[0])
            and p[1:4] == (facts[1], neutral.MEMBERSHIP_SCHEMA, neutral.MEMBERSHIP_CANON),
            'VIEW membership publication/schema')
    require(p[4] != ZERO_ADDRESS and p[5] == keccak256(b'\0' + raw)
            and p[6] == record[7] > 0, 'VIEW membership carrier/effective time')
    runtimes = {}
    for address, digest in [(row['address'], row['runtimeHash']) for row in graph.values()] + [
            (p[4], p[5]), *((row['pointer'], row['codeHash']) for row in value['parts'])]:
        from_json('address', address); from_json('bytes32', digest)
        require(address not in runtimes or runtimes[address] == digest,
                'VIEW observed runtime address conflict')
        runtimes[address] = digest
    receipt = p[7]
    require(receipt[0] == scope[1] and receipt[1] != ZERO_ADDRESS and receipt[2] in (7, 8)
            and 0 < receipt[3] <= _n(context['timestamp']) and receipt[5] != ZERO
            and receipt[6] == ZERO and receipt[7:] == (neutral.MEMBERSHIP_SCHEMA_HASH, neutral.MEMBERSHIP_CANON_HASH),
            'VIEW membership authority/definitions')
    sid = subject_id('collection', str(_n(context['chainId'])), context['core'], str(scope[1]))
    require(record[:3] == (schema_id('SCOPE_MEMBERSHIP'), sid, (1, hex_bytes(facts[1]), neutral.MEMBERSHIP_CANON))
            and record[4:7] == (neutral.MEMBERSHIP_SCHEMA, ZERO, (0, b'', ZERO)),
            'VIEW membership Metadata record')
    require(generic_hash(_n(context['chainId']), _address(graph, 'metadata'), context['core'],
                         scope[1], receipt[1], record) == p[0], 'VIEW membership native record hash')
    require(scope[3] == _hash('6529STREAM_SCOPE_MEMBERSHIP_ID_V1',
            ('uint256', 'address', 'uint256', 'uint8', 'bytes32'),
            (_n(context['chainId']), context['core'], scope[1], 4, p[0])), 'VIEW membership scope identifier')
    require(progress == (True, True, len(tokens), len(tokens), count, count), 'VIEW membership not sealed')
    require(type(value['progressHistory']) is list and 0 < len(value['progressHistory']) <= count,
            'VIEW membership progress bound')
    previous = 0
    for row in value['progressHistory']:
        parts, done = from_json(('uint256', 'uint256'), row)
        require(previous < parts <= count and parts - previous <= 64
                and done == min(parts*256, len(tokens)), 'VIEW membership progress partition')
        previous = parts
    require(previous == count and facts[5] == membership_hash(facts, scope, context, graph),
            'VIEW membership completion/hash')
    return {'scope': json_values(scope), 'facts': json_values(facts), 'tokenIds': json_values(tokens),
            'identityObservations': observations}


def inventory_hash(plan, tokens, coordinators, policies):
    """Exact original coordinator inventory chains, including A/B/A occurrences."""
    require(len(tokens) == len(coordinators), 'VIEW original coordinator denominator')
    token_chain = _hash('6529STREAM_COORDINATOR_TOKEN_CHAIN_V1', ('bytes32',), (plan,))
    source_chain = _hash('6529STREAM_COORDINATOR_SOURCE_CHAIN_V1', ('bytes32',), (plan,))
    positions, ordered = {}, []
    policy_by_address = {row[0]: row for row in policies}
    for index, (token, coordinator) in enumerate(zip(tokens, coordinators)):
        require(coordinator in policy_by_address, 'VIEW token coordinator outside original roster')
        if coordinator not in positions:
            position = len(positions); positions[coordinator] = position
            row = policy_by_address[coordinator]
            require(row[2] == index, 'VIEW coordinator first occurrence')
            ordered.append(coordinator)
            source_chain = _hash('6529STREAM_COORDINATOR_SOURCE_APPEND_V1',
                ('bytes32', 'uint256', ('address', 'bytes32', 'uint256')),
                (source_chain, position, (coordinator, row[1], index)))
        token_chain = _hash('6529STREAM_COORDINATOR_TOKEN_APPEND_V1',
            ('bytes32', 'uint256', 'uint256', 'address', 'uint256'),
            (token_chain, index, token, coordinator, positions[coordinator]))
    require(ordered == [row[0] for row in policies], 'VIEW complete original coordinator order')
    return _hash('6529STREAM_COORDINATOR_INVENTORY_COMPLETE_V1',
        ('bytes32', 'uint256', 'uint256', 'bytes32', 'bytes32'),
        (plan, len(tokens), len(policies), token_chain, source_chain))


def source_set_commitments(scope, facts, evidence, dependencies, graph):
    inventory, pin = _address(graph, 'tokenInventory'), graph['tokenInventory']['runtimeHash']
    return {'manifestHash': keccak256(encode(('bytes32', POLICY_DEPS, 'address', 'bytes32'),
                (SOURCE_SET_PROFILE, dependencies, inventory, pin))),
            'dataHash': keccak256(encode(('bytes32', SCOPE, 'bytes32', 'bytes32', 'bytes32',
                MEMBERSHIP_FACTS, 'address', 'bytes32'),
                (SOURCE_SET_PROFILE, scope, evidence[0], evidence[1], evidence[2], facts, inventory, pin)))}


def validate(value, context, graph, binding, outputs=None):
    _closed(value, ('membership', 'sourceSet'), 'evidence')
    b = from_json(VIEW_BINDING, binding)
    scope = scope_value(b[7], context)
    require(b[:6] == (_address(graph, 'core'), graph['core']['runtimeHash'],
            _address(graph, 'sourceFactory'), graph['sourceFactory']['runtimeHash'],
            _address(graph, 'entropySourceSet'), graph['entropySourceSet']['runtimeHash'])
            and b[6] == _n(context['chainId']), 'VIEW original binding graph/chain')
    member = validate_membership(value['membership'], context, graph, scope, b[8])
    facts, tokens = from_json(MEMBERSHIP_FACTS, member['facts']), tuple(map(_n, member['tokenIds']))
    source = _closed(value['sourceSet'], ('dependencies', 'evidence', 'tokenCoordinators',
                                        'manifestHash', 'dataHash'), 'source set')
    d = from_json(POLICY_DEPS, source['dependencies'])
    require(d[:2] == (tuple(_address(graph, k) for k in POLICY_KEYS),
            tuple(graph[k]['runtimeHash'] for k in POLICY_KEYS)) and d[2] == b[6]
            and d[3] >= 50000 and d[4] >= d[3], 'VIEW factory immutable dependencies')
    e = from_json(POLICY_EVIDENCE, source['evidence'])
    require(e[0] == policy_plan(scope, facts, d, context) and e[0:4] == b[9:13]
            and e[4] and 0 < e[3] == len(e[5]) <= len(tokens), 'VIEW complete policy denominator/binding')
    require(type(source['tokenCoordinators']) is list and len(source['tokenCoordinators']) == len(tokens),
            'VIEW original coordinator denominator')
    coordinators = tuple(from_json('address', row) for row in source['tokenCoordinators'])
    seen = set()
    for row in e[5]:
        require(row[0] != ZERO_ADDRESS and row[0] not in seen and row[1] != ZERO and row[3]
                and row[2] < len(tokens) and all(row[i] != ZERO for i in (4, 5, 6, 7, 8, 12)),
                'VIEW original policy identity/frozen')
        seen.add(row[0]); p = row[14]
        if row[13]:
            require(p[:3] == (True, True, True) and p[3] <= 2 and p[4] <= 1 and p[5] <= 1
                    and p[6] > 0 and p[8] == row[8] and p[10] != ZERO and p[11] != ZERO
                    and p[9] == _hash('6529STREAM_ENTROPY_CONFIGURATION_V1', ('bytes32', 'bool'), (p[8], p[2]))
                    and row[9:12] == (ZERO_ADDRESS, 0, ZERO), 'VIEW explicit original policy')
        else:
            require(p == (False, False, False, 0, 0, 0, 0, 0, ZERO, ZERO, ZERO, ZERO)
                    and row[9] != ZERO_ADDRESS and row[10] > 0 and row[11] != ZERO,
                    'VIEW legacy policy has no explicit projection')
        require(row[12] == policy_component(row, scope, context), 'VIEW policy component hash')
    require(e[1] == inventory_hash(e[0], tokens, coordinators, e[5]), 'VIEW original inventory hash')
    require(e[2] == policy_chain(e, scope, d, context), 'VIEW original policy chain')
    commitments = source_set_commitments(scope, facts, e, d, graph)
    require(all(source[key] == digest for key, digest in commitments.items()), 'VIEW source-set commitments')
    if outputs is not None:
        from .view_policy_output_types_v2 import OUTPUT
        require(type(outputs) in (list, tuple) and len(outputs) == len(tokens), 'VIEW output denominator')
        for index, raw in enumerate(outputs):
            row = from_json(OUTPUT, raw)
            identity = from_json(('bool', 'uint256', 'uint256', 'bool'), value['membership']['identities'][index])
            lifecycle = from_json('uint8', value['membership']['lifecycles'][index])
            require(row[0] == index and row[1] == tokens[index]
                    and row[7][0] == coordinators[index], 'VIEW output member/coordinator join')
            require(row[2] == identity[2], 'VIEW output permanent collection serial')
            require((row[3], row[4], row[5]) in ((2, False, 1), (3, True, 2))
                    and (not row[4] or (identity[3] and lifecycle == 3)),
                    'VIEW output historical burn cannot become live')
    return {**member, 'binding': json_values(b), 'inventoryPlan': e[0], 'inventoryHash': e[1],
        'policyChainHash': e[2], 'policies': json_values(e[5]), 'evidence': json_values(e),
        'tokenCoordinators': list(coordinators), **commitments, 'qualification': list(QUALIFICATION),
        'claims': {'originalMembershipCommitmentVerified': True, 'originalInventoryHashReconstructed': True,
            'originalPolicyChainReconstructed': True, 'currentEligibilityVerified': False,
            'historicalAuthorityVerified': False, 'renderedBytesReconstructed': False, 'sourceAuthenticated': False}}


def expected_events(value, context, graph, binding):
    b = from_json(VIEW_BINDING, binding); scope = scope_value(b[7], context)
    m = value['membership']; p = from_json(MEMBERSHIP_PUBLICATION, m['publication'])
    facts = from_json(MEMBERSHIP_FACTS, m['facts']); record = from_json(METADATA_RECORD, m['metadataRecord'])
    topic = lambda kind, v: '0x'+encode((kind,), (v,)).hex()
    descriptor = neutral._descriptor
    out = [descriptor('membership_recorded', _address(graph, 'metadata'), 'CollectionRecordRecorded',
        ('uint256', 'bytes32', 'bytes32', METADATA_RECORD, 'bytes32', 'bytes32', 'address', 'bytes32', 'uint16'),
        (topic('uint256', scope[1]), record[0], record[1]),
        (METADATA_RECORD, 'bytes32', 'bytes32', 'address', 'bytes32', 'uint16'),
        (record, p[0], p[7][5], p[7][1], topic('uint8', p[7][2]), 1)),
        descriptor('membership_admitted', _address(graph, 'scopeMembership'), 'ScopeMembershipAdmitted',
        ('bytes32', 'uint256', 'uint8', 'bytes32', 'bytes32', 'bytes32', 'uint256', 'address', 'uint8'),
        (scope[3], topic('uint256', scope[1]), topic('uint8', 4)),
        ('bytes32', 'bytes32', 'bytes32', 'uint256', 'address', 'uint8'),
        (p[0], p[1], facts[4], facts[3], p[7][1], p[7][2]))]
    for row in m['progressHistory']:
        out.append(descriptor('membership_progressed', _address(graph, 'scopeMembership'),
            'ScopeMembershipProgressed', ('bytes32', 'uint256', 'uint256'), (scope[3],),
            ('uint256', 'uint256'), from_json(('uint256', 'uint256'), row)))
    out.append(descriptor('membership_sealed', _address(graph, 'scopeMembership'), 'ScopeMembershipSealed',
        ('bytes32', 'bytes32', 'uint256'), (scope[3],), ('bytes32', 'uint256'), (facts[5], facts[3])))
    out.append(descriptor('source_set_prepared', _address(graph, 'sourceFactory'), 'EntropySourceSetPrepared',
        ('bytes32', 'address', 'bytes32', 'bytes32', 'bytes32'),
        (b[9], topic('address', b[4]), facts[0]), ('bytes32', 'bytes32'),
        (b[5], value['sourceSet']['dataHash'])))
    return out


class ViewPolicyMembershipReads:
    """Parent supplies a/graph/reader and _read/_one/_carrier/_history."""
    _original_membership = ScopedStaticSourceReads._original_membership

    def _view_membership(self, binding):
        b = from_json(VIEW_BINDING, binding); scope = scope_value(b[7], self.a)
        require(0 < b[8][3] <= MAX_MEMBERS and 0 < b[12] <= b[8][3], 'VIEW membership read bound')
        graph, a = self.graph, self.a
        require(b[:6] == (_address(graph, 'core'), graph['core']['runtimeHash'],
                _address(graph, 'sourceFactory'), graph['sourceFactory']['runtimeHash'],
                _address(graph, 'entropySourceSet'), graph['entropySourceSet']['runtimeHash']),
                'VIEW source binding graph')
        member = self._original_membership(scope, b[8])
        host, factory = b[4], b[2]
        require(self._one(factory, 'scopedPolicyFactoryProfile()', 'bytes32') == FACTORY_PROFILE,
                'VIEW original factory profile')
        dependencies = self._one(factory, 'dependencies()', POLICY_DEPS)
        for signature, role in (('core()', 'core'), ('metadataHost()', 'metadata'),
                ('scopeMembershipHost()', 'scopeMembership'), ('coordinatorInventory()', 'coordinatorInventory')):
            require(self._one(factory, signature, 'address') == a[role], 'VIEW factory dependency getter')
        require(self._read(factory, 'sourceSetForPlan(bytes32)', ('address', 'bytes32'),
                ('bytes32',), (b[9],)) == (host, b[5]), 'VIEW original factory source-set mapping')
        for signature, kind, expected in (('factory()', 'address', factory), ('core()', 'address', b[0]),
                ('coreCodeHash()', 'bytes32', b[1]), ('SOURCE_SET_PROFILE()', 'bytes32', SOURCE_SET_PROFILE),
                ('sourceScope()', SCOPE, scope), ('scopeMembershipFacts()', MEMBERSHIP_FACTS, b[8]),
                ('inventoryPlan()', 'bytes32', b[9]), ('originalInventoryHash()', 'bytes32', b[10]),
                ('originalPolicyChainHash()', 'bytes32', b[11]), ('sourceCount()', 'uint256', b[12]),
                ('tokenInventory()', 'address', a['tokenInventory']),
                ('tokenInventoryCodeHash()', 'bytes32', graph['tokenInventory']['runtimeHash'])):
            require(self._one(host, signature, kind) == expected, 'VIEW immutable source-set getter ' + signature)
        policies = tuple(self._one(host, 'sourcePolicyAt(uint256)', POLICY_ROW,
                         ('uint256',), (index,)) for index in range(b[12]))
        coordinators = [self._one(a['core'], 'coordinatorAtMint(uint256)', 'address',
                        ('uint256',), (token,)) for token in member['tokens']]
        source = {'dependencies': dependencies, 'evidence': (*b[9:13], all(row[3] for row in policies), policies),
            'tokenCoordinators': coordinators,
            'manifestHash': self._one(host, 'sourceSetManifestHash()', 'bytes32'),
            'dataHash': self._one(host, 'sourceSetDataHash()', 'bytes32')}
        value = _json({'membership': member, 'sourceSet': source})
        validate(value, a, graph, b)
        for role in ('sourceFactory', 'entropySourceSet'):
            raw = hex_bytes(self.reader.code(a[role]))
            require(0 < len(raw) <= 24576 and keccak256(raw) == graph[role]['runtimeHash'],
                    'VIEW original source runtime')
        event = expected_events(value, a, graph, b)[-1]
        self._history(factory, event['topics'])
        return value
