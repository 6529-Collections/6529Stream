// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistBindingCorrectionTypes as BC,
    IStreamArtistBindingCorrectionOwner
} from "../../interfaces/stream/artist/IStreamArtistBindingCorrection.sol";

import { StreamArtistBindingCorrectionHashes } from "./StreamArtistBindingCorrectionHashes.sol";
import { StreamArtistHashes as H } from "./StreamArtistHashes.sol";

/// @notice Fixed new-profile tuple storage/read codec; original owner guards and replay/commit stay on the owner.
library StreamArtistBindingCorrectionState {
    struct Correction {
        BC.Approval approval;
        bytes32 recordHash;
    }

    struct Summary {
        uint8 cause;
        bytes32 causeRecord;
        bytes32 actionId;
        uint64 previousGeneration;
        bytes32 previousBindingHash;
    }

    function validateEncoded(
        mapping(uint256 => T.Binding) storage bindings,
        bytes calldata originalCall
    ) public view returns (Summary memory result) {
        (, uint256 collectionId, bytes32 artistId,, BC.Approval memory approval) =
            _decode(originalCall);
        validate(bindings[collectionId], collectionId, artistId, approval);
        return Summary(
            approval.cause,
            approval.causeRecord,
            approval.governance.actionId,
            approval.previous.generation,
            approval.previous.bindingHash
        );
    }

    function hashEncoded(
        H.Environment memory e,
        uint256 collectionId,
        bytes32 bindingHash,
        bytes calldata originalCall
    ) public pure returns (bytes32) {
        (,,,, BC.Approval memory approval) = _decode(originalCall);
        return StreamArtistBindingCorrectionHashes.hash(e, collectionId, bindingHash, approval);
    }

    function saveEncoded(
        mapping(bytes32 => Correction) storage rows,
        bytes32 bindingHash,
        bytes32 recordHash,
        bytes calldata originalCall
    ) public {
        (,,,, BC.Approval memory approval) = _decode(originalCall);
        rows[bindingHash] = Correction(approval, recordHash);
    }

    function _decode(bytes calldata originalCall)
        private
        pure
        returns (
            T.ActionContext memory,
            uint256,
            bytes32,
            T.BindingProposal memory,
            BC.Approval memory
        )
    {
        if (
            bytes4(originalCall[:4])
                != IStreamArtistBindingCorrectionOwner.proposeAfterRevocation.selector
        ) revert T.InvalidRecord();
        return abi.decode(
            originalCall[4:], (T.ActionContext, uint256, bytes32, T.BindingProposal, BC.Approval)
        );
    }

    function validate(
        T.Binding storage previous,
        uint256 collectionId,
        bytes32 artistId,
        BC.Approval memory approval
    ) public view {
        if (
            approval.cause == 0 || approval.cause > 4 || approval.causeRecord == 0
                || approval.causeData.length == 0 || approval.proposalHash == 0
                || approval.proposedArtistId != artistId || approval.governance.actionId == 0
                || approval.governance.actionClass != 2
                || approval.governance.proposer == address(0)
                || approval.approvedAt != block.timestamp
                || keccak256(abi.encode(approval.previous)) != keccak256(abi.encode(previous))
        ) {
            revert BC.InvalidBindingCorrection(collectionId);
        }
    }

    function encoded(mapping(bytes32 => Correction) storage rows, bytes32 bindingHash)
        public
        view
        returns (bytes memory)
    {
        Correction storage saved = rows[bindingHash];
        return abi.encode(saved.approval, saved.recordHash);
    }
}
