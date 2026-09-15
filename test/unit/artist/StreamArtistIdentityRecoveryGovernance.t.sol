// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistIdentityRecoveryGovernance as G
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityRecoveryGovernance.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamGovernanceReads
} from "../../../smart-contracts/interfaces/stream/governance/IStreamGovernanceReads.sol";
import {
    IStreamRoleRegistry
} from "../../../smart-contracts/interfaces/stream/governance/IStreamRoleRegistry.sol";
import {
    GovernanceAction,
    GovernanceActionStatus
} from "../../../smart-contracts/interfaces/stream/governance/StreamGovernanceTypes.sol";

/// @dev Typed and raw governance responses; this is not actual scheduling or guardian execution.
contract IdentityRecoveryGovernanceBoundary {
    mapping(bytes4 => bytes) private replies;

    function set(bytes4 selector, bytes memory value) external {
        replies[selector] = value;
    }

    fallback() external {
        bytes memory value = replies[msg.sig];
        assembly ("memory-safe") { return(add(value, 32), mload(value)) }
    }
}

contract StreamArtistIdentityRecoveryGovernanceTest {
    IdentityRecoveryGovernanceBoundary private executor;
    IdentityRecoveryGovernanceBoundary private roles;
    bytes32 private constant ACTION = bytes32(uint256(0xaa));
    bytes32 private constant REASON = bytes32(uint256(0xbb));
    address private constant PROPOSER = address(0xcc);

    function setUp() public {
        executor = new IdentityRecoveryGovernanceBoundary();
        roles = new IdentityRecoveryGovernanceBoundary();
        _restore();
    }

    function _context() private pure returns (Recovery.Context memory c) {
        c.scopeHash = bytes32(uint256(0x11));
        c.oldValueHash = bytes32(uint256(0x22));
        c.newValueHash = bytes32(uint256(0x33));
    }

    function _bootstrap(uint256 bound, uint256 seal) private pure returns (bytes memory) {
        bytes32[29] memory w;
        w[0] = bytes32(bound);
        w[1] = bytes32(seal);
        return abi.encode(w);
    }

    function _action(uint8 classId) private pure returns (GovernanceAction memory a) {
        a.status = GovernanceActionStatus.EXECUTED;
        a.actionClass = classId;
        a.target = address(0xdead);
        a.selector = bytes4(0x01020304);
        a.scopeHash = bytes32(uint256(0xffff));
        a.oldValueHash = bytes32(uint256(0xeeee));
        a.newValueHash = bytes32(uint256(0xdddd));
        a.proposer = PROPOSER;
        a.reasonHash = REASON;
        a.reasonURI = string(new bytes(2048));
    }

    function _setClass(uint8 classId) private {
        Recovery.Context memory c = _context();
        executor.set(
            IStreamGovernanceReads.currentAction.selector,
            abi.encode(true, ACTION, classId, c.scopeHash, c.oldValueHash, c.newValueHash)
        );
        executor.set(IStreamGovernanceReads.governanceAction.selector, abi.encode(_action(classId)));
    }

    function _restore() private {
        executor.set(IStreamGovernanceReads.systemManifestBootstrapState.selector, _bootstrap(1, 1));
        executor.set(bytes4(keccak256("roleRegistry()")), abi.encode(address(roles)));
        _setClass(2);
        roles.set(IStreamRoleRegistry.hasRole.selector, abi.encode(true));
        roles.set(
            IStreamRoleRegistry.roleMutationState.selector,
            abi.encode(bytes32(uint256(0x44)), uint64(7))
        );
    }

    function observe(address actor, bytes32 reason)
        external
        view
        returns (Contest.GovernanceWitness memory)
    {
        D.CoordinatorContext memory x;
        x.suite.roleRegistry = address(roles);
        return G.read(x, address(executor), actor, reason, _context());
    }

    function _healthy() private view {
        Contest.GovernanceWitness memory g = this.observe(address(executor), REASON);
        Recovery.Context memory c = _context();
        require(g.actionId == ACTION && g.actionClass == 2 && g.proposer == PROPOSER);
        require(
            g.scopeHash == c.scopeHash && g.oldValueHash == c.oldValueHash
                && g.newValueHash == c.newValueHash
        );
        require(g.roleRevision == 7 && g.roleMutationHash == bytes32(uint256(0x44)));
    }

    function _reject(bytes memory expected) private view {
        (bool ok, bytes memory result) =
            address(this).staticcall(abi.encodeCall(this.observe, (address(executor), REASON)));
        require(!ok && keccak256(result) == keccak256(expected), "exact governance error");
    }

    function testSealedTerminalUsesOriginalProposerAndCurrentCall() public view {
        _healthy();
    }

    function testBoundAndSealMustBothBeCanonicalTrue() public {
        uint256[4] memory bad = [uint256(0), 2, 256, type(uint256).max];
        for (uint256 i; i < bad.length; ++i) {
            executor.set(
                IStreamGovernanceReads.systemManifestBootstrapState.selector, _bootstrap(bad[i], 1)
            );
            _reject(abi.encodeWithSelector(Recovery.InvalidIdentityRecoveryGovernance.selector));
            executor.set(
                IStreamGovernanceReads.systemManifestBootstrapState.selector, _bootstrap(1, bad[i])
            );
            _reject(abi.encodeWithSelector(Recovery.InvalidIdentityRecoveryGovernance.selector));
        }
        _restore();
        _healthy();
    }

    function testCompleteBootstrapLengthRequiredAndRestored() public {
        bytes memory healthy = _bootstrap(1, 1);
        executor.set(
            IStreamGovernanceReads.systemManifestBootstrapState.selector, abi.encode(true, true)
        );
        _reject(abi.encodeWithSelector(Recovery.InvalidIdentityRecoveryGovernance.selector));
        executor.set(
            IStreamGovernanceReads.systemManifestBootstrapState.selector,
            bytes.concat(healthy, bytes32(0))
        );
        _reject(abi.encodeWithSelector(Recovery.InvalidIdentityRecoveryGovernance.selector));
        executor.set(IStreamGovernanceReads.systemManifestBootstrapState.selector, new bytes(0));
        _reject(abi.encodeWithSelector(Recovery.InvalidIdentityRecoveryGovernance.selector));
        _restore();
        _healthy();
    }

    function testOtherClassesCannotSubstituteForTerminalFreeze() public {
        _setClass(1);
        _reject(abi.encodeWithSelector(Recovery.InvalidIdentityRecoveryGovernance.selector));
        _setClass(3);
        _reject(abi.encodeWithSelector(Contest.InvalidContestGovernance.selector));
        _setClass(0);
        _reject(abi.encodeWithSelector(Contest.InvalidContestGovernance.selector));
        _restore();
        _healthy();
    }

    function testWrongActorMissingReasonAndRevokedProposerFail() public {
        (bool ok, bytes memory result) =
            address(this).staticcall(abi.encodeCall(this.observe, (address(this), REASON)));
        require(
            !ok
                && keccak256(result)
                    == keccak256(
                        abi.encodeWithSelector(Recovery.InvalidIdentityRecoveryGovernance.selector)
                    )
        );
        (ok, result) =
            address(this).staticcall(abi.encodeCall(this.observe, (address(executor), bytes32(0))));
        require(
            !ok
                && keccak256(result)
                    == keccak256(
                        abi.encodeWithSelector(Recovery.InvalidIdentityRecoveryGovernance.selector)
                    )
        );
        roles.set(IStreamRoleRegistry.hasRole.selector, abi.encode(false));
        _reject(abi.encodeWithSelector(T.Unauthorized.selector, PROPOSER));
        _restore();
        _healthy();
    }

    function testStoredStatusReasonAndActualContextRemainRequired() public {
        GovernanceAction memory a = _action(2);
        a.status = GovernanceActionStatus.VETOED;
        executor.set(IStreamGovernanceReads.governanceAction.selector, abi.encode(a));
        _reject(abi.encodeWithSelector(Contest.InvalidContestGovernance.selector));
        a = _action(2);
        a.reasonHash = bytes32(uint256(1));
        executor.set(IStreamGovernanceReads.governanceAction.selector, abi.encode(a));
        _reject(abi.encodeWithSelector(Contest.InvalidContestGovernance.selector));
        _restore();
        Recovery.Context memory c = _context();
        executor.set(
            IStreamGovernanceReads.currentAction.selector,
            abi.encode(true, ACTION, uint8(2), c.scopeHash, c.oldValueHash, bytes32(uint256(5)))
        );
        _reject(abi.encodeWithSelector(Contest.InvalidContestGovernance.selector));
        _restore();
        _healthy();
    }
}
