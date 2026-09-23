// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamMetadataContentRoot as Root
} from "../../../smart-contracts/domains/metadata/StreamMetadataContentRoot.sol";
import {
    StreamMetadataScopedContent as Scoped
} from "../../../smart-contracts/domains/metadata/StreamMetadataScopedContent.sol";
import {
    StreamMetadataScopedContentState as State
} from "../../../smart-contracts/domains/metadata/StreamMetadataScopedContentState.sol";
import {
    StreamMetadataRouterRootCodec as Codec
} from "../../../smart-contracts/domains/metadata/StreamMetadataRouterRootCodec.sol";
import {
    StreamMetadataSubjects as Subjects
} from "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import {
    StreamPolicyContentRootStateV2 as OldCollection
} from "../../../smart-contracts/domains/metadata/StreamPolicyContentRootStateV2.sol";
import {
    StreamMetadataScopedPolicyContentStateV2 as OldScoped
} from "../../../smart-contracts/domains/metadata/StreamMetadataScopedPolicyContentStateV2.sol";
import {
    StreamPreservationPolicyContentRootStateV1 as NewCollection
} from "../../../smart-contracts/domains/metadata/StreamPreservationPolicyContentRootStateV1.sol";
import {
    StreamMetadataScopedPreservationPolicyContentStateV1 as NewScoped
} from "../../../smart-contracts/domains/metadata/StreamMetadataScopedPreservationPolicyContentStateV1.sol";
import {
    IStreamContentRootPublication as R
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamContentRootPublication.sol";
import {
    IStreamScopedContentRootPublication as S
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamPreservationPolicyContentRootPublicationV1 as P
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamPreservationPolicyContentRootPublicationV1.sol";
import {
    IStreamScopedPreservationPolicyContentRootPublicationV1 as SP
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPreservationPolicyContentRootPublicationV1.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @dev Explicit injected-state boundary: no publication, producer, authority, snapshot, op17,
/// or actual Router deployment is claimed. Complete typed records and original companion maps
/// are seeded here; the production collection/scoped read and original codec execute unchanged.
contract PreservationStoredProfilesV2Host {
    address public constant CORE = address(0xC012);
    Root.State private roots;
    State.State private scopes;

    function seedCollection(
        bytes32 key,
        R.Record memory record,
        P.Binding memory binding_,
        bytes32 oldProfile
    ) external {
        roots.heads[record.publication.collectionId] = key;
        roots.records[key] = record;
        NewCollection.state().bindings[key] = binding_;
        OldCollection.state().bindings[key].profileId = oldProfile;
    }

    function seedScope(
        StreamFinalityScope memory requested,
        bytes32 key,
        S.Record memory record,
        SP.Binding memory binding_,
        bytes32 oldProfile
    ) external {
        scopes.heads[State.subject(CORE, requested)] = key;
        scopes.records[key] = record;
        NewScoped.state().bindings[key] = binding_;
        OldScoped.state().bindings[key].profileId = oldProfile;
    }

    function collection(uint256 cid, bytes32 subject)
        external
        view
        returns (bytes32, uint64, bytes32)
    {
        return Root.readRoot(roots, CORE, cid, subject);
    }

    function readScope(bytes calldata input) external view returns (bytes memory) {
        return Scoped.read(scopes, CORE, input);
    }

    function readOriginal(bytes calldata input) external view returns (bytes memory) {
        return Codec.read(roots, input);
    }
}

/// @notice Stored interpretation dispatch only; literal profiles come from the separate V2 definitions.
/// The schema returned below is the original six-field preservation leaf interpretation. These
/// cases do not authenticate an injected record as a genuinely published or admitted root.
contract StreamPreservationStoredRootProfilesV2Test {
    PreservationStoredProfilesV2Host private host;
    bytes32 private constant COLLECTION_V1 = keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1");
    bytes32 private constant COLLECTION_V2 = keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V2");
    bytes32 private constant SCOPED_V1 =
        keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_V1");
    bytes32 private constant SCOPED_V2 =
        keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_V2");
    bytes32 private constant FAMILY_V1 = keccak256("6529STREAM_PRESERVATION_RENDER_V1");
    bytes32 private constant FAMILY_V2 = keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2");
    bytes32 private constant LEAF = keccak256("STREAM_PRESERVATION_POLICY_TOKEN_CONTENT_LEAF_V1");
    bytes32 private constant KEY = keccak256("original injected record");
    bytes32 private constant CONTENT = keccak256("original six-field tree root");
    uint256 private constant CID = 17;

    function setUp() public {
        host = new PreservationStoredProfilesV2Host();
    }

    function testCollectionV2ReturnsOriginalLeafAndRetainsCompleteHistoryAndBinding() public {
        R.Record memory record = _collectionRecord(CONTENT, 37);
        P.Binding memory binding_ = _collectionBinding(COLLECTION_V2, FAMILY_V2);
        host.seedCollection(KEY, record, binding_, 0);
        _collectionResult(record.contentRoot, record.leafCount, LEAF);
        _collectionHistory(KEY, record, binding_);
        bytes32 next = keccak256("later injected collection head");
        R.Record memory later = abi.decode(abi.encode(record), (R.Record));
        later.publication.expectedPredecessor = KEY;
        later.publication.manifestURI = "urn:stored-root:later:with-a-distinct-dynamic-tail";
        later.contentRoot = keccak256("later content");
        later.leafCount = 41;
        host.seedCollection(next, later, binding_, 0);
        _collectionResult(later.contentRoot, later.leafCount, LEAF);
        _collectionHistory(KEY, record, binding_);
        _collectionHistory(next, later, binding_);
    }

    function testTokenReleaseAndSeasonV2ReturnOriginalLeafAndCompleteOriginalTuples() public {
        for (uint256 i; i < 3; ++i) {
            StreamFinalityScope memory scope = _scope(i);
            S.Record memory record = _scopedRecord(scope, bytes32(uint256(901 + i)), uint64(5 + i));
            SP.Binding memory binding_ = _scopedBinding(SCOPED_V2, FAMILY_V2);
            bytes32 key = bytes32(uint256(701 + i));
            host.seedScope(scope, key, record, binding_, 0);
            _scopedResult(scope, key, record.contentRoot, record.leafCount, LEAF);
            _scopedHistory(key, record, binding_);
        }
        // Writing the last scope cannot overwrite another scope's head or historical tuple.
        for (uint256 i; i < 3; ++i) {
            _scopedResult(
                _scope(i), bytes32(uint256(701 + i)), bytes32(uint256(901 + i)), uint64(5 + i), LEAF
            );
        }
    }

    function testV2RequiresExactFamilyAndEachRefusalRepairsWithoutChangingOriginalBytes() public {
        bytes32[4] memory wrong = [
            bytes32(0),
            FAMILY_V1,
            keccak256("6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1"),
            keccak256("unknown family")
        ];
        R.Record memory collection = _collectionRecord(CONTENT, 37);
        for (uint256 j; j < wrong.length; ++j) {
            host.seedCollection(KEY, collection, _collectionBinding(COLLECTION_V2, wrong[j]), 0);
            _collectionRefused();
            host.seedCollection(KEY, collection, _collectionBinding(COLLECTION_V2, FAMILY_V2), 0);
            _collectionResult(CONTENT, 37, LEAF);
            for (uint256 i; i < 3; ++i) {
                StreamFinalityScope memory scope = _scope(i);
                S.Record memory record = _scopedRecord(scope, CONTENT, 37);
                host.seedScope(scope, KEY, record, _scopedBinding(SCOPED_V2, wrong[j]), 0);
                _scopedRefused(scope);
                host.seedScope(scope, KEY, record, _scopedBinding(SCOPED_V2, FAMILY_V2), 0);
                _scopedResult(scope, KEY, CONTENT, 37, LEAF);
                _scopedHistory(KEY, record, _scopedBinding(SCOPED_V2, FAMILY_V2));
            }
        }
        _collectionHistory(KEY, collection, _collectionBinding(COLLECTION_V2, FAMILY_V2));
    }

    function testUnknownCrossProfileAndMixedOldBindingsRefuseThenRestore() public {
        R.Record memory collection = _collectionRecord(CONTENT, 37);
        bytes32[3] memory wrongCollection = [keccak256("unknown profile"), SCOPED_V2, SCOPED_V1];
        bytes32[3] memory wrongScoped = [keccak256("unknown profile"), COLLECTION_V2, COLLECTION_V1];
        for (uint256 j; j < 4; ++j) {
            bytes32 oldProfile = j == 3 ? keccak256("old policy binding") : bytes32(0);
            host.seedCollection(
                KEY,
                collection,
                _collectionBinding(j == 3 ? COLLECTION_V2 : wrongCollection[j], FAMILY_V2),
                oldProfile
            );
            _collectionRefused();
            host.seedCollection(KEY, collection, _collectionBinding(COLLECTION_V2, FAMILY_V2), 0);
            _collectionResult(CONTENT, 37, LEAF);
            for (uint256 i; i < 3; ++i) {
                StreamFinalityScope memory scope = _scope(i);
                S.Record memory record = _scopedRecord(scope, CONTENT, 37);
                host.seedScope(
                    scope,
                    KEY,
                    record,
                    _scopedBinding(j == 3 ? SCOPED_V2 : wrongScoped[j], FAMILY_V2),
                    oldProfile
                );
                _scopedRefused(scope);
                host.seedScope(scope, KEY, record, _scopedBinding(SCOPED_V2, FAMILY_V2), 0);
                _scopedResult(scope, KEY, CONTENT, 37, LEAF);
            }
        }
    }

    function testEachStoredScopeCoordinateIsComparedAndCollectionWrongSubjectStaysEmpty() public {
        for (uint256 i; i < 3; ++i) {
            StreamFinalityScope memory scope = _scope(i);
            S.Record memory original = _scopedRecord(scope, CONTENT, 37);
            for (uint256 j; j < 4; ++j) {
                S.Record memory changed = abi.decode(abi.encode(original), (S.Record));
                if (j == 0) {
                    changed.publication.scope.scopeType = StreamFinalityScopeType.COLLECTION;
                }
                if (j == 1) changed.publication.scope.collectionId += 1;
                if (j == 2) changed.publication.scope.tokenId += 1;
                if (j == 3) {
                    changed.publication.scope.scopeId = keccak256("different retained scope id");
                }
                host.seedScope(scope, KEY, changed, _scopedBinding(SCOPED_V2, FAMILY_V2), 0);
                _scopedRefused(scope);
                // The historical Record getter remains a literal dossier read despite bad head eligibility.
                _equal(
                    host.readScope(abi.encodeCall(S.scopedContentRootRecord, (KEY))),
                    abi.encode(changed)
                );
                host.seedScope(scope, KEY, original, _scopedBinding(SCOPED_V2, FAMILY_V2), 0);
                _scopedResult(scope, KEY, CONTENT, 37, LEAF);
            }
        }
        host.seedCollection(
            KEY,
            _collectionRecord(CONTENT, 37),
            _collectionBinding(keccak256("unknown profile"), FAMILY_V2),
            0
        );
        (bytes32 root, uint64 count, bytes32 schema) =
            host.collection(CID, keccak256("foreign subject"));
        require(root == 0 && count == 0 && schema == 0, "original subject short circuit");
        _collectionRefused();
        host.seedCollection(
            KEY, _collectionRecord(CONTENT, 37), _collectionBinding(COLLECTION_V2, FAMILY_V2), 0
        );
        _collectionResult(CONTENT, 37, LEAF);
    }

    function testUnknownKeysSelectorsAndZeroLeafKeepOriginalBehavior() public {
        _collectionResult(0, 0, 0);
        for (uint256 i; i < 3; ++i) {
            _scopedResult(_scope(i), 0, 0, 0, 0);
        }
        bytes32 unknown = keccak256("never injected");
        _revertCall(
            abi.encodeCall(host.readOriginal, (abi.encodeCall(R.contentRootRecord, (unknown)))),
            abi.encodeWithSelector(R.ContentRootRecordUnknown.selector, unknown)
        );
        _revertCall(
            abi.encodeCall(host.readScope, (abi.encodeCall(S.scopedContentRootRecord, (unknown)))),
            abi.encodeWithSelector(S.ScopedContentRootUnknown.selector, unknown)
        );
        _revertCall(
            abi.encodeCall(
                host.readOriginal, (abi.encodeWithSelector(bytes4(0xdeadbeef), unknown))
            ),
            abi.encodeWithSelector(R.InvalidContentRootPublication.selector)
        );
        _revertCall(
            abi.encodeCall(host.readScope, (abi.encodeWithSelector(bytes4(0xdeadbeef), unknown))),
            abi.encodeWithSelector(S.InvalidScopedContentRoot.selector)
        );
        _equal(
            host.readOriginal(abi.encodeCall(P.preservationPolicyContentRootBinding, (unknown))),
            abi.encode(
                P.Binding(
                    0,
                    address(0),
                    0,
                    address(0),
                    0,
                    0,
                    0,
                    address(0),
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    address(0),
                    0
                )
            )
        );
        host.seedCollection(
            KEY, _collectionRecord(CONTENT, 0), _collectionBinding(COLLECTION_V2, FAMILY_V2), 0
        );
        _collectionResult(CONTENT, 0, 0);
        for (uint256 i; i < 3; ++i) {
            StreamFinalityScope memory scope = _scope(i);
            host.seedScope(
                scope,
                KEY,
                _scopedRecord(scope, CONTENT, 0),
                _scopedBinding(SCOPED_V2, FAMILY_V2),
                0
            );
            _scopedResult(scope, KEY, CONTENT, 0, 0);
            host.seedScope(
                scope, KEY, _scopedRecord(scope, CONTENT, 0), _scopedBinding(SCOPED_V2, 0), 0
            );
            _scopedRefused(scope); // Zero count must not bypass profile/family authentication.
            host.seedScope(
                scope,
                KEY,
                _scopedRecord(scope, CONTENT, 0),
                _scopedBinding(SCOPED_V2, FAMILY_V2),
                0
            );
            _scopedResult(scope, KEY, CONTENT, 0, 0);
        }
        host.seedCollection(
            KEY, _collectionRecord(CONTENT, 0), _collectionBinding(COLLECTION_V2, 0), 0
        );
        _collectionRefused();
        host.seedCollection(
            KEY, _collectionRecord(CONTENT, 0), _collectionBinding(COLLECTION_V2, FAMILY_V2), 0
        );
        _collectionResult(CONTENT, 0, 0);
    }

    function testOriginalV1AndOldPolicyBranchesKeepTheirStoredInterpretation() public {
        bytes32[3] memory oldCollection =
            [bytes32(0), keccak256("original policy profile"), bytes32(0)];
        bytes32[3] memory oldScoped =
            [bytes32(0), keccak256("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_V2"), bytes32(0)];
        bytes32[3] memory collectionSchema = [
            keccak256("STREAM_TOKEN_CONTENT_LEAF_MANIFEST_V1"),
            keccak256("STREAM_POLICY_TOKEN_CONTENT_LEAF_V2"),
            LEAF
        ];
        bytes32[3] memory scopedSchema = [
            keccak256("STREAM_TOKEN_CONTENT_LEAF_MANIFEST_V1"),
            keccak256("STREAM_SCOPED_POLICY_TOKEN_CONTENT_LEAF_V2"),
            LEAF
        ];
        for (uint256 j; j < 3; ++j) {
            host.seedCollection(
                KEY,
                _collectionRecord(CONTENT, 37),
                _collectionBinding(j == 2 ? COLLECTION_V1 : bytes32(0), FAMILY_V1),
                oldCollection[j]
            );
            _collectionResult(CONTENT, 37, collectionSchema[j]);
            for (uint256 i; i < 3; ++i) {
                StreamFinalityScope memory scope = _scope(i);
                host.seedScope(
                    scope,
                    KEY,
                    _scopedRecord(scope, CONTENT, 37),
                    _scopedBinding(j == 2 ? SCOPED_V1 : bytes32(0), FAMILY_V1),
                    oldScoped[j]
                );
                _scopedResult(scope, KEY, CONTENT, 37, scopedSchema[j]);
            }
        }
        // Preserve V1's historical dispatch exactly: its read path did not reauthenticate this field.
        // This deliberately injected state is not an assertion that any writer could admit it.
        host.seedCollection(
            KEY, _collectionRecord(CONTENT, 37), _collectionBinding(COLLECTION_V1, 0), 0
        );
        _collectionResult(CONTENT, 37, LEAF);
        StreamFinalityScope memory scope = _scope(1);
        host.seedScope(
            scope, KEY, _scopedRecord(scope, CONTENT, 37), _scopedBinding(SCOPED_V1, 0), 0
        );
        _scopedResult(scope, KEY, CONTENT, 37, LEAF);
    }

    function testFuzzV2ReadPreservesPayloadCountAndOriginalLeafMeaning(
        bytes32 content,
        uint64 count
    ) public {
        bytes32 schema = count == 0 ? bytes32(0) : LEAF;
        R.Record memory collection = _collectionRecord(content, count);
        P.Binding memory binding_ = _collectionBinding(COLLECTION_V2, FAMILY_V2);
        host.seedCollection(KEY, collection, binding_, 0);
        _collectionResult(content, count, schema);
        _collectionHistory(KEY, collection, binding_);
        for (uint256 i; i < 3; ++i) {
            StreamFinalityScope memory scope = _scope(i);
            S.Record memory record = _scopedRecord(scope, content, count);
            SP.Binding memory scopedBinding = _scopedBinding(SCOPED_V2, FAMILY_V2);
            host.seedScope(scope, KEY, record, scopedBinding, 0);
            _scopedResult(scope, KEY, content, count, schema);
            _scopedHistory(KEY, record, scopedBinding);
        }
    }

    function _scope(uint256 i) private pure returns (StreamFinalityScope memory) {
        if (i == 0) return StreamFinalityScope(StreamFinalityScopeType.TOKEN, CID, 170003, 0);
        return StreamFinalityScope(
            i == 1 ? StreamFinalityScopeType.RELEASE : StreamFinalityScopeType.SEASON,
            CID,
            0,
            bytes32(uint256(80 + i))
        );
    }

    function _subject() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SUBJECT_COLLECTION_V1"), block.chainid, host.CORE(), CID
            )
        );
    }

    function _collectionRecord(bytes32 content, uint64 count)
        private
        view
        returns (R.Record memory r)
    {
        r.publication = R.Publication(
            CID,
            bytes32(uint256(101)),
            bytes32(uint256(102)),
            "urn:stored-root:original:collection:dynamic-uri"
        );
        r.contentRoot = content;
        r.leafCount = count;
        r.manifestHash = bytes32(uint256(103));
        r.artistId = bytes32(uint256(104));
        r.bindingGeneration = 105;
        r.bindingHash = bytes32(uint256(106));
        r.publisher = address(this);
        r.authorizationClass = 7;
        r.grantRevision = 108;
        r.routeHash = bytes32(uint256(109));
        r.stateHash = bytes32(uint256(110));
        r.artistConsent = bytes32(uint256(111));
        r.publishedAt = 112;
    }

    function _scopedRecord(StreamFinalityScope memory scope, bytes32 content, uint64 count)
        private
        view
        returns (S.Record memory r)
    {
        r.publication = S.Publication(
            scope,
            bytes32(uint256(201)),
            bytes32(uint256(202)),
            203,
            "urn:stored-root:original:scoped:distinct-dynamic-uri"
        );
        r.snapshotHost = address(0x204);
        r.snapshotCodeHash = bytes32(uint256(205));
        r.snapshotManifestHash = bytes32(uint256(206));
        r.snapshotSourceHash = bytes32(uint256(207));
        r.contentRoot = content;
        r.leafCount = count;
        r.outputManifestHash = bytes32(uint256(208));
        r.artistId = bytes32(uint256(209));
        r.bindingGeneration = 210;
        r.bindingHash = bytes32(uint256(211));
        r.publisher = address(this);
        r.authorizationClass = 8;
        r.grantRevision = 213;
        r.routeHash = bytes32(uint256(214));
        r.stateHash = bytes32(uint256(215));
        r.artistConsent = bytes32(uint256(216));
        r.publishedAt = 217;
    }

    function _collectionBinding(bytes32 profile, bytes32 family)
        private
        view
        returns (P.Binding memory b)
    {
        b = P.Binding(
            profile,
            address(0x301),
            bytes32(uint256(302)),
            address(0x303),
            bytes32(uint256(304)),
            bytes32(uint256(305)),
            bytes32(uint256(306)),
            address(0x307),
            bytes32(uint256(308)),
            bytes32(uint256(309)),
            bytes32(uint256(310)),
            bytes32(uint256(311)),
            bytes32(uint256(312)),
            bytes32(uint256(313)),
            bytes32(uint256(314)),
            bytes32(uint256(315)),
            bytes32(uint256(316)),
            address(host),
            family
        );
    }

    function _scopedBinding(bytes32 profile, bytes32 family)
        private
        view
        returns (SP.Binding memory b)
    {
        b = SP.Binding(
            profile,
            address(0x401),
            bytes32(uint256(402)),
            address(0x403),
            bytes32(uint256(404)),
            bytes32(uint256(405)),
            bytes32(uint256(406)),
            address(0x407),
            bytes32(uint256(408)),
            bytes32(uint256(409)),
            bytes32(uint256(410)),
            bytes32(uint256(411)),
            bytes32(uint256(412)),
            bytes32(uint256(413)),
            bytes32(uint256(414)),
            bytes32(uint256(415)),
            bytes32(uint256(416)),
            address(0x417),
            bytes32(uint256(418)),
            bytes32(uint256(419)),
            bytes32(uint256(420)),
            bytes32(uint256(421)),
            bytes32(uint256(422)),
            address(host),
            family
        );
    }

    function _collectionResult(bytes32 content, uint64 count, bytes32 schema) private view {
        (bytes32 actual, uint64 size, bytes32 interpretation) = host.collection(CID, _subject());
        _equal(abi.encode(actual, size, interpretation), abi.encode(content, count, schema));
    }

    function _scopedResult(
        StreamFinalityScope memory scope,
        bytes32 key,
        bytes32 content,
        uint64 count,
        bytes32 schema
    ) private view {
        _equal(
            host.readScope(abi.encodeCall(S.scopedTokenContentRoot, (scope))),
            abi.encode(content, count, schema)
        );
        _equal(host.readScope(abi.encodeCall(S.scopedContentRootHead, (scope))), abi.encode(key));
    }

    function _collectionHistory(bytes32 key, R.Record memory record, P.Binding memory binding_)
        private
        view
    {
        _equal(host.readOriginal(abi.encodeCall(R.contentRootRecord, (key))), abi.encode(record));
        bytes memory raw =
            host.readOriginal(abi.encodeCall(P.preservationPolicyContentRootBinding, (key)));
        require(raw.length == 608, "original19-word collection binding");
        _equal(raw, abi.encode(binding_));
    }

    function _scopedHistory(bytes32 key, S.Record memory record, SP.Binding memory binding_)
        private
        view
    {
        _equal(host.readScope(abi.encodeCall(S.scopedContentRootRecord, (key))), abi.encode(record));
        bytes memory raw =
            host.readOriginal(abi.encodeCall(SP.scopedPreservationPolicyContentRootBinding, (key)));
        require(raw.length == 800, "original25-word scoped binding");
        _equal(raw, abi.encode(binding_));
    }

    function _collectionRefused() private view {
        _revertCall(
            abi.encodeCall(host.collection, (CID, _subject())),
            abi.encodeWithSelector(R.InvalidContentRootPublication.selector)
        );
    }

    function _scopedRefused(StreamFinalityScope memory scope) private view {
        bytes memory expected = abi.encodeWithSelector(S.InvalidScopedContentRoot.selector);
        _revertCall(
            abi.encodeCall(host.readScope, (abi.encodeCall(S.scopedTokenContentRoot, (scope)))),
            expected
        );
        _revertCall(
            abi.encodeCall(host.readScope, (abi.encodeCall(S.scopedContentRootHead, (scope)))),
            expected
        );
    }

    function _revertCall(bytes memory input, bytes memory expected) private view {
        (bool ok, bytes memory error_) = address(host).staticcall(input);
        require(!ok, "bad stored interpretation accepted");
        _equal(error_, expected);
    }

    function _equal(bytes memory a, bytes memory b) private pure {
        require(keccak256(a) == keccak256(b), "full original tuple mismatch");
    }
}
