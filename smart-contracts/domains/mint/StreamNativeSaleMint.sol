// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamMintManager as M } from "../../interfaces/stream/mint/IStreamMintManager.sol";
import {
    IStreamNativeFixedPriceSaleAdapter as N
} from "../../interfaces/stream/mint/IStreamNativeFixedPriceSaleAdapter.sol";
import "./StreamNativePriceProgram.sol";

/// @notice Linked native sale mint-result and retained-rights validation.
/// @dev Preserves the adapter as Manager executor; no storage, owner or independent mint route.
library StreamNativeSaleMint {
    function requireRetainedRights(
        StreamNativePriceProgram.Context memory x,
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c,
        address artist
    ) external view {
        StreamSaleArtist.requireArtist(x.artists, x.artistHash, c.sale.collectionId, artist);
        StreamNativeSettlementSupport.requireCurrent(
            x.resolver,
            c.sale.collectionId,
            StreamSaleTemplate.Selection(
                c.rights.profileId,
                c.rights.wallet,
                c.rights.templateId,
                c.rights.assignmentHash,
                c.rights.entriesHash
            )
        );
    }

    function execute(M manager, M.MintBatch memory batch, bytes32 expectedRoot, bytes32 expectedId)
        external
        returns (uint256 tokenId)
    {
        (uint256[] memory tokens, bytes32 root, bytes32[] memory ids) =
            manager.executeSingleStepMint(batch, "");
        if (
            tokens.length != 1 || tokens[0] == 0 || root != expectedRoot || ids.length != 1
                || ids[0] != expectedId
        ) {
            revert N.NativeMintResultInvalid();
        }
        return tokens[0];
    }
}
