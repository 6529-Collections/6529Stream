// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistUnboundPlatformFixture.sol";

/// @notice New actual-producer oracles. Inherited prior tests are not part of this profile's cohort.
contract StreamArtistUnboundPlatformActualTest is ArtistUnboundPlatformFixture {
    function testUnboundPlatformOnlyRegistryHasNoInventedIdentityAcceptanceOrNativeReceipt()
        external
    {
        _upSource(false);
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).nextRegistrationNonce() == 0,
            "zero authentic principals"
        );
        Successor memory next = _upCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _upPrepare(next);
        require(
            p.admission.provenance.journals[2].length == 0
                && p.admission.provenance.journals[4].length == 1,
            "only real original8"
        );
        _upImport(next, r, p);
    }

    function testUnboundPlatformBothClaimFamiliesAndGovernedDismissalKeepFullOriginalBodies()
        external
    {
        _upSource(false);
        bytes32 claim = _hpClaim(false);
        _hpClaim(true);
        _hpContest(1, claim, false);
        _hpContest(2, claim, false);
        Successor memory next = _upCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _upPrepare(next);
        (,, P.Platform memory b) = _upPlatform(p);
        require(
            b.state.contestState == 2 && b.state.claimCount == 1 && b.allegationCount == 1
                && b.claims.length == 1 && b.contests.length == 2
                && b.latestDisplayClaim == allegations[0],
            "complete mixed display and governed dismissal"
        );
        _upImport(next, r, p);
    }

    function testUnboundPlatformPendingCorrectionDoesNotInventCorrectiveGeneration() external {
        _upSource(false);
        bytes32 claim = _hpClaim(false);
        _hpContest(1, claim, false);
        _hpContest(3, claim, false);
        _hpContest(3, claim, true);
        Successor memory next = _upCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _upPrepare(next);
        (,, P.Platform memory b) = _upPlatform(p);
        require(
            b.state.correction.recordHash != 0 && b.state.correction.correctiveGeneration == 0
                && !b.state.correction.accepted && b.continuations.length == 0,
            "original approval remains unused"
        );
        _upImport(next, r, p);
    }

    function testUnboundPlatformRepeatedAToBToCPreservesOriginalAliasesAndFreshClaim() external {
        _upSource(false);
        bytes32 oldClaim = _hpClaim(false);
        _hpClaim(true);
        Successor memory middle = _upCutover();
        (RH.Request memory r, Commit.Prepared memory first) = _upPrepare(middle);
        bytes32 firstValue = _upImport(middle, r, first);
        PW.Claim memory old = ingress.platformWorksClaimRecord(oldClaim);
        _upAdopt(middle);
        bytes32 before_ = _upSourceHash();
        (bool replay,) = address(ingress)
            .call(
                abi.encodeCall(
                    IStreamArtistPlatformWorks.filePlatformWorksClaim,
                    (upCollection, old.evidenceHash, old.reasonHash, "changed URI")
                )
            );
        require(!replay && _upSourceHash() == before_, "original claim subject remains spent");
        bytes32 fresh = _hpClaim(true);
        Successor memory last = _upCutover();
        Commit.Prepared memory second;
        (r, second) = _upPrepare(last);
        require(
            r.expectedSourceImportCommitment == firstValue
                && second.admission.provenance.eras.length == 2
                && second.admission.provenance.eras[1].lowerRevisions[2] == 3,
            "real collection-only55/56/60 import boundary"
        );
        RH.JournalEntry[] memory a = first.admission.provenance.journals[4];
        RH.JournalEntry[] memory b = second.admission.provenance.journals[4];
        require(
            b.length == a.length + 1 && b[b.length - 1].receipt.recordHash == fresh
                && b[b.length - 1].position.nativeIndex == 0,
            "one authentic fresh suffix"
        );
        for (uint256 i; i < a.length; ++i) {
            require(
                keccak256(abi.encode(a[i])) == keccak256(abi.encode(b[i])),
                "all original occurrence positions unchanged"
            );
        }
        _upImport(last, r, second);
    }

    function testUnboundPlatformMixedRegistryRetainsCompleteOrdinaryRecoveredArtist() external {
        _upSource(true);
        _hpClaim(false);
        _hpClaim(true);
        Successor memory next = _upCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _upPrepare(next);
        require(
            p.admission.artists.length == 1 && p.admission.collections.length == 2
                && p.admission.collections[0].artistId == artistId
                && p.admission.collections[1].artistId == 0,
            "complete mixed scope"
        );
        _upImport(next, r, p);
    }

    function testUnboundPlatformMissingOrdinaryScopeCannotImportOnlySelectedPlatformRows()
        external
    {
        _upSource(true);
        Successor memory next = _upCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _upPrepare(next);
        RH.Request memory bad = abi.decode(abi.encode(r), (RH.Request));
        bad.records.authority.artistIds = new bytes32[](0);
        bad.records.authority.collections = new MH.Collection[](1);
        bad.records.authority.collections[0] = r.records.authority.collections[1];
        bytes32 before_ = _rhDestinationHash(next);
        (bool ok,) = address(this)
            .staticcall(
                abi.encodeCall(this.upPrepareRaw, (next.coordinator.suiteConfiguration(), bad))
            );
        require(!ok && _rhDestinationHash(next) == before_, "omitted Artist native journal refuses");
        _upImport(next, r, p);
    }

    function testUnboundPlatformArchiveFieldsOutsideRecordHashAreAuthenticatedAndRestore()
        external
    {
        _upSource(false);
        _hpClaim(false);
        Successor memory next = _upCutover();
        (, Commit.Prepared memory p) = _upPrepare(next);
        (M.State memory scope, Payload.Payload memory local, P.Platform memory b) = _upPlatform(p);
        M.State memory bad = abi.decode(abi.encode(scope), (M.State));
        P.Platform memory changed = abi.decode(abi.encode(b), (P.Platform));
        changed.claims[0].record.proposedArtist = address(0xBAD);
        bad.rows[0] = abi.encode(changed);
        (bool ok,) =
            address(this).staticcall(abi.encodeCall(this.upValidate, (bad, local.provenance)));
        require(
            !ok, "Archive proposal field cannot be invented despite unchanged original record hash"
        );
        this.upValidate(scope, local.provenance);
    }

    function testUnboundPlatformMissingNativeRowOrReplayCellCannotHideHistory() external {
        _upSource(false);
        _hpClaim(false);
        Successor memory next = _upCutover();
        (, Commit.Prepared memory p) = _upPrepare(next);
        (M.State memory scope, Payload.Payload memory local, P.Platform memory b) = _upPlatform(p);
        M.State memory bad = abi.decode(abi.encode(scope), (M.State));
        b.claims = new P.ClaimRow[](0);
        bad.rows[0] = abi.encode(b);
        (bool ok,) =
            address(this).staticcall(abi.encodeCall(this.upValidate, (bad, local.provenance)));
        require(!ok, "complete native row count");
        RH.OwnerProvenance memory stripped =
            abi.decode(abi.encode(local.provenance), (RH.OwnerProvenance));
        stripped.aliases = new RH.ReplayAlias[](0);
        (ok,) = address(this).staticcall(abi.encodeCall(this.upValidate, (scope, stripped)));
        require(!ok, "complete original replay inventory");
        this.upValidate(scope, local.provenance);
    }

    function testUnboundPlatformEmptyPrincipalRejectsInventedTimingAndNonceInventory() external {
        _upSource(false);
        Successor memory next = _upCutover();
        (, Commit.Prepared memory p) = _upPrepare(next);
        (M.State memory scope, Payload.Payload memory local) =
            UCodec.outer(2, p.query, p.data[2].typedState);
        (bytes32 tag, uint16 version, TM.Checkpoint memory checkpoint) =
            abi.decode(scope.rows[0], (bytes32, uint16, TM.Checkpoint));
        checkpoint.configurationHash = keccak256("invented global timing");
        (bool ok,) = address(this)
            .staticcall(
                abi.encodeCall(
                    this.upEmpty,
                    (
                        local.provenance,
                        local.nonces,
                        scope.collections,
                        abi.encode(tag, version, checkpoint)
                    )
                )
            );
        require(!ok, "no absent-principal timing inference");
        RH.NonceInventory[] memory nonces = new RH.NonceInventory[](1);
        (ok,) = address(this)
            .staticcall(
                abi.encodeCall(
                    this.upEmpty, (local.provenance, nonces, scope.collections, scope.rows[0])
                )
            );
        require(!ok, "global nonce inventory remains empty and exact");
        this.upEmpty(local.provenance, local.nonces, scope.collections, scope.rows[0]);
    }

    function testUnboundPlatformLateArchiveFailureRollsBackSevenOwnersAndIdenticalSafeRetry()
        external
    {
        _upSource(false);
        _hpClaim(false);
        Successor memory next = _upCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _upPrepare(next);
        bytes memory call_ = abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (r));
        uint256 nonce = artist.nonce();
        bytes32 before_ = _rhDestinationHash(next);
        bytes32 sourceBefore = _upSourceHash();
        address last = next.coordinator.suiteConfiguration().owners[6];
        UnboundTestVM(address(avm))
            .expectCall(
                last,
                abi.encodeWithSelector(HydrationOwner.applyArtistAuthorityHydration.selector),
                2
            );
        uint256 height = block.number;
        vm.roll(uint256(type(uint64).max) + 1);
        (bool ok,) = address(this)
            .call(abi.encodeCall(this.executeTargetSafe, (address(next.registry), call_)));
        require(
            !ok && artist.nonce() == nonce && _rhDestinationHash(next) == before_
                && _upSourceHash() == sourceBefore,
            "late original Archive overflow rolls back complete import and Safe nonce"
        );
        vm.roll(height);
        require(
            this.executeTargetSafe(address(next.registry), call_) && artist.nonce() == nonce + 1,
            "identical Safe request succeeds after restoration"
        );
        _upAssert(next, p, HydrationOwner(next.identity).authorityHydrationCommitment());
    }

    function _upSourceHash() private view returns (bytes32) {
        T.Snapshot[7] memory states;
        for (uint8 i; i < 7; ++i) {
            states[i] = Owner(suite.owners[i]).ownerStateSnapshotV2();
        }
        return keccak256(abi.encode(states, Reconstruction(suite.archive).storedPayloadCount()));
    }

    function upPrepareRaw(T.SuiteConfiguration calldata destination, RH.Request calldata r)
        external
        view
        returns (bytes32)
    {
        Commit.Prepared memory p = Prepared.prepare(destination, r);
        return Prepared.inventory(p);
    }
}
