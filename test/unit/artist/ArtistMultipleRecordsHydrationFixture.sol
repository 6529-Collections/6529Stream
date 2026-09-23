// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistMultipleAuthorityHydration.t.sol";
import "./StreamArtistDelegationAuthorityHydration.t.sol";
import "../../../smart-contracts/domains/artist/StreamArtistMultipleDelegationCodec.sol";
import "../../../smart-contracts/domains/artist/StreamArtistMultipleDelegationSource.sol";

/// @notice Local copy of the completed combined-profile setup helpers; no shared fixture changes.
/// @notice Real Artist registries, fixed owners, Archive and threshold Safes.
/// @dev Core, governance and explicit sale-facts/catalog reads are typed boundaries; no current-graph claim.
abstract contract ArtistMultipleRecordsHydrationFixture is ArtistOnboardingFixture {
    bytes32 internal constant CHAIN =
        0x2eac9cfc5ca84fbeed56ef1741255e2ec7e45f48bc5c5ceda94397aa23d2f23e;
    bytes32 internal constant LEAF =
        0xea04da6644046a7c731e99312c32df311e81aa7e137dfc2a49c2116bb325195d;
    bytes32 internal constant POINTER = keccak256("ARTIST_REGISTRY");

    struct Next {
        StreamArtistOnboardingRegistry registry;
        StreamArtistArchiveV2 archive;
        StreamArtistOnboardingCoordinator coordinator;
        address identity;
    }
    AH.Origin[][7] internal candidates;
    bytes32 internal secondId;
    OfficialSafe internal second;
    uint256[] internal secondKeys;
    bytes32[2] internal savedPolicies;
    bytes[2] internal savedSignatures;
    bytes32 internal revokedDigest = keccak256("multi exact digest revocation");
    bool internal legacy;
    bool internal directHistory;

    function _initialBindingProposal() internal view override returns (T.BindingProposal memory p) {
        p = _proposal(0);
        p.identityRecordURI = "urn:multiple:identity";
        p.consentMode = legacy ? 1 : 2;
        p.saleConsentScope = 1;
    }

    function _source(bool shared) internal {
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
        _acceptCollection(2, secondId, second, secondKeys);
        _acceptCollection(1, artistId, artist, keys);
        _candidate(2, "identity_authority.replay.one_way_cutover_latch", 0);
        _delegateSetup();
    }

    function _grantFor(
        bytes32 id,
        OfficialSafe signer,
        uint256[] memory signerKeys,
        uint256 scope,
        uint64 maximum
    ) internal returns (bytes32 record) {
        D.Grant memory p = D.Grant(
            id,
            address(delegateSafe),
            scope,
            uint32(1026),
            uint64(block.timestamp),
            uint64(block.timestamp + 1 days),
            maximum,
            bytes32(0)
        );
        uint256 nonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(id).nonceHint;
        T.Authorization memory a = T.Authorization(nonce, 0, "");
        bytes32 digest = ingress.delegationGrantDigest(p, a);
        _auth(id, digest, nonce);
        a.signature = _sign(signer, signerKeys, digest);
        if (directHistory) {
            a.signature = "";
            require(
                executeSafe(
                    signer,
                    signerKeys,
                    address(ingress),
                    0,
                    abi.encodeCall(IStreamArtistDelegation.grantArtistDelegation, (p, a)),
                    0
                ),
                "direct original grant Safe"
            );
            record = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_DELEGATION_RECORD_V1"),
                    block.chainid,
                    address(ingress),
                    p.artistId,
                    p.delegate,
                    p.collectionId,
                    p.capabilities,
                    p.notBefore,
                    p.expiresAt,
                    p.maxUses,
                    p.constraintsHash,
                    a.nonce
                )
            );
        } else {
            record = ingress.grantArtistDelegation(p, a);
        }
        _candidate(2, "identity_authority.replay.delegation_key", record);
    }

    function _delegateOrigins(bytes32 id, bytes32 digest, uint256 nonce) internal {
        bytes32 lane = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"), id, address(delegateSafe)
            )
        );
        _candidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(id, digest))
        );
        _candidate(
            2, "identity_authority.replay.delegated_nonce", keccak256(abi.encode(lane, nonce))
        );
    }

    function _delegatedPolicy(uint256 id, bytes32 identity, bytes32 grant, uint256 nonce)
        internal
        returns (bytes32 record)
    {
        bytes32 hash = keccak256(abi.encode("multiple-policy", id));
        T.PolicyConsent memory p = T.PolicyConsent(id, PHASE, hash);
        T.Authorization memory a = T.Authorization(nonce, type(uint64).max, "");
        bytes32 digest = ingress.policyConsentDigest(p, a);
        a.signature = _delegateSignature(digest);
        _delegateOrigins(identity, digest, nonce);
        if (directHistory) {
            a.signature = "";
            require(
                this.executeDelegate(
                    address(ingress),
                    abi.encodeCall(
                        IStreamArtistDelegatedConsent.recordDelegatedPolicyConsent, (p, grant, a)
                    )
                ),
                "direct original delegate Safe"
            );
            record = IStreamArtistConsentOwner(suite.owners[6]).policyRecord(id, PHASE, hash);
        } else {
            record = IStreamArtistDelegatedConsent(address(ingress))
                .recordDelegatedPolicyConsent(p, grant, a);
        }
        savedPolicies[id - 1] = record;
        savedSignatures[id - 1] = a.signature;
        _candidate(
            6, "consent_finality.replay.policy_consent_key", keccak256(abi.encode(id, PHASE, hash))
        );
    }

    function _revokeGrant(
        bytes32 id,
        OfficialSafe signer,
        uint256[] memory signerKeys,
        bytes32 grant
    ) internal {
        D.Revocation memory p = D.Revocation(
            id, address(delegateSafe), grant, keccak256("combined revoke")
        );
        uint256 nonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(id).nonceHint;
        T.Authorization memory a = T.Authorization(nonce, uint64(block.timestamp + 1 days), "");
        bytes32 digest = ingress.delegationRevocationDigest(p, a);
        a.signature = _sign(signer, signerKeys, digest);
        _auth(id, digest, nonce);
        ingress.revokeArtistDelegation(p, a);
        _candidate(2, "identity_authority.replay.one_way_delegation_revocation", grant);
    }

    function _hydrate(Next memory n, MH.Request memory p) internal returns (bytes32) {
        return Multiple(address(n.registry)).hydrateMultipleArtistAuthority(p);
    }

    function _query(bytes32 id) internal view returns (AH.Query memory q) {
        q.artistId = id;
        uint256 count;
        for (uint256 i; i < 7; ++i) {
            for (
                uint256 j;
                j < IStreamArtistNativeReceipts(suite.owners[i]).artistNativeReceiptCount();
                ++j
            ) {
                if (
                    IStreamArtistNativeReceipts(suite.owners[i]).artistNativeReceiptAt(j).artistId
                        == id
                ) ++count;
            }
        }
        q.records = new bytes32[](count);
        count = 0;
        for (uint256 i; i < 7; ++i) {
            for (
                uint256 j;
                j < IStreamArtistNativeReceipts(suite.owners[i]).artistNativeReceiptCount();
                ++j
            ) {
                HT.Receipt memory r =
                    IStreamArtistNativeReceipts(suite.owners[i]).artistNativeReceiptAt(j);
                if (r.artistId == id) q.records[count++] = r.recordHash;
            }
        }
    }

    function _parity(Next memory n, MH.Request memory p, bytes32 value, bytes32[] memory grants)
        internal
        view
    {
        T.SuiteConfiguration memory s = n.coordinator.suiteConfiguration();
        for (uint256 i; i < 7; ++i) {
            require(
                HydrationOwner(s.owners[i]).authorityHydrationCommitment() == value,
                "same seven-owner completion"
            );
            for (uint256 j; j < p.expectedSource[i].replayCount; ++j) {
                (bytes32 key, T.ReplayCell memory cell) = CP(suite.owners[i]).authorityReplayAt(j);
                require(
                    keccak256(
                        abi.encode(StreamArtistOwner(s.owners[i]).importedAuthorityReplayCell(key))
                    ) == keccak256(abi.encode(cell)),
                    "every original owner replay cell retained"
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
                "original identity/nonce hint"
            );
            AH.Query memory q = _query(id);
            for (uint256 j; j < q.records.length; ++j) {
                require(
                    keccak256(IStreamArtistIdentityOwner(n.identity).signatureBundle(q.records[j]))
                        == keccak256(
                            IStreamArtistIdentityOwner(suite.owners[2])
                                .signatureBundle(q.records[j])
                        ),
                    "historical signature bytes"
                );
            }
            (bool used, uint256 hint) = n.registry.delegatedNonceState(id, address(delegateSafe), 0);
            (bool oldUsed, uint256 oldHint) =
                ingress.delegatedNonceState(id, address(delegateSafe), 0);
            require(used == oldUsed && hint == oldHint, "per-Artist delegated nonce lane");
        }
        for (uint256 i; i < grants.length; ++i) {
            require(
                keccak256(abi.encode(n.registry.delegationRecord(grants[i])))
                    == keccak256(abi.encode(ingress.delegationRecord(grants[i]))),
                "immutable grant record and live use/revocation cells"
            );
        }
        for (uint256 c; c < 2; ++c) {
            if (savedPolicies[c] != 0) {
                (bool consented, bytes32 record) = n.registry
                    .isPolicyConsented(
                        c + 1, PHASE, keccak256(abi.encode("multiple-policy", c + 1))
                    );
                require(consented && record == savedPolicies[c], "durable policy consent read");
                require(
                    n.registry.recordDelegation(savedPolicies[c])
                        == ingress.recordDelegation(savedPolicies[c]),
                    "recorded grant association survives replacement"
                );
            }
        }
    }

    function _one(bytes32 grant) internal pure returns (bytes32[] memory a) {
        a = new bytes32[](1);
        a[0] = grant;
    }

    function _candidate(uint256 owner, string memory surface, bytes32 scope) internal {
        candidates[owner].push(AH.Origin(keccak256(bytes(surface)), scope));
    }

    function _auth(bytes32 id, bytes32 digest, uint256 nonce) internal {
        _candidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(id, digest))
        );
        _candidate(2, "identity_authority.replay.nonce_allocator", keccak256(abi.encode(id, nonce)));
    }

    function _sign(OfficialSafe signer, uint256[] memory signerKeys, bytes32 digest)
        internal
        returns (bytes memory)
    {
        return safeThresholdSignature(signerKeys, safeMessageDigest(signer, abi.encode(digest)));
    }

    function _acceptCollection(
        uint256 id,
        bytes32 identity,
        OfficialSafe signer,
        uint256[] memory signerKeys
    ) internal {
        uint256 nonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(identity).nonceHint;
        T.Authorization memory a = T.Authorization(nonce, uint64(block.timestamp + 1 days), "");
        bytes32 digest = ingress.acceptanceDigest(id, a);
        a.signature = _sign(signer, signerKeys, digest);
        _auth(identity, digest, nonce);
        if (directHistory) {
            a.signature = "";
            require(
                executeSafe(
                    signer,
                    signerKeys,
                    address(ingress),
                    0,
                    abi.encodeCall(StreamArtistOnboardingRegistry.acceptArtistBinding, (id, a)),
                    0
                ),
                "direct original acceptance Safe"
            );
        } else {
            ingress.acceptArtistBinding(id, a);
        }
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
    ) internal {
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
        internal
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

    function _ids() internal view returns (bytes32[] memory ids) {
        ids = new bytes32[](secondId == artistId ? 1 : 2);
        ids[0] = artistId;
        if (ids.length == 2) {
            ids[1] = secondId;
            if (ids[0] > ids[1]) (ids[0], ids[1]) = (ids[1], ids[0]);
        }
    }

    function _sourceKey(uint256 owner, AH.Origin memory o) internal view returns (bytes32) {
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

    function _request() internal view returns (MH.Request memory p) {
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

    function _leaves() internal view returns (HT.Leaf[] memory rows) {
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

    function _cutover(bool all) internal returns (Next memory n) {
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

    function _empty(Next memory n) internal view {
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

    function _allRoots(StreamArtistOnboardingCoordinator c) internal view returns (bytes32) {
        T.SuiteConfiguration memory s = c.suiteConfiguration();
        T.Snapshot[7] memory snapshots;
        for (uint256 j; j < 7; ++j) {
            snapshots[j] = IStreamArtistOwner(s.owners[j]).ownerStateSnapshotV2();
        }
        return keccak256(abi.encode(snapshots));
    }

    function _leaf(address predecessor, HT.Leaf memory p) internal view returns (bytes32) {
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
        internal
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
        internal
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

    function _commit(Next memory n, bytes32 root, bytes32 manifest) internal {
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
    ) internal pure {
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

    function _next() internal returns (Next memory n) {
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
