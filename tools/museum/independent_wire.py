"""Exact historical wire/hash checks for StreamCollectionAttestations v1.

Historical signature acceptance comes from the externally admitted host runtime
and its stored receipt. These checks bind the full retained proof; they do not
ask today's wallet to approve an old signature or prove the RPC is truthful.
"""

from .canonical import MuseumError, hex_bytes, keccak256, schema_id, subject_id, record_chain
from .chain_abi import Array, decode, encode


ZERO = "0x" + "00" * 32
ZERO_ADDRESS = "0x" + "00" * 20
HASH_REF = ("uint16", "bytes", "bytes32")
RECORD = ("bytes32", "bytes32", HASH_REF, "string", "bytes32", "bytes32", HASH_REF, "uint64")
RECEIPT = ("uint256", "address", "uint8", "uint64", "uint64", "bytes32", "bytes32",
           "uint256", "uint64", "bytes32", "bytes32")
SUBJECT = ("uint8", "uint256", "uint256", "bytes32")
DOCUMENT_SPEC = ("string", "uint8", "bytes32", "bytes32", "bytes32", "string", "uint32")
DOCUMENT = ("bool", "uint8", "bytes32", DOCUMENT_SPEC, Array("bytes32"))
TYPE_NAME = ("StreamIndependentPreservationRecord(address attestor,uint256 scopeKey,"
             "bytes32 subjectId,bytes32 recordType,bytes32 schemaId,uint16 algorithmId,"
             "bytes digest,bytes32 canonicalizationId,string uri,bytes payload,"
             "uint64 effectiveAt,uint256 nonce,uint64 deadline)")
TYPE_HASH = "0xcb13914f7a4c90b3e2d3d1513c3009284117ccab71b2a60935a620486947c768"
RECORD_TYPES = tuple(schema_id("INDEPENDENT_" + suffix) for suffix in (
    "FIXITY", "PRESERVATION_EVENT", "EXHIBITION", "CONDITION", "CONSERVATION_TREATMENT",
    "ENVIRONMENT_MIGRATION", "EXPORT_MIRROR", "SEMANTIC_ASSERTION"))
RAW_BYTES = schema_id("RAW_BYTES")
RAW_DEFINITION = b'{"name":"RAW_BYTES","rule":"Do not transform the supplied bytes.","version":1}'


def require(condition, message):
    if not condition:
        raise MuseumError(message)


def domain(chain_id, host):
    return keccak256(encode(("bytes32", "bytes32", "bytes32", "uint256", "address"), (
        schema_id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
        schema_id("6529StreamCollectionAttestations"), schema_id("1"), chain_id, host)))


def hash_ref(ref):
    return keccak256(encode(("uint16", "bytes32", "bytes32"), (ref[0], keccak256(ref[1]), ref[2])))


def generic_hash(chain_id, host, core, scope, attestor, record):
    record_type, subject, content, uri, schema, scheme, signature, effective = record
    return keccak256(encode(("bytes32", "uint256", "address", "address", "address", "uint256",
                            "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32",
                            "bytes32", "uint64"), (
        schema_id("6529stream.preservation-record.v2"), chain_id, host, core, attestor, scope,
        record_type, subject, hash_ref(content), keccak256(uri.encode("utf-8")), schema, scheme,
        hash_ref(signature), effective)))


def verify_record(chain_id, host, core, timestamp, lane, index, previous, record_hash,
                  record_output, subject_output, payload, bundle):
    record, receipt = decode((RECORD, RECEIPT), record_output)
    subject, = decode((SUBJECT,), subject_output)
    scope, attestor, authority, recorded, stored_index, chain, authorization, nonce, deadline, sh, ch = receipt
    record_type, sid, content, uri, schema, scheme, signature, effective = record
    kind, collection, token, object_id = subject
    require(scope == lane[0] and record_type == lane[1] and record_type in RECORD_TYPES,
            "record lane mismatch")
    require(attestor != ZERO_ADDRESS and authority == 5 and stored_index == index,
            "record authority/index mismatch")
    require(0 < recorded <= timestamp and deadline >= recorded and effective > 0,
            "record publication time mismatch")
    require(schema != ZERO and sh != ZERO and ch != ZERO, "record definition missing")
    require(0 < len(payload) <= 8192 and content[0] == 1 and len(content[1]) == 32
            and content[2] != ZERO and keccak256(payload) == "0x" + content[1].hex(),
            "record payload commitment/bound mismatch")
    require(len(uri.encode("utf-8")) <= 2048, "record URI byte bound")
    require(collection == scope and kind in (0, 1, 2), "subject scope/kind mismatch")
    if kind == 0:
        require(token == 0 and object_id == ZERO, "collection subject shape")
    elif kind == 1:
        require(collection > 0 and token > 0 and object_id == ZERO, "token subject shape")
    else:
        require(collection > 0 and token == 0 and object_id != ZERO, "media subject shape")
    expected_subject = subject_id(("collection", "token", "media")[kind], str(chain_id), core,
                                  str(collection), token_id=str(token), object_id=object_id)
    require(sid == expected_subject, "subject preimage mismatch")
    require(generic_hash(chain_id, host, core, scope, attestor, record) == record_hash,
            "generic record hash mismatch")
    require(record_chain(str(chain_id), host, str(scope), record_type, previous, record_hash,
                         str(index)) == chain, "rolling record chain mismatch")
    require(0 < len(bundle) <= 8192 and signature == (1, hex_bytes(keccak256(bundle)), RAW_BYTES),
            "signature bundle commitment/bound mismatch")
    saved_domain, saved_words, signed_bytes = decode(("bytes32", ("bytes32",) * 14, "bytes"), bundle,
                                                    maximum=8192)
    require(len(signed_bytes) <= 4096, "signature byte bound")
    require(scheme in tuple(schema_id(s) for s in ("DIRECT", "EIP712", "ERC1271")),
            "unsupported historical signature scheme")
    if scheme == schema_id("DIRECT"):
        require(not signed_bytes, "direct record has signature bytes")
    if scheme == schema_id("EIP712"):
        require(len(signed_bytes) in (64, 65), "EOA signature shape")
    words = encode(("bytes32", "address", "uint256", "bytes32", "bytes32", "bytes32", "uint16",
                    "bytes32", "bytes32", "bytes32", "bytes32", "uint64", "uint256", "uint64"), (
        TYPE_HASH, attestor, scope, sid, record_type, schema, content[0], keccak256(content[1]),
        content[2], keccak256(uri.encode("utf-8")), keccak256(payload), effective, nonce, deadline))
    require(saved_domain == domain(chain_id, host) and encode(("bytes32",) * 14, saved_words) == words,
            "full signed tuple/domain mismatch")
    require(keccak256(b"\x19\x01" + hex_bytes(saved_domain) + hex_bytes(keccak256(words))) == authorization,
            "authorization digest mismatch")
    return record, receipt, subject


def verify_document(document_id, raw, payload, expected_kind=None, expected_hash=None):
    document, = decode((DOCUMENT,), raw, maximum=8192)
    exists, status, declaration, spec, chunks = document
    name, kind, content_hash, canonical, predecessor, uri, total = spec
    require(exists and status in (0, 1, 2) and kind in (0, 1, 2, 3), "unknown document/status/kind")
    require(schema_id(name) == document_id and 0 < len(name.encode("utf-8")) <= 128
            and all(c.isascii() and (c.isalnum() or c in "_-.") for c in name), "document identity")
    require(0 < total <= 524288 and 0 < len(chunks) <= 64 and len(payload) == total
            and keccak256(payload) == content_hash, "document bytes/hash/bound mismatch")
    require(len(uri.encode("utf-8")) <= 2048 and canonical != ZERO and predecessor != document_id,
            "document reference shape")
    require(keccak256(encode((DOCUMENT_SPEC, Array("bytes32")), (spec, chunks))) == declaration,
            "document declaration mismatch")
    require(expected_kind is None or kind == expected_kind, "document kind mismatch")
    require(expected_hash is None or content_hash == expected_hash, "historical definition hash mismatch")
    if document_id == RAW_BYTES:
        require(kind == 1 and canonical == RAW_BYTES and predecessor == ZERO
                and payload == RAW_DEFINITION, "RAW_BYTES bootstrap mismatch")
    return document


def json_values(value):
    """Lossless wire tuples for retained diagnostics; no floats or source coercion."""
    if type(value) is bytes:
        return "0x" + value.hex()
    if type(value) is int:
        return str(value)
    if isinstance(value, (tuple, list)):
        return [json_values(v) for v in value]
    return value
