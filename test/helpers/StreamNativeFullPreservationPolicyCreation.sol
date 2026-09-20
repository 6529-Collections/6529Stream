// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamPreservationPolicyPublicationFactoryV1
} from "../../smart-contracts/domains/finality/StreamPreservationPolicyPublicationFactoryV1.sol";
import {
    StreamScopedPreservationPolicyPublicationFactoryV1
} from "../../smart-contracts/domains/finality/StreamScopedPreservationPolicyPublicationFactoryV1.sol";
import {
    StreamFinalityFullPreservationPolicyEvidenceProviderV1
} from "../../smart-contracts/domains/finality/StreamFinalityFullPreservationPolicyEvidenceProviderV1.sol";
import {
    StreamFinalityFullPreservationPolicyDiscoveryV1
} from "../../smart-contracts/domains/finality/StreamFinalityFullPreservationPolicyDiscoveryV1.sol";

/// @notice Test-only public literal creation templates, mirroring the original native fixture.
/// @dev This fixture library is not a production product; all products retain their size/link checks.
library StreamNativeFullPreservationPolicyCreation {
    enum Kind {
        StreamPreservationPolicyPublicationFactoryV1,
        StreamScopedPreservationPolicyPublicationFactoryV1,
        StreamFinalityFullPreservationPolicyEvidenceProviderV1,
        StreamFinalityFullPreservationPolicyDiscoveryV1
    }

    function name(Kind kind) internal pure returns (string memory) {
        if (kind == Kind.StreamPreservationPolicyPublicationFactoryV1) {
            return "StreamPreservationPolicyPublicationFactoryV1";
        }
        if (kind == Kind.StreamScopedPreservationPolicyPublicationFactoryV1) {
            return "StreamScopedPreservationPolicyPublicationFactoryV1";
        }
        if (kind == Kind.StreamFinalityFullPreservationPolicyEvidenceProviderV1) {
            return "StreamFinalityFullPreservationPolicyEvidenceProviderV1";
        }
        if (kind == Kind.StreamFinalityFullPreservationPolicyDiscoveryV1) {
            return "StreamFinalityFullPreservationPolicyDiscoveryV1";
        }
        revert("unknown preservation creation kind");
    }

    function creation(Kind kind) public pure returns (bytes memory) {
        if (kind == Kind.StreamPreservationPolicyPublicationFactoryV1) {
            return type(StreamPreservationPolicyPublicationFactoryV1).creationCode;
        }
        if (kind == Kind.StreamScopedPreservationPolicyPublicationFactoryV1) {
            return type(StreamScopedPreservationPolicyPublicationFactoryV1).creationCode;
        }
        if (kind == Kind.StreamFinalityFullPreservationPolicyEvidenceProviderV1) {
            return type(StreamFinalityFullPreservationPolicyEvidenceProviderV1).creationCode;
        }
        if (kind == Kind.StreamFinalityFullPreservationPolicyDiscoveryV1) {
            return type(StreamFinalityFullPreservationPolicyDiscoveryV1).creationCode;
        }
        revert("unknown preservation creation kind");
    }
}
