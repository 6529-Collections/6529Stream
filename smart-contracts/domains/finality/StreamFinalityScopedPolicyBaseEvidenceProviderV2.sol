// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityNativeEvidenceProvider.sol";
import { StreamFinalityScopedProviderReads } from "./StreamFinalityScopedProviderReads.sol";
import { StreamFinalityScopedSnapshotReads } from "./StreamFinalityScopedSnapshotReads.sol";
import {
    StreamFinalityScopedProviderOperations
} from "./StreamFinalityScopedProviderOperations.sol";
import { StreamFinalityScopedProviderMetadata } from "./StreamFinalityScopedProviderMetadata.sol";
import { StreamFinalityScopedMetadataFacts } from "./StreamFinalityScopedMetadataFacts.sol";
import { StreamFinalityScopedStaticComponents } from "./StreamFinalityScopedStaticComponents.sol";
import "../../interfaces/stream/finality/IStreamFinalityScopedMetadataReads.sol";
import "../../interfaces/stream/finality/IStreamScopedContentRootEvidenceBinding.sol";

/// @notice Additive inheritance surface preserving original COLLECTION and scoped V1 bodies.
/// @dev The original COLLECTION path executes unchanged super bodies at this host address. It
/// does not inherit records or provider identity from a prior deployment. All supplemental
/// sources are constructor-only and must be actual/current/reciprocal on operative reads.
/// Only this new inheritance copy exposes virtual scoped reads for the complete-policy sibling.
contract StreamFinalityScopedPolicyBaseEvidenceProviderV2 is
    StreamFinalityNativeEvidenceProvider,
    IStreamFinalityScopedMetadataReads,
    IStreamScopedContentRootEvidenceBinding
{
    StreamFinalityScopedProviderReads.Config private _scoped;

    constructor(
        StreamFinalityNativeProviderReads.Config memory original,
        StreamFinalityScopedProviderReads.Config memory scoped
    ) StreamFinalityNativeEvidenceProvider(original) {
        if (
            scoped.chainId != original.chainId || scoped.readGas != original.readGas
                || scoped.sourceGas != original.sourceGas
                || scoped.componentSourceGas != original.componentSourceGas
                || scoped.inventoryDependencyHash == 0
        ) revert StreamFinalityScopedProviderReads.NativeProviderConfiguration();
        for (uint256 i; i < 22; ++i) {
            if (scoped.targets[i] == address(0) || scoped.codeHashes[i] == 0) {
                revert StreamFinalityScopedProviderReads.NativeProviderConfiguration();
            }
            // Only the scoped snapshot/reference/inventory/bundle replace original roles.
            // No alias of their records or profiles is inferred from sharing the other roles.
            if (i != 8 && i != 9 && i != 18 && i != 19) {
                if (
                    scoped.targets[i] != original.targets[i]
                        || scoped.codeHashes[i] != original.codeHashes[i]
                ) {
                    revert StreamFinalityScopedProviderReads.NativeProviderConfiguration();
                }
            }
        }
        _scoped = scoped;
    }

    function supportsInterface(bytes4 id) public pure virtual override returns (bool) {
        return super.supportsInterface(id)
            || id == type(IStreamFinalityScopedMetadataReads).interfaceId
            || id == type(IStreamScopedContentRootEvidenceBinding).interfaceId;
    }

    function scopedConfiguration()
        external
        view
        returns (StreamFinalityScopedProviderReads.Config memory)
    {
        return _scoped;
    }

    function scopedSnapshotHost() external view override returns (address) {
        return _scoped.targets[8];
    }

    function scopedSnapshotCodeHash() external view override returns (bytes32) {
        return _scoped.codeHashes[8];
    }

    function scopedSnapshotValidationGas() external view override returns (uint256) {
        return _scoped.componentSourceGas;
    }

    function scopedContentRoot(StreamFinalityScope calldata scope)
        public
        view
        virtual
        override
        returns (bytes32, uint64, bytes32)
    {
        return StreamFinalityScopedProviderMetadata.root(_metadataConfig(), scope);
    }

    function scopedSnapshotHash(StreamFinalityScope calldata scope)
        public
        view
        virtual
        override
        returns (bytes32)
    {
        return StreamFinalityScopedProviderMetadata.snapshot(_metadataConfig(), scope);
    }

    function scopedManifest(StreamFinalityScope calldata scope)
        public
        view
        virtual
        override
        returns (bool, bytes32)
    {
        return StreamFinalityScopedProviderMetadata.manifest(_metadataConfig(), scope);
    }

    function finalityComponentFacts(bytes32 family, StreamFinalityScope calldata scope)
        public
        view
        virtual
        override
        returns (StreamFinalityHostComponentFacts memory f)
    {
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            return super.finalityComponentFacts(family, scope);
        }
        _requireScoped(scope);
        _pins();
        _scope(scope);
        if (family == StreamFinalityDomains.COMPONENT_COLLECTION_METADATA) {
            (f.frozen, f.dataHash) = StreamFinalityScopedMetadataFacts.facts(_scoped, scope);
            f.moduleVersion = metadataModuleVersion;
            f.manifestHash = metadataModuleManifestHash;
        } else {
            componentHost(family);
            (f.frozen, f.dataHash) =
                StreamFinalityScopedStaticComponents.facts(_scoped, scope, family);
            f.moduleVersion = routerModuleVersion;
            f.manifestHash = routerModuleManifestHash;
        }
    }

    function inputManifestBytes(StreamFinalityScope calldata scope)
        public
        view
        virtual
        override
        returns (bytes memory)
    {
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            return super.inputManifestBytes(scope);
        }
        _requireScoped(scope);
        return StreamFinalityScopedProviderOperations.manifest(_scoped, scope);
    }

    function requireFinalityScopeInputs(StreamFinalityScope calldata scope, bytes32 manifestHash)
        public
        view
        virtual
        override
        returns (StreamFinalityScopeInputs memory, bytes32, bytes32)
    {
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            return super.requireFinalityScopeInputs(scope, manifestHash);
        }
        _requireScoped(scope);
        return StreamFinalityScopedProviderOperations.inputs(_scoped, scope, manifestHash);
    }

    function requireSanctionReviewFacts(StreamFinalityScope calldata scope, bytes32 manifestHash)
        public
        view
        virtual
        override
        returns (IStreamFinalitySanctionReview.ReviewFacts memory)
    {
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            return super.requireSanctionReviewFacts(scope, manifestHash);
        }
        _requireScoped(scope);
        return StreamFinalityScopedProviderOperations.review(_scoped, scope, manifestHash);
    }

    function requirePreparedFinalityScopeInputs(
        StreamFinalityScope calldata scope,
        bytes32 manifestHash,
        StreamFinalityComponentExpectation[] calldata components
    ) public view virtual override returns (StreamFinalityScopeInputs memory, bytes32, bytes32) {
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            return super.requirePreparedFinalityScopeInputs(scope, manifestHash, components);
        }
        // Fixed worker retains Registry/runtime admission before scope/source validation.
        (StreamFinalityScopeInputs memory inputs_, bytes32 schema, bytes32 canon,) = StreamFinalityScopedProviderOperations.prepared(
            _scoped, scope, manifestHash, components, false
        );
        return (inputs_, schema, canon);
    }

    function requirePreparedFinalityScopeInputsAndReview(
        StreamFinalityScope calldata scope,
        bytes32 manifestHash,
        StreamFinalityComponentExpectation[] calldata components
    )
        public
        view
        virtual
        override
        returns (
            StreamFinalityScopeInputs memory,
            bytes32,
            bytes32,
            IStreamFinalitySanctionReview.ReviewFacts memory
        )
    {
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            return
                super.requirePreparedFinalityScopeInputsAndReview(scope, manifestHash, components);
        }
        // Fixed worker retains Registry/runtime admission before scope/source validation.
        return StreamFinalityScopedProviderOperations.prepared(
            _scoped, scope, manifestHash, components, true
        );
    }

    function _requireScoped(StreamFinalityScope memory scope) private view {
        if (
            scope.scopeType != StreamFinalityScopeType.TOKEN
                && scope.scopeType != StreamFinalityScopeType.RELEASE
                && scope.scopeType != StreamFinalityScopeType.SEASON
        ) revert RouterProviderScope();
        StreamMetadataSubjects.scopeSubject(deploymentChainId, core, scope);
    }

    function _metadataConfig()
        private
        view
        returns (StreamFinalityScopedProviderMetadata.Config memory c)
    {
        StreamFinalityScopedProviderReads.Config storage s = _scoped;
        c.snapshots = StreamFinalityScopedSnapshotReads.Dependencies(
            s.targets[0],
            s.targets[1],
            s.targets[2],
            s.targets[8],
            s.codeHashes[0],
            s.codeHashes[1],
            s.codeHashes[2],
            s.codeHashes[8],
            s.chainId,
            s.readGas,
            s.componentSourceGas
        );
        c.membership = s.targets[3];
        c.membershipCodeHash = s.codeHashes[3];
    }
}
