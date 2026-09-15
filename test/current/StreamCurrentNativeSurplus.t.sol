// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamCurrentNativeSettlementTest } from "./StreamCurrentNativeSettlement.t.sol";
import { StreamCurrentDutchSaleTest } from "./StreamCurrentDutchSale.t.sol";
import { StreamCurrentClearingSaleTest } from "./StreamCurrentClearingSale.t.sol";
import { StreamCurrentRefundWindowTest } from "./StreamCurrentRefundWindow.t.sol";
import "../helpers/StreamCurrentSafeGovernanceFixture.sol";
import {
    IStreamNativeSurplus as NS
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeSurplus.sol";
import { StreamNativeSurplus } from "../../smart-contracts/domains/mint/StreamNativeSurplus.sol";
import {
    IStreamNativeFixedPriceSaleAdapter
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeFixedPriceSaleAdapter.sol";

import {
    StreamNativeEnglishAuction
} from "../../smart-contracts/domains/auctions/StreamNativeEnglishAuction.sol";
import {
    StreamPrivateSaleAdapter
} from "../../smart-contracts/domains/mint/StreamPrivateSaleAdapter.sol";
import {
    StreamPrimarySaleSettlement
} from "../../smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol";
import {
    IStreamNativeRefundDelegatedClaims as NR
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeRefundDelegatedClaims.sol";

interface SurplusCallVm {
    function expectCall(address, uint256, bytes calldata, uint64) external;
}

contract NativeSurplusForce {
    constructor(address payable receiver) payable {
        selfdestruct(receiver);
    }
}

contract NativeSurplusRecipient {
    bool public rejecting;
    uint256 public donation;
    address public target;
    bool public reentered;
    bytes public reentryData;

    function configure(bool fail, uint256 extra, address host, bytes calldata data) external {
        rejecting = fail;
        donation = extra;
        target = host;
        reentryData = data;
    }

    receive() external payable {
        require(!rejecting, "recipient unavailable");
        if (reentryData.length != 0) (reentered,) = target.call(reentryData);
        if (donation != 0) new NativeSurplusForce{ value: donation }(payable(target));
    }
}

/// @dev Actual Core/Registry/Executor/RoleRegistry/Safes and original ledgers. No mocked authority.
/// @dev One shared test probe operates the actual fixture's Executor, RoleRegistry and threshold Safe.
/// Keys and graph coordinates come only from the test fixture; no production state or authority is mocked.
contract NativeSurplusProbe is StreamCurrentSafeGovernanceFixture {
    constructor(
        StreamCore c,
        StreamModuleRegistry registry_,
        StreamGovernanceExecutor executor_,
        StreamRoleRegistry roles_,
        OfficialSafe account,
        uint256[] memory signingKeys
    ) {
        core = c;
        registry = registry_;
        executor = executor_;
        roles = roles_;
        governorSafe = account;
        governorKeys = signingKeys;
    }
    bytes32 internal constant SURPLUS_REASON = keccak256("recover unsolicited native surplus");
    bytes32 private constant EMERGENCY = keccak256("ROLE_EMERGENCY_RECIPIENT");
    SurplusCallVm private constant calls =
        SurplusCallVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _withSurplusPolicy(GovernanceActionPolicyEntry[] memory original, address host)
        internal
        view
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](original.length + 1);
        for (uint256 i; i < original.length; ++i) {
            rows[i] = original[i];
        }
        rows[original.length] = GovernanceActionPolicyEntry(
            1,
            host,
            NS.sweepNativeSurplus.selector,
            host.codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, host)),
            1,
            0,
            0,
            bytes32(0)
        );
    }

    function selectRecipient(address recipient) public {
        while (roles.roleHolderCount(EMERGENCY) != 0) {
            _setRole(EMERGENCY, roles.roleHolderAt(EMERGENCY, 0), false);
        }
        _setRole(EMERGENCY, recipient, true);
    }

    function fund(address host, uint256 amount) public {
        vm.deal(address(this), amount);
        new NativeSurplusForce{ value: amount }(payable(host));
    }

    function surplusTestNow() external view returns (uint256) {
        return block.timestamp;
    }

    function quoteRequest(NS host, NS.NativeSurplusQuote memory q)
        public
        view
        returns (GovernanceActionRequest memory request)
    {
        request = _governanceRequest(
            1,
            address(host),
            abi.encodeCall(NS.sweepNativeSurplus, (q.amount, q.reasonHash)),
            q.scopeHash,
            q.oldValueHash,
            q.newValueHash
        );
        request.notBefore = uint64(this.surplusTestNow() + executor.minimumDelay(1));
        request.expiresAfter = request.notBefore + 30 days;
    }

    function _assertQuote(NS host, NS.NativeSurplusQuote memory q, uint256 owed) internal view {
        require(
            q.state.liabilities == owed && q.state.available == 100
                && q.state.balance == owed + 100,
            "all tracked liabilities excluded"
        );
        StreamNativeSurplus.Context memory x = StreamNativeSurplus.Context(
            address(core),
            address(core).codehash,
            address(registry),
            address(registry).codehash,
            address(executor)
        );
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_SURPLUS_SCOPE_V1"), block.chainid, address(host), x
            )
        );
        bytes32 request = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_SURPLUS_REQUEST_V1"),
                q.amount,
                q.reasonHash,
                q.authority
            )
        );
        require(
            q.scopeHash == scope
                && q.oldValueHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_NATIVE_SURPLUS_STATE_V1"),
                            scope,
                            request,
                            owed,
                            uint64(0),
                            uint256(0)
                        )
                    )
                && q.newValueHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_NATIVE_SURPLUS_STATE_V1"),
                            scope,
                            request,
                            owed,
                            uint64(1),
                            q.amount
                        )
                    ),
            "independent scope and transition hashes"
        );
        (bytes32 chain, uint64 revision) = roles.roleMutationState(EMERGENCY);
        require(
            q.authority.executor == address(executor)
                && q.authority.executorCodeHash == address(executor).codehash
                && q.authority.roleRegistry == address(roles)
                && q.authority.roleRegistryCodeHash == address(roles).codehash
                && q.authority.recipient == roles.resolveRole(EMERGENCY)
                && q.authority.roleChainHash == chain && q.authority.roleRevision == revision,
            "actual canonical role witness"
        );
    }

    function sweepAndAssert(NS host, uint256 owed, bool donate) external {
        NativeSurplusRecipient recipient = new NativeSurplusRecipient();
        selectRecipient(address(recipient));
        fund(address(host), 100);
        NS.NativeSurplusQuote memory q = host.nativeSurplusQuote(60, SURPLUS_REASON);
        _assertQuote(host, q, owed);
        recipient.configure(
            false,
            donate ? 3 : 0,
            address(host),
            abi.encodeCall(NS.sweepNativeSurplus, (uint256(1), SURPLUS_REASON))
        );
        GovernanceActionRequest memory request = quoteRequest(host, q);
        bytes32 id = _scheduleAsGovernor(request);
        vm.warp(request.notBefore);
        vm.recordLogs();
        _executeAsGovernor(id, request.callData);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(host)
                    && logs[i].topics[0]
                        == keccak256("AdapterSurplusSwept(uint16,address,address,uint256,bytes32)")
            ) {
                ++found;
                require(
                    logs[i].topics.length == 2
                        && logs[i].topics[1] == bytes32(uint256(uint160(address(recipient)))),
                    "canonical indexed recipient"
                );
                require(
                    keccak256(logs[i].data)
                        == keccak256(abi.encode(uint16(1), address(0), uint256(60), id)),
                    "canonical unchanged event payload"
                );
            }
        }
        require(
            found == 1 && !recipient.reentered(), "one event and original guard covers callback"
        );
        NS.NativeSurplusState memory after_ = host.nativeSurplusState();
        require(
            after_.liabilities == owed && after_.available == (donate ? 43 : 40)
                && after_.balance == owed + after_.available && after_.revision == 1
                && after_.cumulativeSwept == 60 && after_.lastActionId == id
                && host.nativeSurplusActionUsed(id),
            "exact accounting and replay state"
        );
        require(address(recipient).balance == (donate ? 57 : 60), "only dynamic recipient paid");
    }

    function _serializeGovernor(address target, bytes memory data) internal returns (bytes memory) {
        bytes32 digest = governorSafe.getTransactionHash(
            target, 0, data, 0, 0, 0, 0, address(0), address(0), governorSafe.nonce()
        );
        return abi.encodeCall(
            OfficialSafe.execTransaction,
            (
                target,
                uint256(0),
                data,
                uint8(0),
                uint256(0),
                uint256(0),
                uint256(0),
                address(0),
                payable(address(0)),
                safeThresholdSignature(governorKeys, digest)
            )
        );
    }

    function lateRetry(NS host, uint256 owed) external {
        NativeSurplusRecipient recipient = new NativeSurplusRecipient();
        selectRecipient(address(recipient));
        fund(address(host), 100);
        NS.NativeSurplusQuote memory q = host.nativeSurplusQuote(100, SURPLUS_REASON);
        GovernanceActionRequest memory request = quoteRequest(host, q);
        bytes32 id = _scheduleAsGovernor(request);
        vm.warp(request.notBefore);
        recipient.configure(true, 0, address(host), bytes(""));
        bytes memory serialized = _serializeGovernor(
            address(executor),
            abi.encodeCall(executor.executeGovernanceAction, (id, request.callData))
        );
        uint256 nonce = governorSafe.nonce();
        calls.expectCall(address(recipient), 100, bytes(""), 2);
        (bool failed, bytes memory error) = address(governorSafe).call(serialized);
        require(
            !failed
                && keccak256(error) == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
            "actual failed Safe transaction"
        );
        NS.NativeSurplusState memory beforeRetry = host.nativeSurplusState();
        require(
            governorSafe.nonce() == nonce && beforeRetry.balance == owed + 100
                && beforeRetry.liabilities == owed && beforeRetry.revision == 0
                && beforeRetry.cumulativeSwept == 0 && beforeRetry.lastActionId == 0
                && !host.nativeSurplusActionUsed(id)
                && executor.governanceAction(id).status == GovernanceActionStatus.SCHEDULED,
            "failed callback rolls back money, host and governance replay"
        );
        recipient.configure(false, 0, address(host), bytes(""));
        (bool ok, bytes memory result) = address(governorSafe).call(serialized);
        require(
            ok && abi.decode(result, (bool)) && governorSafe.nonce() == nonce + 1
                && address(recipient).balance == 100,
            "byte-identical Safe transaction retries"
        );
        require(
            host.nativeSurplusState().balance == owed
                && host.nativeSurplusState().liabilities == owed
                && host.nativeSurplusActionUsed(id),
            "all liabilities remain funded"
        );
        (ok,) = address(governorSafe).call(serialized);
        require(!ok, "original signed transaction cannot replay");
    }
}

contract StreamCurrentFixedSurplusTest is StreamCurrentNativeSettlementTest {
    StreamNativeEnglishAuction private surplusHouse;
    StreamPrivateSaleAdapter private surplusPrivate;

    /// @dev Fresh hosts use the actual Core/Manager/Artist/Executor graph. They have no sale
    /// admission or liability yet: recovery of donated ETH does not grant sale authority.
    function _refundClaimDeployment() internal override returns (NR.DelegationDeployment memory) {
        StreamNativeEnglishAuction.DeploymentConfig memory d;
        d.manager = manager;
        d.recorder =
            new StreamPrimarySaleSettlement(primaryResolver, address(registry), revenueEscrow);
        d.platform = vm.addr(PLATFORM_KEY);
        d.artists = IStreamArtistAttribution(address(artists));
        d.entropy = IStreamRevealFeeEscrow(address(entropy));
        d.roles = roles;
        d.authority = address(executor);
        d.parameters[0] =
            IStreamGasParameterHost.GasParameterConfig("SALE_ERC1271_GAS_LIMIT", 400000, 350000, 2);
        d.parameters[1] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ARTIST_AUTHORITY_GAS_LIMIT", 300000, 50000, 2
        );
        d.parameters[2] = IStreamGasParameterHost.GasParameterConfig(
            "REVEAL_ATTEMPT_GAS_LIMIT", 200000, 50000, 2
        );
        d.parameters[3] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_NFT_DELIVERY_GAS_LIMIT", 300000, 100000, 2
        );
        surplusHouse = new StreamNativeEnglishAuction(d);
        StreamPrivateSaleAdapter.DeploymentConfig memory p;
        p.core = address(core);
        p.moduleRegistry = address(registry);
        p.platformSigner = vm.addr(PLATFORM_KEY);
        p.configurationOwner = address(this);
        p.governanceAuthority = address(executor);
        p.roleRegistry = address(roles);
        p.parameters[0] = d.parameters[0];
        p.parameters[1] = d.parameters[3];
        p.parameters[2] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ROYALTY_DELIVERY_GAS_LIMIT", 100000, 30000, 2
        );
        surplusPrivate = new StreamPrivateSaleAdapter(p);
        return NR.DelegationDeployment(
            address(0), 0, 0, IStreamGasParameterHost.GasParameterConfig("", 0, 0, 0)
        );
    }

    function testSurplusAuctionOriginalGraphRecoversOnlyDonationWithoutGrantingAuctionAuthority()
        external
    {
        _earned();
        probe.sweepAndAssert(NS(address(surplusHouse)), 0, false);
        require(
            surplusHouse.totalBuyerLiabilities() == 0 && surplusHouse.totalLiveBidDeposits() == 0
                && nativeSale.refundLiability() == 17 && core.ownerOf(1) == address(payerSafe),
            "other credits and token custody untouched"
        );
    }

    function testSurplusPrivateOriginalGraphRecoversOnlyDonationWithoutGrantingInventoryAuthority()
        external
    {
        _earned();
        probe.sweepAndAssert(NS(address(surplusPrivate)), 0, true);
        require(
            surplusPrivate.nativeSurplusState().liabilities == 0
                && nativeSale.refundLiability() == 17 && core.ownerOf(1) == address(payerSafe),
            "no private liability or NFT changed"
        );
    }

    NativeSurplusProbe private probe;
    bytes32 private constant SURPLUS_REASON = keccak256("recover unsolicited native surplus");

    function _withSurplusPolicy(GovernanceActionPolicyEntry[] memory original, address host)
        internal
        view
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](original.length + 1);
        for (uint256 i; i < original.length; ++i) {
            rows[i] = original[i];
        }
        rows[original.length] = GovernanceActionPolicyEntry(
            1,
            host,
            NS.sweepNativeSurplus.selector,
            host.codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, host)),
            1,
            0,
            0,
            bytes32(0)
        );
    }

    function surplusTestNow() external view returns (uint256) {
        return block.timestamp;
    }
    OfficialSafe internal governorSafe;
    uint256[] internal governorKeys;
    bytes32 internal constant GOVERNANCE_REASON = keccak256("current artist governance evidence");

    function _installGovernorSafe(OfficialSafe next, uint256[] memory signingKeys) internal {
        governorSafe = next;
        governorKeys = signingKeys;
        (address previous, bytes32 codeHash, uint64 revision) = executor.governanceRootState();
        bytes memory data = abi.encodeCall(
            executor.rotateGovernanceRoot, (address(next), address(next).codehash)
        );
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_ROOT_SCOPE_V1"), block.chainid, address(executor)
            )
        );
        GovernanceActionRequest memory request = _governanceRequest(
            3,
            address(executor),
            data,
            scope,
            _rootState(previous, codeHash, revision),
            _rootState(address(next), address(next).codehash, revision + 1)
        );
        bytes memory scheduled = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (request))
        );
        vm.warp(request.notBefore);
        executor.executeGovernanceAction(abi.decode(scheduled, (bytes32)), data);
        (address actual,,) = executor.governanceRootState();
        require(actual == address(next), "actual Safe governor installed");
    }

    function _rootState(address principal, bytes32 codeHash, uint64 revision)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_ROOT_STATE_V1"),
                block.chainid,
                address(executor),
                principal,
                codeHash,
                revision
            )
        );
    }

    function _governanceRequest(
        uint8 actionClass,
        address target,
        bytes memory data,
        bytes32 scope,
        bytes32 oldState,
        bytes32 newState
    ) internal view returns (GovernanceActionRequest memory request) {
        bytes4 selector;
        assembly ("memory-safe") { selector := mload(add(data, 32)) }
        uint64 ready = uint64(block.timestamp + executor.minimumDelay(actionClass));
        request = GovernanceActionRequest(
            actionClass,
            target,
            0,
            selector,
            data,
            scope,
            oldState,
            newState,
            ready,
            ready + 7 days,
            GOVERNANCE_REASON,
            "urn:stream:current:artist-governance",
            DEPLOYMENT_HASH
        );
    }

    function _scheduleAsGovernor(GovernanceActionRequest memory request)
        internal
        returns (bytes32 id)
    {
        vm.recordLogs();
        require(
            executeSafe(
                governorSafe,
                governorKeys,
                address(executor),
                0,
                abi.encodeCall(executor.scheduleGovernanceAction, (request)),
                0
            ),
            "Safe schedules actual action"
        );
        id = _scheduledAction(vm.getRecordedLogs());
        GovernanceAction memory stored = executor.governanceAction(id);
        require(
            stored.proposer == address(governorSafe)
                && stored.status == GovernanceActionStatus.SCHEDULED
                && stored.target == request.target && stored.selector == request.selector
                && stored.reasonHash == request.reasonHash,
            "exact stored Safe request"
        );
    }

    function _scheduleBatchAsGovernor(
        uint8 actionClass,
        GovernanceCall[] memory calls,
        bytes[] memory data
    ) internal returns (bytes32 id, uint64 ready) {
        require(calls.length == data.length, "matching batch");
        executor.publishGovernanceCallData(data);
        (bytes32 scope, bytes32 oldState, bytes32 newState) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            calls, StreamGovernanceBootstrap.governanceCallsHash(calls)
        );
        ready = uint64(block.timestamp + executor.minimumDelay(actionClass));
        vm.recordLogs();
        require(
            executeSafe(
                governorSafe,
                governorKeys,
                address(executor),
                0,
                abi.encodeCall(
                    executor.scheduleGovernanceBatch,
                    (
                        actionClass,
                        calls,
                        scope,
                        oldState,
                        newState,
                        ready,
                        ready + 7 days,
                        GOVERNANCE_REASON,
                        "urn:stream:current:artist-batch",
                        DEPLOYMENT_HASH
                    )
                ),
                0
            ),
            "Safe schedules actual batch"
        );
        id = _scheduledAction(vm.getRecordedLogs());
    }

    function _scheduledAction(Vm.Log[] memory logs) private view returns (bytes32 id) {
        bytes32 topic = keccak256(
            "GovernanceActionScheduled(uint16,bytes32,uint8,address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint256,address,bytes32,string,bytes32)"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(executor) && logs[i].topics.length == 4
                    && logs[i].topics[0] == topic
            ) {
                require(id == 0, "one scheduled action");
                id = logs[i].topics[1];
            }
        }
        require(id != 0, "canonical action event");
    }

    /// @dev External void boundary prevents an expected revert being consumed by Safe nonce reads.
    function executeCurrentGovernorCall(address target, bytes calldata data) external {
        require(msg.sender == address(this), "test only");
        require(
            executeSafe(governorSafe, governorKeys, target, 0, data, 0), "Safe target execution"
        );
    }

    function _executeAsGovernor(bytes32 id, bytes memory data) internal {
        this.executeCurrentGovernorCall(
            address(executor), abi.encodeCall(executor.executeGovernanceAction, (id, data))
        );
        require(
            executor.governanceAction(id).status == GovernanceActionStatus.EXECUTED,
            "actual action executed"
        );
    }

    function _govern(GovernanceActionRequest memory request) internal returns (bytes32 id) {
        id = _scheduleAsGovernor(request);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionNotExecutable.selector,
                id,
                request.notBefore
            )
        );
        executor.executeGovernanceAction(id, request.callData);
        vm.warp(request.notBefore);
        _executeAsGovernor(id, request.callData);
    }

    function _roleCall(bytes32 role, address holder, bool granted)
        internal
        view
        returns (GovernanceCall memory call_, bytes memory data)
    {
        bool oldGranted = roles.hasRole(role, holder);
        require(oldGranted != granted, "real membership transition");
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
        bytes32 oldState =
            _roleState(scope, oldGranted, roleChain, roleRevision, globalChain, globalRevision);
        roleChain = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_V1"),
                roleChain,
                block.chainid,
                address(roles),
                role,
                holder,
                granted,
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
                granted,
                globalRevision + 1
            )
        );
        data = granted
            ? abi.encodeCall(roles.grantRole, (role, holder))
            : abi.encodeCall(roles.revokeRole, (role, holder));
        call_ = StreamCurrentStackPlan.call(
            address(roles),
            data,
            scope,
            oldState,
            _roleState(scope, granted, roleChain, roleRevision + 1, globalChain, globalRevision + 1)
        );
    }

    function _setRole(bytes32 role, address holder, bool granted) internal {
        (GovernanceCall memory call_, bytes memory data) = _roleCall(role, holder, granted);
        _govern(
            _governanceRequest(
                1, call_.target, data, call_.scopeHash, call_.oldValueHash, call_.newValueHash
            )
        );
        require(roles.hasRole(role, holder) == granted, "actual role mutation");
    }

    function _roleState(
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

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory)
    {
        return _withSurplusPolicy(
            _withSurplusPolicy(
                _withSurplusPolicy(
                    StreamCurrentNativeSettlementTest._additionalOperatingPolicies(),
                    address(nativeSale)
                ),
                address(surplusHouse)
            ),
            address(surplusPrivate)
        );
    }

    function _earned() private {
        this.deployNativeScenario(false, false);
        (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,) =
            _execution(1, address(payerSafe));
        uint256 fee = nativeSale.saleRevealQuote(saleId).policy.revealFeePerTokenWei;
        require(
            executeSafe(
                payerSafe,
                keys,
                address(nativeSale),
                1017 + fee,
                abi.encodeCall(nativeSale.purchase, (e)),
                0
            )
        );
        require(
            nativeSale.refundLiability() == 17 && core.ownerOf(1) == address(payerSafe),
            "actual paid mint and original credit"
        );
        _installGovernorSafe(payerSafe, keys);
        probe = new NativeSurplusProbe(core, registry, executor, roles, governorSafe, governorKeys);
    }

    function testSurplusFixedDonationAndGuardPreserveCreditAndOriginalClaim() external {
        _earned();
        probe.sweepAndAssert(NS(address(nativeSale)), 17, true);
        require(
            executeSafe(
                payerSafe,
                keys,
                address(nativeSale),
                0,
                abi.encodeCall(nativeSale.claimRefund, (saleId, address(payerSafe))),
                0
            )
        );
        require(
            nativeSale.refundLiability() == 0 && nativeSale.nativeSurplusState().available == 43,
            "own claim independent of surplus"
        );
    }

    function testSurplusFixedRecipientFailureKeepsExactSafeActionRetry() external {
        _earned();
        probe.lateRetry(NS(address(nativeSale)), 17);
    }

    function testSurplusCannotTreatOwedFundsOrDirectValueAsAuthority() external {
        _earned();
        NS host = NS(address(nativeSale));
        vm.expectRevert(abi.encodeWithSelector(NS.AdapterSurplusUnderfunded.selector, address(0)));
        host.nativeSurplusQuote(1, SURPLUS_REASON);
        probe.fund(address(host), 100);
        vm.expectRevert(abi.encodeWithSelector(NS.AdapterSurplusUnderfunded.selector, address(0)));
        host.nativeSurplusQuote(101, SURPLUS_REASON);
        vm.expectRevert(
            abi.encodeWithSelector(NS.NativeSurplusAuthorityInvalid.selector, address(this))
        );
        host.sweepNativeSurplus(100, SURPLUS_REASON);
        vm.deal(address(this), 1);
        (bool ok,) = address(host).call{ value: 1 }(bytes(""));
        require(
            !ok && host.nativeSurplusState().liabilities == 17,
            "no payable fallback or fake liability"
        );
    }

    function testSurplusRecipientRoundTripAndSpentRevisionInvalidateOldActions() external {
        _earned();
        NS host = NS(address(nativeSale));
        NativeSurplusRecipient recipient = new NativeSurplusRecipient();
        probe.selectRecipient(address(recipient));
        probe.fund(address(host), 100);
        NS.NativeSurplusQuote memory original = host.nativeSurplusQuote(40, SURPLUS_REASON);
        GovernanceActionRequest memory stale = probe.quoteRequest(host, original);
        bytes32 id = _scheduleAsGovernor(stale);
        _setRole(keccak256("ROLE_EMERGENCY_RECIPIENT"), address(recipient), false);
        _setRole(keccak256("ROLE_EMERGENCY_RECIPIENT"), address(recipient), true);
        NS.NativeSurplusQuote memory current = host.nativeSurplusQuote(40, SURPLUS_REASON);
        require(
            current.authority.recipient == original.authority.recipient
                && current.oldValueHash != original.oldValueHash,
            "A to empty to A is new authority history"
        );
        require(
            this.surplusTestNow() >= stale.notBefore && this.surplusTestNow() <= stale.expiresAfter,
            "stale authority action is still time-executable"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceCallFailed.selector, id, uint256(0)
            )
        );
        executor.executeGovernanceAction(id, stale.callData);
        require(
            !host.nativeSurplusActionUsed(id) && address(recipient).balance == 0,
            "stale authority cannot transfer"
        );
        GovernanceActionRequest memory fresh = probe.quoteRequest(host, current);
        _govern(fresh);
        // A newly scheduled action still cannot use the already-consumed old state commitment.
        fresh.notBefore = uint64(this.surplusTestNow() + executor.minimumDelay(1));
        fresh.expiresAfter = fresh.notBefore + 7 days;
        bytes32 staleState = _scheduleAsGovernor(fresh);
        vm.warp(fresh.notBefore);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceCallFailed.selector, staleState, uint256(0)
            )
        );
        executor.executeGovernanceAction(staleState, fresh.callData);
        require(
            host.nativeSurplusState().revision == 1 && host.nativeSurplusState().available == 60,
            "revision prevents fresh-action stale quote replay"
        );
    }
}

contract StreamCurrentDutchSurplusTest is StreamCurrentDutchSaleTest {
    NativeSurplusProbe private probe;
    bytes32 private constant SURPLUS_REASON = keccak256("recover unsolicited native surplus");

    function _withSurplusPolicy(GovernanceActionPolicyEntry[] memory original, address host)
        internal
        view
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](original.length + 1);
        for (uint256 i; i < original.length; ++i) {
            rows[i] = original[i];
        }
        rows[original.length] = GovernanceActionPolicyEntry(
            1,
            host,
            NS.sweepNativeSurplus.selector,
            host.codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, host)),
            1,
            0,
            0,
            bytes32(0)
        );
    }

    function surplusTestNow() external view returns (uint256) {
        return block.timestamp;
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory)
    {
        return _withSurplusPolicy(
            StreamCurrentDutchSaleTest._additionalOperatingPolicies(), address(dutchSale)
        );
    }

    function testSurplusDutchPreservesOriginalLiabilityAndOwnWithdrawal() external {
        probe = new NativeSurplusProbe(core, registry, executor, roles, governorSafe, governorKeys);
        _consent();
        _purchase(_purchaseData(1, 1000), 1117);
        probe.sweepAndAssert(NS(address(dutchSale)), 17, false);
        require(
            executeSafe(
                payerSafe,
                keys,
                address(dutchSale),
                0,
                abi.encodeCall(dutchSale.claimRefund, (dutchId, address(payerSafe))),
                0
            )
        );
        require(dutchSale.nativeSurplusState().available == 40, "only original owed claim paid");
    }
}

contract StreamCurrentClearingSurplusTest is StreamCurrentClearingSaleTest {
    NativeSurplusProbe private probe;
    bytes32 private constant SURPLUS_REASON = keccak256("recover unsolicited native surplus");

    function _withSurplusPolicy(GovernanceActionPolicyEntry[] memory original, address host)
        internal
        view
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](original.length + 1);
        for (uint256 i; i < original.length; ++i) {
            rows[i] = original[i];
        }
        rows[original.length] = GovernanceActionPolicyEntry(
            1,
            host,
            NS.sweepNativeSurplus.selector,
            host.codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, host)),
            1,
            0,
            0,
            bytes32(0)
        );
    }

    function surplusTestNow() external view returns (uint256) {
        return block.timestamp;
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory)
    {
        return _withSurplusPolicy(
            StreamCurrentStackFixture._additionalOperatingPolicies(), address(clearing)
        );
    }

    function testSurplusClearingPreservesOriginalLiabilityAndOwnWithdrawal() external {
        probe = new NativeSurplusProbe(core, registry, executor, roles, governorSafe, governorKeys);
        _consent();
        _buy(_purchaseData(1), 1217);
        probe.sweepAndAssert(NS(address(clearing)), 1017, false);
        require(
            executeSafe(
                payerSafe,
                signingKeys,
                address(clearing),
                0,
                abi.encodeCall(clearing.claimRefund, (saleId, address(payerSafe))),
                0
            )
        );
        require(clearing.nativeSurplusState().available == 40, "only original owed claim paid");
    }
}

contract StreamCurrentRefundWindowSurplusTest is StreamCurrentRefundWindowTest {
    NativeSurplusProbe private probe;
    bytes32 private constant SURPLUS_REASON = keccak256("recover unsolicited native surplus");

    function _withSurplusPolicy(GovernanceActionPolicyEntry[] memory original, address host)
        internal
        view
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](original.length + 1);
        for (uint256 i; i < original.length; ++i) {
            rows[i] = original[i];
        }
        rows[original.length] = GovernanceActionPolicyEntry(
            1,
            host,
            NS.sweepNativeSurplus.selector,
            host.codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, host)),
            1,
            0,
            0,
            bytes32(0)
        );
    }

    function surplusTestNow() external view returns (uint256) {
        return block.timestamp;
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory)
    {
        return _withSurplusPolicy(
            StreamCurrentRefundWindowTest._additionalOperatingPolicies(), address(refundSale)
        );
    }

    function testSurplusRefundWindowPreservesOriginalLiabilityAndOwnWithdrawal() external {
        probe = new NativeSurplusProbe(core, registry, executor, roles, governorSafe, governorKeys);
        bytes32 purchase = _purchase(_purchaseData(1));
        probe.sweepAndAssert(NS(address(refundSale)), 1100, false);
        (, uint64 finalizeBy,) = refundSale.purchaseDeadlines(purchase);
        if (this.surplusTestNow() <= finalizeBy) vm.warp(uint256(finalizeBy) + 1);
        _exec(
            payerSafe,
            address(refundSale),
            0,
            abi.encodeCall(refundSale.unlockRefund, (purchase, uint8(0)))
        );
        require(core.totalSupply() == 0, "pending deposit was never minted or swept");
        require(
            executeSafe(
                payerSafe,
                keys,
                address(refundSale),
                0,
                abi.encodeCall(refundSale.claimRefund, (refundId, payable(address(payerSafe)))),
                0
            )
        );
        require(refundSale.nativeSurplusState().available == 40, "only original owed claim paid");
    }
}
