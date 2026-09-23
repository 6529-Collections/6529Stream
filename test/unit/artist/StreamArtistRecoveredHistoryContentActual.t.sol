// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistRecoveredHistoryContentFixture.sol";

contract StreamArtistRecoveredHistoryContentActualTest is ArtistRecoveredHistoryContentFixture {
    function testForeignSavedRoyaltyGrantCannotHideAnOriginalUseThenExactRetry() external {
        _baseline();
        bytes32 grant = _hcGrant(3);
        _delegatedDispute(1, grant, 0);
        _delegatedDispute(2, grant, 1);
        bytes32 record = _hcDelegatedRoyalty(grant, 2);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _hcPrepare(next);
        bytes memory call_ = abi.encodeCall(Delegated.recordDelegation, (record));
        bytes32 before_ = _rhDestinationHash(next);
        avm.mockCall(suite.owners[6], call_, abi.encode(keccak256("foreign historical grant")));
        dv.expectRevert();
        Prepared.prepare(next.coordinator.suiteConfiguration(), r, _hcRoyalties());
        avm.mockCall(suite.owners[6], call_, abi.encode(bytes32(0)));
        dv.expectRevert();
        Prepared.prepare(next.coordinator.suiteConfiguration(), r, _hcRoyalties());
        require(_rhDestinationHash(next) == before_, "neither foreign grant nor missing use writes");
        avm.mockCall(suite.owners[6], call_, abi.encode(grant));
        _hcImport(next, r, p);
    }

    function testSameHistoricalGrantConservesDisputeAndRoyaltyUsesAcrossImport() external {
        _baseline();
        bytes32 grant = _hcGrant(3);
        _delegatedDispute(1, grant, 0);
        _delegatedDispute(2, grant, 1);
        bytes32 royaltyRecord = _hcDelegatedRoyalty(grant, 2);
        require(
            ingress.delegationRecord(grant).uses == 3, "two original dispute uses plus one royalty"
        );
        _hcRatify(19, false);
        _revokeDisputeGrant(grant);
        Delegate.Record memory saved = ingress.delegationRecord(grant);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _hcPrepare(next);
        HC.Bundle memory b = _hcBundle(p);
        require(
            b.royalties.length == 1 && b.royalties[0].grant == grant,
            "exact historical grant association"
        );
        _hcImport(next, r, p);
        T.SuiteConfiguration memory target = next.coordinator.suiteConfiguration();
        require(
            keccak256(abi.encode(ingress.delegationRecord(grant))) == keccak256(abi.encode(saved)),
            "source grant unchanged"
        );
        require(
            Delegated(target.owners[6]).recordDelegation(royaltyRecord) == grant,
            "destination keeps historical grant"
        );
        _rhAdopt(next);
        require(
            keccak256(abi.encode(ingress.delegationRecord(grant))) == keccak256(abi.encode(saved)),
            "uses and revoked/exhausted state imported"
        );
        _correctAccepted(); // Creates a genuinely unused royalty scope for the successor refusal.
        T.RoyaltyFreeze memory terms = _freezePayload();
        T.Authorization memory auth = T.Authorization(3, uint64(block.timestamp + 1 days), "");
        auth.signature = _delegateSignature(ingress.royaltyFreezeDigest(terms, auth));
        bytes32 before_ = _rhDestinationHash(next);
        (bool usedBefore, uint256 hintBefore) =
            ingress.delegatedNonceState(artistId, address(delegateSafe), 3);
        uint256 archiveBefore = Reconstruction(suite.archive).storedPayloadCount();
        dv.expectRevert(abi.encodeWithSelector(Delegate.DelegationUnavailable.selector, grant));
        ingress.authorizeDelegatedRoyaltyFreeze(terms, grant, auth);
        (bool usedAfter, uint256 hintAfter) =
            ingress.delegatedNonceState(artistId, address(delegateSafe), 3);
        require(
            _rhDestinationHash(next) == before_ && usedBefore == usedAfter
                && hintBefore == hintAfter
                && Reconstruction(suite.archive).storedPayloadCount() == archiveBefore,
            "exact original refusal rolls back all effects"
        );
        bytes32 fresh = _hcGrant(2);
        _hcDelegatedRoyalty(fresh, 3);
        require(
            ingress.delegationRecord(fresh).uses == 1
                && keccak256(abi.encode(ingress.delegationRecord(grant)))
                    == keccak256(abi.encode(saved)),
            "same failed nonce fresh original authority works"
        );
    }

    function testMissingEmptyDirectRatificationSignatureRowRefusesIndependentFacts() external {
        _baseline();
        _hcRatify(20, true);
        _confirm(_sanction());
        Successor memory next = _rhCutover();
        (, Commit.Prepared memory p) = _hcPrepare(next);
        HC.Bundle memory b = _hcBundle(p);
        (, Payload.Payload memory ip) = Payload.decode(p.data[2].typedState, 2);
        IH.Bundle memory identity = IdentitySource.decode(ip.semanticState, ip.provenance);
        HCFacts.IdentityRows memory rows =
            HCFacts.IdentityRows(identity.artistId, identity.signatures, identity.delegations);
        HCFacts.validate(rows, b, p.admission.provenance);
        uint256 at = type(uint256).max;
        for (uint256 i; i < rows.signatures.length; ++i) {
            if (rows.signatures[i].recordHash == retained[0].recordHash) at = i;
        }
        require(
            at != type(uint256).max && rows.signatures[at].signature.length == 0,
            "exact real direct-empty row"
        );
        IH.SignatureRow[] memory original = rows.signatures;
        rows.signatures = new IH.SignatureRow[](original.length - 1);
        for (uint256 i; i < rows.signatures.length; ++i) {
            rows.signatures[i] = original[i < at ? i : i + 1];
        }
        dv.expectRevert();
        HCFacts.validate(rows, b, p.admission.provenance);
        rows.signatures = original;
        HCFacts.validate(rows, b, p.admission.provenance);
    }

    function testCompletePriorAndAcceptedGenerationContentFreezeRatificationAndConfirmation()
        external
    {
        _baseline();
        _baseConsents();
        _hcContent(keccak256("same content target"), false);
        _hcFreeze();
        _hcRoyalty();
        _hcRatify(1, false);
        _confirm(_sanction());
        _correctAccepted();
        _hcContent(keccak256("same content target"), true);
        _hcFreeze();
        _hcRoyalty();
        _hcRatify(2, true);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _hcPrepare(next);
        HC.Bundle memory b = _hcBundle(p);
        require(
            b.base.bindings.length == 2 && b.consents.length == 2 && b.royalties.length == 2
                && b.freezes.length == 2 && b.ratifications.length == 2,
            "all original owner6 families"
        );
        require(
            b.consents[0].bindingGeneration == 1 && b.consents[1].bindingGeneration == 2
                && b.royalties[0].item.bindingGeneration == 1
                && b.royalties[1].item.bindingGeneration == 2,
            "original attested generations, no current substitution"
        );
        require(
            b.sanctions.confirmations.length == 1
                && b.sanctions.confirmations[0].transition.bindingGeneration == 1,
            "exact earlier confirmation"
        );
        _hcImport(next, r, p);
        _assertBaseConsents(next.coordinator.suiteConfiguration());
        (, Payload.Payload memory ap) = Payload.decode(p.data[4].typedState, 4);
        SH.AttributionBundle memory ab =
            SanctionCodec.decode(p.query, ap.provenance, ap.semanticState);
        _assertSanctionImport(next.coordinator.suiteConfiguration(), ab);
    }

    function testRatificationOnlyCompositionDoesNotInventContentFeatureOrGeneration() external {
        _baseline();
        _hcRatify(3, false);
        _confirm(_sanction());
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _hcPrepare(next);
        HC.Bundle memory b = _hcBundle(p);
        require(!HC.hasContent(b) && b.ratifications.length == 1, "52 without content rows");
        (RH.ExportHeader memory h,) = Payload.decode(p.data[6].typedState, 6);
        require(
            (h.requiredFeatures & 256) == 0 && (h.requiredFeatures & 1024) != 0,
            "no false content capability"
        );
        _hcImport(next, r, p);
    }

    function testRepeatedAtoBtoCContentAndSignedEmptyRatificationEvidence() external {
        _baseline();
        _hcContent(keccak256("A content"), false);
        _hcRatify(4, false);
        _signedDispute(1, keccak256("A signed opening"), false);
        _signedDispute(2, keccak256("A signed withdrawal"), false);
        Successor memory middle = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _hcPrepare(middle);
        HC.Bundle memory first = _hcBundle(p);
        bytes32 original = keccak256(abi.encode(first.consents[0], first.ratifications[0]));
        _hcImport(middle, r, p);
        _rhAdopt(middle);
        _hcContent(keccak256("B content"), true);
        _hcRatify(5, true);
        Successor memory last = _rhCutover();
        (r, p) = _hcPrepare(last);
        HC.Bundle memory full = _hcBundle(p);
        require(
            p.admission.provenance.eras.length == 2 && full.consents.length == 2
                && full.ratifications.length == 2
                && keccak256(abi.encode(full.consents[0], full.ratifications[0])) == original,
            "original A domain/body retained through B"
        );
        _hcImport(last, r, p);
    }

    function testContentImportKeepsGenuineOpenDisputeThenSuccessorResolvesOriginalHead() external {
        _baseline();
        _hcContent(keccak256("before adverse state"), false);
        _hcFreeze();
        _signedDispute(1, keccak256("genuine open"), false);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _hcPrepare(next);
        _hcBundle(p);
        _hcImport(next, r, p);
        (uint8 state,) = IStreamArtistAttributionOwner(
                next.coordinator.suiteConfiguration().owners[4]
            ).attributionState(1);
        require(state == 4, "no promotion of disputed current state");
        _rhAdopt(next);
        _resolve(1, 1);
        (state,) = IStreamArtistAttributionOwner(suite.owners[4]).attributionState(1);
        require(state == 2, "original governed resolution after import");
    }

    function testCompleteRoyaltyWitnessesMissingExtraAndForeignRefuseBeforeWrites() external {
        _baseline();
        _hcRoyalty();
        _correctAccepted();
        _hcRoyalty();
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _hcPrepare(next);
        bytes32 before_ = _rhDestinationHash(next);
        T.RoyaltyFreeze[] memory exact = _hcRoyalties();
        T.RoyaltyFreeze[] memory bad = new T.RoyaltyFreeze[](1);
        bad[0] = exact[0];
        dv.expectRevert();
        Prepared.prepare(next.coordinator.suiteConfiguration(), r, bad);
        bad = new T.RoyaltyFreeze[](3);
        bad[0] = exact[0];
        bad[1] = exact[1];
        bad[2] = exact[1];
        dv.expectRevert();
        Prepared.prepare(next.coordinator.suiteConfiguration(), r, bad);
        bad = abi.decode(abi.encode(exact), (T.RoyaltyFreeze[]));
        bad[1].expectedAssignmentHash = keccak256("foreign original assignment");
        dv.expectRevert();
        Prepared.prepare(next.coordinator.suiteConfiguration(), r, bad);
        require(_rhDestinationHash(next) == before_, "no partial owner writes");
        _hcImport(next, r, p);
    }

    function testHistoricalGenerationAndIndependentConfirmationClockCannotBeRewritten() external {
        _baseline();
        _hcContent(keccak256("prior"), false);
        _hcRatify(6, false);
        _confirm(_sanction());
        _correctAccepted();
        Successor memory next = _rhCutover();
        (, Commit.Prepared memory p) = _hcPrepare(next);
        HC.Bundle memory original = _hcBundle(p);
        (, Payload.Payload memory local) = Payload.decode(p.data[6].typedState, 6);
        HC.Bundle memory bad = abi.decode(abi.encode(original), (HC.Bundle));
        bad.consents[0].bindingGeneration = 2;
        dv.expectRevert();
        this.checkHistoryContent(p.query, local.provenance, abi.encode(HC.SCHEMA, uint16(1), bad));
        bad = abi.decode(abi.encode(original), (HC.Bundle));
        bad.sanctions.confirmations[0].consentPoint.ownerRevision =
        bad.sanctions.confirmations[0].attributionPoint.ownerRevision;
        require(
            bad.sanctions.confirmations[0].consentPoint.ownerRevision
                != original.sanctions.confirmations[0].consentPoint.ownerRevision,
            "independent clocks negative"
        );
        dv.expectRevert();
        this.checkHistoryContent(p.query, local.provenance, abi.encode(HC.SCHEMA, uint16(1), bad));
        this.checkHistoryContent(p.query, local.provenance, local.semanticState);
    }

    function testWrongTagAndMissingOriginalContentReplayCannotDowngradeToOldHistory() external {
        _baseline();
        _hcContent(keccak256("complete scope"), false);
        _correctAccepted();
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _hcPrepare(next);
        HC.Bundle memory b = _hcBundle(p);
        (, Payload.Payload memory local) = Payload.decode(p.data[6].typedState, 6);
        dv.expectRevert();
        this.checkHistoryContent(
            p.query,
            local.provenance,
            abi.encode(keccak256("6529STREAM_ARTIST_RECOVERED_SANCTION_CONSENT_V1"), uint16(1), b)
        );
        r.expectedCapabilities[6].supportedFeatures &= ~uint256(32768);
        dv.expectRevert();
        Prepared.prepare(next.coordinator.suiteConfiguration(), r, _hcRoyalties());
        r.expectedCapabilities[6].supportedFeatures |= 32768;
        bool changed;
        for (uint256 i; i < r.records.authority.replayOrigins[6].length; ++i) {
            if (
                r.records.authority.replayOrigins[6][i].surface
                    != keccak256("consent_finality.replay.content_consent_key")
            ) continue;
            r.records.authority.replayOrigins[6][i].scope = keccak256("missing original17");
            changed = true;
        }
        require(changed, "actual source cell targeted");
        dv.expectRevert();
        Prepared.prepare(next.coordinator.suiteConfiguration(), r, _hcRoyalties());
    }

    function testHeadDriftRefusesThenSameRequestAndOriginalHeadRetry() external {
        _baseline();
        _hcContent(keccak256("same"), false);
        _hcContent(keccak256("same"), false);
        _correctAccepted();
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _hcPrepare(next);
        HC.Bundle memory b = _hcBundle(p);
        bytes memory call_ =
            abi.encodeCall(ContentOwner.contentConsentAt, (b.consents[0].terms, uint64(1)));
        avm.mockCall(suite.owners[6], call_, abi.encode(b.consents[0]));
        bytes32 before_ = _rhDestinationHash(next);
        dv.expectRevert();
        WithConsents(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(r, _hcRoyalties());
        require(_rhDestinationHash(next) == before_, "source drift before import");
        avm.mockCall(suite.owners[6], call_, abi.encode(b.consents[1]));
        _hcImport(next, r, p);
    }

    function testLateArchiveFailureRollsBackAllNewMapsThenIdenticalSafeBytesRetry() external {
        _baseline();
        _hcContent(keccak256("all maps rollback"), false);
        _hcFreeze();
        _hcRoyalty();
        _hcRatify(7, true);
        _confirm(_sanction());
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _hcPrepare(next);
        bytes memory data = _hcCall(r);
        dv.expectCall(next.coordinator.suiteConfiguration().archive, _firstPage(next, r, p), 2);
        bytes32 before_ = _rhDestinationHash(next);
        uint256 nonce = rotationSafe.nonce();
        uint256 height = block.number;
        vm.roll(uint256(type(uint64).max) + 1);
        dv.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(address(next.registry), data);
        require(
            _rhDestinationHash(next) == before_ && rotationSafe.nonce() == nonce,
            "all seven roots and Safe rollback"
        );
        address target = next.coordinator.suiteConfiguration().owners[6];
        require(
            ContentOwner(target).contentConsentRecord(contentRows[0].record).recordHash == 0
                && ContentOwner(target).contentFreezeRecord(contentRows[1].record).recordHash == 0
                && Consent(target)
                .royaltyFreezeRecord(contentRows[2].royalty, artistId, 1)
                .recordHash == 0
                && Consent(target).ratificationRecord(retained[0].recordHash).recordHash == 0,
            "all new semantic maps rolled back"
        );
        vm.roll(height);
        require(
            this.rhExecuteNewSafe(address(next.registry), data), "same frozen Safe data succeeds"
        );
        require(rotationSafe.nonce() == nonce + 1, "exactly one successful Safe");
        _hcAssert(next.coordinator.suiteConfiguration());
    }

    function testEarlierNoContentSanctionCodecRemainsByteExact() external {
        _baseline();
        _confirm(_sanction());
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        (RH.ExportHeader memory h,) = Payload.decode(p.data[6].typedState, 6);
        require((h.requiredFeatures & 32768) == 0, "old profile remains selected");
        SH.AttributionBundle memory b = _sanctionBundle(p);
        _import(next, r, p);
        _assertSanctionImport(next.coordinator.suiteConfiguration(), b);
    }
}
