// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";

/// @notice Rebuildable display checkpoints; no authority, nonce or historical record mutation.
library StreamArtistStaticIdentityProjection {
    bytes32 private constant SLOT =
        keccak256("6529STREAM_ARTIST_STATIC_IDENTITY_PROJECTION_STORAGE_V1");
    bytes32 internal constant DOMAIN = keccak256("6529STREAM_ARTIST_STATIC_IDENTITY_MATURITY_V1");

    struct Context {
        bytes32 artistId;
        bytes32 candidate;
        bytes32 documentHash;
        bytes32 latestExecution;
        address authority;
        uint8 authorityClass;
        uint8 status;
        R.ProvisionalAssociation association;
        R.TransitionState transition;
    }

    struct Store {
        mapping(bytes32 => bool) checkpoints;
    }
    event ArtistStaticIdentityMaturityCheckpointed(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 indexed candidate,
        bytes32 indexed checkpoint,
        uint256 chainId,
        address registry,
        bytes context
    );

    function store() private pure returns (Store storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function key(address registry, Context memory c) internal view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN, block.chainid, address(this), registry, c));
    }

    function recorded(bytes32 checkpoint) internal view returns (bool) {
        return store().checkpoints[checkpoint];
    }

    /// @dev Fixed Identity validates the actual pending revision, live transition and time before entry.
    function record(address registry, Context memory c) public returns (bytes32 checkpoint) {
        checkpoint = key(registry, c);
        if (!store().checkpoints[checkpoint]) {
            store().checkpoints[checkpoint] = true;
            emit ArtistStaticIdentityMaturityCheckpointed(
                1, c.artistId, c.candidate, checkpoint, block.chainid, registry, abi.encode(c)
            );
        }
    }
}
