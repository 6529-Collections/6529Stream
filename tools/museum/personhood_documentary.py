"""Exact immutable native personhood documentary proof, separate from current selection."""
from tools.metadata import identity_notarization_profile as notarization

from . import general_attestation_source as general
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, subject_id, uint
from .chain_abi import decode, encode
from .independent_wire import RAW_BYTES, ZERO, ZERO_ADDRESS, json_values, require

SOURCE_REVISION = "68498f8d8fc95d9a96324426bf7c1e50976b8405"
EVIDENCE_SCHEMA = schema_id("6529STREAM_ARTIST_PERSONHOOD_EVIDENCE_V1")
WAIVER_SCHEMA = schema_id("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")
PROFILE_ID = schema_id("STREAM_ARTIST_PERSONHOOD_REFERENCE_JSON_PROFILE_V1")
PROFILE_HASH = "0x06eaf449a0abe6a4305706d589bc597f14f7d23f62acc661b4b1fff128b921c3"
PROFILE_BYTES = b'{"authority":"Only the original native Artist op24 signature and schema-specific personhood head select this reference. The General receipt proves its recorded signer\'s authorization, not legal personhood, institutional standing or truth.","canonicalization":"RFC8785_JCS","fields":{"artistId":"Nonzero lowercase 0x-prefixed 32-byte stable Artist identity.","artistRegistry":"Nonzero lowercase 0x-prefixed 20-byte original native Artist signing-domain registry.","notarizationHost":"Nonzero lowercase 0x-prefixed 20-byte General notarization host.","notarizationRecordHash":"Nonzero lowercase 0x-prefixed 32-byte original General receipt hash.","notarizationRuntimeHash":"Nonzero lowercase 0x-prefixed 32-byte exact registered General host runtime hash.","operativeIdentityRecordHash":"Nonzero lowercase 0x-prefixed 32-byte identity document attested by both original records.","profileHash":"Keccak-256 of these exact profile bytes, lowercase 0x-prefixed 32 bytes.","version":1},"history":"Original records, statements, signer domains and signature bundles remain immutable. A newer recorder-scoped General head is disclosed separately and never replaces the artist-selected reference. Credential-only C2PA records do not replace the personhood head.","name":"STREAM_ARTIST_PERSONHOOD_REFERENCE_JSON_PROFILE_V1","representation":"Exactly these eight fields in lexicographic order, no whitespace, no additional fields, lowercase fixed-width hexadecimal strings and the JSON integer 1; exactly 590 UTF-8 bytes.","semanticSchema":"6529STREAM_ARTIST_PERSONHOOD_EVIDENCE_V1","status":"Additive explicit interpretation; this profile does not replace any previously registered native evidence or waiver schema definition. Opaque legacy evidence is historical and unresolved; established signed waiver semantics remain unchanged.","version":1}\n'
SUMMARY_TAG = schema_id("6529STREAM_ARTIST_PERSONHOOD_PROOF_SUMMARY_V1")
DOCUMENTARY_TAG = schema_id("6529STREAM_ARTIST_PERSONHOOD_DOCUMENTARY_PROOF_V1")
GENERAL_INTERFACE = "0xb4afac56"
GENERAL_VERSION = schema_id("6529stream.general-attestations.v2")
GENERAL_TYPE = schema_id("GENERAL_ATTESTATIONS")
ATTESTATION_RECORD = general.ARTIST_RECORD
REFERENCE = ("uint16", "bytes32", "address", "bytes32", "bytes32", "address", "bytes32", "bytes32")
REFERENCE_FIELDS = ("version", "profileHash", "artistRegistry", "artistId", "operativeIdentityRecordHash",
    "notarizationHost", "notarizationRuntimeHash", "notarizationRecordHash")
SUMMARY = ("uint16", "uint256", "bytes32", "bytes32", "bytes32", "bytes32", "uint64", "uint256", "bytes32",
    REFERENCE, "bytes32", "address", "bytes32", "address", "bytes32", "address", "bytes32", "address", "bytes32",
    ("bytes32",) * 4, "uint256", "bytes32", "bytes32", "address", "bytes32", "bytes32", ("address",) * 6, ("bytes32",) * 6)
SUMMARY_FIELDS = ("version", "chainId", "nativeRecordHash", "statementHash", "artistId", "bindingHash", "generation",
    "collectionId", "identityRecordHash", "evidenceReference", "originalRegistryCodeHash", "core", "coreCodeHash",
    "moduleRegistry", "moduleRegistryCodeHash", "schemaRegistry", "schemaRegistryCodeHash", "chunkStore",
    "chunkStoreCodeHash", "definitionFactsHashes", "notarizationCollectionId", "attestationType", "subjectId",
    "recorder", "documentaryHash", "moduleIdentityHash", "carriers", "carrierCodeHashes")
SELECTION = (ATTESTATION_RECORD, "address", REFERENCE, "bytes32", "address", "bytes32", "bool", "bool", "uint8")
SELECTION_FIELDS = ("nativeRecord", "sourceRegistry", "evidenceReference", "notarizationType", "recorder",
    "notarizationHead", "identityCurrent", "notarizationCurrent", "status")
FACTS = ("bytes32", "address", "bytes32", "bool")
STATUSES = ("NONE", "WAIVER", "RESOLVED", "STALE", "UNRESOLVED")
POINTER = ("address", "bytes32", "bool", "bytes32", "bytes4", "address", "uint8", "bytes32", "bytes32", "uint64")
MODULE = ("uint8", "bytes32", "bytes32", "bytes4", "uint32", "bytes32", "bytes32", "bytes32", "string",
    "uint64", "uint64", "uint64")
DOCUMENT_FACTS = ("bool", "uint8", "uint8", "bytes32", "bytes32", "bytes32", "uint32", "uint256", "bytes32")
MAX_PAYLOAD, MAX_SIGNATURE, MAX_BUNDLE = 8192, 4096, 8192


def definitions():
    """Exact native four-definition order; status is not an immutable fact hash field."""
    rows = ((general.SCHEMA_ID, 0, notarization.SCHEMA_HASH, notarization.SCHEMA_BYTES),
        (general.PROFILE_ID, 2, notarization.PROFILE_HASH, notarization.PROFILE_BYTES),
        (general.JCS_ID, 1, "0xbc33af15c6b6374052871a5fdfa255f900f56fa594f650b2d0814c681fdb35a9", general.JCS_BYTES),
        (PROFILE_ID, 2, PROFILE_HASH, PROFILE_BYTES))
    for (_, _, digest, raw), size in zip(rows, (4236, 1488, 362, 1837), strict=True):
        require(len(raw) == size and keccak256(raw) == digest, "personhood local definition bytes differ")
    return rows


def reference_bytes(reference):
    encode((REFERENCE,), (reference,))
    require(reference[0] == 1 and reference[1] == PROFILE_HASH and
        all(any(hex_bytes(reference[index], 20 if index in (2, 5) else 32)) for index in range(2, 8)),
        "personhood canonical reference differs")
    result = dumps(dict(zip(REFERENCE_FIELDS, json_values(reference))))
    # The native representation uses a JSON integer, unlike general notarization's string version.
    value = loads(result); value["version"] = 1; result = dumps(value)
    require(len(result) == 590, "personhood reference byte length differs")
    return result


def decode_reference(raw):
    require(type(raw) is bytes and len(raw) == 590, "personhood reference byte length differs")
    value = loads(raw, maximum=590, canonical=True)
    require(type(value) is dict and set(value) == set(REFERENCE_FIELDS) and type(value["version"]) is int,
        "personhood reference shape differs")
    result = tuple(value[key] for key in REFERENCE_FIELDS)
    require(reference_bytes(result) == raw, "personhood reference canonical bytes differ")
    return result


def summary_hash(summary):
    return keccak256(encode(("bytes32", SUMMARY), (SUMMARY_TAG, summary)))


def module_identity(module):
    return keccak256(encode(("bytes32", "bytes32", "bytes4", "bytes32", "bytes32", "bytes32", "bytes32", "uint64"),
        (module[1], module[2], module[3], module[5], module[6], module[7],
            keccak256(module[8].encode("utf-8")), module[9])))


def definition_facts_hash(facts):
    return keccak256(encode(("bool", "uint8", "bytes32", "bytes32", "bytes32", "uint32", "uint256", "bytes32"),
        (facts[0], facts[1], *facts[3:])))


def _code(ctx, address, expected):
    require(address != ZERO_ADDRESS and expected != ZERO, "personhood original runtime pin missing")
    raw = ctx.code(address, expected)
    require(type(raw) is bytes and 0 < len(raw) <= 24576 and keccak256(raw) == expected,
        "personhood original runtime differs")
    return raw


def _definitions(ctx, schemas, store):
    result, pointers, code_hashes, fact_hashes = [], [], [], []
    for identifier, kind, digest, expected in definitions():
        facts = ctx.one(schemas, "documentFacts(bytes32)", DOCUMENT_FACTS, ("bytes32",), (identifier,))
        encode((DOCUMENT_FACTS,), (facts,))
        require(facts[0] and facts[1] == kind and facts[2] <= 2 and facts[3] == digest
            and facts[4] == RAW_BYTES and facts[5] == ZERO and facts[6] == len(expected)
            and facts[7] == 1 and facts[8] != ZERO, "personhood definition facts differ")
        chunk_hash = ctx.one(schemas, "documentChunkHashAt(bytes32,uint256)", "bytes32",
            ("bytes32", "uint256"), (identifier, 0))
        pointer, length = ctx.read(store, "chunk(bytes32)", ("address", "uint32"), ("bytes32",), (chunk_hash,))
        raw = ctx.one(store, "readChunk(bytes32)", "bytes", ("bytes32",), (chunk_hash,))
        require(chunk_hash == digest and length == len(expected) and raw == expected,
            "personhood original definition bytes differ")
        code_hash = keccak256(b"\x00" + raw)
        require(_code(ctx, pointer, code_hash) == b"\x00" + raw, "personhood definition carrier differs")
        fact_hash = definition_facts_hash(facts)
        pointers.append(pointer); code_hashes.append(code_hash); fact_hashes.append(fact_hash)
        result.append({"documentId": identifier, "facts": json_values(facts), "factsHash": fact_hash,
            "payloadHex": "0x" + raw.hex(), "pointer": pointer, "carrierCodeHash": code_hash})
    return result, tuple(pointers), tuple(code_hashes), tuple(fact_hashes)


def verify_documentary(ctx, summary):
    """Verify the full original General documentary half; caller joins original op24 identity.

    Requires exact original runtimes and carriers to remain available. An incident-revoked
    or unknown module with retained immutable identity is disclosed as not current. No old
    signature is reauthorized and no current replacement record is substituted.
    """
    try:
        return _verify_documentary(ctx, summary)
    except MuseumError:
        raise
    except (KeyError, TypeError, IndexError, ValueError, OverflowError) as exc:
        raise MuseumError("malformed personhood documentary evidence") from exc


def _verify_documentary(ctx, s):
    encoded_summary = encode((SUMMARY,), (s,))
    require(len(encoded_summary) == 1536 and s[0] == 1 and s[1] == uint(ctx.a["chainId"])
        and s[11] == ctx.a["core"] and s[24] != ZERO, "personhood summary documentary context differs")
    p = s[9]; reference_bytes(p)
    host, record_hash = p[5], p[7]
    for address, digest in ((p[2], s[10]), (host, p[6]), (s[11], s[12]), (s[13], s[14]),
            (s[15], s[16]), (s[17], s[18])):
        _code(ctx, address, digest)
    pointer = ctx.read(s[11], "getSatellitePointer(bytes32)", POINTER, ("bytes32",), (schema_id("MODULE_REGISTRY"),))
    require(pointer[:2] == (s[13], s[14]), "personhood original module registry pointer differs")
    module = ctx.one(s[13], "moduleRecord(address)", MODULE, ("address",), (host,))
    encode((MODULE,), (module,))
    require(len(encode((MODULE,), (module,))) <= 8192 and module[0] <= 3
        and module[1:4] == (GENERAL_TYPE, GENERAL_VERSION, GENERAL_INTERFACE) and module[5] == p[6]
        and module_identity(module) == s[25], "personhood original module identity differs")
    for signature, output, expected in (("core()", "address", s[11]), ("coreCodeHash()", "bytes32", s[12]),
            ("artistRegistry()", "address", p[2]), ("schemaRegistry()", "address", s[15]),
            ("schemaRegistryCodeHash()", "bytes32", s[16]), ("chunkStore()", "address", s[17]),
            ("chunkStoreCodeHash()", "bytes32", s[18]), ("streamModuleType()", "bytes32", GENERAL_TYPE),
            ("streamModuleVersion()", "bytes32", GENERAL_VERSION)):
        require(ctx.one(host, signature, output) == expected, "personhood General dependency getter differs")
    require(ctx.one(s[15], "chunkStore()", "address") == s[17], "personhood schema Store differs")
    a, r = ctx.read(host, "attestation(bytes32)", (general.ATTESTATION, general.RECEIPT), ("bytes32",), (record_hash,))
    original = encode((general.ATTESTATION, general.RECEIPT), (a, r))
    require(len(original) <= 12288 and a[3] in (general.INSTITUTIONAL, general.ESTATE)
        and a[0] != ZERO_ADDRESS and r[0] == a[0] and r[1:3] == (1, 1)
        and a[5:7] == (general.SCHEMA_ID, general.JCS_ID)
        and r[11:14] == (notarization.SCHEMA_HASH, general.JCS_HASH, notarization.PROFILE_HASH)
        and r[18:22] == (p[2], s[10], p[3], p[4]) and 0 < r[3] <= uint(ctx.a["timestamp"])
        and r[6] != ZERO and r[10] != ZERO and a[2] != ZERO and a[8] != ZERO and a[10] == ZERO
        and r[14:18] == (ZERO, 0, 0, 0) and r[22:24] == (ZERO, 0), "personhood original signed General receipt differs")
    require(general.native_record_hash(s[1], host, a, r) == record_hash,
        "personhood original General record hash differs")
    require(ctx.one(host, "recordHashAt(uint256,bytes32,uint256)", "bytes32", ("uint256", "bytes32", "uint256"),
        (a[1], a[3], r[4])) == record_hash, "personhood original General history slot differs")
    subject = ctx.one(host, "recordSubject(bytes32)", general.SUBJECT, ("bytes32",), (record_hash,))
    encode((general.SUBJECT,), (subject,))
    require(subject[1] == a[1] and subject[0] <= 2, "personhood original subject scope differs")
    kind, cid, token, object_id = subject
    require((kind == 0 and token == 0 and object_id == ZERO) or
        (kind == 1 and cid > 0 and token > 0 and object_id == ZERO) or
        (kind == 2 and cid > 0 and token == 0 and object_id != ZERO), "personhood original subject shape differs")
    expected_subject = subject_id(("collection", "token", "media")[kind], str(s[1]), s[11], str(cid),
        token_id=str(token), object_id=object_id)
    require(expected_subject == a[2], "personhood original subject preimage differs")
    subject_hash = keccak256(encode((general.SUBJECT,), (subject,)))
    payload_pointer, payload = ctx.read(host, "recordPayload(bytes32)", ("address", "bytes"), ("bytes32",), (record_hash,))
    bundle_pointer, bundle = ctx.read(host, "recordSignatureBundle(bytes32)", ("address", "bytes"), ("bytes32",), (record_hash,))
    require(type(payload) is bytes and 0 < len(payload) <= MAX_PAYLOAD and keccak256(payload) == a[8]
        and type(bundle) is bytes and 0 < len(bundle) <= MAX_BUNDLE and keccak256(bundle) == r[10],
        "personhood original payload/signature bundle differs")
    interpretation = notarization.validate(payload, artist_id=p[3], operative_identity_record_hash=p[4])
    domain, words, signature = decode(("bytes32", ("bytes32",) * 15, "bytes"), bundle, maximum=MAX_BUNDLE)
    require(0 < len(signature) <= MAX_SIGNATURE and r[9] in (general.EIP712, general.ERC1271)
        and domain == general.domain(s[1], host) and encode(("bytes32",) * 15, words) == general.signed_words(a, payload, r)
        and keccak256(b"\x19\x01" + hex_bytes(domain) + hex_bytes(keccak256(encode(("bytes32",) * 15, words)))) == r[6],
        "personhood original signature preimage differs")
    carriers, carrier_hashes = [payload_pointer, bundle_pointer], []
    for carrier, content in ((payload_pointer, payload), (bundle_pointer, bundle)):
        digest = keccak256(b"\x00" + content)
        require(_code(ctx, carrier, digest) == b"\x00" + content, "personhood report carrier differs")
        carrier_hashes.append(digest)
    documents, definition_carriers, definition_code_hashes, facts_hashes = _definitions(ctx, s[15], s[17])
    carriers.extend(definition_carriers); carrier_hashes.extend(definition_code_hashes)
    require(tuple(carriers) == s[26] and tuple(carrier_hashes) == s[27] and facts_hashes == s[19],
        "personhood summary original carriers/definitions differ")
    require((a[1], a[3], a[2], r[0]) == s[20:24], "personhood summary original General fields differ")
    carriers_hash = keccak256(encode(("bytes", "bytes"), (payload, bundle)))
    documentary_hash = keccak256(encode(("bytes32", "uint256", "address", REFERENCE, general.ATTESTATION,
        general.RECEIPT, "bytes32", "bytes32", "address", "bytes32", "address", "bytes32", ("bytes32",) * 4),
        (DOCUMENTARY_TAG, s[1], s[11], p, a, r, subject_hash, carriers_hash, s[15], s[16], s[17], s[18], facts_hashes)))
    require(documentary_hash == s[24], "personhood immutable documentary hash differs")
    eligible = module[0] in (1, 2) and module[11] != 0
    head = ctx.one(host, "latestAttestationHashFor(uint256,bytes32,bytes32,address)", "bytes32",
        ("uint256", "bytes32", "bytes32", "address"), (a[1], a[3], a[2], r[0])) if eligible else ZERO
    facts = (a[3], r[0], head, eligible and head == record_hash)
    return {"facts": json_values(facts), "recordHash": record_hash, "attestation": json_values(a),
        "receipt": json_values(r), "attestationRawHex": "0x" + original.hex(), "subject": json_values(subject),
        "subjectHash": subject_hash, "payloadHex": "0x" + payload.hex(), "payloadValue": interpretation,
        "signatureBundleHex": "0x" + bundle.hex(), "signatureHex": "0x" + signature.hex(),
        "signatureDomain": domain, "signatureWords": json_values(words), "definitions": documents,
        "carriers": [{"address": address, "runtimeHash": digest} for address, digest in zip(carriers, carrier_hashes, strict=True)],
        "carriersHash": carriers_hash, "module": json_values(module), "moduleIdentityHash": module_identity(module),
        "moduleCurrentlyEligible": eligible, "moduleRegistryPointer": json_values(pointer),
        "documentaryHash": documentary_hash, "summaryHash": summary_hash(s),
        "summaryRawHex": "0x" + encoded_summary.hex(), "runtimeCodeMatch": True,
        "generalLaneHistoryComplete": False, "signatureCurrentlyRevalidated": False,
        "qualification": "Exact original documentary bytes and summary fields are joined; unavailable original artifacts fail closed. Recorder-scoped currentness is separate from the retained report. No signature, legal personhood or historical execution is reauthorized."}
