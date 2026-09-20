// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistC2PACredentials.sol";
import {
    StreamArtistReadinessHydrationTypes as RH
} from "../../interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";

/// @notice Reconstruct the new derived indices from every original ordered attestation receipt.
library StreamArtistC2PAHydration {
    function checkSource(
        address owner,
        address origin,
        bytes32 artistId,
        bytes32 bindingHash,
        uint256 collectionId,
        RH.AttestationRow[] memory rows
    ) public view {
        C2PA.Head memory expected;
        T.AttestationRecord memory personhood;
        for (uint256 i; i < rows.length; ++i) {
            RH.AttestationRow memory row = rows[i];
            T.Attestation memory p = row.input.terms;
            if (p.subjectKind != 10) continue;
            if (StreamArtistC2PACredentials.isPersonhood(p.schemaId)) personhood = row.record;
            if (p.schemaId != StreamArtistC2PACredentials.SCHEMA) continue;
            C2PA.Payload memory payload =
                StreamArtistC2PACredentials.decode(row.statement, artistId, p.subjectStateHash);
            if (payload.previousRecordHash != expected.recordHash) revert T.InvalidRecord();
            expected = C2PA.Head(
                expected.revision + 1,
                row.record.recordHash,
                expected.recordHash,
                artistId,
                collectionId,
                bindingHash,
                row.record.generation,
                p.subjectStateHash,
                row.record.statementHash,
                origin
            );
            if (
                keccak256(
                        abi.encode(
                            IStreamArtistC2PAReads(owner).c2paCredentialRecord(expected.recordHash)
                        )
                    ) != keccak256(abi.encode(expected))
            ) revert T.InvalidRecord();
        }
        // No new read is needed for old histories with no credential records. Complete native
        // receipt count/order and original record rehashing already prohibit omitting such a row.
        if (expected.recordHash == 0) return;
        if (
            keccak256(abi.encode(IStreamArtistC2PAReads(owner).c2paCredentialHead(artistId)))
                    != keccak256(abi.encode(expected))
                || keccak256(
                        abi.encode(
                            IStreamArtistC2PAReads(owner)
                                .personhoodAttestation(collectionId, artistId)
                        )
                    ) != keccak256(abi.encode(personhood))
        ) revert T.InvalidRecord();
    }
}
