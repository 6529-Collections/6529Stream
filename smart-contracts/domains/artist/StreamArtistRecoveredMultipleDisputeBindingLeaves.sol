// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRepudiationTypes as RP
} from "../../interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredBindingGenerations as G
} from "./StreamArtistRecoveredBindingGenerations.sol";
import { StreamArtistBindingCorrectionState as CS } from "./StreamArtistBindingCorrectionState.sol";
import {
    StreamArtistBindingCorrectionTypes as BC
} from "../../interfaces/stream/artist/IStreamArtistBindingCorrection.sol";
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    StreamArtistBindingLifecycleTypes as L
} from "../../interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { StreamArtistCollaboratorHashes as H } from "./StreamArtistCollaboratorHashes.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistBindingCorrectionHashes as CorrectionHash
} from "./StreamArtistBindingCorrectionHashes.sol";

/// @notice Original binding/correction leaves including executed repudiation and arbiter revocation.
library StreamArtistRecoveredMultipleDisputeBindingLeaves {
    function row(
        G.Row memory r,
        AH.Query memory q,
        uint64 generation,
        RH.OriginEnvironment memory o
    ) public pure {
        if (
            r.item.artistId != q.artistId || r.item.artistAddress == address(0)
                || r.item.identityRecordHash == 0 || r.item.proposer == address(0)
                || r.item.generation != generation
                || (r.item.consentMode != 1 && r.item.consentMode != 2)
                || r.item.saleConsentScope > 1 || r.item.registryImmutabilityElection > 1
                || r.terms.count != 0 || r.terms.mode != 0 || r.terms.threshold != 0
                || r.terms.collaboratorSetHash != Hashes.emptyCollaborators()
                || r.terms.capabilityPolicySetHash != Hashes.emptyCapabilities()
                || H.binding(
                        Hashes.Environment(o.chainId, o.registry, o.core, o.manager),
                        q.collectionId,
                        r.item,
                        new T.CollaboratorRecord[](0)
                    ) != r.item.bindingHash
        ) _invalid();
    }

    function correction(
        CB.Bundle memory c,
        AH.Query memory q,
        uint256 i,
        RH.OriginEnvironment memory o
    ) public pure returns (bool) {
        CS.Correction memory row = c.corrections[i];
        if (row.recordHash == 0) {
            CS.Correction memory empty;
            if (
                keccak256(abi.encode(row)) != keccak256(abi.encode(empty))
                    || (i != 0 && c.bindings.rows[i - 1].item.accepted)
            ) _invalid();
            return false;
        }
        if (i == 0) _invalid();
        BC.Approval memory a = row.approval;
        G.Row memory previous = c.bindings.rows[i - 1];
        bytes memory originalCauseData = a.causeData;
        if (
            keccak256(abi.encode(a.previous)) != keccak256(abi.encode(previous.item))
                || a.proposalHash == 0 || a.proposedArtistId != q.artistId
                || a.registrationNonce != 0 || a.approvedAt == 0 || a.governance.actionId == 0
                || a.governance.proposer == address(0) || a.governance.actionClass != 2
        ) _invalid();
        if (previous.item.accepted || a.cause == 4) {
            if (a.cause == 3) {
                _repudiated(a, previous, q);
            } else {
                if (a.cause != 4) _invalid();
                (
                    L.Terminal memory terminal,
                    AD.Head memory head,
                    AD.Record memory opening,
                    AD.Resolution memory resolution
                ) = abi.decode(originalCauseData, (L.Terminal, AD.Head, AD.Record, AD.Resolution));
                if (
                    keccak256(originalCauseData)
                            != keccak256(abi.encode(terminal, head, opening, resolution))
                        || keccak256(abi.encode(terminal))
                            != keccak256(abi.encode(previous.terminal)) || head.open
                        || head.revocationReason != 4 || head.resolutionActionId == 0
                        || resolution.actionId != head.resolutionActionId
                        || a.causeRecord != resolution.actionId || resolution.actionClass != 2
                        || resolution.terms.resolution != 2 || resolution.restoredState != 5
                        || resolution.terms.collectionId != q.collectionId
                        || resolution.terms.bindingGeneration != previous.item.generation
                        || resolution.terms.disputeRecordHash != head.disputeRecordHash
                        || opening.recordHash != head.disputeRecordHash
                        || opening.bindingHash != previous.item.bindingHash
                        || opening.artistId != q.artistId
                ) _invalid();
            }
        } else {
            AD.Head memory emptyHead;
            if (
                a.cause != previous.terminal.kind || (a.cause != 1 && a.cause != 2)
                    || a.causeRecord
                        != (a.cause == 1 ? previous.terminal.recordHash : previous.item.bindingHash)
                    || keccak256(originalCauseData)
                        != keccak256(abi.encode(previous.terminal, emptyHead))
            ) _invalid();
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
                || row.recordHash
                    != CorrectionHash.hash(
                        Hashes.Environment(o.chainId, o.registry, o.core, o.manager),
                        q.collectionId,
                        c.bindings.rows[i].item.bindingHash,
                        a
                    )
        ) _invalid();
        for (uint256 j; j < i; ++j) {
            if (
                c.corrections[j].recordHash != 0
                    && (c.corrections[j].recordHash == row.recordHash
                        || c.corrections[j].approval.governance.actionId == a.governance.actionId)
            ) _invalid();
        }
        return true;
    }

    function _repudiated(BC.Approval memory a, G.Row memory previous, AH.Query memory q)
        private
        pure
    {
        bytes memory originalCauseData = a.causeData;
        (
            L.Terminal memory terminal,
            AD.Head memory head,
            RP.Record memory record,
            RP.Terminal memory end
        ) = abi.decode(originalCauseData, (L.Terminal, AD.Head, RP.Record, RP.Terminal));
        if (
            keccak256(originalCauseData) != keccak256(abi.encode(terminal, head, record, end))
                || keccak256(abi.encode(terminal)) != keccak256(abi.encode(previous.terminal))
                || head.open || head.revocationReason != 3 || record.recordHash == 0
                || a.causeRecord != record.recordHash || record.artistId != q.artistId
                || record.bindingHash != previous.item.bindingHash
                || record.terms.collectionId != q.collectionId
                || record.terms.bindingGeneration != previous.item.generation
                || record.terms.disputeAction != 4 || end.phase != 4 || end.actor == address(0)
                || end.recordedAt < record.executableAt || end.reasonHash != record.terms.reasonHash
        ) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
