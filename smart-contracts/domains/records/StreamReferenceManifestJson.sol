// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import "./StreamReferenceEnvironmentJson.sol";
import "./StreamReferenceRendererCatalog.sol";
import "./StreamReferenceRenderDefinitions.sol";
import "../../vendor/openzeppelin/Base64.sol";

/// @notice Canonical complete native reference publication and original attribution.
/// @dev Today's passing fixity never enters these original bytes. Dates of actual publication
///      remain in the outer original receipt so preview/canonical upload has no self-hash cycle.
library StreamReferenceManifestJson {
    /// @dev Exact fields rendered outside the separately authenticated complete environment.
    struct ManifestInput {
        uint256 collectionId;
        bytes32 referenceId;
        bytes32 expectedHead;
        bytes32 environmentHash;
        uint32 environmentBytes;
        string manifestURI;
        uint64 effectiveAt;
        bytes32 reasonHash;
        StreamReferenceRenderTypes.Capture[] captures;
    }

    function manifest(
        StreamReferenceRenderTypes.Dependencies memory d,
        StreamReferenceRenderTypes.Publication memory p,
        StreamReferenceRenderTypes.Receipt memory r,
        StreamReferenceRenderTypes.SourceFacts memory f
    ) public pure returns (bytes memory raw) {
        bytes memory environment = StreamReferenceEnvironmentJson.manifest(p.environment);
        return assemble(d, p, r, f, environment);
    }

    /// @dev The fixed host supplies exact prepared, authenticated environment bytes.
    function assemble(
        StreamReferenceRenderTypes.Dependencies memory d,
        StreamReferenceRenderTypes.Publication memory p,
        StreamReferenceRenderTypes.Receipt memory r,
        StreamReferenceRenderTypes.SourceFacts memory f,
        bytes memory environment
    ) public pure returns (bytes memory) {
        return assembleInputs(d, project(p), r, f, environment);
    }

    function project(StreamReferenceRenderTypes.Publication memory p)
        internal
        pure
        returns (ManifestInput memory)
    {
        return ManifestInput(
            p.collectionId,
            p.referenceId,
            p.expectedHead,
            p.environment.manifestHash,
            p.environment.manifestBytes,
            p.manifestURI,
            p.effectiveAt,
            p.reasonHash,
            p.captures
        );
    }

    function assembleInputs(
        StreamReferenceRenderTypes.Dependencies memory d,
        ManifestInput memory p,
        StreamReferenceRenderTypes.Receipt memory r,
        StreamReferenceRenderTypes.SourceFacts memory f,
        bytes memory environment
    ) public pure returns (bytes memory raw) {
        if (keccak256(environment) != p.environmentHash || environment.length != p.environmentBytes)
        {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
        string memory captures = "[";
        for (uint256 i; i < p.captures.length; ++i) {
            if (p.captures[i].environmentManifestHash != p.environmentHash) {
                revert StreamReferenceRenderTypes.InvalidReferenceRender();
            }
            captures =
                string.concat(captures, i == 0 ? "" : ",", _capture(p.captures[i], f.samples[i]));
        }
        captures = string.concat(captures, "]");
        string memory out = string.concat(
            '{"acceptanceMode":"BYTE_EXACT","artworkClassification":"STATIC",',
            '"captureClass":"still","captures":',
            captures,
            ',"chainId":',
            u(d.chainId),
            ',"collectionId":',
            u(p.collectionId),
            ',"environment":',
            string(environment),
            ',"environmentCoverage":',
            coverageJSON(f.environmentCoverage)
        );
        out = string.concat(
            string.concat(
                out,
                ',"environmentManifestBytes":',
                u(environment.length),
                ',"environmentManifestHash":',
                h(p.environmentHash),
                ',"mintedEver":',
                u(f.mintedEver),
                ',"profileHash":'
            ),
            h(StreamReferenceRenderDefinitions.PROFILE_HASH),
            ',"publication":',
            _publication(p, r),
            ',"renderer":',
            string(StreamReferenceRendererCatalog.declarationJSON(f.renderer))
        );
        out = string.concat(
            string.concat(
                out,
                ',"rendererCatalogHash":',
                h(d.rendererCatalogHash),
                ',"rendererCatalogId":',
                h(d.rendererCatalogId),
                ',"schemaHash":',
                h(StreamReferenceRenderDefinitions.SCHEMA_HASH),
                ',"schemaId":'
            ),
            h(StreamReferenceRenderDefinitions.SCHEMA_ID),
            ',"snapshot":',
            _snapshot(f.snapshot),
            ',"sources":',
            _sources(d),
            ',"subject":',
            h(f.subject),
            ',"version":1}'
        );
        raw = bytes(out);
        if (raw.length > 524288) revert StreamReferenceRenderTypes.InvalidReferenceRender();
    }

    function _capture(
        StreamReferenceRenderTypes.Capture memory c,
        StreamReferenceRenderTypes.SampleFacts memory f
    ) private pure returns (string memory out) {
        out = string.concat(
            string.concat(
                '{"animationHTMLBase64":"',
                Base64.encode(c.animationHTML),
                '","capturedAt":',
                u(c.capturedAt),
                ',"collectionSerial":',
                u(c.collectionSerial),
                ',"coverage":',
                coverageJSON(f.captureCoverage)
            ),
            ',"environmentManifestHash":',
            h(c.environmentManifestHash),
            ',"htmlBytes":',
            u(c.htmlBytes),
            ',"htmlHash":',
            h(c.htmlHash)
        );
        out = string.concat(
            string.concat(
                string.concat(
                    out,
                    ',"metadataJSONHash":',
                    h(c.metadataJSONHash),
                    ',"originalCoordinator":',
                    a(f.originalCoordinator),
                    ',"repeatCaptureSha256":[',
                    h(c.repeatCaptureSha256[0]),
                    ","
                ),
                h(c.repeatCaptureSha256[1]),
                '],"seed":',
                h(f.seed),
                ',"sourceSha256":',
                h(c.sourceSha256),
                ',"tokenDataBytes":',
                u(f.tokenDataBytes),
                ',"tokenDataHash":'
            ),
            h(f.tokenDataHash),
            ',"tokenId":',
            u(c.tokenId),
            "}"
        );
    }

    function _publication(ManifestInput memory p, StreamReferenceRenderTypes.Receipt memory r)
        private
        pure
        returns (string memory out)
    {
        out = string.concat(
            string.concat(
                string.concat(
                    '{"authorizationClass":',
                    u(r.authorizationClass),
                    ',"effectiveAt":',
                    u(p.effectiveAt),
                    ',"grantRevision":',
                    u(r.grantRevision),
                    ',"manifestURI":',
                    StreamRecordJson.quote(p.manifestURI, 2048, true)
                ),
                ',"predecessor":',
                h(p.expectedHead),
                ',"reasonHash":',
                h(p.reasonHash),
                ',"recorder":',
                a(r.recorder),
                ',"referenceId":',
                h(p.referenceId)
            ),
            ',"revision":',
            u(r.revision),
            "}"
        );
    }

    function _snapshot(StreamReferenceRenderTypes.SnapshotBinding memory s)
        private
        pure
        returns (string memory)
    {
        return string.concat(
            string.concat(
                string.concat(
                    '{"canonicalizationHash":',
                    h(s.canonicalizationHash),
                    ',"inventoryPlan":',
                    h(s.inventoryPlan),
                    ',"manifestHash":',
                    h(s.manifestHash),
                    ',"profileHash":',
                    h(s.profileHash)
                ),
                ',"recordHash":',
                h(s.recordHash),
                ',"revision":',
                u(s.revision),
                ',"schemaHash":',
                h(s.schemaHash),
                ',"sourceHash":',
                h(s.sourceHash)
            ),
            "}"
        );
    }

    function _sources(StreamReferenceRenderTypes.Dependencies memory d)
        private
        pure
        returns (string memory out)
    {
        out = "[";
        for (uint256 i; i < 7; ++i) {
            out = string.concat(
                out,
                i == 0 ? "" : ",",
                '{"address":',
                a(d.targets[i]),
                ',"role":',
                u(i),
                ',"runtimeHash":',
                h(d.codeHashes[i]),
                "}"
            );
        }
        return string.concat(out, "]");
    }

    function coverageJSON(E.Coverage memory e) public pure returns (string memory out) {
        out = string.concat(
            '{"artistId":',
            h(e.artistId),
            ',"arweaveDataRoot":',
            h(e.arweaveDataRoot),
            ',"byteSize":',
            u(e.byteSize),
            ',"checkpointHash":',
            h(e.checkpointHash),
            ',"contentHash":',
            h(e.contentHash),
            ',"coverageHash":',
            h(e.coverageHash)
        );
        out = string.concat(
            out,
            ',"firstFamilyRecordHash":',
            h(e.firstFamilyRecordHash),
            ',"firstFixityHash":',
            h(e.firstFixityHash),
            ',"firstReceiptHash":',
            h(e.firstReceiptHash),
            ',"objectHash":',
            h(e.objectHash),
            ',"profileHash":',
            h(e.profileHash)
        );
        return string.concat(
            out,
            ',"secondFamilyRecordHash":',
            h(e.secondFamilyRecordHash),
            ',"secondFixityHash":',
            h(e.secondFixityHash),
            ',"secondReceiptHash":',
            h(e.secondReceiptHash),
            ',"sha256Digest":',
            h(e.sha256Digest),
            "}"
        );
    }

    function h(bytes32 v) private pure returns (string memory) {
        return _quotedHex(v, 32);
    }

    function a(address v) private pure returns (string memory) {
        if (v == address(0)) revert StreamRecordJson.InvalidJsonWitness();
        return _quotedHex(bytes32(uint256(uint160(v)) << 96), 20);
    }

    function u(uint256 v) private pure returns (string memory) {
        uint256 digits = 1;
        for (uint256 remaining = v; remaining >= 10; remaining /= 10) {
            ++digits;
        }
        bytes memory output = new bytes(digits + 2);
        output[0] = '"';
        output[digits + 1] = '"';
        do {
            output[digits--] = bytes1(uint8(48 + v % 10));
            v /= 10;
        } while (v != 0);
        return string(output);
    }

    // Literal pinned Snapshot helper: fixed widths, lowercase, leading zeros and quoting.
    function _quotedHex(bytes32 value, uint256 size) private pure returns (string memory result) {
        result = new string(size * 2 + 4);
        assembly ("memory-safe") {
            let start := add(result, 32)
            mstore8(start, 0x22)
            mstore8(add(start, 1), 0x30)
            mstore8(add(start, 2), 0x78)
            let alphabet := 0x3031323334353637383961626364656600000000000000000000000000000000
            let cursor := add(start, 3)
            let end := add(cursor, mul(size, 2))
            for { } lt(cursor, end) { cursor := add(cursor, 1) } {
                mstore8(cursor, byte(shr(252, value), alphabet))
                value := shl(4, value)
            }
            mstore8(end, 0x22)
        }
    }
}
