"""Actual OwnerRecords publication helpers and read-only local capture/offline replay.

The current-stack mint recipe is separate. This module never starts Anvil, mints a
token, impersonates an owner, or turns Foundry inspector logs into RPC receipts.
"""
from pathlib import Path
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_abi import encode, decode
from .chain_rpc import RpcTransport, ReplayTransport, MAX_TRANSCRIPT
from .current_native_fixture import CurrentNativeFixture
from .current_museum_capture import CurrentMuseumFixture
from .independent_wire import ZERO, RAW_BYTES, require
from .owner_record_source import OwnerRecordSource, OWNER_RECORD, verify_wire
from .valuation_history import ValuationHistory, PROFILE as HISTORY_PROFILE, EVENT
from .loan_package import build_loan_package
from .valuation_package import build_valuation_package
from .package_recorded import verify_recorded_package
from .package import write_package
from .package_v2 import verify_package
from .loans import NAME as LOAN_NAME, SCHEMA_BYTES as LOAN_SCHEMA, PROFILE_HASH as LOAN_PROFILE
from .valuations import NAME as VAL_NAME, SCHEMA_BYTES as VAL_SCHEMA, PROFILE_HASH as VAL_PROFILE, JCS_ID
from .account_profile import JCS_BYTES

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "test/fixtures/metadata/current-owner-museum"
HOST = "StreamOwnerRecords"
QUALIFICATION = "Public local test declarations from actual owner receipts; no institutional acceptance, physical performance, legal rights, current valuation or professional countersignature is established."
CONDITION_NAME = "CURRENT_OWNER_MUSEUM_CONDITION_FIXTURE_V1"
CONDITION_SCHEMA = dumps({"type": "object", "additionalProperties": False,
    "properties": {"note": {"type": "string"}, "version": {"const": "1"}}, "required": ["note", "version"]})
MARKERS = tuple("0x" + c * 64 for c in ("a", "b", "c", "d", "e", "f"))


def example_payloads():
    def ref(text):
        return {"uri": "urn:stream:local-owner:" + text, "hash": {"algorithm": "1",
            "digest": keccak256(("Explicit public test reference: " + text).encode()),
            "canonicalizationId": RAW_BYTES}}
    def party(name):
        return {"entityId": "urn:stream:local-owner:" + name, "kind": "Group",
            "identity": {"kind": "did", "value": "did:example:" + name},
            "name": {"value": "Fictional test " + name, "language": "en"}, "reference": ref(name)}
    def date(value):
        return {"expression": value, "earliest": value + "T00:00:00Z", "latest": value + "T23:59:59Z",
            "precision": "range", "calendar": "gregorian", "timezone": "UTC"}
    valuation = {"version": "1", "valuationId": "urn:stream:local-owner:insurance", "tokenId": "1",
        "status": "asserted", "title": {"value": "Public local insurance test statement", "language": "en"},
        "scope": {"kind": "object", "loanId": None}, "basis": "insurance", "basisReference": ref("insurance-basis"),
        "effectiveDate": date("2026-01-01"), "amount": "1000.004500", "currency": {"kind": "ISO4217", "code": "USD", "reference": None},
        "confidential": False, "instrument": ref("insurance-instrument"), "issuer": party("lender"),
        "appraiser": None, "supersedes": [], "references": [], "countersignatures": []}
    book = dict(valuation, valuationId="urn:stream:local-owner:book-value", basis="book_value", amount="1.2500",
        title={"value": "Separate local book-value test statement", "language": "en"})
    def record_ref(i, name):
        return {"recordHash": MARKERS[i], "uri": "urn:stream:local-owner:" + name,
            "hash": {"algorithm": "1", "digest": MARKERS[i+3], "canonicalizationId": JCS_ID}}
    loan = {"version": "1", "loanId": "urn:stream:local-owner:loan", "tokenId": "1", "status": "completed",
        "title": {"value": "Fictional completed local loan declaration", "language": "en"},
        "lender": party("lender"), "borrower": party("borrower"), "opening": date("2026-01-02"), "closing": date("2026-01-03"),
        "insuranceValuation": record_ref(0, "insurance"), "outboundConditionReport": record_ref(1, "outbound"),
        "returnConditionReport": record_ref(2, "return"), "conditionReferences": [],
        "returnConditions": {"text": "Fictional test terms only; no transfer or enforcement.", "reference": ref("return-terms")}}
    return {"valuation.json": dumps(valuation), "book-value.json": dumps(book), "loan-template.json": dumps(loan),
        "outbound.json": dumps({"version": "1", "note": "Public test outbound declaration; no examination established."}),
        "return.json": dumps({"version": "1", "note": "Public test return declaration; no physical return established."}),
        "condition-schema.json": CONDITION_SCHEMA}


def loan_payload(records, payloads, token_id=1):
    require(len(records) == len(payloads) == 3 and uint(str(token_id)) > 0, "owner fixture reference shape")
    value = loads(example_payloads()["loan-template.json"], canonical=True)
    value["tokenId"] = str(token_id)
    for name, record, payload in zip(("insuranceValuation", "outboundConditionReport", "returnConditionReport"), records, payloads):
        require(hex_bytes(record, 32) != bytes(32) and record not in MARKERS, "actual returned owner hash required")
        value[name]["recordHash"] = record; value[name]["hash"]["digest"] = keccak256(payload)
    return dumps(value)


def record_input(subject, family, schema, payload, effective_at):
    require(0 < len(payload) <= 8192 and 0 < effective_at < 2**64, "owner capture payload/date bound")
    return (schema_id(family), subject, schema_id(schema), (1, hex_bytes(keccak256(payload)), JCS_ID),
        "", payload, effective_at)


def publish_owner_records(fixture, token_id, owner_safe):
    """Mutating recipe for an already constructed isolated current graph; no process creation.

    Caller coordinates the owned chain first. Schema registration must already be admitted
    to its real Executor, and the actual NFT must already belong to the supplied Safe.
    """
    require(isinstance(fixture, CurrentMuseumFixture), "actual museum registration fixture required")
    require(fixture.rpc("eth_chainId", []) == "0x7a69", "owner publication is local chain 31337 only")
    require(owner_safe in fixture.safe_accounts, "known controlled official Safe required")
    require(fixture.call("StreamCore", "ownerOf", (token_id,)) == (owner_safe,), "actual current token owner differs")
    exists, collection, _, burned = fixture.call("StreamCore", "tokenCollectionIdentity", (token_id,))
    require(exists and collection == 1 and not burned, "actual current collection-1 token required")
    require(fixture.call(HOST, "core") == (fixture.addresses["StreamCore"],)
        and fixture.call(HOST, "schemaRegistry") == (fixture.schemas,), "actual owner host dependencies differ")
    require(fixture.call("StreamSchemaRegistry", "documentBytes", (JCS_ID,)) == (JCS_BYTES,), "exact registered JCS definition required")
    # Exact existing definitions, including the shared JCS definition, must be registered.
    for name, raw in ((LOAN_NAME, LOAN_SCHEMA), (VAL_NAME, VAL_SCHEMA), (CONDITION_NAME, CONDITION_SCHEMA)):
        fixture.register_document(name, 0, raw, JCS_ID)
        require(fixture.call("StreamSchemaRegistry", "documentBytes", (schema_id(name),)) == (raw,), "owner registered bytes differ")
    subject, = fixture.call(HOST, "deriveOwnerSubject", (token_id,))
    values = example_payloads(); selected = []; transactions = []; now = int(fixture.rpc("eth_getBlockByNumber", ["latest", False])["timestamp"], 16)
    def publish(family, schema, raw, *, relay=False):
        record = record_input(subject, family, schema, raw, now)
        nonce, deadline = 771, now + 86400
        if relay:
            digest, = fixture.call(HOST, "ownerRecordDigest", (token_id, record, owner_safe, nonce, deadline))
            # Official compatibility handler wraps the original bytes32 in SafeMessage(bytes).
            message_hash, = fixture.read(owner_safe, "getMessageHash(bytes)", ("bytes",), (encode(("bytes32",), (digest,)),), ("bytes32",))
            signature = b""
            for owner in sorted(fixture.safe_accounts[owner_safe]):
                fixture.invoke(owner_safe, "approveHash(bytes32)", ("bytes32",), (message_hash,), sender=owner)
                signature += bytes(12) + hex_bytes(owner, 20) + bytes(32) + b"\x01"
            tx = fixture.transact(HOST, "recordOwnerRecordFor", (token_id, record, owner_safe, nonce, deadline, signature))
        else:
            tx = fixture.transact(HOST, "recordOwnerRecord", (token_id, record), safe=owner_safe)
        events = [e for e in tx["logs"] if e["address"] == fixture.addresses[HOST] and e["topics"] and e["topics"][0] == EVENT]
        require(len(events) == 1, "one actual owner event required")
        saved_record, h, chain, relayed, version = decode((OWNER_RECORD, "bytes32", "bytes32", "bool", "uint16"), hex_bytes(events[0]["data"]))
        actual_record, receipt = fixture.call(HOST, "ownerRecord", (h,))
        _, bundle = fixture.call(HOST, "ownerRecordSignatureBundle", (h,))
        require(saved_record == actual_record == record and relayed == relay and version == 1 and receipt[4] == chain, "owner event/readback differs")
        stamp = int(fixture.rpc("eth_getBlockByNumber", ["latest", False])["timestamp"], 16)
        verify_wire(31337, fixture.addresses[HOST], fixture.addresses["StreamCore"], stamp, h, token_id, record, receipt, bundle)
        selected.append({"recordHash": h, "tokenId": str(token_id)}); transactions.append(tx["transactionHash"])
        return h
    def token(raw):
        value = loads(raw, canonical=True); value["tokenId"] = str(token_id); return dumps(value)
    insurance_payload = token(values["valuation.json"])
    insurance = publish("VALUATION", VAL_NAME, insurance_payload)
    outgoing = publish("CONDITION_REPORT", CONDITION_NAME, values["outbound.json"])
    returned = publish("CONDITION_REPORT", CONDITION_NAME, values["return.json"])
    loan = publish("LOAN", LOAN_NAME, loan_payload((insurance, outgoing, returned),
        (insurance_payload, values["outbound.json"], values["return.json"]), token_id), relay=True)
    book = publish("VALUATION", VAL_NAME, token(values["book-value.json"]))
    require(fixture.call("StreamCore", "ownerOf", (token_id,)) == (owner_safe,), "record publication changed actual ownership")
    return {"records": selected, "loans": [loan], "valuations": [insurance, book],
        # History requires loan and all valuation events, not unrelated condition receipts.
        "transactions": [transactions[i] for i in (0, 3, 4)], "qualification": QUALIFICATION}


def make_owner_anchor(fixture, account_anchor, evidence, records):
    """Pin the same final block after both account and owner publications have finished."""
    from .owner_record_source import PROFILE
    require(isinstance(fixture, CurrentNativeFixture), "actual native fixture required")
    original = loads(account_anchor, maximum=524288, canonical=True)
    require(original["core"] == fixture.addresses["StreamCore"] and original["environment"] == "local_evm_fixture"
        and original["chainId"] == "31337", "owner anchor original current fixture differs")
    block = {"blockHash": original["blockHash"], "requireCanonical": True}
    addresses = {"host": fixture.addresses[HOST], "core": original["core"], "schemas": fixture.schemas, "store": fixture.store}
    pins = [{"address": a, "runtimeHash": keccak256(hex_bytes(fixture.rpc("eth_getCode", [a, block])))} for a in sorted(set(addresses.values()))]
    return dumps({"profile": PROFILE, **{k: original[k] for k in ("chainId", "blockHash", "blockNumber", "timestamp", "stateRoot", "environment")},
        "deploymentEvidenceHash": keccak256(evidence), **addresses, "codePins": pins, "records": records})


def capture_owner_evidence(account_package, account_hash, anchor_bytes, evidence_bytes, plan_bytes, *, plan_hash, transport, disclosure):
    """Read-only RPC capture; returns byte inputs. Never interprets a test trace as receipts."""
    require(disclosure == "public" and type(transport) is RpcTransport, "explicit public RPC capture required")
    import urllib.parse
    require(urllib.parse.urlparse(transport._endpoint).hostname == "127.0.0.1", "owner capture loopback only")
    require(keccak256(plan_bytes) == plan_hash, "owner capture plan hash differs")
    plan = loads(plan_bytes, maximum=524288, canonical=True)
    require(isinstance(plan, dict) and set(plan) == {"version", "loans", "valuations", "transactions"} and plan["version"] == "1", "owner capture plan shape")
    for key in ("loans", "valuations", "transactions"):
        require(isinstance(plan[key], list) and 0 < len(plan[key]) <= 64 and len(set(plan[key])) == len(plan[key]), "owner capture selection bound")
        for h in plan[key]: require(hex_bytes(h, 32) != bytes(32), "owner capture empty hash")
    original = verify_recorded_package(account_package, account_hash)
    files = dict(original.files)
    for path in ("premis/premis.xml", "iiif/manifest.json", "lido/lido.xml", "linked-art/entity-index.json"):
        require(path in files, "actual recorded four-format base required: " + path)
    account_anchor = loads(files["inputs/anchor.json"], maximum=524288, canonical=True)
    source = OwnerRecordSource(anchor_bytes, transport, provenance="trusted_rpc")
    require(source.a["environment"] == "local_evm_fixture" and source.a["chainId"] == "31337", "local owner capture only")
    require(keccak256(evidence_bytes) == source.a["deploymentEvidenceHash"], "owner deployment evidence differs")
    for key in ("chainId", "core", "blockHash", "blockNumber", "timestamp", "stateRoot", "environment"):
        require(source.a[key] == account_anchor[key], "account/owner original anchor differs: " + key)
    snapshot = source.snapshot(); transcript = source.reader.transcript()
    hints = dumps({"profile": HISTORY_PROFILE, "ownerSourceHash": keccak256(snapshot), "loans": plan["loans"], "transactions": plan["transactions"]})
    history = ValuationHistory(source, hints, transport, hints_hash=keccak256(hints), provenance="trusted_rpc")
    history_snapshot = dumps(history.capture()); history_transcript = history.reader.transcript()
    inputs = {"anchor.json": anchor_bytes, "transcript.json": transcript, "deployment-evidence.json": evidence_bytes}
    owner_pins = {"anchorHash": keccak256(anchor_bytes), "transcriptHash": keccak256(transcript), "sourceHash": keccak256(snapshot)}
    history_inputs = {"hints.json": hints, "transcript.json": history_transcript}
    history_pins = {"hintsHash": keccak256(hints), "transcriptHash": keccak256(history_transcript), "snapshotHash": keccak256(history_snapshot)}
    # Exercise only the offline reconstruction from here, using the captured literal bytes.
    replay = OwnerRecordSource(anchor_bytes, ReplayTransport(transcript, owner_pins["transcriptHash"]), provenance="trusted_rpc")
    require(replay.snapshot() == snapshot, "owner offline source replay differs")
    replay_history = ValuationHistory(replay, hints, ReplayTransport(history_transcript, history_pins["transcriptHash"]), hints_hash=keccak256(hints), provenance="trusted_rpc")
    require(dumps(replay_history.capture()) == history_snapshot, "owner offline history replay differs")
    return inputs, owner_pins, history_inputs, history_pins, plan


def export_owner_dossier(account_package, account_hash, captured, output, *, disclosure):
    """Network-free composition of the exact source package and both derivative profiles."""
    inputs, owner_pins, history_inputs, history_pins, plan = captured
    output = Path(output); require(not output.exists() and not output.is_symlink(), "owner capture output exists")
    original = verify_recorded_package(account_package, account_hash)
    original_files = dict(original.files)
    for path in ("premis/premis.xml", "iiif/manifest.json", "lido/lido.xml", "linked-art/entity-index.json"):
        require(path in original_files, "actual recorded four-format base required: " + path)
    loan_plan = dumps({"version": "1", "ownerSourceHash": owner_pins["sourceHash"], "records": plan["loans"]})
    loan = build_loan_package(account_package, account_hash, loan_plan, plan_hash=keccak256(loan_plan),
        profile_hash=LOAN_PROFILE, owner_inputs=inputs, owner_pins=owner_pins, disclosure=disclosure)
    output.mkdir(parents=True, exist_ok=False); write_package(loan, output / "loan-package")
    valuation_plan = dumps({"version": "1", "ownerSourceHash": owner_pins["sourceHash"], "records": plan["valuations"], "loans": plan["loans"]})
    result = build_valuation_package(output / "loan-package", loan.manifest_hash, valuation_plan,
        plan_hash=keccak256(valuation_plan), profile_hash=VAL_PROFILE, history_inputs=history_inputs, history_pins=history_pins, disclosure=disclosure)
    write_package(result, output / "valuation-package"); verify_package(output / "valuation-package", result.manifest_hash)
    # Preserve all original formats literally rather than inserting loan/monetary fields
    # into format profiles that do not define them. New semantics have explicit sidecars.
    emitted = dict(result.files)
    for path, raw in original.files: require(emitted["source/source/" + path] == raw, "four-format original bytes drifted")
    report = {"mode": "recorded_local_owner_dossier_capture", "sourceManifestHash": account_hash,
        "loanManifestHash": loan.manifest_hash, "valuationManifestHash": result.manifest_hash,
        "formatsRetained": ["Linked Art", "PREMIS", "IIIF", "LIDO"], "offlineReplayed": True,
        "newSemanticProfiles": ["owner loan", "owner valuation"], "qualification": QUALIFICATION,
        "loanInsuranceStatuses": [r["status"] for r in loads(emitted["valuations/loan-insurance.json"], maximum=MAX_TRANSCRIPT)],
        "institutionalConformance": False, "consensusFinality": False, "loanCustodyProven": False}
    output.joinpath("result.json").write_bytes(dumps(report)); return report


def main():
    import argparse
    import urllib.parse
    p = argparse.ArgumentParser(description=__doc__); sub = p.add_subparsers(dest="command", required=True)
    check = sub.add_parser("check-fixtures")
    capture = sub.add_parser("capture", help="Read an already coordinated loopback chain; never publishes or starts a process")
    for name in ("account-package", "anchor", "evidence", "plan", "output"): capture.add_argument("--" + name, type=Path, required=True)
    for name in ("account-hash", "anchor-hash", "plan-hash", "rpc"): capture.add_argument("--" + name, required=True)
    capture.add_argument("--disclosure", choices=("public", "restricted"), required=True)
    args = p.parse_args()
    try:
        if args.command == "check-fixtures":
            for name, raw in example_payloads().items(): require((DATA / name).read_bytes() == raw, "owner fixture bytes differ: " + name)
            print("owner fixture bytes match"); return 0
        require(urllib.parse.urlparse(args.rpc).hostname == "127.0.0.1", "owner capture loopback only")
        for path in (args.anchor, args.evidence, args.plan): require(path.stat().st_size <= MAX_TRANSCRIPT, "owner capture input bound")
        anchor = args.anchor.read_bytes(); require(keccak256(anchor) == args.anchor_hash, "owner external anchor hash differs")
        captured = capture_owner_evidence(args.account_package, args.account_hash, anchor, args.evidence.read_bytes(), args.plan.read_bytes(),
            plan_hash=args.plan_hash, transport=RpcTransport(args.rpc), disclosure=args.disclosure)
        print(dumps(export_owner_dossier(args.account_package, args.account_hash, captured, args.output, disclosure=args.disclosure)).decode()); return 0
    except (MuseumError, OSError) as exc: p.exit(2, str(exc) + "\n")


if __name__ == "__main__": main()
