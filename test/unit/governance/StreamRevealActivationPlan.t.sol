// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../script/current/StreamRevealActivationPlan.sol";
import "../../../smart-contracts/domains/governance/StreamRoleRegistry.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";

/// @dev Explicit execution-context fixture; the actual Executor is covered by current-stack tests.
contract RevealPlanExecutorFixture {
    GovernanceAction private action;
    GovernanceCall private current;
    bool private executing;
    uint256 public executions;
    StreamRoleRegistry public roles;
    bytes32 private constant ID = keccak256("reveal plan action");

    function initialize() external {
        require(address(roles) == address(0), "initialize once after executor has code");
        roles = new StreamRoleRegistry(address(this));
    }

    function admit(StreamArtistActivationPlan.Plan memory plan) external {
        action.status = GovernanceActionStatus.SCHEDULED;
        action.actionClass = 1;
        action.callHash = StreamGovernanceBootstrap.governanceCallsHash(plan.calls);
        action.scopeHash = plan.scopeHash;
        action.oldValueHash = plan.oldValueHash;
        action.newValueHash = plan.newValueHash;
    }

    function governanceAction(bytes32 id) external view returns (GovernanceAction memory) {
        require(id == ID, "saved identity");
        return action;
    }

    function currentAction()
        external
        view
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return (executing, ID, 1, current.scopeHash, current.oldValueHash, current.newValueHash);
    }

    function executeGovernanceBatch(bytes32 id, GovernanceCall[] memory calls, bytes[] memory data)
        external
    {
        require(
            id == ID && action.status == GovernanceActionStatus.SCHEDULED
                && StreamGovernanceBootstrap.governanceCallsHash(calls) == action.callHash,
            "saved calls"
        );
        for (uint256 i; i < calls.length; ++i) {
            _call(calls[i], data[i]);
        }
        action.status = GovernanceActionStatus.EXECUTED;
        ++executions;
    }

    function _call(GovernanceCall memory call_, bytes memory data) private {
        current = call_;
        executing = true;
        require(call_.callDataHash == keccak256(data), "exact calldata");
        (bool ok, bytes memory result) = call_.target.call(data);
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        executing = false;
    }

    /// @dev Model an independently completed governed grant against the actual registry.
    function grantOne(bytes32 role, address holder) external {
        (bytes32 roleChain, uint64 roleRevision) = roles.roleMutationState(role);
        (bytes32 globalChain, uint64 globalRevision) = roles.globalRoleMutationState();
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_SCOPE_V1"),
                block.chainid,
                address(roles),
                role,
                holder
            )
        );
        bytes32 old_ = _state(scope, false, roleChain, roleRevision, globalChain, globalRevision);
        roleChain = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_V1"),
                roleChain,
                block.chainid,
                address(roles),
                role,
                holder,
                true,
                roleRevision + 1
            )
        );
        globalChain = keccak256(
            abi.encode(
                keccak256("6529STREAM_GLOBAL_ROLE_MUTATION_V1"),
                globalChain,
                block.chainid,
                address(roles),
                role,
                holder,
                true,
                globalRevision + 1
            )
        );
        bytes memory data = abi.encodeCall(roles.grantRole, (role, holder));
        _call(
            GovernanceCall(
                address(roles),
                0,
                roles.grantRole.selector,
                keccak256(data),
                scope,
                old_,
                _state(scope, true, roleChain, roleRevision + 1, globalChain, globalRevision + 1)
            ),
            data
        );
    }

    function _state(
        bytes32 scope,
        bool granted,
        bytes32 roleChain,
        uint64 roleRevision,
        bytes32 globalChain,
        uint64 globalRevision
    ) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_STATE_V1"),
                block.chainid,
                address(roles),
                scope,
                granted,
                roleChain,
                roleRevision,
                globalChain,
                globalRevision
            )
        );
    }
}

/// @notice Planner regression tests use the actual role mutation and unique resolution semantics.
contract StreamRevealActivationPlanTest is CharacterizationTestBase {
    RevealPlanExecutorFixture private executor;
    StreamRoleRegistry private roles;
    StreamRevealActivationPlan.Principals private principals;
    bytes32 private constant ID = keccak256("reveal plan action");
    bytes32 private constant ADMIN = keccak256("ROLE_ENTROPY_ADMIN");
    bytes32 private constant OWNER = keccak256("ROLE_ENTROPY_REVEAL_OWNER");
    bytes32 private constant TREASURY = keccak256("ROLE_TREASURY");

    function setUp() public {
        executor = new RevealPlanExecutorFixture();
        executor.initialize();
        roles = executor.roles();
        principals =
            StreamRevealActivationPlan.Principals(address(this), address(this), address(this));
    }

    function testThreeGrantsExecuteAndResumeWithExactUniqueResolution() public {
        StreamArtistActivationPlan.Plan memory plan = _prepare();
        this.executePlan(plan);
        this.executePlan(plan);
        require(
            executor.executions() == 1 && roles.resolveRole(OWNER) == address(this)
                && roles.resolveRole(TREASURY) == address(this),
            "one execution with unique recipients"
        );
        (, uint64 revision) = roles.globalRoleMutationState();
        require(revision == 3, "canonical ordered mutations");
    }

    function testExistingRevealOwnerPreventsAPlanThatWouldCreateAmbiguity() public {
        executor.grantOne(OWNER, address(executor));
        vm.expectRevert(
            abi.encodeWithSelector(StreamRevealActivationPlan.InvalidRevealActivationPlan.selector)
        );
        this.buildPlan();
        require(
            roles.resolveRole(OWNER) == address(executor) && roles.roleHolderCount(ADMIN) == 0,
            "planning cannot change existing roles"
        );
    }

    function testExistingTreasuryPreventsAPlanThatWouldCreateAmbiguity() public {
        executor.grantOne(TREASURY, address(executor));
        vm.expectRevert(
            abi.encodeWithSelector(StreamRevealActivationPlan.InvalidRevealActivationPlan.selector)
        );
        this.buildPlan();
        require(
            roles.resolveRole(TREASURY) == address(executor) && roles.roleHolderCount(OWNER) == 0,
            "existing treasury remains unique"
        );
    }

    function testStaleGlobalMutationCannotPartiallyActivateSavedPlan() public {
        StreamArtistActivationPlan.Plan memory plan = _prepare();
        executor.grantOne(keccak256("ROLE_EXPORT_PUBLISHER"), address(executor));
        (bytes32 chain, uint64 revision) = roles.globalRoleMutationState();
        bytes32 expectedOld = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_STATE_V1"),
                block.chainid,
                address(roles),
                plan.calls[0].scopeHash,
                false,
                bytes32(0),
                uint64(0),
                chain,
                revision
            )
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRoleRegistry.RoleGovernanceOldStateHashMismatch.selector,
                expectedOld,
                plan.calls[0].oldValueHash
            )
        );
        this.executePlan(plan);
        (bytes32 afterChain, uint64 afterRevision) = roles.globalRoleMutationState();
        require(
            chain == afterChain && revision == afterRevision && roles.roleHolderCount(ADMIN) == 0
                && roles.roleHolderCount(OWNER) == 0 && roles.roleHolderCount(TREASURY) == 0
                && executor.executions() == 0
                && executor.governanceAction(ID).status == GovernanceActionStatus.SCHEDULED,
            "stale plan changes no registry or action state"
        );
    }

    function testResumptionRejectsLaterAmbiguousTreasury() public {
        StreamArtistActivationPlan.Plan memory plan = _prepare();
        this.executePlan(plan);
        executor.grantOne(TREASURY, address(executor));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRevealActivationPlan.RevealActivationReadbackFailed.selector
            )
        );
        this.executePlan(plan);
        require(executor.executions() == 1, "resumption never executes a second batch");
    }

    function testResumptionRejectsLaterAmbiguousOwnerButAllowsMultipleAdministrators() public {
        StreamArtistActivationPlan.Plan memory plan = _prepare();
        this.executePlan(plan);
        executor.grantOne(ADMIN, address(executor));
        this.executePlan(plan);
        require(
            roles.roleHolderCount(ADMIN) == 2 && executor.executions() == 1,
            "administrators may be multiple"
        );
        executor.grantOne(OWNER, address(executor));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRevealActivationPlan.RevealActivationReadbackFailed.selector
            )
        );
        this.executePlan(plan);
    }

    function buildPlan() external view returns (StreamArtistActivationPlan.Plan memory) {
        return StreamRevealActivationPlan.build(roles, principals);
    }

    function executePlan(StreamArtistActivationPlan.Plan memory plan) external {
        require(msg.sender == address(this), "fixture only");
        StreamRevealActivationPlan.execute(
            IStreamGovernanceExecutor(address(executor)),
            roles,
            IStreamGasParameterHost(address(0)),
            address(0),
            principals,
            ID,
            plan
        );
    }

    function _prepare() private returns (StreamArtistActivationPlan.Plan memory plan) {
        plan = StreamRevealActivationPlan.build(roles, principals);
        executor.admit(plan);
    }
}
