// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistCompleteHistoryDecode as Decode
} from "./StreamArtistCompleteHistoryDecode.sol";
import { StreamArtistCompleteHistoryCodec as Codec } from "./StreamArtistCompleteHistoryCodec.sol";
import { StreamArtistCompleteHistoryTypes as CT } from "./StreamArtistCompleteHistoryTypes.sol";
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistCollaboratorTypes as C
} from "../../interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";
import { StreamArtistCollaboratorHashes as Hashes } from "./StreamArtistCollaboratorHashes.sol";

/// @notice Original collaborator and acceptance maps, including retained partial/terminal generations.
/// @dev All target keys are checked before the first write. The common op60 worker alone
/// installs provenance/replay and commits once; these workers emit no historical events.
library StreamArtistCompleteHistoryCollectionImport {
    function collaborators(
        mapping(bytes32 => C.IdentityProposalState) storage proposals,
        mapping(bytes32 => C.Join) storage joins,
        mapping(bytes32 => uint32) storage counts,
        mapping(bytes32 => mapping(address => bool)) storage links,
        AH.Query memory anchor,
        bytes memory outer
    ) public returns (bool) {
        if (!Codec.selected(outer, 1)) return false;
        (,, CT.Inventory memory inventory,) = Decode.collect(1, anchor, outer);
        C.IdentityProposalState memory emptyProposal;
        C.Join memory emptyJoin;
        for (uint256 i; i < inventory.archive.proposals.length; ++i) {
            C.IdentityProposal memory row = inventory.archive.proposals[i].state.proposal;
            if (
                keccak256(
                        abi.encode(
                            proposals[keccak256(abi.encode(row.account, row.identityRecordHash))]
                        )
                    ) != keccak256(abi.encode(emptyProposal))
            ) _invalid();
        }
        for (uint256 k; k < inventory.bindings.bindings.length; ++k) {
            for (uint256 g; g < inventory.bindings.generations[k].length; ++g) {
                if (counts[inventory.bindings.generations[k][g].bindingHash] != 0) _invalid();
            }
        }
        for (uint256 i; i < inventory.archive.accepted.length; ++i) {
            PC.AcceptedRow memory row = inventory.archive.accepted[i];
            bytes32 key = Hashes.rowKey(
                row.acceptance.bindingHash,
                row.acceptance.account,
                row.acceptance.role,
                row.acceptance.shareLabelId
            );
            if (
                keccak256(abi.encode(joins[key])) != keccak256(abi.encode(emptyJoin))
                    || links[row.join.artistId][row.acceptance.account]
            ) _invalid();
        }
        for (uint256 i; i < inventory.archive.proposals.length; ++i) {
            C.IdentityProposalState memory row = inventory.archive.proposals[i].state;
            proposals[
                keccak256(abi.encode(row.proposal.account, row.proposal.identityRecordHash))
            ] = row;
        }
        for (uint256 i; i < inventory.archive.accepted.length; ++i) {
            PC.AcceptedRow memory row = inventory.archive.accepted[i];
            joins[
                Hashes.rowKey(
                    row.acceptance.bindingHash,
                    row.acceptance.account,
                    row.acceptance.role,
                    row.acceptance.shareLabelId
                )
            ] = row.join;
            ++counts[row.acceptance.bindingHash];
            links[row.join.artistId][row.acceptance.account] = true;
        }
        return true;
    }

    function acceptances(
        mapping(bytes32 => bytes32) storage primary,
        mapping(bytes32 => uint64) storage times,
        mapping(bytes32 => bytes32) storage collaborators_,
        AH.Query memory anchor,
        bytes memory outer
    ) public returns (bool) {
        if (!Codec.selected(outer, 3)) return false;
        (M.State memory scope,, CT.Inventory memory inventory,) = Decode.collect(3, anchor, outer);
        if (scope.rows.length != inventory.accepted.length) _invalid();
        for (uint256 k; k < inventory.accepted.length; ++k) {
            if (keccak256(scope.rows[k]) != keccak256(abi.encode(inventory.accepted[k]))) {
                _invalid();
            }
            for (uint256 g; g < inventory.accepted[k].rows.length; ++g) {
                bytes32 key = inventory.accepted[k].rows[g].bindingHash;
                if (primary[key] != 0 || times[key] != 0) _invalid();
            }
        }
        for (uint256 i; i < inventory.archive.accepted.length; ++i) {
            C.BindingAcceptance memory row = inventory.archive.accepted[i].acceptance;
            if (
                collaborators_[
                        Hashes.rowKey(row.bindingHash, row.account, row.role, row.shareLabelId)
                    ] != 0
            ) _invalid();
        }
        for (uint256 k; k < inventory.accepted.length; ++k) {
            // Unbound slots have no rows. Pending/terminal rows retain their actual
            // primary map and timestamp, including both zeros when never accepted.
            for (uint256 g; g < inventory.accepted[k].rows.length; ++g) {
                primary[inventory.accepted[k].rows[g].bindingHash] =
                inventory.accepted[k].rows[g].recordHash;
                times[inventory.accepted[k].rows[g].bindingHash] =
                inventory.accepted[k].rows[g].acceptedAt;
            }
        }
        for (uint256 i; i < inventory.archive.accepted.length; ++i) {
            PC.AcceptedRow memory row = inventory.archive.accepted[i];
            collaborators_[
                Hashes.rowKey(
                    row.acceptance.bindingHash,
                    row.acceptance.account,
                    row.acceptance.role,
                    row.acceptance.shareLabelId
                )
            ] = row.join.acceptanceRecordHash;
        }
        return true;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
