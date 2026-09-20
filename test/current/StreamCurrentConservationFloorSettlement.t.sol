// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/NativeCustodyAuctionFixture.sol";
import "../helpers/UniversalSettlementTestMocks.sol";
import "../../smart-contracts/domains/metadata/StreamConservationFloor.sol";
import "../../smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol";
import "../../smart-contracts/domains/mint/StreamUniversalFixedPriceSaleAdapter.sol";
import "../../smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol";
import "../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";

/// @dev Selected Metadata writer boundary only. Actual facade class-7/8/Safe tests are separate.
contract CurrentFloorTierWriter {
    address public immutable core;

    constructor(address c) {
        core = c;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamCollectionMetadataV1).interfaceId;
    }

    function declareWaived() external {
        IStreamCoreConservationTier(core)
            .recordConservationTier(1, keccak256("CONSERVATION_WAIVED"));
    }
}

/// @notice Actual Core/Manager/Ledger/Registry/recorder/asset-payment/auction/floor composition.
/// @dev Original fixture governance, Artist and entropy boundaries remain explicit. WAIVED is
/// declared before mint through the selected writer; this never fabricates native artist proof.
contract StreamCurrentConservationFloorSettlementTest is NativeCustodyAuctionFixture {
    StreamConservationFloor private floor;
    StreamNativeFixedPriceSaleAdapter private nativeSale;
    StreamUniversalFixedPriceSaleAdapter private erc20Sale;
    StreamERC20PrimarySettlementAdapter private payment;
    UniversalPermitToken private token;
    bytes32 private nativeSaleId;
    bytes32 private erc20SaleId;

    function _installFloor(bool waive) private {
        CurrentFloorTierWriter metadata = new CurrentFloorTierWriter(address(core));
        _register(
            address(metadata),
            keccak256("COLLECTION_METADATA"),
            type(IStreamCollectionMetadataV1).interfaceId,
            MANIFEST
        );
        _pointer(keccak256("COLLECTION_METADATA"), address(metadata));
        if (waive) metadata.declareWaived();
        floor = new StreamConservationFloor(
            address(core),
            address(revenueAuthority),
            IStreamGasParameterHost.GasParameterConfig(
                "CONSERVATION_FLOOR_READ_GAS", 300000, 300000, 2
            ),
            IStreamGasParameterHost.GasParameterConfig(
                "CONSERVATION_FLOOR_PRODUCER_GAS", 1000000, 1000000, 2
            ),
            IStreamGasParameterHost.GasParameterConfig(
                // Fresh WAIVED-fixture tuple; not a reduction of an existing governed cap.
                "CONSERVATION_FLOOR_CALL_GAS",
                2000000,
                2000000,
                2
            )
        );
        (uint256 callGas, uint256 callFloor, uint8 failureClass,) =
            floor.gasParameterInfo(floor.CALL_GAS());
        uint256 callbackGas = manager.gasParameter(manager.GGP_PREPARED_NATIVE_CALLBACK_GAS_LIMIT());
        require(
            callGas == 2000000 && callFloor == 2000000 && failureClass == 2
                && callbackGas == 4000000 && callGas + callGas / 63 + 100000 + 3300 < callbackGas,
            "fresh WAIVED floor reservation fits the unchanged callback configuration"
        );
        (bytes32 s, bytes32 o, bytes32 n) = core.conservationFloorTransition(address(floor));
        _context(s, o, n, 1);
        vm.prank(address(revenueAuthority));
        core.bindConservationFloor(address(floor));
        _clearContext();
        require(address(floor).code.length <= 24576, "actual ledger EIP170");
    }

    function _nativeProduct() private {
        nativeSale = new StreamNativeFixedPriceSaleAdapter(
            manager,
            recorder,
            vm.addr(AUCTION_PLATFORM_KEY),
            artists,
            IStreamGasParameterHost.GasParameterConfig(
                "REVEAL_ATTEMPT_GAS_LIMIT", 2000000, 50000, 2
            ),
            IStreamNativeRefundDelegatedClaims.DelegationDeployment(
                    address(0),
                    0,
                    bytes32(0),
                    IStreamGasParameterHost.GasParameterConfig("", 0, 0, 0)
                )
        );
        _register(
            address(nativeSale),
            keccak256("NATIVE_PRIMARY_SALE_ADAPTER"),
            type(IStreamNativeSaleBinding).interfaceId,
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1")
        );
        manager.setPhaseExecutor(1, PHASE, address(nativeSale), true);
        nativeSaleId = nativeSale.registerSale(
            IStreamNativeFixedPriceSaleAdapter.SaleConfig(
                1,
                PHASE,
                1000,
                0,
                10000,
                manager.phasePolicyHash(1, PHASE),
                resolver.resolvePrimaryAssignment(1, 0, CLASS).assignmentHash
            )
        );
    }

    function _nativeData()
        private
        returns (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        )
    {
        e.tokenData = bytes("actual conservation native work");
        e.authorization = IStreamNativeFixedPriceSaleAdapter.SaleAuthorization(
            nativeSaleId,
            nativeSale.saleRecord(nativeSaleId).configHash,
            payer,
            payer,
            payer,
            vm.addr(SIGNER_KEY),
            keccak256(e.tokenData),
            keccak256("native conservation mint"),
            1,
            bytes32(uint256(1)),
            9000,
            StreamNativeEnglishAuctionSupport.profilePolicy(resolver, 1)
        );
        bytes32 digest = nativeSale.authorizationDigest(e.authorization);
        e.platformSignature = _proof(AUCTION_PLATFORM_KEY, digest);
        e.artistSignature = _proof(SIGNER_KEY, digest);
        c = nativeSale.previewExecution(e);
    }

    function testActualNativeRecorderStoresOriginalProjectionAndRollsBackLateMintFailure() public {
        _installFloor(true);
        _nativeProduct();
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        ) = _nativeData();
        bytes32 key = recorder.settlementKey(address(nativeSale), c.executionBinding.executionId);
        uint256 preparationProbe = vm.snapshotState();
        bytes32 expectedPreparation = _prepareProjection(
            StreamNativeSettlementHash.accountingContext(c),
            StreamNativeSettlementHash.candidateCommitment(address(recorder), c)
        );
        require(
            vm.revertToState(preparationProbe) && !floor.primarySalePrepared(expectedPreparation),
            "no preparation before purchase"
        );
        uint256 payerBefore = payer.balance;
        entropy.configure(100, 1, true, false);
        vm.prank(payer);
        (bool ok,) =
            address(nativeSale).call{ value: 1100 }(abi.encodeCall(nativeSale.purchase, (e)));
        require(
            !ok && floor.firstSale(1).receiptHash == 0 && !recorder.settlementConsumed(key)
                && !floor.primarySalePrepared(expectedPreparation) && wallet.balance == 0
                && payer.balance == payerBefore && core.collectionMintedEver(1) == 0,
            "actual late mint reverts floor, payment, replay and mint count"
        );
        entropy.configure(100, 1, false, false);
        vm.prank(payer);
        (StreamPrimarySettlementTypes.PrimarySettlementResult memory r, uint256 id) =
            nativeSale.purchase{ value: 1100 }(e);
        require(
            id == 1 && core.ownerOf(1) == payer && r.settlementKey == key,
            "same signed native retry"
        );
        StreamConservationFloorTypes.SettlementReceipt memory receipt = _receipt(r);
        require(
            floor.primarySalePrepared(expectedPreparation) && receipt.tokenId == 0
                && receipt.candidatePayloadHash
                    == keccak256(abi.encode(StreamNativeSettlementHash.accountingContext(c)))
                && receipt.candidateCommitment
                    == StreamNativeSettlementHash.candidateCommitment(address(recorder), c),
            "projection and native commitment are distinct exact identities"
        );
    }

    function testActualNativeInlineAndOptionalPreparationProduceIdenticalReceipts() public {
        _installFloor(true);
        _nativeProduct();
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        ) = _nativeData();
        uint256 snapshot = vm.snapshotState();
        vm.prank(payer);
        (StreamPrimarySettlementTypes.PrimarySettlementResult memory inlineResult,) =
            nativeSale.purchase{ value: 1100 }(e);
        StreamConservationFloorTypes.SettlementReceipt memory inlineReceipt = _receipt(inlineResult);
        require(vm.revertToState(snapshot), "same original sale state");
        _prepareProjection(
            StreamNativeSettlementHash.accountingContext(c),
            StreamNativeSettlementHash.candidateCommitment(address(recorder), c)
        );
        vm.prank(payer);
        (StreamPrimarySettlementTypes.PrimarySettlementResult memory preparedResult,) =
            nativeSale.purchase{ value: 1100 }(e);
        require(
            keccak256(abi.encode(inlineResult)) == keccak256(abi.encode(preparedResult))
                && keccak256(abi.encode(inlineReceipt))
                    == keccak256(abi.encode(_receipt(preparedResult))),
            "original result, full permanent receipt and payment are preparation independent"
        );
    }

    function testActualNativeMissingProspectiveFloorRollsBackPaidSale() public {
        _installFloor(false);
        _nativeProduct();
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        ) = _nativeData();
        uint256 payerBefore = payer.balance;
        vm.prank(payer);
        (bool ok,) =
            address(nativeSale).call{ value: 1100 }(abi.encodeCall(nativeSale.purchase, (e)));
        require(
            !ok && payer.balance == payerBefore && wallet.balance == 0
                && recorder.totalOfficialSettled(address(0)) == 0
                && !recorder.settlementConsumed(
                    recorder.settlementKey(address(nativeSale), c.executionBinding.executionId)
                ) && core.lastAllocatedTokenId() == 0 && floor.firstSale(1).receiptHash == 0,
            "no silent undeclared waiver"
        );
    }

    function _erc20Product() private {
        // Keep this existing receipt/floor oracle on an explicit zero-fee OWNER_WINDOW policy.
        entropy.configure(0, 1, false, false);
        token = new UniversalPermitToken();
        _setAssetPolicy(policy, address(token), 1, keccak256("conservation exact ERC20"), 0);
        payment = new StreamERC20PrimarySettlementAdapter(recorder, address(0), bytes32(0));
        erc20Sale = new StreamUniversalFixedPriceSaleAdapter(
            manager, recorder, vm.addr(AUCTION_PLATFORM_KEY), artists,
            IStreamGasParameterHost.GasParameterConfig("REVEAL_ATTEMPT_GAS_LIMIT", 1_000_000, 100_000, 2)
        );
        _register(
            address(payment),
            keccak256("ERC20_PRIMARY_SETTLEMENT_ADAPTER"),
            type(IStreamERC20PrimarySettlementAdapter).interfaceId,
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1")
        );
        _register(
            address(erc20Sale),
            keccak256("FIXED_PRICE_SALE_ADAPTER"),
            type(IStreamERC20SaleExecution).interfaceId,
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1")
        );
        manager.setPhaseExecutor(1, PHASE, address(erc20Sale), true);
        erc20SaleId = erc20Sale.registerSale(
            IStreamUniversalFixedPriceSaleAdapter.SaleConfig(
                address(payment),
                1,
                PHASE,
                address(token),
                1000,
                0,
                10000,
                manager.phasePolicyHash(1, PHASE),
                StreamNativeEnglishAuctionSupport.profilePolicy(resolver, 1)
            )
        );
        token.mint(payer, 10000);
        vm.prank(payer);
        token.approve(address(payment), 10000);
    }

    function testActualERC20RecorderStoresFullOriginalProjection() public {
        _installFloor(true);
        _erc20Product();
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e;
        e.tokenData = bytes("actual conservation ERC20 work");
        e.authorization = IStreamUniversalFixedPriceSaleAdapter.SaleAuthorization(
            erc20SaleId,
            erc20Sale.saleRecord(erc20SaleId).configHash,
            payer,
            payer,
            payer,
            vm.addr(SIGNER_KEY),
            keccak256(e.tokenData),
            keccak256("ERC20 conservation mint"),
            1,
            bytes32(uint256(1)),
            9000
        );
        bytes32 digest = erc20Sale.authorizationDigest(e.authorization);
        e.platformSignature = _proof(AUCTION_PLATFORM_KEY, digest);
        e.artistSignature = _proof(SIGNER_KEY, digest);
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c =
            erc20Sale.previewExecution(e);
        vm.prank(payer);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory r =
            payment.settleERC20PrimarySaleByPayer(c, abi.encode(e));
        StreamConservationFloorTypes.SettlementReceipt memory receipt = _receipt(r);
        require(
            core.ownerOf(1) == payer && token.balanceOf(wallet) == 1000
                && token.balanceOf(payer) == 9000 && r.asset == address(token)
                && receipt.candidatePayloadHash == keccak256(abi.encode(c)),
            "actual ERC20 sale joined"
        );
    }

    function testActualPreparedAuctionWritesFloorWhileTokenAllocated() public {
        _installFloor(true);
        IStreamNativeEnglishAuction.Configuration memory c;
        c.collectionId = 1;
        c.phaseId = PHASE;
        c.mintAtSettlement = true;
        c.artworkCommitment = keccak256("conservation prepared work");
        c.mintCommitment = keccak256("conservation prepared mint");
        c.poster = address(this);
        c.reservePrice = 1000;
        c.minIncrementBps = 500;
        c.clock =
            StreamEnglishAuctionClock.Configuration(1000, 4600, 0, 600, 600, 3600, false, false);
        c.expectedPrimaryPolicyHash = StreamNativeEnglishAuctionSupport.profilePolicy(resolver, 1);
        c.primaryPolicyMode = 1;
        c.settlementWindow = 86400;
        c.mintPolicyHash = manager.phasePolicyHash(1, PHASE);
        IStreamNativeEnglishAuction.CreationAuthorization memory a =
            IStreamNativeEnglishAuction.CreationAuthorization(
                house.auctionConfigurationHash(c), vm.addr(SIGNER_KEY), bytes32(uint256(1)), 2000
            );
        bytes32 digest = house.creationAuthorizationDigest(a);
        bytes32 id = house.registerAuction(
            c,
            bytes("conservation prepared work"),
            a,
            _proof(AUCTION_PLATFORM_KEY, digest),
            _proof(SIGNER_KEY, digest)
        );
        vm.prank(payer);
        house.bid{ value: 1100 }(id, address(0));
        _custodyEnd(id);
        (uint256 tokenId, bytes32 key) = house.settle(id);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory result =
            recorder.settlementResult(key);
        StreamConservationFloorTypes.SettlementReceipt memory receipt = _receipt(result);
        require(
            tokenId == 1 && receipt.tokenId == tokenId && result.operationIdentityCommitment != 0
                && core.ownerOf(tokenId) == payer && recorder.preparedNativeFactsHash(key) != 0
                && core.collectionMintedEver(1) == 1,
            "actual prepared mint floor precedes completion"
        );
    }

    function testActualCustodyPaidTransferWritesFloorWithoutSecondMint() public {
        _installFloor(true);
        _bindCustody();
        Plan memory p = _custodyPlan(false, address(this), address(this));
        bytes32 id = _openCustody(p);
        require(
            floor.firstSale(1).receiptHash == 0 && core.collectionMintedEver(1) == 1,
            "unpaid custody creates no floor sale"
        );
        _custodyBid(id, payer, 1000);
        _custodyEnd(id);
        (uint256 tokenId, bytes32 key) = house.settle(id);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory result =
            recorder.settlementResult(key);
        StreamConservationFloorTypes.SettlementReceipt memory receipt = _receipt(result);
        require(
            receipt.tokenId == tokenId && tokenId == 1 && result.operationIdentityCommitment == 0
                && result.currentPolicyHash == 0 && result.boundPolicyHash == 0
                && recorder.nativeCustodyFactsHash(key) != 0 && core.ownerOf(tokenId) == payer
                && manager.nextOperationNonce() == 1 && core.collectionMintedEver(1) == 1,
            "actual paid transfer, original mint only"
        );
    }

    function _prepareProjection(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        bytes32 commitment
    ) private returns (bytes32 preparation) {
        StreamPrimarySettlementTypes.PrimarySettlementResult memory expected =
            StreamPrimarySettlementTypes.PrimarySettlementResult(
                commitment,
                StreamPrimarySettlementHash.settlementKey(
                    address(recorder), c.saleAdapter, c.executionBinding.executionId
                ),
                c.rights.profileId,
                c.rights.wallet,
                c.asset,
                c.sale.amount,
                c.executor,
                c.executionBinding.executionId,
                false,
                c.operationIdentityCommitment,
                c.currentPolicyHash,
                c.boundPolicyHash
            );
        preparation = floor.preparePrimarySale(address(recorder), c, expected);
        require(
            !recorder.settlementConsumed(expected.settlementKey)
                && floor.settlementReceipt(expected.settlementKey).receiptHash == 0,
            "preparation does not pay"
        );
    }

    function _receipt(StreamPrimarySettlementTypes.PrimarySettlementResult memory r)
        private
        view
        returns (StreamConservationFloorTypes.SettlementReceipt memory receipt)
    {
        receipt = floor.settlementReceipt(r.settlementKey);
        require(
            recorder.settlementConsumed(r.settlementKey) && receipt.receiptHash != 0
                && receipt.recorder == address(recorder)
                && receipt.recorderCodeHash == address(recorder).codehash
                && receipt.collectionId == 1 && receipt.candidateCommitment == r.candidateCommitment
                && receipt.resultHash == keccak256(abi.encode(r))
                && receipt.effectiveTier == keccak256("CONSERVATION_WAIVED")
                && receipt.firstSaleReceiptHash == floor.firstSale(1).receiptHash,
            "exact actual recorder floor receipt"
        );
    }

    function _proof(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }
}
