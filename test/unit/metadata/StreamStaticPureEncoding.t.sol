// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderContextV1 as Current
} from "../../../smart-contracts/domains/metadata/StreamRenderContextV1.sol";
import {
    StreamStaticRenderEncoding as Encoding
} from "../../../smart-contracts/domains/metadata/StreamStaticRenderEncoding.sol";
import { FrozenRenderContextV1 as Previous } from "./helpers/FrozenRenderContextV1.sol";
import {
    FrozenStaticRenderEncoding as PreviousEncoding
} from "./helpers/FrozenStaticRenderEncoding.sol";
import {
    IStreamRenderer as R
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";

/// @notice Differential output and isolated gas evidence against the immutable 2549ddd3 encoders.
/// @dev Gas covers pure formatting only. It is not a current-route or checkpoint transaction test.
contract StreamStaticPureEncodingTest {
    event log_named_uint(string key, uint256 value);

    function currentRender(bytes calldata input) external pure returns (string memory) {
        (
            R.RenderRequest memory r,
            Encoding.Prepared memory p,
            string memory script,
            address router,
            uint8 mode
        ) = abi.decode(input, (R.RenderRequest, Encoding.Prepared, string, address, uint8));
        return Encoding.render(r, p, script, router, mode);
    }

    function previousRender(bytes calldata input) external pure returns (string memory) {
        (
            R.RenderRequest memory r,
            PreviousEncoding.Prepared memory p,
            string memory script,
            address router,
            uint8 mode
        ) = abi.decode(input, (R.RenderRequest, PreviousEncoding.Prepared, string, address, uint8));
        return PreviousEncoding.render(r, p, script, router, mode);
    }

    function currentEscape(string calldata raw) external pure returns (string memory) {
        return Current.escape(raw);
    }

    function previousEscape(string calldata raw) external pure returns (string memory) {
        return Previous.escape(raw);
    }

    function currentScript(string calldata raw) external pure returns (string memory) {
        return Current.scriptText(raw);
    }

    function previousScript(string calldata raw) external pure returns (string memory) {
        return Previous.scriptText(raw);
    }

    function testEveryByteAndEveryWordBoundary() public pure {
        bytes memory all = new bytes(256);
        for (uint256 i; i < all.length; ++i) {
            all[i] = bytes1(uint8(i));
        }
        _parity(all);
        for (uint256 n; n < 65; ++n) {
            bytes memory prefix = _fill(n, 0x61);
            _parity(
                bytes.concat(
                    prefix,
                    all,
                    hex"e280a8e280a9e280e2e280aa80a8",
                    bytes("</ScRiPtX</script</SCRIPTx")
                )
            );
            _parity(bytes.concat(prefix, bytes("</script")));
            _parity(bytes.concat(prefix, hex"e280a8"));
            _parity(bytes.concat(prefix, hex"e280a9"));
        }
    }

    function testExactHistoricalEscapesAndIncompletePrefixes() public pure {
        require(
            keccak256(bytes(Current.escape(string(hex"00225c3ce280a8e280a9"))))
                == keccak256(bytes("\\u0000\\\"\\\\\\u003c\\u2028\\u2029")),
            "literal escape oracle"
        );
        require(
            keccak256(bytes(Current.scriptText("</scriptX</ScRiPt></script")))
                == keccak256(bytes("<\\/scriptX<\\/ScRiPt><\\/script")),
            "prefix needs no closing angle"
        );
        bytes memory prefix = bytes("</script");
        for (uint256 n; n < 8; ++n) {
            bytes memory truncated = new bytes(n);
            for (uint256 j; j < n; ++j) {
                truncated[j] = prefix[j];
            }
            require(keccak256(bytes(Current.scriptText(string(truncated)))) == keccak256(truncated));
        }
        _parity(hex"e280a7e280aae280e2e280f09f8ea8f09feda080ff");
    }

    function testAllCaseVariantsAdjacentMatchesAndLongRuns() public pure {
        bytes memory tag = bytes("</script");
        for (uint256 mask; mask < 64; ++mask) {
            for (uint256 j; j < 6; ++j) {
                uint8 lower = uint8(bytes("script")[j]);
                tag[j + 2] = bytes1((mask & (uint256(1) << j)) == 0 ? lower : lower - 32);
            }
            _parity(bytes.concat(tag, tag, bytes("!"), _fill(67, 0x61), tag));
        }
        bytes memory repeated = new bytes(24576);
        for (uint256 i; i < repeated.length; ++i) {
            repeated[i] = bytes("</script")[i % 8];
        }
        _parity(repeated);
    }

    function testInputAndNeighboringMemoryRemainUnchanged() public pure {
        for (uint256 n; n < 65; ++n) {
            bytes memory raw = bytes.concat(_fill(n, 0x61), bytes("</script\"<"), hex"e280a8");
            bytes memory neighbor = _fill(96, 0xff);
            bytes32 before_ = keccak256(raw);
            bytes32 neighborBefore = keccak256(neighbor);
            _parity(raw);
            require(
                keccak256(raw) == before_ && keccak256(neighbor) == neighborBefore,
                "input memory changed"
            );
        }
    }

    function testFullJSONHTMLAndCompactMatchFrozenBytes() public view {
        for (uint8 metadataMode; metadataMode < 3; ++metadataMode) {
            for (uint8 mode; mode < 4; ++mode) {
                bytes memory input = _input(mode, "const t='</ScRiPtX';", metadataMode, false, true);
                _renderParity(input);
                _renderParity(_input(mode, "small();", metadataMode, true, false));
            }
        }
    }

    function testSourceProvidedAnimationStillEscapesAndGeneratedBase64Matches() public view {
        // OFFCHAIN keeps the source-provided animation branch; ONCHAIN exercises generated Base64.
        _renderParity(
            _input(2, "const a='</script>';", uint8(R.MetadataMode.OFFCHAIN), false, true)
        );
        _renderParity(_input(2, "const a='</script>';", uint8(R.MetadataMode.ONCHAIN), false, true));
    }

    function testFuzzArbitraryEscapeAndScriptBytes(bytes memory raw) public pure {
        if (raw.length > 4096) return;
        _parity(raw);
    }

    function testFuzzSpecialSpansAcrossBoundaries(bytes memory raw, uint8 offset) public pure {
        if (raw.length > 2048) return;
        _parity(
            bytes.concat(
                _fill(uint256(offset) % 65, 0x78),
                raw,
                hex"e280a83c225c0001e280a9",
                bytes("</SCRIPT"),
                raw
            )
        );
    }

    function testFuzzFullRenderBytes(bytes memory raw, uint8 mode) public view {
        if (raw.length > 1024) return;
        _renderParity(_input(mode % 4, string(raw), uint8(R.MetadataMode.ONCHAIN), false, true));
    }

    function testGas24576ByteScriptHTMLAndJSON() public {
        bytes memory program = _fill(24576, 0x61);
        program[0] = 0x2f;
        program[1] = 0x2a;
        program[program.length - 2] = 0x2a;
        program[program.length - 1] = 0x2f;
        _measure(
            _input(3, string(program), uint8(R.MetadataMode.ONCHAIN), false, false),
            "HTML old",
            "HTML new"
        );
        _measure(
            _input(2, string(program), uint8(R.MetadataMode.ONCHAIN), false, false),
            "JSON old",
            "JSON new"
        );
    }

    function testGas24576ByteDependencyAndEscapes() public {
        bytes memory raw = _fill(24576, 0x61);
        uint256 before_ = gasleft();
        string memory old = this.previousEscape(string(raw));
        uint256 oldGas = before_ - gasleft();
        before_ = gasleft();
        string memory next = this.currentEscape(string(raw));
        uint256 newGas = before_ - gasleft();
        require(keccak256(bytes(old)) == keccak256(bytes(next)) && newGas < oldGas);
        emit log_named_uint("Escape ASCII old", oldGas);
        emit log_named_uint("Escape ASCII new", newGas);
        for (uint256 i; i < raw.length; ++i) {
            raw[i] = i % 97 == 0 ? bytes1(0x3c) : bytes1(0x61);
        }
        before_ = gasleft();
        old = this.previousEscape(string(raw));
        oldGas = before_ - gasleft();
        before_ = gasleft();
        next = this.currentEscape(string(raw));
        newGas = before_ - gasleft();
        require(keccak256(bytes(old)) == keccak256(bytes(next)) && newGas < oldGas);
        emit log_named_uint("Escape mixed old", oldGas);
        emit log_named_uint("Escape mixed new", newGas);
    }

    function _measure(bytes memory input, string memory oldLabel, string memory newLabel) private {
        uint256 before_ = gasleft();
        string memory old = this.previousRender(input);
        uint256 oldGas = before_ - gasleft();
        before_ = gasleft();
        string memory next = this.currentRender(input);
        uint256 newGas = before_ - gasleft();
        require(keccak256(bytes(old)) == keccak256(bytes(next)), "frozen full output mismatch");
        require(newGas < oldGas, "pure workload did not improve");
        emit log_named_uint(oldLabel, oldGas);
        emit log_named_uint(newLabel, newGas);
    }

    function _renderParity(bytes memory input) private view {
        require(
            keccak256(bytes(this.previousRender(input)))
                == keccak256(bytes(this.currentRender(input))),
            "frozen render mismatch"
        );
    }

    function _parity(bytes memory raw) private pure {
        require(
            keccak256(bytes(Current.escape(string(raw))))
                == keccak256(bytes(Previous.escape(string(raw)))),
            "escape parity"
        );
        require(
            keccak256(bytes(Current.scriptText(string(raw))))
                == keccak256(bytes(Previous.scriptText(string(raw)))),
            "script parity"
        );
    }

    function _fill(uint256 n, bytes1 value) private pure returns (bytes memory result) {
        result = new bytes(n);
        for (uint256 i; i < n; ++i) {
            result[i] = value;
        }
    }

    function _input(
        uint8 mode,
        string memory script,
        uint8 metadataMode,
        bool pending,
        bool special
    ) private pure returns (bytes memory) {
        R.RenderRequest memory r;
        r.core = address(1);
        r.collectionId = 3;
        r.tokenId = 91;
        r.collectionSerial = 5;
        r.tokenHash = bytes32(uint256(9));
        r.state = pending ? R.TokenRenderState.PENDING_RANDOMNESS : R.TokenRenderState.ACTIVE;
        r.metadataSnapshotHash = bytes32(uint256(7));
        Encoding.Prepared memory p;
        p.source.chainId = 1;
        p.source.name = special ? "name\"<" : "";
        p.source.description = special ? string(hex"e280a80a005c") : "";
        p.source.imageURI = "ipfs://image";
        p.source.animationBaseURI =
            special ? string(hex"68747470733a2f2f782f223c5ce280a8") : "https://animation/";
        p.config.mode = R.MetadataMode(metadataMode);
        p.config.baseURI = "https://base/\"<";
        p.facts.chainId = 1;
        p.facts.viewName = "MARKETPLACE";
        p.facts.entropyStatus = pending ? 4 : 5;
        p.facts.tokenData = special ? bytes(hex"ff00225c") : bytes(hex"0102");
        p.facts.dependencyScript =
            special ? string(hex"636f6e737420643d223c2f53635269507458223be280a8") : "";
        p.bundle = bytes32(uint256(1));
        p.artist = bytes('{"state":"unbound"}');
        return abi.encode(r, p, script, address(2), mode);
    }
}
