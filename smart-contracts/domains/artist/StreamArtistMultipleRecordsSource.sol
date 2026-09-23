// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistMultipleRecordsInventory.sol";
import "./StreamArtistMultipleDelegationSource.sol";
import "./StreamArtistMultipleRecordsRead.sol";
import "./StreamArtistMultipleRecordsAttestations.sol";
import {
    StreamArtistMultipleRecordsTypes as MR
} from "../../interfaces/stream/artist/IStreamArtistMultipleRecordsHydration.sol";

library StreamArtistMultipleRecordsSource {
    function prepare(
        D.CoordinatorContext memory x,
        MR.Request memory p,
        T.SuiteConfiguration memory s,
        address prior,
        address coordinator
    ) public view returns (StreamArtistHydrationPrepared.Bundle memory h) {
        MH.Request memory a = p.authority;
        if (p.witnesses.length != a.collections.length) revert T.InvalidRecord();
        for (uint256 c; c < p.witnesses.length; ++c) {
            if (
                p.witnesses[c].collectionId != a.collections[c].collectionId
                    || p.witnesses[c].economics.length > 128
                    || p.witnesses[c].attestations.length > 128
            ) revert T.InvalidRecord();
        }
        h.profile = MR.PROFILE;
        h.prior = prior;
        h.source = s;
        h.sourceCoordinator = coordinator;
        for (uint256 i; i < 7; ++i) {
            h.before_[i] = IStreamArtistOwner(x.suite.owners[i]).ownerStateSnapshotV2();
            if (
                h.before_[i].revision
                        != (i == 2 ? 1 + a.artistIds.length + a.collections.length : 0)
                    || IStreamArtistNativeReceipts(x.suite.owners[i]).artistNativeReceiptCount()
                        != 0
                    || IStreamArtistAuthorityHydrationOwner(x.suite.owners[i])
                            .authorityHydrationCommitment() != 0
            ) revert T.InvalidRecord();
            StreamArtistHydrationSourceGuards._multipleHeader(s.owners[i], a.expectedSource[i]);
        }
        MD.Inventory memory inv = StreamArtistMultipleRecordsInventory.collect(s, a);
        IStreamArtistHistory history = IStreamArtistHistory(x.suite.owners[2]);
        for (uint256 k; k < a.artistIds.length; ++k) {
            StreamArtistHydrationSourceGuards._lane(history, prior, 1, a.artistIds[k]);
            (, uint64 count) = IStreamArtistHistory(prior).artistHistoryLane(1, a.artistIds[k]);
            if (count != inv.artists[k].records.length) revert T.InvalidRecord();
        }
        uint256[] memory ids = new uint256[](a.collections.length);
        for (uint256 c; c < ids.length; ++c) {
            ids[c] = a.collections[c].collectionId;
            StreamArtistHydrationSourceGuards._lane(history, prior, 2, bytes32(ids[c]));
            (, uint64 count) = IStreamArtistHistory(prior).artistHistoryLane(2, bytes32(ids[c]));
            uint256 expected;
            for (uint256 i; i < 7; ++i) {
                for (uint256 j; j < inv.receipts[i].length; ++j) {
                    if (inv.receipts[i][j].collectionId == ids[c]) ++expected;
                }
            }
            if (count != expected) revert T.InvalidRecord();
        }
        MD.Identities memory identities;
        identities.rows = new MD.IdentityRow[](a.artistIds.length);
        identities.collectionIds = ids;
        for (uint256 j; j < a.artistIds.length; ++j) {
            identities.rows[j].artistId = a.artistIds[j];
            identities.rows[j].records = inv.artists[j].records;
            identities.rows[j].state = IStreamArtistDelegationHydrationOwner(s.owners[2])
                .authorityDelegationHydrationState(inv.artists[j]);
        }
        StreamArtistMultipleDelegationSource._nonces(s.owners[2], a, identities);
        MD.Collections memory collections =
            StreamArtistMultipleDelegationSource._collections(s, inv);
        // Projections are permitted only after the complete inventory above. All policy/sale
        // grant uses across every included collection are still reconciled by the old proof.
        uint256 n;
        for (uint256 j; j < inv.receipts[6].length; ++j) {
            if (inv.receipts[6][j].operation == 14 || inv.receipts[6][j].operation == 16) ++n;
        }
        H.Receipt[] memory projected = new H.Receipt[](n);
        n = 0;
        for (uint256 j; j < inv.receipts[6].length; ++j) {
            if (inv.receipts[6][j].operation == 14 || inv.receipts[6][j].operation == 16) {
                projected[n++] = inv.receipts[6][j];
            }
        }
        H.Receipt[][7] memory checkReceipts;
        for (uint256 i; i < 7; ++i) {
            checkReceipts[i] = i == 6 ? projected : inv.receipts[i];
        }
        MD.Inventory memory checks = MD.Inventory(inv.artists, inv.collections, checkReceipts);
        StreamArtistMultipleDelegationFacts.check(s, a, checks, identities, collections);
        for (uint256 i; i < 7; ++i) {
            h.data[i] = StreamArtistMultipleHydrationOperations._replay(s, coordinator, i, a);
            if (i != 2 && a.expectedSource[i].nonceIndexCount != 0) revert T.UnsupportedProfile();
        }
        h.data[0].typedState = abi.encode(MD.BINDING, collections.bindings);
        h.data[2].typedState = abi.encode(MD.IDENTITY, identities);
        h.data[3].typedState = abi.encode(MD.ACCEPTANCE, collections.acceptances);
        h.data[5].typedState =
            StreamArtistMultipleRecordsRead.payouts(s, a.artistIds, inv.receipts[5], h.data[5]);
        h.data[6].typedState =
            StreamArtistMultipleRecordsRead.consents(s, inv, collections, p.witnesses, h.data[6]);
        h.data[4].typedState =
            StreamArtistMultipleRecordsAttestations.collect(s, inv, p.witnesses, identities);
        h.q = inv.collections[0];
    }
}
