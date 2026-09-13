// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/finality/StreamFinalityGovernanceWitness.sol";

/// @dev Raw response doubles exercise the bounded ABI boundary, not canonical governance lifecycle.
contract FinalityWitnessBoundary {
    mapping(bytes4 => bytes) private _replies;

    function reply(bytes4 selector, bytes memory value) external {
        _replies[selector] = value;
    }

    function execute(address target, bytes memory data, uint256 callGas)
        external
        returns (bool ok, bytes memory result)
    {
        return target.call{ gas: callGas }(data);
    }

    fallback() external {
        bytes memory result = _replies[msg.sig];
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
    }
}

contract FinalityWitnessHost {
    address private immutable _executor;
    bytes32 private immutable _executorHash;
    address private immutable _roles;
    bytes32 private immutable _rolesHash;
    uint256 private immutable _readGas;
    bytes32 public lastWitness;
    uint256 public writes;

    constructor(address executor_, address roles_, uint256 readGas_) {
        _executor = executor_;
        _executorHash = executor_.codehash;
        _roles = roles_;
        _rolesHash = roles_.codehash;
        _readGas = readGas_;
    }

    function accept(StreamFinalityExecutionContext calldata context)
        external
        returns (StreamFinalityExecutionWitness memory result)
    {
        StreamFinalityGovernanceWitness.Pins memory pins =
            StreamFinalityGovernanceWitness.Pins(_executor, _executorHash, _roles, _rolesHash);
        result = StreamFinalityGovernanceWitness.requireExecution(pins, context, _readGas);
        lastWitness = keccak256(abi.encode(result));
        ++writes;
    }
}

contract StreamFinalityGovernanceWitnessTest {
    FinalityWitnessBoundary private _executor;
    FinalityWitnessBoundary private _roles;
    FinalityWitnessHost private _host;
    bytes32 private constant ACTION = keccak256("actual active action");
    address private constant PROPOSER = address(0xabc);
    bytes32 private constant REASON = keccak256("recorded reason");
    bytes32 private constant MUTATION = keccak256("current role mutation");

    function setUp() public {
        _executor = new FinalityWitnessBoundary();
        _roles = new FinalityWitnessBoundary();
        _host = new FinalityWitnessHost(address(_executor), address(_roles), 200_000);
        _restore();
    }

    function testWitnessUsesStoredProposerAndActiveCallNotBatchFirstCall() public {
        GovernanceAction memory action = _action();
        // These are valid first-call/batch facts, deliberately unrelated to this active call.
        action.target = address(0x123);
        action.selector = bytes4(0x10203040);
        action.scopeHash = keccak256("aggregate scope");
        action.oldValueHash = keccak256("first old");
        action.newValueHash = keccak256("first new");
        action.executor = address(0x987);
        action.reasonURI = string(new bytes(1025));
        _executor.reply(IStreamGovernanceReads.governanceAction.selector, abi.encode(action));
        _healthy(_host);
        StreamFinalityExecutionWitness memory expected =
            StreamFinalityExecutionWitness(ACTION, PROPOSER, REASON, MUTATION, 7);
        require(_host.lastWitness() == keccak256(abi.encode(expected)), "recorded witness");
        require(_host.writes() == 1, "one admitted write");
    }

    function testWitnessDirectCallerAndLiveRoleRevocationRestore() public {
        (bool ok, bytes memory result) = address(_host).call(_callData());
        require(!ok, "direct caller accepted");
        _exact(
            result,
            abi.encodeWithSelector(
                StreamFinalityGovernanceWitness.FinalityExecutorOnly.selector, address(this)
            )
        );
        _roles.reply(IStreamRoleRegistry.hasRole.selector, abi.encode(false));
        _reject(
            abi.encodeWithSelector(
                StreamFinalityGovernanceWitness.FinalityProposerRoleMissing.selector, PROPOSER
            )
        );
        _roles.reply(IStreamRoleRegistry.hasRole.selector, abi.encode(true));
        _healthy(_host);
    }

    function testWitnessRejectsEveryMalformedCurrentContextWithSameContextRetry() public {
        uint256[6] memory invalid = [uint256(2), 0, 1, 19, 20, 21];
        for (uint256 i; i < invalid.length; ++i) {
            bytes memory raw = _contextBytes();
            _setWord(raw, i, invalid[i]);
            _executor.reply(IStreamGovernanceReads.currentAction.selector, raw);
            _reject(
                abi.encodeWithSelector(
                    StreamFinalityGovernanceWitness.FinalityGovernanceContextInvalid.selector
                )
            );
            _executor.reply(IStreamGovernanceReads.currentAction.selector, _contextBytes());
            _healthy(_host);
        }
        bytes memory healthy = _contextBytes();
        _executor.reply(
            IStreamGovernanceReads.currentAction.selector, bytes.concat(healthy, bytes32(0))
        );
        _reject(
            abi.encodeWithSelector(
                StreamFinalityGovernanceWitness.FinalityGovernanceReadFailed.selector,
                address(_executor)
            )
        );
        _executor.reply(IStreamGovernanceReads.currentAction.selector, healthy);
        _healthy(_host);
    }

    function testWitnessRejectsMalformedStoredActionHeadersAndRestoresSameAction() public {
        uint256[10] memory indices = [uint256(0), 1, 2, 3, 5, 10, 11, 12, 17, 19];
        uint256[10] memory invalid = [
            uint256(64),
            1,
            1,
            uint256(1) << 160,
            1,
            uint256(1) << 64,
            uint256(1) << 64,
            uint256(1) << 160,
            608,
            type(uint256).max
        ];
        for (uint256 i; i < indices.length; ++i) {
            bytes memory raw = abi.encode(_action());
            _setWord(raw, indices[i], invalid[i]);
            _executor.reply(IStreamGovernanceReads.governanceAction.selector, raw);
            _reject(
                abi.encodeWithSelector(
                    StreamFinalityGovernanceWitness.FinalityGovernanceContextInvalid.selector
                )
            );
            _executor.reply(IStreamGovernanceReads.governanceAction.selector, abi.encode(_action()));
            _healthy(_host);
        }
        _executor.reply(IStreamGovernanceReads.governanceAction.selector, new bytes(639));
        _reject(
            abi.encodeWithSelector(
                StreamFinalityGovernanceWitness.FinalityGovernanceReadFailed.selector,
                address(_executor)
            )
        );
        _executor.reply(IStreamGovernanceReads.governanceAction.selector, abi.encode(_action()));
        _healthy(_host);
    }

    function testWitnessOwnerRegistryAndCanonicalRoleWordsFailClosedThenRestore() public {
        _roles.reply(IStreamFinalityGovernanceBindings.owner.selector, abi.encode(address(this)));
        _rejectContext();
        _restore();
        _healthy(_host);
        _executor.reply(
            IStreamFinalityGovernanceBindings.roleRegistry.selector, abi.encode(address(this))
        );
        _rejectContext();
        _restore();
        _healthy(_host);
        _roles.reply(
            IStreamFinalityGovernanceBindings.owner.selector,
            abi.encode(uint256(uint160(address(_executor))) | (uint256(1) << 160))
        );
        _rejectContext();
        _restore();
        _healthy(_host);
        _roles.reply(IStreamRoleRegistry.hasRole.selector, abi.encode(uint256(2)));
        _reject(
            abi.encodeWithSelector(
                StreamFinalityGovernanceWitness.FinalityProposerRoleMissing.selector, PROPOSER
            )
        );
        _restore();
        _healthy(_host);
        _roles.reply(
            IStreamRoleRegistry.roleMutationState.selector, abi.encode(MUTATION, uint256(1) << 64)
        );
        _rejectContext();
        _restore();
        _healthy(_host);
    }

    function testWitnessChildCapAndParentGasPreserveStateBeforeHealthyRetry() public {
        FinalityWitnessHost small = new FinalityWitnessHost(address(_executor), address(_roles), 1);
        (bool ok, bytes memory result) = _executor.execute(address(small), _callData(), 1_000_000);
        require(!ok && small.writes() == 0, "small cap accepted");
        _exact(
            result,
            abi.encodeWithSelector(
                StreamFinalityGovernanceWitness.FinalityGovernanceReadFailed.selector,
                address(_executor)
            )
        );
        (ok, result) = _executor.execute(address(_host), _callData(), 120_000);
        require(!ok && _host.writes() == 0, "parent gas accepted");
        require(result.length == 68, "parent error shape");
        bytes4 selector;
        assembly ("memory-safe") { selector := mload(add(result, 32)) }
        require(
            selector == StreamFinalityGovernanceWitness.FinalityGovernanceParentGas.selector,
            "parent error selector"
        );
        _healthy(_host);
    }

    function _restore() private {
        _executor.reply(
            IStreamFinalityGovernanceBindings.roleRegistry.selector, abi.encode(address(_roles))
        );
        _executor.reply(IStreamGovernanceReads.currentAction.selector, _contextBytes());
        _executor.reply(IStreamGovernanceReads.governanceAction.selector, abi.encode(_action()));
        _roles.reply(
            IStreamFinalityGovernanceBindings.owner.selector, abi.encode(address(_executor))
        );
        _roles.reply(IStreamRoleRegistry.hasRole.selector, abi.encode(true));
        _roles.reply(
            IStreamRoleRegistry.roleMutationState.selector, abi.encode(MUTATION, uint64(7))
        );
    }

    function _context() private pure returns (StreamFinalityExecutionContext memory c) {
        c.scopeHash = keccak256("active scope");
        c.oldValueHash = keccak256("active old");
        c.newValueHash = keccak256("active new");
        c.finalityRecordHash = keccak256("finality record");
        c.coreFactsHash = keccak256("Core facts");
        c.componentsHash = keccak256("components");
        c.inputsHash = keccak256("inputs");
    }

    function _contextBytes() private pure returns (bytes memory) {
        StreamFinalityExecutionContext memory c = _context();
        return abi.encode(true, ACTION, uint8(2), c.scopeHash, c.oldValueHash, c.newValueHash);
    }

    function _action() private pure returns (GovernanceAction memory a) {
        a.status = GovernanceActionStatus.EXECUTED;
        a.actionClass = 2;
        a.proposer = PROPOSER;
        a.reasonHash = REASON;
    }

    function _callData() private pure returns (bytes memory) {
        return abi.encodeCall(FinalityWitnessHost.accept, (_context()));
    }

    function _healthy(FinalityWitnessHost host) private {
        uint256 before_ = host.writes();
        (bool ok, bytes memory result) = _executor.execute(address(host), _callData(), 2_000_000);
        require(ok, "healthy rejected");
        StreamFinalityExecutionWitness memory witness =
            abi.decode(result, (StreamFinalityExecutionWitness));
        require(witness.actionId == ACTION && witness.proposer == PROPOSER, "healthy provenance");
        require(host.writes() == before_ + 1, "healthy commit");
    }

    function _rejectContext() private {
        _reject(
            abi.encodeWithSelector(
                StreamFinalityGovernanceWitness.FinalityGovernanceContextInvalid.selector
            )
        );
    }

    function _reject(bytes memory expected) private {
        uint256 before_ = _host.writes();
        bytes32 previous = _host.lastWitness();
        (bool ok, bytes memory result) = _executor.execute(address(_host), _callData(), 2_000_000);
        require(!ok, "negative accepted");
        _exact(result, expected);
        require(
            _host.writes() == before_ && _host.lastWitness() == previous, "negative changed state"
        );
    }

    function _exact(bytes memory result, bytes memory expected) private pure {
        require(keccak256(result) == keccak256(expected), "exact error mismatch");
    }

    function _setWord(bytes memory value, uint256 index, uint256 word) private pure {
        assembly ("memory-safe") { mstore(add(add(value, 32), mul(index, 32)), word) }
    }
}
