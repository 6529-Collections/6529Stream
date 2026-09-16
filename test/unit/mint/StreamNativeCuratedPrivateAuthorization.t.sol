// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamNativeCuratedPrivateAuthorization as Authorization
} from "../../../smart-contracts/domains/mint/StreamNativeCuratedPrivateAuthorization.sol";
import "../../../smart-contracts/interfaces/stream/mint/IStreamMintManager.sol";
import "../../../smart-contracts/interfaces/stream/mint/IStreamPrivateSaleAdapter.sol";

interface CuratedPrivateAuthorizationVm {
    function addr(uint256 key) external returns (address);
    function sign(uint256 key, bytes32 digest) external returns (uint8, bytes32, bytes32);
    function warp(uint256 timestamp) external;
    function prank(address sender) external;
    function expectRevert(bytes4 selector) external;
    function expectRevert(bytes calldata reason) external;
    function expectPartialRevert(bytes4 selector) external;
}

/// @dev Real linked validator only. No Manager, gate, replay, payment or mint result is simulated.
contract CuratedPrivateAuthorizationHost {
    function validate(
        Authorization.Context memory context,
        Authorization.Terms memory terms,
        StreamPrivateSaleTypes.SaleAuthorization memory authorization,
        IStreamPrivateSaleAdapter.Signature memory proof,
        IStreamMintManager.MintBatch memory batch
    ) external view returns (bytes32, bytes32) {
        return Authorization.validate(context, terms, authorization, proof, batch);
    }
}

/// @dev Positive ERC1271 acceptance verifies an actual owner signature over the supplied digest.
contract CuratedPrivateSignatureWallet {
    address private immutable _owner;
    uint256 private _mode;

    constructor(address owner) {
        _owner = owner;
    }

    function setMode(uint256 mode) external {
        _mode = mode;
    }

    function isValidSignature(bytes32 digest, bytes calldata signature)
        external
        view
        returns (bytes4)
    {
        if (_mode == 1) revert("wallet unavailable");
        if (_mode != 0) {
            uint256 mode = _mode;
            assembly ("memory-safe") {
                mstore(0, shl(224, 0x1626ba7e))
                switch mode
                case 2 { return(0, 4) }
                case 3 { return(0, 64) }
                case 4 {
                    mstore(0, or(mload(0), 1))
                    return(0, 32)
                }
                case 6 { invalid() }
                default {
                    mstore(0, 0)
                    return(0, 32)
                }
            }
        }
        if (signature.length != 65) return 0xffffffff;
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly ("memory-safe") {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }
        return ecrecover(digest, v, r, s) == _owner ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
    }
}

contract StreamNativeCuratedPrivateAuthorizationTest {
    CuratedPrivateAuthorizationVm private constant vm =
        CuratedPrivateAuthorizationVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 private constant SELLER_KEY = 0x515111;
    address private constant BUYER = address(0xB0B);
    address private constant MANAGER = address(0xA11CE);
    CuratedPrivateAuthorizationHost private host;
    address private seller;

    function setUp() public {
        vm.warp(1000);
        seller = vm.addr(SELLER_KEY);
        host = new CuratedPrivateAuthorizationHost();
    }

    function testEOAAndCompactSignaturesReturnOriginalDigestAndLedgerKey() public {
        Authorization.Terms memory terms = _terms();
        IStreamMintManager.MintBatch memory batch = _batch(terms);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(terms, batch);
        bytes32 digest = _digest(a);
        batch.authorizationId = _id(digest);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SELLER_KEY, digest);
        IStreamPrivateSaleAdapter.Signature memory proof =
            IStreamPrivateSaleAdapter.Signature(seller, 1, abi.encodePacked(r, s, v));
        (bytes32 actual, bytes32 id) = _validate(terms, a, proof, batch, BUYER);
        require(actual == digest && id == _id(digest), "canonical full digest and ticket key");
        proof.signature = abi.encodePacked(r, bytes32(uint256(s) | (uint256(v - 27) << 255)));
        (actual, id) = _validate(terms, a, proof, batch, BUYER);
        require(actual == digest && id == _id(digest), "compact signature has identical identity");
        // This is a view validator; duplicate validation must not impersonate Ledger consumption.
        (actual, id) = _validate(terms, a, proof, batch, BUYER);
        require(actual == digest && id == batch.authorizationId, "replay remains a host/ledger job");
    }

    function testActualERC1271SignatureAndExplicitSellerMembership() public {
        CuratedPrivateSignatureWallet wallet = new CuratedPrivateSignatureWallet(seller);
        Authorization.Terms memory terms = _terms();
        terms.seller = address(wallet);
        terms.sellerKind = 2;
        IStreamMintManager.MintBatch memory batch = _batch(terms);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(terms, batch);
        IStreamPrivateSaleAdapter.Signature memory proof = _proof(terms, a, batch);
        (bytes32 actual, bytes32 id) = _validate(terms, a, proof, batch, BUYER);
        require(actual == _digest(a) && id == batch.authorizationId, "actual owner signature");
        proof.signature = _sign(0xBAD, _digest(a));
        _reject(terms, a, proof, batch, Authorization.CuratedPrivateSignatureInvalid.selector);
        proof = _proof(terms, a, batch);
        proof.kind = 1;
        _reject(terms, a, proof, batch, Authorization.CuratedPrivateSignerNotAuthorized.selector);
        proof.kind = 2;
        proof.authorizer = address(new CuratedPrivateSignatureWallet(seller));
        _reject(terms, a, proof, batch, Authorization.CuratedPrivateSignerNotAuthorized.selector);
    }

    function testERC1271RejectsRevertShortLongDirtyAndWrongReturns() public {
        CuratedPrivateSignatureWallet wallet = new CuratedPrivateSignatureWallet(seller);
        Authorization.Terms memory terms = _terms();
        terms.seller = address(wallet);
        terms.sellerKind = 2;
        IStreamMintManager.MintBatch memory batch = _batch(terms);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(terms, batch);
        IStreamPrivateSaleAdapter.Signature memory proof = _proof(terms, a, batch);
        for (uint256 mode = 1; mode <= 6; ++mode) {
            wallet.setMode(mode);
            _reject(terms, a, proof, batch, Authorization.CuratedPrivateSignatureInvalid.selector);
        }
    }

    function testERC1271RequiresParentGasBeforeMakingItsBoundedCall() public {
        CuratedPrivateSignatureWallet wallet = new CuratedPrivateSignatureWallet(seller);
        Authorization.Terms memory terms = _terms();
        terms.seller = address(wallet);
        terms.sellerKind = 2;
        IStreamMintManager.MintBatch memory batch = _batch(terms);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(terms, batch);
        IStreamPrivateSaleAdapter.Signature memory proof = _proof(terms, a, batch);
        Authorization.Context memory context = _context();
        context.signatureGas = type(uint64).max;
        vm.expectPartialRevert(IStreamPrivateSaleAdapter.PrivateSaleInsufficientGas.selector);
        vm.prank(BUYER);
        host.validate(context, terms, a, proof, batch);
    }

    function testPositivePriceKeepsAllUint256Bits() public {
        Authorization.Terms memory terms = _terms();
        terms.price = type(uint256).max;
        IStreamMintManager.MintBatch memory batch = _batch(terms);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(terms, batch);
        IStreamPrivateSaleAdapter.Signature memory proof = _proof(terms, a, batch);
        (bytes32 digest,) = _validate(terms, a, proof, batch, BUYER);
        require(digest == _digest(a), "full width canonical native price");
        a.unitPrice = uint256(type(uint128).max);
        proof = _proof(terms, a, batch);
        _reject(terms, a, proof, batch, Authorization.InvalidCuratedPrivateAuthorization.selector);
    }

    function testEOARejectsMalformedHighSInvalidVWrongSignerAndChangedPresentationKind() public {
        Authorization.Terms memory terms = _terms();
        IStreamMintManager.MintBatch memory batch = _batch(terms);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(terms, batch);
        IStreamPrivateSaleAdapter.Signature memory proof = _proof(terms, a, batch);
        proof.signature = hex"1234";
        _reject(terms, a, proof, batch, Authorization.CuratedPrivateSignatureInvalid.selector);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SELLER_KEY, _digest(a));
        proof.signature = abi.encodePacked(
            r,
            bytes32(
                0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141 - uint256(s)
            ),
            uint8(v == 27 ? 28 : 27)
        );
        _reject(terms, a, proof, batch, Authorization.CuratedPrivateSignatureInvalid.selector);
        proof.signature = abi.encodePacked(r, s, uint8(0));
        _reject(terms, a, proof, batch, Authorization.CuratedPrivateSignatureInvalid.selector);
        proof.signature = _sign(0xBAD, _digest(a));
        _reject(terms, a, proof, batch, Authorization.CuratedPrivateSignatureInvalid.selector);
        proof = _proof(terms, a, batch);
        proof.authorizer = vm.addr(0xBAD);
        _reject(terms, a, proof, batch, Authorization.CuratedPrivateSignerNotAuthorized.selector);
        proof.authorizer = seller;
        proof.kind = 2;
        _reject(terms, a, proof, batch, Authorization.CuratedPrivateSignerNotAuthorized.selector);
    }

    function testEveryCanonicalAuthorizationFieldIsBoundEvenWithFreshSellerSignature() public {
        for (uint256 field; field < 24; ++field) {
            Authorization.Terms memory terms = _terms();
            IStreamMintManager.MintBatch memory batch = _batch(terms);
            StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(terms, batch);
            // The canonical struct consists of 24 words in the permanent normative field order.
            assembly ("memory-safe") {
                let position := add(a, mul(field, 32))
                mstore(position, add(mload(position), 1))
            }
            if (field == 21) a.nonce = 0;
            if (field == 22) a.deadline = terms.deadline + 1;
            IStreamPrivateSaleAdapter.Signature memory proof = _proof(terms, a, batch);
            _reject(
                terms,
                a,
                proof,
                batch,
                field >= 10 && field <= 13
                    ? Authorization.InvalidCuratedPrivateBatch.selector
                    : Authorization.InvalidCuratedPrivateAuthorization.selector
            );
        }
    }

    function testActualBatchFieldsAndArrayShapesCannotDifferFromSignedRequest() public {
        for (uint256 field; field < 15; ++field) {
            Authorization.Terms memory terms = _terms();
            IStreamMintManager.MintBatch memory batch = _batch(terms);
            StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(terms, batch);
            IStreamPrivateSaleAdapter.Signature memory proof = _proof(terms, a, batch);
            if (field == 0) ++batch.collectionId;
            else if (field == 1) batch.phaseId = keccak256("other phase");
            else if (field == 2) batch.payer = address(0xBAD);
            else if (field == 3) batch.expectedPolicyHash = keccak256("other policy");
            else if (field == 4) batch.contextHash = 0;
            else if (field == 5) batch.initialRecipients[0] = BUYER;
            else if (field == 6) batch.beneficiaries[0] = address(0xBAD);
            else if (field == 7) batch.tokenData[0] = bytes("other selected bytes");
            else if (field == 8) batch.mintCommitments[0] = keccak256("other commitment");
            else if (field == 9) batch.initialRecipients = new address[](0);
            else if (field == 10) batch.beneficiaries = new address[](2);
            else if (field == 11) batch.tokenData = new bytes[](0);
            else if (field == 12) batch.mintCommitments = new bytes32[](2);
            else if (field == 13) batch.mintCommitments[0] = 0;
            else batch.authorizer = address(0xBAD);
            _reject(terms, a, proof, batch, Authorization.InvalidCuratedPrivateBatch.selector);
        }
    }

    function testPlainArrayHashesAndIntentHashCannotSubstituteForCanonicalBindings() public {
        Authorization.Terms memory terms = _terms();
        for (uint256 field; field < 4; ++field) {
            IStreamMintManager.MintBatch memory batch = _batch(terms);
            StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(terms, batch);
            if (field == 0) {
                a.initialRecipientsHash = keccak256(abi.encode(batch.initialRecipients));
            } else if (field == 1) {
                a.beneficiariesHash = keccak256(abi.encode(batch.beneficiaries));
            } else if (field == 2) {
                a.tokenDataArrayHash = keccak256(abi.encode(batch.tokenData));
            } else {
                a.mintCommitmentsHash = keccak256(abi.encode(batch.mintCommitments));
            }
            IStreamPrivateSaleAdapter.Signature memory proof = _proof(terms, a, batch);
            _reject(terms, a, proof, batch, Authorization.InvalidCuratedPrivateBatch.selector);
        }
        IStreamMintManager.MintBatch memory batch = _batch(terms);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(terms, batch);
        IStreamPrivateSaleAdapter.Signature memory proof = _proof(terms, a, batch);
        batch.authorizationId = keccak256("prepared intent has a separate identity");
        _reject(terms, a, proof, batch, Authorization.CuratedPrivateLedgerIdMismatch.selector);
        batch.authorizationId = 0;
        _reject(terms, a, proof, batch, Authorization.CuratedPrivateLedgerIdMismatch.selector);
    }

    function testNonceAndDeadlineChangesNeedNewSignaturesAndHostDomainCannotReplay() public {
        Authorization.Terms memory terms = _terms();
        IStreamMintManager.MintBatch memory batch = _batch(terms);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(terms, batch);
        IStreamPrivateSaleAdapter.Signature memory proof = _proof(terms, a, batch);
        a.nonce = keccak256("fresh valid nonce");
        batch.authorizationId = _id(_digest(a));
        _reject(terms, a, proof, batch, Authorization.CuratedPrivateSignatureInvalid.selector);
        proof = _proof(terms, a, batch);
        --a.deadline;
        batch.authorizationId = _id(_digest(a));
        _reject(terms, a, proof, batch, Authorization.CuratedPrivateSignatureInvalid.selector);
        proof = _proof(terms, a, batch);
        CuratedPrivateAuthorizationHost other = new CuratedPrivateAuthorizationHost();
        vm.expectRevert(Authorization.InvalidCuratedPrivateAuthorization.selector);
        vm.prank(BUYER);
        other.validate(_context(), terms, a, proof, batch);
    }

    function testSaleAndAuthorizationTimeBoundariesAreInclusive() public {
        Authorization.Terms memory terms = _terms();
        IStreamMintManager.MintBatch memory batch = _batch(terms);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(terms, batch);
        a.deadline = terms.deadline;
        IStreamPrivateSaleAdapter.Signature memory proof = _proof(terms, a, batch);
        vm.warp(terms.startsAt - 1);
        _reject(terms, a, proof, batch, Authorization.InvalidCuratedPrivateAuthorization.selector);
        vm.warp(terms.startsAt);
        _validate(terms, a, proof, batch, BUYER);
        vm.warp(terms.deadline);
        _validate(terms, a, proof, batch, BUYER);
        vm.warp(terms.deadline + 1);
        _reject(terms, a, proof, batch, Authorization.InvalidCuratedPrivateAuthorization.selector);
        vm.warp(1000);
        a.deadline = 999;
        proof = _proof(terms, a, batch);
        _reject(terms, a, proof, batch, Authorization.InvalidCuratedPrivateAuthorization.selector);
    }

    function testExplicitExecutorCanDifferFromBuyerButValidatorDoesNotAuthorizeDelegation() public {
        Authorization.Terms memory terms = _terms();
        IStreamMintManager.MintBatch memory batch = _batch(terms);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(terms, batch);
        address delegate = address(0xDE1E6A7E);
        a.executor = delegate;
        IStreamPrivateSaleAdapter.Signature memory proof = _proof(terms, a, batch);
        (bytes32 digest, bytes32 id) = _validate(terms, a, proof, batch, delegate);
        require(digest == _digest(a) && id == batch.authorizationId, "caller retained by library");
        require(a.payer == BUYER && batch.beneficiaries[0] == BUYER, "no buyer redirection");
        _reject(terms, a, proof, batch, Authorization.InvalidCuratedPrivateAuthorization.selector);
    }

    function testZeroPriceUnknownPolicyAndUndeclaredSellerKindAreInvalidTerms() public {
        for (uint256 field; field < 12; ++field) {
            Authorization.Terms memory terms = _terms();
            IStreamMintManager.MintBatch memory batch = _batch(terms);
            StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(terms, batch);
            IStreamPrivateSaleAdapter.Signature memory proof = _proof(terms, a, batch);
            if (field == 0) terms.price = 0;
            else if (field == 1) terms.primaryPolicyMode = 2;
            else if (field == 2) terms.sellerKind = 0;
            else if (field == 3) terms.sellerKind = 3;
            else if (field == 4) terms.saleId = 0;
            else if (field == 5) terms.collectionId = 0;
            else if (field == 6) terms.phaseId = 0;
            else if (field == 7) terms.buyer = address(host);
            else if (field == 8) terms.selectedLeaf = 0;
            else if (field == 9) terms.mintPolicyHash = 0;
            else if (field == 10) terms.expectedPrimaryPolicyHash = 0;
            else terms.deadline = terms.startsAt;
            _reject(terms, a, proof, batch, Authorization.InvalidCuratedPrivateTerms.selector);
        }
    }

    function testMissingBuyerSellerManagerOrSignatureBudgetCannotAdmitTerms() public {
        for (uint256 field; field < 5; ++field) {
            Authorization.Context memory context = _context();
            Authorization.Terms memory terms = _terms();
            IStreamMintManager.MintBatch memory batch = _batch(terms);
            StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(terms, batch);
            IStreamPrivateSaleAdapter.Signature memory proof = _proof(terms, a, batch);
            if (field == 0) terms.buyer = address(0);
            else if (field == 1) terms.seller = address(0);
            else if (field == 2) context.manager = address(0);
            else if (field == 3) context.signatureGas = 0;
            else context.signatureGas = type(uint256).max;
            vm.expectRevert(Authorization.InvalidCuratedPrivateTerms.selector);
            vm.prank(BUYER);
            host.validate(context, terms, a, proof, batch);
        }
    }

    function _context() private pure returns (Authorization.Context memory) {
        return Authorization.Context(MANAGER, 200000);
    }

    function _terms() private view returns (Authorization.Terms memory) {
        return Authorization.Terms(
            keccak256("original private sale"),
            7,
            keccak256("original phase"),
            BUYER,
            1 ether,
            900,
            2000,
            keccak256("host verified original selected leaf"),
            keccak256("original mint policy"),
            0,
            keccak256("strict primary policy"),
            seller,
            1
        );
    }

    function _batch(Authorization.Terms memory terms)
        private
        view
        returns (IStreamMintManager.MintBatch memory b)
    {
        b.collectionId = terms.collectionId;
        b.phaseId = terms.phaseId;
        b.payer = terms.buyer;
        b.authorizer = terms.seller;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = address(host);
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = terms.buyer;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = bytes("original selected work");
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = keccak256("original mint commitment");
        b.expectedPolicyHash = terms.mintPolicyHash;
        b.contextHash = keccak256("host verified original content context");
    }

    function _authorization(Authorization.Terms memory terms, IStreamMintManager.MintBatch memory b)
        private
        view
        returns (StreamPrivateSaleTypes.SaleAuthorization memory a)
    {
        a.chainId = block.chainid;
        a.saleAdapter = address(host);
        a.mintManager = MANAGER;
        a.collectionId = terms.collectionId;
        a.phaseId = terms.phaseId;
        a.saleId = terms.saleId;
        a.saleKind = 5;
        a.revenueClass = keccak256("PRIMARY_SALE");
        a.expectedPrimaryPolicyHash = terms.expectedPrimaryPolicyHash;
        a.primaryPolicyMode = terms.primaryPolicyMode;
        a.initialRecipientsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), b.initialRecipients)
        );
        a.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), b.beneficiaries)
        );
        a.tokenDataArrayHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), b.tokenData));
        a.mintCommitmentsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), b.mintCommitments)
        );
        a.payer = terms.buyer;
        a.executor = BUYER;
        a.unitPrice = terms.price;
        a.quantity = 1;
        a.contentSelectionHash = terms.selectedLeaf;
        a.policyHash = terms.mintPolicyHash;
        a.nonce = keccak256("original authorization nonce");
        a.deadline = 1900;
    }

    function _digest(StreamPrivateSaleTypes.SaleAuthorization memory a)
        private
        view
        returns (bytes32)
    {
        // Independent permanent typehash and domain; production hash helpers are not the oracle.
        bytes32 body = keccak256(
            abi.encode(
                bytes32(0x6e5460498aa6274ffa516d53c6046a385c1ff9dd62d6adbfc54c339a4bb6e8d6), a
            )
        );
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream Sales"),
                keccak256("1"),
                block.chainid,
                address(host)
            )
        );
        return keccak256(abi.encodePacked(hex"1901", domain, body));
    }

    function _id(bytes32 digest) private pure returns (bytes32) {
        return keccak256(abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), digest));
    }

    function _sign(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _proof(
        Authorization.Terms memory terms,
        StreamPrivateSaleTypes.SaleAuthorization memory a,
        IStreamMintManager.MintBatch memory batch
    ) private returns (IStreamPrivateSaleAdapter.Signature memory) {
        bytes32 digest = _digest(a);
        batch.authorizationId = _id(digest);
        return IStreamPrivateSaleAdapter.Signature(
            terms.seller, terms.sellerKind, _sign(SELLER_KEY, digest)
        );
    }

    function _validate(
        Authorization.Terms memory terms,
        StreamPrivateSaleTypes.SaleAuthorization memory a,
        IStreamPrivateSaleAdapter.Signature memory proof,
        IStreamMintManager.MintBatch memory batch,
        address executor
    ) private returns (bytes32, bytes32) {
        vm.prank(executor);
        return host.validate(_context(), terms, a, proof, batch);
    }

    function _reject(
        Authorization.Terms memory terms,
        StreamPrivateSaleTypes.SaleAuthorization memory a,
        IStreamPrivateSaleAdapter.Signature memory proof,
        IStreamMintManager.MintBatch memory batch,
        bytes4 selector
    ) private {
        if (selector == Authorization.CuratedPrivateSignatureInvalid.selector) {
            vm.expectRevert(abi.encodeWithSelector(selector, proof.authorizer));
        } else if (selector == Authorization.CuratedPrivateSignerNotAuthorized.selector) {
            vm.expectRevert(abi.encodeWithSelector(selector, proof.authorizer, proof.kind));
        } else if (selector == Authorization.CuratedPrivateLedgerIdMismatch.selector) {
            vm.expectRevert(
                abi.encodeWithSelector(selector, _id(_digest(a)), batch.authorizationId)
            );
        } else {
            vm.expectRevert(selector);
        }
        _validate(terms, a, proof, batch, BUYER);
    }
}
