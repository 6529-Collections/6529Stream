// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredSimpleHydrationTypes as S
} from "../../interfaces/stream/artist/StreamArtistRecoveredSimpleHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistCollaboratorTypes as C
} from "../../interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";
import {
    StreamArtistBindingLifecycleTypes as L
} from "../../interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import {
    StreamArtistRecoveredMultipleConsentCodec as Codec
} from "./StreamArtistRecoveredMultipleConsentCodec.sol";
import {
    StreamArtistRecoveredSimpleHydration as Simple
} from "./StreamArtistRecoveredSimpleHydration.sol";
import {
    StreamArtistRecoveredCollectionHydration as Original
} from "./StreamArtistRecoveredCollectionHydration.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistCollaboratorHashes as Collaborators
} from "./StreamArtistCollaboratorHashes.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import { StreamArtistAttributionStateTypes as AS } from "./StreamArtistAttributionStateTypes.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistCollaboratorBindingOwner as Terms
} from "../../interfaces/stream/artist/IStreamArtistCollaboratorBindingOwner.sol";
import {
    IStreamArtistBindingLifecycle as Lifecycle
} from "../../interfaces/stream/artist/IStreamArtistBindingLifecycle.sol";
import {
    IStreamArtistAcceptanceOwner as Acceptance
} from "../../interfaces/stream/artist/IStreamArtistAcceptanceOwner.sol";
import {
    IStreamArtistAttributionOwner as Attribution
} from "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    IStreamArtistConsentOwner as Consent
} from "../../interfaces/stream/artist/IStreamArtistConsentOwner.sol";
import {
    IStreamArtistDelegatedConsentOwner as Delegated
} from "../../interfaces/stream/artist/IStreamArtistDelegatedConsentOwner.sol";

import {
    StreamArtistRecoveredMultipleConsentCollectionRows as Rows
} from "./StreamArtistRecoveredMultipleConsentCollectionRows.sol";

/// @notice Fixed complete source reads; original global collection validation follows unchanged.
library StreamArtistRecoveredMultipleConsentCollectionSource {
    function collect(
        T.SuiteConfiguration memory source,
        uint8 owner,
        M.State memory s,
        RH.Provenance memory full
    ) public view returns (bytes[] memory rows) {
        RH.OwnerProvenance memory p = RH.ownerProvenance(full, owner);
        Provenance.validateOwnerSource(p, owner, source.owners[owner]);
        rows = new bytes[](owner == 1 ? 0 : s.collections.length);
        for (uint256 i; i < rows.length; ++i) {
            AH.Query memory q = s.collections[i];
            if (owner == 0) {
                S.Binding memory b = S.Binding(
                    Simple.scope(q),
                    RH.ownerProvenanceHash(p, 0),
                    Binding(source.owners[0]).binding(q.collectionId),
                    Binding(source.owners[0]).bindingAt(q.collectionId, 1),
                    Terms(source.owners[0]).bindingTerms(q.collectionId, 1),
                    Lifecycle(source.owners[0]).bindingTermination(q.collectionId, 1)
                );
                rows[i] = abi.encode(b);
            } else if (owner == 3) {
                bytes32 record = Acceptance(source.owners[3]).acceptanceRecord(q.bindingHash);
                RH.JournalEntry memory proposal =
                    Rows.occurrence(RH.ownerProvenance(full, 0), q, 1, q.bindingHash);
                RH.JournalEntry memory accepted = Rows.occurrence(p, q, 2, record);
                // This profile imports only already-accepted graphs. Proposal and acceptance
                // must therefore originate in the same era, including collections added later.
                if (
                    proposal.position.point.environmentHash
                        != accepted.position.point.environmentHash
                ) _invalid();
                rows[i] = abi.encode(
                    S.Acceptance(
                        Simple.scope(q),
                        RH.ownerProvenanceHash(p, 3),
                        record,
                        Acceptance(source.owners[3]).acceptedAt(q.bindingHash)
                    )
                );
            } else if (owner == 4) {
                (uint8 state, uint64 generation) =
                    Attribution(source.owners[4]).attributionState(q.collectionId);
                RH.JournalEntry memory proposal =
                    Rows.occurrence(RH.ownerProvenance(full, 0), q, 1, q.bindingHash);
                rows[i] = abi.encode(
                    Rows.AttributionRow(
                        Original.AttributionBundle(
                            RH.ownerProvenanceHash(p, 4),
                            q.artistId,
                            q.collectionId,
                            q.bindingHash,
                            AS.Attribution(state, generation)
                        ),
                        proposal.position.point.environmentHash
                    )
                );
            } else if (owner == 6) {
                Original.PolicyBundle memory b;
                b.provenance = RH.ownerProvenanceHash(p, 6);
                b.artistId = q.artistId;
                b.collectionId = q.collectionId;
                b.policies = q.policies;
                b.records = new bytes32[](q.policies.length);
                for (uint256 j; j < b.records.length; ++j) {
                    b.records[j] = Consent(source.owners[6])
                        .policyRecord(
                            q.collectionId, q.policies[j].phaseId, q.policies[j].policyHash
                        );
                    if (Delegated(source.owners[6]).recordDelegation(b.records[j]) != 0) {
                        _invalid();
                    }
                }
                rows[i] = abi.encode(b);
            } else {
                _invalid();
            }
        }
        s.rows = rows;
        Rows.validate(owner, s, p);
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
