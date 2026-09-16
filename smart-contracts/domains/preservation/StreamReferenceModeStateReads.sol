// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamFinalityComponentState
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    IStreamArtworkFinalityComponent
} from "../../interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import {
    IStreamCollectionMetadataV1
} from "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    StreamFinalityDomains
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import { StreamFinalityRouterEvidence } from "../finality/StreamFinalityRouterEvidence.sol";
import { StreamReferenceModeDefinitions as D } from "../records/StreamReferenceModeDefinitions.sol";
import { StreamRecordFamilies } from "../records/StreamRecordFamilies.sol";
import { StreamMetadataRenderer } from "../metadata/StreamMetadataRenderer.sol";

/// @notice Fixed original writer and finality encodings; the host retains all mutation/currentness guards.
/// @dev Delegate context is the actual original producer, including address(this) and its code hash.
library StreamReferenceModeStateReads {
    function candidate(
        R.Publication memory p,
        mapping(uint256 => mapping(bytes32 => bool)) storage ids,
        mapping(uint256 => bytes32[]) storage history,
        mapping(uint256 => R.Lock) storage locks
    ) public view {
        if (
            p.collectionId == 0 || p.referenceId == 0 || p.reasonHash == 0 || p.effectiveAt == 0
                || p.effectiveAt > block.timestamp || block.timestamp > type(uint64).max
                || p.expectedRevision == type(uint64).max || ids[p.collectionId][p.referenceId]
        ) revert R.InvalidReferenceRender();
        uint256 count = history[p.collectionId].length;
        bytes32 head = count == 0 ? bytes32(0) : history[p.collectionId][count - 1];
        if (head != p.expectedHead || count != p.expectedRevision) {
            revert R.ReferenceLineage(p.expectedHead, head);
        }
        if (locks[p.collectionId].actionId != 0) revert R.ReferenceLocked();
        StreamMetadataRenderer.requireValidUtf8ContentUri(
            "referenceManifestURI", p.manifestURI, 2048, true
        );
    }

    function authority(address metadata, uint256 cid, address actor, uint256 readGas)
        public
        view
        returns (uint8 cls, uint64 rev)
    {
        for (uint8 i; i < 2; ++i) {
            cls = i == 0 ? 3 : 8;
            bytes memory raw = StreamFinalityRouterEvidence.read(
                metadata,
                abi.encodeCall(
                    IStreamCollectionMetadataV1.familyWriter,
                    (i == 0 ? cid : 0, StreamRecordFamilies.CURATOR, cls, actor)
                ),
                64,
                readGas
            );
            bool enabled;
            (enabled, rev) = abi.decode(raw, (bool, uint64));
            if (keccak256(raw) != keccak256(abi.encode(enabled, rev))) {
                revert R.ReferenceDependency(metadata);
            }
            if (enabled && rev != 0) return (cls, rev);
        }
        revert R.ReferenceAuthority(actor);
    }

    function lock(
        uint256 chainId,
        address core,
        uint256 cid,
        bytes32 recordHash,
        uint64 revision,
        bytes32 supplement
    ) public view returns (bytes32 scope, bytes32 oldHash, bytes32 newHash) {
        scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_REFERENCE_LOCK_SCOPE_V1"), chainId, address(this), core, cid
            )
        );
        oldHash = keccak256(abi.encode(scope, recordHash, revision, false));
        newHash = keccak256(abi.encode(scope, recordHash, revision, true));
        if (supplement != 0) {
            oldHash = keccak256(
                abi.encode(keccak256("6529STREAM_METRIC_REFERENCE_LOCK_V1"), oldHash, supplement)
            );
            newHash = keccak256(
                abi.encode(keccak256("6529STREAM_METRIC_REFERENCE_LOCK_V1"), newHash, supplement)
            );
        }
    }

    function component(
        R.Receipt storage r,
        R.Lock storage l,
        uint256 chainId,
        address core,
        uint256 cid,
        bytes32 version,
        bytes32 supplement
    ) public view returns (StreamFinalityComponentState memory) {
        bytes32 dataHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_LOCKED_REFERENCE_COMPONENT_V1"),
                chainId,
                address(this),
                core,
                cid,
                r,
                l
            )
        );
        if (supplement != 0) {
            dataHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_LOCKED_METRIC_REFERENCE_COMPONENT_V1"),
                    dataHash,
                    supplement
                )
            );
        }
        return StreamFinalityComponentState(
            true,
            StreamFinalityDomains.COMPONENT_REFERENCE_RENDER,
            address(this),
            type(IStreamArtworkFinalityComponent).interfaceId,
            address(this).codehash,
            version,
            D.PROFILE_HASH,
            dataHash
        );
    }
}
