"""Filtered block-zero public history with explicit provider completeness trust.

Only matching receipts and their canonical block mappings are read. Neither a
genesis header walk nor a cryptographic ancestry/receipt proof is claimed.
"""
from .canonical import MuseumError, dumps, hex_bytes, keccak256, uint
from .chain_history import LOG_FIELDS, MAX_LOGS_PER_RECEIPT, MAX_TRANSACTIONS_PER_BLOCK
from .chain_rpc import quantity
from .independent_wire import require
from .public_history_rpc import PublicLimitError

PROFILE = "STREAM_MUSEUM_PUBLIC_CHAIN_HISTORY_V1"
WINDOW_BLOCKS = 50000
SATURATION_LOGS = 1000
MAX_QUERIES = 16384
MAX_FILTERS = 32
MAX_LOGS = 8192
MAX_RECEIPTS = 4096
MAX_TOUCHED_BLOCKS = 4096
PROFILE_BYTES = dumps({"id": PROFILE, "version": "1", "range": "inclusive block0 through external source anchor",
    "windowBlocks": str(WINDOW_BLOCKS), "saturationLogs": str(SATURATION_LOGS),
    "bounds": {"queries": str(MAX_QUERIES), "filters": str(MAX_FILTERS), "matchingLogs": str(MAX_LOGS),
        "receipts": str(MAX_RECEIPTS), "touchedBlocks": str(MAX_TOUCHED_BLOCKS)},
    "splitting": "Ascending fixed windows; on explicit sanitized range/size limit or saturation, visit lower binary half then upper. Every filter's disclosed hits must survive its own completed children; overlapping filters cannot rescue an omission. A saturated or limited single block fails.",
    "filters": "Exact source-derived address and positional topics; no caller-selected lower bound.",
    "correspondence": "Every hit equals a log in its complete successful receipt; all matching logs in retained receipts equal the union of query hits. Header hash/number mappings and transaction slots agree.",
    "retainedHeaders": "Timestamps never decrease over sorted touched heights. Adjacent touched heights have exact parentHash linkage. No missing intervening header or full ancestry proof is inferred.",
    "claims": {"providerLogCompletenessTrusted": True, "canonicalMappingTrusted": True,
        "genesisWalk": False, "allBlockReceipts": False, "ancestryProven": False,
        "receiptTrieProven": False, "consensusVerified": False}})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _filters(filters):
    require(type(filters) is list and 0 < len(filters) <= MAX_FILTERS, "public history filter bound")
    seen = set()
    for f in filters:
        require(type(f) is dict and set(f) == {"address", "topics"}, "public history filter shape")
        require(any(hex_bytes(f["address"], 20)), "public history filter address")
        require(type(f["topics"]) is list and len(f["topics"]) <= 4, "public history filter topics")
        for term in f["topics"]:
            if term is None: continue
            if type(term) is list:
                require(0 < len(term) <= 64 and len(set(term)) == len(term), "public history topic OR bound")
                for topic in term: hex_bytes(topic, 32)
            else: hex_bytes(term, 32)
        key = dumps(f)
        require(key not in seen, "public history duplicate filter"); seen.add(key)


def _matches(log, f):
    if log["address"] != f["address"] or len(log["topics"]) < len(f["topics"]): return False
    for i, term in enumerate(f["topics"]):
        if term is None: continue
        if type(term) is list:
            if log["topics"][i] not in term: return False
        elif log["topics"][i] != term: return False
    return True


def _log(value):
    require(type(value) is dict and value.get("removed") is False and all(k in value for k in LOG_FIELDS),
        "public history removed/malformed log")
    for key in ("blockHash", "transactionHash"): require(any(hex_bytes(value[key], 32)), "public history log hash")
    for key in ("blockNumber", "transactionIndex", "logIndex"): quantity(value[key])
    hex_bytes(value["address"], 20)
    require(len(hex_bytes(value["data"])) <= 1048576 and type(value["topics"]) is list and len(value["topics"]) <= 4,
        "public history log data/topics bound")
    for topic in value["topics"]: hex_bytes(topic, 32)
    return {key: value[key] for key in LOG_FIELDS}


def _key(log): return (log["blockHash"], log["transactionHash"], log["logIndex"])
def _position(log): return tuple(quantity(log[k]) for k in ("blockNumber", "transactionIndex", "logIndex"))


def scan_public_history(reader, anchor, *, filters):
    try:
        return _scan(reader, anchor, filters)
    except (KeyError, TypeError, IndexError, OverflowError) as exc:
        raise MuseumError("malformed public history evidence") from exc


def _scan(reader, anchor, filters):
    _filters(filters)
    end = uint(anchor["blockNumber"])
    require((end // WINDOW_BLOCKS + 1) * len(filters) <= MAX_QUERIES, "public history initial query bound")
    require(reader.block == {"blockHash": anchor["blockHash"], "requireCanonical": True}, "public history reader anchor")
    require(quantity(reader.request("eth_chainId", [])) == uint(anchor["chainId"]), "public history chain differs")
    blocks, number_hashes, transaction_blocks = {}, {}, {}

    def block_at(digest, number):
        if digest in blocks:
            require(quantity(blocks[digest]["number"]) == number, "public history block number differs")
            return blocks[digest]
        require(len(blocks) < MAX_TOUCHED_BLOCKS, "public history touched block bound")
        by_hash = reader.request("eth_getBlockByHash", [digest, False])
        by_number = reader.request("eth_getBlockByNumber", [hex(number), False])
        require(type(by_hash) is dict and by_hash == by_number and by_hash.get("hash") == digest
            and quantity(by_hash["number"]) == number and number <= end, "public history canonical header differs")
        require(any(hex_bytes(digest, 32)) and any(hex_bytes(by_hash["stateRoot"], 32)), "public history header commitment")
        parent = hex_bytes(by_hash["parentHash"], 32)
        require(bool(any(parent)) == (number != 0), "public history header parent")
        stamp = quantity(by_hash["timestamp"])
        require(stamp < 1 << 64 and stamp <= uint(anchor["timestamp"], 64), "public history header time")
        txs = by_hash["transactions"]
        require(type(txs) is list and len(txs) <= MAX_TRANSACTIONS_PER_BLOCK and len(set(txs)) == len(txs),
            "public history header transaction bound/duplicate")
        for tx in txs:
            require(any(hex_bytes(tx, 32)) and (tx not in transaction_blocks or transaction_blocks[tx] == digest),
                "public history transaction in multiple blocks")
            transaction_blocks[tx] = digest
        require(number not in number_hashes or number_hashes[number] == digest, "public history conflicting block at height")
        number_hashes[number], blocks[digest] = digest, by_hash
        return by_hash

    source = block_at(anchor["blockHash"], end)
    require(source["stateRoot"] == anchor["stateRoot"] and quantity(source["timestamp"]) == uint(anchor["timestamp"], 64),
        "public history source anchor differs")
    hits, disclosed, queries, pages, split_count = {}, {}, 0, 0, 0
    query_ranges = []
    for filter_index, f in enumerate(filters):
        filter_disclosed, filter_completed = set(), set()
        for start in range(0, end + 1, WINDOW_BLOCKS):
            stack = [(start, min(end, start + WINDOW_BLOCKS - 1))]
            while stack:
                lower, upper = stack.pop()
                require(queries < MAX_QUERIES, "public history query bound")
                queries += 1
                params = [{**f, "fromBlock": hex(lower), "toBlock": hex(upper)}]
                limited, rows = False, []
                try: rows = reader.request("eth_getLogs", params)
                except PublicLimitError: limited = True
                if not limited: require(type(rows) is list, "public history query result must be list")
                saturated = not limited and len(rows) >= SATURATION_LOGS
                query_ranges.append({"filter": str(filter_index), "fromBlock": str(lower), "toBlock": str(upper),
                    "outcome": "limit" if limited else "saturated" if saturated else "complete_response"})
                # Validate even discarded saturation responses; foreign or malformed hits are not a split signal.
                normalized = []
                for raw in rows:
                    row = _log(raw)
                    require(lower <= quantity(row["blockNumber"]) <= upper and _matches(row, f), "public history hit outside query filter/range")
                    key = _key(row)
                    require(key not in disclosed or disclosed[key] == row, "public history conflicting disclosed hit")
                    disclosed[key] = row
                    filter_disclosed.add(key)
                    require(len(disclosed) <= MAX_LOGS, "public history disclosed log bound")
                    normalized.append(row)
                if limited or saturated:
                    require(lower < upper, "public history single block query saturated/limited")
                    split_count += 1
                    middle = (lower + upper) // 2
                    stack.extend(((middle + 1, upper), (lower, middle)))
                    continue
                pages += 1
                for row in normalized:
                    key = _key(row)
                    require(key not in hits or hits[key] == row, "public history conflicting duplicate hit")
                    hits[key] = row
                    filter_completed.add(key)
                    require(len(hits) <= MAX_LOGS, "public history matching log bound")
        require(filter_disclosed == filter_completed, "public history filter split response omitted disclosed hit")
    require(disclosed == hits, "public history split response omitted disclosed hit")
    receipts, receipt_matches, block_log_positions = {}, {}, {}
    for hit in sorted(hits.values(), key=_position):
        tx = hit["transactionHash"]
        if tx in receipts: continue
        require(len(receipts) < MAX_RECEIPTS, "public history receipt bound")
        receipt = reader.request("eth_getTransactionReceipt", [tx])
        require(type(receipt) is dict and receipt.get("transactionHash") == tx and receipt.get("status") == "0x1",
            "public history successful receipt required")
        require(all(receipt.get(k) == hit[k] for k in ("blockHash", "blockNumber", "transactionIndex")),
            "public history receipt/hit coordinates differ")
        block = block_at(receipt["blockHash"], quantity(receipt["blockNumber"]))
        index = quantity(receipt["transactionIndex"])
        require(index < len(block["transactions"]) and block["transactions"][index] == tx, "public history receipt transaction slot differs")
        raw_logs = receipt["logs"]
        require(type(raw_logs) is list and 0 < len(raw_logs) <= MAX_LOGS_PER_RECEIPT, "public history receipt log bound")
        previous = None
        for raw in raw_logs:
            row = _log(raw)
            require(all(row[k] == receipt[k] for k in ("blockHash", "blockNumber", "transactionHash", "transactionIndex")),
                "public history receipt log coordinates differ")
            position = quantity(row["logIndex"])
            require(previous is None or position == previous + 1, "public history receipt log order/gap")
            previous = position
            key = (row["blockHash"], position)
            require(key not in block_log_positions, "public history duplicate block log position")
            block_log_positions[key] = index
            if any(_matches(row, f) for f in filters): receipt_matches[_key(row)] = row
        receipts[tx] = receipt
    require(receipt_matches == hits, "public history query/receipt matching logs differ")
    for digest in blocks:
        positions = [index for (block_hash, _), index in sorted(block_log_positions.items(), key=lambda kv: kv[0][1]) if block_hash == digest]
        require(positions == sorted(positions), "public history transaction/log order differs")
    previous_header = None
    for number in sorted(number_hashes):
        header = blocks[number_hashes[number]]
        if previous_header is not None:
            require(quantity(previous_header["timestamp"]) <= quantity(header["timestamp"]),
                "public history touched header time regresses")
            if quantity(previous_header["number"]) + 1 == number:
                require(header["parentHash"] == previous_header["hash"], "public history adjacent header parent differs")
        previous_header = header
    require(reader.request("eth_getBlockByHash", [anchor["blockHash"], False]) == source
        and reader.request("eth_getBlockByNumber", [hex(end), False]) == source, "public history final source changed")
    coverage = {"profile": PROFILE, "profileHash": PROFILE_HASH, "startBlock": "0", "endBlock": str(end),
        "filters": filters, "queries": str(queries), "pages": str(pages), "splits": str(split_count),
        "logs": str(len(hits)), "touchedBlocks": str(len(blocks)), "receipts": str(len(receipts)),
        "queryRanges": query_ranges, "providerLogCompletenessTrusted": True, "canonicalMappingTrusted": True,
        "genesisWalk": False, "allBlockReceipts": False, "ancestryProven": False, "receiptTrieProven": False,
        "qualification": "Full numeric query range; complete responses are trusted provider claims. Only returned-hit receipts are inspected; silently omitted transactions remain unproven."}
    return {"logs": sorted(hits.values(), key=_position),
        "blockTimestamps": {str(quantity(b["number"])): str(quantity(b["timestamp"])) for b in blocks.values()}, "coverage": coverage}
