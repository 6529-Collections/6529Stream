// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamArtistPublicationAuthorityHydration as PublicationHydrate,
    IStreamArtistPublicationHydrationOwner as PublicationExport,
    StreamArtistPublicationHydrationTypes as PubH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPublicationAuthorityHydration.sol";
import "../../../smart-contracts/domains/artist/StreamArtistPublicationHydration.sol";
import {
    IStreamArtistReadinessAuthorityHydration as ReadyHydrate,
    IStreamArtistReadinessAttributionOwner as ReadyAttr,
    IStreamArtistReadinessConsentOwner as ReadyConsent,
    StreamArtistReadinessHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import "../../../smart-contracts/domains/artist/StreamArtistAttestationHydration.sol";
import "../../../smart-contracts/domains/artist/StreamArtistContentHydration.sol";
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
abstract contract ArtistPublicationHydrationFixture is ArtistOnboardingFixture {
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
    bytes32 internal savedPolicy;
    bytes internal savedPolicySignature;
    bytes32 internal revokedDigest;

    T.EconomicsConsent[] internal selectedEconomics;
    bytes32[] internal selectedRecords;
    bytes internal firstEconomicsSignature;

    function _economicHistory() internal {
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
        _approveEconomics(second);
    }

    function _approveEconomics(T.AssignmentFact memory fact) internal {
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

    function _economicsRequest() internal view returns (EH.Request memory p) {
        p.authority = _request();
        p.economics = selectedEconomics;
    }

    function _assertEconomics(Next memory n) internal {
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

    RH.AttestationInput[] internal originalAttestations;
    bytes32[] internal originalAttestationRecords;
    bytes32 internal originalRatification;
    Content.Consent internal pendingContent;
    bytes32 internal pendingContentRecord;

    /// @dev Fresh actual source branch with a short lawful identity URI. The shared
    /// fixture's 2048-byte URI is a read-gas stress case, not this bounded inline Archive profile.
    function _compactSource() internal {
        Next memory source = _next();
        core.set(POINTER, address(source.registry), false);
        ingress = source.registry;
        archive = source.archive;
        coordinator = source.coordinator;
        suite = coordinator.suiteConfiguration();
        nextNonce = 0;
        T.BindingProposal memory proposal = _proposal(0);
        proposal.identityRecordURI = "urn:publication-source:identity";
        (artistId,) = ingress.proposeArtistBinding(
            1, proposal, bytes("unit identity document"), "Artist Safe"
        );
        metadata.configureArtist(address(ingress));
        POLICY = _prospective(false);
    }

    function _readinessHistory() internal {
        _compactSource();
        _economicHistory();
        _recordRatification();
        pendingContent = _contentProposal(keccak256("next admitted source content"));
        pendingContentRecord = _recordContent(pendingContent);
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        _recordHistoricalAttestation(
            9,
            bytes32(uint256(uint160(suite.core))),
            StreamArtistHashes.deploymentFacts(
                StreamArtistHashes.Environment(
                    block.chainid, address(ingress), suite.core, suite.mintManager
                ),
                1,
                b
            ),
            keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1")
        );
        _recordHistoricalAttestation(
            10,
            artistId,
            ingress.operativeIdentityRecord(artistId),
            keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")
        );
    }

    function _recordRatification() internal returns (bytes32 record) {
        (, bytes32 state) = metadata.currentArtistContentState(1);
        T.Ratification memory p = T.Ratification(1, address(metadata), state);
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.contentRatificationDigest(p, a);
        _authOrigins(digest, a.nonce);
        a.signature = _signature(digest);
        _artistCall(abi.encodeCall(IStreamArtistOnboarding.recordContentRatification, (p, a)));
        record = IStreamArtistConsentOwner(suite.owners[6]).firstReleaseRatification(1).recordHash;
        _candidate(
            6, "consent_finality.replay.ratification_key", keccak256(abi.encode(uint256(1), record))
        );
        if (originalRatification == 0) originalRatification = record;
    }

    function _recordContent(Content.Consent memory p) internal returns (bytes32 record) {
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.contentConsentDigest(p, a);
        _authOrigins(digest, a.nonce);
        a.signature = _signature(digest);
        record = ingress.recordContentConsent(p, a);
        _candidate(
            6,
            "consent_finality.replay.content_consent_key",
            keccak256(abi.encode(keccak256(abi.encode(p, uint64(1))), record))
        );
    }

    function _recordHistoricalAttestation(
        uint8 kind,
        bytes32 subject,
        bytes32 state,
        bytes32 schema
    ) internal {
        bytes memory statement = abi.encode(kind, subject, state, schema);
        T.Attestation memory p = T.Attestation(
            1, kind, subject, state, schema, keccak256(statement), "urn:retained:source"
        );
        T.Authorization memory a = _authorization(true);
        bytes32 digest = ingress.attestationDigest(p, a);
        _authOrigins(digest, a.nonce);
        a.signature = _signature(digest);
        _artistCall(
            abi.encodeCall(IStreamArtistOnboarding.recordArtistAttestation, (p, a, statement))
        );
        originalAttestations.push(RH.AttestationInput(p, a.nonce));
        originalAttestationRecords.push(
            IStreamArtistAttributionOwner(suite.owners[4]).attestation(1, kind, subject).recordHash
        );
    }

    function _readyRequest() internal view returns (RH.Request memory p) {
        p.economics = _economicsRequest();
        p.attestations = originalAttestations;
    }

    function _freshDeployment(Next memory n) internal returns (bytes32 record) {
        T.SuiteConfiguration memory s = n.coordinator.suiteConfiguration();
        T.Binding memory b = IStreamArtistBindingOwner(s.owners[0]).binding(1);
        bytes32 state = StreamArtistHashes.deploymentFacts(
            StreamArtistHashes.Environment(
                block.chainid, address(n.registry), suite.core, suite.mintManager
            ),
            1,
            b
        );
        bytes memory statement = abi.encode("new actual successor deployment", state);
        T.Attestation memory p = T.Attestation(
            1,
            9,
            bytes32(uint256(uint160(suite.core))),
            state,
            keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1"),
            keccak256(statement),
            "urn:successor:approval"
        );
        T.Authorization memory a = T.Authorization(
            IStreamArtistIdentityOwner(n.identity).identity(artistId).nonceHint,
            uint64(block.timestamp),
            ""
        );
        require(
            this.executeTargetSafe(
                address(n.registry),
                abi.encodeCall(IStreamArtistOnboarding.recordArtistAttestation, (p, a, statement))
            ),
            "real Safe approves changed successor deployment"
        );
        record =
        IStreamArtistAttributionOwner(s.owners[4]).attestation(1, 9, p.subjectId).recordHash;
    }

    function _assertHistorical(Next memory n) internal view {
        T.SuiteConfiguration memory s = n.coordinator.suiteConfiguration();
        for (uint256 j; j < originalAttestationRecords.length; ++j) {
            bytes32 record = originalAttestationRecords[j];
            T.AttestationRecord memory r =
                IStreamArtistAttributionOwner(s.owners[4]).attestationRecord(record);
            require(
                keccak256(abi.encode(r))
                    == keccak256(
                        abi.encode(
                            IStreamArtistAttributionOwner(suite.owners[4]).attestationRecord(record)
                        )
                    ),
                "exact original historical attestation"
            );
            require(
                ReadyAttr(s.owners[4]).attestationAuthorityClass(record) == 1,
                "exact recorded signing class"
            );
            require(
                keccak256(
                        IStreamArtistAttributionOwner(s.owners[4]).statementBytes(r.statementHash)
                    )
                    == keccak256(
                        IStreamArtistAttributionOwner(suite.owners[4])
                            .statementBytes(r.statementHash)
                    ),
                "complete original statement bytes"
            );
            require(
                keccak256(IStreamArtistIdentityOwner(n.identity).signatureBundle(record))
                    == keccak256(
                        IStreamArtistIdentityOwner(suite.owners[2]).signatureBundle(record)
                    ),
                "original signature bytes without resigning"
            );
        }
        require(
            IStreamArtistConsentOwner(s.owners[6])
                .ratificationRecord(originalRatification)
                .recordHash == originalRatification,
            "original ratification history"
        );
    }

    function _candidate(uint256 owner, string memory surface, bytes32 scope) internal {
        candidates[owner].push(AH.Origin(keccak256(bytes(surface)), scope));
    }

    function _authOrigins(bytes32 digest, uint256 nonce) internal {
        _candidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(artistId, digest))
        );
        _candidate(
            2, "identity_authority.replay.nonce_allocator", keccak256(abi.encode(artistId, nonce))
        );
    }

    function _baseline() internal {
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
        _candidate(2, "identity_authority.replay.one_way_cutover_latch", 0);
    }

    function _revoke(StreamArtistAuthorizationTypes.Revocation memory p) internal {
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

    function _request() internal view returns (AH.Request memory p) {
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

    function _cutover(bool seal, bool latchCollection) internal returns (Next memory n) {
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

    function _allRoots(StreamArtistOnboardingCoordinator c) internal view returns (bytes32) {
        T.SuiteConfiguration memory s = c.suiteConfiguration();
        T.Snapshot[7] memory snapshots;
        for (uint256 j; j < 7; ++j) {
            snapshots[j] = IStreamArtistOwner(s.owners[j]).ownerStateSnapshotV2();
        }
        return keccak256(abi.encode(snapshots));
    }

    function _notHydrated(Next memory n) internal view {
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

    function _leaves(History h) internal view returns (HT.Leaf[] memory rows) {
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

    uint256[] internal publicationIndices;
    P.Publication[] internal publications;
    T.Authorization[] internal publicationAuthorizations;
    ArtistPublicationHostFixture internal candidateHost;

    function _publicationHistory() internal {
        actualSaleRegistryFixture = true;
        setUp();
        _compactSource();
        _economicHistory();
        _recordRatification();
        candidateHost = new ArtistPublicationHostFixture(address(core));
        _saleRegister(
            saleModules,
            factory.governanceAuthority(),
            address(candidateHost),
            keccak256("COLLECTION_METADATA"),
            type(IStreamArtistRecordPublicationHost).interfaceId
        );
        core.set(keccak256("COLLECTION_METADATA"), address(candidateHost), false);
        (P.Publication memory pub, T.Attestation memory p, bytes memory statement) =
            _publicationTerms(candidateHost, true);
        _recordPublication(pub, p, statement);
        (pub, p, statement) = _publicationTerms(candidateHost, false);
        _recordPublication(pub, p, statement);
    }

    function _recordPublication(
        P.Publication memory pub,
        T.Attestation memory p,
        bytes memory statement
    ) internal returns (bytes32 record) {
        T.Authorization memory a = _authorization(true);
        bytes32 digest = ingress.attestationDigest(p, a);
        _authOrigins(digest, a.nonce);
        a.signature = _signature(digest);
        _artistCall(
            abi.encodeCall(IStreamArtistOnboarding.recordArtistAttestation, (p, a, statement))
        );
        record =
        IStreamArtistAttributionOwner(suite.owners[4])
        .attestation(1, p.subjectKind, p.subjectId)
        .recordHash;
        require(record == _publicationExpected(p, a, 1), "independent original op24 preimage");
        publicationIndices.push(originalAttestations.length);
        originalAttestations.push(RH.AttestationInput(p, a.nonce));
        originalAttestationRecords.push(record);
        publications.push(pub);
        publicationAuthorizations.push(a);
    }

    function _assertPublications(Next memory n) internal view {
        _assertHistorical(n);
        T.SuiteConfiguration memory target = n.coordinator.suiteConfiguration();
        for (uint256 j; j < publicationIndices.length; ++j) {
            bytes32 record = originalAttestationRecords[publicationIndices[j]];
            IStreamArtistRecordPublicationOwner.Record memory saved = IStreamArtistRecordPublicationOwner(
                    target.owners[4]
                ).publicationAttestation(record);
            require(
                keccak256(abi.encode(saved))
                    == keccak256(
                        abi.encode(
                            IStreamArtistRecordPublicationOwner(suite.owners[4])
                                .publicationAttestation(record)
                        )
                    ),
                "whole original publication and admission evidence"
            );
            require(
                saved.evidence.signer == address(artist) && saved.evidence.authorityClass == 1
                    && saved.evidence.publicationHash == keccak256(abi.encode(publications[j])),
                "exact old signer, class and publication preimage"
            );
        }
    }

}
