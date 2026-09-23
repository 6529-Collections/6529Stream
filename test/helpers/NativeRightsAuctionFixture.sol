// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./NativeEnglishAuctionFixture.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistBeneficiaryFacts.sol";

/// @dev Explicit Artist boundary. Real Resolver/Factory derive and materialize every payout.
contract NativeRightsAuctionArtist is NativeAuctionArtist, IStreamArtistBeneficiaryFacts {
    address public payout;
    address public fundingTrigger;
    address public afterFundingPayout;

    constructor(address c, address m) NativeAuctionArtist(c, m) { }

    function supportsInterface(bytes4 id) public pure virtual override returns (bool) {
        return id == type(IStreamArtistBeneficiaryFacts).interfaceId || super.supportsInterface(id);
    }

    function setPayout(address value) external {
        payout = value;
    }

    function changeAfterFunding(address trigger, address value) external {
        fundingTrigger = trigger;
        afterFundingPayout = value;
    }

    function collectionArtistBeneficiary(uint256)
        external
        view
        returns (bytes32, address, bytes32)
    {
        require(artist != address(0), "typed artist accepted");
        address current = fundingTrigger != address(0) && fundingTrigger.balance != 0
            ? afterFundingPayout
            : payout;
        return (
            keccak256("native auction artist"),
            current,
            keccak256(abi.encode("designation", current))
        );
    }
}

abstract contract NativeRightsAuctionFixture is NativeEnglishAuctionFixture {
    NativeRightsAuctionArtist internal rightsArtist;
    bytes32 internal template;
    uint256 internal rightsNonce;

    function _deployAuctionArtist() internal virtual override returns (NativeAuctionArtist) {
        rightsArtist = new NativeRightsAuctionArtist(address(core), address(manager));
        return rightsArtist;
    }

    function setUp() public virtual override {
        super.setUp();
        rightsArtist.setPayout(address(0xA77157));
        template = _selectTemplate(900000, keccak256("original template"));
    }

    /// @dev Template assignment is made during the typed Artist's unbound setup state;
    /// this is not evidence for a live facade's template-migration authority.
    function _selectTemplate(uint32 share, bytes32 terms) internal returns (bytes32 id) {
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](2);
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), keccak256("COLLECTION_ARTIST"), share, keccak256("artist")
        );
        entries[1] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0xFEE), 0, 1000000 - share, keccak256("protocol")
        );
        id = resolver.createPrimaryTemplate(entries, terms);
        artists.accept(address(0));
        resolver.setPrimaryTemplateAssignment(CLASS, 1, 1, id, 0);
        artists.accept(vm.addr(SIGNER_KEY));
    }

    function _rightsConfig()
        internal
        view
        returns (IStreamNativeEnglishAuction.Configuration memory c)
    {
        uint64 observedTime = this.rightsFixtureTime();
        c.collectionId = 1;
        c.phaseId = PHASE;
        c.mintAtSettlement = true;
        c.artworkCommitment = keccak256("rights artwork");
        c.mintCommitment = keccak256("rights mint");
        c.poster = address(this);
        c.reservePrice = 1000;
        c.minIncrementBps = 500;
        c.clock = StreamEnglishAuctionClock.Configuration(
            observedTime, observedTime + 3600, 0, 600, 600, 3600, false, false
        );
        c.expectedPrimaryPolicyHash = _policy(0, _selected());
        c.primaryPolicyMode = 1;
        c.settlementWindow = 86400;
        c.mintPolicyHash = manager.phasePolicyHash(1, PHASE);
    }

    function _selected() internal view virtual returns (StreamSaleTemplate.Selection memory) {
        return StreamPreparedNativeRightsProjection.collectionTemplate(resolver, 1);
    }

    /// @dev Independent original specification preimage, with explicit token identity.
    function _policy(uint256 token, StreamSaleTemplate.Selection memory s)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_POLICY_V1"),
                block.chainid,
                address(resolver),
                CLASS,
                uint256(1),
                token,
                s.templateId,
                s.profileId,
                s.wallet,
                s.assignmentHash
            )
        );
    }

    function _original()
        internal
        view
        virtual
        returns (StreamPreparedNativeRightsTypes.OriginalPolicy memory)
    {
        StreamSaleTemplate.Selection memory s = _selected();
        return StreamPreparedNativeRightsTypes.OriginalPolicy(1, s.assignmentHash, s.templateId);
    }

    function _proof(uint256 key, bytes32 digest) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _createRights(IStreamNativeEnglishAuction.Configuration memory c)
        internal
        returns (bytes32)
    {
        StreamPreparedNativeRightsTypes.OriginalPolicy memory o = _original();
        IStreamNativeEnglishAuction.CreationAuthorization memory a =
            IStreamNativeEnglishAuction.CreationAuthorization(
                house.rightsConfigurationHash(c, o),
                vm.addr(SIGNER_KEY),
                bytes32(++rightsNonce),
                this.rightsFixtureTime() + 1000
            );
        bytes32 digest = house.creationAuthorizationDigest(a);
        return house.registerRightsAuction(
            c,
            o,
            bytes("rights artwork"),
            a,
            _proof(AUCTION_PLATFORM_KEY, digest),
            _proof(SIGNER_KEY, digest)
        );
    }

    function _rightsBid(bytes32 id, address who) internal {
        uint256 value = 1000 + entropy.fee();
        vm.deal(who, 1 ether);
        vm.prank(who);
        house.bid{ value: value }(id, address(0));
        IStreamNativeEnglishAuction.WinningBid memory winner = house.auction(id).winner;
        require(
            winner.payer == who && winner.executor == who && winner.deliverTo == who,
            "actual original public bidder"
        );
    }

    function _endRights(bytes32 id) internal {
        (uint64 end,,,) = house.auctionDeadlines(id);
        vm.warp(end);
    }

    /// @dev An external observation prevents IR rematerialization across a test-only warp.
    function rightsFixtureTime() external view returns (uint64) {
        return uint64(block.timestamp);
    }
}
