// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ViewReviewCompositionFixture.sol";

contract StreamFinalityViewMediaReviewCompositionV1Test is ViewReviewCompositionFixture {
    function testPresentImageReturnsActualFullArchiveContentNotUriOrSha() public view {
        bytes32[] memory got = consumer.media(statement);
        require(
            got.length == 1
                && got[0]
                    == bytes32(0x68c77c4fc0ab6e7bec76afe7f82d84d0112fd1cacbd8bcfe26a18d2849f2d473)
        );
        require(
            got[0] == mediaObject.contentHash && got[0] != mediaObject.sha256Digest
                && got[0] != keccak256(bytes(IMAGE))
        );
        require(
            rows[5].byteSize == 0 && admitted.externalOriginal.byteSize == 253440410,
            "CID length remains unknown until original archive supplies full size"
        );
        require(
            admitted.proof.backend == 1
                && admitted.externalOriginal.coverageHash == proof.coverageHash
        );
    }

    function testAbsentImageNeedsNoInventedArchiveOccurrence() public {
        _prepare("", 1);
        // No image admission response is installed for this new plan. A mistaken read refuses.
        require(rows[5].kind == T.Kind.ABSENT && consumer.media(statement).length == 0);
        IStreamFinalitySanctionReview.ReviewFacts memory got = consumer.review(statement);
        require(
            got.profile == 1 && got.mediaContentHashes.length == 0
                && got.referenceRenderContentHashes.length == 1
                && got.referenceRenderContentHashes[0] == pngHash
        );
    }

    function testWrongStageAndOrdinalCannotSelectSimilarArtworkSegment() public {
        bytes32 original = _mediaHash();
        for (uint256 i; i < 3; ++i) {
            T.Segment memory bad = artworkSegment;
            if (i == 0) {
                bad.sourceWitnessHash = keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_PRESERVATION_OUTPUT_INVENTORY_SOURCE_V1"),
                        context.adoptionRecord,
                        context.checkpointHash,
                        context.sourceContextHash,
                        uint16(7),
                        uint64(0),
                        uint64(7)
                    )
                );
            }
            if (i == 1) {
                bad.key = keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_SEGMENT_V1"),
                        evidence.inventory.planId,
                        uint64(0)
                    )
                );
            }
            if (i == 2) bad.itemCount = 6;
            _segment(1, bad);
            _mediaRefuses(abi.encodeWithSelector(Media.InvalidViewMediaReview.selector));
            _segment(1, artworkSegment);
            require(_mediaHash() == original, "exact stage restores");
        }
    }

    function testWrongAdmittedOrdinalAndEveryRowCoordinateRefuseThenRestore() public {
        bytes32 original = _mediaHash();
        for (uint256 i; i < 5; ++i) {
            T.Item memory bad = abi.decode(abi.encode(rows[5]), (T.Item));
            if (i == 0) bad = rows[4];
            if (i == 1) bad.sourceRecord = keccak256("other declaration");
            if (i == 2) bad.sourceIndex = 1;
            if (i == 3) bad.digest = abi.encodePacked(bytes32(uint256(1)));
            if (i == 4) bad.byteSize = 1;
            _admitted(bad, admitted);
            _mediaRefuses(abi.encodeWithSelector(Media.InvalidViewMediaReview.selector));
            _admitted(rows[5], admitted);
            require(_mediaHash() == original);
        }
    }

    function testCanonicalOtherCidCannotBorrowOriginalArchiveObject() public {
        bytes32 original = _mediaHash();
        skipAdmission = true;
        _prepare(OTHER_IMAGE, 2);
        // Artwork, canonical source/context, segment and admitted item all agree on the new CID.
        // Only the genuine original Archive SHA correspondence is inconsistent.
        _mediaRefuses(abi.encodeWithSelector(T.InvalidInventoryItem.selector));
        skipAdmission = false;
        _prepare(IMAGE, 2);
        require(_mediaHash() == original, "original complete request restored");
    }

    function testActualArchiveCurrentPairStaleThenExactSameRequestRetry() public {
        bytes memory request = abi.encodeCall(consumer.media, (statement));
        bytes32 original = _mediaHash();
        bytes32 saved = keccak256(abi.encode(admitted));
        archiveFixture.familyStatus(2);
        _mediaRefuses(abi.encodeWithSelector(T.InventoryRead.selector, address(archive)));
        archiveFixture.familyStatus(1);
        (bool ok, bytes memory result) = address(consumer).staticcall(request);
        require(
            ok && keccak256(result) == original,
            "byte-identical request and result after genuine archive restore"
        );
        require(keccak256(abi.encode(admitted)) == saved, "no replacement saved coverage");
    }

    function testSavedAdmissionCannotReplaceOriginalCurrentObjectFacts() public {
        bytes32 original = _mediaHash();
        B.Admission memory bad = abi.decode(abi.encode(admitted), (B.Admission));
        bad.externalOriginal.contentHash = keccak256("invented image");
        _admitted(rows[5], bad);
        _mediaRefuses(abi.encodeWithSelector(Media.InvalidViewMediaReview.selector));
        _admitted(rows[5], admitted);
        require(_mediaHash() == original);
    }
}
