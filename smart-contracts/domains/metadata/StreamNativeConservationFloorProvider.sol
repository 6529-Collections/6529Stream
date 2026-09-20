// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/IStreamConservationFloorProvider.sol";
import "../../interfaces/stream/metadata/IStreamConservationReleaseContext.sol";
import "../../interfaces/stream/metadata/IStreamMediaMasterSelection.sol";
import "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import "../../interfaces/stream/metadata/IStreamCollectionManifestReads.sol";
import "../../interfaces/stream/metadata/IStreamScriptBundles.sol";
import "../../interfaces/stream/metadata/StreamCollectionManifestTypes.sol";
import "../../interfaces/stream/artist/IStreamArtistPlatformWorks.sol";
import "../../interfaces/stream/artist/StreamArtistPlatformTypes.sol";
import "../../interfaces/stream/core/IStreamCore.sol";
import "../finality/StreamFinalityConservationReads.sol";
import "../../interfaces/stream/core/IStreamCoreConservationTier.sol";
import "../parameters/StreamGasParameterHost.sol";
import "./StreamConservationSaleRights.sol";
import "./StreamConservationTiers.sol";

/// @notice Original native records and complete selected media slots for primary conservation.
/// @dev Documentary personhood remains unavailable; FULL script sales require the original prospective reference host.
/// This host never substitutes an opaque schema head for the held personhood verification.
contract StreamNativeConservationFloorProvider is
    StreamGasParameterHost,
    IStreamConservationFloorProvider,
    IStreamConservationReleaseContext
{
    struct Configuration {
        // Core, Metadata, schemas, store, RIGHTS, conservation, masters, Router, Artist,
        // original prospective reference host. The last target may be absent (FULL scripts then fail).
        address[10] targets;
        bytes32[10] codeHashes;
        address executor;
        GasParameterConfig readGas;
        GasParameterConfig sourceGas;
        GasParameterConfig referenceGas;
    }

    Configuration private _configuration;
    address public immutable override core;
    bytes32 public immutable override coreCodeHash;
    address public immutable override metadata;
    bytes32 public immutable override metadataCodeHash;
    bytes32 public immutable override configurationHash;
    uint256 public immutable override deploymentChainId;
    bytes32 public constant READ_GAS = keccak256("6529STREAM_GGP_CONSERVATION_PROVIDER_READ_GAS");
    bytes32 public constant SOURCE_GAS =
        keccak256("6529STREAM_GGP_CONSERVATION_PROVIDER_SOURCE_GAS");
    bytes32 public constant REFERENCE_GAS =
        keccak256("6529STREAM_GGP_CONSERVATION_PROVIDER_REFERENCE_GAS");

    error InvalidNativeConservationConfiguration();
    error NativeConservationDependency(address target);
    error NativeConservationRead(address target, bytes4 selector);
    error NativeConservationScopeUnavailable();
    error NativePersonhoodVerificationUnavailable(
        uint256 collectionId, bytes32 artistId, bytes32 identityRecordHash
    );
    error NativePresaleReferenceUnavailable(uint256 collectionId);

    constructor(Configuration memory c) StreamGasParameterHost(c.executor) {
        for (uint256 i; i < 9; ++i) {
            if (i == 5 || i == 6) continue;
            if (c.targets[i].code.length == 0 || c.targets[i].codehash != c.codeHashes[i]) {
                revert InvalidNativeConservationConfiguration();
            }
        }
        if (c.targets[9] == address(0)
                ? c.codeHashes[9] != 0
                : (c.targets[9].code.length == 0 || c.targets[9].codehash != c.codeHashes[9])) {
            revert InvalidNativeConservationConfiguration();
        }
        if (
            _registerGasParameter(c.readGas) != READ_GAS
                || _registerGasParameter(c.sourceGas) != SOURCE_GAS
                || _registerGasParameter(c.referenceGas) != REFERENCE_GAS
                || c.readGas.failureClass != 2 || c.sourceGas.failureClass != 2
                || c.referenceGas.failureClass != 2
                || c.sourceGas.genesisValue <= c.readGas.genesisValue
                || c.referenceGas.genesisValue <= c.readGas.genesisValue
        ) {
            revert InvalidNativeConservationConfiguration();
        }
        _configuration = c;
        core = c.targets[0];
        coreCodeHash = c.codeHashes[0];
        metadata = c.targets[1];
        metadataCodeHash = c.codeHashes[1];
        deploymentChainId = block.chainid;
        configurationHash = keccak256(
            abi.encode(keccak256("6529STREAM_NATIVE_CONSERVATION_PROVIDER_V1"), block.chainid, c)
        );
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IStreamConservationFloorProvider).interfaceId
            || id == type(IStreamConservationReleaseContext).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId || id == 0x01ffc9a7;
    }

    /// @notice Diagnostic original RIGHTS/intent/interview facts. Zero personhood means unavailable.
    /// @dev This diagnostic is not a successful floor proof and is never consumed as one by the ledger.
    function currentCollectionRecords(uint256 collectionId)
        public
        view
        returns (StreamConservationFloorTypes.CollectionFacts memory f)
    {
        _collection(collectionId);
        StreamConservationSaleRights.Dependencies memory rights;
        for (uint256 i; i < 5; ++i) {
            rights.targets[i] = _configuration.targets[i];
            rights.codeHashes[i] = _configuration.codeHashes[i];
        }
        rights.chainId = deploymentChainId;
        rights.readGas = _gasParameterValue(READ_GAS);
        rights.selectionGas = _gasParameterValue(SOURCE_GAS);
        f.rightsRecordHash =
        StreamConservationSaleRights.requireCurrent(rights, collectionId).recordHash;
        f.platformWorks = _platform(collectionId);
        if (f.platformWorks) return f;
        _pin(5);
        StreamFinalityConservationReads.Dependencies memory conservation;
        for (uint256 i; i < 4; ++i) {
            conservation.targets[i] = _configuration.targets[i];
            conservation.codeHashes[i] = _configuration.codeHashes[i];
        }
        conservation.targets[4] = _configuration.targets[5];
        conservation.codeHashes[4] = _configuration.codeHashes[5];
        conservation.chainId = deploymentChainId;
        conservation.readGas = rights.readGas;
        conservation.selectionGas = rights.selectionGas;
        StreamFinalityConservationEvidence memory e =
            StreamFinalityConservationReads.requireCurrent(conservation, _scope(collectionId));
        f.artistId = e.selected.association.artistId;
        f.identityRecordHash = e.selected.association.identityRecordHash;
        f.intentRecordHash = e.intentRecordHash;
        f.intentWaiverRecordHash = e.intentWaiverRecordHash;
        f.interviewEvidenceHash = e.interviewEvidenceHash;
    }

    function requireCollectionFloor(uint256 collectionId, bytes32 tier)
        external
        view
        override
        returns (StreamConservationFloorTypes.CollectionFacts memory f)
    {
        _tier(tier);
        f = currentCollectionRecords(collectionId);
        if (!f.platformWorks) {
            revert NativePersonhoodVerificationUnavailable(
                collectionId, f.artistId, f.identityRecordHash
            );
        }
    }

    /// @notice Actual current source description for prospective evidence preparation.
    /// @dev This diagnostic does not certify that collection or release sale floors are met.
    function currentReleaseContext(uint256 collectionId)
        external
        view
        override
        returns (StreamConservationFloorTypes.ReleaseContext memory)
    {
        StreamConservationFloorTypes.SaleContext memory sale;
        sale.collectionId = collectionId;
        return _release(sale);
    }

    function saleRelease(StreamConservationFloorTypes.SaleContext calldata sale)
        external
        view
        override
        returns (StreamConservationFloorTypes.ReleaseContext memory r)
    {
        r = _release(sale);
        if (
            r.scriptWork
                && abi.decode(
                        _read(
                            core,
                            abi.encodeCall(
                                IStreamCoreConservationTier.declaredConservationTier,
                                (sale.collectionId)
                            ),
                            32,
                            _gasParameterValue(READ_GAS)
                        ),
                        (bytes32)
                    ) == StreamConservationTiers.MUSEUM_GRADE
        ) {
            // Eligibility is checked before the ledger can reuse an earlier semantic release.
            _reference(sale, r);
        }
    }

    function requireReleaseFloor(
        StreamConservationFloorTypes.SaleContext calldata sale,
        StreamConservationFloorTypes.ReleaseContext calldata release,
        bytes32 tier
    ) external view override returns (StreamConservationFloorTypes.ReleaseFacts memory facts) {
        _tier(tier);
        StreamConservationFloorTypes.ReleaseContext memory current = _release(sale);
        if (keccak256(abi.encode(current)) != keccak256(abi.encode(release))) {
            revert NativeConservationScopeUnavailable();
        }
        facts.sourceContextHash = current.sourceContextHash;
        facts.mediaEvidenceHash = abi.decode(
            _read(
                _configuration.targets[6],
                abi.encodeCall(
                    IStreamMediaMasterSelection.requireCollectionMasters,
                    (sale.collectionId, current.scopeSubject)
                ),
                32,
                _gasParameterValue(SOURCE_GAS)
            ),
            (bytes32)
        );
        if (facts.mediaEvidenceHash == 0) revert NativeConservationScopeUnavailable();
        if (tier == StreamConservationTiers.MUSEUM_GRADE && current.scriptWork) {
            facts.referenceEvidenceHash = _reference(sale, current);
        }
    }

    function _release(StreamConservationFloorTypes.SaleContext memory sale)
        private
        view
        returns (StreamConservationFloorTypes.ReleaseContext memory r)
    {
        _collection(sale.collectionId);
        if (sale.tokenId != 0) {
            (bool allocated, uint256 cid,, bool burned) = abi.decode(
                _read(
                    core,
                    abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (sale.tokenId)),
                    128,
                    _gasParameterValue(READ_GAS)
                ),
                (bool, uint256, uint256, bool)
            );
            if (!allocated || cid != sale.collectionId || burned) {
                revert NativeConservationScopeUnavailable();
            }
        }
        _pin(6);
        _sameAddress(6, abi.encodeCall(IStreamMediaMasterSelection.core, ()), core);
        _sameAddress(6, abi.encodeCall(IStreamMediaMasterSelection.metadata, ()), metadata);
        _sameAddress(
            6,
            abi.encodeCall(IStreamMediaMasterSelection.schemaRegistry, ()),
            _configuration.targets[2]
        );
        bytes32 mediaManifest;
        uint8 occupied;
        (r.scopeSubject, mediaManifest, r.mediaInventoryHash, occupied) = abi.decode(
            _read(
                _configuration.targets[6],
                abi.encodeCall(
                    IStreamMediaMasterSelection.collectionMediaContext, (sale.collectionId)
                ),
                128,
                _gasParameterValue(SOURCE_GAS)
            ),
            (bytes32, bytes32, bytes32, uint8)
        );
        if (
            r.scopeSubject
                    != StreamMetadataSubjects.scopeSubject(
                        deploymentChainId, core, _scope(sale.collectionId)
                    ) || mediaManifest == 0 || r.mediaInventoryHash == 0 || occupied > 7
        ) revert NativeConservationScopeUnavailable();
        IStreamMetadataServingFacts.ServingFacts memory serving = abi.decode(
            _read(
                _configuration.targets[7],
                abi.encodeCall(
                    IStreamMetadataServingFacts.collectionServingFacts, (sale.collectionId)
                ),
                512,
                _gasParameterValue(SOURCE_GAS)
            ),
            (IStreamMetadataServingFacts.ServingFacts)
        );
        if (
            !serving.configured
                || (serving.mode != keccak256("OFFCHAIN") && serving.mode != keccak256("ONCHAIN"))
                || (serving.presentationProfile
                        != keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1")
                    && serving.presentationProfile
                        != keccak256("6529STREAM_ROUTER_CHUNKED_PRESENTATION_V1"))
        ) {
            revert NativeConservationScopeUnavailable();
        }
        r.scriptWork = serving.mode == keccak256("ONCHAIN");
        bytes32 scriptManifest;
        if (r.scriptWork) {
            (r.scriptSourceHash, scriptManifest) = _script(sale.collectionId, serving);
        } else if (serving.scriptHash != 0 || serving.scriptBytes != 0) {
            revert NativeConservationScopeUnavailable();
        }
        r.membershipHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_COLLECTION_RELEASE_V1"),
                deploymentChainId,
                core,
                sale.collectionId,
                r.scopeSubject,
                r.mediaInventoryHash,
                r.scriptSourceHash
            )
        );
        r.sourceContextHash = keccak256(
            abi.encode(
                configurationHash,
                mediaManifest,
                scriptManifest,
                occupied,
                serving,
                r.membershipHash
            )
        );
    }

    function _script(uint256 collectionId, IStreamMetadataServingFacts.ServingFacts memory serving)
        private
        view
        returns (bytes32 semanticHash, bytes32 manifest)
    {
        uint256 cap = _gasParameterValue(SOURCE_GAS);
        manifest = abi.decode(
            _read(
                metadata,
                abi.encodeCall(IStreamCollectionManifestReads.scriptManifestHash, (collectionId)),
                32,
                cap
            ),
            (bytes32)
        );
        bytes memory raw = _readAtMost(
            metadata,
            abi.encodeCall(IStreamCollectionManifestReads.scriptManifest, (collectionId)),
            8192,
            cap
        );
        StreamCollectionManifestTypes.ScriptManifest memory m =
            abi.decode(raw, (StreamCollectionManifestTypes.ScriptManifest));
        if (
            keccak256(raw) != keccak256(abi.encode(m)) || manifest == 0 || !m.executable
                || m.scriptHash == 0 || m.scriptHash != serving.scriptHash
                || serving.scriptBytes == 0
                || m.rendererCompatibility != serving.presentationProfile
                || bytes(m.libraryURI).length != 0
                || keccak256(bytes(m.mimeType)) != keccak256("application/javascript")
        ) {
            revert NativeConservationScopeUnavailable();
        }
        if (serving.presentationProfile == keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1")) {
            if (
                m.sourceType != StreamCollectionManifestTypes.PayloadSourceType.INLINE_CHUNKS
                    || m.chunkCount != 1 || bytes(m.sourcePointer).length != 0
                    || serving.scriptBytes > 8192
            ) {
                revert NativeConservationScopeUnavailable();
            }
        } else {
            IStreamScriptBundles.Selection memory selected = abi.decode(
                _read(
                    _configuration.targets[7],
                    abi.encodeCall(
                        IStreamScriptBundleSelection.collectionScriptBundle, (collectionId)
                    ),
                    128,
                    cap
                ),
                (IStreamScriptBundles.Selection)
            );
            if (
                selected.host != metadata || selected.codeHash != metadataCodeHash
                    || selected.manifestHash != manifest || selected.bundleId == 0
            ) revert NativeConservationScopeUnavailable();
            IStreamScriptBundles.Facts memory b = abi.decode(
                _read(
                    metadata,
                    abi.encodeCall(IStreamScriptBundles.scriptBundle, (selected.bundleId)),
                    224,
                    cap
                ),
                (IStreamScriptBundles.Facts)
            );
            // Original finalization verified all immutable chunk bytes. A library dependency
            // needs its own complete producer profile; an empty library URI does not exclude it.
            if (
                !b.finalized || b.libraryOnly || b.libraryBundle != 0
                    || b.payloadHash != m.scriptHash || b.totalBytes != serving.scriptBytes
                    || b.chunkCount != m.chunkCount || b.sourceType != m.sourceType
            ) {
                revert NativeConservationScopeUnavailable();
            }
            // The bundle locator includes its Metadata owner. The selected immutable payload
            // and full declared semantic fields, rather than that locator, define a release.
            m.sourcePointer = "";
        }
        semanticHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_NATIVE_SCRIPT_V1"),
                m,
                serving.scriptBytes,
                serving.renderer,
                serving.rendererCodeHash
            )
        );
    }

    function _reference(
        StreamConservationFloorTypes.SaleContext memory sale,
        StreamConservationFloorTypes.ReleaseContext memory release
    ) private view returns (bytes32 evidenceHash) {
        if (_configuration.targets[9] == address(0)) {
            revert NativePresaleReferenceUnavailable(sale.collectionId);
        }
        _pin(9);
        // The original prospective host derives this provider from the permanently bound
        // Floor's current source row, then independently rejoins this exact diagnostic context.
        // It authenticates the original capture/environment evidence, never minted samples.
        evidenceHash = abi.decode(
            _read(
                _configuration.targets[9],
                abi.encodeWithSignature(
                    "requireProspectiveCollectionReference(uint256,bytes32,bytes32)",
                    sale.collectionId,
                    release.scopeSubject,
                    release.membershipHash
                ),
                32,
                _gasParameterValue(REFERENCE_GAS)
            ),
            (bytes32)
        );
        if (evidenceHash == 0) revert NativePresaleReferenceUnavailable(sale.collectionId);
    }

    function _platform(uint256 collectionId) private view returns (bool) {
        bytes memory raw = _read(
            _configuration.targets[8],
            abi.encodeCall(IStreamArtistPlatformWorks.platformWorksState, (collectionId)),
            640,
            _gasParameterValue(SOURCE_GAS)
        );
        StreamArtistPlatformTypes.State memory p =
            abi.decode(raw, (StreamArtistPlatformTypes.State));
        if (keccak256(raw) != keccak256(abi.encode(p))) {
            revert NativeConservationScopeUnavailable();
        }
        return p.declaration.recordHash != 0 && p.declaration.statementHash != 0
            && p.declaration.declaredAt != 0 && !p.correction.accepted;
    }

    function _collection(uint256 id) private view {
        if (block.chainid != deploymentChainId || id == 0) {
            revert NativeConservationScopeUnavailable();
        }
        _pin(0);
        _pin(1);
        _pin(7);
        _pin(8);
        if (
            abi.decode(
                    _read(
                        core,
                        abi.encodeCall(IStreamCoreCollectionView.collectionExists, (id)),
                        32,
                        _gasParameterValue(READ_GAS)
                    ),
                    (uint256)
                ) != 1
        ) revert NativeConservationScopeUnavailable();
        _selected(keccak256("COLLECTION_METADATA"), 1);
        _selected(keccak256("METADATA_ROUTER"), 7);
        _selected(keccak256("ARTIST_REGISTRY"), 8);
    }

    function _selected(bytes32 role, uint256 index) private view {
        bytes memory raw = _read(
            core,
            abi.encodeCall(IStreamCorePointers.getSatellitePointer, (role)),
            320,
            _gasParameterValue(READ_GAS)
        );
        uint256[10] memory w = abi.decode(raw, (uint256[10]));
        address target = address(uint160(w[0]));
        if (
            w[0] > type(uint160).max || w[2] > 1 || bytes32(w[3]) != role
                || (w[4] & type(uint224).max) != 0 || w[5] > type(uint160).max || w[6] != 1
                || w[7] == 0 || w[8] == 0 || w[9] == 0 || w[9] > type(uint64).max
                || target != _configuration.targets[index]
                || bytes32(w[1]) != _configuration.codeHashes[index]
        ) {
            revert NativeConservationDependency(target);
        }
    }

    function _sameAddress(uint256 index, bytes memory data, address expected) private view {
        if (
            abi.decode(
                    _read(_configuration.targets[index], data, 32, _gasParameterValue(READ_GAS)),
                    (address)
                ) != expected
        ) {
            revert NativeConservationDependency(_configuration.targets[index]);
        }
    }

    function _pin(uint256 index) private view {
        address target = _configuration.targets[index];
        if (target.code.length == 0 || target.codehash != _configuration.codeHashes[index]) {
            revert NativeConservationDependency(target);
        }
    }

    function _tier(bytes32 tier) private pure {
        if (
            tier != StreamConservationTiers.MUSEUM_GRADE
                && tier != StreamConservationTiers.MUSEUM_GRADE_LITE
        ) {
            revert InvalidNativeConservationConfiguration();
        }
    }

    function _scope(uint256 id) private pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(StreamFinalityScopeType.COLLECTION, id, 0, 0);
    }

    function _read(address target, bytes memory data, uint256 size, uint256 cap)
        private
        view
        returns (bytes memory raw)
    {
        raw = _readAtMost(target, data, size, cap);
        if (raw.length != size) revert NativeConservationRead(target, bytes4(data));
    }

    function _readAtMost(address target, bytes memory data, uint256 maximum, uint256 cap)
        private
        view
        returns (bytes memory raw)
    {
        if (cap == 0 || cap > type(uint64).max || gasleft() <= cap + cap / 63 + 10000) {
            revert NativeConservationRead(target, bytes4(data));
        }
        raw = new bytes(maximum);
        bool ok;
        uint256 actual;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), add(raw, 32), maximum)
            actual := returndatasize()
        }
        if (!ok || actual > maximum) revert NativeConservationRead(target, bytes4(data));
        assembly ("memory-safe") { mstore(raw, actual) }
    }
}
