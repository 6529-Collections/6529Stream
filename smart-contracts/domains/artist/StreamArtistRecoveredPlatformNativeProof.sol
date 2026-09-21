// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredPlatformPayload as Payload
} from "./StreamArtistRecoveredPlatformPayload.sol";
import {
    StreamArtistRecoveredPlatformTransitionProof as Transition
} from "./StreamArtistRecoveredPlatformTransitionProof.sol";
import {
    StreamArtistPlatformTypes as PW
} from "../../interfaces/stream/artist/StreamArtistPlatformTypes.sol";
import {
    StreamArtistAttributionClaimTypes as AC
} from "../../interfaces/stream/artist/IStreamArtistAttributionClaims.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Authenticated original Archive payloads bind all original Platform record fields.
library StreamArtistRecoveredPlatformNativeProof {
    function advance(
        P.Platform memory b,
        PW.State memory current,
        RH.OwnerProvenance memory p,
        uint256 era,
        H.Envelope memory e
    ) public pure returns (PW.State memory) {
        RH.OriginEnvironment memory o = p.origins[era];
        RH.Point memory point = RH.Point(p.eras[era].originHash, 4, e.after_[4].revision);
        bytes32 scope;
        bytes32 action = e.value;
        bytes32 state;
        bytes32 primary = e.operation == 11 ? bytes32(0) : e.value;
        if (e.operation == 8) {
            (uint256 id, bytes32 statement, bytes32 role, uint64 revision) =
                abi.decode(e.payload, (uint256, bytes32, bytes32, uint64));
            if (
                keccak256(e.payload) != keccak256(abi.encode(id, statement, role, revision))
                    || id != b.collectionId || statement != b.state.declaration.statementHash
                    || e.actor != b.state.declaration.actor
                    || e.value != b.state.declaration.recordHash
                    || !D.samePoint(point, b.declarationPoint)
                    || current.declaration.recordHash != 0
            ) {
                _invalid();
            }
            current.declaration = b.state.declaration;
            scope = bytes32(id);
        } else if (e.operation == 9 || e.operation == 10) {
            Payload.Claim memory c = Payload.claim(e.payload);
            _documents(
                b.collectionId, c.evidence, c.reason, 0, c.evidenceDocument, c.reasonDocument
            );
            if (c.id != b.collectionId || bytes(c.uri).length > 4096) _invalid();
            scope = keccak256(abi.encode(c.id, e.actor, c.evidence, c.reason));
            if (e.operation == 9) {
                PW.Claim memory r = _claim(b, point);
                if (
                    r.recordHash != e.value || r.claimant != e.actor || r.evidenceHash != c.evidence
                        || r.reasonHash != c.reason
                        || r.proposedArtist != c.evidenceDocument.proposedArtist
                ) _invalid();
                ++current.claimCount;
                current.latestClaim = r.recordHash;
            } else {
                AC.Claim memory r = _allegation(b, point);
                if (
                    r.recordHash != e.value || r.claimant != e.actor || r.evidenceHash != c.evidence
                        || r.reasonHash != c.reason
                        || r.proposedArtist != c.evidenceDocument.proposedArtist
                        || keccak256(bytes(r.reasonURI)) != keccak256(bytes(c.uri))
                ) _invalid();
                state = keccak256(abi.encode(r));
                action = keccak256(
                    abi.encode(
                        c.id,
                        e.actor,
                        c.evidence,
                        c.reason,
                        c.uri,
                        c.evidenceDocument.proposedArtist
                    )
                );
            }
        } else if (e.operation == 11 || e.operation == 53) {
            Payload.ContestPayload memory c = Payload.contest(e.payload);
            bool correction = e.operation == 53;
            _documents(
                b.collectionId, c.evidence, c.reason, c.claim, c.evidenceDocument, c.reasonDocument
            );
            PW.Context memory expected;
            expected.scopeHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_PLATFORM_WORKS_GOVERNANCE_SCOPE_V1"),
                    o.chainId,
                    o.registry,
                    o.core,
                    b.collectionId,
                    correction
                )
            );
            expected.oldValueHash = keccak256(
                abi.encode(
                    current.declaration,
                    current.contestState,
                    current.contestClaim,
                    current.contestRecord,
                    current.correction
                )
            );
            expected.newValueHash = keccak256(
                abi.encode(
                    expected.scopeHash,
                    expected.oldValueHash,
                    c.state,
                    c.claim,
                    c.evidence,
                    c.reason
                )
            );
            if (
                c.id != b.collectionId || c.correction != correction || (correction && c.state != 3)
                    || keccak256(abi.encode(c.context)) != keccak256(abi.encode(expected))
                    || c.governance.scopeHash != expected.scopeHash
                    || c.governance.oldValueHash != expected.oldValueHash
                    || c.governance.newValueHash != expected.newValueHash
                    || c.governance.actionId == 0 || c.governance.proposer == address(0)
                    || c.governance.roleMutationHash == 0 || c.governance.roleRevision == 0
                    || c.governance.actionClass != (correction ? 2 : 1)
            ) _invalid();
            scope = keccak256(abi.encode(b.collectionId, c.governance.actionId));
            if (correction) {
                PW.Correction memory r = b.state.correction;
                if (
                    !D.samePoint(point, b.correctionPoint) || r.recordHash != e.value
                        || r.claimRecordHash != c.claim || r.evidenceHash != c.evidence
                        || r.reasonHash != c.reason || r.approvalActionId != c.governance.actionId
                        || r.proposedArtist != c.evidenceDocument.proposedArtist
                        || current.correction.recordHash != 0
                ) _invalid();
                current.correction = PW.Correction(
                    r.collectionId,
                    r.proposedArtist,
                    r.claimRecordHash,
                    r.sustainedContestRecordHash,
                    r.evidenceHash,
                    r.reasonHash,
                    r.approvalActionId,
                    r.approvedAt,
                    0,
                    false,
                    r.recordHash
                );
            } else {
                PW.Contest memory r = _contest(b, point);
                if (
                    r.recordHash != e.value || r.state != c.state || r.claimRecordHash != c.claim
                        || r.evidenceHash != c.evidence || r.reasonHash != c.reason
                        || r.actionId != c.governance.actionId
                        || r.adjudicatedArtist != c.evidenceDocument.proposedArtist
                ) _invalid();
                current.contestState = r.state;
                current.contestClaim = r.claimRecordHash;
                current.contestRecord = r.recordHash;
            }
        } else {
            _invalid();
        }
        if (e.operation != 10) state = keccak256(abi.encode(b.collectionId, current));
        _otherSnapshots(e);
        Transition.validate(
            o, p, era, e, action, state, Transition.replay(o, e.operation, scope, e.value), primary
        );
        return current;
    }

    function _documents(
        uint256 id,
        bytes32 evidence,
        bytes32 reason,
        bytes32 claim,
        PW.Evidence memory a,
        PW.Evidence memory b
    ) private pure {
        if (
            evidence == 0 || reason == 0 || a.schemaVersion != 1 || b.schemaVersion != 1
                || a.collectionId != id || b.collectionId != id || a.narrativeHash == 0
                || b.narrativeHash == 0 || a.claimRecordHash != claim || b.claimRecordHash != claim
                || a.proposedArtist != b.proposedArtist || keccak256(abi.encode(a)) != evidence
                || keccak256(abi.encode(b)) != reason
        ) _invalid();
    }

    function _claim(P.Platform memory b, RH.Point memory point)
        private
        pure
        returns (PW.Claim memory)
    {
        for (uint256 i; i < b.claims.length; ++i) {
            if (D.samePoint(point, b.claims[i].point)) return b.claims[i].record;
        }
        _invalid();
    }

    function _allegation(P.Platform memory b, RH.Point memory point)
        private
        pure
        returns (AC.Claim memory)
    {
        for (uint256 i; i < b.allegations.length; ++i) {
            if (D.samePoint(point, b.allegations[i].point)) return b.allegations[i].record;
        }
        _invalid();
    }

    function _contest(P.Platform memory b, RH.Point memory point)
        private
        pure
        returns (PW.Contest memory)
    {
        for (uint256 i; i < b.contests.length; ++i) {
            if (D.samePoint(point, b.contests[i].point)) return b.contests[i].record;
        }
        _invalid();
    }

    function _otherSnapshots(H.Envelope memory e) private pure {
        T.Snapshot memory zero;
        for (uint8 i; i < 7; ++i) {
            if (i == 4) continue;
            if (e.operation == 8 && (i == 0 || i == 6)) {
                if (
                    e.before_[i].domainId != RH.ownerDomain(i) || e.before_[i].stateRoot == 0
                        || e.before_[i].recordChainTip == 0
                        || keccak256(abi.encode(e.before_[i])) != keccak256(abi.encode(e.after_[i]))
                ) {
                    _invalid();
                }
            } else if (
                keccak256(abi.encode(e.before_[i])) != keccak256(abi.encode(zero))
                    || keccak256(abi.encode(e.after_[i])) != keccak256(abi.encode(zero))
            ) {
                _invalid();
            }
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
