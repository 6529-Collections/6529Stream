// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityScopedPreservationPolicyReferenceFixture
} from "../helpers/StreamCurrentAuthorityScopedPreservationPolicyReferenceFixture.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyPublicationFixture
} from "../helpers/StreamCurrentAuthorityScopedPreservationPolicyPublicationFixture.sol";
import {
    StreamCurrentAuthorityCollectionPreservationCallerFixture
} from "../helpers/StreamCurrentAuthorityCollectionPreservationCallerFixture.sol";
import {
    StreamFinalityScopeType
} from "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1 as CallerSnapshot
} from "../../smart-contracts/interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
import {
    StreamRecordFamilies as CallerFamilies
} from "../../smart-contracts/domains/records/StreamRecordFamilies.sol";
import {
    IStreamStaticSelectionCheckpoint as CallerSelection
} from "../../smart-contracts/interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";

/// @notice Genuine collection and scoped preparation before client-produced publication calls.
/// @dev This setup test supplies no mined receipt, client calldata or state-export acceptance.
contract StreamCurrentAuthorityPreservationCallerPreparationTest is
    StreamCurrentAuthorityScopedPreservationPolicyReferenceFixture,
    StreamCurrentAuthorityCollectionPreservationCallerFixture
{
    function testPrepareCollectionAndScopedGraphsWithFourRealTokensForGrantedSafe() public {
        _deployAssemblyGraph();
        _activateAssemblyArtwork();
        _authorityRecoverOriginal();
        _assemblyPrepareDescriptionDefinitions();
        _assemblySelectDescriptionsAndWaiver();

        AuthorityScopedPublication memory token =
            _authorityPrepareScopedPreservationPolicy(StreamFinalityScopeType.TOKEN);
        AuthorityScopedPublication memory release =
            _authorityPrepareScopedPreservationPolicy(StreamFinalityScopeType.RELEASE);
        AuthorityScopedPublication memory season =
            _authorityPrepareScopedPreservationPolicy(StreamFinalityScopeType.SEASON);
        _assertPrepared(token, 1);
        _assertPrepared(release, 4);
        _assertPrepared(season, 4);
        _authorityPrepareScopedPreservationPolicyReferenceWriter();
        CollectionPreservationCallerPreparation memory collection =
            _authorityPrepareCollectionPreservationCaller();
        require(
            collection.membership.tokenCount == 4 && collection.graph.preparedChildren == 7
                && collection.selectionId != 0 && collection.selection.nextIndex == 4
                && collection.selection.selectionRoot != 0,
            "actual four-token collection graph and selection"
        );
        require(collection.writer == address(assemblyArtist), "same actual Safe across scopes");
        _authorityPrepareScopedPreservationSelection(token);
        _authorityPrepareScopedPreservationSelection(release);
        _authorityPrepareScopedPreservationSelection(season);
        _assertSelection(token);
        _assertSelection(release);
        _assertSelection(season);
        require(
            keccak256(
                abi.encode(
                    CallerSelection(sourceStaticSelection)
                        .requireCurrentCheckpoint(collection.selectionId)
                )
            ) == keccak256(abi.encode(collection.selection)),
            "collection selection remains current after scoped preparation"
        );

        address writer = address(assemblyArtist);
        require(writer.code.length != 0 && assemblyArtist.getThreshold() != 0, "actual Safe writer");
        _assertWriter(CallerFamilies.SNAPSHOT, 7, writer);
        _assertWriter(CallerFamilies.IDENTITY, 7, writer);
        _assertWriter(CallerFamilies.CURATOR, 3, writer);
        _assertWriter(CallerFamilies.IDENTITY, 7, address(this));
        require(assemblyRouter.collectionContentRootHead(1) == 0, "setup has no native root");
        require(
            assemblyRouter.scopedContentRootAggregate(1).revision == 0,
            "setup has no scoped publication roots"
        );
    }

    function _authorityScopedPublicationWriter()
        internal
        view
        override(
            StreamCurrentAuthorityScopedPreservationPolicyPublicationFixture,
            StreamCurrentAuthorityCollectionPreservationCallerFixture
        )
        returns (address)
    {
        return address(assemblyArtist);
    }

    function _assemblyArtworkTokenCount() internal pure override returns (uint64) {
        return 4;
    }

    function _assertWriter(bytes32 family, uint8 authorizationClass, address writer) private view {
        (bool enabled, uint64 revision) =
            assemblyMetadata.familyWriter(1, family, authorizationClass, writer);
        require(enabled && revision != 0, "actual family grant");
    }

    function _assertSelection(AuthorityScopedPublication memory p) private view {
        require(
            p.selectionId != 0 && p.selection.nextIndex == p.membership.tokenCount
                && p.selection.selectionRoot != 0,
            "real STATIC selection prerequisite"
        );
        require(
            keccak256(
                abi.encode(
                    CallerSelection(sourceStaticSelection).requireCurrentCheckpoint(p.selectionId)
                )
            ) == keccak256(abi.encode(p.selection)),
            "same complete current selection"
        );
        require(
            p.checkpointId == 0 && p.outputPlan == 0 && p.outputRecord == 0 && p.rootHash == 0
                && CallerSnapshot(p.graph.children[3]).snapshotCount(p.scope) == 0,
            "selection preparation leaves Client publications untouched"
        );
    }

    function _assertPrepared(AuthorityScopedPublication memory p, uint256 tokenCount) private view {
        require(p.membership.tokenCount == tokenCount, "genuine complete membership");
        require(p.graph.graphId != 0 && p.graph.preparedChildren == 7, "genuine complete graph");
        require(p.graph.sourceSet.codehash == p.graph.sourceSetCodeHash, "actual fixed source set");
        for (uint256 i; i < 7; ++i) {
            address child = p.graph.children[i];
            require(
                child.code.length != 0 && child.code.length <= 24576
                    && child.codehash == p.graph.codeHashes[i],
                "actual factory child runtime"
            );
        }
        require(
            p.selectionId == 0 && p.checkpointId == 0 && p.outputPlan == 0 && p.outputRecord == 0
                && p.rootHash == 0,
            "setup returns no completed publication"
        );
        require(
            CallerSnapshot(p.graph.children[3]).snapshotCount(p.scope) == 0,
            "client snapshot has not been published"
        );
        require(assemblyRouter.scopedContentRootHead(p.scope) == 0, "client root is absent");
    }
}
