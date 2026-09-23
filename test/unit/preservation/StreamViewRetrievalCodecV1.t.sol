// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamViewRetrievalWitnessTypesV1 as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamViewRetrievalWitnessTypesV1.sol";
import {
    StreamViewRetrievalCodecV1 as Codec
} from "../../../smart-contracts/domains/preservation/StreamViewRetrievalCodecV1.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";

contract ViewRetrievalCodecProbe {
    function check(T.Observation memory o) external pure {
        Codec.shape(o);
    }

    function decode(bytes memory raw) external pure returns (T.Observation memory, bytes memory) {
        return Codec.canonical(raw);
    }

    function uri(string memory raw) external pure returns (uint8, bytes32) {
        return Codec.uri(raw);
    }

    function digest(T.Configuration memory c, address h, T.Observation memory o)
        external
        pure
        returns (bytes32)
    {
        return Codec.digest(c, h, o);
    }
}

contract StreamViewRetrievalCodecV1Test is CharacterizationTestBase {
    ViewRetrievalCodecProbe private probe;
    string private constant AR = "ar://ElP9Xu-yoWLv6x6Vy7JtbNUKYXxruXflEH6kwLA1QL0";

    function setUp() public {
        probe = new ViewRetrievalCodecProbe();
    }

    function _observation() private pure returns (T.Observation memory o) {
        o.source.scope =
            StreamFinalityScope(StreamFinalityScopeType.VIEW, 7, 0, bytes32(uint256(4)));
        o.source.core = address(1);
        o.source.router = address(2);
        o.source.declaration = address(3);
        o.source.declarationRecord = bytes32(uint256(4));
        o.source.adoptionRecord = bytes32(uint256(5));
        o.source.adoptionSourceHash = bytes32(uint256(6));
        o.source.payloadHash = bytes32(uint256(7));
        o.source.checkpointContextHash = bytes32(uint256(8));
        o.source.requestedURI = "https://origin.invalid/image?exact=%2F";
        o.source.artistId = keccak256("original Artist");
        o.source.artistPresentationHash = keccak256("complete presentation");
        o.object.artistId = o.source.artistId;
        o.object.contentHash = keccak256("whole bytes");
        o.object.sha256Digest = sha256("whole bytes");
        o.object.byteSize = 11;
        o.coverage.coverageHash = bytes32(uint256(9));
        o.coverage.objectHash = bytes32(uint256(10));
        o.writer = address(11);
        o.observedAt = 12;
        o.deadline = 20;
        o.nonce = 13;
        o.steps = new T.Step[](2);
        o.steps[0].kind = 1;
        o.steps[0].status = 307;
        o.steps[0].fromURI = o.source.requestedURI;
        o.steps[0].toURI = "https://origin.invalid/final";
        o.steps[1].kind = 2;
        o.steps[1].fromURI = o.steps[0].toURI;
        o.steps[1].toURI = "https://institution.invalid/mirror";
        o.resolvedURI = o.steps[1].toURI;
    }

    function testLiteralCompleteObservationDomainAndCanonicalEnvelope() public view {
        T.Configuration memory c;
        c.chainId = 17;
        c.core = address(1);
        T.Observation memory o = _observation();
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_RETRIEVAL_OBSERVATION_V1"),
                uint256(17),
                address(this),
                keccak256(abi.encode(keccak256("6529STREAM_VIEW_ATTRIBUTED_RETRIEVAL_V1"), c)),
                o
            )
        );
        require(probe.digest(c, address(this), o) == expected);
        (T.Observation memory actual, bytes memory sig) = probe.decode(abi.encode(o, hex"1234"));
        require(
            keccak256(abi.encode(actual)) == keccak256(abi.encode(o))
                && keccak256(sig) == keccak256(hex"1234")
        );
    }

    function testOriginQueryPercentAndExactArweavePathRemainLiteral() public view {
        (uint8 k,) = probe.uri("https://origin.invalid:443/path/%2f?q=1#fragment");
        require(k == 1);
        bytes32 tx_;
        (k, tx_) = probe.uri(string.concat(AR, "/index/assets/picture.png"));
        require(k == 3 && tx_ == 0x1253fd5eefb2a162efeb1e95cbb26d6cd50a617c6bb977e5107ea4c0b03540bd);
    }

    function testEveryRouteKindCoordinateIsClosedAndRestores() public {
        T.Observation memory o = _observation();
        T.Observation memory x = abi.decode(abi.encode(o), (T.Observation));
        x.steps[0].status = 200;
        vm.expectRevert(abi.encodeWithSelector(T.InvalidViewRetrieval.selector));
        probe.check(x);
        x = abi.decode(abi.encode(o), (T.Observation));
        x.steps[1].fromURI = "https://other.invalid/";
        vm.expectRevert(abi.encodeWithSelector(T.InvalidViewRetrieval.selector));
        probe.check(x);
        x = abi.decode(abi.encode(o), (T.Observation));
        x.steps[1].manifestBytes = hex"01";
        vm.expectRevert(abi.encodeWithSelector(T.InvalidViewRetrieval.selector));
        probe.check(x);
        x = abi.decode(abi.encode(o), (T.Observation));
        x.steps[1].toURI = x.steps[1].fromURI;
        vm.expectRevert(abi.encodeWithSelector(T.InvalidViewRetrieval.selector));
        probe.check(x);
        probe.check(o);
    }

    function testArweavePathNeedsExplicitFullManifestEvidenceAndResolvedTarget() public {
        T.Observation memory o = _observation();
        o.source.requestedURI = string.concat(AR, "/image.png");
        o.steps = new T.Step[](1);
        o.steps[0].kind = 3;
        o.steps[0].fromURI = o.source.requestedURI;
        o.steps[0].toURI = "ar://AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE";
        o.resolvedURI = o.steps[0].toURI;
        vm.expectRevert(abi.encodeWithSelector(T.InvalidViewRetrieval.selector));
        probe.check(o);
        o.steps[0].manifestObject = keccak256("manifest object");
        o.steps[0].manifestCoverage = keccak256("manifest pair");
        o.steps[0].manifestBytes =
            bytes("full manifest; semantic mapping remains signed attribution");
        probe.check(o);
        o.resolvedURI = string.concat(AR, "/still/unresolved");
        vm.expectRevert(abi.encodeWithSelector(T.InvalidViewRetrieval.selector));
        probe.check(o);
    }

    function testCanonicalBytesRejectTrailingDataWrongOffsetsAndNarrowWords() public {
        T.Observation memory o = _observation();
        bytes memory raw = abi.encode(o, hex"1234");
        bytes memory trailing = bytes.concat(raw, bytes32(0));
        vm.expectRevert(abi.encodeWithSelector(T.InvalidViewRetrieval.selector));
        probe.decode(trailing);
        bytes memory changed = abi.encode(o, hex"1234");
        assembly ("memory-safe") { mstore(add(changed, 32), 96) }
        vm.expectRevert();
        probe.decode(changed);
        o.steps[0].kind = 255;
        vm.expectRevert(abi.encodeWithSelector(T.InvalidViewRetrieval.selector));
        probe.check(o);
        probe.decode(raw);
    }

    function testAllSignedSourcePairWriterAndRouteMutationsChangeDigest() public view {
        T.Observation memory o = _observation();
        T.Configuration memory c;
        c.chainId = 17;
        bytes32 original = probe.digest(c, address(this), o);
        T.Observation memory x = abi.decode(abi.encode(o), (T.Observation));
        x.source.scope.scopeId = bytes32(uint256(99));
        require(probe.digest(c, address(this), x) != original);
        x = abi.decode(abi.encode(o), (T.Observation));
        x.coverage.firstReceiptHash = bytes32(uint256(1));
        require(probe.digest(c, address(this), x) != original);
        x = abi.decode(abi.encode(o), (T.Observation));
        x.writer = address(91);
        require(probe.digest(c, address(this), x) != original);
        x = abi.decode(abi.encode(o), (T.Observation));
        x.steps[0].status = 308;
        require(probe.digest(c, address(this), x) != original);
        require(probe.digest(c, address(71), o) != original);
        c.chainId = 18;
        require(probe.digest(c, address(this), o) != original);
    }

    function testFuzzCanonicalRoundTripBindsFullNonceAndExactURI(bytes32 salt, uint256 nonce)
        public
        view
    {
        T.Observation memory o = _observation();
        o.nonce = nonce;
        o.object.contentHash = salt == 0 ? bytes32(uint256(1)) : salt;
        bytes memory raw = abi.encode(o, bytes(""));
        (T.Observation memory result, bytes memory sig) = probe.decode(raw);
        require(sig.length == 0 && keccak256(abi.encode(result)) == keccak256(abi.encode(o)));
    }
}
