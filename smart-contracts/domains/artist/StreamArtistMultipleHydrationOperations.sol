// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistHydrationCommit.sol";
import "./StreamArtistMultipleHydrationCodec.sol";
import "./StreamArtistMultipleDelegationSelection.sol";
import {
    StreamArtistMultipleHydrationTypes as MH
} from "../../interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";

/// @notice Whole-source multiplicity profile. Every journal/index is visited before any owner write.
library StreamArtistMultipleHydrationOperations {
    struct Inventory {
        AH.Query[] artists;
        AH.Query[] collections;
        H.Receipt[][7] receipts;
        uint256 policies;
        uint256 revocations;
    }
    event MultipleArtistAuthorityHydrated(
        address indexed predecessor,
        bytes32 indexed commitment,
        bytes32[] artistIds,
        uint256[] collectionIds
    );

    function hydrate(D.CoordinatorContext memory x, address actor, MH.Request memory p)
        public
        returns (bytes32 value)
    {
        _selectors(p);
        IStreamArtistHistory history = IStreamArtistHistory(x.suite.owners[2]);
        if (history.importedHistoryBindingCount() != 1) revert T.InvalidBinding();
        (address prior,,,) = history.importedHistoryBinding(0);
        (, bytes32 pin,) = history.artistHistoryPredecessorBinding(prior);
        StreamArtistHistoryProof.predecessor(
            x.suite.core,
            x.suite.registry,
            prior,
            pin,
            StreamArtistHistoryProof.cap(x.suite.registry)
        );
        (bool sealed_, address successor,) = IStreamArtistHistory(prior).artistRegistryCutover();
        if (
            !sealed_ || successor != x.suite.registry
                || IStreamArtistHistory(prior).importedHistoryBindingCount() != 0
        ) revert T.InvalidBinding();
        address coordinator = IStreamArtistIngressBinding(prior).operationCoordinator();
        T.SuiteConfiguration memory source =
            IStreamArtistAuthorityHydrationCoordinator(coordinator).authorityHydrationSuite();
        StreamArtistHydrationSourceGuards._suite(x.suite, source, prior, coordinator);
        if (StreamArtistMultipleDelegationSelection.required(source)) {
            return StreamArtistMultipleDelegationSelection.hydrate(
                x, actor, p, source, prior, coordinator
            );
        }
        StreamArtistHydrationPrepared.Bundle memory h;
        h.profile = MH.PROFILE;
        h.prior = prior;
        h.sourceCoordinator = coordinator;
        h.source = source;
        for (uint256 i; i < 7; ++i) {
            h.before_[i] = IStreamArtistOwner(x.suite.owners[i]).ownerStateSnapshotV2();
            if (
                h.before_[i].revision
                        != (i == 2 ? 1 + p.artistIds.length + p.collections.length : 0)
                    || IStreamArtistNativeReceipts(x.suite.owners[i]).artistNativeReceiptCount()
                        != 0
                    || IStreamArtistAuthorityHydrationOwner(x.suite.owners[i])
                            .authorityHydrationCommitment() != 0
            ) {
                revert T.InvalidRecord();
            }
            StreamArtistHydrationSourceGuards._multipleHeader(source.owners[i], p.expectedSource[i]);
        }
        Inventory memory inv = _inventory(source, p);
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
            if (count != 2 + p.collections[i].policies.length) revert T.InvalidRecord();
        }
        h.data = _data(source, coordinator, p, inv, ids);
        h.q = inv.collections[0];
        AH.Request memory base;
        base.artistId = h.q.artistId;
        base.collectionId = h.q.collectionId;
        base.policies = h.q.policies;
        base.expectedSource = p.expectedSource;
        base.replayOrigins = p.replayOrigins;
        value = StreamArtistHydrationCommit.execute(x, actor, base, h);
        emit MultipleArtistAuthorityHydrated(prior, value, p.artistIds, ids);
    }

    function _selectors(MH.Request memory p) internal pure {
        if (
            p.bindingIndex != 0 || p.artistIds.length == 0 || p.artistIds.length > 128
                || p.collections.length == 0 || p.collections.length > 128
        ) revert T.UnsupportedProfile();
        for (uint256 i; i < p.artistIds.length; ++i) {
            if (p.artistIds[i] == 0 || (i != 0 && p.artistIds[i] <= p.artistIds[i - 1])) {
                revert T.InvalidRecord();
            }
            bool present;
            for (uint256 j; j < p.collections.length; ++j) {
                if (p.collections[j].artistId == p.artistIds[i]) present = true;
            }
            if (!present) revert T.InvalidRecord();
        }
        for (uint256 i; i < p.collections.length; ++i) {
            MH.Collection memory c = p.collections[i];
            if (
                c.collectionId == 0
                    || (i != 0 && c.collectionId <= p.collections[i - 1].collectionId)
                    || c.policies.length > 128
            ) revert T.InvalidRecord();
            _artist(p.artistIds, c.artistId);
            for (uint256 j; j < c.policies.length; ++j) {
                if (c.policies[j].phaseId == 0 || c.policies[j].policyHash == 0) {
                    revert T.InvalidRecord();
                }
                for (uint256 k; k < j; ++k) {
                    if (
                        c.policies[k].phaseId == c.policies[j].phaseId
                            && c.policies[k].policyHash == c.policies[j].policyHash
                    ) {
                        revert T.InvalidRecord();
                    }
                }
            }
        }
    }

    function _inventory(T.SuiteConfiguration memory s, MH.Request memory p)
        private
        view
        returns (Inventory memory v)
    {
        v.artists = new AH.Query[](p.artistIds.length);
        v.collections = new AH.Query[](p.collections.length);
        for (uint256 j; j < p.artistIds.length; ++j) {
            v.artists[j].artistId = p.artistIds[j];
        }
        for (uint256 j; j < p.collections.length; ++j) {
            v.collections[j].artistId = p.collections[j].artistId;
            v.collections[j].collectionId = p.collections[j].collectionId;
            v.collections[j].policies = p.collections[j].policies;
            v.policies += p.collections[j].policies.length;
        }
        if (v.policies > 128) revert T.UnsupportedProfile();
        uint256[] memory artistCounts = new uint256[](p.artistIds.length);
        bool[] memory registered = new bool[](p.artistIds.length);
        bool[] memory accepted = new bool[](p.collections.length);
        uint256[] memory policies = new uint256[](p.collections.length);
        uint256 registrations;
        for (uint256 i; i < 7; ++i) {
            uint256 n = IStreamArtistNativeReceipts(s.owners[i]).artistNativeReceiptCount();
            if (n > 128) revert T.UnsupportedProfile();
            v.receipts[i] = new H.Receipt[](n);
            if ((i == 0 || i == 3) && n != p.collections.length) revert T.UnsupportedProfile();
            if ((i == 1 || i == 4 || i == 5) && n != 0) revert T.UnsupportedProfile();
            if (i == 6 && n != v.policies) revert T.InvalidRecord();
            for (uint256 j; j < n; ++j) {
                H.Receipt memory r =
                    IStreamArtistNativeReceipts(s.owners[i]).artistNativeReceiptAt(j);
                v.receipts[i][j] = r;
                uint256 a = _artist(p.artistIds, r.artistId);
                if (r.recordHash == 0) revert T.InvalidRecord();
                ++artistCounts[a];
                if (i == 2) {
                    if (r.collectionId != 0) revert T.UnsupportedProfile();
                    if (r.operation == 1) {
                        if (registered[a] || r.recordHash != r.artistId) revert T.InvalidRecord();
                        registered[a] = true;
                        ++registrations;
                    } else if (r.operation == 54) {
                        ++v.revocations;
                    } else {
                        revert T.UnsupportedProfile();
                    }
                } else {
                    uint256 c = _collection(p.collections, r.collectionId);
                    if (p.collections[c].artistId != r.artistId) revert T.InvalidRecord();
                    if (i == 0 && r.operation == 1) {
                        if (v.collections[c].bindingHash != 0) revert T.InvalidRecord();
                        v.collections[c].bindingHash = r.recordHash;
                    } else if (i == 3 && r.operation == 2) {
                        if (accepted[c]) revert T.InvalidRecord();
                        accepted[c] = true;
                    } else if (i == 6 && r.operation == 14) {
                        ++policies[c];
                    } else {
                        revert T.UnsupportedProfile();
                    }
                }
            }
            uint256 revision = i == 0 || i == 4
                ? 2 * p.collections.length
                : i == 2
                    ? p.artistIds.length + p.collections.length + v.policies + v.revocations + 1
                    : i == 3 ? p.collections.length : i == 6 ? v.policies : 0;
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
                    || policies[c] != p.collections[c].policies.length
            ) {
                revert T.InvalidRecord();
            }
        }
    }

    function _data(
        T.SuiteConfiguration memory s,
        address coordinator,
        MH.Request memory p,
        Inventory memory inv,
        uint256[] memory ids
    ) private view returns (AH.OwnerData[7] memory data) {
        MH.Bundle memory identities;
        identities.rows = new MH.Row[](p.artistIds.length);
        identities.artistIds = p.artistIds;
        identities.collectionIds = ids;
        identities.registrationCount = p.artistIds.length;
        for (uint256 j; j < identities.rows.length; ++j) {
            identities.rows[j].query = inv.artists[j];
            identities.rows[j].state = IStreamArtistMultipleHydrationIdentity(s.owners[2])
                .authorityLivingIdentityHydrationState(inv.artists[j]);
            AH.Identity memory identity = abi.decode(identities.rows[j].state, (AH.Identity));
            if (identity.nextRegistrationNonce != p.artistIds.length) {
                revert T.UnsupportedProfile();
            }
        }
        uint256 registration;
        for (uint256 j; j < inv.receipts[2].length; ++j) {
            H.Receipt memory r = inv.receipts[2][j];
            if (r.operation != 1) continue;
            AH.Identity memory a =
                abi.decode(identities.rows[_artist(p.artistIds, r.artistId)].state, (AH.Identity));
            if (
                StreamArtistHashes.identity(
                        StreamArtistHashes.Environment(
                            block.chainid, s.registry, s.core, s.mintManager
                        ),
                        a.item.authorityAddress,
                        a.item.identityRecordHash,
                        registration++
                    ) != r.artistId
            ) revert T.InvalidRecord();
        }
        _nonces(s.owners[2], p, identities);
        for (uint256 i; i < 7; ++i) {
            data[i] = _replay(s, coordinator, i, p);
            if (i == 2) {
                data[i].typedState = abi.encode(MH.SCHEMA, identities);
            } else if (i == 1 || i == 5) {
                if (p.expectedSource[i].nonceIndexCount != 0) revert T.UnsupportedProfile();
            } else {
                if (p.expectedSource[i].nonceIndexCount != 0) revert T.UnsupportedProfile();
                MH.Bundle memory b;
                b.rows = new MH.Row[](p.collections.length);
                for (uint256 c; c < p.collections.length; ++c) {
                    AH.Query memory q = inv.collections[c];
                    bytes memory raw = IStreamArtistAuthorityHydrationOwner(s.owners[i])
                        .authorityHydrationState(q);
                    _collectionFacts(i, c, q, raw, identities, p, inv);
                    // Only Consent consumes policy selectors. Keep the other typed rows minimal.
                    b.rows[c].query = AH.Query(
                        q.artistId,
                        q.collectionId,
                        q.bindingHash,
                        i == 6 ? q.policies : new AH.PolicyKey[](0),
                        new bytes32[](0)
                    );
                    b.rows[c].state = raw;
                }
                data[i].typedState = abi.encode(MH.SCHEMA, b);
            }
        }
    }

    function _collectionFacts(
        uint256 owner,
        uint256 c,
        AH.Query memory q,
        bytes memory raw,
        MH.Bundle memory identities,
        MH.Request memory p,
        Inventory memory inv
    ) private pure {
        if (owner == 0) {
            AH.Binding memory b = abi.decode(raw, (AH.Binding));
            AH.Identity memory a =
                abi.decode(identities.rows[_artist(p.artistIds, q.artistId)].state, (AH.Identity));
            if (
                b.item.artistId != q.artistId || b.item.bindingHash != q.bindingHash
                    || b.item.artistAddress != a.item.authorityAddress
                    || b.item.identityRecordHash != a.item.identityRecordHash
            ) {
                revert T.InvalidRecord();
            }
        } else if (owner == 3) {
            AH.Acceptance memory a = abi.decode(raw, (AH.Acceptance));
            bool found;
            for (uint256 j; j < inv.receipts[3].length; ++j) {
                if (
                    inv.receipts[3][j].collectionId == q.collectionId
                        && inv.receipts[3][j].recordHash == a.record
                ) found = true;
            }
            if (!found) revert T.InvalidRecord();
        } else if (owner == 6) {
            bytes32[] memory records = abi.decode(raw, (bytes32[]));
            if (records.length != p.collections[c].policies.length) revert T.InvalidRecord();
            uint256 k;
            for (uint256 j; j < inv.receipts[6].length; ++j) {
                H.Receipt memory r = inv.receipts[6][j];
                if (r.collectionId != q.collectionId) continue;
                if (k >= records.length || records[k++] != r.recordHash) revert T.InvalidRecord();
            }
            if (k != records.length) revert T.InvalidRecord();
        }
    }

    function _nonces(address owner, MH.Request memory p, MH.Bundle memory b) private view {
        if (p.expectedSource[2].nonceIndexCount != p.artistIds.length) {
            revert T.UnsupportedProfile();
        }
        bool[] memory seen = new bool[](p.artistIds.length);
        uint256 total;
        for (uint256 j; j < p.artistIds.length; ++j) {
            CP.NonceIndex memory n = CP(owner).authorityNonceIndexAt(j);
            uint256 a = _artist(p.artistIds, n.key);
            if (seen[a] || n.kind != 1 || n.prefixCount == 0) revert T.UnsupportedProfile();
            seen[a] = true;
            total += n.prefixCount;
            if (total > 256) revert T.UnsupportedProfile();
            b.rows[a].nonces = new AH.NonceWord[](n.prefixCount);
            for (uint256 k; k < n.prefixCount; ++k) {
                (
                    b.rows[a].nonces[k].prefix,
                    b.rows[a].nonces[k].words,
                    b.rows[a].nonces[k].exhausted
                ) = CP(owner).authorityNonceWordAt(1, n.key, k);
            }
        }
    }

    function _replay(
        T.SuiteConfiguration memory s,
        address coordinator,
        uint256 i,
        MH.Request memory p
    ) internal view returns (AH.OwnerData memory d) {
        CP.Checkpoint memory h = p.expectedSource[i];
        d.origins = p.replayOrigins[i];
        if (d.origins.length != h.replayCount) revert T.InvalidRecord();
        d.sourceKeys = new bytes32[](h.replayCount);
        d.cells = new T.ReplayCell[](h.replayCount);
        for (uint256 j; j < h.replayCount; ++j) {
            (bytes32 key, T.ReplayCell memory cell) = CP(s.owners[i]).authorityReplayAt(j);
            bytes32 expected = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                    block.chainid,
                    s.registry,
                    coordinator,
                    s.archive,
                    s.owners[i],
                    h.ownerState.domainId,
                    d.origins[j].surface,
                    d.origins[j].scope
                )
            );
            if (
                key != expected || cell.status == 0
                    || keccak256(abi.encode(cell))
                        != keccak256(abi.encode(IStreamArtistOwner(s.owners[i]).replayCell(key)))
            ) revert T.InvalidRecord();
            d.sourceKeys[j] = key;
            d.cells[j] = cell;
        }
    }

    function _artist(bytes32[] memory ids, bytes32 id) internal pure returns (uint256) {
        for (uint256 i; i < ids.length; ++i) {
            if (ids[i] == id) return i;
        }
        revert T.InvalidRecord();
    }

    function _collection(MH.Collection[] memory rows, uint256 id) internal pure returns (uint256) {
        for (uint256 i; i < rows.length; ++i) {
            if (rows[i].collectionId == id) return i;
        }
        revert T.InvalidRecord();
    }
}
