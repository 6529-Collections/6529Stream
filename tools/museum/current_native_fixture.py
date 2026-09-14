"""Real current native products and official Safe calls for isolated museum captures.

All executable products come from an explicit SHA-256-pinned artifact manifest.
No compiler, code replacement, storage edits, impersonation or remote RPC input.
"""
import hashlib
import json
from pathlib import Path

from .canonical import dumps, hex_bytes, keccak256
from .chain_abi import Array, calldata, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, require
from .local_independent_fixture import LocalFixture


def abi_kind(row):
    kind = row["type"]
    if kind.endswith("[]"):
        return Array(abi_kind(row | {"type": kind[:-2]}), 4096)
    if kind == "tuple": return tuple(abi_kind(c) for c in row["components"])
    require(kind == "address" or kind in ("bool", "bytes", "string") or kind.startswith(("uint", "bytes")), "unsupported capture ABI type")
    return kind


def abi_name(row):
    kind = row["type"]
    if kind.endswith("[]"): return abi_name(row | {"type": kind[:-2]}) + "[]"
    return "(" + ",".join(abi_name(c) for c in row["components"]) + ")" if kind == "tuple" else kind


def patch_links(code, references, resolve):
    require(isinstance(code, str) and len(code.removeprefix("0x")) % 2 == 0, "malformed native bytecode")
    code = code.removeprefix("0x")
    used, links = set(), {}
    for source, libraries in references.items():
        for library, positions in libraries.items():
            address = resolve(source, library)
            hex_bytes(address, 20)
            links[source + ":" + library] = address
            for position in positions:
                start, length = position["start"], position["length"]
                require(type(start) is int and type(length) is int and length == 20 and start >= 0 and (start + 20) * 2 <= len(code), "invalid native link offset")
                span = set(range(start, start + 20))
                require(not used & span, "overlapping native links")
                used |= span
                code = code[:start * 2] + address[2:] + code[(start + 20) * 2:]
    raw = hex_bytes("0x" + code)
    require(raw, "empty/unresolved native bytecode")
    return raw, links


class CurrentNativeFixture(LocalFixture):
    def __init__(self, manifest_path, endpoint, *, expected_manifest_sha256):
        self.manifest_raw = Path(manifest_path).read_bytes()
        require(hashlib.sha256(self.manifest_raw).hexdigest() == expected_manifest_sha256, "native manifest hash changed before capture")
        self.manifest = json.loads(self.manifest_raw)
        super().__init__(Path(manifest_path).parent, endpoint)
        require(self.manifest["mode"] == "current_museum_native_products_v1", "wrong native capture manifest")
        self.products = {}
        for name, row in self.manifest["products"].items():
            raw = Path(row["artifact"]).read_bytes()
            require(hashlib.sha256(raw).hexdigest() == row["sha256"], "native artifact hash mismatch: " + name)
            artifact = json.loads(raw)
            require(isinstance(artifact["abi"], list), "native ABI missing")
            require(artifact["metadata"]["settings"]["compilationTarget"] == {row["source"]: name}, "native source/contract identity differs")
            self.products[name] = artifact
        self.deploying = set()
        self.safe_accounts = {}

    def read(self, target, signature, kinds=(), values=(), outputs=()):
        # Native genesis plans are larger than ordinary museum view responses.
        result = self.rpc("eth_call", [{"to": target, "data": calldata(signature, kinds, values)}, "latest"])
        return decode(outputs, hex_bytes(result), maximum=1048576)

    def function(self, name, function):
        found = [r for r in self.products[name]["abi"] if r["type"] == "function" and
                 (r["name"] == function or r["name"] + "(" + ",".join(abi_name(c) for c in r.get("inputs", [])) + ")" == function)]
        require(len(found) == 1, "ambiguous/missing native function " + name + ":" + function)
        row = found[0]
        return row["name"] + "(" + ",".join(abi_name(c) for c in row.get("inputs", [])) + ")", tuple(abi_kind(c) for c in row.get("inputs", [])), tuple(abi_kind(c) for c in row.get("outputs", []))

    def data(self, name, function, values=()):
        signature, kinds, _ = self.function(name, function)
        identifiers = self.products[name]["methodIdentifiers"]
        candidates = ([identifiers[signature]] if signature in identifiers else
            [value for key, value in identifiers.items() if key.split("(")[0] == signature.split("(")[0]])
        require(len(candidates) == 1, "ambiguous/missing compiler selector")
        selector = hex_bytes("0x" + candidates[0], 4)
        return "0x" + (selector + encode(kinds, values)).hex()

    def call(self, name, function, values=()):
        _, _, outputs = self.function(name, function)
        result = self.rpc("eth_call", [{"to": self.addresses[name], "data": self.data(name, function, values)}, "latest"])
        return decode(outputs, hex_bytes(result), maximum=1048576)

    def transact(self, name, function, values=(), *, safe=None):
        data = self.data(name, function, values)
        return self.safe_call(safe, self.addresses[name], data) if safe else self.send(data, self.addresses[name])

    def deploy(self, name, values=()):
        if name in self.addresses:
            require(not values, "native constructor cannot be silently replaced")
            return self.addresses[name]
        require(name in self.products and name not in self.deploying, "missing/cyclic native product: " + name)
        self.deploying.add(name)
        artifact = self.products[name]
        def resolve(source, library):
            require(self.manifest["products"].get(library, {}).get("source") == source, "native library source mismatch")
            return self.deploy(library)
        creation, links = patch_links(artifact["bytecode"]["object"], artifact["bytecode"]["linkReferences"], resolve)
        ctor = [r for r in artifact["abi"] if r["type"] == "constructor"]
        require(len(ctor) <= 1, "duplicate native constructor")
        kinds = tuple(abi_kind(c) for c in ctor[0].get("inputs", [])) if ctor else ()
        arguments = encode(kinds, values)
        receipt = self.send("0x" + (creation + arguments).hex())
        address = receipt["contractAddress"]
        runtime = hex_bytes(self.rpc("eth_getCode", [address, "latest"]))
        expected, runtime_links = patch_links(artifact["deployedBytecode"]["object"], artifact["deployedBytecode"]["linkReferences"], resolve)
        require(0 < len(runtime) == len(expected) <= 24576, "native deployed-code size mismatch")
        immutable_bytes = set()
        immutable_values = {}
        for identifier, positions in artifact["deployedBytecode"].get("immutableReferences", {}).items():
            observed = set()
            for position in positions:
                start, length = position["start"], position["length"]
                require(type(start) is int and type(length) is int and start >= 0 and length == 32 and start + length <= len(runtime), "native immutable offset")
                span = set(range(start, start + length))
                require(not immutable_bytes & span, "overlapping native immutables")
                immutable_bytes |= span
                observed.add(runtime[start:start + length])
            require(len(observed) == 1, "native immutable occurrences disagree")
            immutable_values[identifier] = "0x" + next(iter(observed)).hex()
        # Solidity's declared library self-address guard is the sole non-immutable constructor patch.
        if expected.startswith(bytes.fromhex("73" + "00" * 20 + "3014")):
            require(runtime[1:21] == hex_bytes(address, 20), "native library self-address mismatch")
            immutable_bytes.update(range(1, 21))
        require(all(a == b or i in immutable_bytes for i, (a, b) in enumerate(zip(runtime, expected))), "native runtime differs outside declared patches")
        self.addresses[name] = address
        self.deploying.remove(name)
        self.artifact_rows[name] = self.manifest["products"][name] | {"address": address, "links": links,
            "runtimeLinks": runtime_links, "constructorArgumentsHex": "0x" + arguments.hex(),
            "creationHash": keccak256(creation + arguments), "runtimeHash": keccak256(runtime),
            "runtimeBytes": str(len(runtime)), "immutableValues": immutable_values}
        return address

    def safe(self, salt):
        if not hasattr(self, "safe_components"):
            row = self.manifest["safeFixture"]
            raw = Path(row["path"]).read_bytes()
            require(hashlib.sha256(raw).hexdigest() == row["sha256"], "official Safe fixture hash mismatch")
            fixture = json.loads(raw)
            self.safe_components = {}
            for key in ("singleton", "factory", "handler"):
                tx = self.send(fixture[key]["creationCode"])
                address = tx["contractAddress"]
                require(self.rpc("eth_getCode", [address, "latest"]).lower() == fixture[key]["runtimeCode"].lower(), "official Safe component runtime mismatch")
                self.safe_components[key] = address
        components = self.safe_components
        owners = sorted(self.rpc("eth_accounts", [])[1:3])
        initializer = calldata("setup(address[],uint256,address,bytes,address,address,uint256,address)",
            (Array("address"), "uint256", "address", "bytes", "address", "address", "uint256", "address"),
            (owners, 2, ZERO_ADDRESS, b"", components["handler"], ZERO_ADDRESS, 0, ZERO_ADDRESS))
        receipt = self.invoke(components["factory"], "createProxyWithNonce(address,bytes,uint256)",
            ("address", "bytes", "uint256"), (components["singleton"], hex_bytes(initializer), salt))
        topic = keccak256(b"ProxyCreation(address,address)")
        log = next(r for r in receipt["logs"] if r["address"] == components["factory"] and r["topics"][0] == topic)
        require(len(log["topics"]) == 2 and decode(("address",), hex_bytes(log["data"])) == (components["singleton"],), "official Safe creation event mismatch")
        address = decode(("address",), hex_bytes(log["topics"][1]))[0]
        require(self.read(address, "getThreshold()", outputs=("uint256",))[0] == 2, "official Safe threshold mismatch")
        require(set(self.read(address, "getOwners()", outputs=(Array("address"),))[0]) == set(owners), "official Safe owners mismatch")
        self.safe_accounts[address] = owners
        return address

    def safe_call(self, safe, target, data):
        """Real two-owner approveHash then Safe CALL; no fake signatures or signer impersonation."""
        nonce = self.read(safe, "nonce()", outputs=("uint256",))[0]
        kinds = ("address", "uint256", "bytes", "uint8", "uint256", "uint256", "uint256", "address", "address", "uint256")
        values = (target, 0, hex_bytes(data), 0, 0, 0, 0, ZERO_ADDRESS, ZERO_ADDRESS, nonce)
        digest = self.read(safe, "getTransactionHash(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,uint256)", kinds, values, ("bytes32",))[0]
        signatures = b""
        for owner in self.safe_accounts[safe]:
            self.invoke(safe, "approveHash(bytes32)", ("bytes32",), (digest,), sender=owner)
            signatures += bytes(12) + hex_bytes(owner, 20) + bytes(32) + b"\x01"
        result = self.invoke(safe, "execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)",
            kinds[:-1] + ("bytes",), values[:-1] + (signatures,))
        require(self.read(safe, "nonce()", outputs=("uint256",))[0] == nonce + 1, "actual Safe nonce did not advance once")
        return result

    def store_payload(self, data):
        require(0 < len(data) <= 24575, "native data carrier size")
        receipt = self.send("0x600b5981380380925939f300" + data.hex())
        pointer = receipt["contractAddress"]
        require(self.rpc("eth_getCode", [pointer, "latest"]) == "0x00" + data.hex(), "native data carrier readback")
        return pointer
