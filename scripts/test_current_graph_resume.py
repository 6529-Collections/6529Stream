#!/usr/bin/env python3
"""Actual two-process current graph rehearsal on a new, local Anvil chain.

Requires a prepared native current checkout (including the exact current-graph
projections), Foundry, eth_abi and eth_hash. It never builds or prepares artifacts.
Only public unlocked local accounts are used. The optional transaction cap validates
every actual local deployment/governance receipt; it does not prove Safe or testnet execution.
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import time
from urllib.request import Request, urlopen

from eth_abi import decode, encode
from eth_hash.auto import keccak

ZERO = "0x" + "00" * 20
CALL = "(address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32)"
POLICY = "(uint8,address,bytes4,bytes32,bytes32,uint8,uint8,uint256,bytes32)"
MODULES = ["revenueResolver", "metadataRouter", "collectionMetadata",
           "entropyCoordinator", "mintManager", "mintLedger", "artistRegistry",
           "streamAdminsOrGovernance", "artworkFinalityRegistry", "moduleRegistry",
           "stateExportPublisher"]
DISCOVERY = ["eventCatalogHash", "compatibilityMatrixHash", "numericIdCatalogHash",
             "schemaCatalogHash", "canonicalizationCatalogHash", "specBundleHash",
             "reconstructionClientHash"]
SCRIPT = "script/current/DeployCurrentStack.s.sol:DeployCurrentStack"
TRANSACTION_CAP = 16_777_216


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def hexbytes(value):
    require(isinstance(value, str) and re.fullmatch(r"0x(?:[0-9a-fA-F]{2})*", value), "canonical hex bytes")
    return bytes.fromhex(value[2:])


def hx(value):
    return "0x" + value.hex()


def domain(value):
    return keccak(value.encode())


def digest(types, values):
    return keccak(encode(types, values))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def jsonable(value):
    if isinstance(value, bytes):
        return hx(value)
    if isinstance(value, dict):
        return {k: jsonable(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [jsonable(v) for v in value]
    return value


def canonical(parameter):
    kind = parameter["type"]
    if kind.startswith("tuple"):
        return "(" + ",".join(canonical(c) for c in parameter["components"]) + ")" + kind[5:]
    return kind


def array_parameter(parameter):
    match = re.fullmatch(r"(.*)\[(\d*)\]", parameter["type"])
    if match is None:
        return None
    return dict(parameter, type=match[1]), None if not match[2] else int(match[2])


def typed(parameter, value, *, named=False):
    """Strictly map ABI-shaped values; dict ordering never determines ABI order."""
    array = array_parameter(parameter)
    if array:
        item, size = array
        require(isinstance(value, (tuple, list)), "ABI array required")
        require(size is None or len(value) == size, "fixed ABI array length")
        return [typed(item, v, named=named) for v in value]
    kind = parameter["type"]
    if kind == "tuple":
        fields = parameter["components"]
        if isinstance(value, dict):
            require(set(value) == {p["name"] for p in fields}, "exact tuple fields")
            value = [value[p["name"]] for p in fields]
        require(isinstance(value, (tuple, list)) and len(value) == len(fields), "exact tuple arity")
        result = [typed(p, v, named=named) for p, v in zip(fields, value)]
        return {p["name"]: v for p, v in zip(fields, result)} if named else tuple(result)
    if kind.startswith(("uint", "int")):
        require(isinstance(value, int) and not isinstance(value, bool), "ABI integer required")
        return value
    if kind == "bool":
        require(isinstance(value, bool), "ABI boolean required")
        return value
    if kind == "address":
        require(isinstance(value, str) and re.fullmatch(r"0x[0-9a-fA-F]{40}", value), "ABI address required")
        return value.lower()
    if kind.startswith("bytes"):
        result = hexbytes(value) if isinstance(value, str) else value
        require(isinstance(result, bytes), "ABI bytes required")
        if kind != "bytes":
            require(len(result) == int(kind[5:]), "fixed ABI bytes length")
        return result
    require(kind == "string" and isinstance(value, str), "ABI string required")
    return value


class TupleText:
    """Foundry's decoded tuple notation, never eval/ast.literal_eval."""
    def __init__(self, text):
        self.text, self.pos = text, 0

    def space(self):
        while self.pos < len(self.text) and self.text[self.pos].isspace():
            self.pos += 1

    def value(self):
        self.space()
        require(self.pos < len(self.text), "truncated Foundry tuple")
        char = self.text[self.pos]
        if char in "([":
            self.pos += 1
            closing, result = (")" if char == "(" else "]"), []
            self.space()
            if self.pos < len(self.text) and self.text[self.pos] == closing:
                self.pos += 1
                return result
            while True:
                result.append(self.value())
                self.space()
                require(self.pos < len(self.text), "unclosed Foundry tuple")
                separator = self.text[self.pos]
                self.pos += 1
                if separator == closing:
                    return result
                require(separator == ",", "Foundry tuple separator")
        if char == '"':
            value, consumed = json.JSONDecoder().raw_decode(self.text[self.pos:])
            require(isinstance(value, str), "quoted Foundry string")
            self.pos += consumed
            return value
        match = re.match(r"(?:0x[0-9a-fA-F]*|true|false|-?[0-9]+)", self.text[self.pos:])
        require(match is not None, "unknown Foundry tuple token")
        token = match.group(0)
        self.pos += len(token)
        return {"true": True, "false": False}.get(token, token if token.startswith("0x") else
                                                int(token) if token not in ("true", "false") else None)

    def parse(self):
        value = self.value()
        self.space()
        require(self.pos == len(self.text), "trailing Foundry tuple input")
        return value


def output_records(text):
    decoder, position = json.JSONDecoder(), 0
    while position < len(text):
        start = text.find("{", position)
        if start < 0:
            return
        try:
            value, length = decoder.raw_decode(text[start:])
        except json.JSONDecodeError:
            position = start + 1
            continue
        position = start + length
        if isinstance(value, dict):
            yield value


class ABI:
    def __init__(self, project, output):
        self.project, self.output, self.cache = project, output, {}

    def artifact(self, name):
        if name not in self.cache:
            paths = list(self.output.glob(f"*/{name}.json"))
            require(len(paths) == 1, f"one physical artifact for {name}")
            self.cache[name] = json.loads(paths[0].read_text(encoding="utf-8"))
        return self.cache[name]

    def entry(self, contract, name, kind="function"):
        matches = [x for x in self.artifact(contract)["abi"] if x["type"] == kind and x.get("name") == name]
        require(len(matches) == 1, f"unique ABI {contract}.{name}")
        return matches[0]

    def data(self, contract, name, args=()):
        entry = self.entry(contract, name)
        require(len(args) == len(entry["inputs"]), "ABI argument count")
        types = [canonical(p) for p in entry["inputs"]]
        signature = name + "(" + ",".join(types) + ")"
        return domain(signature)[:4] + encode(types, [typed(p, v) for p, v in zip(entry["inputs"], args)])

    def result(self, contract, name, raw):
        fields = self.entry(contract, name)["outputs"]
        values = decode([canonical(p) for p in fields], raw)
        require(encode([canonical(p) for p in fields], values) == raw, "canonical complete ABI result")
        return [typed(p, v, named=True) for p, v in zip(fields, values)]

    def script_result(self, text, name):
        fields = self.entry("DeployCurrentStack", name)["outputs"]
        candidates = [x for x in output_records(text) if "returned" in x or "returns" in x]
        require(candidates, "actual structured Forge result missing")
        result = candidates[-1]
        if "returned" in result:
            return self.result("DeployCurrentStack", name, hexbytes(result["returned"]))
        values = result["returns"]
        require(isinstance(values, dict) and len(values) == len(fields), "exact Forge returned field count")
        decoded = []
        for index, p in enumerate(fields):
            key = p["name"] if p["name"] else str(index)
            require(key in values, "named or indexed Forge return missing")
            parsed = TupleText(values[key]["value"]).parse()
            decoded.append(typed(p, parsed, named=True))
        raw = encode([canonical(p) for p in fields], [typed(p, v) for p, v in zip(fields, decoded)])
        return self.result("DeployCurrentStack", name, raw)


class RPCError(RuntimeError):
    def __init__(self, error):
        super().__init__(json.dumps(error))
        self.error = error


def check_transaction_capacity(transaction, receipt, cap):
    require(receipt["transactionHash"].lower() == transaction["hash"].lower()
            and receipt["blockHash"] == transaction["blockHash"], "receipt transaction identity")
    used, limit = int(receipt["gasUsed"], 16), int(transaction["gas"], 16)
    require(int(receipt["status"], 16) == 1 and 0 < used <= limit, "successful metered transaction")
    if cap:
        require(cap == TRANSACTION_CAP and limit <= cap and used < cap,
                "actual transaction gas limit and usage below target")
    return used, limit


class Rehearsal:
    def __init__(self, args):
        self.args = args
        self.project = args.project.resolve()
        self.evidence = args.evidence.resolve()
        require(not self.evidence.exists(), "evidence directory must be new")
        self.evidence.mkdir(parents=True)
        self.url = f"http://127.0.0.1:{args.port}"
        self.abi = ABI(self.project, self.project / args.out)
        self.actions, self.transactions, self.invocations = [], [], []
        self.capacity_receipts = []
        require(args.transaction_gas_cap in (0, TRANSACTION_CAP), "supported transaction cap")
        self.rpc_id, self.anvil = 0, None
        self.initial = self.inventory()
        self.driver_hash = sha(Path(__file__))
        self.save("driver.json", {"path": str(Path(__file__).resolve()), "sha256": self.driver_hash})
        self.save("inputs.json", self.initial)

    def save(self, name, value):
        (self.evidence / name).write_text(json.dumps(jsonable(value), indent=2) + "\n", encoding="utf-8")

    def inventory(self):
        paths = {self.project / "foundry.toml"}
        paths.update(p for p in self.project.rglob("*.sol") if p.is_file())
        for directory in [self.args.out, "artifacts/current-graph/compiled"]:
            root = self.project / directory
            require(root.is_dir(), f"prepared input directory missing: {directory}")
            paths.update(root.rglob("*.json"))
        return {p.relative_to(self.project).as_posix(): sha(p) for p in sorted(paths)}

    def rpc(self, method, params=()):
        self.rpc_id += 1
        request = Request(self.url, json.dumps({"jsonrpc": "2.0", "id": self.rpc_id,
                                              "method": method, "params": list(params)}).encode(),
                          {"Content-Type": "application/json"})
        with urlopen(request, timeout=120) as response:
            result = json.load(response)
        if "error" in result:
            raise RPCError(result["error"])
        require(result.get("id") == self.rpc_id and "result" in result, "RPC response identity")
        return result["result"]

    def code(self, target):
        return hexbytes(self.rpc("eth_getCode", [target, "latest"]))

    def read(self, contract, target, name, args=()):
        data = self.abi.data(contract, name, args)
        raw = hexbytes(self.rpc("eth_call", [{"from": self.operator, "to": target,
                                            "data": hx(data), "gas": hex(90_000_000)}, "latest"]))
        return self.abi.result(contract, name, raw)

    def transaction_receipt(self, transaction_hash):
        deadline, attempts = time.monotonic() + 30, 0
        while True:
            receipt = self.rpc("eth_getTransactionReceipt", [transaction_hash])
            attempts += 1
            if receipt is not None or time.monotonic() >= deadline:
                return receipt, attempts
            time.sleep(.05)

    def retain_capacity(self, transaction, receipt, label):
        used, limit = check_transaction_capacity(transaction, receipt, self.args.transaction_gas_cap)
        block = self.rpc("eth_getBlockByHash", [receipt["blockHash"], False])
        require(block and receipt["transactionHash"] in block["transactions"], "mined transaction in original block")
        if self.args.transaction_gas_cap:
            require(int(block["gasLimit"], 16) == self.args.transaction_gas_cap, "actual capped block")
        require(transaction["from"].lower() == self.operator
                and transaction["hash"] not in {r["transaction"]["hash"] for r in self.capacity_receipts},
                "one original operator receipt")
        if self.capacity_receipts:
            require(int(transaction["nonce"], 16) == int(self.capacity_receipts[-1]["transaction"]["nonce"], 16) + 1,
                    "consecutive original operator nonce")
        else:
            require(int(transaction["nonce"], 16) == 0, "receipt ledger starts at original fresh nonce zero")
        self.capacity_receipts.append({"label": label, "transaction": transaction, "receipt": receipt,
                                       "gasUsed": used, "gasLimit": limit})
        self.save("capacity-receipts.json", self.capacity_receipts)

    def send(self, target, data, label):
        nonce = self.rpc("eth_getTransactionCount", [self.operator, "latest"])
        transaction = {"from": self.operator, "to": target, "data": hx(data), "nonce": nonce, "value": "0x0"}
        gas = int(self.rpc("eth_estimateGas", [transaction]), 16)
        padded = gas + gas // 5 + 100_000
        if self.args.transaction_gas_cap:
            require(gas < self.args.transaction_gas_cap, "direct transaction estimate below target")
            padded = min(padded, self.args.transaction_gas_cap)
        transaction["gas"] = hex(padded)
        transaction_hash = self.rpc("eth_sendTransaction", [transaction])
        receipt, polls = self.transaction_receipt(transaction_hash)
        if not receipt or int(receipt["status"], 16) != 1:
            failure = {"label": label, "request": transaction, "estimatedGas": gas,
                       "transactionHash": transaction_hash, "receipt": receipt, "receiptPolls": polls}
            self.save("failed-transaction.json", failure)
            if receipt:
                try:
                    self.save("failed-transaction-call-trace.json", self.rpc(
                        "debug_traceTransaction", [transaction_hash, {"tracer": "callTracer"}]))
                except RPCError as error:
                    self.save("failed-transaction-trace-error.json", {"error": str(error)})
        require(receipt and int(receipt["status"], 16) == 1, f"actual successful receipt: {label}")
        actual = self.rpc("eth_getTransactionByHash", [transaction_hash])
        require(actual["from"].lower() == self.operator and actual["to"].lower() == target.lower()
                and actual["input"].lower() == hx(data) and actual["nonce"] == nonce
                and int(actual["value"], 16) == 0, "confirmed exact public transaction")
        self.retain_capacity(actual, receipt, label)
        self.transactions.append({"label": label, "transaction": actual, "receipt": receipt, "receiptPolls": polls})
        self.save("transactions.json", self.transactions)
        return receipt

    def send_method(self, contract, target, name, args=()):
        return self.send(target, self.abi.data(contract, name, args), name)

    def script(self, name, args=(), *, broadcast=False, operator=None, rejection=None):
        before = self.inventory()
        require(before == self.initial and sha(Path(__file__)) == self.driver_hash,
                "compiled/source/projection/driver inputs changed before invocation")
        sender = operator or self.operator
        environment = {k: v for k, v in os.environ.items()
                       if not k.startswith(("STREAM_", "FOUNDRY_", "DAPP_"))}
        environment.update(self.environment)
        environment["STREAM_DEPLOYER"] = sender
        command = [str(self.args.forge), "script", SCRIPT, "--sig",
                   hx(self.abi.data("DeployCurrentStack", name, args)), "--rpc-url", self.url,
                   "--sender", sender, "--unlocked", "--json", "--offline"]
        if broadcast:
            command += ["--broadcast", "--slow", "--gas-estimate-multiplier",
                        "600" if name == "resume" and not self.args.transaction_gas_cap else "130"]
        ordinal = len(self.invocations)
        log_path = self.evidence / f"invocation-{ordinal}-{name}.log"
        with log_path.open("wb") as log:
            process = subprocess.Popen(command, cwd=self.project, env=environment, stdout=log,
                                       stderr=subprocess.STDOUT, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
            # Kill an unexpected cache miss immediately; this runner never owns compilation.
            while process.poll() is None:
                time.sleep(.25)
                if re.search(rb"Compiling [1-9]|Compiler run", log_path.read_bytes()):
                    process.kill()
                    process.wait()
                    raise RuntimeError("unexpected compilation: prepare exact cached artifacts first")
        text = log_path.read_text(encoding="utf-8", errors="strict")
        require(self.inventory() == before and sha(Path(__file__)) == self.driver_hash,
                "invocation changed retained sources/artifacts/projections/driver")
        require(not re.search(r"Compiling [1-9]|Compiler run", text), "no compilation admitted")
        self.invocations.append({"ordinal": ordinal, "function": name, "pid": process.pid,
                                 "command": command, "exitCode": process.returncode,
                                 "logSha256": sha(log_path), "broadcast": broadcast})
        self.save("invocations.json", self.invocations)
        if rejection is not None:
            require(process.returncode != 0 and rejection in text, "expected specific script rejection")
            return None
        if process.returncode != 0:
            failures = set(re.findall(r"Transaction Failure: (0x[0-9a-fA-F]{64})", text))
            for failed_hash in sorted(failures):
                self.save(f"invocation-{ordinal}-failed-receipt.json", self.rpc(
                    "eth_getTransactionReceipt", [failed_hash]))
                try:
                    self.save(f"invocation-{ordinal}-failed-call-trace.json", self.rpc(
                        "debug_traceTransaction", [failed_hash, {"tracer": "callTracer"}]))
                except RPCError as error:
                    self.save(f"invocation-{ordinal}-failed-trace-error.json", {"error": str(error)})
        require(process.returncode == 0, f"actual Forge {name} failed; inspect {log_path.name}")
        result = self.abi.script_result(text, name)
        if broadcast:
            selector = self.abi.data("DeployCurrentStack", name, args)[:4].hex()
            journal = self.project / f"broadcast/DeployCurrentStack.s.sol/31337/{selector}-latest.json"
            require(journal.is_file(), "actual broadcast journal required")
            raw = journal.read_bytes()
            (self.evidence / f"invocation-{ordinal}-broadcast.json").write_bytes(raw)
            saved = json.loads(raw)
            require(saved["receipts"] and all(int(r["status"], 16) == 1 for r in saved["receipts"]),
                    "all broadcast receipts successful")
            transaction_hashes = [t["hash"].lower() for t in saved["transactions"]]
            receipt_hashes = [r["transactionHash"].lower() for r in saved["receipts"]]
            require(len(transaction_hashes) == len(set(transaction_hashes)) == len(receipt_hashes)
                    == len(set(receipt_hashes)) and set(transaction_hashes) == set(receipt_hashes),
                    "exact complete broadcast transaction and receipt hash sets")
            for receipt in saved["receipts"]:
                onchain = self.rpc("eth_getTransactionReceipt", [receipt["transactionHash"]])
                require(onchain and onchain["blockHash"] == receipt["blockHash"]
                        and int(onchain["status"], 16) == 1, "broadcast receipt confirmed on same chain")
                transaction = self.rpc("eth_getTransactionByHash", [receipt["transactionHash"]])
                self.retain_capacity(transaction, onchain, f"{name}:{transaction['nonce']}")
        self.save(f"invocation-{ordinal}-result.json", result)
        return result

    def publication(self, label, replacement=None):
        current_values = self.read("StreamSystemManifest", self.manifest, "streamSystemManifest")
        fields = self.abi.entry("StreamSystemManifest", "streamSystemManifest")["outputs"]
        current = dict(zip([p["name"] for p in fields], current_values))
        modules = [current[n] for n in MODULES]
        if replacement:
            modules = [replacement.get(n, value) for n, value in zip(MODULES, modules)]
        raw = json.dumps({"schema": 1, "rehearsal": label, "chainId": 31337,
                          "executor": self.executor, "revision": current["revision"] + 1},
                         separators=(",", ":"), sort_keys=True).encode()
        pointer = self.chunk(raw)
        fmt = hexbytes("0x8844b744a67cdcdb84ea3c6e3d686883da175820b9ff07a19cffa14bf62e6e81")
        canon = hexbytes("0x886c7c89c308c459ca8a626e0ef36a5ea9f4c7a7b56aaf86c71a2ddf3b4f9044")
        leaf = digest(["bytes32", "uint256", "uint32", "bytes32"],
                      [hexbytes("0x852f4811a2eb32694863d94ba41b545a65ef4c76086a32c35881f0c4e250a7b5"), 0, len(raw), keccak(raw)])
        listed = digest(["bytes32", "uint32", "bytes32[]"],
                        [hexbytes("0xa93750a5551ac5668c8f24cca85acaf1d5f8334fac9406f845fce1ce35548839"), len(raw), [leaf]])
        manifest_hash = digest(["bytes32", "uint16", "bytes32", "bytes32", "uint32", "uint16", "bytes32"],
                               [hexbytes("0xd6ab89b077c61a288c7168cf8f1c9a7a19464b10475735dae37cb46a0c94c40b"), 1, fmt, canon, len(raw), 1, listed])
        envelope = encode(["bytes4", "uint16", "bytes32", "bytes32", "uint32", "uint16", "(address,uint32,bytes32)[]"],
                          [hexbytes("0x6c9d2530"), 1, fmt, canon, len(raw), 1, [(pointer, len(raw), keccak(raw))]])
        root = self.chunk(envelope)
        update = {"manifestHash": manifest_hash, "manifestURI": f"https://example.invalid/local-resume/{label}"}
        update.update({n: current[n] for n in DISCOVERY})
        scope = digest(["bytes32", "uint256", "address"],
                       [hexbytes("0xf73b4d7b4d260fce0823707f836fdf29a1767a2a2a9cfbce14ec8c5e49e47841"), 31337, self.manifest])
        state_domain = hexbytes("0x3764ccb415d0aac07f1bddb8d4841ad6d4c2f9b2fe7ce7d221c586bc056aaf60")
        state_types = ["bytes32", "bytes32", "bytes32", "bytes32", "address", "bytes32", "bytes32", "uint64"]
        discovery = digest(["bytes32"] * 7, [current[n] for n in DISCOVERY])
        old = digest(state_types, [state_domain, scope, current["manifestHash"], domain(current["manifestURI"]),
                     self.read("StreamSystemManifest", self.manifest, "streamSystemManifestPointer")[0],
                     digest(["address"] * 11, [current[n] for n in MODULES]), discovery, current["revision"]])
        new = digest(state_types, [state_domain, scope, manifest_hash, domain(update["manifestURI"]), root,
                                  digest(["address"] * 11, modules), discovery, current["revision"] + 1])
        data = self.abi.data("StreamSystemManifest", "publishStreamSystemManifest", [root, update])
        return self.operation(self.manifest, data, (scope, old, new)), data, root, update

    @staticmethod
    def operation(target, data, hashes):
        return (target, 0, data[:4], keccak(data), *hashes)

    def chunk(self, raw):
        self.send_method("StreamSchemaDocumentStore", self.store, "publishChunk", [raw])
        pointer, length = self.read("StreamSchemaDocumentStore", self.store, "chunk", [keccak(raw)])
        require(length == len(raw) and self.code(pointer) == b"\0" + raw, "exact immutable STOP payload")
        return pointer

    def execute_batch(self, label, action_class, calls, data):
        calls = [typed({"type": "tuple", "components": self.abi.entry(
            "StreamGovernanceExecutor", "scheduleGovernanceBatch")["inputs"][1]["components"]}, c) for c in calls]
        require(len(calls) == len(data) and calls, "complete actual batch")
        require(all(c[1] == 0 and c[2] == d[:4] and c[3] == keccak(d) for c, d in zip(calls, data)),
                "actual calldata/selector/zero-value binding")
        self.send_method("StreamGovernanceExecutor", self.executor, "publishGovernanceCallData", [data])
        call_hash = digest(["bytes32", CALL + "[]"],
                           [hexbytes("0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70"), calls])
        domains = ["0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c",
                   "0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7",
                   "0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b"]
        hashes = [digest(["bytes32", "bytes32", "bytes32[]"], [hexbytes(d), call_hash, [c[4+i] for c in calls]])
                  for i, d in enumerate(domains)]
        root, root_hash, root_revision = self.read("StreamGovernanceExecutor", self.executor, "governanceRootState")
        require(root == self.root and keccak(self.code(root)) == root_hash and root_revision > 0, "original actual root")
        delay = self.read("StreamGovernanceExecutor", self.executor, "minimumDelay", [action_class])[0]
        now = int(self.rpc("eth_getBlockByNumber", ["latest", False])["timestamp"], 16)
        ready, expires = now + delay + 60, now + delay + 60 + 7 * 86400
        reason, uri, manifest_hash = domain(label), f"https://example.invalid/local-resume/{label}", domain("local resume governance")
        schedule = self.abi.data("StreamGovernanceExecutor", "scheduleGovernanceBatch",
                                 [action_class, calls, *hashes, ready, expires, reason, uri, manifest_hash])
        receipt = self.send_method("StreamGovernanceActor", self.root, "execute", [self.executor, 0, schedule])
        event = self.abi.entry("StreamGovernanceExecutor", "GovernanceActionScheduled", "event")
        topic = hx(domain(event["name"] + "(" + ",".join(canonical(p) for p in event["inputs"]) + ")"))
        logs = [l for l in receipt["logs"] if l["address"].lower() == self.executor and l["topics"][0] == topic]
        require(len(logs) == 1, "one original scheduled action receipt")
        action_id = hexbytes(logs[0]["topics"][1])
        original = self.read("StreamGovernanceExecutor", self.executor, "governanceAction", [action_id])[0]
        expected = {"status": 1, "actionClass": action_class, "proposer": self.root,
                    "target": calls[0][0], "value": 0, "selector": calls[0][2], "callHash": call_hash,
                    "scopeHash": hashes[0], "oldValueHash": hashes[1], "newValueHash": hashes[2],
                    "notBefore": ready, "expiresAfter": expires, "reasonHash": reason,
                    "reasonURI": uri, "manifestHash": manifest_hash,
                    "executor": ZERO, "canceller": ZERO, "vetoer": ZERO}
        require(all(original[k] == v for k, v in expected.items()), "complete original scheduled action")
        execute = self.abi.data("StreamGovernanceExecutor", "executeGovernanceBatch", [action_id, calls, data])
        try:
            self.rpc("eth_call", [{"from": self.operator, "to": self.executor, "data": hx(execute)}, "latest"])
        except RPCError as exc:
            require(hx(domain("GovernanceActionNotExecutable(bytes32,uint64)")[:4])[2:] in str(exc),
                    "exact premature execution error")
        else:
            raise RuntimeError("governance delay was bypassed")
        self.rpc("evm_setNextBlockTimestamp", [ready])
        self.rpc("evm_mine")
        self.send(self.executor, execute, label)
        current = self.read("StreamGovernanceExecutor", self.executor, "governanceAction", [action_id])[0]
        require(current["status"] == 3 and current["executor"] == self.operator, "actual permissionless completion")
        require(all(current[k] == v for k, v in expected.items() if k not in ("status", "executor")),
                "original action and zero cancellation/veto retained")
        self.actions.append({"label": label, "actionId": action_id, "original": original, "completed": current})
        self.save("actions.json", self.actions)

    def admit_catalog(self, rows):
        policy_inputs = self.abi.entry("StreamGovernanceExecutor", "extendGovernanceActionPolicy")["inputs"][3]
        rows = typed(policy_inputs, rows)
        keys = [digest(["uint8", "address", "bytes4"], r[:3]) for r in rows]
        require(keys == sorted(set(keys)), "complete ordered unique initial admission intent")
        for index in range(0, len(rows), 64):
            chunk = rows[index:index+64]
            require(all(keccak(self.code(r[1])) == r[3] for r in chunk), "original admitted runtime pins")
            candidate, catalog, count, revision = self.read("StreamGovernanceExecutor", self.executor, "governanceActionPolicyState")
            following = digest(["bytes32", "uint256", "address", "bytes32", "uint64", "bytes32", "uint256", "bytes32"],
                               [domain("6529STREAM_GOVERNANCE_ACTION_POLICY_EXTENSION_V1"), 31337, self.executor,
                                candidate, revision+1, catalog, count, digest([POLICY+"[]"], [chunk])])
            scope = digest(["bytes32", "uint256", "address"],
                           [domain("6529STREAM_GOVERNANCE_ACTION_POLICY_SCOPE_V1"), 31337, self.executor])
            state_types = ["bytes32", "bytes32", "bytes32", "uint64", "bytes32", "uint256"]
            state_domain = domain("6529STREAM_GOVERNANCE_ACTION_POLICY_STATE_V1")
            old = digest(state_types, [state_domain, scope, candidate, revision, catalog, count])
            new = digest(state_types, [state_domain, scope, candidate, revision+1, following, count+len(chunk)])
            data = self.abi.data("StreamGovernanceExecutor", "extendGovernanceActionPolicy", [revision, catalog, following, chunk])
            tail, tail_data, _, _ = self.publication(f"catalog-{index//64}")
            self.execute_batch(f"catalog-{index//64}", 3, [self.operation(self.executor, data, (scope, old, new)), tail],
                               [data, tail_data])
            require(self.read("StreamGovernanceExecutor", self.executor, "governanceActionPolicyState")
                    == [candidate, following, count+len(chunk), revision+1], "exact sequential catalog prefix")

    def run(self):
        with socket.socket() as probe:
            require(probe.connect_ex(("127.0.0.1", self.args.port)) != 0, "local port must be unused")
        command = [str(self.args.anvil), "--host", "127.0.0.1", "--port", str(self.args.port),
                   "--chain-id", "31337", "--hardfork", "paris", "--gas-limit",
                   str(self.args.transaction_gas_cap or 100_000_000), "--quiet"]
        # Suppress Anvil's test-key banner: only public accounts and receipts are retained.
        self.anvil = subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                      creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        try:
            for _ in range(100):
                try:
                    if self.rpc("eth_chainId") == "0x7a69":
                        break
                except (OSError, RPCError):
                    time.sleep(.1)
            else:
                raise RuntimeError("new local Anvil did not start")
            require(self.rpc("web3_clientVersion").lower().startswith("anvil"), "owned local Anvil only")
            accounts = [a.lower() for a in self.rpc("eth_accounts")]
            require(len(accounts) >= 6 and self.rpc("eth_blockNumber") == "0x0", "fresh local chain")
            self.operator = accounts[0]
            require(int(self.rpc("eth_getTransactionCount", [self.operator, "latest"]), 16) == 0,
                    "original fresh operator nonce zero")
            self.environment = {"FOUNDRY_PROFILE": self.args.profile, "STREAM_DEPLOYER": self.operator,
                                "STREAM_ARTIST": accounts[1], "STREAM_PLATFORM_SIGNER": accounts[2],
                                "STREAM_PROTOCOL_TREASURY": accounts[3],
                                "STREAM_ARCHIVAL_OBSERVERS": hx(encode(["(address,bytes32)[]"],
                                    [sorted([(accounts[4], domain("local observer one")),
                                             (accounts[5], domain("local observer two"))])]))}
            self.save("local-chain.json", {"command": command, "pid": self.anvil.pid,
                      "operator": self.operator, "configuration": self.environment,
                      "limits": {"blockGas": self.args.transaction_gas_cap or 100_000_000,
                                 "transactionGasCap": self.args.transaction_gas_cap, "hardfork": "paris"}})
            phase1 = self.script("run", broadcast=True)[0]
            require(phase1["schemaVersion"] == 3 and phase1["phase"] == 1
                    and phase1["operator"] == self.operator and not phase1["graphPrerequisitesSelected"], "explicit original phase one")
            self.checkpoint = phase1["checkpoint"]
            self.executor = phase1["executor"]
            self.root = self.read("StreamGovernanceExecutor", self.executor, "governanceRootState")[0]
            core = phase1["core"]
            self.manifest = self.read("StreamCore", core, "getSatellitePointer", [domain("SYSTEM_MANIFEST")])[0]
            self.store = self.read("StreamCollectionMetadataV1", phase1["collectionMetadata"], "chunkStore")[0]
            checkpoint_raw = self.read("StreamCurrentGraphCheckpoint", self.checkpoint, "payload")[0]
            require(keccak(checkpoint_raw) == phase1["checkpointPayloadHash"], "exact phase-one payload hash")
            require(self.read("StreamCurrentGraphCheckpoint", self.checkpoint, "operator")[0] == self.operator
                    and self.read("StreamCurrentGraphCheckpoint", self.checkpoint, "deploymentChainId")[0] == 31337,
                    "original checkpoint creator/chain")
            checkpoint_template = hexbytes(self.abi.artifact("StreamCurrentGraphCheckpoint")["deployedBytecode"]["object"])
            require(self.code(self.checkpoint) == checkpoint_template, "exact checkpoint runtime implementation")
            require(self.read("StreamGovernanceActor", self.root, "controller")[0] == self.operator,
                    "actual root Actor controlled by original public local operator")
            require(not self.code(phase1["reservedCoordinator"]), "reserved is not deployed")
            journal = json.loads((self.evidence / "invocation-0-broadcast.json").read_bytes())
            slots = [t["contractAddress"].lower() for t in journal["transactions"]
                     if t.get("contractName") == "StreamDeploymentSlot" and t.get("transactionType") == "CREATE"]
            require(len(slots) == len(set(slots)) == 12 and phase1["coordinatorSlot"] in slots,
                    "two completed Artist and ten reserved graph slots")
            consumed = [slot for slot in slots if self.read("StreamDeploymentSlot", slot, "consumed")[0]]
            require(len(consumed) == 2, "only both Artist slots completed in phase one")
            artist_slots = {}
            for slot in consumed:
                product = self.read("StreamDeploymentSlot", slot, "product")[0]
                require(self.read("StreamDeploymentSlot", slot, "operator")[0] == self.operator
                        and self.rpc("eth_getTransactionCount", [slot, "latest"]) == "0x2"
                        and self.rpc("eth_getTransactionCount", [product, "latest"]) == "0x1"
                        and 0 < len(self.code(product)) <= 24576, "original single-use Artist slot and child-free host")
                artist_slots[product] = {"slot": slot, "slotRuntimeHash": keccak(self.code(slot)),
                                         "runtimeHash": keccak(self.code(product))}
            require(phase1["artistRegistry"] in artist_slots, "original facade slot")
            identity = next(host for host in artist_slots if host != phase1["artistRegistry"])
            require(self.read("StreamArtistIdentityAuthority", identity, "artistRegistry")[0] == phase1["artistRegistry"]
                    and self.read("StreamArtistIdentityAuthority", identity, "core")[0] == core
                    and self.read("StreamArtistIdentityAuthority", identity, "operationCoordinator")[0] == phase1["reservedCoordinator"],
                    "original Identity host pins")
            original_slots = {}
            for slot in slots:
                if slot in consumed:
                    continue
                product = self.read("StreamDeploymentSlot", slot, "product")[0]
                require(self.read("StreamDeploymentSlot", slot, "operator")[0] == self.operator
                        and not self.read("StreamDeploymentSlot", slot, "consumed")[0]
                        and self.rpc("eth_getTransactionCount", [slot, "latest"]) == "0x1"
                        and not self.code(product), "original unconsumed nonce-one slot")
                original_slots[slot] = {"product": product, "runtimeHash": keccak(self.code(slot))}
            require(len(original_slots) == 10, "exact ten original late graph slots")
            self.save("artist-slots.json", artist_slots)
            self.script("resume", [self.checkpoint], rejection="executed original graph pointer selection")
            self.script("resume", [self.checkpoint], operator=accounts[1], rejection="checkpoint operator")
            self.admit_catalog(phase1["catalogAdmissionIntent"])
            registration = self.script("prepareGraphRegistration", [self.checkpoint])[0]
            require(registration["actionClass"] == 1, "actual class-one registration stage")
            self.execute_batch("graph-registration", registration["actionClass"], registration["calls"], registration["callDatas"])
            _, _, payload, update = self.publication("graph-selection", {
                "metadataRouter": phase1["metadataRouter"], "artistRegistry": phase1["artistRegistry"],
                "collectionMetadata": phase1["collectionMetadata"]})
            selection = self.script("prepareGraphSelection", [self.checkpoint, payload, update])[0]
            require(selection["actionClass"] == 3, "actual class-three pointer/manifest stage")
            self.execute_batch("graph-selection", selection["actionClass"], selection["calls"], selection["callDatas"])
            for key, target in [("METADATA_ROUTER", phase1["metadataRouter"]), ("ARTIST_REGISTRY", phase1["artistRegistry"]),
                                ("COLLECTION_METADATA", phase1["collectionMetadata"])]:
                pointer = self.read("StreamCore", core, "getSatellitePointer", [domain(key)])
                require(pointer[0] == target and pointer[1] == keccak(self.code(target)) and pointer[6] == 1,
                        "actual selected prerequisite before new resume process")
            phase2 = self.script("resume", [self.checkpoint], broadcast=True)[0]
            legacy = phase2["deployment"]
            require(phase2["schemaVersion"] == 3 and phase2["phase"] == 2 and phase2["phaseOneCheckpoint"] == self.checkpoint
                    and phase2["graphPrerequisitesSelected"]
                    and phase2["selectedPrerequisites"] == [domain("COLLECTION_METADATA"), domain("METADATA_ROUTER"), domain("ARTIST_REGISTRY")],
                    "actual second invocation completion")
            require(legacy["schemaVersion"] == 2 and legacy["core"] == core and legacy["executor"] == self.executor
                    and legacy["artistRegistry"] == phase1["artistRegistry"]
                    and legacy["artistCoordinator"] == phase1["reservedCoordinator"]
                    and legacy["artistOwners"][2] == identity
                    and legacy["metadata"] == phase1["metadataRouter"] and legacy["provider"] == phase1["entropyProvider"]
                    and legacy["foundationInitialized"] and not legacy["productsActivated"],
                    "legacy meanings and partial product-selection output preserved")
            require(self.inventory() == self.initial, "all original final source/artifact/projection inputs retained")
            require(phase2["collectionMetadata"] == phase1["collectionMetadata"]
                    and phase2["schemaStore"] == self.store, "same original graph prerequisites")
            for slot, old in original_slots.items():
                require(keccak(self.code(slot)) == old["runtimeHash"]
                        and self.read("StreamDeploymentSlot", slot, "product")[0] == old["product"]
                        and self.read("StreamDeploymentSlot", slot, "consumed")[0]
                        and self.rpc("eth_getTransactionCount", [slot, "latest"]) == "0x2"
                        and 0 < len(self.code(old["product"])) <= 24576, "same original consumed slot/runtime")
            for host, original in artist_slots.items():
                require(keccak(self.code(host)) == original["runtimeHash"]
                        and keccak(self.code(original["slot"])) == original["slotRuntimeHash"]
                        and self.read("StreamDeploymentSlot", original["slot"], "product")[0] == host
                        and self.read("StreamDeploymentSlot", original["slot"], "consumed")[0],
                        "same completed phase-one Artist slots after resume")
            require(self.capacity_receipts and all(r["gasUsed"] > 0 for r in self.capacity_receipts)
                    and int(self.rpc("eth_getTransactionCount", [self.operator, "latest"]), 16)
                        == len(self.capacity_receipts), "complete original operator nonce range metered")
            require(self.read("StreamCurrentGraphCheckpoint", self.checkpoint, "payload")[0] == checkpoint_raw,
                    "checkpoint unchanged through governance and fresh resume")
            require(len({v["pid"] for v in self.invocations}) == len(self.invocations), "separate OS invocation identities")
            self.save("result.json", {"status": "PASS", "phase1": phase1, "phase2": phase2,
                      "originalSlots": original_slots, "actions": len(self.actions), "invocations": self.invocations,
                      "inputsUnchanged": self.inventory() == self.initial,
                      "localBroadcastGasEstimateMultiplier": {"run": 130, "resume": 130 if self.args.transaction_gas_cap else 600},
                      "transactionGasCap": self.args.transaction_gas_cap,
                      "transactionCount": len(self.capacity_receipts),
                      "maximumReceiptGas": max(r["gasUsed"] for r in self.capacity_receipts),
                      "transactionCapacityAccepted": bool(self.args.transaction_gas_cap),
                      "scope": "actual local Actor/Executor governance and fresh-process checkpoint resume; not Safe or testnet execution"})
        except Exception:
            try:
                state = self.rpc("anvil_dumpState")
                with gzip.GzipFile(filename=str(self.evidence / "failed-local-state.json.gz"),
                                   mode="wb", mtime=0) as handle:
                    handle.write(json.dumps({"state": state}).encode())
            except Exception as state_error:
                self.save("failed-state-capture-error.json", {"error": str(state_error)})
            raise
        finally:
            if self.anvil:
                self.anvil.terminate()
                self.anvil.wait(timeout=20)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--out", default="out/current")
    parser.add_argument("--profile", default="current")
    parser.add_argument("--forge", type=Path, default=Path("forge"))
    parser.add_argument("--anvil", type=Path, default=Path("anvil"))
    parser.add_argument("--port", type=int, default=18749)
    parser.add_argument("--transaction-gas-cap", type=int, choices=[0, TRANSACTION_CAP], default=0,
                        help="0 keeps the legacy local harness; 16777216 requires all actual deployment/governance transactions to fit")
    args = parser.parse_args()
    rehearsal = Rehearsal(args)
    try:
        rehearsal.run()
    except Exception as exc:
        rehearsal.save("failure.json", {"status": "FAIL", "error": str(exc),
                                       "invocations": rehearsal.invocations})
        raise


if __name__ == "__main__":
    main()
