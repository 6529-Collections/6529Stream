// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import "./StreamArtistAttestationHydration.sol";
import "./StreamArtistContentHydration.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistConsentOwner.sol";
import {
    StreamArtistReadinessHydrationTypes as RH
} from "../../interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

library StreamArtistReadinessHydrationFacts {
    function check(
        AH.Query memory q,
        AH.OwnerData[7] memory data,
        T.SuiteConfiguration memory source,
        RH.AttestationInput[] memory inputs
    ) public view {
        RH.AttributionBundle memory b = StreamArtistAttestationHydration.decode(data[4].typedState);
        AH.Identity memory identity = abi.decode(data[2].typedState, (AH.Identity));
        if (b.sourceRegistry != source.registry || b.records.length != inputs.length) {
            revert T.InvalidRecord();
        }
        for (uint256 j; j < b.records.length; ++j) {
            RH.AttestationRow memory r = b.records[j];
            bytes32 record = r.record.recordHash;
            if (
                keccak256(abi.encode(inputs[j])) != keccak256(abi.encode(r.input))
                    || r.record.signer != identity.item.authorityAddress
                    || record
                        != IStreamArtistNativeReceipts(source.owners[4])
                        .artistNativeReceiptAt(j)
                        .recordHash
                    || keccak256(abi.encode(r.record))
                        != keccak256(
                            abi.encode(
                                IStreamArtistAttributionOwner(source.owners[4])
                                    .attestationRecord(record)
                            )
                        )
                    || r.authorityClass
                        != IStreamArtistReadinessAttributionOwner(source.owners[4])
                            .attestationAuthorityClass(record)
                    || keccak256(r.statement)
                        != keccak256(
                            IStreamArtistAttributionOwner(source.owners[4])
                                .statementBytes(r.record.statementHash)
                        )
                    || keccak256(abi.encode(r.association))
                        != keccak256(
                            abi.encode(
                                IStreamArtistAuthenticatedAttestationOwner(source.owners[4])
                                    .attestationAssociation(record)
                            )
                        )
            ) revert T.InvalidRecord();
            bool last = true;
            bytes32 key = keccak256(abi.encode(r.input.terms.subjectKind, r.input.terms.subjectId));
            for (uint256 k = j + 1; k < b.records.length; ++k) {
                if (
                    keccak256(
                            abi.encode(
                                b.records[k].input.terms.subjectKind,
                                b.records[k].input.terms.subjectId
                            )
                        ) == key
                ) last = false;
            }
            if (
                last
                    && keccak256(abi.encode(r.record))
                        != keccak256(
                            abi.encode(
                                IStreamArtistAttributionOwner(source.owners[4])
                                    .attestation(
                                        q.collectionId,
                                        r.input.terms.subjectKind,
                                        r.input.terms.subjectId
                                    )
                            )
                        )
            ) revert T.InvalidRecord();
        }
        RH.ConsentBundle memory c = StreamArtistContentHydration.decode(data[6].typedState);
        uint256 rc;
        uint256 cc;
        uint256 count = IStreamArtistNativeReceipts(source.owners[6]).artistNativeReceiptCount();
        for (uint256 j; j < count; ++j) {
            H.Receipt memory n =
                IStreamArtistNativeReceipts(source.owners[6]).artistNativeReceiptAt(j);
            if (n.operation == 52) {
                if (rc >= c.ratifications.length) revert T.InvalidRecord();
                T.RatificationRecord memory r = c.ratifications[rc++];
                if (
                    r.recordHash != n.recordHash || r.metadataContract != source.metadata
                        || keccak256(abi.encode(r))
                            != keccak256(
                                abi.encode(
                                    IStreamArtistConsentOwner(source.owners[6])
                                        .ratificationRecord(n.recordHash)
                                )
                            )
                ) revert T.InvalidRecord();
                _guard(
                    data[6],
                    keccak256("consent_finality.replay.ratification_key"),
                    keccak256(abi.encode(q.collectionId, n.recordHash)),
                    n.recordHash
                );
            } else if (n.operation == 17) {
                if (cc >= c.consents.length) revert T.InvalidRecord();
                IStreamArtistContentRecordsOwner.ConsentRecord memory r = c.consents[cc++];
                if (
                    r.recordHash != n.recordHash
                        || keccak256(abi.encode(r))
                            != keccak256(
                                abi.encode(
                                    IStreamArtistContentRecordsOwner(source.owners[6])
                                        .contentConsentRecord(n.recordHash)
                                )
                            )
                ) revert T.InvalidRecord();
                _guard(
                    data[6],
                    keccak256("consent_finality.replay.content_consent_key"),
                    keccak256(abi.encode(keccak256(abi.encode(r.terms, uint64(1))), n.recordHash)),
                    n.recordHash
                );
            }
        }
        if (
            rc != c.ratifications.length || cc != c.consents.length
                || keccak256(abi.encode(c.ratifications[rc - 1]))
                    != keccak256(
                        abi.encode(
                            IStreamArtistConsentOwner(source.owners[6])
                                .firstReleaseRatification(q.collectionId)
                        )
                    )
        ) revert T.InvalidRecord();
        for (uint256 j; j < cc; ++j) {
            bool last = true;
            bytes32 key = keccak256(abi.encode(c.consents[j].terms));
            for (uint256 k = j + 1; k < cc; ++k) {
                if (keccak256(abi.encode(c.consents[k].terms)) == key) last = false;
            }
            if (
                last
                    && keccak256(abi.encode(c.consents[j]))
                        != keccak256(
                            abi.encode(
                                IStreamArtistContentRecordsOwner(source.owners[6])
                                    .contentConsentAt(c.consents[j].terms, 1)
                            )
                        )
            ) revert T.InvalidRecord();
        }
    }

    function _guard(AH.OwnerData memory data, bytes32 surface, bytes32 scope, bytes32 record)
        private
        pure
    {
        bool found;
        for (uint256 j; j < data.origins.length; ++j) {
            if (data.origins[j].surface == surface && data.origins[j].scope == scope) {
                if (
                    data.cells[j].kind != 1 || data.cells[j].status != 2
                        || data.cells[j].commitment != record
                ) revert T.InvalidRecord();
                found = true;
            }
        }
        if (!found) revert T.InvalidRecord();
    }
}
