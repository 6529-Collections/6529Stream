"""Original native mint/entropy joins over provider-admitted public log history."""
from .canonical import dumps, hex_bytes, keccak256, loads, uint
from .chain_history import LOG_FIELDS
from .chain_rpc import quantity
from .independent_wire import require
from .mint_entropy_source import (MintEntropySource, PROFILE as ORIGINAL_PROFILE,
    PROFILE_BYTES as ORIGINAL_PROFILE_BYTES, PROFILE_HASH as ORIGINAL_PROFILE_HASH,
    MAX_EVENTS, MAX_OUTPUT, ZERO, REGISTERED, REVERTED, TRANSFER, ENTROPY_REGISTERED,
    REQUESTED, FINALIZED, TERMINAL, SUPERSEDED)
from .public_chain_history import (scan_public_history, _matches, MAX_LOGS, MAX_RECEIPTS,
    MAX_TOUCHED_BLOCKS, PROFILE as HISTORY_PROFILE, PROFILE_HASH as HISTORY_PROFILE_HASH)
from .public_history_rpc import (PublicRecordingReader, PublicReplayTransport, PublicRpcTransport,
    PROFILE as RPC_PROFILE, PROFILE_HASH as RPC_PROFILE_HASH)

PROFILE = "STREAM_MUSEUM_PUBLIC_MINT_ENTROPY_SOURCE_V1"
CLAIMS = {"originalCoordinatorAtMintJoined": True, "nativeEntropyViewsReconciled": True,
    "filteredEventReceiptCorrespondenceChecked": True, "crossStageObservationsReconciled": True,
    "providerLogCompletenessTrusted": True, "canonicalMappingTrusted": True,
    "independentlyVerifiedLogCompleteness": False, "lifetimeAttemptHighWaterProven": False,
    "genesisWalk": False, "allBlockReceipts": False, "ancestryProven": False,
    "cryptographicReceiptProof": False, "cryptographicStateProof": False, "consensusVerified": False,
    "oracleRandomnessVerified": False, "recoveryAuthorityReexecuted": False,
    "rendererEntropyExemption": False, "fullProtocolEventArchive": False, "actualChainAcceptance": False}
QUALIFICATION = (
    "One Core token and its original coordinator at an externally admitted RPC anchor. "
    "Source-derived mint/entropy filters scan numeric block zero through the anchor; bounded request keys "
    "derive a second control-event scan. Complete returned receipts, touched canonical headers and all "
    "cross-stage observations agree. Log completeness and canonical mappings remain provider trust, "
    "not a genesis walk, receipt-trie proof or complete event archive. Original native mint, policy, "
    "request, recovery and seed checks remain unchanged. The leaf attempt belongs to its active request; "
    "a late original can restore attempt1 after observed attempt2. Observed requests are not proof of a "
    "lifetime attempt high-water mark. Recovery authority and oracle quality are not reexecuted. "
    "DISABLED and NOT_REQUIRED have no writer in this profile; no renderer exemption is inferred.")
PROFILE_BYTES = dumps({"id": PROFILE, "version": "1", "status": "prospective_unregistered_export_profile",
    "nativeProfile": loads(ORIGINAL_PROFILE_BYTES)["nativeProfile"], "originalNativeReaderProfileHash": ORIGINAL_PROFILE_HASH,
    "historyProfile": {"id": HISTORY_PROFILE, "hash": HISTORY_PROFILE_HASH},
    "rpcProfile": {"id": RPC_PROFILE, "hash": RPC_PROFILE_HASH},
    "bounds": {"requestedFinalizedEvents": str(MAX_EVENTS), "derivedRequestKeys": str(MAX_EVENTS),
        "combinedMatchingLogs": str(MAX_LOGS), "combinedReceipts": str(MAX_RECEIPTS),
        "combinedTouchedBlocks": str(MAX_TOUCHED_BLOCKS), "tokenDataBytes": "16384",
        "snapshotBytes": str(MAX_OUTPUT), "transcriptBytes": "67108864"},
    "rules": {"primaryFilters": "Core Registered/Reverted indexed token, Core Transfer indexed token, original coordinator EntropyRegistered indexed token, Requested/Finalized indexed token. No caller filters or ranges.",
        "controlFilters": "Chronological first-occurrence nonzero request keys from primary Requested/Finalized logs; Terminal by key and Superseded by either indexed key. No control scan when key list is empty.",
        "union": "Exact duplicate logs and receipts; full matching-log equality across every retained receipt under both stages' filters, global block log positions/order, nondecreasing touched-header timestamps and exact adjacent parent links.",
        "native": "Reuse unchanged original identity, mint, request/policy, locked first policy, recovery/late-original, status and nine-word entropy leaf checks.",
        "attempt": "Active leaf attempt and observed request maximum remain distinct; no lifetime-highwater claim.",
        "anchor": "Repeat exact hash and number source headers after all native state reads; consume the complete version2 replay."},
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _key(log): return log["blockHash"], log["transactionHash"], log["logIndex"]
def _position(log): return tuple(quantity(log[k]) for k in ("blockNumber", "transactionIndex", "logIndex"))


class PublicMintEntropySource(MintEntropySource):
    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc") and
            (provenance != "trusted_rpc" or type(transport) in (PublicRpcTransport, PublicReplayTransport)),
            "public mint entropy provenance")
        a = loads(anchor_bytes, maximum=65536, canonical=True)
        require(type(a) is dict and a.get("profile") == PROFILE, "public mint entropy anchor shape/profile")
        # The old constructor validates the unchanged closed native anchor without reads.
        super().__init__(dumps(dict(a, profile=ORIGINAL_PROFILE)), transport, provenance="synthetic_fixture")
        self.anchor_bytes, self.a, self.provenance = anchor_bytes, a, provenance
        self.reader = PublicRecordingReader(transport, a["blockHash"])

    def _primary_filters(self):
        a = self.a; token = "0x" + uint(a["tokenId"]).to_bytes(32, "big").hex()
        return [{"address": a["core"], "topics": [[REGISTERED, REVERTED], token]},
            {"address": a["core"], "topics": [TRANSFER, None, None, token]},
            {"address": a["coordinator"], "topics": [ENTROPY_REGISTERED, None, token]},
            {"address": a["coordinator"], "topics": [[REQUESTED, FINALIZED], None, token]}]

    def _request_keys(self, primary):
        keys, count = [], 0
        for log in primary["logs"]:
            if log["address"] != self.a["coordinator"] or log["topics"][0] not in (REQUESTED, FINALIZED): continue
            topics = log["topics"]; count += 1
            require(count <= MAX_EVENTS and len(topics) == 4 and topics[1] != ZERO and topics[3] == ZERO,
                "public mint entropy request key/event bound or scope")
            if topics[1] not in keys: keys.append(topics[1])
        return keys

    def _control_filters(self, keys):
        return [{"address": self.a["coordinator"], "topics": topics} for topics in
            ([TERMINAL, keys], [SUPERSEDED, keys], [SUPERSEDED, None, keys])]

    def _joined_history(self, stages, filters):
        logs, headers, receipts = {}, {}, {}
        for stage in stages:
            for log in stage["logs"]:
                key = _key(log)
                require(key not in logs or logs[key] == log, "public mint entropy cross-stage duplicate log differs")
                logs[key] = log
        require(len(logs) <= MAX_LOGS, "public mint entropy combined log bound")
        # Each scan validates its own full receipts and headers. Reconcile their
        # union as well: different stages can touch different txs in one block.
        for row in self.reader.rows:
            if "result" not in row: continue
            if row["method"] in ("eth_getBlockByHash", "eth_getBlockByNumber"):
                block = row["result"]; number = quantity(block["number"])
                require(number not in headers or headers[number] == block, "public mint entropy cross-stage header differs")
                headers[number] = block
            elif row["method"] == "eth_getTransactionReceipt":
                receipt = row["result"]; tx = receipt["transactionHash"]
                require(tx not in receipts or receipts[tx] == receipt, "public mint entropy cross-stage receipt differs")
                receipts[tx] = receipt
        require(len(headers) <= MAX_TOUCHED_BLOCKS and len(receipts) <= MAX_RECEIPTS,
            "public mint entropy combined header/receipt bound")
        previous, transactions = None, {}
        for number, header in sorted(headers.items()):
            if previous is not None:
                require(quantity(previous["timestamp"]) <= quantity(header["timestamp"]), "public mint entropy cross-stage header time regresses")
                if quantity(previous["number"]) + 1 == number:
                    require(header["parentHash"] == previous["hash"], "public mint entropy cross-stage adjacent parent differs")
            for tx in header["transactions"]:
                require(tx not in transactions or transactions[tx] == header["hash"], "public mint entropy cross-stage transaction blocks differ")
                transactions[tx] = header["hash"]
            previous = header
        positions, matched = {}, {}
        for receipt in receipts.values():
            for raw in receipt["logs"]:
                log = {key: raw[key] for key in LOG_FIELDS}
                block_position = log["blockHash"], quantity(log["logIndex"])
                require(block_position not in positions, "public mint entropy cross-stage duplicate block log position")
                positions[block_position] = quantity(log["transactionIndex"])
                if any(_matches(log, f) for f in filters): matched[_key(log)] = log
        require(matched == logs, "public mint entropy cross-stage query/receipt matching logs differ")
        by_block = {}
        for (block_hash, log_index), tx_index in positions.items():
            by_block.setdefault(block_hash, []).append((log_index, tx_index))
        for block_positions in by_block.values():
            order = [tx_index for _, tx_index in sorted(block_positions)]
            require(order == sorted(order), "public mint entropy cross-stage transaction/log order differs")
        return {"logs": sorted(logs.values(), key=_position),
            "blockTimestamps": {str(n): str(quantity(b["timestamp"])) for n, b in headers.items()},
            "counts": {"logs": str(len(logs)), "touchedBlocks": str(len(headers)), "receipts": str(len(receipts))}}

    def snapshot(self):
        if self._snapshot is not None: return self._snapshot
        require(not self._started, "public mint entropy failed capture cannot resume"); self._started = True
        a, token = self.a, uint(self.a["tokenId"])
        primary_filters = self._primary_filters()
        primary = scan_public_history(self.reader, a, filters=primary_filters)
        keys = self._request_keys(primary)
        control_filters = self._control_filters(keys) if keys else []
        controls = scan_public_history(self.reader, a, filters=control_filters) if keys else None
        history = self._joined_history([primary] + ([controls] if controls else []), primary_filters + control_filters)
        source_header = dumps(next(row["result"] for row in self.reader.rows if row["method"] == "eth_getBlockByHash"
            and row["params"] == [a["blockHash"], False]))
        self._interfaces()
        identity = self._read(a["core"], "tokenCollectionIdentity(uint256)", ("uint256",), (token,), ("bool", "uint256", "uint256", "bool"))
        lifecycle, = self._read(a["core"], "tokenLifecycle(uint256)", ("uint256",), (token,), ("uint8",))
        require(identity[0] and identity[1] == uint(a["collectionId"]) and identity[2] > 0 and lifecycle in (2, 3)
            and identity[3] == (lifecycle == 3), "public mint entropy Core identity/lifecycle differs")
        require(self._read(a["core"], "coordinatorAtMint(uint256)", ("uint256",), (token,), ("address",)) == (a["coordinator"],),
            "public mint entropy original coordinator differs")
        data, = self._read(a["core"], "tokenData(uint256)", ("uint256",), (token,), ("bytes",), maximum=16448)
        require(len(data) <= 16384, "public mint entropy token data bound")
        mint = self._mint(history, identity, lifecycle)
        entropy = self._entropy(history, mint)
        require(dumps(self.reader.request("eth_getBlockByHash", [a["blockHash"], False])) == source_header
            and dumps(self.reader.request("eth_getBlockByNumber", [hex(uint(a["blockNumber"])), False])) == source_header,
            "public mint entropy final source differs")
        if type(self.reader.transport) is PublicReplayTransport: self.reader.transport.finish()
        requests = entropy["native"]["requests"]
        coverage = {"historyProfile": HISTORY_PROFILE, "historyProfileHash": HISTORY_PROFILE_HASH,
            "startBlock": "0", "endBlock": a["blockNumber"], "primary": primary["coverage"],
            "controls": controls["coverage"] if controls else None, "derivedRequestKeys": keys,
            "controlScanStatus": "queried" if controls else "not_queried_no_request_keys", "unionCounts": history["counts"],
            "providerLogCompletenessTrusted": True, "canonicalMappingTrusted": True,
            "genesisWalk": False, "allBlockReceipts": False, "ancestryProven": False}
        result = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1", "source": a,
            "mode": "caller_admitted_public_rpc_history" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "anchorHash": keccak256(self.anchor_bytes), "transcriptHash": keccak256(self.reader.transcript()),
            "historyCoverage": coverage,
            "identity": {"tokenId": a["tokenId"], "collectionId": a["collectionId"], "collectionSerial": str(identity[2]),
                "lifecycle": str(lifecycle), "burned": identity[3], "coordinatorAtMint": a["coordinator"], "tokenDataHash": keccak256(data)},
            "mint": mint, **entropy, "requestHistoryObservation": {"observedRequestCount": str(len(requests)),
                "observedMaximumAttempt": str(max((uint(row["policy"][6]) for row in requests), default=0)),
                "lifetimeAttemptHighWaterProven": False}, "claims": CLAIMS, "qualification": QUALIFICATION})
        require(len(result) <= MAX_OUTPUT, "public mint entropy snapshot bound")
        self._snapshot = result
        return result
