// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistPublicationHydration.sol";
import "./StreamArtistHydrationRecordFacts.sol";

library StreamArtistPublicationHydrationFacts {
    function check(
        AH.Query memory q,
        AH.OwnerData[7] memory data,
        T.SuiteConfiguration memory source,
        T.EconomicsConsent[] memory economics,
        RH.AttestationInput[] memory inputs
    ) public view {
        bytes memory original = data[4].typedState;
        PubH.Bundle memory b = StreamArtistPublicationHydration.decode(original);
        StreamArtistHashes.Environment memory e = StreamArtistHashes.Environment(
            block.chainid, source.registry, source.core, source.mintManager
        );
        if (b.sourceRegistry != source.registry) revert T.InvalidRecord();
        bool publication;
        for (uint256 j; j < b.records.length; ++j) {
            PubH.Row memory row = b.records[j];
            StreamArtistPublicationHydration.validate(e, q, row);
            if (
                keccak256(abi.encode(row.publication))
                    != keccak256(
                        abi.encode(
                            IStreamArtistRecordPublicationOwner(source.owners[4])
                                .publicationAttestation(row.attestation.record.recordHash)
                        )
                    )
            ) revert T.InvalidRecord();
            if (
                row.attestation.input.terms.subjectKind == 7
                    || row.attestation.input.terms.subjectKind == 8
            ) publication = true;
        }
        if (!publication) revert T.UnsupportedProfile();
        // The common checker reads the original attestation rows. Restore the complete
        // tagged publication bytes before returning; commit must carry all evidence.
        data[4].typedState = StreamArtistPublicationHydration.readinessState(b);
        StreamArtistHydrationRecordFacts.check(q, data, source, true, economics, inputs);
        data[4].typedState = original;
    }
}
