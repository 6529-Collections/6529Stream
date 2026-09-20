// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentCommerceConservationFixture.sol";
import { IStreamMintGate } from "../../smart-contracts/interfaces/stream/mint/IStreamMintGate.sol";
import {
    StreamMintGateValidator
} from "../../smart-contracts/domains/mint/StreamMintGateValidator.sol";
import {
    StreamPrimarySaleSettlement
} from "../../smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol";
import "../../smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol";
import { StreamBurnMintGate } from "../../smart-contracts/domains/mint/StreamBurnMintGate.sol";
import {
    IStreamNativePrimarySaleSettlement
} from "../../smart-contracts/interfaces/stream/revenue/IStreamNativePrimarySaleSettlement.sol";
import {
    IStreamBurnMintGate as Burn
} from "../../smart-contracts/interfaces/stream/mint/IStreamBurnMintGate.sol";

interface CurrentBurnPolicyVm {
    function expectCall(address target, uint256 value, bytes calldata data, uint64 count) external;
}

/// @notice Actual current Burn/Core/Manager/Ledger/revenue/Artist/Executor and distinct threshold Safes.
/// @dev The inherited external entropy provider is the sole service boundary. No finality is simulated.
contract StreamCurrentBurnPolicyTest is CurrentCommerceConservationFixture {
    bytes32 private constant BURN_PHASE = keccak256("current burn mint phase");
    bytes32 private constant SEED_PHASE = keccak256("current burn sources");
    bytes32 private constant CAP = keccak256("burn supply");
    StreamBurnMintGate private burnGate;
    StreamNativeFixedPriceSaleAdapter private nativeSale;
    StreamPrimarySaleSettlement private recorder;
    OfficialSafe private artistSafe;
    OfficialSafe private buyerSafe;
    uint256[] private artistKeys;
    uint256[] private buyerKeys;
    uint256 private constant SOURCE_COLLECTION = 2;
    bool private nativeMode;
    bytes32 private nativeId;
    bytes32 private sourceRoot;
    bytes32 private sourceAuthorization;

    struct Attempt {
        address target;
        uint256 value;
        bytes data;
        bytes safeCall;
        bytes mintCall;
        bytes32 authorization;
        bytes32 nativeNonce;
        uint256 source;
    }

    function setUp() public {
        artistKeys.push(0xB101);
        artistKeys.push(0xB102);
        buyerKeys.push(0xB201);
        buyerKeys.push(0xB202);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        artistSafe = createOfficialSafe(components, safeOwnerAddresses(artistKeys), 2, 301);
        buyerSafe = createOfficialSafe(components, safeOwnerAddresses(buyerKeys), 2, 302);
        vm.deal(address(buyerSafe), 1 ether);
        vm.deal(address(this), 1 ether);
    }

    function deployBurnScenario(bool paid) external {
        require(msg.sender == address(this), "fixture only");
        nativeMode = paid;
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
        this.installBurnCommerceGovernor();
        if (paid) {
            this.enableBurnCommerceFloor();
        }
    }

    function installBurnCommerceGovernor() external {
        require(msg.sender == address(this), "fixture only");
        uint256[] memory governanceKeys = new uint256[](2);
        governanceKeys[0] = 0x6001;
        governanceKeys[1] = 0x6002;
        OfficialSafe next = createOfficialSafe(
            deploySafeComponents("1.4.1"), safeOwnerAddresses(governanceKeys), 2, 203
        );
        _installGovernorSafe(next, governanceKeys);
    }

    function enableBurnCommerceFloor() external {
        require(msg.sender == address(this), "fixture only");
        _enableWaivedCommerceFloor();
    }

    function burnScenarioTime() external view returns (uint256) {
        return block.timestamp;
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(artistKeys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function _deployAdditionalProducts() internal override {
        recorder =
            new StreamPrimarySaleSettlement(primaryResolver, address(registry), revenueEscrow);
        nativeSale = new StreamNativeFixedPriceSaleAdapter(
            manager,
            recorder,
            vm.addr(PLATFORM_KEY),
            IStreamArtistAttribution(address(artists)),
            IStreamGasParameterHost.GasParameterConfig(
                "REVEAL_ATTEMPT_GAS_LIMIT", 2000000, 50000, 2
            ),
            IStreamNativeRefundDelegatedClaims.DelegationDeployment(
                    address(0), 0, 0, IStreamGasParameterHost.GasParameterConfig("", 0, 0, 0)
                )
        );
        burnGate = new StreamBurnMintGate(
            StreamBurnMintGate.Configuration(
                address(core),
                address(registry),
                address(executor),
                address(this),
                DEPLOYMENT_HASH,
                keccak256("burn gate manifest"),
                "ipfs://burn-gate",
                IStreamGasParameterHost.GasParameterConfig(
                    "BURN_DEPENDENCY_READ_GAS", 300000, 100000, 2
                ),
                IStreamGasParameterHost.GasParameterConfig(
                    "BURN_EXECUTION_GAS", 2000000, 200000, 2
                ),
                IStreamGasParameterHost.GasParameterConfig(
                        "REVEAL_ATTEMPT_GAS_LIMIT", 2000000, 50000, 2
                    )
            )
        );
        _assertDeployableProductionInstance(address(recorder));
        _assertDeployableProductionInstance(address(nativeSale));
        _assertDeployableProductionInstance(address(burnGate));
    }

    function _revealPrincipals()
        internal
        view
        override
        returns (StreamRevealActivationPlan.Principals memory)
    {
        return StreamRevealActivationPlan.Principals(
            address(this), address(nativeSale), address(governanceRoot)
        );
    }

    function _additionalEscrowProducers() internal view override returns (address[] memory rows) {
        rows = new address[](1);
        rows[0] = address(recorder);
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = _commerceFloorPolicies(new GovernanceActionPolicyEntry[](0));
    }

    function _configureAdditionalProducts() internal override {
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](3);
        records[0] = StreamModuleRegistration(
            address(nativeSale),
            keccak256("NATIVE_PRIMARY_SALE_ADAPTER"),
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1"),
            type(IStreamNativeSaleBinding).interfaceId,
            500000,
            address(nativeSale).codehash,
            DEPLOYMENT_HASH,
            keccak256("native burn sale"),
            "ipfs://current-burn-policy-native"
        );
        records[1] = StreamModuleRegistration(
            address(burnGate),
            burnGate.streamModuleType(),
            burnGate.streamModuleVersion(),
            type(IStreamMintGate).interfaceId,
            400000,
            address(burnGate).codehash,
            DEPLOYMENT_HASH,
            keccak256("burn gate manifest"),
            "ipfs://burn-gate"
        );
        records[2] = StreamModuleRegistration(
            address(recorder),
            keccak256("PRIMARY_SALE_SETTLEMENT"),
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1"),
            type(IStreamPrimarySaleSettlement).interfaceId,
            500000,
            address(recorder).codehash,
            DEPLOYMENT_HASH,
            keccak256("current burn settlement manifest"),
            "ipfs://current-burn-policy-settlement"
        );
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        (bytes32 scope, bytes32 before_, bytes32 after_) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            calls, StreamGovernanceBootstrap.governanceCallsHash(calls)
        );
        uint64 ready = uint64(this.burnScenarioTime() + 48 hours);
        executor.publishGovernanceCallData(data);
        bytes memory scheduled = governanceRoot.execute(
            address(executor),
            0,
            abi.encodeCall(
                executor.scheduleGovernanceBatch,
                (
                    uint8(1),
                    calls,
                    scope,
                    before_,
                    after_,
                    ready,
                    uint64(ready + 7 days),
                    keccak256("burn admission"),
                    "ipfs://current-burn-policy-admission",
                    DEPLOYMENT_HASH
                )
            )
        );
        vm.warp(ready);
        executor.executeGovernanceBatch(abi.decode(scheduled, (bytes32)), calls, data);
        _configureSourceCollection();
        this.configureBurnPolicies();
    }

    // A fresh external frame observes the completed governance warps before signing Artist records.
    function configureBurnPolicies() external {
        require(msg.sender == address(this), "fixture only");
        _onboardSourceArtist(address(artistSafe));
        _configureSourcePhase();
        uint256[] memory sources = new uint256[](1);
        sources[0] = SOURCE_COLLECTION;
        bytes32 configHash = burnGate.configureProgram(
            Burn.ProgramConfig(
                address(manager),
                1,
                BURN_PHASE,
                sources,
                1,
                0,
                0,
                false,
                nativeMode ? address(nativeSale) : address(0)
            )
        );
        _configureBurnPhase(configHash);
        if (nativeMode) {
            nativeId = nativeSale.registerSale(
                IStreamNativeFixedPriceSaleAdapter.SaleConfig(
                    1,
                    BURN_PHASE,
                    1000,
                    0,
                    uint64(this.burnScenarioTime() + 30 days),
                    manager.phasePolicyHash(1, BURN_PHASE),
                    primaryResolver.resolvePrimaryAssignment(1, 0, PRIMARY_REVENUE_CLASS)
                    .assignmentHash
                )
            );
        }
    }

    function _configureBurnPhase(bytes32 hash) private {
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = CAP;
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            5,
            1,
            keccak256("cap")
        );
        IStreamMintManager.MintGateConfig memory gateConfig;
        gateConfig.gate = address(burnGate);
        gateConfig.gateConfigHash = hash;
        gateConfig = StreamMintGateValidator.validateConfiguration(gateConfig, registry);
        IStreamMintManager.MintPhaseConfig memory config =
            IStreamMintManager.MintPhaseConfig(false, 0, 0, 1, keccak256("burn app"), hash);
        _recordFixturePolicy(
            BURN_PHASE,
            manager.previewPhasePolicyHash(
                1, BURN_PHASE, config, gateConfig, ids, counters, new address[](0)
            )
        );
        manager.configurePhase(1, BURN_PHASE, config, gateConfig, ids, counters);
        address[] memory enabled = new address[](1);
        enabled[0] = nativeMode ? address(nativeSale) : address(burnGate);
        _recordFixturePolicy(
            BURN_PHASE,
            manager.previewPhasePolicyHash(
                1, BURN_PHASE, config, gateConfig, ids, counters, enabled
            )
        );
        manager.setPhaseExecutor(1, BURN_PHASE, enabled[0], true);
    }

    function _batch(bytes32 phase, address recipient)
        private
        view
        returns (IStreamMintManager.MintBatch memory b)
    {
        b.collectionId = phase == SEED_PHASE ? SOURCE_COLLECTION : 1;
        b.phaseId = phase;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = recipient;
        b.beneficiaries = b.initialRecipients;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = TOKEN_DATA;
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = keccak256(abi.encode(phase, recipient));
        b.expectedPolicyHash = manager.phasePolicyHash(b.collectionId, phase);
        b.authorizationId = keccak256(abi.encode("request", phase, recipient));
    }

    function _seed() private returns (uint256[] memory ids) {
        IStreamMintManager.MintBatch memory b = _batch(SEED_PHASE, address(buyerSafe));
        sourceAuthorization = b.authorizationId;
        (ids, sourceRoot,) = manager.executeSingleStepMint(b, "");
        (bool exists, uint256 collection,, bool burned) = core.tokenCollectionIdentity(ids[0]);
        require(
            exists && collection == SOURCE_COLLECTION && !burned
                && core.ownerOf(ids[0]) == address(buyerSafe),
            "ordinary independent source mint"
        );
        require(
            executeSafe(
                buyerSafe,
                buyerKeys,
                address(core),
                0,
                abi.encodeCall(core.setApprovalForAll, (address(burnGate), true)),
                0
            ),
            "Safe burn approval"
        );
    }

    function _nativeExecution(address recipient)
        private
        returns (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e)
    {
        e.authorization = IStreamNativeFixedPriceSaleAdapter.SaleAuthorization(
            nativeId,
            nativeSale.saleRecord(nativeId).configHash,
            address(buyerSafe),
            address(buyerSafe),
            recipient,
            address(artistSafe),
            keccak256(TOKEN_DATA),
            keccak256("native burn commitment"),
            1,
            keccak256("native burn nonce"),
            uint64(this.burnScenarioTime() + 30 days),
            _nativePrimaryPolicyHash()
        );
        e.tokenData = TOKEN_DATA;
        bytes32 digest = nativeSale.authorizationDigest(e.authorization);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        e.platformSignature = abi.encodePacked(r, s, v);
        e.artistSignature =
            safeThresholdSignature(artistKeys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function _safeCall(address target, uint256 value, bytes memory data)
        private
        returns (bytes memory)
    {
        bytes32 digest = buyerSafe.getTransactionHash(
            target, value, data, 0, 0, 0, 0, address(0), address(0), buyerSafe.nonce()
        );
        return abi.encodeCall(
            buyerSafe.execTransaction,
            (
                target,
                value,
                data,
                uint8(0),
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(buyerKeys, digest)
            )
        );
    }

    function testCurrentClosedSourceStillBurnsIntoIndependentActiveTarget() public {
        this.deployBurnScenario(false);
        uint256[] memory ids = _seed();
        this.changeCollectionStatus(SOURCE_COLLECTION, 2);
        require(
            core.collectionStatus(SOURCE_COLLECTION) == 2
                && !core.collectionBurnsBlocked(SOURCE_COLLECTION)
                && !core.collectionFreezeStatus(SOURCE_COLLECTION) && core.collectionStatus(1) == 0,
            "CLOSED is not burn-blocked or target closure"
        );
        Attempt memory a = _attempt(ids);
        _expectAttemptCalls(a, 1, 0);
        _succeed(a);
    }

    function testCurrentGovernedSourceBurnBlockRejectsFreeBurnWithoutResidue() public {
        this.deployBurnScenario(false);
        uint256[] memory ids = _seed();
        this.changeCollectionStatus(SOURCE_COLLECTION, 2);
        this.blockSourceBurns();
        Attempt memory a = _attempt(ids);
        _expectAttemptCalls(a, 2, 0);
        _reject(a, abi.encodeWithSelector(Burn.BurnMintExecutionFailed.selector, ids[0]));
        require(
            core.collectionStatus(1) == 0 && !core.collectionBurnsBlocked(1),
            "source terminal policy never changes target"
        );
    }

    function testCurrentGovernedSourceBurnBlockRejectsNativeBurnWithoutPayment() public {
        this.deployBurnScenario(true);
        uint256[] memory ids = _seed();
        this.changeCollectionStatus(SOURCE_COLLECTION, 2);
        this.blockSourceBurns();
        Attempt memory a = _attempt(ids);
        _expectAttemptCalls(a, 2, 0);
        _reject(a, abi.encodeWithSelector(Burn.BurnMintExecutionFailed.selector, ids[0]));
        require(
            recorder.totalOfficialSettled(address(0)) == 0 && nativeSale.refundLiability() == 0,
            "blocked source cannot settle or credit"
        );
    }

    function testCurrentTargetPauseRollsBackNativePaymentAndIdenticalSafeRetries() public {
        this.deployBurnScenario(true);
        uint256[] memory ids = _seed();
        this.changeCollectionStatus(1, 1);
        Attempt memory a = _attempt(ids);
        bytes32 exact = keccak256(a.safeCall);
        _expectAttemptCalls(a, 3, 3);
        _reject(a, abi.encodeWithSelector(StreamCore.InvalidCollectionTransition.selector));
        this.changeCollectionStatus(1, 0);
        require(keccak256(a.safeCall) == exact, "retain original Safe signature and payload");
        _succeed(a);
    }

    function testCurrentTargetClosurePermanentlyRejectsNativeMintAndRestoresSource() public {
        this.deployBurnScenario(true);
        uint256[] memory ids = _seed();
        this.changeCollectionStatus(1, 2);
        Attempt memory a = _attempt(ids);
        _expectAttemptCalls(a, 5, 4);
        _reject(a, abi.encodeWithSelector(StreamCore.InvalidCollectionTransition.selector));
        _reject(a, abi.encodeWithSelector(StreamCore.InvalidCollectionTransition.selector));
        require(
            core.collectionStatus(1) == 2 && core.collectionStatus(SOURCE_COLLECTION) == 0
                && !core.collectionBurnsBlocked(SOURCE_COLLECTION),
            "terminal target is independent"
        );
        // The same source remains genuinely burnable by its owner after failed paid target minting.
        require(
            executeSafe(
                buyerSafe, buyerKeys, address(core), 0, abi.encodeCall(core.burn, (ids[0])), 0
            ),
            "source can still burn independently"
        );
        (, uint256 collection,, bool burned) = core.tokenCollectionIdentity(ids[0]);
        require(
            collection == SOURCE_COLLECTION && burned
                && !manager.isNullifierUsed(burnGate.burnNullifier(ids[0]))
                && recorder.totalOfficialSettled(address(0)) == 0,
            "owner burn creates no mint nullifier or sale"
        );
    }

    function testCurrentFreePhasePauseRestoresBurnAndIdenticalSafeRetries() public {
        this.deployBurnScenario(false);
        uint256[] memory ids = _seed();
        Attempt memory a = _attempt(ids);
        this.changeTargetPhasePause(true);
        _expectAttemptCalls(a, 3, 0);
        _reject(
            a,
            abi.encodeWithSelector(
                IStreamMintManager.MintPhasePaused.selector, uint256(1), BURN_PHASE
            )
        );
        this.changeTargetPhasePause(false);
        _succeed(a);
    }

    function testCurrentNativePhasePauseRestoresBurnAndIdenticalSafeRetries() public {
        this.deployBurnScenario(true);
        uint256[] memory ids = _seed();
        Attempt memory a = _attempt(ids);
        this.changeTargetPhasePause(true);
        _expectAttemptCalls(a, 3, 1);
        _reject(
            a,
            abi.encodeWithSelector(
                IStreamMintManager.MintPhasePaused.selector, uint256(1), BURN_PHASE
            )
        );
        this.changeTargetPhasePause(false);
        _succeed(a);
    }

    function _attempt(uint256[] memory ids) private returns (Attempt memory a) {
        a.source = ids[0];
        if (nativeMode) {
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e =
                _nativeExecution(address(buyerSafe));
            a.target = address(nativeSale);
            a.value = 1250;
            a.data = abi.encodeCall(nativeSale.purchaseWithBurn, (e, ids));
            a.mintCall = abi.encodeCall(
                core.mintFromManager,
                (
                    uint256(1),
                    e.authorization.recipient,
                    e.tokenData,
                    keccak256(e.tokenData),
                    e.authorization.mintCommitment
                )
            );
            a.nativeNonce = e.authorization.nonce;
            a.authorization = keccak256(
                abi.encode(
                    keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"),
                    nativeSale.authorizationDigest(e.authorization)
                )
            );
        } else {
            IStreamMintManager.MintBatch memory b = _batch(BURN_PHASE, address(buyerSafe));
            a.target = address(burnGate);
            a.value = 25;
            a.data = abi.encodeCall(burnGate.burnAndMint, (b, ids));
            a.authorization = b.authorizationId;
        }
        a.safeCall = _safeCall(a.target, a.value, a.data);
    }

    // Counted expectations persist until test completion, including a successful retry or owner burn.
    function _expectAttemptCalls(Attempt memory a, uint64 burns, uint64 targetMints) private {
        CurrentBurnPolicyVm(address(vm))
            .expectCall(address(core), 0, abi.encodeCall(core.burn, (a.source)), burns);
        if (targetMints != 0) {
            require(nativeMode, "late target oracle requires native settlement");
            CurrentBurnPolicyVm(address(vm))
                .expectCall(
                    address(recorder),
                    1000,
                    abi.encodeWithSelector(
                        IStreamNativePrimarySaleSettlement.settleNativePrimarySaleFromAdapter
                            .selector
                    ),
                    targetMints
                );
            CurrentBurnPolicyVm(address(vm)).expectCall(address(core), 0, a.mintCall, targetMints);
        }
    }

    function _reject(Attempt memory a, bytes memory expected) private {
        bytes32 beforeState = _attemptState(a);
        vm.prank(address(buyerSafe));
        (bool ok, bytes memory out) = a.target.call{ value: a.value }(a.data);
        require(!ok && keccak256(out) == keccak256(expected), "exact actual policy rejection");
        require(_attemptState(a) == beforeState, "diagnostic call restores complete attempt state");
        (ok, out) = address(buyerSafe).call(a.safeCall);
        require(
            !ok && keccak256(out) == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
            "actual threshold Safe target rejection"
        );
        require(
            _attemptState(a) == beforeState,
            "Safe failure restores payment burn accounting and replay"
        );
        require(
            !manager.isAuthorizationUsed(a.authorization)
                && !manager.isNullifierUsed(burnGate.burnNullifier(a.source)),
            "attempt has no durable authority use"
        );
    }

    function _attemptState(Attempt memory a) private view returns (bytes32 h) {
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            core.tokenCollectionIdentity(a.source);
        h = keccak256(
            abi.encode(
                exists,
                collection,
                serial,
                burned,
                core.ownerOf(a.source),
                core.getApproved(a.source),
                core.isApprovedForAll(address(buyerSafe), address(burnGate)),
                keccak256(core.tokenData(a.source)),
                core.coordinatorAtMint(a.source),
                core.lastAllocatedTokenId(),
                core.totalSupply(),
                core.totalSupplyOfCollection(SOURCE_COLLECTION),
                core.totalSupplyOfCollection(1),
                core.collectionMintedEver(SOURCE_COLLECTION),
                core.collectionMintedEver(1),
                core.collectionNextSerial(SOURCE_COLLECTION),
                core.collectionNextSerial(1)
            )
        );
        h = keccak256(
            abi.encode(
                h,
                manager.nextOperationNonce(),
                manager.isAuthorizationUsed(a.authorization),
                manager.isNullifierUsed(burnGate.burnNullifier(a.source)),
                _counterValue(1, BURN_PHASE),
                _counterValue(SOURCE_COLLECTION, SEED_PHASE),
                ledger.isManagerOperationRootUsed(address(manager), sourceRoot),
                ledger.isManagerAuthorizationUsed(address(manager), sourceAuthorization),
                buyerSafe.nonce(),
                address(buyerSafe).balance,
                address(this).balance,
                address(burnGate).balance,
                address(nativeSale).balance
            )
        );
        h = keccak256(
            abi.encode(
                h,
                recorder.totalOfficialSettled(address(0)),
                address(recorder).balance,
                address(revenueEscrow).balance,
                revenueEscrow.totalOwed(address(0)),
                address(wallet).balance,
                burnGate.refundLiability(),
                burnGate.refundableBalance(burnGate.program(1).configHash, address(buyerSafe)),
                nativeSale.refundLiability(),
                nativeSale.refundableBalance(nativeId, address(buyerSafe)),
                nativeSale.authorizationUsed(address(artistSafe), a.nativeNonce),
                nativeSale.executionIdByNonce(nativeId, 1),
                entropy.revealFeeEscrow(1),
                nativeMode ? commerceFloor.firstSale(1).receiptHash : bytes32(0)
            )
        );
    }

    function _counterValue(uint256 collection, bytes32 phase) private view returns (uint256) {
        bytes32 subject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.CONSTANT,
            collection,
            phase,
            CAP,
            address(0),
            address(0),
            address(0),
            address(0),
            bytes32(0)
        );
        return ledger.counterValue(manager.previewCounterValueKey(collection, phase, CAP, subject));
    }

    function _succeed(Attempt memory a) private {
        uint256 nonce = buyerSafe.nonce();
        uint256 operationNonce = manager.nextOperationNonce();
        vm.recordLogs();
        (bool ok, bytes memory out) = address(buyerSafe).call(a.safeCall);
        require(
            ok && abi.decode(out, (bool)) && buyerSafe.nonce() == nonce + 1,
            "same threshold envelope succeeds"
        );
        bytes32 root = _burnRoot(vm.getRecordedLogs(), a.source);
        (, uint256 sourceCollection,, bool burned) = core.tokenCollectionIdentity(a.source);
        uint256 target = core.lastAllocatedTokenId();
        (bool exists, uint256 targetCollection,, bool targetBurned) =
            core.tokenCollectionIdentity(target);
        require(
            sourceCollection == SOURCE_COLLECTION && burned && exists && targetCollection == 1
                && !targetBurned && core.ownerOf(target) == address(buyerSafe),
            "source burn and target identity remain distinct"
        );
        require(
            manager.nextOperationNonce() == operationNonce + 1 && _counterValue(1, BURN_PHASE) == 1
                && _counterValue(SOURCE_COLLECTION, SEED_PHASE) == 1 && core.totalSupply() == 1
                && core.collectionMintedEver(SOURCE_COLLECTION) == 1
                && core.collectionMintedEver(1) == 1,
            "one original mint and independent source accounting"
        );
        require(
            manager.isAuthorizationUsed(a.authorization) && manager.isOperationRootUsed(root)
                && manager.isNullifierUsed(burnGate.burnNullifier(a.source))
                && ledger.isManagerOperationRootUsed(address(manager), sourceRoot),
            "original durable replay owners consumed once"
        );
        if (nativeMode) {
            bytes32 execution = nativeSale.executionIdByNonce(nativeId, 1);
            bytes32 settlement = recorder.settlementKey(address(nativeSale), execution);
            require(
                execution != 0 && nativeSale.executionStatus(execution) == 2
                    && nativeSale.authorizationUsed(address(artistSafe), a.nativeNonce)
                    && recorder.settlementConsumed(settlement)
                    && recorder.totalOfficialSettled(address(0)) == 1000
                    && nativeSale.refundLiability() == 250
                    && nativeSale.refundableBalance(nativeId, address(buyerSafe)) == 250,
                "one native settlement and original payer excess credit"
            );
            _assertWaivedCommerceReceipt(address(recorder), settlement);
        } else {
            require(
                recorder.totalOfficialSettled(address(0)) == 0 && burnGate.refundLiability() == 25
                    && burnGate.refundableBalance(
                        burnGate.program(1).configHash, address(buyerSafe)
                    ) == 25,
                "free program only retains original caller reveal allowance"
            );
        }
        (ok,) = address(buyerSafe).call(a.safeCall);
        require(!ok && buyerSafe.nonce() == nonce + 1, "original Safe envelope cannot replay");
    }

    function _burnRoot(Vm.Log[] memory logs, uint256 source) private view returns (bytes32 root) {
        bytes32 topic = keccak256(
            "BurnMintBatchExecuted(uint16,uint256,bytes32,address,uint256[],address[],uint256[])"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(burnGate) && logs[i].topics[0] == topic) {
                require(
                    root == 0 && logs[i].topics[1] == bytes32(uint256(1))
                        && logs[i].topics[3] == bytes32(uint256(uint160(address(buyerSafe)))),
                    "one exact Burn batch context"
                );
                (
                    uint16 schema,
                    uint256[] memory sources,
                    address[] memory owners,
                    uint256[] memory targets
                ) = abi.decode(logs[i].data, (uint16, uint256[], address[], uint256[]));
                require(
                    schema == 1 && sources.length == 1 && sources[0] == source && owners.length == 1
                        && owners[0] == address(buyerSafe) && targets.length == 1
                        && targets[0] == core.lastAllocatedTokenId(),
                    "original source owner and target event arrays"
                );
                root = logs[i].topics[2];
            }
        }
        require(root != 0, "actual Manager operation root event");
    }

    function changeCollectionStatus(uint256 collection, uint8 next) external {
        require(msg.sender == address(this), "fixture only");
        bytes32 scope = _collectionScope(collection);
        bytes memory data = abi.encodeCall(core.setCollectionStatus, (collection, next));
        uint8 actionClass = next == 2 ? 2 : (next == 1 ? 0 : 1);
        GovernanceActionRequest memory request = _governanceRequest(
            actionClass,
            address(core),
            data,
            scope,
            _collectionConfig(collection, core.collectionStatus(collection)),
            _collectionConfig(collection, next)
        );
        bytes32 id = _scheduleAsGovernor(request);
        vm.warp(request.notBefore);
        _executeAsGovernor(id, data);
        require(core.collectionStatus(collection) == next, "actual governed Core status");
    }

    function blockSourceBurns() external {
        require(msg.sender == address(this), "fixture only");
        bytes32 scope = _collectionScope(SOURCE_COLLECTION);
        bytes32 domain = 0x0a834b49bdbe94b7d08a85a25431e3405b397e5f84bf90a90107edb2a58013ec;
        bytes memory data = abi.encodeCall(core.blockCollectionBurns, (SOURCE_COLLECTION));
        GovernanceActionRequest memory request = _governanceRequest(
            2,
            address(core),
            data,
            scope,
            keccak256(abi.encode(domain, scope, false)),
            keccak256(abi.encode(domain, scope, true))
        );
        bytes32 id = _scheduleAsGovernor(request);
        vm.warp(request.notBefore);
        _executeAsGovernor(id, data);
        require(
            core.collectionBurnsBlocked(SOURCE_COLLECTION)
                && core.collectionBurnsBlockedAtBlock(SOURCE_COLLECTION) != 0
                && !core.collectionFreezeStatus(SOURCE_COLLECTION),
            "actual burn block distinct from freeze"
        );
    }

    function changeTargetPhasePause(bool paused) external {
        require(msg.sender == address(this), "fixture only");
        bytes32 policy = manager.phasePolicyHash(1, BURN_PHASE);
        bytes memory data = abi.encodeCall(manager.setPhasePaused, (uint256(1), BURN_PHASE, paused));
        GovernanceActionRequest memory request = _governanceRequest(
            1,
            address(manager),
            data,
            keccak256(abi.encode(address(manager), data)),
            0,
            keccak256(data)
        );
        bytes32 id = _scheduleAsGovernor(request);
        vm.warp(request.notBefore);
        _executeAsGovernor(id, data);
        (, IStreamMintManager.MintPhaseConfig memory phase) = manager.phase(1, BURN_PHASE);
        require(
            phase.paused == paused && manager.phasePolicyHash(1, BURN_PHASE) == policy,
            "genuine phase pause preserves signed policy identity"
        );
    }

    function _collectionScope(uint256 collection) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                bytes32(0x3a882a22dad9915c9193738f63216234155080ed4c4fc9bfae446e90f1df6e16),
                block.chainid,
                address(core),
                collection
            )
        );
    }

    function _collectionConfig(uint256 collection, uint8 status) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                bytes32(0x854c83f82b7677e58c61a2482a7a430a8318d765d99a95d3fbce5c84be6cc2b5),
                _collectionScope(collection),
                true,
                core.collectionSupplyMode(collection),
                status,
                core.collectionHasMaxSupply(collection),
                core.collectionMaxSupply(collection)
            )
        );
    }

    function _configureSourceCollection() private {
        GovernanceCall[] memory calls = new GovernanceCall[](6);
        bytes[] memory data = new bytes[](6);
        (calls[0], data[0]) =
            StreamCurrentStackPlan.createCollectionCall(core, SOURCE_COLLECTION, 5);
        data[1] = abi.encodeCall(
            router.setCollectionMetadata,
            (
                SOURCE_COLLECTION,
                "Burn sources",
                "Independent source collection",
                "ipfs://burn-source",
                ""
            )
        );
        data[2] = abi.encodeCall(
            router.setCollectionScript, (SOURCE_COLLECTION, "burn source artwork")
        );
        data[3] = abi.encodeCall(
            royalties.configureCollectionRoyalty, (SOURCE_COLLECTION, profile, uint16(690))
        );
        data[4] = abi.encodeCall(
            primaryResolver.setPrimaryProfileAssignment,
            (PRIMARY_REVENUE_CLASS, uint8(1), SOURCE_COLLECTION, profile, bytes32(0))
        );
        data[5] = abi.encodeCall(
            entropy.configureCollection,
            (
                SOURCE_COLLECTION,
                address(provider),
                keccak256("burn source entropy"),
                true,
                uint64(100)
            )
        );
        address[5] memory targets = [
            address(router),
            address(router),
            address(royalties),
            address(primaryResolver),
            address(entropy)
        ];
        for (uint256 i = 1; i < calls.length; ++i) {
            calls[i] = StreamCurrentStackPlan.call(
                targets[i - 1],
                data[i],
                keccak256(abi.encode(targets[i - 1], data[i])),
                0,
                keccak256(data[i])
            );
        }
        _setupBatch(calls, data);
        entropy.configureCollectionRevealPolicy(
            SOURCE_COLLECTION, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 100, 0
        );
    }

    function _setupBatch(GovernanceCall[] memory calls, bytes[] memory data) private {
        (bytes32 scope, bytes32 oldState, bytes32 newState) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            calls, StreamGovernanceBootstrap.governanceCallsHash(calls)
        );
        uint64 ready = uint64(this.burnScenarioTime() + executor.minimumDelay(1));
        executor.publishGovernanceCallData(data);
        bytes memory scheduled = governanceRoot.execute(
            address(executor),
            0,
            abi.encodeCall(
                executor.scheduleGovernanceBatch,
                (
                    uint8(1),
                    calls,
                    scope,
                    oldState,
                    newState,
                    ready,
                    ready + 7 days,
                    keccak256("actual independent burn source"),
                    "ipfs://burn-source-setup",
                    DEPLOYMENT_HASH
                )
            )
        );
        vm.warp(ready);
        bytes32 id = abi.decode(scheduled, (bytes32));
        executor.executeGovernanceBatch(id, calls, data);
        require(
            executor.governanceAction(id).status == GovernanceActionStatus.EXECUTED,
            "real second collection governance"
        );
    }

    function _configureSourcePhase() private {
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = CAP;
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            5,
            1,
            keccak256("source cap")
        );
        IStreamMintManager.MintGateConfig memory gate;
        IStreamMintManager.MintPhaseConfig memory config = IStreamMintManager.MintPhaseConfig(
            false, 0, 0, 1, keccak256("source mint app"), keccak256("source metadata")
        );
        address[] memory allowed = new address[](0);
        _sourcePolicy(
            manager.previewPhasePolicyHash(
                SOURCE_COLLECTION, SEED_PHASE, config, gate, ids, counters, allowed
            )
        );
        manager.configurePhase(SOURCE_COLLECTION, SEED_PHASE, config, gate, ids, counters);
        allowed = new address[](1);
        allowed[0] = address(this);
        _sourcePolicy(
            manager.previewPhasePolicyHash(
                SOURCE_COLLECTION, SEED_PHASE, config, gate, ids, counters, allowed
            )
        );
        manager.setPhaseExecutor(SOURCE_COLLECTION, SEED_PHASE, address(this), true);
    }

    function _sourcePolicy(bytes32 hash) private {
        T.PolicyConsent memory p = T.PolicyConsent(SOURCE_COLLECTION, SEED_PHASE, hash);
        T.Authorization memory a = _artistAuthorization(false);
        a.signature = _artistProof(artists.policyConsentDigest(p, a));
        artists.recordPolicyConsent(p, a);
    }

    function _onboardSourceArtist(address artist_) private {
        bytes memory document = bytes("current-stack artist identity");
        T.BindingProposal memory p;
        p.artistId = fixtureArtistId;
        p.artistAddress = artist_;
        p.identityRecordHash = keccak256(document);
        p.identityRecordURI = "urn:6529stream:fixture:artist-identity";
        p.consentMode = 1;
        p.saleConsentScope = _fixtureSaleConsentScope();
        p.collaborators = new T.CollaboratorRecord[](0);
        p.capabilityPolicyOverrides = new T.CapabilityPolicyOverride[](0);
        (bytes32 sourceArtistId,) =
            artists.proposeArtistBinding(SOURCE_COLLECTION, p, document, "Stream Artist");
        require(sourceArtistId == fixtureArtistId, "same genuine Artist identity");
        T.Authorization memory a = _artistAuthorization(false);
        a.signature = _artistProof(artists.acceptanceDigest(SOURCE_COLLECTION, a));
        artists.acceptArtistBinding(SOURCE_COLLECTION, a);
        (T.AssignmentFact memory primary, T.AssignmentFact memory royalty) =
            artistCoordinator.reads().currentAssignments(SOURCE_COLLECTION);
        _sourceEconomics(primary);
        _sourceEconomics(royalty);
        (, bytes32 contentState) = router.currentArtistContentState(SOURCE_COLLECTION);
        T.Ratification memory ratification =
            T.Ratification(SOURCE_COLLECTION, address(router), contentState);
        a = _artistAuthorization(false);
        a.signature = _artistProof(artists.contentRatificationDigest(ratification, a));
        artists.recordContentRatification(ratification, a);
        T.Binding memory binding_ =
            IStreamArtistBindingOwner(artistSuite.owners[0]).binding(SOURCE_COLLECTION);
        bytes32 facts = StreamArtistHashes.deploymentFacts(
            StreamArtistHashes.Environment(
                block.chainid, address(artists), artistSuite.core, artistSuite.mintManager
            ),
            SOURCE_COLLECTION,
            binding_
        );
        _sourceAttestation(
            9,
            bytes32(uint256(uint160(artistSuite.core))),
            facts,
            keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1")
        );
        _sourceAttestation(
            10,
            fixtureArtistId,
            binding_.identityRecordHash,
            keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")
        );
    }

    function _sourceEconomics(T.AssignmentFact memory fact) private {
        T.EconomicsConsent memory p = T.EconomicsConsent(
            SOURCE_COLLECTION,
            fact.resolver,
            fact.revenueClass,
            fact.scope,
            fact.scopeId,
            fact.assignmentHash
        );
        T.Authorization memory a = _artistAuthorization(false);
        a.signature = _artistProof(artists.economicsConsentDigest(p, a));
        artists.recordEconomicsConsent(p, a);
    }

    function _sourceAttestation(uint8 kind, bytes32 subject, bytes32 state, bytes32 schema)
        private
    {
        bytes memory statement = abi.encode(kind, subject, state, schema);
        T.Attestation memory p = T.Attestation(
            SOURCE_COLLECTION,
            kind,
            subject,
            state,
            schema,
            keccak256(statement),
            "urn:6529stream:fixture:statement"
        );
        T.Authorization memory a = _artistAuthorization(true);
        a.signature = _artistProof(artists.attestationDigest(p, a));
        artists.recordArtistAttestation(p, a, statement);
    }
}
