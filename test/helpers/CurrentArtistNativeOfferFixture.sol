// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CurrentDynamicRoyaltyCommerceFixture.sol";
import { IStreamMintGate } from "../../smart-contracts/interfaces/stream/mint/IStreamMintGate.sol";
import {
    StreamPreparedNativeSettlementAdmission
} from "../../smart-contracts/domains/revenue/StreamPreparedNativeSettlementAdmission.sol";
import {
    StreamNativePrimaryOfferSale
} from "../../smart-contracts/domains/mint/StreamNativePrimaryOfferSale.sol";
import {
    StreamNativePrimaryOfferGate
} from "../../smart-contracts/domains/mint/StreamNativePrimaryOfferGate.sol";
import {
    StreamNativeCuratedSaleBase
} from "../../smart-contracts/domains/mint/StreamNativeCuratedSaleBase.sol";
import {
    StreamNativeCuratedSaleState
} from "../../smart-contracts/domains/mint/StreamNativeCuratedSaleState.sol";
import {
    StreamNativePrimaryOfferTypes as NativeOffer
} from "../../smart-contracts/interfaces/stream/mint/StreamNativePrimaryOfferTypes.sol";
import {
    StreamNativeCuratedSaleTypes as NativeOfferSale
} from "../../smart-contracts/interfaces/stream/mint/StreamNativeCuratedSaleTypes.sol";
import {
    StreamPreparedNativeContentTypes as NativeOfferContent
} from "../../smart-contracts/interfaces/stream/mint/StreamPreparedNativeContentTypes.sol";
import {
    StreamPreparedNativeOfferTypes as NativeOfferPurchase
} from "../../smart-contracts/interfaces/stream/mint/StreamPreparedNativeOfferTypes.sol";
import {
    StreamPreparedNativeSettlementTypes as NativeOfferPrepared
} from "../../smart-contracts/interfaces/stream/revenue/StreamPreparedNativeSettlementTypes.sol";
import {
    StreamNativeSettlementTypes
} from "../../smart-contracts/interfaces/stream/revenue/StreamNativeSettlementTypes.sol";
import {
    IStreamPreparedNativeOfferMint,
    IStreamPreparedNativeOfferSettlement
} from "../../smart-contracts/interfaces/stream/mint/IStreamPreparedNativeOfferMint.sol";
import {
    IStreamPreparedNativeSaleBinding
} from "../../smart-contracts/interfaces/stream/revenue/IStreamPreparedNativeSaleBinding.sol";
import {
    StreamPreparedNativeSettlementHash
} from "../../smart-contracts/domains/revenue/StreamPreparedNativeSettlementHash.sol";
import {
    StreamPrimarySettlementHash
} from "../../smart-contracts/domains/revenue/StreamPrimarySettlementHash.sol";
import {
    StreamPreparedNativeContentHash
} from "../../smart-contracts/domains/mint/StreamPreparedNativeContentHash.sol";
import {
    StreamArtistSaleTypes as NativeOfferArtistSale
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistSaleTypes.sol";
import {
    IStreamArtistSaleAuthority
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistSaleAuthority.sol";
import {
    IStreamArtistAuthorizationRevocation
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorizationRevocation.sol";

/// @dev Actual Artist, Governor, Registry, Manager, Ledger, Core, recorder and entropy coordinator.
/// Only the inherited external entropy service is a double. Products use original artifact CREATE.
abstract contract CurrentArtistNativeOfferFixture is CurrentDynamicRoyaltyCommerceFixture {
    uint256 internal constant ARTIST_NATIVE_OFFER_PRICE = 1000;
    bytes32 private constant OFFER_GATE_VERSION =
        keccak256("6529STREAM_NATIVE_PRIMARY_OFFER_GATE_V1");
    bytes32 private constant OFFER_MANIFEST = keccak256("actual Artist native offer registration");
    StreamNativePrimaryOfferSale internal artistNativeOffers;

    struct ArtistNativeOfferPlan {
        bytes32 id;
        uint256 nonce;
        bytes32 counter;
        bytes32 leaf;
        StreamNativePrimaryOfferGate gate;
        NativeOffer.Configuration config;
    }

    struct ArtistNativeOfferReceipt {
        NativeOfferSale.ExecutionRecord execution;
        NativeOfferPrepared.Facts facts;
        NativeOfferPrepared.Intent intent;
        NativeOfferContent.Facts content;
    }

    function _fixtureSaleConsentScope() internal pure override returns (uint8) {
        return 1;
    }

    function artistNativeOfferTime() external view returns (uint64) {
        return uint64(block.timestamp);
    }

    function _deployArtistNativeOffers() internal {
        _deployJoinedCommerce();
        StreamNativeCuratedSaleBase.DeploymentConfig memory d;
        d.manager = manager;
        d.recorder = joinedRecorder;
        d.platform = vm.addr(PLATFORM_KEY);
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
        d.parameters[3] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_NFT_DELIVERY_GAS_LIMIT", 300000, 100000, 2
        );
        artistNativeOffers = StreamNativePrimaryOfferSale(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/mint/StreamNativePrimaryOfferSale.sol:StreamNativePrimaryOfferSale",
                    abi.encode(d)
                ))
        );
        _assertDeployableProductionInstance(address(artistNativeOffers));
        artistNativeOffers.transferOwnership(address(joinedCollaborator));
        _nativeOfferRegister(
            StreamModuleRegistration(
                address(artistNativeOffers),
                keccak256("NATIVE_PREPARED_SALE_ADAPTER"),
                keccak256("6529STREAM_PREPARED_NATIVE_SETTLEMENT_V1"),
                type(IStreamPreparedNativeSaleBinding).interfaceId,
                500000,
                address(artistNativeOffers).codehash,
                DEPLOYMENT_HASH,
                OFFER_MANIFEST,
                "urn:current:artist-native-offer"
            )
        );
        StreamPreparedNativeSettlementAdmission.requireModule(
            address(registry), address(artistNativeOffers)
        );
        require(
            artistNativeOffers.owner() == address(joinedCollaborator)
                && address(artistNativeOffers.mintManager()) == address(manager)
                && address(artistNativeOffers.primarySaleSettlement()) == address(joinedRecorder),
            "separate owner and original production bindings"
        );
    }

    function _nativeOfferRegister(StreamModuleRegistration memory record) private {
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](1);
        records[0] = record;
        (GovernanceCall[] memory calls, bytes[] memory datas) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        _joinedBatch(calls, datas);
        StreamModuleRecord memory actual = registry.moduleRecord(record.module);
        require(
            actual.status == ModuleRegistryStatus.ACTIVE
                && actual.runtimeCodeHash == record.module.codehash,
            "actual delayed Governor Safe admission"
        );
    }

    function _openArtistNativeOffer(bool selected, bool consent)
        internal
        returns (ArtistNativeOfferPlan memory p, NativeOffer.Acceptance memory q)
    {
        p.nonce = artistNativeOffers.nextSaleNonce();
        p.config.sale.phaseId = keccak256(abi.encode("actual Artist native offer phase", p.nonce));
        p.id = artistNativeOffers.saleIdFor(6, 1, p.config.sale.phaseId, p.nonce);
        p.counter = keccak256(abi.encode("actual Artist native offer counter", p.id));
        q.selection.tokenData =
            selected ? bytes("") : bytes("original collection-level native offer artwork");
        q.selection.recipient = address(joinedBuyer);
        q.selection.purchaseNonce = 1;
        q.selection.mintCommitment = keccak256(abi.encode("actual native offer commitment", p.id));
        if (selected) {
            p.config.contentId = 0;
            p.config.tokenDataHash = keccak256(q.selection.tokenData);
            p.leaf = keccak256(
                bytes.concat(
                    keccak256(
                        abi.encode(
                            keccak256("6529STREAM_CONTENT_LEAF_V1"),
                            block.chainid,
                            address(artistNativeOffers),
                            p.id,
                            p.config.contentId,
                            p.config.tokenDataHash
                        )
                    )
                )
            );
            p.config.sale.contentManifestRoot = p.leaf;
            NativeOfferContent.Row[] memory rows = new NativeOfferContent.Row[](1);
            rows[0] = NativeOfferContent.Row(
                0, p.config.tokenDataHash, "urn:actual-native-offer:empty-work"
            );
            p.gate = StreamNativePrimaryOfferGate(
                _artistArtifactCreate(
                    "smart-contracts/domains/mint/StreamNativePrimaryOfferGate.sol:StreamNativePrimaryOfferGate",
                    abi.encode(
                        address(manager),
                        address(artistNativeOffers),
                        p.id,
                        uint256(1),
                        p.config.sale.phaseId,
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
                                NativeOfferContent.Publication(
                                    block.chainid,
                                    address(manager),
                                    address(artistNativeOffers),
                                    p.id,
                                    1,
                                    p.config.sale.phaseId,
                                    p.leaf,
                                    keccak256(abi.encode(rows)),
                                    p.counter
                                )
                            )
                        ) && p.gate.itemCount() == 1
                    && keccak256(p.gate.manifestBytes()) == keccak256(abi.encode(rows)),
                "exact original publication and manifest"
            );
            _nativeOfferRegister(
                StreamModuleRegistration(
                    address(p.gate),
                    keccak256("6529STREAM_MINT_GATE_V1"),
                    OFFER_GATE_VERSION,
                    type(IStreamMintGate).interfaceId,
                    800000,
                    address(p.gate).codehash,
                    DEPLOYMENT_HASH,
                    p.gate.gateConfigHash(),
                    "urn:current:artist-native-offer-gate"
                )
            );
            q.selection.content.tokenDataHash = p.config.tokenDataHash;
        }
        _nativeOfferPhase(p);
        _joinedSafe(
            joinedCollaborator,
            address(artistNativeOffers),
            0,
            abi.encodeCall(
                artistNativeOffers.configureCollectionSigner,
                (
                    uint256(1),
                    address(joinedCollector),
                    uint8(2),
                    keccak256("actual native offer seller membership"),
                    true
                )
            )
        );
        NativeOfferSale.CollectionSigner memory member =
            artistNativeOffers.collectionSigner(1, address(joinedCollector), 2);
        p.config.buyer = address(joinedBuyer);
        p.config.signer = address(joinedCollector);
        p.config.signerKind = 2;
        p.config.signerEvidenceHash = member.evidenceHash;
        p.config.signerRevision = member.revision;
        p.config.signerAuthority = member.authority;
        p.config.sale.collectionId = 1;
        p.config.sale.price = ARTIST_NATIVE_OFFER_PRICE;
        p.config.sale.poster = address(joinedCollaborator);
        p.config.sale.startsAt = this.artistNativeOfferTime() + 1;
        p.config.sale.endsAt = p.config.sale.startsAt + 7 days;
        p.config.sale.mintPolicyHash = manager.phasePolicyHash(1, p.config.sale.phaseId);
        p.config.sale.expectedPrimaryPolicyHash = _nativePrimaryPolicyHash();
        q.offer = StreamPrivateSaleTypes.SaleOffer(
            block.chainid,
            address(artistNativeOffers),
            address(core),
            1,
            0,
            p.leaf,
            address(joinedBuyer),
            address(0),
            ARTIST_NATIVE_OFFER_PRICE,
            keccak256(abi.encode("actual buyer native offer", p.id)),
            p.config.sale.endsAt,
            0
        );
        p.config.offerDigest = _nativeOfferBuyerDigest(q.offer);
        _joinedSafe(
            joinedCollaborator,
            address(artistNativeOffers),
            0,
            abi.encodeCall(
                artistNativeOffers.registerPrimaryOffer, (p.config, q.selection.content.proof)
            )
        );
        require(
            artistNativeOffers.saleRecord(p.id).configHash
                    == artistNativeOffers.primaryOfferConfigurationHash(p.config)
                && artistNativeOffers.saleRecord(p.id).configHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_NATIVE_PRIMARY_OFFER_CONFIG_V1"),
                            block.chainid,
                            address(artistNativeOffers),
                            p.config
                        )
                    ) && artistNativeOffers.nextSaleNonce() == p.nonce + 1,
            "original full sale configuration"
        );
        if (consent) _nativeOfferConsent(p);
        q.authorization = _nativeOfferAuthorization(p, q.selection);
        q.sellerProof = IStreamPrivateSaleAdapter.Signature(
            address(joinedCollector),
            2,
            _joinedProof(joinedCollector, _nativeOfferSellerDigest(q.authorization))
        );
        q.buyerProof = IStreamPrivateSaleAdapter.Signature(
            address(joinedBuyer), 2, _joinedProof(joinedBuyer, p.config.offerDigest)
        );
        vm.warp(p.config.sale.startsAt);
    }

    function _nativeOfferPhase(ArtistNativeOfferPlan memory p) private {
        IStreamMintManager.MintGateConfig memory gate;
        if (address(p.gate) != address(0)) {
            gate = IStreamMintManager.MintGateConfig(
                address(p.gate),
                p.gate.gateConfigHash(),
                address(p.gate).codehash,
                keccak256(abi.encode(OFFER_GATE_VERSION, p.gate.gateConfigHash())),
                0,
                800000
            );
        }
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = p.counter;
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            p.leaf == 0
                ? IStreamMintManager.CounterKeyMode.RECIPIENT
                : IStreamMintManager.CounterKeyMode.CONTEXT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            1,
            1,
            keccak256(abi.encode("actual native offer cap one", p.id))
        );
        IStreamMintManager.MintPhaseConfig memory config =
            IStreamMintManager.MintPhaseConfig(false, 0, 0, 1, OFFER_MANIFEST, OFFER_MANIFEST);
        address[] memory allowed = new address[](0);
        _nativeOfferPolicyConsent(
            p,
            manager.previewPhasePolicyHash(
                1, p.config.sale.phaseId, config, gate, ids, counters, allowed
            )
        );
        this.joinedGovern(
            address(manager),
            abi.encodeCall(
                manager.configurePhase,
                (uint256(1), p.config.sale.phaseId, config, gate, ids, counters)
            )
        );
        allowed = new address[](1);
        allowed[0] = address(artistNativeOffers);
        bytes32 policy = manager.previewPhasePolicyHash(
            1, p.config.sale.phaseId, config, gate, ids, counters, allowed
        );
        _nativeOfferPolicyConsent(p, policy);
        this.joinedGovern(
            address(manager),
            abi.encodeCall(
                manager.setPhaseExecutor,
                (uint256(1), p.config.sale.phaseId, address(artistNativeOffers), true)
            )
        );
        require(
            manager.phasePolicyHash(1, p.config.sale.phaseId) == policy
                && ledger.registeredPhasePolicyHash(address(manager), 1, p.config.sale.phaseId)
                    == policy,
            "Artist-approved actual Manager and Ledger policy"
        );
        artists.requireMintConsent(1, p.config.sale.phaseId, policy);
    }

    function _nativeOfferArtistAuthorization() private view returns (T.Authorization memory) {
        return T.Authorization(
            IStreamArtistAuthorizationRevocation(address(artists))
            .artistAuthorizationState(fixtureArtistId, bytes32(0), 0)
            .nextUnusedNonce,
            this.artistNativeOfferTime() + 1 days,
            ""
        );
    }

    function _nativeOfferPolicyConsent(ArtistNativeOfferPlan memory p, bytes32 policy) private {
        _joinedSafe(
            joinedArtist,
            address(artists),
            0,
            abi.encodeCall(
                artists.recordPolicyConsent,
                (
                    T.PolicyConsent(1, p.config.sale.phaseId, policy),
                    _nativeOfferArtistAuthorization()
                )
            )
        );
    }

    function _nativeOfferConsent(ArtistNativeOfferPlan memory p) internal {
        NativeOfferArtistSale.Consent memory consent = NativeOfferArtistSale.Consent(
            1, address(artistNativeOffers), p.id, artistNativeOffers.saleRecord(p.id).configHash
        );
        _joinedSafe(
            joinedArtist,
            address(artists),
            0,
            abi.encodeCall(
                IStreamArtistSaleAuthority.recordSaleConsent,
                (consent, _nativeOfferArtistAuthorization())
            )
        );
        (bool approved, bytes32 hash) = artists.isSaleConsented(1, p.id, consent.saleConfigHash);
        NativeOfferArtistSale.Record memory record = artists.saleConsentRecord(hash);
        require(
            artists.saleConsentScope(1) == 1 && approved && record.signer == address(joinedArtist)
                && record.artistId == fixtureArtistId
                && keccak256(abi.encode(record.terms)) == keccak256(abi.encode(consent)),
            "actual Artist operation16 for original sale"
        );
    }

    function _nativeOfferAuthorization(
        ArtistNativeOfferPlan memory p,
        NativeOfferSale.Selection memory chosen
    ) private view returns (StreamPrivateSaleTypes.SaleAuthorization memory a) {
        address[] memory recipients = new address[](1);
        recipients[0] = address(artistNativeOffers);
        address[] memory beneficiaries = new address[](1);
        beneficiaries[0] = address(joinedBuyer);
        bytes[] memory data = new bytes[](1);
        data[0] = chosen.tokenData;
        bytes32[] memory commitments = new bytes32[](1);
        commitments[0] = chosen.mintCommitment;
        a.chainId = block.chainid;
        a.saleAdapter = address(artistNativeOffers);
        a.mintManager = address(manager);
        a.collectionId = 1;
        a.phaseId = p.config.sale.phaseId;
        a.saleId = p.id;
        a.saleKind = 6;
        a.revenueClass = PRIMARY_REVENUE_CLASS;
        a.expectedPrimaryPolicyHash = p.config.sale.expectedPrimaryPolicyHash;
        a.initialRecipientsHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), recipients));
        a.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), beneficiaries)
        );
        a.tokenDataArrayHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), data));
        a.mintCommitmentsHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), commitments));
        a.payer = address(joinedBuyer);
        a.executor = address(joinedBuyer);
        a.unitPrice = ARTIST_NATIVE_OFFER_PRICE;
        a.quantity = 1;
        a.contentSelectionHash = p.leaf;
        a.policyHash = p.config.sale.mintPolicyHash;
        a.nonce = keccak256(abi.encode("actual seller native acceptance", p.id));
        a.deadline = p.config.sale.endsAt;
    }

    function _nativeOfferTyped(bytes32 body) private view returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream Sales"),
                keccak256("1"),
                block.chainid,
                address(artistNativeOffers)
            )
        );
        return keccak256(abi.encodePacked(hex"1901", domain, body));
    }

    function _nativeOfferBuyerDigest(StreamPrivateSaleTypes.SaleOffer memory offer)
        internal
        view
        returns (bytes32 digest)
    {
        digest = _nativeOfferTyped(
            keccak256(
                abi.encode(
                    keccak256(
                        "SaleOffer(uint256 chainId,address saleAdapter,address core,uint256 collectionId,uint256 tokenId,bytes32 contentSelectionHash,address buyer,address asset,uint256 price,bytes32 nonce,uint64 deadline,uint64 finalizeBy)"
                    ),
                    offer
                )
            )
        );
        require(
            digest == artistNativeOffers.offerDigest(offer),
            "independent original twelve-field buyer digest"
        );
    }

    function _nativeOfferSellerDigest(StreamPrivateSaleTypes.SaleAuthorization memory a)
        internal
        view
        returns (bytes32 digest)
    {
        digest = _nativeOfferTyped(
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
            digest == artistNativeOffers.authorizationDigest(a),
            "independent original full seller digest"
        );
    }

    function _nativeOfferId(bytes32 digest) internal pure returns (bytes32) {
        return keccak256(abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), digest));
    }

    function _nativeOfferSafePayload(NativeOffer.Acceptance memory q, uint256 value)
        internal
        returns (bytes memory)
    {
        bytes memory data = abi.encodeCall(artistNativeOffers.acceptPrimaryOffer, (q));
        bytes32 hash = joinedBuyer.getTransactionHash(
            address(artistNativeOffers),
            value,
            data,
            0,
            0,
            0,
            0,
            address(0),
            address(0),
            joinedBuyer.nonce()
        );
        return abi.encodeCall(
            joinedBuyer.execTransaction,
            (
                address(artistNativeOffers),
                value,
                data,
                uint8(0),
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(joinedKeys, hash)
            )
        );
    }

    function _nativeOfferFailed(bytes memory exact) internal {
        uint256 nonce = joinedBuyer.nonce();
        uint256 balance = address(joinedBuyer).balance;
        (bool ok, bytes memory out) = address(joinedBuyer).call(exact);
        require(
            !ok && keccak256(out) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && joinedBuyer.nonce() == nonce && address(joinedBuyer).balance == balance,
            "failed complete Safe envelope rolls back"
        );
    }

    function _nativeOfferSucceeded(bytes memory exact) internal {
        uint256 nonce = joinedBuyer.nonce();
        (bool ok, bytes memory out) = address(joinedBuyer).call(exact);
        require(
            ok && abi.decode(out, (bool)) && joinedBuyer.nonce() == nonce + 1,
            "original complete Safe envelope succeeds"
        );
    }

    function _nativeOfferCounter(ArtistNativeOfferPlan memory p) internal view returns (bytes32) {
        bytes32 subject;
        if (p.leaf == 0) {
            subject = keccak256(
                abi.encode(
                    keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1"),
                    block.chainid,
                    address(ledger),
                    IStreamMintManager.CounterKeyMode.RECIPIENT,
                    address(joinedBuyer)
                )
            );
        } else {
            subject = keccak256(
                abi.encode(
                    keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1"),
                    block.chainid,
                    address(ledger),
                    IStreamMintManager.CounterKeyMode.CONTEXT,
                    _nativeOfferContentContext(p)
                )
            );
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_VALUE_KEY_V1"),
                address(manager),
                uint256(1),
                p.config.sale.phaseId,
                p.counter,
                subject
            )
        );
    }

    function _nativeOfferContentContext(ArtistNativeOfferPlan memory p)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CONTENT_CONTEXT_V1"),
                block.chainid,
                address(artistNativeOffers),
                p.id,
                p.config.contentId
            )
        );
    }

    function _nativeOfferUnused(ArtistNativeOfferPlan memory p, NativeOffer.Acceptance memory q)
        internal
        view
    {
        require(
            !artistNativeOffers.digestConsumed(_nativeOfferSellerDigest(q.authorization))
                && !ledger.isManagerAuthorizationUsed(
                    address(manager), _nativeOfferId(p.config.offerDigest)
                ) && artistNativeOffers.nextPurchaseNonce(p.id, address(joinedBuyer)) == 1
                && artistNativeOffers.saleRecord(p.id).status == 1 && core.totalSupply() == 0
                && core.lastAllocatedTokenId() == 0 && core.collectionNextSerial(1) == 1
                && core.collectionMintedEver(1) == 0 && core.pendingPreparedMintTokenId() == 0
                && !core.preparedMint(1).exists && core.tokenData(1).length == 0
                && manager.nextOperationNonce() == 0
                && ledger.counterValue(_nativeOfferCounter(p)) == 0 && wallet.balance == 0
                && joinedRecorder.totalOfficialSettled(address(0)) == 0
                && revenueEscrow.totalOwed(address(0)) == 0 && entropy.revealFeeEscrow(1) == 0
                && artistNativeOffers.totalBuyerLiabilities() == 0
                && address(artistNativeOffers).balance == 0
                && IStreamPreparedNativeOfferMint(address(manager)).preparedNativeOfferAdmission()
                    == 0
                && IStreamPreparedNativeOfferMint(address(manager))
                .activePreparedNativeOfferContent()
                .operationRoot == 0 && manager.activePreparedNativeMint().operationRoot == 0,
            "no partial token counter replay receipt credit fee or offer admission"
        );
    }

    function artistNativeOfferRecorderAdmission(bool enabled) external {
        require(msg.sender == address(this), "fixture self");
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            revenueEscrow.creditProducerTransitionHashes(address(joinedRecorder), enabled);
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        bytes[] memory data = new bytes[](1);
        data[0] =
            abi.encodeCall(revenueEscrow.setCreditProducer, (address(joinedRecorder), enabled));
        calls[0] =
            StreamCurrentStackPlan.call(address(revenueEscrow), data[0], scope, oldHash, newHash);
        _joinedBatch(calls, data);
    }

    function _nativeOfferIntent(ArtistNativeOfferPlan memory p, NativeOffer.Acceptance memory q)
        internal
        view
        returns (NativeOfferPrepared.Intent memory i)
    {
        bytes32 purchase = artistNativeOffers.purchaseIdFor(p.id, address(joinedBuyer), 1);
        StreamNativeCuratedSaleState.Request memory request = StreamNativeCuratedSaleState.Request(
            p.id,
            address(joinedBuyer),
            q.selection,
            1,
            _nativeOfferSellerDigest(q.authorization),
            q.authorization,
            q.buyerProof,
            false
        );
        i = NativeOfferPrepared.Intent(
            1,
            p.config.sale.phaseId,
            p.id,
            p.nonce,
            address(joinedBuyer),
            address(joinedBuyer),
            address(joinedCollaborator),
            address(joinedBuyer),
            ARTIST_NATIVE_OFFER_PRICE,
            0,
            p.config.sale.expectedPrimaryPolicyHash,
            1,
            1,
            request.authorizationDigest,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_NATIVE_PRIMARY_OFFER_EXECUTION_V1"),
                    block.chainid,
                    address(artistNativeOffers),
                    artistNativeOffers.saleRecord(p.id).configHash,
                    purchase,
                    request
                )
            ),
            p.leaf,
            q.selection.mintCommitment,
            p.config.sale.mintPolicyHash
        );
    }

    function _nativeOfferReceipt(
        ArtistNativeOfferPlan memory p,
        NativeOffer.Acceptance memory q,
        Vm.Log[] memory logs,
        bool escrowed
    ) internal view returns (ArtistNativeOfferReceipt memory r) {
        bytes32 purchase = artistNativeOffers.purchaseIdFor(p.id, address(joinedBuyer), 1);
        r.execution = artistNativeOffers.executionRecord(purchase);
        bytes32 key = r.execution.settlementKey;
        uint256 records;
        uint256 contents;
        uint256 revenues;
        uint256 accepted;
        uint256 sellerConsumed;
        for (uint256 n; n < logs.length; ++n) {
            if (logs[n].emitter == address(artistNativeOffers) && logs[n].topics.length == 3) {
                if (
                    logs[n].topics[0]
                        == keccak256("SaleAuthorizationConsumed(uint16,bytes32,bytes32,address)")
                ) {
                    require(
                        logs[n].topics[1] == p.id
                            && logs[n].topics[2] == _nativeOfferSellerDigest(q.authorization)
                            && keccak256(logs[n].data)
                                == keccak256(abi.encode(uint16(1), address(joinedCollector))),
                        "original seller consumption receipt"
                    );
                    ++sellerConsumed;
                } else if (
                    logs[n].topics[0]
                        == keccak256(
                            "OfferAccepted(uint16,bytes32,address,bytes32,uint256,address)"
                        )
                ) {
                    require(
                        logs[n].topics[1] == p.id
                            && address(uint160(uint256(logs[n].topics[2]))) == address(joinedBuyer)
                            && keccak256(logs[n].data)
                                == keccak256(
                                    abi.encode(
                                        uint16(1),
                                        p.config.offerDigest,
                                        ARTIST_NATIVE_OFFER_PRICE,
                                        address(0)
                                    )
                                ),
                        "original buyer acceptance receipt"
                    );
                    ++accepted;
                }
            }
            if (logs[n].emitter != address(joinedRecorder) || logs[n].topics.length < 3) continue;
            if (
                logs[n].topics[0]
                    == keccak256(
                        "PreparedNativeOfferRevenueRecorded(bytes32,bytes32,bytes32,(address,address,address,bytes32,uint256,bytes32,bytes32,bytes32,bytes32,uint256,uint256,address,address,address,bytes32,bytes32,bytes32,bytes32),(uint256,bytes32,bytes32,uint256,address,address,address,address,uint256,uint8,bytes32,uint256,uint8,bytes32,bytes32,bytes32,bytes32,bytes32))"
                    )
            ) {
                require(
                    logs[n].topics.length == 4 && logs[n].data.length == 1152
                        && logs[n].topics[1] == key
                        && logs[n].topics[2]
                            == StreamPreparedNativeSettlementHash.saleKey(
                                address(joinedRecorder), address(artistNativeOffers), p.id, p.nonce
                            ),
                    "original offer revenue event identity"
                );
                (r.facts, r.intent) = abi.decode(
                    logs[n].data, (NativeOfferPrepared.Facts, NativeOfferPrepared.Intent)
                );
                require(
                    logs[n].topics[3] == StreamPreparedNativeSettlementHash.factsHash(r.facts),
                    "original facts event hash"
                );
                ++revenues;
            } else if (
                logs[n].topics[0]
                    == keccak256(
                        "PreparedNativeOfferContentRecorded(bytes32,bytes32,(bytes32,address,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32))"
                    )
            ) {
                require(
                    logs[n].topics.length == 3 && logs[n].data.length == 352
                        && logs[n].topics[1] == key,
                    "offer content event shape"
                );
                r.content = abi.decode(logs[n].data, (NativeOfferContent.Facts));
                require(
                    logs[n].topics[2] == StreamPreparedNativeContentHash.factsHash(r.content),
                    "offer content event hash"
                );
                ++contents;
            } else if (
                logs[n].topics[0]
                    == keccak256(
                        "PreparedNativeOfferRecorded(uint16,address,bytes32,bytes32,bytes32,uint256,bytes32,bytes32)"
                    )
            ) {
                require(
                    logs[n].topics.length == 4
                        && address(uint160(uint256(logs[n].topics[1])))
                            == address(artistNativeOffers) && logs[n].topics[2] == purchase
                        && logs[n].topics[3] == key
                        && keccak256(logs[n].data)
                            == keccak256(
                                abi.encode(
                                    uint16(1),
                                    p.id,
                                    p.nonce,
                                    p.config.offerDigest,
                                    _nativeOfferSellerDigest(q.authorization)
                                )
                            ),
                    "original dual digest offer receipt"
                );
                ++records;
            }
        }
        require(
            records == 1 && contents == 1 && revenues == 1 && accepted == 1 && sellerConsumed == 1
                && key != 0,
            "one committed offer-specific receipt"
        );
        require(
            keccak256(abi.encode(r.intent)) == keccak256(abi.encode(_nativeOfferIntent(p, q))),
            "full original prepared intent"
        );
        NativeOfferPrepared.Facts memory expected = NativeOfferPrepared.Facts(
            address(artistNativeOffers),
            address(manager),
            address(joinedRecorder),
            address(joinedRecorder).codehash,
            1,
            p.config.sale.phaseId,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_PREPARED_NATIVE_OFFER_INTENT_V1"),
                    block.chainid,
                    address(artistNativeOffers),
                    address(joinedRecorder),
                    r.intent
                )
            ),
            r.execution.operationRoot,
            r.execution.operationId,
            1,
            1,
            address(joinedBuyer),
            address(artistNativeOffers),
            address(joinedBuyer),
            keccak256(q.selection.tokenData),
            q.selection.mintCommitment,
            p.config.sale.mintPolicyHash,
            p.config.sale.mintPolicyHash
        );
        require(
            keccak256(abi.encode(r.facts)) == keccak256(abi.encode(expected)),
            "all original prepared facts"
        );
        NativeOfferContent.Facts memory content;
        content.operationRoot = r.execution.operationRoot;
        content.tokenDataHash = keccak256(q.selection.tokenData);
        if (p.leaf != 0) {
            content.gate = address(p.gate);
            content.gateCodeHash = address(p.gate).codehash;
            content.gateConfigHash = p.gate.gateConfigHash();
            content.manifestRoot = p.leaf;
            content.manifestHash = keccak256(p.gate.manifestBytes());
            content.counterId = p.counter;
            content.contentId = p.config.contentId;
            content.contentLeaf = p.leaf;
            content.contextHash = _nativeOfferContentContext(p);
        } else {
            content.contextHash = StreamPreparedNativeSettlementHash.mintContext(
                address(manager), address(artistNativeOffers), r.facts.intentHash
            );
        }
        require(
            keccak256(abi.encode(r.content)) == keccak256(abi.encode(content)),
            "full selected or collection facts without invented content identity"
        );
        _nativeOfferResult(p, q, r, escrowed);
        require(
            r.execution.saleId == p.id && r.execution.buyer == address(joinedBuyer)
                && r.execution.recipient == address(joinedBuyer) && r.execution.purchaseNonce == 1
                && r.execution.authorizationId == _nativeOfferId(p.config.offerDigest)
                && r.execution.authorizationDigest == _nativeOfferSellerDigest(q.authorization)
                && r.execution.contentLeaf == p.leaf
                && r.execution.tokenDataHash == content.tokenDataHash
                && r.execution.mintCommitment == q.selection.mintCommitment
                && r.execution.price == ARTIST_NATIVE_OFFER_PRICE && r.execution.tokenId == 1
                && r.execution.operationRoot != 0 && r.execution.operationId != 0,
            "complete original purchase execution"
        );
        require(
            artistNativeOffers.digestConsumed(r.execution.authorizationDigest)
                && !artistNativeOffers.digestRevoked(r.execution.authorizationDigest)
                && !artistNativeOffers.digestConsumed(p.config.offerDigest)
                && ledger.isManagerAuthorizationUsed(address(manager), r.execution.authorizationId)
                && !ledger.isManagerAuthorizationUsed(
                    address(manager), _nativeOfferId(r.execution.authorizationDigest)
                ) && ledger.isManagerOperationRootUsed(address(manager), r.execution.operationRoot)
                && ledger.counterValue(_nativeOfferCounter(p)) == 1,
            "independent seller store and original buyer Ledger key"
        );
        require(
            joinedRecorder.preparedNativeFactsHash(key)
                    == StreamPreparedNativeSettlementHash.factsHash(r.facts)
                && joinedRecorder.preparedNativeContentHash(key)
                    == StreamPreparedNativeContentHash.factsHash(content)
                && joinedRecorder.settlementConsumed(key)
                && IStreamPreparedNativeOfferSettlement(address(joinedRecorder))
                    .preparedNativeOfferConsumed(address(artistNativeOffers), purchase)
                && !joinedRecorder.preparedNativeSaleConsumed(
                    joinedRecorder.preparedNativeSaleKey(address(artistNativeOffers), p.id, p.nonce)
                ),
            "original offer recorder lane and hashes"
        );
        require(
            core.ownerOf(1) == address(joinedBuyer) && core.totalSupply() == 1
                && core.collectionMintedEver(1) == 1 && core.lastAllocatedTokenId() == 1
                && core.collectionNextSerial(1) == 2 && core.pendingPreparedMintTokenId() == 0
                && !core.preparedMint(1).exists
                && keccak256(core.tokenData(1)) == content.tokenDataHash
                && manager.nextOperationNonce() == 1
                && artistNativeOffers.nextPurchaseNonce(p.id, address(joinedBuyer)) == 2
                && artistNativeOffers.saleRecord(p.id).status == 4
                && IStreamPreparedNativeOfferMint(address(manager)).preparedNativeOfferAdmission()
                    == 0
                && IStreamPreparedNativeOfferMint(address(manager))
                .activePreparedNativeOfferContent()
                .operationRoot == 0 && manager.activePreparedNativeMint().operationRoot == 0,
            "one token and terminal sale with temporary prepared state cleared"
        );
        require(
            joinedRecorder.totalOfficialSettled(address(0)) == ARTIST_NATIVE_OFFER_PRICE
                && entropy.revealFeeEscrow(1) == 100
                && wallet.balance == (escrowed ? 0 : ARTIST_NATIVE_OFFER_PRICE)
                && revenueEscrow.escrowOwed(PRIMARY_REVENUE_CLASS, profile, wallet, address(0))
                    == (escrowed ? ARTIST_NATIVE_OFFER_PRICE : 0),
            "exact PROFILE price and separate actual reveal fee"
        );
    }

    function _nativeOfferResult(
        ArtistNativeOfferPlan memory p,
        NativeOffer.Acceptance memory q,
        ArtistNativeOfferReceipt memory r,
        bool escrowed
    ) private view {
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c;
        c.saleAdapter = address(artistNativeOffers);
        c.executor = address(joinedBuyer);
        c.sale = StreamPrimarySettlementTypes.PrimarySale(
            p.id,
            PRIMARY_REVENUE_CLASS,
            0,
            1,
            1,
            p.nonce,
            address(joinedBuyer),
            address(joinedCollaborator),
            address(joinedBuyer),
            ARTIST_NATIVE_OFFER_PRICE,
            p.config.sale.expectedPrimaryPolicyHash
        );
        StreamNativeSettlementTypes.SaleLifecycleBinding memory lifecycle =
            artistNativeOffers.preparedNativeSaleLifecycle(p.id);
        c.lifecycleBinding.saleCreatedAt = lifecycle.saleCreatedAt;
        c.lifecycleBinding.saleAdapterRegistryRevision = lifecycle.saleAdapterRegistryRevision;
        c.executionBinding = StreamPrimarySettlementTypes.SaleExecutionBinding(
            StreamPreparedNativeSettlementHash.executionId(r.facts, r.intent),
            1,
            1,
            _nativeOfferSellerDigest(q.authorization)
        );
        c.orchestrationOrder = 2;
        c.mintManager = address(manager);
        c.operationIdentityCommitment = r.facts.operationRoot;
        c.operationId = r.facts.operationId;
        c.currentPolicyHash = p.config.sale.mintPolicyHash;
        c.boundPolicyHash = p.config.sale.mintPolicyHash;
        c.rights = StreamPrimarySettlementTypes.PrimaryRights(
            profile,
            wallet,
            0,
            primaryResolver.resolvePrimaryAssignment(1, 0, PRIMARY_REVENUE_CLASS).assignmentHash,
            factory.profileEntriesHash(profile)
        );
        c.saleExecutionHash = r.intent.saleExecutionHash;
        NativeOfferPurchase.Purchase memory purchase = NativeOfferPurchase.Purchase(
            p.id,
            p.nonce,
            artistNativeOffers.saleRecord(p.id).configHash,
            artistNativeOffers.purchaseIdFor(p.id, address(joinedBuyer), 1),
            address(joinedBuyer),
            1,
            _nativeOfferId(p.config.offerDigest),
            address(joinedBuyer),
            2,
            0,
            p.config.offerDigest
        );
        StreamPrimarySettlementTypes.PrimarySettlementResult memory expected =
            StreamPrimarySettlementTypes.PrimarySettlementResult(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PREPARED_NATIVE_OFFER_CANDIDATE_V1"),
                        block.chainid,
                        address(joinedRecorder),
                        r.facts,
                        r.content,
                        r.intent,
                        purchase,
                        c
                    )
                ),
                StreamPrimarySettlementHash.settlementKey(
                    address(joinedRecorder),
                    address(artistNativeOffers),
                    c.executionBinding.executionId
                ),
                profile,
                wallet,
                address(0),
                ARTIST_NATIVE_OFFER_PRICE,
                address(joinedBuyer),
                c.executionBinding.executionId,
                escrowed,
                r.facts.operationRoot,
                p.config.sale.mintPolicyHash,
                p.config.sale.mintPolicyHash
            );
        require(
            r.execution.settlementKey == expected.settlementKey
                && keccak256(abi.encode(joinedRecorder.settlementResult(expected.settlementKey)))
                    == keccak256(abi.encode(expected)),
            "all twelve offer result fields and complete original candidate"
        );
    }
}
