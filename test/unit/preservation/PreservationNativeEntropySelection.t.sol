// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./PreservationNativeFixture.sol";
import {
    StreamEntropyStatus
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyView.sol";

/// @notice The publication fixture selects each real coordinator before admitting its scope.
contract PreservationNativeEntropySelectionTest is PreservationNativeFixture {
    function setUp() public override {
        vm.warp(1000);
        core = new RootCoreBoundary();
    }

    function testNativeFixtureSelectsBothOriginalCoordinators() public {
        StreamEntropyCoordinator firstCoordinator = _native();
        _requireSelected(firstCoordinator);
        bytes32 firstScope = _scopeId(firstCoordinator, keccak256("scope"));
        _requireRegistered(firstCoordinator, firstScope);

        StreamEntropyCoordinator secondCoordinator = _native();
        require(address(firstCoordinator) != address(secondCoordinator));
        _requireSelected(secondCoordinator);
        _requireRegistered(secondCoordinator, _scopeId(secondCoordinator, keccak256("scope")));
        // Selecting the second coordinator does not replace the first coordinator's original scope.
        _requireRegistered(firstCoordinator, firstScope);
    }

    function testMissingCoordinatorSelectionRefusesThenSelectedRetrySucceeds() public {
        StreamEntropyCoordinator coordinator = _native();
        bytes32 scopeRef = keccak256("new scope after missing selection");
        bytes32 expected = _scopeId(coordinator, scopeRef);
        core.setPointer(keccak256("ENTROPY_COORDINATOR"), address(0));
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.InvalidCollection.selector, 1)
        );
        coordinator.registerEntropyScope(1, 1, scopeRef);
        require(coordinator.scopeEntropy(expected).status == StreamEntropyStatus.NONE);

        core.setPointer(keccak256("ENTROPY_COORDINATOR"), address(coordinator));
        _requireSelected(coordinator);
        require(coordinator.registerEntropyScope(1, 1, scopeRef) == expected);
        _requireRegistered(coordinator, expected);
    }

    function _requireSelected(StreamEntropyCoordinator coordinator) private view {
        StreamCorePointerState memory selected =
            core.getSatellitePointer(keccak256("ENTROPY_COORDINATOR"));
        require(selected.target == address(coordinator));
        require(selected.codeHash == address(coordinator).codehash);
    }

    function _requireRegistered(StreamEntropyCoordinator coordinator, bytes32 scope) private view {
        StreamEntropyCoordinator.Subject memory subject = coordinator.scopeEntropy(scope);
        require(subject.collectionId == 1 && subject.status == StreamEntropyStatus.REGISTERED);
    }

    function _scopeId(StreamEntropyCoordinator coordinator, bytes32 scopeRef)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_SCOPE_SUBJECT_V1"),
                block.chainid,
                address(coordinator),
                address(core),
                uint256(1),
                uint8(1),
                scopeRef
            )
        );
    }
}
