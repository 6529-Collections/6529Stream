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

/// @dev Only the common read/dispatch seam. Stored records are deliberately injected, so these
/// tests cannot prove authority, output validity, snapshot production or actual Router deployment.
/// The separate writer suites exercise the real codec/consent sequence with declared boundaries.
contract PreservationRootReadHost {
    address public constant CORE = address(0x1234);
    Root.State private roots;
    State.State private scopes;

    function seedCollection(
        bytes32 key,
        bytes32 content,
        uint64 count,
        bytes32 oldProfile,
        bytes32 newProfile
    ) external {
        roots.heads[1] = key;
        R.Record storage record = roots.records[key];
        record.publisher = msg.sender;
        record.publication.collectionId = 1;
        record.contentRoot = content;
        record.leafCount = count;
        OldCollection.state().bindings[key].profileId = oldProfile;
        NewCollection.state().bindings[key].profileId = newProfile;
        NewCollection.state().bindings[key].metadataRouter = address(this);
        NewCollection.state().bindings[key].preservationOutputProfile =
            keccak256("6529STREAM_PRESERVATION_RENDER_V1");
    }

    function seedScope(
        StreamFinalityScope memory requested,
        StreamFinalityScope memory recorded,
        bytes32 key,
        bytes32 content,
        uint64 count,
        bytes32 oldProfile,
        bytes32 newProfile
    ) external {
        scopes.heads[State.subject(CORE, requested)] = key;
        S.Record storage record = scopes.records[key];
        record.publisher = msg.sender;
        record.publication.scope = recorded;
        record.contentRoot = content;
        record.leafCount = count;
        OldScoped.state().bindings[key].profileId = oldProfile;
        NewScoped.state().bindings[key].profileId = newProfile;
        NewScoped.state().bindings[key].metadataRouter = address(this);
        NewScoped.state().bindings[key].preservationOutputProfile =
            keccak256("6529STREAM_PRESERVATION_RENDER_V1");
    }

    function collection(bytes32 subject) external view returns (bytes32, uint64, bytes32) {
        return Root.readRoot(roots, CORE, 1, subject);
    }

    function readScope(bytes calldata input) external view returns (bytes memory) {
        return Scoped.read(scopes, CORE, input);
    }

    function readBinding(bytes calldata input) external view returns (bytes memory) {
        return Codec.read(roots, input);
    }

    function collectionSubject() external view returns (bytes32) {
        return Subjects.scopeSubject(
            block.chainid, CORE, StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0)
        );
    }
}

contract StreamPreservationRootReadDispatchTest {
    PreservationRootReadHost private host;
    bytes32 private constant CP = keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1");
    bytes32 private constant SPROFILE =
        keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_V1");
    bytes32 private constant NEW_LEAF =
        keccak256("STREAM_PRESERVATION_POLICY_TOKEN_CONTENT_LEAF_V1");

    function setUp() public {
        host = new PreservationRootReadHost();
    }

    function _scope() private pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(StreamFinalityScopeType.RELEASE, 1, 0, bytes32(uint256(7)));
    }

    function _collectionSchema() private view returns (bytes32 schema) {
        (,, schema) = host.collection(host.collectionSubject());
    }

    function _scopedSchema(StreamFinalityScope memory scope) private view returns (bytes32 schema) {
        (,, schema) = abi.decode(
            host.readScope(abi.encodeCall(S.scopedTokenContentRoot, (scope))),
            (bytes32, uint64, bytes32)
        );
    }

    function testCollectionProfilesKeepLiteralLeafSchemasAndWrongSubjectEmpty() public {
        host.seedCollection(bytes32(uint256(1)), bytes32(uint256(9)), 2, 0, 0);
        require(
            _collectionSchema() == keccak256("STREAM_TOKEN_CONTENT_LEAF_MANIFEST_V1"),
            "original leaf"
        );
        host.seedCollection(bytes32(uint256(2)), bytes32(uint256(9)), 2, keccak256("old"), 0);
        require(
            _collectionSchema() == keccak256("STREAM_POLICY_TOKEN_CONTENT_LEAF_V2"), "policy leaf"
        );
        host.seedCollection(bytes32(uint256(3)), bytes32(uint256(9)), 2, 0, CP);
        require(_collectionSchema() == NEW_LEAF, "preservation leaf");
        (bytes32 content, uint64 count, bytes32 schema) = host.collection(bytes32(uint256(99)));
        require(content == 0 && count == 0 && schema == 0, "foreign subject");
    }

    function testScopedProfilesAndHeadReadPreserveScope() public {
        StreamFinalityScope memory scope = _scope();
        host.seedScope(scope, scope, bytes32(uint256(1)), bytes32(uint256(9)), 2, 0, 0);
        require(
            _scopedSchema(scope) == keccak256("STREAM_TOKEN_CONTENT_LEAF_MANIFEST_V1"),
            "original scoped leaf"
        );
        host.seedScope(
            scope,
            scope,
            bytes32(uint256(2)),
            bytes32(uint256(9)),
            2,
            keccak256("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_V2"),
            0
        );
        require(
            _scopedSchema(scope) == keccak256("STREAM_SCOPED_POLICY_TOKEN_CONTENT_LEAF_V2"),
            "policy scoped leaf"
        );
        host.seedScope(scope, scope, bytes32(uint256(3)), bytes32(uint256(9)), 2, 0, SPROFILE);
        require(_scopedSchema(scope) == NEW_LEAF, "preservation scoped leaf");
        require(
            abi.decode(host.readScope(abi.encodeCall(S.scopedContentRootHead, (scope))), (bytes32))
                == bytes32(uint256(3)),
            "shared head"
        );
    }

    function testPreservationBindingsHaveExactWidthsAndSeparateNamespaces() public {
        bytes32 key = bytes32(uint256(1));
        host.seedCollection(key, bytes32(uint256(9)), 2, 0, CP);
        bytes memory raw =
            host.readBinding(abi.encodeCall(P.preservationPolicyContentRootBinding, (key)));
        P.Binding memory binding = abi.decode(raw, (P.Binding));
        require(
            raw.length == 608 && binding.profileId == CP && binding.metadataRouter == address(host),
            "collection binding"
        );
        bytes memory absent =
            host.readBinding(abi.encodeCall(SP.scopedPreservationPolicyContentRootBinding, (key)));
        require(
            absent.length == 800 && abi.decode(absent, (SP.Binding)).profileId == 0,
            "namespace isolation"
        );
        StreamFinalityScope memory scope = _scope();
        host.seedScope(scope, scope, key, bytes32(uint256(9)), 2, 0, SPROFILE);
        raw = host.readBinding(abi.encodeCall(SP.scopedPreservationPolicyContentRootBinding, (key)));
        SP.Binding memory scoped = abi.decode(raw, (SP.Binding));
        require(
            raw.length == 800 && scoped.profileId == SPROFILE
                && scoped.metadataRouter == address(host),
            "scoped binding"
        );
        require(
            binding.preservationOutputProfile == scoped.preservationOutputProfile,
            "shared producer profile"
        );
    }

    function testCollectionUnknownOrAmbiguousPreservationProfileRefused() public {
        host.seedCollection(bytes32(uint256(1)), bytes32(uint256(9)), 2, 0, keccak256("unknown"));
        (bool ok,) =
            address(host).staticcall(abi.encodeCall(host.collection, (host.collectionSubject())));
        require(!ok, "unknown collection accepted");
        host.seedCollection(bytes32(uint256(1)), bytes32(uint256(9)), 2, keccak256("old"), CP);
        (ok,) =
            address(host).staticcall(abi.encodeCall(host.collection, (host.collectionSubject())));
        require(!ok, "ambiguous collection accepted");
    }

    function testScopedUnknownAmbiguousAndWrongScopeRefused() public {
        StreamFinalityScope memory scope = _scope();
        StreamFinalityScope memory wrong = _scope();
        wrong.scopeId = bytes32(uint256(8));
        for (uint256 i; i < 3; ++i) {
            host.seedScope(
                scope,
                i == 2 ? wrong : scope,
                bytes32(uint256(1)),
                bytes32(uint256(9)),
                2,
                i == 1 ? keccak256("old") : bytes32(0),
                i == 0 ? keccak256("unknown") : SPROFILE
            );
            (bool ok,) = address(host)
                .staticcall(
                    abi.encodeCall(
                        host.readScope, (abi.encodeCall(S.scopedTokenContentRoot, (scope)))
                    )
                );
            require(!ok, "bad root accepted");
            (ok,) = address(host)
                .staticcall(
                    abi.encodeCall(
                        host.readScope, (abi.encodeCall(S.scopedContentRootHead, (scope)))
                    )
                );
            require(!ok, "bad head accepted");
        }
    }

    function testHistoricalRecordReadKeepsOriginalTuple() public {
        bytes32 key = bytes32(uint256(1));
        host.seedCollection(key, bytes32(uint256(9)), 2, 0, CP);
        bytes memory before = host.readBinding(abi.encodeCall(R.contentRootRecord, (key)));
        host.seedCollection(bytes32(uint256(2)), bytes32(uint256(10)), 3, 0, CP);
        require(
            keccak256(before)
                == keccak256(host.readBinding(abi.encodeCall(R.contentRootRecord, (key)))),
            "history changed"
        );
        R.Record memory record = abi.decode(before, (R.Record));
        require(record.contentRoot == bytes32(uint256(9)) && record.leafCount == 2, "wrong record");
    }

    function testUnknownReadSelectorRefusedAndZeroLeafIsUnlabelled() public {
        (bool ok,) = address(host)
            .staticcall(
                abi.encodeCall(
                    host.readBinding, (abi.encodePacked(bytes4(0xdeadbeef), bytes32(uint256(1))))
                )
            );
        require(!ok, "unknown selector accepted");
        host.seedCollection(bytes32(uint256(1)), bytes32(0), 0, 0, CP);
        require(_collectionSchema() == 0, "empty collection leaf");
        StreamFinalityScope memory scope = _scope();
        host.seedScope(scope, scope, bytes32(uint256(1)), bytes32(0), 0, 0, SPROFILE);
        require(_scopedSchema(scope) == 0, "empty scoped leaf");
    }

    function testFuzzPreservationReadsPreservePayload(bytes32 content, uint64 count) public {
        host.seedCollection(bytes32(uint256(1)), content, count, 0, CP);
        (bytes32 actual, uint64 size, bytes32 schema) = host.collection(host.collectionSubject());
        require(
            actual == content && size == count && schema == (count == 0 ? bytes32(0) : NEW_LEAF),
            "collection payload"
        );
        StreamFinalityScope memory scope = _scope();
        host.seedScope(scope, scope, bytes32(uint256(1)), content, count, 0, SPROFILE);
        (actual, size, schema) = abi.decode(
            host.readScope(abi.encodeCall(S.scopedTokenContentRoot, (scope))),
            (bytes32, uint64, bytes32)
        );
        require(
            actual == content && size == count && schema == (count == 0 ? bytes32(0) : NEW_LEAF),
            "scoped payload"
        );
    }
}
