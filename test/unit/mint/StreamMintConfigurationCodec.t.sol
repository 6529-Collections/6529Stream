// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/MintEngineTestBase.sol";

/// @notice Original configure/read ABI through the fixed worker and unchanged16-counter cap.
/// @dev Actual Manager/Ledger/Registry; explicitly typed Core/Artist/governance boundaries.
contract StreamMintConfigurationCodecTest is MintEngineTestBase {
    struct Terms {
        IStreamMintManager.MintPhaseConfig config;
        IStreamMintManager.MintGateConfig gate;
        bytes32[] ids;
        IStreamMintManager.MintCounterConfig[] counters;
    }

    function _terms(uint256 count) private pure returns (Terms memory t) {
        t.config = IStreamMintManager.MintPhaseConfig(
            true, 7, 99999, 3, keccak256("codec application"), keccak256("codec metadata")
        );
        t.ids = new bytes32[](count);
        t.counters = new IStreamMintManager.MintCounterConfig[](count);
        for (uint256 i; i < count; ++i) {
            t.ids[i] = keccak256(abi.encode("ordered codec counter", i));
            t.counters[i] = IStreamMintManager.MintCounterConfig(
                true,
                IStreamMintManager.CounterKeyMode.CONSTANT,
                IStreamMintLedger.CounterCapMode.STATIC,
                IStreamMintLedger.CounterDeltaMode.STATIC,
                uint64(i + 3),
                1,
                keccak256(abi.encode("codec counter definition", i))
            );
        }
    }

    function _configure(Terms memory t) private returns (bytes32) {
        return manager.configurePhase(1, PHASE, t.config, t.gate, t.ids, t.counters);
    }

    function _absent() private view {
        (bool exists,) = manager.phase(1, PHASE);
        require(
            !exists && !manager.hasRegisteredPhasePolicy(1)
                && manager.phasePolicyHash(1, PHASE) == 0
                && ledger.registeredPhasePolicyHash(address(manager), 1, PHASE) == 0
                && manager.phaseCounterIds(1, PHASE).length == 0,
            "rejected decoding has no writes"
        );
    }

    function testOriginalMaximumCountersAndAllReadFieldsRoundTrip() public {
        Terms memory t = _terms(16);
        bytes32 expected = manager.previewPhasePolicyHash(
            1, PHASE, t.config, t.gate, t.ids, t.counters, new address[](0)
        );
        bytes32 actual = _configure(t);
        require(
            actual == expected && manager.phasePolicyHash(1, PHASE) == expected,
            "original preview and configuration policy agree"
        );
        (bool exists, IStreamMintManager.MintPhaseConfig memory config) = manager.phase(1, PHASE);
        require(
            exists && keccak256(abi.encode(config)) == keccak256(abi.encode(t.config)),
            "all six phase fields preserved"
        );
        require(
            keccak256(abi.encode(manager.phaseCounterIds(1, PHASE)))
                == keccak256(abi.encode(t.ids)),
            "original dynamic counter return ABI and order"
        );
        for (uint256 i; i < 16; ++i) {
            require(
                keccak256(abi.encode(manager.counterConfig(1, PHASE, t.ids[i])))
                    == keccak256(abi.encode(t.counters[i])),
                "full counter tuple retained"
            );
        }
        IStreamMintRoyaltyPolicy.Policy memory empty;
        require(
            keccak256(abi.encode(manager.phaseRoyaltyPolicy(1, PHASE)))
                    == keccak256(abi.encode(empty)) && manager.phaseExecutors(1, PHASE).length == 0,
            "fixed royalty and dynamic executor ABI"
        );
        vm.recordLogs();
        manager.setPhasePaused(1, PHASE, false);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            logs.length == 1 && logs[0].emitter == address(manager) && logs[0].topics.length == 3
                && logs[0].topics[0]
                    == keccak256("MintPhasePausedEvent(uint256,bytes32,bool,bytes32,address)")
                && logs[0].topics[1] == bytes32(uint256(1)) && logs[0].topics[2] == PHASE
                && keccak256(logs[0].data) == keccak256(abi.encode(false, expected, address(this))),
            "original pause event and caller survive fixedworker"
        );
        vm.recordLogs();
        manager.setPhasePaused(1, PHASE, false);
        require(
            vm.getRecordedLogs().length == 0 && manager.phasePolicyHash(1, PHASE) == expected,
            "pause no-op preserves policy and emits nothing"
        );
    }

    function testOriginalSeventeenthCounterRejectsWithoutRegistration() public {
        Terms memory t = _terms(17);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintManager.MintCounterCountLimitExceeded.selector, uint256(17), uint256(16)
            )
        );
        _configure(t);
        _absent();
    }

    function testOriginalMismatchedAndEmptyArraysRejectWithoutWrites() public {
        Terms memory t = _terms(1);
        t.counters = new IStreamMintManager.MintCounterConfig[](2);
        vm.expectRevert(abi.encodeWithSelector(IStreamMintManager.MintArrayLengthMismatch.selector));
        _configure(t);
        _absent();
        t = _terms(0);
        vm.expectRevert(abi.encodeWithSelector(IStreamMintManager.MintArrayLengthMismatch.selector));
        _configure(t);
        _absent();
    }

    function testOriginalPhaseValidationPrecedesCounterLimit() public {
        Terms memory t = _terms(17);
        t.config.maxBatchQuantity = 11;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintManager.InvalidMintBatchLimit.selector, uint256(11), uint256(10)
            )
        );
        _configure(t);
        _absent();
    }

    function testMalformedRawArrayHeadFailsAtomically() public {
        Terms memory t = _terms(1);
        bytes memory data =
            abi.encodeCall(manager.configurePhase, (1, PHASE, t.config, t.gate, t.ids, t.counters));
        assembly ("memory-safe") { mstore(add(data, 484), not(0)) }
        (bool ok,) = address(manager).call(data);
        require(!ok, "out-of-bounds array head rejected");
        _absent();
    }

    function testZeroExecutorRetainsOriginalError() public {
        _configure(_terms(1));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintManager.InvalidMintExecutor.selector, address(0))
        );
        manager.setPhaseExecutor(1, PHASE, address(0), true);
    }
}
