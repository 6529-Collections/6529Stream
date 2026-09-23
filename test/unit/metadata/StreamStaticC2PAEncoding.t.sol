// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamStaticRenderEncoding as E
} from "../../../smart-contracts/domains/metadata/StreamStaticRenderEncoding.sol";
import { FrozenStaticRenderEncoding as Old } from "./helpers/FrozenStaticRenderEncoding.sol";
import {
    IStreamRenderer as R
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamC2PAReconciliation as C
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamC2PAReconciliation.sol";
import {
    IStreamC2PAConflicts as CF
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamC2PAConflicts.sol";

contract StreamStaticC2PAEncodingTest {
    function testNoC2PAFieldsKeepFrozenAllModeExactBytes() public pure {
        for (uint8 metadataMode; metadataMode < 3; ++metadataMode) {
            for (uint8 mode; mode < 4; ++mode) {
                (R.RenderRequest memory r, E.Prepared memory p) = _input();
                p.config.mode = R.MetadataMode(metadataMode);
                Old.Prepared memory old = abi.decode(abi.encode(p), (Old.Prepared));
                string memory script = "const t='</ScRiPtX';";
                require(
                    keccak256(bytes(E.render(r, p, script, address(2), mode)))
                        == keccak256(bytes(Old.render(r, old, script, address(2), mode))),
                    "old output changed"
                );
            }
        }
    }

    function testFuzzAbsentC2PAKeepsFrozenJSONHTMLBytes(bytes memory arbitrary) public pure {
        if (arbitrary.length > 256) return;
        (R.RenderRequest memory r, E.Prepared memory p) = _input();
        p.source.name = string(arbitrary);
        p.source.description = string(arbitrary);
        p.source.animationBaseURI = string(arbitrary);
        p.facts.tokenData = arbitrary;
        Old.Prepared memory old = abi.decode(abi.encode(p), (Old.Prepared));
        for (uint8 mode; mode < 4; ++mode) {
            require(
                keccak256(bytes(E.render(r, p, string(arbitrary), address(2), mode)))
                    == keccak256(bytes(Old.render(r, old, string(arbitrary), address(2), mode))),
                "arbitrary bytes parity"
            );
        }
    }

    function testReportFieldsNeverAlterExecutableHTML() public pure {
        (R.RenderRequest memory r, E.Prepared memory p) = _input();
        bytes32 before_ = keccak256(bytes(E.render(r, p, "run();", address(2), 3)));
        p.c2pa = C.Display(
            keccak256("record"),
            keccak256("selection"),
            C.ValidationStatus.VALID,
            C.AuthorshipStatus.DIVERGENT,
            true,
            true
        );
        p.c2paSubject = keccak256("subject");
        require(
            before_ == keccak256(bytes(E.render(r, p, "run();", address(2), 3))),
            "report became executable content"
        );
    }

    function testStandingConflictSurvivesStaleOrConsistentReportWithoutChangingArtwork()
        public
        pure
    {
        (R.RenderRequest memory r, E.Prepared memory p) = _input();
        bytes32 html = keccak256(bytes(E.render(r, p, "run();", address(2), 3)));
        p.c2paConflictsEnabled = true;
        p.c2paCollectionConflict = CF.Standing(
            keccak256("conflict"),
            keccak256("chain"),
            keccak256("adverse record"),
            keccak256("selection"),
            1,
            1
        );
        p.c2pa = C.Display(
            keccak256("latest"),
            keccak256("latest selection"),
            C.ValidationStatus.UNEVALUATED,
            C.AuthorshipStatus.UNEVALUATED,
            false,
            true
        );
        string memory stale = E.render(r, p, "run();", address(2), 2);
        require(_contains(stale, '"c2pa_attribution_divergence":true'));
        require(_contains(stale, '"c2pa_authorship_status":"unevaluated"'));
        require(_contains(stale, '"c2pa_conflict_state":"standing"'));
        p.c2pa.validation = C.ValidationStatus.VALID;
        p.c2pa.authorship = C.AuthorshipStatus.CONSISTENT;
        p.c2pa.current = true;
        string memory current = E.render(r, p, "run();", address(2), 2);
        require(_contains(current, '"c2pa_attribution_divergence":true'));
        require(_contains(current, '"c2pa_authorship_status":"consistent"'));
        require(
            keccak256(bytes(stale)) != keccak256(bytes(current)),
            "full JSON remains exact live bytes"
        );
        require(html == keccak256(bytes(E.render(r, p, "run();", address(2), 3))));
    }

    function testUnavailableConflictReadNeverClaimsClear() public pure {
        (R.RenderRequest memory r, E.Prepared memory p) = _input();
        p.c2paConflictsEnabled = true;
        p.c2paConflictsUnavailable = true;
        string memory output = E.render(r, p, "", address(2), 0);
        require(_contains(output, '"c2pa_conflict_read_unavailable":true'));
        require(_contains(output, '"c2pa_attribution_divergence":null'));
        require(!_contains(output, '"c2pa_conflict_state":"none"'));
    }

    function _contains(string memory value, string memory needle) private pure returns (bool) {
        bytes memory v = bytes(value);
        bytes memory n = bytes(needle);
        for (uint256 i; i + n.length <= v.length; ++i) {
            bool ok = true;
            for (uint256 j; j < n.length; ++j) {
                if (v[i + j] != n[j]) {
                    ok = false;
                    break;
                }
            }
            if (ok) return true;
        }
        return false;
    }

    function _input() private pure returns (R.RenderRequest memory r, E.Prepared memory p) {
        r.core = address(1);
        r.collectionId = 3;
        r.tokenId = 91;
        r.collectionSerial = 5;
        r.tokenHash = bytes32(uint256(9));
        r.state = R.TokenRenderState.ACTIVE;
        r.metadataSnapshotHash = bytes32(uint256(7));
        p.source.chainId = 1;
        p.source.name = "name\"<";
        p.source.description = string(hex"e280a80a005c");
        p.source.imageURI = "ipfs://image";
        p.source.animationBaseURI = "https://animation/";
        p.config.mode = R.MetadataMode.ONCHAIN;
        p.config.baseURI = "https://base/\"<";
        p.facts.chainId = 1;
        p.facts.viewName = "MARKETPLACE";
        p.facts.entropyStatus = 5;
        p.facts.tokenData = hex"ff00225c";
        p.bundle = bytes32(uint256(1));
        p.artist = '{"state":"unbound"}';
    }
}
