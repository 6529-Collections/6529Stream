"""Native owner catalogue and token lanes using provider-admitted public logs.

The type denominator combines the fixed native catalogue with all returned type
admissions. Native lane heads supply record counts. Completeness of filtered
admission/publication logs remains an explicit RPC-provider trust assumption.
"""
from .canonical import dumps, hex_bytes, keccak256, loads, record_chain, uint
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require
from .owner_catalog_source import (OwnerCatalogSource, PROFILE as ORIGINAL_PROFILE,
    PROFILE_HASH as ORIGINAL_PROFILE_HASH, CLAIMS as ORIGINAL_CLAIMS,
    FIXED_TYPES, MAX_TYPES, MAX_RECORDS, MAX_ABI, MAX_ANCHOR, OWNER_RECORD, RECEIPT,
    ADMISSION_EVENT, RECORD_EVENT, verify_native_wire, _position, _location)
from .public_chain_history import (scan_public_history, PROFILE as HISTORY_PROFILE,
    PROFILE_HASH as HISTORY_PROFILE_HASH)
from .public_history_rpc import (PublicRecordingReader, PublicReplayTransport, PublicRpcTransport,
    PROFILE as RPC_PROFILE, PROFILE_HASH as RPC_PROFILE_HASH, MAX_TRANSCRIPT, quantity)


PROFILE = "STREAM_MUSEUM_PUBLIC_OWNER_CATALOG_SOURCE_V1"
MAX_OUTPUT = 64 * 1024 * 1024
CLAIMS = dict(ORIGINAL_CLAIMS, nativeLaneRecordDenominatorsChecked=True,
    filteredEventReceiptCorrespondenceChecked=True, providerLogCompletenessTrusted=True,
    canonicalMappingTrusted=True, genesisWalk=False, allBlockReceipts=False,
    independentlyVerifiedLogCompleteness=False, ancestryProven=False)
QUALIFICATION = (
    "Complete fixed-plus-provider-observed admitted native type catalogue and every native lane for "
    "the exact token at the pinned source block. Type admissions and token publication logs are "
    "queried over numeric block zero through the anchor using only two consumer-derived filters. "
    "Native per-type heads and indexes supply record denominators; RPC log completeness and canonical "
    "block mappings remain provider trust. An omitted empty admitted type cannot be independently "
    "discovered from native state. Returned logs are checked against their complete receipts and "
    "touched canonical headers; this is not a genesis walk, all-block receipt capture or ancestry "
    "proof. Historical original receipt/signature preimages do not reauthorize an old owner or prove "
    "current custody, legal title, payload semantics, signature cryptography, consensus or full dossier "
    "conformance. Opaque and URI-only commitments remain opaque. Transcript origin is externally admitted.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_read_profile",
    "originalSemanticsProfileHash": ORIGINAL_PROFILE_HASH,
    "historyProfile": {"id": HISTORY_PROFILE, "hash": HISTORY_PROFILE_HASH},
    "rpcProfile": {"id": RPC_PROFILE, "hash": RPC_PROFILE_HASH},
    "fixedTypes": list(FIXED_TYPES),
    "bounds": {"types": str(MAX_TYPES), "records": str(MAX_RECORDS), "abiBytes": str(MAX_ABI),
        "anchorBytes": str(MAX_ANCHOR), "snapshotBytes": str(MAX_OUTPUT), "transcriptBytes": str(MAX_TRANSCRIPT)},
    "filters": ["host: OwnerRecordTypeAdmitted, all types", "host: OwnerRecordRecorded, indexed exact tokenId"],
    "rules": {"range": "Inclusive numeric block zero through the source anchor; no caller range, type list or transaction hint.",
        "native": "Original owner catalogue anchor, bindings, event admission order, lane hashes, receipts, signature bundles, nonces and author-latest checks unchanged.",
        "end": "Repeat both source hash and number headers after all native reads, require exact equality, and exhaust replay."},
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


class PublicOwnerCatalogSource(OwnerCatalogSource):
    """Additive public capture; original owner ABI and historical meaning remain fixed."""

    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc") and
            (provenance != "trusted_rpc" or type(transport) in (PublicRpcTransport, PublicReplayTransport)),
            "public owner catalogue provenance")
        a = loads(anchor_bytes, maximum=MAX_ANCHOR, canonical=True)
        require(type(a) is dict and a.get("profile") == PROFILE, "public owner catalogue anchor shape/profile")
        # The original constructor performs no reads. Preserve its closed anchor
        # validation without changing any shared module globals or old bytes.
        super().__init__(dumps(dict(a, profile=ORIGINAL_PROFILE)), transport, provenance="synthetic_fixture")
        self.anchor_bytes, self.a, self.provenance = anchor_bytes, a, provenance
        self.reader = PublicRecordingReader(transport, a["blockHash"])

    def _filters(self):
        return [{"address": self.a["host"], "topics": [ADMISSION_EVENT]},
            {"address": self.a["host"], "topics": [RECORD_EVENT, "0x" + uint(self.a["tokenId"]).to_bytes(32, "big").hex()]}]

    def _capture(self):
        a = self.a; token, chain = uint(a["tokenId"]), uint(a["chainId"])
        subject = self._bindings()
        history = scan_public_history(self.reader, a, filters=self._filters())
        source_header = dumps(next(row["result"] for row in self.reader.rows if row["method"] == "eth_getBlockByHash"
            and row["params"] == [a["blockHash"], False]))
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
        require(dumps(self.reader.request("eth_getBlockByHash", [a["blockHash"], False])) == source_header
            and dumps(self.reader.request("eth_getBlockByNumber", [hex(uint(a["blockNumber"])), False])) == source_header,
            "public owner catalogue final source header differs")
        if type(self.reader.transport) is PublicReplayTransport: self.reader.transport.finish()
        result = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1",
            "mode": "caller_admitted_rpc_owner_catalogue" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "provenanceDeclaredByCaller": True, "anchorHash": keccak256(self.anchor_bytes),
            "transcriptHash": keccak256(self.transcript()),
            "sourceState": {key: a[key] for key in ("chainId", "core", "tokenId", "blockNumber", "blockHash")},
            "host": a["host"], "subjectId": subject, "catalogue": [catalogue[key] for key in sorted(catalogue)],
            "lanes": lanes, "records": [records[key] for key in sorted(records)],
            "historyCoverage": history["coverage"], "claims": CLAIMS, "qualification": QUALIFICATION})
        require(len(result) <= MAX_OUTPUT, "public owner catalogue snapshot bound")
        return result
