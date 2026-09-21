// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import { StreamArtistAttributionStateTypes as AS } from "./StreamArtistAttributionStateTypes.sol";
import {
    StreamArtistPlatformCorrectionState as Lineage
} from "./StreamArtistPlatformCorrectionState.sol";
import {
    StreamArtistPlatformCorrectionLineageTypes as PL
} from "../../interfaces/stream/artist/IStreamArtistPlatformCorrectionLineage.sol";
import {
    StreamArtistPlatformTypes as PW
} from "../../interfaces/stream/artist/StreamArtistPlatformTypes.sol";
import {
    StreamArtistAttributionClaimTypes as AC
} from "../../interfaces/stream/artist/IStreamArtistAttributionClaims.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

/// @notice Exact original typed maps only, reached beneath the original owner's operation60 guard.
library StreamArtistRecoveredPlatformWrites {
    function requireEmpty(AS.State storage s, P.Platform memory p) public view {
        PW.State memory state;
        PW.Claim memory claim;
        PW.Contest memory contest;
        AC.Claim memory allegation;
        PL.Status memory status;
        PL.Record memory lineage;
        PL.Acceptance memory acceptance;
        Lineage.Store storage ls = Lineage.store();
        if (
            keccak256(abi.encode(s.platform.collections[p.collectionId]))
                    != keccak256(abi.encode(state))
                || s.attributionClaims.counts[p.collectionId] != 0
                || s.attributionClaims.latest[p.collectionId] != 0
                || s.latestDisplayClaim[p.collectionId] != 0
                || keccak256(abi.encode(ls.heads[p.collectionId])) != keccak256(abi.encode(status))
        ) _invalid();
        for (uint256 i; i < p.claims.length; ++i) {
            PW.Claim memory r = p.claims[i].record;
            if (
                keccak256(abi.encode(s.platform.claims[r.recordHash]))
                        != keccak256(abi.encode(claim))
                    || s.platform
                    .claimSubjects[
                        _subject(p.collectionId, r.claimant, r.evidenceHash, r.reasonHash)
                    ]
            ) {
                _invalid();
            }
        }
        for (uint256 i; i < p.contests.length; ++i) {
            PW.Contest memory r = p.contests[i].record;
            if (
                keccak256(abi.encode(s.platform.contests[r.recordHash]))
                        != keccak256(abi.encode(contest))
                    || s.platform.actions[keccak256(abi.encode(p.collectionId, r.actionId))]
            ) _invalid();
        }
        if (
            p.state.correction.recordHash != 0
                && s.platform
                .actions[keccak256(abi.encode(p.collectionId, p.state.correction.approvalActionId))]
        ) {
            _invalid();
        }
        for (uint256 i; i < p.allegations.length; ++i) {
            AC.Claim memory r = p.allegations[i].record;
            if (
                keccak256(abi.encode(s.attributionClaims.records[r.recordHash]))
                        != keccak256(abi.encode(allegation))
                    || s.attributionClaims
                    .subjects[_subject(p.collectionId, r.claimant, r.evidenceHash, r.reasonHash)]
            ) {
                _invalid();
            }
        }
        for (uint256 i; i < p.continuations.length; ++i) {
            PL.Record memory r = p.continuations[i].record;
            if (
                keccak256(abi.encode(ls.records[r.recordHash])) != keccak256(abi.encode(lineage))
                    || ls.generations[p.collectionId][r.generation] != 0
                    || keccak256(abi.encode(ls.acceptances[r.recordHash]))
                        != keccak256(abi.encode(acceptance))
            ) {
                _invalid();
            }
        }
    }

    function applyState(AS.State storage s, P.Platform memory p) public {
        s.platform.collections[p.collectionId] = p.state;
        for (uint256 i; i < p.claims.length; ++i) {
            PW.Claim memory r = p.claims[i].record;
            s.platform.claims[r.recordHash] = r;
            s.platform
            .claimSubjects[
                _subject(p.collectionId, r.claimant, r.evidenceHash, r.reasonHash)
            ] = true;
        }
        for (uint256 i; i < p.contests.length; ++i) {
            PW.Contest memory r = p.contests[i].record;
            s.platform.contests[r.recordHash] = r;
            s.platform.actions[keccak256(abi.encode(p.collectionId, r.actionId))] = true;
        }
        if (p.state.correction.recordHash != 0) {
            s.platform
            .actions[
                keccak256(abi.encode(p.collectionId, p.state.correction.approvalActionId))
            ] = true;
        }
        s.attributionClaims.counts[p.collectionId] = p.allegationCount;
        s.attributionClaims.latest[p.collectionId] = p.latestAllegation;
        s.latestDisplayClaim[p.collectionId] = p.latestDisplayClaim;
        for (uint256 i; i < p.allegations.length; ++i) {
            AC.Claim memory r = p.allegations[i].record;
            s.attributionClaims.records[r.recordHash] = r;
            s.attributionClaims
            .subjects[_subject(p.collectionId, r.claimant, r.evidenceHash, r.reasonHash)] = true;
        }
        Lineage.Store storage ls = Lineage.store();
        if (p.continuations.length != 0) ls.heads[p.collectionId] = p.status;
        for (uint256 i; i < p.continuations.length; ++i) {
            P.ContinuationRow memory row = p.continuations[i];
            ls.records[row.record.recordHash] = row.record;
            ls.generations[p.collectionId][row.record.generation] = row.record.recordHash;
            if (row.acceptance.recordHash != 0) {
                ls.acceptances[row.record.recordHash] = row.acceptance;
            }
        }
    }

    function _subject(uint256 id, address actor, bytes32 evidence, bytes32 reason)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(id, actor, evidence, reason));
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
