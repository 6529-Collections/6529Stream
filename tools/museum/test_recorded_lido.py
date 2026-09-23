"""Recorded source admission and explicit synthetic publisher/rendering controls."""
import copy
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError,dumps,keccak256,loads
from .recorded_lido import MODE,PUBLISHER,PROFILE_BYTES,PROFILE_HASH,_availability,project_recorded_lido
from .lido import _project_selected_work
from .lido_model import PinnedLIDO,PROFILE_BYTES as OLD_BYTES,PROFILE_HASH as OLD_HASH,NS
from .iiif import project_iiif_fixture
from .semantic_selection import select_canonical_fixture
from .package import write_package
from .package_recorded import build_recorded_package
from .package_v2 import verify_package
from . import test_recorded_iiif as recorded_iiif_tests
from .test_recorded_account import ROOT,FIXTURE
from .test_package_recorded import inputs,pins
from .test_package import changed
from .test_lido import source_data,arguments,source_document,ISSUER
from .test_projection import entity
from .test_projection_v2 import assertion

EXAMPLES=ROOT/"lido-recorded"
PUBLISHER_ID="urn:fixture:declared-publisher"


class RecordedLIDO(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        recorded_iiif_tests.RecordedIIIF.setUpClass()
        cls.base=recorded_iiif_tests.RecordedIIIF()
        cls.schema=PinnedLIDO(ROOT,OLD_BYTES,profile_hash=OLD_HASH)
        cls.iiif_plan=(ROOT/"iiif-recorded/missing-presentation-plan.json").read_bytes()

    def plan_for(self,**updates):
        return {"mode":MODE,"version":"1","sourceStateHash":self.base.base.source.state.commitment,
            "profileHash":self.base.base.source.profile_hash,"linkedArtPlanHash":keccak256(self.base.base.plan),
            "premisPlanHash":keccak256(self.base.premis_plan),"iiifPlanHash":keccak256(self.iiif_plan),
            "lidoProfileHash":PROFILE_HASH,"recordId":"https://example.org/lido/recorded/record"}|updates

    def project(self,plan=None,**updates):
        raw=dumps(self.plan_for() if plan is None else plan)
        return project_recorded_lido(self.base.base.source,self.base.base.selection,self.base.base.plan,
            self.base.premis_plan,self.iiif_plan,raw,**(self.base.kwargs()|{
                "iiif_plan_hash":keccak256(self.iiif_plan),"lido_plan_hash":keccak256(raw),
                "lido_profile_hash":PROFILE_HASH,"lido_schema":self.schema}|updates))

    def test_actual_capture_is_unsupported_without_promoting_account_to_legal_body(self):
        with patch("socket.socket",side_effect=AssertionError("network")): result=self.project()
        self.assertIsNone(result.projection)
        report=loads(result.report,maximum=67108864)
        self.assertEqual(report["status"],"unsupported")
        self.assertEqual(report["issues"][0]["reasonCode"],"recorded_iiif_unavailable")
        missing=[i for i in report["issues"] if i["reasonCode"]=="missing_selected_publisher_assertion"]
        self.assertTrue(missing)
        self.assertTrue(all(i["relation"]==PUBLISHER for i in missing))
        self.assertEqual(report["sourceEvidence"]["environment"],"local_evm_fixture")
        self.assertFalse(any(report["claims"].values()))
        self.assertEqual(self.base.base.source.capture_bytes,(FIXTURE/"source-capture.json").read_bytes())

    def test_exact_profile_scope_and_identity_rejections(self):
        for update in ({"mode":"synthetic_lido_projection"},{"version":"2"},{"sourceStateHash":OLD_HASH},
            {"profileHash":OLD_HASH},{"linkedArtPlanHash":OLD_HASH},{"premisPlanHash":OLD_HASH},
            {"iiifPlanHash":OLD_HASH},{"lidoProfileHash":OLD_HASH}):
            with self.subTest(update=update),self.assertRaisesRegex(MuseumError,"scope mismatch"):self.project(self.plan_for(**update))
        with self.assertRaisesRegex(MuseumError,"hash mismatch"):self.project(lido_profile_hash=OLD_HASH)
        with self.assertRaisesRegex(MuseumError,"hash mismatch"):self.project(lido_plan_hash=OLD_HASH)
        for record_id in ("urn:local:semantic:work","https://example.org/iiif/recorded/manifest"):
            with self.assertRaisesRegex(MuseumError,"aliases"):self.project(self.plan_for(recordId=record_id))
        with self.assertRaisesRegex(MuseumError,"verified recorded"):
            project_recorded_lido(source_data()[0],b"",b"",b"",b"",b"",lido_plan_hash=OLD_HASH,
                lido_profile_hash=PROFILE_HASH,lido_schema=self.schema)

    def synthetic(self,publisher=True,mutate=None):
        # Original synthetic source evidence stays synthetic; this is not a recorded positive capture.
        doc=source_document(source_data())
        doc["entities"]=[e for e in doc["entities"] if e["id"]!=ISSUER]
        doc["entities"].append(entity(PUBLISHER_ID,"group",[{"kind":"preferred","value":"Explicit publisher only","language":None}]))
        if publisher:doc["assertions"].append(assertion("record-publisher","work",PUBLISHER,{"entity":PUBLISHER_ID}))
        if mutate:mutate(doc)
        data=source_data(doc["assertions"],doc["entities"])
        data[1]["singleValuedRelations"].append(PUBLISHER)
        data[2]["selectionPolicyHash"]=keccak256(dumps(data[1]))
        args,kwargs=arguments(data,self.base.base.linked,self.base.base.schema,self.base.schema,self.schema)
        selected=select_canonical_fixture(data[0],args[1],policy_hash=kwargs["selection_hash"],profile_hash=kwargs["profile_hash"])
        return data,args,kwargs,selected

    def test_selected_publisher_is_distinct_from_account_and_actual_xsd_provenance_joins(self):
        data,args,kwargs,selected=self.synthetic()
        issues,publishers=_availability(data[0],selected,data[1],data[2]["entityAuthoritySet"],"urn:fixture:work")
        self.assertEqual(issues,[])
        self.assertEqual(set(publishers),{ISSUER})
        iiif=project_iiif_fixture(*args[:5],**{k:v for k,v in kwargs.items() if k not in ("lido_plan_hash","lido_profile")})
        plan=loads(args[5])|{"mode":MODE,"lidoProfileHash":PROFILE_HASH};raw=dumps(plan)
        result=_project_selected_work(data[0],iiif,selected,args[1],args[2],raw,
            **(kwargs|{"lido_plan_hash":keccak256(raw)}),mode=MODE,export_profile_hash=PROFILE_HASH,publishers=publishers)
        xml=self.schema.validate(result.xml);ns={"l":NS,"lido":NS}
        self.assertEqual(xml.xpath("//l:recordSource/l:legalBodyID/text()",namespaces=ns),[PUBLISHER_ID])
        self.assertEqual(xml.xpath("//l:recordSource/l:legalBodyName/l:appellationValue/text()",namespaces=ns),["Explicit publisher only"])
        rows=loads(result.correspondence,maximum=67108864)["sourceRecords"]
        self.assertEqual({r["issuer"] for r in rows},{ISSUER})
        self.assertEqual({r["declaredRecordPublisher"] for r in rows},{PUBLISHER_ID})
        proofs=[p for p in loads(result.provenance,maximum=67108864) if p["rule"]==PUBLISHER]
        self.assertTrue(proofs)
        self.assertTrue(all(p["issuer"]==ISSUER and p["sourcePointer"].endswith("/object/entity") for p in proofs))
        self.assertTrue(all(xml.xpath(p["targetXPath"],namespaces=ns)[0].text==PUBLISHER_ID for p in proofs))

    def test_missing_publisher_never_falls_back_to_creator_or_account(self):
        data,_,_,selected=self.synthetic(publisher=False)
        issues,publishers=_availability(data[0],selected,data[1],data[2]["entityAuthoritySet"],"urn:fixture:work")
        self.assertEqual(publishers,{})
        self.assertEqual(issues,[{"reasonCode":"missing_selected_publisher_assertion","entity":"urn:fixture:work","issuer":ISSUER,"relation":PUBLISHER}])

    def test_publisher_requires_selected_named_legal_body_and_rejects_account_alias_or_conflict(self):
        def unnamed(doc):next(e for e in doc["entities"] if e["id"]==PUBLISHER_ID)["names"]=[]
        data,_,_,selected=self.synthetic(mutate=unnamed)
        issues,_=_availability(data[0],selected,data[1],data[2]["entityAuthoritySet"],"urn:fixture:work")
        self.assertIn({"reasonCode":"explicit_und_compatible_names_required","entity":PUBLISHER_ID},issues)
        def alias(doc):next(a for a in doc["assertions"] if a["relation"]==PUBLISHER)["object"]={"entity":ISSUER}
        data,_,_,selected=self.synthetic(mutate=alias)
        with self.assertRaisesRegex(MuseumError,"distinct declared"):
            _availability(data[0],selected,data[1],data[2]["entityAuthoritySet"],"urn:fixture:work")
        def conflict(doc):doc["assertions"].append(assertion("other-publisher","work",PUBLISHER,{"entity":"urn:fixture:actual-creator"}))
        data,_,_,selected=self.synthetic(mutate=conflict)
        with self.assertRaisesRegex(MuseumError,"conflicting selected publishers"):
            _availability(data[0],selected,data[1],data[2]["entityAuthoritySet"],"urn:fixture:work")

    def test_each_contributing_account_needs_its_own_selected_publisher_statement(self):
        from .source import FixtureSourceAdapter
        from .test_review import record,row
        from .test_schema_inventory import assertion_document
        from .test_projection_v2 import literal
        data,_,kwargs,_=self.synthetic()
        other="urn:fixture:other-attestor"
        doc=assertion_document();doc["entities"]=[]
        first=assertion("other-account-note","work","urn:fixture:extra-note",literal("Another public source account"))
        publisher=assertion("other-account-publisher","work",PUBLISHER,{"entity":PUBLISHER_ID})
        for claim in (first,publisher):claim["assertingAgent"]=other
        doc["assertions"]=[first,publisher]
        additional=record(doc,"other-publisher-source",other,"artist",["200","0","0"])
        state=FixtureSourceAdapter("synthetic-publisher-control",tuple(data[0].records)+(additional,)).snapshot()
        policy=copy.deepcopy(data[1]);policy["sourceStateHash"]=state.commitment
        policy["sourceAuthoritySet"].append(row(additional))
        selected=select_canonical_fixture(state,dumps(policy),policy_hash=keccak256(dumps(policy)),profile_hash=kwargs["profile_hash"])
        issues,_=_availability(state,selected,policy,data[2]["entityAuthoritySet"],"urn:fixture:work")
        self.assertEqual(issues,[{"reasonCode":"missing_selected_publisher_assertion","entity":"urn:fixture:work","issuer":other,"relation":PUBLISHER}])
        policy["sourceAuthoritySet"].append(row(additional)|{"pointer":"/assertions/1"})
        selected=select_canonical_fixture(state,dumps(policy),policy_hash=keccak256(dumps(policy)),profile_hash=kwargs["profile_hash"])
        issues,publishers=_availability(state,selected,policy,data[2]["entityAuthoritySet"],"urn:fixture:work")
        self.assertEqual(issues,[])
        self.assertEqual(set(publishers),{ISSUER,other})

    def package(self,**updates):
        from .recorded_premis import PROFILE_HASH as PH
        from .recorded_iiif import PROFILE_HASH as IH
        raw=dumps(self.plan_for())
        return build_recorded_package(inputs(),root=ROOT,disclosure="public",**pins(),**(dict(
            premis_plan_bytes=self.base.premis_plan,premis_plan_hash=keccak256(self.base.premis_plan),premis_profile_hash=PH,
            iiif_plan_bytes=self.iiif_plan,iiif_plan_hash=keccak256(self.iiif_plan),iiif_profile_hash=IH,
            lido_plan_bytes=raw,lido_plan_hash=keccak256(raw),lido_profile_hash=PROFILE_HASH)|updates))

    def test_offline_package_preserves_source_and_rejects_rehashed_publisher_or_report(self):
        package=self.package();files=dict(package.files)
        self.assertNotIn("lido/lido.xml",files)
        self.assertEqual(files["inputs/source-capture.json"],self.base.base.source.capture_bytes)
        self.assertEqual(files["definitions/recorded-lido-profile.json"],PROFILE_BYTES)
        self.assertEqual(loads(package.manifest,maximum=2097152)["mode"],"recorded_account_lido_resource_package")
        with tempfile.TemporaryDirectory() as temp:
            folder=Path(temp)/"package";write_package(package,folder)
            with patch("socket.socket",side_effect=AssertionError("network")):
                self.assertEqual(verify_package(folder,package.manifest_hash),package)
            altered=changed(package,"lido/report.json",b"{}");folder=Path(temp)/"tampered";write_package(altered,folder)
            with self.assertRaisesRegex(MuseumError,"semantic reconstruction"):verify_package(folder,altered.manifest_hash)
        for update in ({"lido_plan_hash":None},{"lido_profile_hash":None},{"iiif_plan_bytes":None}):
            with self.subTest(update=update),self.assertRaises(MuseumError):self.package(**update)

    def test_static_plan_and_actual_cli(self):
        self.assertEqual((EXAMPLES/"profile.json").read_bytes(),PROFILE_BYTES)
        raw=(EXAMPLES/"missing-work-plan.json").read_bytes();self.assertEqual(raw,dumps(self.plan_for()))
        lp=loads((EXAMPLES/"pins.json").read_bytes());self.assertEqual(lp,{"lido_plan":keccak256(raw),"lido_profile":PROFILE_HASH})
        pp=loads((ROOT/"premis-recorded/pins.json").read_bytes());ip=loads((ROOT/"iiif-recorded/pins.json").read_bytes())
        with tempfile.TemporaryDirectory() as temp:
            folder=Path(temp)/"package"
            command=[sys.executable,"-B","-m","tools.museum.package_v2","build-recorded",str(FIXTURE),str(folder),
                "--dependency-root",str(ROOT),"--disclosure","public","--premis-plan",str(ROOT/"premis-recorded/missing-file-plan.json"),
                "--iiif-plan",str(ROOT/"iiif-recorded/missing-presentation-plan.json"),"--lido-plan",str(EXAMPLES/"missing-work-plan.json")]
            for key,value in (pins()|{k+"_hash":v for k,v in (pp|ip|lp).items()}).items():command += ["--"+key.replace("_","-"),value]
            result=subprocess.run(command,capture_output=True,text=True,timeout=60);self.assertEqual(result.returncode,0,result.stderr)
            self.assertEqual((folder/"lido/report.json").read_bytes(),self.project().report)


if __name__=="__main__":unittest.main()
