// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistPlatformState.sol";
import "./StreamArtistAttributionClaimState.sol";

/// @notice Original Attribution commit preimages encoded in the fixed owner context.
library StreamArtistAttributionCommitEncoding {
    function platformState(StreamArtistPlatformState.Store storage s, uint256 id)
        public
        view
        returns (bytes32)
    {
        return keccak256(abi.encode(id, s.collections[id]));
    }

    function claimState(StreamArtistAttributionClaimState.Store storage s, bytes32 record)
        public
        view
        returns (bytes32)
    {
        return keccak256(abi.encode(s.records[record]));
    }
}
