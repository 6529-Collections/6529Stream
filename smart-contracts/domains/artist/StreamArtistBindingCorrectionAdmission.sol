// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistBindingCorrectionTypes as BC
} from "../../interfaces/stream/artist/IStreamArtistBindingCorrection.sol";
import "../../interfaces/stream/artist/IStreamArtistBindingLifecycle.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";
import {
    StreamArtistRepudiationTypes as RP
} from "../../interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import "./StreamArtistGovernanceWitness.sol";
import { StreamArtistPlatformTypes as PW } from "../../interfaces/stream/artist/StreamArtistPlatformTypes.sol";
import { StreamArtistPlatformCorrectionState as PlatformState } from "./StreamArtistPlatformCorrectionState.sol";
import { StreamArtistPlatformCorrectionLineageTypes as PL, IStreamArtistPlatformCorrectionLineage as PlatformLineage } from "../../interfaces/stream/artist/IStreamArtistPlatformCorrectionLineage.sol";
import { IStreamArtistPlatformOwner } from "../../interfaces/stream/artist/IStreamArtistPlatformWorks.sol";
import "./StreamArtistTimingState.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";

/// @notice Exact original stored terminal cause and staged class2 authority for a new op1 generation.
library StreamArtistBindingCorrectionAdmission {
    function context(
        T.SuiteConfiguration memory s,
        uint256 id,
        T.BindingProposal memory proposal,
        bytes memory document,
        string memory displayName,
        bytes32 repudiation
    ) public view returns (BC.Context memory c, BC.Approval memory a) {
        a.previous = IStreamArtistBindingOwner(s.owners[0]).binding(id);
        (uint8 state, uint64 generation) =
            IStreamArtistAttributionOwner(s.owners[4]).attributionState(id);
        if (
            state != 5 || generation == 0 || generation != a.previous.generation
                || a.previous.bindingHash == 0 || proposal.reasonHash == 0
        ) revert BC.InvalidBindingCorrection(id);
        L.Terminal memory terminal =
            IStreamArtistBindingLifecycle(s.owners[0]).bindingTermination(id, generation);
        AD.Head memory head =
            IStreamArtistAttributionDisputesOwner(s.owners[4]).attributionDispute(id, generation);
        if (head.open) revert BC.InvalidBindingCorrection(id);
        if (!a.previous.accepted && (terminal.kind == 1 || terminal.kind == 2)) {
            if (
                repudiation != 0 || terminal.reasonHash == 0
                    || (terminal.kind == 1 ? terminal.recordHash == 0 : terminal.recordHash != 0)
            ) {
                revert BC.InvalidBindingCorrection(id);
            }
            a.cause = terminal.kind;
            a.causeRecord = terminal.kind == 1 ? terminal.recordHash : a.previous.bindingHash;
            a.causeData = abi.encode(terminal, head);
        } else if (head.revocationReason == 4) {
            if (repudiation != 0 || terminal.kind != 0 || head.resolutionActionId == 0) {
                revert BC.InvalidBindingCorrection(id);
            }
            AD.Resolution memory r = IStreamArtistAttributionDisputesOwner(s.owners[4])
                .attributionDisputeResolution(head.resolutionActionId);
            AD.Record memory opening = IStreamArtistAttributionDisputesOwner(s.owners[4])
                .attributionDisputeRecord(head.disputeRecordHash);
            if (
                r.actionId != head.resolutionActionId || r.actionClass != 2
                    || r.terms.resolution != 2 || r.terms.collectionId != id
                    || r.terms.bindingGeneration != generation
                    || r.terms.disputeRecordHash != head.disputeRecordHash || r.restoredState != 5
                    || opening.recordHash != head.disputeRecordHash
                    || opening.bindingHash != a.previous.bindingHash
                    || opening.artistId != a.previous.artistId
            ) revert BC.InvalidBindingCorrection(id);
            a.cause = 4;
            a.causeRecord = r.actionId;
            a.causeData = abi.encode(terminal, head, opening, r);
        } else if (a.previous.accepted && head.revocationReason == 3) {
            RP.Record memory r = IStreamArtistRepudiationOwner(s.owners[4])
                .attributionRepudiationRecord(repudiation);
            RP.Terminal memory t = IStreamArtistRepudiationOwner(s.owners[4])
                .attributionRepudiationTerminal(repudiation);
            if (
                repudiation == 0 || terminal.kind != 0 || r.recordHash != repudiation
                    || r.terms.collectionId != id || r.terms.bindingGeneration != generation
                    || r.bindingHash != a.previous.bindingHash || r.artistId != a.previous.artistId
                    || t.phase != 4 || t.recordedAt < r.executableAt
                    || t.reasonHash != r.terms.reasonHash
            ) {
                revert BC.InvalidBindingCorrection(id);
            }
            a.cause = 3;
            a.causeRecord = repudiation;
            a.causeData = abi.encode(terminal, head, r, t);
        } else {
            revert BC.InvalidBindingCorrection(id);
        }
        PW.State memory platform = IStreamArtistPlatformOwner(s.owners[4]).platformWorksState(id);
        if (platform.declaration.recordHash != 0 && platform.correction.correctiveGeneration != 0) {
            PL.Status memory prior = PlatformLineage(s.owners[4]).platformCorrectionStatus(id);
            a.causeData = abi.encode(PL.WITNESS,
                PL.Witness(a.causeData, PlatformState.pins(platform), prior));
        }
        a.proposalHash = keccak256(abi.encode(id, proposal, document, displayName));
        a.proposedArtistId = proposal.artistId;
        if (a.proposedArtistId == 0) {
            a.registrationNonce = IStreamArtistIdentityOwner(s.owners[2]).nextRegistrationNonce();
            a.proposedArtistId = Hashes.identity(
                Hashes.Environment(block.chainid, s.registry, s.core, s.mintManager),
                proposal.artistAddress,
                proposal.identityRecordHash,
                a.registrationNonce
            );
        }
        c.scopeHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_BINDING_CORRECTION_SCOPE_V1"),
                block.chainid,
                s.registry,
                s.core,
                s.mintManager,
                id,
                generation
            )
        );
        c.oldValueHash =
            keccak256(abi.encode(a.previous, state, a.cause, a.causeRecord, a.causeData));
        c.newValueHash = keccak256(
            abi.encode(
                c.scopeHash, c.oldValueHash, a.proposalHash, a.proposedArtistId, a.registrationNonce
            )
        );
    }

    function admit(
        D.CoordinatorContext memory x,
        address actor,
        uint256 id,
        T.BindingProposal memory proposal,
        bytes memory document,
        string memory displayName,
        bytes32 repudiation
    ) public view returns (BC.Context memory c, BC.Approval memory a) {
        address authority = StreamArtistTimingState.canonicalAuthority(
                x.suite.core, x.suite.mintManager
            );
        if (actor != authority) revert T.Unauthorized(actor);
        (c, a) = context(x.suite, id, proposal, document, displayName, repudiation);
        a.governance = StreamArtistGovernanceWitness.read(
            x, authority, proposal.reasonHash, c.scopeHash, c.oldValueHash, c.newValueHash
        );
        if (a.governance.actionClass != 2 || block.timestamp > type(uint64).max) {
            revert BC.InvalidBindingCorrection(id);
        }
        a.approvedAt = uint64(block.timestamp);
    }
}
