// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamStaticSelectionCheckpoint
} from "../../smart-contracts/domains/finality/StreamStaticSelectionCheckpoint.sol";
import {
    StreamStaticContentCheckpoint
} from "../../smart-contracts/domains/finality/StreamStaticContentCheckpoint.sol";
import {
    StreamStaticOutputManifest
} from "../../smart-contracts/domains/finality/StreamStaticOutputManifest.sol";
import {
    StreamScopedSnapshotPublication
} from "../../smart-contracts/domains/metadata/StreamScopedSnapshotPublication.sol";
import {
    StreamScopedReferencePublication
} from "../../smart-contracts/domains/preservation/StreamScopedReferencePublication.sol";
import {
    StreamFinalityEntropyPolicySourceFactoryV2
} from "../../smart-contracts/domains/finality/StreamFinalityEntropyPolicySourceFactoryV2.sol";
import {
    StreamFinalityScopedEntropyPolicySourceFactoryV2
} from "../../smart-contracts/domains/finality/StreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    StreamTerminalEntropyReadiness
} from "../../smart-contracts/domains/finality/StreamTerminalEntropyReadiness.sol";
import {
    StreamPolicyContentCheckpointV2
} from "../../smart-contracts/domains/finality/StreamPolicyContentCheckpointV2.sol";
import {
    StreamPolicyOutputManifestV2
} from "../../smart-contracts/domains/finality/StreamPolicyOutputManifestV2.sol";
import {
    StreamPolicySnapshotPublicationV2
} from "../../smart-contracts/domains/metadata/StreamPolicySnapshotPublicationV2.sol";
import {
    StreamPolicyReferencePublicationV2
} from "../../smart-contracts/domains/preservation/StreamPolicyReferencePublicationV2.sol";
import {
    StreamCurrentAuthorityScopedRenderCriticalInventory
} from "../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedRenderCriticalInventory.sol";
import {
    StreamCurrentAuthorityPolicyRenderCriticalInventoryV2
} from "../../smart-contracts/domains/preservation/StreamCurrentAuthorityPolicyRenderCriticalInventoryV2.sol";
import {
    StreamCurrentAuthorityScopedBundleArchiveCoverage
} from "../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedBundleArchiveCoverage.sol";
import {
    StreamCurrentAuthorityBundleArchiveCoverage
} from "../../smart-contracts/domains/preservation/StreamCurrentAuthorityBundleArchiveCoverage.sol";
import {
    StreamCurrentAuthorityScopedPolicyPublicationFactoryV2
} from "../../smart-contracts/domains/finality/StreamCurrentAuthorityScopedPolicyPublicationFactoryV2.sol";
import {
    StreamCurrentAuthorityDeferredScopedPolicyEvidenceProviderV2
} from "../../smart-contracts/domains/finality/StreamCurrentAuthorityDeferredScopedPolicyEvidenceProviderV2.sol";
import {
    StreamFinalityLineageDeferredScopedPolicyDiscoveryV2
} from "../../smart-contracts/domains/finality/StreamFinalityLineageDeferredScopedPolicyDiscoveryV2.sol";

/// @notice Literal linked templates for the new original scoped-policy deployment recipe.
/// @dev Simulation-only; no helper library instance is a protocol authority or deployed product.
library StreamCurrentAuthorityScopedPolicyGraphCreation {
    function code(string memory name) internal pure returns (bytes memory) {
        bytes32 key = keccak256(bytes(name));
        if (key == keccak256("StreamStaticSelectionCheckpoint")) {
            return type(StreamStaticSelectionCheckpoint).creationCode;
        }
        if (key == keccak256("StreamStaticContentCheckpoint")) {
            return type(StreamStaticContentCheckpoint).creationCode;
        }
        if (key == keccak256("StreamStaticOutputManifest")) {
            return type(StreamStaticOutputManifest).creationCode;
        }
        if (key == keccak256("StreamScopedSnapshotPublication")) {
            return type(StreamScopedSnapshotPublication).creationCode;
        }
        if (key == keccak256("StreamScopedReferencePublication")) {
            return type(StreamScopedReferencePublication).creationCode;
        }
        if (key == keccak256("StreamFinalityEntropyPolicySourceFactoryV2")) {
            return type(StreamFinalityEntropyPolicySourceFactoryV2).creationCode;
        }
        if (key == keccak256("StreamFinalityScopedEntropyPolicySourceFactoryV2")) {
            return type(StreamFinalityScopedEntropyPolicySourceFactoryV2).creationCode;
        }
        if (key == keccak256("StreamTerminalEntropyReadiness")) {
            return type(StreamTerminalEntropyReadiness).creationCode;
        }
        if (key == keccak256("StreamPolicyContentCheckpointV2")) {
            return type(StreamPolicyContentCheckpointV2).creationCode;
        }
        if (key == keccak256("StreamPolicyOutputManifestV2")) {
            return type(StreamPolicyOutputManifestV2).creationCode;
        }
        if (key == keccak256("StreamPolicySnapshotPublicationV2")) {
            return type(StreamPolicySnapshotPublicationV2).creationCode;
        }
        if (key == keccak256("StreamPolicyReferencePublicationV2")) {
            return type(StreamPolicyReferencePublicationV2).creationCode;
        }
        if (key == keccak256("StreamCurrentAuthorityScopedRenderCriticalInventory")) {
            return type(StreamCurrentAuthorityScopedRenderCriticalInventory).creationCode;
        }
        if (key == keccak256("StreamCurrentAuthorityPolicyRenderCriticalInventoryV2")) {
            return type(StreamCurrentAuthorityPolicyRenderCriticalInventoryV2).creationCode;
        }
        if (key == keccak256("StreamCurrentAuthorityScopedBundleArchiveCoverage")) {
            return type(StreamCurrentAuthorityScopedBundleArchiveCoverage).creationCode;
        }
        if (key == keccak256("StreamCurrentAuthorityBundleArchiveCoverage")) {
            return type(StreamCurrentAuthorityBundleArchiveCoverage).creationCode;
        }
        if (key == keccak256("StreamCurrentAuthorityScopedPolicyPublicationFactoryV2")) {
            return type(StreamCurrentAuthorityScopedPolicyPublicationFactoryV2).creationCode;
        }
        if (key == keccak256("StreamCurrentAuthorityDeferredScopedPolicyEvidenceProviderV2")) {
            return type(StreamCurrentAuthorityDeferredScopedPolicyEvidenceProviderV2).creationCode;
        }
        if (key == keccak256("StreamFinalityLineageDeferredScopedPolicyDiscoveryV2")) {
            return type(StreamFinalityLineageDeferredScopedPolicyDiscoveryV2).creationCode;
        }
        revert("unknown original scoped-policy product");
    }
}
