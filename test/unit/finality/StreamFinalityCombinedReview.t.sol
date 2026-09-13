// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityPreparedScope.t.sol";
import "../artist/StreamArtistSanctionReviewProfiles.t.sol";
import "../../../smart-contracts/domains/finality/StreamArtworkFinalityRegistry.sol";

/// @dev Typed dispatch/return boundaries; full original Registry/native producer assembly is separate.
contract CombinedCandidateBoundary {
    bool public combined;
    bool public rejectLegacy;
    uint8 public fault;

    function configure(bool enabled, bool reject, uint8 failure) external {
        combined = enabled;
        rejectLegacy = reject;
        fault = failure;
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        if (fault == 6) assembly ("memory-safe") {
            mstore(0, 2)
            return(0, 32)
        }
        return combined && id == type(IStreamArtistSanctionReviewPreparation).interfaceId;
    }
    bytes private response;
    uint8 private burnStage;
    uint256 public successfulPrepares;

    function setBurnStage(uint8 stage) external {
        burnStage = stage;
    }

    function _burn(uint8 stage) private view {
        if (burnStage == stage) assembly ("memory-safe") { for { } 1 { } { } }
    }

    function prepareWithCap(bytes memory raw, uint256 cap) external returns (Q.Prepared memory) {
        return _prepare(raw, cap);
    }
    bytes32 private constant MANIFEST = keccak256("typed original manifest");

    function prepare(bytes memory raw) external returns (Q.Prepared memory) {
        return _prepare(raw, 500_000);
    }

    function _prepare(bytes memory raw, uint256 cap) private returns (Q.Prepared memory result) {
        response = raw;
        Q.Request memory q;
        q.terms.collectionId = 1;
        q.manifest = StreamFinalityManifestRef(
            "https://example.invalid/original",
            keccak256("uri"),
            MANIFEST,
            keccak256("schema"),
            keccak256("canon")
        );
        q.statement = "Typed review profile decoder fixture";
        q.signingToolName = "fixture";
        q.signingToolVersion = "1";
        StreamArtistHashes.Environment memory e = StreamArtistHashes.Environment(
            block.chainid, address(this), address(this), address(this)
        );
        StreamArtistSanctionCandidate.Pins memory p = StreamArtistSanctionCandidate.Pins(
            address(this), address(this).codehash, address(this), address(this).codehash, cap
        );
        result = StreamArtistSanctionCandidate.prepare(e, p, q);
        ++successfulPrepares;
    }

    function getSatellitePointer(bytes32 key)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        _burn(1);
        require(
            key == keccak256("ARTIST_REGISTRY") || key == keccak256("ARTWORK_FINALITY_REGISTRY"),
            "exact typed pointer"
        );
        return (
            address(this),
            address(this).codehash,
            false,
            bytes32(0),
            bytes4(0),
            address(0),
            0,
            bytes32(0),
            bytes32(0),
            0
        );
    }

    function prepareSanction(
        StreamFinalityScope calldata scope,
        StreamFinalityComponentExpectation[] calldata,
        StreamFinalityManifestRef calldata manifest
    ) external view returns (StreamArtistSanctionPreparation memory p) {
        require(!rejectLegacy, "legacy preparation must not be called");
        return _actual(scope, manifest);
    }

    function prepareSanctionWithReview(
        StreamFinalityScope calldata scope,
        StreamFinalityComponentExpectation[] calldata,
        StreamFinalityManifestRef calldata manifest
    )
        external
        view
        returns (
            StreamArtistSanctionPreparation memory p,
            IStreamFinalitySanctionReview.ReviewFacts memory review
        )
    {
        require(combined, "not advertised");
        if (fault == 1) revert("advertised failure");
        if (fault == 2) assembly ("memory-safe") { return(0, 4096) }
        if (fault == 5) assembly ("memory-safe") { for { } 1 { } { } }
        p = _actual(scope, manifest);
        review = abi.decode(response, (IStreamFinalitySanctionReview.ReviewFacts));
        if (fault == 3) {
            bytes memory raw = bytes.concat(abi.encode(p, review), bytes32(0));
            assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
        }
        if (fault == 4) p.sanctionSubjectHash = keccak256("different subject");
    }

    function _actual(
        StreamFinalityScope calldata scope,
        StreamFinalityManifestRef calldata manifest
    ) private view returns (StreamArtistSanctionPreparation memory p) {
        _burn(2);
        require(
            scope.collectionId == 1 && uint8(scope.scopeType) == 0 && scope.tokenId == 0
                && scope.scopeId == 0 && manifest.contentHash == MANIFEST,
            "exact typed current candidate"
        );
        S.Subject memory s = S.Subject(
            keccak256("6529STREAM_ARTIST_SANCTION_SUBJECT_V1"),
            block.chainid,
            address(this),
            address(this),
            0,
            1,
            0,
            0,
            keccak256("core"),
            keccak256("components"),
            manifest.uriHash,
            manifest.contentHash,
            manifest.schemaId,
            manifest.canonicalizationHash
        );
        return StreamArtistSanctionPreparation(
            StreamArtistSanctionHashes.subject(s),
            s.coreFactsHash,
            s.nonSanctionComponentsHash,
            keccak256("inputs")
        );
    }

    fallback(bytes calldata input) external returns (bytes memory) {
        require(!rejectLegacy, "legacy review must not be called");
        _burn(3);
        require(
            msg.sig == IStreamFinalitySanctionReview.requireSanctionReviewFacts.selector,
            "exact typed review selector"
        );
        (StreamFinalityScope memory scope, bytes32 manifest) =
            abi.decode(input[4:], (StreamFinalityScope, bytes32));
        require(
            scope.collectionId == 1 && uint8(scope.scopeType) == 0 && scope.tokenId == 0
                && scope.scopeId == 0 && manifest == MANIFEST,
            "exact typed review locator"
        );
        return response;
    }
}

contract CombinedPreparationHarness {
    function read(
        address provider,
        StreamFinalityScope calldata scope,
        StreamFinalityComponentExpectation[] calldata components
    ) external view returns (bytes memory, IStreamFinalitySanctionReview.ReviewFacts memory) {
        return StreamFinalityPreparedScopeReads.readWithReview(
            provider, scope, keccak256("manifest"), components, 800000
        );
    }

    function decode(bytes calldata raw, uint256 base)
        external
        pure
        returns (IStreamFinalitySanctionReview.ReviewFacts memory)
    {
        return StreamFinalitySanctionReviewReads.review(raw, base);
    }
}

contract StreamFinalityCombinedReviewTest is CharacterizationTestBase {
    CombinedPreparationHarness private harness;
    NativeProviderReadTable private table;
    CombinedCandidateBoundary private candidate;
    StreamFinalityScope private scope;

    function setUp() public {
        harness = new CombinedPreparationHarness();
        table = new NativeProviderReadTable();
        candidate = new CombinedCandidateBoundary();
        scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
    }

    function _facts(uint256 n)
        private
        pure
        returns (IStreamFinalitySanctionReview.ReviewFacts memory r)
    {
        r.schemaVersion = 1;
        r.profile = n == 1 ? 1 : 2;
        r.contentRoot = keccak256("original content root");
        r.mediaContentHashes = new bytes32[](0);
        r.referenceRenderContentHashes = new bytes32[](n);
        for (uint256 i; i < n; ++i) {
            r.referenceRenderContentHashes[i] = keccak256(abi.encode("original PNG", i % 2));
        }
    }

    function _inputs() private pure returns (bytes memory raw) {
        StreamFinalityScopeInputs memory facts;
        facts.rootRecordHash = keccak256("root");
        return abi.encode(facts, keccak256("schema"), keccak256("canon"));
    }

    function _envelope(uint256 base, IStreamFinalitySanctionReview.ReviewFacts memory r)
        private
        pure
        returns (bytes memory)
    {
        if (base == 32) return abi.encode(r);
        if (base == 160) {
            StreamArtistSanctionPreparation memory p = StreamArtistSanctionPreparation(
                keccak256("subject"),
                keccak256("core"),
                keccak256("components"),
                keccak256("inputs")
            );
            return abi.encode(p, r);
        }
        (StreamFinalityScopeInputs memory i, bytes32 s, bytes32 c) =
            abi.decode(_inputs(), (StreamFinalityScopeInputs, bytes32, bytes32));
        return abi.encode(i, s, c, r);
    }

    function _probe(bytes4 id, bytes memory raw) private {
        table.put(abi.encodeCall(IERC165.supportsInterface, (id)), raw);
    }

    function _provider(bytes memory raw) private {
        StreamFinalityComponentExpectation[] memory rows =
            new StreamFinalityComponentExpectation[](0);
        table.put(
            abi.encodeCall(
                IStreamFinalityPreparedSanctionReview.requirePreparedFinalityScopeInputsAndReview,
                (scope, keccak256("manifest"), rows)
            ),
            raw
        );
    }

    function _legacy(IStreamFinalitySanctionReview.ReviewFacts memory r) private {
        StreamFinalityComponentExpectation[] memory rows =
            new StreamFinalityComponentExpectation[](0);
        _probe(type(IStreamFinalityPreparedScopeEvidence).interfaceId, abi.encode(true));
        table.put(
            abi.encodeCall(
                IStreamFinalityPreparedScopeEvidence.requirePreparedFinalityScopeInputs,
                (scope, keccak256("manifest"), rows)
            ),
            _inputs()
        );
        table.put(
            abi.encodeCall(
                IStreamFinalitySanctionReview.requireSanctionReviewFacts,
                (scope, keccak256("manifest"))
            ),
            abi.encode(r)
        );
    }

    function _read()
        private
        view
        returns (bytes memory, IStreamFinalitySanctionReview.ReviewFacts memory)
    {
        StreamFinalityComponentExpectation[] memory rows =
            new StreamFinalityComponentExpectation[](0);
        return harness.read(address(table), scope, rows);
    }

    function _reject(bytes memory raw, uint256 base) private {
        vm.expectRevert();
        harness.decode(raw, base);
    }

    function _set(bytes memory raw, uint256 offset, uint256 value) private pure {
        assembly ("memory-safe") { mstore(add(add(raw, 32), offset), value) }
    }

    function testFuzzAllCanonicalEnvelopesPreserveEveryOrderedOccurrence(uint8 seed) public view {
        IStreamFinalitySanctionReview.ReviewFacts memory r = _facts(1 + uint256(seed) % 16);
        uint256[3] memory bases = [uint256(32), 160, 416];
        for (uint256 i; i < 3; ++i) {
            require(
                keccak256(abi.encode(harness.decode(_envelope(bases[i], r), bases[i])))
                    == keccak256(abi.encode(r))
            );
        }
    }

    function testEveryOffsetAndDirtySchemaProfileWordRejects() public {
        uint256[3] memory bases = [uint256(32), 160, 416];
        for (uint256 i; i < 3; ++i) {
            uint256 base = bases[i];
            uint256[6] memory offsets = [
                base - 32, base, base + 32, base + 96, base + 128, base + 160
            ];
            for (uint256 j; j < 6; ++j) {
                bytes memory raw = _envelope(base, _facts(2));
                _set(raw, offsets[j], type(uint256).max);
                _reject(raw, base);
            }
        }
    }

    function testEnvelopeCountZeroRootAndTrailingBytesReject() public {
        uint256[3] memory bases = [uint256(32), 160, 416];
        for (uint256 i; i < 3; ++i) {
            uint256 base = bases[i];
            bytes memory raw = _envelope(base, _facts(2));
            _set(raw, base + 192, 17);
            _reject(raw, base);
            raw = _envelope(base, _facts(2));
            _set(raw, base + 64, 0);
            _reject(raw, base);
            raw = _envelope(base, _facts(2));
            _set(raw, base + 224, 0);
            _reject(raw, base);
            _reject(bytes.concat(_envelope(base, _facts(2)), bytes32(0)), base);
            _reject(new bytes(32), base);
        }
    }

    function testCombinedProviderNeedsNoLegacyRead() public {
        _probe(type(IStreamFinalityPreparedSanctionReview).interfaceId, abi.encode(true));
        _provider(_envelope(416, _facts(16)));
        (bytes memory inputs, IStreamFinalitySanctionReview.ReviewFacts memory r) = _read();
        require(
            keccak256(inputs) == keccak256(_inputs())
                && keccak256(abi.encode(r)) == keccak256(abi.encode(_facts(16)))
        );
    }

    function testAbsentProviderCapabilityKeepsOriginalTwoReadsWithSameResult() public {
        _legacy(_facts(2));
        (bytes memory before_, IStreamFinalitySanctionReview.ReviewFacts memory a) = _read();
        _probe(type(IStreamFinalityPreparedSanctionReview).interfaceId, abi.encode(true));
        _provider(_envelope(416, _facts(2)));
        (bytes memory after_, IStreamFinalitySanctionReview.ReviewFacts memory b) = _read();
        require(
            keccak256(before_) == keccak256(after_)
                && keccak256(abi.encode(a)) == keccak256(abi.encode(b))
        );
    }

    function testAdvertisedProviderFailureCannotUseHealthyLegacyFallback() public {
        _legacy(_facts(2));
        _probe(type(IStreamFinalityPreparedSanctionReview).interfaceId, abi.encode(true));
        vm.expectRevert();
        _read();
        _provider(bytes.concat(_envelope(416, _facts(2)), bytes32(0)));
        vm.expectRevert();
        _read();
        _provider(new bytes(4096));
        vm.expectRevert();
        _read();
        _provider(_envelope(416, _facts(2)));
        _read();
    }

    function testMalformedProviderCapabilityFailsClosed() public {
        _legacy(_facts(1));
        _probe(type(IStreamFinalityPreparedSanctionReview).interfaceId, abi.encode(uint256(2)));
        vm.expectRevert();
        _read();
    }

    function testCombinedCandidateAndOriginalPathHaveIdenticalCompleteResults() public {
        bytes memory r = abi.encode(_facts(2));
        Q.Prepared memory legacy = candidate.prepare(r);
        candidate.configure(true, true, 0);
        Q.Prepared memory combined = candidate.prepare(r);
        require(
            keccak256(abi.encode(legacy)) == keccak256(abi.encode(combined))
                && candidate.successfulPrepares() == 2
        );
    }

    function testFuzzCombinedCandidateRetainsOriginalOneThroughSixteenCaptures(uint8 seed) public {
        bytes memory r = abi.encode(_facts(1 + uint256(seed) % 16));
        Q.Prepared memory legacy = candidate.prepare(r);
        candidate.configure(true, true, 0);
        Q.Prepared memory combined = candidate.prepare(r);
        require(keccak256(abi.encode(legacy)) == keccak256(abi.encode(combined)));
    }

    function testCandidateAdvertisedFailureMalformedBombAndBurnDoNotFallbackOrConsume() public {
        bytes memory r = abi.encode(_facts(2));
        candidate.prepare(r);
        for (uint8 i = 1; i <= 5; ++i) {
            candidate.configure(true, false, i);
            vm.expectRevert();
            candidate.prepare(r);
            require(candidate.successfulPrepares() == 1, "failed read consumed state");
        }
        candidate.configure(true, true, 0);
        candidate.prepare(r);
        require(candidate.successfulPrepares() == 2);
    }

    function testMalformedRegistryCapabilityCannotSelectLegacy() public {
        candidate.configure(true, false, 6);
        vm.expectRevert();
        candidate.prepare(abi.encode(_facts(2)));
    }

    function testConfiguredLargeReadCapIsNotMandatoryParentGas() public {
        candidate.configure(true, true, 0);
        (bool success,) = address(candidate).call{ gas: 2000000 }(
            abi.encodeCall(candidate.prepareWithCap, (abi.encode(_facts(2)), uint256(40000000)))
        );
        require(success && candidate.successfulPrepares() == 1);
    }
}
