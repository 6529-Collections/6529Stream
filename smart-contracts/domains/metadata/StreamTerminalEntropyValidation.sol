// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamRenderer as R } from "../../interfaces/stream/metadata/IStreamRenderer.sol";
import { IStreamCoreIdentity as I } from "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import {
    IStreamCoreCollectionView as C
} from "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import {
    StreamEntropyRenderPolicyReads as Reads
} from "../entropy/StreamEntropyRenderPolicyReads.sol";
import {
    StreamEntropyPolicyConsumerTypes as P
} from "../../interfaces/stream/entropy/StreamEntropyPolicyConsumerTypes.sol";
import { StreamRendererCalls as Calls } from "./StreamRendererCalls.sol";

/// @notice Fixed STATIC-only validator for the new terminal entry; no storage or authority mutation.
library StreamTerminalEntropyValidation {
    error InvalidTerminalRequest();

    function validate(
        R.RenderRequest memory r,
        address entropy,
        bytes32 entropyHash,
        bool configFrozen,
        uint256 cap
    ) public view returns (P.Terminal memory p) {
        p = Reads.staticTerminal(r.core, r.tokenId, r.collectionId, cap);
        (bool exists, uint256 cid, uint256 serial, bool burned) = abi.decode(
            Calls.read(
                r.core,
                abi.encodeCall(I.tokenCollectionIdentity, (r.tokenId)),
                Calls.ReadOptions(128, true),
                cap
            ),
            (bool, uint256, uint256, bool)
        );
        uint8 lifecycle = abi.decode(
            Calls.read(
                r.core,
                abi.encodeCall(I.tokenLifecycle, (r.tokenId)),
                Calls.ReadOptions(32, true),
                cap
            ),
            (uint8)
        );
        bool frozen = configFrozen
            || abi.decode(
                Calls.read(
                    r.core,
                    abi.encodeCall(C.collectionFreezeStatus, (r.collectionId)),
                    Calls.ReadOptions(32, true),
                    cap
                ),
                (bool)
            );
        R.TokenRenderState expected = burned
            ? R.TokenRenderState.BURNED
            : frozen ? R.TokenRenderState.FROZEN : R.TokenRenderState.ACTIVE;
        if (
            !exists || cid != r.collectionId || serial != r.collectionSerial
                || lifecycle != (burned ? 3 : 2) || p.coordinator != entropy
                || p.coordinatorCodeHash != entropyHash || r.tokenHash != 0 || r.state != expected
                || r.collectionSupplyMode
                    != abi.decode(
                        Calls.read(
                            r.core,
                            abi.encodeCall(C.collectionSupplyMode, (cid)),
                            Calls.ReadOptions(32, true),
                            cap
                        ),
                        (uint8)
                    )
                || r.collectionStatus
                    != abi.decode(
                        Calls.read(
                            r.core,
                            abi.encodeCall(C.collectionStatus, (cid)),
                            Calls.ReadOptions(32, true),
                            cap
                        ),
                        (uint8)
                    )
        ) revert InvalidTerminalRequest();
    }
}
