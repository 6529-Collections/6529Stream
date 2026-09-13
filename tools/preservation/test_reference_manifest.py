"""Independent offline reference consistency controls; no carrier/authority claim."""
import base64
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import zipfile
from tools.metadata import reference_render_profile as p
from tools.preservation.reference_manifest import canonical, validate, kh, sh, png_pixels, capture_bytes, tool_controls, package_bytes
from tools.preservation.reference_archive import inspect

ROOT=Path(__file__).resolve().parents[2]
FIXTURES=ROOT/"test/fixtures/preservation"

def fixture():
    """Declared consistency example; original source/PNG bytes are real retained tool outputs."""
    source=json.loads((FIXTURES/"reference-actual-native-v1.json").read_bytes())
    env=json.loads((FIXTURES/"reference-environment.json").read_bytes())
    h=lambda name:kh(name.encode())
    def cover(label,obj):
        row={k:h(label+k) for k in "artistId arweaveDataRoot checkpointHash contentHash coverageHash firstFamilyRecordHash firstFixityHash firstReceiptHash objectHash profileHash secondFamilyRecordHash secondFixityHash secondReceiptHash sha256Digest".split()}
        row["artistId"]=h("artist");row["objectHash"]=obj;row["byteSize"]="198";return row
    renderer={k:h(k) for k in "context dependencyReadSet presentationProfile rendererCodeHash routerManifestHash routerVersion".split()}
    renderer.update(renderer="0x"+"21"*20,rendererClass="STATIC",version=1)
    sources=[{"role":str(i),"address":"0x"+f"{i+1:02x}"*20,"runtimeHash":h(f"runtime{i}")} for i in range(7)]
    snapshot={k:h("snapshot"+k) for k in "canonicalizationHash inventoryPlan manifestHash profileHash recordHash schemaHash sourceHash".split()};snapshot["revision"]="1"
    v={"acceptanceMode":"BYTE_EXACT","artworkClassification":"STATIC","captureClass":"still","captures":[],"chainId":"31337","collectionId":"1",
       "environment":env,"environmentCoverage":cover("runtime",env["runtimeObjectHash"]),"environmentManifestHash":kh(canonical(env)),"environmentManifestBytes":str(len(canonical(env))),"mintedEver":"2",
       "profileHash":kh(p.canonical(p.documents()[p.PROFILE])),"schemaHash":kh(p.canonical(p.documents()[p.SCHEMA])),"schemaId":kh(p.SCHEMA.encode()),
       "renderer":renderer,"rendererCatalogHash":kh(canonical(renderer)),"rendererCatalogId":h("fixed renderer declaration"),"sources":sources,"snapshot":snapshot,
       "publication":{"authorizationClass":"3","effectiveAt":"1000","grantRevision":"1","revision":"1","predecessor":"0x"+"00"*32,"reasonHash":h("reason"),"referenceId":h("reference"),"manifestURI":"","recorder":"0x"+"22"*20},"version":1}
    v["subject"]=kh(bytes.fromhex(h("6529STREAM_SUBJECT_COLLECTION_V1")[2:])+int(v["chainId"]).to_bytes(32,"big")+int(sources[0]["address"],16).to_bytes(32,"big")+(1).to_bytes(32,"big"))
    for i in (1,2):
        src=source[f"capture{i}"];html=bytes.fromhex(src["html"][2:]);cov=cover(str(i),h(f"png{i}"))
        cov.update({k:src[k] for k in ("sha256Digest","contentHash","arweaveDataRoot")});cov["byteSize"]=str(src["byteSize"])
        v["captures"].append({"animationHTMLBase64":base64.b64encode(html).decode(),"capturedAt":"1000","collectionSerial":str(i),"tokenId":str(i),"coverage":cov,
          "environmentManifestHash":v["environmentManifestHash"],"htmlBytes":str(len(html)),"htmlHash":kh(html),"metadataJSONHash":h(f"metadata{i}"),"originalCoordinator":"0x"+"23"*20,
          "repeatCaptureSha256":[cov["sha256Digest"]]*2,"seed":"0x"+(77).to_bytes(32,"big").hex(),"sourceSha256":sh(html),"tokenDataBytes":"2","tokenDataHash":kh(b"\x00\xff")})
    return v

class ReferenceManifestTests(unittest.TestCase):
    def setUp(self):self.value=fixture()
    def reject(self):
        with self.assertRaises(Exception):validate(canonical(self.value))
    def env_changed(self):
        raw=canonical(self.value["environment"]);self.value["environmentManifestHash"]=kh(raw);self.value["environmentManifestBytes"]=str(len(raw))
        for c in self.value["captures"]:c["environmentManifestHash"]=kh(raw)
    def test_complete_declared_fixture_and_exact_case_preserved(self):
        got=validate(canonical(self.value));self.assertEqual(got,self.value)
        self.assertEqual(len(got["environment"]["packageFiles"]),364)
        self.assertEqual(len(got["environment"]["platformPrerequisites"]),108)
    def test_missing_unknown_duplicate_and_noncanonical_members(self):
        for kind in range(4):
            v=copy.deepcopy(self.value)
            if kind==0:del v["captures"]
            if kind==1:v["inferredAuthority"]=True
            raw=canonical(v)
            if kind==2:raw=raw[:-1]+b',"version":1}'
            if kind==3:raw+=b"\n"
            with self.assertRaises(Exception):validate(raw)
    def test_only_literal_version_integers_with_rehashed_nested_commitments(self):
        for where in ("root","environment","renderer"):
            self.value=fixture()
            target=self.value if where=="root" else self.value[where]
            target["version"]=1.0
            if where=="environment":self.env_changed()
            if where=="renderer":self.value["rendererCatalogHash"]=kh(canonical(self.value["renderer"]))
            with self.assertRaisesRegex(ValueError,"noninteger JSON number"):
                validate(canonical(self.value))
        original=canonical(fixture())
        for token in (b"1e0",b"1E+0",b"NaN",b"Infinity",b"-Infinity"):
            raw=original.replace(b'"version":1',b'"version":'+token,1)
            with self.assertRaisesRegex(ValueError,"noninteger JSON number"):
                validate(raw)
    def test_wrong_definition_with_other_values_well_formed(self):
        self.value["profileHash"]=kh(b"different supported profile");self.reject()
    def test_subject_does_not_follow_wrong_chain_or_core(self):
        self.value["chainId"]="1";self.reject()
        self.value=fixture();self.value["sources"][0]["address"]="0x"+"ff"*20;self.reject()
    def test_snapshot_grant_is_not_curator_authority(self):
        self.value["publication"]["authorizationClass"]="7";self.reject()
    def test_duplicate_slot_and_zero_fixity_rejected(self):
        row=self.value["captures"][0]["coverage"];row["secondFamilyRecordHash"]=row["firstFamilyRecordHash"];self.reject()
        self.value=fixture();self.value["environmentCoverage"]["firstFixityHash"]="0x"+"00"*32;self.reject()
    def test_dynamic_renderer_with_rehashed_catalog_still_rejected(self):
        self.value["renderer"]["rendererClass"]="DYNAMIC";self.value["rendererCatalogHash"]=kh(canonical(self.value["renderer"]));self.reject()
    def test_wrong_sample_order_count_and_repeat_digest(self):
        self.value["captures"].reverse();self.reject()
        self.value=fixture();self.value["mintedEver"]="3";self.reject()
        self.value=fixture();self.value["captures"][0]["repeatCaptureSha256"][1]=kh(b"different PNG");self.reject()
    def test_full_html_length_and_native_bytes_not_a_descriptor(self):
        self.value["captures"][0]["htmlBytes"]="10";self.reject()
        self.value=fixture();self.value["captures"][0]["animationHTMLBase64"]=base64.b64encode(b"descriptor").decode();self.reject()
    def test_rehashed_windows_reserved_and_case_alias_rows_rejected_offline(self):
        self.value["environment"]["packageFiles"][0]["path"]="CON/file";self.env_changed();self.reject()
        self.value=fixture();rows=self.value["environment"]["packageFiles"]
        row=copy.deepcopy(rows[0]);row["path"]=row["path"].lower();rows.append(row);rows.sort(key=lambda r:r["path"])
        self.env_changed();self.reject()
        for path in ("engine/\u00e9.dll","engine/\u007f.dll"):
            self.value=fixture();self.value["environment"]["packageFiles"][0]["path"]=path
            self.value["environment"]["packageFiles"].sort(key=lambda r:r["path"].encode())
            self.env_changed()
            with self.assertRaisesRegex(ValueError,"relative ASCII path"):
                validate(canonical(self.value))
    def test_zero_byte_nonexecutables_and_nonempty_executable(self):
        self.assertTrue(any(r["byteSize"]=="0" for r in self.value["environment"]["packageFiles"]))
        validate(canonical(self.value))
        for r in self.value["environment"]["packageFiles"]:
            if r["path"]=="engine/chrome.exe":r["byteSize"]="0"
        self.env_changed();self.reject()
    def test_runtime_and_capture_environment_identity_cannot_diverge(self):
        self.value["environment"]["runtimeObjectHash"]=kh(b"replacement runtime");self.env_changed();self.reject()
        self.value=fixture();self.value["captures"][0]["environmentManifestHash"]=kh(b"other environment");self.reject()
    def test_explicit_large_unsigned_and_predecessor_shape(self):
        self.value["publication"]["revision"]="2";self.value["publication"]["predecessor"]=kh(b"prior reference");validate(canonical(self.value))
        self.value["publication"]["effectiveAt"]=str(1<<64);self.reject()
    def test_archived_tool_literal_controls_without_execution(self):
        source=(ROOT/"tools/preservation/reference_capture.py").read_bytes();controls=tool_controls(source)
        self.assertEqual(controls["profile"],"STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1")
        self.assertIn("--disable-gpu",controls["flags"])
        with self.assertRaises(ValueError):tool_controls(source+b"\nFLAGS=('other',)\n")
        with self.assertRaises(ValueError):tool_controls(b"PROFILE=execute_untrusted_code()")
    def test_actual_png_stream_crc_geometry_and_trailing_bytes(self):
        for i in (1,2):
            raw=(FIXTURES/f"reference-token-{i}.png").read_bytes();self.assertEqual(len(png_pixels(raw,64,64)),12352)
            for bad in (raw+b"x",raw[:-1],raw[:40]+bytes([raw[40]^1])+raw[41:]):
                with self.assertRaises(ValueError):png_pixels(bad,64,64)
            with self.assertRaises(ValueError):png_pixels(raw,65,64)

    def test_complete_small_zip_members_and_whole_object_are_independent_checks(self):
        # A miniature transport oracle, expressly not the archived browser package.
        with tempfile.TemporaryDirectory() as directory:
            archive=Path(directory)/"package.zip"
            source=(ROOT/"tools/preservation/reference_capture.py").read_bytes()
            rows=[("PACKAGE.json",b'{"version":1}'),("tool/reference_capture.py",source)]
            with zipfile.ZipFile(archive,"w") as output:
                for name,raw in rows:output.writestr(name,raw)
            actual=inspect(archive)
            value={"environmentCoverage":{"byteSize":actual["byteSize"],"sha256Digest":"0x"+actual["sha256"],"contentHash":"0x"+actual["keccak256"],"arweaveDataRoot":"0x"+actual["arweaveDataRoot"]},
                   "environment":{"toolchainPath":"tool/reference_capture.py","packageFiles":[{"path":name,"byteSize":str(len(raw)),"sha256Digest":sh(raw)} for name,raw in rows]}}
            self.assertEqual(package_bytes(value,archive),tool_controls(source))
            for field in ("sha256Digest","contentHash","arweaveDataRoot"):
                bad=copy.deepcopy(value);bad["environmentCoverage"][field]=kh(b"different whole object")
                with self.assertRaises(ValueError):package_bytes(bad,archive)
            for kind in range(4):
                bad=copy.deepcopy(value);files=bad["environment"]["packageFiles"]
                if kind==0:files.pop(0)
                if kind==1:files.reverse()
                if kind==2:files[0]["sha256Digest"]=kh(b"different member")
                if kind==3:files[0]["byteSize"]="1"
                with self.assertRaises(ValueError):package_bytes(bad,archive)

    def test_capture_report_and_actual_bytes_controls(self):
        # Construct declared reports independently; their acceptance proves consistency only.
        value=self.value;c=value["captures"][0];env=value["environment"]
        controls=tool_controls((ROOT/"tools/preservation/reference_capture.py").read_bytes())
        html=base64.b64decode(c["animationHTMLBase64"])
        metadata=canonical({"animation_url":"data:text/html;base64,"+base64.b64encode(html).decode()})
        c["metadataJSONHash"]=kh(metadata)
        png=(FIXTURES/"reference-token-1.png").read_bytes()
        row=env["packageFiles"][0]
        with tempfile.TemporaryDirectory() as directory:
            base=Path(directory).resolve();runtime=base/"runtime";capture=base/"capture";capture.mkdir()
            metadata_path=base/"metadata.json";metadata_path.write_bytes(metadata)
            (capture/"original.html").write_bytes(html)
            report={"sourceSha256":c["sourceSha256"][2:],"captureSha256":c["coverage"]["sha256Digest"][2:],"engineSha256":env["engineExecutableSha256"][2:],
                "sourceBytes":len(html),"captureBytes":len(png),"browser":{"product":"Chrome/"+env["engineVersion"]},
                "os":{"platform":"win32","machine":"AMD64","version":env["operatingSystemVersion"]},"viewport":{"width":64,"height":64,"deviceScaleFactor":1},
                "profile":controls["profile"],"colorSpace":"srgb","locale":"en-US","timezone":"UTC","command":list(controls["flags"]),"guardsSha256":controls["guardsSha256"],
                "gpu":{"featureStatus":{"gpu_compositing":"disabled_software","rasterization":"disabled_software"},"auxAttributes":{"sandboxed":True}},
                "inspection":{"unsupported":[],"animations":[],"resources":[],"text":"","nodes":["CANVAS","SCRIPT"],"canvas":[{"width":64,"height":64,"x":0,"y":0,"displayWidth":64,"displayHeight":64}],"width":64,"height":64,"ratio":1},
                "loadedModules":[{"path":(runtime/row["path"]).as_posix(),"bytes":int(row["byteSize"]),"sha256":row["sha256Digest"][2:]}]}
            for i in range(2):
                (capture/f"capture-{i}.png").write_bytes(png)
                (capture/f"capture-{i}.json").write_bytes(canonical(report))
            self.assertEqual(capture_bytes(value,0,metadata_path,capture,runtime,controls)["repeatCount"],2)
            mutations=[lambda r:r.update(sourceSha256="00"*32),lambda r:r["command"].append("--no-sandbox"),
                lambda r:r["command"].append(controls["flags"][0]),lambda r:r["inspection"]["resources"].append("https://external.invalid"),
                lambda r:r["inspection"]["canvas"][0].update(width=65),lambda r:r["gpu"]["auxAttributes"].update(sandboxed=False),
                lambda r:r["loadedModules"][0].update(sha256="00"*32),lambda r:r["loadedModules"][0].update(path="C:/unretained.dll"),
                lambda r:r.update(loadedModules=[]),lambda r:r["os"].update(version="different OS")]
            for mutate in mutations:
                bad=copy.deepcopy(report);mutate(bad);(capture/"capture-1.json").write_bytes(canonical(bad))
                with self.assertRaises(ValueError):capture_bytes(value,0,metadata_path,capture,runtime,controls)
            (capture/"capture-1.json").write_bytes(canonical(report))
            (capture/"original.html").write_bytes(html+b" ")
            with self.assertRaises(ValueError):capture_bytes(value,0,metadata_path,capture,runtime,controls)
            (capture/"original.html").write_bytes(html)
            (capture/"capture-1.png").write_bytes((FIXTURES/"reference-token-2.png").read_bytes())
            with self.assertRaises(ValueError):capture_bytes(value,0,metadata_path,capture,runtime,controls)
            (capture/"capture-1.png").write_bytes(png);metadata_path.write_bytes(metadata+b" ")
            with self.assertRaises(ValueError):capture_bytes(value,0,metadata_path,capture,runtime,controls)

if __name__=="__main__":unittest.main()
