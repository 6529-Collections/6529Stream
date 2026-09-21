// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import {
    StreamFinalityViewSanctionReviewCodecV1 as Codec
} from "../../../smart-contracts/domains/finality/StreamFinalityViewSanctionReviewCodecV1.sol";
import {
    StreamFinalitySanctionReviewReads as Reads
} from "../../../smart-contracts/domains/finality/StreamFinalitySanctionReviewReads.sol";
import "../../../smart-contracts/interfaces/stream/finality/StreamFinalityEvidenceTypes.sol";
import "../../../smart-contracts/interfaces/stream/finality/IStreamFinalitySanctionReview.sol";

contract ViewReviewCodecProbe {
    function decode(bytes memory raw, uint256 base)
        external
        pure
        returns (IStreamFinalitySanctionReview.ReviewFacts memory)
    {
        return Reads.review(raw, base);
    }

    function read(address target, uint256 maximum) external view returns (bytes memory) {
        return Reads.read(target, hex"12345678", maximum, 500000);
    }

    function scope(StreamFinalityScope memory s, bytes32 schema, bytes32 canon) external pure {
        Codec.requireScope(s, schema, canon);
    }
}

contract ViewReviewBytesBoundary {
    bytes private data;

    function set(bytes memory raw) external {
        data = raw;
    }

    fallback() external {
        bytes memory raw = data;
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }
}

/// @notice Canonical transport only: actual source/Registry/governance acceptance is separate.
contract StreamFinalityViewSanctionCodecV1Test is CharacterizationTestBase {
    ViewReviewCodecProbe private probe;
    ViewReviewBytesBoundary private boundary;

    function setUp() public {
        probe = new ViewReviewCodecProbe();
        boundary = new ViewReviewBytesBoundary();
    }

    function _facts(uint256 m, uint256 n, uint8 profile)
        private
        pure
        returns (IStreamFinalitySanctionReview.ReviewFacts memory r)
    {
        r.schemaVersion = 1;
        r.profile = profile;
        r.contentRoot = keccak256("literal complete root");
        r.mediaContentHashes = new bytes32[](m);
        r.referenceRenderContentHashes = new bytes32[](n);
        for (uint256 i; i < m; ++i) {
            r.mediaContentHashes[i] = keccak256(abi.encode("media", i));
        }
        for (uint256 i; i < n; ++i) {
            r.referenceRenderContentHashes[i] = keccak256(abi.encode("reference", i));
        }
    }

    function _envelope(IStreamFinalitySanctionReview.ReviewFacts memory r, uint256 base)
        private
        pure
        returns (bytes memory raw)
    {
        if (base == 32) return abi.encode(r);
        if (base == 160) {
            return abi.encode(
                bytes32(uint256(1)),
                bytes32(uint256(2)),
                bytes32(uint256(3)),
                bytes32(uint256(4)),
                r
            );
        }
        StreamFinalityScopeInputs memory s;
        s.rootRecordHash = bytes32(uint256(1));
        s.bundleCoverageHash = bytes32(uint256(10));
        return abi.encode(s, bytes32(uint256(11)), bytes32(uint256(12)), r);
    }

    function _word(bytes memory raw, uint256 offset, uint256 value) private pure {
        assembly ("memory-safe") { mstore(add(add(raw, 32), offset), value) }
    }

    function _copy(bytes memory raw) private pure returns (bytes memory) {
        return bytes.concat(raw);
    }

    function _invalid(bytes memory raw, uint256 base) private {
        (bool ok, bytes memory reason) =
            address(probe).call(abi.encodeCall(probe.decode, (raw, base)));
        require(
            !ok
                && keccak256(reason)
                    == keccak256(abi.encodeWithSelector(Codec.InvalidViewSanctionReview.selector)),
            "exact bounded profile3 error"
        );
    }

    function testLiteralAllThreeEnvelopeWidthsAtBothBounds() public view {
        uint256[3] memory bases = [uint256(32), 160, 416];
        uint256[3] memory maxima = [uint256(1280), 1408, 1664];
        for (uint256 j; j < 3; ++j) {
            for (uint256 edge; edge < 2; ++edge) {
                IStreamFinalitySanctionReview.ReviewFacts memory r =
                    _facts(edge == 0 ? 1 : 16, edge == 0 ? 1 : 16, 3);
                bytes memory raw = _envelope(r, bases[j]);
                require(
                    raw.length == (edge == 0 ? bases[j] + 288 : maxima[j]),
                    "literal original ABI widths"
                );
                require(
                    keccak256(abi.encode(probe.decode(raw, bases[j]))) == keccak256(abi.encode(r)),
                    "all ordered words retained"
                );
            }
        }
    }

    function testOldProfilesOneAndTwoRemainExactAtAllBases() public view {
        uint256[3] memory bases = [uint256(32), 160, 416];
        for (uint256 j; j < 3; ++j) {
            for (uint256 n = 1; n <= 16; ++n) {
                IStreamFinalitySanctionReview.ReviewFacts memory r = _facts(0, n, n == 1 ? 1 : 2);
                require(
                    keccak256(abi.encode(probe.decode(_envelope(r, bases[j]), bases[j])))
                        == keccak256(abi.encode(r)),
                    "legacy byte parity"
                );
            }
        }
    }

    function testCanonicalOffsetsWidthsNonzeroAndTrailingBytesRefused() public {
        uint256[3] memory bases = [uint256(32), 160, 416];
        for (uint256 j; j < 3; ++j) {
            uint256 b = bases[j];
            bytes memory original = _envelope(_facts(2, 3, 3), b);
            uint256[10] memory offsets = [
                b - 32, b, b + 64, b + 96, b + 128, b + 160, b + 160, b + 192, b + 256, b + 288
            ];
            uint256[10] memory values = [
                uint256(0), 257, 0, 192, 288, 0, type(uint256).max, 0, 17, 0
            ];
            for (uint256 i; i < 10; ++i) {
                bytes memory raw = _copy(original);
                _word(raw, offsets[i], values[i]);
                _invalid(raw, b);
            }
            _invalid(bytes.concat(original, bytes32(0)), b);
            bytes memory shortRaw = _copy(original);
            assembly ("memory-safe") { mstore(shortRaw, sub(mload(shortRaw), 32)) }
            _invalid(shortRaw, b);
            require(
                keccak256(abi.encode(probe.decode(original, b)))
                    == keccak256(abi.encode(_facts(2, 3, 3))),
                "restore original after every independent mutation"
            );
        }
    }

    function testTransportMaximaAndOldOversizeErrorOrder() public {
        uint256[3] memory bases = [uint256(32), 160, 416];
        uint256[3] memory maxima = [uint256(1280), 1408, 1664];
        for (uint256 j; j < 3; ++j) {
            bytes memory raw = _envelope(_facts(16, 16, 3), bases[j]);
            boundary.set(raw);
            require(keccak256(probe.read(address(boundary), maxima[j])) == keccak256(raw));
            boundary.set(bytes.concat(raw, bytes32(uint256(1))));
            vm.expectRevert(
                abi.encodeWithSelector(Reads.SanctionReviewReadFailed.selector, address(boundary))
            );
            probe.read(address(boundary), maxima[j]);
            raw = bytes.concat(_envelope(_facts(0, 16, 2), bases[j]), bytes32(uint256(1)));
            boundary.set(raw);
            vm.expectRevert(
                abi.encodeWithSelector(Reads.SanctionReviewReadFailed.selector, address(boundary))
            );
            probe.read(address(boundary), maxima[j]);
            _word(raw, bases[j] + 32, 255);
            boundary.set(raw);
            vm.expectRevert(
                abi.encodeWithSelector(Reads.SanctionReviewReadFailed.selector, address(boundary))
            );
            probe.read(address(boundary), maxima[j]);
        }
    }

    function testViewScopeAndBothExactManifestIdsAreMandatory() public {
        StreamFinalityScope memory s =
            StreamFinalityScope(StreamFinalityScopeType.VIEW, 7, 0, keccak256("membership"));
        bytes32 schema = keccak256("STREAM_VIEW_PRESERVATION_FINALITY_INPUT_V1");
        bytes32 canon = keccak256("STREAM_VIEW_PRESERVATION_FINALITY_INPUT_ABI_V1");
        probe.scope(s, schema, canon);
        for (uint8 i; i < 4; ++i) {
            s.scopeType = StreamFinalityScopeType(i);
            vm.expectRevert(abi.encodeWithSelector(Codec.InvalidViewSanctionReview.selector));
            probe.scope(s, schema, canon);
        }
        s.scopeType = StreamFinalityScopeType.VIEW;
        vm.expectRevert(abi.encodeWithSelector(Codec.InvalidViewSanctionReview.selector));
        probe.scope(s, bytes32(uint256(1)), canon);
        vm.expectRevert(abi.encodeWithSelector(Codec.InvalidViewSanctionReview.selector));
        probe.scope(s, schema, bytes32(uint256(1)));
        s.tokenId = 1;
        vm.expectRevert(abi.encodeWithSelector(Codec.InvalidViewSanctionReview.selector));
        probe.scope(s, schema, canon);
    }

    function testFuzzFullOrderedArrays(uint8 m, uint8 n, bytes32 salt) public view {
        IStreamFinalitySanctionReview.ReviewFacts memory r =
            _facts(1 + uint256(m) % 16, 1 + uint256(n) % 16, 3);
        r.contentRoot = salt == 0 ? bytes32(uint256(1)) : salt;
        // Repeated occurrences are meaningful and must not be sorted or deduplicated.
        for (uint256 i; i < r.mediaContentHashes.length; ++i) {
            r.mediaContentHashes[i] = r.contentRoot;
        }
        uint256[3] memory bases = [uint256(32), 160, 416];
        for (uint256 j; j < 3; ++j) {
            require(
                keccak256(abi.encode(probe.decode(_envelope(r, bases[j]), bases[j])))
                    == keccak256(abi.encode(r))
            );
        }
    }
}
