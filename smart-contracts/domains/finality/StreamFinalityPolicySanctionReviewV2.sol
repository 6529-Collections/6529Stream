// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamFinalityNativeProviderReads.sol";
import "./StreamFinalityPolicyInputManifestReadsV2.sol";
import {
    StreamFinalityPolicyReferenceReadsV2 as ReferenceReads
} from "./StreamFinalityPolicyReferenceReadsV2.sol";
import {
    IStreamPolicyReferencePublicationV2 as Reference
} from "../../interfaces/stream/preservation/IStreamPolicyReferencePublicationV2.sol";
import {
    StreamPolicyReferenceTypesV2 as R2
} from "../../interfaces/stream/preservation/StreamPolicyReferenceTypesV2.sol";
import "./StreamFinalityNativeSanctionProfile.sol";
import "../../interfaces/stream/finality/IStreamFinalitySanctionReview.sol";
import "../../interfaces/stream/preservation/IStreamExternalArtifactCoverage.sol";
import "../../interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import "../records/StreamReferenceRenderDefinitions.sol";
import "../records/StreamReferenceModeDefinitions.sol";
import "../../interfaces/stream/preservation/IStreamReferenceModePublication.sol";

/// @notice Ordered original PNG content hashes for the admitted native finality statement.
/// @dev The provider first validates all current inputs and the exact registered manifest.
/// This projection is not a separate readiness gate and accepts no caller-selected object list.
library StreamFinalityPolicySanctionReviewV2 {
    error NativeReviewSource();
    error NativeReviewRead(address target);
    uint256 internal constant MAX_PUBLICATION_BYTES = 1048576;

    function review(
        StreamFinalityNativeProviderReads.Config memory c,
        StreamFinalityPolicyInputManifestTypesV2.Statement memory s
    ) public view returns (IStreamFinalitySanctionReview.ReviewFacts memory result) {
        if (
            c.chainId != block.chainid || s.scope.scopeType != StreamFinalityScopeType.COLLECTION
                || s.scope.collectionId == 0 || s.scope.tokenId != 0 || s.scope.scopeId != 0
                || s.contentRoot == 0 || s.inputs.referenceRenderRecordHash == 0
                || s.inputs.snapshotRecordHash == 0 || s.referenceRenderManifestHash == 0
        ) {
            revert NativeReviewSource();
        }
        _pin(c, 2);
        _pin(c, 9);
        _pin(c, 11);
        _pin(c, 21);
        bytes32 artistId = _artist(c, s.scope.collectionId);
        (StreamReferenceRenderTypes.Publication memory publication, bool exact) = _publication(c, s);
        uint256 count = publication.captures.length;
        if (count == 0 || count > 16) revert NativeReviewSource();
        if (count > 1) {
            StreamFinalityNativeSanctionProfile.requireCurrent(
                c.targets[4], c.codeHashes[4], c.targets[5], c.codeHashes[5], c.readGas
            );
        }
        result.schemaVersion = 1;
        result.profile = count == 1 ? 1 : 2;
        result.contentRoot = s.contentRoot;
        // This native ONCHAIN profile has no separate off-chain media object list.
        result.mediaContentHashes = new bytes32[](0);
        result.referenceRenderContentHashes = new bytes32[](count);
        for (uint256 i; i < count; ++i) {
            result.referenceRenderContentHashes[i] =
                _capture(c, artistId, publication.captures[i], exact);
        }
    }

    function _artist(StreamFinalityNativeProviderReads.Config memory c, uint256 cid)
        private
        view
        returns (bytes32)
    {
        bytes memory raw = StreamFinalityBoundedReads.read(
            c.targets[2],
            abi.encodeCall(IStreamMetadataServingFacts.artistPresentation, (cid)),
            384,
            c.readGas
        );
        IStreamMetadataServingFacts.ArtistPresentation memory p =
            abi.decode(raw, (IStreamMetadataServingFacts.ArtistPresentation));
        if (
            keccak256(raw) != keccak256(abi.encode(p)) || !p.locked || p.artistId == 0
                || p.registry != c.targets[11] || p.registryCodeHash != c.codeHashes[11]
                || p.bindingGeneration == 0 || p.bindingHash == 0 || p.identityRecordHash == 0
                || p.acceptanceRecordHash == 0 || p.snapshotHash == 0
        ) revert NativeReviewSource();
        return p.artistId;
    }

    function _publication(
        StreamFinalityNativeProviderReads.Config memory c,
        StreamFinalityPolicyInputManifestTypesV2.Statement memory s
    ) private view returns (StreamReferenceRenderTypes.Publication memory p, bool exact) {
        bytes memory raw = StreamFinalityBoundedReads.read(
            c.targets[9], abi.encodeCall(Reference.currentReference, (s.scope)), 672, c.readGas
        );
        R2.Receipt memory current = abi.decode(raw, (R2.Receipt));
        if (
            keccak256(raw) != keccak256(abi.encode(current))
                || current.observation.recordHash != s.inputs.referenceRenderRecordHash
                || current.observation.payloadHash != s.referenceRenderManifestHash
                || current.observation.snapshotRecordHash != s.inputs.snapshotRecordHash
                || current.observation.profileHash != s.entropy.referenceProfileHash
        ) revert NativeReviewSource();
        ReferenceReads.Dependencies memory rd;
        uint256[5] memory indexes = [uint256(0), 1, 2, 8, 9];
        for (uint256 i; i < 5; ++i) {
            rd.targets[i] = c.targets[indexes[i]];
            rd.codeHashes[i] = c.codeHashes[indexes[i]];
        }
        rd.chainId = c.chainId;
        rd.readGas = c.readGas;
        rd.sourceGas = c.sourceGas;
        (R2.Publication memory declared, R2.Receipt memory receipt) = ReferenceReads.original(
            rd, s.scope, current.observation.recordHash, current.observation.revision
        );
        if (
            keccak256(abi.encode(receipt)) != keccak256(raw)
                || declared.observation.snapshotRecordHash != s.inputs.snapshotRecordHash
        ) revert NativeReviewSource();
        // Actual provider statement/inventory has already revalidated complete current coverage.
        // This exact original reader independently authenticates the full V2 payload and receipt.
        p = declared.observation;
        exact = true;
    }

    function _capture(
        StreamFinalityNativeProviderReads.Config memory c,
        bytes32 artistId,
        StreamReferenceRenderTypes.Capture memory capture,
        bool exact
    ) private view returns (bytes32) {
        bytes memory raw = StreamFinalityBoundedReads.read(
            c.targets[21],
            abi.encodeCall(IStreamExternalArtifactCoverage.objectIdentity, (capture.objectHash)),
            320,
            c.readGas
        );
        StreamExternalArtifactTypes.ObjectIdentity memory o =
            abi.decode(raw, (StreamExternalArtifactTypes.ObjectIdentity));
        if (
            keccak256(raw) != keccak256(abi.encode(o)) || o.artistId != artistId
                || o.contentHash == 0 || o.sha256Digest == 0 || capture.repeatCaptureSha256[0] == 0
                || capture.repeatCaptureSha256[1] == 0
                || (exact && capture.repeatCaptureSha256[0] != capture.repeatCaptureSha256[1])
                || o.sha256Digest != capture.repeatCaptureSha256[0] || o.arweaveDataRoot == 0
                || o.byteSize == 0 || capture.coverageHash == 0
                || o.canonicalizationId != keccak256("RAW_BYTES")
                || o.schemaId != StreamReferenceRenderDefinitions.PNG_SCHEMA_ID
                || o.formatId != keccak256("IANA:image/png")
                || o.formatCatalogId != StreamReferenceRenderDefinitions.FORMAT_CATALOG_ID
                || o.formatCatalogHash != StreamReferenceRenderDefinitions.FORMAT_CATALOG_HASH
                || capture.objectHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_EXTERNAL_OBJECT_V1"),
                            c.chainId,
                            c.targets[21],
                            c.targets[0],
                            o
                        )
                    )
        ) revert NativeReviewSource();
        return o.contentHash;
    }

    function _pin(StreamFinalityNativeProviderReads.Config memory c, uint256 index) private view {
        if (c.targets[index].code.length == 0 || c.targets[index].codehash != c.codeHashes[index]) {
            revert NativeReviewRead(c.targets[index]);
        }
    }

    function _dynamicRead(address target, bytes memory input, uint256 cap)
        private
        view
        returns (bytes memory result)
    {
        // Inspect bounded returndata before allocating/copying it. No unbounded return bomb.
        uint256 available = gasleft();
        if (available <= 100000 || cap == 0) revert NativeReviewRead(target);
        uint256 forwarded = available - 100000;
        if (cap < forwarded) forwarded = cap;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(forwarded, target, add(input, 32), mload(input), 0, 0)
            size := returndatasize()
        }
        if (!ok || size == 0 || size > MAX_PUBLICATION_BYTES) revert NativeReviewRead(target);
        result = new bytes(size);
        assembly ("memory-safe") { returndatacopy(add(result, 32), 0, size) }
    }
}
