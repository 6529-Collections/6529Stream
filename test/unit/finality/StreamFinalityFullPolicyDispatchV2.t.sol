// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityFullPolicyDispatchV2 as Dispatch
} from "../../../smart-contracts/domains/finality/StreamFinalityFullPolicyDispatchV2.sol";
import {
    StreamFinalityScopedPolicyGraphSelectionV2 as Scoped
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPolicyGraphSelectionV2.sol";
import {
    StreamFinalityPolicyGraphSelectionV2 as Collection
} from "../../../smart-contracts/domains/finality/StreamFinalityPolicyGraphSelectionV2.sol";
import {
    StreamFinalityFactoryProfileSourceReadsV2 as Profiles
} from "../../../smart-contracts/domains/finality/StreamFinalityFactoryProfileSourceReadsV2.sol";
import {
    IStreamFinalityProfileSources as P
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    IStreamScopedPolicyPublicationEvidenceBindingV2 as S
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyPublicationEvidenceBindingV2.sol";
import {
    IStreamPolicyPublicationGraphBindingV2 as C
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPolicyPublicationGraphBindingV2.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType,
    StreamFinalityComponentExpectation
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

interface FullPolicyDispatchVm {
    function chainId(uint256) external;
    function prank(address) external;
}

/// @dev Explicit original Router boundary: zero policy heads plus a real STATIC activation.
contract FullPolicyDispatchRouter {
    address public expectedCaller;

    function expectCaller(address caller) external {
        expectedCaller = caller;
    }

    function supportsInterface(bytes4) external view returns (bool) {
        _caller();
        return true;
    }

    function collectionContentRootHead(uint256) external view returns (bytes32) {
        _caller();
        return 0;
    }

    function scopedContentRootHead(StreamFinalityScope calldata) external view returns (bytes32) {
        _caller();
        return 0;
    }

    function staticMetadataActivation(uint256) external view returns (bytes32, uint64, bytes32) {
        _caller();
        return (bytes32(uint256(1)), 1, bytes32(uint256(2)));
    }

    function _caller() private view {
        require(msg.sender == expectedCaller, "delegate host remains original Router caller");
        require(gasleft() <= 200000, "unchanged leaf read ceiling");
    }
}

/// @dev Actual fixed Dispatch with explicitly seeded two namespaces, not an admitted provider.
/// Canonical construction, original evidence workers and complete finality remain separate tests.
/// Every raw dispatch is an external entry; no cross-selector internal-call support is asserted.
contract FullPolicyDispatchHarness {
    bytes32 public canaryBefore = keccak256("policy before");
    Scoped.Context private _scoped;
    Collection.Context private _collection;
    Profiles.Context private _profiles;
    Scoped.Context private _otherScoped;
    Collection.Context private _otherCollection;
    Profiles.Context private _otherProfiles;
    bytes32 public canaryAfter = keccak256("policy after");
    uint256 public immutable savedChain;
    address public immutable registry;
    error NativeProviderOriginalRegistryOnly();

    constructor(address router) {
        savedChain = block.chainid;
        registry = router;
        _scoped.original.chainId = block.chainid;
        _scoped.original.targets[0] = address(0x1234);
        _scoped.original.targets[2] = router;
        _scoped.original.codeHashes[2] = router.codehash;
        _scoped.original.targets[12] = router;
        _scoped.original.codeHashes[12] = router.codehash;
        _scoped.original.readGas = 200000;
        _scoped.original.componentSourceGas = 345678;
        _collection.original = _scoped.original;
        _scoped.binding = S.FactoryBinding(
            address(0xA1),
            bytes32(uint256(101)),
            bytes32(uint256(102)),
            bytes32(uint256(103)),
            104,
            bytes32(uint256(105))
        );
        _collection.binding = C.CollectionFactoryBinding(
            address(0xB1),
            bytes32(uint256(201)),
            bytes32(uint256(202)),
            bytes32(uint256(203)),
            204,
            bytes32(uint256(205))
        );
        _profiles.core = address(0x1234);
        _profiles.router = router;
        _profiles.routerCodeHash = router.codehash;
        _profiles.chainId = block.chainid;
        _profiles.readGas = 200000;
        for (uint8 i; i < 2; ++i) {
            _profiles.profiles[i] = P.Profile(
                Profiles.profileHash(i),
                router,
                router.codehash,
                router,
                router.codehash,
                router,
                router.codehash,
                bytes32(uint256(901 + i))
            );
        }
        _otherScoped.original = _scoped.original;
        _otherScoped.original.componentSourceGas = 765432;
        _otherScoped.binding = _scoped.binding;
        _otherScoped.binding.graphGas = type(uint256).max;
        _otherCollection.original = _collection.original;
        _otherCollection.binding = _collection.binding;
        _otherProfiles = _profiles;
    }

    function readOther(bytes calldata input) external view returns (bool, bytes memory) {
        return Dispatch.read(_otherScoped, _otherCollection, _otherProfiles, input);
    }

    function storedHash() external view returns (bytes32) {
        return keccak256(
            abi.encode(
                canaryBefore,
                _scoped,
                _collection,
                _profiles,
                _otherScoped,
                _otherCollection,
                _otherProfiles,
                canaryAfter
            )
        );
    }

    function routerPin(bytes32 pin) external {
        _scoped.original.codeHashes[2] = pin;
        _collection.original.codeHashes[2] = pin;
    }

    fallback() external {
        if (msg.sig == 0x343d8ac3 || msg.sig == 0x9850674d) {
            if (
                msg.sender != _collection.original.targets[12] || msg.sender.code.length == 0
                    || msg.sender.codehash != _collection.original.codeHashes[12]
            ) revert NativeProviderOriginalRegistryOnly();
        }
        (bool handled, bytes memory encoded) =
            Dispatch.read(_scoped, _collection, _profiles, msg.data);
        if (!handled) encoded = abi.encode(keccak256(msg.data), address(this), msg.sender);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }
}

contract StreamFinalityFullPolicyDispatchV2Test {
    FullPolicyDispatchVm private constant vm =
        FullPolicyDispatchVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    FullPolicyDispatchHarness private h;
    FullPolicyDispatchRouter private router;

    function setUp() public {
        router = new FullPolicyDispatchRouter();
        h = new FullPolicyDispatchHarness(address(router));
        router.expectCaller(address(h));
    }

    function _call(bytes memory input) private view returns (bytes memory out) {
        (bool ok, bytes memory data) = address(h).staticcall(input);
        if (!ok) assembly ("memory-safe") { revert(add(data, 32), mload(data)) }
        return data;
    }

    function _same(bytes memory input, bytes memory expected) private view {
        bytes memory out = _call(input);
        require(
            out.length == expected.length && keccak256(out) == keccak256(expected),
            "independent complete ABI bytes"
        );
    }

    function _failure(bytes memory input, bytes memory expected) private view {
        (bool ok, bytes memory data) = address(h).staticcall(input);
        require(!ok && keccak256(data) == keccak256(expected), "exact intended failure");
    }

    function _scope(uint8 kind) private pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(
            StreamFinalityScopeType(kind),
            9,
            kind == 1 ? 77 : 0,
            kind < 2 ? bytes32(0) : bytes32(uint256(99))
        );
    }

    function _sourceInput(StreamFinalityScope memory scope) private pure returns (bytes memory) {
        return abi.encodeWithSignature(
            "finalitySourcesForScope((uint8,uint256,uint256,bytes32))", scope
        );
    }

    function _profile(uint8 i) private view returns (P.Profile memory) {
        return P.Profile(
            Profiles.profileHash(i),
            address(router),
            address(router).codehash,
            address(router),
            address(router).codehash,
            address(router),
            address(router).codehash,
            bytes32(uint256(901 + i))
        );
    }

    function testLiteralBindingsCatalogueAndTwoStorageRoots() public view {
        bytes32 before_ = h.storedHash();
        _same(
            abi.encodeWithSignature("scopedPolicyPublicationBinding()"),
            abi.encode(
                address(0xA1),
                bytes32(uint256(101)),
                bytes32(uint256(102)),
                bytes32(uint256(103)),
                uint256(104),
                bytes32(uint256(105))
            )
        );
        _same(
            abi.encodeWithSignature("collectionPolicyPublicationBinding()"),
            abi.encode(
                address(0xB1),
                bytes32(uint256(201)),
                bytes32(uint256(202)),
                bytes32(uint256(203)),
                uint256(204),
                bytes32(uint256(205))
            )
        );
        for (uint8 i; i < 2; ++i) {
            _same(
                abi.encodeWithSignature("finalitySourceProfile(uint8)", i), abi.encode(_profile(i))
            );
        }
        (bool handled, bytes memory other) =
            h.readOther(abi.encodeWithSignature("scopedPolicyPublicationBinding()"));
        require(
            handled
                && keccak256(other)
                    == keccak256(
                        abi.encode(
                            address(0xA1),
                            bytes32(uint256(101)),
                            bytes32(uint256(102)),
                            bytes32(uint256(103)),
                            type(uint256).max,
                            bytes32(uint256(105))
                        )
                    ),
            "other compiler-owned storage root"
        );
        _failure(
            abi.encodeWithSignature("finalitySourceProfile(uint8)", uint8(2)),
            abi.encodeWithSignature("InvalidFinalitySourceProfile()")
        );
        require(h.storedHash() == before_, "complete state and canaries unchanged");
    }

    function testCompleteLegacyCatalogueAndClosedScopeGas() public view {
        for (uint8 kind; kind < 4; ++kind) {
            StreamFinalityScope memory s = _scope(kind);
            _same(_sourceInput(s), abi.encode(s, _profile(kind == 0 ? 0 : 1)));
            bytes memory input = abi.encodeWithSignature(
                "scopedPolicySnapshotValidationGas((uint8,uint256,uint256,bytes32))", s
            );
            if (kind == 0) {
                _failure(input, abi.encodeWithSignature("ScopedPolicyGraphConfiguration()"));
            } else {
                _same(input, abi.encode(uint256(345678)));
                (bool handled, bytes memory other) = h.readOther(input);
                require(
                    handled && keccak256(other) == keccak256(abi.encode(uint256(765432))),
                    "independent source budget root"
                );
            }
        }
        _failure(
            abi.encodeWithSignature(
                "scopedPolicySnapshotValidationGas((uint8,uint256,uint256,bytes32))", _scope(4)
            ),
            abi.encodeWithSignature("ScopedPolicyGraphConfiguration()")
        );
    }

    function testLegacyOperationFallthroughKeepsFullCalldataAndCaller() public view {
        for (uint8 kind; kind < 4; ++kind) {
            StreamFinalityScope memory s = _scope(kind);
            _fallback(
                abi.encodeWithSignature("inputManifestBytes((uint8,uint256,uint256,bytes32))", s)
            );
            _fallback(
                abi.encodeWithSignature(
                    "requireFinalityScopeInputs((uint8,uint256,uint256,bytes32),bytes32)",
                    s,
                    bytes32(uint256(123))
                )
            );
            _fallback(
                abi.encodeWithSignature(
                    "requireSanctionReviewFacts((uint8,uint256,uint256,bytes32),bytes32)",
                    s,
                    bytes32(uint256(456))
                )
            );
            _fallback(
                abi.encodeWithSignature("scopedContentRoot((uint8,uint256,uint256,bytes32))", s)
            );
            _fallback(
                abi.encodeWithSignature("scopedSnapshotHash((uint8,uint256,uint256,bytes32))", s)
            );
            _fallback(abi.encodeWithSignature("scopedManifest((uint8,uint256,uint256,bytes32))", s));
        }
    }

    function _fallback(bytes memory input) private view {
        _same(input, abi.encode(keccak256(input), address(h), address(this)));
    }

    function testOriginalRegistryGuardPrecedesInvalidScopeInBothPreparedSelectors() public {
        StreamFinalityComponentExpectation[] memory items =
            new StreamFinalityComponentExpectation[](0);
        bytes4[2] memory selectors = [bytes4(0x343d8ac3), bytes4(0x9850674d)];
        for (uint256 i; i < 2; ++i) {
            bytes memory input =
                abi.encodeWithSelector(selectors[i], _scope(4), bytes32(uint256(1)), items);
            _failure(input, abi.encodeWithSignature("NativeProviderOriginalRegistryOnly()"));
            vm.prank(address(router));
            (bool ok, bytes memory out) = address(h).staticcall(input);
            require(
                !ok
                    && keccak256(out)
                        == keccak256(abi.encodeWithSignature("ScopedPolicyGraphConfiguration()")),
                "authorized caller reaches original VIEW refusal"
            );
        }
    }

    function testRouterRuntimeAndChainErrorsRestoreExactLegacySources() public {
        bytes memory input = _sourceInput(_scope(1));
        bytes memory expected = abi.encode(_scope(1), _profile(1));
        _same(input, expected);
        h.routerPin(bytes32(uint256(1)));
        _failure(
            input, abi.encodeWithSignature("ScopedPolicyGraphSource(address)", address(router))
        );
        h.routerPin(address(router).codehash);
        _same(input, expected);
        uint256 chain = h.savedChain();
        vm.chainId(chain + 1);
        _failure(input, abi.encodeWithSignature("InvalidFinalitySourceProfile()"));
        vm.chainId(chain);
        _same(input, expected);
    }

    function testFuzzCompleteScopeIdentityAndNoStoredMutation(bytes32 id, uint8 kind) public view {
        if (id == 0) id = bytes32(uint256(1));
        kind = uint8(2 + kind % 2);
        StreamFinalityScope memory s = StreamFinalityScope(StreamFinalityScopeType(kind), 9, 0, id);
        bytes32 before_ = h.storedHash();
        _same(_sourceInput(s), abi.encode(s, _profile(1)));
        require(h.storedHash() == before_, "read cannot alter selected contexts");
    }
}
