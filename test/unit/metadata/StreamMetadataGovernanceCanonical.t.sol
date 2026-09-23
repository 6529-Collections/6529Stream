// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/StreamGovernanceBootstrapHarness.sol";
import "../../../smart-contracts/domains/metadata/StreamMetadataGovernance.sol";

/// @dev A minimal host of the actual hardwired guard, not the complete metadata host.
contract MetadataGuardHost {
    address public immutable executor;
    bytes32 public immutable executorCodeHash;
    mapping(address => bool) public admitted;
    bytes32 public lastAction;

    constructor(address executor_) {
        executor = executor_;
        executorCodeHash = executor_.codehash;
    }

    function transition(address account, bool enabled)
        public view returns (bytes32 scope, bytes32 oldHash, bytes32 newHash)
    {
        scope = StreamMetadataGovernance.configurationScope(
            executor, executorCodeHash, 150000, keccak256(abi.encode("review family", account))
        );
        oldHash = keccak256(abi.encode(admitted[account]));
        newHash = keccak256(abi.encode(enabled));
    }

    function configure(address account, bool enabled) external {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = transition(account, enabled);
        lastAction = StreamMetadataGovernance.requireTransition(
            executor, executorCodeHash, 150000, scope, oldHash, newHash
        );
        admitted[account] = enabled;
    }
}

/// @dev Real sealed Executor/RoleRegistry. Core, registry inventory and manifest remain
/// explicit bootstrap fixtures. No Safe, full metadata publisher or cold-gas claim.
contract StreamMetadataGovernanceCanonicalTest is StreamGovernanceBootstrapHarness {
    BootstrapArtifacts private b;
    MetadataGuardHost private host;
    StreamGovernanceBootstrapTriggerMock private first;

    function _additionalActionPolicies(BootstrapArtifacts memory a)
        internal override returns (GovernanceActionPolicyEntry[] memory rows)
    {
        host = new MetadataGuardHost(address(a.executor));
        first = new StreamGovernanceBootstrapTriggerMock();
        rows = new GovernanceActionPolicyEntry[](2);
        rows[0] = _zeroPolicy(1, address(host), host.configure.selector, keccak256("review guarded host"));
        rows[1] = _zeroPolicy(1, address(first), first.bootstrapWrite.selector, keccak256("review prefix"));
    }

    function setUp() public {
        vm.warp(1000);
        b = _deploySealedExecutor(address(this));
        require(address(b.executor.roleRegistry()) == address(b.roleRegistry), "actual bound roles");
        require(b.roleRegistry.owner() == address(b.executor), "actual permanent role owner");
        (address root, bytes32 rootHash, uint64 rev) = b.executor.governanceRootState();
        require(root == address(this) && rootHash == address(this).codehash && rev == 1, "actual root state");
    }

    function nowTimestamp() external view returns (uint256) { return block.timestamp; }

    function _call(address target, bytes memory data, bytes32 scope, bytes32 oldHash, bytes32 newHash)
        private pure returns (GovernanceCall memory)
    {
        return GovernanceCall(target, 0, bytes4(data), keccak256(data), scope, oldHash, newHash);
    }

    function _hashes(GovernanceCall[] memory calls)
        private pure returns (bytes32 scope, bytes32 oldHash, bytes32 newHash)
    {
        bytes32 callHash = keccak256(abi.encode(GOVERNANCE_CALLS_V2, calls));
        bytes32[] memory scopes = new bytes32[](calls.length);
        bytes32[] memory oldValues = new bytes32[](calls.length);
        bytes32[] memory newValues = new bytes32[](calls.length);
        for (uint256 i; i < calls.length; ++i) {
            scopes[i] = calls[i].scopeHash;
            oldValues[i] = calls[i].oldValueHash;
            newValues[i] = calls[i].newValueHash;
        }
        return (keccak256(abi.encode(BATCH_SCOPE_V2, callHash, scopes)),
            keccak256(abi.encode(BATCH_OLD_STATE_V2, callHash, oldValues)),
            keccak256(abi.encode(BATCH_NEW_STATE_V2, callHash, newValues)));
    }

    function _schedule(address proposer, GovernanceCall[] memory calls, bytes[] memory data, string memory uri)
        private returns (bytes32 actionId, uint64 notBefore)
    {
        b.executor.publishGovernanceCallData(data);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = _hashes(calls);
        notBefore = uint64(this.nowTimestamp() + 48 hours);
        bytes32 manifest = b.manifestHash;
        StreamGovernanceExecutor executor = b.executor;
        vm.prank(proposer);
        actionId = executor.scheduleGovernanceBatch(
            1, calls, scope, oldHash, newHash, notBefore, notBefore + 7 days,
            keccak256(bytes(uri)), uri, manifest
        );
    }

    function _registration(address proposer) private {
        bytes32 kind = keccak256("6529STREAM_GOVERNANCE_CONFIG_PROPOSER");
        (bool enabled, uint64 rev, bytes32 oldHash) = b.executor.proposerConfig(proposer);
        require(!enabled && rev == 0, "new proposer");
        bytes32 scope = keccak256(abi.encode(
            keccak256("6529STREAM_GOVERNANCE_CONFIG_SCOPE_V1"), block.chainid, address(b.executor), kind, proposer
        ));
        bytes32 newHash = keccak256(abi.encode(
            keccak256("6529STREAM_GOVERNANCE_CONFIG_STATE_V1"), block.chainid, address(b.executor), kind, proposer, true, uint64(1)
        ));
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(b.executor.registerProposer, (proposer, true));
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        calls[0] = _call(address(b.executor), data[0], scope, oldHash, newHash);
        (bytes32 actionId, uint64 notBefore) = _schedule(address(this), calls, data, "ipfs://review-proposer-admission");
        vm.warp(notBefore);
        b.executor.executeGovernanceBatch(actionId, calls, data);
        require(b.executor.isProposer(proposer), "actual proposer admitted through delayed root action");
    }

    function _batch(address account) private view returns (GovernanceCall[] memory calls, bytes[] memory data) {
        calls = new GovernanceCall[](2);
        data = new bytes[](2);
        data[0] = abi.encodeCall(first.bootstrapWrite, (99));
        calls[0] = _call(address(first), data[0], keccak256("prefix scope"), keccak256("prefix old"), keccak256("prefix new"));
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = host.transition(account, true);
        data[1] = abi.encodeCall(host.configure, (account, true));
        calls[1] = _call(address(host), data[1], scope, oldHash, newHash);
    }

    function _executeLow(bytes32 id, GovernanceCall[] memory calls, bytes[] memory data)
        private returns (bool ok, bytes memory reason)
    {
        return address(b.executor).call(abi.encodeCall(b.executor.executeGovernanceBatch, (id, calls, data)));
    }

    function _has(bytes memory reason, bytes memory needle) private pure returns (bool) {
        for (uint256 i; i + needle.length <= reason.length; ++i) {
            bool matches = true;
            for (uint256 j; j < needle.length; ++j) {
                if (reason[i + j] != needle[j]) { matches = false; break; }
            }
            if (matches) return true;
        }
        return false;
    }

    function testActualRegisteredProposerCannotSelfGrantAndRootRetriesSamePayload() public {
        address proposer = address(0xCAFE);
        _registration(proposer);
        (GovernanceCall[] memory calls, bytes[] memory data) = _batch(proposer);
        (bytes32 id, uint64 at) = _schedule(proposer, calls, data, "ipfs://review-non-root-self-grant");
        GovernanceAction memory action = b.executor.governanceAction(id);
        require(action.proposer == proposer && action.status == GovernanceActionStatus.SCHEDULED, "real scheduling admitted");
        vm.warp(at);
        (bool ok, bytes memory reason) = _executeLow(id, calls, data);
        require(!ok && _has(reason, abi.encodeWithSelector(IStreamCollectionMetadataV1.MetadataAuthorityRequired.selector)), "exact target authority rejection");
        require(!host.admitted(proposer) && host.lastAction() == 0 && first.value() == 0, "entire batch rolled back");
        action = b.executor.governanceAction(id);
        require(action.status == GovernanceActionStatus.SCHEDULED && action.executor == address(0), "execution receipt rollback");
        (bytes32 healthyId, uint64 healthyAt) = _schedule(address(this), calls, data, "ipfs://review-root-identical-payload");
        vm.warp(healthyAt);
        b.executor.executeGovernanceBatch(healthyId, calls, data);
        require(host.admitted(proposer) && host.lastAction() == healthyId && first.value() == 99, "root same payload healthy");
    }

    function testActualRootSecondBatchElementUsesActiveContextAndBoundedLongReasonHeader() public {
        address account = address(0xD00D);
        (GovernanceCall[] memory calls, bytes[] memory data) = _batch(account);
        bytes memory uri = new bytes(2000);
        for (uint256 i; i < uri.length; ++i) uri[i] = 0x61;
        bytes memory prefix = bytes("ipfs://");
        for (uint256 i; i < prefix.length; ++i) uri[i] = prefix[i];
        (bytes32 id, uint64 at) = _schedule(address(this), calls, data, string(uri));
        GovernanceAction memory action = b.executor.governanceAction(id);
        require(action.target == address(first) && action.target != address(host) && action.selector == first.bootstrapWrite.selector, "stored header indexes first element only");
        vm.warp(at - 1);
        (bool early,) = _executeLow(id, calls, data);
        require(!early && !host.admitted(account) && first.value() == 0, "real delay enforced");
        vm.warp(at);
        b.executor.executeGovernanceBatch(id, calls, data);
        require(host.admitted(account) && host.lastAction() == id && first.value() == 99, "second element exact context succeeds");
        action = b.executor.governanceAction(id);
        require(action.status == GovernanceActionStatus.EXECUTED && keccak256(bytes(action.reasonURI)) == keccak256(uri), "actual variable length action ABI retained");
    }

    function testDirectRootCallCannotSubstituteForExecutingGovernanceContext() public {
        (bool ok, bytes memory reason) = address(host).call(abi.encodeCall(host.configure, (address(this), true)));
        require(!ok && keccak256(reason) == keccak256(abi.encodeWithSelector(IStreamCollectionMetadataV1.MetadataAuthorityRequired.selector)), "direct root is not executor");
        require(!host.admitted(address(this)) && host.lastAction() == 0, "no direct mutation");
    }
}
