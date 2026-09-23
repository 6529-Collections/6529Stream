// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

import {
    StreamArtistRecoveredIdentityHydrationState as X
} from "./StreamArtistRecoveredIdentityHydrationState.sol";

/// @notice Fixed Identity export stage in the original owner storage context.
library StreamArtistRecoveredIdentityExportRecordRowsA {
    function row25(uint256[17] memory r, bytes32 artistId, RH.JournalEntry memory j)
        public
        view
        returns (bytes memory)
    {
        bytes32 key = j.receipt.recordHash;
        IH.RevisionRow memory row;
        row.position = j.position;
        row.record = X.revisions(r).records[key];
        row.document = X.identity(r).documents[row.record.revisedRecordHash];
        row.association = X.revisions(r).associations[key];
        row.status = X.rewinds(r).statuses[key];
        row.rewindContinuation = X.rewinds(r).revisionRecordContinuations[key];
        return abi.encode(row);
    }

    function row26(uint256[17] memory r, bytes32 artistId, RH.JournalEntry memory j)
        public
        view
        returns (bytes memory)
    {
        bytes32 key = j.receipt.recordHash;
        IH.DelegationRow memory row;
        row.position = j.position;
        row.recordHash = key;
        row.record = X.delegations(r).records[key];
        row.current =
            X.delegations(r).current[keccak256(abi.encode(artistId, row.record.grant.delegate))];
        row.epoch = X.estate(r).grantEpoch[key];
        return abi.encode(row);
    }

    function row28(uint256[17] memory r, bytes32 artistId, RH.JournalEntry memory j)
        public
        view
        returns (bytes memory)
    {
        bytes32 key = j.receipt.recordHash;
        return abi.encode(
            IH.GuardianRow(
                j.position,
                X.rotations(r).guardians[key],
                X.recovery(r).guardianHistory.entries[key],
                X.recovery(r).guardianSupersession.statuses[key]
            )
        );
    }

    function row29(uint256[17] memory r, bytes32 artistId, RH.JournalEntry memory j)
        public
        view
        returns (bytes memory)
    {
        bytes32 key = j.receipt.recordHash;
        IH.RotationRow memory row;
        row.position = j.position;
        row.record = X.rotations(r).rotations[key];
        address[] memory members =
        X.rotations(r).guardians[row.record.guardianSetRecordHash].terms.guardians;
        row.approvals = new bool[](members.length);
        for (uint256 k; k < members.length; ++k) {
            row.approvals[k] = X.rotations(r).approvals[key][members[k]];
        }
        return abi.encode(row);
    }
}
