// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistHistoryState as HistoryStorage
} from "../../../smart-contracts/domains/artist/StreamArtistHistoryState.sol";
import {
    IStreamArtistAcceptanceOwner as Acceptance
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAcceptanceOwner.sol";
import {
    IStreamArtistAttributionOwner as Attribution
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    IStreamArtistCollaboratorBindingOwner as Terms
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistCollaboratorBindingOwner.sol";
import {
    IStreamArtistBindingLifecycle as Lifecycle
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingLifecycle.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV3 as IdentityInventory
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";
import {
    IStreamArtistRecoveryPayoutOwnerV3 as PayoutInventory
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryPayoutOwnerV3.sol";

import "./StreamArtistRecoveredAuthorityActual.t.sol";
import { OfficialSafe } from "../../helpers/OfficialSafeFixture.sol";
import {
    StreamArtistEstateTypes as Estate
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistEstateTypes.sol";
import {
    StreamArtistSuccessionTypes as Succ
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSuccessionTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleCodec as Aggregate
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleCodec.sol";
import {
    StreamArtistRecoveredMultipleIdentityNonces as Union
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleIdentityNonces.sol";
import {
    StreamArtistRecoveredMultipleCollectionRows as CollectionRows
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleCollectionRows.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistConsentOwner as Consent
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistConsentOwner.sol";

/// @notice Actual seven-owner aggregate flows. Core and scheduled governance remain explicit unit boundaries.
/// @dev No owner state, capability, checkpoint, nonce or history receipt is mocked. Native execution pending.
abstract contract ArtistRecoveredMultipleFixture is StreamArtistRecoveredAuthorityActualTest {
    bytes32[] internal multiArtists;
    bytes32[2] internal multiCollectionArtists;
    bytes32[2] internal multiPolicies;
    bytes32[2] internal multiPolicyRecords;
    bytes32[2] internal multiRecovery;
    address[2] internal multiAuthorities;
    bytes32 private constant MULTI_LEAF =
        0xea04da6644046a7c731e99312c32df311e81aa7e137dfc2a49c2116bb325195d;

    function _multiSource(bool shared, bool estate) internal {
        bytes32 first = artistId;
        OfficialSafe firstSafe = artist;
        uint256[] memory firstKeys = keys;
        _newRotationSafe(991001);
        OfficialSafe second = shared ? firstSafe : rotationSafe;
        uint256[] memory secondKeys = shared ? firstKeys : rotationKeys;
        T.BindingProposal memory proposal = _multiProposal(shared ? first : bytes32(0));
        proposal.artistAddress = address(second);
        (bytes32 secondId,) = ingress.proposeArtistBinding(
            2, proposal, bytes("unit identity document"), "Artist Safe"
        );
        _rhCandidate(
            0, "binding_lifecycle.replay.proposal_key", keccak256(abi.encode(uint256(2), uint64(1)))
        );
        if (!shared) {
            _rhCandidate(
                2,
                "identity_authority.replay.nonce_allocator",
                keccak256(abi.encode(bytes32(0), uint256(1)))
            );
        }
        multiCollectionArtists = [first, secondId];
        multiArtists = new bytes32[](shared ? 1 : 2);
        multiArtists[0] = first;
        if (!shared) {
            multiArtists[1] = secondId;
            if (secondId < first) {
                multiArtists[0] = secondId;
                multiArtists[1] = first;
            }
        }
        artistId = secondId;
        artist = second;
        keys = secondKeys;
        nextNonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(secondId).nonceHint;
        T.Authorization memory accepted = _authorization(false);
        bytes32 digest = ingress.acceptanceDigest(2, accepted);
        _rhAuthorization(digest, accepted.nonce);
        accepted.signature = _signature(digest);
        ingress.acceptArtistBinding(2, accepted);
        _rhCandidate(
            3,
            "acceptance_lifecycle.replay.record_uniqueness",
            keccak256(abi.encode(uint256(2), uint64(1), uint8(1), address(second)))
        );
        _multiPolicy(2);
        artistId = first;
        artist = firstSafe;
        keys = firstKeys;
        nextNonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(first).nonceHint;
        _rhBaseline();
        multiRecovery[0] = rhRecovery;
        multiAuthorities[0] = address(rotationSafe);
        _adoptRotatedSafe();
        vm.warp(ingress.artistTransitionState(rhRecovery).postWindowEndsAt);
        _multiPolicy(1);
        _multiPayout();
        if (!shared) {
            artistId = secondId;
            artist = second;
            keys = secondKeys;
            nextNonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(secondId).nonceHint;
            if (estate) _multiEstateRecovery();
            else _multiLivingRecovery();
            multiAuthorities[1] = address(rotationSafe);
        } else {
            multiRecovery[1] = multiRecovery[0];
            multiAuthorities[1] = multiAuthorities[0];
        }
        require(
            keccak256(
                IStreamArtistIdentityOwner(suite.owners[2])
                    .identityDocumentBytes(keccak256("unit identity document"))
            ) == keccak256("unit identity document"),
            "authentic shared global document"
        );
    }

    function _multiPolicy(uint256 collection) internal {
        T.PolicyConsent memory p = T.PolicyConsent(
            collection, PHASE, keccak256(abi.encode("multi recovered policy", collection))
        );
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.policyConsentDigest(p, a);
        _rhAuthorization(digest, a.nonce);
        a.signature = _signature(digest);
        multiPolicyRecords[collection - 1] = ingress.recordPolicyConsent(p, a);
        multiPolicies[collection - 1] = p.policyHash;
        _rhCandidate(
            6,
            "consent_finality.replay.policy_consent_key",
            keccak256(abi.encode(collection, p.phaseId, p.policyHash))
        );
    }

    function _multiPayout() internal {
        T.PayoutDesignation memory p = T.PayoutDesignation(artistId, address(artist), 0);
        T.Authorization memory a = _authorization(true);
        bytes32 digest = ingress.payoutDesignationDigest(p, a);
        _rhAuthorization(digest, a.nonce);
        a.signature = _signature(digest);
        ingress.recordPayoutDesignation(p, a);
        _rhCandidate(
            5, "payout_lifecycle.replay.designation_chain", keccak256(abi.encode(artistId))
        );
    }

    function _multiRequest() internal view returns (RH.Request memory r) {
        r = _rhRequest();
        r.records.authority.artistIds = multiArtists;
        r.records.authority.collections = new MH.Collection[](2);
        for (uint256 i; i < 2; ++i) {
            AH.PolicyKey[] memory policies = new AH.PolicyKey[](1);
            policies[0] = AH.PolicyKey(PHASE, multiPolicies[i]);
            r.records.authority.collections[i] =
                MH.Collection(multiCollectionArtists[i], i + 1, policies);
        }
    }

    function _multiCutover() internal returns (Successor memory next) {
        next = _multiNext();
        HT.Leaf[] memory rows = _multiLeaves(History(address(ingress)));
        (bytes32 root,) = _multiProof(address(ingress), rows, 0);
        bytes32 manifest = keccak256("recovered complete multiple manifest");
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

    function _multiLeaves(History h) private view returns (HT.Leaf[] memory rows) {
        uint256 total;
        for (uint256 i; i < multiArtists.length + 2; ++i) {
            (, uint64 n) = h.artistHistoryLane(
                i < multiArtists.length ? 1 : 2,
                i < multiArtists.length ? multiArtists[i] : bytes32(i - multiArtists.length + 1)
            );
            total += n;
        }
        rows = new HT.Leaf[](total);
        uint256 at;
        for (uint256 i; i < multiArtists.length + 2; ++i) {
            uint8 kind = i < multiArtists.length ? 1 : 2;
            bytes32 key =
                i < multiArtists.length ? multiArtists[i] : bytes32(i - multiArtists.length + 1);
            (, uint64 n) = h.artistHistoryLane(kind, key);
            for (uint64 j; j < n; ++j) {
                (bytes32 r, bytes32 chain) = h.artistHistoryRecordAt(kind, key, j);
                rows[at++] = HT.Leaf(kind, key, j, r, chain);
            }
        }
    }

    function _multiPrepare(Successor memory next)
        internal
        view
        returns (RH.Request memory r, Commit.Prepared memory p)
    {
        r = _multiRequest();
        p = Prepared.prepare(next.coordinator.suiteConfiguration(), r);
        r.expectedSemanticInventory = Prepared.inventory(p);
    }

    function _multiDestinationHash(Successor memory next) internal view returns (bytes32 h) {
        T.SuiteConfiguration memory target = next.coordinator.suiteConfiguration();
        h = keccak256(
            abi.encode(
                _rhDestinationHash(next),
                IStreamArtistIdentityOwner(next.identity).nextRegistrationNonce(),
                History(next.identity).artistHistoryContinuityCommitment(),
                Guards.collectNonces(next.identity, CP(next.identity).authorityCheckpoint()),
                IStreamArtistRecoveredTimingInventory(next.identity).recoveredTimingCheckpoint()
            )
        );
        for (uint256 i; i < multiArtists.length; ++i) {
            bytes32 id = multiArtists[i];
            T.Identity memory current = IStreamArtistIdentityOwner(next.identity).identity(id);
            T.Identity memory original = IStreamArtistIdentityOwner(suite.owners[2]).identity(id);
            (bytes32 tip, uint64 count) = History(next.identity).artistHistoryLane(1, id);
            h = keccak256(
                abi.encode(
                    h,
                    current,
                    IStreamArtistIdentityOwner(next.identity)
                        .activeIdentity(original.authorityAddress),
                    IStreamArtistIdentityOwner(next.identity)
                        .identityDocumentBytes(original.identityRecordHash),
                    IdentityInventory(next.identity).recoveryRewindInventoryV3(id),
                    PayoutInventory(target.owners[5]).payoutRewindInventoryV3(id),
                    tip,
                    count,
                    _activated(next.identity, 1, id)
                )
            );
        }
        for (uint256 i; i < 2; ++i) {
            bytes32 bindingHash = Binding(suite.owners[0]).binding(i + 1).bindingHash;
            (uint8 status, uint64 generation) =
                Attribution(target.owners[4]).attributionState(i + 1);
            (bytes32 tip, uint64 count) =
                History(next.identity).artistHistoryLane(2, bytes32(i + 1));
            h = keccak256(
                abi.encode(
                    h,
                    Binding(target.owners[0]).binding(i + 1),
                    Binding(target.owners[0]).bindingAt(i + 1, 1),
                    Terms(target.owners[0]).bindingTerms(i + 1, 1),
                    Lifecycle(target.owners[0]).bindingTermination(i + 1, 1),
                    Acceptance(target.owners[3]).acceptanceRecord(bindingHash),
                    Acceptance(target.owners[3]).acceptedAt(bindingHash),
                    status,
                    generation,
                    Consent(target.owners[6]).policyRecord(i + 1, PHASE, multiPolicies[i]),
                    IStreamArtistIdentityRecoveryOwner(next.identity)
                        .identityRecoveryRecord(multiRecovery[i]),
                    tip,
                    count,
                    _activated(next.identity, 2, bytes32(i + 1))
                )
            );
        }
    }

    /// @dev Read-only access to the original internal activation map. The compiler derives its
    /// storage slot from the production State type; the fixture never writes any protocol slot.
    function _activated(address owner, uint8 kind, bytes32 id) private view returns (bytes32) {
        HistoryStorage.State storage state = HistoryStorage.state();
        mapping(bytes32 => bytes32) storage cells = state.hydrated;
        uint256 slot;
        assembly ("memory-safe") { slot := cells.slot }
        return vm.load(owner, keccak256(abi.encode(HistoryStorage.key(kind, id), slot)));
    }

    function _multiAssert(Successor memory next, Commit.Prepared memory prepared) internal view {
        T.SuiteConfiguration memory target = next.coordinator.suiteConfiguration();
        bytes32 value = HydrationOwner(next.identity).authorityHydrationCommitment();
        require(value != 0, "single aggregate commitment");
        for (uint8 owner; owner < 7; ++owner) {
            (RH.ExportHeader memory h, Payload.Payload memory payload) =
                Payload.decode(prepared.data[owner].typedState, owner);
            require((h.requiredFeatures & _multiFeature()) != 0, "explicit aggregate capability");
            (RH.OwnerProvenance memory prefix, bytes32 committed,) =
                RecoveredOwner(target.owners[owner]).recoveredHydrationImportedPrefix();
            require(
                committed == value
                    && keccak256(abi.encode(prefix)) == keccak256(abi.encode(payload.provenance)),
                "complete original unfiltered owner prefix"
            );
            T.Snapshot memory after_ = Owner(target.owners[owner]).ownerStateSnapshotV2();
            require(
                after_.revision == prepared.admission.before_[owner].revision + 1
                    && after_.recordChainTip == prepared.admission.before_[owner].recordChainTip,
                "exactly one owner commit and no synthetic native record"
            );
            require(
                Native(target.owners[owner]).artistNativeReceiptCount() == 0,
                "hydration adds no native semantic receipt"
            );
            require(
                keccak256(abi.encode(Publications.collect(target.owners[owner], owner)))
                    == keccak256(abi.encode(payload.publications)),
                "full original publication catalog"
            );
            require(
                keccak256(
                    abi.encode(
                        Guards.collectNonces(
                            target.owners[owner], CP(target.owners[owner]).authorityCheckpoint()
                        )
                    )
                ) == keccak256(abi.encode(payload.nonces)),
                "all original global nonce words"
            );
        }
        for (uint256 i; i < multiArtists.length; ++i) {
            bytes32 id = multiArtists[i];
            require(
                keccak256(abi.encode(IStreamArtistIdentityOwner(target.owners[2]).identity(id)))
                    == keccak256(
                        abi.encode(IStreamArtistIdentityOwner(suite.owners[2]).identity(id))
                    ),
                "exact distinct principal head"
            );
            (address a, bytes32 b) = ingress.artistPayoutAccount(id);
            (address c, bytes32 e) = next.registry.artistPayoutAccount(id);
            require(a == c && b == e, "per Artist complete payout head");
            require(
                IStreamArtistIdentityOwner(next.identity)
                        .activeIdentity(
                            IStreamArtistIdentityOwner(next.identity).identity(id).authorityAddress
                        ) == id && _activated(next.identity, 1, id) == value,
                "every distinct principal and Artist lane activated once"
            );
        }
        require(
            IStreamArtistIdentityOwner(next.identity).nextRegistrationNonce()
                == multiArtists.length,
            "one unchanged global registration nonce"
        );
        for (uint256 i; i < 2; ++i) {
            require(
                _activated(next.identity, 2, bytes32(i + 1)) == value,
                "every collection lane activated once"
            );
            require(
                keccak256(abi.encode(Binding(target.owners[0]).binding(i + 1)))
                    == keccak256(abi.encode(Binding(suite.owners[0]).binding(i + 1))),
                "both original bindings"
            );
            require(
                Consent(target.owners[6]).policyRecord(i + 1, PHASE, multiPolicies[i])
                    == multiPolicyRecords[i],
                "each collection policy installed"
            );
            require(
                keccak256(
                    abi.encode(
                        IStreamArtistIdentityRecoveryOwner(next.identity)
                            .identityRecoveryRecord(multiRecovery[i])
                    )
                )
                == keccak256(
                    abi.encode(
                        IStreamArtistIdentityRecoveryOwner(suite.owners[2])
                            .identityRecoveryRecord(multiRecovery[i])
                    )
                ),
                "original recovery bytes preserved"
            );
        }
        (, Payload.Payload memory identity) = Payload.decode(prepared.data[2].typedState, 2);
        M.State memory aggregate = _multiDecode(identity);
        IH.NonceLane[] memory lanes = _multiOrdered(aggregate, identity.nonces);
        for (uint256 i; i < lanes.length; ++i) {
            CP.NonceIndex memory actual = CP(next.identity).authorityNonceIndexAt(i);
            require(
                actual.kind == identity.nonces[i].index.kind
                    && actual.key == identity.nonces[i].index.key,
                "original global nonce index order"
            );
        }
    }

    function _multiProposal(bytes32 id) internal view virtual returns (T.BindingProposal memory) {
        return _proposal(id);
    }

    function _multiFeature() internal pure virtual returns (uint256) {
        return RH.MULTIPLE_BASE;
    }

    function _multiDecode(Payload.Payload memory p) internal pure virtual returns (M.State memory) {
        return Aggregate.decode(2, p.semanticState, p.provenance);
    }

    function _multiOrdered(M.State memory s, RH.NonceInventory[] memory n)
        internal
        pure
        virtual
        returns (IH.NonceLane[] memory)
    {
        return Union.ordered(s, n);
    }

    function _multiLivingRecovery() private {
        _sizes();
        // Reuse the actual first Artist's guardian Safe, never redeploy its CREATE2 tuple.
        // The second recovered principal needs a distinct live authority address.
        _newRotationSafe(991002);
        address[] memory members = new address[](1);
        members[0] = address(delegateSafe);
        bytes32 guardianHash = _guardianRecord(members, 1, 10 days, nextNonce);
        _governedInitialContest();
        R.GuardianRecord memory guardian = ingress.guardianSetRecord(guardianHash);
        _rhAuthorization(
            ingress.guardianSetDigest(
                guardian.terms, T.Authorization(guardian.nonce, guardian.signedAt, "")
            ),
            guardian.nonce
        );
        _rhCandidate(
            2,
            "identity_authority.replay.guardian_set_chain",
            keccak256(abi.encode(artistId, guardian.nonce))
        );
        bytes32 contest = ingress.currentIdentityContestCause(artistId).facts.referenceHash;
        _rhCandidate(
            2,
            "identity_authority.replay.contest_record_hash_and_subject_key",
            keccak256(
                abi.encode(
                    keccak256("subject"),
                    artistId,
                    bytes32(0),
                    keccak256("compromise evidence"),
                    keccak256("compromise reason")
                )
            )
        );
        _rhCandidate(
            2,
            "identity_authority.replay.contest_record_hash_and_subject_key",
            keccak256(abi.encode(keccak256("record"), contest))
        );
        Recovery.Request memory p = _terms();
        T.Authorization memory a = _acceptance(p);
        GovernanceCall[] memory calls =
            _schedule(keccak256(abi.encode("multi second recovery", artistId)), p, a);

        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        _rhCandidate(2, "identity_authority.replay.recovery_preparation", currentId);
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        Recovery.Context memory c = ingress.identityRecoveryContext(p, a);
        bytes32 recoveryHash = _rhExecuteRecovery(p, a);
        Recovery.Record memory recovery = ingress.identityRecoveryRecord(recoveryHash);
        require(
            recovery.fields.vestedAuthorityClass == 1
                && recovery.fields.newAddress == address(rotationSafe),
            "actual original class1 recovery"
        );
        _rhCandidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(artistId, recovery.acceptanceDigest))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(
                abi.encode(
                    keccak256("rotation_acceptance"), artistId, address(rotationSafe), a.nonce
                )
            )
        );
        _rhCandidate(
            2,
            "identity_authority.replay.contest_resolution",
            keccak256(abi.encode(artistId, c.causeHash))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.recovery_action",
            keccak256(abi.encode(currentId, c.scopeHash, c.oldValueHash, c.newValueHash))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.standing_retirement",
            keccak256(abi.encode(artistId, c.incumbent, recoveryHash))
        );
        _rhCandidate(2, "identity_authority.replay.one_way_cutover_latch", 0);
        uint256 count = Native(suite.owners[2]).artistNativeReceiptCount();
        require(
            count >= 2
                && Native(suite.owners[2]).artistNativeReceiptAt(count - 2).recordHash
                    == recoveryHash,
            "actual primary35 occurrence"
        );
        require(
            Native(suite.owners[2]).artistNativeReceiptAt(count - 1).operation == 35
                && NativeClock(suite.owners[2]).artistNativeReceiptRevisionAt(count - 2)
                    == NativeClock(suite.owners[2]).artistNativeReceiptRevisionAt(count - 1),
            "same original revision paired35"
        );

        multiRecovery[1] = recoveryHash;
    }

    function _multiEstateCapabilities() internal pure virtual returns(uint32) { return 2304; }

    function _multiEstateRecovery() private {
        // This existing Safe is a guardian, not the first Artist's recovered authority.
        // Reuse it as the original estate successor; do not repeat its CREATE2 deployment.
        address[] memory members = new address[](1);
        members[0] = address(artist);
        bytes32 guardianHash = _guardianRecord(members, 1, 10 days, nextNonce);
        R.GuardianRecord memory guardian = ingress.guardianSetRecord(guardianHash);
        _rhAuthorization(
            ingress.guardianSetDigest(
                guardian.terms, T.Authorization(guardian.nonce, guardian.signedAt, "")
            ),
            guardian.nonce
        );
        _rhCandidate(
            2,
            "identity_authority.replay.guardian_set_chain",
            keccak256(abi.encode(artistId, guardian.nonce))
        );
        Estate.Execution memory activation = _estatePendingFixture(_multiEstateCapabilities());
        bytes32 estateHash = activation.expectedActivationRecordHash;
        (Estate.RequestRecord memory item,,) = ingress.estateActivationRecord(estateHash);
        Succ.DesignationRecord memory designation =
            ingress.successorDesignationRecord(item.designationRecordHash);
        _rhAuthorization(
            ingress.successorDesignationDigest(
                designation.terms, T.Authorization(designation.nonce, designation.signedAt, "")
            ),
            designation.nonce
        );
        _rhCandidate(
            2,
            "identity_authority.replay.succession_chain",
            keccak256(abi.encode(designation.recordHash))
        );
        bytes32 digest = ingress.estateActivationDigest(item.terms, item.authorization);
        _rhCandidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(artistId, digest))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(
                abi.encode(
                    "estate_activation", artistId, item.terms.successor, item.authorization.nonce
                )
            )
        );
        _rhCandidate(2, "identity_authority.replay.activation_request_key", estateHash);
        uint256 nativeBefore = Native(suite.owners[2]).artistNativeReceiptCount();
        vm.warp(item.noticeEndsAt);
        ingress.executeEstateActivation(activation);

        require(
            Native(suite.owners[2]).artistNativeReceiptCount() == nativeBefore,
            "original40 has no normative new native row"
        );
        require(
            _snapshot(estateHash).operationId == 40 && _snapshot(estateHash).authorityClass == 3
                && _snapshot(estateHash).guardians.count == 1,
            "real40 freezes exact living guardian prefix"
        );
        _rhCandidate(2, "identity_authority.replay.activation_execution_key", estateHash);
        _rhCandidate(
            2,
            "identity_authority.replay.standing_retirement",
            keccak256(abi.encode(artistId, item.incumbent, estateHash))
        );
        artist = delegateSafe;
        keys = delegateKeys;
        nextNonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        vm.warp(ingress.artistTransitionState(estateHash).postWindowEndsAt);
        _multiEstateCompromise(estateHash);
        _newRotationSafe(882001);
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        Recovery.Request memory p = Recovery.Request(
            artistId,
            address(rotationSafe),
            3,
            cause.causeHash,
            ingress.latestIdentityContestDismissal(artistId),
            cause.facts.evidenceHash,
            cause.facts.reasonHash,
            new bytes32[](0)
        );
        T.Authorization memory a = _acceptance(p);
        GovernanceCall[] memory calls =
            _schedule(keccak256("estate source original recovery"), p, a);

        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        _rhCandidate(2, "identity_authority.replay.recovery_preparation", currentId);
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        Recovery.Context memory context = ingress.identityRecoveryContext(p, a);
        bytes32 recoveryHash = this.executeRegistered(p, a);
        _multiInactive();
        Recovery.Record memory recovered = ingress.identityRecoveryRecord(recoveryHash);
        require(
            recovered.fields.vestedAuthorityClass == 3
                && recovered.fields.newAddress == address(rotationSafe)
                && recovered.delegationEpoch == context.delegationEpoch + 1
                && _snapshot(recoveryHash).previousTransitionRecordHash == estateHash,
            "genuine registered class3 original35 retains40 ancestry"
        );
        _rhCandidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(artistId, recovered.acceptanceDigest))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(
                abi.encode(
                    keccak256("rotation_acceptance"), artistId, address(rotationSafe), a.nonce
                )
            )
        );
        _rhCandidate(
            2,
            "identity_authority.replay.contest_resolution",
            keccak256(abi.encode(artistId, context.causeHash))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.recovery_action",
            keccak256(
                abi.encode(currentId, context.scopeHash, context.oldValueHash, context.newValueHash)
            )
        );
        _rhCandidate(
            2,
            "identity_authority.replay.standing_retirement",
            keccak256(abi.encode(artistId, context.incumbent, recoveryHash))
        );
        _rhCandidate(2, "identity_authority.replay.one_way_cutover_latch", 0);

        multiRecovery[1] = recoveryHash;
    }

    function _multiEstateCompromise(bytes32 subject) private {
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        bytes32 evidence = keccak256(abi.encode("estate import real compromise", subject));
        bytes32 reason = keccak256(abi.encode("estate import compromise reason", subject));
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:estate-import:33"
        );
        (bytes32 scope, bytes32 old_, bytes32 next_) =
            ingress.identityContestGovernanceContext(artistId, subject, evidence, reason);
        _multiActive(keccak256("unit authority gas raise"), 1, scope, old_, next_);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(
                IStreamArtistIdentityContest.contestArtistIdentity,
                (artistId, subject, evidence, reason)
            ),
            1,
            scope,
            old_,
            next_
        );
        _multiInactive();
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.kind == 1 && cause.facts.authorityClass == 3 && cause.facts.priorStatus == 3
                && cause.facts.executedTransitionHash == subject
                && cause.facts.incumbent == address(artist),
            "real original class3 compromise producer"
        );
        _rhCandidate(
            2,
            "identity_authority.replay.contest_record_hash_and_subject_key",
            keccak256(abi.encode(keccak256("subject"), artistId, subject, evidence, reason))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.contest_record_hash_and_subject_key",
            keccak256(abi.encode(keccak256("record"), cause.facts.referenceHash))
        );
    }

    function _multiActive(bytes32 action, uint8 class_, bytes32 scope, bytes32 old_, bytes32 next_)
        private
    {
        address authority = manager.governanceAuthority();
        avm.mockCall(
            authority,
            abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
            abi.encode(true, action, class_, scope, old_, next_)
        );
        (bool active, bytes32 id, uint8 c, bytes32 s, bytes32 o, bytes32 n) =
            IStreamGovernanceReads(authority).currentAction();
        require(
            active && id == action && c == class_ && s == scope && o == old_ && n == next_,
            "exact governed current-action witness"
        );
    }

    function _multiInactive() private {
        _inactive();
        (bool active, bytes32 id, uint8 c, bytes32 s, bytes32 o, bytes32 n) =
            IStreamGovernanceReads(manager.governanceAuthority()).currentAction();
        require(
            !active && id == 0 && c == 0 && s == 0 && o == 0 && n == 0,
            "all-zero inactive context restored"
        );
    }

    function _multiNext() private returns (Successor memory next) {
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

    function _multiLeaf(address predecessor, HT.Leaf memory p) private view returns (bytes32) {
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

    function _multiProof(address predecessor, HT.Leaf[] memory leaves, uint256 index)
        private
        view
        returns (bytes32 root, bytes32[] memory proof)
    {
        bytes32[] memory layer = new bytes32[](leaves.length);
        proof = new bytes32[](64);
        uint256 used;
        uint256 n = leaves.length;
        for (uint256 i; i < n; ++i) {
            layer[i] = _multiLeaf(predecessor, leaves[i]);
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
