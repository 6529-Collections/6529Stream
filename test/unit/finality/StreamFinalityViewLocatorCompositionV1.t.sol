// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ViewReviewCompositionFixture.sol";
import {
    StreamViewPreservationBundleArchiveCoverageV1
} from "../../../smart-contracts/domains/preservation/StreamViewPreservationBundleArchiveCoverageV1.sol";
import {
    StreamViewPreservationArchiveReadsV1 as Locator
} from "../../../smart-contracts/domains/preservation/StreamViewPreservationArchiveReadsV1.sol";
import {
    StreamViewPreservationMediaCorrespondenceV1 as Image
} from "../../../smart-contracts/domains/preservation/StreamViewPreservationMediaCorrespondenceV1.sol";
import {
    ViewBundleInventoryBoundary,
    ViewBundleEnvironmentBoundary
} from "../preservation/StreamViewPreservationBundleArchiveCoverageV1.t.sol";

contract ViewLocatorProbe {
    function admit(B.Dependencies memory d, bytes32 artist, T.Item memory row, B.Proof memory proof)
        external
        view
        returns (B.Admission memory a, bytes32 observation, bytes32 afterHash)
    {
        (a, observation) = Locator.admit(d, artist, row, proof);
        afterHash = keccak256(abi.encode(row));
    }

    function current(
        B.Dependencies memory d,
        bytes32 artist,
        T.Item memory row,
        B.Admission memory a
    ) external view returns (bytes32) {
        return Locator.current(d, artist, row, a);
    }
}

/// @dev Actual original Archive/receipt/fixity/native and catalog; surrounding VIEW selection
/// and complete source graph are typed. The covered ZIP is opaque bytes, not an image decoder claim.
contract StreamFinalityViewLocatorCompositionV1Test is ViewReviewCompositionFixture {
    string private constant HTTPS =
        "https://institution.example.invalid/objects/sha256/d2eabd7dffeed4f37632e9e8d5a861d7fe5df621d66e62cd43234ecb9a572417";
    string private constant AR = "ar://ElP9Xu-yoWLv6x6Vy7JtbNUKYXxruXflEH6kwLA1QL0";
    string private constant OTHER_AR = "ar://AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE";
    ViewLocatorProbe private locator;

    function setUp() public override {
        super.setUp();
        locator = new ViewLocatorProbe();
    }

    function _row(string memory uri) private view returns (T.Item memory) {
        return Image.item(rows[5].source, rows[5].sourceRecord, uri);
    }

    function _locatorPrepare(string memory uri) private {
        skipAdmission = true;
        _prepare(uri, 2);
        (admitted,) = Locator.admit(bundle, mediaObject.artistId, rows[5], proof);
        _admitted(rows[5], admitted);
    }

    function _refuse(T.Item memory row, B.Proof memory p, bytes memory error) private {
        vm.expectRevert(error);
        locator.admit(bundle, mediaObject.artistId, row, p);
    }

    function testExactSignedHTTPSAndArMatchSameOriginalCompleteArchive() public {
        T.Item memory https = _row(HTTPS);
        T.Item memory ar = _row(AR);
        (B.Admission memory h, bytes32 observation, bytes32 afterHash) =
            locator.admit(bundle, mediaObject.artistId, https, proof);
        (B.Admission memory a, bytes32 arObservation, bytes32 afterAr) =
            locator.admit(bundle, mediaObject.artistId, ar, proof);
        require(
            keccak256(abi.encode(h)) == keccak256(abi.encode(admitted))
                && keccak256(abi.encode(a)) == keccak256(abi.encode(h))
        );
        require(
            observation != 0 && observation == arObservation
                && afterHash == keccak256(abi.encode(https))
                && afterAr == keccak256(abi.encode(ar)),
            "input rows do not alias materialized digest"
        );
        require(
            h.externalOriginal.contentHash == mediaObject.contentHash
                && h.externalOriginal.byteSize == 253440410
        );
        (E.Receipt memory receiptHTTPS, bytes memory signedURI,) =
            archive.receipt(h.externalOriginal.secondReceiptHash);
        require(
            keccak256(signedURI) == keccak256(bytes(HTTPS))
                && receiptHTTPS.storageIdentifierHash == keccak256(bytes(HTTPS))
        );
        (E.Receipt memory receiptAr, bytes memory transaction,) =
            archive.receipt(h.externalOriginal.firstReceiptHash);
        require(
            keccak256(transaction)
                == keccak256(
                    abi.encodePacked(
                        bytes32(0x1253fd5eefb2a162efeb1e95cbb26d6cd50a617c6bb977e5107ea4c0b03540bd)
                    )
                )
        );
        require(receiptAr.proofRecordHash == h.externalOriginal.checkpointHash);
        require(
            https.digest.length == 0 && ar.digest.length == 0
                && h.externalOriginal.contentHash != keccak256(bytes(HTTPS))
                && h.externalOriginal.contentHash != abi.decode(transaction, (bytes32))
        );
    }

    function testCurrentLocatorRechecksExactReceiptNotOnlySavedPair() public {
        T.Item memory row = _row(HTTPS);
        (B.Admission memory saved, bytes32 observation,) =
            locator.admit(bundle, mediaObject.artistId, row, proof);
        require(locator.current(bundle, mediaObject.artistId, row, saved) == observation);
        T.Item memory wrong = _row("https://origin.example.invalid/the-same-object");
        vm.expectRevert(abi.encodeWithSelector(Locator.InvalidViewLocatorCorrespondence.selector));
        locator.current(bundle, mediaObject.artistId, wrong, saved);
        T.Item memory otherAr = _row(OTHER_AR);
        vm.expectRevert(abi.encodeWithSelector(Locator.InvalidViewLocatorCorrespondence.selector));
        locator.current(bundle, mediaObject.artistId, otherAr, saved);
        require(locator.current(bundle, mediaObject.artistId, row, saved) == observation);
    }

    function testEveryLocatorRowCoordinateAndOnchainSubstitutionRefuses() public {
        T.Item memory exact = _row(HTTPS);
        for (uint256 i; i < 15; ++i) {
            T.Item memory bad = abi.decode(abi.encode(exact), (T.Item));
            if (i == 0) bad.kind = T.Kind.EXTERNAL_OBJECT;
            if (i == 1) bad.sourceIndex = 1;
            if (i == 2) bad.algorithm = 1;
            if (i == 3) bad.canonicalizationId = keccak256("RFC8785_JCS");
            if (i == 4) bad.digest = abi.encodePacked(mediaObject.contentHash);
            if (i == 5) bad.byteSize = mediaObject.byteSize;
            if (i == 6) bad.schemaId = bytes32(uint256(1));
            if (i == 7) bad.formatId = bytes32(uint256(1));
            if (i == 8) bad.catalogId = bytes32(uint256(1));
            if (i == 9) bad.catalogHash = bytes32(uint256(1));
            if (i == 10) bad.objectHash = proof.objectHash;
            if (i == 11) bad.originalCoverageHash = proof.coverageHash;
            if (i == 12) bad.provenanceHash = keccak256("caller selected observation");
            if (i == 13) bad.source = address(123);
            if (i == 14) bad.sourceRecord = bytes32(uint256(456));
            _refuse(
                bad,
                proof,
                abi.encodeWithSelector(Locator.InvalidViewLocatorCorrespondence.selector)
            );
        }
        _refuse(
            exact,
            B.Proof(2, proof.coverageHash, proof.objectHash),
            abi.encodeWithSelector(Locator.InvalidViewLocatorCorrespondence.selector)
        );
        locator.admit(bundle, mediaObject.artistId, exact, proof);
    }

    function testUnrelatedObjectAndExactLocatorMismatchCannotBorrowCoverage() public {
        E.ObjectIdentity memory wrong = mediaObject;
        wrong.contentHash = keccak256("different bytes");
        bytes32 otherObject = archive.recordObject(wrong);
        _refuse(
            _row(HTTPS),
            B.Proof(1, proof.coverageHash, otherObject),
            abi.encodeWithSelector(T.InvalidInventoryItem.selector)
        );
        _refuse(
            _row(string.concat(HTTPS, "?mirror=1")),
            proof,
            abi.encodeWithSelector(Locator.InvalidViewLocatorCorrespondence.selector)
        );
        _refuse(
            _row(OTHER_AR),
            proof,
            abi.encodeWithSelector(Locator.InvalidViewLocatorCorrespondence.selector)
        );
        locator.admit(bundle, mediaObject.artistId, _row(HTTPS), proof);
    }

    function testArchiveRuntimeAndChainPinRefuseBeforeObjectThenRestore() public {
        T.Item memory exact = _row(HTTPS);
        B.Dependencies memory wrong = abi.decode(abi.encode(bundle), (B.Dependencies));
        wrong.codeHashes[4] = bytes32(uint256(1));
        vm.expectRevert(abi.encodeWithSelector(T.InventoryRead.selector, address(archive)));
        locator.admit(wrong, mediaObject.artistId, exact, proof);
        wrong = abi.decode(abi.encode(bundle), (B.Dependencies));
        wrong.chainId += 1;
        vm.expectRevert(abi.encodeWithSelector(T.InventorySourceChanged.selector));
        locator.admit(wrong, mediaObject.artistId, exact, proof);
        locator.admit(bundle, mediaObject.artistId, exact, proof);
    }

    function testActualArchiveStaleRestoresSameLocatorCurrentAndMediaRequest() public {
        _locatorPrepare(HTTPS);
        bytes memory request = abi.encodeCall(consumer.review, (statement));
        bytes32 original = _reviewHash();
        archiveFixture.familyStatus(2);
        vm.expectRevert(abi.encodeWithSelector(T.InventoryRead.selector, address(archive)));
        locator.current(bundle, mediaObject.artistId, rows[5], admitted);
        _reviewRefuses(abi.encodeWithSelector(T.InventoryRead.selector, address(archive)));
        archiveFixture.familyStatus(1);
        locator.current(bundle, mediaObject.artistId, rows[5], admitted);
        (bool ok, bytes memory result) = address(consumer).staticcall(request);
        require(
            ok && keccak256(result) == original,
            "same request restores after genuine signed-family status action"
        );
    }

    function testHTTPSAndArComposeIntoActualMediaAndRepeatedPNGReview() public {
        for (uint256 i; i < 2; ++i) {
            _locatorPrepare(i == 0 ? HTTPS : AR);
            bytes32[] memory values = consumer.media(statement);
            require(values.length == 1 && values[0] == mediaObject.contentHash);
            IStreamFinalitySanctionReview.ReviewFacts memory actual = consumer.review(statement);
            require(
                actual.profile == 3 && actual.mediaContentHashes.length == 1
                    && actual.mediaContentHashes[0] == mediaObject.contentHash
            );
            require(
                actual.referenceRenderContentHashes.length == 2
                    && actual.referenceRenderContentHashes[0] == pngHash
                    && actual.referenceRenderContentHashes[1] == pngHash
            );
        }
    }

    function testRawCidAndAbsentRetainLiteralOriginalAdmissions() public view {
        (B.Admission memory old, bytes32 oldObservation) =
            Archive.admit(bundle, mediaObject.artistId, rows[5], proof);
        (B.Admission memory actual, bytes32 actualObservation,) =
            locator.admit(bundle, mediaObject.artistId, rows[5], proof);
        require(
            keccak256(abi.encode(old)) == keccak256(abi.encode(actual))
                && oldObservation == actualObservation
        );
        T.Item memory empty = Image.item(rows[5].source, rows[5].sourceRecord, "");
        (old, oldObservation) = Archive.admit(bundle, mediaObject.artistId, empty, B.Proof(0, 0, 0));
        (actual, actualObservation,) =
            locator.admit(bundle, mediaObject.artistId, empty, B.Proof(0, 0, 0));
        require(
            keccak256(abi.encode(old)) == keccak256(abi.encode(actual))
                && oldObservation == actualObservation
        );
    }

    function testActualViewBundleCoverRefreshAndFullCurrentUseLocatorChecks() public {
        ViewBundleEnvironmentBoundary env = new ViewBundleEnvironmentBoundary();
        ViewBundleInventoryBoundary inv = new ViewBundleInventoryBoundary(
            bundle.targets[0], bundle.targets[1], address(env), address(archive)
        );
        B.Dependencies memory d = abi.decode(abi.encode(bundle), (B.Dependencies));
        d.targets[2] = address(inv);
        d.codeHashes[2] = address(inv).codehash;
        d.targets[3] = address(env);
        d.codeHashes[3] = address(env).codehash;
        StreamViewPreservationBundleArchiveCoverageV1 actual =
            new StreamViewPreservationBundleArchiveCoverageV1(d);
        bytes32 id = keccak256("complete two-locator VIEW archive fixture");
        T.Item[] memory items = new T.Item[](2);
        items[0] = _row(HTTPS);
        items[1] = _row(AR);
        T.Segment[] memory segments = new T.Segment[](1);
        segments[0] = Chains.segmentInMemory(
            keccak256("exact ordered locators"), keccak256("typed source witness"), items
        );
        V.Evidence memory e;
        e.scope = statement.scope;
        e.inventory.planId = id;
        e.inventory.collectionId = e.scope.collectionId;
        e.inventory.scopeSubject =
            StreamMetadataSubjects.scopeSubject(d.chainId, d.targets[0], e.scope);
        e.inventory.artistId = mediaObject.artistId;
        e.inventory.sourceContextHash = keccak256("typed full current source");
        e.inventory.tokenInventoryHash = keccak256("complete selected tokens");
        e.inventory.tokenCount = 1;
        e.inventory.segmentCount = 1;
        e.inventory.itemCount = 2;
        e.inventory.segmentChainHash = Chains.append(0, 0, segments[0]);
        e.inventory.renderCriticalEvidenceHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_EVIDENCE_V1"),
                d.chainId,
                address(inv),
                inv.dependencyHash(),
                e
            )
        );
        inv.configure(e, segments);
        actual.beginCoverage(id);
        bytes32 next = Chains.link(segments[0].key, 2, 1, items[1], 0);
        actual.coverNext(id, items[0], next, proof);
        B.Proof memory bad = B.Proof(2, proof.coverageHash, proof.objectHash);
        vm.expectRevert(abi.encodeWithSelector(Locator.InvalidViewLocatorCorrespondence.selector));
        actual.coverNext(id, items[1], 0, bad);
        require(actual.progress(id).itemCount == 1, "late bad proof rolls back progress");
        actual.coverNext(id, items[1], 0, proof);
        V.BundleEvidence memory done =
            actual.requireCoverage(e.scope, id, e.inventory.renderCriticalEvidenceHash);
        require(
            actual.requireFullCurrentCoverage(id).coverage.bundleCoverageHash
                == done.coverage.bundleCoverageHash
        );
        (T.Item memory retained, B.Admission memory saved) = actual.admittedItem(id, 0);
        require(
            keccak256(abi.encode(retained)) == keccak256(abi.encode(items[0]))
                && retained.algorithm == 0 && retained.digest.length == 0
        );
        require(saved.externalOriginal.contentHash == mediaObject.contentHash);
        env.advance();
        bytes32 refreshId = actual.beginRefresh(id);
        actual.refreshNext(id, 0);
        actual.refreshNext(id, 1);
        require(actual.refresh(refreshId).complete);
        require(
            actual.requireCoverage(e.scope, id, e.inventory.renderCriticalEvidenceHash).coverage
                .bundleCoverageHash == done.coverage.bundleCoverageHash
        );
        archiveFixture.familyStatus(2);
        vm.expectRevert(abi.encodeWithSelector(T.InventoryRead.selector, address(archive)));
        actual.requireFullCurrentCoverage(id);
        archiveFixture.familyStatus(1);
        require(
            actual.requireFullCurrentCoverage(id).coverage.bundleCoverageHash
                == done.coverage.bundleCoverageHash
        );
    }
}
