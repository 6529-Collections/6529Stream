"""Cross-domain regressions over explicit synthetic original scoped evidence."""
from copy import deepcopy
import unittest

from . import native_scoped_policy_finality_wire_v2 as wire
from . import scoped_policy_factory_v2 as factory
from .canonical import MuseumError
from .independent_wire import json_values
from .scoped_policy_finality_fixture_v2 import ScopedPolicyFinalityFixtureV2


class ScopedPolicyIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = ScopedPolicyFinalityFixtureV2(scope_type=2, count=3)

    def test_incremental_preparation_before_each_consumer(self):
        f = self.fixture
        report = wire.validate_event_join(f.policy_bundle, f.policy_context, f.policy_graph, f.policy_events)
        self.assertTrue(report["originalPublicationChronologyChecked"])
        rows = f.policy_events
        child2 = next(i for i,r in enumerate(rows) if r["log"]["topics"][0] == factory.CHILD_EVENT
            and int(r["log"]["topics"][3],16) == 2)
        from .scoped_policy_content_wire_v2 import EVENTS
        completed = next(i for i,r in enumerate(rows) if r["log"]["topics"][0] == EVENTS["contentCompleted"])
        self.assertLess(completed,child2)

    def test_child_must_exist_before_its_consumer(self):
        from .scoped_policy_content_wire_v2 import EVENTS
        f=self.fixture
        for index,after in ((1,EVENTS["contentStarted"]),(6,EVENTS["binding"])):
            rows=deepcopy(f.policy_events)
            positions=[r["log"]["logIndex"] for r in rows]
            i=next(i for i,r in enumerate(rows) if r["log"]["topics"][0] == factory.CHILD_EVENT
                and int(r["log"]["topics"][3],16) == index)
            row=rows.pop(i)
            j=next(i for i,r in enumerate(rows) if r["log"]["topics"][0] == after)
            rows.insert(j+1,row)
            for r,position in zip(rows,positions):r["log"]["logIndex"]=position
            with self.subTest(child=index),self.assertRaisesRegex(MuseumError,"chronology"):
                wire.validate_event_join(f.policy_bundle,f.policy_context,f.policy_graph,rows)

    def test_monotonic_publication_gas_raise_preserves_original_evidence(self):
        f=self.fixture;b=deepcopy(f.policy_bundle)
        for group in ("snapshot","reference"):
            b[group]["dependencies"][3:]=[str(int(v)+10000) for v in b[group]["dependencies"][3:]]
        wire.validate_bundle(b,f.policy_context,f.policy_graph)
        for group in ("snapshot","reference"):
            self.assertEqual(b[group]["payload"],f.policy_bundle[group]["payload"])
        self.assertEqual(b["content"]["roots"],f.policy_bundle["content"]["roots"])

    def test_child_budget_cannot_fall_below_creation_recipe(self):
        f=self.fixture;b=deepcopy(f.policy_bundle)
        minimum=b["factory"]["childDependencies"]["policySnapshot"]
        b["snapshot"]["dependencies"][3:]=minimum[3:]
        b["snapshot"]["dependencies"][4]=str(int(minimum[4])-1)
        with self.assertRaisesRegex(MuseumError,"minimum budgets"):
            wire.validate_bundle(b,f.policy_context,f.policy_graph)

    def test_rehashed_factory_dependency_split_is_rejected(self):
        f=self.fixture;b=deepcopy(f.policy_bundle);v=b["factory"]
        v["sourceFactoryDependencies"][-1]=str(int(v["sourceFactoryDependencies"][-1])+1)
        v["sourceFactoryDependenciesHash"]=factory.dependencies_hash(v["sourceFactoryDependencies"])
        v["graph"][4]=factory.graph_id(v["chainId"],v["factory"],v["recipeHash"],v["sourceFactoryDependenciesHash"],v["graph"])
        for row in v["preparationEvents"]:row["graphId"]=v["graph"][4]
        c=b["provider"]["configuration"];c["factoryBinding"][3]=v["sourceFactoryDependenciesHash"]
        profiles,binding,digest=wire.provider_hashes(c["originalConfiguration"],c["scopedConfiguration"],c["policyConfiguration"],
            c["collectionPolicyOutput"],c["factoryBinding"],int(f.policy_context["chainId"]),f.policy_graph["provider"]["address"])
        c["profiles"],c["factoryBinding"],c["sourceConfigurationHash"]=json_values(profiles),json_values(binding),digest
        b["provider"]["discoverySourceConfigurationHash"]=digest
        wire.validate_provider(c,f.policy_context,f.policy_graph,v)
        with self.assertRaisesRegex(MuseumError,"shared source factory dependency tuple"):
            wire.validate_bundle(b,f.policy_context,f.policy_graph)


if __name__ == "__main__":unittest.main()
