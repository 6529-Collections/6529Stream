// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentFullPreservationPolicyViewAdoptionFixture.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as VPCheckpoint
} from "../../smart-contracts/interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    StreamViewPreservationManifestTypesV1 as VPManifest
} from "../../smart-contracts/interfaces/stream/finality/StreamViewPreservationManifestTypesV1.sol";
import {
    StreamViewPreservationSnapshotTypesV1 as VPSnapshot
} from "../../smart-contracts/interfaces/stream/metadata/StreamViewPreservationSnapshotTypesV1.sol";
import {
    StreamViewPreservationOutputSchemasV1 as VPOutputDefinitions
} from "../../smart-contracts/domains/finality/StreamViewPreservationOutputSchemasV1.sol";
import {
    StreamViewPreservationSnapshotDefinitionsV1 as VPSnapshotDefinitions
} from "../../smart-contracts/domains/records/StreamViewPreservationSnapshotDefinitionsV1.sol";
import {
    StreamViewPreservationContentDefinitionsV1 as VPRootDefinitions
} from "../../smart-contracts/domains/records/StreamViewPreservationContentDefinitionsV1.sol";
import {
    IStreamScopedContentRootPublication as VPScopedRoot
} from "../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamViewPreservationContentRootV1 as VPRoot
} from "../../smart-contracts/interfaces/stream/metadata/IStreamViewPreservationContentRootV1.sol";
import {
    IStreamViewPreservationRendererV1 as VPServing
} from "../../smart-contracts/interfaces/stream/metadata/IStreamViewPreservationRendererV1.sol";
import {
    StreamArtistContentTypes as VPArtistContent
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    StreamOnchainContentBytes
} from "../../smart-contracts/domains/finality/StreamOnchainContentBytes.sol";

/// @notice Actual adopted VIEW outputs, archive carriers, root-free snapshot and original op17 root.
/// @dev All products and authority calls are genuine. Locally signed archive observations and
/// producer-derived golden vectors remain fixture evidence; they establish no browser or gas result.
abstract contract StreamCurrentFullPreservationPolicyViewPublicationFixture is
    StreamCurrentFullPreservationPolicyViewAdoptionFixture
{
    bytes32 internal viewPublicationCheckpoint;
    bytes32 internal viewPublicationOutputManifest;
    bytes32 internal assemblyViewSnapshotRecord;
    bytes32 internal assemblyViewOriginalContentRoot;
    bytes32 internal viewPublicationRootConsent;
    uint64 internal viewRootConsentObservedAt;
    VPScopedRoot.Aggregate internal viewOriginalRootAggregate;
    bytes32 internal viewOriginalLegacyFamilyHash;
    VPSnapshot.Receipt internal viewPublicationSnapshotReceipt;
    mapping(uint256 => bytes) internal viewPublicationJSON;
    mapping(uint256 => bytes) internal viewPublicationHTML;

    function _publishFullPolicyViewBeforeFreeze() internal virtual override {
        require(
            !assemblyCore.collectionFreezeStatus(1), "VIEW ceremony before original Core freeze"
        );
        _admitFullPolicyViewPreservation();
        _viewPreparePublicationDefinitions();
        _viewCheckpointOutputs();
        _viewPublishAndLockSnapshot();
        _viewBeforeRootPublication();
        _viewPublishRoot();
        _viewAfterRootPublication();
        _viewRequireCurrentPublication();
    }

    /// @dev A test can exercise failure/retry while the original publication window is open.
    function _viewBeforeRootPublication() internal virtual { }

    function _viewAfterRootPublication() internal virtual { }

    function _viewPreparePublicationDefinitions() internal {
        _assemblySetupArchiveAdmissions();
        string[5] memory outputNames = [
            "STREAM_VIEW_PRESERVATION_OUTPUT_PART_V1",
            "STREAM_ABI_VIEW_PRESERVATION_OUTPUT_PART_V1",
            "STREAM_VIEW_PRESERVATION_OUTPUT_MANIFEST_V1",
            "STREAM_ABI_VIEW_PRESERVATION_OUTPUT_MANIFEST_V1",
            "STREAM_VIEW_PRESERVATION_CONTENT_LEAF_V1"
        ];
        for (uint256 i; i < outputNames.length; ++i) {
            bytes32 id = keccak256(bytes(outputNames[i]));
            _assemblyRegisterDocument(
                outputNames[i],
                i == 1 || i == 3
                    ? IStreamSchemaRegistry.DocumentKind.CANONICALIZATION
                    : IStreamSchemaRegistry.DocumentKind.SCHEMA,
                VPOutputDefinitions.document(id),
                assemblySchemas.RAW_BYTES()
            );
        }
        string[5] memory names = [
            "STREAM_VIEW_PRESERVATION_SNAPSHOT_ABI_V1",
            "STREAM_VIEW_PRESERVATION_SNAPSHOT_PROFILE_V1",
            "STREAM_ABI_VIEW_PRESERVATION_SNAPSHOT_V1",
            "STREAM_VIEW_PRESERVATION_CONTENT_ROOT_V1",
            "STREAM_ABI_VIEW_PRESERVATION_CONTENT_ROOT_V1"
        ];
        bytes32[5] memory hashes = [
            VPSnapshotDefinitions.SCHEMA_HASH,
            VPSnapshotDefinitions.PROFILE_HASH,
            VPSnapshotDefinitions.CANON_HASH,
            VPRootDefinitions.SCHEMA_HASH,
            VPRootDefinitions.CANON_HASH
        ];
        uint256[5] memory lengths = [
            VPSnapshotDefinitions.SCHEMA_BYTES,
            VPSnapshotDefinitions.PROFILE_BYTES,
            VPSnapshotDefinitions.CANON_BYTES,
            VPRootDefinitions.SCHEMA_BYTES,
            VPRootDefinitions.CANON_BYTES
        ];
        for (uint256 i; i < names.length; ++i) {
            string memory folder =
                i < 3 ? "view-preservation-snapshot-v1/" : "view-preservation-content-root-v1/";
            string memory suffix = i == 0 || i == 3 ? "schema" : i == 1 ? "profile" : "canon";
            bytes memory raw = bytes(
                assemblyVm.readFile(string.concat("schemas/metadata/", folder, suffix, ".json"))
            );
            require(
                raw.length == lengths[i] && keccak256(raw) == hashes[i],
                "exact VIEW definition source bytes"
            );
            _assemblyRegisterDocument(
                names[i],
                i == 2 || i == 4
                    ? IStreamSchemaRegistry.DocumentKind.CANONICALIZATION
                    : i == 1
                        ? IStreamSchemaRegistry.DocumentKind.CATALOG
                        : IStreamSchemaRegistry.DocumentKind.SCHEMA,
                raw,
                assemblySchemas.RAW_BYTES()
            );
        }
        _assemblyGrantFamily(StreamRecordFamilies.SNAPSHOT, 7, address(this));
        (bool identity, uint64 revision) =
            assemblyMetadata.familyWriter(1, StreamRecordFamilies.IDENTITY, 7, address(this));
        require(identity && revision != 0, "original display writer grant remains explicit");
    }

    function _viewCurrentPreservationBytes(uint256 tokenId, bool html)
        internal
        view
        returns (bytes memory raw)
    {
        bytes memory input = html
            ? abi.encodeCall(VPServing.preservationViewHTML, (fullPolicyViewScope, tokenId))
            : abi.encodeCall(VPServing.preservationViewJSON, (fullPolicyViewScope, tokenId));
        uint256 cap = assemblyViewPreservationCheckpoint.configuration().servingGas;
        (bool ok, bytes memory result) =
            address(assemblyViewPreservationRenderer).staticcall{ gas: cap }(input);
        require(ok, "actual VIEW preservation serving within original configured cap");
        (bytes32 adoption, string memory output) = abi.decode(result, (bytes32, string));
        require(
            adoption == fullPolicyViewAdoption
                && keccak256(result) == keccak256(abi.encode(adoption, output)),
            "exact current VIEW adoption and canonical output transport"
        );
        raw = bytes(output);
        require(raw.length != 0, "complete VIEW preservation output");
    }

    function _viewCheckpointOutputs() internal {
        viewPublicationCheckpoint = assemblyViewPreservationCheckpoint.begin(
            fullPolicyViewScope, keccak256("actual current VIEW preservation ceremony")
        );
        for (uint256 i; i < fullPolicyTokens.length; ++i) {
            uint256 token = fullPolicyTokens[i];
            bytes memory json = _viewCurrentPreservationBytes(token, false);
            bytes memory html = _viewCurrentPreservationBytes(token, true);
            require(
                StreamOnchainContentBytes.matchesAnimation(json, html),
                "complete actual VIEW HTML nested in JSON"
            );
            viewPublicationJSON[token] = json;
            viewPublicationHTML[token] = html;
            assemblyViewPreservationCheckpoint.append(viewPublicationCheckpoint, token, json, html);
        }
        assemblyViewPreservationCheckpoint.seal(viewPublicationCheckpoint);
        VPCheckpoint.Plan memory p =
            assemblyViewPreservationCheckpoint.requireCurrentCheckpoint(viewPublicationCheckpoint);
        require(
            p.tokenCount == 2 && p.nextIndex == 2 && p.adoptionRecord == fullPolicyViewAdoption
                && p.contentRoot != 0 && p.outputRoot != 0,
            "complete actual VIEW membership and outputs"
        );
        VPCheckpoint.Output[] memory rows = new VPCheckpoint.Output[](2);
        bytes32[2] memory leaves;
        for (uint256 i; i < rows.length; ++i) {
            rows[i] = assemblyViewPreservationCheckpoint.outputAt(viewPublicationCheckpoint, i);
            uint256 token = fullPolicyTokens[i];
            (uint8 status, bytes32 seed, address selectedProvider) =
                entropy.staticTokenRenderFacts(token);
            require(
                status == 5 && seed != 0 && selectedProvider == address(provider)
                    && rows[i].entropy.coordinator == address(entropy)
                    && rows[i].entropy.coordinatorCodeHash == address(entropy).codehash
                    && rows[i].entropy.status == status && rows[i].entropy.seed == seed
                    && rows[i].entropy.finalized,
                "VIEW row preserves actual original fulfilled entropy"
            );
            require(
                rows[i].index == i && rows[i].tokenId == token
                    && rows[i].jsonHash == keccak256(viewPublicationJSON[token])
                    && rows[i].htmlHash == keccak256(viewPublicationHTML[token])
                    && rows[i].jsonBytes == viewPublicationJSON[token].length
                    && rows[i].htmlBytes == viewPublicationHTML[token].length && !rows[i].burned
                    && rows[i].servingKind == 1,
                "full ordered actual VIEW row fields"
            );
            leaves[i] = keccak256(
                abi.encode(
                    keccak256("6529STREAM_VIEW_PRESERVATION_CONTENT_LEAF_V1"),
                    keccak256("6529STREAM_ADOPTED_POLICY_VIEW_PRESERVATION_V1"),
                    block.chainid,
                    address(assemblyCore),
                    fullPolicyViewScope,
                    fullPolicyViewAdoption,
                    rows[i]
                )
            );
        }
        require(
            p.contentRoot
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_PRESERVATION_CONTENT_NODE_V1"),
                        leaves[0],
                        leaves[1]
                    )
                ),
            "independent ordered two-leaf VIEW content root"
        );
        _viewCoverManifest(p, rows);
    }

    function _viewCoverManifest(VPCheckpoint.Plan memory p, VPCheckpoint.Output[] memory rows)
        private
    {
        VPManifest.Configuration memory c = assemblyViewPreservationManifest.configuration();
        VPManifest.Header memory h = VPManifest.Header(
            viewPublicationCheckpoint,
            keccak256(abi.encode(p)),
            fullPolicyViewScope,
            p.adoptionRecord,
            p.sourceContextHash,
            p.membershipHash,
            p.policyChainHash,
            p.tokenCount,
            p.outputRoot,
            p.contentRoot
        );
        // Independent literal canonical encoders; the publisher authenticates every byte.
        bytes memory raw = abi.encode(
            VPOutputDefinitions.PART,
            block.chainid,
            address(assemblyCore),
            c.checkpoint,
            c.checkpointConfigurationHash,
            h,
            uint64(0),
            rows
        );
        require(
            raw.length == 672 + 992 * rows.length, "complete final remainder part canonical size"
        );
        (bytes32 artifact, bytes32 coverage) =
            _ocCover(raw, VPOutputDefinitions.PART, VPOutputDefinitions.PART_CANON);
        bytes32 partRecord = assemblyViewPreservationManifest.preparePart(
            viewPublicationCheckpoint, 0, artifact, coverage, assemblyArtistId
        );
        VPManifest.Part memory part = assemblyViewPreservationManifest.partRecord(partRecord);
        require(
            part.first == 0 && part.count == 2 && part.firstToken == fullPolicyTokens[0]
                && part.lastToken == fullPolicyTokens[1]
                && part.carrier.contentHash == keccak256(raw)
                && part.carrier.byteLength == raw.length,
            "complete covered part retains exact two current outputs"
        );
        VPManifest.Descriptor[] memory descriptors = new VPManifest.Descriptor[](1);
        descriptors[0] = VPManifest.Descriptor(
            partRecord,
            artifact,
            coverage,
            keccak256(raw),
            uint64(raw.length),
            0,
            2,
            fullPolicyTokens[0],
            fullPolicyTokens[1]
        );
        raw = abi.encode(
            VPOutputDefinitions.INDEX,
            block.chainid,
            address(assemblyCore),
            c.checkpoint,
            c.checkpointConfigurationHash,
            h,
            assemblyArtistId,
            descriptors
        );
        require(raw.length == 672 + 288 * descriptors.length, "complete VIEW index canonical size");
        (artifact, coverage) =
            _ocCover(raw, VPOutputDefinitions.INDEX, VPOutputDefinitions.INDEX_CANON);
        bytes32 plan = assemblyViewPreservationManifest.beginManifest(
            viewPublicationCheckpoint, artifact, coverage, assemblyArtistId
        );
        viewPublicationOutputManifest =
            assemblyViewPreservationManifest.verifyNextPart(plan, partRecord);
        VPManifest.Plan memory output = assemblyViewPreservationManifest.requireCurrentManifest(
            viewPublicationOutputManifest, assemblyArtistId
        );
        require(
            viewPublicationOutputManifest != 0 && output.nextRow == 2 && output.nextPart == 1
                && output.partCount == 1 && output.carrier.contentHash == keccak256(raw)
                && output.carrier.byteLength == raw.length
                && output.header.contentRoot == p.contentRoot
                && output.header.outputRoot == p.outputRoot,
            "actual complete archive-covered VIEW index"
        );
    }

    function _viewPublishAndLockSnapshot() internal {
        VPSnapshot.Publication memory p = VPSnapshot.Publication(
            fullPolicyViewScope,
            keccak256("actual VIEW root-free snapshot"),
            bytes32(0),
            0,
            viewPublicationOutputManifest,
            fullPolicyViewAdoption,
            bytes32(0),
            "urn:fixture:view-preservation:snapshot",
            uint64(block.timestamp),
            keccak256("actual adopted VIEW original source snapshot")
        );
        bytes memory canonical;
        (p.expectedSourceHash, canonical) =
            assemblyViewPreservationSnapshot.previewSnapshot(p, address(this));
        _assemblyUpload(canonical);
        assemblyViewSnapshotRecord = assemblyViewPreservationSnapshot.publishSnapshot(p);
        viewPublicationSnapshotReceipt = assemblyViewPreservationSnapshot.requireCurrent(
            fullPolicyViewScope, assemblyViewSnapshotRecord, 1
        );
        require(
            viewPublicationSnapshotReceipt.recordHash == assemblyViewSnapshotRecord
                && viewPublicationSnapshotReceipt.manifestHash == keccak256(canonical)
                && viewPublicationSnapshotReceipt.manifestBytes == canonical.length
                && viewPublicationSnapshotReceipt.authorizationClass == 7
                && viewPublicationSnapshotReceipt.displayAuthorizationClass == 7
                && keccak256(
                    assemblyViewPreservationSnapshot.snapshotPayload(assemblyViewSnapshotRecord)
                ) == keccak256(canonical),
            "actual root-free snapshot bytes and both original grants"
        );
        require(
            VPScopedRoot(address(assemblyRouter)).scopedContentRootHead(fullPolicyViewScope) == 0,
            "snapshot requires no future content root"
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            assemblyViewPreservationSnapshot.lockTransition(fullPolicyViewScope);
        GenesisBatch memory batch;
        batch.actionClass = 2;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.callDatas[0] =
            abi.encodeCall(assemblyViewPreservationSnapshot.lockSnapshot, (fullPolicyViewScope));
        batch.calls[0] = StreamCurrentStackPlan.call(
            address(assemblyViewPreservationSnapshot), batch.callDatas[0], scope, oldHash, newHash
        );
        _admitAssemblyBatch(batch);
        bytes32 action = _assemblyGovernance(batch, "urn:fixture:view-preservation:seal-snapshot");
        VPSnapshot.Lock memory saved =
            assemblyViewPreservationSnapshot.snapshotLock(fullPolicyViewScope);
        require(
            saved.recordHash == assemblyViewSnapshotRecord && saved.revision == 1
                && saved.actionId == action && saved.lockedAt != 0,
            "actual original class2 snapshot seal"
        );
    }

    function _viewRootPublication() internal view returns (VPScopedRoot.Publication memory) {
        return VPScopedRoot.Publication(
            fullPolicyViewScope,
            bytes32(0),
            assemblyViewSnapshotRecord,
            1,
            "urn:fixture:view-preservation:content-root"
        );
    }

    function _viewPublishRoot() internal {
        VPScopedRoot.Publication memory p = _viewRootPublication();
        require(
            VPScopedRoot(address(assemblyRouter)).scopedContentRootAggregate(1).revision == 0
                && assemblyRouter.collectionContentRootHead(1) == 0,
            "fixture starts with no original or scoped content root"
        );
        (bool supported, bytes32 legacy) =
            assemblyRouter.artistContentFamilyState(1, keccak256("CONTENT_ROOT"));
        require(
            supported
                && legacy
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_EMPTY_CONTENT_ROOT_STATE_V1"),
                            block.chainid,
                            address(assemblyRouter),
                            address(assemblyCore),
                            uint256(1)
                        )
                    ),
            "actual pre-publication legacy family witness"
        );
        viewOriginalLegacyFamilyHash = legacy;
        bytes32 state =
            VPRoot(address(assemblyRouter)).previewViewPreservationContentRoot(p, address(this));
        VPArtistContent.Consent memory consent =
            VPArtistContent.Consent(1, address(assemblyRouter), keccak256("CONTENT_ROOT"), state);
        T.Authorization memory authorization = _assemblyAuthorization(false);
        authorization.signature =
            _assemblyArtistProof(assemblyArtists.contentConsentDigest(consent, authorization));
        viewRootConsentObservedAt = uint64(block.timestamp);
        viewPublicationRootConsent = assemblyArtists.recordContentConsent(consent, authorization);
        require(
            viewPublicationRootConsent != fullPolicyViewConsent
                && !assemblyRouter.consumedArtistContentConsent(viewPublicationRootConsent),
            "root consent is distinct from adoption consent"
        );
        assemblyViewOriginalContentRoot =
            VPRoot(address(assemblyRouter)).publishViewPreservationContentRoot(p);
        VPScopedRoot.Record memory saved = VPScopedRoot(address(assemblyRouter))
            .scopedContentRootRecord(assemblyViewOriginalContentRoot);
        viewOriginalRootAggregate =
            VPScopedRoot(address(assemblyRouter)).scopedContentRootAggregate(1);
        require(
            viewOriginalRootAggregate.revision == 1
                && assemblyViewOriginalContentRoot
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_SCOPED_CONTENT_ROOT_RECORD_V1"),
                            block.chainid,
                            address(assemblyRouter),
                            address(assemblyCore),
                            saved,
                            viewOriginalRootAggregate
                        )
                    )
                && state
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_CONTENT_ROOT_FAMILY_WITH_SCOPES_V1"),
                            block.chainid,
                            address(assemblyRouter),
                            address(assemblyCore),
                            uint256(1),
                            legacy,
                            viewOriginalRootAggregate
                        )
                    ),
            "exact historical aggregate and signed family preimages for future inventory"
        );
        require(
            saved.artistConsent == viewPublicationRootConsent && saved.artistId == assemblyArtistId
                && saved.publisher == address(this)
                && saved.snapshotHost == address(assemblyViewPreservationSnapshot)
                && saved.snapshotManifestHash == viewPublicationSnapshotReceipt.manifestHash
                && saved.snapshotSourceHash == viewPublicationSnapshotReceipt.sourceHash
                && saved.publication.snapshotRecordHash == assemblyViewSnapshotRecord
                && saved.publication.snapshotRevision == 1
                && assemblyRouter.consumedArtistContentConsent(viewPublicationRootConsent),
            "original op17 root and exact retained source"
        );
        VPRoot.Binding memory b = VPRoot(address(assemblyRouter))
            .viewPreservationContentRootBinding(assemblyViewOriginalContentRoot);
        require(
            b.profileId == VPRootDefinitions.PROFILE
                && b.outputProfile == VPCheckpoint.OUTPUT_PROFILE
                && b.adoptionRecord == fullPolicyViewAdoption
                && b.checkpoint == address(assemblyViewPreservationCheckpoint)
                && b.checkpointRecord == viewPublicationCheckpoint
                && b.outputManifest == address(assemblyViewPreservationManifest)
                && b.outputManifestRecord == viewPublicationOutputManifest
                && b.preservationRenderer == address(assemblyViewPreservationRenderer)
                && b.liveRenderer == address(fullPolicyViewRenderer),
            "exact VIEW content profile and genuine producer joins"
        );
    }

    function _viewRequireCurrentPublication() internal view {
        VPCheckpoint.Plan memory checkpoint =
            assemblyViewPreservationCheckpoint.requireCurrentCheckpoint(viewPublicationCheckpoint);
        VPManifest.Plan memory manifest = assemblyViewPreservationManifest.requireCurrentManifest(
            viewPublicationOutputManifest, assemblyArtistId
        );
        VPSnapshot.Receipt memory receipt = assemblyViewPreservationSnapshot.requireCurrent(
            fullPolicyViewScope, assemblyViewSnapshotRecord, 1
        );
        require(
            keccak256(abi.encode(receipt)) == keccak256(abi.encode(viewPublicationSnapshotReceipt))
                && manifest.header.contentRoot == checkpoint.contentRoot
                && VPScopedRoot(address(assemblyRouter)).scopedContentRootHead(fullPolicyViewScope)
                    == assemblyViewOriginalContentRoot,
            "same original VIEW source remains current after root"
        );
        for (uint256 i; i < fullPolicyTokens.length; ++i) {
            uint256 token = fullPolicyTokens[i];
            require(
                keccak256(_viewCurrentPreservationBytes(token, false))
                        == keccak256(viewPublicationJSON[token])
                    && keccak256(_viewCurrentPreservationBytes(token, true))
                        == keccak256(viewPublicationHTML[token]),
                "actual VIEW root does not change preservation bytes"
            );
        }
    }
}
