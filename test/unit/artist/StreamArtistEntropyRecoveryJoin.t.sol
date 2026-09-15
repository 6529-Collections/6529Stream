// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistOnboardingFixture.sol";
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

/// @notice Actual Artist owners/facade/Archive and entropy coordinator/workers in one Safe flow.
/// @dev Core, role resolution, governance execution context and upstream randomness remain typed
/// boundaries. No Artist consent/evidence or entropy state/result is mocked. These cases do not
/// demonstrate a real mint, delayed Executor, upstream provider or transaction gas conformance.
contract StreamArtistEntropyRecoveryJoinTest is ArtistOnboardingFixture {
    bytes32 private constant FAMILY = keccak256("6529STREAM_ENTROPY_RECOVERY_V1");
    bytes32 private constant INCIDENT_ROLE = keccak256("ROLE_ENTROPY_INCIDENT_DECLARER");
    bytes32 private constant EVIDENCE = keccak256("independent joined recovery incident evidence");
    bytes32 private constant INPUTS = keccak256("original committed scope inputs");
    StreamEntropyCoordinator private entropy;
    MockStreamEntropyProvider private originalProvider;
    MockStreamEntropyProvider private nextProvider;
    MockEntropyRoleRegistry private entropyRoles;
    ArtistUnitGovernance private entropyAuthority;

    function _deployJoined() private {
        _accept();
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

    function testActualArtistConsentAndEntropyScopeRecoveryShareOriginalEvidence() external {
        _deployJoined();
        (bytes32 scope, bytes32 old) = _failedScope();
        (bytes32 key, bytes32 state, bytes32 record) = _consent(old);
        bytes32 independent = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_SCOPE_REQUEST_V1"),
                block.chainid,
                address(entropy),
                address(core),
                uint256(1),
                scope,
                address(nextProvider),
                uint32(3),
                nextProvider.streamEntropyProviderConfigHash(),
                INPUTS,
                uint16(2)
            )
        );
        require(key == independent, "original independent scope request domain");
        vm.recordLogs();
        require(this.executeJoinedRecovery(_input(old), 0), "actual Safe recovery");
        _assertReceipt(scope, old, key, state, record);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool found;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(entropy)
                    || logs[i].topics[0]
                        != keccak256(
                            "EntropyRecoveryEvidence(uint16,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32)"
                        )
            ) continue;
            require(
                logs[i].topics[1] == key && logs[i].topics[2] == scope
                    && keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                record,
                                EVIDENCE,
                                EVIDENCE,
                                state,
                                entropy.freshRecoveryReceipt(key).journalHead
                            )
                        ),
                "exact original recovery evidence event"
            );
            found = true;
        }
        require(
            found && nextProvider.fulfill(1, keccak256("joined original output")) == 0,
            "evidence then actual fulfillment"
        );
        (, bool finalized) = entropy.scopeSeed(scope);
        require(finalized && entropy.pendingRequestCount() == 0, "one finalized outcome");
        _rejected(_input(old));
    }

    function testActualArtistConsentDoesNotAuthorizeChangedRecoveryOrHost() external {
        _deployJoined();
        (, bytes32 old) = _failedScope();
        _rejected(_input(old));
        _consent(old);
        Fresh.RecoveryInput memory changed = _input(old);
        changed.providerEvidenceHash = keccak256("different independent evidence");
        _rejected(changed);
        changed = _input(old);
        changed.reasonURI = "urn:test:different-redraw";
        _rejected(changed);
        core.set(keccak256("ENTROPY_COORDINATOR"), address(metadata), false);
        _rejected(_input(old));
        core.set(keccak256("ENTROPY_COORDINATOR"), address(entropy), false);
        require(
            this.executeJoinedRecovery(_input(old), 0),
            "identical original consent after host restoration"
        );
    }

    function testActualSafeProviderFailureRollsBackConsumptionAndFeeCredit() external {
        _deployJoined();
        (bytes32 scope, bytes32 old) = _failedScope();
        nextProvider.setFee(10);
        (bytes32 key, bytes32 state, bytes32 record) = _consent(old);
        vm.deal(address(artist), 100);
        bytes32 before_ = _joinedState();
        nextProvider.setReenterOnRequest(true);
        vm.expectRevert(bytes("GS013"));
        this.executeJoinedRecovery(_input(old), 15);
        require(
            _joinedState() == before_ && address(artist).balance == 100
                && address(entropy).balance == 0 && address(nextProvider).balance == 0
                && entropy.freshRecoveryReceipt(key).artistRecordHash == 0,
            "whole request, custody, receipt and evidence consumption rollback"
        );
        nextProvider.setReenterOnRequest(false);
        require(this.executeJoinedRecovery(_input(old), 15), "identical signed Safe retry");
        _assertReceipt(scope, old, key, state, record);
        require(
            address(artist).balance == 85 && address(nextProvider).balance == 10
                && address(entropy).balance == 5 && entropy.entropyFeeCredit(address(artist)) == 5
                && entropy.entropyFeeCredit(address(this)) == 0,
            "actual supplying Safe owns excess fee"
        );
    }

    function testActualArchiveFailureCannotCreateEntropyRecoveryEvidence() external {
        _deployJoined();
        (, bytes32 old) = _failedScope();
        (, bytes32 state,) = entropy.freshRecoveryTransition(_input(old));
        Content.Consent memory p = Content.Consent(1, address(entropy), FAMILY, state);
        T.Authorization memory a = _authorization(false);
        bytes memory callData =
            abi.encodeCall(IStreamArtistContentAuthority.recordContentConsent, (p, a));
        bytes32 expected = _recordHash(p, a);
        bytes32 before_ = _joinedState();
        avm.mockCallRevert(
            address(archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSignature("Error(string)", "joined Archive failure")
        );
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(ingress), callData);
        require(
            _joinedState() == before_
                && IStreamArtistContentRecordsOwner(suite.owners[6])
                    .contentConsentRecord(expected)
                    .recordHash == 0,
            "no partial Artist authorization"
        );
        _rejected(_input(old));
        avm.clearMockedCalls();
        require(
            this.executeTargetSafe(address(ingress), callData), "same original Artist Safe calldata"
        );
        require(
            this.executeJoinedRecovery(_input(old), 0),
            "recovery consumes newly committed actual Artist evidence"
        );
    }

    function testNextRecoveryNeedsFreshActualArtistConsentForChangedJournal() external {
        _deployJoined();
        (bytes32 scope, bytes32 old) = _failedScope();
        (bytes32 second,, bytes32 firstRecord) = _consent(old);
        require(this.executeJoinedRecovery(_input(old), 0), "first recovery");
        _incident(scope);
        _rejected(_input(second));
        (bytes32 third, bytes32 state, bytes32 secondRecord) = _consent(second);
        require(
            firstRecord != secondRecord && second != third,
            "new original Artist consent and request"
        );
        require(this.executeJoinedRecovery(_input(second), 0), "second recovery");
        _assertReceipt(scope, second, third, state, secondRecord);
        require(
            entropy.requestPolicySnapshot(third).requestAttempt == 3
                && entropy.requestPolicySnapshot(third).providerEpoch == 4
                && entropy.freshRecoveryReceipt(second).artistRecordHash == firstRecord,
            "ordered policy and immutable earlier consent"
        );
        require(
            originalProvider.fulfill(1, keccak256("stale original")) == 1
                && nextProvider.fulfill(2, keccak256("final authorized output")) == 0,
            "frozen late policy and authorized winner"
        );
    }
}
