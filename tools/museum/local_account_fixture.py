"""Public local-EVM semantic inputs; uses the existing reviewed host artifacts only."""

import copy
from pathlib import Path

from .account_profile import AccountProjectionProfile, JCS_ID, JCS_NAME, account_iri
from .canonical import dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import decode
from .chain_rpc import ReplayTransport, RpcTransport
from .independent_publication import EVENT_DATA, EVENT_TOPIC
from .independent_source import IndependentSourceAdapter
from .independent_wire import RAW_BYTES, RECORD, RECEIPT, SUBJECT, ZERO, require
from .local_independent_fixture import REQUEST, WRITE_SIGNATURE
from .projection import CRM, LA
from .projection_v2 import CONTENT, CONTENT_KIND, STRING
from .recorded_semantic import RegisteredInterpretationCapture, RecordedSemanticSource
from .recorded_selection import project_recorded
from .review import REVIEW_MAPPING_RULE, REVIEW_RELATION, review_literal
from .schemas import NAMES

ROOT = Path(__file__).resolve().parents[2] / "schemas/museum"


def _selector(host, h, generic, receipt, schema, pointer=""):
    return {"host": host, "recordHash": h, "subjectId": generic[1], "schemaId": generic[4],
        "schemaHash": keccak256(schema), "recordType": generic[0], "recorder": receipt[1],
        "authorizationClass": "INDEPENDENT_ATTESTOR", "recordIndex": str(receipt[4]),
        "recordChainHash": receipt[5], "pointer": pointer}


def publish_semantics(fixture, anchor, evidence):
    a = loads(anchor)
    profile = AccountProjectionProfile(ROOT)
    base = loads(IndependentSourceAdapter(anchor, RpcTransport(fixture.endpoint), provenance="trusted_rpc").snapshot(), maximum=16777216)
    original = next(r for r in base["records"] if r["receipt"][1] == fixture.account)
    schema = next(hex_bytes(d["payloadHex"]) for d in base["documents"] if d["documentId"] == original["record"][4])
    prior = _selector(a["host"], original["recordHash"], original["record"], original["receipt"], schema)
    order = [JCS_NAME] + [name for name in profile.documents if name != JCS_NAME]
    executor = fixture.addresses["IndependentExecutorBoundary"]
    for name in order:
        kind, raw = profile.documents[name]
        fixture.register(a["schemas"], executor, a["store"], name, kind, raw, RAW_BYTES if name == JCS_NAME else JCS_ID)
    subject = (0, 1, 0, ZERO)
    sid, = fixture.read(a["host"], "deriveSubject((uint8,uint256,uint256,bytes32))", (SUBJECT,), (subject,), ("bytes32",))
    agent = account_iri(a["chainId"], fixture.account)
    stamp = "2026-09-12T00:00:00Z"  # Claimed creation time, deliberately not publication order.
    evidence_ref = {"source": {"algorithm": "1", "digest": original["record"][2][1], "canonicalizationId": RAW_BYTES},
        "selectorType": "json_pointer", "selector": "/exactText", "basis": "own_signed_statement"}
    def entity(suffix, kind):
        return {"id": "urn:local:semantic:" + suffix, "kind": kind, "declaringAgent": agent,
            "names": [{"value": suffix + " — A\r\n& < > 🧭", "language": None, "kind": "preferred"}],
            "sourceRecords": [prior], "predecessors": []}
    def claim(index, subject_, relation, obj, origin="direct_statement"):
        return {"id": "urn:local:semantic:assertion:" + str(index), "subject": "urn:local:semantic:" + subject_,
            "relation": relation, "object": obj, "assertingAgent": agent, "createdAt": stamp,
            "evidence": [evidence_ref], "origin": origin, "reviewStatus": "unreviewed",
            "mappingRule": "urn:local:semantic:mapping:" + str(index), "rationale": "Public local account statement; no human-identity inference.",
            "reviewEvidence": [], "corrects": [], "disputes": []}
    def literal(value):
        return {"literal": {"lexicalValue": value, "datatype": STRING, "language": None, "unit": None, "precision": None}}
    claims = [claim(0, "file", LA + "digitally_shows", {"entity": "urn:local:semantic:visual"}),
        claim(1, "visual", CRM + "P129_is_about", {"entity": "urn:local:semantic:work"}, "human_mapping"),
        claim(2, "text", CONTENT_KIND, literal("linguistic")),
        claim(3, "text", CONTENT, literal("A\r\n& < > 🧭 " + str((1 << 256) - 1)))]
    payload = {"profileSchemaId": schema_id(NAMES[0]), "profileHash": profile.profile_hash,
        "anchorSubject": {"kind": "collection", "subjectId": sid},
        "entities": [entity("file", "digital_object"), entity("visual", "visual_content"),
            entity("work", "abstract_work"), entity("text", "information_object")],
        "assertions": claims, "sourceRecords": [prior], "authorityAlignments": []}
    def publish(value, nonce, attestor=None):
        attestor = attestor or fixture.account
        raw = dumps(value)
        require(len(raw) <= 8192, "local semantic payload exceeds host bound")
        now = int(fixture.rpc("eth_getBlockByNumber", ["latest", False])["timestamp"], 16)
        request = (attestor, 1, sid, schema_id("INDEPENDENT_SEMANTIC_ASSERTION"), schema_id(NAMES[1]), 1,
            hex_bytes(keccak256(raw)), JCS_ID, "ipfs://public-local-semantic-fixture", raw, now, nonce, now + 86400)
        tx = fixture.invoke(a["host"], WRITE_SIGNATURE, (SUBJECT, REQUEST, "bytes"), (subject, request, b""), sender=attestor)
        event = next(e for e in tx["logs"] if e["address"] == a["host"] and e["topics"][0] == EVENT_TOPIC)
        h = decode(EVENT_DATA, hex_bytes(event["data"]))[1]
        generic, receipt = fixture.read(a["host"], "collectionRecord(bytes32)", ("bytes32",), (h,), (RECORD, RECEIPT))
        return _selector(a["host"], h, generic, receipt, profile.documents[NAMES[1]][1]), raw
    all_claims = payload["assertions"]
    payload["assertions"] = all_claims[:2]
    first, first_raw = publish(payload, 10)
    content_record = copy.deepcopy(payload)
    content_record.update(entities=[], assertions=all_claims[2:])
    publish(content_record, 12)
    target = first | {"pointer": "/assertions/1"}
    body = {"assertionRecord": target, "assertionRevisionHash": keccak256(dumps(claims[1])),
        "profileHash": profile.profile_hash, "mappingRule": claims[1]["mappingRule"], "disposition": "reviewed"}
    review = claim("review", "unused", REVIEW_RELATION, {"literal": review_literal(body)})
    review.update(subject=claims[1]["id"], mappingRule=REVIEW_MAPPING_RULE)
    review["evidence"] = [{"source": {"algorithm": "1", "digest": keccak256(first_raw), "canonicalizationId": JCS_ID},
        "selectorType": "json_pointer", "selector": "/assertions/1", "basis": "own_signed_statement"}]
    second = copy.deepcopy(payload)
    second.update(entities=[], assertions=[review], sourceRecords=[first])
    publish(second, 11)
    # Actual signed counterexample: a different account can author a review but cannot establish independent human identity.
    other = fixture.rpc("eth_accounts", [])[1]
    foreign = copy.deepcopy(second)
    foreign["assertions"][0]["assertingAgent"] = account_iri(a["chainId"], other)
    foreign["assertions"][0]["evidence"][0]["basis"] = "documentary_evidence"
    publish(foreign, 10, other)
    # Real signed records with well-formed JSON but unsupported account/profile authority.
    # They remain unselected sidecars; tests explicitly select each counterexample.
    for index, tag in enumerate(("wrong_chain", "leading_zero", "upper_case", "foreign_account",
                               "declaring_agent", "account_person", "wrong_profile", "conflicting_content")):
        bad = copy.deepcopy(content_record)
        bad["assertions"] = [copy.deepcopy(all_claims[3])]
        assertion = bad["assertions"][0]
        assertion["rationale"] = "Actual signed negative: " + tag
        if tag == "wrong_chain":
            assertion["assertingAgent"] = agent.replace(":31337:", ":1:")
        elif tag == "leading_zero":
            assertion["assertingAgent"] = agent.replace(":31337:", ":031337:")
        elif tag == "upper_case":
            assertion["assertingAgent"] = agent[:agent.rfind(":") + 1] + fixture.account.upper()
        elif tag == "foreign_account":
            assertion["assertingAgent"] = account_iri(a["chainId"], other)
        elif tag == "declaring_agent":
            bad["entities"] = [entity("fake", "person")]
            bad["entities"][0]["declaringAgent"] = account_iri(a["chainId"], other)
        elif tag == "account_person":
            bad["entities"] = [entity("fake", "person")]
            bad["entities"][0]["id"] = agent
        elif tag == "wrong_profile":
            bad["profileHash"] = "0x" + "11" * 32
        else:
            assertion["object"] = literal("Contradictory exact text")
        publish(bad, 20 + index)
    # Retired profile/schema definitions stay historically resolvable.
    for name in (NAMES[1], JCS_NAME):
        transition = fixture.read(a["schemas"], "statusTransition(bytes32,uint8)", ("bytes32", "uint8"),
            (schema_id(name), 2), ("bytes32",) * 3)
        from .chain_abi import calldata
        fixture.invoke(executor, "execute(address,bytes,bytes32,bytes32,bytes32,uint8)",
            ("address", "bytes", "bytes32", "bytes32", "bytes32", "uint8"),
            (a["schemas"], hex_bytes(calldata("setDocumentStatus(bytes32,uint8)", ("bytes32", "uint8"), (schema_id(name), 2))), *transition, 1))
    block = fixture.rpc("eth_getBlockByNumber", ["latest", False])
    old = loads(evidence, maximum=16777216)
    updated = dumps(old | {"transactions": fixture.receipts})
    a.update(blockHash=block["hash"], blockNumber=str(int(block["number"], 16)),
        timestamp=str(int(block["timestamp"], 16)), stateRoot=block["stateRoot"], deploymentEvidenceHash=keccak256(updated))
    return dumps(a), updated


def default_inputs(source):
    semantic = [r for r in source.state.records if r.selector.schema_id == schema_id(NAMES[1])]
    original = next(r for r in semantic if len(loads(r.payload)["entities"]) == 4)
    account = source.payload(original)["assertions"][0]["assertingAgent"]
    review = next(r for r in semantic if loads(r.payload)["assertions"][0]["relation"] == REVIEW_RELATION
        and r.selector.recorder == original.selector.recorder)
    content = next(r for r in semantic if loads(r.payload)["assertions"][0]["relation"] == CONTENT_KIND)
    from .review import _selector
    policy = {"mode": "recorded_account_selection", "version": "1", "sourceStateHash": source.state.commitment,
        "profileHash": source.profile_hash, "sourceAuthoritySet": [_selector(original, "/assertions/" + str(i)) for i in range(2)]
            + [_selector(content, "/assertions/" + str(i)) for i in range(2)],
        "reviewerAuthoritySet": [_selector(review, "/assertions/0")], "singleValuedRelations": [CONTENT_KIND, CONTENT],
        "independentReviewRequired": False, "allowAccountSelfReview": True}
    plan = {"mode": "recorded_account_resource_projection", "version": "account-1", "sourceStateHash": source.state.commitment,
        "profileHash": source.profile_hash, "selectionPolicyHash": keccak256(dumps(policy)), "crosswalkHash": source.profile.crosswalk_hash,
        "entityAuthoritySet": [_selector(original, "/entities/" + str(i)) for i in range(4)],
        "externalEntities": [{"id": account, "kind": "account"}]}
    return dumps(policy), dumps(plan)


def capture_semantics(publication, replay, endpoint, output):
    profile = AccountProjectionProfile(ROOT)
    capture = RegisteredInterpretationCapture(publication, profile, RpcTransport(endpoint))
    raw = capture.snapshot()
    transcript = capture.probe.reader.transcript()
    (output / "interpretation.json").write_bytes(raw)
    (output / "interpretation-transcript.json").write_bytes(transcript)
    repeated = RegisteredInterpretationCapture(replay, profile, ReplayTransport(transcript, keccak256(transcript)))
    require(repeated.snapshot() == raw, "registered interpretation exact offline parity")
    source = RecordedSemanticSource(repeated, profile_hash=profile.profile_hash)
    selection, plan = default_inputs(source)
    (output / "selection.json").write_bytes(selection)
    (output / "plan.json").write_bytes(plan)
    result = project_recorded(source, selection, plan, selection_hash=keccak256(selection), plan_hash=keccak256(plan))
    for name in ("sidecar", "coverage", "provenance", "report"):
        (output / (name + ".json")).write_bytes(getattr(result, name))
    for index, resource in enumerate(result.resources):
        (output / ("resource-" + str(index) + ".json")).write_bytes(resource.content)
        (output / ("expanded-" + str(index) + ".json")).write_bytes(resource.expanded)
    print(dumps({"mode": "local_evm_fixture", "profileHash": profile.profile_hash,
        "recordCount": str(len(source.records)), "resources": str(len(result.resources)),
        "interpretationHash": keccak256(raw)}).decode())
