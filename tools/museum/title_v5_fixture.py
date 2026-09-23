"""Synthetic eleven-source title fixture; no chain, legal-title or institution proof.

All OwnerRecords and Core transfers are installed before either package is
captured.  The unchanged nine-source preservation fixture and both additional
readers use one response map and return identical shared headers and receipts.
"""
from . import acquisition_accession as accession
from . import acquisition_preservation_v5 as preservation
from . import institutional
from . import owner_catalog_source as wire
from . import public_owner_catalog_source as owner_source
from . import public_ownership_source as ownership_source
from .canonical import dumps, hex_bytes, keccak256, record_chain, schema_id, subject_id
from .chain_abi import encode
from .independent_wire import RAW_BYTES, ZERO, ZERO_ADDRESS
from .preservation_v5_fixture import PreservationV5Fixture
from .ownership_source import TRANSFER
from .test_acquisition_accession import _accession, _deaccession, _hash_ref
from .test_current_rights_source import A, H


TOKEN, COLLECTION, SERIAL = 41, 1, 3
MINT_RECIPIENT, ACQUIRER, LATER_OWNER = A(90), A(28001), A(28002)


class TitleV5Fixture(PreservationV5Fixture):
    """Concrete replay fixtures; an explicit selected accession remains historical."""

    def __init__(self, *, later_accession=False, burned=False, unsupported=True, self_transfer_before_selected=False):
        super().__init__()
        self.title_host = A(28000)
        self.codes[self.title_host] = b"synthetic native OwnerRecords title fixture"
        self.pins[self.title_host] = keccak256(self.codes[self.title_host])
        self.typed_rows, self.owner_events = [], {}
        self.instrument = b"Synthetic title instrument\r\nexact retained bytes\n"
        self.instrument_ref = _hash_ref(self.instrument)
        self.title_burned = burned
        self._title_bindings()

        mint = next(log for receipt in self.receipts.values() for log in receipt["logs"]
            if log["address"] == self.core and log["topics"][0] == TRANSFER
            and log["topics"][1] == ZERO and log["topics"][3] == self.topic("uint256", TOKEN))
        self.transfer_rows = [mint]
        self.first_accession = self.append_owner("ACCESSION", self._accession_value(mint, "mint"), 3, MINT_RECIPIENT)
        hop = self.append_transfer(4, MINT_RECIPIENT, ACQUIRER)
        if self_transfer_before_selected:
            self.append_transfer(4, ACQUIRER, ACQUIRER)
        self.selected = self.append_owner("ACCESSION", self._accession_value(hop, "selected"), 4,
            ACQUIRER, relayed="EIP712")
        hop = self.append_transfer(5, ACQUIRER, LATER_OWNER)
        value = _deaccession(self.transfer_value(hop)); value["tokenId"] = str(TOKEN)
        self.deaccession = self.append_owner("DEACCESSION", value, 5, LATER_OWNER, relayed="ERC1271")
        self.later_accession = (self.append_owner("ACCESSION", self._accession_value(hop, "later"), 5,
            LATER_OWNER) if later_accession else None)
        self.unsupported = (self.append_owner("ACCESSION", {"opaque": "uninterpreted historical title row"},
            5, LATER_OWNER, schema="STREAM_VALUATION_V1") if unsupported else None)
        if burned:
            self.append_transfer(5, LATER_OWNER, ZERO_ADDRESS)
        self._title_lane_state()
        self.add(self.core, "tokenCollectionIdentity(uint256)", ("uint256",), (TOKEN,),
            ("bool", "uint256", "uint256", "bool"), (True, COLLECTION, SERIAL, burned))
        self.add(self.core, "tokenLifecycle(uint256)", ("uint256",), (TOKEN,), ("uint8",), (3 if burned else 2,))
        self.add(self.core, "ownerOf(uint256)", ("uint256",), (TOKEN,), ("address",), (LATER_OWNER,))
        common = {key: self.a[key] for key in ("chainId", "blockHash", "blockNumber", "timestamp",
            "stateRoot", "environment", "deploymentEvidenceHash", "core")}
        self.title_owner_anchor = {**common, "profile": owner_source.PROFILE, "tokenId": str(TOKEN),
            "host": self.title_host, "schemas": A(3), "store": A(4), "codePins": [
                {"address": address, "runtimeHash": self.pins[address]}
                for address in (self.title_host, self.core, A(3), A(4))]}
        self.title_ownership_anchor = {**common, "profile": ownership_source.PROFILE,
            "tokenId": str(TOKEN), "collectionId": str(COLLECTION), "coreRuntimeHash": self.pins[self.core]}

    def _title_bindings(self):
        for getter, address in (("core", self.core), ("schemaRegistry", A(3)), ("chunkStore", A(4))):
            self.add(self.title_host, getter + "()", (), (), ("address",), (address,))
            self.add(self.title_host, getter + "CodeHash()", (), (), ("bytes32",), (self.pins[address],))
        self.add(A(3), "chunkStore()", (), (), ("address",), (A(4),))
        for getter, name in (("streamModuleType", "OWNER_RECORDS"), ("streamModuleVersion", "6529stream.owner-records.v1")):
            self.add(self.title_host, getter + "()", (), (), ("bytes32",), (schema_id(name),))
        self.add(self.title_host, "deriveOwnerSubject(uint256)", ("uint256",), (TOKEN,), ("bytes32",),
            (subject_id("token", self.a["chainId"], self.core, "0", token_id=str(TOKEN)),))
        for name in wire.FIXED_TYPES:
            self.add(self.title_host, "isOwnerRecordType(bytes32)", ("bytes32",), (schema_id(name),), ("bool",), (True,))

    def append_transfer(self, block, sender, recipient):
        log = self.event(block, self.core, [TRANSFER, self.topic("address", sender),
            self.topic("address", recipient), self.topic("uint256", TOKEN)], (), ())
        self.transfer_rows.append(log)
        return log

    def transfer_value(self, log):
        return {"chainId": self.a["chainId"], "core": self.core, "tokenId": str(TOKEN),
            "blockNumber": str(int(log["blockNumber"], 16)), "transactionHash": log["transactionHash"],
            "logIndex": str(int(log["logIndex"], 16)), "from": "0x" + log["topics"][1][-40:],
            "to": "0x" + log["topics"][2][-40:]}

    def _accession_value(self, transfer, suffix):
        value = _accession(self.transfer_value(transfer), self.instrument_ref, suffix=suffix)
        value.update(tokenId=str(TOKEN), accessionIdentifier="ACC-2026-41-" + suffix)
        return value

    def append_owner(self, family, value, block, author, *, relayed=None, schema=None):
        """Install original wire/getters/event, then call _title_lane_state after extra rows."""
        raw = dumps(value); record_type = schema_id(family)
        lane = [row for row in self.typed_rows if row[1][0] == record_type]
        schema = schema or institutional.NAMES[family]
        record = (record_type, subject_id("token", self.a["chainId"], self.core, "0", token_id=str(TOKEN)),
            schema_id(schema), (1, hex_bytes(keccak256(raw)), institutional.JCS_ID),
            "ipfs://synthetic-owner-title", raw, 1)
        stamp = int(self.blocks[H(200 + block)]["timestamp"], 16)
        receipt = [TOKEN, author, stamp, len(lane), ZERO, relayed is not None, ZERO, 0, 0,
            keccak256(institutional.SCHEMAS[family] if schema == institutional.NAMES[family] else dumps({"opaque": True})),
            keccak256(institutional.JCS_BYTES), schema_id(relayed or "DIRECT"), ZERO]
        if relayed is None:
            bundle = encode(("bytes32", "address", "bytes32"), (schema_id("DIRECT"), author, keccak256(raw)))
        else:
            receipt[7], receipt[8] = 2000 + len(self.typed_rows), stamp + 1000
            body = wire.signed_words(record, receipt); domain = wire.domain(int(self.a["chainId"]), self.title_host)
            words = tuple("0x" + body[index:index + 32].hex() for index in range(0, len(body), 32))
            signature = b"\x12" * 65 if relayed == "EIP712" else b"synthetic historical ERC1271 proof"
            bundle = encode(("bytes32", ("bytes32",) * 14, "bytes"), (domain, words, signature))
            receipt[6] = keccak256(b"\x19\x01" + hex_bytes(domain) + hex_bytes(keccak256(body)))
        receipt[12] = keccak256(bundle)
        digest = wire.native_hash(int(self.a["chainId"]), self.title_host, self.core, record, receipt)
        receipt[4] = record_chain(self.a["chainId"], self.title_host, str(TOKEN), record_type,
            lane[-1][2][4] if lane else ZERO, digest, str(receipt[3]))
        receipt = tuple(receipt); self.typed_rows.append((digest, record, receipt, bundle))
        pointer = self._carrier(bundle)
        self.add(self.title_host, "ownerRecord(bytes32)", ("bytes32",), (digest,), (wire.OWNER_RECORD, wire.RECEIPT), (record, receipt))
        self.add(self.title_host, "ownerRecordSignatureBundle(bytes32)", ("bytes32",), (digest,), ("address", "bytes"), (pointer, bundle))
        self.add(self.title_host, "recordHashAt(uint256,bytes32,uint256)", ("uint256", "bytes32", "uint256"),
            (TOKEN, record_type, receipt[3]), ("bytes32",), (digest,))
        if relayed:
            self.add(self.title_host, "isOwnerRecordNonceUsed(address,uint256)", ("address", "uint256"),
                (author, receipt[7]), ("bool",), (True,))
        self.owner_events[digest] = self.event(block, self.title_host,
            [wire.RECORD_EVENT, self.topic("uint256", TOKEN), record_type, self.topic("address", author)],
            (wire.OWNER_RECORD, "bytes32", "bytes32", "bool", "uint16"), (record, digest, receipt[4], receipt[5], 1))
        return digest

    def _title_lane_state(self):
        for name in wire.FIXED_TYPES:
            record_type = schema_id(name); lane = [row for row in self.typed_rows if row[1][0] == record_type]
            self.add(self.title_host, "recordChainHash(uint256,bytes32)", ("uint256", "bytes32"),
                (TOKEN, record_type), ("bytes32", "uint64"), (lane[-1][2][4] if lane else ZERO, len(lane)))
            latest = {row[2][1]: row[0] for row in lane}
            for author, digest in latest.items():
                self.add(self.title_host, "latestOwnerRecordHashFor(uint256,bytes32,address)",
                    ("uint256", "bytes32", "address"), (TOKEN, record_type, author), ("bytes32",), (digest,))

    def _title_capture(self, constructor, anchor, profile_hash):
        raw = dumps(anchor); source = constructor(raw, self)
        snapshot = source.snapshot(); transcript = source.transcript()
        return ({"anchor.json": raw, "transcript.json": transcript, "snapshot.json": snapshot},
            {"profileHash": profile_hash, "anchorHash": keccak256(raw), "snapshotHash": keccak256(snapshot),
                "transcriptHash": keccak256(transcript), "provenance": "synthetic_fixture"})

    def owner_capture(self):
        return self._title_capture(owner_source.PublicOwnerCatalogSource, self.title_owner_anchor, owner_source.PROFILE_HASH)

    def ownership_capture(self):
        return self._title_capture(ownership_source.PublicOwnershipSource, self.title_ownership_anchor, ownership_source.PROFILE_HASH)

    def accession_inputs(self, *, documents=True):
        owner_files, owner_pins = self.owner_capture(); ownership_files, ownership_pins = self.ownership_capture()
        selected = dumps({"profile": accession.PROFILE, "host": self.title_host, "tokenId": str(TOKEN),
            "accessionRecordHash": self.selected})
        return owner_files, owner_pins, ownership_files, ownership_pins, selected, (
            {keccak256(dumps(self.instrument_ref)): self.instrument} if documents else {})

    def accession_assembly(self, *, documents=True):
        owner_files, owner_pins, ownership_files, ownership_pins, selected, supplied = self.accession_inputs(documents=documents)
        result = accession.compose(owner_files, owner_pins, ownership_files, ownership_pins, selected,
            keccak256(selected), disclosure="public", documents=supplied)
        return accession.verify(dict(result.files), result.manifest_hash)

    def title_inputs(self):
        parts = self.preservation_inputs()
        old = preservation.compose(*(item for assembly in parts for item in (dict(assembly.files), assembly.manifest_hash)),
            disclosure="public")
        return preservation.verify(dict(old.files), old.manifest_hash), self.accession_assembly()
