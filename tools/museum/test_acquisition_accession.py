"""Synthetic accession/history joins; never actual-chain or legal-title evidence."""
from copy import deepcopy
from hashlib import sha256
import unittest
from unittest.mock import patch

from . import acquisition_accession as acquisition
from . import institutional
from . import owner_catalog_source as owner_wire
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, record_chain, schema_id, subject_id
from .chain_abi import encode
from .independent_wire import RAW_BYTES, ZERO, ZERO_ADDRESS, generic_hash
from .public_history_rpc import PublicReplayTransport
from .public_owner_catalog_source import PublicOwnerCatalogSource, PROFILE as OWNER_PROFILE, PROFILE_HASH as OWNER_PROFILE_HASH
from .public_ownership_source import PublicOwnershipSource, PROFILE as OWNERSHIP_PROFILE, PROFILE_HASH as OWNERSHIP_PROFILE_HASH
from .test_exhibitions import date, reference
from .test_loans import party
from .test_owner_catalog_source import A, H
from .test_public_owner_catalog_source import PublicOwnerCatalogFixture


TOKEN, COLLECTION = 71, 6
OWNER_A, OWNER_B, OWNER_C = A(8), A(9), A(10)


def _topic_address(value):
    return "0x" + encode(("address",), (value,)).hex()


def _topic_uint(value):
    return "0x" + int(value).to_bytes(32, "big").hex()


def _hash_ref(raw, algorithm="1"):
    digest = keccak256(raw) if algorithm == "1" else "0x" + sha256(raw).hexdigest()
    return {"algorithm": algorithm, "digest": digest, "canonicalizationId": RAW_BYTES}


def _accession(transfer, instrument, *, suffix="selected"):
    return {"version": "1", "recordId": "urn:test:accession:" + suffix, "tokenId": str(TOKEN),
        "recordedDate": date(), "supersedes": [], "accessionIdentifier": "ACC-2026-71-" + suffix,
        "acquiringInstitution": party("Synthetic acquiring museum", "acquiring-museum"),
        "titleBinding": {"instrument": {"uri": "https://example.invalid/instrument/" + suffix,
            "hash": instrument}, "custodian": party("Synthetic instrument custodian", "custodian"),
            "transfer": transfer}}


def _deaccession(transfer):
    return {"version": "1", "recordId": "urn:test:deaccession:later", "tokenId": str(TOKEN),
        "recordedDate": date(), "supersedes": [], "reasonClass": "urn:test:reason:transfer",
        "disposition": reference(21), "titleBinding": {"instrument": reference(22),
            "custodian": party("Synthetic later custodian", "later-custodian"), "transfer": transfer}}


class JoinedFixture(PublicOwnerCatalogFixture):
    """One coherent synthetic RPC response set consumed by both exact readers."""

    def __init__(self, *, selected_binding="matched", unsupported=True, bad_receipt_owner=False,
            instrument_algorithm="1", unsupported_owner=OWNER_C):
        super().__init__(source_block=5, empty=True)
        # Fill the sparse public interval only where events occur. These exact
        # headers and receipts are returned to both independent source readers.
        for number in (3, 4):
            self.blocks[number] = {"hash": H("joined-block-" + str(number)), "number": hex(number),
                "parentHash": self.blocks[number - 1]["hash"], "timestamp": hex(100 + number),
                "stateRoot": H("joined-state-" + str(number)), "transactions": []}
        self.blocks[5]["parentHash"] = self.blocks[4]["hash"]
        for number, header in self.blocks.items():
            self.put("eth_getBlockByHash", [header["hash"], False], header)

        self.instrument = b"Synthetic accession instrument\r\nexact bytes\n"
        instrument = _hash_ref(self.instrument, instrument_algorithm)
        self.instrument_ref = instrument
        self.transfer_rows = []
        self._transfer(2, ZERO_ADDRESS, OWNER_A)
        future = self._transfer_value(3, OWNER_A, OWNER_B)
        self.first = self._append_owner("ACCESSION", institutional.NAMES["ACCESSION"],
            _accession(future, instrument, suffix="early"), 2, OWNER_A, None)
        if selected_binding == "same_block_future":
            selected_transfer = self._transfer_value(3, OWNER_A, OWNER_B, log_index=1)
            self.selected = self._append_owner("ACCESSION", institutional.NAMES["ACCESSION"],
                _accession(selected_transfer, instrument), 3, OWNER_A, "EIP712")
            self._transfer(3, OWNER_A, OWNER_B)
        else:
            self._transfer(3, OWNER_A, OWNER_B)
            selected_transfer = self._transfer_value(3, OWNER_A, OWNER_B)
            if selected_binding == "wrong_hash": selected_transfer["transactionHash"] = H("wrong-transaction")
            elif selected_binding == "wrong_owner": selected_transfer["to"] = OWNER_C
            elif selected_binding == "future": selected_transfer = self._transfer_value(4, OWNER_B, OWNER_C)
            self.selected = self._append_owner("ACCESSION", institutional.NAMES["ACCESSION"],
                _accession(selected_transfer, instrument), 3,
                OWNER_C if bad_receipt_owner else OWNER_B, "EIP712")

        self._transfer(4, OWNER_B, OWNER_C)
        later_transfer = self._transfer_value(4, OWNER_B, OWNER_C)
        self.deaccession = self._append_owner("DEACCESSION", institutional.NAMES["DEACCESSION"],
            _deaccession(later_transfer), 4, OWNER_C, "ERC1271")
        self.unsupported = None
        if unsupported:
            # A silent C -> C transfer in a receipt fetched only by the owner
            # reader is the cross-source completeness oracle below.
            self._transfer(5, OWNER_C, OWNER_C)
            self.unsupported = self._append_owner("ACCESSION", "STREAM_VALUATION_V1",
                {"opaque": "uninterpreted historical accession schema"}, 5, unsupported_owner, None)

        self._lane_state()
        self._ownership_state()

    def _transfer(self, block, sender, recipient):
        from .ownership_source import TRANSFER
        log = self.log(block, self.a["core"], [TRANSFER, _topic_address(sender),
            _topic_address(recipient), _topic_uint(TOKEN)], b"")
        self.transfer_rows.append(log)

    def _transfer_value(self, block, sender, recipient, *, log_index=0):
        return {"chainId": self.a["chainId"], "core": self.a["core"], "tokenId": str(TOKEN),
            "blockNumber": str(block), "transactionHash": H("tx" + str(block)), "logIndex": str(log_index),
            "from": sender, "to": recipient}

    def _append_owner(self, family, schema, value, block, author, relayed):
        raw = dumps(value); record_type = schema_id(family)
        lane = [row for row in getattr(self, "typed_rows", []) if row[1][0] == record_type]
        record = (record_type, subject_id("token", self.a["chainId"], self.a["core"], "0", token_id=str(TOKEN)),
            schema_id(schema), (1, hex_bytes(keccak256(raw)), institutional.JCS_ID),
            "ipfs://synthetic-owner-record", raw, 1)
        receipt = [TOKEN, author, 100 + block, len(lane), ZERO, relayed is not None, ZERO,
            0, 0, keccak256(institutional.SCHEMAS.get(family, dumps({"opaque": True}))),
            keccak256(institutional.JCS_BYTES), schema_id("DIRECT" if relayed is None else relayed), ZERO]
        if relayed is None:
            bundle = encode(("bytes32", "address", "bytes32"), (schema_id("DIRECT"), author, keccak256(raw)))
        else:
            receipt[7], receipt[8] = 1000 + len(getattr(self, "typed_rows", [])), 1000
            body = owner_wire.signed_words(record, receipt); saved_domain = owner_wire.domain(int(self.a["chainId"]), self.a["host"])
            words = tuple("0x" + body[i:i + 32].hex() for i in range(0, len(body), 32))
            signature = b"\x12" * 65 if relayed == "EIP712" else b"synthetic ERC1271 witness"
            bundle = encode(("bytes32", ("bytes32",) * 14, "bytes"), (saved_domain, words, signature))
            receipt[6] = keccak256(b"\x19\x01" + hex_bytes(saved_domain) + hex_bytes(keccak256(body)))
        receipt[12] = keccak256(bundle)
        generic = (record_type, record[1], record[3], record[4], record[2], receipt[11],
            (1, hex_bytes(receipt[12]), RAW_BYTES), record[6])
        digest = generic_hash(int(self.a["chainId"]), self.a["host"], self.a["core"], TOKEN, author, generic)
        previous = lane[-1][2][4] if lane else ZERO
        receipt[4] = record_chain(self.a["chainId"], self.a["host"], str(TOKEN), record_type,
            previous, digest, str(receipt[3]))
        row = (digest, record, tuple(receipt), bundle)
        if not hasattr(self, "typed_rows"): self.typed_rows = []
        self.typed_rows.append(row)
        pointer = A(100 + len(self.typed_rows))
        self.call("ownerRecord(bytes32)", (owner_wire.OWNER_RECORD, owner_wire.RECEIPT),
            (record, tuple(receipt)), ("bytes32",), (digest,))
        self.call("ownerRecordSignatureBundle(bytes32)", ("address", "bytes"), (pointer, bundle),
            ("bytes32",), (digest,))
        self.put("eth_getCode", [pointer, {"blockHash": self.a["blockHash"], "requireCanonical": True}],
            "0x00" + bundle.hex())
        self.call("recordHashAt(uint256,bytes32,uint256)", ("bytes32",), (digest,),
            ("uint256", "bytes32", "uint256"), (TOKEN, record_type, receipt[3]))
        if relayed:
            self.call("isOwnerRecordNonceUsed(address,uint256)", ("bool",), (True,),
                ("address", "uint256"), (author, receipt[7]))
        self.log(block, self.a["host"], [owner_wire.RECORD_EVENT, _topic_uint(TOKEN), record_type,
            _topic_address(author)], encode((owner_wire.OWNER_RECORD, "bytes32", "bytes32", "bool", "uint16"),
                (record, digest, receipt[4], receipt[5], 1)))
        return digest

    def _lane_state(self):
        rows = getattr(self, "typed_rows", [])
        self.rows = rows
        for name in owner_wire.FIXED_TYPES:
            record_type = schema_id(name); lane = [row for row in rows if row[1][0] == record_type]
            self.call("recordChainHash(uint256,bytes32)", ("bytes32", "uint64"),
                (lane[-1][2][4] if lane else ZERO, len(lane)), ("uint256", "bytes32"), (TOKEN, record_type))
            latest = {}
            for digest, _, receipt, _ in lane: latest[receipt[1]] = digest
            for author, digest in latest.items():
                self.call("latestOwnerRecordHashFor(uint256,bytes32,address)", ("bytes32",), (digest,),
                    ("uint256", "bytes32", "address"), (TOKEN, record_type, author))

    def _ownership_state(self):
        self.call("supportsInterface(bytes4)", ("bool",), (True,), ("bytes4",), ("0x80ac58cd",), target=self.a["core"])
        self.call("tokenCollectionIdentity(uint256)", ("bool", "uint256", "uint256", "bool"),
            (True, COLLECTION, 1, False), ("uint256",), (TOKEN,), target=self.a["core"])
        self.call("tokenLifecycle(uint256)", ("uint8",), (2,), ("uint256",), (TOKEN,), target=self.a["core"])
        self.call("ownerOf(uint256)", ("address",), (OWNER_C,), ("uint256",), (TOKEN,), target=self.a["core"])

    def owner_capture(self):
        source = PublicOwnerCatalogSource(dumps(self.a), self); raw = source.snapshot(); transcript = source.transcript()
        return ({"anchor.json": dumps(self.a), "transcript.json": transcript, "snapshot.json": raw},
            {"profileHash": OWNER_PROFILE_HASH, "anchorHash": keccak256(dumps(self.a)),
             "transcriptHash": keccak256(transcript), "snapshotHash": keccak256(raw), "provenance": "synthetic_fixture"})

    def ownership_capture(self):
        anchor = {"profile": OWNERSHIP_PROFILE, "chainId": self.a["chainId"], "blockHash": self.a["blockHash"],
            "blockNumber": self.a["blockNumber"], "timestamp": self.a["timestamp"], "stateRoot": self.a["stateRoot"],
            "environment": self.a["environment"], "deploymentEvidenceHash": self.a["deploymentEvidenceHash"],
            "core": self.a["core"], "coreRuntimeHash": next(p["runtimeHash"] for p in self.a["codePins"]
                if p["address"] == self.a["core"]), "tokenId": str(TOKEN), "collectionId": str(COLLECTION)}
        source = PublicOwnershipSource(dumps(anchor), self); raw = source.snapshot(); transcript = source.transcript()
        return ({"anchor.json": dumps(anchor), "transcript.json": transcript, "snapshot.json": raw},
            {"profileHash": OWNERSHIP_PROFILE_HASH, "anchorHash": keccak256(dumps(anchor)),
             "transcriptHash": keccak256(transcript), "snapshotHash": keccak256(raw), "provenance": "synthetic_fixture"})

    def artifacts(self, *, documents=True):
        owner_files, owner_pins = self.owner_capture(); ownership_files, ownership_pins = self.ownership_capture()
        selection = dumps({"profile": acquisition.PROFILE, "host": self.a["host"],
            "tokenId": str(TOKEN), "accessionRecordHash": self.selected})
        key = keccak256(dumps(self.instrument_ref))
        supplied = {key: self.instrument} if documents else {}
        return owner_files, owner_pins, ownership_files, ownership_pins, selection, supplied


class AcquisitionAccessionTests(unittest.TestCase):
    def compose(self, fixture=None, *, documents=True, disclosure="public"):
        fixture = fixture or JoinedFixture()
        owner_files, owner_pins, ownership_files, ownership_pins, selection, supplied = fixture.artifacts(documents=documents)
        return fixture, acquisition.compose(owner_files, owner_pins, ownership_files, ownership_pins,
            selection, keccak256(selection), disclosure=disclosure, documents=supplied)

    def test_joined_full_histories_direct_eip712_erc1271_and_instrument(self):
        fixture, result = self.compose()
        report = result.report
        self.assertEqual(report["selectedAccession"]["recordHash"], fixture.selected)
        self.assertEqual(report["selectedAccession"]["titleBinding"]["status"], "matched_native_transfer")
        self.assertEqual(report["selectedAccession"]["instrumentEvidence"]["status"], "retained_hash_verified")
        self.assertEqual(report["ownership"]["currentOwner"], OWNER_C)
        self.assertEqual([row["kind"] for row in report["ownership"]["transitions"]],
            ["mint", "transfer", "transfer", "transfer"])
        schemes = {row["record"]["authority"]["signatureScheme"] for row in report["records"]}
        self.assertEqual(schemes, {schema_id("DIRECT"), schema_id("EIP712"), schema_id("ERC1271")})
        self.assertTrue(report["claims"]["historicalReceiptOwnersReconciled"])
        for claim in ("legalTitleProven", "custodyTransferred", "institutionIdentityProven",
                "canonicalPacketEmitted", "actualChainAcceptance"):
            self.assertFalse(report["claims"][claim])
        self.assertFalse(report["items"]["9"]["canonicalPacketCompatible"])
        self.assertEqual(acquisition.verify(result.files, result.manifest_hash), result)

    def test_missing_instrument_is_explicit_and_sha256_bytes_are_supported(self):
        _, missing = self.compose(documents=False)
        self.assertEqual(missing.report["selectedAccession"]["instrumentEvidence"]["status"], "referenced_not_supplied")
        self.assertTrue(any(row["sourcePath"] == "/titleBinding/instrument" for row in missing.report["missingEvidence"]))
        fixture, supplied = self.compose(JoinedFixture(instrument_algorithm="2"))
        self.assertEqual(supplied.report["selectedAccession"]["instrumentEvidence"]["status"], "retained_hash_verified")
        files = dict(supplied.files)
        instrument_path = next(path for path in files if path.startswith("documents/"))
        self.assertEqual(files[instrument_path], fixture.instrument)

    def test_selected_coordinates_chronology_and_historical_owner_fail_closed(self):
        for fixture, message in ((JoinedFixture(selected_binding="wrong_hash"), "TITLE_BINDING"),
                (JoinedFixture(selected_binding="wrong_owner"), "TITLE_BINDING"),
                (JoinedFixture(selected_binding="future"), "TITLE_BINDING"),
                (JoinedFixture(selected_binding="same_block_future"), "TITLE_BINDING"),
                (JoinedFixture(bad_receipt_owner=True), "historical receipt owner")):
            with self.subTest(message=message), self.assertRaisesRegex(MuseumError, message):
                self.compose(fixture)

    def test_unselected_future_binding_and_unsupported_schema_remain_visible(self):
        fixture, result = self.compose()
        by_hash = {row["recordHash"]: row for row in result.report["records"]}
        self.assertEqual(by_hash[fixture.first]["titleBinding"]["status"], "transfer_follows_publication")
        self.assertEqual(by_hash[fixture.unsupported]["interpretation"]["status"], "unsupported")
        self.assertTrue(any(row["recordHash"] == fixture.unsupported for row in result.report["missingEvidence"]))
        source = loads(dict(result.files)["sources/owner/snapshot.json"], maximum=64 * 1024 * 1024)
        self.assertEqual(len(source["lanes"]), len(owner_wire.FIXED_TYPES) + 1)
        self.assertTrue(any(row["recordHash"] == fixture.unsupported for row in source["records"]))

    def test_selected_unknown_schema_is_not_promoted_by_family_or_owner_receipt(self):
        fixture = JoinedFixture(); owner_files, owner_pins, ownership_files, ownership_pins, _, documents = fixture.artifacts()
        selection = dumps({"profile": acquisition.PROFILE, "host": fixture.a["host"],
            "tokenId": str(TOKEN), "accessionRecordHash": fixture.unsupported})
        with self.assertRaisesRegex(MuseumError, "selected original schema/payload unsupported"):
            acquisition.compose(owner_files, owner_pins, ownership_files, ownership_pins, selection,
                keccak256(selection), disclosure="public", documents=documents)

    def test_unsupported_owner_row_still_reconciles_against_complete_transfer_history(self):
        with self.assertRaisesRegex(MuseumError, "historical receipt owner differs"):
            self.compose(JoinedFixture(unsupported_owner=OWNER_B))

    def test_same_transaction_transfer_strictly_precedes_selected_publication(self):
        fixture, result = self.compose()
        selected = result.report["selectedAccession"]
        self.assertEqual((selected["titleBinding"]["declared"]["transactionHash"],
            selected["titleBinding"]["declared"]["logIndex"]), (H("tx3"), "0"))
        self.assertEqual((selected["publication"]["transactionHash"], selected["publication"]["logIndex"]),
            (H("tx3"), "1"))
        self.assertTrue(selected["titleBinding"]["transferPrecedesPublication"])

    def test_owner_receipt_exposes_transfer_omitted_from_ownership_query(self):
        fixture = JoinedFixture(); owner_files, owner_pins, ownership_files, ownership_pins, selection, documents = fixture.artifacts()
        transcript = loads(ownership_files["transcript.json"], maximum=64 * 1024 * 1024)
        for row in transcript["calls"]:
            if row["method"] == "eth_getLogs":
                row["result"] = [log for log in row["result"] if log["transactionHash"] != H("tx5")]
        transcript["calls"] = [row for row in transcript["calls"]
            if not (row["method"] == "eth_getTransactionReceipt" and row["params"] == [H("tx5")])]
        changed = dict(ownership_files, **{"transcript.json": dumps(transcript)})
        changed_pins = dict(ownership_pins, transcriptHash=keccak256(changed["transcript.json"]))
        replay = PublicOwnershipSource(changed["anchor.json"],
            PublicReplayTransport(changed["transcript.json"], changed_pins["transcriptHash"]))
        changed["snapshot.json"] = replay.snapshot(); changed_pins["snapshotHash"] = keccak256(changed["snapshot.json"])
        with self.assertRaisesRegex(MuseumError, "union query/receipt matching logs differ"):
            acquisition.compose(owner_files, owner_pins, changed, changed_pins, selection,
                keccak256(selection), disclosure="public", documents=documents)

    def test_selection_schema_identity_and_document_controls(self):
        fixture = JoinedFixture(); owner_files, owner_pins, ownership_files, ownership_pins, selection, documents = fixture.artifacts()
        def run(raw=selection, docs=documents):
            return acquisition.compose(owner_files, owner_pins, ownership_files, ownership_pins,
                raw, keccak256(raw), disclosure="public", documents=docs)
        for edit in (lambda v: v.update(host=A(99)), lambda v: v.update(tokenId="72"),
                lambda v: v.update(accessionRecordHash=fixture.deaccession), lambda v: v.update(extra=True)):
            value = loads(selection); edit(value); raw = dumps(value)
            with self.subTest(value=value), self.assertRaises(MuseumError): run(raw)
        key, raw = next(iter(documents.items()))
        with self.assertRaisesRegex(MuseumError, "digest"): run(docs={key: raw + b"!"})
        with self.assertRaisesRegex(MuseumError, "unreferenced"): run(docs={H("unused-document"): b"unused"})
        with self.assertRaisesRegex(MuseumError, "public disclosure"):
            acquisition.compose(owner_files, owner_pins, ownership_files, ownership_pins,
                selection, keccak256(selection), disclosure="restricted", documents=documents)

    def test_cross_source_anchor_shared_receipt_and_repeated_result_conflicts_reject(self):
        fixture = JoinedFixture(); owner_files, owner_pins, ownership_files, ownership_pins, selection, documents = fixture.artifacts()
        args = [owner_files, owner_pins, ownership_files, ownership_pins, selection, keccak256(selection)]
        changed = deepcopy(ownership_files); anchor = loads(changed["anchor.json"]); anchor["environment"] = "local_evm_fixture"
        changed["anchor.json"] = dumps(anchor); bad_pins = dict(ownership_pins, anchorHash=keccak256(changed["anchor.json"]))
        replay = PublicOwnershipSource(changed["anchor.json"],
            PublicReplayTransport(changed["transcript.json"], ownership_pins["transcriptHash"]))
        changed["snapshot.json"] = replay.snapshot(); bad_pins["snapshotHash"] = keccak256(changed["snapshot.json"])
        with self.assertRaisesRegex(MuseumError, "source anchors differ"):
            acquisition.compose(owner_files, owner_pins, changed, bad_pins, selection, keccak256(selection),
                disclosure="public", documents=documents)

        # Change a Transfer log only in the owner transcript. It remains
        # irrelevant to that reader's two filters, while the duplicated full
        # receipt now conflicts with the ownership transcript at the join.
        changed = deepcopy(owner_files); transcript = loads(changed["transcript.json"], maximum=64 * 1024 * 1024)
        target = H("tx3")
        for row in transcript["calls"]:
            if row["method"] == "eth_getTransactionReceipt" and row["params"] == [target]:
                row["result"]["logs"][0]["address"] = A(99)
        changed["transcript.json"] = dumps(transcript)
        changed_pins = dict(owner_pins, transcriptHash=keccak256(changed["transcript.json"]))
        replay = PublicOwnerCatalogSource(changed["anchor.json"],
            PublicReplayTransport(changed["transcript.json"], changed_pins["transcriptHash"]))
        changed["snapshot.json"] = replay.snapshot(); changed_pins["snapshotHash"] = keccak256(changed["snapshot.json"])
        with self.assertRaisesRegex(MuseumError, "shared RPC response differs"):
            acquisition.compose(changed, changed_pins, ownership_files, ownership_pins, selection,
                keccak256(selection), disclosure="public", documents=documents)

    def test_offline_reconstruction_and_rehashed_derived_tamper_reject(self):
        _, result = self.compose()
        files = dict(result.files)
        with patch("socket.socket", side_effect=AssertionError("offline acquisition replay")):
            self.assertEqual(acquisition.verify(result.files, result.manifest_hash), result)
        report = loads(files["acquisition/report.json"], maximum=64 * 1024 * 1024)
        report["claims"]["legalTitleProven"] = True
        files["acquisition/report.json"] = dumps(report)
        manifest = loads(files["manifest.json"], maximum=1048576)
        manifest["files"] = [acquisition.base._ref(path, raw) for path, raw in sorted(files.items())
            if path != "manifest.json"]
        files["manifest.json"] = dumps(manifest)
        with self.assertRaisesRegex(MuseumError, "source reconstruction differs"):
            acquisition.verify(files.items(), keccak256(files["manifest.json"]))

    def test_source_triplets_pins_and_selection_bounds_fail_before_derivation(self):
        fixture = JoinedFixture(); owner_files, owner_pins, ownership_files, ownership_pins, selection, documents = fixture.artifacts()
        with self.assertRaisesRegex(MuseumError, "source triplet"):
            acquisition.compose({k: v for k, v in owner_files.items() if k != "snapshot.json"}, owner_pins,
                ownership_files, ownership_pins, selection, keccak256(selection), disclosure="public", documents=documents)
        with self.assertRaisesRegex(MuseumError, "source pin"):
            acquisition.compose(owner_files, dict(owner_pins, snapshotHash=H("wrong")), ownership_files,
                ownership_pins, selection, keccak256(selection), disclosure="public", documents=documents)
        with self.assertRaisesRegex(MuseumError, "selection pin"):
            acquisition.compose(owner_files, owner_pins, ownership_files, ownership_pins, selection,
                H("wrong"), disclosure="public", documents=documents)


if __name__ == "__main__":
    unittest.main()
