// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleDisputeCatalogue as Catalogue
} from "./StreamArtistRecoveredMultipleDisputeCatalogue.sol";
import {
    StreamArtistRecoveredMultipleDisputeTypes as MD
} from "./StreamArtistRecoveredMultipleDisputeTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    StreamArtistRepudiationTypes as RP
} from "../../interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";

/// @notice A bijection with authentic Archive events, including non-native46/48/49/50 coordinates.
/// @dev Original source maps, immutable evidence metadata and complete seven-owner cutoffs are all retained.
library StreamArtistRecoveredMultipleDisputeArchive {
    function validate(
        D.Bundle[] memory all,
        RH.OwnerProvenance memory p,
        G.Inventory memory inventory
    ) public view {
        uint256 expected;
        for (uint256 k; k < all.length; ++k) {
            expected += all[k].disputes.length + all[k].resolutions.length
            + all[k].repudiations.length;
            for (uint256 i; i < all[k].repudiations.length; ++i) {
                uint8 phase = all[k].repudiations[i].terminal.phase;
                if (phase >= 2 && phase <= 4) ++expected;
            }
        }
        uint256 matched;
        for (uint256 i; i < inventory.operations.length; ++i) {
            H.OperationEvidence memory row = inventory.operations[i];
            if (row.operation <= 4) continue;
            uint256 era = A.era(p, row.originHash);
            H.Envelope memory e =
                Catalogue.read(p.origins[era], inventory.catalogues[era], row.evidence);
            if (e.operation != row.operation || !MD.archivedOperation(e.operation)) _invalid();
            for (uint256 j; j < i; ++j) {
                H.OperationEvidence memory previous = inventory.operations[j];
                if (
                    previous.originHash == row.originHash
                        && previous.evidence.evidenceId == row.evidence.evidenceId
                ) _invalid();
            }
            RH.Point memory point = RH.Point(row.originHash, 4, e.after_[4].revision);
            (uint256 count, bool identityWrite) = _match(all, e, point);
            if (count != 1) _invalid();
            _snapshots(inventory.catalogues[era], e, identityWrite);
            ++matched;
        }
        if (matched != expected) _invalid();
    }

    function _match(D.Bundle[] memory all, H.Envelope memory e, RH.Point memory point)
        private
        pure
        returns (uint256 count, bool identityWrite)
    {
        for (uint256 k; k < all.length; ++k) {
            D.Bundle memory b = all[k];
            if (e.operation == 44 || e.operation == 45 || e.operation == 61) {
                for (uint256 i; i < b.disputes.length; ++i) {
                    D.DisputeRow memory r = b.disputes[i];
                    if (r.record.recordHash != e.value) continue;
                    uint16 expected = r.record.terms.disputeAction == 1
                        ? 44
                        : r.record.terms.disputeAction == 2 ? 61 : 45;
                    if (e.operation != expected || !D.samePoint(r.point, point)) _invalid();
                    identityWrite = r.record.governanceActionId == 0;
                    ++count;
                }
            } else if (e.operation == 46) {
                for (uint256 i; i < b.resolutions.length; ++i) {
                    D.ResolutionRow memory r = b.resolutions[i];
                    if (r.record.actionId != e.value) continue;
                    if (!D.samePoint(r.point, point) || r.record.actor != e.actor) _invalid();
                    _resolution(r.record, b, e.payload);
                    ++count;
                }
            } else {
                for (uint256 i; i < b.repudiations.length; ++i) {
                    D.RepudiationRow memory r = b.repudiations[i];
                    if (r.record.recordHash != e.value) continue;
                    if (e.operation == 47) {
                        if (!D.samePoint(r.point, point)) _invalid();
                        identityWrite = true;
                    } else {
                        if (
                            e.operation < 48 || e.operation > 50
                                || r.terminal.phase != e.operation - 46
                                || !D.samePoint(r.terminalPoint, point)
                                || r.terminal.actor != e.actor
                        ) _invalid();
                        _terminal(r, e);
                        identityWrite = e.operation != 50;
                    }
                    ++count;
                }
            }
        }
    }

    function _resolution(AD.Resolution memory r, D.Bundle memory b, bytes memory raw) private pure {
        (
            AD.ResolutionRequest memory terms,
            T.Binding memory binding_,
            AD.Context memory context,
            Contest.GovernanceWitness memory governance,
            bytes32 evidence,
            bytes32 reason
        ) = abi.decode(
            raw,
            (
                AD.ResolutionRequest,
                T.Binding,
                AD.Context,
                Contest.GovernanceWitness,
                bytes32,
                bytes32
            )
        );
        if (
            keccak256(raw)
                    != keccak256(abi.encode(terms, binding_, context, governance, evidence, reason))
                || keccak256(abi.encode(terms)) != keccak256(abi.encode(r.terms))
                || binding_.artistId != b.artistId || binding_.generation != terms.bindingGeneration
                || binding_.bindingHash != b.generations[terms.bindingGeneration - 1].bindingHash
                || governance.actionId != r.actionId || governance.proposer != r.proposer
                || governance.actionClass != r.actionClass
                || keccak256(abi.encode(governance)) != r.witnessHash
                || context.restoredState != r.restoredState || context.requiredClass > r.actionClass
                || context.scopeHash != governance.scopeHash
                || context.oldValueHash != governance.oldValueHash
                || context.newValueHash != governance.newValueHash || evidence == 0 || reason == 0
        ) _invalid();
    }

    function _terminal(D.RepudiationRow memory r, H.Envelope memory e) private pure {
        if (e.operation == 48) {
            (RP.Record memory record, RP.GuardianProof memory proof, bytes32 contest) =
                abi.decode(e.payload, (RP.Record, RP.GuardianProof, bytes32));
            if (
                keccak256(e.payload) != keccak256(abi.encode(record, proof, contest))
                    || keccak256(abi.encode(record)) != keccak256(abi.encode(r.record))
                    || proof.collectionId != r.record.terms.collectionId
                    || proof.repudiationRecordHash != r.record.recordHash
                    || proof.capturedGuardianSet != r.record.capturedGuardianSet
                    || proof.vetoer != r.terminal.actor || proof.reasonHash != r.terminal.reasonHash
                    || proof.vetoedAt != r.terminal.recordedAt || contest == 0
            ) _invalid();
        } else if (keccak256(e.payload) != keccak256(abi.encode(r.record))) {
            _invalid();
        }
    }

    function _snapshots(P.Catalogue memory c, H.Envelope memory e, bool identityWrite)
        private
        pure
    {
        uint256 mask = e.operation == 45 || e.operation == 47
            ? 0x17
            : e.operation == 46 ? 0x11 : e.operation == 48 || e.operation == 49 ? 0x14 : 0x15;
        T.Snapshot memory zero;
        for (uint8 i; i < 7; ++i) {
            T.Snapshot memory before_ = e.before_[i];
            T.Snapshot memory after_ = e.after_[i];
            if ((mask & (1 << i)) == 0) {
                if (
                    keccak256(abi.encode(before_)) != keccak256(abi.encode(zero))
                        || keccak256(abi.encode(after_)) != keccak256(abi.encode(zero))
                ) _invalid();
            } else {
                if (
                    before_.domainId != RH.ownerDomain(i) || after_.domainId != RH.ownerDomain(i)
                        || before_.stateRoot == 0 || before_.recordChainTip == 0
                        || after_.stateRoot == 0 || after_.recordChainTip == 0
                        || before_.revision < c.lower[i] || after_.revision > c.upper[i]
                ) _invalid();
                if (i == 4 || (i == 2 && identityWrite)) {
                    if (after_.revision != before_.revision + 1) _invalid();
                } else if (keccak256(abi.encode(before_)) != keccak256(abi.encode(after_))) {
                    _invalid();
                }
            }
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
