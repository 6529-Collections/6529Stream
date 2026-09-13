// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/finality/IStreamFinalityServingHostAdapter.sol";
import "../../interfaces/stream/finality/IStreamFinalityServingEvidenceProvider.sol";
import "../../interfaces/stream/metadata/IStreamMetadataRouter.sol";
import "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import "../../interfaces/stream/entropy/IStreamEntropyCoordinator.sol";
import "../metadata/StreamMetadataRecoveryRoutes.sol";

/// @notice Fixed provider-backed component identity for the actual serving host.
/// @dev Does not change the original HostAdapter. Historical state reads require all immutable
///      code/reciprocal joins, while only current-discovery admission checks Core selection.
contract StreamFinalityServingHostAdapter is IStreamFinalityServingHostAdapter {
    address public immutable override core;
    address public immutable override host;
    bytes32 public immutable override componentType;
    bytes32 public immutable override hostCodeHash;
    bytes32 public immutable override coreCodeHash;
    bytes32 public immutable override hostPointerType;
    address public immutable override evidenceProvider;
    bytes32 public immutable override evidenceProviderCodeHash;
    address public immutable override metadataHost;
    bytes32 public immutable override metadataHostCodeHash;
    bytes4 private immutable _hostInterface;
    error FinalityServingBindingInvalid(address target);
    error FinalityServingFamilyUnsupported(bytes32 family);

    constructor(address core_, address host_, address provider_, bytes32 family) {
        core = core_;
        host = host_;
        evidenceProvider = provider_;
        componentType = family;
        coreCodeHash = core_.codehash;
        hostCodeHash = host_.codehash;
        evidenceProviderCodeHash = provider_.codehash;
        (bytes32 key, bytes4 id) = _identity(family);
        hostPointerType = key;
        _hostInterface = id;
        metadataHost = abi.decode(
            _read(
                provider_,
                abi.encodeCall(IStreamFinalityServingEvidenceProvider.metadataHost, ()),
                32
            ),
            (address)
        );
        metadataHostCodeHash = metadataHost.codehash;
        _pins();
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IStreamFinalityHostAdapter).interfaceId
            || id == type(IStreamFinalityServingHostAdapter).interfaceId
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
        _pins();
        StreamMetadataRecoveryRoutes.requireCurrentHost(
            core, hostPointerType, host, hostPointerType, _hostInterface
        );
        StreamMetadataRecoveryRoutes.requireCurrentHost(
            core,
            keccak256("COLLECTION_METADATA"),
            metadataHost,
            keccak256("COLLECTION_METADATA"),
            type(IStreamCollectionMetadataV1).interfaceId
        );
    }

    function _state(StreamFinalityScope memory scope)
        private
        view
        returns (StreamFinalityComponentState memory)
    {
        if (
            scope.collectionId == 0
                || (scope.scopeType == StreamFinalityScopeType.COLLECTION
                        ? scope.tokenId != 0 || scope.scopeId != 0
                        : scope.scopeType == StreamFinalityScopeType.TOKEN
                            ? scope.tokenId == 0 || scope.scopeId != 0
                            : scope.tokenId != 0 || scope.scopeId == 0)
        ) revert FinalityServingBindingInvalid(core);
        _pins();
        StreamFinalityHostComponentFacts memory f = abi.decode(
            _read(
                evidenceProvider,
                abi.encodeCall(
                    IStreamFinalityComponentFacts.finalityComponentFacts, (componentType, scope)
                ),
                128
            ),
            (StreamFinalityHostComponentFacts)
        );
        if (f.moduleVersion == 0 || f.manifestHash == 0 || f.dataHash == 0) {
            revert FinalityServingBindingInvalid(evidenceProvider);
        }
        return StreamFinalityComponentState(
            f.frozen,
            componentType,
            address(this),
            scope.scopeType == StreamFinalityScopeType.COLLECTION
                ? type(IStreamArtworkFinalityComponent).interfaceId
                : type(IStreamArtworkScopedFinalityComponent).interfaceId,
            address(this).codehash,
            f.moduleVersion,
            f.manifestHash,
            f.dataHash
        );
    }

    function _pins() private view {
        if (
            core.code.length == 0 || host.code.length == 0 || evidenceProvider.code.length == 0
                || metadataHost.code.length == 0 || core.codehash != coreCodeHash
                || host.codehash != hostCodeHash
                || evidenceProvider.codehash != evidenceProviderCodeHash
                || metadataHost.codehash != metadataHostCodeHash
                || abi.decode(
                        _read(
                            evidenceProvider,
                            abi.encodeCall(IStreamFinalityComponentFacts.core, ()),
                            32
                        ),
                        (address)
                    ) != core
                || abi.decode(
                        _read(
                            evidenceProvider,
                            abi.encodeCall(IStreamFinalityServingEvidenceProvider.metadataHost, ()),
                            32
                        ),
                        (address)
                    ) != metadataHost
                || abi.decode(
                        _read(
                            evidenceProvider,
                            abi.encodeCall(
                                IStreamFinalityServingEvidenceProvider.componentHost,
                                (componentType)
                            ),
                            32
                        ),
                        (address)
                    ) != host
                || abi.decode(_read(metadataHost, abi.encodeWithSignature("core()"), 32), (address))
                    != core
                || abi.decode(_read(host, abi.encodeWithSignature("core()"), 32), (address)) != core
        ) revert FinalityServingBindingInvalid(host);
        _supports(host, _hostInterface);
        _supports(evidenceProvider, type(IStreamFinalityServingEvidenceProvider).interfaceId);
    }

    function _supports(address target, bytes4 id) private view {
        if (
            !abi.decode(_read(target, abi.encodeCall(IERC165.supportsInterface, (id)), 32), (bool))
                || !abi.decode(
                    _read(
                        target,
                        abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)),
                        32
                    ),
                    (bool)
                )
                || abi.decode(
                    _read(
                        target, abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))), 32
                    ),
                    (bool)
                )
        ) revert FinalityServingBindingInvalid(target);
    }

    function _read(address target, bytes memory data, uint256 size)
        private
        view
        returns (bytes memory)
    {
        // Fixed-copy-only adapter reads inherit the caller's governed component budget.
        bytes memory output = new bytes(size);
        bool ok;
        uint256 n;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), add(output, 32), size)
            n := returndatasize()
        }
        if (!ok || n != size) revert FinalityServingBindingInvalid(target);
        return output;
    }

    function _identity(bytes32 family) private pure returns (bytes32, bytes4) {
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
        revert FinalityServingFamilyUnsupported(family);
    }
}
