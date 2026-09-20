"""Scoped identities retain the original six-family native STATIC algorithm."""
from copy import deepcopy
import unittest

from . import scoped_policy_static_components_v2 as wire
from .canonical import MuseumError
from .independent_wire import ZERO
from .test_policy_static_components_v2 import Fixture as OriginalFixture, ReadHarness as OriginalReads, H


class Fixture(OriginalFixture):
    def __init__(self, kind=2, count=3):
        super().__init__(count=1 if kind == 1 else count)
        self.scope = (kind, 7, 41 if kind == 1 else 0, ZERO if kind == 1 else H("scope"))
        self.authenticated = (self.scope, *self.authenticated[1:])
        self.plan = (self.scope, *self.plan[1:])
        self.expectations = self._expectations()

    def mixin_inputs(self):
        snapshot, content, statement = super().mixin_inputs()
        snapshot["source"].append(())
        return snapshot, content, (*statement[:9], 1, 1, 1)


class Reads(wire.ScopedPolicyStaticReads, OriginalReads):
    pass


class ScopedPolicyStaticTests(unittest.TestCase):
    def test_three_scopes_and_complete_six_families(self):
        for kind in (1, 2, 3):
            value = Fixture(kind).value()
            result = wire.validate(value)
            self.assertEqual(len(result["families"]), 6)
            self.assertEqual(result["tokenCount"], "1" if kind == 1 else "3")
            self.assertFalse(result["currentSourceRevalidated"])

    def test_collection_view_and_scope_relabeling_reject(self):
        for kind in (0, 4):
            with self.subTest(kind=kind), self.assertRaises(MuseumError): wire.validate(Fixture(kind).value())
        value = Fixture(2).value()
        value["authenticated"] = ((3, *value["authenticated"][0][1:]), *value["authenticated"][1:])
        value["plan"] = (value["authenticated"][0], *value["plan"][1:])
        with self.assertRaisesRegex(MuseumError, "data hash"): wire.validate(value)

    def test_exact_stored_reads_do_not_consult_current_projection(self):
        f = Fixture(3); reader = Reads(f)
        value = reader._static_components(*f.mixin_inputs())
        self.assertEqual(value["authenticated"][0][0], "3")
        self.assertEqual(wire.validate(value)["uniqueConfigRecords"], "1")
        self.assertEqual(sum(sig == "staticRenderSourceForConfig(uint256,bytes32)" for _, sig, _ in reader.calls), 1)

    def test_original_source_change_cannot_keep_saved_expectations(self):
        value = deepcopy(Fixture().value())
        raw = list(value["originals"][0]["rawSource"]); raw[6] += " changed"
        value["originals"][0]["rawSource"] = raw
        with self.assertRaises(MuseumError): wire.validate(value)


if __name__ == "__main__": unittest.main()
