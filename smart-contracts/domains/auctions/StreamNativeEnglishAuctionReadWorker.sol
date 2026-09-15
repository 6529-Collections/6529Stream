// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativeEnglishAuctionRuntime.sol";
import "./StreamNativeEnglishAuctionCustodyState.sol";
import "./StreamTokenProfileCustodyState.sol";
import "./StreamCustodyRightsState.sol";
import "../../interfaces/stream/mint/StreamPreparedNativeContentTypes.sol";
import "../../interfaces/stream/revenue/StreamPreparedNativeRightsTypes.sol";

/// @notice Fixed read-only tuple encoding in the actual house storage context.
/// @dev Original getter predicates and return bytes are retained; no dependency/current gates added.
library StreamNativeEnglishAuctionReadWorker {
    function read(
        StreamNativeEnglishAuctionState.State storage _state,
        StreamNativeEnglishAuctionRuntime.Active storage _active,
        StreamNativeEnglishAuctionCustodyState.State storage _custody,
        mapping(bytes32 => StreamPreparedNativeContentTypes.Selection) storage _curated,
        mapping(bytes32 => StreamPreparedNativeRightsTypes.OriginalPolicy) storage _rights,
        StreamTokenProfileCustodyState.State storage _tokenProfileCustody,
        StreamCustodyRightsState.State storage _custodyRights,
        uint8 kind,
        bytes32 key
    ) public view returns (bytes memory encoded) {
        if (kind == 1) {
            return abi.encode(StreamNativeEnglishAuctionState.requireAuction(_state, key));
        }
        if (kind == 2) {
            if (
                key == 0 || key != _active.intentHash || _active.auction == 0
                    || _state.auctions[_active.auction].status != 2
            ) revert IStreamNativeEnglishAuction.InvalidNativeAuction();
            return abi.encode(_active.intent);
        }
        if (kind == 3) {
            if (_state.auctions[_active.auction].config.contentManifestRoot == 0) {
                revert IStreamNativeEnglishAuction.InvalidNativeAuction();
            }
            if (
                key == 0 || key != _active.intentHash || _active.auction == 0
                    || _state.auctions[_active.auction].status != 2
            ) revert IStreamNativeEnglishAuction.InvalidNativeAuction();
            return abi.encode(_active.intent);
        }
        if (kind == 4) {
            if (
                key == 0 || _active.intentHash != key || _active.auction == 0
                    || _rights[_active.auction].mode == 0
            ) revert IStreamNativeEnglishAuction.InvalidNativeAuction();
            return abi.encode(
                StreamPreparedNativeRightsTypes.Intent(_active.intent, _rights[_active.auction])
            );
        }
        if (kind == 5) {
            return abi.encode(_custody.origins[key]);
        }
        if (kind == 6) {
            IStreamNativeEnglishAuction.Auction storage a =
                StreamNativeEnglishAuctionState.requireAuction(_state, key);
            if (
                a.status != 2 || a.config.mintAtSettlement || _custody.acquiring != 0
                    || !_custody.origins[key].eligible || a.winner.amount == 0
            ) revert IStreamNativeCustodyAuction.InvalidNativeCustody();
            return
                abi.encode(StreamNativeCustodySettlementTypes.Facts(key, a, _custody.origins[key]));
        }
        if (kind == 7) {
            return abi.encode(_tokenProfileCustody.activations[key]);
        }
        if (kind == 8) {
            return abi.encode(_custodyRights.activations[key]);
        }
        if (kind == 9) {
            return abi.encode(_curated[key]);
        }
        if (kind == 10) {
            IStreamNativeEnglishAuction.Auction storage a =
                StreamNativeEnglishAuctionState.requireAuction(_state, key);
            (uint64 end,,,) = StreamNativeEnglishAuctionState.deadlines(_state, key);
            return abi.encode(
                a.config.minIncrementBps,
                a.config.incrementFloorWaived,
                a.config.clock.hardClose,
                a.config.clock.antiSnipeWindow,
                a.config.clock.antiSnipeExtension,
                a.config.clock.maxTotalExtension,
                uint32(a.clock.nominalEnd - a.clock.originalEnd),
                end
            );
        }
        revert IStreamNativeEnglishAuction.InvalidNativeAuction();
    }
}
