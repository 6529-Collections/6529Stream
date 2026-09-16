// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CurrentDynamicRoyaltyCommerceFixture.sol";
import "../../script/current/StreamGovernanceCatalogStagePlan.sol";
import "../../smart-contracts/domains/revenue/StreamCustodyRightsValidation.sol";
import "../../smart-contracts/interfaces/stream/revenue/StreamTokenProfileCustodyTypes.sol";
import "../../smart-contracts/interfaces/stream/revenue/StreamCustodyRightsTypes.sol";
import "../../smart-contracts/vendor/openzeppelin/IERC721Receiver.sol";

/// @dev Actual current graph: original prepared acquisition, then separately approved token rights.
abstract contract CurrentArtistCustodyRightsFixture is CurrentDynamicRoyaltyCommerceFixture {
    IStreamRoyaltySnapshot.Snapshot internal acquiredSnapshot;
    StreamNativeCustodySettlementTypes.Origin internal acquiredOrigin;
    uint256 internal acquiredNonce;

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }

    function _deployArtistCustody() internal {
        _deployJoinedCommerce();
        this.custodyAdmitBinding();
        this.custodyBindHouse();
        this.joinedSnapshotSetup(0);
        this.joinedInstallPhase();
        vm.deal(address(this), 10 ether);
    }

    /// @dev Extend the actual Executor catalog, then publish its required SystemManifest tail.
    function custodyAdmitBinding() external {
        require(msg.sender == address(this), "fixture self");
        GovernanceActionPolicyEntry[] memory rows = new GovernanceActionPolicyEntry[](1);
        rows[0] = GovernanceActionPolicyEntry(
            1,
            address(joinedRecorder),
            joinedRecorder.bindCanonicalCustodyHouse.selector,
            address(joinedRecorder).codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, address(joinedRecorder))),
            1,
            0,
            0,
            0
        );
        StreamGovernanceCatalogStagePlan.Inventory memory inventory =
            StreamGovernanceCatalogStagePlan.inventory(executor, rows);
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        (address payload, bytes32 hash) = StreamGenesisManifestPlan.writePayload(
            bytes('{"purpose":"actual Artist token custody binding","version":1}')
        );
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            hash,
            "urn:stream:current:artist-custody",
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
        (GenesisBatch memory batch, uint256 done) = StreamGovernanceCatalogStagePlan.nextBatch(
            inventory,
            StreamGovernanceCatalogStagePlan.inventoryHash(inventory),
            0,
            manifest,
            payload,
            update
        );
        require(done == 1 && batch.actionClass == 3, "exact catalog extension");
        (bytes32 action, uint64 ready) = _scheduleBatchAsGovernor(3, batch.calls, batch.callDatas);
        vm.warp(ready);
        _joinedSafe(
            governorSafe,
            address(executor),
            0,
            abi.encodeCall(executor.executeGovernanceBatch, (action, batch.calls, batch.callDatas))
        );
        require(
            executor.governanceAction(action).status == GovernanceActionStatus.EXECUTED,
            "catalog actual delayed Safe execution"
        );
    }

    function custodyBindHouse() external {
        require(msg.sender == address(this), "fixture self");
        (bytes32 scope, bytes32 previous, bytes32 next) =
            joinedRecorder.custodyHouseTransition(address(joinedHouse));
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        bytes[] memory datas = new bytes[](1);
        datas[0] = abi.encodeCall(joinedRecorder.bindCanonicalCustodyHouse, (address(joinedHouse)));
        calls[0] =
            StreamCurrentStackPlan.call(address(joinedRecorder), datas[0], scope, previous, next);
        _joinedBatch(calls, datas);
        joinedRecorder.requireCanonicalCustodyHouse(address(joinedHouse));
    }

    function _custodyDomain(string memory name) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256("1"),
                block.chainid,
                address(joinedHouse)
            )
        );
    }

    function _custodyTyped(string memory name, bytes32 value) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(hex"1901", _custodyDomain(name), value));
    }

    /// @dev Fresh external frame observes time after all governance delays. Acquisition Safe != poster.
    function custodyAcquire() external returns (bytes32 id) {
        require(msg.sender == address(this), "fixture self");
        IStreamNativeEnglishAuction.Configuration memory c;
        c.collectionId = 1;
        c.phaseId = JOINED_PHASE;
        c.tokenId = core.lastAllocatedTokenId() + 1;
        c.mintCommitment = keccak256("original prepared token rights acquisition");
        c.poster = address(this);
        c.reservePrice = JOINED_PRICE;
        c.minIncrementBps = 500;
        // Leave room for real delayed token-rights governance after the token exists.
        c.clock = StreamEnglishAuctionClock.Configuration(
            uint64(block.timestamp),
            uint64(block.timestamp + 30 days),
            0,
            600,
            600,
            3600,
            false,
            false
        );
        c.expectedPrimaryPolicyHash = _joinedPrimaryPolicy(0, _custodyProfileSelection(0));
        c.primaryPolicyMode = 1;
        c.settlementWindow = 7 days;
        c.mintPolicyHash = manager.phasePolicyHash(1, JOINED_PHASE);
        (uint256 saleNonce,) = joinedHouse.nextCuratedSaleId(1, JOINED_PHASE);
        IStreamNativeCustodyAuction.Acquisition memory a = IStreamNativeCustodyAuction.Acquisition(
            joinedHouse.auctionConfigurationHash(c),
            keccak256(TOKEN_DATA),
            saleNonce,
            c.tokenId,
            core.collectionNextSerial(1),
            manager.nextOperationNonce(),
            keccak256("original custody context"),
            address(joinedBuyer),
            150,
            address(joinedArtist),
            bytes32(++joinedCreationNonce),
            uint64(block.timestamp + 1 days)
        );
        bytes32 digest = _custodyTyped(
            "6529StreamPreparedNativeCustodyAuction",
            keccak256(
                abi.encode(
                    keccak256(
                        "PreparedNativeCustodyAcquisition(bytes32 configHash,bytes32 tokenDataHash,uint256 expectedSaleNonce,uint256 expectedTokenId,uint256 expectedCollectionSerial,uint256 expectedOperationNonce,bytes32 contextHash,address executor,uint256 revealFeeDeposit,address artist,bytes32 nonce,uint64 deadline)"
                    ),
                    a
                )
            )
        );
        require(
            digest == joinedHouse.preparedCustodyAcquisitionDigest(a)
                && digest != joinedHouse.custodyAcquisitionDigest(a),
            "original independent acquisition domain"
        );
        id = keccak256(
            abi.encode(
                keccak256("6529STREAM_AUCTION_V1"),
                block.chainid,
                address(joinedHouse),
                uint256(1),
                saleNonce,
                c.tokenId,
                false
            )
        );
        vm.recordLogs();
        _joinedSafe(
            joinedBuyer,
            address(joinedHouse),
            150,
            abi.encodeCall(
                joinedHouse.registerPreparedCustodyAuction,
                (c, a, TOKEN_DATA, _platformProof(digest), _artistProof(digest))
            )
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        acquiredOrigin = joinedHouse.custodyOrigin(id);
        acquiredSnapshot = royalties.royaltySnapshot(c.tokenId);
        acquiredNonce = manager.nextOperationNonce();
        IStreamRoyaltyResolver.RoyaltyConfig memory royalty = royalties.tokenRoyalty(c.tokenId);
        require(
            core.ownerOf(c.tokenId) == address(joinedHouse) && acquiredOrigin.eligible
                && acquiredOrigin.authorizationId == digest
                && acquiredOrigin.fundingAccount == address(joinedBuyer)
                && acquiredOrigin.tokenId == c.tokenId
                && acquiredOrigin.operationNonce == a.expectedOperationNonce
                && acquiredOrigin.tokenDataHash == a.tokenDataHash
                && acquiredNonce == a.expectedOperationNonce + 1 && acquiredSnapshot.exists
                && acquiredSnapshot.operationRoot == acquiredOrigin.operationRoot
                && acquiredSnapshot.operationId == acquiredOrigin.operationId
                && acquiredSnapshot.sourceAssignmentHash == joinedSource.sourceAssignmentHash
                && acquiredSnapshot.sourceRoyaltyPolicyHash == joinedSource.sourceRoyaltyPolicyHash
                && acquiredSnapshot.modeAssignmentHash == joinedSource.modeAssignmentHash
                && ledger.isManagerOperationRootUsed(address(manager), acquiredOrigin.operationRoot)
                && royalty.configured && royalty.frozen && royalty.revision == 1
                && royalty.royaltyBps == 600
                && acquiredSnapshot.tokenConfigHash == keccak256(abi.encode(royalty))
                && entropy.revealFeeEscrow(c.tokenId) == 100
                && acquiredOrigin.revealFeeForwarded == 100
                && joinedHouse.refundableBalance(
                    joinedHouse.auction(id).saleId, address(joinedBuyer)
                ) == 50 && joinedRecorder.totalOfficialSettled(address(0)) == 0
                && wallet.balance == 0,
            "actual unpaid acquisition and frozen default source; executor owns reveal excess"
        );
        uint256 found;
        bytes32 topic = keccak256(
            "NativeAuctionPreparedCustodyBound(uint16,bytes32,uint256,bytes32,bytes32,bytes32)"
        );
        for (uint256 n; n < logs.length; ++n) {
            if (
                logs[n].emitter == address(joinedHouse) && logs[n].topics.length == 4
                    && logs[n].topics[0] == topic
            ) {
                ++found;
                require(
                    logs[n].topics[1] == id && uint256(logs[n].topics[2]) == c.tokenId
                        && logs[n].topics[3] == acquiredOrigin.operationRoot
                        && keccak256(logs[n].data)
                            == keccak256(abi.encode(uint16(1), acquiredOrigin.operationId, digest)),
                    "complete acquisition event"
                );
            }
        }
        require(found == 1, "single original acquisition");
    }

    function custodyProfile(uint32 artistShare) external returns (bytes32 p, address w) {
        require(msg.sender == address(this) && artistShare <= 700000, "fixture profile");
        IStreamSplitWallet.SplitEntry[] memory rows = new IStreamSplitWallet.SplitEntry[](3);
        rows[0] =
            IStreamSplitWallet.SplitEntry(address(joinedArtist), artistShare, keccak256("artist"));
        rows[1] = IStreamSplitWallet.SplitEntry(
            address(joinedCollaborator), 900000 - artistShare, COLLAB_LABEL
        );
        rows[2] = IStreamSplitWallet.SplitEntry(PROTOCOL, 100000, keccak256("protocol"));
        return
            factory.createProfile(rows, keccak256(abi.encode("actual token profile", artistShare)));
    }

    function custodyApprove(uint256 token, bytes32 content, bool template_)
        external
        returns (bytes32 assignment)
    {
        require(msg.sender == address(this), "fixture self");
        T.AssignmentFact memory f = template_
            ? primaryResolver.previewArtistScopedPrimaryTemplateAssignment(
                1, 2, token, content, 0, false
            )
            : primaryResolver.previewArtistPrimaryAssignmentForScope(1, 2, token, content, 0, false);
        T.EconomicsConsent memory p = T.EconomicsConsent(
            1, address(primaryResolver), PRIMARY_REVENUE_CLASS, 2, token, f.assignmentHash
        );
        T.Authorization memory a = _artistAuthorization(false);
        a.signature = _artistProof(artists.economicsConsentDigest(p, a));
        bytes memory data = template_
            ? abi.encodeCall(
                IStreamArtistTemplateEconomicsAuthority.recordProspectiveTemplateEconomicsConsent,
                (p, content, a)
            )
            : abi.encodeCall(
                IStreamArtistEconomicsAuthority.recordProspectiveEconomicsConsent,
                (p, T.FixedEconomicsCandidate(content, 0, 0, false), a)
            );
        _joinedSafe(joinedArtist, address(artists), 0, data);
        bytes32 record = _joinedConsentEvidence(p);
        bytes32 evidence = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(artists),
                address(artistCoordinator),
                uint16(15),
                address(joinedArtist),
                record
            )
        );
        (
            uint16 schema,
            bytes32 config,
            uint16 op,
            address actor,
            bytes32 saved,,,
            bytes memory payload
        ) = abi.decode(
            StreamArtistArchiveV2(artistSuite.archive).artistEvidenceBytesV2(evidence, 1),
            (uint16, bytes32, uint16, address, bytes32, T.Snapshot[7], T.Snapshot[7], bytes)
        );
        require(
            schema == 1 && config == artistCoordinator.configurationHash() && op == 15
                && actor == address(joinedArtist) && saved == record && payload.length != 0,
            "actual scope2 Safe op15 Archive"
        );
        return f.assignmentHash;
    }

    function _custodySetCall(uint256 token, bytes32 content, bool template_)
        internal
        view
        returns (bytes memory)
    {
        return template_
            ? abi.encodeCall(
                primaryResolver.setPrimaryTemplateAssignment,
                (PRIMARY_REVENUE_CLASS, uint8(2), token, content, bytes32(0))
            )
            : abi.encodeCall(
                primaryResolver.setPrimaryProfileAssignment,
                (PRIMARY_REVENUE_CLASS, uint8(2), token, content, bytes32(0))
            );
    }

    function custodyInstall(uint256 token, bytes32 content, bool template_)
        external
        returns (bytes32 hash)
    {
        require(msg.sender == address(this), "fixture self");
        hash = this.custodyApprove(token, content, template_);
        this.joinedGovern(address(primaryResolver), _custodySetCall(token, content, template_));
    }

    function _custodyProfileSelection(uint256 token)
        internal
        view
        returns (StreamSaleTemplate.Selection memory s)
    {
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a =
            primaryResolver.resolvePrimaryAssignment(1, token, PRIMARY_REVENUE_CLASS);
        s.profileId = a.profileId;
        s.wallet = factory.walletFor(a.profileId);
        s.assignmentHash = a.assignmentHash;
    }

    function _custodyDynamicSelection(uint256 token)
        internal
        view
        returns (StreamSaleTemplate.Selection memory s, bytes32 witness)
    {
        bytes32 policy;
        (s, policy, witness) = StreamCustodyRightsValidation.selection(
            StreamPrimarySettlementRights.Context(
                primaryResolver, factory, factory.splitWalletRuntimeCodeHash()
            ),
            1,
            token,
            4,
            address(this)
        );
        require(
            policy == _joinedPrimaryPolicy(token, s) && witness != 0,
            "canonical actual token policy and binding witness"
        );
    }

    function custodyProfileAuthorization(bytes32 id)
        external
        view
        returns (StreamTokenProfileCustodyTypes.Authorization memory a)
    {
        IStreamNativeEnglishAuction.Auction memory sale = joinedHouse.auction(id);
        StreamSaleTemplate.Selection memory s = _custodyProfileSelection(sale.tokenId);
        return StreamTokenProfileCustodyTypes.Authorization(
            id,
            sale.configHash,
            keccak256(abi.encode(joinedHouse.custodyOrigin(id))),
            sale.tokenId,
            s.assignmentHash,
            _joinedPrimaryPolicy(sale.tokenId, s),
            1,
            address(joinedArtist),
            id,
            uint64(block.timestamp + 1 days)
        );
    }

    function _custodyProfileCall(StreamTokenProfileCustodyTypes.Authorization memory a)
        internal
        returns (bytes memory)
    {
        bytes32 digest = _custodyTyped(
            "6529StreamTokenProfileCustodyAllowCurrent",
            keccak256(
                abi.encode(
                    keccak256(
                        "TokenProfileCustodyActivation(bytes32 auctionId,bytes32 baseConfigHash,bytes32 originHash,uint256 tokenId,bytes32 assignmentHash,bytes32 primaryPolicyHash,uint8 primaryPolicyMode,address artist,bytes32 nonce,uint64 deadline)"
                    ),
                    a
                )
            )
        );
        require(
            digest == joinedHouse.tokenProfileCustodyDigest(a),
            "independent profile activation digest"
        );
        return abi.encodeCall(
            joinedHouse.activateTokenProfileCustody,
            (a, _platformProof(digest), _artistProof(digest))
        );
    }

    function custodyActivateProfile(bytes32 id) external {
        require(msg.sender == address(this), "fixture self");
        StreamTokenProfileCustodyTypes.Authorization memory a = this.custodyProfileAuthorization(id);
        bytes memory data = _custodyProfileCall(a);
        (bool ok, bytes memory reason) = address(joinedHouse).call(data);
        if (!ok) assembly ("memory-safe") { revert(add(reason, 32), mload(reason)) }
        StreamTokenProfileCustodyTypes.Activation memory active =
            joinedHouse.tokenProfileCustodyActivation(id);
        require(
            active.effectiveConfigHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_TOKEN_PROFILE_CUSTODY_ALLOW_CURRENT_CONFIG_V1"),
                        block.chainid,
                        address(joinedHouse),
                        a,
                        active.authorizationDigest
                    )
                ),
            "independent appended profile config"
        );
        _custodyOriginal(id, true);
    }

    function custodyActivateDynamic(bytes32 id) external {
        require(msg.sender == address(this), "fixture self");
        IStreamNativeEnglishAuction.Auction memory sale = joinedHouse.auction(id);
        (StreamSaleTemplate.Selection memory s,) = _custodyDynamicSelection(sale.tokenId);
        StreamCustodyRightsTypes.Authorization memory a = StreamCustodyRightsTypes.Authorization(
            id,
            sale.configHash,
            keccak256(abi.encode(joinedHouse.custodyOrigin(id))),
            sale.tokenId,
            4,
            s.assignmentHash,
            _joinedPrimaryPolicy(sale.tokenId, s),
            1,
            address(joinedArtist),
            id,
            uint64(block.timestamp + 1 days)
        );
        bytes32 digest = _custodyTyped(
            "6529StreamCustodyRightsAllowCurrent",
            keccak256(
                abi.encode(
                    keccak256(
                        "CustodyRightsActivation(bytes32 auctionId,bytes32 baseConfigHash,bytes32 originHash,uint256 tokenId,uint8 rightsMode,bytes32 assignmentHash,bytes32 primaryPolicyHash,uint8 primaryPolicyMode,address artist,bytes32 nonce,uint64 deadline)"
                    ),
                    a
                )
            )
        );
        require(
            digest == joinedHouse.custodyRightsDigest(a), "independent dynamic activation digest"
        );
        joinedHouse.activateCustodyRights(a, _platformProof(digest), _artistProof(digest));
        StreamCustodyRightsTypes.Activation memory active = joinedHouse.custodyRightsActivation(id);
        require(
            active.effectiveConfigHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CUSTODY_RIGHTS_ALLOW_CURRENT_CONFIG_V1"),
                        block.chainid,
                        address(joinedHouse),
                        a,
                        digest
                    )
                ),
            "independent appended dynamic config"
        );
        _custodyOriginal(id, true);
    }

    function _custodyOriginal(bytes32 id, bool eligible) internal view {
        IStreamNativeEnglishAuction.Auction memory sale = joinedHouse.auction(id);
        StreamNativeCustodySettlementTypes.Origin memory original = joinedHouse.custodyOrigin(id);
        original.eligible = true;
        (address receiver, uint256 amount) = core.royaltyInfo(sale.tokenId, 10000);
        require(
            receiver == joinedSource.config.wallet && amount == 600,
            "actual Core keeps frozen disclosure after primary changes"
        );
        require(
            keccak256(abi.encode(original)) == keccak256(abi.encode(acquiredOrigin))
                && joinedHouse.custodyOrigin(id).eligible == eligible
                && sale.config.poster == address(this)
                && sale.configHash == joinedHouse.auctionConfigurationHash(sale.config)
                && acquiredNonce == manager.nextOperationNonce()
                && core.lastAllocatedTokenId() == acquiredOrigin.tokenId
                && core.collectionNextSerial(1) == acquiredOrigin.collectionSerial + 1
                && keccak256(core.tokenData(sale.tokenId)) == acquiredOrigin.tokenDataHash
                && keccak256(abi.encode(royalties.royaltySnapshot(sale.tokenId)))
                    == keccak256(abi.encode(acquiredSnapshot))
                && entropy.revealFeeEscrow(sale.tokenId) == 100,
            "same original token/mint/source/proof/reveal"
        );
    }

    function _custodyBid(bytes32 id, bool dynamic_) internal {
        bytes memory data = dynamic_
            ? abi.encodeCall(joinedHouse.bidCustodyRights, (id, address(joinedCollector)))
            : abi.encodeCall(joinedHouse.bidTokenProfileCustody, (id, address(joinedCollector)));
        _joinedSafe(joinedCollector, address(joinedHouse), JOINED_PRICE, data);
        IStreamNativeEnglishAuction.WinningBid memory b = joinedHouse.auction(id).winner;
        require(
            b.payer == address(joinedCollector) && b.executor == address(joinedCollector)
                && b.deliverTo == address(joinedCollector) && b.amount == JOINED_PRICE
                && b.revealFee == 0,
            "collector Safe funds only the later primary price"
        );
    }

    function _custodyEnd(bytes32 id) internal {
        (uint64 end,,,) = joinedHouse.auctionDeadlines(id);
        vm.warp(end);
    }

    function _custodySettleData(bytes32 id, bool dynamic_) internal view returns (bytes memory) {
        return dynamic_
            ? abi.encodeCall(joinedHouse.settleCustodyRights, (id))
            : abi.encodeCall(joinedHouse.settleTokenProfileCustody, (id));
    }

    function _custodySafeCall(OfficialSafe safe, address target, uint256 value, bytes memory data)
        internal
        returns (bytes memory)
    {
        bytes32 digest = safe.getTransactionHash(
            target, value, data, 0, 0, 0, 0, address(0), address(0), safe.nonce()
        );
        return abi.encodeCall(
            safe.execTransaction,
            (
                target,
                value,
                data,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(joinedKeys, digest)
            )
        );
    }

    function _custodyFinish(bytes32 id, bool dynamic_, StreamSaleTemplate.Selection memory selected)
        internal
    {
        _custodyEnd(id);
        IStreamNativeEnglishAuction.Auction memory sale = joinedHouse.auction(id);
        sale.status = 2;
        StreamNativeCustodySettlementTypes.Facts memory facts =
            StreamNativeCustodySettlementTypes.Facts(id, sale, acquiredOrigin);
        vm.recordLogs();
        _joinedSafe(joinedCollector, address(joinedHouse), 0, _custodySettleData(id, dynamic_));
        _custodyReceipt(id, dynamic_, selected, facts, vm.getRecordedLogs());
    }

    function _custodyReceipt(
        bytes32 id,
        bool dynamic_,
        StreamSaleTemplate.Selection memory selected,
        StreamNativeCustodySettlementTypes.Facts memory facts,
        Vm.Log[] memory logs
    ) internal view {
        bytes32 key = joinedHouse.auction(id).settlementKey;
        StreamPrimarySettlementTypes.PrimarySettlementResult memory result =
            joinedRecorder.settlementResult(key);
        bytes32 saleKey = joinedRecorder.preparedNativeSaleKey(
            address(joinedHouse), facts.auction.saleId, facts.auction.saleNonce
        );
        bytes32 factsHash;
        bytes32 eventTopic;
        bytes memory encoded;
        if (dynamic_) {
            eventTopic = 0x1ba2dc4a23e4fb495f1c1f975237c5c0c93eefdba8ce180646e12f7e8d860785;
            StreamCustodyRightsTypes.Activation memory active =
                joinedHouse.custodyRightsActivation(id);
            (, bytes32 witness) = _custodyDynamicSelection(facts.auction.tokenId);
            factsHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_CUSTODY_RIGHTS_FACTS_V1"),
                    block.chainid,
                    address(joinedRecorder),
                    address(joinedHouse),
                    facts,
                    active
                )
            );
            encoded = abi.encode(uint16(1), facts, active, witness, result);
        } else {
            StreamTokenProfileCustodyTypes.Activation memory active =
                joinedHouse.tokenProfileCustodyActivation(id);
            eventTopic = 0x13000ba63a7428760618ad3721e5a23b74d6f2e8dadaacb7e7ccdfcf9dfc9f63;
            factsHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_TOKEN_PROFILE_CUSTODY_FACTS_V1"),
                    block.chainid,
                    address(joinedRecorder),
                    address(joinedHouse),
                    facts,
                    active
                )
            );
            encoded = abi.encode(uint16(1), facts, active, result);
        }
        require(
            joinedRecorder.nativeCustodyFactsHash(key) == factsHash
                && joinedRecorder.preparedNativeSaleConsumed(saleKey)
                && joinedRecorder.settlementConsumed(key) && result.amount == JOINED_PRICE
                && result.profileId == selected.profileId && result.wallet == selected.wallet
                && result.operationIdentityCommitment == 0 && result.currentPolicyHash == 0
                && result.boundPolicyHash == 0
                && core.ownerOf(facts.auction.tokenId) == address(joinedCollector)
                && result.escrowed == dynamic_
                && joinedRecorder.totalOfficialSettled(address(0)) == JOINED_PRICE,
            "complete actual token primary receipt, no second mint fields"
        );
        require(
            dynamic_
                ? revenueEscrow.escrowOwed(
                    PRIMARY_REVENUE_CLASS, selected.profileId, selected.wallet, address(0)
                ) == JOINED_PRICE
                : selected.wallet.balance == JOINED_PRICE,
            "exact official primary destination"
        );
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(joinedRecorder) && logs[i].topics.length == 4
                    && logs[i].topics[0] == eventTopic && logs[i].topics[1] == key
                    && logs[i].topics[2] == saleKey && logs[i].topics[3] == factsHash
            ) {
                ++found;
                require(
                    keccak256(logs[i].data) == keccak256(encoded),
                    "complete versioned custody event bytes"
                );
            }
        }
        require(found == 1, "one full custody revenue receipt");
        _custodyOriginal(id, false);
    }
}
