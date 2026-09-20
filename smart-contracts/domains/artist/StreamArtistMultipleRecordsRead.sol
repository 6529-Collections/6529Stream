// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistMultipleDelegationCodec.sol";
import "./StreamArtistEconomicsHydration.sol";
import "./StreamArtistContentHydration.sol";
import "./StreamArtistMultipleHydrationOperations.sol";
import "../../interfaces/stream/artist/IStreamArtistConsentOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutTransitionOwner.sol";
import {
    StreamArtistMultipleRecordsTypes as MR
} from "../../interfaces/stream/artist/IStreamArtistMultipleRecordsHydration.sol";
import {
    StreamArtistPayoutHydrationTypes as PH
} from "../../interfaces/stream/artist/IStreamArtistPayoutAuthorityHydration.sol";

library StreamArtistMultipleRecordsRead {
    function guard(
        AH.OwnerData memory d,
        bytes32 surface,
        bytes32 scope,
        bytes32 record,
        uint8 kind,
        uint8 status
    ) internal pure {
        uint256 matches;
        for (uint256 i; i < d.origins.length; ++i) {
            if (d.origins[i].surface == surface && d.origins[i].scope == scope) {
                if (
                    d.cells[i].commitment != record || d.cells[i].kind != kind
                        || d.cells[i].status != status
                ) revert T.InvalidRecord();
                ++matches;
            }
        }
        if (matches != 1) revert T.InvalidRecord();
    }

    function payouts(
        T.SuiteConfiguration memory s,
        bytes32[] memory artists,
        H.Receipt[] memory receipts,
        AH.OwnerData memory guards
    ) public view returns (bytes memory) {
        MR.PayoutRow[] memory rows = new MR.PayoutRow[](artists.length);
        uint256 nonempty;
        for (uint256 a; a < artists.length; ++a) {
            rows[a].artistId = artists[a];
            uint256 n;
            for (uint256 j; j < receipts.length; ++j) {
                if (receipts[j].artistId == artists[a]) ++n;
            }
            PH.Bundle memory b;
            b.records = new PH.Row[](n);
            n = 0;
            (
                T.Payout memory current,
                T.Payout memory pending,
                R.ProvisionalAssociation memory assoc
            ) = IStreamArtistPayoutTransitionOwner(s.owners[5]).payoutCandidates(artists[a]);
            R.ProvisionalAssociation memory empty;
            if (
                pending.recordHash != 0 || pending.account != address(0)
                    || keccak256(abi.encode(assoc)) != keccak256(abi.encode(empty))
            ) revert T.UnsupportedProfile();
            bytes32 prior;
            address last;
            for (uint256 j; j < receipts.length; ++j) {
                H.Receipt memory r = receipts[j];
                if (r.artistId != artists[a]) continue;
                T.PayoutDesignation memory terms =
                    IStreamArtistPayoutOwner(s.owners[5]).designationRecord(r.recordHash);
                assoc = IStreamArtistPayoutTransitionOwner(s.owners[5])
                    .payoutDesignationProvisionalAssociation(r.recordHash);
                if (
                    terms.artistId != artists[a] || terms.previousDesignationRecordHash != prior
                        || terms.payoutAccount == address(0) || terms.payoutAccount == last
                        || keccak256(abi.encode(assoc)) != keccak256(abi.encode(empty))
                ) revert T.InvalidRecord();
                b.records[n++] = PH.Row(r.recordHash, terms);
                prior = r.recordHash;
                last = terms.payoutAccount;
            }
            if (current.recordHash != prior || current.account != last) revert T.InvalidRecord();
            b.current = current;
            rows[a].state = b;
            if (n != 0) {
                ++nonempty;
                guard(
                    guards,
                    keccak256("payout_lifecycle.replay.designation_chain"),
                    keccak256(abi.encode(artists[a])),
                    prior,
                    3,
                    1
                );
            }
        }
        if (guards.cells.length != nonempty) revert T.InvalidRecord();
        return abi.encode(MR.PAYOUT, rows);
    }

    function consents(
        T.SuiteConfiguration memory s,
        MD.Inventory memory inv,
        MD.Collections memory collections,
        MR.CollectionWitness[] memory inputs,
        AH.OwnerData memory guards
    ) public view returns (bytes memory) {
        MR.ConsentRow[] memory rows = new MR.ConsentRow[](inv.collections.length);
        for (uint256 c; c < rows.length; ++c) {
            AH.Query memory q = inv.collections[c];
            MR.ConsentRow memory row;
            row.query = q;
            row.delegation = collections.consents[c].state;
            AH.Query memory eq = AH.Query(
                q.artistId, q.collectionId, q.bindingHash, new AH.PolicyKey[](0), new bytes32[](0)
            );
            bytes memory raw = IStreamArtistEconomicsAuthorityHydrationOwner(s.owners[6])
                .authorityEconomicsHydrationState(eq, inputs[c].economics);
            bytes32 schema;
            bytes32[] memory policies;
            (schema, policies, row.economics) = abi.decode(raw, (bytes32, bytes32[], EH.Row[]));
            if (
                schema != StreamArtistEconomicsHydration.SCHEMA || policies.length != 0
                    || row.economics.length != inputs[c].economics.length
            ) revert T.InvalidRecord();
            uint256 rc;
            uint256 cc;
            for (uint256 j; j < inv.receipts[6].length; ++j) {
                H.Receipt memory r = inv.receipts[6][j];
                if (r.collectionId != q.collectionId) continue;
                if (r.operation == 52) ++rc;
                else if (r.operation == 17) ++cc;
            }
            row.ratifications = new T.RatificationRecord[](rc);
            row.content = new IStreamArtistContentRecordsOwner.ConsentRecord[](cc);
            rc = 0;
            cc = 0;
            uint256 ec;
            for (uint256 j; j < inv.receipts[6].length; ++j) {
                H.Receipt memory r = inv.receipts[6][j];
                if (r.collectionId != q.collectionId) continue;
                if (r.operation == 15) {
                    if (ec >= row.economics.length) revert T.InvalidRecord();
                    EH.Row memory er = row.economics[ec];
                    T.EconomicsConsent memory terms = inputs[c].economics[ec++];
                    if (
                        er.recordHash != r.recordHash
                            || keccak256(abi.encode(er.terms)) != keccak256(abi.encode(terms))
                            || (terms.resolver != s.primaryResolver
                                && terms.resolver != s.royaltyResolver)
                            || IStreamArtistConsentOwner(s.owners[6]).economicsRecord(terms)
                                != r.recordHash
                            || IStreamArtistEconomicsEvidence(s.owners[6])
                                    .economicsRecordForBinding(terms, q.artistId, 1, q.bindingHash)
                                != r.recordHash
                            || keccak256(
                                    abi.encode(
                                        IStreamArtistEconomicsEvidence(s.owners[6])
                                            .economicsRecordAssociation(r.recordHash)
                                    )
                                ) != keccak256(abi.encode(er.association))
                    ) revert T.InvalidRecord();
                    guard(
                        guards,
                        keccak256("consent_finality.replay.consent_key"),
                        keccak256(abi.encode(terms)),
                        r.recordHash,
                        1,
                        2
                    );
                } else if (r.operation == 52) {
                    T.RatificationRecord memory rr =
                        IStreamArtistConsentOwner(s.owners[6]).ratificationRecord(r.recordHash);
                    if (
                        rr.recordHash != r.recordHash || rr.metadataContract != s.metadata
                            || rr.contentStateHash == 0
                    ) revert T.InvalidRecord();
                    row.ratifications[rc++] = rr;
                    guard(
                        guards,
                        keccak256("consent_finality.replay.ratification_key"),
                        keccak256(abi.encode(q.collectionId, r.recordHash)),
                        r.recordHash,
                        1,
                        2
                    );
                } else if (r.operation == 17) {
                    IStreamArtistContentRecordsOwner.ConsentRecord memory cr = IStreamArtistContentRecordsOwner(
                            s.owners[6]
                        ).contentConsentRecord(r.recordHash);
                    if (cr.terms.familyId == keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1")) {
                        revert T.UnsupportedProfile();
                    }
                    if (
                        cr.recordHash != r.recordHash || cr.artistId != q.artistId
                            || cr.bindingGeneration != 1 || cr.authorityClass != 1
                            || cr.terms.collectionId != q.collectionId
                            || cr.terms.metadataContract == address(0) || cr.terms.familyId == 0
                            || cr.terms.newStateHash == 0
                    ) revert T.InvalidRecord();
                    row.content[cc++] = cr;
                    guard(
                        guards,
                        keccak256("consent_finality.replay.content_consent_key"),
                        keccak256(
                            abi.encode(keccak256(abi.encode(cr.terms, uint64(1))), r.recordHash)
                        ),
                        r.recordHash,
                        1,
                        2
                    );
                }
            }
            if (ec != row.economics.length) revert T.InvalidRecord();
            T.RatificationRecord memory expected;
            if (rc != 0) expected = row.ratifications[rc - 1];
            if (
                keccak256(abi.encode(expected))
                    != keccak256(
                        abi.encode(
                            IStreamArtistConsentOwner(s.owners[6])
                                .firstReleaseRatification(q.collectionId)
                        )
                    )
            ) revert T.InvalidRecord();
            for (uint256 j; j < cc; ++j) {
                bool last = true;
                for (uint256 k = j + 1; k < cc; ++k) {
                    if (
                        keccak256(abi.encode(row.content[j].terms))
                            == keccak256(abi.encode(row.content[k].terms))
                    ) last = false;
                }
                if (
                    last
                        && keccak256(abi.encode(row.content[j]))
                            != keccak256(
                                abi.encode(
                                    IStreamArtistContentRecordsOwner(s.owners[6])
                                        .contentConsentAt(row.content[j].terms, 1)
                                )
                            )
                ) revert T.InvalidRecord();
            }
            rows[c] = row;
        }
        return abi.encode(MR.CONSENT, rows);
    }
}
