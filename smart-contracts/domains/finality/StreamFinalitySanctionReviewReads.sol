// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityBoundedReads.sol";
import {
    StreamFinalityViewSanctionReviewCodecV1 as ViewReview
} from "./StreamFinalityViewSanctionReviewCodecV1.sol";
import "../../interfaces/stream/finality/IStreamFinalitySanctionReview.sol";

/// @notice Bounded canonical native review envelopes; no dynamic decoder sees unchecked lengths.
library StreamFinalitySanctionReviewReads {
    error SanctionReviewReadFailed(address target);
    error SanctionReviewEnvelopeInvalid();

    function read(address target, bytes memory input, uint256 maximum, uint256 cap)
        public
        view
        returns (bytes memory raw)
    {
        raw = new bytes(maximum);
        uint256 available = gasleft();
        if (available <= 100000) revert SanctionReviewReadFailed(target);
        uint256 forwarded = available - 100000;
        if (cap < forwarded) forwarded = cap;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(forwarded, target, add(input, 32), mload(input), add(raw, 32), maximum)
            size := returndatasize()
        }
        if (!ok || size > maximum || size < 32) revert SanctionReviewReadFailed(target);
        // New VIEW calls reserve both original sixteen-entry arrays. Other profiles retain
        // their exact former transport maximum, including unknown-profile failure ordering.
        uint256 base = maximum == 1280 ? 32 : maximum == 1408 ? 160 : maximum == 1664 ? 416 : 0;
        if (base != 0 && (size < base + 64 || _word(raw, base + 32) != 3) && size > base + 736) {
            revert SanctionReviewReadFailed(target);
        }
        assembly ("memory-safe") { mstore(raw, size) }
    }

    /// @dev Base is32 for the original review,160 for Registry preparation,416 for provider inputs.
    /// All prefix fields are static bytes32 values. The final dynamic tuple is the entire tail.
    function review(bytes memory raw, uint256 base)
        public
        pure
        returns (IStreamFinalitySanctionReview.ReviewFacts memory result)
    {
        if (
            (base == 32 || base == 160 || base == 416) && raw.length >= base + 256
                && _word(raw, base + 32) == 3
        ) {
            return ViewReview.review(raw, base);
        }
        if (
            (base != 32 && base != 160 && base != 416) || raw.length < base + 256
                || _word(raw, base - 32) != base
        ) revert SanctionReviewEnvelopeInvalid();
        uint256 count = _word(raw, base + 192);
        uint256 profile = _word(raw, base + 32);
        if (
            _word(raw, base) != 1 || _word(raw, base + 64) == 0 || _word(raw, base + 96) != 160
                || _word(raw, base + 128) != 192 || _word(raw, base + 160) != 0 || count == 0
                || count > 16 || raw.length != base + 224 + count * 32
                || !((profile == 1 && count == 1) || (profile == 2 && count >= 2))
        ) {
            revert SanctionReviewEnvelopeInvalid();
        }
        result.schemaVersion = 1;
        result.profile = uint8(profile);
        result.contentRoot = bytes32(_word(raw, base + 64));
        result.mediaContentHashes = new bytes32[](0);
        result.referenceRenderContentHashes = new bytes32[](count);
        for (uint256 i; i < count; ++i) {
            bytes32 hash = bytes32(_word(raw, base + 224 + i * 32));
            if (hash == 0) revert SanctionReviewEnvelopeInvalid();
            result.referenceRenderContentHashes[i] = hash;
        }
    }

    function _word(bytes memory raw, uint256 offset) private pure returns (uint256 value) {
        assembly ("memory-safe") { value := mload(add(add(raw, 32), offset)) }
    }
}
