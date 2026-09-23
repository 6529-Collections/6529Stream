// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityScopedPolicyPublicationFixture
} from "./StreamCurrentAuthorityScopedPolicyPublicationFixture.sol";
import {
    StreamScopedPolicyReferencePublicationV2 as ScopedReferenceHost
} from "../../smart-contracts/domains/preservation/StreamScopedPolicyReferencePublicationV2.sol";
import {
    StreamScopedPolicyReferenceTypesV2 as ScopedReference
} from "../../smart-contracts/interfaces/stream/preservation/StreamScopedPolicyReferenceTypesV2.sol";
import {
    StreamReferenceRenderTypes as ScopedObservation
} from "../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamScopedPolicySnapshotTypesV2 as ScopedReferenceSnapshot
} from "../../smart-contracts/interfaces/stream/metadata/StreamScopedPolicySnapshotTypesV2.sol";
import {
    IStreamScopedPolicySnapshotPublicationV2 as ScopedReferenceSnapshots
} from "../../smart-contracts/interfaces/stream/metadata/IStreamScopedPolicySnapshotPublicationV2.sol";
import {
    IStreamScopedPolicyContentCheckpointV2 as ScopedReferenceCheckpoint
} from "../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyContentCheckpointV2.sol";
import {
    StreamExternalArtifactTypes as ScopedReferenceArchive
} from "../../smart-contracts/interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import {
    IStreamSchemaRegistry as ScopedReferenceSchema
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamCoreIdentity as ScopedReferenceCore
} from "../../smart-contracts/interfaces/stream/core/IStreamCoreIdentity.sol";
import {
    StreamScopedPolicyReferenceDefinitionsV2 as ScopedReferenceDefinitions
} from "../../smart-contracts/domains/records/StreamScopedPolicyReferenceDefinitionsV2.sol";
import {
    StreamReferenceRenderDefinitions as ScopedReferenceCommon
} from "../../smart-contracts/domains/records/StreamReferenceRenderDefinitions.sol";
import {
    StreamReferenceEnvironmentJson as ScopedReferenceEnvironment
} from "../../smart-contracts/domains/records/StreamReferenceEnvironmentJson.sol";
import {
    StreamRecordFamilies as ScopedReferenceFamilies
} from "../../smart-contracts/domains/records/StreamRecordFamilies.sol";

/// @notice Genuine scoped-policy reference publication from explicitly supplied observations.
/// @dev This helper executes the real graph child, native byte retention, external-object proof/
/// receipt/fixity pipeline and optional governed lock. It never runs a browser or substitutes
/// capture output. Supplied engine/package facts and repeated PNG observations remain the
/// separately auditable offchain boundary. Archive checkpoint observers are the existing local
/// fixture signers, not a claim of live Arweave delivery. No old native capture files or renderer
/// catalog are selected. Complete inventory and Finality require their own later stages.
abstract contract StreamCurrentAuthorityScopedPolicyReferenceFixture is
    StreamCurrentAuthorityScopedPolicyPublicationFixture
{
    struct AuthorityScopedReference {
        address host;
        bytes32 recordHash;
        ScopedReference.Receipt receipt;
        ScopedReference.Publication publication;
        ScopedReference.SourceFacts source;
        bytes canonical;
        bytes environmentManifest;
        bytes32 inputsHash;
        // Runtime ZIP, first membership PNG, last membership PNG. The last slot remains zero
        // when the complete scope contains only one token.
        ScopedReferenceArchive.Coverage[3] coverage;
        bytes32[3] firstReceipts;
        bytes32[3] secondReceipts;
        bytes32 lockAction;
    }

    /// @dev environmentJSON.environmentABI is canonical abi.encode(Environment), with only the
    /// first four archive/manifest fields zero. No browser version, platform or clock is invented.
    /// browserJSON provides the runtime ZIP's native endpoint identity and proofs.
    /// capturesJSON.capture1 and (when distinct) capture2 provide tokenId, collectionSerial,
    /// hex html/metadataJSON, exact 32-byte repeatCapture0Sha256/repeatCapture1Sha256, and the
    /// archived PNG's endpoint fields. These must come from a fresh export/capture of this graph.
    function _authorityPublishScopedPolicyReference(
        AuthorityScopedPublication memory publication,
        string memory environmentJSON,
        string memory browserJSON,
        string memory capturesJSON,
        bool lockReference
    ) internal returns (AuthorityScopedReference memory result) {
        ScopedReferenceHost host = _scopedReferencePrepare(publication);
        result.host = address(host);
        result.inputsHash = keccak256(abi.encode(environmentJSON, browserJSON, capturesJSON));
        ScopedReference.Publication memory p;
        p.scope = publication.scope;
        p.observation.collectionId = p.scope.collectionId;
        p.observation.referenceId = keccak256(
            abi.encode(
                "current-authority supplied scoped-policy reference observations",
                publication.graph.graphId,
                publication.snapshot.recordHash,
                result.inputsHash
            )
        );
        p.observation.snapshotRecordHash = publication.snapshot.recordHash;
        p.observation.snapshotRevision = publication.snapshot.revision;
        p.observation.reasonHash = result.inputsHash;
        p.observation.manifestURI = "urn:fixture:current-authority:scoped-policy-reference";
        require(
            block.timestamp != 0 && block.timestamp <= type(uint64).max, "bounded EVM record time"
        );
        p.observation.effectiveAt = uint64(block.timestamp);
        (p.observation.environment, result.environmentManifest, result.coverage[0]) =
            _scopedReferenceEnvironment(environmentJSON, browserJSON);
        uint256 count = publication.checkpoint.tokenCount == 1 ? 1 : 2;
        p.observation.captures = new ScopedObservation.Capture[](count);
        for (uint256 i; i < count; ++i) {
            (p.observation.captures[i], result.coverage[i + 1]) = _scopedReferenceCapture(
                publication,
                capturesJSON,
                i == 0 ? ".capture1" : ".capture2",
                i == 0 ? 0 : publication.checkpoint.tokenCount - 1,
                p.observation.environment.manifestHash
            );
        }
        for (uint256 i; i <= count; ++i) {
            result.firstReceipts[i] = result.coverage[i].firstReceiptHash;
            result.secondReceipts[i] = result.coverage[i].secondReceiptHash;
            require(
                result.firstReceipts[i] != 0 && result.secondReceipts[i] != 0,
                "actual independent original receipt pair"
            );
        }
        _scopedReferencePrepareEnvironment(
            host, p.observation.environment, result.environmentManifest
        );
        (p.observation.expectedSourcesHash,) = host.previewReference(p, address(this));
        (bytes32 sourceHash, bytes memory canonical) = host.previewReference(p, address(this));
        require(
            sourceHash == p.observation.expectedSourcesHash && sourceHash != 0,
            "stable complete reference source"
        );
        _assemblyUpload(canonical);
        _assemblyUpload(abi.encode(p));
        result.recordHash = host.publishReference(p);
        (result.publication, result.receipt) = host.referenceRecord(result.recordHash);
        result.canonical = host.referencePayload(result.recordHash);
        result.source = host.referenceSource(result.recordHash);
        _scopedReferenceRequireSaved(publication, p, canonical, result);
        if (lockReference) result.lockAction = _scopedReferenceLock(host, result);
    }

    function _scopedReferencePrepare(AuthorityScopedPublication memory publication)
        private
        returns (ScopedReferenceHost host)
    {
        require(
            publication.scope.collectionId == 1 && publication.graph.preparedChildren == 7
                && keccak256(abi.encode(publication.scope))
                    == keccak256(abi.encode(publication.graph.scope))
                && publication.snapshot.recordHash != 0 && publication.rootHash != 0,
            "complete actual scoped graph and accepted root precede reference"
        );
        for (uint256 i; i < 7; ++i) {
            address child = publication.graph.children[i];
            require(
                child.code.length != 0 && child.codehash == publication.graph.codeHashes[i],
                "exact actual scoped child runtime"
            );
        }
        host = ScopedReferenceHost(publication.graph.children[4]);
        require(
            host.core() == address(assemblyCore) && host.metadataHost() == address(assemblyMetadata)
                && host.metadataRouter() == address(assemblyRouter)
                && host.snapshots() == publication.graph.children[3]
                && host.archiveCoverage() == address(assemblyExternal)
                && host.scopedPolicyReferenceProfile()
                    == keccak256("6529STREAM_SCOPED_POLICY_REFERENCE_V2")
                && host.referenceCount(publication.scope) == 0,
            "same original empty scoped reference child"
        );
        ScopedReferenceSnapshot.Receipt memory snapshot = ScopedReferenceSnapshots(host.snapshots())
            .requireCurrent(
                publication.scope, publication.snapshot.recordHash, publication.snapshot.revision
            );
        ScopedReferenceCheckpoint.Plan memory checkpoint = ScopedReferenceCheckpoint(
                publication.graph.children[1]
            ).requireCurrentCheckpoint(publication.checkpointId);
        require(
            keccak256(abi.encode(snapshot)) == keccak256(abi.encode(publication.snapshot))
                && keccak256(abi.encode(checkpoint))
                    == keccak256(abi.encode(publication.checkpoint)) && checkpoint.tokenCount != 0
                && checkpoint.nextIndex == checkpoint.tokenCount
                && keccak256(abi.encode(checkpoint.scope))
                    == keccak256(abi.encode(publication.scope))
                && assemblyMembership.requireScopeMembership(publication.scope).tokenCount
                    == checkpoint.tokenCount,
            "same complete current snapshot, checkpoint and membership"
        );
        _scopedReferenceDefinitions();
        (bool enabled,) = assemblyMetadata.familyWriter(
            publication.scope.collectionId, ScopedReferenceFamilies.CURATOR, 3, address(this)
        );
        if (!enabled) _assemblyGrantFamily(ScopedReferenceFamilies.CURATOR, 3, address(this));
    }

    function _scopedReferenceDefinitions() private {
        string[7] memory names = [
            "STREAM_SCOPED_POLICY_REFERENCE_ABI_V2",
            "STREAM_SCOPED_POLICY_REFERENCE_PROFILE_V2",
            "STREAM_ABI_SCOPED_POLICY_REFERENCE_V2",
            "STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1",
            "STREAM_REFERENCE_PNG_OBJECT_V1",
            "STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1",
            "STREAM_REFERENCE_NATIVE_FORMATS_V1"
        ];
        bytes32[7] memory hashes = [
            ScopedReferenceDefinitions.SCHEMA_HASH,
            ScopedReferenceDefinitions.PROFILE_HASH,
            ScopedReferenceDefinitions.CANON_HASH,
            ScopedReferenceCommon.ENVIRONMENT_SCHEMA_HASH,
            ScopedReferenceCommon.PNG_SCHEMA_HASH,
            ScopedReferenceCommon.ZIP_SCHEMA_HASH,
            ScopedReferenceCommon.FORMAT_CATALOG_HASH
        ];
        uint256[7] memory lengths = [
            uint256(ScopedReferenceDefinitions.SCHEMA_BYTES),
            ScopedReferenceDefinitions.PROFILE_BYTES,
            ScopedReferenceDefinitions.CANON_BYTES,
            ScopedReferenceCommon.ENVIRONMENT_SCHEMA_BYTES,
            ScopedReferenceCommon.PNG_SCHEMA_BYTES,
            ScopedReferenceCommon.ZIP_SCHEMA_BYTES,
            ScopedReferenceCommon.FORMAT_CATALOG_BYTES
        ];
        for (uint256 i; i < names.length; ++i) {
            string memory path = i < 3
                ? string.concat(
                    "docs/schemas/preservation/scoped-policy-reference-v2.",
                    i == 0 ? "schema" : i == 1 ? "profile" : "abi",
                    ".json"
                )
                : string.concat("schemas/records/", names[i], ".json");
            bytes memory raw = bytes(assemblyVm.readFile(path));
            require(
                raw.length == lengths[i] && keccak256(raw) == hashes[i],
                "literal scoped reference definition bytes"
            );
            ScopedReferenceSchema.DocumentKind kind = i == 2
                ? ScopedReferenceSchema.DocumentKind.CANONICALIZATION
                : (i == 1 || i == 6)
                    ? ScopedReferenceSchema.DocumentKind.CATALOG
                    : ScopedReferenceSchema.DocumentKind.SCHEMA;
            bytes32 id = keccak256(bytes(names[i]));
            ScopedReferenceSchema.DocumentView memory retained = assemblySchemas.document(id);
            if (!retained.exists) {
                require(
                    _assemblyRegisterDocument(names[i], kind, raw, assemblySchemas.RAW_BYTES())
                        == id,
                    "actual scoped reference definition registration"
                );
                retained = assemblySchemas.document(id);
            }
            require(
                retained.status == ScopedReferenceSchema.DocumentStatus.ACTIVE
                    && retained.specification.kind == kind
                    && retained.specification.contentHash == hashes[i]
                    && retained.specification.totalBytes == lengths[i]
                    && retained.specification.canonicalizationId == assemblySchemas.RAW_BYTES()
                    && keccak256(assemblySchemas.documentBytes(id)) == hashes[i],
                "active exact scoped reference definition"
            );
        }
    }

    function _scopedReferenceEnvironment(string memory environmentJSON, string memory browserJSON)
        private
        returns (
            ScopedObservation.Environment memory env,
            bytes memory manifest,
            ScopedReferenceArchive.Coverage memory cover
        )
    {
        bytes memory raw = safeVm.parseJsonBytes(environmentJSON, ".environmentABI");
        env = abi.decode(raw, (ScopedObservation.Environment));
        require(
            keccak256(raw) == keccak256(abi.encode(env)) && env.objectHash == 0
                && env.coverageHash == 0 && env.manifestHash == 0 && env.manifestBytes == 0,
            "complete supplied environment before actual archive binding"
        );
        cover = _scopedReferenceObject(browserJSON, "", true);
        env.objectHash = cover.objectHash;
        env.coverageHash = cover.coverageHash;
        manifest = ScopedReferenceEnvironment.manifest(env);
        require(
            manifest.length != 0 && manifest.length <= 524288, "bounded exact environment manifest"
        );
        env.manifestHash = keccak256(manifest);
        env.manifestBytes = uint32(manifest.length);
    }

    function _scopedReferencePrepareEnvironment(
        ScopedReferenceHost host,
        ScopedObservation.Environment memory env,
        bytes memory manifest
    ) private {
        bytes memory files = bytes(ScopedReferenceEnvironment.files(env.packageFiles, true));
        _assemblyUpload(files);
        bytes32 id = host.prepareFileInventory(env.packageFiles, true);
        require(
            keccak256(host.preparedFileInventory(id)) == keccak256(files),
            "complete original package inventory"
        );
        files = bytes(ScopedReferenceEnvironment.files(env.platformPrerequisites, false));
        _assemblyUpload(files);
        id = host.prepareFileInventory(env.platformPrerequisites, false);
        require(
            keccak256(host.preparedFileInventory(id)) == keccak256(files),
            "complete original platform inventory"
        );
        _assemblyUpload(manifest);
        id = host.prepareEnvironment(env);
        require(
            keccak256(host.preparedFileInventory(id)) == keccak256(manifest),
            "complete exact environment retention"
        );
    }

    function _scopedReferenceCapture(
        AuthorityScopedPublication memory publication,
        string memory capturesJSON,
        string memory prefix,
        uint256 membershipIndex,
        bytes32 environmentManifestHash
    )
        private
        returns (
            ScopedObservation.Capture memory capture,
            ScopedReferenceArchive.Coverage memory cover
        )
    {
        uint256 token = assemblyMembership.scopeTokenAt(publication.scope, membershipIndex);
        ScopedReferenceCheckpoint.Output memory output = ScopedReferenceCheckpoint(
                publication.graph.children[1]
            ).outputAt(publication.checkpointId, membershipIndex);
        (bool exists, uint256 cid, uint256 serial,) =
            ScopedReferenceCore(address(assemblyCore)).tokenCollectionIdentity(token);
        require(
            exists && cid == publication.scope.collectionId && serial != 0
                && output.leaf.tokenId == token
                && assemblyVm.parseJsonUint(capturesJSON, string.concat(prefix, ".tokenId"))
                    == token
                && assemblyVm.parseJsonUint(
                    capturesJSON, string.concat(prefix, ".collectionSerial")
                ) == serial,
            "capture names the actual membership token and Core serial"
        );
        capture.tokenId = token;
        capture.collectionSerial = serial;
        capture.animationHTML = safeVm.parseJsonBytes(capturesJSON, string.concat(prefix, ".html"));
        bytes memory json =
            safeVm.parseJsonBytes(capturesJSON, string.concat(prefix, ".metadataJSON"));
        require(
            capture.animationHTML.length != 0 && capture.animationHTML.length <= 40960
                && json.length != 0 && json.length <= 65536
                && keccak256(capture.animationHTML)
                    == keccak256(bytes(assemblyRouter.tokenHTML(token)))
                && keccak256(json) == keccak256(bytes(assemblyRouter.tokenJSON(token)))
                && keccak256(capture.animationHTML) == output.leaf.animationHash
                && keccak256(capture.animationHTML) == output.htmlHash
                && keccak256(json) == output.leaf.metadataHash,
            "supplied capture is exact current Router HTML/JSON and accepted checkpoint"
        );
        require(
            !_scopedReferenceContains(json, bytes("attribution_unavailable")),
            "available actual Artist attribution"
        );
        capture.metadataJSONHash = keccak256(json);
        capture.htmlHash = keccak256(capture.animationHTML);
        capture.htmlBytes = uint32(capture.animationHTML.length);
        capture.sourceSha256 = sha256(capture.animationHTML);
        cover = _scopedReferenceObject(capturesJSON, prefix, false);
        capture.objectHash = cover.objectHash;
        capture.coverageHash = cover.coverageHash;
        capture.repeatCaptureSha256[0] =
            _scopedReferenceHash(capturesJSON, string.concat(prefix, ".repeatCapture0Sha256"));
        capture.repeatCaptureSha256[1] =
            _scopedReferenceHash(capturesJSON, string.concat(prefix, ".repeatCapture1Sha256"));
        require(
            capture.repeatCaptureSha256[0] == cover.sha256Digest
                && capture.repeatCaptureSha256[1] == cover.sha256Digest,
            "both supplied PNG observations match actual archived identity"
        );
        capture.environmentManifestHash = environmentManifestHash;
        // This is EVM publication observation time, not a fabricated browser wall-clock report.
        capture.capturedAt = uint64(block.timestamp);
    }

    function _scopedReferenceObject(string memory json, string memory prefix, bool runtime)
        private
        returns (ScopedReferenceArchive.Coverage memory cover)
    {
        uint256 size = assemblyVm.parseJsonUint(json, string.concat(prefix, ".byteSize"));
        require(size != 0 && size <= type(uint64).max, "exact bounded external object size");
        bytes32 content = _scopedReferenceHash(json, string.concat(prefix, ".contentHash"));
        bytes32 digest = _scopedReferenceHash(json, string.concat(prefix, ".sha256Digest"));
        bytes32 dataRoot = _scopedReferenceHash(json, string.concat(prefix, ".arweaveDataRoot"));
        cover = _assemblyReferenceObject(json, prefix, runtime);
        require(
            cover.contentHash == content && cover.sha256Digest == digest
                && cover.arweaveDataRoot == dataRoot && cover.byteSize == size
                && cover.artistId == assemblyArtistId && cover.objectHash != 0
                && cover.coverageHash != 0,
            "actual external proof and coverage retain supplied object identity"
        );
    }

    function _scopedReferenceHash(string memory json, string memory path)
        private
        pure
        returns (bytes32 value)
    {
        bytes memory raw = safeVm.parseJsonBytes(json, path);
        require(raw.length == 32, "exact hash width in supplied observation");
        value = bytes32(raw);
        require(value != 0, "nonzero supplied observation hash");
    }

    function _scopedReferenceRequireSaved(
        AuthorityScopedPublication memory original,
        ScopedReference.Publication memory submitted,
        bytes memory canonical,
        AuthorityScopedReference memory saved
    ) private view {
        ScopedObservation.Receipt memory receipt = saved.receipt.observation;
        require(
            keccak256(abi.encode(saved.publication)) == keccak256(abi.encode(submitted))
                && saved.receipt.scopeSubject == original.snapshot.scopeSubject
                && receipt.recordHash == saved.recordHash && receipt.revision == 1
                && receipt.predecessor == 0 && receipt.recorder == address(this)
                && receipt.authorizationClass == 3 && receipt.grantRevision != 0
                && receipt.snapshotRecordHash == original.snapshot.recordHash
                && receipt.snapshotRevision == original.snapshot.revision
                && receipt.sourcesHash == submitted.observation.expectedSourcesHash
                && receipt.payloadHash == keccak256(canonical)
                && receipt.payloadBytes == canonical.length
                && keccak256(saved.canonical) == keccak256(canonical)
                && receipt.schemaHash == ScopedReferenceDefinitions.SCHEMA_HASH
                && receipt.profileHash == ScopedReferenceDefinitions.PROFILE_HASH
                && receipt.canonicalizationHash == ScopedReferenceDefinitions.CANON_HASH,
            "exact original scoped reference publication, receipt and complete payload"
        );
        require(
            keccak256(abi.encode(saved.source.snapshot)) == keccak256(abi.encode(original.snapshot))
                && saved.source.contentRootRecordHash == original.rootHash
                && keccak256(abi.encode(saved.source.contentRoot))
                    == keccak256(abi.encode(original.root))
                && keccak256(abi.encode(saved.source.contentRootBinding))
                    == keccak256(abi.encode(original.binding))
                && keccak256(abi.encode(saved.source.environmentCoverage))
                    == keccak256(abi.encode(saved.coverage[0]))
                && saved.source.samples.length == submitted.observation.captures.length,
            "exact genuine snapshot, scoped CONTENT_ROOT and external environment joins"
        );
        for (uint256 i; i < saved.source.samples.length; ++i) {
            require(
                saved.source.samples[i].membershipIndex
                        == (i == 0 ? 0 : original.checkpoint.tokenCount - 1)
                    && keccak256(abi.encode(saved.source.samples[i].observation.captureCoverage))
                    == keccak256(abi.encode(saved.coverage[i + 1])),
                "actual first/last ordinal and full original PNG coverage"
            );
        }
        ScopedReferenceHost host = ScopedReferenceHost(saved.host);
        require(
            host.referenceCount(original.scope) == 1
                && host.referenceAt(original.scope, 0) == saved.recordHash
                && keccak256(
                    abi.encode(
                        host.requireCurrent(original.scope, saved.recordHash, receipt.revision)
                    )
                ) == keccak256(abi.encode(saved.receipt)),
            "same exact current scoped reference history"
        );
    }

    function _scopedReferenceLock(ScopedReferenceHost host, AuthorityScopedReference memory saved)
        private
        returns (bytes32 action)
    {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            host.lockTransition(saved.publication.scope);
        action = _assemblyGovernanceCall(
            2,
            address(host),
            abi.encodeCall(host.lockReference, (saved.publication.scope)),
            scope,
            oldHash,
            newHash
        );
        ScopedObservation.Lock memory locked = host.referenceLock(saved.publication.scope);
        require(
            locked.actionId == action && action != 0 && locked.recordHash == saved.recordHash
                && locked.revision == saved.receipt.observation.revision
                && keccak256(
                    abi.encode(
                        host.requireCurrent(
                            saved.publication.scope, saved.recordHash, locked.revision
                        )
                    )
                ) == keccak256(abi.encode(saved.receipt)),
            "actual class-2 governed lock preserves the exact reference"
        );
    }

    function _scopedReferenceContains(bytes memory source, bytes memory needle)
        private
        pure
        returns (bool)
    {
        if (needle.length > source.length) return false;
        for (uint256 i; i <= source.length - needle.length; ++i) {
            bool same = true;
            for (uint256 j; j < needle.length; ++j) {
                if (source[i + j] != needle[j]) {
                    same = false;
                    break;
                }
            }
            if (same) return true;
        }
        return false;
    }
}
