// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtworkFinalityTypes.sol";

/// @notice Actual reviewed object hashes derived from the authoritative finality scope inventory.
interface IStreamFinalitySanctionReview {
    /// @dev Version1 supports profile1: ONCHAIN content-root plus exactly one reference capture.
    ///      Profile1 has no mediaContentHashes. Future profiles must be admitted explicitly.
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
    ///      return encoding is bounded to1280bytes (both arrays16); profile1 encodes to288bytes.
    function requireSanctionReviewFacts(
        StreamFinalityScope calldata scope,
        bytes32 manifestContentHash
    ) external view returns (ReviewFacts memory);
}
