"""Independent lexical and numeric oracles for the IIIF target encoding."""

from decimal import Decimal
import unittest

from .canonical import MuseumError, dumps, loads
from .iiif_numbers import ExactDecimal, target_dumps, target_loads


class ExactIIIFNumbers(unittest.TestCase):
    def test_decimal_lexical_values_never_pass_through_binary_float(self):
        raw = target_dumps({"duration": ExactDecimal("0.10000000000000001"), "width": 6000,
                            "otherDuration": ExactDecimal("220.000"), "label": "e\u0301\r\n40.00"})
        self.assertEqual(raw, b'{"duration":0.10000000000000001,"label":"e\xcc\x81\\r\\n40.00","otherDuration":220.000,"width":6000}')
        result = target_loads(raw)
        self.assertEqual(result["duration"], Decimal("0.10000000000000001"))
        self.assertEqual(result["otherDuration"].as_tuple(), Decimal("220.000").as_tuple())
        self.assertNotEqual(result["duration"], Decimal(str(float("0.10000000000000001"))))

    def test_full_width_integers_are_exact_and_bounded(self):
        value = (1 << 256) - 1
        raw = target_dumps({"value": value})
        self.assertEqual(raw, ('{"value":' + str(value) + '}').encode())
        self.assertEqual(target_loads(raw), {"value": value})
        for raw in (str(1 << 256).encode(), b"1" * 100):
            with self.assertRaises(MuseumError):
                target_loads(raw)
        with self.assertRaises(MuseumError):
            target_dumps(1 << 256)

    def test_stream_source_parser_remains_unchanged(self):
        with self.assertRaises(MuseumError):
            dumps({"duration": 0.25})
        with self.assertRaises(MuseumError):
            loads(b'{"duration":0.25}')
        self.assertEqual(dumps({"duration": "0.25"}), b'{"duration":"0.25"}')

    def test_unsupported_spelling_float_unicode_and_json_shapes_reject(self):
        for text in ("1e2", "01.0", ".5", "1.", "-0.5", "+1.0", "NaN", "Infinity", "1.0\n", "1" * 129):
            with self.subTest(text=text), self.assertRaises(MuseumError):
                ExactDecimal(text)
        for value in (0.1, Decimal("0.1"), {1: "not a string key"}, "\ud800"):
            with self.assertRaises(MuseumError):
                target_dumps(value)
        for raw in (b'{"a":1,"a":2}', b'{"a":"\\ud800"}', b'{"a":NaN}', b'1e2', b'-0.5', b'Infinity', b'\xff'):
            with self.subTest(raw=raw), self.assertRaises(MuseumError):
                target_loads(raw)

    def test_depth_nodes_and_bytes_have_deterministic_failures(self):
        deep = 0
        for _ in range(66):
            deep = [deep]
        for action in (lambda: target_dumps(deep), lambda: target_loads(b'[' * 66 + b'0' + b']' * 66),
                       lambda: target_dumps([0] * 65536), lambda: target_loads(b'[' + b'0,' * 65535 + b'0]'),
                       lambda: target_loads(b' ' * (16 * 1024 * 1024 + 1))):
            with self.assertRaises(MuseumError):
                action()


if __name__ == "__main__":
    unittest.main()
