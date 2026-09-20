"""Coherence controls for the combined scoped policy V2 fixture."""
from copy import deepcopy
import unittest

from . import scoped_policy_content_wire_v2 as content
from . import scoped_policy_factory_v2 as factory
from . import scoped_policy_membership_v2 as membership
from . import scoped_policy_preservation_wire_v2 as preservation
from . import native_scoped_policy_finality_wire_v2 as native
from .canonical import MuseumError
from . import public_scoped_policy_finality_capture_v2 as capture
from .scoped_policy_finality_fixture_v2 import ScopedPolicyFinalityFixtureV2


class ScopedPolicyFinalityFixtureTests(unittest.TestCase):
    def test_pure_bundle_all_three_scopes(self):
        for scope_type, count in ((1, 1), (2, 3), (3, 30)):
            with self.subTest(scope_type=scope_type):
                fixture = ScopedPolicyFinalityFixtureV2(scope_type=scope_type, count=count)
                bundle = fixture.pure_bundle()
                result = content.validate(bundle["content"], fixture.policy_context,
                    fixture.policy_graph, bundle["statement"])
                preserved = preservation.validate({"snapshot": bundle["snapshot"],
                    "reference": bundle["reference"]}, fixture.policy_context,
                    fixture.policy_graph, None, result)
                self.assertEqual(len(result["tokenIds"]), count)
                self.assertEqual(preserved["source"][0][0], str(scope_type))

    def test_actual_membership_and_current_burn_are_distinct(self):
        fixture = ScopedPolicyFinalityFixtureV2(scope_type=2, count=3, burned=True)
        group = fixture.scoped_policy_membership
        result = membership.validate(group, fixture.policy_context, fixture.policy_graph,
            fixture.scoped_policy_statement[0], group["facts"],
            fixture.scoped_policy_content_result["tokenIds"])
        self.assertTrue(result["identityObservations"][0]["burned"])
        self.assertEqual(result["facts"], group["facts"])

    def test_factory_graph_is_exactly_the_content_graph(self):
        fixture = ScopedPolicyFinalityFixtureV2(scope_type=3, count=3)
        value = fixture.scoped_policy_factory
        result = factory.validate(value, fixture.policy_context,
            fixture.policy_graph, fixture.scoped_policy_statement[0])
        self.assertEqual(result["graph"][1],
            fixture.scoped_policy_preservation["snapshot"]["source"][9][0])
        self.assertFalse(result["currentEligibilityChecked"])

    def test_cross_helper_scope_or_membership_relabel_rejects(self):
        fixture = ScopedPolicyFinalityFixtureV2(scope_type=2, count=3)
        changed = deepcopy(fixture.scoped_policy_content)
        changed["checkpoint"]["selectionPlan"][1] = "0x" + "01" * 32
        with self.assertRaises(MuseumError):
            content.validate(changed, fixture.policy_context, fixture.policy_graph,
                fixture.scoped_policy_statement)

    def test_constructor_bounds(self):
        for kwargs in ({"scope_type": 0}, {"scope_type": 1, "count": 2},
                {"scope_type": 2, "count": 0}):
            with self.subTest(kwargs=kwargs), self.assertRaises(ValueError):
                ScopedPolicyFinalityFixtureV2(**kwargs)

    def test_concrete_source_and_offline_capture_reconstruct(self):
        fixture = ScopedPolicyFinalityFixtureV2(scope_type=1, burned=True)
        result = fixture.policy_result()
        native.validate_bundle(result["bundle"], fixture.policy_context,
            fixture.policy_graph)
        self.assertTrue(result["identity"]["burned"])
        package = fixture.policy_capture()
        rebuilt = capture.verify(dict(package.files), package.manifest_hash)
        self.assertEqual(rebuilt.files, package.files)


if __name__ == "__main__":
    unittest.main()
