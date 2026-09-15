// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistOnboardingFixture.sol";
import "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPlatformWorks.sol";
import "../../../smart-contracts/interfaces/stream/preservation/IStreamCollectionArchivalCoverage.sol";

/// @dev Actual Artist/Safe/Manager/Archive/dual-family preservation, with explicit unit
/// Core, selected metadata-host getters and governance action contexts. No paid-sale or network claim.
contract StreamArtistPlatformWorksTest is ArtistOnboardingFixture {
    StreamSchemaDocumentStore private _pwStore;
    bytes32 private _pwFirst;
    bytes32 private _pwSecond;
    uint256 private _pwNonce;
    error PlatformTestFailure();

    function testPlatformDeclarationOriginalHashMode3AndActualPhaseHistory() public {
        bytes32 statement = keccak256("platform declaration");
        vm.recordLogs();
        bytes32 record = ingress.declarePlatformWorks(2, statement);
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PLATFORM_WORKS_DECLARATION_V1"),
                        block.chainid,
                        address(ingress),
                        address(core),
                        uint256(2),
                        statement,
                        uint64(block.timestamp)
                    )
                ),
            "original declaration preimage"
        );
        require(
            ingress.consentMode(2) == 3 && ingress.acceptedArtist(2) == address(0),
            "platform is not a fabricated Artist"
        );
        _pwArchive(8, address(this), record);
        (bool ready, bytes32 evidence) = ingress.isPolicyConsented(2, PHASE, POLICY);
        require(ready && evidence == record, "declaration evidence");
        bytes32 registered = _pwRegister();
        require(
            registered != 0 && manager.hasRegisteredPhasePolicy(2),
            "actual successful registration is monotonic"
        );
        vm.prank(manager.owner());
        manager.setPhaseExecutor(2, PHASE, address(this), true);
        vm.prank(manager.owner());
        manager.setPhaseExecutor(2, PHASE, address(this), false);
        require(manager.hasRegisteredPhasePolicy(2), "disabling executor retains history");
        vm.expectRevert(abi.encodeWithSelector(PW.InvalidPlatformWorks.selector, uint256(2)));
        ingress.declarePlatformWorks(2, keccak256("replacement"));
        require(
            ingress.platformWorksState(2).declaration.recordHash == record, "immutable declaration"
        );
    }

    function testAnyPreviousPhaseBlocksDeclarationAndFailedRegistrationDoesNotSetHistory() public {
        bytes32 before_ = _roots();
        // First real registration fails at Artist admission and rolls back its new history bit.
        (bool ok,) = address(this).call(abi.encodeCall(this.platformRegisterExternal, ()));
        require(
            !ok && !manager.hasRegisteredPhasePolicy(2) && _roots() == before_,
            "failed phase has no history"
        );
        // Explicit typed Artist boundary permits a prior phase without inventing a Binding record.
        avm.mockCall(
            address(ingress),
            abi.encodeCall(IStreamArtistMintConsent.consentMode, (2)),
            abi.encode(uint8(1))
        );
        avm.mockCall(
            address(ingress),
            abi.encodeWithSelector(IStreamArtistMintConsent.isPolicyConsented.selector),
            abi.encode(true, keccak256("typed prior approval"))
        );
        avm.mockCall(
            address(ingress),
            abi.encodeWithSelector(IStreamArtistMintConsent.requireMintConsent.selector),
            bytes("")
        );
        _pwRegister();
        avm.clearMockedCalls();
        vm.expectRevert(abi.encodeWithSelector(PW.InvalidPlatformWorks.selector, uint256(2)));
        ingress.declarePlatformWorks(2, keccak256("late declaration"));
        require(
            manager.hasRegisteredPhasePolicy(2)
                && ingress.platformWorksState(2).declaration.recordHash == 0,
            "old phase cannot be hidden"
        );
    }

    function testPlatformAdminOriginalBindingAndUnapprovedCorrectionGates() public {
        bytes32 statement = keccak256("declaration");
        vm.prank(address(0xBAD));
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(0xBAD)));
        ingress.declarePlatformWorks(2, statement);
        vm.expectRevert(abi.encodeWithSelector(PW.InvalidPlatformWorks.selector, uint256(1)));
        ingress.declarePlatformWorks(1, statement);
        ingress.declarePlatformWorks(2, statement);
        bytes32 before_ = _roots();
        T.BindingProposal memory p = _proposal(artistId);
        vm.expectRevert(abi.encodeWithSelector(PW.InvalidPlatformWorks.selector, uint256(2)));
        ingress.proposeArtistBinding(2, p, bytes("unit identity document"), "Artist Safe");
        require(
            _roots() == before_
                && IStreamArtistBindingOwner(suite.owners[0]).binding(2).generation == 0,
            "whole failed proposal rolls back"
        );
    }

    function testPermissionlessClaimActualCoverageOriginalRecordAndReplay() public {
        ingress.declarePlatformWorks(2, keccak256("declaration"));
        (bytes32 evidence, bytes32 coverage) =
            _pwEvidence(address(0), 0, keccak256("public evidence"));
        A.CoverageFacts memory f =
            estateCoverageProvider.requireCollectionCoverage(coverage, 2, evidence);
        require(
            f.artistId == 0 && f.coverageRecordHash == coverage,
            "actual collection subject not fake artist"
        );
        vm.expectRevert(abi.encodeWithSelector(A.InvalidArchivalCoverage.selector));
        estateCoverageProvider.requireCollectionCoverage(coverage, 1, evidence);
        vm.expectRevert(abi.encodeWithSelector(A.InvalidArchivalCoverage.selector));
        estateCoverageProvider.requireCoverage(coverage, 0, evidence);
        address claimant = address(0xBEEF);
        vm.prank(claimant);
        bytes32 record = ingress.filePlatformWorksClaim(2, evidence, evidence, "urn:platform:claim");
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PLATFORM_WORKS_CLAIM_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(core),
                        uint256(2),
                        claimant,
                        evidence,
                        evidence,
                        uint64(block.timestamp)
                    )
                ),
            "original claim preimage"
        );
        PW.State memory p = ingress.platformWorksState(2);
        require(
            p.claimCount == 1 && p.latestClaim == record && p.contestState == 0
                && ingress.consentMode(2) == 3,
            "claim alone grants no authority or sale stop"
        );
        _pwArchive(9, claimant, record);
        bytes32 roots = _roots();
        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(PW.InvalidPlatformWorks.selector, uint256(2)));
        ingress.filePlatformWorksClaim(2, evidence, evidence, "different uri cannot replay");
        require(_roots() == roots, "permanent original tuple replay");
    }

    function testUnrelatedPublicClaimsCannotInvalidateGovernedResolutionContext() public {
        bytes32 claim_ = _pwClaim();
        bytes32 evidence = keccak256("scheduled resolution bytes");
        PW.Context memory first = ingress.platformWorksContext(
            2, 1, claim_, evidence, evidence, false
        );
        (bytes32 other,) = _pwEvidence(address(0), 0, keccak256("unrelated claimant"));
        vm.prank(address(0xCAFE));
        ingress.filePlatformWorksClaim(2, other, other, "urn:unrelated");
        require(
            keccak256(abi.encode(first))
                == keccak256(
                    abi.encode(
                        ingress.platformWorksContext(2, 1, claim_, evidence, evidence, false)
                    )
                ),
            "append-only claims cannot grief scheduled context"
        );
        require(ingress.platformWorksState(2).claimCount == 2, "both claims remain visible");
    }

    function testGovernedContestStopsMintDismissalResumesAndSustainedIsPermanent() public {
        bytes32 claim_ = _pwClaim();
        _pwResolve(1, claim_, false, 1);
        vm.expectRevert(abi.encodeWithSelector(PW.InvalidPlatformWorks.selector, uint256(2)));
        ingress.requireMintConsent(2, PHASE, POLICY);
        require(!ingress.finalityState(2).frozen, "open contest stops finality");
        _pwResolve(2, claim_, false, 1);
        ingress.requireMintConsent(2, PHASE, POLICY);
        _pwResolve(1, claim_, false, 1);
        _pwResolve(3, claim_, false, 1);
        bytes32 rootBefore = _roots();
        (bool ok,) = address(this)
            .call(abi.encodeCall(this.platformResolveExternal, (uint8(2), claim_, false, uint8(1))));
        require(
            !ok && _roots() == rootBefore && ingress.platformWorksState(2).contestState == 3,
            "sustained cannot be dismissed away"
        );
    }

    function testSustainedCorrectionActualSafeAcceptanceAndFreshMintPrerequisites() public {
        _pwInitialEconomics();
        bytes32 claim_ = _pwClaim();
        _pwResolve(1, claim_, false, 1);
        _pwResolve(3, claim_, false, 1);
        bytes32 before_ = _roots();
        (bool bad,) = address(this)
            .call(abi.encodeCall(this.platformResolveExternal, (uint8(3), claim_, true, uint8(1))));
        require(!bad && _roots() == before_, "correction requires terminal-freeze class2");
        bytes32 approval = _pwResolve(3, claim_, true, 2);
        PW.State memory p = ingress.platformWorksState(2);
        require(
            approval
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PLATFORM_WORKS_CORRECTION_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(core),
                        uint256(2),
                        p.correction.sustainedContestRecordHash,
                        claim_,
                        p.correction.evidenceHash,
                        p.correction.reasonHash,
                        p.correction.approvalActionId,
                        p.correction.approvedAt
                    )
                ),
            "original correction record"
        );
        _pwArchive(53, manager.governanceAuthority(), approval);
        T.BindingProposal memory proposal = _proposal(artistId);
        proposal.artistAddress = address(0xBAD);
        (bool wrong,) = address(ingress)
            .call(
                abi.encodeCall(
                    IStreamArtistOnboarding.proposeArtistBinding,
                    (2, proposal, bytes("unit identity document"), "Artist Safe")
                )
            );
        require(
            !wrong && ingress.platformWorksState(2).correction.correctiveGeneration == 0,
            "wrong true author cannot consume approval"
        );
        ingress.proposeArtistBinding(
            2, _proposal(artistId), bytes("unit identity document"), "Artist Safe"
        );
        require(
            ingress.consentMode(2) == 3 && !ingress.platformWorksState(2).correction.accepted,
            "proposal alone remains stopped"
        );
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.acceptanceDigest(2, a));
        ingress.acceptArtistBinding(2, a);
        require(
            ingress.consentMode(2) == 1 && ingress.acceptedArtist(2) == address(artist)
                && ingress.platformWorksState(2).contestState == 3,
            "real Safe approval preserves permanent contest display"
        );
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("policy"))
        );
        ingress.requireMintConsent(2, PHASE, POLICY);
        T.PolicyConsent memory policy = T.PolicyConsent(2, PHASE, POLICY);
        a = _authorization(false);
        a.signature = _signature(ingress.policyConsentDigest(policy, a));
        ingress.recordPolicyConsent(policy, a);
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("payout"))
        );
        ingress.requireMintConsent(2, PHASE, POLICY);
        _payout();
        _pwFullConsent();
        ingress.requireMintConsent(2, PHASE, POLICY);
        require(
            ingress.platformWorksState(2).declaration.recordHash == p.declaration.recordHash,
            "complete corrected mint consent never rewrites declaration"
        );
    }

    function testRefusedCorrectiveGenerationPermanentlyConsumesOnlyApproval() public {
        bytes32 claim_ = _pwClaim();
        _pwResolve(1, claim_, false, 1);
        _pwResolve(3, claim_, false, 1);
        _pwResolve(3, claim_, true, 2);
        ingress.proposeArtistBinding(
            2, _proposal(artistId), bytes("unit identity document"), "Artist Safe"
        );
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(2);
        L.Termination memory refusal = L.Termination(
            2, b.generation, b.bindingHash, keccak256("true author refuses"), "urn:refusal"
        );
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.bindingRefusalDigest(refusal, a));
        bytes32 record = ingress.refuseArtistBinding(refusal, a);
        require(
            record != 0 && ingress.bindingTermination(2, b.generation).kind == 1,
            "actual Safe refusal"
        );
        bytes32 before_ = _roots();
        vm.expectRevert(abi.encodeWithSelector(PW.InvalidPlatformWorks.selector, uint256(2)));
        ingress.proposeArtistBinding(
            2, _proposal(artistId), bytes("unit identity document"), "Artist Safe"
        );
        require(
            _roots() == before_
                && ingress.platformWorksState(2).correction.correctiveGeneration == b.generation
                && !ingress.platformWorksState(2).correction.accepted,
            "no replacement generation or fabricated acceptance"
        );
        vm.expectRevert(abi.encodeWithSelector(PW.InvalidPlatformWorks.selector, uint256(2)));
        ingress.requireMintConsent(2, PHASE, POLICY);
    }

    function testClaimMissingCoverageAndLateArchiveLeaveExactRetryUsable() public {
        ingress.declarePlatformWorks(2, keccak256("declaration"));
        (bytes32 evidence, bytes32 coverage) =
            _pwEvidence(address(artist), 0, keccak256("retry evidence"));
        bytes memory call_ = abi.encodeCall(
            IStreamArtistPlatformWorks.filePlatformWorksClaim, (2, evidence, evidence, "urn:retry")
        );
        bytes32 roots = _roots();
        avm.mockCallRevert(
            address(estateCoverageProvider),
            abi.encodeCall(
                IStreamCollectionArchivalCoverage.requireCollectionEvidence, (2, evidence)
            ),
            abi.encodeWithSelector(PlatformTestFailure.selector)
        );
        vm.expectRevert(abi.encodeWithSelector(PlatformTestFailure.selector));
        this.platformCallExternal(call_);
        require(
            _roots() == roots && ingress.platformWorksState(2).claimCount == 0,
            "coverage failure is terminal"
        );
        avm.clearMockedCalls();
        _pwMetadata();
        estateCoverageProvider.selectCollectionCoverage(coverage);
        avm.mockCallRevert(
            address(archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(PlatformTestFailure.selector)
        );
        vm.expectRevert(abi.encodeWithSelector(PlatformTestFailure.selector));
        this.platformCallExternal(call_);
        require(
            _roots() == roots && ingress.platformWorksState(2).claimCount == 0,
            "late archive rolls all state and replay back"
        );
        avm.clearMockedCalls();
        _pwMetadata();
        this.platformCallExternal(call_);
        require(ingress.platformWorksState(2).claimCount == 1, "identical original calldata retry");
    }

    function testPostFinalityDeclarationPersistsWhileUnmintedRemainderStops() public {
        bytes32 claim_ = _pwClaim();
        PW.State memory p = ingress.platformWorksState(2);
        address f = ingress.finalityRegistry();
        StreamCollectionFinalityRecord memory saved;
        saved.finalized = true;
        saved.finalityRecordHash = keccak256("typed prior finality");
        StreamFinalityComponentExpectation[] memory rows =
            new StreamFinalityComponentExpectation[](1);
        rows[0].component = address(ingress);
        rows[0].componentType = keccak256("PLATFORM_WORKS_DECLARATION");
        rows[0].dataHash = p.declaration.recordHash;
        avm.mockCall(
            f,
            abi.encodeCall(IStreamArtworkFinalityRegistry.collectionFinalityRecord, (2)),
            abi.encode(saved)
        );
        avm.mockCall(
            f,
            abi.encodeCall(IStreamArtworkFinalityRegistry.finalityComponentCount, (2)),
            abi.encode(uint256(1))
        );
        avm.mockCall(
            f,
            abi.encodeCall(IStreamArtworkFinalityRegistry.finalityComponents, (2, 0, 1)),
            abi.encode(rows)
        );
        StreamFinalityComponentState memory first = ingress.finalityState(2);
        _pwResolve(1, claim_, false, 1);
        require(
            keccak256(abi.encode(ingress.finalityState(2))) == keccak256(abi.encode(first)),
            "executed declaration finality remains byte-identical"
        );
        vm.expectRevert(abi.encodeWithSelector(PW.InvalidPlatformWorks.selector, uint256(2)));
        ingress.requireMintConsent(2, PHASE, POLICY);
    }

    function platformCallExternal(bytes calldata data) external {
        require(msg.sender == address(this));
        (bool ok, bytes memory reason) = address(ingress).call(data);
        if (!ok) assembly ("memory-safe") { revert(add(reason, 32), mload(reason)) }
    }

    function platformRegisterExternal() external returns (bytes32) {
        require(msg.sender == address(this));
        return _pwRegister();
    }

    function platformResolveExternal(
        uint8 state,
        bytes32 claim_,
        bool correction,
        uint8 actionClass
    ) external returns (bytes32) {
        require(msg.sender == address(this));
        return _pwResolve(state, claim_, correction, actionClass);
    }

    function _pwInitialEconomics() private {
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory first =
            primary.primaryEconomicsFacts(1, 1, 1);
        IStreamRoyaltyResolver.RoyaltyConfig memory second = royalty.collectionRoyalty(1);
        vm.prank(manager.governanceAuthority());
        primary.setPrimaryProfileAssignment(PRIMARY, 1, 2, first.profileId, 0);
        vm.prank(manager.governanceAuthority());
        royalty.configureCollectionRoyalty(2, second.profileId, 500);
    }

    function _pwFullConsent() private {
        (T.AssignmentFact memory first, T.AssignmentFact memory second) =
            coordinator.reads().currentAssignments(2);
        for (uint256 i; i < 2; ++i) {
            T.AssignmentFact memory f = i == 0 ? first : second;
            T.EconomicsConsent memory p =
                T.EconomicsConsent(
                2, f.resolver, f.revenueClass, f.scope, f.scopeId, f.assignmentHash
            );
            T.Authorization memory a = _authorization(false);
            a.signature = _signature(ingress.economicsConsentDigest(p, a));
            ingress.recordEconomicsConsent(p, a);
        }
        (, bytes32 content) = metadata.currentArtistContentState(2);
        T.Ratification memory r = T.Ratification(2, address(metadata), content);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.contentRatificationDigest(r, a));
        ingress.recordContentRatification(r, a);
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(2);
        bytes32 deployed = StreamArtistHashes.deploymentFacts(
            StreamArtistHashes.Environment(
                block.chainid, address(ingress), suite.core, suite.mintManager
            ),
            2,
            b
        );
        _pwAttest(
            9,
            bytes32(uint256(uint160(suite.core))),
            deployed,
            keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1")
        );
        _pwAttest(
            10,
            artistId,
            ingress.operativeIdentityRecord(artistId),
            keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")
        );
    }

    function _pwAttest(uint8 kind, bytes32 subject, bytes32 state, bytes32 schema) private {
        bytes memory statement = abi.encode(kind, subject, state, schema);
        T.Attestation memory p = T.Attestation(
            2, kind, subject, state, schema, keccak256(statement), "urn:platform:corrected"
        );
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.attestationDigest(p, a));
        ingress.recordArtistAttestation(p, a, statement);
    }

    function _pwRegister() private returns (bytes32) {
        (bytes32[] memory ids, IStreamMintManager.MintCounterConfig[] memory configs) = _counters();
        IStreamMintManager.MintGateConfig memory gate;
        vm.prank(manager.owner());
        return manager.configurePhase(2, PHASE, _phaseConfig(), gate, ids, configs);
    }

    function _pwClaim() private returns (bytes32) {
        ingress.declarePlatformWorks(2, keccak256("declaration"));
        (bytes32 e,) = _pwEvidence(address(artist), 0, keccak256("claim evidence"));
        return ingress.filePlatformWorksClaim(2, e, e, "urn:claim");
    }

    function _pwResolve(uint8 state, bytes32 claim_, bool correction, uint8 actionClass)
        private
        returns (bytes32)
    {
        (bytes32 evidence,) = _pwEvidence(
            address(artist),
            claim_,
            keccak256(
                abi.encode(
                    "resolution", state, correction, ingress.platformWorksState(2).contestRecord
                )
            )
        );
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        authority.configureContestReads(
            suite.roleRegistry, address(artist), evidence, "urn:platform:resolution"
        );
        PW.Context memory c =
            ingress.platformWorksContext(2, state, claim_, evidence, evidence, correction);
        bytes32 action = keccak256(abi.encode(c, actionClass));
        // Explicit unique action-id boundary; the reused unit governor otherwise returns one constant id.
        avm.mockCall(
            address(authority),
            abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
            abi.encode(true, action, actionClass, c.scopeHash, c.oldValueHash, c.newValueHash)
        );
        authority.executeModuleContext(
            address(ingress),
            correction
                ? abi.encodeCall(
                    IStreamArtistPlatformWorks.approvePlatformWorksCorrection,
                    (2, claim_, evidence, evidence)
                )
                : abi.encodeCall(
                    IStreamArtistPlatformWorks.setPlatformWorksContest,
                    (2, state, claim_, evidence, evidence)
                ),
            actionClass,
            c.scopeHash,
            c.oldValueHash,
            c.newValueHash
        );
        avm.mockCall(
            address(authority),
            abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
            abi.encode(false, bytes32(0), uint8(0), bytes32(0), bytes32(0), bytes32(0))
        );
        PW.State memory p = ingress.platformWorksState(2);
        return correction ? p.correction.recordHash : p.contestRecord;
    }

    function _pwMetadata() private {
        if (address(_pwStore) == address(0)) _pwStore = new StreamSchemaDocumentStore();
        avm.mockCall(
            address(metadata),
            abi.encodeCall(IStreamCollectionMetadataV1.core, ()),
            abi.encode(address(core))
        );
        avm.mockCall(
            address(metadata),
            abi.encodeCall(IStreamCollectionMetadataV1.chunkStore, ()),
            abi.encode(address(_pwStore))
        );
    }

    function _pwEvidence(address author, bytes32 claim_, bytes32 narrative)
        private
        returns (bytes32 evidence, bytes32 coverage)
    {
        _pwMetadata();
        if (_pwFirst == 0) {
            _pwGrantFixity();
            _pwFirst = _pwFamily(true);
            _pwSecond = _pwFamily(false);
        }
        bytes memory payload = abi.encode(PW.Evidence(1, 2, author, claim_, narrative));
        (evidence,) = _pwStore.publishChunk(payload);
        A.Envelope memory e = A.Envelope(
            0,
            evidence,
            keccak256("6529STREAM_PLATFORM_WORKS_EVIDENCE_V1"),
            keccak256("BINARY_EXACT_V1"),
            2,
            sha256(payload),
            uint64(payload.length),
            1,
            0
        );
        bytes32 env = estateCoverageProvider.recordCollectionEnvelope(2, e, payload);
        A.Checkpoint memory c;
        c.networkId = estateCheckpointVerifier.networkId();
        c.blockHash = new bytes(48);
        c.blockHash[0] = 0x65;
        c.blockHeight = 1500000;
        c.dataSize = uint64(payload.length);
        c.blockDataSize = payload.length;
        c.dataRoot = _pwLeaf(sha256(payload), payload.length);
        c.transactionRoot = _pwLeaf(c.dataRoot, payload.length);
        c.transactionId = keccak256(abi.encode("synthetic platform transaction", evidence));
        c.transactionEnd = payload.length;
        c.observedAt = uint64(block.timestamp);
        c.configurationHash = estateCheckpointVerifier.configurationHash();
        bytes32 digest = estateCheckpointVerifier.checkpointDigest(c);
        A.ObserverProof[] memory cert = new A.ObserverProof[](2);
        cert[0] = A.ObserverProof(safeVm.addr(0xE5701), _pwSign(0xE5701, digest));
        cert[1] = A.ObserverProof(safeVm.addr(0xE5702), _pwSign(0xE5702, digest));
        if (cert[0].account > cert[1].account) (cert[0], cert[1]) = (cert[1], cert[0]);
        bytes32 checkpoint = estateCheckpointVerifier.recordCheckpoint(
            c,
            abi.encodePacked(c.dataRoot, uint256(payload.length)),
            abi.encodePacked(sha256(payload), uint256(payload.length)),
            payload,
            cert
        );
        bytes32 first =
            _pwReceipt(env, _pwFirst, checkpoint, abi.encodePacked(c.transactionId), 0xE5703, true);
        bytes32 second = _pwReceipt(
            env, _pwSecond, 0, abi.encodePacked(bytes4(0x01551220), e.payloadDigest), 0xE5704, false
        );
        _pwFixity(first, e, _pwNonce++);
        _pwFixity(second, e, _pwNonce++);
        coverage = estateCoverageProvider.recordCoverage(first, second);
        require(
            estateCoverageProvider.requireCollectionEvidence(2, evidence).coverageRecordHash
                == coverage,
            "actual two independent families and exact native checkpoint"
        );
    }

    function _pwLeaf(bytes32 digest, uint256 end) private pure returns (bytes32) {
        return sha256(abi.encodePacked(sha256(abi.encodePacked(digest)), sha256(abi.encode(end))));
    }

    function _pwArchive(uint16 op, address actor, bytes32 record) private view {
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(ingress),
                address(coordinator),
                op,
                actor,
                record
            )
        );
        (uint16 schema, bytes32 config, uint16 actual, address savedActor, bytes32 saved,,,) = abi.decode(
            archive.artistEvidenceBytesV2(id, 1),
            (uint16, bytes32, uint16, address, bytes32, T.Snapshot[7], T.Snapshot[7], bytes)
        );
        require(
            schema == 1 && config == coordinator.configurationHash() && actual == op
                && savedActor == actor && saved == record,
            "exact original operation archive"
        );
    }

    function _pwFamily(bool endowed) private returns (bytes32 hash) {
        string memory name = endowed ? "estate-arweave" : "estate-ipfs";
        bytes memory salt = bytes(name);
        A.Family memory f = A.Family(
            keccak256(salt),
            endowed ? estateCheckpointVerifier.networkId() : keccak256("IPFS"),
            keccak256(bytes.concat(salt, "protocol")),
            keccak256(bytes.concat(salt, "addressing")),
            keccak256(bytes.concat(salt, "custodian")),
            keccak256(bytes.concat(salt, "funding")),
            keccak256(bytes.concat(salt, "retrieval")),
            keccak256(bytes.concat(salt, "jurisdiction")),
            endowed ? 1 : 2,
            safeVm.addr(endowed ? 0xE5703 : 0xE5704),
            endowed
                ? estateCheckpointVerifier.profileHash()
                : estateCoverageProvider.POSSESSION_PROFILE()
        );
        bytes32 scope;
        bytes32 oldHash;
        bytes32 newHash;
        (hash, scope, oldHash, newHash) = estateCoverageProvider.familyRegistrationContext(name, f);
        EstateGovernanceFixture(manager.governanceAuthority())
            .executeModuleContext(
                address(estateCoverageProvider),
                abi.encodeCall(estateCoverageProvider.admitFamily, (name, f)),
                1,
                scope,
                oldHash,
                newHash
            );
    }

    function _pwReceipt(
        bytes32 envelope,
        bytes32 family,
        bytes32 checkpoint,
        bytes memory identifier,
        uint256 key,
        bool endowed
    ) private returns (bytes32) {
        A.ReceiptTerms memory r = A.ReceiptTerms(
            envelope,
            family,
            keccak256(identifier),
            keccak256(bytes(endowed ? "CONTENT_ADDRESSED_INCLUSION" : "ATTESTED_POSSESSION")),
            endowed
                ? estateCheckpointVerifier.profileHash()
                : estateCoverageProvider.POSSESSION_PROFILE(),
            checkpoint,
            safeVm.addr(key),
            uint64(block.timestamp),
            _pwNonce++,
            uint64(block.timestamp + 1 days)
        );
        if (!endowed) {
            r.proofRecordHash = estateCoverageProvider.possessionHash(
                A.Possession(envelope, family, r.storageIdentifierHash, r.writer, r.observedAt)
            );
        }
        return estateCoverageProvider.recordReceipt(
            r, identifier, _pwSign(key, estateCoverageProvider.receiptDigest(r))
        );
    }

    function _pwFixity(bytes32 receipt, A.Envelope memory e, uint256 nonce) private {
        (A.ReceiptTerms memory r,,) = estateCoverageProvider.receipt(receipt);
        A.FixityTerms memory f = A.FixityTerms(
            receipt,
            r.envelopeHash,
            r.familyRecordHash,
            e.payloadDigest,
            e.payloadDigest,
            e.byteSize,
            uint64(block.timestamp),
            1,
            keccak256(abi.encode("estate fixity", receipt)),
            0,
            0,
            safeVm.addr(0xE5705),
            nonce,
            uint64(block.timestamp + 1 days)
        );
        estateCoverageProvider.recordFixity(
            f, _pwSign(0xE5705, estateCoverageProvider.fixityDigest(f))
        );
    }

    function _pwSign(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = safeVm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _pwGrantFixity() private {
        bytes32 role = keccak256("ROLE_FIXITY_OPERATOR");
        address holder = safeVm.addr(0xE5705);
        (bytes32 chain, uint64 revision) = estateFixityRoles.roleMutationState(role);
        (bytes32 global, uint64 globalRevision) = estateFixityRoles.globalRoleMutationState();
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_SCOPE_V1"),
                block.chainid,
                address(estateFixityRoles),
                role,
                holder
            )
        );
        bytes32 next = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_V1"),
                chain,
                block.chainid,
                address(estateFixityRoles),
                role,
                holder,
                true,
                revision + 1
            )
        );
        bytes32 nextGlobal = keccak256(
            abi.encode(
                keccak256("6529STREAM_GLOBAL_ROLE_MUTATION_V1"),
                global,
                block.chainid,
                address(estateFixityRoles),
                role,
                holder,
                true,
                globalRevision + 1
            )
        );
        bytes32 domain = keccak256("6529STREAM_ROLE_MUTATION_STATE_V1");
        bytes32 oldHash = keccak256(
            abi.encode(
                domain,
                block.chainid,
                address(estateFixityRoles),
                scope,
                false,
                chain,
                revision,
                global,
                globalRevision
            )
        );
        bytes32 newHash = keccak256(
            abi.encode(
                domain,
                block.chainid,
                address(estateFixityRoles),
                scope,
                true,
                next,
                revision + 1,
                nextGlobal,
                globalRevision + 1
            )
        );
        EstateGovernanceFixture(manager.governanceAuthority())
            .executeModuleContext(
                address(estateFixityRoles),
                abi.encodeCall(estateFixityRoles.grantRole, (role, holder)),
                1,
                scope,
                oldHash,
                newHash
            );
    }
}
