// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredTimingTypes as TM
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";
import {
    StreamArtistRecoveredTimingInventory as Inventory
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredTimingInventory.sol";
import {
    StreamArtistWindowConfiguration as Windows
} from "../../../smart-contracts/domains/artist/StreamArtistWindowConfiguration.sol";
import {
    StreamArtistRotationState as Rotations
} from "../../../smart-contracts/domains/artist/StreamArtistRotationState.sol";
import {
    StreamArtistEstateState as Estate
} from "../../../smart-contracts/domains/artist/StreamArtistEstateState.sol";
import {
    StreamArtistDormancyState as Dormancy
} from "../../../smart-contracts/domains/artist/StreamArtistDormancyState.sol";
import {
    StreamArtistUnavailabilityState as Findings
} from "../../../smart-contracts/domains/artist/StreamArtistUnavailabilityState.sol";
import {
    StreamArtistNativeReceipts as Native
} from "../../../smart-contracts/domains/artist/StreamArtistNativeReceipts.sol";

interface RecoveredTimingVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

/// @dev Typed currentAction boundary only. This does not claim full governance admission.
contract RecoveredTimingGovernance {
    bool private executing;
    bytes32 private action;
    uint8 private class_;
    bytes32 private scope_;
    bytes32 private oldHash;
    bytes32 private newHash;

    function set(
        bool active,
        bytes32 id,
        uint8 actionClass,
        bytes32 scope,
        bytes32 oldValue,
        bytes32 newValue
    ) external {
        executing = active;
        action = id;
        class_ = actionClass;
        scope_ = scope;
        oldHash = oldValue;
        newHash = newValue;
    }

    function currentAction()
        external
        view
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return (executing, action, class_, scope_, oldHash, newHash);
    }
}

/// @dev Actual original timing leaves and observer with isolated storage. The import method
/// copies only this test's timing fixture; production operation60/owner authorization is separate.
contract RecoveredTimingHost {
    uint256 public sentinel = 17;
    Rotations.State private rotations;
    Estate.State private estate;
    Findings.State private findings;
    Dormancy.State private dormancy;

    struct Repudiation {
        uint64 seconds_;
        uint64 revision;
        mapping(bytes32 => bool) actions;
    }

    constructor(bool initialize) {
        if (initialize) Inventory.initialize();
    }

    function info(bytes32 parameter) public view returns (uint64, uint64, uint64) {
        return Windows.info(rotations, estate, findings, dormancy, parameter);
    }

    function configure(
        address authority,
        address actor,
        bytes32 parameter,
        uint64 value,
        uint64 revision
    ) external {
        Windows.configure(
            rotations, estate, findings, dormancy, authority, actor, parameter, value, revision
        );
    }

    function configuration() public view returns (TM.Configuration memory c) {
        c.values = [
            rotations.rotationContestSeconds,
            rotations.priorStandingTailSeconds,
            estate.noticeSeconds,
            dormancy.inactivitySeconds,
            dormancy.noticeSeconds,
            findings.noticeSeconds,
            _repudiation().seconds_
        ];
        c.revisions = [
            rotations.timingRevision,
            estate.noticeRevision,
            dormancy.timingRevision,
            findings.timingRevision,
            _repudiation().revision
        ];
    }

    function collect() external view returns (TM.Bundle memory) {
        return Inventory.collect(configuration());
    }

    function checkpoint() external view returns (TM.Checkpoint memory) {
        return Inventory.checkpoint(configuration());
    }

    function validate(TM.Bundle memory b) external pure returns (bytes32) {
        return Inventory.validate(b);
    }

    function nativeCount() external view returns (uint256) {
        return Native.count();
    }

    function install(TM.Bundle memory b) external {
        Inventory.install(b);
        rotations.rotationContestSeconds = b.configuration.values[0];
        rotations.priorStandingTailSeconds = b.configuration.values[1];
        estate.noticeSeconds = b.configuration.values[2];
        dormancy.inactivitySeconds = b.configuration.values[3];
        dormancy.noticeSeconds = b.configuration.values[4];
        findings.noticeSeconds = b.configuration.values[5];
        _repudiation().seconds_ = b.configuration.values[6];
        rotations.timingRevision = b.configuration.revisions[0];
        estate.noticeRevision = b.configuration.revisions[1];
        dormancy.timingRevision = b.configuration.revisions[2];
        findings.timingRevision = b.configuration.revisions[3];
        _repudiation().revision = b.configuration.revisions[4];
    }

    function _repudiation() private pure returns (Repudiation storage s) {
        bytes32 slot = keccak256("6529STREAM_ARTIST_REPUDIATION_TIMING_V1");
        assembly ("memory-safe") { s.slot := slot }
    }
}

contract StreamArtistRecoveredTimingInventoryTest {
    RecoveredTimingVm private constant vm =
        RecoveredTimingVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    RecoveredTimingHost private host;
    RecoveredTimingGovernance private governance;
    uint256 private actions;

    function setUp() public {
        host = new RecoveredTimingHost(true);
        governance = new RecoveredTimingGovernance();
    }

    function testRecoveredTimingEmptyObserverHasExplicitVersionAndRawDefaults() public view {
        TM.Bundle memory b = host.collect();
        require(
            b.checkpoint.schema == TM.SCHEMA && b.checkpoint.version == 1 && b.entries.length == 0
        );
        require(b.checkpoint.count == 0 && b.checkpoint.root == 0);
        for (uint256 i; i < 7; ++i) {
            require(b.configuration.values[i] == 0);
        }
        for (uint256 i; i < 5; ++i) {
            require(b.configuration.revisions[i] == 0);
        }
        require(host.nativeCount() == 0 && host.sentinel() == 17);
    }

    function testRecoveredTimingAllFiveActualLeavesPreserveSevenParametersAndSharedRevisions()
        public
    {
        for (uint256 i; i < 7; ++i) {
            _change(host, _parameter(i), _default(i) + 1 days);
        }
        TM.Bundle memory b = host.collect();
        require(b.entries.length == 7 && b.checkpoint.count == 7);
        require(
            b.configuration.revisions[0] == 3 && b.configuration.revisions[1] == 2
                && b.configuration.revisions[2] == 3 && b.configuration.revisions[3] == 2
                && b.configuration.revisions[4] == 2
        );
        for (uint256 i; i < 7; ++i) {
            require(b.entries[i].change.parameter == _parameter(i));
            require(b.entries[i].owner == address(host) && b.entries[i].chainId == block.chainid);
            require(b.entries[i].change.oldValue == _default(i));
            require(b.entries[i].change.newValue == _default(i) + 1 days);
        }
        require(host.nativeCount() == 0 && host.sentinel() == 17);
    }

    function testRecoveredTimingOriginalEventAndContextStillExact() public {
        bytes32 parameter = _parameter(6);
        vm.recordLogs();
        bytes32 action = _change(host, parameter, 8 days);
        RecoveredTimingVm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 1 && logs[0].emitter == address(host));
        require(
            logs[0].topics.length == 3
                && logs[0].topics[0]
                    == keccak256(
                        "ArtistWindowChanged(uint16,bytes32,uint64,uint64,uint64,uint64,bytes32)"
                    )
        );
        require(logs[0].topics[1] == parameter && logs[0].topics[2] == action);
        require(
            keccak256(logs[0].data)
                == keccak256(
                    abi.encode(uint16(1), uint64(7 days), uint64(8 days), uint64(3 days), uint64(2))
                )
        );
        TM.Entry memory row = host.collect().entries[0];
        require(row.change.oldHash == _state(address(host), parameter, 7 days, 3 days, 1));
        require(row.change.newHash == _state(address(host), parameter, 8 days, 3 days, 2));
    }

    function testRecoveredTimingRejectedOriginalWritesLeaveBothStatesUnchanged() public {
        bytes32 parameter = _parameter(0);
        _change(host, parameter, 8 days);
        bytes32 before_ = keccak256(abi.encode(host.collect()));
        _witness(host, parameter, 9 days);
        _fails(
            address(host),
            abi.encodeCall(
                host.configure,
                (address(governance), address(1), parameter, uint64(9 days), uint64(2))
            )
        );
        _fails(
            address(host),
            abi.encodeCall(
                host.configure,
                (address(governance), address(governance), parameter, uint64(9 days), uint64(1))
            )
        );
        _fails(
            address(host),
            abi.encodeCall(
                host.configure,
                (address(governance), address(governance), parameter, uint64(8 days), uint64(2))
            )
        );
        _fails(
            address(host),
            abi.encodeCall(
                host.configure,
                (address(governance), address(governance), parameter, uint64(1 days), uint64(2))
            )
        );
        governance.set(false, bytes32(uint256(1)), 0, 0, 0, 0);
        _fails(
            address(host),
            abi.encodeCall(
                host.configure,
                (address(governance), address(governance), parameter, uint64(9 days), uint64(2))
            )
        );
        require(before_ == keccak256(abi.encode(host.collect())));
    }

    function testRecoveredTimingImportedPrefixKeepsOriginalDomainThenAppendsNewOwner() public {
        _change(host, _parameter(0), 8 days);
        _change(host, _parameter(6), 8 days);
        TM.Bundle memory original = host.collect();
        RecoveredTimingHost destination = new RecoveredTimingHost(true);
        destination.install(original);
        require(keccak256(abi.encode(destination.collect())) == keccak256(abi.encode(original)));
        _change(destination, _parameter(0), 9 days);
        TM.Bundle memory next = destination.collect();
        require(next.entries.length == 3 && next.entries[2].owner == address(destination));
        require(next.entries[2].previousCommitment == original.checkpoint.root);
        require(
            next.entries[2].change.oldHash
                == _state(address(destination), _parameter(0), 8 days, 72 hours, 2)
        );
        for (uint256 i; i < 2; ++i) {
            require(
                keccak256(abi.encode(next.entries[i])) == keccak256(abi.encode(original.entries[i]))
            );
        }
        require(destination.nativeCount() == 0 && destination.sentinel() == 17);
    }

    function testRecoveredTimingIncompleteOrAlteredInventoryCannotInstall() public {
        _change(host, _parameter(0), 8 days);
        _change(host, _parameter(2), 181 days);
        TM.Bundle memory valid = host.collect();
        RecoveredTimingHost destination = new RecoveredTimingHost(true);
        TM.Bundle memory b = abi.decode(abi.encode(valid), (TM.Bundle));
        b.entries[0].owner = address(destination);
        _fails(address(destination), abi.encodeCall(destination.install, (b)));
        b = abi.decode(abi.encode(valid), (TM.Bundle));
        b.entries[1].change.actionId = bytes32(uint256(999));
        _fails(address(destination), abi.encodeCall(destination.install, (b)));
        b = abi.decode(abi.encode(valid), (TM.Bundle));
        b.configuration.values[6] = 8 days;
        b.checkpoint.configurationHash = keccak256(abi.encode(b.configuration));
        _fails(address(destination), abi.encodeCall(destination.install, (b)));
        b = abi.decode(abi.encode(valid), (TM.Bundle));
        b.entries = new TM.Entry[](0);
        b.checkpoint.count = 0;
        b.checkpoint.root = 0;
        _fails(address(destination), abi.encodeCall(destination.install, (b)));
        require(destination.collect().entries.length == 0);
        destination.install(valid);
        require(keccak256(abi.encode(destination.collect())) == keccak256(abi.encode(valid)));
    }

    function testRecoveredTimingMissingObserverAndConflictingImportAreUnavailable() public {
        RecoveredTimingHost absent = new RecoveredTimingHost(false);
        _fails(address(absent), abi.encodeCall(absent.collect, ()));
        _change(host, _parameter(0), 8 days);
        TM.Bundle memory original = host.collect();
        RecoveredTimingHost destination = new RecoveredTimingHost(true);
        destination.install(original);
        destination.install(original);
        _change(host, _parameter(0), 9 days);
        _fails(address(destination), abi.encodeCall(destination.install, (host.collect())));
        require(keccak256(abi.encode(destination.collect())) == keccak256(abi.encode(original)));
    }

    function testRecoveredTimingTransportCapacityDoesNotCapOriginalWriter() public {
        bytes32 parameter = _parameter(0);
        for (uint256 i; i <= TM.MAX_ENTRIES; ++i) {
            _change(host, parameter, uint64(8 days + i));
        }
        (uint64 value,, uint64 revision) = host.info(parameter);
        require(value == 8 days + TM.MAX_ENTRIES && revision == TM.MAX_ENTRIES + 2);
        _fails(address(host), abi.encodeCall(host.collect, ()));
        _fails(address(host), abi.encodeCall(host.checkpoint, ()));
        require(host.nativeCount() == 0 && host.sentinel() == 17);
    }

    function _change(RecoveredTimingHost target, bytes32 parameter, uint64 value)
        private
        returns (bytes32 action)
    {
        action = _witness(target, parameter, value);
        (,, uint64 revision) = target.info(parameter);
        target.configure(address(governance), address(governance), parameter, value, revision);
    }

    function _witness(RecoveredTimingHost target, bytes32 parameter, uint64 value)
        private
        returns (bytes32 action)
    {
        (uint64 prior, uint64 floor, uint64 revision) = target.info(parameter);
        action = keccak256(abi.encode("timing action", ++actions));
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_WINDOW_SCOPE_V1"),
                block.chainid,
                address(target),
                parameter
            )
        );
        governance.set(
            true,
            action,
            value < prior ? 1 : 0,
            scope,
            _state(address(target), parameter, prior, floor, revision),
            _state(address(target), parameter, value, floor, revision + 1)
        );
    }

    function _state(address owner, bytes32 parameter, uint64 value, uint64 floor, uint64 revision)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_WINDOW_STATE_V1"),
                block.chainid,
                owner,
                parameter,
                value,
                floor,
                revision
            )
        );
    }

    function _fails(address target, bytes memory data) private {
        (bool success,) = target.call(data);
        require(!success, "malformed operation accepted");
    }

    function _parameter(uint256 i) private pure returns (bytes32) {
        if (i == 0) return keccak256("ARTIST_ROTATION_CONTEST_SECONDS");
        if (i == 1) return keccak256("ARTIST_PRIOR_ADDRESS_STANDING_TAIL_SECONDS");
        if (i == 2) return keccak256("ARTIST_ESTATE_ACTIVATION_NOTICE_SECONDS");
        if (i == 3) return keccak256("ARTIST_DORMANCY_MIN_INACTIVITY_SECONDS");
        if (i == 4) return keccak256("ARTIST_DORMANCY_NOTICE_SECONDS");
        if (i == 5) return keccak256("ARTIST_UNAVAILABILITY_RECOVERY_NOTICE_SECONDS");
        return keccak256("ARTIST_REPUDIATION_CONTEST_SECONDS");
    }

    function _default(uint256 i) private pure returns (uint64) {
        if (i == 0 || i == 6) return 7 days;
        if (i == 1 || i == 5) return 90 days;
        if (i == 2) return 180 days;
        if (i == 3) return 730 days;
        return 365 days;
    }
}
