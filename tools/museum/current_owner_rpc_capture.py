"""Coordinate one actual local mint, Safe ownership and owner/account dossier capture.

Requires separately authenticated native artifacts. Pure and transport-double
tests do not establish that this joined RPC composition has executed.
"""
import base64
import hashlib
import re
from pathlib import Path

from .canonical import dumps, hex_bytes, keccak256, schema_id
from .chain_abi import Array, encode
from .chain_rpc import RpcTransport
from .current_museum_capture import CurrentMuseumFixture, capture as capture_media, main as run_main
from .current_owner_capture import (HOST, QUALIFICATION as OWNER_QUALIFICATION,
    publish_owner_records, make_owner_anchor, capture_owner_evidence, export_owner_dossier)
from .current_rights_capture import CurrentRightsFixture
from .current_owner_rpc_commerce import OwnerCommerceMixin
from . import current_owner_registry_capture as registry_capture
from .independent_wire import DOCUMENT_SPEC, RAW_BYTES, ZERO, require
from .token_governance import TokenGovernanceMixin
from .token_mint_flow import TOKEN_MODULE_ROWS, TOKEN_PRODUCT_ROOTS, TokenMintFlowMixin
from .token_native_graph import TokenNativeGraphMixin

OWNER_PRODUCT_ROOTS = tuple(sorted(set(TOKEN_PRODUCT_ROOTS) | {
    HOST, "StreamCollectionAttestations", "StreamIndependentReads", "StreamConservationFloor",
    "IStreamDirectPrimarySaleReceipt"}))
OWNER_MANIFEST = b"public local owner dossier recipe"
TRANSFER_EVENT = keccak256(b"Transfer(address,address,uint256)")
QUALIFICATION = ("New isolated local composition of explicitly pinned native products. "
    "Actual paid mint to an EOA, separate transfer to an official Safe, and recorded "
    "account/owner statements share one final anchor. Controlled local entropy only; "
    "no full graph, institutional, public deployment or consensus acceptance. " + OWNER_QUALIFICATION)


def document_input(name, kind, raw, canonical, supersedes=ZERO):
    """Original registry specification and ordered chunks; no alternative encoding."""
    require(isinstance(name, str) and re.fullmatch(r"[A-Za-z0-9_.-]{1,128}", name)
        and type(kind) is int and 0 <= kind <= 3
        and isinstance(raw, bytes) and 0 < len(raw) <= 524288, "owner document shape")
    require(hex_bytes(canonical, 32) != bytes(32), "owner canonicalization missing")
    hex_bytes(supersedes, 32)
    parts = tuple(raw[i:i + 8192] for i in range(0, len(raw), 8192))
    chunks = tuple(keccak256(part) for part in parts)
    spec = (name, kind, keccak256(raw), canonical, supersedes, "", len(raw))
    return spec, chunks, parts


class CurrentOwnerRpcFixture(OwnerCommerceMixin, TokenGovernanceMixin, TokenNativeGraphMixin,
                             TokenMintFlowMixin, CurrentMuseumFixture):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.require_owner_products()

    def require_owner_products(self):
        require(set(OWNER_PRODUCT_ROOTS) <= self.products.keys(), "owner native root products missing")
        require("graphImmutableProjection" in self.manifest, "owner native graph projection missing")
        # Check the entire explicit link closure before sending any deployment.
        pending, seen = list(OWNER_PRODUCT_ROOTS), set()
        while pending:
            name = pending.pop()
            if name in seen:
                continue
            seen.add(name)
            require(name in self.products, "owner linked native product missing: " + name)
            product = self.products[name]
            require("ast" in product, "owner same-native AST missing: " + name)
            for field, limit in (("bytecode", 49152), ("deployedBytecode", 24576)):
                code = product[field]["object"].removeprefix("0x")
                require(len(code) % 2 == 0 and len(code) // 2 <= limit,
                    "owner native product exceeds original bound: " + name)
                for source, libraries in product[field]["linkReferences"].items():
                    for library in libraries:
                        require(self.manifest["products"].get(library, {}).get("source") == source,
                            "owner native link source differs")
                        pending.append(library)
        self.owner_native_roots = OWNER_PRODUCT_ROOTS

    def deploy_library_closure(self, names):
        # Reuse the existing ordinary-CREATE cyclic-library deployment method;
        # do not inherit its RIGHTS or preservation publication hooks.
        return CurrentRightsFixture.deploy_library_closure(self, names)

    def send(self, data, target=None, sender=None):
        if target is None:
            require(len(hex_bytes(data)) <= 49152, "owner full initcode exceeds original bound")
        return super().send(data, target, sender)

    def foundation(self):
        require(not getattr(self, "owner_foundation_started", False), "owner foundation already attempted")
        self.owner_foundation_started = True
        require(self.rpc("eth_chainId", []) == "0x7a69", "owner fixture is local chain 31337 only")
        super().foundation()
        self.build_token_artist_graph()
        self.select_token_modules([
            ("StreamArtistOnboardingRegistry", "ARTIST_REGISTRY", "IStreamArtistMintConsent"),
            ("StreamMetadataRouter", "METADATA_ROUTER", "IStreamMetadataRouter"),
            ("StreamCollectionMetadataV1", "COLLECTION_METADATA", "IStreamCollectionMetadataV1"),
        ])
        self.complete_token_artist_graph()
        self.deploy_token_sale_products()
        self.select_token_modules(TOKEN_MODULE_ROWS)
        self.configure_token_sale_products()
        self.prepare_owner_commerce()
        self.owner_safe = self.safe(791)
        self.mint_token()
        self.verify_owner_commerce()
        self.transfer_token_to_owner_safe()
        self.deploy_owner_records()

    def transfer_token_to_owner_safe(self):
        core, token, buyer, safe = self.addresses["StreamCore"], self.token_id, self.token_buyer, self.owner_safe
        require(safe in self.safe_accounts and len(self.safe_accounts[safe]) == 2
            and safe != buyer, "distinct controlled owner Safe required")
        require(self.call("StreamCore", "ownerOf", (token,)) == (buyer,), "mint buyer no longer owns token")
        data = self.data("StreamCore", "transferFrom(address,address,uint256)", (buyer, safe, token))
        receipt = self.send(data, core, sender=buyer)
        topics = [TRANSFER_EVENT, "0x" + encode(("address",), (buyer,)).hex(),
            "0x" + encode(("address",), (safe,)).hex(), "0x" + encode(("uint256",), (token,)).hex()]
        events = [row for row in receipt["logs"] if row["address"] == core and row["topics"] == topics]
        require(receipt["status"] == "0x1" and len(events) == 1 and events[0]["data"] == "0x",
            "actual owner transfer event differs")
        require(self.call("StreamCore", "ownerOf", (token,)) == (safe,)
            and self.call("StreamCore", "tokenCollectionIdentity", (token,)) == (True, 1, 1, False),
            "actual Safe token ownership differs")
        transaction = self.rpc("eth_getTransactionByHash", [receipt["transactionHash"]])
        require(transaction is not None and transaction["hash"] == receipt["transactionHash"]
            and transaction["from"] == buyer and transaction["to"] == core
            and transaction["input"] == data, "actual owner transfer transaction differs")
        self.owner_transfer = {"transaction": transaction, "receipt": receipt,
            "tokenId": str(token), "from": buyer, "to": safe}

    def deploy_owner_records(self):
        self.deploy_library_closure((HOST,))
        cid = "b" + base64.b32encode(b"\x01\x55\x12\x20" + hashlib.sha256(OWNER_MANIFEST).digest()).decode().lower().rstrip("=")
        config = (self.addresses["StreamCore"], self.schemas, self.addresses["StreamGovernanceExecutor"],
            self.deployment, "ipfs://" + cid, keccak256(OWNER_MANIFEST),
            ("METADATA_ERC1271_VERIFY_GAS", 400000, 90000, 2),
            ("METADATA_DEPENDENCY_READ_GAS", 300000, 50000, 2))
        self.deploy(HOST, (config,))
        self.require_owner_bindings()

    def require_owner_bindings(self):
        for getter, address in (("core", self.addresses["StreamCore"]),
                ("schemaRegistry", self.schemas), ("chunkStore", self.store),
                ("governanceAuthority", self.addresses["StreamGovernanceExecutor"])):
            require(self.call(HOST, getter) == (address,), "owner constructor binding differs: " + getter)
        for getter, address in (("coreCodeHash", self.addresses["StreamCore"]),
                ("schemaRegistryCodeHash", self.schemas), ("chunkStoreCodeHash", self.store),
                ("executorCodeHash", self.addresses["StreamGovernanceExecutor"])):
            code = hex_bytes(self.rpc("eth_getCode", [address, "latest"]))
            require(code and self.call(HOST, getter) == (keccak256(code),), "owner runtime binding differs: " + getter)
        require(self.call(HOST, "streamModuleType") == (schema_id("OWNER_RECORDS"),)
            and self.call(HOST, "streamModuleVersion") == (schema_id("6529stream.owner-records.v1"),),
            "owner module identity differs")

    def _exact_document(self, spec, chunks, parts):
        row, = self.call("StreamSchemaRegistry", "document", (schema_id(spec[0]),))
        if not row[0]:
            return False
        expected = encode((DOCUMENT_SPEC, Array("bytes32")), (spec, chunks))
        require(row[1] == 0 and row[2] == keccak256(expected)
            and encode((DOCUMENT_SPEC, Array("bytes32")), (row[3], row[4])) == expected,
            "conflicting or retired owner document")
        require(self.call("StreamSchemaRegistry", "chunkStore") == (self.store,)
            and self.call("StreamSchemaRegistry", "governanceAuthority") == (self.addresses["StreamGovernanceExecutor"],),
            "owner document graph differs")
        for digest, part in zip(chunks, parts):
            require(self.read(self.store, "readChunk(bytes32)", ("bytes32",), (digest,), ("bytes",)) == (part,),
                "owner registered ordered chunk differs")
        require(self.call("StreamSchemaRegistry", "documentBytes", (schema_id(spec[0]),)) == (b"".join(parts),),
            "owner registered document bytes differ")
        return True

    def register_document(self, name, kind, raw, canonical=RAW_BYTES, supersedes=ZERO):
        spec, chunks, parts = document_input(name, kind, raw, canonical, supersedes)
        if not self._exact_document(spec, chunks, parts):
            super().register_document(name, kind, raw, canonical, supersedes)
            require(self._exact_document(spec, chunks, parts), "owner document admission absent")
        return schema_id(name)

    def after_media_publications(self):
        require(not hasattr(self, "owner_publications"), "owner publication already attempted")
        # Retain an attempt marker even if one of the original calls fails.
        self.owner_publications = None
        self.require_owner_bindings()
        self.owner_publications = publish_owner_records(self, self.token_id, self.owner_safe)

    def capture_code_addresses(self):
        # Pin bounded reader inputs. All deployment products remain in artifact_rows.
        names = ("StreamCore", "StreamCollectionAttestations", "StreamSchemaRegistry", HOST,
            "StreamGovernanceExecutor")
        return sorted({self.store, *(self.addresses[name] for name in names), *self.safe_accounts})

    def extra_capture_evidence(self):
        require(self.owner_publications is not None, "owner publications incomplete")
        return {"workflow": "actual_current_owner_rpc_composition_v1", "qualification": QUALIFICATION,
            "boundaries": [{"component": "DevelopmentEntropyProvider", "kind": "controlled_local_oracle"}],
            "tokenMint": self.token_mint_evidence, "ownerTransfer": self.owner_transfer,
            "commerce": self.owner_commerce,
            "ownerRecords": self.owner_publications, "ownerSafe": self.owner_safe,
            "ownerManifestHex": "0x" + OWNER_MANIFEST.hex(), "nativeGraph": self.token_graph_evidence}


def capture(fixture, output):
    """All mutations precede the shared anchor; both RPC captures use this one process."""
    output = Path(output)
    account_hash = capture_media(fixture, output)
    require(fixture.owner_publications is not None, "owner capture publications missing")
    evidence = (output / "deployment-evidence.json").read_bytes()
    anchor = make_owner_anchor(fixture, (output / "anchor.json").read_bytes(), evidence,
        fixture.owner_publications["records"])
    plan = dumps({"version": "1", **{key: fixture.owner_publications[key]
        for key in ("loans", "valuations", "transactions")}})
    for name, raw in (("owner-anchor.json", anchor), ("owner-plan.json", plan)):
        with (output / name).open("xb") as stream:
            stream.write(raw)
    pins = {"accountHash": account_hash, "anchorHash": keccak256(anchor),
        "planHash": keccak256(plan), "deploymentEvidenceHash": keccak256(evidence)}
    with (output / "owner-input-pins.json").open("xb") as stream:
        stream.write(dumps(pins))
    captured = capture_owner_evidence(output / "package", account_hash, anchor, evidence, plan,
        plan_hash=pins["planHash"], transport=RpcTransport(fixture.endpoint), disclosure="public")
    result = export_owner_dossier(output / "package", account_hash, captured,
        output / "owner-dossier", disclosure="public")
    if getattr(fixture, "registry_bridge", None) is not None:
        registry_capture.capture_registry(fixture, output, account_hash, captured)
    return result["valuationManifestHash"]


def main():
    run_main(fixture_type=CurrentOwnerRpcFixture, capture_function=capture,
        configure_parser=configure_parser, prepare_arguments=registry_capture.prepare_arguments,
        configure_fixture=registry_capture.configure_fixture)


def configure_parser(parser):
    parser.description = __doc__
    registry_capture.configure_parser(parser)


if __name__ == "__main__":
    main()
