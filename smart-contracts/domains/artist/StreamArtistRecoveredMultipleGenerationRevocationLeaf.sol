// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    StreamArtistRecoveredHydrationProvenance as P
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import { StreamArtistDisputeHashes as H } from "./StreamArtistDisputeHashes.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";

/// @notice Exact original governed-opening and class2-revocation body predicates.
library StreamArtistRecoveredMultipleGenerationRevocationLeaf {
    function row(
        A.Revocation memory r,
        A.Generation memory g,
        AH.Query memory q,
        RH.OriginEnvironment memory o
    ) public pure {
        AD.Record memory a = r.opening;
        AD.Resolution memory d = r.resolution;
        AD.Head memory h = r.head;
        AD.Standing memory empty;
        if (
            a.recordHash == 0 || a.terms.collectionId != q.collectionId
                || a.terms.bindingGeneration != g.generation || a.terms.disputeAction != 1
                || a.terms.evidenceHash == 0 || a.terms.reasonHash == 0 || a.signer == address(0)
                || a.authorityClass != 0 || a.nonce != 0 || a.recordedAt == 0
                || a.artistId != q.artistId || a.bindingHash != g.bindingHash
                || a.disputeRecordHash != a.recordHash || a.previousRecordHash != 0
                || keccak256(abi.encode(a.standing)) != keccak256(abi.encode(empty))
                || a.governanceActionId == 0
                || a.recordHash
                    != H.record(
                        Hashes.Environment(o.chainId, o.registry, o.core, o.manager),
                        a.terms,
                        a.signer,
                        0,
                        0,
                        a.recordedAt
                    )
        ) _invalid();
        if (
            h.disputeRecordHash != a.recordHash || h.counterStatementRecordHash != 0
                || h.resolutionActionId != d.actionId || h.restoreState != 2
                || h.revocationReason != 4 || h.open || h.reopened || d.actionId == 0
                || d.actionId == a.governanceActionId || d.actor == address(0)
                || d.proposer == address(0) || d.actionClass != 2 || d.restoredState != 5
                || d.resolvedAt < a.recordedAt || d.previousResolutionActionId != 0
                || d.witnessHash == 0 || d.terms.collectionId != q.collectionId
                || d.terms.bindingGeneration != g.generation
                || d.terms.disputeRecordHash != a.recordHash || d.terms.resolution != 2
                || d.terms.evidenceHash == 0 || d.terms.reasonHash == 0
                || d.terms.counterStatementRecordHash != 0
        ) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
