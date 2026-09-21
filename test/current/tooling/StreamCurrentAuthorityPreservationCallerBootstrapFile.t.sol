// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { FoundryAccountStateExport as Export } from "../../helpers/FoundryAccountStateExport.sol";
import {
    StreamCurrentAuthorityPreservationCallerBootstrap as Bootstrap
} from "../../helpers/StreamCurrentAuthorityPreservationCallerBootstrap.sol";

interface BootstrapFileTestVm {
    function expectRevert(bytes calldata reason) external;
    function writeFileBinary(string calldata path, bytes calldata data) external;
    function readFileBinary(string calldata path) external view returns (bytes memory);
    function createDir(string calldata path, bool recursive) external;
    function removeFile(string calldata path) external;
}

/// @notice File invocation guards only; these cases do not prepare or admit a protocol graph.
contract StreamCurrentAuthorityPreservationCallerBootstrapFileTest {
    BootstrapFileTestVm private constant vm =
        BootstrapFileTestVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    Bootstrap private bootstrap;

    function setUp() public {
        bootstrap = new Bootstrap();
        vm.createDir("./artifacts/native-assembly/", true);
    }

    function testRejectsTraversalBeforeAttemptingFileRead() public {
        vm.expectRevert(abi.encodeWithSelector(Bootstrap.InvalidArtifactPrefix.selector));
        bootstrap.exportPreparationFile("./artifacts/native-assembly/../outside");
    }

    function testBinaryInputRetainsCanonicalEncodingCheck() public {
        string memory prefix = "./artifacts/native-assembly/bootstrap-file-noncanonical";
        string memory path = string.concat(prefix, ".admitted-prestate.abi");
        bytes memory canonical = abi.encode(new Export.Account[](0));
        vm.writeFileBinary(path, bytes.concat(canonical, hex"01"));
        vm.expectRevert(abi.encodeWithSelector(Bootstrap.InvalidPrestateEncoding.selector));
        bootstrap.exportPreparationFile(prefix);
        require(keccak256(vm.readFileBinary(path)) == keccak256(bytes.concat(canonical, hex"01")));
        vm.removeFile(path);
    }

    function testBinaryInputRetainsLiveAccountValidation() public {
        string memory prefix = "./artifacts/native-assembly/bootstrap-file-live-account";
        string memory path = string.concat(prefix, ".admitted-prestate.abi");
        Export.Account[] memory accounts = new Export.Account[](1);
        accounts[0].account = address(bootstrap);
        // A deployed Bootstrap cannot have the supplied empty code and zero code hash.
        bytes memory admitted = abi.encode(accounts);
        vm.writeFileBinary(path, admitted);
        bytes memory reason =
            abi.encodeWithSelector(Bootstrap.PrestateAccountMismatch.selector, address(bootstrap));
        vm.expectRevert(reason);
        bootstrap.exportPreparationFile(prefix);
        vm.expectRevert(reason);
        bootstrap.exportPreparation(admitted, prefix);
        require(keccak256(vm.readFileBinary(path)) == keccak256(admitted));
        vm.removeFile(path);
    }

    function testExistingOutputIsPreservedWithFileInput() public {
        string memory prefix = "./artifacts/native-assembly/bootstrap-file-existing-output";
        string memory input = string.concat(prefix, ".admitted-prestate.abi");
        string memory output = string.concat(prefix, ".complete.abi");
        vm.writeFileBinary(input, abi.encode(new Export.Account[](0)));
        vm.writeFileBinary(output, hex"012345");
        vm.expectRevert(abi.encodeWithSelector(Bootstrap.ExistingArtifact.selector, output));
        bootstrap.exportPreparationFile(prefix);
        require(keccak256(vm.readFileBinary(output)) == keccak256(hex"012345"));
        vm.removeFile(input);
        vm.removeFile(output);
    }
}
