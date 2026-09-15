"""Independent literal WORK definition hashes and generated-source identity."""

import unittest

from . import work_definitions as pins
from .work_profile import digest


class WorkDefinitionsTests(unittest.TestCase):
    def test_five_original_documents_have_the_accepted_hashes_and_lengths(self):
        expected = [
            (11481, "0xc534a4212c652d620942266ff32d8699bcc40492aa9a323e0f5b711bbc5bba88"),
            (2350, "0x1c5e8281a5c12e06b334020bc158dc101dd33baaa449feeb8f504e20bd910353"),
            (1720, "0xa2c03300254919dad0436cffd743bc869665f06434123b92ae48c5ff98a284ed"),
            (957, "0x03799bc44aab386d3032a5859e6e7b7f6558bdb279f0e9906d3af535274a6514"),
            (362, "0xbc33af15c6b6374052871a5fdfa255f900f56fa594f650b2d0814c681fdb35a9"),
        ]
        self.assertEqual(len(pins.DOCUMENTS), 5)
        for (_, _, path), (length, hash_) in zip(pins.DOCUMENTS, expected):
            raw = (pins.ROOT / path).read_bytes()
            self.assertEqual((len(raw), digest(raw)), (length, hash_))

    def test_generated_solidity_is_exact_and_contains_all_distinct_identities(self):
        raw = pins.generated()
        self.assertEqual(raw, pins.TARGET.read_bytes())
        self.assertEqual(len({name for _, name, _ in pins.DOCUMENTS}), 5)
        for label, name, _ in pins.DOCUMENTS:
            self.assertIn(f'{label}_ID=keccak256("{name}")', "".join(raw.decode().split()))


if __name__ == "__main__":
    unittest.main()
