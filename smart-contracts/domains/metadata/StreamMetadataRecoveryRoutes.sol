// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/modules/IStreamModule.sol";
import "../../interfaces/stream/modules/IStreamModuleRegistry.sol";
import "../../interfaces/stream/finality/IStreamArtworkFinalityRegistry.sol";
import "../../interfaces/stream/finality/IStreamArtworkFinalityRecovery.sol";
import "../../interfaces/stream/finality/IStreamFinalityHostAdapter.sol";
import "../../interfaces/stream/finality/IStreamFinalityDeploymentBindings.sol";
import "../../interfaces/stream/finality/IStreamFinalityRecoveryServingBindings.sol";
import "../../interfaces/stream/artist/IStreamArtistFinalityBinding.sol";

/// @notice Current recovery selection and immutable adapter-to-host joins for serving.
/// @dev Permanent registry reads only classify absence before companion installation. They
///      never select a serving route. All selected routes use both canonical companion reads.
library StreamMetadataRecoveryRoutes {
    uint256 internal constant READ_GAS = 150000;
    uint256 internal constant ROUTE_GAS = 2000000;
    bytes32 internal constant RECOVERY = keccak256("ARTWORK_FINALITY_RECOVERY");
    bytes32 internal constant ORIGINAL = keccak256("ARTWORK_FINALITY_REGISTRY");

    struct OriginalAnchor {
        address registry;
        bytes32 codeHash;
    }

    struct Environment {
        address core;
        address artist;
        bytes32 artistCodeHash;
    }

    struct Pointer {
        address target;
        bytes32 codeHash;
        bool frozen;
        bytes32 moduleType;
        bytes4 interfaceId;
        address registry;
        uint8 status;
        bytes32 moduleManifest;
        bytes32 deploymentManifest;
        uint64 revision;
    }

    struct Context {
        address core;
        address recovery;
        StreamFinalityScope scope;
    }

    struct Route {
        bool pinned;
        address module;
        bytes32 hash;
        bytes32 original;
        bytes32 recoveryId;
    }

    struct Status {
        bool pinned;
        bool current;
        bytes32 hash;
        bytes32 recoveryId;
    }

    error MetadataRecoveryBindingInvalid(address target);
    error MetadataRecoveryReadFailed(address target, bytes4 selector);
    error MetadataRecoveryParentGas(uint256 available, uint256 required);
    error MetadataFrozenRouteInvalid(bytes32 family);

    /// @notice The lock captures this binding from the fixed facade, never a caller target.
    function captureOriginal(Environment memory e) public view returns (OriginalAnchor memory a) {
        if (e.artist.code.length == 0 || e.artist.codehash != e.artistCodeHash) {
            revert MetadataRecoveryBindingInvalid(e.artist);
        }
        a.registry =
            _address(e.artist, abi.encodeCall(IStreamArtistFinalityBinding.finalityRegistry, ()));
        a.codeHash = abi.decode(
            read(
                e.artist,
                abi.encodeCall(IStreamArtistFinalityBinding.finalityRegistryCodeHash, ()),
                32,
                READ_GAS
            ),
            (bytes32)
        );
        if (_address(e.artist, abi.encodeWithSignature("core()")) != e.core) {
            revert MetadataRecoveryBindingInvalid(e.artist);
        }
        _original(e.core, a);
    }

    function _original(address core, OriginalAnchor memory a) private view {
        if (
            a.registry == address(0) || a.codeHash == 0 || a.registry.code.length == 0
                || a.registry.codehash != a.codeHash
                || _address(
                        a.registry, abi.encodeCall(IStreamFinalityDeploymentBindings.coreReads, ())
                    ) != core
        ) {
            revert MetadataRecoveryBindingInvalid(a.registry);
        }
    }

    function context(
        Environment memory e,
        bool locked,
        OriginalAnchor memory saved,
        StreamFinalityScope memory scope
    ) public view returns (Context memory c, bool frozen) {
        // A locked collection must retain its entire one-time binding. Missing or partial
        // saved data is corruption, never permission to consult a newer facade or registry.
        if (locked) {
            _original(e.core, saved);
        } else {
            if (saved.registry != address(0) || saved.codeHash != 0) {
                revert MetadataRecoveryBindingInvalid(saved.registry);
            }
            saved = captureOriginal(e);
        }
        address core = e.core;
        address original = saved.registry;
        c = Context(core, address(0), scope);
        // Immutable original counts classify absence only; they never select a serving route.
        uint256 count = abi.decode(
            read(
                original,
                abi.encodeCall(
                    IStreamArtworkFinalityRegistry.finalityComponentCountForScope, (scope)
                ),
                32,
                READ_GAS
            ),
            (uint256)
        );
        if (count == 0 && scope.scopeType == StreamFinalityScopeType.TOKEN) {
            count = abi.decode(
                read(
                    original,
                    abi.encodeCall(
                        IStreamArtworkFinalityRegistry.finalityComponentCount, (scope.collectionId)
                    ),
                    32,
                    READ_GAS
                ),
                (uint256)
            );
        }
        if (count == 0) return (c, false);
        Pointer memory recovery = _pointer(core, RECOVERY);
        _installed(
            core,
            recovery,
            keccak256("STREAM_ARTWORK_FINALITY_RECOVERY"),
            type(IStreamArtworkFinalityRecovery).interfaceId,
            true
        );
        c.recovery = recovery.target;
        address executor = _identityAddress(
            c.recovery,
            abi.encodeCall(IStreamFinalityRecoveryServingBindings.governanceAuthority, ())
        );
        address artist = _address(
            c.recovery, abi.encodeCall(IStreamFinalityRecoveryServingBindings.artistEvidence, ())
        );
        if (
            _address(c.recovery, abi.encodeCall(IStreamFinalityRecoveryServingBindings.core, ()))
                    != core
                || _address(
                        c.recovery,
                        abi.encodeCall(
                            IStreamFinalityRecoveryServingBindings.originalFinalityRegistry, ()
                        )
                    ) != original
                || _address(
                        original, abi.encodeCall(IStreamFinalityDeploymentBindings.coreReads, ())
                    ) != core
                || _address(
                        original,
                        abi.encodeCall(IStreamFinalityDeploymentBindings.sanctionReads, ())
                    ) != artist
                || _identityAddress(
                        original,
                        abi.encodeCall(
                            IStreamFinalityRecoveryServingBindings.governanceAuthority, ()
                        )
                    ) != executor
        ) revert MetadataRecoveryBindingInvalid(c.recovery);
        // OwnerRecords was authenticated at companion construction and recovery execution.
        // Historical serving uses the recorded evidence and canonical route/status reads.
        Route memory r = route(c, StreamFinalityDomains.COMPONENT_METADATA_ROUTER, true);
        frozen = r.pinned;
    }

    function route(Context memory c, bytes32 family, bool required)
        public
        view
        returns (Route memory r)
    {
        r = abi.decode(
            read(
                c.recovery,
                abi.encodeCall(
                    IStreamArtworkFinalityRecovery.resolvedFinalityRoute, (family, c.scope)
                ),
                160,
                ROUTE_GAS
            ),
            (Route)
        );
        Status memory s = abi.decode(
            read(
                c.recovery,
                abi.encodeCall(
                    IStreamArtworkFinalityRecovery.finalityRecoveryRouteStatus, (family, c.scope)
                ),
                128,
                ROUTE_GAS
            ),
            (Status)
        );
        if (
            r.pinned != s.pinned || r.hash != s.hash || r.recoveryId != s.recoveryId
                || (r.pinned
                    && (!s.current || r.module.code.length == 0 || r.hash == 0 || r.original == 0))
                || (!r.pinned
                    && (required
                        || s.current
                        || r.module != address(0)
                        || r.hash != 0
                        || r.original != 0
                        || r.recoveryId != 0))
        ) revert MetadataFrozenRouteInvalid(family);
    }

    function host(Context memory c, bytes32 family) public view returns (address target) {
        Route memory r = route(c, family, true);
        _supports(r.module, type(IStreamFinalityHostAdapter).interfaceId);
        target = _address(r.module, abi.encodeCall(IStreamFinalityHostAdapter.host, ()));
        if (
            _address(r.module, abi.encodeCall(IStreamFinalityHostAdapter.core, ())) != c.core
                || abi.decode(
                        read(
                            r.module,
                            abi.encodeCall(IStreamFinalityHostAdapter.coreCodeHash, ()),
                            32,
                            READ_GAS
                        ),
                        (bytes32)
                    ) != c.core.codehash
                || abi.decode(
                        read(
                            r.module,
                            abi.encodeCall(IStreamFinalityHostAdapter.hostCodeHash, ()),
                            32,
                            READ_GAS
                        ),
                        (bytes32)
                    ) != target.codehash
                || abi.decode(
                        read(
                            r.module,
                            abi.encodeCall(IStreamFinalityHostAdapter.componentType, ()),
                            32,
                            READ_GAS
                        ),
                        (bytes32)
                    ) != family || _address(target, abi.encodeWithSignature("core()")) != c.core
        ) {
            revert MetadataRecoveryBindingInvalid(r.module);
        }
    }

    function _pointer(address core, bytes32 key) private view returns (Pointer memory p) {
        bytes memory raw = read(
            core, abi.encodeCall(IStreamCorePointers.getSatellitePointer, (key)), 320, READ_GAS
        );
        p = abi.decode(raw, (Pointer));
        if (p.target == address(0) && keccak256(raw) != keccak256(new bytes(320))) {
            revert MetadataRecoveryBindingInvalid(core);
        }
    }

    /// @notice Current discovery admission, separate from historical serving-host pins.
    function requireCurrentHost(
        address core,
        bytes32 key,
        address expected,
        bytes32 kind,
        bytes4 id
    ) public view {
        Pointer memory p = _pointer(core, key);
        if (p.target != expected) revert MetadataRecoveryBindingInvalid(p.target);
        _installed(core, p, kind, id, true);
    }

    function _installed(address core, Pointer memory p, bytes32 kind, bytes4 id, bool current)
        private
        view
    {
        if (
            p.target.code.length == 0 || p.codeHash != p.target.codehash || p.moduleType != kind
                || p.interfaceId != id || p.registry == address(0)
                || (p.status != 1 && p.status != 2) || p.moduleManifest == 0
                || p.deploymentManifest == 0 || p.revision == 0
        ) {
            revert MetadataRecoveryBindingInvalid(p.target);
        }
        _supports(p.target, id);
        if (
            abi.decode(
                        read(
                            p.target,
                            abi.encodeCall(IStreamModule.streamModuleType, ()),
                            32,
                            READ_GAS
                        ),
                        (bytes32)
                    ) != kind
                || abi.decode(
                        read(
                            p.target,
                            abi.encodeCall(IStreamModule.streamModuleInterfaceId, ()),
                            32,
                            READ_GAS
                        ),
                        (bytes4)
                    ) != id
        ) {
            revert MetadataRecoveryBindingInvalid(p.target);
        }
        if (current) {
            Pointer memory registry = _pointer(core, keccak256("MODULE_REGISTRY"));
            if (
                registry.target != p.registry || registry.target.code.length == 0
                    || registry.codeHash != registry.target.codehash
                    || !abi.decode(
                        read(
                            registry.target,
                            abi.encodeCall(
                                IStreamModuleRegistry.isModuleEligible, (p.target, kind, id)
                            ),
                            32,
                            READ_GAS
                        ),
                        (bool)
                    )
            ) {
                revert MetadataRecoveryBindingInvalid(p.target);
            }
        }
    }

    function _supports(address target, bytes4 id) private view {
        if (
            !abi.decode(
                    read(target, abi.encodeCall(IERC165.supportsInterface, (id)), 32, READ_GAS),
                    (bool)
                )
                || !abi.decode(
                    read(
                        target,
                        abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)),
                        32,
                        READ_GAS
                    ),
                    (bool)
                )
                || abi.decode(
                    read(
                        target,
                        abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))),
                        32,
                        READ_GAS
                    ),
                    (bool)
                )
        ) {
            revert MetadataRecoveryBindingInvalid(target);
        }
    }

    function _address(address target, bytes memory input) private view returns (address value) {
        value = abi.decode(read(target, input, 32, READ_GAS), (address));
        if (value.code.length == 0) revert MetadataRecoveryBindingInvalid(value);
    }

    /// @dev Historical Executor identity is exact but its current runtime is not route evidence.
    function _identityAddress(address target, bytes memory input)
        private
        view
        returns (address value)
    {
        value = abi.decode(read(target, input, 32, READ_GAS), (address));
        if (value == address(0)) revert MetadataRecoveryBindingInvalid(value);
    }

    function read(address target, bytes memory input, uint256 length, uint256 cap)
        internal
        view
        returns (bytes memory output)
    {
        output = new bytes(length);
        uint256 required = cap + cap / 63 + 100000;
        if (gasleft() <= required) revert MetadataRecoveryParentGas(gasleft(), required);
        bool ok;
        uint256 returned;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(output, 32), length)
            returned := returndatasize()
        }
        if (!ok || returned != length) {
            bytes4 selector;
            assembly ("memory-safe") { selector := mload(add(input, 32)) }
            revert MetadataRecoveryReadFailed(target, selector);
        }
    }
}
