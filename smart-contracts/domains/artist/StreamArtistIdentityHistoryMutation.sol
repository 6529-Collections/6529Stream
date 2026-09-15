// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistHistoryState.sol";
import "./StreamArtistIdentityState.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";

/// @notice Exact original55–57 mutations; host retains operation admission and its single commit.
library StreamArtistIdentityHistoryMutation {
    function applyArtistHistoryImport(
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        address artistWindowAuthority,
        T.ActionContext memory c,
        H.Binding memory p,
        bytes32 actionId
    ) public returns (StreamArtistIdentityState.Mutation memory) {
        if (c.actor != artistWindowAuthority || actionId == 0) {
            revert T.Unauthorized(c.actor);
        }
        H.Context memory x = StreamArtistHistoryState.context(o.environment.registry, p);
        bytes memory raw = StreamArtistHistoryProof.fixedRead(
            artistWindowAuthority,
            abi.encodeWithSignature("currentAction()"),
            192,
            StreamArtistHistoryProof.cap(o.environment.registry)
        );
        (bool executing, bytes32 id, uint8 cls, bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            abi.decode(raw, (bool, bytes32, uint8, bytes32, bytes32, bytes32));
        if (
            !executing || id != actionId || cls != 1 || scope != x.scopeHash
                || oldHash != x.oldValueHash || newHash != x.newValueHash
                || keccak256(raw)
                    != keccak256(abi.encode(executing, id, cls, scope, oldHash, newHash))
        ) revert T.InvalidRecord();
        bytes32 a = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.governance_action"),
            keccak256(abi.encode(id, scope, oldHash, newHash)),
            p.importRoot
        );
        bytes32 b = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.import_binding_key"),
            keccak256(abi.encode(p)),
            p.importRoot
        );
        StreamArtistHistoryState.commit(
            o.environment.core,
            o.environment.registry,
            p,
            actionId,
            StreamArtistHistoryProof.cap(o.environment.registry)
        );
        return StreamArtistIdentityState.Mutation(
            bytes32(0),
            keccak256(abi.encode(p, id)),
            StreamArtistHistoryState.commitment(),
            keccak256(abi.encode(a, b))
        );
    }

    function applyArtistHistoryLaneVerification(
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        address artistWindowAuthority,
        T.ActionContext memory c,
        uint256 index,
        H.Leaf memory p,
        bytes32[] memory proof
    ) public returns (StreamArtistIdentityState.Mutation memory) {
        H.Binding memory b = StreamArtistHistoryState.binding(index);
        bytes32 a = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.verified_lane_key"),
            keccak256(abi.encode(p.laneKind, p.laneKey)),
            p.recordChainHash
        );
        bytes32 bound = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.import_binding"),
            keccak256(abi.encode(index, p.laneKind, p.laneKey)),
            b.importRoot
        );
        StreamArtistHistoryState.verifyTip(
            o.environment.core,
            o.environment.registry,
            index,
            p,
            proof,
            StreamArtistHistoryProof.cap(o.environment.registry)
        );
        return StreamArtistIdentityState.Mutation(
            bytes32(0),
            keccak256(abi.encode(index, p, proof)),
            StreamArtistHistoryState.commitment(),
            keccak256(abi.encode(a, bound))
        );
    }

    function applyArtistRegistryCutover(
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        address artistWindowAuthority,
        T.ActionContext memory c
    ) public returns (StreamArtistIdentityState.Mutation memory) {
        bytes32 a = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.one_way_cutover_latch"),
            bytes32(0),
            keccak256(abi.encode(block.number))
        );
        StreamArtistHistoryState.observe(
            o.environment.core,
            o.environment.registry,
            StreamArtistHistoryProof.cap(o.environment.registry)
        );
        return StreamArtistIdentityState.Mutation(
            bytes32(0),
            keccak256(abi.encode(c.actor, block.number)),
            StreamArtistHistoryState.commitment(),
            a
        );
    }

    function _consume(
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes32 surface,
        bytes32 scope,
        bytes32 commitment
    ) private returns (bytes32 key) {
        key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                o.environment.chainId,
                o.environment.registry,
                o.coordinator,
                o.archive,
                address(this),
                o.domain,
                surface,
                scope
            )
        );
        if (replay[key].status != 0) revert T.Replay(key);
        replay[key] = T.ReplayCell(commitment, o.revision + 1, 1, 2);
        StreamArtistAuthorityCheckpoint.noteReplay(key, replay[key]);
    }
}
