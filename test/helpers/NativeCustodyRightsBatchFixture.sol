// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./NativeCustodyAuctionFixture.sol";
import "./NativeRightsAuctionFixture.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistTemplateEconomicsAuthority.sol";
import {
    StreamArtistCollaboratorTypes as BC
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";
import {
    IStreamDynamicPrimaryTemplates as BD
} from "../../smart-contracts/interfaces/stream/revenue/IStreamDynamicPrimaryTemplates.sol";

/// @dev Typed Artist only; exact scoped approval and real current token identity stay distinct.
contract CustodyRightsBatchArtist is NativeRightsAuctionArtist {
    mapping(bytes32 => bool) private scoped;
    BC.Row[] private rows;
    mapping(bytes32 => address) private payouts;
    address public lateTrigger;
    constructor(address c, address m) NativeRightsAuctionArtist(c, m) { }

    function supportsInterface(bytes4 id) public pure override returns (bool) {
        return id == type(IStreamArtistTemplateEconomicsAuthority).interfaceId
            || super.supportsInterface(id);
    }

    function approveScope(
        address resolver,
        uint256 collection,
        uint8 scope,
        uint256 id,
        bytes32 hash,
        bool yes
    ) external {
        scoped[keccak256(abi.encode(resolver, collection, scope, id, hash))] = yes;
    }

    function failAfterFunding(address trigger) external {
        lateTrigger = trigger;
    }

    function requireEconomicsConsent(
        uint256 collection,
        bytes32 cls,
        uint8 scope,
        uint256 id,
        bytes32 hash
    ) external view override {
        require(consent, "artist economics");
        if (scope != 1) {
            require(
                cls == keccak256("PRIMARY_SALE")
                    && scoped[keccak256(abi.encode(msg.sender, collection, scope, id, hash))],
                "exact scoped consent"
            );
            require(lateTrigger == address(0) || lateTrigger.balance == 0, "late scoped consent");
        }
    }

    function setRows(BC.Row[] calldata value) external {
        delete rows;
        for (uint256 i; i < value.length; ++i) {
            rows.push(value[i]);
        }
    }

    function setCollaboratorPayout(bytes32 id, address account) external {
        payouts[id] = account;
    }

    function collaboratorCount(uint256 collection, uint64 generation)
        external
        view
        returns (uint256)
    {
        require(collection == 1 && generation == 1);
        return rows.length;
    }

    function collaboratorAt(uint256 collection, uint64 generation, uint256 i)
        external
        view
        returns (BC.Row memory)
    {
        require(collection == 1 && generation == 1);
        return rows[i];
    }

    function collaboratorPayoutAccount(bytes32 id, address account)
        external
        view
        returns (address, bytes32)
    {
        for (uint256 i; i < rows.length; ++i) {
            if (
                rows[i].accepted && rows[i].collaboratorArtistId == id && rows[i].account == account
            ) {
                address p = payouts[id];
                return (p, p == address(0) ? bytes32(0) : keccak256(abi.encode(id, p)));
            }
        }
        return (address(0), 0);
    }
}

abstract contract NativeCustodyRightsBatchFixture is NativeCustodyAuctionFixture {
    CustodyRightsBatchArtist internal scopedArtist;
    bytes32 internal constant COLLAB = keccak256("batch collaborator");

    function _deployAuctionArtist() internal override returns (NativeAuctionArtist) {
        scopedArtist = new CustodyRightsBatchArtist(address(core), address(manager));
        return scopedArtist;
    }

    function setUp() public virtual override {
        super.setUp();
        scopedArtist.setPayout(address(0xA77157));
    }

    function _batchTemplate(uint256 token, uint8 mode)
        internal
        returns (bytes32 tid, bytes32 hash)
    {
        if (mode == 4) {
            BC.Row[] memory rows = new BC.Row[](1);
            rows[0] = BC.Row(
                address(0xC011),
                0,
                keccak256("composer-share"),
                COLLAB,
                keccak256("accepted batch row"),
                true
            );
            scopedArtist.setRows(rows);
            scopedArtist.setCollaboratorPayout(COLLAB, address(0xC0B));
            BD.CollaboratorReference[] memory refs = new BD.CollaboratorReference[](1);
            refs[0] = BD.CollaboratorReference(rows[0].account, rows[0].role, rows[0].shareLabelId);
            bytes32 source = keccak256(
                abi.encode(
                    keccak256("6529STREAM_PRIMARY_COLLABORATOR_SOURCE_V1"),
                    rows[0].account,
                    rows[0].role,
                    rows[0].shareLabelId
                )
            );
            IStreamRevenueResolver.PrimaryTemplateEntry[] memory e =
                new IStreamRevenueResolver.PrimaryTemplateEntry[](3);
            e[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
                address(0), keccak256("COLLECTION_ARTIST"), 100000, keccak256("artist")
            );
            e[1] = IStreamRevenueResolver.PrimaryTemplateEntry(
                address(0), source, 600000, rows[0].shareLabelId
            );
            e[2] = IStreamRevenueResolver.PrimaryTemplateEntry(
                address(0), keccak256("SALE_POSTER"), 300000, keccak256("poster")
            );
            tid = resolver.createDynamicPrimaryTemplate(
                e, keccak256(abi.encode("token dynamic", token)), refs
            );
        } else {
            uint32 share = mode == 2 ? 700000 : 1;
            IStreamRevenueResolver.PrimaryTemplateEntry[] memory e =
                new IStreamRevenueResolver.PrimaryTemplateEntry[](2);
            e[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
                address(0), keccak256("COLLECTION_ARTIST"), share, keccak256("artist")
            );
            e[1] = IStreamRevenueResolver.PrimaryTemplateEntry(
                address(0xFEE), 0, 1000000 - share, keccak256("protocol")
            );
            tid =
                resolver.createPrimaryTemplate(
                e, keccak256(abi.encode("token static", token, mode))
            );
        }
        hash =
        resolver.previewArtistScopedPrimaryTemplateAssignment(1, 2, token, tid, 0, false)
        .assignmentHash;
        scopedArtist.approveScope(address(resolver), 1, 2, token, hash, true);
        require(
            resolver.setPrimaryTemplateAssignment(CLASS, 2, token, tid, 0) == hash,
            "actual scoped template SET"
        );
    }

    function _defaultProfile() internal returns (bytes32 hash) {
        IStreamSplitWallet.SplitEntry[] memory e = new IStreamSplitWallet.SplitEntry[](1);
        e[0] = IStreamSplitWallet.SplitEntry(address(0xD3FA), 1000000, keccak256("artist"));
        (bytes32 p,) = factory.createProfile(e, keccak256("default custody profile"));
        // Existing target-side governance fixture owns this real Resolver; no fabricated action context.
        hash = resolver.setPrimaryProfileAssignment(CLASS, 0, 0, p, 0);
        scopedArtist.approveScope(address(resolver), 1, 0, 0, hash, true);
        resolver.clearPrimaryAssignment(CLASS, 1, 1);
    }

    function _batchAuthorization(bytes32 id, uint8 mode, bytes32 nonce)
        internal
        view
        returns (StreamCustodyRightsTypes.Authorization memory a)
    {
        IStreamNativeEnglishAuction.Auction memory sale = house.auction(id);
        (StreamSaleTemplate.Selection memory selected, bytes32 policy,) = StreamCustodyRightsValidation.selection(
            StreamPrimarySettlementRights.Context(
                resolver, factory, factory.splitWalletRuntimeCodeHash()
            ),
            1,
            sale.tokenId,
            mode,
            address(this)
        );
        a = StreamCustodyRightsTypes.Authorization(
            id,
            sale.configHash,
            keccak256(abi.encode(house.custodyOrigin(id))),
            sale.tokenId,
            mode,
            selected.assignmentHash,
            policy,
            1,
            artists.artist(),
            nonce,
            this.custodyFixtureTime() + 1000
        );
    }

    function _batchCall(StreamCustodyRightsTypes.Authorization memory a)
        internal
        returns (bytes memory)
    {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamCustodyRightsAllowCurrent"),
                keccak256("1"),
                block.chainid,
                address(house)
            )
        );
        bytes32 typed = keccak256(
            abi.encode(
                keccak256(
                    "CustodyRightsActivation(bytes32 auctionId,bytes32 baseConfigHash,bytes32 originHash,uint256 tokenId,uint8 rightsMode,bytes32 assignmentHash,bytes32 primaryPolicyHash,uint8 primaryPolicyMode,address artist,bytes32 nonce,uint64 deadline)"
                ),
                a.auctionId,
                a.baseConfigHash,
                a.originHash,
                a.tokenId,
                a.rightsMode,
                a.assignmentHash,
                a.primaryPolicyHash,
                a.primaryPolicyMode,
                a.artist,
                a.nonce,
                a.deadline
            )
        );
        bytes32 digest = keccak256(abi.encodePacked(hex"1901", domain, typed));
        require(house.custodyRightsDigest(a) == digest, "independent full custody rights EIP712");
        return abi.encodeCall(
            house.activateCustodyRights,
            (a, _custodyProof(AUCTION_PLATFORM_KEY, digest), _custodyProof(SIGNER_KEY, digest))
        );
    }

    function _activateBatch(bytes32 id, uint8 mode)
        internal
        returns (StreamCustodyRightsTypes.Activation memory)
    {
        bytes memory data = _batchCall(_batchAuthorization(id, mode, id));
        (bool ok,) = address(house).call(data);
        require(ok, "rights activation");
        return house.custodyRightsActivation(id);
    }

    function _batchBid(bytes32 id, address buyer) internal {
        vm.deal(buyer, 1 ether);
        vm.prank(buyer);
        house.bidCustodyRights{ value: 1000 }(id, buyer);
    }
}
