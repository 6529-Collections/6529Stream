// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistCompleteHistoryCollectionImport as Complete } from "./StreamArtistCompleteHistoryCollectionImport.sol";
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
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorCodec as Codec
} from "./StreamArtistPrimaryCollaboratorCodec.sol";
import {
    StreamArtistPrimaryCollaboratorSourceProof as Source
} from "./StreamArtistPrimaryCollaboratorSourceProof.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistPrimaryCollaboratorDecode as Decode
} from "./StreamArtistPrimaryCollaboratorDecode.sol";
import {
    StreamArtistCollaboratorTypes as C
} from "../../interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";
import { StreamArtistCollaboratorHashes as Hashes } from "./StreamArtistCollaboratorHashes.sol";

/// @notice Original owner1 and owner3 maps; all target keys checked before the first write.
/// @dev Common op60 alone installs provenance/replay and commits the owner once. These
/// workers do not replay original producers or emit fabricated historical events.
library StreamArtistPrimaryCollaboratorCollectionImport {
    function collaborators(
        mapping(bytes32 => C.IdentityProposalState) storage proposals,
        mapping(bytes32 => C.Join) storage joins,
        mapping(bytes32 => uint32) storage counts,
        mapping(bytes32 => mapping(address => bool)) storage links,
        AH.Query memory anchor,
        bytes memory outer
    ) public returns (bool) {
        if (Complete.collaborators(proposals, joins, counts, links, anchor, outer)) return true;
        if (!Codec.selected(outer, 1)) return false;
        (,, PC.Proof memory proof) = Decode.collect(1, anchor, outer);
        C.IdentityProposalState memory emptyProposal;
        C.Join memory emptyJoin;
        for (uint256 i; i < proof.archive.proposals.length; ++i) {
            C.IdentityProposal memory row = proof.archive.proposals[i].state.proposal;
            if (
                keccak256(
                        abi.encode(
                            proposals[keccak256(abi.encode(row.account, row.identityRecordHash))]
                        )
                    ) != keccak256(abi.encode(emptyProposal))
            ) _invalid();
        }
        for (uint256 k; k < proof.bindings.bindings.length; ++k) {
            for (uint256 g; g < proof.bindings.generations[k].length; ++g) {
                if (counts[proof.bindings.generations[k][g].bindingHash] != 0) _invalid();
            }
        }
        for (uint256 i; i < proof.archive.accepted.length; ++i) {
            PC.AcceptedRow memory row = proof.archive.accepted[i];
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
        for (uint256 i; i < proof.archive.proposals.length; ++i) {
            C.IdentityProposalState memory row = proof.archive.proposals[i].state;
            proposals[
                keccak256(abi.encode(row.proposal.account, row.proposal.identityRecordHash))
            ] = row;
        }
        for (uint256 i; i < proof.archive.accepted.length; ++i) {
            PC.AcceptedRow memory row = proof.archive.accepted[i];
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
        if (Complete.acceptances(primary, times, collaborators_, anchor, outer)) return true;
        if (!Codec.selected(outer, 3)) return false;
        (M.State memory scope,, PC.Proof memory proof) = Decode.collect(3, anchor, outer);
        if (scope.rows.length != proof.accepted.length) _invalid();
        for (uint256 k; k < proof.accepted.length; ++k) {
            if (keccak256(scope.rows[k]) != keccak256(abi.encode(proof.accepted[k]))) _invalid();
            for (uint256 g; g < proof.accepted[k].rows.length; ++g) {
                bytes32 key = proof.accepted[k].rows[g].bindingHash;
                if (primary[key] != 0 || times[key] != 0) _invalid();
            }
        }
        for (uint256 i; i < proof.archive.accepted.length; ++i) {
            C.BindingAcceptance memory row = proof.archive.accepted[i].acceptance;
            if (
                collaborators_[
                        Hashes.rowKey(row.bindingHash, row.account, row.role, row.shareLabelId)
                    ] != 0
            ) _invalid();
        }
        for (uint256 k; k < proof.accepted.length; ++k) {
            for (uint256 g; g < proof.accepted[k].rows.length; ++g) {
                primary[proof.accepted[k].rows[g].bindingHash] =
                proof.accepted[k].rows[g].recordHash;
                times[proof.accepted[k].rows[g].bindingHash] = proof.accepted[k].rows[g].acceptedAt;
            }
        }
        for (uint256 i; i < proof.archive.accepted.length; ++i) {
            PC.AcceptedRow memory row = proof.archive.accepted[i];
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
