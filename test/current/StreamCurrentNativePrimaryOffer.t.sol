// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./helpers/NativeCuratedSaleFixture.sol";
import {
    IStreamNativeRefundDelegatedClaims
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeRefundDelegatedClaims.sol";
import {
    StreamNativePrimaryOfferSale
} from "../../smart-contracts/domains/mint/StreamNativePrimaryOfferSale.sol";
import {
    StreamNativePrimaryOfferGate
} from "../../smart-contracts/domains/mint/StreamNativePrimaryOfferGate.sol";
import {
    StreamNativePrimaryOfferAuthorization
} from "../../smart-contracts/domains/mint/StreamNativePrimaryOfferAuthorization.sol";
import {
    StreamPrivateSaleHash
} from "../../smart-contracts/domains/mint/StreamPrivateSaleHash.sol";
import { StreamMintTicketHash } from "../../smart-contracts/domains/mint/StreamMintTicketHash.sol";
import {
    IStreamPreparedNativeOfferMint,
    IStreamPreparedNativeOfferSettlement
} from "../../smart-contracts/interfaces/stream/mint/IStreamPreparedNativeOfferMint.sol";
import {
    StreamPrivateSaleTypes
} from "../../smart-contracts/interfaces/stream/mint/StreamPrivateSaleTypes.sol";
import {
    IStreamPrivateSaleAdapter
} from "../../smart-contracts/interfaces/stream/mint/IStreamPrivateSaleAdapter.sol";
import {
    StreamNativePrimaryOfferTypes as OfferT
} from "../../smart-contracts/interfaces/stream/mint/StreamNativePrimaryOfferTypes.sol";
import {
    DelegationManagementContract
} from "../../smart-contracts/integrations/delegation/NFTdelegation.sol";

interface CurrentPrimaryOfferVm {
    function expectEmit(bool, bool, bool, bool, address) external;
}

/// @dev A seller signature is valid only after the host writes the original seller digest.
contract CurrentPrimaryOfferSeller {
    address private immutable owner;
    StreamNativePrimaryOfferSale private host;
    bytes32 private expectedDigest;

    constructor(address signer) {
        owner = signer;
    }

    function configure(StreamNativePrimaryOfferSale target, bytes32 digest) external {
        host = target;
        expectedDigest = digest;
    }

    function isValidSignature(bytes32 digest, bytes calldata signature)
        external
        view
        returns (bytes4)
    {
        if (digest != expectedDigest || signature.length != 65 || !host.digestConsumed(digest)) return 0xffffffff;
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly ("memory-safe") {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }
        return ecrecover(digest, v, r, s) == owner ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
    }
}

/// @dev Controlled buyer callback, explicitly separate from the actual threshold Safe cases below.
contract CurrentPrimaryOfferBuyer is IERC721Receiver {
    address private immutable owner;
    StreamNativePrimaryOfferSale private host;
    bytes32 private sellerDigest;
    bool public rejects;
    bool public sawSellerConsumed;

    constructor(address signer) {
        owner = signer;
    }

    function configure(StreamNativePrimaryOfferSale target, bytes32 digest, bool reject_) external {
        host = target;
        sellerDigest = digest;
        rejects = reject_;
    }

    function callTarget(address target, bytes calldata data)
        external
        payable
        returns (bytes memory raw)
    {
        bool ok;
        (ok, raw) = target.call{ value: msg.value }(data);
        if (!ok) assembly ("memory-safe") { revert(add(raw, 32), mload(raw)) }
    }

    function isValidSignature(bytes32 digest, bytes calldata signature)
        external
        view
        returns (bytes4)
    {
        if (signature.length != 65) return 0xffffffff;
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly ("memory-safe") {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }
        // The seller digest must already be consumed even at the buyer's first signature read.
        if (!host.digestConsumed(sellerDigest)) return 0xffffffff;
        return ecrecover(digest, v, r, s) == owner ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        sawSellerConsumed = host.digestConsumed(sellerDigest);
        require(!rejects, "primary offer receiver rejects");
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice Actual Core/Manager/Ledger/Registry/recorder/native wallet graph and original NFTDelegation.
/// @dev Artist, entropy and target-side governance retain the shared fixture's explicit boundaries.
contract StreamCurrentNativePrimaryOfferTest is NativeCuratedSaleFixture {
    StreamNativePrimaryOfferSale private offers;
    DelegationManagementContract private offerDelegation;
    uint256 private planNonce;
    uint256 private constant OFFER_DELEGATE_KEY = 0xD311;
    uint256 private constant OFFER_EXECUTOR_KEY = 0xE311;
    bytes32 private constant OFFER_SIGNER_EVIDENCE =
        keccak256("current primary offer signer evidence");

    struct OfferPlan {
        bytes32 saleId;
        uint256 nonce;
        bytes32 counter;
        bytes32 leaf;
        StreamNativePrimaryOfferGate gate;
        OfferT.Configuration config;
    }

    event OfferAccepted(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed buyer,
        bytes32 offerDigest,
        uint256 price,
        address asset
    );
    event SaleAuthorizationConsumed(
        uint16 schemaVersion, bytes32 indexed saleId, bytes32 indexed digest, address authorizer
    );

    function setUp() public override {
        super.setUp();
        offers = new StreamNativePrimaryOfferSale(_curatedDeployment());
        _registerCuratedHost(address(offers));
        entropy.configure(7, 1, false, false);
        vm.deal(address(this), 1 ether);
    }

    function testSelectedPrimaryOfferConsumesBothLociAndExactCurrentRevenue() public {
        (OfferPlan memory p, OfferT.Acceptance memory q) =
            _open(true, payer, vm.addr(SIGNER_KEY), 1, _emptyOffer());
        bytes32 sellerDigest = offers.authorizationDigest(q.authorization);
        bytes32 buyerDigest = offers.offerDigest(q.offer);
        CurrentPrimaryOfferVm(address(vm)).expectEmit(true, true, false, true, address(offers));
        emit SaleAuthorizationConsumed(1, p.saleId, sellerDigest, p.config.signer);
        CurrentPrimaryOfferVm(address(vm)).expectEmit(true, true, false, true, address(offers));
        emit OfferAccepted(1, p.saleId, payer, buyerDigest, 1000, address(0));
        vm.prank(payer);
        Curated.ExecutionRecord memory e = offers.acceptPrimaryOffer{ value: 1027 }(q);
        _assertExecution(p, q, e);
        require(wallet.balance == 1000 && entropy.revealFeeEscrow(1) == 7, "price and fee separate");
        require(
            offers.refundableBalance(p.saleId, payer) == 20 && offers.refundLiability() == 20,
            "buyer owns allowance"
        );
        require(ledger.counterValue(_offerCounterKey(p)) == 1, "selected content cap consumed");
    }

    function testCollectionLevelOfferSignsRawArtworkWithoutInventedContentIdentity() public {
        (OfferPlan memory p, OfferT.Acceptance memory q) =
            _open(false, payer, vm.addr(SIGNER_KEY), 1, _emptyOffer());
        require(
            q.offer.tokenId == 0 && q.offer.contentSelectionHash == 0
                && q.authorization.contentSelectionHash == 0,
            "original collection offer"
        );
        vm.prank(payer);
        Curated.ExecutionRecord memory e = offers.acceptPrimaryOffer{ value: 1007 }(q);
        _assertExecution(p, q, e);
        require(
            e.contentLeaf == 0 && offers.saleRecord(p.saleId).gate == address(0),
            "no content gate or leaf"
        );
        require(
            keccak256(core.tokenData(e.tokenId)) == keccak256(q.selection.tokenData),
            "full signed artwork bytes"
        );
    }

    function testBuyerLedgerVoidUsesOriginalOfferKeyAndSurvivesHistoricalDependencies() public {
        (OfferPlan memory p, OfferT.Acceptance memory q) =
            _open(false, payer, vm.addr(SIGNER_KEY), 1, _emptyOffer());
        bytes32 id = _offerId(q.offer);
        vm.prank(payer);
        require(manager.voidMintOffer(q.offer, 1, "") == id, "actual same-key buyer void");
        vm.expectRevert();
        vm.prank(payer);
        offers.acceptPrimaryOffer{ value: 1007 }(q);
        require(
            !offers.digestConsumed(offers.authorizationDigest(q.authorization)),
            "failed acceptance restores seller digest"
        );
        require(
            ledger.isManagerAuthorizationUsed(address(manager), id)
                && core.lastAllocatedTokenId() == 0,
            "void remains durable"
        );
        q.offer.nonce = keccak256("historical unused offer");
        bytes32 historicalId = _offerId(q.offer);
        offers.configureCollectionSigner(1, p.config.signer, 1, OFFER_SIGNER_EVIDENCE, false);
        manager.setPhasePaused(1, p.config.sale.phaseId, true);
        NativeCuratedArtistBoundary(address(artists)).setConsent(false);
        _status(address(offers), ModuleRegistryStatus.INCIDENT_REVOKED);
        vm.warp(p.config.sale.endsAt + 1);
        vm.etch(address(entropy), hex"60006000fd");
        vm.prank(payer);
        require(
            manager.voidMintOffer(q.offer, 1, "") == historicalId,
            "expired unavailable offer still voidable"
        );
        require(
            ledger.isManagerAuthorizationUsed(address(manager), historicalId)
                && manager.nextOperationNonce() == 0,
            "void allocates no mint"
        );
    }

    function testSellerHistoricalDirectRevocationUsesAdapterStoreAfterSignerAndArtistLoss() public {
        (OfferPlan memory p, OfferT.Acceptance memory q) =
            _open(true, payer, vm.addr(SIGNER_KEY), 1, _emptyOffer());
        bytes32 sellerDigest = offers.authorizationDigest(q.authorization);
        bytes32 offerId = _offerId(q.offer);
        IStreamPrivateSaleAdapter.Signature memory proof =
            IStreamPrivateSaleAdapter.Signature(p.config.signer, 1, "");
        vm.expectRevert();
        offers.revokeAuthorization(q.authorization, proof);
        require(!offers.digestConsumed(sellerDigest), "outsider cannot void seller");
        offers.configureCollectionSigner(1, p.config.signer, 1, OFFER_SIGNER_EVIDENCE, false);
        manager.setPhasePaused(1, p.config.sale.phaseId, true);
        NativeCuratedArtistBoundary(address(artists)).setConsent(false);
        _status(address(offers), ModuleRegistryStatus.INCIDENT_REVOKED);
        vm.warp(p.config.sale.endsAt + 1);
        offers.expirePrimaryOffer(p.saleId);
        vm.etch(address(entropy), hex"60006000fd");
        vm.prank(p.config.signer);
        offers.revokeAuthorization(q.authorization, proof);
        require(
            offers.digestConsumed(sellerDigest) && offers.digestRevoked(sellerDigest),
            "permanent adapter void"
        );
        require(
            !ledger.isManagerAuthorizationUsed(address(manager), offerId)
                && manager.nextOperationNonce() == 0,
            "seller void never consumes buyer lane"
        );
        vm.expectRevert();
        vm.prank(p.config.signer);
        offers.revokeAuthorization(q.authorization, proof);
    }

    function testRelayedOfficialSafeSellerRevocationRequiresExactRevocationFamily() public {
        (OfficialSafe seller, uint256[] memory sellerKeys) = _offerSafe(701);
        (OfferPlan memory p, OfferT.Acceptance memory q) =
            _open(false, payer, address(seller), 2, _emptyOffer());
        bytes32 digest = offers.authorizationDigest(q.authorization);
        IStreamPrivateSaleAdapter.Signature memory proof = IStreamPrivateSaleAdapter.Signature(
            address(seller),
            2,
            safeThresholdSignature(sellerKeys, safeMessageDigest(seller, abi.encode(digest)))
        );
        vm.expectRevert();
        offers.revokeAuthorization(q.authorization, proof);
        require(!offers.digestConsumed(digest), "ordinary sale signature cannot revoke");
        offers.configureCollectionSigner(1, address(seller), 2, OFFER_SIGNER_EVIDENCE, false);
        NativeCuratedArtistBoundary(address(artists)).setConsent(false);
        vm.warp(p.config.sale.endsAt + 1);
        bytes32 revokeDigest = StreamPrivateSaleHash.digest(
            block.chainid,
            address(offers),
            StreamPrivateSaleHash.authorizationRevocationBody(
                block.chainid, address(offers), address(seller), digest
            )
        );
        proof.signature =
            safeThresholdSignature(sellerKeys, safeMessageDigest(seller, abi.encode(revokeDigest)));
        offers.revokeAuthorization(q.authorization, proof);
        require(
            offers.digestRevoked(digest) && seller.nonce() == 0 && seller.getThreshold() == 2,
            "real relayed historical Safe1271 void"
        );
        require(
            !ledger.isManagerAuthorizationUsed(address(manager), _offerId(q.offer)),
            "buyer offer remains unused"
        );
    }

    function testConsumedOfferCannotExecuteWithFreshSaleAndFreshSellerAuthorization() public {
        (OfferPlan memory first, OfferT.Acceptance memory q) =
            _open(false, payer, vm.addr(SIGNER_KEY), 1, _emptyOffer());
        vm.prank(payer);
        Curated.ExecutionRecord memory e = offers.acceptPrimaryOffer{ value: 1007 }(q);
        _assertExecution(first, q, e);
        (OfferPlan memory second, OfferT.Acceptance memory fresh) =
            _open(false, payer, vm.addr(SIGNER_KEY), 1, q.offer);
        require(
            first.saleId != second.saleId
                && offers.authorizationDigest(q.authorization)
                    != offers.authorizationDigest(fresh.authorization),
            "fresh opposite-side authorization"
        );
        require(_offerId(q.offer) == _offerId(fresh.offer), "unchanged buyer replay key");
        vm.expectRevert();
        vm.prank(payer);
        offers.acceptPrimaryOffer{ value: 1007 }(fresh);
        require(
            !offers.digestConsumed(offers.authorizationDigest(fresh.authorization))
                && offers.nextPurchaseNonce(second.saleId, payer) == 1,
            "failed attempt restores fresh seller and purchase nonce"
        );
        require(
            core.lastAllocatedTokenId() == 1 && recorder.totalOfficialSettled(address(0)) == 1000,
            "no second mint or payment"
        );
    }

    function testConsumedSellerAuthorizationRejectsSecondOfferAtAdapterBeforeOtherChecks() public {
        (OfferPlan memory p, OfferT.Acceptance memory q) =
            _open(false, payer, vm.addr(SIGNER_KEY), 1, _emptyOffer());
        vm.prank(payer);
        offers.acceptPrimaryOffer{ value: 1007 }(q);
        bytes32 sellerDigest = offers.authorizationDigest(q.authorization);
        q.offer.nonce = keccak256("different buyer offer");
        q.buyerProof.signature = _curatedSignature(PAYER_KEY, offers.offerDigest(q.offer));
        bytes32 unusedOfferId = _offerId(q.offer);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativePrimaryOfferSale.PrimaryOfferDigestConsumed.selector, sellerDigest
            )
        );
        vm.prank(payer);
        offers.acceptPrimaryOffer{ value: 1007 }(q);
        require(
            !ledger.isManagerAuthorizationUsed(address(manager), unusedOfferId)
                && offers.saleRecord(p.saleId).status == 4,
            "second offer untouched"
        );
    }

    function testMalformedSelectedContentAndInsufficientAllowanceRollbackBothDigests() public {
        (OfferPlan memory p, OfferT.Acceptance memory q) =
            _open(true, payer, vm.addr(SIGNER_KEY), 1, _emptyOffer());
        bytes memory original = q.selection.tokenData;
        q.selection.tokenData = "substituted unmanifested artwork";
        vm.expectRevert();
        vm.prank(payer);
        offers.acceptPrimaryOffer{ value: 1007 }(q);
        q.selection.tokenData = original;
        q.selection.content.proof = new bytes32[](1);
        q.selection.content.proof[0] = keccak256("false proof");
        vm.expectRevert();
        vm.prank(payer);
        offers.acceptPrimaryOffer{ value: 1007 }(q);
        q.selection.content.proof = new bytes32[](0);
        vm.expectRevert();
        vm.prank(payer);
        offers.acceptPrimaryOffer{ value: 1006 }(q);
        _assertUnused(p, q);
        vm.prank(payer);
        Curated.ExecutionRecord memory e = offers.acceptPrimaryOffer{ value: 1007 }(q);
        _assertExecution(p, q, e);
    }

    function testLateMintAndRejectedNFTPreserveExactPayloadForAtomicRetry() public {
        CurrentPrimaryOfferBuyer buyer = new CurrentPrimaryOfferBuyer(payer);
        (OfferPlan memory p, OfferT.Acceptance memory q) =
            _open(true, address(buyer), vm.addr(SIGNER_KEY), 1, _emptyOffer());
        bytes32 sellerDigest = offers.authorizationDigest(q.authorization);
        buyer.configure(offers, sellerDigest, false);
        bytes memory exact = abi.encodeCall(offers.acceptPrimaryOffer, (q));
        entropy.configure(7, 1, true, false);
        vm.expectRevert();
        buyer.callTarget{ value: 1027 }(address(offers), exact);
        _assertUnused(p, q);
        entropy.configure(7, 1, false, false);
        buyer.configure(offers, sellerDigest, true);
        vm.expectRevert();
        buyer.callTarget{ value: 1027 }(address(offers), exact);
        _assertUnused(p, q);
        buyer.configure(offers, sellerDigest, false);
        Curated.ExecutionRecord memory e = abi.decode(
            buyer.callTarget{ value: 1027 }(address(offers), exact), (Curated.ExecutionRecord)
        );
        _assertExecution(p, q, e);
        require(
            buyer.sawSellerConsumed() && offers.refundableBalance(p.saleId, address(buyer)) == 20,
            "seller consumed before signatures and receiver"
        );
    }

    function testSeller1271ObservesConsumedDigestAndInvalidSignatureRestoresBothReplayLoci()
        public
    {
        CurrentPrimaryOfferSeller seller = new CurrentPrimaryOfferSeller(vm.addr(SIGNER_KEY));
        (OfferPlan memory p, OfferT.Acceptance memory q) =
            _open(false, payer, address(seller), 2, _emptyOffer());
        bytes32 digest = offers.authorizationDigest(q.authorization);
        seller.configure(offers, digest);
        bytes memory validSignature = q.sellerProof.signature;
        q.sellerProof.signature = hex"01";
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativePrimaryOfferAuthorization.PrimaryOfferSignatureInvalid.selector,
                address(seller)
            )
        );
        vm.prank(payer);
        offers.acceptPrimaryOffer{ value: 1007 }(q);
        _assertUnused(p, q);
        q.sellerProof.signature = validSignature;
        vm.prank(payer);
        Curated.ExecutionRecord memory e = offers.acceptPrimaryOffer{ value: 1007 }(q);
        _assertExecution(p, q, e);
        require(offers.digestConsumed(digest), "seller verified the preconsumed original digest");
    }

    function testLiveSignerAndExecutorDelegationsKeepVaultDeliveryAndCredits() public {
        _deployDelegatedOffers();
        (OfferPlan memory p, OfferT.Acceptance memory q) =
            _open(false, payer, vm.addr(SIGNER_KEY), 1, _emptyOffer());
        address signer = vm.addr(OFFER_DELEGATE_KEY);
        address executor = vm.addr(OFFER_EXECUTOR_KEY);
        q.buyerProof = IStreamPrivateSaleAdapter.Signature(
            signer, 1, _curatedSignature(OFFER_DELEGATE_KEY, offers.offerDigest(q.offer))
        );
        q.authorization.executor = executor;
        q.sellerProof.signature =
            _curatedSignature(SIGNER_KEY, offers.authorizationDigest(q.authorization));
        vm.deal(executor, 1 ether);
        vm.prank(payer);
        offerDelegation.registerDelegationAddress(
            address(core), signer, block.timestamp + 1 days, 2, true, 0
        );
        vm.expectRevert();
        vm.prank(executor);
        offers.acceptPrimaryOffer{ value: 1027 }(q);
        _assertUnused(p, q);
        vm.prank(payer);
        offerDelegation.registerDelegationAddress(
            address(core), executor, block.timestamp + 1 days, 2, true, 0
        );
        vm.prank(payer);
        offerDelegation.revokeDelegationAddress(address(core), signer, 2);
        vm.expectRevert();
        vm.prank(executor);
        offers.acceptPrimaryOffer{ value: 1027 }(q);
        _assertUnused(p, q);
        vm.prank(payer);
        offerDelegation.registerDelegationAddress(
            address(core), signer, block.timestamp + 1 days, 2, true, 0
        );
        uint256 before = payer.balance;
        vm.prank(executor);
        Curated.ExecutionRecord memory e = offers.acceptPrimaryOffer{ value: 1027 }(q);
        _assertExecution(p, q, e);
        require(
            payer.balance == before && executor.balance == 1 ether - 1027
                && core.ownerOf(e.tokenId) == payer,
            "delegate spends its own native value"
        );
        require(
            offers.refundableBalance(p.saleId, payer) == 20
                && offers.refundableBalance(p.saleId, executor) == 0,
            "vault owns declared buyer credit"
        );
    }

    function testActualTwoOfTwoSafeBuyerSellerAndDirectHistoricalSellerRevocation() public {
        (OfficialSafe buyer, uint256[] memory buyerKeys) = _offerSafe(702);
        (OfficialSafe seller, uint256[] memory sellerKeys) = _offerSafe(703);
        (OfferPlan memory p, OfferT.Acceptance memory q) =
            _open(true, address(buyer), address(seller), 2, _emptyOffer());
        q.buyerProof = IStreamPrivateSaleAdapter.Signature(
            address(buyer),
            2,
            safeThresholdSignature(
                buyerKeys, safeMessageDigest(buyer, abi.encode(offers.offerDigest(q.offer)))
            )
        );
        q.sellerProof = IStreamPrivateSaleAdapter.Signature(
            address(seller),
            2,
            safeThresholdSignature(
                sellerKeys,
                safeMessageDigest(seller, abi.encode(offers.authorizationDigest(q.authorization)))
            )
        );
        bytes memory exact = _buyerSafePayload(
            buyer, buyerKeys, 1027, abi.encodeCall(offers.acceptPrimaryOffer, (q))
        );
        entropy.configure(7, 1, true, false);
        (bool ok,) = address(buyer).call(exact);
        require(
            !ok && buyer.nonce() == 0 && address(buyer).balance == 1 ether,
            "Safe failure restores exact signed transaction"
        );
        _assertUnused(p, q);
        entropy.configure(7, 1, false, false);
        bytes memory raw;
        (ok, raw) = address(buyer).call(exact);
        require(ok && abi.decode(raw, (bool)), "byte-identical actual Safe retry");
        Curated.ExecutionRecord memory e =
            offers.executionRecord(offers.purchaseIdFor(p.saleId, address(buyer), 1));
        _assertExecution(p, q, e);
        require(
            buyer.nonce() == 1 && seller.nonce() == 0 && buyer.getThreshold() == 2
                && seller.getThreshold() == 2,
            "actual threshold wallets"
        );
        require(
            executeSafe(
                buyer,
                buyerKeys,
                address(offers),
                0,
                abi.encodeCall(offers.claimRefund, (p.saleId, address(buyer))),
                0
            ),
            "buyer Safe claims own excess"
        );
        require(
            address(buyer).balance == 1 ether - 1007 && offers.refundLiability() == 0,
            "Safe pays only price and live fee"
        );
        (p, q) = _open(false, address(buyer), address(seller), 2, _emptyOffer());
        offers.configureCollectionSigner(1, address(seller), 2, OFFER_SIGNER_EVIDENCE, false);
        vm.warp(p.config.sale.endsAt + 1);
        IStreamPrivateSaleAdapter.Signature memory direct =
            IStreamPrivateSaleAdapter.Signature(address(seller), 2, "");
        require(
            executeSafe(
                seller,
                sellerKeys,
                address(offers),
                0,
                abi.encodeCall(offers.revokeAuthorization, (q.authorization, direct)),
                0
            ),
            "historical seller Safe direct void"
        );
        require(
            seller.nonce() == 1
                && offers.digestRevoked(offers.authorizationDigest(q.authorization)),
            "normal Safe CALL revocation"
        );
    }

    function _open(
        bool selected,
        address buyer,
        address seller,
        uint8 kind,
        StreamPrivateSaleTypes.SaleOffer memory repeated
    ) private returns (OfferPlan memory p, OfferT.Acceptance memory q) {
        p.nonce = offers.nextSaleNonce();
        p.config.sale.phaseId = keccak256(abi.encode("primary offer phase", ++planNonce));
        p.saleId = offers.saleIdFor(6, 1, p.config.sale.phaseId, p.nonce);
        p.counter = keccak256(abi.encode("primary offer counter", p.saleId));
        uint64 starts = uint64(this.offerScenarioTime() + 10);
        p.config.sale.collectionId = 1;
        p.config.sale.price = 1000;
        p.config.sale.poster = address(this);
        p.config.sale.startsAt = starts;
        p.config.sale.endsAt = starts + 1000;
        p.config.sale.expectedPrimaryPolicyHash =
            StreamNativeEnglishAuctionSupport.profilePolicy(resolver, 1);
        q.selection.tokenData = bytes("original primary offer artwork");
        q.selection.mintCommitment = keccak256(abi.encode("primary offer mint", p.saleId));
        q.selection.recipient = buyer;
        q.selection.purchaseNonce = 1;
        IStreamMintManager.MintGateConfig memory gateConfig;
        if (selected) {
            p.config.contentId = keccak256("selected original work");
            p.config.tokenDataHash = keccak256(q.selection.tokenData);
            p.leaf =
                _curatedLeaf(address(offers), p.saleId, p.config.contentId, p.config.tokenDataHash);
            p.config.sale.contentManifestRoot = p.leaf;
            StreamPreparedNativeContentTypes.Row[] memory rows =
                new StreamPreparedNativeContentTypes.Row[](1);
            rows[0] = StreamPreparedNativeContentTypes.Row(
                p.config.contentId, p.config.tokenDataHash, "urn:offer:published-work"
            );
            p.gate = new StreamNativePrimaryOfferGate(
                address(manager),
                address(offers),
                p.saleId,
                1,
                p.config.sale.phaseId,
                p.counter,
                rows
            );
            _registerOfferGate(p.gate);
            gateConfig.gate = address(p.gate);
            gateConfig.gateConfigHash = p.gate.gateConfigHash();
            q.selection.content.contentId = p.config.contentId;
            q.selection.content.tokenDataHash = p.config.tokenDataHash;
        }
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = p.counter;
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            selected
                ? IStreamMintManager.CounterKeyMode.CONTEXT
                : IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            selected ? 1 : 5,
            1,
            keccak256(abi.encode("offer cap configuration", p.saleId))
        );
        manager.configurePhase(
            1,
            p.config.sale.phaseId,
            IStreamMintManager.MintPhaseConfig(
                false, starts, p.config.sale.endsAt, 1, MANIFEST, MANIFEST
            ),
            gateConfig,
            ids,
            counters
        );
        manager.setPhaseExecutor(1, p.config.sale.phaseId, address(offers), true);
        p.config.sale.mintPolicyHash = manager.phasePolicyHash(1, p.config.sale.phaseId);
        offers.configureCollectionSigner(1, seller, kind, OFFER_SIGNER_EVIDENCE, true);
        Curated.CollectionSigner memory member = offers.collectionSigner(1, seller, kind);
        p.config.buyer = buyer;
        p.config.signer = seller;
        p.config.signerKind = kind;
        p.config.signerEvidenceHash = member.evidenceHash;
        p.config.signerRevision = member.revision;
        p.config.signerAuthority = member.authority;
        q.offer = repeated.saleAdapter == address(0)
            ? StreamPrivateSaleTypes.SaleOffer(
                block.chainid,
                address(offers),
                address(core),
                1,
                0,
                p.leaf,
                buyer,
                address(0),
                1000,
                keccak256(abi.encode("buyer offer nonce", p.saleId)),
                p.config.sale.endsAt,
                0
            )
            : repeated;
        p.config.offerDigest = offers.offerDigest(q.offer);
        require(
            offers.registerPrimaryOffer(p.config, q.selection.content.proof) == p.saleId,
            "original sale kind6 identity"
        );
        bytes32 configHash = offers.primaryOfferConfigurationHash(p.config);
        require(
            offers.saleRecord(p.saleId).configHash == configHash, "immutable offer configuration"
        );
        _bindCuratedConsent(p.saleId, configHash);
        q.authorization = _authorization(p, q.selection, buyer);
        q.sellerProof = IStreamPrivateSaleAdapter.Signature(
            seller, kind, _curatedSignature(SIGNER_KEY, offers.authorizationDigest(q.authorization))
        );
        q.buyerProof = IStreamPrivateSaleAdapter.Signature(
            buyer, buyer == payer ? 1 : 2, _curatedSignature(PAYER_KEY, offers.offerDigest(q.offer))
        );
        vm.warp(starts);
    }

    function _authorization(OfferPlan memory p, Curated.Selection memory chosen, address executor)
        private
        view
        returns (StreamPrivateSaleTypes.SaleAuthorization memory a)
    {
        address[] memory recipients = new address[](1);
        recipients[0] = address(offers);
        address[] memory beneficiaries = new address[](1);
        beneficiaries[0] = chosen.recipient;
        bytes[] memory data = new bytes[](1);
        data[0] = chosen.tokenData;
        bytes32[] memory commitments = new bytes32[](1);
        commitments[0] = chosen.mintCommitment;
        a.chainId = block.chainid;
        a.saleAdapter = address(offers);
        a.mintManager = address(manager);
        a.collectionId = 1;
        a.phaseId = p.config.sale.phaseId;
        a.saleId = p.saleId;
        a.saleKind = 6;
        a.revenueClass = CLASS;
        a.expectedPrimaryPolicyHash = p.config.sale.expectedPrimaryPolicyHash;
        a.initialRecipientsHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), recipients));
        a.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), beneficiaries)
        );
        a.tokenDataArrayHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), data));
        a.mintCommitmentsHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), commitments));
        a.payer = p.config.buyer;
        a.executor = executor;
        a.unitPrice = p.config.sale.price;
        a.quantity = 1;
        a.contentSelectionHash = p.leaf;
        a.policyHash = p.config.sale.mintPolicyHash;
        a.nonce = keccak256(abi.encode("seller acceptance nonce", p.saleId));
        a.deadline = p.config.sale.endsAt;
    }

    function _registerOfferGate(StreamNativePrimaryOfferGate gate) private {
        StreamModuleRegistration memory r = StreamModuleRegistration(
            address(gate),
            keccak256("6529STREAM_MINT_GATE_V1"),
            keccak256("6529STREAM_NATIVE_PRIMARY_OFFER_GATE_V1"),
            type(IStreamMintGate).interfaceId,
            800000,
            address(gate).codehash,
            MANIFEST,
            gate.gateConfigHash(),
            "urn:offer:complete-manifest"
        );
        (bytes32 scope, bytes32 oldState, bytes32 newState) = _registrationTransition(r);
        _context(scope, oldState, newState, 1);
        vm.prank(address(revenueAuthority));
        registry.registerModule(r);
        _clearContext();
    }

    function _offerCounterKey(OfferPlan memory p) private view returns (bytes32) {
        bytes32 context = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONTENT_CONTEXT_V1"),
                block.chainid,
                address(offers),
                p.saleId,
                p.config.contentId
            )
        );
        bytes32 subject = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1"),
                block.chainid,
                address(ledger),
                IStreamMintManager.CounterKeyMode.CONTEXT,
                context
            )
        );
        return ledger.deriveCounterValueKey(
            address(manager), 1, p.config.sale.phaseId, p.counter, subject
        );
    }

    function _offerId(StreamPrivateSaleTypes.SaleOffer memory offer)
        private
        view
        returns (bytes32)
    {
        return StreamMintTicketHash.authorizationId(
            StreamPrivateSaleHash.digest(
                block.chainid, address(offers), StreamPrivateSaleHash.offerBody(offer)
            )
        );
    }

    function _assertExecution(
        OfferPlan memory p,
        OfferT.Acceptance memory q,
        Curated.ExecutionRecord memory e
    ) private view {
        bytes32 sellerDigest = offers.authorizationDigest(q.authorization);
        require(
            e.saleId == p.saleId && e.buyer == p.config.buyer && e.recipient == p.config.buyer
                && e.purchaseNonce == 1 && e.tokenId != 0 && e.price == 1000
                && e.authorizationId == _offerId(q.offer) && e.authorizationDigest == sellerDigest
                && e.contentLeaf == p.leaf && e.tokenDataHash == keccak256(q.selection.tokenData)
                && e.mintCommitment == q.selection.mintCommitment
                && core.ownerOf(e.tokenId) == p.config.buyer
                && keccak256(core.tokenData(e.tokenId)) == keccak256(q.selection.tokenData),
            "complete original mint execution"
        );
        require(
            offers.digestConsumed(sellerDigest) && !offers.digestRevoked(sellerDigest)
                && ledger.isManagerAuthorizationUsed(address(manager), _offerId(q.offer))
                && !ledger.isManagerAuthorizationUsed(
                    address(manager), StreamMintTicketHash.authorizationId(sellerDigest)
                ) && ledger.isManagerOperationRootUsed(address(manager), e.operationRoot),
            "independent adapter and ledger replay facts"
        );
        StreamPrimarySettlementTypes.PrimarySettlementResult memory settled =
            recorder.settlementResult(e.settlementKey);
        require(
            settled.amount == 1000 && settled.operationIdentityCommitment == e.operationRoot
                && settled.executor == q.authorization.executor && settled.asset == address(0),
            "actual official native receipt"
        );
        bytes32 purchase = offers.purchaseIdFor(p.saleId, p.config.buyer, 1);
        require(
            IStreamPreparedNativeOfferSettlement(address(recorder))
                .preparedNativeOfferConsumed(address(offers), purchase)
            && !recorder.preparedNativeSaleConsumed(
                recorder.preparedNativeSaleKey(address(offers), p.saleId, p.nonce)
            ) && offers.nextPurchaseNonce(p.saleId, p.config.buyer) == 2
            && offers.saleRecord(p.saleId).status == 4,
            "offer recorder lane and terminal local sale"
        );
        require(
            core.pendingPreparedMintTokenId() == 0
                && IStreamPreparedNativeOfferMint(address(manager)).preparedNativeOfferAdmission()
                    == 0
                && IStreamPreparedNativeOfferMint(address(manager))
                .activePreparedNativeOfferContent()
                .operationRoot == 0,
            "all prepared offer contexts cleared"
        );
    }

    function _assertUnused(OfferPlan memory p, OfferT.Acceptance memory q) private view {
        require(
            !offers.digestConsumed(offers.authorizationDigest(q.authorization))
                && !ledger.isManagerAuthorizationUsed(address(manager), _offerId(q.offer))
                && offers.nextPurchaseNonce(p.saleId, p.config.buyer) == 1
                && offers.saleRecord(p.saleId).status == 1,
            "failed acceptance restores both digests and local nonce"
        );
        require(
            core.lastAllocatedTokenId() == 0 && core.collectionNextSerial(1) == 1
                && manager.nextOperationNonce() == 0
                && recorder.totalOfficialSettled(address(0)) == 0 && wallet.balance == 0
                && offers.refundLiability() == 0 && address(offers).balance == 0
                && entropy.revealFeeEscrow(1) == 0 && core.pendingPreparedMintTokenId() == 0
                && IStreamPreparedNativeOfferMint(address(manager)).preparedNativeOfferAdmission()
                    == 0,
            "no partial Core money fee or admission state"
        );
        if (p.leaf != 0) {
            require(ledger.counterValue(_offerCounterKey(p)) == 0, "content cap rolled back");
        }
    }

    function _deployDelegatedOffers() private {
        offerDelegation = new DelegationManagementContract();
        StreamNativeCuratedSaleBase.DeploymentConfig memory d = _curatedDeployment();
        d.delegation = IStreamNativeRefundDelegatedClaims.DelegationDeployment(
            address(offerDelegation),
            2,
            MANIFEST,
            IStreamGasParameterHost.GasParameterConfig(
                "DELEGATE_REGISTRY_GAS_LIMIT", 150000, 50000, 2
            )
        );
        offers = new StreamNativePrimaryOfferSale(d);
        _registerCuratedHost(address(offers));
    }

    function _moduleManifest(address module) internal view override returns (bytes32) {
        return module == address(offers) && address(offerDelegation) != address(0)
            ? keccak256(offers.refundDelegationManifest())
            : MANIFEST;
    }

    function _offerSafe(uint256 salt)
        private
        returns (OfficialSafe account, uint256[] memory keys)
    {
        keys = new uint256[](2);
        keys[0] = 0x5AFE731 + salt;
        keys[1] = 0x5AFE732 + salt;
        account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, salt);
        vm.deal(address(account), 1 ether);
    }

    function _buyerSafePayload(
        OfficialSafe account,
        uint256[] memory keys,
        uint256 value,
        bytes memory data
    ) private returns (bytes memory) {
        bytes32 digest = account.getTransactionHash(
            address(offers), value, data, 0, 0, 0, 0, address(0), address(0), account.nonce()
        );
        return abi.encodeCall(
            account.execTransaction,
            (
                address(offers),
                value,
                data,
                uint8(0),
                uint256(0),
                uint256(0),
                uint256(0),
                address(0),
                payable(address(0)),
                safeThresholdSignature(keys, digest)
            )
        );
    }

    function _emptyOffer() private pure returns (StreamPrivateSaleTypes.SaleOffer memory offer) { }

    /// @dev An external read prevents optimizer timestamp reuse across multiple vm.warp scenarios.
    function offerScenarioTime() external view returns (uint256) {
        return block.timestamp;
    }
}
