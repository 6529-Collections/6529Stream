// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistAttributionStateTypes.sol";
import {
    StreamArtistAttributionStateTypes as AttrState
} from "./StreamArtistAttributionStateTypes.sol";
import "./StreamArtistPlatformState.sol";
import { StreamArtistPlatformContinuation } from "./StreamArtistPlatformContinuation.sol";
import {
    StreamArtistBindingLifecycleTypes as L
} from "../../interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";

/// @notice Fixed binding state/event mutations over the original Attribution storage.
library StreamArtistAttributionBindingMutation {
    event ArtistBindingTerminationContext(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint64 indexed bindingGeneration,
        bytes32 indexed recordReference,
        bytes32 bindingHash,
        bytes32 artistId,
        address signer,
        uint256 nonce,
        uint64 signedAt
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

    function complete(
        AttrState.State storage s,
        T.ActionContext calldata c,
        uint256 collectionId,
        T.Binding calldata b,
        bytes32 record,
        address signer,
        uint8 authorityClass
    ) public returns (AttrState.Mutation memory m) {
        AttrState.Attribution storage a = s.attributions[collectionId];
        if (a.state != 1 || a.generation != b.generation || record == bytes32(0)) {
            revert T.InvalidAttribution(collectionId);
        }
        bytes32 continuation = StreamArtistPlatformContinuation.accept(collectionId, b.generation, record);
        if (continuation == 0) {
            StreamArtistPlatformState.acceptBinding(s.platform, collectionId, b.generation);
        }
        a.state = 2;
        m = AttrState.Mutation(
            bytes32(0),
            keccak256(abi.encode(collectionId, b, record)),
            continuation == 0 ? keccak256(abi.encode(collectionId, a))
                : keccak256(abi.encode(collectionId, a, continuation))
        );
        emit ArtistAttributionStateChanged(
            1, collectionId, 2, b.generation, 1, signer, authorityClass, record, bytes32(0), ""
        );
    }

    function terminate(
        AttrState.State storage s,
        T.ActionContext calldata c,
        T.Binding calldata b,
        L.Termination calldata p,
        address signer,
        uint8 authority,
        uint256 nonce,
        bytes32 recordReference
    ) public returns (AttrState.Mutation memory m) {
        AttrState.Attribution storage item = s.attributions[p.collectionId];
        if (
            item.state != 1 || item.generation != b.generation || b.accepted
                || p.generation != b.generation || p.bindingHash != b.bindingHash
        ) revert T.InvalidAttribution(p.collectionId);
        item.state = 5;
        m = AttrState.Mutation(
            bytes32(0),
            keccak256(abi.encode(b, p, signer, authority, nonce, recordReference)),
            keccak256(abi.encode(p.collectionId, item))
        );
        emit ArtistAttributionStateChanged(
            1,
            p.collectionId,
            5,
            b.generation,
            1,
            c.actor,
            authority,
            recordReference,
            p.reasonHash,
            p.reasonURI
        );
        emit ArtistBindingTerminationContext(
            1,
            p.collectionId,
            b.generation,
            recordReference,
            b.bindingHash,
            b.artistId,
            signer,
            nonce,
            _now()
        );
    }

    function claim(
        AttrState.State storage s,
        T.ActionContext calldata c,
        uint256 collectionId,
        T.Binding calldata b,
        bytes32 reasonHash,
        string calldata reasonURI
    ) public returns (AttrState.Mutation memory m) {
        AttrState.Attribution memory prior = s.attributions[collectionId];
        if (
            (prior.state != 0 && prior.state != 5) || b.generation != prior.generation + 1
                || b.bindingHash == bytes32(0)
        ) revert T.InvalidAttribution(collectionId);
        StreamArtistPlatformState.consumeBinding(s.platform, collectionId, b);
        s.attributions[collectionId] = AttrState.Attribution(1, b.generation);
        m = AttrState.Mutation(
            bytes32(0),
            keccak256(abi.encode(collectionId, b, reasonHash, reasonURI)),
            keccak256(abi.encode(collectionId, uint8(1), b.generation))
        );
        emit ArtistAttributionStateChanged(
            1,
            collectionId,
            1,
            b.generation,
            prior.state,
            c.actor,
            0,
            b.bindingHash,
            reasonHash,
            reasonURI
        );
    }

    function _now() private view returns (uint64) {
        if (block.timestamp > type(uint64).max) revert T.InvalidRecord();
        return uint64(block.timestamp);
    }
}
