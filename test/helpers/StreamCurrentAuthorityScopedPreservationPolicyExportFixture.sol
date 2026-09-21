// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityScopedPreservationPolicyPublicationFixture
} from "./StreamCurrentAuthorityScopedPreservationPolicyPublicationFixture.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1 as SPExportFactory
} from "../../smart-contracts/domains/finality/StreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as SPExportCheckpoint
} from "../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamStaticSelectionCheckpoint as SPExportSelection
} from "../../smart-contracts/interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    IStreamPreservationPolicyOutputManifestV1 as SPExportOutput
} from "../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1 as SPExportSnapshot
} from "../../smart-contracts/interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as SPExportSnapshotTypes
} from "../../smart-contracts/interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    IStreamCoreIdentity as SPExportCore
} from "../../smart-contracts/interfaces/stream/core/IStreamCoreIdentity.sol";
import {
    StreamArtistCurrentAuthorityTypes as SPExportAuthority
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";
import {
    StreamRenderContextV1 as SPExportEncoding
} from "../../smart-contracts/domains/metadata/StreamRenderContextV1.sol";
import {
    IStreamCollectionMetadataV1 as SPExportMetadata
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamPreservationRecords as SPExportRecords
} from "../../smart-contracts/interfaces/stream/preservation/IStreamPreservationRecords.sol";
import {
    StreamFinalityScope as SPExportScope,
    StreamFinalityScopeType as SPExportScopeType
} from "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamMetadataSubjects as SPExportSubjects
} from "../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import { Strings as SPExportStrings } from "../../smart-contracts/vendor/openzeppelin/Strings.sol";

import {
    StreamPreservationTokenProducerProfilesV1 as SPExportProducerProfiles
} from "../../smart-contracts/interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    IStreamPreservationRendererV1 as SPExportProducer
} from "../../smart-contracts/interfaces/stream/metadata/IStreamPreservationRendererV1.sol";
import {
    IStreamPreservationRegistryV1 as SPExportRegistry
} from "../../smart-contracts/interfaces/stream/metadata/IStreamPreservationRegistryV1.sol";
import {
    StreamScopedPreservationPolicyContentRootSchemasV2 as SPExportRootDefinitions
} from "../../smart-contracts/domains/finality/StreamScopedPreservationPolicyContentRootSchemasV2.sol";
import {
    StreamScopedPreservationPolicySnapshotDefinitionsV2 as SPExportSnapshotDefinitions
} from "../../smart-contracts/domains/records/StreamScopedPreservationPolicySnapshotDefinitionsV2.sol";

/// @dev Filesystem-only extension of the fixed Foundry VM used by the inherited fixture.
interface CurrentAuthorityScopedPreservationExportVm {
    function exists(string calldata path) external view returns (bool);
}

/// @notice Exports actual admitted scoped preservation bytes for a separate fresh browser run.
/// @dev Each token uses its checkpoint's distinct ORIGINAL or CURRENT_ARTIST producer and exact
/// original governed admission. The enclosing checkpoint/output family is V2; it is not a token
/// producer marker. STATIC analysis, source assessment and golden documents in the inherited
/// prefix are explicit synthetic fixture evidence, not renderer conformance. No browser/native
/// capture, full ceremony execution or Finality success is claimed by authoring this helper.
/// The exporter reads preservation endpoints and complete current onchain source joins. The supplied run directory must
/// not already exist. Foundry fs_permissions and the caller's explicit output directory govern
/// filesystem access. These diagnostics create no archive receipt or reference authority.
/// consentNonce is retained fixture provenance, not independently authenticated by this exporter.
/// The selected root, complete consent terms and consumed consent record are checked onchain;
/// an inventory's separate original-origin envelope must authenticate the exact op17 nonce.
abstract contract StreamCurrentAuthorityScopedPreservationPolicyExportFixture is
    StreamCurrentAuthorityScopedPreservationPolicyPublicationFixture
{
    bytes32 private constant SP_PRESERVATION_EXPORT_DOMAIN =
        keccak256("6529STREAM_CURRENT_AUTHORITY_SCOPED_PRESERVATION_SOURCE_EXPORT_V2");

    struct AuthorityScopedPreservationExport {
        string directory;
        string sourceJSONPath;
        string sourceABIPath;
        string captureInputsPath;
        bytes32 sourceHash;
        uint256[] tokenIds;
        string[] htmlPaths;
        string[] metadataPaths;
        bytes32[] htmlHashes;
        bytes32[] metadataHashes;
    }

    /// @dev Exact ABI vocabulary for source-identity.abi.hex: abi.encode(domain,context,publication,tokens).
    struct ScopedPreservationExportContext {
        uint16 schemaVersion;
        bytes32 preservationFamily;
        uint256 chainId;
        uint256 blockNumber;
        uint256 evmTimestamp;
        address exporter;
        // Core, Metadata, Router, schemas, Store, membership, selection, graph factory,
        // current Artist, current Coordinator, original Finality, original provider, resolver.
        address[13] targets;
        bytes32[13] codeHashes;
        SPExportAuthority.Selection authority;
    }

    struct ScopedPreservationExportToken {
        uint256 membershipIndex;
        uint256 tokenId;
        uint256 collectionId;
        uint256 collectionSerial;
        bool mappingExists;
        bool burned;
        uint8 lifecycle;
        address coordinatorAtMint;
        bytes32 coordinatorCodeHash;
        SPExportSelection.TokenSelection selection;
        SPExportCheckpoint.Output output;
        bytes32 htmlKeccak;
        bytes32 htmlSha256;
        bytes32 metadataKeccak;
        bytes32 metadataSha256;
        uint256 htmlBytes;
        uint256 metadataBytes;
        bytes html;
        bytes metadataJSON;
    }

    function _authorityExportScopedPreservationPolicySources(
        AuthorityScopedPublication memory source,
        string memory outputDirectory,
        string memory runLabel
    ) internal returns (AuthorityScopedPreservationExport memory result) {
        _scopedExportLabel(runLabel);
        require(bytes(outputDirectory).length != 0, "task supplies export directory");
        result.directory = string.concat(outputDirectory, "/", runLabel);
        require(
            !CurrentAuthorityScopedPreservationExportVm(address(assemblyVm))
                .exists(result.directory),
            "fresh export directory required"
        );
        _scopedExportRequireSource(source);
        ScopedPreservationExportContext memory context = _scopedExportContext();
        ScopedPreservationExportToken[] memory tokens = _scopedExportTokens(source);
        bytes memory canonical = abi.encode(SP_PRESERVATION_EXPORT_DOMAIN, context, source, tokens);
        result.sourceHash = keccak256(canonical);
        result.sourceJSONPath = string.concat(result.directory, "/source-identity.json");
        result.sourceABIPath = string.concat(result.directory, "/source-identity.abi.hex");
        result.captureInputsPath = string.concat(result.directory, "/capture-inputs.json");
        result.tokenIds = new uint256[](tokens.length);
        result.htmlPaths = new string[](tokens.length);
        result.metadataPaths = new string[](tokens.length);
        result.htmlHashes = new bytes32[](tokens.length);
        result.metadataHashes = new bytes32[](tokens.length);
        assemblyVm.createDir(result.directory, true);
        for (uint256 i; i < tokens.length; ++i) {
            ScopedPreservationExportToken memory token = tokens[i];
            string memory prefix =
                string.concat(result.directory, "/token-", SPExportStrings.toString(token.tokenId));
            result.tokenIds[i] = token.tokenId;
            result.htmlPaths[i] = string.concat(prefix, ".html");
            result.metadataPaths[i] = string.concat(prefix, ".json");
            result.htmlHashes[i] = token.htmlKeccak;
            result.metadataHashes[i] = token.metadataKeccak;
            _scopedExportWrite(result.htmlPaths[i], string(token.html));
            _scopedExportWrite(result.metadataPaths[i], string(token.metadataJSON));
        }
        _scopedExportWrite(result.sourceABIPath, SPExportEncoding.hexBytes(canonical));
        _scopedExportWrite(result.captureInputsPath, _scopedExportCaptureInputs(tokens));
        _scopedExportWrite(
            string.concat(result.directory, "/capture-instructions.txt"),
            "No browser capture has run. These are preservationTokenHTML/preservationTokenJSON bytes from each actual admitted ORIGINAL or CURRENT_ARTIST producer. The packet's V2 family is not a token producer marker or the old live STATIC export. The inherited STATIC analysis/read assessment/golden documents are synthetic fixture evidence, not independent source analysis or conformance. Use tools/preservation/reference_capture.py with --html token-N.html, --engine the actual pinned Chromium executable, --output a new capture directory, and explicit artwork --width/--height. The runner consumes exact UTF-8 HTML, not source-identity.json. Capture first/last authoritative membership (one token when equal), twice in the runner. capture-inputs.json contains only source fields; add actual repeated PNG hashes and archive endpoints/proofs after the separate run. Never copy old native captures. source-identity.abi.hex is lowercase hex without a trailing newline: abi.encode(SP_PRESERVATION_EXPORT_DOMAIN,ScopedPreservationExportContext,AuthorityScopedPublication,ScopedPreservationExportToken[]), with types declared in this fixture. consentNonce is retained fixture provenance, not independent op17 archival authentication. The selected root, complete consent terms and consumed consent record are checked onchain; the inventory's separate original-origin envelope must authenticate the exact nonce. This export is not browser conformance, archive coverage of PNG/runtime, or Finality evidence.\n"
        );
        // Write the completion identity last; all earlier files were read back byte-for-byte.
        _scopedExportWrite(
            result.sourceJSONPath,
            _scopedExportIdentity(
                source, context, tokens, runLabel, result.sourceHash, sha256(canonical)
            )
        );
    }

    function _scopedExportRequireSource(AuthorityScopedPublication memory p) private view {
        require(p.checkpoint.tokenCount != 0 && p.graph.preparedChildren == 7);
        require(
            SPExportCheckpoint(p.graph.children[1]).preservationPolicyProfile()
                    == SPExportProducerProfiles.SCOPED_CHECKPOINT_PROFILE
                && SPExportCheckpoint(p.graph.children[1]).preservationOutputProfile()
                    == SPExportProducerProfiles.FAMILY_PROFILE
                && SPExportOutput(p.graph.children[2]).outputProfile()
                    == SPExportProducerProfiles.OUTPUT_MANIFEST_PROFILE
                && SPExportSnapshot(p.graph.children[3]).scopedPreservationPolicySnapshotProfile()
                == keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V2"),
            "exact fixed preservation V2 publication products"
        );
        require(
            keccak256(abi.encode(p.graph))
                == keccak256(
                    abi.encode(SPExportFactory(scopedGraphFactory).requireCurrentGraph(p.scope))
                ),
            "actual current seven-child graph"
        );
        require(
            keccak256(abi.encode(p.membership))
                == keccak256(abi.encode(assemblyMembership.requireScopeMembership(p.scope))),
            "actual complete scope membership"
        );
        _scopedExportMembership(p);
        require(
            keccak256(abi.encode(p.selection))
                == keccak256(
                    abi.encode(
                        SPExportSelection(sourceStaticSelection)
                            .requireCurrentCheckpoint(p.selectionId)
                    )
                ),
            "current selection unchanged"
        );
        require(
            keccak256(abi.encode(p.checkpoint))
                == keccak256(
                    abi.encode(
                        SPExportCheckpoint(p.graph.children[1])
                            .requireCurrentCheckpoint(p.checkpointId)
                    )
                ),
            "all checkpoint rows current"
        );
        require(
            keccak256(abi.encode(p.output))
                == keccak256(
                    abi.encode(
                        SPExportOutput(p.graph.children[2])
                            .requireCurrentManifest(p.outputRecord, assemblyArtistId)
                    )
                ),
            "complete output manifest current"
        );
        require(p.output.manifestHash == keccak256(p.outputPayload));
        require(
            p.outputArtifact == p.output.artifactHash && p.outputCoverage == p.output.coverageHash,
            "exported output archive identities match actual manifest"
        );
        SPExportOutput.Plan memory outputPlan =
            SPExportOutput(p.graph.children[2]).manifestPlan(p.outputPlan);
        require(
            outputPlan.recordHash == p.outputRecord && outputPlan.nextIndex == p.output.tokenCount
                && keccak256(abi.encode(outputPlan.manifest)) == keccak256(abi.encode(p.output)),
            "original completed output plan matches actual manifest"
        );
        SPExportSnapshot snapshots = SPExportSnapshot(p.graph.children[3]);
        require(
            keccak256(abi.encode(p.snapshot))
                == keccak256(
                    abi.encode(
                        snapshots.requireCurrent(
                            p.scope, p.snapshot.recordHash, p.snapshot.revision
                        )
                    )
                ),
            "actual snapshot current"
        );
        (
            SPExportSnapshotTypes.Publication memory publication,
            SPExportSnapshotTypes.Receipt memory receipt
        ) = snapshots.snapshotRecord(p.snapshot.recordHash);
        require(
            keccak256(abi.encode(publication, receipt))
                == keccak256(abi.encode(p.snapshotPublication, p.snapshot))
        );
        require(
            keccak256(snapshots.snapshotPayload(p.snapshot.recordHash))
                == keccak256(p.snapshotPayload)
        );
        require(
            p.snapshot.manifestHash == keccak256(p.snapshotPayload)
                && p.snapshot.schemaHash == SPExportSnapshotDefinitions.SCHEMA_HASH
                && p.snapshot.profileHash == SPExportSnapshotDefinitions.PROFILE_HASH
                && p.snapshot.canonicalizationHash == SPExportSnapshotDefinitions.CANON_HASH
                && abi.decode(p.snapshotPayload, (bytes32))
                    == keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_PAYLOAD_V2"),
            "exact preservation snapshot V2 bytes and definitions"
        );
        require(
            assemblyRouter.scopedContentRootHead(p.scope) == p.rootHash,
            "original scoped root remains selected"
        );
        require(
            keccak256(abi.encode(assemblyRouter.scopedContentRootRecord(p.rootHash)))
                == keccak256(abi.encode(p.root))
        );
        require(
            keccak256(
                abi.encode(assemblyRouter.scopedPreservationPolicyContentRootBinding(p.rootHash))
            ) == keccak256(abi.encode(p.binding))
        );
        require(
            p.rootHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2"),
                        block.chainid,
                        address(assemblyRouter),
                        address(assemblyCore),
                        p.root,
                        p.binding,
                        p.aggregate
                    )
                ),
            "historical resulting aggregate authenticates original root"
        );
        require(
            p.legacyFamily
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_EMPTY_CONTENT_ROOT_STATE_V1"),
                            block.chainid,
                            address(assemblyRouter),
                            address(assemblyCore),
                            p.scope.collectionId
                        )
                    ) && assemblyRouter.collectionContentRootHead(p.scope.collectionId) == 0
        );
        require(
            p.signedFamily
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_CONTENT_ROOT_FAMILY_WITH_SCOPES_V1"),
                            block.chainid,
                            address(assemblyRouter),
                            address(assemblyCore),
                            p.scope.collectionId,
                            p.legacyFamily,
                            p.aggregate
                        )
                    ) && p.root.artistConsent == p.consentRecord && p.root.publisher == p.actor
        );
        require(
            p.root.publishedAt == p.observedAt && p.consent.newStateHash == p.signedFamily
                && p.consent.collectionId == p.scope.collectionId
                && p.consent.metadataContract == address(assemblyRouter)
                && p.consent.familyId == keccak256("CONTENT_ROOT"),
            "same complete original CONTENT_ROOT consent terms"
        );
        require(
            assemblyRouter.consumedArtistContentConsent(p.consentRecord),
            "original op17 consent consumed by Router"
        );
        _scopedExportCorrespondence(p);
        // consentNonce is retained fixture authorization input. The exported authenticated
        // root binds consentRecord; this diagnostic does not independently re-read its nonce.
    }

    function _scopedExportCorrespondence(AuthorityScopedPublication memory p) private pure {
        require(
            p.checkpoint.preservationProfile == SPExportProducerProfiles.FAMILY_PROFILE
                && p.output.preservationProfile == SPExportProducerProfiles.FAMILY_PROFILE
                && p.output.metadataRouter == p.binding.metadataRouter
                && p.binding.preservationOutputProfile == SPExportProducerProfiles.FAMILY_PROFILE
                && p.binding.profileId == SPExportRootDefinitions.PROFILE,
            "V2 family is distinct from each actual row producer marker"
        );
        bytes32 scopeHash = keccak256(abi.encode(p.scope));
        require(
            keccak256(abi.encode(p.graph.scope)) == scopeHash
                && keccak256(abi.encode(p.selection.scope)) == scopeHash
                && keccak256(abi.encode(p.checkpoint.scope)) == scopeHash
                && keccak256(abi.encode(p.output.scope)) == scopeHash
                && keccak256(abi.encode(p.snapshotPublication.scope)) == scopeHash
                && keccak256(abi.encode(p.root.publication.scope)) == scopeHash,
            "one exact scope throughout exported publication"
        );
        require(
            p.selection.membershipHash == p.membership.membershipHash
                && p.selection.tokenCount == p.membership.tokenCount
                && p.checkpoint.selectionId == p.selectionId
                && p.output.checkpointHash == p.checkpointId
                && p.output.checkpointStateHash == keccak256(abi.encode(p.checkpoint))
                && p.output.entropySourceSet == p.graph.sourceSet
                && p.output.tokenCount == p.checkpoint.tokenCount
                && p.output.byteLength == p.outputPayload.length,
            "exported selection checkpoint and manifest form the same chain"
        );
        require(
            p.snapshotPublication.outputManifestRecord == p.outputRecord
                && p.snapshotPublication.coordinatorInventoryPlan == p.graph.inventoryPlan
                && p.snapshotPublication.expectedSourceHash == p.snapshot.sourceHash
                && p.snapshot.scopeSubject == p.membership.scopeSubject
                && p.snapshot.manifestBytes == p.snapshotPayload.length
                && p.root.publication.snapshotRecordHash == p.snapshot.recordHash
                && p.root.publication.snapshotRevision == p.snapshot.revision
                && p.root.snapshotHost == p.graph.children[3]
                && p.root.snapshotCodeHash == p.graph.codeHashes[3]
                && p.root.snapshotManifestHash == p.snapshot.manifestHash
                && p.root.snapshotSourceHash == p.snapshot.sourceHash
                && p.binding.checkpoint == p.graph.children[1]
                && p.binding.checkpointHash == p.checkpointId
                && p.binding.outputManifest == p.graph.children[2],
            "exported snapshot and original root select the same output"
        );
    }

    function _scopedExportMembership(AuthorityScopedPublication memory p) private view {
        if (p.scope.scopeType == SPExportScopeType.TOKEN) {
            require(
                p.membershipRecord == 0 && p.membershipPayload.length == 0,
                "TOKEN has no published membership record or payload"
            );
            return;
        }
        require(
            p.scope.scopeType == SPExportScopeType.RELEASE
                || p.scope.scopeType == SPExportScopeType.SEASON,
            "closed published membership profiles"
        );
        require(
            p.membershipRecord != 0 && p.membershipRecord == p.membership.sourceRecordHash
                && keccak256(p.membershipPayload) == p.membership.scopeManifestHash,
            "exported membership preimage matches actual sealed facts"
        );
        (
            SPExportRecords.CollectionRecord memory record,
            SPExportMetadata.RecordReceipt memory receipt
        ) = assemblyMetadata.collectionRecord(p.membershipRecord);
        require(
            receipt.collectionId == p.scope.collectionId && receipt.recorder != address(0)
                && record.recordType == keccak256("SCOPE_MEMBERSHIP")
                && record.schemaId == keccak256("STREAM_SCOPE_MEMBERSHIP_V1")
                && record.subjectId
                    == SPExportSubjects.scopeSubject(
                        block.chainid,
                        address(assemblyCore),
                        SPExportScope(SPExportScopeType.COLLECTION, p.scope.collectionId, 0, 0)
                    ) && record.contentHash.algorithm == 1
                && record.contentHash.canonicalizationId
                    == keccak256("STREAM_SCOPE_MEMBERSHIP_ABI_V1")
                && keccak256(record.contentHash.digest)
                    == keccak256(abi.encode(keccak256(p.membershipPayload)))
                && assemblyMetadata.deriveCollectionRecordHashFor(
                    receipt.recorder, receipt.collectionId, record
                ) == p.membershipRecord,
            "actual original typed Metadata membership publication"
        );
        (, bytes memory originalPayload) = assemblyMetadata.recordPayload(p.membershipRecord);
        require(
            originalPayload.length == p.membershipPayload.length
                && keccak256(originalPayload) == keccak256(p.membershipPayload),
            "exact original Metadata membership bytes"
        );
    }

    function _scopedExportContext()
        private
        view
        returns (ScopedPreservationExportContext memory c)
    {
        c.schemaVersion = 2;
        c.preservationFamily = SPExportProducerProfiles.FAMILY_PROFILE;
        c.chainId = block.chainid;
        c.blockNumber = block.number;
        c.evmTimestamp = block.timestamp;
        c.exporter = address(this);
        c.authority = assemblyAuthorityResolver.currentSelection();
        c.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(assemblyRouter),
            address(assemblySchemas),
            address(assemblyStore),
            address(assemblyMembership),
            sourceStaticSelection,
            scopedGraphFactory,
            c.authority.origin.environment.registry,
            c.authority.origin.environment.coordinator,
            address(assemblyFinality),
            address(assemblyProvider),
            address(assemblyAuthorityResolver)
        ];
        for (uint256 i; i < c.targets.length; ++i) {
            require(c.targets[i].code.length != 0, "live exact export source");
            c.codeHashes[i] = c.targets[i].codehash;
        }
    }

    function _scopedExportTokens(AuthorityScopedPublication memory p)
        private
        view
        returns (ScopedPreservationExportToken[] memory tokens)
    {
        uint256 count = p.membership.tokenCount;
        require(
            count == p.checkpoint.tokenCount && count == p.payloads.length
                && count == p.metadataJSON.length && count == p.outputRows.length
        );
        tokens = new ScopedPreservationExportToken[](count);
        for (uint256 i; i < count; ++i) {
            ScopedPreservationExportToken memory t;
            t.membershipIndex = i;
            t.tokenId = assemblyMembership.scopeTokenAt(p.scope, i);
            (t.mappingExists, t.collectionId, t.collectionSerial, t.burned) =
                SPExportCore(address(assemblyCore)).tokenCollectionIdentity(t.tokenId);
            t.lifecycle = SPExportCore(address(assemblyCore)).tokenLifecycle(t.tokenId);
            t.coordinatorAtMint = SPExportCore(address(assemblyCore)).coordinatorAtMint(t.tokenId);
            t.coordinatorCodeHash = t.coordinatorAtMint.codehash;
            require(
                t.mappingExists && !t.burned && t.lifecycle == 2
                    && t.collectionId == p.scope.collectionId
            );
            t.selection = SPExportSelection(sourceStaticSelection).selectionAt(p.selectionId, i);
            t.output = SPExportCheckpoint(p.graph.children[1]).outputAt(p.checkpointId, i);
            require(t.selection.tokenId == t.tokenId && t.output.leaf.tokenId == t.tokenId);
            require(
                t.output.entropy.coordinator == t.coordinatorAtMint
                    && t.output.entropy.coordinatorCodeHash == t.coordinatorCodeHash
            );
            require(keccak256(abi.encode(t.output)) == keccak256(abi.encode(p.outputRows[i])));
            require(
                t.output.selectionRowHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_STATIC_SELECTION_ROW_V1"),
                            block.chainid,
                            address(assemblyCore),
                            address(assemblyRouter),
                            t.selection
                        )
                    ),
                "actual output row binds exported token selection"
            );
            _scopedExportPreservation(t);
            t.html = bytes(
                SPExportProducer(t.output.preservation.producer).preservationTokenHTML(t.tokenId)
            );
            t.metadataJSON = bytes(
                SPExportProducer(t.output.preservation.producer).preservationTokenJSON(t.tokenId)
            );
            require(
                t.html.length != 0 && t.html.length <= 40960 && t.metadataJSON.length != 0
                    && t.metadataJSON.length <= 65536,
                "exact preservation reference byte bounds"
            );
            t.htmlBytes = t.html.length;
            t.metadataBytes = t.metadataJSON.length;
            t.htmlKeccak = keccak256(t.html);
            t.metadataKeccak = keccak256(t.metadataJSON);
            t.htmlSha256 = sha256(t.html);
            t.metadataSha256 = sha256(t.metadataJSON);
            require(
                t.htmlKeccak == t.output.htmlHash && t.htmlKeccak == t.output.leaf.animationHash,
                "fresh preservation HTML equals original checkpoint leaf"
            );
            require(
                t.metadataKeccak == t.output.leaf.metadataHash,
                "fresh preservation JSON equals original checkpoint leaf"
            );
            require(
                p.payloads[i].tokenId == t.tokenId
                    && p.payloads[i].producer == t.output.preservation.producer
                    && keccak256(p.payloads[i].animation) == t.htmlKeccak
                    && keccak256(p.metadataJSON[i]) == t.metadataKeccak
            );
            require(
                t.output.leaf.imageHash
                    == (p.payloads[i].image.length == 0
                            ? bytes32(0)
                            : keccak256(p.payloads[i].image))
            );
            _scopedExportCaptureShape(t.html);
            tokens[i] = t;
        }
    }

    /// @dev Re-read the actual row's selected producer and immutable governed admission.
    /// The checkpoint currentness check above independently revalidates its complete output.
    function _scopedExportPreservation(ScopedPreservationExportToken memory t) private view {
        address producer = t.output.preservation.producer;
        address registry = t.selection.selection.registry;
        require(
            abi.encode(t.output).length == 1152 && abi.encode(t.output.preservation).length == 288
                && abi.encode(t.output.preservationAdmission).length == 224
                && SPExportProducerProfiles.isSupported(t.output.preservation.profile)
                && producer.code.length != 0
                && producer.codehash == t.output.preservation.producerCodeHash
                && SPExportProducer(producer).preservationProfile() == t.output.preservation.profile
                && t.output.preservation.core == address(assemblyCore)
                && t.output.preservation.metadataRouter == address(assemblyRouter)
                && t.output.preservation.liveRenderer == t.selection.selection.renderer
                && t.output.preservation.liveRendererCodeHash
                    == t.selection.selection.rendererCodeHash
                && t.output.preservation.liveRenderer.codehash
                    == t.output.preservation.liveRendererCodeHash
                && t.output.preservation.attribution.code.length != 0
                && t.output.preservation.attribution.codehash
                    == t.output.preservation.attributionCodeHash,
            "actual admitted token producer identity and original runtime pins"
        );
        (bool ok, bytes memory raw) =
            producer.staticcall(abi.encodeCall(SPExportProducer.preservationBinding, ()));
        require(
            ok && raw.length == 192
                && keccak256(raw)
                    == keccak256(
                        abi.encode(
                            t.output.preservation.core,
                            t.output.preservation.metadataRouter,
                            t.output.preservation.liveRenderer,
                            t.output.preservation.liveRendererCodeHash,
                            t.output.preservation.attribution,
                            t.output.preservation.attributionCodeHash
                        )
                    ),
            "complete original producer binding remains exact"
        );
        require(
            registry.code.length != 0 && registry.codehash == t.selection.selection.registryCodeHash
                && t.output.preservationAdmission.registry == registry
                && t.output.preservationAdmission.registryCodeHash == registry.codehash
                && t.output.preservationAdmission.versionKey == t.selection.selection.versionKey,
            "same original selected admission registry and version"
        );
        (ok, raw) = registry.staticcall(
            abi.encodeCall(
                SPExportRegistry.requirePreservation,
                (t.selection.selection.versionKey, producer, t.output.preservation.profile)
            )
        );
        require(
            ok && raw.length == 512
                && keccak256(raw)
                    == keccak256(abi.encode(t.output.preservation, t.output.preservationAdmission)),
            "actual Registry returns the complete unchanged binding and admission"
        );
    }

    function _scopedExportIdentity(
        AuthorityScopedPublication memory p,
        ScopedPreservationExportContext memory c,
        ScopedPreservationExportToken[] memory tokens,
        string memory label,
        bytes32 hash,
        bytes32 sha
    ) private pure returns (string memory json) {
        json = string.concat(
            '{"schema":"6529STREAM_CURRENT_AUTHORITY_SCOPED_PRESERVATION_SOURCE_EXPORT_V2","schemaVersion":2,"preservationFamily":',
            _scopedExportHash(c.preservationFamily),
            ',"syntheticSTATICAdmissionEvidence":true,"captureExecuted":false,"runLabel":"',
            label,
            '","sourceKeccak256":',
            _scopedExportHash(hash),
            ',"sourceSha256":',
            _scopedExportHash(sha),
            ',"sourceABIFile":"source-identity.abi.hex","sourceABIEncoding":"abi.encode(domain,ScopedPreservationExportContext,AuthorityScopedPublication,ScopedPreservationExportToken[])","contextABI":',
            _scopedExportABI(abi.encode(c)),
            ',"scope":{"scopeType":',
            SPExportStrings.toString(uint8(p.scope.scopeType)),
            ',"collectionId":',
            SPExportStrings.toString(p.scope.collectionId),
            ',"tokenId":',
            SPExportStrings.toString(p.scope.tokenId),
            ',"scopeId":',
            _scopedExportHash(p.scope.scopeId),
            ',"abi":',
            _scopedExportABI(abi.encode(p.scope)),
            '},"graphABI":',
            _scopedExportABI(abi.encode(p.graph)),
            ',"membershipABI":',
            _scopedExportABI(abi.encode(p.membership)),
            ',"membershipRecord":',
            _scopedExportHash(p.membershipRecord),
            ',"membershipPayload":',
            _scopedExportABI(p.membershipPayload)
        );
        json = string.concat(
            json,
            ',"selectionId":',
            _scopedExportHash(p.selectionId),
            ',"selectionABI":',
            _scopedExportABI(abi.encode(p.selection)),
            ',"checkpointId":',
            _scopedExportHash(p.checkpointId),
            ',"checkpointABI":',
            _scopedExportABI(abi.encode(p.checkpoint)),
            ',"outputRecord":',
            _scopedExportHash(p.outputRecord),
            ',"outputABI":',
            _scopedExportABI(abi.encode(p.output)),
            ',"outputPayload":',
            _scopedExportABI(p.outputPayload),
            ',"snapshotPublicationABI":',
            _scopedExportABI(abi.encode(p.snapshotPublication)),
            ',"snapshotReceiptABI":',
            _scopedExportABI(abi.encode(p.snapshot)),
            ',"snapshotPayload":',
            _scopedExportABI(p.snapshotPayload)
        );
        json = string.concat(
            json,
            ',"rootHash":',
            _scopedExportHash(p.rootHash),
            ',"rootRecordABI":',
            _scopedExportABI(abi.encode(p.root)),
            ',"bindingABI":',
            _scopedExportABI(abi.encode(p.binding)),
            ',"historicalResultingAggregateABI":',
            _scopedExportABI(abi.encode(p.aggregate)),
            ',"legacyFamily":',
            _scopedExportHash(p.legacyFamily),
            ',"signedFamily":',
            _scopedExportHash(p.signedFamily),
            ',"consentABI":',
            _scopedExportABI(abi.encode(p.consent)),
            ',"consentRecord":',
            _scopedExportHash(p.consentRecord),
            ',"consentNonceProvenance":"retained fixture authorization input; not independent op17 archival authentication; exact nonce requires the original-origin envelope","consentNonce":',
            SPExportStrings.toString(p.consentNonce),
            ',"actor":',
            _scopedExportAccount(p.actor),
            ',"observedAt":',
            SPExportStrings.toString(p.observedAt),
            ',"tokens":['
        );
        for (uint256 i; i < tokens.length; ++i) {
            json = string.concat(json, i == 0 ? "" : ",", _scopedExportTokenJSON(tokens[i]));
        }
        return string.concat(json, "]}");
    }

    function _scopedExportTokenJSON(ScopedPreservationExportToken memory t)
        private
        pure
        returns (string memory)
    {
        string memory stem = string.concat("token-", SPExportStrings.toString(t.tokenId));
        return string.concat(
            '{"membershipIndex":',
            SPExportStrings.toString(t.membershipIndex),
            ',"tokenId":',
            SPExportStrings.toString(t.tokenId),
            ',"collectionId":',
            SPExportStrings.toString(t.collectionId),
            ',"collectionSerial":',
            SPExportStrings.toString(t.collectionSerial),
            ',"htmlFile":"',
            stem,
            '.html","metadataJSONFile":"',
            stem,
            '.json","htmlKeccak256":',
            _scopedExportHash(t.htmlKeccak),
            ',"htmlSha256":',
            _scopedExportHash(t.htmlSha256),
            ',"metadataKeccak256":',
            _scopedExportHash(t.metadataKeccak),
            ',"metadataSha256":',
            _scopedExportHash(t.metadataSha256),
            ',"htmlBytes":',
            SPExportStrings.toString(t.htmlBytes),
            ',"metadataBytes":',
            SPExportStrings.toString(t.metadataBytes),
            ',"producer":',
            _scopedExportAccount(t.output.preservation.producer),
            ',"producerCodeHash":',
            _scopedExportHash(t.output.preservation.producerCodeHash),
            ',"producerProfile":',
            _scopedExportHash(t.output.preservation.profile),
            ',"preservationBindingABI":',
            _scopedExportABI(abi.encode(t.output.preservation)),
            ',"preservationAdmissionABI":',
            _scopedExportABI(abi.encode(t.output.preservationAdmission)),
            ',"identityABI":',
            _scopedExportABI(abi.encode(t)),
            "}"
        );
    }

    function _scopedExportCaptureInputs(ScopedPreservationExportToken[] memory tokens)
        private
        pure
        returns (string memory json)
    {
        json = string.concat(
            '{"schema":"6529STREAM_CURRENT_AUTHORITY_SCOPED_PRESERVATION_SOURCE_EXPORT_V2","schemaVersion":2,"preservationFamily":',
            _scopedExportHash(SPExportProducerProfiles.FAMILY_PROFILE),
            ',"syntheticSTATICAdmissionEvidence":true,"captureExecuted":false,"sourceFieldsOnly":true,"capture1":',
            _scopedExportCaptureToken(tokens[0])
        );
        if (tokens.length > 1) {
            json = string.concat(
                json, ',"capture2":', _scopedExportCaptureToken(tokens[tokens.length - 1])
            );
        }
        return string.concat(json, "}");
    }

    function _scopedExportCaptureToken(ScopedPreservationExportToken memory t)
        private
        pure
        returns (string memory)
    {
        return string.concat(
            '{"tokenId":',
            SPExportStrings.toString(t.tokenId),
            ',"collectionSerial":',
            SPExportStrings.toString(t.collectionSerial),
            ',"producer":',
            _scopedExportAccount(t.output.preservation.producer),
            ',"producerProfile":',
            _scopedExportHash(t.output.preservation.profile),
            ',"preservationBindingABI":',
            _scopedExportABI(abi.encode(t.output.preservation)),
            ',"preservationAdmissionABI":',
            _scopedExportABI(abi.encode(t.output.preservationAdmission)),
            ',"html":',
            _scopedExportABI(t.html),
            ',"metadataJSON":',
            _scopedExportABI(t.metadataJSON),
            "}"
        );
    }

    function _scopedExportABI(bytes memory raw) private pure returns (string memory) {
        return string.concat('"', SPExportEncoding.hexBytes(raw), '"');
    }

    function _scopedExportHash(bytes32 value) private pure returns (string memory) {
        return string.concat('"', SPExportStrings.toHexString(uint256(value), 32), '"');
    }

    function _scopedExportAccount(address value) private pure returns (string memory) {
        return string.concat('"', SPExportStrings.toHexString(uint160(value), 20), '"');
    }

    function _scopedExportWrite(string memory path, string memory raw) private {
        assemblyVm.writeFile(path, raw);
        require(
            keccak256(bytes(assemblyVm.readFile(path))) == keccak256(bytes(raw)),
            "exact export filesystem readback"
        );
    }

    function _scopedExportLabel(string memory label) private pure {
        bytes memory raw = bytes(label);
        require(raw.length != 0 && raw.length <= 64, "bounded nonempty run label");
        for (uint256 i; i < raw.length; ++i) {
            uint8 c = uint8(raw[i]);
            require(
                (c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 45
                    || c == 95,
                "run label is a single safe path component"
            );
        }
    }

    /// @dev Exact initial source envelope/size contract from reference_capture.py. Runtime
    /// feature and viewport checks belong to the later actual browser run and may still fail.
    function _scopedExportCaptureShape(bytes memory html) private pure {
        bytes memory prefix = bytes("<html><head></head><body><script>");
        bytes memory suffix = bytes("</script></body></html>");
        require(
            html.length >= prefix.length + suffix.length && html.length <= 65536,
            "declared capture runner HTML bound"
        );
        for (uint256 i; i < prefix.length; ++i) {
            require(html[i] == prefix[i], "exact capture HTML prefix");
        }
        for (uint256 i; i < suffix.length; ++i) {
            require(html[html.length - suffix.length + i] == suffix[i], "exact capture HTML suffix");
        }
    }
}
