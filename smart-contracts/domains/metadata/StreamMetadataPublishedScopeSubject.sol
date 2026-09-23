// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamScopeMembershipReads as Reads } from "../finality/StreamScopeMembershipReads.sol";
import {
    StreamScopeMembershipEncoding as Encoding
} from "../finality/StreamScopeMembershipEncoding.sol";
import { StreamMetadataSubjects } from "./StreamMetadataSubjects.sol";
import {
    StreamScopeMembershipManifest
} from "../../interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Reuses the actual membership producer's original publication grammar and checks.
/// @dev Linked execution retains the Metadata host. Caller-supplied hosts or scope tuples are absent.
import { StreamCollectionMetadataV1 } from "./StreamCollectionMetadataV1.sol";
import { IStreamCoreIdentity } from "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import { IStreamCoreCollectionView } from "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import { IStreamCollectionMetadataV1 } from "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";

library StreamMetadataPublishedScopeSubject {
    struct Context {
        address core;
        bytes32 coreCodeHash;
        address schemas;
        bytes32 schemaCodeHash;
        address store;
        bytes32 storeCodeHash;
        uint256 readGas;
    }

    event MetadataScopeSubjectRegistered(
        bytes32 indexed subjectId,
        uint256 indexed collectionId,
        bytes32 indexed membershipRecordHash,
        uint8 scopeType,
        bytes32 scopeId
    );

    /// @dev Exact original token-subject semantics with the same declared Metadata mapping.
    function registerToken(
        mapping(bytes32 => StreamCollectionMetadataV1.Subject) storage subjects,
        Context memory c,
        uint256 tokenId
    ) public returns (bytes32 subjectId) {
        _code(c.core, c.coreCodeHash);
        (bool exists, uint256 collectionId,,) = abi.decode(
            _read(c, abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (tokenId)), 128),
            (bool, uint256, uint256, bool)
        );
        uint8 lifecycle = abi.decode(
            _read(c, abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (tokenId)), 32), (uint8)
        );
        if (!exists || (lifecycle != 2 && lifecycle != 3)) {
            revert IStreamCollectionMetadataV1.InvalidMetadataRecord();
        }
        _collection(c, collectionId);
        subjectId = StreamMetadataSubjects.scopeSubject(
            block.chainid,
            c.core,
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, collectionId, tokenId, 0)
        );
        subjects[subjectId] = StreamCollectionMetadataV1.Subject(collectionId, tokenId);
    }

    function registerPublished(
        mapping(bytes32 => StreamCollectionMetadataV1.Subject) storage subjects,
        Context memory c,
        bytes32 membershipRecordHash
    ) public returns (bytes32 subjectId) {
        _code(c.core, c.coreCodeHash);
        _code(c.schemas, c.schemaCodeHash);
        _code(c.store, c.storeCodeHash);
        StreamFinalityScope memory scope;
        (subjectId, scope) = derive(c.core, c.schemas, c.store, c.readGas, membershipRecordHash);
        _collection(c, scope.collectionId);
        subjects[subjectId] = StreamCollectionMetadataV1.Subject(scope.collectionId, 0);
        emit MetadataScopeSubjectRegistered(
            subjectId,
            scope.collectionId,
            membershipRecordHash,
            uint8(scope.scopeType),
            scope.scopeId
        );
    }

    function _code(address target, bytes32 expected) private view {
        if (target.code.length == 0 || target.codehash != expected) {
            revert IStreamCollectionMetadataV1.MetadataDependencyChanged(target);
        }
    }

    function _collection(Context memory c, uint256 collectionId) private view {
        _code(c.core, c.coreCodeHash);
        if (
            collectionId == 0
                || !abi.decode(
                    _read(
                        c,
                        abi.encodeCall(IStreamCoreCollectionView.collectionExists, (collectionId)),
                        32
                    ),
                    (bool)
                )
        ) revert IStreamCollectionMetadataV1.InvalidMetadataRecord();
    }

    /// @dev Preserve the original Metadata dependency-read cap, bound and error semantics.
    function _read(Context memory c, bytes memory input, uint256 maximum)
        private
        view
        returns (bytes memory data)
    {
        uint256 cap = c.readGas;
        address target = c.core;
        if (gasleft() <= cap + cap / 63 + 10000) {
            revert IStreamCollectionMetadataV1.MetadataReadFailed(target);
        }
        data = new bytes(maximum);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(data, 32), maximum)
            size := returndatasize()
        }
        if (!ok || size > maximum || (maximum <= 320 && size != maximum)) {
            revert IStreamCollectionMetadataV1.MetadataReadFailed(target);
        }
        assembly ("memory-safe") { mstore(data, size) }
    }

    function derive(
        address core,
        address schemas,
        address store,
        uint256 readGas,
        bytes32 recordHash
    ) public view returns (bytes32 subjectId, StreamFinalityScope memory scope) {
        (StreamScopeMembershipManifest memory manifest,) = Reads.publicationFromMetadata(
            Reads.Inputs(block.chainid, core, address(this), schemas, store, readGas), recordHash
        );
        scope = StreamFinalityScope(
            StreamFinalityScopeType(manifest.scopeType),
            manifest.collectionId,
            0,
            Encoding.scopeId(
                block.chainid, core, manifest.collectionId, manifest.scopeType, recordHash
            )
        );
        subjectId = StreamMetadataSubjects.scopeSubject(block.chainid, core, scope);
    }
}
