"""Original VIEW snapshot/Store getters; no currentSource or requireCurrent calls."""
from . import view_preservation_snapshot_types_v1 as t, view_preservation_snapshot_wire_v1 as wire
from .canonical import hex_bytes, keccak256, uint
from .chain_abi import decode
from .independent_wire import ZERO, json_values, require
from .native_finality_wire import event_matches, from_json

SCOPE_SIGNATURE = '(uint8,uint256,uint256,bytes32)'


class ViewPreservationSnapshotReads:
    """Parent provides a/graph, _one/_read/_carrier/_history and source context."""

    def _view_preservation_snapshot(self, record_hash=None, scope=None):
        a, graph = self.a, self.graph
        host = graph['viewSnapshot']['address']
        scope = from_json(t.SCOPE, a['scope'] if scope is None else scope)
        record_hash = a['snapshotRecordHash'] if record_hash is None else record_hash
        require(self._one(host, 'core()', 'address') == a['core']
            and self._one(host, 'metadataHost()', 'address') == graph['metadata']['address'],
            'VIEW snapshot immutable Core/Metadata')
        dependencies = self._one(host, 'dependencies()', t.DEPENDENCIES)
        require(self._one(host, 'governanceAuthority()', 'address') == graph['authority']['address']
            and self._one(host, 'authorityCodeHash()', 'bytes32') == graph['authority']['runtimeHash'],
            'VIEW snapshot original authority binding')
        count = self._one(host, 'snapshotCount('+SCOPE_SIGNATURE+')', 'uint256', (t.SCOPE,), (scope,))
        require(0 < count <= t.MAX_HISTORY, 'VIEW snapshot full history bound')
        history, total = [], 0
        for index in range(count):
            key = self._one(host, 'snapshotAt('+SCOPE_SIGNATURE+',uint256)', 'bytes32',
                (t.SCOPE, 'uint256'), (scope, index))
            p, r = self._read(host, 'snapshotRecord(bytes32)', (t.PUBLICATION, t.RECEIPT), ('bytes32',), (key,), maximum=4096)
            require(p[0] == scope and r[0] == key != ZERO and 0 < r[6] <= t.MAX_PAYLOAD, 'VIEW snapshot indexed original/scope')
            total += r[6]; require(total <= 16*1024*1024, 'VIEW snapshot aggregate payload bound')
            raw = self._one(host, 'snapshotPayload(bytes32)', 'bytes', ('bytes32',), (key,), maximum=t.MAX_PAYLOAD+96)
            require(len(raw) == r[6] and keccak256(raw) == r[5], 'VIEW snapshot original payload hash/length')
            decoded = decode(t.ENVELOPE, raw, maximum=t.MAX_PAYLOAD)
            chunks = []
            chunk_count = self._one(host, 'snapshotChunkCount(bytes32)', 'uint256', ('bytes32',), (key,))
            require(chunk_count == (len(raw)+8191)//8192, 'VIEW snapshot complete native chunk count')
            for offset in range(chunk_count):
                pointer, digest, length = self._read(host, 'snapshotChunkAt(bytes32,uint256)',
                    ('address', 'bytes32', 'uint32'), ('bytes32', 'uint256'), (key, offset))
                expected = raw[offset*8192:(offset+1)*8192]
                require(digest == keccak256(expected) and length == len(expected), 'VIEW snapshot chunk original layout')
                require(self._read(graph['store']['address'], 'chunk(bytes32)', ('address', 'uint32'),
                    ('bytes32',), (digest,)) == (pointer, length), 'VIEW snapshot original Store descriptor')
                body = self._carrier(pointer, keccak256(b'\0'+expected), 8192)
                require(body == expected, 'VIEW snapshot original Store bytes')
                chunks.append({'pointer': pointer, 'chunkHash': digest, 'byteLength': str(length),
                    'runtime': '0x'+(b'\0'+body).hex()})
            history.append({'publication': json_values(p), 'receipt': json_values(r),
                'source': json_values(decoded[-1]), 'payload': '0x'+raw.hex(), 'chunks': chunks})
        current = self._one(host, 'currentSnapshot('+SCOPE_SIGNATURE+')', t.RECEIPT, (t.SCOPE,), (scope,))
        lock = self._one(host, 'snapshotLock('+SCOPE_SIGNATURE+')', t.LOCK, (t.SCOPE,), (scope,))
        value = {'dependencies': json_values(dependencies), 'selectedRecordHash': record_hash,
            'current': json_values(current), 'history': history, 'lock': json_values(lock)}
        wire.validate(value, a, graph)
        expected = wire.expected_events(value, a, graph)
        for topic in (wire.PUBLISHED, wire.LOCKED):
            originals = [row for row in expected if row['topics'][0] == topic]
            observed = self._history(host, [topic, current[1]])['logs']
            require(len(originals) == len(observed) and all(event_matches(
                (row['address'], row['topics'], row['data']), log)
                for row, log in zip(originals, observed)),
                'VIEW snapshot complete publication/lock event history differs')
        return value
