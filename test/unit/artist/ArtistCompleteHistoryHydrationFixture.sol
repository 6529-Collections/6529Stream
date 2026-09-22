// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistCompleteHistoryCompositionActual.t.sol";
import {
    StreamArtistCompleteHistoryCodec as CHCodec
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryCodec.sol";
import {
    StreamArtistCompleteHistoryCurrent as CHCurrent
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryCurrent.sol";
import {
    StreamArtistCompleteHistorySelection as CHSelection
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistorySelection.sol";
import {
    StreamArtistRecoveredHydrationEvidence as CHEvidence
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationEvidence.sol";
import {
    StreamArtistRepudiationTypes as CHRP,
    IStreamArtistAttributionRepudiation as CHRepudiation,
    IStreamArtistRepudiationOwner as CHRepudiationOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";
import {
    StreamArtistAttributionDisputeTypes as CHAD
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    IStreamArtistPlatformOwner as CHPlatformOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPlatformWorks.sol";

interface CompleteHistoryHydrationVm {
    function expectCall(address target, bytes calldata data, uint64 count) external;
}

/// @notice Original Safe, all seven owners, Registry, Coordinator, Archive and complete lane import.
/// @dev Core collection3 and governed action scheduling retain their explicit inherited unit
/// boundaries. No capability, owner receipt, replay, nonce, checkpoint or Archive result is mocked.
/// The tests require the integrator's shared complete-history activation; no test dispatch exists.
abstract contract ArtistCompleteHistoryHydrationFixture is
    StreamArtistCompleteHistoryCompositionActualTest
{
    CompleteHistoryHydrationVm internal constant chVm =
        CompleteHistoryHydrationVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    CHRP.Record internal chRepudiation;

    struct CompleteRun {
        Successor next;
        RH.Request request;
        Commit.Prepared prepared;
        bytes32 latest;
    }

    function _chRun() internal returns (CompleteRun memory run) {
        CHAdmissionType.Certificate memory source;
        (source, run.latest) = _compositionSource();
        _chAcceptedRepudiation();
        multiArtists = new bytes32[](source.artists.length);
        for (uint256 i; i < source.artists.length; ++i) {
            multiArtists[i] = source.artists[i].artistId;
        }
        multiCollectionArtists = [source.collections[0].artistId, source.collections[1].artistId];
        run.next = _chCutover(source);
        run.request = _rhRequest();
        run.request.records.authority.artistIds = multiArtists;
        run.request.records.authority.collections = new MH.Collection[](source.collections.length);
        for (uint256 k; k < source.collections.length; ++k) {
            AH.Query memory q = source.collections[k];
            run.request.records.authority.collections[k] =
                MH.Collection(q.artistId, q.collectionId, q.policies);
        }
        require(
            CHSelection.required(run.next.coordinator.suiteConfiguration(), run.request),
            "actual mixed source selects complete history"
        );
        run.prepared = Prepared.prepare(run.next.coordinator.suiteConfiguration(), run.request);
        run.request.expectedSemanticInventory = Prepared.inventory(run.prepared);
        (RH.ExportHeader memory header,) = Payload.decode(run.prepared.data[0].typedState, 0);
        require(
            (header.requiredFeatures & CHType.FEATURE) != 0
                && (header.requiredFeatures & RH.DISPUTE_HISTORY) != 0,
            "shared preparation admits real complete MD graph"
        );
    }

    function _chAcceptedRepudiation() private {
        T.Authorization memory acceptance = T.Authorization(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint,
            uint64(block.timestamp + 1 days),
            ""
        );
        bytes32 digest = ingress.acceptanceDigest(1, acceptance);
        acceptance.signature = _signature(digest);
        bytes32 accepted = ingress.acceptArtistBinding(1, acceptance);
        _pcRemember(artistId, accepted, digest, acceptance);
        _rhCandidate(
            3,
            "acceptance_lifecycle.replay.record_uniqueness",
            keccak256(abi.encode(uint256(1), uint64(1), uint8(1), address(artist)))
        );
        require(Binding(suite.owners[0]).binding(1).accepted, "original A acceptance");
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint
                == acceptance.nonce + 1,
            "original2 advances A nonce before original47"
        );
        CHAD.Filing memory filing =
            CHAD.Filing(1, 1, 4, 0, keccak256("complete mixed genuine pending repudiation"));
        T.Authorization memory authorization = T.Authorization(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint,
            uint64(block.timestamp + 1 days),
            ""
        );
        digest = ingress.attributionRepudiationDigest(filing, authorization);
        authorization.signature = _signature(digest);
        uint256 before_ = Native(suite.owners[2]).artistNativeReceiptCount();
        _artistCall(abi.encodeCall(CHRepudiation.revokeAttribution, (filing, authorization)));
        require(
            Native(suite.owners[2]).artistNativeReceiptCount() == before_,
            "original47 creates no Identity native receipt"
        );
        bytes32 record = CHRepudiationOwner(suite.owners[4]).rawPendingRepudiation(1);
        chRepudiation = CHRepudiationOwner(suite.owners[4]).attributionRepudiationRecord(record);
        require(
            record != 0 && chRepudiation.artistId == artistId
                && chRepudiation.nonce == authorization.nonce
                && chRepudiation.signer == address(artist),
            "genuine signed original47"
        );
        require(
            chRepudiation.authorityHead.principal == address(artist)
                && chRepudiation.authorityHead.authorityClass == 1
                && chRepudiation.authorityHead.latestTransition == 0
                && chRepudiation.authorityHead.latestContest == 0
                && chRepudiation.authorityHead.latestDismissal == 0
                && chRepudiation.capturedGuardianSet == 0
                && IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint
                    == authorization.nonce + 1,
            "ordinary original authority head and consumed repudiation nonce"
        );
        require(
            CHRepudiationOwner(suite.owners[4]).attributionRepudiationTerminal(record).phase == 1,
            "real pending terminal"
        );
        _pcRemember(artistId, record, digest, authorization);
        _rhCandidate(4, "attribution_lifecycle.replay.repudiation_key", record);
    }

    function _chCutover(CHAdmissionType.Certificate memory source)
        private
        returns (Successor memory next)
    {
        next = _multiNext();
        HT.Leaf[] memory rows = _chLeaves(source);
        (bytes32 root,) = _multiProof(address(ingress), rows, 0);
        bytes32 manifest = keccak256("complete mixed PC MD U original lane manifest");
        HT.Context memory context = History(address(next.registry))
            .artistHistoryImportContext(address(ingress), uint64(block.number), root, manifest);
        _rhCandidate(
            2,
            "identity_authority.replay.governance_action",
            keccak256(
                abi.encode(
                    keccak256("unit authority gas raise"),
                    context.scopeHash,
                    context.oldValueHash,
                    context.newValueHash
                )
            )
        );
        _rhCandidate(
            2,
            "identity_authority.replay.import_binding_key",
            keccak256(
                abi.encode(HT.Binding(address(ingress), uint64(block.number), root, manifest))
            )
        );
        _rhCandidate(2, "identity_authority.replay.one_way_cutover_latch", 0);
        _rhCommitHistory(next, context, root, manifest);
        core.set(keccak256("ARTIST_REGISTRY"), address(next.registry), false);
        History(address(ingress)).observeRegistryCutover();
        for (uint256 i; i < rows.length; ++i) {
            if (
                i + 1 < rows.length && rows[i + 1].laneKind == rows[i].laneKind
                    && rows[i + 1].laneKey == rows[i].laneKey
            ) continue;
            (, bytes32[] memory proof) = _multiProof(address(ingress), rows, i);
            History(address(next.registry)).verifyImportedLaneTip(0, rows[i], proof);
            _rhCandidate(
                2,
                "identity_authority.replay.verified_lane_key",
                keccak256(abi.encode(rows[i].laneKind, rows[i].laneKey))
            );
            _rhCandidate(
                2,
                "identity_authority.replay.import_binding",
                keccak256(abi.encode(uint256(0), rows[i].laneKind, rows[i].laneKey))
            );
        }
    }

    function _chLeaves(CHAdmissionType.Certificate memory source)
        private
        view
        returns (HT.Leaf[] memory rows)
    {
        History h = History(address(ingress));
        uint256 lanes = source.artists.length + source.collections.length;
        uint256 total;
        for (uint256 i; i < lanes; ++i) {
            (uint8 kind, bytes32 key) = _chLane(source, i);
            (, uint64 count) = h.artistHistoryLane(kind, key);
            total += count;
        }
        rows = new HT.Leaf[](total);
        uint256 cursor;
        for (uint256 i; i < lanes; ++i) {
            (uint8 kind, bytes32 key) = _chLane(source, i);
            (, uint64 count) = h.artistHistoryLane(kind, key);
            for (uint64 j; j < count; ++j) {
                (bytes32 record, bytes32 chain) = h.artistHistoryRecordAt(kind, key, j);
                rows[cursor++] = HT.Leaf(kind, key, j, record, chain);
            }
        }
    }

    function _chLane(CHAdmissionType.Certificate memory source, uint256 i)
        private
        pure
        returns (uint8, bytes32)
    {
        return i < source.artists.length
            ? (uint8(1), source.artists[i].artistId)
            : (uint8(2), bytes32(source.collections[i - source.artists.length].collectionId));
    }

    function _chImport(CompleteRun memory run) internal {
        require(
            this.executeTargetSafe(
                address(run.next.registry),
                abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (run.request))
            ),
            "actual original Safe operation60"
        );
        _chAssert(run);
    }

    function _chAssert(CompleteRun memory run) internal view {
        Commit.Prepared memory p = run.prepared;
        T.SuiteConfiguration memory target = run.next.coordinator.suiteConfiguration();
        bytes32 value = HydrationOwner(target.owners[2]).authorityHydrationCommitment();
        require(
            value != 0 && CHCurrent.recheck(p), "same full source still current after actual import"
        );
        for (uint8 i; i < 7; ++i) {
            (RH.ExportHeader memory header, Payload.Payload memory payload) =
                Payload.decode(p.data[i].typedState, i);
            require(
                (header.requiredFeatures & CHType.FEATURE) != 0,
                "all seven original envelopes select complete profile"
            );
            (RH.OwnerProvenance memory prefix, bytes32 installed, uint64 revision) =
                RecoveredOwner(target.owners[i]).recoveredHydrationImportedPrefix();
            T.Snapshot memory after_ = Owner(target.owners[i]).ownerStateSnapshotV2();
            require(
                installed == value
                    && HydrationOwner(target.owners[i]).authorityHydrationCommitment() == value
                    && revision == after_.revision,
                "one common imported certificate"
            );
            require(
                keccak256(abi.encode(prefix)) == keccak256(abi.encode(payload.provenance)),
                "entire original unfiltered receipt and alias prefix"
            );
            require(
                after_.revision == p.admission.before_[i].revision + 1
                    && after_.recordChainTip == p.admission.before_[i].recordChainTip
                    && Native(target.owners[i]).artistNativeReceiptCount() == 0,
                "one mutation and zero fabricated native receipts"
            );
            require(
                keccak256(abi.encode(Publications.collect(target.owners[i], i)))
                    == keccak256(abi.encode(payload.publications)),
                "original artifact pointers"
            );
            require(
                keccak256(
                    abi.encode(
                        Guards.collectNonces(
                            target.owners[i], CP(target.owners[i]).authorityCheckpoint()
                        )
                    )
                ) == keccak256(abi.encode(payload.nonces)),
                "exact global nonce words and hints"
            );
            _rhGuardCells(
                target.owners[i], i, p.data[i], prefix, target, address(run.next.coordinator)
            );
        }
        require(
            _pcSemantics(target) == _pcSemantics(suite),
            "original partial collaborator and signatures retained"
        );
        for (uint256 i; i < p.admission.artists.length; ++i) {
            bytes32 id = p.admission.artists[i].artistId;
            require(
                keccak256(abi.encode(IStreamArtistIdentityOwner(target.owners[2]).identity(id)))
                    == keccak256(
                        abi.encode(IStreamArtistIdentityOwner(suite.owners[2]).identity(id))
                    ),
                "every original principal head"
            );
            require(
                IStreamArtistIdentityOwner(target.owners[2])
                    .activeIdentity(
                        IStreamArtistIdentityOwner(suite.owners[2]).identity(id).authorityAddress
                    ) == id,
                "principal address association"
            );
            _chLaneEqual(target.owners[2], 1, id, value);
            (address a, bytes32 b) = ingress.artistPayoutAccount(id);
            (address c, bytes32 d) = run.next.registry.artistPayoutAccount(id);
            require(a == c && b == d, "per Artist payout head");
        }
        require(
            IStreamArtistIdentityOwner(target.owners[2]).nextRegistrationNonce() == 3,
            "actual allocation slots zero one two"
        );
        for (uint256 k; k < p.admission.collections.length; ++k) {
            uint256 id = p.admission.collections[k].collectionId;
            _chLaneEqual(target.owners[2], 2, bytes32(id), value);
            T.Binding memory old = Binding(suite.owners[0]).binding(id);
            require(
                keccak256(abi.encode(Binding(target.owners[0]).binding(id)))
                    == keccak256(abi.encode(old)),
                "latest binding exact including pending and zero"
            );
            for (uint64 g = 1; g <= old.generation; ++g) {
                bytes32 hash = Binding(suite.owners[0]).bindingAt(id, g).bindingHash;
                require(
                    keccak256(abi.encode(Binding(target.owners[0]).bindingAt(id, g)))
                        == keccak256(abi.encode(Binding(suite.owners[0]).bindingAt(id, g))),
                    "former-generation binding retained"
                );
                require(
                    keccak256(abi.encode(Lifecycle(target.owners[0]).bindingTermination(id, g)))
                        == keccak256(
                            abi.encode(Lifecycle(suite.owners[0]).bindingTermination(id, g))
                        ),
                    "original terminal retained"
                );
                require(
                    _chCorrectionHash(target.owners[0], hash)
                        == _chCorrectionHash(suite.owners[0], hash),
                    "original correction approval and global registration slot"
                );
                require(
                    Acceptance(target.owners[3]).acceptanceRecord(hash)
                            == Acceptance(suite.owners[3]).acceptanceRecord(hash)
                        && Acceptance(target.owners[3]).acceptedAt(hash)
                            == Acceptance(suite.owners[3]).acceptedAt(hash),
                    "original accepted and genuinely empty pending heads"
                );
            }
            (uint8 oldState, uint64 oldGeneration) =
                Attribution(suite.owners[4]).attributionState(id);
            (uint8 newState, uint64 newGeneration) =
                Attribution(target.owners[4]).attributionState(id);
            require(
                oldState == newState && oldGeneration == newGeneration, "current Attribution exact"
            );
        }
        require(
            Binding(target.owners[0]).binding(2).artistId == run.latest
                && !Binding(target.owners[0]).binding(2).accepted,
            "new B pending is not replaced by accepted historical A"
        );
        require(
            keccak256(abi.encode(CHPlatformOwner(target.owners[4]).platformWorksState(3)))
                == keccak256(abi.encode(CHPlatformOwner(suite.owners[4]).platformWorksState(3))),
            "unbound original declaration"
        );
        require(
            _chRepudiationHash(target.owners[4]) == _chRepudiationHash(suite.owners[4]),
            "original47 record terminal pending and cohort"
        );
        require(
            CHRepudiationOwner(target.owners[4])
                .repudiationCount(artistId, keccak256(abi.encode(chRepudiation.authorityHead)))
            == 1,
            "authentic pending cohort count"
        );
    }

    function _chLaneEqual(address destination, uint8 kind, bytes32 id, bytes32 value) private view {
        (bytes32 oldTip, uint64 oldCount) = History(address(ingress)).artistHistoryLane(kind, id);
        (bytes32 newTip, uint64 newCount) = History(destination).artistHistoryLane(kind, id);
        require(
            oldTip == newTip && oldCount == newCount
                && _chActivated(destination, kind, id) == value,
            "exact original activated lane"
        );
        for (uint64 i; i < oldCount; ++i) {
            (bytes32 oldRecord, bytes32 oldChain) =
                History(address(ingress)).artistHistoryRecordAt(kind, id, i);
            (bytes32 newRecord, bytes32 newChain) =
                History(destination).artistHistoryRecordAt(kind, id, i);
            require(oldRecord == newRecord && oldChain == newChain, "original lane index and chain");
        }
    }

    function _chActivated(address owner, uint8 kind, bytes32 id) private view returns (bytes32) {
        HistoryStorage.State storage state = HistoryStorage.state();
        mapping(bytes32 => bytes32) storage cells = state.hydrated;
        uint256 slot;
        assembly ("memory-safe") { slot := cells.slot }
        return vm.load(owner, keccak256(abi.encode(HistoryStorage.key(kind, id), slot)));
    }

    function _chRepudiationHash(address owner) private view returns (bytes32) {
        CHRepudiationOwner r = CHRepudiationOwner(owner);
        return keccak256(
            abi.encode(
                r.attributionRepudiationRecord(chRepudiation.recordHash),
                r.attributionRepudiationTerminal(chRepudiation.recordHash),
                r.rawPendingRepudiation(1),
                r.repudiationCount(artistId, keccak256(abi.encode(chRepudiation.authorityHead)))
            )
        );
    }

    function _chCorrectionHash(address owner, bytes32 bindingHash) private view returns (bytes32) {
        (PCBC.Approval memory approval, bytes32 hash) =
            PCCorrectionOwner(owner).bindingCorrection(bindingHash);
        return keccak256(abi.encode(approval, hash));
    }

    function _chDestinationHash(CompleteRun memory run) internal view returns (bytes32) {
        T.SuiteConfiguration memory target = run.next.coordinator.suiteConfiguration();
        (uint8 state, uint64 generation) = Attribution(target.owners[4]).attributionState(3);
        return keccak256(
            abi.encode(
                _pcDestination(run.next),
                Binding(target.owners[0]).bindingAt(2, 2),
                Terms(target.owners[0]).bindingTerms(2, 2),
                Lifecycle(target.owners[0]).bindingTermination(2, 2),
                _chCorrectionHash(
                    target.owners[0], Binding(suite.owners[0]).binding(2).bindingHash
                ),
                Binding(target.owners[0]).binding(3),
                state,
                generation,
                CHPlatformOwner(target.owners[4]).platformWorksState(3),
                _chActivated(target.owners[2], 2, bytes32(uint256(3))),
                _chRepudiationHash(target.owners[4]),
                _chGuardsHash(run),
                _chArchiveHash(run.next.archive)
            )
        );
    }

    function _chGuardsHash(CompleteRun memory run) private view returns (bytes32 h) {
        T.SuiteConfiguration memory target = run.next.coordinator.suiteConfiguration();
        RH.OriginEnvironment memory env;
        env.chainId = block.chainid;
        env.registry = target.registry;
        env.coordinator = address(run.next.coordinator);
        env.archive = target.archive;
        env.owners = target.owners;
        for (uint8 i; i < 7; ++i) {
            address owner = target.owners[i];
            h = keccak256(
                abi.encode(
                    h,
                    Native(owner).artistNativeReceiptCount(),
                    Guards.collectNonces(owner, CP(owner).authorityCheckpoint())
                )
            );
            for (uint256 j; j < run.prepared.data[i].origins.length; ++j) {
                bytes32 key = Guards.replayKey(env, i, run.prepared.data[i].origins[j]);
                h = keccak256(
                    abi.encode(
                        h,
                        Owner(owner).replayCell(key),
                        RecoveredOwner(owner).recoveredHydrationReplayPoint(key)
                    )
                );
            }
        }
        for (uint256 i; i < pcRecords.length; ++i) {
            h = keccak256(
                abi.encode(
                    h, IStreamArtistIdentityOwner(target.owners[2]).signatureBundle(pcRecords[i])
                )
            );
        }
    }

    function _chSourceHash() internal view returns (bytes32 h) {
        for (uint8 i; i < 7; ++i) {
            h = keccak256(
                abi.encode(
                    h,
                    CP(suite.owners[i]).authorityCheckpoint(),
                    Publications.collect(suite.owners[i], i),
                    Native(suite.owners[i]).artistNativeReceiptCount()
                )
            );
        }
        return keccak256(
            abi.encode(
                h,
                _pcSemantics(suite),
                _chRepudiationHash(suite.owners[4]),
                CHPlatformOwner(suite.owners[4]).platformWorksState(3),
                _chArchiveHash(archive)
            )
        );
    }

    function _chArchiveHash(StreamArtistArchiveV2 target) private view returns (bytes32 h) {
        uint256 count = target.storedPayloadCount();
        h = keccak256(abi.encode(count));
        for (uint256 i; i < count; ++i) {
            (address pointer, bytes32 kind, bytes32 hash) = target.storedPayloadAt(i);
            h = keccak256(abi.encode(h, pointer, kind, hash));
        }
    }

    function _chFirstPage(CompleteRun memory run) internal view returns (bytes memory) {
        Commit.Prepared memory p = run.prepared;
        bytes32 value = keccak256(
            abi.encode(
                RH.PROFILE,
                RH.VERSION,
                block.chainid,
                address(run.next.registry),
                address(run.next.coordinator),
                p.admission.prior,
                p.admission.sourceCoordinator,
                run.request,
                p.admission.artists,
                p.admission.collections,
                p.query,
                p.data,
                p.timing,
                p.externalGuards,
                p.admission.before_
            )
        );
        bytes memory profile = abi.encode(
            RH.PROFILE,
            RH.VERSION,
            p.admission.prior,
            p.admission.sourceCoordinator,
            run.request,
            p.admission.artists,
            p.admission.collections,
            p.query,
            p.data,
            p.timing,
            p.externalGuards
        );
        bytes32 id = CHEvidence.pageId(
            address(run.next.registry),
            address(run.next.coordinator),
            value,
            CHEvidence.describe(profile),
            0
        );
        return abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector, id);
    }
}
