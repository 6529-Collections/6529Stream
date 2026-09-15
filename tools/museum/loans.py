"""Versioned loan documentation mapping from selected original OwnerRecords receipts."""
from .account_profile import JCS_BYTES
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .exhibitions import fields, nullable, _date, _instant, _iri, _reference
from .owner_record_source import OwnerRecordSource
from .independent_wire import RAW_BYTES
from .preservation_graph import CONTEXT, VALIDATION_HASH, validator
from .review import _validate
from .schemas import HEX32, IRI, TEXT, UINT, arr, definitions, enum, obj

NAME="STREAM_LOAN_V1"
JCS_ID=schema_id("RFC8785_JCS")
MODE="recorded_owner_loan_dossier_projection"
QUALIFICATION="Historical token-owner loan documentation; performance, named-party identity, physical custody and legal title are not independently established."
CLAIMS={"historicalPerformanceProven":False,"namedPartyIdentityProven":False,"custodyTransferred":False,
    "legalTitleTransferred":False,"currentOwnerProven":False,"loanEnforced":False,"countersigned":False,
    "valuationOperativenessProven":False,"referenceBytesRetrieved":False,"institutionalConformance":False,"registeredExport":False}


def documents():
    ref=obj({"uri":IRI,"hash":definitions()["hashRef"]})
    record_ref=obj({"recordHash":HEX32,"uri":IRI,"hash":definitions()["hashRef"]})
    name=obj({"value":dict(TEXT,minLength=1),"language":{"type":["string","null"],"maxLength":128}})
    party=obj({"entityId":IRI,"kind":enum("Person","Group"),"identity":obj({"kind":enum("address","did","record"),"value":TEXT}),
        "name":nullable(name),"reference":ref})
    return {"$schema":"https://json-schema.org/draft/2020-12/schema","title":NAME,
        "description":"Closed prospective token loan documentation; never transfers title or custody.",
        **obj({"version":enum("1"),"loanId":IRI,"tokenId":UINT,"status":enum("planned","completed","cancelled","unknown"),
            "title":nullable(name),"lender":party,"borrower":party,
            "opening":definitions()["date"],"closing":definitions()["date"],
            "insuranceValuation":nullable(record_ref),"outboundConditionReport":nullable(record_ref),"returnConditionReport":nullable(record_ref),
            "conditionReferences":arr(ref,maximum=16),
            "returnConditions":obj({"text":nullable(TEXT),"reference":nullable(ref)})})}


SCHEMA_BYTES=dumps(documents())
PROFILE_BYTES=dumps({"id":"STREAM_MUSEUM_OWNER_LOAN_DOSSIER_PROFILE_V1","version":"1","status":"prospective_unregistered_export_profile",
    "sourceSchemaId":schema_id(NAME),"sourceSchemaHash":keccak256(SCHEMA_BYTES),"validationPolicyHash":VALIDATION_HASH,
    "context":CONTEXT,"qualification":QUALIFICATION,"claims":CLAIMS,"bounds":{"loans":"64","ownerRecords":"128","payloadBytes":"8192"},
    "rules":{
        "source":"Original externally pinned OwnerRecords LOAN receipt, embedded Keccak payload and exact registered candidate schema/JCS. No INDEPENDENT_LOAN family is invented.",
        "parties":"Exact named Person/Group declarations; participant links have separate lender/borrower role correspondence. Wallets and names do not merge IDs or prove institution identity.",
        "status":"Only completed source statements with both named parties and title create generic Activity. No TransferOfCustody, Acquisition or title transfer is emitted.",
        "dates":"Original expressions/precision/calendar/timezone retained. Only explicit Gregorian UTC bounds become TimeSpan bounds; no publication timestamp conversion.",
        "references":"Insurance references an original VALUATION record; outbound and return references name CONDITION_REPORT records of the same token. Missing selected evidence is explicit; reference payloads stay opaque registered bytes, no appraisal or condition facts inferred.",
        "history":"Selected original receipts are historical owner statements. No current ownerOf check or source-time latest valuation assertion; same-block cross-family publication chronology is not inferred from timestamps.",
        "coverage":"Every source value and linked receipt/registered bytes remain in the dossier; each graph value retains original record selectors and source paths. Shared identical same-kind declarations emit once with all source provenance.",
        "privacy":"Only public disclosure; no remote reference fetching or sealed insurance instruments. Null required dossier references become explicit incomplete dispositions."}})
PROFILE_HASH=keccak256(PROFILE_BYTES)


def need(condition,message):
    if not condition:raise MuseumError("loan "+message)


def selector(source,row):
    r,t=row["record"],row["receipt"]
    return {"host":source.a["host"],"recordHash":row["recordHash"],"subjectId":r[1],"schemaId":r[2],
        "schemaHash":t[9],"recordType":r[0],"owner":t[1],"recordIndex":t[3],"recordChainHash":t[4],"pointer":""}


def admit(source,selected):
    """Pure shape/semantic admission also permits explicitly labelled synthetic wire controls."""
    need(isinstance(selected,list) and len(selected)<=64,"selection bound")
    rows=[];seen=set();identities={}
    for h in selected:
        need(hex_bytes(h,32)!=bytes(32) and h not in seen,"duplicate/invalid selected record");seen.add(h)
        need(h in source.records,"selected owner loan record missing")
        row=source.records[h];r,t=row["record"],row["receipt"]
        need(r[0]==schema_id("LOAN") and r[2]==schema_id(NAME) and r[3][2]==JCS_ID
            and source.documents[r[2]][1]==SCHEMA_BYTES and source.documents[r[2]][2][3][3]==JCS_ID
            and source.documents[JCS_ID][1]==JCS_BYTES and source.documents[JCS_ID][2][3][3]==RAW_BYTES,
            "exact original LOAN/schema/JCS required")
        value=_validate(SCHEMA_BYTES,hex_bytes(row["payloadHex"]))
        need(uint(value["tokenId"])>0 and value["tokenId"]==t[0],"original token subject differs")
        _iri(value["loanId"])
        need(value["loanId"] not in identities,"event identity reused")
        identities[value["loanId"]]=("Activity",dumps(value))
        for role in ("lender","borrower"):
            party=value[role];identifier=party["entityId"]
            _iri(identifier);_reference(party["reference"])
            need(not identifier.casefold().startswith(("urn:6529stream:account:","eip155:")),"party account equivalence")
            exact=(party["kind"],dumps(party))
            need(identifier not in identities or identities[identifier]==exact,"conflicting/cross-kind party declaration")
            identities[identifier]=exact
            identity=party["identity"]
            if identity["kind"] in ("address","record"):
                need(any(hex_bytes(identity["value"],20 if identity["kind"]=="address" else 32)),"empty party identity")
            else:
                _iri(identity["value"]);need(identity["value"].startswith("did:"),"party DID required")
        need(value["lender"]["entityId"]!=value["borrower"]["entityId"],"same party on both loan roles")
        bounds=[_date(value[k]) for k in ("opening","closing")]
        if all(bounds) and value["opening"]["earliest"] is not None and value["closing"]["latest"] is not None:
            need(_instant(value["opening"]["earliest"])<=_instant(value["closing"]["latest"]),"closing precedes opening")
        for ref in value["conditionReferences"]:_reference(ref)
        if value["returnConditions"]["reference"] is not None:_reference(value["returnConditions"]["reference"])
        refs=[];missing=[]
        for field,family,schema in (("insuranceValuation","VALUATION","STREAM_VALUATION_V1"),
                ("outboundConditionReport","CONDITION_REPORT","STREAM_CONDITION_REPORT_V1"),
                ("returnConditionReport","CONDITION_REPORT","STREAM_CONDITION_REPORT_V1")):
            ref=value[field]
            if ref is None:
                missing.append(field+"_not_recorded");continue
            _reference(ref);need(hex_bytes(ref["recordHash"],32)!=bytes(32),"zero reference record")
            linked=source.records.get(ref["recordHash"])
            if linked is None:
                missing.append(field+"_selected_record_missing");continue
            lr,lt=linked["record"],linked["receipt"]
            need(lr[0]==schema_id(family) and lr[2]==schema_id(schema) and lr[1]==r[1] and lt[0]==t[0]
                and ref["hash"]=={"algorithm":str(lr[3][0]),"digest":lr[3][1],"canonicalizationId":lr[3][2]},
                "linked reference family/schema/subject/content differs")
            refs.append({"field":field,"source":selector(source,linked),"authority":linked["authority"],
                "originalPayloadHex":linked["payloadHex"],"registeredSchemaHex":"0x"+source.documents[lr[2]][1].hex(),
                "interpretation":"opaque_original_registered_bytes",
                "recordedBeforeLoan":uint(lt[2])<uint(t[2]),"operativeAtLoanPublicationProven":False})
        if value["returnConditions"]["text"] is None and value["returnConditions"]["reference"] is None:missing.append("return_conditions_not_recorded")
        rows.append({"source":selector(source,row),"authority":row["authority"],"value":value,"bounds":bounds,"references":refs,"missing":missing})
    return sorted(rows,key=lambda row:row["source"]["recordHash"])


def render(rows,model,missing_source=False):
    files={};index=[];provenance=[];dossiers=[];coverage=[];dispositions=[];roles=[]
    def named(identifier,kind,name):
        return {"@context":CONTEXT,"id":identifier,"type":kind,"_label":name["value"],
            "identified_by":[{"type":"Name","content":name["value"]}],
            "referred_to_by":[{"type":"LinguisticObject","content":QUALIFICATION}]}
    def emit(resource,row,paths):
        raw=dumps(resource);result=model.validate_and_expand(raw);key=keccak256(resource["id"].encode())[2:]
        path="loans/resources/"+key+".json"
        if path in files:need(files[path]==raw,"conflicting resource output")
        else:
            files[path]=raw;files["loans/expanded/"+key+".json"]=result.expanded_bytes
            index.append({"id":resource["id"],"type":resource["type"],"path":path})
        provenance.extend({"entity":resource["id"],"path":p,"value":v,"source":row["source"],"sourcePaths":paths,
            "rule":"urn:6529stream:museum:owner-loan:v1:documented-activity","qualification":QUALIFICATION} for p,v in fields(resource))
    for row in rows:
        v=row["value"];missing=list(row["missing"])
        dossiers.append({"source":row["source"],"authority":row["authority"],"loan":v,"references":row["references"],"qualification":QUALIFICATION})
        coverage.extend({"source":row["source"],"sourcePath":p,"value":value,"disposition":"retained_stream_only"} for p,value in fields(v))
        names=[v["title"],v["lender"]["name"],v["borrower"]["name"]]
        missing.extend(name+"_name_not_recorded" for name,value in zip(("title","lender","borrower"),names) if value is None)
        disposition="nonperformed_source" if v["status"]!="completed" else "unsupported" if any(x is None for x in names) else "activity"
        dispositions.append({"source":row["source"],"sourceStatus":v["status"],"disposition":disposition,"missingFacts":missing})
        if disposition!="activity":continue
        event=named(v["loanId"],"Activity",v["title"]);event["participant"]=[]
        for role in ("lender","borrower"):
            party=v[role];entity=named(party["entityId"],party["kind"],party["name"])
            event["participant"].append({"id":entity["id"],"type":entity["type"]})
            emit(entity,row,["/"+role]);roles.append({"event":v["loanId"],"participant":entity["id"],"role":role,"source":row["source"],"sourcePath":"/"+role})
        span={"type":"TimeSpan","identified_by":[{"type":"Name","content":v["opening"]["expression"]+" / "+v["closing"]["expression"]}]}
        for i,k,names in ((0,"opening",("begin_of_the_begin","end_of_the_begin")),(1,"closing",("begin_of_the_end","end_of_the_end"))):
            if row["bounds"][i] and v[k]["earliest"] is not None:span[names[0]],span[names[1]]=v[k]["earliest"],v[k]["latest"]
        event["timespan"]=span;emit(event,row,["/loanId","/status","/title","/lender","/borrower","/opening","/closing"])
    reason="owner_receipt_source_missing" if missing_source else "no_selected_owner_loan_records" if not rows else None
    status="unsupported" if reason else "incomplete" if any(r["missingFacts"] for r in dispositions) else "complete_with_stream_extensions"
    for name,value in {"index":{"resources":sorted(index,key=lambda r:r["id"])},"provenance":provenance,"dossiers":dossiers,
        "coverage":coverage,"participant-roles":roles,"report":{"mode":MODE,"version":"1","profileHash":PROFILE_HASH,
        "status":status,"reasonCode":reason,"dispositions":dispositions,"claims":CLAIMS,"qualification":QUALIFICATION}}.items():files["loans/"+name+".json"]=dumps(value)
    return files


def project_loans(source,plan_bytes,*,plan_hash,profile_hash,source_hash,model):
    need(profile_hash==PROFILE_HASH and keccak256(plan_bytes)==plan_hash,"external profile/plan pin differs")
    plan=loads(plan_bytes,maximum=524288,canonical=True)
    need(isinstance(plan,dict) and set(plan)=={"version","ownerSourceHash","records"} and plan["version"]=="1"
        and plan["ownerSourceHash"]==source_hash,"source-bound plan differs")
    if source is None:
        need(source_hash is None and plan["records"]==[],"selected loans require owner source")
        return render([],model,True)
    need(type(source) is OwnerRecordSource and source.provenance=="trusted_rpc","concrete recorded owner source required")
    need(keccak256(source.snapshot())==source_hash,"owner source snapshot pin differs")
    return render(admit(source,plan["records"]),model)


def main():
    import argparse
    from pathlib import Path
    p=argparse.ArgumentParser(description="Generate/check prospective loan definitions; no registration.");p.add_argument("--check",action="store_true")
    args=p.parse_args();root=Path(__file__).resolve().parents[2]/"schemas/museum/loan"
    for name,raw in ((NAME+".json",SCHEMA_BYTES),("profile.json",PROFILE_BYTES)):
        path=root/name
        if args.check:need(path.is_file() and path.read_bytes()==raw,"definition differs")
        else:root.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
    print(PROFILE_HASH)


if __name__=="__main__":main()
