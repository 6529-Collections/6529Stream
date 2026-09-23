"""Original inventory prefixes are complete, ordered and independent of later burns."""
from copy import deepcopy
import unittest

from . import policy_membership_v2 as membership
from .canonical import MuseumError, subject_id
from .independent_wire import ZERO, json_values
from .test_native_policy_finality_wire_v2 import supplied


def fixture():
    _, context, graph, _ = supplied()
    tokens, serials = (41, 44, 49), (3, 7, 12)
    prefix = membership.base._hash("6529STREAM_TOKEN_INVENTORY_V1",
        ("uint256", "address", "address", "uint256"),
        (31337, graph["tokenInventory"]["address"], graph["core"]["address"], 1))
    for serial, token in zip(serials, tokens):
        prefix = membership.base._hash("6529STREAM_TOKEN_INVENTORY_APPEND_V1",
            ("bytes32", "uint256", "uint256"), (prefix, serial, token))
    facts = [subject_id("collection", "31337", graph["core"]["address"], "1"),
        ZERO, ZERO, 3, ZERO, ZERO, 3, prefix]
    facts[5] = membership.membership_hash(tuple(facts), (0, 1, 0, ZERO), context, graph)
    value = {"facts": facts, "inventoryState": (3, prefix), "tokens": tokens,
        "identities": [(True, 1, serial, False) for serial in serials],
        "lifecycles": [2]*3, "serialTokens": tokens}
    value = {key: json_values(row) for key, row in value.items()}
    return value, context, graph


class PolicyMembershipTests(unittest.TestCase):
    def verify(self, value, context, graph):
        return membership.validate(value, context, graph, value["facts"], value["tokens"])

    def test_actual_serial_gaps_and_complete_prefix(self):
        value, context, graph = fixture()
        result = self.verify(value, context, graph)
        self.assertEqual(result["originalCount"], "3")
        self.assertEqual(result["tokenIds"], ["41", "44", "49"])
        self.assertEqual(result["prefixHashes"][-1], value["facts"][7])
        self.assertEqual(len(membership.expected_events(value, context, graph)), 3)
        self.assertFalse(result["currentCompletenessVerified"])

    def test_later_burn_and_later_inventory_do_not_rewrite_original(self):
        value, context, graph = fixture()
        original = self.verify(value, context, graph)
        value["identities"][0][3], value["lifecycles"][0] = True, "3"
        value["inventoryState"] = ["4", membership.base.schema_id("later prefix")]
        self.assertEqual(self.verify(value, context, graph), original)

    def test_omission_duplicates_wrong_serial_and_wrong_lifecycle_reject(self):
        original, context, graph = fixture()
        for mode in ("omit", "duplicate", "serial", "reverse", "lifecycle", "mapping", "collection"):
            value = deepcopy(original)
            if mode == "omit": value["identities"].pop()
            elif mode == "duplicate": value["tokens"][1] = value["tokens"][0]
            elif mode == "serial": value["identities"][1][2] = "8"
            elif mode == "reverse": value["identities"][1][2] = "2"
            elif mode == "lifecycle": value["lifecycles"][0] = "3"
            elif mode == "mapping": value["serialTokens"][0] = "44"
            else: value["identities"][0][1] = "2"
            with self.subTest(mode=mode), self.assertRaises(MuseumError): self.verify(value, context, graph)

    def test_original_snapshot_and_output_order_are_external_constraints(self):
        value, context, graph = fixture()
        facts = deepcopy(value["facts"]); facts[7] = membership.base.schema_id("different prefix")
        with self.assertRaisesRegex(MuseumError, "original membership"):
            membership.validate(value, context, graph, facts, value["tokens"])
        with self.assertRaisesRegex(MuseumError, "selection order"):
            membership.validate(value, context, graph, value["facts"], list(reversed(value["tokens"])))

    def test_smaller_or_contradictory_current_inventory_and_outside_target_reject(self):
        original, context, graph = fixture()
        for state in (["2", original["facts"][7]], ["3", membership.base.schema_id("wrong")], ["4", ZERO]):
            value = deepcopy(original); value["inventoryState"] = state
            with self.subTest(state=state), self.assertRaisesRegex(MuseumError, "current inventory"):
                self.verify(value, context, graph)
        context["tokenId"] = "42"
        with self.assertRaisesRegex(MuseumError, "outside original"): self.verify(original, context, graph)


if __name__ == "__main__": unittest.main()
