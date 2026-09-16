"""Actual byte measurement controls, independent of publication/source authority."""
import copy
import hashlib
from fractions import Fraction
import random
import json
from pathlib import Path
import struct
import unittest
import zlib

from tools.museum.canonical import keccak256
from tools.preservation import reference_metric as m
from tools.preservation.reference_mode_profile import generated


def png(pixels, method=0, alpha=None, ancillary=b""):
    height, width = len(pixels), len(pixels[0])
    channels = 3 if alpha is None else 4
    previous = bytes(width * channels)
    scan = bytearray()
    for row in pixels:
        raw = bytes(c for pixel in row for c in (pixel if alpha is None else (*pixel, alpha)))
        scan.append(method)
        for i, c in enumerate(raw):
            left = raw[i - channels] if i >= channels else 0
            above = previous[i]
            upper = previous[i - channels] if i >= channels else 0
            p = left + above - upper
            distances = [abs(p - v) for v in (left, above, upper)]
            predictors = (0, left, above, (left + above) // 2,
                          (left, above, upper)[distances.index(min(distances))])
            scan.append((c - predictors[method]) & 255)
        previous = raw
    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2 if alpha is None else 6, 0, 0, 0))
            + ancillary + chunk(b"IDAT", zlib.compress(scan)) + chunk(b"IEND", b""))


class ReferenceMetricTests(unittest.TestCase):
    def setUp(self):
        self.pixels = [[((x * 13 + y * 7) % 256, (x * 9) % 256, (y * 17) % 256) for x in range(16)] for y in range(16)]
        self.raw = png(self.pixels)

    def test_all_five_png_filters_decode_to_exact_original_pixels(self):
        expected = [tuple(row) for row in self.pixels]
        for method in range(5):
            self.assertEqual(m.rgb(png(self.pixels, method), 16, 16), expected)
            self.assertEqual(m.score(self.raw, png(self.pixels, method), 16, 16), m.SCALE)
        self.assertEqual(m.rgb(png(self.pixels, 4, 255), 16, 16), expected)

    def test_constant_luminance_formula_independently_matches_integer_score(self):
        a, b = 70, 90
        first = png([[(a, a, a)] * 11] * 11)
        second = png([[(b, b, b)] * 11] * 11)
        expected = m.SCALE * (20000 * a * b + 65025) // (10000 * (a * a + b * b) + 65025)
        self.assertEqual(m.score(first, second, 11, 11), expected)
        self.assertEqual(m.score(second, first, 11, 11), expected)

    def test_nonconstant_rgb_matches_independent_two_dimensional_fraction_oracle(self):
        # Direct normalized 2-D population moments; independent of the production
        # separable scan and integer-expanded formula. Preserve per-window flooring.
        weights = (1, 8, 38, 114, 222, 277, 222, 114, 38, 8, 1)
        total_weight = sum(weights) ** 2
        rng = random.Random(6529)
        width, height = 13, 12
        first = [[tuple(rng.randrange(256) for _ in range(3)) for _ in range(width)] for _ in range(height)]
        nearby = [[tuple(max(0, min(255, c + rng.randrange(-17, 18))) for c in pixel) for pixel in row] for row in first]
        inverse = [[tuple(255 - c for c in pixel) for pixel in row] for row in first]
        for second in (nearby, inverse):
            scores = []
            for channel in range(3):
                for top in range(height - 10):
                    for left in range(width - 10):
                        values = [(Fraction(wy * wx, total_weight),
                                   first[top + dy][left + dx][channel],
                                   second[top + dy][left + dx][channel])
                                  for dy, wy in enumerate(weights) for dx, wx in enumerate(weights)]
                        ux = sum(w * x for w, x, _ in values)
                        uy = sum(w * y for w, _, y in values)
                        vx = sum(w * (x - ux) ** 2 for w, x, _ in values)
                        vy = sum(w * (y - uy) ** 2 for w, _, y in values)
                        covariance = sum(w * (x - ux) * (y - uy) for w, x, y in values)
                        c1, c2 = Fraction(65025, 10000), Fraction(585225, 10000)
                        exact = ((2 * ux * uy + c1) * (2 * covariance + c2)
                                 / ((ux * ux + uy * uy + c1) * (vx + vy + c2)))
                        scaled = exact * 1_000_000_000
                        scores.append(scaled.numerator // scaled.denominator)
            expected = sum(scores) // len(scores)
            self.assertEqual(m.score(png(first, 3), png(second, 4), width, height), expected)
            self.assertEqual(m.score(png(second), png(first), width, height), expected)

    def test_inverted_structure_has_negative_score_not_unsigned_wrap(self):
        other = [[tuple(255 - c for c in p) for p in row] for row in self.pixels]
        self.assertLess(m.score(self.raw, png(other), 16, 16), 0)

    def test_corrupt_geometry_alpha_and_interpretation_refuse(self):
        broken = self.raw[:-5] + b"xxxxx"
        for raw, width in ((broken, 16), (self.raw, 17), (self.raw, 10), (self.raw, 513), (png(self.pixels, alpha=254), 16)):
            with self.assertRaises(ValueError):
                m.rgb(raw, width, 16)
        body = struct.pack(">I", 45455)
        ancillary = struct.pack(">I", len(body)) + b"gAMA" + body + struct.pack(">I", zlib.crc32(b"gAMA" + body))
        with self.assertRaisesRegex(ValueError, "color"):
            m.rgb(png(self.pixels, ancillary=ancillary), 16, 16)

    def test_report_abi_offsets_signed_words_and_hash_preimage(self):
        h = "0x" + "11" * 32
        definition = (h, h, "tool", "1", h, h, m.SCALE)
        raw = m.report_preimage(h, definition, 990000000, [999000000, -2], 1000)
        word = lambda offset: int.from_bytes(raw[offset:offset + 32], "big")
        self.assertEqual(raw[:32].hex(), keccak256(b"6529STREAM_PERCEPTUAL_REPORT_V1")[2:])
        self.assertEqual(raw[32:64], bytes.fromhex(h[2:]))
        self.assertEqual(word(64), 192)  # six top-level heads
        self.assertEqual(word(96), 990000000)
        self.assertEqual(word(160), 1000)
        metric = word(64)
        self.assertEqual(word(metric + 64), 224)  # seven Metric heads
        self.assertEqual(word(metric + 96), 288)
        self.assertEqual(raw[metric + 256:metric + 260], b"tool")
        scores = word(128)
        self.assertEqual(word(scores), 2)
        self.assertEqual(word(scores + 32), 999000000)
        self.assertEqual(word(scores + 64), (1 << 256) - 2)
        self.assertEqual(len(raw), scores + 96)

    def manifest(self, second):
        sha = lambda raw: "0x" + hashlib.sha256(raw).hexdigest()
        return {"contextHash": keccak256(b"actual host context supplied separately"),
                "environmentHash": keccak256(b"retained environment"), "threshold": 990000000, "evaluatedAt": 1000,
                "captures": [{"firstSha256": sha(self.raw), "secondSha256": sha(second), "width": 16, "height": 16}]}

    def test_actual_byte_report_classifies_match_variance_and_divergence(self):
        for second, outcome in ((self.raw, "MATCH"), (png(self.pixels, 4), "TOLERABLE_VARIANCE"),
                                (png([[(0, 0, 0)] * 16] * 16), "DIVERGENT")):
            report = m.measure(self.manifest(second), b"retained environment", [(self.raw, second)])
            self.assertEqual(report["outcomes"], [outcome])
            self.assertEqual(report["reportHash"], keccak256(bytes.fromhex(report["reportPreimageABI"][2:])))
            self.assertEqual(report["publishableThreshold"], outcome != "DIVERGENT")

    def test_exact_context_environment_capture_and_threshold_mutations(self):
        original = self.manifest(self.raw)
        for field in ("contextHash", "threshold", "evaluatedAt"):
            changed = copy.deepcopy(original)
            changed[field] = keccak256(b"other context") if field == "contextHash" else changed[field] + 1
            self.assertNotEqual(m.measure(original, b"retained environment", [(self.raw, self.raw)])["reportHash"],
                                m.measure(changed, b"retained environment", [(self.raw, self.raw)])["reportHash"])
        with self.assertRaisesRegex(ValueError, "environment"):
            m.measure(original, b"changed", [(self.raw, self.raw)])
        with self.assertRaisesRegex(ValueError, "capture"):
            m.measure(original, b"retained environment", [(self.raw, png(self.pixels, 1))])
        for value in (-1, m.SCALE + 1, True):
            with self.assertRaises(ValueError):
                m.report_preimage(original["contextHash"], m.metric(), value, [m.SCALE], 1000)

    def test_registered_definition_has_exact_tool_parameters_and_source_hashes(self):
        definition = m.metric()
        self.assertEqual(definition[0], keccak256(b"STREAM_METRIC_SSIM_V1"))
        self.assertEqual(definition[5], keccak256(m.canonical(m.PARAMETERS)))
        self.assertEqual(definition[4], m.implementation_hash())
        self.assertEqual(definition[6], m.SCALE)

    def test_existing_retained_native_capture_bytes_measure_exactly(self):
        # Existing public test-capture files, not a new chain or institutional acceptance.
        for name in ("reference-token-1.png", "reference-token-2.png"):
            raw = (m.ROOT / "test/fixtures/preservation" / name).read_bytes()
            width, height = struct.unpack(">II", raw[16:24])
            self.assertEqual(m.score(raw, raw, width, height), m.SCALE)

    def test_complete_schema_and_generated_solidity_literals_match(self):
        path = m.ROOT / "smart-contracts/domains/records/StreamReferenceModeDefinitions.sol"
        self.assertEqual(path.read_text(encoding="utf8"), generated())
        schema = json.loads((m.ROOT / "schemas/records/STREAM_REFERENCE_MODE_ABI_V1.json").read_bytes())
        self.assertEqual(len(schema["abi"]), 7)
        def complete(row):
            if row["type"].startswith("tuple"):
                self.assertTrue(row["components"])
                for item in row["components"]:
                    complete(item)
        for row in schema["abi"]:
            complete(row)


if __name__ == "__main__":
    unittest.main()
