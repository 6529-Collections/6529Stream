// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredBindingGenerations as G
} from "./StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistRecoveredMultipleGenerationBindingLeaves as Original
} from "./StreamArtistRecoveredMultipleGenerationBindingLeaves.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { StreamArtistCollaboratorHashes as Hashes } from "./StreamArtistCollaboratorHashes.sol";
import { StreamArtistHashes as OriginalHash } from "./StreamArtistHashes.sol";

/// @notice Exact original binding fields and complete sorted collaborator terms under PRIMARY_ONLY.
/// @dev Nonempty terms do not admit any collaborator quorum policy. Correction leaves retain
/// their separately authenticated original governance/dispute/cause predicates unchanged.
library StreamArtistPrimaryCollaboratorBindingLeaves {
    function row(
        G.Row memory r,
        AH.Query memory q,
        uint64 generation,
        RH.OriginEnvironment memory o,
        T.CollaboratorRecord[] memory collaborators
    ) public pure {
        if (
            r.item.artistId != q.artistId || r.item.artistAddress == address(0)
                || r.item.identityRecordHash == 0 || r.item.proposer == address(0)
                || r.item.generation != generation
                || (r.item.consentMode != 1 && r.item.consentMode != 2)
                || r.item.saleConsentScope > 1 || r.item.registryImmutabilityElection > 1
                || r.terms.mode != 0 || r.terms.threshold != 0
                || r.terms.count != collaborators.length || collaborators.length > 32
                || r.terms.collaboratorSetHash != Hashes.collaboratorSetHash(collaborators)
                || r.terms.capabilityPolicySetHash != OriginalHash.emptyCapabilities()
                || Hashes.binding(
                        OriginalHash.Environment(o.chainId, o.registry, o.core, o.manager),
                        q.collectionId,
                        r.item,
                        collaborators
                    ) != r.item.bindingHash
        ) _invalid();
        for (uint256 i; i < collaborators.length; ++i) {
            T.CollaboratorRecord memory current = collaborators[i];
            if (current.account == address(0)) _invalid();
            if (i != 0) {
                T.CollaboratorRecord memory prior = collaborators[i - 1];
                if (
                    uint160(current.account) < uint160(prior.account)
                        || (current.account == prior.account
                            && uint256(current.role) <= uint256(prior.role))
                ) _invalid();
            }
        }
    }

    function correction(
        CB.Bundle memory b,
        AH.Query memory q,
        uint256 i,
        RH.OriginEnvironment memory o
    ) public pure returns (bool) {
        return Original.correction(b, q, i, o);
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
