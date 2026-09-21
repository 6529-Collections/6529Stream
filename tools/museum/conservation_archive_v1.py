"""All-occurrence retained-byte and original dual-family Archive correspondence.

The caller replays the dossier first. This additional supplied-evidence check
does not authenticate archive observations, signatures, delivery or liveness.
"""
from copy import deepcopy
import base64
import hashlib
import json

import rfc8785
from blake3 import blake3

from . import conservation_dossier_projection_v1 as projection
from . import view_preservation_bundle_wire_v1 as archive
from .bagit import _paths
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_abi import calldata, decode, encode
from .independent_wire import ZERO, json_values, require

NAME = 'STREAM_MUSEUM_CONSERVATION_ARCHIVE_CORRESPONDENCE_V1'
SOURCE_REVISION = archive.SOURCE_REVISION
MAX_BYTES = 64 * 1024 * 1024
MAX_MATERIAL = 16 * 1024 * 1024
MAX_OCCURRENCES = 16384
PLAN = ('bytes32',)*4 + ('uint64','uint32','bytes32','bytes32')
CHUNK_SCHEMA = schema_id('6529STREAM_FINALITY_ARTIFACT_CHUNK_V1')
ESTATE_SCHEMA = schema_id('6529STREAM_PUBLIC_ESTATE_EVIDENCE_V1')
BINARY = schema_id('BINARY_EXACT_V1')
QUALIFICATION = (
    'Every original reference occurrence is retained, including duplicates and unselected catalog '
    'specifications. Complete means supplied bytes and original dual-family archive preimages '
    'correspond for every occurrence under this bounded verifier; it is not M10 institutional '
    'acceptance. Unsupported opaque encodings/codecs and unknown canonicalizations remain unresolved. Formats are '
    'exact declarations, not detected codecs. Archive observations and runtime identities are '
    'caller-admitted at the original source block. No delivery, URI retrieval, current availability, '
    'historical signature authorization, consensus, family admission or native execution is proved.')
CLAIMS = {'allOriginalReferenceOccurrencesAccounted': True, 'duplicateOccurrencesPreserved': True,
    'declaredFormatsPreserved': True, 'sourceProvenanceAuthenticated': False,
    'archiveDeliveryProven': False, 'currentAvailabilityProven': False, 'uriRetrievalProven': False,
    'historicalSignaturesVerified': False, 'archiveConsensusVerified': False,
    'familyAdmissionReplayed': False, 'formatDetected': False, 'nativeExecutionProven': False,
    'completeM10Proven': False}
PROFILE_BYTES = dumps({'name': NAME, 'version': '1', 'sourceRevision': SOURCE_REVISION,
    'projectionProfileHash': projection.PROFILE_HASH,
    'archivePrimitives': 'StreamBundleArchiveReads original external/artifact/chunk preimages; no VIEW inventory projection.',
    'algorithms': {'1': 'Keccak-256', '2': 'SHA-256', '3': 'BLAKE3-256 via pinned blake3 1.0.9',
        '4': 'Canonical binary SHA2-256 multihash; other opaque forms unresolved',
        '5': 'CIDv1/raw/SHA2-256 binary or lower-base32 identifier; other opaque forms unresolved',
        '6': 'Exact original external receipt/checkpoint transaction identity, not a byte digest'},
    'canonicalizations': ['RAW_BYTES', 'RFC8785_JCS exact original canonical bytes'],
    'bounds': {'totalBytes': str(MAX_BYTES), 'materialBytes': str(MAX_MATERIAL), 'occurrences': str(MAX_OCCURRENCES)},
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)
OUTPUTS = ('archive/profile.json', 'archive/correspondence.json', 'archive/report.json')


def _closed(value, keys, label):
    require(type(value) is dict and set(value) == set(keys), 'conservation archive ' + label + ' shape')


def _sha(raw):
    return '0x' + hashlib.sha256(raw).hexdigest()


def _load(files):
    require(type(files) is dict, 'conservation archive dossier files')
    snapshot = loads(files['input/source/snapshot.json'], maximum=MAX_BYTES, canonical=True)
    for path, raw in projection.project(snapshot).items():
        require(files.get(path) == raw, 'conservation archive projection differs')
    dossier = loads(files[projection.OUTPUTS[0]], maximum=MAX_BYTES, canonical=True)
    inventory = loads(files[projection.OUTPUTS[1]], maximum=MAX_BYTES, canonical=True)
    transcript = loads(files['input/source/transcript.json'], maximum=MAX_BYTES, canonical=True)
    require(keccak256(files['input/source/transcript.json']) == snapshot['transcriptHash'],
        'conservation archive source transcript pin')
    return snapshot, dossier, inventory['occurrences'], transcript


def template(projected_files):
    """All-null diagnostic envelope; no missing material is silently omitted."""
    snapshot, _, occurrences, _ = _load(projected_files)
    return dumps({'profileHash': PROFILE_HASH, 'dossierHash': keccak256(projected_files[projection.OUTPUTS[0]]),
        'referenceInventoryHash': keccak256(projected_files[projection.OUTPUTS[1]]),
        'context': deepcopy(snapshot['source']), 'graph': {},
        'occurrences': [{'occurrence': row['occurrence'], 'materialPath': None, 'archive': None}
            for row in occurrences],
        'sourceBindings': {'blockHash': snapshot['source']['blockHash'],
            'provenance': 'synthetic_fixture' if snapshot['mode'] == 'synthetic_fixture' else 'externally_admitted_rpc',
            'calls': []}})


class _Originals(archive._Originals):
    def __init__(self, snapshot, transcript, graph):
        super().__init__(snapshot['source'], {})
        self.source_answers = {}
        for row in snapshot['source']['codePins']:
            self.pin(row['address'], row['runtimeHash'])
        for row in transcript['calls']:
            if 'result' not in row: continue
            if row['method'] == 'eth_getCode':
                address, block = row['params']
                require(block == {'blockHash': self.context['blockHash'], 'requireCanonical': True},
                    'conservation archive source code block')
                self.pin(address, keccak256(hex_bytes(row['result'])))
            if row['method'] == 'eth_call':
                request, block = row['params']
                if block == {'blockHash': self.context['blockHash'], 'requireCanonical': True}:
                    self.source_answers[(request['to'], request['data'])] = row['result']
        for row in graph.values(): self.pin(row['address'], row['runtimeHash'])

    def read(self, host, signature, inputs, arguments, result):
        data = calldata(signature, inputs, arguments)
        require(self.source_answers.get((host, data), result) == result
            and self.answers.setdefault((host, data), result) == result,
            'conservation archive conflicting original getter')
        self.calls.append({'target': host, 'calldata': data, 'result': result})

    def address_read(self, host, signature, address):
        self.read(host, signature, (), (), '0x' + encode(('address',), (address,)).hex())

    def signed(self, host, key, value, kind, domain, maximum, receipt=False, expected=()):
        digest = super().signed(host, key, value, kind, domain, maximum, receipt, expected)
        record = decode((kind, 'bytes', 'bytes') if receipt else (kind, 'bytes'), hex_bytes(value), maximum=maximum)[0]
        time_index = 7 if receipt else 13 if kind == archive.EXTERNAL_FIXITY else 6
        require(0 < record[time_index] <= uint(self.context['timestamp']), 'conservation archive future original timestamp')
        require(record[-1] >= record[time_index], 'conservation archive original signed deadline')
        if not receipt:
            if kind == archive.EXTERNAL_FIXITY:
                require(record[4] == schema_id('STREAM_EXTERNAL_OBJECT_FIXITY_V1'),
                    'conservation archive original fixity profile')
            receipt_data = self.answers.get((host, calldata('receipt(bytes32)', ('bytes32',), (record[0],))))
            receipt_row = decode((archive.RECEIPT,'bytes','bytes'), hex_bytes(receipt_data), maximum=65536)[0] if receipt_data else None
            require(receipt_row is not None and record[time_index] >= receipt_row[7],
                'conservation archive fixity precedes receipt observation')
            report_index, verifier_index = (15,18) if kind == archive.EXTERNAL_FIXITY else (8,11)
            require(record[report_index] != ZERO and record[verifier_index] != receipt_row[6],
                'conservation archive original independent fixity')
        if receipt and record[3] == schema_id('ATTESTED_POSSESSION'):
            external = domain == '6529STREAM_EXTERNAL_RECEIPT_V1'
            require(record[4] == schema_id('STREAM_INSTITUTIONAL_EXTERNAL_OBJECT_POSSESSION_V1' if external
                else '6529STREAM_RAW_CID_SHA256_POSSESSION_V1'), 'conservation archive original possession profile')
            identifier = decode((kind,'bytes','bytes'), hex_bytes(value), maximum=maximum)[1]
            if external:
                from .view_preservation_locator_wire_v1 import locator
                require(locator(identifier.decode('ascii'))[0] == 1, 'conservation archive institutional identifier')
            else:
                require(len(identifier) == 36 and identifier[:4] == b'\x01\x55\x12\x20',
                    'conservation archive institutional raw CID')
            kinds = ('uint256','address','bytes32','bytes32','bytes32')
            values = (self.chain,host,record[0],record[1],record[2])
            if external: kinds += ('bytes32',); values += (record[4],)
            expected = archive._domain('6529STREAM_EXTERNAL_OBJECT_POSSESSION_V1' if external else '6529STREAM_ARCHIVAL_POSSESSION_V1',
                (*kinds,'address','uint64'), (*values,record[6],record[7]))
            require(record[5] == expected, 'conservation archive original possession preimage')
        self.read(host, 'receipt(bytes32)' if receipt else 'fixity(bytes32)', ('bytes32',), (key,), value)
        return digest

    def native(self, value, key, external, host, locator, content, size, digest):
        result = super().native(value, key, external, host, locator, content, size, digest)
        record = decode((archive.EXTERNAL_NATIVE if external else archive.ARCHIVE_NATIVE,),
            hex_bytes(value['record']), maximum=65536)[0]
        require(record[-1] <= uint(self.context['timestamp']), 'conservation archive future checkpoint')
        self.read(value['verifier'], 'checkpointRecord(bytes32)', ('bytes32',), (key,), value['record'])
        return result

    def archive(self, value, artist, content, first, second):
        _closed(value, ('host','runtimeHash','coverage','receipts','fixities','checkpoint','envelope','envelopePointer'),
            'original chunk archive')
        c = archive._v(archive.ARCHIVE_COVERAGE, value['coverage'])
        e,payload = decode((archive.ENVELOPE,'bytes'),hex_bytes(value['envelope']),maximum=16384)
        require(e[2] in (CHUNK_SCHEMA,ESTATE_SCHEMA) and e[3:5] == (BINARY,2) and e[7:] == (1,ZERO),
            'conservation archive original envelope profile')
        if e[2] == CHUNK_SCHEMA:
            pointer = value['envelopePointer']; _closed(pointer, ('address','runtimeHash'), 'envelope pointer')
            require(pointer['runtimeHash'] == keccak256(b'\0'+payload), 'conservation archive envelope STOP bytes')
            self.pin(pointer['address'], pointer['runtimeHash'])
            key = archive._domain('6529STREAM_ARCHIVAL_CHUNK_ENVELOPE_V1',
                ('uint256','address',archive.ENVELOPE,'address','bytes32'),
                (self.chain,value['host'],e,pointer['address'],pointer['runtimeHash']))
            self.read(value['host'],'chunkEnvelopePointer(bytes32)',('bytes32',),(key,),
                '0x'+encode(('address','bytes32'),(pointer['address'],pointer['runtimeHash'])).hex())
        else:
            require(value['envelopePointer'] is None, 'conservation archive unexpected envelope pointer')
            key = archive._domain('6529STREAM_ARCHIVAL_ENVELOPE_V1',('uint256','address',archive.ENVELOPE),
                (self.chain,value['host'],e))
        require(c[1] == key, 'conservation archive original envelope hash')
        institutional = decode((archive.RECEIPT,'bytes','bytes'),hex_bytes(value['receipts'][1]),maximum=16384)[1]
        require(institutional == b'\x01\x55\x12\x20'+hex_bytes(e[5],32),
            'conservation archive institutional chunk digest')
        self.address_read(value['host'], 'core()', self.context['core'])
        self.read(value['host'], 'profileHash()', (), (),
            '0x' + encode(('bytes32',), (archive.ARCHIVE_PROFILE,)).hex())
        self.read(value['host'], 'coverage(bytes32)', ('bytes32',), (c[0],),
            '0x' + encode((archive.ARCHIVE_COVERAGE,), (c,)).hex())
        self.read(value['host'], 'envelope(bytes32)', ('bytes32',), (c[1],), value['envelope'])
        return super().archive({k:v for k,v in value.items() if k != 'envelopePointer'}, artist, content, first, second)


def _reference_context(dossier, occurrence):
    """Original historical Artist and exact declared format, never today's signer."""
    parts = occurrence['jsonPointer'].split('/')[1:]
    node = dossier
    ancestors = []
    for part in parts:
        ancestors.append(node)
        node = node[int(part)] if isinstance(node, list) else node[part.replace('~1', '/').replace('~0', '~')]
    require(node == {'hash': occurrence['hash'], 'uri': occurrence['uri']}, 'conservation archive reference pointer')
    form = ancestors[-1].get('format') if parts[-1] == 'content' and isinstance(ancestors[-1], dict) else None
    original = None
    if occurrence['sourceKind'] == 'record':
        original = dossier['records'][int(parts[1])]
        artists = [original['provenance']['association'][0]]
    else:
        catalog = occurrence['catalogSelector']
        artists = list(dict.fromkeys(record['provenance']['association'][0] for record in dossier['records']
            if any(c['documentId'] == catalog['documentId'] and c['documentHash'] == catalog['documentHash']
                for c in record['catalogOccurrences'])))
    require(artists and all(a != ZERO for a in artists), 'conservation archive original Artist association missing')
    return artists, form, original


def _canonical(raw, canonicalization):
    if canonicalization == archive.RAW: return True
    if canonicalization != archive.JCS: return False
    def pairs(values):
        result = {}
        for key, value in values:
            require(key not in result, 'conservation archive duplicate JCS property')
            result[key] = value
        return result
    value = json.loads(raw.decode('utf-8'), object_pairs_hook=pairs,
        parse_constant=lambda _: (_ for _ in ()).throw(MuseumError('conservation archive invalid JCS constant')))
    require(rfc8785.dumps(value) == raw, 'conservation archive bytes are not exact JCS')
    return True


def _external(proof, raw, canon, artists, form, original, originals, graph):
    evidence = proof['sourceEvidence']
    _closed(evidence, ('object', 'receipts', 'fixities', 'checkpoint'), 'external originals')
    host = graph['externalCoverage']['address']; pin = graph['externalCoverage']['runtimeHash']
    obj = archive._v(archive.OBJECT, evidence['object'])
    c = archive._v(archive.t.ADMISSION[3], proof['coverage'])
    require(all(obj[i] != ZERO for i in (*range(6),7,8,9)) and obj[0] in artists
        and obj[2] == canon and obj[3:5] == (keccak256(raw), _sha(raw))
        and obj[6] == len(raw) > 0, 'conservation archive external material correspondence')
    if form is not None:
        catalog = form.get('catalog')
        require(obj[7] == form['formatId'] and (catalog is None or obj[8:10] ==
            (catalog['documentId'], catalog['documentHash'])),
            'conservation archive exact declared format/catalog')
    if original is not None:
        require(obj[1] == original['semantic']['interview']['record']['schemaId'],
            'conservation archive original interview schema')
    require(c[0] != ZERO and c[1] == archive.external_object_hash(obj, originals.chain, host, originals.context['core'])
        and c[2:7] == (obj[0], *obj[3:7]) and all(c[i] != ZERO for i in range(7,14))
        and c[7] != c[8] and c[14] == archive.EXTERNAL_PROFILE
        and c[0] == archive.external_coverage_hash(c, originals.chain, host),
        'conservation archive original external coverage')
    require(proof['partsHash'] == ZERO and len(evidence['receipts']) == len(evidence['fixities']) == 2,
        'conservation archive exact external pair')
    originals.address_read(host, 'core()', originals.context['core'])
    originals.read(host, 'profileHash()', (), (), '0x' + encode(('bytes32',), (archive.EXTERNAL_PROFILE,)).hex())
    originals.read(host, 'objectIdentity(bytes32)', ('bytes32',), (c[1],), '0x' + encode((archive.OBJECT,), (obj,)).hex())
    originals.read(host, 'coverage(bytes32)', ('bytes32',), (c[0],), '0x' + encode((archive.t.ADMISSION[3],), (c,)).hex())
    hashes = [originals.signed(host, c[9+i], body, archive.RECEIPT, '6529STREAM_EXTERNAL_RECEIPT_V1', 65536, True,
        ((0,c[1]), (1,c[7+i]), (3,schema_id('CONTENT_ADDRESSED_INCLUSION' if i == 0 else 'ATTESTED_POSSESSION')))
        + (((5,c[13]),) if i == 0 else ())) for i, body in enumerate(evidence['receipts'])]
    hashes += [originals.signed(host, c[11+i], body, archive.EXTERNAL_FIXITY, '6529STREAM_EXTERNAL_FIXITY_V1', 65536,
        expected=((0,c[9+i]), (1,c[1]), (2,c[7+i]),
            (3,decode((archive.RECEIPT,'bytes','bytes'), hex_bytes(evidence['receipts'][i]), maximum=65536)[0][2]),
            (5,obj[4]), (6,obj[4]), (7,obj[3]), (8,obj[3]), (9,obj[5]), (10,obj[5]),
            (11,obj[6]), (12,obj[6]), (14,1))) for i, body in enumerate(evidence['fixities'])]
    locator = decode((archive.RECEIPT, 'bytes', 'bytes'), hex_bytes(evidence['receipts'][0]), maximum=65536)[1]
    hashes.append(originals.native(evidence['checkpoint'], c[13], True, host, locator, obj[3], obj[6], obj[5]))
    expected = archive._hash(('address','bytes32',archive.t.ADMISSION[3],('bytes32',)*5), (host,pin,c,tuple(hashes)))
    require(proof['originalBundleHash'] == expected, 'conservation archive external original bundle')
    return {'backend': 'external', 'objectHash': c[1], 'coverageHash': c[0], 'artistId': obj[0],
        'families': list(c[7:9]), 'originalBundleHash': expected, 'partsHash': ZERO,
        'transactionId': '0x' + locator.hex()}


def _onchain(proof, raw, canon, artists, originals, graph, original=None):
    evidence = proof['sourceEvidence']
    _closed(evidence, ('artifact', 'chunks','planHash','plan'), 'onchain originals')
    host = graph['coverage']['address']; pin = graph['coverage']['runtimeHash']
    a = archive._v(archive.ARTIFACT, evidence['artifact']); c = archive._v(archive.t.ADMISSION[4], proof['coverage'])
    require(c[0] != ZERO and a[0] in artists and a[1] != ZERO and c[10] > 0 and c[11] != ZERO
        and c[:7] == (c[0], archive.artifact_hash(a, originals.chain, host,
        originals.context['core']), a[0], a[1], canon, keccak256(raw), len(raw))
        and a[2:6] == (canon, 1, keccak256(raw), len(raw)) and 0 < c[7] <= 64
        and c[8] != ZERO and c[9] != ZERO and c[8] != c[9]
        and len(a[6]) == len(a[7]) == c[7] == len(evidence['chunks'])
        and len(encode((archive.ARTIFACT,), (a,))) <= 8192, 'conservation archive original artifact correspondence')
    if original is not None:
        require(a[1] == original['semantic']['interview']['record']['schemaId'],
            'conservation archive original interview artifact schema')
    plan = archive._v(PLAN,evidence['plan']); plan_hash = evidence['planHash']
    require(plan[3] != ZERO and plan == (c[1],c[8],c[9],plan[3],c[10],c[7],c[11],c[0])
        and plan_hash == archive._domain('6529STREAM_FINALITY_ARTIFACT_COVERAGE_PLAN_V1',
            ('uint256','address','bytes32','bytes32','bytes32','bytes32','uint64'),
            (originals.chain,host,c[1],c[8],c[9],plan[3],c[10])), 'conservation archive original coverage plan')
    originals.address_read(host, 'core()', originals.context['core'])
    originals.read(host, 'artifact(bytes32)', ('bytes32',), (c[1],), '0x' + encode((archive.ARTIFACT,), (a,)).hex())
    originals.read(host, 'coverage(bytes32)', ('bytes32',), (c[0],),
        '0x' + encode((archive.t.ADMISSION[4],), (c,)).hex())
    originals.read(host,'coveragePlan(bytes32)',('bytes32',),(plan_hash,), '0x'+encode((PLAN,),(plan,)).hex())
    evidence_chain = archive._domain('6529STREAM_FINALITY_ARTIFACT_COVERAGE_CHAIN_V1',('bytes32',),(plan_hash,))
    parts = bundles = ZERO; material = []
    for index, chunk in enumerate(evidence['chunks']):
        _closed(chunk, ('pointer', 'runtime', 'archive'), 'artifact chunk')
        runtime = originals.raw(chunk['runtime'], 8193)
        require(runtime[:1] == b'\0' and len(runtime) == a[7][index]+1 and 0 < a[7][index] <= 8192
            and (index+1 == c[7] or a[7][index] == 8192) and keccak256(runtime[1:]) == a[6][index],
            'conservation archive original STOP chunk')
        digest = keccak256(runtime); originals.pin(chunk['pointer'], digest); material.append(runtime[1:])
        originals.read(host, 'artifactChunk(bytes32,uint32)', ('bytes32','uint32'), (c[1],index),
            '0x' + encode(('address','bytes32'), (chunk['pointer'],digest)).hex())
        originals.address_read(host, 'archivalCoverage()', chunk['archive']['host'])
        envelope = decode((archive.ENVELOPE,'bytes'),hex_bytes(chunk['archive']['envelope']),maximum=16384)[0]
        require(envelope[2] == CHUNK_SCHEMA and chunk['archive']['envelopePointer'] ==
            {'address':chunk['pointer'],'runtimeHash':digest}, 'conservation archive exact original artifact chunk envelope')
        original = originals.archive(chunk['archive'], a[0], a[6][index], c[8], c[9])
        ac = archive._v(archive.ARCHIVE_COVERAGE,chunk['archive']['coverage'])
        originals.read(host,'originalArtifactChunkCoverage(bytes32,uint32)',('bytes32','uint32'),(c[0],index),
            '0x'+encode(('bytes32',),(ac[0],)).hex())
        evidence_chain = archive._domain('6529STREAM_FINALITY_ARTIFACT_COVERED_PART_V1',
            ('bytes32','bytes32','uint32','bytes32','uint32','address','bytes32',archive.ARCHIVE_COVERAGE),
            (evidence_chain,plan_hash,index,a[6][index],a[7][index],chunk['pointer'],digest,ac))
        parts = archive._hash(('bytes32','uint32','address','bytes32','bytes32','uint32'),
            (parts,index,chunk['pointer'],digest,a[6][index],a[7][index]))
        bundles = archive._hash(('bytes32','uint32','bytes32'), (bundles,index,original))
    require(b''.join(material) == raw and proof['partsHash'] == parts, 'conservation archive complete artifact bytes/parts')
    require(evidence_chain == c[11] and c[0] == archive._domain('6529STREAM_FINALITY_ARTIFACT_COVERAGE_COMPLETE_V1',
        ('bytes32','bytes32','uint64','bytes32','uint32'),(plan_hash,c[1],c[10],evidence_chain,c[7])),
        'conservation archive original completion preimage')
    expected = archive._hash(('address','bytes32',archive.t.ADMISSION[4],archive.ARTIFACT,'bytes32','bytes32'),
        (host,pin,c,a,parts,bundles))
    require(proof['originalBundleHash'] == expected, 'conservation archive original artifact bundle')
    return {'backend': 'onchain', 'objectHash': c[1], 'coverageHash': c[0], 'artistId': a[0],
        'families': list(c[8:10]), 'originalBundleHash': expected, 'partsHash': parts}


def _hashref(raw, reference, canonical, archived):
    algorithm = reference['algorithm']; digest = hex_bytes(reference['digest'])
    if algorithm in (1,2,3):
        if canonical:
            expected = keccak256(raw) if algorithm == 1 else _sha(raw) if algorithm == 2 else '0x'+blake3(raw).hexdigest()
            require(reference['digest'] == expected,
                'conservation archive original reference digest differs')
        return canonical, [], 'content_digest'
    if algorithm == 4:
        if len(digest) != 34 or digest[:2] != b'\x12\x20': return False, ['unsupported_multihash_encoding'], None
        require(digest[2:] == hashlib.sha256(raw).digest(), 'conservation archive multihash digest differs')
        return canonical, [], 'sha2_256_multihash'
    if algorithm == 5:
        from .iiif_uri import content_uri_facts
        if len(digest) == 36 and digest[:4] == b'\x01\x55\x12\x20':
            cid = 'b' + base64.b32encode(digest).decode('ascii').lower().rstrip('=')
        elif len(digest) == 59 and digest[:1] == b'b' and all(c in b'abcdefghijklmnopqrstuvwxyz234567' for c in digest[1:]):
            cid = digest.decode('ascii')
            decoded = base64.b32decode(cid[1:].upper() + '======')
            if decoded[:4] != b'\x01\x55\x12\x20': return False, ['unsupported_cid_codec'], None
        else: return False, ['unsupported_cid_encoding'], None
        content_uri_facts('ipfs://' + cid, hashlib.sha256(raw).hexdigest())
        return canonical, [], 'cid_v1_raw_sha2_256'
    if algorithm == 6:
        if archived is None or archived['backend'] != 'external':
            return False, ['original_external_transaction_identity_required'], None
        require(reference['digest'] == archived['transactionId'], 'conservation archive original transaction identity differs')
        return canonical, [], 'original_arweave_transaction_identity'
    return False, ['unsupported_hash_algorithm_' + str(algorithm)], None


def _verify(files, envelope_raw, expected_hash, material_files):
    snapshot, dossier, references, transcript = _load(files)
    empty = loads(template(files), maximum=MAX_BYTES, canonical=True)
    if envelope_raw is None:
        require(expected_hash is None and not material_files, 'conservation archive missing pinned materials envelope')
        value = empty
    else:
        require(type(envelope_raw) is bytes and 0 < len(envelope_raw) <= MAX_BYTES
            and any(hex_bytes(expected_hash,32)) and keccak256(envelope_raw) == expected_hash,
            'conservation archive external materials pin/bound')
        value = loads(envelope_raw, maximum=MAX_BYTES, canonical=True)
    _closed(value, empty, 'materials envelope')
    require(all(value[k] == empty[k] for k in ('profileHash','dossierHash','referenceInventoryHash','context')),
        'conservation archive source/profile pins')
    require(type(value['graph']) is dict and set(value['graph']) <= {'coverage','externalCoverage'},
        'conservation archive actual archive graph')
    for row in value['graph'].values(): _closed(row, ('address','runtimeHash'), 'graph pin')
    rows = value['occurrences']
    require(type(rows) is list and len(rows) == len(references) <= MAX_OCCURRENCES,
        'conservation archive all reference occurrences required')
    material_files = {} if material_files is None else dict(material_files)
    _paths(material_files)
    require(all(type(raw) is bytes and len(raw) <= MAX_MATERIAL for raw in material_files.values())
        and sum(map(len, material_files.values())) <= MAX_BYTES, 'conservation archive material byte bound')
    originals = _Originals(snapshot, transcript, value['graph'])
    used = set(); output = []
    for index, (row, occurrence) in enumerate(zip(rows, references)):
        _closed(row, ('occurrence','materialPath','archive'), 'material occurrence')
        require(type(row['occurrence']) is int and row['occurrence'] == index == occurrence['occurrence'],
            'conservation archive occurrence order/identity')
        artists, form, original = _reference_context(dossier, occurrence)
        reasons = []; raw = None; archived = None; checked = False
        algorithm, canon = occurrence['hash']['algorithm'], occurrence['hash']['canonicalizationId']
        if canon not in (archive.RAW,archive.JCS): reasons.append('unsupported_canonicalization')
        if row['materialPath'] is None:
            reasons.append('material_not_supplied')
            require(row['archive'] is None, 'conservation archive proof requires complete material')
        else:
            path = row['materialPath']; require(type(path) is str and path in material_files, 'conservation archive material missing')
            used.add(path); raw = material_files[path]
            canonical = _canonical(raw, canon)
            if occurrence['relation'] == 'interview_payload':
                child_hash = original['semantic']['interview']['record']['recordHash']
                child = next(r for r in dossier['records'] if r['selector']['recordHash'] == child_hash)
                require(raw == hex_bytes(child['provenance']['payloadHex']), 'conservation archive original interview payload bytes')
            if row['archive'] is not None:
                proof = row['archive']
                _closed(proof, ('backend','coverage','sourceEvidence','originalBundleHash','partsHash'), 'proof')
                require(proof['backend'] in ('external','onchain'), 'conservation archive unsupported backend')
                archived = (_external(proof,raw,canon,artists,form,
                    original if occurrence['relation'] == 'interview_payload' else None,originals,value['graph'])
                    if proof['backend'] == 'external' else _onchain(proof,raw,canon,artists,originals,value['graph'],
                        original if occurrence['relation'] == 'interview_payload' else None))
            checked, unsupported, binding_kind = _hashref(raw, occurrence['hash'], canonical, archived)
            reasons.extend(unsupported)
        if archived is None: reasons.append('original_dual_family_archive_not_supplied')
        output.append({'occurrence': deepcopy(occurrence), 'originalArtistIds': artists, 'declaredFormat': deepcopy(form),
            'materialPath': row['materialPath'], 'material': None if raw is None else
                {'byteLength': str(len(raw)), 'keccak256': keccak256(raw), 'sha256': _sha(raw)},
            'originalHashRefChecked': checked, 'archive': archived, 'status': 'complete' if not reasons else 'unresolved',
            'referenceCorrespondenceKind': None if raw is None else binding_kind,
            'reasons': reasons})
    require(used == set(material_files), 'conservation archive undeclared material files')
    bindings = value['sourceBindings']; _closed(bindings, ('blockHash','provenance','calls'), 'source bindings')
    require(bindings == {**empty['sourceBindings'], 'calls': originals.calls}, 'conservation archive exact original source bindings')
    unresolved = [str(index) for index,r in enumerate(output) if r['status'] != 'complete']
    report = {'profileHash': PROFILE_HASH, 'sourceRevision': SOURCE_REVISION,
        'dossierHash': value['dossierHash'], 'referenceInventoryHash': value['referenceInventoryHash'],
        'materialsHash': expected_hash, 'sourceProvenance': bindings['provenance'],
        'occurrenceCount': str(len(output)), 'completeCount': str(len(output)-len(unresolved)),
        'unresolvedOccurrences': unresolved, 'complete': bool(output) and not unresolved,
        'claims': CLAIMS, 'qualification': QUALIFICATION}
    return dict(zip(OUTPUTS, (PROFILE_BYTES, dumps({'occurrences': output}), dumps(report))))


def verify(projected_files, materials_envelope_bytes=None, materials_hash=None, material_files=None):
    """Check all occurrences after the parent has replayed the original dossier."""
    try: return _verify(projected_files, materials_envelope_bytes, materials_hash, material_files)
    except MuseumError: raise
    except (KeyError,ValueError,TypeError,IndexError,OverflowError,UnicodeError,RecursionError) as exc:
        raise MuseumError('malformed conservation archival correspondence') from exc


def require_complete(output_files):
    report = loads(output_files[OUTPUTS[2]], maximum=MAX_BYTES, canonical=True)
    require(report['profileHash'] == PROFILE_HASH and report['complete'] is True
        and report['occurrenceCount'] != '0' and report['unresolvedOccurrences'] == [],
        'conservation archive unresolved original reference occurrences')
    return report
