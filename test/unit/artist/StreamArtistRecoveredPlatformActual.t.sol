// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistRecoveredPlatformFixture.sol";

contract StreamArtistRecoveredPlatformActualTest is ArtistRecoveredPlatformFixture {
    function testPlatformHistoryActualFirstCorrectionRetainsCollectionOnlyRowsAndOriginalState()
        external
    {
        _baseline();
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p, HP.Bundle memory b) = _hpPrepare(next);
        require(
            b.platform.state.correction.correctiveGeneration == 1
                && b.platform.state.correction.accepted && b.platform.continuations.length == 0,
            "original consumed generation and acceptance"
        );
        _hpImport(next, r, p, b);
    }

    function testPlatformHistoryActualRefusedOriginalCorrectionThenAcceptedContinuation() external {
        _hpPendingTerminal(false);
        _baseline();
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p, HP.Bundle memory b) = _hpPrepare(next);
        require(
            !b.platform.state.correction.accepted
                && b.platform.state.correction.correctiveGeneration == 1
                && b.platform.status.effectiveAccepted && b.platform.continuations.length == 1
                && b.platform.continuations[0].record.previousGeneration == 1
                && b.platform.continuations[0].record.generation == 2,
            "append-only continuation does not rewrite refused original correction"
        );
        _hpImport(next, r, p, b);
    }

    function testPlatformHistoryActualWithdrawnOriginalCorrectionThenAcceptedContinuation()
        external
    {
        _hpPendingTerminal(true);
        _baseline();
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p, HP.Bundle memory b) = _hpPrepare(next);
        require(
            b.bindings.bindings.rows[0].terminal.kind == 2 && !b.platform.state.correction.accepted
                && b.platform.status.effectiveAccepted,
            "withdrawal cause retained with later effective acceptance"
        );
        _hpImport(next, r, p, b);
    }

    function testPlatformHistoryActualAcceptedThenExecutedRepudiationAndFreshContinuation()
        external
    {
        _baseline();
        RP.Record memory pending = _stage(keccak256("Platform original accepted repudiation"), true);
        _execute(pending);
        _hpContinue(pending.recordHash, true);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p, HP.Bundle memory b) = _hpPrepare(next);
        require(
            b.platform.state.correction.accepted
                && b.platform.state.correction.correctiveGeneration == 1
                && b.platform.continuations[0].record.previousBindingHash
                    == b.bindings.bindings.rows[0].item.bindingHash
                && b.bindings.corrections[1].approval.causeRecord == pending.recordHash,
            "full original repudiation cause and fresh approval"
        );
        _hpImport(next, r, p, b);
    }

    function testPlatformHistoryActualMixedDisplayHeadsAndRepeatedAToBToC() external {
        _baseline();
        _hpClaim(true);
        _hpClaim(false);
        bytes32 latest = _hpClaim(true);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p, HP.Bundle memory b) = _hpPrepare(next);
        require(
            b.platform.latestDisplayClaim == latest && b.platform.allegationCount == 2,
            "original9/10 ordering"
        );
        _hpImport(next, r, p, b);
        bytes32 originalPW = keccak256(abi.encode(b.platform.state));
        _rhAdopt(next);
        bytes32 fresh = _hpClaim(true);
        Successor memory third = _rhCutover();
        (r, p, b) = _hpPrepare(third);
        require(
            b.platform.latestDisplayClaim == fresh && b.platform.catalogues.length == 2
                && keccak256(abi.encode(b.platform.state)) == originalPW,
            "flattened original history plus actual new native suffix"
        );
        _hpImport(third, r, p, b);
    }

    function testPlatformHistoryActualContentFreezeRatificationAndConfirmedDisputeCompose()
        external
    {
        _baseline();
        _hcRatify(19, false);
        _hcContent(keccak256("Platform content consent"), false);
        _hcFreeze();
        _hcRoyalty();
        bytes32 sanction = _sanction();
        _confirm(sanction);
        _signedDispute(1, keccak256("Platform confirmed opening"), false);
        _signedDispute(2, keccak256("Platform confirmed withdrawal"), false);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p, HP.Bundle memory b) = _hpPrepare(next);
        require(
            b.original.current.state == 3 && b.sanctions.confirmations.length == 1,
            "original independent confirmation clock and restore3"
        );
        _hpImport(next, r, p, b);
    }

    function testPlatformHistoryMissingArchiveOperationCannotHideConsumedCorrection() external {
        _baseline();
        Successor memory next = _rhCutover();
        (, Commit.Prepared memory p, HP.Bundle memory b) = _hpPrepare(next);
        HP.Bundle memory bad = abi.decode(abi.encode(b), (HP.Bundle));
        bad.platform.operations = new SH.OperationEvidence[](0);
        _hpRefuses(p, bad);
        _hpValidates(p, b);
    }

    function testPlatformHistoryWrongArchivedClaimFieldOutsideOriginalHashRefuses() external {
        _baseline();
        Successor memory next = _rhCutover();
        (, Commit.Prepared memory p, HP.Bundle memory b) = _hpPrepare(next);
        HP.Bundle memory bad = abi.decode(abi.encode(b), (HP.Bundle));
        bad.platform.claims[0].record.proposedArtist = address(0xBAD);
        _hpRefuses(p, bad);
        _hpValidates(p, b);
    }

    function testPlatformHistoryWrappedContinuationCauseCannotBeSubstituted() external {
        _hpPendingTerminal(false);
        _baseline();
        Successor memory next = _rhCutover();
        (, Commit.Prepared memory p, HP.Bundle memory b) = _hpPrepare(next);
        HP.Bundle memory bad = abi.decode(abi.encode(b), (HP.Bundle));
        bad.bindings.corrections[1].approval.causeData =
            abi.encode("foreign wrapped original cause");
        _hpRefuses(p, bad);
        _hpValidates(p, b);
    }

    function testPlatformHistoryImportedClaimSubjectCannotReplayAndFreshClaimStillWorks() external {
        _baseline();
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p, HP.Bundle memory b) = _hpPrepare(next);
        PW.Claim memory old = b.platform.claims[0].record;
        _hpImport(next, r, p, b);
        _rhAdopt(next);
        bytes32 before_ = _hpSourceHash();
        uint256 count = Reconstruction(suite.archive).storedPayloadCount();
        dv.expectRevert(abi.encodeWithSelector(PW.InvalidPlatformWorks.selector, uint256(1)));
        ingress.filePlatformWorksClaim(1, old.evidenceHash, old.reasonHash, "different URI");
        require(
            _hpSourceHash() == before_
                && Reconstruction(suite.archive).storedPayloadCount() == count,
            "original subject replay and complete rollback"
        );
        bytes32 fresh = _hpClaim(false);
        require(fresh != old.recordHash, "fresh successor-domain occurrence succeeds");
    }

    function testPlatformHistoryExactCatalogueDriftRefusesBeforeWriteThenRestoredRetry() external {
        _baseline();
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p, HP.Bundle memory b) = _hpPrepare(next);
        uint256 original = Reconstruction(suite.archive).storedPayloadCount();
        bytes memory call_ = abi.encodeCall(Reconstruction.storedPayloadCount, ());
        bytes32 before_ = _rhDestinationHash(next);
        avm.mockCall(suite.archive, call_, abi.encode(original + 1));
        dv.expectRevert();
        WithConsents(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(r, _hcRoyalties());
        require(_rhDestinationHash(next) == before_, "unobserved catalogue suffix cannot import");
        avm.mockCall(suite.archive, call_, abi.encode(original));
        _hpImport(next, r, p, b);
    }

    function testPlatformHistoryWrongOwnerOrOperationCannotUseCollectionOnlyAdmission() external {
        _baseline();
        _signedDispute(1, keccak256("real Artist-bound dispute"), false);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p, HP.Bundle memory b) = _hpPrepare(next);
        uint256 index = Native(suite.owners[4]).artistNativeReceiptCount() - 1;
        HT.Receipt memory original = Native(suite.owners[4]).artistNativeReceiptAt(index);
        require(
            original.operation == 44 && original.artistId == artistId, "genuine non-Platform row"
        );
        HT.Receipt memory bad = abi.decode(abi.encode(original), (HT.Receipt));
        bad.artistId = 0;
        bytes memory call_ = abi.encodeCall(Native.artistNativeReceiptAt, (index));
        bytes32 before_ = _rhDestinationHash(next);
        avm.mockCall(suite.owners[4], call_, abi.encode(bad));
        dv.expectRevert();
        Prepared.prepare(next.coordinator.suiteConfiguration(), r, _hcRoyalties());
        require(
            _rhDestinationHash(next) == before_,
            "zero Artist exception is closed to exact native operations"
        );
        avm.mockCall(suite.owners[4], call_, abi.encode(original));
        _hpImport(next, r, p, b);
    }

    function testPlatformHistoryLateArchiveFailureRollsBackAllSevenAndExactSafeRetry() external {
        _baseline();
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p, HP.Bundle memory b) = _hpPrepare(next);
        bytes memory call_ = _hcCall(r);
        bytes memory append = _firstPage(next, r, p);
        uint256 originalBlock = block.number;
        uint256 nonce = rotationSafe.nonce();
        bytes32 before_ = _rhDestinationHash(next);
        bytes32 sourceBefore = _hpSourceHash();
        dv.expectCall(address(next.archive), append, 2);
        vm.roll(uint256(type(uint64).max) + 1);
        (bool ok,) = address(this)
            .call(abi.encodeCall(this.rhExecuteNewSafe, (address(next.registry), call_)));
        require(
            !ok && rotationSafe.nonce() == nonce && _rhDestinationHash(next) == before_
                && _hpSourceHash() == sourceBefore,
            "late Archive reverts all imports and Safe nonce"
        );
        vm.roll(originalBlock);
        require(
            this.rhExecuteNewSafe(address(next.registry), call_),
            "identical saved Safe request retries"
        );
        require(rotationSafe.nonce() == nonce + 1, "exactly one successful Safe execution");
        _rhImported(next, p, HydrationOwner(next.identity).authorityHydrationCommitment());
        _hpAssert(next.coordinator.suiteConfiguration(), b);
    }

    function _hpBytes(HP.Bundle memory b) private pure returns (bytes memory) {
        bytes[4] memory parts = [
            abi.encode(b.original),
            abi.encode(b.sanctions),
            abi.encode(b.platform),
            abi.encode(b.bindings)
        ];
        return abi.encode(
            keccak256("6529STREAM_ARTIST_RECOVERED_PLATFORM_HISTORY_V1"), uint16(1), parts
        );
    }

    function _hpSourceHash() private view returns (bytes32) {
        T.Snapshot[7] memory rows;
        for (uint8 i; i < 7; ++i) {
            rows[i] = OriginalOwner(suite.owners[i]).ownerStateSnapshotV2();
        }
        return keccak256(abi.encode(rows, Reconstruction(suite.archive).storedPayloadCount()));
    }

    function _hpRefuses(Commit.Prepared memory p, HP.Bundle memory b) private {
        dv.expectRevert();
        this.platformValidate(p.query, RH.ownerProvenance(p.admission.provenance, 4), _hpBytes(b));
    }

    function _hpValidates(Commit.Prepared memory p, HP.Bundle memory b) private view {
        this.platformValidate(p.query, RH.ownerProvenance(p.admission.provenance, 4), _hpBytes(b));
    }
}

/// @notice A bound collection can have original10 allegations without ever declaring Platform Works.
contract StreamArtistRecoveredPlatformAllegationOnlyTest is ArtistRecoveredPlatformFixture {
    function _beforeInitialBindingProposal() internal override { }

    function testPlatformHistoryActualAllegationOnlyKeepsAbsentDeclarationAndOriginalConsentBytes()
        external
    {
        _baseline();
        bytes32 claim = _hpClaim(true);
        Successor memory next = _rhCutover();
        (RH.Request memory r, Commit.Prepared memory p, HP.Bundle memory b) = _hpPrepare(next);
        require(
            b.platform.state.declaration.recordHash == 0
                && b.platform.state.correction.recordHash == 0 && b.platform.allegationCount == 1
                && b.platform.latestDisplayClaim == claim && !b.platform.status.effectiveAccepted
                && b.platform.continuations.length == 0,
            "allegation does not invent Platform declaration or corrective authority"
        );
        (, Payload.Payload memory payload) = Payload.decode(p.data[6].typedState, 6);
        ConsentCodec.Bundle memory original = ConsentCodec.collect(
            suite.owners[6],
            p.query,
            payload.provenance,
            new T.EconomicsConsent[](0),
            b.bindings.bindings
        );
        require(
            keccak256(payload.semanticState)
                == keccak256(ConsentCodec.encode(original, p.query, payload.provenance)),
            "owner6 supported earlier codec remains byte-identical"
        );
        _hpImport(next, r, p, b);
    }
}
