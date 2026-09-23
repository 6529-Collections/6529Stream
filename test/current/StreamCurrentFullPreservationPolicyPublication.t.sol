// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentFullPreservationPolicyFinalityFixture.sol";
import "../helpers/StreamCurrentFullPreservationPolicyPublicationBase.sol";
import {
    IStreamPreservationPolicyContentRootPublicationV1
} from "../../smart-contracts/interfaces/stream/metadata/IStreamPreservationPolicyContentRootPublicationV1.sol";
import {
    StreamPreservationPolicySnapshotTypesV1 as PublicationSnapshot
} from "../../smart-contracts/interfaces/stream/metadata/StreamPreservationPolicySnapshotTypesV1.sol";

/// @notice Actual current graph publication cases, separate from construction-only evidence.
/// @dev The external captured-ceremony entry point requires fresh supplied browser observations.
/// It is deliberately not counted as a passed/default Foundry test without those observations.
contract StreamCurrentFullPreservationPolicyPublicationTest is
    StreamCurrentFullPreservationPolicyFinalityFixture
{
    event PublicationStage(string stage, bytes32 commitment, uint256 count);

    function testActualStaticActivationPrecedesOriginalRatificationAndGovernedMintPhases() public {
        _constructFullPolicyPublication();
        require(
            manager.owner() == address(executor) && core.collectionMintedEver(1) == 0,
            "original handoff retained before preparation"
        );
        (bool ratified,,) = artists.firstReleaseRatification(1);
        require(!ratified, "no manufactured original release");
        _prepareFullPolicyArtwork();
        _assertFullPolicyPrepared();
        require(
            manager.owner() == address(executor) && manager.phaseExecutor(1, PHASE, address(sale))
                && manager.phaseExecutor(1, AUCTION_PHASE, address(auction)),
            "genuine executor-owned mint setup"
        );
        require(
            sale.totalNativeProceeds() == 0.02 ether && core.ownerOf(fullPolicyTokens[0]) == BUYER
                && core.ownerOf(fullPolicyTokens[1]) == BUYER,
            "both original paid mints"
        );
    }

    function testActualFullOutputsRequireOriginalArtistConsentAndPreserveRetry() public {
        _publicationBuildToOutputs();
        IStreamContentRootPublication.Publication memory publication =
            IStreamContentRootPublication.Publication(
                1,
                bytes32(0),
                publicationOutputManifest,
                "urn:fixture:preservation-policy:output-manifest"
            );
        bytes32 candidate = IStreamPreservationPolicyContentRootPublicationV1(
                address(assemblyRouter)
            ).previewPreservationPolicyContentRootPublication(publication, address(this));
        require(
            candidate != 0 && router.collectionContentRootHead(1) == 0,
            "archive does not confer root authority"
        );
        vm.expectRevert();
        IStreamPreservationPolicyContentRootPublicationV1(address(assemblyRouter))
            .publishVerifiedPreservationPolicyContentRoot(publication);
        require(
            router.collectionContentRootHead(1) == 0
                && publicationOutputs.requireCurrentManifest(
                    publicationOutputManifest, assemblyArtistId
                )
                .tokenCount == 2,
            "failed adoption preserves exact covered candidate"
        );
        _publicationAdoptRoot();
        require(
            router.collectionContentRootHead(1) == assemblyOriginalContentRoot, "real op17 retry"
        );
    }

    function testActualFullPolicyRootSnapshotSealAndExactBrowserSourceExport() public {
        _publicationBuildToSnapshot();
        _publicationExportCurrentSources();
        PublicationSnapshot.Receipt memory receipt =
            publicationSnapshots.requireCurrent(_collectionScope(), assemblySnapshotRecord, 1);
        require(
            receipt.recordHash == assemblySnapshotRecord && receipt.manifestBytes != 0
                && publicationSnapshots.snapshotLock(_collectionScope()).actionId != 0,
            "real full source snapshot and original class2 seal"
        );
        require(
            !assemblyFinality.collectionFinalityRecord(1).finalized,
            "root and snapshot do not imply complete finality"
        );
    }

    function testActualPreservationCheckpointRejectsReplacedProducerAndRetainsOriginalReceipt()
        public
    {
        _publicationBuildToOutputs();
        bytes32 saved = keccak256(abi.encode(publicationCheckpoint.checkpoint(publicationContent)));
        address producer = address(assemblyPreservationRenderer);
        bytes memory runtime = producer.code;
        vm.etch(producer, hex"00");
        vm.expectRevert();
        publicationCheckpoint.requireCurrentCheckpoint(publicationContent);
        require(
            keccak256(abi.encode(publicationCheckpoint.checkpoint(publicationContent))) == saved,
            "historical checkpoint remains exact after current producer replacement"
        );
        vm.etch(producer, runtime);
        require(
            keccak256(
                    abi.encode(publicationCheckpoint.requireCurrentCheckpoint(publicationContent))
                ) == saved,
            "exact original runtime restores currentness"
        );
    }

    function testActualPreservationCheckpointRejectsUnadmittedLiveRendererPayloadAndPreservesRetry()
        public
    {
        _publicationBuildToOutputs();
        bytes32 candidate = publicationCheckpoint.begin(
            publicationSelection, keccak256("unadmitted producer retry")
        );
        IStreamPreservationPolicyContentCheckpointV1.Payload[] memory payloads =
            new IStreamPreservationPolicyContentCheckpointV1.Payload[](2);
        for (uint256 i; i < 2; ++i) {
            payloads[i] = IStreamPreservationPolicyContentCheckpointV1.Payload(
                fullPolicyTokens[i],
                publicationCheckpoint.outputAt(publicationContent, i).preservation.liveRenderer,
                bytes(""),
                publicationHTML[fullPolicyTokens[i]]
            );
        }
        vm.expectRevert();
        publicationCheckpoint.append(candidate, payloads);
        require(
            publicationCheckpoint.checkpoint(candidate).nextIndex == 0,
            "wrong producer cannot consume any ordered token row"
        );
        for (uint256 i; i < 2; ++i) {
            payloads[i].producer = address(assemblyPreservationRenderer);
        }
        publicationCheckpoint.append(candidate, payloads);
        require(
            publicationCheckpoint.requireCurrentCheckpoint(candidate).nextIndex == 2,
            "actual governed producer remains retryable"
        );
    }

    /// @notice Source-authored ceremony candidate after actual fresh browser/package observation.
    /// @dev Caller supplies JSON contents, not paths, except the explicit member-witness directory.
    /// No old native captures, synthesized PNGs, default skips or implicit success are accepted.
    /// The preservation output omits only sanction display. Actual sanction, finalization and
    /// confirmation must preserve every independent input and keep the live sanction visible.
    /// Source authorship does not establish execution, browser capture or gas acceptance.
    function runCapturedFullPolicyCeremony(
        string memory environmentJSON,
        string memory browserJSON,
        string memory capturesJSON,
        string memory packageMembersDirectory
    ) public returns (bytes32 finalityRecord) {
        require(
            bytes(packageMembersDirectory).length != 0, "explicit observed package member witnesses"
        );
        _publicationBuildToSnapshot();
        _publicationPrepareReferenceDefinitions();
        _publicationPublishReference(environmentJSON, browserJSON, capturesJSON);
        emit PublicationStage("actual supplied reference observations", assemblyReferenceRecord, 2);
        _assemblyPrepareCeremonyDefinitions();
        AssemblyInventory.Item[][] memory rows = _publicationMaterializeInventory();
        emit PublicationStage(
            "all complete source occurrences",
            assemblyRenderInventoryEvidence.renderCriticalEvidenceHash,
            assemblyRenderInventoryEvidence.itemCount
        );
        publicationPackageMembersDirectory = packageMembersDirectory;
        _assemblyCoverCompleteBundle(rows);
        emit PublicationStage(
            "every source occurrence covered",
            assemblyCompleteBundle.bundleCoverageHash,
            assemblyCompleteBundle.itemCount
        );
        _assemblyPerformSanctionAndFinality();
        require(
            assemblySanctionRecord != 0 && assemblyFinalityRecord != 0
                && assemblyFinality.collectionFinalityRecord(1).finalized,
            "original canonical finality complete"
        );
        emit PublicationStage(
            "actual Artist Safe sanction and canonical finality", assemblyFinalityRecord, 10
        );
        return assemblyFinalityRecord;
    }

    /// @dev Forge simulation entry points; neither uses broadcast or signs a public transaction.
    function exportFullPolicyCurrentSources() external {
        _publicationBuildToSnapshot();
        _publicationExportCurrentSources();
    }

    function runCapturedFullPolicyCeremonyFromFiles(
        string calldata environmentPath,
        string calldata browserPath,
        string calldata capturesPath,
        string calldata packageMembersDirectory
    ) external returns (bytes32) {
        return runCapturedFullPolicyCeremony(
            assemblyVm.readFile(environmentPath),
            assemblyVm.readFile(browserPath),
            assemblyVm.readFile(capturesPath),
            packageMembersDirectory
        );
    }

    function _publicationBuildToOutputs() private {
        _constructFullPolicyPublication();
        _prepareFullPolicyArtwork();
        _publicationPrepareGraph();
        _publicationPrepareOutputDefinitions();
        _publicationCheckpointOutputs();
        emit PublicationStage("actual covered full STATIC outputs", publicationOutputManifest, 2);
    }

    function _publicationBuildToSnapshot() private {
        _publicationBuildToOutputs();
        _publicationAdoptRoot();
        _publicationPublishAndLockSnapshot();
        emit PublicationStage("actual root and source snapshot", assemblySnapshotRecord, 2);
    }
}
