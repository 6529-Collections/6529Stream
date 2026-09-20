"""Historical scoped STATIC snapshot reads for the additive public source.

The parent supplies pinned graph/reader/history machinery. No requireCurrent
read is used to replace original snapshots, renderer choices or policy facts.
"""
from . import scoped_static_snapshot_wire as wire
from .canonical import hex_bytes, keccak256, schema_id, uint
from .chain_abi import decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require
from .native_finality_wire import from_json
from .scoped_static_types import *

SCOPE_SIGNATURE = '(uint8,uint256,uint256,bytes32)'


def _json(value):
    if type(value) is dict: return {k:_json(v) for k,v in value.items()}
    if isinstance(value, (list, tuple)): return [_json(v) for v in value]
    return json_values(value)


def _topic(kind, value): return '0x' + encode((kind,), (value,)).hex()


def _event_topic(name, types):
    return schema_id(name + '(' + ','.join(wire._type(k) for k in types) + ')')


class ScopedStaticSourceReads:
    """Mixin contract: a/graph/scope and _read/_one/_history/_carrier/reader."""

    def _snapshot_membership(self, statement, content_result):
        a = self.a
        statement = from_json(STATEMENT, statement)
        scope = wire._scope(statement[0], a)
        require(tuple(self.scope) == scope, 'scoped source snapshot requested scope')
        host = a['scopedSnapshot']
        deps = self._one(host, 'dependencies()', SNAPSHOT_DEPS)
        count = self._one(host, 'snapshotCount('+SCOPE_SIGNATURE+')', 'uint256', (SCOPE,), (scope,))
        require(0 < count <= MAX_HISTORY, 'scoped source snapshot history bound')
        history, selected_source = [], None
        for index in range(count):
            key = self._one(host, 'snapshotAt('+SCOPE_SIGNATURE+',uint256)', 'bytes32',
                            (SCOPE, 'uint256'), (scope, index))
            p, r = self._read(host, 'snapshotRecord(bytes32)', (SNAPSHOT_PUBLICATION, SNAPSHOT_RECEIPT),
                              ('bytes32',), (key,), maximum=8192)
            require(key != ZERO and r[0] == key, 'scoped source snapshot index/record')
            raw = self._one(host, 'snapshotPayload(bytes32)', 'bytes', ('bytes32',), (key,),
                            maximum=wire.MAX_PAYLOAD + 96)
            require(0 < len(raw) <= wire.MAX_PAYLOAD and keccak256(raw) == r[5], 'scoped source snapshot original payload')
            decoded = decode(SNAPSHOT_ENVELOPE, raw, maximum=wire.MAX_PAYLOAD)
            history.append({'publication': p, 'receipt': r, 'payload': '0x'+raw.hex()})
            if key == statement[7][1]: selected_source = decoded[-1]
        require(selected_source is not None, 'scoped source original snapshot unavailable')
        current = self._one(host, 'currentSnapshot('+SCOPE_SIGNATURE+')', SNAPSHOT_RECEIPT, (SCOPE,), (scope,))
        require(current == history[-1]['receipt'], 'scoped source snapshot head differs')
        lock = self._one(host, 'snapshotLock('+SCOPE_SIGNATURE+')', SNAPSHOT_LOCK, (SCOPE,), (scope,))
        snapshot = {'dependencies': deps, 'history': history, 'head': current[0], 'lock': lock}
        facts = selected_source[1]
        require(0 < facts[3] <= MAX_OUTPUTS, 'scoped source member bound')
        key = selected_source[4][0]
        plan = self._one(a['staticSelection'], 'checkpoint(bytes32)', SELECTION_PLAN, ('bytes32',), (key,))
        require(plan == selected_source[3] and plan[3] == plan[4] == facts[3], 'scoped source original selection plan')
        rows = [self._one(a['staticSelection'], 'selectionAt(bytes32,uint256)', SELECTION_ROW,
                          ('bytes32', 'uint256'), (key, index)) for index in range(facts[3])]
        selection = {'id': key, 'plan': plan, 'rows': rows}
        member = self._original_membership(scope, facts)
        groups = _json({'snapshot': snapshot, 'selection': selection, 'membership': member})
        # Fixed filters retain every original scope revision and every original
        # selection index, including batching events; parent binds receipts/time.
        published = _event_topic('ScopedSnapshotPublished', ('uint16','bytes32','bytes32','bytes32',SNAPSHOT_PUBLICATION,SNAPSHOT_RECEIPT))
        locked = _event_topic('ScopedSnapshotLocked', ('uint16','bytes32',SNAPSHOT_LOCK))
        self._history(host, [[published, locked], facts[0]])
        selection_events = [_event_topic(name, types) for name,types in (
            ('StaticSelectionStarted', ('uint16','bytes32',SELECTION_PLAN)),
            ('StaticSelectionAppended', ('uint16','bytes32','uint64',SELECTION_ROW,'bytes32')),
            ('StaticSelectionCompleted', ('uint16','bytes32','bytes32','uint64')))]
        self._history(a['staticSelection'], [selection_events, key])
        wire.validate(groups, a, self.graph, statement, content_result)
        return groups

    def _original_membership(self, scope, facts):
        a = self.a
        host = a['scopeMembership']
        member = {'facts': facts, 'publication': None, 'progress': None, 'metadataRecord': None,
                  'manifestBytes': None, 'parts': [], 'tokens': [], 'identities': [],
                  'lifecycles': [], 'inventoryTokens': [], 'progressHistory': []}
        if scope[0] == 1:
            tokens = [scope[2]]
        else:
            p = self._one(host, 'scopeMembershipPublication('+SCOPE_SIGNATURE+')', MEMBERSHIP_PUBLICATION,
                          (SCOPE,), (scope,))
            progress = self._one(host, 'scopeMembershipProgress('+SCOPE_SIGNATURE+')', MEMBERSHIP_PROGRESS,
                                 (SCOPE,), (scope,))
            require(p[0] == facts[2] and p[1] == facts[1], 'scoped source original membership publication')
            record, receipt = self._read(a['metadata'], 'collectionRecord(bytes32)',
                (wire.METADATA_RECORD, METADATA_RECEIPT), ('bytes32',), (p[0],), maximum=4096)
            require(receipt == p[7] and self._one(a['metadata'], 'recordHashAt(uint256,bytes32,uint256)', 'bytes32',
                ('uint256','bytes32','uint256'), (scope[1],schema_id('SCOPE_MEMBERSHIP'),receipt[4])) == p[0],
                'scoped source membership Metadata index/receipt')
            pointer, payload = self._read(a['metadata'], 'recordPayload(bytes32)', ('address','bytes'),
                                          ('bytes32',), (p[0],), maximum=8352)
            require(pointer == p[4] and payload == self._carrier(pointer,p[5],8192), 'scoped source membership carrier')
            store_pointer, length = self._read(a['store'], 'chunk(bytes32)', ('address','uint32'), ('bytes32',), (p[1],))
            require(store_pointer == pointer and length == len(payload), 'scoped source membership Store manifest')
            manifest = decode(MEMBERSHIP_MANIFEST,payload,maximum=2336)
            require(manifest[5] == facts[3] and len(manifest[7]) <= MAX_PARTS, 'scoped source membership part bound')
            whole = b''
            for digest in manifest[7]:
                pointer,length = self._read(a['store'],'chunk(bytes32)',('address','uint32'),('bytes32',),(digest,))
                code = hex_bytes(self.reader.code(pointer))
                require(pointer != ZERO_ADDRESS and 0 < length <= CHUNK_BYTES and len(code) == length+1
                        and code[0] == 0 and keccak256(code[1:]) == digest, 'scoped source membership part runtime')
                member['parts'].append({'pointer':pointer,'codeHash':keccak256(code),'runtime':'0x'+code.hex()})
                whole += code[1:]
            require(len(whole) == facts[3]*32, 'scoped source membership token byte length')
            tokens = [int.from_bytes(whole[i:i+32],'big') for i in range(0,len(whole),32)]
            member.update(publication=p,progress=progress,metadataRecord=record,manifestBytes='0x'+payload.hex())
            admitted = _event_topic('ScopeMembershipAdmitted', ('bytes32','uint256','uint8','bytes32','bytes32','bytes32','uint256','address','uint8'))
            progressed = _event_topic('ScopeMembershipProgressed', ('bytes32','uint256','uint256'))
            sealed = _event_topic('ScopeMembershipSealed', ('bytes32','bytes32','uint256'))
            events = self._history(host, [[admitted,progressed,sealed],scope[3]])
            for log in events['logs']:
                if log['topics'][0] == progressed:
                    require(len(log['topics']) == 2, 'scoped source membership progress event shape')
                    member['progressHistory'].append(decode(('uint256','uint256'),hex_bytes(log['data']),maximum=64))
            metadata_topic = _event_topic('CollectionRecordRecorded', ('uint256','bytes32','bytes32',wire.METADATA_RECORD,'bytes32','bytes32','address','bytes32','uint16'))
            self._history(a['metadata'],[metadata_topic,_topic('uint256',scope[1]),record[0],record[1]])
        for index, token in enumerate(tokens):
            require(self._one(host,'scopeTokenAt('+SCOPE_SIGNATURE+',uint256)','uint256',
                             (SCOPE,'uint256'),(scope,index)) == token, 'scoped source membership original token index')
            identity = self._read(a['core'],'tokenCollectionIdentity(uint256)',('bool','uint256','uint256','bool'),
                                  ('uint256',),(token,))
            lifecycle = self._one(a['core'],'tokenLifecycle(uint256)','uint8',('uint256',),(token,))
            member['identities'].append(identity);member['lifecycles'].append(lifecycle)
            if scope[0] != 1:
                member['inventoryTokens'].append(self._one(a['tokenInventory'],'collectionTokenBySerial(uint256,uint256)',
                    'uint256',('uint256','uint256'),(scope[1],identity[2])))
        member['tokens'] = tokens
        return member
