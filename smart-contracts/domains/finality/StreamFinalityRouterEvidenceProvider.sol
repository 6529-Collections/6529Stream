// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamFinalityRouterEvidence.sol";
import "../metadata/StreamMetadataRecoveryRoutes.sol";
import "../metadata/StreamMetadataSubjects.sol";
import "../../interfaces/stream/finality/IStreamFinalityServingEvidenceProvider.sol";
import "../../interfaces/stream/finality/IStreamFinalityRouterEvidenceBinding.sol";
import "../../interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import "../../interfaces/stream/metadata/IStreamMetadataRouter.sol";

/// @notice Concrete fixed-provider implementation of the six Router serving families.
/// @dev This is the serving base for the developing complete typed provider. It advertises no
///      ten-reference scope-input, entropy, discovery or complete finality-readiness interface.
contract StreamFinalityRouterEvidenceProvider is
    IStreamFinalityServingEvidenceProvider,
    IStreamFinalityRouterEvidenceBinding,
    IERC165
{
    address public immutable override core;
    bytes32 public immutable override coreCodeHash;
    address public immutable override metadataHost;
    bytes32 public immutable override metadataHostCodeHash;
    address public immutable override metadataRouter;
    bytes32 public immutable override metadataRouterCodeHash;
    address public immutable override scopeMembershipHost;
    bytes32 public immutable override scopeMembershipHostCodeHash;
    uint256 public immutable deploymentChainId;
    uint32 public immutable readGas;
    uint32 public immutable sourceGas;
    bytes32 public immutable routerModuleVersion;
    bytes32 public immutable routerModuleManifestHash;

    error RouterProviderConfiguration();
    error RouterProviderDependency(address target);
    error RouterProviderScope();
    error RouterProviderAnchor(address registry);

    constructor(
        address core_,
        address metadata_,
        address router_,
        address membership_,
        uint32 readGas_,
        uint32 sourceGas_
    ) {
        if (
            core_.code.length == 0 || metadata_.code.length == 0 || router_.code.length == 0
                || membership_.code.length == 0 || readGas_ < 50000 || sourceGas_ < readGas_
        ) {
            revert RouterProviderConfiguration();
        }
        core = core_;
        coreCodeHash = core_.codehash;
        metadataHost = metadata_;
        metadataHostCodeHash = metadata_.codehash;
        metadataRouter = router_;
        metadataRouterCodeHash = router_.codehash;
        scopeMembershipHost = membership_;
        scopeMembershipHostCodeHash = membership_.codehash;
        deploymentChainId = block.chainid;
        readGas = readGas_;
        sourceGas = sourceGas_;
        _address(metadata_, abi.encodeCall(IStreamCollectionMetadataV1.core, ()), core_);
        _address(router_, abi.encodeWithSignature("core()"), core_);
        _address(membership_, abi.encodeWithSignature("core()"), core_);
        _address(membership_, abi.encodeWithSignature("metadataHost()"), metadata_);
        _supports(router_, type(IStreamMetadataServingFacts).interfaceId);
        _supports(router_, type(IStreamMetadataRouter).interfaceId);
        (routerModuleVersion, routerModuleManifestHash) =
            StreamFinalityRouterEvidence.moduleIdentity(router_, sourceGas_);
        // No Coordinator/facade-Finality read, selected pointer or collection lock in construction.
    }

    function supportsInterface(bytes4 id) external pure virtual override returns (bool) {
        return id == type(IERC165).interfaceId
            || id == type(IStreamFinalityServingEvidenceProvider).interfaceId
            || id == type(IStreamFinalityComponentFacts).interfaceId
            || id == type(IStreamFinalityRouterEvidenceBinding).interfaceId;
    }

    function componentHost(bytes32 family) public view virtual override returns (address) {
        if (!StreamFinalityRouterEvidence.supported(family)) {
            revert StreamFinalityRouterEvidence.RouterEvidenceFamily(family);
        }
        return metadataRouter;
    }

    function finalityComponentFacts(bytes32 family, StreamFinalityScope calldata scope)
        external
        view
        virtual
        override
        returns (StreamFinalityHostComponentFacts memory result)
    {
        componentHost(family);
        _pins();
        _scope(scope);
        (result.frozen, result.dataHash) =
            StreamFinalityRouterEvidence.facts(_config(), family, scope);
        result.moduleVersion = routerModuleVersion;
        result.manifestHash = routerModuleManifestHash;
    }

    function requireCurrentRouterCandidate(uint256 collectionId, address registry)
        external
        view
        override
    {
        _pins();
        if (registry.code.length == 0) revert RouterProviderAnchor(registry);
        StreamMetadataRecoveryRoutes.requireCurrentHost(
            core,
            keccak256("METADATA_ROUTER"),
            metadataRouter,
            keccak256("METADATA_ROUTER"),
            type(IStreamMetadataRouter).interfaceId
        );
        StreamMetadataRecoveryRoutes.requireCurrentHost(
            core,
            keccak256("COLLECTION_METADATA"),
            metadataHost,
            keccak256("COLLECTION_METADATA"),
            type(IStreamCollectionMetadataV1).interfaceId
        );
        StreamMetadataRecoveryRoutes.requireCurrentHost(
            core,
            keccak256("ARTWORK_FINALITY_REGISTRY"),
            registry,
            keccak256("ARTWORK_FINALITY_REGISTRY"),
            type(IStreamArtworkFinalityRegistry).interfaceId
        );
        _address(registry, abi.encodeWithSignature("coreReads()"), core);
        _address(registry, abi.encodeWithSignature("scopeEvidenceProvider()"), address(this));
        _address(registry, abi.encodeWithSignature("metadataReads()"), metadataHost);
        if (
            abi.decode(
                    _read(registry, abi.encodeWithSignature("scopeEvidenceProviderCodeHash()"), 32),
                    (bytes32)
                ) != address(this).codehash
        ) revert RouterProviderAnchor(registry);
        (address original, bytes32 codeHash) = abi.decode(
            _read(
                metadataRouter,
                abi.encodeWithSignature("originalFinalityAnchor(uint256)", collectionId),
                64
            ),
            (address, bytes32)
        );
        IStreamMetadataServingFacts.ArtistPresentation memory p = abi.decode(
            _read(
                metadataRouter,
                abi.encodeCall(IStreamMetadataServingFacts.artistPresentation, (collectionId)),
                384
            ),
            (IStreamMetadataServingFacts.ArtistPresentation)
        );
        if (
            !p.locked || p.snapshotHash == 0 || original != registry
                || codeHash != registry.codehash
        ) {
            revert RouterProviderAnchor(registry);
        }
        _address(metadataRouter, abi.encodeWithSignature("artistRegistry()"), p.registry);
        _address(registry, abi.encodeWithSignature("sanctionReads()"), p.registry);
    }

    function _scope(StreamFinalityScope memory scope) private view {
        if (
            scope.collectionId == 0
                || (scope.scopeType == StreamFinalityScopeType.COLLECTION
                        ? scope.tokenId != 0 || scope.scopeId != 0
                        : scope.scopeType == StreamFinalityScopeType.TOKEN
                            ? scope.tokenId == 0 || scope.scopeId != 0
                            : scope.tokenId != 0 || scope.scopeId == 0)
        ) revert RouterProviderScope();
        StreamScopeMembershipFacts memory f = abi.decode(
            StreamFinalityRouterEvidence.read(
                scopeMembershipHost,
                abi.encodeWithSignature(
                    "requireScopeMembership((uint8,uint256,uint256,bytes32))", scope
                ),
                256,
                sourceGas
            ),
            (StreamScopeMembershipFacts)
        );
        if (
            f.scopeSubject != StreamMetadataSubjects.scopeSubject(deploymentChainId, core, scope)
                || f.membershipHash == 0
        ) {
            revert RouterProviderScope();
        }
        // Membership admission belongs to the fixed authoritative host. A mutable collection
        // inventory head is deliberately not included in immutable Router source data hashes.
    }

    function _config() private view returns (StreamFinalityRouterEvidence.Config memory) {
        return StreamFinalityRouterEvidence.Config(
            core, metadataRouter, deploymentChainId, readGas, sourceGas
        );
    }

    function _pins() private view {
        if (block.chainid != deploymentChainId) revert RouterProviderConfiguration();
        _pin(core, coreCodeHash);
        _pin(metadataHost, metadataHostCodeHash);
        _pin(metadataRouter, metadataRouterCodeHash);
        _pin(scopeMembershipHost, scopeMembershipHostCodeHash);
    }

    function _pin(address target, bytes32 hash) private view {
        if (target.code.length == 0 || target.codehash != hash) {
            revert RouterProviderDependency(target);
        }
    }

    function _address(address target, bytes memory input, address expected) private view {
        if (abi.decode(_read(target, input, 32), (address)) != expected) {
            revert RouterProviderDependency(target);
        }
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
        ) {
            revert RouterProviderDependency(target);
        }
    }

    function _read(address target, bytes memory input, uint256 size)
        private
        view
        returns (bytes memory)
    {
        return StreamFinalityRouterEvidence.read(target, input, size, readGas);
    }
}
