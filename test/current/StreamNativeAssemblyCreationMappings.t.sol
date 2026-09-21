// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamNativeAssemblyCreation as Native
} from "../helpers/StreamNativeAssemblyCreation.sol";
import {
    StreamCurrentGraphCreation as Graph
} from "../../script/current/StreamCurrentGraphCreation.sol";
import {
    StreamCurrentAuthorityGraphCreation as Authority
} from "../../script/current/StreamCurrentAuthorityGraphCreation.sol";

/// @dev Mapping-only regression oracles frozen from the original f407acea dispatchers/imports.
/// No production creation code, constructor execution, artifact lookup or current-graph proof
/// is exercised here. Literal expected coordinates are independent of the new native getters.
contract StreamNativeAssemblyCreationMappingsTest {
    function testOriginalEnumPrefixAndNativeExtraPreserved() public pure {
        string[] memory names = _originalNames();
        require(uint256(type(Graph.Kind).max) == 63, "original enum length");
        require(uint256(type(Native.Kind).max) == 64, "native enum length");
        for (uint256 i; i < names.length; ++i) {
            _same(Graph.name(Graph.Kind(i)), names[i]);
            _same(Native.name(Native.Kind(i)), names[i]);
        }
        require(
            uint256(Native.Kind.StreamCurrentAuthorityRightsRecordSelection) == 64,
            "native extra ordinal"
        );
        _same(
            Native.name(Native.Kind.StreamCurrentAuthorityRightsRecordSelection),
            "StreamCurrentAuthorityRightsRecordSelection"
        );
        _same(
            Native.artifact(Native.Kind.StreamCurrentAuthorityRightsRecordSelection),
            "smart-contracts/domains/metadata/StreamCurrentAuthorityRightsRecordSelection.sol:StreamCurrentAuthorityRightsRecordSelection"
        );
    }

    function testAll39GraphArtifactsUseOriginalCoordinates() public pure {
        (uint8[] memory ordinals, string[] memory paths) = _graphCases();
        require(ordinals.length == 39 && paths.length == 39, "original supported graph count");
        for (uint256 i; i < ordinals.length; ++i) {
            _same(Native.graphArtifact(Graph.Kind(ordinals[i])), paths[i]);
            _same(Native.artifact(Native.Kind(ordinals[i])), paths[i]);
        }
    }

    function testAll25UnsupportedGraphKindsKeepOriginalError() public view {
        (uint8[] memory ordinals, string[] memory paths) = _graphCases();
        bool[64] memory supported;
        for (uint256 i; i < ordinals.length; ++i) {
            require(!supported[ordinals[i]], "duplicate frozen supported kind");
            supported[ordinals[i]] = true;
        }
        uint256 refused;
        bytes memory expected =
            abi.encodeWithSignature("Error(string)", "unknown original product template");
        for (uint256 i; i < 64; ++i) {
            if (supported[i]) continue;
            (bool ok, bytes memory result) =
                address(this).staticcall(abi.encodeCall(this.graphProbe, (uint8(i))));
            require(!ok && keccak256(result) == keccak256(expected), "original graph refusal bytes");
            ++refused;
        }
        require(refused == 25, "closed original graph domain");
        _same(Native.graphArtifact(Graph.Kind(ordinals[0])), paths[0]);
    }

    function testAll10AuthorityArtifactsUseOriginalCoordinates() public pure {
        string[] memory paths = _authorityCases();
        require(
            uint256(type(Authority.Kind).max) == 9 && paths.length == 10, "authority enum length"
        );
        for (uint256 i; i < paths.length; ++i) {
            _same(Native.authorityArtifact(Authority.Kind(i)), paths[i]);
        }
    }

    function testAll23ScopedArtifactsUseOriginalCoordinatesAndFallback() public pure {
        (string[] memory names, string[] memory paths) = _scopedCases();
        require(
            names.length == 23 && paths.length == 23, "four preservation and nineteen prefix cases"
        );
        for (uint256 i; i < names.length; ++i) {
            _same(Native.scopedPolicyArtifact(names[i]), paths[i]);
        }
        // These original prefix products remain supported after the four preservation cases.
        _same(
            Native.scopedPolicyArtifact("StreamStaticSelectionCheckpoint"),
            "smart-contracts/domains/finality/StreamStaticSelectionCheckpoint.sol:StreamStaticSelectionCheckpoint"
        );
        _same(
            Native.scopedPolicyArtifact("StreamFinalityLineageDeferredScopedPolicyDiscoveryV2"),
            "smart-contracts/domains/finality/StreamFinalityLineageDeferredScopedPolicyDiscoveryV2.sol:StreamFinalityLineageDeferredScopedPolicyDiscoveryV2"
        );
    }

    function testScopedUnknownAndSentinelKeepOriginalError() public view {
        string[] memory names = new string[](8);
        names[0] = "";
        names[1] = "__sentinel__";
        names[2] = "unknown";
        names[3] = "StreamCore"; // Genuine native artifact, outside the scoped allowlist.
        names[4] = "StreamCurrentAuthorityRightsRecordSelection";
        names[5] = "streamStaticSelectionCheckpoint";
        names[6] = "StreamStaticSelectionCheckpoint ";
        names[7] =
            "smart-contracts/domains/finality/StreamStaticSelectionCheckpoint.sol:StreamStaticSelectionCheckpoint";
        bytes memory expected =
            abi.encodeWithSignature("Error(string)", "unknown original scoped-policy product");
        for (uint256 i; i < names.length; ++i) {
            (bool ok, bytes memory result) =
                address(this).staticcall(abi.encodeCall(this.scopedProbe, (names[i])));
            require(
                !ok && keccak256(result) == keccak256(expected), "original scoped refusal bytes"
            );
        }
        _same(
            Native.scopedPolicyArtifact("StreamStaticSelectionCheckpoint"),
            "smart-contracts/domains/finality/StreamStaticSelectionCheckpoint.sol:StreamStaticSelectionCheckpoint"
        );
    }

    function graphProbe(uint8 ordinal) external pure returns (string memory) {
        return Native.graphArtifact(Graph.Kind(ordinal));
    }

    function scopedProbe(string calldata name_) external pure returns (string memory) {
        return Native.scopedPolicyArtifact(name_);
    }

    function _same(string memory actual, string memory expected) private pure {
        require(
            keccak256(bytes(actual)) == keccak256(bytes(expected)),
            "exact original artifact mapping"
        );
    }

    function _originalNames() private pure returns (string[] memory names) {
        names = new string[](64);
        names[0] = "StreamArchivalCoverage";
        names[1] = "StreamArtistAcceptanceLifecycle";
        names[2] = "StreamArtistArchiveV2";
        names[3] = "StreamArtistAttributionLifecycle";
        names[4] = "StreamArtistBindingLifecycle";
        names[5] = "StreamArtistCollaboratorLifecycle";
        names[6] = "StreamArtistConsentFinalityLifecycle";
        names[7] = "StreamArtistIdentityAuthority";
        names[8] = "StreamArtistOnboardingCoordinator";
        names[9] = "StreamArtistOnboardingRegistry";
        names[10] = "StreamArtistPayoutLifecycle";
        names[11] = "StreamArtistRegistryValidatorBase";
        names[12] = "StreamArtworkFinalityRegistry";
        names[13] = "StreamArweaveCheckpointVerifier";
        names[14] = "StreamArweaveObjectCheckpointVerifier";
        names[15] = "StreamAssetPolicyRegistry";
        names[16] = "StreamBundleArchiveCoverage";
        names[17] = "StreamCollectionMetadataV1";
        names[18] = "StreamCollectionSnapshots";
        names[19] = "StreamCollectionTokenInventory";
        names[20] = "StreamConservationRecordSelection";
        names[21] = "StreamContentLeafManifest";
        names[22] = "StreamCore";
        names[23] = "StreamCoreFinalityAdapter";
        names[24] = "StreamEntropyCoordinator";
        names[25] = "StreamExternalArtifactCoverage";
        names[26] = "StreamFinalityArtifactCoverage";
        names[27] = "StreamFinalityCoordinatorInventory";
        names[28] = "StreamFinalityCurrentDiscovery";
        names[29] = "StreamFinalityEntropySourceFactory";
        names[30] = "StreamFinalityNativeEvidenceProvider";
        names[31] = "StreamFinalityScopeMembership";
        names[32] = "StreamFinalityServingHostAdapter";
        names[33] = "StreamFixedPriceSaleAdapter";
        names[34] = "StreamGovernanceExecutor";
        names[35] = "StreamMetadataRouter";
        names[36] = "StreamMintLedger";
        names[37] = "StreamMintManager";
        names[38] = "StreamModuleRegistry";
        names[39] = "StreamOnchainContentCheckpoint";
        names[40] = "StreamReferenceRenderPublication";
        names[41] = "StreamRenderCriticalInventory";
        names[42] = "StreamRevenueEscrow";
        names[43] = "StreamRevenueResolver";
        names[44] = "StreamRightsRecordSelection";
        names[45] = "StreamRoleRegistry";
        names[46] = "StreamRoyaltyResolver";
        names[47] = "StreamSchemaRegistry";
        names[48] = "StreamSplitFactory";
        names[49] = "StreamSystemManifest";
        names[50] = "StreamWorkRecordSelection";
        names[51] = "StreamStaticSelectionCheckpoint";
        names[52] = "StreamStaticContentCheckpoint";
        names[53] = "StreamStaticOutputManifest";
        names[54] = "StreamScopedSnapshotPublication";
        names[55] = "StreamScopedReferencePublication";
        names[56] = "StreamScopedRenderCriticalInventory";
        names[57] = "StreamScopedBundleArchiveCoverage";
        names[58] = "StreamFinalityEntropyPolicySourceFactoryV2";
        names[59] = "StreamFinalityScopedEntropyPolicySourceFactoryV2";
        names[60] = "StreamPolicyPublicationFactoryV2";
        names[61] = "StreamScopedPolicyPublicationFactoryV2";
        names[62] = "StreamFinalityFullPolicyEvidenceProviderV2";
        names[63] = "StreamFinalityFullPolicyDiscoveryV2";
    }

    function _graphCases() private pure returns (uint8[] memory ordinals, string[] memory paths) {
        ordinals = new uint8[](39);
        paths = new string[](39);
        ordinals[0] = 7;
        paths[0] =
            "smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol:StreamArtistIdentityAuthority";
        ordinals[1] = 8;
        paths[1] =
            "smart-contracts/domains/artist/StreamArtistOnboardingCoordinator.sol:StreamArtistOnboardingCoordinator";
        ordinals[2] = 9;
        paths[2] =
            "smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol:StreamArtistOnboardingRegistry";
        ordinals[3] = 12;
        paths[3] =
            "smart-contracts/domains/finality/StreamArtworkFinalityRegistry.sol:StreamArtworkFinalityRegistry";
        ordinals[4] = 14;
        paths[4] =
            "smart-contracts/domains/preservation/StreamArweaveObjectCheckpointVerifier.sol:StreamArweaveObjectCheckpointVerifier";
        ordinals[5] = 16;
        paths[5] =
            "smart-contracts/domains/preservation/StreamBundleArchiveCoverage.sol:StreamBundleArchiveCoverage";
        ordinals[6] = 17;
        paths[6] =
            "smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol:StreamCollectionMetadataV1";
        ordinals[7] = 18;
        paths[7] =
            "smart-contracts/domains/metadata/StreamCollectionSnapshots.sol:StreamCollectionSnapshots";
        ordinals[8] = 19;
        paths[8] =
            "smart-contracts/domains/finality/StreamCollectionTokenInventory.sol:StreamCollectionTokenInventory";
        ordinals[9] = 20;
        paths[9] =
            "smart-contracts/domains/metadata/StreamConservationRecordSelection.sol:StreamConservationRecordSelection";
        ordinals[10] = 21;
        paths[10] =
            "smart-contracts/domains/finality/StreamContentLeafManifest.sol:StreamContentLeafManifest";
        ordinals[11] = 23;
        paths[11] =
            "smart-contracts/domains/finality/StreamCoreFinalityAdapter.sol:StreamCoreFinalityAdapter";
        ordinals[12] = 25;
        paths[12] =
            "smart-contracts/domains/preservation/StreamExternalArtifactCoverage.sol:StreamExternalArtifactCoverage";
        ordinals[13] = 26;
        paths[13] =
            "smart-contracts/domains/preservation/StreamFinalityArtifactCoverage.sol:StreamFinalityArtifactCoverage";
        ordinals[14] = 27;
        paths[14] =
            "smart-contracts/domains/finality/StreamFinalityCoordinatorInventory.sol:StreamFinalityCoordinatorInventory";
        ordinals[15] = 28;
        paths[15] =
            "smart-contracts/domains/finality/StreamFinalityCurrentDiscovery.sol:StreamFinalityCurrentDiscovery";
        ordinals[16] = 29;
        paths[16] =
            "smart-contracts/domains/finality/StreamFinalityEntropySourceFactory.sol:StreamFinalityEntropySourceFactory";
        ordinals[17] = 30;
        paths[17] =
            "smart-contracts/domains/finality/StreamFinalityNativeEvidenceProvider.sol:StreamFinalityNativeEvidenceProvider";
        ordinals[18] = 31;
        paths[18] =
            "smart-contracts/domains/finality/StreamFinalityScopeMembership.sol:StreamFinalityScopeMembership";
        ordinals[19] = 32;
        paths[19] =
            "smart-contracts/domains/finality/StreamFinalityServingHostAdapter.sol:StreamFinalityServingHostAdapter";
        ordinals[20] = 39;
        paths[20] =
            "smart-contracts/domains/finality/StreamOnchainContentCheckpoint.sol:StreamOnchainContentCheckpoint";
        ordinals[21] = 40;
        paths[21] =
            "smart-contracts/domains/preservation/StreamReferenceRenderPublication.sol:StreamReferenceRenderPublication";
        ordinals[22] = 41;
        paths[22] =
            "smart-contracts/domains/preservation/StreamRenderCriticalInventory.sol:StreamRenderCriticalInventory";
        ordinals[23] = 44;
        paths[23] =
            "smart-contracts/domains/metadata/StreamRightsRecordSelection.sol:StreamRightsRecordSelection";
        ordinals[24] = 47;
        paths[24] = "smart-contracts/domains/metadata/StreamSchemaRegistry.sol:StreamSchemaRegistry";
        ordinals[25] = 50;
        paths[25] =
            "smart-contracts/domains/metadata/StreamWorkRecordSelection.sol:StreamWorkRecordSelection";
        ordinals[26] = 51;
        paths[26] =
            "smart-contracts/domains/finality/StreamStaticSelectionCheckpoint.sol:StreamStaticSelectionCheckpoint";
        ordinals[27] = 52;
        paths[27] =
            "smart-contracts/domains/finality/StreamStaticContentCheckpoint.sol:StreamStaticContentCheckpoint";
        ordinals[28] = 53;
        paths[28] =
            "smart-contracts/domains/finality/StreamStaticOutputManifest.sol:StreamStaticOutputManifest";
        ordinals[29] = 54;
        paths[29] =
            "smart-contracts/domains/metadata/StreamScopedSnapshotPublication.sol:StreamScopedSnapshotPublication";
        ordinals[30] = 55;
        paths[30] =
            "smart-contracts/domains/preservation/StreamScopedReferencePublication.sol:StreamScopedReferencePublication";
        ordinals[31] = 56;
        paths[31] =
            "smart-contracts/domains/preservation/StreamScopedRenderCriticalInventory.sol:StreamScopedRenderCriticalInventory";
        ordinals[32] = 57;
        paths[32] =
            "smart-contracts/domains/preservation/StreamScopedBundleArchiveCoverage.sol:StreamScopedBundleArchiveCoverage";
        ordinals[33] = 58;
        paths[33] =
            "smart-contracts/domains/finality/StreamFinalityEntropyPolicySourceFactoryV2.sol:StreamFinalityEntropyPolicySourceFactoryV2";
        ordinals[34] = 59;
        paths[34] =
            "smart-contracts/domains/finality/StreamFinalityScopedEntropyPolicySourceFactoryV2.sol:StreamFinalityScopedEntropyPolicySourceFactoryV2";
        ordinals[35] = 60;
        paths[35] =
            "smart-contracts/domains/finality/StreamPolicyPublicationFactoryV2.sol:StreamPolicyPublicationFactoryV2";
        ordinals[36] = 61;
        paths[36] =
            "smart-contracts/domains/finality/StreamScopedPolicyPublicationFactoryV2.sol:StreamScopedPolicyPublicationFactoryV2";
        ordinals[37] = 62;
        paths[37] =
            "smart-contracts/domains/finality/StreamFinalityFullPolicyEvidenceProviderV2.sol:StreamFinalityFullPolicyEvidenceProviderV2";
        ordinals[38] = 63;
        paths[38] =
            "smart-contracts/domains/finality/StreamFinalityFullPolicyDiscoveryV2.sol:StreamFinalityFullPolicyDiscoveryV2";
    }

    function _authorityCases() private pure returns (string[] memory paths) {
        paths = new string[](10);
        paths[0] =
            "smart-contracts/domains/preservation/StreamCurrentAuthorityBundleArchiveCoverage.sol:StreamCurrentAuthorityBundleArchiveCoverage";
        paths[1] =
            "smart-contracts/domains/finality/StreamCurrentAuthorityNativeEvidenceProvider.sol:StreamCurrentAuthorityNativeEvidenceProvider";
        paths[2] =
            "smart-contracts/domains/preservation/StreamArtistArchiveOriginReads.sol:StreamArtistArchiveOriginReads";
        paths[3] =
            "smart-contracts/domains/preservation/StreamArtistCurrentAuthorityResolver.sol:StreamArtistCurrentAuthorityResolver";
        paths[4] =
            "smart-contracts/domains/finality/StreamLineageArtworkFinalityRegistry.sol:StreamLineageArtworkFinalityRegistry";
        paths[5] =
            "smart-contracts/domains/finality/StreamFinalityLineageCurrentDiscovery.sol:StreamFinalityLineageCurrentDiscovery";
        paths[6] =
            "smart-contracts/domains/metadata/StreamCurrentAuthorityWorkRecordSelection.sol:StreamCurrentAuthorityWorkRecordSelection";
        paths[7] =
            "smart-contracts/domains/metadata/StreamCurrentAuthorityConservationRecordSelection.sol:StreamCurrentAuthorityConservationRecordSelection";
        paths[8] =
            "smart-contracts/domains/preservation/StreamCurrentAuthorityRenderCriticalInventory.sol:StreamCurrentAuthorityRenderCriticalInventory";
        paths[9] =
            "smart-contracts/domains/metadata/StreamCurrentAuthorityRightsRecordSelection.sol:StreamCurrentAuthorityRightsRecordSelection";
    }

    function _scopedCases() private pure returns (string[] memory names, string[] memory paths) {
        names = new string[](23);
        paths = new string[](23);
        names[0] = "StreamCurrentAuthorityPreservationPolicyPublicationFactoryV1";
        paths[0] =
            "smart-contracts/domains/finality/StreamCurrentAuthorityPreservationPolicyPublicationFactoryV1.sol:StreamCurrentAuthorityPreservationPolicyPublicationFactoryV1";
        names[1] = "StreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1";
        paths[1] =
            "smart-contracts/domains/finality/StreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1.sol:StreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1";
        names[2] = "StreamCurrentAuthorityFullPreservationPolicyEvidenceProviderV1";
        paths[2] =
            "smart-contracts/domains/finality/StreamCurrentAuthorityFullPreservationPolicyEvidenceProviderV1.sol:StreamCurrentAuthorityFullPreservationPolicyEvidenceProviderV1";
        names[3] = "StreamCurrentAuthorityFullPreservationPolicyDiscoveryV1";
        paths[3] =
            "smart-contracts/domains/finality/StreamCurrentAuthorityFullPreservationPolicyDiscoveryV1.sol:StreamCurrentAuthorityFullPreservationPolicyDiscoveryV1";
        names[4] = "StreamStaticSelectionCheckpoint";
        paths[4] =
            "smart-contracts/domains/finality/StreamStaticSelectionCheckpoint.sol:StreamStaticSelectionCheckpoint";
        names[5] = "StreamStaticContentCheckpoint";
        paths[5] =
            "smart-contracts/domains/finality/StreamStaticContentCheckpoint.sol:StreamStaticContentCheckpoint";
        names[6] = "StreamStaticOutputManifest";
        paths[6] =
            "smart-contracts/domains/finality/StreamStaticOutputManifest.sol:StreamStaticOutputManifest";
        names[7] = "StreamScopedSnapshotPublication";
        paths[7] =
            "smart-contracts/domains/metadata/StreamScopedSnapshotPublication.sol:StreamScopedSnapshotPublication";
        names[8] = "StreamScopedReferencePublication";
        paths[8] =
            "smart-contracts/domains/preservation/StreamScopedReferencePublication.sol:StreamScopedReferencePublication";
        names[9] = "StreamFinalityEntropyPolicySourceFactoryV2";
        paths[9] =
            "smart-contracts/domains/finality/StreamFinalityEntropyPolicySourceFactoryV2.sol:StreamFinalityEntropyPolicySourceFactoryV2";
        names[10] = "StreamFinalityScopedEntropyPolicySourceFactoryV2";
        paths[10] =
            "smart-contracts/domains/finality/StreamFinalityScopedEntropyPolicySourceFactoryV2.sol:StreamFinalityScopedEntropyPolicySourceFactoryV2";
        names[11] = "StreamTerminalEntropyReadiness";
        paths[11] =
            "smart-contracts/domains/finality/StreamTerminalEntropyReadiness.sol:StreamTerminalEntropyReadiness";
        names[12] = "StreamPolicyContentCheckpointV2";
        paths[12] =
            "smart-contracts/domains/finality/StreamPolicyContentCheckpointV2.sol:StreamPolicyContentCheckpointV2";
        names[13] = "StreamPolicyOutputManifestV2";
        paths[13] =
            "smart-contracts/domains/finality/StreamPolicyOutputManifestV2.sol:StreamPolicyOutputManifestV2";
        names[14] = "StreamPolicySnapshotPublicationV2";
        paths[14] =
            "smart-contracts/domains/metadata/StreamPolicySnapshotPublicationV2.sol:StreamPolicySnapshotPublicationV2";
        names[15] = "StreamPolicyReferencePublicationV2";
        paths[15] =
            "smart-contracts/domains/preservation/StreamPolicyReferencePublicationV2.sol:StreamPolicyReferencePublicationV2";
        names[16] = "StreamCurrentAuthorityScopedRenderCriticalInventory";
        paths[16] =
            "smart-contracts/domains/preservation/StreamCurrentAuthorityScopedRenderCriticalInventory.sol:StreamCurrentAuthorityScopedRenderCriticalInventory";
        names[17] = "StreamCurrentAuthorityPolicyRenderCriticalInventoryV2";
        paths[17] =
            "smart-contracts/domains/preservation/StreamCurrentAuthorityPolicyRenderCriticalInventoryV2.sol:StreamCurrentAuthorityPolicyRenderCriticalInventoryV2";
        names[18] = "StreamCurrentAuthorityScopedBundleArchiveCoverage";
        paths[18] =
            "smart-contracts/domains/preservation/StreamCurrentAuthorityScopedBundleArchiveCoverage.sol:StreamCurrentAuthorityScopedBundleArchiveCoverage";
        names[19] = "StreamCurrentAuthorityBundleArchiveCoverage";
        paths[19] =
            "smart-contracts/domains/preservation/StreamCurrentAuthorityBundleArchiveCoverage.sol:StreamCurrentAuthorityBundleArchiveCoverage";
        names[20] = "StreamCurrentAuthorityScopedPolicyPublicationFactoryV2";
        paths[20] =
            "smart-contracts/domains/finality/StreamCurrentAuthorityScopedPolicyPublicationFactoryV2.sol:StreamCurrentAuthorityScopedPolicyPublicationFactoryV2";
        names[21] = "StreamCurrentAuthorityDeferredScopedPolicyEvidenceProviderV2";
        paths[21] =
            "smart-contracts/domains/finality/StreamCurrentAuthorityDeferredScopedPolicyEvidenceProviderV2.sol:StreamCurrentAuthorityDeferredScopedPolicyEvidenceProviderV2";
        names[22] = "StreamFinalityLineageDeferredScopedPolicyDiscoveryV2";
        paths[22] =
            "smart-contracts/domains/finality/StreamFinalityLineageDeferredScopedPolicyDiscoveryV2.sol:StreamFinalityLineageDeferredScopedPolicyDiscoveryV2";
    }
}
