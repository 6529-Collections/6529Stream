// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistRecoveredDisputeHistoryFixture.sol";
import {
    StreamArtistRecoveredIdentityHydrationSource as IdentitySource
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredIdentityHydrationSource.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredDisputeIdentityFacts as Facts
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredDisputeIdentityFacts.sol";

contract StreamArtistRecoveredDisputeHistoryActualTest is ArtistRecoveredDisputeHistoryFixture {
    function testSignedOpenCounterAndDirectWithdrawalRetainOriginalDomains() external {
        _baseline();
        _signedDispute(1, keccak256("opening"), false);
        _signedDispute(3, keccak256("counter"), false);
        _signedDispute(2, keccak256("withdraw"), true);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        D.Bundle memory b = _bundle(p);
        require(
            b.disputes.length == 3 && b.current.state == 2
                && b.disputes[0].withdrawal.recordHash == b.disputes[2].record.recordHash,
            "complete original chain"
        );
        _import(next, r, p);
        _assertDisputeImport(next.coordinator.suiteConfiguration(), b);
    }

    function testLiveOpenDisputePreservedAndResolvedByNewOriginalOwner() external {
        _baseline();
        _signedDispute(1, keccak256("unresolved"), false);
        _signedDispute(3, keccak256("live counter"), true);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        D.Bundle memory b = _bundle(p);
        require(b.current.state == 4 && b.heads[0].open, "legitimate open source");
        _import(next, r, p);
        _assertDisputeImport(next.coordinator.suiteConfiguration(), b);
        _rhAdopt(next);
        bytes32 resolution = _resolve(1, 1);
        require(
            ingress.attributionDisputeResolution(resolution).restoredState == 2,
            "new original class1 disposition"
        );
    }

    function testClass2RevokedStateRetainedWithoutInventedNewAcceptance() external {
        _baseline();
        _signedDispute(1, keccak256("revoke opening"), false);
        _resolve(2, 2);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        D.Bundle memory b = _bundle(p);
        require(
            b.current.state == 5 && b.resolutions[0].record.actionClass == 2,
            "actual class2 revoked state"
        );
        _import(next, r, p);
        _assertDisputeImport(next.coordinator.suiteConfiguration(), b);
    }

    function testPendingRepudiationCountAndExactCancellationAfterImport() external {
        _baseline();
        RP.Record memory staged = _stage(keccak256("pending"), false);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        D.Bundle memory b = _bundle(p);
        _import(next, r, p);
        _assertDisputeImport(next.coordinator.suiteConfiguration(), b);
        require(
            RepudiationOwner(next.coordinator.suiteConfiguration().owners[4])
                .repudiationCount(artistId, keccak256(abi.encode(staged.authorityHead))) == 1,
            "exact active cohort count"
        );
        _rhAdopt(next);
        _cancel(staged);
        require(
            ingress.attributionRepudiationTerminal(staged.recordHash).phase == 3,
            "new owner original cancel"
        );
    }

    function testCancelledAndExecutedRepudiationsRetainEveryTerminal() external {
        _baseline();
        RP.Record memory first = _stage(keccak256("cancelled"), true);
        _cancel(first);
        RP.Record memory second = _stage(keccak256("executed"), false);
        _execute(second);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        D.Bundle memory b = _bundle(p);
        require(
            b.repudiations.length == 2 && b.repudiations[0].terminal.phase == 3
                && b.repudiations[1].terminal.phase == 4 && b.current.state == 5,
            "two distinct terminal records"
        );
        _import(next, r, p);
        _assertDisputeImport(next.coordinator.suiteConfiguration(), b);
    }

    function testOpeningInvalidatesPendingWithoutInventedReceiptOrRevision() external {
        _baseline();
        RP.Record memory staged = _stage(keccak256("invalidated"), false);
        bytes32 opening = _signedDispute(1, keccak256("interrupt"), false);
        require(
            ingress.attributionRepudiationTerminal(staged.recordHash).phase == 5,
            "actual automatic invalidation"
        );
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        D.Bundle memory b = _bundle(p);
        require(
            b.repudiations[0].terminal.reasonHash == opening
                && b.repudiations[0].terminalPoint.ownerRevision == 0,
            "same original opening commit"
        );
        _import(next, r, p);
        _assertDisputeImport(next.coordinator.suiteConfiguration(), b);
    }

    function testSourceDriftRefusesThenSameCapturedHistoryImports() external {
        _baseline();
        bytes32 opening = _signedDispute(1, keccak256("drift"), false);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        D.Bundle memory b = _bundle(p);
        AD.Record memory bad = abi.decode(abi.encode(b.disputes[0].record), (AD.Record));
        bad.nonce += 1;
        bytes memory input = abi.encodeCall(DisputeOwner.attributionDisputeRecord, (opening));
        avm.mockCall(suite.owners[4], input, abi.encode(bad));
        bytes32 before_ = _rhDestinationHash(next);
        dv.expectRevert();
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(r);
        require(_rhDestinationHash(next) == before_, "no partial import");
        avm.mockCall(suite.owners[4], input, abi.encode(b.disputes[0].record));
        _import(next, r, p);
        _assertDisputeImport(next.coordinator.suiteConfiguration(), b);
    }

    function testLateArchiveFailureRollsBackPendingStateAndSameSafeEnvelopeRetries() external {
        _baseline();
        _stage(keccak256("rollback pending"), true);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        D.Bundle memory b = _bundle(p);
        bytes memory data = abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (r));
        dv.expectCall(next.coordinator.suiteConfiguration().archive, _firstPage(next, r, p), 2);
        bytes32 before_ = _rhDestinationHash(next);
        uint256 nonce = rotationSafe.nonce();
        uint256 height = block.number;
        vm.roll(uint256(type(uint64).max) + 1);
        dv.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(address(next.registry), data);
        require(
            _rhDestinationHash(next) == before_ && rotationSafe.nonce() == nonce,
            "all seven roots and Safe nonce roll back"
        );
        require(
            RepudiationOwner(next.coordinator.suiteConfiguration().owners[4])
                    .rawPendingRepudiation(1) == 0,
            "semantic pending import rolled back"
        );
        vm.roll(height);
        require(this.rhExecuteNewSafe(address(next.registry), data), "identical request retry");
        _assertDisputeImport(next.coordinator.suiteConfiguration(), b);
    }

    function testSignedHistorySurvivesTwoOriginalRegistryDomains() external {
        _baseline();
        _signedDispute(1, keccak256("first era"), false);
        _signedDispute(2, keccak256("first withdrawal"), false);
        Successor memory middle = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(middle);
        _import(middle, r, p);
        _rhAdopt(middle);
        _signedDispute(1, keccak256("second era"), true);
        _resolve(1, 1);
        Successor memory last = _rhCutover();
        (r, p) = _prepare(last);
        D.Bundle memory b = _bundle(p);
        require(
            p.admission.provenance.eras.length == 2
                && b.disputes[0].point.environmentHash != b.disputes[2].point.environmentHash,
            "two exact original domains"
        );
        _import(last, r, p);
        _assertDisputeImport(last.coordinator.suiteConfiguration(), b);
    }

    function testMissingCapabilityAndReplayNeverDropTheHistory() external {
        _baseline();
        _stage(keccak256("complete inventory"), false);
        Successor memory next = _rhCutover();
        (RH.Request memory r,) = _prepare(next);
        bytes32 before_ = _rhDestinationHash(next);
        r.expectedCapabilities[4].supportedFeatures &= ~uint256(8192);
        dv.expectRevert();
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(r);
        r.expectedCapabilities[4].supportedFeatures |= 8192;
        r.records.authority.replayOrigins[4][0].scope = keccak256("missing original");
        dv.expectRevert();
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(r);
        require(_rhDestinationHash(next) == before_, "no silent projection or partial state");
    }

    function testGuardianVetoRetainsOriginal48ContestCauseAndCurrentContestedIdentity() external {
        _baseline();
        RP.Record memory staged = _stage(keccak256("veto"), false);
        bytes32 contest = _veto(staged);
        bytes32 cause = ingress.currentIdentityContestCause(artistId).causeHash;
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        D.Bundle memory b = _bundle(p);
        require(
            b.repudiations[0].terminal.phase == 2
                && Identity(suite.owners[2]).identity(artistId).status == 4,
            "actual guardian veto status"
        );
        _import(next, r, p);
        _assertDisputeImport(next.coordinator.suiteConfiguration(), b);
        require(
            next.registry.currentIdentityContestCause(artistId).causeHash == cause
                && next.registry.currentIdentityContestCause(artistId).facts.referenceHash
                    == contest
                && Identity(next.coordinator.suiteConfiguration().owners[2])
                .identity(artistId)
                .status == 4,
            "same canonical Contest Cause and contested status"
        );
    }

    function testRevokedExhaustedGrantRetainsBothHistoricalDisputeUses() external {
        _baseline();
        bytes32 grant = _grantDispute(2);
        _delegatedDispute(1, grant, 0);
        _delegatedDispute(2, grant, 1);
        _revokeDisputeGrant(grant);
        require(
            ingress.delegationRecord(grant).uses == 2 && ingress.delegationRecord(grant).revoked,
            "actual exhausted revoked historical grant"
        );
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        D.Bundle memory b = _bundle(p);
        _import(next, r, p);
        _assertDisputeImport(next.coordinator.suiteConfiguration(), b);
        require(
            next.registry.delegationRecord(grant).uses == 2
                && next.registry.delegationRecord(grant).revoked,
            "no replay resurrection or current grant substitution"
        );
    }

    function testSuccessorRejectsImportedConsumedNonceBeforeFreshSignedOpening() external {
        _baseline();
        bytes32 opening = _signedDispute(1, keccak256("source consumed nonce"), false);
        uint256 consumed = ingress.attributionDisputeRecord(opening).nonce;
        _signedDispute(2, keccak256("close before migration"), false);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        _import(next, r, p);
        _rhAdopt(next);
        require(Identity(suite.owners[2]).nonceUsed(artistId, consumed), "imported consumed nonce");
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                address(ingress),
                address(coordinator),
                suite.archive,
                suite.owners[2],
                OriginalOwner(suite.owners[2]).domainId(),
                keccak256("identity_authority.replay.nonce_allocator"),
                keccak256(abi.encode(artistId, consumed))
            )
        );
        _refusedSuccessorOpening(next, 0, consumed, abi.encodeWithSelector(T.Replay.selector, key));
        bytes32 fresh = _signedDispute(1, keccak256("fresh successor nonce"), false);
        require(
            ingress.attributionDisputeRecord(fresh).nonce != consumed
                && ingress.attributionDispute(1, Binding(suite.owners[0]).binding(1).generation).open,
            "fresh successor-domain signature succeeds"
        );
    }

    function testSuccessorRejectsImportedRevokedGrantThenFreshReplacementSucceeds() external {
        _successorUnavailableGrant(true);
    }

    function testSuccessorRejectsImportedExhaustedGrantThenFreshReplacementSucceeds() external {
        _successorUnavailableGrant(false);
    }

    function _successorUnavailableGrant(bool revoked) private {
        _baseline();
        bytes32 grant = _grantDispute(revoked ? 0 : 2);
        _delegatedDispute(1, grant, 0);
        _delegatedDispute(2, grant, 1);
        if (revoked) _revokeDisputeGrant(grant);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        _import(next, r, p);
        _rhAdopt(next);
        Delegate.Record memory saved = ingress.delegationRecord(grant);
        require(
            saved.uses == 2 && saved.revoked == revoked
                && saved.grant.maxUses == (revoked ? 0 : 2),
            "distinct original unavailability cause"
        );
        _refusedSuccessorOpening(
            next, grant, 2, abi.encodeWithSelector(Delegate.DelegationUnavailable.selector, grant)
        );
        bytes32 replacement = _grantDispute(3);
        require(replacement != grant, "new original successor-domain grant");
        bytes32 fresh = _delegatedDispute(1, replacement, 2);
        require(
            ingress.attributionDisputeRecord(fresh).standing.delegation == replacement
                && ingress.delegationRecord(replacement).uses == 1
                && keccak256(abi.encode(ingress.delegationRecord(grant)))
                    == keccak256(abi.encode(saved)),
            "failed nonce was rolled back; new grant works without rewriting history"
        );
    }

    function _refusedSuccessorOpening(
        Successor memory next,
        bytes32 grant,
        uint256 nonce,
        bytes memory expectedError
    ) private {
        T.Binding memory binding = Binding(suite.owners[0]).binding(1);
        bytes32 evidence = _evidence(0, keccak256(abi.encode("successor refusal", grant, nonce)));
        AD.Filing memory filing = AD.Filing(1, binding.generation, 1, evidence, evidence);
        AD.Standing memory standing = AD.Standing(artistId, binding.generation, 0, grant);
        T.Authorization memory a = T.Authorization(nonce, uint64(block.timestamp + 1 days), "");
        bytes32 digest = ingress.attributionDisputeDigest(filing, a);
        a.signature = grant == 0 ? _signature(digest) : _delegateSignature(digest);
        require(a.signature.length != 0, "fresh signature under actual successor domain");
        bytes32 before_ = _rhDestinationHash(next);
        bool principalUsed = Identity(suite.owners[2]).nonceUsed(artistId, nonce);
        (bool delegateUsed, uint256 delegateHint) =
            ingress.delegatedNonceState(artistId, address(delegateSafe), nonce);
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(ingress),
                address(coordinator),
                uint16(60),
                address(rotationSafe),
                HydrationOwner(next.identity).authorityHydrationCommitment()
            )
        );
        bytes32 archiveBefore = keccak256(Archive(suite.archive).artistEvidenceBytesV2(id, 1));
        uint256 archiveNonce = avm.getNonce(suite.archive);
        dv.recordLogs();
        (bool ok, bytes memory reason) = address(ingress).call(
            abi.encodeCall(Disputes.openAttributionDispute, (filing, standing, a))
        );
        require(!ok && keccak256(reason) == keccak256(expectedError), "exact original refusal");
        DisputeHistoryVm.Log[] memory logs = dv.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            require(logs[i].emitter != suite.archive, "refusal never reaches Archive append");
        }
        (bool usedAfter, uint256 hintAfter) =
            ingress.delegatedNonceState(artistId, address(delegateSafe), nonce);
        require(
            _rhDestinationHash(next) == before_
                && Identity(suite.owners[2]).nonceUsed(artistId, nonce) == principalUsed
                && usedAfter == delegateUsed && hintAfter == delegateHint
                && avm.getNonce(suite.archive) == archiveNonce
                && keccak256(Archive(suite.archive).artistEvidenceBytesV2(id, 1)) == archiveBefore,
            "all seven owner/nonce and retained Archive state unchanged"
        );
    }

    function testExecutedRepudiationFreshCorrectionAndLaterAcceptedHistoryRemainExact() external {
        _baseline();
        RP.Record memory staged = _stage(keccak256("executed cause3"), false);
        _execute(staged);
        _correctExecuted(staged.recordHash);
        _signedDispute(1, keccak256("second accepted generation"), true);
        _resolve(1, 1);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        D.Bundle memory b = _bundle(p);
        require(
            b.generations.length == 2 && b.repudiations[0].terminal.phase == 4
                && b.current.state == 2,
            "actual correction and independent acceptance"
        );
        _import(next, r, p);
        _assertDisputeImport(next.coordinator.suiteConfiguration(), b);
        (BC.Approval memory expected, bytes32 hash) =
            CorrectionOwner(suite.owners[0]).bindingCorrection(p.query.bindingHash);
        (BC.Approval memory actual, bytes32 imported) = CorrectionOwner(
                next.coordinator.suiteConfiguration().owners[0]
            ).bindingCorrection(p.query.bindingHash);
        require(
            expected.cause == 3 && hash == imported
                && keccak256(abi.encode(actual)) == keccak256(abi.encode(expected)),
            "exact class2 action and executed cause preimage"
        );
    }

    function testMalformedHeadTerminalAndOriginalDomainAreRejectedByFullCodec() external {
        _baseline();
        _signedDispute(1, keccak256("codec"), false);
        _signedDispute(3, keccak256("codec counter"), false);
        _signedDispute(2, keccak256("codec withdrawal"), false);
        _stage(keccak256("codec pending"), false);
        Successor memory next = _rhCutover();
        (, Commit.Prepared memory p) = _prepare(next);
        (, Payload.Payload memory local) = Payload.decode(p.data[4].typedState, 4);
        for (uint256 i; i < 6; ++i) {
            D.Bundle memory b = DisputeCodec.decode(p.query, local.provenance, local.semanticState);
            if (i == 0) b.disputes[0].record.bindingHash = keccak256("foreign binding");
            if (i == 1) b.disputes[1].record.previousRecordHash = keccak256("hidden counter");
            if (i == 2) b.disputes[0].withdrawal.counterStatementRecordHash = 0;
            if (i == 3) b.repudiations[0].terminal.phase = 4;
            if (i == 4) b.repudiations[0].point.environmentHash = keccak256("foreign era");
            if (i == 5) b.heads[0].open = true;
            dv.expectRevert();
            this.decodeDisputeHistory(
                p.query, local.provenance, abi.encode(D.ATTRIBUTION, uint16(1), b)
            );
        }
    }

    function testPriorAccepted14And15And16RemainExactAcrossTwoImports() external {
        _baseline();
        _baseConsents();
        _correctAccepted();
        _signedDispute(1, keccak256("later accepted generation with prior consents"), true);
        _signedDispute(2, keccak256("later withdrawal"), false);
        Successor memory middle = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(middle);
        _import(middle, r, p);
        _assertBaseConsents(middle.coordinator.suiteConfiguration());
        _rhAdopt(middle);
        _basePolicy();
        _signedDispute(1, keccak256("fresh B opening"), false);
        _resolve(1, 1);
        Successor memory last = _rhCutover();
        (r, p) = _prepare(last);
        require(p.admission.provenance.eras.length == 2, "complete original A/B domains");
        _import(last, r, p);
        _assertBaseConsents(last.coordinator.suiteConfiguration());
        _assertDisputeImport(last.coordinator.suiteConfiguration(), _bundle(p));
    }

    function testPriorEraEconomicsWitnessAndBindingSubstitutionAreRejected() external {
        _baseline();
        _baseConsents();
        _correctAccepted();
        _signedDispute(1, keccak256("prior consent negative"), false);
        _signedDispute(2, keccak256("withdraw before import"), false);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        bytes32 before_ = _rhDestinationHash(next);
        r.records.witnesses[0].economics = new T.EconomicsConsent[](0);
        dv.expectRevert();
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(r);
        require(_rhDestinationHash(next) == before_, "missing original15 cannot partially import");
        (r, p) = _prepare(next);
        r.records.witnesses[0].economics[0].resolver = address(0xBAD);
        dv.expectRevert();
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(r);
        (, Payload.Payload memory local) = Payload.decode(p.data[6].typedState, 6);
        ConsentCodec.Bundle memory c =
            ConsentCodec.decode(p.query, local.provenance, local.semanticState);
        c.original.economics[0].item.association.bindingGeneration = 2;
        dv.expectRevert();
        this.decodeDisputeConsents(
            p.query,
            local.provenance,
            abi.encode(keccak256("6529STREAM_ARTIST_RECOVERED_DISPUTE_CONSENTS_V1"), uint16(1), c)
        );
        (r, p) = _prepare(next);
        _import(next, r, p);
        _assertBaseConsents(next.coordinator.suiteConfiguration());
    }

    function testExactOriginalVetoCausePairCannotBeSubstituted() external {
        _baseline();
        RP.Record memory staged = _stage(keccak256("veto fact negatives"), false);
        bytes32 contest = _veto(staged);
        Successor memory next = _rhCutover();
        (, Commit.Prepared memory p) = _prepare(next);
        D.Bundle memory b = _bundle(p);
        Facts.IdentityRows memory rows = _identityRows(p);
        this.disputeIdentityFacts(rows, b, p.query, p.admission.provenance);
        bytes memory original = abi.encode(rows);
        for (uint256 k; k < 3; ++k) {
            rows = abi.decode(original, (Facts.IdentityRows));
            for (uint256 i; i < rows.causes.length; ++i) {
                if (rows.causes[i].cause.facts.referenceHash == contest) {
                    if (k == 0) {
                        rows.causes[i].cause.facts.evidenceHash = keccak256("foreign repudiation");
                    }
                    if (k == 1) rows.causes[i].point.ownerRevision += 1;
                }
            }
            if (k == 2) {
                for (uint256 i; i < rows.contests.length; ++i) {
                    if (rows.contests[i].record.recordHash == contest) {
                        rows.contests[i].record.contester = address(0xBAD);
                    }
                }
            }
            dv.expectRevert(abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector));
            this.disputeIdentityFacts(rows, b, p.query, p.admission.provenance);
        }
    }

    function testSavedDisputeGrantAndOriginalNonceCannotBeSubstituted() external {
        _baseline();
        bytes32 grant = _grantDispute(2);
        _delegatedDispute(1, grant, 0);
        _delegatedDispute(2, grant, 1);
        Successor memory next = _rhCutover();
        (, Commit.Prepared memory p) = _prepare(next);
        D.Bundle memory b = _bundle(p);
        Facts.IdentityRows memory rows = _identityRows(p);
        uint256[] memory uses = this.disputeIdentityFacts(rows, b, p.query, p.admission.provenance);
        require(uses.length == 1 && uses[0] == 2, "literal combined original dispute uses");
        bytes memory original = abi.encode(rows);
        for (uint256 k; k < 3; ++k) {
            rows = abi.decode(original, (Facts.IdentityRows));
            if (k == 0) rows.delegations[0].recordHash = keccak256("foreign grant");
            if (k == 1) rows.nonces = new IH.NonceLane[](0);
            if (k == 2) rows.signatures = new IH.SignatureRow[](0);
            dv.expectRevert(abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector));
            this.disputeIdentityFacts(rows, b, p.query, p.admission.provenance);
        }
    }

    function _identityRows(Commit.Prepared memory p)
        private
        view
        returns (Facts.IdentityRows memory)
    {
        IH.Bundle memory identity = IdentitySource.collect(
            suite.owners[2], p.query, RH.ownerProvenance(p.admission.provenance, 2)
        );
        return Facts.IdentityRows(
            identity.artistId,
            identity.signatures,
            identity.nonces,
            identity.delegations,
            identity.contests,
            identity.causes,
            identity.guardians
        );
    }

    function disputeIdentityFacts(
        Facts.IdentityRows calldata rows,
        D.Bundle calldata b,
        AH.Query calldata q,
        RH.Provenance calldata p
    ) external pure returns (uint256[] memory) {
        return Facts.validate(rows, b, q, p);
    }

    function testOriginalGovernedAcceptedGenerationCodecBytesRemainIdentical() external {
        _baseline();
        _correctAccepted();
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        (RH.ExportHeader memory h, Payload.Payload memory local) =
            Payload.decode(p.data[4].typedState, 4);
        require(
            (h.requiredFeatures & 8192) == 0 && (h.requiredFeatures & RH.ACCEPTED_GENERATIONS) != 0,
            "original supported profile remains selected"
        );
        CB.Bundle memory b = BindingCodec.collect(
            suite.owners[0], p.query, RH.ownerProvenance(p.admission.provenance, 0)
        );
        A.AttributionBundle memory original =
            AttributionCodec.collect(suite.owners[4], p.query, p.admission.provenance, b);
        require(
            keccak256(local.semanticState)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_RECOVERED_REVOKED_ATTRIBUTION_V1"),
                        uint16(1),
                        original
                    )
                ),
            "literal historical tag and full old tuple"
        );
        _import(next, r, p);
    }

    function testPendingGovernedRevocationRetainsSingleProposalRevisionAndFreshAcceptance()
        external
    {
        _baseline();
        _correctAndPropose(false);
        require(
            !Binding(suite.owners[0]).binding(1).accepted, "genuine unaccepted second generation"
        );
        _correctAndPropose(true);
        _signedDispute(1, keccak256("third generation after pending arbiter cause"), false);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        D.Bundle memory b = _bundle(p);
        require(
            b.generations.length == 3 && !b.generations[1].accepted && b.heads[1].restoreState == 1
                && b.heads[1].revocationReason == 4 && b.heads[2].open,
            "full actual pending disposition, no invented acceptance"
        );
        require(
            p.admission.provenance.journals[0].length == 3
                && p.admission.provenance.journals[3].length == 2
                && p.admission.provenance.journals[0][2].position.point.ownerRevision == 4,
            "literal Binding revisions1,3,4 and only two acceptances"
        );
        _import(next, r, p);
        _assertDisputeImport(next.coordinator.suiteConfiguration(), b);
        T.Binding memory pending =
            Binding(next.coordinator.suiteConfiguration().owners[0]).bindingAt(1, 2);
        require(
            !pending.accepted
                && Acceptance(next.coordinator.suiteConfiguration().owners[3])
                    .acceptanceRecord(pending.bindingHash) == 0,
            "no fabricated op2 map"
        );
        _rhAdopt(next);
        _resolve(1, 1);
        Successor memory last = _rhCutover();
        (r, p) = _prepare(last);
        _import(last, r, p);
        _assertDisputeImport(last.coordinator.suiteConfiguration(), _bundle(p));
    }

    function decodeDisputeConsents(
        AH.Query calldata q,
        RH.OwnerProvenance calldata p,
        bytes calldata raw
    ) external pure {
        ConsentCodec.decode(q, p, raw);
    }

    function decodeDisputeHistory(
        AH.Query calldata q,
        RH.OwnerProvenance calldata p,
        bytes calldata raw
    ) external pure {
        DisputeCodec.decode(q, p, raw);
    }
}
