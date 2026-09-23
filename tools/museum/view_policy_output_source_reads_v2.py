"""Historical VIEW checkpoint and complete parts/index reads; no currentness substitution."""
from copy import deepcopy
from . import view_policy_output_types_v2 as t, view_policy_output_wire_v2 as wire
from .canonical import hex_bytes, uint
from .chain_abi import decode
from .independent_wire import ZERO, json_values, require


class ViewPolicyOutputReads:
    """Host supplies a/graph and exact _one/_read/_history/_carrier primitives."""

    def _view_output_header(self):
        a, graph = self.a, self.graph
        address = lambda role: graph[role]['address']
        configuration = {}
        for role, kind, profile, getter, interface in (
            ('checkpoint', t.CHECKPOINT_CONFIG, t.PROFILE, 'checkpointProfile()', t.CHECKPOINT_INTERFACE),
            ('outputManifest', t.MANIFEST_CONFIG, t.OUTPUT_PROFILE, 'outputProfile()', t.MANIFEST_INTERFACE),
        ):
            require(self._one(address(role), getter, 'bytes32') == profile, 'VIEW exact output profile')
            for interface_id, expected in ((interface, True), ('0x01ffc9a7', True), ('0xffffffff', False)):
                require(self._one(address(role), 'supportsInterface(bytes4)', 'bool', ('bytes4',),
                    (interface_id,)) is expected, 'VIEW exact output interface')
            name = 'checkpoint' if role == 'checkpoint' else 'manifest'
            configuration[name] = json_values(self._one(address(role), 'configuration()', kind))
            configuration[name + 'Hash'] = self._one(address(role), 'configurationHash()', 'bytes32')
        for host, getter, worker in (
            ('checkpoint', 'sourceWorkerCodeHash()', 'checkpointSourceWorker'),
            ('checkpoint', 'tokenWorkerCodeHash()', 'checkpointTokenWorker'),
            ('outputManifest', 'readWorkerCodeHash()', 'manifestReadWorker'),
            ('outputManifest', 'encodingWorkerCodeHash()', 'manifestEncodingWorker'),
        ):
            require(self._one(address(host), getter, 'bytes32') == graph[worker]['runtimeHash'],
                'VIEW original linked worker pin')
        key, record = a['checkpointId'], a['manifestRecordHash']
        require(key != ZERO and record != ZERO, 'VIEW exact selected output keys')
        plan = self._one(address('checkpoint'), 'checkpoint(bytes32)', t.CHECKPOINT_PLAN, ('bytes32',), (key,))
        require(plan[0][0] == 4 and plan[0][1] == uint(a['collectionId']) and plan[0][2] == 0 and plan[0][3] != ZERO
            and 0 < plan[5] <= t.MAX_ROWS and plan[6] == plan[5] and plan[8] != ZERO,
            'VIEW source complete historical checkpoint')
        history = self._history(address('checkpoint'), [wire.EVENTS['checkpoint_started'], key])
        logs = history['logs']
        require(len(logs) == 1, 'VIEW original checkpoint start denominator')
        log = logs[0]
        require(log['address'] == address('checkpoint') and log['topics'] == [wire.EVENTS['checkpoint_started'], key, plan[1]],
            'VIEW original checkpoint start identity')
        salt, = decode(('bytes32',), hex_bytes(log['data']), maximum=32)
        manifest = self._one(address('outputManifest'), 'manifestRecord(bytes32)', t.MANIFEST_PLAN, ('bytes32',), (record,))
        require(manifest[0] == wire.header(key, plan) and manifest[7] == record,
            'VIEW original selected manifest/checkpoint')
        plan_hash = wire.manifest_plan_hash(uint(a['chainId']), address('outputManifest'), configuration['manifestHash'],
            manifest[0], manifest[1])
        require(self._one(address('outputManifest'), 'manifestPlan(bytes32)', t.MANIFEST_PLAN, ('bytes32',), (plan_hash,)) == manifest,
            'VIEW original manifest plan/record differs')
        return {'configuration': configuration,
            'checkpoint': {'id': key, 'salt': salt, 'plan': json_values(plan)},
            'manifest': {'recordHash': record, 'planHash': plan_hash, 'plan': json_values(manifest)}}

    def _view_covered_carrier(self, saved):
        host = self.graph['coverage']['address']
        require(saved[0] != ZERO and saved[1] != ZERO and 0 < saved[4] <= t.MAX_BYTES, 'VIEW bounded carrier')
        coverage = self._one(host, 'coverage(bytes32)', t.COVERAGE, ('bytes32',), (saved[1],))
        count = (saved[4] + t.CHUNK_BYTES - 1) // t.CHUNK_BYTES
        require(coverage[7] == count, 'VIEW original covered chunk denominator')
        chunks = []
        for index in range(count):
            pointer, digest = self._read(host, 'artifactChunk(bytes32,uint32)', ('address', 'bytes32'),
                ('bytes32', 'uint32'), (saved[0], index))
            raw = self._carrier(pointer, digest, t.CHUNK_BYTES)
            chunks.append({'pointer': pointer, 'codeHash': digest, 'runtime': '0x' + (b'\0' + raw).hex()})
        return {'coverage': json_values(coverage), 'chunks': chunks}

    def _view_outputs(self, header, adoption):
        value = deepcopy(header)
        cp, manifest = value['checkpoint'], value['manifest']
        plan = wire._v(t.CHECKPOINT_PLAN, cp['plan'])
        cp['outputs'] = [json_values(self._one(self.graph['checkpoint']['address'], 'outputAt(bytes32,uint256)', t.OUTPUT,
            ('bytes32', 'uint256'), (cp['id'], index))) for index in range(plan[5])]
        mp = wire._v(t.MANIFEST_PLAN, manifest['plan'])
        require(mp[2] == (plan[5] + 63) // 64 and mp[3] == mp[2] and mp[4] == plan[5], 'VIEW complete manifest parts')
        parts = []
        for index in range(mp[2]):
            descriptor = self._one(self.graph['outputManifest']['address'], 'manifestPart(bytes32,uint256)', t.DESCRIPTOR,
                ('bytes32', 'uint256'), (manifest['recordHash'], index))
            part = self._one(self.graph['outputManifest']['address'], 'partRecord(bytes32)', t.PART,
                ('bytes32',), (descriptor[0],))
            parts.append({'recordHash': descriptor[0], 'record': json_values(part), 'descriptor': json_values(descriptor),
                **self._view_covered_carrier(part[1])})
        manifest.update(parts=parts, **self._view_covered_carrier(mp[1]))
        wire.validate(value, self.a, self.graph, adoption)
        return value
