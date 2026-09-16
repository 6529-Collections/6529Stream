// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Producer-owned complete guard-key inventories. These reads alone install no authority.
interface IStreamArtistAuthorityCheckpoint {
    struct Checkpoint {
        bytes32 schema;
        T.Snapshot ownerState;
        bytes32 replayRoot;
        uint256 replayCount;
        bytes32 nonceRoot;
        uint256 nonceIndexCount;
    }

    struct NonceIndex {
        uint8 kind;
        bytes32 key;
        uint256 prefixCount;
    }
    function authorityCheckpoint() external view returns (Checkpoint memory);
    function authorityReplayAt(uint256 index)
        external
        view
        returns (bytes32 key, T.ReplayCell memory cell);
    function authorityNonceIndexAt(uint256 index) external view returns (NonceIndex memory);
    /// @notice Level zero is the complete leaf word; higher entries are its actual 256-way ancestors.
    /// @dev Index kinds: 1 identity, 2 delegate lane, 3 collaborator account,
    /// 4 rotation acceptance lane, 5 estate acceptance lane. No raw storage pointer is accepted.
    function authorityNonceWordAt(uint8 kind, bytes32 key, uint256 index)
        external
        view
        returns (uint256 prefix, uint256[32] memory words, bool exhausted);
}
