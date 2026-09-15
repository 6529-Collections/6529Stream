// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/PrivateSaleTestBase.sol";
import {
    IStreamPrivateSaleDelegatedClaims as Claims
} from "../../../smart-contracts/interfaces/stream/mint/IStreamPrivateSaleDelegatedClaims.sol";

/// @dev Explicit old optional-zero deployment and typed Core/governance boundary.
contract StreamPrivateSaleDelegationZeroModeTest is PrivateSaleTestBase {
    function testOptionalZeroRetainsOriginalPaymentsAndClaimsWithoutNewCapability() external {
        require(
            sale.delegateRegistry() == address(0) && sale.delegateRegistryCodeHash() == 0
                && sale.delegationUsecase() == 0
                && !sale.supportsInterface(type(Claims).interfaceId)
        );
        bytes32 id = sale.registerSale(_config(5, 1, buyer, 0));
        _deposit(id);
        _purchase(id, 1017);
        require(core.ownerOf(1) == buyer && sale.refundableBalance(id, buyer) == 17);
        vm.expectRevert();
        sale.claimRefundFor(id, buyer, Claims.DelegationWitness(false, 0));
        uint256 beforeBalance = buyer.balance;
        vm.prank(buyer);
        sale.claimRefund(id, buyer);
        require(buyer.balance == beforeBalance + 17 && sale.refundableBalance(id, buyer) == 0);
    }
}
