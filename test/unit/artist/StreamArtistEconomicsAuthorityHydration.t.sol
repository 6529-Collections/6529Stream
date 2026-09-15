// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamArtistEconomicsAuthorityHydration as EconHydrate,
    IStreamArtistEconomicsAuthorityHydrationOwner as EconExport,
    StreamArtistEconomicsHydrationTypes as EH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEconomicsAuthorityHydration.sol";
import "../../../smart-contracts/domains/artist/StreamArtistEconomicsHydration.sol";
import "./ArtistOnboardingFixture.sol";
import {
    IStreamArtistPayoutAuthorityHydration as PayoutHydrate,
    StreamArtistPayoutHydrationTypes as PH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPayoutAuthorityHydration.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH,
    IStreamArtistAuthorityHydration as Hydrate,
    IStreamArtistAuthorityHydrationOwner as HydrationOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    IStreamArtistHistory as History,
    IStreamArtistHistoryOwner as HistoryOwner,
    IStreamArtistNativeReceipts as Native,
    StreamArtistHistoryTypes as HT
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import "../../../smart-contracts/core/StreamCoreExternalReads.sol";
import "../../../smart-contracts/domains/artist/StreamArtistHistoryState.sol";

/// @notice Actual two-registry/owner/Archive/Safe round-trip; Core and governance remain typed unit boundaries.
/// @dev Original Safe/Registry/seven-owner/Archive baseline; typed unit Core/governance, no commerce claim.
contract StreamArtistEconomicsAuthorityHydrationTest is ArtistOnboardingFixture {
    bytes32 private constant CHAIN =
        0x2eac9cfc5ca84fbeed56ef1741255e2ec7e45f48bc5c5ceda94397aa23d2f23e;
    bytes32 private constant LEAF =
        0xea04da6644046a7c731e99312c32df311e81aa7e137dfc2a49c2116bb325195d;
    bytes32 private constant POINTER = keccak256("ARTIST_REGISTRY");

    struct Next {
        StreamArtistOnboardingRegistry registry;
        StreamArtistArchiveV2 archive;
        StreamArtistOnboardingCoordinator coordinator;
        address identity;
    }

    AH.Origin[][7] private candidates;
    bytes32 private savedPolicy;
    bytes private savedPolicySignature;
    bytes32 private revokedDigest;

    T.EconomicsConsent[] private selectedEconomics;
    bytes32[] private selectedRecords;
    bytes private firstEconomicsSignature;

    function _economicHistory() private {
        _baseline();
        T.PayoutDesignation memory payout = T.PayoutDesignation(artistId, address(artist), 0);
        T.Authorization memory a = _authorization(true);
        bytes32 digest = ingress.payoutDesignationDigest(payout, a);
        _authOrigins(digest, a.nonce);
        a.signature = _signature(digest);
        _artistCall(abi.encodeCall(IStreamArtistOnboarding.recordPayoutDesignation, (payout, a)));
        _candidate(5, "payout_lifecycle.replay.designation_chain", keccak256(abi.encode(artistId)));
        (T.AssignmentFact memory first, T.AssignmentFact memory second) =
            coordinator.reads().currentAssignments(1);
        _approveEconomics(first);
        T.PolicyConsent memory policy =
            T.PolicyConsent(1, keccak256("second phase"), keccak256("interleaved policy"));
        a = _authorization(false);
        digest = ingress.policyConsentDigest(policy, a);
        _authOrigins(digest, a.nonce);
        a.signature = _signature(digest);
        _artistCall(abi.encodeCall(IStreamArtistOnboarding.recordPolicyConsent, (policy, a)));
        _candidate(
            6,
            "consent_finality.replay.policy_consent_key",
            keccak256(abi.encode(policy.collectionId, policy.phaseId, policy.policyHash))
        );
        _approveEconomics(second);
    }

    function _approveEconomics(T.AssignmentFact memory fact) private {
        T.EconomicsConsent memory p = T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.economicsConsentDigest(p, a);
        _authOrigins(digest, a.nonce);
        a.signature = _signature(digest);
        if (selectedEconomics.length == 0) firstEconomicsSignature = a.signature;
        _artistCall(abi.encodeCall(IStreamArtistOnboarding.recordEconomicsConsent, (p, a)));
        _candidate(6, "consent_finality.replay.consent_key", keccak256(abi.encode(p)));
        selectedEconomics.push(p);
        selectedRecords.push(IStreamArtistConsentOwner(suite.owners[6]).economicsRecord(p));
    }

    function _economicsRequest() private view returns (EH.Request memory p) {
        p.authority = _request();
        p.economics = selectedEconomics;
    }

    function _assertEconomics(Next memory n) private {
        T.SuiteConfiguration memory s = n.coordinator.suiteConfiguration();
        T.Binding memory binding_ = IStreamArtistBindingOwner(s.owners[0]).binding(1);
        for (uint256 j; j < selectedEconomics.length; ++j) {
            T.EconomicsConsent memory p = selectedEconomics[j];
            bytes32 record = selectedRecords[j];
            require(
                IStreamArtistConsentOwner(s.owners[6]).economicsRecord(p) == record,
                "original payload lookup"
            );
            require(
                IStreamArtistEconomicsEvidence(s.owners[6])
                    .economicsRecordForBinding(p, artistId, 1, binding_.bindingHash) == record,
                "exact carried current association"
            );
            require(
                keccak256(
                    abi.encode(
                        IStreamArtistEconomicsEvidence(s.owners[6])
                            .economicsRecordAssociation(record)
                    )
                )
                == keccak256(
                    abi.encode(
                        IStreamArtistEconomicsEvidence(suite.owners[6])
                            .economicsRecordAssociation(record)
                    )
                ),
                "whole original association retained"
            );
            vm.prank(p.resolver);
            n.registry
                .requireEconomicsConsent(1, p.revenueClass, p.scope, p.scopeId, p.assignmentHash);
            require(
                IStreamArtistEconomicsEvidence(s.owners[6])
                    .economicsRecordForBinding(p, artistId, 2, binding_.bindingHash) == 0,
                "no correction-generation authority invented"
            );
        }
        require(
            keccak256(IStreamArtistIdentityOwner(n.identity).signatureBundle(selectedRecords[0]))
                == keccak256(firstEconomicsSignature),
            "exact old domain signature bytes"
        );
    }

    function testEconomicsHydrationPreservesBothResolverApprovalsAndFreshSafeConsent() external {
        _economicHistory();
        Next memory n = _cutover(true, true);
        EH.Request memory p = _economicsRequest();
        require(
            EconHydrate(address(n.registry)).hydrateArtistAuthorityWithEconomics(p) != 0,
            "complete economics hydration"
        );
        _assertEconomics(n);
        T.EconomicsConsent memory approved = p.economics[0];
        T.Authorization memory a = T.Authorization(
            IStreamArtistIdentityOwner(n.identity).identity(artistId).nonceHint,
            uint64(block.timestamp),
            ""
        );
        bytes32 roots = _allRoots(n.coordinator);
        uint256 nonce = artist.nonce();
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(
            address(n.registry),
            abi.encodeCall(IStreamArtistOnboarding.recordEconomicsConsent, (approved, a))
        );
        require(
            artist.nonce() == nonce && _allRoots(n.coordinator) == roots,
            "consumed old payload cannot be reapproved with a fresh nonce"
        );
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](2);
        entries[0] = IStreamSplitWallet.SplitEntry(address(artist), 800000, keccak256("artist"));
        entries[1] = IStreamSplitWallet.SplitEntry(address(0xFEE), 200000, keccak256("protocol"));
        (bytes32 profile,) = factory.createProfile(entries, keccak256("successor future economics"));
        T.AssignmentFact memory fact = primary.previewArtistPrimaryAssignment(1, profile, 0, false);
        T.EconomicsConsent memory fresh =
            T.EconomicsConsent(1, address(primary), PRIMARY, 1, 1, fact.assignmentHash);
        T.FixedEconomicsCandidate memory candidate = T.FixedEconomicsCandidate(profile, 0, 0, false);
        require(
            this.executeTargetSafe(
                address(n.registry),
                abi.encodeCall(
                    IStreamArtistEconomicsAuthority.recordProspectiveEconomicsConsent,
                    (fresh, candidate, a)
                )
            ),
            "fresh successor original op15 Safe approval"
        );
        T.SuiteConfiguration memory s = n.coordinator.suiteConfiguration();
        bytes32 record = IStreamArtistConsentOwner(s.owners[6]).economicsRecord(fresh);
        require(
            record != 0 && record != selectedRecords[0]
                && IStreamArtistConsentOwner(suite.owners[6]).economicsRecord(fresh) == 0,
            "new successor-domain record, source untouched"
        );
        _assertEconomics(n);
    }

    function testEconomicsHydrationRejectsIncompleteSelectionAndStrictOlderProfiles() external {
        _economicHistory();
        Next memory n = _cutover(true, true);
        EH.Request memory p = _economicsRequest();
        avm.expectRevert(T.UnsupportedProfile.selector);
        Hydrate(address(n.registry)).hydrateArtistAuthority(p.authority);
        _notHydrated(n);
        avm.expectRevert(T.InvalidRecord.selector);
        PayoutHydrate(address(n.registry)).hydrateArtistAuthorityWithPayout(p.authority);
        _notHydrated(n);
        T.EconomicsConsent[] memory full = p.economics;
        p.economics = new T.EconomicsConsent[](1);
        p.economics[0] = full[0];
        avm.expectRevert(T.InvalidRecord.selector);
        EconHydrate(address(n.registry)).hydrateArtistAuthorityWithEconomics(p);
        _notHydrated(n);
        p.economics = full;
        p.economics[1] = full[0];
        avm.expectRevert(T.InvalidRecord.selector);
        EconHydrate(address(n.registry)).hydrateArtistAuthorityWithEconomics(p);
        _notHydrated(n);
        p = _economicsRequest();
        require(
            EconHydrate(address(n.registry)).hydrateArtistAuthorityWithEconomics(p) != 0,
            "complete exact selectors restored"
        );
    }

    function testEconomicsHydrationRejectsAssociationPayloadAndSourceHeadDrift() external {
        _economicHistory();
        Next memory n = _cutover(true, true);
        EH.Request memory p = _economicsRequest();
        AH.Query memory q;
        q.artistId = artistId;
        q.collectionId = 1;
        q.bindingHash = IStreamArtistBindingOwner(suite.owners[0]).binding(1).bindingHash;
        q.policies = p.authority.policies;
        EH.Bundle memory bundle = StreamArtistEconomicsHydration.decode(
            EconExport(suite.owners[6]).authorityEconomicsHydrationState(q, p.economics)
        );
        bundle.records[0].association.bindingGeneration = 2;
        avm.mockCall(
            suite.owners[6],
            abi.encodeWithSelector(EconExport.authorityEconomicsHydrationState.selector),
            abi.encode(abi.encode(bundle.schema, bundle.policies, bundle.records))
        );
        avm.expectRevert(T.InvalidRecord.selector);
        EconHydrate(address(n.registry)).hydrateArtistAuthorityWithEconomics(p);
        _notHydrated(n);
        avm.clearMockedCalls();
        avm.mockCall(
            suite.owners[6],
            abi.encodeCall(IStreamArtistConsentOwner.economicsRecord, (p.economics[0])),
            abi.encode(keccak256("foreign original payload head"))
        );
        avm.expectRevert(T.InvalidRecord.selector);
        EconHydrate(address(n.registry)).hydrateArtistAuthorityWithEconomics(p);
        _notHydrated(n);
        avm.clearMockedCalls();
        require(
            EconHydrate(address(n.registry)).hydrateArtistAuthorityWithEconomics(p) != 0,
            "identical request after exact source restoration"
        );
        _assertEconomics(n);
    }

    function testEconomicsHydrationLateArchiveRollsBackAndExactSafeRetry() external {
        _economicHistory();
        Next memory n = _cutover(true, true);
        EH.Request memory p = _economicsRequest();
        bytes memory data = abi.encodeCall(EconHydrate.hydrateArtistAuthorityWithEconomics, (p));
        bytes32 roots = _allRoots(n.coordinator);
        uint256 nonce = artist.nonce();
        avm.mockCallRevert(
            address(n.archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSignature("Error(string)", "economics hydration archive")
        );
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(n.registry), data);
        _notHydrated(n);
        require(
            artist.nonce() == nonce && _allRoots(n.coordinator) == roots,
            "no partial economics authority or Safe advance"
        );
        avm.clearMockedCalls();
        require(
            this.executeTargetSafe(address(n.registry), data), "byte-identical signed Safe retry"
        );
        _assertEconomics(n);
    }

    function _candidate(uint256 owner, string memory surface, bytes32 scope) private {
        candidates[owner].push(AH.Origin(keccak256(bytes(surface)), scope));
    }

    function _authOrigins(bytes32 digest, uint256 nonce) private {
        _candidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(artistId, digest))
        );
        _candidate(
            2, "identity_authority.replay.nonce_allocator", keccak256(abi.encode(artistId, nonce))
        );
    }

    function _baseline() private {
        _candidate(
            0, "binding_lifecycle.replay.proposal_key", keccak256(abi.encode(uint256(1), uint64(1)))
        );
        _candidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(abi.encode(bytes32(0), uint256(0)))
        );
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.acceptanceDigest(1, a);
        _authOrigins(digest, a.nonce);
        a.signature = _signature(digest);
        _artistCall(abi.encodeCall(IStreamArtistOnboarding.acceptArtistBinding, (1, a)));
        _candidate(
            3,
            "acceptance_lifecycle.replay.record_uniqueness",
            keccak256(abi.encode(uint256(1), uint64(1), uint8(1), address(artist)))
        );
        T.PolicyConsent memory p = T.PolicyConsent(1, PHASE, POLICY);
        a = _authorization(false);
        digest = ingress.policyConsentDigest(p, a);
        _authOrigins(digest, a.nonce);
        a.signature = _signature(digest);
        savedPolicySignature = a.signature;
        _artistCall(abi.encodeCall(IStreamArtistOnboarding.recordPolicyConsent, (p, a)));
        savedPolicy = IStreamArtistConsentOwner(suite.owners[6]).policyRecord(1, PHASE, POLICY);
        _candidate(
            6,
            "consent_finality.replay.policy_consent_key",
            keccak256(abi.encode(uint256(1), PHASE, POLICY))
        );
        _revoke(StreamArtistAuthorizationTypes.Revocation(artistId, 0, 257));
        revokedDigest = keccak256("exact digest already revoked at the predecessor");
        _revoke(StreamArtistAuthorizationTypes.Revocation(artistId, revokedDigest, 0));
        _candidate(2, "identity_authority.replay.one_way_cutover_latch", 0);
    }

    function _revoke(StreamArtistAuthorizationTypes.Revocation memory p) private {
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.authorizationRevocationDigest(p, a);
        _authOrigins(digest, a.nonce);
        a.signature = _signature(digest);
        ingress.revokeArtistAuthorization(p, a);
        _candidate(
            2,
            "identity_authority.replay.target_authorization_revocation",
            keccak256(abi.encode(artistId, p.revokedDigest, p.revokedNonce))
        );
        if (p.revokedDigest == 0) {
            _candidate(
                2,
                "identity_authority.replay.nonce_allocator",
                keccak256(abi.encode(artistId, p.revokedNonce))
            );
        } else {
            _candidate(
                2,
                "identity_authority.replay.digest_revocation",
                keccak256(abi.encode(artistId, p.revokedDigest))
            );
        }
    }

    function _sourceKey(uint256 owner, AH.Origin memory o) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                address(ingress),
                address(coordinator),
                address(archive),
                suite.owners[owner],
                IStreamArtistOwner(suite.owners[owner]).domainId(),
                o.surface,
                o.scope
            )
        );
    }

    function _request() private view returns (AH.Request memory p) {
        p.artistId = artistId;
        p.collectionId = 1;
        p.policies = new AH.PolicyKey[](2);
        p.policies[0] = AH.PolicyKey(PHASE, POLICY);
        p.policies[1] = AH.PolicyKey(keccak256("second phase"), keccak256("interleaved policy"));
        for (uint256 owner; owner < 7; ++owner) {
            p.expectedSource[owner] = CP(suite.owners[owner]).authorityCheckpoint();
            p.replayOrigins[owner] = new AH.Origin[](p.expectedSource[owner].replayCount);
            for (uint256 j; j < p.expectedSource[owner].replayCount; ++j) {
                (bytes32 key,) = CP(suite.owners[owner]).authorityReplayAt(j);
                bool found;
                for (uint256 k; k < candidates[owner].length; ++k) {
                    if (_sourceKey(owner, candidates[owner][k]) == key) {
                        p.replayOrigins[owner][j] = candidates[owner][k];
                        found = true;
                        break;
                    }
                }
                require(found, "independent preimage exists for every actual source guard");
            }
        }
    }

    function _cutover(bool seal, bool latchCollection) private returns (Next memory n) {
        n = _next();
        HT.Leaf[] memory rows = _leaves(History(address(ingress)));
        (bytes32 root,) = _proof(address(ingress), rows, 0);
        _commit(n, root, keccak256("complete baseline manifest"));
        core.set(POINTER, address(n.registry), false);
        if (seal) History(address(ingress)).observeRegistryCutover();
        (, uint64 count) = History(address(ingress)).artistHistoryLane(1, artistId);
        (, bytes32[] memory proof) = _proof(address(ingress), rows, count - 1);
        History(address(n.registry)).verifyImportedLaneTip(0, rows[count - 1], proof);
        if (latchCollection) {
            (, proof) = _proof(address(ingress), rows, rows.length - 1);
            History(address(n.registry)).verifyImportedLaneTip(0, rows[rows.length - 1], proof);
        }
    }

    function _allRoots(StreamArtistOnboardingCoordinator c) private view returns (bytes32) {
        T.SuiteConfiguration memory s = c.suiteConfiguration();
        T.Snapshot[7] memory snapshots;
        for (uint256 j; j < 7; ++j) {
            snapshots[j] = IStreamArtistOwner(s.owners[j]).ownerStateSnapshotV2();
        }
        return keccak256(abi.encode(snapshots));
    }

    function _notHydrated(Next memory n) private view {
        T.SuiteConfiguration memory s = n.coordinator.suiteConfiguration();
        for (uint256 j; j < 7; ++j) {
            require(
                HydrationOwner(s.owners[j]).authorityHydrationCommitment() == 0,
                "no partial owner activation"
            );
        }
        require(
            IStreamArtistIdentityOwner(n.identity).identity(artistId).authorityAddress
                == address(0),
            "no living default authority"
        );
    }

    function _leaves(History h) private view returns (HT.Leaf[] memory rows) {
        (, uint64 a) = h.artistHistoryLane(1, artistId);
        (, uint64 b) = h.artistHistoryLane(2, bytes32(uint256(1)));
        rows = new HT.Leaf[](uint256(a) + b);
        for (uint64 i; i < a; ++i) {
            (bytes32 r, bytes32 c) = h.artistHistoryRecordAt(1, artistId, i);
            rows[i] = HT.Leaf(1, artistId, i, r, c);
        }
        for (uint64 i; i < b; ++i) {
            (bytes32 r, bytes32 c) = h.artistHistoryRecordAt(2, bytes32(uint256(1)), i);
            rows[uint256(a) + i] = HT.Leaf(2, bytes32(uint256(1)), i, r, c);
        }
    }

    function _leaf(address predecessor, HT.Leaf memory p) private view returns (bytes32) {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        LEAF,
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

    function _proof(address predecessor, HT.Leaf[] memory leaves, uint256 index)
        private
        view
        returns (bytes32 root, bytes32[] memory proof)
    {
        bytes32[] memory layer = new bytes32[](leaves.length);
        proof = new bytes32[](64);
        uint256 used;
        uint256 n = leaves.length;
        for (uint256 i; i < n; ++i) {
            layer[i] = _leaf(predecessor, leaves[i]);
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

    function _commitData(Next memory n, bytes32 root, bytes32 manifest, uint8 cls, bool wrong)
        private
        view
        returns (bytes memory)
    {
        HT.Context memory x = History(address(n.registry))
            .artistHistoryImportContext(address(ingress), uint64(block.number), root, manifest);
        return abi.encodeCall(
            ArtistUnitGovernance.executeModuleContext,
            (
                address(n.registry),
                abi.encodeCall(
                    History.commitArtistHistoryImportRoot,
                    (address(ingress), uint64(block.number), root, manifest)
                ),
                cls,
                x.scopeHash,
                wrong ? keccak256("wrong import state") : x.oldValueHash,
                x.newValueHash
            )
        );
    }

    function _commit(Next memory n, bytes32 root, bytes32 manifest) private {
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(artist), manifest, "urn:history"
        );
        bytes memory data = _commitData(n, root, manifest, 1, false);
        vm.recordLogs();
        require(
            this.executeTargetSafe(address(authority), data),
            "actual threshold Safe executes typed governance context"
        );
        _historyEvent(
            vm.getRecordedLogs(),
            n.identity,
            keccak256(
                "ArtistHistoryImportRootCommitted(uint16,address,bytes32,uint64,bytes32,bytes32)"
            ),
            bytes32(uint256(uint160(address(ingress)))),
            root,
            abi.encode(
                uint16(1), uint64(block.number), manifest, keccak256("unit authority gas raise")
            )
        );
    }

    function _historyEvent(
        Vm.Log[] memory logs,
        address emitter,
        bytes32 topic,
        bytes32 first,
        bytes32 second,
        bytes memory expected
    ) private pure {
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory entry = logs[i];
            if (entry.emitter != emitter || entry.topics.length == 0 || entry.topics[0] != topic) {
                continue;
            }
            ++found;
            require(
                entry.topics.length == (second == 0 ? 2 : 3) && entry.topics[1] == first,
                "exact original event emitter/topics"
            );
            if (second != 0) require(entry.topics[2] == second, "exact second indexed word");
            require(
                keccak256(entry.data) == keccak256(expected),
                "independent complete normative event data"
            );
        }
        require(found == 1, "one original normative import event");
    }

    function _next() private returns (Next memory n) {
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
        n.registry = new StreamArtistOnboardingRegistry(
            s.core,
            s.mintManager,
            coordinator_,
            governance,
            address(estateCoverageProvider),
            keccak256("successor deployment"),
            "urn:successor",
            keccak256("successor manifest"),
            address(artistExtensionFactory),
            facade
        );
        n.archive = new StreamArtistArchiveV2(registry_, coordinator_);
        s.registry = registry_;
        s.archive = archive_;
        s.owners[0] = address(
            new StreamArtistBindingLifecycle(
                registry_, coordinator_, archive_, s.core, s.mintManager
            )
        );
        s.owners[1] = address(
            new StreamArtistCollaboratorLifecycle(
                registry_, coordinator_, archive_, s.core, s.mintManager
            )
        );
        s.owners[2] = address(
            new StreamArtistIdentityAuthority(
                registry_,
                coordinator_,
                archive_,
                s.core,
                s.mintManager,
                address(artistExtensionFactory),
                identity
            )
        );
        s.owners[3] = address(
            new StreamArtistAcceptanceLifecycle(
                registry_, coordinator_, archive_, s.core, s.mintManager
            )
        );
        s.owners[4] = address(
            new StreamArtistAttributionLifecycle(
                registry_, coordinator_, archive_, s.core, s.mintManager
            )
        );
        s.owners[5] = address(
            new StreamArtistPayoutLifecycle(
                registry_, coordinator_, archive_, s.core, s.mintManager
            )
        );
        s.owners[6] = address(
            new StreamArtistConsentFinalityLifecycle(
                registry_, coordinator_, archive_, s.core, s.mintManager
            )
        );
        ArtistUnitGovernance(governance)
            .configureContestReads(
                s.roleRegistry, address(artist), keccak256("successor finality"), "urn:successor"
            );
        address finality = finalityFixture.deploy(s.core, s.metadata, registry_, governance);
        n.coordinator = new StreamArtistOnboardingCoordinator(s, finality);
        n.identity = s.owners[2];
        require(
            address(n.registry) == registry_ && address(n.archive) == archive_
                && address(n.coordinator) == coordinator_ && n.identity == identity_,
            "actual successor pins"
        );
    }
}
