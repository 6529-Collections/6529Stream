"""Synthetic planner-only controls for registered-host/native catalogue joins."""
from copy import deepcopy
import unittest

from .canonical import MuseumError, keccak256
from . import object_dossier_native as native


def A(number):
    return "0x" + number.to_bytes(20, "big").hex()


def H(label):
    return keccak256(str(label).encode())


def host(address, kind, scopes, *, status="ACTIVE", supported=True, runtime=True,
         resolution="verified_within_current_registry", heads=()):
    return {"host": address, "kind": kind, "scopes": list(scopes), "status": status,
        "supported": supported, "runtimeMatches": runtime, "runtimeHash": H(address),
        "resolution": resolution, "catalog": {"scopeHeads": list(heads)}}


def roster(rows, *, provenance="trusted_rpc"):
    return {"kind": "hosts", "anchor": {"core": A(1), "tokenId": "7"},
        "snapshot": {"hosts": rows}, "provenance": provenance,
        "input": {"id": "registered-roster"}}


def catalogue(kind, address, scope, *, heads=(), policies=(), provenance="trusted_rpc",
              identifier=None, runtime=None):
    anchor = {"host": address, "codePins": [{"address": address,
        "runtimeHash": runtime or H(address)}]}
    anchor["tokenId" if kind == "owner" else
           "scopeKey" if kind == "independent" else "collectionId"] = scope
    return {"kind": kind, "anchor": anchor,
        "snapshot": {"lanes": list(heads), "catalog": list(policies)},
        "provenance": provenance, "input": {"id": identifier or kind + "-catalog"}}


def lane(record_type, scope, *, head=None, count="1", family=None, mask="256"):
    row = {"recordType": record_type, "scopeKey": scope,
        "chainHash": head or H(record_type + scope), "count": count}
    if family is not None:
        row.update(family=family, authorizationMask=mask)
    return row


class NativeRosterJoinTests(unittest.TestCase):
    """These unit vectors do not admit native evidence or claim chain acceptance."""

    def test_missing_owner_independent_both_scopes_and_metadata_are_denominated(self):
        rows = [host(A(2), "owner", ["7"], status="DEPRECATED"),
            host(A(3), "independent", ["0", "1"]),
            host(A(4), "metadata", ["1"], status="INCIDENT_REVOKED")]
        coverage, observed = native._coverage([roster(rows)], {})
        self.assertIsNotNone(observed)
        self.assertEqual([(r["kind"], r["scopeKey"], r["status"]) for r in coverage],
            [("owner", "7", "missing_source"), ("independent", "0", "missing_source"),
             ("independent", "1", "missing_source"), ("metadata", "1", "missing_source")])
        self.assertEqual([r["registryStatus"] for r in coverage],
            ["DEPRECATED", "ACTIVE", "ACTIVE", "INCIDENT_REVOKED"])

    def test_unsupported_future_and_changed_runtime_rows_are_retained(self):
        rows = [host(A(2), "owner", ["7"], supported=False,
                resolution="unsupported_registered_version"),
            host(A(3), "independent", ["0", "1"], runtime=False,
                resolution="runtime_changed_or_missing")]
        coverage, _ = native._coverage([roster(rows)], {})
        self.assertEqual([(r["host"], r["scopeKey"], r["status"]) for r in coverage],
            [(A(2), "7", "unsupported_host"), (A(3), "0", "unsupported_host"),
             (A(3), "1", "unsupported_host")])
        self.assertTrue(all(r["rosterSourceId"] == "registered-roster" for r in coverage))

    def test_trust_status_requires_both_roster_and_catalogue_to_be_nonsynthetic(self):
        record_type = H("independent-type")
        cases = (("trusted_rpc", "trusted_rpc", "verified_within_registered_roster"),
            ("synthetic_fixture", "trusted_rpc", "synthetic_only"),
            ("trusted_rpc", "synthetic_fixture", "synthetic_only"),
            ("synthetic_fixture", "synthetic_fixture", "synthetic_only"))
        for roster_mode, catalog_mode, expected in cases:
            address = A(2); expected_lane = lane(record_type, "1")
            source_lane = {k: expected_lane[k] for k in ("recordType", "chainHash", "count")}
            sources = [roster([host(address, "independent", ["1"], heads=[expected_lane])],
                              provenance=roster_mode),
                catalogue("independent", address, "1", heads=[source_lane],
                          provenance=catalog_mode)]
            with self.subTest(roster=roster_mode, catalog=catalog_mode):
                coverage, _ = native._coverage(sources, {})
                self.assertEqual(coverage[0]["status"], expected)

    def test_head_count_and_metadata_policy_conflicts_fail_closed(self):
        independent_type = H("independent-type"); metadata_type = H("metadata-type")
        family = H("family")
        independent_expected = lane(independent_type, "1")
        metadata_expected = lane(metadata_type, "1", family=family)
        independent_source = {k: independent_expected[k]
            for k in ("recordType", "chainHash", "count")}
        metadata_source = {k: metadata_expected[k]
            for k in ("recordType", "chainHash", "count")}
        policy = {k: metadata_expected[k]
            for k in ("recordType", "family", "authorizationMask")}
        base = [roster([host(A(2), "independent", ["1"], heads=[independent_expected]),
                        host(A(3), "metadata", ["1"], heads=[metadata_expected])]),
            catalogue("independent", A(2), "1", heads=[independent_source]),
            catalogue("metadata", A(3), "1", heads=[metadata_source], policies=[policy])]
        self.assertEqual([r["status"] for r in native._coverage(base, {})[0]],
            ["verified_within_registered_roster", "verified_within_registered_roster"])
        mutations = []
        changed = deepcopy(base); changed[1]["snapshot"]["lanes"][0]["chainHash"] = H("other")
        mutations.append(("head", changed))
        changed = deepcopy(base); changed[1]["snapshot"]["lanes"][0]["count"] = "2"
        mutations.append(("count", changed))
        changed = deepcopy(base); changed[2]["snapshot"]["catalog"][0]["family"] = H("other")
        mutations.append(("policy", changed))
        for label, sources in mutations:
            with self.subTest(label=label), self.assertRaises(MuseumError):
                native._coverage(sources, {})

    def test_source_runtime_conflict_and_catalogue_for_unsupported_host_reject(self):
        expected = lane(H("type"), "1")
        source_lane = {k: expected[k] for k in ("recordType", "chainHash", "count")}
        base_host = host(A(2), "independent", ["1"], heads=[expected])
        wrong_runtime = catalogue("independent", A(2), "1", heads=[source_lane],
            runtime=H("wrong-runtime"))
        with self.assertRaisesRegex(MuseumError, "runtime differs"):
            native._coverage([roster([base_host]), wrong_runtime], {})
        unsupported = deepcopy(base_host); unsupported["supported"] = False
        unsupported["resolution"] = "unsupported_registered_version"
        with self.assertRaisesRegex(MuseumError, "unsupported roster host"):
            native._coverage([roster([unsupported]),
                catalogue("independent", A(2), "1", heads=[source_lane])], {})

    def test_duplicate_host_scope_in_roster_rejects_instead_of_collapsing(self):
        repeated = host(A(2), "owner", ["7"])
        with self.assertRaisesRegex(MuseumError, "duplicate roster host/scope"):
            native._coverage([roster([repeated, deepcopy(repeated)])], {})
        one = host(A(2), "independent", ["0", "0"])
        with self.assertRaisesRegex(MuseumError, "duplicate roster host/scope"):
            native._coverage([roster([one])], {})

    def test_synthetic_catalogue_outside_roster_remains_synthetic_only(self):
        source = catalogue("owner", A(9), "7", provenance="synthetic_fixture")
        coverage, observed = native._coverage([source], {})
        self.assertIsNone(observed)
        self.assertEqual(coverage, [{"host": A(9), "kind": "owner", "scopeKey": "7",
            "status": "synthetic_only", "sourceId": "owner-catalog",
            "rosterSourceId": None, "registryStatus": None}])


if __name__ == "__main__":
    unittest.main()
