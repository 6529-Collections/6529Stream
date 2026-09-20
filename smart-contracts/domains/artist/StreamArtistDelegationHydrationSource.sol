// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistHydrationCommit.sol";
import "./StreamArtistDelegationHydrationCodec.sol";
import "../../interfaces/stream/artist/IStreamArtistDelegationAuthorityHydration.sol";

/// @notice Complete source collection; no mutation is reachable before all seven inventories pass.
library StreamArtistDelegationHydrationSource {
    function prepare(D.CoordinatorContext memory x, AH.Request memory p)
        public
        view
        returns (StreamArtistHydrationPrepared.Bundle memory h)
    {
        if (
            p.artistId == 0 || p.collectionId == 0 || p.bindingIndex != 0 || p.policies.length > 128
        ) revert T.UnsupportedProfile();
        IStreamArtistHistory history = IStreamArtistHistory(x.suite.owners[2]);
        if (history.importedHistoryBindingCount() != 1) revert T.InvalidBinding();
        (h.prior,,,) = history.importedHistoryBinding(0);
        (, bytes32 pin,) = history.artistHistoryPredecessorBinding(h.prior);
        StreamArtistHistoryProof.predecessor(
            x.suite.core,
            x.suite.registry,
            h.prior,
            pin,
            StreamArtistHistoryProof.cap(x.suite.registry)
        );
        (bool sealed_, address successor,) = IStreamArtistHistory(h.prior).artistRegistryCutover();
        if (
            !sealed_ || successor != x.suite.registry
                || IStreamArtistHistory(h.prior).importedHistoryBindingCount() != 0
        ) revert T.InvalidBinding();
        StreamArtistHydrationSourceGuards._lane(history, h.prior, 1, p.artistId);
        StreamArtistHydrationSourceGuards._lane(history, h.prior, 2, bytes32(p.collectionId));
        h.sourceCoordinator = IStreamArtistIngressBinding(h.prior).operationCoordinator();
        h.source = IStreamArtistAuthorityHydrationCoordinator(h.sourceCoordinator)
            .authorityHydrationSuite();
        StreamArtistHydrationSourceGuards._suite(x.suite, h.source, h.prior, h.sourceCoordinator);
        h.profile = DH.PROFILE;
        h.q = _inventory(x.suite, h, p);
        for (uint256 i; i < 7; ++i) {
            h.data[i] = _guards(h.source, h.sourceCoordinator, i, p);
            h.data[i].typedState = i == 0 || i == 2 || i == 6
                ? IStreamArtistDelegationHydrationOwner(h.source.owners[i])
                    .authorityDelegationHydrationState(h.q)
                : IStreamArtistAuthorityHydrationOwner(h.source.owners[i])
                    .authorityHydrationState(h.q);
        }
    }

    function _inventory(
        T.SuiteConfiguration memory next,
        StreamArtistHydrationPrepared.Bundle memory h,
        AH.Request memory p
    ) private view returns (AH.Query memory q) {
        q.artistId = p.artistId;
        q.collectionId = p.collectionId;
        q.policies = p.policies;
        uint256[7] memory counts;
        uint256 total;
        for (uint256 i; i < 7; ++i) {
            h.before_[i] = IStreamArtistOwner(next.owners[i]).ownerStateSnapshotV2();
            if (
                h.before_[i].revision != (i == 2 ? 3 : 0)
                    || IStreamArtistNativeReceipts(next.owners[i]).artistNativeReceiptCount() != 0
                    || IStreamArtistAuthorityHydrationOwner(next.owners[i])
                            .authorityHydrationCommitment() != 0
            ) revert T.InvalidRecord();
            StreamArtistHydrationSourceGuards._multipleHeader(
                h.source.owners[i], p.expectedSource[i]
            );
            counts[i] = IStreamArtistNativeReceipts(h.source.owners[i]).artistNativeReceiptCount();
            if (counts[i] > 128) revert T.UnsupportedProfile();
            if ((i == 0 || i == 3) && counts[i] != 1) revert T.UnsupportedProfile();
            if ((i == 1 || i == 4 || i == 5) && counts[i] != 0) revert T.UnsupportedProfile();
            if (i == 2 && counts[i] == 0) revert T.UnsupportedProfile();
            total += counts[i];
        }
        q.records = new bytes32[](total);
        uint256 index;
        uint256 policies;
        uint256 collectionCount;
        for (uint256 i; i < 7; ++i) {
            for (uint256 j; j < counts[i]; ++j) {
                H.Receipt memory r =
                    IStreamArtistNativeReceipts(h.source.owners[i]).artistNativeReceiptAt(j);
                bool allowed = i == 0
                    ? r.operation == 1
                    : i == 3
                        ? r.operation == 2
                        : i == 2
                            ? (j == 0
                                    ? r.operation == 1 && r.recordHash == q.artistId
                                    : r.operation == 25 || r.operation == 26 || r.operation == 27
                                        || r.operation == 54)
                            : i == 6 && (r.operation == 14 || r.operation == 16);
                if (
                    !allowed || r.artistId != q.artistId
                        || r.collectionId != (i == 2 ? 0 : q.collectionId) || r.recordHash == 0
                ) revert T.UnsupportedProfile();
                q.records[index++] = r.recordHash;
                if (i == 0) q.bindingHash = r.recordHash;
                if (i == 6 && r.operation == 14) ++policies;
                if (r.collectionId != 0) ++collectionCount;
            }
            uint256 revision = i == 0 || i == 4
                ? 2
                : i == 2 ? 2 + counts[2] + counts[6] : i == 3 ? 1 : i == 6 ? counts[6] : 0;
            if (p.expectedSource[i].ownerState.revision != revision) revert T.UnsupportedProfile();
        }
        if (policies != q.policies.length) revert T.InvalidRecord();
        for (uint256 i; i < policies; ++i) {
            if (q.policies[i].phaseId == 0 || q.policies[i].policyHash == 0) {
                revert T.InvalidRecord();
            }
            for (uint256 j; j < i; ++j) {
                if (
                    q.policies[i].phaseId == q.policies[j].phaseId
                        && q.policies[i].policyHash == q.policies[j].policyHash
                ) revert T.InvalidRecord();
            }
        }
        (, uint64 ac) = IStreamArtistHistory(h.prior).artistHistoryLane(1, q.artistId);
        (, uint64 cc) = IStreamArtistHistory(h.prior).artistHistoryLane(2, bytes32(q.collectionId));
        if (ac != total || cc != collectionCount) revert T.InvalidRecord();
    }

    function _guards(
        T.SuiteConfiguration memory s,
        address coordinator,
        uint256 i,
        AH.Request memory p
    ) private view returns (AH.OwnerData memory d) {
        CP.Checkpoint memory header = p.expectedSource[i];
        d.origins = p.replayOrigins[i];
        if (d.origins.length != header.replayCount) revert T.InvalidRecord();
        d.sourceKeys = new bytes32[](header.replayCount);
        d.cells = new T.ReplayCell[](header.replayCount);
        for (uint256 j; j < header.replayCount; ++j) {
            (bytes32 key, T.ReplayCell memory cell) = CP(s.owners[i]).authorityReplayAt(j);
            if (
                key
                        != keccak256(
                            abi.encode(
                                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                                block.chainid,
                                s.registry,
                                coordinator,
                                s.archive,
                                s.owners[i],
                                header.ownerState.domainId,
                                d.origins[j].surface,
                                d.origins[j].scope
                            )
                        ) || cell.status == 0
                    || keccak256(abi.encode(cell))
                        != keccak256(abi.encode(IStreamArtistOwner(s.owners[i]).replayCell(key)))
            ) revert T.InvalidRecord();
            d.sourceKeys[j] = key;
            d.cells[j] = cell;
        }
        if (i != 2) {
            if (header.nonceIndexCount != 0) revert T.UnsupportedProfile();
            return d;
        }
        bool found;
        uint256 prefixes;
        for (uint256 j; j < header.nonceIndexCount; ++j) {
            CP.NonceIndex memory n = CP(s.owners[i]).authorityNonceIndexAt(j);
            prefixes += n.prefixCount;
            if ((n.kind != 1 && n.kind != 2) || n.prefixCount == 0 || prefixes > 256) {
                revert T.UnsupportedProfile();
            }
            if (n.kind == 2) continue;
            if (found || n.key != p.artistId) revert T.UnsupportedProfile();
            found = true;
            d.nonces = new AH.NonceWord[](n.prefixCount);
            for (uint256 k; k < n.prefixCount; ++k) {
                (d.nonces[k].prefix, d.nonces[k].words, d.nonces[k].exhausted) =
                    CP(s.owners[i]).authorityNonceWordAt(1, n.key, k);
            }
        }
        if (!found) revert T.InvalidRecord();
    }
}
