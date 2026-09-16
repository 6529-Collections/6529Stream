// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamNativePrimaryOfferGate
} from "../../../smart-contracts/domains/mint/StreamNativePrimaryOfferGate.sol";
import {
    StreamPreparedNativeOfferHash as Hash
} from "../../../smart-contracts/domains/mint/StreamPreparedNativeOfferHash.sol";
import {
    StreamPreparedNativeOfferReads as Reads
} from "../../../smart-contracts/domains/mint/StreamPreparedNativeOfferReads.sol";
import {
    StreamNativePrimaryOfferSignatures as Signatures
} from "../../../smart-contracts/domains/mint/StreamNativePrimaryOfferSignatures.sol";
import {
    StreamPreparedNativeContentHash as ContentHash
} from "../../../smart-contracts/domains/mint/StreamPreparedNativeContentHash.sol";
import {
    StreamPreparedNativeSettlementHash as PreparedHash
} from "../../../smart-contracts/domains/revenue/StreamPreparedNativeSettlementHash.sol";
import {
    StreamPrivateSaleHash
} from "../../../smart-contracts/domains/mint/StreamPrivateSaleHash.sol";
import {
    StreamMintTicketHash
} from "../../../smart-contracts/domains/mint/StreamMintTicketHash.sol";
import {
    StreamPreparedNativeOfferTypes as Offer
} from "../../../smart-contracts/interfaces/stream/mint/StreamPreparedNativeOfferTypes.sol";
import {
    StreamPreparedNativeContentTypes as Content
} from "../../../smart-contracts/interfaces/stream/mint/StreamPreparedNativeContentTypes.sol";
import {
    StreamPreparedNativeSettlementTypes as Prepared
} from "../../../smart-contracts/interfaces/stream/revenue/StreamPreparedNativeSettlementTypes.sol";
import {
    StreamPrivateSaleTypes as Sales
} from "../../../smart-contracts/interfaces/stream/mint/StreamPrivateSaleTypes.sol";
import {
    IStreamMintManager
} from "../../../smart-contracts/interfaces/stream/mint/IStreamMintManager.sol";
import {
    IStreamMintLedger
} from "../../../smart-contracts/interfaces/stream/mint/IStreamMintLedger.sol";
import {
    IStreamMintGate
} from "../../../smart-contracts/interfaces/stream/mint/IStreamMintGate.sol";
import {
    IStreamPreparedNativeOfferGate
} from "../../../smart-contracts/interfaces/stream/mint/IStreamPreparedNativeOfferGate.sol";
import {
    IStreamPreparedNativeContentPurchaseGate
} from "../../../smart-contracts/interfaces/stream/mint/IStreamPreparedNativeContentPurchaseGate.sol";
import {
    IStreamPrivateSaleAdapter
} from "../../../smart-contracts/interfaces/stream/mint/IStreamPrivateSaleAdapter.sol";
import {
    IStreamNativeRefundDelegatedClaims as Refund
} from "../../../smart-contracts/interfaces/stream/mint/IStreamNativeRefundDelegatedClaims.sol";
import {
    IStreamModuleRegistry,
    StreamModuleRecord,
    ModuleRegistryStatus
} from "../../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";
import { IERC165 } from "../../../smart-contracts/vendor/openzeppelin/IERC165.sol";
import {
    DelegationManagementContract
} from "../../../smart-contracts/integrations/delegation/NFTdelegation.sol";
import { CuratedGateVm, CuratedGateSignatureWallet } from "./StreamNativeCuratedContentGate.t.sol";

/// @dev Typed Manager and ledger reads isolate offer admission. No mint or settlement is simulated.
contract OfferAdmissionManagerBoundary {
    address public core;
    address public moduleRegistry;
    address public mintLedger;
    bytes32 public preparedNativeOfferAdmission;
    Content.Facts private _content;
    IStreamMintManager.MintGateConfig private _gate;
    IStreamMintManager.MintCounterConfig private _counter;
    bool public authorizationUsed;
    uint256 public count = 1;
    bytes32 private _counterId;

    constructor(address registry) {
        core = address(0xC0DE);
        moduleRegistry = registry;
        mintLedger = address(this);
    }

    function setGate(IStreamMintManager.MintGateConfig memory value, bytes32 counterId) external {
        _gate = value;
        _counterId = counterId;
        _counter.enabled = true;
        _counter.keyMode = IStreamMintManager.CounterKeyMode.CONTEXT;
        _counter.capMode = IStreamMintLedger.CounterCapMode.STATIC;
        _counter.deltaMode = IStreamMintLedger.CounterDeltaMode.STATIC;
        _counter.staticCap = 1;
        _counter.staticIncrement = 1;
        _counter.counterConfigHash = keccak256("actual cap one");
    }

    function setCounterCap(uint256 value) external {
        _counter.staticCap = uint64(value);
    }

    function setCount(uint256 value) external {
        count = value;
    }

    function setAuthorizationUsed(bool value) external {
        authorizationUsed = value;
    }

    function setAdmission(bytes32 value, Content.Facts memory content) external {
        preparedNativeOfferAdmission = value;
        _content = content;
    }

    function phaseGate(uint256, bytes32)
        external
        view
        returns (IStreamMintManager.MintGateConfig memory)
    {
        return _gate;
    }

    function phase(uint256, bytes32)
        external
        pure
        returns (bool, IStreamMintManager.MintPhaseConfig memory p)
    {
        p.maxBatchQuantity = 1;
        return (true, p);
    }

    function phaseExecutor(uint256, bytes32, address) external pure returns (bool) {
        return true;
    }

    function counterConfig(uint256, bytes32, bytes32)
        external
        view
        returns (IStreamMintManager.MintCounterConfig memory)
    {
        return _counter;
    }

    function phaseCounterIds(uint256, bytes32) external view returns (bytes32[] memory ids) {
        ids = new bytes32[](1);
        ids[0] = _counterId;
    }

    function isManagerAuthorizationUsed(address, bytes32) external view returns (bool) {
        return authorizationUsed;
    }

    function counterValue(bytes32) external view returns (uint256) {
        return count;
    }

    function previewSubjectKey(
        IStreamMintManager.CounterKeyMode,
        uint256,
        bytes32,
        bytes32,
        address,
        address,
        address,
        address,
        bytes32 context
    ) external pure returns (bytes32) {
        return context;
    }

    function previewCounterValueKey(uint256, bytes32, bytes32, bytes32 subject)
        external
        pure
        returns (bytes32)
    {
        return subject;
    }

    function activePreparedNativeOfferContent() external view returns (Content.Facts memory) {
        return _content;
    }

    function readBatch(
        IStreamMintManager.MintBatch calldata b,
        bytes calldata d,
        bytes32 h,
        Prepared.Intent memory i
    ) external view returns (Content.Facts memory) {
        return Reads.requireBatch(moduleRegistry, b, d, h, i);
    }

    function validate(
        StreamNativePrimaryOfferGate gate,
        address house,
        IStreamMintManager.MintBatch memory b,
        bytes memory d
    ) external view returns (IStreamMintGate.GateResult memory) {
        return gate.validateMint(
            address(this),
            house,
            b.collectionId,
            b.phaseId,
            b.payer,
            b.authorizer,
            b.initialRecipients,
            b.beneficiaries,
            b.contextHash,
            b.expectedPolicyHash,
            d
        );
    }
}

/// @dev Canonical registry record seam; real gate runtime and full manifest are still checked.
contract OfferAdmissionRegistryBoundary {
    mapping(address => StreamModuleRecord) private _records;

    function set(address target, StreamModuleRecord memory record) external {
        _records[target] = record;
    }

    function moduleRecord(address target) external view returns (StreamModuleRecord memory) {
        return _records[target];
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IStreamModuleRegistry).interfaceId;
    }
}

/// @dev Explicit house read seam with malformed-return modes, not a runnable sale executor.
contract OfferAdmissionHouseBoundary {
    Offer.Purchase private _purchase;
    Prepared.Intent private _intent;
    bytes32 private _hash;
    address private _seller;
    uint8 private _kind;
    Refund.DelegationConfiguration private _delegation;
    uint256 public fault;
    address public primarySaleSettlement = address(0x5E771E);

    function arm(bytes32 hash, Offer.Purchase memory p, Prepared.Intent memory i) external {
        _hash = hash;
        _purchase = p;
        _intent = i;
    }

    function bind(address seller, uint8 kind) external {
        _seller = seller;
        _kind = kind;
    }

    function configure(Refund.DelegationConfiguration memory d) external {
        _delegation = d;
    }

    function setFault(uint256 value) external {
        fault = value;
    }

    function gasParameter(bytes32) external view returns (uint256) {
        if (fault == 7) assembly ("memory-safe") { return(0, 0) }
        return 500000;
    }

    function refundDelegationConfiguration()
        external
        view
        returns (Refund.DelegationConfiguration memory)
    {
        if (fault == 8) assembly ("memory-safe") { return(0, 224) }
        return _delegation;
    }

    function primaryOfferAuthorizationBinding(bytes32)
        external
        view
        returns (uint256, bytes32, address, uint8, bytes32)
    {
        if (fault == 6) assembly ("memory-safe") { return(0, 128) }
        return (_intent.collectionId, _intent.phaseId, _seller, _kind, _purchase.saleConfigHash);
    }

    function activePreparedNativeOfferPurchase(bytes32 hash)
        external
        view
        returns (Offer.Purchase memory p)
    {
        require(hash == _hash, "active offer");
        p = _purchase;
        bytes memory raw = abi.encode(p);
        if (fault == 1) assembly ("memory-safe") { return(add(raw, 32), 320) }
        if (fault == 2) {
            raw = bytes.concat(raw, abi.encode(uint256(0)));
            assembly ("memory-safe") { return(add(raw, 32), 384) }
        }
        if (fault == 3) {
            assembly ("memory-safe") {
                mstore(add(raw, 288), 0x101)
                return(add(raw, 32), 352)
            }
        }
    }

    function activePreparedNativeOfferIntent(bytes32 hash)
        external
        view
        returns (Prepared.Intent memory i)
    {
        require(hash == _hash, "active offer");
        i = _intent;
        bytes memory raw = abi.encode(i);
        if (fault == 4) assembly ("memory-safe") { return(add(raw, 32), 544) }
        if (fault == 5) {
            raw = bytes.concat(raw, abi.encode(uint256(0)));
            assembly ("memory-safe") { return(add(raw, 32), 608) }
        }
    }
}

/// @notice Real original Sales signatures, published leaf proofs and NFTDelegation grant rows.
/// Manager/ledger/house/registry lifecycle reads are typed boundaries; runtime settlement is separate.
contract StreamPreparedNativeOfferTest {
    CuratedGateVm private constant vm =
        CuratedGateVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 private constant SELLER_KEY = 0x5E11;
    uint256 private constant BUYER_KEY = 0xB0B;
    uint256 private constant DELEGATE_KEY = 0xDE1;
    bytes32 private constant SALE = keccak256("original offer sale");
    bytes32 private constant PHASE = keccak256("phase");
    bytes32 private constant CONFIG = keccak256("immutable original config");
    bytes32 private constant POLICY = keccak256("bound mint policy");
    bytes32 private constant COUNTER = keccak256("content uniqueness");
    OfferAdmissionRegistryBoundary private registry;
    OfferAdmissionManagerBoundary private manager;
    OfferAdmissionHouseBoundary private house;
    StreamNativePrimaryOfferGate private gate;
    address private seller;
    address private buyer;

    struct Case {
        IStreamMintManager.MintBatch batch;
        Offer.GateData data;
        Offer.Purchase purchase;
        Prepared.Intent intent;
        Content.Facts content;
    }

    function setUp() public {
        vm.warp(1000);
        seller = vm.addr(SELLER_KEY);
        buyer = vm.addr(BUYER_KEY);
        registry = new OfferAdmissionRegistryBoundary();
        manager = new OfferAdmissionManagerBoundary(address(registry));
        house = new OfferAdmissionHouseBoundary();
        house.bind(seller, 1);
        Content.Row[] memory rows = new Content.Row[](2);
        rows[0] = Content.Row(0, keccak256("actual selected bytes"), "urn:preview:zero");
        rows[1] =
            Content.Row(bytes32(uint256(1)), keccak256("other actual bytes"), "urn:preview:one");
        gate = new StreamNativePrimaryOfferGate(
            address(manager), address(house), SALE, 1, PHASE, COUNTER, rows
        );
    }

    function testUnselectedOriginalTwoSignaturesBindActualBytesWithoutContentClaim() public {
        Case memory c = _case(false);
        Content.Facts memory actual = _read(c);
        require(
            actual.gate == address(0) && actual.contentLeaf == 0 && actual.counterId == 0,
            "no selected content claim"
        );
        require(
            actual.tokenDataHash == keccak256(c.batch.tokenData[0])
                && actual.contextHash == c.batch.contextHash,
            "actual signed bytes and original context"
        );
        require(
            c.purchase.offerDigest != c.intent.saleAuthorizationDigest
                && c.purchase.authorizationId
                    == StreamMintTicketHash.authorizationId(c.purchase.offerDigest),
            "separate buyer replay digest"
        );
        require(
            c.purchase.authorizationId
                != StreamMintTicketHash.authorizationId(c.intent.saleAuthorizationDigest),
            "seller digest never buyer replay"
        );
    }

    function testSelectedReadsAndRealGateAuthenticateCompleteManifestAndOfferSigner() public {
        _selectGate();
        Case memory c = _case(true);
        Content.Facts memory actual = _read(c);
        require(
            keccak256(abi.encode(actual)) == keccak256(abi.encode(c.content)),
            "same actual selected facts"
        );
        IStreamMintGate.GateResult memory result = _gate(c);
        require(
            result.authorizer == buyer && result.authorizerKind == 1
                && result.authorizationId == c.purchase.authorizationId && result.maxQuantity == 1
                && result.nullifiers.length == 0 && result.gateHash != 0,
            "explicit buyer offer admission"
        );
        require(
            gate.supportsInterface(type(IStreamPreparedNativeOfferGate).interfaceId)
                && !gate.supportsInterface(
                    type(IStreamPreparedNativeContentPurchaseGate).interfaceId
                ),
            "new capability only"
        );
    }

    function testEveryOriginalSellerPayloadWordIsAuthenticated() public {
        Case memory original = _case(false);
        for (uint256 n; n < 24; ++n) {
            Case memory c = abi.decode(abi.encode(original), (Case));
            bytes memory raw = abi.encode(c.data.authorization);
            assembly ("memory-safe") {
                let p := add(add(raw, 32), mul(n, 32))
                mstore(p, xor(mload(p), 1))
            }
            c.data.authorization = abi.decode(raw, (Sales.SaleAuthorization));
            vm.expectRevert();
            _signatures(c);
        }
    }

    function testEveryOriginalBuyerOfferWordIsAuthenticated() public {
        Case memory original = _case(false);
        for (uint256 n; n < 12; ++n) {
            Case memory c = abi.decode(abi.encode(original), (Case));
            bytes memory raw = abi.encode(c.data.offer);
            assembly ("memory-safe") {
                let p := add(add(raw, 32), mul(n, 32))
                mstore(p, xor(mload(p), 1))
            }
            c.data.offer = abi.decode(raw, (Sales.SaleOffer));
            vm.expectRevert();
            _signatures(c);
        }
    }

    function testEachActualBatchFieldAndCanonicalArrayHashIsBound() public {
        Case memory original = _case(false);
        for (uint256 n; n < 11; ++n) {
            Case memory c = abi.decode(abi.encode(original), (Case));
            if (n == 0) c.batch.collectionId++;
            if (n == 1) c.batch.phaseId = keccak256("other phase");
            if (n == 2) c.batch.payer = seller;
            if (n == 3) c.batch.authorizer = seller;
            if (n == 4) c.batch.initialRecipients[0] = buyer;
            if (n == 5) c.batch.beneficiaries[0] = seller;
            if (n == 6) c.batch.tokenData[0] = "changed full bytes";
            if (n == 7) c.batch.mintCommitments[0] = keccak256("other commitment");
            if (n == 8) c.batch.expectedPolicyHash = keccak256("other policy");
            if (n == 9) {
                c.batch.authorizationId =
                    StreamMintTicketHash.authorizationId(c.intent.saleAuthorizationDigest);
            }
            if (n == 10) c.batch.contextHash = c.intent.contentSelectionHash;
            vm.expectRevert();
            _read(c);
        }
    }

    function testSellerAndBuyerSignaturesCannotBeInterchanged() public {
        Case memory c = _case(false);
        bytes memory original = c.data.sellerSignature.signature;
        c.data.sellerSignature.signature = c.data.buyerSignature.signature;
        c.data.buyerSignature.signature = original;
        vm.expectRevert();
        _signatures(c);
    }

    function testResignedWrongPrimaryProfileAndNonNativeOfferAreRejected() public {
        Case memory c = _case(false);
        c.data.authorization.saleKind = 5;
        _sign(c, SELLER_KEY, BUYER_KEY);
        vm.expectRevert();
        _signatures(c);
        c = _case(false);
        c.data.offer.asset = address(0xA55E7);
        _sign(c, SELLER_KEY, BUYER_KEY);
        vm.expectRevert();
        _signatures(c);
    }

    function testOriginalDeadlinesAndFinalizeByRemainStrict() public {
        Case memory c = _case(false);
        vm.warp(c.data.offer.deadline);
        _signatures(c);
        vm.warp(uint256(c.data.offer.deadline) + 1);
        vm.expectRevert();
        _signatures(c);
        vm.warp(1000);
        c.data.authorization.finalizeBy = 1200;
        _sign(c, SELLER_KEY, BUYER_KEY);
        vm.expectRevert();
        _signatures(c);
        c = _case(false);
        c.data.offer.finalizeBy = 1200;
        _sign(c, SELLER_KEY, BUYER_KEY);
        vm.expectRevert();
        _signatures(c);
    }

    function testBuyerNonceChangesOnlyBuyerDigestAndReplayKey() public {
        Case memory c = _case(false);
        bytes32 sellerDigest = c.intent.saleAuthorizationDigest;
        bytes32 offerDigest = c.purchase.offerDigest;
        c.data.offer.nonce = keccak256("second buyer nonce");
        _sign(c, SELLER_KEY, BUYER_KEY);
        require(
            c.intent.saleAuthorizationDigest == sellerDigest
                && c.purchase.offerDigest != offerDigest
                && c.purchase.authorizationId
                    == StreamMintTicketHash.authorizationId(c.purchase.offerDigest),
            "two digest families remain distinct"
        );
        _signatures(c);
    }

    function testExact352BytePurchaseAnd576ByteIntentReadsRejectLegacyAndTrailingForms() public {
        Case memory c = _case(true);
        for (uint256 n = 1; n <= 3; ++n) {
            house.setFault(n);
            vm.expectRevert();
            Hash.readPurchase(address(house), c.data.intentHash, c.intent);
        }
        house.setFault(0);
        Hash.readPurchase(address(house), c.data.intentHash, c.intent);
        for (uint256 n = 4; n <= 5; ++n) {
            house.setFault(n);
            vm.expectRevert();
            _gate(c);
        }
    }

    function testMalformedHistoricalMembershipAndGasReadsFailClosed() public {
        Case memory c = _case(false);
        house.setFault(6);
        vm.expectRevert();
        _signatures(c);
        house.setFault(7);
        vm.expectRevert();
        _signatures(c);
        house.setFault(0);
        house.bind(buyer, 1);
        vm.expectRevert();
        _signatures(c);
    }

    function testExplicitEOAAndContractSignerKindsCannotBeSubstituted() public {
        Case memory c = _case(false);
        c.data.sellerSignature.kind = 2;
        vm.expectRevert();
        _signatures(c);
        c = _case(false);
        c.data.buyerSignature.kind = 2;
        c.purchase.authorizerKind = 2;
        vm.expectRevert();
        _signatures(c);
    }

    function testActualERC1271SellerAndBuyerSignaturesAndMalformedReturns() public {
        CuratedGateSignatureWallet sellerWallet = new CuratedGateSignatureWallet(seller);
        CuratedGateSignatureWallet buyerWallet = new CuratedGateSignatureWallet(buyer);
        seller = address(sellerWallet);
        buyer = address(buyerWallet);
        house.bind(seller, 2);
        Case memory c = _case(false);
        c.data.sellerSignature.kind = 2;
        c.data.buyerSignature.kind = 2;
        c.purchase.authorizerKind = 2;
        _arm(c);
        _read(c);
        for (uint256 n = 1; n <= 4; ++n) {
            buyerWallet.setMode(n);
            vm.expectRevert();
            _signatures(c);
        }
        buyerWallet.setMode(0);
        sellerWallet.setMode(3);
        vm.expectRevert();
        _signatures(c);
    }

    function testUnselectedRequiresGenuinelyEmptyGateConfigurationAndSelection() public {
        Case memory c = _case(false);
        IStreamMintManager.MintGateConfig memory residual;
        residual.gateConfigHash = keccak256("residual selected config");
        manager.setGate(residual, COUNTER);
        vm.expectRevert();
        _read(c);
        delete residual.gateConfigHash;
        manager.setGate(residual, 0);
        c.data.selection.tokenDataHash = keccak256(c.batch.tokenData[0]);
        vm.expectRevert();
        _read(c);
        c = _case(false);
        c.data.selection.proof = new bytes32[](1);
        vm.expectRevert();
        _read(c);
    }

    function testUnselectedCannotSmuggleSignedSelectedHashOrSelectedContext() public {
        Case memory c = _case(true);
        delete c.data.selection;
        vm.expectRevert();
        _read(c);
        c = _case(false);
        c.batch.contextHash = ContentHash.context(block.chainid, address(house), SALE, 0);
        vm.expectRevert();
        _read(c);
    }

    function testSelectedCounterMustBeStaticCapOne() public {
        _selectGate();
        Case memory c = _case(true);
        manager.setCounterCap(2);
        vm.expectRevert();
        _read(c);
    }

    function testSelectedWrongProofAndEmptySelectionCannotEnterNewGate() public {
        _selectGate();
        Case memory c = _case(true);
        c.data.selection.proof[0] = keccak256("wrong sibling");
        vm.expectRevert();
        _read(c);
        vm.expectRevert();
        _gate(c);
        c = _case(true);
        delete c.data.selection;
        vm.expectRevert();
        _read(c);
    }

    function testGateRequiresExactNewAdmissionAndCanonicalGateBytes() public {
        Case memory c = _case(true);
        manager.setAdmission(keccak256("old content admission"), c.content);
        vm.expectRevert();
        _gate(c);
        _arm(c);
        vm.expectRevert();
        manager.validate(gate, address(house), c.batch, bytes.concat(abi.encode(c.data), hex"00"));
    }

    function testActualDelegationRequiresLiveGrantAndHouseManifest() public {
        Case memory c = _case(false);
        DelegationManagementContract delegates = _delegated(c);
        _read(c);
        address core = manager.core();
        vm.prank(buyer);
        delegates.revokeDelegationAddress(core, c.purchase.authorizer, 2);
        vm.expectRevert();
        _read(c);
    }

    function testDelegationWrongScopeExpiredAndTokenLimitedRowsFail() public {
        Case memory c = _case(false);
        DelegationManagementContract delegates = _delegated(c);
        c.data.buyerDelegation.walletWide = true;
        vm.expectRevert();
        _signatures(c);
        c.data.buyerDelegation.walletWide = false;
        _signatures(c);
        vm.warp(1499);
        _signatures(c);
        vm.warp(1500);
        vm.expectRevert();
        _signatures(c);
        vm.warp(1000);
        _signatures(c);
        address core = manager.core();
        vm.prank(buyer);
        delegates.registerDelegationAddress(core, c.purchase.authorizer, 2000, 2, false, 1);
        _assertGrantRow(delegates, core, c.purchase.authorizer, 1, 2000, false, 1);
        c.data.buyerDelegation.index = 1;
        vm.expectRevert();
        _signatures(c);
        c.data.buyerDelegation.index = 0;
        _signatures(c);
    }

    function testDelegationManifestNamesActualHouseAndExactPinnedUsecase() public {
        Case memory c = _case(false);
        _delegated(c);
        StreamModuleRecord memory r = registry.moduleRecord(address(house));
        r.moduleManifestHash = keccak256("different usecase or Manager manifest");
        registry.set(address(house), r);
        vm.expectRevert();
        _signatures(c);
    }

    function testMalformedDelegationConfigurationFailsButDirectBuyerNeedsNoProvider() public {
        Case memory c = _case(false);
        _delegated(c);
        house.setFault(8);
        vm.expectRevert();
        _signatures(c);
        c = _case(false);
        _read(c);
    }

    function testUnselectedActiveFactsRequireConsumedOfferTicketAndEmptyContentClaim() public {
        Case memory c = _case(false);
        Prepared.Facts memory facts = _active(c);
        vm.expectRevert();
        Reads.requireActive(address(registry), facts, c.intent);
        manager.setAuthorizationUsed(true);
        Reads.requireActive(address(registry), facts, c.intent);
        c.content.counterId = COUNTER;
        _active(c);
        vm.expectRevert();
        Reads.requireActive(address(registry), facts, c.intent);
    }

    function testSelectedActiveFactsRequireExactlyOneConsumedContentCounter() public {
        _selectGate();
        Case memory c = _case(true);
        Prepared.Facts memory facts = _active(c);
        manager.setAuthorizationUsed(true);
        Reads.requireActive(address(registry), facts, c.intent);
        manager.setCount(0);
        vm.expectRevert();
        Reads.requireActive(address(registry), facts, c.intent);
        manager.setCount(2);
        vm.expectRevert();
        Reads.requireActive(address(registry), facts, c.intent);
    }

    function _case(bool selected) private returns (Case memory c) {
        c.batch.collectionId = 1;
        c.batch.phaseId = PHASE;
        c.batch.payer = buyer;
        c.batch.authorizer = buyer;
        c.batch.initialRecipients = new address[](1);
        c.batch.initialRecipients[0] = address(house);
        c.batch.beneficiaries = new address[](1);
        c.batch.beneficiaries[0] = buyer;
        c.batch.tokenData = new bytes[](1);
        c.batch.tokenData[0] = "actual selected bytes";
        c.batch.mintCommitments = new bytes32[](1);
        c.batch.mintCommitments[0] = keccak256("exact mint commitment");
        c.batch.expectedPolicyHash = POLICY;
        c.intent.collectionId = 1;
        c.intent.phaseId = PHASE;
        c.intent.saleId = SALE;
        c.intent.saleNonce = 1;
        c.intent.executor = buyer;
        c.intent.payer = buyer;
        c.intent.poster = seller;
        c.intent.beneficiary = buyer;
        c.intent.amount = 1000;
        c.intent.originalPrimaryPolicyHash = keccak256("original primary PROFILE policy");
        c.intent.executionNonce = 1;
        c.intent.authorityMode = 1;
        c.intent.saleExecutionHash = keccak256("full original sale execution");
        c.intent.mintCommitment = c.batch.mintCommitments[0];
        c.intent.boundMintPolicyHash = POLICY;
        c.purchase.saleId = SALE;
        c.purchase.saleNonce = 1;
        c.purchase.saleConfigHash = CONFIG;
        c.purchase.buyer = buyer;
        c.purchase.purchaseNonce = 1;
        c.purchase.purchaseId = Hash.purchaseId(address(house), SALE, buyer, 1);
        c.purchase.authorizer = buyer;
        c.purchase.authorizerKind = 1;
        c.data.sellerSignature.authorizer = seller;
        c.data.sellerSignature.kind = 1;
        c.data.buyerSignature.authorizer = buyer;
        c.data.buyerSignature.kind = 1;
        if (selected) {
            c.data.selection.tokenDataHash = keccak256(c.batch.tokenData[0]);
            c.data.selection.proof = new bytes32[](1);
            c.data.selection.proof[0] = ContentHash.leaf(
                block.chainid,
                address(house),
                SALE,
                bytes32(uint256(1)),
                keccak256("other actual bytes")
            );
            c.intent.contentSelectionHash = ContentHash.leaf(
                block.chainid, address(house), SALE, 0, c.data.selection.tokenDataHash
            );
        }
        Sales.SaleAuthorization memory a;
        a.chainId = block.chainid;
        a.saleAdapter = address(house);
        a.mintManager = address(manager);
        a.collectionId = 1;
        a.phaseId = PHASE;
        a.saleId = SALE;
        a.saleKind = 6;
        a.revenueClass = keccak256("PRIMARY_SALE");
        a.expectedPrimaryPolicyHash = c.intent.originalPrimaryPolicyHash;
        a.initialRecipientsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), c.batch.initialRecipients)
        );
        a.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), c.batch.beneficiaries)
        );
        a.tokenDataArrayHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), c.batch.tokenData)
        );
        a.mintCommitmentsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), c.batch.mintCommitments)
        );
        a.payer = buyer;
        a.executor = buyer;
        a.unitPrice = 1000;
        a.quantity = 1;
        a.contentSelectionHash = c.intent.contentSelectionHash;
        a.policyHash = POLICY;
        a.nonce = keccak256("original seller nonce");
        a.deadline = 2000;
        c.data.authorization = a;
        c.data.offer = Sales.SaleOffer(
            block.chainid,
            address(house),
            manager.core(),
            1,
            0,
            c.intent.contentSelectionHash,
            buyer,
            address(0),
            1000,
            keccak256("original offer nonce"),
            2000,
            0
        );
        _sign(c, SELLER_KEY, BUYER_KEY);
        if (selected) {
            Content.Publication memory p = gate.publication();
            c.batch.contextHash = ContentHash.context(block.chainid, address(house), SALE, 0);
            c.content = Content.Facts(
                0,
                address(gate),
                address(gate).codehash,
                gate.gateConfigHash(),
                p.manifestRoot,
                p.manifestHash,
                COUNTER,
                0,
                c.data.selection.tokenDataHash,
                c.intent.contentSelectionHash,
                c.batch.contextHash
            );
        } else {
            c.batch.contextHash =
                PreparedHash.mintContext(address(manager), address(house), c.data.intentHash);
            c.content.tokenDataHash = keccak256(c.batch.tokenData[0]);
            c.content.contextHash = c.batch.contextHash;
        }
        _arm(c);
    }

    function _sign(Case memory c, uint256 sellerKey, uint256 buyerKey) private {
        c.intent.saleAuthorizationDigest = StreamPrivateSaleHash.digest(
            block.chainid,
            address(house),
            StreamPrivateSaleHash.authorizationBody(c.data.authorization)
        );
        c.purchase.offerDigest = StreamPrivateSaleHash.digest(
            block.chainid, address(house), StreamPrivateSaleHash.offerBody(c.data.offer)
        );
        c.purchase.authorizationId = StreamMintTicketHash.authorizationId(c.purchase.offerDigest);
        c.data.authorizationId = c.purchase.authorizationId;
        c.batch.authorizationId = c.purchase.authorizationId;
        c.data.intentHash = Hash.intentHash(address(house), house.primarySaleSettlement(), c.intent);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerKey, c.intent.saleAuthorizationDigest);
        c.data.sellerSignature.signature = abi.encodePacked(r, s, v);
        (v, r, s) = vm.sign(buyerKey, c.purchase.offerDigest);
        c.data.buyerSignature.signature = abi.encodePacked(r, s, v);
    }

    function _arm(Case memory c) private {
        house.arm(c.data.intentHash, c.purchase, c.intent);
        manager.setAdmission(
            Hash.admissionHash(address(house), c.data.intentHash, c.purchase, c.content), c.content
        );
    }

    function _read(Case memory c) private returns (Content.Facts memory) {
        vm.prank(address(house));
        return manager.readBatch(c.batch, abi.encode(c.data), c.data.intentHash, c.intent);
    }

    function _gate(Case memory c) private view returns (IStreamMintGate.GateResult memory) {
        return manager.validate(gate, address(house), c.batch, abi.encode(c.data));
    }

    function _signatures(Case memory c) private view {
        Signatures.validate(address(manager), address(house), c.data, c.purchase, c.intent);
    }

    function _selectGate() private {
        StreamModuleRecord memory r;
        r.status = ModuleRegistryStatus.ACTIVE;
        r.moduleType = keccak256("6529STREAM_MINT_GATE_V1");
        r.moduleVersion = keccak256("offer gate version");
        r.interfaceId = type(IStreamMintGate).interfaceId;
        r.moduleGasLimit = 2000000;
        r.runtimeCodeHash = address(gate).codehash;
        r.moduleManifestHash = gate.publication().manifestHash;
        r.revision = 1;
        registry.set(address(gate), r);
        manager.setGate(
            IStreamMintManager.MintGateConfig(
                address(gate),
                gate.gateConfigHash(),
                address(gate).codehash,
                keccak256(abi.encode(r.moduleVersion, r.moduleManifestHash)),
                0,
                r.moduleGasLimit
            ),
            COUNTER
        );
    }

    function _delegated(Case memory c) private returns (DelegationManagementContract delegates) {
        delegates = new DelegationManagementContract();
        address core = manager.core();
        address signer = vm.addr(DELEGATE_KEY);
        c.purchase.authorizer = signer;
        c.batch.authorizer = signer;
        c.data.buyerSignature.authorizer = signer;
        _sign(c, SELLER_KEY, DELEGATE_KEY);
        Refund.DelegationConfiguration memory config = Refund.DelegationConfiguration(
            block.chainid,
            core,
            address(delegates),
            address(delegates).codehash,
            2,
            keccak256("original host manifest"),
            address(registry),
            address(registry).codehash
        );
        house.configure(config);
        StreamModuleRecord memory r;
        r.status = ModuleRegistryStatus.ACTIVE;
        r.runtimeCodeHash = address(house).codehash;
        r.deploymentManifestHash = keccak256("host deployment");
        r.moduleManifestHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_AUCTION_NFTDELEGATION_MANIFEST_V1"),
                block.chainid,
                address(house),
                config.baseManifestHash,
                core,
                address(delegates),
                address(delegates).codehash,
                uint256(2)
            )
        );
        r.registeredAt = 1000;
        r.statusUpdatedAt = 1000;
        r.revision = 1;
        registry.set(address(house), r);
        vm.prank(buyer);
        delegates.registerDelegationAddress(core, signer, 1500, 2, true, 0);
        _assertGrantRow(delegates, core, signer, 0, 1500, true, 0);
        _arm(c);
        _signatures(c);
    }

    function _assertGrantRow(
        DelegationManagementContract delegates,
        address core,
        address signer,
        uint256 index,
        uint256 expiry,
        bool allTokens,
        uint256 tokenId
    ) private view {
        bytes32 key = keccak256(abi.encodePacked(buyer, core, signer, uint256(2)));
        (
            address vault,
            address delegate,
            uint256 registered,
            uint256 expires,
            bool all,
            uint256 token
        ) = delegates.globalDelegationHashes(key, index);
        require(
            vault == buyer && delegate == signer && registered == 1000 && expires == expiry
                && all == allTokens && token == tokenId,
            "actual buyer delegation row at expected index"
        );
    }

    function _active(Case memory c) private returns (Prepared.Facts memory f) {
        f.saleAdapter = address(house);
        f.mintManager = address(manager);
        f.collectionId = 1;
        f.phaseId = PHASE;
        f.intentHash = c.data.intentHash;
        f.operationRoot = keccak256("actual root boundary");
        f.tokenDataHash = c.content.tokenDataHash;
        f.payer = buyer;
        f.beneficiary = buyer;
        bytes32 admission =
            Hash.admissionHash(address(house), c.data.intentHash, c.purchase, c.content);
        Content.Facts memory active = abi.decode(abi.encode(c.content), (Content.Facts));
        active.operationRoot = f.operationRoot;
        manager.setAdmission(admission, active);
    }
}
