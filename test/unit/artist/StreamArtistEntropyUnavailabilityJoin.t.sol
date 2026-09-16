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
import {
    StreamRoleRegistry
} from "../../../smart-contracts/domains/governance/StreamRoleRegistry.sol";
import { MockStreamEntropyProvider } from "../../mocks/MockStreamEntropyProvider.sol";

/// @notice Actual op23 Identity/Archive/activity and token/scope entropy finding consumption.
/// @dev Core, governance execution context and upstream randomness remain typed
/// boundaries. No Artist consent/evidence or entropy state/result is mocked. These cases do not
/// demonstrate a real mint, delayed Executor, upstream provider or transaction gas conformance.
/// Setup is copied from the existing joined consent fixture; no shared fixture or original case changes.
contract StreamArtistEntropyUnavailabilityJoinTest is ArtistOnboardingFixture {
    bytes32 private constant FAMILY = keccak256("6529STREAM_ENTROPY_RECOVERY_V1");
    bytes32 private constant INCIDENT_ROLE = keccak256("ROLE_ENTROPY_INCIDENT_DECLARER");
    bytes32 private constant EVIDENCE = keccak256("independent joined recovery incident evidence");
    bytes32 private constant INPUTS = keccak256("original committed scope inputs");
    StreamEntropyCoordinator private entropy;
    MockStreamEntropyProvider private originalProvider;
    MockStreamEntropyProvider private nextProvider;
    StreamRoleRegistry private entropyRoles;
    ArtistUnitGovernance private entropyAuthority;

    bool private euAlreadyAccepted;

    function _deployJoined() private {
        if (!euAlreadyAccepted) _accept();
        vm.roll(100);
        entropyAuthority = ArtistUnitGovernance(
            ArtistUnitModuleRegistry(core.targets(keccak256("MODULE_REGISTRY")))
                .governanceExecutor()
        );
        entropyRoles = estateFixityRoles;
        require(
            entropyAuthority.roleRegistry() == address(entropyRoles)
                && entropyRoles.owner() == address(entropyAuthority),
            "original canonical role registry"
        );
        _setEntropyRole(keccak256("ROLE_ENTROPY_ADMIN"), address(entropyAuthority), true);
        _setEntropyRole(INCIDENT_ROLE, address(artist), true);
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
        _governTarget(address(entropy), data, cls, scope, oldHash, newHash);
    }

    function _governTarget(
        address target,
        bytes memory data,
        uint8 cls,
        bytes32 scope,
        bytes32 oldHash,
        bytes32 newHash
    ) private {
        // The shared governance fixture otherwise uses one constant action ID.
        // Supply distinct exact typed action facts so actual policy replay checks remain active.
        bytes memory selector = abi.encodeCall(IStreamGovernanceReads.currentAction, ());
        bytes32 actionId = keccak256(abi.encode(target, data, cls, scope, oldHash, newHash));
        avm.mockCall(
            address(entropyAuthority),
            selector,
            abi.encode(true, actionId, cls, scope, oldHash, newHash)
        );
        entropyAuthority.executeModuleContext(target, data, cls, scope, oldHash, newHash);
        avm.mockCall(
            address(entropyAuthority),
            selector,
            abi.encode(false, bytes32(0), uint8(0), bytes32(0), bytes32(0), bytes32(0))
        );
    }

    function _setEntropyRole(bytes32 role, address holder, bool granted) private {
        bool previous = entropyRoles.hasRole(role, holder);
        require(previous != granted, "actual role membership transition");
        (bytes32 chain, uint64 revision) = entropyRoles.roleMutationState(role);
        (bytes32 global, uint64 globalRevision) = entropyRoles.globalRoleMutationState();
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_SCOPE_V1"),
                block.chainid,
                address(entropyRoles),
                role,
                holder
            )
        );
        bytes32 oldHash = _roleState(scope, previous, chain, revision, global, globalRevision);
        chain = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_V1"),
                chain,
                block.chainid,
                address(entropyRoles),
                role,
                holder,
                granted,
                revision + 1
            )
        );
        global = keccak256(
            abi.encode(
                keccak256("6529STREAM_GLOBAL_ROLE_MUTATION_V1"),
                global,
                block.chainid,
                address(entropyRoles),
                role,
                holder,
                granted,
                globalRevision + 1
            )
        );
        _governTarget(
            address(entropyRoles),
            granted
                ? abi.encodeCall(entropyRoles.grantRole, (role, holder))
                : abi.encodeCall(entropyRoles.revokeRole, (role, holder)),
            1,
            scope,
            oldHash,
            _roleState(scope, granted, chain, revision + 1, global, globalRevision + 1)
        );
        require(entropyRoles.hasRole(role, holder) == granted, "actual canonical role membership");
    }

    function _roleState(
        bytes32 scope,
        bool granted,
        bytes32 chain,
        uint64 revision,
        bytes32 global,
        uint64 globalRevision
    ) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_STATE_V1"),
                block.chainid,
                address(entropyRoles),
                scope,
                granted,
                chain,
                revision,
                global,
                globalRevision
            )
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

    /// @dev A fresh external frame prevents via-IR from reusing the caller's block.number
    /// across cheatcode rolls or separate invocations during ordered recovery.
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

    function _consent(bytes32 old) private returns (bytes32 key, bytes32 state, bytes32 record) {
        (key, state,) = entropy.freshRecoveryTransition(_input(old));
        Content.Consent memory p = Content.Consent(1, address(entropy), FAMILY, state);
        T.Authorization memory a = _authorization(false);
        record = _recordHash(p, a);
        require(
            this.executeTargetSafe(
                address(ingress),
                abi.encodeCall(IStreamArtistContentAuthority.recordContentConsent, (p, a))
            ),
            "actual Artist consent Safe"
        );
        require(
            IStreamArtistContentHostEvidence(address(ingress))
                .contentConsentEvidenceForHost(1, address(entropy), FAMILY, state) == record,
            "actual exact Artist evidence"
        );
        IStreamArtistContentRecordsOwner.ConsentRecord memory saved =
            IStreamArtistContentRecordsOwner(suite.owners[6]).contentConsentRecord(record);
        require(
            saved.recordHash == record && saved.artistId == artistId
                && keccak256(abi.encode(saved.terms)) == keccak256(abi.encode(p)),
            "original immutable consent"
        );
        (
            T.Binding memory binding_,
            Content.Consent memory archived,
            T.Authorization memory auth,
            T.SignerApproval memory proof,
            bytes32 prior
        ) = abi.decode(
            _operationPayload(17, address(artist), record),
            (T.Binding, Content.Consent, T.Authorization, T.SignerApproval, bytes32)
        );
        require(
            binding_.artistId == artistId
                && keccak256(abi.encode(archived)) == keccak256(abi.encode(p))
                && auth.nonce == a.nonce && proof.signer == address(artist) && prior != 0
                && prior != state,
            "actual Archive binds original host and proposed change"
        );
    }

    function _recordHash(Content.Consent memory p, T.Authorization memory a)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_CONTENT_CONSENT_RECORD_V1"),
                block.chainid,
                address(ingress),
                address(entropy),
                address(core),
                uint256(1),
                FAMILY,
                p.newStateHash,
                artistId,
                address(artist),
                uint8(1),
                a.nonce,
                uint64(block.timestamp)
            )
        );
    }

    function executeJoinedRecovery(Fresh.RecoveryInput calldata input, uint256 value)
        external
        returns (bool)
    {
        require(msg.sender == address(this), "test-only Safe boundary");
        return executeSafe(
            artist,
            keys,
            address(entropy),
            value,
            abi.encodeCall(Fresh.requestFreshEntropy, (input)),
            0
        );
    }

    function _rejected(Fresh.RecoveryInput memory input) private {
        bytes32 before_ = _joinedState();
        vm.expectRevert(bytes("GS013"));
        this.executeJoinedRecovery(input, 0);
        require(_joinedState() == before_, "rejection preserves Artist, entropy, Archive and Safe");
    }

    function _joinedState() private view returns (bytes32) {
        (, bytes32 state) = entropy.artistContentFamilyState(1, FAMILY);
        return keccak256(
            abi.encode(
                _confirmationSnapshots(),
                archive.storedPayloadCount(),
                artist.nonce(),
                state,
                entropy.pendingRequestCount(),
                entropy.totalFeeCredits(),
                nextProvider.nextRequestId()
            )
        );
    }

    function _assertReceipt(bytes32 scope, bytes32 old, bytes32 key, bytes32 state, bytes32 record)
        private
        view
    {
        Fresh.RecoveryReceipt memory r = entropy.freshRecoveryReceipt(key);
        bytes32 evidence = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_RECOVERY_EVIDENCE_V1"),
                EVIDENCE,
                EVIDENCE,
                record,
                old,
                key,
                state,
                keccak256(bytes(_input(old).reasonURI))
            )
        );
        require(
            r.previousRequestKey == old && r.artistRecordHash == record
                && r.contentStateHash == state && r.evidenceHash == evidence
                && !r.acceptLateOriginalFulfillment,
            "recovery commits original Artist record and exact evidence"
        );
        require(
            entropy.scopeEntropy(scope).requestKey == key
                && entropy.scopeEntropy(scope).inputsHash == INPUTS,
            "original scope inputs and selected request"
        );
        (, bytes32 actual) = entropy.artistContentFamilyState(1, FAMILY);
        require(actual == state, "consented state is the resulting actual host state");
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

    function _rejectFinding(Fresh.RecoveryInput memory input, bytes32 hash) private {
        bytes32 before_ = _joinedState();
        vm.expectRevert(bytes("GS013"));
        this.executeFindingRecovery(input, hash, 0);
        require(_joinedState() == before_, "exact original finding/replay/Archive/Safe rollback");
    }

    function advanceFindingNotice(uint64 ends) external {
        require(msg.sender == address(this), "test-only fresh timestamp frame");
        vm.warp(ends);
    }

    function findingArtistActivity() external {
        require(msg.sender == address(this), "test-only authenticated activity frame");
        _payout();
    }

    function _assertFinding(
        bytes32 hash,
        Recovery.FindingRequest memory request,
        EU.Target memory target
    ) private view returns (Recovery.FindingRecord memory saved) {
        EU.Admission memory a;
        (saved, a) = ingress.entropyUnavailabilityFindingRecord(hash);
        require(
            hash != 0 && saved.recordHash == hash
                && hash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_UNAVAILABILITY_FINDING_RECORD_V1"),
                            block.chainid,
                            address(ingress),
                            artistId,
                            uint256(1),
                            request.evidenceHash,
                            request.reasonHash,
                            saved.governanceActionId,
                            saved.noticeEndsAt,
                            saved.recordedAt
                        )
                    ),
            "original ten-word finding preimage"
        );
        require(
            saved.noticeSeconds == 90 days && saved.noticeEndsAt == saved.recordedAt + 90 days
                && keccak256(abi.encode(saved.terms)) == keccak256(abi.encode(request))
                && keccak256(abi.encode(a.target)) == keccak256(abi.encode(target))
                && a.coordinatorCodeHash == address(entropy).codehash
                && a.governanceWitnessHash != 0,
            "complete manifest and original notice"
        );
        (
            bytes32 tag,
            StreamArtistEntropyUnavailabilityAdmission.Prepared memory prepared,
            Recovery.FindingRecord memory archived,
            EU.Admission memory admission
        ) = abi.decode(
            _operationPayload(
                23, StreamArtistIdentityAuthority(suite.owners[2]).artistWindowAuthority(), hash
            ),
            (
                bytes32,
                StreamArtistEntropyUnavailabilityAdmission.Prepared,
                Recovery.FindingRecord,
                EU.Admission
            )
        );
        require(
            tag == keccak256("6529STREAM_ARTIST_ENTROPY_UNAVAILABILITY_V1")
                && keccak256(abi.encode(saved)) == keccak256(abi.encode(archived))
                && keccak256(abi.encode(a)) == keccak256(abi.encode(admission))
                && keccak256(abi.encode(prepared.input.target)) == keccak256(abi.encode(target))
                && prepared.input.governance.actionId == saved.governanceActionId,
            "actual original op23 Archive with complete new profile"
        );
        (, U.Admission memory old) = ingress.unavailabilityFindingRecord(hash);
        require(
            old.target.recoveryRegistry == address(0), "entropy never invents Finality admission"
        );
    }

    function testEntropyFindingScopeNoticeOriginalArchiveAndExactEvent() external {
        _deployFinding();
        (bytes32 scope, bytes32 old) = _failedScope();
        (Recovery.FindingRequest memory request, EU.Target memory target) =
            _finding(old, keccak256("inability A"));
        vm.recordLogs();
        bytes32 hash = this.recordEntropyFinding(request, target);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 count;
        for (uint256 n; n < logs.length; ++n) {
            if (
                logs[n].emitter == suite.owners[2] && logs[n].topics.length == 3
                    && logs[n].topics[0]
                        == keccak256(
                            "ArtistEntropyUnavailabilityContext(uint16,uint256,address,bytes32,((address,(bytes32,string,bytes32),bytes32,bytes32),(uint256,uint256,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32),bytes32,uint256,bytes32))"
                        )
            ) {
                (uint16 schema, uint256 chain, EU.Admission memory emitted) =
                    abi.decode(logs[n].data, (uint16, uint256, EU.Admission));
                (, EU.Admission memory actual) = ingress.entropyUnavailabilityFindingRecord(hash);
                require(
                    schema == 1 && chain == block.chainid
                        && logs[n].topics[1] == bytes32(uint256(uint160(address(ingress))))
                        && logs[n].topics[2] == hash
                        && keccak256(abi.encode(emitted)) == keccak256(abi.encode(actual)),
                    "complete canonical companion"
                );
                ++count;
            }
        }
        require(count == 1, "one actual Identity companion");
        Recovery.FindingRecord memory saved = _assertFinding(hash, request, target);
        _rejectFinding(_input(old), hash);
        this.advanceFindingNotice(saved.noticeEndsAt - 1);
        _rejectFinding(_input(old), hash);
        this.advanceFindingNotice(saved.noticeEndsAt);
        _rejected(_input(old)); // A finding is not an op17 consent.
        (bytes32 key, bytes32 state,) = entropy.freshRecoveryTransition(_input(old));
        require(
            this.executeFindingRecovery(_input(old), hash, 0),
            "exact notice boundary accepts finding"
        );
        _assertReceipt(scope, old, key, state, hash);
        (bytes32 actual, bytes32 intentHash, uint64 ends) =
            entropy.entropyUnavailabilityEvidence(key);
        require(
            actual == hash && intentHash == target.intentHash && ends == saved.noticeEndsAt,
            "original receipt identifies exact finding profile"
        );
        _rejectFinding(_input(old), hash);
    }

    function testEntropyFindingManifestCannotRetargetAndCurrentPinsRefuseDrift() external {
        _deployFinding();
        (, bytes32 old) = _failedScope();
        (Recovery.FindingRequest memory request, EU.Target memory target) =
            _finding(old, keccak256("inability B"));
        EU.Target memory changed = abi.decode(abi.encode(target), (EU.Target));
        changed.unavailableEvidenceHash = keccak256("foreign inability evidence");
        avm.expectRevert(Recovery.InvalidUnavailabilityFinding.selector);
        ingress.entropyUnavailabilityFindingContext(request, changed);
        bytes32 hash = this.recordEntropyFinding(request, target);
        (Recovery.FindingRecord memory saved,) = ingress.entropyUnavailabilityFindingRecord(hash);
        this.advanceFindingNotice(saved.noticeEndsAt);
        Fresh.RecoveryInput memory other = _input(old);
        other.reasonURI = "urn:changed-recovery-reason";
        _rejectFinding(other, hash);
        other = _input(old);
        other.providerEvidenceHash = keccak256("foreign provider evidence");
        _rejectFinding(other, hash);
        core.set(keccak256("ENTROPY_COORDINATOR"), address(originalProvider), false);
        _rejectFinding(_input(old), hash);
        core.set(keccak256("ENTROPY_COORDINATOR"), address(entropy), false);
        require(
            this.executeFindingRecovery(_input(old), hash, 0),
            "same immutable manifest after host restoration"
        );
    }

    function testEntropyFindingActivityCancelsAfterNoticeAndDuringSameBlock() external {
        _deployFinding();
        (, bytes32 old) = _failedScope();
        (Recovery.FindingRequest memory request, EU.Target memory target) =
            _finding(old, keccak256("inability C"));
        bytes32 hash = this.recordEntropyFinding(request, target);
        (Recovery.FindingRecord memory saved,) = ingress.entropyUnavailabilityFindingRecord(hash);
        this.advanceFindingNotice(saved.noticeEndsAt);
        vm.recordLogs();
        this.findingArtistActivity();
        _unavailabilityActivityEvent(vm.getRecordedLogs(), address(artist), 1, 14);
        _rejectFinding(_input(old), hash);
        // A cancelled finding permits a newly evidenced finding, but cannot shorten its notice.
        (request, target) = _finding(old, keccak256("new inability after activity"));
        bytes32 next = this.recordEntropyFinding(request, target);
        (Recovery.FindingRecord memory newer, EU.Admission memory admission) =
            ingress.entropyUnavailabilityFindingRecord(next);
        require(
            next != hash && newer.recordedAt == saved.noticeEndsAt && admission.activityEpoch == 1,
            "new full notice after authenticated activity"
        );
        _rejectFinding(_input(old), next);
        // Original op17 is another actual authenticated current-Artist activity in the same block.
        this.findingConsent(old);
        T.Binding memory binding_ = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        require(
            !IStreamArtistUnavailabilityOwner(suite.owners[2])
                .unavailabilityFindingLive(next, binding_),
            "same-block activity invalidates epoch"
        );
    }

    function findingConsent(bytes32 old) external {
        require(msg.sender == address(this), "test-only fresh consent clock");
        _consent(old);
    }

    function testEntropyFindingLateArchiveFailureRollsBackNoticeLaneAndSafe() external {
        _deployFinding();
        (, bytes32 old) = _failedScope();
        (Recovery.FindingRequest memory request, EU.Target memory target) =
            _finding(old, keccak256("inability D"));
        bytes32 before_ = _joinedState();
        avm.mockCallRevert(
            address(archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSignature("Error(string)", "entropy finding Archive failure")
        );
        vm.expectRevert(bytes("GS013"));
        this.recordEntropyFinding(request, target);
        require(
            _joinedState() == before_
                && StreamArtistIdentityAuthority(suite.owners[2])
                        .latestUnavailabilityFinding(artistId, 1) == 0,
            "whole original finding and Safe transaction rolls back"
        );
        // Restore only the failed Archive call; retain every original typed Core dependency.
        avm.clearMockedCalls();
        _unavailabilityModule(
            keccak256("ARTIST_REGISTRY"),
            address(ingress),
            keccak256("ARTIST_REGISTRY"),
            type(IStreamArtistMintConsent).interfaceId
        );
        bytes32 hash = this.recordEntropyFinding(request, target);
        _assertFinding(hash, request, target);
    }

    function testRejectedAuthenticatedActivityDoesNotCancelEntropyFinding() external {
        _deployFinding();
        (, bytes32 old) = _failedScope();
        (Recovery.FindingRequest memory request, EU.Target memory target) =
            _finding(old, keccak256("failed activity inability"));
        bytes32 hash = this.recordEntropyFinding(request, target);
        (Recovery.FindingRecord memory saved,) = ingress.entropyUnavailabilityFindingRecord(hash);
        bytes32 before_ = _joinedState();
        avm.mockCallRevert(
            address(archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSignature("Error(string)", "authenticated activity Archive refusal")
        );
        vm.expectRevert(bytes("GS013"));
        this.findingArtistActivity();
        require(_joinedState() == before_, "failed authorized activity and epoch revert together");
        avm.clearMockedCalls();
        _unavailabilityModule(
            keccak256("ARTIST_REGISTRY"),
            address(ingress),
            keccak256("ARTIST_REGISTRY"),
            type(IStreamArtistMintConsent).interfaceId
        );
        T.Binding memory binding_ = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        require(
            IStreamArtistUnavailabilityOwner(suite.owners[2])
                .unavailabilityFindingLive(hash, binding_),
            "failed activity does not cancel finding"
        );
        this.advanceFindingNotice(saved.noticeEndsAt);
        require(
            this.executeFindingRecovery(_input(old), hash, 0),
            "original finding still usable after notice"
        );
    }

    function testEntropyFindingProviderFailureRetainsExactSafeRetryAndRefundOwner() external {
        _deployFinding();
        (bytes32 scope, bytes32 old) = _failedScope();
        (Recovery.FindingRequest memory request, EU.Target memory target) =
            _finding(old, keccak256("inability E"));
        bytes32 hash = this.recordEntropyFinding(request, target);
        (Recovery.FindingRecord memory saved,) = ingress.entropyUnavailabilityFindingRecord(hash);
        this.advanceFindingNotice(saved.noticeEndsAt);
        nextProvider.setFee(10);
        vm.deal(address(artist), 100);
        (bytes32 key, bytes32 state,) = entropy.freshRecoveryTransition(_input(old));
        bytes32 before_ = _joinedState();
        nextProvider.setReenterOnRequest(true);
        vm.expectRevert(bytes("GS013"));
        this.executeFindingRecovery(_input(old), hash, 15);
        (bytes32 failed,,) = entropy.entropyUnavailabilityEvidence(key);
        require(
            failed == 0 && _joinedState() == before_ && address(artist).balance == 100
                && address(entropy).balance == 0 && address(nextProvider).balance == 0,
            "finding use and all custody roll back"
        );
        nextProvider.setReenterOnRequest(false);
        require(
            this.executeFindingRecovery(_input(old), hash, 15), "identical Safe calldata and value"
        );
        _assertReceipt(scope, old, key, state, hash);
        require(
            entropy.entropyFeeCredit(address(artist)) == 5
                && entropy.entropyFeeCredit(address(this)) == 0
                && address(nextProvider).balance == 10 && address(artist).balance == 85,
            "actual supplying Safe owns refund"
        );
    }

    function testEntropyFindingOriginalRoleAndNoLiveFindingReplacement() external {
        _deployFinding();
        (, bytes32 old) = _failedScope();
        (Recovery.FindingRequest memory request, EU.Target memory target) =
            _finding(old, keccak256("inability F"));
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(this), false);
        bytes32 before_ = _joinedState();
        vm.expectRevert(bytes("GS013"));
        this.recordEntropyFinding(request, target);
        require(_joinedState() == before_, "no unauthorized original op23");
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(this), true);
        bytes32 hash = this.recordEntropyFinding(request, target);
        (request, target) = _finding(old, keccak256("cannot replace active finding"));
        vm.expectRevert(abi.encodeWithSelector(U.UnavailabilityFindingActive.selector, hash));
        ingress.entropyUnavailabilityFindingContext(request, target);
        (Recovery.FindingRecord memory saved,) = ingress.entropyUnavailabilityFindingRecord(hash);
        this.advanceFindingNotice(saved.noticeEndsAt);
        _setEntropyRole(INCIDENT_ROLE, address(artist), false);
        _setEntropyRole(INCIDENT_ROLE, address(this), true);
        _rejectFinding(_input(old), hash);
        _setEntropyRole(INCIDENT_ROLE, address(this), false);
        _setEntropyRole(INCIDENT_ROLE, address(artist), true);
        require(
            this.executeFindingRecovery(_input(old), hash, 0), "original incident role restored"
        );
    }

    function testEntropyFindingNextStepNeedsNewManifestAndFullNotice() external {
        _deployFinding();
        (bytes32 scope, bytes32 old) = _failedScope();
        (Recovery.FindingRequest memory request, EU.Target memory target) =
            _finding(old, keccak256("inability G"));
        bytes32 hash = this.recordEntropyFinding(request, target);
        (Recovery.FindingRecord memory saved,) = ingress.entropyUnavailabilityFindingRecord(hash);
        this.advanceFindingNotice(saved.noticeEndsAt);
        (bytes32 second,,) = entropy.freshRecoveryTransition(_input(old));
        require(this.executeFindingRecovery(_input(old), hash, 0), "first fallback");
        _incident(scope);
        _rejectFinding(_input(second), hash);
        (request, target) = _finding(second, keccak256("inability H"));
        bytes32 next = this.recordEntropyFinding(request, target);
        (Recovery.FindingRecord memory newer,) = ingress.entropyUnavailabilityFindingRecord(next);
        require(
            newer.recordedAt >= saved.noticeEndsAt
                && newer.noticeEndsAt == newer.recordedAt + 90 days,
            "actual terminal prior request allows distinct fresh full notice"
        );
        _rejectFinding(_input(second), next);
        this.advanceFindingNotice(newer.noticeEndsAt);
        require(this.executeFindingRecovery(_input(second), next, 0), "next ordered attempt");
        require(
            entropy.freshRecoveryReceipt(second).artistRecordHash == hash,
            "first evidence immutable"
        );
    }

    function testFinalityFindingCannotBecomeEntropyAdmissionOrBeSilentlyReplaced() external {
        (Recovery.FindingRequest memory legacy, U.Target memory oldTarget) =
            _unavailabilityFixture();
        bytes32 original = _recordUnavailability(legacy, oldTarget);
        euAlreadyAccepted = true;
        _deployFinding();
        (, bytes32 old) = _failedScope();
        (Recovery.FindingRequest memory request, EU.Target memory target) =
            _finding(old, keccak256("entropy cannot steal legacy finding"));
        (, EU.Admission memory admission) = ingress.entropyUnavailabilityFindingRecord(original);
        require(admission.target.coordinator == address(0), "Finality has no entropy manifest");
        _rejectFinding(_input(old), original);
        vm.expectRevert(abi.encodeWithSelector(U.UnavailabilityFindingActive.selector, original));
        ingress.entropyUnavailabilityFindingContext(request, target);
        this.findingArtistActivity();
        bytes32 next = this.recordEntropyFinding(request, target);
        _assertFinding(next, request, target);
    }

    function advanceTokenFindingIncident(uint256 token) external {
        require(msg.sender == address(this), "test-only fresh token incident frame");
        uint256 start = block.number;
        vm.roll(start + 11);
        require(
            this.executeTargetSafe(
                address(entropy),
                abi.encodeCall(
                    entropy.markEntropyRequestUnrecoverable,
                    (token, "urn:test:joined-incident", EVIDENCE)
                )
            ),
            "actual token incident"
        );
        vm.roll(start + 22);
    }

    function testEntropyFindingActualTokenSubjectKeepsCanonicalTokenPolicy() external {
        _deployFinding();
        core.setTokenCollection(41, 1);
        avm.mockCall(
            address(core),
            abi.encodeWithSignature("tokenLifecycle(uint256)", uint256(41)),
            abi.encode(uint8(StreamTokenLifecycle.MINTED))
        );
        avm.mockCall(
            address(core),
            abi.encodeWithSignature("coordinatorAtMint(uint256)", uint256(41)),
            abi.encode(address(entropy))
        );
        vm.prank(address(core));
        entropy.onTokenMinted(1, 41, address(artist), INPUTS);
        (bytes32 old,) = entropy.requestEntropy(41);
        this.advanceTokenFindingIncident(41);
        (Recovery.FindingRequest memory request, EU.Target memory target) =
            _finding(old, keccak256("token inability"));
        FindingHost.Intent memory i = entropy.artistEntropyRecoveryIntent(_input(old));
        require(i.tokenId == 41 && i.scopeId == 0 && i.collectionId == 1, "actual token subject");
        bytes32 hash = this.recordEntropyFinding(request, target);
        (Recovery.FindingRecord memory saved,) = ingress.entropyUnavailabilityFindingRecord(hash);
        this.advanceFindingNotice(saved.noticeEndsAt);
        require(this.executeFindingRecovery(_input(old), hash, 0), "actual token finding recovery");
        Fresh.RecoveryReceipt memory receipt = entropy.freshRecoveryReceipt(i.newRequestKey);
        require(
            receipt.artistRecordHash == hash && receipt.contentStateHash == i.contentStateHash
                && entropy.requestPolicySnapshot(i.newRequestKey).requestAttempt == 2,
            "original token attempt and evidence"
        );
    }
}
