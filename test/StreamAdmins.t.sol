// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/StreamAdmins.sol";
import "./helpers/Assertions.sol";
import "./helpers/CharacterizationTestBase.sol";

contract StreamAdminsTest is CharacterizationTestBase {
    using Assertions for address;
    using Assertions for bool;

    event GlobalAdminUpdated(address indexed account, bool enabled, address indexed admin);
    event FunctionAdminUpdated(
        address indexed account,
        address indexed target,
        bytes4 indexed selector,
        bool enabled,
        address admin
    );

    function testConstructorSetsSignerAsGlobalAdmin() public {
        StreamAdmins admins = new StreamAdmins(address(this));

        address(admins.tdhSigner()).assertEq(address(this), "tdh signer mismatch");
        admins.retrieveGlobalAdmin(address(this)).assertTrue("signer is not global admin");
    }

    function testZeroTdhSignerConstructorFails() public {
        vm.expectRevert("Zero tdh signer");
        new StreamAdmins(address(0));
    }

    function testOnlyRegistrarCanRegisterGlobalAdmin() public {
        StreamAdmins admins = new StreamAdmins(address(0xBEEF));

        vm.prank(address(0xBAD));
        (bool success,) = address(admins)
            .call(abi.encodeWithSelector(admins.registerAdmin.selector, address(0xCAFE), true));

        success.assertFalse("non-registrar registered global admin");
        admins.retrieveGlobalAdmin(address(0xCAFE)).assertFalse("admin was changed");
    }

    function testOwnerCanRegisterGlobalAdminAsRootRecoveryPath() public {
        StreamAdmins admins = new StreamAdmins(address(0xBEEF));

        vm.expectEmit(true, false, true, true);
        emit GlobalAdminUpdated(address(0xCAFE), true, address(this));
        admins.registerAdmin(address(0xCAFE), true);

        admins.retrieveGlobalAdmin(address(0xCAFE))
            .assertTrue("owner did not register global admin");
    }

    function testTdhSignerCanRegisterGlobalAdmin() public {
        StreamAdmins admins = new StreamAdmins(address(this));

        vm.expectEmit(true, false, true, true);
        emit GlobalAdminUpdated(address(0xCAFE), true, address(this));
        admins.registerAdmin(address(0xCAFE), true);

        admins.retrieveGlobalAdmin(address(0xCAFE)).assertTrue("global admin not set");
    }

    function testTdhSignerCanRegisterFunctionAdmin() public {
        StreamAdmins admins = new StreamAdmins(address(this));
        address target = address(0xF00D);
        bytes4 selector = StreamAdmins.registerAdmin.selector;

        vm.expectEmit(true, true, true, true);
        emit FunctionAdminUpdated(address(0xCAFE), target, selector, true, address(this));
        admins.registerFunctionAdmin(address(0xCAFE), target, selector, true);

        admins.retrieveFunctionAdmin(address(0xCAFE), target, selector)
            .assertTrue("function admin not set");
    }

    function testTdhSignerCanRevokeFunctionAdmin() public {
        StreamAdmins admins = new StreamAdmins(address(this));
        address functionAdmin = address(0xCAFE);
        address target = address(0xF00D);
        bytes4 selector = StreamAdmins.registerAdmin.selector;

        admins.registerFunctionAdmin(functionAdmin, target, selector, true);

        vm.expectEmit(true, true, true, true);
        emit FunctionAdminUpdated(functionAdmin, target, selector, false, address(this));
        admins.registerFunctionAdmin(functionAdmin, target, selector, false);

        admins.retrieveFunctionAdmin(functionAdmin, target, selector)
            .assertFalse("function admin not revoked");
    }

    function testTdhSignerCanBatchRegisterFunctionAdmins() public {
        StreamAdmins admins = new StreamAdmins(address(this));
        address functionAdmin = address(0xCAFE);
        address target = address(0xF00D);
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = StreamAdmins.registerAdmin.selector;
        selectors[1] = StreamAdmins.registerFunctionAdmin.selector;

        admins.registerBatchFunctionAdmin(functionAdmin, target, selectors, true);

        admins.retrieveFunctionAdmin(functionAdmin, target, selectors[0])
            .assertTrue("first selector not set");
        admins.retrieveFunctionAdmin(functionAdmin, target, selectors[1])
            .assertTrue("second selector not set");
        admins.retrieveFunctionAdmin(functionAdmin, address(0xABCD), selectors[0])
            .assertFalse("batch grant leaked to another target");
    }

    function testZeroAddressRoleAssignmentsFail() public {
        StreamAdmins admins = new StreamAdmins(address(this));

        (bool zeroGlobalSuccess,) = address(admins)
            .call(abi.encodeWithSelector(admins.registerAdmin.selector, address(0), true));
        zeroGlobalSuccess.assertFalse("zero global admin was registered");

        (bool zeroFunctionAdminSuccess,) = address(admins)
            .call(
                abi.encodeWithSelector(
                    admins.registerFunctionAdmin.selector,
                    address(0),
                    address(0xF00D),
                    StreamAdmins.registerAdmin.selector,
                    true
                )
            );
        zeroFunctionAdminSuccess.assertFalse("zero function admin was registered");

        (bool zeroTargetSuccess,) = address(admins)
            .call(
                abi.encodeWithSelector(
                    admins.registerFunctionAdmin.selector,
                    address(0xCAFE),
                    address(0),
                    StreamAdmins.registerAdmin.selector,
                    true
                )
            );
        zeroTargetSuccess.assertFalse("zero target was registered");

        (bool zeroSelectorSuccess,) = address(admins)
            .call(
                abi.encodeWithSelector(
                    admins.registerFunctionAdmin.selector,
                    address(0xCAFE),
                    address(0xF00D),
                    bytes4(0),
                    true
                )
            );
        zeroSelectorSuccess.assertFalse("zero selector was registered");
    }

    function testCollectionAdminSupportIsExplicitlyDeferred() public {
        StreamAdmins admins = new StreamAdmins(address(this));

        admins.retrieveCollectionAdmin(address(0xCAFE), 1)
            .assertFalse("collection admin unexpectedly set");
    }
}
