// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityScopedPolicySealingFixture
} from "../helpers/StreamCurrentAuthorityScopedPolicySealingFixture.sol";
import {
    StreamFinalityScopeType
} from "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamConservationRecordTypes as StaticScopedConservation
} from "../../smart-contracts/interfaces/stream/metadata/StreamConservationRecordTypes.sol";
import {
    IStreamPreservationRecords as StaticScopedRecords
} from "../../smart-contracts/interfaces/stream/preservation/IStreamPreservationRecords.sol";
import {
    IStreamCollectionMetadataV1 as StaticScopedMetadata
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamCurrentAuthorityDeferredPolicyBindingV2 as StaticScopedDeferred
} from "../../smart-contracts/interfaces/stream/finality/IStreamCurrentAuthorityDeferredPolicyBindingV2.sol";

/// @notice Real original STATIC roots and scope-specific op24 records across complete A/B/C imports.
/// @dev These cases do not assert browser observations, bundle completion, or Finality completion.
/// Runtime, original renderer admission conformance, bytecode and gas qualification remain separate.
contract StreamCurrentAuthorityStaticScopedPolicyTest is
    StreamCurrentAuthorityScopedPolicySealingFixture
{
    function testActualTokenStaticRootAndScopedRecordsThroughBAndC() public {
        _throughSuccessors(StreamFinalityScopeType.TOKEN);
    }

    function testActualReleaseStaticRootAndScopedRecordsThroughBAndC() public {
        _throughSuccessors(StreamFinalityScopeType.RELEASE);
    }

    function testActualSeasonStaticRootAndScopedRecordsThroughBAndC() public {
        _throughSuccessors(StreamFinalityScopeType.SEASON);
    }

    function _throughSuccessors(StreamFinalityScopeType kind) private {
        _deployAssemblyGraph();
        _activateAssemblyArtwork();
        _authorityRecoverOriginal();
        _assemblyPrepareDescriptionDefinitions();
        // Retain the original independently sealed collection-level history as well as the
        // new scope's own unsealed record lineage. This reuses every original invariant.
        _assemblySelectDescriptionsAndWaiver();
        AuthorityScopedPublication memory publication = _authorityPublishScopedPolicy(kind);
        _authorityCaptureOriginalPreservation();
        bytes32 presentation = authorityOriginalPresentationHash;
        bytes32 originalRoot = assemblyRouter.scopedContentRootHead(publication.scope);
        require(originalRoot != 0, "actual scoped root published under A");
        bytes32 originalSource =
            keccak256(abi.encode(assemblyRouter.scopedContentRootRecord(originalRoot)));
        require(assemblyRouter.collectionContentRootHead(1) == 0, "STATIC keeps native head empty");
        require(
            StaticScopedDeferred(address(assemblyProvider)).policyBindingHash() == 0,
            "scoped graph remains independent of collection-policy admission"
        );

        _authorityMigrateNext();
        ScopedRecordHeads memory expected;
        expected.contentTag = keccak256("B original scoped op24 records");
        ScopedRecordSet memory b = _publishScopedRecords(publication.scope, expected);
        AuthorityScopedRights memory rightsResult = _authorityPublishScopedRights(publication.scope);
        bytes32 originalRights = _savedMetadataRecordHash(rightsResult.recordHash);
        require(
            authorityEra == 1 && b.workPublication.receipt.recordIndex != 0,
            "B WORK appends after actual original collection record"
        );
        require(b.workSelection.revision == 1 && b.intentSelection.revision == 1);
        bytes32 bWork = _savedMetadataRecordHash(b.workPublication.recordHash);
        bytes32 bInterview = _savedMetadataRecordHash(b.interviewPublication.recordHash);
        bytes32 bIntent = _savedMetadataRecordHash(b.intentPublication.recordHash);
        bytes32 bWorkSelection = keccak256(abi.encode(b.workSelection));
        bytes32 bIntentSelection = keccak256(abi.encode(b.intentSelection));
        _authorityRequireOriginals();
        _authorityRequireRoute();

        _authorityMigrateNext();
        require(authorityEra == 2, "actual C completes all seven owner imports");
        require(_savedMetadataRecordHash(b.workPublication.recordHash) == bWork);
        require(_savedMetadataRecordHash(b.interviewPublication.recordHash) == bInterview);
        require(_savedMetadataRecordHash(b.intentPublication.recordHash) == bIntent);
        require(_savedMetadataRecordHash(rightsResult.recordHash) == originalRights);
        require(
            keccak256(
                abi.encode(
                    assemblyRights.requireCurrent(
                        1, rightsResult.subject, rightsResult.recordHash, 1
                    )
                )
            ) == keccak256(abi.encode(rightsResult.selection)),
            "original RIGHTS instance and scope survive C"
        );
        require(
            keccak256(abi.encode(assemblyWork.workSelectionAt(1, b.subject, 1))) == bWorkSelection,
            "same original WORK instance preserves B selection"
        );
        require(
            keccak256(
                abi.encode(
                    assemblyConservation.conservationSelectionAt(
                        1, b.subject, StaticScopedConservation.StatementOrigin.ARTIST_INTENT, 1
                    )
                )
            ) == bIntentSelection,
            "same original Conservation instance preserves B selection"
        );
        expected.workHead = b.workPublication.recordHash;
        expected.workRevision = 1;
        expected.intentHead = b.intentPublication.recordHash;
        expected.intentRevision = 1;
        expected.interviewPredecessor = b.interviewPublication.recordHash;
        expected.contentTag = keccak256("C successor scoped op24 records");
        ScopedRecordSet memory c = _publishScopedRecords(publication.scope, expected);
        require(c.workSelection.revision == 2 && c.intentSelection.revision == 2);
        require(c.workPublication.recordHash != b.workPublication.recordHash);
        require(c.intentPublication.recordHash != b.intentPublication.recordHash);
        require(c.interviewPublication.recordHash != b.interviewPublication.recordHash);
        require(c.workPublication.receipt.recordIndex == b.workPublication.receipt.recordIndex + 1);
        require(
            c.intentPublication.receipt.recordIndex == b.intentPublication.receipt.recordIndex + 1
        );
        require(_savedMetadataRecordHash(b.workPublication.recordHash) == bWork);
        require(_savedMetadataRecordHash(b.interviewPublication.recordHash) == bInterview);
        require(_savedMetadataRecordHash(b.intentPublication.recordHash) == bIntent);
        require(assemblyRouter.scopedContentRootHead(publication.scope) == originalRoot);
        require(
            keccak256(abi.encode(assemblyRouter.scopedContentRootRecord(originalRoot)))
                == originalSource
        );
        require(keccak256(abi.encode(assemblyRouter.artistPresentation(1))) == presentation);
        require(assemblyRouter.collectionContentRootHead(1) == 0);
        AuthorityScopedSeals memory seals = _authoritySealScopedRecords(c, rightsResult);
        require(
            seals.work.revision == 2 && seals.rights.revision == 1 && seals.intent.revision == 2
        );
        _authorityRequireOriginals();
        _authorityRequireRoute();
    }

    function _savedMetadataRecordHash(bytes32 recordHash) private view returns (bytes32) {
        (
            StaticScopedRecords.CollectionRecord memory record,
            StaticScopedMetadata.RecordReceipt memory receipt
        ) = assemblyMetadata.collectionRecord(recordHash);
        (, bytes memory payload) = assemblyMetadata.recordPayload(recordHash);
        return keccak256(abi.encode(record, receipt, payload));
    }
}
