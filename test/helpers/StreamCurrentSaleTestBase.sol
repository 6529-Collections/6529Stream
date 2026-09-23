// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentStackFixture.sol";

interface SaleCallbackFaultVm {
    function mockCallRevert(address callee, bytes calldata data, bytes calldata revertData) external;
    function clearMockedCalls() external;
}

/// @notice Sale behavior tests share the actual current deployment and artist consent setup.
/// @dev The callback-failure cases explicitly inject one entropy CALL failure; positive paths
///      use the real coordinator. No authority, policy, payment or mint response is mocked.
abstract contract StreamCurrentSaleTestBase is StreamCurrentStackFixture {
    address internal platform;
    address internal constant protocol = PROTOCOL;
    bytes internal tokenData = bytes("ipfs://artist-token");

    function _setUpSaleFixture() internal {
        vm.deal(address(this), 100 ether);
        platform = vm.addr(PLATFORM_KEY);
        _deployCurrentStack(vm.addr(ARTIST_KEY), platform);
    }

    function _executeSaleGovernance(address target, bytes memory data) internal {
        bytes4 selector;
        assembly ("memory-safe") { selector := mload(add(data, 32)) }
        GovernanceActionRequest memory request = GovernanceActionRequest({
            actionClass: 1,
            target: target,
            value: 0,
            selector: selector,
            callData: data,
            scopeHash: keccak256(abi.encode(target, selector)),
            oldValueHash: bytes32(0),
            newValueHash: keccak256(data),
            notBefore: uint64(block.timestamp + 48 hours),
            expiresAfter: uint64(block.timestamp + 9 days),
            reasonHash: keccak256("current sale unit configuration"),
            reasonURI: "urn:6529stream:test:current-sale-configuration",
            manifestHash: DEPLOYMENT_HASH
        });
        bytes memory result = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (request))
        );
        vm.warp(request.notBefore);
        executor.executeGovernanceAction(abi.decode(result, (bytes32)), data);
    }

    function _failEntropyRegistrationCallback() internal {
        SaleCallbackFaultVm(address(vm))
            .mockCallRevert(
                address(entropy),
                abi.encodeWithSelector(IStreamEntropyCoordinator.onTokenMinted.selector),
                abi.encodeWithSignature("InjectedEntropyCallbackFailure()")
            );
    }

    function _restoreEntropyRegistrationCallback() internal {
        SaleCallbackFaultVm(address(vm)).clearMockedCalls();
    }
}
