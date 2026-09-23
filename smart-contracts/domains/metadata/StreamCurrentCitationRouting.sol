// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import { IStreamRenderer as R } from "../../interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamCurrentCitationRenderer as C
} from "../../interfaces/stream/metadata/IStreamCurrentCitationRenderer.sol";
import {
    IStreamCurrentCitationRegistry as A
} from "../../interfaces/stream/metadata/IStreamCurrentCitationRegistry.sol";
import {
    IStreamStaticMetadataRouter as S
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import { StreamRendererV1 } from "./StreamRendererV1.sol";
import { StreamRendererCalls as Calls } from "./StreamRendererCalls.sol";

library StreamCurrentCitationRouting {
    /// @dev The selected renderer and Registry have already passed their original runtime pins.
    /// Old renderers keep the original entry. Advertised current output must be separately admitted.
    function input(
        S.Selection memory selected,
        R.RenderRequest memory request,
        uint8 mode,
        uint256 cap
    ) internal view returns (bytes memory) {
        bool current = abi.decode(
            Calls.read(
                selected.renderer,
                abi.encodeCall(IERC165.supportsInterface, (type(C).interfaceId)),
                Calls.ReadOptions(32, true),
                cap
            ),
            (bool)
        );
        if (current) {
            (address renderer, bytes32 runtime, bytes32 profile, bytes4 selector) = abi.decode(
                Calls.read(
                    selected.registry,
                    abi.encodeCall(A.requireCurrentCitation, (selected.versionKey)),
                    Calls.ReadOptions(128, true),
                    cap
                ),
                (address, bytes32, bytes32, bytes4)
            );
            if (
                renderer != selected.renderer || runtime != selected.rendererCodeHash
                    || profile != keccak256("6529STREAM_CURRENT_BASE_CITATION_V1")
                    || selector != C.renderCurrent.selector
            ) {
                revert S.InvalidStaticMetadataConfig();
            }
            return abi.encodeCall(C.renderCurrent, (request, mode == 4 ? 2 : mode));
        }
        return mode == 1
            ? abi.encodeCall(R.tokenURI, (request))
            : abi.encodeCall(StreamRendererV1.renderView, (request, mode == 4 ? 2 : mode));
    }
}
