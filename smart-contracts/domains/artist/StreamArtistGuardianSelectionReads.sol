// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamArtistGuardianSelectionPreparation,
    IStreamArtistGuardianSelectionBinding,
    IStreamArtistGuardianSelectionOwner
} from "../../interfaces/stream/artist/IStreamArtistGuardianSelectionPreparation.sol";
import {
    StreamArtistGuardianSelectionTypes as S
} from "../../interfaces/stream/artist/StreamArtistGuardianSelectionTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as H
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";

/// @notice The immutable Identity child supplies the sole accepted election producer.
library StreamArtistGuardianSelectionReads {
    function requireSelection(
        StreamArtistHashes.Environment memory e,
        bytes32 artistId,
        H.Head memory history,
        R.TransitionState memory transition,
        bytes32[] memory excluded
    ) public view returns (S.Result memory result) {
        address child = IStreamArtistGuardianSelectionOwner(address(this))
            .identityRecoveryExtension();
        if (child.code.length == 0 || block.chainid != e.chainId) {
            revert S.InvalidGuardianSelection(bytes32(0));
        }
        (address target, bytes32 codeHash) =
            IStreamArtistGuardianSelectionBinding(child).guardianSelectionPreparationBinding();
        if (target.code.length == 0 || target.codehash != codeHash || codeHash == 0) {
            revert S.InvalidGuardianSelection(bytes32(0));
        }
        IStreamArtistGuardianSelectionPreparation preparation =
            IStreamArtistGuardianSelectionPreparation(target);
        if (
            preparation.owner() != address(this) || preparation.artistRegistry() != e.registry
                || preparation.deploymentChainId() != e.chainId
        ) revert S.InvalidGuardianSelection(bytes32(0));
        result = preparation.requireSelection(artistId, history, transition, excluded);
        if (
            result.commitment == 0 || result.sourceKey == 0
                || (result.selectedRecordHash == 0
                        ? result.selectedDataHash != 0 || result.selectedNonce != 0
                        : result.selectedDataHash == 0)
        ) revert S.InvalidGuardianSelection(result.sourceKey);
    }
}
