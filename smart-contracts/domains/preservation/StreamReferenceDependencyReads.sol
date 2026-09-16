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

/// @notice Fixed original graph validation; extracted without changing checks or call order.
library StreamReferenceDependencyReads {
    function validateDependencies(StreamReferenceRenderTypes.Dependencies memory d) public view {
        if (
            d.chainId != block.chainid || d.readGas < 50000 || d.sourceGas < d.readGas
                || d.snapshotGas < d.sourceGas || d.archiveGas < d.readGas
                || d.rendererCatalogId == 0 || d.rendererCatalogHash == 0
                || d.rendererCatalogBytes == 0
        ) {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
        for (uint256 i; i < 7; ++i) {
            if (d.targets[i].code.length == 0 || d.targets[i].codehash != d.codeHashes[i]) {
                revert StreamReferenceRenderTypes.ReferenceDependency(d.targets[i]);
            }
        }
        _addressEquals(d, d.targets[1], "core()", d.targets[0]);
        _addressEquals(d, d.targets[1], "schemaRegistry()", d.targets[2]);
        _addressEquals(d, d.targets[1], "chunkStore()", d.targets[3]);
        _addressEquals(d, d.targets[2], "chunkStore()", d.targets[3]);
        _addressEquals(d, d.targets[4], "core()", d.targets[0]);
        _addressEquals(d, d.targets[5], "core()", d.targets[0]);
        _addressEquals(d, d.targets[5], "metadataHost()", d.targets[1]);
        _addressEquals(d, d.targets[5], "metadataRouter()", d.targets[4]);
        _addressEquals(d, d.targets[5], "schemaRegistry()", d.targets[2]);
        _addressEquals(d, d.targets[5], "chunkStore()", d.targets[3]);
        _addressEquals(d, d.targets[6], "core()", d.targets[0]);
        if (
            _word(
                    d.targets[6],
                    abi.encodeCall(
                        IStreamExternalArtifactCoverage.supportsInterface,
                        (type(IStreamExternalArtifactCurrentPair).interfaceId)
                    ),
                    d.readGas
                ) != bytes32(uint256(1))
        ) {
            revert StreamReferenceRenderTypes.ReferenceDependency(d.targets[6]);
        }
    }

    function _addressEquals(
        StreamReferenceRenderTypes.Dependencies memory d,
        address target,
        string memory getter,
        address expected
    ) private view {
        if (
            _word(target, abi.encodeWithSignature(getter), d.readGas)
                != bytes32(uint256(uint160(expected)))
        ) {
            revert StreamReferenceRenderTypes.ReferenceDependency(target);
        }
    }

    function bindings(StreamReferenceRenderTypes.Dependencies memory d)
        public
        view
        returns (StreamSnapshotTypes.Dependencies memory source)
    {
        if (
            d.chainId != block.chainid || d.readGas < 50000 || d.sourceGas < d.readGas
                || d.snapshotGas < d.sourceGas || d.archiveGas < d.readGas
                || d.rendererCatalogId == 0 || d.rendererCatalogHash == 0
                || d.rendererCatalogBytes == 0
        ) {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
        for (uint256 i; i < 7; ++i) {
            if (d.targets[i].code.length == 0 || d.targets[i].codehash != d.codeHashes[i]) {
                revert StreamReferenceRenderTypes.ReferenceDependency(d.targets[i]);
            }
        }
        bytes memory raw = _read(
            d.targets[5],
            abi.encodeCall(IStreamCollectionSnapshots.dependencies, ()),
            736,
            d.readGas
        );
        source = abi.decode(raw, (StreamSnapshotTypes.Dependencies));
        _canonical(d.targets[5], raw, abi.encode(source));
        for (uint256 i; i < 5; ++i) {
            if (source.targets[i] != d.targets[i] || source.codeHashes[i] != d.codeHashes[i]) {
                revert StreamReferenceRenderTypes.ReferenceDependency(d.targets[5]);
            }
        }
        if (
            source.chainId != d.chainId
                || _word(
                        d.targets[6],
                        abi.encodeCall(IStreamExternalArtifactCoverage.core, ()),
                        d.readGas
                    ) != bytes32(uint256(uint160(d.targets[0])))
                || _word(
                        d.targets[6],
                        abi.encodeCall(
                            IStreamExternalArtifactCoverage.supportsInterface,
                            (type(IStreamExternalArtifactCurrentPair).interfaceId)
                        ),
                        d.readGas
                    ) != bytes32(uint256(1))
        ) {
            revert StreamReferenceRenderTypes.ReferenceDependency(d.targets[6]);
        }
        StreamSnapshotSourceReads.bindings(source);
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
