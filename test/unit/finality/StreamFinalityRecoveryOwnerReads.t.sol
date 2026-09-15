// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/finality/StreamFinalityRecoveryOwnerReads.sol";
import {
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

interface RecoveryOwnerReadVm {
    function warp(uint256 timestamp) external;
    function etch(address target, bytes calldata code) external;
}

contract RecoveryOwnerReadBoundary {
    bytes private _result;
    bytes32 private _inputHash;
    bool private _fail;

    function configure(bytes memory result, bytes32 inputHash, bool fail) external {
        _result = result;
        _inputHash = inputHash;
        _fail = fail;
    }

    fallback() external {
        require(!_fail && keccak256(msg.data) == _inputHash, "fixture input/failure");
        bytes memory result = _result;
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
    }
}

contract RecoveryOwnerReadHost {
    address private immutable _target;
    bytes32 private immutable _codeHash;
    uint256 private immutable _cap;

    constructor(address target, uint256 cap) {
        _target = target;
        _codeHash = target.codehash;
        _cap = cap;
    }

    function read(StreamFinalityScope memory scope, bytes32 action, bytes32 manifest)
        external
        view
        returns (StreamFinalityRecoveryOwnerReads.Facts memory)
    {
        return StreamFinalityRecoveryOwnerReads.read(
            _target, _codeHash, _cap, scope, action, manifest
        );
    }
}

/// @dev Returned OwnerRecords and fixed-host boundaries only; no actual notice/governance proof.
contract StreamFinalityRecoveryOwnerReadsTest {
    RecoveryOwnerReadVm private constant vm =
        RecoveryOwnerReadVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    RecoveryOwnerReadBoundary private owner;
    RecoveryOwnerReadHost private host;
    StreamFinalityScope private scope;
    bytes32 private constant ACTION = keccak256("actual action fixture");
    bytes32 private constant MANIFEST = keccak256("actual manifest fixture");

    function setUp() public {
        vm.warp(100);
        owner = new RecoveryOwnerReadBoundary();
        host = new RecoveryOwnerReadHost(address(owner), 150000);
        scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 7, 0, 0);
        _set(_healthy(), false);
    }

    function _healthy() private pure returns (uint256[6] memory words) {
        words = [uint256(1), uint256(keccak256("owner evidence")), 17, 100, 23, 9];
    }

    function _set(uint256[6] memory words, bool fail) private {
        owner.configure(abi.encode(words), keccak256(_input()), fail);
    }

    function _input() private view returns (bytes memory) {
        return abi.encodeCall(
            IStreamFinalityRecoveryOwnerEvidence.verifyRecoveryOwnerEvidence,
            (scope, ACTION, MANIFEST)
        );
    }

    function _call() private view returns (bool ok, bytes memory data) {
        return address(host)
            .staticcall(abi.encodeCall(RecoveryOwnerReadHost.read, (scope, ACTION, MANIFEST)));
    }

    function _error(bytes memory expected) private view {
        (bool ok, bytes memory data) = _call();
        require(!ok && keccak256(data) == keccak256(expected), "exact error");
    }

    function testOwnerEvidenceExactSelectorTupleAndNoticeEquality() public view {
        require(type(IStreamFinalityRecoveryOwnerEvidence).interfaceId == 0x20279cd8, "interface1");
        (bool ok, bytes memory data) = _call();
        require(
            ok && data.length == 160
                && keccak256(data)
                    == keccak256(
                        abi.encode(
                            keccak256("owner evidence"),
                            uint64(17),
                            uint64(100),
                            uint32(23),
                            uint32(9)
                        )
                    ),
            "exact five saved fields at notice equality"
        );
    }

    function testOwnerEvidenceZerosPrecedeFutureNoticeAndInvalidFlag() public {
        for (uint256 i = 1; i <= 3; ++i) {
            uint256[6] memory words = _healthy();
            words[0] = 0;
            words[3] = 101;
            words[i] = 0;
            _set(words, false);
            _error(hex"f17d89ad");
        }
    }

    function testOwnerEvidenceFutureNoticePrecedesFalseButElapsedFalseInvalid() public {
        uint256[6] memory words = _healthy();
        words[0] = 0;
        words[3] = 101;
        _set(words, false);
        _error(abi.encodeWithSelector(bytes4(0x00298c68), uint64(101)));
        vm.warp(101);
        _error(hex"f17d89ad");
        words[0] = 1;
        _set(words, false);
        (bool ok,) = _call();
        require(ok, "healthy elapsed record");
    }

    function testOwnerEvidenceMalformedWidthsLengthsAndReadFailureAreUnreadable() public {
        for (uint256 i; i < 6; ++i) {
            if (i == 1) continue;
            uint256[6] memory words = _healthy();
            words[i] = i == 0
                ? 2
                : (i < 4 ? uint256(type(uint64).max) + 1 : uint256(type(uint32).max) + 1);
            _set(words, false);
            _error(hex"781ae739");
        }
        bytes memory correct = abi.encode(_healthy());
        for (uint256 i; i < 3; ++i) {
            bytes memory malformed = new bytes(i == 0 ? 0 : (i == 1 ? 191 : 193));
            owner.configure(malformed, keccak256(_input()), false);
            _error(hex"781ae739");
        }
        owner.configure(correct, keccak256(_input()), true);
        _error(hex"781ae739");
    }

    function testOwnerEvidenceExactScopeActionAndManifestArePassedToProducer() public {
        StreamFinalityScope memory wrong = scope;
        wrong.collectionId = 8;
        (bool ok, bytes memory data) = address(host)
            .staticcall(abi.encodeCall(RecoveryOwnerReadHost.read, (wrong, ACTION, MANIFEST)));
        require(!ok && keccak256(data) == keccak256(hex"781ae739"), "scope");
        (ok, data) = address(host)
            .staticcall(
                abi.encodeCall(RecoveryOwnerReadHost.read, (scope, bytes32(uint256(1)), MANIFEST))
            );
        require(!ok && keccak256(data) == keccak256(hex"781ae739"), "action");
        (ok, data) = address(host)
            .staticcall(
                abi.encodeCall(RecoveryOwnerReadHost.read, (scope, ACTION, bytes32(uint256(1))))
            );
        require(!ok && keccak256(data) == keccak256(hex"781ae739"), "manifest");
        (ok,) = _call();
        require(ok, "healthy exact input retry");
    }

    function testOwnerEvidenceSameHostParentGasAndRuntimeRestore() public {
        (bool ok, bytes memory data) = address(host).staticcall{ gas: 200000 }(
            abi.encodeCall(RecoveryOwnerReadHost.read, (scope, ACTION, MANIFEST))
        );
        require(!ok && data.length == 68, "typed bounded parent failure");
        bytes4 selector;
        uint256 available;
        uint256 required;
        assembly ("memory-safe") {
            selector := mload(add(data, 32))
            available := mload(add(data, 36))
            required := mload(add(data, 68))
        }
        require(
            selector == StreamFinalityRecoveryOwnerReads.FinalityRecoveryParentGas.selector
                && available < required && required == 150000 + uint256(150000) / 63 + 100000,
            "same fixed cap"
        );
        (ok,) = _call();
        require(ok, "same host healthy parent retry");
        bytes memory code = address(owner).code;
        vm.etch(address(owner), hex"00");
        _error(hex"781ae739");
        vm.etch(address(owner), code);
        (ok,) = _call();
        require(ok, "same original runtime restored");
    }
}
