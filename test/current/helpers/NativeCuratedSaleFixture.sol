// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/NativeEnglishAuctionFixture.sol";
import "../../../smart-contracts/domains/mint/StreamNativeCuratedFixedPriceSale.sol";
import "../../../smart-contracts/domains/mint/StreamNativeCuratedContentGate.sol";
import {
    StreamNativeCuratedSaleTypes as Curated
} from "../../../smart-contracts/interfaces/stream/mint/StreamNativeCuratedSaleTypes.sol";
import {
    IStreamPreparedNativeContentPurchaseSettlement,
    IStreamPreparedNativeContentPurchaseSale
} from "../../../smart-contracts/interfaces/stream/mint/IStreamPreparedNativeContentPurchaseMint.sol";

/// @dev Explicit Artist semantic fixture. Sale consent binds the exact immutable id/configuration;
///      Artist onboarding/signatures and governance ceremony are not simulated as actual modules.
contract NativeCuratedArtistBoundary is IStreamArtistAttribution {
    address public immutable override core;
    address public immutable mintManager;
    address public artist;
    bool public consent = true;
    uint8 public state = 2;
    uint8 public contest;
    mapping(bytes32 => bytes32) public saleConsent;

    constructor(address c, address manager_) {
        core = c;
        mintManager = manager_;
    }

    function accept(address value) external {
        artist = value;
    }

    function setConsent(bool value) external {
        consent = value;
    }

    function setState(uint8 value) external {
        state = value;
    }

    function setContest(uint8 value) external {
        contest = value;
    }

    function bindSaleConsent(bytes32 saleId, bytes32 configHash) external {
        saleConsent[saleId] = configHash;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamArtistAttribution).interfaceId
            || id == 0x606af4b9 || id == type(IStreamArtistAttributionState).interfaceId
            || id == type(IStreamArtistMintConsent).interfaceId
            || id == type(IStreamArtistEconomicsAuthority).interfaceId;
    }

    function acceptedArtist(uint256) external view returns (address) {
        return artist;
    }

    function attribution(uint256)
        external
        view
        returns (IStreamCollectionArtistRegistry.Attribution memory a)
    {
        if (artist != address(0)) {
            a.artist = artist;
            a.nominationHash = keccak256("nomination");
            a.acceptanceHash = keccak256("acceptance");
        }
    }

    function collectionArtistState(uint256)
        external
        view
        returns (uint8, uint64, bytes32, uint8, bytes32)
    {
        return
            (state, 1, keccak256("native auction artist"), 1, keccak256("native auction binding"));
    }

    function platformWorksContest(uint256) external view returns (uint8, bytes32) {
        return (contest, keccak256("curated test contest"));
    }

    function requireEconomicsConsent(uint256, bytes32, uint8, uint256, bytes32) external view {
        require(consent, "artist economics");
    }

    function requireSaleConsent(uint256 collection, bytes32 saleId, bytes32 configHash)
        external
        view
    {
        require(
            collection == 1 && consent && configHash != 0 && saleConsent[saleId] == configHash,
            "exact artist sale consent"
        );
    }

    function consentMode(uint256) external pure returns (uint8) {
        return 1;
    }

    function isPolicyConsented(uint256, bytes32, bytes32 hash)
        external
        view
        returns (bool, bytes32)
    {
        return (artist != address(0) && consent, keccak256(abi.encode("fixture policy", hash)));
    }

    function requireMintConsent(uint256, bytes32, bytes32) external view {
        require(artist != address(0) && consent, "artist mint");
    }
}

    interface CuratedFixtureSaleReads {
        function nextSaleNonce() external view returns (uint256);
        function saleIdFor(uint8 kind, uint256 collection, bytes32 phase, uint256 nonce)
            external
            view
            returns (bytes32);
    }

    /// @notice Real current Core, Manager, Ledger, Registry, recorder, Resolver, wallet/escrow and roles.
    /// @dev Inherits the existing actual native graph; its unused auction deployment is fixture setup.
    ///      Governance is a target-context fixture, Artist is the exact-consent boundary above, and
    ///      entropy uses the existing controlled Coordinator boundary. Neither Manager nor Core is mocked.
    abstract contract NativeCuratedSaleFixture is NativeEnglishAuctionFixture {
        struct CuratedPlan {
            address adapter;
            uint8 kind;
            uint256 nonce;
            bytes32 saleId;
            bytes32 counter;
            StreamNativeCuratedContentGate gate;
            Curated.Configuration config;
            Curated.SelectionWindows windows;
            bytes32[3] leaves;
        }

        StreamNativeCuratedFixedPriceSale internal fixedSale;
        uint256 private _curatedPlanNumber;

        function setUp() public virtual override {
            super.setUp();
        }

        function _deployAuctionArtist() internal override returns (NativeAuctionArtist) {
            return NativeAuctionArtist(
                address(new NativeCuratedArtistBoundary(address(core), address(manager)))
            );
        }

        /// @dev Also reusable by the private carrier: deploy its host, then call _registerCuratedHost.
        function _curatedDeployment()
            internal
            returns (StreamNativeCuratedSaleBase.DeploymentConfig memory d)
        {
            d.manager = manager;
            d.recorder = recorder;
            d.platform = vm.addr(AUCTION_PLATFORM_KEY);
            d.artists = artists;
            d.roles = auctionRoles;
            d.authority = address(revenueAuthority);
            d.parameters[0] = IStreamGasParameterHost.GasParameterConfig(
                "SALE_ERC1271_GAS_LIMIT", 400000, 350000, 2
            );
            d.parameters[1] = IStreamGasParameterHost.GasParameterConfig(
                "SALE_ARTIST_AUTHORITY_GAS_LIMIT", 300000, 50000, 2
            );
            d.parameters[2] = IStreamGasParameterHost.GasParameterConfig(
                "REVEAL_ATTEMPT_GAS_LIMIT", 200000, 50000, 2
            );
            d.parameters[3] = IStreamGasParameterHost.GasParameterConfig(
                "SALE_NFT_DELIVERY_GAS_LIMIT", 300000, 100000, 2
            );
        }

        function _deployCuratedFixed() internal returns (StreamNativeCuratedFixedPriceSale) {
            fixedSale = new StreamNativeCuratedFixedPriceSale(_curatedDeployment());
            _registerCuratedHost(address(fixedSale));
            return fixedSale;
        }

        function _registerCuratedHost(address adapter) internal {
            require(
                IERC165(adapter)
                        .supportsInterface(type(IStreamPreparedNativeSaleBinding).interfaceId)
                    && IERC165(adapter)
                        .supportsInterface(
                            type(IStreamPreparedNativeContentPurchaseSale).interfaceId
                        ),
                "original prepared role and explicit purchase capability"
            );
            _register(
                adapter,
                keccak256("NATIVE_PREPARED_SALE_ADAPTER"),
                type(IStreamPreparedNativeSaleBinding).interfaceId,
                keccak256("6529STREAM_PREPARED_NATIVE_SETTLEMENT_V1")
            );
        }

        function _curatedLeaf(address adapter, bytes32 saleId, bytes32 contentId, bytes32 dataHash)
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
                            adapter,
                            saleId,
                            contentId,
                            dataHash
                        )
                    )
                )
            );
        }

        function _curatedPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
            return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
        }

        function _curatedContext(CuratedPlan memory p, uint256 index)
            internal
            view
            returns (bytes32)
        {
            return keccak256(
                abi.encode(
                    keccak256("6529STREAM_CONTENT_CONTEXT_V1"),
                    block.chainid,
                    p.adapter,
                    p.saleId,
                    bytes32(index)
                )
            );
        }

        function _curatedCounterKey(CuratedPlan memory p, uint256 index)
            internal
            view
            returns (bytes32)
        {
            bytes32 subject = keccak256(
                abi.encode(
                    keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1"),
                    block.chainid,
                    address(ledger),
                    IStreamMintManager.CounterKeyMode.CONTEXT,
                    _curatedContext(p, index)
                )
            );
            return
                ledger.deriveCounterValueKey(
                    address(manager), 1, p.config.phaseId, p.counter, subject
                );
        }

        function _curatedArtwork(uint256 index) internal pure returns (bytes memory) {
            require(index < 3, "manifest index");
            if (index == 0) return bytes("");
            if (index == 1) return bytes("curated actual artwork");
            return bytes("other declared artwork");
        }

        function _curatedPlan(address adapter, uint8 kind, Curated.SelectionMode mode)
            internal
            returns (CuratedPlan memory p)
        {
            p.adapter = adapter;
            p.kind = kind;
            p.config.phaseId =
                keccak256(abi.encode("current curated sale phase", ++_curatedPlanNumber));
            p.nonce = CuratedFixtureSaleReads(adapter).nextSaleNonce();
            p.saleId = CuratedFixtureSaleReads(adapter)
                .saleIdFor(kind, 1, p.config.phaseId, p.nonce);
            p.counter = keccak256(abi.encode("current curated cap1", p.config.phaseId));
            StreamPreparedNativeContentTypes.Row[] memory rows =
                new StreamPreparedNativeContentTypes.Row[](3);
            for (uint256 n; n < 3; ++n) {
                rows[n] = StreamPreparedNativeContentTypes.Row(
                    bytes32(n), keccak256(_curatedArtwork(n)), "urn:curated:published-preview"
                );
                p.leaves[n] =
                    _curatedLeaf(adapter, p.saleId, rows[n].contentId, rows[n].tokenDataHash);
            }
            p.gate = new StreamNativeCuratedContentGate(
                address(manager), adapter, p.saleId, 1, p.config.phaseId, p.counter, rows
            );
            _registerCuratedGate(p.gate);
            bytes32 root = _curatedPair(_curatedPair(p.leaves[0], p.leaves[1]), p.leaves[2]);
            require(
                p.gate.publication().manifestRoot == root && p.gate.itemCount() == 3
                    && keccak256(p.gate.manifestBytes()) == keccak256(abi.encode(rows)),
                "complete actual manifest publication"
            );
            uint64 starts = uint64(block.timestamp + 100);
            p.windows = Curated.SelectionWindows(
                starts, starts + 100, starts + 200, starts + 500, starts + 1000
            );
            bytes32[] memory ids = new bytes32[](1);
            ids[0] = p.counter;
            IStreamMintManager.MintCounterConfig[] memory counters =
                new IStreamMintManager.MintCounterConfig[](1);
            counters[0] = IStreamMintManager.MintCounterConfig(
                true,
                IStreamMintManager.CounterKeyMode.CONTEXT,
                IStreamMintLedger.CounterCapMode.STATIC,
                IStreamMintLedger.CounterDeltaMode.STATIC,
                1,
                1,
                keccak256(abi.encode("curated cap1 configuration", p.config.phaseId))
            );
            IStreamMintManager.MintGateConfig memory gate;
            gate.gate = address(p.gate);
            gate.gateConfigHash = p.gate.gateConfigHash();
            manager.configurePhase(
                1,
                p.config.phaseId,
                IStreamMintManager.MintPhaseConfig(
                    false, starts, p.windows.absoluteEscape, 1, MANIFEST, MANIFEST
                ),
                gate,
                ids,
                counters
            );
            manager.setPhaseExecutor(1, p.config.phaseId, adapter, true);
            p.config.collectionId = 1;
            p.config.price = 1000;
            p.config.poster = address(this);
            p.config.startsAt = starts;
            p.config.endsAt = p.windows.revealClose;
            p.config.mintPolicyHash = manager.phasePolicyHash(1, p.config.phaseId);
            p.config.expectedPrimaryPolicyHash =
                StreamNativeEnglishAuctionSupport.profilePolicy(resolver, 1);
            p.config.primaryPolicyMode = mode == Curated.SelectionMode.COMMIT_REVEAL ? 1 : 0;
            p.config.contentManifestRoot = root;
        }

        function _registerCuratedGate(StreamNativeCuratedContentGate gate) internal {
            StreamModuleRegistration memory r = StreamModuleRegistration(
                address(gate),
                keccak256("6529STREAM_MINT_GATE_V1"),
                keccak256("NATIVE_CURATED_PURCHASE_GATE_V1"),
                type(IStreamMintGate).interfaceId,
                800000,
                address(gate).codehash,
                MANIFEST,
                gate.gateConfigHash(),
                "urn:curated:complete-sale-manifest"
            );
            (bytes32 scope, bytes32 oldState, bytes32 newState) = _registrationTransition(r);
            _context(scope, oldState, newState, 1);
            vm.prank(address(revenueAuthority));
            registry.registerModule(r);
            _clearContext();
        }

        function _curatedSelection(
            CuratedPlan memory p,
            uint256 index,
            address recipient,
            uint256 nonce
        ) internal pure returns (Curated.Selection memory chosen) {
            chosen.content.contentId = bytes32(index);
            chosen.tokenData = _curatedArtwork(index);
            chosen.content.tokenDataHash = keccak256(chosen.tokenData);
            chosen.content.proof = new bytes32[](index == 2 ? 1 : 2);
            if (index == 2) {
                chosen.content.proof[0] = _curatedPair(p.leaves[0], p.leaves[1]);
            } else {
                chosen.content.proof[0] = p.leaves[index == 0 ? 1 : 0];
                chosen.content.proof[1] = p.leaves[2];
            }
            chosen.mintCommitment = keccak256(abi.encode("curated current mint", p.saleId, index));
            chosen.recipient = recipient;
            chosen.purchaseNonce = nonce;
        }

        function _fixedConfiguration(CuratedPlan memory p, Curated.SelectionMode mode)
            internal
            pure
            returns (Curated.FixedConfiguration memory c)
        {
            c.sale = p.config;
            c.mode = mode;
            c.differentiatedContent = mode == Curated.SelectionMode.COMMIT_REVEAL;
            c.publicSelectionDisclosure = mode == Curated.SelectionMode.PUBLIC;
            if (mode == Curated.SelectionMode.COMMIT_REVEAL) c.windows = p.windows;
        }

        function _bindCuratedConsent(bytes32 id, bytes32 configHash) internal {
            NativeCuratedArtistBoundary(address(artists)).bindSaleConsent(id, configHash);
        }

        function _openCuratedFixed(CuratedPlan memory p, Curated.SelectionMode mode)
            internal
            returns (bytes32 id)
        {
            Curated.FixedConfiguration memory config = _fixedConfiguration(p, mode);
            id = fixedSale.registerCuratedFixedSale(config);
            Curated.SaleRecord memory r = fixedSale.saleRecord(id);
            require(
                id == p.saleId && r.saleNonce == p.nonce
                    && r.configHash
                        == keccak256(
                            abi.encode(
                                keccak256("6529STREAM_NATIVE_CURATED_FIXED_CONFIG_V1"),
                                block.chainid,
                                address(fixedSale),
                                config
                            )
                        ),
                "unchanged canonical creation identity and configuration"
            );
            _bindCuratedConsent(id, r.configHash);
        }

        function _curatedSignature(uint256 key, bytes32 digest) internal returns (bytes memory) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
            return abi.encodePacked(r, s, v);
        }

        function _assertCuratedExecution(
            CuratedPlan memory p,
            uint256 index,
            Curated.ExecutionRecord memory e
        ) internal view {
            require(
                e.saleId == p.saleId && e.price == p.config.price
                    && e.contentLeaf == p.leaves[index]
                    && e.tokenDataHash == keccak256(_curatedArtwork(index)) && e.tokenId != 0
                    && core.ownerOf(e.tokenId) == e.recipient
                    && keccak256(core.tokenData(e.tokenId)) == e.tokenDataHash,
                "actual selected work and delivery"
            );
            require(
                ledger.counterValue(_curatedCounterKey(p, index)) == 1
                    && ledger.isManagerAuthorizationUsed(address(manager), e.authorizationId)
                    && ledger.isManagerOperationRootUsed(address(manager), e.operationRoot),
                "actual cap1 and replay consumption"
            );
            StreamPrimarySettlementTypes.PrimarySettlementResult memory settled =
                recorder.settlementResult(e.settlementKey);
            require(
                settled.amount == p.config.price
                    && settled.operationIdentityCommitment == e.operationRoot
                    && settled.wallet == wallet && settled.asset == address(0),
                "actual official purchase receipt"
            );
            require(
                manager.preparedNativeContentAdmission() == 0
                    && manager.activePreparedNativeContent().operationRoot == 0
                    && core.pendingPreparedMintTokenId() == 0,
                "prepared admission fully cleared"
            );
        }
    }
