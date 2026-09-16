// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamERC20PrimaryOfferAuthorization as OfferAuth
} from "../../../smart-contracts/domains/mint/StreamERC20PrimaryOfferAuthorization.sol";
import {
    StreamPrivateSaleTypes as Sale
} from "../../../smart-contracts/interfaces/stream/mint/StreamPrivateSaleTypes.sol";
import {
    IStreamPrivateSaleAdapter as Private
} from "../../../smart-contracts/interfaces/stream/mint/IStreamPrivateSaleAdapter.sol";
import {
    IStreamMintManager as Manager
} from "../../../smart-contracts/interfaces/stream/mint/IStreamMintManager.sol";

interface ERC20PrimaryOfferVm {
    function warp(uint256) external;
    function addr(uint256) external returns (address);
    function sign(uint256, bytes32) external returns (uint8, bytes32, bytes32);
    function expectRevert() external;
    function expectRevert(bytes calldata) external;
    function expectCall(address, bytes calldata, uint64) external;
}

contract ERC20PrimaryOfferAuthorizationHarness {
    function validate(
        OfferAuth.Context calldata context,
        OfferAuth.Terms calldata terms,
        Sale.SaleAuthorization calldata authorization,
        Private.Signature calldata sellerProof,
        Sale.SaleOffer calldata offer,
        Private.Signature calldata buyerProof,
        Manager.MintBatch calldata batch
    ) external view returns (bytes32, bytes32, bytes32) {
        return OfferAuth.validate(
            context, terms, authorization, sellerProof, offer, buyerProof, batch
        );
    }
}

/// @dev Only the ERC-1271 boundary is substituted; the helper must call the exact claimed account.
contract ERC20PrimaryOffer1271 {
    bytes32 private acceptedDigest;
    bytes32 private acceptedSignature;

    function allow(bytes32 digest, bytes calldata signature) external {
        acceptedDigest = digest;
        acceptedSignature = keccak256(signature);
    }

    function isValidSignature(bytes32 digest, bytes calldata signature)
        external
        view
        returns (bytes4)
    {
        return digest == acceptedDigest && keccak256(signature) == acceptedSignature
            ? bytes4(0x1626ba7e)
            : bytes4(0xffffffff);
    }
}

/// @dev Any attempt to treat proof validation as allowance, permit or transfer authority fails.
contract ERC20PrimaryOfferUncallableAsset {
    fallback() external {
        revert("proof helper must not call payment asset");
    }
}

/// @notice Proof-only tests; durable consumption, historical revocation and delegation belong to hosts.
contract StreamERC20PrimaryOfferAuthorizationTest {
    ERC20PrimaryOfferVm private constant vm =
        ERC20PrimaryOfferVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 private constant SELLER_KEY = 0x5151;
    uint256 private constant BUYER_KEY = 0xB001;
    uint256 private constant DELEGATE_KEY = 0xD311;
    ERC20PrimaryOfferAuthorizationHarness private host;

    struct Request {
        OfferAuth.Context context;
        OfferAuth.Terms terms;
        Sale.SaleAuthorization authorization;
        Private.Signature sellerProof;
        Sale.SaleOffer offer;
        Private.Signature buyerProof;
        Manager.MintBatch batch;
    }

    function setUp() public {
        vm.warp(1000);
        host = new ERC20PrimaryOfferAuthorizationHarness();
    }

    function testOriginalCanonicalEOASignaturesBindSelectedWorkAndBothDigests() public {
        Request memory q = _request();
        (bytes32 seller, bytes32 offer, bytes32 id) = _validate(q);
        require(seller == _sellerDigest(q.authorization), "literal seller digest");
        require(offer == _offerDigest(q.offer), "literal original offer digest");
        require(id == _ticket(offer) && id == q.batch.authorizationId, "Ledger owns wrapped offer");
        require(id != _ticket(seller) && id != offer, "distinct durable replay locus");
    }

    function testCollectionLevelOfferAllowsZeroSelectedLeafAndTokenIdRemainsZero() public {
        Request memory q = _request();
        q.terms.selectedLeaf = 0;
        q.authorization.contentSelectionHash = 0;
        q.offer.contentSelectionHash = 0;
        q.batch.contextHash = keccak256("host-validated ordinary mint execution context");
        _signBoth(q);
        (, bytes32 digest, bytes32 id) = _validate(q);
        require(q.offer.tokenId == 0 && id == _ticket(digest), "unselected primary offer");
        q.batch.contextHash = 0;
        vm.expectRevert(abi.encodeWithSelector(OfferAuth.InvalidPrimaryOfferBatch.selector));
        _validate(q);
    }

    function testAuthenticatedExecutorIsDistinctFromPaymentCallbackCaller() public {
        Request memory q = _request();
        require(q.context.executor != address(this), "callback caller differs from executor");
        _validate(q);
        q.authorization.executor = address(this);
        q.sellerProof.signature = _sign(SELLER_KEY, _sellerDigest(q.authorization));
        vm.expectRevert(abi.encodeWithSelector(OfferAuth.InvalidPrimaryOfferAuthorization.selector));
        _validate(q);
        q.context.executor = address(0);
        vm.expectRevert(abi.encodeWithSelector(OfferAuth.InvalidPrimaryOfferTerms.selector));
        _validate(q);
    }

    function testNativeAssetCannotReplaceERC20TermsEvenWithBothValidSignatures() public {
        Request memory q = _request();
        q.terms.asset = address(0);
        q.authorization.asset = address(0);
        q.offer.asset = address(0);
        _signBoth(q);
        vm.expectRevert(abi.encodeWithSelector(OfferAuth.InvalidPrimaryOfferTerms.selector));
        _validate(q);

        q = _request();
        q.authorization.asset = address(0);
        q.sellerProof.signature = _sign(SELLER_KEY, _sellerDigest(q.authorization));
        vm.expectRevert(abi.encodeWithSelector(OfferAuth.InvalidPrimaryOfferAuthorization.selector));
        _validate(q);
        q = _request();
        q.offer.asset = address(0);
        _signBoth(q);
        vm.expectRevert(abi.encodeWithSelector(OfferAuth.InvalidPrimaryOffer.selector));
        _validate(q);
    }

    function testProofValidationNeverCallsAssetOrAuthorizesItsAllowance() public {
        Request memory q = _request();
        ERC20PrimaryOfferUncallableAsset asset = new ERC20PrimaryOfferUncallableAsset();
        q.terms.asset = address(asset);
        q.authorization.asset = address(asset);
        q.offer.asset = address(asset);
        _signBoth(q);
        (, bytes32 digest, bytes32 id) = _validate(q);
        require(id == _ticket(digest), "proof produces only offer replay key");
        // The actual carrier and contract20 must separately validate payment and asset policy.
    }

    function testDirectBuyerRecipientCannotBecomeAdapterCustodyEvenWhenResigned() public {
        Request memory q = _request();
        q.batch.initialRecipients[0] = address(host);
        _batchHashes(q);
        _signBoth(q);
        vm.expectRevert(abi.encodeWithSelector(OfferAuth.InvalidPrimaryOfferBatch.selector));
        _validate(q);
        q = _request();
        q.batch.beneficiaries[0] = q.terms.seller;
        _batchHashes(q);
        _signBoth(q);
        vm.expectRevert(abi.encodeWithSelector(OfferAuth.InvalidPrimaryOfferBatch.selector));
        _validate(q);
    }

    function testRevocationSignaturesCannotAuthorizeAnAcceptance() public {
        Request memory q = _request();
        bytes32 offerRevocation = _digest(
            address(host),
            keccak256(
                abi.encode(
                    keccak256(
                        "SaleOfferRevocation(uint256 chainId,address saleAdapter,bytes32 offerDigest)"
                    ),
                    block.chainid,
                    address(host),
                    _offerDigest(q.offer)
                )
            )
        );
        q.buyerProof.signature = _sign(BUYER_KEY, offerRevocation);
        vm.expectRevert(
            abi.encodeWithSelector(OfferAuth.PrimaryOfferSignatureInvalid.selector, q.terms.buyer)
        );
        _validate(q);
        _signBoth(q);
        bytes32 authorizationRevocation = _digest(
            address(host),
            keccak256(
                abi.encode(
                    keccak256(
                        "SaleAuthorizationRevocation(uint256 chainId,address saleAdapter,address authorizer,bytes32 authorizationDigest)"
                    ),
                    block.chainid,
                    address(host),
                    q.terms.seller,
                    _sellerDigest(q.authorization)
                )
            )
        );
        q.sellerProof.signature = _sign(SELLER_KEY, authorizationRevocation);
        vm.expectRevert(
            abi.encodeWithSelector(OfferAuth.PrimaryOfferSignatureInvalid.selector, q.terms.seller)
        );
        _validate(q);
    }

    function testPaymentIntentSignatureCannotReplaceOriginalBuyerOfferSignature() public {
        Request memory q = _request();
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamPaymentIntentVerifier"),
                keccak256("1"),
                block.chainid,
                address(0x20)
            )
        );
        bytes32 body = keccak256(
            abi.encode(
                keccak256(
                    "StreamPaymentIntent(address payer,address asset,uint256 maxAmount,bytes32 saleRef,bytes32 expectedPrimaryPolicyHash,bytes32 nonce,uint64 deadline)"
                ),
                q.terms.buyer,
                q.terms.asset,
                q.terms.price,
                q.terms.saleId,
                q.terms.expectedPrimaryPolicyHash,
                q.offer.nonce,
                q.offer.deadline
            )
        );
        q.buyerProof.signature =
            _sign(BUYER_KEY, keccak256(abi.encodePacked(hex"1901", domain, body)));
        vm.expectRevert(
            abi.encodeWithSelector(OfferAuth.PrimaryOfferSignatureInvalid.selector, q.terms.buyer)
        );
        _validate(q);
    }

    function testFreshSellerNonceCannotChangeOfferLedgerKey() public {
        Request memory q = _request();
        (bytes32 oldSeller, bytes32 oldOffer, bytes32 oldId) = _validate(q);
        q.authorization.nonce = keccak256("fresh seller nonce");
        q.sellerProof.signature = _sign(SELLER_KEY, _sellerDigest(q.authorization));
        (bytes32 seller, bytes32 offer, bytes32 id) = _validate(q);
        require(
            seller != oldSeller && offer == oldOffer && id == oldId,
            "offer replay survives countersignature renewal"
        );
        q.offer.nonce = keccak256("second buyer offer");
        _signBoth(q);
        (bytes32 sameSeller, bytes32 newOffer, bytes32 newId) = _validate(q);
        require(
            sameSeller == seller && newOffer != offer && newId != id,
            "seller replay is independent of offer"
        );
    }

    function testChangedOfferCannotBypassImmutableExpectedDigest() public {
        Request memory q = _request();
        q.offer.nonce = keccak256("fresh offer with identical economics");
        q.buyerProof.signature = _sign(BUYER_KEY, _offerDigest(q.offer));
        q.batch.authorizationId = _ticket(_offerDigest(q.offer));
        vm.expectRevert(abi.encodeWithSelector(OfferAuth.InvalidPrimaryOffer.selector));
        _validate(q);
    }

    function testRawSellerAndCombinedDigestIdsCannotReplaceOfferLedgerId() public {
        Request memory q = _request();
        bytes32 offer = _offerDigest(q.offer);
        bytes32 seller = _sellerDigest(q.authorization);
        bytes32[3] memory incorrect =
            [offer, _ticket(seller), _ticket(keccak256(abi.encode(offer, seller)))];
        for (uint256 i; i < incorrect.length; ++i) {
            q.batch.authorizationId = incorrect[i];
            vm.expectRevert(
                abi.encodeWithSelector(
                    OfferAuth.PrimaryOfferLedgerIdMismatch.selector, _ticket(offer), incorrect[i]
                )
            );
            _validate(q);
        }
    }

    function testEveryOfferFieldIsValidatedEvenWhenCorrectlyResignedAndPinned() public {
        for (uint256 field; field < 12; ++field) {
            Request memory q = _request();
            if (field == 0) q.offer.chainId += 1;
            else if (field == 1) q.offer.saleAdapter = address(0xBAD);
            else if (field == 2) q.offer.core = address(0xBAD);
            else if (field == 3) q.offer.collectionId += 1;
            else if (field == 4) q.offer.tokenId = 1;
            else if (field == 5) q.offer.contentSelectionHash = 0;
            else if (field == 6) q.offer.buyer = address(0xBAD);
            else if (field == 7) q.offer.asset = address(0xBAD);
            else if (field == 8) q.offer.price += 1;
            else if (field == 9) q.offer.nonce = 0;
            else if (field == 10) q.offer.deadline = 999;
            else q.offer.finalizeBy = 2000;
            _signBoth(q);
            vm.expectRevert(abi.encodeWithSelector(OfferAuth.InvalidPrimaryOffer.selector));
            _validate(q);
        }
    }

    function testEverySellerAuthorizationFieldIsValidatedEvenWithValidSellerSignature() public {
        for (uint256 field; field < 24; ++field) {
            Request memory q = _request();
            if (field == 0) q.authorization.chainId += 1;
            else if (field == 1) q.authorization.saleAdapter = address(0xBAD);
            else if (field == 2) q.authorization.mintManager = address(0xBAD);
            else if (field == 3) q.authorization.collectionId += 1;
            else if (field == 4) q.authorization.phaseId = 0;
            else if (field == 5) q.authorization.saleId = 0;
            else if (field == 6) q.authorization.saleKind = 5;
            else if (field == 7) q.authorization.revenueClass = 0;
            else if (field == 8) q.authorization.expectedPrimaryPolicyHash = 0;
            else if (field == 9) q.authorization.primaryPolicyMode = 1;
            else if (field == 10) q.authorization.initialRecipientsHash = 0;
            else if (field == 11) q.authorization.beneficiariesHash = 0;
            else if (field == 12) q.authorization.tokenDataArrayHash = 0;
            else if (field == 13) q.authorization.mintCommitmentsHash = 0;
            else if (field == 14) q.authorization.payer = address(0xBAD);
            else if (field == 15) q.authorization.executor = address(0xBAD);
            else if (field == 16) q.authorization.asset = address(0xBAD);
            else if (field == 17) q.authorization.unitPrice += 1;
            else if (field == 18) q.authorization.quantity = 2;
            else if (field == 19) q.authorization.contentSelectionHash = 0;
            else if (field == 20) q.authorization.policyHash = 0;
            else if (field == 21) q.authorization.nonce = 0;
            else if (field == 22) q.authorization.deadline = 999;
            else q.authorization.finalizeBy = 2000;
            q.sellerProof.signature = _sign(SELLER_KEY, _sellerDigest(q.authorization));
            vm.expectRevert();
            _validate(q);
        }
    }

    function testBatchAuthorityRecipientsBytesAndCommitmentRemainExact() public {
        for (uint256 field; field < 12; ++field) {
            Request memory q = _request();
            if (field == 0) q.batch.collectionId += 1;
            else if (field == 1) q.batch.phaseId = 0;
            else if (field == 2) q.batch.authorizer = q.terms.seller;
            else if (field == 3) q.batch.payer = q.terms.seller;
            else if (field == 4) q.batch.expectedPolicyHash = 0;
            else if (field == 5) q.batch.contextHash = 0;
            else if (field == 6) q.batch.initialRecipients[0] = address(host);
            else if (field == 7) q.batch.beneficiaries[0] = q.terms.seller;
            else if (field == 8) q.batch.tokenData[0] = "substituted artwork";
            else if (field == 9) q.batch.mintCommitments[0] = keccak256("substituted commitment");
            else if (field == 10) q.batch.beneficiaries = new address[](0);
            else q.batch.mintCommitments[0] = 0;
            vm.expectRevert(abi.encodeWithSelector(OfferAuth.InvalidPrimaryOfferBatch.selector));
            _validate(q);
        }
    }

    function testEffectiveDeadlineIsMinimumOfOfferSellerAndSale() public {
        Request memory q = _request();
        q.offer.deadline = 1500;
        q.authorization.deadline = 1700;
        _signBoth(q);
        vm.warp(1500);
        _validate(q);
        vm.warp(1501);
        vm.expectRevert(abi.encodeWithSelector(OfferAuth.InvalidPrimaryOffer.selector));
        _validate(q);
        q.offer.deadline = 2100;
        q.authorization.deadline = 1500;
        _signBoth(q);
        vm.expectRevert(abi.encodeWithSelector(OfferAuth.InvalidPrimaryOfferAuthorization.selector));
        _validate(q);
        q.authorization.deadline = 2000;
        _signBoth(q);
        vm.warp(2000);
        _validate(q);
        vm.warp(2001);
        vm.expectRevert(abi.encodeWithSelector(OfferAuth.InvalidPrimaryOfferAuthorization.selector));
        _validate(q);
        vm.warp(999);
        vm.expectRevert(abi.encodeWithSelector(OfferAuth.InvalidPrimaryOfferAuthorization.selector));
        _validate(q);
    }

    function testSellerAndBuyerERC1271ValidateExactlyClaimedAccounts() public {
        Request memory q = _request();
        ERC20PrimaryOffer1271 seller = new ERC20PrimaryOffer1271();
        ERC20PrimaryOffer1271 buyer = new ERC20PrimaryOffer1271();
        q.terms.seller = address(seller);
        q.terms.sellerKind = 2;
        q.terms.buyer = address(buyer);
        q.batch.authorizer = address(buyer);
        q.batch.payer = address(buyer);
        q.batch.initialRecipients[0] = address(buyer);
        q.batch.beneficiaries[0] = address(buyer);
        q.authorization.payer = address(buyer);
        q.offer.buyer = address(buyer);
        _batchHashes(q);
        bytes32 sellerDigest = _sellerDigest(q.authorization);
        bytes32 offerDigest = _offerDigest(q.offer);
        q.terms.expectedOfferDigest = offerDigest;
        q.batch.authorizationId = _ticket(offerDigest);
        q.sellerProof = Private.Signature(address(seller), 2, hex"1234");
        q.buyerProof = Private.Signature(address(buyer), 2, hex"5678");
        seller.allow(sellerDigest, q.sellerProof.signature);
        buyer.allow(offerDigest, q.buyerProof.signature);
        vm.expectCall(
            address(seller),
            abi.encodeCall(seller.isValidSignature, (sellerDigest, q.sellerProof.signature)),
            1
        );
        vm.expectCall(
            address(buyer),
            abi.encodeCall(buyer.isValidSignature, (offerDigest, q.buyerProof.signature)),
            1
        );
        _validate(q);
    }

    function testSellerMembershipCheckedBeforeAnyOutsiderERC1271Magic() public {
        Request memory q = _request();
        ERC20PrimaryOffer1271 outsider = new ERC20PrimaryOffer1271();
        outsider.allow(_sellerDigest(q.authorization), hex"1234");
        q.sellerProof = Private.Signature(address(outsider), 2, hex"1234");
        vm.expectRevert(
            abi.encodeWithSelector(
                OfferAuth.PrimaryOfferSignerNotAuthorized.selector, address(outsider), uint8(2)
            )
        );
        _validate(q);
    }

    function testDelegateProofPreservesBuyerEconomicsAndOnlyChecksExplicitSignerHere() public {
        Request memory q = _request();
        address buyer = q.terms.buyer;
        q.buyerProof.authorizer = vm.addr(DELEGATE_KEY);
        q.batch.authorizer = q.buyerProof.authorizer;
        q.buyerProof.signature = _sign(DELEGATE_KEY, _offerDigest(q.offer));
        (, bytes32 digest, bytes32 id) = _validate(q);
        require(
            q.offer.buyer == buyer && q.batch.payer == buyer && q.batch.beneficiaries[0] == buyer,
            "principal remains economic owner"
        );
        require(id == _ticket(digest), "delegate does not change offer key");
        // This proof helper intentionally cannot grant delegation; its host must validate the live row.
    }

    function testInvalidSignaturesExplicitKindsAndDomainCannotBeSubstituted() public {
        Request memory q = _request();
        q.sellerProof.signature = _sign(BUYER_KEY, _sellerDigest(q.authorization));
        vm.expectRevert(
            abi.encodeWithSelector(OfferAuth.PrimaryOfferSignatureInvalid.selector, q.terms.seller)
        );
        _validate(q);
        _signBoth(q);
        q.buyerProof.signature = _sign(SELLER_KEY, _offerDigest(q.offer));
        vm.expectRevert(
            abi.encodeWithSelector(OfferAuth.PrimaryOfferSignatureInvalid.selector, q.terms.buyer)
        );
        _validate(q);
        q.buyerProof.kind = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                OfferAuth.PrimaryOfferSignerNotAuthorized.selector, q.terms.buyer, uint8(0)
            )
        );
        _validate(q);
        q.buyerProof.kind = 1;
        q.buyerProof.signature = _sign(
            BUYER_KEY, _digest(address(0xBAD), keccak256(abi.encode(_offerTypehash(), q.offer)))
        );
        vm.expectRevert(
            abi.encodeWithSelector(OfferAuth.PrimaryOfferSignatureInvalid.selector, q.terms.buyer)
        );
        _validate(q);
    }

    function _request() private returns (Request memory q) {
        q.context = OfferAuth.Context(address(0xC0DE), address(0x6000), 400000, address(0xE0EC));
        q.terms = OfferAuth.Terms(
            keccak256("sale"),
            1,
            keccak256("phase"),
            vm.addr(BUYER_KEY),
            address(0x20C0),
            1000,
            1000,
            2000,
            keccak256("selected leaf"),
            keccak256("mint policy"),
            0,
            keccak256("primary policy"),
            vm.addr(SELLER_KEY),
            1,
            bytes32(0)
        );
        q.batch.collectionId = 1;
        q.batch.phaseId = q.terms.phaseId;
        q.batch.payer = q.terms.buyer;
        q.batch.authorizer = q.terms.buyer;
        q.batch.initialRecipients = new address[](1);
        q.batch.initialRecipients[0] = q.terms.buyer;
        q.batch.beneficiaries = new address[](1);
        q.batch.beneficiaries[0] = q.terms.buyer;
        q.batch.tokenData = new bytes[](1);
        q.batch.tokenData[0] = "selected artwork";
        q.batch.mintCommitments = new bytes32[](1);
        q.batch.mintCommitments[0] = keccak256("mint commitment");
        q.batch.expectedPolicyHash = q.terms.mintPolicyHash;
        q.batch.contextHash = keccak256("host-validated ordinary mint context");
        q.authorization.chainId = block.chainid;
        q.authorization.saleAdapter = address(host);
        q.authorization.mintManager = q.context.manager;
        q.authorization.collectionId = 1;
        q.authorization.phaseId = q.terms.phaseId;
        q.authorization.saleId = q.terms.saleId;
        q.authorization.saleKind = 6;
        q.authorization.revenueClass = keccak256("PRIMARY_SALE");
        q.authorization.expectedPrimaryPolicyHash = q.terms.expectedPrimaryPolicyHash;
        q.authorization.payer = q.terms.buyer;
        q.authorization.executor = q.context.executor;
        q.authorization.asset = q.terms.asset;
        q.authorization.unitPrice = 1000;
        q.authorization.quantity = 1;
        q.authorization.contentSelectionHash = q.terms.selectedLeaf;
        q.authorization.policyHash = q.terms.mintPolicyHash;
        q.authorization.nonce = keccak256("seller nonce");
        q.authorization.deadline = 2000;
        _batchHashes(q);
        q.offer = Sale.SaleOffer(
            block.chainid,
            address(host),
            q.context.core,
            1,
            0,
            q.terms.selectedLeaf,
            q.terms.buyer,
            q.terms.asset,
            1000,
            keccak256("buyer nonce"),
            2000,
            0
        );
        q.sellerProof = Private.Signature(q.terms.seller, 1, "");
        q.buyerProof = Private.Signature(q.terms.buyer, 1, "");
        _signBoth(q);
    }

    function _batchHashes(Request memory q) private pure {
        q.authorization.initialRecipientsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), q.batch.initialRecipients)
        );
        q.authorization.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), q.batch.beneficiaries)
        );
        q.authorization.tokenDataArrayHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), q.batch.tokenData)
        );
        q.authorization.mintCommitmentsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), q.batch.mintCommitments)
        );
    }

    function _signBoth(Request memory q) private {
        q.terms.expectedOfferDigest = _offerDigest(q.offer);
        q.batch.authorizationId = _ticket(q.terms.expectedOfferDigest);
        q.sellerProof.signature = _sign(SELLER_KEY, _sellerDigest(q.authorization));
        q.buyerProof.signature = _sign(BUYER_KEY, q.terms.expectedOfferDigest);
    }

    function _sign(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _validate(Request memory q) private view returns (bytes32, bytes32, bytes32) {
        return host.validate(
            q.context, q.terms, q.authorization, q.sellerProof, q.offer, q.buyerProof, q.batch
        );
    }

    function _sellerDigest(Sale.SaleAuthorization memory a) private view returns (bytes32) {
        bytes32 typehash = keccak256(
            "SaleAuthorization(uint256 chainId,address saleAdapter,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 saleId,uint8 saleKind,bytes32 revenueClass,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,address payer,address executor,address asset,uint256 unitPrice,uint256 quantity,bytes32 contentSelectionHash,bytes32 policyHash,bytes32 nonce,uint64 deadline,uint64 finalizeBy)"
        );
        return _digest(address(host), keccak256(abi.encode(typehash, a)));
    }

    function _offerDigest(Sale.SaleOffer memory offer) private view returns (bytes32) {
        return _digest(address(host), keccak256(abi.encode(_offerTypehash(), offer)));
    }

    function _offerTypehash() private pure returns (bytes32) {
        return keccak256(
            "SaleOffer(uint256 chainId,address saleAdapter,address core,uint256 collectionId,uint256 tokenId,bytes32 contentSelectionHash,address buyer,address asset,uint256 price,bytes32 nonce,uint64 deadline,uint64 finalizeBy)"
        );
    }

    function _digest(address adapter, bytes32 body) private view returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream Sales"),
                keccak256("1"),
                block.chainid,
                adapter
            )
        );
        return keccak256(abi.encodePacked(hex"1901", domain, body));
    }

    function _ticket(bytes32 digest) private pure returns (bytes32) {
        return keccak256(abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), digest));
    }
}
