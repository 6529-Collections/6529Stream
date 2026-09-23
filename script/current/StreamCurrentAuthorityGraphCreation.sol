// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamCurrentAuthorityBundleArchiveCoverage
} from "../../smart-contracts/domains/preservation/StreamCurrentAuthorityBundleArchiveCoverage.sol";
import {
    StreamCurrentAuthorityNativeEvidenceProvider
} from "../../smart-contracts/domains/finality/StreamCurrentAuthorityNativeEvidenceProvider.sol";
import {
    StreamArtistArchiveOriginReads
} from "../../smart-contracts/domains/preservation/StreamArtistArchiveOriginReads.sol";
import {
    StreamArtistCurrentAuthorityResolver
} from "../../smart-contracts/domains/preservation/StreamArtistCurrentAuthorityResolver.sol";
import {
    StreamLineageArtworkFinalityRegistry
} from "../../smart-contracts/domains/finality/StreamLineageArtworkFinalityRegistry.sol";
import {
    StreamFinalityLineageCurrentDiscovery
} from "../../smart-contracts/domains/finality/StreamFinalityLineageCurrentDiscovery.sol";
import {
    StreamCurrentAuthorityWorkRecordSelection
} from "../../smart-contracts/domains/metadata/StreamCurrentAuthorityWorkRecordSelection.sol";
import {
    StreamCurrentAuthorityConservationRecordSelection
} from "../../smart-contracts/domains/metadata/StreamCurrentAuthorityConservationRecordSelection.sol";
import {
    StreamCurrentAuthorityRenderCriticalInventory
} from "../../smart-contracts/domains/preservation/StreamCurrentAuthorityRenderCriticalInventory.sol";
import {
    StreamCurrentAuthorityRightsRecordSelection
} from "../../smart-contracts/domains/metadata/StreamCurrentAuthorityRightsRecordSelection.sol";

/// @notice Literal linked creation templates for the additive original-authority graph.
/// @dev Simulation-only; no library instance is broadcast and no existing Kind value changes.
library StreamCurrentAuthorityGraphCreation {
    enum Kind {
        StreamCurrentAuthorityBundleArchiveCoverage,
        StreamCurrentAuthorityNativeEvidenceProvider,
        StreamArtistArchiveOriginReads,
        StreamArtistCurrentAuthorityResolver,
        StreamLineageArtworkFinalityRegistry,
        StreamFinalityLineageCurrentDiscovery,
        StreamCurrentAuthorityWorkRecordSelection,
        StreamCurrentAuthorityConservationRecordSelection,
        StreamCurrentAuthorityRenderCriticalInventory,
        StreamCurrentAuthorityRightsRecordSelection
    }

    function name(Kind kind) internal pure returns (string memory) {
        if (kind == Kind.StreamCurrentAuthorityBundleArchiveCoverage) {
            return "StreamCurrentAuthorityBundleArchiveCoverage";
        }
        if (kind == Kind.StreamCurrentAuthorityNativeEvidenceProvider) {
            return "StreamCurrentAuthorityNativeEvidenceProvider";
        }
        if (kind == Kind.StreamArtistArchiveOriginReads) return "StreamArtistArchiveOriginReads";
        if (kind == Kind.StreamArtistCurrentAuthorityResolver) {
            return "StreamArtistCurrentAuthorityResolver";
        }
        if (kind == Kind.StreamLineageArtworkFinalityRegistry) {
            return "StreamLineageArtworkFinalityRegistry";
        }
        if (kind == Kind.StreamFinalityLineageCurrentDiscovery) {
            return "StreamFinalityLineageCurrentDiscovery";
        }
        if (kind == Kind.StreamCurrentAuthorityWorkRecordSelection) {
            return "StreamCurrentAuthorityWorkRecordSelection";
        }
        if (kind == Kind.StreamCurrentAuthorityConservationRecordSelection) {
            return "StreamCurrentAuthorityConservationRecordSelection";
        }
        if (kind == Kind.StreamCurrentAuthorityRenderCriticalInventory) {
            return "StreamCurrentAuthorityRenderCriticalInventory";
        }
        if (kind == Kind.StreamCurrentAuthorityRightsRecordSelection) {
            return "StreamCurrentAuthorityRightsRecordSelection";
        }
        revert("unknown authority product template");
    }

    function code(Kind kind) internal pure returns (bytes memory) {
        if (kind == Kind.StreamCurrentAuthorityBundleArchiveCoverage) {
            return type(StreamCurrentAuthorityBundleArchiveCoverage).creationCode;
        }
        if (kind == Kind.StreamCurrentAuthorityNativeEvidenceProvider) {
            return type(StreamCurrentAuthorityNativeEvidenceProvider).creationCode;
        }
        if (kind == Kind.StreamArtistArchiveOriginReads) {
            return type(StreamArtistArchiveOriginReads).creationCode;
        }
        if (kind == Kind.StreamArtistCurrentAuthorityResolver) {
            return type(StreamArtistCurrentAuthorityResolver).creationCode;
        }
        if (kind == Kind.StreamLineageArtworkFinalityRegistry) {
            return type(StreamLineageArtworkFinalityRegistry).creationCode;
        }
        if (kind == Kind.StreamFinalityLineageCurrentDiscovery) {
            return type(StreamFinalityLineageCurrentDiscovery).creationCode;
        }
        if (kind == Kind.StreamCurrentAuthorityWorkRecordSelection) {
            return type(StreamCurrentAuthorityWorkRecordSelection).creationCode;
        }
        if (kind == Kind.StreamCurrentAuthorityConservationRecordSelection) {
            return type(StreamCurrentAuthorityConservationRecordSelection).creationCode;
        }
        if (kind == Kind.StreamCurrentAuthorityRenderCriticalInventory) {
            return type(StreamCurrentAuthorityRenderCriticalInventory).creationCode;
        }
        if (kind == Kind.StreamCurrentAuthorityRightsRecordSelection) {
            return type(StreamCurrentAuthorityRightsRecordSelection).creationCode;
        }
        revert("unknown authority product template");
    }
}
