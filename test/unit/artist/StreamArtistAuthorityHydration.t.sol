// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistOnboardingFixture.sol";
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
contract StreamArtistAuthorityHydrationTest is ArtistOnboardingFixture {
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

    function testActualCompleteHydrationPreservesOldReadsThenSafeWritesExtendImportedLanes()
        external
    {
        _baseline();
        Next memory n = _cutover(true, true);
        AH.Request memory p = _request();
        bytes32 priorRoots = _allRoots(n.coordinator);
        vm.recordLogs();
        bytes32 value = Hydrate(address(n.registry)).hydrateArtistAuthority(p);
        _hydrationEvidence(n, p, value, priorRoots, vm.getRecordedLogs());
        T.SuiteConfiguration memory s = n.coordinator.suiteConfiguration();
        require(value != 0, "complete profile commitment");
        for (uint256 j; j < 7; ++j) {
            require(
                HydrationOwner(s.owners[j]).authorityHydrationCommitment() == value,
                "all seven commit same profile"
            );
        }
        require(
            keccak256(abi.encode(n.coordinator.reads().acceptedBinding(1)))
                == keccak256(abi.encode(coordinator.reads().acceptedBinding(1))),
            "exact original binding and generation"
        );
        require(
            IStreamArtistConsentOwner(s.owners[6]).policyRecord(1, PHASE, POLICY) == savedPolicy,
            "original policy record hash retained"
        );
        require(
            keccak256(IStreamArtistIdentityOwner(n.identity).signatureBundle(savedPolicy))
                == keccak256(savedPolicySignature),
            "original retained signature bytes, not new authorization"
        );
        StreamArtistAuthorizationTypes.State memory state =
            n.registry.artistAuthorizationState(artistId, revokedDigest, 257);
        require(
            state.digestRevoked && state.nonceRevoked && state.nonceConsumed,
            "carried exact digest and sparse revoked nonce"
        );
        uint256 nonce = IStreamArtistIdentityOwner(n.identity).identity(artistId).nonceHint;
        T.PolicyConsent memory next = T.PolicyConsent(1, PHASE, keccak256("successor policy"));
        T.Authorization memory a = T.Authorization(nonce, uint64(block.timestamp + 1 days), "");
        (bytes32 beforeTip, uint64 count) =
            History(address(n.registry)).artistHistoryLane(1, artistId);
        require(
            this.executeTargetSafe(
                address(n.registry),
                abi.encodeCall(IStreamArtistOnboarding.recordPolicyConsent, (next, a))
            ),
            "actual Safe successor write"
        );
        bytes32 record =
            IStreamArtistConsentOwner(s.owners[6]).policyRecord(1, PHASE, next.policyHash);
        (bytes32 tip, uint64 afterCount) =
            History(address(n.registry)).artistHistoryLane(1, artistId);
        require(
            record != 0 && afterCount == count + 1
                && tip == keccak256(abi.encode(CHAIN, beforeTip, record)),
            "original accumulator extends latched prefix"
        );
        (bytes32 oldRecord, bytes32 oldChain) =
            History(address(ingress)).artistHistoryRecordAt(1, artistId, 0);
        (bytes32 imported, bytes32 importedChain) =
            History(address(n.registry)).artistHistoryRecordAt(1, artistId, 0);
        require(
            oldRecord == imported && oldChain == importedChain, "prefix index remains historical"
        );
        (bytes32 suffix,) = History(address(n.registry)).artistHistoryRecordAt(1, artistId, count);
        require(suffix == record, "native suffix at original offset");
        // The sealed predecessor's latch must not preconsume the successor's own later cutover.
        core.set(POINTER, address(ingress), false);
        History(address(n.registry)).observeRegistryCutover();
        (bool done,,) = History(address(n.registry)).artistRegistryCutover();
        require(done, "distinct successor cutover latch");
    }

    function testHydrationRejectsMissingOwnerGuardAndChangedNonceHeaderWithoutPartialState()
        external
    {
        _baseline();
        Next memory n = _cutover(true, true);
        AH.Request memory p = _request();
        bytes32 roots = _allRoots(n.coordinator);
        AH.Origin[] memory saved = p.replayOrigins[2];
        p.replayOrigins[2] = new AH.Origin[](saved.length - 1);
        avm.expectRevert(T.InvalidRecord.selector);
        Hydrate(address(n.registry)).hydrateArtistAuthority(p);
        _notHydrated(n);
        p.replayOrigins[2] = saved;
        AH.PolicyKey[] memory policies = p.policies;
        p.policies = new AH.PolicyKey[](0);
        avm.expectRevert(T.InvalidRecord.selector);
        Hydrate(address(n.registry)).hydrateArtistAuthority(p);
        p.policies = policies;
        p.expectedSource[2].nonceRoot = keccak256("omitted nonce history");
        avm.expectRevert(T.InvalidRecord.selector);
        Hydrate(address(n.registry)).hydrateArtistAuthority(p);
        require(_allRoots(n.coordinator) == roots, "whole seven-owner snapshot remains");
        _notHydrated(n);
    }

    function testHydrationRequiresCompletedSourceSealAndBothPermanentLaneLatches() external {
        _baseline();
        Next memory n = _cutover(false, false);
        AH.Request memory p = _request();
        avm.expectRevert(T.InvalidBinding.selector);
        Hydrate(address(n.registry)).hydrateArtistAuthority(p);
        _notHydrated(n);
        History(address(ingress)).observeRegistryCutover();
        p = _request();
        avm.expectRevert(T.InvalidRecord.selector);
        Hydrate(address(n.registry)).hydrateArtistAuthority(p);
        _notHydrated(n);
    }

    function testHydrationForeignReplayOriginAndChangedPinnedSourceAreTerminal() external {
        _baseline();
        Next memory n = _cutover(true, true);
        AH.Request memory p = _request();
        bytes32 original = p.replayOrigins[2][0].scope;
        p.replayOrigins[2][0].scope = keccak256("foreign logical guard");
        avm.expectRevert(T.InvalidRecord.selector);
        Hydrate(address(n.registry)).hydrateArtistAuthority(p);
        p.replayOrigins[2][0].scope = original;
        bytes memory code = suite.owners[6].code;
        vm.etch(suite.owners[6], hex"00");
        vm.expectRevert(abi.encodeWithSelector(T.ComponentChanged.selector, suite.owners[6]));
        Hydrate(address(n.registry)).hydrateArtistAuthority(p);
        vm.etch(suite.owners[6], code);
        _notHydrated(n);
        require(
            Hydrate(address(n.registry)).hydrateArtistAuthority(p) != 0,
            "restored exact source permits unchanged request"
        );
    }

    function testHydrationLateArchiveRollsBackAllOwnersAndExactSafeRetry() external {
        _baseline();
        Next memory n = _cutover(true, true);
        AH.Request memory p = _request();
        bytes memory data = abi.encodeCall(Hydrate.hydrateArtistAuthority, (p));
        bytes32 roots = _allRoots(n.coordinator);
        uint256 nonce = artist.nonce();
        avm.mockCallRevert(
            address(n.archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSignature("Error(string)", "late hydration archive")
        );
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(n.registry), data);
        require(
            artist.nonce() == nonce && _allRoots(n.coordinator) == roots,
            "Safe and every owner roll back"
        );
        _notHydrated(n);
        avm.clearMockedCalls();
        require(
            this.executeTargetSafe(address(n.registry), data), "byte-identical Safe hydration retry"
        );
        require(artist.nonce() == nonce + 1, "one actual successful Safe operation");
        avm.expectRevert(T.InvalidRecord.selector);
        Hydrate(address(n.registry)).hydrateArtistAuthority(p);
    }

    function testHydrationPreservesOldNonceRefusalAndRejectsPredecessorDomainSignature() external {
        _baseline();
        Next memory n = _cutover(true, true);
        AH.Request memory p = _request();
        Hydrate(address(n.registry)).hydrateArtistAuthority(p);
        uint256 hint = IStreamArtistIdentityOwner(n.identity).identity(artistId).nonceHint;
        bytes32 before_ = _allRoots(n.coordinator);
        T.PolicyConsent memory usedPolicy = T.PolicyConsent(1, PHASE, POLICY);
        T.Authorization memory usedA = T.Authorization(hint, uint64(block.timestamp + 1 days), "");
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(
            address(n.registry),
            abi.encodeCall(IStreamArtistOnboarding.recordPolicyConsent, (usedPolicy, usedA))
        );
        require(
            _allRoots(n.coordinator) == before_
                && IStreamArtistIdentityOwner(n.identity).identity(artistId).nonceHint == hint,
            "original policy-scope replay rolls back new authorization nonce"
        );
        T.PolicyConsent memory policy = T.PolicyConsent(1, PHASE, keccak256("fresh signed policy"));
        T.Authorization memory a = T.Authorization(257, uint64(block.timestamp + 1 days), "");
        bytes32 digest = n.registry.policyConsentDigest(policy, a);
        a.signature = safeThresholdSignature(keys, safeMessageDigest(artist, abi.encode(digest)));
        avm.expectPartialRevert(T.Replay.selector);
        n.registry.recordPolicyConsent(policy, a);
        a.nonce = 1000;
        bytes32 oldDigest = ingress.policyConsentDigest(policy, a);
        a.signature = safeThresholdSignature(keys, safeMessageDigest(artist, abi.encode(oldDigest)));
        avm.expectRevert(T.InvalidSignature.selector);
        n.registry.recordPolicyConsent(policy, a);
        bytes32 nextDigest = n.registry.policyConsentDigest(policy, a);
        require(oldDigest != nextDigest, "different original registry signature domain");
        a.signature = safeThresholdSignature(
            keys, safeMessageDigest(artist, abi.encode(nextDigest))
        );
        require(
            n.registry.recordPolicyConsent(policy, a) != 0,
            "fresh successor signature succeeds with same otherwise-unused nonce"
        );
    }

    function testHydrationRejectsAdditionalGuardianHistoryAndOmittedPolicyDependency() external {
        _baseline();
        _selfGuardian();
        Next memory n = _cutover(true, true);
        AH.Request memory p;
        p.artistId = artistId;
        p.collectionId = 1;
        p.policies = new AH.PolicyKey[](1);
        p.policies[0] = AH.PolicyKey(PHASE, POLICY);
        for (uint256 j; j < 7; ++j) {
            p.expectedSource[j] = CP(suite.owners[j]).authorityCheckpoint();
        }
        avm.expectRevert(T.UnsupportedProfile.selector);
        Hydrate(address(n.registry)).hydrateArtistAuthority(p);
        _notHydrated(n);
    }

    function _hydrationEvidence(
        Next memory n,
        AH.Request memory p,
        bytes32 value,
        bytes32 prior,
        Vm.Log[] memory logs
    ) private view {
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(n.registry),
                address(n.coordinator),
                uint16(60),
                address(this),
                value
            )
        );
        (
            uint16 schema,
            bytes32 configuration,
            uint16 op,
            address actor,
            bytes32 record,
            T.Snapshot[7] memory before_,
            T.Snapshot[7] memory after_,
            bytes memory payload
        ) = abi.decode(
            n.archive.artistEvidenceBytesV2(id, 1),
            (uint16, bytes32, uint16, address, bytes32, T.Snapshot[7], T.Snapshot[7], bytes)
        );
        require(
            schema == 1 && op == 60 && actor == address(this) && record == value
                && configuration == n.coordinator.configurationHash(),
            "original atomic operation envelope"
        );
        require(
            keccak256(abi.encode(before_)) == prior
                && keccak256(abi.encode(after_)) == _allRoots(n.coordinator),
            "all seven exact owner snapshots"
        );
        for (uint256 j; j < 7; ++j) {
            require(
                before_[j].domainId != 0 && after_[j].revision == before_[j].revision + 1,
                "explicit seven-owner write mask"
            );
        }
        (
            bytes32 profile,
            address predecessor,
            address priorCoordinator,
            CP.Checkpoint[7] memory sourceHeaders,
            AH.Query memory query,
            AH.OwnerData[7] memory data
        ) =
            abi.decode(
                payload, (bytes32, address, address, CP.Checkpoint[7], AH.Query, AH.OwnerData[7])
            );
        AH.Request memory original;
        original.artistId = query.artistId;
        original.collectionId = query.collectionId;
        original.expectedSource = sourceHeaders;
        original.policies = query.policies;
        for (uint256 j; j < 7; ++j) {
            original.replayOrigins[j] = data[j].origins;
        }
        require(
            profile == keccak256("6529STREAM_ARTIST_LIVING_BASELINE_HYDRATION_V1")
                && predecessor == address(ingress) && priorCoordinator == address(coordinator)
                && keccak256(abi.encode(original)) == keccak256(abi.encode(p)),
            "complete source headers and original request"
        );
        require(
            value
                == keccak256(
                    abi.encode(
                        profile,
                        block.chainid,
                        address(n.registry),
                        address(n.coordinator),
                        predecessor,
                        priorCoordinator,
                        p,
                        query,
                        data
                    )
                ),
            "independent whole profile commitment"
        );
        uint256 found;
        bytes32 topic =
            keccak256("ArtistAuthorityHydrated(uint16,bytes32,uint256,address,bytes32,bytes32)");
        for (uint256 j; j < logs.length; ++j) {
            if (
                logs[j].emitter == address(n.coordinator) && logs[j].topics.length != 0
                    && logs[j].topics[0] == topic
            ) {
                ++found;
                require(
                    logs[j].topics.length == 4 && logs[j].topics[1] == artistId
                        && logs[j].topics[2] == bytes32(uint256(1))
                        && logs[j].topics[3] == bytes32(uint256(uint160(address(ingress))))
                        && keccak256(logs[j].data)
                            == keccak256(abi.encode(uint16(1), profile, value)),
                    "independent actual emitter and complete schema event"
                );
            }
        }
        require(found == 1, "one successful hydration event");
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
