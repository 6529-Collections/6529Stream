// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentFullPreservationPolicyViewPublicationFixture
} from "./StreamCurrentFullPreservationPolicyViewPublicationFixture.sol";
import {
    StreamViewPreservationReferencePublicationV1
} from "../../smart-contracts/domains/preservation/StreamViewPreservationReferencePublicationV1.sol";
import {
    StreamViewPreservationReferenceTypesV1 as PolicyReference
} from "../../smart-contracts/interfaces/stream/preservation/StreamViewPreservationReferenceTypesV1.sol";
import {
    StreamReferenceRenderTypes as ReferenceObservation
} from "../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamViewPreservationSnapshotTypesV1 as ReferenceSnapshot
} from "../../smart-contracts/interfaces/stream/metadata/StreamViewPreservationSnapshotTypesV1.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as ReferenceContent
} from "../../smart-contracts/interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
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
    StreamViewPreservationReferenceDefinitionsV1 as ReferenceDefinitions
} from "../../smart-contracts/domains/records/StreamViewPreservationReferenceDefinitionsV1.sol";
import {
    StreamReferenceRenderDefinitions as ReferenceCommonDefinitions
} from "../../smart-contracts/domains/records/StreamReferenceRenderDefinitions.sol";
import {
    StreamReferenceEnvironmentJson
} from "../../smart-contracts/domains/records/StreamReferenceEnvironmentJson.sol";
import {
    StreamRecordFamilies
} from "../../smart-contracts/domains/records/StreamRecordFamilies.sol";
import {
    IStreamGasParameterHost as ReferenceGas
} from "../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";

/// @notice Actual VIEW preservation reference publication after its genuine snapshot and Artist op17 root.
/// @dev Browser execution is an explicit supplied-observation boundary. This helper validates
/// exact input/output identities and real archive receipts; it does not execute a browser or
/// prove that supplied repeated PNG observations came from that browser. No old native captures
/// are selected implicitly. Fresh independently captured evidence must name these exact complete
/// non-sanction VIEW input bytes. Browser execution/provenance remains separately verified;
/// synthetic observations exercising this fixture cannot establish browser acceptance.
abstract contract StreamCurrentFullPreservationPolicyViewReferenceFixture is
    StreamCurrentFullPreservationPolicyViewPublicationFixture
{
    StreamViewPreservationReferencePublicationV1 internal viewReference;
    PolicyReference.Publication internal viewReferencePublication;
    PolicyReference.Receipt internal viewReferenceReceipt;
    bytes32 internal assemblyViewReferenceRecord;
    bytes32[3] internal assemblyViewReferenceFirstReceipts;
    bytes32[3] internal assemblyViewReferenceSecondReceipts;
    bytes32 internal viewObservationInputsHash;

    /// @dev Caller supplies the unchanged original C component tuple [1m,16m,16m,1m].
    /// These are read/source/snapshot/archive caps, not measured whole-transaction capacity.
    /// The constructor derives every target from the genuine current construction graph.
    function _viewDeployReference(uint256[4] memory caps) internal {
        require(address(viewReference) == address(0), "one actual VIEW reference host");
        PolicyReference.Dependencies memory d;
        d.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(assemblySchemas),
            address(assemblyStore),
            address(assemblyRouter),
            address(assemblyViewPreservationSnapshot),
            address(assemblyExternal)
        ];
        for (uint256 i; i < d.targets.length; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = caps[0];
        d.sourceGas = caps[1];
        d.snapshotGas = caps[2];
        d.archiveGas = caps[3];
        ReferenceGas.GasParameterConfig[4] memory gasConfig;
        gasConfig[0] = ReferenceGas.GasParameterConfig(
            "VIEW_PRESERVATION_REFERENCE_READ_GAS", caps[0], 50000, 1
        );
        gasConfig[1] = ReferenceGas.GasParameterConfig(
            "VIEW_PRESERVATION_REFERENCE_SOURCE_GAS", caps[1], 50000, 1
        );
        gasConfig[2] = ReferenceGas.GasParameterConfig(
            "VIEW_PRESERVATION_REFERENCE_SNAPSHOT_GAS", caps[2], 50000, 1
        );
        gasConfig[3] = ReferenceGas.GasParameterConfig(
            "VIEW_PRESERVATION_REFERENCE_ARCHIVE_GAS", caps[3], 50000, 1
        );
        bytes memory arguments = abi.encode(d, address(assemblyExecutor), gasConfig);
        require(
            type(StreamViewPreservationReferencePublicationV1).creationCode.length
                    + arguments.length <= 49152,
            "actual VIEW reference initcode fits"
        );
        viewReference = new StreamViewPreservationReferencePublicationV1(
            d, address(assemblyExecutor), gasConfig
        );
        require(
            address(viewReference).code.length != 0 && address(viewReference).code.length <= 24576,
            "actual VIEW reference runtime fits"
        );
        require(
            keccak256(abi.encode(viewReference.dependencies())) == keccak256(abi.encode(d)),
            "exact original VIEW reference constructor dependencies"
        );
    }

    function _viewPrepareReferenceDefinitions() internal {
        require(
            address(viewReference) != address(0) && fullPolicyViewScope.collectionId == 1
                && viewReference.core() == address(assemblyCore)
                && viewReference.metadataHost() == address(assemblyMetadata)
                && viewReference.metadataRouter() == address(assemblyRouter)
                && viewReference.snapshots() == address(assemblyViewPreservationSnapshot)
                && viewReference.archiveCoverage() == address(assemblyExternal),
            "same actual VIEW reference graph"
        );
        string[7] memory names = [
            "STREAM_VIEW_PRESERVATION_REFERENCE_RENDER_ABI_V1",
            "STREAM_VIEW_PRESERVATION_REFERENCE_RENDER_PROFILE_V1",
            "STREAM_VIEW_PRESERVATION_REFERENCE_CANON_V1",
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
                    "schemas/preservation/view-preservation-reference-v1/",
                    i == 0 ? "schema" : i == 1 ? "profile" : "canon",
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
            fullPolicyViewScope.collectionId, StreamRecordFamilies.CURATOR, 3, address(this)
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
    function _viewPublishReference(
        string memory environmentJSON,
        string memory browserJSON,
        string memory capturesJSON
    ) internal {
        require(
            address(viewReference) != address(0) && assemblyViewReferenceRecord == 0
                && assemblyViewSnapshotRecord != 0 && assemblyViewOriginalContentRoot != 0,
            "actual VIEW reference follows snapshot and original Artist root"
        );
        ReferenceSnapshot.Receipt memory snapshot = assemblyViewPreservationSnapshot.requireCurrent(
            fullPolicyViewScope,
            assemblyViewSnapshotRecord,
            assemblyViewPreservationSnapshot.currentSnapshot(fullPolicyViewScope).revision
        );
        ReferenceContent.Plan memory content =
            assemblyViewPreservationCheckpoint.requireCurrentCheckpoint(viewPublicationCheckpoint);
        require(
            content.tokenCount != 0 && content.nextIndex == content.tokenCount
                && keccak256(abi.encode(content.scope))
                    == keccak256(abi.encode(fullPolicyViewScope)),
            "complete same-scope output checkpoint"
        );
        viewObservationInputsHash =
            keccak256(abi.encode(environmentJSON, browserJSON, capturesJSON));
        ReferenceObservation.Environment memory env =
            _viewReferenceEnvironment(environmentJSON, browserJSON);
        PolicyReference.Publication memory p;
        p.scope = fullPolicyViewScope;
        p.observation.collectionId = p.scope.collectionId;
        p.observation.referenceId = keccak256(
            abi.encode(
                "VIEW preservation supplied first and last reference observations",
                fullPolicyViewAdoption,
                assemblyViewSnapshotRecord,
                viewObservationInputsHash
            )
        );
        p.observation.snapshotRecordHash = assemblyViewSnapshotRecord;
        p.observation.snapshotRevision = snapshot.revision;
        p.observation.environment = env;
        p.observation.reasonHash = viewObservationInputsHash;
        p.observation.effectiveAt = uint64(block.timestamp);
        p.observation.manifestURI = "urn:fixture:view-preservation:supplied-reference-observations";
        uint256 count = content.tokenCount == 1 ? 1 : 2;
        p.observation.captures = new ReferenceObservation.Capture[](count);
        for (uint256 i; i < count; ++i) {
            p.observation.captures[i] = _viewReferenceCapture(
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
        viewReference.prepareFileInventory(env.packageFiles, true);
        viewReference.prepareFileInventory(env.platformPrerequisites, false);
        bytes memory environment = StreamReferenceEnvironmentJson.manifest(env);
        require(
            keccak256(environment) == env.manifestHash && environment.length == env.manifestBytes,
            "exact complete supplied environment bytes"
        );
        _assemblyUpload(environment);
        bytes32 environmentId = viewReference.prepareEnvironment(env);
        require(
            environmentId
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_REFERENCE_ENVIRONMENT_PREPARATION_V1"),
                        block.chainid,
                        address(viewReference),
                        env
                    )
                ),
            "original full environment preparation identity"
        );
        require(
            keccak256(viewReference.preparedFileInventory(environmentId)) == env.manifestHash,
            "complete original prepared environment retained"
        );
        (p.observation.expectedSourcesHash,) = viewReference.previewReference(p, address(this));
        (, bytes memory canonical) = viewReference.previewReference(p, address(this));
        _assemblyUpload(canonical);
        _assemblyUpload(abi.encode(p));
        assemblyViewReferenceRecord = viewReference.publishReference(p);
        (PolicyReference.Publication memory original, PolicyReference.Receipt memory receipt) =
            viewReference.referenceRecord(assemblyViewReferenceRecord);
        require(
            keccak256(abi.encode(original)) == keccak256(abi.encode(p))
                && receipt.scopeSubject == snapshot.scopeSubject
                && receipt.observation.recordHash == assemblyViewReferenceRecord
                && receipt.observation.revision == 1
                && receipt.observation.recorder == address(this)
                && receipt.observation.sourcesHash == p.observation.expectedSourcesHash
                && receipt.observation.payloadHash == keccak256(canonical)
                && receipt.observation.payloadBytes == canonical.length
                && keccak256(viewReference.referencePayload(assemblyViewReferenceRecord))
                    == keccak256(canonical),
            "complete original VIEW preservation reference and payload retained"
        );
        viewReferencePublication = p;
        viewReferenceReceipt = receipt;
        _viewAssertReferenceOriginal(canonical, environment);
        _viewLockReference();
    }

    function _viewReferenceEnvironment(string memory environmentJSON, string memory browserJSON)
        private
        returns (ReferenceObservation.Environment memory env)
    {
        bytes memory raw = safeVm.parseJsonBytes(environmentJSON, ".environmentABI");
        env = abi.decode(raw, (ReferenceObservation.Environment));
        require(
            keccak256(raw) == keccak256(abi.encode(env)) && env.objectHash == 0
                && env.coverageHash == 0 && env.manifestHash == 0 && env.manifestBytes == 0,
            "literal supplied environment before actual archive bindings"
        );
        ReferenceArchive.Coverage memory cover = _viewReferenceObject(browserJSON, "", true);
        env.objectHash = cover.objectHash;
        env.coverageHash = cover.coverageHash;
        assemblyViewReferenceFirstReceipts[0] = cover.firstReceiptHash;
        assemblyViewReferenceSecondReceipts[0] = cover.secondReceiptHash;
        bytes memory manifest = StreamReferenceEnvironmentJson.manifest(env);
        require(manifest.length <= type(uint32).max, "bounded environment manifest");
        env.manifestHash = keccak256(manifest);
        env.manifestBytes = uint32(manifest.length);
    }

    function _viewReferenceCapture(
        string memory capturesJSON,
        string memory prefix,
        uint256 membershipIndex,
        bytes32 environmentManifestHash,
        uint256 receiptIndex
    ) private returns (ReferenceObservation.Capture memory c) {
        ReferenceContent.Output memory output =
            assemblyViewPreservationCheckpoint.outputAt(viewPublicationCheckpoint, membershipIndex);
        c.tokenId = output.tokenId;
        (bool exists, uint256 collectionId, uint256 serial, bool burned) =
            ReferenceCore(address(assemblyCore)).tokenCollectionIdentity(c.tokenId);
        require(
            exists && collectionId == fullPolicyViewScope.collectionId && serial != 0
                && serial == output.collectionSerial && burned == output.burned
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
            c.animationHTML.length != 0 && c.animationHTML.length <= 262144 && json.length != 0
                && json.length <= 262144 && c.animationHTML.length == output.htmlBytes
                && json.length == output.jsonBytes
                && keccak256(c.animationHTML) == keccak256(viewPublicationHTML[c.tokenId])
                && keccak256(json) == keccak256(viewPublicationJSON[c.tokenId])
                && keccak256(c.animationHTML) == output.htmlHash
                && keccak256(json) == output.jsonHash,
            "supplied capture input is exact retained complete non-sanction VIEW output"
        );
        require(
            !_viewReferenceContains(json, bytes("attribution_unavailable"))
                && !_viewReferenceContains(c.animationHTML, bytes("attribution_unavailable")),
            "actual available Artist attribution required"
        );
        c.metadataJSONHash = keccak256(json);
        c.htmlHash = keccak256(c.animationHTML);
        c.htmlBytes = uint32(c.animationHTML.length);
        c.sourceSha256 = sha256(c.animationHTML);
        ReferenceArchive.Coverage memory cover = _viewReferenceObject(capturesJSON, prefix, false);
        c.objectHash = cover.objectHash;
        c.coverageHash = cover.coverageHash;
        c.repeatCaptureSha256 = [
            _viewReferenceJsonHash(capturesJSON, string.concat(prefix, ".repeatCapture0Sha256")),
            _viewReferenceJsonHash(capturesJSON, string.concat(prefix, ".repeatCapture1Sha256"))
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
        assemblyViewReferenceFirstReceipts[receiptIndex] = cover.firstReceiptHash;
        assemblyViewReferenceSecondReceipts[receiptIndex] = cover.secondReceiptHash;
    }

    function _viewReferenceObject(string memory json, string memory prefix, bool runtime)
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
            _viewReferenceJsonHash(json, string.concat(prefix, ".contentHash")),
            _viewReferenceJsonHash(json, string.concat(prefix, ".sha256Digest")),
            _viewReferenceJsonHash(json, string.concat(prefix, ".arweaveDataRoot")),
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

    function _viewLockReference() private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            viewReference.lockTransition(fullPolicyViewScope);
        bytes32 action = _assemblyGovernanceCall(
            2,
            address(viewReference),
            abi.encodeCall(viewReference.lockReference, (fullPolicyViewScope)),
            scope,
            oldHash,
            newHash
        );
        ReferenceObservation.Lock memory locked = viewReference.referenceLock(fullPolicyViewScope);
        require(
            locked.actionId == action && locked.recordHash == assemblyViewReferenceRecord
                && locked.revision == viewReferenceReceipt.observation.revision,
            "real governed terminal reference lock"
        );
        require(
            keccak256(
                abi.encode(
                    viewReference.requireCurrent(
                        fullPolicyViewScope, assemblyViewReferenceRecord, locked.revision
                    )
                )
            ) == keccak256(abi.encode(viewReferenceReceipt)),
            "same original reference remains current after actual lock"
        );
    }

    function _viewAssertReferenceOriginal(bytes memory canonical, bytes memory environment)
        private
        view
    {
        PolicyReference.Publication memory p = viewReferencePublication;
        PolicyReference.Receipt memory r = viewReferenceReceipt;
        PolicyReference.SourceFacts memory facts =
            viewReference.referenceSource(assemblyViewReferenceRecord);
        require(
            facts.snapshot.recordHash == assemblyViewSnapshotRecord
                && facts.contentRootRecordHash == assemblyViewOriginalContentRoot
                && facts.contentBinding.adoptionRecord == fullPolicyViewAdoption
                && facts.contentBinding.checkpointRecord == viewPublicationCheckpoint
                && facts.contentBinding.outputManifestRecord == viewPublicationOutputManifest
                && facts.snapshotSource.checkpoint.adoptionRecord == fullPolicyViewAdoption
                && facts.snapshotSource.checkpoint.nextIndex
                    == facts.snapshotSource.membership.tokenCount
                && keccak256(abi.encode(facts.snapshotSource.scope))
                    == keccak256(abi.encode(fullPolicyViewScope)),
            "reference retains actual snapshot root and complete original VIEW source"
        );
        require(
            facts.samples.length == p.observation.captures.length,
            "first-last observations remain distinct from complete inventory"
        );
        for (uint256 i; i < facts.samples.length; ++i) {
            uint256 index = i == 0 ? 0 : facts.snapshotSource.membership.tokenCount - 1;
            ReferenceContent.Output memory row =
                assemblyViewPreservationCheckpoint.outputAt(viewPublicationCheckpoint, index);
            require(
                facts.samples[i].membershipIndex == index
                    && keccak256(abi.encode(facts.samples[i].output)) == keccak256(abi.encode(row))
                    && row.tokenId == p.observation.captures[i].tokenId,
                "all 31 original output words retained without terminal-finalized conversion"
            );
        }
        PolicyReference.Dependencies memory d = viewReference.dependencies();
        require(
            r.observation.sourcesHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_PRESERVATION_REFERENCE_SOURCES_V1"),
                        d.chainId,
                        address(viewReference),
                        d.targets,
                        d.codeHashes,
                        facts
                    )
                ),
            "literal VIEW source commitment"
        );
        PolicyReference.Receipt memory originalFields =
            abi.decode(abi.encode(r), (PolicyReference.Receipt));
        originalFields.observation.recordHash = 0;
        originalFields.observation.recordChainHash = 0;
        require(
            assemblyViewReferenceRecord
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_PRESERVATION_REFERENCE_RECORD_V1"),
                        block.chainid,
                        address(viewReference),
                        address(assemblyCore),
                        address(assemblyMetadata),
                        p,
                        originalFields
                    )
                ),
            "literal original VIEW reference record"
        );
        require(
            r.observation.recordChainHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_PRESERVATION_REFERENCE_CHAIN_V1"),
                        block.chainid,
                        address(viewReference),
                        address(assemblyCore),
                        r.scopeSubject,
                        bytes32(0),
                        uint64(1),
                        assemblyViewReferenceRecord
                    )
                ),
            "literal original first VIEW reference chain"
        );
        p.observation.expectedSourcesHash = 0;
        originalFields.observation.payloadHash = 0;
        originalFields.observation.payloadBytes = 0;
        originalFields.observation.recordedAt = 0;
        require(
            keccak256(canonical)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_PRESERVATION_REFERENCE_PAYLOAD_V1"),
                        block.chainid,
                        address(viewReference),
                        p,
                        originalFields,
                        facts,
                        environment
                    )
                ),
            "literal complete VIEW reference payload"
        );
        require(
            viewReference.referenceCount(fullPolicyViewScope) == 1
                && viewReference.referenceAt(fullPolicyViewScope, 0) == assemblyViewReferenceRecord,
            "single exact original reference history"
        );
    }

    function _viewReferenceJsonHash(string memory json, string memory key)
        private
        pure
        returns (bytes32)
    {
        bytes memory raw = safeVm.parseJsonBytes(json, key);
        require(raw.length == 32, "exact 32-byte supplied observation hash");
        return bytes32(raw);
    }

    function _viewReferenceContains(bytes memory value, bytes memory needle)
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
