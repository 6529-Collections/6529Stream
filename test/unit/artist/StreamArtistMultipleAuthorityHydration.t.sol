// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistAuthorityHydration.t.sol";
import {
    StreamArtistMultipleHydrationTypes as MH,
    IStreamArtistMultipleAuthorityHydration as Multiple
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";

/// @notice Actual two registries/seven owners/Archives/threshold Safes; Core/governance remain typed boundaries.
/// @dev No collaborator, advanced authority, current-Core cutover or measured transaction-capacity claim.
contract StreamArtistMultipleAuthorityHydrationTest is ArtistOnboardingFixture {
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
    bytes32 private secondId;
    OfficialSafe private second;
    uint256[] private secondKeys;
    bytes32[2] private savedPolicies;
    bytes[2] private savedSignatures;
    bytes32 private revokedDigest = keccak256("multi exact digest revocation");

    function _initialBindingProposal() internal view override returns (T.BindingProposal memory p) {
        p = _proposal(0);
        p.identityRecordURI = "urn:multiple:identity";
    }

    function _candidate(uint256 owner, string memory surface, bytes32 scope) private {
        candidates[owner].push(AH.Origin(keccak256(bytes(surface)), scope));
    }

    function _auth(bytes32 id, bytes32 digest, uint256 nonce) private {
        _candidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(id, digest))
        );
        _candidate(2, "identity_authority.replay.nonce_allocator", keccak256(abi.encode(id, nonce)));
    }

    function _sign(OfficialSafe signer, uint256[] memory signerKeys, bytes32 digest)
        private
        returns (bytes memory)
    {
        return safeThresholdSignature(signerKeys, safeMessageDigest(signer, abi.encode(digest)));
    }

    function _acceptCollection(
        uint256 id,
        bytes32 identity,
        OfficialSafe signer,
        uint256[] memory signerKeys
    ) private {
        uint256 nonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(identity).nonceHint;
        T.Authorization memory a = T.Authorization(nonce, uint64(block.timestamp + 1 days), "");
        bytes32 digest = ingress.acceptanceDigest(id, a);
        a.signature = _sign(signer, signerKeys, digest);
        _auth(identity, digest, nonce);
        ingress.acceptArtistBinding(id, a);
        _candidate(
            3,
            "acceptance_lifecycle.replay.record_uniqueness",
            keccak256(abi.encode(id, uint64(1), uint8(1), address(signer)))
        );
    }

    function _policyFor(
        uint256 id,
        bytes32 identity,
        OfficialSafe signer,
        uint256[] memory signerKeys
    ) private {
        T.PolicyConsent memory p = T.PolicyConsent(
            id, PHASE, keccak256(abi.encode("multiple-policy", id))
        );
        uint256 nonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(identity).nonceHint;
        T.Authorization memory a = T.Authorization(nonce, uint64(block.timestamp + 1 days), "");
        bytes32 digest = ingress.policyConsentDigest(p, a);
        a.signature = _sign(signer, signerKeys, digest);
        _auth(identity, digest, nonce);
        savedSignatures[id - 1] = a.signature;
        savedPolicies[id - 1] = ingress.recordPolicyConsent(p, a);
        _candidate(
            6,
            "consent_finality.replay.policy_consent_key",
            keccak256(abi.encode(id, p.phaseId, p.policyHash))
        );
    }

    function _revokeFor(bytes32 id, OfficialSafe signer, uint256[] memory signerKeys, bool digest_)
        private
    {
        StreamArtistAuthorizationTypes.Revocation memory p =
            StreamArtistAuthorizationTypes.Revocation(
                id, digest_ ? revokedDigest : bytes32(0), digest_ ? 0 : 257
            );
        uint256 nonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(id).nonceHint;
        T.Authorization memory a = T.Authorization(nonce, uint64(block.timestamp + 1 days), "");
        bytes32 digest = ingress.authorizationRevocationDigest(p, a);
        a.signature = _sign(signer, signerKeys, digest);
        _auth(id, digest, nonce);
        ingress.revokeArtistAuthorization(p, a);
        _candidate(
            2,
            "identity_authority.replay.target_authorization_revocation",
            keccak256(abi.encode(id, p.revokedDigest, p.revokedNonce))
        );
        if (digest_) {
            _candidate(
                2,
                "identity_authority.replay.digest_revocation",
                keccak256(abi.encode(id, revokedDigest))
            );
        } else {
            _candidate(
                2,
                "identity_authority.replay.nonce_allocator",
                keccak256(abi.encode(id, uint256(257)))
            );
        }
    }

    function _source(bool shared, bool revocations) private {
        _candidate(
            0, "binding_lifecycle.replay.proposal_key", keccak256(abi.encode(uint256(1), uint64(1)))
        );
        _candidate(
            0, "binding_lifecycle.replay.proposal_key", keccak256(abi.encode(uint256(2), uint64(1)))
        );
        _candidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(abi.encode(bytes32(0), uint256(0)))
        );
        T.BindingProposal memory p = _initialBindingProposal();
        if (shared) {
            p.artistId = artistId;
            second = artist;
            secondKeys = keys;
        } else {
            _newRotationSafe(0xabc123);
            second = rotationSafe;
            secondKeys = rotationKeys;
            p.artistAddress = address(second);
            _candidate(
                2,
                "identity_authority.replay.nonce_allocator",
                keccak256(abi.encode(bytes32(0), uint256(1)))
            );
        }
        (secondId,) =
            ingress.proposeArtistBinding(2, p, bytes("unit identity document"), "Artist Safe");
        // Deliberately reverse acceptance order; nonce-index insertion order need not be sorted identity order.
        _acceptCollection(2, secondId, second, secondKeys);
        _acceptCollection(1, artistId, artist, keys);
        if (!revocations) {
            _policyFor(2, secondId, second, secondKeys);
            _policyFor(1, artistId, artist, keys);
        }
        if (revocations) {
            _revokeFor(artistId, artist, keys, false);
            _revokeFor(secondId, second, secondKeys, true);
        }
        _candidate(2, "identity_authority.replay.one_way_cutover_latch", 0);
    }

    function _ids() private view returns (bytes32[] memory ids) {
        ids = new bytes32[](secondId == artistId ? 1 : 2);
        ids[0] = artistId;
        if (ids.length == 2) {
            ids[1] = secondId;
            if (ids[0] > ids[1]) (ids[0], ids[1]) = (ids[1], ids[0]);
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

    function _request() private view returns (MH.Request memory p) {
        p.artistIds = _ids();
        p.collections = new MH.Collection[](2);
        for (uint256 c; c < 2; ++c) {
            p.collections[c].artistId = c == 0 ? artistId : secondId;
            p.collections[c].collectionId = c + 1;
            p.collections[c].policies = new AH.PolicyKey[](savedPolicies[c] == 0 ? 0 : 1);
            if (savedPolicies[c] != 0) {
                p.collections[c].policies[0] =
                    AH.PolicyKey(PHASE, keccak256(abi.encode("multiple-policy", c + 1)));
            }
        }
        for (uint256 i; i < 7; ++i) {
            p.expectedSource[i] = CP(suite.owners[i]).authorityCheckpoint();
            p.replayOrigins[i] = new AH.Origin[](p.expectedSource[i].replayCount);
            for (uint256 j; j < p.replayOrigins[i].length; ++j) {
                (bytes32 key,) = CP(suite.owners[i]).authorityReplayAt(j);
                bool found;
                for (uint256 k; k < candidates[i].length; ++k) {
                    if (_sourceKey(i, candidates[i][k]) == key) {
                        p.replayOrigins[i][j] = candidates[i][k];
                        found = true;
                        break;
                    }
                }
                require(found, "complete independent original guard preimages");
            }
        }
    }

    function _leaves() private view returns (HT.Leaf[] memory rows) {
        History h = History(address(ingress));
        bytes32[] memory ids = _ids();
        uint256 total;
        for (uint256 i; i < ids.length; ++i) {
            (, uint64 n) = h.artistHistoryLane(1, ids[i]);
            total += n;
        }
        for (uint256 i = 1; i <= 2; ++i) {
            (, uint64 n) = h.artistHistoryLane(2, bytes32(i));
            total += n;
        }
        rows = new HT.Leaf[](total);
        uint256 k;
        for (uint256 i; i < ids.length + 2; ++i) {
            uint8 kind = i < ids.length ? 1 : 2;
            bytes32 id = i < ids.length ? ids[i] : bytes32(i - ids.length + 1);
            (, uint64 n) = h.artistHistoryLane(kind, id);
            for (uint64 j; j < n; ++j) {
                (bytes32 record, bytes32 chain) = h.artistHistoryRecordAt(kind, id, j);
                rows[k++] = HT.Leaf(kind, id, j, record, chain);
            }
        }
    }

    function _cutover(bool all) private returns (Next memory n) {
        n = _next();
        HT.Leaf[] memory rows = _leaves();
        (bytes32 root,) = _proof(address(ingress), rows, 0);
        _commit(n, root, keccak256("complete multiple living manifest"));
        core.set(POINTER, address(n.registry), false);
        History(address(ingress)).observeRegistryCutover();
        for (uint256 j; j < rows.length; ++j) {
            bool last = j + 1 == rows.length || rows[j].laneKind != rows[j + 1].laneKind
                || rows[j].laneKey != rows[j + 1].laneKey;
            if (!last || (!all && rows[j].laneKind == 2 && rows[j].laneKey == bytes32(uint256(2))))
            {
                continue;
            }
            (, bytes32[] memory proof) = _proof(address(ingress), rows, j);
            History(address(n.registry)).verifyImportedLaneTip(0, rows[j], proof);
        }
    }

    function _empty(Next memory n) private view {
        T.SuiteConfiguration memory s = n.coordinator.suiteConfiguration();
        for (uint256 i; i < 7; ++i) {
            require(
                HydrationOwner(s.owners[i]).authorityHydrationCommitment() == 0,
                "no partial owner marker"
            );
        }
        require(
            IStreamArtistIdentityOwner(n.identity).identity(artistId).authorityAddress == address(0)
                && IStreamArtistIdentityOwner(n.identity).identity(secondId).authorityAddress
                    == address(0),
            "no partial identity"
        );
    }

    function _parity(Next memory n, MH.Request memory p, bytes32 value) private view {
        T.SuiteConfiguration memory s = n.coordinator.suiteConfiguration();
        for (uint256 i; i < 7; ++i) {
            require(
                HydrationOwner(s.owners[i]).authorityHydrationCommitment() == value,
                "one shared complete marker"
            );
            for (uint256 j; j < p.expectedSource[i].replayCount; ++j) {
                (bytes32 key, T.ReplayCell memory cell) = CP(suite.owners[i]).authorityReplayAt(j);
                require(
                    keccak256(abi.encode(cell))
                        == keccak256(
                            abi.encode(
                                StreamArtistOwner(s.owners[i]).importedAuthorityReplayCell(key)
                            )
                        ),
                    "every original source cell retained"
                );
            }
        }
        for (uint256 i; i < p.artistIds.length; ++i) {
            bytes32 id = p.artistIds[i];
            require(
                keccak256(abi.encode(IStreamArtistIdentityOwner(n.identity).identity(id)))
                    == keccak256(
                        abi.encode(IStreamArtistIdentityOwner(suite.owners[2]).identity(id))
                    ),
                "exact preserved predecessor identity"
            );
        }
        for (uint256 c = 1; c <= 2; ++c) {
            require(
                keccak256(abi.encode(n.coordinator.reads().acceptedBinding(c)))
                    == keccak256(abi.encode(coordinator.reads().acceptedBinding(c))),
                "current binding parity"
            );
            require(
                IStreamArtistConsentOwner(s.owners[6])
                    .policyRecord(c, PHASE, p.collections[c - 1].policies[0].policyHash)
                == savedPolicies[c - 1],
                "same original policy record"
            );
            require(
                keccak256(
                        IStreamArtistIdentityOwner(n.identity).signatureBundle(savedPolicies[c - 1])
                    ) == keccak256(savedSignatures[c - 1]),
                "original signature bytes"
            );
        }
    }

    function _write(
        Next memory n,
        uint256 collection,
        bytes32 id,
        OfficialSafe signer,
        uint256[] memory signerKeys
    ) private {
        T.PolicyConsent memory p = T.PolicyConsent(
            collection, PHASE, keccak256(abi.encode("fresh successor", collection))
        );
        T.Authorization memory a = T.Authorization(
            IStreamArtistIdentityOwner(n.identity).identity(id).nonceHint,
            uint64(block.timestamp + 1 days),
            ""
        );
        (bytes32 artistTip, uint64 ac) = History(address(n.registry)).artistHistoryLane(1, id);
        (bytes32 collectionTip, uint64 cc) =
            History(address(n.registry)).artistHistoryLane(2, bytes32(collection));
        require(
            executeSafe(
                signer,
                signerKeys,
                address(n.registry),
                0,
                abi.encodeCall(IStreamArtistOnboarding.recordPolicyConsent, (p, a)),
                0
            ),
            "actual successor Safe write"
        );
        T.SuiteConfiguration memory s = n.coordinator.suiteConfiguration();
        bytes32 record =
            IStreamArtistConsentOwner(s.owners[6]).policyRecord(collection, PHASE, p.policyHash);
        (bytes32 at, uint64 an) = History(address(n.registry)).artistHistoryLane(1, id);
        (bytes32 ct, uint64 cn) =
            History(address(n.registry)).artistHistoryLane(2, bytes32(collection));
        require(
            an == ac + 1 && cn == cc + 1 && at == keccak256(abi.encode(CHAIN, artistTip, record))
                && ct == keccak256(abi.encode(CHAIN, collectionTip, record)),
            "both original accumulators extend once"
        );
        (bytes32 oldRecord, bytes32 oldChain) =
            History(address(ingress)).artistHistoryRecordAt(2, bytes32(collection), 0);
        (bytes32 imported, bytes32 importedChain) =
            History(address(n.registry)).artistHistoryRecordAt(2, bytes32(collection), 0);
        require(
            oldRecord == imported && oldChain == importedChain, "historical source prefix unchanged"
        );
    }

    function _evidence(
        Next memory n,
        MH.Request memory p,
        bytes32 value,
        bytes32 roots,
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
        bytes memory encoded = n.archive.artistEvidenceBytesV2(id, 1);
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
            encoded,
            (uint16, bytes32, uint16, address, bytes32, T.Snapshot[7], T.Snapshot[7], bytes)
        );
        require(
            schema == 1 && configuration == n.coordinator.configurationHash() && op == 60
                && actor == address(this) && record == value
                && roots == keccak256(abi.encode(before_))
                && _allRoots(n.coordinator) == keccak256(abi.encode(after_)),
            "exact original outer evidence and all seven snapshots"
        );
        for (uint256 i; i < 7; ++i) {
            require(after_[i].revision == before_[i].revision + 1, "one commit per owner");
        }
        (
            bytes32 profile,
            address prior,
            address priorCoordinator,
            CP.Checkpoint[7] memory headers,
            AH.Query memory q,
            AH.OwnerData[7] memory data
        ) =
            abi.decode(
                payload, (bytes32, address, address, CP.Checkpoint[7], AH.Query, AH.OwnerData[7])
            );
        require(
            profile == keccak256("6529STREAM_ARTIST_MULTIPLE_LIVING_HYDRATION_V1")
                && prior == address(ingress) && priorCoordinator == address(coordinator)
                && keccak256(abi.encode(headers)) == keccak256(abi.encode(p.expectedSource)),
            "independent profile and all source headers"
        );
        AH.Request memory original;
        original.artistId = q.artistId;
        original.collectionId = q.collectionId;
        original.policies = q.policies;
        original.expectedSource = headers;
        original.replayOrigins = p.replayOrigins;
        require(
            value
                == keccak256(
                    abi.encode(
                        profile,
                        block.chainid,
                        address(n.registry),
                        address(n.coordinator),
                        prior,
                        priorCoordinator,
                        original,
                        q,
                        data
                    )
                ),
            "independent exact whole-profile commitment"
        );
        for (uint256 owner; owner < 7; ++owner) {
            require(
                keccak256(abi.encode(data[owner].origins))
                    == keccak256(abi.encode(p.replayOrigins[owner])),
                "guard preimages retain original ordering"
            );
            if (owner == 1 || owner == 5) {
                require(data[owner].typedState.length == 0, "explicit empty unchanged owner");
                continue;
            }
            (bytes32 tag, MH.Bundle memory b) =
                abi.decode(data[owner].typedState, (bytes32, MH.Bundle));
            require(
                tag == keccak256("6529STREAM_ARTIST_MULTIPLE_LIVING_STATE_V1")
                    && keccak256(data[owner].typedState) == keccak256(abi.encode(tag, b)),
                "canonical closed tagged codec"
            );
            if (owner == 2) {
                require(
                    keccak256(abi.encode(b.artistIds)) == keccak256(abi.encode(p.artistIds))
                        && b.registrationCount == p.artistIds.length && b.collectionIds.length == 2
                        && b.collectionIds[0] == 1 && b.collectionIds[1] == 2,
                    "all allocator and lane identities retained"
                );
                for (uint256 j; j < b.rows.length; ++j) {
                    require(
                        b.rows[j].query.artistId == p.artistIds[j]
                            && keccak256(b.rows[j].state)
                                == keccak256(
                                    IStreamArtistMultipleHydrationIdentity(suite.owners[2])
                                        .authorityLivingIdentityHydrationState(b.rows[j].query)
                                ),
                        "fixed original identity and signature export parity"
                    );
                    for (uint256 k; k < b.rows[j].nonces.length; ++k) {
                        (uint256 prefix, uint256[32] memory words, bool exhausted) =
                            CP(suite.owners[2]).authorityNonceWordAt(1, p.artistIds[j], k);
                        require(
                            prefix == b.rows[j].nonces[k].prefix
                                && keccak256(abi.encode(words))
                                    == keccak256(abi.encode(b.rows[j].nonces[k].words))
                                && exhausted == b.rows[j].nonces[k].exhausted,
                            "every original typed nonce word"
                        );
                    }
                }
            } else {
                require(b.rows.length == p.collections.length, "complete collection rows");
                for (uint256 c; c < b.rows.length; ++c) {
                    require(
                        b.rows[c].query.collectionId == p.collections[c].collectionId
                            && b.rows[c].query.artistId == p.collections[c].artistId
                            && keccak256(b.rows[c].state)
                                == keccak256(
                                    HydrationOwner(suite.owners[owner])
                                        .authorityHydrationState(b.rows[c].query)
                                ),
                        "original per-owner export and canonical collection ordering"
                    );
                }
            }
        }
        bytes32 topic =
            keccak256("MultipleArtistAuthorityHydrated(address,bytes32,bytes32[],uint256[])");
        uint256 matches;
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(n.coordinator) && logs[i].topics.length > 0
                    && logs[i].topics[0] == topic
            ) {
                ++matches;
                require(
                    logs[i].topics.length == 3
                        && logs[i].topics[1] == bytes32(uint256(uint160(prior)))
                        && logs[i].topics[2] == value
                        && keccak256(logs[i].data) == keccak256(abi.encode(p.artistIds, ids)),
                    "independent complete typed event"
                );
            }
        }
        require(matches == 1, "one successful batch event");
    }

    function testMultipleLivingIdentitiesKeepCompleteStateAndIndependentSafeWrites() external {
        _source(false, false);
        Next memory n = _cutover(true);
        MH.Request memory p = _request();
        bytes32 roots = _allRoots(n.coordinator);
        vm.recordLogs();
        bytes32 value = Multiple(address(n.registry)).hydrateMultipleArtistAuthority(p);
        _parity(n, p, value);
        _evidence(n, p, value, roots, vm.getRecordedLogs());
        _write(n, 2, secondId, second, secondKeys);
        _write(n, 1, artistId, artist, keys);
    }

    function testSharedLivingIdentityActivatesBothCollectionLanesOnce() external {
        _source(true, false);
        Next memory n = _cutover(true);
        MH.Request memory p = _request();
        bytes32 value = Multiple(address(n.registry)).hydrateMultipleArtistAuthority(p);
        _parity(n, p, value);
        _write(n, 2, artistId, artist, keys);
        _write(n, 1, artistId, artist, keys);
    }

    function testMultipleHydrationRequiresCompleteIdentityCollectionAndNonceInventories() external {
        _source(false, false);
        Next memory n = _cutover(true);
        MH.Request memory p = _request();
        bytes32 roots = _allRoots(n.coordinator);
        bytes32[] memory ids = p.artistIds;
        p.artistIds = new bytes32[](1);
        p.artistIds[0] = artistId;
        vm.expectRevert();
        Multiple(address(n.registry)).hydrateMultipleArtistAuthority(p);
        p.artistIds = ids;
        MH.Collection[] memory rows = p.collections;
        p.collections = new MH.Collection[](1);
        p.collections[0] = rows[0];
        vm.expectRevert();
        Multiple(address(n.registry)).hydrateMultipleArtistAuthority(p);
        p.collections = rows;
        bytes32 original = p.expectedSource[2].nonceRoot;
        p.expectedSource[2].nonceRoot = keccak256("omitted nonce tree");
        avm.expectRevert(T.InvalidRecord.selector);
        Multiple(address(n.registry)).hydrateMultipleArtistAuthority(p);
        p.expectedSource[2].nonceRoot = original;
        bytes32 scope = p.replayOrigins[2][0].scope;
        p.replayOrigins[2][0].scope = keccak256("another identity scope");
        avm.expectRevert(T.InvalidRecord.selector);
        Multiple(address(n.registry)).hydrateMultipleArtistAuthority(p);
        p.replayOrigins[2][0].scope = scope;
        require(roots == _allRoots(n.coordinator), "all refusals leave every owner unchanged");
        _empty(n);
        require(
            Multiple(address(n.registry)).hydrateMultipleArtistAuthority(p) != 0,
            "exact restoration succeeds"
        );
    }

    function testMultipleHydrationRejectsDuplicateRowsAndWrongPolicyCollectionOrder() external {
        _source(false, false);
        Next memory n = _cutover(true);
        MH.Request memory p = _request();
        bytes32 saved = p.artistIds[1];
        p.artistIds[1] = p.artistIds[0];
        avm.expectRevert(T.InvalidRecord.selector);
        Multiple(address(n.registry)).hydrateMultipleArtistAuthority(p);
        p.artistIds[1] = saved;
        uint256 id = p.collections[1].collectionId;
        p.collections[1].collectionId = 1;
        avm.expectRevert(T.InvalidRecord.selector);
        Multiple(address(n.registry)).hydrateMultipleArtistAuthority(p);
        p.collections[1].collectionId = id;
        bytes32 policy = p.collections[0].policies[0].policyHash;
        p.collections[0].policies[0].policyHash = p.collections[1].policies[0].policyHash;
        avm.expectRevert(T.InvalidRecord.selector);
        Multiple(address(n.registry)).hydrateMultipleArtistAuthority(p);
        p.collections[0].policies[0].policyHash = policy;
        _empty(n);
        require(
            Multiple(address(n.registry)).hydrateMultipleArtistAuthority(p) != 0,
            "same complete profile succeeds"
        );
    }

    function testMultipleHydrationRejectsMissingLaneAndChangedSourceRuntime() external {
        _source(false, false);
        Next memory n = _cutover(false);
        MH.Request memory p = _request();
        avm.expectRevert(T.InvalidRecord.selector);
        Multiple(address(n.registry)).hydrateMultipleArtistAuthority(p);
        _empty(n);
        HT.Leaf[] memory rows = _leaves();
        (, bytes32[] memory proof) = _proof(address(ingress), rows, rows.length - 1);
        History(address(n.registry)).verifyImportedLaneTip(0, rows[rows.length - 1], proof);
        bytes memory code = suite.owners[6].code;
        vm.etch(suite.owners[6], hex"00");
        vm.expectRevert(abi.encodeWithSelector(T.ComponentChanged.selector, suite.owners[6]));
        Multiple(address(n.registry)).hydrateMultipleArtistAuthority(p);
        vm.etch(suite.owners[6], code);
        _empty(n);
        require(
            Multiple(address(n.registry)).hydrateMultipleArtistAuthority(p) != 0,
            "latch and exact source restoration admit retry"
        );
    }

    function testMultipleHydrationLateArchiveFailureRollsBackAllLanesAndSafeNonce() external {
        _source(false, false);
        Next memory n = _cutover(true);
        MH.Request memory p = _request();
        bytes memory call = abi.encodeCall(Multiple.hydrateMultipleArtistAuthority, (p));
        bytes32 roots = _allRoots(n.coordinator);
        uint256 nonce = artist.nonce();
        avm.mockCallRevert(
            address(n.archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSignature("Error(string)", "late multiple archive")
        );
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(n.registry), call);
        _empty(n);
        require(
            roots == _allRoots(n.coordinator) && artist.nonce() == nonce,
            "all seven writes and Safe nonce roll back"
        );
        avm.clearMockedCalls();
        require(this.executeTargetSafe(address(n.registry), call), "identical Safe retry");
        require(artist.nonce() == nonce + 1, "one successful caller transaction");
        _write(n, 2, secondId, second, secondKeys);
        avm.expectRevert(T.InvalidRecord.selector);
        Multiple(address(n.registry)).hydrateMultipleArtistAuthority(p);
    }

    function testMultipleHydrationPreservesPerArtistRevocationsAndRejectsOldDomain() external {
        _source(false, true);
        Next memory n = _cutover(true);
        MH.Request memory p = _request();
        Multiple(address(n.registry)).hydrateMultipleArtistAuthority(p);
        StreamArtistAuthorizationTypes.State memory first =
            n.registry.artistAuthorizationState(artistId, revokedDigest, 257);
        StreamArtistAuthorizationTypes.State memory other =
            n.registry.artistAuthorizationState(secondId, revokedDigest, 257);
        require(
            first.nonceRevoked && first.nonceConsumed && !first.digestRevoked && other.digestRevoked
                && !other.nonceRevoked,
            "independent sparse guards do not cross identities"
        );
        T.PolicyConsent memory policy = T.PolicyConsent(1, PHASE, keccak256("new domain policy"));
        T.Authorization memory a = T.Authorization(1000, uint64(block.timestamp + 1 days), "");
        a.signature = _sign(artist, keys, ingress.policyConsentDigest(policy, a));
        avm.expectRevert(T.InvalidSignature.selector);
        n.registry.recordPolicyConsent(policy, a);
        a.signature = _sign(artist, keys, n.registry.policyConsentDigest(policy, a));
        require(
            n.registry.recordPolicyConsent(policy, a) != 0,
            "fresh successor-domain original type accepted"
        );
    }

    function testMultipleHydrationKeepsGlobalRegistrationAllocatorForFreshSuccessorIdentity()
        external
    {
        _source(false, false);
        Next memory n = _cutover(true);
        MH.Request memory p = _request();
        Multiple(address(n.registry)).hydrateMultipleArtistAuthority(p);
        _newRotationSafe(0xabcdef);
        T.BindingProposal memory proposal = _initialBindingProposal();
        proposal.artistAddress = address(rotationSafe);
        avm.mockCall(
            address(core),
            abi.encodeCall(IStreamCoreCollectionView.collectionExists, (uint256(3))),
            abi.encode(true)
        );
        (bytes32 newId,) = n.registry
        .proposeArtistBinding(3, proposal, bytes("unit identity document"), "Artist Safe");
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ID_V1"),
                block.chainid,
                address(n.registry),
                address(rotationSafe),
                proposal.identityRecordHash,
                uint256(2)
            )
        );
        require(
            newId == expected && newId != artistId && newId != secondId,
            "fresh successor registration follows complete original allocator without rederiving imported IDs"
        );
        require(
            IStreamArtistIdentityOwner(n.identity).activeIdentity(address(artist)) == artistId
                && IStreamArtistIdentityOwner(n.identity).activeIdentity(address(second))
                    == secondId,
            "both imported reverse identity indexes remain exact"
        );
    }

    function testOriginalSingleSelectorStaysStrictWhileExplicitMultipleProfileSucceeds() external {
        _source(false, false);
        Next memory n = _cutover(true);
        MH.Request memory p = _request();
        AH.Request memory old;
        old.artistId = artistId;
        old.collectionId = 1;
        old.expectedSource = p.expectedSource;
        avm.expectRevert(T.UnsupportedProfile.selector);
        Hydrate(address(n.registry)).hydrateArtistAuthority(old);
        _empty(n);
        require(
            Multiple(address(n.registry)).hydrateMultipleArtistAuthority(p) != 0,
            "only explicit complete multiplicity profile admits this source"
        );
    }

    function testOriginalSelectorStillRejectsMultipleIdentitiesAndAdvancedHistoryIsNotDropped()
        external
    {
        _source(false, false);
        nextNonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        _selfGuardian();
        Next memory n = _cutover(true);
        MH.Request memory p;
        p.artistIds = _ids();
        p.collections = new MH.Collection[](2);
        for (uint256 i; i < 2; ++i) {
            p.collections[i].artistId = i == 0 ? artistId : secondId;
            p.collections[i].collectionId = i + 1;
        }
        for (uint256 i; i < 7; ++i) {
            p.expectedSource[i] = CP(suite.owners[i]).authorityCheckpoint();
        }
        avm.expectRevert(T.UnsupportedProfile.selector);
        Multiple(address(n.registry)).hydrateMultipleArtistAuthority(p);
        _empty(n);
        AH.Request memory old;
        old.artistId = artistId;
        old.collectionId = 1;
        old.expectedSource = p.expectedSource;
        vm.expectRevert();
        Hydrate(address(n.registry)).hydrateArtistAuthority(old);
        _empty(n);
    }

    function _allRoots(StreamArtistOnboardingCoordinator c) private view returns (bytes32) {
        T.SuiteConfiguration memory s = c.suiteConfiguration();
        T.Snapshot[7] memory snapshots;
        for (uint256 j; j < 7; ++j) {
            snapshots[j] = IStreamArtistOwner(s.owners[j]).ownerStateSnapshotV2();
        }
        return keccak256(abi.encode(snapshots));
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
        n.registry = StreamArtistOnboardingRegistry(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol:StreamArtistOnboardingRegistry",
                    abi.encode(
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
                    )
                ))
        );
        n.archive = StreamArtistArchiveV2(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/artist/StreamArtistArchiveV2.sol:StreamArtistArchiveV2",
                    abi.encode(registry_, coordinator_)
                ))
        );
        s.registry = registry_;
        s.archive = archive_;
        s.owners[0] = address(
            StreamArtistBindingLifecycle(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistBindingLifecycle.sol:StreamArtistBindingLifecycle",
                        abi.encode(registry_, coordinator_, archive_, s.core, s.mintManager)
                    ))
            )
        );
        s.owners[1] = address(
            StreamArtistCollaboratorLifecycle(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistCollaboratorLifecycle.sol:StreamArtistCollaboratorLifecycle",
                        abi.encode(registry_, coordinator_, archive_, s.core, s.mintManager)
                    ))
            )
        );
        s.owners[2] = address(
            StreamArtistIdentityAuthority(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol:StreamArtistIdentityAuthority",
                        abi.encode(
                            registry_,
                            coordinator_,
                            archive_,
                            s.core,
                            s.mintManager,
                            address(artistExtensionFactory),
                            identity
                        )
                    ))
            )
        );
        s.owners[3] = address(
            StreamArtistAcceptanceLifecycle(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistAcceptanceLifecycle.sol:StreamArtistAcceptanceLifecycle",
                        abi.encode(registry_, coordinator_, archive_, s.core, s.mintManager)
                    ))
            )
        );
        s.owners[4] = address(
            StreamArtistAttributionLifecycle(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistAttributionLifecycle.sol:StreamArtistAttributionLifecycle",
                        abi.encode(registry_, coordinator_, archive_, s.core, s.mintManager)
                    ))
            )
        );
        s.owners[5] = address(
            StreamArtistPayoutLifecycle(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistPayoutLifecycle.sol:StreamArtistPayoutLifecycle",
                        abi.encode(registry_, coordinator_, archive_, s.core, s.mintManager)
                    ))
            )
        );
        s.owners[6] = address(
            StreamArtistConsentFinalityLifecycle(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistConsentFinalityLifecycle.sol:StreamArtistConsentFinalityLifecycle",
                        abi.encode(registry_, coordinator_, archive_, s.core, s.mintManager)
                    ))
            )
        );
        ArtistUnitGovernance(governance)
            .configureContestReads(
                s.roleRegistry, address(artist), keccak256("successor finality"), "urn:successor"
            );
        address finality = finalityFixture.deploy(s.core, s.metadata, registry_, governance);
        n.coordinator = StreamArtistOnboardingCoordinator(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/artist/StreamArtistOnboardingCoordinator.sol:StreamArtistOnboardingCoordinator",
                    abi.encode(s, finality)
                ))
        );
        n.identity = s.owners[2];
        require(
            address(n.registry) == registry_ && address(n.archive) == archive_
                && address(n.coordinator) == coordinator_ && n.identity == identity_,
            "actual successor pins"
        );
    }
}
