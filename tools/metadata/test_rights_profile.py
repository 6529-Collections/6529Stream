"""Independent schema and RFC8785 fixture validation using the pinned museum runtime."""

import copy
import json
import unittest

import jsonschema
import rfc8785

from . import rights_profile as p


class RightsProfile(unittest.TestCase):
    def test_generated_documents_are_exact_jcs_and_schema_is_complete(self):
        for name, value in p.outputs().items():
            self.assertEqual((p.ROOT / name).read_bytes(), rfc8785.dumps(value), name)
        jsonschema.Draft202012Validator.check_schema(p.schema())
        validator = jsonschema.Draft202012Validator(p.schema())
        for example in p.examples():
            validator.validate(example)

    def test_every_mandatory_field_and_use_class_is_required(self):
        validator = jsonschema.Draft202012Validator(p.schema())
        base, _ = p.examples()
        for field in base:
            value = copy.deepcopy(base)
            del value[field]
            self.assertFalse(validator.is_valid(value), field)
        for use in p.USES:
            value = copy.deepcopy(base)
            del value["grants"][use]
            self.assertFalse(validator.is_valid(value), use)

    def test_unknown_field_branch_and_vocabulary_are_rejected(self):
        validator = jsonschema.Draft202012Validator(p.schema())
        base, _ = p.examples()
        mutations = [
            lambda v: v.update(extra="not silently discarded"),
            lambda v: v["grants"].update(other=v["grants"]["print"]),
            lambda v: v.update(basis="other"),
            lambda v: v["grants"]["print"].update(status="permission granted"),
            lambda v: v["grants"]["print"].update(status="granted_with_conditions"),
            lambda v: v.update(AI_TRAINING_PERMISSION="denied"),
            lambda v: v["licensor"]["identity"].update(name="second active branch"),
        ]
        for change in mutations:
            value = copy.deepcopy(base)
            change(value)
            self.assertFalse(validator.is_valid(value))

    def test_all_statuses_and_explicit_optional_ai_field(self):
        validator = jsonschema.Draft202012Validator(p.schema())
        for status in p.STATUS:
            value, _ = p.examples()
            value["AI_TRAINING_PERMISSION"] = status
            value["grants"]["ai_training"]["status"] = status
            if status == "granted_with_conditions":
                value["grants"]["ai_training"]["conditions"] = {"kind": "text", "text": "Authored condition"}
            validator.validate(value)

    def test_unicode_and_large_integer_oracle(self):
        value = {"control": '\"\\\b\f\n\r\t\x00\x1f', "text": "é𝄞", "uint256": str((1 << 256) - 1)}
        standard = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
        self.assertEqual(standard, rfc8785.dumps(value))


if __name__ == "__main__":
    unittest.main()
