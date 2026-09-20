// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityRouterEvidenceProvider.sol";
import "./StreamFinalityNativeMetadataFacts.sol";
import "./StreamCurrentAuthorityNativeSanctionReview.sol";
import "./StreamCurrentAuthorityNativeProviderReads.sol";
import "../../interfaces/stream/finality/IStreamFinalityPreparedSanctionReview.sol";
import "./StreamFinalityRouteReads.sol";
import "../../interfaces/stream/finality/IStreamFinalityPreparedScopeEvidence.sol";
import "../../interfaces/stream/finality/IStreamFinalityEvidenceProvider.sol";
import "../../interfaces/stream/finality/IStreamFinalityDiscoverySources.sol";
import "../../interfaces/stream/finality/IStreamContentRootEvidenceBinding.sol";

/// @notice Additive ten-input COLLECTION provider with authenticated original Artist archives.
/// @dev Late original addresses and runtime pins live in constructor-only storage, avoiding
/// runtime-hash cycles. No setter, deferred binding, readiness cache or caller-selected source.
/// Other specified scopes/profiles require their own producers and remain unsupported here.
contract StreamCurrentAuthorityNativeEvidenceProvider is StreamFinalityRouterEvidenceProvider {
    StreamFinalityNativeProviderReads.Config private _native;
    bytes32 public immutable metadataModuleVersion;
    bytes32 public immutable metadataModuleManifestHash;
    error NativeProviderOriginalRegistryOnly();

    constructor(StreamFinalityNativeProviderReads.Config memory c)
        StreamFinalityRouterEvidenceProvider(
            c.targets[0],
            c.targets[1],
            c.targets[2],
            c.targets[3],
            uint32(c.readGas),
            uint32(c.componentSourceGas)
        )
    {
        if (
            c.chainId != block.chainid || c.readGas > type(uint32).max
                || c.sourceGas > type(uint32).max || c.componentSourceGas > type(uint32).max
                || c.componentSourceGas < c.readGas
                || c.sourceGas <= c.componentSourceGas + c.componentSourceGas / 63 + 100000
                || c.inventoryDependencyHash == 0
        ) {
            revert StreamCurrentAuthorityNativeProviderReads.NativeProviderConfiguration();
        }
        for (uint256 i; i < 22; ++i) {
            if (c.targets[i] == address(0) || c.codeHashes[i] == 0) {
                revert StreamCurrentAuthorityNativeProviderReads.NativeProviderConfiguration();
            }
            // Only early installed sources are admitted now. Future original dependencies have
            // nonzero predicted pins and must be real and reciprocal at every operative read.
            if (
                i < 6 && (c.targets[i].code.length == 0 || c.targets[i].codehash != c.codeHashes[i])
            ) {
                revert StreamCurrentAuthorityNativeProviderReads.NativeProviderDependency(c.targets[
                        i
                    ]);
            }
        }
        _native = c;
        (metadataModuleVersion, metadataModuleManifestHash) =
            StreamFinalityRouterEvidence.moduleIdentity(c.targets[1], c.readGas);
    }

    function supportsInterface(bytes4 id) public pure virtual override returns (bool) {
        return super.supportsInterface(id)
            || id == type(IStreamFinalityEvidenceProvider).interfaceId
            || id == type(IStreamFinalityMetadataReads).interfaceId
            || id == type(IStreamFinalityScopeEvidence).interfaceId
            || id == type(IStreamFinalityPreparedScopeEvidence).interfaceId
            || id == type(IStreamFinalityDiscoverySources).interfaceId
            || id == type(IStreamContentRootEvidenceBinding).interfaceId
            || id == type(IStreamFinalitySanctionReview).interfaceId
            || id == type(IStreamFinalityPreparedSanctionReview).interfaceId;
    }

    function nativeConfiguration()
        external
        view
        returns (StreamFinalityNativeProviderReads.Config memory)
    {
        return _native;
    }

    function referenceRenderHost() external view returns (address) {
        return _native.targets[9];
    }

    function snapshotHost() external view returns (address) {
        return _native.targets[8];
    }

    function entropySourceFactory() external view returns (address) {
        return _native.targets[10];
    }

    function contentLeafManifest() external view returns (address) {
        return _native.targets[6];
    }

    function contentLeafManifestCodeHash() external view returns (bytes32) {
        return _native.codeHashes[6];
    }

    function schemaRegistry() external view returns (address) {
        return _native.targets[4];
    }

    function schemaRegistryCodeHash() external view returns (bytes32) {
        return _native.codeHashes[4];
    }

    function componentHost(bytes32 family) public view override returns (address) {
        if (family == StreamFinalityDomains.COMPONENT_COLLECTION_METADATA) return metadataHost;
        return super.componentHost(family);
    }

    function finalityComponentFacts(bytes32 family, StreamFinalityScope calldata scope)
        public
        view
        virtual
        override
        returns (StreamFinalityHostComponentFacts memory f)
    {
        if (family != StreamFinalityDomains.COMPONENT_COLLECTION_METADATA) {
            return super.finalityComponentFacts(family, scope);
        }
        _pins();
        _scope(scope);
        (f.frozen, f.dataHash) = StreamFinalityNativeMetadataFacts.facts(_native, scope);
        f.moduleVersion = metadataModuleVersion;
        f.manifestHash = metadataModuleManifestHash;
    }

    function collectionMetadataMode(uint256 cid) public view returns (uint8) {
        _pins();
        bytes memory raw = StreamFinalityBoundedReads.read(
            metadataRouter,
            abi.encodeCall(IStreamMetadataServingFacts.collectionServingFacts, (cid)),
            512,
            readGas
        );
        IStreamMetadataServingFacts.ServingFacts memory f =
            abi.decode(raw, (IStreamMetadataServingFacts.ServingFacts));
        if (!f.configured || keccak256(raw) != keccak256(abi.encode(f))) {
            revert RouterProviderScope();
        }
        if (f.mode == keccak256("ONCHAIN")) return 1;
        if (f.mode == keccak256("OFFCHAIN")) return 0;
        revert RouterProviderScope();
    }

    function tokenContentRoot(uint256 cid, bytes32 subject)
        external
        view
        returns (bytes32, uint64, bytes32)
    {
        _pins();
        return abi.decode(
            StreamFinalityBoundedReads.read(
                metadataRouter,
                abi.encodeCall(IStreamContentRootPublication.tokenContentRoot, (cid, subject)),
                96,
                readGas
            ),
            (bytes32, uint64, bytes32)
        );
    }

    function latestCollectionSnapshotHash(uint256 cid) public view virtual returns (bytes32) {
        _pins();
        _snapshotPin();
        StreamSnapshotTypes.Receipt memory r = abi.decode(
            StreamFinalityBoundedReads.read(
                _native.targets[8],
                abi.encodeCall(IStreamCollectionSnapshots.currentSnapshot, (cid)),
                672,
                readGas
            ),
            (StreamSnapshotTypes.Receipt)
        );
        return r.manifestHash;
    }

    function collectionRecordTypeLocked(uint256 cid, bytes32) external view returns (bool) {
        collectionMetadataMode(cid);
        // Generic MetadataV1 dossier publication has no record-type seal. Actual selected WORK/
        // RIGHTS and intent seals are distinct typed facts, never mislabeled as this broad lock.
        return false;
    }

    function scopeManifest(uint256 cid, bytes32 scopeId) external view returns (bool, bytes32) {
        collectionMetadataMode(cid);
        if (scopeId != 0) revert RouterProviderScope();
        return (false, bytes32(0));
    }

    function inputManifestBytes(StreamFinalityScope calldata scope)
        public
        view
        virtual
        returns (bytes memory)
    {
        StreamFinalityNativeProviderReads.Config memory c = _native;
        _candidate(c, scope);
        StreamFinalityInputManifestTypes.Statement memory s =
            StreamCurrentAuthorityNativeProviderReads.statement(
                c, scope, StreamCurrentAuthorityNativeProviderReads.currentComponents(c, scope)
            );
        return StreamFinalityInputManifestReads.encode(
            StreamCurrentAuthorityNativeProviderReads.manifestDependencies(c), s
        );
    }

    function requireFinalityScopeInputs(StreamFinalityScope calldata scope, bytes32 manifestHash)
        public
        view
        virtual
        returns (StreamFinalityScopeInputs memory, bytes32, bytes32)
    {
        StreamFinalityNativeProviderReads.Config memory c = _native;
        _candidate(c, scope);
        return _admit(
            c,
            scope,
            manifestHash,
            StreamCurrentAuthorityNativeProviderReads.currentComponents(c, scope)
        );
    }

    /// @notice Original ordered capture bytes for the artist's review of this exact current manifest.
    function requireSanctionReviewFacts(StreamFinalityScope calldata scope, bytes32 manifestHash)
        public
        view
        virtual
        returns (IStreamFinalitySanctionReview.ReviewFacts memory)
    {
        StreamFinalityNativeProviderReads.Config memory c = _native;
        _candidate(c, scope);
        StreamFinalityInputManifestTypes.Statement memory s =
            StreamCurrentAuthorityNativeProviderReads.statement(
                c, scope, StreamCurrentAuthorityNativeProviderReads.currentComponents(c, scope)
            );
        StreamFinalityInputManifestReads.requireCurrent(
            StreamCurrentAuthorityNativeProviderReads.manifestDependencies(c), s, manifestHash
        );
        return StreamCurrentAuthorityNativeSanctionReview.review(c, s);
    }

    function requirePreparedFinalityScopeInputs(
        StreamFinalityScope calldata scope,
        bytes32 manifestHash,
        StreamFinalityComponentExpectation[] calldata components
    ) public view virtual returns (StreamFinalityScopeInputs memory, bytes32, bytes32) {
        StreamFinalityNativeProviderReads.Config memory c = _native;
        _requirePreparedCandidate(c, scope, components);
        return _admit(
            c,
            scope,
            manifestHash,
            StreamCurrentAuthorityNativeProviderReads.independentComponents(components)
        );
    }

    /// @notice Original Registry-only inputs and image facts from one complete current statement.
    function requirePreparedFinalityScopeInputsAndReview(
        StreamFinalityScope calldata scope,
        bytes32 manifestHash,
        StreamFinalityComponentExpectation[] calldata components
    )
        public
        view
        virtual
        returns (
            StreamFinalityScopeInputs memory inputs,
            bytes32 schema,
            bytes32 canon,
            IStreamFinalitySanctionReview.ReviewFacts memory review
        )
    {
        StreamFinalityNativeProviderReads.Config memory c = _native;
        _requirePreparedCandidate(c, scope, components);
        StreamFinalityInputManifestTypes.Statement memory s =
            StreamCurrentAuthorityNativeProviderReads.statement(
                c,
                scope,
                StreamCurrentAuthorityNativeProviderReads.independentComponents(components)
            );
        (schema, canon) = StreamFinalityInputManifestReads.requireCurrent(
            StreamCurrentAuthorityNativeProviderReads.manifestDependencies(c), s, manifestHash
        );
        inputs = s.inputs;
        review = StreamCurrentAuthorityNativeSanctionReview.review(c, s);
    }

    function _requirePreparedCandidate(
        StreamFinalityNativeProviderReads.Config memory c,
        StreamFinalityScope calldata scope,
        StreamFinalityComponentExpectation[] calldata components
    ) private view {
        if (
            msg.sender != c.targets[12] || msg.sender.code.length == 0
                || msg.sender.codehash != c.codeHashes[12]
        ) {
            revert NativeProviderOriginalRegistryOnly();
        }
        _candidate(c, scope);
        if (!StreamFinalityRouteReads.verifyIfSupported(
                c.targets[13], scope, components, components.length == 10, c.sourceGas
            )) {
            revert StreamCurrentAuthorityNativeProviderReads.NativeProviderSource();
        }
    }

    function _admit(
        StreamFinalityNativeProviderReads.Config memory c,
        StreamFinalityScope memory scope,
        bytes32 manifestHash,
        StreamFinalityComponentExpectation[] memory components
    ) private view returns (StreamFinalityScopeInputs memory, bytes32 schema, bytes32 canon) {
        StreamFinalityInputManifestTypes.Statement memory s =
            StreamCurrentAuthorityNativeProviderReads.statement(c, scope, components);
        (schema, canon) = StreamFinalityInputManifestReads.requireCurrent(
            StreamCurrentAuthorityNativeProviderReads.manifestDependencies(c), s, manifestHash
        );
        return (s.inputs, schema, canon);
    }

    function _candidate(
        StreamFinalityNativeProviderReads.Config memory c,
        StreamFinalityScope memory scope
    ) private view {
        StreamCurrentAuthorityNativeProviderReads.requirePins(c);
        if (
            scope.scopeType != StreamFinalityScopeType.COLLECTION || scope.tokenId != 0
                || scope.scopeId != 0 || collectionMetadataMode(scope.collectionId) != 1
        ) revert RouterProviderScope();
        this.requireCurrentRouterCandidate(scope.collectionId, c.targets[12]);
    }

    function _snapshotPin() private view {
        address target = _native.targets[8];
        if (target.code.length == 0 || target.codehash != _native.codeHashes[8]) {
            revert RouterProviderDependency(target);
        }
    }
}
