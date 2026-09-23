// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityViewPublicationFixture
} from "./StreamCurrentAuthorityViewPublicationFixture.sol";
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
import { Strings } from "../../smart-contracts/vendor/openzeppelin/Strings.sol";
import {
    StreamRecordFamilies
} from "../../smart-contracts/domains/records/StreamRecordFamilies.sol";

/// @notice Current-authority VIEW reference on the exact complete-bound original-A graph.
/// @dev Browser execution is an explicit supplied-observation boundary. This helper validates
/// exact input/output identities and real archive receipts; it does not execute a browser or
/// prove that supplied repeated PNG observations came from that browser. No old native captures
/// are selected implicitly. Fresh independently captured evidence must name these exact complete
/// non-sanction VIEW input bytes. Browser execution/provenance remains separately verified;
/// synthetic observations exercising this fixture cannot establish browser acceptance.
/// The discovery convenience entry below deliberately supplies labelled synthetic observations.
abstract contract StreamCurrentAuthorityViewReferenceFixture is
    StreamCurrentAuthorityViewPublicationFixture
{
    PolicyReference.Publication internal authorityViewReferencePublication;
    PolicyReference.Receipt internal authorityViewReferenceReceipt;
    bytes32 internal authorityViewReferenceRecord;
    bytes32[3] internal authorityViewReferenceFirstReceipts;
    bytes32[3] internal authorityViewReferenceSecondReceipts;
    bytes32 internal authorityViewObservationInputsHash;

    function _authorityPrepareViewReferenceDefinitions() internal {
        require(
            address(avReference) != address(0) && authorityViewAdoption.scope.collectionId == 1
                && avReference.core() == address(assemblyCore)
                && avReference.metadataHost() == address(assemblyMetadata)
                && avReference.metadataRouter() == address(assemblyRouter)
                && avReference.snapshots() == address(avSnapshot)
                && avReference.archiveCoverage() == address(assemblyExternal),
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
            authorityViewAdoption.scope.collectionId, StreamRecordFamilies.CURATOR, 3, address(this)
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
    function _authorityPublishViewReferenceInputs(
        string memory environmentJSON,
        string memory browserJSON,
        string memory capturesJSON
    ) internal {
        require(
            address(avReference) != address(0) && authorityViewReferenceRecord == 0
                && authorityViewPublication.snapshotRecord != 0
                && authorityViewPublication.rootRecord != 0,
            "actual VIEW reference follows snapshot and original Artist root"
        );
        ReferenceSnapshot.Receipt memory snapshot = avSnapshot.requireCurrent(
            authorityViewAdoption.scope,
            authorityViewPublication.snapshotRecord,
            avSnapshot.currentSnapshot(authorityViewAdoption.scope).revision
        );
        ReferenceContent.Plan memory content =
            avCheckpoint.requireCurrentCheckpoint(authorityViewPublication.checkpoint);
        require(
            content.tokenCount != 0 && content.nextIndex == content.tokenCount
                && keccak256(abi.encode(content.scope))
                    == keccak256(abi.encode(authorityViewAdoption.scope)),
            "complete same-scope output checkpoint"
        );
        authorityViewObservationInputsHash =
            keccak256(abi.encode(environmentJSON, browserJSON, capturesJSON));
        ReferenceObservation.Environment memory env =
            _authorityViewReferenceEnvironment(environmentJSON, browserJSON);
        PolicyReference.Publication memory p;
        p.scope = authorityViewAdoption.scope;
        p.observation.collectionId = p.scope.collectionId;
        p.observation.referenceId = keccak256(
            abi.encode(
                "VIEW preservation supplied first and last reference observations",
                authorityViewAdoption.adoptionRecord,
                authorityViewPublication.snapshotRecord,
                authorityViewObservationInputsHash
            )
        );
        p.observation.snapshotRecordHash = authorityViewPublication.snapshotRecord;
        p.observation.snapshotRevision = snapshot.revision;
        p.observation.environment = env;
        p.observation.reasonHash = authorityViewObservationInputsHash;
        p.observation.effectiveAt = uint64(block.timestamp);
        p.observation.manifestURI = "urn:fixture:view-preservation:supplied-reference-observations";
        uint256 count = content.tokenCount == 1 ? 1 : 2;
        p.observation.captures = new ReferenceObservation.Capture[](count);
        for (uint256 i; i < count; ++i) {
            p.observation.captures[i] = _authorityViewReferenceCapture(
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
        avReference.prepareFileInventory(env.packageFiles, true);
        avReference.prepareFileInventory(env.platformPrerequisites, false);
        bytes memory environment = StreamReferenceEnvironmentJson.manifest(env);
        require(
            keccak256(environment) == env.manifestHash && environment.length == env.manifestBytes,
            "exact complete supplied environment bytes"
        );
        _assemblyUpload(environment);
        bytes32 environmentId = avReference.prepareEnvironment(env);
        require(
            environmentId
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_REFERENCE_ENVIRONMENT_PREPARATION_V1"),
                        block.chainid,
                        address(avReference),
                        env
                    )
                ),
            "original full environment preparation identity"
        );
        require(
            keccak256(avReference.preparedFileInventory(environmentId)) == env.manifestHash,
            "complete original prepared environment retained"
        );
        (p.observation.expectedSourcesHash,) = avReference.previewReference(p, address(this));
        (, bytes memory canonical) = avReference.previewReference(p, address(this));
        _assemblyUpload(canonical);
        _assemblyUpload(abi.encode(p));
        authorityViewReferenceRecord = avReference.publishReference(p);
        (PolicyReference.Publication memory original, PolicyReference.Receipt memory receipt) =
            avReference.referenceRecord(authorityViewReferenceRecord);
        require(
            keccak256(abi.encode(original)) == keccak256(abi.encode(p))
                && receipt.scopeSubject == snapshot.scopeSubject
                && receipt.observation.recordHash == authorityViewReferenceRecord
                && receipt.observation.revision == 1
                && receipt.observation.recorder == address(this)
                && receipt.observation.sourcesHash == p.observation.expectedSourcesHash
                && receipt.observation.payloadHash == keccak256(canonical)
                && receipt.observation.payloadBytes == canonical.length
                && keccak256(avReference.referencePayload(authorityViewReferenceRecord))
                    == keccak256(canonical),
            "complete original VIEW preservation reference and payload retained"
        );
        authorityViewReferencePublication = p;
        authorityViewReferenceReceipt = receipt;
        _authorityAssertViewReferenceOriginal(canonical, environment);
        _authorityLockViewReference();
    }

    function _authorityViewReferenceEnvironment(
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
        ReferenceArchive.Coverage memory cover =
            _authorityViewReferenceObject(browserJSON, "", true);
        env.objectHash = cover.objectHash;
        env.coverageHash = cover.coverageHash;
        authorityViewReferenceFirstReceipts[0] = cover.firstReceiptHash;
        authorityViewReferenceSecondReceipts[0] = cover.secondReceiptHash;
        bytes memory manifest = StreamReferenceEnvironmentJson.manifest(env);
        require(manifest.length <= type(uint32).max, "bounded environment manifest");
        env.manifestHash = keccak256(manifest);
        env.manifestBytes = uint32(manifest.length);
    }

    function _authorityViewReferenceCapture(
        string memory capturesJSON,
        string memory prefix,
        uint256 membershipIndex,
        bytes32 environmentManifestHash,
        uint256 receiptIndex
    ) private returns (ReferenceObservation.Capture memory c) {
        ReferenceContent.Output memory output = avCheckpoint.outputAt(
            authorityViewPublication.checkpoint, membershipIndex
        );
        c.tokenId = output.tokenId;
        (bool exists, uint256 collectionId, uint256 serial, bool burned) =
            ReferenceCore(address(assemblyCore)).tokenCollectionIdentity(c.tokenId);
        require(
            exists && collectionId == authorityViewAdoption.scope.collectionId && serial != 0
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
                && keccak256(c.animationHTML) == keccak256(authorityViewHTML[c.tokenId])
                && keccak256(json) == keccak256(authorityViewJSON[c.tokenId])
                && keccak256(c.animationHTML) == output.htmlHash
                && keccak256(json) == output.jsonHash,
            "supplied capture input is exact retained complete non-sanction VIEW output"
        );
        require(
            !_authorityViewReferenceContains(json, bytes("attribution_unavailable"))
                && !_authorityViewReferenceContains(
                    c.animationHTML, bytes("attribution_unavailable")
                ),
            "actual available Artist attribution required"
        );
        c.metadataJSONHash = keccak256(json);
        c.htmlHash = keccak256(c.animationHTML);
        c.htmlBytes = uint32(c.animationHTML.length);
        c.sourceSha256 = sha256(c.animationHTML);
        ReferenceArchive.Coverage memory cover =
            _authorityViewReferenceObject(capturesJSON, prefix, false);
        c.objectHash = cover.objectHash;
        c.coverageHash = cover.coverageHash;
        c.repeatCaptureSha256 = [
            _authorityViewReferenceJsonHash(
                capturesJSON, string.concat(prefix, ".repeatCapture0Sha256")
            ),
            _authorityViewReferenceJsonHash(
                capturesJSON, string.concat(prefix, ".repeatCapture1Sha256")
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
        authorityViewReferenceFirstReceipts[receiptIndex] = cover.firstReceiptHash;
        authorityViewReferenceSecondReceipts[receiptIndex] = cover.secondReceiptHash;
    }

    function _authorityViewReferenceObject(string memory json, string memory prefix, bool runtime)
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
            _authorityViewReferenceJsonHash(json, string.concat(prefix, ".contentHash")),
            _authorityViewReferenceJsonHash(json, string.concat(prefix, ".sha256Digest")),
            _authorityViewReferenceJsonHash(json, string.concat(prefix, ".arweaveDataRoot")),
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

    function _authorityLockViewReference() private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            avReference.lockTransition(authorityViewAdoption.scope);
        bytes32 action = _assemblyGovernanceCall(
            2,
            address(avReference),
            abi.encodeCall(avReference.lockReference, (authorityViewAdoption.scope)),
            scope,
            oldHash,
            newHash
        );
        ReferenceObservation.Lock memory locked =
            avReference.referenceLock(authorityViewAdoption.scope);
        require(
            locked.actionId == action && locked.recordHash == authorityViewReferenceRecord
                && locked.revision == authorityViewReferenceReceipt.observation.revision,
            "real governed terminal reference lock"
        );
        require(
            keccak256(
                abi.encode(
                    avReference.requireCurrent(
                        authorityViewAdoption.scope, authorityViewReferenceRecord, locked.revision
                    )
                )
            ) == keccak256(abi.encode(authorityViewReferenceReceipt)),
            "same original reference remains current after actual lock"
        );
    }

    function _authorityAssertViewReferenceOriginal(bytes memory canonical, bytes memory environment)
        private
        view
    {
        PolicyReference.Publication memory p = authorityViewReferencePublication;
        PolicyReference.Receipt memory r = authorityViewReferenceReceipt;
        PolicyReference.SourceFacts memory facts =
            avReference.referenceSource(authorityViewReferenceRecord);
        require(
            facts.snapshot.recordHash == authorityViewPublication.snapshotRecord
                && facts.contentRootRecordHash == authorityViewPublication.rootRecord
                && facts.contentBinding.adoptionRecord == authorityViewAdoption.adoptionRecord
                && facts.contentBinding.checkpointRecord == authorityViewPublication.checkpoint
                && facts.contentBinding.outputManifestRecord
                    == authorityViewPublication.outputManifest
                && facts.snapshotSource.checkpoint.adoptionRecord
                    == authorityViewAdoption.adoptionRecord
                && facts.snapshotSource.checkpoint.nextIndex
                    == facts.snapshotSource.membership.tokenCount
                && keccak256(abi.encode(facts.snapshotSource.scope))
                    == keccak256(abi.encode(authorityViewAdoption.scope)),
            "reference retains actual snapshot root and complete original VIEW source"
        );
        require(
            facts.samples.length == p.observation.captures.length,
            "first-last observations remain distinct from complete inventory"
        );
        for (uint256 i; i < facts.samples.length; ++i) {
            uint256 index = i == 0 ? 0 : facts.snapshotSource.membership.tokenCount - 1;
            ReferenceContent.Output memory row =
                avCheckpoint.outputAt(authorityViewPublication.checkpoint, index);
            require(
                facts.samples[i].membershipIndex == index
                    && keccak256(abi.encode(facts.samples[i].output)) == keccak256(abi.encode(row))
                    && row.tokenId == p.observation.captures[i].tokenId,
                "all 31 original output words retained without terminal-finalized conversion"
            );
        }
        PolicyReference.Dependencies memory d = avReference.dependencies();
        require(
            r.observation.sourcesHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_PRESERVATION_REFERENCE_SOURCES_V1"),
                        d.chainId,
                        address(avReference),
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
            authorityViewReferenceRecord
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_PRESERVATION_REFERENCE_RECORD_V1"),
                        block.chainid,
                        address(avReference),
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
                        address(avReference),
                        address(assemblyCore),
                        r.scopeSubject,
                        bytes32(0),
                        uint64(1),
                        authorityViewReferenceRecord
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
                        address(avReference),
                        p,
                        originalFields,
                        facts,
                        environment
                    )
                ),
            "literal complete VIEW reference payload"
        );
        require(
            avReference.referenceCount(authorityViewAdoption.scope) == 1
                && avReference.referenceAt(authorityViewAdoption.scope, 0)
                    == authorityViewReferenceRecord,
            "single exact original reference history"
        );
    }

    function _authorityViewReferenceJsonHash(string memory json, string memory key)
        private
        pure
        returns (bytes32)
    {
        bytes memory raw = safeVm.parseJsonBytes(json, key);
        require(raw.length == 32, "exact 32-byte supplied observation hash");
        return bytes32(raw);
    }

    function _authorityViewReferenceContains(bytes memory value, bytes memory needle)
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

    struct AuthorityViewFixtureEndpoint {
        bytes32 contentHash;
        bytes32 sha256Digest;
        uint64 byteSize;
        bytes32 arweaveDataRoot;
        bytes firstDataPath;
        bytes lastDataPath;
        bytes firstChunkRaw;
        bytes lastChunkRaw;
    }

    /// @dev Real publication and archive proofs with synthetic observations only. No browser
    /// execution or image-to-HTML correspondence is asserted by these deterministic fixtures.
    function _authorityPublishViewReference() internal {
        _authorityPrepareViewReferenceDefinitions();
        (string memory environment, string memory runtime, string memory captures) =
            _authorityViewFixtureObservations();
        _authorityPublishViewReferenceInputs(environment, runtime, captures);
    }

    function _authorityViewFixtureObservations()
        private
        view
        returns (string memory environment, string memory runtime, string memory captures)
    {
        ReferenceObservation.Environment memory e;
        bytes memory engine = _authorityViewFixtureEngine();
        bytes memory tool = _authorityViewFixtureTool();
        e.engineName = "Synthetic composition fixture; not an executed browser";
        e.engineVersion = "1";
        e.engineExecutableSha256 = sha256(engine);
        e.toolchainName = "Synthetic observation fixture; no rendering performed";
        e.toolchainVersion = "1";
        e.toolchainSha256 = sha256(tool);
        e.engineExecutablePath = "engine/fixture.txt";
        e.toolchainPath = "tool/fixture.txt";
        e.packageFiles = new ReferenceObservation.PackageFile[](2);
        e.packageFiles[0] = ReferenceObservation.PackageFile(
            e.engineExecutablePath, uint64(engine.length), sha256(engine)
        );
        e.packageFiles[1] =
            ReferenceObservation.PackageFile(e.toolchainPath, uint64(tool.length), sha256(tool));
        e.platformPrerequisites = new ReferenceObservation.PackageFile[](1);
        bytes memory prerequisite =
            bytes("Synthetic declared platform boundary; no operating system observation.\n");
        e.platformPrerequisites[0] = ReferenceObservation.PackageFile(
            "C:/fixture/platform.txt", uint64(prerequisite.length), sha256(prerequisite)
        );
        // These fixed vocabulary values select the production schema. They describe the
        // synthetic declared profile, not this Windows host or a measured browser environment.
        e.operatingSystem = "Windows";
        e.operatingSystemVersion = "synthetic declared fixture; not observed";
        e.architecture = "AMD64";
        e.viewportWidth = 1;
        e.viewportHeight = 1;
        e.devicePixelRatio = 1;
        e.colorSpace = "srgb";
        e.softwareRasterization = true;
        e.captureProfile = keccak256("STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1");
        e.licenseNote = "Synthetic fixture bytes only; no executable browser or capture claim.";
        environment =
            string.concat('{"environmentABI":"', _authorityViewFixtureHex(abi.encode(e)), '"}');
        runtime =
            string.concat("{", _authorityViewFixtureEndpointJSON(_authorityViewFixtureZip()), "}");
        captures = string.concat('{"capture1":', _authorityViewFixtureCaptureJSON(0));
        if (
            avCheckpoint.requireCurrentCheckpoint(authorityViewPublication.checkpoint).tokenCount
                > 1
        ) {
            captures = string.concat(
                captures,
                ',"capture2":',
                _authorityViewFixtureCaptureJSON(
                    avCheckpoint.requireCurrentCheckpoint(authorityViewPublication.checkpoint)
                        .tokenCount - 1
                )
            );
        }
        captures = string.concat(captures, "}");
    }

    function _authorityViewFixtureCaptureJSON(uint256 index) private view returns (string memory) {
        ReferenceContent.Output memory output =
            avCheckpoint.outputAt(authorityViewPublication.checkpoint, index);
        uint256 token = output.tokenId;
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            ReferenceCore(address(assemblyCore)).tokenCollectionIdentity(token);
        require(
            exists && collection == authorityViewAdoption.scope.collectionId
                && serial == output.collectionSerial && burned == output.burned,
            "actual VIEW checkpoint identity"
        );
        bytes memory html = authorityViewHTML[token];
        bytes memory json = authorityViewJSON[token];
        require(
            html.length == output.htmlBytes && json.length == output.jsonBytes
                && keccak256(html) == output.htmlHash && keccak256(json) == output.jsonHash,
            "exact retained VIEW preservation outputs"
        );
        bytes memory png = _authorityViewFixturePNG();
        string memory capture = string.concat(
            '{"tokenId":',
            Strings.toString(token),
            ',"collectionSerial":',
            Strings.toString(serial),
            ',"html":"',
            _authorityViewFixtureHex(html),
            '","metadataJSON":"',
            _authorityViewFixtureHex(json),
            '"'
        );
        return string.concat(
            capture,
            ',"repeatCapture0Sha256":"',
            _authorityViewFixtureHex(abi.encodePacked(sha256(png))),
            '","repeatCapture1Sha256":"',
            _authorityViewFixtureHex(abi.encodePacked(sha256(png))),
            '",',
            _authorityViewFixtureEndpointJSON(png),
            "}"
        );
    }

    function _authorityViewFixtureEndpoint(bytes memory raw)
        private
        pure
        returns (AuthorityViewFixtureEndpoint memory e)
    {
        require(raw.length != 0 && raw.length < 262144);
        e.contentHash = keccak256(raw);
        e.sha256Digest = sha256(raw);
        e.byteSize = uint64(raw.length);
        e.arweaveDataRoot = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(e.sha256Digest)), sha256(abi.encode(uint256(raw.length)))
            )
        );
        e.firstDataPath = abi.encode(e.sha256Digest, uint256(raw.length));
        e.lastDataPath = e.firstDataPath;
        e.firstChunkRaw = raw;
        e.lastChunkRaw = raw;
    }

    function _authorityViewFixtureEndpointJSON(bytes memory raw)
        private
        pure
        returns (string memory out)
    {
        AuthorityViewFixtureEndpoint memory e = _authorityViewFixtureEndpoint(raw);
        out = string.concat(
            '"contentHash":"',
            _authorityViewFixtureHex(abi.encodePacked(e.contentHash)),
            '","sha256Digest":"',
            _authorityViewFixtureHex(abi.encodePacked(e.sha256Digest)),
            '","arweaveDataRoot":"',
            _authorityViewFixtureHex(abi.encodePacked(e.arweaveDataRoot)),
            '","byteSize":',
            Strings.toString(e.byteSize)
        );
        out = string.concat(
            out,
            ',"firstDataPath":"',
            _authorityViewFixtureHex(e.firstDataPath),
            '","lastDataPath":"',
            _authorityViewFixtureHex(e.lastDataPath),
            '","firstChunkRaw":"',
            _authorityViewFixtureHex(e.firstChunkRaw),
            '","lastChunkRaw":"',
            _authorityViewFixtureHex(e.lastChunkRaw),
            '"'
        );
    }

    function _authorityViewFixtureHex(bytes memory raw) private pure returns (string memory) {
        bytes memory alphabet = bytes("0123456789abcdef");
        bytes memory out = new bytes(2 + 2 * raw.length);
        out[0] = "0";
        out[1] = "x";
        for (uint256 i; i < raw.length; ++i) {
            out[2 + 2 * i] = alphabet[uint8(raw[i]) >> 4];
            out[3 + 2 * i] = alphabet[uint8(raw[i]) & 15];
        }
        return string(out);
    }

    function _authorityViewFixtureEngine() private pure returns (bytes memory) {
        return bytes("Synthetic engine bytes; not executable and never used to render.\n");
    }

    function _authorityViewFixtureTool() private pure returns (bytes memory) {
        return bytes("Synthetic capture tool bytes; no browser execution took place.\n");
    }

    function _authorityViewFixtureZip() private pure returns (bytes memory) {
        return hex"504b0304140000000000000021009f49f865410000004100000012000000656e67696e652f666978747572652e74787453796e74686574696320656e67696e652062797465733b206e6f742065786563757461626c6520616e64206e65766572207573656420746f2072656e6465722e0a504b030414000000000000002100c506cc4a3f0000003f00000010000000746f6f6c2f666978747572652e74787453796e746865746963206361707475726520746f6f6c2062797465733b206e6f2062726f7773657220657865637574696f6e20746f6f6b20706c6163652e0a504b01021403140000000000000021009f49f8654100000041000000120000000000000000000000800100000000656e67696e652f666978747572652e747874504b0102140314000000000000002100c506cc4a3f0000003f000000100000000000000000000000800171000000746f6f6c2f666978747572652e747874504b050600000000020002007e000000de0000000000";
    }

    function _authorityViewFixturePNG() private pure returns (bytes memory) {
        return hex"89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000b49444154789c6360000200000500017a5eab3f0000000049454e44ae426082";
    }
}
