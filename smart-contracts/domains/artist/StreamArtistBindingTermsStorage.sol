// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistCollaboratorHashes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistCollaboratorTypes as C
} from "../../interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";

/// @dev Fixed delegate-linked storage worker; the owner retains proposal admission and commit ordering.
library StreamArtistBindingTermsStorage {
    function store(
        mapping(uint256 => mapping(uint64 => C.BindingTerms)) storage _terms,
        mapping(uint256 => mapping(uint64 => T.CollaboratorRecord[])) storage _collaborators,
        uint256 collectionId,
        uint64 generation,
        T.CollaboratorRecord[] calldata rows
    ) public {
        if (rows.length > 32) revert T.BoundExceeded(rows.length, 32);
        for (uint256 i; i < rows.length; ++i) {
            T.CollaboratorRecord calldata row = rows[i];
            if (row.account == address(0)) revert T.InvalidRecord();
            if (i != 0) {
                T.CollaboratorRecord calldata prior = rows[i - 1];
                // Strict (account,role) ordering also satisfies sorted triples and excludes duplicate pairs.
                if (
                    uint160(row.account) < uint160(prior.account)
                        || (row.account == prior.account
                            && uint256(row.role) <= uint256(prior.role))
                ) revert T.InvalidRecord();
            }
            _collaborators[collectionId][generation].push(row);
        }
        _terms[collectionId][generation] = C.BindingTerms(
            StreamArtistCollaboratorHashes.collaboratorSetHash(rows),
            StreamArtistHashes.emptyCapabilities(),
            0,
            0,
            uint32(rows.length)
        );
    }
}
