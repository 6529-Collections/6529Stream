// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistRecoveredSanctionHistoryFixture.sol";

contract StreamArtistRecoveredSanctionHistoryActualTest is ArtistRecoveredSanctionHistoryFixture {
    function testSignedSanctionWithoutConfirmationRetainsAcceptedStateAndOriginalBytes() external {
        _baseline();
        _sanction();
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        SH.AttributionBundle memory b = _sanctionBundle(p);
        require(
            b.original.current.state == 2 && b.history.confirmations.length == 0
                && b.history.sanctions.length == 1,
            "sanction alone never confirms"
        );
        _import(next, r, p);
        _assertSanctionImport(next.coordinator.suiteConfiguration(), b);
    }

    function testExecutedConfirmationRetainsSeparateClocksAndStateThreeAcrossTwoImports() external {
        _baseline();
        _basePolicy();
        _confirm(_sanction());
        Successor memory middle = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(middle);
        SH.AttributionBundle memory b = _sanctionBundle(p);
        require(
            b.original.current.state == 3 && b.history.confirmations.length == 1
                && b.history.confirmations[0].attributionPoint.ownerRevision
                    != b.history.confirmations[0].consentPoint.ownerRevision,
            "genuine original independent clocks"
        );
        bytes32 original = keccak256(abi.encode(b.history.confirmations[0]));
        _import(middle, r, p);
        _assertSanctionImport(middle.coordinator.suiteConfiguration(), b);
        _rhAdopt(middle);
        Successor memory last = _rhCutover();
        (r, p) = _prepare(last);
        b = _sanctionBundle(p);
        require(
            p.admission.provenance.eras.length == 2
                && keccak256(abi.encode(b.history.confirmations[0])) == original,
            "A's immutable confirmation remains A's through B"
        );
        _import(last, r, p);
        _assertSanctionImport(last.coordinator.suiteConfiguration(), b);
    }

    function testConfirmedDisputeWithdrawalRestoresThreeBeforeMigration() external {
        _baseline();
        _confirm(_sanction());
        _signedDispute(1, keccak256("confirmed opening"), false);
        _signedDispute(2, keccak256("confirmed withdrawal"), false);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        SH.AttributionBundle memory b = _sanctionBundle(p);
        require(
            b.original.current.state == 3 && b.original.disputes[0].withdrawal.restoredState == 3,
            "original61 restores confirmed state"
        );
        _import(next, r, p);
        _assertSanctionImport(next.coordinator.suiteConfiguration(), b);
    }

    function testConfirmedLiveDisputeImportsThenOriginalClassOneResolutionRestoresThree() external {
        _baseline();
        _confirm(_sanction());
        _signedDispute(1, keccak256("live confirmed opening"), false);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        SH.AttributionBundle memory b = _sanctionBundle(p);
        require(
            b.original.current.state == 4 && b.original.heads[0].restoreState == 3,
            "live adverse state is retained"
        );
        _import(next, r, p);
        _assertSanctionImport(next.coordinator.suiteConfiguration(), b);
        _rhAdopt(next);
        bytes32 action = _resolve(1, 1);
        require(
            ingress.attributionDisputeResolution(action).restoredState == 3,
            "successor original46 uses retained restore state"
        );
        (uint8 state,) = IStreamArtistAttributionOwner(suite.owners[4]).attributionState(1);
        require(state == 3, "actual successor state3");
    }

    function testEarlierUpheldDisputeRemainsTwoWhenConfirmationComesLater() external {
        _baseline();
        _signedDispute(1, keccak256("pre-confirmation opening"), false);
        _resolve(1, 1);
        _confirm(_sanction());
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        SH.AttributionBundle memory b = _sanctionBundle(p);
        require(
            b.original.resolutions[0].record.restoredState == 2 && b.original.current.state == 3,
            "no retrospective state3 rewrite"
        );
        _import(next, r, p);
        _assertSanctionImport(next.coordinator.suiteConfiguration(), b);
    }

    function testRevokedConfirmedGenerationDoesNotConfirmItsAcceptedCorrection() external {
        _baseline();
        _confirm(_sanction());
        _correctAccepted();
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        SH.AttributionBundle memory b = _sanctionBundle(p);
        require(
            b.original.generations.length == 2 && b.original.current.state == 2
                && b.original.current.generation == 2
                && b.history.confirmations[0].transition.bindingGeneration == 1,
            "exact old confirmed generation, new accepted state2"
        );
        _import(next, r, p);
        _assertSanctionImport(next.coordinator.suiteConfiguration(), b);
    }

    function testCompleteSanctionAssociationHistoryPreservesEarlierConfirmedRecord() external {
        _baseline();
        bytes32 first = _sanction();
        _confirm(first);
        _sanction();
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        SH.AttributionBundle memory b = _sanctionBundle(p);
        require(
            b.history.sanctions.length == 2
                && b.history.confirmations[0].transition.sanctionRecordHash == first,
            "new head cannot replace original confirmed record"
        );
        _import(next, r, p);
        _assertSanctionImport(next.coordinator.suiteConfiguration(), b);
    }

    function testMissingCatalogueOccurrenceRefusesWithoutAnyOwnerWriteThenExactRetry() external {
        _baseline();
        _confirm(_sanction());
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        SH.AttributionBundle memory b = _sanctionBundle(p);
        uint256 index = b.history.confirmations[0].evidence.catalogueIndex;
        (address pointer, bytes32 kind, bytes32 hash) =
            Reconstruction(address(archive)).storedPayloadAt(index);
        bytes memory callData = abi.encodeCall(Reconstruction.storedPayloadAt, (index));
        avm.mockCall(
            address(archive), callData, abi.encode(pointer, keccak256("foreign kind"), hash)
        );
        bytes32 before_ = _rhDestinationHash(next);
        dv.expectRevert();
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(r);
        require(
            _rhDestinationHash(next) == before_, "all owners unchanged after missing confirmation"
        );
        avm.mockCall(address(archive), callData, abi.encode(pointer, kind, hash));
        _import(next, r, p);
        _assertSanctionImport(next.coordinator.suiteConfiguration(), b);
    }

    function testOriginalSanctionSignatureCannotBeSubstitutedByCurrentAuthority() external {
        _baseline();
        bytes32 record = _sanction();
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        SH.AttributionBundle memory b = _sanctionBundle(p);
        bytes memory callData = abi.encodeCall(Identity.signatureBundle, (record));
        avm.mockCall(suite.owners[2], callData, abi.encode(bytes("foreign original signature")));
        bytes32 before_ = _rhDestinationHash(next);
        dv.expectRevert();
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(r);
        require(
            _rhDestinationHash(next) == before_,
            "original signed preimage required before all writes"
        );
        avm.mockCall(suite.owners[2], callData, abi.encode(sanctionSignatures[0]));
        _import(next, r, p);
        _assertSanctionImport(next.coordinator.suiteConfiguration(), b);
    }

    function testConfirmationCannotUseConsentRevisionOrForeignGenerationAtOwnerCodec() external {
        _baseline();
        _basePolicy();
        _confirm(_sanction());
        Successor memory next = _rhCutover();
        (, Commit.Prepared memory p) = _prepare(next);
        SH.AttributionBundle memory b = _sanctionBundle(p);
        (, Payload.Payload memory local) = Payload.decode(p.data[4].typedState, 4);
        SH.AttributionBundle memory bad = abi.decode(abi.encode(b), (SH.AttributionBundle));
        bad.history.confirmations[0].attributionPoint.ownerRevision =
        bad.history.confirmations[0].consentPoint.ownerRevision;
        dv.expectRevert();
        this.checkSanctionAttribution(bad, p.query, local.provenance);
        bad = abi.decode(abi.encode(b), (SH.AttributionBundle));
        bad.history.confirmations[0].transition.bindingGeneration += 1;
        dv.expectRevert();
        this.checkSanctionAttribution(bad, p.query, local.provenance);
        this.checkSanctionAttribution(b, p.query, local.provenance);
    }

    function testMissingSanctionCapabilityAndReplayDoNotSilentlySelectOldCodec() external {
        _baseline();
        _confirm(_sanction());
        Successor memory next = _rhCutover();
        (RH.Request memory r,) = _prepare(next);
        bytes32 before_ = _rhDestinationHash(next);
        r.expectedCapabilities[6].supportedFeatures &= ~uint256(16384);
        dv.expectRevert();
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(r);
        r.expectedCapabilities[6].supportedFeatures |= 16384;
        bool changed;
        for (uint256 i; i < r.records.authority.replayOrigins[6].length; ++i) {
            if (
                r.records.authority.replayOrigins[6][i].surface
                    != keccak256("consent_finality.replay.sanction_finalization_transition_key")
            ) continue;
            r.records.authority.replayOrigins[6][i].scope =
                keccak256("missing original confirmation scope");
            changed = true;
        }
        require(changed, "negative reaches actual original13 cell");
        dv.expectRevert();
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(r);
        require(_rhDestinationHash(next) == before_, "no profile downgrade or partial write");
    }

    function testLateArchiveFailureRollsBackSanctionsConfirmedStateAndSameSafeRequestRetries()
        external
    {
        _baseline();
        _confirm(_sanction());
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _prepare(next);
        SH.AttributionBundle memory b = _sanctionBundle(p);
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
            "all owner roots and Safe nonce roll back"
        );
        T.SuiteConfiguration memory target = next.coordinator.suiteConfiguration();
        (uint8 state,) = IStreamArtistAttributionOwner(target.owners[4]).attributionState(1);
        require(
            state == 0
                && SanctionOwner(target.owners[6]).sanctionRecord(sanctionHashes[0]).recordHash
                    == 0,
            "semantic writes rolled back"
        );
        vm.roll(height);
        require(
            this.rhExecuteNewSafe(address(next.registry), data), "identical saved request retries"
        );
        _assertSanctionImport(target, b);
    }
}
