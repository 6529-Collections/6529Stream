// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    IStreamArtistRecoveryRewindSelection as Selection,
    IStreamArtistRecoveryRewindSelectionBinding as Binding
} from "../../interfaces/stream/artist/IStreamArtistRecoveryRewindSelection.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";
import {
    StreamArtistRecoveredIdentityHydrationState as X
} from "./StreamArtistRecoveredIdentityHydrationState.sol";

/// @notice Fixed continuation producer over the complete canonical owner-supplied Bundle.
/// @dev Called through the typed veneer after complete abi.encode traversal of all 34 fields.
/// Frame supplies only a bounded view, not authentication or independent raw-bytes admission.
/// Linked calls retain the owner's declared storage roots and address context. Historical
/// fixed selections still resolve to exact actual stored tuples in original check order.
library StreamArtistRecoveredIdentityContinuationRows {
    struct Rows {
        IH.OriginalContinuationRow[] originalContinuations;
        IH.RevisionContinuationRow[] revisionContinuations;
        IH.StandingContinuationRow[] standingContinuations;
        IH.CapabilityContinuationRow[] capabilityContinuations;
    }

    function collect(
        uint256[17] memory roots,
        bytes calldata canonicalBundle,
        RH.OwnerProvenance memory local
    ) public view returns (bytes memory) {
        IH.Bundle calldata b = Frame.bundle(canonicalBundle);
        Rows memory rows;
        rows.originalContinuations = new IH.OriginalContinuationRow[](b.dismissals.length);
        uint256 count;
        for (uint256 i; i < b.dismissals.length; ++i) {
            bytes32 key = b.dismissals[i].record.revisionContinuationHead;
            if (key == 0) continue;
            bool seen;
            for (uint256 j; j < count; ++j) {
                if (rows.originalContinuations[j].continuation.continuationHash == key) {
                    seen = true;
                }
            }
            if (seen) continue;
            IH.OriginalContinuationRow memory r;
            r.continuation = X.resolutions(roots).continuations[key];
            if (r.continuation.continuationHash != key || r.continuation.artistId != b.artistId) {
                revert IH.InvalidRecoveredIdentity(key);
            }
            r.point = _dismissalPoint(b, r.continuation.dismissalRecordHash);
            rows.originalContinuations[count++] = r;
        }
        // Array lengths are reduced through dedicated helpers; no Bundle layout offsets are used.
        rows.originalContinuations = _originalPrefix(rows.originalContinuations, count);
        rows.revisionContinuations = new IH.RevisionContinuationRow[](b.revisions.length);
        rows.standingContinuations = new IH.StandingContinuationRow[](b.standingRecords.length);
        rows.capabilityContinuations = new IH.CapabilityContinuationRow[](b.recoveries.length);
        uint256 revisions;
        uint256 standing;
        uint256 caps;
        for (uint256 i; i < b.recoveries.length; ++i) {
            IH.RecoveryRow memory recovery = b.recoveries[i];
            bytes32 action = recovery.record.fields.governanceActionId;
            W.EvidenceStateV3 memory evidence = X.rewinds(roots).actions[action];
            if (evidence.manifestHash == 0) continue;
            RH.Point memory preparedPoint = _actionPoint(b, action);
            RH.OriginEnvironment memory source = _origin(local, preparedPoint.environmentHash);
            (address selector, bytes32 pin) =
                Binding(source.owners[2]).recoveryRewindSelectionBinding();
            if (
                selector == address(0) || pin == 0 || selector.codehash != pin
                    || Selection(selector).owner() != source.owners[2]
                    || Selection(selector).payoutOwner() != source.owners[5]
                    || Selection(selector).artistRegistry() != source.registry
                    || Selection(selector).coordinator() != source.coordinator
                    || Selection(selector).deploymentChainId() != source.chainId
            ) revert IH.InvalidRecoveredIdentity(action);
            (W.BasisV3 memory basis, W.ProgressV3 memory progress) =
                Selection(selector).selectionV3(evidence.sourceKey);
            W.ResultV3 memory result = Selection(selector).selectionResultV3(evidence.sourceKey);
            if (
                !progress.complete || result.manifestHash != evidence.manifestHash
                    || result.sourceKey != evidence.sourceKey
                    || result.commitment != evidence.selectionCommitment
                    || progress.resultCommitment != result.commitment
                    || result.sourceCommitment != evidence.sourceCommitment
                    || basis.identity.artistId != b.artistId
            ) revert IH.InvalidRecoveredIdentity(action);
            W.EnvironmentV3 memory e =
                _environment(_origin(local, recovery.position.point.environmentHash));
            bytes32 tip = basis.identity.inventory.revisions.candidate == 0
                ? basis.identity.inventory.revisions.stable
                : basis.identity.inventory.revisions.candidate;
            if (
                tip != 0 && tip != result.identityRevision.operative.recordHash
                    && result.identityRevision.retainedCandidateRecordHash == 0
                    && X.rewinds(roots).statuses[tip].recoveryRecordHash
                        == recovery.record.recordHash
                    && X.rewinds(roots).statuses[tip].kind == W.RecordKind.IDENTITY_REVISION
            ) {
                W.RevisionContinuationV3 memory c;
                c.artistId = b.artistId;
                c.recoveryRecordHash = recovery.record.recordHash;
                c.actionId = action;
                c.planCommitment = result.commitment;
                c.stableRevisionRecordHash = result.identityRevision.operative.recordHash;
                c.stableDocumentHash = c.stableRevisionRecordHash == 0
                    ? b.identity.identityRecordHash
                    : X.revisions(roots).records[c.stableRevisionRecordHash].revisedRecordHash;
                c.resolvedChildRecordHash = tip;
                c.ownerRevision = recovery.position.point.ownerRevision;
                c.continuationHash = W.revisionContinuationHash(e, c);
                if (
                    revisions >= rows.revisionContinuations.length
                        || keccak256(abi.encode(c))
                            != keccak256(
                                abi.encode(
                                    X.rewinds(roots).revisionContinuations[c.continuationHash]
                                )
                            )
                ) revert IH.InvalidRecoveredIdentity(c.continuationHash);
                rows.revisionContinuations[revisions++] =
                    IH.RevisionContinuationRow(recovery.position.point, c);
            }
            for (uint256 j; j < result.standing.length; ++j) {
                W.StandingSelectionV3 memory s = result.standing[j];
                // The original35 creates a fresh retirement of its old incumbent before apply.
                if (
                    s.priorAddress == recovery.record.fields.oldAddress
                        || s.retainedRevocation.recordHash == s.expectedRevocationRecordHash
                ) continue;
                if (
                    s.expectedRevocationRecordHash == 0
                        || X.rewinds(roots)
                            .statuses[s.expectedRevocationRecordHash].recoveryRecordHash
                            != recovery.record.recordHash
                ) revert IH.InvalidRecoveredIdentity(s.expectedRevocationRecordHash);
                W.StandingContinuationV3 memory c = W.StandingContinuationV3(
                    b.artistId,
                    s.priorAddress,
                    s.retirementHash,
                    recovery.record.recordHash,
                    action,
                    result.commitment,
                    s.retainedRevocation.recordHash,
                    s.expectedRevocationRecordHash,
                    recovery.position.point.ownerRevision,
                    bytes32(0)
                );
                c.continuationHash = W.standingContinuationHash(e, c);
                if (
                    standing >= rows.standingContinuations.length
                        || keccak256(abi.encode(c))
                            != keccak256(
                                abi.encode(
                                    X.rewinds(roots).standingContinuations[c.continuationHash]
                                )
                            )
                ) revert IH.InvalidRecoveredIdentity(c.continuationHash);
                bytes32 scope = keccak256(abi.encode(b.artistId, c.priorAddress, c.retirementHash));
                rows.standingContinuations[standing++] = IH.StandingContinuationRow(
                    recovery.position.point, c, X.rewinds(roots).standingHeads[scope]
                );
            }
            W.CapabilityContinuationV3 memory cap =
                X.rewinds(roots).capabilityContinuations[recovery.record.recordHash];
            if (cap.commitment != 0) {
                if (
                    cap.recoveryRecordHash != recovery.record.recordHash
                        || cap.artistId != b.artistId || cap.actionId != action
                        || cap.manifestHash != evidence.manifestHash
                        || cap.planCommitment != result.commitment
                        || cap.commitment != W.capabilityContinuationHash(e, cap)
                ) revert IH.InvalidRecoveredIdentity(recovery.record.recordHash);
                rows.capabilityContinuations[caps++] =
                    IH.CapabilityContinuationRow(recovery.position.point, cap);
            }
        }
        rows.revisionContinuations = _revisionPrefix(rows.revisionContinuations, revisions);
        rows.standingContinuations = _standingPrefix(rows.standingContinuations, standing);
        rows.capabilityContinuations = _capabilityPrefix(rows.capabilityContinuations, caps);
        return abi.encode(
            rows.originalContinuations,
            rows.revisionContinuations,
            rows.standingContinuations,
            rows.capabilityContinuations
        );
    }

    function _actionPoint(IH.Bundle calldata b, bytes32 key)
        private
        pure
        returns (RH.Point memory)
    {
        for (uint256 i; i < b.actions.length; ++i) {
            if (b.actions[i].association.action.actionId == key) {
                return b.actions[i].point;
            }
        }
        revert IH.InvalidRecoveredIdentity(key);
    }

    function _dismissalPoint(IH.Bundle calldata b, bytes32 key)
        private
        pure
        returns (RH.Point memory)
    {
        for (uint256 i; i < b.dismissals.length; ++i) {
            if (b.dismissals[i].record.recordHash == key) {
                return b.dismissals[i].position.point;
            }
        }
        revert IH.InvalidRecoveredIdentity(key);
    }

    function _origin(RH.OwnerProvenance memory p, bytes32 hash)
        private
        pure
        returns (RH.OriginEnvironment memory)
    {
        for (uint256 i; i < p.origins.length; ++i) {
            if (RH.originHash(p.origins[i]) == hash) return p.origins[i];
        }
        revert IH.InvalidRecoveredIdentity(hash);
    }

    function _environment(RH.OriginEnvironment memory o)
        private
        pure
        returns (W.EnvironmentV3 memory)
    {
        return W.EnvironmentV3(
            o.chainId,
            o.registry,
            o.owners[2],
            o.ownerCodeHashes[2],
            o.owners[5],
            o.ownerCodeHashes[5],
            o.coordinator,
            o.archive,
            o.core,
            o.manager
        );
    }

    function _originalPrefix(IH.OriginalContinuationRow[] memory a, uint256 n)
        private
        pure
        returns (IH.OriginalContinuationRow[] memory)
    {
        assembly ("memory-safe") { mstore(a, n) }
        return a;
    }

    function _revisionPrefix(IH.RevisionContinuationRow[] memory a, uint256 n)
        private
        pure
        returns (IH.RevisionContinuationRow[] memory)
    {
        assembly ("memory-safe") { mstore(a, n) }
        return a;
    }

    function _standingPrefix(IH.StandingContinuationRow[] memory a, uint256 n)
        private
        pure
        returns (IH.StandingContinuationRow[] memory)
    {
        assembly ("memory-safe") { mstore(a, n) }
        return a;
    }

    function _capabilityPrefix(IH.CapabilityContinuationRow[] memory a, uint256 n)
        private
        pure
        returns (IH.CapabilityContinuationRow[] memory)
    {
        assembly ("memory-safe") { mstore(a, n) }
        return a;
    }
}
