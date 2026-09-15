// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentSafeGovernanceFixture.sol";
import "./ArtistArtifactCreate.sol";
import {
    StreamDynamicPrimaryBeneficiaries as DB
} from "../../smart-contracts/domains/revenue/StreamDynamicPrimaryBeneficiaries.sol";
import {
    StreamArtistCollaboratorTypes as C
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";
import {
    StreamNativeCommerceDeployment,
    StreamNativeEnglishAuction,
    StreamPrimarySaleSettlement,
    IStreamNativeEnglishAuction,
    StreamEnglishAuctionClock,
    StreamSaleTemplate,
    StreamPreparedNativeRightsProjection,
    StreamPreparedNativeRightsTypes,
    StreamPrimarySettlementTypes,
    IStreamPreparedNativeMint
} from "../../script/current/StreamNativeCommerceDeployment.sol";
import {
    StreamPrivateSaleAdapter,
    IStreamPrivateSaleAdapter,
    StreamPrivateSaleTypes
} from "../../smart-contracts/domains/mint/StreamPrivateSaleAdapter.sol";
import {
    IStreamArtistTemplateEconomicsAuthority
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistTemplateEconomicsAuthority.sol";
import {
    IStreamArtistEconomicsEvidence
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistEconomicsEvidence.sol";
import {
    IStreamArtistCollaboratorLifecycle
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistCollaboratorLifecycle.sol";
import {
    IStreamDynamicPrimaryTemplates
} from "../../smart-contracts/interfaces/stream/revenue/IStreamDynamicPrimaryTemplates.sol";
import {
    IStreamRoyaltySnapshot
} from "../../smart-contracts/interfaces/stream/revenue/IStreamRoyaltySnapshot.sol";
import {
    IStreamMintRoyaltyPolicy
} from "../../smart-contracts/interfaces/stream/mint/IStreamMintRoyaltyPolicy.sol";

/// @dev Real current graph and real Safe/Artist identities. Only the external entropy service is a double.
abstract contract CurrentDynamicRoyaltyCommerceFixture is
    StreamCurrentSafeGovernanceFixture,
    ArtistArtifactCreate
{
    bytes32 internal constant ROYALTY_CLASS = keccak256("ROYALTY_ERC2981");
    bytes32 internal constant JOINED_PHASE = keccak256("actual dynamic royalty commerce phase");
    bytes32 internal constant COLLAB_LABEL = keccak256("composer-share");
    bytes32 internal constant PRIVATE_SIGNER =
        keccak256("actual current secondary signer evidence");
    uint96 internal constant JOINED_PRICE = 1_000_000;
    uint96 internal constant RESALE_PRICE = 2_000_000;
    OfficialSafe internal joinedArtist;
    OfficialSafe internal joinedCollaborator;
    OfficialSafe internal joinedCollector;
    OfficialSafe internal joinedBuyer;
    uint256[] internal joinedKeys;
    bytes32 internal joinedCollaboratorId;
    StreamNativeCommerceDeployment.Products internal joinedProducts;
    StreamNativeEnglishAuction internal joinedHouse;
    StreamPrimarySaleSettlement internal joinedRecorder;
    StreamPrivateSaleAdapter internal joinedPrivate;
    IStreamRoyaltySnapshot.Source internal joinedSource;
    uint256 internal joinedCreationNonce;

    receive() external payable { }

    function _deployJoinedCommerce() internal {
        joinedKeys.push(0xD1901);
        joinedKeys.push(0xD1902);
        SafeComponents memory safe = deploySafeComponents("1.4.1");
        address[] memory owners = safeOwnerAddresses(joinedKeys);
        joinedArtist = createOfficialSafe(safe, owners, 2, 1401);
        joinedCollaborator = createOfficialSafe(safe, owners, 2, 1402);
        joinedCollector = createOfficialSafe(safe, owners, 2, 1403);
        joinedBuyer = createOfficialSafe(safe, owners, 2, 1404);
        OfficialSafe governor = createOfficialSafe(safe, owners, 2, 1405);
        _deployCurrentStack(address(joinedArtist), vm.addr(PLATFORM_KEY));
        _installGovernorSafe(governor, joinedKeys);
        vm.deal(address(joinedCollector), 10 ether);
        vm.deal(address(joinedBuyer), 10 ether);
        require(
            core.lastAllocatedTokenId() == 0 && core.collectionMintedEver(1) == 0,
            "no fabricated prior mint"
        );
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return
            safeThresholdSignature(joinedKeys, safeMessageDigest(joinedArtist, abi.encode(digest)));
    }

    function _joinedProof(OfficialSafe safe, bytes32 digest) internal returns (bytes memory) {
        return safeThresholdSignature(joinedKeys, safeMessageDigest(safe, abi.encode(digest)));
    }

    function _platformProof(bytes32 digest) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        return abi.encodePacked(r, s, v);
    }

    function _joinedSafe(OfficialSafe safe, address target, uint256 value, bytes memory data)
        internal
    {
        require(executeSafe(safe, joinedKeys, target, value, data, 0), "actual threshold Safe CALL");
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
        d.parameters[0] =
            IStreamGasParameterHost.GasParameterConfig(
            "SALE_ERC1271_GAS_LIMIT", 400_000, 350_000, 2
        );
        d.parameters[1] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ARTIST_AUTHORITY_GAS_LIMIT", 600_000, 50_000, 2
        );
        d.parameters[2] =
            IStreamGasParameterHost.GasParameterConfig(
            "REVEAL_ATTEMPT_GAS_LIMIT", 200_000, 50_000, 2
        );
        d.parameters[3] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_NFT_DELIVERY_GAS_LIMIT", 300_000, 100_000, 2
        );
        joinedRecorder = StreamPrimarySaleSettlement(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol:StreamPrimarySaleSettlement",
                    abi.encode(primaryResolver, address(registry), revenueEscrow)
                ))
        );
        d.recorder = joinedRecorder;
        joinedHouse = StreamNativeEnglishAuction(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/auctions/StreamNativeEnglishAuction.sol:StreamNativeEnglishAuction",
                    abi.encode(d)
                ))
        );
        bytes32 modules = keccak256("joined actual primary and royalty commerce");
        joinedProducts = StreamNativeCommerceDeployment.Products(
            block.chainid,
            joinedRecorder,
            joinedHouse,
            address(joinedRecorder).codehash,
            address(joinedHouse).codehash,
            DEPLOYMENT_HASH,
            modules,
            modules
        );
        StreamNativeCommerceDeployment.validate(joinedProducts);
        IStreamGasParameterHost.GasParameterConfig[3] memory caps;
        caps[0] =
            IStreamGasParameterHost.GasParameterConfig(
            "SALE_ERC1271_GAS_LIMIT", 400_000, 350_000, 2
        );
        caps[1] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_NFT_DELIVERY_GAS_LIMIT", 300_000, 150_000, 2
        );
        caps[2] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ROYALTY_DELIVERY_GAS_LIMIT", 150_000, 30_000, 2
        );
        StreamPrivateSaleAdapter.DeploymentConfig memory p =
            StreamPrivateSaleAdapter.DeploymentConfig(
                address(core),
                address(registry),
                vm.addr(PLATFORM_KEY),
                address(executor),
                address(executor),
                address(roles),
                caps,
                address(0),
                0,
                bytes32(0),
                IStreamGasParameterHost.GasParameterConfig("", 0, 0, 0)
            );
        joinedPrivate = StreamPrivateSaleAdapter(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/mint/StreamPrivateSaleAdapter.sol:StreamPrivateSaleAdapter",
                    abi.encode(p)
                ))
        );
        _assertDeployableProductionInstance(address(joinedPrivate));
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](7);
        rows[0] = _joinedPolicy(
            address(manager), IStreamPreparedNativeMint.bindPreparedNativeRecorder.selector
        );
        rows[1] =
            _joinedPolicy(address(joinedHouse), IStreamGasParameterHost.raiseGasParameter.selector);
        rows[2] = _joinedPolicy(
            address(royalties), IStreamRoyaltySnapshot.electCollectionRoyaltyMode.selector
        );
        rows[3] = _joinedPolicy(
            address(manager), IStreamMintRoyaltyPolicy.registerPhaseRoyaltyPolicy.selector
        );
        rows[4] = _joinedPolicy(address(royalties), royalties.clearCollectionRoyalty.selector);
        rows[5] =
            _joinedPolicy(address(joinedPrivate), joinedPrivate.configureCollectionSigner.selector);
        rows[6] = _joinedPolicy(address(joinedPrivate), joinedPrivate.registerSale.selector);
    }

    function _joinedPolicy(address target, bytes4 selector)
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
        GenesisBatch memory batch = StreamNativeCommerceDeployment.admission(joinedProducts);
        _joinedBatch(batch.calls, batch.callDatas);
        (address target, bytes memory data) =
            StreamNativeCommerceDeployment.managerBinding(joinedProducts);
        (bool ok,) = target.call(data);
        require(ok, "original temporary owner binds actual admitted recorder");
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](1);
        records[0] = StreamModuleRegistration(
            address(joinedPrivate),
            joinedPrivate.streamModuleType(),
            joinedPrivate.streamModuleVersion(),
            joinedPrivate.streamModuleInterfaceId(),
            500_000,
            address(joinedPrivate).codehash,
            DEPLOYMENT_HASH,
            keccak256("actual native secondary custody"),
            "urn:stream:joined:secondary"
        );
        (GovernanceCall[] memory calls, bytes[] memory datas) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        _joinedBatch(calls, datas);
        this.joinedGovern(
            address(joinedPrivate),
            abi.encodeCall(
                joinedPrivate.configureCollectionSigner, (uint256(1), PRIVATE_SIGNER, true)
            )
        );
    }

    function joinedGovern(address target, bytes calldata data) external {
        require(msg.sender == address(this), "fixture self-call");
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        bytes[] memory datas = new bytes[](1);
        datas[0] = data;
        calls[0] = StreamCurrentStackPlan.call(
            target, data, keccak256(abi.encode(target, data)), 0, keccak256(data)
        );
        _joinedBatch(calls, datas);
    }

    function _joinedBatch(GovernanceCall[] memory calls, bytes[] memory datas) internal {
        executor.publishGovernanceCallData(datas);
        uint64 ready = uint64(block.timestamp + executor.minimumDelay(1));
        bytes32 action;
        if (address(governorSafe) != address(0)) {
            (action, ready) = _scheduleBatchAsGovernor(1, calls, datas);
        } else {
            (bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
                calls, StreamGovernanceBootstrap.governanceCallsHash(calls)
            );
            action = abi.decode(
                governanceRoot.execute(
                    address(executor),
                    0,
                    abi.encodeCall(
                        executor.scheduleGovernanceBatch,
                        (
                            uint8(1),
                            calls,
                            scope,
                            oldHash,
                            newHash,
                            ready,
                            uint64(ready + 7 days),
                            GOVERNANCE_REASON,
                            "urn:stream:joined:setup",
                            DEPLOYMENT_HASH
                        )
                    )
                ),
                (bytes32)
            );
        }
        vm.warp(ready);
        executor.executeGovernanceBatch(action, calls, datas);
        require(
            executor.governanceAction(action).status == GovernanceActionStatus.EXECUTED,
            "actual delayed governance"
        );
    }

    function _onboardFixtureArtist(address artist_) internal override {
        // The shared fixture's original no-collaborator body is unchanged; only this derived scenario differs.
        _joinedCollaboratorIdentity();
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](3);
        entries[0] = IStreamSplitWallet.SplitEntry(artist_, 700_000, keccak256("artist"));
        entries[1] =
            IStreamSplitWallet.SplitEntry(address(joinedCollaborator), 200_000, COLLAB_LABEL);
        entries[2] = IStreamSplitWallet.SplitEntry(PROTOCOL, 100_000, keccak256("protocol"));
        (profile, wallet) = factory.createProfile(
            entries, keccak256("actual collaborator baseline primary and royalty")
        );
        require(wallet.code.length != 0, "royalty source uses an actual deployed verified wallet");
        this.joinedGovern(
            address(primaryResolver),
            abi.encodeCall(
                primaryResolver.setPrimaryProfileAssignment,
                (PRIMARY_REVENUE_CLASS, uint8(1), uint256(1), profile, bytes32(0))
            )
        );
        this.joinedGovern(
            address(royalties),
            abi.encodeCall(royalties.configureDefaultRoyalty, (profile, uint16(600)))
        );
        this.joinedGovern(
            address(royalties), abi.encodeCall(royalties.clearCollectionRoyalty, (uint256(1)))
        );
        bytes memory document = bytes("joined current artist identity");
        T.BindingProposal memory p;
        p.artistAddress = artist_;
        p.identityRecordHash = keccak256(document);
        p.identityRecordURI = "urn:stream:joined:artist";
        p.consentMode = 1;
        p.saleConsentScope = _fixtureSaleConsentScope();
        p.collaborators = new T.CollaboratorRecord[](1);
        p.collaborators[0] =
            T.CollaboratorRecord(address(joinedCollaborator), bytes32(0), COLLAB_LABEL);
        p.capabilityPolicyOverrides = new T.CapabilityPolicyOverride[](0);
        (fixtureArtistId,) = artists.proposeArtistBinding(1, p, document, "Joined Artist");
        T.Authorization memory a = _artistAuthorization(false);
        _joinedSafe(
            joinedArtist,
            address(artists),
            0,
            abi.encodeCall(artists.acceptArtistBinding, (uint256(1), a))
        );
        T.Binding memory b = IStreamArtistBindingOwner(artistSuite.owners[0]).binding(1);
        C.BindingAcceptance memory row = C.BindingAcceptance(
            1, b.generation, b.bindingHash, address(joinedCollaborator), bytes32(0), COLLAB_LABEL
        );
        a = T.Authorization(
            IStreamArtistIdentityOwner(artistSuite.owners[2])
            .identity(joinedCollaboratorId)
            .nonceHint,
            uint64(block.timestamp + 1 days),
            ""
        );
        _joinedSafe(
            joinedCollaborator,
            address(artists),
            0,
            abi.encodeCall(IStreamArtistCollaboratorLifecycle.acceptCollaborator, (row, a))
        );
        _joinedPayout(joinedCollaborator, joinedCollaboratorId, address(joinedCollaborator));
        T.PayoutDesignation memory payout = T.PayoutDesignation(
            fixtureArtistId, artist_, bytes32(0)
        );
        a = _artistAuthorization(true);
        _joinedSafe(
            joinedArtist,
            address(artists),
            0,
            abi.encodeCall(artists.recordPayoutDesignation, (payout, a))
        );
        (T.AssignmentFact memory primary, T.AssignmentFact memory royalty) =
            artistCoordinator.reads().currentAssignments(1);
        _joinedCurrentConsent(primary);
        _joinedCurrentConsent(royalty);
        (, bytes32 content) = router.currentArtistContentState(1);
        T.Ratification memory ratification = T.Ratification(1, address(router), content);
        a = _artistAuthorization(false);
        _joinedSafe(
            joinedArtist,
            address(artists),
            0,
            abi.encodeCall(artists.recordContentRatification, (ratification, a))
        );
        b = IStreamArtistBindingOwner(artistSuite.owners[0]).binding(1);
        bytes32 facts = StreamArtistHashes.deploymentFacts(
            StreamArtistHashes.Environment(
                block.chainid, address(artists), artistSuite.core, artistSuite.mintManager
            ),
            1,
            b
        );
        _joinedAttestation(
            9,
            bytes32(uint256(uint160(address(core)))),
            facts,
            keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1")
        );
        _joinedAttestation(
            10,
            fixtureArtistId,
            b.identityRecordHash,
            keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")
        );
        require(
            artists.collaboratorAt(1, b.generation, 0).accepted
                && artists.acceptedArtist(1) == artist_,
            "real complete collaborative binding"
        );
    }

    function _joinedCollaboratorIdentity() private {
        bytes memory doc = bytes("joined collaborator actual identity");
        C.IdentityProposal memory p = C.IdentityProposal(
            address(joinedCollaborator),
            keccak256(doc),
            "urn:stream:joined:collaborator",
            keccak256("actual collaborator proposal"),
            "urn:stream:joined:reason"
        );
        artists.proposeCollaboratorIdentity(p);
        T.Authorization memory a = T.Authorization(0, uint64(block.timestamp + 1 days), "");
        _joinedSafe(
            joinedCollaborator,
            address(artists),
            0,
            abi.encodeCall(
                IStreamArtistCollaboratorLifecycle.acceptCollaboratorIdentity,
                (p.account, p.identityRecordHash, a, doc, "Joined Collaborator")
            )
        );
        joinedCollaboratorId =
            IStreamArtistIdentityOwner(artistSuite.owners[2]).activeIdentity(p.account);
        require(joinedCollaboratorId != 0, "actual accepted collaborator identity");
    }

    function _joinedPayout(OfficialSafe safe, bytes32 artistId, address account) internal {
        (, bytes32 previous) = artists.artistPayoutAccount(artistId);
        T.PayoutDesignation memory p = T.PayoutDesignation(artistId, account, previous);
        T.Authorization memory a = T.Authorization(
            IStreamArtistIdentityOwner(artistSuite.owners[2]).identity(artistId).nonceHint,
            uint64(block.timestamp),
            ""
        );
        _joinedSafe(
            safe, address(artists), 0, abi.encodeCall(artists.recordPayoutDesignation, (p, a))
        );
    }

    function _joinedCurrentConsent(T.AssignmentFact memory fact) internal {
        T.EconomicsConsent memory p = T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
        T.Authorization memory a = _artistAuthorization(false);
        _joinedSafe(
            joinedArtist,
            address(artists),
            0,
            abi.encodeCall(artists.recordEconomicsConsent, (p, a))
        );
        _joinedConsentEvidence(p);
    }

    function _joinedConsentEvidence(T.EconomicsConsent memory p)
        internal
        view
        returns (bytes32 record)
    {
        T.Binding memory b = artistCoordinator.reads().acceptedBinding(1);
        IStreamArtistEconomicsEvidence evidence =
            IStreamArtistEconomicsEvidence(artistSuite.owners[6]);
        record = evidence.economicsRecordForBinding(p, b.artistId, b.generation, b.bindingHash);
        IStreamArtistEconomicsEvidence.Association memory x =
            evidence.economicsRecordAssociation(record);
        require(
            record != 0 && x.originalRecord == record && x.artistId == b.artistId
                && x.bindingGeneration == b.generation && x.bindingHash == b.bindingHash
                && x.payloadHash == keccak256(abi.encode(p)),
            "full actual binding-specific op15 association"
        );
    }

    function _joinedAttestation(uint8 kind, bytes32 subject, bytes32 state, bytes32 schema)
        private
    {
        bytes memory statement = abi.encode(kind, subject, state, schema);
        T.Attestation memory p = T.Attestation(
            1, kind, subject, state, schema, keccak256(statement), "urn:stream:joined:statement"
        );
        T.Authorization memory a = _artistAuthorization(true);
        _joinedSafe(
            joinedArtist,
            address(artists),
            0,
            abi.encodeCall(artists.recordArtistAttestation, (p, a, statement))
        );
    }

    /// @param sourceKind 0 positive inherited default; 1 explicit collection zero; 2 inherited default zero.
    function joinedSnapshotSetup(uint8 sourceKind) external {
        require(msg.sender == address(this) && sourceKind <= 2, "fixture source kind");
        this.joinedGovern(
            address(royalties),
            abi.encodeCall(royalties.electCollectionRoyaltyMode, (uint256(1), uint8(2)))
        );
        if (sourceKind == 1) {
            T.AssignmentFact memory f =
                royalties.previewArtistSnapshotRoyaltyAssignment(1, 0, 0, false);
            T.EconomicsConsent memory p =
                T.EconomicsConsent(1, address(royalties), ROYALTY_CLASS, 1, 1, f.assignmentHash);
            T.Authorization memory a = _artistAuthorization(false);
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
                address(royalties),
                abi.encodeCall(
                    royalties.configureCollectionRoyalty, (uint256(1), bytes32(0), uint16(0))
                )
            );
        } else {
            if (sourceKind == 2) {
                this.joinedGovern(
                    address(royalties),
                    abi.encodeCall(royalties.configureDefaultRoyalty, (bytes32(0), uint16(0)))
                );
            }
            require(
                !royalties.collectionRoyalty(1).configured,
                "default is selected by missing collection key"
            );
            _joinedCurrentConsent(royalties.currentArtistSnapshotRoyaltyAssignment(1));
        }
        joinedSource = royalties.currentRoyaltySnapshotSource(1);
        (T.AssignmentFact memory raw,, bytes32 policy) = royalties.resolveRoyaltyAssignment(1, 0);
        require(
            raw.scope == (sourceKind == 1 ? 1 : 0) && raw.scopeId == (sourceKind == 1 ? 1 : 0)
                && raw.assignmentHash == joinedSource.sourceAssignmentHash
                && policy == joinedSource.sourceRoyaltyPolicyHash,
            "original scope0/1 source facts stay distinct from approval wrapper"
        );
        require(
            joinedSource.modeAssignmentHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SNAPSHOT_ROYALTY_ASSIGNMENT_V1"),
                        block.chainid,
                        address(royalties),
                        address(core),
                        uint256(1),
                        joinedSource.electionHash,
                        raw.assignmentHash
                    )
                ),
            "original collection election wrapper"
        );
        require(
            joinedSource.config.configured
                && (sourceKind == 0
                        ? joinedSource.config.royaltyBps == 600
                        : joinedSource.config.royaltyBps == 0 && joinedSource.config.profileId == 0
                        && joinedSource.config.wallet == address(0)),
            "explicit configured terms"
        );
    }

    function joinedInstallPhase() external {
        require(msg.sender == address(this), "fixture self-call");
        IStreamMintRoyaltyPolicy.Policy memory p = IStreamMintRoyaltyPolicy.Policy(
            true,
            keccak256("joined application"),
            address(royalties),
            address(royalties).codehash,
            joinedSource.electionHash,
            joinedSource.modeAssignmentHash,
            joinedSource.sourceRoyaltyPolicyHash
        );
        bytes32 wrapper = manager.phaseRoyaltyConfigHash(1, JOINED_PHASE, p);
        this.joinedGovern(
            address(manager),
            abi.encodeCall(manager.registerPhaseRoyaltyPolicy, (uint256(1), JOINED_PHASE, p))
        );
        this.joinedMintPhase(wrapper);
    }

    function joinedMintPhase(bytes32 wrapper) external {
        require(msg.sender == address(this), "fixture self-call");
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = keccak256("joined actual supply");
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            10,
            1,
            keccak256("joined counter")
        );
        IStreamMintManager.MintGateConfig memory gate;
        IStreamMintManager.MintPhaseConfig memory config =
            IStreamMintManager.MintPhaseConfig(
            false, 0, 0, 1, wrapper, keccak256("joined metadata")
        );
        address[] memory allowed = new address[](0);
        _recordFixturePolicy(
            JOINED_PHASE,
            manager.previewPhasePolicyHash(1, JOINED_PHASE, config, gate, ids, counters, allowed)
        );
        this.joinedGovern(
            address(manager),
            abi.encodeCall(
                manager.configurePhase, (uint256(1), JOINED_PHASE, config, gate, ids, counters)
            )
        );
        this.joinedPhaseExecutor(config, gate, ids, counters);
    }

    function joinedPhaseExecutor(
        IStreamMintManager.MintPhaseConfig calldata config,
        IStreamMintManager.MintGateConfig calldata gate,
        bytes32[] calldata ids,
        IStreamMintManager.MintCounterConfig[] calldata counters
    ) external {
        require(msg.sender == address(this), "fixture self-call");
        address[] memory allowed = new address[](1);
        allowed[0] = address(joinedHouse);
        _recordFixturePolicy(
            JOINED_PHASE,
            manager.previewPhasePolicyHash(1, JOINED_PHASE, config, gate, ids, counters, allowed)
        );
        this.joinedGovern(
            address(manager),
            abi.encodeCall(
                manager.setPhaseExecutor, (uint256(1), JOINED_PHASE, address(joinedHouse), true)
            )
        );
        artists.requireMintConsent(1, JOINED_PHASE, manager.phasePolicyHash(1, JOINED_PHASE));
    }

    function joinedCreateTemplate() external returns (bytes32 templateId) {
        require(msg.sender == address(this), "fixture self-call");
        IStreamDynamicPrimaryTemplates.CollaboratorReference[] memory refs =
            new IStreamDynamicPrimaryTemplates.CollaboratorReference[](1);
        refs[0] = IStreamDynamicPrimaryTemplates.CollaboratorReference(
            address(joinedCollaborator), 0, COLLAB_LABEL
        );
        bytes32 source = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_COLLABORATOR_SOURCE_V1"),
                address(joinedCollaborator),
                bytes32(0),
                COLLAB_LABEL
            )
        );
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](4);
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), keccak256("COLLECTION_ARTIST"), 300_000, keccak256("artist")
        );
        entries[1] =
            IStreamRevenueResolver.PrimaryTemplateEntry(address(0), source, 200_000, COLLAB_LABEL);
        entries[2] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), keccak256("SALE_POSTER"), 300_000, keccak256("poster")
        );
        entries[3] =
            IStreamRevenueResolver.PrimaryTemplateEntry(PROTOCOL, 0, 200_000, keccak256("protocol"));
        vm.recordLogs();
        this.joinedGovern(
            address(primaryResolver),
            abi.encodeCall(
                primaryResolver.createDynamicPrimaryTemplate,
                (entries, keccak256("joined symbolic template"), refs)
            )
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 n; n < logs.length; n++) {
            if (
                logs[n].emitter == address(primaryResolver) && logs[n].topics.length == 4
                    && logs[n].topics[0]
                        == keccak256(
                            "PrimaryTemplateCreated(bytes32,bytes32,bytes32,uint16,uint16)"
                        )
            ) {
                require(templateId == 0, "one template event");
                templateId = logs[n].topics[1];
            }
        }
        require(templateId != 0, "governed dynamic template");
    }

    function joinedApproveTemplate(bytes32 templateId) external returns (bytes32 assignment) {
        require(msg.sender == address(this), "fixture self-call");
        T.AssignmentFact memory f =
            primaryResolver.previewArtistDynamicPrimaryTemplateAssignment(1, templateId, 0, false);
        T.EconomicsConsent memory p = T.EconomicsConsent(
            1, address(primaryResolver), PRIMARY_REVENUE_CLASS, 1, 1, f.assignmentHash
        );
        T.Authorization memory a = _artistAuthorization(false);
        a.signature = _artistProof(artists.economicsConsentDigest(p, a));
        _joinedSafe(
            joinedArtist,
            address(artists),
            0,
            abi.encodeCall(
                IStreamArtistTemplateEconomicsAuthority.recordProspectiveTemplateEconomicsConsent,
                (p, templateId, a)
            )
        );
        bytes32 record = _joinedConsentEvidence(p);
        bytes32 evidenceId = keccak256(
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
            StreamArtistArchiveV2(artistSuite.archive).artistEvidenceBytesV2(evidenceId, 1),
            (uint16, bytes32, uint16, address, bytes32, T.Snapshot[7], T.Snapshot[7], bytes)
        );
        require(
            schema == 1 && config == artistCoordinator.configurationHash() && op == 15
                && actor == address(joinedArtist) && saved == record && payload.length != 0,
            "actual Safe op15 retained in original Archive"
        );
        return f.assignmentHash;
    }

    function joinedInstallTemplate(bytes32 templateId) external {
        require(msg.sender == address(this), "fixture self-call");
        this.joinedGovern(
            address(primaryResolver),
            abi.encodeCall(
                primaryResolver.setPrimaryTemplateAssignment,
                (PRIMARY_REVENUE_CLASS, uint8(1), uint256(1), templateId, bytes32(0))
            )
        );
    }

    function _joinedSelection() internal view returns (StreamSaleTemplate.Selection memory) {
        return StreamPreparedNativeRightsProjection.collectionTemplateForPoster(
            primaryResolver, 1, 3, address(this)
        );
    }

    function _joinedPrimaryPolicy(uint256 token, StreamSaleTemplate.Selection memory s)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_POLICY_V1"),
                block.chainid,
                address(primaryResolver),
                PRIMARY_REVENUE_CLASS,
                uint256(1),
                token,
                s.templateId,
                s.profileId,
                s.wallet,
                s.assignmentHash
            )
        );
    }

    function joinedCreateAuction() external returns (bytes32 id) {
        require(msg.sender == address(this), "fixture self-call");
        StreamSaleTemplate.Selection memory s = _joinedSelection();
        IStreamNativeEnglishAuction.Configuration memory c;
        c.collectionId = 1;
        c.phaseId = JOINED_PHASE;
        c.mintAtSettlement = true;
        c.artworkCommitment = keccak256(TOKEN_DATA);
        c.mintCommitment = keccak256("joined actual prepared artwork");
        c.poster = address(this);
        c.reservePrice = JOINED_PRICE;
        c.minIncrementBps = 500;
        c.clock = StreamEnglishAuctionClock.Configuration(
            uint64(block.timestamp), uint64(block.timestamp + 3600), 0, 600, 600, 3600, false, false
        );
        c.expectedPrimaryPolicyHash = _joinedPrimaryPolicy(0, s);
        c.primaryPolicyMode = 1;
        c.settlementWindow = 7 days;
        c.mintPolicyHash = manager.phasePolicyHash(1, JOINED_PHASE);
        StreamPreparedNativeRightsTypes.OriginalPolicy memory original =
            StreamPreparedNativeRightsTypes.OriginalPolicy(3, s.assignmentHash, s.templateId);
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
            "original poster is not the buyer executor"
        );
    }

    function _joinedBid(bytes32 id) internal {
        _joinedSafe(
            joinedCollector,
            address(joinedHouse),
            JOINED_PRICE + 100,
            abi.encodeCall(joinedHouse.bid, (id, address(0)))
        );
        IStreamNativeEnglishAuction.WinningBid memory w = joinedHouse.auction(id).winner;
        require(
            w.payer == address(joinedCollector) && w.executor == address(joinedCollector)
                && w.deliverTo == address(joinedCollector) && w.amount == JOINED_PRICE
                && w.revealFee == 100,
            "actual Safe bid and fee identities"
        );
    }

    function _joinedSettle(bytes32 id) internal returns (uint256 token) {
        (uint64 end,,,) = joinedHouse.auctionDeadlines(id);
        vm.warp(end);
        vm.recordLogs();
        _joinedSafe(
            joinedCollector, address(joinedHouse), 0, abi.encodeCall(joinedHouse.settle, (id))
        );
        _joinedReceipt(id, vm.getRecordedLogs());
        token = joinedHouse.auction(id).tokenId;
        require(
            core.ownerOf(token) == address(joinedCollector),
            "actual first paid delivery to collector Safe"
        );
    }

    function _joinedAssertMint(bytes32 id)
        internal
        returns (IStreamRoyaltySnapshot.Snapshot memory snapshot)
    {
        IStreamNativeEnglishAuction.Auction memory a = joinedHouse.auction(id);
        snapshot = royalties.royaltySnapshot(a.tokenId);
        IStreamRoyaltyResolver.RoyaltyConfig memory c = royalties.tokenRoyalty(a.tokenId);
        require(
            a.status == 3 && a.tokenId == 1 && core.totalSupply() == 1
                && core.collectionNextSerial(1) == 2 && manager.nextOperationNonce() == 1
                && core.pendingPreparedMintTokenId() == 0,
            "one actual prepared mint"
        );
        require(
            snapshot.exists && snapshot.collectionId == 1 && snapshot.tokenId == a.tokenId
                && snapshot.manager == address(manager)
                && snapshot.electionHash == joinedSource.electionHash
                && snapshot.sourceAssignmentHash == joinedSource.sourceAssignmentHash
                && snapshot.sourceRoyaltyPolicyHash == joinedSource.sourceRoyaltyPolicyHash
                && snapshot.modeAssignmentHash == joinedSource.modeAssignmentHash
                && ledger.isManagerOperationRootUsed(address(manager), snapshot.operationRoot)
                && c.configured && c.frozen && c.revision == 1
                && c.profileId == joinedSource.config.profileId
                && c.wallet == joinedSource.config.wallet
                && c.royaltyBps == joinedSource.config.royaltyBps,
            "complete original source copied to frozen actual token"
        );
        (T.AssignmentFact memory f,, bytes32 policy) =
            royalties.resolveRoyaltyAssignment(1, a.tokenId);
        require(
            f.scope == 2 && f.scopeId == a.tokenId
                && f.assignmentHash == snapshot.tokenAssignmentHash
                && policy == snapshot.tokenRoyaltyPolicyHash
                && snapshot.tokenConfigHash == keccak256(abi.encode(c)),
            "actual token policy is scope2"
        );
        StreamSaleTemplate.Selection memory selected = _joinedSelection();
        StreamPrimarySettlementTypes.PrimarySettlementResult memory result =
            joinedRecorder.settlementResult(a.settlementKey);
        require(
            joinedRecorder.settlementConsumed(a.settlementKey) && result.amount == JOINED_PRICE
                && result.profileId == selected.profileId && result.wallet == selected.wallet
                && result.operationIdentityCommitment == snapshot.operationRoot
                && result.currentPolicyHash == manager.phasePolicyHash(1, JOINED_PHASE)
                && result.boundPolicyHash == manager.phasePolicyHash(1, JOINED_PHASE)
                && result.escrowed
                && revenueEscrow.escrowOwed(
                    PRIMARY_REVENUE_CLASS, selected.profileId, selected.wallet, address(0)
                ) == JOINED_PRICE,
            "actual dynamic materialization and mint-phase policy with deferred wallet"
        );
        require(selected.wallet.code.length == 0, "first receipt honestly escrows absent wallet");
        revenueEscrow.flushEscrow(
            PRIMARY_REVENUE_CLASS, selected.profileId, selected.wallet, address(0)
        );
        require(
            selected.wallet.code.length != 0 && selected.wallet.balance == JOINED_PRICE
                && revenueEscrow.totalOwed(address(0)) == 0,
            "actual wallet deployed and funded by escrow"
        );
        _joinedShare(selected.profileId, address(joinedArtist), keccak256("artist"), 300_000);
        (address collaboratorPayout,) = artists.artistPayoutAccount(joinedCollaboratorId);
        _joinedShare(selected.profileId, collaboratorPayout, COLLAB_LABEL, 200_000);
        _joinedShare(selected.profileId, address(this), keccak256("poster"), 300_000);
        _joinedShare(selected.profileId, PROTOCOL, keccak256("protocol"), 200_000);
        require(
            factory.profileEntryCount(selected.profileId) == 4
                && entropy.revealFeeEscrow(a.tokenId) == 100,
            "four exact concrete rows and one reveal fee"
        );
    }

    function _joinedShare(bytes32 p, address account, bytes32 label, uint32 amount) private view {
        uint256 found;
        for (uint256 n; n < factory.profileEntryCount(p); n++) {
            IStreamSplitWallet.SplitEntry memory row;
            (row.account, row.sharePpm, row.labelId) = factory.profileEntry(p, n);
            if (row.account == account && row.labelId == label) {
                require(row.sharePpm == amount, "exact current primary share");
                found++;
            }
        }
        require(found == 1, "one current concrete account and label");
    }

    function joinedConfigureResale(uint256 token) external returns (bytes32 id) {
        require(
            msg.sender == address(this) && core.ownerOf(token) == address(joinedCollector),
            "actual paid collector delivery required"
        );
        IStreamPrivateSaleAdapter.SaleConfig memory c;
        c.saleKind = 5;
        c.collectionId = 1;
        c.tokenId = token;
        c.consignor = address(joinedCollector);
        c.buyer = address(joinedBuyer);
        c.price = RESALE_PRICE;
        c.startTime = uint64(block.timestamp);
        c.deadline = uint64(block.timestamp + 10 days);
        c.signerEvidenceHash = PRIVATE_SIGNER;
        c.signerRevision = 1;
        c.signerAuthority = address(executor);
        c.secondaryConsignment = true;
        id = joinedPrivate.saleIdFor(5, 1, joinedPrivate.nextSaleNonce());
        this.joinedGovern(address(joinedPrivate), abi.encodeCall(joinedPrivate.registerSale, (c)));
        require(
            joinedPrivate.saleDetails(id).config.consignor == address(joinedCollector),
            "actual owner remains consignor"
        );
    }

    function _joinedCustody(bytes32 id, uint256 token) internal {
        _joinedSafe(
            joinedCollector,
            address(core),
            0,
            abi.encodeCall(core.setApprovalForAll, (address(joinedPrivate), true))
        );
        StreamPrivateSaleTypes.SaleCustodyGrant memory grant =
            StreamPrivateSaleTypes.SaleCustodyGrant(
                block.chainid,
                address(joinedPrivate),
                address(core),
                token,
                address(joinedCollector),
                id,
                keccak256(abi.encode(id, "original collector grant")),
                joinedPrivate.saleDetails(id).config.deadline
            );
        bytes memory proof = _joinedProof(joinedCollector, joinedPrivate.custodyGrantDigest(grant));
        _joinedSafe(
            joinedCollector,
            address(joinedPrivate),
            0,
            abi.encodeCall(joinedPrivate.depositCustody, (id, grant, uint8(2), proof))
        );
        require(
            core.ownerOf(token) == address(joinedPrivate)
                && joinedPrivate.saleDetails(id).status == 2,
            "real same NFT custody transfer"
        );
    }

    function _joinedResaleAuthorization(bytes32 id)
        internal
        view
        returns (StreamPrivateSaleTypes.SaleAuthorization memory a)
    {
        a.chainId = block.chainid;
        a.saleAdapter = address(joinedPrivate);
        a.collectionId = 1;
        a.saleId = id;
        a.saleKind = 5;
        address[] memory recipients = new address[](1);
        recipients[0] = address(joinedBuyer);
        a.initialRecipientsHash = keccak256(abi.encode(recipients));
        a.beneficiariesHash = a.initialRecipientsHash;
        a.tokenDataArrayHash = keccak256(abi.encode(new bytes[](0)));
        a.mintCommitmentsHash = keccak256(abi.encode(new bytes32[](0)));
        a.payer = address(joinedBuyer);
        a.executor = address(joinedBuyer);
        a.unitPrice = RESALE_PRICE;
        a.quantity = 1;
        a.nonce = keccak256(abi.encode(id, "original secondary purchase"));
        a.deadline = joinedPrivate.saleDetails(id).config.deadline;
    }

    function _joinedResale(bytes32 id, IStreamRoyaltySnapshot.Snapshot memory snapshot) internal {
        StreamPrivateSaleTypes.SaleAuthorization memory a = _joinedResaleAuthorization(id);
        IStreamPrivateSaleAdapter.Signature memory proof = IStreamPrivateSaleAdapter.Signature(
            vm.addr(PLATFORM_KEY), 1, _platformProof(joinedPrivate.authorizationDigest(a))
        );
        uint256 beforeRoyalty = joinedSource.config.wallet.balance;
        _joinedSafe(
            joinedBuyer,
            address(joinedPrivate),
            RESALE_PRICE + 77,
            abi.encodeCall(joinedPrivate.purchasePrivate, (a, proof))
        );
        uint256 royaltyAmount = uint256(RESALE_PRICE) * joinedSource.config.royaltyBps / 10000;
        IStreamPrivateSaleAdapter.Sale memory sold = joinedPrivate.saleDetails(id);
        require(
            sold.status == 3 && core.ownerOf(snapshot.tokenId) == address(joinedBuyer)
                && sold.royaltyReceiver == joinedSource.config.wallet
                && sold.royaltyAmount == royaltyAmount
                && joinedPrivate.digestConsumed(joinedPrivate.authorizationDigest(a)),
            "same actual NFT pays frozen snapshot quote"
        );
        require(
            joinedSource.config.wallet.balance == beforeRoyalty + royaltyAmount
                && joinedPrivate.totalLiabilities() == RESALE_PRICE - royaltyAmount + 77,
            "actual royalty funding and separate proceeds/excess liabilities"
        );
        require(
            core.totalSupply() == 1 && manager.nextOperationNonce() == 1
                && core.collectionNextSerial(1) == 2
                && keccak256(abi.encode(royalties.royaltySnapshot(snapshot.tokenId)))
                    == keccak256(abi.encode(snapshot)),
            "resale never remints or rewrites snapshot"
        );
        _joinedSafe(
            joinedCollector,
            address(joinedPrivate),
            0,
            abi.encodeCall(joinedPrivate.claimRefund, (id, address(joinedCollector)))
        );
        _joinedSafe(
            joinedBuyer,
            address(joinedPrivate),
            0,
            abi.encodeCall(joinedPrivate.claimRefund, (id, address(joinedBuyer)))
        );
        require(
            joinedPrivate.totalLiabilities() == 0 && address(joinedPrivate).balance == 0,
            "original account-only proceeds and excess exits"
        );
    }

    function joinedReplaceCollectionSource(uint16 bps) external {
        require(msg.sender == address(this), "fixture self-call");
        T.AssignmentFact memory f =
            royalties.previewArtistSnapshotRoyaltyAssignment(1, profile, bps, false);
        T.EconomicsConsent memory p =
            T.EconomicsConsent(1, address(royalties), ROYALTY_CLASS, 1, 1, f.assignmentHash);
        T.Authorization memory a = _artistAuthorization(false);
        _joinedSafe(
            joinedArtist,
            address(artists),
            0,
            abi.encodeCall(
                IStreamArtistEconomicsAuthority.recordProspectiveEconomicsConsent,
                (p, T.FixedEconomicsCandidate(profile, 0, bps, false), a)
            )
        );
        _joinedConsentEvidence(p);
        this.joinedGovern(
            address(royalties),
            abi.encodeCall(royalties.configureCollectionRoyalty, (uint256(1), profile, bps))
        );
    }

    function joinedRotateCollaboratorPayout(address account) external {
        require(msg.sender == address(this), "fixture self-call");
        _joinedPayout(joinedCollaborator, joinedCollaboratorId, account);
    }

    function _joinedWitness() internal view returns (bytes32) {
        DB.Witness memory w;
        (w.artistId, w.payout, w.designation) = artists.collectionArtistBeneficiary(1);
        T.Binding memory b = artistCoordinator.reads().acceptedBinding(1);
        w.generation = b.generation;
        w.bindingHash = b.bindingHash;
        w.authority = artists.acceptedArtist(1);
        w.rows = new C.Row[](1);
        w.rows[0] = artists.collaboratorAt(1, b.generation, 0);
        w.payouts = new address[](1);
        w.designations = new bytes32[](1);
        (w.payouts[0], w.designations[0]) =
            artists.collaboratorPayoutAccount(w.rows[0].collaboratorArtistId, w.rows[0].account);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_DYNAMIC_PRIMARY_BENEFICIARIES_V1"),
                block.chainid,
                address(primaryResolver),
                uint256(1),
                w
            )
        );
    }
    bytes32 private constant RECEIPT = keccak256(
        "PreparedNativeRightsRevenueRecorded(bytes32,bytes32,bytes32,((address,address,address,bytes32,uint256,bytes32,bytes32,bytes32,bytes32,uint256,uint256,address,address,address,bytes32,bytes32,bytes32,bytes32),(uint8,bytes32,bytes32)),((uint256,bytes32,bytes32,uint256,address,address,address,address,uint256,uint8,bytes32,uint256,uint8,bytes32,bytes32,bytes32,bytes32,bytes32),(uint8,bytes32,bytes32)),bytes32)"
    );

    function _joinedReceipt(bytes32 id, Vm.Log[] memory logs) internal view {
        bytes32 key = joinedHouse.auction(id).settlementKey;
        StreamSaleTemplate.Selection memory selected = _joinedSelection();
        bytes32 witness = _joinedWitness();
        IStreamNativeEnglishAuction.Auction memory a = joinedHouse.auction(id);
        uint256 receiptCount;
        uint256 dynamicCount;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(joinedRecorder)) continue;
            if (logs[i].topics[0] == RECEIPT) {
                ++receiptCount;
                require(
                    logs[i].topics.length == 4 && logs[i].data.length == 1376,
                    "original full43-word receipt"
                );
                (
                    StreamPreparedNativeRightsTypes.Facts memory f,
                    StreamPreparedNativeRightsTypes.Intent memory o,
                    bytes32 policy_
                ) = abi.decode(
                    logs[i].data,
                    (
                        StreamPreparedNativeRightsTypes.Facts,
                        StreamPreparedNativeRightsTypes.Intent,
                        bytes32
                    )
                );
                bytes32 hash = keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PREPARED_NATIVE_RIGHTS_FACTS_V1"), block.chainid, f
                    )
                );
                require(
                    logs[i].topics[1] == key
                        && logs[i].topics[2]
                            == joinedRecorder.preparedNativeSaleKey(
                                address(joinedHouse), a.saleId, a.saleNonce
                            ) && logs[i].topics[3] == hash
                        && joinedRecorder.preparedNativeRightsFactsHash(key) == hash,
                    "all indexed receipt identities"
                );
                require(
                    f.original.mode == 3
                        && keccak256(abi.encode(f.original))
                            == keccak256(abi.encode(joinedHouse.originalAuctionRights(id)))
                        && keccak256(abi.encode(o.original)) == keccak256(abi.encode(f.original)),
                    "original signed mode and assignment retained"
                );
                require(
                    f.mint.saleAdapter == address(joinedHouse)
                        && f.mint.mintManager == address(manager)
                        && f.mint.recorder == address(joinedRecorder) && f.mint.tokenId == a.tokenId
                        && f.mint.collectionSerial == a.tokenId && f.mint.collectionId == 1
                        && f.mint.tokenDataHash == keccak256(TOKEN_DATA)
                        && o.sale.poster == a.config.poster && o.sale.saleId == a.saleId
                        && o.sale.saleNonce == a.saleNonce && o.sale.payer == a.winner.payer
                        && o.sale.executor == a.winner.executor
                        && o.sale.originalPrimaryPolicyHash == a.config.expectedPrimaryPolicyHash,
                    "original context and actual prepared fields"
                );
                require(
                    policy_ == _joinedPrimaryPolicy(a.tokenId, selected)
                        && policy_ != _joinedPrimaryPolicy(0, selected)
                        && ledger.isManagerOperationRootUsed(address(manager), f.mint.operationRoot)
                        && joinedRecorder.settlementResult(key).operationIdentityCommitment
                            == f.mint.operationRoot,
                    "actual token policy and canonical root"
                );
            }
            if (
                logs[i].topics[0]
                    == keccak256(
                        "DynamicPreparedPrimaryBeneficiariesBound(uint16,bytes32,bytes32,bytes32,address)"
                    )
            ) {
                ++dynamicCount;
                require(
                    logs[i].topics.length == 3 && logs[i].topics[1] == key
                        && logs[i].topics[2] == selected.templateId
                        && keccak256(logs[i].data)
                            == keccak256(abi.encode(uint16(1), witness, a.config.poster)),
                    "full independently reconstructed beneficiary witness"
                );
            }
        }
        require(receiptCount == 1 && dynamicCount == 1, "one of each original and additive receipt");
    }
}
