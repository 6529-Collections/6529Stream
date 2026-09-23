// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CurrentDynamicRoyaltyCommerceFixture.sol";
import "../mocks/MockStreamPaymentToken.sol";
import {
    StreamERC20PrimaryOfferSale
} from "../../smart-contracts/domains/mint/StreamERC20PrimaryOfferSale.sol";
import { StreamERC20OfferGate } from "../../smart-contracts/domains/mint/StreamERC20OfferGate.sol";
import {
    StreamERC20PrimarySettlementAdapter
} from "../../smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol";
import "../../smart-contracts/domains/revenue/StreamPrimarySettlementHash.sol";
import "../../smart-contracts/domains/mint/StreamMintTicketHash.sol";
import "../../smart-contracts/integrations/delegation/NFTdelegation.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistSaleAuthority.sol";
import "../../smart-contracts/interfaces/stream/mint/IStreamNativeRefundDelegatedClaims.sol";
import "../../smart-contracts/interfaces/stream/revenue/IStreamERC20PrimarySettlementAdapter.sol";
import "../../smart-contracts/interfaces/stream/mint/StreamPreparedNativeContentTypes.sol";
import "../../smart-contracts/interfaces/stream/mint/IStreamMintGate.sol";
import {
    StreamArtistSaleTypes as OfferConsent
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistSaleTypes.sol";
import {
    StreamERC20PrimaryOfferTypes as OfferE20
} from "../../smart-contracts/interfaces/stream/mint/StreamERC20PrimaryOfferTypes.sol";
import {
    StreamPrivateSaleTypes as OfferSale
} from "../../smart-contracts/interfaces/stream/mint/StreamPrivateSaleTypes.sol";
import {
    IStreamPrivateSaleAdapter as OfferPrivate
} from "../../smart-contracts/interfaces/stream/mint/IStreamPrivateSaleAdapter.sol";
import {
    StreamPrimarySettlementTypes as PrimaryE20
} from "../../smart-contracts/interfaces/stream/revenue/StreamPrimarySettlementTypes.sol";

/// @dev Real current authority/Artist/mint/revenue/entropy graph and original NFTDelegation.
/// The ERC20 asset and external entropy provider are explicit external-service fixtures.
abstract contract CurrentArtistERC20OfferFixture is CurrentDynamicRoyaltyCommerceFixture {
    StreamERC20PrimaryOfferSale internal artistOffers;
    StreamERC20PrimarySettlementAdapter internal offerPayment;
    MockStreamPaymentToken internal offerToken;
    DelegationManagementContract internal offerDelegates;
    bytes32 internal constant OFFER_GATE_VERSION =
        keccak256("6529STREAM_ERC20_PRIMARY_OFFER_GATE_V1");
    bytes32 internal constant OFFER_DELEGATION_BASE =
        keccak256("actual Artist ERC20 offer delegation");
    uint256 private offerPlanNumber;

    struct ERC20OfferPlan {
        bytes32 id;
        uint256 nonce;
        bytes32 counter;
        bytes32 leaf;
        StreamERC20OfferGate gate;
        OfferE20.Configuration config;
    }

    function _fixtureSaleConsentScope() internal pure override returns (uint8) {
        return 1;
    }

    function artistERC20OfferTime() external view returns (uint64) {
        return uint64(block.timestamp);
    }

    function _deployArtistERC20Offers() internal {
        _deployJoinedCommerce();
        // The fixture's genuinely admitted ENTROPY_ADMIN changes only the future live fee.
        entropy.updateRevealFeePerToken(1, 0);
        offerToken = new MockStreamPaymentToken();
        offerDelegates = DelegationManagementContract(
            _artistArtifactCreate(
                "smart-contracts/integrations/delegation/NFTdelegation.sol:DelegationManagementContract",
                ""
            )
        );
        offerPayment = StreamERC20PrimarySettlementAdapter(
            _artistArtifactCreate(
                "smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol:StreamERC20PrimarySettlementAdapter",
                abi.encode(joinedRecorder, address(0), bytes32(0))
            )
        );
        StreamERC20PrimaryOfferSale.DeploymentConfig memory d;
        d.manager = manager;
        d.recorder = joinedRecorder;
        d.artists = IStreamArtistAttribution(address(artists));
        d.roles = roles;
        d.authority = address(executor);
        d.parameters[0] =
            IStreamGasParameterHost.GasParameterConfig("SALE_ERC1271_GAS_LIMIT", 400000, 350000, 2);
        d.parameters[1] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ARTIST_AUTHORITY_GAS_LIMIT", 600000, 50000, 2
        );
        d.parameters[2] = IStreamGasParameterHost.GasParameterConfig(
            "REVEAL_ATTEMPT_GAS_LIMIT", 200000, 50000, 2
        );
        d.delegation = IStreamNativeRefundDelegatedClaims.DelegationDeployment(
            address(offerDelegates),
            2,
            OFFER_DELEGATION_BASE,
            IStreamGasParameterHost.GasParameterConfig(
                "DELEGATE_REGISTRY_GAS_LIMIT", 150000, 50000, 2
            )
        );
        artistOffers = StreamERC20PrimaryOfferSale(
            _artistArtifactCreate(
                "smart-contracts/domains/mint/StreamERC20PrimaryOfferSale.sol:StreamERC20PrimaryOfferSale",
                abi.encode(d)
            )
        );
        _assertDeployableProductionInstance(address(offerPayment));
        _assertDeployableProductionInstance(address(artistOffers));
        artistOffers.transferOwnership(address(joinedCollaborator));
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](2);
        records[0] = StreamModuleRegistration(
            address(offerPayment),
            keccak256("ERC20_PRIMARY_SETTLEMENT_ADAPTER"),
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1"),
            type(IStreamERC20PrimarySettlementAdapter).interfaceId,
            500000,
            address(offerPayment).codehash,
            DEPLOYMENT_HASH,
            OFFER_DELEGATION_BASE,
            "urn:stream:actual-offer:payment"
        );
        records[1] = StreamModuleRegistration(
            address(artistOffers),
            artistOffers.streamModuleType(),
            artistOffers.streamModuleVersion(),
            artistOffers.streamModuleInterfaceId(),
            500000,
            address(artistOffers).codehash,
            DEPLOYMENT_HASH,
            keccak256(artistOffers.offerDelegationManifest()),
            "urn:stream:actual-offer:sale"
        );
        _erc20OfferRegister(records);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = assetPolicy.assetPolicyTransitionHashes(
            address(offerToken), 1, keccak256("actual ERC20 offer exact-balance asset"), 0
        );
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(
            assetPolicy.setAssetStatus,
            (
                address(offerToken),
                uint8(1),
                keccak256("actual ERC20 offer exact-balance asset"),
                uint64(0)
            )
        );
        calls[0] =
            StreamCurrentStackPlan.call(address(assetPolicy), data[0], scope, oldHash, newHash);
        _joinedBatch(calls, data);
        offerToken.mint(address(joinedBuyer), 10000);
        _joinedSafe(
            joinedBuyer,
            address(offerToken),
            0,
            abi.encodeCall(offerToken.approve, (address(offerPayment), uint256(10000)))
        );
    }

    function _erc20OfferRegister(StreamModuleRegistration[] memory records) private {
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        _joinedBatch(calls, data);
        for (uint256 i; i < records.length; ++i) {
            StreamModuleRecord memory r = registry.moduleRecord(records[i].module);
            require(
                r.status == ModuleRegistryStatus.ACTIVE
                    && r.runtimeCodeHash == records[i].module.codehash,
                "actual Governor admits original module"
            );
        }
    }

    function _openArtistERC20Offer(bool selected, bool consent)
        internal
        returns (ERC20OfferPlan memory p, OfferE20.Acceptance memory q)
    {
        p.nonce = artistOffers.nextSaleNonce();
        p.config.collectionId = 1;
        p.config.phaseId =
            keccak256(abi.encode("actual Artist ERC20 offer phase", ++offerPlanNumber));
        p.id = artistOffers.saleIdFor(1, p.config.phaseId, p.nonce);
        p.counter = keccak256(abi.encode("actual offer content counter", p.id));
        q.selection.tokenData =
            selected ? bytes("") : bytes("actual Artist collection-level ERC20 offer bytes");
        q.selection.mintCommitment = keccak256(abi.encode("actual original ERC20 offer mint", p.id));
        q.selection.executionNonce = 1;
        IStreamMintManager.MintGateConfig memory gate;
        if (selected) gate = _erc20OfferGate(p, q);
        _erc20OfferPhase(p, gate, selected);
        p.config.asset = address(offerToken);
        p.config.paymentAdapter = address(offerPayment);
        p.config.price = 1000;
        p.config.poster = address(joinedCollaborator);
        p.config.buyer = address(joinedBuyer);
        p.config.startsAt = this.artistERC20OfferTime() + 1;
        p.config.endsAt = p.config.startsAt + 7 days;
        p.config.expectedPrimaryPolicyHash = _nativePrimaryPolicyHash();
        p.config.mintPolicyHash = manager.phasePolicyHash(1, p.config.phaseId);
        _joinedSafe(
            joinedCollaborator,
            address(artistOffers),
            0,
            abi.encodeCall(
                artistOffers.configureCollectionSigner,
                (
                    uint256(1),
                    address(joinedCollector),
                    uint8(2),
                    keccak256("actual ERC20 seller Safe evidence"),
                    true
                )
            )
        );
        OfferE20.CollectionSigner memory member =
            artistOffers.collectionSigner(1, address(joinedCollector), 2);
        p.config.signer = address(joinedCollector);
        p.config.signerKind = 2;
        p.config.signerEvidenceHash = member.evidenceHash;
        p.config.signerRevision = member.revision;
        p.config.signerAuthority = member.authority;
        q.offer = OfferSale.SaleOffer(
            block.chainid,
            address(artistOffers),
            address(core),
            1,
            0,
            p.leaf,
            address(joinedBuyer),
            address(offerToken),
            1000,
            keccak256(abi.encode("actual original buyer offer", p.id)),
            p.config.endsAt,
            0
        );
        p.config.offerDigest = _erc20BuyerDigest(q.offer);
        _joinedSafe(
            joinedCollaborator,
            address(artistOffers),
            0,
            abi.encodeCall(artistOffers.registerPrimaryOffer, (p.config, q.selection.content.proof))
        );
        bytes32 configHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ERC20_PRIMARY_OFFER_CONFIG_V1"),
                block.chainid,
                address(artistOffers),
                p.config
            )
        );
        require(
            artistOffers.saleRecord(p.id).configHash == configHash
                && artistOffers.nextSaleNonce() == p.nonce + 1,
            "original complete offer config and creation identity"
        );
        if (consent) _erc20ArtistConsent(p);
        q.authorization = _erc20SellerAuthorization(p, q.selection);
        q.sellerProof = OfferPrivate.Signature(
            address(joinedCollector),
            2,
            _joinedProof(joinedCollector, _erc20SellerDigest(q.authorization))
        );
        q.buyerProof = OfferPrivate.Signature(
            address(joinedBuyer), 2, _joinedProof(joinedBuyer, p.config.offerDigest)
        );
        vm.warp(p.config.startsAt);
    }

    function _erc20OfferGate(ERC20OfferPlan memory p, OfferE20.Acceptance memory q)
        private
        returns (IStreamMintManager.MintGateConfig memory gate)
    {
        // One complete published empty work. Zero content ID remains a valid selected identity.
        p.config.tokenDataHash = keccak256(q.selection.tokenData);
        p.leaf = keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CONTENT_LEAF_V1"),
                        block.chainid,
                        address(artistOffers),
                        p.id,
                        bytes32(0),
                        p.config.tokenDataHash
                    )
                )
            )
        );
        p.config.contentManifestRoot = p.leaf;
        StreamPreparedNativeContentTypes.Row[] memory rows =
            new StreamPreparedNativeContentTypes.Row[](1);
        rows[0] = StreamPreparedNativeContentTypes.Row(
            0, p.config.tokenDataHash, "urn:stream:actual-offer:empty-work"
        );
        p.gate = StreamERC20OfferGate(
            _artistArtifactCreate(
                "smart-contracts/domains/mint/StreamERC20OfferGate.sol:StreamERC20OfferGate",
                abi.encode(
                    address(manager),
                    address(artistOffers),
                    p.id,
                    uint256(1),
                    p.config.phaseId,
                    p.counter,
                    rows
                )
            )
        );
        _assertDeployableProductionInstance(address(p.gate));
        require(
            keccak256(abi.encode(p.gate.publication()))
                    == keccak256(
                        abi.encode(
                            StreamPreparedNativeContentTypes.Publication(
                                block.chainid,
                                address(manager),
                                address(artistOffers),
                                p.id,
                                1,
                                p.config.phaseId,
                                p.leaf,
                                keccak256(abi.encode(rows)),
                                p.counter
                            )
                        )
                    ) && p.gate.itemCount() == 1
                && keccak256(p.gate.manifestBytes()) == keccak256(abi.encode(rows)),
            "complete original selected publication"
        );
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](1);
        records[0] = StreamModuleRegistration(
            address(p.gate),
            keccak256("6529STREAM_MINT_GATE_V1"),
            OFFER_GATE_VERSION,
            type(IStreamMintGate).interfaceId,
            800000,
            address(p.gate).codehash,
            DEPLOYMENT_HASH,
            p.gate.gateConfigHash(),
            "urn:stream:actual-offer:gate"
        );
        _erc20OfferRegister(records);
        gate = IStreamMintManager.MintGateConfig(
            address(p.gate),
            p.gate.gateConfigHash(),
            address(p.gate).codehash,
            keccak256(abi.encode(OFFER_GATE_VERSION, p.gate.gateConfigHash())),
            0,
            800000
        );
        q.selection.content.tokenDataHash = p.config.tokenDataHash;
    }

    function _erc20OfferPhase(
        ERC20OfferPlan memory p,
        IStreamMintManager.MintGateConfig memory gate,
        bool selected
    ) private {
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = p.counter;
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            selected
                ? IStreamMintManager.CounterKeyMode.CONTEXT
                : IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            selected ? 1 : 5,
            1,
            keccak256(abi.encode("actual ERC20 offer cap", p.id))
        );
        IStreamMintManager.MintPhaseConfig memory phase = IStreamMintManager.MintPhaseConfig(
            false, 0, 0, 1, OFFER_DELEGATION_BASE, OFFER_DELEGATION_BASE
        );
        address[] memory allowed = new address[](0);
        _erc20PolicyConsent(
            p.config.phaseId,
            manager.previewPhasePolicyHash(1, p.config.phaseId, phase, gate, ids, counters, allowed)
        );
        this.joinedGovern(
            address(manager),
            abi.encodeCall(
                manager.configurePhase, (1, p.config.phaseId, phase, gate, ids, counters)
            )
        );
        allowed = new address[](1);
        allowed[0] = address(artistOffers);
        bytes32 hash = manager.previewPhasePolicyHash(
            1, p.config.phaseId, phase, gate, ids, counters, allowed
        );
        _erc20PolicyConsent(p.config.phaseId, hash);
        this.joinedGovern(
            address(manager),
            abi.encodeCall(
                manager.setPhaseExecutor, (1, p.config.phaseId, address(artistOffers), true)
            )
        );
        require(
            manager.phasePolicyHash(1, p.config.phaseId) == hash
                && ledger.registeredPhasePolicyHash(address(manager), 1, p.config.phaseId) == hash,
            "actual Artist-approved Manager and Ledger policy"
        );
        artists.requireMintConsent(1, p.config.phaseId, hash);
    }

    function _erc20ArtistAuthorization() private view returns (T.Authorization memory) {
        return T.Authorization(
            artists.artistAuthorizationState(fixtureArtistId, 0, 0).nextUnusedNonce,
            this.artistERC20OfferTime() + 1 days,
            ""
        );
    }

    function _erc20PolicyConsent(bytes32 phase, bytes32 hash) private {
        _joinedSafe(
            joinedArtist,
            address(artists),
            0,
            abi.encodeCall(
                artists.recordPolicyConsent,
                (T.PolicyConsent(1, phase, hash), _erc20ArtistAuthorization())
            )
        );
    }

    function _erc20ArtistConsent(ERC20OfferPlan memory p) internal {
        OfferConsent.Consent memory terms = OfferConsent.Consent(
            1, address(artistOffers), p.id, artistOffers.saleRecord(p.id).configHash
        );
        _joinedSafe(
            joinedArtist,
            address(artists),
            0,
            abi.encodeCall(
                IStreamArtistSaleAuthority.recordSaleConsent, (terms, _erc20ArtistAuthorization())
            )
        );
        (bool approved, bytes32 hash) = artists.isSaleConsented(1, p.id, terms.saleConfigHash);
        OfferConsent.Record memory record = artists.saleConsentRecord(hash);
        require(
            artists.saleConsentScope(1) == 1 && approved && record.signer == address(joinedArtist)
                && record.artistId == fixtureArtistId
                && keccak256(abi.encode(record.terms)) == keccak256(abi.encode(terms)),
            "actual Artist operation16 preserves original sale and signer"
        );
    }

    function _erc20SellerAuthorization(ERC20OfferPlan memory p, OfferE20.Selection memory selected)
        private
        view
        returns (OfferSale.SaleAuthorization memory a)
    {
        address[] memory buyer = new address[](1);
        buyer[0] = address(joinedBuyer);
        bytes[] memory data = new bytes[](1);
        data[0] = selected.tokenData;
        bytes32[] memory commitments = new bytes32[](1);
        commitments[0] = selected.mintCommitment;
        a.chainId = block.chainid;
        a.saleAdapter = address(artistOffers);
        a.mintManager = address(manager);
        a.collectionId = 1;
        a.phaseId = p.config.phaseId;
        a.saleId = p.id;
        a.saleKind = 6;
        a.revenueClass = PRIMARY_REVENUE_CLASS;
        a.expectedPrimaryPolicyHash = p.config.expectedPrimaryPolicyHash;
        a.initialRecipientsHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), buyer));
        a.beneficiariesHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), buyer));
        a.tokenDataArrayHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), data));
        a.mintCommitmentsHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), commitments));
        a.payer = address(joinedBuyer);
        a.executor = address(joinedBuyer);
        a.asset = address(offerToken);
        a.unitPrice = 1000;
        a.quantity = 1;
        a.contentSelectionHash = p.leaf;
        a.policyHash = p.config.mintPolicyHash;
        a.nonce = keccak256(abi.encode("actual original ERC20 seller authorization", p.id));
        a.deadline = p.config.endsAt;
    }

    function _erc20Typed(address target, string memory name, bytes32 body)
        private
        view
        returns (bytes32)
    {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256("1"),
                block.chainid,
                target
            )
        );
        return keccak256(abi.encodePacked(hex"1901", domain, body));
    }

    function _erc20SellerDigest(OfferSale.SaleAuthorization memory a)
        internal
        view
        returns (bytes32 digest)
    {
        digest = _erc20Typed(
            address(artistOffers),
            "6529Stream Sales",
            keccak256(
                abi.encode(
                    keccak256(
                        "SaleAuthorization(uint256 chainId,address saleAdapter,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 saleId,uint8 saleKind,bytes32 revenueClass,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,address payer,address executor,address asset,uint256 unitPrice,uint256 quantity,bytes32 contentSelectionHash,bytes32 policyHash,bytes32 nonce,uint64 deadline,uint64 finalizeBy)"
                    ),
                    a
                )
            )
        );
        require(
            digest == artistOffers.authorizationDigest(a),
            "independent full original seller authorization"
        );
    }

    function _erc20BuyerDigest(OfferSale.SaleOffer memory offer)
        internal
        view
        returns (bytes32 digest)
    {
        digest = _erc20Typed(
            address(artistOffers),
            "6529Stream Sales",
            keccak256(
                abi.encode(
                    keccak256(
                        "SaleOffer(uint256 chainId,address saleAdapter,address core,uint256 collectionId,uint256 tokenId,bytes32 contentSelectionHash,address buyer,address asset,uint256 price,bytes32 nonce,uint64 deadline,uint64 finalizeBy)"
                    ),
                    offer
                )
            )
        );
        require(digest == artistOffers.offerDigest(offer), "independent full original buyer offer");
    }

    function _erc20Intent(ERC20OfferPlan memory p)
        internal
        pure
        returns (PrimaryE20.PaymentIntent memory)
    {
        return PrimaryE20.PaymentIntent(
            p.config.buyer,
            p.config.asset,
            p.config.price,
            p.id,
            p.config.expectedPrimaryPolicyHash,
            keccak256(abi.encode("actual payer payment intent", p.id)),
            p.config.endsAt
        );
    }

    function _erc20IntentDigest(PrimaryE20.PaymentIntent memory intent)
        internal
        view
        returns (bytes32 digest)
    {
        digest = _erc20Typed(
            address(offerPayment),
            "6529StreamPaymentIntentVerifier",
            keccak256(
                abi.encode(
                    keccak256(
                        "StreamPaymentIntent(address payer,address asset,uint256 maxAmount,bytes32 saleRef,bytes32 expectedPrimaryPolicyHash,bytes32 nonce,uint64 deadline)"
                    ),
                    intent
                )
            )
        );
        require(
            digest == offerPayment.paymentIntentDigest(intent),
            "independent payer-only payment intent domain"
        );
    }

    function _erc20DelegateExecutor(ERC20OfferPlan memory p, OfferE20.Acceptance memory q)
        internal
    {
        _joinedSafe(
            joinedBuyer,
            address(offerDelegates),
            0,
            abi.encodeCall(
                offerDelegates.registerDelegationAddress,
                (
                    address(core),
                    address(joinedCollaborator),
                    uint256(p.config.endsAt),
                    uint256(2),
                    true,
                    uint256(0)
                )
            )
        );
        q.authorization.executor = address(joinedCollaborator);
        q.sellerProof.signature = _joinedProof(joinedCollector, _erc20SellerDigest(q.authorization));
    }

    function _erc20SafePayload(OfficialSafe safe, bytes memory data)
        internal
        returns (bytes memory)
    {
        bytes32 hash = safe.getTransactionHash(
            address(offerPayment), 0, data, 0, 0, 0, 0, address(0), address(0), safe.nonce()
        );
        return abi.encodeCall(
            safe.execTransaction,
            (
                address(offerPayment),
                uint256(0),
                data,
                uint8(0),
                uint256(0),
                uint256(0),
                uint256(0),
                address(0),
                payable(address(0)),
                safeThresholdSignature(joinedKeys, hash)
            )
        );
    }

    function _erc20SafeFailure(OfficialSafe safe, bytes memory exact) internal {
        uint256 nonce = safe.nonce();
        (bool ok, bytes memory reason) = address(safe).call(exact);
        require(
            !ok && keccak256(reason) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && safe.nonce() == nonce,
            "failed original Safe envelope restores nonce"
        );
    }

    function _erc20SafeSuccess(OfficialSafe safe, bytes memory exact) internal {
        uint256 nonce = safe.nonce();
        (bool ok, bytes memory result) = address(safe).call(exact);
        require(
            ok && abi.decode(result, (bool)) && safe.nonce() == nonce + 1,
            "original signed Safe envelope succeeds once"
        );
    }

    function _erc20OfferKey(PrimaryE20.ERC20SettlementCandidate memory c)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_SETTLEMENT_KEY_V2"),
                block.chainid,
                address(joinedRecorder),
                address(artistOffers),
                c.executionBinding.executionId
            )
        );
    }

    function _erc20Counter(ERC20OfferPlan memory p) internal view returns (bytes32) {
        bytes32 context = p.leaf == 0
            ? bytes32(0)
            : keccak256(
                abi.encode(
                    keccak256("6529STREAM_CONTENT_CONTEXT_V1"),
                    block.chainid,
                    address(artistOffers),
                    p.id,
                    p.config.contentId
                )
            );
        IStreamMintManager.CounterKeyMode mode = p.leaf == 0
            ? IStreamMintManager.CounterKeyMode.RECIPIENT
            : IStreamMintManager.CounterKeyMode.CONTEXT;
        bytes32 subject = manager.previewSubjectKey(
            mode,
            1,
            p.config.phaseId,
            p.counter,
            address(joinedBuyer),
            address(joinedBuyer),
            address(artistOffers),
            address(joinedBuyer),
            context
        );
        return manager.previewCounterValueKey(1, p.config.phaseId, p.counter, subject);
    }

    function _assertERC20OfferUnused(
        ERC20OfferPlan memory p,
        OfferE20.Acceptance memory q,
        PrimaryE20.ERC20SettlementCandidate memory c,
        bytes32 intentNonce
    ) internal view {
        require(
            !artistOffers.digestConsumed(_erc20SellerDigest(q.authorization))
                && !ledger.isManagerAuthorizationUsed(
                    address(manager),
                    StreamMintTicketHash.authorizationId(_erc20BuyerDigest(q.offer))
                )
                && !ledger.isManagerOperationRootUsed(
                    address(manager), c.operationIdentityCommitment
                ) && !offerPayment.isPaymentIntentNonceUsed(address(joinedBuyer), intentNonce)
                && !joinedRecorder.settlementConsumed(_erc20OfferKey(c))
                && joinedRecorder.settlementResult(_erc20OfferKey(c)).candidateCommitment == 0
                && artistOffers.executionRecord(c.executionBinding.executionId).saleId == 0
                && artistOffers.saleRecord(p.id).status == 1
                && artistOffers.nextExecutionNonce(p.id, address(joinedBuyer)) == 1
                && ledger.counterValue(_erc20Counter(p)) == 0,
            "all original authority receipt and counter stores unused"
        );
        require(
            core.totalSupply() == 0 && core.collectionMintedEver(1) == 0
                && core.lastAllocatedTokenId() == 0 && core.collectionNextSerial(1) == 1
                && core.pendingPreparedMintTokenId() == 0 && manager.nextOperationNonce() == 0
                && entropy.revealFeeEscrow(1) == 0
                && joinedRecorder.totalOfficialSettled(address(offerToken)) == 0
                && revenueEscrow.totalOwed(address(offerToken)) == 0
                && offerToken.balanceOf(address(joinedBuyer)) == 10000
                && offerToken.allowance(address(joinedBuyer), address(offerPayment)) == 10000
                && offerToken.balanceOf(wallet) == 0
                && offerToken.balanceOf(address(offerPayment)) == 0
                && offerToken.balanceOf(address(joinedRecorder)) == 0
                && offerToken.balanceOf(address(artistOffers)) == 0
                && offerToken.transferCalls() == 0
                && offerPayment.phase() == StreamERC20PrimarySettlementAdapter.Phase.IDLE,
            "entire real mint token pull routing allowance and payment phase roll back"
        );
    }

    function _assertERC20OfferExecuted(
        ERC20OfferPlan memory p,
        OfferE20.Acceptance memory q,
        PrimaryE20.ERC20SettlementCandidate memory c
    ) internal view {
        OfferE20.ExecutionRecord memory e = artistOffers.executionRecord(
            c.executionBinding.executionId
        );
        require(
            e.saleId == p.id && e.buyer == address(joinedBuyer)
                && e.executor == q.authorization.executor && e.executionNonce == 1 && e.tokenId == 1
                && e.offerDigest == _erc20BuyerDigest(q.offer)
                && e.authorizationDigest == _erc20SellerDigest(q.authorization)
                && e.authorizationId == StreamMintTicketHash.authorizationId(e.offerDigest)
                && e.contentLeaf == p.leaf && e.tokenDataHash == keccak256(q.selection.tokenData)
                && e.operationRoot == c.operationIdentityCommitment
                && e.operationId == c.operationId && e.settlementKey == _erc20OfferKey(c),
            "complete original ERC20 offer execution record"
        );
        PrimaryE20.PrimarySettlementResult memory expected = PrimaryE20.PrimarySettlementResult(
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_ERC20_SETTLEMENT_CANDIDATE_V2"),
                    block.chainid,
                    address(offerPayment),
                    address(joinedRecorder),
                    c
                )
            ),
            e.settlementKey,
            profile,
            wallet,
            address(offerToken),
            1000,
            q.authorization.executor,
            c.executionBinding.executionId,
            false,
            e.operationRoot,
            p.config.mintPolicyHash,
            p.config.mintPolicyHash
        );
        require(
            keccak256(abi.encode(joinedRecorder.settlementResult(e.settlementKey)))
                    == keccak256(abi.encode(expected))
                && joinedRecorder.settlementConsumed(e.settlementKey)
                && artistOffers.digestConsumed(e.authorizationDigest)
                && !artistOffers.digestRevoked(e.authorizationDigest)
                && ledger.isManagerAuthorizationUsed(address(manager), e.authorizationId)
                && !ledger.isManagerAuthorizationUsed(
                    address(manager), StreamMintTicketHash.authorizationId(e.authorizationDigest)
                ) && ledger.isManagerOperationRootUsed(address(manager), e.operationRoot)
                && ledger.counterValue(_erc20Counter(p)) == 1,
            "all twelve receipt fields and distinct original replay stores"
        );
        require(
            core.ownerOf(1) == address(joinedBuyer)
                && keccak256(core.tokenData(1)) == keccak256(q.selection.tokenData)
                && core.totalSupply() == 1 && core.collectionMintedEver(1) == 1
                && core.collectionNextSerial(1) == 2 && core.pendingPreparedMintTokenId() == 0
                && manager.nextOperationNonce() == 1 && entropy.revealFeeEscrow(1) == 0
                && offerToken.balanceOf(address(joinedBuyer)) == 9000
                && offerToken.allowance(address(joinedBuyer), address(offerPayment)) == 9000
                && offerToken.balanceOf(wallet) == 1000
                && offerToken.balanceOf(address(offerPayment)) == 0
                && offerToken.balanceOf(address(joinedRecorder)) == 0
                && offerToken.balanceOf(address(artistOffers)) == 0
                && offerToken.transferCalls() == 3
                && joinedRecorder.totalOfficialSettled(address(offerToken)) == 1000
                && artistOffers.saleRecord(p.id).status == 4
                && artistOffers.nextExecutionNonce(p.id, address(joinedBuyer)) == 2
                && offerPayment.phase() == StreamERC20PrimarySettlementAdapter.Phase.IDLE,
            "one current mint and exact original payer token flow without retained custody"
        );
    }
}
