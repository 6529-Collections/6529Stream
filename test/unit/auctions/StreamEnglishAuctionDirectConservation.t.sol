// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/auctions/StreamEnglishAuctionHouse.sol";
import {
    StreamDirectPrimarySaleTypes as D
} from "../../../smart-contracts/interfaces/stream/revenue/StreamDirectPrimarySaleTypes.sol";
import "../../../smart-contracts/interfaces/stream/metadata/IStreamDirectPrimaryConservationFloor.sol";
import "../../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";
import "../../../smart-contracts/vendor/openzeppelin/ERC721.sol";

interface AuctionDirectVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }

    function addr(uint256 key) external returns (address);
    function sign(uint256 key, bytes32 digest) external returns (uint8, bytes32, bytes32);
    function deal(address account, uint256 balance) external;
    function prank(address caller) external;
    function warp(uint256 timestamp) external;
    function expectRevert() external;
    function expectRevert(bytes calldata data) external;
    function expectCall(address target, bytes calldata data) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

/// @dev Typed lifecycle boundary. Its setters are fixture inputs, not governance execution evidence.
contract AuctionDirectRegistryBoundary is ERC165 {
    mapping(address => StreamModuleRecord) private _records;

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamModuleRegistry).interfaceId || super.supportsInterface(id);
    }

    function register(address house) external {
        _records[house] = StreamModuleRecord(
            ModuleRegistryStatus.ACTIVE,
            D.MODULE_TYPE,
            D.MODULE_VERSION,
            type(IStreamDirectPrimarySaleReceipt).interfaceId,
            1_000_000,
            house.codehash,
            keccak256("auction fixture deployment"),
            keccak256("auction fixture manifest"),
            "urn:fixture:direct-auction",
            uint64(block.timestamp),
            uint64(block.timestamp),
            1
        );
    }

    function setStatus(address house, ModuleRegistryStatus status) external {
        StreamModuleRecord storage r = _records[house];
        r.status = status;
        r.statusUpdatedAt = uint64(block.timestamp);
        ++r.revision;
    }

    function moduleRecord(address target) external view returns (StreamModuleRecord memory) {
        return _records[target];
    }

    function isModuleEligible(address target, bytes32 kind, bytes4 id)
        external
        view
        returns (bool)
    {
        StreamModuleRecord storage r = _records[target];
        return r.status == ModuleRegistryStatus.ACTIVE && r.moduleType == kind
            && r.interfaceId == id && r.runtimeCodeHash == target.codehash;
    }
}

/// @dev Actual vendored ERC721 transfers/callbacks, with typed Core pointer and mint boundaries.
contract AuctionDirectCoreBoundary is ERC721 {
    address public immutable moduleRegistry;
    address public artists;
    address public manager;
    address public floor;
    uint256 public minted;
    mapping(uint256 => uint256) public tokenCollection;

    constructor(address registry) ERC721("Auction boundary", "ADB") {
        moduleRegistry = registry;
    }

    function configure(address artists_, address manager_, address floor_) external {
        artists = artists_;
        manager = manager_;
        floor = floor_;
    }

    function conservationFloor() external view returns (address, bytes32) {
        return (floor, floor.codehash);
    }

    function getSatellitePointer(bytes32 kind)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        address target = kind == keccak256("ARTIST_REGISTRY") ? artists : moduleRegistry;
        return (
            target,
            target.codehash,
            true,
            kind,
            kind == keccak256("ARTIST_REGISTRY")
                ? type(IStreamArtistAttribution).interfaceId
                : type(IStreamModuleRegistry).interfaceId,
            moduleRegistry,
            1,
            keccak256("pointer manifest"),
            keccak256("pointer deployment"),
            1
        );
    }

    function mintAuction(address recipient, uint256 collectionId) external returns (uint256 id) {
        require(msg.sender == manager, "fixture manager");
        id = ++minted;
        tokenCollection[id] = collectionId;
        _safeMint(recipient, id);
    }
}

/// @dev Exact Manager call/return ABI; actual Manager/Ledger policy accounting is separate coverage.
contract AuctionDirectManagerBoundary {
    address public immutable core;
    address public immutable moduleRegistry;
    uint256 public nextOperationNonce;
    bool public executable = true;
    bool public wrongOperationId;
    mapping(bytes32 => bool) public isOperationRootUsed;
    mapping(bytes32 => bool) public isAuthorizationUsed;

    constructor(address core_, address registry) {
        core = core_;
        moduleRegistry = registry;
    }

    function setExecutable(bool value) external {
        executable = value;
    }

    function setWrongOperationId(bool value) external {
        wrongOperationId = value;
    }

    function previewSingleStepMintOperation(
        IStreamMintManager.MintBatch calldata batch,
        bytes calldata
    ) public view returns (bytes32 root, bytes32[] memory ids) {
        require(executable, "fixture phase disabled");
        root = keccak256(abi.encode("fixture actual mint root", nextOperationNonce, batch));
        ids = new bytes32[](1);
        ids[0] = keccak256(abi.encode("fixture actual operation", root));
    }

    function executeSingleStepMint(IStreamMintManager.MintBatch calldata batch, bytes calldata data)
        external
        returns (uint256[] memory tokens, bytes32 root, bytes32[] memory ids)
    {
        (root, ids) = previewSingleStepMintOperation(batch, data);
        ++nextOperationNonce;
        isOperationRootUsed[root] = true;
        isAuthorizationUsed[batch.authorizationId] = true;
        tokens = new uint256[](1);
        tokens[0] = AuctionDirectCoreBoundary(core)
            .mintAuction(batch.initialRecipients[0], batch.collectionId);
        if (wrongOperationId) ids[0] = keccak256("wrong actual operation");
    }
}

/// @dev Typed Artist attribution/NONE election; signatures remain genuine test-key ECDSA signatures.
contract AuctionDirectArtistBoundary is ERC165 {
    address public immutable core;
    address public artist;

    constructor(address core_, address artist_) {
        core = core_;
        artist = artist_;
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamArtistAttribution).interfaceId || super.supportsInterface(id);
    }

    function setArtist(address artist_) external {
        artist = artist_;
    }

    function acceptedArtist(uint256) external view returns (address) {
        return artist;
    }

    function saleConsentScope(uint256) external pure returns (uint8) {
        return 0;
    }

    function attribution(uint256)
        external
        view
        returns (IStreamCollectionArtistRegistry.Attribution memory)
    {
        return IStreamCollectionArtistRegistry.Attribution(
            artist,
            artist,
            keccak256("identity"),
            keccak256("nomination"),
            keccak256("acceptance"),
            1,
            1
        );
    }
}

contract AuctionDirectAssetBoundary { }

contract AuctionDirectWalletBoundary {
    bool public rejecting;

    function setRejecting(bool value) external {
        rejecting = value;
    }

    receive() external payable {
        require(!rejecting, "fixture wallet rejects");
    }
}

/// @dev Fixed profile/factory boundary, not production split deployment evidence.
contract AuctionDirectFactoryBoundary {
    address public immutable assetPolicyRegistry;
    address public immutable wallet;
    address public immutable governanceAuthority = address(0x6529);

    constructor(address asset, address wallet_) {
        assetPolicyRegistry = asset;
        wallet = wallet_;
    }

    function walletFor(bytes32) external view returns (address) {
        return wallet;
    }

    function splitWalletExists(bytes32) external pure returns (bool) {
        return true;
    }

    function splitWalletRuntimeCodeHash() external view returns (bytes32) {
        return wallet.codehash;
    }

    function gasParameter(bytes32) external pure returns (uint256) {
        return 100_000;
    }
}

contract AuctionDirectEscrowBoundary {
    address public immutable splitFactory;
    address public immutable assetPolicyRegistry;
    bytes32 public immutable factoryCodeHash;
    bytes32 public immutable walletCodeHash;
    address public immutable governanceAuthority = address(0x6529);
    uint256 public owed;

    constructor(AuctionDirectFactoryBoundary factory) {
        splitFactory = address(factory);
        assetPolicyRegistry = factory.assetPolicyRegistry();
        factoryCodeHash = address(factory).codehash;
        walletCodeHash = factory.splitWalletRuntimeCodeHash();
    }

    function escrowOwed(bytes32, bytes32, address, address) external view returns (uint256) {
        return owed;
    }

    function creditNative(bytes32, bytes32, address, bool) external payable {
        owed += msg.value;
    }
}

contract AuctionDirectResolverBoundary {
    address public immutable core;
    address public immutable splitFactory;
    address public immutable artistRegistry;
    bytes32 public constant PROFILE = keccak256("direct auction profile");

    constructor(address core_, address factory, address artists) {
        core = core_;
        splitFactory = factory;
        artistRegistry = artists;
    }

    function isStreamRevenueResolver() external pure returns (bool) {
        return true;
    }

    function resolvePrimaryAssignment(uint256 cid, uint256, bytes32)
        external
        pure
        returns (IStreamRevenueResolver.ResolvedPrimaryAssignment memory)
    {
        return IStreamRevenueResolver.ResolvedPrimaryAssignment(
            true, 1, cid, 1, PROFILE, 0, 0, keccak256("original assignment"), false
        );
    }
}

/// @dev Typed floor boundary. It verifies local evidence and completed NFT delivery at the late call.
///      Documentary conservation evidence and production floor admission are separate test scopes.
contract AuctionDirectFloorBoundary is ERC165 {
    error FloorDenied();
    bool public denying;
    uint256 public calls;
    bytes32 public lastHash;

    function setDenying(bool value) external {
        denying = value;
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamDirectPrimaryConservationFloor).interfaceId
            || super.supportsInterface(id);
    }

    /// @dev Boundary-test allowance only; not a production gas-floor measurement.
    function gasParameter(bytes32) external pure returns (uint256) {
        return 800_000;
    }

    function recordDirectPrimarySale(bytes32 authorizationId) external returns (bytes32 hash) {
        if (denying) revert FloorDenied();
        IStreamDirectPrimarySaleReceipt source = IStreamDirectPrimarySaleReceipt(msg.sender);
        D.Receipt memory r = source.directPrimarySaleReceipt(authorizationId);
        D.Bindings memory b = source.directPrimaryBindings();
        require(r.amount != 0 && r.authorizationDigest != 0, "genuine locally stored paid receipt");
        require(
            AuctionDirectCoreBoundary(b.core).ownerOf(r.tokenId) == r.beneficiary,
            "floor called after NFT delivery"
        );
        hash = source.directPrimarySaleReceiptHash(authorizationId);
        require(hash != 0, "receipt hash available in floor callback");
        ++calls;
        lastHash = hash;
    }
}

contract AuctionDirectReceiverBoundary is IERC721Receiver {
    StreamEnglishAuctionHouse public immutable house;
    bytes32 public immutable authorizationId;
    bool public reentered;
    bytes32 public receiptDuringDelivery;

    constructor(StreamEnglishAuctionHouse house_, bytes32 id) {
        house = house_;
        authorizationId = id;
    }

    function onERC721Received(address, address, uint256 tokenId, bytes calldata)
        external
        returns (bytes4)
    {
        receiptDuringDelivery = house.directPrimarySaleReceiptHash(authorizationId);
        (reentered,) = address(house).call(abi.encodeCall(house.settle, (tokenId)));
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice Production auction/receipt-helper with typed external boundaries and actual ERC721 custody.
contract StreamEnglishAuctionDirectConservationTest {
    AuctionDirectVm private constant vm =
        AuctionDirectVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 private constant ARTIST_KEY = 0xA771;
    uint256 private constant PLATFORM_KEY = 0xF17;
    address private constant BUYER = address(0xB0A);
    address private constant NEXT_BUYER = address(0xB0B);
    address private constant RECIPIENT = address(0xD311);
    uint256 private constant COLLECTION = 7;
    bytes32 private constant PHASE = keccak256("original auction phase");
    bytes32 private constant MINT_POLICY = keccak256("original signed mint policy");

    AuctionDirectRegistryBoundary private registry;
    AuctionDirectCoreBoundary private core;
    AuctionDirectManagerBoundary private manager;
    AuctionDirectArtistBoundary private artists;
    AuctionDirectWalletBoundary private wallet;
    AuctionDirectEscrowBoundary private escrow;
    AuctionDirectFloorBoundary private floor;
    StreamEnglishAuctionHouse private house;
    address private artist;
    bytes32 private profile;

    function setUp() public {
        vm.warp(1000);
        artist = vm.addr(ARTIST_KEY);
        registry = new AuctionDirectRegistryBoundary();
        core = new AuctionDirectCoreBoundary(address(registry));
        manager = new AuctionDirectManagerBoundary(address(core), address(registry));
        artists = new AuctionDirectArtistBoundary(address(core), artist);
        floor = new AuctionDirectFloorBoundary();
        core.configure(address(artists), address(manager), address(floor));
        wallet = new AuctionDirectWalletBoundary();
        AuctionDirectFactoryBoundary factory = new AuctionDirectFactoryBoundary(
            address(new AuctionDirectAssetBoundary()), address(wallet)
        );
        escrow = new AuctionDirectEscrowBoundary(factory);
        AuctionDirectResolverBoundary resolver =
            new AuctionDirectResolverBoundary(address(core), address(factory), address(artists));
        profile = resolver.PROFILE();
        house = new StreamEnglishAuctionHouse(
            IStreamCore(address(core)),
            IStreamMintManager(address(manager)),
            IStreamRevenueResolver(address(resolver)),
            vm.addr(PLATFORM_KEY),
            IStreamArtistAttribution(address(artists)),
            IStreamRevenueEscrow(address(escrow))
        );
        registry.register(address(house));
        vm.deal(BUYER, 10 ether);
        vm.deal(NEXT_BUYER, 10 ether);
    }

    function testCreationRetainsMintButDoesNotInventPaidReceipt() public {
        IStreamEnglishAuctionHouse.AuctionAuthorization memory a = _authorization(1);
        uint256 token = _create(a);
        bytes32 id = house.authorizationId(a.artist, a.nonce);
        D.Receipt memory empty;
        require(core.ownerOf(token) == address(house) && core.minted() == 1, "auction custody");
        require(manager.nextOperationNonce() == 1, "one creation mint");
        require(
            keccak256(abi.encode(house.directPrimarySaleReceipt(id)))
                    == keccak256(abi.encode(empty)) && house.directPrimarySaleReceiptHash(id) == 0
                && floor.calls() == 0,
            "unpaid tuple remains zero"
        );
        require(house.supportsInterface(type(IStreamEnglishAuctionHouse).interfaceId), "old ABI");
        require(
            house.supportsInterface(type(IStreamDirectPrimarySaleReceipt).interfaceId), "new ABI"
        );
    }

    function testPaidReceiptKeepsOriginalDomainAndEveryActualOutcomeField() public {
        IStreamEnglishAuctionHouse.AuctionAuthorization memory a = _authorization(2);
        uint256 token = _create(a);
        bytes32 id = house.authorizationId(a.artist, a.nonce);
        // setUp fixes creation at 1000; do not rematerialize TIMESTAMP after vm.warp.
        uint64 createdAt = 1000;
        bytes32 root = house.auction(token).operationRoot;
        _bid(BUYER, token, RECIPIENT, 1 ether);
        vm.warp(a.endTime);
        vm.recordLogs();
        house.settle(token);
        D.Receipt memory expected = _expected(a, token, root, createdAt, false, BUYER, RECIPIENT);
        _assertReceipt(id, expected);
        _assertReceiptEvent(id, expected, vm.getRecordedLogs());
        require(
            core.ownerOf(token) == RECIPIENT && address(wallet).balance == 1 ether,
            "actual paid outcome"
        );
        require(house.totalBidEscrow() == 0 && house.totalNativeProceeds() == 1 ether, "accounting");
        require(
            floor.calls() == 1 && manager.nextOperationNonce() == 1, "one floor call, no remint"
        );
        vm.expectRevert();
        house.settle(token);
        require(floor.calls() == 1, "no receipt replay");
    }

    function testLateFloorFailureRollsBackPaymentDeliveryReceiptAndRetriesExactlyOnce() public {
        IStreamEnglishAuctionHouse.AuctionAuthorization memory a = _authorization(3);
        uint256 token = _create(a);
        bytes32 id = house.authorizationId(a.artist, a.nonce);
        _bid(BUYER, token, RECIPIENT, 1 ether);
        floor.setDenying(true);
        vm.warp(a.endTime);
        vm.expectCall(
            address(floor),
            abi.encodeCall(IStreamDirectPrimaryConservationFloor.recordDirectPrimarySale, (id))
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamDirectPrimarySaleFloorCall.DirectSaleFloorCallFailed.selector,
                address(floor),
                AuctionDirectFloorBoundary.FloorDenied.selector
            )
        );
        house.settle(token);
        _assertUnsettled(token, id);
        floor.setDenying(false);
        house.settle(token);
        require(
            core.ownerOf(token) == RECIPIENT && address(wallet).balance == 1 ether,
            "same settlement retry"
        );
        require(floor.calls() == 1 && house.directPrimarySaleReceiptHash(id) != 0, "one receipt");
        require(manager.nextOperationNonce() == 1, "original creation retained");
    }

    function testDeprecatedOriginalAuctionUsesCreationAdmissionWithoutCurrentPhaseOrArtist()
        public
    {
        IStreamEnglishAuctionHouse.AuctionAuthorization memory a = _authorization(4);
        uint256 token = _create(a);
        bytes32 id = house.authorizationId(a.artist, a.nonce);
        _bid(BUYER, token, RECIPIENT, 1 ether);
        vm.warp(block.timestamp + 1);
        registry.setStatus(address(house), ModuleRegistryStatus.DEPRECATED);
        manager.setExecutable(false);
        artists.setArtist(address(0xBAD));
        house.setPaused(true);
        vm.warp(a.endTime);
        house.settle(token);
        D.Receipt memory receipt = house.directPrimarySaleReceipt(id);
        require(receipt.createdAt == 1000 && receipt.registryRevision == 1, "original admission");
        require(
            receipt.authorizationDigest == house.authorizationDigest(a), "original signed digest"
        );
        require(
            receipt.boundMintPolicyHash == MINT_POLICY && floor.calls() == 1, "historical phase"
        );
        require(
            core.ownerOf(token) == RECIPIENT && manager.nextOperationNonce() == 1, "accrued exit"
        );
    }

    function testSameTimestampDeprecationDoesNotInventStrictCreationPrecedence() public {
        IStreamEnglishAuctionHouse.AuctionAuthorization memory a = _authorization(5);
        uint256 token = _create(a);
        bytes32 id = house.authorizationId(a.artist, a.nonce);
        _bid(BUYER, token, RECIPIENT, 1 ether);
        registry.setStatus(address(house), ModuleRegistryStatus.DEPRECATED);
        vm.warp(a.endTime);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamDirectPrimaryAdmission.DirectPrimaryNotAdmitted.selector, address(house)
            )
        );
        house.settle(token);
        _assertUnsettled(token, id);
    }

    function testIncidentRevocationRejectsPaidExitWithoutLosingWinnerEscrow() public {
        IStreamEnglishAuctionHouse.AuctionAuthorization memory a = _authorization(6);
        uint256 token = _create(a);
        bytes32 id = house.authorizationId(a.artist, a.nonce);
        _bid(BUYER, token, RECIPIENT, 1 ether);
        vm.warp(block.timestamp + 1);
        registry.setStatus(address(house), ModuleRegistryStatus.INCIDENT_REVOKED);
        vm.warp(a.endTime);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamDirectPrimaryAdmission.DirectPrimaryNotAdmitted.selector, address(house)
            )
        );
        house.settle(token);
        _assertUnsettled(token, id);
    }

    function testEscrowOutcomeAndRecipientChangeAreTheActualPaidFacts() public {
        IStreamEnglishAuctionHouse.AuctionAuthorization memory a = _authorization(7);
        uint256 token = _create(a);
        bytes32 id = house.authorizationId(a.artist, a.nonce);
        // setUp fixes creation at 1000; do not rematerialize TIMESTAMP after vm.warp.
        uint64 createdAt = 1000;
        bytes32 root = house.auction(token).operationRoot;
        _bid(BUYER, token, BUYER, 1 ether);
        vm.prank(BUYER);
        house.setDeliveryRecipient(token, RECIPIENT);
        wallet.setRejecting(true);
        vm.warp(a.endTime);
        house.settle(token);
        _assertReceipt(id, _expected(a, token, root, createdAt, true, BUYER, RECIPIENT));
        require(
            escrow.owed() == 1 ether && address(escrow).balance == 1 ether, "exact escrow funding"
        );
        require(address(wallet).balance == 0 && address(house).balance == 0, "no duplicate payment");
    }

    function testReceiptIsPublishedAfterDeliveryAndReceiverCannotReenter() public {
        IStreamEnglishAuctionHouse.AuctionAuthorization memory a = _authorization(8);
        uint256 token = _create(a);
        bytes32 id = house.authorizationId(a.artist, a.nonce);
        AuctionDirectReceiverBoundary receiver = new AuctionDirectReceiverBoundary(house, id);
        _bid(BUYER, token, address(receiver), 1 ether);
        vm.warp(a.endTime);
        house.settle(token);
        require(
            !receiver.reentered() && receiver.receiptDuringDelivery() == 0,
            "guard and publication order"
        );
        require(
            house.directPrimarySaleReceiptHash(id) != 0 && floor.calls() == 1,
            "published after delivery"
        );
    }

    function testNoBidCancellationAndRefundDoNotRequireFloorOrCreatePaidReceipt() public {
        IStreamEnglishAuctionHouse.AuctionAuthorization memory a = _authorization(9);
        uint256 cancelled = _create(a);
        bytes32 cancelledId = house.authorizationId(a.artist, a.nonce);
        a = _authorization(10);
        uint256 unsold = _create(a);
        bytes32 unsoldId = house.authorizationId(a.artist, a.nonce);
        a = _authorization(11);
        uint256 withBids = _create(a);
        bytes32 bidId = house.authorizationId(a.artist, a.nonce);
        _bid(BUYER, withBids, BUYER, 1 ether);
        _bid(NEXT_BUYER, withBids, NEXT_BUYER, 2 ether);
        floor.setDenying(true);
        registry.setStatus(address(house), ModuleRegistryStatus.INCIDENT_REVOKED);
        house.setPaused(true);
        vm.prank(artist);
        house.cancel(cancelled);
        vm.prank(BUYER);
        house.withdrawRefund(payable(BUYER));
        vm.warp(a.endTime);
        house.settle(unsold);
        require(
            core.ownerOf(cancelled) == artist && core.ownerOf(unsold) == artist, "unpaid NFT exits"
        );
        require(BUYER.balance == 10 ether && house.totalRefundOwed() == 0, "refund exit");
        require(
            house.totalBidEscrow() == 2 ether && address(house).balance == 2 ether,
            "winner funds retained"
        );
        require(
            house.directPrimarySaleReceiptHash(cancelledId) == 0
                && house.directPrimarySaleReceiptHash(unsoldId) == 0
                && house.directPrimarySaleReceiptHash(bidId) == 0 && floor.calls() == 0,
            "no invented paid receipt"
        );
    }

    function testNewAuctionRequiresActiveAdmissionBeforeMintOrNonceConsumption() public {
        registry.setStatus(address(house), ModuleRegistryStatus.DEPRECATED);
        IStreamEnglishAuctionHouse.AuctionAuthorization memory a = _authorization(12);
        (bytes memory platformSignature, bytes memory artistSignature) = _sign(a);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamDirectPrimaryAdmission.DirectPrimaryNotAdmitted.selector, address(house)
            )
        );
        house.createAuction(a, bytes("auction artwork"), platformSignature, artistSignature);
        require(core.minted() == 0 && manager.nextOperationNonce() == 0, "no admitted mint");
        require(!house.authorizationUsed(artist, a.nonce), "nonce preserved");
    }

    function testMismatchedManagerOperationIdCannotInstallAuctionOrigin() public {
        manager.setWrongOperationId(true);
        IStreamEnglishAuctionHouse.AuctionAuthorization memory a = _authorization(13);
        (bytes memory platformSignature, bytes memory artistSignature) = _sign(a);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamEnglishAuctionHouse.AuctionMintResultInvalid.selector)
        );
        house.createAuction(a, bytes("auction artwork"), platformSignature, artistSignature);
        require(core.minted() == 0 && manager.nextOperationNonce() == 0, "mint rollback");
        require(!house.authorizationUsed(artist, a.nonce), "nonce rollback");
        require(
            house.directPrimarySaleReceiptHash(house.authorizationId(artist, a.nonce)) == 0,
            "no receipt"
        );
    }

    function _authorization(uint256 nonce)
        private
        view
        returns (IStreamEnglishAuctionHouse.AuctionAuthorization memory a)
    {
        (bytes32 policy,,) = house.primaryPolicy(COLLECTION);
        a = IStreamEnglishAuctionHouse.AuctionAuthorization(
            COLLECTION,
            PHASE,
            artist,
            profile,
            policy,
            keccak256(bytes("auction artwork")),
            keccak256(abi.encode("original commitment", nonce)),
            MINT_POLICY,
            1 ether,
            uint64(block.timestamp),
            uint64(block.timestamp + 100),
            0,
            500,
            bytes32(nonce),
            uint64(block.timestamp + 100),
            house.signerEpoch()
        );
    }

    function _create(IStreamEnglishAuctionHouse.AuctionAuthorization memory a)
        private
        returns (uint256)
    {
        (bytes memory platformSignature, bytes memory artistSignature) = _sign(a);
        return house.createAuction(a, bytes("auction artwork"), platformSignature, artistSignature);
    }

    function _sign(IStreamEnglishAuctionHouse.AuctionAuthorization memory a)
        private
        returns (bytes memory platformSignature, bytes memory artistSignature)
    {
        bytes32 digest = house.authorizationDigest(a);
        (uint8 pv, bytes32 pr, bytes32 ps) = vm.sign(PLATFORM_KEY, digest);
        (uint8 av, bytes32 ar, bytes32 as_) = vm.sign(ARTIST_KEY, digest);
        return (abi.encodePacked(pr, ps, pv), abi.encodePacked(ar, as_, av));
    }

    function _bid(address buyer, uint256 token, address recipient, uint256 amount) private {
        vm.prank(buyer);
        house.bid{ value: amount }(token, recipient);
    }

    function _expected(
        IStreamEnglishAuctionHouse.AuctionAuthorization memory a,
        uint256 token,
        bytes32 root,
        uint64 createdAt,
        bool escrowed,
        address payer,
        address beneficiary
    ) private view returns (D.Receipt memory r) {
        r.authorizationDigest = house.authorizationDigest(a);
        r.collectionId = COLLECTION;
        r.tokenId = token;
        r.operationRoot = root;
        r.operationId = keccak256(abi.encode("fixture actual operation", root));
        r.boundMintPolicyHash = MINT_POLICY;
        r.expectedPrimaryPolicyHash = a.expectedPrimaryPolicyHash;
        r.profileId = profile;
        r.wallet = address(wallet);
        r.createdAt = createdAt;
        r.escrowed = escrowed;
        r.payer = payer;
        r.registryRevision = 1;
        r.beneficiary = beneficiary;
        r.asset = address(0);
        r.amount = 1 ether;
    }

    function _assertReceipt(bytes32 id, D.Receipt memory expected) private view {
        require(
            keccak256(abi.encode(house.directPrimarySaleReceipt(id)))
                == keccak256(abi.encode(expected)),
            "all sixteen receipt words"
        );
        D.Bindings memory bindings = house.directPrimaryBindings();
        require(
            bindings.core == address(core) && bindings.coreCodeHash == address(core).codehash
                && bindings.mintManager == address(manager)
                && bindings.mintManagerCodeHash == address(manager).codehash
                && bindings.deploymentChainId == block.chainid
                && bindings.productKind == keccak256("6529STREAM_DIRECT_ENGLISH_AUCTION_V1"),
            "immutable original deployment"
        );
        bytes32 expectedHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_DIRECT_PRIMARY_SALE_RECEIPT_V1"),
                block.chainid,
                address(core),
                address(house),
                keccak256("6529STREAM_DIRECT_ENGLISH_AUCTION_V1"),
                id,
                expected
            )
        );
        require(
            house.directPrimarySaleReceiptHash(id) == expectedHash
                && floor.lastHash() == expectedHash,
            "independent original DIRECT hash"
        );
    }

    function _assertReceiptEvent(
        bytes32 id,
        D.Receipt memory expected,
        AuctionDirectVm.Log[] memory logs
    ) private view {
        bytes32 topic = keccak256(
            "DirectPrimarySaleRecorded(bytes32,bytes32,uint256,(bytes32,uint256,uint256,bytes32,bytes32,bytes32,bytes32,bytes32,address,uint64,bool,address,uint64,address,address,uint256),uint16)"
        );
        bool found;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(house) || logs[i].topics.length == 0
                    || logs[i].topics[0] != topic
            ) continue;
            require(
                !found && logs[i].topics.length == 4 && logs[i].topics[1] == id, "one receipt event"
            );
            require(
                logs[i].topics[2] == house.directPrimarySaleReceiptHash(id)
                    && logs[i].topics[3] == bytes32(expected.tokenId),
                "event identity"
            );
            (D.Receipt memory actual, uint16 schema) = abi.decode(logs[i].data, (D.Receipt, uint16));
            require(
                schema == 1 && keccak256(abi.encode(actual)) == keccak256(abi.encode(expected)),
                "full event facts"
            );
            found = true;
        }
        require(found, "observable paid receipt");
    }

    function _assertUnsettled(uint256 token, bytes32 id) private view {
        require(
            !house.auction(token).settled && core.ownerOf(token) == address(house),
            "NFT and terminal state rollback"
        );
        require(
            house.totalBidEscrow() == 1 ether && address(house).balance == 1 ether,
            "winner escrow preserved"
        );
        require(
            house.totalNativeProceeds() == 0 && house.nativeProceeds(profile) == 0,
            "proceeds rollback"
        );
        require(address(wallet).balance == 0 && escrow.owed() == 0, "payment rollback");
        require(
            house.directPrimarySaleReceiptHash(id) == 0 && floor.calls() == 0, "receipt rollback"
        );
    }
}
