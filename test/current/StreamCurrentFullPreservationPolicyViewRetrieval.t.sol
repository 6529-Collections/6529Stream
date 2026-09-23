// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentFullPreservationPolicyViewRetrievalFixture.sol";
import {
    IStreamFinalitySanctionReview as VRReview
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalitySanctionReview.sol";

/// @notice Actual nonempty VIEW image/source/Archive/Safe recipe and supplied full-finality continuation.
/// @dev The two default cases execute no fake browser capture. Full sanction/finality needs externally
/// supplied observations of this exact exported source, as in the original empty-image recipe.
contract StreamCurrentFullPreservationPolicyViewRetrievalTest is
    StreamCurrentFullPreservationPolicyViewRetrievalFixture
{
    function _prepareRetrievalSource() private {
        _viewPrepareInputSource();
        _viewPrepareReferenceDefinitions();
        if (viewImageCoverage.coverageHash == 0) _viewPrepareImageArchive();
        _viewRequireCurrentPublication();
    }

    function exportViewRetrievalSource(string memory directory, bytes20 sourceRevision)
        external
        returns (bytes32 sourceHash, bytes32 exportSHA256, bytes32 retrievalSHA256)
    {
        require(sourceRevision != bytes20(0), "explicit source revision provenance");
        _prepareRetrievalSource();
        (sourceHash, exportSHA256) = _viewExportSource(directory, sourceRevision);
        ViewCeremonyFileVm files =
            ViewCeremonyFileVm(address(uint160(uint256(keccak256("hevm cheat code")))));
        bytes memory png = _viewRetrievalPNG();
        string memory file = string.concat(directory, "/adopted-image.png");
        require(!files.exists(file), "fresh actual adopted image export");
        files.writeFileBinary(file, png);
        require(
            keccak256(files.readFileBinary(file)) == viewImageObject.contentHash
                && sha256(files.readFileBinary(file)) == viewImageObject.sha256Digest,
            "export includes exact full archived image bytes"
        );
        bytes memory envelope = _retrievalExportEnvelope(exportSHA256);
        string memory completion = string.concat(directory, "/retrieval-source.abi");
        require(!files.exists(completion), "fresh retrieval completion manifest");
        files.writeFileBinary(completion, envelope); // Last: complete source plus full image and pair.
        retrievalSHA256 = sha256(envelope);
        require(
            sha256(files.readFileBinary(completion)) == retrievalSHA256,
            "exact retrieval completion manifest readback"
        );
    }

    function _retrievalExportEnvelope(bytes32 sourceSHA256) private view returns (bytes memory) {
        return abi.encode(
            keccak256("6529STREAM_VIEW_RETRIEVAL_ACTUAL_FIXTURE_EXPORT_V1"),
            sourceSHA256,
            block.chainid,
            address(this),
            address(viewRetrieval),
            address(viewRetrieval).codehash,
            viewRetrieval.configuration(),
            fullPolicyViewScope,
            fullPolicyViewAdoption,
            fullPolicyViewPayload,
            VIEW_RETRIEVAL_ORIGIN,
            VIEW_RETRIEVAL_MIRROR,
            viewImageObject,
            viewImageCoverage,
            viewImageInstitutionalFamily,
            address(assemblyRoot),
            _viewRetrievalPNG()
        );
    }

    function runSuppliedViewRetrievalFinalityFiles(
        string memory sourceExportFile,
        bytes32 expectedExportSHA256,
        bytes20 expectedSourceRevision,
        string memory retrievalSourceFile,
        bytes32 expectedRetrievalSHA256,
        string memory environmentFile,
        string memory browserFile,
        string memory capturesFile,
        string memory packageMembersDirectory
    ) external returns (bytes32 referenceRecord, bytes32 sanctionRecord, bytes32 finalityRecord) {
        require(
            expectedExportSHA256 != 0 && expectedSourceRevision != bytes20(0)
                && expectedRetrievalSHA256 != 0,
            "explicit pinned source export required"
        );
        _prepareRetrievalSource();
        (string memory environmentJSON, string memory browserJSON, string memory capturesJSON) = _viewLoadSuppliedFiles(
            sourceExportFile,
            expectedExportSHA256,
            expectedSourceRevision,
            environmentFile,
            browserFile,
            capturesFile,
            packageMembersDirectory
        );
        ViewCeremonyFileVm files =
            ViewCeremonyFileVm(address(uint160(uint256(keccak256("hevm cheat code")))));
        bytes memory recorded = files.readFileBinary(retrievalSourceFile);
        bytes memory actual = _retrievalExportEnvelope(expectedExportSHA256);
        require(
            sha256(recorded) == expectedRetrievalSHA256 && recorded.length == actual.length
                && keccak256(recorded) == keccak256(actual),
            "caller-pinned complete actual source/image/Archive/Safe envelope"
        );
        _viewRevokeAndReprepareImage();
        viewPackageMembersDirectory = packageMembersDirectory;
        _viewPublishReference(environmentJSON, browserJSON, capturesJSON);
        VRInventory.Item[][] memory rows = _viewMaterializeInventory();
        _viewCoverCompleteBundle(rows);
        require(
            viewImagePreparedCount == 1 && viewImageCoveredCount == 1,
            "one actual full image obligation and exact retrieval occurrence"
        );
        _viewRepairImageFixityAndRefresh();
        _viewPerformSanctionAndFinality();
        VRReview.ReviewFacts memory reviewed = VRReview(address(assemblyProvider))
            .requireSanctionReviewFacts(fullPolicyViewScope, viewFinalityManifestHash);
        require(
            reviewed.schemaVersion == 1 && reviewed.profile == 3
                && reviewed.contentRoot == assemblyViewOriginalContentRoot
                && reviewed.mediaContentHashes.length == 1
                && reviewed.mediaContentHashes[0] == viewImageObject.contentHash
                && reviewed.referenceRenderContentHashes.length != 0
                && assemblyViewReferenceRecord != 0 && viewSanctionRecord != 0
                && viewFinalityRecord != 0,
            "actual finality reviewed the independently archived image, never its URI hash"
        );
        require(
            reviewed.referenceRenderContentHashes.length
                == viewReferencePublication.observation.captures.length,
            "all ordered first/last reference occurrences remain present"
        );
        for (uint256 i; i < reviewed.referenceRenderContentHashes.length; ++i) {
            VRExternal.Coverage memory capture = assemblyExternal.coverage(
                viewReferencePublication.observation.captures[i].coverageHash
            );
            require(
                capture.objectHash == viewReferencePublication.observation.captures[i].objectHash
                    && reviewed.referenceRenderContentHashes[i] == capture.contentHash,
                "independent original PNG content hash for every reference occurrence"
            );
        }
        return (assemblyViewReferenceRecord, viewSanctionRecord, viewFinalityRecord);
    }

    function testActualAdoptedImageAndInstitutionalSafeWitnessRevocationReprepare() external {
        _prepareRetrievalSource();
        _viewRevokeAndReprepareImage();
        require(
            viewRetrieval.revoked(viewImageRevokedPredecessor)
                && !viewRetrieval.revoked(viewImageWitness)
                && viewRetrieval.revocationEpoch(fullPolicyViewScope) == 1
                && viewRetrieval.nonceUsed(
                    keccak256(abi.encode(VR.NONCE, address(assemblyRoot), uint256(1)))
                )
                && viewRetrieval.nonceUsed(
                    keccak256(abi.encode(VR.NONCE, address(assemblyRoot), uint256(2)))
                ),
            "actual Safe and source: immutable revocation, distinct consumed nonces and new current evidence"
        );
        _viewRequireImageWitness(viewImageWitness);
        _viewRequireRevokedImage(viewImageRevokedPredecessor);
        require(
            viewImageObject.contentHash == keccak256(_viewRetrievalPNG())
                && viewImageObject.contentHash != keccak256(bytes(VIEW_RETRIEVAL_ORIGIN))
                && assemblyViewReferenceRecord == 0 && viewSanctionRecord == 0
                && viewFinalityRecord == 0,
            "actual attribution closure alone cannot fabricate browser reference or finality"
        );
    }

    function testActualImageArchiveFailureThenRepairPreservesSameSignedRequest() external {
        _prepareRetrievalSource();
        VR.Request memory request = _viewImageRequest(9);
        (VR.Observation memory observed, bytes memory signature) = _viewPrepareImageRequest(request);
        bytes32 nonceKey = keccak256(abi.encode(VR.NONCE, address(assemblyRoot), uint256(9)));
        bytes32 failed = _assemblyExternalFixity(viewImageCoverage.secondReceiptHash, 2, 0);
        (bool ok,) =
            address(viewRetrieval).call(abi.encodeCall(viewRetrieval.publish, (request, signature)));
        require(
            !ok && !viewRetrieval.nonceUsed(nonceKey)
                && viewRetrieval.revocationEpoch(fullPolicyViewScope) == 0,
            "original archive failure refuses before fresh nonce or scope epoch changes"
        );
        (VRExternal.Fixity memory failure,) = assemblyExternal.fixity(failed);
        _assemblyExternalFixity(viewImageCoverage.secondReceiptHash, 1, failure.reportHash);
        viewImageWitness = viewRetrieval.publish(request, signature);
        require(
            viewRetrieval.nonceUsed(nonceKey)
                && keccak256(viewRetrieval.encoded(viewImageWitness))
                    == keccak256(abi.encode(observed, signature)),
            "identical original request and Safe signature succeed after same-pair repair"
        );
        _viewRequireImageWitness(viewImageWitness);
    }
}
