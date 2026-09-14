// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamNativeFinalityAssemblyFixture.sol";

/// @notice First real deployment join for the complete native provider and original Artist suite.
/// @dev This case proves the actual constructor graph. Original content/records, selected seals,
/// full archival inventory and the final governed ceremony are separate subsequent flow checks.
contract StreamNativeFinalityAssemblyTest is StreamNativeFinalityAssemblyFixture {
    event AssemblyFlowStep(string step, bytes32 commitment, uint256 count);

    function testActualNativeCompletePreservationSafeSanctionAndCanonicalFinality() public {
        _deployAssemblyGraph();
        _activateAssemblyArtwork();
        emit AssemblyFlowStep(
            "actual paid artworks", assemblyArtistId, assemblyCore.collectionMintedEver(1)
        );
        _assemblyPrepareDescriptionDefinitions();
        _assemblyPublishOriginalRoot();
        _assemblySelectDescriptionsAndWaiver();
        _assemblyPublishAndLockSnapshot();
        emit AssemblyFlowStep(
            "actual original snapshot and selected seals", assemblySnapshotRecord, 2
        );
        _assemblyPrepareReferenceDefinitions();
        _assemblyPublishReference(
            assemblyVm.readFile("test/fixtures/native-assembly/reference-environment.json"),
            assemblyVm.readFile("test/fixtures/native-assembly/reference-browser-endpoints.json"),
            assemblyVm.readFile("test/fixtures/native-assembly/reference-captures.json")
        );
        emit AssemblyFlowStep("fresh original reference renders", assemblyReferenceRecord, 364);
        _assemblyPrepareCeremonyDefinitions();
        AssemblyInventory.Item[][] memory rows = _assemblyMaterializeInventory();
        emit AssemblyFlowStep(
            "eight actual original inventory producers",
            assemblyRenderInventoryEvidence.renderCriticalEvidenceHash,
            assemblyRenderInventoryEvidence.itemCount
        );
        _assemblyCoverCompleteBundle(rows);
        emit AssemblyFlowStep(
            "every original occurrence covered",
            assemblyCompleteBundle.bundleCoverageHash,
            assemblyCompleteBundle.itemCount
        );
        _assemblyCloseAndFreezeCore();
        _assemblyPerformSanctionAndFinality();
        emit AssemblyFlowStep(
            "actual Safe sanction and canonical finality", assemblyFinalityRecord, 10
        );
        require(
            assemblySanctionRecord != 0 && assemblyFinalityRecord != 0
                && assemblyFinality.collectionFinalityRecord(1).finalized,
            "complete original native ceremony"
        );
    }

    function testActualOriginalSourceSnapshotAndEntropySetWithAllLocalSeals() public {
        _deployAssemblyGraph();
        _activateAssemblyArtwork();
        _assemblyPrepareDescriptionDefinitions();
        _assemblyPublishOriginalRoot();
        _assemblySelectDescriptionsAndWaiver();
        _assemblyPublishAndLockSnapshot();
        _assemblyExportOriginalSources();
        require(
            assemblySnapshotRecord != 0 && assemblyEntropySourceSet != address(0),
            "real retained source and complete original coordinator set"
        );
    }

    function testActualOriginalArtistPublicationAndGovernedWorkRightsSeals() public {
        _deployAssemblyGraph();
        _activateAssemblyArtwork();
        _assemblyPrepareDescriptionDefinitions();
        _assemblyPublishOriginalRoot();
        _assemblySelectDescriptionsAndWaiver();
        require(
            assemblyWork.currentWork(1, _assemblySubject()).recordHash == assemblyWorkRecord
                && assemblyRights.currentRights(1, _assemblySubject()).recordHash
                    == assemblyRightsRecord,
            "original actual current selections"
        );
        require(
            assemblyWaiverRecord != 0 && assemblyWaiverAuthorization != 0,
            "actual Artist/Safe op24 original waiver"
        );
    }

    function testActualOriginalContentConsentCheckpointAndDualArchivePublication() public {
        _deployAssemblyGraph();
        _activateAssemblyArtwork();
        _assemblyPublishOriginalRoot();
        require(
            assemblyOriginalContentRoot != 0
                && assemblyRouter.collectionContentRootHead(1) == assemblyOriginalContentRoot,
            "actual native original content producer"
        );
    }

    function testActualSafeArtistPaidMintAndOriginalEntropyWithCanonicalFinalityGraph() public {
        _deployAssemblyGraph();
        _activateAssemblyArtwork();
        require(
            assemblyArtists.acceptedArtist(1) == address(assemblyArtist), "actual original artist"
        );
        require(
            assemblyCoordinator.finalityRegistry() == address(assemblyFinality)
                && assemblyFinality.scopeEvidenceProvider() == address(assemblyProvider),
            "same original complete finality graph"
        );
        require(
            assemblySplitWallet.balance == 0.02 ether
                && assemblySale.totalNativeProceeds() == 0.02 ether,
            "both paid mints funded the original split"
        );
        require(
            assemblyCore.ownerOf(1) == ASSEMBLY_BUYER && assemblyCore.ownerOf(2) == ASSEMBLY_BUYER,
            "two actual allocated artworks"
        );
        (bool locked,,,,) = assemblyEntropy.entropyPolicyFrozen(1);
        require(locked, "original entropy policy locked by actual mint");
    }

    function testActualOriginalNativeGraphUsesPredictedCreateAndExactRuntimePins() public {
        _deployAssemblyGraph();
        require(assemblyCore.collectionExists(1), "actual current Core collection");
        require(
            assemblyExecutor.owner() == address(assemblyRoot) && assemblyRoot.getThreshold() == 2,
            "real two-owner Safe governance"
        );
        require(
            assemblyArtists.operationCoordinator() == address(assemblyCoordinator)
                && assemblyCoordinator.finalityRegistry() == address(assemblyFinality)
                && assemblyCoordinator.finalityEvidenceProvider() == address(assemblyProvider),
            "original Artist finality joins"
        );
        require(
            address(assemblyFinality.coreReads()) == address(assemblyCore)
                && address(assemblyFinality.metadataReads()) == address(assemblyMetadata)
                && address(assemblyFinality.sanctionReads()) == address(assemblyArtists)
                && assemblyFinality.scopeEvidenceProvider() == address(assemblyProvider)
                && assemblyFinality.finalityDiscovery() == address(assemblyDiscovery)
                && assemblyFinality.finalityRoleRegistry() == address(assemblyRoles),
            "real canonical Registry dependencies"
        );
        require(
            assemblyArtifact.finalityRegistry() == address(assemblyFinality)
                && assemblyArtifact.archivalCoverage() == address(assemblyArchive)
                && assemblyDiscovery.configuration().finalityRegistry == address(assemblyFinality),
            "actual reciprocal construction"
        );
        require(
            assemblyWork.core() == address(assemblyCore)
                && assemblyRights.core() == address(assemblyCore)
                && assemblyConservation.core() == address(assemblyCore),
            "actual three selectors"
        );
        require(
            assemblyWork.supportsInterface(type(IStreamRecordSelectionLock).interfaceId)
                && assemblyRights.supportsInterface(type(IStreamRecordSelectionLock).interfaceId),
            "original selector seal interfaces"
        );
        T.SuiteConfiguration memory saved = assemblyCoordinator.suiteConfiguration();
        require(
            keccak256(abi.encode(saved)) == keccak256(abi.encode(assemblySuite)),
            "same complete original suite"
        );
        for (uint256 i; i < 7; ++i) {
            IStreamArtistOwner owner = IStreamArtistOwner(saved.owners[i]);
            require(
                owner.operationCoordinator() == address(assemblyCoordinator)
                    && owner.artistRegistry() == address(assemblyArtists)
                    && owner.archiveV2() == saved.archive,
                "seven actual original owners"
            );
            require(saved.owners[i].code.length <= 24576, "original owner runtime fits");
        }
        _assertOriginalChildren(saved);
        for (uint256 i; i < 9; ++i) {
            require(
                assemblyVm.getNonce(address(assemblySlots[i])) == 2,
                "one actual product from every slot"
            );
            (bool repeat,) = address(assemblySlots[i])
                .call(
                    abi.encodeCall(
                        NativeFinalityAssemblySlot.deploy,
                        (bytes("retry"), assemblyLate[i], keccak256(assemblyRuntimes[i]))
                    )
                );
            require(
                !repeat && assemblyVm.getNonce(address(assemblySlots[i])) == 2,
                "consumed slot permanently rejects retry"
            );
        }
    }

    function _assertOriginalChildren(T.SuiteConfiguration memory suite) private view {
        require(
            assemblyVm.getNonce(address(assemblyArtists)) == 4,
            "facade created exactly its three original children"
        );
        address[3] memory children = [
            assemblyArtists.registryWriterExtension(),
            assemblyArtists.registryReadExtension(),
            assemblyArtists.registryFinalityReadExtension()
        ];
        for (uint256 i; i < 3; ++i) {
            require(
                children[i] == assemblyVm.computeCreateAddress(address(assemblyArtists), i + 1)
                    && children[i].code.length != 0 && children[i].code.length <= 24576,
                "actual ordered facade children"
            );
        }
        StreamArtistIdentityAuthority identity = StreamArtistIdentityAuthority(suite.owners[2]);
        require(
            assemblyVm.getNonce(address(identity)) == 4,
            "Identity created exactly its three original children"
        );
        children = [
            identity.identityWriterExtension(),
            identity.identityEstateExtension(),
            identity.identityRecoveryExtension()
        ];
        for (uint256 i; i < 3; ++i) {
            require(
                children[i] == assemblyVm.computeCreateAddress(address(identity), i + 1)
                    && children[i].code.length != 0 && children[i].code.length <= 24576,
                "actual ordered Identity children"
            );
        }
        require(
            assemblySchemas.chunkStore()
                    == assemblyVm.computeCreateAddress(address(assemblySchemas), 1)
                && assemblyVm.getNonce(address(assemblySchemas)) == 2,
            "original Schema Store CREATE"
        );
        address[] memory products = new address[](22);
        products[0] = address(assemblyCore);
        products[1] = address(assemblyExecutor);
        products[2] = address(assemblyRoles);
        products[3] = address(assemblyModules);
        products[4] = address(assemblyManifest);
        products[5] = address(assemblyManager);
        products[6] = address(assemblyLedger);
        products[7] = address(assemblyAssetPolicy);
        products[8] = address(assemblySplits);
        products[9] = address(assemblyArtists);
        products[10] = suite.archive;
        products[11] = suite.validator;
        products[12] = address(assemblyCoordinator.reads());
        products[13] = address(assemblyRouter);
        products[14] = address(assemblyPrimary);
        products[15] = address(assemblyRoyalties);
        products[16] = address(assemblyCheckpointVerifier);
        products[17] = address(assemblyArchive);
        products[18] = address(assemblySchemas);
        products[19] = address(assemblyStore);
        products[20] = address(assemblyObjectVerifier);
        products[21] = address(assemblyMetadata);
        for (uint256 i; i < products.length; ++i) {
            require(
                products[i].code.length != 0 && products[i].code.length <= 24576,
                "actual foundation and original product runtime fits"
            );
        }
        for (uint256 i; i < 6; ++i) {
            require(
                assemblyRouterAdapters[i].code.length != 0
                    && assemblyRouterAdapters[i].code.length <= 24576,
                "actual serving adapter runtime fits"
            );
        }
    }
}
