// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistAggregateSanctionConsentTypes as F
} from "../../../smart-contracts/domains/artist/StreamArtistAggregateSanctionConsentTypes.sol";
import {
    StreamArtistRecoveredAggregateSanctionConsentFacts as Facts
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAggregateSanctionConsentFacts.sol";
import {
    StreamArtistRecoveredAggregateSanctionAttributionFacts as Attribution
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAggregateSanctionAttributionFacts.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationClocks as Clocks
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationClocks.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistSanctionTypes as S
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSanctionTypes.sol";

/// @notice Pure predicates after original Archive/provenance admission, with explicit global clocks.
/// @dev Synthetic source facts only: no actual signature, source admission, full owner4 partition,
/// governance, or operation60 execution is claimed. The original fixed predicates run unmocked.
contract StreamArtistRecoveredAggregateSanctionConsentFactsTest {
    struct Fixture {
        G.Consents[] original;
        AH.Query[] collections;
        RH.OwnerProvenance provenance;
        F.Facts facts;
        bytes32[] surfaces;
        bytes32[] scopes;
    }

    function check(Fixture memory f) external pure {
        Facts.validate(f.original, f.collections, f.provenance, f.facts);
        Facts.nativeRows(f.provenance, f.facts);
        Facts.clocksAndAliases(f.provenance, f.surfaces, f.scopes, f.facts);
    }

    function checkGenerations(
        A.AttributionBundle[] memory all,
        RH.OwnerProvenance memory p,
        Clocks.Result memory clocks,
        H.ConfirmationRow[] memory confirmations
    ) external pure {
        Attribution.generations(all, p, clocks, confirmations);
    }

    function checkDisputes(
        D.Bundle[] memory all,
        RH.OwnerProvenance memory p,
        Clocks.Result memory clocks,
        H.ConfirmationRow[] memory confirmations
    ) external pure {
        Attribution.disputes(all, p, clocks, confirmations);
    }

    function testTwoCollectionsCanConfirmSameGenerationWithIndependentOwnerClocks() external view {
        Fixture memory f = _fixture();
        bytes32 before_ = keccak256(abi.encode(f));
        this.check(f);
        require(f.facts.confirmations[0].attributionPoint.ownerRevision == 101, "original owner4");
        require(f.facts.confirmations[0].consentPoint.ownerRevision == 2, "original owner6");
        require(keccak256(abi.encode(f)) == before_, "original facts unchanged");
    }

    function testNativeTwelveMappingRejectsMissingDuplicateAndReorderedOriginalRows()
        external
        view
    {
        bytes memory saved = abi.encode(_fixture());
        Fixture memory f = abi.decode(saved, (Fixture));
        f.provenance.journal[1].receipt.operation = 14;
        _bad(f, _profile());
        f = abi.decode(saved, (Fixture));
        f.facts.sanctions[1] = f.facts.sanctions[0];
        _bad(f, _profile());
        f = abi.decode(saved, (Fixture));
        F.Record memory first = f.facts.sanctions[0];
        f.facts.sanctions[0] = f.facts.sanctions[1];
        f.facts.sanctions[1] = first;
        _bad(f, _profile());
        this.check(abi.decode(saved, (Fixture)));
    }

    function testMissingAndDuplicateConfirmationsCannotHideGlobalRevisionGaps() external view {
        bytes memory saved = abi.encode(_fixture());
        Fixture memory f = abi.decode(saved, (Fixture));
        H.ConfirmationRow memory first = f.facts.confirmations[0];
        f.facts.confirmations = new H.ConfirmationRow[](1);
        f.facts.confirmations[0] = first;
        _bad(f, _profile());
        f = abi.decode(saved, (Fixture));
        f.facts.confirmations[1] = f.facts.confirmations[0];
        _bad(f, _profile());
        f = abi.decode(saved, (Fixture));
        f.facts.confirmations[1].consentPoint = f.facts.sanctions[1].point;
        _bad(f, _profile());
        this.check(abi.decode(saved, (Fixture)));
    }

    function testOwnerFourPointCannotReplaceOriginalConsentPoint() external view {
        Fixture memory f = _fixture();
        RH.Point memory wrong = f.facts.confirmations[0].attributionPoint;
        f.facts.confirmations[0].consentPoint = wrong;
        _bad(
            f,
            abi.encodeWithSelector(
                RH.InvalidRecoveredHydrationPoint.selector,
                wrong.environmentHash,
                wrong.ownerIndex,
                wrong.ownerRevision
            )
        );
        f = _fixture();
        // Even changing the owner label cannot turn the unrelated owner4 revision into owner6.
        wrong.ownerIndex = 6;
        f.facts.confirmations[0].consentPoint = wrong;
        _bad(
            f,
            abi.encodeWithSelector(
                RH.InvalidRecoveredHydrationPoint.selector,
                wrong.environmentHash,
                wrong.ownerIndex,
                wrong.ownerRevision
            )
        );
        this.check(_fixture());
    }

    function testMissingWrongAndExtraAliasesRefuseThenOriginalFactsRetry() external view {
        bytes memory saved = abi.encode(_fixture());
        Fixture memory f = abi.decode(saved, (Fixture));
        f.provenance.aliases[1].scope = bytes32(uint256(99));
        _bad(f, _profile());
        f = abi.decode(saved, (Fixture));
        f.provenance.aliases[1].cell.commitment = bytes32(uint256(99));
        _bad(f, _profile());
        f = abi.decode(saved, (Fixture));
        f.provenance.aliases[1].admittedAt = f.provenance.aliases[0].admittedAt;
        _bad(f, _profile());
        f = abi.decode(saved, (Fixture));
        RH.ReplayAlias[] memory old = f.provenance.aliases;
        f.provenance.aliases = new RH.ReplayAlias[](3);
        for (uint256 i; i < 3; ++i) {
            f.provenance.aliases[i] = old[i];
        }
        _bad(f, _profile());
        f = abi.decode(saved, (Fixture));
        old = f.provenance.aliases;
        f.provenance.aliases = new RH.ReplayAlias[](5);
        for (uint256 i; i < 4; ++i) {
            f.provenance.aliases[i] = old[i];
        }
        f.provenance.aliases[4] = old[0];
        _bad(f, _profile());
        this.check(abi.decode(saved, (Fixture)));
    }

    function testHistoricalBindingArtistIsUsedInsteadOfHeadQueryArtist() external view {
        Fixture memory f = _fixture();
        f.collections[0].artistId = bytes32(uint256(555));
        this.check(f);
        f.original[0].bindings[0].artistId = f.collections[0].artistId;
        _bad(f, _profile());
        f = _fixture();
        f.original[0].bindings[0].accepted = false;
        _bad(f, _profile());
        f = _fixture();
        f.collections[1].collectionId = f.collections[0].collectionId;
        _bad(f, _profile());
        this.check(_fixture());
    }

    function testCheckpointCannotOmitZeroNativeConfirmationOrInventNonceInventory() external view {
        bytes memory saved = abi.encode(_fixture());
        Fixture memory f = abi.decode(saved, (Fixture));
        f.provenance.eras[0].checkpoint.replayCount = 2;
        _bad(f, _profile());
        f = abi.decode(saved, (Fixture));
        f.provenance.eras[0].nativeCount = 3;
        _bad(f, _profile());
        f = abi.decode(saved, (Fixture));
        f.provenance.eras[0].checkpoint.nonceIndexCount = 1;
        _bad(f, _profile());
        this.check(abi.decode(saved, (Fixture)));
    }

    function testRekeyedAliasesRetainOriginalAdmissionPointsAcrossImportEra() external view {
        Fixture memory f = _fixture();
        RH.OriginEnvironment memory first = f.provenance.origins[0];
        RH.OwnerEra memory firstEra = f.provenance.eras[0];
        f.provenance.origins = new RH.OriginEnvironment[](2);
        f.provenance.origins[0] = first;
        f.provenance.origins[1] = abi.decode(abi.encode(first), (RH.OriginEnvironment));
        f.provenance.origins[1].owners[6] = address(0x6767);
        bytes32 next = RH.originHash(f.provenance.origins[1]);
        f.provenance.eras = new RH.OwnerEra[](2);
        f.provenance.eras[0] = firstEra;
        f.provenance.eras[1].originHash = next;
        f.provenance.eras[1].lowerRevision = 1;
        f.provenance.eras[1].checkpoint.schema = RH.CHECKPOINT;
        f.provenance.eras[1].checkpoint.ownerState.domainId = RH.ownerDomain(6);
        f.provenance.eras[1].checkpoint.ownerState.revision = 1;
        f.provenance.eras[1].checkpoint.replayCount = 4;
        f.provenance.eras[1].checkpoint.replayRoot = bytes32(uint256(405));
        RH.ReplayAlias[] memory firstAliases = f.provenance.aliases;
        f.provenance.aliases = new RH.ReplayAlias[](8);
        for (uint256 i; i < 4; ++i) {
            f.provenance.aliases[i] = firstAliases[i];
            f.provenance.aliases[4 + i] = abi.decode(abi.encode(firstAliases[i]), (RH.ReplayAlias));
            f.provenance.aliases[4 + i].originHash = next;
            f.provenance.aliases[4 + i].originalKey = keccak256(abi.encode(next, i));
        }
        this.check(f);
        f.provenance.aliases[5].admittedAt = RH.Point(next, 6, 1);
        _bad(f, _profile());
        f.provenance.aliases[5].admittedAt = firstAliases[1].admittedAt;
        this.check(f);
    }

    function testAttributionIntervalsUseOriginalOwnerFourAndPreserveConfirmedState() external view {
        (
            A.AttributionBundle[] memory all,
            RH.OwnerProvenance memory p,
            Clocks.Result memory clocks,
            H.ConfirmationRow[] memory confirmations
        ) = _attribution();
        this.checkGenerations(all, p, clocks, confirmations);
        all[0].current.state = 2;
        _badCall(abi.encodeCall(this.checkGenerations, (all, p, clocks, confirmations)), _profile());
        all[0].current.state = 3;
        RH.Point memory saved = confirmations[0].attributionPoint;
        confirmations[0].attributionPoint = clocks.collections[0].attributionCompletions[0];
        _badCall(abi.encodeCall(this.checkGenerations, (all, p, clocks, confirmations)), _profile());
        confirmations[0].attributionPoint = saved;
        this.checkGenerations(all, p, clocks, confirmations);
    }

    function testEarlierConfirmedGenerationDoesNotConfirmAcceptedReplacement() external view {
        (
            A.AttributionBundle[] memory all,
            RH.OwnerProvenance memory p,
            Clocks.Result memory clocks,
            H.ConfirmationRow[] memory confirmations
        ) = _attribution();
        for (uint256 k; k < 2; ++k) {
            A.Generation memory original = all[k].generations[0];
            all[k].generations = new A.Generation[](2);
            all[k].generations[0] = original;
            all[k].generations[1].accepted = true;
            all[k].generations[1].generation = 2;
            all[k].current.generation = 2;
            all[k].current.state = 2;
            clocks.collections[k].attributionProposals = new RH.Point[](2);
            clocks.collections[k].attributionProposals[1] = RH.Point(p.eras[0].originHash, 4, 110);
        }
        this.checkGenerations(all, p, clocks, confirmations);
        all[0].current.state = 3;
        _badCall(abi.encodeCall(this.checkGenerations, (all, p, clocks, confirmations)), _profile());
    }

    function testDisputeTimelineAdapterDoesNotDropForeignConfirmation() external view {
        (
            A.AttributionBundle[] memory rows,
            RH.OwnerProvenance memory p,
            Clocks.Result memory clocks,
            H.ConfirmationRow[] memory confirmations
        ) = _attribution();
        D.Bundle[] memory all = new D.Bundle[](2);
        for (uint256 k; k < 2; ++k) {
            all[k].artistId = rows[k].artistId;
            all[k].collectionId = rows[k].collectionId;
            all[k].generations = rows[k].generations;
            all[k].current = rows[k].current;
        }
        this.checkDisputes(all, p, clocks, confirmations);
        confirmations[1].transition.collectionId = 999;
        _badCall(abi.encodeCall(this.checkDisputes, (all, p, clocks, confirmations)), _profile());
    }

    function _bad(Fixture memory f, bytes memory error_) private view {
        _badCall(abi.encodeCall(this.check, (f)), error_);
    }

    function _badCall(bytes memory callData, bytes memory error_) private view {
        (bool ok, bytes memory reason) = address(this).staticcall(callData);
        require(!ok && keccak256(reason) == keccak256(error_), "exact predicate refusal");
    }

    function _profile() private pure returns (bytes memory) {
        return abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector);
    }

    function _fixture() private pure returns (Fixture memory f) {
        f.original = new G.Consents[](2);
        f.collections = new AH.Query[](2);
        f.provenance.origins = new RH.OriginEnvironment[](1);
        RH.OriginEnvironment memory origin;
        origin.chainId = 1;
        origin.owners[4] = address(0x4444);
        origin.ownerCodeHashes[4] = bytes32(uint256(444));
        origin.owners[6] = address(0x6666);
        origin.ownerCodeHashes[6] = bytes32(uint256(666));
        f.provenance.origins[0] = origin;
        bytes32 environment = RH.originHash(origin);
        f.provenance.eras = new RH.OwnerEra[](1);
        f.provenance.eras[0].originHash = environment;
        f.provenance.eras[0].nativeCount = 2;
        f.provenance.eras[0].checkpoint.schema = RH.CHECKPOINT;
        f.provenance.eras[0].checkpoint.ownerState.domainId = RH.ownerDomain(6);
        f.provenance.eras[0].checkpoint.ownerState.revision = 4;
        f.provenance.eras[0].checkpoint.replayCount = 4;
        f.provenance.eras[0].checkpoint.replayRoot = bytes32(uint256(404));
        f.provenance.journal = new RH.JournalEntry[](2);
        f.provenance.aliases = new RH.ReplayAlias[](4);
        f.facts.sanctions = new F.Record[](2);
        f.facts.confirmations = new H.ConfirmationRow[](2);
        f.surfaces = new bytes32[](2);
        f.scopes = new bytes32[](2);
        for (uint256 k; k < 2; ++k) {
            bytes32 artist = bytes32(81 + k);
            bytes32 hash = bytes32(201 + k);
            S.Record memory record;
            record.recordHash = hash;
            record.artistId = artist;
            record.signer = address(uint160(0x8100 + k));
            record.authorityClass = 1;
            record.signedAt = 10;
            record.deadline = 20;
            record.bindingGeneration = 1;
            record.bindingHash = bytes32(301 + k);
            record.terms.collectionId = 101 + k;
            f.collections[k].artistId = artist;
            f.collections[k].collectionId = 101 + k;
            f.collections[k].bindingHash = record.bindingHash;
            f.original[k].bindings = new T.Binding[](1);
            f.original[k].bindings[0].artistId = artist;
            f.original[k].bindings[0].bindingHash = record.bindingHash;
            f.original[k].bindings[0].generation = 1;
            f.original[k].bindings[0].accepted = true;
            RH.Point memory nativePoint = RH.Point(environment, 6, uint64(1 + 2 * k));
            f.facts.sanctions[k] = F.Record(nativePoint, record);
            f.provenance.journal[k].position = RH.Position(nativePoint, k);
            f.provenance.journal[k].receipt.operation = 12;
            f.provenance.journal[k].receipt.artistId = artist;
            f.provenance.journal[k].receipt.collectionId = 101 + k;
            f.provenance.journal[k].receipt.recordHash = hash;
            f.surfaces[k] = keccak256("consent_finality.replay.sanction_uniqueness");
            f.scopes[k] = keccak256(abi.encode(hash));
            H.ConfirmationRow memory c;
            c.attributionPoint = RH.Point(environment, 4, uint64(101 + 2 * k));
            c.consentPoint = RH.Point(environment, 6, uint64(2 + 2 * k));
            c.transition.collectionId = 101 + k;
            c.transition.artistId = artist;
            c.transition.bindingGeneration = 1;
            c.transition.sanctionRecordHash = hash;
            c.transition.finalityRecordHash = bytes32(401 + k);
            c.transition.priorAttributionState = 2;
            f.facts.confirmations[k] = c;
            f.provenance.aliases[2 * k] =
                _alias(environment, f.surfaces[k], f.scopes[k], hash, nativePoint);
            f.provenance.aliases[2 * k + 1] = _alias(
                environment,
                keccak256("consent_finality.replay.sanction_finalization_transition_key"),
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_SANCTION_FINALIZATION_TRANSITION_V1"),
                        c.transition
                    )
                ),
                hash,
                c.consentPoint
            );
        }
    }

    function _alias(
        bytes32 environment,
        bytes32 surface,
        bytes32 scope,
        bytes32 hash,
        RH.Point memory point
    ) private pure returns (RH.ReplayAlias memory a) {
        a.originHash = environment;
        a.ownerIndex = 6;
        a.surface = surface;
        a.scope = scope;
        a.originalKey = keccak256(abi.encode(environment, surface, scope));
        a.cell = T.ReplayCell(hash, point.ownerRevision, 1, 2);
        a.admittedAt = point;
    }

    function _attribution()
        private
        pure
        returns (
            A.AttributionBundle[] memory all,
            RH.OwnerProvenance memory p,
            Clocks.Result memory clocks,
            H.ConfirmationRow[] memory confirmations
        )
    {
        Fixture memory f = _fixture();
        p = f.provenance;
        p.eras[0].checkpoint.ownerState.domainId = RH.ownerDomain(4);
        p.eras[0].checkpoint.ownerState.revision = 120;
        confirmations = f.facts.confirmations;
        all = new A.AttributionBundle[](2);
        clocks.collections = new G.Timeline[](2);
        for (uint256 k; k < 2; ++k) {
            all[k].artistId = f.collections[k].artistId;
            all[k].collectionId = f.collections[k].collectionId;
            all[k].current.state = 3;
            all[k].current.generation = 1;
            all[k].generations = new A.Generation[](1);
            all[k].generations[0].accepted = true;
            all[k].generations[0].generation = 1;
            clocks.collections[k].attributionCompletions = new RH.Point[](1);
            clocks.collections[k].attributionCompletions[0] =
                RH.Point(p.eras[0].originHash, 4, uint64(90 + k));
        }
    }
}
