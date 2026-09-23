// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamCurrentNativeSurplus.t.sol";
import "../../smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol";
import "../../script/current/PrepareNativeSurplusRecovery.s.sol";

contract NativeSurplusOperatorProbe is NativeSurplusProbe {
    constructor(
        StreamCore c,
        StreamModuleRegistry r,
        StreamGovernanceExecutor e,
        StreamRoleRegistry roles_,
        OfficialSafe governor,
        uint256[] memory signingKeys
    ) NativeSurplusProbe(c, r, e, roles_, governor, signingKeys) { }

    function schedule(
        StreamGovernanceStagePlan.NextCall memory publication,
        StreamGovernanceStagePlan.NextCall memory scheduling
    ) external returns (bytes32 id) {
        require(
            publication.caller == address(0) && publication.target == address(executor)
                && publication.value == 0 && scheduling.caller == address(governorSafe)
                && scheduling.target == address(executor) && scheduling.value == 0,
            "exact caller/value coordinates"
        );
        (bool ok,) = publication.target.call(publication.data);
        require(ok, "original calldata publication");
        vm.recordLogs();
        require(
            executeSafe(governorSafe, governorKeys, scheduling.target, 0, scheduling.data, 0),
            "actual root Safe schedules"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256(
            "GovernanceActionScheduled(uint16,bytes32,uint8,address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint256,address,bytes32,string,bytes32)"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(executor) && logs[i].topics.length == 4
                    && logs[i].topics[0] == topic
            ) {
                require(id == 0, "one actual receipt");
                id = logs[i].topics[1];
            }
        }
        require(id != 0, "receipt-owned action id");
    }

    function serialize(StreamGovernanceStagePlan.NextCall memory next)
        external
        returns (bytes memory)
    {
        require(
            next.caller == address(0) && next.target == address(executor) && next.value == 0,
            "permissionless zero-value execution, Safe is only transport"
        );
        return _serializeGovernor(next.target, next.data);
    }
}

/// @notice New plan cases use the actual current Core/Artist/Manager/Registry/Executor/RoleRegistry/Safes.
/// @dev The inherited paid fixture retains its external entropy double. These are authored recipes,
/// not evidence of runtime acceptance until the integrator executes this suite.
contract StreamCurrentNativeSurplusRecoveryPlanTest is StreamCurrentFixedSurplusTest {
    PrepareNativeSurplusRecovery private planner;
    NativeSurplusOperatorProbe private operator;
    NativeSurplusRecipient private recipient;
    bytes32 private constant REASON = keccak256("operator native surplus recovery");

    function _scenario() private {
        // Reuse the original actual paid mint, 17-wei creditor and failed/successful Safe sweep.
        // Its completed sweep is a real prior revision, so planning cannot assume a zero head.
        this.testSurplusFixedRecipientFailureKeepsExactSafeActionRetry();
        planner = new PrepareNativeSurplusRecovery();
        operator = new NativeSurplusOperatorProbe(
            core, registry, executor, roles, governorSafe, governorKeys
        );
        recipient = new NativeSurplusRecipient();
        operator.selectRecipient(address(recipient));
        operator.fund(address(nativeSale), 100);
    }

    function _pins(address host)
        private
        view
        returns (StreamNativeSurplusRecoveryPlan.Pins memory)
    {
        return StreamNativeSurplusRecoveryPlan.Pins(
            host,
            host.codehash,
            address(core),
            address(core).codehash,
            address(registry),
            address(registry).codehash,
            address(executor),
            address(executor).codehash
        );
    }

    function _parameters(uint256 amount, uint8 cls)
        private
        view
        returns (StreamNativeSurplusRecoveryPlan.Parameters memory p)
    {
        uint64 ready = uint64(this.surplusTestNow() + executor.minimumDelay(cls));
        return StreamNativeSurplusRecoveryPlan.Parameters(
            amount,
            ready,
            ready + 30 days,
            REASON,
            "urn:stream:surplus:operator-plan",
            DEPLOYMENT_HASH
        );
    }

    function _prepare(uint256 amount)
        private
        view
        returns (StreamNativeSurplusRecoveryPlan.Prepared memory)
    {
        return planner.prepare(_pins(address(nativeSale)), _parameters(amount, 1));
    }

    function _saved(StreamNativeSurplusRecoveryPlan.Prepared memory p)
        private
        pure
        returns (StreamNativeSurplusRecoveryPlan.Saved memory)
    {
        return abi.decode(p.encodedRecovery, (StreamNativeSurplusRecoveryPlan.Saved));
    }

    function _execute(StreamNativeSurplusRecoveryPlan.Prepared memory p, bytes32 id) private {
        (bool done, StreamGovernanceStagePlan.NextCall memory next) =
            planner.execution(p.encodedRecovery, p.savedRecoveryHash, id);
        require(
            !done && next.caller == address(0) && next.value == 0, "original permissionless CALL"
        );
        (bool ok,) = next.target.call(next.data);
        require(ok, "actual Executor performs original sweep");
    }

    function _claimOriginal() private {
        require(
            executeSafe(
                payerSafe,
                keys,
                address(nativeSale),
                0,
                abi.encodeCall(nativeSale.claimRefund, (saleId, address(payerSafe))),
                0
            ),
            "original claimant exit"
        );
    }

    function testSurplusPlanUsesOriginalCallHashesAndRetainsCompletionAfterClaimAndLaterSweep()
        external
    {
        _scenario();
        StreamNativeSurplusRecoveryPlan.Prepared memory p = _prepare(60);
        StreamNativeSurplusRecoveryPlan.Saved memory s = _saved(p);
        require(
            keccak256(p.encodedRecovery) == p.savedRecoveryHash
                && keccak256(p.encodedPlan) == p.savedPlanHash
                && keccak256(p.encodedPlan) == keccak256(abi.encode(s.plan)),
            "two exact saved byte artifacts"
        );
        require(
            s.plan.batch.actionClass == 1 && s.plan.batch.calls.length == 1
                && s.plan.batch.calls[0].value == 0
                && s.plan.batch.calls[0].target == address(nativeSale)
                && s.plan.batch.calls[0].scopeHash == s.quote.scopeHash
                && s.plan.batch.calls[0].oldValueHash == s.quote.oldValueHash
                && s.plan.batch.calls[0].newValueHash == s.quote.newValueHash
                && keccak256(s.plan.batch.callDatas[0])
                    == keccak256(abi.encodeCall(NS.sweepNativeSurplus, (60, REASON))),
            "original per-call quote, no recipient or value added"
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            s.plan.batch.calls, StreamGovernanceBootstrap.governanceCallsHash(s.plan.batch.calls)
        );
        require(
            s.plan.scopeHash == scope && s.plan.oldValueHash == oldHash
                && s.plan.newValueHash == newHash,
            "aggregate plan hashes are distinct from call commitments"
        );
        bytes32 id = operator.schedule(p.publication, p.scheduling);
        (, StreamGovernanceStagePlan.NextCall memory early) =
            planner.execution(p.encodedRecovery, p.savedRecoveryHash, id);
        (bool premature,) = early.target.call(early.data);
        require(
            !premature && !nativeSale.nativeSurplusActionUsed(id), "actual delay remains mandatory"
        );
        operator.fund(address(nativeSale), 11);
        vm.warp(s.plan.notBefore);
        _execute(p, id);
        StreamNativeSurplusRecoveryPlan.Completion memory result =
            planner.completion(p.encodedRecovery, p.savedRecoveryHash, id);
        require(
            result.recipient == address(recipient) && result.amount == 60 && result.latestSweep
                && result.solvent && result.current.liabilities == 17
                && result.current.available == 51,
            "donations are surplus only"
        );
        _claimOriginal();
        result = planner.completion(p.encodedRecovery, p.savedRecoveryHash, id);
        require(
            result.current.liabilities == 0 && result.current.available == 51,
            "completion survives own claim"
        );
        StreamNativeSurplusRecoveryPlan.Prepared memory second = _prepare(20);
        bytes32 secondId = operator.schedule(second.publication, second.scheduling);
        vm.warp(_saved(second).plan.notBefore);
        _execute(second, secondId);
        result = planner.completion(p.encodedRecovery, p.savedRecoveryHash, id);
        require(
            !result.latestSweep && result.solvent && result.current.available == 31,
            "first executed receipt remains historical after another sweep"
        );
        (bool done, StreamGovernanceStagePlan.NextCall memory none) =
            planner.execution(p.encodedRecovery, p.savedRecoveryHash, id);
        require(
            done && none.target == address(0) && none.data.length == 0,
            "completed plan needs no new transaction"
        );
    }

    function testSurplusPlanFailedRecipientRetriesIdenticalCompleteSafeCall() external {
        _scenario();
        StreamNativeSurplusRecoveryPlan.Prepared memory p = _prepare(100);
        bytes32 id = operator.schedule(p.publication, p.scheduling);
        vm.warp(_saved(p).plan.notBefore);
        (, StreamGovernanceStagePlan.NextCall memory next) =
            planner.execution(p.encodedRecovery, p.savedRecoveryHash, id);
        bytes memory serialized = operator.serialize(next);
        uint256 nonce = governorSafe.nonce();
        NS.NativeSurplusState memory before_ = nativeSale.nativeSurplusState();
        recipient.configure(true, 0, address(nativeSale), bytes(""));
        SurplusCallVm(address(uint160(uint256(keccak256("hevm cheat code")))))
            .expectCall(address(recipient), 100, bytes(""), 2);
        (bool ok, bytes memory error) = address(governorSafe).call(serialized);
        require(
            !ok && keccak256(error) == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
            "late actual Safe failure"
        );
        require(
            governorSafe.nonce() == nonce
                && keccak256(abi.encode(nativeSale.nativeSurplusState()))
                    == keccak256(abi.encode(before_))
                && executor.governanceAction(id).status == GovernanceActionStatus.SCHEDULED
                && !nativeSale.nativeSurplusActionUsed(id),
            "all original balances and replay rolled back"
        );
        recipient.configure(false, 0, address(nativeSale), bytes(""));
        (ok, error) = address(governorSafe).call(serialized);
        require(
            ok && abi.decode(error, (bool)) && governorSafe.nonce() == nonce + 1,
            "identical signed Safe retry"
        );
        require(
            planner.completion(p.encodedRecovery, p.savedRecoveryHash, id).current.liabilities
                == 17,
            "credit never swept"
        );
        (ok,) = address(governorSafe).call(serialized);
        require(!ok, "original Safe signature cannot replay");
    }

    function testSurplusPlanLiabilityDriftFailsThenFreshApprovalAndOriginalClaimStayLive()
        external
    {
        _scenario();
        StreamNativeSurplusRecoveryPlan.Prepared memory p = _prepare(60);
        bytes32 id = operator.schedule(p.publication, p.scheduling);
        _claimOriginal();
        vm.warp(_saved(p).plan.notBefore);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeSurplusRecoveryPlan.SurplusRecoveryStateChanged.selector
            )
        );
        planner.execution(p.encodedRecovery, p.savedRecoveryHash, id);
        StreamNativeSurplusRecoveryPlan.Saved memory s = _saved(p);
        (bool ok,) = address(executor)
            .call(
                abi.encodeCall(
                    executor.executeGovernanceBatch,
                    (id, s.plan.batch.calls, s.plan.batch.callDatas)
                )
            );
        require(
            !ok && executor.governanceAction(id).status == GovernanceActionStatus.SCHEDULED,
            "old signed liability state cannot execute"
        );
        StreamNativeSurplusRecoveryPlan.Prepared memory fresh = _prepare(60);
        require(
            fresh.savedPlanHash != p.savedPlanHash
                && _saved(fresh).quote.oldValueHash != s.quote.oldValueHash,
            "new actual liability commitment"
        );
        bytes32 freshId = operator.schedule(fresh.publication, fresh.scheduling);
        vm.warp(_saved(fresh).plan.notBefore);
        _execute(fresh, freshId);
        require(
            nativeSale.nativeSurplusState().available == 40,
            "owed exit and new approved sweep independent"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeSurplusRecoveryPlan.SurplusRecoveryNotCompleted.selector
            )
        );
        planner.completion(p.encodedRecovery, p.savedRecoveryHash, id);
    }

    function testSurplusPlanRoleRotationAndJournalTamperingCannotChangeDestination() external {
        _scenario();
        StreamNativeSurplusRecoveryPlan.Prepared memory p = _prepare(60);
        bytes32 id = operator.schedule(p.publication, p.scheduling);
        StreamNativeSurplusRecoveryPlan.Saved memory altered = _saved(p);
        altered.quote.authority.recipient = address(0xDEAD);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeSurplusRecoveryPlan.InvalidSurplusRecoveryJournal.selector
            )
        );
        planner.execution(abi.encode(altered), p.savedRecoveryHash, id);
        bytes memory falseJournal = abi.encode(altered);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeSurplusRecoveryPlan.InvalidSurplusRecoveryJournal.selector
            )
        );
        planner.execution(falseJournal, keccak256(falseJournal), id);
        NativeSurplusRecipient replacement = new NativeSurplusRecipient();
        operator.selectRecipient(address(replacement));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeSurplusRecoveryPlan.SurplusRecoveryStateChanged.selector
            )
        );
        planner.execution(p.encodedRecovery, p.savedRecoveryHash, id);
        operator.selectRecipient(address(recipient));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeSurplusRecoveryPlan.SurplusRecoveryStateChanged.selector
            )
        );
        planner.execution(p.encodedRecovery, p.savedRecoveryHash, id);
        StreamNativeSurplusRecoveryPlan.Prepared memory fresh = _prepare(60);
        bytes32 freshId = operator.schedule(fresh.publication, fresh.scheduling);
        vm.warp(_saved(fresh).plan.notBefore);
        _execute(fresh, freshId);
        require(
            address(recipient).balance == 60 && address(replacement).balance == 0,
            "new role-chain approval required even on round trip"
        );
    }

    function testSurplusPlanRejectsForeignPinsAndOwedBalanceBeforeScheduling() external {
        _scenario();
        StreamNativeSurplusRecoveryPlan.Pins memory pins = _pins(address(nativeSale));
        StreamNativeSurplusRecoveryPlan.Parameters memory parameters = _parameters(60, 1);
        pins.adapterCodeHash = keccak256("foreign runtime");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeSurplusRecoveryPlan.InvalidSurplusRecoveryPins.selector
            )
        );
        planner.prepare(pins, parameters);
        pins = _pins(address(nativeSale));
        pins.executor = address(this);
        pins.executorCodeHash = address(this).codehash;
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeSurplusRecoveryPlan.InvalidSurplusRecoveryPins.selector
            )
        );
        planner.prepare(pins, parameters);
        pins = _pins(address(nativeSale));
        parameters.amount = 101;
        vm.expectRevert(abi.encodeWithSelector(NS.AdapterSurplusUnderfunded.selector, address(0)));
        planner.prepare(pins, parameters);
        require(nativeSale.refundLiability() == 17, "read-only planning cannot consume owed funds");
    }

    function checkSavedScheduling(bytes memory encoded, bytes32 hash) external view {
        StreamGovernanceStagePlan.scheduling(
            abi.decode(encoded, (StreamGovernanceStagePlan.Plan)), hash
        );
    }

    function testSurplusMissingSelectorAdmissionUsesSeparateCatalogManifestStage() external {
        _scenario();
        StreamPrimarySaleSettlement recorder =
            new StreamPrimarySaleSettlement(primaryResolver, address(registry), revenueEscrow);
        StreamNativeFixedPriceSaleAdapter extra = new StreamNativeFixedPriceSaleAdapter(
            manager,
            recorder,
            vm.addr(PLATFORM_KEY),
            IStreamArtistAttribution(address(artists)),
            IStreamGasParameterHost.GasParameterConfig(
                "REVEAL_ATTEMPT_GAS_LIMIT", 2000000, 50000, 2
            ),
            NR.DelegationDeployment(
                address(0), 0, 0, IStreamGasParameterHost.GasParameterConfig("", 0, 0, 0)
            )
        );
        operator.fund(address(extra), 100);
        StreamNativeSurplusRecoveryPlan.Pins memory pins = _pins(address(extra));
        StreamNativeSurplusRecoveryPlan.Prepared memory beforeAdmission =
            planner.prepare(pins, _parameters(60, 1));
        vm.expectRevert();
        operator.schedule(beforeAdmission.publication, beforeAdmission.scheduling);
        require(extra.nativeSurplusState().available == 100, "missing catalog never grants sweep");
        (StreamGovernanceCatalogStagePlan.Inventory memory inventory, bytes32 savedInventoryHash) = planner.prepareAdmissionInventory(
            pins, keccak256(abi.encode(DEPLOYMENT_HASH, address(extra)))
        );
        require(
            inventory.additions.length == 1 && inventory.additions[0].actionClass == 1
                && inventory.additions[0].target == address(extra)
                && inventory.additions[0].selector == NS.sweepNativeSurplus.selector
                && inventory.additions[0].callType == 1 && inventory.additions[0].valuePolicy == 0,
            "exact zero-value CALL admission"
        );
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        (address payload, bytes32 hash) = StreamGenesisManifestPlan.writePayload(
            bytes("{\"purpose\":\"native surplus operator admission\"}")
        );
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            hash,
            "urn:stream:surplus:admission",
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
        (
            bytes memory encoded,
            bytes32 planHash,
            StreamGovernanceStagePlan.NextCall memory publication,
            StreamGovernanceStagePlan.NextCall memory scheduling
        ) = planner.prepareAdmissionStage(
            inventory, savedInventoryHash, manifest, payload, update, _parameters(0, 3)
        );
        StreamGovernanceStagePlan.Plan memory plan =
            abi.decode(encoded, (StreamGovernanceStagePlan.Plan));
        require(
            plan.batch.actionClass == 3 && plan.batch.calls.length == 2
                && plan.batch.calls[1].target == address(manifest),
            "original mandatory manifest tail"
        );
        bytes32 id = operator.schedule(publication, scheduling);
        vm.warp(plan.notBefore);
        require(
            StreamGovernanceStagePlan.execute(plan, id, planHash),
            "actual isolated catalog admission"
        );
        vm.expectRevert(
            abi.encodeWithSelector(StreamGovernanceStagePlan.StageStateChanged.selector)
        );
        this.checkSavedScheduling(beforeAdmission.encodedPlan, beforeAdmission.savedPlanHash);
        StreamNativeSurplusRecoveryPlan.Prepared memory admitted =
            planner.prepare(pins, _parameters(60, 1));
        bytes32 admittedId = operator.schedule(admitted.publication, admitted.scheduling);
        vm.warp(_saved(admitted).plan.notBefore);
        _execute(admitted, admittedId);
        require(
            planner.completion(admitted.encodedRecovery, admitted.savedRecoveryHash, admittedId)
                .current.available == 40,
            "fresh admitted plan executes, no sale authority fabricated"
        );
    }
}
