// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeImmediateSalesState.sol";
import "./StreamNativeCuratedSaleSupport.sol";

/// @notice Fixed configuration and stop operations behind the adapter's owner and reentrancy guards.
library StreamNativeImmediateSalesAdministration {
    event ImmediateSaleSignerConfigured(
        uint256 indexed collectionId,
        address indexed authorizer,
        uint8 kind,
        IStreamNativeImmediateSales.SignerBinding binding,
        bool enabled
    );
    event ImmediateSaleClosed(bytes32 indexed saleId, uint64 soldQuantity);
    event ImmediateSaleContestSynced(
        uint256 indexed collectionId, uint8 contestState, bool stopped
    );

    function configureSigner(
        StreamNativeImmediateSalesState.State storage state,
        uint256 collection,
        address signer,
        uint8 kind,
        bytes32 evidence,
        bool enabled
    ) public {
        if (collection == 0 || signer == address(0) || (kind != 1 && kind != 2) || evidence == 0) {
            revert IStreamNativeImmediateSales.InvalidImmediateSale();
        }
        StreamNativeImmediateSalesState.Signer storage s = state.signers[collection][signer][kind];
        s.binding = IStreamNativeImmediateSales.SignerBinding(
            signer, kind, evidence, s.binding.revision + 1, msg.sender
        );
        s.enabled = enabled;
        emit ImmediateSaleSignerConfigured(collection, signer, kind, s.binding, enabled);
    }

    function close(StreamNativeImmediateSalesState.State storage state, bytes32 id) public {
        IStreamNativeImmediateSales.Record storage r = state.sales[id];
        if (r.saleNonce == 0 || r.closed) {
            revert IStreamNativeImmediateSales.ImmediateSaleUnavailable(id);
        }
        r.closed = true;
        emit ImmediateSaleClosed(id, r.soldQuantity);
    }

    function syncContest(
        StreamNativeImmediateSalesState.State storage state,
        StreamNativeCuratedSaleSupport.Context memory context,
        uint256 collection
    ) public {
        uint8 contest = StreamNativeCuratedSaleSupport.contestState(context, collection);
        bool stopped = contest == 1 || contest == 3;
        StreamNativeCuratedClock.Point[] storage history = state.clocks.collections[collection];
        bool prior = history.length != 0 && history[history.length - 1].stopped;
        if (prior != stopped) {
            StreamNativeCuratedClock.setCollection(state.clocks, collection, stopped);
        }
        emit ImmediateSaleContestSynced(collection, contest, stopped);
    }
}
