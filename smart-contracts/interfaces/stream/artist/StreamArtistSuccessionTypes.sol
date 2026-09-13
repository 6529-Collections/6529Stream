// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistRotationTypes.sol";

library StreamArtistSuccessionTypes {
    struct Designation {
        bytes32 artistId;
        address successor;
        uint8 successorKind;
        uint32 grantedCapabilities;
        bytes32 conditionsHash;
        bytes32 directiveHash;
    }

    struct Directive {
        bytes32 artistId;
        uint32 grantedCapabilities;
        uint32 forbiddenCapabilities;
        bytes32 directivePayloadHash;
    }

    struct PublicDocument {
        bytes32 legalInstrumentHash;
        bytes32 payoutRoutingIntentHash;
    }

    struct DesignationRecord {
        bytes32 recordHash;
        Designation terms;
        address signer;
        uint8 authorityClass;
        uint256 nonce;
        uint64 signedAt;
        StreamArtistRotationTypes.ProvisionalAssociation provisional;
    }

    struct DirectiveRecord {
        bytes32 recordHash;
        Directive terms;
        address signer;
        uint8 authorityClass;
        uint256 nonce;
        uint64 signedAt;
        StreamArtistRotationTypes.ProvisionalAssociation provisional;
    }
    error InvalidSuccessor();
    error InvalidDirective();
    error ForbiddenCapability(bytes32 artistId, uint32 capabilities, bytes32 directiveRecordHash);
}
