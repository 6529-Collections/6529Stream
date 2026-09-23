// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistIdentityRecoveryOperationTypes as R
} from "./StreamArtistIdentityRecoveryOperationTypes.sol";
import { StreamArtistSuccessionTypes as S } from "./StreamArtistSuccessionTypes.sol";

/// @notice Typed evidence and the restricted root-admin appeal profile; no authority is granted by publication.
library StreamArtistGuardianAppealTypes {
    bytes32 internal constant ARBITER = keccak256("ROLE_ATTRIBUTION_ARBITER");
    bytes32 internal constant APPEAL = keccak256("ROLE_ATTRIBUTION_APPEAL");

    struct Finding {
        bytes32 guardianRecordHash;
        address[] parties;
    }

    struct Document {
        bytes32 requestCommitment;
        bytes32 causeHash;
        bytes32 contestRecordHash;
        bytes32 vestingCommitment;
        bytes32 transitionRecordHash;
        bytes32 hostileFindingsHash;
        Finding[] findings;
    }

    struct Authority {
        address executor;
        address roles;
        address root;
        bytes32 rootCodeHash;
        uint64 rootRevision;
        bytes32 roleMutationHash;
        uint64 roleRevision;
    }

    struct Evidence {
        Document document;
        Authority authority;
        S.DirectiveRecord directive;
    }

    error InvalidGuardianAppeal(bytes32 recordHash);
    error GuardianAppealDependencyChanged(address target);

    function requestCommitment(R.Request memory request) internal pure returns (bytes32) {
        // The only omitted word is the resulting document hash. Preserve every other request field.
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_GUARDIAN_APPEAL_REQUEST_V1"),
                uint16(1),
                request.artistId,
                request.newAddress,
                request.vestedAuthorityClass,
                request.expectedCauseHash,
                request.expectedResolutionHash,
                bytes32(0),
                request.reasonHash,
                request.supersededRecordHashes
            )
        );
    }

    function documentHash(
        uint256 chainId,
        address registry,
        address owner,
        Document memory document
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_HOSTILE_GUARDIAN_EVIDENCE_V1"),
                uint16(1),
                chainId,
                registry,
                owner,
                document
            )
        );
    }
}
