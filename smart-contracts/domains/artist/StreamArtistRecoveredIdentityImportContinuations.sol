// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationState as X
} from "./StreamArtistRecoveredIdentityHydrationState.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";

/// @notice Fixed continuations phase of the original recovered Identity import.
/// @dev The fixed importer passes the complete canonical Bundle after SourceCodec validation.
/// Linked library calls retain the host's 17 declared roots and storage context.
library StreamArtistRecoveredIdentityImportContinuations {
    function install(uint256[17] memory roots, bytes calldata canonical) public {
        IH.Bundle calldata b = Frame.bundle(canonical);
        _continuations(roots, b);
    }

    function _continuations(uint256[17] memory r, IH.Bundle calldata b) private {
        for (uint256 i; i < b.originalContinuations.length; ++i) {
            IH.OriginalContinuationRow memory row = b.originalContinuations[i];
            IH.OriginalContinuationRow memory zero;
            bytes32 key = row.continuation.continuationHash;
            _empty(
                abi.encode(X.resolutions(r).continuations[key]), abi.encode(zero.continuation), key
            );
            X.resolutions(r).continuations[key] = row.continuation;
        }
        for (uint256 i; i < b.revisionContinuations.length; ++i) {
            IH.RevisionContinuationRow memory row = b.revisionContinuations[i];
            IH.RevisionContinuationRow memory zero;
            bytes32 key = row.continuation.continuationHash;
            _empty(
                abi.encode(X.rewinds(r).revisionContinuations[key]),
                abi.encode(zero.continuation),
                key
            );
            X.rewinds(r).revisionContinuations[key] = row.continuation;
        }
        for (uint256 i; i < b.standingContinuations.length; ++i) {
            IH.StandingContinuationRow memory row = b.standingContinuations[i];
            IH.StandingContinuationRow memory zero;
            bytes32 key = row.continuation.continuationHash;
            _empty(
                abi.encode(X.rewinds(r).standingContinuations[key]),
                abi.encode(zero.continuation),
                key
            );
            bytes32 scope = keccak256(
                abi.encode(
                    b.artistId, row.continuation.priorAddress, row.continuation.retirementHash
                )
            );
            bytes32 old = X.rewinds(r).standingHeads[scope];
            if (old != 0 && old != row.scopeHead) revert IH.InvalidRecoveredIdentity(scope);
            X.rewinds(r).standingContinuations[key] = row.continuation;
            X.rewinds(r).standingHeads[scope] = row.scopeHead;
        }
        for (uint256 i; i < b.capabilityContinuations.length; ++i) {
            IH.CapabilityContinuationRow memory row = b.capabilityContinuations[i];
            IH.CapabilityContinuationRow memory zero;
            bytes32 key = row.continuation.recoveryRecordHash;
            _empty(
                abi.encode(X.rewinds(r).capabilityContinuations[key]),
                abi.encode(zero.continuation),
                key
            );
            X.rewinds(r).capabilityContinuations[key] = row.continuation;
        }
    }

    function _empty(bytes memory old, bytes memory zero, bytes32 key) private pure {
        if (keccak256(old) != keccak256(zero)) revert IH.InvalidRecoveredIdentity(key);
    }
}
