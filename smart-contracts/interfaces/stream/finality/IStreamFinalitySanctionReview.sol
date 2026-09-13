// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtworkFinalityTypes.sol";

/// @notice Actual reviewed object hashes derived from the authoritative finality scope inventory.
interface IStreamFinalitySanctionReview {
    /// @dev Version1 profile1 retains exactly one ONCHAIN reference capture; profile2 retains
    ///      the complete ordered two-to-sixteen capture list. Both have no mediaContentHashes.
    ///      Unknown profiles remain unsupported; future profiles require explicit admission.
    ///      Lists are ordered artifact content hashes, never metadata record hashes or component
    ///      commitments. Each list has at most16 entries; repeated bytes at separate positions
    ///      remain meaningful if the authoritative inventory includes them.
    struct ReviewFacts {
        uint16 schemaVersion;
        uint8 profile;
        bytes32 contentRoot;
        bytes32[] mediaContentHashes;
        bytes32[] referenceRenderContentHashes;
    }

    /// @notice Uses the same current validated scope/manifest evidence as requireFinalityScopeInputs.
    /// @dev Unknown/unsupported profiles, stale evidence, missing actual reference payloads and wrong
    ///      scope membership revert. Callers do not supply the covered hash lists. The canonical
    ///      native return encoding is256+32*n bytes: profile1 is288, profile2 is320..768.
    ///      The generic two-array vocabulary can encode1280 bytes; that does not admit other profiles.
    function requireSanctionReviewFacts(
        StreamFinalityScope calldata scope,
        bytes32 manifestContentHash
    ) external view returns (ReviewFacts memory);
}
