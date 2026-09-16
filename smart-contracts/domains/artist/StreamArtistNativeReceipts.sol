// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistHistoryTypes as H
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Typed receipts of actual record creation in the original fixed semantic owner.
/// @dev No authorization, owner root, or original record hash is replaced by this journal.
library StreamArtistNativeReceipts {
    bytes32 private constant SLOT = keccak256("6529STREAM_ARTIST_NATIVE_RECORD_RECEIPTS_V1");

    struct State {
        H.Receipt[] rows;
    }

    function _state() private pure returns (State storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function record(uint16 operation, bytes32 hash, bytes32 artistId, uint256 collectionId) public {
        if (hash == 0) return;
        if (operation == 0 || (operation > 59 && operation != 61) || (artistId == 0 && collectionId == 0)) {
            revert T.InvalidRecord();
        }
        _state().rows.push(H.Receipt(operation, artistId, collectionId, hash));
    }

    function count() public view returns (uint256) {
        return _state().rows.length;
    }

    function at(uint256 index) public view returns (H.Receipt memory) {
        return _state().rows[index];
    }
}
