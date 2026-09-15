// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistOnboardingFixture.sol";
import {
    StreamArtistEntropyUnavailabilityTypes as EU,
    IStreamArtistEntropyUnavailability
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEntropyUnavailability.sol";
import {
    IStreamEntropyArtistUnavailability as FindingHost
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyArtistUnavailability.sol";
import {
    StreamArtistEntropyUnavailabilityAdmission
} from "../../../smart-contracts/domains/artist/StreamArtistEntropyUnavailabilityAdmission.sol";

import {
    StreamEntropyCoordinator
} from "../../../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol";
import {
    IStreamEntropyFreshRecovery as Fresh
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyFreshRecovery.sol";
import {
    IStreamEntropyRecoveryPolicies as RecoveryPolicy
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyRecoveryPolicies.sol";
import {
    IStreamEntropyProviderLifecycle,
    EntropyProviderState
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyProviderLifecycle.sol";
import {
    IStreamArtistContentHostEvidence
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentHostEvidence.sol";
import { EntropyTimeTestConfigs } from "../../helpers/EntropyTimeTestMocks.sol";
import { MockEntropyRoleRegistry } from "../../mocks/MockEntropyRoleRegistry.sol";
import { MockStreamEntropyProvider } from "../../mocks/MockStreamEntropyProvider.sol";

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

import {
    StreamArtistEntropyFindingHydrationTypes as FH,
    IStreamArtistEntropyFindingHydration as FindingHydrate,
    IStreamArtistEntropyFindingHydrationOwner as FindingOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEntropyFindingHydration.sol";
import "../../../smart-contracts/domains/artist/StreamArtistEntropyFindingHydration.sol";

/// @notice Actual two Artist registries, seven owners, Archive, entropy and threshold Safe.
/// @dev Original finite recipes are copied, not shared fixture changes. Core/governance/roles
/// and upstream randomness remain explicit typed boundaries; no current-Core/Executor claim.
contract StreamArtistEntropyFindingHydrationTest is ArtistOnboardingFixture {
    bytes32 private constant FAMILY = keccak256("6529STREAM_ENTROPY_RECOVERY_V1");
    bytes32 private constant INCIDENT_ROLE = keccak256("ROLE_ENTROPY_INCIDENT_DECLARER");
    bytes32 private constant EVIDENCE = keccak256("independent joined recovery incident evidence");
    bytes32 private constant INPUTS = keccak256("original committed scope inputs");
    StreamEntropyCoordinator private entropy;
    MockStreamEntropyProvider private originalProvider;
    MockStreamEntropyProvider private nextProvider;
    MockEntropyRoleRegistry private entropyRoles;
    ArtistUnitGovernance private entropyAuthority;

    bool private euAlreadyAccepted;

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

    AH.PolicyKey[] private findingPolicies;

    function _deployJoined() private {
        if (!euAlreadyAccepted) _accept();
        vm.roll(100);
        entropyAuthority = ArtistUnitGovernance(
            ArtistUnitModuleRegistry(core.targets(keccak256("MODULE_REGISTRY")))
                .governanceExecutor()
        );
        entropyRoles = new MockEntropyRoleRegistry(address(entropyAuthority));
        entropyRoles.setHolder(INCIDENT_ROLE, address(artist));
        // The shared typed Core exposes one collection before its entropy policy is frozen.
        avm.mockCall(
            address(core),
            abi.encodeCall(IStreamCoreCollectionView.collectionFreezeStatus, (uint256(1))),
            abi.encode(false)
        );
        entropy = StreamEntropyCoordinator(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/entropy/StreamEntropyCoordinator.sol:StreamEntropyCoordinator",
                    abi.encode(
                        StreamEntropyCoordinator.DeploymentConfig(
                            address(core),
                            address(entropyAuthority),
                            address(entropyRoles),
                            EntropyTimeTestConfigs.parameters(),
                            EVIDENCE,
                            "urn:test:artist-entropy-join",
                            EVIDENCE
                        )
                    )
                ))
        );
        core.set(keccak256("ENTROPY_COORDINATOR"), address(entropy), false);
        originalProvider = new MockStreamEntropyProvider(address(entropy));
        nextProvider = new MockStreamEntropyProvider(address(entropy));
        _admit(originalProvider);
        _admit(nextProvider);
        _govern(
            abi.encodeCall(
                entropy.configureCollection, (1, address(originalProvider), EVIDENCE, true, 10)
            ),
            1,
            0,
            0,
            0
        );
        _govern(
            abi.encodeCall(
                entropy.configureCollectionRevealPolicy,
                (1, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 10, 0)
            ),
            1,
            0,
            0,
            0
        );
        RecoveryPolicy.FreshRecoveryStep[] memory steps = new RecoveryPolicy.FreshRecoveryStep[](2);
        steps[0] = RecoveryPolicy.FreshRecoveryStep(
            address(nextProvider), 3, nextProvider.streamEntropyProviderConfigHash(), 10, false
        );
        steps[1] = RecoveryPolicy.FreshRecoveryStep(
            address(nextProvider), 4, nextProvider.streamEntropyProviderConfigHash(), 10, false
        );
        bytes32 policyId = keccak256("joined ordered recovery policy");
        bytes32 policyHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_POLICY_V1"),
                block.chainid,
                address(entropy),
                policyId,
                uint16(2),
                INCIDENT_ROLE,
                EVIDENCE,
                EVIDENCE,
                keccak256(
                    abi.encode(keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_STEPS_V1"), steps)
                )
            )
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            entropy.freshRecoveryPolicyTransition(policyId, policyHash, false);
        _govern(
            abi.encodeCall(
                entropy.configureFreshRecoveryPolicy,
                (policyId, 2, INCIDENT_ROLE, EVIDENCE, EVIDENCE, steps)
            ),
            1,
            scope,
            oldHash,
            newHash
        );
        (scope, oldHash, newHash) =
            entropy.freshRecoveryPolicyTransition(policyId, policyHash, true);
        _govern(
            abi.encodeCall(entropy.freezeFreshRecoveryPolicy, (policyId)),
            1,
            scope,
            oldHash,
            newHash
        );
        (scope, oldHash, newHash) = entropy.collectionFreshRecoveryTransition(1, 2, policyId);
        _govern(
            abi.encodeCall(entropy.configureCollectionFreshRecovery, (1, 2, policyId)),
            1,
            scope,
            oldHash,
            newHash
        );
        _govern(abi.encodeCall(entropy.setRequester, (address(this), true)), 1, 0, 0, 0);
    }

    function _govern(bytes memory data, uint8 cls, bytes32 scope, bytes32 oldHash, bytes32 newHash)
        private
    {
        // The shared governance fixture otherwise uses one constant action ID.
        // Supply distinct exact typed action facts so actual policy replay checks remain active.
        bytes memory selector = abi.encodeCall(IStreamGovernanceReads.currentAction, ());
        bytes32 actionId =
            keccak256(abi.encode(address(entropy), data, cls, scope, oldHash, newHash));
        avm.mockCall(
            address(entropyAuthority),
            selector,
            abi.encode(true, actionId, cls, scope, oldHash, newHash)
        );
        entropyAuthority.executeModuleContext(address(entropy), data, cls, scope, oldHash, newHash);
        avm.mockCall(
            address(entropyAuthority),
            selector,
            abi.encode(false, bytes32(0), uint8(0), bytes32(0), bytes32(0), bytes32(0))
        );
    }

    function _admit(MockStreamEntropyProvider provider) private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash, uint8 cls) = entropy.entropyProviderTransition(
            address(provider), EntropyProviderState.ACTIVE, "urn:test:joined-provider"
        );
        _govern(
            abi.encodeCall(
                IStreamEntropyProviderLifecycle.activateEntropyProvider,
                (address(provider), "urn:test:joined-provider")
            ),
            cls,
            scope,
            oldHash,
            newHash
        );
    }

    function _failedScope() private returns (bytes32 scope, bytes32 old) {
        scope = entropy.registerEntropyScope(1, 1, keccak256("actual joined scope"));
        (old,) = entropy.requestScopeEntropy(scope, INPUTS);
        _incident(scope);
    }

    function _incident(bytes32 scope) private {
        this.advanceJoinedIncident(scope);
    }

    function advanceJoinedIncident(bytes32 scope) external {
        require(msg.sender == address(this), "test-only incident clock");
        uint256 start = block.number;
        vm.roll(start + 11);
        require(
            this.executeTargetSafe(
                address(entropy),
                abi.encodeCall(
                    entropy.markEntropyScopeRequestUnrecoverable,
                    (scope, "urn:test:joined-incident", EVIDENCE)
                )
            ),
            "actual incident Safe"
        );
        vm.roll(start + 22);
    }

    function _input(bytes32 old) private pure returns (Fresh.RecoveryInput memory) {
        return Fresh.RecoveryInput(old, "urn:test:joined-redraw", EVIDENCE);
    }

    function _deployFinding() private {
        _deployJoined();
        _unavailabilityModule(
            keccak256("ARTIST_REGISTRY"),
            address(ingress),
            keccak256("ARTIST_REGISTRY"),
            type(IStreamArtistMintConsent).interfaceId
        );
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(this), true);
    }

    function _finding(bytes32 old, bytes32 evidence)
        private
        view
        returns (Recovery.FindingRequest memory request, EU.Target memory target)
    {
        FindingHost.Intent memory i = entropy.artistEntropyRecoveryIntent(_input(old));
        bytes32 intentHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_ARTIST_RECOVERY_INTENT_V1"),
                block.chainid,
                address(entropy),
                address(core),
                i
            )
        );
        target = EU.Target(address(entropy), _input(old), intentHash, evidence);
        bytes32 manifest = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ENTROPY_UNAVAILABILITY_V1"),
                block.chainid,
                address(ingress),
                address(core),
                target,
                i,
                address(entropy).codehash
            )
        );
        request = Recovery.FindingRequest(
            artistId, 1, manifest, keccak256("actual inability finding reason")
        );
    }

    function recordEntropyFinding(
        Recovery.FindingRequest calldata request,
        EU.Target calldata target
    ) external returns (bytes32 hash) {
        require(msg.sender == address(this), "test-only original finding transaction");
        ArtistUnitGovernance authority = ArtistUnitGovernance(
            StreamArtistIdentityAuthority(suite.owners[2]).artistWindowAuthority()
        );
        authority.configureContestReads(
            suite.roleRegistry, address(this), request.reasonHash, "urn:finding:entropy"
        );
        U.Context memory x = ingress.entropyUnavailabilityFindingContext(request, target);
        bytes32 actionId =
            keccak256(abi.encode("actual entropy finding action", request, target, x));
        avm.mockCall(
            address(authority),
            abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
            abi.encode(true, actionId, uint8(2), x.scopeHash, x.oldValueHash, x.newValueHash)
        );
        require(
            this.executeTargetSafe(
                address(authority),
                abi.encodeCall(
                    authority.executeModuleContext,
                    (
                        address(ingress),
                        abi.encodeCall(
                            IStreamArtistEntropyUnavailability.recordEntropyUnavailabilityFinding,
                            (request, target)
                        ),
                        uint8(2),
                        x.scopeHash,
                        x.oldValueHash,
                        x.newValueHash
                    )
                )
            ),
            "actual Safe finding"
        );
        avm.mockCall(
            address(authority),
            abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
            abi.encode(false, bytes32(0), uint8(0), bytes32(0), bytes32(0), bytes32(0))
        );
        hash =
            StreamArtistIdentityAuthority(suite.owners[2]).latestUnavailabilityFinding(artistId, 1);
    }

    function executeFindingRecovery(
        Fresh.RecoveryInput calldata input,
        bytes32 finding,
        uint256 value
    ) external returns (bool) {
        require(msg.sender == address(this), "test-only Safe finding recovery");
        return executeSafe(
            artist,
            keys,
            address(entropy),
            value,
            abi.encodeCall(FindingHost.requestFreshEntropyWithUnavailability, (input, finding)),
            0
        );
    }

    function advanceFindingNotice(uint64 ends) external {
        require(msg.sender == address(this), "test-only fresh timestamp frame");
        vm.warp(ends);
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
        p.policies = findingPolicies;
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

    function _initialBindingProposal() internal view override returns (T.BindingProposal memory p) {
        p = super._initialBindingProposal();
        p.identityRecordURI = "urn:entropy-finding-source";
    }

    function _start() private returns (bytes32 scope, bytes32 old) {
        _candidate(
            0, "binding_lifecycle.replay.proposal_key", keccak256(abi.encode(uint256(1), uint64(1)))
        );
        _candidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(abi.encode(bytes32(0), uint256(0)))
        );
        T.Authorization memory auth =
            T.Authorization(nextNonce, uint64(block.timestamp + 1 days), "");
        _authOrigins(ingress.acceptanceDigest(1, auth), auth.nonce);
        _candidate(
            3,
            "acceptance_lifecycle.replay.record_uniqueness",
            keccak256(abi.encode(uint256(1), uint64(1), uint8(1), address(artist)))
        );
        _candidate(2, "identity_authority.replay.one_way_cutover_latch", 0);
        _deployFinding();
        return _failedScope();
    }

    function _record(bytes32 old, bytes32 evidence) private returns (bytes32 hash) {
        (Recovery.FindingRequest memory terms, EU.Target memory target) = _finding(old, evidence);
        hash = this.recordEntropyFinding(terms, target);
        (Recovery.FindingRecord memory row,) = ingress.entropyUnavailabilityFindingRecord(hash);
        _candidate(
            2,
            "identity_authority.replay.governance_action_id",
            keccak256(abi.encode(row.governanceActionId))
        );
        _candidate(
            2,
            "identity_authority.replay.finding_key",
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_UNAVAILABILITY_FINDING_KEY_V1"),
                    keccak256("6529STREAM_ARTIST_ENTROPY_UNAVAILABILITY_V1"),
                    artistId,
                    row.bindingGeneration,
                    row.bindingHash,
                    target
                )
            )
        );
    }

    function _migrate() private returns (Next memory n, FH.Request memory p) {
        // Finding recipes use a typed current-action observation. Remove that completed
        // frame before the original real op55-57 owner/import recipe.
        avm.clearMockedCalls();
        n = _cutover(true, true);
        p.authority = _request();
        p.economics = new T.EconomicsConsent[](0);
        p.attestations = new StreamArtistReadinessHydrationTypes.AttestationInput[](0);
        _unavailabilityModule(
            POINTER, address(n.registry), POINTER, type(IStreamArtistMintConsent).interfaceId
        );
    }

    function _hydrate(Next memory n, FH.Request memory p) private returns (bytes32 value) {
        value = FindingHydrate(address(n.registry)).hydrateArtistAuthorityWithEntropyFindings(p);
        require(value != 0, "explicit finding profile commits");
        uint256 findingGuards;
        for (uint256 j; j < p.authority.replayOrigins[2].length; ++j) {
            AH.Origin memory o = p.authority.replayOrigins[2][j];
            if (
                o.surface != keccak256("identity_authority.replay.finding_key")
                    && o.surface != keccak256("identity_authority.replay.governance_action_id")
            ) continue;
            T.ReplayCell memory old =
                IStreamArtistOwner(suite.owners[2]).replayCell(_sourceKey(2, o));
            bytes32 key = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                    block.chainid,
                    address(n.registry),
                    address(n.coordinator),
                    address(n.archive),
                    n.identity,
                    IStreamArtistOwner(n.identity).domainId(),
                    o.surface,
                    o.scope
                )
            );
            T.ReplayCell memory current = IStreamArtistOwner(n.identity).replayCell(key);
            require(
                old.commitment != 0 && current.commitment == old.commitment && current.kind == 1
                    && current.status == 2,
                "actual successor rekey keeps both original consumed finding guards"
            );
            ++findingGuards;
        }
        require(
            findingGuards >= 2 && findingGuards % 2 == 0, "complete action and target replay pairs"
        );
        T.SuiteConfiguration memory next = n.coordinator.suiteConfiguration();
        for (uint256 j; j < 7; ++j) {
            require(
                HydrationOwner(next.owners[j]).authorityHydrationCommitment() == value,
                "same complete seven-owner commitment"
            );
        }
    }

    function _query(FH.Request memory p) private view returns (AH.Query memory q) {
        q.artistId = artistId;
        q.collectionId = 1;
        q.bindingHash = IStreamArtistBindingOwner(suite.owners[0]).binding(1).bindingHash;
        q.policies = p.authority.policies;
        uint256 total;
        for (uint256 j; j < 7; ++j) {
            total += Native(suite.owners[j]).artistNativeReceiptCount();
        }
        q.records = new bytes32[](total);
        uint256 used;
        for (uint256 j; j < 7; ++j) {
            for (uint256 k; k < Native(suite.owners[j]).artistNativeReceiptCount(); ++k) {
                q.records[used++] = Native(suite.owners[j]).artistNativeReceiptAt(k).recordHash;
            }
        }
    }

    function _row(Next memory n, bytes32 hash)
        private
        view
        returns (Recovery.FindingRecord memory r, EU.Admission memory a)
    {
        (Recovery.FindingRecord memory before_, EU.Admission memory admission) =
            ingress.entropyUnavailabilityFindingRecord(hash);
        (r, a) = n.registry.entropyUnavailabilityFindingRecord(hash);
        require(
            keccak256(abi.encode(r, a)) == keccak256(abi.encode(before_, admission)),
            "full original record and admission retained"
        );
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_UNAVAILABILITY_FINDING_RECORD_V1"),
                block.chainid,
                address(ingress),
                r.terms.artistId,
                r.terms.collectionId,
                r.terms.evidenceHash,
                r.terms.reasonHash,
                r.governanceActionId,
                r.noticeEndsAt,
                r.recordedAt
            )
        );
        require(
            expected == hash
                && FindingOwner(n.identity).entropyUnavailabilityFindingOrigin(hash)
                    == address(ingress),
            "original ten-word domain"
        );
        (, U.Admission memory finality) =
            IStreamArtistUnavailabilityOwner(n.identity).unavailabilityFindingRecord(hash);
        require(
            finality.target.recoveryRegistry == address(0),
            "entropy never imports a finality admission"
        );
    }

    function _policy(StreamArtistOnboardingRegistry registry_, bool source) private {
        T.PolicyConsent memory policy = T.PolicyConsent(1, PHASE, POLICY);
        T.Identity memory id = IStreamArtistIdentityOwner(
                StreamArtistOnboardingCoordinator(registry_.operationCoordinator())
                .suiteConfiguration()
                .owners[2]
            ).identity(artistId);
        T.Authorization memory auth =
            T.Authorization(id.nonceHint, uint64(block.timestamp + 1 days), "");
        bytes32 digest = registry_.policyConsentDigest(policy, auth);
        auth.signature = _signature(digest);
        if (source) {
            _authOrigins(digest, auth.nonce);
            _candidate(
                6,
                "consent_finality.replay.policy_consent_key",
                keccak256(abi.encode(uint256(1), PHASE, POLICY))
            );
            findingPolicies.push(AH.PolicyKey(PHASE, POLICY));
        }
        require(
            this.executeTargetSafe(
                address(registry_),
                abi.encodeCall(IStreamArtistOnboarding.recordPolicyConsent, (policy, auth))
            ),
            "actual current-domain Safe activity"
        );
    }

    function testFindingHydrationPreservesOriginalDomainAndActualEntropyConsumption() external {
        (, bytes32 old) = _start();
        bytes32 hash = _record(old, keccak256("first imported finding"));
        (Next memory n, FH.Request memory p) = _migrate();
        _hydrate(n, p);
        (Recovery.FindingRecord memory r, EU.Admission memory a) = _row(n, hash);
        this.advanceFindingNotice(r.noticeEndsAt);
        (bool valid, bytes32 actual,,) = n.registry
            .verifyEntropyRecoveryUnavailability(
                address(entropy), _input(old), a.target.intentHash, hash
            );
        require(valid && actual == hash, "active successor validates original-domain finding");
        (bytes32 key,,) = entropy.freshRecoveryTransition(_input(old));
        require(
            this.executeFindingRecovery(_input(old), hash, 0),
            "same actual host consumes carried finding"
        );
        require(
            entropy.freshRecoveryReceipt(key).artistRecordHash == hash,
            "fresh receipt binds original finding"
        );
        _row(n, hash);
        vm.expectRevert(bytes("GS013"));
        this.executeFindingRecovery(_input(old), hash, 0);
    }

    function testFindingHydrationCurrentSuccessorSafeActivityCancelsOriginalFinding() external {
        (, bytes32 old) = _start();
        bytes32 hash = _record(old, keccak256("cancel after import"));
        (Next memory n, FH.Request memory p) = _migrate();
        _hydrate(n, p);
        (Recovery.FindingRecord memory r, EU.Admission memory a) = _row(n, hash);
        _policy(n.registry, false);
        this.advanceFindingNotice(r.noticeEndsAt);
        (bool valid,,,) = n.registry
            .verifyEntropyRecoveryUnavailability(
                address(entropy), _input(old), a.target.intentHash, hash
            );
        require(!valid, "new actual authority activity cancels original epoch");
        vm.expectRevert(bytes("GS013"));
        this.executeFindingRecovery(_input(old), hash, 0);
        _row(n, hash);
    }

    function testFindingHydrationCarriesCancelledThenNewLatestHistoryAndPolicyDependency()
        external
    {
        (, bytes32 old) = _start();
        bytes32 first = _record(old, keccak256("prior cancelled finding"));
        _policy(ingress, true);
        bytes32 latest = _record(old, keccak256("new independent inability evidence"));
        (Next memory n, FH.Request memory p) = _migrate();
        _hydrate(n, p);
        _row(n, first);
        (Recovery.FindingRecord memory r, EU.Admission memory a) = _row(n, latest);
        require(
            a.activityEpoch == 1
                && IStreamArtistUnavailabilityOwner(n.identity)
                        .latestUnavailabilityFinding(artistId, 1) == latest,
            "canonical new head and epoch"
        );
        this.advanceFindingNotice(r.noticeEndsAt);
        (bool stale,,,) = n.registry
            .verifyEntropyRecoveryUnavailability(
                address(entropy), _input(old), a.target.intentHash, first
            );
        require(!stale, "old head never serves");
        require(
            this.executeFindingRecovery(_input(old), latest, 0),
            "complete latest finding remains usable"
        );
    }

    function testFindingHydrationDoesNotResurrectCancelledLatest() external {
        (, bytes32 old) = _start();
        bytes32 hash = _record(old, keccak256("cancelled source head"));
        _policy(ingress, true);
        (Next memory n, FH.Request memory p) = _migrate();
        _hydrate(n, p);
        (Recovery.FindingRecord memory r, EU.Admission memory a) = _row(n, hash);
        this.advanceFindingNotice(r.noticeEndsAt);
        (bool valid,,,) = n.registry
            .verifyEntropyRecoveryUnavailability(
                address(entropy), _input(old), a.target.intentHash, hash
            );
        require(!valid, "exact source cancellation survives import");
        vm.expectRevert(bytes("GS013"));
        this.executeFindingRecovery(_input(old), hash, 0);
    }

    function testFindingHydrationRejectsMissingRowsForeignTargetAndWrongOriginalDomain() external {
        (, bytes32 old) = _start();
        bytes32 hash = _record(old, keccak256("complete row controls"));
        (Next memory n, FH.Request memory p) = _migrate();
        AH.Query memory q = _query(p);
        bytes memory raw = FindingOwner(suite.owners[2]).authorityEntropyFindingHydrationState(q);
        FH.Bundle memory b = StreamArtistEntropyFindingHydration.decode(raw);
        bytes memory call_ = abi.encodeCall(FindingOwner.authorityEntropyFindingHydrationState, (q));
        b.records = new FH.Row[](0);
        avm.mockCall(suite.owners[2], call_, abi.encode(abi.encode(FH.PROFILE, b)));
        avm.expectRevert(T.InvalidRecord.selector);
        FindingHydrate(address(n.registry)).hydrateArtistAuthorityWithEntropyFindings(p);
        _notHydrated(n);
        b = StreamArtistEntropyFindingHydration.decode(raw);
        b.records[0].admission.target.unavailableEvidenceHash = keccak256("retargeted");
        avm.mockCall(suite.owners[2], call_, abi.encode(abi.encode(FH.PROFILE, b)));
        avm.expectRevert(T.InvalidRecord.selector);
        FindingHydrate(address(n.registry)).hydrateArtistAuthorityWithEntropyFindings(p);
        _notHydrated(n);
        b = StreamArtistEntropyFindingHydration.decode(raw);
        b.sourceRegistry = address(n.registry);
        avm.mockCall(suite.owners[2], call_, abi.encode(abi.encode(FH.PROFILE, b)));
        avm.expectRevert(T.InvalidRecord.selector);
        FindingHydrate(address(n.registry)).hydrateArtistAuthorityWithEntropyFindings(p);
        _notHydrated(n);
        avm.clearMockedCalls();
        _hydrate(n, p);
        _row(n, hash);
    }

    function testFindingHydrationRejectsMissingReplayAndChangedSourceThenExactSafeRetry() external {
        (, bytes32 old) = _start();
        _record(old, keccak256("guard completeness"));
        (Next memory n, FH.Request memory p) = _migrate();
        bytes32 originalScope =
            p.authority.replayOrigins[2][p.authority.replayOrigins[2].length - 1].scope;
        p.authority.replayOrigins[2][p.authority.replayOrigins[2].length - 1].scope =
            keccak256("foreign scope");
        avm.expectRevert(T.InvalidRecord.selector);
        FindingHydrate(address(n.registry)).hydrateArtistAuthorityWithEntropyFindings(p);
        _notHydrated(n);
        p.authority.replayOrigins[2][p.authority.replayOrigins[2].length - 1].scope = originalScope;
        CP.Checkpoint memory header =
            abi.decode(abi.encode(p.authority.expectedSource[2]), (CP.Checkpoint));
        header.ownerState.stateRoot = keccak256("changed source");
        avm.mockCall(
            suite.owners[2], abi.encodeCall(CP.authorityCheckpoint, ()), abi.encode(header)
        );
        avm.expectRevert(T.InvalidRecord.selector);
        FindingHydrate(address(n.registry)).hydrateArtistAuthorityWithEntropyFindings(p);
        _notHydrated(n);
        avm.clearMockedCalls();
        require(
            this.executeTargetSafe(
                address(n.registry),
                abi.encodeCall(FindingHydrate.hydrateArtistAuthorityWithEntropyFindings, (p))
            ),
            "same complete request succeeds after source restoration"
        );
    }

    function testFindingHydrationLateArchiveFailureRollsBackSupplementAndAllSevenOwners() external {
        (, bytes32 old) = _start();
        bytes32 hash = _record(old, keccak256("late atomicity"));
        (Next memory n, FH.Request memory p) = _migrate();
        bytes memory data =
            abi.encodeCall(FindingHydrate.hydrateArtistAuthorityWithEntropyFindings, (p));
        bytes32 roots = _allRoots(n.coordinator);
        uint256 nonce = artist.nonce();
        avm.mockCallRevert(
            address(n.archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSignature("Error(string)", "late finding hydration")
        );
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(n.registry), data);
        _notHydrated(n);
        require(
            _allRoots(n.coordinator) == roots && artist.nonce() == nonce,
            "whole roots and Safe nonce restored"
        );
        (Recovery.FindingRecord memory empty, EU.Admission memory admission) =
            n.registry.entropyUnavailabilityFindingRecord(hash);
        require(
            empty.recordHash == 0 && admission.target.coordinator == address(0)
                && FindingOwner(n.identity).entropyUnavailabilityFindingOrigin(hash) == address(0),
            "no supplemental authority survives rollback"
        );
        avm.clearMockedCalls();
        require(this.executeTargetSafe(address(n.registry), data), "identical Safe calldata retry");
        _row(n, hash);
    }

    function testOldHydrationSelectorStillRejectsFindingProfile() external {
        (, bytes32 old) = _start();
        _record(old, keccak256("explicit profile"));
        (Next memory n, FH.Request memory p) = _migrate();
        avm.expectRevert(T.UnsupportedProfile.selector);
        Hydrate(address(n.registry)).hydrateArtistAuthority(p.authority);
        _notHydrated(n);
        _hydrate(n, p);
    }

    function testImportedFindingCannotRepeatOrRetargetActualEntropyRequest() external {
        (bytes32 scope, bytes32 old) = _start();
        bytes32 hash = _record(old, keccak256("already consumed source evidence"));
        (Recovery.FindingRecord memory before_,) = ingress.entropyUnavailabilityFindingRecord(hash);
        this.advanceFindingNotice(before_.noticeEndsAt);
        (bytes32 key,,) = entropy.freshRecoveryTransition(_input(old));
        require(
            this.executeFindingRecovery(_input(old), hash, 0), "original actual entropy consumption"
        );
        bytes32 receipt = keccak256(abi.encode(entropy.freshRecoveryReceipt(key)));
        (Next memory n, FH.Request memory p) = _migrate();
        _hydrate(n, p);
        _row(n, hash);
        uint256 nonce = artist.nonce();
        uint256 requests = nextProvider.nextRequestId();
        vm.expectRevert(bytes("GS013"));
        this.executeFindingRecovery(_input(old), hash, 0);
        require(
            artist.nonce() == nonce && nextProvider.nextRequestId() == requests
                && keccak256(abi.encode(entropy.freshRecoveryReceipt(key))) == receipt,
            "original request cannot repeat and immutable receipt remains"
        );
        // The stale old-request refusal above is separate from this eligible next-request
        // control. This does not directly inspect the host's private consumed-evidence cell.
        _incident(scope);
        (bytes32 nextKey,,) = entropy.freshRecoveryTransition(_input(key));
        require(nextKey != 0 && nextKey != key, "actual next failed request has a fresh candidate");
        nonce = artist.nonce();
        vm.expectRevert(bytes("GS013"));
        this.executeFindingRecovery(_input(key), hash, 0);
        require(
            artist.nonce() == nonce && nextProvider.nextRequestId() == requests
                && keccak256(abi.encode(entropy.freshRecoveryReceipt(key))) == receipt,
            "old complete finding cannot authorize a different eligible request"
        );
    }
}
