// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistMultipleHydrationOperations.sol";
import "./StreamArtistMultipleDelegationCodec.sol";

/// @notice Exhaustive global journal partition before any filtered export or destination call.
library StreamArtistMultipleRecordsInventory {
    function collect(T.SuiteConfiguration memory s, MH.Request memory p)
        public
        view
        returns (MD.Inventory memory v)
    {
        v.artists = new AH.Query[](p.artistIds.length);
        v.collections = new AH.Query[](p.collections.length);
        uint256 policies;
        for (uint256 i; i < p.artistIds.length; ++i) {
            v.artists[i].artistId = p.artistIds[i];
        }
        for (uint256 i; i < p.collections.length; ++i) {
            v.collections[i].artistId = p.collections[i].artistId;
            v.collections[i].collectionId = p.collections[i].collectionId;
            v.collections[i].policies = p.collections[i].policies;
            policies += p.collections[i].policies.length;
        }
        if (policies > 128) revert T.UnsupportedProfile();
        uint256[] memory artistCounts = new uint256[](p.artistIds.length);
        bool[] memory registered = new bool[](p.artistIds.length);
        bool[] memory accepted = new bool[](p.collections.length);
        uint256[] memory policyCounts = new uint256[](p.collections.length);
        uint256 registrations;
        for (uint256 i; i < 7; ++i) {
            uint256 n = IStreamArtistNativeReceipts(s.owners[i]).artistNativeReceiptCount();
            if (n > 128) revert T.UnsupportedProfile();
            if ((i == 0 || i == 3) && n != p.collections.length) revert T.UnsupportedProfile();
            if (i == 1 && n != 0) revert T.UnsupportedProfile();
            v.receipts[i] = new H.Receipt[](n);
            for (uint256 j; j < n; ++j) {
                H.Receipt memory r =
                    IStreamArtistNativeReceipts(s.owners[i]).artistNativeReceiptAt(j);
                v.receipts[i][j] = r;
                uint256 a = StreamArtistMultipleHydrationOperations._artist(p.artistIds, r.artistId);
                if (r.recordHash == 0) revert T.InvalidRecord();
                ++artistCounts[a];
                if (i == 5) {
                    if (r.operation != 18 || r.collectionId != 0) revert T.UnsupportedProfile();
                } else if (i == 2) {
                    if (r.collectionId != 0) revert T.UnsupportedProfile();
                    if (r.operation == 1) {
                        if (registered[a] || r.recordHash != r.artistId) revert T.InvalidRecord();
                        registered[a] = true;
                        ++registrations;
                    } else if (
                        !registered[a]
                            || (r.operation != 25
                                && r.operation != 26
                                && r.operation != 27
                                && r.operation != 54)
                    ) {
                        revert T.UnsupportedProfile();
                    }
                } else {
                    uint256 c = StreamArtistMultipleHydrationOperations._collection(
                        p.collections, r.collectionId
                    );
                    if (p.collections[c].artistId != r.artistId) revert T.InvalidRecord();
                    if (i == 0 && r.operation == 1) {
                        if (v.collections[c].bindingHash != 0) revert T.InvalidRecord();
                        v.collections[c].bindingHash = r.recordHash;
                    } else if (i == 3 && r.operation == 2) {
                        if (accepted[c]) revert T.InvalidRecord();
                        accepted[c] = true;
                    } else if (i == 6 && r.operation == 14) {
                        ++policyCounts[c];
                    } else if (
                        !(i == 4 && r.operation == 24)
                            && !(i == 6
                                && (r.operation == 15
                                    || r.operation == 16
                                    || r.operation == 17
                                    || r.operation == 52))
                    ) {
                        revert T.UnsupportedProfile();
                    }
                }
            }
        }
        for (uint256 i; i < 7; ++i) {
            uint256 revision = i == 0
                ? 2 * p.collections.length
                : i == 2
                    ? v.receipts[2].length + p.collections.length + v.receipts[4].length
                        + v.receipts[5].length + v.receipts[6].length + 1
                    : i == 3
                        ? p.collections.length
                        : i == 4
                            ? 2 * p.collections.length + v.receipts[4].length
                            : i == 5 || i == 6 ? v.receipts[i].length : 0;
            if (p.expectedSource[i].ownerState.revision != revision) revert T.UnsupportedProfile();
        }
        if (registrations != p.artistIds.length) revert T.UnsupportedProfile();
        for (uint256 a; a < p.artistIds.length; ++a) {
            if (!registered[a]) revert T.InvalidRecord();
            v.artists[a].records = new bytes32[](artistCounts[a]);
            uint256 k;
            for (uint256 i; i < 7; ++i) {
                for (uint256 j; j < v.receipts[i].length; ++j) {
                    if (v.receipts[i][j].artistId == p.artistIds[a]) {
                        v.artists[a].records[k++] = v.receipts[i][j].recordHash;
                    }
                }
            }
        }
        for (uint256 c; c < p.collections.length; ++c) {
            if (
                !accepted[c] || v.collections[c].bindingHash == 0
                    || policyCounts[c] != p.collections[c].policies.length
            ) revert T.InvalidRecord();
        }
    }
}
