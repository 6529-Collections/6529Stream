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
    IStreamBurnMintGate as Burn
} from "../../smart-contracts/interfaces/stream/mint/IStreamBurnMintGate.sol";
import {
    IStreamNativeSurplus as BurnSurplus
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeSurplus.sol";
import { StreamNativeSurplus } from "../../smart-contracts/domains/mint/StreamNativeSurplus.sol";
import { ReentrancyGuard } from "../../smart-contracts/vendor/openzeppelin/ReentrancyGuard.sol";

interface CurrentBurnCallVm {
    function expectCall(address, uint256, bytes calldata, uint64) external;
    function expectEmit(bool, bool, bool, bool, address) external;
}

contract CurrentBurnForcedNative {
    constructor(address payable target) payable {
        selfdestruct(target);
    }
}

contract CurrentBurnSurplusRecipient {
    StreamBurnMintGate private immutable gate;
    bytes32 private immutable key;
    bool public rejects;
    bool public reentered;
    bytes public callbackError;
    uint256 private donation;

    constructor(StreamBurnMintGate gate_, bytes32 key_) {
        gate = gate_;
        key = key_;
    }

    function configure(bool reject_, uint256 donation_) external {
        rejects = reject_;
        donation = donation_;
    }

    receive() external payable {
        require(!rejects, "burn surplus recipient rejects");
        (reentered, callbackError) =
            address(gate).call(abi.encodeCall(gate.claimRefund, (key, address(this))));
        if (donation != 0) new CurrentBurnForcedNative{ value: donation }(payable(address(gate)));
    }
}

contract CurrentBurnMintReceiver is IERC721Receiver {
    bool public rejects;
    address public callback;
    bytes public data;
    bool public callbackSucceeded;

    function configure(bool reject_, address target, bytes calldata input) external {
        rejects = reject_;
        callback = target;
        data = input;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        if (callback != address(0)) (callbackSucceeded,) = callback.call(data);
        require(!rejects, "burn mint recipient rejects");
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice Whole current Core/Manager/Ledger/Artist/registry/recorder/native adapter joins and threshold Safes.
/// @dev The shared fixture's external entropy provider remains the explicit service boundary.
contract StreamCurrentBurnMintTest is CurrentCommerceConservationFixture {
    bytes32 private constant BURN_PHASE = keccak256("current burn mint phase");
    bytes32 private constant SEED_PHASE = keccak256("current burn sources");
    bytes32 private constant CAP = keccak256("burn supply");
    StreamBurnMintGate private burnGate;
    StreamNativeFixedPriceSaleAdapter private nativeSale;
    StreamPrimarySaleSettlement private recorder;
    OfficialSafe private artistSafe;
    OfficialSafe private buyerSafe;
    uint256[] private keys;
    bool private nativeMode;
    bytes32 private nativeId;
    bytes32 private constant BURN_SURPLUS_REASON =
        keccak256("recover unsolicited burn gate native value");
    bytes32 private constant EMERGENCY = keccak256("ROLE_EMERGENCY_RECIPIENT");
    event AdapterSurplusSwept(
        uint16 schemaVersion, address indexed to, address asset, uint256 amount, bytes32 actionId
    );

    function setUp() public {
        keys.push(0xB001);
        keys.push(0xB002);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        artistSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 201);
        buyerSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 202);
        vm.deal(address(buyerSafe), 1 ether);
    }

    function deployBurnScenario(bool paid) external {
        require(msg.sender == address(this), "fixture only");
        nativeMode = paid;
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
        if (paid) {
            _installBurnCommerceGovernor();
            _enableWaivedCommerceFloor();
        }
    }

    function _installBurnCommerceGovernor() private {
        uint256[] memory governanceKeys = new uint256[](2);
        governanceKeys[0] = 0x6001;
        governanceKeys[1] = 0x6002;
        OfficialSafe next = createOfficialSafe(
            deploySafeComponents("1.4.1"), safeOwnerAddresses(governanceKeys), 2, 203
        );
        _installGovernorSafe(next, governanceKeys);
    }

    function burnScenarioTime() external view returns (uint256) {
        return block.timestamp;
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(keys, safeMessageDigest(artistSafe, abi.encode(digest)));
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
        rows = new GovernanceActionPolicyEntry[](1);
        rows[0] = GovernanceActionPolicyEntry(
            1,
            address(burnGate),
            BurnSurplus.sweepNativeSurplus.selector,
            address(burnGate).codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, address(burnGate))),
            1,
            0,
            0,
            bytes32(0)
        );
        rows = _commerceFloorPolicies(rows);
    }

    function _configureAdditionalProducts() internal override {
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](2);
        records[0] = StreamModuleRegistration(
            address(nativeSale),
            keccak256("NATIVE_PRIMARY_SALE_ADAPTER"),
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1"),
            type(IStreamNativeSaleBinding).interfaceId,
            500000,
            address(nativeSale).codehash,
            DEPLOYMENT_HASH,
            keccak256("native burn sale"),
            "urn:fixture:native-burn"
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
                    "urn:fixture:burn",
                    DEPLOYMENT_HASH
                )
            )
        );
        vm.warp(ready);
        executor.executeGovernanceBatch(abi.decode(scheduled, (bytes32)), calls, data);
        uint256[] memory sources = new uint256[](1);
        sources[0] = 1;
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
        _configureMintPhase(SEED_PHASE, address(this));
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
        b.collectionId = 1;
        b.phaseId = phase;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = recipient;
        b.beneficiaries = b.initialRecipients;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = TOKEN_DATA;
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = keccak256(abi.encode(phase, recipient));
        b.expectedPolicyHash = manager.phasePolicyHash(1, phase);
        b.authorizationId = keccak256(abi.encode("request", phase, recipient));
    }

    function _seed() private returns (uint256[] memory ids) {
        (ids,,) = manager.executeSingleStepMint(_batch(SEED_PHASE, address(buyerSafe)), "");
        require(
            executeSafe(
                buyerSafe,
                keys,
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
            uint64(this.burnScenarioTime() + 1 days),
            _nativePrimaryPolicyHash()
        );
        e.tokenData = TOKEN_DATA;
        bytes32 digest = nativeSale.authorizationDigest(e.authorization);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        e.platformSignature = abi.encodePacked(r, s, v);
        e.artistSignature =
            safeThresholdSignature(keys, safeMessageDigest(artistSafe, abi.encode(digest)));
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
                safeThresholdSignature(keys, digest)
            )
        );
    }

    function testCurrentFreeBurnManagerLedgerAndSafeRecipient() public {
        this.deployBurnScenario(false);
        (address floor,) = core.conservationFloor();
        require(
            floor == address(0) && core.declaredConservationTier(1) == 0,
            "free burn has no implicit waiver"
        );
        uint256[] memory ids = _seed();
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(burnGate),
                25,
                abi.encodeCall(burnGate.burnAndMint, (_batch(BURN_PHASE, address(buyerSafe)), ids)),
                0
            ),
            "Safe burns and mints"
        );
        (bool exists, uint256 collection,, bool burned) = core.tokenCollectionIdentity(ids[0]);
        require(
            exists && collection == 1 && burned
                && manager.isNullifierUsed(burnGate.burnNullifier(ids[0])),
            "actual retained identity and ledger"
        );
        require(
            core.ownerOf(core.lastAllocatedTokenId()) == address(buyerSafe)
                && core.collectionMintedEver(1) == 2,
            "actual mint"
        );
        require(recorder.totalOfficialSettled(address(0)) == 0, "free no settlement");
        bytes32 programHash = burnGate.program(1).configHash;
        require(
            burnGate.refundableBalance(programHash, address(buyerSafe)) == 25
                && burnGate.refundLiability() == 25,
            "zero declared fee leaves Safe maximum allowance refundable"
        );
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(burnGate),
                0,
                abi.encodeCall(burnGate.claimRefund, (programHash, address(buyerSafe))),
                0
            ),
            "Safe claims free burn allowance"
        );
        require(
            address(buyerSafe).balance == 1 ether && burnGate.refundLiability() == 0,
            "zero fee burns no buyer value"
        );
    }

    function testCurrentNativeBurnPaymentRefundOwnerAndReceiverRollbackSafeRetry() public {
        this.deployBurnScenario(true);
        uint256[] memory sources = _seed();
        CurrentBurnMintReceiver receiver = new CurrentBurnMintReceiver();
        receiver.configure(true, address(0), "");
        IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e =
            _nativeExecution(address(receiver));
        bytes memory signedCall = _safeCall(
            address(nativeSale), 1250, abi.encodeCall(nativeSale.purchaseWithBurn, (e, sources))
        );
        (bool ok,) = address(buyerSafe).call(signedCall);
        require(!ok, "receiver rolls back whole signed Safe transaction");
        require(
            core.ownerOf(sources[0]) == address(buyerSafe)
                && recorder.totalOfficialSettled(address(0)) == 0
                && !manager.isNullifierUsed(burnGate.burnNullifier(sources[0]))
                && nativeSale.refundLiability() == 0,
            "source/payment/replay/refund rollback"
        );
        receiver.configure(
            false,
            address(nativeSale),
            abi.encodeCall(
                nativeSale.executeBurnPurchase, (e, address(buyerSafe), uint256(1250), sources)
            )
        );
        (ok,) = address(buyerSafe).call(signedCall);
        require(ok, "byte-identical signed Safe retry");
        require(
            !receiver.callbackSucceeded()
                && core.ownerOf(core.lastAllocatedTokenId()) == address(receiver),
            "one-use callback and target recipient"
        );
        require(
            recorder.totalOfficialSettled(address(0)) == 1000
                && nativeSale.refundableBalance(nativeId, address(buyerSafe)) == 250
                && nativeSale.refundableBalance(nativeId, address(burnGate)) == 0,
            "original payer owns all excess"
        );
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(nativeSale),
                0,
                abi.encodeCall(nativeSale.claimRefund, (nativeId, address(buyerSafe))),
                0
            ),
            "Safe refund claim"
        );
        require(address(buyerSafe).balance == 1 ether - 1000, "payer pays price only");
    }

    /// @dev External setup/time boundaries prevent via-IR from reusing timestamps across test warps.
    function prepareCurrentBurnSurplus()
        external
        returns (CurrentBurnSurplusRecipient recipient, bytes32 key)
    {
        require(msg.sender == address(this), "fixture only");
        this.deployBurnScenario(false);
        uint256[] memory sources = _seed();
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(burnGate),
                25,
                abi.encodeCall(
                    burnGate.burnAndMint, (_batch(BURN_PHASE, address(buyerSafe)), sources)
                ),
                0
            ),
            "actual Safe burn creates credit"
        );
        key = burnGate.program(1).configHash;
        require(
            burnGate.refundableBalance(key, address(buyerSafe)) == 25
                && burnGate.refundLiability() == 25,
            "actual buyer liability"
        );
        if (address(governorSafe) == address(0)) _installBurnCommerceGovernor();
        (address floor,) = core.conservationFloor();
        require(
            floor == address(0) && core.declaredConservationTier(1) == 0,
            "free surplus recovery retains unbound undeclared collection"
        );
        recipient = new CurrentBurnSurplusRecipient(burnGate, key);
        while (roles.roleHolderCount(EMERGENCY) != 0) {
            this.setCurrentBurnEmergency(roles.roleHolderAt(EMERGENCY, 0), false);
        }
        this.setCurrentBurnEmergency(address(recipient), true);
        vm.deal(address(this), 100);
        new CurrentBurnForcedNative{ value: 100 }(payable(address(burnGate)));
    }

    function setCurrentBurnEmergency(address holder, bool granted) external {
        require(msg.sender == address(this), "fixture only");
        (GovernanceCall memory call_, bytes memory data) = _roleCall(EMERGENCY, holder, granted);
        _govern(
            _burnRequest(
                call_.target, data, call_.scopeHash, call_.oldValueHash, call_.newValueHash
            )
        );
        require(roles.hasRole(EMERGENCY, holder) == granted, "actual emergency role mutation");
    }

    function _burnRequest(
        address target,
        bytes memory data,
        bytes32 scope,
        bytes32 before_,
        bytes32 after_
    ) private view returns (GovernanceActionRequest memory request) {
        request = _governanceRequest(1, target, data, scope, before_, after_);
        request.notBefore = uint64(this.burnScenarioTime() + executor.minimumDelay(1));
        request.expiresAfter = request.notBefore + 7 days;
    }

    function _burnSweepRequest(BurnSurplus.NativeSurplusQuote memory q)
        private
        view
        returns (GovernanceActionRequest memory)
    {
        return _burnRequest(
            address(burnGate),
            abi.encodeCall(burnGate.sweepNativeSurplus, (q.amount, q.reasonHash)),
            q.scopeHash,
            q.oldValueHash,
            q.newValueHash
        );
    }

    function _assertCurrentBurnQuote(BurnSurplus.NativeSurplusQuote memory q, address recipient)
        private
        view
    {
        require(
            q.state.balance == 125 && q.state.liabilities == 25 && q.state.available == 100,
            "only forced ETH available"
        );
        StreamNativeSurplus.Context memory context = StreamNativeSurplus.Context(
            address(core),
            address(core).codehash,
            address(registry),
            address(registry).codehash,
            address(executor)
        );
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_SURPLUS_SCOPE_V1"),
                block.chainid,
                address(burnGate),
                context
            )
        );
        bytes32 request = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_SURPLUS_REQUEST_V1"),
                q.amount,
                BURN_SURPLUS_REASON,
                q.authority
            )
        );
        require(
            q.scopeHash == scope && q.reasonHash == BURN_SURPLUS_REASON
                && q.oldValueHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_NATIVE_SURPLUS_STATE_V1"),
                            scope,
                            request,
                            uint256(25),
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
                            uint256(25),
                            uint64(1),
                            q.amount
                        )
                    ),
            "independent gate scope and exact liability transition"
        );
        (bytes32 chain, uint64 revision) = roles.roleMutationState(EMERGENCY);
        require(
            q.authority.executor == address(executor)
                && q.authority.executorCodeHash == address(executor).codehash
                && q.authority.roleRegistry == address(roles)
                && q.authority.roleRegistryCodeHash == address(roles).codehash
                && q.authority.recipient == recipient && q.authority.roleChainHash == chain
                && q.authority.roleRevision == revision,
            "actual canonical recipient witness"
        );
    }

    function _claimCurrentBurnCredit(bytes32 key, uint256 surplus) private {
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(burnGate),
                0,
                abi.encodeCall(burnGate.claimRefund, (key, address(buyerSafe))),
                0
            ),
            "original buyer Safe claims"
        );
        require(
            address(buyerSafe).balance == 1 ether && burnGate.refundLiability() == 0
                && address(burnGate).balance == surplus
                && burnGate.nativeSurplusState().available == surplus,
            "original credit remains withdrawable independently"
        );
        require(
            core.ownerOf(core.lastAllocatedTokenId()) == address(buyerSafe)
                && core.collectionMintedEver(1) == 2
                && recorder.totalOfficialSettled(address(0)) == 0,
            "sweep and claim do not alter NFT or revenue"
        );
    }

    function testCurrentBurnSurplusSafeGovernancePreservesCreditAndRejectsClaimReentry() public {
        (CurrentBurnSurplusRecipient recipient, bytes32 key) = this.prepareCurrentBurnSurplus();
        recipient.configure(false, 3);
        BurnSurplus.NativeSurplusQuote memory q =
            burnGate.nativeSurplusQuote(60, BURN_SURPLUS_REASON);
        _assertCurrentBurnQuote(q, address(recipient));
        vm.expectRevert(
            abi.encodeWithSelector(BurnSurplus.AdapterSurplusUnderfunded.selector, address(0))
        );
        burnGate.nativeSurplusQuote(101, BURN_SURPLUS_REASON);
        vm.expectRevert(
            abi.encodeWithSelector(
                BurnSurplus.NativeSurplusAuthorityInvalid.selector, address(this)
            )
        );
        burnGate.sweepNativeSurplus(60, BURN_SURPLUS_REASON);
        GovernanceActionRequest memory request = _burnSweepRequest(q);
        bytes32 id = _scheduleAsGovernor(request);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionNotExecutable.selector,
                id,
                request.notBefore
            )
        );
        executor.executeGovernanceAction(id, request.callData);
        vm.warp(request.notBefore);
        CurrentBurnCallVm(address(vm)).expectEmit(true, false, false, true, address(burnGate));
        emit AdapterSurplusSwept(1, address(recipient), address(0), 60, id);
        _executeAsGovernor(id, request.callData);
        require(
            !recipient.reentered()
                && keccak256(recipient.callbackError())
                    == keccak256(
                        abi.encodeWithSelector(
                            ReentrancyGuard.ReentrancyGuardReentrantCall.selector
                        )
                    ),
            "exact shared guard blocks refund callback"
        );
        BurnSurplus.NativeSurplusState memory after_ = burnGate.nativeSurplusState();
        require(
            after_.balance == 68 && after_.liabilities == 25 && after_.available == 43
                && after_.revision == 1 && after_.cumulativeSwept == 60 && after_.lastActionId == id
                && burnGate.nativeSurplusActionUsed(id) && address(recipient).balance == 57,
            "surplus donation and buyer liability conserved"
        );
        this.setCurrentBurnEmergency(address(recipient), false);
        _claimCurrentBurnCredit(key, 43);
    }

    function _signedCurrentGovernorSweep(bytes32 id, bytes memory data)
        private
        returns (bytes memory)
    {
        bytes memory callData = abi.encodeCall(executor.executeGovernanceAction, (id, data));
        bytes32 digest = governorSafe.getTransactionHash(
            address(executor), 0, callData, 0, 0, 0, 0, address(0), address(0), governorSafe.nonce()
        );
        return abi.encodeCall(
            governorSafe.execTransaction,
            (
                address(executor),
                uint256(0),
                callData,
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

    function testCurrentBurnSurplusFailedRecipientRetriesIdenticalSignedSafeTransaction() public {
        (CurrentBurnSurplusRecipient recipient, bytes32 key) = this.prepareCurrentBurnSurplus();
        BurnSurplus.NativeSurplusQuote memory q =
            burnGate.nativeSurplusQuote(100, BURN_SURPLUS_REASON);
        _assertCurrentBurnQuote(q, address(recipient));
        GovernanceActionRequest memory request = _burnSweepRequest(q);
        bytes32 id = _scheduleAsGovernor(request);
        vm.warp(request.notBefore);
        recipient.configure(true, 0);
        bytes memory signedCall = _signedCurrentGovernorSweep(id, request.callData);
        uint256 nonce = governorSafe.nonce();
        CurrentBurnCallVm(address(vm)).expectCall(address(recipient), 100, bytes(""), 2);
        (bool ok, bytes memory result) = address(governorSafe).call(signedCall);
        require(
            !ok
                && keccak256(result)
                    == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
            "actual rejected Safe transfer"
        );
        BurnSurplus.NativeSurplusState memory failed = burnGate.nativeSurplusState();
        require(
            failed.balance == 125 && failed.liabilities == 25 && failed.available == 100
                && failed.revision == 0 && failed.cumulativeSwept == 0 && failed.lastActionId == 0
                && !burnGate.nativeSurplusActionUsed(id) && governorSafe.nonce() == nonce
                && executor.governanceAction(id).status == GovernanceActionStatus.SCHEDULED,
            "failure preserves all balances and both replay ledgers"
        );
        recipient.configure(false, 0);
        (ok, result) = address(governorSafe).call(signedCall);
        require(
            ok && abi.decode(result, (bool)) && governorSafe.nonce() == nonce + 1
                && address(recipient).balance == 100 && burnGate.nativeSurplusActionUsed(id)
                && executor.governanceAction(id).status == GovernanceActionStatus.EXECUTED,
            "byte identical governor Safe retry completes"
        );
        require(
            burnGate.nativeSurplusState().balance == 25 && burnGate.refundLiability() == 25,
            "governance never spends buyer allowance"
        );
        (ok,) = address(governorSafe).call(signedCall);
        require(!ok, "signed Safe transaction cannot replay");
        _claimCurrentBurnCredit(key, 0);
    }
}
