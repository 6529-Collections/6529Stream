// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderContextV1 as C
} from "../../../smart-contracts/domains/metadata/StreamRenderContextV1.sol";
import {
    IStreamRenderer as R
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import { Strings } from "../../../smart-contracts/vendor/openzeppelin/Strings.sol";
import {
    CharacterizationTestBase
} from "../../regression/legacy/helpers/CharacterizationTestBase.sol";

contract StreamRenderContextV1Test is CharacterizationTestBase {
    function testExactPendingContextOrderAndOptionalOmission() public pure {
        (R.RenderRequest memory r, C.Facts memory f) = _input();
        string memory actual = C.json(r, f, bytes32(uint256(1)), bytes32(uint256(2)));
        string memory expected =
            '{"schema":"stream-render-context-v1","chainId":"1","contract":"0x0000000000000000000000000000000000000001","tokenId":"9007199254740993","collectionId":"3","collectionSerial":"5","collectionSupplyMode":"UNCAPPED_OPEN","collectionStatus":"PAUSED","entropyStatus":"REQUESTED","viewId":"MARKETPLACE","rendererId":"0x0000000000000000000000000000000000000000000000000000000000000001","rendererVersion":"0x0000000000000000000000000000000000000000000000000000000000000002","renderContextVersion":"STREAM_CONTEXT_V1","tokenData":"0x","dependencyScript":""}';
        require(
            keccak256(bytes(actual)) == keccak256(bytes(expected)),
            "independent exact context golden"
        );
    }

    function testOpaqueTokenDataAndExactFourLegacyNames() public pure {
        (R.RenderRequest memory r, C.Facts memory f) = _input();
        r.state = R.TokenRenderState.ACTIVE;
        r.tokenHash = bytes32(uint256(7));
        f.entropyStatus = 5;
        f.tokenData = hex"ff007b2222666f6f";
        string memory context = C.json(r, f, bytes32(uint256(1)), bytes32(uint256(2)));
        require(
            _has(context, '"tokenData":"0xff007b2222666f6f"'),
            "opaque bytes preserved without JSON parsing"
        );
        require(
            _has(
                context,
                '"hash":"0x0000000000000000000000000000000000000000000000000000000000000007","seed":"0x0000000000000000000000000000000000000000000000000000000000000007"'
            ),
            "same canonical hash and finalized seed"
        );
        string memory html = C.html(context, "function dep(){}", "draw();");
        require(
            keccak256(bytes(html))
                == keccak256(
                    abi.encodePacked(
                        "<html><head></head><body><script>window.__STREAM_TOKEN__=",
                        context,
                        ";const stream=window.__STREAM_TOKEN__;const hash=stream.hash;const tokenId=Number(stream.tokenId);const tokenData=stream.tokenData;",
                        "</script><script>function dep(){}</script><script>draw();</script></body></html>"
                    )
                ),
            "exact shell and only four compatibility declarations"
        );
    }

    function testDependencyJSONAndScriptEndTagEscapesHaveSeparateMeaning() public pure {
        string memory raw = unicode'const example="</ScRiPt>";\n// λ';
        require(
            keccak256(bytes(C.escape(raw)))
                == keccak256(bytes(unicode'const example=\\"\\u003c/ScRiPt>\\";\\u000a// λ')),
            "JSON escaping includes HTML-safe less-than"
        );
        require(
            keccak256(bytes(C.scriptText(raw)))
                == keccak256(bytes(unicode'const example="<\\/ScRiPt>";\n// λ')),
            "script closing prefix escaped without JSON-quoting program"
        );
        (R.RenderRequest memory r, C.Facts memory f) = _input();
        f.dependencyScript = raw;
        string memory context = C.json(r, f, bytes32(uint256(1)), bytes32(uint256(2)));
        require(!_has(context, "</ScRiPt>"), "context cannot terminate its script element");
    }

    function testOptionalReferenceOrderAndExplicitViewNameHash() public pure {
        (R.RenderRequest memory r, C.Facts memory f) = _input();
        r.viewId = keccak256("GALLERY");
        f.viewName = "GALLERY";
        r.viewManifestHash = bytes32(uint256(11));
        r.metadataSnapshotHash = bytes32(uint256(12));
        f.scriptHash = bytes32(uint256(13));
        f.dependencyHash = bytes32(uint256(14));
        f.mediaManifestHash = bytes32(uint256(15));
        f.entropyProvider = address(16);
        string memory context = C.json(r, f, bytes32(uint256(1)), bytes32(uint256(2)));
        require(
            _has(
                context,
                '"entropyProvider":"0x0000000000000000000000000000000000000010","viewId":"GALLERY","viewManifestHash":'
            ),
            "provider and view order"
        );
        require(
            _has(
                context,
                '"mediaManifestHash":"0x000000000000000000000000000000000000000000000000000000000000000f","tokenData":"0x"'
            ),
            "optional references precede always-present token data"
        );
    }

    function testInvalidEnumAndUnmatchedViewNameRejected() public {
        (R.RenderRequest memory r, C.Facts memory f) = _input();
        r.collectionSupplyMode = 3;
        vm.expectRevert(abi.encodeWithSelector(C.InvalidRenderContext.selector));
        this.encode(r, f);
        r.collectionSupplyMode = 0;
        r.collectionStatus = 3;
        vm.expectRevert(abi.encodeWithSelector(C.InvalidRenderContext.selector));
        this.encode(r, f);
        r.collectionStatus = 0;
        f.viewName = "unregistered-name";
        vm.expectRevert(abi.encodeWithSelector(C.InvalidRenderContext.selector));
        this.encode(r, f);
    }

    function testFuzzExactLargeIdentifiers(uint256 tokenId, uint256 serial) public pure {
        (R.RenderRequest memory r, C.Facts memory f) = _input();
        r.tokenId = tokenId;
        r.collectionSerial = serial;
        string memory context = C.json(r, f, bytes32(uint256(1)), bytes32(uint256(2)));
        require(
            _has(context, string.concat('"tokenId":"', Strings.toString(tokenId), '"')),
            "decimal string token ID"
        );
        require(
            _has(context, string.concat('"collectionSerial":"', Strings.toString(serial), '"')),
            "decimal string serial"
        );
    }

    function encode(R.RenderRequest memory r, C.Facts memory f)
        external
        pure
        returns (string memory)
    {
        return C.json(r, f, bytes32(uint256(1)), bytes32(uint256(2)));
    }

    function _input() private pure returns (R.RenderRequest memory r, C.Facts memory f) {
        r.core = address(1);
        r.tokenId = 9007199254740993;
        r.collectionId = 3;
        r.collectionSerial = 5;
        r.collectionSupplyMode = 2;
        r.collectionStatus = 1;
        r.state = R.TokenRenderState.PENDING_RANDOMNESS;
        r.mode = R.MetadataMode.ONCHAIN;
        f.chainId = 1;
        f.entropyStatus = 4;
        f.viewName = "MARKETPLACE";
    }

    function _has(string memory raw, string memory needle) private pure returns (bool) {
        bytes memory a = bytes(raw);
        bytes memory b = bytes(needle);
        for (uint256 i; i + b.length <= a.length; ++i) {
            bool same = true;
            for (uint256 j; j < b.length; ++j) {
                if (a[i + j] != b[j]) {
                    same = false;
                    break;
                }
            }
            if (same) return true;
        }
        return false;
    }
}
