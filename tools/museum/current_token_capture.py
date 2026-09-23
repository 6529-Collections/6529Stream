"""New isolated actual token/media composition from pinned mint and Museum products."""
from datetime import datetime, timezone
import base64
import hashlib
from pathlib import Path
import urllib.request

from .account_profile import AccountProjectionProfile, JCS_ID, JCS_NAME, account_iri
from .canonical import dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import decode
from .current_archive_capture import CurrentArchiveFixture
from .current_authority_capture import (CurrentAuthorityFixture, configure_fixture, configure_parser,
    documentary_bytes, prepare_arguments, synthetic_snapshot)
from .current_media_inputs import image_bytes, media_description
from .current_museum_capture import ROOT, capture as capture_current, main as run_main
from .dossier import build_dossier, verify_dossier, verify_ocfl
from .bagit import write_tree
from .independent_source import PROFILE
from .independent_wire import RAW_BYTES, RAW_DEFINITION, ZERO, require
from .ocfl import build_version
from .package import write_package
from .schemas import NAMES as V1_NAMES
from .semantic_export import build_export, verify_export
from .token_governance import TokenGovernanceMixin
from .token_media_inputs import (token_alignment_payload, token_declaration_payload, token_payloads,
    token_review_payload, token_scope)
from .token_native_graph import TokenNativeGraphMixin
from .token_mint_flow import TokenMintFlowMixin, TOKEN_MODULE_ROWS
from .typed_authority_profile import NAMES

QUALIFICATION = ("New local joined deployment using exact pinned accepted mint-recipe products plus "
    "two explicitly version-bound Museum extension binaries. Actual Core mint and fresh token-subject "
    "Safe media statements; not previously accepted as a composition. Controlled local entropy, "
    "synthetic authority snapshot and self-review remain explicit. No external broadcast, secure "
    "randomness, consensus finality, publisher authentication, human qualification, or full "
    "OBJECT_DOSSIER_V1 acceptance is claimed.")


def verify_token_metadata(uri, token_id):
    prefix = "data:application/json;base64,"
    require(isinstance(uri, str) and uri.startswith(prefix) and len(uri) <= 1048576,
        "actual token metadata must be bounded native JSON")
    raw = base64.b64decode(uri[len(prefix):], validate=True)
    metadata = loads(raw, maximum=524288)
    require(isinstance(metadata, dict)
        and all(type(metadata.get(key)) is int for key in ("token_id", "collection_id", "collection_serial"))
        and metadata.get("image") == media_description(image_bytes())["uri"]
        and metadata.get("token_id") == token_id and metadata.get("collection_id") == 1
        and metadata.get("collection_serial") == 1, "actual token metadata identity/media differs")
    require(base64.b64decode(metadata.get("token_data_base64", ""), validate=True) == image_bytes(),
        "actual token metadata data bytes differ")
    return raw


class CurrentTokenFixture(TokenGovernanceMixin, TokenNativeGraphMixin, TokenMintFlowMixin, CurrentArchiveFixture):
    def rpc(self, method, params):
        """Retain bounded local errors without repeating a failed request."""
        request = urllib.request.Request(self.endpoint, data=dumps({
            "jsonrpc": "2.0", "id": 1, "method": method, "params": params}),
            headers={"Content-Type": "application/json"})
        maximum = 128 * 1024 * 1024 if method == "anvil_dumpState" else 8388608
        with urllib.request.urlopen(request, timeout=30) as response:
            value = loads(response.read(maximum + 1), maximum=maximum)
        if "error" in value:
            row = {"method": method, "params": params, "error": value["error"]}
            if hasattr(self, "token_capture_output"):
                (self.token_capture_output / "rpc-failure.json").write_bytes(dumps(row))
            require(False, "local token fixture RPC failure: " + method + " " + str(value["error"])[:2048])
        return value["result"]

    def publish(self, raw, schema, canonical, nonce, *, record_type=None, subject=None):
        require(hasattr(self, "token_scope"), "token must be minted before semantic publication")
        require(subject is None or subject == self.token_scope.wire_subject, "foreign subject in token capture")
        return super().publish(raw, schema, canonical, nonce, record_type=record_type, subject=self.token_scope.wire_subject)

    def build_media(self):
        require(not hasattr(self, "diagnostic_restore"), "diagnostic restored state cannot establish a fresh capture")
        require(self.manifest.get("tokenComposition", {}).get("joinedCompositionPreviouslyAccepted") is False,
            "explicit newly composed token native manifest required")
        self.foundation()
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
        if hasattr(self, "token_capture_output"):
            from .token_diagnostic import checkpoint
            pin = checkpoint(self, self.token_capture_output / "before-paid-mint")
            print("Local pre-mint diagnostic checkpoint:", pin, flush=True)
        token_id = self.mint_token()
        self.token_scope = token_scope("31337", self.addresses["StreamCore"], "1", str(token_id))
        require(self.call("StreamCore", "tokenCollectionIdentity", (token_id,)) == (True, 1, 1, False),
            "actual unburned first token identity required")
        self.register_document("RAW_BYTES", 1, RAW_DEFINITION)
        seed = dumps({"purpose": "Fresh token-scoped public local test-image statements; not a museum accession.",
            "tokenId": str(token_id), "core": self.addresses["StreamCore"], "subjectId": self.token_scope.subject_id,
            "media": media_description(image_bytes()), "notAnAccession": True})
        seed_schema = self.register_document("CURRENT_TOKEN_MEDIA_CAPTURE_SEED_V1", 0, b'{"type":"object"}')
        executor, core = self.addresses["StreamGovernanceExecutor"], self.addresses["StreamCore"]
        self.deploy("StreamCollectionAttestations", ((core, self.schemas, executor, self.deployment,
            "https://example.org/local-token/attestations.json", schema_id("new joined token Museum module"),
            ("METADATA_ERC1271_VERIFY_GAS", 400000, 90000, 2), ("METADATA_DEPENDENCY_READ_GAS", 300000, 50000, 2)),))
        prior, sid = self.publish(seed, seed_schema, RAW_BYTES, 1)
        require(sid == self.token_scope.subject_id, "native derived token subject differs")
        profile = self.profile_for_capture()
        for name in [JCS_NAME] + [n for n in profile.documents if n != JCS_NAME]:
            kind, raw = profile.documents[name]
            canonical = getattr(profile, "document_canonicalizations", {}).get(name, RAW_BYTES if name == JCS_NAME else JCS_ID)
            self.register_document(name, kind, raw, canonical, getattr(profile, "document_predecessors", {}).get(name, ZERO))
        stamp = self._token_stamp()
        media_profile = AccountProjectionProfile(ROOT)
        media_payloads = token_payloads(chain_id="31337", core=core, collection_id="1", token_id=str(token_id),
            attestor=self.attestor, profile_hash=media_profile.profile_hash, prior=prior,
            source_digest=keccak256(seed), created_at=stamp)
        for nonce, raw in enumerate(media_payloads, 2): self.publish(raw, schema_id(V1_NAMES[1]), JCS_ID, nonce)
        self.capture_context = {"profile": profile, "mediaProfile": media_profile, "subjectId": sid,
            "prior": prior, "seedSchema": seed_schema, "seedDigest": keccak256(seed), "createdAt": stamp,
            "nextNonce": 2 + len(media_payloads)}
        self.after_media_publications()
        block = self.rpc("eth_getBlockByNumber", ["latest", False])
        views = {}
        expected_views = {"ownerOf": (self.token_buyer,), "tokenCollectionIdentity": (True, 1, 1, False),
            "tokenLifecycle": (2,), "tokenData": (image_bytes(),),
            "coordinatorAtMint": (self.addresses["StreamEntropyCoordinator"],)}
        for name in (*expected_views, "tokenURI"):
            arguments = (token_id,)
            data = self.data("StreamCore", name, arguments)
            result = self.rpc("eth_call", [{"to": core, "data": data}, {"blockHash": block["hash"], "requireCanonical": True}])
            decoded = decode(self.function("StreamCore", name)[2], hex_bytes(result), maximum=1048576)
            if name in expected_views:
                require(decoded == expected_views[name], "source-block token read differs: " + name)
            else:
                require(len(decoded) == 1 and decoded[0], "source-block actual token metadata is empty")
                verify_token_metadata(decoded[0], token_id)
            views[name] = {"to": core, "data": data, "result": result, "blockHash": block["hash"]}
        evidence = dumps({"kind": "local_evm_fixture", "workflow": "new_joined_current_token_safe_media_v1",
            "nativeInputManifestSha256": hashlib.sha256(self.manifest_raw).hexdigest(), "nativeComposition": self.manifest["tokenComposition"],
            "artifacts": self.artifact_rows, "safeFixture": self.manifest["safeFixture"], "safeComponents": self.safe_components,
            "safeAccounts": self.safe_accounts, "transactions": self.receipts,
            "boundaries": [{"component": "DevelopmentEntropyProvider", "kind": "controlled_local_oracle"}],
            "governanceRoot": self.governor, "attestor": self.attestor, "hostGovernanceAuthority": executor,
            "media": media_description(image_bytes()), "tokenMint": self.token_mint_evidence,
            "tokenSourceBlockViews": views, "qualification": QUALIFICATION,
            **CurrentAuthorityFixture.extra_capture_evidence(self)})
        addresses = self.capture_code_addresses()
        anchor = dumps({"profile": PROFILE, "chainId": "31337", "blockHash": block["hash"],
            "blockNumber": str(int(block["number"], 16)), "timestamp": str(int(block["timestamp"], 16)),
            "stateRoot": block["stateRoot"], "environment": "local_evm_fixture", "deploymentEvidenceHash": keccak256(evidence),
            "host": self.addresses["StreamCollectionAttestations"], "core": core, "schemas": self.schemas, "store": self.store,
            "codePins": [{"address": address, "runtimeHash": keccak256(hex_bytes(self.rpc("eth_getCode", [address, "latest"])))} for address in addresses],
            "lanes": self.capture_lanes()})
        return anchor, evidence

    def _token_stamp(self):
        return datetime.fromtimestamp(int(self.rpc("eth_getBlockByNumber", ["latest", False])["timestamp"], 16), timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    def after_media_publications(self):
        if not hasattr(self, "authority_input"): self.configure_authority(*synthetic_snapshot())
        item, context = self.authority_input, self.capture_context
        profile = context["profile"]; agent = account_iri("31337", self.attestor)
        documentary = documentary_bytes(item["descriptor"], item["raw"], item["descriptorHash"], item["mode"], item["label"])
        nonce = context["nextNonce"]
        source_selector, sid = self.publish(documentary, context["seedSchema"], RAW_BYTES, nonce)
        raw, declaration = token_declaration_payload(profile, agent, sid, source_selector, documentary, self._token_stamp(), item["label"])
        declared, _ = self.publish(raw, schema_id(NAMES[1]), JCS_ID, nonce + 1)
        declaration_selector = dict(declared, pointer="/entities/0")
        raw, assertion = token_alignment_payload(profile, agent, sid, source_selector, documentary,
            declaration_selector, declaration, self._token_stamp(), item["parsed"], item["label"], item["typeFact"])
        aligned, _ = self.publish(raw, schema_id(NAMES[1]), JCS_ID, nonce + 2)
        alignment_selector = dict(aligned, pointer="/assertions/0")
        review = token_review_payload(profile, agent, sid, alignment_selector, raw, assertion, self._token_stamp())
        reviewed, _ = self.publish(review, schema_id(NAMES[1]), JCS_ID, nonce + 3)
        self.authority_records = {"documentary": source_selector, "declaration": declaration_selector,
            "alignment": alignment_selector, "review": dict(reviewed, pointer="/assertions/0")}

    def capture_code_addresses(self):
        names = ("StreamCore", "StreamCollectionAttestations", "StreamSchemaRegistry", "StreamGovernanceExecutor")
        return sorted({self.store, *(self.addresses[name] for name in names), *self.safe_accounts})

    def export_capture(self, source, output):
        output = Path(output)
        authority_hash = CurrentAuthorityFixture.export_capture(self, source, output)
        result = build_export(output / "authority-package", authority_hash, disclosure="public")
        directory = output / "semantic-export-package"; write_package(result, directory)
        verify_export(directory, result.manifest_hash)
        bag = build_dossier(directory, result.manifest_hash,
            {hashlib.sha256(image_bytes()).hexdigest() + ".bin": image_bytes()}, bagging_date="2026-09-16")
        bag_directory = output / "dossier-bag"; write_tree(bag.files, bag_directory); verify_dossier(bag_directory, bag.manifest_hash)
        ocfl = build_version(bag, created="2026-09-16T00:00:00Z", message="New actual token and fresh token-subject media capture")
        object_directory = output / "dossier-ocfl"; write_tree(ocfl.files, object_directory); verify_ocfl(object_directory, ocfl.inventory_hash)
        output.joinpath("token-result.json").write_bytes(dumps({"mode": "actual_joined_token_scoped_dossier_capture",
            "nativeInputManifestSha256": hashlib.sha256(self.manifest_raw).hexdigest(),
            "subjectId": self.token_scope.subject_id, "tokenId": self.token_scope.token_id,
            "exportManifestHash": result.manifest_hash, "bagManifestHash": bag.manifest_hash,
            "ocflInventoryHash": ocfl.inventory_hash, "qualification": QUALIFICATION}))
        return bag.manifest_hash


def main():
    def configure_token_fixture(fixture, args):
        configure_fixture(fixture, args)
        fixture.token_capture_output = args.output
    def capture_token(fixture, output):
        try:
            return capture_current(fixture, output)
        except Exception:
            from .token_diagnostic import checkpoint
            try:
                pin = checkpoint(fixture, output / "failure-state")
                print("Local failure diagnostic checkpoint:", pin, flush=True)
            except Exception as error:
                print("Local diagnostic checkpoint failed:", str(error)[:2048], flush=True)
            raise
    run_main(fixture_type=CurrentTokenFixture, capture_function=capture_token,
        configure_parser=configure_parser, prepare_arguments=prepare_arguments, configure_fixture=configure_token_fixture)


if __name__ == "__main__": main()
