"""Focused tests for the prospective broad genesis preservation profiles."""

import copy
import unittest
from pathlib import Path

import jsonschema

from tools.metadata import genesis_preservation_profile as profile
from tools.museum.canonical import MuseumError, dumps, keccak256


class GenesisPreservationProfileTest(unittest.TestCase):
    def value(self, filename):
        return copy.deepcopy(profile.examples()[filename])

    def rejects(self, name, value):
        with self.assertRaises(MuseumError):
            profile.validate(name, dumps(value))

    def test_generated_documents_and_examples_are_exact(self):
        outputs = profile.outputs()
        self.assertEqual(set(outputs), {
            "schemas/records/STREAM_MASTER_WAIVER_V1.json",
            "schemas/records/STREAM_REFERENCE_RENDER_V1.json",
            "schemas/records/STREAM_METRIC_SSIM_V1.json",
            "schemas/records/examples/genesis-preservation/master-waiver.json",
            "schemas/records/examples/genesis-preservation/reference-render.json",
            "schemas/records/examples/genesis-preservation/metric-ssim.json",
        })
        for relative, expected in outputs.items():
            self.assertEqual((profile.ROOT / relative).read_bytes(), expected)
        for name, raw in profile.SCHEMA_BYTES.items():
            self.assertEqual(profile.SCHEMA_HASHES[name], keccak256(raw))
            self.assertEqual(profile.documents()[name]["x-stream-document-status"],
                             "prospective_unregistered")

    def test_worked_examples_validate(self):
        names = {
            "master-waiver.json": profile.MASTER_WAIVER,
            "reference-render.json": profile.REFERENCE_RENDER,
            "metric-ssim.json": profile.METRIC,
        }
        for filename, name in names.items():
            value = self.value(filename)
            self.assertEqual(profile.validate(name, dumps(value)), value)

    def test_master_waiver_scope_artist_and_objects_are_bound(self):
        value = self.value("master-waiver.json")
        value["scope"]["subjectId"] = "0x" + "99" * 32
        self.rejects(profile.MASTER_WAIVER, value)
        value = self.value("master-waiver.json")
        value["scope"]["mediaObjects"].append(copy.deepcopy(value["scope"]["mediaObjects"][0]))
        self.rejects(profile.MASTER_WAIVER, value)
        for key in ("artistId", "bindingHash"):
            value = self.value("master-waiver.json")
            value["artist"][key] = "0x" + "00" * 32
            self.rejects(profile.MASTER_WAIVER, value)

    def test_master_waiver_bounds_and_canonical_input(self):
        value = self.value("master-waiver.json")
        value["reason"] = "x" * 16385
        self.rejects(profile.MASTER_WAIVER, value)
        raw = dumps(self.value("master-waiver.json"))
        with self.assertRaises(MuseumError):
            profile.validate_master_waiver(b" " + raw)
        with self.assertRaises(MuseumError):
            profile.validate_master_waiver(raw[:-1] + b',"version":1}')

    def test_reference_requires_endpoint_and_complete_class_coverage(self):
        value = self.value("reference-render.json")
        value["tokenSample"]["tokens"].remove("100")
        self.rejects(profile.REFERENCE_RENDER, value)
        value = self.value("reference-render.json")
        value["captures"] = value["captures"][:-1]
        self.rejects(profile.REFERENCE_RENDER, value)
        value = self.value("reference-render.json")
        value["captures"][0]["tokenId"] = "77"
        self.rejects(profile.REFERENCE_RENDER, value)

    def test_reference_work_class_requirements(self):
        value = self.value("reference-render.json")
        value["requiredCaptureClasses"] = ["still"]
        value["captures"] = []
        self.rejects(profile.REFERENCE_RENDER, value)
        value = self.value("reference-render.json")
        value["workClass"] = "interactive"
        self.rejects(profile.REFERENCE_RENDER, value)

    def test_reference_sample_rule_is_explicit(self):
        value = self.value("reference-render.json")
        value["tokenSample"]["kind"] = "sampling_rule"
        self.rejects(profile.REFERENCE_RENDER, value)
        value = self.value("reference-render.json")
        value["tokenSample"]["samplingRule"] = profile._ref(77, "ipfs://sampling-rule")
        self.rejects(profile.REFERENCE_RENDER, value)

    def test_reference_capture_and_archive_semantics(self):
        value = self.value("reference-render.json")
        value["captures"][0]["parameters"]["kind"] = "av_container"
        self.rejects(profile.REFERENCE_RENDER, value)
        value = self.value("reference-render.json")
        value["captures"][0]["artifact"]["byteLength"] = "0"
        self.rejects(profile.REFERENCE_RENDER, value)
        value = self.value("reference-render.json")
        mirrors = value["executionEnvironment"]["artifact"]["archiveMirrors"]
        mirrors[1]["storageFamily"] = mirrors[0]["storageFamily"]
        self.rejects(profile.REFERENCE_RENDER, value)

    def test_reference_numeric_and_identifier_bounds(self):
        for token in (str(1 << 256), "1\n"):
            value = self.value("reference-render.json")
            value["tokenSample"]["tokens"][0] = token
            value["tokenSample"]["firstSerialTokenId"] = token
            for capture in value["captures"]:
                if capture["tokenId"] == "1": capture["tokenId"] = token
            self.rejects(profile.REFERENCE_RENDER, value)
        for mutate in (
                lambda value: value["executionEnvironment"]["viewport"].update(width="0"),
                lambda value: value["executionEnvironment"]["viewport"].update(height=str(1 << 256)),
                lambda value: value["captures"][1]["parameters"]["audio"].update(channels="0"),
                lambda value: value["captures"][1]["parameters"]["audio"].update(sampleRateHz="0"),
                lambda value: value["captures"][0]["artifact"].update(formatId="0x" + "00" * 32)):
            value = self.value("reference-render.json")
            mutate(value)
            self.rejects(profile.REFERENCE_RENDER, value)

    def test_reference_license_branches(self):
        value = self.value("reference-render.json")
        value["executionEnvironment"]["artifact"]["licenseNote"] = ""
        self.rejects(profile.REFERENCE_RENDER, value)
        value = self.value("reference-render.json")
        value["executionEnvironment"]["artifact"]["licenseBasis"] = "licensed_with_instrument"
        value["executionEnvironment"]["artifact"]["instrument"] = None
        self.rejects(profile.REFERENCE_RENDER, value)

    def test_reference_acceptance_branches(self):
        value = self.value("reference-render.json")
        value["acceptance"]["threshold"] = str(profile.SCALE + 1)
        self.rejects(profile.REFERENCE_RENDER, value)
        value = self.value("reference-render.json")
        value["acceptance"]["metricSchemaId"] = "0x" + "00" * 32
        self.rejects(profile.REFERENCE_RENDER, value)
        value = self.value("reference-render.json")
        value["acceptance"]["metricSchemaId"] += "\n"
        self.rejects(profile.REFERENCE_RENDER, value)
        for predecessor in ("0x" + "00" * 32, "0x" + "11" * 32 + "\n"):
            value = self.value("reference-render.json")
            value["predecessor"] = predecessor
            self.rejects(profile.REFERENCE_RENDER, value)

        byte_exact = self.value("reference-render.json")
        byte_exact["workClass"] = "static"
        byte_exact["rendererClass"] = "STATIC"
        byte_exact["requiredCaptureClasses"] = ["still"]
        byte_exact["captures"] = [
            {"tokenId": token, "captureClass": "still",
             "artifact": copy.deepcopy(byte_exact["captures"][index]["artifact"]),
             "parameters": {"kind": "still"}}
            for index, token in enumerate(byte_exact["tokenSample"]["tokens"])
        ]
        byte_exact["acceptance"] = {"mode": "BYTE_EXACT", "softwareRasterization": True}
        self.assertEqual(profile.validate_reference_render(dumps(byte_exact)), byte_exact)
        byte_exact["rendererClass"] = "DYNAMIC"
        self.rejects(profile.REFERENCE_RENDER, byte_exact)

        curated = self.value("reference-render.json")
        curated["acceptance"] = {
            "mode": "CURATED_EQUIVALENCE", "evidenceClass": "INSTITUTION_SIGNER",
            "attestation": profile._ref(80, "ipfs://curated-attestation"),
            "examinerInstitution": profile._ref(81, "https://example.org/museum"),
            "examinerName": "Synthetic fixture examiner",
            "examinerCredential": profile._ref(82, "ipfs://credential"),
            "significantPropertiesEvaluation": profile._ref(83, "ipfs://evaluation"),
        }
        self.assertEqual(profile.validate_reference_render(dumps(curated)), curated)

    def test_metric_is_exact_source_and_parameter_definition(self):
        value = self.value("metric-ssim.json")
        self.assertEqual(value["referenceTool"]["implementationHash"],
                         profile.REFERENCE_IMPLEMENTATION_HASH)
        self.assertEqual(value["parametersHash"], profile.PARAMETERS_HASH)
        for mutate in ("name", "version", "sourceRevision", "implementationHash"):
            changed = self.value("metric-ssim.json")
            changed["referenceTool"][mutate] = "different"
            self.rejects(profile.METRIC, changed)
        changed = self.value("metric-ssim.json")
        changed["referenceTool"]["sourceFiles"][0]["sha256"] = "00" * 32
        self.rejects(profile.METRIC, changed)
        changed = self.value("metric-ssim.json")
        changed["parameters"]["window"][0] = 8
        self.rejects(profile.METRIC, changed)

    def test_metric_schema_itself_pins_source_rows_and_parameter_order(self):
        validator = jsonschema.Draft202012Validator(profile.documents()[profile.METRIC])
        changed = self.value("metric-ssim.json")
        changed["referenceTool"]["sourceFiles"][0]["sha256"] = "00" * 32
        self.assertFalse(validator.is_valid(changed))
        changed = self.value("metric-ssim.json")
        changed["parameters"]["window"][0], changed["parameters"]["window"][1] = (
            changed["parameters"]["window"][1], changed["parameters"]["window"][0])
        self.assertFalse(validator.is_valid(changed))

    def test_unknown_schema_and_invalid_uri_reject(self):
        with self.assertRaises(MuseumError):
            profile.validate("STREAM_UNKNOWN", b"{}")
        value = self.value("master-waiver.json")
        value["waiverStatement"]["uri"] = "not a URI"
        self.rejects(profile.MASTER_WAIVER, value)


if __name__ == "__main__":
    unittest.main()
