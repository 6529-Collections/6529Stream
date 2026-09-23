"""Selected native SchemaRegistry proof for the additive script interpretation."""
from . import genesis_registry_plan_v1 as genesis_plan
from . import genesis_registry_source_v1 as genesis
from . import token_script_interpretation_v1 as interpretation
from .canonical import dumps, keccak256, loads
from .independent_wire import require

PROFILE = 'STREAM_MUSEUM_TOKEN_SCRIPT_REGISTRY_SOURCE_V1'
CLAIMS = {'selectedNativeRegistryBound': True,
    'exactDocumentBytesAndStatusChecked': True,
    'registeredScriptInterpretationMatched': True,
    'registrationHistoryComplete': False, 'governanceAuthorizationProven': False,
    'sourceOriginAuthenticated': False, 'consensusVerified': False}
QUALIFICATION = ('Four fixed native documents, including the existing RFC8785_JCS '
    'canonicalizer and three additive script interpretation documents, are read from '
    'the current Core-selected Metadata SchemaRegistry at one source block. Every '
    'document must be ACTIVE and match exact bytes, declarations, ordered chunks '
    'and original Store carriers. This does not prove registration event history, '
    'governance action, provider origin, consensus or institutional acceptance.')
PROFILE_BYTES = dumps({'name': PROFILE, 'version': '1',
    'genesisRegistrySourceProfileHash': genesis.PROFILE_HASH,
    'interpretationProfileHash': interpretation.PROFILE_HASH,
    'documentNames': [row.name for row in interpretation.documents()],
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


class TokenScriptRegistrySource(genesis.GenesisRegistrySource):
    def __init__(self, anchor_bytes, transport, *, provenance='synthetic_fixture'):
        anchor = loads(anchor_bytes, maximum=genesis.MAX_ANCHOR, canonical=True)
        require(type(anchor) is dict and anchor.get('profile') == PROFILE,
            'script Registry anchor profile')
        frozen = genesis_plan.prepare()
        super().__init__(dumps(dict(anchor, profile=genesis.PROFILE)), transport,
            plan_files=dict(frozen.files), plan_hash=frozen.manifest_hash,
            provenance=provenance)
        self.a, self.anchor_bytes = anchor, bytes(anchor_bytes)

    def _capture(self):
        self._source()
        graph = self._graph()
        documents = [self._document(index, expected,
            graph['schemaRegistry'], graph['chunkStore'])
            for index, expected in enumerate(interpretation.documents())]
        require(all(row['matchesPlan'] and row['currentStatus'] == 'ACTIVE'
            for row in documents), 'script registered interpretation missing or differs')
        self._source()
        graph['runtimePins'] = [{'address': address, 'runtimeHash': digest}
            for address, digest in sorted(self.runtime_pins.items())]
        return dumps({'profile': PROFILE, 'profileHash': PROFILE_HASH, 'version': '1',
            'sourceState': {key: self.a[key] for key in genesis.COMMON},
            'anchorHash': keccak256(self.anchor_bytes),
            'transcriptHash': keccak256(self.reader.transcript()),
            'provenance': self.provenance, 'graph': graph,
            'interpretationProfileHash': interpretation.PROFILE_HASH,
            'documents': documents, 'claims': CLAIMS, 'qualification': QUALIFICATION})
