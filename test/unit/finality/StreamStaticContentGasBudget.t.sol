// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamStaticContentCheckpoint
} from "../../../smart-contracts/domains/finality/StreamStaticContentCheckpoint.sol";
import {
    IStreamStaticContentCheckpoint as C
} from "../../../smart-contracts/interfaces/stream/finality/IStreamStaticContentCheckpoint.sol";
import {
    IStreamStaticSelectionCheckpoint as P
} from "../../../smart-contracts/interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import { StreamRendererV1 } from "../../../smart-contracts/domains/metadata/StreamRendererV1.sol";
import {
    IStreamStaticMetadataRouter as S
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    IStreamRenderer as R
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamGasParameterHost as G
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

contract StaticGasSource {
    function tokenData(uint256) external pure returns (bytes memory) {
        return hex"0102";
    }

    function coordinatorAtMint(uint256) external view returns (address) {
        return address(this);
    }

    function staticTokenRenderFacts(uint256) external view returns (uint8, bytes32, address) {
        return (5, keccak256("seed"), address(this));
    }
}

contract StaticGasAttribution {
    address public immutable core;
    address public immutable router;
    bool public fail;

    constructor(address c, address r) {
        core = c;
        router = r;
    }

    function setFail(bool value) external {
        fail = value;
    }

    function attribution(uint256, uint256) external view returns (bytes memory) {
        require(!fail);
        return '{"state":"disputed"}';
    }
}

/// @dev Typed route/selection boundary deliberately propagates caller gas to the actual Renderer.
/// This isolates producer admission and the actual Renderer's unchanged optional-attribution branch.
contract StaticGasRouter {
    address public immutable core;
    StreamRendererV1 public renderer;

    constructor(address c) {
        core = c;
    }

    function bind(StreamRendererV1 value) external {
        require(address(renderer) == address(0));
        renderer = value;
    }

    function staticRenderSourceForConfig(uint256, bytes32)
        external
        view
        returns (S.RawSource memory, R.MetadataConfig memory)
    {
        return (_source(), _config().config);
    }

    function resolvedMetadataConfig(uint256) external view returns (S.ConfigRecord memory) {
        return _config();
    }

    function rawSource() external view returns (S.RawSource memory) {
        return _source();
    }

    function _source() private view returns (S.RawSource memory s) {
        s.chainId = block.chainid;
        s.configured = true;
        s.name = "Gas admission";
        s.script = "document.body.textContent='fixed';";
    }

    function _config() private view returns (S.ConfigRecord memory c) {
        c.recordHash = keccak256("fixed selected row");
        c.collectionId = 1;
        c.revision = 1;
        c.defaultRevision = 1;
        c.level = 3;
        c.sourceSnapshotHash =
            keccak256(abi.encode(keccak256("6529STREAM_STATIC_SOURCE_SNAPSHOT_V1"), _source()));
        c.config = R.MetadataConfig(
            R.MetadataMode.ONCHAIN, address(renderer), "", "", R.OffchainURIIdMode.TOKEN_ID, true
        );
        c.selection.renderer = address(renderer);
        c.selection.rendererCodeHash = address(renderer).codehash;
        c.selection.rendererId = keccak256("6529STREAM_RENDERER_V1");
        c.selection.rendererVersion = keccak256("6529STREAM_STATIC_RENDERER_V1");
    }

    function tokenJSON(uint256 token) external view returns (string memory) {
        return renderer.renderView(_request(token), 2);
    }

    function tokenHTML(uint256 token) external view returns (string memory) {
        return renderer.renderView(_request(token), 3);
    }

    function _request(uint256 token) private view returns (R.RenderRequest memory) {
        return R.RenderRequest(
            core,
            token,
            1,
            1,
            keccak256("seed"),
            R.TokenRenderState.FROZEN,
            R.MetadataMode.ONCHAIN,
            0,
            0,
            0,
            0,
            _config().recordHash
        );
    }
}

contract StaticGasSelection {
    address public immutable core;
    address public immutable metadataRouter;

    constructor(address c, address r) {
        core = c;
        metadataRouter = r;
    }

    function requireCurrentCheckpoint(bytes32) external pure returns (P.Plan memory) {
        return P.Plan(
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 1, 0),
            keccak256("membership"),
            keccak256("source"),
            1,
            1,
            keccak256("one complete row")
        );
    }

    function selectionAt(bytes32, uint256 index)
        external
        view
        returns (P.TokenSelection memory row)
    {
        require(index == 0);
        S.ConfigRecord memory config = StaticGasRouter(metadataRouter).resolvedMetadataConfig(1);
        row.tokenId = 1;
        row.configRecordHash = config.recordHash;
        row.configHash = keccak256(abi.encode(config));
        row.sourceSnapshotHash = config.sourceSnapshotHash;
        row.rawSourceHash = keccak256(abi.encode(StaticGasRouter(metadataRouter).rawSource()));
        row.selection = config.selection;
        (row.sources, row.sourceCodeHashes) =
            abi.decode(_bindings(config.selection.renderer), (address[6], bytes32[6]));
    }

    function _bindings(address renderer) private view returns (bytes memory) {
        (bool ok, bytes memory out) =
            renderer.staticcall(abi.encodeWithSignature("sourceBindings()"));
        require(ok);
        return out;
    }
}

/// @notice Isolated behavioral gas regression with actual RendererV1 and content producer.
/// @dev Core/route/selection are explicit fixed input boundaries. This is not current-stack acceptance.
contract StreamStaticContentGasBudgetTest {
    uint8 internal constant PRODUCER_FAILURE_CLASS = 2;
    StaticGasSource private source;
    StaticGasRouter private router;
    StaticGasAttribution private attribution;
    StreamStaticContentCheckpoint private producer;
    event ParentBudgetResult(uint256 budget, bool accepted);

    function setUp() public {
        source = new StaticGasSource();
        router = new StaticGasRouter(address(source));
        attribution = new StaticGasAttribution(address(source), address(router));
        StreamRendererV1.Deployment memory d;
        d.sources = StreamRendererV1.Sources(
            address(source),
            address(router),
            address(source),
            address(source),
            address(0),
            address(attribution)
        );
        d.readGas = G.GasParameterConfig("METADATA_DEPENDENCY_READ_GAS", 2000000, 100000, 2);
        d.attributionGas = G.GasParameterConfig("STATIC_ATTRIBUTION_GAS", 8000000, 8000000, 1);
        d.manifest = R.RendererManifest(
            keccak256("6529STREAM_RENDERER_V1"),
            keccak256("6529STREAM_STATIC_RENDERER_V1"),
            keccak256("STREAM_CONTEXT_V1"),
            keccak256("STATIC"),
            keccak256("schema"),
            "ipfs://schema",
            "ipfs://manifest",
            keccak256("manifest"),
            16777216,
            16777216,
            false
        );
        router.bind(new StreamRendererV1(d));
        StaticGasSelection selection = new StaticGasSelection(address(source), address(router));
        producer = new StreamStaticContentCheckpoint(
            address(selection),
            address(0),
            G.GasParameterConfig(
                "STATIC_CONTENT_READ_GAS", 1000000, 100000, PRODUCER_FAILURE_CLASS
            ),
            G.GasParameterConfig(
                    "STATIC_CONTENT_RENDER_GAS", 30000000, 100000, PRODUCER_FAILURE_CLASS
                )
        );
    }

    function testRecoveredAttributionCannotRevalidateUnavailableAcrossParentGasSweep() public {
        attribution.setFail(true);
        bytes32 id = _capture();
        require(_contains(router.tokenJSON(1), '"attribution_unavailable"'));
        require(producer.requireCurrentCheckpoint(id).tokenCount == 1);
        attribution.setFail(false);
        require(_contains(router.tokenJSON(1), '"state":"disputed"'));
        bytes memory input = abi.encodeCall(producer.requireCurrentCheckpoint, (id));
        uint256[18] memory budgets = [
            uint256(200000),
            500000,
            900000,
            1100000,
            1500000,
            2000000,
            3000000,
            5000000,
            7500000,
            8250000,
            8500000,
            9000000,
            12000000,
            20000000,
            30000000,
            30600000,
            32000000,
            45000000
        ];
        for (uint256 i; i < budgets.length; ++i) {
            (bool ok,) = address(producer).staticcall{ gas: budgets[i] }(input);
            emit ParentBudgetResult(budgets[i], ok);
            require(!ok, "recovered source falsely accepted unavailable capture");
        }
    }

    function testLowParentAdmissionFailsExplicitlyAndFullBudgetOriginalOutputWorks() public {
        bytes32 id = _capture();
        bytes memory input = abi.encodeCall(producer.requireCurrentCheckpoint, (id));
        (bool ok, bytes memory reason) = address(producer).staticcall{ gas: 2000000 }(input);
        require(
            !ok && reason.length == 68
                && bytes4(reason) == bytes4(keccak256("StaticContentParentGas(uint256,uint256)")),
            "producer must reject before reduced render budget"
        );
        (ok, reason) = address(producer).staticcall{ gas: 45000000 }(input);
        require(ok && abi.decode(reason, (C.Plan)).tokenCount == 1, "unchanged full-budget output");
    }

    function _capture() private returns (bytes32 id) {
        id = producer.begin(keccak256("selection"), 0);
        C.Payload[] memory payload = new C.Payload[](1);
        payload[0] = C.Payload(1, "", bytes(router.tokenHTML(1)));
        producer.append(id, payload);
    }

    function _contains(string memory text, string memory target) private pure returns (bool) {
        bytes memory a = bytes(text);
        bytes memory b = bytes(target);
        for (uint256 i; i + b.length <= a.length; ++i) {
            bool equal = true;
            for (uint256 j; j < b.length; ++j) {
                if (a[i + j] != b[j]) {
                    equal = false;
                    break;
                }
            }
            if (equal) return true;
        }
        return false;
    }
}
