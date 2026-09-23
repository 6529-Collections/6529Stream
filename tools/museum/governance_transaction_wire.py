"""Pure original Executor transaction preimages at the frozen e031 native source.

Transaction fields are supplied observations, not a signed-transaction or receipt
proof. Unsupported outer calls are retained as partial; they are never decoded
as if the Executor had been the transaction recipient.

The finite 64-call and 131072-byte input limits and canonical ABI decoding are
consumer availability limits, not claimed Solidity restrictions. In particular,
Solidity may accept ignored trailing transaction calldata. Current policy,
roles, initialization exceptions and EVM execution are not re-executed here.
"""
from . import native_finality_wire as finality
from .canonical import MuseumError, hex_bytes, keccak256, uint
from .chain_abi import Array, decode, encode
from .independent_wire import ZERO_ADDRESS, json_values, require

SOURCE_REVISION = finality.SOURCE_REVISION
MAX_CALLS, MAX_CALL_BYTES, MAX_TRANSACTION_BYTES = 64, 32768, 131072
MAX_CARRIER_BYTES = 24576
CALL = ("address", "uint256", "bytes4", "bytes32", "bytes32", "bytes32", "bytes32")
CALLS = Array(CALL, MAX_CALLS)
REQUEST = ("uint8", "address", "uint256", "bytes4", "bytes", "bytes32", "bytes32", "bytes32",
    "uint64", "uint64", "bytes32", "string", "bytes32")
IDENTITY = ("uint8", "bytes32", "bytes32", "bytes32", "bytes32", "uint256", "uint64", "uint64", "bytes32", "bytes32")
SCHEDULE_BATCH = ("uint8", CALLS, "bytes32", "bytes32", "bytes32", "uint64", "uint64", "bytes32", "string", "bytes32")
SCHEDULE_ACTION = (REQUEST,)
EXECUTE_BATCH = ("bytes32", CALLS, Array("bytes", MAX_CALLS))
EXECUTE_ACTION = ("bytes32", "bytes")
TYPES = {"schedule_batch": SCHEDULE_BATCH, "schedule_action": SCHEDULE_ACTION,
    "execute_batch": EXECUTE_BATCH, "execute_action": EXECUTE_ACTION}
SIGNATURES = {
    "schedule_batch": "scheduleGovernanceBatch(uint8,(address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32)[],bytes32,bytes32,bytes32,uint64,uint64,bytes32,string,bytes32)",
    "schedule_action": "scheduleGovernanceAction((uint8,address,uint256,bytes4,bytes,bytes32,bytes32,bytes32,uint64,uint64,bytes32,string,bytes32))",
    "execute_batch": "executeGovernanceBatch(bytes32,(address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32)[],bytes[])",
    "execute_action": "executeGovernanceAction(bytes32,bytes)"}
SELECTORS = {"schedule_batch": "0x9c954144", "schedule_action": "0xd1699cf2",
    "execute_batch": "0x2eccc33e", "execute_action": "0xed8259ec"}
CALLS_DOMAIN = "0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70"
ACTION_DOMAIN = "0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b"
TRANSITION_DOMAINS = (
    "0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c",
    "0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7",
    "0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b")
CALL_FIELDS = ("target", "value", "selector", "callDataHash", "scopeHash", "oldValueHash", "newValueHash")
TRANSACTION_FIELDS = ("to", "from", "value", "input")


class _UnsupportedCanonicalInput(MuseumError):
    """The original calldata is outside this consumer's strict ABI subset."""


def _bytes(raw, maximum, label):
    require(type(raw) in (bytes, str), label + " bytes")
    if type(raw) is str:
        require(len(raw) <= 2 + maximum * 2, label + " bound")
        raw = hex_bytes(raw)
    require(len(raw) <= maximum, label + " bound")
    return raw


def _calls(calls):
    values = finality.from_json(CALLS, calls)
    require(0 < len(values) <= MAX_CALLS, "governance complete call count")
    require(all(row[0] != ZERO_ADDRESS for row in values), "governance zero call target")
    require(sum(row[1] for row in values) < 1 << 256, "governance total value overflow")
    return values


def calls_hash_preimage(calls): return encode(("bytes32", CALLS), (CALLS_DOMAIN, _calls(calls)))
def calls_hash(calls): return keccak256(calls_hash_preimage(calls))


def transition_hashes(calls):
    calls = _calls(calls); digest = calls_hash(calls)
    return tuple(keccak256(encode(("bytes32", "bytes32", Array("bytes32", MAX_CALLS)),
        (domain, digest, tuple(row[index] for row in calls))))
        for index, domain in zip((4, 5, 6), TRANSITION_DOMAINS))


def action_id_preimage(chain_id, executor, identity):
    chain = uint(chain_id) if type(chain_id) is str else finality.from_json("uint256", chain_id)
    require(chain > 0 and any(hex_bytes(executor, 20)), "governance action domain identity")
    identity = finality.from_json(IDENTITY, identity)
    require(identity[0] <= 5, "governance retired/unknown action class")
    # Native bytes.concat(abi.encode(domain,chain,host), abi.encode(identity)).
    return encode(("bytes32", "uint256", "address"), (ACTION_DOMAIN, chain, executor)) + encode((IDENTITY,), (identity,))


def action_id(chain_id, executor, identity): return keccak256(action_id_preimage(chain_id, executor, identity))


def _decode(raw, names):
    raw = _bytes(raw, MAX_TRANSACTION_BYTES, "governance original transaction input")
    name = next((name for name in names if raw[:4] == hex_bytes(SELECTORS[name], 4)), None)
    if name is None: return None
    try:
        values = decode(TYPES[name], raw[4:], maximum=MAX_TRANSACTION_BYTES)
    except MuseumError as exc:
        raise _UnsupportedCanonicalInput("governance unsupported noncanonical input") from exc
    return name, values


def decode_schedule(raw):
    """Decode exact outer schedule ABI; unknown selectors return None."""
    decoded = _decode(raw, ("schedule_batch", "schedule_action"))
    if decoded is None: return None
    name, values = decoded
    if name == "schedule_batch":
        calls = _calls(values[1]); own = transition_hashes(calls)
        require(values[2:5] == own, "governance supplied batch aggregate transitions differ")
        ctx = (values[0], *values[2:]); call_datas = None
    else:
        request = values[0]
        calls = _calls(((request[1], request[2], request[3], keccak256(request[4]), *request[5:8]),))
        ctx = (request[0], *transition_hashes(calls), *request[8:])
        call_datas = (request[4],)
    require(ctx[0] <= 5 and ctx[4] < ctx[5], "governance schedule class/window")
    return {"kind": name, "calls": calls, "context": ctx, "callDatas": call_datas}


def decode_execution(raw):
    """Single execution deliberately contains no inferred per-call transitions."""
    decoded = _decode(raw, ("execute_batch", "execute_action"))
    if decoded is None: return None
    name, values = decoded
    return {"kind": name, "actionId": values[0], "calls": _calls(values[1]) if name == "execute_batch" else None,
        "callDatas": values[2] if name == "execute_batch" else (values[1],)}


def _transaction(value, executor, side):
    if value is None: return None, side + "_transaction_unavailable"
    require(type(value) is dict and set(value) == set(TRANSACTION_FIELDS), "governance transaction observation shape")
    require(value["to"] is None or bool(any(hex_bytes(value["to"], 20))), "governance transaction recipient")
    require(any(hex_bytes(value["from"], 20)), "governance transaction sender")
    require(type(value["input"]) is str, "governance transaction input must be canonical hex")
    uint(value["value"])
    raw = _bytes(value["input"], MAX_TRANSACTION_BYTES, "governance original transaction input")
    if value["to"] != executor: return None, side + "_outer_recipient_not_executor"
    try:
        decoded = decode_schedule(raw) if side == "schedule" else decode_execution(raw)
    except _UnsupportedCanonicalInput:
        return None, side + "_unsupported_noncanonical_input"
    if decoded is None: return None, side + "_outer_selector_unsupported"
    return decoded, None


def _data(call_datas):
    require(type(call_datas) in (list, tuple) and 0 < len(call_datas) <= MAX_CALLS,
        "governance saved calldata count")
    raw = tuple(_bytes(item, MAX_CALL_BYTES, "governance governed calldata") for item in call_datas)
    require(len(encode((Array("bytes", MAX_CALLS),), (raw,))) + 1 <= MAX_CARRIER_BYTES, "governance published carrier bound")
    return raw


def _selector_value(selector, value, data, action_class):
    if not data:
        require(selector == "0x00000000" and value > 0 and action_class != 0,
            "governance empty native transfer semantics")
    else:
        require(len(data) >= 4 and data[:4] == hex_bytes(selector, 4), "governance original call selector differs")


def _pair(calls, call_datas, action_class):
    raw = _data(call_datas)
    require(len(calls) == len(raw), "governance call/calldata count differs")
    for call, data in zip(calls, raw):
        require(keccak256(data) == call[3], "governance original calldata hash differs")
        _selector_value(call[2], call[1], data, action_class)
    return raw


def _event_nonce(action, expected_action_id, executor, scheduled_event, executed_event):
    nonce = decode(finality.GOVERNANCE_SCHEDULED_DATA,
        _bytes(scheduled_event["data"], MAX_TRANSACTION_BYTES, "governance scheduled event"), maximum=MAX_TRANSACTION_BYTES)[9]
    topics = (expected_action_id, finality._topic("uint8", action[1]), finality._topic("address", action[2]))
    scheduled = (1, *action[3:11], nonce, action[11], action[15], action[16], action[17])
    executed = (1, *action[3:9], action[12], action[17])
    require(finality.event_matches((executor, (finality.EVENTS["governanceScheduled"], *topics),
        "0x" + encode(finality.GOVERNANCE_SCHEDULED_DATA, scheduled).hex()), scheduled_event), "governance original scheduling event differs")
    require(finality.event_matches((executor, (finality.EVENTS["governanceExecuted"], *topics),
        "0x" + encode(finality.GOVERNANCE_EXECUTED_DATA, executed).hex()), executed_event), "governance original execution event differs")
    return nonce


def verify_action(transactions, *, chain_id, executor, action, expected_action_id, scheduled_event, executed_event, call_datas):
    """Reconstruct any available complete call list; never promote partial inputs."""
    require(type(transactions) is dict and set(transactions) == {"schedule", "execution"}, "governance transaction pair shape")
    chain = uint(chain_id) if type(chain_id) is str else finality.from_json("uint256", chain_id)
    require(chain > 0, "governance action domain identity")
    action = finality.from_json(finality.GOVERNANCE_ACTION, action)
    require(action[0] == 3 and action[1] <= 5 and action[13:15] == (ZERO_ADDRESS, ZERO_ADDRESS), "governance executed stored status/class")
    require(any(hex_bytes(expected_action_id, 32)) and any(hex_bytes(executor, 20)), "governance original identities")
    nonce = _event_nonce(action, expected_action_id, executor, scheduled_event, executed_event)
    schedule, schedule_gap = _transaction(transactions["schedule"], executor, "schedule")
    execution, execution_gap = _transaction(transactions["execution"], executor, "execution")
    raw = _data(call_datas)
    for observed in (schedule, execution):
        if observed is not None and observed["callDatas"] is not None:
            require(tuple(observed["callDatas"]) == raw, "governance original transaction/saved calldata differs")
    if schedule is not None:
        require(transactions["schedule"]["from"] == action[11] and uint(transactions["schedule"]["value"]) == 0,
            "governance original schedule caller/value differs")
        require(schedule["context"] == (action[1], *action[6:11], *action[15:]), "governance schedule/stored original fields differ")
    if execution is not None:
        require(transactions["execution"]["from"] == action[12] and uint(transactions["execution"]["value"]) == action[3]
            and execution["actionId"] == expected_action_id, "governance original execution caller/value/id differs")
    calls = schedule["calls"] if schedule is not None else execution["calls"] if execution is not None else None
    claims = {"fullGovernanceCallMetadataReconstructed": calls is not None, "actionIdPreimageReconstructed": calls is not None,
        "originalSchedulingTransactionDecoded": schedule is not None, "originalExecutionTransactionDecoded": execution is not None,
        "bothOriginalTransactionInputsDecoded": schedule is not None and execution is not None,
        "transactionHashesRecomputed": False, "transactionSenderSignatureVerified": False,
        "historicalRoleAuthorizationReexecuted": False, "historicalPolicyReexecuted": False,
        "historicalEvmExecutionReexecuted": False, "completeAuthority": False, "actualChainAcceptance": False}
    report = {"status": "reconstructed" if schedule is not None and execution is not None else "partial",
        "reasons": [gap for gap in (schedule_gap, execution_gap) if gap],
        "scheduleKind": None if schedule is None else schedule["kind"], "executionKind": None if execution is None else execution["kind"],
        "originalNonce": str(nonce), "calls": None, "callDatas": None, "callsHash": None, "callsHashPreimage": None,
        "aggregateTransitions": None, "actionId": expected_action_id, "actionIdPreimage": None,
        "callDataKey": None, "claims": claims}
    if calls is None:
        if execution is not None:
            # The original data is available even though private first-call
            # transition fields cannot be recovered from this single wrapper.
            require(len(raw) == 1, "governance single execution saved calldata count")
            _selector_value(action[4], action[3], raw[0], action[1])
            report["reasons"].append("single_execution_first_call_transitions_unavailable")
        return report
    if execution is not None:
        require((execution["calls"] is None and len(calls) == 1) or execution["calls"] == calls,
            "governance schedule/execution ordered calls differ")
    raw = _pair(calls, raw, action[1])
    digest, aggregates = calls_hash(calls), transition_hashes(calls)
    total = sum(row[1] for row in calls)
    require(action[2:9] == (calls[0][0], total, calls[0][2], digest, *aggregates), "governance full calls/stored aggregates differ")
    identity = (action[1], digest, *aggregates, nonce, action[9], action[10], action[15], action[17])
    preimage = action_id_preimage(chain_id, executor, identity)
    require(keccak256(preimage) == expected_action_id, "governance original action ID preimage differs")
    report.update(calls=[{key: json_values(value) for key, value in zip(CALL_FIELDS, row)} for row in calls],
        callDatas=["0x" + value.hex() for value in raw], callsHash=digest, callsHashPreimage="0x" + calls_hash_preimage(calls).hex(),
        aggregateTransitions=dict(zip(("scopeHash", "oldValueHash", "newValueHash"), aggregates)),
        actionIdPreimage="0x" + preimage.hex(), callDataKey=keccak256(b"".join(hex_bytes(row[3], 32) for row in calls)))
    return report


def verify(bundle, context, graph, transactions, events):
    """Upgrade only original transaction preimages, retaining every frozen limit."""
    derived = finality.validate_bundle(bundle, context, graph)
    finality.validate_event_join(bundle, context, graph, events)
    def log(name):
        found = [row["log"] for row in events if row["log"]["address"] == graph["executor"]["address"]
            and row["log"]["topics"][0] == finality.EVENTS[name]]
        require(len(found) == 1, "governance exact original event required")
        return found[0]
    report = verify_action(transactions, chain_id=context["chainId"], executor=graph["executor"]["address"],
        action=bundle["execution"]["action"], expected_action_id=bundle["finality"]["executionWitness"][0],
        scheduled_event=log("governanceScheduled"), executed_event=log("governanceExecuted"), call_datas=bundle["execution"]["callDatas"])
    report["finalityCall"] = None
    if report["calls"] is not None:
        index = int(derived["execution"]["matchedCallIndex"]); call = report["calls"][index]
        expected = derived["executionContext"]
        require(call["target"] == graph["finality"]["address"] and call["value"] == "0"
            and call["selector"] == bundle["execution"]["callDatas"][index][:10]
            and all(call[key] == expected[key] for key in ("scopeHash", "oldValueHash", "newValueHash")),
            "governance original finality call target/value/transition differs")
        report["finalityCall"] = {"index": str(index), **call}
    return report
