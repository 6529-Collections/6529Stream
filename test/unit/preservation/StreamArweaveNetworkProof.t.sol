// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/preservation/StreamArweaveInclusion.sol";
import {
    StreamArchivalTypes as NetworkArch
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArchivalTypes.sol";

interface ArweaveNetworkVm {
    function readFile(string calldata path) external view returns (string memory);
    function parseJsonBytes(string calldata json, string calldata key)
        external
        pure
        returns (bytes memory);
    function parseJsonUint(string calldata json, string calldata key)
        external
        pure
        returns (uint256);
    function expectRevert(bytes4 error) external;
    function assume(bool condition) external;
}

contract ArweaveNetworkInclusionHarness {
    function verify(
        NetworkArch.Checkpoint calldata c,
        bytes calldata txPath,
        bytes calldata dataPath,
        bytes calldata payload
    ) external pure returns (bytes32) {
        return StreamArweaveInclusion.verify(c, txPath, dataPath, payload);
    }
}

/// @notice Native proof from historical Arweave-mainnet block 899979, retrieved through the public API.
/// @dev Tests inclusion only. A gateway response is not an independent quorum or a consensus proof.
contract StreamArweaveNetworkProofTest {
    ArweaveNetworkVm private constant vm =
        ArweaveNetworkVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    ArweaveNetworkInclusionHarness private verifier;

    function setUp() public {
        verifier = new ArweaveNetworkInclusionHarness();
    }

    function testRealMainnetPayloadAndPaddedTransactionRange() public view {
        (
            NetworkArch.Checkpoint memory c,
            bytes memory txPath,
            bytes memory dataPath,
            bytes memory payload
        ) = _vector();
        require(
            c.blockHeight == 899979 && c.transactionStart == 4680056832
                && c.transactionEnd == 4680056836,
            "actual padded range"
        );
        require(keccak256(payload) == keccak256(bytes("test")), "public four-byte payload");
        bytes32 digest = verifier.verify(c, txPath, dataPath, payload);
        require(
            digest == 0x9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08,
            "independent expected SHA256"
        );
    }

    function testRealMainnetProofRejectsShiftedRange() public {
        (
            NetworkArch.Checkpoint memory c,
            bytes memory txPath,
            bytes memory dataPath,
            bytes memory payload
        ) = _vector();
        --c.transactionStart;
        --c.transactionEnd;
        vm.expectRevert(NetworkArch.InvalidNativeInclusion.selector);
        verifier.verify(c, txPath, dataPath, payload);
    }

    function testRealMainnetProofRejectsAnotherTransactionRoot() public {
        (
            NetworkArch.Checkpoint memory c,
            bytes memory txPath,
            bytes memory dataPath,
            bytes memory payload
        ) = _vector();
        c.transactionRoot ^= bytes32(uint256(1));
        vm.expectRevert(NetworkArch.InvalidNativeInclusion.selector);
        verifier.verify(c, txPath, dataPath, payload);
    }

    function testFuzzRealMainnetProofRejectsChangedPayload(bytes4 replacement) public {
        vm.assume(replacement != bytes4("test"));
        (NetworkArch.Checkpoint memory c, bytes memory txPath, bytes memory dataPath,) = _vector();
        vm.expectRevert(NetworkArch.InvalidNativeInclusion.selector);
        verifier.verify(c, txPath, dataPath, abi.encodePacked(replacement));
    }

    function _vector()
        private
        view
        returns (
            NetworkArch.Checkpoint memory c,
            bytes memory txPath,
            bytes memory dataPath,
            bytes memory payload
        )
    {
        string memory fixture = vm.readFile(
            "test/fixtures/preservation/arweave-mainnet-899979.json"
        );
        c.networkId = keccak256("ARWEAVE_MAINNET");
        c.blockHash = vm.parseJsonBytes(fixture, ".blockHash");
        c.blockHeight = uint64(vm.parseJsonUint(fixture, ".blockHeight"));
        c.transactionRoot = bytes32(vm.parseJsonBytes(fixture, ".transactionRoot"));
        c.blockDataSize = vm.parseJsonUint(fixture, ".blockDataSize");
        c.transactionId = bytes32(vm.parseJsonBytes(fixture, ".transactionId"));
        c.dataRoot = bytes32(vm.parseJsonBytes(fixture, ".dataRoot"));
        c.dataSize = uint64(vm.parseJsonUint(fixture, ".dataSize"));
        c.transactionStart = vm.parseJsonUint(fixture, ".transactionStart");
        c.transactionEnd = vm.parseJsonUint(fixture, ".transactionEnd");
        txPath = vm.parseJsonBytes(fixture, ".transactionPath");
        dataPath = vm.parseJsonBytes(fixture, ".dataPath");
        payload = vm.parseJsonBytes(fixture, ".payload");
    }
}
