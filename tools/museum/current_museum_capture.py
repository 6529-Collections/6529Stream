"""Positive recorded media capture on a real, isolated current governance foundation.

Uses existing pinned native products only. This is a local foundation/metadata
workflow, not the entire product graph, live deployment or institutional evidence.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import time

from .canonical import dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import Array, decode, encode
from .chain_rpc import RpcTransport, ReplayTransport
from .current_native_fixture import CurrentNativeFixture
from .independent_wire import DOCUMENT_SPEC, RAW_BYTES, RAW_DEFINITION, RECORD, RECEIPT, SUBJECT, ZERO, ZERO_ADDRESS, require
from .independent_source import IndependentSourceAdapter, PROFILE
from .independent_publication import IndependentPublicationAdapter, EVENT_DATA, EVENT_TOPIC, PROFILE as PUBLICATION_PROFILE
from .recorded_semantic import RegisteredInterpretationCapture, RecordedSemanticSource
from .account_profile import AccountProjectionProfile, JCS_NAME, JCS_ID
from .local_independent_fixture import REQUEST, WRITE_SIGNATURE
from .local_account_fixture import _selector
from .current_media_inputs import image_bytes, media_description, payloads, selected_plans
from .schemas import NAMES

GOV_CALL = ("address", "uint256", "bytes4", "bytes32", "bytes32", "bytes32", "bytes32")
ROOT = Path(__file__).resolve().parents[2] / "schemas/museum"


def h(kinds, values): return keccak256(encode(kinds, values))


class CurrentMuseumFixture(CurrentNativeFixture):
    def manifest_payload(self, payload):
        pointer = self.store_payload(payload)
        digest, size = keccak256(payload), len(payload)
        format_ = "0x8844b744a67cdcdb84ea3c6e3d686883da175820b9ff07a19cffa14bf62e6e81"
        canonical = "0x886c7c89c308c459ca8a626e0ef36a5ea9f4c7a7b56aaf86c71a2ddf3b4f9044"
        root = self.store_payload(encode(("bytes4", "uint16", "bytes32", "bytes32", "uint32", "uint16", Array(("address", "uint32", "bytes32"))),
            ("0x6c9d2530", 1, format_, canonical, size, 1, [(pointer, size, digest)])))
        leaf = h(("bytes32", "uint256", "uint32", "bytes32"),
            ("0x852f4811a2eb32694863d94ba41b545a65ef4c76086a32c35881f0c4e250a7b5", 0, size, digest))
        listed = h(("bytes32", "uint32", Array("bytes32")),
            ("0xa93750a5551ac5668c8f24cca85acaf1d5f8334fac9406f845fce1ce35548839", size, [leaf]))
        digest = h(("bytes32", "uint16", "bytes32", "bytes32", "uint32", "uint16", "bytes32"),
            ("0xd6ab89b077c61a288c7168cf8f1c9a7a19464b10475735dae37cb46a0c94c40b", 1, format_, canonical, size, 1, listed))
        return root, digest

    def foundation(self):
        executor = self.deploy("StreamGovernanceExecutor", (self.account,))
        roles = self.deploy("StreamRoleRegistry", (executor,))
        deployment = schema_id("current museum foundation capture v1")
        registry_hash = schema_id("current museum module registry")
        registry = self.deploy("StreamModuleRegistry", (executor, registry_hash, "urn:stream:current-media:registry"))
        gas = [("0x9bae92ab1dd0c5535c65125ea4ee7cff3d55fc31fc2555096c2b5eabceb5bcda", 100000, 25000, 1),
            ("0x0af6f5a1a5059e398191fa0af185be12fee6d609933826603244c7f247793be7", 2910000, 1460000, 1),
            ("0x02ad62929eaa837b9d1704745193125454925fd11a6bf273d7bb1faa23272e93", 12000000, 250000, 1),
            ("0x51125071e3dfb233a2711689d4cc377bbda429f1356ebc09a58d763548541e17", 500000, 120000, 2)]
        code_hash = keccak256(hex_bytes(self.rpc("eth_getCode", [registry, "latest"])))
        core = self.deploy("StreamCore", ("Current museum capture", "STREAM", executor,
            (registry, code_hash, registry_hash, deployment), gas))
        manifest = self.deploy("StreamSystemManifest", (core, executor))
        self.governor = self.safe(731)
        self.attestor = self.safe(732)
        # Distinct real Safe principals are valid canonical terminal-freeze guardians.
        guardians = sorted((self.safe(733), self.safe(734)))
        self.deploy("StreamDeploymentPlan")
        pointer, digest = self.manifest_payload(dumps({"purpose": "actual current museum foundation only", "version": 1}))
        update = (digest, "urn:stream:current-media:foundation", *(schema_id(v) for v in ("events", "compatibility", "numeric", "schema", "canonical", "spec", "client")))
        config = (executor, roles, core, registry, manifest, self.account, self.governor, guardians,
                  deployment, schema_id("museum foundation manifest module"), "urn:stream:current-media:module")
        binding, batches = self.call("StreamDeploymentPlan", "buildFoundation", (config, pointer, update))
        commitment, = self.call("StreamGovernanceExecutor", "hashGenesisPlan", (binding, batches))
        self.transact("StreamGovernanceExecutor", "commitGenesisPlan", (commitment,))
        self.transact("StreamGovernanceExecutor", "initializeGenesis", (binding, batches))
        require(self.call("StreamGovernanceExecutor", "genesisInitialized") == (True,), "actual genesis did not initialize")
        require(self.call("StreamGovernanceExecutor", "owner") == (self.governor,), "actual governor differs")
        self.deployment = deployment
        # Ordinary delayed class-1 collection creation, not a state injection.
        scope = h(("bytes32", "uint256", "address", "uint256"),
            ("0x3a882a22dad9915c9193738f63216234155080ed4c4fc9bfae446e90f1df6e16", 31337, core, 1))
        domain = "0x854c83f82b7677e58c61a2482a7a430a8318d765d99a95d3fbce5c84be6cc2b5"
        kinds = ("bytes32", "bytes32", "bool", "uint8", "uint8", "bool", "uint256")
        transition = (scope, h(kinds, (domain, scope, False, 0, 0, False, 0)), h(kinds, (domain, scope, True, 0, 0, True, 1)))
        data = self.data("StreamCore", "createCollection", (0, True, 1, 0))
        self.govern(1, [self.operation(core, data, transition)], [hex_bytes(data)])
        require(self.call("StreamCore", "collectionExists", (1,)) == (True,), "actual Core collection missing")
        self.deploy("StreamSchemaRegistry", (executor,))
        self.schemas = self.addresses["StreamSchemaRegistry"]
        self.store, = self.call("StreamSchemaRegistry", "chunkStore")
        self.admit_schema()

    @staticmethod
    def operation(target, data, transition):
        return (target, 0, data[:10], keccak256(hex_bytes(data)), *transition)

    def govern(self, action_class, calls, datas):
        self.deploy("StreamGovernanceBootstrap")
        calls_hash, = self.call("StreamGovernanceBootstrap", "governanceCallsHash", (calls,))
        transition = self.call("StreamGovernanceBootstrap", "deriveBatchTransitionHashes", (calls, calls_hash))
        delay, = self.call("StreamGovernanceExecutor", "minimumDelay", (action_class,))
        now = int(self.rpc("eth_getBlockByNumber", ["latest", False])["timestamp"], 16)
        ready = now + delay + 3600
        self.transact("StreamGovernanceExecutor", "publishGovernanceCallData", (datas,), safe=self.governor)
        receipt = self.transact("StreamGovernanceExecutor", "scheduleGovernanceBatch", (action_class, calls,
            *transition, ready, ready + 7 * 86400, schema_id("museum capture exact delayed action"),
            "urn:stream:current-media:governance", self.deployment), safe=self.governor)
        topic = keccak256(b"GovernanceActionScheduled(uint16,bytes32,uint8,address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint256,address,bytes32,string,bytes32)")
        found = [r for r in receipt["logs"] if r["address"] == self.addresses["StreamGovernanceExecutor"] and r["topics"][0] == topic]
        require(len(found) == 1, "exact governance schedule receipt required")
        action = found[0]["topics"][1]
        self.rpc("evm_setNextBlockTimestamp", [ready])
        self.rpc("evm_mine", [])
        self.transact("StreamGovernanceExecutor", "executeGovernanceBatch", (action, calls, datas), safe=self.governor)
        return action

    def publication(self, pointer, digest):
        name = "StreamSystemManifest"
        current = self.call(name, "streamSystemManifest")
        old_pointer, = self.call(name, "streamSystemManifestPointer")
        address = self.addresses[name]
        scope = h(("bytes32", "uint256", "address"), ("0xf73b4d7b4d260fce0823707f836fdf29a1767a2a2a9cfbce14ec8c5e49e47841", 31337, address))
        modules_hash, discovery_hash = h(("address",) * 11, current[2:13]), h(("bytes32",) * 7, current[13:20])
        def state(hash_, uri, carrier, revision):
            return h(("bytes32", "bytes32", "bytes32", "bytes32", "address", "bytes32", "bytes32", "uint64"),
                ("0x3764ccb415d0aac07f1bddb8d4841ad6d4c2f9b2fe7ce7d221c586bc056aaf60", scope, hash_, keccak256(uri.encode()), carrier, modules_hash, discovery_hash, revision))
        uri = "urn:stream:current-media:schema-admission"
        data = self.data(name, "publishStreamSystemManifest", (pointer, (digest, uri, *current[13:20])))
        transition = (scope, state(current[0], current[1], old_pointer, current[20]), state(digest, uri, pointer, current[20] + 1))
        return self.operation(address, data, transition), hex_bytes(data)

    def admit_schema(self):
        target = self.schemas
        selector = self.data("StreamSchemaRegistry", "registerDocument", (("RAW_BYTES", 1, keccak256(RAW_DEFINITION), RAW_BYTES, ZERO, "", len(RAW_DEFINITION)), []))[:10]
        rows = [(1, target, selector, keccak256(hex_bytes(self.rpc("eth_getCode", [target, "latest"]))),
            h(("bytes32", "address"), (self.deployment, target)), 1, 0, 0, ZERO)]
        candidate, catalog, count, revision = self.call("StreamGovernanceExecutor", "governanceActionPolicyState")
        self.deploy("StreamGovernanceActionPolicy")
        next_, scope, old, new = self.call("StreamGovernanceActionPolicy", "extensionTransition",
            (self.addresses["StreamGovernanceExecutor"], candidate, catalog, count, revision, rows))
        data = self.data("StreamGovernanceExecutor", "extendGovernanceActionPolicy", (revision, catalog, next_, rows))
        pointer, digest = self.manifest_payload(dumps({"purpose": "current museum schema action admission"}))
        tail, tail_data = self.publication(pointer, digest)
        self.govern(3, [self.operation(self.addresses["StreamGovernanceExecutor"], data, (scope, old, new)), tail], [hex_bytes(data), tail_data])

    def register_document(self, name, kind, raw, canonical=RAW_BYTES):
        chunks = []
        for offset in range(0, len(raw), 8192):
            part = raw[offset:offset + 8192]
            self.invoke(self.store, "publishChunk(bytes)", ("bytes",), (part,))
            chunks.append(keccak256(part))
        spec = (name, kind, keccak256(raw), canonical, ZERO, "", len(raw))
        transition = self.call("StreamSchemaRegistry", "registrationTransition", (spec, chunks))
        data = self.data("StreamSchemaRegistry", "registerDocument", (spec, chunks))
        self.govern(1, [self.operation(self.schemas, data, transition)], [hex_bytes(data)])
        actual, = self.call("StreamSchemaRegistry", "documentBytes", (schema_id(name),))
        require(actual == raw, "registered current document bytes differ")
        return schema_id(name)

    def publish(self, raw, schema, canonical, nonce):
        subject = (0, 1, 0, ZERO)
        sid, = self.call("StreamCollectionAttestations", "deriveSubject", (subject,))
        now = int(self.rpc("eth_getBlockByNumber", ["latest", False])["timestamp"], 16)
        request = (self.attestor, 1, sid, schema_id("INDEPENDENT_SEMANTIC_ASSERTION"), schema, 1,
            hex_bytes(keccak256(raw)), canonical, "ipfs://public-current-media-capture", raw, now, nonce, now + 86400)
        receipt = self.transact("StreamCollectionAttestations", WRITE_SIGNATURE, (subject, request, b""), safe=self.attestor)
        host = self.addresses["StreamCollectionAttestations"]
        event = next(r for r in receipt["logs"] if r["address"] == host and r["topics"][0] == EVENT_TOPIC)
        record_hash = decode(EVENT_DATA, hex_bytes(event["data"]))[1]
        record, saved = self.call("StreamCollectionAttestations", "collectionRecord", (record_hash,))
        definition, = self.call("StreamSchemaRegistry", "documentBytes", (schema,))
        require(saved[1] == self.attestor, "record is not attributed to actual Safe")
        return _selector(host, record_hash, record, saved, definition), sid

    def build_media(self):
        self.foundation()
        self.register_document("RAW_BYTES", 1, RAW_DEFINITION)
        seed = dumps({"purpose": "Public test image and explicit semantic claims for local current-stack museum export.", "notAnAccession": True})
        seed_schema = self.register_document("CURRENT_MEDIA_CAPTURE_SEED_V1", 0, b'{"type":"object"}')
        executor, core = self.addresses["StreamGovernanceExecutor"], self.addresses["StreamCore"]
        self.deploy("StreamCollectionAttestations", ((core, self.schemas, executor, self.deployment,
            "https://example.org/current-media/attestations.json", schema_id("current museum attestation module"),
            ("METADATA_ERC1271_VERIFY_GAS", 400000, 90000, 2), ("METADATA_DEPENDENCY_READ_GAS", 300000, 50000, 2)),))
        prior, sid = self.publish(seed, seed_schema, RAW_BYTES, 1)
        profile = AccountProjectionProfile(ROOT)
        for name in [JCS_NAME] + [n for n in profile.documents if n != JCS_NAME]:
            kind, raw = profile.documents[name]
            self.register_document(name, kind, raw, RAW_BYTES if name == JCS_NAME else JCS_ID)
        stamp = datetime.fromtimestamp(int(self.rpc("eth_getBlockByNumber", ["latest", False])["timestamp"], 16), timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        for nonce, raw in enumerate(payloads(chain_id=31337, attestor=self.attestor, subject_id=sid,
                profile_hash=profile.profile_hash, prior=prior, source_digest=keccak256(seed), created_at=stamp), 2):
            self.publish(raw, schema_id(NAMES[1]), JCS_ID, nonce)
        block = self.rpc("eth_getBlockByNumber", ["latest", False])
        evidence = dumps({"kind": "local_evm_fixture", "workflow": "actual_current_foundation_safe_recorded_media_v1",
            "nativeInputManifestSha256": hashlib.sha256(self.manifest_raw).hexdigest(), "artifacts": self.artifact_rows,
            "safeFixture": self.manifest["safeFixture"], "safeComponents": self.safe_components, "safeAccounts": self.safe_accounts,
            "transactions": self.receipts, "boundaries": [], "governanceRoot": self.governor, "attestor": self.attestor,
            "hostGovernanceAuthority": executor, "media": media_description(image_bytes()),
            "qualification": "Real selected native Core/Executor/ModuleRegistry/Manifest/SchemaRegistry/attestation products and official Safe CALLs. Foundation plus collection/document/attestation workflow only; no whole-product graph, latest-source, institutional, consensus-finality or public-deployment claim."})
        addresses = sorted(set([self.store, *self.addresses.values(), *self.safe_components.values(), *self.safe_accounts]))
        anchor = dumps({"profile": PROFILE, "chainId": "31337", "blockHash": block["hash"],
            "blockNumber": str(int(block["number"], 16)), "timestamp": str(int(block["timestamp"], 16)),
            "stateRoot": block["stateRoot"], "environment": "local_evm_fixture", "deploymentEvidenceHash": keccak256(evidence),
            "host": self.addresses["StreamCollectionAttestations"], "core": core, "schemas": self.schemas, "store": self.store,
            "codePins": [{"address": a, "runtimeHash": keccak256(hex_bytes(self.rpc("eth_getCode", [a, "latest"])))} for a in addresses],
            "lanes": [{"scopeKey": "1", "recordType": schema_id("INDEPENDENT_SEMANTIC_ASSERTION")}]})
        return anchor, evidence


def capture(fixture, output):
    anchor, evidence = fixture.build_media()
    output.joinpath("anchor.json").write_bytes(anchor)
    output.joinpath("deployment-evidence.json").write_bytes(evidence)
    output.joinpath("test-image.png").write_bytes(image_bytes())
    adapter = IndependentSourceAdapter(anchor, RpcTransport(fixture.endpoint), provenance="trusted_rpc")
    snapshot = adapter.snapshot()
    transcript = adapter.reader.transcript()
    output.joinpath("source-capture.json").write_bytes(snapshot)
    output.joinpath("transcript.json").write_bytes(transcript)
    source_replay = IndependentSourceAdapter(anchor, ReplayTransport(transcript, keccak256(transcript)), provenance="trusted_rpc")
    require(source_replay.snapshot() == snapshot, "current source offline replay differs")
    hashes = {r["recordHash"] for r in loads(snapshot, maximum=16777216)["records"]}
    hints = []
    for row in fixture.receipts:
        for event in row["receipt"]["logs"]:
            if event["address"] == adapter.a["host"] and event["topics"] and event["topics"][0] == EVENT_TOPIC:
                record = decode(EVENT_DATA, hex_bytes(event["data"]))[1]
                if record in hashes: hints.append({"recordHash": record, "transactionHash": row["transactionHash"]})
    hint_bytes = dumps({"profile": PUBLICATION_PROFILE, "records": hints})
    output.joinpath("publication-hints.json").write_bytes(hint_bytes)
    publication = IndependentPublicationAdapter(adapter, hint_bytes, RpcTransport(fixture.endpoint), provenance="trusted_rpc")
    publication_raw = publication.snapshot()
    publication_transcript = publication.reader.transcript()
    output.joinpath("publications.json").write_bytes(publication_raw)
    output.joinpath("publication-transcript.json").write_bytes(publication_transcript)
    publication_replay = IndependentPublicationAdapter(source_replay, hint_bytes,
        ReplayTransport(publication_transcript, keccak256(publication_transcript)), provenance="trusted_rpc")
    require(publication_replay.snapshot() == publication_raw, "current publication replay differs")
    profile = AccountProjectionProfile(ROOT)
    interpretation = RegisteredInterpretationCapture(publication, profile, RpcTransport(fixture.endpoint))
    interpretation_raw = interpretation.snapshot()
    interpretation_transcript = interpretation.probe.reader.transcript()
    output.joinpath("interpretation.json").write_bytes(interpretation_raw)
    output.joinpath("interpretation-transcript.json").write_bytes(interpretation_transcript)
    interpreted_replay = RegisteredInterpretationCapture(publication_replay, profile,
        ReplayTransport(interpretation_transcript, keccak256(interpretation_transcript)))
    require(interpreted_replay.snapshot() == interpretation_raw, "current interpretation replay differs")
    source = RecordedSemanticSource(interpreted_replay, profile_hash=profile.profile_hash)
    return export_media(source, output)


def export_media(source, output):
    """Export only an already verified captured source; no chain calls or metadata inference."""
    plans = selected_plans(source)
    for name, raw in plans.items(): output.joinpath(name).write_bytes(raw)
    for name, raw in selected_plans(source, omit_publisher=True).items(): output.joinpath("missing-publisher-" + name).write_bytes(raw)
    from .package_recorded import build_recorded_directory
    from .package import write_package
    from .package_v2 import verify_package
    from .recorded_premis import PROFILE_HASH as PH
    from .recorded_iiif import PROFILE_HASH as IH
    from .recorded_lido import PROFILE_HASH as LH
    pins = {"source_hash": keccak256(output.joinpath("transcript.json").read_bytes()),
        "publication_hash": keccak256(output.joinpath("publication-transcript.json").read_bytes()),
        "interpretation_hash": keccak256(output.joinpath("interpretation-transcript.json").read_bytes()), "profile_hash": source.profile_hash,
        "selection_hash": keccak256(plans["selection.json"]), "plan_hash": keccak256(plans["plan.json"]),
        "premis_plan_hash": keccak256(plans["premis-plan.json"]), "premis_profile_hash": PH,
        "iiif_plan_hash": keccak256(plans["iiif-plan.json"]), "iiif_profile_hash": IH,
        "lido_plan_hash": keccak256(plans["lido-plan.json"]), "lido_profile_hash": LH}
    result = build_recorded_directory(output, root=ROOT, disclosure="public", **pins,
        premis_plan_bytes=plans["premis-plan.json"], iiif_plan_bytes=plans["iiif-plan.json"], lido_plan_bytes=plans["lido-plan.json"])
    for name in ("premis/premis.xml", "iiif/manifest.json", "lido/lido.xml"):
        require(name in dict(result.files), "complete recorded format missing: " + name)
    package_path = output / "package"
    write_package(result, package_path)
    verify_package(package_path, result.manifest_hash)
    output.joinpath("pins.json").write_bytes(dumps(pins | {"package_manifest": result.manifest_hash}))
    # The same captured source with only publisher selection omitted must not invent a legal body.
    from .package_recorded import build_recorded_package, INPUT_FILES
    missing = selected_plans(source, omit_publisher=True)
    inputs = {name: output.joinpath(name).read_bytes() for name in INPUT_FILES}
    inputs.update({name: missing[name] for name in ("selection.json", "plan.json")})
    negative_pins = pins | {key: keccak256(missing[name]) for key, name in (
        ("selection_hash", "selection.json"), ("plan_hash", "plan.json"),
        ("premis_plan_hash", "premis-plan.json"), ("iiif_plan_hash", "iiif-plan.json"), ("lido_plan_hash", "lido-plan.json"))}
    negative = build_recorded_package(inputs, root=ROOT, disclosure="public", **negative_pins,
        premis_plan_bytes=missing["premis-plan.json"], iiif_plan_bytes=missing["iiif-plan.json"], lido_plan_bytes=missing["lido-plan.json"])
    files = dict(negative.files)
    require("lido/lido.xml" not in files and "premis/premis.xml" in files and "iiif/manifest.json" in files,
        "missing publisher must withhold only LIDO")
    report = loads(files["lido/report.json"], maximum=67108864)
    require(report["status"] == "unsupported" and "missing_selected_publisher_assertion" in files["lido/report.json"].decode(),
        "missing publisher unsupported reason differs")
    output.joinpath("missing-publisher-report.json").write_bytes(files["lido/report.json"])
    output.joinpath("result.json").write_bytes(dumps({"mode": "actual_current_foundation_recorded_media",
        "formats": ["Linked Art", "PREMIS", "IIIF", "LIDO"], "manifestHash": result.manifest_hash,
        "offlinePackageVerified": True, "missingPublisherWithholdsLido": True,
        "sourceStateHash": source.state.commitment, "records": len(source.state.records),
        "media": media_description(image_bytes()), "captureIncludesRetainedImage": True,
        "packageIncludesMediaBytes": False, "institutionalConformance": False, "consensusFinality": False}))
    return result.manifest_hash


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native-manifest", required=True, type=Path)
    parser.add_argument("--native-manifest-sha256", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--disclosure", required=True, choices=("public", "restricted"))
    parser.add_argument("--anvil", default="anvil")
    args = parser.parse_args()
    require(args.disclosure == "public", "restricted current capture is unsupported")
    manifest_raw = args.native_manifest.read_bytes()
    require(hashlib.sha256(manifest_raw).hexdigest() == args.native_manifest_sha256, "native manifest hash mismatch")
    args.output.mkdir(parents=True, exist_ok=False)
    args.output.joinpath("native-inputs.json").write_bytes(manifest_raw)
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0)); port = sock.getsockname()[1]
    endpoint = "http://127.0.0.1:" + str(port)
    with (args.output / "anvil.log").open("wb") as log:
        process = subprocess.Popen([args.anvil, "--host", "127.0.0.1", "--port", str(port), "--chain-id", "31337",
            "--hardfork", "shanghai", "--gas-limit", "30000000", "--silent"], stdout=log, stderr=subprocess.STDOUT,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
        fixture = None
        try:
            for _ in range(100):
                try:
                    fixture = CurrentMuseumFixture(args.native_manifest, endpoint, expected_manifest_sha256=args.native_manifest_sha256); break
                except OSError:
                    require(process.poll() is None, "current capture Anvil exited"); time.sleep(0.05)
            require(fixture is not None, "current capture Anvil did not start")
            print(capture(fixture, args.output), flush=True)
        finally:
            if fixture is not None:
                args.output.joinpath("execution-journal.json").write_bytes(dumps({"transactions": fixture.receipts, "artifacts": fixture.artifact_rows}))
            process.terminate()
            try: process.wait(timeout=10)
            except subprocess.TimeoutExpired: process.kill(); process.wait(timeout=5)


if __name__ == "__main__": main()
