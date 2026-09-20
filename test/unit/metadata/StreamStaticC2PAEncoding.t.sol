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
