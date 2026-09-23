// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import "../../interfaces/stream/preservation/IStreamExternalArtifactCoverage.sol";
import "../../interfaces/stream/preservation/IStreamExternalArtifactCurrentPair.sol";
import "../../interfaces/stream/metadata/IStreamCollectionSnapshots.sol";
import "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import "../../interfaces/stream/core/IStreamCoreMint.sol";
import "../../interfaces/stream/entropy/IStreamEntropyView.sol";
import "../records/StreamReferenceRendererCatalog.sol";
import "../records/StreamSnapshotSourceReads.sol";
import "../finality/StreamFinalitySnapshotReads.sol";
import "../finality/StreamOnchainContentBytes.sol";

import { StreamReferenceDependencyReads } from "./StreamReferenceDependencyReads.sol";

/// @notice Full original source and archive identity joins for native first/last reference capture.
/// @dev Engine execution and full-file retrieval remain attributed observations, not EVM execution.
library StreamReferenceRenderSourceReads {
    /// @dev Only fields actually consumed by source validation; the host retains the full original.
    struct SourceInput {
        uint256 collectionId;
        bytes32 snapshotRecordHash;
        uint64 snapshotRevision;
        bytes32 environmentCoverageHash;
        bytes32 environmentObjectHash;
        StreamReferenceRenderTypes.Capture[] captures;
    }

    /// @notice Early fixed graph only; no Core selection, inventory, Coordinator or Finality reads.
    function validateDependencies(StreamReferenceRenderTypes.Dependencies memory d) public view {
        StreamReferenceDependencyReads.validateDependencies(d);
    }

    function bindings(StreamReferenceRenderTypes.Dependencies memory d)
        public
        view
        returns (StreamSnapshotTypes.Dependencies memory source)
    {
        return StreamReferenceDependencyReads.bindings(d);
    }

    function requireSources(
        StreamReferenceRenderTypes.Dependencies memory d,
        StreamReferenceRenderTypes.Publication memory p,
        bool current
    ) public view returns (StreamReferenceRenderTypes.SourceFacts memory) {
        return requireSourceInputs(d, project(p), current);
    }

    function project(StreamReferenceRenderTypes.Publication memory p)
        internal
        pure
        returns (SourceInput memory)
    {
        return SourceInput(
            p.collectionId,
            p.snapshotRecordHash,
            p.snapshotRevision,
            p.environment.coverageHash,
            p.environment.objectHash,
            p.captures
        );
    }

    function requireSourceInputs(
        StreamReferenceRenderTypes.Dependencies memory d,
        SourceInput memory p,
        bool current
    ) public view returns (StreamReferenceRenderTypes.SourceFacts memory f) {
        return _requireSourceInputs(d, p, current, true);
    }

    /// @notice Distinct mode producer must also authenticate the second archived observation.
    /// The original BYTE_EXACT entry above always retains its equality requirement.
    function requireModeSourceInputs(
        StreamReferenceRenderTypes.Dependencies memory d,
        SourceInput memory p,
        bool current
    ) public view returns (StreamReferenceRenderTypes.SourceFacts memory f) {
        return _requireSourceInputs(d, p, current, false);
    }

    function _requireSourceInputs(
        StreamReferenceRenderTypes.Dependencies memory d,
        SourceInput memory p,
        bool current,
        bool exact
    ) private view returns (StreamReferenceRenderTypes.SourceFacts memory f) {
        StreamSnapshotTypes.Dependencies memory source = bindings(d);
        StreamFinalitySnapshotReads.Dependencies memory snapshot =
            StreamFinalitySnapshotReads.Dependencies(
                d.targets[0],
                d.targets[1],
                d.targets[5],
                d.codeHashes[0],
                d.codeHashes[1],
                d.codeHashes[5],
                d.chainId,
                d.readGas,
                d.snapshotGas
            );
        StreamFinalitySnapshotEvidence memory e = StreamFinalitySnapshotReads.requireCurrent(
            snapshot,
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, p.collectionId, 0, 0),
            p.snapshotRecordHash,
            p.snapshotRevision
        );
        f.snapshot = StreamReferenceRenderTypes.SnapshotBinding(
            e.recordHash,
            e.manifestHash,
            e.sourceHash,
            e.inventoryPlan,
            e.revision,
            e.schemaHash,
            e.profileHash,
            e.canonicalizationHash
        );
        StreamSnapshotTypes.NativeFacts memory native =
            StreamSnapshotSourceReads.requireCurrent(source, p.collectionId);
        f.subject = native.subject;
        f.artistId = native.artist.artistId;
        f.mintedEver = native.checkpoint.tokenCount;
        if (f.mintedEver == 0 || p.captures.length != (f.mintedEver == 1 ? 1 : 2)) {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
        f.renderer = StreamReferenceRendererCatalog.requireStatic(
            d,
            StreamReferenceRenderTypes.RendererDeclaration(
                native.serving.renderer,
                native.serving.rendererCodeHash,
                native.routerVersion,
                native.routerManifestHash,
                native.presentationProfile,
                native.rendererContext,
                native.dependencyProfile,
                keccak256("STATIC")
            )
        );
        f.environmentCoverage =
            coverage(d, p.environmentCoverageHash, f.artistId, p.environmentObjectHash, current);
        _object(d, f.environmentCoverage, true);
        f.samples = new StreamReferenceRenderTypes.SampleFacts[](p.captures.length);
        for (uint256 i; i < p.captures.length; ++i) {
            uint256 index = i == 0 ? 0 : f.mintedEver - 1;
            f.samples[i] = _sample(
                d,
                source.targets[6],
                native.leafManifest.checkpointHash,
                p.collectionId,
                index,
                p.captures[i],
                f.artistId,
                current,
                exact
            );
        }
    }

    function _sample(
        StreamReferenceRenderTypes.Dependencies memory d,
        address checkpoint,
        bytes32 plan,
        uint256 cid,
        uint256 index,
        StreamReferenceRenderTypes.Capture memory c,
        bytes32 artistId,
        bool current,
        bool exact
    ) private view returns (StreamReferenceRenderTypes.SampleFacts memory f) {
        bytes memory raw = _read(
            checkpoint,
            abi.encodeCall(IStreamOnchainContentCheckpoint.checkpointLeaf, (plan, index)),
            192,
            d.readGas
        );
        StreamTokenContentLeaf memory leaf = abi.decode(raw, (StreamTokenContentLeaf));
        _canonical(checkpoint, raw, abi.encode(leaf));
        if (
            c.tokenId == 0 || leaf.tokenId != c.tokenId || c.collectionSerial == 0
                || c.metadataJSONHash != leaf.metadataHash || c.htmlHash != leaf.animationHash
                || c.animationHTML.length == 0 || c.animationHTML.length > 40960
                || c.animationHTML.length != c.htmlBytes || keccak256(c.animationHTML) != c.htmlHash
                || sha256(c.animationHTML) != c.sourceSha256 || c.capturedAt == 0
                || c.capturedAt > block.timestamp || c.repeatCaptureSha256[0] == 0
                || c.repeatCaptureSha256[1] == 0
                || (exact && c.repeatCaptureSha256[0] != c.repeatCaptureSha256[1])
        ) {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
        _identity(d, c.tokenId, cid, c.collectionSerial);
        f = _token(d, c, leaf);
        f.captureCoverage = coverage(d, c.coverageHash, artistId, c.objectHash, current);
        _object(d, f.captureCoverage, false);
        if (f.captureCoverage.sha256Digest != c.repeatCaptureSha256[0]) {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
    }

    function _token(
        StreamReferenceRenderTypes.Dependencies memory d,
        StreamReferenceRenderTypes.Capture memory c,
        StreamTokenContentLeaf memory leaf
    ) private view returns (StreamReferenceRenderTypes.SampleFacts memory f) {
        f.tokenId = c.tokenId;
        f.collectionSerial = c.collectionSerial;
        bytes32 coordinatorWord = _word(
            d.targets[0],
            abi.encodeCall(IStreamCoreIdentity.coordinatorAtMint, (c.tokenId)),
            d.readGas
        );
        if (uint256(coordinatorWord) > type(uint160).max) {
            revert StreamReferenceRenderTypes.ReferenceDependency(d.targets[0]);
        }
        f.originalCoordinator = address(uint160(uint256(coordinatorWord)));
        if (f.originalCoordinator.code.length == 0) {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
        bytes memory raw = _read(
            f.originalCoordinator,
            abi.encodeCall(IStreamEntropyView.tokenSeed, (c.tokenId)),
            64,
            d.sourceGas
        );
        bool finalized;
        (f.seed, finalized) = abi.decode(raw, (bytes32, bool));
        _canonical(f.originalCoordinator, raw, abi.encode(f.seed, finalized));
        if (
            !finalized
                || _word(
                        f.originalCoordinator,
                        abi.encodeCall(IStreamEntropyView.tokenEntropyStatus, (c.tokenId)),
                        d.sourceGas
                    ) != bytes32(uint256(5))
        ) {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
        raw = StreamFinalityRouterEvidence.dynamicRead(
            d.targets[0], abi.encodeCall(IStreamCoreMint.tokenData, (c.tokenId)), 16448, d.sourceGas
        );
        bytes memory tokenData = abi.decode(raw, (bytes));
        _canonical(d.targets[0], raw, abi.encode(tokenData));
        if (tokenData.length > 16384 || keccak256(tokenData) != leaf.tokenDataHash) {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
        f.tokenDataHash = leaf.tokenDataHash;
        f.tokenDataBytes = uint32(tokenData.length);
        raw = StreamFinalityRouterEvidence.dynamicRead(
            d.targets[4],
            abi.encodeCall(
                IStreamMetadataServingFacts.historicalTokenMetadataJSON, (d.targets[0], c.tokenId)
            ),
            65600,
            d.sourceGas
        );
        bytes memory json = abi.decode(raw, (bytes));
        _canonical(d.targets[4], raw, abi.encode(json));
        if (
            json.length > 65536 || keccak256(json) != leaf.metadataHash
                || !StreamOnchainContentBytes.matchesAnimation(json, c.animationHTML)
        ) {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
        f.metadataJSONHash = leaf.metadataHash;
        f.htmlHash = leaf.animationHash;
        f.htmlBytes = c.htmlBytes;
    }

    function _identity(
        StreamReferenceRenderTypes.Dependencies memory d,
        uint256 token,
        uint256 cid,
        uint256 serial
    ) private view {
        bytes memory raw = _read(
            d.targets[0],
            abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (token)),
            128,
            d.readGas
        );
        (bool exists, uint256 collection, uint256 number, bool burned) =
            abi.decode(raw, (bool, uint256, uint256, bool));
        _canonical(d.targets[0], raw, abi.encode(exists, collection, number, burned));
        bytes32 life = _word(
            d.targets[0], abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (token)), d.readGas
        );
        if (
            !exists || collection != cid || number != serial
                || life != bytes32(uint256(burned ? 3 : 2))
        ) {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
    }

    /// @notice Current mode returns original stable coverage after corroborating same-receipt liveness.
    function coverage(
        StreamReferenceRenderTypes.Dependencies memory d,
        bytes32 hash,
        bytes32 artist,
        bytes32 object,
        bool current
    ) public view returns (E.Coverage memory saved) {
        bytes memory raw = _read(
            d.targets[6],
            current
                ? abi.encodeCall(IStreamExternalArtifactCoverage.coverage, (hash))
                : abi.encodeCall(
                    IStreamExternalArtifactCoverage.requireCoverage, (hash, artist, object)
                ),
            480,
            d.archiveGas
        );
        saved = abi.decode(raw, (E.Coverage));
        _canonical(d.targets[6], raw, abi.encode(saved));
        if (
            hash == 0 || saved.coverageHash != hash || saved.artistId != artist
                || saved.objectHash != object
        ) {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
        if (current) {
            raw = _read(
                d.targets[6],
                abi.encodeCall(
                    IStreamExternalArtifactCurrentPair.currentReceiptPair,
                    (saved.firstReceiptHash, saved.secondReceiptHash, artist, object)
                ),
                448,
                d.archiveGas
            );
            E.CurrentPair memory pair = abi.decode(raw, (E.CurrentPair));
            _canonical(d.targets[6], raw, abi.encode(pair));
            if (
                pair.objectHash != saved.objectHash || pair.artistId != saved.artistId
                    || pair.contentHash != saved.contentHash
                    || pair.sha256Digest != saved.sha256Digest
                    || pair.arweaveDataRoot != saved.arweaveDataRoot
                    || pair.byteSize != saved.byteSize
                    || pair.firstFamilyRecordHash != saved.firstFamilyRecordHash
                    || pair.secondFamilyRecordHash != saved.secondFamilyRecordHash
                    || pair.firstReceiptHash != saved.firstReceiptHash
                    || pair.secondReceiptHash != saved.secondReceiptHash
                    || pair.checkpointHash != saved.checkpointHash
                    || pair.profileHash != saved.profileHash || pair.firstFixityHash == 0
                    || pair.secondFixityHash == 0
            ) {
                revert StreamReferenceRenderTypes.InvalidReferenceRender();
            }
        }
    }

    function requireCaptureObject(
        StreamReferenceRenderTypes.Dependencies memory d,
        E.Coverage memory e
    ) public view {
        _object(d, e, false);
    }

    function _object(
        StreamReferenceRenderTypes.Dependencies memory d,
        E.Coverage memory e,
        bool runtime
    ) private view {
        bytes memory raw = _read(
            d.targets[6],
            abi.encodeCall(IStreamExternalArtifactCoverage.objectIdentity, (e.objectHash)),
            320,
            d.archiveGas
        );
        E.ObjectIdentity memory o = abi.decode(raw, (E.ObjectIdentity));
        _canonical(d.targets[6], raw, abi.encode(o));
        if (
            o.artistId != e.artistId || o.contentHash != e.contentHash
                || o.sha256Digest != e.sha256Digest || o.arweaveDataRoot != e.arweaveDataRoot
                || o.byteSize != e.byteSize || o.canonicalizationId != keccak256("RAW_BYTES")
                || o.schemaId
                    != (runtime
                            ? StreamReferenceRenderDefinitions.ZIP_SCHEMA_ID
                            : StreamReferenceRenderDefinitions.PNG_SCHEMA_ID)
                || o.formatId
                    != (runtime ? keccak256("IANA:application/zip") : keccak256("IANA:image/png"))
                || o.formatCatalogId != StreamReferenceRenderDefinitions.FORMAT_CATALOG_ID
                || o.formatCatalogHash != StreamReferenceRenderDefinitions.FORMAT_CATALOG_HASH
        ) {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
    }

    function _word(address target, bytes memory data, uint256 cap) private view returns (bytes32) {
        return abi.decode(_read(target, data, 32, cap), (bytes32));
    }

    function _read(address target, bytes memory data, uint256 size, uint256 cap)
        private
        view
        returns (bytes memory)
    {
        return StreamFinalityRouterEvidence.read(target, data, size, cap);
    }

    function _canonical(address target, bytes memory raw, bytes memory encoded) private pure {
        if (keccak256(raw) != keccak256(encoded)) {
            revert StreamReferenceRenderTypes.ReferenceDependency(target);
        }
    }
}
