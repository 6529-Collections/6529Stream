"""Exact CID wire/header and Arweave identifier controls without network."""

import base64
from unittest.mock import patch
import unittest

from .canonical import MuseumError
from .iiif_uri import content_uri_facts

DIGEST = "6e6ff7950a36187a801613426e858dce686cd7d7e3c0fc42ee0330072d245c95"


def uri(raw):
    return "ipfs://b" + base64.b32encode(raw).decode("ascii").lower().rstrip("=")


class IIIFContentURI(unittest.TestCase):
    def test_named_wire_fields_join_exact_declared_hash_without_retrieval(self):
        # Multiformats CID specification's human-readable raw sha2-256 example.
        # Header bytes are independently named here, not imported from production.
        raw = bytes.fromhex("01" "55" "12" "20" + DIGEST)
        value = uri(raw)
        with patch("socket.socket", side_effect=AssertionError("no network")):
            facts = content_uri_facts(value, DIGEST)
        self.assertTrue(facts["rawDigestAgreement"])
        self.assertFalse(facts["bytesRetrieved"])

    def test_wrong_version_codec_hash_length_and_digest_reject(self):
        raw = bytes.fromhex("01551220" + DIGEST)
        for index, replacement in ((0, 0), (1, 0x70), (2, 0x13), (3, 31)):
            mutant = bytearray(raw); mutant[index] = replacement
            with self.subTest(index=index), self.assertRaises(MuseumError):
                content_uri_facts(uri(mutant), DIGEST)
        with self.assertRaisesRegex(MuseumError, "differs from declared"):
            content_uri_facts(uri(raw), "00" * 32)
        self.assertTrue(content_uri_facts(uri(raw), DIGEST)["rawDigestAgreement"])

    def test_noncanonical_bits_case_and_path_do_not_normalize(self):
        value = uri(bytes.fromhex("01551220" + DIGEST))
        alphabet = "abcdefghijklmnopqrstuvwxyz234567"
        bad_tail = alphabet[alphabet.index(value[-1]) + 1]
        for mutant in (value[:-1] + bad_tail, value.upper(), value + "/file", value + "?x=1", value + "#x", value + "\n"):
            with self.subTest(value=mutant), self.assertRaises(MuseumError):
                content_uri_facts(mutant, DIGEST)
        for digest in (DIGEST.upper(), "0x" + DIGEST, DIGEST + "\n"):
            with self.assertRaises(MuseumError):
                content_uri_facts(value, digest)

    def test_arweave_transaction_identity_does_not_claim_raw_digest_agreement(self):
        txid = base64.urlsafe_b64encode(bytes(range(32))).decode().rstrip("=")
        facts = content_uri_facts("ar://" + txid, DIGEST)
        self.assertIsNone(facts["rawDigestAgreement"])
        self.assertFalse(facts["bytesRetrieved"])
        alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
        bad = txid[:-1] + alphabet[alphabet.index(txid[-1]) + 1]
        for tail in (bad, txid + "=", txid + "/file", txid + "\n", txid[:-1]):
            with self.subTest(tail=tail), self.assertRaises(MuseumError):
                content_uri_facts("ar://" + tail, DIGEST)

    def test_https_data_and_unsupported_ipfs_codecs_are_explicit(self):
        for value in ("https://example.org/file.mp4", "data:text/html,test", "ipfs://Qmexample", "javascript:alert(1)", None):
            with self.subTest(value=value), self.assertRaises(MuseumError):
                content_uri_facts(value, DIGEST)


if __name__ == "__main__":
    unittest.main()
