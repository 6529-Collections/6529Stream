// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../revenue/StreamSettlementAdmission.sol";
import "./StreamSaleArtist.sol";

/// @notice Original Universal lifecycle and Artist admission checks linked for code size.
/// @dev Delegatecalls retain the sale and payment caller context. No storage or authority is added.
library StreamUniversalSaleExecution {
    function capture(address registry, address saleAdapter, address paymentAdapter)
        public
        view
        returns (StreamPrimarySettlementTypes.SaleLifecycleBinding memory)
    {
        return StreamSettlementAdmission.capture(registry, saleAdapter, paymentAdapter);
    }

    function requireAdmission(
        address registry,
        address paymentAdapter,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory candidate
    ) public view {
        StreamSettlementAdmission.requireAdmission(registry, paymentAdapter, candidate);
    }

    function requireArtist(
        IStreamArtistAttribution registry,
        bytes32 admittedCodeHash,
        uint256 collectionId,
        address suppliedArtist
    ) public view {
        StreamSaleArtist.requireArtist(registry, admittedCodeHash, collectionId, suppliedArtist);
    }
}
