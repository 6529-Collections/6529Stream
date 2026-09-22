"""Version-local Artist review interpretation over complete original native evidence."""
from .account_profile import ACCOUNT_PREFIX, JCS_ID, account_iri
from .artist_attestation_source import ARCHIVE, ArtistAttestationSource
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_abi import decode
from .chain_rpc import MAX_TRANSCRIPT, RecordingReader, ReplayTransport, RpcTransport
from .independent_source import IndependentSourceAdapter
from .independent_wire import RAW_BYTES, ZERO, require
from .native_attribution_semantics import _metadata_positions, selector
from .owner_notice_semantics import consistent_reads
from .recorded_semantic import resolve_pointer
from .review import _validate

PROFILE = 'STREAM_MUSEUM_NATIVE_ARTIST_REVIEW_SOURCE_V1'


def scope(anchor):
    """Stable publication scope; later capture block/current state is not an issuer."""
    return {key: anchor[key] for key in ('chainId', 'core', 'collectionId', 'artistRegistry', 'host')}


def authority(native):
    """Only original immutable authority, excluding later revocation/rotation reads."""
    historical = native['historicalAuthority']
    raw = hex_bytes(native['archive']['bytesHex'])
    outer = decode(ARCHIVE, raw, maximum=524288)
    return {key: historical[key] for key in ('artistId', 'signer', 'authorityClass', 'bindingHash',
        'bindingGeneration')} | {'attestationRecordHash': native['attestationRecordHash'],
        'operationEvidenceId': native['archive']['evidenceId'], 'operationEvidenceHash': keccak256(raw),
        'actor': outer[3], 'grantRecordHash': native['associationWire'][3]}


class NativeArtistReviewSource:
    """Exact new profile only; malformed unselected interpretation stays a diagnostic."""
    _read = IndependentSourceAdapter._read
    _block = IndependentSourceAdapter._block
    _chunk = IndependentSourceAdapter._chunk
    _document = IndependentSourceAdapter._document

    def __init__(self, artist, transport, *, profile=None):
        from .native_artist_review_profile import NativeArtistReviewProfile
        require(type(artist) is ArtistAttestationSource, 'concrete native Artist review source required')
        require(artist.provenance != 'trusted_rpc' or type(transport) in (RpcTransport, ReplayTransport),
            'synthetic Artist review transport cannot become trusted')
        self.artist, self.catalogue = artist, artist.metadata_catalog
        self.a, self.pins, self.anchor_bytes = self.catalogue.a, self.catalogue.pins, self.catalogue.anchor_bytes
        self.provenance = artist.provenance
        self.profile = NativeArtistReviewProfile() if profile is None else profile
        require(type(self.profile) is NativeArtistReviewProfile, 'exact native Artist review profile required')
        self.reader = RecordingReader(transport, self.a['blockHash'])
        self.documents, self.document_stack, self.chunks = {}, set(), {}
        self.document_bytes, self._started, self._snapshot = 0, False, None

    def transcript(self):
        require(self._snapshot is not None, 'Artist review snapshot required')
        return self.reader.transcript()

    def snapshot(self):
        if self._snapshot is not None: return self._snapshot
        require(not self._started, 'failed Artist review source cannot resume')
        self._started = True
        try: return self._capture()
        except MuseumError: raise
        except (ValueError, TypeError, IndexError, KeyError, OverflowError) as exc:
            raise MuseumError('malformed native Artist review evidence') from exc

    def _registered_documents(self):
        for name, (kind, raw) in self.profile.documents.items():
            identifier = schema_id(name); self._document(identifier, kind)
            _, actual, view = self.documents[identifier]
            require(actual == raw and view[3][2] == keccak256(raw)
                and view[3][3] == self.profile.document_canonicalizations.get(name,
                    RAW_BYTES if identifier == JCS_ID else JCS_ID)
                and view[3][4] == self.profile.document_predecessors.get(name, ZERO),
                'Artist review registered interpretation differs')

    def _interpret(self, value, native, original, originals, positions):
        """Check shared envelope authority; individual assertions are checked separately."""
        from .native_artist_review_profile import ASSERTION_PROFILE_SCHEMA_ID
        record, receipt = original['record'], original['receipt']
        require(value['profileSchemaId'] == ASSERTION_PROFILE_SCHEMA_ID and value['anchorSubject'] == {
            'kind': 'collection' if original['subjectKind'] == 'collection' else 'token', 'subjectId': record[1]},
            'Artist review semantic subject/profile differs')
        signer = native['historicalAuthority']['signer']; issuer = account_iri(self.a['chainId'], signer)
        require(signer == receipt[1] and native['historicalAuthority']['artistId'] != ZERO,
            'Artist review original native signer/identity differs')
        references = [*value['sourceRecords'], *(reference for entity in value['entities'] for reference in entity['sourceRecords'])]
        for reference in references:
            previous = originals.get(reference['recordHash'])
            require(previous is not None and reference == selector(previous, self.a['host'], reference['pointer']),
                'Artist review original evidence selector differs')
            require(previous['recordHash'] in positions
                and positions[previous['recordHash']] < positions[original['recordHash']],
                'Artist review evidence must precede publication')
            resolve_pointer(hex_bytes(previous['payloadHex']), reference['pointer'])
        priors = [originals[reference['recordHash']] for reference in value['sourceRecords']]
        require(all(entity['declaringAgent'] == issuer and not entity['id'].casefold().startswith(ACCOUNT_PREFIX)
            for entity in value['entities']), 'Artist review declaring signer impersonation')
        return signer, priors

    def _interpret_assertion(self, assertion, signer, priors):
        require(assertion['assertingAgent'] == account_iri(self.a['chainId'], signer),
            'Artist review asserting signer impersonation')
        for evidence in assertion['evidence']:
            matches = [p for p in priors if evidence['source'] == {'algorithm': '1',
                'digest': keccak256(hex_bytes(p['payloadHex'])), 'canonicalizationId': p['record'][2][2]}]
            require(matches, 'Artist review evidence is not a referenced original')
            require(evidence['selectorType'] in ('json_pointer', 'whole_document')
                and (evidence['selectorType'] != 'whole_document' or evidence['selector'] == ''),
                'Artist review evidence selector unsupported')
            for previous in matches: resolve_pointer(hex_bytes(previous['payloadHex']), evidence['selector'])
            if evidence['basis'] == 'own_signed_statement':
                require(all(p['receipt'][1] == signer and p['receipt'][2] == '1' for p in matches),
                    'Artist review own statement has another signer')

    def _capture(self):
        from .native_artist_review_profile import ASSERTION_SCHEMA_BYTES, CLAIMS, NAMES, QUALIFICATION
        # Local evaluation views of the exact admitted schema, not replacement
        # registered schemas or rewritten payloads. Preserve original indices/bytes.
        envelope_schema = loads(ASSERTION_SCHEMA_BYTES)
        assertion_array = envelope_schema['properties'].pop('assertions')
        assertion_schema = dumps({'$schema': envelope_schema['$schema'], '$defs': envelope_schema['$defs'],
            '$ref': assertion_array['items']['$ref']})
        envelope_schema['required'].remove('assertions')
        envelope_schema = dumps(envelope_schema)
        raw_artist = self.artist.snapshot(); artist = loads(raw_artist, maximum=MAX_TRANSCRIPT, canonical=True)
        catalogue_raw = self.catalogue.snapshot(); catalogue = loads(catalogue_raw, maximum=MAX_TRANSCRIPT, canonical=True)
        originals = {row['recordHash']: row for row in catalogue['records']}
        positions = _metadata_positions(self.artist.transcript(), originals, self.a['host'])
        self._block()
        for key in ('schemas', 'store'):
            require(keccak256(hex_bytes(self.reader.code(self.a[key]))) == self.pins[self.a[key]],
                'Artist review interpretation runtime differs')
        rows, checked = [], False
        for native in artist['attestations']:
            original = native['metadataOriginal']; record = original['record']
            row = {'source': selector(original, self.a['host']), 'original': original,
                'nativeEvidence': native, 'nativeAuthority': authority(native),
                'historicalAuthority': native['historicalAuthority'], 'currentQualification': native['current'],
                'status': 'unsupported', 'reasonCode': 'source_schema_or_profile_unsupported',
                'payloadHex': original['payloadHex'], 'value': None, 'assertionInterpretations': [],
                'publicationPosition': [native['metadataPublicationPosition'][key]
                    for key in ('blockNumber', 'transactionIndex', 'logIndex')]}
            rows.append(row)
            if record[0] != schema_id('ARTIST_SEMANTIC_ASSERTION') or record[4] != schema_id(NAMES[1]) or record[2][2] != JCS_ID:
                continue
            try:
                value = loads(hex_bytes(original['payloadHex']), canonical=True)
                require(type(value) is dict, 'Artist review semantic envelope required')
            except MuseumError as exc:
                row.update(status='invalid', reasonCode='semantic_schema_invalid', diagnostic=str(exc)); continue
            if value.get('profileHash') != self.profile.profile_hash: continue
            if not checked:
                self._registered_documents(); checked = True
            # Definition admission is fatal even when interpretation is malformed.
            receipt = original['receipt']
            require(receipt[6] == keccak256(ASSERTION_SCHEMA_BYTES)
                and receipt[7] == keccak256(self.profile.documents['RFC8785_JCS'][1]),
                'Artist review receipt definition differs')
            try:
                require(type(value.get('assertions')) is list
                    and assertion_array['minItems'] <= len(value['assertions']) <= assertion_array['maxItems'],
                    'Artist review assertion array shape/bound differs')
                _validate(envelope_schema, dumps({key: item for key, item in value.items() if key != 'assertions'}))
            except MuseumError as exc:
                row.update(status='invalid', reasonCode='semantic_schema_invalid', diagnostic=str(exc)); continue
            try:
                signer, priors = self._interpret(value, native, original, originals, positions)
            except MuseumError as exc:
                row.update(status='invalid', reasonCode='semantic_authority_or_evidence_invalid', diagnostic=str(exc)); continue
            row.update(status='supported', reasonCode=None, value=value)
            for index, assertion in enumerate(value['assertions']):
                interpretation = {'pointer': '/assertions/' + str(index), 'status': 'invalid',
                    'reasonCode': 'semantic_schema_invalid'}
                row['assertionInterpretations'].append(interpretation)
                try:
                    _validate(assertion_schema, dumps(assertion))
                except MuseumError as exc:
                    interpretation['diagnostic'] = str(exc); continue
                try:
                    self._interpret_assertion(assertion, signer, priors)
                except MuseumError as exc:
                    interpretation.update(reasonCode='semantic_authority_or_evidence_invalid', diagnostic=str(exc)); continue
                interpretation.update(status='supported', reasonCode=None)
        self._block()
        if type(self.reader.transport) is ReplayTransport: self.reader.transport.finish()
        transcript = self.reader.transcript()
        consistent_reads([self.catalogue.transcript(), self.artist.transcript(), transcript])
        result = dumps({'profile': PROFILE, 'version': '1',
            'interpretationProfileHash': self.profile.profile_hash, 'anchorHash': keccak256(self.anchor_bytes),
            'mode': 'caller_admitted_rpc_artist_review' if self.provenance == 'trusted_rpc' else 'synthetic_fixture',
            'sourceScope': scope(self.a), 'sourceState': artist['sourceState'],
            'artistSourceHash': keccak256(raw_artist), 'metadataCatalogueHash': keccak256(catalogue_raw),
            'transcriptHash': keccak256(transcript), 'statements': rows,
            'documents': [{'documentId': key, 'rawViewHex': '0x' + raw.hex(), 'payloadHex': '0x' + payload.hex()}
                for key, (raw, payload, _) in sorted(self.documents.items())],
            'claims': CLAIMS, 'qualification': QUALIFICATION})
        require(len(result) <= MAX_TRANSCRIPT, 'Artist review source snapshot bound')
        self._snapshot = result
        return self._snapshot

    def assertion(self, reference):
        snapshot = loads(self.snapshot(), maximum=MAX_TRANSCRIPT, canonical=True)
        require(type(reference) is dict and type(reference.get('pointer')) is str
            and reference['pointer'].startswith('/assertions/'), 'Artist review exact assertion pointer required')
        index = uint(reference['pointer'][len('/assertions/'):], 64)
        rows = [row for row in snapshot['statements'] if reference == row['source'] | {'pointer': reference['pointer']}]
        require(len(rows) == 1 and rows[0]['status'] == 'supported', 'Artist review selected original unavailable or invalid')
        row = rows[0]
        require(index < len(row['value']['assertions']), 'Artist review assertion index unavailable')
        require(row['assertionInterpretations'][index]['status'] == 'supported',
            'Artist review selected assertion unavailable or invalid')
        return row['value']['assertions'][index], row


def review_body(source, reference, disposition):
    """Prepare an exact target body from an admitted original; never publish it."""
    require(type(source) is NativeArtistReviewSource, 'concrete Artist review source required')
    assertion, row = source.assertion(reference)
    from .native_artist_review_profile import BODY_SCHEMA_BYTES
    body = {'assertionRecord': reference, 'assertionRevisionHash': keccak256(dumps(assertion)),
        'profileHash': row['value']['profileHash'], 'mappingRule': assertion['mappingRule'],
        'disposition': disposition, 'sourceScope': scope(source.a), 'assertionAuthority': row['nativeAuthority']}
    return _validate(BODY_SCHEMA_BYTES, dumps(body))
