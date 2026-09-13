// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./RouterOriginalCompositionBoundaries.sol";
import "./RouterReplacementRendererHostBoundary.sol";

interface RouterCompositionVm {
    function getCode(string calldata artifact) external view returns (bytes memory);
    function readFile(string calldata path) external view returns (string memory);
}

/// @notice Actual Router, linked rendering, canonical original Registry and companion.
/// @dev Core/Executor, artist/Consent, interpretation registry, archival admission and the
/// authoritative producer remain explicit read boundaries. No full finality authority claim.
contract RouterOriginalCompositionFixture is RecoveryCompanionBoundaryFixture {
    RouterCompositionVm private constant bytesVm =
        RouterCompositionVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    StreamMetadataRouter public router;
    StreamArtworkFinalityRegistry public original;
    StreamArtworkFinalityRecovery public recovery;
    RouterCompositionProviderBoundary public provider;
    CompanionExecutorBoundary public actionHost;
    CompanionDependencyBoundary public metadataHost;
    CompanionDependencyBoundary public entropyHost;
    CompanionDependencyBoundary public definitions;
    ServingArtifactAdmissionBoundary public artifact;
    StreamFinalityComponentExpectation[] private entries;
    StreamFinalityManifestRef private manifest;
    StreamFinalitySanctionArchiveProof private archive;
    bytes32 public originalHash;
    bytes32 public beforeJSON;
    S.Record private savedSanction;

    function initialize() external {
        vm.warp(1000);
        super.setUp();
        actionHost = new CompanionExecutorBoundary();
        executor = CompanionDependencyBoundary(address(actionHost));
        _address(executor, IStreamFinalityGovernanceBindings.roleRegistry.selector, address(roles));
        _address(roles, IStreamFinalityGovernanceBindings.owner.selector, address(executor));
        _address(
            ownerEvidence,
            IStreamFinalityRecoveryOwnerBindings.governanceAuthority.selector,
            address(executor)
        );
        metadataHost = new CompanionDependencyBoundary();
        entropyHost = new CompanionDependencyBoundary();
        _address(metadataHost, bytes4(keccak256("core()")), address(core));
        _address(entropyHost, bytes4(keccak256("core()")), address(core));
        _erc(core, 0x80ac58cd);
        _erc(artist, type(IStreamArtistAttribution).interfaceId);
        _erc(artist, type(IStreamArtistContentRatification).interfaceId);
        _erc(artist, type(IStreamArtistAttributionState).interfaceId);
        _erc(entropyHost, type(IStreamEntropyCoordinator).interfaceId);
        _coreFacts(false);
        _pointer(
            keccak256("ARTIST_REGISTRY"),
            address(artist),
            keccak256("ARTIST_REGISTRY"),
            type(IStreamArtistMintConsent).interfaceId,
            address(artist).codehash
        );
        router = new StreamMetadataRouter(
            address(core),
            address(this),
            keccak256("deployment"),
            "urn:serving:router",
            keccak256("router-manifest"),
            IStreamArtistAttribution(address(artist))
        );
        suite.metadata = address(router);
        coordinator.answer(
            abi.encodeCall(IStreamArtistRecoveryDeployment.suiteConfiguration, ()),
            abi.encode(suite)
        );
        provider = new RouterCompositionProviderBoundary(
            address(core), address(metadataHost), address(router), address(entropyHost)
        );
        artifact = new ServingArtifactAdmissionBoundary();
        definitions = new CompanionDependencyBoundary();
        _address(artifact, IStreamFinalityArtifactCoverage.core.selector, address(core));
        _address(artifact, IStreamGasParameterHost.governanceAuthority.selector, address(executor));
        _address(
            artifact, IStreamFinalityArtifactCoverage.schemaRegistry.selector, address(definitions)
        );
        _deployOriginal();
        finality = CompanionDependencyBoundary(address(original));
        _address(artist, IStreamArtistFinalityBinding.finalityRegistry.selector, address(original));
        _word(
            artist,
            IStreamArtistFinalityBinding.finalityRegistryCodeHash.selector,
            uint256(address(original).codehash)
        );
        _address(
            coordinator,
            IStreamArtistRecoveryDeployment.finalityRegistry.selector,
            address(original)
        );
        _word(
            coordinator,
            IStreamArtistRecoveryDeployment.finalityRegistryCodeHash.selector,
            uint256(address(original).codehash)
        );
        _pointer(
            keccak256("ARTWORK_FINALITY_REGISTRY"),
            address(original),
            keccak256("ARTWORK_FINALITY_REGISTRY"),
            type(IStreamArtworkFinalityRegistry).interfaceId,
            address(original).codehash
        );
        _pointer(
            keccak256("COLLECTION_METADATA"),
            address(metadataHost),
            keccak256("COLLECTION_METADATA"),
            type(IStreamCollectionMetadataV1).interfaceId,
            address(metadataHost).codehash
        );
        _configureRouter();
        beforeJSON = keccak256(bytes(router.tokenMetadataJSON(address(core), 91)));
        _coreFacts(true);
        _configureComponents();
        _finalizeOriginal();
        _deployCompanion();
    }

    function _deployOriginal() private {
        StreamCoreFinalityAdapter adapter =
            new StreamCoreFinalityAdapter(address(core), address(metadataHost), address(provider));
        bytes memory args = abi.encode(
            address(core),
            address(metadataHost),
            address(adapter),
            address(artist),
            address(executor),
            address(provider),
            IStreamGasParameterHost.GasParameterConfig(
                "FINALITY_COMPONENT_READ_GAS", 1000000, 50000, 2
            ),
            StreamFinalityDeploymentConfiguration(
                address(artifact),
                keccak256("deployment"),
                "urn:serving:original",
                keccak256("original-manifest")
            )
        );
        bytes memory init = abi.encodePacked(
            bytesVm.getCode("StreamArtworkFinalityRegistry.sol:StreamArtworkFinalityRegistry"), args
        );
        bytes32 salt = keccak256("actual-original-serving-composition");
        address predicted = address(
            uint160(
                uint256(
                    keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(init)))
                )
            )
        );
        artifact.bind(predicted);
        address deployed;
        assembly ("memory-safe") { deployed := create2(0, add(init, 32), mload(init), salt) }
        require(
            deployed == predicted && deployed.code.length != 0, "actual linked original CREATE2"
        );
        original = StreamArtworkFinalityRegistry(deployed);
    }

    function _coreFacts(bool frozen) private {
        core.answer(abi.encodeWithSignature("collectionExists(uint256)", 1), abi.encode(true));
        core.answer(abi.encodeWithSignature("collectionHasMaxSupply(uint256)", 1), abi.encode(true));
        core.answer(abi.encodeWithSignature("collectionStatus(uint256)", 1), abi.encode(uint8(2)));
        core.answer(
            abi.encodeWithSignature("collectionSupplyMode(uint256)", 1), abi.encode(uint8(0))
        );
        core.answer(
            abi.encodeWithSignature("collectionMaxSupply(uint256)", 1), abi.encode(uint256(1))
        );
        core.answer(
            abi.encodeWithSignature("collectionMintedEver(uint256)", 1),
            abi.encode(frozen ? uint256(1) : uint256(0))
        );
        core.answer(
            abi.encodeWithSignature("collectionNextSerial(uint256)", 1), abi.encode(uint256(2))
        );
        core.answer(
            abi.encodeWithSignature("totalSupplyOfCollection(uint256)", 1),
            abi.encode(frozen ? uint256(1) : uint256(0))
        );
        core.answer(
            abi.encodeWithSignature("collectionBurnsBlocked(uint256)", 1), abi.encode(frozen)
        );
        core.answer(
            abi.encodeWithSignature("collectionFreezeStatus(uint256)", 1), abi.encode(frozen)
        );
        // Constructor canonical empty-scope probe reads collection zero.
        core.answer(abi.encodeWithSignature("collectionExists(uint256)", 0), abi.encode(false));
        core.answer(
            abi.encodeWithSignature("collectionHasMaxSupply(uint256)", 0), abi.encode(false)
        );
        string[6] memory names = [
            "collectionStatus(uint256)",
            "collectionSupplyMode(uint256)",
            "collectionMaxSupply(uint256)",
            "collectionMintedEver(uint256)",
            "collectionNextSerial(uint256)",
            "totalSupplyOfCollection(uint256)"
        ];
        for (uint256 i; i < names.length; ++i) {
            core.answer(
                abi.encodeWithSelector(bytes4(keccak256(bytes(names[i]))), 0),
                abi.encode(uint256(0))
            );
        }
        core.answer(
            abi.encodeWithSignature("tokenCollectionIdentity(uint256)", 91),
            abi.encode(true, uint256(1), uint256(1), false)
        );
        core.answer(abi.encodeWithSignature("tokenLifecycle(uint256)", 91), abi.encode(uint8(2)));
        core.answer(abi.encodeWithSignature("tokenData(uint256)", 91), abi.encode(bytes(hex"1234")));
        core.answer(
            abi.encodeWithSignature("coordinatorAtMint(uint256)", 91),
            abi.encode(address(entropyHost))
        );
        core.answer(abi.encodeWithSignature("lastAllocatedTokenId()"), abi.encode(uint256(0)));
        entropyHost.answer(
            abi.encodeCall(IStreamEntropyView.tokenSeed, (91)),
            abi.encode(keccak256("actual-serving-seed"), true)
        );
        entropyHost.answer(
            abi.encodeWithSignature("tokenEntropyStatus(uint256)", 91),
            abi.encode(StreamEntropyStatus.FINALIZED)
        );
    }

    function _configureRouter() private {
        IStreamCollectionArtistRegistry.Attribution memory a;
        a.artist = address(0xA11CE);
        a.nominatedArtist = address(0xA11CE);
        a.nominationHash = keccak256("binding");
        a.nominationRevision = 3;
        a.identityHash = keccak256("identity");
        a.acceptanceHash = keccak256("acceptance");
        artist.answer(abi.encodeCall(IStreamArtistAttribution.attribution, (1)), abi.encode(a));
        artist.answer(
            abi.encodeCall(IStreamArtistAttributionState.collectionArtistState, (1)),
            abi.encode(uint8(2), uint64(3), keccak256("artist"), uint8(1), keccak256("binding"))
        );
        artist.answer(
            abi.encodeCall(IStreamArtistContentRatification.firstReleaseRatification, (1)),
            abi.encode(false, bytes32(0), bytes32(0))
        );
        router.setCollectionMetadata(1, "Actual original", "Description", "ipfs://image", "");
        router.setCollectionScript(1, "return 6529;");
        router.lockArtistIdentity(1);
        router.lockDisplayMetadata(1);
        bytes32[] memory locks = new bytes32[](3);
        locks[0] = keccak256("SCRIPT");
        locks[1] = keccak256("MEDIA_MANIFEST");
        locks[2] = keccak256("BASE_URI");
        for (uint256 i; i < 3; ++i) {
            for (uint256 j = i + 1; j < 3; ++j) {
                if (locks[j] < locks[i]) (locks[j], locks[i]) = (locks[i], locks[j]);
            }
        }
        bytes32 record = keccak256("explicit artist freeze approval");
        StreamArtistContentTypes.FreezeRecord memory f = StreamArtistContentTypes.FreezeRecord(
            record,
            keccak256("artist"),
            3,
            address(router),
            locks,
            router.artistContentFreezeState(1),
            1
        );
        artist.answer(
            abi.encodeCall(IStreamArtistContentAuthority.contentFreezeAuthorization, (record)),
            abi.encode(f)
        );
        for (uint256 i; i < 3; ++i) {
            artist.answer(
                abi.encodeCall(
                    IStreamArtistContentAuthority.isContentFreezeAuthorized, (1, locks[i])
                ),
                abi.encode(true, record)
            );
        }
        router.applyArtistContentFreeze(1, record);
    }

    function _configureComponents() private {
        bytes32[9] memory kinds = [
            keccak256("COLLECTION_METADATA"),
            keccak256("METADATA_ROUTER"),
            keccak256("RENDERER"),
            keccak256("RENDER_CONTEXT"),
            keccak256("MEDIA_MANIFEST"),
            keccak256("ENTROPY_COORDINATOR"),
            keccak256("SCRIPT_SOURCE"),
            keccak256("DEPENDENCY_SOURCE"),
            keccak256("REFERENCE_RENDER")
        ];
        for (uint256 i; i < 9; ++i) {
            StreamFinalityComponentState memory state;
            if (i == 0 || i == 8) {
                CompanionDependencyBoundary component = new CompanionDependencyBoundary();
                state = StreamFinalityComponentState(
                    true,
                    kinds[i],
                    address(component),
                    type(IStreamArtworkFinalityComponent).interfaceId,
                    address(component).codehash,
                    keccak256("version"),
                    keccak256("manifest"),
                    keccak256(abi.encode(kinds[i], "record boundary"))
                );
                component.answer(
                    abi.encodeCall(IStreamArtworkFinalityComponent.finalityState, (1)),
                    abi.encode(state)
                );
                _erc(component, type(IStreamArtworkFinalityComponent).interfaceId);
            } else {
                StreamFinalityServingHostAdapter a = new StreamFinalityServingHostAdapter(
                    address(core),
                    i == 5 ? address(entropyHost) : address(router),
                    address(provider),
                    kinds[i]
                );
                state = a.finalityState(1);
            }
            entries.push(
                StreamFinalityComponentExpectation(
                    state.componentType,
                    state.component,
                    state.interfaceId,
                    state.codeHash,
                    state.moduleVersion,
                    state.manifestHash,
                    state.dataHash
                )
            );
        }
    }

    function _finalizeOriginal() private {
        bytes memory bytes_ = bytes("{\"scope\":\"actual-target-composition-boundary\"}");
        original.stageFinalityManifest(bytes_);
        manifest = StreamFinalityManifestRef(
            "urn:serving:manifest",
            keccak256("urn:serving:manifest"),
            keccak256(bytes_),
            keccak256("manifest-schema-boundary"),
            keccak256("manifest-canonicalization-boundary")
        );
        _sort();
        bytes32 coreHash = original.computeCollectionCoreFactsHash(1);
        bytes32 subject = original.computeSanctionSubjectHash(
            _scope(), coreHash, original.computeComponentsHash(entries), manifest
        );
        savedSanction = S.Record(
            0,
            keccak256("artist"),
            address(0xA11CE),
            1,
            S.Terms(0, 1, 0, 0, subject, keccak256("ceremony-boundary")),
            1,
            1000,
            2000,
            3,
            keccak256("binding"),
            keccak256("digest-boundary")
        );
        savedSanction.recordHash = StreamArtistSanctionHashes.record(
            StreamArtistHashes.Environment(
                block.chainid, address(artist), address(core), suite.mintManager
            ),
            savedSanction
        );
        CompanionDependencyBoundary(suite.owners[6])
            .answer(
                abi.encodeCall(
                    IStreamArtistSanctionOwner.sanctionRecord, (savedSanction.recordHash)
                ),
                abi.encode(savedSanction)
            );
        StreamFinalityComponentExpectation memory e = StreamFinalityComponentExpectation(
            keccak256("ARTIST_SANCTION"),
            address(artist),
            type(IStreamArtworkFinalityComponent).interfaceId,
            address(artist).codehash,
            keccak256("artist-version"),
            keccak256("artist-manifest"),
            savedSanction.recordHash
        );
        entries.push(e);
        _sort();
        artist.answer(
            abi.encodeCall(IStreamArtworkFinalityComponent.finalityState, (1)),
            abi.encode(
                StreamFinalityComponentState(
                    true,
                    e.componentType,
                    e.component,
                    e.interfaceId,
                    e.codeHash,
                    e.moduleVersion,
                    e.manifestHash,
                    e.dataHash
                )
            )
        );
        _erc(artist, type(IStreamArtworkFinalityComponent).interfaceId);
        artist.answer(
            abi.encodeCall(IStreamFinalitySanctionReads.collectionSanctionComponentType, (1)),
            abi.encode(keccak256("ARTIST_SANCTION"))
        );
        artist.answer(
            abi.encodeCall(
                IStreamFinalitySanctionReads.verifySanctionForSubject,
                (0, 1, 0, bytes32(0), subject)
            ),
            abi.encode(true, savedSanction.recordHash, address(0xA11CE), uint8(1))
        );
        provider.setEntries(entries);
        originalHash = original.computeFinalityRecordHash(
            _scope(), coreHash, original.computeComponentsHash(entries), manifest
        );
        _archiveEvidence();
        StreamFinalityExecutionContext memory c = original.finalityExecutionContextWithArchive(
            _scope(), entries, originalHash, manifest, archive
        );
        bytes32 action = keccak256("explicit original Executor context boundary");
        GovernanceAction memory a;
        a.actionClass = 2;
        a.status = GovernanceActionStatus.EXECUTED;
        a.proposer = address(this);
        a.reasonHash = keccak256("reason");
        executor.answer(
            abi.encodeCall(IStreamGovernanceReads.governanceAction, (action)), abi.encode(a)
        );
        roles.answer(
            abi.encodeCall(
                IStreamRoleRegistry.hasRole,
                (keccak256("ROLE_COLLECTION_FINALITY_ADMIN"), address(this))
            ),
            abi.encode(true)
        );
        roles.answer(
            abi.encodeCall(
                IStreamRoleRegistry.roleMutationState, (keccak256("ROLE_COLLECTION_FINALITY_ADMIN"))
            ),
            abi.encode(keccak256("role-mutation"), uint64(1))
        );
        (bool ok, bytes memory output) = actionHost.run(
            address(original),
            abi.encodeCall(
                original.finalizeCollectionArtworkWithArchive,
                (1, entries, originalHash, manifest, archive)
            ),
            [action, c.scopeHash, c.oldValueHash, c.newValueHash],
            2
        );
        if (!ok) assembly ("memory-safe") { revert(add(output, 32), mload(output)) }
        require(
            original.collectionFinalityRecord(1).finalized
                && original.finalityComponentCount(1) == 10,
            "actual immutable original record"
        );
    }

    function _archiveEvidence() private {
        string[4] memory names = [
            "6529STREAM_ARTIST_SANCTION_ARCHIVE_V1",
            "6529STREAM_ARTIST_SANCTION_ARCHIVE_ABI_V1",
            "6529STREAM_ARTIST_SANCTION_CEREMONY_V1",
            "6529STREAM_ARTIST_SANCTION_CEREMONY_JCS_V1"
        ];
        string[4] memory files = [
            "sanction-archive-v1.schema.json",
            "sanction-archive-abi-v1.json",
            "sanction-ceremony-v1.schema.json",
            "sanction-ceremony-jcs-v1.json"
        ];
        for (uint256 i; i < 4; ++i) {
            bytes memory content =
                bytes(bytesVm.readFile(string.concat("docs/schemas/finality/", files[i])));
            bytes32 id = keccak256(bytes(names[i]));
            IStreamSchemaRegistry.DocumentView memory d;
            d.exists = true;
            d.specification = IStreamSchemaRegistry.DocumentSpec(
                names[i],
                i % 2 == 0
                    ? IStreamSchemaRegistry.DocumentKind.SCHEMA
                    : IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
                keccak256(content),
                keccak256("RAW_BYTES"),
                0,
                "urn:fixture:definition",
                uint32(content.length)
            );
            definitions.answer(abi.encodeCall(IStreamSchemaRegistry.document, (id)), abi.encode(d));
            definitions.answer(
                abi.encodeCall(IStreamSchemaRegistry.documentBytes, (id)), abi.encode(content)
            );
        }
        archive = StreamFinalitySanctionArchiveProof(
            savedSanction.recordHash, keccak256("artifact-boundary"), keccak256("coverage-boundary")
        );
        bytes32 schema = keccak256(bytes(names[0]));
        bytes32 canon = keccak256(bytes(names[1]));
        artist.answer(
            abi.encodeCall(
                IStreamArtistSanctionArchiveFacts.sanctionArchiveFacts, (savedSanction.recordHash)
            ),
            abi.encode(
                IStreamArtistSanctionArchiveFacts.Facts(
                    savedSanction.recordHash,
                    savedSanction.artistId,
                    schema,
                    canon,
                    keccak256("whole-artifact-boundary"),
                    uint64(1000)
                )
            )
        );
        artifact.answer(
            abi.encodeCall(
                IStreamFinalityArtifactCoverage.requireArtifactCoverage,
                (archive.completionHash, savedSanction.artistId, archive.artifactHash)
            ),
            abi.encode(
                F.Coverage(
                    archive.completionHash,
                    archive.artifactHash,
                    savedSanction.artistId,
                    schema,
                    canon,
                    keccak256("whole-artifact-boundary"),
                    1000,
                    1,
                    keccak256("family-one"),
                    keccak256("family-two"),
                    1,
                    keccak256("chain")
                )
            )
        );
    }

    function _deployCompanion() private {
        IStreamGasParameterHost.GasParameterConfig[3] memory caps;
        caps[0] = IStreamGasParameterHost.GasParameterConfig(
            "RECOVERY_DEPENDENCY_READ_GAS", 150000, 50000, 2
        );
        caps[1] = IStreamGasParameterHost.GasParameterConfig(
            "RECOVERY_ARTIST_READ_GAS", 2000000, 50000, 2
        );
        caps[2] =
            IStreamGasParameterHost.GasParameterConfig("RECOVERY_OWNER_READ_GAS", 500000, 50000, 2);
        recovery = new StreamArtworkFinalityRecovery(
            StreamFinalityRecoveryTargets(
                address(core),
                address(executor),
                address(original),
                address(artist),
                address(ownerEvidence)
            ),
            caps,
            StreamFinalityRecoveryDeploymentConfiguration(
                keccak256("deployment"), "urn:serving:recovery", keccak256("recovery-manifest")
            )
        );
        companion = CompanionDependencyBoundary(address(recovery));
        _pointer(
            keccak256("MODULE_REGISTRY"),
            address(modules),
            keccak256("MODULE_REGISTRY"),
            0x11223344,
            address(modules).codehash
        );
        _pointer(
            keccak256("ARTWORK_FINALITY_RECOVERY"),
            address(recovery),
            recovery.streamModuleType(),
            recovery.streamModuleInterfaceId(),
            address(recovery).codehash
        );
        modules.answer(
            abi.encodeCall(
                IStreamModuleRegistry.isModuleEligible,
                (address(recovery), recovery.streamModuleType(), recovery.streamModuleInterfaceId())
            ),
            abi.encode(true)
        );
    }

    function originalRenderer() external view returns (address) {
        return router.collectionServingFacts(1).renderer;
    }

    function clearRecoverySelection() external {
        core.answer(
            abi.encodeCall(
                IStreamCorePointers.getSatellitePointer, (keccak256("ARTWORK_FINALITY_RECOVERY"))
            ),
            new bytes(320)
        );
    }

    function restoreRecoverySelection() external {
        _pointer(
            keccak256("ARTWORK_FINALITY_RECOVERY"),
            address(recovery),
            recovery.streamModuleType(),
            recovery.streamModuleInterfaceId(),
            address(recovery).codehash
        );
    }

    function replaceCurrentOriginal(address target) external {
        _pointer(
            keccak256("ARTWORK_FINALITY_REGISTRY"),
            target,
            keccak256("ARTWORK_FINALITY_REGISTRY"),
            type(IStreamArtworkFinalityRegistry).interfaceId,
            target.codehash
        );
    }

    function recoverRenderer(address selectedRenderer) external returns (bytes32 action) {
        RouterReplacementRendererHostBoundary host =
            new RouterReplacementRendererHostBoundary(address(core), selectedRenderer);
        RouterCompositionProviderBoundary replacementProvider = new RouterCompositionProviderBoundary(
            address(core), address(metadataHost), address(host), address(entropyHost)
        );
        StreamFinalityServingHostAdapter adapter = new StreamFinalityServingHostAdapter(
            address(core), address(host), address(replacementProvider), keccak256("RENDERER")
        );
        StreamFinalityComponentState memory state = adapter.finalityState(1);
        StreamFinalityRecoveryRequest memory r;
        r.scope = _scope();
        r.expectedOriginalFinalityRecordHash = originalHash;
        (,, r.expectedOldRouteHash,,) =
            recovery.resolvedFinalityRoute(keccak256("RENDERER"), r.scope);
        r.replacementRoute = StreamFinalityComponentExpectation(
            state.componentType,
            state.component,
            state.interfaceId,
            state.codeHash,
            state.moduleVersion,
            state.manifestHash,
            state.dataHash
        );
        r.recoveryManifest = StreamFinalityManifestRef(
            "urn:renderer:recovery",
            keccak256("urn:renderer:recovery"),
            0,
            keccak256("intent-schema"),
            keccak256("intent-abi")
        );
        r.reasonHash = keccak256("replace failed renderer");
        r.reasonURI = "urn:renderer:failure";
        r.recoveryManifest.contentHash =
            recovery.stageFinalityRecoveryManifest(recovery.finalityRecoveryIntentBytes(r));
        recovery.registerFinalityRecoveryIntent(r);
        _module(
            artist, keccak256("ARTIST_REGISTRY"), type(IStreamArtistMintConsent).interfaceId, true
        );
        artist.answer(
            abi.encodeCall(
                IStreamArtistRecoveryApproval.verifyRecoveryApproval,
                (1, originalHash, r.recoveryManifest.contentHash)
            ),
            abi.encode(
                true, keccak256("explicit saved approval boundary"), address(0xA11CE), uint8(1)
            )
        );
        action = keccak256("explicit renderer recovery context boundary");
        ownerEvidence.answer(
            abi.encodeCall(
                IStreamFinalityRecoveryOwnerEvidence.verifyRecoveryOwnerEvidence,
                (r.scope, action, r.recoveryManifest.contentHash)
            ),
            abi.encode(
                true,
                keccak256("elapsed owner boundary"),
                uint64(1),
                uint64(1000),
                uint32(3),
                uint32(0)
            )
        );
        IStreamArtistRecoveryIntent.Facts memory facts = recovery.requireArtistRecoveryIntent(
            r.scope, originalHash, r.recoveryManifest.contentHash
        );
        (bool ok, bytes memory output) = actionHost.run(
            address(recovery),
            abi.encodeCall(recovery.executeFinalityRecovery, (r)),
            [action, facts.scopeHash, facts.oldValueHash, facts.newValueHash],
            2
        );
        if (!ok) assembly ("memory-safe") { revert(add(output, 32), mload(output)) }
        require(
            recovery.finalityRecoveryRecord(action).executed, "actual appended renderer recovery"
        );
    }

    function prepareRendererSuccessor(bytes32 predecessor)
        external
        returns (StreamFinalityRecoveryRequest memory r)
    {
        StreamFinalityRecoveryRecord memory previous = recovery.finalityRecoveryRecord(predecessor);
        require(previous.executed, "actual predecessor required");
        r = recovery.finalityRecoveryIntentRequest(previous.recoveryManifest.contentHash);
        r.expectedPredecessorRecoveryId = predecessor;
        (,, r.expectedOldRouteHash,,) =
            recovery.resolvedFinalityRoute(keccak256("RENDERER"), r.scope);
        r.reasonHash = keccak256("separately admitted successor");
        r.recoveryManifest.contentHash = 0;
        r.recoveryManifest.contentHash =
            recovery.stageFinalityRecoveryManifest(recovery.finalityRecoveryIntentBytes(r));
        recovery.registerFinalityRecoveryIntent(r);
        artist.answer(
            abi.encodeCall(
                IStreamArtistRecoveryApproval.verifyRecoveryApproval,
                (1, originalHash, r.recoveryManifest.contentHash)
            ),
            abi.encode(true, keccak256("successor approval boundary"), address(0xA11CE), uint8(1))
        );
        ownerEvidence.answer(
            abi.encodeCall(
                IStreamFinalityRecoveryOwnerEvidence.verifyRecoveryOwnerEvidence,
                (
                    r.scope,
                    keccak256("successor recovery context boundary"),
                    r.recoveryManifest.contentHash
                )
            ),
            abi.encode(
                true,
                keccak256("successor owner boundary"),
                uint64(1),
                uint64(1000),
                uint32(3),
                uint32(0)
            )
        );
    }

    function _sort() private {
        for (uint256 i; i < entries.length; ++i) {
            for (uint256 j = i + 1; j < entries.length; ++j) {
                if (entries[j].componentType < entries[i].componentType) {
                    StreamFinalityComponentExpectation memory temp = entries[i];
                    entries[i] = entries[j];
                    entries[j] = temp;
                }
            }
        }
    }

    function _scope() private pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
    }

    function coreAddress() external view returns (address) {
        return address(core);
    }
}
