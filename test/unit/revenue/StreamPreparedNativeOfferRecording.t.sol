// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/NativeEnglishAuctionFixture.sol";
import "../../../smart-contracts/domains/revenue/StreamPreparedNativeOfferRecording.sol";
import "../../../smart-contracts/domains/mint/StreamNativePrimaryOfferGate.sol";

interface OfferRecorderVm {
    function mockCall(address target, bytes calldata data, bytes calldata result) external;
    function clearMockedCalls() external;
}

/// @dev Explicit active-sale fixture; signatures and Manager execution are tested by their owners.
/// The actual recorder below still checks every registry, pointer, active-state and funding join.
contract OfferRecorderSaleBoundary is ERC165 {
    address public immutable core;
    address public immutable moduleRegistry;
    address public immutable mintManager;
    address public immutable revenueResolver;
    address public immutable primarySaleSettlement;
    bytes32 public immutable settlementCodeHash;
    address public immutable wallet;
    uint256 public fault;
    StreamNativeSettlementTypes.SaleLifecycleBinding private _lifecycle;
    StreamPreparedNativeSettlementTypes.Intent private _intent;
    StreamPreparedNativeOfferTypes.Purchase private _purchase;
    bytes32 private _hash;

    constructor(
        StreamMintManager manager,
        StreamPrimarySaleSettlement recorder,
        address destination
    ) {
        core = address(manager.core());
        moduleRegistry = address(manager.moduleRegistry());
        mintManager = address(manager);
        revenueResolver = address(recorder.revenueResolver());
        primarySaleSettlement = address(recorder);
        settlementCodeHash = address(recorder).codehash;
        wallet = destination;
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamPreparedNativeSaleBinding).interfaceId
            || id == type(IStreamPreparedNativeOfferSale).interfaceId || super.supportsInterface(id);
    }

    function open() external {
        _lifecycle = StreamPreparedNativeSettlementAdmission.capture(moduleRegistry, address(this));
    }

    function setFault(uint256 value) external {
        fault = value;
    }

    function configure(
        StreamPreparedNativeSettlementTypes.Intent calldata intent,
        StreamPreparedNativeOfferTypes.Purchase calldata purchase,
        bytes32 hash
    ) external {
        _intent = intent;
        _purchase = purchase;
        _hash = hash;
    }

    function preparedNativeSaleLifecycle(bytes32 id)
        external
        view
        returns (StreamNativeSettlementTypes.SaleLifecycleBinding memory)
    {
        require(id == _intent.saleId, "original sale");
        return _lifecycle;
    }

    function activePreparedNativeOfferIntent(bytes32 hash)
        external
        view
        returns (StreamPreparedNativeSettlementTypes.Intent memory result)
    {
        require(hash == _hash, "active offer only");
        result = _intent;
        if (fault == 1 && wallet.balance != 0) {
            result.saleAuthorizationDigest = keccak256("post-funding seller mutation");
        }
        if (fault == 2) {
            bytes memory malformed = bytes.concat(abi.encode(result), abi.encode(uint256(0)));
            assembly ("memory-safe") { return(add(malformed, 32), mload(malformed)) }
        }
    }

    function activePreparedNativeOfferPurchase(bytes32 hash)
        external
        view
        returns (StreamPreparedNativeOfferTypes.Purchase memory result)
    {
        require(hash == _hash, "active offer only");
        result = _purchase;
        if (fault == 3 && wallet.balance != 0) {
            result.saleConfigHash = keccak256("post-funding purchase mutation");
        }
    }

    function record(
        StreamPreparedNativeSettlementTypes.Facts calldata facts,
        StreamPreparedNativeSettlementTypes.Intent calldata intent
    ) external payable returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory) {
        return IStreamPreparedNativeOfferSettlement(primarySaleSettlement)
        .settlePreparedNativeOffer{ value: msg.value }(
            facts, intent
        );
    }

    function recordUsingOldEntry(
        StreamPreparedNativeSettlementTypes.Facts calldata facts,
        StreamPreparedNativeSettlementTypes.Intent calldata intent
    ) external payable returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory) {
        return IStreamPreparedNativeContentPurchaseSettlement(primarySaleSettlement)
        .settlePreparedNativeContentPurchase{ value: msg.value }(
            facts, intent
        );
    }
}

/// @notice Real official recorder, registry/pointers, resolver, wallet and escrow; the singleton
/// prepared Core/Manager/Ledger getters are narrowly mocked to isolate this recorder boundary.
/// This suite does not claim real offer signature admission, token allocation or mint completion.
contract StreamPreparedNativeOfferRecordingTest is NativeEnglishAuctionFixture {
    OfferRecorderVm private constant recorderVm =
        OfferRecorderVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    OfferRecorderSaleBoundary private offerSale;
    StreamPreparedNativeSettlementTypes.Facts private facts;
    StreamPreparedNativeSettlementTypes.Intent private intent;
    StreamPreparedNativeOfferTypes.Purchase private purchase;
    StreamPreparedNativeContentTypes.Facts private content;

    function setUp() public override {
        super.setUp();
        offerSale = new OfferRecorderSaleBoundary(manager, recorder, wallet);
        _register(
            address(offerSale),
            keccak256("NATIVE_PREPARED_SALE_ADAPTER"),
            type(IStreamPreparedNativeSaleBinding).interfaceId,
            keccak256("6529STREAM_PREPARED_NATIVE_SETTLEMENT_V1")
        );
        offerSale.open();
        manager.setPhaseExecutor(1, PHASE, address(offerSale), true);
        _recipe();
        _arm();
    }

    function testUnselectedOfferFundsActualWalletAndRecordsSeparateDigestsAndReplayMap() public {
        vm.recordLogs();
        StreamPrimarySettlementTypes.PrimarySettlementResult memory result = _record();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 execution = StreamPreparedNativeSettlementHash.executionId(facts, intent);
        bytes32 key = recorder.settlementKey(address(offerSale), execution);
        require(
            result.settlementKey == key && result.executionId == execution && result.amount == 1000
                && result.executor == payer && result.profileId == profile
                && result.wallet == wallet && result.asset == address(0)
                && result.operationIdentityCommitment == facts.operationRoot && !result.escrowed,
            "original prepared execution identity and actual positive native rights"
        );
        require(
            wallet.balance == 1000 && address(recorder).balance == 0
                && recorder.totalOfficialSettled(address(0)) == 1000
                && recorder.officialSettled(CLASS, profile, wallet, address(0)) == 1000
                && recorder.settlementConsumed(key)
                && recorder.preparedNativeOfferConsumed(address(offerSale), purchase.purchaseId)
                && !recorder.preparedNativeContentPurchaseConsumed(
                    address(offerSale), purchase.purchaseId
                )
                && !recorder.preparedNativeSaleConsumed(
                    recorder.preparedNativeSaleKey(
                        address(offerSale), intent.saleId, intent.saleNonce
                    )
                ),
            "offer map appended independently with shared official accounting"
        );
        require(
            recorder.preparedNativeFactsHash(key)
                    == StreamPreparedNativeSettlementHash.factsHash(facts)
                && recorder.preparedNativeContentHash(key)
                    == StreamPreparedNativeContentHash.factsHash(content),
            "original facts and explicit unselected token facts retained"
        );
        bytes32 eventId = keccak256(
            "PreparedNativeOfferRecorded(uint16,address,bytes32,bytes32,bytes32,uint256,bytes32,bytes32)"
        );
        uint256 found;
        for (uint256 n; n < logs.length; ++n) {
            if (logs[n].emitter != address(recorder)) continue;
            require(
                logs[n].topics[0]
                    != keccak256(
                        "PreparedNativeContentPurchaseRecorded(uint16,address,bytes32,bytes32,bytes32,uint256)"
                    ),
                "unselected offer never claims the older private-content event"
            );
            if (logs[n].topics[0] != eventId) continue;
            (uint16 schema, bytes32 id, uint256 nonce, bytes32 buyerDigest, bytes32 sellerDigest) =
                abi.decode(logs[n].data, (uint16, bytes32, uint256, bytes32, bytes32));
            require(
                schema == 1 && id == intent.saleId && nonce == intent.saleNonce
                    && buyerDigest == purchase.offerDigest
                    && sellerDigest == intent.saleAuthorizationDigest && buyerDigest != sellerDigest
                    && logs[n].topics[1] == bytes32(uint256(uint160(address(offerSale))))
                    && logs[n].topics[2] == purchase.purchaseId && logs[n].topics[3] == key,
                "specific offer receipt separates original buyer and seller digests"
            );
            ++found;
        }
        require(found == 1, "one canonical offer receipt");
    }

    function testOfferPurchaseReplayCannotFundTwice() public {
        _record();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamPreparedNativeOfferSettlement.PreparedNativeOfferAlreadySettled.selector,
                address(offerSale),
                purchase.purchaseId
            )
        );
        _record();
        require(
            wallet.balance == 1000 && recorder.totalOfficialSettled(address(0)) == 1000,
            "durable offer purchase replay"
        );
    }

    function testOfferCannotEnterOriginalContentPurchaseRecorder() public {
        vm.prank(payer);
        vm.expectRevert();
        offerSale.recordUsingOldEntry{ value: 1000 }(facts, intent);
        _assertEmpty();
        _record();
        require(wallet.balance == 1000, "new explicit boundary still available");
    }

    function testWrongCallerAndExactNativeAmountRejectBeforeFunding() public {
        vm.prank(payer);
        vm.expectRevert();
        recorder.settlePreparedNativeOffer{ value: 1000 }(facts, intent);
        vm.prank(payer);
        vm.expectRevert();
        offerSale.record{ value: 999 }(facts, intent);
        vm.prank(payer);
        vm.expectRevert();
        offerSale.record{ value: 1001 }(facts, intent);
        _assertEmpty();
    }

    function testFuzzUnsignedAllowCurrentZeroPriceOrForeignBeneficiaryCannotRecord(uint8 mutation)
        public
    {
        if (mutation % 4 == 0) {
            intent.authorityMode = 2;
        } else if (mutation % 4 == 1) {
            intent.primaryPolicyMode = 1;
        } else if (mutation % 4 == 2) {
            intent.amount = 0;
        } else {
            intent.beneficiary = address(0xBAD);
            facts.beneficiary = intent.beneficiary;
        }
        _arm();
        vm.expectRevert();
        _record();
        _assertEmpty();
    }

    function testDifferentCurrentPrimaryPolicyFailsStrictMatch() public {
        intent.originalPrimaryPolicyHash = keccak256("other primary rights");
        _arm();
        vm.expectRevert();
        _record();
        _assertEmpty();
    }

    function testSellerAuthorizationCannotReplaceBuyerOfferTicket() public {
        purchase.authorizationId =
            StreamMintTicketHash.authorizationId(intent.saleAuthorizationDigest);
        _arm();
        vm.expectRevert();
        _record();
        _assertEmpty();
    }

    function testInactiveAdmissionAndUnconsumedBuyerAuthorizationFailClosed() public {
        recorderVm.mockCall(
            address(manager),
            abi.encodeCall(IStreamPreparedNativeOfferMint.preparedNativeOfferAdmission, ()),
            abi.encode(bytes32(0))
        );
        vm.expectRevert();
        _record();
        _arm();
        recorderVm.mockCall(
            address(ledger),
            abi.encodeCall(
                IStreamMintLedger.isManagerAuthorizationUsed,
                (address(manager), purchase.authorizationId)
            ),
            abi.encode(false)
        );
        vm.expectRevert();
        _record();
        _assertEmpty();
    }

    function testActualCorePendingIdentityAndConsumedOperationRemainMandatory() public {
        recorderVm.mockCall(
            address(core),
            abi.encodeCall(IStreamCoreMint.preparedMint, (uint256(1))),
            abi.encode(StreamPreparedMintRecord(true, keccak256("different operation"), 1))
        );
        vm.expectRevert();
        _record();
        _arm();
        recorderVm.mockCall(
            address(ledger),
            abi.encodeCall(
                IStreamMintLedger.isManagerOperationRootUsed,
                (address(manager), facts.operationRoot)
            ),
            abi.encode(false)
        );
        vm.expectRevert();
        _record();
        _assertEmpty();
    }

    function testMalformedActiveOfferIntentShapeFailsAndExactOriginalRetries() public {
        offerSale.setFault(2);
        vm.expectRevert();
        _record();
        _assertEmpty();
        offerSale.setFault(0);
        _record();
        require(wallet.balance == 1000, "exact original tuple after fixed-size read repair");
    }

    function testUnselectedOfferCannotSmuggleSelectedContentFacts() public {
        content.contentLeaf = keccak256("undeclared selected leaf");
        content.counterId = keccak256("undeclared selected counter");
        _arm();
        vm.expectRevert();
        _record();
        _assertEmpty();
    }

    function testSelectedOfferCannotUseUnselectedNoGateAdmission() public {
        intent.contentSelectionHash = keccak256("selected leaf without publication");
        _arm();
        vm.expectRevert();
        _record();
        _assertEmpty();
    }

    function testSelectedOfferRequiresActualPublicationAndExactlyConsumedCapOne() public {
        bytes32 key = _selected();
        recorderVm.mockCall(
            address(ledger),
            abi.encodeCall(IStreamMintLedger.counterValue, (key)),
            abi.encode(uint64(0))
        );
        vm.expectRevert();
        _record();
        _assertEmpty();
        recorderVm.mockCall(
            address(ledger),
            abi.encodeCall(IStreamMintLedger.counterValue, (key)),
            abi.encode(uint64(2))
        );
        vm.expectRevert();
        _record();
        _assertEmpty();
        recorderVm.mockCall(
            address(ledger),
            abi.encodeCall(IStreamMintLedger.counterValue, (key)),
            abi.encode(uint64(1))
        );
        StreamPrimarySettlementTypes.PrimarySettlementResult memory result = _record();
        require(
            result.amount == 1000 && wallet.balance == 1000
                && content.contentLeaf == intent.contentSelectionHash
                && recorder.preparedNativeContentHash(result.settlementKey)
                    == StreamPreparedNativeContentHash.factsHash(content),
            "selected offer receipt joins real declared manifest and consumed cap1 fixture"
        );
    }

    function testPostFundingIntentMutationRevertsPaymentReplayAndOfficialRecordsThenRetries()
        public
    {
        _postFundingRetry(1);
    }

    function testPostFundingPurchaseMutationRevertsPaymentReplayAndOfficialRecordsThenRetries()
        public
    {
        _postFundingRetry(3);
    }

    function testReferencedSaleIncidentRejectsWithoutFunding() public {
        _status(address(offerSale), ModuleRegistryStatus.INCIDENT_REVOKED);
        vm.expectRevert();
        _record();
        _assertEmpty();
    }

    function _postFundingRetry(uint256 fault) private {
        offerSale.setFault(fault);
        uint256 before = payer.balance;
        vm.expectRevert();
        _record();
        require(payer.balance == before, "failed post-funding check restores buyer value");
        _assertEmpty();
        offerSale.setFault(0);
        _record();
        require(
            wallet.balance == 1000
                && recorder.preparedNativeOfferConsumed(address(offerSale), purchase.purchaseId),
            "identical original offer facts retry atomically"
        );
    }

    function _record()
        private
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory)
    {
        vm.prank(payer);
        return offerSale.record{ value: 1000 }(facts, intent);
    }

    function _assertEmpty() private view {
        bytes32 key = recorder.settlementKey(
            address(offerSale), StreamPreparedNativeSettlementHash.executionId(facts, intent)
        );
        require(
            wallet.balance == 0 && address(recorder).balance == 0
                && recorder.totalOfficialSettled(address(0)) == 0
                && !recorder.settlementConsumed(key)
                && !recorder.preparedNativeOfferConsumed(address(offerSale), purchase.purchaseId)
                && recorder.preparedNativeFactsHash(key) == 0
                && recorder.preparedNativeContentHash(key) == 0
                && recorder.settlementResult(key).amount == 0,
            "no partial recorder or wallet effects"
        );
    }

    function _recipe() private {
        intent.collectionId = 1;
        intent.phaseId = PHASE;
        intent.saleId = keccak256("isolated original primary offer");
        intent.saleNonce = 3;
        intent.executor = payer;
        intent.payer = payer;
        intent.poster = address(this);
        intent.beneficiary = payer;
        intent.amount = 1000;
        intent.originalPrimaryPolicyHash =
            StreamNativeEnglishAuctionSupport.profilePolicy(resolver, 1);
        intent.executionNonce = 7;
        intent.authorityMode = 1;
        intent.saleAuthorizationDigest =
            keccak256("full original seller authorization digest fixture");
        intent.saleExecutionHash = keccak256("host offer execution fixture");
        intent.mintCommitment = keccak256("offer mint commitment");
        intent.boundMintPolicyHash = manager.phasePolicyHash(1, PHASE);
        facts.saleAdapter = address(offerSale);
        facts.mintManager = address(manager);
        facts.recorder = address(recorder);
        facts.recorderCodeHash = address(recorder).codehash;
        facts.collectionId = 1;
        facts.phaseId = PHASE;
        facts.currentPolicyHash = intent.boundMintPolicyHash;
        facts.boundPolicyHash = intent.boundMintPolicyHash;
        facts.operationRoot = keccak256("actual operation fixture");
        facts.operationId = keccak256("actual token operation fixture");
        facts.tokenId = 1;
        facts.collectionSerial = 1;
        facts.initialRecipient = address(offerSale);
        facts.beneficiary = payer;
        facts.payer = payer;
        facts.tokenDataHash = keccak256("actual offered token bytes");
        facts.mintCommitment = intent.mintCommitment;
        purchase.saleId = intent.saleId;
        purchase.saleNonce = intent.saleNonce;
        purchase.saleConfigHash = keccak256("immutable primary offer config");
        purchase.purchaseId = StreamPreparedNativeOfferHash.purchaseId(
            address(offerSale), intent.saleId, payer, intent.executionNonce
        );
        purchase.buyer = payer;
        purchase.purchaseNonce = intent.executionNonce;
        purchase.offerDigest = keccak256("full original buyer offer digest fixture");
        purchase.authorizationId = StreamMintTicketHash.authorizationId(purchase.offerDigest);
        purchase.authorizer = payer;
        purchase.authorizerKind = 1;
        content.tokenDataHash = facts.tokenDataHash;
    }

    function _selected() private returns (bytes32 key) {
        bytes32 phase = keccak256("selected offer recorder phase");
        bytes32 counter = keccak256("selected offer recorder cap1");
        StreamPreparedNativeContentTypes.Row[] memory rows =
            new StreamPreparedNativeContentTypes.Row[](1);
        rows[0] = StreamPreparedNativeContentTypes.Row(
            bytes32(0), facts.tokenDataHash, "urn:offer:published-work"
        );
        StreamNativePrimaryOfferGate gate = new StreamNativePrimaryOfferGate(
            address(manager), address(offerSale), intent.saleId, 1, phase, counter, rows
        );
        StreamModuleRegistration memory registration = StreamModuleRegistration(
            address(gate),
            keccak256("6529STREAM_MINT_GATE_V1"),
            keccak256("NATIVE_PRIMARY_OFFER_GATE_V1"),
            type(IStreamMintGate).interfaceId,
            800000,
            address(gate).codehash,
            MANIFEST,
            gate.gateConfigHash(),
            "urn:offer:full-manifest"
        );
        (bytes32 scope, bytes32 oldState, bytes32 newState) = _registrationTransition(registration);
        _context(scope, oldState, newState, 1);
        vm.prank(address(revenueAuthority));
        registry.registerModule(registration);
        _clearContext();
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = counter;
        IStreamMintManager.MintCounterConfig[] memory configs =
            new IStreamMintManager.MintCounterConfig[](1);
        configs[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONTEXT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            1,
            1,
            keccak256("selected offer cap1 definition")
        );
        IStreamMintManager.MintGateConfig memory gateConfig;
        gateConfig.gate = address(gate);
        gateConfig.gateConfigHash = gate.gateConfigHash();
        manager.configurePhase(
            1,
            phase,
            IStreamMintManager.MintPhaseConfig(false, 0, 0, 1, MANIFEST, MANIFEST),
            gateConfig,
            ids,
            configs
        );
        manager.setPhaseExecutor(1, phase, address(offerSale), true);
        intent.phaseId = phase;
        intent.boundMintPolicyHash = manager.phasePolicyHash(1, phase);
        facts.phaseId = phase;
        facts.currentPolicyHash = intent.boundMintPolicyHash;
        facts.boundPolicyHash = intent.boundMintPolicyHash;
        content.gate = address(gate);
        content.gateCodeHash = address(gate).codehash;
        content.gateConfigHash = gate.gateConfigHash();
        content.manifestRoot = gate.publication().manifestRoot;
        content.manifestHash = keccak256(gate.manifestBytes());
        content.counterId = counter;
        content.contentLeaf = content.manifestRoot;
        intent.contentSelectionHash = content.contentLeaf;
        _arm();
        bytes32 subject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.CONTEXT,
            1,
            phase,
            counter,
            payer,
            payer,
            address(offerSale),
            purchase.authorizer,
            content.contextHash
        );
        key = manager.previewCounterValueKey(1, phase, counter, subject);
    }

    function _arm() private {
        facts.intentHash =
            StreamPreparedNativeOfferHash.intentHash(address(offerSale), address(recorder), intent);
        content.contextHash = content.gate == address(0)
            ? StreamPreparedNativeSettlementHash.mintContext(
                address(manager), address(offerSale), facts.intentHash
            )
            : StreamPreparedNativeContentHash.context(
                block.chainid, address(offerSale), intent.saleId, content.contentId
            );
        content.operationRoot = 0;
        bytes32 admission = StreamPreparedNativeOfferHash.admissionHash(
            address(offerSale), facts.intentHash, purchase, content
        );
        content.operationRoot = facts.operationRoot;
        offerSale.configure(intent, purchase, facts.intentHash);
        recorderVm.mockCall(
            address(manager),
            abi.encodeCall(IStreamPreparedNativeMint.activePreparedNativeMint, ()),
            abi.encode(facts)
        );
        recorderVm.mockCall(
            address(manager),
            abi.encodeCall(IStreamPreparedNativeOfferMint.activePreparedNativeOfferContent, ()),
            abi.encode(content)
        );
        recorderVm.mockCall(
            address(manager),
            abi.encodeCall(IStreamPreparedNativeOfferMint.preparedNativeOfferAdmission, ()),
            abi.encode(admission)
        );
        recorderVm.mockCall(
            address(core),
            abi.encodeCall(IStreamCoreMint.preparedMint, (uint256(1))),
            abi.encode(StreamPreparedMintRecord(true, facts.operationId, 1))
        );
        recorderVm.mockCall(
            address(core),
            abi.encodeWithSignature("pendingPreparedMintTokenId()"),
            abi.encode(uint256(1))
        );
        recorderVm.mockCall(
            address(core),
            abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (uint256(1))),
            abi.encode(true, uint256(1), uint256(1), false)
        );
        recorderVm.mockCall(
            address(core),
            abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (uint256(1))),
            abi.encode(uint256(1))
        );
        recorderVm.mockCall(
            address(ledger),
            abi.encodeCall(
                IStreamMintLedger.isManagerOperationRootUsed,
                (address(manager), facts.operationRoot)
            ),
            abi.encode(true)
        );
        recorderVm.mockCall(
            address(ledger),
            abi.encodeCall(
                IStreamMintLedger.isManagerAuthorizationUsed,
                (address(manager), purchase.authorizationId)
            ),
            abi.encode(true)
        );
    }
}
