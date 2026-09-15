// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistHydrationSourceGuards.sol";

/// @notice Fixed complete native receipt/revision inventory. The original source order and limits remain.
library StreamArtistHydrationSourceInventory {
    function collect(
        T.SuiteConfiguration memory next,
        T.SuiteConfiguration memory source,
        AH.Request memory p,
        bool includePayout,
        uint256 economicsCount,
        uint256 attestationCount,
        bool findings
    )
        public
        view
        returns (
            AH.Query memory q,
            T.Snapshot[7] memory before_,
            uint256 artistCount,
            uint256 collectionCount
        )
    {
        bool readiness = attestationCount != 0;
        q.artistId = p.artistId;
        q.collectionId = p.collectionId;
        q.policies = p.policies;
        uint256 total;
        uint256 revocations;
        uint256 payoutCount;
        uint256 contentCount;
        for (uint256 i; i < 7; ++i) {
            before_[i] = IStreamArtistOwner(next.owners[i]).ownerStateSnapshotV2();
            if (
                before_[i].revision != (i == 2 ? 3 : 0)
                    || IStreamArtistNativeReceipts(next.owners[i]).artistNativeReceiptCount() != 0
                    || IStreamArtistAuthorityHydrationOwner(next.owners[i])
                            .authorityHydrationCommitment() != 0
            ) revert T.InvalidRecord();
            StreamArtistHydrationSourceGuards._header(source.owners[i], p.expectedSource[i]);
            uint256 count = IStreamArtistNativeReceipts(source.owners[i]).artistNativeReceiptCount();
            if (count > 128) revert T.UnsupportedProfile();
            total += count;
            if (i == 0) {
                if (count != 1) revert T.UnsupportedProfile();
                q.bindingHash =
                IStreamArtistNativeReceipts(source.owners[i]).artistNativeReceiptAt(0).recordHash;
            } else if (i == 2) {
                if (count == 0) revert T.UnsupportedProfile();
                revocations = count - 1;
            } else if (i == 3) {
                if (count != 1) revert T.UnsupportedProfile();
            } else if (i == 4 && readiness) {
                if (count != attestationCount) revert T.InvalidRecord();
            } else if (i == 5 && includePayout) {
                if (count == 0) revert T.UnsupportedProfile();
                payoutCount = count;
            } else if (i == 6) {
                if (readiness) {
                    if (count <= p.policies.length + economicsCount) revert T.InvalidRecord();
                    contentCount = count - p.policies.length - economicsCount;
                } else if (count != p.policies.length + economicsCount) {
                    revert T.InvalidRecord();
                }
            } else if (count != 0) {
                revert T.UnsupportedProfile();
            }
        }
        q.records = new bytes32[](total);
        uint256 used;
        for (uint256 i; i < 7; ++i) {
            uint256 count = IStreamArtistNativeReceipts(source.owners[i]).artistNativeReceiptCount();
            for (uint256 j; j < count; ++j) {
                H.Receipt memory r =
                    IStreamArtistNativeReceipts(source.owners[i]).artistNativeReceiptAt(j);
                uint16 op = i == 0 ? 1 : i == 2 ? (j == 0 ? 1 : 54) : i == 3 ? 2 : i == 5 ? 18 : 14;
                if (findings && i == 2 && j != 0 && r.operation == 23) op = 23;
                if (i == 6 && economicsCount != 0 && r.operation == 15) op = 15;
                if (readiness && i == 4) op = 24;
                if (readiness && i == 6 && (r.operation == 52 || r.operation == 17)) {
                    op = r.operation;
                }
                if (
                    r.operation != op || r.artistId != p.artistId
                        || r.collectionId != ((i == 2 && op != 23) || i == 5 ? 0 : p.collectionId)
                        || r.recordHash == 0 || (i == 2 && j == 0 && r.recordHash != p.artistId)
                ) revert T.UnsupportedProfile();
                q.records[used++] = r.recordHash;
                ++artistCount;
                if (r.collectionId != 0) ++collectionCount;
            }
            uint64 expectedRevision = i == 0
                ? 2
                : i == 2
                    ? uint64(
                        3 + p.policies.length + economicsCount + revocations + payoutCount
                            + contentCount + attestationCount
                    )
                    : i == 3
                        ? 1
                        : i == 4
                            ? uint64(2 + attestationCount)
                            : i == 5
                                ? uint64(payoutCount)
                                : i == 6
                                    ? uint64(p.policies.length + economicsCount + contentCount)
                                    : 0;
            if (p.expectedSource[i].ownerState.revision != expectedRevision) {
                revert T.UnsupportedProfile();
            }
        }
    }
}
