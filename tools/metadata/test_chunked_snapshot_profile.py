"""Offline source cases; synthetic composition over retained common facts is not a recorded capture."""
import base64
import copy
import json
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path
from jsonschema.exceptions import ValidationError
from . import chunked_snapshot_profile as p
from .work_profile import digest

def encoded(v): return json.dumps(v,ensure_ascii=False,sort_keys=True,separators=(",",":")).encode()
def payload(parts,kind=2):
    return {"bundleId":p.ZERO,"byteLength":str(sum(map(len,parts))),"chunkCount":str(len(parts)),
        "chunks":[{"byteLength":str(len(raw)),"contentBase64":base64.b64encode(raw).decode(),"contentHash":digest(raw),"index":str(i)} for i,raw in enumerate(parts)],
        "contentHash":digest(b"".join(parts)),"sourceType":str(kind)}
def specimen(parts=None,library=True,registry=False):
    v=json.loads((p.ROOT/"test/fixtures/metadata/snapshot-native-onchain.json").read_bytes())
    v.update(version=2,checkpointProfile=p.CHECKPOINT,schemaId=digest(p.SCHEMA.encode()),
        schemaHash=digest(p.generated()[f"schemas/records/{p.SCHEMA}.json"]),profileHash=digest(p.generated()[f"schemas/records/{p.PROFILE}.json"]))
    v["renderer"].update(presentationProfile=p.RENDERER,context=digest(b"6529STREAM_CHUNKED_RENDER_CONTEXT_V1"))
    v["dependencyReadProfile"]=digest(b"6529STREAM_PINNED_BUNDLE_DEPENDENCIES_V1")
    v["library"]=None
    if library:
        lib=payload([b"const value=",b"7;"],4 if registry else 2);lib["registry"]=None
        if registry:
            lib["registry"]={"address":"0x"+"cd"*20,"runtimeHash":digest(b"registry code"),"dependencyId":digest(b"lib@1"),"version":str((1<<128)+9),"contentHash":p.ZERO}
            lib["registry"]["contentHash"]=p.registry_hash(lib)
        lib["bundleId"]=p.bundle_hash(v,lib,True);v["library"]=lib
    s=payload(parts or [b"// ","€".encode(),b"\nrender();"])
    s["libraryBundle"]=v["library"]["bundleId"] if library else p.ZERO
    s["bundleId"]=p.bundle_hash(v,s,False)
    s["manifest"]={"scriptHash":s["contentHash"],"rendererCompatibility":p.RENDERER,"sourceType":s["sourceType"],"libraryURI":"https://example.test/library.js" if library else "",
        "scriptURI":"ipfs://mirror","sourcePointer":s["bundleId"],"mimeType":"application/javascript","chunkCount":s["chunkCount"],"executable":True}
    s["manifestHash"]=p.ZERO;v["script"]=s;s["manifestHash"]=p.manifest_hash(v)
    return v

class ChunkedSnapshotTests(unittest.TestCase):
    def reject(self,fn):
        v=specimen();fn(v)
        with self.assertRaises(Exception):p.validate(encoded(v))
    def test_complete_local_and_registry_payloads(self):
        for registry in (False,True):
            v=specimen(registry=registry)
            self.assertEqual(p.validate(encoded(v)),v)
            self.assertEqual(p._payload(v["library"]),b"const value=7;")
    def test_no_library_is_explicit_null(self):
        v=specimen(library=False);self.assertIsNone(p.validate(encoded(v))["library"])
        v["script"]["manifest"]["libraryURI"]="https://fake.example"
        with self.assertRaises(ValueError):p.validate(encoded(v))
    def test_utf8_can_cross_chunk_boundary(self):
        v=specimen(parts=[b"// \xe2",b"\x82\xac"])
        self.assertEqual(p._payload(p.validate(encoded(v))["script"]),"// €".encode())
    def test_full32_times24576_for_script_and_library(self):
        part=b" "*24576;v=specimen(parts=[part]*32)
        lib=payload([part]*32);lib["registry"]=None;lib["bundleId"]=p.bundle_hash(v,lib,True);v["library"]=lib
        v["script"]["libraryBundle"]=lib["bundleId"];v["script"]["bundleId"]=p.bundle_hash(v,v["script"],False)
        v["script"]["manifest"]["sourcePointer"]=v["script"]["bundleId"];v["script"]["manifestHash"]=p.manifest_hash(v)
        raw=encoded(v);self.assertGreater(len(raw),2_000_000);self.assertLess(len(raw),p.MAXIMUM);p.validate(raw)
    def test_empty_oversize_missing_reordered_chunks_reject(self):
        self.reject(lambda v:v["script"]["chunks"].reverse())
        self.reject(lambda v:v["script"]["chunks"].pop())
        self.reject(lambda v:v["script"]["chunks"][0].update(contentBase64="",byteLength="0"))
        self.reject(lambda v:v["script"].update(byteLength="786433"))
        self.reject(lambda v:v["script"].update(chunkCount="33"))
    def test_bad_base64_padding_hash_and_utf8_reject(self):
        for text in ("//??","YQ===","YR==","_w=="):
            self.reject(lambda v,text=text:v["script"]["chunks"][0].update(contentBase64=text))
        self.reject(lambda v:v["script"]["chunks"][0].update(contentHash=digest(b"wrong")))
        v=specimen(parts=[b"\xff"])
        with self.assertRaises(ValueError):p.validate(encoded(v))
    def test_source_specific8192_limit(self):
        v=specimen(parts=[b"x"*8193]);v["script"]["sourceType"]="1"
        with self.assertRaises(ValueError):p.validate(encoded(v))
    def test_wrong_library_relationship_and_registry_reject(self):
        self.reject(lambda v:v.update(library=None))
        self.reject(lambda v:v["library"].update(bundleId=digest(b"wrong")))
        v=specimen(registry=True);v["library"]["registry"]["contentHash"]=v["library"]["contentHash"]
        with self.assertRaises(ValueError):p.validate(encoded(v))
    def test_canonical_source_preimages_bind_host_chain_and_manifest_fields(self):
        self.reject(lambda v:v["script"].update(bundleId=digest(b"arbitrary")))
        self.reject(lambda v:v["script"].update(manifestHash=digest(b"arbitrary")))
        self.reject(lambda v:v["sources"][1].update(address="0x"+"45"*20))
        self.reject(lambda v:v["sources"][4].update(runtimeHash=digest(b"replacement")))
        self.reject(lambda v:v["script"]["manifest"].update(scriptURI="ar://changed"))
    def test_missing_compact_unknown_and_duplicate_fields_reject(self):
        self.reject(lambda v:v["script"].pop("chunks"))
        self.reject(lambda v:v["script"].update(fullURI="web3://host/full"))
        self.reject(lambda v:v.pop("checkpointProfile"))
        with self.assertRaises(ValueError):p.validate(b'{"version":2,'+encoded(specimen())[1:])
    def test_wrong_interpretation_and_noncanonical_bytes_reject(self):
        for key in ("schemaId","schemaHash","profileHash","checkpointProfile"):
            self.reject(lambda v,key=key:v.update({key:digest(b"wrong")}))
        with self.assertRaises(ValueError):p.validate(encoded(specimen())+b"\n")
        self.reject(lambda v:v.update(version=True))
    def test_original_common_guards_retained(self):
        self.reject(lambda v:v["entropy"]["policies"].pop())
        self.reject(lambda v:v["publication"].update(displayGrantRevision="0"))
        self.reject(lambda v:v["contentRoot"]["checkpoint"].update(tokenCount="1"))
        self.reject(lambda v:v["metadata"]["locks"].update(script=False))
    def test_export_exact_bytes_manifest_and_no_overwrite(self):
        v=specimen();raw=encoded(v)
        with tempfile.TemporaryDirectory() as temp:
            out=Path(temp)/"export";report=p.export(raw,out)
            self.assertEqual((out/"snapshot.json").read_bytes(),raw)
            self.assertEqual((out/"script.js").read_bytes(),p._payload(v["script"]))
            self.assertEqual((out/"library.js").read_bytes(),b"const value=7;")
            self.assertIn("not established",report["qualification"])
            with self.assertRaises(FileExistsError):p.export(raw,out)
    def test_bad_input_leaves_no_output(self):
        with tempfile.TemporaryDirectory() as temp:
            out=Path(temp)/"export"
            with self.assertRaises(ValidationError):p.export(b"{}",out)
            self.assertFalse(out.exists())
    def test_main_entry_exports_the_validated_manifest(self):
        raw=encoded(specimen(library=False))
        with tempfile.TemporaryDirectory() as temp:
            source=Path(temp)/"source.json";source.write_bytes(raw);out=Path(temp)/"out"
            with patch("sys.argv",["chunked_snapshot_profile","--manifest",str(source),"--output",str(out)]):p.main()
            self.assertEqual((out/"snapshot.json").read_bytes(),raw)
            self.assertFalse((out/"library.js").exists())
            self.assertTrue((out/"export.json").is_file())
    def test_independent_cast_abi_encoding_vectors(self):
        # Independently cross-checked with cast abi-encode using the original explicit tuple types.
        # The fixture is synthetic; these vectors establish encoding correspondence only.
        v=specimen(registry=True)
        self.assertEqual(v["script"]["bundleId"],"0x1cf2c671d875c900621265c8765d454516efde558de8f4bcb4b54330a49a743f")
        self.assertEqual(v["library"]["bundleId"],"0xfbc53d2d626951463c06243947d7fc6a65d5c3e7589ff9dee5f63ff7efd90436")
        self.assertEqual(v["script"]["manifestHash"],"0xee3abb92533bd5bef9ac438f6ef63671dec5f1640327ee27c6120eca2accce69")
    def test_new_numeric_fields_reject_newline_and_overwidth(self):
        self.reject(lambda v:v["script"].update(sourceType="2\n"))
        self.reject(lambda v:v["script"]["chunks"][0].update(index="0\n"))
        self.reject(lambda v:v["script"].update(byteLength=str(1<<256)))
    def test_generated_and_legacy_profile_bytes_unchanged(self):
        for path,raw in p.generated().items():self.assertEqual((p.ROOT/path).read_bytes(),raw)
        for path,raw in p.inline.generated().items():self.assertEqual((p.ROOT/path).read_bytes(),raw)
        p.inline.validate((p.ROOT/"test/fixtures/metadata/snapshot-native-onchain.json").read_bytes())

if __name__=="__main__":unittest.main()
