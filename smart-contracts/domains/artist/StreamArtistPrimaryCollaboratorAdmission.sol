// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH,
    IStreamArtistAuthorityHydrationCoordinator,
    IStreamArtistAuthorityHydrationOwner
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistMultipleHydrationTypes as MH
} from "../../interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    IStreamArtistBindingOwner
} from "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistIngressBinding
} from "../../interfaces/stream/artist/IStreamArtistIngressBinding.sol";
import {
    IStreamArtistHistory,
    IStreamArtistNativeReceipts,
    StreamArtistHistoryTypes as H
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamArtistMultipleHydrationOperations
} from "./StreamArtistMultipleHydrationOperations.sol";
import {
    StreamArtistHydrationSourceGuards as Original
} from "./StreamArtistHydrationSourceGuards.sol";
import { StreamArtistHistoryProof } from "./StreamArtistHistoryProof.sol";
import {
    StreamArtistRecoveredHydrationSource as Source
} from "./StreamArtistRecoveredHydrationSource.sol";

import {
    StreamArtistRecoveredHydrationAdmission as Admission
} from "./StreamArtistRecoveredHydrationAdmission.sol";

/// @notice Governed predecessor admission and complete journal partition before semantic export.
/// @dev Lane proofs alone grant no authority. The enclosing profile must still validate every
/// typed semantic bundle, replay/nonce inventory, capability and external one-use dependency.
library StreamArtistPrimaryCollaboratorAdmission {
    function collect(T.SuiteConfiguration memory destination, RH.Request memory request)
        public
        view
        returns (Admission.Certificate memory c)
    {
        MH.Request memory selectors = request.records.authority;
        _selectors(selectors);
        IStreamArtistHistory history = IStreamArtistHistory(destination.owners[2]);
        if (history.importedHistoryBindingCount() != 1) revert T.InvalidBinding();
        (c.prior,,,) = history.importedHistoryBinding(0);
        (, bytes32 pin,) = history.artistHistoryPredecessorBinding(c.prior);
        StreamArtistHistoryProof.predecessor(
            destination.core,
            destination.registry,
            c.prior,
            pin,
            StreamArtistHistoryProof.cap(destination.registry)
        );
        (bool sealed_, address successor,) = IStreamArtistHistory(c.prior).artistRegistryCutover();
        if (!sealed_ || successor != destination.registry) revert T.InvalidBinding();
        c.sourceCoordinator = IStreamArtistIngressBinding(c.prior).operationCoordinator();
        c.source = IStreamArtistAuthorityHydrationCoordinator(c.sourceCoordinator)
            .authorityHydrationSuite();
        Original._suite(destination, c.source, c.prior, c.sourceCoordinator);
        c.provenance = Source.collect(c.source, c.sourceCoordinator, selectors.replayOrigins);
        uint256 last = c.provenance.eras.length - 1;
        if (c.provenance.eras[last].priorImportCommitment != request.expectedSourceImportCommitment)
        {
            revert RH.InvalidRecoveredHydrationProvenance();
        }
        for (uint8 i; i < 7; ++i) {
            if (
                keccak256(abi.encode(c.provenance.eras[last].checkpoints[i]))
                    != keccak256(abi.encode(selectors.expectedSource[i]))
            ) {
                revert RH.InvalidRecoveredHydrationProvenance();
            }
            c.before_[i] = IStreamArtistOwner(destination.owners[i]).ownerStateSnapshotV2();
            CP.Checkpoint memory actual = CP(destination.owners[i]).authorityCheckpoint();
            uint256 laneCount = selectors.artistIds.length + selectors.collections.length;
            if (
                c.before_[i].revision != (i == 2 ? 1 + laneCount : 0)
                    || IStreamArtistNativeReceipts(destination.owners[i]).artistNativeReceiptCount()
                        != 0
                    || IStreamArtistAuthorityHydrationOwner(destination.owners[i])
                            .authorityHydrationCommitment() != 0 || actual.schema != RH.CHECKPOINT
                    || actual.nonceIndexCount != 0
                    || actual.replayCount != (i == 2 ? 2 + 2 * laneCount : 0)
                    || keccak256(abi.encode(actual.ownerState))
                        != keccak256(abi.encode(c.before_[i]))
            ) revert RH.InvalidRecoveredHydrationProvenance();
        }
        _partition(c, selectors);
        for (uint256 i; i < c.artists.length; ++i) {
            Original._lane(history, c.prior, 1, c.artists[i].artistId);
            (, uint64 count) =
                IStreamArtistHistory(c.prior).artistHistoryLane(1, c.artists[i].artistId);
            if (count != c.artists[i].records.length) revert T.InvalidRecord();
        }
        for (uint256 i; i < c.collections.length; ++i) {
            Original._lane(history, c.prior, 2, bytes32(c.collections[i].collectionId));
            (, uint64 count) = IStreamArtistHistory(c.prior)
                .artistHistoryLane(2, bytes32(c.collections[i].collectionId));
            if (count != c.collections[i].records.length) revert T.InvalidRecord();
        }
    }

    function _partition(Admission.Certificate memory c, MH.Request memory selected) private view {
        c.artists = new AH.Query[](selected.artistIds.length);
        c.collections = new AH.Query[](selected.collections.length);
        uint256[] memory artistCounts = new uint256[](c.artists.length);
        uint256[] memory collectionCounts = new uint256[](c.collections.length);
        uint256[] memory registrations = new uint256[](c.artists.length);
        for (uint256 i; i < c.artists.length; ++i) {
            c.artists[i].artistId = selected.artistIds[i];
        }
        for (uint256 i; i < c.collections.length; ++i) {
            T.Binding memory binding = IStreamArtistBindingOwner(c.source.owners[0])
                .binding(selected.collections[i].collectionId);
            if (binding.artistId != selected.collections[i].artistId || binding.bindingHash == 0) {
                revert T.InvalidRecord();
            }
            c.collections[i].artistId = binding.artistId;
            c.collections[i].collectionId = selected.collections[i].collectionId;
            c.collections[i].bindingHash = binding.bindingHash;
            c.collections[i].policies = selected.collections[i].policies;
        }
        for (uint8 owner; owner < 7; ++owner) {
            for (uint256 j; j < c.provenance.journals[owner].length; ++j) {
                H.Receipt memory row = c.provenance.journals[owner][j].receipt;
                if (_platformCollectionOnly(owner, row)) {
                    uint256 collection = StreamArtistMultipleHydrationOperations._collection(
                        selected.collections, row.collectionId
                    );
                    ++collectionCounts[collection];
                    continue;
                }
                uint256 artist = StreamArtistMultipleHydrationOperations._artist(
                    selected.artistIds, row.artistId
                );
                ++artistCounts[artist];
                if (owner == 2 && (row.operation == 1 || row.operation == 6)) {
                    if (row.recordHash != row.artistId || row.collectionId != 0) {
                        revert T.InvalidRecord();
                    }
                    ++registrations[artist];
                }
                if (row.collectionId != 0) {
                    uint256 collection = StreamArtistMultipleHydrationOperations._collection(
                        selected.collections, row.collectionId
                    );
                    if (
                        selected.collections[collection].artistId != row.artistId
                            && !(owner == 3 && row.operation == 7)
                    ) {
                        revert T.InvalidRecord();
                    }
                    ++collectionCounts[collection];
                }
            }
        }
        for (uint256 i; i < c.artists.length; ++i) {
            if (registrations[i] != 1) revert T.InvalidRecord();
            c.artists[i].records = new bytes32[](artistCounts[i]);
            artistCounts[i] = 0;
        }
        for (uint256 i; i < c.collections.length; ++i) {
            if (collectionCounts[i] == 0) revert T.InvalidRecord();
            c.collections[i].records = new bytes32[](collectionCounts[i]);
            collectionCounts[i] = 0;
        }
        for (uint8 owner; owner < 7; ++owner) {
            for (uint256 j; j < c.provenance.journals[owner].length; ++j) {
                H.Receipt memory row = c.provenance.journals[owner][j].receipt;
                if (_platformCollectionOnly(owner, row)) {
                    uint256 collection = StreamArtistMultipleHydrationOperations._collection(
                        selected.collections, row.collectionId
                    );
                    c.collections[collection].records[collectionCounts[collection]++] =
                    row.recordHash;
                    continue;
                }
                uint256 artist = StreamArtistMultipleHydrationOperations._artist(
                    selected.artistIds, row.artistId
                );
                c.artists[artist].records[artistCounts[artist]++] = row.recordHash;
                if (row.collectionId != 0) {
                    uint256 collection = StreamArtistMultipleHydrationOperations._collection(
                        selected.collections, row.collectionId
                    );
                    c.collections[collection].records[collectionCounts[collection]++] =
                    row.recordHash;
                }
            }
        }
    }

    function _platformCollectionOnly(uint8 owner, H.Receipt memory row)
        private
        pure
        returns (bool)
    {
        return owner == 4 && row.artistId == 0 && row.collectionId != 0
            && (row.operation == 8
                || row.operation == 9
                || row.operation == 10
                || row.operation == 11
                || row.operation == 53);
    }

    /// @dev Original bounds/order/policy uniqueness, with dependency identities allowed.
    /// Every identity still has exactly one authentic op1/op6 registration in the complete
    /// admitted history. The profile joins all op6 proposals and op7 dependency identities.
    function _selectors(MH.Request memory p) private pure {
        if (
            p.bindingIndex != 0 || p.artistIds.length == 0 || p.artistIds.length > 128
                || p.collections.length == 0 || p.collections.length > 128
        ) revert T.UnsupportedProfile();
        for (uint256 i; i < p.artistIds.length; ++i) {
            if (p.artistIds[i] == 0 || (i != 0 && p.artistIds[i] <= p.artistIds[i - 1])) {
                revert T.InvalidRecord();
            }
        }
        for (uint256 i; i < p.collections.length; ++i) {
            MH.Collection memory c = p.collections[i];
            if (
                c.collectionId == 0
                    || (i != 0 && c.collectionId <= p.collections[i - 1].collectionId)
                    || c.policies.length > 128
            ) revert T.InvalidRecord();
            StreamArtistMultipleHydrationOperations._artist(p.artistIds, c.artistId);
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
}
