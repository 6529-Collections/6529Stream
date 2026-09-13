// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/artist/StreamArtistRecoveryTypes.sol";
import "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Exact original scopes and completed tokens inheriting their collection's finality.
/// @dev Fresh admission checks token identity. Saved consent preserves the admitted relation;
///      the companion independently checks current route validity before a new execution.
library StreamArtistRecoveryApprovalScopes {
    error RecoveryApprovalScopeReadFailed(address core, bytes4 selector);
    error RecoveryApprovalScopeParentGas(uint256 available, uint256 required);

    /// @notice Recognizes immutable recorded scope relations; it does not establish fresh membership.
    function supportedAdmission(
        StreamFinalityScope memory original,
        StreamFinalityScope memory requested
    ) internal pure returns (bool) {
        return supported(original, requested) || _familyShape(original, requested);
    }

    /// @notice Exact/TOKEN admission retains its reads. New family identity is checked by the
    ///         authenticated companion's subsequent exact Request preparation in approvalIntent.
    function requireFreshAdmission(
        address core,
        StreamFinalityScope memory original,
        StreamFinalityScope memory requested,
        uint256 cap
    ) public view {
        if (_familyShape(original, requested)) return;
        requireFresh(core, original, requested, cap);
    }

    function _familyShape(StreamFinalityScope memory original, StreamFinalityScope memory requested)
        private
        pure
        returns (bool)
    {
        return original.scopeType == StreamFinalityScopeType.COLLECTION
            && original.collectionId != 0 && original.tokenId == 0 && original.scopeId == 0
            && requested.scopeType >= StreamFinalityScopeType.RELEASE
            && requested.scopeType <= StreamFinalityScopeType.VIEW
            && requested.collectionId == original.collectionId && requested.tokenId == 0
            && requested.scopeId != 0;
    }

    function supported(StreamFinalityScope memory original, StreamFinalityScope memory requested)
        internal
        pure
        returns (bool)
    {
        if (keccak256(abi.encode(original)) == keccak256(abi.encode(requested))) return true;
        return original.scopeType == StreamFinalityScopeType.COLLECTION
            && original.collectionId != 0 && original.tokenId == 0 && original.scopeId == 0
            && requested.scopeType == StreamFinalityScopeType.TOKEN
            && requested.collectionId == original.collectionId && requested.tokenId != 0
            && requested.scopeId == 0;
    }

    function requireFresh(
        address core,
        StreamFinalityScope memory original,
        StreamFinalityScope memory requested,
        uint256 cap
    ) public view {
        if (!supported(original, requested)) {
            revert StreamArtistRecoveryTypes.InvalidRecoveryApproval();
        }
        if (original.scopeType == requested.scopeType) return;
        (uint256 mapped, uint256 collectionId, uint256 serial, uint256 burned) = abi.decode(
            _read(
                core,
                abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (requested.tokenId)),
                128,
                cap
            ),
            (uint256, uint256, uint256, uint256)
        );
        uint256 lifecycle = abi.decode(
            _read(
                core,
                abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (requested.tokenId)),
                32,
                cap
            ),
            (uint256)
        );
        if (
            mapped != 1 || collectionId != requested.collectionId || serial == 0 || burned > 1
                || (lifecycle != 2 && lifecycle != 3) || (burned == 1) != (lifecycle == 3)
        ) revert StreamArtistRecoveryTypes.InvalidRecoveryApproval();
    }

    function _read(address core, bytes memory input, uint256 size, uint256 cap)
        private
        view
        returns (bytes memory raw)
    {
        if (cap == 0 || cap > type(uint256).max / 64) {
            revert StreamArtistRecoveryTypes.InvalidRecoveryApproval();
        }
        raw = new bytes(size);
        uint256 required = cap + cap / 63 + 100000;
        if (gasleft() <= required) {
            revert RecoveryApprovalScopeParentGas(gasleft(), required);
        }
        bool ok;
        uint256 actual;
        assembly ("memory-safe") {
            ok := staticcall(cap, core, add(input, 32), mload(input), add(raw, 32), size)
            actual := returndatasize()
        }
        if (!ok || actual != size) revert RecoveryApprovalScopeReadFailed(core, bytes4(input));
    }
}
