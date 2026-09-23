"""Archival core, supplied-source joins and permitted Presentation extensions."""
import copy
import unittest
from unittest.mock import patch

import rfc8785

from tools.museum.canonical import MuseumError, dumps
from .genesis_iiif_profile import MEDIA_TERM, SCHEMA_BYTES, example, outputs, ROOT, validate


class GenesisIIIF(unittest.TestCase):
    def check(self, value, **kwargs):
        return validate(rfc8785.dumps(value), **kwargs)

    def body(self, value):
        return value["items"][0]["items"][0]["items"][0]["body"]

    def test_exact_generator_and_offline_supplied_media_join(self):
        value = example()
        with patch("socket.socket", side_effect=AssertionError("offline")):
            self.assertEqual(self.check(value, expected_media=[self.body(value)[MEDIA_TERM]]), value)
        for name, raw in outputs().items():
            self.assertEqual((ROOT / name).read_bytes(), raw)
        self.assertIn(b'"title":"STREAM_IIIF_P3_MIN_V1"', SCHEMA_BYTES)

    def test_media_set_missing_extra_or_conflicting_commitment_rejected(self):
        value = example()
        changed = copy.deepcopy(self.body(value)[MEDIA_TERM]); changed["source"]["field"] = "animationHash"
        for expected in ([], [changed]):
            with self.assertRaises(MuseumError):
                self.check(value, expected_media=expected)
        duplicate = copy.deepcopy(value["items"][0]); duplicate["id"] += "-2"
        page = duplicate["items"][0]; page["id"] += "-2"
        annotation = page["items"][0]; annotation["id"] += "-2"; annotation["target"] = duplicate["id"]
        annotation["body"][MEDIA_TERM]["contentHash"]["digest"] = "0x" + "45" * 32
        value["items"].append(duplicate)
        with self.assertRaisesRegex(MuseumError, "conflicting"):
            self.check(value)

    def test_extensions_choices_segments_languages_and_fractional_duration(self):
        value = example(); value["label"]["fr"] = ["Exemple"]
        value["behavior"] = ["individuals"]
        canvas = value["items"][0]; canvas["duration"] = 1.25
        annotation = canvas["items"][0]["items"][0]
        annotation["target"] = canvas["id"] + "#t=0,1.25"
        content = annotation["body"]; content.update(type="Video", format="video/mp4", duration=1.25)
        content["service"] = [{"id": "https://example.invalid/live-image-service", "type": "ImageService3", "profile": "level1"}]
        annotation["body"] = {"type": "Choice", "items": [content]}
        self.assertEqual(self.check(value), value)

    def test_core_required_fields_and_non_archival_uris(self):
        for key in ("label", "summary", "requiredStatement", "rights", "items"):
            value = example(); del value[key]
            with self.subTest(key=key), self.assertRaises(MuseumError): self.check(value)
        for uri in ("https://example.invalid/image.png", "ar://invalid", "javascript:alert(1)", "ipfs://example", "ipfs://ba", "ar://" + "A" * 43 + "/../image"):
            value = example(); self.body(value)["id"] = uri
            with self.subTest(uri=uri), self.assertRaises(MuseumError): self.check(value)

    def test_manifest_identifier_and_rights_core_reject_arbitrary_uris(self):
        for field, text in (("id", "urn:test:manifest"), ("id", "ipfs://bafkreigh"),
                            ("rights", "urn:test:made-up-rights")):
            value = example(); value[field] = text
            with self.subTest(field=field, text=text), self.assertRaises(MuseumError): self.check(value)

    def test_media_selectors_derive_subject_and_one_object_per_canvas(self):
        for callback in (lambda b: b["source"].pop("field"),
                         lambda b: b["source"].update(field="metadataHash"),
                         lambda b: b["source"].update(tokenId="42"),
                         lambda b: b["source"].update(leafHash="0x" + "00" * 32)):
            value = example(); callback(self.body(value)[MEDIA_TERM])
            with self.assertRaises(MuseumError): self.check(value)
        value = example(); annotation = value["items"][0]["items"][0]["items"][0]
        other = copy.deepcopy(annotation["body"]); other[MEDIA_TERM]["source"]["field"] = "contentHash"
        annotation["body"] = [annotation["body"], other]
        with self.assertRaisesRegex(MuseumError, "per Canvas"): self.check(value)

    def test_canvas_has_extent_paired_spatial_dimensions_and_body_dimensions(self):
        for removed in (("width",), ("height",), ("width", "height")):
            value = example()
            for field in removed: del value["items"][0][field]
            with self.subTest(removed=removed), self.assertRaises(MuseumError): self.check(value)
        value = example(); self.body(value)["duration"] = 1.5
        with self.assertRaisesRegex(MuseumError, "Canvas dimensions"): self.check(value)
        value = example(); value["items"][0]["width"] = 512; value["items"][0]["height"] = 384
        # Presentation supports scaling a larger image onto a smaller Canvas.
        self.assertEqual(self.check(value), value)

    def test_executable_content_and_target_rebinding_reject(self):
        for callback in (lambda v: self.body(v).update(value="inline resource"),
                         lambda v: v["summary"].update(en=["<script>run()</script>"]),
                         lambda v: self.body(v).update(format="application/javascript"),
                         lambda v: v["items"][0]["items"][0]["items"][0].update(target="https://example.invalid/other")):
            value = example(); callback(value)
            with self.assertRaises(MuseumError): self.check(value)

    def test_original_noncanonical_duplicate_and_oversized_integer_reject(self):
        raw = dumps(example())
        for mutant in (raw + b"\n", b'{"type":"Manifest",' + raw[1:]):
            with self.assertRaises(MuseumError): validate(mutant)
        with self.assertRaises(MuseumError):
            validate(b'{"extension":9007199254740992,' + raw[1:])


if __name__ == "__main__":
    unittest.main()
