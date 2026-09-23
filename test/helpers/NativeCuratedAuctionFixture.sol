// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./NativeEnglishAuctionFixture.sol";
import "../../smart-contracts/domains/auctions/StreamNativeAuctionContentGate.sol";

/// @dev Extends accepted actual Core/Manager/9 fixture; original typed authority/Artist/entropy boundaries remain.
abstract contract NativeCuratedAuctionFixture is NativeEnglishAuctionFixture {
    struct Plan {
        IStreamNativeEnglishAuction.Configuration config;
        StreamPreparedNativeContentTypes.Selection selection;
        StreamNativeAuctionContentGate gate;
        bytes artwork;
        uint256 nonce;
        bytes32 saleId;
        bytes32 counter;
    }
    uint256 private planNumber;
    uint256 private authNumber;

    function _leaf(bytes32 saleId, bytes32 contentId, bytes32 dataHash)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CONTENT_LEAF_V1"),
                        block.chainid,
                        address(house),
                        saleId,
                        contentId,
                        dataHash
                    )
                )
            )
        );
    }

    function _pair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    function _contextOf(Plan memory p) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CONTENT_CONTEXT_V1"),
                block.chainid,
                address(house),
                p.saleId,
                p.selection.contentId
            )
        );
    }

    function _counterKey(Plan memory p) internal view returns (bytes32) {
        bytes32 subject = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1"),
                block.chainid,
                address(ledger),
                IStreamMintManager.CounterKeyMode.CONTEXT,
                _contextOf(p)
            )
        );
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_VALUE_KEY_V1"),
                address(manager),
                uint256(1),
                p.config.phaseId,
                p.counter,
                subject
            )
        );
    }

    function _gateRegister(StreamNativeAuctionContentGate gate) private {
        StreamModuleRegistration memory r = StreamModuleRegistration(
            address(gate),
            keccak256("6529STREAM_MINT_GATE_V1"),
            keccak256("NATIVE_CURATED_GATE_V1"),
            type(IStreamMintGate).interfaceId,
            800000,
            address(gate).codehash,
            MANIFEST,
            gate.gateConfigHash(),
            "urn:curated:complete-manifest"
        );
        (bytes32 scope, bytes32 oldState, bytes32 newState) = _registrationTransition(r);
        _context(scope, oldState, newState, 1);
        vm.prank(address(revenueAuthority));
        registry.registerModule(r);
        _clearContext();
    }

    function _unconfiguredPlan(bool empty) internal returns (Plan memory p) {
        bytes32 phase = keccak256(abi.encode("curated phase", ++planNumber));
        (p.nonce, p.saleId) = house.nextCuratedSaleId(1, phase);
        p.counter = keccak256(abi.encode("curated context", phase));
        StreamPreparedNativeContentTypes.Row[] memory rows =
            new StreamPreparedNativeContentTypes.Row[](3);
        rows[0] = StreamPreparedNativeContentTypes.Row(0, keccak256(""), "urn:preview:empty");
        rows[1] = StreamPreparedNativeContentTypes.Row(
            bytes32(uint256(1)), keccak256("curated actual artwork"), "urn:preview:one"
        );
        rows[2] = StreamPreparedNativeContentTypes.Row(
            bytes32(uint256(2)), keccak256("other declared artwork"), "urn:preview:two"
        );
        p.gate = new StreamNativeAuctionContentGate(
            address(manager), address(house), p.saleId, 1, phase, p.counter, rows
        );
        bytes32 a = _leaf(p.saleId, rows[0].contentId, rows[0].tokenDataHash);
        bytes32 b = _leaf(p.saleId, rows[1].contentId, rows[1].tokenDataHash);
        bytes32 c = _leaf(p.saleId, rows[2].contentId, rows[2].tokenDataHash);
        bytes32 root = _pair(_pair(a, b), c);
        StreamPreparedNativeContentTypes.Publication memory published = p.gate.publication();
        require(
            published.manifestRoot == root && published.manifestHash == keccak256(abi.encode(rows))
                && p.gate.itemCount() == 3
                && keccak256(p.gate.manifestBytes()) == keccak256(abi.encode(rows)),
            "full actual ordered publication"
        );
        p.artwork = empty ? bytes("") : bytes("curated actual artwork");
        p.selection.contentId = empty ? bytes32(0) : bytes32(uint256(1));
        p.selection.tokenDataHash = keccak256(p.artwork);
        p.selection.proof = new bytes32[](2);
        p.selection.proof[0] = empty ? b : a;
        p.selection.proof[1] = c;
        p.config.collectionId = 1;
        p.config.phaseId = phase;
        p.config.mintAtSettlement = true;
        p.config.artworkCommitment = empty ? a : b;
        p.config.contentManifestRoot = root;
        p.config.mintCommitment = keccak256("curated mint");
        p.config.poster = address(this);
        p.config.reservePrice = 1000;
        p.config.minIncrementBps = 500;
        p.config.clock =
            StreamEnglishAuctionClock.Configuration(1000, 4600, 0, 600, 600, 3600, false, false);
        p.config.expectedPrimaryPolicyHash =
            StreamNativeEnglishAuctionSupport.profilePolicy(resolver, 1);
        p.config.primaryPolicyMode = 1;
        p.config.settlementWindow = 86400;
    }

    function _configure(Plan memory p, uint64 cap) internal returns (Plan memory) {
        _gateRegister(p.gate);
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = p.counter;
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONTEXT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            cap,
            1,
            keccak256(abi.encode("curated cap", p.config.phaseId, cap))
        );
        IStreamMintManager.MintGateConfig memory g;
        g.gate = address(p.gate);
        g.gateConfigHash = p.gate.gateConfigHash();
        manager.configurePhase(
            1,
            p.config.phaseId,
            IStreamMintManager.MintPhaseConfig(false, 0, 0, 1, MANIFEST, MANIFEST),
            g,
            ids,
            counters
        );
        manager.setPhaseExecutor(1, p.config.phaseId, address(house), true);
        p.config.mintPolicyHash = manager.phasePolicyHash(1, p.config.phaseId);
        return p;
    }

    function _plan(bool empty, uint64 cap) internal returns (Plan memory) {
        return _configure(_unconfiguredPlan(empty), cap);
    }

    function _sig(uint256 key, bytes32 hash) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, hash);
        return abi.encodePacked(r, s, v);
    }

    function _approval(Plan memory p)
        internal
        returns (
            IStreamNativeEnglishAuction.CreationAuthorization memory a,
            bytes memory platform,
            bytes memory artist
        )
    {
        a = IStreamNativeEnglishAuction.CreationAuthorization(
            house.auctionConfigurationHash(p.config),
            vm.addr(SIGNER_KEY),
            bytes32(++authNumber),
            2000
        );
        bytes32 digest = house.creationAuthorizationDigest(a);
        platform = _sig(AUCTION_PLATFORM_KEY, digest);
        artist = _sig(SIGNER_KEY, digest);
    }

    function _opening(Plan memory p) internal returns (bytes memory) {
        (
            IStreamNativeEnglishAuction.CreationAuthorization memory a,
            bytes memory platform,
            bytes memory artist
        ) = _approval(p);
        return abi.encodeCall(
            house.registerCuratedAuction,
            (p.config, p.artwork, p.selection, p.nonce, a, platform, artist)
        );
    }

    function _open(Plan memory p) internal returns (bytes32 id) {
        (bool ok, bytes memory raw) = address(house).call(_opening(p));
        require(ok, "curated actual opening");
        return abi.decode(raw, (bytes32));
    }

    function _bidCurated(bytes32 id, address who) internal {
        uint256 value = 1000 + entropy.fee();
        vm.deal(who, 1 ether);
        vm.prank(who);
        house.bid{ value: value }(id, address(0));
        require(
            house.auction(id).winner.payer == who && house.auction(id).winner.executor == who,
            "original curated payer"
        );
    }

    function _endCurated(bytes32 id) internal {
        (uint64 end,,,) = house.auctionDeadlines(id);
        vm.warp(end);
    }

    function _batchFor(Plan memory p, bytes32 authorization)
        internal
        view
        returns (IStreamMintManager.MintBatch memory b, bytes memory g)
    {
        b.collectionId = 1;
        b.phaseId = p.config.phaseId;
        b.payer = payer;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = address(house);
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = payer;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = p.artwork;
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = p.config.mintCommitment;
        b.expectedPolicyHash = p.config.mintPolicyHash;
        b.authorizationId = authorization;
        b.contextHash = _contextOf(p);
        g = abi.encode(StreamPreparedNativeContentTypes.GateData(authorization, p.selection));
    }
}
