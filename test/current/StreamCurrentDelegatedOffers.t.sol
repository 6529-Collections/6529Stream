// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamCurrentPrivateSaleDelegation.t.sol";
import {
    IStreamPrivateSaleDelegatedOffers as Offers
} from "../../smart-contracts/interfaces/stream/mint/IStreamPrivateSaleDelegatedOffers.sol";

contract OfferDelegationBuyer {
    DelegationManagementContract public registry;
    address public core;
    address public delegate;
    bool public revokeOnDelivery;

    constructor(DelegationManagementContract r, address c, address d) {
        registry = r;
        core = c;
        delegate = d;
    }

    function revokeDuringDelivery(bool value) external {
        revokeOnDelivery = value;
    }

    function execute(address target, uint256 value, bytes calldata data) external {
        (bool ok, bytes memory out) = target.call{ value: value }(data);
        if (!ok) assembly ("memory-safe") { revert(add(out, 32), mload(out)) }
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        require(msg.sender == core);
        if (revokeOnDelivery) registry.revokeDelegationAddress(core, delegate, 2);
        return 0x150b7a02;
    }
    receive() external payable { }
}

/// @dev Actual current Core, module/role registries, original NFTDelegation, collector/buyer/delegate
/// Safes and secondary royalty settlement. Inherited Artist/entropy/governance seams remain typed.
contract StreamCurrentDelegatedOffersTest is StreamCurrentPrivateSaleDelegationTest {
    uint256 private constant DELEGATE_KEY = 0x77191;

    struct OfferPlan {
        bytes32 id;
        PT.SaleOffer offer;
        PT.SaleAuthorization authorization;
        Private.Signature sellerProof;
        Private.Signature delegateProof;
        PT.SaleCustodyGrant ownerGrant;
        bytes ownerSignature;
    }

    function _registry() private view returns (DelegationManagementContract) {
        return DelegationManagementContract(inventory.delegateRegistry());
    }

    function _witness() private pure returns (Claims.DelegationWitness memory) {
        return Claims.DelegationWitness(false, 0);
    }

    function _grantTo(address delegate) private {
        DelegationManagementContract registry_ = _registry();
        require(
            executeSafe(
                customer,
                customerKeys,
                address(registry_),
                0,
                abi.encodeCall(
                    registry_.registerDelegationAddress,
                    (
                        address(core),
                        delegate,
                        uint256(this.timeNow()) + 1 days,
                        uint256(2),
                        true,
                        uint256(0)
                    )
                ),
                0
            )
        );
    }

    function _sig(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _offerPlan(uint256 token, address principal, address signer, uint8 signatureKind)
        private
        returns (OfferPlan memory p)
    {
        p.offer = PT.SaleOffer(
            block.chainid,
            address(inventory),
            address(core),
            2,
            token,
            0,
            principal,
            address(0),
            1000,
            keccak256(abi.encode("delegated original offer", token, principal)),
            this.timeNow() + 1 days,
            0
        );
        bytes32 offerHash = inventory.offerDigest(p.offer);
        p.id = inventory.registerSale(
            Private.SaleConfig(
                6,
                2,
                token,
                address(collector),
                principal,
                1000,
                this.timeNow(),
                this.timeNow() + 1 days,
                offerHash,
                keccak256("actual explicit configuration delegation"),
                1,
                address(this),
                true,
                0
            )
        );
        PT.SaleAuthorization memory a;
        a.chainId = block.chainid;
        a.saleAdapter = address(inventory);
        a.collectionId = 2;
        a.saleId = p.id;
        a.saleKind = 6;
        address[] memory recipients = new address[](1);
        recipients[0] = principal;
        a.initialRecipientsHash = keccak256(abi.encode(recipients));
        a.beneficiariesHash = keccak256(abi.encode(recipients));
        a.tokenDataArrayHash = keccak256(abi.encode(new bytes[](0)));
        a.mintCommitmentsHash = keccak256(abi.encode(new bytes32[](0)));
        a.payer = principal;
        a.executor = principal;
        a.unitPrice = 1000;
        a.quantity = 1;
        a.nonce = keccak256(abi.encode("matching unchanged authorization", p.id));
        a.deadline = this.timeNow() + 1 days;
        p.authorization = a;
        p.sellerProof = Private.Signature(
            vm.addr(AUCTION_PLATFORM_KEY),
            1,
            _sig(AUCTION_PLATFORM_KEY, inventory.authorizationDigest(a))
        );
        p.delegateProof = Private.Signature(
            signer, signatureKind, signatureKind == 1 ? _sig(DELEGATE_KEY, offerHash) : bytes("")
        );
        p.ownerGrant = _grant(offerHash, token);
        p.ownerSignature = _wrapped(inventory.custodyGrantDigest(p.ownerGrant));
    }

    function _data(OfferPlan memory p, bool delegated) private view returns (bytes memory) {
        if (delegated) {
            return abi.encodeCall(
                inventory.acceptDelegatedOffer,
                (
                    p.authorization,
                    p.sellerProof,
                    p.offer,
                    p.delegateProof,
                    p.ownerGrant,
                    uint8(2),
                    p.ownerSignature,
                    _witness()
                )
            );
        }
        return abi.encodeCall(
            inventory.acceptOffer,
            (
                p.authorization,
                p.sellerProof,
                p.offer,
                p.delegateProof,
                p.ownerGrant,
                uint8(2),
                p.ownerSignature
            )
        );
    }

    function _buyerTransaction(bytes memory data) private returns (bytes memory) {
        bytes32 digest = customer.getTransactionHash(
            address(inventory), 1017, data, 0, 0, 0, 0, address(0), address(0), customer.nonce()
        );
        bytes memory signatures = safeThresholdSignature(customerKeys, digest);
        return abi.encodeCall(
            OfficialSafe.execTransaction,
            (
                address(inventory),
                1017,
                data,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                signatures
            )
        );
    }

    function _assertUnused(OfferPlan memory p) private view {
        require(
            !inventory.digestConsumed(inventory.offerDigest(p.offer))
                && !inventory.digestConsumed(inventory.authorizationDigest(p.authorization))
                && !inventory.digestConsumed(inventory.custodyGrantDigest(p.ownerGrant))
                && inventory.saleDetails(p.id).status == 1
                && core.ownerOf(p.offer.tokenId) == address(collector)
        );
    }

    function testEOADelegateUsesOriginalPrincipalDigestAndCannotExecuteOrReplaceMakerEntry()
        external
    {
        uint256 token = _delivered(1)[0];
        address delegate = vm.addr(DELEGATE_KEY);
        _grantTo(delegate);
        require(inventory.supportsInterface(type(Offers).interfaceId));
        OfferPlan memory p = _offerPlan(token, address(customer), delegate, 1);
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream Sales"),
                keccak256("1"),
                block.chainid,
                address(inventory)
            )
        );
        bytes32 original = keccak256(
            abi.encodePacked(
                hex"1901",
                domain,
                keccak256(
                    abi.encode(
                        keccak256(
                            "SaleOffer(uint256 chainId,address saleAdapter,address core,uint256 collectionId,uint256 tokenId,bytes32 contentSelectionHash,address buyer,address asset,uint256 price,bytes32 nonce,uint64 deadline,uint64 finalizeBy)"
                        ),
                        p.offer
                    )
                )
            )
        );
        require(original == inventory.offerDigest(p.offer) && p.offer.buyer == address(customer));
        bytes memory delegatedData = _data(p, true);
        vm.deal(delegate, 1017);
        vm.prank(delegate);
        (bool ok, bytes memory out) = address(inventory).call{ value: 1017 }(delegatedData);
        // Low-level call returns the precise original payment-authority failure.
        require(
            !ok
                && keccak256(out)
                    == keccak256(
                        abi.encodeWithSelector(Private.PrivateSaleNotBuyer.selector, delegate)
                    )
        );
        _assertUnused(p);
        bytes memory oldData = _buyerTransaction(_data(p, false));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeSerialized(oldData);
        _assertUnused(p);
        uint256 principalBefore = address(customer).balance;
        uint256 signerBefore = delegate.balance;
        bytes memory accepted = _buyerTransaction(delegatedData);
        vm.recordLogs();
        this.executeSerialized(accepted);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 seen;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(inventory) || logs[i].topics.length == 0
                    || logs[i].topics[0]
                        != keccak256(
                            "OfferAccepted(uint16,bytes32,address,bytes32,uint256,address)"
                        )
            ) continue;
            ++seen;
            require(
                logs[i].topics.length == 3 && logs[i].topics[1] == p.id
                    && logs[i].topics[2] == bytes32(uint256(uint160(address(customer))))
                    && keccak256(logs[i].data)
                        == keccak256(abi.encode(uint16(1), original, uint256(1000), address(0)))
            );
        }
        require(seen == 1, "original indexed fields and full nonindexed receipt");
        require(
            core.ownerOf(token) == address(customer)
                && address(customer).balance == principalBefore - 1017
                && delegate.balance == signerBefore
                && inventory.refundableBalance(p.id, address(customer)) == 17
        );
        require(
            inventory.digestConsumed(original)
                && inventory.digestConsumed(inventory.authorizationDigest(p.authorization))
                && inventory.digestConsumed(inventory.custodyGrantDigest(p.ownerGrant))
        );
        bytes memory replay = _buyerTransaction(delegatedData);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeSerialized(replay);
        // A fresh sale, seller authorization and owner grant cannot revive the consumed offer.
        require(
            executeSafe(
                customer,
                customerKeys,
                address(core),
                0,
                abi.encodeWithSignature(
                    "transferFrom(address,address,uint256)",
                    address(customer),
                    address(collector),
                    token
                ),
                0
            )
        );
        OfferPlan memory fresh = _offerPlan(token, address(customer), delegate, 1);
        require(
            inventory.offerDigest(fresh.offer) == original && fresh.id != p.id
                && !inventory.digestConsumed(inventory.authorizationDigest(fresh.authorization))
                && !inventory.digestConsumed(inventory.custodyGrantDigest(fresh.ownerGrant))
        );
        bytes memory freshData = _buyerTransaction(_data(fresh, true));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeSerialized(freshData);
        fresh.delegateProof = Private.Signature(
            address(customer),
            2,
            safeThresholdSignature(customerKeys, safeMessageDigest(customer, abi.encode(original)))
        );
        freshData = _buyerTransaction(_data(fresh, false));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeSerialized(freshData);
        require(
            inventory.saleDetails(fresh.id).status == 1 && core.ownerOf(token) == address(collector)
                && !inventory.digestConsumed(inventory.authorizationDigest(fresh.authorization))
                && !inventory.digestConsumed(inventory.custodyGrantDigest(fresh.ownerGrant))
        );
    }

    function testActualDelegateSafe1271AndMakerSafeRemainSeparateSharedReplayRoutes() external {
        uint256[] memory tokens = _delivered(2);
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x19121;
        keys[1] = 0x19122;
        OfficialSafe signer =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 1717);
        _grantTo(address(signer));
        OfferPlan memory p = _offerPlan(tokens[0], address(customer), address(signer), 2);
        p.delegateProof.signature = safeThresholdSignature(
            keys, safeMessageDigest(signer, abi.encode(inventory.offerDigest(p.offer)))
        );
        this.executeSerialized(_buyerTransaction(_data(p, true)));
        require(core.ownerOf(tokens[0]) == address(customer));
        OfferPlan memory maker = _offerPlan(tokens[1], address(customer), address(customer), 2);
        maker.delegateProof.signature = safeThresholdSignature(
            customerKeys,
            safeMessageDigest(customer, abi.encode(inventory.offerDigest(maker.offer)))
        );
        bytes memory makerAsDelegate = _buyerTransaction(_data(maker, true));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeSerialized(makerAsDelegate);
        _assertUnused(maker);
        this.executeSerialized(_buyerTransaction(_data(maker, false)));
        require(core.ownerOf(tokens[1]) == address(customer));
        bytes memory makerReplay = _buyerTransaction(_data(maker, true));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeSerialized(makerReplay);
    }

    function testUnavailableRegistryRollsBackIdenticalBuyerSafeAndOriginalSignaturesRetry()
        external
    {
        uint256 token = _delivered(1)[0];
        address delegate = vm.addr(DELEGATE_KEY);
        _grantTo(delegate);
        OfferPlan memory p = _offerPlan(token, address(customer), delegate, 1);
        bytes memory serialized = _buyerTransaction(_data(p, true));
        uint256 nonce = customer.nonce();
        uint256 beforeBalance = address(customer).balance;
        bytes32 key =
            keccak256(abi.encodePacked(address(customer), address(core), delegate, uint256(2)));
        bytes memory row =
            abi.encodeWithSignature("globalDelegationHashes(bytes32,uint256)", key, uint256(0));
        // One failed first read, followed by five successful live reads around the original phases.
        calls.expectCall(address(_registry()), row, uint64(6));
        calls.mockCallRevert(
            address(_registry()),
            row,
            abi.encodeWithSignature("Error(string)", "registry unavailable")
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeSerialized(serialized);
        _assertUnused(p);
        require(
            customer.nonce() == nonce && address(customer).balance == beforeBalance
                && inventory.totalLiabilities() == 0 && address(inventory).balance == 0
        );
        calls.clearMockedCalls();
        this.executeSerialized(serialized);
        require(customer.nonce() == nonce + 1 && core.ownerOf(token) == address(customer));
    }

    function testRevokedDelegateWrongSignatureAndOwnerGrantCannotBorrowOtherAuthorities() external {
        uint256 token = _delivered(1)[0];
        address delegate = vm.addr(DELEGATE_KEY);
        _grantTo(delegate);
        OfferPlan memory p = _offerPlan(token, address(customer), delegate, 1);
        bytes memory original = p.delegateProof.signature;
        p.delegateProof.signature = _sig(DELEGATE_KEY + 1, inventory.offerDigest(p.offer));
        bytes memory data = _buyerTransaction(_data(p, true));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeSerialized(data);
        _assertUnused(p);
        p.delegateProof.signature = original;
        bytes memory ownerSignature = p.ownerSignature;
        p.ownerSignature = _sig(DELEGATE_KEY, inventory.custodyGrantDigest(p.ownerGrant));
        data = _buyerTransaction(_data(p, true));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeSerialized(data);
        _assertUnused(p);
        p.ownerSignature = ownerSignature;
        DelegationManagementContract registry_ = _registry();
        require(
            executeSafe(
                customer,
                customerKeys,
                address(registry_),
                0,
                abi.encodeCall(
                    registry_.revokeDelegationAddress, (address(core), delegate, uint256(2))
                ),
                0
            )
        );
        data = _buyerTransaction(_data(p, true));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeSerialized(data);
        _assertUnused(p);
        _grantTo(delegate);
        this.executeSerialized(_buyerTransaction(_data(p, true)));
        require(core.ownerOf(token) == address(customer));
    }

    function testNFTCallbackRevokesActualGrantAfterRoyaltyAndFullExecutionRollsBackThenRetries()
        external
    {
        uint256 token = _delivered(1)[0];
        address delegate = vm.addr(DELEGATE_KEY);
        OfferDelegationBuyer principal =
            new OfferDelegationBuyer(_registry(), address(core), delegate);
        vm.deal(address(principal), 1017);
        principal.execute(
            address(_registry()),
            0,
            abi.encodeCall(
                _registry().registerDelegationAddress,
                (
                    address(core),
                    delegate,
                    uint256(this.timeNow()) + 1 days,
                    uint256(2),
                    true,
                    uint256(0)
                )
            )
        );
        OfferPlan memory p = _offerPlan(token, address(principal), delegate, 1);
        bytes memory data = _data(p, true);
        (address receiver, uint256 royalty,,) = inventory.royaltyQuote(p.id);
        uint256 royaltyBefore = receiver.balance;
        calls.expectCall(receiver, royalty, bytes(""), uint64(2));
        principal.revokeDuringDelivery(true);
        vm.expectRevert();
        principal.execute(address(inventory), 1017, data);
        _assertUnused(p);
        require(
            receiver.balance == royaltyBefore && address(principal).balance == 1017
                && address(inventory).balance == 0 && inventory.totalLiabilities() == 0
        );
        principal.revokeDuringDelivery(false);
        principal.execute(address(inventory), 1017, data);
        require(
            receiver.balance == royaltyBefore + royalty && core.ownerOf(token) == address(principal)
                && inventory.refundableBalance(p.id, address(principal)) == 17
        );
    }

    function testPrincipalRevocationConsumesOriginalOfferAndDelegateCannotRevokeForPrincipal()
        external
    {
        uint256 token = _delivered(1)[0];
        address delegate = vm.addr(DELEGATE_KEY);
        _grantTo(delegate);
        OfferPlan memory p = _offerPlan(token, address(customer), delegate, 1);
        // Even a valid offer signature is not a principal-signed revocation.
        vm.prank(delegate);
        vm.expectRevert();
        inventory.revokeOffer(p.offer, 1, p.delegateProof.signature);
        require(!inventory.digestConsumed(inventory.offerDigest(p.offer)));
        require(
            executeSafe(
                customer,
                customerKeys,
                address(inventory),
                0,
                abi.encodeCall(inventory.revokeOffer, (p.offer, uint8(2), bytes(""))),
                0
            )
        );
        bytes memory data = _buyerTransaction(_data(p, true));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeSerialized(data);
        require(
            inventory.digestConsumed(inventory.offerDigest(p.offer))
                && !inventory.digestConsumed(inventory.authorizationDigest(p.authorization))
                && !inventory.digestConsumed(inventory.custodyGrantDigest(p.ownerGrant))
                && core.ownerOf(token) == address(collector)
        );
    }
}
