// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistCollaboratorTypes as C
} from "../../interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorCatalogue as Catalogue
} from "./StreamArtistPrimaryCollaboratorCatalogue.sol";
import {
    StreamArtistPrimaryCollaboratorLeaves as Leaves
} from "./StreamArtistPrimaryCollaboratorLeaves.sol";
import {
    StreamArtistPrimaryCollaboratorBindingLeaves as BindingLeaves
} from "./StreamArtistPrimaryCollaboratorBindingLeaves.sol";
import {
    StreamArtistPrimaryCollaboratorProposalProof as Proposal
} from "./StreamArtistPrimaryCollaboratorProposalProof.sol";
import {
    StreamArtistRecoveredMultipleGenerationCompletionProof as Terminal
} from "./StreamArtistRecoveredMultipleGenerationCompletionProof.sol";
import {
    StreamArtistRecoveredMultipleGenerationClocks as OriginalClocks
} from "./StreamArtistRecoveredMultipleGenerationClocks.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredPlatformTransitionProof as Transition
} from "./StreamArtistRecoveredPlatformTransitionProof.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import { StreamArtistAttributionStateTypes as AS } from "./StreamArtistAttributionStateTypes.sol";

import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";

/// @notice Fixed original binding transition proofs, with explicit collection projections.
/// @dev Pure/view delegate worker; only the returned cursor is copied back by Clocks.
library StreamArtistPrimaryCollaboratorClockBindingProof {
    struct Context {
        AH.Query query;
        CB.Bundle binding;
        A.Generation[] generations;
        T.CollaboratorRecord[] collaborators;
        P.Cursor cursor;
        RH.OwnerProvenance owner4;
        uint256 era;
        H.Envelope envelope;
        uint256 generation;
    }

    struct Completion {
        uint256 collectionId;
        T.Binding binding;
        RH.OwnerProvenance owner4;
        uint256 era;
        H.Envelope envelope;
        uint256 generation;
        RH.Point proposal;
    }

    function proposal(Context memory x) public pure returns (P.Cursor memory) {
        A.Generation memory generation = x.generations[x.generation];
        if (
            x.generation != x.cursor.generation || (x.generation != 0 && !x.cursor.completed)
                || generation.generation != x.generation + 1
                || generation.bindingHash != x.binding.bindings.rows[x.generation].item.bindingHash
                || generation.accepted != x.binding.bindings.rows[x.generation].item.accepted
                || generation.proposal.ownerIndex != 0
        ) _invalid();
        BindingLeaves.row(
            x.binding.bindings.rows[x.generation],
            x.query,
            uint64(x.generation + 1),
            x.owner4.origins[x.era],
            x.collaborators
        );
        BindingLeaves.correction(x.binding, x.query, x.generation, x.owner4.origins[x.era]);
        _fixedFrames(
            x.envelope,
            0x15,
            x.envelope.after_[2].revision == x.envelope.before_[2].revision ? 0x11 : 0x15
        );
        P.Platform memory platform;
        platform.collectionId = x.query.collectionId;
        x.cursor = Proposal.advance(
            platform, x.binding, x.generations, x.cursor, x.owner4, x.era, x.envelope, true
        );
        return x.cursor;
    }

    function terminal(Context memory x) public view returns (P.Cursor memory) {
        if (x.envelope.operation != 3 && x.envelope.operation != 4) _invalid();
        _fixedFrames(
            x.envelope,
            x.envelope.operation == 3 ? 0x15 : 0x11,
            x.envelope.operation == 3 ? 0x15 : 0x11
        );
        P.Platform memory platform;
        platform.collectionId = x.query.collectionId;
        x.cursor = Terminal.advance(
            platform, x.binding, x.generations, x.cursor, x.owner4, x.era, x.envelope, true
        );
        return x.cursor;
    }

    function complete(Completion memory x) public pure {
        RH.Point memory point =
            RH.Point(x.owner4.eras[x.era].originHash, 4, x.envelope.after_[4].revision);
        // The shared _attributionPoint below advances the global cursor once, after
        // the complete original transition preimage is authenticated.
        if (!Clock.beforeOwner(x.owner4, 4, x.proposal, point)) {
            _invalid();
        }
        T.Binding memory pending = abi.decode(abi.encode(x.binding), (T.Binding));
        pending.accepted = false;
        Transition.validateWithRecords(
            x.owner4.origins[x.era],
            x.owner4,
            x.era,
            x.envelope,
            keccak256(abi.encode(x.collectionId, pending, x.envelope.value)),
            keccak256(abi.encode(x.collectionId, AS.Attribution(2, uint64(x.generation + 1)))),
            0,
            0
        );
    }

    function _fixedFrames(H.Envelope memory e, uint256 observed, uint256 changed) private pure {
        T.Snapshot memory zero;
        for (uint8 i; i < 7; ++i) {
            if ((observed & (1 << i)) == 0) {
                if (
                    keccak256(abi.encode(e.before_[i])) != keccak256(abi.encode(zero))
                        || keccak256(abi.encode(e.after_[i])) != keccak256(abi.encode(zero))
                ) _invalid();
            } else if ((changed & (1 << i)) != 0) {
                if (e.after_[i].revision != e.before_[i].revision + 1) _invalid();
            } else if (keccak256(abi.encode(e.before_[i])) != keccak256(abi.encode(e.after_[i]))) {
                _invalid();
            }
        }
    }

    function bounds(uint64[7] memory lower, uint64[7] memory upper, H.Envelope memory e)
        public
        pure
    {
        for (uint8 i; i < 7; ++i) {
            T.Snapshot memory a = e.before_[i];
            T.Snapshot memory b = e.after_[i];
            if (a.domainId == 0 && b.domainId == 0) continue;
            if (
                a.domainId != RH.ownerDomain(i) || b.domainId != a.domainId || a.stateRoot == 0
                    || b.stateRoot == 0 || a.recordChainTip == 0 || b.recordChainTip == 0
                    || a.revision < lower[i] || b.revision > upper[i] || b.revision < a.revision
                    || b.revision > a.revision + 1
            ) _invalid();
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
