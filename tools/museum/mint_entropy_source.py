"""Bounded mint and original-coordinator entropy evidence from admitted RPC bytes.

The receipt denominator is every transaction from genesis to the anchor. Neither
that RPC assumption nor a native seed hash proves consensus or random quality.
"""
from .canonical import dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_abi import calldata, decode, encode
from .chain_history import MAX_BLOCKS, scan_history
from .chain_rpc import RecordingReader, ReplayTransport, RpcTransport, quantity
from .independent_wire import ZERO_ADDRESS, require

PROFILE = "STREAM_MUSEUM_MINT_ENTROPY_SOURCE_V1"
ZERO = "0x" + "00" * 32
MAX_EVENTS = 64
MAX_OUTPUT = 4 * 1024 * 1024
STATUS = ("NONE", "DISABLED", "NOT_REQUIRED", "REGISTERED", "REQUESTED", "FINALIZED", "STALE", "FAILED")
TOKEN_ENTROPY = ("uint8", "bytes32", "address", "uint32", "bytes32", "bytes32", "uint256", "uint16")
SUBJECT = ("uint256", "bytes32", "bytes32", "bytes32", "uint8")
REQUEST = ("bytes32", "uint256", "bytes32", "address", "uint64", "uint256", "bytes32")
POLICY = ("address", "bytes32", "uint32", "bytes32", "bytes32", "bytes32", "uint16")
RECOVERY = ("bytes32",) * 7 + ("uint64", "bool")
CONFIG = ("address", "bool", "bool", "uint64", "bytes32", "bytes32", "bytes32")
LEAF = ("bytes32", "uint256", "uint8", "bytes32", "address", "address", "uint32", "bytes32", "uint16")
TRANSFER = schema_id("Transfer(address,address,uint256)")
REGISTERED = schema_id("TokenCollectionRegistered(uint16,uint256,uint256,uint256)")
REVERTED = schema_id("TokenCollectionRegistrationReverted(uint16,uint256,uint256)")
ENTROPY_REGISTERED = schema_id("EntropyRegistered(uint256,uint256,bytes32)")
REQUESTED = schema_id("EntropyRequested(bytes32,uint256,bytes32,address,uint256)")
FINALIZED = schema_id("EntropyFinalized(bytes32,uint256,bytes32,bytes32,bytes32)")
TERMINAL = schema_id("EntropyRequestTerminal(bytes32,uint8)")
SUPERSEDED = schema_id("EntropyRecoverySuperseded(uint16,bytes32,bytes32)")


def _interface(signatures):
    result = 0
    for signature in signatures:
        result ^= int(keccak256(signature.encode())[:10], 16)
    return "0x" + f"{result:08x}"


VIEW_INTERFACE = _interface(("tokenSeed(uint256)", "tokenEntropyStatus(uint256)", "tokenEntropy(uint256)"))
COORDINATOR_INTERFACE = _interface(("onTokenMinted(uint256,uint256,address,bytes32)", "requestEntropy(uint256)",
    "registerEntropyScope(uint256,uint8,bytes32)", "requestScopeEntropy(bytes32,bytes32)", "fulfillEntropy(bytes32,bytes32)"))
MODULE_TYPE = "0xb3b3ef20764c647bdeda70b21ab009ff2783106d6995be14389ec6f42ea6dfbb"
CLAIMS = {"completeTokenRequestedFinalizedHistory": True, "completeMintToSourceReceiptRange": True,
    "originalCoordinatorAtMintJoined": True, "nativeEntropyViewsReconciled": True,
    "cryptographicReceiptProof": False, "cryptographicStateProof": False, "consensusVerified": False,
    "oracleRandomnessVerified": False, "recoveryAuthorityReexecuted": False,
    "rendererEntropyExemption": False, "fullProtocolEventArchive": False, "actualChainAcceptance": False}
QUALIFICATION = ("One Core token and its original coordinator at an externally admitted RPC block. "
    "Every header and receipt from genesis is retained; native tuples, mint logs, ordered requests and "
    "finalization are reconciled. RPC completeness is not consensus or receipt-trie verification. "
    "Recovery receipts preserve original decisions without reexecuting Artist or governance authority. "
    "No renderer implies an entropy exemption; DISABLED and NOT_REQUIRED have no writer in this profile.")
PROFILE_BYTES = dumps({"id": PROFILE, "version": "1", "status": "prospective_unregistered_export_profile",
    "bounds": {"blocksIncludingGenesis": str(MAX_BLOCKS), "requestedFinalizedEvents": str(MAX_EVENTS),
        "tokenDataBytes": "16384", "transcriptBytes": "67108864", "snapshotBytes": str(MAX_OUTPUT)},
    "nativeProfile": {"coordinatorModuleType": MODULE_TYPE,
        "coordinatorVersion": schema_id("6529stream.entropy-coordinator.v1"),
        "coordinatorInterface": COORDINATOR_INTERFACE, "viewInterface": VIEW_INTERFACE,
        "sourceReviewCommit": "c4c82ca4f16abc2ca4eb131fcda9e64c26daf691"},
    "rules": {"source": "Full parent-linked genesis range, every receipt and exact EIP-1898 state reads; no hints or RPC log filters.",
        "identity": "Core mapping and lifecycle plus original coordinator; abandoned allocations may precede the unique completed mint.",
        "entropy": "REGISTERED through FAILED only; all token Requested/Finalized logs, each request and policy, first policy joined to permanently locked collection configuration, unique provider request IDs, terminal transitions and late-original recovery joins.",
        "leaf": "keccak256(abi.encode(domain,tokenId,status,seed,coordinatorAtMint,provider,providerEpoch,requestKey,requestAttempt)); domain=keccak256(6529STREAM_EXPORT_ENTROPY_LEAF_V1).",
        "eligibility": "Only FINALIZED is terminalEligible here; the output does not itself approve an acquisition or native finality."},
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def token_key(token):
    return keccak256(encode(("string", "uint256"), ("TOKEN", token)))


def request_hash(a, policy):
    return keccak256(encode(("bytes32", "uint256", "address", "address", "uint256", "uint256",
        "address", "uint32", "bytes32", "uint16"), (schema_id("6529STREAM_ENTROPY_REQUEST_V1"),
        uint(a["chainId"]), a["coordinator"], a["core"], uint(a["collectionId"]), uint(a["tokenId"]),
        policy[0], policy[2], policy[3], policy[6])))


def seed_hash(a, key, request, policy, raw):
    return keccak256(encode(("bytes32", "uint256", "address", "address", "uint256", "bytes32",
        "address", "uint32", "bytes32", "bytes32", "uint256", "bytes32", "bytes32", "bytes32"),
        (schema_id("6529STREAM_ENTROPY_SEED_V1"), uint(a["chainId"]), a["coordinator"], a["core"],
         uint(a["collectionId"]), "0x" + uint(a["tokenId"]).to_bytes(32, "big").hex(), policy[0], policy[2],
         policy[3], key, request[5], raw, policy[4], policy[5])))


def _json_tuple(values):
    return [str(value) if type(value) is int else value for value in values]


def _topic(log, index, kind="uint256"):
    return decode((kind,), hex_bytes(log["topics"][index], 32))[0]


def _position(log):
    return quantity(log["blockNumber"]), quantity(log["logIndex"])


class MintEntropySource:
    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc") and
            (provenance != "trusted_rpc" or type(transport) in (RpcTransport, ReplayTransport)), "mint entropy provenance")
        a = loads(anchor_bytes, maximum=65536, canonical=True)
        require(type(a) is dict and set(a) == {"profile", "chainId", "core", "tokenId", "collectionId", "blockHash",
            "blockNumber", "timestamp", "stateRoot", "environment", "deploymentEvidenceHash", "codePins", "coordinator"}
            and a["profile"] == PROFILE, "mint entropy anchor shape/profile")
        require(a["environment"] in ("local_evm_fixture", "public_chain"), "mint entropy environment")
        for key in ("chainId", "tokenId", "collectionId", "blockNumber", "timestamp"):
            uint(a[key], 64 if key == "timestamp" else 256)
        require(all(uint(a[key]) > 0 for key in ("chainId", "tokenId", "collectionId")), "mint entropy nonzero identity")
        for key in ("blockHash", "stateRoot", "deploymentEvidenceHash"):
            require(any(hex_bytes(a[key], 32)), "mint entropy commitment")
        require(a["core"] != a["coordinator"], "mint entropy separate native hosts")
        for key in ("core", "coordinator"): require(any(hex_bytes(a[key], 20)), "mint entropy native address")
        require(type(a["codePins"]) is list and 2 <= len(a["codePins"]) <= 32, "mint entropy pin bound")
        pins = {}
        for row in a["codePins"]:
            require(type(row) is dict and set(row) == {"address", "runtimeHash"}, "mint entropy pin shape")
            require(any(hex_bytes(row["address"], 20)) and any(hex_bytes(row["runtimeHash"], 32))
                and row["address"] not in pins, "mint entropy duplicate/zero pin")
            pins[row["address"]] = row["runtimeHash"]
        require(a["core"] in pins and a["coordinator"] in pins, "mint entropy required runtime pins")
        self.anchor_bytes, self.a, self.pins, self.provenance = anchor_bytes, a, pins, provenance
        self.reader = RecordingReader(transport, a["blockHash"])
        self._started, self._snapshot = False, None

    def _read(self, host, signature, inputs=(), values=(), outputs=(), *, maximum=32768):
        raw = self.reader.call(host, calldata(signature, inputs, values))
        require(type(raw) is str and len(raw) <= 2 + 2 * maximum, "mint entropy ABI return bound")
        return decode(outputs, hex_bytes(raw), maximum=maximum)

    def _interfaces(self):
        a = self.a
        for address, expected in self.pins.items():
            raw = self.reader.code(address)
            require(type(raw) is str and 2 < len(raw) <= 2 + 2 * 24576
                and keccak256(hex_bytes(raw)) == expected, "mint entropy runtime differs")
        for address, ids in ((a["core"], ("0x80ac58cd",)),
                             (a["coordinator"], (COORDINATOR_INTERFACE, VIEW_INTERFACE))):
            for interface in ("0x01ffc9a7",) + ids:
                require(self._read(address, "supportsInterface(bytes4)", ("bytes4",), (interface,), ("bool",)) == (True,),
                    "mint entropy required interface")
            require(self._read(address, "supportsInterface(bytes4)", ("bytes4",), ("0xffffffff",), ("bool",)) == (False,),
                "mint entropy invalid interface")
        for signature, kinds, expected in (("core()", ("address",), (a["core"],)),
            ("streamModuleType()", ("bytes32",), (MODULE_TYPE,)),
            ("streamModuleVersion()", ("bytes32",), (schema_id("6529stream.entropy-coordinator.v1"),)),
            ("streamModuleInterfaceId()", ("bytes4",), (COORDINATOR_INTERFACE,))):
            require(self._read(a["coordinator"], signature, outputs=kinds) == expected, "mint entropy native binding/version")

    def _mint(self, history, identity, lifecycle):
        a, token, cid = self.a, uint(self.a["tokenId"]), uint(self.a["collectionId"])
        allocation, mint, registration, owner = None, None, None, ZERO_ADDRESS
        transfers, abandoned = [], []
        for log in history["logs"]:
            topics = log["topics"]
            if not topics: continue
            if log["address"] == a["core"] and topics[0] in (REGISTERED, REVERTED):
                require(len(topics) == 3, "mint allocation topics")
                event_token, event_cid = _topic(log, 1), _topic(log, 2)
                data = decode(("uint16", "uint256") if topics[0] == REGISTERED else ("uint16",), hex_bytes(log["data"]))
                if event_token != token: continue
                require(data[0] == 1 and mint is None, "mint allocation version/order")
                if topics[0] == REGISTERED:
                    require(allocation is None and event_cid > 0 and data[1] > 0, "mint repeated/invalid allocation")
                    allocation = (log, event_cid, data[1])
                else:
                    require(allocation is not None and allocation[1] == event_cid and registration is None,
                        "mint abandoned allocation differs")
                    abandoned.append({"registered": allocation[0], "reverted": log})
                    require(len(abandoned) <= MAX_EVENTS, "mint abandoned allocation bound")
                    allocation = None
            elif log["address"] == a["coordinator"] and topics[0] == ENTROPY_REGISTERED:
                require(len(topics) == 3, "mint entropy registration topics")
                event_cid, event_token = _topic(log, 1), _topic(log, 2)
                commitment, = decode(("bytes32",), hex_bytes(log["data"]))
                if event_token != token: continue
                require(event_cid == cid and allocation is not None and allocation[1:] == (cid, identity[2])
                    and registration is None and mint is None, "mint entropy registration identity/order")
                registration = (log, commitment)
            elif log["address"] == a["core"] and topics[0] == TRANSFER:
                require(len(topics) == 4 and log["data"] == "0x", "mint Transfer shape")
                sender, recipient, event_token = _topic(log, 1, "address"), _topic(log, 2, "address"), _topic(log, 3)
                if event_token != token: continue
                if mint is None:
                    require(sender == ZERO_ADDRESS and recipient != ZERO_ADDRESS and allocation is not None
                        and registration is not None and log["transactionHash"] == registration[0]["transactionHash"],
                        "mint missing registration or unique mint Transfer")
                    mint = log
                else:
                    require(owner != ZERO_ADDRESS and sender == owner, "mint disconnected/post-burn Transfer")
                owner = recipient
                transfers.append(log)
        require(mint is not None and registration is not None and allocation is not None
            and (owner == ZERO_ADDRESS) == (lifecycle == 3), "mint incomplete history/lifecycle")
        if lifecycle == 2:
            require(self._read(a["core"], "ownerOf(uint256)", ("uint256",), (token,), ("address",)) == (owner,),
                "mint current owner differs")
        return {"mintCommitment": registration[1], "logs": {"registered": allocation[0],
            "entropyRegistered": registration[0], "transfer": mint}, "abandonedAllocations": abandoned,
            "tokenTransfers": transfers}

    def _entropy(self, history, mint):
        a, token, cid = self.a, uint(self.a["tokenId"]), uint(self.a["collectionId"])
        host, subject_key = a["coordinator"], token_key(token)
        entropy = self._read(host, "tokenEntropy(uint256)", ("uint256",), (token,), TOKEN_ENTROPY)
        status, seed, provider, epoch, config_hash, active, provider_id, attempt = entropy
        require(status in (3, 4, 5, 6, 7), "mint entropy status has no supported production writer")
        require(provider != ZERO_ADDRESS and epoch > 0 and config_hash != ZERO, "mint entropy provider policy missing")
        require(self._read(host, "tokenEntropyStatus(uint256)", ("uint256",), (token,), ("uint8",)) == (status,), "mint entropy status views differ")
        require(self._read(host, "tokenSeed(uint256)", ("uint256",), (token,), ("bytes32", "bool")) == (seed, status == 5), "mint entropy seed views differ")
        subject = self._read(host, "scopeEntropy(bytes32)", ("bytes32",), (subject_key,), SUBJECT)
        require(subject == (cid, mint["mintCommitment"], active, seed, status), "mint entropy subject/commitment differs")
        registered_at, = self._read(host, "registeredAtBlock(uint256)", ("uint256",), (token,), ("uint64",))
        require(registered_at == quantity(mint["logs"]["entropyRegistered"]["blockNumber"]), "mint entropy registration block differs")
        config = self._read(host, "collectionEntropyConfig(uint256)", ("uint256",), (cid,), CONFIG)
        configured_epoch, = self._read(host, "collectionProviderEpoch(uint256)", ("uint256",), (cid,), ("uint32",))
        require(config[0] != ZERO_ADDRESS and config[2] and config[3] > 0 and config[4] != ZERO
            and config[5] != ZERO and configured_epoch > 0, "mint entropy locked collection configuration")
        logs, keys = [], set()
        completed_at = _position(mint["logs"]["transfer"])
        last_transfer = mint["tokenTransfers"][-1]
        burned_at = _position(last_transfer) if _topic(last_transfer, 2, "address") == ZERO_ADDRESS else None
        for log in history["logs"]:
            topics = log["topics"]
            if log["address"] != host or not topics or topics[0] not in (REQUESTED, FINALIZED): continue
            require(len(topics) == 4, "mint entropy event topics")
            event_token = _topic(log, 2)
            if event_token != token: continue
            require(topics[3] == ZERO and topics[1] != ZERO, "mint entropy token event scope/request")
            require(_position(log) > completed_at, "mint entropy event before completed mint Transfer")
            require(topics[0] != REQUESTED or burned_at is None or _position(log) < burned_at,
                "mint entropy request after burn")
            logs.append(log)
            require(len(logs) <= MAX_EVENTS, "mint entropy packet event bound")
            if topics[0] == REQUESTED:
                require(topics[1] not in keys, "mint entropy repeated request key")
                keys.add(topics[1])
        requests, policy_rows, recovery_rows, provider_ids = {}, {}, {}, set()
        for log in logs:
            if log["topics"][0] != REQUESTED: continue
            key = log["topics"][1]
            event_provider, event_id = decode(("address", "uint256"), hex_bytes(log["data"]))
            require((event_provider, event_id) not in provider_ids, "mint entropy duplicate provider request ID")
            provider_ids.add((event_provider, event_id))
            r = self._read(host, "requests(bytes32)", ("bytes32",), (key,), REQUEST)
            p = self._read(host, "requestPolicySnapshot(bytes32)", ("bytes32",), (key,), POLICY)
            require(r[:4] == (subject_key, token, ZERO, event_provider) and r[4] == quantity(log["blockNumber"])
                and r[5] == event_id and p[0] == event_provider and p[0] != ZERO_ADDRESS and p[1] != ZERO
                and p[2] > 0 and p[3] != ZERO and p[5] == mint["mintCommitment"] and p[6] > 0,
                "mint entropy request/policy/event differs")
            require(request_hash(a, p) == key, "mint entropy request hash differs")
            require(self._read(host, "providerRequestKeys(address,uint256)", ("address", "uint256"),
                (event_provider, event_id), ("bytes32",)) == (key,), "mint entropy provider request index differs")
            recovery = self._read(host, "freshRecoveryReceipt(bytes32)", ("bytes32",), (key,), RECOVERY)
            requests[key], policy_rows[key], recovery_rows[key] = r, p, recovery
        observed, current, final_key = 3, ZERO, None
        ordered_keys, controls, superseded = [], [], None
        for log in history["logs"]:
            topics = log["topics"]
            if log["address"] != host or not topics: continue
            if topics[0] == REQUESTED and len(topics) == 4 and topics[1] in keys:
                key, p = topics[1], policy_rows[topics[1]]
                recovery = recovery_rows[key]
                require(p[6] == len(ordered_keys) + 1, "mint entropy request attempt sequence")
                if not ordered_keys:
                    require(observed == 3 and recovery == (ZERO,) * 7 + (0, False), "mint entropy initial recovery tuple")
                    require(p[:5] == (config[0], config[5], configured_epoch, config[4], config[6]),
                        "mint entropy first request differs from locked collection policy")
                else:
                    previous = policy_rows[current]
                    require(observed == 7 and recovery[0] == current and recovery[7] == requests[key][4]
                        and all(recovery[i] != ZERO for i in (2, 3, 4, 5, 6)) and p[2] > previous[2]
                        and p[4:6] == previous[4:6], "mint entropy fresh recovery sequence/receipt")
                ordered_keys.append(key)
                observed, current = 4, key
            elif topics[0] == TERMINAL:
                require(len(topics) == 2, "mint entropy terminal topics")
                if topics[1] not in keys: continue
                terminal, = decode(("uint8",), hex_bytes(log["data"]))
                require(observed == 4 and topics[1] == current and terminal in (6, 7), "mint entropy terminal transition")
                observed = terminal
                controls.append(log)
            elif topics[0] == SUPERSEDED:
                require(len(topics) == 3, "mint entropy supersession topics")
                if topics[1] not in keys and topics[2] not in keys: continue
                require(decode(("uint16",), hex_bytes(log["data"])) == (1,) and observed == 4
                    and topics[2] == current and topics[1] in ordered_keys and topics[1] != current
                    and superseded is None, "mint entropy late-original supersession")
                superseded = log
                controls.append(log)
            elif topics[0] == FINALIZED and len(topics) == 4 and _topic(log, 2) == token:
                key = topics[1]
                require(observed == 4 and key in ordered_keys and final_key is None, "mint entropy finalization without active request")
                if key != current:
                    position = ordered_keys.index(key)
                    path = ordered_keys[position + 1:]
                    require(0 < len(path) <= 32 and all(recovery_rows[k][8] for k in path)
                        and superseded is not None and superseded["topics"][1:3] == [key, current]
                        and superseded["transactionHash"] == log["transactionHash"], "mint entropy late-original path differs")
                else:
                    require(superseded is None, "mint entropy unexpected supersession")
                event_seed, raw = decode(("bytes32", "bytes32"), hex_bytes(log["data"]))
                require(requests[key][6] == raw and seed_hash(a, key, requests[key], policy_rows[key], raw) == event_seed
                    and event_seed == seed, "mint entropy finalized seed preimage differs")
                observed, current, final_key = 5, key, key
        require(observed == status and current == active and (superseded is None or final_key is not None), "mint entropy history/current status differs")
        if active == ZERO:
            require(status == 3 and not logs and seed == ZERO and provider_id == attempt == 0, "mint entropy unrequested tuple")
            require(config[0] == provider and config[4] == config_hash and configured_epoch == epoch,
                "mint entropy registered configuration differs")
        else:
            require(active in requests and (provider, epoch, config_hash, attempt) ==
                (policy_rows[active][0], policy_rows[active][2], policy_rows[active][3], policy_rows[active][6])
                and provider_id == requests[active][5], "mint entropy current request tuple differs")
        require(status == 5 or seed == ZERO, "mint entropy nonfinalized seed")
        require(all(key == final_key or row[6] == ZERO for key, row in requests.items()), "mint entropy unfinalized request randomness")
        leaf = {"tokenId": a["tokenId"], "status": str(status), "seed": seed, "coordinatorAtMint": host,
            "provider": provider, "providerEpoch": str(epoch), "requestKey": active, "requestAttempt": str(attempt)}
        leaf_bytes = encode(LEAF, (schema_id("6529STREAM_EXPORT_ENTROPY_LEAF_V1"), token, status, seed,
            host, provider, epoch, active, attempt))
        packet = {"leaf": leaf, "leafHash": keccak256(leaf_bytes), "events": [{"event":
            "EntropyRequested" if log["topics"][0] == REQUESTED else "EntropyFinalized", "emitter": host,
            "tokenId": a["tokenId"], "blockNumber": str(quantity(log["blockNumber"])),
            "transactionHash": log["transactionHash"], "logIndex": str(quantity(log["logIndex"]))} for log in logs]}
        return {"entropy": packet, "entropyLeafBytes": "0x" + leaf_bytes.hex(), "entropyLogs": logs,
            "entropyControlLogs": controls, "observedStatus": str(status), "observedStatusLabel": STATUS[status],
            "terminalEligible": status == 5, "native": {"tokenEntropy": _json_tuple(entropy), "subject": _json_tuple(subject),
                "registeredAtBlock": str(registered_at), "collectionEntropyConfig": _json_tuple(config),
                "collectionProviderEpoch": str(configured_epoch), "requests": [{"requestKey": key, "request": _json_tuple(requests[key]),
                "policy": _json_tuple(policy_rows[key]), "recovery": _json_tuple(recovery_rows[key])} for key in ordered_keys]},
            "remaining": (["Entropy is not FINALIZED at the source block."] if status != 5 else []) +
                ["RPC consensus and receipt/state proofs are not supplied.", "Oracle randomness quality and recovery authority are not reexecuted."]}

    def snapshot(self):
        if self._snapshot is not None: return self._snapshot
        require(not self._started, "failed mint entropy capture cannot resume")
        self._started = True
        a, token = self.a, uint(self.a["tokenId"])
        history = scan_history(self.reader, a)
        source_header = dumps(next(row["result"] for row in self.reader.rows if
            row["method"] == "eth_getBlockByHash" and row["params"] == [a["blockHash"], False]))
        self._interfaces()
        identity = self._read(a["core"], "tokenCollectionIdentity(uint256)", ("uint256",), (token,), ("bool", "uint256", "uint256", "bool"))
        lifecycle, = self._read(a["core"], "tokenLifecycle(uint256)", ("uint256",), (token,), ("uint8",))
        require(identity[0] and identity[1] == uint(a["collectionId"]) and identity[2] > 0 and lifecycle in (2, 3)
            and identity[3] == (lifecycle == 3), "mint entropy Core identity/lifecycle differs")
        require(self._read(a["core"], "coordinatorAtMint(uint256)", ("uint256",), (token,), ("address",)) == (a["coordinator"],),
            "mint entropy original coordinator differs")
        data, = self._read(a["core"], "tokenData(uint256)", ("uint256",), (token,), ("bytes",), maximum=16448)
        require(len(data) <= 16384, "mint entropy token data bound")
        mint = self._mint(history, identity, lifecycle)
        entropy = self._entropy(history, mint)
        block = self.reader.request("eth_getBlockByHash", [a["blockHash"], False])
        require(dumps(block) == source_header, "mint entropy final source differs")
        if type(self.reader.transport) is ReplayTransport: self.reader.transport.finish()
        result = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1", "source": a,
            "mode": "caller_admitted_rpc_history" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "anchorHash": keccak256(self.anchor_bytes), "transcriptHash": keccak256(self.reader.transcript()),
            "historyCoverage": {key: history[key] for key in ("startBlock", "endBlock", "blockCount", "transactionCount")},
            "identity": {"tokenId": a["tokenId"], "collectionId": a["collectionId"], "collectionSerial": str(identity[2]),
                "lifecycle": str(lifecycle), "burned": identity[3], "coordinatorAtMint": a["coordinator"], "tokenDataHash": keccak256(data)},
            "mint": mint, **entropy, "claims": CLAIMS, "qualification": QUALIFICATION})
        require(len(result) <= MAX_OUTPUT, "mint entropy snapshot bound")
        self._snapshot = result
        return result

    def transcript(self):
        require(self._snapshot is not None, "mint entropy snapshot required before transcript")
        return self.reader.transcript()
