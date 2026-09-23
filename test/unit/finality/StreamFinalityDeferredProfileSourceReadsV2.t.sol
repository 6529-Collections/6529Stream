// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityDeferredProfileSourceReadsV2 as S
} from "../../../smart-contracts/domains/finality/StreamFinalityDeferredProfileSourceReadsV2.sol";
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
import {
    StreamCurrentAuthorityDeferredPolicyBindingTypesV2 as T
} from "../../../smart-contracts/interfaces/stream/finality/StreamCurrentAuthorityDeferredPolicyBindingTypesV2.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";

/// @dev Exact input-keyed external facts; no genuine Router/output/provider authority is claimed.
contract DeferredProfileSourceWire {
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

contract DeferredProfileSourceProbe {
    function current(S.Context memory c, StreamFinalityScope memory scope)
        external
        view
        returns (P.Sources memory)
    {
        return S.current(c, scope);
    }
}

/// @notice Real deferred selector against explicit, input-keyed Router/source facts.
/// @dev These boundary tests claim no genuine policy publication, governance or Finality flow.
contract StreamFinalityDeferredProfileSourceReadsV2Test is CharacterizationTestBase {
    DeferredProfileSourceProbe private probe;
    DeferredProfileSourceWire private router;
    DeferredProfileSourceWire private output;
    DeferredProfileSourceWire private checkpoint;
    DeferredProfileSourceWire private sourceSet;
    S.Context private config;
    bytes32 private constant HEAD = keccak256("typed canonical root");

    function setUp() public {
        probe = new DeferredProfileSourceProbe();
        router = new DeferredProfileSourceWire();
        output = new DeferredProfileSourceWire();
        checkpoint = new DeferredProfileSourceWire();
        sourceSet = new DeferredProfileSourceWire();
        config.core = address(0xC0DE);
        config.router = address(router);
        config.routerCodeHash = address(router).codehash;
        config.chainId = block.chainid;
        config.readGas = 800000;
        for (uint8 i; i < 2; ++i) {
            DeferredProfileSourceWire host = new DeferredProfileSourceWire();
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
        _support(0);
        router.answer(
            abi.encodeWithSignature("staticMetadataActivation(uint256)", uint256(1)),
            abi.encode(keccak256("activation"), uint64(1), bytes32(0))
        );
    }

    function _scope() private pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
    }

    function _support(uint256 value) private {
        router.answer(
            abi.encodeWithSignature("supportsInterface(bytes4)", type(Root).interfaceId),
            abi.encode(value)
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

    function _root(Root.Binding memory b) private {
        _support(1);
        router.answer(
            abi.encodeWithSignature("collectionContentRootHead(uint256)", uint256(1)),
            abi.encode(HEAD)
        );
        router.answer(abi.encodeCall(Root.policyContentRootBinding, (HEAD)), abi.encode(b));
        output.answer(
            abi.encodeWithSignature("contentCheckpoint()"), abi.encode(address(checkpoint))
        );
        checkpoint.answer(
            abi.encodeWithSignature("entropySourceSet()"), abi.encode(address(sourceSet))
        );
    }

    function _bound() private {
        config.policyBound = true;
        config.policyOutput = address(output);
        config.policyOutputCodeHash = address(output).codehash;
        config.profiles[2] = P.Profile(
            S.profileHash(2),
            address(output),
            address(output).codehash,
            address(output),
            address(output).codehash,
            address(sourceSet),
            address(sourceSet).codehash,
            keccak256("once-bound policy configuration")
        );
    }

    function _equal(StreamFinalityScope memory scope, uint8 index) private view {
        P.Sources memory actual = probe.current(config, scope);
        require(
            keccak256(abi.encode(actual))
                == keccak256(abi.encode(P.Sources(scope, config.profiles[index]))),
            "exact source tuple"
        );
    }

    function _reject(bytes memory expected) private view {
        (bool ok, bytes memory out) =
            address(probe).staticcall(abi.encodeCall(probe.current, (config, _scope())));
        require(!ok && keccak256(out) == keccak256(expected), "exact refusal without fallback");
    }

    function testPendingNativeAndAllScopedKindsRemainAvailable() public view {
        _equal(_scope(), 0);
        _equal(StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 7, 0), 1);
        _equal(StreamFinalityScope(StreamFinalityScopeType.RELEASE, 1, 0, bytes32(uint256(8))), 1);
        _equal(StreamFinalityScope(StreamFinalityScopeType.SEASON, 1, 0, bytes32(uint256(9))), 1);
    }

    function testExplicitPolicyRootRefusesPendingInsteadOfLegacyFallback() public {
        _root(_binding());
        _reject(abi.encodeWithSelector(T.CollectionPolicyPending.selector));
        _equal(StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 7, 0), 1);
    }

    function testMalformedCapabilityAndBindingNeverFallback() public {
        _support(2);
        _reject(abi.encodeWithSelector(S.InvalidFinalitySourceProfile.selector));
        Root.Binding memory b = _binding();
        b.profileId = 0;
        _root(b);
        _reject(abi.encodeWithSelector(S.InvalidFinalitySourceProfile.selector));
        b = _binding();
        b.profileId = keccak256("wrong profile");
        _root(b);
        _reject(abi.encodeWithSelector(S.InvalidFinalitySourceProfile.selector));
        b = _binding();
        b.rootSchemaHash = 0;
        _root(b);
        _reject(abi.encodeWithSelector(S.InvalidFinalitySourceProfile.selector));
    }

    function testOnlyLiteralZeroBindingSelectsLegacyWhenCapabilityPresent() public {
        Root.Binding memory empty;
        _root(empty);
        _equal(_scope(), 0);
        _bound();
        _equal(_scope(), 0);
    }

    function testBoundPolicySelectsExactProfileAndLeavesOtherBranchesUnchanged() public {
        _bound();
        _root(_binding());
        _equal(_scope(), 2);
        _equal(StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 7, 0), 1);
        _support(0);
        _equal(_scope(), 0);
    }

    function testBoundPolicyRejectsSwappedOutputAndReciprocalCheckpoint() public {
        _bound();
        Root.Binding memory b = _binding();
        b.outputManifest = address(sourceSet);
        _root(b);
        _reject(abi.encodeWithSelector(S.InvalidFinalitySourceProfile.selector));
        _root(_binding());
        output.answer(
            abi.encodeWithSignature("contentCheckpoint()"), abi.encode(address(sourceSet))
        );
        _reject(abi.encodeWithSelector(S.InvalidFinalitySourceProfile.selector));
        _root(_binding());
        _equal(_scope(), 2);
    }

    function testPendingCannotExposePartialProfileOrOutput() public {
        config.policyOutput = address(output);
        _reject(abi.encodeWithSelector(S.InvalidFinalitySourceProfile.selector));
        config.policyOutput = address(0);
        config.profiles[2] = config.profiles[0];
        _reject(abi.encodeWithSelector(S.InvalidFinalitySourceProfile.selector));
    }

    function testBoundProfileAndScopeStillRequireExactCanonicalConfiguration() public {
        _bound();
        _root(_binding());
        config.profiles[2].profileHash = S.profileHash(1);
        _reject(abi.encodeWithSelector(S.InvalidFinalitySourceProfile.selector));
        _bound();
        StreamFinalityScope memory malformed = _scope();
        malformed.tokenId = 1;
        (bool ok, bytes memory out) =
            address(probe).staticcall(abi.encodeCall(probe.current, (config, malformed)));
        require(
            !ok
                && keccak256(out)
                    == keccak256(abi.encodeWithSelector(Subjects.InvalidMetadataScope.selector))
        );
        _equal(_scope(), 2);
    }
}
