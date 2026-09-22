// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistRecoveredAuthorityActual.t.sol";
import {
    StreamArtistPlatformTypes as PW
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistPlatformTypes.sol";
import {
    IStreamArtistPlatformWorks,
    IStreamArtistPlatformOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPlatformWorks.sol";
import {
    IStreamArtistAttributionClaimsOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionClaims.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistAcceptanceOwner as Acceptance
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAcceptanceOwner.sol";
import {
    IStreamArtistAttributionOwner as Attribution
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    IStreamArtistReconstruction as Reconstruction
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReconstruction.sol";
import {
    StreamSchemaDocumentStore
} from "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import {
    IStreamCollectionMetadataV1
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamCollectionArchivalCoverage
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamCollectionArchivalCoverage.sol";
import {
    StreamArchivalTypes as Archival
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArchivalTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredPlatformTypes as P
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistUnboundPlatformCodec as UCodec
} from "../../../smart-contracts/domains/artist/StreamArtistUnboundPlatformCodec.sol";
import {
    StreamArtistUnboundPlatformCollectionRows as URows
} from "../../../smart-contracts/domains/artist/StreamArtistUnboundPlatformCollectionRows.sol";
import {
    StreamArtistUnboundPlatformTimeline as UTimeline
} from "../../../smart-contracts/domains/artist/StreamArtistUnboundPlatformTimeline.sol";
import {
    StreamArtistUnboundPlatformEmptyIdentity as UEmpty
} from "../../../smart-contracts/domains/artist/StreamArtistUnboundPlatformEmptyIdentity.sol";

interface UnboundTestVM {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
    function expectCall(address target, bytes calldata data, uint64 count) external;
}

interface UnboundAttributionDisplay {
    function attributionClaims(uint256 id) external view returns (uint256, bytes32);
    function staticAttributionClaims(uint256 id) external view returns (uint256, bytes32);
}

/// @notice Actual original Platform/Archive/seven-owner/Safe recipe; Core, coverage and scheduled
/// governance are explicit inherited typed unit boundaries. No deployment/gas acceptance claim.
abstract contract ArtistUnboundPlatformFixture is StreamArtistRecoveredAuthorityActualTest {
    uint256 internal upCollection = 1;
    bool internal upMixed;
    uint256 internal upAction;
    StreamSchemaDocumentStore internal documents;
    bytes32[] internal platformClaims;
    bytes32[] internal platformContests;
    bytes32[] internal allegations;
    bytes32 private constant MULTI_LEAF =
        0xea04da6644046a7c731e99312c32df311e81aa7e137dfc2a49c2116bb325195d;

    function _createInitialBinding() internal pure override returns (bool) {
        return false;
    }

    function _upSource(bool mixed) internal {
        upMixed = mixed;
        if (mixed) {
            T.BindingProposal memory proposal = _proposal(0);
            proposal.identityRecordURI = "urn:unbound:mixed:ordinary";
            (artistId,) = ingress.proposeArtistBinding(
                1, proposal, bytes("unit identity document"), "Artist Safe"
            );
            _rhBaseline();
            upCollection = 2;
        }
        bytes32 statement = keccak256(abi.encode("unbound original Platform", upCollection));
        bytes32 record = ingress.declarePlatformWorks(upCollection, statement);
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PLATFORM_WORKS_DECLARATION_V1"),
                        block.chainid,
                        address(ingress),
                        address(core),
                        upCollection,
                        statement,
                        uint64(block.timestamp)
                    )
                ),
            "literal original declaration"
        );
        _hpGuard(8, bytes32(upCollection));
        _rhCandidate(2, "identity_authority.replay.one_way_cutover_latch", 0);
        T.Binding memory empty;
        require(
            keccak256(abi.encode(Binding(suite.owners[0]).binding(upCollection)))
                == keccak256(abi.encode(empty)),
            "actual unbound source"
        );
    }

    function _upRequest() internal view returns (RH.Request memory r) {
        r = _rhRequest();
        r.records.authority.artistIds = new bytes32[](upMixed ? 1 : 0);
        if (upMixed) r.records.authority.artistIds[0] = artistId;
        r.records.authority.collections = new MH.Collection[](upMixed ? 2 : 1);
        if (upMixed) {
            r.records.authority.collections[0] = MH.Collection(artistId, 1, new AH.PolicyKey[](0));
        }
        r.records.authority.collections[upMixed ? 1 : 0] =
            MH.Collection(0, upCollection, new AH.PolicyKey[](0));
    }

    function _upCutover() internal returns (Successor memory next) {
        next = _upNext();
        HT.Leaf[] memory rows = _upLeaves(History(address(ingress)));
        (bytes32 root,) = _upProof(address(ingress), rows, 0);
        bytes32 manifest = keccak256("complete unbound Platform manifest");
        HT.Context memory c = History(address(next.registry))
            .artistHistoryImportContext(address(ingress), uint64(block.number), root, manifest);
        _rhCandidate(
            2,
            "identity_authority.replay.governance_action",
            keccak256(
                abi.encode(
                    keccak256("unit authority gas raise"),
                    c.scopeHash,
                    c.oldValueHash,
                    c.newValueHash
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
        _rhCommitHistory(next, c, root, manifest);
        core.set(keccak256("ARTIST_REGISTRY"), address(next.registry), false);
        History(address(ingress)).observeRegistryCutover();
        for (uint256 i; i < rows.length; ++i) {
            if (
                i + 1 < rows.length && rows[i + 1].laneKind == rows[i].laneKind
                    && rows[i + 1].laneKey == rows[i].laneKey
            ) continue;
            (, bytes32[] memory proof) = _upProof(address(ingress), rows, i);
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

    function _upLeaves(History h) private view returns (HT.Leaf[] memory rows) {
        uint256 count = upMixed ? 3 : 1;
        uint256 total;
        for (uint256 i; i < count; ++i) {
            (uint8 kind, bytes32 key) = _upLane(i);
            (, uint64 n) = h.artistHistoryLane(kind, key);
            total += n;
        }
        rows = new HT.Leaf[](total);
        uint256 at;
        for (uint256 i; i < count; ++i) {
            (uint8 kind, bytes32 key) = _upLane(i);
            (, uint64 n) = h.artistHistoryLane(kind, key);
            for (uint64 j; j < n; ++j) {
                (bytes32 record, bytes32 chain) = h.artistHistoryRecordAt(kind, key, j);
                rows[at++] = HT.Leaf(kind, key, j, record, chain);
            }
        }
    }

    function _upLane(uint256 i) private view returns (uint8, bytes32) {
        if (!upMixed) return (2, bytes32(upCollection));
        return i == 0 ? (uint8(1), artistId) : (uint8(2), bytes32(i));
    }

    function _upPrepare(Successor memory next)
        internal
        view
        returns (RH.Request memory r, Commit.Prepared memory p)
    {
        r = _upRequest();
        p = Prepared.prepare(next.coordinator.suiteConfiguration(), r);
        r.expectedSemanticInventory = Prepared.inventory(p);
        for (uint8 i; i < 7; ++i) {
            (RH.ExportHeader memory h, Payload.Payload memory local) =
                Payload.decode(p.data[i].typedState, i);
            require(
                (h.requiredFeatures & 4194304) != 0
                    && (h.requiredFeatures & ~(uint256(4194304) | 31)) == 0,
                "closed explicit new feature mask"
            );
            (bytes32 tag, uint16 version, uint8 owner,) =
                abi.decode(local.semanticState, (bytes32, uint16, uint8, M.State));
            require(
                tag == keccak256("6529STREAM_ARTIST_UNBOUND_PLATFORM_HYDRATION_V1") && version == 1
                    && owner == i,
                "independent literal tag"
            );
        }
        require(p.admission.artists.length == (upMixed ? 1 : 0), "no invented Artist");
    }

    function _upImport(Successor memory next, RH.Request memory r, Commit.Prepared memory p)
        internal
        returns (bytes32 value)
    {
        bytes memory call_ = abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (r));
        bytes32 expected = _upCommitment(next, r, p);
        bytes32 payloadHash = _upProfileHash(r, p);
        UnboundTestVM v = UnboundTestVM(address(avm));
        v.recordLogs();
        require(this.executeTargetSafe(address(next.registry), call_), "actual Safe operation60");
        value = HydrationOwner(next.identity).authorityHydrationCommitment();
        require(value == expected, "independent full original operation60 commitment");
        UnboundTestVM.Log[] memory logs = v.getRecordedLogs();
        uint256 matched;
        bytes32 eventType =
            keccak256("RecoveredArtistAuthorityHydrated(uint16,address,bytes32,bytes32,bytes32)");
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics.length == 0 || logs[i].topics[0] != eventType) continue;
            require(
                logs[i].emitter == address(next.coordinator) && logs[i].topics.length == 4
                    && logs[i].topics[1] == bytes32(uint256(uint160(p.admission.prior)))
                    && logs[i].topics[2] == expected
                    && logs[i].topics[3] == r.expectedSemanticInventory
                    && keccak256(logs[i].data) == keccak256(abi.encode(uint16(1), payloadHash)),
                "literal original event context and complete profile bytes"
            );
            ++matched;
        }
        require(matched == 1, "exactly one original operation60 event");
        _upAssert(next, p, value);
    }

    function _upCommitment(Successor memory next, RH.Request memory r, Commit.Prepared memory p)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERED_AUTHORITY_HYDRATION_V1"),
                uint16(1),
                block.chainid,
                address(next.registry),
                address(next.coordinator),
                p.admission.prior,
                p.admission.sourceCoordinator,
                r,
                p.admission.artists,
                p.admission.collections,
                p.query,
                p.data,
                p.timing,
                p.externalGuards,
                p.admission.before_
            )
        );
    }

    function _upProfileHash(RH.Request memory r, Commit.Prepared memory p)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERED_AUTHORITY_HYDRATION_V1"),
                uint16(1),
                p.admission.prior,
                p.admission.sourceCoordinator,
                r,
                p.admission.artists,
                p.admission.collections,
                p.query,
                p.data,
                p.timing,
                p.externalGuards
            )
        );
    }

    function _upAssert(Successor memory next, Commit.Prepared memory p, bytes32 value)
        internal
        view
    {
        T.SuiteConfiguration memory dest = next.coordinator.suiteConfiguration();
        require(value != 0, "real import commitment");
        for (uint8 i; i < 7; ++i) {
            T.Snapshot memory after_ = Owner(dest.owners[i]).ownerStateSnapshotV2();
            require(
                after_.revision == p.admission.before_[i].revision + 1
                    && after_.recordChainTip == p.admission.before_[i].recordChainTip
                    && Native(dest.owners[i]).artistNativeReceiptCount() == 0
                    && HydrationOwner(dest.owners[i]).authorityHydrationCommitment() == value,
                "seven guarded single commits, no invented native receipt"
            );
            (RH.OwnerProvenance memory prefix, bytes32 imported, uint64 revision) =
                RecoveredOwner(dest.owners[i]).recoveredHydrationImportedPrefix();
            require(
                imported == value && revision == after_.revision
                    && keccak256(abi.encode(prefix))
                        == keccak256(abi.encode(RH.ownerProvenance(p.admission.provenance, i))),
                "full exact original provenance"
            );
        }
        require(
            keccak256(
                abi.encode(
                    IStreamArtistPlatformOwner(dest.owners[4]).platformWorksState(upCollection)
                )
            ) == keccak256(abi.encode(ingress.platformWorksState(upCollection))),
            "all original twenty Platform words"
        );
        // Compare immediately against the untouched predecessor. A later fresh claim must
        // never repair an omitted count or latest-display pointer before this assertion.
        (uint256 expectedCount, bytes32 expectedLatest) =
            UnboundAttributionDisplay(suite.owners[4]).attributionClaims(upCollection);
        (uint256 displayCount, bytes32 latest) =
            UnboundAttributionDisplay(dest.owners[4]).attributionClaims(upCollection);
        require(
            displayCount == expectedCount && latest == expectedLatest,
            "complete original destination display count/latest at import"
        );
        (uint256 staticCount, bytes32 staticLatest) =
            UnboundAttributionDisplay(dest.owners[4]).staticAttributionClaims(upCollection);
        (uint256 oldStaticCount, bytes32 oldStaticLatest) =
            UnboundAttributionDisplay(suite.owners[4]).staticAttributionClaims(upCollection);
        require(
            staticCount == oldStaticCount && staticLatest == oldStaticLatest
                && staticCount == expectedCount && staticLatest == expectedLatest,
            "direct STATIC display projection agrees immediately with original public state"
        );
        for (uint256 i; i < platformClaims.length; ++i) {
            require(
                keccak256(
                    abi.encode(
                        IStreamArtistPlatformOwner(dest.owners[4])
                            .platformWorksClaimRecord(platformClaims[i])
                    )
                ) == keccak256(abi.encode(ingress.platformWorksClaimRecord(platformClaims[i]))),
                "whole original claim"
            );
        }
        for (uint256 i; i < platformContests.length; ++i) {
            require(
                keccak256(
                    abi.encode(
                        IStreamArtistPlatformOwner(dest.owners[4])
                            .platformWorksContestRecord(platformContests[i])
                    )
                ) == keccak256(abi.encode(ingress.platformWorksContestRecord(platformContests[i]))),
                "whole governed contest"
            );
        }
        for (uint256 i; i < allegations.length; ++i) {
            require(
                keccak256(
                    abi.encode(
                        IStreamArtistAttributionClaimsOwner(dest.owners[4])
                            .attributionClaimRecord(allegations[i])
                    )
                )
                == keccak256(
                    abi.encode(
                        IStreamArtistAttributionClaimsOwner(suite.owners[4])
                            .attributionClaimRecord(allegations[i])
                    )
                ),
                "whole original allegation"
            );
        }
        require(
            IStreamArtistIdentityOwner(next.identity).nextRegistrationNonce() == (upMixed ? 1 : 0),
            "no principal allocation"
        );
        T.Binding memory zero;
        require(
            keccak256(abi.encode(Binding(dest.owners[0]).binding(upCollection)))
                    == keccak256(abi.encode(zero))
                && Acceptance(dest.owners[3]).acceptanceRecord(0) == 0,
            "no binding or acceptance invented"
        );
        (uint8 state, uint64 generation) =
            Attribution(dest.owners[4]).attributionState(upCollection);
        require(state == 0 && generation == 0, "unbound attribution remains zero");
        (bytes32 tip, uint64 count) =
            History(next.identity).artistHistoryLane(2, bytes32(upCollection));
        (bytes32 oldTip, uint64 oldCount) =
            History(address(ingress)).artistHistoryLane(2, bytes32(upCollection));
        require(tip == oldTip && count == oldCount, "exact original collection lane");
        if (upMixed) {
            require(
                keccak256(abi.encode(Binding(dest.owners[0]).binding(1)))
                    == keccak256(abi.encode(Binding(suite.owners[0]).binding(1))),
                "ordinary binding retained"
            );
            require(
                keccak256(abi.encode(IStreamArtistIdentityOwner(next.identity).identity(artistId)))
                    == keccak256(
                        abi.encode(IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId))
                    ),
                "complete ordinary recovered identity"
            );
            require(
                _rhRecoveryFacts(next.identity) == _rhRecoveryFacts(suite.owners[2]),
                "ordinary recovery and receipt associations retained"
            );
        }
    }

    function _upAdopt(Successor memory next) internal {
        ingress = next.registry;
        coordinator = next.coordinator;
        archive = next.archive;
        suite = next.coordinator.suiteConfiguration();
    }

    function _upPlatform(Commit.Prepared memory p)
        internal
        pure
        returns (M.State memory scope, Payload.Payload memory local, P.Platform memory b)
    {
        (scope, local) = UCodec.outer(4, p.query, p.data[4].typedState);
        b = abi.decode(scope.rows[scope.rows.length - 1], (P.Platform));
    }

    function upValidate(M.State calldata scope_, RH.OwnerProvenance calldata local_) external view {
        M.State memory s = scope_;
        RH.OwnerProvenance memory p = local_;
        URows.validate(4, s, p);
        for (uint256 i; i < s.collections.length; ++i) {
            if (s.collections[i].artistId == 0) {
                UTimeline.validate(abi.decode(s.rows[i], (P.Platform)), p);
            }
        }
    }

    function upEmpty(
        RH.OwnerProvenance calldata p,
        RH.NonceInventory[] calldata n,
        AH.Query[] calldata c,
        bytes calldata raw
    ) external pure {
        UEmpty.validate(p, n, c, raw);
    }

    function _hpEvidence(bytes32 claim, bytes32 narrative) internal returns (bytes32 hash) {
        if (address(documents) == address(0)) documents = new StreamSchemaDocumentStore();
        (hash,) = documents.publishChunk(
            abi.encode(PW.Evidence(1, upCollection, address(artist), claim, narrative))
        );
        avm.mockCall(
            address(metadata),
            abi.encodeCall(IStreamCollectionMetadataV1.core, ()),
            abi.encode(address(core))
        );
        avm.mockCall(
            address(metadata),
            abi.encodeCall(IStreamCollectionMetadataV1.chunkStore, ()),
            abi.encode(address(documents))
        );
        Archival.CoverageFacts memory facts;
        facts.coverageRecordHash = keccak256(abi.encode("typed collection coverage", hash));
        facts.envelopeHash = keccak256(abi.encode("typed Platform envelope", hash));
        facts.evidenceHash = hash;
        avm.mockCall(
            address(estateCoverageProvider),
            abi.encodeCall(
                IStreamCollectionArchivalCoverage.requireCollectionEvidence, (upCollection, hash)
            ),
            abi.encode(facts)
        );
    }

    function _hpGuard(uint16 op, bytes32 scope) internal {
        _rhCandidate(4, string(abi.encode("PLATFORM_WORKS", op)), scope);
    }

    function _hpClaim(bool allegation) internal returns (bytes32 record) {
        bytes32 evidence = _hpEvidence(0, keccak256(abi.encode("new original claim", ++upAction)));
        bytes32 scope = keccak256(abi.encode(upCollection, address(this), evidence, evidence));
        if (allegation) {
            record = ingress.fileAttributionClaim(
                upCollection, evidence, evidence, "urn:platform:allegation"
            );
            _rhCandidate(4, "attribution_lifecycle.replay.claim_record_hash_uniqueness", scope);
            allegations.push(record);
        } else {
            record = ingress.filePlatformWorksClaim(
                upCollection, evidence, evidence, "urn:platform:claim"
            );
            _hpGuard(9, scope);
            platformClaims.push(record);
        }
        require(
            record
                == keccak256(
                    abi.encode(
                        allegation
                            ? keccak256("6529STREAM_ARTIST_ATTRIBUTION_CLAIM_RECORD_V1")
                            : keccak256("6529STREAM_PLATFORM_WORKS_CLAIM_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(core),
                        upCollection,
                        address(this),
                        evidence,
                        evidence,
                        uint64(block.timestamp)
                    )
                ),
            "literal original claim preimage"
        );
    }

    function _hpContest(uint8 state, bytes32 claim, bool correction)
        internal
        returns (bytes32 record)
    {
        bytes32 evidence = _hpEvidence(
            claim, keccak256(abi.encode("exact Platform adjudication", ++upAction))
        );
        PW.Context memory c = ingress.platformWorksContext(
            upCollection, state, claim, evidence, evidence, correction
        );
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        authority.configureContestReads(
            suite.roleRegistry, address(artist), evidence, "urn:platform:resolution"
        );
        uint8 cls = correction ? 2 : 1;
        bytes32 action =
            keccak256(abi.encode("Platform actual action", address(ingress), upAction, c));
        bytes memory data = correction
            ? abi.encodeCall(
                IStreamArtistPlatformWorks.approvePlatformWorksCorrection,
                (upCollection, claim, evidence, evidence)
            )
            : abi.encodeCall(
                IStreamArtistPlatformWorks.setPlatformWorksContest,
                (upCollection, state, claim, evidence, evidence)
            );
        require(
            executeSafe(
                artist,
                keys,
                address(authority),
                0,
                abi.encodeCall(
                    ArtistUnitGovernance.executeModuleContextWithAction,
                    (
                        action,
                        address(ingress),
                        data,
                        cls,
                        c.scopeHash,
                        c.oldValueHash,
                        c.newValueHash
                    )
                ),
                0
            ),
            "actual Safe governed Platform producer"
        );
        (bool active,,,,,) = authority.currentAction();
        require(!active, "actual context cleared without persistent mock");
        _hpGuard(correction ? 53 : 11, keccak256(abi.encode(upCollection, action)));
        PW.State memory p = ingress.platformWorksState(upCollection);
        record = correction ? p.correction.recordHash : p.contestRecord;
        if (!correction) platformContests.push(record);
    }

    function _upNext() private returns (Successor memory next) {
        T.SuiteConfiguration memory s = suite;
        address governance = manager.governanceAuthority();
        ArtistSanctionFinalityFixture finalityFixture = new ArtistSanctionFinalityFixture();
        uint256 nonce = avm.getNonce(address(this));
        address registry_ = avm.computeCreateAddress(address(this), nonce);
        address archive_ = avm.computeCreateAddress(address(this), nonce + 1);
        address coordinator_ = avm.computeCreateAddress(address(this), nonce + 9);
        address identity_ = avm.computeCreateAddress(address(this), nonce + 4);
        address[3] memory facade;
        address[3] memory identity;
        for (uint8 i; i < 3; ++i) {
            facade[i] = artistExtensionFactory.deployRegistry(i + 4, registry_, coordinator_);
        }
        for (uint8 i; i < 3; ++i) {
            identity[i] = artistExtensionFactory.deployIdentity(
                i + 1, [identity_, registry_, coordinator_, archive_, s.core, s.mintManager]
            );
        }
        next.registry = StreamArtistOnboardingRegistry(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol:StreamArtistOnboardingRegistry",
                    abi.encode(
                        s.core,
                        s.mintManager,
                        coordinator_,
                        governance,
                        address(estateCoverageProvider),
                        keccak256("recovered successor deployment"),
                        "urn:recovered-successor",
                        keccak256("recovered successor manifest"),
                        address(artistExtensionFactory),
                        facade
                    )
                ))
        );
        next.archive = StreamArtistArchiveV2(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/artist/StreamArtistArchiveV2.sol:StreamArtistArchiveV2",
                    abi.encode(registry_, coordinator_)
                ))
        );
        s.registry = registry_;
        s.archive = archive_;
        string[7] memory artifacts_ = [
            "smart-contracts/domains/artist/StreamArtistBindingLifecycle.sol:StreamArtistBindingLifecycle",
            "smart-contracts/domains/artist/StreamArtistCollaboratorLifecycle.sol:StreamArtistCollaboratorLifecycle",
            "smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol:StreamArtistIdentityAuthority",
            "smart-contracts/domains/artist/StreamArtistAcceptanceLifecycle.sol:StreamArtistAcceptanceLifecycle",
            "smart-contracts/domains/artist/StreamArtistAttributionLifecycle.sol:StreamArtistAttributionLifecycle",
            "smart-contracts/domains/artist/StreamArtistPayoutLifecycle.sol:StreamArtistPayoutLifecycle",
            "smart-contracts/domains/artist/StreamArtistConsentFinalityLifecycle.sol:StreamArtistConsentFinalityLifecycle"
        ];
        for (uint8 i; i < 7; ++i) {
            bytes memory args = i == 2
                ? abi.encode(
                    registry_,
                    coordinator_,
                    archive_,
                    s.core,
                    s.mintManager,
                    address(artistExtensionFactory),
                    identity
                )
                : abi.encode(registry_, coordinator_, archive_, s.core, s.mintManager);
            s.owners[i] = _artistArtifactCreate(artifacts_[i], args);
        }
        ArtistUnitGovernance(governance)
            .configureContestReads(
                s.roleRegistry,
                address(artist),
                keccak256("recovered successor finality"),
                "urn:successor"
            );
        address finality = finalityFixture.deploy(s.core, s.metadata, registry_, governance);
        next.coordinator = StreamArtistOnboardingCoordinator(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/artist/StreamArtistOnboardingCoordinator.sol:StreamArtistOnboardingCoordinator",
                    abi.encode(s, finality)
                ))
        );
        next.identity = s.owners[2];
        require(
            address(next.registry) == registry_ && address(next.archive) == archive_
                && address(next.coordinator) == coordinator_ && next.identity == identity_,
            "actual successor deployment pins"
        );
    }

    function _upLeaf(address predecessor, HT.Leaf memory p) private view returns (bytes32) {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        MULTI_LEAF,
                        block.chainid,
                        predecessor,
                        p.laneKind,
                        p.laneKey,
                        p.sequence,
                        p.recordHash,
                        p.recordChainHash
                    )
                )
            )
        );
    }

    function _upProof(address predecessor, HT.Leaf[] memory leaves, uint256 index)
        private
        view
        returns (bytes32 root, bytes32[] memory proof)
    {
        bytes32[] memory layer = new bytes32[](leaves.length);
        proof = new bytes32[](64);
        uint256 used;
        uint256 n = leaves.length;
        for (uint256 i; i < n; ++i) {
            layer[i] = _upLeaf(predecessor, leaves[i]);
        }
        while (n > 1) {
            if ((index ^ 1) < n) proof[used++] = layer[index ^ 1];
            uint256 nextN = (n + 1) / 2;
            for (uint256 i; i < nextN; ++i) {
                uint256 j = i * 2;
                if (j + 1 == n) {
                    layer[i] = layer[j];
                } else {
                    bytes32 a = layer[j];
                    bytes32 b = layer[j + 1];
                    layer[i] = a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
                }
            }
            index /= 2;
            n = nextN;
        }
        root = layer[0];
        assembly ("memory-safe") { mstore(proof, used) }
    }
}
