// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistRecoveredMultipleDisputeFixture.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredHistoryRecordRouting as Routing
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHistoryRecordRouting.sol";
import {
    StreamArtistRecoveredMultipleDisputeConservation as DisputeConservation
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleDisputeConservation.sol";
import {
    StreamArtistRecoveredMultipleDisputeCurrent as DisputeCurrent
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleDisputeCurrent.sol";

/// @notice Authored actual-owner/Safe aggregate regressions; native execution remains separate.
contract StreamArtistRecoveredMultipleDisputeActualTest is ArtistRecoveredMultipleDisputeFixture {
    function _finish() private {
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mdPrepare(next);
        _mdImport(next, r, p);
    }

    function _openPair() private {
        _mdSource(false);
        _mdSigned(1, 1, keccak256("first opening"), false);
        _mdSelect(2);
        _mdSigned(2, 1, keccak256("second opening"), true);
    }

    function testAggregateSignedOpenCounterWithdrawAcrossTwoArtists() external {
        _openPair();
        _mdSigned(2, 3, keccak256("second counter"), false);
        _mdSelect(1);
        _mdSigned(1, 3, keccak256("first counter"), true);
        _mdSelect(2);
        _mdSigned(2, 2, keccak256("second withdrawal"), true);
        _mdSelect(1);
        _mdSigned(1, 2, keccak256("first withdrawal"), false);
        _finish();
    }

    function testAggregateOriginalInterleavedResolutionPoints() external {
        _openPair();
        _mdSelect(1);
        _mdResolve(1, 1, 1);
        _mdSelect(2);
        _mdResolve(2, 1, 1);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mdPrepare(next);
        D.Bundle[] memory all = _mdHistory(p);
        require(
            all[0].resolutions[0].point.ownerRevision > all[0].disputes[0].point.ownerRevision + 1,
            "another collection occupies opening plus one"
        );
        _mdImport(next, r, p);
    }

    function _governedOpen(uint256 collection) private {
        T.Binding memory b = Binding(suite.owners[0]).binding(collection);
        bytes32 parent = ingress.attributionDispute(collection, b.generation).disputeRecordHash;
        bytes32 evidence =
            _mdEvidence(collection, parent, keccak256(abi.encode("reopen", ++actionNonce)));
        AD.Filing memory filing = AD.Filing(collection, b.generation, 1, evidence, evidence);
        AD.Standing memory noStanding;
        T.Authorization memory noAuthorization;
        bytes32 action = _govern(
            abi.encodeCall(Disputes.openAttributionDispute, (filing, noStanding, noAuthorization)),
            ingress.attributionDisputeOpeningContext(filing),
            evidence,
            2
        );
        _rhCandidate(
            4,
            "attribution_lifecycle.replay.dispute_key",
            keccak256(
                abi.encode(
                    collection, b.generation, bytes32(0), address(artist), evidence, evidence
                )
            )
        );
        _rhCandidate(4, "attribution_lifecycle.replay.governance_action", action);
    }

    function testAggregateRevocationReopenAndOriginalSecondResolution() external {
        _openPair();
        _mdSelect(1);
        _mdResolve(1, 2, 2);
        _mdSelect(2);
        _mdSigned(2, 2, keccak256("other withdrawal"), false);
        _mdSelect(1);
        _governedOpen(1);
        require(
            ingress.attributionDispute(1, 1).reopened, "actual arbiter reopened prior revocation"
        );
        _mdResolve(1, 1, 2);
        _finish();
    }

    function testAggregateSharedArtistPendingCountsAndOriginalCancellation() external {
        _mdSource(true);
        RP.Record memory first = _mdStage(1, keccak256("first pending"), false);
        _mdStage(2, keccak256("second pending"), true);
        _mdCancel(1, first);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mdPrepare(next);
        _mdImport(next, r, p);
        D.Bundle[] memory all = _mdHistory(p);
        require(all[0].pending == 0 && all[1].pending != 0, "distinct live pending cells");
        require(
            RepudiationOwner(next.coordinator.suiteConfiguration().owners[4])
                .repudiationCount(artistId, keccak256(abi.encode(first.authorityHead))) == 1,
            "one global cohort count"
        );
    }

    function testAggregateGuardianVetoPreservesOriginalIdentityPairAndOtherArtist() external {
        _mdSource(false);
        RP.Record memory first = _mdStage(1, keccak256("veto first"), false);
        _mdSelect(2);
        RP.Record memory second = _mdStage(2, keccak256("cancel second"), true);
        _mdCancel(2, second);
        _mdSelect(1);
        _mdVeto(1, first);
        _finish();
    }

    function testAggregateExecutedRepudiationCorrectionAndLaterSignedHistory() external {
        _mdSource(false);
        RP.Record memory first = _mdStage(1, keccak256("execute first"), false);
        _mdSelect(2);
        _mdSigned(2, 1, keccak256("interleaved second"), true);
        _mdSelect(1);
        _mdExecute(1, first);
        _mdCorrect(1, first.recordHash);
        _mdSigned(1, 1, keccak256("later generation opening"), true);
        _mdSigned(1, 2, keccak256("later generation withdrawal"), false);
        _finish();
    }

    function testAggregatePendingGenerationRevocationDoesNotInventAcceptance() external {
        _openPair();
        _mdSelect(1);
        bytes32 first = _mdResolve(1, 2, 2);
        _mdCorrectWithAcceptance(1, first, false);
        require(!Binding(suite.owners[0]).binding(1).accepted, "actual pending generation two");
        _governedOpen(1);
        bytes32 second = _mdResolve(1, 2, 2);
        _mdCorrect(1, second);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mdPrepare(next);
        D.Bundle[] memory all = _mdHistory(p);
        require(
            all[0].generations.length == 3 && !all[0].generations[1].accepted,
            "retained original unaccepted interval"
        );
        _mdImport(next, r, p);
        T.Binding memory pending =
            Binding(next.coordinator.suiteConfiguration().owners[0]).bindingAt(1, 2);
        require(
            !pending.accepted
                && Acceptance(next.coordinator.suiteConfiguration().owners[3])
                    .acceptanceRecord(pending.bindingHash) == 0,
            "no synthetic acceptance after whole import"
        );
    }

    function testAggregateTwoVetoesShareOneGlobalIdentityInventory() external {
        _mdSource(false);
        RP.Record memory first = _mdStage(1, keccak256("veto first Artist"), false);
        _mdSelect(2);
        RP.Record memory second = _mdStage(2, keccak256("veto second Artist"), true);
        _mdSelect(1);
        _mdVeto(1, first);
        _mdSelect(2);
        _mdVeto(2, second);
        _finish();
    }

    function testAggregateTwoArtistsSameNumericDelegateNonceIndependentLanes() external {
        _mdSource(false);
        bytes32 first = _mcGrant(3);
        _mcPolicy(1, first, 77, false);
        _mdDelegated(1, 1, first, 78);
        _mdSelect(2);
        bytes32 second = _mcGrant(3);
        _mcPolicy(2, second, 77, false);
        _mdDelegated(2, 1, second, 78);
        _mdSelect(1);
        _mdDelegated(1, 2, first, 79);
        _mdSelect(2);
        _mdDelegated(2, 2, second, 79);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mdPrepare(next);
        _mdImport(next, r, p);
        for (uint256 k; k < 2; ++k) {
            (bool used,) = next.registry
                .delegatedNonceState(multiCollectionArtists[k], address(delegateSafe), 77);
            require(used, "same numeric nonce survives in independent original Artist lanes");
        }
    }

    function _crossFamilies() private {
        _mdSource(true);
        bytes32 grant = _mcGrant(9);
        _mdFamilies(grant); // 14/15/16/20: five original uses, plus direct17/21.
        bytes32 credential = _maCredential(1, 0, grant, 4, false);
        _mdDelegated(1, 1, grant, 5);
        _maCredential(2, credential, grant, 6, false);
        _mdSigned(1, 3, keccak256("signed original counter"), true);
        _mdDelegated(1, 2, grant, 7);
        require(
            ingress.delegationRecord(grant).uses == 9, "all original consent plus24 plus44/61 uses"
        );
        _mcRevoke(grant);
        _mcGrant(0);
    }

    function testAggregateGrantConservationAndPerArtistC2PAAcrossFamilies() external {
        _crossFamilies();
        _finish();
    }

    function testAggregateGlobalGrantCountRejectsMissingDisputeFamily() external {
        _crossFamilies();
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mdPrepare(next);
        (, Payload.Payload memory id) = Payload.decode(p.data[2].typedState, 2);
        M.State memory identities = ConsentCodec.decode(2, id.semanticState, id.provenance);
        (, Payload.Payload memory consent) = Payload.decode(p.data[6].typedState, 6);
        M.State memory rows = ConsentCodec.decode(6, consent.semanticState, consent.provenance);
        G.Consents[] memory consents = new G.Consents[](rows.rows.length);
        for (uint256 k; k < consents.length; ++k) {
            consents[k] = abi.decode(rows.rows[k], (G.Consents));
        }
        (, Payload.Payload memory ap) = Payload.decode(p.data[4].typedState, 4);
        (M.State memory attested, bytes memory raw) =
            ConsentCodec.decodeAuxiliary(4, ap.semanticState, ap.provenance);
        G.Inventory memory inventory = abi.decode(raw, (G.Inventory));
        for (uint256 k; k < attested.rows.length; ++k) {
            attested.rows[k] = abi.encode(abi.decode(attested.rows[k], (MD.Attribution)).records);
        }
        DisputeConservation.Context memory x = DisputeConservation.Context(
            identities.rows,
            identities,
            consents,
            attested.rows,
            inventory,
            p.admission.provenance,
            _mdHistory(p)
        );
        DisputeConservation.validate(x);
        bytes memory saved = x.identities[0];
        IH.Bundle memory b = abi.decode(saved, (IH.Bundle));
        bool changed;
        for (uint256 j; j < b.delegations.length; ++j) {
            if (b.delegations[j].recordHash == mcGrants[0]) {
                require(b.delegations[j].record.uses == 9, "known actual global count");
                b.delegations[j].record.uses = 7;
                changed = true;
            }
        }
        require(changed, "selected actual original grant");
        x.identities[0] = abi.encode(b);
        (bool ok, bytes memory reason) = address(DisputeConservation)
            .staticcall(abi.encodeWithSelector(DisputeConservation.validate.selector, x));
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector)
                    ),
            "consent plus24 cannot omit original44/61 grant uses"
        );
        x.identities[0] = saved;
        DisputeConservation.validate(x);
        _mdImport(next, r, p);
    }

    function testAggregateLateArchiveFailureRollsBackAllOwnersThenIdenticalSafeRetry() external {
        _crossFamilies();
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mdPrepare(next);
        bytes memory data = abi.encodeCall(
            ConsentHydration.hydrateRecoveredArtistAuthorityWithConsents, (r, mdRoyalties)
        );
        bytes32 before_ = _mdState(next, p);
        uint256 nonce = rotationSafe.nonce();
        uint256 at = block.number;
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ArtistArchiveBlockNumberOverflow(uint256)", uint256(type(uint64).max) + 1
            )
        );
        ConsentHydration(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(r, mdRoyalties);
        require(
            _mdState(next, p) == before_,
            "direct late append rollback all seven owners and original maps"
        );
        vm.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(address(next.registry), data);
        require(
            rotationSafe.nonce() == nonce && _mdState(next, p) == before_,
            "Safe nonce and state rolled back"
        );
        vm.roll(at);
        _mdImport(next, r, p);
    }

    function testAggregateFinalArchiveCutoffRecheckWithoutAttestations() external {
        _openPair();
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mdPrepare(next);
        DisputeCurrent.requireCurrent(p.admission.provenance, p.query, p.data[4].typedState);
        (RH.ExportHeader memory header, Payload.Payload memory payload) =
            Payload.decode(p.data[4].typedState, 4);
        require((header.requiredFeatures & RH.ATTESTATIONS) == 0, "no op24 branch");
        (M.State memory scope, bytes memory raw) =
            ConsentCodec.decodeAuxiliary(4, payload.semanticState, payload.provenance);
        G.Inventory memory inventory = abi.decode(raw, (G.Inventory));
        ++inventory.catalogues[0].upper[0];
        payload.semanticState =
            ConsentCodec.encode(4, scope, payload.provenance, abi.encode(inventory));
        header.semanticInventory = keccak256(payload.semanticState);
        (bool ok,) = address(Routing)
            .staticcall(
                abi.encodeWithSelector(
                    Routing.requireCurrent.selector,
                    p.admission.provenance,
                    p.query,
                    Payload.encode(4, header, payload)
                )
            );
        require(!ok, "actual post-import route rejects unrelated owner cutoff drift");
        _mdImport(next, r, p);
    }

    function testAggregateRepeatedImportRetainsOriginalPositionsAndFreshSuccessorHistory()
        external
    {
        _openPair();
        Successor memory middle = _multiCutover();
        (RH.Request memory firstRequest, Commit.Prepared memory first) = _mdPrepare(middle);
        _mdImport(middle, firstRequest, first);
        bytes32 firstValue = HydrationOwner(middle.identity).authorityHydrationCommitment();
        _rhAdopt(middle);
        _mdSelect(1);
        bytes32 withdrawal = _mdSigned(1, 2, keccak256("successor original61"), true);
        _mdSelect(2);
        _mdResolve(2, 1, 1);
        Successor memory last = _multiCutover();
        (RH.Request memory secondRequest, Commit.Prepared memory second) = _mdPrepare(last);
        require(
            secondRequest.expectedSourceImportCommitment == firstValue
                && second.admission.provenance.eras.length == 2,
            "real imported prefix and fresh era"
        );
        RH.JournalEntry[] memory before_ = first.admission.provenance.journals[4];
        RH.JournalEntry[] memory after_ = second.admission.provenance.journals[4];
        require(after_.length == before_.length + 1, "only fresh signed61 adds a native record");
        for (uint256 i; i < before_.length; ++i) {
            require(
                keccak256(abi.encode(before_[i])) == keccak256(abi.encode(after_[i])),
                "original occurrence index, point and receipt preserved"
            );
        }
        require(
            after_[before_.length].receipt.recordHash == withdrawal
                && after_[before_.length].position.nativeIndex == 0
                && after_[before_.length].position.point.environmentHash
                    == second.admission.provenance.eras[1].originHash,
            "fresh successor receipt keeps its own original domain and index"
        );
        _mdImport(last, secondRequest, second);
    }
}
