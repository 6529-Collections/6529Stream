// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./PreservationReferenceDependencies.sol";
import "./PreservationNativeFixture.sol";

/// @dev Root 8b7b5822 fields/setup/helpers copied; visibility widened solely for test reuse.
/// The native _root hook is virtual solely to retain real original Artist archive bytes.
abstract contract PreservationReferenceFixture is PreservationNativeFixture {
    PreservationReferenceVm internal constant fixtureVm =
        PreservationReferenceVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    StreamExternalArtifactCoverage internal archiveHost;
    StreamArweaveObjectCheckpointVerifier internal archiveVerifier;
    StreamRoleRegistry internal archiveRoles;
    OfficialSafe internal archiveAgentSafe;
    OfficialSafe internal archiveFixitySafe;
    uint256[] internal archiveAgentKeys;
    uint256[] internal archiveFixityKeys;
    uint256 internal constant OBSERVER_A = 0x652921;
    uint256 internal constant OBSERVER_B = 0x652922;
    uint256 internal constant SECOND_AGENT = 0x652925;
    E.ObjectIdentity internal archiveObject;
    bytes32 internal archiveObjectHash;
    bytes32 internal archiveCheckpointHash;
    bytes32 internal archiveTransactionId;
    bytes32 internal archiveFirstFamily;
    bytes32 internal archiveSecondFamily;
    bytes internal archiveFirstPath;
    bytes internal archiveLastPath;
    StreamReferenceRenderPublication internal referenceHost;
    StreamReferenceRenderTypes.Publication internal terms;
    bytes32[3] internal originalFirstReceipts;
    bytes32[3] internal originalSecondReceipts;

    function setUp() public virtual override {
        super.setUp();
        archiveRoles = _createArchiveRoles();
        cheat.mockCall(
            address(executor),
            abi.encodeWithSignature("roleRegistry()"),
            abi.encode(address(archiveRoles))
        );
        cheat.mockCall(
            core.selected(keccak256("MODULE_REGISTRY")),
            abi.encodeWithSignature("governanceExecutor()"),
            abi.encode(address(executor))
        );
        A.Observer[] memory observers = new A.Observer[](2);
        observers[0] = A.Observer(safeVm.addr(OBSERVER_A), keccak256("observer-one"));
        observers[1] = A.Observer(safeVm.addr(OBSERVER_B), keccak256("observer-two"));
        if (observers[0].account > observers[1].account) {
            (observers[0], observers[1]) = (observers[1], observers[0]);
        }
        archiveVerifier = new StreamArweaveObjectCheckpointVerifier(
            address(executor),
            observers,
            2,
            IStreamGasParameterHost.GasParameterConfig(
                "ARCHIVAL_ERC1271_VERIFY_GAS", 400000, 90000, 2
            )
        );
        archiveHost = new StreamExternalArtifactCoverage(
            address(core),
            address(executor),
            address(archiveRoles),
            address(archiveVerifier),
            IStreamGasParameterHost.GasParameterConfig(
                "EXTERNAL_ARCHIVE_READ_GAS", 300000, 150000, 2
            ),
            IStreamGasParameterHost.GasParameterConfig(
                "EXTERNAL_ARCHIVE_SIGNATURE_GAS", 400000, 90000, 2
            )
        );
        SafeComponents memory components = deploySafeComponents("1.4.1");
        archiveAgentKeys.push(0x652931);
        archiveAgentKeys.push(0x652932);
        archiveFixityKeys.push(0x652933);
        archiveFixityKeys.push(0x652934);
        archiveAgentSafe =
            createOfficialSafe(components, safeOwnerAddresses(archiveAgentKeys), 2, 131);
        archiveFixitySafe =
            createOfficialSafe(components, safeOwnerAddresses(archiveFixityKeys), 2, 132);
        _extRole(address(archiveFixitySafe), true);
        archiveFirstFamily = _extAdmit(
            "arweave-object", _extFamily("arweave-object", true, address(archiveAgentSafe))
        );
        archiveSecondFamily = _extAdmit(
            "institution-object", _extFamily("institution-object", false, safeVm.addr(SECOND_AGENT))
        );
        _registerReferenceDefinitions();
        StreamSnapshotTypes.NativeFacts memory native =
            StreamSnapshotSourceReads.requireCurrent(_dependencies(), 1);
        StreamReferenceRenderTypes.RendererDeclaration memory declaration =
            StreamReferenceRenderTypes.RendererDeclaration(
                native.serving.renderer,
                native.serving.rendererCodeHash,
                native.routerVersion,
                native.routerManifestHash,
                native.presentationProfile,
                native.rendererContext,
                native.dependencyProfile,
                keccak256("STATIC")
            );
        bytes memory catalog = StreamReferenceRendererCatalog.declarationJSON(declaration);
        _snapshotDocument(
            "STREAM_REFERENCE_RENDERER_CLASS_FIXTURE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            catalog
        );
        StreamReferenceRenderTypes.Dependencies memory d;
        d.targets = [
            address(core),
            address(metadata),
            address(schemas),
            address(store),
            address(router),
            address(snapshots),
            address(archiveHost)
        ];
        for (uint256 i; i < 7; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.rendererCatalogId = keccak256("STREAM_REFERENCE_RENDERER_CLASS_FIXTURE_V1");
        d.rendererCatalogHash = keccak256(catalog);
        d.rendererCatalogBytes = uint32(catalog.length);
        d.readGas = 500000;
        d.sourceGas = 4000000;
        d.snapshotGas = 6000000;
        d.archiveGas = 2000000;
        IStreamGasParameterHost.GasParameterConfig[4] memory configs;
        configs[0] = _gas("REFERENCE_READ_GAS", d.readGas, 1);
        configs[1] = _gas("REFERENCE_SOURCE_GAS", d.sourceGas, 1);
        configs[2] = _gas("REFERENCE_SNAPSHOT_GAS", d.snapshotGas, 1);
        configs[3] = _gas("REFERENCE_ARCHIVE_GAS", d.archiveGas, 1);
        referenceHost = new StreamReferenceRenderPublication(d, address(executor), configs);
        _curator(address(this), 3, true);
        _terms();
    }

    function _createArchiveRoles() internal virtual returns (StreamRoleRegistry) {
        return new StreamRoleRegistry(address(executor));
    }

    function _registerReferenceDefinitions() internal {
        string[8] memory names = [
            "STREAM_NATIVE_REFERENCE_RENDER_V1",
            "STREAM_NATIVE_REFERENCE_RENDER_JSON_PROFILE_V1",
            "STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1",
            "STREAM_REFERENCE_PNG_OBJECT_V1",
            "STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1",
            "STREAM_REFERENCE_NATIVE_FORMATS_V1",
            "STREAM_RENDERER_CLASS_DECLARATION_V1",
            "STREAM_RENDERER_CLASS_DECLARATION_JSON_PROFILE_V1"
        ];
        for (uint256 i; i < 8; ++i) {
            _snapshotDocument(
                names[i],
                (i == 1 || i == 5 || i == 7)
                    ? IStreamSchemaRegistry.DocumentKind.CATALOG
                    : IStreamSchemaRegistry.DocumentKind.SCHEMA,
                bytes(vm.readFile(string.concat("schemas/records/", names[i], ".json")))
            );
        }
    }

    function _curator(address actor, uint8 cls, bool enabled) internal {
        uint256 cid = cls == 8 ? 0 : 1;
        (bytes32 s, bytes32 o, bytes32 n) =
            metadata.familyWriterTransition(cid, StreamRecordFamilies.CURATOR, cls, actor, enabled);
        executor.execute(
            address(metadata),
            abi.encodeCall(
                metadata.setFamilyWriter, (cid, StreamRecordFamilies.CURATOR, cls, actor, enabled)
            ),
            s,
            o,
            n
        );
    }

    function _loadObject(string memory json, string memory prefix, bool runtime)
        internal
        returns (bytes32 hash, bytes32 coverageHash)
    {
        archiveObject = E.ObjectIdentity(
            keccak256("artist"),
            runtime
                ? StreamReferenceRenderDefinitions.ZIP_SCHEMA_ID
                : StreamReferenceRenderDefinitions.PNG_SCHEMA_ID,
            keccak256("RAW_BYTES"),
            bytes32(safeVm.parseJsonBytes(json, string.concat(prefix, ".contentHash"))),
            bytes32(safeVm.parseJsonBytes(json, string.concat(prefix, ".sha256Digest"))),
            bytes32(safeVm.parseJsonBytes(json, string.concat(prefix, ".arweaveDataRoot"))),
            uint64(fixtureVm.parseJsonUint(json, string.concat(prefix, ".byteSize"))),
            runtime ? keccak256("IANA:application/zip") : keccak256("IANA:image/png"),
            StreamReferenceRenderDefinitions.FORMAT_CATALOG_ID,
            StreamReferenceRenderDefinitions.FORMAT_CATALOG_HASH
        );
        archiveFirstPath = safeVm.parseJsonBytes(json, string.concat(prefix, ".firstDataPath"));
        archiveLastPath = safeVm.parseJsonBytes(json, string.concat(prefix, ".lastDataPath"));
        hash = archiveHost.recordObject(archiveObject);
        archiveObjectHash = hash;
        A.Checkpoint memory cp = _extCheckpointTerms();
        cp.transactionId = keccak256(abi.encode("actual reference object", hash));
        archiveTransactionId = cp.transactionId;
        archiveCheckpointHash = archiveVerifier.recordCheckpoint(
            cp,
            abi.encode(cp.dataRoot, uint256(cp.dataSize)),
            archiveFirstPath,
            archiveLastPath,
            _extCertificate(cp)
        );
        bytes32 a = _extRecordReceipt(true, uint256(hash));
        bytes32 b = _extRecordReceipt(false, uint256(hash));
        _extRecordFixity(a, 1, false);
        _extRecordFixity(b, 1, false);
        coverageHash = archiveHost.recordCoverage(a, b);
    }

    function _terms() internal {
        string memory json =
            vm.readFile("test/fixtures/preservation/reference-actual-native-v1.json");
        StreamReferenceRenderTypes.Environment memory env;
        (env.objectHash, env.coverageHash) = _loadObject(
            vm.readFile("test/fixtures/preservation/reference-browser-object-v1.json"), "", true
        );
        E.Coverage memory cover = archiveHost.coverage(env.coverageHash);
        originalFirstReceipts[0] = cover.firstReceiptHash;
        originalSecondReceipts[0] = cover.secondReceiptHash;
        env.engineName = "Google Chrome";
        env.engineVersion = "152.0.7977.83";
        env.engineExecutableSha256 = bytes32(safeVm.parseJsonBytes(json, ".engineExecutableSha256"));
        env.engineExecutablePath = "engine/chrome.exe";
        env.toolchainName = "reference_capture.py; Python; websockets";
        env.toolchainVersion = "STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1; 3.12.10; 15.0.1";
        env.toolchainSha256 = bytes32(safeVm.parseJsonBytes(json, ".toolchainSha256"));
        env.toolchainPath = "tool/reference_capture.py";
        env.packageFiles = abi.decode(
            safeVm.parseJsonBytes(json, ".packageFilesABI"),
            (StreamReferenceRenderTypes.PackageFile[])
        );
        env.platformPrerequisites = abi.decode(
            safeVm.parseJsonBytes(json, ".platformPrerequisitesABI"),
            (StreamReferenceRenderTypes.PackageFile[])
        );
        env.operatingSystem = "Windows";
        env.operatingSystemVersion = fixtureVm.parseJsonString(json, ".operatingSystemVersion");
        env.architecture = "AMD64";
        env.viewportWidth = 64;
        env.viewportHeight = 64;
        env.devicePixelRatio = 1;
        env.colorSpace = "srgb";
        env.softwareRasterization = true;
        env.captureProfile = keccak256("STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1");
        env.licenseNote = fixtureVm.parseJsonString(json, ".licenseNote");
        bytes memory environment = StreamReferenceEnvironmentJson.manifest(env);
        env.manifestHash = keccak256(environment);
        env.manifestBytes = uint32(environment.length);
        StreamReferenceRenderTypes.Publication memory p;
        p.collectionId = 1;
        p.referenceId = keccak256("actual first and last native reference");
        (p.snapshotRecordHash,) = _publish(address(this));
        p.snapshotRevision = 1;
        p.environment = env;
        p.reasonHash = keccak256("actual source export and repeated capture");
        p.effectiveAt = 1000;
        p.manifestURI = "ipfs://local-fixture-reference-manifest";
        p.captures = new StreamReferenceRenderTypes.Capture[](2);
        for (uint256 i; i < 2; ++i) {
            string memory prefix = i == 0 ? ".capture1" : ".capture2";
            StreamReferenceRenderTypes.Capture memory c;
            c.tokenId = i + 1;
            c.collectionSerial = i + 1;
            c.animationHTML = safeVm.parseJsonBytes(json, string.concat(prefix, ".html"));
            c.htmlHash = keccak256(c.animationHTML);
            c.htmlBytes = uint32(c.animationHTML.length);
            c.sourceSha256 = sha256(c.animationHTML);
            c.metadataJSONHash =
                keccak256(bytes(router.historicalTokenMetadataJSON(address(core), i + 1)));
            (c.objectHash, c.coverageHash) = _loadObject(json, prefix, false);
            cover = archiveHost.coverage(c.coverageHash);
            originalFirstReceipts[i + 1] = cover.firstReceiptHash;
            originalSecondReceipts[i + 1] = cover.secondReceiptHash;
            c.repeatCaptureSha256 = [cover.sha256Digest, cover.sha256Digest];
            c.environmentManifestHash = env.manifestHash;
            c.capturedAt = 1000;
            p.captures[i] = c;
        }
        bytes memory packageJSON =
            bytes(StreamReferenceEnvironmentJson.files(env.packageFiles, true));
        bytes memory platformJSON =
            bytes(StreamReferenceEnvironmentJson.files(env.platformPrerequisites, false));
        _upload(packageJSON);
        _upload(platformJSON);
        referenceHost.prepareFileInventory(env.packageFiles, true);
        referenceHost.prepareFileInventory(env.platformPrerequisites, false);
        terms = p;
    }

    function _referencePublish(address actor) internal returns (bytes32 hash) {
        StreamReferenceRenderTypes.Publication memory p = terms;
        (p.expectedSourcesHash,) = referenceHost.previewReference(p, actor);
        (, bytes memory raw) = referenceHost.previewReference(p, actor);
        _upload(raw);
        _upload(abi.encode(p));
        bytes memory input = abi.encodeCall(referenceHost.publishReference, (p));
        vm.prank(actor);
        uint256 before = gasleft();
        (bool ok, bytes memory result) = address(referenceHost).call{ gas: 16000000 }(input);
        uint256 used = before - gasleft();
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        hash = abi.decode(result, (bytes32));
        emit log_named_uint("referencePublishCalleeGas", used);
    }

    function _lockReference() internal {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = referenceHost.lockTransition(1);
        cheat.mockCall(
            address(executor),
            abi.encodeCall(IStreamGovernedParameterAuthority.currentAction, ()),
            abi.encode(
                true, keccak256("reference terminal action"), uint8(2), scope, oldHash, newHash
            )
        );
        vm.prank(address(executor));
        referenceHost.lockReference(1);
    }

    function _referenceConsumer() internal returns (PreservationReferenceConsumer) {
        StreamFinalityReferenceReads.Dependencies memory d;
        d.core = address(core);
        d.metadata = address(metadata);
        d.referencePublisher = address(referenceHost);
        d.metadataRouter = address(router);
        d.snapshots = address(snapshots);
        d.coreCodeHash = address(core).codehash;
        d.metadataCodeHash = address(metadata).codehash;
        d.referenceCodeHash = address(referenceHost).codehash;
        d.routerCodeHash = address(router).codehash;
        d.snapshotsCodeHash = address(snapshots).codehash;
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.validationGas = 10000000;
        return new PreservationReferenceConsumer(d);
    }

    function _extSign(uint256 key, bytes32 digest) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = safeVm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _extCheckpointTerms() internal view returns (A.Checkpoint memory c) {
        c.networkId = archiveVerifier.networkId();
        c.configurationHash = archiveVerifier.configurationHash();
        c.blockHash = new bytes(48);
        c.blockHash[0] = 0x65;
        c.blockHeight = 1;
        c.transactionId =
            keccak256("explicit local quorum network fixture for complete browser object");
        c.dataRoot = archiveObject.arweaveDataRoot;
        c.dataSize = archiveObject.byteSize;
        c.transactionRoot = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(c.dataRoot)), sha256(abi.encode(uint256(c.dataSize)))
            )
        );
        c.transactionEnd = c.dataSize;
        c.blockDataSize = c.dataSize;
        c.observedAt = uint64(block.timestamp);
    }

    function _extCertificate(A.Checkpoint memory c) internal returns (A.ObserverProof[] memory p) {
        bytes32 digest = archiveVerifier.checkpointDigest(c);
        p = new A.ObserverProof[](2);
        p[0] = A.ObserverProof(safeVm.addr(OBSERVER_A), _extSign(OBSERVER_A, digest));
        p[1] = A.ObserverProof(safeVm.addr(OBSERVER_B), _extSign(OBSERVER_B, digest));
        if (p[0].account > p[1].account) (p[0], p[1]) = (p[1], p[0]);
    }

    function _extFamily(string memory name, bool endowed, address agent)
        internal
        view
        returns (A.Family memory)
    {
        bytes memory salt = bytes(endowed ? "one" : "two");
        return A.Family(
            keccak256(bytes(name)),
            endowed ? archiveVerifier.networkId() : keccak256("INSTITUTIONAL_ARCHIVE"),
            keccak256(bytes.concat(salt, "protocol")),
            keccak256(bytes.concat(salt, "addressing")),
            keccak256(bytes.concat(salt, "custodian")),
            keccak256(bytes.concat(salt, "funding")),
            keccak256(bytes.concat(salt, "retrieval")),
            keccak256("same jurisdiction allowed"),
            endowed ? 1 : 2,
            agent,
            endowed ? archiveVerifier.profileHash() : archiveHost.POSSESSION_PROFILE()
        );
    }

    function _extAdmit(string memory name, A.Family memory f) internal returns (bytes32 hash) {
        bytes32 scope;
        bytes32 oldHash;
        bytes32 newHash;
        (hash, scope, oldHash, newHash) = archiveHost.familyRegistrationContext(name, f);
        require(
            abi.decode(
                executor.execute(
                    address(archiveHost),
                    abi.encodeCall(archiveHost.admitFamily, (name, f)),
                    scope,
                    oldHash,
                    newHash
                ),
                (bytes32)
            ) == hash
        );
    }

    function _extStatus(bytes32 hash, uint8 status) internal {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            archiveHost.familyStatusContext(hash, status);
        executor.execute(
            address(archiveHost),
            abi.encodeCall(archiveHost.setFamilyStatus, (hash, status)),
            scope,
            oldHash,
            newHash
        );
    }

    function _extReceipt(bool first, uint256 nonce)
        internal
        virtual
        returns (E.Receipt memory r, bytes memory id)
    {
        id = first
            ? abi.encodePacked(archiveTransactionId)
            : bytes(
                "https://institution.example.invalid/objects/sha256/d2eabd7dffeed4f37632e9e8d5a861d7fe5df621d66e62cd43234ecb9a572417"
            );
        r = E.Receipt(
            archiveObjectHash,
            first ? archiveFirstFamily : archiveSecondFamily,
            keccak256(id),
            keccak256(bytes(first ? "CONTENT_ADDRESSED_INCLUSION" : "ATTESTED_POSSESSION")),
            first ? archiveVerifier.profileHash() : archiveHost.POSSESSION_PROFILE(),
            first ? archiveCheckpointHash : bytes32(0),
            first ? address(archiveAgentSafe) : safeVm.addr(SECOND_AGENT),
            uint64(block.timestamp),
            nonce,
            uint64(block.timestamp + 1 days)
        );
        if (!first) r.proofRecordHash = archiveHost.possessionHash(r);
    }

    function _extRecordReceipt(bool first, uint256 nonce) internal returns (bytes32 hash) {
        (E.Receipt memory r, bytes memory id) = _extReceipt(first, nonce);
        bytes memory sig = first
            ? safeThresholdSignature(
                archiveAgentKeys,
                safeMessageDigest(archiveAgentSafe, abi.encodePacked(archiveHost.receiptDigest(r)))
            )
            : _extSign(SECOND_AGENT, archiveHost.receiptDigest(r));
        return archiveHost.recordReceipt(r, id, sig);
    }

    function _extFixity(bytes32 receiptHash, uint8 outcome)
        internal
        view
        returns (E.Fixity memory f)
    {
        (E.Receipt memory r,,) = archiveHost.receipt(receiptHash);
        f.receiptHash = receiptHash;
        f.objectHash = r.objectHash;
        f.familyRecordHash = r.familyRecordHash;
        f.storageIdentifierHash = r.storageIdentifierHash;
        f.profileHash = archiveHost.FIXITY_PROFILE();
        E.ObjectIdentity memory originalObject = archiveHost.objectIdentity(r.objectHash);
        f.expectedSha256 = originalObject.sha256Digest;
        f.expectedKeccak256 = originalObject.contentHash;
        f.expectedArweaveRoot = originalObject.arweaveDataRoot;
        f.expectedSize = originalObject.byteSize;
        if (outcome == 1) {
            f.observedSha256 = originalObject.sha256Digest;
            f.observedKeccak256 = originalObject.contentHash;
            f.observedArweaveRoot = originalObject.arweaveDataRoot;
            f.observedSize = originalObject.byteSize;
        }
        f.checkedAt = uint64(block.timestamp);
        f.outcome = outcome;
        f.reportHash = keccak256("full locally retrieved original package fixity report fixture");
        f.previousFixityHash = archiveHost.latestFixity(receiptHash);
        f.verifier = address(archiveFixitySafe);
        f.deadline = uint64(block.timestamp + 1 days);
        f.nonce = uint256(f.previousFixityHash);
    }

    function _extRecordFixity(bytes32 receiptHash, uint8 outcome, bool repair)
        internal
        returns (bytes32)
    {
        E.Fixity memory f = _extFixity(receiptHash, outcome);
        if (repair) f.repairReportHash = keccak256("repair report");
        return archiveHost.recordFixity(
            f,
            safeThresholdSignature(
                archiveFixityKeys,
                safeMessageDigest(archiveFixitySafe, abi.encodePacked(archiveHost.fixityDigest(f)))
            )
        );
    }

    function _extCovered() internal returns (bytes32 first, bytes32 second, bytes32 hash) {
        first = _extRecordReceipt(true, 0);
        second = _extRecordReceipt(false, 0);
        _extRecordFixity(first, 1, false);
        _extRecordFixity(second, 1, false);
        hash = archiveHost.recordCoverage(first, second);
    }

    function _extFails(address target, bytes memory data) internal {
        (bool ok,) = target.call(data);
        require(!ok, "expected rejection");
    }

    function _extRole(address holder, bool granted) internal {
        bytes32 role = keccak256("ROLE_FIXITY_OPERATOR");
        (bytes32 chain, uint64 revision) = archiveRoles.roleMutationState(role);
        (bytes32 globalChain, uint64 globalRevision) = archiveRoles.globalRoleMutationState();
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_SCOPE_V1"),
                block.chainid,
                address(archiveRoles),
                role,
                holder
            )
        );
        bytes32 nextChain = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_V1"),
                chain,
                block.chainid,
                address(archiveRoles),
                role,
                holder,
                granted,
                revision + 1
            )
        );
        bytes32 nextGlobal = keccak256(
            abi.encode(
                keccak256("6529STREAM_GLOBAL_ROLE_MUTATION_V1"),
                globalChain,
                block.chainid,
                address(archiveRoles),
                role,
                holder,
                granted,
                globalRevision + 1
            )
        );
        bytes32 oldHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_STATE_V1"),
                block.chainid,
                address(archiveRoles),
                scope,
                !granted,
                chain,
                revision,
                globalChain,
                globalRevision
            )
        );
        bytes32 newHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_STATE_V1"),
                block.chainid,
                address(archiveRoles),
                scope,
                granted,
                nextChain,
                revision + 1,
                nextGlobal,
                globalRevision + 1
            )
        );
        executor.execute(
            address(archiveRoles),
            granted
                ? abi.encodeCall(archiveRoles.grantRole, (role, holder))
                : abi.encodeCall(archiveRoles.revokeRole, (role, holder)),
            scope,
            oldHash,
            newHash
        );
    }
}
