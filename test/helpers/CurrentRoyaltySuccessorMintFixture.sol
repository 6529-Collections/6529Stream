// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./CurrentDynamicRoyaltyCommerceFixture.sol";
import {
    IStreamRoyaltyConsumerContinuity as Consumer
} from "../../smart-contracts/interfaces/stream/revenue/IStreamRoyaltyConsumerContinuity.sol";

interface SuccessorCallCounts {
    function expectCall(address target, uint256 value, bytes calldata data, uint64 count) external;
}

/// @dev Test-only actual graph recipes. The pending consumer implementation is not supplied here.
abstract contract CurrentRoyaltySuccessorMintFixture is CurrentDynamicRoyaltyCommerceFixture {
    function _successorAuthorization() internal view returns (T.Authorization memory) {
        T.Binding memory b = artistCoordinator.reads().acceptedBinding(1);
        return T.Authorization(
            IStreamArtistIdentityOwner(artistSuite.owners[2]).identity(b.artistId).nonceHint,
            uint64(block.timestamp + 1 days),
            ""
        );
    }

    function _successorPayload(T.AssignmentFact memory f)
        internal
        pure
        returns (T.EconomicsConsent memory)
    {
        return
            T.EconomicsConsent(1, f.resolver, f.revenueClass, f.scope, f.scopeId, f.assignmentHash);
    }

    function _successorDigest(T.EconomicsConsent memory p, T.Authorization memory a)
        internal
        view
        returns (bytes32)
    {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamArtistRegistry"),
                keccak256("1"),
                block.chainid,
                address(artists)
            )
        );
        bytes32 statement = keccak256(
            abi.encode(
                keccak256(
                    "StreamArtistEconomicsConsent(address core,address resolver,bytes32 revenueClass,uint8 scope,uint256 scopeId,bytes32 assignmentHash,uint256 nonce,uint64 deadline)"
                ),
                address(core),
                p.resolver,
                p.revenueClass,
                p.scope,
                p.scopeId,
                p.assignmentHash,
                a.nonce,
                a.time
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", domain, statement));
    }

    function _successorApprove(T.AssignmentFact memory f) internal returns (bytes32 record) {
        T.EconomicsConsent memory p = _successorPayload(f);
        T.Authorization memory a = _successorAuthorization();
        bytes32 digest = _successorDigest(p, a);
        require(digest == artists.economicsConsentDigest(p, a), "literal original Artist domain");
        a.signature = _joinedProof(joinedArtist, digest);
        _joinedSafe(
            joinedArtist,
            address(artists),
            0,
            abi.encodeCall(artists.recordEconomicsConsent, (p, a))
        );
        record = _joinedConsentEvidence(p);
        require(
            _successorAuthorization().nonce == a.nonce + 1, "actual principal nonce advances once"
        );
    }

    function _successorProspectiveZero(StreamRoyaltyResolver selected) internal {
        T.AssignmentFact memory f = selected.previewArtistSnapshotRoyaltyAssignment(1, 0, 0, false);
        T.EconomicsConsent memory p = _successorPayload(f);
        T.Authorization memory a = _successorAuthorization();
        a.signature = _joinedProof(joinedArtist, _successorDigest(p, a));
        _joinedSafe(
            joinedArtist,
            address(artists),
            0,
            abi.encodeCall(
                IStreamArtistEconomicsAuthority.recordProspectiveEconomicsConsent,
                (p, T.FixedEconomicsCandidate(0, 0, 0, false), a)
            )
        );
        _joinedConsentEvidence(p);
        this.joinedGovern(
            address(selected),
            abi.encodeCall(selected.configureCollectionRoyalty, (uint256(1), bytes32(0), uint16(0)))
        );
    }

    function _successorPolicy(bytes32 phaseId, bytes32 policyHash) internal {
        T.PolicyConsent memory p = T.PolicyConsent(1, phaseId, policyHash);
        T.Authorization memory a = _successorAuthorization();
        a.signature = _joinedProof(joinedArtist, artists.policyConsentDigest(p, a));
        _joinedSafe(
            joinedArtist, address(artists), 0, abi.encodeCall(artists.recordPolicyConsent, (p, a))
        );
    }

    function _successorPhase(StreamRoyaltyResolver selected, bytes32 phaseId, bool snapshot)
        internal
        returns (IStreamRoyaltySnapshot.Source memory source)
    {
        (bool existed,) = manager.phase(1, phaseId);
        require(!existed && phaseId != JOINED_PHASE, "fresh explicit successor phase");
        bytes32 wrapper = keccak256(abi.encode("live successor application", phaseId));
        if (snapshot) {
            source = selected.currentRoyaltySnapshotSource(1);
            IStreamMintRoyaltyPolicy.Policy memory p = IStreamMintRoyaltyPolicy.Policy(
                true,
                keccak256(abi.encode("snapshot successor application", phaseId)),
                address(selected),
                address(selected).codehash,
                source.electionHash,
                source.modeAssignmentHash,
                source.sourceRoyaltyPolicyHash
            );
            wrapper = manager.phaseRoyaltyConfigHash(1, phaseId, p);
            this.joinedGovern(
                address(manager),
                abi.encodeCall(manager.registerPhaseRoyaltyPolicy, (uint256(1), phaseId, p))
            );
        }
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = keccak256(abi.encode("successor actual supply", phaseId));
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            10,
            1,
            keccak256(abi.encode("successor counter", phaseId))
        );
        IStreamMintManager.MintGateConfig memory gate;
        IStreamMintManager.MintPhaseConfig memory config = IStreamMintManager.MintPhaseConfig(
            false, 0, 0, 1, wrapper, keccak256("joined metadata")
        );
        address[] memory allowed = new address[](0);
        _successorPolicy(
            phaseId,
            manager.previewPhasePolicyHash(1, phaseId, config, gate, ids, counters, allowed)
        );
        this.joinedGovern(
            address(manager),
            abi.encodeCall(
                manager.configurePhase, (uint256(1), phaseId, config, gate, ids, counters)
            )
        );
        allowed = new address[](1);
        allowed[0] = address(joinedHouse);
        _successorPolicy(
            phaseId,
            manager.previewPhasePolicyHash(1, phaseId, config, gate, ids, counters, allowed)
        );
        this.joinedGovern(
            address(manager),
            abi.encodeCall(
                manager.setPhaseExecutor, (uint256(1), phaseId, address(joinedHouse), true)
            )
        );
        artists.requireMintConsent(1, phaseId, manager.phasePolicyHash(1, phaseId));
    }

    function _successorAuction(bytes32 phaseId) internal returns (bytes32 id) {
        StreamSaleTemplate.Selection memory selected = _joinedSelection();
        IStreamNativeEnglishAuction.Configuration memory c;
        c.collectionId = 1;
        c.phaseId = phaseId;
        c.mintAtSettlement = true;
        c.artworkCommitment = keccak256(TOKEN_DATA);
        c.mintCommitment = keccak256(abi.encode("actual successor prepared artwork", phaseId));
        c.poster = address(this);
        c.reservePrice = JOINED_PRICE;
        c.minIncrementBps = 500;
        c.clock = StreamEnglishAuctionClock.Configuration(
            uint64(block.timestamp), uint64(block.timestamp + 3600), 0, 600, 600, 3600, false, false
        );
        c.expectedPrimaryPolicyHash = _joinedPrimaryPolicy(0, selected);
        c.primaryPolicyMode = 1;
        c.settlementWindow = 7 days;
        c.mintPolicyHash = manager.phasePolicyHash(1, phaseId);
        StreamPreparedNativeRightsTypes.OriginalPolicy memory original =
            StreamPreparedNativeRightsTypes.OriginalPolicy(
                3, selected.assignmentHash, selected.templateId
            );
        IStreamNativeEnglishAuction.CreationAuthorization memory a =
            IStreamNativeEnglishAuction.CreationAuthorization(
                joinedHouse.rightsConfigurationHash(c, original),
                address(joinedArtist),
                bytes32(++joinedCreationNonce),
                uint64(block.timestamp + 1 days)
            );
        bytes32 digest = joinedHouse.creationAuthorizationDigest(a);
        id = joinedHouse.registerRightsAuction(
            c, original, TOKEN_DATA, a, _platformProof(digest), _artistProof(digest)
        );
        require(
            joinedHouse.auction(id).config.poster == address(this)
                && address(this) != address(joinedCollector),
            "original poster is separate from paid Safe"
        );
    }

    function _successorMint(StreamRoyaltyResolver selected, bytes32 phaseId, bool snapshot)
        internal
        returns (IStreamRoyaltySnapshot.Snapshot memory saved, uint256 token)
    {
        IStreamRoyaltySnapshot.Source memory source = _successorPhase(selected, phaseId, snapshot);
        bytes32 id = _successorAuction(phaseId);
        _joinedBid(id);
        token = _joinedSettle(id);
        saved = _assertSuccessorMint(selected, id, source, snapshot);
    }

    function _assertSuccessorMint(
        StreamRoyaltyResolver selected,
        bytes32 id,
        IStreamRoyaltySnapshot.Source memory source,
        bool snapshot
    ) internal returns (IStreamRoyaltySnapshot.Snapshot memory saved) {
        IStreamNativeEnglishAuction.Auction memory a = joinedHouse.auction(id);
        saved = selected.royaltySnapshot(a.tokenId);
        IStreamRoyaltyResolver.RoyaltyConfig memory token = selected.tokenRoyalty(a.tokenId);
        require(
            a.status == 3 && core.ownerOf(a.tokenId) == address(joinedCollector)
                && core.lastAllocatedTokenId() == a.tokenId && core.totalSupply() == a.tokenId
                && core.collectionNextSerial(1) == a.tokenId + 1
                && manager.nextOperationNonce() == a.tokenId
                && core.pendingPreparedMintTokenId() == 0
                && joinedHouse.totalBuyerLiabilities() == 0,
            "actual one-time paid allocation, owner and operation"
        );
        StreamPrimarySettlementTypes.PrimarySettlementResult memory result =
            joinedRecorder.settlementResult(a.settlementKey);
        require(
            joinedRecorder.settlementConsumed(a.settlementKey) && result.amount == JOINED_PRICE
                && result.currentPolicyHash == manager.phasePolicyHash(1, a.config.phaseId)
                && result.boundPolicyHash == manager.phasePolicyHash(1, a.config.phaseId)
                && ledger.isManagerOperationRootUsed(
                    address(manager), result.operationIdentityCommitment
                ),
            "actual current phase, original recorder and consumed ledger root"
        );
        require(
            joinedRecorder.totalOfficialSettled(address(0)) == uint256(JOINED_PRICE) * a.tokenId
                && entropy.revealFeeEscrow(a.tokenId) == 100,
            "all actual sale value and reveal liabilities"
        );
        StreamSaleTemplate.Selection memory primary = _joinedSelection();
        require(
            primary.wallet.balance
                    + revenueEscrow.escrowOwed(
                        PRIMARY_REVENUE_CLASS, primary.profileId, primary.wallet, address(0)
                    ) == uint256(JOINED_PRICE) * a.tokenId,
            "every primary payment remains in its original wallet or owed ledger"
        );
        if (snapshot) {
            require(
                saved.exists && saved.tokenId == a.tokenId && saved.collectionId == 1
                    && saved.manager == address(manager)
                    && saved.operationRoot == result.operationIdentityCommitment
                    && saved.electionHash == source.electionHash
                    && saved.sourceAssignmentHash == source.sourceAssignmentHash
                    && saved.modeAssignmentHash == source.modeAssignmentHash
                    && saved.sourceRoyaltyPolicyHash == source.sourceRoyaltyPolicyHash
                    && token.configured && token.frozen && token.revision == 1
                    && token.profileId == source.config.profileId
                    && token.wallet == source.config.wallet
                    && token.royaltyBps == source.config.royaltyBps,
                "new consumer records full actual prepared snapshot"
            );
            (T.AssignmentFact memory f,, bytes32 policy) =
                selected.resolveRoyaltyAssignment(1, a.tokenId);
            require(
                f.resolver == address(selected) && f.scope == 2 && f.scopeId == a.tokenId
                    && f.assignmentHash == saved.tokenAssignmentHash
                    && policy == saved.tokenRoyaltyPolicyHash
                    && keccak256(abi.encode(token)) == saved.tokenConfigHash,
                "actual new scope2 policy and config"
            );
        } else {
            require(!saved.exists && !token.configured, "live mode never fabricates a snapshot");
        }
    }

    function _assertConsumer(
        StreamRoyaltyResolver selected,
        address origin,
        address source,
        bytes32 manifestHash
    ) internal view returns (Consumer.Receipt memory receipt) {
        receipt = Consumer(address(selected)).royaltyConsumerContinuity();
        require(
            receipt.status == 2 && receipt.core == address(core)
                && receipt.factory == address(factory) && receipt.origin == origin
                && receipt.originRuntimeHash == origin.codehash && receipt.source == source
                && receipt.sourceRuntimeHash == source.codehash
                && receipt.manifestHash == manifestHash && receipt.beginActionId != 0
                && receipt.importedHeaderHash != 0,
            "complete actual origin, immediate predecessor and governed import"
        );
        (T.AssignmentFact memory primary, T.AssignmentFact memory royalty) =
            artistCoordinator.reads().currentAssignments(1);
        require(
            primary.resolver == address(primaryResolver) && royalty.resolver == address(selected)
                && artistSuite.royaltyResolver == origin
                && artistSuite.primaryResolver == address(primaryResolver),
            "only current royalty consumer changes; immutable Artist suite remains origin"
        );
    }

    function _savedSuccessorSafe(OfficialSafe safe, address target, bytes memory data)
        internal
        returns (bytes memory signed, uint256 nonce)
    {
        nonce = safe.nonce();
        bytes32 digest =
            safe.getTransactionHash(target, 0, data, 0, 0, 0, 0, address(0), address(0), nonce);
        signed = abi.encodeCall(
            safe.execTransaction,
            (
                target,
                uint256(0),
                data,
                uint8(0),
                uint256(0),
                uint256(0),
                uint256(0),
                address(0),
                payable(address(0)),
                safeThresholdSignature(joinedKeys, digest)
            )
        );
    }
}
