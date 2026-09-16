// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/CurrentRoyaltySuccessorMintFixture.sol";
import "../../script/current/StreamGovernanceCatalogStagePlan.sol";
import {
    StreamRoyaltyContinuityTypes as RC
} from "../../smart-contracts/interfaces/stream/revenue/IStreamRoyaltyEconomicContinuity.sol";

/// @notice Actual Artist/Safe op15, paid current-Core snapshot and delayed governed Resolver cutover.
/// @dev Source-authored integration; runtime/size acceptance is separate. No new mint authority is inferred from copied receipts.
contract StreamCurrentRoyaltyEconomicContinuityTest is CurrentRoyaltySuccessorMintFixture {
    StreamRoyaltyResolver private nextRoyalty;
    bytes32 private constant POINTER = keccak256("ROYALTY_RESOLVER");

    function setUp() public {
        _deployJoinedCommerce();
    }

    function _mintOriginal(uint8 sourceKind)
        private
        returns (IStreamRoyaltySnapshot.Snapshot memory old)
    {
        this.joinedSnapshotSetup(sourceKind);
        bytes32 templateId = this.joinedCreateTemplate();
        this.joinedApproveTemplate(templateId);
        this.joinedInstallTemplate(templateId);
        this.joinedInstallPhase();
        bytes32 saleId = this.joinedCreateAuction();
        _joinedBid(saleId);
        _joinedSettle(saleId);
        return _joinedAssertMint(saleId);
    }

    function _deployNext() private {
        nextRoyalty = StreamRoyaltyResolver(
            _artistArtifactCreate(
                "smart-contracts/domains/revenue/StreamRoyaltyResolver.sol:StreamRoyaltyResolver",
                abi.encode(
                    core, factory, address(executor), IStreamArtistAttribution(address(artists))
                )
            )
        );
        _assertDeployableProductionInstance(address(nextRoyalty));
        // Extend only this exact new target/selector through the actual saved catalog and required tail.
        GovernanceActionPolicyEntry[] memory rows = new GovernanceActionPolicyEntry[](1);
        rows[0] = GovernanceActionPolicyEntry(
            1,
            address(nextRoyalty),
            nextRoyalty.beginEconomicContinuity.selector,
            address(nextRoyalty).codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, address(nextRoyalty))),
            1,
            0,
            0,
            0
        );
        StreamGovernanceCatalogStagePlan.Inventory memory saved =
            StreamGovernanceCatalogStagePlan.inventory(executor, rows);
        (address payload, StreamSystemManifestUpdate memory update) =
            _discovery("continuity admission");
        (GenesisBatch memory batch, uint256 count) = StreamGovernanceCatalogStagePlan.nextBatch(
            saved,
            StreamGovernanceCatalogStagePlan.inventoryHash(saved),
            0,
            manifest,
            payload,
            update
        );
        require(count == 1, "one exact candidate admission");
        _run(3, batch.calls, batch.callDatas);
    }

    function _reference() private view returns (RC.ManifestRef memory r) {
        RC.Header memory h = royalties.continuityHeader();
        r.expectedSourceHeaderHash = keccak256(abi.encode(h));
        r.uri = "ipfs://actual-current-royalty-continuity";
        r.uriHash = keccak256(bytes(r.uri));
        r.schemaId = keccak256("STREAM_ROYALTY_CONTINUITY_MANIFEST_V1");
        r.canonicalizationId = keccak256("STREAM_ROYALTY_CONTINUITY_ABI_V1");
        r.contentHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROYALTY_CONTINUITY_MANIFEST_V1"),
                block.chainid,
                address(royalties),
                address(royalties).codehash,
                address(nextRoyalty),
                address(core),
                address(factory),
                h,
                r.uri,
                r.uriHash,
                r.schemaId,
                r.canonicalizationId
            )
        );
    }

    function _copy() private returns (bytes32 manifestHash) {
        RC.ManifestRef memory r = _reference();
        (bytes32 hash, bytes32 scope, bytes32 before_, bytes32 after_) =
            nextRoyalty.previewEconomicContinuity(address(royalties), r);
        require(hash == r.contentHash, "canonical original manifest");
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(nextRoyalty.beginEconomicContinuity, (address(royalties), r));
        calls[0] =
            StreamCurrentStackPlan.call(address(nextRoyalty), data[0], scope, before_, after_);
        _run(1, calls, data);
        _joinedSafe(
            joinedCollector,
            address(nextRoyalty),
            0,
            abi.encodeCall(nextRoyalty.importEconomicContinuity, (uint256(16), uint256(64)))
        );
        _joinedSafe(
            joinedCollector,
            address(nextRoyalty),
            0,
            abi.encodeCall(nextRoyalty.completeEconomicContinuity, ())
        );
        return hash;
    }

    function _install() private {
        StreamModuleRegistration memory item = StreamModuleRegistration(
            address(nextRoyalty),
            keccak256("REVENUE_RESOLVER"),
            keccak256("exact royalty economic continuity"),
            type(IStreamRoyaltyResolver).interfaceId,
            500000,
            address(nextRoyalty).codehash,
            DEPLOYMENT_HASH,
            keccak256("continuity reconstruction"),
            "ipfs://continuity-reconstruction"
        );
        StreamModuleRegistration[] memory items = new StreamModuleRegistration[](1);
        items[0] = item;
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, items);
        _run(1, calls, data);
        StreamCorePointerState memory old = StreamCurrentStackPlan.readPointer(core, POINTER);
        StreamCorePointerState memory next =
            StreamCurrentStackPlan.pointerState(address(registry), item, false, old.revision + 1);
        (bytes32 scope, bytes32 before_, bytes32 after_) =
            StreamCurrentStackPlan.pointerTransitionHashes(core, POINTER, old, next);
        calls = new GovernanceCall[](2);
        data = new bytes[](2);
        data[0] = abi.encodeCall(core.updateSatellitePointer, (POINTER, address(nextRoyalty)));
        calls[0] = StreamCurrentStackPlan.call(address(core), data[0], scope, before_, after_);
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        current.modules.revenueResolver = address(nextRoyalty);
        (address payload, StreamSystemManifestUpdate memory update) =
            _discovery("continuity pointer replacement");
        (calls[1], data[1]) =
            StreamGenesisManifestPlan.publicationCall(manifest, payload, update, current.modules);
        _run(3, calls, data);
        require(
            StreamCurrentStackPlan.readPointer(core, POINTER).target == address(nextRoyalty),
            "actual governed Core cutover"
        );
    }

    function _discovery(string memory purpose)
        private
        returns (address payload, StreamSystemManifestUpdate memory update)
    {
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        bytes32 hash;
        (payload, hash) =
            StreamGenesisManifestPlan.writePayload(abi.encode(purpose, address(nextRoyalty)));
        update = StreamSystemManifestUpdate(
            hash,
            "ipfs://current-royalty-continuity",
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
    }

    function _run(uint8 cls, GovernanceCall[] memory calls, bytes[] memory data) private {
        (bytes32 action, uint64 ready) = _scheduleBatchAsGovernor(cls, calls, data);
        vm.warp(ready);
        _joinedSafe(
            governorSafe,
            address(executor),
            0,
            abi.encodeCall(executor.executeGovernanceBatch, (action, calls, data))
        );
        require(
            executor.governanceAction(action).status == GovernanceActionStatus.EXECUTED,
            "actual Safe delayed execution"
        );
    }

    function _assertOriginal(IStreamRoyaltySnapshot.Snapshot memory old, bytes32 manifestHash)
        private
        view
    {
        require(
            keccak256(abi.encode(nextRoyalty.royaltySnapshot(old.tokenId)))
                == keccak256(abi.encode(old)),
            "entire original Manager/root/operation/election/source/config and actual token receipt retained"
        );
        require(
            nextRoyalty.tokenRoyalty(old.tokenId).frozen
                && nextRoyalty.continuitySource() == address(royalties)
                && nextRoyalty.supportsEconomicContinuity(
                    address(royalties),
                    royalties.frozenEconomicStateHash(address(core)),
                    manifestHash
                ),
            "complete exact old-resolver economic continuity after actual cutover"
        );
        (address receiver, uint256 amount) = core.royaltyInfo(old.tokenId, RESALE_PRICE);
        require(
            receiver == joinedSource.config.wallet
                && amount == uint256(RESALE_PRICE) * joinedSource.config.royaltyBps / 10000,
            "actual ERC2981 still serves original token terms through successor"
        );
        require(
            core.ownerOf(old.tokenId) == address(joinedCollector),
            "original paid collector remains owner"
        );
    }

    function testActualPositiveDefaultSnapshotSurvivesGovernedResolverCutoverAndSameTokenResale()
        public
    {
        IStreamRoyaltySnapshot.Snapshot memory old = _mintOriginal(0);
        _deployNext();
        bytes32 h = _copy();
        _install();
        _assertOriginal(old, h);
        require(
            nextRoyalty.economicElectionAt(0).hashOrigin == address(royalties)
                && nextRoyalty.protectedEconomicRouteAt(0).hashOrigin == address(royalties),
            "election and token origins retain old domains"
        );
        bytes32 saleId = this.joinedConfigureResale(old.tokenId);
        _joinedCustody(saleId, old.tokenId);
        (address receiver, uint256 due, bool secondary, bool disclosure) =
            joinedPrivate.royaltyQuote(saleId);
        require(
            receiver == joinedSource.config.wallet && due == uint256(RESALE_PRICE) * 600 / 10000
                && secondary && !disclosure,
            "same NFT current Core secondary quote uses copied frozen token, not missing new default"
        );
        _joinedResale(saleId, old);
    }

    function testActualConfiguredZeroSnapshotCopiesOriginalReceiptAndSuppressesFallback() public {
        IStreamRoyaltySnapshot.Snapshot memory old = _mintOriginal(1);
        _deployNext();
        bytes32 h = _copy();
        _install();
        _assertOriginal(old, h);
        require(
            nextRoyalty.tokenRoyalty(old.tokenId).configured
                && nextRoyalty.tokenRoyalty(old.tokenId).royaltyBps == 0,
            "configured zero remains an actual frozen assignment"
        );
        require(
            !nextRoyalty.collectionRoyalty(1).configured
                && !nextRoyalty.defaultRoyalty().configured,
            "only protected ledgers are imported; mutable future configuration is a separate explicit authority action"
        );
        require(
            manager.nextOperationNonce() == 1 && core.lastAllocatedTokenId() == old.tokenId,
            "copying a receipt never repeats original mint or consumes another operation"
        );
    }

    // The following cases are authored for the explicitly proposed current royalty consumer.
    // Their expected success is intentionally not replaced by a mock or a missing-feature skip.
    function _admitExtraPolicy(address target, bytes4 selector) private {
        GovernanceActionPolicyEntry[] memory rows = new GovernanceActionPolicyEntry[](1);
        rows[0] = GovernanceActionPolicyEntry(
            1,
            target,
            selector,
            target.codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, target)),
            1,
            0,
            0,
            0
        );
        StreamGovernanceCatalogStagePlan.Inventory memory saved =
            StreamGovernanceCatalogStagePlan.inventory(executor, rows);
        (address payload, StreamSystemManifestUpdate memory update) =
            _discovery("successor exact operating selector");
        (GenesisBatch memory batch, uint256 count) = StreamGovernanceCatalogStagePlan.nextBatch(
            saved,
            StreamGovernanceCatalogStagePlan.inventoryHash(saved),
            0,
            manifest,
            payload,
            update
        );
        require(count == 1, "one exact new operating policy");
        _run(3, batch.calls, batch.callDatas);
    }

    function _cutoverSnapshot(uint8 sourceKind)
        private
        returns (IStreamRoyaltySnapshot.Snapshot memory old, bytes32 manifestHash)
    {
        old = _mintOriginal(sourceKind);
        _deployNext();
        manifestHash = _copy();
        _install();
        _admitExtraPolicy(address(nextRoyalty), nextRoyalty.configureDefaultRoyalty.selector);
        _admitExtraPolicy(address(nextRoyalty), nextRoyalty.configureCollectionRoyalty.selector);
        this.joinedGovern(
            address(nextRoyalty),
            abi.encodeCall(
                nextRoyalty.configureDefaultRoyalty,
                (sourceKind == 2 ? bytes32(0) : profile, sourceKind == 2 ? uint16(0) : uint16(600))
            )
        );
    }

    function _approveSuccessorSnapshot(uint8 sourceKind) private returns (bytes32 record) {
        if (sourceKind == 1) {
            _successorProspectiveZero(nextRoyalty);
            record = _joinedConsentEvidence(
                _successorPayload(nextRoyalty.currentArtistSnapshotRoyaltyAssignment(1))
            );
        } else {
            record = _successorApprove(nextRoyalty.currentArtistSnapshotRoyaltyAssignment(1));
        }
    }

    function _assertUnchangedSnapshot(
        StreamRoyaltyResolver target,
        IStreamRoyaltySnapshot.Snapshot memory old
    ) private view {
        require(
            keccak256(abi.encode(target.royaltySnapshot(old.tokenId)))
                == keccak256(abi.encode(old)),
            "every old prepared field remains byte-exact after later mint"
        );
    }

    function testActualSuccessorPositiveSnapshotFreshConsentNewPhaseAndMint() public {
        (IStreamRoyaltySnapshot.Snapshot memory old, bytes32 manifestHash) = _cutoverSnapshot(0);
        T.AssignmentFact memory fact = nextRoyalty.currentArtistSnapshotRoyaltyAssignment(1);
        T.EconomicsConsent memory original =
            T.EconomicsConsent(1, address(royalties), ROYALTY_CLASS, 1, 1, old.modeAssignmentHash);
        bytes32 oldConsent = _joinedConsentEvidence(original);
        (bool admitted,) = address(nextRoyalty)
            .staticcall(abi.encodeCall(nextRoyalty.currentRoyaltySnapshotSource, (uint256(1))));
        require(!admitted && oldConsent != 0, "real old op15 cannot authorize candidate source");
        bytes32 newConsent = _approveSuccessorSnapshot(0);
        require(
            newConsent != oldConsent && fact.resolver == address(nextRoyalty),
            "new original-domain op15 names current consumer"
        );
        Consumer.Receipt memory receipt =
            _assertConsumer(nextRoyalty, address(royalties), address(royalties), manifestHash);
        (IStreamRoyaltySnapshot.Snapshot memory current, uint256 token) =
            _successorMint(nextRoyalty, keccak256("successor positive phase"), true);
        require(
            token == 2 && current.electionHash == old.electionHash
                && current.modeAssignmentHash != old.modeAssignmentHash,
            "retained election with fresh candidate source"
        );
        _assertUnchangedSnapshot(nextRoyalty, old);
        require(
            keccak256(abi.encode(Consumer(address(nextRoyalty)).royaltyConsumerContinuity()))
                == keccak256(abi.encode(receipt)),
            "later snapshots do not mutate completed lineage"
        );
        nextRoyalty.currentRoyaltySnapshotSource(1);
        artists.requireMintConsent(
            1,
            keccak256("successor positive phase"),
            manager.phasePolicyHash(1, keccak256("successor positive phase"))
        );
        (address receiver, uint256 due) = core.royaltyInfo(token, RESALE_PRICE);
        require(
            receiver == wallet && due == RESALE_PRICE * 600 / 10000, "new token actual Core quote"
        );
        bytes32 saleId = this.joinedConfigureResale(old.tokenId);
        _joinedCustody(saleId, old.tokenId);
        _joinedResale(saleId, old);
    }

    function testActualSuccessorCollectionConfiguredZeroSnapshotAfterPositiveDefault() public {
        (IStreamRoyaltySnapshot.Snapshot memory old, bytes32 manifestHash) = _cutoverSnapshot(1);
        _approveSuccessorSnapshot(1);
        _assertConsumer(nextRoyalty, address(royalties), address(royalties), manifestHash);
        (IStreamRoyaltySnapshot.Snapshot memory current, uint256 token) =
            _successorMint(nextRoyalty, keccak256("successor collection zero phase"), true);
        require(
            token == 2 && nextRoyalty.defaultRoyalty().royaltyBps == 600
                && nextRoyalty.collectionRoyalty(1).configured
                && nextRoyalty.tokenRoyalty(token).configured
                && nextRoyalty.tokenRoyalty(token).frozen
                && nextRoyalty.tokenRoyalty(token).royaltyBps == 0
                && current.tokenRoyaltyPolicyHash != 0,
            "explicit zero is an actual captured policy, not absence"
        );
        (address receiver, uint256 due) = core.royaltyInfo(token, RESALE_PRICE);
        require(
            receiver == address(0) && due == 0,
            "zero collection snapshot suppresses positive default"
        );
        (address assignmentOrigin, address electionOrigin) =
            Consumer(address(nextRoyalty)).royaltyHashOrigins(2, token, 1);
        require(
            assignmentOrigin == address(nextRoyalty) && electionOrigin == address(royalties),
            "new token and original election domains distinct"
        );
        _assertUnchangedSnapshot(nextRoyalty, old);
    }

    function testActualSuccessorZeroDefaultSnapshotDoesNotInventCollectionOverride() public {
        (IStreamRoyaltySnapshot.Snapshot memory old,) = _cutoverSnapshot(2);
        _approveSuccessorSnapshot(2);
        (IStreamRoyaltySnapshot.Snapshot memory current, uint256 token) =
            _successorMint(nextRoyalty, keccak256("successor default zero phase"), true);
        require(
            token == 2 && !nextRoyalty.collectionRoyalty(1).configured
                && nextRoyalty.defaultRoyalty().configured && current.exists
                && current.tokenAssignmentHash != 0,
            "selected configured-zero default remains distinct from missing collection"
        );
        (address receiver, uint256 due) = core.royaltyInfo(token, RESALE_PRICE);
        require(receiver == address(0) && due == 0, "actual configured-zero default snapshot");
        _assertUnchangedSnapshot(nextRoyalty, old);
    }

    function _liveCutover(bool zero) private {
        bytes32 templateId = this.joinedCreateTemplate();
        this.joinedApproveTemplate(templateId);
        this.joinedInstallTemplate(templateId);
        if (zero) {
            this.joinedGovern(
                address(royalties),
                abi.encodeCall(royalties.configureDefaultRoyalty, (bytes32(0), uint16(0)))
            );
        }
        _admitExtraPolicy(address(royalties), royalties.freezeDefaultRoyalty.selector);
        this.joinedGovern(address(royalties), abi.encodeCall(royalties.freezeDefaultRoyalty, ()));
        T.AssignmentFact memory oldFact = royalties.currentArtistRoyaltyAssignment(1);
        bytes32 oldConsent = _successorApprove(oldFact);
        (, uint256 first) = _successorMint(royalties, keccak256("original live phase"), false);
        require(
            first == 1 && royalties.defaultRoyalty().frozen,
            "real first live mint under protected terms"
        );
        _deployNext();
        bytes32 manifestHash = _copy();
        _install();
        T.AssignmentFact memory current = nextRoyalty.currentArtistRoyaltyAssignment(1);
        require(
            current.assignmentHash == oldFact.assignmentHash
                && current.resolver != oldFact.resolver,
            "copy preserves protected hash but does not rename consumer"
        );
        (bool oldAccepted,) = address(artists)
            .staticcall(
                abi.encodeCall(
                    artists.requireMintConsent,
                    (
                        uint256(1),
                        keccak256("original live phase"),
                        manager.phasePolicyHash(1, keccak256("original live phase"))
                    )
                )
            );
        require(!oldAccepted, "old live economics receipt does not authorize replacement");
        bytes32 fresh = _successorApprove(current);
        require(fresh != oldConsent, "candidate-specific live consent despite identical assignment");
        _assertConsumer(nextRoyalty, address(royalties), address(royalties), manifestHash);
        (, uint256 second) = _successorMint(nextRoyalty, keccak256("successor live phase"), false);
        require(
            second == 2 && !nextRoyalty.royaltySnapshot(first).exists
                && !nextRoyalty.royaltySnapshot(second).exists,
            "neither real live mint has a fabricated snapshot"
        );
        require(
            keccak256(abi.encode(nextRoyalty.defaultRoyalty()))
                == keccak256(abi.encode(royalties.defaultRoyalty())),
            "complete protected live terms retained"
        );
        (address receiver, uint256 due) = core.royaltyInfo(second, RESALE_PRICE);
        require(
            receiver == (zero ? address(0) : wallet)
                && due == (zero ? 0 : uint256(RESALE_PRICE) * 600 / 10000),
            "actual current live quote after second paid mint"
        );
    }

    function testActualSuccessorFrozenPositiveDefaultLiveNewMint() public {
        _liveCutover(false);
    }

    function testActualSuccessorFrozenZeroDefaultLiveNewMint() public {
        _liveCutover(true);
    }

    function testActualSuccessorPaidSafeFailureThenByteIdenticalRetry() public {
        (IStreamRoyaltySnapshot.Snapshot memory old,) = _cutoverSnapshot(0);
        _approveSuccessorSnapshot(0);
        bytes32 phaseId = keccak256("successor saved Safe phase");
        IStreamRoyaltySnapshot.Source memory source = _successorPhase(nextRoyalty, phaseId, true);
        bytes32 id = _successorAuction(phaseId);
        _joinedBid(id);
        (uint64 end,,,) = joinedHouse.auctionDeadlines(id);
        vm.warp(end);
        this.joinedGovern(
            address(nextRoyalty),
            abi.encodeCall(nextRoyalty.configureDefaultRoyalty, (profile, uint16(500)))
        );
        bytes memory callData = abi.encodeCall(joinedHouse.settle, (id));
        SuccessorCallCounts(address(vm)).expectCall(address(joinedHouse), 0, callData, 2);
        (bytes memory signed, uint256 nonce) =
            _savedSuccessorSafe(joinedCollector, address(joinedHouse), callData);
        uint256 balance = address(joinedCollector).balance;
        bytes32 header = keccak256(abi.encode(nextRoyalty.continuityHeader()));
        (bool ok, bytes memory failed) = address(joinedCollector).call(signed);
        require(
            !ok && keccak256(failed) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && joinedCollector.nonce() == nonce && address(joinedCollector).balance == balance
                && core.lastAllocatedTokenId() == 1 && core.pendingPreparedMintTokenId() == 0
                && manager.nextOperationNonce() == 1 && !nextRoyalty.royaltySnapshot(2).exists
                && joinedHouse.totalBuyerLiabilities() == JOINED_PRICE + 100
                && joinedRecorder.totalOfficialSettled(address(0)) == JOINED_PRICE
                && keccak256(abi.encode(nextRoyalty.continuityHeader())) == header,
            "failed saved transaction rolls back Safe, allocation, snapshot, ledger and payments"
        );
        this.joinedGovern(
            address(nextRoyalty),
            abi.encodeCall(nextRoyalty.configureDefaultRoyalty, (profile, uint16(600)))
        );
        require(
            nextRoyalty.currentRoyaltySnapshotSource(1).modeAssignmentHash
                == source.modeAssignmentHash,
            "restore the exact previously approved candidate preimage"
        );
        vm.recordLogs();
        (ok,) = address(joinedCollector).call(signed);
        require(
            ok && joinedCollector.nonce() == nonce + 1, "identical signatures and CALL retry once"
        );
        _joinedReceipt(id, vm.getRecordedLogs());
        _assertSuccessorMint(nextRoyalty, id, source, true);
        _assertUnchangedSnapshot(nextRoyalty, old);
        (ok,) = address(joinedCollector).call(signed);
        require(
            !ok && joinedCollector.nonce() == nonce + 1 && manager.nextOperationNonce() == 2,
            "saved Safe replay cannot mint a third token"
        );
    }

    function testActualSuccessorRejectsSignatureForOriginalResolverWithoutConsumingNonce() public {
        _cutoverSnapshot(0);
        T.EconomicsConsent memory p =
            _successorPayload(nextRoyalty.currentArtistSnapshotRoyaltyAssignment(1));
        T.Authorization memory a = _successorAuthorization();
        T.EconomicsConsent memory wrong = T.EconomicsConsent(
            p.collectionId, address(royalties), p.revenueClass, p.scope, p.scopeId, p.assignmentHash
        );
        a.signature = _joinedProof(joinedArtist, _successorDigest(wrong, a));
        uint256 safeNonce = joinedArtist.nonce();
        (bytes memory signed,) = _savedSuccessorSafe(
            joinedArtist, address(artists), abi.encodeCall(artists.recordEconomicsConsent, (p, a))
        );
        (bool ok, bytes memory failed) = address(joinedArtist).call(signed);
        require(
            !ok && keccak256(failed) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && joinedArtist.nonce() == safeNonce && _successorAuthorization().nonce == a.nonce,
            "wrong original-resolver signature is not candidate authority"
        );
        _successorApprove(nextRoyalty.currentArtistSnapshotRoyaltyAssignment(1));
        _successorMint(nextRoyalty, keccak256("correct original domain successor phase"), true);
    }

    function testActualSuccessorMultiHopRetainsBothSnapshotsAndOriginalElectionOrigin() public {
        (IStreamRoyaltySnapshot.Snapshot memory first,) = _cutoverSnapshot(0);
        StreamRoyaltyResolver origin = royalties;
        StreamRoyaltyResolver middle = nextRoyalty;
        _approveSuccessorSnapshot(0);
        (IStreamRoyaltySnapshot.Snapshot memory second,) =
            _successorMint(middle, keccak256("middle successor phase"), true);
        // Fixture references select the next source; no contract pointer or suite is forged here.
        royalties = middle;
        _deployNext();
        bytes32 manifestHash = _copy();
        _install();
        _admitExtraPolicy(address(nextRoyalty), nextRoyalty.configureDefaultRoyalty.selector);
        this.joinedGovern(
            address(nextRoyalty),
            abi.encodeCall(nextRoyalty.configureDefaultRoyalty, (profile, uint16(600)))
        );
        (bool oldAccepted,) = address(nextRoyalty)
            .staticcall(abi.encodeCall(nextRoyalty.currentRoyaltySnapshotSource, (uint256(1))));
        require(!oldAccepted, "middle consent never aliases final consumer");
        _approveSuccessorSnapshot(0);
        _assertConsumer(nextRoyalty, address(origin), address(middle), manifestHash);
        (IStreamRoyaltySnapshot.Snapshot memory third, uint256 token) =
            _successorMint(nextRoyalty, keccak256("final successor phase"), true);
        require(
            token == 3 && third.electionHash == first.electionHash
                && third.electionHash == second.electionHash,
            "three actual mints preserve original election provenance"
        );
        _assertUnchangedSnapshot(nextRoyalty, first);
        _assertUnchangedSnapshot(nextRoyalty, second);
        (address firstOrigin, address election) =
            Consumer(address(nextRoyalty)).royaltyHashOrigins(2, 1, 1);
        (address secondOrigin,) = Consumer(address(nextRoyalty)).royaltyHashOrigins(2, 2, 1);
        (address thirdOrigin,) = Consumer(address(nextRoyalty)).royaltyHashOrigins(2, 3, 1);
        require(
            firstOrigin == address(origin) && secondOrigin == address(middle)
                && thirdOrigin == address(nextRoyalty) && election == address(origin),
            "exact per-token hash origins across hops"
        );
        nextRoyalty.currentRoyaltySnapshotSource(1);
    }

    function _requireConsumerRefusal(address failedTarget) private view {
        (bool ok, bytes memory reason) = address(artistCoordinator.reads())
            .staticcall(abi.encodeWithSignature("currentAssignments(uint256)", uint256(1)));
        require(
            !ok
                && keccak256(reason)
                    == keccak256(abi.encodeWithSelector(T.ComponentChanged.selector, failedTarget)),
            "consumer failure is terminal, with the actual failed component"
        );
    }

    function _healthyConsumerAgain(IStreamRoyaltySnapshot.Snapshot memory old) private view {
        (T.AssignmentFact memory primary, T.AssignmentFact memory royalty) =
            artistCoordinator.reads().currentAssignments(1);
        require(
            primary.resolver == address(primaryResolver)
                && royalty.resolver == address(nextRoyalty),
            "restored actual graph selects only intended consumer"
        );
        nextRoyalty.currentRoyaltySnapshotSource(1);
        _assertUnchangedSnapshot(nextRoyalty, old);
    }

    function testActualSuccessorRejectsIncompleteOrForeignReceiptFieldsAndRestores() public {
        (IStreamRoyaltySnapshot.Snapshot memory old,) = _cutoverSnapshot(0);
        _approveSuccessorSnapshot(0);
        bytes memory original =
            abi.encode(Consumer(address(nextRoyalty)).royaltyConsumerContinuity());
        bytes memory callData = abi.encodeCall(Consumer.royaltyConsumerContinuity, ());
        for (uint256 i; i < 12; ++i) {
            Consumer.Receipt memory bad = abi.decode(original, (Consumer.Receipt));
            if (i == 0) bad.status = 0;
            else if (i == 1) bad.status = 1;
            else if (i == 2) bad.core = address(primaryResolver);
            else if (i == 3) bad.factory = address(primaryResolver);
            else if (i == 4) bad.origin = address(nextRoyalty);
            else if (i == 5) bad.originRuntimeHash = keccak256("wrong original runtime");
            else if (i == 6) bad.source = address(0);
            else if (i == 7) bad.source = address(nextRoyalty);
            else if (i == 8) bad.sourceRuntimeHash = keccak256("wrong immediate runtime");
            else if (i == 9) bad.manifestHash = 0;
            else if (i == 10) bad.beginActionId = 0;
            else bad.importedHeaderHash = 0;
            SuccessorFaultVm(address(vm)).mockCall(address(nextRoyalty), callData, abi.encode(bad));
            _requireConsumerRefusal(address(nextRoyalty));
            // Stored original-token disclosure is deliberately independent of new-mint admission.
            (address receiver, uint256 due) = core.royaltyInfo(old.tokenId, RESALE_PRICE);
            require(
                receiver == wallet && due == RESALE_PRICE * 600 / 10000,
                "receipt refusal cannot erase frozen token money"
            );
            SuccessorFaultVm(address(vm)).clearMockedCalls();
            _healthyConsumerAgain(old);
        }
    }

    function testActualSuccessorRequiresExactReceiptWidthAndCanonicalCapabilityReplies() public {
        (IStreamRoyaltySnapshot.Snapshot memory old,) = _cutoverSnapshot(0);
        _approveSuccessorSnapshot(0);
        bytes memory callData = abi.encodeCall(Consumer.royaltyConsumerContinuity, ());
        bytes memory original =
            abi.encode(Consumer(address(nextRoyalty)).royaltyConsumerContinuity());
        require(original.length == 320, "ten-word complete fixed receipt");
        for (uint256 i; i < 4; ++i) {
            bytes memory bad = i == 3
                ? bytes.concat(original, bytes32(0))
                : new bytes(i == 0 ? 0 : i == 1 ? 32 : 319);
            SuccessorFaultVm(address(vm)).mockCall(address(nextRoyalty), callData, bad);
            _requireConsumerRefusal(address(nextRoyalty));
            SuccessorFaultVm(address(vm)).clearMockedCalls();
        }
        for (uint256 field; field < 3; ++field) {
            address target = field == 2 ? address(registry) : address(nextRoyalty);
            bytes memory query = field == 0
                ? abi.encodeWithSignature("supportsInterface(bytes4)", type(Consumer).interfaceId)
                : field == 1
                    ? abi.encodeCall(nextRoyalty.economicContinuityReady, ())
                    : abi.encodeWithSignature(
                        "isModuleEligible(address,bytes32,bytes4)",
                        address(nextRoyalty),
                        keccak256("REVENUE_RESOLVER"),
                        type(IStreamRoyaltyResolver).interfaceId
                    );
            for (uint256 shape; shape < 4; ++shape) {
                bytes memory bad = shape == 0
                    ? abi.encode(uint256(0))
                    : shape == 1
                        ? abi.encode(uint256(2))
                        : shape == 2 ? bytes(hex"01") : abi.encode(uint256(1), uint256(0));
                SuccessorFaultVm(address(vm)).mockCall(target, query, bad);
                _requireConsumerRefusal(shape >= 2 ? target : address(nextRoyalty));
                SuccessorFaultVm(address(vm)).clearMockedCalls();
            }
        }
        _healthyConsumerAgain(old);
        _successorMint(nextRoyalty, keccak256("restored canonical views phase"), true);
    }

    function testActualSuccessorRuntimeDriftRefusesNewConsumerButExactRestorationWorks() public {
        (IStreamRoyaltySnapshot.Snapshot memory old,) = _cutoverSnapshot(0);
        _approveSuccessorSnapshot(0);
        bytes memory original = address(royalties).code;
        vm.etch(address(royalties), hex"60006000fd");
        _requireConsumerRefusal(address(royalties));
        vm.etch(address(royalties), original);
        _healthyConsumerAgain(old);
        original = address(nextRoyalty).code;
        vm.etch(address(nextRoyalty), hex"60006000fd");
        _requireConsumerRefusal(address(nextRoyalty));
        vm.etch(address(nextRoyalty), original);
        _healthyConsumerAgain(old);
        _successorMint(nextRoyalty, keccak256("restored exact runtime phase"), true);
    }

    function testOriginalSelectedProviderDoesNotRequireAdditiveConsumerCapability() public {
        IStreamRoyaltySnapshot.Snapshot memory old = _mintOriginal(0);
        SuccessorFaultVm(address(vm))
            .mockCallRevert(
                address(royalties),
                abi.encodeWithSignature("supportsInterface(bytes4)", type(Consumer).interfaceId),
                hex"aabbccdd"
            );
        SuccessorFaultVm(address(vm))
            .mockCallRevert(
                address(royalties),
                abi.encodeCall(Consumer.royaltyConsumerContinuity, ()),
                hex"aabbccdd"
            );
        (T.AssignmentFact memory primary, T.AssignmentFact memory royalty) =
            artistCoordinator.reads().currentAssignments(1);
        require(
            primary.resolver == address(primaryResolver) && royalty.resolver == address(royalties),
            "original immutable providers do not enter replacement capability branch"
        );
        royalties.currentRoyaltySnapshotSource(1);
        _successorMint(royalties, keccak256("original direct second mint phase"), true);
        _assertUnchangedSnapshot(royalties, old);
        SuccessorFaultVm(address(vm)).clearMockedCalls();
    }
}
