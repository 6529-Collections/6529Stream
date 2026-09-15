// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistPlatformState.sol";
import {
    StreamArtistAttestationTypes as Attest
} from "../../interfaces/stream/artist/IStreamArtistAttestationWriter.sol";
import "./StreamArtistAttributionClaimState.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionClaims.sol";
import "../../interfaces/stream/artist/IStreamArtistDisplayFacts.sol";
import "./StreamArtistAttributionPolicy.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityRevision.sol";

import "./StreamArtistCurrentAuthorityFacts.sol";
import "./StreamArtistRecordPublicationState.sol";
import "../../interfaces/stream/artist/IStreamArtistRecordPublicationOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistSanctionConfirmation.sol";
import {
    StreamArtistBindingLifecycleTypes as L
} from "../../interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

library StreamArtistAttributionStateTypes {
    struct Attribution {
        uint8 state;
        uint64 generation;
    }

    struct AttestationContext {
        bytes32 operativeIdentityHash;
        address signer;
        uint256 nonce;
        uint64 signedAt;
        uint8 authorityClass;
        bytes32 verifiedSubjectHash;
        bytes32 associationHash;
    }

    /// @dev Exact view beginning at the owner's original _attributions.slot, with no new root.
    struct State {
        mapping(uint256 => Attribution) attributions;
        mapping(bytes32 => T.AttestationRecord) attestations;
        mapping(bytes32 => T.AttestationRecord) records;
        mapping(bytes32 => bytes) statements;
        mapping(bytes32 => IStreamArtistRecordPublicationOwner.Record) publications;
        StreamArtistPlatformState.Store platform;
        mapping(bytes32 => uint8) attestationClasses;
        StreamArtistAttributionClaimState.Store attributionClaims;
        mapping(uint256 => bytes32) latestDisplayClaim;
        mapping(bytes32 => Attest.Association) attestationAssociations;
    }

    struct Mutation {
        bytes32 record;
        bytes32 action;
        bytes32 stateDelta;
    }
}
