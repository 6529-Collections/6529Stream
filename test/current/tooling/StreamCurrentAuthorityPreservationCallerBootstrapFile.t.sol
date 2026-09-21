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
    function readFile(string calldata path) external view returns (string memory);
    function exists(string calldata path) external view returns (bool);
    function createDir(string calldata path, bool recursive) external;
    function removeFile(string calldata path) external;
    function getNonce(address account) external view returns (uint64);
}

contract BootstrapBaselineWitness {
    uint256 public value;

    constructor(uint256 initialValue) payable {
        value = initialValue;
    }
}

contract BootstrapBaselineEmptyWitness {
    constructor() payable {
        assembly ("memory-safe") {
            return(0, 0)
        }
    }
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

    function testBaselineCapturesLiveAccountsWithSeparateBoundMarker() public {
        string memory prefix = "./artifacts/native-assembly/bootstrap-file-baseline";
        // Created during this test, unlike the recorder created in setUp. dumpState omits its
        // immediate cheatcode caller (the Bootstrap child), not every ordinary created child.
        BootstrapBaselineWitness witness = new BootstrapBaselineWitness{ value: 7 }(6529);
        BootstrapBaselineEmptyWitness empty = new BootstrapBaselineEmptyWitness{ value: 1 }();
        address[] memory reads = new address[](2);
        (reads[0], reads[1]) = uint160(address(witness)) < uint160(address(empty))
            ? (address(witness), address(empty))
            : (address(empty), address(witness));
        string memory input = string.concat(prefix, ".baseline-read-accounts.abi");
        vm.writeFileBinary(input, abi.encode(reads));
        Bootstrap.BaselineCut memory cut = bootstrap.capturePrestateFile(prefix);
        bytes memory candidate = vm.readFileBinary(string.concat(prefix, ".candidate-prestate.abi"));
        Export.Account[] memory accounts = abi.decode(candidate, (Export.Account[]));
        require(keccak256(abi.encode(accounts)) == keccak256(candidate));
        require(cut.accountsHash == keccak256(candidate));
        require(
            cut.dumpHash
                == keccak256(bytes(vm.readFile(string.concat(prefix, ".baseline-dump.json"))))
        );
        require(cut.recorder == address(bootstrap) && cut.caller == address(this));
        require(cut.origin == tx.origin && cut.recorderCodeHash == address(bootstrap).codehash);
        require(cut.recorderNonce == vm.getNonce(address(bootstrap)));
        require(cut.recorderBalance == address(bootstrap).balance);
        bool witnessFound;
        bool emptyFound;
        for (uint256 i; i < accounts.length; ++i) {
            require(accounts[i].account != address(bootstrap), "dump omits immediate VM caller");
            if (accounts[i].account == address(witness)) {
                witnessFound = true;
                require(accounts[i].codeHash == address(witness).codehash);
                require(keccak256(accounts[i].code) == keccak256(address(witness).code));
                require(
                    accounts[i].nonce == 1 && accounts[i].nonce == vm.getNonce(address(witness))
                );
                require(accounts[i].balance == 7 && accounts[i].balance == address(witness).balance);
                require(accounts[i].slots.length == 1);
                require(accounts[i].slots[0].slot == bytes32(0));
                require(accounts[i].slots[0].value == bytes32(uint256(6529)));
                require(witness.value() == 6529);
            }
            if (accounts[i].account == address(empty)) {
                emptyFound = true;
                require(accounts[i].code.length == 0 && address(empty).code.length == 0);
                require(
                    accounts[i].codeHash == keccak256("")
                        && accounts[i].codeHash == address(empty).codehash
                );
                require(accounts[i].nonce == 1 && accounts[i].nonce == vm.getNonce(address(empty)));
                require(accounts[i].balance == 1 && accounts[i].balance == address(empty).balance);
                require(accounts[i].slots.length == 0);
            }
        }
        require(witnessFound && emptyFound);
        require(keccak256(vm.readFileBinary(input)) == keccak256(abi.encode(reads)));
        bytes memory context = vm.readFileBinary(string.concat(prefix, ".baseline-context.abi"));
        require(keccak256(context) == keccak256(abi.encode(cut)));
        (bytes32 profile, bytes32 contextHash) = abi.decode(
            vm.readFileBinary(string.concat(prefix, ".baseline-complete.abi")), (bytes32, bytes32)
        );
        require(profile == cut.profile && contextHash == keccak256(context));
        require(!vm.exists(string.concat(prefix, ".admitted-prestate.abi")));
        require(!vm.exists(string.concat(prefix, ".complete.abi")));
        vm.removeFile(string.concat(prefix, ".baseline-dump.json"));
        vm.removeFile(string.concat(prefix, ".candidate-prestate.abi"));
        vm.removeFile(string.concat(prefix, ".baseline-context.abi"));
        vm.removeFile(string.concat(prefix, ".baseline-complete.abi"));
        vm.removeFile(input);
    }

    function testBaselineRejectsNoncanonicalReadAccountsBeforeOutputs() public {
        string memory prefix = "./artifacts/native-assembly/bootstrap-file-baseline-noncanonical";
        bytes memory canonical = abi.encode(new address[](0));
        _rejectReadAccounts(
            prefix,
            bytes.concat(canonical, hex"01"),
            abi.encodeWithSelector(Bootstrap.InvalidBaselineReadAccountsEncoding.selector)
        );
        // A decodable empty array with an unused head word is also noncanonical.
        _rejectReadAccounts(
            prefix,
            abi.encode(uint256(64), uint256(0), uint256(0)),
            abi.encodeWithSelector(Bootstrap.InvalidBaselineReadAccountsEncoding.selector)
        );
    }

    function testBaselineRejectsMalformedReadAccountsBeforeOutputs() public {
        string memory prefix = "./artifacts/native-assembly/bootstrap-file-baseline-malformed";
        string memory input = string.concat(prefix, ".baseline-read-accounts.abi");
        vm.writeFileBinary(input, hex"01");
        (bool accepted,) =
            address(bootstrap).call(abi.encodeCall(Bootstrap.capturePrestateFile, (prefix)));
        require(!accepted);
        _noBaselineOutputs(prefix);
        require(keccak256(vm.readFileBinary(input)) == keccak256(hex"01"));
        vm.removeFile(input);
    }

    function testBaselineRejectsDuplicateUnorderedAndZeroReadAccounts() public {
        string memory prefix = "./artifacts/native-assembly/bootstrap-file-baseline-order";
        address[] memory reads = new address[](2);
        reads[0] = address(bootstrap);
        reads[1] = address(bootstrap);
        _rejectReadAccounts(
            prefix,
            abi.encode(reads),
            abi.encodeWithSelector(Bootstrap.InvalidBaselineReadAccount.selector, reads[1])
        );
        (reads[0], reads[1]) = uint160(address(this)) > uint160(address(bootstrap))
            ? (address(this), address(bootstrap))
            : (address(bootstrap), address(this));
        _rejectReadAccounts(
            prefix,
            abi.encode(reads),
            abi.encodeWithSelector(Bootstrap.InvalidBaselineReadAccount.selector, reads[1])
        );
        reads = new address[](1);
        _rejectReadAccounts(
            prefix,
            abi.encode(reads),
            abi.encodeWithSelector(Bootstrap.InvalidBaselineReadAccount.selector, address(0))
        );
    }

    function testBaselineRejectsAbsentReadAccountBeforeOutputs() public {
        string memory prefix = "./artifacts/native-assembly/bootstrap-file-baseline-absent";
        address[] memory reads = new address[](1);
        reads[0] = address(0xBEEF);
        require(reads[0].codehash == bytes32(0), "negative requires genuine absence");
        _rejectReadAccounts(
            prefix,
            abi.encode(reads),
            abi.encodeWithSelector(Bootstrap.BaselineReadAccountMismatch.selector, reads[0])
        );
    }

    function _rejectReadAccounts(string memory prefix, bytes memory encoded, bytes memory reason)
        private
    {
        string memory input = string.concat(prefix, ".baseline-read-accounts.abi");
        vm.writeFileBinary(input, encoded);
        vm.expectRevert(reason);
        bootstrap.capturePrestateFile(prefix);
        _noBaselineOutputs(prefix);
        require(keccak256(vm.readFileBinary(input)) == keccak256(encoded));
        vm.removeFile(input);
    }

    function _noBaselineOutputs(string memory prefix) private view {
        require(!vm.exists(string.concat(prefix, ".baseline-dump.json")));
        require(!vm.exists(string.concat(prefix, ".candidate-prestate.abi")));
        require(!vm.exists(string.concat(prefix, ".baseline-context.abi")));
        require(!vm.exists(string.concat(prefix, ".baseline-complete.abi")));
        require(!vm.exists(string.concat(prefix, ".admitted-prestate.abi")));
        require(!vm.exists(string.concat(prefix, ".complete.abi")));
    }

    function testBaselineRefusesExistingContextWithoutWritingCandidate() public {
        string memory prefix = "./artifacts/native-assembly/bootstrap-file-baseline-existing";
        string memory context = string.concat(prefix, ".baseline-context.abi");
        vm.writeFileBinary(context, hex"5678");
        vm.expectRevert(abi.encodeWithSelector(Bootstrap.ExistingArtifact.selector, context));
        bootstrap.capturePrestateFile(prefix);
        require(keccak256(vm.readFileBinary(context)) == keccak256(hex"5678"));
        require(!vm.exists(string.concat(prefix, ".baseline-dump.json")));
        require(!vm.exists(string.concat(prefix, ".candidate-prestate.abi")));
        require(!vm.exists(string.concat(prefix, ".baseline-complete.abi")));
        require(!vm.exists(string.concat(prefix, ".complete.abi")));
        vm.removeFile(context);
    }
}
