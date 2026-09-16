"""Complete native OwnerRecords type catalogue and one token's historical lanes.

Completeness depends on the externally admitted append-only native host and a
bounded genesis-to-anchor receipt scan. Its original receipts establish native
publication acceptance; they do not prove legal title, current custody, payload
semantics or Ethereum consensus. Opaque/URI-only commitments remain opaque.
"""
from hashlib import sha256
from pathlib import Path

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, record_chain, schema_id, subject_id, uint
from .chain_abi import calldata, decode, encode
from .chain_rpc import MAX_TRANSCRIPT, RecordingReader, ReplayTransport, RpcTransport, quantity
from .independent_wire import HASH_REF, RAW_BYTES, ZERO, ZERO_ADDRESS, generic_hash, json_values, require

PROFILE = "STREAM_MUSEUM_OWNER_CATALOG_SOURCE_V1"
FIXED_TYPES = ("ACCESSION", "CONDITION_REPORT", "EXHIBITION", "LOAN", "DEACCESSION", "CITATION",
    "VALUATION", "STEWARD_DESIGNATION", "RECOVERY_RESPONSE", "REDEMPTION_CLAIM")
FIXED = {schema_id(name): name for name in FIXED_TYPES}
MAX_TYPES, MAX_RECORDS, MAX_ABI, MAX_ANCHOR = 256, 4096, 32768, 524288
OWNER_RECORD = ("bytes32", "bytes32", "bytes32", HASH_REF, "string", "bytes", "uint64")
RECEIPT = ("uint256", "address", "uint64", "uint64", "bytes32", "bool", "bytes32", "uint256", "uint64",
    "bytes32", "bytes32", "bytes32", "bytes32")
RECORD_EVENT = schema_id("OwnerRecordRecorded(uint256,bytes32,address,(bytes32,bytes32,bytes32,(uint16,bytes,bytes32),string,bytes,uint64),bytes32,bytes32,bool,uint16)")
ADMISSION_EVENT = schema_id("OwnerRecordTypeAdmitted(bytes32,bytes32,uint16)")
TYPE_HASH = "0x9c8c4f8b7ec1e8731277f53e36271ebf92fc96425f0c082143042400814c6b05"
QUALIFICATION = ("Complete native fixed-plus-admitted type catalogue and all lanes for the exact token at the admitted source block. "
    "Original host receipts and full genesis history supply publication authority and empty-lane accounting within the pinned native implementation. "
    "RPC origin is externally declared, not authenticated by transcript bytes. Historical schema commitments are retained without semantic interpretation. "
    "Opaque or URI-only content commitments are not byte-verified; no current custody, legal title, consensus or full dossier conformance is established.")
CLAIMS = {"completeNativeTypeCatalogue": True, "completeTokenLanes": True, "allObservedAuthorLatestChecked": True,
    "authenticatedEmptyLanesWithinAdmittedHost": True, "historicalReceiptCorrespondenceChecked": True,
    "allPayloadDigestsVerified": False, "currentOwnerProven": False, "legalTitleProven": False,
    "schemaInterpretationVerified": False, "actualChainAcceptance": False, "consensusProof": False,
    "fullObjectDossierConformance": False, "networkObjectFetch": False}
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_read_profile",
    "fixedTypes": list(FIXED_TYPES), "bounds": {"types": str(MAX_TYPES), "records": str(MAX_RECORDS),
        "abiBytes": str(MAX_ABI), "historyBlocks": "4096"}, "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def domain(chain, host):
    return keccak256(encode(("bytes32", "bytes32", "bytes32", "uint256", "address"),
        (schema_id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
         schema_id("6529StreamOwnerRecords"), schema_id("1"), chain, host)))


def signed_words(record, receipt):
    rt, sid, schema, content, uri, payload, effective = record
    return encode(("bytes32", "address", "uint256", "bytes32", "bytes32", "bytes32", "uint16", "bytes32",
        "bytes32", "bytes32", "bytes32", "uint64", "uint256", "uint64"),
        (TYPE_HASH, receipt[1], receipt[0], sid, rt, schema, content[0], keccak256(content[1]), content[2],
         keccak256(uri.encode("utf-8")), keccak256(payload), effective, receipt[7], receipt[8]))


def native_hash(chain, host, core, record, receipt):
    rt, sid, schema, content, uri, _, effective = record
    generic = (rt, sid, content, uri, schema, receipt[11], (1, hex_bytes(receipt[12]), RAW_BYTES), effective)
    return generic_hash(chain, host, core, receipt[0], receipt[1], generic)


def verify_native_wire(chain, host, core, timestamp, expected, token, record, receipt, bundle):
    """Check the full native wire; report only byte correspondence actually checked."""
    # Canonical encoding enforces tuple lengths, unsigned widths and exact types.
    encode((OWNER_RECORD, RECEIPT), (record, receipt))
    rt, sid, schema, content, uri, payload, effective = record
    require(token > 0 and receipt[0] == token and receipt[1] != ZERO_ADDRESS
        and receipt[2] <= timestamp and effective > 0 and rt != ZERO
        and sid == subject_id("token", str(chain), core, "0", token_id=str(token))
        and schema != ZERO and content[2] != ZERO and receipt[9] != ZERO and receipt[10] != ZERO,
        "owner catalogue original identity/receipt differs")
    algorithm, digest, _ = content
    require(len(payload) <= 8192 and ((algorithm in (1, 2, 3, 6) and len(digest) == 32)
        or (algorithm in (4, 5) and 0 < len(digest) <= 128)), "owner catalogue native payload/hash shape")
    raw_uri = uri.encode("utf-8")
    safe_uri = (not raw_uri or (all(b > 32 and b != 127 for b in raw_uri)
        and ((raw_uri.startswith(b"https://") and len(raw_uri) > 8 and raw_uri[8] not in b"/?#")
            or (raw_uri.startswith(b"ipfs://") and len(raw_uri) > 7)
            or (raw_uri.startswith(b"ar://") and len(raw_uri) > 5))))
    require(len(raw_uri) <= 2048 and safe_uri, "owner catalogue native URI differs")
    correspondence = "external_or_empty_commitment" if not payload else "opaque_algorithm_commitment"
    if payload and algorithm in (1, 2):
        actual = hex_bytes(keccak256(payload)) if algorithm == 1 else sha256(payload).digest()
        require(actual == digest, "owner catalogue embedded digest differs")
        correspondence = "embedded_keccak256_verified" if algorithm == 1 else "embedded_sha256_verified"
    require(type(bundle) is bytes and 0 < len(bundle) <= 8192 and keccak256(bundle) == receipt[12],
        "owner catalogue signature bundle commitment differs")
    if not receipt[5]:
        require(receipt[6] == ZERO and receipt[7] == 0 and receipt[8] == 0 and receipt[11] == schema_id("DIRECT")
            and bundle == encode(("bytes32", "address", "bytes32"),
                (schema_id("DIRECT"), receipt[1], keccak256(payload))), "owner catalogue direct bundle differs")
    else:
        saved_domain, words, signature = decode(("bytes32", ("bytes32",) * 14, "bytes"), bundle, maximum=8192)
        require(receipt[8] >= receipt[2] and len(signature) <= 4096
            and receipt[11] in (schema_id("EIP712"), schema_id("ERC1271")), "owner catalogue relayed receipt differs")
        if receipt[11] == schema_id("EIP712"):
            require(len(signature) in (64, 65), "owner catalogue EOA signature shape")
        body = signed_words(record, receipt)
        require(saved_domain == domain(chain, host) and encode(("bytes32",) * 14, words) == body
            and receipt[6] == keccak256(b"\x19\x01" + hex_bytes(saved_domain) + hex_bytes(keccak256(body))),
            "owner catalogue original signed preimage differs")
    require(native_hash(chain, host, core, record, receipt) == expected, "owner catalogue record hash differs")
    return correspondence


def _anchor(raw):
    a = loads(raw, maximum=MAX_ANCHOR, canonical=True)
    require(type(a) is dict and set(a) == {"profile", "chainId", "blockHash", "blockNumber", "timestamp", "stateRoot",
        "environment", "deploymentEvidenceHash", "host", "core", "schemas", "store", "codePins", "tokenId"}
        and a["profile"] == PROFILE and a["environment"] in ("local_evm_fixture", "public_chain"),
        "owner catalogue anchor shape")
    for key in ("chainId", "blockNumber", "tokenId"):
        uint(a[key])
    uint(a["timestamp"], 64)
    require(uint(a["chainId"]) > 0 and uint(a["tokenId"]) > 0, "owner catalogue identity must be nonzero")
    for key in ("blockHash", "stateRoot", "deploymentEvidenceHash"):
        require(any(hex_bytes(a[key], 32)), "owner catalogue empty commitment")
    for key in ("host", "core", "schemas", "store"):
        require(any(hex_bytes(a[key], 20)), "owner catalogue dependency address")
    require(type(a["codePins"]) is list and 4 <= len(a["codePins"]) <= 64, "owner catalogue pin bound")
    pins = {}
    for row in a["codePins"]:
        require(type(row) is dict and set(row) == {"address", "runtimeHash"}, "owner catalogue pin shape")
        require(any(hex_bytes(row["address"], 20)) and any(hex_bytes(row["runtimeHash"], 32))
            and row["address"] not in pins, "owner catalogue duplicate/empty pin")
        pins[row["address"]] = row["runtimeHash"]
    require(all(a[key] in pins for key in ("host", "core", "schemas", "store")), "owner catalogue missing pin")
    return a, pins


def _position(log):
    return tuple(quantity(log[key]) for key in ("blockNumber", "transactionIndex", "logIndex"))


def _location(log):
    return {key: str(quantity(log[key])) if key in ("blockNumber", "transactionIndex", "logIndex") else log[key]
        for key in ("blockHash", "blockNumber", "transactionHash", "transactionIndex", "logIndex")}


class OwnerCatalogSource:
    """One independently pinned source; no caller type list or transaction hints."""

    def __init__(self, anchor_raw, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc")
            and (provenance != "trusted_rpc" or type(transport) in (RpcTransport, ReplayTransport)),
            "owner catalogue provenance")
        self.a, self.pins = _anchor(anchor_raw)
        self.anchor_bytes, self.provenance = anchor_raw, provenance
        self.reader = RecordingReader(transport, self.a["blockHash"])
        self._started, self._snapshot = False, None

    def transcript(self):
        return self.reader.transcript()

    def _read(self, target, signature, outputs, kinds=(), values=()):
        return decode(outputs, hex_bytes(self.reader.call(target, calldata(signature, kinds, values))), maximum=MAX_ABI)

    def snapshot(self):
        if self._snapshot is not None:
            return self._snapshot
        require(not self._started, "failed owner catalogue capture cannot resume")
        self._started = True
        try:
            self._snapshot = self._capture()
        except MuseumError:
            raise
        except (KeyError, TypeError, IndexError, ValueError, OverflowError) as exc:
            raise MuseumError("malformed owner catalogue evidence") from exc
        return self._snapshot

    def _bindings(self):
        a = self.a
        require(quantity(self.reader.request("eth_chainId", [])) == uint(a["chainId"]), "owner catalogue chain differs")
        for address, digest in sorted(self.pins.items()):
            code = hex_bytes(self.reader.code(address))
            require(0 < len(code) <= 24576 and keccak256(code) == digest, "owner catalogue runtime differs")
        for key, getter in (("core", "core"), ("schemas", "schemaRegistry"), ("store", "chunkStore")):
            require(self._read(a["host"], getter + "()", ("address",)) == (a[key],), "owner catalogue host dependency differs")
            require(self._read(a["host"], getter + "CodeHash()", ("bytes32",)) == (self.pins[a[key]],),
                "owner catalogue original dependency pin differs")
        require(self._read(a["schemas"], "chunkStore()", ("address",)) == (a["store"],), "owner catalogue schema store differs")
        for getter, value in (("streamModuleType()", schema_id("OWNER_RECORDS")),
                              ("streamModuleVersion()", schema_id("6529stream.owner-records.v1"))):
            require(self._read(a["host"], getter, ("bytes32",)) == (value,), "owner catalogue native module differs")
        subject = subject_id("token", a["chainId"], a["core"], "0", token_id=a["tokenId"])
        require(self._read(a["host"], "deriveOwnerSubject(uint256)", ("bytes32",), ("uint256",),
            (uint(a["tokenId"]),)) == (subject,), "owner catalogue native token subject differs")
        return subject

    def _events(self, history):
        catalogue = {key: {"recordType": key, "name": name, "origin": "native_fixed", "admission": None}
            for key, name in FIXED.items()}
        events = {}
        for log in history["logs"]:
            if log["address"] != self.a["host"] or not log["topics"]:
                continue
            topics = log["topics"]
            if topics[0] == ADMISSION_EVENT:
                require(len(topics) == 3 and topics[1] != ZERO and topics[2] != ZERO
                    and topics[1] not in catalogue, "owner catalogue duplicate/invalid type admission")
                require(decode(("uint16",), hex_bytes(log["data"]), maximum=32) == (1,),
                    "owner catalogue admission schema version")
                catalogue[topics[1]] = {"recordType": topics[1], "name": None, "origin": "native_admitted",
                    "admission": {"actionId": topics[2], **_location(log)}}
                require(len(catalogue) <= MAX_TYPES, "owner catalogue type bound")
            elif topics[0] == RECORD_EVENT:
                require(len(topics) == 4, "owner catalogue publication topic shape")
                token, = decode(("uint256",), hex_bytes(topics[1], 32))
                owner, = decode(("address",), hex_bytes(topics[3], 32))
                require(token > 0 and owner != ZERO_ADDRESS and topics[2] in catalogue,
                    "owner catalogue publication type not yet admitted")
                if token != uint(self.a["tokenId"]):
                    continue
                record, digest, chain, relayed, version = decode(
                    (OWNER_RECORD, "bytes32", "bytes32", "bool", "uint16"), hex_bytes(log["data"]), maximum=MAX_ABI)
                require(version == 1 and digest != ZERO and chain != ZERO and record[0] == topics[2]
                    and digest not in events, "owner catalogue duplicate/invalid publication")
                events[digest] = (record, owner, chain, relayed, log)
                require(len(events) <= MAX_RECORDS, "owner catalogue record bound")
        return catalogue, events

    def _capture(self):
        from .chain_history import scan_history
        a = self.a; token, chain = uint(a["tokenId"]), uint(a["chainId"])
        subject = self._bindings()
        history = scan_history(self.reader, {key: a[key] for key in
            ("chainId", "blockHash", "blockNumber", "timestamp", "stateRoot")})
        catalogue, events = self._events(history)
        lanes, records, used_nonces = [], {}, set()
        for record_type in sorted(catalogue):
            require(self._read(a["host"], "isOwnerRecordType(bytes32)", ("bool",), ("bytes32",),
                (record_type,)) == (True,), "owner catalogue admitted type absent in state")
            head, count = self._read(a["host"], "recordChainHash(uint256,bytes32)", ("bytes32", "uint64"),
                ("uint256", "bytes32"), (token, record_type))
            require(count <= MAX_RECORDS - len(records), "owner catalogue complete lane bound")
            previous, hashes, authors, positions = ZERO, [], {}, []
            for index in range(count):
                digest, = self._read(a["host"], "recordHashAt(uint256,bytes32,uint256)", ("bytes32",),
                    ("uint256", "bytes32", "uint256"), (token, record_type, index))
                require(digest != ZERO and digest not in records and digest in events, "owner catalogue missing/duplicate record event")
                record, receipt = self._read(a["host"], "ownerRecord(bytes32)", (OWNER_RECORD, RECEIPT), ("bytes32",), (digest,))
                pointer, bundle = self._read(a["host"], "ownerRecordSignatureBundle(bytes32)", ("address", "bytes"),
                    ("bytes32",), (digest,))
                correspondence = verify_native_wire(chain, a["host"], a["core"], uint(a["timestamp"]),
                    digest, token, record, receipt, bundle)
                require(pointer != ZERO_ADDRESS and hex_bytes(self.reader.code(pointer)) == b"\x00" + bundle,
                    "owner catalogue retained signature storage differs")
                require(record[0] == record_type and receipt[3] == index
                    and record_chain(a["chainId"], a["host"], a["tokenId"], record_type, previous, digest, str(index)) == receipt[4],
                    "owner catalogue lane index/chain differs")
                published, owner, event_chain, relayed, log = events[digest]
                require(published == record and owner == receipt[1] and event_chain == receipt[4] and relayed == receipt[5]
                    and receipt[2] == uint(history["blockTimestamps"][str(quantity(log["blockNumber"]))]),
                    "owner catalogue original publication receipt differs")
                if receipt[5]:
                    nonce_key = (receipt[1], receipt[7])
                    require(nonce_key not in used_nonces, "owner catalogue reused original nonce")
                    used_nonces.add(nonce_key)
                    require(self._read(a["host"], "isOwnerRecordNonceUsed(address,uint256)", ("bool",),
                        ("address", "uint256"), nonce_key) == (True,), "owner catalogue accepted nonce missing")
                positions.append(_position(log)); hashes.append(digest); authors[receipt[1]] = digest
                records[digest] = {"recordHash": digest, "record": json_values(record), "receipt": json_values(receipt),
                    "signatureBundleHex": "0x" + bundle.hex(), "signaturePointer": pointer,
                    "payloadCorrespondence": correspondence, "publication": _location(log),
                    "authority": {"mode": "historical_native_owner_receipt", "owner": receipt[1],
                        "currentOwnerProven": False, "legalTitleProven": False}}
                previous = receipt[4]
            require(head == previous and positions == sorted(set(positions)), "owner catalogue lane head/publication order differs")
            latest = []
            for owner, digest in sorted(authors.items()):
                require(self._read(a["host"], "latestOwnerRecordHashFor(uint256,bytes32,address)", ("bytes32",),
                    ("uint256", "bytes32", "address"), (token, record_type, owner)) == (digest,),
                    "owner catalogue per-author latest differs")
                latest.append({"owner": owner, "recordHash": digest})
            lanes.append({"recordType": record_type, "count": str(count), "head": head, "records": hashes,
                "state": "authenticated_empty" if count == 0 else "complete_history", "latestByAuthor": latest})
        require(set(records) == set(events), "owner catalogue publication outside complete state lanes")
        # Complete state reads are pinned to the same EIP-1898 anchor; repeat its header
        # after the lane reads, not only at the end of the full-history scan.
        end = self.reader.request("eth_getBlockByHash", [a["blockHash"], False])
        require(type(end) is dict and end.get("hash") == a["blockHash"] and end.get("stateRoot") == a["stateRoot"]
            and quantity(end.get("number")) == uint(a["blockNumber"])
            and quantity(end.get("timestamp")) == uint(a["timestamp"]), "owner catalogue final anchor differs")
        if type(self.reader.transport) is ReplayTransport:
            self.reader.transport.finish()
        return dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1",
            "mode": "caller_admitted_rpc_owner_catalogue" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "provenanceDeclaredByCaller": True, "anchorHash": keccak256(self.anchor_bytes),
            "transcriptHash": keccak256(self.transcript()),
            "sourceState": {key: a[key] for key in ("chainId", "core", "tokenId", "blockNumber", "blockHash")},
            "host": a["host"], "subjectId": subject, "catalogue": [catalogue[key] for key in sorted(catalogue)],
            "lanes": lanes, "records": [records[key] for key in sorted(records)],
            "history": {key: history[key] for key in ("blockCount", "transactionCount", "startBlock", "endBlock")},
            "claims": CLAIMS, "qualification": QUALIFICATION})


def definitions(directory, *, check=False):
    path = Path(directory) / "owner-catalog-profile.json"
    if check:
        require(path.is_file() and _bounded_read(path, MAX_ANCHOR) == PROFILE_BYTES, "owner catalogue profile differs")
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(PROFILE_BYTES)
    return PROFILE_HASH


def _bounded_read(path, maximum):
    with Path(path).open("rb") as stream:
        raw = stream.read(maximum + 1)
    require(len(raw) <= maximum, "owner catalogue input file bound")
    return raw


def write_capture(source, output):
    from .bagit import MAX_BYTES, write_tree
    snapshot = source.snapshot()
    transcript = source.transcript()
    pins = {"profileHash": PROFILE_HASH, "anchorHash": keccak256(source.anchor_bytes),
        "snapshotHash": keccak256(snapshot), "transcriptHash": keccak256(transcript),
        "provenance": source.provenance, "actualChainAcceptance": False}
    files = {"anchor.json": source.anchor_bytes, "transcript.json": transcript,
        "snapshot.json": snapshot, "pins.json": dumps(pins), "profile.json": PROFILE_BYTES}
    require(sum(map(len, files.values())) <= MAX_BYTES, "owner catalogue output byte bound")
    write_tree(files, output)
    return pins


def main():
    import argparse
    import os
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    definition = commands.add_parser("definitions")
    definition.add_argument("--output", type=Path, required=True)
    definition.add_argument("--check", action="store_true")
    for name in ("capture", "replay"):
        command = commands.add_parser(name)
        command.add_argument("--anchor", type=Path, required=True)
        command.add_argument("--anchor-hash", required=True)
        command.add_argument("--output", type=Path, required=True)
        if name == "capture":
            command.add_argument("--rpc-env", required=True)
        else:
            command.add_argument("--transcript", type=Path, required=True)
            command.add_argument("--transcript-hash", required=True)
            command.add_argument("--provenance", choices=("synthetic_fixture", "trusted_rpc"), default="synthetic_fixture")
    args = parser.parse_args()
    if args.command == "definitions":
        print(definitions(args.output, check=args.check))
        return
    anchor = _bounded_read(args.anchor, MAX_ANCHOR)
    require(keccak256(anchor) == args.anchor_hash, "owner catalogue external anchor commitment differs")
    if args.command == "capture":
        endpoint = os.environ.get(args.rpc_env)
        require(bool(endpoint), "owner catalogue RPC environment variable missing")
        transport = RpcTransport(endpoint)
    else:
        transport = ReplayTransport(_bounded_read(args.transcript, MAX_TRANSCRIPT), args.transcript_hash)
    source = OwnerCatalogSource(anchor, transport, provenance="trusted_rpc" if args.command == "capture" else args.provenance)
    print(dumps(write_capture(source, args.output)).decode("utf-8"))


if __name__ == "__main__":
    try:
        main()
    except (MuseumError, OSError) as exc:
        raise SystemExit(str(exc)) from None
