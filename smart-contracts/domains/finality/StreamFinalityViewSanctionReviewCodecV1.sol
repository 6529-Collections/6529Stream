// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/finality/IStreamFinalitySanctionReview.sol";
import {
    StreamFinalityViewPreservationInputSchemasV1 as Schemas
} from "./StreamFinalityViewPreservationInputSchemasV1.sol";

/// @notice Closed profile3 envelope. Sixteen per list is the original ceremony/schema limit.
/// @dev Allocation follows checked count/offset/length predicates, never unchecked abi.decode.
library StreamFinalityViewSanctionReviewCodecV1 {
    uint256 internal constant STANDALONE = 1280;
    uint256 internal constant PREPARATION = 1408;
    uint256 internal constant PREPARED_INPUTS = 1664;
    error InvalidViewSanctionReview();

    function requireScope(StreamFinalityScope memory scope, bytes32 schema, bytes32 canon)
        internal
        pure
    {
        if (
            scope.scopeType != StreamFinalityScopeType.VIEW || scope.collectionId == 0
                || scope.tokenId != 0 || scope.scopeId == 0 || schema != Schemas.SCHEMA_ID
                || canon != Schemas.CANON_ID
        ) revert InvalidViewSanctionReview();
    }

    function review(bytes memory raw, uint256 base)
        public
        pure
        returns (IStreamFinalitySanctionReview.ReviewFacts memory r)
    {
        if (
            (base != 32 && base != 160 && base != 416) || raw.length < base + 288
                || _word(raw, base - 32) != base || _word(raw, base) != 1
                || _word(raw, base + 32) != 3 || _word(raw, base + 64) == 0
                || _word(raw, base + 96) != 160
        ) {
            revert InvalidViewSanctionReview();
        }
        uint256 media = _word(raw, base + 160);
        if (media == 0 || media > 16 || _word(raw, base + 128) != 192 + media * 32) {
            revert InvalidViewSanctionReview();
        }
        uint256 referencesAt = base + 192 + media * 32;
        if (raw.length < referencesAt + 32) revert InvalidViewSanctionReview();
        uint256 refs = _word(raw, referencesAt);
        if (refs == 0 || refs > 16 || raw.length != referencesAt + 32 + refs * 32) {
            revert InvalidViewSanctionReview();
        }
        r.schemaVersion = 1;
        r.profile = 3;
        r.contentRoot = bytes32(_word(raw, base + 64));
        r.mediaContentHashes = new bytes32[](media);
        r.referenceRenderContentHashes = new bytes32[](refs);
        for (uint256 i; i < media; ++i) {
            bytes32 h = bytes32(_word(raw, base + 192 + i * 32));
            if (h == 0) revert InvalidViewSanctionReview();
            r.mediaContentHashes[i] = h;
        }
        for (uint256 i; i < refs; ++i) {
            bytes32 h = bytes32(_word(raw, referencesAt + 32 + i * 32));
            if (h == 0) revert InvalidViewSanctionReview();
            r.referenceRenderContentHashes[i] = h;
        }
    }

    function _word(bytes memory raw, uint256 offset) private pure returns (uint256 value) {
        assembly ("memory-safe") { value := mload(add(add(raw, 32), offset)) }
    }
}
