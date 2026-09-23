// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityPreparedSanctionReview.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../../smart-contracts/domains/artist/StreamArtistSanctionCandidate.sol";
import {
    StreamFinalityPreparedScopeReads as PreparedReads
} from "../../../smart-contracts/domains/finality/StreamFinalityPreparedScopeReads.sol";
import {
    StreamFinalityViewPreservationOperationsV1 as Operations
} from "../../../smart-contracts/domains/finality/StreamFinalityViewPreservationOperationsV1.sol";
import {
    StreamFinalityNativeProviderReads as Native
} from "../../../smart-contracts/domains/finality/StreamFinalityNativeProviderReads.sol";

/// @dev Explicit already-validated Registry/provider transport boundary, not a currentness mock.
contract ViewSanctionTransportBoundary {
    bytes private reviewBytes;
    bool private combined;
    bool private breakCombined;
    bytes32 private schema;
    bytes32 private canon;
    StreamFinalityScope private selected;

    function configure(
        bytes memory raw,
        bool enabled,
        StreamFinalityScope memory scope,
        bytes32 s,
        bytes32 c
    ) external {
        reviewBytes = raw;
        combined = enabled;
        selected = scope;
        schema = s;
        canon = c;
    }

    function failCombined(bool value) external {
        breakCombined = value;
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        return combined
            && (id == type(IStreamArtistSanctionReviewPreparation).interfaceId
                || id == type(IStreamFinalityPreparedSanctionReview).interfaceId);
    }

    function getSatellitePointer(bytes32 key)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        require(
            key == keccak256("ARTIST_REGISTRY") || key == keccak256("ARTWORK_FINALITY_REGISTRY")
        );
        return (address(this), address(this).codehash, false, 0, bytes4(0), address(0), 0, 0, 0, 0);
    }

    function _scope(StreamFinalityScope memory scope) private view {
        require(
            keccak256(abi.encode(scope)) == keccak256(abi.encode(selected)),
            "exact original complete scope"
        );
    }

    function _preparation(StreamFinalityScope memory scope, StreamFinalityManifestRef memory m)
        private
        view
        returns (StreamArtistSanctionPreparation memory p)
    {
        _scope(scope);
        require(
            m.contentHash == keccak256("manifest") && m.schemaId == schema
                && m.canonicalizationHash == canon
        );
        // Independent literal original subject preimage, no call to the production subject helper.
        p = StreamArtistSanctionPreparation(
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_SANCTION_SUBJECT_V1"),
                    block.chainid,
                    address(this),
                    address(this),
                    uint8(scope.scopeType),
                    scope.collectionId,
                    scope.tokenId,
                    scope.scopeId,
                    keccak256("core"),
                    keccak256("components"),
                    m.uriHash,
                    m.contentHash,
                    m.schemaId,
                    m.canonicalizationHash
                )
            ),
            keccak256("core"),
            keccak256("components"),
            keccak256("inputs")
        );
    }

    function _inputs() private pure returns (StreamFinalityScopeInputs memory f) {
        f = StreamFinalityScopeInputs(
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            bytes32(uint256(3)),
            bytes32(uint256(4)),
            0,
            bytes32(uint256(6)),
            bytes32(uint256(7)),
            bytes32(uint256(8)),
            bytes32(uint256(9)),
            bytes32(uint256(10))
        );
    }

    function _tail() private view returns (bytes memory tail) {
        bytes memory raw = reviewBytes;
        require(raw.length >= 32);
        tail = new bytes(raw.length - 32);
        for (uint256 i; i < tail.length; ++i) {
            tail[i] = raw[i + 32];
        }
    }

    fallback(bytes calldata data) external returns (bytes memory) {
        if (
            msg.sig == IStreamArtistSanctionPreparation.prepareSanction.selector
                || msg.sig
                    == IStreamArtistSanctionReviewPreparation.prepareSanctionWithReview.selector
        ) {
            (StreamFinalityScope memory s,, StreamFinalityManifestRef memory m) = abi.decode(
                data[4:],
                (
                    StreamFinalityScope,
                    StreamFinalityComponentExpectation[],
                    StreamFinalityManifestRef
                )
            );
            StreamArtistSanctionPreparation memory p = _preparation(s, m);
            if (msg.sig == IStreamArtistSanctionPreparation.prepareSanction.selector) {
                return abi.encode(p);
            }
            require(!breakCombined, "advertised combined refuses");
            return bytes.concat(abi.encode(p, uint256(160)), _tail());
        }
        if (
            msg.sig
                == IStreamFinalityPreparedSanctionReview.requirePreparedFinalityScopeInputsAndReview
                .selector
        ) {
            (StreamFinalityScope memory s, bytes32 hash,) = abi.decode(
                data[4:], (StreamFinalityScope, bytes32, StreamFinalityComponentExpectation[])
            );
            _scope(s);
            require(hash == keccak256("manifest") && !breakCombined, "advertised combined refuses");
            return bytes.concat(abi.encode(_inputs(), schema, canon, uint256(416)), _tail());
        }
        (StreamFinalityScope memory s, bytes32 hash) =
            abi.decode(data[4:], (StreamFinalityScope, bytes32));
        _scope(s);
        require(hash == keccak256("manifest"));
        if (msg.sig == IStreamFinalityScopeEvidence.requireFinalityScopeInputs.selector) {
            return abi.encode(_inputs(), schema, canon);
        }
        require(
            msg.sig == IStreamFinalitySanctionReview.requireSanctionReviewFacts.selector,
            "closed typed selectors"
        );
        return reviewBytes;
    }
}

contract ViewSanctionTransportProbe {
    function candidate(
        address target,
        StreamFinalityScope memory scope,
        bytes32 schema,
        bytes32 canon
    ) external view returns (Q.Prepared memory) {
        Q.Request memory q;
        q.terms.scopeType = uint8(scope.scopeType);
        q.terms.collectionId = scope.collectionId;
        q.terms.tokenId = scope.tokenId;
        q.terms.scopeId = scope.scopeId;
        q.manifest = StreamFinalityManifestRef(
            "ipfs://manifest", keccak256("uri"), keccak256("manifest"), schema, canon
        );
        q.statement = "Full current VIEW media and reference occurrences";
        q.signingToolName = "typed test";
        q.signingToolVersion = "1";
        return StreamArtistSanctionCandidate.prepare(
            StreamArtistHashes.Environment(block.chainid, target, target, target),
            StreamArtistSanctionCandidate.Pins(
                target, target.codehash, target, target.codehash, 2000000
            ),
            q
        );
    }

    function prepared(
        address target,
        StreamFinalityScope memory scope,
        StreamFinalityComponentExpectation[] calldata c
    ) external view returns (bytes memory, IStreamFinalitySanctionReview.ReviewFacts memory) {
        return PreparedReads.readWithReview(target, scope, keccak256("manifest"), c, 2000000);
    }

    function operation(
        Native.Config memory c,
        StreamFinalityScope memory scope,
        StreamFinalityComponentExpectation[] calldata rows
    ) external view {
        Operations.prepared(c, scope, keccak256("manifest"), rows, true);
    }
}

contract StreamFinalityViewSanctionTransportV1Test is CharacterizationTestBase {
    ViewSanctionTransportBoundary private boundary;
    ViewSanctionTransportProbe private probe;
    bytes32 private constant SCHEMA = keccak256("STREAM_VIEW_PRESERVATION_FINALITY_INPUT_V1");
    bytes32 private constant CANON = keccak256("STREAM_VIEW_PRESERVATION_FINALITY_INPUT_ABI_V1");

    function setUp() public {
        boundary = new ViewSanctionTransportBoundary();
        probe = new ViewSanctionTransportProbe();
    }

    function _scope() private pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(
            StreamFinalityScopeType.VIEW, 7, 0, keccak256("sealed membership")
        );
    }

    function _facts(uint256 media, uint256 refs, uint8 profile)
        private
        pure
        returns (IStreamFinalitySanctionReview.ReviewFacts memory r)
    {
        r = IStreamFinalitySanctionReview.ReviewFacts(
            1, profile, keccak256("root"), new bytes32[](media), new bytes32[](refs)
        );
        for (uint256 i; i < media; ++i) {
            r.mediaContentHashes[i] = keccak256(abi.encode("actual media", i));
        }
        for (uint256 i; i < refs; ++i) {
            r.referenceRenderContentHashes[i] = keccak256(abi.encode("actual reference", i));
        }
    }

    function _check(
        IStreamFinalitySanctionReview.ReviewFacts memory r,
        bool combined,
        StreamFinalityScope memory scope
    ) private {
        boundary.configure(abi.encode(r), combined, scope, SCHEMA, CANON);
        Q.Prepared memory p = probe.candidate(address(boundary), scope, SCHEMA, CANON);
        S.Ceremony memory ceremony = S.Ceremony(
            r.contentRoot,
            r.mediaContentHashes,
            r.referenceRenderContentHashes,
            "Full current VIEW media and reference occurrences",
            "typed test",
            "1"
        );
        require(
            p.reviewFactsHash == keccak256(abi.encode(r))
                && p.scopeInputsHash == keccak256("inputs")
        );
        require(
            keccak256(p.ceremony)
                == keccak256(StreamArtistSanctionCeremony.document(p.subject, ceremony)),
            "exact original ceremony including both arrays"
        );
        require(
            p.subject.scopeType == uint8(scope.scopeType) && p.subject.scopeId == scope.scopeId
                && p.subject.core == address(boundary)
                && p.subject.finalityRegistry == address(boundary)
        );
        (bytes memory inputs, IStreamFinalitySanctionReview.ReviewFacts memory observed) =
            probe.prepared(address(boundary), scope, new StreamFinalityComponentExpectation[](0));
        StreamFinalityScopeInputs memory expected = StreamFinalityScopeInputs(
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            bytes32(uint256(3)),
            bytes32(uint256(4)),
            0,
            bytes32(uint256(6)),
            bytes32(uint256(7)),
            bytes32(uint256(8)),
            bytes32(uint256(9)),
            bytes32(uint256(10))
        );
        require(
            keccak256(inputs) == keccak256(abi.encode(expected, SCHEMA, CANON))
                && keccak256(abi.encode(observed)) == keccak256(abi.encode(r)),
            "exact all12 input words and review across both caller routes"
        );
    }

    function testViewMediaMinAndMaxReachOriginalCeremonyOnBothRoutes() public {
        for (uint256 i; i < 2; ++i) {
            _check(_facts(1, 1, 3), i == 1, _scope());
            _check(_facts(16, 16, 3), i == 1, _scope());
        }
    }

    function testOldProfilesRemainAdmittedForOriginalAndViewScopes() public {
        StreamFinalityScope memory collection =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 7, 0, 0);
        for (uint256 i; i < 2; ++i) {
            _check(_facts(0, 1, 1), i == 1, collection);
            _check(_facts(0, 16, 2), i == 1, collection);
            _check(_facts(0, 2, 2), i == 1, _scope());
        }
    }

    function testNonViewAndWrongManifestCannotPromoteProfileThree() public {
        for (uint256 i; i < 2; ++i) {
            StreamFinalityScope memory s = _scope();
            s.scopeType = StreamFinalityScopeType.RELEASE;
            boundary.configure(abi.encode(_facts(1, 1, 3)), i == 1, s, SCHEMA, CANON);
            vm.expectRevert(abi.encodeWithSelector(ViewReview.InvalidViewSanctionReview.selector));
            probe.candidate(address(boundary), s, SCHEMA, CANON);
            vm.expectRevert(abi.encodeWithSelector(ViewReview.InvalidViewSanctionReview.selector));
            probe.prepared(address(boundary), s, new StreamFinalityComponentExpectation[](0));
            s = _scope();
            boundary.configure(abi.encode(_facts(1, 1, 3)), i == 1, s, bytes32(uint256(1)), CANON);
            vm.expectRevert(abi.encodeWithSelector(ViewReview.InvalidViewSanctionReview.selector));
            probe.candidate(address(boundary), s, bytes32(uint256(1)), CANON);
            vm.expectRevert(abi.encodeWithSelector(ViewReview.InvalidViewSanctionReview.selector));
            probe.prepared(address(boundary), s, new StreamFinalityComponentExpectation[](0));
            _check(_facts(1, 1, 3), i == 1, s);
        }
    }

    function testMalformedProfileThreeOffsetAndCountsRefuseBothPreparedRoutes() public {
        for (uint256 i; i < 2; ++i) {
            bytes memory raw = abi.encode(_facts(1, 1, 3));
            assembly ("memory-safe") { mstore(add(raw, 192), not(0)) }
            boundary.configure(raw, i == 1, _scope(), SCHEMA, CANON);
            vm.expectRevert(abi.encodeWithSelector(ViewReview.InvalidViewSanctionReview.selector));
            probe.candidate(address(boundary), _scope(), SCHEMA, CANON);
            vm.expectRevert(abi.encodeWithSelector(ViewReview.InvalidViewSanctionReview.selector));
            probe.prepared(address(boundary), _scope(), new StreamFinalityComponentExpectation[](0));
            _check(_facts(1, 1, 3), i == 1, _scope());
        }
    }

    function testAdvertisedCombinedFailureIsTerminalOnBothCallers() public {
        boundary.configure(abi.encode(_facts(1, 1, 3)), true, _scope(), SCHEMA, CANON);
        boundary.failCombined(true);
        bytes memory error = abi.encodeWithSelector(
            StreamFinalitySanctionReviewReads.SanctionReviewReadFailed.selector, address(boundary)
        );
        vm.expectRevert(error);
        probe.candidate(address(boundary), _scope(), SCHEMA, CANON);
        vm.expectRevert(error);
        probe.prepared(address(boundary), _scope(), new StreamFinalityComponentExpectation[](0));
        boundary.failCombined(false);
        _check(_facts(1, 1, 3), true, _scope());
    }

    function testPreparedViewOperationRejectsCallerBeforeAnySourceRead() public {
        Native.Config memory c;
        c.targets[12] = address(boundary);
        c.codeHashes[12] = address(boundary).codehash;
        vm.expectRevert(abi.encodeWithSelector(Operations.PolicyProviderRegistryOnly.selector));
        probe.operation(c, _scope(), new StreamFinalityComponentExpectation[](0));
    }
}
