// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    CharacterizationTestBase
} from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import {
    StreamMetadataCitation as Citation
} from "../../../smart-contracts/domains/metadata/StreamMetadataCitation.sol";
import {
    StreamMetadataTokenRenderer as TokenRenderer
} from "../../../smart-contracts/domains/metadata/StreamMetadataTokenRenderer.sol";
import {
    StreamMetadataRenderer as Fallback
} from "../../../smart-contracts/domains/metadata/StreamMetadataRenderer.sol";
import {
    StreamStaticRenderEncoding as Encoding
} from "../../../smart-contracts/domains/metadata/StreamStaticRenderEncoding.sol";
import {
    StreamMetadataRenderTypes as T
} from "../../../smart-contracts/interfaces/stream/metadata/StreamMetadataRenderTypes.sol";
import {
    IStreamMetadataServingFacts as F
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    IStreamRenderer as R
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import { Base64 } from "../../../smart-contracts/vendor/openzeppelin/Base64.sol";
import { Strings } from "../../../smart-contracts/vendor/openzeppelin/Strings.sol";
import {
    StreamMetadataBundleRenderer as Bundle
} from "../../../smart-contracts/domains/metadata/StreamMetadataBundleRenderer.sol";
import {
    StreamMetadataDisplayParameters as DisplayGas
} from "../../../smart-contracts/domains/metadata/StreamMetadataDisplayParameters.sol";
import {
    IStreamScriptBundles as B
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScriptBundles.sol";
import {
    StreamCollectionManifestTypes as M
} from "../../../smart-contracts/interfaces/stream/metadata/StreamCollectionManifestTypes.sol";

interface CitationJsonVm {
    function parseJsonString(string calldata json, string calldata key)
        external
        pure
        returns (string memory);
}

/// @dev Exact immutable one-chunk source, isolating the output codec rather than bundle authority.
contract CitationBundleSource {
    function recordedScriptBundle(bytes32) external pure returns (bytes32) {
        return bytes32(uint256(7));
    }

    function scriptBundle(bytes32) external pure returns (B.Facts memory) {
        return B.Facts(
            keccak256("window.art=1;"), 0, 13, 1, M.PayloadSourceType.INLINE_CHUNKS, false, true
        );
    }

    function scriptBundleChunk(bytes32, uint256 index) external pure returns (bytes memory) {
        require(index == 0);
        return bytes("window.art=1;");
    }
}

contract CitationFallbackHost {
    function tokenURI(uint256 token, uint8 status) external view returns (string memory) {
        return Fallback.coreFallbackTokenURI(token, status);
    }
}

contract StreamMetadataCitationTest is CharacterizationTestBase {
    address private constant CORE = address(uint160(0x001234567890abcdef1234567890abcdef12345678));
    string private constant WORK =
        "eip155:1/erc721:0x1234567890abcdef1234567890abcdef12345678/100000000000000000001";

    function testLiteralOriginalIdentityLowercaseAndGlobalToken() public pure {
        require(
            keccak256(bytes(Citation.work(1, CORE, 100000000000000000001)))
                == keccak256(bytes(WORK)),
            "literal identity"
        );
        require(
            keccak256(bytes(Citation.work(1, address(0xabc), 0)))
                == keccak256("eip155:1/erc721:0x0000000000000000000000000000000000000abc/0"),
            "zero decimal and padding"
        );
    }

    function testFullUint256ChainAndTokenDecimalNeverNarrowed() public pure {
        string memory expected =
            "eip155:115792089237316195423570985008687907853269984665640564039457584007913129639935/erc721:0xffffffffffffffffffffffffffffffffffffffff/115792089237316195423570985008687907853269984665640564039457584007913129639935";
        require(
            keccak256(
                bytes(
                    Citation.work(type(uint256).max, address(type(uint160).max), type(uint256).max)
                )
            ) == keccak256(bytes(expected)),
            "uint256 literal"
        );
    }

    function testOrdinaryCurrentJSONAndURIAreExactDistinctProfile() public {
        (T.Token memory t, F.ServingSource memory source) = _ordinary();
        string memory old = TokenRenderer.render(t, source, "");
        string memory literal =
            '{"name":"Work #7","description":"","image":"","metadata_schema_version":"6529stream-v1","metadata_state":"active","token_id":100000000000000000001,"collection_id":99,"collection_serial":7,"hash":"0x0000000000000000000000000000000000000000000000000000000000000000","token_data_base64":"AQI=","attributes":[]}';
        require(keccak256(bytes(old)) == keccak256(bytes(literal)), "old literal output");
        require(
            keccak256(
                bytes(TokenRenderer.renderForFinality(false, abi.encode(t, source, bytes(""))))
            ) == keccak256(bytes(literal)),
            "original archived entry"
        );
        string memory nowJSON = TokenRenderer.renderCurrent(0, t, source, "", false, 1, CORE);
        _citation(nowJSON);
        require(
            _count(nowJSON, '"properties"') == 1 && _count(nowJSON, '"citation"') == 1,
            "unique JSON fields"
        );
        require(
            keccak256(bytes(TokenRenderer.renderCurrent(1, t, source, "", false, 1, CORE)))
                == keccak256(
                    bytes(
                        string.concat(
                            "data:application/json;base64,", Base64.encode(bytes(nowJSON))
                        )
                    )
                ),
            "current URI exact JSON"
        );
        require(_count(old, '"citation"') == 0, "old output unchanged");
    }

    function testPendingBurnedAndUnconfiguredCurrentKeepWorkIdentity() public {
        (T.Token memory t, F.ServingSource memory source) = _ordinary();
        t.finalized = false;
        t.state = "pending";
        _citation(TokenRenderer.renderCurrent(0, t, source, "", false, 1, CORE));
        t.finalized = true;
        t.state = "burned";
        _citation(TokenRenderer.renderCurrent(2, t, source, "", false, 1, CORE));
        t.configured = false;
        _citation(TokenRenderer.renderCurrent(0, t, source, "", false, 1, CORE));
    }

    function testLiveAttributionSharesOnePropertiesObjectWithCitation() public {
        (T.Token memory t, F.ServingSource memory source) = _ordinary();
        bytes memory artist = bytes('{"state":"artist_accepted","artist_display_name":"A"}');
        string memory json = TokenRenderer.renderCurrent(2, t, source, artist, true, 1, CORE);
        _citation(json);
        require(_count(json, '"properties"') == 1, "one actual nested properties object");
        require(
            keccak256(
                bytes(
                    abi.decode(
                        vm.parseJson(json, ".properties.provenance.attribution.state"), (string)
                    )
                )
            ) == keccak256("artist_accepted"),
            "live attribution retained beside stream"
        );
    }

    function testFullCurrentJSONAddsNoDuplicateTokenDataAndPreservesHTML() public {
        (T.Token memory t, F.ServingSource memory source) = _ordinary();
        source.script = "window.art=1;";
        string memory full = TokenRenderer.renderCurrent(2, t, source, "", false, 1, CORE);
        _citation(full);
        require(_count(full, '"token_data_base64"') == 1, "single full data");
        require(
            keccak256(bytes(TokenRenderer.renderCurrent(3, t, source, "", false, 1, CORE)))
                == keccak256(
                    bytes(TokenRenderer.fullViewForFinality(true, abi.encode(t, source, bytes(""))))
                ),
            "original executable HTML exact"
        );
        require(
            _count(TokenRenderer.fullJSON(t, source, ""), '"citation"') == 0, "old full profile"
        );
    }

    function testBundleCurrentCompactAndFullKeepSinglePropertiesAndOriginalFinalityBytes() public {
        DisplayGas.initialize(address(this));
        CitationBundleSource host = new CitationBundleSource();
        B.Selection memory selection = B.Selection(
            address(host), address(host).codehash, bytes32(uint256(7)), bytes32(uint256(9))
        );
        (T.Token memory t, F.ServingSource memory source) = _ordinary();
        bytes memory attribution = bytes('{"state":"artist_accepted"}');
        string memory compact = Bundle.renderCurrent(
            0, t, source, attribution, true, selection, address(this), 1, CORE
        );
        _citation(compact);
        require(_count(compact, '"properties"') == 1, "one compact properties object");
        require(
            keccak256(
                bytes(
                    abi.decode(
                        vm.parseJson(compact, ".properties.provenance.attribution.state"), (string)
                    )
                )
            ) == keccak256("artist_accepted"),
            "compact live attribution"
        );
        string memory full = Bundle.renderCurrent(
            2, t, source, attribution, true, selection, address(this), 1, CORE
        );
        _citation(full);
        require(
            _count(full, '"properties"') == 1 && _count(full, '"token_data_base64"') == 1,
            "one full properties and token data"
        );
        string memory original = Bundle.render(0, t, source, "", selection, address(this), 1);
        string memory retained = Bundle.renderBundleForFinality(
            0,
            abi.encode(t, source, bytes(""), selection, address(this), uint256(1), uint256(2000000))
        );
        require(
            keccak256(bytes(original)) == keccak256(bytes(retained))
                && _count(retained, '"citation"') == 0,
            "original compact finality entry"
        );
        require(
            keccak256(bytes(Bundle.render(3, t, source, "", selection, address(this), 1)))
                == keccak256(
                    bytes(
                        Bundle.renderCurrent(
                            3, t, source, attribution, true, selection, address(this), 1, CORE
                        )
                    )
                ),
            "bundle HTML exact old output"
        );
    }

    function testFallbackUsesDelegateHostCoreNotLinkedLibrary() public {
        CitationFallbackHost host = new CitationFallbackHost();
        vm.chainId(1);
        string memory expected = string.concat(
            '{"name":"6529 Stream #100000000000000000001","description":"Stream metadata is temporarily unavailable.","image":"","properties":{"stream":{"error":"ROUTER_UNSET","citation":"eip155:1/erc721:',
            Strings.toHexString(uint256(uint160(address(host))), 20),
            '/100000000000000000001"}}}'
        );
        vm.parseJson(expected);
        require(
            keccak256(bytes(host.tokenURI(100000000000000000001, 4)))
                == keccak256(
                    bytes(
                        string.concat(
                            "data:application/json;base64,", Base64.encode(bytes(expected))
                        )
                    )
                ),
            "delegate host original identity"
        );
    }

    function testStaticCurrentJSONAndCompactKeepOriginalContextAndEntry() public {
        (R.RenderRequest memory request, Encoding.Prepared memory p) = _static();
        string memory old = Encoding.render(request, p, "", address(0x111), 0);
        string memory current = Encoding.renderCurrent(request, p, "", address(0x111), 0);
        vm.parseJson(old);
        _citation(current);
        require(
            _count(old, '"citation"') == 0 && _count(current, '"properties"') == 1,
            "old entry and unique properties"
        );
        require(
            keccak256(
                bytes(
                    CitationJsonVm(address(vm))
                        .parseJsonString(current, ".properties.stream.contract")
                )
            ) == keccak256("0x1234567890abcdef1234567890abcdef12345678"),
            "original context untouched"
        );
        p.bundle = bytes32(uint256(1));
        string memory compact = Encoding.renderCurrent(request, p, "", address(0x111), 0);
        _citation(compact);
        require(
            _count(compact, '"citation"') == 1
                && _count(Encoding.render(request, p, "", address(0x111), 0), '"citation"') == 0,
            "compact profile separation"
        );
    }

    function testStaticCurrentJSONNeverChangesExecutableHTML() public pure {
        (R.RenderRequest memory request, Encoding.Prepared memory p) = _static();
        request.state = R.TokenRenderState.ACTIVE;
        p.facts.entropyStatus = 5;
        string memory original = Encoding.render(request, p, "window.art=1;", address(0x111), 3);
        string memory current =
            Encoding.renderCurrent(request, p, "window.art=1;", address(0x111), 3);
        require(keccak256(bytes(original)) == keccak256(bytes(current)), "exact old HTML");
        require(_count(current, '"citation"') == 0, "no historical JS context change");
    }

    function _ordinary() private pure returns (T.Token memory t, F.ServingSource memory s) {
        t = T.Token(100000000000000000001, 99, 7, 0, true, "active", hex"0102", true);
        s.name = "Work";
    }

    function _static() private pure returns (R.RenderRequest memory r, Encoding.Prepared memory p) {
        r.core = CORE;
        r.tokenId = 100000000000000000001;
        r.collectionId = 99;
        r.collectionSerial = 7;
        r.state = R.TokenRenderState.PENDING_RANDOMNESS;
        r.mode = R.MetadataMode.ONCHAIN;
        p.config.mode = R.MetadataMode.ONCHAIN;
        p.source.chainId = 1;
        p.source.name = "Work";
        p.facts.chainId = 1;
        p.facts.viewName = "MARKETPLACE";
        p.facts.entropyStatus = 4;
        p.artist = bytes('{"state":"unbound"}');
    }

    function _citation(string memory json) private {
        string memory actual =
            abi.decode(vm.parseJson(json, ".properties.stream.citation"), (string));
        require(keccak256(bytes(actual)) == keccak256(bytes(WORK)), "literal current citation");
    }

    function _count(string memory haystack, string memory needle)
        private
        pure
        returns (uint256 count)
    {
        bytes memory h = bytes(haystack);
        bytes memory n = bytes(needle);
        for (uint256 i; i + n.length <= h.length; ++i) {
            bool match_ = true;
            for (uint256 j; j < n.length; ++j) {
                if (h[i + j] != n[j]) {
                    match_ = false;
                    break;
                }
            }
            if (match_) ++count;
        }
    }
}
