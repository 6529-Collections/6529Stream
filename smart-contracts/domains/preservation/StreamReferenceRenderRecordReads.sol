// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamReferenceRenderSourceReads.sol";
import "../records/StreamSnapshotManifestBytes.sol";
import "../records/StreamReferenceRenderDefinitionReads.sol";

/// @notice Linked retained-record decoding and current validation for the fixed reference host.
/// @dev Explicit original storage references preserve the host layout. A direct library caller
///      cannot manufacture a publication in the host. Current checks retain original coverage.
library StreamReferenceRenderRecordReads {
    function recordBytes(
        StreamSnapshotManifestBytes.Manifest storage original,
        StreamReferenceRenderTypes.Receipt storage receipt
    ) public view returns (bytes memory) {
        return abi.encode(_publication(original), receipt);
    }

    function requireCurrent(
        StreamSnapshotManifestBytes.Manifest storage original,
        StreamSnapshotManifestBytes.Manifest storage payload,
        StreamReferenceRenderTypes.Receipt storage receipt,
        StreamReferenceRenderTypes.Dependencies memory d
    ) public view {
        StreamReferenceRenderDefinitionReads.requireDefinitions(d);
        StreamReferenceRenderTypes.SourceFacts memory f =
            StreamReferenceRenderSourceReads.requireSourceInputs(
                d, StreamReferenceRenderSourceReads.project(_publication(original)), true
            );
        if (
            sourceHash(d, f) != receipt.sourcesHash
                || StreamSnapshotManifestBytes.requireIntact(payload) != receipt.payloadHash
        ) revert StreamReferenceRenderTypes.InvalidReferenceRender();
    }

    function sourceHash(
        StreamReferenceRenderTypes.Dependencies memory d,
        StreamReferenceRenderTypes.SourceFacts memory f
    ) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_REFERENCE_SOURCES_V1"),
                d.chainId,
                address(this),
                d.targets,
                d.codeHashes,
                d.rendererCatalogId,
                d.rendererCatalogHash,
                f
            )
        );
    }

    function _publication(StreamSnapshotManifestBytes.Manifest storage saved)
        private
        view
        returns (StreamReferenceRenderTypes.Publication memory p)
    {
        bytes memory raw = StreamSnapshotManifestBytes.read(saved);
        p = abi.decode(raw, (StreamReferenceRenderTypes.Publication));
        if (keccak256(raw) != keccak256(abi.encode(p))) {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
    }
}
