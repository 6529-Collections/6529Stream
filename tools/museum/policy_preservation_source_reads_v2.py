"""Historical COLLECTION policy V2 reads for the additive public source.

Original payload/chunk/history/source-set getters only. This mixin never calls
current entropy readiness, current factory selection, requireCurrentSnapshot,
requireCurrentReference, or current archive liveness to replace saved evidence.
"""
from . import policy_preservation_wire_v2 as wire
from .canonical import hex_bytes, keccak256, schema_id, uint
from .chain_abi import decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require
from .native_finality_wire import from_json
from .policy_preservation_types_v2 import *
from .policy_content_types_v2 import STATEMENT
from .scoped_static_snapshot_wire import _type

SCOPE_SIGNATURE = '(uint8,uint256,uint256,bytes32)'
MAX_HISTORY_BYTES = 16 * 1024 * 1024


def _json(value):
    if isinstance(value, dict): return {k: _json(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)): return [_json(v) for v in value]
    return json_values(value)


def _event(name, kinds):
    return schema_id(name + '(' + ','.join(_type(k) for k in kinds) + ')')


class PolicyPreservationSourceReads:
    """Requires a/graph/reader, _read/_one/_chunk/_history from the parent."""

    def _policy_payload(self, host, family, key, digest, size):
        require(key != ZERO and digest != ZERO and 0 < size <= MAX_PAYLOAD, 'policy original payload bounds')
        raw = self._one(host, family + 'Payload(bytes32)', 'bytes', ('bytes32',), (key,), maximum=MAX_PAYLOAD+96)
        require(len(raw) == size and keccak256(raw) == digest, 'policy historical payload hash/length')
        count = self._one(host, family + 'ChunkCount(bytes32)', 'uint256', ('bytes32',), (key,))
        require(count == (size+8191)//8192 and 0 < count <= 64, 'policy original payload chunk denominator')
        pieces = []
        for index in range(count):
            pointer, chunk_hash, length = self._read(host, family + 'ChunkAt(bytes32,uint256)',
                ('address','bytes32','uint32'), ('bytes32','uint256'), (key,index))
            expected_length = min(8192,size-8192*index)
            require(pointer != ZERO_ADDRESS and chunk_hash != ZERO and length == expected_length,
                    'policy original payload chunk layout')
            descriptor = self._read(self.a['store'], 'chunk(bytes32)', ('address','uint32'), ('bytes32',), (chunk_hash,))
            require(descriptor == (pointer,length), 'policy original chunk Store pointer')
            payload = self._chunk(chunk_hash)
            require(len(payload) == length and keccak256(payload) == chunk_hash, 'policy original Store chunk bytes')
            pieces.append(payload)
        require(b''.join(pieces) == raw, 'policy original full payload chunk correspondence')
        return raw

    def _policy_source_set(self, source):
        a, graph = self.a, self.graph
        host, factory = a['entropySourceSet'], a['entropyFactory']
        e, scope, membership = source[8], source[0], source[1]
        require(self._one(host,'factory()','address') == factory
                and self._one(host,'core()','address') == a['core']
                and self._one(host,'coreCodeHash()','bytes32') == graph['core']['runtimeHash'],
                'policy immutable source-set factory/Core binding')
        require(self._one(factory,'policyFactoryProfile()','bytes32') == schema_id('6529STREAM_ENTROPY_POLICY_SOURCE_FACTORY_V2'),
                'policy original factory profile')
        dependencies = self._one(factory,'dependencies()',POLICY_DEPS)
        wire._deps(_json(dependencies),POLICY_DEPS,wire.POLICY_KEYS,a,graph)
        for signature, role in (('core()','core'),('metadataHost()','metadata'),
                                ('scopeMembershipHost()','scopeMembership'),('coordinatorInventory()','coordinatorInventory')):
            require(self._one(factory,signature,'address') == a[role], 'policy original factory dependency')
        require(self._read(factory,'sourceSetForPlan(bytes32)',('address','bytes32'),('bytes32',),(e[0],)) ==
                (host,graph['entropySourceSet']['runtimeHash']), 'policy original factory saved source-set/runtime')
        require(self._one(host,'SOURCE_SET_PROFILE()','bytes32') == wire.SOURCE_SET_PROFILE
                and self._one(host,'sourceScope()',SCOPE) == scope
                and self._one(host,'scopeMembershipFacts()',MEMBERSHIP_FACTS) == membership,
                'policy source-set original scope/membership/profile')
        for signature, expected in (('inventoryPlan()',e[0]),('originalInventoryHash()',e[1]),('originalPolicyChainHash()',e[2])):
            require(self._one(host,signature,'bytes32') == expected, 'policy source-set original inventory commitment')
        count = self._one(host,'sourceCount()','uint256')
        require(count == e[3] == len(e[5]) and 0 < count <= MAX_POLICIES, 'policy source-set full original policy count')
        for index, row in enumerate(e[5]):
            require(self._one(host,'sourcePolicyAt(uint256)',POLICY_ROW,('uint256',),(index,)) == row,
                    'policy source-set immutable policy differs')
        inventory, pin = a['tokenInventory'],graph['tokenInventory']['runtimeHash']
        require(self._one(host,'tokenInventory()','address') == inventory
                and self._one(host,'tokenInventoryCodeHash()','bytes32') == pin,
                'policy source-set original token inventory')
        commitments = wire.source_set_commitments(source,dependencies,graph)
        require(self._one(host,'sourceSetManifestHash()','bytes32') == commitments['manifestHash']
                and self._one(host,'sourceSetDataHash()','bytes32') == commitments['dataHash'],
                'policy immutable source-set manifest/data preimages')
        # Parent graph pin pass authenticates all named current runtimes to the
        # supplied admission pins. No claim is made about at-mint code identity.
        for role in ('entropySourceSet','entropyFactory'):
            runtime = hex_bytes(self.reader.code(a[role]))
            require(0 < len(runtime) <= 24576 and keccak256(runtime) == graph[role]['runtimeHash'],
                    'policy original source-set/factory runtime')
        return dependencies

    def _preservation(self, statement, content_result):
        statement = from_json(STATEMENT,statement)
        a, graph = self.a,self.graph
        scope = wire._scope(statement[0],a)
        groups, total_bytes = {},0
        for family, role, pub_type, receipt_type, envelope in (
                ('snapshot','policySnapshot',SNAPSHOT_PUBLICATION,SNAPSHOT_RECEIPT,SNAPSHOT_ENVELOPE),
                ('reference','policyReference',REFERENCE_PUBLICATION,REFERENCE_RECEIPT,REFERENCE_ENVELOPE)):
            host = a[role]
            deps_type = SNAPSHOT_DEPS if family == 'snapshot' else REFERENCE_DEPS
            deps = self._one(host,'dependencies()',deps_type)
            count = self._one(host,family+'Count('+SCOPE_SIGNATURE+')','uint256',(SCOPE,),(scope,))
            require(0 < count <= MAX_HISTORY, 'policy original '+family+' history bound')
            selected_key = statement[7][1 if family=='snapshot' else 2]
            history, selected = [],None
            for index in range(count):
                key = self._one(host,family+'At('+SCOPE_SIGNATURE+',uint256)','bytes32',(SCOPE,'uint256'),(scope,index))
                p,r = self._read(host,family+'Record(bytes32)',(pub_type,receipt_type),('bytes32',),(key,),maximum=MAX_PAYLOAD+4096)
                record = r if family=='snapshot' else r[1]
                hash_index,size_index = (5,6) if family=='snapshot' else (6,7)
                require(record[0] == key != ZERO and record[size_index] > 0, 'policy indexed historical record differs')
                total_bytes += record[size_index]
                require(total_bytes <= MAX_HISTORY_BYTES, 'policy aggregate original payload bound')
                raw = self._policy_payload(host,family,key,record[hash_index],record[size_index])
                decoded = decode(envelope,raw,maximum=MAX_PAYLOAD)
                source = decoded[-1] if family=='snapshot' else decoded[-2]
                if family=='snapshot':
                    require(raw == wire.snapshot_payload(p,r,source,deps,a,graph)
                            and r[7] == wire.source_hash(source,deps,a,graph), 'policy historical snapshot canonical source')
                else:
                    require(raw == wire.reference_payload(p,r,source,decoded[-1],a,graph)
                            and r[1][8] == wire.reference_source_hash(source,deps,a,graph), 'policy historical reference canonical source')
                    observed = self._one(host,'referenceSource(bytes32)',REFERENCE_SOURCE,('bytes32',),(key,),maximum=MAX_PAYLOAD)
                    require(observed == source, 'policy reference immutable source getter/payload')
                history.append({'publication':p,'receipt':r})
                if key == selected_key:
                    selected = {'dependencies':deps,'publication':p,'receipt':r,'source':source,'payload':'0x'+raw.hex()}
                    if family=='reference': selected['environment'] = '0x'+decoded[-1].hex()
            require(selected is not None, 'policy original finality-selected '+family+' unavailable')
            current = self._one(host,'current'+family.title()+'('+SCOPE_SIGNATURE+')',receipt_type,(SCOPE,),(scope,))
            require(current == history[-1]['receipt'], 'policy current '+family+' head differs from full history')
            selected.update(history=history,head=current[0] if family=='snapshot' else current[1][0],
                lock=self._one(host,family+'Lock('+SCOPE_SIGNATURE+')',SNAPSHOT_LOCK,(SCOPE,),(scope,)))
            groups[family] = selected
        groups['snapshot']['entropyDependencies'] = self._policy_source_set(groups['snapshot']['source'])
        original_objects = []
        for digest in dict.fromkeys([groups['reference']['source'][5][1],
                                    *(sample[1][9][1] for sample in groups['reference']['source'][6])]):
            original_objects.append({'objectHash':digest,'identity':self._one(a['externalCoverage'],
                'objectIdentity(bytes32)',EXTERNAL_OBJECT,('bytes32',),(digest,))})
        for coverage in [groups['reference']['source'][5],*(sample[1][9] for sample in groups['reference']['source'][6])]:
            require(self._one(a['externalCoverage'],'coverage(bytes32)',EXTERNAL_COVERAGE,('bytes32',),(coverage[0],)) == coverage,
                    'policy reference original saved coverage differs')
        groups['reference']['objects'] = original_objects
        groups = _json(groups)
        # Fixed scoped history filters include every publication and lock; no
        # caller-selected receipt list or current gate supplies the denominator.
        subject = wire._subject(a)
        for family,role,pub_type,receipt_type in (
                ('snapshot','policySnapshot',SNAPSHOT_PUBLICATION,SNAPSHOT_RECEIPT),
                ('reference','policyReference',REFERENCE_PUBLICATION,REFERENCE_RECEIPT)):
            name = 'Policy'+family.title()
            published = _event(name+'Published',('uint16','bytes32','bytes32','bytes32',pub_type,receipt_type)
                if family=='snapshot' else ('uint16','bytes32','bytes32','bytes32',receipt_type,'string'))
            locked = _event(name+'Locked',('uint16','bytes32',SNAPSHOT_LOCK))
            self._history(a[role],[[published,locked],subject])
        wire.validate(groups,a,graph,statement,content_result)
        return groups
