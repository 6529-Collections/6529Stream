"""Bounded complete RPC receipt walk from genesis to an external block anchor.

The server supplies headers and receipts; this is deliberately not a header,
receipt-trie, consensus, or chain-selection proof. No transaction hint list or
log-filter response supplies the completeness denominator.
"""
from .canonical import MuseumError, hex_bytes, uint
from .chain_rpc import quantity
from .independent_wire import require

MAX_BLOCKS = 4096
MAX_TRANSACTIONS_PER_BLOCK = 8192
MAX_LOGS_PER_RECEIPT = 4096
LOG_FIELDS = ("address", "blockHash", "blockNumber", "data", "logIndex",
              "topics", "transactionHash", "transactionIndex")


def scan_history(reader, anchor, *, maximum_blocks=MAX_BLOCKS):
    """Record every header and receipt, returning canonical ascending logs.

    Uses the caller's RecordingReader, without finishing its transcript. The
    bound is a refusal boundary, never a truncated history or an absent result.
    """
    try:
        return _scan_history(reader, anchor, maximum_blocks)
    except (KeyError, TypeError, IndexError, OverflowError) as exc:
        raise MuseumError("malformed complete history header/receipt/log") from exc


def _scan_history(reader, anchor, maximum_blocks):
    number = uint(anchor["blockNumber"])
    require(type(maximum_blocks) is int and 0 < maximum_blocks <= MAX_BLOCKS
            and number < maximum_blocks, "complete history block bound exceeded")
    require(quantity(reader.request("eth_chainId", [])) == uint(anchor["chainId"]),
            "complete history chain differs")
    expected = anchor["blockHash"]
    require(any(hex_bytes(expected, 32)), "complete history anchor hash")
    blocks, seen_transactions, newer_stamp = {}, set(), None
    for height in range(number, -1, -1):
        block = reader.request("eth_getBlockByHash", [expected, False])
        require(isinstance(block, dict) and block.get("hash") == expected
                and quantity(block["number"]) == height, "complete history ancestry differs")
        stamp = quantity(block["timestamp"])
        require(stamp < 1 << 64 and (newer_stamp is None or stamp <= newer_stamp),
                "complete history timestamp order")
        require(any(hex_bytes(block["stateRoot"], 32)), "complete history state root")
        parent = hex_bytes(block["parentHash"], 32)
        require((not any(parent)) if height == 0 else any(parent),
                "complete history genesis/parent differs")
        if height == number:
            require(block["stateRoot"] == anchor["stateRoot"]
                    and stamp == uint(anchor["timestamp"], 64), "complete history source anchor differs")
        txs = block["transactions"]
        require(isinstance(txs, list) and len(txs) <= MAX_TRANSACTIONS_PER_BLOCK,
                "complete history transaction bound")
        for tx in txs:
            require(any(hex_bytes(tx, 32)) and tx not in seen_transactions,
                    "complete history duplicate/invalid transaction")
            seen_transactions.add(tx)
        blocks[height] = block
        expected, newer_stamp = block["parentHash"], stamp
    logs = []
    for height in range(number + 1):
        block, next_log = blocks[height], 0
        for position, tx in enumerate(block["transactions"]):
            receipt = reader.request("eth_getTransactionReceipt", [tx])
            require(isinstance(receipt, dict) and receipt.get("transactionHash") == tx
                    and receipt.get("blockHash") == block["hash"]
                    and quantity(receipt["blockNumber"]) == height
                    and quantity(receipt["transactionIndex"]) == position,
                    "complete history receipt transaction/block differs")
            require(receipt.get("status") in ("0x0", "0x1"), "complete history receipt status")
            raw_logs = receipt["logs"]
            require(isinstance(raw_logs, list) and len(raw_logs) <= MAX_LOGS_PER_RECEIPT
                    and (receipt["status"] == "0x1" or not raw_logs),
                    "complete history reverted receipt/log bound")
            for log in raw_logs:
                require(isinstance(log, dict) and log.get("removed") is False,
                        "complete history removed/malformed log")
                require(all(log.get(k) == receipt[k] for k in
                        ("blockHash", "blockNumber", "transactionHash", "transactionIndex")),
                        "complete history log coordinates differ")
                require(quantity(log["logIndex"]) == next_log,
                        "complete history missing/duplicate/unordered log index")
                next_log += 1
                hex_bytes(log["address"], 20)
                data = hex_bytes(log["data"])
                require(len(data) <= 1048576 and isinstance(log["topics"], list)
                        and len(log["topics"]) <= 4, "complete history log data/topics bound")
                for topic in log["topics"]:
                    hex_bytes(topic, 32)
                logs.append({k: log[k] for k in LOG_FIELDS})
    require(reader.request("eth_getBlockByHash", [anchor["blockHash"], False]) == blocks[number],
            "complete history source changed during capture")
    return {"logs": logs, "blockCount": str(number + 1), "transactionCount": str(len(seen_transactions)),
            "startBlock": "0", "endBlock": str(number),
            "blockTimestamps": {str(n): str(quantity(b["timestamp"])) for n, b in blocks.items()}}
