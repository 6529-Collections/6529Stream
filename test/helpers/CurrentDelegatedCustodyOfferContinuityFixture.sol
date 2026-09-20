// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CurrentDynamicRoyaltyCommerceFixture.sol";
import {
    DelegationManagementContract
} from "../../smart-contracts/integrations/delegation/NFTdelegation.sol";
import {
    IStreamPrivateSaleAdapter as CustodyPrivate
} from "../../smart-contracts/interfaces/stream/mint/IStreamPrivateSaleAdapter.sol";
import {
    StreamPrivateSaleTypes as CustodyTerms
} from "../../smart-contracts/interfaces/stream/mint/StreamPrivateSaleTypes.sol";
import {
    IStreamPrivateSaleDelegatedClaims as CustodyClaims
} from "../../smart-contracts/interfaces/stream/mint/IStreamPrivateSaleDelegatedClaims.sol";
import {
    StreamNativeAuctionDelegation as CustodyDelegation
} from "../../smart-contracts/domains/auctions/StreamNativeAuctionDelegation.sol";

/// @dev Actual current Artist/Governor/Core/Manager/Recorder/floor/Coordinator, paid collector
/// delivery, original NFTDelegation and threshold Safes. Only the inherited external entropy
/// service is a fixture. Secondary acceptance enters NFT custody atomically; it never mints or
/// records another primary receipt. Negative caller-isolation CALLs expose exact errors only.
abstract contract CurrentDelegatedCustodyOfferContinuityFixture is
    CurrentDynamicRoyaltyCommerceFixture
{
    uint256 internal constant CUSTODY_OFFER_PRICE = 2_000_000;
    uint256 internal constant CUSTODY_OFFER_EXCESS = 77;
    uint256 internal constant CUSTODY_OFFER_ROYALTY = 120_000;
    bytes32 private constant CUSTODY_CONTINUITY_REASON =
        keccak256("actual secondary delegated offer continuity");
    bytes32 private constant CUSTODY_SIGNER_EVIDENCE =
        keccak256("actual secondary configuration Safe authority");
    StreamPrivateSaleAdapter internal custodyOffers;
    DelegationManagementContract internal custodyDelegates;
    OfficialSafe internal custodyDelegate;
    bytes32 internal custodyPrimaryKey;
    bytes32 private custodyPrimaryResult;
    bytes32 private custodyPrimaryFacts;
    bytes32 private custodyPrimaryFloor;
    bytes32 private custodyPrimaryFirst;
    bytes32 private custodyPrimarySnapshot;

    struct CustodyOfferPlan {
        bytes32 id;
        CustodyPrivate.SaleConfig config;
        CustodyTerms.SaleAuthorization authorization;
        CustodyTerms.SaleOffer offer;
        CustodyPrivate.Signature sellerProof;
        CustodyPrivate.Signature buyerProof;
        CustodyTerms.SaleCustodyGrant ownerGrant;
        bytes ownerSignature;
        bytes32 sellerDigest;
        bytes32 offerDigest;
        bytes32 grantDigest;
        bytes32 originalSale;
        bytes32 lifecycle;
        uint256 buyerNonce;
        uint256 buyerBalance;
        uint256 collectorBalance;
        uint256 royaltyBalance;
        bool delegated;
        bytes input;
        bytes envelope;
    }

    function _deployDelegatedCustodyOffers() internal {
        _deployJoinedCommerce();
        this.joinedSnapshotSetup(0);
        bytes32 templateId = this.joinedCreateTemplate();
        this.joinedApproveTemplate(templateId);
        this.joinedInstallTemplate(templateId);
        this.joinedInstallPhase();
        bytes32 primary = this.joinedCreateAuction();
        _joinedBid(primary);
        require(_joinedSettle(primary) == 1, "genuine first paid collector delivery");
        // This helper verifies the real deferred receipt, then deploys/funds its wallet by flush.
        IStreamRoyaltySnapshot.Snapshot memory snapshot = _joinedAssertMint(primary);
        require(
            snapshot.tokenId == 1 && joinedSource.config.royaltyBps == 600,
            "original positive 600bps snapshot"
        );
        custodyPrimaryKey = joinedHouse.auction(primary).settlementKey;
        custodyPrimaryResult =
            keccak256(abi.encode(joinedRecorder.settlementResult(custodyPrimaryKey)));
        custodyPrimaryFacts = joinedRecorder.preparedNativeRightsFactsHash(custodyPrimaryKey);
        custodyPrimaryFloor =
            keccak256(abi.encode(commerceFloor.settlementReceipt(custodyPrimaryKey)));
        custodyPrimaryFirst = keccak256(abi.encode(commerceFloor.firstSale(1)));
        custodyPrimarySnapshot = keccak256(abi.encode(snapshot));
        _assertWaivedCommerceReceipt(address(joinedRecorder), custodyPrimaryKey, 1);
        custodyDelegate = createOfficialSafe(
            deploySafeComponents("1.4.1"), safeOwnerAddresses(joinedKeys), 2, 1811
        );
        vm.deal(address(custodyDelegate), 10 ether);
        vm.deal(address(this), 10 ether);
        custodyDelegates = DelegationManagementContract(
            _artistArtifactCreate(
                "smart-contracts/integrations/delegation/NFTdelegation.sol:DelegationManagementContract",
                ""
            )
        );
        IStreamGasParameterHost.GasParameterConfig[3] memory caps;
        caps[0] =
            IStreamGasParameterHost.GasParameterConfig("SALE_ERC1271_GAS_LIMIT", 500000, 350000, 2);
        caps[1] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_NFT_DELIVERY_GAS_LIMIT", 500000, 150000, 2
        );
        caps[2] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ROYALTY_DELIVERY_GAS_LIMIT", 150000, 30000, 2
        );
        StreamPrivateSaleAdapter.DeploymentConfig memory d =
            StreamPrivateSaleAdapter.DeploymentConfig(
                address(core),
                address(registry),
                address(joinedArtist),
                address(joinedCollaborator),
                address(executor),
                address(roles),
                caps,
                address(custodyDelegates),
                2,
                CUSTODY_CONTINUITY_REASON,
                IStreamGasParameterHost.GasParameterConfig(
                    "DELEGATE_REGISTRY_GAS_LIMIT", 150000, 50000, 2
                )
            );
        custodyOffers = StreamPrivateSaleAdapter(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/mint/StreamPrivateSaleAdapter.sol:StreamPrivateSaleAdapter",
                    abi.encode(d)
                ))
        );
        _assertDeployableProductionInstance(address(custodyOffers));
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](1);
        records[0] = StreamModuleRegistration(
            address(custodyOffers),
            custodyOffers.streamModuleType(),
            custodyOffers.streamModuleVersion(),
            type(CustodyPrivate).interfaceId,
            500000,
            address(custodyOffers).codehash,
            DEPLOYMENT_HASH,
            keccak256(custodyOffers.delegationManifest()),
            "urn:stream:current:delegated-secondary-offer"
        );
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        _joinedBatch(calls, data);
        _joinedSafe(
            joinedCollaborator,
            address(custodyOffers),
            0,
            abi.encodeCall(
                custodyOffers.configureCollectionSigner, (uint256(1), CUSTODY_SIGNER_EVIDENCE, true)
            )
        );
        _joinedSafe(
            joinedCollector,
            address(core),
            0,
            abi.encodeCall(core.setApprovalForAll, (address(custodyOffers), true))
        );
        require(
            custodyOffers.platformSigner() == address(joinedArtist)
                && custodyOffers.owner() == address(joinedCollaborator)
                && custodyOffers.delegateRegistry() == address(custodyDelegates)
                && custodyOffers.delegateRegistryCodeHash() == address(custodyDelegates).codehash
                && custodyOffers.delegationUsecase() == 2
                && registry.moduleRecord(address(custodyOffers)).status
                    == ModuleRegistryStatus.ACTIVE
                && registry.moduleRecord(address(custodyOffers)).moduleManifestHash
                    == keccak256(custodyOffers.delegationManifest()),
            "actual module, original provider and independent seller/configuration Safes"
        );
        _custodyPrimaryUnchanged();
    }

    function _armCustodyOffer(bool delegated) internal returns (CustodyOfferPlan memory p) {
        p.delegated = delegated;
        p.offer = CustodyTerms.SaleOffer(
            block.chainid,
            address(custodyOffers),
            address(core),
            1,
            1,
            0,
            address(joinedBuyer),
            address(0),
            CUSTODY_OFFER_PRICE,
            keccak256("original secondary buyer offer"),
            uint64(block.timestamp + 10 days),
            0
        );
        p.offerDigest = _custodyTyped(
            keccak256(
                abi.encode(
                    keccak256(
                        "SaleOffer(uint256 chainId,address saleAdapter,address core,uint256 collectionId,uint256 tokenId,bytes32 contentSelectionHash,address buyer,address asset,uint256 price,bytes32 nonce,uint64 deadline,uint64 finalizeBy)"
                    ),
                    p.offer
                )
            )
        );
        require(
            p.offerDigest == custodyOffers.offerDigest(p.offer), "independent original buyer digest"
        );
        (bytes32 evidence, uint64 revision, bool enabled, address authority) =
            custodyOffers.collectionSigner(1);
        require(enabled && authority == address(joinedCollaborator), "actual configuration owner");
        p.config = CustodyPrivate.SaleConfig(
            6,
            1,
            1,
            address(joinedCollector),
            address(joinedBuyer),
            CUSTODY_OFFER_PRICE,
            uint64(block.timestamp),
            p.offer.deadline,
            p.offerDigest,
            evidence,
            revision,
            authority,
            true,
            0
        );
        uint256 nonce = custodyOffers.nextSaleNonce();
        p.id = custodyOffers.saleIdFor(6, 1, nonce);
        _joinedSafe(
            joinedCollaborator,
            address(custodyOffers),
            0,
            abi.encodeCall(custodyOffers.registerSale, (p.config))
        );
        CustodyPrivate.Sale memory sale = custodyOffers.saleDetails(p.id);
        require(
            sale.status == 1 && sale.saleNonce == nonce && sale.createdAt == block.timestamp
                && sale.registryRevision == registry.moduleRecord(address(custodyOffers)).revision
                && sale.configHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_NATIVE_CONSIGNMENT_CONFIG_V1"),
                            block.chainid,
                            address(custodyOffers),
                            nonce,
                            address(joinedArtist),
                            p.config
                        )
                    ) && custodyOffers.nextSaleNonce() == nonce + 1
                && core.ownerOf(1) == address(joinedCollector),
            "actual ACTIVE sale preserves collector token with no prefunded custody"
        );
        p.originalSale = keccak256(abi.encode(sale));
        p.lifecycle = _custodyLifecycle(p.id);
        CustodyTerms.SaleAuthorization memory a;
        a.chainId = block.chainid;
        a.saleAdapter = address(custodyOffers);
        a.collectionId = 1;
        a.saleId = p.id;
        a.saleKind = 6;
        address[] memory buyer = new address[](1);
        buyer[0] = address(joinedBuyer);
        a.initialRecipientsHash = keccak256(abi.encode(buyer));
        a.beneficiariesHash = a.initialRecipientsHash;
        a.tokenDataArrayHash = keccak256(abi.encode(new bytes[](0)));
        a.mintCommitmentsHash = keccak256(abi.encode(new bytes32[](0)));
        a.payer = address(joinedBuyer);
        a.executor = address(joinedBuyer);
        a.unitPrice = CUSTODY_OFFER_PRICE;
        a.quantity = 1;
        a.nonce = keccak256(abi.encode("original secondary seller", p.id));
        a.deadline = p.config.deadline;
        p.authorization = a;
        p.sellerDigest = _custodyTyped(
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
            p.sellerDigest == custodyOffers.authorizationDigest(a),
            "independent original seller digest"
        );
        p.sellerProof = CustodyPrivate.Signature(
            address(joinedArtist), 2, _joinedProof(joinedArtist, p.sellerDigest)
        );
        OfficialSafe signer = delegated ? custodyDelegate : joinedBuyer;
        p.buyerProof =
            CustodyPrivate.Signature(address(signer), 2, _joinedProof(signer, p.offerDigest));
        p.ownerGrant = CustodyTerms.SaleCustodyGrant(
            block.chainid,
            address(custodyOffers),
            address(core),
            1,
            address(joinedCollector),
            p.offerDigest,
            keccak256(abi.encode("original collector custody", p.id)),
            p.config.deadline
        );
        p.grantDigest = _custodyTyped(
            keccak256(
                abi.encode(
                    keccak256(
                        "SaleCustodyGrant(uint256 chainId,address saleAdapter,address core,uint256 tokenId,address owner,bytes32 saleRef,bytes32 nonce,uint64 deadline)"
                    ),
                    p.ownerGrant
                )
            )
        );
        require(
            p.grantDigest == custodyOffers.custodyGrantDigest(p.ownerGrant),
            "independent owner grant binds original offer"
        );
        p.ownerSignature = _joinedProof(joinedCollector, p.grantDigest);
        if (delegated) _custodyGrant(p, true);
        p.buyerBalance = address(joinedBuyer).balance;
        p.collectorBalance = address(joinedCollector).balance;
        p.royaltyBalance = joinedSource.config.wallet.balance;
        (address receiver, uint256 amount, bool secondary, bool disclosure) =
            custodyOffers.royaltyQuote(p.id);
        require(
            receiver == joinedSource.config.wallet && amount == CUSTODY_OFFER_ROYALTY && secondary
                && disclosure,
            "actual frozen Core quote and external-market disclosure"
        );
        _custodyRebuild(p);
        _custodyUnused(p);
    }

    function _custodyGrant(CustodyOfferPlan memory p, bool allTokens) internal {
        _joinedSafe(
            joinedBuyer,
            address(custodyDelegates),
            0,
            abi.encodeCall(
                custodyDelegates.registerDelegationAddress,
                (
                    address(core),
                    address(custodyDelegate),
                    uint256(p.config.deadline),
                    uint256(2),
                    allTokens,
                    allTokens ? uint256(0) : uint256(42)
                )
            )
        );
        bytes32 key = keccak256(
            abi.encodePacked(
                address(joinedBuyer), address(core), address(custodyDelegate), uint256(2)
            )
        );
        (
            address vault,
            address delegate,
            uint256 start,
            uint256 end,
            bool actualAll,
            uint256 token
        ) = custodyDelegates.globalDelegationHashes(key, 0);
        require(
            vault == address(joinedBuyer) && delegate == address(custodyDelegate)
                && start <= block.timestamp && end == p.config.deadline && end > block.timestamp
                && actualAll == allTokens && token == (allTokens ? 0 : 42),
            "actual complete original grant row at index zero"
        );
    }

    function _custodyRevokeGrant() internal {
        _joinedSafe(
            joinedBuyer,
            address(custodyDelegates),
            0,
            abi.encodeCall(
                custodyDelegates.revokeDelegationAddress,
                (address(core), address(custodyDelegate), uint256(2))
            )
        );
    }

    /// @dev Buyer grant writes spend buyer transaction nonces. Original commercial proofs stay
    /// valid but only a refreshed buyer envelope can execute after those independent transactions.
    function _custodyRebuild(CustodyOfferPlan memory p) internal {
        p.input = p.delegated
            ? abi.encodeCall(
                custodyOffers.acceptDelegatedOffer,
                (
                    p.authorization,
                    p.sellerProof,
                    p.offer,
                    p.buyerProof,
                    p.ownerGrant,
                    uint8(2),
                    p.ownerSignature,
                    CustodyClaims.DelegationWitness(false, 0)
                )
            )
            : abi.encodeCall(
                custodyOffers.acceptOffer,
                (
                    p.authorization,
                    p.sellerProof,
                    p.offer,
                    p.buyerProof,
                    p.ownerGrant,
                    uint8(2),
                    p.ownerSignature
                )
            );
        p.buyerNonce = joinedBuyer.nonce();
        p.envelope =
            _custodyEnvelope(joinedBuyer, CUSTODY_OFFER_PRICE + CUSTODY_OFFER_EXCESS, p.input);
    }

    function _custodyEnvelope(OfficialSafe safe, uint256 value, bytes memory input)
        internal
        returns (bytes memory)
    {
        bytes32 digest = safe.getTransactionHash(
            address(custodyOffers), value, input, 0, 0, 0, 0, address(0), address(0), safe.nonce()
        );
        return abi.encodeCall(
            safe.execTransaction,
            (
                address(custodyOffers),
                value,
                input,
                uint8(0),
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(joinedKeys, digest)
            )
        );
    }

    function _custodyFailure(CustodyOfferPlan memory p, bytes memory expected) internal {
        // No non-mutating preview exists. This negative-only real CALL exposes the exact error.
        vm.prank(address(joinedBuyer));
        (bool ok, bytes memory out) = address(custodyOffers)
        .call{ value: CUSTODY_OFFER_PRICE + CUSTODY_OFFER_EXCESS }(
            p.input
        );
        require(!ok && keccak256(out) == keccak256(expected), "exact secondary acceptance refusal");
        _custodyUnused(p);
        require(joinedBuyer.nonce() == p.buyerNonce, "correct fresh or unchanged buyer nonce");
        _custodySafeFailure(joinedBuyer, p.envelope);
        _custodyUnused(p);
    }

    function _custodySafeFailure(OfficialSafe safe, bytes memory envelope) internal {
        uint256 nonce = safe.nonce();
        uint256 balance = address(safe).balance;
        (bool ok, bytes memory out) = address(safe).call(envelope);
        require(
            !ok && keccak256(out) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && safe.nonce() == nonce && address(safe).balance == balance,
            "actual Safe failure restores nonce and value"
        );
    }

    function _custodyDelegateCannotExecute(CustodyOfferPlan memory p) internal {
        vm.prank(address(custodyDelegate));
        (bool ok, bytes memory out) = address(custodyOffers)
        .call{ value: CUSTODY_OFFER_PRICE + CUSTODY_OFFER_EXCESS }(
            p.input
        );
        require(
            !ok
                && keccak256(out)
                    == keccak256(
                        abi.encodeWithSelector(
                            CustodyPrivate.PrivateSaleNotBuyer.selector, address(custodyDelegate)
                        )
                    ),
            "signing grant never authorizes delegate payment or execution"
        );
        _custodySafeFailure(
            custodyDelegate,
            _custodyEnvelope(custodyDelegate, CUSTODY_OFFER_PRICE + CUSTODY_OFFER_EXCESS, p.input)
        );
        _custodyUnused(p);
    }

    function _custodyRejectNew(CustodyOfferPlan memory p) internal {
        CustodyPrivate.SaleConfig memory next =
            abi.decode(abi.encode(p.config), (CustodyPrivate.SaleConfig));
        next.offerDigest = keccak256("new prohibited retired secondary offer");
        uint256 nonce = custodyOffers.nextSaleNonce();
        bytes32 newId = custodyOffers.saleIdFor(6, 1, nonce);
        bytes memory input = abi.encodeCall(custodyOffers.registerSale, (next));
        vm.prank(address(joinedCollaborator));
        (bool ok, bytes memory out) = address(custodyOffers).call(input);
        require(
            !ok
                && keccak256(out)
                    == keccak256(
                        abi.encodeWithSelector(
                            CustodyDelegation.DelegationManifestMismatch.selector
                        )
                    ),
            "new registration remains ACTIVE-only"
        );
        _custodySafeFailure(joinedCollaborator, _custodyEnvelope(joinedCollaborator, 0, input));
        require(
            custodyOffers.nextSaleNonce() == nonce && custodyOffers.saleDetails(newId).status == 0,
            "no new lifecycle or nonce"
        );
        _custodyUnused(p);
    }

    function _custodyUnused(CustodyOfferPlan memory p) internal view {
        require(
            core.ownerOf(1) == address(joinedCollector)
                && address(joinedBuyer).balance == p.buyerBalance
                && address(joinedCollector).balance == p.collectorBalance
                && joinedSource.config.wallet.balance == p.royaltyBalance
                && !custodyOffers.digestConsumed(p.sellerDigest)
                && !custodyOffers.digestConsumed(p.offerDigest)
                && !custodyOffers.digestConsumed(p.grantDigest)
                && !custodyOffers.digestRevoked(p.sellerDigest)
                && !custodyOffers.digestRevoked(p.offerDigest)
                && !custodyOffers.digestRevoked(p.grantDigest)
                && keccak256(abi.encode(custodyOffers.saleDetails(p.id))) == p.originalSale
                && _custodyLifecycle(p.id) == p.lifecycle && custodyOffers.totalLiabilities() == 0
                && address(custodyOffers).balance == 0
                && custodyOffers.refundableBalance(p.id, address(joinedBuyer)) == 0
                && custodyOffers.refundableBalance(p.id, address(joinedCollector)) == 0,
            "three original proofs, custody, money and lifecycle roll back together"
        );
        _custodyPrimaryUnchanged();
    }

    function _custodyComplete(CustodyOfferPlan memory p) internal {
        _custodyUnused(p);
        require(joinedBuyer.nonce() == p.buyerNonce, "actual original transaction nonce");
        vm.recordLogs();
        (bool ok, bytes memory out) = address(joinedBuyer).call(p.envelope);
        require(
            ok && abi.decode(out, (bool)) && joinedBuyer.nonce() == p.buyerNonce + 1,
            "actual secondary buyer Safe settlement"
        );
        _custodyEvents(p, vm.getRecordedLogs());
        CustodyPrivate.Sale memory sold = custodyOffers.saleDetails(p.id);
        require(
            sold.status == 3 && sold.nftClaim == 0 && sold.configHash != 0
                && keccak256(abi.encode(sold.config)) == keccak256(abi.encode(p.config))
                && sold.custodyGrantDigest == p.grantDigest
                && sold.authorizationDigest == p.sellerDigest
                && sold.royaltyReceiver == joinedSource.config.wallet
                && sold.royaltyAmount == CUSTODY_OFFER_ROYALTY
                && custodyOffers.digestConsumed(p.sellerDigest)
                && custodyOffers.digestConsumed(p.offerDigest)
                && custodyOffers.digestConsumed(p.grantDigest)
                && _custodyLifecycle(p.id) == p.lifecycle && core.ownerOf(1) == address(joinedBuyer)
                && address(joinedBuyer).balance
                    == p.buyerBalance - CUSTODY_OFFER_PRICE - CUSTODY_OFFER_EXCESS
                && address(joinedCollector).balance == p.collectorBalance
                && joinedSource.config.wallet.balance == p.royaltyBalance + CUSTODY_OFFER_ROYALTY,
            "one existing NFT, independent proofs and exact original royalty payment"
        );
        CustodyPrivate.Credits memory buyer =
            custodyOffers.creditBreakdown(p.id, address(joinedBuyer));
        CustodyPrivate.Credits memory owner =
            custodyOffers.creditBreakdown(p.id, address(joinedCollector));
        require(
            buyer.excess == CUSTODY_OFFER_EXCESS && buyer.consignorProceeds == 0
                && buyer.royalty == 0
                && owner.consignorProceeds == CUSTODY_OFFER_PRICE - CUSTODY_OFFER_ROYALTY
                && owner.excess == 0 && owner.royalty == 0
                && custodyOffers.totalLiabilities()
                    == CUSTODY_OFFER_PRICE - CUSTODY_OFFER_ROYALTY + CUSTODY_OFFER_EXCESS
                && address(custodyOffers).balance == custodyOffers.totalLiabilities()
                && custodyOffers.refundableBalance(p.id, address(custodyDelegate)) == 0,
            "buyer excess and original collector proceeds remain separate perpetual liabilities"
        );
        _custodyPrimaryUnchanged();
    }

    function _custodyEvents(CustodyOfferPlan memory p, Vm.Log[] memory logs) private view {
        uint256 seller;
        uint256 buyer;
        uint256 owner;
        uint256 entered;
        uint256 accepted;
        uint256 settled;
        uint256 royalty;
        uint256 delivered;
        uint256 transfers;
        uint256 indexedCredits;
        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory log = logs[i];
            if (
                log.emitter == address(core) && log.topics.length == 4
                    && log.topics[0] == keccak256("Transfer(address,address,uint256)")
            ) {
                require(
                    log.topics[3] == bytes32(uint256(1)) && log.data.length == 0,
                    "same token transfer event"
                );
                if (transfers == 0) {
                    require(
                        address(uint160(uint256(log.topics[1]))) == address(joinedCollector)
                            && address(uint160(uint256(log.topics[2]))) == address(custodyOffers),
                        "collector custody entry"
                    );
                } else {
                    require(
                        transfers == 1
                            && address(uint160(uint256(log.topics[1]))) == address(custodyOffers)
                            && address(uint160(uint256(log.topics[2]))) == address(joinedBuyer),
                        "buyer custody delivery"
                    );
                }
                ++transfers;
            }
            if (log.emitter != address(custodyOffers) || log.topics.length < 2) continue;
            if (
                log.topics[0]
                    == keccak256("NativeSaleCreditAccountIndexed(uint16,uint256,bytes32,address)")
            ) {
                require(
                    log.topics.length == 4 && uint256(log.topics[1]) == indexedCredits
                        && log.topics[2] == p.id
                        && address(uint160(uint256(log.topics[3])))
                            == (indexedCredits == 0
                                    ? address(joinedCollector)
                                    : address(joinedBuyer))
                        && keccak256(log.data) == keccak256(abi.encode(uint16(1))),
                    "exact original creditor index"
                );
                ++indexedCredits;
                continue;
            }
            require(log.topics[1] == p.id, "secondary event original sale");
            if (
                log.topics[0]
                    == keccak256("SaleAuthorizationConsumed(uint16,bytes32,bytes32,address)")
            ) {
                require(log.topics.length == 3, "consumption event shape");
                address expected;
                if (log.topics[2] == p.sellerDigest) {
                    ++seller;
                    expected = address(joinedArtist);
                } else if (log.topics[2] == p.offerDigest) {
                    ++buyer;
                    expected = p.buyerProof.authorizer;
                } else {
                    require(log.topics[2] == p.grantDigest, "only original owner digest");
                    ++owner;
                    expected = address(joinedCollector);
                }
                require(
                    keccak256(log.data) == keccak256(abi.encode(uint16(1), expected)),
                    "original digest authorizer event"
                );
            } else if (
                log.topics[0] == keccak256("SaleCustodyDeposited(uint16,bytes32,uint256,address)")
            ) {
                require(
                    log.topics.length == 4 && log.topics[2] == bytes32(uint256(1))
                        && address(uint160(uint256(log.topics[3]))) == address(joinedCollector)
                        && keccak256(log.data) == keccak256(abi.encode(uint16(1))),
                    "collector deposit event"
                );
                ++entered;
            } else if (
                log.topics[0]
                    == keccak256("OfferAccepted(uint16,bytes32,address,bytes32,uint256,address)")
            ) {
                require(
                    log.topics.length == 3
                        && address(uint160(uint256(log.topics[2]))) == address(joinedBuyer)
                        && keccak256(log.data)
                            == keccak256(
                                abi.encode(
                                    uint16(1), p.offerDigest, CUSTODY_OFFER_PRICE, address(0)
                                )
                            ),
                    "offer acceptance event"
                );
                ++accepted;
            } else if (
                log.topics[0]
                    == keccak256(
                        "ConsignmentSettled(uint16,bytes32,uint256,address,uint256,uint256,address,address)"
                    )
            ) {
                require(
                    log.topics.length == 4 && log.topics[2] == bytes32(uint256(1))
                        && address(uint160(uint256(log.topics[3]))) == address(joinedBuyer)
                        && keccak256(log.data)
                            == keccak256(
                                abi.encode(
                                    uint16(1),
                                    CUSTODY_OFFER_PRICE,
                                    CUSTODY_OFFER_ROYALTY,
                                    joinedSource.config.wallet,
                                    address(joinedCollector)
                                )
                            ),
                    "secondary economics event"
                );
                ++settled;
            } else if (
                log.topics[0]
                    == keccak256("ConsignmentRoyaltyDelivery(uint16,bytes32,address,uint256,bool)")
            ) {
                require(
                    log.topics.length == 3
                        && address(uint160(uint256(log.topics[2]))) == joinedSource.config.wallet
                        && keccak256(log.data)
                            == keccak256(abi.encode(uint16(1), CUSTODY_OFFER_ROYALTY, true)),
                    "royalty delivery event"
                );
                ++royalty;
            } else if (
                log.topics[0]
                    == keccak256("PrivateSaleNftDelivery(uint16,bytes32,uint256,address,bool)")
            ) {
                require(
                    log.topics.length == 4 && log.topics[2] == bytes32(uint256(1))
                        && address(uint160(uint256(log.topics[3]))) == address(joinedBuyer)
                        && keccak256(log.data) == keccak256(abi.encode(uint16(1), true)),
                    "buyer delivery event"
                );
                ++delivered;
            }
        }
        require(
            seller == 1 && buyer == 1 && owner == 1 && entered == 1 && accepted == 1 && settled == 1
                && royalty == 1 && delivered == 1 && transfers == 2 && indexedCredits == 2,
            "one atomic offer and three original authority receipts"
        );
    }

    function _custodyClaim(CustodyOfferPlan memory p, OfficialSafe account, uint256 amount)
        internal
    {
        uint256 balance = address(account).balance;
        uint256 liability = custodyOffers.totalLiabilities();
        _joinedSafe(
            account,
            address(custodyOffers),
            0,
            abi.encodeCall(custodyOffers.claimRefund, (p.id, address(account)))
        );
        require(
            address(account).balance == balance + amount
                && custodyOffers.refundableBalance(p.id, address(account)) == 0
                && custodyOffers.totalLiabilities() == liability - amount,
            "original account claim conserved"
        );
        _custodyPrimaryUnchanged();
    }

    function _custodyPrimaryUnchanged() internal view {
        require(
            core.totalSupply() == 1 && core.collectionMintedEver(1) == 1
                && core.lastAllocatedTokenId() == 1 && core.collectionNextSerial(1) == 2
                && manager.nextOperationNonce() == 1 && core.pendingPreparedMintTokenId() == 0
                && entropy.revealFeeEscrow(1) == 100
                && keccak256(abi.encode(royalties.royaltySnapshot(1))) == custodyPrimarySnapshot
                && joinedRecorder.totalOfficialSettled(address(0)) == JOINED_PRICE
                && joinedRecorder.settlementConsumed(custodyPrimaryKey)
                && keccak256(abi.encode(joinedRecorder.settlementResult(custodyPrimaryKey)))
                    == custodyPrimaryResult
                && joinedRecorder.preparedNativeRightsFactsHash(custodyPrimaryKey)
                == custodyPrimaryFacts
                && keccak256(abi.encode(commerceFloor.settlementReceipt(custodyPrimaryKey)))
                == custodyPrimaryFloor
                && keccak256(abi.encode(commerceFloor.firstSale(1))) == custodyPrimaryFirst
                && revenueEscrow.totalOwed(address(0)) == 0,
            "original primary receipt, floor, mint, royalty snapshot and reveal escrow remain exact"
        );
    }

    function _custodyLifecycle(bytes32 id) private view returns (bytes32) {
        (uint64 created, uint64 revision) = custodyOffers.custodySaleLifecycle(id);
        return keccak256(abi.encode(created, revision));
    }

    function _custodyTyped(bytes32 body) private view returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream Sales"),
                keccak256("1"),
                block.chainid,
                address(custodyOffers)
            )
        );
        return keccak256(abi.encodePacked(hex"1901", domain, body));
    }

    function _custodyStatus(address module, ModuleRegistryStatus status) internal {
        // Every retained lifecycle must predate the tightening timestamp strictly.
        vm.warp(block.timestamp + 1);
        _custodyStatusNow(module, status);
    }

    function _custodyStatusNow(address module, ModuleRegistryStatus status) internal {
        StreamModuleRecord memory before_ = registry.moduleRecord(module);
        (bytes32 chain, uint64 count) = registry.registrationChainHash();
        bytes32 scope = keccak256(
            abi.encode(
                registry.STREAM_MODULE_STATUS_SCOPE_V1(),
                uint256(block.chainid),
                address(registry),
                module
            )
        );
        bytes32 oldHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_STATUS_STATE_V1(),
                scope,
                _custodyRecordFacts(before_, before_.status, before_.revision),
                registry.moduleCount(),
                chain,
                count
            )
        );
        bytes32 newHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_STATUS_STATE_V1(),
                scope,
                _custodyRecordFacts(before_, status, before_.revision + 1),
                registry.moduleCount(),
                chain,
                count
            )
        );
        uint8 actionClass = uint8(status) > uint8(before_.status) ? 0 : 1;
        GovernanceActionRequest memory request = _governanceRequest(
            actionClass,
            address(registry),
            abi.encodeCall(
                registry.setModuleStatus,
                (
                    module,
                    status,
                    CUSTODY_CONTINUITY_REASON,
                    "urn:stream:current:delegated-secondary-offer-continuity"
                )
            ),
            scope,
            oldHash,
            newHash
        );
        bytes32 id = _scheduleAsGovernor(request);
        if (actionClass == 1) {
            require(request.notBefore >= block.timestamp + 48 hours, "actual delayed loosening");
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamGovernanceExecutor.GovernanceActionNotExecutable.selector,
                    id,
                    request.notBefore
                )
            );
            executor.executeGovernanceAction(id, request.callData);
        }
        vm.warp(request.notBefore);
        _executeAsGovernor(id, request.callData);
        StreamModuleRecord memory after_ = registry.moduleRecord(module);
        (bytes32 afterChain, uint64 afterCount) = registry.registrationChainHash();
        require(
            after_.status == status && after_.revision == before_.revision + 1
                && after_.registeredAt == before_.registeredAt
                && after_.statusUpdatedAt == block.timestamp
                && _custodyRecordFacts(after_, status, after_.revision)
                    == _custodyRecordFacts(before_, status, before_.revision + 1)
                && chain == afterChain && count == afterCount,
            "actual Safe-governed status revision preserves original registration evidence"
        );
    }

    function _custodyRecordFacts(
        StreamModuleRecord memory r,
        ModuleRegistryStatus status,
        uint64 revision
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                uint8(status),
                r.moduleType,
                r.moduleVersion,
                r.interfaceId,
                r.moduleGasLimit,
                r.runtimeCodeHash,
                r.deploymentManifestHash,
                r.moduleManifestHash,
                keccak256(bytes(r.moduleManifestURI)),
                revision
            )
        );
    }
}
