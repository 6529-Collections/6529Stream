"""Synthetic supplied-reference controls, never native or institutional evidence."""
import copy
import re
import unittest

from jsonschema import Draft202012Validator

from . import acquisition_packet_v2 as v2
from . import genesis_dossier_profile as v1
from tools.museum.canonical import dumps, keccak256, loads


def packet():
    value = copy.deepcopy(v1.examples()["acquisition-packet.json"])
    value.update(schema=v2.PACKET, version=2)
    return value


def owner_record(value, *, scheme="DIRECT"):
    source = value["sourceState"]; transfer = value["ownershipProvenance"]["transfers"][0]
    bundle_hash = v1._h("original signature bundle bytes")
    receipt = {"tokenId": source["tokenId"], "owner": transfer["to"], "recordedAt": "900", "recordIndex": "0",
        "recordChainHash": v1._h("owner chain"), "relayed": scheme != "DIRECT",
        "authorizationDigest": v1.ZERO if scheme == "DIRECT" else v1._h("authorization digest"),
        "nonce": "0" if scheme == "DIRECT" else "17", "deadline": "0" if scheme == "DIRECT" else "901",
        "schemaDefinitionHash": v1._h("original accession definition"),
        "canonicalizationDefinitionHash": v1._h("original JCS definition"),
        "signatureScheme": keccak256(scheme.encode()), "signatureBundleHash": bundle_hash}
    provenance = {key: v1._h(key) for key in v2.PROVENANCE_FIELDS}
    provenance.update(ownerSourceProfileHash=v2.OWNER_SOURCE_PROFILE_HASH,
        ownershipSourceProfileHash=v2.OWNERSHIP_SOURCE_PROFILE_HASH, signatureBundleBytesHash=bundle_hash)
    authority = {"kind": "native_owner_receipt", "version": "1", "receipt": receipt,
        "publication": {"blockHash": v1._h("original publication block"), "blockNumber": "90",
            "transactionHash": v1._h("original publication transaction"), "transactionIndex": "0", "logIndex": "0"},
        "ownerState": {"transferIndex": "0", "transfer": {**copy.deepcopy(transfer),
            "blockHash": v1._h("original mint block"), "transactionIndex": "0"}, "sourceBlockHash": source["blockHash"],
            "sourceBlockTimestamp": "1000"},
        "provenance": provenance}
    return {"recordHash": v1._h("native owner accession"), "host": "0x" + "55" * 20,
        "subjectId": source["subjectId"], "subjectKind": "token", "recordType": keccak256(b"ACCESSION"),
        "schemaId": keccak256(b"STREAM_ACCESSION_V1"), "signer": transfer["to"], "recordedBlock": "90",
        "authority": authority}


def add_owner_head(value, record):
    receipt = record["authority"]["receipt"]
    head = {"lane": "owner", "host": record["host"], "scopeKey": receipt["tokenId"],
        "recordType": record["recordType"], "count": str(int(receipt["recordIndex"]) + 1),
        "headHash": receipt["recordChainHash"]}
    value["recordChainHeads"].append(head)
    value["recordChainHeads"].sort(key=v1._head_key)
    return head


def with_owner(*, scheme="DIRECT", title=False):
    value = packet(); record = owner_record(value, scheme=scheme)
    add_owner_head(value, record)
    value["legalInstrument"] = {"status": "recorded", "instrument": v1._reference("instrument"), "accession": record}
    if title:
        transfer = value["ownershipProvenance"]["transfers"][0]
        value["ownershipProvenance"]["titleBindings"] = [{"record": copy.deepcopy(record), "mode": "TITLE_BINDING",
            "transferIndex": "0", "transactionHash": transfer["transactionHash"], "from": transfer["from"],
            "to": transfer["to"], "instrument": copy.deepcopy(value["legalInstrument"]["instrument"])}]
    return value


class AcquisitionPacketV2Tests(unittest.TestCase):
    def reject(self, value, message=None):
        with self.assertRaises(v1.DossierError) as caught: v2.validate(dumps(value))
        if message: self.assertIn(message, str(caught.exception))

    def test_full_v2_legacy_references_remain_exact_and_v1_rejects_v2(self):
        value = packet()
        self.assertEqual(v2.validate(dumps(value)), value)
        original = v1.examples()["acquisition-packet.json"]
        self.assertEqual(v1.validate(v1.PACKET, dumps(original)), original)
        with self.assertRaises(v1.DossierError): v1.validate(v1.PACKET, dumps(value))
        self.reject(original)
        value = with_owner(); value.update(schema=v1.PACKET, version=1)
        with self.assertRaises(v1.DossierError): v1.validate(v1.PACKET, dumps(value))

    def test_owner_legal_fragment_and_both_allowed_slots_preserve_all_receipt_fields(self):
        for scheme in ("DIRECT", "EIP712", "ERC1271"):
            value = with_owner(scheme=scheme, title=True)
            with self.subTest(scheme=scheme):
                self.assertEqual(v2.validate(dumps(value)), value)
                fragment = value["legalInstrument"]
                self.assertEqual(v2.validate_legal_instrument(dumps(fragment), value["sourceState"]), fragment)
                receipt = fragment["accession"]["authority"]["receipt"]
                self.assertEqual(tuple(receipt), v2.RECEIPT_FIELDS)
                self.assertNotIn("authorityClass", fragment["accession"])
        value = packet()
        self.assertEqual(v2.validate_legal_instrument(dumps(value["legalInstrument"]), value["sourceState"]), value["legalInstrument"])

    def test_exact_definitions_are_additive_and_original_schema_hashes_fixed(self):
        old, new = v1.definitions(), v2.definitions()
        changed = {"packet", "legalInstrument", "titleBinding"}
        for name in old.keys() - changed: self.assertEqual(new[name], old[name], name)
        self.assertEqual(new["record"], old["record"])
        for name, expected in ((v1.PACKET, v2.V1_PACKET_SCHEMA_HASH), (v1.OBJECT, v2.V1_OBJECT_SCHEMA_HASH)):
            self.assertEqual(keccak256(v1.documents()[name]), expected)
            self.assertEqual(keccak256((v1.ROOT / "schemas/records" / (name + ".json")).read_bytes()), expected)
        from tools.museum import public_owner_catalog_source as owner, public_ownership_source as ownership
        self.assertEqual(owner.PROFILE_HASH, v2.OWNER_SOURCE_PROFILE_HASH)
        self.assertEqual(ownership.PROFILE_HASH, v2.OWNERSHIP_SOURCE_PROFILE_HASH)
        for raw in v2.schema_document_bytes().values(): Draft202012Validator.check_schema(loads(raw, maximum=v2.MAX_BYTES))
        self.assertEqual(set(v2.documents()), {v2.PACKET, v2.LEGAL_INSTRUMENT, v2.PROFILE})
        self.assertNotIn("schemas/records/" + v1.PACKET + ".json", v2.outputs())
        for path, raw in v2.outputs().items(): self.assertEqual((v2.ROOT / path).read_bytes(), raw)

    def test_named_receipt_order_and_widths_match_native_interface(self):
        source = (v1.ROOT / "smart-contracts/interfaces/stream/metadata/IStreamOwnerRecords.sol").read_text(encoding="utf-8")
        body = re.search(r"struct Receipt\s*\{(.*?)\}", source, re.S)[1]
        fields = [tuple(row.strip().split()) for row in body.split(";") if row.strip()]
        self.assertEqual(tuple(name for _, name in fields), v2.RECEIPT_FIELDS)
        defs = v2.definitions()
        for kind, name in fields:
            field = defs["nativeOwnerReceipt"]["properties"][name]
            if kind.startswith("uint"): self.assertEqual(field, v1.ref(kind))
            elif kind == "bool": self.assertEqual(field, {"type": "boolean"})

    def test_owner_variant_cannot_escape_to_artist_general_rights_or_other_owner_roles(self):
        value = with_owner(); record = value["legalInstrument"]["accession"]
        for path in (("tombstone",), ("conservation", "artistIntent"), ("attribution", "binding"),
                ("attribution", "sanction"), ("attribution", "personhood"), ("conditionReports", "owner")):
            wrong = copy.deepcopy(value); target = wrong
            for key in path[:-1]: target = target[key]
            target[path[-1]] = {"status": "present", "record": copy.deepcopy(record)}
            with self.subTest(path=path): self.reject(wrong)
        wrong = copy.deepcopy(value)
        wrong["rights"]["token"] = {"record": copy.deepcopy(record), "grants": dict(wrong["rights"]["effectiveGrants"])}
        self.reject(wrong)

    def test_closed_authority_receipt_provenance_and_wrong_source_profiles_rejected(self):
        edits = [lambda r: r.update(authorityClass="1"), lambda r: r["authority"].update(kind="artist"),
            lambda r: r["authority"].update(version=1), lambda r: r["authority"]["receipt"].update(digest=v1.ZERO),
            lambda r: r["authority"]["provenance"].update(originalRecordHash=r["recordHash"]),
            lambda r: r["authority"]["provenance"].update(ownerSourceProfileHash=v1._h("old-profile")),
            lambda r: r["authority"]["provenance"].update(ownershipSourceProfileHash=v1._h("other-profile"))]
        for edit in edits:
            wrong = with_owner(); edit(wrong["legalInstrument"]["accession"])
            with self.subTest(edit=edit): self.reject(wrong)

    def test_source_subject_signer_receipt_timestamp_and_bundle_hash_joins(self):
        edits = [lambda r: r.update(subjectId=v1._h("wrong-subject")),
            lambda r: r.update(signer="0x" + "99" * 20),
            lambda r: r.update(recordedBlock="89"),
            lambda r: r["authority"]["receipt"].update(tokenId="124"),
            lambda r: r["authority"]["receipt"].update(recordedAt="1001"),
            lambda r: r["authority"]["ownerState"].update(sourceBlockHash=v1._h("wrong-source")),
            lambda r: r["authority"]["ownerState"].update(sourceBlockTimestamp="1001"),
            lambda r: r["authority"]["ownerState"].update(sourceBlockTimestamp="899"),
            lambda r: r["authority"]["provenance"].update(signatureBundleBytesHash=v1._h("different-bundle"))]
        for edit in edits:
            value = with_owner(); edit(value["legalInstrument"]["accession"])
            with self.subTest(edit=edit):
                self.reject(value)
                with self.assertRaises(v1.DossierError): v2.validate_legal_instrument(dumps(value["legalInstrument"]), value["sourceState"])

    def test_direct_and_relayed_rules_preserve_original_deadline(self):
        for scheme, changes in (("DIRECT", {"nonce": "1"}), ("DIRECT", {"deadline": "1"}),
                ("DIRECT", {"authorizationDigest": v1._h("digest")}), ("DIRECT", {"signatureScheme": keccak256(b"EIP712")}),
                ("EIP712", {"authorizationDigest": v1.ZERO}), ("ERC1271", {"deadline": "899"}),
                ("ERC1271", {"signatureScheme": keccak256(b"DIRECT")})):
            value = with_owner(scheme=scheme); value["legalInstrument"]["accession"]["authority"]["receipt"].update(changes)
            with self.subTest(scheme=scheme, changes=changes): self.reject(value, "receipt")
        # An expired-at-examination authorization remains an original valid receipt.
        value = with_owner(scheme="ERC1271")
        self.assertLess(int(value["legalInstrument"]["accession"]["authority"]["receipt"]["deadline"]),
            int(value["sourceState"]["examinedAt"]))
        v2.validate(dumps(value))

    def test_same_transaction_and_different_transaction_same_block_ordering(self):
        for transaction_index in ("0", "1"):
            value = with_owner(); authority = value["legalInstrument"]["accession"]["authority"]
            transfer = authority["ownerState"]["transfer"]; publication = authority["publication"]
            publication.update(blockNumber=transfer["blockNumber"], blockHash=transfer["blockHash"],
                transactionIndex=transaction_index, logIndex="2")
            if transaction_index == "0": publication["transactionHash"] = transfer["transactionHash"]
            value["legalInstrument"]["accession"]["recordedBlock"] = transfer["blockNumber"]
            v2.validate(dumps(value))
            for field, bad in (("logIndex", "1"), ("blockHash", v1._h("different-block")),
                    ("transactionIndex", "2" if transaction_index == "0" else "0")):
                wrong = copy.deepcopy(value); wrong["legalInstrument"]["accession"]["authority"]["publication"][field] = bad
                with self.subTest(index=transaction_index, field=field): self.reject(wrong)

    def test_full_packet_owner_state_joins_last_prior_transfer_without_rewriting_title_binding(self):
        value = with_owner(title=True); first = value["ownershipProvenance"]["transfers"][0]
        later = {"from": first["to"], "to": first["to"], "blockNumber": "85",
            "transactionHash": v1._h("owner self-transfer"), "logIndex": "0"}
        value["ownershipProvenance"]["transfers"].append(later)
        self.reject(value, "last transfer")
        for record in (value["legalInstrument"]["accession"], value["ownershipProvenance"]["titleBindings"][0]["record"]):
            record["authority"]["ownerState"].update(transferIndex="1", transfer={**copy.deepcopy(later),
                "blockHash": v1._h("self-transfer-block"), "transactionIndex": "0"})
        v2.validate(dumps(value))
        self.assertEqual(value["ownershipProvenance"]["titleBindings"][0]["transferIndex"], "0")
        # Fragments deliberately have no independent history denominator.
        fragment = with_owner()["legalInstrument"]
        v2.validate_legal_instrument(dumps(fragment), value["sourceState"])

    def test_repeated_native_and_mixed_legacy_records_cannot_disagree(self):
        value = with_owner(title=True)
        value["ownershipProvenance"]["titleBindings"][0]["record"]["authority"]["provenance"]["originalPayloadBytesHash"] = v1._h("conflict")
        self.reject(value, "contradictory repeated")
        value = with_owner(title=True)
        legacy = value["ownershipProvenance"]["titleBindings"][0]["record"]
        del legacy["authority"]; legacy["authorityClass"] = "1"
        self.reject(value, "contradictory repeated")

    def test_native_title_transfer_must_precede_original_publication(self):
        value = with_owner(title=True); old = value["ownershipProvenance"]["transfers"][0]
        future = {"from": old["to"], "to": "0x" + "77" * 20, "blockNumber": "95",
            "transactionHash": v1._h("future-transfer"), "logIndex": "0"}
        value["ownershipProvenance"]["transfers"].append(future)
        value["ownershipProvenance"]["currentOwner"] = future["to"]
        binding = value["ownershipProvenance"]["titleBindings"][0]
        binding.update(transferIndex="1", **{k: future[k] for k in ("from", "to", "transactionHash")})
        self.reject(value, "title transfer must precede")

    def test_distinct_native_references_share_consistent_block_transaction_and_log_maps(self):
        value = with_owner(title=True)
        first = value["legalInstrument"]["accession"]
        first["authority"]["publication"].update(transactionIndex="3", logIndex="3")
        second = value["ownershipProvenance"]["titleBindings"][0]["record"]
        second.update(recordHash=v1._h("native deaccession"), recordType=keccak256(b"DEACCESSION"),
            schemaId=keccak256(b"STREAM_DEACCESSION_V1"))
        second["authority"]["publication"].update(transactionHash=v1._h("second publication"), transactionIndex="4", logIndex="4")
        second["authority"]["receipt"]["recordChainHash"] = v1._h("deaccession chain")
        add_owner_head(value, second)
        v2.validate(dumps(value))
        edits = [
            (lambda r: r["authority"]["publication"].update(blockHash=v1._h("other block90")), "shared block mapping"),
            (lambda r: r["authority"]["ownerState"]["transfer"].update(blockHash=v1._h("other block80")), "shared block mapping"),
            (lambda r: r["authority"]["publication"].update(transactionHash=first["authority"]["publication"]["transactionHash"]), "shared transaction mapping"),
            (lambda r: r["authority"]["publication"].update(transactionIndex="3"), "shared transaction mapping"),
            (lambda r: r["authority"]["publication"].update(logIndex="3"), "shared block log slot"),
            (lambda r: r["authority"]["publication"].update(transactionIndex="2"), "transaction/log order"),
            (lambda r: r["authority"]["receipt"].update(recordedAt="901"), "shared publication timestamp"),
            (lambda r: r["authority"]["ownerState"].update(sourceBlockTimestamp="999"), "source block timestamp differs across"),
        ]
        for edit, message in edits:
            wrong = copy.deepcopy(value); edit(wrong["ownershipProvenance"]["titleBindings"][0]["record"])
            with self.subTest(message=message): self.reject(wrong, message)
        wrong = copy.deepcopy(value); record = wrong["ownershipProvenance"]["titleBindings"][0]["record"]
        record["recordedBlock"] = "91"
        record["authority"]["publication"].update(blockNumber="91", blockHash=v1._h("block91"))
        record["authority"]["receipt"]["recordedAt"] = "899"
        self.reject(wrong, "block time regresses")
        # A later prior-owner transfer cannot reuse the first publication's log slot.
        wrong = copy.deepcopy(value)
        original = wrong["legalInstrument"]["accession"]["authority"]
        hop = {"from": original["receipt"]["owner"], "to": original["receipt"]["owner"],
            **copy.deepcopy(original["publication"])}
        wrong["ownershipProvenance"]["transfers"].append({k: hop[k] for k in
            ("from", "to", "blockNumber", "transactionHash", "logIndex")})
        wrong["ownershipProvenance"]["titleBindings"][0]["record"]["authority"]["ownerState"].update(
            transferIndex="1", transfer=hop)
        self.reject(wrong, "shared block log slot")

    def test_source_block_publication_timestamp_is_exact_in_fragment_and_packet(self):
        value = with_owner(); record = value["legalInstrument"]["accession"]
        source = value["sourceState"]
        record["recordedBlock"] = source["blockNumber"]
        record["authority"]["publication"].update(blockNumber=source["blockNumber"], blockHash=source["blockHash"])
        self.reject(value, "source-block publication timestamp")
        with self.assertRaisesRegex(v1.DossierError, "source-block publication timestamp"):
            v2.validate_legal_instrument(dumps(value["legalInstrument"]), source)
        record["authority"]["receipt"]["recordedAt"] = record["authority"]["ownerState"]["sourceBlockTimestamp"]
        self.assertEqual(v2.validate(dumps(value)), value)
        self.assertEqual(v2.validate_legal_instrument(dumps(value["legalInstrument"]), source), value["legalInstrument"])
        # Examination may occur later than the pinned source block.
        source["examinedAt"] = "1001"
        value["platformSustainability"]["stateExport"]["ageSeconds"] = "101"
        self.assertEqual(v2.validate(dumps(value)), value)
        self.assertEqual(v2.validate_legal_instrument(dumps(value["legalInstrument"]), source), value["legalInstrument"])
        record["authority"]["receipt"]["recordedAt"] = "1001"
        self.reject(value, "publication source context")
        with self.assertRaisesRegex(v1.DossierError, "publication source context"):
            v2.validate_legal_instrument(dumps(value["legalInstrument"]), source)

    def test_full_packet_native_record_indices_join_matching_heads_only(self):
        value = with_owner(title=True); record = value["legalInstrument"]["accession"]
        matching = next(h for h in value["recordChainHeads"] if h["host"] == record["host"])
        for changes, message in (({"count": "0", "headHash": v1.ZERO}, "head count"),
                ({"headHash": v1._h("different head")}, "last receipt chain"),
                ({"host": "0x" + "56" * 20}, "record head missing")):
            wrong = copy.deepcopy(value)
            head = next(h for h in wrong["recordChainHeads"] if h["host"] == record["host"])
            head.update(changes)
            wrong["recordChainHeads"].sort(key=v1._head_key)
            with self.subTest(changes=changes): self.reject(wrong, message)
        # A non-final original receipt does not pretend to prove missing intermediate records.
        matching.update(count="2", headHash=v1._h("later head"))
        self.assertEqual(v2.validate(dumps(value)), value)
        # Fragment validation deliberately has no supplied head denominator.
        value["recordChainHeads"] = []
        self.assertEqual(v2.validate_legal_instrument(dumps(value["legalInstrument"]), value["sourceState"]), value["legalInstrument"])

    def test_distinct_native_originals_cannot_occupy_one_record_index(self):
        value = with_owner(title=True)
        second = value["ownershipProvenance"]["titleBindings"][0]["record"]
        second["recordHash"] = v1._h("different original at same index")
        second["authority"]["publication"].update(transactionHash=v1._h("later tx"), transactionIndex="1", logIndex="1")
        self.reject(value, "shared record index")
        # A later index with its own final chain and event coordinates is consistent.
        second["authority"]["receipt"].update(recordIndex="1", recordChainHash=v1._h("later native chain"))
        head = next(h for h in value["recordChainHeads"] if h["host"] == second["host"])
        head.update(count="2", headHash=second["authority"]["receipt"]["recordChainHash"])
        self.assertEqual(v2.validate(dumps(value)), value)
        # Coherently swapping indices and final head cannot reverse original publication order.
        wrong = copy.deepcopy(value)
        first = wrong["legalInstrument"]["accession"]
        last = wrong["ownershipProvenance"]["titleBindings"][0]["record"]
        first["authority"]["receipt"]["recordIndex"] = "1"
        last["authority"]["receipt"]["recordIndex"] = "0"
        wrong_head = next(h for h in wrong["recordChainHeads"] if h["host"] == first["host"])
        wrong_head["headHash"] = first["authority"]["receipt"]["recordChainHash"]
        self.reject(wrong, "record index publication order")
        # Supplied originals may omit intermediate indices without implying complete history.
        second["authority"]["receipt"]["recordIndex"] = "3"
        head["count"] = "4"
        self.assertEqual(v2.validate(dumps(value)), value)

    def test_canonical_bytes_unknown_fields_and_native_integer_widths(self):
        value = with_owner()
        for raw in (dumps(value) + b"\n", b'{"version":2,"version":2}', b" " * (v2.MAX_BYTES + 1)):
            with self.assertRaises(v1.DossierError): v2.validate(raw)
        for name, bad in (("tokenId", str(1 << 256)), ("recordIndex", str(1 << 64)), ("recordedAt", "01")):
            wrong = copy.deepcopy(value); wrong["legalInstrument"]["accession"]["authority"]["receipt"][name] = bad
            with self.subTest(name=name): self.reject(wrong)
        wrong = copy.deepcopy(value); wrong["legalInstrument"]["accession"]["authority"]["publication"]["logIndex"] = str(1 << 32)
        self.reject(wrong)


if __name__ == "__main__": unittest.main()
