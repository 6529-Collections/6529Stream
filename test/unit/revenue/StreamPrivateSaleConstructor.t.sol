// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/PrivateSaleTestBase.sol";

contract StreamPrivateSaleConstructorTest is PrivateSaleTestBase {
    function testCanonicalRegistryExecutorRejectsSelfConsistentForeignGovernanceAndRoles()
        external
    {
        PrivateSaleAuthorityMock canonicalAuthority = authority;
        PrivateSaleRolesMock canonicalRoles = roles;
        authority = new PrivateSaleAuthorityMock();
        roles = new PrivateSaleRolesMock(address(authority));
        authority.setRoles(address(roles));
        require(roles.owner() == address(authority) && authority.roleRegistry() == address(roles));
        require(address(registry.governanceExecutor()) != address(authority));
        vm.expectRevert(abi.encodeWithSelector(IStreamPrivateSaleAdapter.InvalidPrivateSale.selector));
        _newSale(platform, address(this));

        authority = canonicalAuthority;
        roles = canonicalRoles;
        sale = _newSale(platform, address(this));
        require(sale.governanceAuthority() == address(registry.governanceExecutor()));
        require(sale.roleRegistry() == address(roles));
        _register();
        sale.configureCollectionSigner(1, keccak256("explicit collection signer authority"), true);
        vm.prank(consignor);
        core.setApprovalForAll(address(sale), true);
        bytes32 id = sale.registerSale(_config(5, 1, buyer, 0));
        _deposit(id);
        _purchase(id, 1000);
        require(core.ownerOf(1) == buyer && sale.refundableBalance(id, consignor) == 900);
    }
}
