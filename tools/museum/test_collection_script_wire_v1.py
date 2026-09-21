import copy
import unittest

from .canonical import MuseumError, keccak256
from .chain_abi import Array, decode, encode
from . import collection_script_wire_v1 as wire


def H(label):
    return keccak256(label.encode("utf-8"))


def available(value):
    return {"status": "available", "value": value}


def unavailable(kind="transport_unavailable", code=None):
    return {"status": "unavailable", "kind": kind, "code": code}


def context():
    return {"chainId": "31337", "core": "0x" + "11" * 20,
        "collectionId": "7", "metadata": "0x" + "22" * 20,
        "metadataRuntimeHash": H("metadata runtime"),
        "router": "0x" + "33" * 20, "routerRuntimeHash": H("router runtime")}


def zero_registry():
    return {"registry": wire.ZERO_ADDRESS, "codeHash": wire.ZERO,
        "dependencyId": wire.ZERO, "version": "0", "contentHash": wire.ZERO}


def chunks(rows):
    return [{"index": str(index), "outcome": available("0x" + raw.hex())}
        for index, raw in enumerate(rows)]


def facts(payload, rows, *, source_type="2", library=wire.ZERO, library_only=False):
    return {"payloadHash": keccak256(payload), "libraryBundle": library,
        "totalBytes": str(len(payload)), "chunkCount": str(len(rows)),
        "sourceType": source_type, "libraryOnly": library_only, "finalized": True}


def manifest(payload_hash, *, source_type="2", count="1", pointer=wire.ZERO,
        library_uri=""):
    return {"scriptHash": payload_hash, "rendererCompatibility": wire.CHUNKED_PROFILE,
        "sourceType": source_type, "libraryURI": library_uri,
        "scriptURI": "ipfs://script-reference", "sourcePointer": pointer,
        "mimeType": "application/javascript", "chunkCount": count, "executable": True}


def registry_observations(source, rows):
    content, typed = wire.registry_content_hash(source["dependencyId"], rows)
    return {"count": available(str(len(rows))),
        "chunkTypedHashes": [{"index": str(index), "outcome": available(value)}
            for index, value in enumerate(typed)],
        "contentHash": available(content), "chunks": chunks(rows)}


def chunked_fixture(*, registry=True):
    c = context()
    # U+1F642 is deliberately split across logical chunk boundaries.
    library_rows = [b"const smile='\xf0", b"\x9f\x99\x82';"]
    library_payload = b"".join(library_rows)
    if registry:
        source = {"registry": "0x" + "44" * 20, "codeHash": H("registry runtime"),
            "dependencyId": H("library name and version"), "version": "3", "contentHash": wire.ZERO}
        source["contentHash"] = wire.registry_content_hash(source["dependencyId"], library_rows)[0]
        source_type = "4"
        registry_reads = registry_observations(source, library_rows)
    else:
        source, source_type, registry_reads = zero_registry(), "2", None
    library_facts = facts(library_payload, library_rows,
        source_type=source_type, library_only=True)
    library_id = wire.bundle_id(c, library_facts, source, library_rows)
    dependency_manifest = {"dependencyId": library_id,
        "dependencyHash": library_facts["payloadHash"], "sourceType": source_type,
        "dependencyURI": "", "sourcePointer": library_id,
        "version": source["version"] if registry else "",
        "mimeType": "application/javascript", "useDependencyRegistry": registry}
    library = {"bundleId": library_id, "facts": library_facts,
        "registrySource": source, "chunks": chunks(library_rows),
        "registryObservations": registry_reads, "dependencyManifest": dependency_manifest}

    script_rows = [b"(()=>{", b"return 7})()"]
    script_payload = b"".join(script_rows)
    script_facts = facts(script_payload, script_rows, library=library_id)
    script_id = wire.bundle_id(c, script_facts, zero_registry(), script_rows)
    script = {"bundleId": script_id, "facts": script_facts,
        "registrySource": zero_registry(), "chunks": chunks(script_rows),
        "registryObservations": None}
    m = manifest(script_facts["payloadHash"], count="2", pointer=script_id,
        library_uri="https://example.test/library.js")
    selected_hash = wire._chunked_hash(c, m, script_id, script_facts)
    value = {"selection": {"host": c["metadata"], "codeHash": c["metadataRuntimeHash"],
        "manifestHash": selected_hash}, "manifest": m, "stable": None,
        "script": script, "library": library}
    return value, c


def stable_fixture():
    c = context(); payload = b"(()=>42)()"
    m = {"scriptHash": keccak256(payload), "rendererCompatibility": wire.STABLE_PROFILE,
        "sourceType": "1", "libraryURI": "", "scriptURI": "",
        "sourcePointer": "", "mimeType": "application/javascript",
        "chunkCount": "1", "executable": True}
    digest = wire._stable_hash(c, m, keccak256(payload))
    return {"selection": {"host": c["metadata"], "codeHash": c["metadataRuntimeHash"],
        "manifestHash": digest}, "manifest": m,
        "stable": {"servingScriptBytes": "0x" + payload.hex(),
            "chunkOutcome": available("0x" + payload.hex())},
        "script": None, "library": None}, c


class CollectionScriptWireV1Tests(unittest.TestCase):
    def test_collection_script_bundle_signature_preserves_all_four_native_words(self):
        # IStreamScriptBundles.Selection: host, codeHash, bundleId, manifestHash.
        expected = (context()['metadata'], H('original host code'),
            H('distinct bundle identifier'), H('distinct manifest commitment'))
        raw = b'\0' * 12 + bytes.fromhex(expected[0][2:]) + b''.join(
            bytes.fromhex(value[2:]) for value in expected[1:])
        signature, declaration = wire.SIGNATURES['collectionScriptBundle']
        self.assertEqual(signature, 'collectionScriptBundle(uint256)')
        declared = tuple(declaration.removeprefix('(').removesuffix(')').split(','))
        self.assertEqual(len(raw), 128)
        self.assertEqual(decode((declared,), raw), (expected,))
        self.assertEqual(encode((declared,), (expected,)), raw)
        # The separate three-word manifest selection cannot consume this return.
        manifest_selection = tuple(wire.SELECTION_ABI[1:-1].split(','))
        with self.assertRaises(MuseumError):
            decode((manifest_selection,), raw)

    def test_generic_abi_encoder_independently_matches_native_commitments(self):
        value, c = chunked_fixture()
        manifest_kind = ("bytes32", "bytes32", "uint8", "string", "string",
            "string", "string", "uint256", "bool")
        facts_kind = ("bytes32", "bytes32", "uint32", "uint8", "uint8", "bool", "bool")
        registry_kind = ("address", "bytes32", "bytes32", "uint256", "bytes32")
        plan_kind = ("bytes32", "uint8", Array("bytes32", 32),
            Array("uint32", 32), "bytes32", "bool")

        def manifest_values(row):
            return (row["scriptHash"], row["rendererCompatibility"], int(row["sourceType"]),
                row["libraryURI"], row["scriptURI"], row["sourcePointer"],
                row["mimeType"], int(row["chunkCount"]), row["executable"])

        def facts_values(row):
            return (row["payloadHash"], row["libraryBundle"], int(row["totalBytes"]),
                int(row["chunkCount"]), int(row["sourceType"]),
                row["libraryOnly"], row["finalized"])

        def registry_values(row):
            return (row["registry"], row["codeHash"], row["dependencyId"],
                int(row["version"]), row["contentHash"])

        def logical_rows(group):
            return [bytes.fromhex(row["outcome"]["value"][2:]) for row in group["chunks"]]

        library = value["library"]
        registry_hash = keccak256(encode((registry_kind,),
            (registry_values(library["registrySource"]),)))
        library_rows = logical_rows(library)
        library_plan = (library["facts"]["payloadHash"], int(library["facts"]["sourceType"]),
            [keccak256(row) for row in library_rows], [len(row) for row in library_rows],
            library["facts"]["libraryBundle"], library["facts"]["libraryOnly"])
        generic_library_id = keccak256(encode(
            ("bytes32", "uint256", "address", plan_kind, "bytes32"),
            (wire.BUNDLE_DOMAIN, int(c["chainId"]), c["metadata"], library_plan,
                registry_hash)))
        self.assertEqual(generic_library_id, library["bundleId"])

        script = value["script"]
        script_rows = logical_rows(script)
        script_plan = (script["facts"]["payloadHash"], int(script["facts"]["sourceType"]),
            [keccak256(row) for row in script_rows], [len(row) for row in script_rows],
            script["facts"]["libraryBundle"], script["facts"]["libraryOnly"])
        generic_script_id = keccak256(encode(
            ("bytes32", "uint256", "address", plan_kind, "bytes32"),
            (wire.BUNDLE_DOMAIN, int(c["chainId"]), c["metadata"], script_plan,
                wire.ZERO)))
        self.assertEqual(generic_script_id, script["bundleId"])
        generic_chunked = keccak256(encode(
            ("bytes32", "uint256", "address", "address", "address", "bytes32",
                "uint256", "bytes32", facts_kind, manifest_kind),
            (wire.CHUNKED_DOMAIN, int(c["chainId"]), c["core"], c["metadata"],
                c["router"], c["routerRuntimeHash"], int(c["collectionId"]),
                script["bundleId"], facts_values(script["facts"]),
                manifest_values(value["manifest"]))))
        self.assertEqual(generic_chunked, value["selection"]["manifestHash"])

        stable, stable_context = stable_fixture()
        payload = bytes.fromhex(stable["stable"]["servingScriptBytes"][2:])
        generic_stable = keccak256(encode(
            ("bytes32", "uint256", "address", "address", "address", "bytes32",
                "uint256", "bytes32", manifest_kind),
            (wire.STABLE_DOMAIN, int(stable_context["chainId"]), stable_context["core"],
                stable_context["metadata"], stable_context["router"],
                stable_context["routerRuntimeHash"], int(stable_context["collectionId"]),
                keccak256(payload), manifest_values(stable["manifest"]))))
        self.assertEqual(generic_stable, stable["selection"]["manifestHash"])

    def test_stable_manifest_and_exact_chunk_readback(self):
        value, c = stable_fixture(); result = wire.validate(value, c)
        self.assertEqual(result["mode"], "stable_inline")
        self.assertTrue(result["completeScriptBytes"])
        self.assertTrue(result["script"]["chunkReadbackVerified"])
        self.assertEqual(result["dependency"]["status"], "authenticated_empty")
        self.assertFalse(result["claims"]["scriptExecuted"])

    def test_registry_library_full_bytes_and_cross_chunk_utf8(self):
        value, c = chunked_fixture(); result = wire.validate(value, c)
        self.assertEqual(result["mode"], "immutable_bundle")
        self.assertTrue(result["completeScriptBytes"])
        self.assertTrue(result["completeDependencyBytes"])
        self.assertTrue(result["dependency"]["utf8Verified"])
        self.assertEqual(result["dependency"]["status"], "complete")
        self.assertNotEqual(result["dependency"]["payloadHash"],
            value["library"]["registrySource"]["contentHash"])
        self.assertEqual(value["library"]["bundleId"],
            "0x940027a132e2af275655848ace34bb6a9ed150562662b7201e54aa399de929a0")
        self.assertEqual(value["script"]["bundleId"],
            "0x7b94f5e67d162c8b41315f9f242ad15933498e84f3795d9ffd2af418553121b4")
        self.assertEqual(result["manifestHash"],
            "0xc9a7fb0de4c318d446f8354024a9d7b5caa6d32b1fa55c6cb748bc120bf97f5a")

    def test_local_library_has_no_registry_claim(self):
        value, c = chunked_fixture(registry=False); result = wire.validate(value, c)
        self.assertEqual(result["dependency"]["registry"]["status"], "not_applicable")
        self.assertTrue(result["completeDependencyBytes"])

    def test_unavailable_script_bytes_preserve_partial_manifest(self):
        value, c = chunked_fixture()
        value["script"]["chunks"][1]["outcome"] = unavailable("provider_error", -32000)
        result = wire.validate(value, c)
        self.assertFalse(result["completeScriptBytes"])
        self.assertFalse(result["script"]["bundleIdPreimageVerified"])
        self.assertIsNone(result["script"]["payloadHex"])
        self.assertEqual(result["manifestHash"], value["selection"]["manifestHash"])

    def test_unavailable_registry_observation_stays_partial(self):
        value, c = chunked_fixture()
        value["library"]["registryObservations"]["contentHash"] = unavailable("response_size")
        result = wire.validate(value, c)
        self.assertFalse(result["completeDependencyBytes"])
        self.assertEqual(result["dependency"]["status"], "partial_unavailable")
        self.assertTrue(result["dependency"]["bundleIdPreimageVerified"])

    def test_changed_registry_runtime_is_explicitly_not_read(self):
        value, c = chunked_fixture()
        value["library"]["chunks"] = [{"index": str(index),
            "outcome": unavailable("provider_error", -32000)} for index in range(2)]
        no_read = unavailable("not_read_runtime_mismatch")
        value["library"]["registryObservations"] = {
            "count": copy.deepcopy(no_read),
            "chunkTypedHashes": [{"index": str(index), "outcome": copy.deepcopy(no_read)}
                for index in range(2)],
            "contentHash": copy.deepcopy(no_read),
            "chunks": [{"index": str(index), "outcome": copy.deepcopy(no_read)}
                for index in range(2)]}
        result = wire.validate(value, c)
        self.assertEqual(result["dependency"]["status"], "partial_unavailable")
        self.assertEqual(result["dependency"]["payloadStatus"], "unavailable")

    def test_registry_bytes_close_payload_when_host_chunk_readback_is_unavailable(self):
        value, c = chunked_fixture()
        value["library"]["chunks"] = [{"index": str(index),
            "outcome": unavailable("provider_error", -32000)} for index in range(2)]
        result = wire.validate(value, c)
        self.assertTrue(result["completeDependencyBytes"])
        self.assertTrue(result["dependency"]["bundleIdPreimageVerified"])
        self.assertFalse(result["dependency"]["hostChunkReadbackComplete"])
        self.assertIsNotNone(result["dependency"]["payloadHex"])

    def test_typed_registry_hash_length_order_and_bytes_reject(self):
        for mutate in (
            lambda v: v["library"]["registryObservations"]["chunkTypedHashes"][0]["outcome"].update(value=H("wrong")),
            lambda v: v["library"]["registryObservations"]["chunks"].reverse(),
            lambda v: v["library"]["registryObservations"]["chunks"][0]["outcome"].update(value="0x00"),
            lambda v: v["library"]["registrySource"].update(contentHash=H("wrong content")),
        ):
            value, c = chunked_fixture(); mutate(value)
            with self.assertRaises(MuseumError): wire.validate(value, c)
        value, c = chunked_fixture()
        value["library"]["registryObservations"]["chunkTypedHashes"][0]["outcome"] = unavailable()
        value["library"]["registryObservations"]["contentHash"] = available(H("wrong available content"))
        with self.assertRaises(MuseumError): wire.validate(value, c)

    def test_bundle_manifest_dependency_and_selection_hashes_reject(self):
        for mutate in (
            lambda v: v["script"].update(bundleId=H("other bundle")),
            lambda v: v["manifest"].update(sourcePointer=H("other pointer")),
            lambda v: v["library"]["dependencyManifest"].update(dependencyId=H("external registry id")),
            lambda v: v["selection"].update(manifestHash=H("other manifest")),
            lambda v: v["selection"].update(codeHash=H("other host runtime")),
        ):
            value, c = chunked_fixture(); mutate(value)
            with self.assertRaises(MuseumError): wire.validate(value, c)

    def test_absent_library_is_exact_and_uri_cannot_substitute(self):
        value, c = chunked_fixture(registry=False)
        value["script"]["facts"]["libraryBundle"] = wire.ZERO
        value["script"]["bundleId"] = wire.bundle_id(
            c, value["script"]["facts"], zero_registry(),
            [bytes.fromhex(row["outcome"]["value"][2:]) for row in value["script"]["chunks"]])
        value["manifest"]["sourcePointer"] = value["script"]["bundleId"]
        value["manifest"]["libraryURI"] = ""
        value["library"] = None
        value["selection"]["manifestHash"] = wire._chunked_hash(
            c, value["manifest"], value["script"]["bundleId"], value["script"]["facts"])
        result = wire.validate(value, c)
        self.assertEqual(result["dependency"]["status"], "authenticated_empty")
        changed = copy.deepcopy(value); changed["manifest"]["libraryURI"] = "https://example.test/library.js"
        changed["selection"]["manifestHash"] = wire._chunked_hash(
            c, changed["manifest"], changed["script"]["bundleId"], changed["script"]["facts"])
        with self.assertRaises(MuseumError): wire.validate(changed, c)

    def test_utf8_invalid_whole_stream_and_source_specific_bounds_reject(self):
        value, c = chunked_fixture(registry=False)
        rows = [b"x" * 8192 + b"\xf0", b"\x28\x8c\xbc"]
        facts_value = facts(b"".join(rows), rows)
        identifier = wire.bundle_id(c, facts_value, zero_registry(), rows)
        value["script"].update(bundleId=identifier, facts=facts_value, chunks=chunks(rows))
        value["manifest"].update(scriptHash=facts_value["payloadHash"], chunkCount="2",
            sourcePointer=identifier)
        value["selection"]["manifestHash"] = wire._chunked_hash(
            c, value["manifest"], identifier, facts_value)
        with self.assertRaises(MuseumError): wire.validate(value, c)
        value, c = stable_fixture(); value["stable"]["servingScriptBytes"] = "0x" + (b"x" * 8193).hex()
        with self.assertRaises(MuseumError): wire.validate(value, c)

    def test_partial_bounds_and_registry_only_executable_bundle_reject(self):
        value, c = chunked_fixture()
        value["script"]["chunks"][1]["outcome"] = unavailable()
        value["script"]["facts"]["totalBytes"] = "1"
        value["selection"]["manifestHash"] = wire._chunked_hash(
            c, value["manifest"], value["script"]["bundleId"], value["script"]["facts"])
        with self.assertRaises(MuseumError): wire.validate(value, c)

    def test_partial_registry_union_and_typed_fold_remain_bound(self):
        value, c = chunked_fixture()
        value["library"]["chunks"] = [{"index": str(index), "outcome": unavailable()}
            for index in range(2)]
        value["library"]["registryObservations"]["chunks"][1]["outcome"] = unavailable()
        value["library"]["facts"]["totalBytes"] = "2"
        with self.assertRaisesRegex(MuseumError, "effective payload total"):
            wire.validate(value, c)

        value, c = chunked_fixture()
        value["library"]["chunks"] = [{"index": str(index), "outcome": unavailable()}
            for index in range(2)]
        for row in value["library"]["registryObservations"]["chunks"]:
            row["outcome"] = unavailable()
        wrong = H("mutually agreeing wrong registry content")
        value["library"]["registrySource"]["contentHash"] = wrong
        value["library"]["registryObservations"]["contentHash"] = available(wrong)
        with self.assertRaisesRegex(MuseumError, "typed commitment"):
            wire.validate(value, c)
        value, c = chunked_fixture()
        value["script"]["facts"]["sourceType"] = "4"
        value["script"]["registrySource"] = copy.deepcopy(value["library"]["registrySource"])
        value["script"]["registryObservations"] = copy.deepcopy(value["library"]["registryObservations"])
        value["manifest"]["sourceType"] = "4"
        value["selection"]["manifestHash"] = wire._chunked_hash(
            c, value["manifest"], value["script"]["bundleId"], value["script"]["facts"])
        with self.assertRaises(MuseumError): wire.validate(value, c)

    def test_uri_reference_is_bounded_but_never_retrieved(self):
        value, c = chunked_fixture()
        for uri in ("https://?query", "ipfs://", "ar://", "https://example.test/a b"):
            changed = copy.deepcopy(value); changed["manifest"]["scriptURI"] = uri
            changed["selection"]["manifestHash"] = wire._chunked_hash(
                c, changed["manifest"], changed["script"]["bundleId"], changed["script"]["facts"])
            with self.assertRaises(MuseumError): wire.validate(changed, c)
        self.assertFalse(wire.validate(value, c)["claims"]["externalUriRetrieved"])


if __name__ == "__main__":
    unittest.main()
