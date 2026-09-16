// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamERC20PrimaryOfferRevocation as Revocation
} from "../../../smart-contracts/domains/mint/StreamERC20PrimaryOfferRevocation.sol";
import {
    StreamPrivateSaleHash
} from "../../../smart-contracts/domains/mint/StreamPrivateSaleHash.sol";
import {
    StreamPrivateSaleTypes as Sale
} from "../../../smart-contracts/interfaces/stream/mint/StreamPrivateSaleTypes.sol";
import {
    IStreamPrivateSaleAdapter as Private
} from "../../../smart-contracts/interfaces/stream/mint/IStreamPrivateSaleAdapter.sol";
import {
    StreamERC20PrimaryOfferTypes as Offer
} from "../../../smart-contracts/interfaces/stream/mint/StreamERC20PrimaryOfferTypes.sol";

interface ERC20OfferRevocationVm {
    function addr(uint256) external returns (address);
    function sign(uint256, bytes32) external returns (uint8, bytes32, bytes32);
    function prank(address) external;
    function warp(uint256) external;
    function expectRevert(bytes calldata) external;
}

contract ERC20OfferHistoricalUnavailable {
    fallback() external {
        revert("historical revocation must not read live dependencies");
    }
}

/// @dev Only the host's immutable membership lookup and append-only consumed store are modeled.
contract ERC20OfferRevocationHarness {
    address public immutable manager;
    mapping(bytes32 => Offer.Configuration) private history;
    mapping(bytes32 => bool) private exists;
    mapping(bytes32 => bool) public consumed;
    mapping(bytes32 => bool) public revoked;
    bool public liveSignerEnabled = true;
    bool public phasePaused;
    bool public adapterAdmitted = true;
    uint8 public saleStatus = 1;
    error AlreadyConsumed(bytes32 digest);

    constructor(address manager_) {
        manager = manager_;
    }

    function install(bytes32 id, Offer.Configuration calldata c) external {
        require(!exists[id], "history immutable");
        exists[id] = true;
        history[id] = c;
    }

    function disableLiveState() external {
        liveSignerEnabled = false;
        phasePaused = true;
        adapterAdmitted = false;
        saleStatus = 3;
    }

    function authorizationDigest(Sale.SaleAuthorization memory a) public view returns (bytes32) {
        return StreamPrivateSaleHash.digest(
            block.chainid, address(this), StreamPrivateSaleHash.authorizationBody(a)
        );
    }

    function revoke(Sale.SaleAuthorization calldata a, Private.Signature calldata proof)
        external
        returns (bytes32 digest)
    {
        digest = authorizationDigest(a);
        if (consumed[digest]) revert AlreadyConsumed(digest);
        consumed[digest] = true;
        Revocation.validate(exists[a.saleId], manager, history[a.saleId], a, proof, digest, 400000);
        revoked[digest] = true;
    }
}

contract ERC20OfferRevocation1271 {
    ERC20OfferRevocationHarness private host;
    bytes32 private authorizationDigest;
    bytes32 private acceptedDigest;
    bytes32 private acceptedSignature;

    function allow(
        ERC20OfferRevocationHarness h,
        bytes32 authorization,
        bytes32 digest,
        bytes calldata signature
    ) external {
        host = h;
        authorizationDigest = authorization;
        acceptedDigest = digest;
        acceptedSignature = keccak256(signature);
    }

    function isValidSignature(bytes32 digest, bytes calldata signature)
        external
        view
        returns (bytes4)
    {
        return digest == acceptedDigest && keccak256(signature) == acceptedSignature
            && host.consumed(authorizationDigest)
            ? bytes4(0x1626ba7e)
            : bytes4(0xffffffff);
    }

    function revokeDirect(ERC20OfferRevocationHarness h, Sale.SaleAuthorization calldata a)
        external
        returns (bytes32)
    {
        return h.revoke(a, Private.Signature(address(this), 2, ""));
    }
}

contract StreamERC20PrimaryOfferRevocationTest {
    ERC20OfferRevocationVm private constant vm =
        ERC20OfferRevocationVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 private constant SELLER_KEY = 0x5252;
    ERC20OfferRevocationHarness private host;
    ERC20OfferHistoricalUnavailable private unavailable;

    function setUp() public {
        vm.warp(1000);
        unavailable = new ERC20OfferHistoricalUnavailable();
        host = new ERC20OfferRevocationHarness(address(unavailable));
    }

    function testDirectOriginalSellerRevokesAfterExpiryDisablementAndProviderLoss() public {
        (Sale.SaleAuthorization memory a, Private.Signature memory p) =
            _install(vm.addr(SELLER_KEY), 1);
        host.disableLiveState();
        require(
            a.deadline < block.timestamp && !host.liveSignerEnabled() && host.phasePaused()
                && !host.adapterAdmitted() && host.saleStatus() == 3,
            "expired inactive historical sale"
        );
        bytes32 digest = host.authorizationDigest(a);
        vm.prank(p.authorizer);
        require(host.revoke(a, p) == digest && host.revoked(digest), "original seller direct void");
        vm.expectRevert(
            abi.encodeWithSelector(ERC20OfferRevocationHarness.AlreadyConsumed.selector, digest)
        );
        vm.prank(p.authorizer);
        host.revoke(a, p);
    }

    function testRelayedEOARequiresOriginalAuthorizationRevocationDigest() public {
        (Sale.SaleAuthorization memory a, Private.Signature memory p) =
            _install(vm.addr(SELLER_KEY), 1);
        host.disableLiveState();
        bytes32 digest = host.authorizationDigest(a);
        p.signature = _sign(_revocation(p.authorizer, digest));
        require(
            host.revoke(a, p) == digest && host.consumed(digest) && host.revoked(digest),
            "exact original Sales family"
        );
    }

    function testOrdinarySaleAndOfferRevocationSignaturesCannotVoidAuthorization() public {
        (Sale.SaleAuthorization memory a, Private.Signature memory p) =
            _install(vm.addr(SELLER_KEY), 1);
        bytes32 digest = host.authorizationDigest(a);
        p.signature = _sign(digest);
        _invalidAuthority(a, p, digest);
        p.signature = _sign(
            _digest(
                keccak256(
                    abi.encode(
                        keccak256(
                            "SaleOfferRevocation(uint256 chainId,address saleAdapter,bytes32 offerDigest)"
                        ),
                        block.chainid,
                        address(host),
                        digest
                    )
                )
            )
        );
        _invalidAuthority(a, p, digest);
        p.signature = _sign(_revocation(p.authorizer, digest));
        host.revoke(a, p);
        require(host.revoked(digest), "wrong families leave original revocable");
    }

    function testRelayed1271ChecksExactAccountAndObservesPreconsumedDigest() public {
        ERC20OfferRevocation1271 seller = new ERC20OfferRevocation1271();
        (Sale.SaleAuthorization memory a, Private.Signature memory p) = _install(address(seller), 2);
        bytes32 digest = host.authorizationDigest(a);
        p.signature = hex"1234";
        seller.allow(host, digest, _revocation(address(seller), digest), p.signature);
        host.disableLiveState();
        host.revoke(a, p);
        require(
            host.consumed(digest) && host.revoked(digest),
            "1271 sees consumed before external proof"
        );
    }

    function testOriginalContractSellerDirectCallNeedsNo1271Signature() public {
        ERC20OfferRevocation1271 seller = new ERC20OfferRevocation1271();
        (Sale.SaleAuthorization memory a,) = _install(address(seller), 2);
        host.disableLiveState();
        bytes32 digest = host.authorizationDigest(a);
        // No accepted digest is configured: any ERC-1271 validation would fail.
        require(
            seller.revokeDirect(host, a) == digest && host.revoked(digest),
            "ordinary admitted seller CALL"
        );
    }

    function testOutsiderAndWrongExplicitKindCannotUseHistoricalMembership() public {
        (Sale.SaleAuthorization memory a, Private.Signature memory p) =
            _install(vm.addr(SELLER_KEY), 1);
        bytes32 digest = host.authorizationDigest(a);
        _invalidAuthority(a, p, digest);
        p.kind = 2;
        vm.expectRevert(abi.encodeWithSelector(Revocation.InvalidERC20PrimaryOffer.selector));
        vm.prank(p.authorizer);
        host.revoke(a, p);
        require(!host.consumed(digest), "direct caller cannot change admitted kind");
        p.authorizer = address(new ERC20OfferRevocation1271());
        vm.expectRevert(abi.encodeWithSelector(Revocation.InvalidERC20PrimaryOffer.selector));
        vm.prank(p.authorizer);
        host.revoke(a, p);
        require(!host.consumed(digest), "outsider contract is not original seller");
    }

    function testWrongAssetAndHistoricalBindingFieldsRollbackConsumption() public {
        (Sale.SaleAuthorization memory original, Private.Signature memory p) =
            _install(vm.addr(SELLER_KEY), 1);
        for (uint256 field; field < 16; ++field) {
            Sale.SaleAuthorization memory a =
                abi.decode(abi.encode(original), (Sale.SaleAuthorization));
            if (field == 0) a.chainId += 1;
            else if (field == 1) a.saleAdapter = address(0xBAD);
            else if (field == 2) a.mintManager = address(0xBAD);
            else if (field == 3) a.collectionId += 1;
            else if (field == 4) a.phaseId = 0;
            else if (field == 5) a.saleId = keccak256("absent sale");
            else if (field == 6) a.saleKind = 5;
            else if (field == 7) a.revenueClass = 0;
            else if (field == 8) a.payer = address(0xBAD);
            else if (field == 9) a.asset = address(0);
            else if (field == 10) a.unitPrice += 1;
            else if (field == 11) a.quantity = 2;
            else if (field == 12) a.primaryPolicyMode = 1;
            else if (field == 13) a.expectedPrimaryPolicyHash = 0;
            else if (field == 14) a.policyHash = 0;
            else a.finalizeBy = 1;
            bytes32 digest = host.authorizationDigest(a);
            vm.expectRevert(abi.encodeWithSelector(Revocation.InvalidERC20PrimaryOffer.selector));
            vm.prank(p.authorizer);
            host.revoke(a, p);
            require(!host.consumed(digest), "malformed historical binding never consumes");
        }
    }

    function testFullPayloadAndClaimedAuthorizerRemainBoundInRelayedRevocation() public {
        (Sale.SaleAuthorization memory a, Private.Signature memory p) =
            _install(vm.addr(SELLER_KEY), 1);
        bytes32 digest = host.authorizationDigest(a);
        p.signature = _sign(_revocation(address(0xBAD), digest));
        _invalidAuthority(a, p, digest);
        p.signature = _sign(_revocation(p.authorizer, digest));
        a.nonce = keccak256("another original authorization");
        bytes32 replacement = host.authorizationDigest(a);
        _invalidAuthority(a, p, replacement);
        p.signature = _sign(_revocation(p.authorizer, replacement));
        host.revoke(a, p);
        require(
            host.revoked(replacement) && !host.consumed(digest),
            "full payload selects one historical digest"
        );
    }

    function _install(address seller, uint8 kind)
        private
        returns (Sale.SaleAuthorization memory a, Private.Signature memory p)
    {
        Offer.Configuration memory c;
        c.collectionId = 1;
        c.phaseId = keccak256("historical phase");
        c.asset = address(unavailable);
        c.paymentAdapter = address(unavailable);
        c.price = 1000;
        c.poster = address(0x9057);
        c.startsAt = 100;
        c.endsAt = 500;
        c.mintPolicyHash = keccak256("original mint policy");
        c.expectedPrimaryPolicyHash = keccak256("original primary policy");
        c.buyer = address(0xB001);
        c.offerDigest = keccak256("original buyer offer");
        c.signer = seller;
        c.signerKind = kind;
        c.signerEvidenceHash = keccak256("original seller evidence");
        c.signerRevision = 1;
        c.signerAuthority = address(unavailable);
        a.chainId = block.chainid;
        a.saleAdapter = address(host);
        a.mintManager = address(unavailable);
        a.collectionId = c.collectionId;
        a.phaseId = c.phaseId;
        a.saleId = keccak256("original sale");
        a.saleKind = 6;
        a.revenueClass = keccak256("PRIMARY_SALE");
        a.expectedPrimaryPolicyHash = c.expectedPrimaryPolicyHash;
        a.initialRecipientsHash = keccak256("original buyer initial recipients");
        a.beneficiariesHash = keccak256("original buyer beneficiaries");
        a.tokenDataArrayHash = keccak256("original artwork");
        a.mintCommitmentsHash = keccak256("original commitments");
        a.payer = c.buyer;
        a.executor = address(0xE0EC);
        a.asset = c.asset;
        a.unitPrice = c.price;
        a.quantity = 1;
        a.policyHash = c.mintPolicyHash;
        a.nonce = keccak256("original nonce");
        a.deadline = c.endsAt;
        host.install(a.saleId, c);
        p = Private.Signature(seller, kind, "");
    }

    function _invalidAuthority(
        Sale.SaleAuthorization memory a,
        Private.Signature memory p,
        bytes32 digest
    ) private {
        vm.expectRevert(
            abi.encodeWithSelector(Private.PrivateSaleAuthorityInvalid.selector, p.authorizer)
        );
        host.revoke(a, p);
        require(
            !host.consumed(digest) && !host.revoked(digest), "failed proof restores durable store"
        );
    }

    function _revocation(address authorizer, bytes32 digest) private view returns (bytes32) {
        return _digest(
            keccak256(
                abi.encode(
                    keccak256(
                        "SaleAuthorizationRevocation(uint256 chainId,address saleAdapter,address authorizer,bytes32 authorizationDigest)"
                    ),
                    block.chainid,
                    address(host),
                    authorizer,
                    digest
                )
            )
        );
    }

    function _digest(bytes32 body) private view returns (bytes32) {
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

    function _sign(bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SELLER_KEY, digest);
        return abi.encodePacked(r, s, v);
    }
}
