// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistRecoveredHistoryRecordsFixture.sol";

contract StreamArtistRecoveredHistoryRecordsActualTest is ArtistRecoveredHistoryRecordsFixture {
    function testOriginalPlatformWithout24RetainsItsExactCodecThroughSharedStage() external {
        _baseline();
        _baseConsents();
        _hpClaim(true);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p, HP.Bundle memory b) = _hpPrepare(next);
        (RH.ExportHeader memory header,) = Payload.decode(p.data[4].typedState, 4);
        require(
            (header.requiredFeatures & (uint256(131072) | uint256(128))) == 0,
            "old profile has no new op24 feature or synthetic records"
        );
        _hpImport(next, r, p, b);
    }

    function testHistoryRecordsActualPlatformAndResolvedPersonhoodCredentialHeads() external {
        _hrBaseline();
        _raPrimary(0, 0);
        _raDeployment();
        bytes32 evidence = _raPersonhood(_hrNotarize(0));
        bytes32 first = _raCredential(0, false);
        bytes32 last = _raCredential(first, true);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p, HR.Bundle memory b) = _hrPrepare(next);
        require(
            b.attestations.personhood.length == 1
                && b.attestations.personhood[0].recordHash == evidence,
            "one exact sparse original proof summary"
        );
        _hrImport(next, r, p, b);
        PersonhoodTypes.Selection memory selected = PersonhoodRead(
                next.coordinator.suiteConfiguration().owners[4]
            ).personhoodEvidence(1, artistId);
        require(
            selected.status == PersonhoodTypes.Status.RESOLVED
                && selected.nativeRecord.recordHash == evidence,
            "documentary resolution retained, not inferred legal truth"
        );
        require(
            CredentialRead(next.coordinator.suiteConfiguration().owners[4])
            .c2paCredentialHead(artistId)
            .recordHash == last,
            "explicit credential withdrawal is independent of personhood head"
        );
    }

    function testHistoryRecordsActualEarlierAcceptedGenerationKeepsItsOwnBinding() external {
        _hrBaseline();
        bytes32 first = _raCredential(0, false);
        _raPrimary(0, 0);
        RP.Record memory pending = _stage(keccak256("op24 prior accepted generation"), true);
        _execute(pending);
        _hpContinue(pending.recordHash, true);
        _raCredential(first, true);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p, HR.Bundle memory b) = _hrPrepare(next);
        require(
            b.attestations.records[0].attestation.record.generation == 1
                && b.attestations.records[2].attestation.record.generation == 2
                && b.attestations.records[0].attestation.association.bindingHash
                    != p.query.bindingHash,
            "saved historical association is not current binding"
        );
        _hrImport(next, r, p, b);
    }

    function testHistoryRecordsActualContentFreeze52ConfirmationAndRestore3() external {
        _hrBaseline();
        _raPrimary(0, 0);
        _baseConsents();
        _hcRatify(23, false);
        _hcContent(keccak256("complete24 plus17"), false);
        _hcRoyalty();
        _hcFreeze();
        _confirm(_sanction());
        _signedDispute(1, keccak256("confirmed24 opening"), false);
        _signedDispute(2, keccak256("confirmed24 withdrawal"), false);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p, HR.Bundle memory b) = _hrPrepare(next);
        require(
            b.history.original.current.state == 3 && b.history.sanctions.confirmations.length == 1,
            "independent original owner4/owner6 clocks and restored confirmation"
        );
        _hrImport(next, r, p, b);
    }

    function testHistoryRecordsActualAToBToCNewCredentialRetainsUltimateDomains() external {
        _hrBaseline();
        address originalRegistry = address(ingress);
        bytes32 credential = _raCredential(0, false);
        _raPersonhood(_hrNotarize(0));
        Successor memory middle = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p, HR.Bundle memory b) = _hrPrepare(middle);
        _hrImport(middle, r, p, b);
        bytes32 originalPrefix = keccak256(abi.encode(p.admission.provenance.journals[4]));
        _rhAdopt(middle);
        address middleRegistry = address(ingress);
        bytes32 suffix = _raCredential(credential, true);
        _hpClaim(true);
        Successor memory last = _rhCutover();
        (r, p, b) = _hrPrepare(last);
        require(
            p.admission.provenance.eras.length == 2
                && b.attestations.records[0].attestation.record.recordHash == credential
                && b.attestations.personhood[0].originalRegistry == originalRegistry
                && b.attestations.personhood[0].summary.evidenceReference.artistRegistry
                    == originalRegistry && raRows[0].registry == originalRegistry
                && raRows[2].registry == middleRegistry
                && b.attestations.records[2].attestation.record.recordHash == suffix
                && originalRegistry != middleRegistry,
            "original documentary and native domains remain explicit"
        );
        require(
            originalPrefix != keccak256(abi.encode(p.admission.provenance.journals[4])),
            "actual new suffix included"
        );
        _hrImport(last, r, p, b);
    }

    function testHistoryRecordsMissingDuplicateWitnessRefusesBeforeAnyImport() external {
        _hrBaseline();
        _raPrimary(0, 0);
        _raDeployment();
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p, HR.Bundle memory b) = _hrPrepare(next);
        RH.Request memory bad = abi.decode(abi.encode(r), (RH.Request));
        bad.records.witnesses[0].attestations = new Ready.AttestationInput[](0);
        bytes32 before_ = _rhDestinationHash(next);
        dv.expectRevert();
        Prepared.prepare(next.coordinator.suiteConfiguration(), bad, _hcRoyalties());
        bad = abi.decode(abi.encode(r), (RH.Request));
        bad.records.witnesses[0].attestations[1] = bad.records.witnesses[0].attestations[0];
        dv.expectRevert();
        Prepared.prepare(next.coordinator.suiteConfiguration(), bad, _hcRoyalties());
        require(_rhDestinationHash(next) == before_, "no partial target state");
        _hrImport(next, r, p, b);
    }

    function testHistoryRecordsCannotRelabelEarlierRecordToLaterAcceptedGeneration() external {
        _hrBaseline();
        _raPrimary(0, 0);
        RP.Record memory pending = _stage(keccak256("real prior binding revocation"), true);
        _execute(pending);
        _hpContinue(pending.recordHash, true);
        _raPrimary(0, 0);
        Successor memory next = _rhCutover();
        (, Commit.Prepared memory p, HR.Bundle memory b) = _hrPrepare(next);
        HR.Bundle memory bad = abi.decode(abi.encode(b), (HR.Bundle));
        bad.attestations.records[0].attestation.record.generation = 2;
        bad.attestations.records[0].attestation.association.generation = 2;
        bad.attestations.records[0].attestation.association.bindingHash = p.query.bindingHash;
        // Original record hash omits generation: independently reconstructed owner4 clocks must refuse.
        require(
            bad.attestations.records[0].attestation.record.recordHash
                == b.attestations.records[0].attestation.record.recordHash,
            "hash preserved while out-of-hash generation is attacked"
        );
        _hrBad(p, bad);
        _hrGood(p, b);
    }

    function testHistoryRecordsWrongPersonhoodOriginalRegistryCannotReplaceOriginalDomain()
        external
    {
        _hrBaseline();
        _raPersonhood(_hrNotarize(0));
        Successor memory next = _rhCutover();
        (, Commit.Prepared memory p, HR.Bundle memory b) = _hrPrepare(next);
        HR.Bundle memory bad = abi.decode(abi.encode(b), (HR.Bundle));
        bad.attestations.personhood[0].originalRegistry = address(0xBAD);
        _hrBad(p, bad);
        _hrGood(p, b);
    }

    function testHistoryRecordsSourceCredentialHeadMismatchRefusesThenExactRestore() external {
        _hrBaseline();
        bytes32 hash = _raCredential(0, false);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p, HR.Bundle memory b) = _hrPrepare(next);
        C2PA.Head memory original = CredentialRead(suite.owners[4]).c2paCredentialRecord(hash);
        C2PA.Head memory bad = abi.decode(abi.encode(original), (C2PA.Head));
        bad.bindingHash = keccak256("foreign credential binding");
        bytes memory call_ = abi.encodeCall(CredentialRead.c2paCredentialRecord, (hash));
        avm.mockCall(suite.owners[4], call_, abi.encode(bad));
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Prepared.prepare(next.coordinator.suiteConfiguration(), r, _hcRoyalties());
        avm.mockCall(suite.owners[4], call_, abi.encode(original));
        _hrImport(next, r, p, b);
    }

    function testHistoryRecordsActualRevokedUnderLimitGrantRefusesNewOp24ThenFreshGrantWorks()
        external
    {
        _historyUnavailableGrant(true);
    }

    function testHistoryRecordsActualExhaustedUnrevokedGrantRefusesNewOp24ThenFreshGrantWorks()
        external
    {
        _historyUnavailableGrant(false);
    }

    function _historyUnavailableGrant(bool revoked) private {
        _hrBaseline();
        Delegate.Grant memory grant = _delegation(
            1,
            Delegate.ATTEST | Delegate.DISPUTE | Delegate.ROYALTY_FREEZE,
            uint64(block.timestamp),
            uint64(block.timestamp + 365 days),
            revoked ? 4 : 3
        );
        T.Authorization memory a = T.Authorization(nextNonce, 0, "");
        bytes32 digest = ingress.delegationGrantDigest(grant, a);
        bytes32 record = _grant(grant);
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(2, "identity_authority.replay.delegation_key", record);
        _raPrimary(record, 401);
        _hcDelegatedRoyalty(record, 402);
        _delegatedDispute(1, record, 403);
        if (revoked) _revokeDisputeGrant(record);
        require(
            ingress.delegationRecord(record).uses == 3
                && ingress.delegationRecord(record).revoked == revoked
                && ingress.delegationRecord(record).grant.maxUses == (revoked ? 4 : 3),
            "actual exact cross-family use total with independently isolated unavailability cause"
        );
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p, HR.Bundle memory b) = _hrPrepare(next);
        _hrImport(next, r, p, b);
        _rhAdopt(next);
        require(
            ingress.delegationRecord(record).uses == 3
                && ingress.delegationRecord(record).revoked == revoked
                && ingress.delegationRecord(record).grant.maxUses == (revoked ? 4 : 3),
            "import retains the exact independent unavailability cause"
        );
        (T.Attestation memory terms, bytes memory statement) = _raPrimaryTerms();
        T.Authorization memory auth = T.Authorization(404, uint64(block.timestamp), "");
        bytes32 freshDigest = ingress.attestationDigest(terms, auth);
        auth.signature = _delegateSignature(freshDigest);
        bytes32 before_ = _hrSourceHash();
        (bool used, uint256 hint) =
            ingress.delegatedNonceState(artistId, address(delegateSafe), auth.nonce);
        require(!used, "fresh successor nonce before refusal");
        dv.recordLogs();
        (bool ok, bytes memory reason) = address(ingress)
            .call(
                abi.encodeCall(
                    StreamArtistOnboardingRegistry.recordDelegatedArtistAttestation,
                    (terms, record, auth, statement)
                )
            );
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(Delegate.DelegationUnavailable.selector, record)
                    ),
            "original authorization refuses the exact imported unavailable grant"
        );
        (bool usedAfter, uint256 hintAfter) =
            ingress.delegatedNonceState(artistId, address(delegateSafe), auth.nonce);
        require(
            _hrSourceHash() == before_ && !usedAfter && hintAfter == hint,
            "failed live authorization rolls back owners, digest observation, nonce and Archive"
        );
        DisputeHistoryVm.Log[] memory logs = dv.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            require(logs[i].emitter != suite.archive, "no Archive append on refusal");
        }
        Delegate.Grant memory fresh = _delegation(
            1, Delegate.ATTEST, uint64(block.timestamp), uint64(block.timestamp + 365 days), 1
        );
        bytes32 replacement = _grant(fresh);
        require(replacement != record, "fresh successor grant is a new immutable record");
        bytes32 newRecord = _raRecord(terms, statement, replacement, auth.nonce);
        require(
            ingress.attestationAssociation(newRecord).delegation == replacement
                && ingress.delegationRecord(replacement).uses == 1
                && ingress.delegationRecord(record).uses == 3
                && ingress.delegationRecord(record).revoked == revoked,
            "same failed nonce works under fresh authority; old grant keeps its distinct unavailability cause"
        );
    }

    function testHistoryRecordsMalformedOuterTagAndTrailingBytesRefuse() external {
        _hrBaseline();
        _raPrimary(0, 0);
        Successor memory next = _rhCutover();
        (, Commit.Prepared memory p, HR.Bundle memory b) = _hrPrepare(next);
        bytes memory raw = HRParts.encode(b);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        this.hrValidate(
            p.query, RH.ownerProvenance(p.admission.provenance, 4), bytes.concat(raw, bytes32(0))
        );
        bytes[5] memory members = HRParts.members(raw);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        this.hrValidate(
            p.query,
            RH.ownerProvenance(p.admission.provenance, 4),
            abi.encode(HP.ATTRIBUTION, uint16(1), members)
        );
        _hrGood(p, b);
    }

    function testHistoryRecordsMissingExplicitCapabilityAndForeignNonceWitnessRefuse() external {
        _hrBaseline();
        _raPrimary(0, 0);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p, HR.Bundle memory b) = _hrPrepare(next);
        RH.Request memory bad = abi.decode(abi.encode(r), (RH.Request));
        bad.expectedCapabilities[4].supportedFeatures &= ~uint256(131072);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Prepared.prepare(next.coordinator.suiteConfiguration(), bad, _hcRoyalties());
        bad = abi.decode(abi.encode(r), (RH.Request));
        ++bad.records.witnesses[0].attestations[0].nonce;
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Prepared.prepare(next.coordinator.suiteConfiguration(), bad, _hcRoyalties());
        _hrImport(next, r, p, b);
    }

    function testHistoryRecordsNative24CannotUseZeroArtistPlatformException() external {
        _hrBaseline();
        _raPrimary(0, 0);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p, HR.Bundle memory b) = _hrPrepare(next);
        uint256 index = Native(suite.owners[4]).artistNativeReceiptCount() - 1;
        HT.Receipt memory original = Native(suite.owners[4]).artistNativeReceiptAt(index);
        require(original.operation == 24 && original.artistId == artistId, "actual original24");
        HT.Receipt memory bad = abi.decode(abi.encode(original), (HT.Receipt));
        bad.artistId = 0;
        bytes memory call_ = abi.encodeCall(Native.artistNativeReceiptAt, (index));
        avm.mockCall(suite.owners[4], call_, abi.encode(bad));
        dv.expectRevert();
        Prepared.prepare(next.coordinator.suiteConfiguration(), r, _hcRoyalties());
        avm.mockCall(suite.owners[4], call_, abi.encode(original));
        _hrImport(next, r, p, b);
    }

    function testHistoryRecordsLateArchiveAllSevenAndSummaryRollbackExactSafeRetry() external {
        _hrBaseline();
        bytes32 evidence = _raPersonhood(_hrNotarize(0));
        _raCredential(0, false);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p, HR.Bundle memory b) = _hrPrepare(next);
        bytes memory call_ = _hcCall(r);
        bytes memory append = _firstPage(next, r, p);
        uint256 originalBlock = block.number;
        uint256 nonce = rotationSafe.nonce();
        bytes32 before_ = _rhDestinationHash(next);
        bytes32 sourceBefore = _hrSourceHash();
        dv.expectCall(address(next.archive), append, 2);
        vm.roll(uint256(type(uint64).max) + 1);
        (bool ok,) = address(this)
            .call(abi.encodeCall(this.rhExecuteNewSafe, (address(next.registry), call_)));
        require(
            !ok && rotationSafe.nonce() == nonce && _rhDestinationHash(next) == before_
                && _hrSourceHash() == sourceBefore,
            "late Archive restores every owner/source/Safe state"
        );
        address owner = next.coordinator.suiteConfiguration().owners[4];
        require(
            PersonhoodRead(owner).personhoodProofSummaryHash(evidence) == 0
                && CredentialRead(owner).c2paCredentialHead(artistId).recordHash == 0,
            "new summary and derived credential writes rollback too"
        );
        vm.roll(originalBlock);
        require(
            this.rhExecuteNewSafe(address(next.registry), call_), "identical saved Safe bytes retry"
        );
        require(rotationSafe.nonce() == nonce + 1, "one committed Safe transaction");
        _rhImported(next, p, HydrationOwner(next.identity).authorityHydrationCommitment());
        _hpAssert(next.coordinator.suiteConfiguration(), b.history);
        _raAssert(next.coordinator.suiteConfiguration(), raRows.length);
    }
}

contract StreamArtistRecoveredHistoryRecordsNoPlatformTest is ArtistRecoveredHistoryRecordsFixture {
    function _beforeInitialBindingProposal() internal override { }

    function testHistoryRecordsActualDisputeAnd24KeepCanonicalAbsentPlatform() external {
        _hrBaseline();
        _raPrimary(0, 0);
        _signedDispute(1, keccak256("no Platform declaration, real dispute"), false);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p, HR.Bundle memory b) = _hrPrepare(next);
        (RH.ExportHeader memory h,) = Payload.decode(p.data[4].typedState, 4);
        require(
            (h.requiredFeatures & 65536) == 0
                && b.history.platform.state.declaration.recordHash == 0
                && b.history.platform.continuations.length == 0,
            "no synthetic Platform capability or lineage"
        );
        _hrImport(next, r, p, b);
    }
}
