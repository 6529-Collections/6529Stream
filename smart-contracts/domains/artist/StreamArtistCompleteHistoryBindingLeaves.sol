// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistBindingLifecycleTypes as L
} from "../../interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import {
    StreamArtistBindingCorrectionTypes as BC
} from "../../interfaces/stream/artist/IStreamArtistBindingCorrection.sol";
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    StreamArtistRepudiationTypes as RP
} from "../../interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";
import {
    StreamArtistRecoveredBindingGenerations as G
} from "./StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import { StreamArtistBindingCorrectionState as CS } from "./StreamArtistBindingCorrectionState.sol";
import {
    StreamArtistPrimaryCollaboratorBindingLeaves as Original
} from "./StreamArtistPrimaryCollaboratorBindingLeaves.sol";
import {
    StreamArtistCompleteHistoryBindingTypes as Types
} from "./StreamArtistCompleteHistoryBindingTypes.sol";
import {
    StreamArtistPlatformCorrectionState as Platform
} from "./StreamArtistPlatformCorrectionState.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistBindingCorrectionHashes as CorrectionHash
} from "./StreamArtistBindingCorrectionHashes.sol";

/// @notice Exact original PRIMARY_ONLY rows and correction approvals with genuine historical principals.
/// @dev Native/Archive, Identity allocation and Platform lineage joins are proved by the fixed
/// enclosing workers. These leaves never infer authority from the latest collection principal.
library StreamArtistCompleteHistoryBindingLeaves {
    function row(
        G.Row memory r,
        AH.Query memory q,
        uint64 generation,
        RH.OriginEnvironment memory o,
        T.CollaboratorRecord[] memory collaborators
    ) public pure {
        if (generation == 0) _invalid();
        Original.row(r, Types.rowQuery(q, r), generation, o, collaborators);
        terminal(r);
    }

    function terminal(G.Row memory r) public pure {
        if (r.item.accepted || r.terminal.kind == 0) {
            L.Terminal memory empty;
            if (keccak256(abi.encode(r.terminal)) != keccak256(abi.encode(empty))) _invalid();
        } else if (
            r.terminal.kind > 2 || r.terminal.reasonHash == 0
                || (r.terminal.kind == 1 ? r.terminal.recordHash == 0 : r.terminal.recordHash != 0)
        ) {
            _invalid();
        }
    }

    function correction(
        CB.Bundle memory c,
        AH.Query memory q,
        uint256 i,
        RH.OriginEnvironment memory o
    ) public pure returns (bool) {
        if (i >= c.bindings.rows.length || c.corrections.length != c.bindings.rows.length) _invalid();
        CS.Correction memory saved = c.corrections[i];
        if (saved.recordHash == 0) {
            CS.Correction memory empty;
            if (
                keccak256(abi.encode(saved)) != keccak256(abi.encode(empty))
                    || (i != 0
                        && (c.bindings.rows[i - 1].item.accepted
                            || c.bindings.rows[i - 1].terminal.kind == 0))
            ) _invalid();
            return false;
        }
        if (i == 0) _invalid();
        BC.Approval memory a = saved.approval;
        G.Row memory previous = c.bindings.rows[i - 1];
        T.Binding memory next = c.bindings.rows[i].item;
        if (
            keccak256(abi.encode(a.previous)) != keccak256(abi.encode(previous.item))
                || a.proposalHash == 0 || next.artistId == 0 || a.proposedArtistId != next.artistId
                || a.approvedAt == 0 || a.governance.actionId == 0
                || a.governance.proposer == address(0) || a.governance.actionClass != 2
                || next.generation != previous.item.generation + 1
        ) _invalid();
        // Zero also represents an existing identity. The authenticated proposal payload
        // distinguishes that case from allocation zero and proves the complete allocator.
        if (
            a.registrationNonce != 0
                && next.artistId
                    != Hashes.identity(
                        Hashes.Environment(o.chainId, o.registry, o.core, o.manager),
                        next.artistAddress,
                        next.identityRecordHash,
                        a.registrationNonce
                    )
        ) _invalid();

        bytes memory cause = Platform.tagged(a.causeData)
            ? Platform.decode(a.causeData).originalCauseData
            : a.causeData;
        if (!previous.item.accepted && (previous.terminal.kind == 1 || previous.terminal.kind == 2))
        {
            _terminated(a, previous, cause);
        } else if (a.cause == 4) {
            _revoked(a, previous, q.collectionId, cause);
        } else {
            if (!previous.item.accepted || a.cause != 3) _invalid();
            _repudiated(a, previous, q.collectionId, cause);
        }
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_BINDING_CORRECTION_SCOPE_V1"),
                o.chainId,
                o.registry,
                o.core,
                o.manager,
                q.collectionId,
                previous.item.generation
            )
        );
        bytes32 oldValue =
            keccak256(abi.encode(a.previous, uint8(5), a.cause, a.causeRecord, a.causeData));
        if (
            a.governance.scopeHash != scope || a.governance.oldValueHash != oldValue
                || a.governance.newValueHash
                    != keccak256(
                        abi.encode(
                            scope, oldValue, a.proposalHash, a.proposedArtistId, a.registrationNonce
                        )
                    )
                || saved.recordHash
                    != CorrectionHash.hash(
                        Hashes.Environment(o.chainId, o.registry, o.core, o.manager),
                        q.collectionId,
                        next.bindingHash,
                        a
                    )
        ) _invalid();
        for (uint256 j; j < i; ++j) {
            if (
                c.corrections[j].recordHash != 0
                    && (c.corrections[j].recordHash == saved.recordHash
                        || c.corrections[j].approval.governance.actionId == a.governance.actionId)
            ) _invalid();
        }
        return true;
    }

    function _terminated(BC.Approval memory a, G.Row memory previous, bytes memory cause)
        private
        pure
    {
        (L.Terminal memory end, AD.Head memory head) = abi.decode(cause, (L.Terminal, AD.Head));
        if (
            keccak256(cause) != keccak256(abi.encode(end, head))
                || keccak256(abi.encode(end)) != keccak256(abi.encode(previous.terminal))
                || head.open || a.cause != end.kind || end.reasonHash == 0
                || (end.kind == 1 ? end.recordHash == 0 : end.recordHash != 0)
                || a.causeRecord != (end.kind == 1 ? end.recordHash : previous.item.bindingHash)
        ) _invalid();
    }

    function _revoked(BC.Approval memory a, G.Row memory previous, uint256 id, bytes memory cause)
        private
        pure
    {
        (
            L.Terminal memory end,
            AD.Head memory head,
            AD.Record memory opening,
            AD.Resolution memory resolution
        ) = abi.decode(cause, (L.Terminal, AD.Head, AD.Record, AD.Resolution));
        L.Terminal memory empty;
        if (
            keccak256(cause) != keccak256(abi.encode(end, head, opening, resolution))
                || keccak256(abi.encode(end)) != keccak256(abi.encode(previous.terminal))
                || keccak256(abi.encode(end)) != keccak256(abi.encode(empty)) || head.open
                || head.revocationReason != 4 || head.resolutionActionId == 0
                || resolution.actionId != head.resolutionActionId
                || a.causeRecord != resolution.actionId || resolution.actionClass != 2
                || resolution.terms.resolution != 2 || resolution.restoredState != 5
                || resolution.terms.collectionId != id
                || resolution.terms.bindingGeneration != previous.item.generation
                || resolution.terms.disputeRecordHash != head.disputeRecordHash
                || opening.recordHash != head.disputeRecordHash
                || opening.bindingHash != previous.item.bindingHash
                || opening.artistId != previous.item.artistId
        ) _invalid();
    }

    function _repudiated(
        BC.Approval memory a,
        G.Row memory previous,
        uint256 id,
        bytes memory cause
    ) private pure {
        (
            L.Terminal memory end,
            AD.Head memory head,
            RP.Record memory record,
            RP.Terminal memory result
        ) = abi.decode(cause, (L.Terminal, AD.Head, RP.Record, RP.Terminal));
        L.Terminal memory empty;
        if (
            keccak256(cause) != keccak256(abi.encode(end, head, record, result))
                || keccak256(abi.encode(end)) != keccak256(abi.encode(previous.terminal))
                || keccak256(abi.encode(end)) != keccak256(abi.encode(empty)) || head.open
                || head.revocationReason != 3 || record.recordHash == 0
                || a.causeRecord != record.recordHash || record.artistId != previous.item.artistId
                || record.bindingHash != previous.item.bindingHash
                || record.terms.collectionId != id
                || record.terms.bindingGeneration != previous.item.generation
                || record.terms.disputeAction != 4 || result.phase != 4
                || result.actor == address(0) || result.recordedAt < record.executableAt
                || result.reasonHash != record.terms.reasonHash
        ) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
