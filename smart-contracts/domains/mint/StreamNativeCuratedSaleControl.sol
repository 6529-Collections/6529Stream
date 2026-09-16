// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamNativeCuratedSaleState } from "./StreamNativeCuratedSaleState.sol";
import { StreamNativeCuratedSaleSupport } from "./StreamNativeCuratedSaleSupport.sol";
import { StreamNativeCuratedClock } from "./StreamNativeCuratedClock.sol";
import { StreamRefundWindowSupport } from "./StreamRefundWindowSupport.sol";

interface ICuratedControlLiabilities {
    function totalBuyerLiabilities() external view returns (uint256);
}

/// @notice Fixed linked controls and earned-credit effects under the host's original shared guard.
/// @dev The host authenticates own/delegated credit callers and passes only immutable role bindings.
library StreamNativeCuratedSaleControl {
    struct Roles {
        address registry;
        bytes32 registryHash;
        address authority;
    }
    error CuratedSaleUnavailable(bytes32 saleId);
    error CuratedPurchaseInvalid();
    error CuratedAccountingMismatch();
    error CuratedCreditEmpty();
    error CuratedCreditTransferFailed();
    event CuratedCreditClaimed(
        bytes32 indexed saleId, address indexed buyer, address indexed recipient, uint256 amount
    );
    event AdapterPaused(uint16 schemaVersion, address indexed guardian, bytes32 reasonHash);
    event AdapterUnpaused(uint16 schemaVersion, address indexed unpauser, bytes32 reasonHash);
    event SalePaused(
        uint16 schemaVersion, bytes32 indexed saleId, address indexed guardian, bytes32 reasonHash
    );
    event SaleUnpaused(
        uint16 schemaVersion, bytes32 indexed saleId, address indexed unpauser, bytes32 reasonHash
    );
    event CollectionSaleStopSynced(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        address indexed actor,
        uint8 observedContestState,
        bool stopped
    );

    function claimCredit(
        StreamNativeCuratedSaleState.State storage state,
        bytes32 id,
        address buyer,
        address recipient
    ) public returns (uint256 amount) {
        if (recipient == address(0) || recipient == address(this)) {
            revert CuratedCreditTransferFailed();
        }
        amount = state.credits[id][buyer];
        if (amount == 0) revert CuratedCreditEmpty();
        delete state.credits[id][buyer];
        state.refundLiability -= amount;
        bool ok;
        assembly ("memory-safe") { ok := call(gas(), recipient, amount, 0, 0, 0, 0) }
        if (!ok) revert CuratedCreditTransferFailed();
        if (
            address(this).balance
                < ICuratedControlLiabilities(address(this)).totalBuyerLiabilities()
        ) revert CuratedAccountingMismatch();
        emit CuratedCreditClaimed(id, buyer, recipient, amount);
    }

    function setGlobalPause(
        StreamNativeCuratedSaleState.State storage state,
        Roles memory roles,
        bool value,
        bytes32 reason
    ) public {
        if (reason == 0) revert CuratedPurchaseInvalid();
        _requireRole(roles, value);
        StreamNativeCuratedClock.setGlobal(state.clocks, value);
        if (value) emit AdapterPaused(1, msg.sender, reason);
        else emit AdapterUnpaused(1, msg.sender, reason);
    }

    function setSalePause(
        StreamNativeCuratedSaleState.State storage state,
        Roles memory roles,
        bytes32 id,
        bool value,
        bytes32 reason
    ) public {
        if (reason == 0) revert CuratedPurchaseInvalid();
        _requireRole(roles, value);
        if (state.sales[id].status == 0) revert CuratedSaleUnavailable(id);
        StreamNativeCuratedClock.setSale(
            state.clocks, id, state.sales[id].config.collectionId, value
        );
        if (value) emit SalePaused(1, id, msg.sender, reason);
        else emit SaleUnpaused(1, id, msg.sender, reason);
    }

    function syncCollectionContest(
        StreamNativeCuratedSaleState.State storage state,
        StreamNativeCuratedSaleSupport.Context memory context,
        uint256 collectionId
    ) public {
        uint8 contest = StreamNativeCuratedSaleSupport.contestState(context, collectionId);
        bool stopped = contest == 1 || contest == 3;
        StreamNativeCuratedClock.Point[] storage history = state.clocks.collections[collectionId];
        bool previous = history.length != 0 && history[history.length - 1].stopped;
        if (stopped != previous) {
            StreamNativeCuratedClock.setCollection(state.clocks, collectionId, stopped);
        }
        emit CollectionSaleStopSynced(1, collectionId, msg.sender, contest, stopped);
    }

    function _requireRole(Roles memory roles, bool paused) private view {
        StreamRefundWindowSupport.requireRole(
            roles.registry,
            roles.registryHash,
            roles.authority,
            paused ? keccak256("ROLE_PAUSE_GUARDIAN") : keccak256("ROLE_UNPAUSE")
        );
    }
}
