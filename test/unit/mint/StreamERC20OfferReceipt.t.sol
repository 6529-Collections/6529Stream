// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/NativeEnglishAuctionFixture.sol";
import "../../helpers/UniversalSettlementTestMocks.sol";
import {
    StreamERC20OfferReceipt
} from "../../../smart-contracts/domains/mint/StreamERC20OfferReceipt.sol";
import {
    StreamERC20OfferMintTypes
} from "../../../smart-contracts/interfaces/stream/mint/StreamERC20OfferMintTypes.sol";
import {
    StreamUniversalSaleRights
} from "../../../smart-contracts/domains/mint/StreamUniversalSaleRights.sol";
import "../../../smart-contracts/domains/mint/StreamPrivateSaleHash.sol";
import "../../../smart-contracts/domains/mint/StreamMintTicketHash.sol";
import "../../../smart-contracts/domains/mint/StreamPreparedNativeContentHash.sol";
import "../../../smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol";

interface ERC20OfferReceiptVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
}

/// @dev The library runs in a Manager-shaped wrapper with a real, previously admitted recorder.
contract ERC20OfferReceiptHarness {
    address public immutable core;
    address public immutable moduleRegistry;
    address public immutable recorder;
    bytes32 public immutable recorderHash;
    uint64 private immutable _boundAt;
    uint64 private immutable _revision;

    constructor(StreamMintManager manager) {
        core = address(manager.core());
        moduleRegistry = address(manager.moduleRegistry());
        (address selected, bytes32 hash, uint64 boundAt, uint64 revision) =
            manager.preparedNativeRecorder();
        recorder = selected;
        recorderHash = hash;
        _boundAt = boundAt;
        _revision = revision;
    }

    function preparedNativeRecorder() external view returns (address, bytes32, uint64, uint64) {
        return (recorder, recorderHash, _boundAt, _revision);
    }

    function check(
        IStreamMintManager.MintBatch calldata b,
        StreamERC20OfferMintTypes.GateData calldata d,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata c,
        StreamMintTranscriptTypes.OperationTranscript calldata t
    ) external view {
        StreamERC20OfferReceipt.requireReceipt(
            core, moduleRegistry, recorder, recorderHash, b, d, c, t
        );
    }

    /// @dev Same three parameter types/order as the frozen Manager execute selector.
    function candidateSliceHash(
        IStreamMintManager.MintBatch calldata,
        StreamERC20OfferMintTypes.GateData calldata,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata
    ) external pure returns (bytes32) {
        return keccak256(msg.data[68:1156]);
    }

    function checkArguments(
        IStreamMintManager.MintBatch calldata b,
        bytes calldata arguments,
        StreamMintTranscriptTypes.OperationTranscript calldata t
    ) external view {
        StreamERC20OfferReceipt.requireReceiptArguments(
                core, moduleRegistry, recorder, recorderHash, b, arguments, t
            );
    }

    function checkEncoded(
        IStreamMintManager.MintBatch calldata b,
        StreamERC20OfferMintTypes.GateData calldata d,
        bytes calldata encodedCandidate,
        StreamMintTranscriptTypes.OperationTranscript calldata t
    ) external view {
        StreamERC20OfferReceipt.requireReceiptEncoded(
                core, moduleRegistry, recorder, recorderHash, b, d, encodedCandidate, t
            );
    }
}

/// @dev Registered sale identity only. No funding, signature verification or minting is claimed.
contract ERC20OfferReceiptSale is ERC165 {
    address public immutable core;
    address public immutable moduleRegistry;
    address public immutable mintManager;
    address public immutable revenueResolver;
    address public immutable primarySaleSettlement;
    bytes32 public immutable settlementCodeHash;
    StreamPrimarySettlementTypes.SaleLifecycleBinding private _lifecycle;
    uint256 private _saleNonce;
    address private _poster;
    address private _seller;
    bytes32 private _phase;

    function setFacts(uint256 nonce, address poster, address seller, bytes32 phase) external {
        _saleNonce = nonce;
        _poster = poster;
        _seller = seller;
        _phase = phase;
    }

    function primaryOfferSettlementBinding(bytes32)
        external
        view
        returns (uint256, address, bytes32)
    {
        return (_saleNonce, _poster, keccak256("retained sale config"));
    }

    function primaryOfferAuthorizationBinding(bytes32)
        external
        view
        returns (uint256, bytes32, address, uint8, bytes32)
    {
        return (1, _phase, _seller, 1, keccak256("retained sale config"));
    }

    constructor(ERC20OfferReceiptHarness manager, StreamPrimarySaleSettlement recorder) {
        core = manager.core();
        moduleRegistry = manager.moduleRegistry();
        mintManager = address(manager);
        revenueResolver = address(recorder.revenueResolver());
        primarySaleSettlement = address(recorder);
        settlementCodeHash = address(recorder).codehash;
    }

    function open(address payment) external {
        _lifecycle = StreamSettlementAdmission.capture(moduleRegistry, address(this), payment);
    }

    function saleLifecycleBinding(bytes32)
        external
        view
        returns (StreamPrimarySettlementTypes.SaleLifecycleBinding memory)
    {
        return _lifecycle;
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamERC20SaleExecution).interfaceId || super.supportsInterface(id);
    }
}

/// @notice Real Core/registry/recorder/resolver/PROFILE wallet/payment adapter identities. Only the
/// recorder receipt getter is mocked: these tests isolate admission and exact receipt comparisons,
/// and do not establish payment, signature, transcript derivation or end-to-end mint correctness.
contract StreamERC20OfferReceiptTest is NativeEnglishAuctionFixture {
    ERC20OfferReceiptVm private constant receiptVm =
        ERC20OfferReceiptVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    ERC20OfferReceiptHarness private verifier;
    ERC20OfferReceiptSale private offerSale;
    StreamERC20PrimarySettlementAdapter private payment;
    UniversalPermitToken private token;
    IStreamMintManager.MintBatch private batch;
    StreamERC20OfferMintTypes.GateData private data;
    StreamPrimarySettlementTypes.ERC20SettlementCandidate private candidate;
    StreamMintTranscriptTypes.OperationTranscript private transcript;
    StreamPrimarySettlementTypes.PrimarySettlementResult private result;

    // Independently declared carrier tuple: guards the dynamic struct wrapper and field order.
    struct CarrierSelection {
        StreamPreparedNativeContentTypes.Selection content;
        bytes tokenData;
        bytes32 mintCommitment;
        uint256 executionNonce;
    }

    struct CarrierAcceptance {
        StreamPrivateSaleTypes.SaleOffer offer;
        IStreamPrivateSaleAdapter.Signature buyerProof;
        StreamPrivateSaleTypes.SaleAuthorization authorization;
        IStreamPrivateSaleAdapter.Signature sellerProof;
        CarrierSelection selection;
        IStreamNativeRefundDelegatedClaims.DelegationWitness signerDelegation;
        IStreamNativeRefundDelegatedClaims.DelegationWitness executorDelegation;
    }

    function setUp() public override {
        super.setUp();
        verifier = new ERC20OfferReceiptHarness(manager);
        payment = new StreamERC20PrimarySettlementAdapter(recorder, address(0), bytes32(0));
        offerSale = new ERC20OfferReceiptSale(verifier, recorder);
        _register(
            address(payment),
            keccak256("ERC20_PRIMARY_SETTLEMENT_ADAPTER"),
            type(IStreamERC20PrimarySettlementAdapter).interfaceId,
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1")
        );
        _register(
            address(offerSale),
            keccak256("FIXED_PRICE_SALE_ADAPTER"),
            type(IStreamERC20SaleExecution).interfaceId,
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1")
        );
        offerSale.open(address(payment));
        token = new UniversalPermitToken();
        _setAssetPolicy(policy, address(token), 1, keccak256("receipt token"), 0);
        entropy.configure(0, 1, false, false);
        _recipe();
        offerSale.setFacts(
            candidate.sale.saleNonce,
            candidate.sale.poster,
            data.sellerSignature.authorizer,
            batch.phaseId
        );
        _stamp();
    }

    function testExactStoredDirectReceiptPermitsRelayerExecutorWithoutEffects() public {
        _check();
        require(data.executor != payer && candidate.sale.payer == payer, "executor remains relayer");
        require(
            token.balanceOf(wallet) == 0 && recorder.totalOfficialSettled(address(token)) == 0,
            "receipt-only check cannot fund or record"
        );
    }

    function testOfficialEscrowReceiptIsAccepted() public {
        result.escrowed = true;
        _arm();
        _check();
    }

    function testEncodedCanonicalCandidateRunsSameReceiptChecks() public {
        bytes memory encoded = abi.encode(candidate);
        require(encoded.length == 1088, "original 34-word candidate");
        _check();
        vm.prank(address(offerSale));
        verifier.checkEncoded(batch, data, encoded, transcript);
        ++result.amount;
        _arm();
        vm.expectRevert();
        vm.prank(address(offerSale));
        verifier.checkEncoded(batch, data, encoded, transcript);
    }

    function testFrozenThreeArgumentHeadMatchesOriginalCandidateEncoding() public {
        data.selection.proof.push(keccak256("dynamic sibling"));
        data.buyerSignature.signature = new bytes(257);
        batch.tokenData[0] = new bytes(129);
        require(
            verifier.candidateSliceHash(batch, data, candidate) == keccak256(abi.encode(candidate)),
            "dynamic argument tails do not change the static candidate head"
        );
    }

    function testFullThreeArgumentBufferDecodesCandidateAndDynamicTails() public {
        data.selection.proof.push(keccak256("full-buffer sibling"));
        data.buyerSignature.signature = new bytes(193);
        data.sellerSignature.signature = new bytes(97);
        _stamp();
        bytes memory arguments = abi.encode(batch, data, candidate);
        _check();
        vm.prank(address(offerSale));
        verifier.checkArguments(batch, arguments, transcript);
    }

    function testFullArgumentDecodedBatchMustMatchTypedBatch() public {
        bytes memory arguments = abi.encode(batch, data, candidate);
        batch.resolverData = hex"1234";
        _rejectArguments(arguments);
    }

    function testFullArgumentTruncatedHeadAndMalformedDynamicOffsetsReject() public {
        _rejectArguments(new bytes(1151));
        bytes memory arguments = abi.encode(batch, data, candidate);
        assembly ("memory-safe") { mstore(add(arguments, 32), not(0)) }
        _rejectArguments(arguments);
        arguments = abi.encode(batch, data, candidate);
        assembly ("memory-safe") { mstore(add(arguments, 64), mload(arguments)) }
        _rejectArguments(arguments);
    }

    function testFullArgumentNonCanonicalSignatureKindRejects() public {
        bytes memory arguments = abi.encode(batch, data, candidate);
        // GateData is dynamic; the seller Signature offset follows its static authorization.
        assembly ("memory-safe") {
            let start := add(arguments, 32)
            let gate := add(start, mload(add(start, 32)))
            // executor + selection offset + 24-word static SaleAuthorization precede sellerProof.
            let signature := add(gate, mload(add(gate, 832)))
            mstore(add(signature, 32), 256)
        }
        _rejectArguments(arguments);
    }

    function testEncodedShortAndTrailingDataReject() public {
        _rejectEncoded(new bytes(1087));
        _rejectEncoded(bytes.concat(abi.encode(candidate), abi.encode(uint256(0))));
    }

    function testFuzzEncodedNonCanonicalNarrowFieldsReject(uint8 selected) public {
        bytes memory encoded = abi.encode(candidate);
        uint8 field = selected % 3;
        if (field == 0) {
            // candidate.sale.policyMode, uint8, word four.
            assembly ("memory-safe") { mstore(add(encoded, 160), 256) }
        } else if (field == 1) {
            // candidate.lifecycleBinding.saleCreatedAt, uint64, word fourteen.
            assembly ("memory-safe") { mstore(add(encoded, 480), shl(64, 1)) }
        } else {
            // candidate.saleAdapter, address, word zero: preserve low bits and dirty high bits.
            assembly ("memory-safe") {
                mstore(add(encoded, 32), or(mload(add(encoded, 32)), shl(160, 1)))
            }
        }
        _rejectEncoded(encoded);
    }

    function testExplicitUnselectedOfferUsesSellerContextAndOriginalReceipt() public {
        delete data.selection;
        data.offer.contentSelectionHash = 0;
        data.authorization.contentSelectionHash = 0;
        candidate.executionBinding.saleAuthorizationDigest = StreamPrivateSaleHash.digest(
            block.chainid,
            address(offerSale),
            StreamPrivateSaleHash.authorizationBody(data.authorization)
        );
        batch.contextHash = candidate.executionBinding.saleAuthorizationDigest;
        batch.authorizationId = StreamMintTicketHash.authorizationId(
            StreamPrivateSaleHash.digest(
                block.chainid, address(offerSale), StreamPrivateSaleHash.offerBody(data.offer)
            )
        );
        transcript.authorization.authorizationId = batch.authorizationId;
        _stamp();
        _check();
        data.selection.tokenDataHash = keccak256(batch.tokenData[0]);
        _stamp();
        _reject();
    }

    function testCanonicalCarrierAcceptanceRetainsDynamicProofAndSignatures() public {
        data.selection.proof.push(keccak256("manifest sibling"));
        data.buyerSignature.signature = hex"0102030405";
        data.sellerSignature.signature = hex"aabbcc";
        data.buyerDelegation = IStreamNativeRefundDelegatedClaims.DelegationWitness(true, 42);
        data.executorDelegation = IStreamNativeRefundDelegatedClaims.DelegationWitness(true, 43);
        _stamp();
        _check();
        data.sellerSignature.signature = hex"aabbcd";
        _reject();
    }

    function testConsumedFalseCannotBeReplacedByAWellFormedReceipt() public {
        receiptVm.mockCall(
            address(recorder),
            abi.encodeCall(IStreamPrimarySaleSettlement.settlementConsumed, (result.settlementKey)),
            abi.encode(false)
        );
        _reject();
    }

    function testNonCanonicalConsumedWordRejects() public {
        receiptVm.mockCall(
            address(recorder),
            abi.encodeCall(IStreamPrimarySaleSettlement.settlementConsumed, (result.settlementKey)),
            abi.encode(uint256(2))
        );
        _reject();
    }

    function testReceiptShortAndOversizedResponsesReject() public {
        bytes memory selector =
            abi.encodeCall(IStreamPrimarySaleSettlement.settlementResult, (result.settlementKey));
        receiptVm.mockCall(address(recorder), selector, new bytes(352));
        _reject();
        receiptVm.mockCall(
            address(recorder), selector, bytes.concat(abi.encode(result), abi.encode(uint256(0)))
        );
        _reject();
    }

    function testNonCanonicalReceiptBooleanRejects() public {
        bytes memory raw = abi.encode(result);
        assembly ("memory-safe") { mstore(add(raw, 288), 2) }
        receiptVm.mockCall(
            address(recorder),
            abi.encodeCall(IStreamPrimarySaleSettlement.settlementResult, (result.settlementKey)),
            raw
        );
        _reject();
    }

    function testFuzzEveryStoredReceiptBindingIsChecked(uint8 selected) public {
        uint8 field = selected % 11;
        if (field == 0) result.candidateCommitment = bytes32(uint256(123));
        else if (field == 1) result.settlementKey = bytes32(uint256(123));
        else if (field == 2) result.profileId = bytes32(uint256(123));
        else if (field == 3) result.wallet = address(0x123);
        else if (field == 4) result.asset = address(0x123);
        else if (field == 5) ++result.amount;
        else if (field == 6) result.executor = payer;
        else if (field == 7) result.executionId = bytes32(uint256(123));
        else if (field == 8) result.operationIdentityCommitment = bytes32(uint256(123));
        else if (field == 9) result.currentPolicyHash = bytes32(uint256(123));
        else result.boundPolicyHash = bytes32(uint256(123));
        _arm();
        _reject();
    }

    function testFuzzCandidateMintAndEconomicMismatchRejectsEvenWithMatchingReceipt(uint8 selected)
        public
    {
        uint8 field = selected % 13;
        if (field == 0) candidate.operationId = keccak256("other operation");
        else if (field == 1) candidate.operationIdentityCommitment = keccak256("other root");
        else if (field == 2) candidate.currentPolicyHash = keccak256("other current");
        else if (field == 3) candidate.boundPolicyHash = keccak256("other bound");
        else if (field == 4) candidate.sale.beneficiary = address(0x123);
        else if (field == 5) ++candidate.sale.amount;
        else if (field == 6) candidate.sale.tokenId = 1;
        else if (field == 7) candidate.orchestrationOrder = 2;
        else if (field == 8) candidate.executionBinding.authorityMode = 2;
        else if (field == 9) candidate.sale.policyMode = 1;
        else if (field == 10) candidate.asset = address(0);
        else if (field == 11) candidate.sale.saleNonce = 0;
        else candidate.executionBinding.saleAuthorizationDigest = keccak256("other seller");
        _stamp();
        _reject();
    }

    function testDifferentNonzeroSaleNonceRejectsEvenWithMatchingOfficialReceipt() public {
        ++candidate.sale.saleNonce;
        _stamp();
        _reject();
    }

    function testDifferentPosterRejectsEvenWithMatchingOfficialReceipt() public {
        candidate.sale.poster = address(0xF023);
        _stamp();
        _reject();
    }

    function testSettlementAndSignerBindingsMustShareExactHistoricalConfig() public {
        receiptVm.mockCall(
            address(offerSale),
            abi.encodeWithSignature(
                "primaryOfferSettlementBinding(bytes32)", candidate.sale.settlementId
            ),
            abi.encode(
                candidate.sale.saleNonce, candidate.sale.poster, keccak256("different config")
            )
        );
        _reject();
    }

    function testSettlementBindingRequiresExactCanonical96Bytes() public {
        bytes memory callData = abi.encodeWithSignature(
            "primaryOfferSettlementBinding(bytes32)", candidate.sale.settlementId
        );
        receiptVm.mockCall(address(offerSale), callData, new bytes(95));
        _reject();
        receiptVm.mockCall(
            address(offerSale),
            callData,
            abi.encode(
                candidate.sale.saleNonce,
                candidate.sale.poster,
                keccak256("retained sale config"),
                uint256(0)
            )
        );
        _reject();
    }

    function testExactOperationIdIsRequiredAlthoughReceiptHasOnlyRoot() public {
        transcript.operationIds[0] = keccak256("different singleton");
        _reject();
    }

    function testBuyerTicketCannotBeReplacedBySellerDigest() public {
        batch.authorizationId = candidate.executionBinding.saleAuthorizationDigest;
        transcript.authorization.authorizationId = batch.authorizationId;
        _reject();
    }

    function testDirectBuyerRecipientAndFullTokenBytesRemainBound() public {
        batch.initialRecipients[0] = address(offerSale);
        _reject();
        batch.initialRecipients[0] = payer;
        batch.tokenData[0] = hex"ff";
        _reject();
    }

    function testChangedNonceRequiresNewCarrierDataHashAndSettlementReceipt() public {
        ++candidate.executionBinding.executionNonce;
        _reject();
        _stamp();
        _check();
    }

    function testUnwrappedCarrierTupleHashRejects() public {
        CarrierAcceptance memory a = _acceptance();
        candidate.saleExecutionHash = keccak256(
            abi.encode(
                a.offer,
                a.buyerProof,
                a.authorization,
                a.sellerProof,
                a.selection,
                a.signerDelegation,
                a.executorDelegation
            )
        );
        _receipt();
        _reject();
    }

    function testCurrentPositiveNativeFeeRejectsBeforeMint() public {
        entropy.configure(1, 0, false, false);
        _reject();
    }

    function testUndeclaredPolicyCannotMasqueradeAsZeroFee() public {
        receiptVm.mockCall(
            address(entropy),
            abi.encodeCall(IStreamRevealFeeEscrow.collectionRevealPolicy, (uint256(1))),
            abi.encode(IStreamRevealFeeEscrow.CollectionRevealPolicy(false, 1, bytes32(0), 0, 0))
        );
        _reject();
    }

    function testMalformedRevealPolicyRejects() public {
        receiptVm.mockCall(
            address(entropy),
            abi.encodeCall(IStreamRevealFeeEscrow.collectionRevealPolicy, (uint256(1))),
            new bytes(128)
        );
        _reject();
    }

    function testRevokedRecorderRejects() public {
        _status(address(recorder), ModuleRegistryStatus.INCIDENT_REVOKED);
        _reject();
    }

    function testRevokedPaymentRejects() public {
        _status(address(payment), ModuleRegistryStatus.INCIDENT_REVOKED);
        _reject();
    }

    function testRevokedSaleRejects() public {
        _status(address(offerSale), ModuleRegistryStatus.INCIDENT_REVOKED);
        _reject();
    }

    function testPreviouslyBoundDeprecatedRecorderRemainsAdmitted() public {
        vm.warp(block.timestamp + 1);
        _status(address(recorder), ModuleRegistryStatus.DEPRECATED);
        _check();
    }

    function testWrongSelectedRecorderHashRejects() public {
        receiptVm.mockCall(
            address(verifier),
            abi.encodeCall(IStreamPreparedNativeMint.preparedNativeRecorder, ()),
            abi.encode(address(recorder), keccak256("wrong runtime"), uint64(1000), uint64(1))
        );
        _reject();
    }

    function testAssetMustRemainActive() public {
        _check();
        uint8 inactive = policy.ASSET_STATUS_INACTIVE();
        _setAssetPolicy(policy, address(token), inactive, keccak256("inactive token"), 0);
        _rejectAssetReceipt(inactive);

        uint8 active = policy.ASSET_STATUS_ACTIVE();
        _setAssetPolicy(policy, address(token), active, keccak256("active token"), 0);
        _check();

        uint8 deprecated = policy.ASSET_STATUS_DEPRECATED();
        uint64 grace = uint64(block.timestamp + 180 days);
        _setAssetPolicy(policy, address(token), deprecated, keccak256("deprecated token"), grace);
        require(policy.assetReleaseGraceUntil(address(token)) == grace, "retained release grace");
        _rejectAssetReceipt(deprecated);

        uint8 unsupported = policy.ASSET_STATUS_UNSUPPORTED();
        _setAssetPolicy(policy, address(token), unsupported, keccak256("unsupported token"), grace);
        _rejectAssetReceipt(unsupported);

        // Restoring acceptance keeps the exit grace; the original receipt remains otherwise valid.
        _setAssetPolicy(policy, address(token), active, keccak256("reactivated token"), grace);
        _check();
    }

    function _rejectAssetReceipt(uint8 expectedStatus) private {
        require(policy.assetStatus(address(token)) == expectedStatus, "policy transition applied");
        vm.expectRevert(
            abi.encodeWithSelector(StreamERC20OfferReceipt.InvalidERC20OfferReceipt.selector)
        );
        vm.prank(address(offerSale));
        verifier.check(batch, data, candidate, transcript);
    }

    function testAlteredCreationLifecycleRejectsEvenWithMatchingReceipt() public {
        ++candidate.lifecycleBinding.saleCreatedAt;
        _stamp();
        _reject();
    }

    function testTemplateCannotEnterFrozenProfilePath() public {
        candidate.rights.templateId = keccak256("template");
        _stamp();
        _reject();
    }

    function testCurrentConcreteEntriesMustMatchPaidCandidate() public {
        candidate.rights.entriesHash = keccak256("different recipients");
        _stamp();
        _reject();
    }

    function testOtherCallerCannotUsePaidSaleReceipt() public {
        vm.prank(payer);
        vm.expectRevert();
        verifier.check(batch, data, candidate, transcript);
    }

    function _check() private {
        vm.prank(address(offerSale));
        verifier.check(batch, data, candidate, transcript);
    }

    function _rejectEncoded(bytes memory encoded) private {
        vm.expectRevert();
        vm.prank(address(offerSale));
        verifier.checkEncoded(batch, data, encoded, transcript);
    }

    function _rejectArguments(bytes memory arguments) private {
        vm.expectRevert();
        vm.prank(address(offerSale));
        verifier.checkArguments(batch, arguments, transcript);
    }

    function _reject() private {
        vm.expectRevert();
        vm.prank(address(offerSale));
        verifier.check(batch, data, candidate, transcript);
    }

    function _acceptance() private view returns (CarrierAcceptance memory) {
        return CarrierAcceptance(
            data.offer,
            data.buyerSignature,
            data.authorization,
            data.sellerSignature,
            CarrierSelection(
                data.selection,
                batch.tokenData[0],
                batch.mintCommitments[0],
                candidate.executionBinding.executionNonce
            ),
            data.buyerDelegation,
            data.executorDelegation
        );
    }

    function _stamp() private {
        candidate.executionBinding.executionId = StreamPrimarySettlementHash.executionId(candidate);
        candidate.saleExecutionHash = keccak256(abi.encode(_acceptance()));
        _receipt();
    }

    function _receipt() private {
        result = StreamPrimarySettlementTypes.PrimarySettlementResult(
            StreamPrimarySettlementHash.candidateCommitment(
                address(payment), address(recorder), candidate
            ),
            StreamPrimarySettlementHash.settlementKey(
                address(recorder), address(offerSale), candidate.executionBinding.executionId
            ),
            candidate.rights.profileId,
            candidate.rights.wallet,
            candidate.asset,
            candidate.sale.amount,
            candidate.executor,
            candidate.executionBinding.executionId,
            false,
            candidate.operationIdentityCommitment,
            candidate.currentPolicyHash,
            candidate.boundPolicyHash
        );
        _arm();
    }

    function _arm() private {
        bytes32 key = StreamPrimarySettlementHash.settlementKey(
            address(recorder), address(offerSale), candidate.executionBinding.executionId
        );
        receiptVm.mockCall(
            address(recorder),
            abi.encodeCall(IStreamPrimarySaleSettlement.settlementConsumed, (key)),
            abi.encode(true)
        );
        receiptVm.mockCall(
            address(recorder),
            abi.encodeCall(IStreamPrimarySaleSettlement.settlementResult, (key)),
            abi.encode(result)
        );
    }

    function _recipe() private {
        batch.collectionId = 1;
        batch.phaseId = PHASE;
        batch.payer = payer;
        batch.authorizer = payer;
        batch.expectedPolicyHash = keccak256("bound policy");
        batch.initialRecipients.push(payer);
        batch.beneficiaries.push(payer);
        batch.tokenData.push(hex"010203");
        batch.mintCommitments.push(keccak256("commitment"));
        data.executor = address(0xE123);
        data.selection.contentId = keccak256("content");
        data.selection.tokenDataHash = keccak256(batch.tokenData[0]);
        data.buyerSignature = IStreamPrivateSaleAdapter.Signature(payer, 1, hex"01");
        data.sellerSignature = IStreamPrivateSaleAdapter.Signature(vm.addr(SIGNER_KEY), 1, hex"02");
        bytes32 id = keccak256("receipt offer");
        batch.contextHash = StreamPreparedNativeContentHash.context(
            block.chainid, address(offerSale), id, data.selection.contentId
        );
        bytes32 leaf = StreamPreparedNativeContentHash.leaf(
            block.chainid,
            address(offerSale),
            id,
            data.selection.contentId,
            data.selection.tokenDataHash
        );
        data.offer = StreamPrivateSaleTypes.SaleOffer(
            block.chainid,
            address(offerSale),
            address(core),
            1,
            0,
            leaf,
            payer,
            address(token),
            1000,
            keccak256("buyer nonce"),
            uint64(block.timestamp + 100),
            0
        );
        StreamSaleTemplate.Selection memory rights =
            StreamUniversalSaleRights.rights(resolver, factory, 1);
        bytes32 primary = StreamSaleTemplate.policyHash(resolver, 1, rights);
        StreamPrivateSaleTypes.SaleAuthorization storage a = data.authorization;
        a.chainId = block.chainid;
        a.saleAdapter = address(offerSale);
        a.mintManager = address(verifier);
        a.collectionId = 1;
        a.phaseId = PHASE;
        a.saleId = id;
        a.saleKind = 6;
        a.revenueClass = CLASS;
        a.expectedPrimaryPolicyHash = primary;
        a.initialRecipientsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), batch.initialRecipients)
        );
        a.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), batch.beneficiaries)
        );
        a.tokenDataArrayHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), batch.tokenData)
        );
        a.mintCommitmentsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), batch.mintCommitments)
        );
        a.payer = payer;
        a.executor = data.executor;
        a.asset = address(token);
        a.unitPrice = 1000;
        a.quantity = 1;
        a.contentSelectionHash = leaf;
        a.policyHash = batch.expectedPolicyHash;
        a.nonce = keccak256("seller nonce");
        a.deadline = uint64(block.timestamp + 100);
        batch.authorizationId = StreamMintTicketHash.authorizationId(
            StreamPrivateSaleHash.digest(
                block.chainid, address(offerSale), StreamPrivateSaleHash.offerBody(data.offer)
            )
        );
        transcript.quantity = 1;
        transcript.firstOperationNonce = 1;
        transcript.currentPolicyHash = keccak256("current policy");
        transcript.boundPolicyHash = batch.expectedPolicyHash;
        transcript.operationRoot = keccak256("operation root");
        transcript.operationIds.push(keccak256("operation id"));
        transcript.authorization.authorizationId = batch.authorizationId;
        transcript.authorization.authorizer = payer;
        transcript.authorization.authorizerKind = IStreamMintManager.AuthorizerKind.EOA_712;
        transcript.authorization.maxQuantity = 1;
        candidate.saleAdapter = address(offerSale);
        candidate.executor = data.executor;
        candidate.sale = StreamPrimarySettlementTypes.PrimarySale(
            id, CLASS, 0, 1, 0, 1, payer, address(0), payer, 1000, primary
        );
        candidate.lifecycleBinding = offerSale.saleLifecycleBinding(id);
        candidate.executionBinding.executionNonce = 1;
        candidate.executionBinding.authorityMode = 1;
        candidate.executionBinding.saleAuthorizationDigest = StreamPrivateSaleHash.digest(
            block.chainid,
            address(offerSale),
            StreamPrivateSaleHash.authorizationBody(data.authorization)
        );
        candidate.asset = address(token);
        candidate.orchestrationOrder = 1;
        candidate.mintManager = address(verifier);
        candidate.operationIdentityCommitment = transcript.operationRoot;
        candidate.operationId = transcript.operationIds[0];
        candidate.currentPolicyHash = transcript.currentPolicyHash;
        candidate.boundPolicyHash = transcript.boundPolicyHash;
        candidate.rights = StreamPrimarySettlementTypes.PrimaryRights(
            rights.profileId,
            rights.wallet,
            rights.templateId,
            rights.assignmentHash,
            rights.entriesHash
        );
    }
}
