// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import { IStreamRenderer as R } from "../../interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamRendererRegistry as V
} from "../../interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamSchemaRegistry as S
} from "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamSchemaDocumentFacts as F
} from "../../interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import {
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import { StreamRendererCalls as Calls } from "./StreamRendererCalls.sol";

/// @notice Original admission-only renderer checks, executed in the Registry delegate-host.
/// @dev Governance and every immutable insertion remain in the host. Serving never enters this worker.
library StreamRendererAdmissionValidation {
    bytes32 private constant ANALYSIS_PROFILE =
        keccak256("6529STREAM_STATIC_RENDERER_ANALYSIS_ABI_V1");
    bytes32 private constant READ_SET = keccak256("6529STREAM_RENDERER_READ_SET_V1");
    bytes32 private constant READ_GAS = keccak256("6529STREAM_GGP_METADATA_DEPENDENCY_READ_GAS");
    bytes32 private constant GOLDEN_GAS = keccak256("6529STREAM_GGP_RENDERER_GOLDEN_VECTOR_GAS");
    uint256 private constant MAX_READS = 128;
    uint256 private constant MAX_VECTORS = 16;
    uint256 private constant MAX_OUTPUT_BYTES = 16777216;

    struct Context {
        address schemas;
        bytes32 schemasHash;
        bytes32 targetSetHash;
    }

    struct Input {
        address renderer;
        bytes32 goldenDocument;
        uint32 maxJSONBytes;
    }

    function validate(
        V.Registration calldata r,
        V.Read[] calldata declared,
        V.Target[] storage targets,
        Context memory c
    ) public view returns (bytes32 setHash, bytes32 analysis, bytes32 goldenHash) {
        _manifest(r, c);
        setHash = _readSet(declared, targets, c);
        analysis = _analysis(r, setHash, c);
        bytes memory payload = _document(c, r.goldenDocument);
        goldenHash = golden(Input(r.renderer, r.goldenDocument, r.manifest.maxJSONBytes), payload);
    }

    function _manifest(V.Registration calldata r, Context memory c) private view {
        R.RendererManifest calldata m = r.manifest;
        if (
            r.renderer.code.length == 0 || m.rendererId == 0 || m.rendererVersion == 0
                || m.contextVersion == 0 || m.rendererClass != keccak256("STATIC")
                || m.schemaHash == 0 || m.manifestHash == 0 || m.deprecated
                || bytes(m.schemaURI).length > 2048 || bytes(m.manifestURI).length > 2048
                || m.maxJSONBytes == 0 || m.maxJSONBytes > MAX_OUTPUT_BYTES
                || m.maxHTMLBytes > MAX_OUTPUT_BYTES || r.contextDocument != m.contextVersion
        ) revert V.InvalidRendererRegistration();
        uint256 cap = IStreamGasParameterHost(address(this)).gasParameter(READ_GAS);
        if (
            !abi.decode(
                    Calls.read(
                        r.renderer,
                        abi.encodeCall(IERC165.supportsInterface, (type(R).interfaceId)),
                        Calls.ReadOptions(32, true),
                        cap
                    ),
                    (bool)
                )
                || abi.decode(
                        Calls.read(
                            r.renderer,
                            abi.encodeCall(R.rendererVersion, ()),
                            Calls.ReadOptions(32, true),
                            cap
                        ),
                        (bytes32)
                    ) != m.rendererVersion
                || abi.decode(
                        Calls.read(
                            r.renderer,
                            abi.encodeCall(R.renderContextVersion, ()),
                            Calls.ReadOptions(32, true),
                            cap
                        ),
                        (bytes32)
                    ) != m.contextVersion
        ) {
            revert V.InvalidRendererRegistration();
        }
        bytes memory encoded = Calls.read(
            r.renderer, abi.encodeCall(R.rendererManifest, ()), Calls.ReadOptions(4576, false), cap
        );
        R.RendererManifest memory actual = abi.decode(encoded, (R.RendererManifest));
        if (
            keccak256(encoded) != keccak256(abi.encode(actual))
                || keccak256(abi.encode(actual)) != keccak256(abi.encode(m))
        ) {
            revert V.InvalidRendererRegistration();
        }
        if (
            _fact(c, r.schemaDocument, S.DocumentKind.SCHEMA).contentHash != m.schemaHash
                || _fact(c, r.manifestDocument, S.DocumentKind.CATALOG).contentHash
                    != m.manifestHash
        ) {
            revert V.InvalidRendererEvidence(r.manifestDocument);
        }
        _fact(c, r.contextDocument, S.DocumentKind.SCHEMA);
    }

    function _readSet(V.Read[] calldata declared, V.Target[] storage targets, Context memory c)
        private
        view
        returns (bytes32)
    {
        if (declared.length > MAX_READS) revert V.InvalidRendererRegistration();
        uint256 previous;
        for (uint256 i; i < declared.length; ++i) {
            V.Read calldata r = declared[i];
            uint256 order = (uint256(r.targetIndex) << 32) | uint32(r.selector);
            if (
                r.targetIndex >= targets.length || r.selector == 0 || (i != 0 && order <= previous)
                    || r.maxReturnBytes == 0 || r.maxReturnBytes > MAX_OUTPUT_BYTES
                    || (r.exact && r.maxReturnBytes % 32 != 0)
            ) revert V.InvalidRendererRegistration();
            V.Target storage t = targets[r.targetIndex];
            if (t.target.code.length == 0 || t.target.codehash != t.codeHash) {
                revert V.InvalidRendererRegistration();
            }
            previous = order;
        }
        return keccak256(abi.encode(READ_SET, c.targetSetHash, declared));
    }

    function _analysis(V.Registration calldata r, bytes32 setHash, Context memory c)
        private
        view
        returns (bytes32)
    {
        bytes memory payload = _document(c, r.analysisDocument);
        V.Analysis memory a = abi.decode(payload, (V.Analysis));
        if (
            keccak256(payload) != keccak256(abi.encode(a)) || a.profile != ANALYSIS_PROFILE
                || a.renderer != r.renderer || a.runtimeHash != r.renderer.codehash
                || a.readSetHash != setHash || a.rendererVersion != r.manifest.rendererVersion
                || a.contextVersion != r.manifest.contextVersion
                || a.schemaHash != r.manifest.schemaHash || a.toolHash == 0 || a.findingsHash == 0
                || !a.passed
        ) {
            revert V.InvalidRendererEvidence(r.analysisDocument);
        }
        return keccak256(payload);
    }

    function _document(Context memory c, bytes32 id) private view returns (bytes memory payload) {
        F.DocumentFacts memory f = _fact(c, id, S.DocumentKind.CATALOG);
        if (f.totalBytes == 0 || f.totalBytes > 8192) revert V.InvalidRendererEvidence(id);
        bytes memory encoded = Calls.read(
            c.schemas,
            abi.encodeCall(S.documentBytes, (id)),
            Calls.ReadOptions(64 + ((uint256(f.totalBytes) + 31) / 32) * 32, false),
            IStreamGasParameterHost(address(this)).gasParameter(READ_GAS)
        );
        payload = abi.decode(encoded, (bytes));
        if (
            payload.length != f.totalBytes || keccak256(payload) != f.contentHash
                || keccak256(encoded) != keccak256(abi.encode(payload))
        ) revert V.InvalidRendererEvidence(id);
    }

    function _fact(Context memory c, bytes32 id, S.DocumentKind kind)
        private
        view
        returns (F.DocumentFacts memory f)
    {
        if (c.schemas.codehash != c.schemasHash || id == 0) {
            revert V.InvalidRendererEvidence(id);
        }
        f = abi.decode(
            Calls.read(
                c.schemas,
                abi.encodeCall(F.documentFacts, (id)),
                Calls.ReadOptions(288, true),
                IStreamGasParameterHost(address(this)).gasParameter(READ_GAS)
            ),
            (F.DocumentFacts)
        );
        if (
            !f.exists || f.kind != kind || f.status != S.DocumentStatus.ACTIVE || f.contentHash == 0
        ) {
            revert V.InvalidRendererEvidence(id);
        }
    }

    function golden(Input memory r, bytes memory payload) public view returns (bytes32) {
        V.GoldenVector[] memory vectors = abi.decode(payload, (V.GoldenVector[]));
        if (
            keccak256(payload) != keccak256(abi.encode(vectors)) || vectors.length == 0
                || vectors.length > MAX_VECTORS
        ) {
            revert V.InvalidRendererEvidence(r.goldenDocument);
        }
        uint256 maximum = 29 + 4 * ((uint256(r.maxJSONBytes) + 2) / 3);
        for (uint256 i; i < vectors.length; ++i) {
            if (vectors[i].outputHash == 0) revert V.InvalidRendererEvidence(r.goldenDocument);
            bytes memory output = Calls.read(
                r.renderer,
                abi.encodeCall(R.tokenURI, (vectors[i].request)),
                Calls.ReadOptions(64 + ((maximum + 31) / 32) * 32, false),
                IStreamGasParameterHost(address(this)).gasParameter(GOLDEN_GAS)
            );
            string memory uri = Calls.stringResult(output, maximum);
            if (keccak256(bytes(uri)) != vectors[i].outputHash) {
                revert V.InvalidRendererEvidence(r.goldenDocument);
            }
        }
        return keccak256(payload);
    }
}
