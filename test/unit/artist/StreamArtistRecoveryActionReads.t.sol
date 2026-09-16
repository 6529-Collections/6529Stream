// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryActionReads as Reads
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryActionReads.sol";
import {
    StreamArtistRecoveryActionTypes as A
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistIdentityRecovery
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamGovernanceActionFacts
} from "../../../smart-contracts/interfaces/stream/governance/IStreamGovernanceActionFacts.sol";
import {
    GovernanceCall,
    GovernanceAction,
    GovernanceActionStatus
} from "../../../smart-contracts/interfaces/stream/governance/StreamGovernanceTypes.sol";

interface RecoveryActionVm {
    function warp(uint256 value) external;
    function expectRevert() external;
    function expectRevert(bytes calldata error) external;
}

contract RecoveryActionBoundary {
    GovernanceAction private action;
    uint64 public delay = 72 hours;
    bool public sealed_ = true;
    bool public arbiter = true;
    bool public malformedFacts;
    bool public malformedHeader;

    function set(GovernanceAction calldata value) external {
        action = value;
    }

    function status(GovernanceActionStatus value) external {
        action.status = value;
    }

    function controls(uint64 value, bool sealedValue, bool role) external {
        delay = value;
        sealed_ = sealedValue;
        arbiter = role;
    }

    function malformed(bool facts, bool header) external {
        malformedFacts = facts;
        malformedHeader = header;
    }

    function minimumDelay(uint8) external view returns (uint64) {
        return delay;
    }

    function roleRegistry() external view returns (address) {
        return address(this);
    }

    function hasRole(bytes32 role, address actor) external view returns (bool) {
        return arbiter && role == keccak256("ROLE_ATTRIBUTION_ARBITER") && actor == address(0x1234);
    }

    function roleMutationState(bytes32) external pure returns (bytes32, uint64) {
        return (keccak256("roles"), 3);
    }

    function systemManifestBootstrapState() external view returns (uint256[29] memory words) {
        words[0] = 1;
        words[1] = sealed_ ? 1 : 0;
    }

    function governanceActionFacts(bytes32)
        external
        view
        returns (IStreamGovernanceActionFacts.ActionFacts memory value)
    {
        value = IStreamGovernanceActionFacts.ActionFacts(
            action.status,
            action.actionClass,
            action.callHash,
            action.notBefore,
            action.expiresAfter
        );
        if (malformedFacts) assembly ("memory-safe") {
            mstore(value, 6)
            return(value, 160)
        }
    }

    function governanceAction(bytes32) external view returns (GovernanceAction memory) {
        bytes memory result = abi.encode(action);
        if (malformedHeader) assembly ("memory-safe") { mstore(add(result, 32), 64) }
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
    }
}

contract StreamArtistRecoveryActionReadsTest {
    RecoveryActionVm private constant vm =
        RecoveryActionVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    RecoveryActionBoundary private executor;
    RecoveryActionBoundary private registry;
    bytes32 private constant ID = keccak256("scheduled exact identity recovery");
    R.Request private request;
    T.Authorization private acceptance;
    R.Context private context;
    GovernanceAction private action;

    function setUp() public {
        vm.warp(1_000_000);
        executor = new RecoveryActionBoundary();
        registry = new RecoveryActionBoundary();
        request.artistId = keccak256("artist");
        request.newAddress = address(0x4321);
        request.vestedAuthorityClass = 1;
        request.reasonHash = keccak256("reason");
        request.evidenceHash = keccak256("evidence");
        acceptance = T.Authorization(9, uint64(block.timestamp + 10 days), hex"010203");
        context.scopeHash = keccak256("scope");
        context.oldValueHash = keccak256("old");
        context.newValueHash = keccak256("new");
        action.status = GovernanceActionStatus.SCHEDULED;
        action.actionClass = 2;
        action.notBefore = uint64(block.timestamp + 72 hours);
        action.expiresAfter = action.notBefore + 1 days;
        action.proposer = address(0x1234);
        action.reasonHash = request.reasonHash;
        action.reasonURI = "ipfs://reason";
        action.manifestHash = keccak256("manifest");
        _publish(_calls());
    }

    function _environment() private view returns (A.Environment memory) {
        return A.Environment(
            address(registry), address(executor), address(executor).codehash, address(executor)
        );
    }

    function _calls() private view returns (GovernanceCall[] memory calls) {
        calls = new GovernanceCall[](2);
        calls[0] = GovernanceCall(
            address(0x2222),
            0,
            bytes4(0x12345678),
            keccak256("preceding calldata"),
            keccak256("scope0"),
            keccak256("old0"),
            keccak256("new0")
        );
        calls[1] = GovernanceCall(
            address(registry),
            0,
            IStreamArtistIdentityRecovery.recoverArtistIdentity.selector,
            keccak256(
                abi.encodeCall(
                    IStreamArtistIdentityRecovery.recoverArtistIdentity, (request, acceptance)
                )
            ),
            context.scopeHash,
            context.oldValueHash,
            context.newValueHash
        );
    }

    function _publish(GovernanceCall[] memory calls) private {
        action.target = calls[0].target;
        action.selector = calls[0].selector;
        action.callHash = keccak256(
            abi.encode(
                bytes32(0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70), calls
            )
        );
        executor.set(action);
    }

    function probe(GovernanceCall[] calldata calls) external view returns (A.Witness memory) {
        return Reads.prepare(_environment(), ID, calls, request, acceptance, context);
    }

    function testExactCompleteBatchAndLongHeader() public {
        bytes memory uri = new bytes(2048);
        for (uint256 i; i < uri.length; ++i) {
            uri[i] = bytes1(uint8(65 + i % 26));
        }
        action.reasonURI = string(uri);
        _publish(_calls());
        A.Witness memory w = this.probe(_calls());
        require(
            w.actionId == ID && w.callsHash == action.callHash && w.callIndex == 1
                && w.callDataHash == _calls()[1].callDataHash,
            "complete second call"
        );
        require(
            w.proposer == action.proposer && w.roleRevision == 3
                && w.roleMutationHash == keccak256("roles")
                && w.manifestHash == action.manifestHash,
            "stored governance"
        );
        require(
            w.notBefore == action.notBefore && w.expiresAfter == action.expiresAfter
                && w.minimumDelay == 72 hours && w.executorCodeHash == address(executor).codehash,
            "timing and pin"
        );
    }

    function testBatchMembershipCardinalityAndExactCalldata() public {
        GovernanceCall[] memory calls = _calls();
        calls[0].callDataHash = keccak256("different prefix");
        vm.expectRevert();
        this.probe(calls);
        calls = _calls();
        calls[0] = calls[1];
        _publish(calls);
        vm.expectRevert();
        this.probe(calls);
        calls = _calls();
        calls[1].target = address(executor);
        _publish(calls);
        vm.expectRevert();
        this.probe(calls);
        calls = _calls();
        calls[1].value = 1;
        _publish(calls);
        vm.expectRevert();
        this.probe(calls);
        calls = _calls();
        calls[1].callDataHash = keccak256("trailing or alternate recovery bytes");
        _publish(calls);
        vm.expectRevert();
        this.probe(calls);
        calls = _calls();
        calls[1].newValueHash = keccak256("wrong context");
        _publish(calls);
        vm.expectRevert();
        this.probe(calls);
        calls = _calls();
        _publish(calls);
        this.probe(calls);
    }

    function testWholeRemainingDelayAndAcceptanceDeadline() public {
        this.probe(_calls());
        vm.warp(block.timestamp + 1);
        vm.expectRevert();
        this.probe(_calls());
        action.notBefore = uint64(block.timestamp + 73 hours);
        action.expiresAfter = action.notBefore;
        _publish(_calls());
        executor.controls(73 hours, true, true);
        this.probe(_calls());
        executor.controls(74 hours, true, true);
        vm.expectRevert();
        this.probe(_calls());
        executor.controls(72 hours, true, true);
        acceptance.time = action.notBefore - 1;
        _publish(_calls());
        vm.expectRevert();
        this.probe(_calls());
        acceptance.time = action.notBefore;
        _publish(_calls());
        this.probe(_calls());
    }

    function testUnsealedRoleAndMalformedGovernanceReject() public {
        executor.controls(72 hours, false, true);
        vm.expectRevert();
        this.probe(_calls());
        executor.controls(72 hours, true, false);
        vm.expectRevert();
        this.probe(_calls());
        executor.controls(72 hours, true, true);
        executor.malformed(true, false);
        vm.expectRevert();
        this.probe(_calls());
        executor.malformed(false, true);
        vm.expectRevert();
        this.probe(_calls());
        executor.malformed(false, false);
        action.reasonHash = keccak256("different stored reason");
        _publish(_calls());
        vm.expectRevert();
        this.probe(_calls());
        action.reasonHash = request.reasonHash;
        _publish(_calls());
        this.probe(_calls());
    }

    function testScheduledVetoWindowAndTerminalReplacementBoundary() public {
        A.Witness memory w = this.probe(_calls());
        require(!Reads.terminal(w), "live");
        vm.warp(w.notBefore);
        Reads.requireScheduled(w);
        require(!Reads.terminal(w), "ready remains live");
        vm.warp(w.expiresAfter);
        Reads.requireScheduled(w);
        require(!Reads.terminal(w), "expiry equality remains live");
        vm.warp(uint256(w.expiresAfter) + 1);
        require(Reads.terminal(w), "authoritative expired timestamp");
        executor.status(GovernanceActionStatus.CANCELLED);
        require(Reads.terminal(w), "cancelled");
        vm.expectRevert();
        Reads.requireScheduled(w);
        executor.status(GovernanceActionStatus.VETOED);
        require(Reads.terminal(w), "independent veto");
    }

    function testExecutedActionAndImmutableFactsRemainExact() public {
        A.Witness memory w = this.probe(_calls());
        vm.expectRevert();
        Reads.requireExecuted(w);
        executor.status(GovernanceActionStatus.EXECUTED);
        vm.expectRevert();
        Reads.requireExecuted(w);
        vm.warp(w.notBefore);
        Reads.requireExecuted(w);
        require(Reads.terminal(w), "executed terminal");
        action.status = GovernanceActionStatus.EXECUTED;
        action.expiresAfter++;
        executor.set(action);
        vm.expectRevert();
        Reads.requireExecuted(w);
        executor.set(action);
        w.executorCodeHash = keccak256("wrong pinned code");
        vm.expectRevert(
            abi.encodeWithSelector(A.RecoveryActionDependencyChanged.selector, address(executor))
        );
        Reads.requireScheduled(w);
    }
}
