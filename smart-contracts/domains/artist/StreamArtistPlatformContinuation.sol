// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistPlatformTypes as PW
} from "../../interfaces/stream/artist/StreamArtistPlatformTypes.sol";
import {
    StreamArtistPlatformCorrectionState as State
} from "./StreamArtistPlatformCorrectionState.sol";
import {
    StreamArtistPlatformCorrectionLineageTypes as PL,
    IStreamArtistPlatformCorrectionLineage as API
} from "../../interfaces/stream/artist/IStreamArtistPlatformCorrectionLineage.sol";
import {
    StreamArtistAttributionStateTypes as AttrState
} from "./StreamArtistAttributionStateTypes.sol";
import {
    StreamArtistBindingCorrectionTypes as BC
} from "../../interfaces/stream/artist/IStreamArtistBindingCorrection.sol";
import { StreamArtistBindingCorrectionHashes } from "./StreamArtistBindingCorrectionHashes.sol";
import { StreamArtistHashes as H } from "./StreamArtistHashes.sol";

/// @notice Fixed op1/op2 mutation worker. The original owner checks and commit stay on Attribution.
library StreamArtistPlatformContinuation {
    event PlatformCorrectionContinued(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint64 indexed generation,
        bytes32 indexed recordHash,
        bytes32 originalCorrectionRecord,
        bytes32 previousLineageRecord,
        bytes32 bindingHash,
        bytes32 approvalHash,
        bytes32 governanceActionId
    );
    event PlatformCorrectionAccepted(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint64 indexed generation,
        bytes32 indexed lineageRecord,
        bytes32 acceptanceRecord,
        bytes32 recordHash,
        uint64 acceptedAt
    );
    event ArtistAttributionStateChanged(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint8 indexed newState,
        uint64 bindingGeneration,
        uint8 oldState,
        address actor,
        uint8 authorityClass,
        bytes32 recordHash,
        bytes32 reasonHash,
        string reasonURI
    );

    function claimEncoded(AttrState.State storage s, H.Environment memory e, bytes calldata call_)
        public
        returns (AttrState.Mutation memory m)
    {
        if (bytes4(call_[:4]) != API.claimPlatformContinuation.selector) revert T.InvalidRecord();
        (
            T.ActionContext memory c,
            uint256 id,
            T.Binding memory b,
            bytes32 reason,
            string memory uri,
            BC.Approval memory a
        ) =
            abi.decode(
                call_[4:], (T.ActionContext, uint256, T.Binding, bytes32, string, BC.Approval)
            );
        PL.Witness memory w = State.decode(a.causeData);
        PW.State storage p = s.platform.collections[id];
        AttrState.Attribution memory old = s.attributions[id];
        State.Store storage st = State.store();
        PL.Status memory prior = State.status(p, id);
        if (
            old.state != 5 || old.generation != a.previous.generation
                || b.generation != old.generation + 1 || b.bindingHash == 0 || b.accepted
                || (b.consentMode != 1 && b.consentMode != 2) || b.artistId != a.proposedArtistId
                || p.declaration.recordHash == 0 || p.contestState != 3
                || p.correction.recordHash == 0 || p.correction.correctiveGeneration == 0
                || keccak256(abi.encode(State.pins(p))) != keccak256(abi.encode(w.platform))
                || keccak256(abi.encode(prior)) != keccak256(abi.encode(w.prior))
                || a.previous.bindingHash == 0 || a.governance.actionClass != 2
                || a.governance.actionId == 0 || a.approvedAt != _time()
                || st.generations[id][b.generation] != 0
        ) revert PL.InvalidPlatformContinuation(id);
        if (prior.count == 0) {
            if (
                old.generation != p.correction.correctiveGeneration
                    || prior.latestLineageRecord != 0
            ) {
                revert PL.InvalidPlatformContinuation(id);
            }
        } else {
            PL.Record storage previous = st.records[prior.latestLineageRecord];
            if (
                previous.collectionId != id || previous.generation != old.generation
                    || previous.bindingHash != a.previous.bindingHash
                    || previous.recordHash != st.generations[id][old.generation]
            ) {
                revert PL.InvalidPlatformContinuation(id);
            }
        }
        bytes32 approvalHash = StreamArtistBindingCorrectionHashes.hash(e, id, b.bindingHash, a);
        PL.Record memory r = PL.Record(
            0,
            id,
            p.declaration.recordHash,
            p.correction.recordHash,
            prior.latestLineageRecord,
            a.previous.bindingHash,
            old.generation,
            b.bindingHash,
            b.generation,
            b.artistId,
            b.artistAddress,
            approvalHash,
            a.governance.actionId,
            a.approvedAt
        );
        r.recordHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_PLATFORM_BINDING_CONTINUATION_RECORD_V1"),
                e.chainId,
                e.registry,
                e.core,
                e.manager,
                address(this),
                r
            )
        );
        st.records[r.recordHash] = r;
        st.generations[id][b.generation] = r.recordHash;
        st.heads[id] = PL.Status(
            p.correction.recordHash,
            r.recordHash,
            b.generation,
            prior.count + 1,
            prior.effectiveAccepted,
            prior.latestAcceptanceRecord
        );
        s.attributions[id] = AttrState.Attribution(1, b.generation);
        m = AttrState.Mutation(
            0,
            keccak256(abi.encode(id, b, reason, uri, approvalHash, r.recordHash)),
            keccak256(abi.encode(id, uint8(1), b.generation, r.recordHash, st.heads[id]))
        );
        emit PlatformCorrectionContinued(
            1,
            id,
            b.generation,
            r.recordHash,
            p.correction.recordHash,
            prior.latestLineageRecord,
            b.bindingHash,
            approvalHash,
            a.governance.actionId
        );
        emit ArtistAttributionStateChanged(
            1, id, 1, b.generation, old.state, c.actor, 0, b.bindingHash, reason, uri
        );
    }

    function accept(uint256 id, uint64 generation, bytes32 originalAcceptance)
        public
        returns (bytes32 record)
    {
        State.Store storage s = State.store();
        PL.Status storage h = s.heads[id];
        if (h.latestLineageRecord == 0 || h.generation != generation) return 0;
        PL.Record storage r = s.records[h.latestLineageRecord];
        if (
            originalAcceptance == 0 || r.collectionId != id || r.generation != generation
                || s.acceptances[r.recordHash].recordHash != 0
        ) revert PL.InvalidPlatformContinuation(id);
        PL.Acceptance memory a = PL.Acceptance(0, r.recordHash, originalAcceptance, _time());
        record = keccak256(
            abi.encode(
                keccak256("6529STREAM_PLATFORM_BINDING_CONTINUATION_ACCEPTANCE_V1"),
                block.chainid,
                address(this),
                id,
                generation,
                a
            )
        );
        a.recordHash = record;
        s.acceptances[r.recordHash] = a;
        h.effectiveAccepted = true;
        h.latestAcceptanceRecord = record;
        emit PlatformCorrectionAccepted(
            1, id, generation, r.recordHash, originalAcceptance, record, a.acceptedAt
        );
    }

    function readEncoded(bytes calldata input) public view returns (bytes memory) {
        if (bytes4(input[:4]) == API.platformCorrectionLineage.selector) {
            return abi.encode(State.store().records[abi.decode(input[4:], (bytes32))]);
        }
        if (bytes4(input[:4]) == API.platformCorrectionAcceptance.selector) {
            return abi.encode(State.store().acceptances[abi.decode(input[4:], (bytes32))]);
        }
        revert T.InvalidRecord();
    }

    function _time() private view returns (uint64) {
        if (block.timestamp > type(uint64).max) revert T.InvalidRecord();
        return uint64(block.timestamp);
    }
}
