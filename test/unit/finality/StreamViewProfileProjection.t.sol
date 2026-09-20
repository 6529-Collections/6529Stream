// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityProfileSourceReads as S
} from "../../../smart-contracts/domains/finality/StreamFinalityProfileSourceReads.sol";
import {
    IStreamFinalityProfileSources as P
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    IStreamPolicyContentRootPublicationV2 as Root
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamPolicyContentRootPublicationV2.sol";
import {
    StreamMetadataSubjects as Subjects
} from "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";

/// @dev Exact input-keyed external facts; no genuine Router/output/provider authority is claimed.
contract ViewProfileProjectionWire {
    mapping(bytes32 => bytes) private responses;

    function answer(bytes memory input, bytes memory result) external {
        responses[keccak256(input)] = result;
    }

    fallback() external {
        bytes memory result = responses[keccak256(msg.data)];
        require(result.length != 0, "unconfigured typed fact");
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
    }
}

contract ViewProfileProjectionProbe {
    uint256 public firstCanary = 111;
    S.Context private first;
    uint256 public middleCanary = 222;
    S.Context private second;
    uint256 public lastCanary = 333;

    function install(S.Context memory c, bool other) external {
        if (other) second = c;
        else first = c;
    }

    function original(bool other, StreamFinalityScope memory scope)
        external
        view
        returns (P.Sources memory)
    {
        return other ? S.current(second, scope) : S.current(first, scope);
    }

    function projected(bool other, StreamFinalityScope memory scope)
        external
        view
        returns (P.Sources memory)
    {
        bytes memory raw = other ? S.currentEncoded(second, scope) : S.currentEncoded(first, scope);
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }

    function policy(bool original_, bool other, StreamFinalityScope memory scope)
        external
        view
        returns (bool)
    {
        if (scope.scopeType != StreamFinalityScopeType.COLLECTION) return false;
        if (original_) {
            return (other ? S.current(second, scope) : S.current(first, scope)).profile.profileHash
                == S.profileHash(2);
        }
        return other ? S.isPolicyStored(second, scope) : S.isPolicyStored(first, scope);
    }

    function hash(bool other) external view returns (bytes32) {
        return other ? S.configurationHashStored(second) : S.configurationHashStored(first);
    }
}

contract StreamViewProfileProjectionTest is CharacterizationTestBase {
    ViewProfileProjectionProbe private probe;
    ViewProfileProjectionWire private router;
    ViewProfileProjectionWire private output;
    ViewProfileProjectionWire private checkpoint;
    ViewProfileProjectionWire private sourceSet;
    S.Context private config;
    bytes32 private constant HEAD = keccak256("typed canonical root");

    function setUp() public {
        probe = new ViewProfileProjectionProbe();
        router = new ViewProfileProjectionWire();
        output = new ViewProfileProjectionWire();
        checkpoint = new ViewProfileProjectionWire();
        sourceSet = new ViewProfileProjectionWire();
        config.core = address(0xC0DE);
        config.router = address(router);
        config.routerCodeHash = address(router).codehash;
        config.chainId = block.chainid;
        config.readGas = 800000;
        config.policyOutput = address(output);
        config.policyOutputCodeHash = address(output).codehash;
        for (uint8 i; i < 3; ++i) {
            ViewProfileProjectionWire host = new ViewProfileProjectionWire();
            config.profiles[i] = P.Profile(
                S.profileHash(i),
                address(host),
                address(host).codehash,
                address(host),
                address(host).codehash,
                address(host),
                address(host).codehash,
                keccak256(abi.encode(i, "configuration"))
            );
        }
        probe.install(config, false);
        probe.install(config, true);
        _support(false);
        router.answer(
            abi.encodeWithSignature("staticMetadataActivation(uint256)", uint256(1)),
            abi.encode(keccak256("activation"), uint64(1), bytes32(0))
        );
    }

    function _scope() private pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
    }

    function _support(bool yes) private {
        router.answer(
            abi.encodeWithSignature("supportsInterface(bytes4)", type(Root).interfaceId),
            abi.encode(yes)
        );
    }

    function _binding() private view returns (Root.Binding memory b) {
        b.profileId = keccak256("6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2");
        b.outputManifest = address(output);
        b.outputManifestCodeHash = address(output).codehash;
        b.checkpoint = address(checkpoint);
        b.checkpointCodeHash = address(checkpoint).codehash;
        b.checkpointHash = keccak256("checkpoint");
        b.checkpointStateHash = keccak256("state");
        b.entropySourceSet = address(sourceSet);
        b.entropySourceSetCodeHash = address(sourceSet).codehash;
        b.inventoryHash = keccak256("inventory");
        b.policyChainHash = keccak256("policies");
        b.outputRoot = keccak256("output");
        b.outputSchemaHash = keccak256("output schema");
        b.outputCanonicalizationHash = keccak256("output canonical");
        b.leafSchemaHash = keccak256("leaf schema");
        b.rootSchemaHash = keccak256("root schema");
        b.rootCanonicalizationHash = keccak256("root canonical");
    }

    function _policy() private {
        _support(true);
        router.answer(
            abi.encodeWithSignature("collectionContentRootHead(uint256)", uint256(1)),
            abi.encode(HEAD)
        );
        router.answer(abi.encodeCall(Root.policyContentRootBinding, (HEAD)), abi.encode(_binding()));
        output.answer(
            abi.encodeWithSignature("contentCheckpoint()"), abi.encode(address(checkpoint))
        );
        checkpoint.answer(
            abi.encodeWithSignature("entropySourceSet()"), abi.encode(address(sourceSet))
        );
    }

    function _equal(bool other, StreamFinalityScope memory scope, uint8 index, S.Context memory c)
        private
        view
    {
        (bool a, bytes memory x) =
            address(probe).staticcall(abi.encodeCall(probe.original, (other, scope)));
        (bool b, bytes memory y) =
            address(probe).staticcall(abi.encodeCall(probe.projected, (other, scope)));
        bytes memory literal = abi.encode(P.Sources(scope, c.profiles[index]));
        require(
            a && b && x.length == 384 && keccak256(x) == keccak256(literal)
                && keccak256(y) == keccak256(literal),
            "complete original/static384 literal"
        );
        bool expected = scope.scopeType == StreamFinalityScopeType.COLLECTION && index == 2;
        require(
            probe.policy(true, other, scope) == expected
                && probe.policy(false, other, scope) == expected,
            "exact bool projection"
        );
        require(
            probe.hash(other)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_FINALITY_SOURCE_CONFIGURATION_V1"),
                        c.chainId,
                        address(probe),
                        c
                    )
                ),
            "full stored config/domain"
        );
        require(
            probe.firstCanary() == 111 && probe.middleCanary() == 222 && probe.lastCanary() == 333
        );
    }

    function _failure(bool other, StreamFinalityScope memory scope, bytes memory expected)
        private
        view
    {
        (bool a, bytes memory x) =
            address(probe).staticcall(abi.encodeCall(probe.original, (other, scope)));
        (bool b, bytes memory y) =
            address(probe).staticcall(abi.encodeCall(probe.projected, (other, scope)));
        require(
            !a && !b && keccak256(x) == keccak256(expected) && keccak256(y) == keccak256(expected),
            "original error precedence"
        );
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            (a, x) = address(probe).staticcall(abi.encodeCall(probe.policy, (true, other, scope)));
            (b, y) = address(probe).staticcall(abi.encodeCall(probe.policy, (false, other, scope)));
            require(
                !a && !b && keccak256(x) == keccak256(expected)
                    && keccak256(y) == keccak256(expected),
                "policy original error precedence"
            );
        }
    }

    function testFullLegacyPolicyAndScopedTuplesAcrossTwoStorageRoots() public {
        _equal(false, _scope(), 0, config);
        _policy();
        _equal(false, _scope(), 2, config);
        S.Context memory alternate = config;
        alternate.profiles[1].configurationHash = keccak256("other namespace");
        probe.install(alternate, true);
        StreamFinalityScope memory release_ =
            StreamFinalityScope(StreamFinalityScopeType.RELEASE, 1, 0, bytes32(uint256(7)));
        StreamFinalityScope memory season =
            StreamFinalityScope(StreamFinalityScopeType.SEASON, 1, 0, bytes32(uint256(7)));
        _equal(false, release_, 1, config);
        _equal(true, season, 1, alternate);
        require(
            keccak256(abi.encode(probe.projected(false, release_)))
                != keccak256(abi.encode(probe.projected(true, season)))
        );
    }

    function testOriginalValidationChainPinAndScopeErrorOrder() public {
        S.Context memory c = config;
        c.readGas = 1;
        c.routerCodeHash = 0;
        probe.install(c, false);
        _failure(false, _scope(), abi.encodeWithSelector(S.InvalidFinalitySourceProfile.selector));
        c = config;
        c.chainId += 1;
        c.routerCodeHash = bytes32(uint256(3));
        probe.install(c, false);
        _failure(false, _scope(), abi.encodeWithSelector(S.InvalidFinalitySourceProfile.selector));
        c = config;
        c.routerCodeHash = bytes32(uint256(3));
        probe.install(c, false);
        _failure(
            false,
            _scope(),
            abi.encodeWithSelector(S.FinalitySourceDependency.selector, address(router))
        );
        c = config;
        c.profiles[0].referenceRenderCodeHash = bytes32(uint256(3));
        probe.install(c, false);
        StreamFinalityScope memory bad = _scope();
        bad.tokenId = 1;
        _failure(false, bad, abi.encodeWithSelector(Subjects.InvalidMetadataScope.selector));
        _failure(
            false,
            _scope(),
            abi.encodeWithSelector(
                S.FinalitySourceDependency.selector, c.profiles[0].referenceRender
            )
        );
        probe.install(config, false);
        _equal(false, _scope(), 0, config);
    }

    function testUnknownOrMixedPolicyBindingsRefuseAndRestore() public {
        _policy();
        Root.Binding memory b = _binding();
        b.policyChainHash = 0;
        router.answer(abi.encodeCall(Root.policyContentRootBinding, (HEAD)), abi.encode(b));
        _failure(false, _scope(), abi.encodeWithSelector(S.InvalidFinalitySourceProfile.selector));
        b = _binding();
        b.profileId = 0;
        router.answer(abi.encodeCall(Root.policyContentRootBinding, (HEAD)), abi.encode(b));
        _failure(false, _scope(), abi.encodeWithSelector(S.InvalidFinalitySourceProfile.selector));
        _policy();
        _equal(false, _scope(), 2, config);
        Root.Binding memory empty;
        router.answer(abi.encodeCall(Root.policyContentRootBinding, (HEAD)), abi.encode(empty));
        _equal(false, _scope(), 0, config);
    }

    function testNonCollectionPolicyBranchRetainsEarlyFalseBeforeInvalidStoredContext() public {
        S.Context memory broken;
        probe.install(broken, false);
        StreamFinalityScope memory view_ = StreamFinalityScope(
            StreamFinalityScopeType.VIEW, 0, 0, 0
        );
        require(!probe.policy(true, false, view_) && !probe.policy(false, false, view_));
        _failure(false, view_, abi.encodeWithSelector(S.InvalidFinalitySourceProfile.selector));
    }
}
