"""Offline observation reconciliation after independent capture verification.

This utility does not verify a capture manifest, select native records or
authenticate provenance. Callers must first verify all three original packages.
"""
from bisect import bisect_left, bisect_right

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .chain_history import MAX_LOGS_PER_RECEIPT, MAX_TRANSACTIONS_PER_BLOCK
from .independent_wire import require
from . import public_chain_history as history
from . import public_history_rpc as rpc

PROFILE = "STREAM_MUSEUM_CONSERVATION_CAPTURE_JOIN_V1"
NAMES = ("tier", "selection", "floor")
SOURCE_PROFILES = {"tier": "STREAM_MUSEUM_PUBLIC_CONSERVATION_TIER_SOURCE_V1",
    "selection": "STREAM_MUSEUM_PUBLIC_CONSERVATION_SOURCE_V1",
    "floor": "STREAM_MUSEUM_PUBLIC_CONSERVATION_FLOOR_SOURCE_V1"}
COMMON = ("chainId", "core", "collectionId", "blockHash", "blockNumber", "timestamp",
    "stateRoot", "environment", "deploymentEvidenceHash")
MAX_INPUT_BYTES, MAX_ANCHOR_BYTES = 64 * 1024 * 1024, 524288
MAX_ROWS, MAX_QUERIES = 100000, 16384
MAX_HEADERS, MAX_RECEIPTS = 4096, 4096
MAX_LOGS, MAX_TRANSACTIONS, MAX_MATCH_CHECKS = 65536, 65536, 4194304
CLAIMS = {"capturesAlreadyVerifiedRequired": True, "commonAnchorChecked": True,
    "sharedRuntimePinsChecked": True, "sharedRpcOutcomesChecked": True,
    "retainedHeaderReceiptLogUnionChecked": True, "retainedMatchingLogOmissionsChecked": True,
    "providerLogCompletenessTrusted": True, "canonicalMappingTrusted": True,
    "sourceProvenanceAuthenticated": False, "unobservedLogCompletenessProven": False,
    "ancestryProven": False, "receiptTrieProven": False, "consensusVerified": False,
    "actualChainAcceptance": False, "nativeSemanticsReverified": False}
QUALIFICATION = ("Reconciles supplied observations from three independently verified captures. "
    "Exact shared queries, runtime pins, touched canonical headers and complete successful receipts must agree. "
    "Every completed log page must include all matching logs in any retained receipt within its range. "
    "Saturated disclosures must agree with retained receipts and their own completed binary children. "
    "No missing headers, silently omitted transactions, native semantics, provenance or consensus are proved.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "inputs": list(NAMES),
    "sourceProfiles": SOURCE_PROFILES, "historyProfileHash": history.PROFILE_HASH,
    "rpcProfileHash": rpc.PROFILE_HASH, "commonAnchorFields": list(COMMON),
    "bounds": {"inputBytes": str(MAX_INPUT_BYTES), "anchorBytes": str(MAX_ANCHOR_BYTES),
        "rowOccurrences": str(MAX_ROWS), "uniqueQueries": str(MAX_QUERIES),
        "headers": str(MAX_HEADERS), "receipts": str(MAX_RECEIPTS),
        "receiptLogs": str(MAX_LOGS), "transactionPlacements": str(MAX_TRANSACTIONS),
        "queryCandidateLogChecks": str(MAX_MATCH_CHECKS)},
    "headers": "Exact reciprocal hash/height mappings, nondecreasing touched timestamps, exact adjacent parents and unique transaction slots; no missing ancestry inferred.",
    "receipts": "Exact repeated receipts, successful status, header transaction slot and every log coordinate; global positions and adjacent retained transaction log continuity agree.",
    "queries": "Each query keeps its numeric range and positional filter, with unique log identities in every response. Complete responses equal matching retained receipt logs; saturated/limited parents have exact lower/upper child queries in the same input, recursively through complete pages. Limits are exact outcomes, never empty responses.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _nonzero(value, length):
    require(any(hex_bytes(value, length)), "conservation join empty commitment/address")


def _inputs(inputs):
    require(type(inputs) is dict and set(inputs) == set(NAMES), "conservation join exact inputs required")
    total = 0
    for value in inputs.values():
        require(type(value) is dict and set(value) == {"anchor", "transcript"}, "conservation join input shape")
        for raw in value.values():
            require(type(raw) is bytes and raw, "conservation join original bytes required")
            total += len(raw)
    require(total <= MAX_INPUT_BYTES, "conservation join aggregate input byte bound")
    calls, hashes, pins = {}, {}, {}
    row_count = 0; common = None
    for name in NAMES:
        value = inputs[name]
        a = loads(value["anchor"], maximum=MAX_ANCHOR_BYTES, canonical=True)
        require(type(a) is dict and all(k in a for k in COMMON) and a.get("profile") == SOURCE_PROFILES[name],
            "conservation join source anchor shape/profile")
        current = {k: a[k] for k in COMMON}
        require(common is None or current == common, "conservation join common anchor differs")
        common = current
        require(uint(a["chainId"]) > 0 and uint(a["collectionId"]) > 0, "conservation join nonzero identity")
        uint(a["blockNumber"]); uint(a["timestamp"], 64)
        _nonzero(a["core"], 20)
        for key in ("blockHash", "stateRoot", "deploymentEvidenceHash"): _nonzero(a[key], 32)
        require(a["environment"] in ("public_chain", "local_evm_fixture"), "conservation join environment")
        if name == "tier":
            own_pins = {a["core"]: a["coreRuntimeHash"]}
        else:
            require(type(a["codePins"]) is list and 0 < len(a["codePins"]) <= 256, "conservation join pin bound")
            own_pins = {}
            for row in a["codePins"]:
                require(type(row) is dict and set(row) == {"address", "runtimeHash"}
                    and row["address"] not in own_pins, "conservation join duplicate/malformed pin")
                own_pins[row["address"]] = row["runtimeHash"]
            require(a["core"] in own_pins, "conservation join missing Core pin")
        for address, digest in own_pins.items():
            _nonzero(address, 20); _nonzero(digest, 32)
            require(address not in pins or pins[address] == digest, "conservation join runtime pin differs")
            pins[address] = digest
        transcript = loads(value["transcript"], maximum=rpc.MAX_TRANSCRIPT, canonical=True)
        require(type(transcript) is dict and set(transcript) == {"version", "profile", "calls"}
            and type(transcript["version"]) is int and transcript["version"] == rpc.VERSION
            and transcript["profile"] == rpc.PROFILE and type(transcript["calls"]) is list,
            "conservation join transcript profile/shape")
        row_count += len(transcript["calls"])
        require(row_count <= MAX_ROWS, "conservation join aggregate row bound")
        calls[name] = transcript["calls"]
        hashes[name] = {"anchorHash": keccak256(value["anchor"]), "transcriptHash": keccak256(value["transcript"])}
    return common, calls, hashes, pins, total, row_count


def reconcile(inputs):
    """Return a small deterministic coverage summary; never perform network reads."""
    try:
        return _reconcile(inputs)
    except (KeyError, TypeError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError("malformed conservation join evidence") from exc


def _reconcile(inputs):
    a, calls, hashes, pins, input_size, row_count = _inputs(inputs)
    counts = _observations(a, calls, pins)
    return {"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1", "sourceState": a,
        "coreRuntimeHash": pins[a["core"]], "inputs": hashes,
        "counts": {"inputBytes": str(input_size), "rowOccurrences": str(row_count), **counts},
        "claims": dict(CLAIMS), "qualification": QUALIFICATION}


def _observations(a, calls, pins):
    """Reconcile already parsed, bounded source observations without projecting anchors."""
    end, stamp = uint(a["blockNumber"]), uint(a["timestamp"], 64)
    outcomes, headers, heights, receipts, queries = {}, {}, {}, {}, {}
    header_observations = set(); input_queries = {}
    for name in calls:
        input_queries[name] = {}
        for row in calls[name]:
            rpc._row(row)
            method, params = row["method"], row["params"]
            outcome = {k: row[k] for k in ("result", "limit") if k in row}
            if "result" in row:
                require(len(dumps(row["result"])) <= rpc.MAX_RESPONSE, "conservation join response byte bound")
            key = dumps([method, params]); encoded = dumps(outcome)
            require(key not in outcomes or outcomes[key] == encoded, "conservation join repeated RPC outcome differs")
            outcomes[key] = encoded
            if method in ("eth_call", "eth_getCode"):
                require(params[1]["blockHash"] == a["blockHash"], "conservation join state-read block differs")
                raw = hex_bytes(row["result"])
                if method == "eth_getCode" and params[0] in pins:
                    require(keccak256(raw) == pins[params[0]], "conservation join observed runtime differs")
            elif method == "eth_chainId":
                require(rpc.quantity(row["result"]) == uint(a["chainId"]), "conservation join chain differs")
            elif method in ("eth_getBlockByHash", "eth_getBlockByNumber"):
                b = row["result"]
                require(type(b) is dict, "conservation join malformed header")
                number, digest = rpc.quantity(b["number"]), b["hash"]
                _nonzero(digest, 32); _nonzero(b["stateRoot"], 32)
                require(number <= end and bool(any(hex_bytes(b["parentHash"], 32))) == (number != 0),
                    "conservation join header height/parent")
                require(rpc.quantity(b["timestamp"]) <= stamp, "conservation join future header timestamp")
                require((method == "eth_getBlockByHash" and params[0] == digest)
                    or (method == "eth_getBlockByNumber" and rpc.quantity(params[0]) == number),
                    "conservation join header request differs")
                require(digest not in headers or dumps(headers[digest]) == dumps(b),
                    "conservation join header hash observation differs")
                require(number not in heights or heights[number] == digest, "conservation join conflicting header height")
                txs = b["transactions"]
                require(type(txs) is list and len(txs) <= MAX_TRANSACTIONS_PER_BLOCK and len(set(txs)) == len(txs),
                    "conservation join header transaction bound/duplicate")
                for tx in txs: _nonzero(tx, 32)
                headers[digest], heights[number] = b, digest
                header_observations.add((method, digest))
                require(len(headers) <= MAX_HEADERS, "conservation join header bound")
            elif method == "eth_getTransactionReceipt":
                r = row["result"]
                require(type(r) is dict and r.get("transactionHash") == params[0] and r.get("status") == "0x1",
                    "conservation join successful original receipt required")
                tx = r["transactionHash"]
                require(tx not in receipts or receipts[tx] == r, "conservation join repeated receipt differs")
                receipts[tx] = r
                require(len(receipts) <= MAX_RECEIPTS, "conservation join receipt bound")
            elif method == "eth_getLogs":
                f = params[0]
                history._filters([{k: f[k] for k in ("address", "topics")}])
                require(rpc.quantity(f["toBlock"]) <= end, "conservation join query outside source range")
                if "result" in row: require(type(row["result"]) is list, "conservation join query result shape")
                queries[key] = row; input_queries[name][key] = row
                require(len(queries) <= MAX_QUERIES, "conservation join query bound")
    require(a["blockHash"] in headers and heights.get(end) == a["blockHash"], "conservation join source header missing")
    source = headers[a["blockHash"]]
    require(source["stateRoot"] == a["stateRoot"] and rpc.quantity(source["timestamp"]) == stamp,
        "conservation join source header differs")
    previous, transactions = None, {}
    for number, digest in sorted(heights.items()):
        b = headers[digest]
        require(all((m, digest) in header_observations for m in ("eth_getBlockByHash", "eth_getBlockByNumber")),
            "conservation join reciprocal header mapping missing")
        if previous is not None:
            require(rpc.quantity(previous["timestamp"]) <= rpc.quantity(b["timestamp"]), "conservation join header time regresses")
            if rpc.quantity(previous["number"]) + 1 == number:
                require(b["parentHash"] == previous["hash"], "conservation join adjacent parent differs")
        for index, tx in enumerate(b["transactions"]):
            require(tx not in transactions, "conservation join transaction appears in multiple blocks")
            transactions[tx] = (digest, index)
            require(len(transactions) <= MAX_TRANSACTIONS, "conservation join transaction placement bound")
        previous = b
    logs, positions, by_block, block_positions = {}, {}, {}, {}
    for tx, r in receipts.items():
        digest, number, index = r["blockHash"], rpc.quantity(r["blockNumber"]), rpc.quantity(r["transactionIndex"])
        require(heights.get(number) == digest and transactions.get(tx) == (digest, index),
            "conservation join receipt/header transaction slot differs")
        raw_logs = r["logs"]
        require(type(raw_logs) is list and len(raw_logs) <= MAX_LOGS_PER_RECEIPT, "conservation join receipt log bound")
        previous_index = None
        for raw in raw_logs:
            log = history._log(raw)
            require(all(log[k] == r[k] for k in ("blockHash", "blockNumber", "transactionHash", "transactionIndex")),
                "conservation join receipt log coordinates differ")
            log_index = rpc.quantity(log["logIndex"])
            require(previous_index is None or log_index == previous_index + 1, "conservation join receipt log order/gap")
            previous_index = log_index
            require((digest, log_index) not in positions, "conservation join duplicate block log position")
            positions[digest, log_index] = index
            block_positions.setdefault(digest, []).append((log_index, index))
            logs[history._key(log)] = log
            require(len(logs) <= MAX_LOGS, "conservation join receipt log union bound")
        by_block.setdefault(digest, []).append((index, raw_logs))
    for digest, block_receipts in by_block.items():
        order = [index for _, index in sorted(block_positions.get(digest, []))]
        require(order == sorted(order), "conservation join global transaction/log order differs")
        prior_tx, next_log = None, None
        for index, raw_logs in sorted(block_receipts):
            if index == 0: next_log = 0
            elif prior_tx is None or prior_tx + 1 != index: next_log = None
            if raw_logs:
                first = rpc.quantity(raw_logs[0]["logIndex"])
                require(next_log is None or first == next_log, "conservation join adjacent receipt log gap")
                next_log = rpc.quantity(raw_logs[-1]["logIndex"]) + 1
            prior_tx = index
    log_index = {}
    for key, log in logs.items():
        log_index.setdefault(log["address"], []).append((rpc.quantity(log["blockNumber"]), key, log))
    for rows in log_index.values(): rows.sort(key=lambda row: (row[0], row[1]))
    log_numbers = {address: [row[0] for row in rows] for address, rows in log_index.items()}
    query_counts = {"complete": 0, "saturated": 0, "limited": 0}; match_checks = 0
    for row in queries.values():
        f = row["params"][0]; lower, upper = rpc.quantity(f["fromBlock"]), rpc.quantity(f["toBlock"])
        if "limit" in row:
            query_counts["limited"] += 1; continue
        returned = {}
        for raw in row["result"]:
            log = history._log(raw); key = history._key(log)
            require(lower <= rpc.quantity(log["blockNumber"]) <= upper and history._matches(log, f),
                "conservation join query hit outside range/filter")
            require(key in logs and logs[key] == log, "conservation join query hit differs from retained receipt")
            require(key not in returned, "conservation join duplicate query hit")
            returned[key] = log
        if len(row["result"]) >= history.SATURATION_LOGS:
            query_counts["saturated"] += 1
        else:
            query_counts["complete"] += 1
            numbers = log_numbers.get(f["address"], [])
            left, right = bisect_left(numbers, lower), bisect_right(numbers, upper)
            match_checks += right - left
            require(match_checks <= MAX_MATCH_CHECKS, "conservation join query comparison bound")
            expected = {key: log for _, key, log in log_index.get(f["address"], [])[left:right]
                if history._matches(log, f)}
            require(returned == expected, "conservation join query omitted matching retained receipt log")
    # Splits must close in the input that disclosed or limited the parent.
    # An overlapping query from another capture cannot rescue a missing child.
    for own in input_queries.values():
        for row in own.values():
            if "limit" not in row and len(row["result"]) < history.SATURATION_LOGS: continue
            f = row["params"][0]; lower, upper = rpc.quantity(f["fromBlock"]), rpc.quantity(f["toBlock"])
            require(lower < upper, "conservation join single-block incomplete query")
            middle = (lower + upper) // 2
            for left, right in ((lower, middle), (middle + 1, upper)):
                child = dumps(["eth_getLogs", [{**f, "fromBlock": hex(left), "toBlock": hex(right)}]])
                require(child in own, "conservation join missing exact split child")
    return {"uniqueRpcOutcomes": str(len(outcomes)),
            "headers": str(len(headers)), "receipts": str(len(receipts)), "receiptLogs": str(len(logs)),
            "transactionPlacements": str(len(transactions)), "queries": str(len(queries)),
            "queryCandidateLogChecks": str(match_checks),
            **{k + "Queries": str(v) for k, v in query_counts.items()}}
