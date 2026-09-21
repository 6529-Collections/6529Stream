// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityFullPreservationPolicyEvidenceProviderV1 as Host
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityFullPreservationPolicyEvidenceProviderV1.sol";
import {
    StreamFinalityNativeProviderReads as Native
} from "../../../smart-contracts/domains/finality/StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityScopedProviderReads as NativeScoped
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedProviderReads.sol";
import {
    StreamFinalityScopedPreservationPolicyProviderReadsV1 as Policy
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPreservationPolicyProviderReadsV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyGraphSelectionV1 as Selection
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityScopedPreservationPolicyGraphSelectionV1.sol";
import {
    StreamCurrentAuthorityPreservationPolicyGraphSelectionV1 as CollectionSelection
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityPreservationPolicyGraphSelectionV1.sol";
import {
    StreamScopedPreservationPolicyPublicationGraphTypesV1 as Graph
} from "../../../smart-contracts/interfaces/stream/finality/StreamScopedPreservationPolicyPublicationGraphTypesV1.sol";
import {
    IStreamScopedPreservationPolicyPublicationEvidenceBindingV1 as Binding
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPreservationPolicyPublicationEvidenceBindingV1.sol";
import {
    IStreamPreservationPolicyPublicationGraphBindingV1 as CollectionBinding
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyPublicationGraphBindingV1.sol";
import {
    StreamFinalityScopedPreservationPolicyProviderMetadataV1 as Metadata
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPreservationPolicyProviderMetadataV1.sol";
import {
    StreamFinalityScopedPreservationPolicySnapshotReadsV1 as Snapshots
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPreservationPolicySnapshotReadsV1.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Family
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    StreamPreservationPolicySnapshotFamiliesV2 as Families
} from "../../../smart-contracts/domains/records/StreamPreservationPolicySnapshotFamiliesV2.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1 as Snapshot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
import {
    IStreamScopedPreservationPolicyContentRootPublicationV1 as Root
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPreservationPolicyContentRootPublicationV1.sol";
import {
    IStreamMetadataServingFacts as Serving
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    IStreamMetadataRouter as Router
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataRouter.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamScopeMembershipFacts
} from "../../../smart-contracts/interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    StreamMetadataSubjects
} from "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import { IERC165 } from "../../../smart-contracts/vendor/openzeppelin/IERC165.sol";

interface PreservationMetadataDispatchVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
    function mockCallRevert(address, bytes calldata, bytes calldata) external;
    function etch(address, bytes calldata) external;
}

contract PreservationMetadataDispatchTable {
    mapping(bytes32 => bytes) private answers;

    function set(bytes memory input, bytes memory output) external {
        answers[keccak256(input)] = output;
    }

    fallback(bytes calldata input) external returns (bytes memory) {
        bytes memory output = answers[keccak256(input)];
        require(output.length != 0, "unconfigured typed boundary");
        return output;
    }
}

/// @dev Test-only linked-worker transport. The exact config, scope and explicit third family word
/// are verified independently of the overload selector. An old two-argument call cannot decode.
/// Constructor immutables survive copying this runtime to the linked worker for a single case.
contract PreservationMetadataDispatchSpy {
    bytes32 private immutable expectedConfig;
    bytes32 private immutable expectedScope;
    uint8 private immutable mode;

    constructor(Metadata.Config memory c, StreamFinalityScope memory scope, uint8 mode_) {
        expectedConfig = keccak256(abi.encode(c));
        expectedScope = keccak256(abi.encode(scope));
        mode = mode_;
    }

    fallback(bytes calldata input) external returns (bytes memory) {
        (Metadata.Config memory c, StreamFinalityScope memory scope, bytes32 family) =
            abi.decode(input[4:], (Metadata.Config, StreamFinalityScope, bytes32));
        require(
            keccak256(input[4:]) == keccak256(abi.encode(c, scope, family)), "exact worker tuple"
        );
        require(
            keccak256(abi.encode(c)) == expectedConfig
                && keccak256(abi.encode(scope)) == expectedScope,
            "complete selected graph config and exact scope"
        );
        require(family == Family.FAMILY_PROFILE, "fixed family V2");
        if (mode == 0) return abi.encode(keccak256("root"), uint64(2), keccak256("leaf schema"));
        if (mode == 1) return abi.encode(keccak256("snapshot manifest"));
        require(mode == 2);
        return abi.encode(true, keccak256("scope manifest"));
    }
}

contract PreservationMetadataDefaultProbe {
    function manifest(Metadata.Config memory c, StreamFinalityScope memory scope, bool v2)
        external
        view
        returns (bool, bytes32)
    {
        return v2 ? Metadata.manifest(c, scope, Family.FAMILY_PROFILE) : Metadata.manifest(c, scope);
    }
}

/// @notice Actual production host overload dispatch with explicit graph/metadata transport boundaries.
/// @dev The constructor runs over typed topology tables; graph initialize/isPolicy/current are
/// exact-calldata mocked. Three dispatch cases replace only the linked Metadata runtime with a
/// tuple-checking spy. Separate cases execute real Metadata.manifest profile/scope/pin checks.
/// No authentic graph, snapshot/root publication, current authority, complete Finality or gas claim.
contract StreamCurrentAuthorityPreservationMetadataDispatchV2Test {
    PreservationMetadataDispatchVm private constant vm =
        PreservationMetadataDispatchVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    Native.Config private original;
    NativeScoped.Config private nativeScoped;
    Policy.Config private selected;
    Selection.Context private graphContext;
    StreamFinalityScope private scope;
    Host private host;
    PreservationMetadataDefaultProbe private probe;

    function setUp() public {
        for (uint256 i; i < 22; ++i) {
            original.targets[i] = address(new PreservationMetadataDispatchTable());
            original.codeHashes[i] = original.targets[i].codehash;
        }
        original.chainId = block.chainid;
        original.readGas = 1000000;
        original.componentSourceGas = 16000000;
        original.sourceGas = 40000000;
        original.inventoryDependencyHash = keccak256("boundary inventory configuration");
        nativeScoped = abi.decode(abi.encode(original), (NativeScoped.Config));
        selected = abi.decode(abi.encode(original), (Policy.Config));
        scope = StreamFinalityScope(StreamFinalityScopeType.RELEASE, 1, 0, keccak256("release"));
        address executor = address(new PreservationMetadataDispatchTable());
        _set(original.targets[1], "core()", abi.encode(original.targets[0]));
        _set(original.targets[1], "governanceAuthority()", abi.encode(executor));
        _set(original.targets[1], "executorCodeHash()", abi.encode(executor.codehash));
        _set(original.targets[2], "core()", abi.encode(original.targets[0]));
        _set(original.targets[3], "core()", abi.encode(original.targets[0]));
        _set(original.targets[3], "metadataHost()", abi.encode(original.targets[1]));
        _support(original.targets[2], type(Serving).interfaceId);
        _support(original.targets[2], type(Router).interfaceId);
        for (uint256 i = 1; i < 3; ++i) {
            _set(original.targets[i], "streamModuleVersion()", abi.encode(keccak256("version")));
            _set(
                original.targets[i],
                "streamModuleManifest()",
                abi.encode("urn:fixture", keccak256("manifest"))
            );
        }
        Binding.FactoryBinding memory b;
        b.factory = address(new PreservationMetadataDispatchTable());
        b.factoryCodeHash = b.factory.codehash;
        b.recipeHash = keccak256("scoped recipe");
        b.sourceFactoryDependenciesHash = keccak256("scoped sources");
        b.graphGas = 4000000;
        b.configurationHash = keccak256("scoped configuration");
        graphContext.original = original;
        graphContext.binding = b;
        vm.mockCall(
            address(Selection),
            abi.encodeWithSelector(Selection.initialize.selector, original, b),
            abi.encode(graphContext)
        );
        CollectionBinding.CollectionFactoryBinding memory cb;
        cb.factory = address(new PreservationMetadataDispatchTable());
        cb.factoryCodeHash = cb.factory.codehash;
        cb.recipeHash = keccak256("collection recipe");
        cb.sourceFactoryDependenciesHash = keccak256("collection sources");
        cb.graphGas = 4000000;
        cb.configurationHash = keccak256("collection configuration");
        CollectionSelection.Context memory cc;
        cc.original = original;
        cc.binding = cb;
        vm.mockCall(
            address(CollectionSelection),
            abi.encodeWithSelector(CollectionSelection.initialize.selector, original, cb),
            abi.encode(cc)
        );
        host = new Host(original, nativeScoped, cb, b);
        vm.mockCall(
            address(Selection),
            abi.encodeWithSelector(Selection.isPolicy.selector, graphContext, scope),
            abi.encode(true)
        );
        Graph.Graph memory g;
        vm.mockCall(
            address(Selection),
            abi.encodeWithSelector(Selection.current.selector, graphContext, scope),
            abi.encode(selected, g)
        );
        probe = new PreservationMetadataDefaultProbe();
        _metadataSource(Family.FAMILY_PROFILE);
    }

    function testScopedRootPassesExactSelectedConfigScopeAndV2Family() public {
        _spy(0);
        (bytes32 root, uint64 count, bytes32 schema) = host.scopedContentRoot(scope);
        require(root == keccak256("root") && count == 2 && schema == keccak256("leaf schema"));
    }

    function testScopedSnapshotPassesExactSelectedConfigScopeAndV2Family() public {
        _spy(1);
        require(host.scopedSnapshotHash(scope) == keccak256("snapshot manifest"));
    }

    function testScopedManifestPassesExactSelectedConfigScopeAndV2Family() public {
        _spy(2);
        (bool exists, bytes32 hash) = host.scopedManifest(scope);
        require(exists && hash == keccak256("scope manifest"));
    }

    function testAllThreeReadsPropagateCurrentGraphFailureBeforeProjection() public {
        bytes memory reason = abi.encodeWithSignature("UnverifiedCurrentGraph()");
        vm.mockCallRevert(
            address(Selection),
            abi.encodeWithSelector(Selection.current.selector, graphContext, scope),
            reason
        );
        _reverts(address(host), abi.encodeCall(host.scopedContentRoot, (scope)), reason);
        _reverts(address(host), abi.encodeCall(host.scopedSnapshotHash, (scope)), reason);
        _reverts(address(host), abi.encodeCall(host.scopedManifest, (scope)), reason);
    }

    function testRealWorkerV2AcceptsAndOriginalDefaultRejectsSameV2Snapshot() public {
        Metadata.Config memory c = _config();
        (bool exists, bytes32 hash) = host.scopedManifest(scope);
        require(exists && hash == keccak256("scope manifest"));
        _reverts(
            address(probe),
            abi.encodeCall(probe.manifest, (c, scope, false)),
            abi.encodeWithSelector(Metadata.InvalidScopedProviderMetadata.selector)
        );
    }

    function testRealWorkerFixedV2RejectsOriginalProfileWithoutWideningDefault() public {
        _metadataSource(Family.ORIGINAL_PROFILE);
        Metadata.Config memory c = _config();
        (bool exists, bytes32 hash) = probe.manifest(c, scope, false);
        require(exists && hash == keccak256("scope manifest"));
        _reverts(
            address(host),
            abi.encodeCall(host.scopedManifest, (scope)),
            abi.encodeWithSelector(Metadata.InvalidScopedProviderMetadata.selector)
        );
    }

    function testRealWorkerRetainsExactSnapshotRuntimePin() public {
        Metadata.Config memory c = _config();
        c.snapshots.snapshotsCodeHash ^= bytes32(uint256(1));
        _reverts(
            address(probe),
            abi.encodeCall(probe.manifest, (c, scope, true)),
            abi.encodeWithSelector(Metadata.InvalidScopedProviderMetadata.selector)
        );
        (bool exists,) = host.scopedManifest(scope);
        require(exists);
    }

    function _spy(uint8 mode) private {
        PreservationMetadataDispatchSpy spy =
            new PreservationMetadataDispatchSpy(_config(), scope, mode);
        vm.etch(address(Metadata), address(spy).code);
    }

    function _config() private view returns (Metadata.Config memory c) {
        c.snapshots = Snapshots.Dependencies(
            selected.targets[0],
            selected.targets[1],
            selected.targets[2],
            selected.targets[8],
            selected.codeHashes[0],
            selected.codeHashes[1],
            selected.codeHashes[2],
            selected.codeHashes[8],
            selected.chainId,
            selected.readGas,
            selected.componentSourceGas
        );
        c.membership = selected.targets[3];
        c.membershipCodeHash = selected.codeHashes[3];
    }

    function _metadataSource(bytes32 family) private {
        _support(selected.targets[2], type(Root).interfaceId);
        _support(selected.targets[8], type(Snapshot).interfaceId);
        _set(
            selected.targets[8],
            "scopedPreservationPolicySnapshotProfile()",
            abi.encode(Families.profile(family, true))
        );
        StreamScopeMembershipFacts memory membership;
        membership.scopeSubject =
            StreamMetadataSubjects.scopeSubject(block.chainid, selected.targets[0], scope);
        membership.scopeManifestHash = keccak256("scope manifest");
        membership.sourceRecordHash = scope.scopeId;
        membership.tokenCount = 2;
        membership.tokenListHash = keccak256("token list");
        membership.membershipHash = keccak256("membership");
        PreservationMetadataDispatchTable(selected.targets[3])
            .set(
                abi.encodeWithSignature(
                    "requireScopeMembership((uint8,uint256,uint256,bytes32))", scope
                ),
                abi.encode(membership)
            );
    }

    function _set(address target, string memory signature, bytes memory value) private {
        PreservationMetadataDispatchTable(target).set(abi.encodeWithSignature(signature), value);
    }

    function _support(address target, bytes4 id) private {
        PreservationMetadataDispatchTable(target)
            .set(abi.encodeCall(IERC165.supportsInterface, (id)), abi.encode(true));
        PreservationMetadataDispatchTable(target)
            .set(
                abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)),
                abi.encode(true)
            );
        PreservationMetadataDispatchTable(target)
            .set(abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))), abi.encode(false));
    }

    function _reverts(address target, bytes memory input, bytes memory expected) private view {
        (bool ok, bytes memory actual) = target.staticcall(input);
        require(
            !ok && keccak256(actual) == keccak256(expected),
            "exact failure, not a masked earlier guard"
        );
    }
}
