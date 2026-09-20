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
from tools.preservation.reference_manifest import canonical, validate, kh, sh, png_pixels, capture_bytes, tool_controls, package_bytes, _checkpoint_commitments
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
    retained_evidence(v)
    return v


def retained_evidence(value, token_ids=None):
    """Synthetic original declarations; actual Core/archival authority is not claimed.

    Tree arithmetic has separate fixed Solidity-compatible vector coverage below.
    Retained leaves have no owner, burned flag or serial field, just as onchain.
    """
    snapshot=json.loads((ROOT/"test/fixtures/metadata/snapshot-native-onchain.json").read_bytes())
    for key in ("chainId","collectionId","subject"):snapshot[key]=value[key]
    snapshot["sources"][:5]=copy.deepcopy(value["sources"][:5])
    snapshot["metadata"]["artist"]["artistId"]=value["environmentCoverage"]["artistId"]
    token_ids=token_ids or [int(c["tokenId"]) for c in value["captures"]]
    count=len(token_ids)
    snapshot["entropy"]["policies"]=snapshot["entropy"]["policies"][:min(count,2)]
    snapshot["entropy"]["policyCount"]=str(len(snapshot["entropy"]["policies"]))
    captures={int(c["tokenId"]):c for c in value["captures"]}
    leaves=[]
    for token in token_ids:
        capture=captures.get(token)
        hashes=[capture[k] if capture else kh(f"{k}:{token}".encode())
                for k in ("metadataJSONHash","htmlHash","tokenDataHash")]
        leaves.append(token.to_bytes(32,"big")+bytes.fromhex(hashes[0][2:])+bytes(32)
                      +bytes.fromhex(hashes[1][2:])+bytes(32)+bytes.fromhex(hashes[2][2:]))
    root=snapshot["contentRoot"];checkpoint=root["checkpoint"]
    chain_hash,content_root=_checkpoint_commitments(leaves,int(value["chainId"]),value["sources"][0]["address"])
    checkpoint.update(tokenCount=str(count),contentRoot=content_root,leafChainHash=chain_hash)
    root.update(leafCount=str(count),contentRoot=content_root)
    header=(int(kh(b"STREAM_TOKEN_CONTENT_LEAF_MANIFEST_V1"),16),int(value["chainId"]),
            int(value["sources"][0]["address"],16),int(snapshot["sources"][6]["address"],16),
            int(checkpoint["planHash"],16),int(value["collectionId"]),int(content_root,16),count,288,count)
    raw=b"".join(word.to_bytes(32,"big") for word in header)+b"".join(leaves)
    root["manifestHash"]=kh(raw);root["leafManifest"]["byteLength"]=str(len(raw))
    value["snapshot"].update(manifestHash=kh(canonical(snapshot)),schemaHash=snapshot["schemaHash"],
                             profileHash=snapshot["profileHash"],revision=snapshot["publication"]["revision"],
                             inventoryPlan=snapshot["entropy"]["planId"],
                             canonicalizationHash=kh((ROOT/"schemas/museum/account-profile/RFC8785_JCS.json").read_bytes()))
    return canonical(snapshot),raw

class ReferenceManifestTests(unittest.TestCase):
    def setUp(self):
        self.value=fixture()
        self.snapshot_bytes,self.leaf_manifest_bytes=retained_evidence(self.value)
    def validate(self,raw):
        return validate(raw,snapshot_bytes=self.snapshot_bytes,leaf_manifest_bytes=self.leaf_manifest_bytes)
    def reject(self):
        with self.assertRaises(Exception):self.validate(canonical(self.value))
    def env_changed(self):
        raw=canonical(self.value["environment"]);self.value["environmentManifestHash"]=kh(raw);self.value["environmentManifestBytes"]=str(len(raw))
        for c in self.value["captures"]:c["environmentManifestHash"]=kh(raw)
    def test_complete_declared_fixture_and_exact_case_preserved(self):
        got=self.validate(canonical(self.value));self.assertEqual(got,self.value)
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
            with self.assertRaises(Exception):self.validate(raw)
    def test_only_literal_version_integers_with_rehashed_nested_commitments(self):
        for where in ("root","environment","renderer"):
            self.value=fixture()
            target=self.value if where=="root" else self.value[where]
            target["version"]=1.0
            if where=="environment":self.env_changed()
            if where=="renderer":self.value["rendererCatalogHash"]=kh(canonical(self.value["renderer"]))
            with self.assertRaisesRegex(ValueError,"noninteger JSON number"):
                self.validate(canonical(self.value))
        original=canonical(fixture())
        for token in (b"1e0",b"1E+0",b"NaN",b"Infinity",b"-Infinity"):
            raw=original.replace(b'"version":1',b'"version":'+token,1)
            with self.assertRaisesRegex(ValueError,"noninteger JSON number"):
                self.validate(raw)
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
                self.validate(canonical(self.value))
    def test_zero_byte_nonexecutables_and_nonempty_executable(self):
        self.assertTrue(any(r["byteSize"]=="0" for r in self.value["environment"]["packageFiles"]))
        self.validate(canonical(self.value))
        for r in self.value["environment"]["packageFiles"]:
            if r["path"]=="engine/chrome.exe":r["byteSize"]="0"
        self.env_changed();self.reject()
    def test_runtime_and_capture_environment_identity_cannot_diverge(self):
        self.value["environment"]["runtimeObjectHash"]=kh(b"replacement runtime");self.env_changed();self.reject()
        self.value=fixture();self.value["captures"][0]["environmentManifestHash"]=kh(b"other environment");self.reject()
    def test_explicit_large_unsigned_and_predecessor_shape(self):
        self.value["publication"]["revision"]="2";self.value["publication"]["predecessor"]=kh(b"prior reference");self.validate(canonical(self.value))
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

class ReferenceEndpointTests(unittest.TestCase):
    def setUp(self):
        self.prepare((2,7,19),(2,6))

    def prepare(self,token_ids,serials):
        self.value=fixture();self.value["mintedEver"]=str(len(token_ids))
        self.value["captures"]=self.value["captures"][:len(serials)]
        endpoints=(token_ids[0],) if len(token_ids)==1 else (token_ids[0],token_ids[-1])
        for capture,token,serial in zip(self.value["captures"],endpoints,serials):
            capture.update(tokenId=str(token),collectionSerial=str(serial))
        self.snapshot_bytes,self.leaf_manifest_bytes=retained_evidence(self.value,token_ids)

    def validate(self):
        return validate(canonical(self.value),snapshot_bytes=self.snapshot_bytes,
                        leaf_manifest_bytes=self.leaf_manifest_bytes)

    def reanchor_transport(self,mutate_snapshot=None):
        # Deliberately re-sign declared transport hashes to reach deeper checks.
        # The checkpoint root/chain stay fixed unless the test explicitly changes them.
        snapshot=json.loads(self.snapshot_bytes)
        snapshot["contentRoot"]["manifestHash"]=kh(self.leaf_manifest_bytes)
        if mutate_snapshot:mutate_snapshot(snapshot)
        self.snapshot_bytes=canonical(snapshot)
        self.value["snapshot"]["manifestHash"]=kh(self.snapshot_bytes)

    def test_no_gap_singleton_and_multiple_remain_compatible(self):
        for ids,serials in (((1,),(1,)),((1,2),(1,2))):
            with self.subTest(ids=ids):
                self.prepare(ids,serials);self.assertEqual(self.validate(),self.value)

    def test_first_aborted_serial_then_single_retained_token(self):
        self.prepare((2,),(2,))
        self.assertEqual(self.validate()["captures"][0]["collectionSerial"],"2")

    def test_first_and_interior_serial_gaps_keep_exact_endpoints(self):
        for ids,serials in (((2,7,19),(2,6)),((1,7,19),(1,5)),((12,(1<<256)-1),(4,10))):
            with self.subTest(ids=ids):
                self.prepare(ids,serials)
                self.assertEqual([c["tokenId"] for c in self.validate()["captures"]],[str(ids[0]),str(ids[-1])])

    def test_burned_history_is_retained_without_live_owner_or_serial_fields_in_leaves(self):
        # These named fixture identities represent completed, subsequently burned
        # endpoints. Core lifecycle admission belongs to publication, not this tool.
        historical_identities=((2,2,3),(19,6,3))
        self.assertEqual([int(c["tokenId"]) for c in self.validate()["captures"]],
                         [identity[0] for identity in historical_identities])
        self.assertEqual(len(self.leaf_manifest_bytes),320+192*3)

    def test_complete_evidence_is_required_even_for_dense_serials(self):
        self.prepare((1,2),(1,2))
        with self.assertRaises(TypeError):validate(canonical(self.value))
        with self.assertRaises(ValueError):
            validate(canonical(self.value),snapshot_bytes=b"",leaf_manifest_bytes=self.leaf_manifest_bytes)

    def test_snapshot_and_leaf_bytes_cannot_be_replaced_without_anchors(self):
        original=self.snapshot_bytes;self.snapshot_bytes+=b"\n"
        with self.assertRaisesRegex(ValueError,"snapshot manifest anchor"):self.validate()
        self.snapshot_bytes=original;self.leaf_manifest_bytes=self.leaf_manifest_bytes[:-1]+b"\x01"
        with self.assertRaisesRegex(ValueError,"leaf manifest anchor"):self.validate()

    def test_missing_trailing_and_duplicate_extra_leaves_rejected(self):
        original=self.leaf_manifest_bytes
        for bad in (original[:-192],original+b"\x00",original+original[-192:]):
            with self.subTest(length=len(bad)):
                self.leaf_manifest_bytes=bad;self.reanchor_transport()
                with self.assertRaisesRegex(ValueError,"leaf manifest length"):self.validate()

    def test_duplicate_and_reordered_leaves_rejected_after_transport_rehash(self):
        header=self.leaf_manifest_bytes[:320]
        leaves=[self.leaf_manifest_bytes[i:i+192] for i in range(320,len(self.leaf_manifest_bytes),192)]
        for rows in ((leaves[0],leaves[0],leaves[2]),(leaves[1],leaves[0],leaves[2]),tuple(reversed(leaves))):
            self.leaf_manifest_bytes=header+b"".join(rows);self.reanchor_transport()
            with self.assertRaisesRegex(ValueError,"strictly ordered"):self.validate()

    def test_zero_token_or_metadata_rejected_after_transport_rehash(self):
        original=self.leaf_manifest_bytes
        for offset in (320,352):
            self.leaf_manifest_bytes=original[:offset]+bytes(32)+original[offset+32:];self.reanchor_transport()
            with self.assertRaisesRegex(ValueError,"strictly ordered"):self.validate()

    def test_every_canonical_header_word_is_checked(self):
        original=self.leaf_manifest_bytes
        for word in range(10):
            with self.subTest(word=word):
                bad=bytearray(original);bad[word*32+31]^=1;self.leaf_manifest_bytes=bytes(bad);self.reanchor_transport()
                with self.assertRaisesRegex(ValueError,"canonical leaf manifest header"):self.validate()

    def test_interior_content_and_ordered_chain_commitments_are_checked(self):
        original=self.leaf_manifest_bytes
        for field in range(1,6):
            with self.subTest(field=field):
                bad=bytearray(original);bad[320+192+field*32]^=1
                self.leaf_manifest_bytes=bytes(bad);self.reanchor_transport()
                with self.assertRaisesRegex(ValueError,"ordered checkpoint commitments"):self.validate()
        self.leaf_manifest_bytes=original
        self.reanchor_transport(lambda s:s["contentRoot"]["checkpoint"].update(leafChainHash=kh(b"replacement chain")))
        with self.assertRaisesRegex(ValueError,"ordered checkpoint commitments"):self.validate()

    def test_tree_root_is_checked_independently_of_leaf_chain(self):
        bad_root=kh(b"replacement root")
        raw=self.leaf_manifest_bytes;self.leaf_manifest_bytes=raw[:192]+bytes.fromhex(bad_root[2:])+raw[224:]
        def mutate(snapshot):
            snapshot["contentRoot"]["contentRoot"]=bad_root
            snapshot["contentRoot"]["checkpoint"]["contentRoot"]=bad_root
        self.reanchor_transport(mutate)
        with self.assertRaisesRegex(ValueError,"ordered checkpoint commitments"):self.validate()

    def test_count_and_capture_count_cannot_hide_missing_endpoints(self):
        self.value["mintedEver"]="2"
        with self.assertRaisesRegex(ValueError,"complete checkpoint count"):self.validate()
        self.value["mintedEver"]="3";self.value["captures"].pop()
        with self.assertRaisesRegex(ValueError,"first/last complete inventory"):self.validate()

    def test_late_wrong_endpoint_or_content_failure_allows_identical_retry(self):
        original=canonical(self.value)
        for field,replacement in (("tokenId","7"),("metadataJSONHash",kh(b"wrong metadata")),
                                  ("tokenDataHash",kh(b"wrong data"))):
            self.value=json.loads(original);self.value["captures"][-1][field]=replacement
            with self.assertRaisesRegex(ValueError,"exact checkpoint endpoint sample"):self.validate()
            self.value=json.loads(original);self.assertEqual(self.validate(),self.value)
        self.value["captures"].reverse()
        with self.assertRaisesRegex(ValueError,"exact checkpoint endpoint sample"):self.validate()

    def test_html_hash_must_match_last_leaf_even_when_capture_is_self_consistent(self):
        capture=self.value["captures"][-1];html=b"other complete HTML"
        capture.update(animationHTMLBase64=base64.b64encode(html).decode(),htmlBytes=str(len(html)),
                       htmlHash=kh(html),sourceSha256=sh(html))
        with self.assertRaisesRegex(ValueError,"exact checkpoint endpoint sample"):self.validate()

    def test_serials_are_positive_and_increasing_after_endpoint_join(self):
        for serials in ((0,6),(6,6),(9,6)):
            for capture,serial in zip(self.value["captures"],serials):capture["collectionSerial"]=str(serial)
            with self.assertRaises(ValueError):self.validate()

    def test_snapshot_collection_source_and_interpretation_bindings(self):
        self.reanchor_transport(lambda s:s["sources"][4].update(runtimeHash=kh(b"other router")))
        with self.assertRaisesRegex(ValueError,"source context"):self.validate()
        self.setUp();self.value["snapshot"]["inventoryPlan"]=kh(b"other inventory")
        with self.assertRaisesRegex(ValueError,"interpretation and inventory"):self.validate()

    def test_existing_solidity_tree_vectors_include_odd_promoted_nodes(self):
        roots={1:"249a9aa88f1d67e053b01d82a52f3b87cde5f594d2a802781d17ef78575f032c",
               2:"a1a8bedcc1ce4966887df8087307fb605199133b34ed2ef15ece8800bd9bfb72",
               3:"7ff81836082f972574397915c2c209e9048736cf0faac729a810521ca2db45e1",
               5:"0212371ee488a82515c61609360339ddb79adbeb85e38523c064bdfd22e2254f",
               8:"c0539a20aa460146e51a8e06ad4fb9fc1293c6e893c215657a176a4718ce84eb",
               37:"8d9a566342c739139265758502412fd8253dabfc5c556adac8d683722c37ecaf"}
        for count,expected in roots.items():
            leaves=[(3*i+1).to_bytes(32,"big")+b"".join(bytes.fromhex(kh(f"{field}:{i}".encode())[2:])
                    for field in ("metadata","image","animation","content","data")) for i in range(count)]
            self.assertEqual(_checkpoint_commitments(leaves,11155111,"0x1234567890123456789012345678901234567890")[1],"0x"+expected)

    def test_cli_requires_both_evidence_files_and_reports_join_before_capture_work(self):
        import contextlib
        import io
        from unittest.mock import patch
        from tools.preservation import reference_manifest as manifest
        # CLI/evidence wiring only; existing tests independently exercise real ZIP,
        # metadata and PNG bytes. This test does not execute the archived browser.
        with tempfile.TemporaryDirectory() as directory:
            base=Path(directory);reference=base/"reference.json";snapshot=base/"snapshot.json"
            leaves=base/"leaves.bin";output=base/"report.json"
            reference.write_bytes(canonical(self.value));snapshot.write_bytes(self.snapshot_bytes)
            leaves.write_bytes(self.leaf_manifest_bytes)
            args=["reference_manifest","--manifest",str(reference),"--expected-manifest-keccak",kh(reference.read_bytes()),
                  "--runtime-zip",str(base/"runtime.zip"),"--runtime-root",str(base/"runtime"),
                  "--output",str(output)]
            for index in range(2):args += ["--metadata",str(base/f"metadata-{index}.json"),"--capture-directory",str(base/f"capture-{index}")]
            evidence_args=["--snapshot-manifest",str(snapshot),"--leaf-manifest",str(leaves)]
            for incomplete in ([],evidence_args[:2],evidence_args[2:]):
                with patch("sys.argv",args+incomplete),contextlib.redirect_stderr(io.StringIO()):
                    with self.assertRaises(SystemExit) as error:manifest.main()
                    self.assertEqual(error.exception.code,2)
            with (patch("sys.argv",args+evidence_args),patch.object(manifest,"package_bytes",return_value={}) as package,
                  patch.object(manifest,"capture_bytes",return_value={}) as capture,contextlib.redirect_stdout(io.StringIO())):
                manifest.main();report=json.loads(output.read_bytes())
                self.assertTrue(report["retainedCheckpointEndpointsMatch"])
                self.assertFalse(report["liveAuthorityOrArchiveEstablished"])
                self.assertEqual(report["snapshotManifestHash"],kh(self.snapshot_bytes))
                self.assertEqual(report["leafManifestHash"],kh(self.leaf_manifest_bytes))
                self.assertEqual(capture.call_count,2);package.assert_called_once()
            self.value["captures"][-1]["tokenId"]="7";reference.write_bytes(canonical(self.value))
            args[args.index("--expected-manifest-keccak")+1]=kh(reference.read_bytes())
            with patch("sys.argv",args+evidence_args),patch.object(manifest,"package_bytes") as package:
                with self.assertRaisesRegex(ValueError,"exact checkpoint endpoint sample"):manifest.main()
                package.assert_not_called()


if __name__=="__main__":unittest.main()
