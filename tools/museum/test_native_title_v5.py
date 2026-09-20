"""Pure title derivation over concrete synthetic replayed native captures."""
from copy import deepcopy
import unittest
from unittest.mock import patch

from ..metadata import acquisition_packet_v5 as packet
from ..metadata import genesis_dossier_profile as legacy
from . import acquisition_packet_v2 as old_assembly
from . import native_title_v5 as title
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id
from .independent_wire import ZERO
from .title_v5_fixture import TitleV5Fixture


class NativeTitleV5Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.preservation, cls.accession = TitleV5Fixture().title_inputs()
        cls.files = dict(cls.accession.files)
        cls.original = loads(dict(cls.preservation.files)["packet/acquisition-packet.json"], maximum=packet.MAX_BYTES)
        cls.result = title.derive(cls.accession, cls.files, cls.accession.manifest_hash, cls.original)

    def derive(self, original=None):
        return title.derive(self.accession, self.files, self.accession.manifest_hash,
            self.original if original is None else original)

    def test_full_packet_validates_and_chosen_instrument_is_unchanged_v2_fragment(self):
        value = self.result["packet"]
        self.assertEqual(packet.validate(dumps(value)), value)
        fragment = old_assembly._fragment(self.accession, self.files, self.accession.manifest_hash, value["sourceState"])
        self.assertEqual(value["legalInstrument"], fragment)
        self.assertEqual(self.result["selectedAccession"], {"recordHash":self.accession.report["selectedAccession"]["recordHash"],
            "selectionBasis":"explicit_original_accession", "canonicalCurrentAccession":False})

    def test_complete_core_transfers_current_owner_and_original_protocol_reference(self):
        ownership = loads(self.files["sources/ownership/snapshot.json"], maximum=title.MAX_BYTES)
        fields = self.result["packet"]["ownershipProvenance"]
        self.assertEqual(fields["transfers"], [{k:r[k] for k in ("from","to","blockNumber","transactionHash","logIndex")}
            for r in ownership["transitions"]])
        self.assertEqual(fields["currentOwner"], ownership["identity"]["owner"])
        self.assertEqual(fields["eventHistorySnapshot"],self.original["ownershipProvenance"]["eventHistorySnapshot"])
        self.assertEqual(self.result["coverage"]["protocolEventArchive"],"supplied_unverified")

    def test_all_supported_original_title_bindings_keep_authority_and_bytes(self):
        expected = {r["recordHash"] for r in self.accession.report["records"]
            if r["interpretation"]["status"]=="typed_historical" and r["titleBinding"]["status"]=="matched_native_transfer"}
        self.assertEqual({r["record"]["recordHash"] for r in self.result["titleBindings"]},expected)
        self.assertGreater(len(expected),1)
        for row in self.result["titleBindings"]:
            record=row["record"];authority=record["authority"];digest=record["recordHash"]
            prefix="records/"+digest[2:];raw=self.files[prefix+"/original.json"]
            original=loads(raw,maximum=title.MAX_BYTES)
            self.assertNotIn("authorityClass",record)
            self.assertEqual((authority["kind"],authority["version"]),("native_owner_receipt","1"))
            self.assertEqual(record["signer"],original["receipt"][1])
            self.assertEqual(authority["receipt"],dict(zip(old_assembly.RECEIPT_FIELDS,original["receipt"],strict=True)))
            self.assertEqual(authority["provenance"]["originalRecordBytesHash"],keccak256(raw))
            self.assertEqual(authority["provenance"]["originalPayloadBytesHash"],keccak256(self.files[prefix+"/payload.bin"]))
            self.assertEqual(authority["provenance"]["signatureBundleBytesHash"],keccak256(self.files[prefix+"/signature-bundle.bin"]))

    def test_all_captured_lane_heads_are_exact_and_other_heads_stay(self):
        owner=loads(self.files["sources/owner/snapshot.json"],maximum=title.MAX_BYTES)
        heads={legacy._head_key(row):row for row in self.result["packet"]["recordChainHeads"]}
        captured=set()
        for lane in owner["lanes"]:
            head={"lane":"owner","host":owner["host"],"scopeKey":self.original["sourceState"]["tokenId"],
                "recordType":lane["recordType"],"headHash":lane["head"],"count":lane["count"]}
            key=legacy._head_key(head);captured.add(key);self.assertEqual(heads[key],head)
        for row in self.original["recordChainHeads"]:
            if legacy._head_key(row) not in captured:self.assertEqual(heads[legacy._head_key(row)],row)

    def test_exact_captured_lane_replaces_old_supplied_head(self):
        owner=loads(self.files["sources/owner/snapshot.json"],maximum=title.MAX_BYTES)
        lane=next(r for r in owner["lanes"] if r["recordType"]==schema_id("ACCESSION"))
        old=deepcopy(self.original)
        head={"lane":"owner","host":owner["host"],"scopeKey":old["sourceState"]["tokenId"],
            "recordType":lane["recordType"],"headHash":ZERO,"count":"0"}
        old["recordChainHeads"]=[r for r in old["recordChainHeads"] if legacy._head_key(r)!=legacy._head_key(head)]+[head]
        old["recordChainHeads"].sort(key=legacy._head_key)
        result=self.derive(old)["packet"]
        actual=next(r for r in result["recordChainHeads"] if legacy._head_key(r)==legacy._head_key(head))
        self.assertEqual((actual["headHash"],actual["count"]),(lane["head"],lane["count"]))

    def test_unrelated_packet_fields_and_inputs_do_not_mutate(self):
        before=dumps(self.original);source_files=dict(self.files)
        with patch("socket.socket",side_effect=AssertionError("pure derivation used network")):
            result=self.derive()["packet"]
        self.assertEqual(dumps(self.original),before)
        self.assertEqual(self.files,source_files)
        for key in self.original:
            if key not in ("legalInstrument","ownershipProvenance","recordChainHeads"):
                self.assertEqual(result[key],self.original[key],key)

    def test_unsupported_and_unmatched_originals_are_unresolved_not_bindings(self):
        supported={r["record"]["recordHash"] for r in self.result["titleBindings"]}
        for row in self.accession.report["records"]:
            if row["interpretation"]["status"]!="typed_historical" or row["titleBinding"]["status"]!="matched_native_transfer":
                self.assertNotIn(row["recordHash"],supported)
                self.assertTrue(any(r.get("recordHash")==row["recordHash"] for r in self.result["unresolved"]))
        self.assertEqual(self.result["coverage"],title.COVERAGE)
        self.assertFalse(self.result["coverage"]["canonicalCurrentAccession"])
        self.assertFalse(self.result["coverage"]["completeItem10"])
        self.assertEqual(self.result["coverage"]["legalTitle"],"not_proven")

    def test_exact_source_state_including_examination_time_is_required(self):
        original=deepcopy(self.original)
        original["sourceState"]["examinedAt"]=str(int(original["sourceState"]["examinedAt"])+1)
        original["conservation"]["context"]["sourceState"]=deepcopy(original["sourceState"])
        export=original["platformSustainability"]["stateExport"]
        export["ageSeconds"]=str(int(original["sourceState"]["examinedAt"])-int(export["exportedAt"]))
        packet.validate(dumps(original))
        with self.assertRaisesRegex(MuseumError,"sourceState differs"):self.derive(original)

    def test_accession_external_pin_original_byte_and_report_mismatch(self):
        with self.assertRaisesRegex(MuseumError,"bytes/pin"):
            title.derive(self.accession,self.files,keccak256(b"wrong pin"),self.original)
        changed=dict(self.files);changed["documents/extra.bin"]=b"extra"
        with self.assertRaisesRegex(MuseumError,"bytes/pin"):
            title.derive(self.accession,changed,self.accession.manifest_hash,self.original)
        changed=dict(self.files);changed["accession/selected.json"]=b"{}"
        with self.assertRaisesRegex(MuseumError,"bytes/pin"):
            title.derive(self.accession,changed,self.accession.manifest_hash,self.original)

    def test_new_head_union_fails_closed_at_unchanged_v5_bound(self):
        original=deepcopy(self.original)
        for index in range(64-len(original["recordChainHeads"])):
            original["recordChainHeads"].append({"lane":"owner","host":"0x"+(61000+index).to_bytes(20,"big").hex(),
                "scopeKey":original["sourceState"]["tokenId"],"recordType":schema_id("unrelated "+str(index)),"headHash":ZERO,"count":"0"})
        original["recordChainHeads"].sort(key=legacy._head_key);packet.validate(dumps(original))
        with self.assertRaisesRegex(MuseumError,"full packet head bound"):self.derive(original)

    def test_immutable_schema_and_source_profiles_are_pinned(self):
        definition=loads(title.PROFILE_BYTES)
        self.assertEqual(definition["reviewedSourceCommit"],title.SOURCE_REVISION)
        self.assertEqual(definition["packetSchemaHash"],packet.PACKET_SCHEMA_HASH)
        self.assertEqual(definition["nativeOwnerAuthorityProfileHash"],title.owner_authority.PROFILE_HASH)
        self.assertEqual(definition["ownerSourceProfileHash"],title.OWNER_PROFILE_HASH)
        self.assertEqual(definition["ownershipSourceProfileHash"],title.OWNERSHIP_PROFILE_HASH)


if __name__=="__main__":unittest.main()
