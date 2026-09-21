// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentFullPreservationPolicyViewInputFixture.sol";
import {
    StreamViewRetrievalWitnessTypesV1 as VR
} from "../../smart-contracts/interfaces/stream/preservation/StreamViewRetrievalWitnessTypesV1.sol";
import {
    StreamExternalArtifactTypes as VRExternal
} from "../../smart-contracts/interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import {
    StreamArchivalTypes as VRArchive
} from "../../smart-contracts/interfaces/stream/preservation/StreamArchivalTypes.sol";
import {
    StreamPreservationInventoryTypes as VRInventory
} from "../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamBundleArchiveTypes as VRBundle
} from "../../smart-contracts/interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamViewAdoptionTypes as VRAdoption
} from "../../smart-contracts/interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import {
    StreamViewPreservationRenderCriticalTypesV1 as VRView
} from "../../smart-contracts/interfaces/stream/preservation/StreamViewPreservationRenderCriticalTypesV1.sol";
import {
    StreamViewPreservationRenderCriticalArtworkReadsV1 as VRArtwork
} from "../../smart-contracts/domains/preservation/StreamViewPreservationRenderCriticalArtworkReadsV1.sol";
import {
    StreamReferenceRenderDefinitions as VRDefinitions
} from "../../smart-contracts/domains/records/StreamReferenceRenderDefinitions.sol";
import {
    StreamViewPayloadV2 as VRPayload
} from "../../smart-contracts/domains/metadata/StreamViewPayloadV2.sol";
import {
    StreamFinalityViewPreservationInputSchemasV1 as VRInput
} from "../../smart-contracts/domains/finality/StreamFinalityViewPreservationInputSchemasV1.sol";
import {
    StreamFinalityViewSanctionProfileV1 as VRMedia
} from "../../smart-contracts/domains/finality/StreamFinalityViewSanctionProfileV1.sol";
import {
    IStreamSchemaRegistry as VRSchema
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamSchemaDocumentFacts as VRDocuments
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";

/// @notice Nonempty adopted image over the original actual Core/Artist/Router VIEW recipe.
/// @dev The institutional retrieval assertion and native observer certificate are explicit local
/// signed fixtures. They are not network retrieval or browser execution. Supplied reference
/// observations remain independently required by the inherited finality entry. No caps change.
abstract contract StreamCurrentFullPreservationPolicyViewRetrievalFixture is
    StreamCurrentFullPreservationPolicyViewInputFixture
{
    string internal constant VIEW_RETRIEVAL_ORIGIN =
        "https://origin.example.invalid/view/image.png?edition=%31#original";
    string internal constant VIEW_RETRIEVAL_MIRROR =
        "https://institution.example.invalid/view/exact-image.png";
    bytes32 internal viewImageInstitutionalFamily;
    VRExternal.ObjectIdentity internal viewImageObject;
    VRExternal.Coverage internal viewImageCoverage;
    bytes32 internal viewImageWitness;
    bytes32 internal viewImageRevokedPredecessor;
    uint64 internal viewImageOccurrence;
    uint256 internal viewImagePreparedCount;
    uint256 internal viewImageCoveredCount;

    function _fullPolicyViewImageURI() internal pure override returns (string memory) {
        return VIEW_RETRIEVAL_ORIGIN;
    }

    function _viewRequireArtworkImage(VRAdoption.Payload memory p) internal pure override {
        require(
            keccak256(bytes(p.imageURI)) == keccak256(bytes(VIEW_RETRIEVAL_ORIGIN)),
            "exact genuinely nonempty adopted image URI"
        );
    }

    function _viewIsSpecialCoverage(VRInventory.Item memory item)
        internal
        pure
        override
        returns (bool)
    {
        return item.kind == VRInventory.Kind.EXTERNAL_REFERENCE && item.role == VR.ROLE;
    }

    function _viewPrepareSpecialCoverage(VRInventory.Item memory item)
        internal
        override
        returns (bool)
    {
        if (!_viewIsSpecialCoverage(item)) return false;
        _viewRequireImageOccurrence(item);
        require(
            viewImageWitness != 0 && viewImagePreparedCount++ == 0,
            "one complete signed image occurrence prepared before environment freeze"
        );
        _viewRequireImageWitness(viewImageWitness);
        return true;
    }

    function _viewCoverInventoryOccurrence(
        bytes32 id,
        VRInventory.Item memory item,
        bytes32 nextLink,
        VRBundle.Proof memory proof
    ) internal override {
        if (!_viewIsSpecialCoverage(item)) {
            super._viewCoverInventoryOccurrence(id, item, nextLink, proof);
            return;
        }
        _viewRequireImageOccurrence(item);
        VRBundle.Progress memory before_ = viewBundle.progress(id);
        VRView.Context memory context = viewInventory.sourceContext(id);
        VRInventory.Segment memory segment =
            viewInventory.inventorySegment(id, before_.segmentIndex);
        require(
            segment.sourceWitnessHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_PRESERVATION_OUTPUT_INVENTORY_SOURCE_V1"),
                        context.adoptionRecord,
                        context.checkpointHash,
                        context.sourceContextHash,
                        uint16(8),
                        uint64(0),
                        uint64(7)
                    )
                ),
            "literal original stage8 source witness"
        );
        require(
            id == viewRenderInventoryPlan && before_.segmentItemIndex == 5 && segment.itemCount == 7
                && viewImageCoveredCount++ == 0 && proof.backend == 0,
            "actual complete artwork segment and whole image ordinal"
        );
        viewImageOccurrence = before_.itemCount;
        viewBundle.coverRetrievalNext(id, item, nextLink, viewImageWitness);
        (VRInventory.Item memory saved, VRBundle.Admission memory admitted) =
            viewBundle.admittedItem(id, before_.itemCount);
        require(
            viewBundle.progress(id).itemCount == before_.itemCount + 1
                && viewBundle.retrievalWitnessForItem(id, before_.itemCount) == viewImageWitness
                && keccak256(abi.encode(saved)) == keccak256(abi.encode(item))
                && admitted.proof.backend == 1
                && admitted.proof.coverageHash == viewImageCoverage.coverageHash
                && admitted.proof.objectHash == viewImageCoverage.objectHash
                && keccak256(abi.encode(admitted.externalOriginal))
                    == keccak256(abi.encode(viewImageCoverage)),
            "same original full pair and exact occurrence admitted through retrieval path"
        );
    }

    function _viewRequireImageOccurrence(VRInventory.Item memory item) private view {
        VRView.Context memory c = viewInventory.sourceContext(viewRenderInventoryPlan);
        VRInventory.Item[] memory artwork = VRArtwork.items(viewInventory.dependencies(), c);
        require(
            artwork.length == 7 && keccak256(abi.encode(item)) == keccak256(abi.encode(artwork[5]))
                && c.artistId == assemblyArtistId && c.adoptionRecord == fullPolicyViewAdoption
                && c.payloadHash == keccak256(fullPolicyViewPayload)
                && item.source == address(assemblyRouter)
                && item.sourceRecord == fullPolicyViewAdoption && item.sourceIndex == 0
                && item.algorithm == 0 && item.digest.length == 0 && item.byteSize == 0
                && item.objectHash == 0 && item.originalCoverageHash == 0
                && keccak256(bytes(item.uri)) == keccak256(bytes(VIEW_RETRIEVAL_ORIGIN)),
            "full actual source row; URI never supplies object digest or size"
        );
    }

    function _viewPrepareImageArchive() internal {
        require(
            viewImageCoverage.coverageHash == 0 && axFirstFamily != 0,
            "fresh image and existing original endowed family"
        );
        _viewRequireArtworkImage(VRPayload.decode(fullPolicyViewPayload));
        VRArchive.Family memory f = VRArchive.Family(
            keccak256("actual-view-retrieval-institution"),
            keccak256("INSTITUTIONAL_ARCHIVE"),
            keccak256("view-safe-protocol"),
            keccak256("view-safe-addressing"),
            keccak256("view-safe-custodian"),
            keccak256("view-safe-funding"),
            keccak256("view-safe-retrieval"),
            keccak256("same jurisdiction allowed"),
            2,
            address(assemblyRoot),
            assemblyExternal.POSSESSION_PROFILE()
        );
        (bytes32 family, bytes32 subject, bytes32 oldHash, bytes32 newHash) =
            assemblyExternal.familyRegistrationContext("actual-view-retrieval-institution", f);
        _assemblyGovernanceCall(
            1,
            address(assemblyExternal),
            abi.encodeCall(assemblyExternal.admitFamily, ("actual-view-retrieval-institution", f)),
            subject,
            oldHash,
            newHash
        );
        (VRArchive.Family memory saved, uint8 status, uint64 revision) =
            assemblyExternal.family(family);
        require(
            status == 1 && revision == 1
                && keccak256(abi.encode(saved)) == keccak256(abi.encode(f)),
            "actual class1 institutional Safe family admission"
        );
        viewImageInstitutionalFamily = family;
        bytes memory png = _viewRetrievalPNG();
        bytes32 sha = sha256(png);
        viewImageObject = VRExternal.ObjectIdentity(
            assemblyArtistId,
            VRDefinitions.PNG_SCHEMA_ID,
            keccak256("RAW_BYTES"),
            keccak256(png),
            sha,
            sha256(abi.encodePacked(sha256(abi.encodePacked(sha)), sha256(abi.encode(png.length)))),
            uint64(png.length),
            keccak256("IANA:image/png"),
            VRDefinitions.FORMAT_CATALOG_ID,
            VRDefinitions.FORMAT_CATALOG_HASH
        );
        bytes32 objectHash = assemblyExternal.recordObject(viewImageObject);
        require(
            objectHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_EXTERNAL_OBJECT_V1"),
                        block.chainid,
                        address(assemblyExternal),
                        address(assemblyCore),
                        viewImageObject
                    )
                ),
            "literal original full PNG object preimage"
        );
        bytes memory path = abi.encode(sha, png.length);
        (bytes32 checkpoint, bytes32 txid) =
            _axCheckpoint(viewImageObject, objectHash, path, path, png, png);
        bytes32 first = _axReceipt(objectHash, sha, checkpoint, txid, true);
        VRExternal.Receipt memory receipt = VRExternal.Receipt(
            objectHash,
            family,
            keccak256(bytes(VIEW_RETRIEVAL_MIRROR)),
            keccak256("ATTESTED_POSSESSION"),
            assemblyExternal.POSSESSION_PROFILE(),
            0,
            address(assemblyRoot),
            uint64(block.timestamp),
            uint256(objectHash),
            uint64(block.timestamp + 1 days)
        );
        receipt.proofRecordHash = assemblyExternal.possessionHash(receipt);
        bytes memory signature = safeThresholdSignature(
            assemblyRootKeys,
            safeMessageDigest(
                assemblyRoot, abi.encodePacked(assemblyExternal.receiptDigest(receipt))
            )
        );
        bytes32 second =
            assemblyExternal.recordReceipt(receipt, bytes(VIEW_RETRIEVAL_MIRROR), signature);
        _assemblyExternalFixity(first, 1, 0);
        _assemblyExternalFixity(second, 1, 0);
        bytes32 coverage = assemblyExternal.recordCoverage(first, second);
        viewImageCoverage = assemblyExternal.requireCoverage(coverage, assemblyArtistId, objectHash);
        require(
            viewImageCoverage.firstReceiptHash == first
                && viewImageCoverage.secondReceiptHash == second
                && viewImageCoverage.secondFamilyRecordHash == family
                && viewImageCoverage.contentHash == keccak256(png)
                && viewImageCoverage.sha256Digest == sha
                && viewImageCoverage.byteSize == png.length,
            "actual independent native/endowed plus Safe possession pair for complete PNG"
        );
    }

    function _viewImageRequest(uint256 nonce) internal view returns (VR.Request memory q) {
        q.scope = fullPolicyViewScope;
        q.coverageHash = viewImageCoverage.coverageHash;
        q.steps = new VR.Step[](1);
        q.steps[0] = VR.Step(2, VIEW_RETRIEVAL_ORIGIN, VIEW_RETRIEVAL_MIRROR, 0, 0, 0, "");
        q.resolvedURI = VIEW_RETRIEVAL_MIRROR;
        q.observedAt = uint64(block.timestamp);
        q.nonce = nonce;
        q.deadline = uint64(block.timestamp + 1 days);
    }

    function _viewPrepareImageRequest(VR.Request memory q)
        internal
        returns (VR.Observation memory o, bytes memory signature)
    {
        bytes32 digest;
        (o, digest) = viewRetrieval.prepare(q);
        require(
            o.writer == address(assemblyRoot) && o.source.artistId == assemblyArtistId
                && o.source.adoptionRecord == fullPolicyViewAdoption
                && o.source.payloadHash == keccak256(fullPolicyViewPayload)
                && keccak256(abi.encode(o.object)) == keccak256(abi.encode(viewImageObject))
                && keccak256(abi.encode(o.coverage)) == keccak256(abi.encode(viewImageCoverage))
                && digest
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_VIEW_RETRIEVAL_OBSERVATION_V1"),
                            block.chainid,
                            address(viewRetrieval),
                            viewRetrieval.configurationHash(),
                            o
                        )
                    ),
            "full actual locked Artist/source, original pair and independent signing domain"
        );
        signature = safeThresholdSignature(
            assemblyRootKeys, safeMessageDigest(assemblyRoot, abi.encodePacked(digest))
        );
        _assemblyUpload(abi.encode(o, signature));
    }

    function _viewPublishImage(uint256 nonce) internal returns (bytes32 recordHash) {
        VR.Request memory q = _viewImageRequest(nonce);
        (VR.Observation memory o, bytes memory signature) = _viewPrepareImageRequest(q);
        recordHash = viewRetrieval.publish(q, signature);
        require(
            keccak256(viewRetrieval.encoded(recordHash)) == keccak256(abi.encode(o, signature)),
            "complete immutable original Store observation and Safe signature"
        );
        _viewRequireImageWitness(recordHash);
    }

    function _viewRequireImageWitness(bytes32 hash) internal view {
        (VR.Source memory source, VR.Receipt memory receipt, VRBundle.Admission memory admission) =
            viewRetrieval.requireCorrespondence(hash);
        require(
            receipt.recordHash == hash && receipt.writer == address(assemblyRoot)
                && source.artistId == assemblyArtistId
                && source.adoptionRecord == fullPolicyViewAdoption
                && source.payloadHash == keccak256(fullPolicyViewPayload)
                && keccak256(abi.encode(source.scope)) == keccak256(abi.encode(fullPolicyViewScope))
                && keccak256(bytes(source.requestedURI)) == keccak256(bytes(VIEW_RETRIEVAL_ORIGIN))
                && admission.proof.backend == 1
                && admission.proof.objectHash == viewImageCoverage.objectHash
                && keccak256(abi.encode(admission.externalOriginal))
                    == keccak256(abi.encode(viewImageCoverage)),
            "complete current correspondence from actual source and same original archive pair"
        );
    }

    function _viewRevokeAndReprepareImage() internal {
        viewImageRevokedPredecessor = _viewPublishImage(1);
        uint64 epoch = viewRetrieval.revocationEpoch(fullPolicyViewScope);
        require(
            executeSafe(
                assemblyRoot,
                assemblyRootKeys,
                address(viewRetrieval),
                0,
                abi.encodeCall(
                    viewRetrieval.revoke,
                    (viewImageRevokedPredecessor, keccak256("replace before coverage"))
                ),
                0
            ),
            "actual institutional Safe revokes its own observation"
        );
        _viewRequireRevokedImage(viewImageRevokedPredecessor);
        require(
            viewRetrieval.revocationEpoch(fullPolicyViewScope) == epoch + 1,
            "only original authenticated scope epoch advances"
        );
        viewImageWitness = _viewPublishImage(2);
        require(
            viewImageWitness != viewImageRevokedPredecessor
                && viewRetrieval.record(viewImageRevokedPredecessor).recordHash
                    == viewImageRevokedPredecessor,
            "fresh signed nonce replaces only usable evidence; revoked history remains"
        );
    }

    function _viewRequireRevokedImage(bytes32 hash) internal view {
        (bool ok, bytes memory reason) =
            address(viewRetrieval).staticcall(abi.encodeCall(viewRetrieval.requireCurrent, (hash)));
        require(
            !ok
                && keccak256(reason)
                    == keccak256(abi.encodeWithSelector(VR.ViewRetrievalRevoked.selector, hash)),
            "exact revocation refusal precedes every later current read"
        );
    }

    function _viewRepairImageFixityAndRefresh() internal {
        require(
            viewImageCoveredCount == 1 && viewBundle.progress(viewRenderInventoryPlan).complete,
            "complete original image-bearing bundle before drift"
        );
        bytes32 failing = _assemblyExternalFixity(viewImageCoverage.secondReceiptHash, 2, 0);
        (bool ok,) = address(viewRetrieval)
            .staticcall(abi.encodeCall(viewRetrieval.requireCurrent, (viewImageWitness)));
        require(!ok, "actual same-pair failing fixity invalidates retained correspondence");
        _viewRequireBundleNotCurrent();
        (VRExternal.Fixity memory failure,) = assemblyExternal.fixity(failing);
        _assemblyExternalFixity(viewImageCoverage.secondReceiptHash, 1, failure.reportHash);
        _viewRequireImageWitness(viewImageWitness);
        _viewRequireBundleNotCurrent();
        bytes32 refresh = viewBundle.beginRefresh(viewRenderInventoryPlan);
        uint64 count = viewCompleteBundle.coverage.itemCount;
        for (uint64 i; i < count; ++i) {
            viewBundle.refreshNext(viewRenderInventoryPlan, i);
        }
        require(
            viewBundle.refresh(refresh).complete && viewBundle.refresh(refresh).nextIndex == count
                && keccak256(
                    abi.encode(viewBundle.requireFullCurrentCoverage(viewRenderInventoryPlan))
                ) == keccak256(abi.encode(viewCompleteBundle))
                && keccak256(
                    abi.encode(
                        viewBundle.requireCoverage(
                            fullPolicyViewScope,
                            viewRenderInventoryPlan,
                            viewRenderInventoryEvidence.inventory.renderCriticalEvidenceHash
                        )
                    )
                ) == keccak256(abi.encode(viewCompleteBundle)),
            "same original pair and complete ordered refresh restore current original bundle"
        );
    }

    function _viewRequireBundleNotCurrent() private view {
        (bool ok, bytes memory reason) = address(viewBundle)
            .staticcall(
                abi.encodeCall(
                    viewBundle.requireCoverage,
                    (
                        fullPolicyViewScope,
                        viewRenderInventoryPlan,
                        viewRenderInventoryEvidence.inventory.renderCriticalEvidenceHash
                    )
                )
            );
        require(
            !ok
                && keccak256(reason)
                    == keccak256(abi.encodeWithSelector(VRInventory.InventoryIncomplete.selector)),
            "changed original environment cannot reuse cached complete refresh"
        );
    }

    function _viewRetrievalPNG() internal pure returns (bytes memory) {
        return hex"89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000b49444154789c6360000200000500017a5eab3f0000000049454e44ae426082";
    }

    function _viewPrepareFinalityDefinitions() internal override {
        _viewRetrievalDefinition(
            "STREAM_VIEW_PRESERVATION_FINALITY_INPUT_V1",
            VRInput.SCHEMA_ID,
            VRSchema.DocumentKind.SCHEMA,
            VRInput.document(VRInput.SCHEMA_ID)
        );
        _viewRetrievalDefinition(
            "STREAM_VIEW_PRESERVATION_FINALITY_INPUT_ABI_V1",
            VRInput.CANON_ID,
            VRSchema.DocumentKind.CANONICALIZATION,
            VRInput.document(VRInput.CANON_ID)
        );
        _viewRetrievalDefinition(
            "6529STREAM_ARTIST_SANCTION_VIEW_MEDIA_V1",
            VRMedia.ID,
            VRSchema.DocumentKind.CATALOG,
            VRMedia.document()
        );
        VRMedia.requireCurrent(
            address(assemblySchemas),
            address(assemblySchemas).codehash,
            address(assemblyStore),
            address(assemblyStore).codehash,
            500000
        );
    }

    function _viewRetrievalDefinition(
        string memory name,
        bytes32 id,
        VRSchema.DocumentKind kind,
        bytes memory raw
    ) private {
        bytes32 registered = _assemblyRegisterDocument(name, kind, raw, assemblySchemas.RAW_BYTES());
        VRDocuments.DocumentFacts memory facts = assemblySchemas.documentFacts(id);
        require(
            registered == id && id == keccak256(bytes(name)) && facts.exists && facts.kind == kind
                && facts.status == VRSchema.DocumentStatus.ACTIVE
                && facts.contentHash == keccak256(raw)
                && facts.canonicalizationId == assemblySchemas.RAW_BYTES()
                && facts.supersedesId == 0 && facts.chunkCount == 1
                && facts.totalBytes == raw.length && facts.declarationHash != 0
                && keccak256(assemblySchemas.documentBytes(id)) == keccak256(raw)
                && keccak256(assemblyStore.readChunk(keccak256(raw))) == keccak256(raw),
            "exact VIEW producer definition and complete registered bytes"
        );
    }
}
