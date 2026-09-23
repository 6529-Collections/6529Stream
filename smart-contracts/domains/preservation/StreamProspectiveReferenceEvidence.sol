// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamProspectiveReferenceTypes as P
} from "../../interfaces/stream/preservation/StreamProspectiveReferenceTypes.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamExternalArtifactTypes as E
} from "../../interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import {
    IStreamExternalArtifactCoverage
} from "../../interfaces/stream/preservation/IStreamExternalArtifactCoverage.sol";
import {
    IStreamExternalArtifactCurrentPair
} from "../../interfaces/stream/preservation/IStreamExternalArtifactCurrentPair.sol";
import {
    StreamProspectiveReferenceSourceReads as Sources
} from "./StreamProspectiveReferenceSourceReads.sol";
import {
    StreamProspectiveReferenceEncoding as Encoding
} from "./StreamProspectiveReferenceEncoding.sol";
import {
    StreamReferenceRenderSourceReads as Original
} from "./StreamReferenceRenderSourceReads.sol";
import {
    StreamReferenceRenderDefinitions as D
} from "../records/StreamReferenceRenderDefinitions.sol";

/// @notice Exact archived source/runtime and repeat PNG joins for named simulations.
/// @dev An authenticated curator asserts execution. EVM checks bindings/fixity, not JavaScript execution.
library StreamProspectiveReferenceEvidence {
    function requireEvidence(
        P.Dependencies memory d,
        P.Publication memory p,
        P.Source memory s,
        bytes memory environment
    ) public view returns (P.Evidence memory e) {
        if (
            p.captures.length == 0 || p.captures.length > 2
                || environment.length != p.environment.manifestBytes
                || keccak256(environment) != p.environment.manifestHash
                || p.environment.manifestHash == 0
        ) revert P.InvalidProspectiveReference();
        e.sourceHash = Sources.sourceHash(d, p.collectionId, s);
        R.Dependencies memory r = Sources.referenceDependencies(d, s);
        if (
            uint256(
                    Sources.word(
                        d.targets[4],
                        abi.encodeWithSelector(
                            bytes4(0x01ffc9a7), type(IStreamExternalArtifactCurrentPair).interfaceId
                        ),
                        d.readGas
                    )
                ) != 1
        ) revert P.ProspectiveDependency(d.targets[4]);
        e.environmentCoverage = Original.coverage(
            r, p.environment.coverageHash, s.artistId, p.environment.objectHash, true
        );
        _object(r, e.environmentCoverage, true);
        _file(
            p.environment.packageFiles,
            "prospective/script.js",
            uint64(s.script.length),
            sha256(s.script)
        );
        bytes memory media = abi.encode(s.mediaManifest);
        _file(
            p.environment.packageFiles, "prospective/media.abi", uint64(media.length), sha256(media)
        );
        e.captureCoverage = new E.Coverage[](p.captures.length);
        for (uint256 i; i < p.captures.length; ++i) {
            P.Capture memory c = p.captures[i];
            bytes32 vector = Encoding.vectorHash(c.vector);
            if (
                i != 0
                    && keccak256(bytes(c.vector.name))
                        == keccak256(bytes(p.captures[0].vector.name))
            ) revert P.InvalidProspectiveReference();
            bytes memory html = Encoding.html(
                d.chainId, d.targets[0], p.collectionId, e.sourceHash, c.vector, s.script
            );
            if (
                c.animationHTML.length != html.length
                    || keccak256(c.animationHTML) != keccak256(html) || c.capturedAt == 0
                    || c.capturedAt > block.timestamp || c.capturedAt > p.effectiveAt
                    || c.repeatCaptureSha256[0] == 0
                    || c.repeatCaptureSha256[0] != c.repeatCaptureSha256[1]
            ) revert P.InvalidProspectiveReference();
            _file(
                p.environment.packageFiles,
                string.concat("prospective/", c.vector.name, ".html"),
                uint64(html.length),
                sha256(html)
            );
            P.Execution memory x = abi.decode(c.execution, (P.Execution));
            Sources.canonical(c.execution, abi.encode(x));
            if (
                x.profile != Encoding.PROFILE || x.sourceHash != e.sourceHash
                    || x.vectorHash != vector
                    || x.environmentManifestHash != p.environment.manifestHash
                    || x.htmlSha256 != sha256(html) || x.pngSha256[0] != c.repeatCaptureSha256[0]
                    || x.pngSha256[1] != c.repeatCaptureSha256[1] || x.observedAt != c.capturedAt
                    || x.exitCode != 0
            ) revert P.InvalidProspectiveReference();
            e.captureCoverage[i] =
                Original.coverage(r, c.coverageHash, s.artistId, c.objectHash, true);
            _object(r, e.captureCoverage[i], false);
            if (e.captureCoverage[i].sha256Digest != c.repeatCaptureSha256[0]) {
                revert P.InvalidProspectiveReference();
            }
        }
    }

    function _file(R.PackageFile[] memory rows, string memory path, uint64 size, bytes32 hash)
        private
        pure
    {
        for (uint256 i; i < rows.length; ++i) {
            if (keccak256(bytes(rows[i].path)) == keccak256(bytes(path))) {
                if (rows[i].byteSize != size || rows[i].sha256Digest != hash) {
                    revert P.InvalidProspectiveReference();
                }
                return;
            }
        }
        revert P.InvalidProspectiveReference();
    }

    function _object(R.Dependencies memory d, E.Coverage memory e, bool runtime) private view {
        bytes memory raw = Sources.read(
            d.targets[6],
            abi.encodeCall(IStreamExternalArtifactCoverage.objectIdentity, (e.objectHash)),
            320,
            d.archiveGas
        );
        E.ObjectIdentity memory o = abi.decode(raw, (E.ObjectIdentity));
        Sources.canonical(raw, abi.encode(o));
        if (
            o.artistId != e.artistId || o.contentHash != e.contentHash
                || o.sha256Digest != e.sha256Digest || o.arweaveDataRoot != e.arweaveDataRoot
                || o.byteSize != e.byteSize || o.contentHash == 0 || o.sha256Digest == 0
                || o.arweaveDataRoot == 0 || o.byteSize == 0
                || o.canonicalizationId != keccak256("RAW_BYTES")
                || o.schemaId != (runtime ? D.ZIP_SCHEMA_ID : D.PNG_SCHEMA_ID)
                || o.formatId
                    != (runtime ? keccak256("IANA:application/zip") : keccak256("IANA:image/png"))
                || o.formatCatalogId != D.FORMAT_CATALOG_ID
                || o.formatCatalogHash != D.FORMAT_CATALOG_HASH
        ) revert P.InvalidProspectiveReference();
    }
}
