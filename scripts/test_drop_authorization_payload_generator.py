#!/usr/bin/env python3
"""Tests for the no-secret drop authorization payload generator."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import generate_drop_authorization_payload as generator  # noqa: E402


FIXTURE_DIR = REPO_ROOT / "test" / "fixtures" / "drop-authorization"
PAYLOAD_DIR = FIXTURE_DIR / "payload-generator"
ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"


def load_json(path: Path) -> dict[str, object]:
    """Load one JSON object."""
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, value: object) -> None:
    """Write deterministic JSON for temporary test fixtures."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def fixed_price_input() -> dict[str, object]:
    """Load the committed fixed-price payload input."""
    return load_json(PAYLOAD_DIR / "fixed-price-input.json")


def auction_input() -> dict[str, object]:
    """Load the committed auction payload input."""
    return load_json(PAYLOAD_DIR / "auction-input.json")


class DropAuthorizationPayloadGeneratorTests(unittest.TestCase):
    def test_committed_payload_outputs_are_current(self) -> None:
        """The committed generated payload outputs match their templates."""
        pairs = [
            ("fixed-price-input.json", "fixed-price-output.json"),
            ("auction-input.json", "auction-output.json"),
        ]
        for input_name, output_name in pairs:
            with self.subTest(input_name=input_name):
                result = generator.main(
                    [
                        "--input",
                        str(PAYLOAD_DIR / input_name),
                        "--output",
                        str(PAYLOAD_DIR / output_name),
                        "--check",
                    ]
                )
                self.assertEqual(result, 0)

    def test_fixed_price_payload_matches_signed_fixture_hashes(self) -> None:
        """Generated fixed-price unsigned payloads share hashes with the signed fixture."""
        payload = generator.build_payload(fixed_price_input(), "fixed-price")
        signed_fixture = load_json(FIXTURE_DIR / "fixed-price-eoa.json")

        self.assertEqual(payload["schema_version"], generator.OUTPUT_SCHEMA_VERSION)
        self.assertEqual(payload["signing_status"], "unsigned")
        payload_domain = payload["typed_data"]["domain"]
        signed_domain = signed_fixture["typed_data"]["domain"]
        self.assertEqual(payload_domain["name"], signed_domain["name"])
        self.assertEqual(payload_domain["version"], signed_domain["version"])
        self.assertEqual(payload_domain["chainId"], signed_domain["chainId"])
        self.assertEqual(
            payload_domain["verifyingContract"].lower(),
            signed_domain["verifyingContract"].lower(),
        )
        self.assertEqual(
            payload["typed_data"]["message"],
            signed_fixture["typed_data"]["message"],
        )
        self.assertEqual(payload["derived"]["digest"], signed_fixture["expected"]["digest"])
        self.assertEqual(payload["derived"]["drop_id"], signed_fixture["expected"]["drop_id"])

    def test_auction_payload_matches_signed_fixture_hashes(self) -> None:
        """Generated auction unsigned payloads share hashes with the signed fixture."""
        payload = generator.build_payload(auction_input(), "auction")
        signed_fixture = load_json(FIXTURE_DIR / "auction-eoa.json")

        self.assertEqual(payload["typed_data"]["message"]["saleMode"], 2)
        self.assertEqual(payload["typed_data"]["message"]["recipient"], ZERO_ADDRESS)
        self.assertEqual(payload["typed_data"]["message"]["payer"], ZERO_ADDRESS)
        self.assertEqual(payload["derived"]["digest"], signed_fixture["expected"]["digest"])

    def test_check_mode_rejects_stale_output(self) -> None:
        """Check mode fails when the output file has drifted."""
        with tempfile.TemporaryDirectory() as temp_dir:
            output = Path(temp_dir) / "fixed-price-output.json"
            output.write_text("{}\n", encoding="utf-8")

            with self.assertRaisesRegex(generator.DropAuthorizationPayloadError, "stale"):
                generator.main(
                    [
                        "--input",
                        str(PAYLOAD_DIR / "fixed-price-input.json"),
                        "--output",
                        str(output),
                        "--check",
                    ]
                )

    def test_rejects_zero_poster(self) -> None:
        """Generated payloads require a non-zero poster."""
        data = fixed_price_input()
        data["sale"]["poster"] = ZERO_ADDRESS

        with self.assertRaisesRegex(generator.DropAuthorizationPayloadError, "poster"):
            generator.build_payload(data, "fixed-price")

    def test_rejects_fixed_price_zero_recipient(self) -> None:
        """Fixed-price payloads require a non-zero recipient."""
        data = fixed_price_input()
        data["sale"]["recipient"] = ZERO_ADDRESS

        with self.assertRaisesRegex(generator.DropAuthorizationPayloadError, "recipient"):
            generator.build_payload(data, "fixed-price")

    def test_rejects_auction_nonzero_recipient(self) -> None:
        """Auction payloads keep custody by using a zero recipient."""
        data = auction_input()
        data["sale"]["recipient"] = "0x0000000000000000000000000000000000005005"

        with self.assertRaisesRegex(generator.DropAuthorizationPayloadError, "recipient"):
            generator.build_payload(data, "auction")

    def test_rejects_secret_like_input(self) -> None:
        """Input templates must not contain secret-shaped fields or values."""
        data = fixed_price_input()
        data["sale"]["signingPrivateKey"] = "0x" + "11" * 32

        with self.assertRaisesRegex(generator.DropAuthorizationPayloadError, "secret-like"):
            generator.build_payload(data, "fixed-price")

    def test_rejects_missing_required_field(self) -> None:
        """Missing message fields fail before a payload is emitted."""
        data = fixed_price_input()
        del data["sale"]["deadline"]

        with self.assertRaisesRegex(generator.DropAuthorizationPayloadError, "deadline"):
            generator.build_payload(data, "fixed-price")


if __name__ == "__main__":
    unittest.main(verbosity=2)
