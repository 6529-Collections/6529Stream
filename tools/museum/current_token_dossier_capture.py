"""Versioned actual-token dossier recipe on one Coordinator-owned local chain.

The capture command writes real fixture transactions to an explicitly supplied
fresh loopback chain. It never starts/stops Anvil or replaces deployed code/state.
The separate native_dossier_capture runner remains entirely read-only.
"""
import argparse
import hashlib
import os
from pathlib import Path
import re
import urllib.parse

from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree, write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .chain_history import MAX_BLOCKS
from .chain_rpc import RpcTransport
from .current_museum_capture import capture as capture_original
from .current_token_capture import CurrentTokenFixture
from .independent_wire import require
from . import native_dossier_capture as runner
from . import object_dossier as base
from . import owner_catalog_source, independent_catalog_source, metadata_catalog_source
from . import ownership_source, dossier_hosts_source
from .token_dossier_publications import TokenDossierPublicationsMixin
from .token_fixture import retain

RECIPE = "STREAM_MUSEUM_CURRENT_TOKEN_NATIVE_DOSSIER_RECIPE_V1"
QUALIFICATION = ("New local actual-token composition with registered OwnerRecords and independent hosts, "
    "direct-buyer owner publication, selected Metadata Safe publication and independent deployment/collection scopes. "
    "Original controlled entropy, synthetic authority snapshot and self-review remain explicit. "
    "This bounded RPC/source exercise does not establish whole-v1 conformance, global host completeness, "
    "consensus, legal title, institutional acceptance or public deployment readiness.")
EXTRA_HOSTS = ("StreamOwnerRecords", "StreamCollectionMetadataV1", "StreamArtistOnboardingRegistry",
               "StreamModuleRegistry")


def local_endpoint(endpoint):
    try:
        parsed = urllib.parse.urlsplit(endpoint)
        port = parsed.port
    except (TypeError, ValueError):
        raise MuseumError("coordinated fixture endpoint is invalid") from None
    require(parsed.scheme == "http" and parsed.hostname == "127.0.0.1"
            and port is not None and 0 < port < 65536 and not parsed.username and not parsed.password
            and not parsed.query and not parsed.fragment and parsed.path in ("", "/"),
            "coordinated fixture requires an explicit credential-free loopback port")
    return endpoint


def bind_fresh_chain(fixture, genesis_hash):
    """Read-only admission of the Coordinator's exact new chain before any writes."""
    require(any(hex_bytes(genesis_hash, 32)), "coordinated genesis commitment is empty")
    require(fixture.rpc("eth_chainId", []) == "0x7a69", "coordinated fixture requires chain 31337")
    block = fixture.rpc("eth_getBlockByNumber", ["latest", False])
    require(type(block) is dict and block.get("hash") == genesis_hash and block.get("number") == "0x0"
            and block.get("parentHash") == "0x" + "00" * 32 and block.get("transactions") == [],
            "coordinated chain is not the pinned fresh genesis")
    require(fixture.rpc("eth_getBlockByHash", [genesis_hash, False]) == block,
            "coordinated genesis changed during admission")
    require(fixture.rpc("eth_getTransactionCount", [fixture.account, {"blockHash": genesis_hash,
            "requireCanonical": True}]) == "0x0", "coordinated fixture deployer is not fresh")
    fixture.coordinated_genesis_hash = genesis_hash


class CurrentTokenDossierFixture(TokenDossierPublicationsMixin, CurrentTokenFixture):
    def __init__(self, manifest_path, endpoint, *, expected_manifest_sha256, source_revision):
        local_endpoint(endpoint)
        require(type(source_revision) is str and re.fullmatch(r"[0-9a-f]{40}", source_revision) is not None,
                "dossier recipe requires an immutable source revision")
        # Check composition admission before CurrentNativeFixture's account read.
        with Path(manifest_path).open("rb") as handle:
            raw = handle.read(MAX_BYTES + 1)
        require(len(raw) <= MAX_BYTES, "dossier recipe native manifest bound")
        require(hashlib.sha256(raw).hexdigest() == expected_manifest_sha256, "dossier recipe native manifest differs")
        manifest = loads(raw, maximum=MAX_BYTES, canonical=True)
        require(type(manifest) is dict, "dossier recipe native manifest shape")
        composition = manifest.get("tokenDossierComposition", {})
        require(type(composition) is dict and type(composition.get("claims")) is dict
                and composition.get("version") == "1" and composition.get("sourceRevision") == source_revision
                and composition.get("claims", {}).get("compilerMetadataSourceCorrespondence") is True
                and composition.get("joinedCaptureStatus") == "not_run"
                and "StreamOwnerRecords" in manifest.get("products", {}),
                "dossier recipe requires source-bound OwnerRecords composition")
        self.dossier_source_revision = source_revision
        super().__init__(manifest_path, endpoint, expected_manifest_sha256=expected_manifest_sha256)

    def after_media_publications(self):
        # Preserve the exact original media/authority source and export route.
        super().after_media_publications()
        self.publish_native_dossier_records()

    def capture_code_addresses(self):
        return sorted(set(super().capture_code_addresses()) | {self.addresses[name] for name in EXTRA_HOSTS})

    def build_media(self):
        require(hasattr(self, "coordinated_genesis_hash"), "coordinated fresh-chain admission is required")
        bind_fresh_chain(self, self.coordinated_genesis_hash)
        anchor_raw, evidence_raw = super().build_media()
        anchor = loads(anchor_raw, maximum=524288, canonical=True)
        evidence = loads(evidence_raw, maximum=MAX_BYTES, canonical=True)
        require(uint(anchor["blockNumber"]) < MAX_BLOCKS,
                "dossier recipe exceeded complete-history source bound")
        evidence.update(workflow=RECIPE, qualification=QUALIFICATION,
            tokenDossierComposition=self.manifest["tokenDossierComposition"],
            tokenDossierRecords=self.native_dossier_records,
            coordinatedGenesisHash=self.coordinated_genesis_hash)
        evidence_raw = dumps(evidence)
        anchor["deploymentEvidenceHash"] = keccak256(evidence_raw)
        block_ref = {"blockHash": anchor["blockHash"], "requireCanonical": True}
        anchor["codePins"] = [{"address": address,
            "runtimeHash": keccak256(hex_bytes(self.rpc("eth_getCode", [address, block_ref])))}
            for address in self.capture_code_addresses()]
        require(self.rpc("eth_getBlockByNumber", ["latest", False])["hash"] == anchor["blockHash"],
                "coordinated source changed during final pinning")
        return dumps(anchor), evidence_raw

    def export_capture(self, source, output):
        result = super().export_capture(source, output)
        path = Path(output) / "token-result.json"
        value = loads(path.read_bytes(), maximum=65536, canonical=True)
        # The frozen retained-token format already permits a qualification string.
        value["qualification"] = QUALIFICATION
        path.write_bytes(dumps(value))
        return result


def make_plan(fixture, anchor_raw, evidence_raw, base_manifest):
    """Construct all six explicit anchors from recorded final-state bindings; no RPC."""
    anchor = loads(anchor_raw, maximum=524288, canonical=True)
    evidence = loads(evidence_raw, maximum=MAX_BYTES, canonical=True)
    manifest = loads(base_manifest, maximum=MAX_MANIFEST, canonical=True)
    state = manifest["sourceState"]
    require(anchor["deploymentEvidenceHash"] == keccak256(evidence_raw)
            and evidence.get("workflow") == RECIPE
            and evidence.get("nativeInputManifestSha256") == hashlib.sha256(fixture.manifest_raw).hexdigest()
            and evidence.get("tokenDossierComposition") == fixture.manifest["tokenDossierComposition"],
            "dossier plan original deployment/composition differs")
    require(all(state[k] == anchor[k] for k in ("chainId", "core", "blockNumber", "blockHash"))
            and state["tokenId"] == fixture.token_scope.token_id
            and state["collectionId"] == fixture.token_scope.collection_id,
            "dossier plan base source identity differs")
    common = {k: anchor[k] for k in ("chainId", "core", "blockHash", "blockNumber", "timestamp",
                                    "stateRoot", "environment", "deploymentEvidenceHash")}
    pins = {row["address"]: row["runtimeHash"] for row in anchor["codePins"]}
    require(len(pins) == len(anchor["codePins"]), "dossier plan duplicate runtime pin")
    core = common | {"coreRuntimeHash": pins[anchor["core"]], "tokenId": state["tokenId"],
                     "collectionId": state["collectionId"]}
    def catalog(kind, host_name, scope, profile):
        addresses = {"host": fixture.addresses[host_name], "core": anchor["core"],
                     "schemas": fixture.schemas, "store": fixture.store}
        if kind == "metadata": addresses["artistRegistry"] = fixture.addresses["StreamArtistOnboardingRegistry"]
        require(set(addresses.values()) <= pins.keys(), "dossier plan original dependency runtime pin missing")
        return common | addresses | {"profile": profile, **scope,
            "codePins": [{"address": address, "runtimeHash": pins[address]} for address in sorted(set(addresses.values()))]}
    rows = [
        ("hosts", "hosts", core | {"profile": dossier_hosts_source.PROFILE}),
        ("independent-collection", "independent", catalog("independent", "StreamCollectionAttestations",
            {"scopeKey": state["collectionId"]}, independent_catalog_source.PROFILE)),
        ("independent-deployment", "independent", catalog("independent", "StreamCollectionAttestations",
            {"scopeKey": "0"}, independent_catalog_source.PROFILE)),
        ("metadata", "metadata", catalog("metadata", "StreamCollectionMetadataV1",
            {"collectionId": state["collectionId"]}, metadata_catalog_source.PROFILE)),
        ("owner", "owner", catalog("owner", "StreamOwnerRecords", {"tokenId": state["tokenId"]}, owner_catalog_source.PROFILE)),
        ("ownership", "ownership", core | {"profile": ownership_source.PROFILE}),
    ]
    return dumps({"profile": runner.PLAN, "version": "1", "disclosure": "public",
        "baseManifestHash": keccak256(base_manifest), "sourceRevision": fixture.dossier_source_revision,
        "nativeInputManifestSha256": hashlib.sha256(fixture.manifest_raw).hexdigest(),
        "sources": [{"id": identifier, "kind": kind, "anchor": a} for identifier, kind, a in rows]})


def require_recipe_coverage(fixture, files):
    """Bind the recipe's actual publication hashes to replayed original occurrences."""
    report = loads(files["assembly/native/joins.json"], maximum=MAX_BYTES, canonical=True)
    hashes = fixture.native_dossier_records["recordHashes"]
    token, collection = fixture.token_scope.token_id, fixture.token_scope.collection_id
    owner, metadata, independent = (fixture.addresses[name] for name in
        ("StreamOwnerRecords", "StreamCollectionMetadataV1", "StreamCollectionAttestations"))
    expected = {(owner, token, hashes["owner"]), (metadata, collection, hashes["metadata"]),
                (independent, "0", hashes["independent"])}
    actual = {(r["host"], r["scopeKey"], r["recordHash"]) for r in report["occurrences"]}
    require(expected <= actual and any(host == independent and scope == collection for host, scope, _ in actual),
            "dossier recipe publication occurrence missing from native replay")
    covered = {(row["host"], row["scopeKey"]) for row in report["scopeCoverage"]
               if row["status"] == "verified_within_registered_roster"}
    require({(owner, token), (metadata, collection), (independent, "0"), (independent, collection)} <= covered,
            "dossier recipe registered scope missing from native replay")
    require({row["kind"] for row in report["checks"] if row["status"] == "verified_within_source_profile"}
            == set(runner.native.KINDS), "dossier recipe source checks incomplete")


def capture(fixture, output, *, genesis_hash):
    """Execute only on an explicitly coordinated fresh chain, then retain/replay it."""
    require(type(fixture) is CurrentTokenDossierFixture, "versioned actual-token dossier fixture required")
    output = Path(output)
    require(not output.exists(), "dossier capture output already exists")
    for path in (output, *output.parents):
        require(not path.is_symlink() and not (hasattr(path, "is_junction") and path.is_junction()),
                "dossier capture output parent links are unsupported")
    bind_fresh_chain(fixture, genesis_hash)
    output.mkdir(parents=True, exist_ok=False)
    original = output / "original-token-capture"
    original.mkdir()
    (original / "native-inputs.json").write_bytes(fixture.manifest_raw)
    fixture.token_capture_output = original
    try:
        capture_original(fixture, original)
        retained = output / "retained-token"
        retained_hash = retain(original, retained)
        base_result = base.assemble(read_tree(retained), retained_hash)
        write_tree(dict(base_result.files), output / "base-assembly")
        plan = make_plan(fixture, (original / "anchor.json").read_bytes(),
                         (original / "deployment-evidence.json").read_bytes(), base_result.manifest)
        plan_hash = keccak256(plan)
        (output / "native-plan.json").write_bytes(plan)
        files = runner.capture(plan, plan_hash, dict(base_result.files), RpcTransport(fixture.endpoint))
        require_recipe_coverage(fixture, files)
        result_hash = keccak256(files["result.json"])
        write_tree(files, output / "native-dossier")
        summary = {"recipe": RECIPE, "version": "1", "sourceRevision": fixture.dossier_source_revision,
            "genesisHash": genesis_hash, "sourceState": loads(base_result.manifest, maximum=MAX_MANIFEST)["sourceState"],
            "retainedTokenManifestHash": retained_hash, "baseManifestHash": base_result.manifest_hash,
            "nativePlanHash": plan_hash, "nativeCaptureResultHash": result_hash,
            "actualNativeCaptureAcceptance": False, "fullObjectDossierConformance": False,
            "globalApplicableHostsComplete": False, "qualification": QUALIFICATION}
        (output / "recipe-result.json").write_bytes(dumps(summary))
        return summary
    finally:
        # Exact public local transactions/artifact bindings, including a failed run.
        (output / "execution-journal.json").write_bytes(dumps({"recipe": RECIPE,
            "transactions": fixture.receipts, "artifacts": fixture.artifact_rows}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native-manifest", type=Path, required=True)
    parser.add_argument("--native-manifest-sha256", required=True)
    parser.add_argument("--source-revision", required=True)
    parser.add_argument("--rpc-env", required=True)
    parser.add_argument("--genesis-hash", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--disclosure", choices=("public",), required=True)
    args = parser.parse_args()
    try:
        endpoint = os.environ.get(args.rpc_env)
        require(endpoint is not None, "coordinated RPC environment variable is absent")
        fixture = CurrentTokenDossierFixture(args.native_manifest, local_endpoint(endpoint),
            expected_manifest_sha256=args.native_manifest_sha256, source_revision=args.source_revision)
        result = capture(fixture, args.output, genesis_hash=args.genesis_hash)
    except (MuseumError, OSError, KeyError, TypeError, ValueError):
        parser.exit(1, "Coordinated dossier recipe failed; retain the local journal and inspect its pinned prerequisites.\n")
    print(dumps(result).decode())


if __name__ == "__main__":
    main()
