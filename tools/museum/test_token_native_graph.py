"""Offline guard checks for exact native graph runtime prediction."""
import copy
import unittest

from .canonical import MuseumError
from .token_native_graph import predicted_runtime, TokenNativeGraphMixin


def declaration(name, variables):
    return {"ast": {"nodes": [{"nodeType": "ContractDefinition", "name": name, "nodes": [
        {"nodeType": "VariableDeclaration", "name": key, "id": identifier, "mutability": "immutable"}
        for key, identifier in variables.items()
    ]}]}}


class RuntimePredictionTests(unittest.TestCase):
    def setUp(self):
        self.products = {"Host": declaration("Host", {"authority": 11}), "Base": declaration("Base", {"chain": 22})}
        self.products["Host"]["deployedBytecode"] = {"immutableReferences": {
            "11": [{"start": 1, "length": 32}, {"start": 66, "length": 32}],
            "22": [{"start": 34, "length": 32}],
        }}
        self.template = b"\x60" + bytes(32) + b"\x61" + bytes(64) + b"\x00"
        self.address = "0x" + "ab" * 20
        self.values = {("Host", "authority"): self.address, ("Base", "chain"): 31337}

    def test_exact_runtime_preserves_opcodes_and_patches_all_copies(self):
        actual = predicted_runtime(self.products, "Host", self.template, self.values)
        word = bytes(12) + bytes.fromhex("ab" * 20)
        self.assertEqual(actual, b"\x60" + word + b"\x61" + (31337).to_bytes(32, "big") + word + b"\x00")

    def test_missing_assignment_is_rejected(self):
        with self.assertRaisesRegex(MuseumError, "assignment inventory"):
            predicted_runtime(self.products, "Host", self.template, {("Host", "authority"): self.address})

    def test_extra_assignment_is_rejected(self):
        self.products["Other"] = declaration("Other", {"extra": 33})
        with self.assertRaisesRegex(MuseumError, "assignment inventory"):
            predicted_runtime(self.products, "Host", self.template, self.values | {("Other", "extra"): 1})

    def test_ambiguous_declaration_is_rejected(self):
        self.products["Base"]["ast"]["nodes"] *= 2
        with self.assertRaisesRegex(MuseumError, "declaration missing"):
            predicted_runtime(self.products, "Host", self.template, self.values)

    def test_duplicate_ast_id_is_rejected(self):
        self.products["Base"]["ast"]["nodes"][0]["nodes"][0]["id"] = 11
        with self.assertRaisesRegex(MuseumError, "duplicate graph immutable"):
            predicted_runtime(self.products, "Host", self.template, self.values)

    def test_bad_offset_width_and_overlap_are_rejected(self):
        for replacement, message in (({"start": -1, "length": 32}, "offset"),
                                      ({"start": 98, "length": 32}, "offset"),
                                      ({"start": 34, "length": 31}, "offset"),
                                      ({"start": 10, "length": 32}, "overlap")):
            with self.subTest(replacement=replacement):
                products = copy.deepcopy(self.products)
                products["Host"]["deployedBytecode"]["immutableReferences"]["22"] = [replacement]
                with self.assertRaisesRegex(MuseumError, message):
                    predicted_runtime(products, "Host", self.template, self.values)

    def test_empty_positions_and_bad_words_are_rejected(self):
        products = copy.deepcopy(self.products)
        products["Host"]["deployedBytecode"]["immutableReferences"]["22"] = []
        with self.assertRaisesRegex(MuseumError, "empty graph immutable"):
            predicted_runtime(products, "Host", self.template, self.values)
        for word in (-1, 2**256, "0xabcd"):
            with self.subTest(word=word), self.assertRaises(MuseumError):
                predicted_runtime(self.products, "Host", self.template, self.values | {("Base", "chain"): word})

    def test_repeated_product_requires_explicit_new_instance(self):
        fixture = TokenNativeGraphMixin()
        fixture.addresses = {"StreamDeploymentSlot": self.address}
        with self.assertRaisesRegex(MuseumError, "instance already deployed"):
            fixture.deploy_graph_product("StreamDeploymentSlot", (self.address,))


if __name__ == "__main__":
    unittest.main()
