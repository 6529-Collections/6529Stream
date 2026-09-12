"""Isolated local-EVM capture using prebuilt, externally reviewed Foundry artifacts.

Starts its own loopback Anvil with public unlocked fixture accounts. This module
cannot broadcast to a supplied RPC URL. It neither builds contracts nor changes
the existing Foundry snapshots. Core/governance/wallet boundaries stay explicit.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import time
import urllib.request
import urllib.parse

from .canonical import dumps, hex_bytes, keccak256, schema_id
from .chain_abi import Array, calldata, decode, encode
from .chain_rpc import ReplayTransport, RpcTransport
from .independent_source import IndependentSourceAdapter, PROFILE
from .independent_wire import DOCUMENT_SPEC, RAW_BYTES, RAW_DEFINITION, SUBJECT, ZERO, require


GAS_CONFIG = ("string", "uint256", "uint256", "uint8")
CONFIG = ("address", "address", "address", "bytes32", "string", "bytes32", GAS_CONFIG, GAS_CONFIG)
REQUEST = ("address", "uint256", "bytes32", "bytes32", "bytes32", "uint16", "bytes", "bytes32",
           "string", "bytes", "uint64", "uint256", "uint64")
WRITE_SIGNATURE = ("recordIndependentPreservation((uint8,uint256,uint256,bytes32),"
                   "(address,uint256,bytes32,bytes32,bytes32,uint16,bytes,bytes32,string,bytes,uint64,uint256,uint64),bytes)")


class LocalFixture:
    def __init__(self, artifacts, endpoint):
        require(urllib.parse.urlparse(endpoint).hostname == "127.0.0.1", "fixture is loopback-only")
        self.artifacts, self.endpoint = artifacts, endpoint
        self.addresses, self.artifact_rows, self.receipts = {}, {}, []
        self.account = self.rpc("eth_accounts", [])[0]

    def rpc(self, method, params):
        request = urllib.request.Request(self.endpoint, data=dumps({
            "jsonrpc": "2.0", "id": 1, "method": method, "params": params}),
            headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(request, timeout=30) as response:
            value = json.load(response)
        require("error" not in value, "local fixture RPC failure: " + method)
        return value["result"]

    def send(self, data, target=None, sender=None):
        tx = {"from": sender or self.account, "data": data, "gas": "0x1c9c380"}
        if target:
            tx["to"] = target
        tx_hash = self.rpc("eth_sendTransaction", [tx])
        receipt = self.rpc("eth_getTransactionReceipt", [tx_hash])
        deadline = time.monotonic() + 30
        while receipt is None and time.monotonic() < deadline:
            time.sleep(0.01)
            receipt = self.rpc("eth_getTransactionReceipt", [tx_hash])
        self.receipts.append({"transaction": tx, "transactionHash": tx_hash, "receipt": receipt})
        require(receipt is not None, "local fixture receipt confirmation timed out")
        require(receipt["status"] == "0x1", "local fixture transaction reverted")
        return receipt

    def read(self, target, signature, kinds=(), values=(), outputs=()):
        result = self.rpc("eth_call", [{"to": target, "data": calldata(signature, kinds, values)}, "latest"])
        return decode(outputs, hex_bytes(result))

    def invoke(self, target, signature, kinds=(), values=(), sender=None):
        return self.send(calldata(signature, kinds, values), target, sender)

    def deploy(self, name, kinds=(), values=()):
        if name in self.addresses:
            return self.addresses[name]
        paths = list(self.artifacts.rglob(name + ".json"))
        require(len(paths) == 1, "fixture artifact ambiguous/missing: " + name)
        raw = paths[0].read_bytes()
        artifact = json.loads(raw)
        bytecode = artifact["bytecode"]["object"].removeprefix("0x")
        links = {}
        for source, libraries in artifact["bytecode"]["linkReferences"].items():
            for library, positions in libraries.items():
                address = self.deploy(library)
                links[source + ":" + library] = address
                for position in positions:
                    require(position["length"] == 20, "fixture link width")
                    start = position["start"] * 2
                    bytecode = bytecode[:start] + address[2:] + bytecode[start + 40:]
        args = encode(kinds, values)
        creation = "0x" + bytecode + args.hex()
        receipt = self.send(creation)
        address = receipt["contractAddress"]
        runtime = hex_bytes(self.rpc("eth_getCode", [address, "latest"]))
        require(0 < len(runtime) <= 24576, "fixture production/runtime size")
        self.addresses[name] = address
        self.artifact_rows[name] = {"path": paths[0].relative_to(self.artifacts).as_posix(), "sha256": hashlib.sha256(raw).hexdigest(),
            "address": address, "links": links, "constructorArgumentsHex": "0x" + args.hex(),
            "creationHash": keccak256(hex_bytes(creation)), "runtimeHash": keccak256(runtime),
            "runtimeBytes": str(len(runtime))}
        return address

    def register(self, registry, executor, store, name, kind, payload, canonicalization=RAW_BYTES):
        chunks = []
        for offset in range(0, len(payload), 8192):
            part = payload[offset:offset + 8192]
            self.invoke(store, "publishChunk(bytes)", ("bytes",), (part,))
            chunks.append(keccak256(part))
        spec = (name, kind, keccak256(payload), canonicalization, ZERO, "", len(payload))
        arguments = (DOCUMENT_SPEC, Array("bytes32"))
        transition = self.read(registry, "registrationTransition((string,uint8,bytes32,bytes32,bytes32,string,uint32),bytes32[])",
                               arguments, (spec, chunks), ("bytes32",) * 3)
        data = calldata("registerDocument((string,uint8,bytes32,bytes32,bytes32,string,uint32),bytes32[])", arguments, (spec, chunks))
        self.invoke(executor, "execute(address,bytes,bytes32,bytes32,bytes32,uint8)",
                    ("address", "bytes", "bytes32", "bytes32", "bytes32", "uint8"),
                    (registry, hex_bytes(data), *transition, 1))
        return schema_id(name)

    def build(self):
        core = self.deploy("IndependentCoreBoundary")
        executor = self.deploy("IndependentExecutorBoundary")
        registry = self.deploy("StreamSchemaRegistry", ("address",), (executor,))
        store, = self.read(registry, "chunkStore()", outputs=("address",))
        self.register(registry, executor, store, "RAW_BYTES", 1, RAW_DEFINITION)
        # Original lexical whitespace spans two native chunks; no JSON coercion.
        schema = b'{"type":"object","description":"' + b"fixture " * 1300 + b'"}'
        schema_id_ = self.register(registry, executor, store, "LOCAL_INDEPENDENT_CAPTURE_SCHEMA_V1", 0, schema)
        host = self.deploy("StreamCollectionAttestations", (CONFIG,), ((core, registry,
            "0x" + "00" * 20, schema_id("local capture deployment"), "ipfs://local-fixture",
            schema_id("local capture manifest"), ("METADATA_ERC1271_VERIFY_GAS", 150000, 90000, 2),
            ("METADATA_DEPENDENCY_READ_GAS", 300000, 50000, 2)),))
        wallet = self.deploy("IndependentSignatureBoundary")
        accounts = self.rpc("eth_accounts", [])
        record_type = schema_id("INDEPENDENT_SEMANTIC_ASSERTION")
        now = int(self.rpc("eth_getBlockByNumber", ["latest", False])["timestamp"], 16)
        payload = dumps({"claim": "local independent fixture", "exactUint256": str((1 << 256) - 1),
                         "exactText": "A\r\n& < > \U0001f9ed", "language": None})

        def publish(subject, attestor, nonce, signature_kind="DIRECT"):
            sid, = self.read(host, "deriveSubject((uint8,uint256,uint256,bytes32))", (SUBJECT,), (subject,), ("bytes32",))
            request = (attestor, subject[1], sid, record_type, schema_id_, 1, hex_bytes(keccak256(payload)),
                       RAW_BYTES, "ipfs://local-independent-claim", payload, now, nonce, now + 86400)
            signature = b""
            if signature_kind == "ERC1271":
                digest, = self.read(host, "independentRecordDigest((address,uint256,bytes32,bytes32,bytes32,uint16,bytes,bytes32,string,bytes,uint64,uint256,uint64))",
                                   (REQUEST,), (request,), ("bytes32",))
                self.invoke(wallet, "set(bytes32,uint256)", ("bytes32", "uint256"), (digest, 0))
                signature = b"retained contract signature fixture"
            elif signature_kind == "EIP712":
                names = ("attestor", "scopeKey", "subjectId", "recordType", "schemaId", "algorithmId", "digest",
                         "canonicalizationId", "uri", "payload", "effectiveAt", "nonce", "deadline")
                message = {n: ("0x" + v.hex() if type(v) is bytes else str(v) if type(v) is int else v)
                           for n, v in zip(names, request)}
                typed = {"domain": {"name": "6529StreamCollectionAttestations", "version": "1", "chainId": "31337",
                                    "verifyingContract": host}, "primaryType": "StreamIndependentPreservationRecord",
                    "types": {"EIP712Domain": [{"name": n, "type": t} for n, t in
                        (("name", "string"), ("version", "string"), ("chainId", "uint256"), ("verifyingContract", "address"))],
                        "StreamIndependentPreservationRecord": [{"name": n, "type": t} for n, t in zip(names, REQUEST)]},
                    "message": message}
                signature = hex_bytes(self.rpc("eth_signTypedData_v4", [attestor, typed]))
            self.invoke(host, WRITE_SIGNATURE, (SUBJECT, REQUEST, "bytes"), (subject, request, signature),
                        sender=attestor if signature_kind == "DIRECT" else accounts[1])

        publish((0, 1, 0, ZERO), accounts[0], 0)
        publish((0, 1, 0, ZERO), accounts[1], 0)
        publish((0, 0, 0, ZERO), accounts[0], 1)
        self.invoke(core, "setLifecycle(uint8)", ("uint8",), (3,))
        publish((1, 1, 71, ZERO), accounts[0], (1 << 256) - 1, "EIP712")
        publish((2, 1, 0, schema_id("declared media fixture")), wallet, 3, "ERC1271")
        transition = self.read(registry, "statusTransition(bytes32,uint8)", ("bytes32", "uint8"),
                               (schema_id_, 2), ("bytes32",) * 3)
        self.invoke(executor, "execute(address,bytes,bytes32,bytes32,bytes32,uint8)",
                    ("address", "bytes", "bytes32", "bytes32", "bytes32", "uint8"),
                    (registry, hex_bytes(calldata("setDocumentStatus(bytes32,uint8)", ("bytes32", "uint8"), (schema_id_, 2))),
                     *transition, 1))
        publish((0, 1, 0, ZERO), accounts[0], 2)
        # The old wallet now refuses every signature; history must still export.
        self.invoke(wallet, "set(bytes32,uint256)", ("bytes32", "uint256"), (ZERO, 1))
        block = self.rpc("eth_getBlockByNumber", ["latest", False])
        addresses = list(dict.fromkeys([host, core, registry, store, *self.addresses.values()]))
        evidence = dumps({"kind": "local_evm_fixture", "artifacts": self.artifact_rows,
                          "transactions": self.receipts, "boundaries": ["IndependentCoreBoundary",
                              "IndependentExecutorBoundary", "IndependentSignatureBoundary"],
                          "hostGovernanceAuthority": "0x" + "00" * 20})
        anchor = dumps({"profile": PROFILE, "chainId": "31337", "blockHash": block["hash"],
            "blockNumber": str(int(block["number"], 16)), "timestamp": str(int(block["timestamp"], 16)),
            "stateRoot": block["stateRoot"], "environment": "local_evm_fixture",
            "deploymentEvidenceHash": keccak256(evidence), "host": host, "core": core,
            "schemas": registry, "store": store, "codePins": [{"address": address,
                "runtimeHash": keccak256(hex_bytes(self.rpc("eth_getCode", [address, "latest"])))} for address in addresses],
            "lanes": [{"scopeKey": str(scope), "recordType": record_type} for scope in (0, 1, 2)]})
        return anchor, evidence


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifacts", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--anvil", default="anvil")
    parser.add_argument("--publications", action="store_true", help="Also retain exact receipt/header publication evidence")
    parser.add_argument("--semantics", action="store_true", help="Publish and project canonical account-authored semantic records")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
    endpoint = "http://127.0.0.1:" + str(port)
    with (args.output / "anvil.log").open("wb") as log:
        process = subprocess.Popen([args.anvil, "--host", "127.0.0.1", "--port", str(port), "--chain-id", "31337",
                                    "--hardfork", "shanghai", "--gas-limit", "30000000", "--silent"],
                                   stdout=log, stderr=subprocess.STDOUT,
                                   creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
        try:
            for _ in range(100):
                try:
                    fixture = LocalFixture(args.artifacts, endpoint)
                    break
                except OSError:
                    require(process.poll() is None, "isolated Anvil exited")
                    time.sleep(0.05)
            else:
                raise RuntimeError("isolated Anvil did not start")
            try:
                anchor, evidence = fixture.build()
                if args.semantics:
                    from .local_account_fixture import publish_semantics
                    anchor, evidence = publish_semantics(fixture, anchor, evidence)
            except Exception:
                (args.output / "failed-rehearsal-transactions.json").write_bytes(dumps({
                    "environment": "local_evm_fixture", "transactions": fixture.receipts,
                    "artifacts": fixture.artifact_rows}))
                raise
            (args.output / "anchor.json").write_bytes(anchor)
            (args.output / "deployment-evidence.json").write_bytes(evidence)
            adapter = IndependentSourceAdapter(anchor, RpcTransport(endpoint), provenance="trusted_rpc")
            snapshot = adapter.snapshot()
            transcript = adapter.reader.transcript()
            (args.output / "transcript.json").write_bytes(transcript)
            (args.output / "source-capture.json").write_bytes(snapshot)
            replay = IndependentSourceAdapter(anchor, ReplayTransport(transcript, keccak256(transcript)), provenance="trusted_rpc")
            require(replay.snapshot() == snapshot, "offline replay byte parity")
            if args.publications or args.semantics:
                from .independent_publication import EVENT_DATA, EVENT_TOPIC, PROFILE as PUBLICATION_PROFILE, IndependentPublicationAdapter
                captured = json.loads(snapshot)
                selected = {r["recordHash"] for r in captured["records"]}
                hints = []
                for tx in fixture.receipts:
                    for event in tx["receipt"]["logs"]:
                        if event["address"] == adapter.a["host"] and event["topics"] and event["topics"][0] == EVENT_TOPIC:
                            h = decode(EVENT_DATA, hex_bytes(event["data"]))[1]
                            if h in selected:
                                hints.append({"recordHash": h, "transactionHash": tx["transactionHash"]})
                hints_raw = dumps({"profile": PUBLICATION_PROFILE, "records": hints})
                publication = IndependentPublicationAdapter(adapter, hints_raw, RpcTransport(endpoint), provenance="trusted_rpc")
                try:
                    publication_bytes = publication.snapshot()
                except Exception:
                    (args.output / "failed-publication-transcript.json").write_bytes(publication.reader.transcript())
                    (args.output / "publication-hints.json").write_bytes(hints_raw)
                    raise
                publication_transcript = publication.reader.transcript()
                (args.output / "publication-hints.json").write_bytes(hints_raw)
                (args.output / "publication-transcript.json").write_bytes(publication_transcript)
                (args.output / "publications.json").write_bytes(publication_bytes)
                publication_replay = IndependentPublicationAdapter(replay, hints_raw,
                    ReplayTransport(publication_transcript, keccak256(publication_transcript)), provenance="trusted_rpc")
                require(publication_replay.snapshot() == publication_bytes, "publication replay byte parity")
                if args.semantics:
                    from .local_account_fixture import capture_semantics
                    capture_semantics(publication, publication_replay, endpoint, args.output)
            print(dumps({"status": "PASS", "environment": "local_evm_fixture", "captureHash": keccak256(snapshot),
                         "transcriptHash": keccak256(transcript), "deploymentEvidenceHash": keccak256(evidence)}).decode())
        finally:
            process.terminate()
            process.wait(timeout=10)


if __name__ == "__main__":
    main()
