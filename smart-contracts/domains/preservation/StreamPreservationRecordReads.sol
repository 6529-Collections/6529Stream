// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamPreservationRecordsV1 as P
} from "../../interfaces/stream/preservation/IStreamPreservationRecordsV1.sol";
import {
    IStreamCollectionMetadataV1 as M
} from "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import { IStreamCorePointers } from "../../interfaces/stream/core/IStreamCorePointers.sol";
import {
    IStreamCoreCollectionView
} from "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import { IStreamCoreIdentity } from "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import { IStreamModuleRegistry } from "../../interfaces/stream/modules/IStreamModuleRegistry.sol";
import { StreamRecordFamilies as F } from "../records/StreamRecordFamilies.sol";
import { StreamRecordDocumentReads as Documents } from "../records/StreamRecordDocumentReads.sol";

/// @notice Fixed bounded reads of original selected authority. Delegate context is the actual record host.
library StreamPreservationRecordReads {
    struct Context {
        address core;
        bytes32 coreHash;
        address metadata;
        bytes32 metadataHash;
        address schemas;
        bytes32 schemasHash;
        uint256 cap;
    }

    function code(address target, bytes32 hash) internal view {
        if (target.code.length == 0 || target.codehash != hash) {
            revert P.PreservationDependencyChanged(target);
        }
    }

    function collection(Context memory c, uint256 id) public view {
        code(c.core, c.coreHash);
        if (
            id == 0
                || !abi.decode(
                    read(
                        c.core,
                        abi.encodeCall(IStreamCoreCollectionView.collectionExists, (id)),
                        32,
                        c.cap
                    ),
                    (bool)
                )
        ) revert P.InvalidPreservationRecord();
    }

    function token(Context memory c, uint256 id) public view returns (uint256 collectionId) {
        code(c.core, c.coreHash);
        (bool exists, uint256 cid,, bool burned) = abi.decode(
            read(
                c.core,
                abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (id)),
                128,
                c.cap
            ),
            (bool, uint256, uint256, bool)
        );
        uint8 state = abi.decode(
            read(c.core, abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (id)), 32, c.cap),
            (uint8)
        );
        if (!exists || id == 0 || (state != 2 && state != 3) || burned != (state == 3)) {
            revert P.InvalidPreservationRecord();
        }
        collection(c, cid);
        return cid;
    }

    function admit(
        Context memory c,
        uint256 id,
        bytes32 recordType,
        address actor,
        bytes32 schemaId,
        bytes32 canonId
    ) public view returns (P.Receipt memory r) {
        live(c, id);
        M.RecordPolicy memory policy = abi.decode(
            read(c.metadata, abi.encodeCall(M.recordPolicy, (recordType)), 96, c.cap),
            (M.RecordPolicy)
        );
        bytes32 f = policy.family;
        if (
            !policy.admitted
                || (f != F.ARCHIVE
                    && f != F.FIXITY
                    && f != F.C2PA
                    && f != F.IIIF
                    && f != F.MEDIA
                    && f != F.AGENT) || policy.authorizationMask == 0
                || (policy.authorizationMask & ~F.allowed(f)) != 0
        ) revert P.PreservationAuthorityRequired();
        r.collectionId = id;
        r.recorder = actor;
        r.family = f;
        for (uint8 kind = 4; kind <= 8; ++kind) {
            if ((policy.authorizationMask & F.bit(kind)) == 0) continue;
            for (uint256 i; i < 2; ++i) {
                uint256 scope = i == 0 ? id : 0;
                (bool enabled, uint64 revision) = abi.decode(
                    read(
                        c.metadata,
                        abi.encodeCall(M.familyWriter, (scope, f, kind, actor)),
                        64,
                        c.cap
                    ),
                    (bool, uint64)
                );
                if (enabled && revision != 0) {
                    r.authorizationClass = kind;
                    r.grantCollectionId = scope;
                    r.grantRevision = revision;
                    (r.schemaDefinitionHash, r.canonicalizationDefinitionHash) =
                        Documents.activeSchema(c.schemas, schemaId, canonId, c.cap);
                    if (r.schemaDefinitionHash == 0 || r.canonicalizationDefinitionHash == 0) {
                        revert P.InvalidPreservationRecord();
                    }
                    return r;
                }
            }
        }
        revert P.PreservationAuthorityRequired();
    }

    function live(Context memory c, uint256 id) public view {
        collection(c, id);
        code(c.metadata, c.metadataHash);
        code(c.schemas, c.schemasHash);
        (address metadata, bytes32 hash) = pointer(c, keccak256("COLLECTION_METADATA"));
        if (metadata != c.metadata || hash != c.metadataHash) {
            revert P.PreservationHostNotSelected();
        }
        (address registry, bytes32 registryHash) = pointer(c, keccak256("MODULE_REGISTRY"));
        code(registry, registryHash);
        if (
            !abi.decode(
                    read(
                        registry,
                        abi.encodeCall(
                            IStreamModuleRegistry.isModuleEligible,
                            (address(this), keccak256("PRESERVATION_RECORDS"), type(P).interfaceId)
                        ),
                        32,
                        c.cap
                    ),
                    (bool)
                )
                || !abi.decode(
                    read(
                        registry,
                        abi.encodeCall(
                            IStreamModuleRegistry.isModuleEligible,
                            (c.metadata, keccak256("COLLECTION_METADATA"), type(M).interfaceId)
                        ),
                        32,
                        c.cap
                    ),
                    (bool)
                )
        ) revert P.PreservationHostNotSelected();
    }

    function pointer(Context memory c, bytes32 kind)
        private
        view
        returns (address target, bytes32 hash)
    {
        (target, hash,,,,,,,,) = abi.decode(
            read(
                c.core, abi.encodeCall(IStreamCorePointers.getSatellitePointer, (kind)), 320, c.cap
            ),
            (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
        );
    }

    function read(address target, bytes memory input, uint256 size, uint256 cap)
        internal
        view
        returns (bytes memory output)
    {
        // Warm the exact target and allocate before the EIP-150 admission check.
        if (target.code.length == 0) revert P.PreservationReadFailed(target);
        output = new bytes(size);
        if (gasleft() <= cap + cap / 63 + 10000) revert P.PreservationReadFailed(target);
        bool ok;
        uint256 actual;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(output, 32), size)
            actual := returndatasize()
        }
        if (!ok || actual != size) revert P.PreservationReadFailed(target);
    }
}
