"""Synthetic scoped V2 finality events, Executor inputs and RPC rows."""
from copy import deepcopy
from . import native_finality_wire as neutral
from . import native_scoped_policy_finality_wire_v2 as wire
from . import scoped_policy_content_wire_v2 as content
from .canonical import hex_bytes, keccak256, schema_id
from .chain_abi import Array, calldata, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values
from .test_current_rights_source import A, H

def seal_execution(self, b, x, g, statement):
    from .test_governance_transaction_wire import _hashes, _inputs, _events
    a = {k:v["address"] for k,v in g.items()}; chain = int(x["chainId"])
    statement = neutral.from_json(wire.STATEMENT, statement)
    proof = tuple(schema_id("synthetic policy archive " + str(i)) for i in range(3))
    archive = (neutral.archive_evidence_hash(chain, a["core"], a["finality"], a["artifacts"], proof), proof)
    sanction = (neutral.SANCTION, a["artist"], wire.COMPONENT_INTERFACE, self.pins[a["artist"]],
        schema_id("synthetic policy sanction version"), schema_id("synthetic policy sanction manifest"), proof[0])
    components = tuple(sorted((*statement[8], sanction)))
    raw = encode(wire.INPUT_ENVELOPE,
        (wire.INPUT_SCHEMA, wire.INPUT_CANON, chain, a["core"], a["metadata"], a["finality"], statement))
    uri = "ipfs://synthetic-original-policy-finality"
    manifest = (uri, keccak256(uri.encode()), keccak256(raw), wire.INPUT_SCHEMA, wire.INPUT_CANON)
    digest = neutral.components_hash(components)
    record_hash = wire.finality_hash(chain, a["core"], statement[0], statement[1], digest, manifest)
    stamp = int(self.blocks[H(204)]["timestamp"], 16)
    record = (True, statement[0], record_hash, manifest[2], manifest[1], digest, uri, a["finality"], stamp)
    witness = [schema_id("pending synthetic policy action"), A(63001), schema_id("synthetic policy reason"),
        schema_id("synthetic policy role witness"), 1]
    ec = neutral.execution_context(chain, a["finality"], a["core"], a["metadata"], statement,
        record_hash, digest, archive[0])
    raw_call = hex_bytes(calldata(wire.FINALIZE_SIGNATURE, wire.FINALIZE_TYPES,
        (statement[0], components, record_hash, manifest, proof)))
    calls = ((a["finality"], 0, "0x" + raw_call[:4].hex(), keccak256(raw_call), ec["scopeHash"],
        ec["oldValueHash"], ec["newValueHash"]),)
    action = [3, 2, a["finality"], 0, calls[0][2], ZERO, ZERO, ZERO, ZERO,
        int(self.blocks[H(203)]["timestamp"], 16), stamp + 100, witness[1], A(63002), ZERO_ADDRESS,
        ZERO_ADDRESS, witness[2], "synthetic original policy reason", schema_id("synthetic policy action manifest")]
    calls_hash, folds, action_id = _hashes(calls, chain, a["executor"], action, 17)
    action[5:9] = [calls_hash, *folds]; witness[0] = action_id
    runtime = b"\0" + encode((Array("bytes", 64),), ((raw_call,),))
    pointer = A(63003); self.codes[pointer] = runtime; self.pins[pointer] = keccak256(runtime)
    b["finality"] = json_values({"record": record, "components": components, "manifestRef": manifest,
        "manifestBytes": "0x" + raw.hex(), "executionWitness": witness, "archiveWitness": archive,
        "inputsHash": ec["inputsHash"]})
    b["execution"] = json_values({"action": action, "callDataPointer": pointer,
        "callDatas": ("0x" + raw_call.hex(),), "runtime": "0x" + runtime.hex()})
    self.policy_normalized_transactions = _inputs(calls, (raw_call,), action, action_id, a["executor"],
        "schedule_batch", "execute_batch")
    self.policy_governance_events = _events(action, action_id, a["executor"], 17)
    wire.validate_finality(b["finality"], x, g, statement[0])


def install_finality_reads(self, b, x, g):
    a={k:v["address"] for k,v in g.items()}
    def put(role,signature,outputs,values,inputs=(),arguments=()):
        self.add(a[role],signature,inputs,arguments,outputs,values)
    f=b["finality"]; scope=wire.scope_value(b["scope"]); r=neutral.from_json(wire.SCOPED_RECORD,f["record"])
    suffix="((uint8,uint256,uint256,bytes32))"
    put("finality","artworkScopeFinalityRecord"+suffix,(wire.SCOPED_RECORD,),(r,),(wire.SCOPE,),(scope,))
    put("finality","finalityComponentCountForScope"+suffix,("uint256",),(10,),(wire.SCOPE,),(scope,))
    put("finality","finalityComponentsForScope((uint8,uint256,uint256,bytes32),uint256,uint256)",
        (Array(wire.COMPONENT,32),),(neutral.from_json(Array(wire.COMPONENT,32),f["components"]),),
        (wire.SCOPE,"uint256","uint256"),(scope,0,10))
    put("finality","finalityManifestStored(bytes32)",("bool",),(True,),("bytes32",),(r[3],))
    raw=hex_bytes(f["manifestBytes"]);self.chunk(raw)
    put("finality","finalityManifestBytes(bytes32)",("bytes",),(raw,),("bytes32",),(r[3],))
    for name,key,kind in (("finalityExecutionWitness","executionWitness",wire.EXECUTION_WITNESS),
            ("finalitySanctionArchiveWitness","archiveWitness",wire.ARCHIVE_WITNESS)):
        put("finality",name+"(bytes32)",(kind,),(neutral.from_json(kind,f[key]),),("bytes32",),(r[2],))
    action_id=f["executionWitness"][0];e=b["execution"]
    put("executor","governanceAction(bytes32)",(neutral.GOVERNANCE_ACTION,),
        (neutral.from_json(neutral.GOVERNANCE_ACTION,e["action"]),),("bytes32",),(action_id,))
    calls=tuple(hex_bytes(v) for v in e["callDatas"])
    key=keccak256(b"".join(hex_bytes(keccak256(v)) for v in calls))
    put("executor","scheduledCallDataPointer(bytes32)",("address",),(e["callDataPointer"],),("bytes32",),(action_id,))
    put("executor","scheduledCallData(bytes32)",(Array("bytes",64),),(calls,),("bytes32",),(action_id,))
    put("executor","publishedCallData(bytes32)",("address",),(e["callDataPointer"],),("bytes32",),(key,))
    self.codes[e["callDataPointer"]]=hex_bytes(e["runtime"])
    self.pins[e["callDataPointer"]]=keccak256(hex_bytes(e["runtime"]))


def install_events(self,b,x,g):
    from .chain_history import LOG_FIELDS
    descriptors=list(wire.expected_events(b,x,g));observed=[]
    def add(kind, *, predicate=None):
        for row in descriptors:
            if row["kind"]==kind and (predicate is None or predicate(row)):
                observed.append(_raw_event(self,3,row))
    for kind in ("membership_recorded","membership_admitted","membership_progressed","membership_sealed"):
        add(kind)
    add("factory_child_prepared",predicate=lambda row:int(row["topics"][3],16)<2)
    for kind in ("selection_started","selection_appended","selection_completed","content_started","content_appended","content_completed"):
        add(kind)
    # Valid native incremental preparation: checkpoint already complete before
    # the other five children are created; complete graph precedes root adoption.
    add("factory_child_prepared",predicate=lambda row:int(row["topics"][3],16)>=2)
    for kind in ("artifact_recorded","coverage_completed","manifest_started"):
        add(kind)
    count=len(b["membership"]["tokens"])
    for first in range(0,count,16):
        row={"address":g["outputManifest"]["address"],
            "topics":[content.EVENTS["manifestAdvanced"],b["content"]["manifest"]["planHash"]],
            "data":"0x"+encode(("uint16","uint64","uint64"),(2,first,min(first+16,count))).hex()}
        observed.append(_raw_event(self,3,row))
    for kind in ("manifest_verified","policy_snapshot_published","policy_snapshot_locked"):
        add(kind)
    for root in b["content"]["roots"]["history"]:
        for kind in ("root_published","root_binding_published"):
            add(kind,predicate=lambda row:row["topics"][3]==root["recordHash"])
    for kind in ("policy_reference_published","policy_reference_locked"):
        add(kind)
    execution=wire.validate_execution(b["execution"],x,g,wire.validate_finality(b["finality"],x,g,b["scope"]))
    publication={"address":g["executor"]["address"],"topics":[wire.EVENTS["governanceCalldataPublished"],execution["callDataKey"]],
        "data":"0x"+encode(neutral.GOVERNANCE_CALLDATA_DATA,(1,b["execution"]["callDataPointer"],A(63004))).hex()}
    observed.append(_raw_event(self,3,publication))
    schedule=_transaction(self,3,"schedule")
    observed.append(_raw_event(self,3,self.policy_governance_events[0],schedule))
    executed=_transaction(self,4,"execution")
    for row in descriptors:
        if row["kind"] in ("scopedFinalized","manifestPointer","terminalExecuted","executionWitness","archiveWitness"):
            observed.append(_raw_event(self,4,row,executed))
    observed.append(_raw_event(self,4,self.policy_governance_events[1],executed))
    self.policy_events=[{"log":{k:log[k] for k in LOG_FIELDS},
        "timestamp":str(int(self.blocks[log["blockHash"]]["timestamp"],16))} for log in observed]
    wire.validate_event_join(b,x,g,self.policy_events)
    wire.validate_governance(b,x,g,self.policy_normalized_transactions,self.policy_events)


def _raw_event(self, block, row, transaction=None):
    tx = transaction or H(400 + block); receipt = self.receipts[tx]
    header = self.blocks[receipt["blockHash"]]
    offset = sum(len(self.receipts[value]["logs"])
        for value in header["transactions"][:int(receipt["transactionIndex"], 16)])
    log = {key: receipt[key] for key in ("transactionHash", "blockHash", "blockNumber", "transactionIndex")}
    topics = [schema_id("synthetic policy wildcard") if value is None else
        ("0x" + value.hex()) if isinstance(value, bytes) else value for value in row["topics"]]
    log.update(address=row["address"], topics=topics, data=row["data"],
        logIndex=hex(offset + len(receipt["logs"])), removed=False)
    receipt["logs"].append(log)
    return log

def _transaction(self, block, side):
    header = self.blocks[H(200 + block)]
    tx = schema_id("synthetic policy " + side + " transaction")
    normalized = self.policy_normalized_transactions[side]
    receipt = {"transactionHash": tx, "blockHash": header["hash"], "blockNumber": header["number"],
        "transactionIndex": hex(len(header["transactions"])), "status": "0x1", "logs": [],
        "from": normalized["from"], "to": normalized["to"]}
    header["transactions"].append(tx); self.receipts[tx] = receipt
    self.policy_transactions[tx] = {key: receipt[key]
        for key in ("blockHash", "blockNumber", "transactionIndex", "from", "to")}
    self.policy_transactions[tx].update(hash=tx, input=normalized["input"],
        value=hex(int(normalized["value"])), chainId=hex(int(self.a["chainId"])))
    return tx
