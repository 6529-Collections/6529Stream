"""Local native Metadata RIGHTS capture. No public chain or legal authority inference."""
import hashlib
import json
from pathlib import Path

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, subject_id
from .chain_rpc import RpcTransport, ReplayTransport
from .current_native_fixture import patch_links
from .current_museum_capture import h, main as run_main, ROOT
from .current_preservation_capture import CurrentPreservationFixture, OBJECT_ID, capture as capture_preservation
from .independent_wire import ZERO, ZERO_ADDRESS, generic_hash, require
from .metadata_rights_source import MetadataRightsSource, PROFILE as SOURCE_PROFILE, SCHEMA_NAME, SCHEMA_BYTES, PROFILE_NAME, PROFILE_BYTES, PROFILE_HASH, JCS_ID, RECORD_TYPE, validate_rights
from .preservation_resources import RIGHT_NAME, OBJECT_NAME, SCHEMAS, MODE, PROFILE_HASH as RESOURCE_HASH
from .premis import NS

METADATA = "StreamCollectionMetadataV1"
RIGHTS_FAMILY = schema_id("6529STREAM_RECORD_FAMILY_RIGHTS_V1")
QUALIFICATION = "Actual local Metadata class-7/8 Safe publication and governance grants. Test-fixture declarations only: no legal ownership, license permission, licensor identity, current rights selection or institutional approval is established."


def fixture_rights(subject, auth_class):
    from tools.metadata.rights_profile import examples
    value = examples()[0]
    value.update(subjectId=subject, profileHash=PROFILE_HASH)
    value["licensor"] = {"identity": {"kind": "institution", "name": "Explicit local test-fixture licensor"}, "instrumentDigest": None}
    value["grants"]["reproduction"]["status"] = "denied" if auth_class == 7 else "granted"
    raw = dumps(value)
    validate_rights(raw, subject)
    return raw


def create_address(sender, nonce):
    require(type(nonce) is int and 0 <= nonce < 2**64, "CREATE nonce bound")
    raw = b"" if nonce == 0 else nonce.to_bytes((nonce.bit_length() + 7) // 8, "big")
    item = raw if len(raw) == 1 and raw[0] < 128 else bytes([128 + len(raw)]) + raw
    payload = b"\x94" + hex_bytes(sender, 20) + item
    return "0x" + hex_bytes(keccak256(bytes([192 + len(payload)]) + payload))[12:].hex()


def augment_manifest(original, expected_hash, native_out):
    """Keep original selected products; add only hash-pinned native dependency closure."""
    raw = Path(original).read_bytes()
    require(hashlib.sha256(raw).hexdigest() == expected_hash, "original native manifest changed")
    manifest = json.loads(raw)
    products = manifest["products"]
    pending = [METADATA, "StreamArtistOnboardingRegistry", "StreamArtistExtensionFactory", "StreamMintManager",
        "StreamMintLedger", "StreamArweaveCheckpointVerifier", "StreamArchivalCoverage", "StreamDeploymentSlot",
        "StreamArtistRegistryWriterExtension", "StreamArtistRegistryReadExtension", "StreamArtistRegistryFinalityReadExtension"]
    seen = set()
    while pending:
        name = pending.pop()
        if name in seen: continue
        seen.add(name)
        if name in products: continue
        matches = list(Path(native_out).glob("*.sol/" + name + ".json"))
        require(len(matches) == 1, "missing/ambiguous retained product: " + name)
        path = matches[0]; artifact_raw = path.read_bytes(); artifact = json.loads(artifact_raw)
        target = artifact["metadata"]["settings"]["compilationTarget"]
        require(len(target) == 1 and list(target.values()) == [name], "retained product identity differs")
        source = next(iter(target))
        require(source.startswith(("smart-contracts/", "script/current/")), "test-only deployment product forbidden")
        products[name] = {"source": source, "artifact": str(path.resolve()), "sha256": hashlib.sha256(artifact_raw).hexdigest()}
        for field in ("bytecode", "deployedBytecode"):
            for imported_source, libraries in artifact[field]["linkReferences"].items():
                for library in libraries:
                    if library in products: require(products[library]["source"] == imported_source, "library identity differs")
                    pending.append(library)
    manifest["rightsCapture"] = {"originalManifestSha256": expected_hash, "originalProductsPreserved": True,
        "nativeDirectory": str(Path(native_out).resolve()), "qualification": QUALIFICATION}
    return dumps(manifest)


class CurrentRightsFixture(CurrentPreservationFixture):
    def send(self, data, target=None, sender=None):
        try: return super().send(data, target, sender)
        except MuseumError:
            if self.receipts and self.receipts[-1]["receipt"]["status"] == "0x0":
                row = self.receipts[-1]
                trace = self.rpc("debug_traceTransaction", [row["transactionHash"], {"tracer": "callTracer"}])
                failures = []
                def collect(frame):
                    if frame.get("error"): failures.append({k: frame[k] for k in ("to", "error", "output") if k in frame})
                    for child in frame.get("calls", []): collect(child)
                collect(trace)
                row["revertedFrames"] = failures
                print("Local reverted frames:", failures, flush=True)
            raise

    def capture_code_addresses(self):
        # All deployed dependencies remain in the original deployment evidence. Source adapters
        # only pin contracts they actually read; their bounded inventory is not a whole graph claim.
        names = ("StreamCore", "StreamCollectionAttestations", "StreamSchemaRegistry", METADATA)
        return sorted(set([self.store, *(self.addresses[n] for n in names), *self.safe_accounts]))

    def extend_actions(self, name, methods):
        target = self.addresses[name]
        rows = [(1, target, "0x" + next(v for k, v in self.products[name]["methodIdentifiers"].items() if k.split("(")[0] == method),
            keccak256(hex_bytes(self.rpc("eth_getCode", [target, "latest"]))), h(("bytes32", "address"), (self.deployment, target)), 1, 0, 0, ZERO) for method in methods]
        rows.sort(key=lambda r: h(("uint8", "address", "bytes4"), r[:3]))
        candidate, catalog, count, revision = self.call("StreamGovernanceExecutor", "governanceActionPolicyState")
        next_, scope, old, new = self.call("StreamGovernanceActionPolicy", "extensionTransition",
            (self.addresses["StreamGovernanceExecutor"], candidate, catalog, count, revision, rows))
        data = self.data("StreamGovernanceExecutor", "extendGovernanceActionPolicy", (revision, catalog, next_, rows))
        pointer, digest = self.manifest_payload(dumps({"purpose": "local RIGHTS exact selector admission", "methods": methods}))
        tail, tail_data = self.publication(pointer, digest)
        self.govern(3, [self.operation(self.addresses["StreamGovernanceExecutor"], data, (scope, old, new)), tail], [hex_bytes(data), tail_data])

    def governed(self, name, function, values, transition):
        data = self.data(name, function, values)
        return self.govern(1, [self.operation(self.addresses[name], data, transition)], [hex_bytes(data)])

    def deploy_library_closure(self, names):
        # Solidity's retained Artist libraries contain mutual links. Reserve exact ordinary
        # EOA CREATE coordinates, perform only those CREATEs, then authenticate the full batch
        # before any contract constructor can use it. No code or storage injection.
        pending = list(names); libraries = set(); visited = set()
        while pending:
            name = pending.pop()
            if name in visited: continue
            visited.add(name)
            for field in ("bytecode", "deployedBytecode"):
                for source, links in self.products[name][field]["linkReferences"].items():
                    for library in links:
                        require(self.manifest["products"][library]["source"] == source, "batch library source differs")
                        libraries.add(library); pending.append(library)
        order = sorted(libraries - self.addresses.keys())
        nonce = int(self.rpc("eth_getTransactionCount", [self.account, "latest"]), 16)
        coordinates = self.addresses | {name: create_address(self.account, nonce+i) for i, name in enumerate(order)}
        def resolve(source, library):
            require(self.manifest["products"][library]["source"] == source, "batch link source differs")
            return coordinates[library]
        staged = {}
        for i, name in enumerate(order):
            artifact = self.products[name]
            require(not [row for row in artifact["abi"] if row["type"] == "constructor"], "linked library constructor unsupported")
            immutables = artifact["deployedBytecode"].get("immutableReferences", {})
            require(set(immutables) <= {"library_deploy_address"}, "linked library non-self immutable unsupported")
            creation, links = patch_links(artifact["bytecode"]["object"], artifact["bytecode"]["linkReferences"], resolve)
            expected, runtime_links = patch_links(artifact["deployedBytecode"]["object"], artifact["deployedBytecode"]["linkReferences"], resolve)
            legacy_guard = expected.startswith(bytes.fromhex("73" + "00"*20 + "3014"))
            definitions = [row for row in artifact["ast"]["nodes"] if row.get("nodeType") == "ContractDefinition" and row.get("name") == name]
            require(len(definitions) == 1 and definitions[0].get("contractKind") == "library", "batch requires native library definition")
            require(int(self.rpc("eth_getTransactionCount", [self.account, "latest"]), 16) == nonce+i, "batch CREATE nonce drift")
            receipt = self.send("0x" + creation.hex()); actual = receipt["contractAddress"]
            require(actual == coordinates[name], "batch CREATE address drift")
            if legacy_guard: expected = expected[:1] + hex_bytes(actual, 20) + expected[21:]
            used = set()
            for position in immutables.get("library_deploy_address", []):
                start, length = position["start"], position["length"]
                require(type(start) is int and length == 32 and 0 <= start and start+length <= len(expected), "library self immutable offset")
                span = set(range(start, start+length)); require(not used & span, "library self immutable overlap"); used |= span
                expected = expected[:start] + bytes(12) + hex_bytes(actual, 20) + expected[start+length:]
            runtime = hex_bytes(self.rpc("eth_getCode", [actual, "latest"]))
            require(0 < len(runtime) <= 24576 and runtime == expected, "batch linked library runtime differs")
            staged[name] = self.manifest["products"][name] | {"address": actual, "links": links, "runtimeLinks": runtime_links,
                "constructorArgumentsHex": "0x", "creationHash": keccak256(creation), "runtimeHash": keccak256(runtime), "runtimeBytes": str(len(runtime)), "immutableValues": {}}
        for name, row in staged.items():
            require(keccak256(hex_bytes(self.rpc("eth_getCode", [row["address"], "latest"]))) == row["runtimeHash"], "completed library batch runtime drift")
        self.addresses.update({name: row["address"] for name, row in staged.items()}); self.artifact_rows.update(staged)

    def ensure_links(self, name):
        for field in ("bytecode", "deployedBytecode"):
            for source, libraries in self.products[name][field]["linkReferences"].items():
                for library in libraries:
                    require(self.manifest["products"][library]["source"] == source, "declared link source mismatch")
                    self.deploy(library)

    def verify_factory_child(self, name, address):
        artifact = self.products[name]
        expected, links = patch_links(artifact["deployedBytecode"]["object"], artifact["deployedBytecode"]["linkReferences"],
            lambda source, library: self.addresses[library])
        actual = hex_bytes(self.rpc("eth_getCode", [address, "latest"]))
        require(0 < len(actual) == len(expected) <= 24576, "factory child size differs")
        used = set(); immutables = {}
        for identifier, positions in artifact["deployedBytecode"].get("immutableReferences", {}).items():
            values = set()
            for row in positions:
                start, length = row["start"], row["length"]
                require(type(start) is int and length == 32 and 0 <= start and start+length <= len(actual), "child immutable offset")
                span = set(range(start, start+length)); require(not used & span, "child immutable overlap")
                used |= span; values.add(actual[start:start+length])
            require(len(values) == 1, "child immutable copies differ")
            immutables[identifier] = "0x" + next(iter(values)).hex()
        require(all(a == b or i in used for i, (a, b) in enumerate(zip(actual, expected))), "factory child runtime differs outside declared immutables")
        self.addresses[name] = address
        self.artifact_rows[name] = self.manifest["products"][name] | {"address": address, "factory": self.addresses["StreamArtistExtensionFactory"],
            "runtimeHash": keccak256(actual), "runtimeBytes": str(len(actual)), "runtimeLinks": links, "immutableValues": immutables}

    def deploy_metadata_dependencies(self):
        core, executor, roles, registry = (self.addresses[n] for n in ("StreamCore", "StreamGovernanceExecutor", "StreamRoleRegistry", "StreamModuleRegistry"))
        ledger = self.deploy("StreamMintLedger")
        manager = self.deploy("StreamMintManager", (core, ledger, registry))
        observers = sorted([(self.safe(751), schema_id("explicit local test observer organization one")),
                            (self.safe(752), schema_id("explicit local test observer organization two"))])
        signature = ("ARCHIVAL_ERC1271_VERIFY_GAS", 400000, 90000, 2)
        checkpoint = self.deploy("StreamArweaveCheckpointVerifier", (executor, observers, 2, signature))
        coverage = self.deploy("StreamArchivalCoverage", (core, executor, roles, checkpoint, signature,
            ("ARCHIVAL_DEPENDENCY_READ_GAS", 150000, 50000, 2)))
        slot = self.deploy("StreamDeploymentSlot", (self.account,))
        coordinator, = self.call("StreamDeploymentSlot", "product")
        self.deploy_library_closure(("StreamArtistExtensionFactory", "StreamArtistOnboardingRegistry", METADATA))
        factory = self.deploy("StreamArtistExtensionFactory")
        facade = "StreamArtistOnboardingRegistry"
        children = ("StreamArtistRegistryWriterExtension", "StreamArtistRegistryReadExtension", "StreamArtistRegistryFinalityReadExtension")
        self.ensure_links(facade)
        for child in children: self.ensure_links(child)
        nonce = int(self.rpc("eth_getTransactionCount", [self.account, "latest"]), 16)
        future = create_address(self.account, nonce+3)
        addresses = []
        for kind, name in enumerate(children, 4):
            child, = self.call("StreamArtistExtensionFactory", "deployRegistry", (kind, future, coordinator))
            self.transact("StreamArtistExtensionFactory", "deployRegistry", (kind, future, coordinator))
            birth, = self.call("StreamArtistExtensionFactory", "birth", (child,))
            binding = h(("bytes32", "uint256", "uint8", "address", "address"),
                (schema_id("6529STREAM_ARTIST_EXTENSION_BIRTH_V1"), 31337, kind, future, coordinator))
            require(birth == (kind, future, 31337, binding, keccak256(hex_bytes(self.rpc("eth_getCode", [child, "latest"])))), "actual extension birth differs")
            self.verify_factory_child(name, child); addresses.append(child)
        artist = self.deploy(facade, (core, manager, coordinator, executor, coverage, self.deployment,
            "urn:6529stream:local-rights:artist-dependency", schema_id("local RIGHTS Artist dependency"), factory, addresses))
        require(artist == future and self.call(facade, "core") == (core,), "actual Artist facade address/core differs")
        require(self.call("StreamDeploymentSlot", "consumed") == (False,) and self.rpc("eth_getCode", [coordinator, "latest"]) == "0x", "unused original Coordinator reservation changed")
        self.artist_dependency = {"facade": artist, "coordinatorReservation": coordinator, "slot": slot,
            "coordinatorConstructed": False, "artistOnboardingAvailable": False, "facadeCoreVerified": True,
            "qualification": "Genuine retained native facade, authenticated extension births and archival/Manager constructors. The original one-use Coordinator coordinate remains unfulfilled and is never selected as a Core authority. Only Metadata's independent class-7/8 family-writer route is exercised."}
        self.deploy(METADATA, ((core, executor, self.schemas, artist, self.deployment,
            "https://example.org/local-rights/metadata.json", schema_id("local RIGHTS Metadata module"),
            ("METADATA_DEPENDENCY_READ_GAS", 400000, 50000, 2), ("METADATA_ARTIST_READ_GAS", 400000, 150000, 2)),))

    def select_metadata(self):
        registry, core, target = (self.addresses[n] for n in ("StreamModuleRegistry", "StreamCore", METADATA))
        module_type, = self.call(METADATA, "streamModuleType")
        version, = self.call(METADATA, "streamModuleVersion")
        interface, = self.call(METADATA, "streamModuleInterfaceId")
        uri, manifest_hash = self.call(METADATA, "streamModuleManifest")
        runtime = keccak256(hex_bytes(self.rpc("eth_getCode", [target, "latest"])))
        item = (target, module_type, version, interface, 2000000, runtime, self.deployment, manifest_hash, uri)
        chain, count = self.call("StreamModuleRegistry", "registrationChainHash")
        record_hash = h(("bytes32", "address", "bytes32", "bytes4", "bytes32", "bytes32", "bytes32", "bytes32"),
            (schema_id("6529STREAM_MODULE_REGISTRATION_RECORD_V1"), target, module_type, interface, version, runtime, self.deployment, manifest_hash))
        next_chain = h(("bytes32", "uint256", "address", "uint256", "bytes32", "bytes32", "bytes32", "uint64"),
            (schema_id("6529STREAM_RECORD_CHAIN_V1"), 31337, registry, 0, schema_id("MODULE_REGISTRATION"), chain, record_hash, count))
        kinds = ("uint8", "bytes32", "bytes32", "bytes4", "uint32", "bytes32", "bytes32", "bytes32", "bytes32", "uint64")
        empty = h(kinds, (0, ZERO, ZERO, "0x00000000", 0, ZERO, ZERO, ZERO, keccak256(b""), 0))
        facts = h(kinds, (1, module_type, version, interface, 2000000, runtime, self.deployment, manifest_hash, keccak256(uri.encode()), 1))
        scope = h(("bytes32", "uint256", "address", "address"), (schema_id("6529STREAM_MODULE_REGISTRATION_SCOPE_V1"), 31337, registry, target))
        kinds = ("bytes32", "bytes32", "bool", "bytes32", "uint256", "bytes32", "uint64", "address")
        old = h(kinds, (schema_id("6529STREAM_MODULE_REGISTRATION_STATE_V1"), scope, False, empty, count, chain, count, ZERO_ADDRESS))
        new = h(kinds, (schema_id("6529STREAM_MODULE_REGISTRATION_STATE_V1"), scope, True, facts, count+1, next_chain, count+1, target))
        self.governed("StreamModuleRegistry", "registerModule", (item,), (scope, old, new))
        previous = self.call("StreamCore", "getSatellitePointer", (module_type,))
        candidate = (target, runtime, False, module_type, interface, registry, 1, manifest_hash, self.deployment, previous[-1]+1)
        scope = h(("bytes32", "uint256", "address", "bytes32"), ("0xf4a381d3d4c51db07c19830799ea01c544326118ea1db1fb59d54af5f637bdbb", 31337, core, module_type))
        old, = self.call("StreamCoreExternalReads", "pointerStateHash", (scope, previous, previous[-1]))
        new, = self.call("StreamCoreExternalReads", "pointerStateHash", (scope, candidate, candidate[-1]))
        data = self.data("StreamCore", "updateSatellitePointer", (module_type, target))
        pointer, digest = self.manifest_payload(dumps({"purpose": "actual local Metadata pointer selection", "target": target, "runtimeHash": runtime}))
        tail, tail_data = self.publication(pointer, digest, collection_metadata=target)
        self.govern(3, [self.operation(core, data, (scope, old, new)), tail], [hex_bytes(data), tail_data])
        require(self.call("StreamCore", "getSatellitePointer", (module_type,)) == candidate, "actual selected Metadata pointer differs")

    def after_media_publications(self):
        super().after_media_publications()
        self.deploy_metadata_dependencies()
        self.select_metadata()
        self.extend_actions(METADATA, ["admitRecordType", "setFamilyWriter"])
        for name, kind, raw in ((SCHEMA_NAME, 0, SCHEMA_BYTES), (PROFILE_NAME, 2, PROFILE_BYTES), (RIGHT_NAME, 0, SCHEMAS[RIGHT_NAME])):
            self.register_document(name, kind, raw, JCS_ID)
        values = (RECORD_TYPE, RIGHTS_FAMILY, 0x0180)
        self.governed(METADATA, "admitRecordType", values, self.call(METADATA, "recordTypeTransition", values))
        sid = subject_id("collection", "31337", self.addresses["StreamCore"], "1")
        self.rights_records, self.selected_rights, self.controls = [], [], []
        for cls in (7, 8):
            actor = self.safe(740+cls)
            raw = fixture_rights(sid, cls)
            uri = "https://example.org/local-rights/class-" + str(cls) + ".json"
            record = (RECORD_TYPE, sid, (1, hex_bytes(keccak256(raw)), JCS_ID), uri, schema_id(SCHEMA_NAME), ZERO, (0, b"", ZERO), 1789171200)
            data = self.data(METADATA, "recordCollectionRecordWithPayload", (1, record, raw))
            before_nonce, = self.read(actor, "nonce()", outputs=("uint256",))
            try: self.safe_call(actor, self.addresses[METADATA], data)
            except MuseumError:
                require(self.receipts[-1]["receipt"]["status"] == "0x0", "grant denial must be an actual failed transaction")
            else: raise MuseumError("ungranted RIGHTS publication succeeded")
            failed_safe_transaction = self.receipts[-1]["transaction"]
            require(self.read(actor, "nonce()", outputs=("uint256",)) == (before_nonce,), "denial consumed actual Safe nonce")
            grant = (1, RIGHTS_FAMILY, cls, actor, True)
            self.governed(METADATA, "setFamilyWriter", grant, self.call(METADATA, "familyWriterTransition", grant))
            expected, = self.call(METADATA, "deriveCollectionRecordHashFor", (actor, 1, record))
            require(expected == generic_hash(31337, self.addresses[METADATA], self.addresses["StreamCore"], 1, actor, record), "independent original RIGHTS preimage differs")
            self.safe_call(actor, self.addresses[METADATA], data)
            require(self.receipts[-1]["transaction"] == failed_safe_transaction, "retry must retain byte-identical complete Safe transaction")
            saved, receipt = self.call(METADATA, "collectionRecord", (expected,))
            _, payload = self.call(METADATA, "recordPayload", (expected,))
            require(saved == record and payload == raw and receipt[1:3] == (actor, cls), "actual RIGHTS receipt/payload differs")
            self.rights_records.append({"recordHash": expected, "collectionId": "1", "kind": "collection", "tokenId": "0"})
            link = {"version": "1", "metadataRecordHash": expected, "rights": {"rightsId": schema_id("local RIGHTS class " + str(cls)),
                "rightsBasis": schema_id("unspecified"), "rightsURI": uri, "rightsHash": keccak256(raw), "validFrom": "1789171200", "validUntil": "0"}, "objectIds": [OBJECT_ID]}
            selector, _ = self.publish(dumps(link), schema_id(RIGHT_NAME), JCS_ID, self.next_preservation_nonce)
            self.next_preservation_nonce += 1; self.selected_rights.append(selector)
            self.controls.append({"class": cls, "account": actor, "recordHash": expected, "ungrantedFailed": True, "identicalSafeCallRetried": True})
            if cls == 7:
                grant = (1, RIGHTS_FAMILY, cls, actor, False)
                self.governed(METADATA, "setFamilyWriter", grant, self.call(METADATA, "familyWriterTransition", grant))
                self.revoked_actor, self.revoked_data = actor, data
        # Original immutable receipt remains readable after revocation; a new effectiveAt is denied.
        record = list(self.call(METADATA, "collectionRecord", (self.rights_records[0]["recordHash"],))[0]); record[-1] += 1
        raw = fixture_rights(sid, 7)
        try: self.transact(METADATA, "recordCollectionRecordWithPayload", (1, tuple(record), raw), safe=self.revoked_actor)
        except MuseumError: require(self.receipts[-1]["receipt"]["status"] == "0x0", "revocation requires failed transaction")
        else: raise MuseumError("revoked writer created new RIGHTS record")

    def extra_capture_evidence(self):
        return super().extra_capture_evidence() | {"metadataRightsQualification": QUALIFICATION,
            "metadataRightsRecords": self.rights_records, "metadataRightsControls": self.controls,
            "artistDependency": self.artist_dependency}


def export_rights(fixture, output):
    from .recorded_projection import replay_source_bytes
    from .package_recorded import INPUT_FILES
    from .package import write_package
    from .package_v2 import verify_package
    from .resource_package import build_resource_package
    from .review import _selector
    output = Path(output); evidence = (output / "deployment-evidence.json").read_bytes()
    base_anchor = loads((output / "anchor.json").read_bytes(), maximum=524288)
    anchor = {key: base_anchor[key] for key in ("chainId", "blockHash", "blockNumber", "timestamp", "stateRoot", "environment", "deploymentEvidenceHash", "core", "schemas", "store", "codePins")}
    anchor.update(profile=SOURCE_PROFILE, host=fixture.addresses[METADATA], records=fixture.rights_records)
    anchor_raw = dumps(anchor); reader = MetadataRightsSource(anchor_raw, RpcTransport(fixture.endpoint), provenance="trusted_rpc")
    snapshot = reader.snapshot(); transcript = reader.reader.transcript()
    replay = MetadataRightsSource(anchor_raw, ReplayTransport(transcript, keccak256(transcript)), provenance="trusted_rpc")
    require(replay.snapshot() == snapshot, "actual Metadata RIGHTS replay differs")
    inputs = {"anchor.json": anchor_raw, "transcript.json": transcript, "deployment-evidence.json": evidence}
    right_pins = {"anchorHash": keccak256(anchor_raw), "transcriptHash": keccak256(transcript), "sourceHash": keccak256(snapshot)}
    folder = output / "metadata-rights"; folder.mkdir()
    for name, raw in inputs.items(): (folder / name).write_bytes(raw)
    (folder / "source-capture.json").write_bytes(snapshot); (folder / "pins.json").write_bytes(dumps(right_pins))
    return export_rights_package(output)


def export_rights_package(output):
    """Finish from original captured bytes only; no RPC, native deployment or inferred metadata."""
    from .recorded_projection import replay_source_bytes
    from .package_recorded import INPUT_FILES
    from .package import write_package
    from .package_v2 import verify_package
    from .resource_package import build_resource_package
    from .review import _selector
    output = Path(output)
    inputs = {name: (output / "metadata-rights" / name).read_bytes() for name in ("anchor.json", "transcript.json", "deployment-evidence.json")}
    right_pins = loads((output / "metadata-rights/pins.json").read_bytes(), canonical=True)
    evidence = loads(inputs["deployment-evidence.json"], maximum=16777216, canonical=True)
    pins = loads((output / "pins.json").read_bytes(), maximum=524288)
    source = replay_source_bytes(ROOT, {name: (output / name).read_bytes() for name in INPUT_FILES},
        **{key + "_hash": pins[key + "_hash"] for key in ("source", "publication", "interpretation", "profile")})
    rights = [_selector(r, "") for r in source.state.records if r.selector.schema_id == schema_id(RIGHT_NAME)]
    objects = [_selector(r, "") for r in source.state.records if r.selector.schema_id == schema_id(OBJECT_NAME)]
    require(len(rights) == 2 and len(objects) == 1, "actual rights/object selector inventory differs")
    plan = dumps({"mode": MODE, "version": "1", "sourceStateHash": source.state.commitment, "accountProfileHash": source.profile_hash,
        "resourceProfileHash": RESOURCE_HASH, "rightsSourceHash": right_pins["sourceHash"], "objects": objects, "rights": rights})
    result = build_resource_package(output / "package", pins["package_manifest"], plan, plan_hash=keccak256(plan), profile_hash=RESOURCE_HASH,
        rights_inputs=inputs, rights_pins=right_pins, disclosure="public")
    from lxml import etree
    xml = etree.fromstring(dict(result.files)["premis-resources/premis.xml"])
    require(len(xml.findall(".//{" + NS + "}rightsStatement")) == 2, "two original RIGHTS statements required")
    write_package(result, output / "rights-package"); verify_package(output / "rights-package", result.manifest_hash)
    report = {"mode": "actual_current_metadata_rights_capture_v1", "manifestHash": result.manifest_hash, "rightsPins": right_pins,
        "metadataRightsCaptured": True, "receiptClasses": [7, 8], "offlinePackageVerified": True, "controls": evidence["metadataRightsControls"],
        "revokedWriterRejected": True, "qualification": QUALIFICATION, "artistDependency": evidence["artistDependency"]}
    (output / "rights-result.json").write_bytes(dumps(report))
    return result.manifest_hash


def capture(fixture, output):
    capture_preservation(fixture, output)
    return export_rights(fixture, output)


def main():
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "replay":
        import argparse
        parser = argparse.ArgumentParser(description="Complete the RIGHTS derivative from retained local source bytes without RPC")
        parser.add_argument("directory", type=Path)
        args = parser.parse_args(sys.argv[2:])
        print(export_rights_package(args.directory))
    else:
        run_main(fixture_type=CurrentRightsFixture, capture_function=capture)


if __name__ == "__main__": main()
