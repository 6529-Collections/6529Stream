"""Native-shaped synthetic media history on the existing attribution/DIRECT map."""
from copy import deepcopy
from types import MethodType
import unittest
from unittest.mock import patch
from . import public_media_master_source as source
from . import public_media_master_capture as capture
from . import artist_attestation_source as artist
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, record_chain, schema_id, subject_id
from .chain_abi import encode, decode
from .independent_wire import ZERO, ZERO_ADDRESS, generic_hash
from .metadata_catalog_source import RECEIPT, POLICY, ARTIST
from .public_history_rpc import PublicReplayTransport
from .test_public_attribution_source import PublicAttributionFixture
from .test_current_rights_source import A, H
from .test_public_personhood_source import K


class MediaMasterMixin:
    def setup_media(self, mode="present"):
        if mode not in ("present","waived","empty","absent","replaced","manifest_changed"):
            raise ValueError("unknown media fixture mode")
        self.media_mode=mode; self.media_master=A(10006); self.external_coverage=A(50020)
        for address,label in ((self.media_master,"synthetic media master905"),(self.external_coverage,"synthetic external coverage905")):
            self.codes[address]=label.encode(); self.pins[address]=keccak256(self.codes[address])
        a={key:self.personhood_anchor[key] for key in source.COMMON}
        a.update(profile=source.PROFILE,host=A(1),router=self.selection_anchor["router"],schemas=A(3),store=A(4),artistRegistry=self.registry,
            mediaMaster=self.media_master,externalCoverage=self.external_coverage,executor=self.floor_executor,
            runtimeAdmission={"sourceCommit":source.SOURCE_REVISION,"kind":"synthetic_fixture","artifactHash":K("synthetic media artifact")})
        self.media_anchor=a; self.media_subject=subject_id("collection",a["chainId"],a["core"],a["collectionId"])
        self.media_association=(self.current_binding[0],self.current_binding[3],self.current_binding[4],self.current_binding[2])
        self.media_selections={1:[],2:[],3:[]}; self.media_originals=[]; self.media_manifests=[]; self.media_coverages=[]
        for key,getter in (("core","core"),("host","metadata"),("schemas","schemaRegistry"),("store","chunkStore"),("externalCoverage","externalCoverage"),("executor","governanceAuthority")):
            self.add(self.media_master,getter+"()",(),(),("address",),(a[key],))
        self.add(self.media_master,"deploymentChainId()",(),(),("uint256",),(31337,))
        self.add(self.media_master,"profileHash()",(),(),("bytes32",),(source.NATIVE_PROFILE_HASH,))
        self.add(self.external_coverage,"core()",(),(),("address",),(self.core,))
        self.add(self.external_coverage,"governanceAuthority()",(),(),("address",),(self.floor_executor,))
        for name,raw in source.DEFINITIONS.items(): self._definition(name,2 if name==source.NATIVE_PROFILE else 0,raw)
        first=self.media_manifest(block=0,empty=mode=="empty")
        if mode not in ("empty","absent"):
            self.media_select(first,waiver=mode=="waived",block=2)
        if mode in ("replaced","manifest_changed"):
            later=self.media_manifest(block=4,label="later")
            if mode=="replaced": self.media_select(later,block=4)
        self.media_update_heads()
        self.media_anchor["codePins"]=[{"address":address,"runtimeHash":digest} for address,digest in sorted(self.pins.items())]
        return self.media_anchor

    def media_manifest(self, *, block=0, empty=False, label="first", slots=1, opaque=False):
        a=self.media_anchor
        uri="" if empty else "ipfs://synthetic-media-"+label
        manifest=(0,"",ZERO,"")*3+("",ZERO,"",ZERO) if empty else tuple(part for slot in range(1,4) for part in
            ((5,uri+('' if slot==1 else str(slot)),K("display "+label+('' if slot==1 else str(slot))),"image/png") if slot<=slots else (0,"",ZERO,"")))+("",ZERO,"",ZERO)
        if opaque: manifest=(*manifest[:12],"ipfs://opaque-manifest",K("opaque manifest"),"",ZERO)
        source_hash=source.h(("string","string"),(uri,""))
        digest=source.h(("bytes32","uint256","address","address","address","bytes32","uint256","bytes32",source.MANIFEST),
            (K("6529STREAM_CURRENT_MEDIA_MANIFEST_V1"),31337,self.core,A(1),a["router"],self.pins[a["router"]],1,source_hash,manifest))
        self.add(A(1),"recordedMediaManifest(bytes32)",("bytes32",),(digest,),(source.MANIFEST,),(manifest,))
        event=self.event(block,A(1),[source.MANIFEST_EVENT,H(1),H(3),digest],("uint16","address","bytes32"),(1,a["router"],source_hash))
        try: hashes,inv=source.inventory(manifest)
        except MuseumError: hashes,inv=None,None
        row={"hash":digest,"manifest":manifest,"hashes":hashes,"inventoryHash":inv,"event":event}
        self.media_manifests.append(row); self.media_reselect(row,block=block)
        return row

    def media_reselect(self, row, *, block):
        a=self.media_anchor;digest=row["hash"];manifest=row["manifest"];hashes=row["hashes"]
        event=self.event(block,a["router"],[source.MANIFEST_SELECTED_EVENT,H(1),H(3),digest],("uint16","address","bytes32"),(1,A(1),self.pins[A(1)]))
        self.add(A(1),"mediaManifestHash(uint256)",("uint256",),(1,),("bytes32",),(digest,))
        self.add(A(1),"mediaManifest(uint256)",("uint256",),(1,),(source.MANIFEST,),(manifest,))
        self.add(a["router"],"selectedCollectionManifest(uint256,uint8)",("uint256","uint8"),(1,3),(("address","bytes32","bytes32"),),((A(1),self.pins[A(1)],digest),))
        self.add(a["router"],"collectionServingSource(uint256)",("uint256",),(1,),(source.SERVING,),(("Synthetic","",manifest[1],"",""),))
        self.add(self.media_master,"collectionMediaContext(uint256)",("uint256",),(1,),
            ("bytes32","bytes32","bytes32","uint8"),(self.media_subject,digest,row["inventoryHash"] or ZERO,
                0 if hashes is None else sum(1<<index for index,value in enumerate(hashes) if value!=ZERO)))
        return event

    def media_clear(self, *, block):
        a=self.media_anchor
        event=self.event(block,a["router"],[source.MANIFEST_SELECTED_EVENT,H(1),H(3),ZERO],("uint16","address","bytes32"),(1,ZERO_ADDRESS,ZERO))
        self.add(a["router"],"selectedCollectionManifest(uint256,uint8)",("uint256","uint8"),(1,3),(("address","bytes32","bytes32"),),((ZERO_ADDRESS,ZERO,ZERO),))
        self.add(A(1),"mediaManifestHash(uint256)",("uint256",),(1,),("bytes32",),(ZERO,))
        return event

    def media_coverage(self, label, *, block=1):
        o=(self.artist_id,K("object schema"),K("RAW_BYTES"),K("master content "+label),K("master SHA "+label),K("master root "+label),123,
            K("PNG"),K("format catalog"),K("format catalog hash"))
        obj=source.h(("bytes32","uint256","address","address",source.OBJECT),(K("6529STREAM_EXTERNAL_OBJECT_V1"),31337,self.external_coverage,self.core,o))
        c=(ZERO,obj,o[0],o[3],o[4],o[5],o[6],K("family1 "+label),K("family2 "+label),K("receipt1 "+label),K("receipt2 "+label),
            K("fixity1 "+label),K("fixity2 "+label),K("checkpoint "+label),K("STREAM_EXTERNAL_ARTIFACT_COVERAGE_V1"))
        digest=source.h(("bytes32","uint256","address",source.COVERAGE),(K("6529STREAM_EXTERNAL_COVERAGE_V1"),31337,self.external_coverage,c))
        c=(digest,*c[1:])
        self.add(self.external_coverage,"objectIdentity(bytes32)",("bytes32",),(obj,),(source.OBJECT,),(o,))
        self.add(self.external_coverage,"coverage(bytes32)",("bytes32",),(digest,),(source.COVERAGE,),(c,))
        object_event=self.event(block,self.external_coverage,[source.OBJECT_EVENT,obj],(source.OBJECT,),(o,))
        event=self.event(block,self.external_coverage,[source.COVERAGE_EVENT,digest,obj],(source.COVERAGE,),(c,))
        row={"objectHash":obj,"hash":digest,"object":o,"coverage":c,"archiveHash":source.h((source.OBJECT,source.COVERAGE),(o,c)),"event":event,"objectEvent":object_event}
        self.media_coverages.append(row); return row

    def media_select(self, manifest, *, waiver=False, block=2, slot=1, authority=6, role=0, waiver_roles=None):
        a=self.media_anchor; prior=self.media_selections[slot][-1] if self.media_selections[slot] else source.EMPTY_SELECTION
        display=manifest["hashes"][slot-1]; objid=source.object_id(a,self.media_subject,manifest["hash"],slot,display)
        coverage=None if waiver else self.media_coverage(str(len(self.media_originals)),block=max(0,block-1))
        value={"version":1,"subjectId":self.media_subject,"predecessor":None if prior[6][0]==ZERO else prior[6][0]}
        if waiver:
            value.update(artist={"artistId":self.artist_id,"bindingGeneration":str(self.media_association[2]),"bindingHash":self.media_association[1]},
                scope={"subjectId":self.media_subject,"mediaObjects":[{"objectId":objid,"mediaClass":"still_image","masterRoles":waiver_roles or [("SOURCE_MASTER","PRINT_MASTER")[role]]}]},
                waiverStatement={"uri":"ipfs://synthetic-waiver","hash":{"algorithm":1,"canonicalizationId":K("RAW_BYTES"),"digest":K("waiver text")}},reason="Synthetic original waiver")
        else:value.update(selectedMediaManifestHash=manifest["hash"],mediaSlot=slot,displayHash=display,masterRole=("SOURCE_MASTER","PRINT_MASTER")[role],masterObjectHash=coverage["objectHash"],coverageHash=coverage["hash"])
        raw=dumps(value); payload=keccak256(raw); self.chunk(raw); timestamp=self.time(block)
        rt=source.TYPES[int(waiver)]; name=source.WAIVER_NAME if waiver else source.MASTER_NAME; auth=1 if waiver else authority
        record=(rt,self.media_subject,(1,hex_bytes(payload),source.JCS),"ipfs://synthetic-original-master",K(name),ZERO,(0,b"",ZERO),timestamp)
        same=[row for row in self.originals+self.media_originals if row["record"][0]==rt]
        index=len(same); previous=same[-1]["receipt"][5] if same else ZERO
        for original in same:
            self.add(A(1),"collectionRecordReceipt(bytes32)",("bytes32",),(original["recordHash"],),(RECEIPT,),(original["receipt"],))
        digest=generic_hash(31337,A(1),self.core,1,self.signer,record)
        chain=record_chain("31337",A(1),"1",rt,previous,digest,str(index)); authorization=K("waiver "+digest) if waiver else ZERO
        receipt=(1,self.signer,auth,timestamp,index,chain,keccak256(source.DEFINITIONS[name]),keccak256(source.JCS_BYTES),authorization)
        self.add(A(1),"recordPolicy(bytes32)",("bytes32",),(rt,),(POLICY,),((ARTIST if waiver else source.MEDIA_FAMILY,2 if waiver else 192,True),))
        self.add(A(1),"collectionRecord(bytes32)",("bytes32",),(digest,),(source.RECORD,RECEIPT),(record,receipt))
        self.add(A(1),"collectionRecordReceipt(bytes32)",("bytes32",),(digest,),(RECEIPT,),(receipt,))
        self.add(A(1),"recordHashAt(uint256,bytes32,uint256)",("uint256","bytes32","uint256"),(1,rt,index),("bytes32",),(digest,))
        evidence=source.conservation._zero(artist.EVIDENCE); publication_hash=ZERO
        if waiver:
            publication=(A(1),self.signer,1,self.media_subject,rt,K(name),source.JCS,1,payload,keccak256(record[3].encode()),timestamp,digest)
            evidence=(authorization,self.artist_id,self.media_association[1],self.media_association[2],self.signer,1,1,timestamp,source.h((artist.PUBLICATION,),(publication,)))
            saved=(publication,evidence,self.pins[A(1)]); statement=encode(("uint16",artist.PUBLICATION),(1,publication))
            attestation=(authorization,ZERO,artist.PUBLICATION_SCHEMA,keccak256(statement),self.media_association[2],timestamp,self.signer)
            self.add(A(1),"consumedArtistAuthorization(bytes32)",("bytes32",),(authorization,),("bool",),(True,))
            self.add(self.owners[4],"publicationAttestation(bytes32)",("bytes32",),(authorization,),(artist.PUBLICATION_RECORD,),(saved,))
            self.add(self.owners[4],"attestationRecord(bytes32)",("bytes32",),(authorization,),(artist.ATTESTATION_RECORD,),(attestation,))
            self.add(self.owners[4],"statementBytes(bytes32)",("bytes32",),(attestation[3],),("bytes",),(statement,))
            self.add(self.owners[2],"signatureBundle(bytes32)",("bytes32",),(authorization,),("bytes",),(b"synthetic waiver signature",))
            publication_hash=source.h((artist.PUBLICATION_RECORD,),(saved,))
        evidence_=(digest,payload,self.signer,auth,timestamp,index,chain,source.h((RECEIPT,),(receipt,)),evidence,publication_hash)
        row=(2 if waiver else 1,self.media_subject,manifest["hash"],slot,display,objid,evidence_,self.media_association,
            ZERO if waiver else coverage["objectHash"],ZERO if waiver else coverage["hash"],role,prior[6][0],prior[12]+1,ZERO)
        row=(*row[:-1],source.selection_hash(a,row))
        event=self.event(block,A(1),[source.METADATA_RECORDED,H(1),rt,self.media_subject],(source.RECORD,"bytes32","bytes32","address","bytes32","uint16"),
            (record,digest,chain,self.signer,H(auth),1))
        selected_event=self.event(block,self.media_master,[source.SELECTED_EVENT,H(1),self.media_subject,H(slot)],(source.SELECTION,),(row,))
        self.media_originals.append({"recordHash":digest,"record":record,"receipt":receipt,"raw":raw,"event":event,"selectionEvent":selected_event})
        self.media_selections[slot].append(row); self.media_update_heads(); return row

    def media_update_heads(self):
        for slot,rows in self.media_selections.items():
            self.add(self.media_master,"currentMaster(uint256,bytes32,uint8)",("uint256","bytes32","uint8"),(1,self.media_subject,slot),(source.SELECTION,),(rows[-1] if rows else source.EMPTY_SELECTION,))
            for index,row in enumerate(rows,1):
                self.add(self.media_master,"masterSelectionAt(uint256,bytes32,uint8,uint64)",("uint256","bytes32","uint8","uint64"),(1,self.media_subject,slot,index),(source.SELECTION,),(row,))

    def media_source(self, **kwargs): return source.PublicMediaMasterSource(dumps(self.media_anchor),self,**kwargs)
    def media_result(self): return loads(self.media_source().snapshot(),maximum=source.MAX_OUTPUT)
    def media_capture(self):
        adapter=self.media_source();adapter.snapshot();transcript=adapter.transcript()
        return capture.replay(adapter.anchor_bytes,keccak256(adapter.anchor_bytes),source.PROFILE_HASH,transcript,keccak256(transcript),provenance="synthetic_fixture",disclosure="public")


def install_into(fixture, mode="present"):
    for name in MediaMasterMixin.__dict__:
        if not name.startswith("__"): setattr(fixture,name,MethodType(getattr(MediaMasterMixin,name),fixture))
    return fixture.setup_media(mode)


class PublicMediaMasterFixture(MediaMasterMixin,PublicAttributionFixture):
    def __init__(self,mode="present"):
        super().__init__();self.setup_media(mode)
    def source(self,**kwargs):return self.media_source(**kwargs)
    def result(self):return self.media_result()


class PublicMediaMasterSourceTests(unittest.TestCase):
    def test_present_original_coverage_replays_offline(self):
        f=PublicMediaMasterFixture();adapter=f.source();raw=adapter.snapshot();transcript=adapter.transcript()
        with patch("socket.socket",side_effect=AssertionError("network forbidden")):
            replay=source.PublicMediaMasterSource(adapter.anchor_bytes,PublicReplayTransport(transcript,keccak256(transcript)))
            self.assertEqual(replay.snapshot(),raw)
        result=loads(raw,maximum=source.MAX_OUTPUT)
        self.assertEqual(result["slots"]["1"]["status"],"PRESENT")
        self.assertEqual(result["coverage"][0]["archiveHash"],f.media_coverages[0]["archiveHash"])

    def test_empty_absent_waived_and_historical_manifest_are_distinct(self):
        outputs={mode:PublicMediaMasterFixture(mode).result() for mode in ("empty","absent","waived","replaced","manifest_changed")}
        self.assertEqual(outputs["empty"]["mediaContext"]["occupiedMask"],"0")
        self.assertEqual(outputs["empty"]["historicalCandidates"][0]["scope"],"source_block_only")
        self.assertIsNone(outputs["empty"]["historicalCandidates"][0]["publication"])
        self.assertEqual(outputs["absent"]["mediaContext"]["occupiedMask"],"1")
        self.assertEqual(outputs["absent"]["historicalCandidates"],[])
        self.assertEqual(outputs["waived"]["slots"]["1"]["status"],"WAIVED")
        self.assertEqual(outputs["waived"]["coverage"],[])
        self.assertEqual(outputs["waived"]["historicalCandidates"][0]["archiveHashes"],[ZERO]*3)
        self.assertEqual(len(outputs["replaced"]["slots"]["1"]["history"]),2)
        self.assertEqual(len(outputs["replaced"]["historicalCandidates"]),2)
        self.assertIn("historical_manifest",outputs["manifest_changed"]["slots"]["1"]["currentEligibility"]["reasons"])

    def test_three_occupied_slots_and_both_native_master_roles(self):
        f=PublicMediaMasterFixture("absent")
        m=f.media_manifest(block=1,label="three",slots=3)
        f.media_select(m,slot=1,block=2,authority=7,role=1)
        f.media_select(m,slot=2,block=2,waiver=True,waiver_roles=["SOURCE_MASTER","PRINT_MASTER"])
        f.media_select(m,slot=3,block=2)
        result=f.result();candidate=result["historicalCandidates"][-1]
        self.assertEqual(result["mediaContext"]["occupiedMask"],"7")
        self.assertEqual([result["slots"][str(s)]["status"] for s in (1,2,3)],["PRESENT","WAIVED","PRESENT"])
        self.assertEqual(candidate["archiveHashes"][1],ZERO)
        self.assertEqual([row["value"].get("masterRole") for row in result["records"]],["PRINT_MASTER",None,"SOURCE_MASTER"])
        self.assertEqual(candidate["factsHash"],source.evidence_hash(f.media_anchor,m["hash"],m["inventoryHash"],m["hashes"],f.media_association,
            tuple(f.media_selections[s][-1] for s in (1,2,3)),candidate["archiveHashes"]))

    def test_full_facts_domain_and_occupied_slot_correspondence(self):
        f=PublicMediaMasterFixture();result=f.result();c=result["historicalCandidates"][0]
        heads=tuple(f.media_selections[s][-1] if f.media_selections[s] else source.EMPTY_SELECTION for s in (1,2,3))
        changed=dict(f.media_anchor,mediaMaster=A(50099))
        with self.assertRaisesRegex(MuseumError,"selected correspondence"):
            source.evidence_hash(changed,c["manifestHash"],c["inventoryHash"],c["hashes"],f.media_association,heads,c["archiveHashes"])
        with self.assertRaisesRegex(MuseumError,"selected correspondence"):
            source.evidence_hash(f.media_anchor,c["manifestHash"],c["inventoryHash"],c["hashes"],f.media_association,heads,[ZERO]*3)
        with self.assertRaisesRegex(MuseumError,"slot count"):
            source.evidence_hash(f.media_anchor,c["manifestHash"],c["inventoryHash"],[],f.media_association,heads,c["archiveHashes"])

    def test_native_inventory_source_enum_and_declared_mime_are_not_reinterpreted(self):
        for kind in range(1,9):
            m=(kind,"opaque:original",H(80),"")+(0,"",ZERO,"retained declaration")*2+("",ZERO,"",ZERO)
            self.assertEqual(source.inventory(m)[0],(H(80),ZERO,ZERO))
        with self.assertRaisesRegex(MuseumError,"slot source/hash"):
            source.inventory((0,"opaque:invalid",ZERO,"")+(0,"",ZERO,"")*2+("",ZERO,"",ZERO))

    def test_current_policy_loss_retains_original_without_current_eligibility(self):
        f=PublicMediaMasterFixture()
        f.add(A(1),"recordPolicy(bytes32)",("bytes32",),(source.TYPES[0],),(POLICY,),((ARTIST,0,False),))
        result=f.result()
        self.assertEqual(result["slots"]["1"]["status"],"PRESENT")
        self.assertIn("current_record_policy_unavailable",result["slots"]["1"]["currentEligibility"]["reasons"])
        self.assertEqual(len(result["historicalCandidates"]),1)

    def test_current_archive_liveness_is_never_substituted_for_saved_bytes(self):
        f=PublicMediaMasterFixture();adapter=f.source();result=loads(adapter.snapshot(),maximum=source.MAX_OUTPUT)
        from .chain_abi import calldata
        forbidden=calldata("requireCoverage(bytes32,bytes32,bytes32)",("bytes32","bytes32","bytes32"),(H(1),H(1),H(1)))[:10]
        self.assertFalse(any(row["method"]=="eth_call" and row["params"][0]["data"].startswith(forbidden) for row in adapter.reader.rows))
        self.assertFalse(result["claims"]["currentArchiveLivenessChecked"])
        self.assertFalse(result["slots"]["1"]["currentEligibility"]["eligible"])
        self.assertEqual(result["coverage"][0]["currentLiveness"],"not_checked")

    def test_selected_record_hash_receipt_and_schema_negatives(self):
        for change in ("type","class","schema","chain"):
            f=PublicMediaMasterFixture();original=f.media_originals[0];record=list(original["record"]);receipt=list(original["receipt"])
            if change=="type":record[0]=H(800)
            elif change=="class":receipt[2]=3
            elif change=="schema":receipt[6]=H(801)
            else:receipt[5]=H(802)
            f.add(A(1),"collectionRecord(bytes32)",("bytes32",),(original["recordHash"],),(source.RECORD,RECEIPT),(tuple(record),tuple(receipt)))
            with self.subTest(change=change),self.assertRaises(MuseumError):f.result()

    def test_payload_carrier_wrong_bytes_reject(self):
        f=PublicMediaMasterFixture();raw=f.media_originals[0]["raw"]
        pointer=next(address for address,code in f.codes.items() if code==b"\x00"+raw)
        f.codes[pointer]=b"\x00"+raw[:-1]+b" "
        with self.assertRaises(MuseumError):f.result()

    def test_waiver_original_op24_class_capability_and_statement_reject(self):
        for change in ("class","capability","statement"):
            f=PublicMediaMasterFixture("waived");row=f.media_selections[1][0];original=f.media_originals[0]
            publication=(A(1),f.signer,1,f.media_subject,source.TYPES[1],K(source.WAIVER_NAME),source.JCS,1,keccak256(original["raw"]),
                keccak256(original["record"][3].encode()),original["record"][7],original["recordHash"])
            evidence=list(row[6][8])
            if change in ("class","capability"):
                evidence[5 if change=="class" else 6]=4
                f.add(f.owners[4],"publicationAttestation(bytes32)",("bytes32",),(evidence[0],),(artist.PUBLICATION_RECORD,),((publication,tuple(evidence),f.pins[A(1)]),))
            else:
                digest=keccak256(encode(("uint16",artist.PUBLICATION),(1,publication)))
                f.add(f.owners[4],"statementBytes(bytes32)",("bytes32",),(digest,),("bytes",),(b"wrong original statement",))
            with self.subTest(change=change),self.assertRaisesRegex(MuseumError,"waiver"):f.result()

    def test_rehashed_selection_wrong_predecessor_and_missing_event_reject(self):
        f=PublicMediaMasterFixture("replaced");row=list(f.media_selections[1][1]);row[11]=H(800)
        row[13]=source.selection_hash(f.media_anchor,tuple(row));f.media_selections[1][1]=tuple(row);f.media_update_heads()
        with self.assertRaisesRegex(MuseumError,"lineage/hash"):f.result()
        f=PublicMediaMasterFixture();event=f.media_originals[0]["selectionEvent"]
        f.receipts[event["transactionHash"]]["logs"].remove(event)
        with self.assertRaisesRegex(MuseumError,"missing original/selected event"):f.result()

    def test_original_object_and_coverage_bytes_and_event_must_agree(self):
        for change in ("object","coverage","event"):
            f=PublicMediaMasterFixture();row=f.media_coverages[0]
            if change=="event":row["event"]["data"]="0x"+encode((source.COVERAGE,),((H(800),*row["coverage"][1:]),)).hex()
            elif change=="object":
                value=list(row["object"]);value[3]=f.media_manifests[0]["hashes"][0]
                f.add(f.external_coverage,"objectIdentity(bytes32)",("bytes32",),(row["objectHash"],),(source.OBJECT,),(tuple(value),))
            else:
                value=list(row["coverage"]);value[11]=H(800)
                f.add(f.external_coverage,"coverage(bytes32)",("bytes32",),(row["hash"],),(source.COVERAGE,),(tuple(value),))
            with self.subTest(change=change),self.assertRaisesRegex(MuseumError,"media"):f.result()

    def test_missing_required_runtime_and_revision_bound_fail(self):
        f=PublicMediaMasterFixture();f.codes[f.media_master]=b""
        next(pin for pin in f.media_anchor["codePins"] if pin["address"]==f.media_master)["runtimeHash"]=keccak256(b"")
        with self.assertRaisesRegex(MuseumError,"runtime differs"):f.result()
        f=PublicMediaMasterFixture();head=list(f.media_selections[1][0]);head[12]=65
        f.add(f.media_master,"currentMaster(uint256,bytes32,uint8)",("uint256","bytes32","uint8"),(1,f.media_subject,1),(source.SELECTION,),(tuple(head),))
        with self.assertRaisesRegex(MuseumError,"revision bound"):f.result()

    def test_closed_anchor_profile_and_provenance(self):
        for change in ("extra","profile","provenance"):
            f=PublicMediaMasterFixture();a=deepcopy(f.media_anchor)
            if change=="extra":a["tokenId"]="41"
            elif change=="profile":a["profile"]="STREAM_MUSEUM_PUBLIC_CONSERVATION_SOURCE_V1"
            with self.subTest(change=change),self.assertRaises(MuseumError):
                source.PublicMediaMasterSource(dumps(a),f,provenance="trusted_rpc" if change=="provenance" else "synthetic_fixture")

    def test_exact_frozen_definition_bytes(self):
        expected={source.MASTER_NAME:(1042,"0xffa74f87b27c73aced2cf2e9f9da7d8255b947b1a7627b0a71536c2a35b8f0e5"),
            source.WAIVER_NAME:(2121,"0x7e437d7591cb009ab71fbdf006e3286e64a74846d66bac9eabef46840d0eb069"),
            source.NATIVE_PROFILE:(2039,source.NATIVE_PROFILE_HASH)}
        for name,raw in source.DEFINITIONS.items():self.assertEqual((len(raw),keccak256(raw)),expected[name])


if __name__=="__main__":unittest.main()
