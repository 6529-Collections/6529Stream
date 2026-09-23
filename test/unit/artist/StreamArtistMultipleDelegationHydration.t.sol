// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistMultipleAuthorityHydration.t.sol";
import "./StreamArtistDelegationAuthorityHydration.t.sol";
import "../../../smart-contracts/domains/artist/StreamArtistMultipleDelegationCodec.sol";
import "../../../smart-contracts/domains/artist/StreamArtistMultipleDelegationSource.sol";

/// @notice Real Artist registries, fixed owners, Archive and threshold Safes.
/// @dev Core, governance and explicit sale-facts/catalog reads are typed boundaries; no current-graph claim.
contract StreamArtistMultipleDelegationHydrationTest is ArtistOnboardingFixture {
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
    bool private legacy;
    bool private directHistory;

    function _initialBindingProposal() internal view override returns (T.BindingProposal memory p) {
        p = _proposal(0);
        p.identityRecordURI = "urn:multiple:identity";
        p.consentMode = legacy ? 1 : 2;
        p.saleConsentScope = 1;
    }

    function _source(bool shared) private {
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
    ) private returns (bytes32 record) {
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

    function _delegateOrigins(bytes32 id, bytes32 digest, uint256 nonce) private {
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
        private
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
    ) private {
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

    function _hydrate(Next memory n, MH.Request memory p) private returns (bytes32) {
        return Multiple(address(n.registry)).hydrateMultipleArtistAuthority(p);
    }

    function _query(bytes32 id) private view returns (AH.Query memory q) {
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
        private
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

    function _one(bytes32 grant) private pure returns (bytes32[] memory a) {
        a = new bytes32[](1);
        a[0] = grant;
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

    function _evidence(Next memory n, MH.Request memory p, bytes32 value, bytes32 beforeRoots)
        private
        view
    {
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
        require(encoded.length <= 24575, "original finite carrier");
        (
            uint16 schema,
            bytes32 configuration,
            uint16 operation,
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
            schema == 1 && configuration == n.coordinator.configurationHash() && operation == 60
                && actor == address(this) && record == value,
            "original outer envelope"
        );
        require(
            keccak256(abi.encode(before_)) == beforeRoots
                && keccak256(abi.encode(after_)) == _allRoots(n.coordinator),
            "exact all-owner roots"
        );
        (
            bytes32 profile,
            address prior,
            address sourceCoordinator,
            CP.Checkpoint[7] memory headers,
            AH.Query memory q,
            AH.OwnerData[7] memory data
        ) = abi.decode(
            payload, (bytes32, address, address, CP.Checkpoint[7], AH.Query, AH.OwnerData[7])
        );
        require(
            profile == keccak256("6529STREAM_ARTIST_MULTIPLE_LIVING_DELEGATION_V1")
                && prior == address(ingress) && sourceCoordinator == address(coordinator),
            "explicit combined original domain"
        );
        require(
            keccak256(abi.encode(headers)) == keccak256(abi.encode(p.expectedSource)),
            "all source headers"
        );
        AH.Request memory anchor;
        anchor.artistId = q.artistId;
        anchor.collectionId = q.collectionId;
        anchor.policies = q.policies;
        anchor.expectedSource = headers;
        anchor.replayOrigins = p.replayOrigins;
        require(
            value
                == keccak256(
                    abi.encode(
                        profile,
                        block.chainid,
                        address(n.registry),
                        address(n.coordinator),
                        prior,
                        sourceCoordinator,
                        anchor,
                        q,
                        data
                    )
                ),
            "independent original commitment preimage"
        );
        for (uint256 i; i < 7; ++i) {
            require(after_[i].revision == before_[i].revision + 1, "one original owner commit");
            require(
                keccak256(abi.encode(data[i].origins)) == keccak256(abi.encode(p.replayOrigins[i])),
                "complete original replay ordering"
            );
        }
        require(
            data[1].typedState.length == 0 && data[5].typedState.length == 0,
            "explicit empty owners"
        );
        (bytes32 tag, MD.Identities memory identities) =
            abi.decode(data[2].typedState, (bytes32, MD.Identities));
        require(
            tag == keccak256("6529STREAM_ARTIST_MULTIPLE_DELEGATION_IDENTITIES_V1")
                && keccak256(data[2].typedState) == keccak256(abi.encode(tag, identities)),
            "canonical identity codec"
        );
        require(
            identities.rows.length == p.artistIds.length && identities.collectionIds.length == 2
                && identities.collectionIds[0] == 1 && identities.collectionIds[1] == 2,
            "complete IDs"
        );
        for (uint256 a; a < p.artistIds.length; ++a) {
            MD.IdentityRow memory row = identities.rows[a];
            AH.Query memory query = _query(p.artistIds[a]);
            require(
                row.artistId == p.artistIds[a]
                    && keccak256(abi.encode(row.records)) == keccak256(abi.encode(query.records)),
                "complete original journal partition"
            );
            require(
                keccak256(row.state)
                    == keccak256(
                        IStreamArtistDelegationHydrationOwner(suite.owners[2])
                            .authorityDelegationHydrationState(query)
                    ),
                "exact original per-Artist projection"
            );
            for (uint256 j; j < row.nonces.length; ++j) {
                (uint256 prefix, uint256[32] memory words, bool exhausted) =
                    CP(suite.owners[2]).authorityNonceWordAt(1, row.artistId, j);
                require(
                    keccak256(abi.encode(prefix, words, exhausted))
                        == keccak256(abi.encode(row.nonces[j])),
                    "all original principal nonce words"
                );
            }
        }
        (bytes32 bindingTag, MD.BindingRow[] memory bindings) =
            abi.decode(data[0].typedState, (bytes32, MD.BindingRow[]));
        (bytes32 consentTag, MD.ConsentRow[] memory consents) =
            abi.decode(data[6].typedState, (bytes32, MD.ConsentRow[]));
        require(
            bindingTag == keccak256("6529STREAM_ARTIST_MULTIPLE_DELEGATION_BINDINGS_V1")
                && consentTag == keccak256("6529STREAM_ARTIST_MULTIPLE_DELEGATION_CONSENTS_V1"),
            "distinct owner tags"
        );
        require(bindings.length == 2 && consents.length == 2, "complete collection owners");
        for (uint256 c; c < 2; ++c) {
            AH.Query memory query;
            query.artistId = p.collections[c].artistId;
            query.collectionId = c + 1;
            query.bindingHash = bindings[c].state.item.bindingHash;
            query.policies = p.collections[c].policies;
            require(
                bindings[c].collectionId == c + 1 && consents[c].collectionId == c + 1,
                "canonical collection order"
            );
            require(
                keccak256(abi.encode(DH.BINDING, bindings[c].state))
                    == keccak256(
                        IStreamArtistDelegationHydrationOwner(suite.owners[0])
                            .authorityDelegationHydrationState(query)
                    ),
                "exact original binding export"
            );
            require(
                keccak256(abi.encode(DH.CONSENT, consents[c].state))
                    == keccak256(
                        IStreamArtistDelegationHydrationOwner(suite.owners[6])
                            .authorityDelegationHydrationState(query)
                    ),
                "full original consent and grant associations"
            );
        }
    }

    function testTwoArtistsPreserveDistinctGrantAndPrincipalHistories() external {
        _source(false);
        bytes32 grant = _grantFor(artistId, artist, keys, 1, 3);
        _delegatedPolicy(1, artistId, grant, 0);
        Next memory n = _cutover(true);
        MH.Request memory p = _request();
        bytes32 roots = _allRoots(n.coordinator);
        bytes32 value = _hydrate(n, p);
        _parity(n, p, value, _one(grant));
        _evidence(n, p, value, roots);
        require(
            IStreamArtistIdentityOwner(n.identity).activeIdentity(address(second)) == secondId,
            "second unrelated identity is not omitted"
        );
        _freshGrant(n, secondId, second, secondKeys, 2);
    }

    function testGlobalGrantCountsBothCollectionsAndRetainsRevokedConsent() external {
        _source(true);
        bytes32 grant = _grantFor(artistId, artist, keys, 0, 2);
        _delegatedPolicy(2, artistId, grant, 0);
        _delegatedPolicy(1, artistId, grant, 1);
        _revokeGrant(artistId, artist, keys, grant);
        Next memory n = _cutover(true);
        MH.Request memory p = _request();
        bytes32 roots = _allRoots(n.coordinator);
        bytes32 value = _hydrate(n, p);
        _parity(n, p, value, _one(grant));
        _evidence(n, p, value, roots);
        require(
            n.registry.delegationRecord(grant).uses == 2
                && n.registry.delegationRecord(grant).revoked,
            "global uses and revocation preserved"
        );
        (bool active,,,,,,) = n.registry.delegationState(grant);
        require(!active, "recorded consents do not resurrect authority");
        T.PolicyConsent memory policy = T.PolicyConsent(1, PHASE, keccak256("revoked new"));
        T.Authorization memory a = T.Authorization(2, type(uint64).max, "");
        a.signature = _delegateSignature(n.registry.policyConsentDigest(policy, a));
        avm.expectRevert(D.DelegationUnavailable.selector);
        IStreamArtistDelegatedConsent(address(n.registry))
            .recordDelegatedPolicyConsent(policy, grant, a);
    }

    function _freshGrant(
        Next memory n,
        bytes32 id,
        OfficialSafe signer,
        uint256[] memory signerKeys,
        uint256 scope
    ) private returns (bytes32 fresh) {
        D.Grant memory g = D.Grant(
            id,
            address(delegateSafe),
            scope,
            2,
            uint64(block.timestamp),
            uint64(block.timestamp + 1 days),
            2,
            0
        );
        uint256 nonce = IStreamArtistIdentityOwner(n.identity).identity(id).nonceHint;
        T.Authorization memory a = T.Authorization(nonce, 0, "");
        a.signature = _sign(signer, signerKeys, ingress.delegationGrantDigest(g, a));
        avm.expectRevert(T.InvalidSignature.selector);
        n.registry.grantArtistDelegation(g, a);
        a.signature = _sign(signer, signerKeys, n.registry.delegationGrantDigest(g, a));
        fresh = n.registry.grantArtistDelegation(g, a);
        require(
            fresh != 0
                && IStreamArtistIdentityOwner(n.identity).identity(id).nonceHint == nonce + 1,
            "new domain and exact next original nonce"
        );
    }

    function testExhaustedGlobalGrantReplacementRetainsDelegateNonceAcrossCollections() external {
        _source(true);
        bytes32 grant = _grantFor(artistId, artist, keys, 0, 1);
        _delegatedPolicy(2, artistId, grant, 0);
        Next memory n = _cutover(true);
        MH.Request memory p = _request();
        _parity(n, p, _hydrate(n, p), _one(grant));
        bytes32 fresh = _freshGrant(n, artistId, artist, keys, 0);
        T.PolicyConsent memory policy =
            T.PolicyConsent(1, PHASE, keccak256("successor delegated across collection"));
        require(
            this.executeDelegate(
                address(n.registry),
                abi.encodeCall(
                    IStreamArtistDelegatedConsent.recordDelegatedPolicyConsent,
                    (policy, fresh, T.Authorization(1, type(uint64).max, ""))
                )
            ),
            "actual delegate Safe next nonce"
        );
        require(
            n.registry.delegationRecord(grant).uses == 1
                && n.registry.recordDelegation(savedPolicies[1]) == grant,
            "historical exhausted grant never substituted"
        );
    }

    function testOmittedArtistOrCollectionCannotSelectIndependentSubset() external {
        _source(false);
        bytes32 grant = _grantFor(artistId, artist, keys, 0, 0);
        _delegatedPolicy(1, artistId, grant, 0);
        Next memory n = _cutover(true);
        MH.Request memory p = _request();
        bytes32[] memory all = p.artistIds;
        p.artistIds = new bytes32[](1);
        p.artistIds[0] = artistId;
        vm.expectRevert();
        _hydrate(n, p);
        _empty(n);
        p.artistIds = all;
        MH.Collection[] memory collections = p.collections;
        p.collections = new MH.Collection[](1);
        p.collections[0] = collections[0];
        vm.expectRevert();
        _hydrate(n, p);
        _empty(n);
        p.collections = collections;
        require(_hydrate(n, p) != 0, "exact complete request retry");
    }

    function testGlobalGrantUnderreportedUsageRefusesBeforeAnyOwnerWrite() external {
        _source(true);
        bytes32 grant = _grantFor(artistId, artist, keys, 0, 0);
        _delegatedPolicy(1, artistId, grant, 0);
        _delegatedPolicy(2, artistId, grant, 1);
        Next memory n = _cutover(true);
        MH.Request memory p = _request();
        AH.Query memory q = _query(artistId);
        DH.Identity memory b = StreamArtistDelegationHydrationCodec.identity(
            IStreamArtistDelegationHydrationOwner(suite.owners[2])
                .authorityDelegationHydrationState(q)
        );
        b.grants[0].item.uses = 1;
        avm.mockCall(
            suite.owners[2],
            abi.encodeCall(
                IStreamArtistDelegationHydrationOwner.authorityDelegationHydrationState, (q)
            ),
            abi.encode(abi.encode(DH.IDENTITY, b))
        );
        avm.expectRevert(T.UnsupportedProfile.selector);
        _hydrate(n, p);
        _empty(n);
        avm.clearMockedCalls();
        require(_hydrate(n, p) != 0, "both collection uses required");
    }

    function testMissingDelegateLaneAndForeignArtistGrantCannotPassCompleteHeaders() external {
        _source(false);
        bytes32 grant = _grantFor(artistId, artist, keys, 1, 2);
        _delegatedPolicy(1, artistId, grant, 0);
        Next memory n = _cutover(true);
        MH.Request memory p = _request();
        AH.Query memory q = _query(artistId);
        bytes memory original = IStreamArtistDelegationHydrationOwner(suite.owners[2])
            .authorityDelegationHydrationState(q);
        DH.Identity memory b = StreamArtistDelegationHydrationCodec.identity(original);
        b.delegateNonces = new DH.NonceLane[](0);
        avm.mockCall(
            suite.owners[2],
            abi.encodeCall(
                IStreamArtistDelegationHydrationOwner.authorityDelegationHydrationState, (q)
            ),
            abi.encode(abi.encode(DH.IDENTITY, b))
        );
        avm.expectRevert(T.InvalidRecord.selector);
        _hydrate(n, p);
        _empty(n);
        b = StreamArtistDelegationHydrationCodec.identity(original);
        b.grants[0].item.grant.artistId = secondId;
        avm.mockCall(
            suite.owners[2],
            abi.encodeCall(
                IStreamArtistDelegationHydrationOwner.authorityDelegationHydrationState, (q)
            ),
            abi.encode(abi.encode(DH.IDENTITY, b))
        );
        avm.expectRevert(T.InvalidRecord.selector);
        _hydrate(n, p);
        _empty(n);
        avm.clearMockedCalls();
        require(_hydrate(n, p) != 0, "restored exact subject projection");
    }

    function testCombinedLateArchiveFailureRollsBackEveryOwnerAndExactSafeNonce() external {
        _source(true);
        bytes32 grant = _grantFor(artistId, artist, keys, 0, 3);
        _delegatedPolicy(2, artistId, grant, 0);
        Next memory n = _cutover(true);
        MH.Request memory p = _request();
        bytes memory call = abi.encodeCall(Multiple.hydrateMultipleArtistAuthority, (p));
        uint256 nonce = artist.nonce();
        bytes32 roots = _allRoots(n.coordinator);
        avm.mockCallRevert(
            address(n.archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSignature("Error(string)", "late combined archive")
        );
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(n.registry), call);
        _empty(n);
        require(
            artist.nonce() == nonce && roots == _allRoots(n.coordinator),
            "all roots/caller nonce roll back"
        );
        require(
            n.registry.delegationRecord(grant).grantor == address(0), "no partial imported grant"
        );
        avm.clearMockedCalls();
        require(this.executeTargetSafe(address(n.registry), call), "identical threshold Safe retry");
        _parity(n, p, HydrationOwner(n.identity).authorityHydrationCommitment(), _one(grant));
        avm.expectRevert(T.InvalidRecord.selector);
        _hydrate(n, p);
    }

    function testMissingReplayAndChangedSourceHeaderRefuseThenExactRetry() external {
        _source(false);
        _grantFor(secondId, second, secondKeys, 2, 1);
        _revokeFor(artistId, artist, keys, true);
        Next memory n = _cutover(true);
        MH.Request memory p = _request();
        AH.Origin[] memory all = p.replayOrigins[2];
        p.replayOrigins[2] = new AH.Origin[](all.length - 1);
        for (uint256 i; i < p.replayOrigins[2].length; ++i) {
            p.replayOrigins[2][i] = all[i];
        }
        avm.expectRevert(T.InvalidRecord.selector);
        _hydrate(n, p);
        _empty(n);
        p.replayOrigins[2] = all;
        CP.Checkpoint memory changed = abi.decode(abi.encode(p.expectedSource[2]), (CP.Checkpoint));
        changed.ownerState.stateRoot = keccak256("different actual source");
        avm.mockCall(
            suite.owners[2], abi.encodeCall(CP.authorityCheckpoint, ()), abi.encode(changed)
        );
        avm.expectRevert(T.InvalidRecord.selector);
        _hydrate(n, p);
        _empty(n);
        avm.clearMockedCalls();
        _hydrate(n, p);
        require(
            n.registry.artistAuthorizationState(artistId, revokedDigest, 257).digestRevoked,
            "per-Artist revocation retained"
        );
    }

    function testOldMultiplicityHistoryKeepsOriginalProfileBytes() external {
        legacy = true;
        super.setUp();
        _source(false);
        _policyFor(1, artistId, artist, keys);
        _policyFor(2, secondId, second, secondKeys);
        Next memory n = _cutover(true);
        MH.Request memory p = _request();
        bytes32 value = _hydrate(n, p);
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
        (,,,,,,, bytes memory payload) = abi.decode(
            n.archive.artistEvidenceBytesV2(id, 1),
            (uint16, bytes32, uint16, address, bytes32, T.Snapshot[7], T.Snapshot[7], bytes)
        );
        (bytes32 profile,,,,, AH.OwnerData[7] memory data) = abi.decode(
            payload, (bytes32, address, address, CP.Checkpoint[7], AH.Query, AH.OwnerData[7])
        );
        require(
            profile == keccak256("6529STREAM_ARTIST_MULTIPLE_LIVING_HYDRATION_V1"),
            "legacy profile is not silently replaced"
        );
        (bytes32 tag, MH.Bundle memory b) = abi.decode(data[2].typedState, (bytes32, MH.Bundle));
        require(
            tag == keccak256("6529STREAM_ARTIST_MULTIPLE_LIVING_STATE_V1")
                && keccak256(data[2].typedState) == keccak256(abi.encode(tag, b)),
            "old canonical state encoding"
        );
        for (uint256 i; i < b.rows.length; ++i) {
            require(
                keccak256(b.rows[i].state)
                    == keccak256(
                        IStreamArtistMultipleHydrationIdentity(suite.owners[2])
                            .authorityLivingIdentityHydrationState(b.rows[i].query)
                    ),
                "unchanged original baseline export bytes"
            );
        }
    }

    function testOverlargeCompleteProfilePreservesOriginalCarrierRefusal() external {
        _source(false);
        for (uint256 i; i < 12; ++i) {
            bytes32 grant = _grantFor(artistId, artist, keys, 0, 0);
            _revokeGrant(artistId, artist, keys, grant);
        }
        Next memory n = _cutover(true);
        MH.Request memory p = _request();
        D.CoordinatorContext memory x = D.CoordinatorContext(
            n.coordinator.suiteConfiguration(),
            address(n.coordinator.reads()),
            n.coordinator.configurationHash()
        );
        StreamArtistHydrationPrepared.Bundle memory h = StreamArtistMultipleDelegationSource.prepare(
            x, p, suite, address(ingress), address(coordinator)
        );
        bytes memory payload = abi.encode(
            MD.PROFILE, address(ingress), address(coordinator), p.expectedSource, h.q, h.data
        );
        uint256 length =
            abi.encode(
            uint16(1),
            x.configurationHash,
            uint16(60),
            address(this),
            bytes32(0),
            h.before_,
            h.before_,
            payload
        )
        .length;
        require(length > 24575, "concrete oversized complete profile");
        vm.expectRevert(abi.encodeWithSelector(T.BoundExceeded.selector, length, uint256(24575)));
        _hydrate(n, p);
        _empty(n);
    }

    function testSecondArtistRevisionAndGrantRemainSeparateFromFirstIdentity() external {
        _source(false);
        bytes memory document = bytes("second revised document");
        StreamArtistIdentityRevisionTypes.Revision memory revision =
            StreamArtistIdentityRevisionTypes.Revision(
                secondId,
                ingress.operativeIdentityRecord(secondId),
                keccak256(document),
                "urn:revision"
            );
        uint256 nonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(secondId).nonceHint;
        T.Authorization memory a = T.Authorization(nonce, uint64(block.timestamp), "");
        bytes32 digest = ingress.identityRevisionDigest(revision, a);
        a.signature = _sign(second, secondKeys, digest);
        _auth(secondId, digest, nonce);
        _candidate(
            2,
            "identity_authority.replay.identity_revision_chain",
            keccak256(abi.encode(secondId, bytes32(0), revision.previousRecordHash))
        );
        bytes32 record = ingress.recordIdentityRevision(revision, a, document, "Second Revised");
        bytes32 grant = _grantFor(secondId, second, secondKeys, 0, 2);
        Next memory n = _cutover(true);
        MH.Request memory p = _request();
        _parity(n, p, _hydrate(n, p), _one(grant));
        require(
            n.registry.operativeIdentityRecord(secondId) == keccak256(document)
                && keccak256(n.registry.identityRecordBytes(secondId)) == keccak256(document),
            "second exact current document"
        );
        require(
            keccak256(abi.encode(n.registry.identityRevisionRecord(record)))
                == keccak256(abi.encode(ingress.identityRevisionRecord(record))),
            "original revision domain/chain/nonce"
        );
        require(
            n.registry.operativeIdentityRecord(artistId)
                == ingress.operativeIdentityRecord(artistId),
            "first current identity unchanged"
        );
    }

    function testGlobalGrantJoinsSaleInFirstCollectionAndPolicyInSecond() external {
        _source(true);
        bytes32 grant = _grantFor(artistId, artist, keys, 0, 2);
        DelegationHydrationSaleFacts sale = new DelegationHydrationSaleFacts(address(core));
        Sale.Consent memory terms = Sale.Consent(1, address(sale), sale.ID(), sale.CONFIG());
        (address modules,,,,,,,,,) = core.getSatellitePointer(keccak256("MODULE_REGISTRY"));
        avm.mockCall(
            modules,
            abi.encodeCall(
                IStreamModuleRegistry.isModuleEligible,
                (address(sale), sale.streamModuleType(), sale.streamModuleInterfaceId())
            ),
            abi.encode(true)
        );
        T.Authorization memory a = T.Authorization(0, type(uint64).max, "");
        bytes32 digest = ingress.saleConsentDigest(terms, a);
        a.signature = _delegateSignature(digest);
        _delegateOrigins(artistId, digest, 0);
        bytes32 record = IStreamArtistDelegatedConsent(address(ingress))
            .recordDelegatedSaleConsent(terms, grant, a);
        T.Binding memory binding = coordinator.reads().acceptedBinding(1);
        _candidate(
            6,
            "consent_finality.replay.sale_consent_key",
            keccak256(abi.encode(terms, binding.generation, binding.bindingHash))
        );
        _delegatedPolicy(2, artistId, grant, 1);
        _revokeGrant(artistId, artist, keys, grant);
        Next memory n = _cutover(true);
        MH.Request memory p = _request();
        _parity(n, p, _hydrate(n, p), _one(grant));
        T.SuiteConfiguration memory s = n.coordinator.suiteConfiguration();
        require(
            keccak256(
                abi.encode(IStreamArtistSaleConsentOwner(s.owners[6]).saleConsentRecord(record))
            )
            == keccak256(
                abi.encode(IStreamArtistSaleConsentOwner(suite.owners[6]).saleConsentRecord(record))
            ),
            "full original sale record"
        );
        require(
            n.registry.recordDelegation(record) == grant
                && n.registry.delegationRecord(grant).uses == 2,
            "one global grant counts both capabilities/collections"
        );
        vm.prank(address(sale));
        n.registry.requireSaleConsent(terms.collectionId, terms.saleId, terms.saleConfigHash);
    }

    function testCompactTagsAndTrailingBytesCannotAliasAnotherOwner() external {
        MD.Identities memory p;
        p.rows = new MD.IdentityRow[](0);
        p.collectionIds = new uint256[](0);
        bytes memory canonical = abi.encode(MD.IDENTITY, p);
        require(
            keccak256(abi.encode(StreamArtistMultipleDelegationCodec.identity(canonical)))
                == keccak256(abi.encode(p)),
            "canonical codec exact"
        );
        avm.expectRevert(T.InvalidRecord.selector);
        StreamArtistMultipleDelegationCodec.identity(abi.encode(MD.BINDING, p));
        avm.expectRevert(T.InvalidRecord.selector);
        StreamArtistMultipleDelegationCodec.identity(bytes.concat(canonical, bytes32(0)));
    }

    function testSameDelegateHasTwoIndependentArtistNonceLanesAndGrantHeads() external {
        directHistory = true;
        _source(false);
        bytes32 first = _grantFor(artistId, artist, keys, 1, 1);
        bytes32 other = _grantFor(secondId, second, secondKeys, 2, 1);
        _delegatedPolicy(2, secondId, other, 0);
        _delegatedPolicy(1, artistId, first, 0);
        Next memory n = _cutover(true);
        MH.Request memory p = _request();
        bytes32 roots = _allRoots(n.coordinator);
        bytes32[] memory grants = new bytes32[](2);
        grants[0] = first;
        grants[1] = other;
        bytes32 value = _hydrate(n, p);
        _parity(n, p, value, grants);
        _evidence(n, p, value, roots);
        (bool firstUsed, uint256 firstHint) =
            n.registry.delegatedNonceState(artistId, address(delegateSafe), 0);
        (bool secondUsed, uint256 secondHint) =
            n.registry.delegatedNonceState(secondId, address(delegateSafe), 0);
        require(
            firstUsed && secondUsed && firstHint == 1 && secondHint == 1,
            "separate original nonce-zero consumptions"
        );
        require(
            n.registry.recordDelegation(savedPolicies[0]) == first
                && n.registry.recordDelegation(savedPolicies[1]) == other,
            "same delegate never cross-substitutes Artist grant"
        );
    }
}
