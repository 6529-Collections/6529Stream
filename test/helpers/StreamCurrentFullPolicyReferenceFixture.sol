// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentFullPolicyPublicationFixture
} from "./StreamCurrentFullPolicyPublicationFixture.sol";
import {
    StreamPolicyReferencePublicationV2
} from "../../smart-contracts/domains/preservation/StreamPolicyReferencePublicationV2.sol";
import {
    StreamPolicyReferenceTypesV2 as PolicyReference
} from "../../smart-contracts/interfaces/stream/preservation/StreamPolicyReferenceTypesV2.sol";
import {
    StreamReferenceRenderTypes as ReferenceObservation
} from "../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamPolicySnapshotTypesV2 as ReferenceSnapshot
} from "../../smart-contracts/interfaces/stream/metadata/StreamPolicySnapshotTypesV2.sol";
import {
    IStreamPolicyContentCheckpointV2 as ReferenceContent
} from "../../smart-contracts/interfaces/stream/finality/IStreamPolicyContentCheckpointV2.sol";
import {
    StreamExternalArtifactTypes as ReferenceArchive
} from "../../smart-contracts/interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import {
    IStreamSchemaRegistry as ReferenceSchema
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamCoreIdentity as ReferenceCore
} from "../../smart-contracts/interfaces/stream/core/IStreamCoreIdentity.sol";
import {
    StreamPolicyReferenceDefinitionsV2 as ReferenceDefinitions
} from "../../smart-contracts/domains/records/StreamPolicyReferenceDefinitionsV2.sol";
import {
    StreamReferenceRenderDefinitions as ReferenceCommonDefinitions
} from "../../smart-contracts/domains/records/StreamReferenceRenderDefinitions.sol";
import {
    StreamReferenceEnvironmentJson
} from "../../smart-contracts/domains/records/StreamReferenceEnvironmentJson.sol";
import {
    StreamRecordFamilies
} from "../../smart-contracts/domains/records/StreamRecordFamilies.sol";

/// @notice Actual V2 reference publication and locking after the current full-policy snapshot.
/// @dev Browser execution is an explicit supplied-observation boundary. This helper validates
/// exact input/output identities and real archive receipts; it does not execute a browser or
/// prove that supplied repeated PNG observations came from that browser. No old native captures
/// are selected implicitly. Fresh independently captured evidence must name these exact full
/// STATIC input bytes before this fixture can establish browser acceptance.
abstract contract StreamCurrentFullPolicyReferenceFixture is
    StreamCurrentFullPolicyPublicationFixture
{
    StreamPolicyReferencePublicationV2 internal publicationReference;
    PolicyReference.Publication internal publicationReferencePublication;
    PolicyReference.Receipt internal publicationReferenceReceipt;
    bytes32 internal assemblyReferenceRecord;
    bytes32[3] internal assemblyReferenceFirstReceipts;
    bytes32[3] internal assemblyReferenceSecondReceipts;
    bytes32 internal publicationObservationInputsHash;

    function _publicationPrepareReferenceDefinitions() internal {
        require(publicationGraph.preparedChildren == 7, "actual complete publication graph");
        address host = publicationGraph.children[4];
        require(
            host.code.length != 0 && host.codehash == publicationGraph.codeHashes[4],
            "actual factory reference runtime"
        );
        publicationReference = StreamPolicyReferencePublicationV2(host);
        require(
            publicationReference.core() == address(assemblyCore)
                && publicationReference.metadataHost() == address(assemblyMetadata)
                && publicationReference.metadataRouter() == address(assemblyRouter)
                && publicationReference.snapshots() == address(publicationSnapshots)
                && publicationReference.archiveCoverage() == address(assemblyExternal),
            "same actual reference graph"
        );
        string[7] memory names = [
            "STREAM_POLICY_COLLECTION_REFERENCE_ABI_V2",
            "STREAM_POLICY_COLLECTION_REFERENCE_PROFILE_V2",
            "STREAM_ABI_POLICY_COLLECTION_REFERENCE_V2",
            "STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1",
            "STREAM_REFERENCE_PNG_OBJECT_V1",
            "STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1",
            "STREAM_REFERENCE_NATIVE_FORMATS_V1"
        ];
        bytes32[7] memory hashes = [
            ReferenceDefinitions.SCHEMA_HASH,
            ReferenceDefinitions.PROFILE_HASH,
            ReferenceDefinitions.CANON_HASH,
            ReferenceCommonDefinitions.ENVIRONMENT_SCHEMA_HASH,
            ReferenceCommonDefinitions.PNG_SCHEMA_HASH,
            ReferenceCommonDefinitions.ZIP_SCHEMA_HASH,
            ReferenceCommonDefinitions.FORMAT_CATALOG_HASH
        ];
        uint256[7] memory lengths = [
            uint256(ReferenceDefinitions.SCHEMA_BYTES),
            ReferenceDefinitions.PROFILE_BYTES,
            ReferenceDefinitions.CANON_BYTES,
            ReferenceCommonDefinitions.ENVIRONMENT_SCHEMA_BYTES,
            ReferenceCommonDefinitions.PNG_SCHEMA_BYTES,
            ReferenceCommonDefinitions.ZIP_SCHEMA_BYTES,
            ReferenceCommonDefinitions.FORMAT_CATALOG_BYTES
        ];
        for (uint256 i; i < names.length; ++i) {
            string memory path = i < 3
                ? string.concat(
                    "docs/schemas/preservation/policy-collection-reference-v2.",
                    i == 0 ? "schema" : i == 1 ? "profile" : "abi",
                    ".json"
                )
                : string.concat("schemas/records/", names[i], ".json");
            bytes memory raw = bytes(assemblyVm.readFile(path));
            require(
                raw.length == lengths[i] && keccak256(raw) == hashes[i],
                "literal reference definition bytes"
            );
            ReferenceSchema.DocumentKind kind = i == 2
                ? ReferenceSchema.DocumentKind.CANONICALIZATION
                : (i == 1 || i == 6)
                    ? ReferenceSchema.DocumentKind.CATALOG
                    : ReferenceSchema.DocumentKind.SCHEMA;
            bytes32 id = keccak256(bytes(names[i]));
            ReferenceSchema.DocumentView memory retained = assemblySchemas.document(id);
            if (!retained.exists) {
                require(
                    _assemblyRegisterDocument(names[i], kind, raw, assemblySchemas.RAW_BYTES())
                        == id,
                    "actual reference definition registration"
                );
                retained = assemblySchemas.document(id);
            }
            require(
                retained.exists && retained.status == ReferenceSchema.DocumentStatus.ACTIVE
                    && retained.specification.kind == kind
                    && retained.specification.contentHash == hashes[i]
                    && retained.specification.totalBytes == lengths[i]
                    && retained.specification.canonicalizationId == assemblySchemas.RAW_BYTES()
                    && keccak256(assemblySchemas.documentBytes(id)) == hashes[i],
                "active retained reference definition"
            );
        }
        (bool enabled,) = assemblyMetadata.familyWriter(
            publicationGraph.scope.collectionId, StreamRecordFamilies.CURATOR, 3, address(this)
        );
        if (!enabled) _assemblyGrantFamily(StreamRecordFamilies.CURATOR, 3, address(this));
    }

    /// @dev Input transport, supplied separately from the onchain publication:
    /// environmentJSON.environmentABI is exact abi.encode(Environment), with its first four
    /// object/coverage/manifest fields zero. Every engine, toolchain, platform, viewport, file
    /// inventory and capture-profile fact comes from this supplied observation.
    /// browserJSON contains the original ZIP endpoint fields consumed below.
    /// capturesJSON.capture1 (and capture2 for distinct first/last rows) contains tokenId,
    /// collectionSerial, html, metadataJSON, repeatCapture0Sha256, repeatCapture1Sha256 and
    /// the original PNG endpoint fields. Byte-valued JSON fields use hexadecimal strings.
    function _publicationPublishReference(
        string memory environmentJSON,
        string memory browserJSON,
        string memory capturesJSON
    ) internal {
        require(
            address(publicationReference) == publicationGraph.children[4]
                && assemblyReferenceRecord == 0 && assemblySnapshotRecord != 0,
            "prepared actual reference follows snapshot"
        );
        ReferenceSnapshot.Receipt memory snapshot = publicationSnapshots.requireCurrent(
            publicationGraph.scope,
            assemblySnapshotRecord,
            publicationSnapshots.currentSnapshot(publicationGraph.scope).revision
        );
        ReferenceContent.Plan memory content =
            publicationCheckpoint.requireCurrentCheckpoint(publicationContent);
        require(
            content.tokenCount != 0 && content.nextIndex == content.tokenCount
                && keccak256(abi.encode(content.scope))
                    == keccak256(abi.encode(publicationGraph.scope)),
            "complete same-scope output checkpoint"
        );
        publicationObservationInputsHash =
            keccak256(abi.encode(environmentJSON, browserJSON, capturesJSON));
        ReferenceObservation.Environment memory env =
            _publicationReferenceEnvironment(environmentJSON, browserJSON);
        PolicyReference.Publication memory p;
        p.scope = publicationGraph.scope;
        p.observation.collectionId = p.scope.collectionId;
        p.observation.referenceId = keccak256(
            abi.encode(
                "full-policy supplied first and last reference observations",
                publicationGraph.graphId,
                assemblySnapshotRecord,
                publicationObservationInputsHash
            )
        );
        p.observation.snapshotRecordHash = assemblySnapshotRecord;
        p.observation.snapshotRevision = snapshot.revision;
        p.observation.environment = env;
        p.observation.reasonHash = publicationObservationInputsHash;
        p.observation.effectiveAt = uint64(block.timestamp);
        p.observation.manifestURI = "urn:fixture:full-policy:supplied-reference-observations";
        uint256 count = content.tokenCount == 1 ? 1 : 2;
        p.observation.captures = new ReferenceObservation.Capture[](count);
        for (uint256 i; i < count; ++i) {
            p.observation.captures[i] = _publicationReferenceCapture(
                capturesJSON,
                i == 0 ? ".capture1" : ".capture2",
                i == 0 ? 0 : content.tokenCount - 1,
                env.manifestHash,
                i + 1
            );
        }
        _assemblyUpload(bytes(StreamReferenceEnvironmentJson.files(env.packageFiles, true)));
        _assemblyUpload(
            bytes(StreamReferenceEnvironmentJson.files(env.platformPrerequisites, false))
        );
        publicationReference.prepareFileInventory(env.packageFiles, true);
        publicationReference.prepareFileInventory(env.platformPrerequisites, false);
        (p.observation.expectedSourcesHash,) =
            publicationReference.previewReference(p, address(this));
        (, bytes memory canonical) = publicationReference.previewReference(p, address(this));
        _assemblyUpload(canonical);
        _assemblyUpload(abi.encode(p));
        assemblyReferenceRecord = publicationReference.publishReference(p);
        (PolicyReference.Publication memory original, PolicyReference.Receipt memory receipt) =
            publicationReference.referenceRecord(assemblyReferenceRecord);
        require(
            keccak256(abi.encode(original)) == keccak256(abi.encode(p))
                && receipt.scopeSubject == snapshot.scopeSubject
                && receipt.observation.recordHash == assemblyReferenceRecord
                && receipt.observation.revision == 1
                && receipt.observation.recorder == address(this)
                && receipt.observation.sourcesHash == p.observation.expectedSourcesHash
                && receipt.observation.payloadHash == keccak256(canonical)
                && receipt.observation.payloadBytes == canonical.length
                && keccak256(publicationReference.referencePayload(assemblyReferenceRecord))
                    == keccak256(canonical),
            "complete original V2 reference and payload retained"
        );
        publicationReferencePublication = p;
        publicationReferenceReceipt = receipt;
        _publicationLockReference();
    }

    function _publicationReferenceEnvironment(
        string memory environmentJSON,
        string memory browserJSON
    ) private returns (ReferenceObservation.Environment memory env) {
        bytes memory raw = safeVm.parseJsonBytes(environmentJSON, ".environmentABI");
        env = abi.decode(raw, (ReferenceObservation.Environment));
        require(
            keccak256(raw) == keccak256(abi.encode(env)) && env.objectHash == 0
                && env.coverageHash == 0 && env.manifestHash == 0 && env.manifestBytes == 0,
            "literal supplied environment before actual archive bindings"
        );
        ReferenceArchive.Coverage memory cover = _publicationReferenceObject(browserJSON, "", true);
        env.objectHash = cover.objectHash;
        env.coverageHash = cover.coverageHash;
        assemblyReferenceFirstReceipts[0] = cover.firstReceiptHash;
        assemblyReferenceSecondReceipts[0] = cover.secondReceiptHash;
        bytes memory manifest = StreamReferenceEnvironmentJson.manifest(env);
        require(manifest.length <= type(uint32).max, "bounded environment manifest");
        env.manifestHash = keccak256(manifest);
        env.manifestBytes = uint32(manifest.length);
    }

    function _publicationReferenceCapture(
        string memory capturesJSON,
        string memory prefix,
        uint256 membershipIndex,
        bytes32 environmentManifestHash,
        uint256 receiptIndex
    ) private returns (ReferenceObservation.Capture memory c) {
        ReferenceContent.Output memory output =
            publicationCheckpoint.outputAt(publicationContent, membershipIndex);
        c.tokenId = output.leaf.tokenId;
        (bool exists, uint256 collectionId, uint256 serial,) =
            ReferenceCore(address(assemblyCore)).tokenCollectionIdentity(c.tokenId);
        require(
            exists && collectionId == publicationGraph.scope.collectionId && serial != 0
                && assemblyVm.parseJsonUint(capturesJSON, string.concat(prefix, ".tokenId"))
                    == c.tokenId
                && assemblyVm.parseJsonUint(
                    capturesJSON, string.concat(prefix, ".collectionSerial")
                ) == serial,
            "supplied capture names actual checkpoint token and Core serial"
        );
        c.collectionSerial = serial;
        c.animationHTML = safeVm.parseJsonBytes(capturesJSON, string.concat(prefix, ".html"));
        bytes memory json =
            safeVm.parseJsonBytes(capturesJSON, string.concat(prefix, ".metadataJSON"));
        require(
            c.animationHTML.length != 0 && c.animationHTML.length <= 40960 && json.length != 0
                && json.length <= 65536
                && keccak256(c.animationHTML) == keccak256(publicationHTML[c.tokenId])
                && keccak256(json) == keccak256(publicationJSON[c.tokenId])
                && keccak256(c.animationHTML) == output.leaf.animationHash
                && keccak256(c.animationHTML) == output.htmlHash
                && keccak256(json) == output.leaf.metadataHash,
            "supplied capture input is exact retained full STATIC output"
        );
        require(
            !_referenceContains(json, bytes("attribution_unavailable"))
                && !_referenceContains(c.animationHTML, bytes("attribution_unavailable")),
            "actual available Artist attribution required"
        );
        c.metadataJSONHash = keccak256(json);
        c.htmlHash = keccak256(c.animationHTML);
        c.htmlBytes = uint32(c.animationHTML.length);
        c.sourceSha256 = sha256(c.animationHTML);
        ReferenceArchive.Coverage memory cover =
            _publicationReferenceObject(capturesJSON, prefix, false);
        c.objectHash = cover.objectHash;
        c.coverageHash = cover.coverageHash;
        c.repeatCaptureSha256 = [
            bytes32(
                safeVm.parseJsonBytes(capturesJSON, string.concat(prefix, ".repeatCapture0Sha256"))
            ),
            bytes32(
                safeVm.parseJsonBytes(capturesJSON, string.concat(prefix, ".repeatCapture1Sha256"))
            )
        ];
        require(
            c.repeatCaptureSha256[0] != 0 && c.repeatCaptureSha256[0] == cover.sha256Digest
                && c.repeatCaptureSha256[1] == cover.sha256Digest,
            "both supplied observations equal the actual archived PNG identity"
        );
        c.environmentManifestHash = environmentManifestHash;
        // EVM record time only. Browser wall time and execution provenance belong to the
        // separately supplied capture report; this helper does not manufacture that evidence.
        c.capturedAt = uint64(block.timestamp);
        assemblyReferenceFirstReceipts[receiptIndex] = cover.firstReceiptHash;
        assemblyReferenceSecondReceipts[receiptIndex] = cover.secondReceiptHash;
    }

    function _publicationReferenceObject(string memory json, string memory prefix, bool runtime)
        internal
        returns (ReferenceArchive.Coverage memory)
    {
        uint256 size = assemblyVm.parseJsonUint(json, string.concat(prefix, ".byteSize"));
        require(size != 0 && size <= type(uint64).max, "literal bounded archive object size");
        ReferenceArchive.ObjectIdentity memory object = ReferenceArchive.ObjectIdentity(
            assemblyArtistId,
            runtime
                ? ReferenceCommonDefinitions.ZIP_SCHEMA_ID
                : ReferenceCommonDefinitions.PNG_SCHEMA_ID,
            assemblySchemas.RAW_BYTES(),
            bytes32(safeVm.parseJsonBytes(json, string.concat(prefix, ".contentHash"))),
            bytes32(safeVm.parseJsonBytes(json, string.concat(prefix, ".sha256Digest"))),
            bytes32(safeVm.parseJsonBytes(json, string.concat(prefix, ".arweaveDataRoot"))),
            uint64(size),
            runtime ? keccak256("IANA:application/zip") : keccak256("IANA:image/png"),
            ReferenceCommonDefinitions.FORMAT_CATALOG_ID,
            ReferenceCommonDefinitions.FORMAT_CATALOG_HASH
        );
        return _assemblyCoverExternal(
            object,
            safeVm.parseJsonBytes(json, string.concat(prefix, ".firstDataPath")),
            safeVm.parseJsonBytes(json, string.concat(prefix, ".lastDataPath")),
            safeVm.parseJsonBytes(json, string.concat(prefix, ".firstChunkRaw")),
            safeVm.parseJsonBytes(json, string.concat(prefix, ".lastChunkRaw"))
        );
    }

    function _publicationLockReference() private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            publicationReference.lockTransition(publicationGraph.scope);
        bytes32 action = _assemblyGovernanceCall(
            2,
            address(publicationReference),
            abi.encodeCall(publicationReference.lockReference, (publicationGraph.scope)),
            scope,
            oldHash,
            newHash
        );
        ReferenceObservation.Lock memory locked =
            publicationReference.referenceLock(publicationGraph.scope);
        require(
            locked.actionId == action && locked.recordHash == assemblyReferenceRecord
                && locked.revision == publicationReferenceReceipt.observation.revision,
            "real governed terminal reference lock"
        );
        require(
            keccak256(
                abi.encode(
                    publicationReference.requireCurrent(
                        publicationGraph.scope, assemblyReferenceRecord, locked.revision
                    )
                )
            ) == keccak256(abi.encode(publicationReferenceReceipt)),
            "same original reference remains current after actual lock"
        );
    }

    function _referenceContains(bytes memory value, bytes memory needle)
        private
        pure
        returns (bool)
    {
        if (needle.length > value.length) return false;
        for (uint256 i; i <= value.length - needle.length; ++i) {
            bool same = true;
            for (uint256 j; j < needle.length; ++j) {
                if (value[i + j] != needle[j]) {
                    same = false;
                    break;
                }
            }
            if (same) return true;
        }
        return false;
    }
}
