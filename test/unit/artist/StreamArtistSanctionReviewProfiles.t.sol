// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/artist/StreamArtistSanctionCandidate.sol";

interface ReviewProfileVm {
    function expectRevert(bytes4 selector) external;
    function expectRevert(bytes calldata reason) external;
}

/// @dev Explicit decoder-only typed boundaries. No actual Core, manifest or governance claim.
contract ReviewProfileBoundary {
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

contract StreamArtistSanctionReviewProfilesTest {
    ReviewProfileVm private constant vm =
        ReviewProfileVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    ReviewProfileBoundary private producer;

    function setUp() public {
        producer = new ReviewProfileBoundary();
    }

    function _facts(uint8 profile, uint256 n)
        private
        pure
        returns (IStreamFinalitySanctionReview.ReviewFacts memory r)
    {
        r.schemaVersion = 1;
        r.profile = profile;
        r.contentRoot = keccak256("original root");
        r.mediaContentHashes = new bytes32[](0);
        r.referenceRenderContentHashes = new bytes32[](n);
        for (uint256 i; i < n; ++i) {
            r.referenceRenderContentHashes[i] = keccak256(abi.encode("original PNG", i));
        }
    }

    function _accepted(IStreamFinalitySanctionReview.ReviewFacts memory r) private {
        Q.Prepared memory p = producer.prepare(abi.encode(r));
        S.Ceremony memory c = S.Ceremony(
            r.contentRoot,
            r.mediaContentHashes,
            r.referenceRenderContentHashes,
            "Typed review profile decoder fixture",
            "fixture",
            "1"
        );
        require(
            keccak256(p.ceremony) == keccak256(StreamArtistSanctionCeremony.document(p.subject, c))
                && p.scopeInputsHash == keccak256("inputs")
                && p.reviewFactsHash == keccak256(abi.encode(r)),
            "full ordered occurrence list reaches unchanged ceremony and original review commitment"
        );
    }

    function testOriginalSingleCaptureProfileIsRetained() public {
        _accepted(_facts(1, 1));
    }

    function testTwoAndSixteenCapturesRetainOrderAndRepeatedOccurrences() public {
        _accepted(_facts(2, 2));
        IStreamFinalitySanctionReview.ReviewFacts memory r = _facts(2, 16);
        r.referenceRenderContentHashes[15] = r.referenceRenderContentHashes[0];
        _accepted(r);
    }

    function testProfileCountSchemaAndZeroHashesFailClosed() public {
        uint8[5] memory profiles = [uint8(0), 1, 2, 3, 2];
        uint256[5] memory counts = [uint256(1), 2, 1, 2, 0];
        for (uint256 i; i < profiles.length; ++i) {
            if (i == 4) {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        StreamArtistSanctionCandidate.SanctionReadFailed.selector, address(producer)
                    )
                );
            } else {
                vm.expectRevert(S.InvalidSanctionCeremony.selector);
            }
            producer.prepare(abi.encode(_facts(profiles[i], counts[i])));
        }
        IStreamFinalitySanctionReview.ReviewFacts memory r = _facts(2, 2);
        r.schemaVersion = 2;
        vm.expectRevert(S.InvalidSanctionCeremony.selector);
        producer.prepare(abi.encode(r));
        r.schemaVersion = 1;
        r.contentRoot = 0;
        vm.expectRevert(S.InvalidSanctionCeremony.selector);
        producer.prepare(abi.encode(r));
        r.contentRoot = keccak256("original root");
        r.referenceRenderContentHashes[1] = 0;
        vm.expectRevert(S.InvalidSanctionCeremony.selector);
        producer.prepare(abi.encode(r));
    }

    function testNoncanonicalOffsetsDirtyProfileAndUnexpectedMediaFailClosed() public {
        uint256[6] memory offsets = [uint256(0), 32, 64, 128, 160, 192];
        for (uint256 i; i < offsets.length; ++i) {
            bytes memory raw = abi.encode(_facts(2, 2));
            uint256 offset = offsets[i];
            assembly ("memory-safe") { mstore(add(add(raw, 32), offset), 0xffff) }
            vm.expectRevert(S.InvalidSanctionCeremony.selector);
            producer.prepare(raw);
        }
        IStreamFinalitySanctionReview.ReviewFacts memory r = _facts(2, 2);
        r.mediaContentHashes = new bytes32[](1);
        r.mediaContentHashes[0] = keccak256("unsupported media");
        vm.expectRevert(S.InvalidSanctionCeremony.selector);
        producer.prepare(abi.encode(r));
    }

    function testTruncationTrailingWordsAndSeventeenCapturesFailClosed() public {
        bytes memory raw = abi.encode(_facts(2, 2));
        vm.expectRevert(S.InvalidSanctionCeremony.selector);
        producer.prepare(bytes.concat(raw, bytes32(0)));
        assembly ("memory-safe") { mstore(raw, sub(mload(raw), 1)) }
        vm.expectRevert(S.InvalidSanctionCeremony.selector);
        producer.prepare(raw);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistSanctionCandidate.SanctionReadFailed.selector, address(producer)
            )
        );
        producer.prepare(new bytes(287));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistSanctionCandidate.SanctionReadFailed.selector, address(producer)
            )
        );
        producer.prepare(abi.encode(_facts(2, 17)));
    }

    function testFuzzEveryAdmittedLengthAndZeroOccurrence(uint8 seed, bytes32 value) public {
        uint256 n = 2 + uint256(seed) % 15;
        IStreamFinalitySanctionReview.ReviewFacts memory r = _facts(2, n);
        r.referenceRenderContentHashes[n - 1] = value == 0 ? bytes32(uint256(1)) : value;
        _accepted(r);
        r.referenceRenderContentHashes[n - 1] = 0;
        vm.expectRevert(S.InvalidSanctionCeremony.selector);
        producer.prepare(abi.encode(r));
    }

    function testConfiguredCapIsAnUpperBoundBelowFortyMillionParentGas() public {
        bytes memory raw = abi.encode(_facts(2, 2));
        (bool ok, bytes memory result) = address(producer).call{ gas: 2_000_000 }(
            abi.encodeCall(producer.prepareWithCap, (raw, uint256(40_000_000)))
        );
        require(ok, "healthy exact read under high configured cap");
        Q.Prepared memory prepared = abi.decode(result, (Q.Prepared));
        require(
            prepared.reviewFactsHash == keccak256(raw) && producer.successfulPrepares() == 1,
            "bounded parent actually completed exact review"
        );
    }

    function testGasBurningReadsFailWithRetainedParentAndHealthyRetry() public {
        bytes memory raw = abi.encode(_facts(2, 2));
        bytes memory callData = abi.encodeCall(producer.prepareWithCap, (raw, uint256(40_000_000)));
        for (uint8 stage = 1; stage <= 3; ++stage) {
            producer.setBurnStage(stage);
            uint256 beforeCount = producer.successfulPrepares();
            (bool ok, bytes memory reason) = address(producer).call{ gas: 2_000_000 }(callData);
            require(
                !ok && reason.length == 36
                    && bytes4(reason) == StreamArtistSanctionCandidate.SanctionReadFailed.selector
                    && producer.successfulPrepares() == beforeCount,
                "callee exhaustion preserves error/rollback path"
            );
            producer.setBurnStage(0);
            (ok, reason) = address(producer).call{ gas: 2_000_000 }(callData);
            require(
                ok && abi.decode(reason, (Q.Prepared)).reviewFactsHash == keccak256(raw)
                    && producer.successfulPrepares() == beforeCount + 1,
                "identical healthy retry after failed read"
            );
        }
    }
}
