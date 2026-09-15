// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/NativePlatformCustodyFixture.sol";
import {
    StreamPrivateSaleAdapter
} from "../../smart-contracts/domains/mint/StreamPrivateSaleAdapter.sol";
import {
    IStreamPrivateSaleAdapter as Private
} from "../../smart-contracts/interfaces/stream/mint/IStreamPrivateSaleAdapter.sol";
import {
    IStreamNativeInventorySale as Inventory
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeInventorySale.sol";
import {
    StreamPrivateSaleTypes as PT
} from "../../smart-contracts/interfaces/stream/mint/StreamPrivateSaleTypes.sol";

interface InventoryTestCalls {
    function expectCall(address, bytes calldata, uint64) external;
    function expectCall(address, uint256, bytes calldata, uint64) external;
    function mockCallRevert(address, bytes calldata, bytes calldata) external;
    function mockCallRevert(address, uint256, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
}

contract InventoryBuyerReceiver {
    bool public reject = true;
    address public target;
    bytes public callback;
    bool public callbackOk;
    uint256 public callbackValue;

    function setup(address a, uint256 value, bytes calldata data) external {
        target = a;
        callbackValue = value;
        callback = data;
    }

    function accepts() external {
        reject = false;
    }

    function execute(address a, uint256 value, bytes calldata data)
        external
        returns (bytes memory out)
    {
        bool ok;
        (ok, out) = a.call{ value: value }(data);
        if (!ok) assembly ("memory-safe") { revert(add(out, 32), mload(out)) }
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        require(!reject, "receiver rejection");
        if (target != address(0)) (callbackOk,) = target.call{ value: callbackValue }(callback);
        return 0x150b7a02;
    }
    receive() external payable { }
}

/// @dev Actual Core/Manager/Registry/royalty/split/recorder/Safes. Artist, entropy provider and
///      governance action context remain explicit typed fixture boundaries. Every token first
///      completes a paid platform primary sale and is delivered to its collector Safe.
contract StreamCurrentSecondaryInventoryTest is NativePlatformCustodyFixture {
    InventoryTestCalls internal constant calls =
        InventoryTestCalls(address(uint160(uint256(keccak256("hevm cheat code")))));
    StreamPrivateSaleAdapter internal inventory;
    OfficialSafe internal collector;
    OfficialSafe internal customer;
    uint256[] internal collectorKeys;
    uint256[] internal customerKeys;
    uint256 internal grantNonce;
    bytes32 internal primaryProfile;
    address internal primaryWallet;

    function setUp() public virtual override {
        super.setUp();
        SafeComponents memory c = deploySafeComponents("1.4.1");
        collectorKeys = new uint256[](2);
        collectorKeys[0] = 0x9981;
        collectorKeys[1] = 0x9982;
        customerKeys = new uint256[](2);
        customerKeys[0] = 0x9983;
        customerKeys[1] = 0x9984;
        collector = createOfficialSafe(c, safeOwnerAddresses(collectorKeys), 2, 721);
        customer = createOfficialSafe(c, safeOwnerAddresses(customerKeys), 2, 722);
        vm.deal(address(collector), 100 ether);
        vm.deal(address(customer), 100 ether);
        IStreamGasParameterHost.GasParameterConfig[3] memory rows;
        rows[0] =
            IStreamGasParameterHost.GasParameterConfig("SALE_ERC1271_GAS_LIMIT", 500000, 350000, 2);
        rows[1] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_NFT_DELIVERY_GAS_LIMIT", 500000, 150000, 2
        );
        rows[2] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ROYALTY_DELIVERY_GAS_LIMIT", 100000, 30000, 2
        );
        StreamPrivateSaleAdapter.DeploymentConfig memory deployment =
            StreamPrivateSaleAdapter.DeploymentConfig(
                address(core),
                address(registry),
                vm.addr(AUCTION_PLATFORM_KEY),
                address(this),
                address(revenueAuthority),
                address(auctionRoles),
                rows,
                address(0),
                0,
                bytes32(0),
                IStreamGasParameterHost.GasParameterConfig("", 0, 0, 0)
            );
        _prepareInventoryDeployment(deployment);
        inventory = new StreamPrivateSaleAdapter(deployment);
        _register(
            address(inventory),
            keccak256("PRIVATE_SALE_ADAPTER"),
            type(Private).interfaceId,
            keccak256("6529STREAM_NATIVE_CONSIGNMENT_V1")
        );
        inventory.configureCollectionSigner(
            2, keccak256("actual explicit configuration delegation"), true
        );
        require(
            executeSafe(
                collector,
                collectorKeys,
                address(core),
                0,
                abi.encodeCall(core.setApprovalForAll, (address(inventory), true)),
                0
            )
        );
        (primaryProfile, primaryWallet) = _fixed(10, address(0xFD551));
    }

    function _prepareInventoryDeployment(StreamPrivateSaleAdapter.DeploymentConfig memory)
        internal
        virtual { }

    function _delivered(uint256 count) internal returns (uint256[] memory ids) {
        ids = new uint256[](count);
        for (uint256 i; i < count; ++i) {
            Plan memory plan = _plan(10, address(this), 100);
            bytes32 auctionId = _acquire(plan);
            require(
                executeSafe(
                    collector,
                    collectorKeys,
                    address(house),
                    1000,
                    abi.encodeCall(house.bid, (auctionId, address(collector))),
                    0
                )
            );
            _end(auctionId);
            (uint256 tokenId, bytes32 key) = house.settle(auctionId);
            require(
                core.ownerOf(tokenId) == address(collector) && recorder.settlementConsumed(key)
                    && recorder.settlementResult(key).profileId == primaryProfile,
                "actual original primary payment and completed collector delivery, not MINTED inference"
            );
            ids[i] = tokenId;
        }
    }

    function _inventoryConfig(uint32 cap) internal view returns (Inventory.Config memory c) {
        c.collectionId = 2;
        c.consignor = address(collector);
        c.unitPrice = 1000;
        c.startTime = this.timeNow();
        c.deadline = this.timeNow() + 1 days;
        c.perBuyerCap = cap;
        c.signerEvidenceHash = keccak256("actual explicit configuration delegation");
        c.signerRevision = 1;
        c.signerAuthority = address(this);
        c.secondaryConsignment = true;
    }

    function _grant(bytes32 id, uint256 token) internal returns (PT.SaleCustodyGrant memory g) {
        g = PT.SaleCustodyGrant(
            block.chainid,
            address(inventory),
            address(core),
            token,
            address(collector),
            id,
            bytes32(++grantNonce),
            this.timeNow() + 1 days
        );
    }

    function _digest(PT.SaleCustodyGrant memory g) internal view returns (bytes32) {
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
        return keccak256(
            abi.encodePacked(
                hex"1901",
                domain,
                keccak256(
                    abi.encode(
                        keccak256(
                            "SaleCustodyGrant(uint256 chainId,address saleAdapter,address core,uint256 tokenId,address owner,bytes32 saleRef,bytes32 nonce,uint64 deadline)"
                        ),
                        g
                    )
                )
            )
        );
    }

    function _wrapped(bytes32 digest) internal returns (bytes memory) {
        return
            safeThresholdSignature(collectorKeys, safeMessageDigest(collector, abi.encode(digest)));
    }

    function _deposit(bytes32 id, uint256 token) internal returns (PT.SaleCustodyGrant memory g) {
        g = _grant(id, token);
        bytes32 digest = _digest(g);
        require(
            digest == inventory.custodyGrantDigest(g), "original canonical domain/full owner grant"
        );
        inventory.depositInventoryCustody(id, g, 2, _wrapped(digest));
        require(
            inventory.digestConsumed(digest) && core.ownerOf(token) == address(inventory),
            "single-use real custody"
        );
    }

    function _opened(uint256 count, uint32 cap)
        internal
        returns (bytes32 id, uint256[] memory ids)
    {
        ids = _delivered(count);
        id = inventory.registerInventory(_inventoryConfig(cap), ids);
        for (uint256 i; i < ids.length; ++i) {
            _deposit(id, ids[i]);
        }
        inventory.openInventory(id);
    }

    function _buy(bytes32 id, uint256 token, uint256 value) internal {
        bytes32 configHash = inventory.inventoryDetails(id).configHash;
        require(
            executeSafe(
                customer,
                customerKeys,
                address(inventory),
                value,
                abi.encodeCall(inventory.purchaseInventory, (id, token, configHash)),
                0
            )
        );
    }

    function _revoke(PT.SaleCustodyGrant memory g) internal {
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
        bytes32 digest = keccak256(
            abi.encodePacked(
                hex"1901",
                domain,
                keccak256(
                    abi.encode(
                        keccak256(
                            "SaleCustodyGrantRevocation(uint256 chainId,address saleAdapter,address owner,bytes32 grantDigest)"
                        ),
                        block.chainid,
                        address(inventory),
                        address(collector),
                        _digest(g)
                    )
                )
            )
        );
        inventory.revokeCustodyGrant(g, 2, _wrapped(digest));
    }

    function testActualPlatformCollectorManifestAndPublicSecondaryPaymentKeepPrimaryCountersUntouched()
        external
    {
        uint256[] memory ids = _delivered(2);
        Inventory.Config memory config = _inventoryConfig(0);
        uint256 nonce = inventory.nextSaleNonce();
        bytes32 id = inventory.registerInventory(config, ids);
        bytes32 manifest = keccak256(abi.encode(ids));
        bytes32 configHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_SECONDARY_INVENTORY_CONFIG_V1"),
                block.chainid,
                address(inventory),
                nonce,
                vm.addr(AUCTION_PLATFORM_KEY),
                config,
                manifest
            )
        );
        Inventory.Inventory memory saved = inventory.inventoryDetails(id);
        require(
            saved.configHash == configHash && saved.inventoryHash == manifest
                && keccak256(abi.encode(saved.tokenIds)) == keccak256(abi.encode(ids)),
            "complete immutable sorted manifest and config"
        );
        _deposit(id, ids[0]);
        vm.expectRevert(
            abi.encodeWithSelector(Inventory.InventoryTokenUnavailable.selector, id, ids[1])
        );
        inventory.openInventory(id);
        PT.SaleCustodyGrant memory direct = _grant(id, ids[1]);
        require(
            executeSafe(
                collector,
                collectorKeys,
                address(inventory),
                0,
                abi.encodeCall(
                    inventory.depositInventoryCustody, (id, direct, uint8(2), bytes(""))
                ),
                0
            ),
            "actual owner-sent Safe deposit requires no separate signature"
        );
        inventory.openInventory(id);
        (uint8 kind, uint256 cid,,, bytes32 h, bytes32 primary,, uint8 status) =
            inventory.saleRecord(id);
        require(
            kind == 14 && cid == 2 && h == configHash && primary == 0 && status == 2,
            "original saleRecord for explicit secondary kind14"
        );
        (address receiver, uint256 royaltyAmount, bool secondary, bool outsideDisclosure) =
            inventory.inventoryRoyaltyQuote(id, ids[0]);
        require(
            receiver == wallet && royaltyAmount == 35 && secondary && outsideDisclosure,
            "pre-purchase itemized actual frozen token royalties"
        );
        uint256 official =
            recorder.officialSettled(CLASS, primaryProfile, primaryWallet, address(0));
        uint256 royaltyBalance = receiver.balance;
        uint256 mintNonce = manager.nextOperationNonce();
        bytes32 oldSnapshot = keccak256(abi.encode(royalty.royaltySnapshot(ids[0])));
        platform.contest(1);
        vm.recordLogs();
        _buy(id, ids[0], 1027);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 receipts;
        bytes32 topic = keccak256(
            "ConsignmentSettled(uint16,bytes32,uint256,address,uint256,uint256,address,address)"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(inventory) && logs[i].topics.length == 4
                    && logs[i].topics[0] == topic && logs[i].topics[1] == id
            ) {
                require(
                    uint256(logs[i].topics[2]) == ids[0]
                        && address(uint160(uint256(logs[i].topics[3]))) == address(customer)
                        && keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(
                                    uint16(1),
                                    uint256(1000),
                                    uint256(35),
                                    receiver,
                                    address(collector)
                                )
                            ),
                    "full canonical secondary receipt"
                );
                ++receipts;
            }
        }
        require(
            receipts == 1 && receiver.balance == royaltyBalance + 35
                && core.ownerOf(ids[0]) == address(customer)
                && inventory.refundableBalance(id, address(collector)) == 965
                && inventory.refundableBalance(id, address(customer)) == 27,
            "exact buyer excess, owner proceeds, royalty and delivery"
        );
        vm.deal(address(0xBEEF), 1000);
        vm.prank(address(0xBEEF));
        inventory.purchaseInventory{ value: 1000 }(id, ids[1], configHash);
        require(
            core.ownerOf(ids[1]) == address(0xBEEF)
                && inventory.inventoryToken(id, ids[1]).config.buyer == address(0xBEEF),
            "public buyer bound only at purchase"
        );
        require(
            recorder.officialSettled(CLASS, primaryProfile, primaryWallet, address(0)) == official
                && manager.nextOperationNonce() == mintNonce && _counter() == 2
                && oldSnapshot == keccak256(abi.encode(royalty.royaltySnapshot(ids[0]))),
            "no second mint/snapshot or official secondary revenue"
        );
        require(
            executeSafe(
                collector,
                collectorKeys,
                address(inventory),
                0,
                abi.encodeCall(inventory.claimRefund, (id, address(collector))),
                0
            )
        );
        require(
            executeSafe(
                customer,
                customerKeys,
                address(inventory),
                0,
                abi.encodeCall(inventory.claimRefund, (id, address(customer))),
                0
            )
        );
        require(
            inventory.totalLiabilities() == 0 && address(inventory).balance == 0,
            "all separate perpetual credits paid exactly"
        );
    }

    function testManifestCustodyAndOldPrivateSelectorsCannotSubstituteForInventory() external {
        uint256[] memory ids = _delivered(2);
        Inventory.Config memory c = _inventoryConfig(0);
        uint256 first = ids[0];
        ids[0] = ids[1];
        vm.expectRevert(abi.encodeWithSelector(Inventory.InvalidInventory.selector));
        inventory.registerInventory(c, ids);
        ids[0] = first;
        c.expectedPrimaryPolicyHash = keccak256("forbidden primary");
        vm.expectRevert(abi.encodeWithSelector(Inventory.InvalidInventory.selector));
        inventory.registerInventory(c, ids);
        c.expectedPrimaryPolicyHash = 0;
        c.secondaryConsignment = false;
        vm.expectRevert(abi.encodeWithSelector(Inventory.InvalidInventory.selector));
        inventory.registerInventory(c, ids);
        c.secondaryConsignment = true;
        bytes32 id = inventory.registerInventory(c, ids);
        PT.SaleCustodyGrant memory g = _grant(id, first);
        PT.SaleCustodyGrant memory wrong = g;
        wrong.owner = address(customer);
        bytes memory sig = _wrapped(_digest(wrong));
        vm.expectRevert(abi.encodeWithSelector(Private.CustodyGrantInvalid.selector));
        inventory.depositInventoryCustody(id, wrong, 2, sig);
        g = _grant(id, first);
        sig = _wrapped(_digest(g));
        vm.expectRevert(abi.encodeWithSelector(Private.PrivateSaleUnavailable.selector, id));
        inventory.depositCustody(id, g, 2, sig);
        require(!inventory.digestConsumed(_digest(g)), "old entry cannot consume new grant");
        inventory.depositInventoryCustody(id, g, 2, sig);
        vm.expectRevert(
            abi.encodeWithSelector(Inventory.InventoryTokenUnavailable.selector, id, first)
        );
        inventory.depositInventoryCustody(id, g, 2, sig);
        _deposit(id, ids[1]);
        inventory.openInventory(id);
        bytes32 hash = inventory.inventoryDetails(id).configHash;
        vm.expectRevert(
            abi.encodeWithSelector(Inventory.InventoryTokenUnavailable.selector, id, first)
        );
        inventory.purchaseInventory{ value: 1000 }(id, first, bytes32(uint256(hash) ^ 1));
        _buy(id, first, 1000);
        vm.expectRevert(
            abi.encodeWithSelector(Inventory.InventoryTokenUnavailable.selector, id, first)
        );
        inventory.purchaseInventory{ value: 1000 }(id, first, hash);
        require(
            inventory.inventoryToken(id, first).status == 3
                && inventory.inventoryBuyerPurchases(id, address(customer)) == 1,
            "one-way per-token sale"
        );
    }

    function testRelayedFullGrantRevocationReleasesOnlyOriginalCollectorAndSoldGrantStaysSpent()
        external
    {
        uint256[] memory ids = _delivered(2);
        bytes32 id = inventory.registerInventory(_inventoryConfig(0), ids);
        PT.SaleCustodyGrant memory first = _deposit(id, ids[0]);
        PT.SaleCustodyGrant memory second = _deposit(id, ids[1]);
        inventory.openInventory(id);
        _revoke(first);
        require(
            inventory.digestRevoked(_digest(first))
                && inventory.inventoryToken(id, ids[0]).nftClaim == 2,
            "canonical original revocation stages only unsold token"
        );
        vm.expectRevert(abi.encodeWithSelector(Private.PrivateSaleClaimUnavailable.selector));
        inventory.claimInventoryNft(id, ids[0], address(0xBAD));
        require(
            inventory.retryInventoryNft(id, ids[0]) && core.ownerOf(ids[0]) == address(collector),
            "relayer cannot redirect reclaimed custody"
        );
        _buy(id, ids[1], 1000);
        vm.expectRevert(abi.encodeWithSelector(Private.PrivateSaleUnavailable.selector, id));
        this.revokeForTest(second);
        require(
            inventory.inventoryToken(id, ids[1]).status == 3
                && !inventory.digestRevoked(_digest(second)),
            "purchase spends grant forever"
        );
        bytes32 next = inventory.registerInventory(_inventoryConfig(0), _one(ids[0]));
        bytes memory oldSig = _wrapped(_digest(first));
        vm.expectRevert(abi.encodeWithSelector(Private.CustodyGrantInvalid.selector));
        inventory.depositInventoryCustody(next, first, 2, oldSig);
        _deposit(next, ids[0]);
        inventory.openInventory(next);
    }

    function revokeForTest(PT.SaleCustodyGrant calldata g) external {
        require(msg.sender == address(this));
        _revoke(g);
    }

    function _one(uint256 token) internal pure returns (uint256[] memory a) {
        a = new uint256[](1);
        a[0] = token;
    }

    function testRoyaltyFailureDivertsExactReceiverAndPermissionlessRetrySurvivesPrimaryContestAndModuleIncident()
        external
    {
        (bytes32 id, uint256[] memory ids) = _opened(1, 0);
        (address receiver, uint256 amount,,) = inventory.inventoryRoyaltyQuote(id, ids[0]);
        uint256 beforeBalance = receiver.balance;
        calls.expectCall(receiver, amount, bytes(""), uint64(2));
        calls.mockCallRevert(
            receiver, amount, bytes(""), abi.encodeWithSignature("Error(string)", "reject royalty")
        );
        _buy(id, ids[0], 1000);
        require(
            core.ownerOf(ids[0]) == address(customer)
                && inventory.creditBreakdown(id, receiver).royalty == amount
                && inventory.totalLiabilities() == 1000 && receiver.balance == beforeBalance,
            "bounded royalty failure cannot stop secondary delivery"
        );
        calls.clearMockedCalls();
        platform.contest(3);
        _status(address(inventory), ModuleRegistryStatus.INCIDENT_REVOKED);
        require(
            inventory.retryInventoryRoyalty(id, receiver)
                && receiver.balance == beforeBalance + amount
                && inventory.creditBreakdown(id, receiver).royalty == 0
                && inventory.totalLiabilities() == 1000 - amount,
            "exact saved receiver retry independent of current primary admission"
        );
        vm.expectRevert(abi.encodeWithSelector(Private.PrivateSaleClaimUnavailable.selector));
        inventory.retryInventoryRoyalty(id, receiver);
        (address historical, uint256 paid,,) = inventory.inventoryRoyaltyQuote(id, ids[0]);
        require(historical == receiver && paid == amount, "immutable per-token royalty snapshot");
    }

    function testRejectedBuyerGetsOwnPullNftAndReentryCannotBuyAgainOrSpendAnotherSale() external {
        (bytes32 id, uint256[] memory ids) = _opened(2, 0);
        InventoryBuyerReceiver who = new InventoryBuyerReceiver();
        vm.deal(address(who), 3000);
        bytes32 hash = inventory.inventoryDetails(id).configHash;
        bytes memory buy = abi.encodeCall(inventory.purchaseInventory, (id, ids[0], hash));
        who.execute(address(inventory), 1000, buy);
        require(
            inventory.inventoryToken(id, ids[0]).nftClaim == 1
                && core.ownerOf(ids[0]) == address(inventory),
            "receiver failure records buyer claim"
        );
        who.accepts();
        who.setup(
            address(inventory),
            1000,
            abi.encodeCall(inventory.purchaseInventory, (id, ids[1], hash))
        );
        require(
            inventory.retryInventoryNft(id, ids[0]) && !who.callbackOk()
                && core.ownerOf(ids[0]) == address(who)
                && inventory.inventoryToken(id, ids[1]).status == 2,
            "guarded claim callback cannot enter purchase"
        );
        inventory.cancelSale(id);
        require(
            inventory.inventoryToken(id, ids[0]).status == 3
                && inventory.inventoryToken(id, ids[1]).nftClaim == 2
                && inventory.retryInventoryNft(id, ids[1])
                && core.ownerOf(ids[1]) == address(collector),
            "close never confiscates sold item or unsold owner claim"
        );
    }

    function testRoyaltyReadFailureRollsBackSoldEffectAndByteIdenticalSafePurchaseRetries()
        external
    {
        (bytes32 id, uint256[] memory ids) = _opened(1, 0);
        bytes32 hash = inventory.inventoryDetails(id).configHash;
        bytes memory data = abi.encodeCall(inventory.purchaseInventory, (id, ids[0], hash));
        uint256 nonce = customer.nonce();
        bytes32 digest = customer.getTransactionHash(
            address(inventory), 1027, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory signatures = safeThresholdSignature(customerKeys, digest);
        bytes memory serialized = abi.encodeCall(
            OfficialSafe.execTransaction,
            (
                address(inventory),
                1027,
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
        uint256 oldBalance = address(customer).balance;
        bytes memory quote =
            abi.encodeWithSignature("royaltyInfo(uint256,uint256)", ids[0], uint256(1000));
        calls.expectCall(address(core), quote, uint64(2));
        calls.mockCallRevert(
            address(core), quote, abi.encodeWithSignature("Error(string)", "quote unavailable")
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeSerialized(serialized);
        require(
            customer.nonce() == nonce && address(customer).balance == oldBalance
                && address(inventory).balance == 0 && inventory.totalLiabilities() == 0
                && inventory.inventoryToken(id, ids[0]).status == 2
                && inventory.inventoryBuyerPurchases(id, address(customer)) == 0
                && core.ownerOf(ids[0]) == address(inventory),
            "failed quote after sold effects rolls back full signed transaction; not a post-payment claim"
        );
        calls.clearMockedCalls();
        this.executeSerialized(serialized);
        require(
            customer.nonce() == nonce + 1 && core.ownerOf(ids[0]) == address(customer)
                && inventory.refundableBalance(id, address(customer)) == 27,
            "byte-identical Safe calldata/signatures succeeds after source recovery"
        );
    }

    function executeSerialized(bytes calldata data) external {
        require(msg.sender == address(this));
        (bool ok, bytes memory out) = address(customer).call(data);
        if (!ok) assembly ("memory-safe") { revert(add(out, 32), mload(out)) }
        require(abi.decode(out, (bool)), "Safe operation completed");
    }

    function testBuyerCapAndPausedExpiredInventoryKeepPerpetualClaimsLive() external {
        (bytes32 id, uint256[] memory ids) = _opened(2, 1);
        _buy(id, ids[0], 1027);
        bytes32 hash = inventory.inventoryDetails(id).configHash;
        vm.prank(address(customer));
        vm.expectRevert(
            abi.encodeWithSelector(Inventory.InventoryBuyerCap.selector, id, address(customer))
        );
        inventory.purchaseInventory{ value: 1000 }(id, ids[1], hash);
        _grantAuctionRole(keccak256("ROLE_PAUSE_GUARDIAN"), address(this));
        inventory.pauseSale(id, keccak256("pause inventory"));
        vm.expectRevert(abi.encodeWithSelector(Private.PrivateSalePaused.selector, id));
        inventory.purchaseInventory{ value: 1000 }(id, ids[1], hash);
        vm.warp(uint256(inventory.inventoryDetails(id).config.deadline) + 1);
        inventory.expireSale(id);
        _status(address(inventory), ModuleRegistryStatus.INCIDENT_REVOKED);
        require(
            inventory.retryInventoryNft(id, ids[1]) && core.ownerOf(ids[1]) == address(collector),
            "paused retired provider cannot strand unsold custody"
        );
        require(
            executeSafe(
                customer,
                customerKeys,
                address(inventory),
                0,
                abi.encodeCall(inventory.claimRefund, (id, address(customer))),
                0
            )
        );
        require(
            inventory.refundableBalance(id, address(customer)) == 0
                && inventory.inventoryDetails(id).status == 5,
            "signed expiry and buyer pull credit independent of admission"
        );
    }
}
