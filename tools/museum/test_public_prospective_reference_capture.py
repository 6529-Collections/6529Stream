"""Concrete synthetic capture/replay controls; no native or browser execution."""
from contextlib import redirect_stdout
from copy import deepcopy
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import public_prospective_reference_capture as capture
from .bagit import read_tree,write_tree
from .canonical import MuseumError,dumps,hex_bytes,keccak256,loads
from .public_history_rpc import PublicRpcTransport
from .test_public_prospective_reference_source import PublicProspectiveReferenceFixture


class PublicProspectiveReferenceCaptureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture=PublicProspectiveReferenceFixture(); adapter=cls.fixture.source()
        cls.snapshot_raw=adapter.snapshot(); cls.snapshot=loads(cls.snapshot_raw,maximum=capture.MAX_BYTES)
        transcript=adapter.transcript()
        cls.inputs=(adapter.anchor_bytes,keccak256(adapter.anchor_bytes),capture._source().PROFILE_HASH,transcript,keccak256(transcript))
        cls.result=capture.replay(*cls.inputs,provenance="synthetic_fixture",disclosure="public")

    @staticmethod
    def repin(files):
        files=dict(files);m=loads(files["manifest.json"],maximum=capture.MAX_MANIFEST)
        m["files"]=[capture.base._ref(p,b) for p,b in sorted(files.items()) if p!="manifest.json"]
        files["manifest.json"]=dumps(m);return files,keccak256(files["manifest.json"])

    def test_exact_original_payload_environment_script_html_execution_and_definitions(self):
        files=dict(self.result.files);r=self.snapshot["records"][0]
        self.assertEqual(files["source/anchor.json"],self.inputs[0]);self.assertEqual(files["source/transcript.json"],self.inputs[3])
        self.assertEqual(files["source/snapshot.json"],self.snapshot_raw)
        for file,key in (("payload.abi","payloadHex"),("publication.abi","publicationAbiHex"),("environment.json","environmentHex")):
            self.assertEqual(files["prospective/records/000/"+file],hex_bytes(r[key]))
        self.assertEqual(files["prospective/records/000/script.js"],hex_bytes(r["originalSource"][15]))
        self.assertEqual(files["prospective/records/000/captures/0.html"],hex_bytes(r["captures"][0]["animationHTMLHex"]))
        self.assertEqual(files["prospective/records/000/captures/0.abi"],hex_bytes(r["captures"][0]["executionHex"]))
        for d in self.snapshot["definitions"]:
            self.assertEqual(files["definitions/native/"+d["documentId"][2:]+".json"],hex_bytes(d["payloadHex"]))

    def test_empty_supersession_current_replacement_and_raised_gas_are_distinct(self):
        for mode,raised in (("empty",False),("superseded",False),("current_replaced",False),("two_vectors",False),("baseline",True)):
            f=PublicProspectiveReferenceFixture(mode,raised=raised);a=f.source();raw=a.snapshot();transcript=a.transcript()
            result=capture.replay(a.anchor_bytes,keccak256(a.anchor_bytes),self.inputs[2],transcript,keccak256(transcript),provenance="synthetic_fixture",disclosure="public")
            with self.subTest(mode=mode,raised=raised):
                self.assertEqual(dict(result.files)["source/snapshot.json"],raw)
                self.assertEqual(capture.verify(result.files,result.manifest_hash).files,result.files)
                if mode=="current_replaced":self.assertEqual(result.report["currentSource"]["status"],"not_evaluated")
                if raised:self.assertNotEqual(result.report["dependencies"][-3:],result.report["records"][0]["originalDependencies"][-3:])

    def test_native_execution_and_archive_authority_are_never_promoted(self):
        self.assertEqual(self.result.report["provenance"],"synthetic_fixture")
        for key in ("historicalCurrentPairReplayed","browserExecutionProven","zipMembershipVerified","postMintReferenceProven",
                "institutionalAcceptance","runtimeArtifactAuthenticated","nativeRuntimeAcceptance","sourceConsensusVerified","actualChainAcceptance","completeCanonicalPacket"):
            self.assertFalse(self.result.report["claims"][key],key)
        self.assertFalse(self.result.report["canonicalPacketCompatible"])

    def test_rehashed_original_and_derived_bytes_require_exact_replay(self):
        for path in ("source/snapshot.json","prospective/records/000/payload.abi","prospective/records/000/script.js",
                "prospective/records/000/captures/0.abi","prospective/currentSource.json","caller-extra.json"):
            files=dict(self.result.files);files[path]=files.get(path,b"")+b" "
            files,digest=self.repin(files)
            with self.subTest(path=path),self.assertRaisesRegex(MuseumError,"reconstruction differs"):
                capture.verify(files,digest)

    def test_closed_manifest_and_wrong_external_pins(self):
        for field,value in (("mode","public_attribution_capture"),("profileHash",keccak256(b"other")),("version","2"),("extra",True)):
            files=dict(self.result.files);m=loads(files["manifest.json"],maximum=capture.MAX_MANIFEST)
            m[field]=value;files["manifest.json"]=dumps(m)
            with self.subTest(field=field),self.assertRaisesRegex(MuseumError,"closed manifest"):
                capture.verify(files,keccak256(files["manifest.json"]))
        for index in (1,2,4):
            args=list(self.inputs);args[index]=keccak256(b"wrong pin")
            with self.subTest(pin=index),self.assertRaises(MuseumError):capture.replay(*args,provenance="synthetic_fixture",disclosure="public")
        with self.assertRaises(MuseumError):capture.verify(self.result.files,keccak256(b"wrong manifest"))

    def test_rehashed_transcript_cannot_omit_append_or_change_chain(self):
        for mode in ("missing","extra","chain"):
            transcript=loads(self.inputs[3],maximum=capture.MAX_BYTES)
            if mode=="missing":transcript["calls"].pop()
            elif mode=="extra":transcript["calls"].append(deepcopy(transcript["calls"][-1]))
            else:next(row for row in transcript["calls"] if row["method"]=="eth_chainId")["result"]="0x1"
            files=dict(self.result.files);files["source/transcript.json"]=dumps(transcript);files,digest=self.repin(files)
            with self.subTest(mode=mode),self.assertRaises(MuseumError):capture.verify(files,digest)

    def test_closed_anchor_provenance_and_runtime_pins_are_rechecked(self):
        for mode in ("extra","runtime","provenance"):
            anchor=loads(self.inputs[0],maximum=capture.MAX_MANIFEST)
            if mode=="extra":anchor["callerLatest"]=True
            elif mode=="runtime":next(p for p in anchor["codePins"] if p["address"]==anchor["host"])["runtimeHash"]=keccak256(b"wrong code")
            raw=dumps(anchor)
            with self.subTest(mode=mode),self.assertRaises(MuseumError):
                capture.replay(raw,keccak256(raw),self.inputs[2],self.inputs[3],self.inputs[4],
                    provenance="trusted_rpc" if mode=="provenance" else "synthetic_fixture",disclosure="public")

    def test_mocked_real_transport_capture_retains_no_endpoint(self):
        anchor=loads(self.inputs[0],maximum=capture.MAX_MANIFEST);anchor["runtimeAdmission"]["kind"]="externally_admitted_runtime";raw=dumps(anchor)
        endpoint="https://example.invalid/private-prospective-path?key=synthetic-key"
        with patch.object(PublicRpcTransport,"request",side_effect=self.fixture.request),patch("socket.socket",side_effect=AssertionError("synthetic only")):
            result=capture.capture(raw,keccak256(raw),self.inputs[2],PublicRpcTransport(endpoint),disclosure="public")
        self.assertEqual(result.report["provenance"],"trusted_rpc")
        for _,body in result.files:
            self.assertNotIn(b"private-prospective-path",body);self.assertNotIn(b"synthetic-key",body)
        self.assertFalse(result.report["claims"]["actualChainAcceptance"])

    def test_disclosure_and_closed_runtime_admission_precede_path_or_endpoint_reads(self):
        with patch.object(capture,"_source",side_effect=AssertionError("read before disclosure")),self.assertRaisesRegex(MuseumError,"public disclosure"):
            capture.replay(*self.inputs,provenance="synthetic_fixture",disclosure="restricted")
        with TemporaryDirectory() as tmp:
            root=Path(tmp);anchor=root/"anchor.json";anchor.write_bytes(self.inputs[0])
            original=capture.os.environ.get
            def guard(name,default=None):
                if name=="PROSPECTIVE_TEST_RPC":raise AssertionError("environment read before runtime admission")
                return original(name,default)
            with patch.object(capture.os.environ,"get",side_effect=guard),self.assertRaisesRegex(MuseumError,"runtime admission"):
                capture.main(["capture","--anchor",str(anchor),"--anchor-hash",self.inputs[1],"--source-profile-hash",self.inputs[2],
                    "--rpc-env","PROSPECTIVE_TEST_RPC","--disclosure","public","--output",str(root/"out")])
            with patch.object(capture,"_read_input",side_effect=AssertionError("path read before public")),self.assertRaisesRegex(MuseumError,"public disclosure"):
                capture.main(["capture","--anchor",str(anchor),"--anchor-hash",self.inputs[1],"--source-profile-hash",self.inputs[2],
                    "--rpc-env","PROSPECTIVE_TEST_RPC","--disclosure","restricted","--output",str(root/"out")])

    def test_bounded_regular_inputs_and_offline_cli_new_destination(self):
        with TemporaryDirectory() as tmp:
            root=Path(tmp);anchor=root/"anchor.json";transcript=root/"transcript.json";out=root/"out"
            anchor.write_bytes(self.inputs[0]);transcript.write_bytes(self.inputs[3])
            with self.assertRaises(MuseumError):capture._read_input(root,1)
            with self.assertRaises(MuseumError):capture._read_input(anchor,1)
            with patch.object(Path,"is_symlink",return_value=True),self.assertRaises(MuseumError):capture._read_input(anchor,len(self.inputs[0]))
            args=["replay","--anchor",str(anchor),"--anchor-hash",self.inputs[1],"--source-profile-hash",self.inputs[2],
                "--transcript",str(transcript),"--transcript-hash",self.inputs[4],"--provenance","synthetic_fixture","--disclosure","public","--output",str(out)]
            with redirect_stdout(io.StringIO()),patch("socket.socket",side_effect=AssertionError("offline")):
                capture.main(args);capture.main(["verify",str(out),"--manifest-hash",self.result.manifest_hash])
            self.assertEqual(read_tree(out),dict(self.result.files))
            with self.assertRaisesRegex(MuseumError,"new directory"):capture.main(args)
            self.assertEqual(read_tree(out),dict(self.result.files))

    def test_common_dispatch_reconstructs_every_byte_offline(self):
        from .package_v2 import verify_package
        with TemporaryDirectory() as tmp,patch("socket.socket",side_effect=AssertionError("offline")):
            path=Path(tmp)/"source";write_tree(dict(self.result.files),path)
            self.assertEqual(verify_package(path,self.result.manifest_hash).files,self.result.files)


if __name__=="__main__":unittest.main()
