// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRendererAdmissionValidation as Golden
} from "../../../smart-contracts/domains/metadata/StreamRendererAdmissionValidation.sol";
import {
    StreamRendererCalls as Calls
} from "../../../smart-contracts/domains/metadata/StreamRendererCalls.sol";
import {
    IStreamRendererRegistry as V
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamRenderer as R
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamGasParameterHost as G
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";

contract GoldenProjectionHost {
    uint256 private constant MAX_VECTORS = 16;
    bytes32 private constant GOLDEN_GAS = keccak256("6529STREAM_GGP_RENDERER_GOLDEN_VECTOR_GAS");
    bool private known = true;

    function setKnown(bool value) external {
        known = value;
    }

    function gasParameter(bytes32 id) public view returns (uint256) {
        if (!known || id != GOLDEN_GAS) revert G.GasParameterUnknown(id);
        return 1000000;
    }

    function _gasParameterValue(bytes32 id) private view returns (uint256) {
        return gasParameter(id);
    }

    function current(V.Registration calldata r, bytes memory payload)
        external
        view
        returns (bytes32)
    {
        return Golden.golden(
            Golden.Input(r.renderer, r.goldenDocument, r.manifest.maxJSONBytes), payload
        );
    }

    // Frozen original Registry tail after the unchanged host _document read.
    function original(V.Registration calldata r, bytes memory payload)
        external
        view
        returns (bytes32)
    {
        V.GoldenVector[] memory vectors = abi.decode(payload, (V.GoldenVector[]));
        if (
            keccak256(payload) != keccak256(abi.encode(vectors)) || vectors.length == 0
                || vectors.length > MAX_VECTORS
        ) {
            revert V.InvalidRendererEvidence(r.goldenDocument);
        }
        uint256 maximum = 29 + 4 * ((uint256(r.manifest.maxJSONBytes) + 2) / 3);
        for (uint256 i; i < vectors.length; ++i) {
            if (vectors[i].outputHash == 0) revert V.InvalidRendererEvidence(r.goldenDocument);
            bytes memory output = Calls.read(
                r.renderer,
                abi.encodeCall(R.tokenURI, (vectors[i].request)),
                Calls.ReadOptions(64 + ((maximum + 31) / 32) * 32, false),
                _gasParameterValue(GOLDEN_GAS)
            );
            string memory uri = Calls.stringResult(output, maximum);
            if (keccak256(bytes(uri)) != vectors[i].outputHash) {
                revert V.InvalidRendererEvidence(r.goldenDocument);
            }
        }
        return keccak256(payload);
    }
}

contract GoldenCallerRenderer {
    address private immutable expectedCaller;
    bytes32 private expectedRequest;

    constructor(address host) {
        expectedCaller = host;
    }

    function setRequest(bytes32 request) external {
        expectedRequest = request;
    }

    function tokenURI(R.RenderRequest calldata request) external view returns (string memory) {
        require(msg.sender == expectedCaller, "actual Registry caller");
        require(keccak256(abi.encode(request)) == expectedRequest, "complete request");
        return "golden://original/full";
    }
}

contract StreamRendererGoldenValidationTest {
    GoldenProjectionHost private host;
    GoldenCallerRenderer private renderer;

    function setUp() public {
        host = new GoldenProjectionHost();
        renderer = new GoldenCallerRenderer(address(host));
    }

    function _recipe() private returns (V.Registration memory r, V.GoldenVector[] memory vectors) {
        r.renderer = address(renderer);
        r.goldenDocument = keccak256("actual original golden document");
        r.manifest.maxJSONBytes = 256;
        vectors = new V.GoldenVector[](2);
        R.RenderRequest memory request;
        request.core = address(0x6529);
        request.tokenId = 91;
        request.collectionId = 7;
        request.collectionSerial = 11;
        request.tokenHash = keccak256("original retained seed");
        request.mode = R.MetadataMode.ONCHAIN;
        renderer.setRequest(keccak256(abi.encode(request)));
        vectors[0] = V.GoldenVector(request, keccak256("golden://original/full"));
        vectors[1] = vectors[0];
    }

    function _same(
        V.Registration memory r,
        bytes memory payload,
        bool wantSuccess,
        bytes memory expected
    ) private view {
        (bool oldOK, bytes memory oldRaw) =
            address(host).staticcall(abi.encodeCall(host.original, (r, payload)));
        (bool newOK, bytes memory newRaw) =
            address(host).staticcall(abi.encodeCall(host.current, (r, payload)));
        require(oldOK == wantSuccess && newOK == wantSuccess, "both exact outcome");
        require(
            keccak256(oldRaw) == keccak256(newRaw) && keccak256(newRaw) == keccak256(expected),
            "literal output/error and old oracle"
        );
    }

    function testFullGoldenHashAndOriginalRegistryCaller() public {
        (V.Registration memory r, V.GoldenVector[] memory v) = _recipe();
        bytes memory payload = abi.encode(v);
        _same(r, payload, true, abi.encode(keccak256(payload)));
    }

    function testCanonicalEnvelopeCountAndZeroHashErrorsRetainOrder() public {
        (V.Registration memory r, V.GoldenVector[] memory v) = _recipe();
        bytes memory expected =
            abi.encodeWithSelector(V.InvalidRendererEvidence.selector, r.goldenDocument);
        _same(r, bytes.concat(abi.encode(v), new bytes(32)), false, expected);
        _same(r, abi.encode(new V.GoldenVector[](0)), false, expected);
        _same(r, abi.encode(new V.GoldenVector[](17)), false, expected);
        v[0].outputHash = 0;
        _same(r, abi.encode(v), false, expected);
    }

    function testWrongHashAndRendererFailureRestoreExactly() public {
        (V.Registration memory r, V.GoldenVector[] memory v) = _recipe();
        bytes32 correct = v[0].outputHash;
        v[0].outputHash = keccak256("wrong");
        _same(
            r,
            abi.encode(v),
            false,
            abi.encodeWithSelector(V.InvalidRendererEvidence.selector, r.goldenDocument)
        );
        v[0].outputHash = correct;
        renderer.setRequest(keccak256("wrong source request"));
        _same(
            r,
            abi.encode(v),
            false,
            abi.encodeWithSelector(
                Calls.RendererReadFailed.selector, address(renderer), R.tokenURI.selector
            )
        );
        renderer.setRequest(keccak256(abi.encode(v[0].request)));
        bytes memory raw = abi.encode(v);
        _same(r, raw, true, abi.encode(keccak256(raw)));
    }

    function testOriginalGasLookupFollowsVectorCheckAndRestores() public {
        (V.Registration memory r, V.GoldenVector[] memory v) = _recipe();
        host.setKnown(false);
        _same(
            r,
            abi.encode(v),
            false,
            abi.encodeWithSelector(
                G.GasParameterUnknown.selector,
                keccak256("6529STREAM_GGP_RENDERER_GOLDEN_VECTOR_GAS")
            )
        );
        bytes32 correct = v[0].outputHash;
        v[0].outputHash = 0;
        _same(
            r,
            abi.encode(v),
            false,
            abi.encodeWithSelector(V.InvalidRendererEvidence.selector, r.goldenDocument)
        );
        v[0].outputHash = correct;
        host.setKnown(true);
        bytes memory raw = abi.encode(v);
        _same(r, raw, true, abi.encode(keccak256(raw)));
    }
}
