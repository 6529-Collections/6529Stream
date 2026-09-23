// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ViewReviewCompositionFixture.sol";
import {
    StreamFinalityViewPreservationReferenceReadsV1 as ReferenceReads
} from "../../../smart-contracts/domains/finality/StreamFinalityViewPreservationReferenceReadsV1.sol";

interface ViewReviewMutationVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
    function clearMockedCalls() external;
}

contract StreamFinalityViewSanctionReviewCompositionV1Test is ViewReviewCompositionFixture {
    ViewReviewMutationVm private constant mutation =
        ViewReviewMutationVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testProfileThreeKeepsEveryRepeatedPngOccurrenceAndLiteralResult() public view {
        IStreamFinalitySanctionReview.ReviewFacts memory got = consumer.review(statement);
        bytes32[] memory media = new bytes32[](1);
        media[0] = mediaObject.contentHash;
        bytes32[] memory pngs = new bytes32[](2);
        pngs[0] = pngHash;
        pngs[1] = pngHash;
        require(
            keccak256(abi.encode(got))
                == keccak256(
                    abi.encode(
                        IStreamFinalitySanctionReview.ReviewFacts(
                            1, 3, statement.contentRoot, media, pngs
                        )
                    )
                )
        );
        require(
            got.referenceRenderContentHashes.length == 2 && pngHash != pngDigest
                && pngHash != pngObject,
            "actual Keccak, repetition not deduplicated"
        );
    }

    function testAbsentMediaRetainsOriginalMultiCaptureProfileTwo() public {
        _prepare("", 2);
        IStreamFinalitySanctionReview.ReviewFacts memory got = consumer.review(statement);
        require(
            got.profile == 2 && got.mediaContentHashes.length == 0
                && got.referenceRenderContentHashes.length == 2
        );
        require(
            got.referenceRenderContentHashes[0] == pngHash
                && got.referenceRenderContentHashes[1] == pngHash
        );
    }

    function testCurrentAndOriginalReferenceMismatchCannotChangeReviewedObjects() public {
        bytes32 original = _reviewHash();
        for (uint256 i; i < 4; ++i) {
            R.Receipt memory bad = abi.decode(abi.encode(receipt), (R.Receipt));
            if (i == 0) bad.observation.payloadHash = keccak256("other payload");
            if (i == 1) bad.observation.snapshotRecordHash = keccak256("other snapshot");
            if (i == 2) bad.observation.profileHash = keccak256("other reference profile");
            if (i == 3) bad.observation.recordHash = keccak256("other current record");
            ViewConfigurationBoundary(selected.referencePublication)
                .set(abi.encodeCall(Reference.currentReference, (statement.scope)), abi.encode(bad));
            _reviewRefuses(abi.encodeWithSelector(Review.NativeReviewSource.selector));
            ViewConfigurationBoundary(selected.referencePublication)
                .set(
                    abi.encodeCall(Reference.currentReference, (statement.scope)),
                    abi.encode(receipt)
                );
            require(_reviewHash() == original);
        }
        R.Publication memory other = abi.decode(abi.encode(publication), (R.Publication));
        other.observation.captures[0].objectHash = keccak256("other original object");
        ViewConfigurationBoundary(selected.referencePublication)
            .set(
                abi.encodeCall(Reference.referenceRecord, (receipt.observation.recordHash)),
                abi.encode(other, receipt)
            );
        _reviewRefuses(
            abi.encodeWithSelector(ReferenceReads.InvalidViewPreservationReferenceEvidence.selector)
        );
        ViewConfigurationBoundary(selected.referencePublication)
            .set(
                abi.encodeCall(Reference.referenceRecord, (receipt.observation.recordHash)),
                abi.encode(publication, receipt)
            );
        require(_reviewHash() == original);
    }

    function testIndependentlyResealedBadCaptureStillRejectsAtActualPngJoin() public {
        bytes32 original = _reviewHash();
        // Reseal the canonical typed record so this reaches the production _capture checks.
        publication.observation.captures[1].repeatCaptureSha256[1] =
            keccak256("different execution");
        _saveReference();
        _reviewRefuses(abi.encodeWithSelector(Review.NativeReviewSource.selector));
        publication.observation.captures[1].repeatCaptureSha256[1] = pngDigest;
        _saveReference();
        require(_reviewHash() == original);
    }

    function testActualActiveCatalogueRetirementRefusesAndSnapshotRestoreRetriesExactRequest()
        public
    {
        bytes memory request = abi.encodeCall(consumer.review, (statement));
        bytes32 original = _reviewHash();
        uint256 snapshot = vm.snapshotState();
        (bytes32 s, bytes32 o, bytes32 n) =
            schemas.statusTransition(PROFILE_ID, IStreamSchemaRegistry.DocumentStatus.DEPRECATED);
        gov.run(
            address(schemas),
            abi.encodeCall(
                schemas.setDocumentStatus,
                (PROFILE_ID, IStreamSchemaRegistry.DocumentStatus.DEPRECATED)
            ),
            s,
            o,
            n
        );
        _reviewRefuses(abi.encodeWithSelector(Profile.ViewSanctionProfileUnavailable.selector));
        require(
            keccak256(schemas.documentBytes(PROFILE_ID)) == keccak256(Profile.document()),
            "retired historical bytes retained"
        );
        require(
            vm.revertToState(snapshot), "test-only rollback, production retirement is irreversible"
        );
        (bool ok, bytes memory result) = address(consumer).staticcall(request);
        require(ok && keccak256(result) == original);
    }

    function testActualStoreCarrierCorruptionAndExactRestoration() public {
        bytes32 original = _reviewHash();
        bytes memory expected = Profile.document();
        (address carrier,) = store.chunk(keccak256(expected));
        bytes memory code = carrier.code;
        bytes memory changed = abi.encodePacked(code);
        changed[changed.length - 1] = bytes1(uint8(changed[changed.length - 1]) ^ 1);
        vm.etch(carrier, changed);
        _reviewRefuses(bytes(""));
        vm.etch(carrier, code);
        require(_reviewHash() == original, "same original schema and carrier restored");
    }

    function testCatalogueProfileFactsRejectCanonicalButWrongInterpretationsAndRestore() public {
        bytes32 original = _reviewHash();
        IStreamSchemaDocumentFacts.DocumentFacts memory f = schemas.documentFacts(PROFILE_ID);
        for (uint256 i; i < 5; ++i) {
            IStreamSchemaDocumentFacts.DocumentFacts memory bad =
                abi.decode(abi.encode(f), (IStreamSchemaDocumentFacts.DocumentFacts));
            if (i == 0) bad.kind = IStreamSchemaRegistry.DocumentKind.SCHEMA;
            if (i == 1) bad.canonicalizationId = keccak256("other profile");
            if (i == 2) bad.contentHash = keccak256(OriginalProfile.document());
            if (i == 3) bad.supersedesId = keccak256("reinterpreted base");
            if (i == 4) bad.declarationHash = 0;
            // Explicit adversarial return boundary on a genuine Registry; no production state edit.
            mutation.mockCall(
                address(schemas),
                abi.encodeCall(IStreamSchemaDocumentFacts.documentFacts, (PROFILE_ID)),
                abi.encode(bad)
            );
            _reviewRefuses(abi.encodeWithSelector(Profile.ViewSanctionProfileUnavailable.selector));
            mutation.clearMockedCalls();
            require(_reviewHash() == original);
        }
    }

    function testArchiveCurrentPairFailureAlsoStopsComposedSanctionReview() public {
        bytes32 original = _reviewHash();
        archiveFixture.familyStatus(2);
        _reviewRefuses(abi.encodeWithSelector(T.InventoryRead.selector, address(archive)));
        archiveFixture.familyStatus(1);
        require(_reviewHash() == original);
    }
}
