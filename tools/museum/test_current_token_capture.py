"""Require actual native token metadata to retain the exact selected media join."""
import base64
import unittest

from .canonical import MuseumError, dumps
from .current_media_inputs import image_bytes, media_description
from .current_token_capture import verify_token_metadata


class TokenMetadataReadbackTests(unittest.TestCase):
    def metadata(self):
        return {"image": media_description(image_bytes())["uri"], "token_id": 1,
            "collection_id": 1, "collection_serial": 1,
            "token_data_base64": base64.b64encode(image_bytes()).decode()}

    def uri(self, value):
        return "data:application/json;base64," + base64.b64encode(dumps(value)).decode()

    def test_exact_native_metadata_is_retained_as_original_bytes(self):
        value = self.metadata()
        self.assertEqual(verify_token_metadata(self.uri(value), 1), dumps(value))

    def test_core_fallback_or_foreign_identity_cannot_count_as_metadata_acceptance(self):
        values = [{"image": "", "properties": {"stream": {"error": "ROUTER_FAILED"}}}]
        for field in ("token_id", "collection_id", "collection_serial", "image"):
            value = self.metadata(); value[field] = 2 if field != "image" else "ipfs://other"
            values.append(value)
        for value in values:
            with self.subTest(value=value), self.assertRaisesRegex(MuseumError, "identity/media differs"):
                verify_token_metadata(self.uri(value), 1)

    def test_matching_uri_cannot_hide_different_token_data(self):
        value = self.metadata(); value["token_data_base64"] = base64.b64encode(b"changed").decode()
        with self.assertRaisesRegex(MuseumError, "data bytes differ"):
            verify_token_metadata(self.uri(value), 1)


if __name__ == "__main__": unittest.main()
