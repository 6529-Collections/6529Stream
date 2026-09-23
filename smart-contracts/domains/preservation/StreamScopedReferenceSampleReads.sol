// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamScopedReferenceTypes as T
} from "../../interfaces/stream/preservation/StreamScopedReferenceTypes.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamScopedSnapshotTypes as S
} from "../../interfaces/stream/metadata/StreamScopedSnapshotTypes.sol";
import {
    IStreamFinalityScopeMembership as Membership
} from "../../interfaces/stream/finality/IStreamFinalityScopeMembership.sol";
import {
    IStreamStaticSelectionCheckpoint as Selection
} from "../../interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    IStreamStaticContentCheckpoint as Content
} from "../../interfaces/stream/finality/IStreamStaticContentCheckpoint.sol";
import {
    IStreamRendererRegistry as Registry
} from "../../interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamMetadataFullViews as Router
} from "../../interfaces/stream/metadata/IStreamMetadataFullViews.sol";
import { IStreamCoreIdentity as Core } from "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import { IStreamCoreMint } from "../../interfaces/stream/core/IStreamCoreMint.sol";
import {
    IStreamEntropyView as Entropy
} from "../../interfaces/stream/entropy/IStreamEntropyView.sol";
import {
    StreamFinalityScope
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamFinalityRouterEvidence as Reads
} from "../finality/StreamFinalityRouterEvidence.sol";
import {
    StreamReferenceRenderSourceReads as Archives
} from "./StreamReferenceRenderSourceReads.sol";
import { StreamStaticContentBytes } from "../finality/StreamStaticContentBytes.sol";

/// @notice First/last membership ordinals joined to actual permanent Core identity and STATIC rows.
/// @dev A collection serial is read from Core. It is never inferred from token id or membership index.
library StreamScopedReferenceSampleReads {
    function requireSample(
        T.Dependencies memory d,
        S.Dependencies memory source,
        StreamFinalityScope memory scope,
        S.Source memory facts,
        uint64 index,
        R.Capture memory c,
        bool current
    ) public view returns (T.Sample memory result) {
        uint256 token = abi.decode(
            Reads.read(
                source.targets[5],
                abi.encodeCall(Membership.scopeTokenAt, (scope, index)),
                32,
                d.readGas
            ),
            (uint256)
        );
        if (token == 0 || token != c.tokenId || index >= facts.membership.tokenCount) {
            revert T.InvalidScopedReference();
        }
        bytes memory raw = Reads.read(
            source.targets[6],
            abi.encodeCall(Selection.selectionAt, (facts.content.selectionId, index)),
            896,
            d.readGas
        );
        result.selection = abi.decode(raw, (Selection.TokenSelection));
        _canonical(source.targets[6], raw, abi.encode(result.selection));
        Selection.TokenSelection memory row = result.selection;
        raw = Reads.read(
            source.targets[7],
            abi.encodeCall(Content.outputAt, (facts.outputs.checkpointHash, index)),
            288,
            d.readGas
        );
        Content.Output memory output = abi.decode(raw, (Content.Output));
        _canonical(source.targets[7], raw, abi.encode(output));
        if (
            row.tokenId != token || output.leaf.tokenId != token
                || output.selectionRowHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_STATIC_SELECTION_ROW_V1"),
                            d.chainId,
                            d.targets[0],
                            d.targets[4],
                            row
                        )
                    ) || c.metadataJSONHash != output.leaf.metadataHash
                || c.htmlHash != output.leaf.animationHash || output.htmlHash != c.htmlHash
                || c.animationHTML.length == 0 || c.animationHTML.length > 40960
                || c.animationHTML.length != c.htmlBytes || keccak256(c.animationHTML) != c.htmlHash
                || sha256(c.animationHTML) != c.sourceSha256 || c.capturedAt == 0
                || c.capturedAt > block.timestamp || c.repeatCaptureSha256[0] == 0
                || c.repeatCaptureSha256[0] != c.repeatCaptureSha256[1]
        ) {
            revert T.InvalidScopedReference();
        }
        _renderer(d, row);
        raw = Reads.read(
            d.targets[0], abi.encodeCall(Core.tokenCollectionIdentity, (token)), 128, d.readGas
        );
        (bool exists, uint256 cid, uint256 serial, bool burned) =
            abi.decode(raw, (bool, uint256, uint256, bool));
        _canonical(d.targets[0], raw, abi.encode(exists, cid, serial, burned));
        if (
            !exists || cid != scope.collectionId || serial == 0 || serial != c.collectionSerial
                || _word(d.targets[0], abi.encodeCall(Core.tokenLifecycle, (token)), d.readGas)
                    != bytes32(uint256(burned ? 3 : 2))
        ) revert T.InvalidScopedReference();
        result.membershipIndex = index;
        R.SampleFacts memory f;
        f.tokenId = token;
        f.collectionSerial = serial;
        f.originalCoordinator = abi.decode(
            Reads.read(
                d.targets[0], abi.encodeCall(Core.coordinatorAtMint, (token)), 32, d.readGas
            ),
            (address)
        );
        if (
            f.originalCoordinator != row.sources[3] || f.originalCoordinator.code.length == 0
                || f.originalCoordinator.codehash != row.sourceCodeHashes[3]
        ) revert T.InvalidScopedReference();
        raw = Reads.read(
            f.originalCoordinator, abi.encodeCall(Entropy.tokenSeed, (token)), 64, d.sourceGas
        );
        bool finalized;
        (f.seed, finalized) = abi.decode(raw, (bytes32, bool));
        _canonical(f.originalCoordinator, raw, abi.encode(f.seed, finalized));
        if (
            !finalized
                || _word(
                        f.originalCoordinator,
                        abi.encodeCall(Entropy.tokenEntropyStatus, (token)),
                        d.sourceGas
                    ) != bytes32(uint256(5))
        ) revert T.InvalidScopedReference();
        raw = Reads.dynamicRead(
            d.targets[0], abi.encodeCall(IStreamCoreMint.tokenData, (token)), 16448, d.sourceGas
        );
        bytes memory data = abi.decode(raw, (bytes));
        _canonical(d.targets[0], raw, abi.encode(data));
        if (data.length > 16384 || keccak256(data) != output.leaf.tokenDataHash) {
            revert T.InvalidScopedReference();
        }
        f.tokenDataHash = output.leaf.tokenDataHash;
        f.tokenDataBytes = uint32(data.length);
        raw = Reads.dynamicRead(
            d.targets[4], abi.encodeCall(Router.tokenJSON, (token)), 65600, d.sourceGas
        );
        bytes memory json = abi.decode(raw, (bytes));
        _canonical(d.targets[4], raw, abi.encode(json));
        if (
            json.length > 65536 || keccak256(json) != output.leaf.metadataHash
                || !StreamStaticContentBytes.matches(json, c.animationHTML, data)
        ) revert T.InvalidScopedReference();
        f.metadataJSONHash = output.leaf.metadataHash;
        f.htmlHash = output.leaf.animationHash;
        f.htmlBytes = c.htmlBytes;
        R.Dependencies memory archive;
        archive.targets = d.targets;
        archive.codeHashes = d.codeHashes;
        archive.chainId = d.chainId;
        archive.readGas = d.readGas;
        archive.archiveGas = d.archiveGas;
        f.captureCoverage = Archives.coverage(
            archive, c.coverageHash, facts.artist.artistId, c.objectHash, current
        );
        Archives.requireCaptureObject(archive, f.captureCoverage);
        if (f.captureCoverage.sha256Digest != c.repeatCaptureSha256[0]) {
            revert T.InvalidScopedReference();
        }
        result.observation = f;
    }

    function _renderer(T.Dependencies memory d, Selection.TokenSelection memory row) private view {
        if (
            row.selection.registry.code.length == 0
                || row.selection.registry.codehash != row.selection.registryCodeHash
                || row.selection.renderer.code.length == 0
                || row.selection.renderer.codehash != row.selection.rendererCodeHash
        ) {
            revert T.ScopedReferenceDependency(row.selection.registry);
        }
        bytes memory raw = Reads.read(
            row.selection.registry,
            abi.encodeCall(Registry.requireRetained, (row.selection.versionKey)),
            64,
            d.readGas
        );
        (address renderer, bytes32 hash) = abi.decode(raw, (address, bytes32));
        _canonical(row.selection.registry, raw, abi.encode(renderer, hash));
        if (renderer != row.selection.renderer || hash != row.selection.rendererCodeHash) {
            revert T.InvalidScopedReference();
        }
        raw = Reads.dynamicRead(
            row.selection.registry,
            abi.encodeCall(Registry.registration, (row.selection.versionKey)),
            12288,
            d.readGas
        );
        Registry.Registration memory registration = abi.decode(raw, (Registry.Registration));
        _canonical(row.selection.registry, raw, abi.encode(registration));
        if (
            registration.renderer != renderer
                || registration.manifest.rendererClass != keccak256("STATIC")
                || registration.manifest.rendererId != row.selection.rendererId
                || registration.manifest.rendererVersion != row.selection.rendererVersion
                || registration.manifest.contextVersion != row.selection.contextVersion
                || registration.manifest.schemaHash != row.selection.schemaHash
        ) revert T.InvalidScopedReference();
    }

    function _word(address target, bytes memory input, uint256 cap) private view returns (bytes32) {
        return abi.decode(Reads.read(target, input, 32, cap), (bytes32));
    }

    function _canonical(address target, bytes memory raw, bytes memory expected) private pure {
        if (keccak256(raw) != keccak256(expected)) revert T.ScopedReferenceDependency(target);
    }
}
