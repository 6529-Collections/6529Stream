// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/finality/IStreamFinalityHostAdapter.sol";
import "../../interfaces/stream/finality/IStreamFinalityComponentFacts.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/metadata/IStreamCollectionMetadata.sol";
import "../../interfaces/stream/metadata/IStreamMetadataRouter.sol";
import "../../interfaces/stream/entropy/IStreamEntropyCoordinator.sol";
import "../metadata/StreamMetadataSubjects.sol";

/// @notice Constructor-fixed component identity over an authoritative scope-evidence host.
/// @dev This adapter cannot make incomplete host evidence final. New discovery must call
///      requireCurrentSelection; old records can still read their exact pinned host after a
///      permitted pointer replacement. The host validates actual membership, locks and bytes.
contract StreamFinalityHostAdapter is IStreamFinalityHostAdapter {
    address public immutable override core;
    address public immutable override host;
    bytes32 public immutable override componentType;
    bytes32 public immutable override hostCodeHash;
    bytes32 public immutable override coreCodeHash;
    bytes32 public immutable override hostPointerType;
    bytes4 public immutable hostInterfaceId;

    struct PointerFacts {
        address target;
        bytes32 codeHash;
        bool frozen;
        bytes32 moduleType;
        bytes4 interfaceId;
        address registry;
        uint8 registryStatus;
        bytes32 moduleManifestHash;
        bytes32 deploymentManifestHash;
        uint64 revision;
    }

    error InvalidFinalityHost(address host);
    error InvalidFinalityCore(address core);
    error UnknownFinalityComponent(bytes32 componentType);
    error InvalidFinalityRead(address target, bytes4 selector);
    error FinalityHostNotSelected(address selected);
    error InvalidFinalityHostFacts();

    constructor(address core_, address host_, bytes32 componentType_) {
        if (core_.code.length == 0 || !_supports(core_, 0x80ac58cd)) {
            revert InvalidFinalityCore(core_);
        }
        (bytes32 pointerType, bytes4 primaryInterface) = _hostIdentity(componentType_);
        core = core_;
        host = host_;
        componentType = componentType_;
        hostPointerType = pointerType;
        hostInterfaceId = primaryInterface;
        coreCodeHash = core_.codehash;
        hostCodeHash = host_.codehash;
        _requireHost();
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IStreamFinalityHostAdapter).interfaceId
            || id == type(IStreamArtworkFinalityComponent).interfaceId
            || id == type(IStreamArtworkScopedFinalityComponent).interfaceId;
    }

    function finalityState(uint256 collectionId)
        external
        view
        override
        returns (StreamFinalityComponentState memory)
    {
        return _state(StreamFinalityScope(StreamFinalityScopeType.COLLECTION, collectionId, 0, 0));
    }

    function finalityStateForScope(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (StreamFinalityComponentState memory)
    {
        return _state(scope);
    }

    function requireCurrentSelection() external view override {
        _requireHost();
        PointerFacts memory pointer = abi.decode(
            _read(
                core,
                abi.encodeCall(IStreamCorePointers.getSatellitePointer, (hostPointerType)),
                320
            ),
            (PointerFacts)
        );
        if (
            pointer.target != host || pointer.codeHash != hostCodeHash
                || pointer.moduleType != hostPointerType || pointer.interfaceId != hostInterfaceId
                || pointer.registry == address(0) || pointer.registryStatus != 1
                || pointer.moduleManifestHash == 0 || pointer.deploymentManifestHash == 0
                || pointer.revision == 0
        ) revert FinalityHostNotSelected(pointer.target);
    }

    function _state(StreamFinalityScope memory scope)
        private
        view
        returns (StreamFinalityComponentState memory)
    {
        // Shape checks do not replace the host's actual Core/scope membership checks.
        StreamMetadataSubjects.scopeSubject(block.chainid, core, scope);
        _requireHost();
        StreamFinalityHostComponentFacts memory facts = abi.decode(
            _read(
                host,
                abi.encodeCall(
                    IStreamFinalityComponentFacts.finalityComponentFacts, (componentType, scope)
                ),
                128
            ),
            (StreamFinalityHostComponentFacts)
        );
        if (facts.moduleVersion == 0 || facts.manifestHash == 0 || facts.dataHash == 0) {
            revert InvalidFinalityHostFacts();
        }
        return StreamFinalityComponentState({
            frozen: facts.frozen,
            componentType: componentType,
            component: address(this),
            interfaceId: type(IStreamFinalityHostAdapter).interfaceId,
            codeHash: address(this).codehash,
            moduleVersion: facts.moduleVersion,
            manifestHash: facts.manifestHash,
            dataHash: facts.dataHash
        });
    }

    function _requireHost() private view {
        if (core.code.length == 0 || core.codehash != coreCodeHash) {
            revert InvalidFinalityCore(core);
        }
        if (
            host.code.length == 0 || host.codehash != hostCodeHash
                || !_supports(host, type(IERC165).interfaceId) || _supports(host, 0xffffffff)
                || !_supports(host, hostInterfaceId)
                || !_supports(host, type(IStreamFinalityComponentFacts).interfaceId)
                || abi.decode(
                        _read(host, abi.encodeCall(IStreamFinalityComponentFacts.core, ()), 32),
                        (address)
                    ) != core
        ) revert InvalidFinalityHost(host);
    }

    function _supports(address target, bytes4 id) private view returns (bool) {
        return
            abi.decode(_read(target, abi.encodeCall(IERC165.supportsInterface, (id)), 32), (bool));
    }

    /// @dev Fixed output allocation prevents return-data expansion; malformed replies fail.
    ///      The registry's governed outer call cap owns the expensive host-read allowance.
    function _read(address target, bytes memory input, uint256 length)
        private
        view
        returns (bytes memory output)
    {
        output = new bytes(length);
        bool success;
        uint256 returned;
        assembly ("memory-safe") {
            success := staticcall(
                gas(),
                target,
                add(input, 32),
                mload(input),
                add(output, 32),
                length
            )
            returned := returndatasize()
        }
        if (!success || returned != length) {
            bytes4 selector;
            assembly ("memory-safe") { selector := mload(add(input, 32)) }
            revert InvalidFinalityRead(target, selector);
        }
    }

    function _hostIdentity(bytes32 family) private pure returns (bytes32 pointer, bytes4 id) {
        if (
            family == StreamFinalityDomains.COMPONENT_COLLECTION_METADATA
                || family == StreamFinalityDomains.COMPONENT_REFERENCE_RENDER
        ) {
            return (
                StreamFinalityDomains.COMPONENT_COLLECTION_METADATA,
                type(IStreamCollectionMetadata).interfaceId
            );
        }
        if (family == StreamFinalityDomains.COMPONENT_ENTROPY_COORDINATOR) {
            return (family, type(IStreamEntropyCoordinator).interfaceId);
        }
        if (
            family == StreamFinalityDomains.COMPONENT_METADATA_ROUTER
                || family == StreamFinalityDomains.COMPONENT_RENDERER
                || family == StreamFinalityDomains.COMPONENT_RENDER_CONTEXT
                || family == StreamFinalityDomains.COMPONENT_MEDIA_MANIFEST
                || family == StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE
                || family == StreamFinalityDomains.COMPONENT_DEPENDENCY_SOURCE
        ) {
            return (
                StreamFinalityDomains.COMPONENT_METADATA_ROUTER,
                type(IStreamMetadataRouter).interfaceId
            );
        }
        revert UnknownFinalityComponent(family);
    }
}
