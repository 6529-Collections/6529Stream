// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ViewRetrievalWitnessFixture.sol";
import {
    StreamSnapshotManifestBytes as ManifestBytes
} from "../../../smart-contracts/domains/records/StreamSnapshotManifestBytes.sol";

contract StreamViewRetrievalWitnessV1Test is ViewRetrievalWitnessFixture {
    function setUp() public {
        _setUpRetrieval();
    }

    function testActualArchiveStoreSignatureLiteralReceiptAndEvent() public {
        T.Request memory q = _request(7);
        (T.Observation memory o, bytes memory sig) = _prepared(q);
        bytes32 digest = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_RETRIEVAL_OBSERVATION_V1"),
                configuration.chainId,
                address(witness),
                keccak256(
                    abi.encode(keccak256("6529STREAM_VIEW_ATTRIBUTED_RETRIEVAL_V1"), configuration)
                ),
                o
            )
        );
        require(
            o.source.artistId == object.artistId
                && o.source.artistPresentationHash
                    == keccak256(abi.encode(router.artistPresentation(scope.collectionId)))
        );
        bytes memory payload = abi.encode(o, sig);
        T.Receipt memory expected;
        expected.sourceKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_RETRIEVAL_SOURCE_V1"),
                scope,
                address(core),
                address(router),
                o.source.adoptionRecord,
                o.source.adoptionSourceHash,
                o.source.declaration,
                o.source.declarationRecord,
                o.source.payloadHash,
                ORIGIN,
                o.source.artistId,
                o.source.artistPresentationHash
            )
        );
        expected.observationHash = digest;
        expected.objectHash = objectHash;
        expected.coverageHash = completeCoverage;
        expected.writer = safeVm.addr(SECOND_AGENT);
        expected.recordedAt = uint64(block.timestamp);
        expected.payloadHash = keccak256(payload);
        expected.payloadBytes = uint32(payload.length);
        bytes32 hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_RETRIEVAL_RECORD_V1"),
                configuration.chainId,
                address(witness),
                witness.configurationHash(),
                expected
            )
        );
        expected.recordHash = hash;
        rv.recordLogs();
        require(witness.publish(q, sig) == hash);
        RetrievalVm.Log[] memory logs = rv.getRecordedLogs();
        require(logs.length == 1 && logs[0].emitter == address(witness));
        require(
            logs[0].topics[0]
                    == keccak256(
                        "ViewRetrievalRecorded(bytes32,bytes32,address,(bytes32,bytes32,bytes32,bytes32,bytes32,address,uint64,bytes32,uint32))"
                    ) && logs[0].topics[1] == hash && logs[0].topics[2] == expected.sourceKey
                && logs[0].topics[3] == bytes32(uint256(uint160(expected.writer)))
                && keccak256(logs[0].data) == keccak256(abi.encode(expected))
        );
        (T.Receipt memory actual, B.Admission memory admission) = witness.requireCurrent(hash);
        require(
            keccak256(abi.encode(actual)) == keccak256(abi.encode(expected))
                && admission.proof.objectHash == objectHash
                && admission.proof.coverageHash == completeCoverage
        );
        require(
            keccak256(witness.encoded(hash)) == keccak256(payload) && witness.nonceUsed(_key(7))
        );
        require(
            keccak256(abi.encode(o.object)) == keccak256(abi.encode(object))
                && o.coverage.firstReceiptHash == firstReceipt
                && o.coverage.secondReceiptHash == secondReceipt && o.writer == expected.writer
        );
    }

    function testWrongSignerDomainAndReplayLeaveNonceUsableUntilExactPublish() public {
        T.Request memory q = _request(9);
        (T.Observation memory o, bytes memory sig) = _prepared(q);
        bytes32 digest = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_RETRIEVAL_OBSERVATION_V1"),
                configuration.chainId,
                address(1),
                witness.configurationHash(),
                o
            )
        );
        bytes memory wrong = _sign(SECOND_AGENT, digest);
        rv.expectRevert(
            abi.encodeWithSelector(A.InvalidArchivalSignature.selector, safeVm.addr(SECOND_AGENT))
        );
        witness.publish(q, wrong);
        require(!witness.nonceUsed(_key(9)));
        (, digest) = witness.prepare(q);
        wrong = _sign(OBSERVER_A, digest);
        rv.expectRevert(
            abi.encodeWithSelector(A.InvalidArchivalSignature.selector, safeVm.addr(SECOND_AGENT))
        );
        witness.publish(q, wrong);
        bytes32 h = witness.publish(q, sig);
        require(h != 0);
        rv.expectRevert(abi.encodeWithSelector(T.ViewRetrievalNonce.selector, _key(9)));
        witness.publish(q, sig);
    }

    function testLateMissingCarrierRollbackAndSameSignedRequestRetry() public {
        T.Request memory q = _request(11);
        (T.Observation memory o, bytes32 digest) = witness.prepare(q);
        bytes memory sig = _sign(SECOND_AGENT, digest);
        bytes memory raw = abi.encode(o, sig);
        bytes32 firstHash;
        assembly ("memory-safe") { firstHash := keccak256(add(raw, 32), mload(raw)) }
        require(raw.length <= 8192);
        rv.expectRevert(
            abi.encodeWithSelector(ManifestBytes.SnapshotChunkUnavailable.selector, firstHash)
        );
        witness.publish(q, sig);
        require(!witness.nonceUsed(_key(11)));
        _upload(raw);
        bytes32 h = witness.publish(q, sig);
        witness.requireCurrent(h);
    }

    function testCurrentSourceIdentityAndURIChangesRefuseThenRestore() public {
        bytes32 h = _publish(_request(13));
        bytes32 original = _currentHash(h);
        C.Source memory originalSource = selected;
        selected.contextHash = keccak256("changed policy/admission context");
        checkpoint.set(selected);
        _refusesCurrent(h);
        selected = originalSource;
        checkpoint.set(selected);
        require(_currentHash(h) == original);
        selected.adoption.recordHash = keccak256("replaced adoption");
        checkpoint.set(selected);
        _refusesCurrent(h);
        selected = originalSource;
        checkpoint.set(selected);
        _setURI("https://origin.example.invalid/different");
        _refusesCurrent(h);
        selected = originalSource;
        checkpoint.set(selected);
        require(_currentHash(h) == original);
        StreamFinalityScope memory wrong = scope;
        wrong.scopeId = bytes32(uint256(99));
        T.Request memory q = _request(14);
        q.scope = wrong;
        rv.expectRevert();
        witness.prepare(q);
        require(_currentHash(h) == original);
    }

    function testActualFamilyAndFailedFixityRejectThenRepairSameOriginalPair() public {
        T.Request memory q = _request(15);
        (, bytes memory sig) = _prepared(q);
        _status(firstFamily, 2);
        rv.expectRevert();
        witness.publish(q, sig);
        require(!witness.nonceUsed(_key(15)));
        _status(firstFamily, 1);
        bytes32 h = witness.publish(q, sig);
        bytes32 original = _currentHash(h);
        _recordFixity(secondReceipt, 2, false);
        _refusesCurrent(h);
        _recordFixity(secondReceipt, 1, true);
        require(_currentHash(h) == original);
        _role(address(fixitySafe), false); // Original retained fixity is not a fresh signature/grant.
        require(_currentHash(h) == original);
    }

    function testRetainedDeadlineIsHistoricalAndStoreCarrierTamperRestores() public {
        T.Request memory q = _request(17);
        bytes32 h = _publish(q);
        bytes32 original = _currentHash(h);
        vm.warp(uint256(q.deadline) + 1);
        require(_currentHash(h) == original);
        bytes memory raw = witness.encoded(h);
        (address pointer,) = store.chunk(keccak256(raw));
        require(pointer != address(0));
        bytes memory code = pointer.code;
        bytes memory changed = bytes.concat(code);
        changed[1] = bytes1(uint8(changed[1]) ^ 1);
        vm.etch(pointer, changed);
        _refusesCurrent(h);
        vm.etch(pointer, code);
        require(_currentHash(h) == original);
    }

    function testWriterRevocationIsScopedAndHistoricalBytesRemain() public {
        bytes32 first = _publish(_request(19));
        bytes memory history = witness.encoded(first);
        StreamFinalityScope memory firstScope = scope;
        scope.scopeId = bytes32(uint256(18));
        selected.adoption.input.scope = scope;
        selected.adoption.recordHash = keccak256("second scope authentic boundary");
        checkpoint.set(selected);
        bytes32 second = _publish(_request(20));
        rv.expectRevert(abi.encodeWithSelector(T.InvalidViewRetrieval.selector));
        witness.revoke(second, keccak256("reason"));
        vm.prank(safeVm.addr(SECOND_AGENT));
        witness.revoke(second, keccak256("signed writer withdrew correspondence"));
        require(witness.revocationEpoch(scope) == 1 && witness.revocationEpoch(firstScope) == 0);
        rv.expectRevert(abi.encodeWithSelector(T.ViewRetrievalRevoked.selector, second));
        witness.requireCurrent(second);
        require(keccak256(witness.encoded(first)) == keccak256(history));
        vm.prank(safeVm.addr(SECOND_AGENT));
        witness.revoke(first, keccak256("withdraw first"));
        require(
            witness.revocationEpoch(firstScope) == 1 && witness.revocationEpoch(scope) == 1
                && witness.record(first).recordHash == first
        );
    }

    function testDirectOriginalWriterNeedsNoFabricatedSignature() public {
        T.Request memory q = _request(23);
        (T.Observation memory o,) = witness.prepare(q);
        _upload(abi.encode(o, bytes("")));
        address writer = safeVm.addr(SECOND_AGENT);
        vm.prank(writer);
        bytes32 h = witness.publish(q, "");
        require(witness.record(h).writer == writer);
        witness.requireCurrent(h);
    }

    function testRuntimeChainAndFutureObservationRefuseWithExactRestoration() public {
        bytes32 h = _publish(_request(25));
        bytes32 original = _currentHash(h);
        bytes memory code = address(checkpoint).code;
        vm.etch(address(checkpoint), hex"00");
        _refusesCurrent(h);
        vm.etch(address(checkpoint), code);
        require(_currentHash(h) == original);
        uint256 chain = configuration.chainId;
        rv.chainId(chain + 1);
        _refusesCurrent(h);
        rv.chainId(chain);
        require(_currentHash(h) == original);
        T.Request memory q = _request(26);
        q.observedAt = uint64(block.timestamp + 1);
        rv.expectRevert(abi.encodeWithSelector(T.InvalidViewRetrieval.selector));
        witness.prepare(q);
        q.observedAt = uint64(block.timestamp);
        witness.prepare(q);
    }

    function testResolvedArweaveTransactionMustBeActualOriginalReceipt() public {
        T.Request memory q = _request(27);
        q.steps[1].toURI = AR;
        q.resolvedURI = AR;
        bytes32 h = _publish(q);
        witness.requireCurrent(h);
        q.nonce = 28;
        q.steps[1].toURI = "ar://AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE";
        q.resolvedURI = q.steps[1].toURI;
        rv.expectRevert(abi.encodeWithSelector(T.InvalidViewRetrieval.selector));
        witness.prepare(q);
        q.steps[1].toURI = AR;
        q.resolvedURI = AR;
        witness.prepare(q);
    }

    function testActualInstitutionalSafeSignsFreshObservationNotOldReceiptReplay() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x662901;
        keys[1] = 0x662902;
        SafeComponents memory components = deploySafeComponents("1.4.1");
        OfficialSafe institution = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 90);
        secondFamily =
            _admit("institution-safe", _family("institution-safe", false, address(institution)));
        (E.Receipt memory receipt, bytes memory locator) = _receipt(false, 1);
        receipt.writer = address(institution);
        receipt.proofRecordHash = host.possessionHash(receipt);
        secondReceipt = host.recordReceipt(
            receipt,
            locator,
            safeThresholdSignature(
                keys, safeMessageDigest(institution, abi.encodePacked(host.receiptDigest(receipt)))
            )
        );
        _recordFixity(secondReceipt, 1, false);
        completeCoverage = host.recordCoverage(firstReceipt, secondReceipt);
        T.Request memory q = _request(29);
        (T.Observation memory o, bytes32 digest) = witness.prepare(q);
        require(o.writer == address(institution));
        bytes memory sig =
            safeThresholdSignature(keys, safeMessageDigest(institution, abi.encodePacked(digest)));
        _upload(abi.encode(o, sig));
        bytes32 h = witness.publish(q, sig);
        witness.requireCurrent(h);
        q.nonce = 30;
        bytes memory originalSig = safeThresholdSignature(
            keys, safeMessageDigest(institution, abi.encodePacked(host.receiptDigest(receipt)))
        );
        rv.expectRevert(
            abi.encodeWithSelector(A.InvalidArchivalSignature.selector, address(institution))
        );
        witness.publish(q, originalSig);
    }

    function testActualFullManifestSamePairAndMultiChunkObservation() public {
        bytes memory padding = new bytes(9000);
        for (uint256 i; i < padding.length; ++i) {
            padding[i] = "a";
        }
        bytes memory raw = bytes.concat(
            bytes(
                '{"manifest":"arweave/paths","paths":{"image.png":{"id":"ElP9Xu-yoWLv6x6Vy7JtbNUKYXxruXflEH6kwLA1QL0"}},"padding":"'
            ),
            padding,
            bytes('"}')
        );
        (bytes32 manifestObject, bytes32 manifestCoverage) = _manifest(raw);
        string memory requested = "ar://AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE/image.png";
        _setURI(requested);
        T.Request memory q = _request(31);
        q.steps = new T.Step[](1);
        q.steps[0] = T.Step(3, requested, AR, 0, manifestObject, manifestCoverage, raw);
        q.resolvedURI = AR;
        (T.Observation memory o, bytes memory sig) = _prepared(q);
        require(abi.encode(o, sig).length > 8192);
        bytes32 h = witness.publish(q, sig);
        bytes32 current = _currentHash(h);
        (T.Observation memory saved, bytes memory savedSig) =
            abi.decode(witness.encoded(h), (T.Observation, bytes));
        require(
            keccak256(saved.steps[0].manifestBytes) == keccak256(raw)
                && keccak256(savedSig) == keccak256(sig)
        );
        // Mutating the independently archived manifest bytes cannot retain its admitted digest/size.
        T.Request memory changed = abi.decode(abi.encode(q), (T.Request));
        changed.nonce = 32;
        changed.steps[0].manifestBytes[150] = bytes1(uint8(changed.steps[0].manifestBytes[150]) ^ 1);
        rv.expectRevert(abi.encodeWithSelector(T.InvalidViewRetrieval.selector));
        witness.prepare(changed);
        changed = abi.decode(abi.encode(q), (T.Request));
        changed.steps[0].manifestObject = objectHash;
        rv.expectRevert(abi.encodeWithSelector(T.InvalidViewRetrieval.selector));
        witness.prepare(changed);
        require(_currentHash(h) == current);
    }

    function testFreshDirectOriginObservationNeedsNoInventedRoute() public {
        T.Request memory q = _request(33);
        q.steps = new T.Step[](0);
        q.resolvedURI = ORIGIN;
        bytes32 h = _publish(q);
        witness.requireCurrent(h);
        q.nonce = 34;
        q.resolvedURI = MIRROR;
        rv.expectRevert(abi.encodeWithSelector(T.InvalidViewRetrieval.selector));
        witness.prepare(q);
        q.resolvedURI = ORIGIN;
        witness.prepare(q);
    }

    function testConstructorCannotSelectForeignCheckpointOrArchiveIdentity() public {
        T.Configuration memory changed = configuration;
        changed.router = address(checkpoint);
        changed.routerCodeHash = address(checkpoint).codehash;
        rv.expectRevert(abi.encodeWithSelector(T.InvalidViewRetrieval.selector));
        new Witness(changed);
        changed = configuration;
        changed.signatureGas = 89999;
        rv.expectRevert(abi.encodeWithSelector(T.InvalidViewRetrieval.selector));
        new Witness(changed);
        changed = configuration;
        changed.sourceGas = 16777217;
        rv.expectRevert(abi.encodeWithSelector(T.InvalidViewRetrieval.selector));
        new Witness(changed);
        changed = configuration;
        changed.archiveCodeHash = bytes32(uint256(1));
        rv.expectRevert();
        new Witness(changed);
        new Witness(configuration);
    }

    function testForeignArtistObservationCannotPublishOrCreateRevocationEpoch() public {
        T.Request memory q = _request(51);
        (, bytes memory signedForRealArtist) = _prepared(q);
        Artist.ArtistPresentation memory original = router.artistPresentation(scope.collectionId);
        Artist.ArtistPresentation memory other =
            abi.decode(abi.encode(original), (Artist.ArtistPresentation));
        other.artistId = keccak256("different actual collection Artist");
        other.snapshotHash = keccak256("different locked snapshot");
        router.setPresentation(scope.collectionId, other);
        rv.expectRevert(abi.encodeWithSelector(T.InvalidViewRetrieval.selector));
        witness.prepare(q);
        rv.expectRevert(abi.encodeWithSelector(T.InvalidViewRetrieval.selector));
        witness.publish(q, signedForRealArtist);
        require(!witness.nonceUsed(_key(51)) && witness.revocationEpoch(scope) == 0);
        rv.expectRevert(
            abi.encodeWithSelector(T.ViewRetrievalUnknown.selector, bytes32(uint256(99)))
        );
        vm.prank(safeVm.addr(SECOND_AGENT));
        witness.revoke(bytes32(uint256(99)), keccak256("no foreign authority"));
        require(witness.revocationEpoch(scope) == 0);
        router.setPresentation(scope.collectionId, original);
        bytes32 h = witness.publish(q, signedForRealArtist);
        witness.requireCurrent(h);
    }

    function testDifferentCollectionArtistAndFullPresentationAreNotSubstitutable() public {
        T.Request memory q = _request(53);
        bytes32 h = _publish(q);
        bytes32 originalCurrent = _currentHash(h);
        C.Source memory originalSource = selected;
        StreamFinalityScope memory originalScope = scope;
        Artist.ArtistPresentation memory presentation =
            router.artistPresentation(scope.collectionId);
        scope.collectionId = 8;
        selected.adoption.input.scope = scope;
        selected.adoption.recordHash = keccak256("second collection adoption");
        checkpoint.set(selected);
        Artist.ArtistPresentation memory other =
            abi.decode(abi.encode(presentation), (Artist.ArtistPresentation));
        other.artistId = keccak256("second collection Artist");
        router.setPresentation(8, other);
        q = _request(54);
        rv.expectRevert(abi.encodeWithSelector(T.InvalidViewRetrieval.selector));
        witness.prepare(q);
        require(witness.revocationEpoch(scope) == 0 && witness.revocationEpoch(originalScope) == 0);
        scope = originalScope;
        selected = originalSource;
        checkpoint.set(selected);
        presentation.snapshotHash = keccak256("changed full locked presentation");
        router.setPresentation(scope.collectionId, presentation);
        _refusesCurrent(h);
        presentation.snapshotHash = keccak256("locked complete Artist snapshot");
        router.setPresentation(scope.collectionId, presentation);
        require(_currentHash(h) == originalCurrent);
    }
}
