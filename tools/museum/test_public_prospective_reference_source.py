"""Synthetic native prospective source controls; no browser, chain or archive acceptance."""
from copy import deepcopy
from pathlib import Path
import unittest
from unittest.mock import patch

from . import public_prospective_reference_source as s
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, subject_id
from .chain_abi import Array, calldata, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS
from .public_history_rpc import PublicReplayTransport
from .test_public_attribution_source import PublicAttributionFixture
from .test_current_rights_source import A, H

K=schema_id


class ProspectiveReferenceMixin:
    """Install original raw calls/logs before any capture; preserve all existing anchors."""
    def setup_prospective_reference(self, mode="baseline", *, host=A(26000), source_capsule=None,
            publication_blocks=(2,), raised=False):
        if mode not in ("baseline","empty","superseded","current_replaced","two_vectors"):
            raise ValueError("unsupported synthetic prospective mode")
        self.prospective_host=host; self.prospective_rows=[]; self.prospective_mode=mode
        self.prospective_executor=self.floor_anchor["executor"]
        self.prospective_archive=A(26001); self.prospective_encoder=A(26002)
        for address,label in ((host,"publication"),(self.prospective_archive,"archive"),(self.prospective_encoder,"encoder")):
            self.codes[address]=("synthetic905 prospective "+label).encode(); self.pins[address]=keccak256(self.codes[address])
        self.prospective_renderer=source_capsule[10] if source_capsule is not None else (A(5),self.pins[A(5)],K("router version"),K("router manifest"),s.STABLE,
            K("6529STREAM_METADATA_TOKEN_RENDER_CONTEXT_V1"),K("6529STREAM_METADATA_RENDER_NO_EXTERNAL_READS_V1"),K("STATIC"))
        self.prospective_catalog_raw=s.renderer_declaration(self.prospective_renderer)
        targets=(self.core,self.floor,A(3),A(4),self.prospective_archive,self.prospective_encoder)
        self.prospective_original_dep=(targets,tuple(self.pins[x] for x in targets),31337,K("synthetic prospective renderer catalogue"),
            keccak256(self.prospective_catalog_raw),len(self.prospective_catalog_raw),500000,16000000,4000000)
        self.prospective_dep=self.prospective_original_dep
        common={key:self.a[key] for key in s.COMMON}
        self.prospective_anchor={**common,"profile":s.PROFILE,"host":host,
            "runtimeAdmission":{"sourceCommit":s.SOURCE_REVISION,"kind":"synthetic_fixture","artifactHash":K("synthetic prospective905 artifact")},
            "codePins":[{"address":a,"runtimeHash":self.pins[a]} for a in dict.fromkeys((host,*targets,self.prospective_executor))]}
        for getter,kind,value in (("core","address",self.core),("conservationFloor","address",self.floor),
                ("deploymentChainId","uint256",31337),("governanceAuthority","address",self.prospective_executor)):
            self.add(host,getter+"()",(),(),(kind,),(value,))
        for interface,value in ((s.PUBLICATION_INTERFACE,True),("0x01ffc9a7",True),("0xffffffff",False)):
            self.add(host,"supportsInterface(bytes4)",("bytes4",),(interface,),("bool",),(value,))
        self.add(self.prospective_archive,"core()",(),(),("address",),(self.core,))
        self.add(self.prospective_encoder,"PROFILE()",(),(),("bytes32",),(s.DOMAIN["simulation"],))
        self.add(A(3),"chunkStore()",(),(),("address",),(A(4),))
        for name in ("COLLECTION_METADATA","METADATA_ROUTER","ARTIST_REGISTRY"):
            role=K(name); pointer,=self._response(self.core,"getSatellitePointer(bytes32)",(s.POINTER,),("bytes32",),(role,))
            pointer=(*pointer[:7],pointer[7] if pointer[7]!=ZERO else K("synthetic installed policy"),
                pointer[8] if pointer[8]!=ZERO else K("synthetic installed manifest"),pointer[9] or self.time(0))
            self.add(self.core,"getSatellitePointer(bytes32)",("bytes32",),(role,),(s.POINTER,),(pointer,))
        self.add(host,"gasParameterIds()",(),(),(Array("bytes32",3),),(s.PARAMETER_IDS,))
        self.prospective_gas_events=[]
        for i,(parameter,name,genesis) in enumerate(zip(s.PARAMETER_IDS,s.PARAMETER_NAMES,self.prospective_original_dep[-3:],strict=True)):
            self.prospective_gas_events.append(self.event(0,host,[s.REGISTERED_EVENT,parameter],s.REGISTERED_DATA,(2,name,genesis,50000,2)))
            self.add(host,"gasParameterInfo(bytes32)",("bytes32",),(parameter,),s.GAS_INFO,(genesis,50000,2,1))
            self.add(host,"gasParameter(bytes32)",("bytes32",),(parameter,),("uint256",),(genesis,))
        self._prospective_definitions()
        self.prospective_source=source_capsule or self._prospective_source_capsule()
        self.prospective_release_context=self.prospective_source[3]
        if mode != "empty":
            for block in publication_blocks: self.append_prospective(block=block,vectors=2 if mode=="two_vectors" else 1)
            if mode == "superseded": self.append_prospective(block=4)
        if raised: self.raise_prospective_gas(block=4)
        self._prospective_heads()
        if mode=="current_replaced":
            new=A(26009); self.codes[new]=b"synthetic replacement metadata"; self.pins[new]=keccak256(self.codes[new])
            pointer=(new,self.pins[new],False,K("COLLECTION_METADATA"),"0x00000000",ZERO_ADDRESS,1,H(1),H(1),1)
            self.add(self.core,"getSatellitePointer(bytes32)",("bytes32",),(K("COLLECTION_METADATA"),),(s.POINTER,),(pointer,))
        return self.prospective_anchor

    def _prospective_definitions(self):
        root=Path(__file__).resolve().parents[2]
        paths=(None,None,None,"schemas/records/STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1.json",
            "schemas/records/STREAM_REFERENCE_PNG_OBJECT_V1.json","schemas/records/STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1.json",
            "schemas/records/STREAM_REFERENCE_NATIVE_FORMATS_V1.json","schemas/museum/account-profile/RFC8785_JCS.json",
            "schemas/records/STREAM_RENDERER_CLASS_DECLARATION_V1.json","schemas/records/STREAM_RENDERER_CLASS_DECLARATION_JSON_PROFILE_V1.json")
        definitions=[]
        for (identifier,kind,digest,size,raw),path in zip(s.DEFINITIONS,paths,strict=True):
            raw=raw if raw is not None else (root/path).read_bytes()
            assert len(raw)==size and keccak256(raw)==digest
            definitions.append((identifier,kind,raw))
        definitions.append((self.prospective_dep[3],2,self.prospective_catalog_raw))
        for identifier,kind,raw in definitions:
            key=(A(3),calldata("documentFacts(bytes32)",("bytes32",),(identifier,)))
            if key in self.responses:
                facts,=decode((s.DOCUMENT_FACTS,),hex_bytes(self.responses[key]))
                assert facts[3]==keccak256(raw)
                continue
            chunks=[raw[i:i+8192] for i in range(0,len(raw),8192)]
            self.add(A(3),"documentFacts(bytes32)",("bytes32",),(identifier,),(s.DOCUMENT_FACTS,),
                ((True,kind,0,keccak256(raw),s.RAW_BYTES,ZERO,len(raw),len(chunks),K("synthetic native definition chunks")),))
            for i,part in enumerate(chunks):
                digest=keccak256(part); pointer=self._carrier(part)
                self.add(A(3),"documentChunkHashAt(bytes32,uint256)",("bytes32","uint256"),(identifier,i),("bytes32",),(digest,))
                self.add(A(4),"chunk(bytes32)",("bytes32",),(digest,),("address","uint32"),(pointer,len(part)))
                self.add(A(4),"readChunk(bytes32)",("bytes32",),(digest,),("bytes",),(part,))

    def _response(self,target,name,outputs,inputs=(),values=()):
        return decode(outputs,hex_bytes(self.responses[(target,calldata(name,inputs,values))]),maximum=s.MAX_ABI)

    def _prospective_source_capsule(self):
        count,head=self._response(self.floor,"sourceSetHead()",("uint64","bytes32"))
        provider,=self._response(self.floor,"sourceAt(uint64)",(s.SOURCE[2],),("uint64",),(count,))
        script=b'console.log("prospective synthetic observation");'
        script_hash=keccak256(script); media=(5,"ipfs://synthetic-master",K("synthetic image"),"image/png",0,"",ZERO,"",0,"",ZERO,"","",ZERO,"",ZERO)
        renderer=self.prospective_renderer
        serving=(s.STABLE,True,K("ONCHAIN"),A(5),self.pins[A(5)],script_hash,len(script),keccak256(media[1].encode()),keccak256(b""),False,False,False,False,False,False,False)
        manifest=(script_hash,s.STABLE,1,"","","","application/javascript",1,True)
        script_manifest=K("retained native script manifest"); media_manifest=K("retained native media manifest")
        subject=subject_id("collection","31337",self.core,"1")
        media_hash=s.hash_abi(("bytes32",s.SOURCE[14]),(K("6529STREAM_MEDIA_MASTER_INVENTORY_V1"),media))
        script_source=s.hash_abi(("bytes32",s.SOURCE[12],"uint32","address","bytes32"),
            (K("6529STREAM_CONSERVATION_NATIVE_SCRIPT_V1"),manifest,len(script),A(5),self.pins[A(5)]))
        membership=s.hash_abi(("bytes32","uint256","address","uint256","bytes32","bytes32","bytes32"),
            (K("6529STREAM_CONSERVATION_COLLECTION_RELEASE_V1"),31337,self.core,1,subject,media_hash,script_source))
        context=s.hash_abi(("bytes32","bytes32","bytes32","uint8",s.SOURCE[8],"bytes32"),
            (provider[4],media_manifest,script_manifest,1,serving,membership))
        release=(subject,membership,media_hash,script_source,context,True)
        artist=(self.registry,self.current_binding[0],self.current_binding[4],self.current_binding[3],2,1,A(90))
        self.add(A(5),"renderingProfile()",(),(),("bytes32","bytes32","bytes32"),(s.STABLE,renderer[5],renderer[6]))
        return (count,head,provider,release,A(5),self.pins[A(5)],self.current_binding[0],artist,serving,
            ("Synthetic","Prospective declaration only",media[1],"",script.decode()),renderer,script_manifest,manifest,media_manifest,media,script)

    def _prospective_archive_object(self, label, *, runtime, stamp, sha_digest=None):
        host=self.prospective_archive; artist=self.prospective_source[6]
        obj=(artist,s.DEFINITIONS[5 if runtime else 4][0],s.RAW_BYTES,K(label+" content"),sha_digest or K(label+" sha"),K(label+" arweave root"),101,
            K("IANA:application/zip" if runtime else "IANA:image/png"),s.DEFINITIONS[6][0],s.DEFINITIONS[6][2])
        object_hash=s.hash_abi(("bytes32","uint256","address","address",s.OBJECT),(K("6529STREAM_EXTERNAL_OBJECT_V1"),31337,host,self.core,obj))
        self.add(host,"objectIdentity(bytes32)",("bytes32",),(object_hash,),(s.OBJECT,),(obj,))
        families=[]; receipts=[]; fixities=[]
        for n in range(2):
            family=K(label+" family "+str(n)); identifier=(label+" identifier "+str(n)).encode(); writer=A(27000+n)
            r=(object_hash,family,keccak256(identifier),K("synthetic receipt class"),K("synthetic receipt profile"),K("synthetic proof"),writer,stamp,0,stamp+100)
            rh=s.hash_abi(("bytes32","uint256","address",s.ARCHIVE_RECEIPT),(K("6529STREAM_EXTERNAL_RECEIPT_V1"),31337,host,r))
            f=(rh,object_hash,family,r[2],K("STREAM_EXTERNAL_OBJECT_FIXITY_V1"),obj[4],obj[4],obj[3],obj[3],obj[5],obj[5],obj[6],obj[6],stamp,1,K(label+" report"),ZERO,ZERO,A(27010+n),0,stamp+100)
            fh=s.hash_abi(("bytes32","uint256","address",s.FIXITY),(K("6529STREAM_EXTERNAL_FIXITY_V1"),31337,host,f))
            self.add(host,"receipt(bytes32)",("bytes32",),(rh,),(s.ARCHIVE_RECEIPT,"bytes","bytes"),(r,identifier,b"synthetic original signature"))
            self.add(host,"fixity(bytes32)",("bytes32",),(fh,),(s.FIXITY,"bytes"),(f,b"synthetic fixity signature"))
            families.append(family);receipts.append(rh);fixities.append(fh)
        cov=(ZERO,object_hash,artist,*obj[3:7],*families,*receipts,*fixities,K(label+" checkpoint"),K("STREAM_EXTERNAL_ARTIFACT_COVERAGE_V1"))
        digest=s.hash_abi(("bytes32","uint256","address",s.COVERAGE),(K("6529STREAM_EXTERNAL_COVERAGE_V1"),31337,host,cov))
        cov=(digest,*cov[1:]); self.add(host,"coverage(bytes32)",("bytes32",),(digest,),(s.COVERAGE,),(cov,))
        return cov

    def append_prospective(self, *, block=2, vectors=1, authorization_class=3, manifest_uri="ipfs://prospective-manifest"):
        stamp=self.time(block); index=len(self.prospective_rows); d=self.prospective_dep; source=self.prospective_source
        digest=s.source_hash(self.prospective_anchor,d,1,source)
        label="synthetic prospective "+str(index)
        environment_coverage=self._prospective_archive_object(label+" runtime",runtime=True,stamp=stamp)
        engine,tool=b"synthetic engine",b"synthetic tool"
        package=[("engine.exe",len(engine),s.sha(engine)),("tool.py",len(tool),s.sha(tool)),
            ("prospective/script.js",len(source[15]),s.sha(source[15]))]
        media=encode((s.SOURCE[14],),(source[14],)); package.append(("prospective/media.abi",len(media),s.sha(media)))
        captures=[]; coverage=[]
        for i in range(vectors):
            vector=("named_"+str(i),ZERO,b"opaque simulation input")
            html=s.simulation_html(self.prospective_anchor,1,digest,vector,source[15]); png=s.sha((label+str(i)+" PNG").encode())
            cov=self._prospective_archive_object(label+" PNG "+str(i),runtime=False,stamp=stamp,sha_digest=png)
            package.append(("prospective/"+vector[0]+".html",len(html),s.sha(html)))
            captures.append((vector,html,cov[1],cov[0],(png,png),stamp,b"")); coverage.append(cov)
        env=(environment_coverage[1],environment_coverage[0],ZERO,0,"Synthetic Chromium","1",s.sha(engine),"Synthetic replay","1",s.sha(tool),
            "engine.exe","tool.py",tuple(sorted(package)),(("C:/Windows/synthetic.dll",1,K("synthetic OS prerequisite")),),
            "Windows","synthetic","AMD64",800,600,1,"srgb",True,K("STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1"),"Synthetic observation; no license conclusion")
        env_raw=s.environment_bytes(env); env=(*env[:2],keccak256(env_raw),len(env_raw),*env[4:])
        captures=tuple((*c[:6],encode((s.EXECUTION,),((s.DOMAIN["simulation"],digest,s.vector_hash(c[0]),env[2],s.sha(c[1]),c[4],stamp,0),))) for c in captures)
        p=(1,K(label+" reference ID"),ZERO if index==0 else self.prospective_rows[-1]["receipt"][0],index,digest,captures,env,manifest_uri,stamp,K(label+" reason"))
        e=(digest,environment_coverage,tuple(coverage)); raw=encode(s.PAYLOAD,(s.DOMAIN["payload"],p,source,e,env_raw))
        r=(ZERO,ZERO,1,p[1],p[2],index+1,source[3][0],source[3][1],digest,keccak256(raw),len(raw),A(90),authorization_class,1,stamp,stamp,p[9],
            *(definition[2] for definition in s.DEFINITIONS[:3]))
        record=s.record_hash(self.prospective_anchor,d,p,r); r=(record,*r[1:])
        chain=s.chain_hash(self.prospective_anchor,ZERO if index==0 else self.prospective_rows[-1]["receipt"][1],r); r=(r[0],chain,*r[2:])
        event=self.event(block,self.prospective_host,[s.PUBLICATION_EVENT,record,H(1),p[1]],s.EVENT_DATA,(1,r,manifest_uri))
        row={"publication":p,"receipt":r,"payload":raw,"source":source,"evidence":e,"environment":env_raw,"log":event,
            "dependencies":d,"evidenceHash":s.evidence_hash(self.prospective_anchor,d,r)}
        self.prospective_rows.append(row); self._prospective_heads(); return row

    def _prospective_heads(self):
        host=self.prospective_host
        self.add(host,"dependencies()",(),(),(s.DEP,),(self.prospective_dep,))
        self.add(host,"prospectiveCount(uint256)",("uint256",),(1,),("uint256",),(len(self.prospective_rows),))
        self.add(host,"currentProspectiveReference(uint256)",("uint256",),(1,),(s.RECEIPT,),
            (s.zero(s.RECEIPT) if not self.prospective_rows else self.prospective_rows[-1]["receipt"],))
        for i,row in enumerate(self.prospective_rows):
            digest=row["receipt"][0]
            self.add(host,"prospectiveAt(uint256,uint256)",("uint256","uint256"),(1,i),("bytes32",),(digest,))
            self.add(host,"prospectiveRecord(bytes32)",("bytes32",),(digest,),(s.PUBLICATION,s.RECEIPT),(row["publication"],row["receipt"]))
            self.add(host,"prospectivePayload(bytes32)",("bytes32",),(digest,),("bytes",),(row["payload"],))
        self.add(host,"currentSource(uint256)",("uint256",),(1,),(s.SOURCE,"bytes32"),
            (self.prospective_source,s.source_hash(self.prospective_anchor,self.prospective_dep,1,self.prospective_source)))

    def raise_prospective_gas(self, *, block=4, index=0):
        old=self.prospective_dep[6+index]; new=old+1000; parameter=s.PARAMETER_IDS[index]
        self.event(block,self.prospective_host,[s.UPDATED_EVENT,parameter,s.topic("address",self.prospective_host),K("synthetic prospective gas action"+str(index))],
            s.UPDATED_DATA,(2,old,new,50000))
        values=list(self.prospective_dep); values[6+index]=new; self.prospective_dep=tuple(values)
        self.add(self.prospective_host,"gasParameterInfo(bytes32)",("bytes32",),(parameter,),s.GAS_INFO,(new,50000,2,2))
        self.add(self.prospective_host,"gasParameter(bytes32)",("bytes32",),(parameter,),("uint256",),(new,))
        self._prospective_heads()

    def recommit_prospective(self,index=0,*,publication=None,source=None,evidence=None,environment=None,receipt_changes=None):
        """Coherently rehash a supplied record; never claims a new native execution."""
        row=self.prospective_rows[index]
        p=row["publication"] if publication is None else publication
        capsule=row["source"] if source is None else source
        e=row["evidence"] if evidence is None else evidence
        env=row["environment"] if environment is None else environment
        raw=encode(s.PAYLOAD,(s.DOMAIN["payload"],p,capsule,e,env))
        r=list(row["receipt"]); r[2:6]=[p[0],p[1],p[2],p[3]+1]; r[8:11]=[p[4],keccak256(raw),len(raw)]
        r[14]=p[8];r[16]=p[9]
        for key,value in (receipt_changes or {}).items():r[key]=value
        r[0]=s.record_hash(self.prospective_anchor,row["dependencies"],p,tuple(r))
        r[1]=s.chain_hash(self.prospective_anchor,ZERO if index==0 else self.prospective_rows[index-1]["receipt"][1],tuple(r))
        row.update(publication=p,source=capsule,evidence=e,environment=env,payload=raw,receipt=tuple(r),evidenceHash=s.evidence_hash(self.prospective_anchor,row["dependencies"],tuple(r)))
        row["log"]["topics"]=[s.PUBLICATION_EVENT,r[0],H(p[0]),p[1]]
        row["log"]["data"]="0x"+encode(s.EVENT_DATA,(1,tuple(r),p[7])).hex()
        self._prospective_heads()
        return row

    def prospective_source_adapter(self): return s.PublicProspectiveReferenceSource(dumps(self.prospective_anchor),self)


class PublicProspectiveReferenceFixture(ProspectiveReferenceMixin,PublicAttributionFixture):
    def __init__(self, mode="baseline", *, raised=False):
        super().__init__(); self.setup_prospective_reference(mode,raised=raised)
    def source(self): return self.prospective_source_adapter()
    def result(self): return loads(self.source().snapshot(),maximum=s.MAX_OUTPUT)


class PublicProspectiveReferenceSourceTests(unittest.TestCase):
    def test_original_native_payload_head_environment_and_archive_replay(self):
        f=PublicProspectiveReferenceFixture(); adapter=f.source(); raw=adapter.snapshot(); result=loads(raw,maximum=s.MAX_OUTPUT)
        self.assertEqual(result["history"]["count"],"1")
        row=result["records"][0]
        self.assertEqual(hex_bytes(row["payloadHex"]),f.prospective_rows[0]["payload"])
        self.assertEqual(row["evidenceHash"],f.prospective_rows[0]["evidenceHash"])
        self.assertEqual(result["currentSource"]["status"],"observed")
        self.assertEqual(len(row["archiveFacts"]),2)
        for key in ("browserExecutionProven","historicalCurrentPairReplayed","postMintReferenceProven","actualChainAcceptance"):
            self.assertFalse(result["claims"][key])
        transcript=adapter.transcript()
        with patch("socket.socket",side_effect=AssertionError("offline")):
            self.assertEqual(s.PublicProspectiveReferenceSource(adapter.anchor_bytes,PublicReplayTransport(transcript,keccak256(transcript))).snapshot(),raw)

    def test_empty_supersession_and_two_named_vectors_are_complete_originals(self):
        for mode,count in (("empty",0),("superseded",2),("two_vectors",1)):
            with self.subTest(mode=mode):
                f=PublicProspectiveReferenceFixture(mode); result=f.result()
                self.assertEqual(result["history"]["count"],str(count))
                self.assertEqual(len(result["records"]),count)
                if count:self.assertEqual(result["history"]["head"],result["records"][-1]["recordHash"])
                else:self.assertEqual(result["history"],{"count":"0","head":ZERO,"chainHash":ZERO})
                if mode=="two_vectors":self.assertEqual(len(result["records"][0]["captures"]),2)

    def test_current_gas_raise_preserves_original_dependency_source_preimage(self):
        f=PublicProspectiveReferenceFixture(raised=True); result=f.result(); row=result["records"][0]
        self.assertEqual(row["originalDependencies"][-3:], ["500000","16000000","4000000"])
        self.assertEqual(result["dependencies"][-3:], ["501000","16000000","4000000"])
        self.assertNotEqual(row["receipt"][8],result["currentSource"]["sourceHash"])
        self.assertEqual(len(result["gasHistory"]["updates"]),1)
        self.assertEqual(row["payloadHex"],"0x"+f.prospective_rows[0]["payload"].hex())

    def test_current_replacement_skips_current_getter_without_erasing_history(self):
        f=PublicProspectiveReferenceFixture("current_replaced"); result=f.result()
        self.assertEqual(result["history"]["count"],"1")
        self.assertEqual(result["currentSource"]["status"],"not_evaluated")
        self.assertIn("current_metadata_differs_from_floor_source",result["currentSource"]["reasons"])
        call=calldata("currentSource(uint256)",("uint256",),(1,))
        self.assertFalse(any(method=="eth_call" and params[0]["data"]==call for method,params in f.requested))

    def test_original_global_curator_and_empty_manifest_uri_are_native_valid(self):
        f=PublicProspectiveReferenceFixture("empty")
        f.append_prospective(authorization_class=8,manifest_uri="")
        result=f.result()
        self.assertEqual(result["records"][0]["receipt"][12],"8")
        self.assertEqual(result["records"][0]["nativePublication"][7],"")

    def test_native_receipt_hash_zeros_both_assigned_fields_and_evidence_domain(self):
        f=PublicProspectiveReferenceFixture(); row=f.prospective_rows[0];r=row["receipt"];p=row["publication"]
        expected=keccak256(encode(("bytes32","uint256","address","address","address",s.PUBLICATION,s.RECEIPT),
            (K("6529STREAM_PROSPECTIVE_REFERENCE_RECORD_V1"),31337,f.prospective_host,f.core,f.floor,p,(ZERO,ZERO,*r[2:]))))
        self.assertEqual(r[0],expected)
        wrong=keccak256(encode(("bytes32","uint256","address","address","address",s.PUBLICATION,s.RECEIPT),
            (K("6529STREAM_PROSPECTIVE_REFERENCE_RECORD_V1"),31337,f.prospective_host,f.core,f.floor,p,(ZERO,*r[1:]))))
        self.assertNotEqual(r[0],wrong)
        self.assertEqual(row["evidenceHash"],keccak256(encode(("bytes32","uint256","address","address","address","uint256","bytes32","bytes32",s.RECEIPT),
            (K("6529STREAM_PROSPECTIVE_COLLECTION_REFERENCE_EVIDENCE_V1"),31337,f.prospective_host,f.core,f.floor,1,r[6],r[7],r))))

    def test_native_count_and_publication_event_denominator_cannot_hide_record(self):
        for mode in ("missing_event","zero_count","wrong_head","wrong_index"):
            f=PublicProspectiveReferenceFixture(); row=f.prospective_rows[0]
            if mode=="missing_event":f.receipts[row["log"]["transactionHash"]]["logs"].remove(row["log"])
            elif mode=="zero_count":f.add(f.prospective_host,"prospectiveCount(uint256)",("uint256",),(1,),("uint256",),(0,))
            elif mode=="wrong_head":f.add(f.prospective_host,"currentProspectiveReference(uint256)",("uint256",),(1,),(s.RECEIPT,),(s.zero(s.RECEIPT),))
            else:f.add(f.prospective_host,"prospectiveAt(uint256,uint256)",("uint256","uint256"),(1,0),("bytes32",),(K("wrong original"),))
            with self.subTest(mode=mode),self.assertRaises(MuseumError):f.result()

    def test_rehashed_wrong_native_scope_source_and_current_gas_are_rejected(self):
        for mode in ("scope","source","current_gas","uri","authority"):
            f=PublicProspectiveReferenceFixture();row=f.prospective_rows[0]
            if mode=="scope":f.recommit_prospective(receipt_changes={6:K("foreign subject")})
            elif mode=="source":
                p=list(row["publication"]);p[4]=K("wrong original source");f.recommit_prospective(publication=tuple(p))
            elif mode=="current_gas":
                # A coherent history raise before publication means the old committed source cannot be used.
                f.raise_prospective_gas(block=1)
            elif mode=="uri":
                p=list(row["publication"]);p[7]="http://not-native";f.recommit_prospective(publication=tuple(p))
            else:f.recommit_prospective(receipt_changes={12:1})
            with self.subTest(mode=mode),self.assertRaises(MuseumError):f.result()

    def test_coherent_rehash_cannot_replace_original_environment_or_execution(self):
        for mode in ("environment","execution","html","repeat"):
            f=PublicProspectiveReferenceFixture();row=f.prospective_rows[0];p=list(row["publication"])
            if mode=="environment":
                env=dict(loads(row["environment"]));env["engineName"]="Different declared engine"
                raw=dumps(env);e=list(p[6]);e[2:4]=[keccak256(raw),len(raw)];p[6]=tuple(e)
                f.recommit_prospective(publication=tuple(p),environment=raw)
            else:
                c=list(p[5][0])
                if mode=="execution":
                    x=list(decode((s.EXECUTION,),c[6])[0]);x[7]=1;c[6]=encode((s.EXECUTION,),(tuple(x),))
                elif mode=="html":c[1]=c[1]+b" "
                else:c[4]=(c[4][0],K("other PNG"))
                p[5]=(tuple(c),);f.recommit_prospective(publication=tuple(p))
            with self.subTest(mode=mode),self.assertRaises(MuseumError):f.result()

    def test_original_archive_fixity_is_retained_and_tampering_rejects(self):
        f=PublicProspectiveReferenceFixture();cov=f.prospective_rows[0]["evidence"][1]
        key=(f.prospective_archive,calldata("fixity(bytes32)",("bytes32",),(cov[11],)))
        fact,sig=decode((s.FIXITY,"bytes"),hex_bytes(f.responses[key]));fact=list(fact);fact[6]=K("mismatching full retrieval")
        f.responses[key]="0x"+encode((s.FIXITY,"bytes"),(tuple(fact),sig)).hex()
        with self.assertRaisesRegex(MuseumError,"original archive fixity"):f.result()

    def test_cached_coverage_cannot_change_artist_or_zip_png_role(self):
        f=PublicProspectiveReferenceFixture();adapter=f.source();adapter.snapshot()
        row=f.prospective_rows[0];coverage=row["evidence"][1];at=row["receipt"][15]
        original=adapter._archive_facts(row["dependencies"],coverage,coverage[2],at,True)
        self.assertEqual(original["coverageHash"],coverage[0])
        for artist,runtime in ((K("other artist"),True),(coverage[2],False)):
            with self.subTest(artist=artist,runtime=runtime),self.assertRaisesRegex(MuseumError,"archive artist/object role"):
                adapter._archive_facts(row["dependencies"],coverage,artist,at,runtime)

    def test_rehashed_source_preserves_native_media_and_serving_constraints(self):
        for mode,reason in (("kind","native media slot"),("uri","native media slot"),("mime","native media slot"),
                ("none_mime","native media slot"),("mode","serving/display"),("display_hash","serving/display"),
                ("renderer","stable renderer context")):
            f=PublicProspectiveReferenceFixture();row=f.prospective_rows[0];capsule=list(row["source"])
            media=list(capsule[14]);serving=list(capsule[8]);renderer=list(capsule[10]);release=list(capsule[3])
            if mode=="kind":media[0]=1
            elif mode=="uri":media[0]=7
            elif mode=="mime":media[3]=""
            elif mode=="none_mime":media[7]="image/png"
            elif mode=="mode":serving[2]=K("OFFCHAIN")
            elif mode=="display_hash":serving[7]=K("different image URI")
            else:renderer[5]=K("different renderer context")
            capsule[14]=tuple(media);capsule[8]=tuple(serving);capsule[10]=tuple(renderer)
            release[2]=s.hash_abi(("bytes32",s.SOURCE[14]),(K("6529STREAM_MEDIA_MASTER_INVENTORY_V1"),tuple(media)))
            release[1]=s.hash_abi(("bytes32","uint256","address","uint256","bytes32","bytes32","bytes32"),
                (K("6529STREAM_CONSERVATION_COLLECTION_RELEASE_V1"),31337,f.core,1,release[0],release[2],release[3]))
            release[4]=s.hash_abi(("bytes32","bytes32","bytes32","uint8",s.SOURCE[8],"bytes32"),
                (capsule[2][4],capsule[13],capsule[11],1,tuple(serving),release[1]))
            capsule[3]=tuple(release);capsule=tuple(capsule)
            p=list(row["publication"]);p[4]=s.source_hash(f.prospective_anchor,row["dependencies"],1,capsule)
            e=(p[4],*row["evidence"][1:])
            f.recommit_prospective(publication=tuple(p),source=capsule,evidence=e,receipt_changes={7:release[1]})
            with self.subTest(mode=mode),self.assertRaisesRegex(MuseumError,reason):f.result()

    def test_gas_registration_unknown_update_and_reused_action_reject(self):
        for mode in ("registration","unknown_update","wrong_old","reuse"):
            f=PublicProspectiveReferenceFixture(raised=mode in ("wrong_old","reuse"))
            if mode=="registration":f.event(0,f.prospective_host,[s.REGISTERED_EVENT,K("unknown")],s.REGISTERED_DATA,(2,"UNKNOWN",1,1,2))
            elif mode=="unknown_update":f.event(1,f.prospective_host,[s.UPDATED_EVENT,K("unknown"),s.topic("address",f.prospective_host),K("action")],s.UPDATED_DATA,(2,1,2,1))
            else:
                event=next(e for r in f.receipts.values() for e in r["logs"] if e["address"]==f.prospective_host and e["topics"][0]==s.UPDATED_EVENT)
                if mode=="wrong_old":event["data"]="0x"+encode(s.UPDATED_DATA,(2,499999,501000,50000)).hex()
                else:f.event(5,f.prospective_host,list(event["topics"]),s.UPDATED_DATA,(2,501000,502000,50000))
            with self.subTest(mode=mode),self.assertRaises(MuseumError):f.result()

    def test_source_runtime_empty_host_provenance_and_closed_anchor_reject(self):
        for mode in ("empty","runtime","extra","provenance"):
            f=PublicProspectiveReferenceFixture();a=deepcopy(f.prospective_anchor)
            if mode in ("empty","runtime"):
                f.codes[f.prospective_host]=b"" if mode=="empty" else b"different runtime"
                if mode=="empty":next(p for p in a["codePins"] if p["address"]==f.prospective_host)["runtimeHash"]=keccak256(b"")
            elif mode=="extra":a["callerCurrent"]=True
            with self.subTest(mode=mode),self.assertRaises(MuseumError):
                s.PublicProspectiveReferenceSource(dumps(a),f,provenance="trusted_rpc" if mode=="provenance" else "synthetic_fixture").snapshot()

    def test_exact_definition_bytes_and_historical_status(self):
        f=PublicProspectiveReferenceFixture();identifier=s.DEFINITIONS[0][0]
        key=(A(3),calldata("documentFacts(bytes32)",("bytes32",),(identifier,)))
        facts=list(decode((s.DOCUMENT_FACTS,),hex_bytes(f.responses[key]))[0]);facts[2]=2
        f.responses[key]="0x"+encode((s.DOCUMENT_FACTS,),(tuple(facts),)).hex()
        self.assertEqual(f.result()["definitions"][0]["currentStatus"],"2")
        facts[3]=K("substitute schema");f.responses[key]="0x"+encode((s.DOCUMENT_FACTS,),(tuple(facts),)).hex()
        with self.assertRaisesRegex(MuseumError,"definition facts"):f.result()

    def test_interface_uses_fixed_bytes32_array_and_script_escape_preserves_case(self):
        self.assertIn("bytes32[2]",s.PUBLICATION_SIGNATURES[5])
        self.assertEqual(s.PUBLICATION_INTERFACE,"0x7d061db6")
        f=PublicProspectiveReferenceFixture();body=s.simulation_html(f.prospective_anchor,1,K("source"),("v",ZERO,b""),b'var x="</ScRiPtSuffix";')
        self.assertIn(b'<\\/ScRiPtSuffix',body)


if __name__=="__main__": unittest.main()
