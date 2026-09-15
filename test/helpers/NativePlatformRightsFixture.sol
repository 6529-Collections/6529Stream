// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./NativeEnglishAuctionFixture.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistPlatformWorks.sol";
import {
    StreamArtistPlatformTypes as PW
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistPlatformTypes.sol";
import {
    IStreamPlatformNativeRightsAuction as P
} from "../../smart-contracts/interfaces/stream/auctions/IStreamPlatformNativeRightsAuction.sol";

/// @dev Typed Artist/governance/entropy, actual Core/Manager/Resolver/recorder/Safe. No op15 fiction.
contract PlatformPrimaryArtist is IStreamArtistAttribution {
    address public immutable override core;
    address public immutable mintManager;
    NativeAuctionArtist private immutable baseline;
    PW.State private _platform;
    uint8 private _mode = 3;
    address public fundingTrigger;

    function failAfterFunding(address target) external {
        fundingTrigger = target;
    }

    function fileDisplayClaim() external {
        ++_platform.claimCount;
    }
    address public royalty;
    bytes32 public approval;

    constructor(address c, address m) {
        core = c;
        mintManager = m;
        baseline = new NativeAuctionArtist(c, m);
    }

    function accept(address value) external {
        baseline.accept(value);
    }

    function setConsent(bool value) external {
        baseline.setConsent(value);
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        return id == type(IStreamArtistPlatformWorks).interfaceId || baseline.supportsInterface(id);
    }

    function acceptedArtist(uint256 id) external view returns (address) {
        return id == 2 && _mode == 3 ? address(0) : baseline.acceptedArtist(id);
    }

    function attribution(uint256 id)
        external
        view
        returns (IStreamCollectionArtistRegistry.Attribution memory a)
    {
        if (id != 2 || _mode != 3) return baseline.attribution(id);
    }

    function collectionArtistState(uint256 id)
        external
        view
        returns (uint8, uint64, bytes32, uint8, bytes32)
    {
        return baseline.collectionArtistState(id);
    }

    function consentMode(uint256 id) external view returns (uint8) {
        return id == 2 ? _mode : 1;
    }

    function isPolicyConsented(uint256 id, bytes32, bytes32 h)
        external
        view
        returns (bool, bytes32)
    {
        if (id == 2 && _mode == 3) {
            return (_allowed(), _platform.declaration.recordHash);
        }
        return (true, keccak256(abi.encode("fixture policy", h)));
    }

    function requireMintConsent(uint256 id, bytes32, bytes32) external view {
        if (id == 2) {
            require(_mode == 3 ? _allowed() : approval != 0, "typed current mint admission");
        }
    }
    function requireSaleConsent(uint256, bytes32, bytes32) external pure { }

    function requireEconomicsConsent(uint256 id, bytes32, uint8 scope, uint256 scopeId, bytes32 h)
        external
        view
    {
        if (id == 2) {
            require(
                _mode != 3 && msg.sender == royalty && scope == 1 && scopeId == 2 && h == approval
                    && h != 0,
                "exact corrected Artist approval; never platform op15"
            );
        }
    }

    function declare() external {
        require(
            _platform.declaration.recordHash == 0
                && !StreamMintManager(mintManager).hasRegisteredPhasePolicy(2),
            "pre-phase declaration"
        );
        bytes32 statement = keccak256("typed platform declaration");
        _platform.declaration = PW.Declaration(
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_PLATFORM_WORKS_DECLARATION_V1"),
                    block.chainid,
                    address(this),
                    core,
                    uint256(2),
                    statement,
                    uint64(block.timestamp)
                )
            ),
            statement,
            msg.sender,
            uint64(block.timestamp)
        );
    }

    function contest(uint8 state) external {
        _platform.contestState = state;
        _platform.contestClaim = state == 0 ? bytes32(0) : keccak256("typed claim");
        _platform.contestRecord =
            state == 0 ? bytes32(0) : keccak256(abi.encode("typed contest", state));
    }

    function correct(uint64 generation, bool accepted) external {
        _platform.correction.correctiveGeneration = generation;
        _platform.correction.accepted = accepted;
        _platform.correction.approvalActionId = keccak256("typed correction action");
        _platform.correction.recordHash = keccak256("typed correction");
        _mode = accepted ? 1 : 3;
    }

    function approve(address r, bytes32 h) external {
        royalty = r;
        approval = h;
    }

    function platformWorksState(uint256) external view returns (PW.State memory) {
        PW.State memory p = _platform;
        if (fundingTrigger != address(0) && fundingTrigger.balance != 0) {
            p.contestState = 1;
            p.contestClaim = keccak256("late platform claim");
            p.contestRecord = keccak256("late platform contest");
        }
        return p;
    }

    function platformWorksDeclaration(uint256) external view returns (bool, bytes32, uint64) {
        return (
            _platform.declaration.recordHash != 0,
            _platform.declaration.recordHash,
            _platform.declaration.declaredAt
        );
    }

    function platformWorksContest(uint256) external view returns (uint8, bytes32) {
        if (fundingTrigger != address(0) && fundingTrigger.balance != 0) {
            return (1, keccak256("late platform claim"));
        }
        return (_platform.contestState, _platform.contestClaim);
    }

    function platformWorksCorrection(uint256) external view returns (uint64, bytes32) {
        return (_platform.correction.correctiveGeneration, _platform.correction.approvalActionId);
    }

    function _allowed() private view returns (bool) {
        return _platform.declaration.recordHash != 0
            && (_platform.contestState == 0 || _platform.contestState == 2)
            && _platform.correction.correctiveGeneration == 0;
    }
}

    abstract contract NativePlatformRightsFixture is NativeEnglishAuctionFixture {
        PlatformPrimaryArtist internal platform;
        bytes32 internal constant PLATFORM_PHASE = keccak256("platform primary prepared");
        uint256 internal creationNonce;

        function _deployAuctionArtist() internal override returns (NativeAuctionArtist) {
            platform = new PlatformPrimaryArtist(address(core), address(manager));
            return NativeAuctionArtist(address(platform));
        }

        function setUp() public virtual override {
            super.setUp();
            bytes32 scope = keccak256(
                abi.encode(
                    bytes32(0x3a882a22dad9915c9193738f63216234155080ed4c4fc9bfae446e90f1df6e16),
                    block.chainid,
                    address(core),
                    uint256(2)
                )
            );
            bytes32 domain = 0x854c83f82b7677e58c61a2482a7a430a8318d765d99a95d3fbce5c84be6cc2b5;
            _context(
                scope,
                keccak256(abi.encode(domain, scope, false, uint8(0), uint8(0), false, uint256(0))),
                keccak256(abi.encode(domain, scope, true, uint8(2), uint8(0), false, uint256(0))),
                1
            );
            vm.prank(address(revenueAuthority));
            require(core.createCollection(2, false, 0, 0) == 2);
            _clearContext();
            platform.declare();
            bytes32[] memory ids = new bytes32[](1);
            ids[0] = COUNTER;
            IStreamMintManager.MintCounterConfig[] memory rows =
                new IStreamMintManager.MintCounterConfig[](1);
            rows[0] = IStreamMintManager.MintCounterConfig(
                true,
                IStreamMintManager.CounterKeyMode.PAYER,
                IStreamMintLedger.CounterCapMode.STATIC,
                IStreamMintLedger.CounterDeltaMode.STATIC,
                10,
                1,
                keccak256("platform counter")
            );
            IStreamMintManager.MintGateConfig memory gate;
            manager.configurePhase(
                2,
                PLATFORM_PHASE,
                IStreamMintManager.MintPhaseConfig(false, 0, 0, 1, MANIFEST, MANIFEST),
                gate,
                ids,
                rows
            );
            manager.setPhaseExecutor(2, PLATFORM_PHASE, address(house), true);
        }

        function timeNow() external view returns (uint64) {
            return uint64(block.timestamp);
        }

        function _template(uint8 mode, bool poster) internal returns (bytes32 template) {
            IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
                new IStreamRevenueResolver.PrimaryTemplateEntry[](2);
            entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
                poster ? address(0) : address(0xA111),
                poster ? keccak256("SALE_POSTER") : bytes32(0),
                900000,
                keccak256("platform creator")
            );
            entries[1] = IStreamRevenueResolver.PrimaryTemplateEntry(
                address(0xFEE), 0, 100000, keccak256("protocol")
            );
            template = resolver.createPrimaryTemplate(
                entries, keccak256(abi.encode("platform terms", mode, poster))
            );
            if (mode == 9) {
                IStreamRevenueResolver.ResolvedPrimaryAssignment memory current =
                    resolver.resolvePrimaryAssignment(2, 0, CLASS);
                if (current.exists && current.scope == 1) {
                    resolver.clearPrimaryAssignment(CLASS, 1, 2);
                }
            }
            resolver.setPrimaryTemplateAssignment(
                CLASS, mode == 8 ? 1 : 0, mode == 8 ? 2 : 0, template, 0
            );
        }

        function _selected(uint8 mode)
            internal
            view
            returns (StreamSaleTemplate.Selection memory selected)
        {
            selected = StreamPreparedNativeRightsProjection.collectionTemplateForPoster(
                resolver, 2, mode, address(this)
            );
        }

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
                    uint256(2),
                    token,
                    s.templateId,
                    s.profileId,
                    s.wallet,
                    s.assignmentHash
                )
            );
        }

        function _config(uint8 mode)
            internal
            view
            returns (IStreamNativeEnglishAuction.Configuration memory c)
        {
            uint64 now_ = this.timeNow();
            c.collectionId = 2;
            c.phaseId = PLATFORM_PHASE;
            c.mintAtSettlement = true;
            c.artworkCommitment = keccak256("platform primary artwork");
            c.mintCommitment = keccak256("platform mint");
            c.poster = address(this);
            c.reservePrice = 1000;
            c.minIncrementBps = 500;
            c.clock = StreamEnglishAuctionClock.Configuration(
                now_, now_ + 3600, 0, 600, 600, 3600, false, false
            );
            c.expectedPrimaryPolicyHash = _policy(0, _selected(mode));
            c.primaryPolicyMode = 1;
            c.settlementWindow = 86400;
            c.mintPolicyHash = manager.phasePolicyHash(2, PLATFORM_PHASE);
        }

        function _proof(uint256 key, bytes32 digest) internal returns (bytes memory) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
            return abi.encodePacked(r, s, v);
        }

        function _opening(uint8 mode) internal returns (bytes memory callData) {
            IStreamNativeEnglishAuction.Configuration memory c = _config(mode);
            StreamSaleTemplate.Selection memory s = _selected(mode);
            StreamPreparedNativeRightsTypes.OriginalPolicy memory o =
                StreamPreparedNativeRightsTypes.OriginalPolicy(mode, s.assignmentHash, s.templateId);
            (, bytes32 declaration,) = platform.platformWorksDeclaration(2);
            P.PlatformCreationAuthorization memory a = P.PlatformCreationAuthorization(
                house.platformRightsConfigurationHash(c, o, declaration),
                declaration,
                bytes32(++creationNonce),
                this.timeNow() + 1 days
            );
            bytes32 domain = keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256("6529StreamPlatformNativeRightsAuction"),
                    keccak256("1"),
                    block.chainid,
                    address(house)
                )
            );
            bytes32 digest = keccak256(
                abi.encodePacked(
                    hex"1901",
                    domain,
                    keccak256(
                        abi.encode(
                            keccak256(
                                "PlatformNativeAuctionCreation(bytes32 configHash,bytes32 declarationHash,bytes32 nonce,uint64 deadline)"
                            ),
                            a
                        )
                    )
                )
            );
            require(
                digest == house.platformRightsCreationDigest(a), "independent new signing domain"
            );
            require(
                a.configHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_PLATFORM_NATIVE_RIGHTS_CONFIG_V1"),
                            block.chainid,
                            address(house),
                            c,
                            o,
                            declaration
                        )
                    ),
                "independent declared configuration"
            );
            return abi.encodeCall(
                house.registerPlatformRightsAuction,
                (c, o, bytes("platform primary artwork"), a, _proof(AUCTION_PLATFORM_KEY, digest))
            );
        }

        function _open(uint8 mode) internal returns (bytes32 id) {
            (bool ok, bytes memory out) = address(house).call(_opening(mode));
            require(ok, "platform opening");
            return abi.decode(out, (bytes32));
        }

        function _bid(bytes32 id, address who) internal {
            uint256 value = 1000 + entropy.fee();
            vm.deal(who, 1 ether);
            vm.prank(who);
            house.bid{ value: value }(id, address(0));
        }

        function _end(bytes32 id) internal {
            (uint64 end,,,) = house.auctionDeadlines(id);
            vm.warp(end);
        }
    }
