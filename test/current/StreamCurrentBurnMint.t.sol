// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentStackFixture.sol";
import "../helpers/OfficialSafeFixture.sol";
import "../../smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol";
import "../../smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol";
import { StreamBurnMintGate } from "../../smart-contracts/domains/mint/StreamBurnMintGate.sol";
import {
    IStreamBurnMintGate as Burn
} from "../../smart-contracts/interfaces/stream/mint/IStreamBurnMintGate.sol";

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
contract StreamCurrentBurnMintTest is StreamCurrentStackFixture, OfficialSafeFixture {
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
    }

    function burnScenarioTime() external view returns (uint256) {
        return block.timestamp;
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(keys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function _deployAdditionalProducts() internal override {
        recorder = new StreamPrimarySaleSettlement(
            primaryResolver, address(registry), revenueEscrow
        );
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
        uint256[] memory ids = _seed();
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(burnGate),
                0,
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
}
