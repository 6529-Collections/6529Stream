// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentSafeGovernanceFixture.sol";
import {
    StreamNativeCommerceDeployment,
    StreamNativeEnglishAuction,
    StreamPrimarySaleSettlement,
    IStreamNativeEnglishAuction,
    StreamEnglishAuctionClock
} from "../../script/current/StreamNativeCommerceDeployment.sol";
import {
    IStreamRoyaltySnapshot
} from "../../smart-contracts/interfaces/stream/revenue/IStreamRoyaltySnapshot.sol";
import {
    IStreamMintRoyaltyPolicy
} from "../../smart-contracts/interfaces/stream/mint/IStreamMintRoyaltyPolicy.sol";
import {
    IStreamArtistSnapshotRoyaltyFacts
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistSnapshotRoyaltyFacts.sol";
import {
    IStreamArtistEconomicsEvidence
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistEconomicsEvidence.sol";

/// @notice Real Artist/Governor/Payer Safes join current Core prepared auctions and royalty snapshots.
/// @dev Only the external entropy service is a double. These aggregate workflows do not
/// establish individual cold transaction capacity or other royalty/primary rights profiles.
contract StreamCurrentArtistRoyaltySnapshotTest is StreamCurrentSafeGovernanceFixture {
    bytes32 private constant SNAPSHOT_PHASE = keccak256("actual Artist royalty snapshot auction");
    bytes32 private constant ROYALTY_CLASS = keccak256("ROYALTY_ERC2981");
    bytes32 private constant APPLICATION = keccak256("actual snapshot application");
    uint96 private constant PRICE = 1_000_000;
    uint16 private constant ORIGINAL_BPS = 600;

    StreamNativeCommerceDeployment.Products private commerce;
    StreamPrimarySaleSettlement private recorder;
    StreamNativeEnglishAuction private house;
    OfficialSafe private artistSafe;
    OfficialSafe private payerSafe;
    uint256[] private signingKeys;
    IStreamRoyaltySnapshot.Source private originalSource;

    function setUp() public {
        signingKeys.push(0x5A9101);
        signingKeys.push(0x5A9102);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        artistSafe = createOfficialSafe(components, safeOwnerAddresses(signingKeys), 2, 901);
        payerSafe = createOfficialSafe(components, safeOwnerAddresses(signingKeys), 2, 902);
        OfficialSafe nextGovernor =
            createOfficialSafe(components, safeOwnerAddresses(signingKeys), 2, 903);
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
        this.installSnapshotGovernor(nextGovernor);
        vm.deal(address(payerSafe), 1 ether);
        require(
            core.collectionNextSerial(1) == 1 && core.collectionMintedEver(1) == 0,
            "actual unminted collection before immutable election"
        );
    }

    function installSnapshotGovernor(OfficialSafe next) external {
        require(msg.sender == address(this), "test only");
        _installGovernorSafe(next, signingKeys);
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return
            safeThresholdSignature(signingKeys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function _configureInitialRevealPolicy() internal override {
        entropy.configureCollectionRevealPolicy(
            1, 1, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 100, 100
        );
    }

    function _deployAdditionalProducts() internal override {
        StreamNativeEnglishAuction.DeploymentConfig memory d;
        d.manager = manager;
        d.platform = vm.addr(PLATFORM_KEY);
        d.artists = IStreamArtistAttribution(address(artists));
        d.entropy = IStreamRevealFeeEscrow(address(entropy));
        d.roles = roles;
        d.authority = address(executor);
        d.parameters[0] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ERC1271_GAS_LIMIT", 400_000, 350_000, 2
        );
        d.parameters[1] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ARTIST_AUTHORITY_GAS_LIMIT", 300_000, 50_000, 2
        );
        d.parameters[2] = IStreamGasParameterHost.GasParameterConfig(
            "REVEAL_ATTEMPT_GAS_LIMIT", 200_000, 50_000, 2
        );
        d.parameters[3] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_NFT_DELIVERY_GAS_LIMIT", 300_000, 100_000, 2
        );
        commerce = StreamNativeCommerceDeployment.deploy(
            primaryResolver,
            registry,
            revenueEscrow,
            d,
            DEPLOYMENT_HASH,
            keccak256("actual royalty snapshot commerce modules")
        );
        recorder = commerce.recorder;
        house = commerce.house;
        _assertDeployableProductionInstance(address(recorder));
        _assertDeployableProductionInstance(address(house));
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        GovernanceActionPolicyEntry[] memory intents =
            StreamNativeCommerceDeployment.policies(commerce);
        rows = new GovernanceActionPolicyEntry[](4);
        uint256 n;
        for (uint256 i; i < intents.length; ++i) {
            if (intents[i].target == address(manager) || intents[i].target == address(house)) {
                rows[n++] = intents[i];
            }
        }
        require(n == 2, "only new commerce selectors");
        rows[n++] = _snapshotPolicy(
            address(royalties), IStreamRoyaltySnapshot.electCollectionRoyaltyMode.selector
        );
        rows[n++] = _snapshotPolicy(
            address(manager), IStreamMintRoyaltyPolicy.registerPhaseRoyaltyPolicy.selector
        );
        require(n == rows.length, "exact two royalty selectors");
    }

    function _snapshotPolicy(address target, bytes4 selector)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
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
    }

    function _configureAdditionalProducts() internal override {
        this.admitSnapshotCommerce();
        (address target, bytes memory data) =
            StreamNativeCommerceDeployment.managerBinding(commerce);
        (bool ok,) = target.call(data);
        require(ok, "actual temporary Manager owner binds admitted recorder before handoff");
    }

    /// @dev External helpers keep time/signature construction in a new frame after each warp.
    function admitSnapshotCommerce() external {
        require(msg.sender == address(this), "test only");
        GenesisBatch memory batch = StreamNativeCommerceDeployment.admission(commerce);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            batch.calls, StreamGovernanceBootstrap.governanceCallsHash(batch.calls)
        );
        uint64 ready = uint64(block.timestamp + executor.minimumDelay(1));
        executor.publishGovernanceCallData(batch.callDatas);
        bytes memory scheduled = governanceRoot.execute(
            address(executor),
            0,
            abi.encodeCall(
                executor.scheduleGovernanceBatch,
                (
                    uint8(1),
                    batch.calls,
                    scope,
                    oldHash,
                    newHash,
                    ready,
                    uint64(ready + 7 days),
                    GOVERNANCE_REASON,
                    "urn:stream:current:snapshot-commerce",
                    DEPLOYMENT_HASH
                )
            )
        );
        vm.warp(ready);
        executor.executeGovernanceBatch(
            abi.decode(scheduled, (bytes32)), batch.calls, batch.callDatas
        );
    }

    function testActualSafeSnapshotConsentPhaseAuctionAndCanonicalTokenRoyalty() public {
        this.electSnapshotMode();
        bytes32 oldPolicy = manager.phasePolicyHash(1, PHASE);
        vm.expectRevert(abi.encodeWithSelector(T.MissingMintPrerequisite.selector, ROYALTY_CLASS));
        artists.requireMintConsent(1, PHASE, oldPolicy);
        require(
            core.lastAllocatedTokenId() == 0 && manager.nextOperationNonce() == 0,
            "old live consent cannot authorize snapshot mint"
        );
        this.approveSnapshotSource(ORIGINAL_BPS);
        this.installSnapshotSource(ORIGINAL_BPS);
        this.configureSnapshotPhase();
        bytes32 id = this.createSnapshotAuction();
        _bidAndSettle(id);
        IStreamRoyaltySnapshot.Snapshot memory s = _assertSnapshot(id);
        require(
            s.operationRoot != 0 && s.operationId != 0 && s.preparedProofHash != 0,
            "actual prepared root and token authority retained"
        );
        _withdrawPrimaryProceeds();
    }

    function testLaterApprovedSourceCannotRewriteTokenSnapshotOrReuseOldPhase() public {
        this.electSnapshotMode();
        this.approveSnapshotSource(ORIGINAL_BPS);
        this.installSnapshotSource(ORIGINAL_BPS);
        this.configureSnapshotPhase();
        bytes32 id = this.createSnapshotAuction();
        _bidAndSettle(id);
        IStreamRoyaltySnapshot.Snapshot memory prior = _assertSnapshot(id);
        bytes32 originalPhasePolicy = manager.phasePolicyHash(1, SNAPSHOT_PHASE);
        bytes32 savedToken = keccak256(abi.encode(royalties.tokenRoyalty(prior.tokenId)));
        this.approveSnapshotSource(700);
        this.installSnapshotSource(700);
        IStreamRoyaltySnapshot.Source memory next = royalties.currentRoyaltySnapshotSource(1);
        require(
            next.modeAssignmentHash != prior.modeAssignmentHash
                && next.sourceAssignmentHash != prior.sourceAssignmentHash
                && next.sourceRoyaltyPolicyHash != prior.sourceRoyaltyPolicyHash
                && next.config.royaltyBps == 700,
            "actual Safe approves distinct collection source after original mint"
        );
        require(
            keccak256(abi.encode(royalties.royaltySnapshot(prior.tokenId)))
                    == keccak256(abi.encode(prior))
                && keccak256(abi.encode(royalties.tokenRoyalty(prior.tokenId))) == savedToken,
            "entire immutable token provenance and config survive source change"
        );
        (address receiver, uint16 bps) =
            royalties.royaltyReceiverAndBps(address(core), prior.tokenId, PRICE, 1, true);
        require(
            receiver == wallet && bps == ORIGINAL_BPS,
            "marketplace reads the original token royalty"
        );
        IStreamMintManager.MintBatch memory batch = _blockedBatch(originalPhasePolicy);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintRoyaltyPolicy.PreparedRoyaltySnapshotRequired.selector, uint256(1)
            )
        );
        vm.prank(address(house));
        manager.previewSingleStepMintOperation(batch, "");
        // This call has the original permitted executor. Failure is the stale royalty source,
        // rather than caller admission; no subsequent retry can satisfy this negative assertion.
        vm.prank(address(house));
        (bool ok, bytes memory why) =
            address(manager).call(abi.encodeCall(manager.executePreparedMint, (batch, bytes(""))));
        require(
            !ok && bytes4(why) == IStreamMintRoyaltyPolicy.InvalidMintRoyaltyPolicy.selector,
            "original phase wrapper rejects a different approved current source"
        );
        require(
            core.lastAllocatedTokenId() == prior.tokenId && core.collectionNextSerial(1) == 2
                && core.pendingPreparedMintTokenId() == 0 && manager.nextOperationNonce() == 1
                && !manager.isAuthorizationUsed(batch.authorizationId)
                && manager.phasePolicyHash(1, SNAPSHOT_PHASE) == originalPhasePolicy,
            "refused stale phase consumes no token, root, authorization or phase state"
        );
    }

    function electSnapshotMode() external {
        require(msg.sender == address(this), "test only");
        _governSnapshotCall(
            address(royalties),
            abi.encodeCall(royalties.electCollectionRoyaltyMode, (uint256(1), uint8(2)))
        );
        (uint8 mode, bytes32 election) = royalties.collectionRoyaltyMode(1);
        require(
            mode == 2
                && election
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ROYALTY_MODE_ELECTION_V1"),
                            block.chainid,
                            address(royalties),
                            address(core),
                            uint256(1),
                            uint8(2)
                        )
                    ),
            "original governed mode election"
        );
    }

    function approveSnapshotSource(uint16 bps) external {
        require(msg.sender == address(this), "test only");
        T.AssignmentFact memory raw =
            royalties.previewArtistRoyaltyAssignmentForScope(1, 1, 1, profile, bps, false);
        T.AssignmentFact memory fact =
            royalties.previewArtistSnapshotRoyaltyAssignment(1, profile, bps, false);
        (, bytes32 election) = royalties.collectionRoyaltyMode(1);
        require(
            fact.assignmentHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SNAPSHOT_ROYALTY_ASSIGNMENT_V1"),
                        block.chainid,
                        address(royalties),
                        address(core),
                        uint256(1),
                        election,
                        raw.assignmentHash
                    )
                ),
            "op15 independently binds original raw source and election"
        );
        T.EconomicsConsent memory p =
            T.EconomicsConsent(1, address(royalties), ROYALTY_CLASS, 1, 1, fact.assignmentHash);
        T.FixedEconomicsCandidate memory candidate =
            T.FixedEconomicsCandidate(profile, 0, bps, false);
        T.Binding memory binding_ = artistCoordinator.reads().acceptedBinding(1);
        IStreamArtistEconomicsEvidence evidence =
            IStreamArtistEconomicsEvidence(artistSuite.owners[6]);
        require(
            evidence.economicsRecordForBinding(
                p, binding_.artistId, binding_.generation, binding_.bindingHash
            ) == 0,
            "candidate not approved before original Safe action"
        );
        bytes32 beforeConfig = keccak256(abi.encode(royalties.collectionRoyalty(1)));
        T.Authorization memory a = _artistAuthorization(false);
        a.signature = _artistProof(artists.economicsConsentDigest(p, a));
        uint256 safeNonce = artistSafe.nonce();
        require(
            executeSafe(
                artistSafe,
                signingKeys,
                address(artists),
                0,
                abi.encodeCall(
                    IStreamArtistEconomicsAuthority.recordProspectiveEconomicsConsent,
                    (p, candidate, a)
                ),
                0
            ),
            "actual Artist Safe executes original signed op15"
        );
        bytes32 record = evidence.economicsRecordForBinding(
            p, binding_.artistId, binding_.generation, binding_.bindingHash
        );
        IStreamArtistEconomicsEvidence.Association memory association =
            evidence.economicsRecordAssociation(record);
        require(
            record != 0 && association.artistId == binding_.artistId
                && association.bindingGeneration == binding_.generation
                && association.bindingHash == binding_.bindingHash
                && association.payloadHash == keccak256(abi.encode(p))
                && artistSafe.nonce() == safeNonce + 1
                && keccak256(abi.encode(royalties.collectionRoyalty(1))) == beforeConfig,
            "exact current binding consent retained without installing candidate"
        );
    }

    function installSnapshotSource(uint16 bps) external {
        require(msg.sender == address(this), "test only");
        uint64 revision = royalties.collectionRoyalty(1).revision;
        _governSnapshotCall(
            address(royalties),
            abi.encodeCall(royalties.configureCollectionRoyalty, (uint256(1), profile, bps))
        );
        IStreamRoyaltySnapshot.Source memory s = royalties.currentRoyaltySnapshotSource(1);
        (T.AssignmentFact memory raw, IStreamRoyaltyResolver.RoyaltyConfig memory config) =
            royalties.royaltyEconomicsFacts(1, 1, 1);
        require(
            s.config.profileId == profile && s.config.wallet == wallet && s.config.royaltyBps == bps
                && s.config.configured && !s.config.frozen && s.config.revision == revision + 1
                && s.sourceAssignmentHash == raw.assignmentHash
                && keccak256(abi.encode(config)) == keccak256(abi.encode(s.config))
                && s.sourceRoyaltyPolicyHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ROYALTY_POLICY_V1"),
                            block.chainid,
                            address(royalties),
                            uint256(1),
                            uint256(0),
                            profile,
                            wallet,
                            bps,
                            raw.assignmentHash
                        )
                    ),
            "separate governed setter preserves canonical source policy and exact config"
        );
        if (originalSource.collectionId == 0) originalSource = s;
    }

    function configureSnapshotPhase() external {
        require(msg.sender == address(this), "test only");
        IStreamMintRoyaltyPolicy.Policy memory p = IStreamMintRoyaltyPolicy.Policy(
            true,
            APPLICATION,
            address(royalties),
            address(royalties).codehash,
            originalSource.electionHash,
            originalSource.modeAssignmentHash,
            originalSource.sourceRoyaltyPolicyHash
        );
        bytes32 wrapper = manager.phaseRoyaltyConfigHash(1, SNAPSHOT_PHASE, p);
        _governSnapshotCall(
            address(manager),
            abi.encodeCall(manager.registerPhaseRoyaltyPolicy, (uint256(1), SNAPSHOT_PHASE, p))
        );
        require(
            keccak256(abi.encode(manager.phaseRoyaltyPolicy(1, SNAPSHOT_PHASE)))
                == keccak256(abi.encode(p)),
            "full retained royalty phase policy"
        );
        this.configureSnapshotMintPhase(wrapper);
    }

    function configureSnapshotMintPhase(bytes32 wrapper) external {
        require(msg.sender == address(this), "test only");
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = keccak256("snapshot supply");
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            10,
            1,
            keccak256("snapshot counter")
        );
        IStreamMintManager.MintGateConfig memory gate;
        IStreamMintManager.MintPhaseConfig memory config =
            IStreamMintManager.MintPhaseConfig(false, 0, 0, 1, wrapper, keccak256("metadata"));
        address[] memory allowed = new address[](0);
        _recordFixturePolicy(
            SNAPSHOT_PHASE,
            manager.previewPhasePolicyHash(1, SNAPSHOT_PHASE, config, gate, ids, counters, allowed)
        );
        _governSnapshotCall(
            address(manager),
            abi.encodeCall(
                manager.configurePhase, (uint256(1), SNAPSHOT_PHASE, config, gate, ids, counters)
            )
        );
        this.allowSnapshotHouse(config, gate, ids, counters);
    }

    function allowSnapshotHouse(
        IStreamMintManager.MintPhaseConfig memory config,
        IStreamMintManager.MintGateConfig memory gate,
        bytes32[] memory ids,
        IStreamMintManager.MintCounterConfig[] memory counters
    ) external {
        require(msg.sender == address(this), "test only");
        address[] memory allowed = new address[](1);
        allowed[0] = address(house);
        _recordFixturePolicy(
            SNAPSHOT_PHASE,
            manager.previewPhasePolicyHash(1, SNAPSHOT_PHASE, config, gate, ids, counters, allowed)
        );
        _governSnapshotCall(
            address(manager),
            abi.encodeCall(
                manager.setPhaseExecutor, (uint256(1), SNAPSHOT_PHASE, address(house), true)
            )
        );
        bytes32 policy = manager.phasePolicyHash(1, SNAPSHOT_PHASE);
        require(
            ledger.registeredPhasePolicyHash(address(manager), 1, SNAPSHOT_PHASE) == policy,
            "actual Manager and Ledger policy parity"
        );
        artists.requireMintConsent(1, SNAPSHOT_PHASE, policy);
    }

    function _governSnapshotCall(address target, bytes memory data) private {
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        bytes[] memory datas = new bytes[](1);
        datas[0] = data;
        calls[0] = StreamCurrentStackPlan.call(
            target, data, keccak256(abi.encode(target, data)), 0, keccak256(data)
        );
        (bytes32 id, uint64 ready) = _scheduleBatchAsGovernor(1, calls, datas);
        GovernanceAction memory scheduled = executor.governanceAction(id);
        require(
            scheduled.proposer == address(governorSafe)
                && scheduled.status == GovernanceActionStatus.SCHEDULED,
            "actual threshold Safe scheduled governance"
        );
        vm.warp(ready);
        executor.executeGovernanceBatch(id, calls, datas);
        require(
            executor.governanceAction(id).status == GovernanceActionStatus.EXECUTED,
            "delayed action executed"
        );
    }

    function createSnapshotAuction() external returns (bytes32) {
        require(msg.sender == address(this), "test only");
        uint64 observed = uint64(block.timestamp);
        IStreamNativeEnglishAuction.Configuration memory c;
        c.collectionId = 1;
        c.phaseId = SNAPSHOT_PHASE;
        c.mintAtSettlement = true;
        c.artworkCommitment = keccak256(TOKEN_DATA);
        c.mintCommitment = keccak256("actual snapshot mint");
        c.poster = address(this);
        c.reservePrice = PRICE;
        c.minIncrementBps = 500;
        c.clock = StreamEnglishAuctionClock.Configuration(
            observed, observed + 3600, 0, 600, 600, 3600, false, false
        );
        c.expectedPrimaryPolicyHash = _nativePrimaryPolicyHash();
        c.primaryPolicyMode = 1;
        c.settlementWindow = 7 days;
        c.mintPolicyHash = manager.phasePolicyHash(1, SNAPSHOT_PHASE);
        IStreamNativeEnglishAuction.CreationAuthorization memory a =
            IStreamNativeEnglishAuction.CreationAuthorization(
                house.auctionConfigurationHash(c),
                address(artistSafe),
                keccak256("actual snapshot auction authorization"),
                observed + 1 days
            );
        bytes32 digest = house.creationAuthorizationDigest(a);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        return
            house.registerAuction(c, TOKEN_DATA, a, abi.encodePacked(r, s, v), _artistProof(digest));
    }

    function _bidAndSettle(bytes32 id) private {
        require(
            executeSafe(
                payerSafe,
                signingKeys,
                address(house),
                PRICE + 100,
                abi.encodeCall(house.bid, (id, address(0))),
                0
            ),
            "actual payer Safe funds bid and reveal fee"
        );
        IStreamNativeEnglishAuction.WinningBid memory bid = house.auction(id).winner;
        require(
            bid.payer == address(payerSafe) && bid.executor == address(payerSafe)
                && bid.deliverTo == address(payerSafe),
            "original payer executor and delivery identity"
        );
        (uint64 end,,,) = house.auctionDeadlines(id);
        vm.warp(end);
        vm.recordLogs();
        require(
            executeSafe(
                payerSafe, signingKeys, address(house), 0, abi.encodeCall(house.settle, (id)), 0
            ),
            "actual Safe executes paid prepared snapshot mint"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        IStreamRoyaltySnapshot.Snapshot memory s =
            royalties.royaltySnapshot(house.auction(id).tokenId);
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(royalties) || logs[i].topics.length == 0
                    || logs[i].topics[0]
                        != keccak256(
                            "TokenRoyaltySnapshotted(uint16,bytes32,uint256,bytes32,uint256,bytes32,bytes32)"
                        )
            ) continue;
            ++count;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == s.operationId
                    && uint256(logs[i].topics[2]) == s.tokenId
                    && logs[i].topics[3] == s.operationRoot
                    && keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1), uint256(1), ROYALTY_CLASS, s.tokenRoyaltyPolicyHash
                            )
                        ),
                "exact indexed and nonindexed snapshot event"
            );
        }
        require(count == 1, "one original token snapshot event");
    }

    function _assertSnapshot(bytes32 id)
        private
        view
        returns (IStreamRoyaltySnapshot.Snapshot memory s)
    {
        IStreamNativeEnglishAuction.Auction memory a = house.auction(id);
        s = royalties.royaltySnapshot(a.tokenId);
        IStreamRoyaltyResolver.RoyaltyConfig memory c = royalties.tokenRoyalty(a.tokenId);
        require(
            a.status == 3 && a.tokenId == 1 && core.ownerOf(1) == address(payerSafe)
                && core.totalSupply() == 1 && core.collectionNextSerial(1) == 2
                && core.pendingPreparedMintTokenId() == 0 && manager.nextOperationNonce() == 1,
            "actual Core completes exactly one prepared token to original Safe"
        );
        require(
            s.exists && s.collectionId == 1 && s.tokenId == a.tokenId
                && s.manager == address(manager) && s.electionHash == originalSource.electionHash
                && s.modeAssignmentHash == originalSource.modeAssignmentHash
                && s.sourceAssignmentHash == originalSource.sourceAssignmentHash
                && s.sourceRoyaltyPolicyHash == originalSource.sourceRoyaltyPolicyHash
                && ledger.isManagerOperationRootUsed(address(manager), s.operationRoot)
                && c.configured && c.frozen && c.revision == 1 && c.profileId == profile
                && c.wallet == wallet && c.royaltyBps == ORIGINAL_BPS,
            "full immutable source authority and frozen token config"
        );
        (T.AssignmentFact memory fact,, bytes32 policy) =
            royalties.resolveRoyaltyAssignment(1, a.tokenId);
        require(
            fact.scope == 2 && fact.scopeId == a.tokenId
                && fact.assignmentHash == s.tokenAssignmentHash
                && policy == s.tokenRoyaltyPolicyHash
                && s.tokenConfigHash == keccak256(abi.encode(c)),
            "actual canonical token assignment and policy hash"
        );
        require(
            recorder.settlementConsumed(a.settlementKey)
                && recorder.preparedNativeFactsHash(a.settlementKey) != 0
                && recorder.totalOfficialSettled(address(0)) == PRICE
                && recorder.settlementResult(a.settlementKey).amount == PRICE
                && recorder.settlementResult(a.settlementKey).profileId == profile
                && recorder.settlementResult(a.settlementKey).wallet == wallet
                && wallet.balance == PRICE && revenueEscrow.totalOwed(address(0)) == 0
                && entropy.revealFeeEscrow(1) == 100 && house.totalBuyerLiabilities() == 0,
            "original official PROFILE payment and separate reveal fee complete"
        );
    }

    function _withdrawPrimaryProceeds() private {
        uint256 prior = address(artistSafe).balance;
        require(
            executeSafe(
                artistSafe,
                signingKeys,
                wallet,
                0,
                abi.encodeCall(
                    IStreamSplitWallet.release,
                    (address(0), address(artistSafe), payable(address(artistSafe)))
                ),
                0
            ),
            "actual Artist Safe withdraws original primary proceeds"
        );
        IStreamSplitWallet(wallet).release(address(0), PROTOCOL, payable(PROTOCOL));
        require(
            address(artistSafe).balance == prior + PRICE * 9 / 10 && PROTOCOL.balance == PRICE / 10
                && wallet.balance == 0,
            "actual immutable primary split pays exact recipients"
        );
    }

    function _blockedBatch(bytes32 policy)
        private
        view
        returns (IStreamMintManager.MintBatch memory b)
    {
        b.collectionId = 1;
        b.phaseId = SNAPSHOT_PHASE;
        b.payer = address(payerSafe);
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = address(payerSafe);
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = address(payerSafe);
        b.tokenData = new bytes[](1);
        b.tokenData[0] = TOKEN_DATA;
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = keccak256("stale snapshot attempt");
        b.expectedPolicyHash = policy;
        b.authorizationId = keccak256("unused stale snapshot authorization");
    }
}
