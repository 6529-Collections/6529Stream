// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/governance/StreamGovernanceRecoveryPolicy.sol";
import {
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

contract RecoveryPolicyCoreBoundary {
    address public old;

    function set(address target) external {
        old = target;
    }

    function getSatellitePointer(bytes32 key)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        require(key == keccak256("ARTWORK_FINALITY_RECOVERY"), "exact pointer");
        return (
            old,
            old == address(0) ? bytes32(0) : old.codehash,
            false,
            keccak256("STREAM_ARTWORK_FINALITY_RECOVERY"),
            bytes4(0x83685f5c),
            address(0x1234),
            uint8(1),
            keccak256("module manifest"),
            keccak256("deployment"),
            uint64(1)
        );
    }
}

contract RecoveryPolicyHost {
    address private immutable _core;
    bytes32 private immutable _hash;

    constructor(address core_) {
        _core = core_;
        _hash = core_.codehash;
    }

    function validate(uint8 class_, GovernanceCall[] memory calls, bytes[] memory data)
        external
        view
    {
        StreamGovernanceRecoveryPolicy.validate(_core, _hash, class_, calls, data);
    }
}

contract RecoveryPolicyTargetBoundary {
    address private immutable _core;
    address private immutable _executor;
    uint8 public fault;

    constructor(address core_, address executor_) {
        _core = core_;
        _executor = executor_;
    }

    function setFault(uint8 value) external {
        fault = value;
    }

    function core() external view returns (address) {
        return fault == 1 ? address(0xDEAD) : _core;
    }

    function governanceAuthority() external view returns (address) {
        return fault == 2 ? address(0xDEAD) : _executor;
    }

    function streamModuleType() external view returns (bytes32) {
        return fault == 3 ? bytes32(0) : keccak256("STREAM_ARTWORK_FINALITY_RECOVERY");
    }

    function streamModuleInterfaceId() external view returns (bytes4) {
        return fault == 4 ? bytes4(0) : bytes4(0x83685f5c);
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        if (id == 0xffffffff) return fault == 5;
        if (id == 0x01ffc9a7) return fault != 6;
        return id == 0x83685f5c && fault != 7;
    }
}

/// @dev Bounded library classifier fixture. Actual catalog/Executor scheduling is a separate gate.
contract StreamGovernanceRecoveryPolicyTest {
    RecoveryPolicyCoreBoundary private core;
    RecoveryPolicyHost private host;
    RecoveryPolicyTargetBoundary private first;
    RecoveryPolicyTargetBoundary private second;
    bytes32 private constant KEY = keccak256("ARTWORK_FINALITY_RECOVERY");

    function setUp() public {
        core = new RecoveryPolicyCoreBoundary();
        host = new RecoveryPolicyHost(address(core));
        first = new RecoveryPolicyTargetBoundary(address(core), address(host));
        second = new RecoveryPolicyTargetBoundary(address(core), address(host));
    }

    function _request(uint256 collectionId) private view returns (bytes memory) {
        StreamFinalityRecoveryRequest memory r;
        r.scope.scopeType = StreamFinalityScopeType.COLLECTION;
        r.scope.collectionId = collectionId;
        r.expectedOriginalFinalityRecordHash = keccak256("original");
        r.expectedOldRouteHash = keccak256("old component");
        r.replacementRoute.component = address(second);
        r.recoveryManifest.uri = "urn:recovery:scope";
        r.recoveryManifest.uriHash = keccak256(bytes(r.recoveryManifest.uri));
        r.recoveryManifest.contentHash = keccak256("staged exact intent");
        r.reasonURI = "urn:reason";
        return abi.encodeCall(IStreamArtworkFinalityRecovery.executeFinalityRecovery, (r));
    }

    function _call(address target, bytes memory data)
        private
        pure
        returns (GovernanceCall memory c)
    {
        c.target = target;
        c.callDataHash = keccak256(data);
        bytes4 selector;
        assembly ("memory-safe") { selector := mload(add(data, 32)) }
        c.selector = selector;
        c.scopeHash = keccak256("per-call scope supplied by owning target");
        c.oldValueHash = keccak256("per-call old state");
        c.newValueHash = keccak256("per-call new state");
    }

    function _one(address target, bytes memory data)
        private
        pure
        returns (GovernanceCall[] memory calls, bytes[] memory all)
    {
        calls = new GovernanceCall[](1);
        all = new bytes[](1);
        all[0] = data;
        calls[0] = _call(target, data);
    }

    function _try(uint8 class_, GovernanceCall[] memory calls, bytes[] memory data)
        private
        view
        returns (bool ok, bytes memory result)
    {
        return address(host)
            .staticcall(abi.encodeCall(RecoveryPolicyHost.validate, (class_, calls, data)));
    }

    function _reject(uint8 class_, GovernanceCall[] memory calls, bytes[] memory data)
        private
        view
    {
        (bool ok,) = _try(class_, calls, data);
        require(!ok, "must reject");
    }

    function _cutover() private view returns (GovernanceCall[] memory calls, bytes[] memory data) {
        calls = new GovernanceCall[](2);
        data = new bytes[](2);
        data[0] = abi.encodeCall(
            IStreamArtworkFinalityRecovery.assertNoIncompleteFinalityRecoveryRefreshPlans, ()
        );
        calls[0] = _call(address(first), data[0]);
        data[1] = abi.encodeCall(IStreamCorePointers.updateSatellitePointer, (KEY, address(second)));
        calls[1] = _call(address(core), data[1]);
    }

    function testRecoveryClassifierAcceptsOneRecoveryAtAnyBatchPosition() public view {
        GovernanceCall[] memory calls = new GovernanceCall[](3);
        bytes[] memory data = new bytes[](3);
        data[0] = hex"01020304";
        data[1] = _request(7);
        data[2] = hex"05060708";
        calls[0] = _call(address(0xAAA), data[0]);
        calls[1] = _call(address(first), data[1]);
        calls[2] = _call(address(0xBBB), data[2]);
        host.validate(2, calls, data);
        (calls[0], calls[1]) = (calls[1], calls[0]);
        (data[0], data[1]) = (data[1], data[0]);
        host.validate(2, calls, data);
    }

    function testRecoveryClassifierCountsAcrossEveryTargetAndScope() public view {
        GovernanceCall[] memory calls = new GovernanceCall[](2);
        bytes[] memory data = new bytes[](2);
        data[0] = _request(7);
        data[1] = _request(8);
        calls[0] = _call(address(first), data[0]);
        calls[1] = _call(address(second), data[1]);
        (bool ok, bytes memory result) = _try(2, calls, data);
        require(
            !ok
                && keccak256(result)
                    == keccak256(
                        abi.encodeWithSelector(
                            StreamGovernanceRecoveryPolicy.GovernanceRecoveryCardinality.selector,
                            uint256(2)
                        )
                    ),
            "exact across-target cardinality"
        );
        calls[1].target = address(first);
        _reject(2, calls, data);
    }

    function testRecoveryClassifierBindsValueClassHashAndExactCanonicalRequest() public view {
        (GovernanceCall[] memory calls, bytes[] memory data) = _one(address(first), _request(7));
        _reject(1, calls, data);
        calls[0].value = 1;
        _reject(2, calls, data);
        calls[0].value = 0;
        calls[0].callDataHash = keccak256("substituted bytes");
        _reject(2, calls, data);
        calls[0] = _call(address(first), data[0]);
        data[0] = bytes.concat(data[0], hex"00");
        calls[0] = _call(address(first), data[0]);
        _reject(2, calls, data);
        data[0] = _request(7);
        // The request's outer offset must be canonical, not a second equivalent offset.
        bytes memory shifted = new bytes(data[0].length + 32);
        for (uint256 i; i < 4; ++i) {
            shifted[i] = data[0][i];
        }
        for (uint256 i = 36; i < data[0].length; ++i) {
            shifted[i + 32] = data[0][i];
        }
        shifted[35] = bytes1(uint8(64));
        data[0] = shifted;
        calls[0] = _call(address(first), shifted);
        _reject(2, calls, data);
    }

    function testRecoveryClassifierRejectsEveryWrongModuleAndReciprocalBinding() public {
        (GovernanceCall[] memory calls, bytes[] memory data) = _one(address(first), _request(7));
        for (uint8 i = 1; i <= 7; ++i) {
            first.setFault(i);
            _reject(2, calls, data);
        }
        first.setFault(0);
        host.validate(2, calls, data);
    }

    function testRecoveryCutoverInitialZeroNeedsNoPredecessorAndExactAdjacentIsAccepted() public {
        (GovernanceCall[] memory calls, bytes[] memory data) = _one(
            address(core),
            abi.encodeCall(IStreamCorePointers.updateSatellitePointer, (KEY, address(first)))
        );
        host.validate(1, calls, data);
        core.set(address(first));
        _reject(1, calls, data);
        (calls, data) = _cutover();
        host.validate(1, calls, data);
    }

    function testRecoveryCutoverRechecksTheCurrentPredecessorAtEveryValidation() public {
        core.set(address(first));
        (GovernanceCall[] memory calls, bytes[] memory data) = _cutover();
        host.validate(1, calls, data);
        core.set(address(second));
        (bool ok, bytes memory result) = _try(1, calls, data);
        require(
            !ok
                && keccak256(result)
                    == keccak256(
                        abi.encodeWithSelector(
                            StreamGovernanceRecoveryPolicy.GovernanceRecoveryCutoverInvalid
                            .selector,
                            uint256(1),
                            address(second)
                        )
                    ),
            "stale scheduled predecessor"
        );
        calls[0].target = address(second);
        host.validate(1, calls, data);
    }

    function testRecoveryCutoverRejectsInterveningWrongTargetValueAndAssertionBytes() public {
        core.set(address(first));
        (GovernanceCall[] memory calls, bytes[] memory data) = _cutover();
        calls[0].target = address(second);
        _reject(1, calls, data);
        calls[0].target = address(first);
        calls[0].value = 1;
        _reject(1, calls, data);
        calls[0].value = 0;
        data[0] = bytes.concat(data[0], hex"00");
        calls[0] = _call(address(first), data[0]);
        _reject(1, calls, data);
        (calls, data) = _cutover();
        GovernanceCall[] memory longer = new GovernanceCall[](3);
        bytes[] memory more = new bytes[](3);
        longer[0] = calls[0];
        more[0] = data[0];
        more[1] = hex"01020304";
        longer[1] = _call(address(first), more[1]);
        longer[2] = calls[1];
        more[2] = data[1];
        _reject(1, longer, more);
    }

    function testRecoveryCutoverRejectsRepeatedUpdateAndNoncanonicalAddressOrTail() public view {
        bytes memory update =
            abi.encodeCall(IStreamCorePointers.updateSatellitePointer, (KEY, address(first)));
        GovernanceCall[] memory calls = new GovernanceCall[](2);
        bytes[] memory data = new bytes[](2);
        data[0] = update;
        data[1] = update;
        calls[0] = _call(address(core), update);
        calls[1] = calls[0];
        _reject(1, calls, data);
        (calls, data) = _one(address(core), bytes.concat(update, hex"00"));
        _reject(1, calls, data);
        update[36] = bytes1(uint8(1));
        (calls, data) = _one(address(core), update);
        _reject(1, calls, data);
    }

    function testOtherPointerAndOrdinaryCallsRetainTheirExistingPolicyBoundary() public view {
        bytes memory data = bytes.concat(
            abi.encodeCall(
                IStreamCorePointers.updateSatellitePointer,
                (keccak256("OTHER_POINTER"), address(first))
            ),
            hex"00"
        );
        (GovernanceCall[] memory calls, bytes[] memory all) = _one(address(core), data);
        host.validate(1, calls, all);
        (calls, all) = _one(address(first), hex"01020304");
        host.validate(0, calls, all);
    }
}
