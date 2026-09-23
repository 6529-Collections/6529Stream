"""Token-resolved native script source over the unchanged collection script wire.

An activation and every subsequent collection/token override are read from
Router events through the pinned block. Script classification is positive only when a selected manifest has
complete verified bytes; a zero selection never proves a non-script work.
"""
from . import collection_script_source_v1 as collection
from . import collection_script_wire_v1 as wire
from . import policy_static_components_v2 as static
from . import public_chain_history as history
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_abi import decode, encode
from .chain_rpc import quantity
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require
from .scoped_static_types import STATIC_SELECTION

PROFILE = 'STREAM_MUSEUM_TOKEN_SCRIPT_SOURCE_V1'
AUTHORIZATION = ('address', 'bytes32', 'address', 'uint8', 'uint256', 'uint64')
IDENTITY = ('bool', 'uint256', 'uint256', 'bool')
ACTIVATION = ('bytes32', 'uint64', 'bytes32')
RECORDED_EVENT = schema_id('MetadataConfigRecorded(uint16,uint256,uint256,bytes32,(bytes32,bytes32,uint256,uint256,uint64,uint64,uint8,bytes32,(address,bytes32,bytes32,address,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32),(uint8,address,string,string,uint8,bool)))')
ACTIVATED_EVENT = schema_id('MetadataStaticActivated(uint16,uint256,bytes32,bytes32)')
AUTHORIZATION_EVENT = schema_id('MetadataConfigAuthorization(bytes32,address,(address,bytes32,address,uint8,uint256,uint64))')
OVERRIDES_DOMAIN = schema_id('6529STREAM_STATIC_METADATA_OVERRIDES_V1')
QUALIFICATION = ('Exact token-to-collection identity, current Router-resolved STATIC config, '
    'stored record/authorization, activation and its retained global default record, original runtime and selected '
    'script bytes at one pinned block. Collection/token overrides and frozen source are checked. A present '
    'manifest with complete bytes establishes positive script classification only. A zero, '
    'unavailable or unsupported source establishes no negative classification. Registered '
    'interpretation, historical writer grant, renderer execution, provider '
    'origin and consensus require separate evidence.')
CLAIMS = {'tokenIdentityBound': True, 'nativeResolutionChecked': True,
    'activationBaseChecked': True, 'originalScriptBytesCheckedWhenComplete': True,
    'registeredInterpretationProven': False, 'collectionOverrideLineageProven': True,
    'historicalWriterGrantProven': False, 'nonScriptClassificationProven': False,
    'rendererExecuted': False, 'sourceOriginAuthenticated': False,
    'consensusVerified': False}
PROFILE_BYTES = dumps({'name': PROFILE, 'version': '1',
    'collectionSourceProfileHash': collection.PROFILE_HASH,
    'scriptWireProfileHash': wire.PROFILE_HASH,
    'staticSourceRevision': static.SOURCE_REVISION,
    'supportedConfigLineage': 'one event-proven activation and all collection/token overrides through source block',
    'classification': 'positive selected executable complete script only',
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


class TokenScriptSource(collection.CollectionScriptSource):
    def __init__(self, anchor_raw, transport, *, provenance='synthetic_fixture'):
        a = loads(anchor_raw, maximum=collection.MAX_ANCHOR, canonical=True)
        require(type(a) is dict and set(a) == set(collection.COMMON) |
            {'profile', 'tokenId', 'coreRuntimeHash', 'codePins', 'runtimeAdmission'}
            and a['profile'] == PROFILE and uint(a['tokenId']) > 0,
            'token script closed anchor/token')
        super().__init__(dumps({key: value for key, value in a.items() if key != 'tokenId'} |
            {'profile': collection.PROFILE}), transport, provenance=provenance)
        self.a, self.anchor_bytes = a, bytes(anchor_raw)

    def _record(self, router, key):
        require(key != ZERO and any(hex_bytes(key, 32)), 'token script empty config record')
        record = self._read(router, 'metadataConfigRecord(bytes32)', static.CONFIG_RECORD,
            ('bytes32',), (key,))
        require(record[0] == key and static._record_hash(self.a['core'], router, record) == key,
            'token script stored config hash differs')
        return record

    def _authorization(self, router, key):
        auth = self._read(router, 'metadataConfigAuthorization(bytes32)', AUTHORIZATION,
            ('bytes32',), (key,))
        require(auth[0] != ZERO_ADDRESS and auth[2] != ZERO_ADDRESS and
            auth[3] in (7, 8) and auth[4] in (0, uint(self.a['collectionId'])) and
            auth[5] > 0 and auth[1] == self.pins.get(auth[0]),
            'token script stored authorization differs')
        self._pin(auth[0])
        require(self._read(auth[0], 'core()', 'address') == self.a['core'] and
            self._read(auth[0], 'coreCodeHash()', 'bytes32') == self.a['coreRuntimeHash'],
            'token script authorization Metadata binding differs')
        return auth

    def _lineage(self, router, cid, token, activation):
        filters = [{'address': router, 'topics': [RECORDED_EVENT, '0x' + f'{cid:064x}']},
            {'address': router, 'topics': [ACTIVATED_EVENT, '0x' + f'{cid:064x}']},
            {'address': router, 'topics': [AUTHORIZATION_EVENT]}]
        observed = history.scan_public_history(self.reader, self.a, filters=filters)
        events, authorizations, activated = [], [], None
        for log in observed['logs']:
            topics = log['topics']
            if topics[0] == RECORDED_EVENT:
                require(len(topics) == 4 and int(topics[1], 16) == cid,
                    'token script config event topics')
                version, record = decode(('uint16', static.CONFIG_RECORD),
                    hex_bytes(log['data']), maximum=collection.MAX_ABI)
                require(version == 1 and int(topics[2], 16) == record[3] and
                    topics[3] == record[0] and record[2] == cid and
                    static._record_hash(self.a['core'], router, record) == record[0],
                    'token script config event/record differs')
                events.append((log, record))
            elif topics[0] == AUTHORIZATION_EVENT:
                require(len(topics) == 3, 'token script authorization event topics')
                (auth,) = decode((AUTHORIZATION,), hex_bytes(log['data']),
                    maximum=collection.MAX_ABI)
                require(topics[2] == '0x' + '00' * 12 + auth[2][2:],
                    'token script authorization event actor differs')
                authorizations.append((log, auth))
            else:
                require(topics[0] == ACTIVATED_EVENT and len(topics) == 3 and
                    int(topics[1], 16) == cid and activated is None,
                    'token script activation event topics/count')
                version, _ = decode(('uint16', 'bytes32'), hex_bytes(log['data']),
                    maximum=collection.MAX_ABI)
                require(version == 1, 'token script activation event version')
                activated = log
        require(activated is not None, 'token script activation event missing')
        for log, record in events:
            paired = [(event, auth) for event, auth in authorizations if
                event['transactionHash'] == log['transactionHash'] and
                int(event['logIndex'], 16) + 1 == int(log['logIndex'], 16)]
            require(len(paired) == 1 and paired[0][0]['topics'][1] == record[0] and
                paired[0][1] == self._authorization(router, record[0]) and
                record == self._record(router, record[0]),
                'token script authorization/record event pairing differs')
        prior = [(log, row) for log, row in events if
            log['transactionHash'] == activated['transactionHash'] and
            quantity(log['logIndex']) + 1 == quantity(activated['logIndex'])]
        require(len(prior) == 1, 'token script activation record/event pairing differs')
        first = prior[0][1]
        require(first[3] == 0 and first[6] == 3 and first[4] == 1 and
            first[1] == activated['topics'][2] == activation[0] and
            first[5] == activation[1], 'token script activation default lineage differs')
        retained_default = self._record(router, first[1])
        require(retained_default[2] == 0 and retained_default[3] == 0 and
            retained_default[6] == 0 and retained_default[4] == first[5] and
            retained_default[5] == first[5] and retained_default[8] == first[8] and
            retained_default[9] == first[9],
            'token script retained default/activation differs')
        require(self._record(router, first[0]) == first,
            'token script activation stored record differs')
        position = lambda log: tuple(quantity(log[key]) for key in
            ('blockNumber', 'transactionIndex', 'logIndex'))
        after = [(log, row) for log, row in events if position(log) > position(activated)]
        require(len(events) == 1 + len(after),
            'token script unexpected preactivation config record')
        head, revision, collection_key, token_keys = ZERO, 1, first[0], {}
        for log, row in after:
            record_token = row[3]
            require(row[6] == (1 if record_token == 0 else 2) and
                row[4] == revision + 1 and row[5] == first[5] and
                row[1] == (collection_key if record_token == 0 and collection_key != first[0]
                    else ZERO if record_token == 0 else token_keys.get(record_token, ZERO)),
                'token script override predecessor/revision differs')
            # Collection slot starts empty after activation; its first previous
            # link is zero, even though the resolved fallback is the activation.
            head = keccak256(encode(('bytes32', 'bytes32', 'uint256', 'uint256',
                'bytes32', 'uint64'), (OVERRIDES_DOMAIN, head, cid,
                record_token, row[0], row[4])))
            revision = row[4]
            if record_token == 0:
                collection_key = row[0]
            else:
                token_keys[record_token] = row[0]
        require(activation[2] == head, 'token script overrides head differs')
        return first, retained_default, collection_key, token_keys.get(token, collection_key), observed

    def _capture(self):
        self._state()
        a = self.a; cid, token = uint(a['collectionId']), uint(a['tokenId'])
        identity = self._read(a['core'], 'tokenCollectionIdentity(uint256)', IDENTITY,
            ('uint256',), (token,))
        require(identity[0] and identity[1] == cid and identity[2] > 0,
            'token script Core token/collection identity differs')
        self.graph, pointers = self._graph()
        router = self.graph['router']['address']
        selected = self._read(router, 'resolvedMetadataConfig(uint256)', static.CONFIG_RECORD,
            ('uint256',), (token,))
        base = self._read(router, 'collectionMetadataConfig(uint256)', static.CONFIG_RECORD,
            ('uint256',), (cid,))
        require(base[0] != ZERO and base == self._record(router, base[0]) and
            base[2] == cid and base[3] == 0 and base[6] in (1, 3) and base[5] > 0,
            'token script collection config differs')
        activation = self._read(router, 'staticMetadataActivation(uint256)', ACTIVATION,
            ('uint256',), (cid,))
        first, retained_default, collection_key, token_key, lineage = self._lineage(
            router, cid, token, activation)
        require(base[0] == collection_key and base[5] == first[5] and
            selected[0] == token_key and selected == self._record(router, selected[0]) and
            selected[2] == cid and selected[5] == first[5] and
            (selected == base or (selected[3] == token and selected[6] == 2)),
            'token script token resolution/override differs')
        auth = self._authorization(router, selected[0])
        base_auth = auth if selected == base else self._authorization(router, base[0])
        for record in (base, selected):
            config, render = record[9], record[8]
            require(config[0] in (0, 1, 2) and config[1] == render[3] and
                render[0] != ZERO_ADDRESS and render[1] != ZERO and
                render[3] != ZERO_ADDRESS and render[4] != ZERO,
                'token script renderer selection/config differs')
            for address, digest in ((render[0], render[1]), (render[3], render[4])):
                require(self.pins.get(address) == digest, 'token script renderer external pin differs')
                self._pin(address)
        source, config = self._read(router, 'staticRenderSourceForConfig(uint256,bytes32)',
            (static.RAW_SOURCE, static.METADATA_CONFIG), ('uint256', 'bytes32'),
            (cid, selected[0]))
        require(config == selected[9] and source[0] == uint(a['chainId']) and source[1],
            'token script original source/config differs')
        require((selected[7] == ZERO and not config[5]) or
            (selected[7] != ZERO and config[5] and
                static._source_snapshot_hash(source) == selected[7]),
            'token script frozen source commitment differs')
        manifest = dict(zip(collection.NAMES['selection'], json_values(source[7])))
        status, interpretation = 'zero_selection', None
        if manifest['manifestHash'] != ZERO:
            require(manifest['host'] != ZERO_ADDRESS and manifest['codeHash'] != ZERO,
                'token script selected manifest pairing differs')
            serving = {'status': 'available', 'value': {'script': source[6]}}
            interpretation, status = self._interpret('resolved_token_config', manifest, serving)
        else:
            require(manifest['host'] == ZERO_ADDRESS and manifest['codeHash'] == ZERO,
                'token script zero manifest pairing differs')
        positive = (interpretation is not None and
            interpretation['report']['completeScriptBytes'] is True)
        self._state()
        return {'profile': PROFILE, 'profileHash': PROFILE_HASH, 'version': '1',
            'anchorHash': keccak256(self.anchor_bytes),
            'transcriptHash': keccak256(self.transcript()), 'provenance': self.provenance,
            'sourceState': {key: a[key] for key in (*collection.COMMON, 'tokenId')},
            'identity': json_values(identity), 'graph': self.graph,
            'pointerAdmissions': pointers, 'activation': json_values(activation),
            'activationRecord': json_values(first),
            'retainedDefaultRecord': json_values(retained_default),
            'lineageEvents': lineage['logs'], 'historyCoverage': lineage['coverage'],
            'baseRecord': json_values(base), 'baseAuthorization': json_values(base_auth),
            'resolvedRecord': json_values(selected), 'resolvedAuthorization': json_values(auth),
            'rawSource': json_values(source), 'selectedConfig': json_values(config),
            'manifestSelection': manifest, 'interpretationStatus': status,
            'interpretation': interpretation, 'positiveScriptClassification': positive,
            'workClass': 'script' if positive else 'unknown',
            'observations': self.observations, 'runtimeObservations': self.runtime_observations,
            'claims': CLAIMS, 'qualification': QUALIFICATION}
