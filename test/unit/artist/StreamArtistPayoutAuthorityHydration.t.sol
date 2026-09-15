// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
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
contract StreamArtistPayoutAuthorityHydrationTest is ArtistOnboardingFixture {
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

    bytes32 private firstPayout;
    bytes32 private finalPayout;
    bytes private firstSignature;

    function _payoutHistory() private {
        _baseline();
        firstPayout = _payoutTo(address(0xB001));
        firstSignature = IStreamArtistIdentityOwner(suite.owners[2]).signatureBundle(firstPayout);
        finalPayout = _payoutTo(address(0xB002));
        _candidate(5, "payout_lifecycle.replay.designation_chain", keccak256(abi.encode(artistId)));
    }

    function _payoutTo(address account) private returns (bytes32 record) {
        (, bytes32 prior) = ingress.artistPayoutAccount(artistId);
        T.PayoutDesignation memory p = T.PayoutDesignation(artistId, account, prior);
        T.Authorization memory a = _authorization(true);
        bytes32 digest = ingress.payoutDesignationDigest(p, a);
        _authOrigins(digest, a.nonce);
        a.signature = _signature(digest);
        _artistCall(abi.encodeCall(IStreamArtistOnboarding.recordPayoutDesignation, (p, a)));
        (, record) = ingress.artistPayoutAccount(artistId);
    }

    function testPayoutHydrationRetainsFullLinearHistoryAndFreshSafeUpdate() external {
        _payoutHistory();
        Next memory n = _cutover(true, true);
        AH.Request memory p = _request();
        require(
            PayoutHydrate(address(n.registry)).hydrateArtistAuthorityWithPayout(p) != 0,
            "complete payout profile"
        );
        T.SuiteConfiguration memory s = n.coordinator.suiteConfiguration();
        (address account, bytes32 current) = n.registry.artistPayoutAccount(artistId);
        require(
            account == address(0xB002) && current == finalPayout,
            "original operative payout, no signer fallback"
        );
        T.PayoutDesignation memory first =
            IStreamArtistPayoutOwner(s.owners[5]).designationRecord(firstPayout);
        T.PayoutDesignation memory last =
            IStreamArtistPayoutOwner(s.owners[5]).designationRecord(finalPayout);
        require(
            first.artistId == artistId && first.payoutAccount == address(0xB001)
                && first.previousDesignationRecordHash == 0
                && last.previousDesignationRecordHash == firstPayout,
            "complete immutable linear predecessor chain"
        );
        require(
            keccak256(IStreamArtistIdentityOwner(n.identity).signatureBundle(firstPayout))
                == keccak256(firstSignature),
            "exact original historical signature bytes"
        );
        (bytes32 sourceKey, T.ReplayCell memory original) = CP(suite.owners[5]).authorityReplayAt(0);
        T.ReplayCell memory saved =
            StreamArtistOwner(s.owners[5]).importedAuthorityReplayCell(sourceKey);
        require(
            keccak256(abi.encode(saved)) == keccak256(abi.encode(original)) && saved.kind == 3
                && saved.status == 1 && saved.commitment == finalPayout,
            "original mutable chain cell retained"
        );
        uint256 nonce = IStreamArtistIdentityOwner(n.identity).identity(artistId).nonceHint;
        T.PayoutDesignation memory next = T.PayoutDesignation(
            artistId, address(0xB003), finalPayout
        );
        T.Authorization memory a = T.Authorization(nonce, uint64(block.timestamp), "");
        uint256 safeNonce = artist.nonce();
        bytes32 before_ = _allRoots(n.coordinator);
        next.previousDesignationRecordHash = firstPayout;
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(
            address(n.registry),
            abi.encodeCall(IStreamArtistOnboarding.recordPayoutDesignation, (next, a))
        );
        require(
            artist.nonce() == safeNonce && _allRoots(n.coordinator) == before_,
            "stale prior hash rolls back authorization and Safe"
        );
        next.previousDesignationRecordHash = finalPayout;
        require(
            this.executeTargetSafe(
                address(n.registry),
                abi.encodeCall(IStreamArtistOnboarding.recordPayoutDesignation, (next, a))
            ),
            "actual Safe signs successor payout update"
        );
        (account, current) = n.registry.artistPayoutAccount(artistId);
        require(account == address(0xB003) && current != finalPayout, "new current head");
        require(
            IStreamArtistPayoutOwner(s.owners[5])
            .designationRecord(current)
            .previousDesignationRecordHash == finalPayout,
            "old source record remains exact parent"
        );
        (, bytes32 unchanged) = ingress.artistPayoutAccount(artistId);
        require(unchanged == finalPayout, "sealed source not mutated");
    }

    function testOriginalBaselineStillRejectsPayoutHistoryAndStaleMutableHeader() external {
        _payoutHistory();
        Next memory n = _cutover(true, true);
        AH.Request memory p = _request();
        avm.expectRevert(T.UnsupportedProfile.selector);
        Hydrate(address(n.registry)).hydrateArtistAuthority(p);
        _notHydrated(n);
        bytes32 root = p.expectedSource[5].replayRoot;
        p.expectedSource[5].replayRoot = keccak256("prior mutable chain head");
        avm.expectRevert(T.InvalidRecord.selector);
        PayoutHydrate(address(n.registry)).hydrateArtistAuthorityWithPayout(p);
        _notHydrated(n);
        p.expectedSource[5].replayRoot = root;
        require(
            PayoutHydrate(address(n.registry)).hydrateArtistAuthorityWithPayout(p) != 0,
            "same complete source with correct latest header"
        );
    }

    function testPayoutHydrationRejectsAdvertisedForeignRecordAndProvisionalAssociation() external {
        _payoutHistory();
        Next memory n = _cutover(true, true);
        AH.Request memory p = _request();
        AH.Query memory q;
        q.artistId = artistId;
        bytes memory original = HydrationOwner(suite.owners[5]).authorityHydrationState(q);
        PH.Bundle memory changed = abi.decode(original, (PH.Bundle));
        changed.records[0].terms.payoutAccount = address(0xDEAD);
        avm.mockCall(
            suite.owners[5],
            abi.encodeWithSelector(HydrationOwner.authorityHydrationState.selector),
            abi.encode(abi.encode(changed))
        );
        avm.expectRevert(T.InvalidRecord.selector);
        PayoutHydrate(address(n.registry)).hydrateArtistAuthorityWithPayout(p);
        _notHydrated(n);
        avm.clearMockedCalls();
        avm.mockCall(
            suite.owners[5],
            abi.encodeCall(
                IStreamArtistPayoutTransitionOwner.payoutDesignationProvisionalAssociation,
                (firstPayout)
            ),
            abi.encode(R.ProvisionalAssociation(keccak256("foreign provisional rotation"), 2000))
        );
        avm.expectRevert(T.UnsupportedProfile.selector);
        PayoutHydrate(address(n.registry)).hydrateArtistAuthorityWithPayout(p);
        _notHydrated(n);
        avm.clearMockedCalls();
        require(
            PayoutHydrate(address(n.registry)).hydrateArtistAuthorityWithPayout(p) != 0,
            "exact source restoration accepts original request"
        );
    }

    function testPayoutHydrationLateArchiveIdenticalSafeRetryPreservesEverySourceRecord() external {
        _payoutHistory();
        Next memory n = _cutover(true, true);
        AH.Request memory p = _request();
        bytes memory data = abi.encodeCall(PayoutHydrate.hydrateArtistAuthorityWithPayout, (p));
        bytes32 roots = _allRoots(n.coordinator);
        uint256 nonce = artist.nonce();
        avm.mockCallRevert(
            address(n.archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSignature("Error(string)", "payout hydration archive")
        );
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(n.registry), data);
        require(
            _allRoots(n.coordinator) == roots && artist.nonce() == nonce,
            "whole profile and actual Safe rollback"
        );
        _notHydrated(n);
        avm.clearMockedCalls();
        require(
            this.executeTargetSafe(address(n.registry), data),
            "byte-identical payout hydration Safe retry"
        );
        (address account, bytes32 record) = n.registry.artistPayoutAccount(artistId);
        require(
            account == address(0xB002) && record == finalPayout, "original source head after retry"
        );
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
        p.policies = new AH.PolicyKey[](1);
        p.policies[0] = AH.PolicyKey(PHASE, POLICY);
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
