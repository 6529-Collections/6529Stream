// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamCurrentSecondaryInventory.t.sol";
import {
    DelegationManagementContract
} from "../../smart-contracts/integrations/delegation/NFTdelegation.sol";
import {
    StreamNativeAuctionDelegation as Delegation
} from "../../smart-contracts/domains/auctions/StreamNativeAuctionDelegation.sol";
import {
    IStreamPrivateSaleDelegatedClaims as Claims
} from "../../smart-contracts/interfaces/stream/mint/IStreamPrivateSaleDelegatedClaims.sol";

interface PrivateClaimsVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
}

/// @dev Actual Core/Manager/Registry/Safe/royalty and retained NFTDelegation producer.
///      The inherited Artist/entropy/governance contexts stay explicitly typed, not full integration.
contract StreamCurrentPrivateSaleDelegationTest is StreamCurrentSecondaryInventoryTest {
    DelegationManagementContract private delegation;
    OfficialSafe private delegateSafe;
    uint256[] private delegateKeys;
    PrivateClaimsVm private constant claimVm =
        PrivateClaimsVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _prepareInventoryDeployment(StreamPrivateSaleAdapter.DeploymentConfig memory d)
        internal
        override
    {
        delegation = new DelegationManagementContract();
        d.delegateRegistry = address(delegation);
        d.delegationUsecase = 2;
        d.baseModuleManifestHash = MANIFEST;
        d.delegationGas = IStreamGasParameterHost.GasParameterConfig(
            "DELEGATE_REGISTRY_GAS_LIMIT", 150000, 50000, 2
        );
    }

    function _moduleManifest(address module) internal view override returns (bytes32) {
        return address(inventory) != address(0) && module == address(inventory)
            ? keccak256(inventory.delegationManifest())
            : super._moduleManifest(module);
    }

    function setUp() public override {
        super.setUp();
        delegateKeys = new uint256[](2);
        delegateKeys[0] = 0x8191;
        delegateKeys[1] = 0x8192;
        delegateSafe = createOfficialSafe(
            deploySafeComponents("1.4.1"), safeOwnerAddresses(delegateKeys), 2, 951
        );
    }

    function _w(bool wallet) private pure returns (Claims.DelegationWitness memory) {
        return Claims.DelegationWitness(wallet, 0);
    }

    function _live(OfficialSafe vault, uint256[] memory keys, address delegate, bool wallet)
        private
    {
        address scope = wallet ? address(0x8888888888888888888888888888888888888888) : address(core);
        require(
            executeSafe(
                vault,
                keys,
                address(delegation),
                0,
                abi.encodeCall(
                    delegation.registerDelegationAddress,
                    (
                        scope,
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

    function _remove(OfficialSafe vault, uint256[] memory keys, address delegate) private {
        require(
            executeSafe(
                vault,
                keys,
                address(delegation),
                0,
                abi.encodeCall(
                    delegation.revokeDelegationAddress, (address(core), delegate, uint256(2))
                ),
                0
            )
        );
    }

    function _row(address account, address delegate, bool wallet)
        private
        view
        returns (bytes memory)
    {
        address scope = wallet ? address(0x8888888888888888888888888888888888888888) : address(core);
        bytes32 key = keccak256(abi.encodePacked(account, scope, delegate, uint256(2)));
        return abi.encodeWithSignature("globalDelegationHashes(bytes32,uint256)", key, uint256(0));
    }

    function _serialized(bytes memory data) private returns (bytes memory out) {
        bytes32 digest = delegateSafe.getTransactionHash(
            address(inventory), 0, data, 0, 0, 0, 0, address(0), address(0), delegateSafe.nonce()
        );
        bytes memory signatures = safeThresholdSignature(delegateKeys, digest);
        return abi.encodeCall(
            OfficialSafe.execTransaction,
            (address(inventory), 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signatures)
        );
    }

    function executeDelegate(bytes calldata serialized) external {
        require(msg.sender == address(this));
        (bool ok, bytes memory out) = address(delegateSafe).call(serialized);
        if (!ok) assembly ("memory-safe") { revert(add(out, 32), mload(out)) }
        require(abi.decode(out, (bool)));
    }

    function testExactManifestAndLiveCoreWalletGrantsPayOnlyEachOriginalAccount() external {
        bytes memory expected = abi.encode(
            keccak256("6529STREAM_NATIVE_AUCTION_NFTDELEGATION_MANIFEST_V1"),
            block.chainid,
            address(inventory),
            MANIFEST,
            address(core),
            address(delegation),
            address(delegation).codehash,
            uint256(2)
        );
        require(keccak256(expected) == keccak256(inventory.delegationManifest()));
        require(registry.moduleRecord(address(inventory)).moduleManifestHash == keccak256(expected));
        require(inventory.supportsInterface(type(Claims).interfaceId));
        (bytes32 id, uint256[] memory ids) = _opened(1, 0);
        _buy(id, ids[0], 1027);
        _live(customer, customerKeys, address(this), false);
        _live(collector, collectorKeys, address(this), true);
        uint256 buyerBefore = address(customer).balance;
        uint256 ownerBefore = address(collector).balance;
        uint256 callerBefore = address(this).balance;
        uint256 owed = inventory.refundableBalance(id, address(collector));
        require(inventory.claimRefundFor(id, address(customer), _w(false)) == 27);
        require(inventory.claimRefundFor(id, address(collector), _w(true)) == owed);
        require(
            address(customer).balance == buyerBefore + 27
                && address(collector).balance == ownerBefore + owed
                && address(this).balance == callerBefore && inventory.totalLiabilities() == 0
        );
        vm.expectRevert();
        inventory.claimRefundFor(id, address(customer), _w(false));
    }

    function testWrongModuleManifestRejectsOriginalAndInventoryRegistrationBeforeNonceThenRetries()
        external
    {
        uint256[] memory ids = _delivered(1);
        StreamModuleRecord memory saved = registry.moduleRecord(address(inventory));
        StreamModuleRecord memory wrong = registry.moduleRecord(address(inventory));
        wrong.moduleManifestHash = keccak256("not the declared delegation pins");
        bytes memory read = abi.encodeCall(registry.moduleRecord, (address(inventory)));
        claimVm.mockCall(address(registry), read, abi.encode(wrong));
        uint256 nonce = inventory.nextSaleNonce();
        Inventory.Config memory c = _inventoryConfig(0);
        vm.expectRevert(abi.encodeWithSelector(Delegation.DelegationManifestMismatch.selector));
        inventory.registerInventory(c, ids);
        Private.SaleConfig memory privateConfig = Private.SaleConfig(
            5,
            2,
            ids[0],
            address(collector),
            address(customer),
            1000,
            this.timeNow(),
            this.timeNow() + 1 days,
            0,
            keccak256("actual explicit configuration delegation"),
            1,
            address(this),
            true,
            0
        );
        vm.expectRevert(abi.encodeWithSelector(Delegation.DelegationManifestMismatch.selector));
        inventory.registerSale(privateConfig);
        require(inventory.nextSaleNonce() == nonce);
        claimVm.mockCall(address(registry), read, abi.encode(saved));
        bytes32 id = inventory.registerInventory(c, ids);
        require(
            inventory.nextSaleNonce() == nonce + 1
                && inventory.inventoryDetails(id).saleNonce == nonce
        );
        calls.clearMockedCalls();
    }

    function testMissingLiveGrantRollsBackExactDelegateSafeThenOriginalBytesRetry() external {
        (bytes32 id, uint256[] memory ids) = _opened(1, 0);
        _buy(id, ids[0], 1027);
        bytes memory data =
            abi.encodeCall(inventory.claimRefundFor, (id, address(customer), _w(false)));
        bytes memory serialized = _serialized(data);
        uint256 nonce = delegateSafe.nonce();
        uint256 beforeBalance = address(customer).balance;
        uint256 liability = inventory.totalLiabilities();
        calls.expectCall(
            address(delegation), _row(address(customer), address(delegateSafe), false), uint64(2)
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeDelegate(serialized);
        require(
            delegateSafe.nonce() == nonce
                && inventory.refundableBalance(id, address(customer)) == 27
                && inventory.totalLiabilities() == liability
                && address(customer).balance == beforeBalance
        );
        _live(customer, customerKeys, address(delegateSafe), false);
        this.executeDelegate(serialized);
        require(
            delegateSafe.nonce() == nonce + 1 && address(customer).balance == beforeBalance + 27
                && inventory.refundableBalance(id, address(customer)) == 0
        );
    }

    function testActualRefundCallbackFailureRollsBackThenIdenticalSignedSafeRetry() external {
        (bytes32 id, uint256[] memory ids) = _opened(1, 0);
        _buy(id, ids[0], 1027);
        _live(customer, customerKeys, address(delegateSafe), false);
        bytes memory serialized = _serialized(
            abi.encodeCall(inventory.claimRefundFor, (id, address(customer), _w(false)))
        );
        uint256 nonce = delegateSafe.nonce();
        uint256 beforeBalance = address(customer).balance;
        uint256 adapterBefore = address(inventory).balance;
        uint256 liability = inventory.totalLiabilities();
        calls.expectCall(address(customer), 27, bytes(""), uint64(2));
        calls.mockCallRevert(
            address(customer),
            27,
            bytes(""),
            abi.encodeWithSignature("Error(string)", "refund callback")
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeDelegate(serialized);
        require(
            delegateSafe.nonce() == nonce
                && inventory.refundableBalance(id, address(customer)) == 27
                && inventory.totalLiabilities() == liability
                && address(inventory).balance == adapterBefore
                && address(customer).balance == beforeBalance
        );
        calls.clearMockedCalls();
        this.executeDelegate(serialized);
        require(
            delegateSafe.nonce() == nonce + 1 && address(customer).balance == beforeBalance + 27
                && address(inventory).balance == adapterBefore - 27
                && inventory.totalLiabilities() == liability - 27
        );
    }

    function testRegistryMalformedRevocationExpiryAndRuntimeLossPreserveOriginalOwnExit() external {
        (bytes32 id, uint256[] memory ids) = _opened(1, 0);
        _buy(id, ids[0], 1027);
        _live(customer, customerKeys, address(this), false);
        bytes memory row = _row(address(customer), address(this), false);
        for (uint256 i; i < 3; ++i) {
            claimVm.mockCall(address(delegation), row, new bytes(i == 0 ? 0 : i == 1 ? 191 : 224));
            vm.expectRevert();
            inventory.claimRefundFor(id, address(customer), _w(false));
            require(inventory.refundableBalance(id, address(customer)) == 27);
        }
        calls.clearMockedCalls();
        _remove(customer, customerKeys, address(this));
        vm.expectRevert();
        inventory.claimRefundFor(id, address(customer), _w(false));
        _live(customer, customerKeys, address(this), false);
        vm.warp(uint256(this.timeNow()) + 1 days);
        vm.expectRevert();
        inventory.claimRefundFor(id, address(customer), _w(false));
        vm.etch(address(delegation), hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(
                Delegation.DelegationRegistryUnavailable.selector, address(delegation)
            )
        );
        inventory.claimRefundFor(id, address(customer), _w(false));
        _status(address(inventory), ModuleRegistryStatus.INCIDENT_REVOKED);
        uint256 beforeBalance = address(this).balance;
        require(
            executeSafe(
                customer,
                customerKeys,
                address(inventory),
                0,
                abi.encodeCall(inventory.claimRefund, (id, address(this))),
                0
            )
        );
        require(
            address(this).balance == beforeBalance + 27
                && inventory.refundableBalance(id, address(customer)) == 0
        );
    }

    function testInventoryBeneficiaryAndRevokedLiveGrantNeverRedirectEarnedNFT() external {
        (bytes32 id, uint256[] memory ids) = _opened(1, 0);
        bytes memory transfer = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256)",
            address(inventory),
            address(customer),
            ids[0]
        );
        calls.mockCallRevert(
            address(core), transfer, abi.encodeWithSignature("Error(string)", "NFT callback")
        );
        _buy(id, ids[0], 1000);
        calls.clearMockedCalls();
        require(
            inventory.inventoryToken(id, ids[0]).nftClaim == 1
                && core.ownerOf(ids[0]) == address(inventory)
        );
        _live(collector, collectorKeys, address(this), false);
        vm.expectRevert(abi.encodeWithSelector(Private.PrivateSaleClaimUnavailable.selector));
        inventory.claimInventoryNftFor(id, ids[0], address(collector), _w(false));
        _live(customer, customerKeys, address(this), false);
        _remove(customer, customerKeys, address(this));
        vm.expectRevert();
        inventory.claimInventoryNftFor(id, ids[0], address(customer), _w(false));
        _live(customer, customerKeys, address(this), false);
        _status(address(inventory), ModuleRegistryStatus.INCIDENT_REVOKED);
        require(inventory.claimInventoryNftFor(id, ids[0], address(customer), _w(false)));
        require(
            core.ownerOf(ids[0]) == address(customer)
                && inventory.inventoryToken(id, ids[0]).nftClaim == 0
        );
        vm.expectRevert();
        inventory.claimInventoryNftFor(id, ids[0], address(customer), _w(false));
    }

    function _privatePurchase(uint8 kind, uint256 token) private returns (bytes32 id) {
        PT.SaleOffer memory offer = PT.SaleOffer(
            block.chainid,
            address(inventory),
            address(core),
            2,
            token,
            0,
            address(customer),
            address(0),
            1000,
            keccak256(abi.encode("current offer", token)),
            this.timeNow() + 1 days,
            0
        );
        Private.SaleConfig memory c = Private.SaleConfig(
            kind,
            2,
            token,
            address(collector),
            address(customer),
            1000,
            this.timeNow(),
            this.timeNow() + 1 days,
            kind == 6 ? inventory.offerDigest(offer) : bytes32(0),
            keccak256("actual explicit configuration delegation"),
            1,
            address(this),
            true,
            0
        );
        id = inventory.registerSale(c);
        PT.SaleCustodyGrant memory grant = _grant(kind == 6 ? c.offerDigest : id, token);
        bytes memory ownerSignature = _wrapped(inventory.custodyGrantDigest(grant));
        if (kind == 5) inventory.depositCustody(id, grant, 2, ownerSignature);
        PT.SaleAuthorization memory a;
        a.chainId = block.chainid;
        a.saleAdapter = address(inventory);
        a.collectionId = 2;
        a.saleId = id;
        a.saleKind = kind;
        address[] memory one = new address[](1);
        one[0] = address(customer);
        a.initialRecipientsHash = keccak256(abi.encode(one));
        a.beneficiariesHash = keccak256(abi.encode(one));
        a.tokenDataArrayHash = keccak256(abi.encode(new bytes[](0)));
        a.mintCommitmentsHash = keccak256(abi.encode(new bytes32[](0)));
        a.payer = address(customer);
        a.executor = address(customer);
        a.unitPrice = 1000;
        a.quantity = 1;
        a.nonce = keccak256(abi.encode(id, "original authorization"));
        a.deadline = this.timeNow() + 1 days;
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(AUCTION_PLATFORM_KEY, inventory.authorizationDigest(a));
        Private.Signature memory authorization =
            Private.Signature(vm.addr(AUCTION_PLATFORM_KEY), 1, abi.encodePacked(r, s, v));
        bytes memory data;
        if (kind == 5) {
            data = abi.encodeCall(inventory.purchasePrivate, (a, authorization));
        } else {
            Private.Signature memory buyerProof = Private.Signature(
                address(customer),
                2,
                safeThresholdSignature(
                    customerKeys, safeMessageDigest(customer, abi.encode(c.offerDigest))
                )
            );
            data = abi.encodeCall(
                inventory.acceptOffer,
                (a, authorization, offer, buyerProof, grant, uint8(2), ownerSignature)
            );
        }
        require(executeSafe(customer, customerKeys, address(inventory), 1017, data, 0));
    }

    function testOriginalPrivateAndOfferPaymentCreateOnlyBuyerDelegateClaims() external {
        uint256[] memory ids = _delivered(2);
        _live(customer, customerKeys, address(this), false);
        for (uint8 kind = 5; kind <= 6; ++kind) {
            uint256 token = ids[kind - 5];
            bytes memory transfer = abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256)",
                address(inventory),
                address(customer),
                token
            );
            calls.mockCallRevert(
                address(core), transfer, abi.encodeWithSignature("Error(string)", "NFT callback")
            );
            bytes32 id = _privatePurchase(kind, token);
            calls.clearMockedCalls();
            require(
                inventory.saleDetails(id).status == 3 && inventory.saleDetails(id).nftClaim == 1
            );
            require(inventory.claimNftFor(id, address(customer), _w(false)));
            require(core.ownerOf(token) == address(customer));
            require(inventory.claimRefundFor(id, address(customer), _w(false)) == 17);
            vm.expectRevert();
            inventory.claimNftFor(id, address(customer), _w(false));
        }
    }

    function testCancelledInventoryReclaimAndPermissionlessOriginalRetryStayIndependent() external {
        (bytes32 id, uint256[] memory ids) = _opened(2, 0);
        inventory.cancelSale(id);
        _live(collector, collectorKeys, address(this), false);
        require(inventory.claimInventoryNftFor(id, ids[0], address(collector), _w(false)));
        _remove(collector, collectorKeys, address(this));
        vm.expectRevert();
        inventory.claimInventoryNftFor(id, ids[1], address(collector), _w(false));
        vm.etch(address(delegation), hex"00");
        require(inventory.retryInventoryNft(id, ids[1]));
        require(
            core.ownerOf(ids[0]) == address(collector) && core.ownerOf(ids[1]) == address(collector)
        );
    }
}
