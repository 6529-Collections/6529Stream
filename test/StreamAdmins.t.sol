// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/StreamAdmins.sol";
import "./helpers/Assertions.sol";

contract StreamAdminsTest {
    using Assertions for address;
    using Assertions for bool;

    function testConstructorSetsSignerAsGlobalAdmin() public {
        StreamAdmins admins = new StreamAdmins(address(this));

        address(admins.tdhSigner()).assertEq(address(this), "tdh signer mismatch");
        admins.retrieveGlobalAdmin(address(this)).assertTrue("signer is not global admin");
    }

    function testOnlyTdhSignerCanRegisterGlobalAdmin() public {
        StreamAdmins admins = new StreamAdmins(address(0xBEEF));

        (bool success,) = address(admins)
            .call(abi.encodeWithSelector(admins.registerAdmin.selector, address(0xCAFE), true));

        success.assertFalse("non-signer registered global admin");
        admins.retrieveGlobalAdmin(address(0xCAFE)).assertFalse("admin was changed");
    }

    function testTdhSignerCanRegisterGlobalAdmin() public {
        StreamAdmins admins = new StreamAdmins(address(this));

        admins.registerAdmin(address(0xCAFE), true);

        admins.retrieveGlobalAdmin(address(0xCAFE)).assertTrue("global admin not set");
    }

    function testTdhSignerCanRegisterFunctionAdmin() public {
        StreamAdmins admins = new StreamAdmins(address(this));
        bytes4 selector =
            bytes4(keccak256("mintDrop(address,string,uint256,uint256,uint256,uint256)"));

        admins.registerFunctionAdmin(address(0xCAFE), selector, true);

        admins.retrieveFunctionAdmin(address(0xCAFE), selector).assertTrue("function admin not set");
    }
}
