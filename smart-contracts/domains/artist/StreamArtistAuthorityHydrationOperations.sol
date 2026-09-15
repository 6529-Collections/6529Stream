// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistEconomicsHydration.sol";
import {
    StreamArtistEconomicsHydrationTypes as EH
} from "../../interfaces/stream/artist/IStreamArtistEconomicsAuthorityHydration.sol";
import "../../interfaces/stream/artist/IStreamArtistConsentOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutTransitionOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutOwner.sol";
import {
    StreamArtistRotationTypes as HydrationRotation
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutAuthorityHydration.sol";
import {
    StreamArtistPayoutHydrationTypes as PH
} from "../../interfaces/stream/artist/IStreamArtistPayoutAuthorityHydration.sol";
import "./StreamArtistHistoryOperations.sol";
import "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import "../../interfaces/stream/artist/IStreamArtistIngressBinding.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";

/// @notice Operation60: complete sealed-source baseline, then seven atomic owner commits.
/// @dev Current cells authenticate against a fixed owner's complete inventory; rolling roots
///      are source history commitments, not recomputed from current cells.
library StreamArtistAuthorityHydrationOperations {
    bytes32 private constant PROFILE = keccak256("6529STREAM_ARTIST_LIVING_BASELINE_HYDRATION_V1");
    bytes32 private constant PAYOUT_PROFILE =
        keccak256("6529STREAM_ARTIST_LIVING_PAYOUT_HYDRATION_V1");
    bytes32 private constant ECONOMICS_PROFILE =
        keccak256("6529STREAM_ARTIST_LIVING_ECONOMICS_HYDRATION_V1");
    bytes32 private constant CHECKPOINT = keccak256("6529STREAM_ARTIST_GUARD_CHECKPOINT_V1");
    event ArtistAuthorityHydrated(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        uint256 indexed collectionId,
        address indexed predecessorRegistry,
        bytes32 profile,
        bytes32 commitment
    );

    function hydrate(D.CoordinatorContext memory x, address actor, AH.Request memory p)
        public
        returns (bytes32 value)
    {
        return _hydrate(x, actor, p, false, new T.EconomicsConsent[](0));
    }

    function hydrateWithPayout(D.CoordinatorContext memory x, address actor, AH.Request memory p)
        public
        returns (bytes32)
    {
        return _hydrate(x, actor, p, true, new T.EconomicsConsent[](0));
    }

    function hydrateWithEconomics(D.CoordinatorContext memory x, address actor, EH.Request memory p)
        public
        returns (bytes32)
    {
        if (p.economics.length == 0 || p.economics.length > 128) revert T.UnsupportedProfile();
        return _hydrate(x, actor, p.authority, true, p.economics);
    }

    function _hydrate(
        D.CoordinatorContext memory x,
        address actor,
        AH.Request memory p,
        bool includePayout,
        T.EconomicsConsent[] memory economics
    ) private returns (bytes32 value) {
        bytes32 profile = economics.length != 0
            ? ECONOMICS_PROFILE
            : includePayout ? PAYOUT_PROFILE : PROFILE;
        if (
            p.artistId == 0 || p.collectionId == 0 || p.bindingIndex != 0 || p.policies.length > 128
        ) revert T.UnsupportedProfile();
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
        (bool sourceSealed, address successor,) =
            IStreamArtistHistory(prior).artistRegistryCutover();
        if (
            !sourceSealed || successor != x.suite.registry
                || IStreamArtistHistory(prior).importedHistoryBindingCount() != 0
        ) revert T.InvalidBinding();
        _lane(history, prior, 1, p.artistId);
        _lane(history, prior, 2, bytes32(p.collectionId));
        address sourceCoordinator = IStreamArtistIngressBinding(prior).operationCoordinator();
        T.SuiteConfiguration memory source =
            IStreamArtistAuthorityHydrationCoordinator(sourceCoordinator).authorityHydrationSuite();
        _suite(x.suite, source, prior, sourceCoordinator);
        AH.Query memory q;
        q.artistId = p.artistId;
        q.collectionId = p.collectionId;
        q.policies = p.policies;
        AH.OwnerData[7] memory data;
        T.Snapshot[7] memory before_;
        uint256 total;
        uint256 revocations;
        uint256 payoutCount;
        for (uint256 i; i < 7; ++i) {
            before_[i] = IStreamArtistOwner(x.suite.owners[i]).ownerStateSnapshotV2();
            if (
                before_[i].revision != (i == 2 ? 3 : 0)
                    || IStreamArtistNativeReceipts(x.suite.owners[i]).artistNativeReceiptCount()
                        != 0
                    || IStreamArtistAuthorityHydrationOwner(x.suite.owners[i])
                            .authorityHydrationCommitment() != 0
            ) revert T.InvalidRecord();
            _header(source.owners[i], p.expectedSource[i]);
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
            } else if (i == 5 && includePayout) {
                if (count == 0) revert T.UnsupportedProfile();
                payoutCount = count;
            } else if (i == 6) {
                if (count != p.policies.length + economics.length) revert T.InvalidRecord();
            } else if (count != 0) {
                revert T.UnsupportedProfile();
            }
        }
        q.records = new bytes32[](total);
        uint256 used;
        uint256 artistCount;
        uint256 collectionCount;
        for (uint256 i; i < 7; ++i) {
            uint256 count = IStreamArtistNativeReceipts(source.owners[i]).artistNativeReceiptCount();
            for (uint256 j; j < count; ++j) {
                H.Receipt memory r =
                    IStreamArtistNativeReceipts(source.owners[i]).artistNativeReceiptAt(j);
                uint16 op = i == 0 ? 1 : i == 2 ? (j == 0 ? 1 : 54) : i == 3 ? 2 : i == 5 ? 18 : 14;
                if (i == 6 && economics.length != 0 && r.operation == 15) op = 15;
                if (
                    r.operation != op || r.artistId != p.artistId
                        || r.collectionId != (i == 2 || i == 5 ? 0 : p.collectionId)
                        || r.recordHash == 0 || (i == 2 && j == 0 && r.recordHash != p.artistId)
                ) revert T.UnsupportedProfile();
                q.records[used++] = r.recordHash;
                ++artistCount;
                if (r.collectionId != 0) ++collectionCount;
            }
            uint64 expectedRevision = i == 0
                ? 2
                : i == 2
                    ? uint64(3 + p.policies.length + economics.length + revocations + payoutCount)
                    : i == 3
                        ? 1
                        : i == 4
                            ? 2
                            : i == 5
                                ? uint64(payoutCount)
                                : i == 6 ? uint64(p.policies.length + economics.length) : 0;
            if (p.expectedSource[i].ownerState.revision != expectedRevision) {
                revert T.UnsupportedProfile();
            }
        }
        for (uint256 i; i < 7; ++i) {
            data[i] = _guards(source, sourceCoordinator, i, p);
            data[i].typedState = i == 6 && economics.length != 0
                ? IStreamArtistEconomicsAuthorityHydrationOwner(source.owners[i])
                    .authorityEconomicsHydrationState(q, economics)
                : IStreamArtistAuthorityHydrationOwner(source.owners[i]).authorityHydrationState(q);
        }
        (, uint64 ac) = IStreamArtistHistory(prior).artistHistoryLane(1, p.artistId);
        (, uint64 cc) = IStreamArtistHistory(prior).artistHistoryLane(2, bytes32(p.collectionId));
        if (ac != artistCount || cc != collectionCount) revert T.InvalidRecord();
        bytes32[] memory policyRecords = economics.length == 0
            ? abi.decode(data[6].typedState, (bytes32[]))
            : StreamArtistEconomicsHydration.decode(data[6].typedState).policies;
        _facts(q, data, source, policyRecords);
        if (economics.length != 0) _economicsFacts(q, data, source, economics);
        if (includePayout) _payoutFacts(q, data, source);
        value = keccak256(
            abi.encode(
                profile,
                block.chainid,
                x.suite.registry,
                address(this),
                prior,
                sourceCoordinator,
                p,
                q,
                data
            )
        );
        // Request fields are losslessly reconstructible from the fixed profile (index0),
        // source headers, query and each owner's original surface/scope list.
        bytes memory profileBytes =
            abi.encode(profile, prior, sourceCoordinator, p.expectedSource, q, data);
        // Original Archive has a finite SSTORE2 carrier. Reject an overlarge baseline
        // before mutation; larger profiles need a distinct paged evidence recipe.
        bytes memory sizeProbe = abi.encode(
            uint16(1), x.configurationHash, uint16(60), actor, value, before_, before_, profileBytes
        );
        if (
            sizeProbe.length
                > IStreamArtistArchiveV2(x.suite.archive).artistArchiveMaxEvidenceBytesV2()
        ) {
            revert T.BoundExceeded(
                sizeProbe.length,
                IStreamArtistArchiveV2(x.suite.archive).artistArchiveMaxEvidenceBytesV2()
            );
        }
        // No destination owner is called until the full profile has been independently collected.
        for (uint256 i; i < 7; ++i) {
            IStreamArtistAuthorityHydrationOwner(x.suite.owners[i])
                .applyArtistAuthorityHydration(
                    T.ActionContext(60, actor, before_[i]), q, data[i], value
                );
        }
        for (uint256 i; i < 7; ++i) {
            _header(source.owners[i], p.expectedSource[i]);
        }
        // Recheck the selected source graph after every mutation, before the one atomic Archive append.
        if (
            keccak256(abi.encode(source))
                != keccak256(
                    abi.encode(
                        IStreamArtistAuthorityHydrationCoordinator(sourceCoordinator)
                            .authorityHydrationSuite()
                    )
                )
        ) revert T.InvalidBinding();
        T.Snapshot[7] memory after_;
        for (uint256 i; i < 7; ++i) {
            after_[i] = IStreamArtistOwner(x.suite.owners[i]).ownerStateSnapshotV2();
        }
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                x.suite.registry,
                address(this),
                uint16(60),
                actor,
                value
            )
        );
        bytes memory evidence = abi.encode(
            uint16(1), x.configurationHash, uint16(60), actor, value, before_, after_, profileBytes
        );
        (bytes32 hash,, bool added) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(id, 1, evidence);
        if (!added || hash != keccak256(evidence)) revert T.InvalidRecord();
        emit ArtistAuthorityHydrated(1, p.artistId, p.collectionId, prior, profile, value);
    }

    function _payoutFacts(
        AH.Query memory q,
        AH.OwnerData[7] memory data,
        T.SuiteConfiguration memory source
    ) private view {
        PH.Bundle memory p = abi.decode(data[5].typedState, (PH.Bundle));
        if (
            p.records.length
                    != IStreamArtistNativeReceipts(source.owners[5]).artistNativeReceiptCount()
                || data[5].cells.length != 1
                || data[5].origins[0].surface
                    != keccak256("payout_lifecycle.replay.designation_chain")
                || data[5].origins[0].scope != keccak256(abi.encode(q.artistId))
                || data[5].cells[0].commitment != p.current.recordHash || data[5].cells[0].kind != 3
                || data[5].cells[0].status != 1
        ) revert T.InvalidRecord();
        (
            T.Payout memory stable,
            T.Payout memory candidate,
            HydrationRotation.ProvisionalAssociation memory association
        ) = IStreamArtistPayoutTransitionOwner(source.owners[5]).payoutCandidates(q.artistId);
        if (
            keccak256(abi.encode(stable)) != keccak256(abi.encode(p.current))
                || candidate.recordHash != 0 || candidate.account != address(0)
                || association.transitionRecordHash != 0 || association.windowEndsAt != 0
        ) revert T.InvalidRecord();
        for (uint256 j; j < p.records.length; ++j) {
            bytes32 record = p.records[j].recordHash;
            if (
                record
                        != IStreamArtistNativeReceipts(source.owners[5])
                        .artistNativeReceiptAt(j)
                        .recordHash
                    || keccak256(abi.encode(p.records[j].terms))
                        != keccak256(
                            abi.encode(
                                IStreamArtistPayoutOwner(source.owners[5]).designationRecord(record)
                            )
                        )
            ) revert T.InvalidRecord();
            HydrationRotation.ProvisionalAssociation memory a =
                IStreamArtistPayoutTransitionOwner(source.owners[5])
                    .payoutDesignationProvisionalAssociation(record);
            if (a.transitionRecordHash != 0 || a.windowEndsAt != 0) revert T.UnsupportedProfile();
        }
    }

    function _lane(IStreamArtistHistory h, address prior, uint8 kind, bytes32 key) private view {
        (bool done, bytes32 tip, uint64 count) = h.importedLaneVerified(kind, key);
        (bytes32 actual, uint64 n) = IStreamArtistHistory(prior).artistHistoryLane(kind, key);
        if (!done || count == 0 || count != n || tip != actual) revert T.InvalidRecord();
    }

    function _header(address owner, CP.Checkpoint memory expected) private view {
        if (
            expected.schema != CHECKPOINT || expected.replayCount > 512
                || expected.nonceIndexCount > 1
                || keccak256(abi.encode(expected))
                    != keccak256(abi.encode(CP(owner).authorityCheckpoint()))
        ) revert T.InvalidRecord();
    }

    function _suite(
        T.SuiteConfiguration memory next,
        T.SuiteConfiguration memory source,
        address prior,
        address coordinator
    ) private view {
        if (
            source.registry != prior || source.core != next.core
                || source.mintManager != next.mintManager
                || source.roleRegistry != next.roleRegistry || source.metadata != next.metadata
                || source.primaryResolver != next.primaryResolver
                || source.royaltyResolver != next.royaltyResolver
                || source.primaryRevenueClass != next.primaryRevenueClass
                || source.validator != next.validator
        ) revert T.InvalidBinding();
        for (uint256 i; i < 7; ++i) {
            IStreamArtistOwner o = IStreamArtistOwner(source.owners[i]);
            if (
                o.artistRegistry() != prior || o.operationCoordinator() != coordinator
                    || o.archiveV2() != source.archive || o.core() != source.core
                    || o.mintManager() != source.mintManager
                    || o.deploymentChainId() != block.chainid
                    || o.domainId() != IStreamArtistOwner(next.owners[i]).domainId()
            ) revert T.InvalidBinding();
        }
    }

    function _guards(
        T.SuiteConfiguration memory s,
        address coordinator,
        uint256 i,
        AH.Request memory p
    ) private view returns (AH.OwnerData memory result) {
        CP.Checkpoint memory h = p.expectedSource[i];
        address owner = s.owners[i];
        result.origins = p.replayOrigins[i];
        if (result.origins.length != h.replayCount) revert T.InvalidRecord();
        result.cells = new T.ReplayCell[](h.replayCount);
        result.sourceKeys = new bytes32[](h.replayCount);
        for (uint256 j; j < h.replayCount; ++j) {
            (bytes32 key, T.ReplayCell memory cell) = CP(owner).authorityReplayAt(j);
            AH.Origin memory origin = result.origins[j];
            bytes32 actual = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                    block.chainid,
                    s.registry,
                    coordinator,
                    s.archive,
                    owner,
                    h.ownerState.domainId,
                    origin.surface,
                    origin.scope
                )
            );
            if (
                actual != key || cell.status == 0
                    || keccak256(abi.encode(cell))
                        != keccak256(abi.encode(IStreamArtistOwner(owner).replayCell(key)))
            ) revert T.InvalidRecord();
            result.cells[j] = cell;
            result.sourceKeys[j] = key;
        }
        if (i != 2) {
            if (h.nonceIndexCount != 0) revert T.UnsupportedProfile();
            return result;
        }
        if (h.nonceIndexCount != 1) revert T.UnsupportedProfile();
        CP.NonceIndex memory index = CP(owner).authorityNonceIndexAt(0);
        if (
            index.kind != 1 || index.key != p.artistId || index.prefixCount == 0
                || index.prefixCount > 256
        ) revert T.UnsupportedProfile();
        result.nonces = new AH.NonceWord[](index.prefixCount);
        for (uint256 j; j < index.prefixCount; ++j) {
            (result.nonces[j].prefix, result.nonces[j].words, result.nonces[j].exhausted) =
                CP(owner).authorityNonceWordAt(1, p.artistId, j);
        }
    }

    function _facts(
        AH.Query memory q,
        AH.OwnerData[7] memory data,
        T.SuiteConfiguration memory source,
        bytes32[] memory records
    ) private view {
        AH.Binding memory b = abi.decode(data[0].typedState, (AH.Binding));
        AH.Identity memory identity = abi.decode(data[2].typedState, (AH.Identity));
        AH.Acceptance memory acceptance = abi.decode(data[3].typedState, (AH.Acceptance));
        if (
            b.item.artistAddress != identity.item.authorityAddress
                || b.item.identityRecordHash != identity.item.identityRecordHash
                || b.item.artistId != q.artistId || b.item.bindingHash != q.bindingHash
                || acceptance.record
                    != IStreamArtistNativeReceipts(source.owners[3])
                    .artistNativeReceiptAt(0)
                    .recordHash
        ) revert T.InvalidRecord();
        if (records.length != q.policies.length) revert T.InvalidRecord();
        uint256 receiptIndex;
        for (uint256 j; j < records.length; ++j) {
            uint256 receiptCount =
                IStreamArtistNativeReceipts(source.owners[6]).artistNativeReceiptCount();
            while (
                receiptIndex < receiptCount
                    && IStreamArtistNativeReceipts(source.owners[6])
                        .artistNativeReceiptAt(receiptIndex)
                        .operation != 14
            ) ++receiptIndex;
            if (receiptIndex == receiptCount) revert T.InvalidRecord();
            if (
                q.policies[j].phaseId == 0 || q.policies[j].policyHash == 0
                    || records[j]
                        != IStreamArtistNativeReceipts(source.owners[6])
                        .artistNativeReceiptAt(receiptIndex++)
                        .recordHash
            ) revert T.InvalidRecord();
            for (uint256 k; k < j; ++k) {
                if (
                    q.policies[k].phaseId == q.policies[j].phaseId
                        && q.policies[k].policyHash == q.policies[j].policyHash
                ) revert T.InvalidRecord();
            }
        }
    }

    function _economicsFacts(
        AH.Query memory q,
        AH.OwnerData[7] memory data,
        T.SuiteConfiguration memory source,
        T.EconomicsConsent[] memory terms
    ) private view {
        EH.Bundle memory b = StreamArtistEconomicsHydration.decode(data[6].typedState);
        if (b.records.length != terms.length) revert T.InvalidRecord();
        uint256 index;
        uint256 policyCount;
        uint256 count = IStreamArtistNativeReceipts(source.owners[6]).artistNativeReceiptCount();
        for (uint256 j; j < count; ++j) {
            H.Receipt memory native_ =
                IStreamArtistNativeReceipts(source.owners[6]).artistNativeReceiptAt(j);
            if (native_.operation == 14) {
                ++policyCount;
                continue;
            }
            if (native_.operation != 15 || index >= terms.length) revert T.InvalidRecord();
            EH.Row memory r = b.records[index];
            T.EconomicsConsent memory p = terms[index++];
            if (
                keccak256(abi.encode(r.terms)) != keccak256(abi.encode(p))
                    || r.recordHash != native_.recordHash
                    || IStreamArtistConsentOwner(source.owners[6]).economicsRecord(p)
                        != r.recordHash
                    || IStreamArtistEconomicsEvidence(source.owners[6])
                            .economicsRecordForBinding(p, q.artistId, 1, q.bindingHash)
                        != r.recordHash
                    || keccak256(
                            abi.encode(
                                IStreamArtistEconomicsEvidence(source.owners[6])
                                    .economicsRecordAssociation(r.recordHash)
                            )
                        ) != keccak256(abi.encode(r.association))
            ) revert T.InvalidRecord();
            if (p.resolver != source.primaryResolver && p.resolver != source.royaltyResolver) {
                revert T.UnsupportedProfile();
            }
            bytes32 scope = keccak256(abi.encode(p));
            bool found;
            for (uint256 k; k < data[6].origins.length; ++k) {
                if (
                    data[6].origins[k].surface == keccak256("consent_finality.replay.consent_key")
                        && data[6].origins[k].scope == scope
                ) {
                    T.ReplayCell memory cell = data[6].cells[k];
                    if (cell.kind != 1 || cell.status != 2 || cell.commitment != r.recordHash) {
                        revert T.InvalidRecord();
                    }
                    found = true;
                }
            }
            if (!found) revert T.InvalidRecord();
        }
        if (index != terms.length || policyCount != q.policies.length) revert T.InvalidRecord();
    }
}
