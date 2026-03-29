// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/contracts/StreamAdmins.sol";
import "./helpers/Vm.sol";

contract StreamAdminsTest {
    Vm internal constant vm = Vm(HEVM_ADDRESS);

    address internal constant TDH_SIGNER = address(0x1001);
    address internal constant OTHER = address(0x2002);
    address internal constant ADMIN = address(0x3003);

    function test_tdhSignerStartsAsGlobalAdmin() external {
        StreamAdmins admins = new StreamAdmins(TDH_SIGNER);
        require(admins.retrieveGlobalAdmin(TDH_SIGNER), "tdh signer should be admin");
    }

    function test_onlySignerCanRegisterAdmin() external {
        StreamAdmins admins = new StreamAdmins(TDH_SIGNER);

        vm.prank(OTHER);
        vm.expectRevert(bytes("Not Allowed"));
        admins.registerAdmin(ADMIN, true);
    }

    function test_signerCanRegisterAdmin() external {
        StreamAdmins admins = new StreamAdmins(TDH_SIGNER);

        vm.prank(TDH_SIGNER);
        admins.registerAdmin(ADMIN, true);

        require(admins.retrieveGlobalAdmin(ADMIN), "registered admin should be active");
    }
}

