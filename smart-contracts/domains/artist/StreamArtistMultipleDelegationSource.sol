// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamArtistMultipleHydrationTypes as MH
} from "../../interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";
import "../../interfaces/stream/artist/IStreamArtistDelegationAuthorityHydration.sol";
import "./StreamArtistMultipleHydrationOperations.sol";
import "./StreamArtistMultipleDelegationCodec.sol";
import "./StreamArtistMultipleDelegationFacts.sol";
import "./StreamArtistHydrationPrepared.sol";
import "./StreamArtistHydrationSourceGuards.sol";

/// @notice A partition of the complete fixed source, never independent subject completeness claims.
library StreamArtistMultipleDelegationSource {
    function prepare(
        D.CoordinatorContext memory x,
        MH.Request memory p,
        T.SuiteConfiguration memory s,
        address prior,
        address coordinator
    ) public view returns (StreamArtistHydrationPrepared.Bundle memory h) {
        h.profile = MD.PROFILE;
        h.prior = prior;
        h.source = s;
        h.sourceCoordinator = coordinator;
        for (uint256 i; i < 7; ++i) {
            h.before_[i] = IStreamArtistOwner(x.suite.owners[i]).ownerStateSnapshotV2();
            if (
                h.before_[i].revision
                        != (i == 2 ? 1 + p.artistIds.length + p.collections.length : 0)
                    || IStreamArtistNativeReceipts(x.suite.owners[i]).artistNativeReceiptCount()
                        != 0
                    || IStreamArtistAuthorityHydrationOwner(x.suite.owners[i])
                            .authorityHydrationCommitment() != 0
            ) revert T.InvalidRecord();
            StreamArtistHydrationSourceGuards._multipleHeader(s.owners[i], p.expectedSource[i]);
        }
        MD.Inventory memory inv = _inventory(s, p);
        IStreamArtistHistory history = IStreamArtistHistory(x.suite.owners[2]);
        for (uint256 i; i < p.artistIds.length; ++i) {
            StreamArtistHydrationSourceGuards._lane(history, prior, 1, p.artistIds[i]);
            (, uint64 count) = IStreamArtistHistory(prior).artistHistoryLane(1, p.artistIds[i]);
            if (count != inv.artists[i].records.length) revert T.InvalidRecord();
        }
        uint256[] memory ids = new uint256[](p.collections.length);
        for (uint256 i; i < p.collections.length; ++i) {
            ids[i] = p.collections[i].collectionId;
            StreamArtistHydrationSourceGuards._lane(history, prior, 2, bytes32(ids[i]));
            (, uint64 count) = IStreamArtistHistory(prior).artistHistoryLane(2, bytes32(ids[i]));
            uint256 expected = 2;
            for (uint256 j; j < inv.receipts[6].length; ++j) {
                if (inv.receipts[6][j].collectionId == ids[i]) ++expected;
            }
            if (count != expected) revert T.InvalidRecord();
        }
        MD.Identities memory identities;
        identities.rows = new MD.IdentityRow[](p.artistIds.length);
        identities.collectionIds = ids;
        for (uint256 i; i < p.artistIds.length; ++i) {
            identities.rows[i].artistId = p.artistIds[i];
            identities.rows[i].records = inv.artists[i].records;
            identities.rows[i].state = IStreamArtistDelegationHydrationOwner(s.owners[2])
                .authorityDelegationHydrationState(inv.artists[i]);
        }
        _nonces(s.owners[2], p, identities);
        MD.Collections memory collections = _collections(s, inv);
        StreamArtistMultipleDelegationFacts.check(s, p, inv, identities, collections);
        for (uint256 i; i < 7; ++i) {
            h.data[i] = StreamArtistMultipleHydrationOperations._replay(s, coordinator, i, p);
            if (i != 2 && p.expectedSource[i].nonceIndexCount != 0) revert T.UnsupportedProfile();
        }
        h.data[0].typedState = abi.encode(MD.BINDING, collections.bindings);
        h.data[2].typedState = abi.encode(MD.IDENTITY, identities);
        h.data[3].typedState = abi.encode(MD.ACCEPTANCE, collections.acceptances);
        h.data[4].typedState = abi.encode(MD.ATTRIBUTION, collections.attributions);
        h.data[6].typedState = abi.encode(MD.CONSENT, collections.consents);
        h.q = inv.collections[0];
    }

    function _inventory(T.SuiteConfiguration memory s, MH.Request memory p)
        private
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
            if ((i == 1 || i == 4 || i == 5) && n != 0) revert T.UnsupportedProfile();
            v.receipts[i] = new H.Receipt[](n);
            for (uint256 j; j < n; ++j) {
                H.Receipt memory r =
                    IStreamArtistNativeReceipts(s.owners[i]).artistNativeReceiptAt(j);
                v.receipts[i][j] = r;
                uint256 a = StreamArtistMultipleHydrationOperations._artist(p.artistIds, r.artistId);
                if (r.recordHash == 0) revert T.InvalidRecord();
                ++artistCounts[a];
                if (i == 2) {
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
                    } else if (i != 6 || r.operation != 16) {
                        revert T.UnsupportedProfile();
                    }
                }
            }
        }
        for (uint256 i; i < 7; ++i) {
            uint256 revision = i == 0 || i == 4
                ? 2 * p.collections.length
                : i == 2
                    ? v.receipts[2].length + p.collections.length + v.receipts[6].length + 1
                    : i == 3 ? p.collections.length : i == 6 ? v.receipts[6].length : 0;
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

    function _nonces(address owner, MH.Request memory p, MD.Identities memory b) private view {
        uint256 n = p.expectedSource[2].nonceIndexCount;
        bool[] memory seen = new bool[](p.artistIds.length);
        uint256 delegateCount;
        uint256 expectedDelegates;
        uint256 total;
        DH.Identity[] memory states = new DH.Identity[](b.rows.length);
        for (uint256 i; i < b.rows.length; ++i) {
            states[i] = StreamArtistDelegationHydrationCodec.identity(b.rows[i].state);
            expectedDelegates += states[i].delegateNonces.length;
        }
        if (n != p.artistIds.length + expectedDelegates) revert T.InvalidRecord();
        for (uint256 i; i < n; ++i) {
            CP.NonceIndex memory index = CP(owner).authorityNonceIndexAt(i);
            if ((index.kind != 1 && index.kind != 2) || index.prefixCount == 0) {
                revert T.UnsupportedProfile();
            }
            total += index.prefixCount;
            if (total > 256) revert T.UnsupportedProfile();
            if (index.kind == 2) {
                uint256 matches;
                for (uint256 a; a < b.rows.length; ++a) {
                    for (uint256 d; d < states[a].delegateNonces.length; ++d) {
                        DH.NonceLane memory lane = states[a].delegateNonces[d];
                        if (lane.key != index.key) continue;
                        ++matches;
                        if (lane.words.length != index.prefixCount) revert T.InvalidRecord();
                        for (uint256 k; k < index.prefixCount; ++k) {
                            (uint256 prefix, uint256[32] memory words, bool exhausted) =
                                CP(owner).authorityNonceWordAt(2, index.key, k);
                            if (
                                keccak256(abi.encode(prefix, words, exhausted))
                                    != keccak256(abi.encode(lane.words[k]))
                            ) revert T.InvalidRecord();
                        }
                    }
                }
                if (matches != 1) revert T.InvalidRecord();
                ++delegateCount;
            } else {
                uint256 a = StreamArtistMultipleHydrationOperations._artist(p.artistIds, index.key);
                if (seen[a]) revert T.InvalidRecord();
                seen[a] = true;
                b.rows[a].nonces = new AH.NonceWord[](index.prefixCount);
                for (uint256 k; k < index.prefixCount; ++k) {
                    (
                        b.rows[a].nonces[k].prefix,
                        b.rows[a].nonces[k].words,
                        b.rows[a].nonces[k].exhausted
                    ) = CP(owner).authorityNonceWordAt(1, index.key, k);
                }
            }
        }
        for (uint256 a; a < seen.length; ++a) {
            if (!seen[a]) revert T.InvalidRecord();
        }
        if (delegateCount != expectedDelegates) revert T.InvalidRecord();
    }

    function _collections(T.SuiteConfiguration memory s, MD.Inventory memory v)
        private
        view
        returns (MD.Collections memory b)
    {
        uint256 n = v.collections.length;
        b.bindings = new MD.BindingRow[](n);
        b.acceptances = new MD.AcceptanceRow[](n);
        b.attributions = new MD.AttributionRow[](n);
        b.consents = new MD.ConsentRow[](n);
        for (uint256 c; c < n; ++c) {
            AH.Query memory q = v.collections[c];
            b.bindings[c] = MD.BindingRow(
                q.collectionId,
                StreamArtistDelegationHydrationCodec.binding(
                    IStreamArtistDelegationHydrationOwner(s.owners[0])
                        .authorityDelegationHydrationState(q)
                )
            );
            b.acceptances[c] = MD.AcceptanceRow(
                q.bindingHash,
                abi.decode(
                    IStreamArtistAuthorityHydrationOwner(s.owners[3]).authorityHydrationState(q),
                    (AH.Acceptance)
                )
            );
            (uint8 state, uint64 generation) = abi.decode(
                IStreamArtistAuthorityHydrationOwner(s.owners[4]).authorityHydrationState(q),
                (uint8, uint64)
            );
            b.attributions[c] = MD.AttributionRow(q.collectionId, state, generation);
            b.consents[c] = MD.ConsentRow(
                q.collectionId,
                q.policies,
                StreamArtistDelegationHydrationCodec.consent(
                    IStreamArtistDelegationHydrationOwner(s.owners[6])
                        .authorityDelegationHydrationState(q)
                )
            );
        }
    }
}
