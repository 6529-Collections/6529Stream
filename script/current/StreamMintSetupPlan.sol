// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/interfaces/stream/mint/IStreamMintReads.sol";
import "../../smart-contracts/interfaces/stream/mint/IStreamMintAdmin.sol";
import "../../smart-contracts/interfaces/stream/mint/IStreamMintGovernanceRegistry.sol";
import "../../smart-contracts/interfaces/stream/core/IStreamCorePointers.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistOnboarding.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistMintConsent.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistBeneficiaryFacts.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorizationRevocation.sol";

interface StreamMintSetupArtistDigest {
    function policyConsentDigest(
        StreamArtistOnboardingTypes.PolicyConsent calldata payload,
        StreamArtistOnboardingTypes.Authorization calldata authorization
    ) external view returns (bytes32);
}

interface StreamMintSetupOwnership {
    function owner() external view returns (address);
    function transferOwnership(address nextOwner) external;
}

/// @notice Stateless next-call planner for post-onboarding development/testnet phase setup.
/// @dev Produces ordinary CALLs for the actual artist or Manager owner, including a Safe.
///      Owns no authority, broadcasts nothing, and never considers a submitted call confirmed.
library StreamMintSetupPlan {
    error InvalidSetupPlan();
    error SetupDependencyChanged();
    error SetupPhaseChanged(uint256 collectionId, bytes32 phaseId);
    error SetupOwnerChanged(address actualOwner);
    error SetupAuthorizationExpired(uint64 deadline);
    error SetupAuthorizationUnavailable(uint256 requiredNonce, uint256 submittedNonce);

    enum Step {
        COMPLETE,
        RECORD_INITIAL_CONSENT,
        CONFIGURE_PHASE,
        RECORD_EXECUTOR_CONSENT,
        ADMIT_EXECUTOR,
        HANDOFF_MANAGER
    }

    struct Phase {
        uint256 collectionId;
        bytes32 phaseId;
        address artist;
        bytes32 artistId;
        bytes32 bindingHash;
        address executor;
        IStreamMintManager.MintPhaseConfig config;
        IStreamMintManager.MintGateConfig gate;
        bytes32[] counterIds;
        IStreamMintManager.MintCounterConfig[] counters;
        StreamArtistOnboardingTypes.Authorization initialConsent;
        StreamArtistOnboardingTypes.Authorization executorConsent;
    }

    struct Plan {
        uint256 chainId;
        address manager;
        bytes32 managerCodeHash;
        address core;
        address artistRegistry;
        bytes32 artistRegistryCodeHash;
        address governanceExecutor;
        address initialOwner;
        Phase[] phases;
    }

    struct NextCall {
        Step step;
        address actor;
        address target;
        uint256 value;
        bytes data;
        uint256 collectionId;
        bytes32 phaseId;
        bytes32 policyHash;
    }

    /// @notice Recompute from confirmed state after each receipt; COMPLETE has no transaction.
    /// @dev The plan is an explicit phase inventory, not a claim to enumerate all Manager phases.
    function next(Plan memory p) internal view returns (NextCall memory result) {
        _validate(p);
        address owner = StreamMintSetupOwnership(p.manager).owner();
        if (owner != p.initialOwner && owner != p.governanceExecutor) {
            revert SetupOwnerChanged(owner);
        }
        // Validate the complete inventory before returning any call, including later rows.
        for (uint256 i; i < p.phases.length; ++i) {
            Phase memory phase_ = p.phases[i];
            if (
                phase_.collectionId == 0 || phase_.phaseId == 0 || phase_.artist == address(0)
                    || phase_.artistId == 0 || phase_.bindingHash == 0
                    || phase_.executor == address(0)
                    || phase_.counterIds.length != phase_.counters.length
                    || phase_.initialConsent.signature.length != 0
                    || phase_.executorConsent.signature.length != 0
                    || phase_.initialConsent.nonce == phase_.executorConsent.nonce
            ) revert InvalidSetupPlan();
            for (uint256 j; j < i; ++j) {
                if (
                    p.phases[j].collectionId == phase_.collectionId
                        && p.phases[j].phaseId == phase_.phaseId
                ) revert InvalidSetupPlan();
                Phase memory prior = p.phases[j];
                if (
                    prior.artistId == phase_.artistId
                        && (prior.initialConsent.nonce == phase_.initialConsent.nonce
                            || prior.initialConsent.nonce == phase_.executorConsent.nonce
                            || prior.executorConsent.nonce == phase_.initialConsent.nonce
                            || prior.executorConsent.nonce == phase_.executorConsent.nonce)
                ) revert InvalidSetupPlan();
            }
            if (
                IStreamArtistAttribution(p.artistRegistry).acceptedArtist(phase_.collectionId)
                        != phase_.artist
                    || IStreamArtistAttribution(p.artistRegistry)
                        .attribution(phase_.collectionId)
                        .nominationHash != phase_.bindingHash
            ) revert SetupDependencyChanged();
            (bytes32 actualArtistId,,) = IStreamArtistBeneficiaryFacts(p.artistRegistry)
                .collectionArtistBeneficiary(phase_.collectionId);
            if (actualArtistId != phase_.artistId) revert SetupDependencyChanged();
            NextCall memory candidate = _phase(p, phase_);
            if (candidate.step != Step.COMPLETE) {
                if (owner != p.initialOwner) revert SetupOwnerChanged(owner);
                if (result.step == Step.COMPLETE) result = candidate;
            }
        }
        if (result.step != Step.COMPLETE) {
            // Future rows may reserve later nonces. Check only the next call against today's hint.
            if (
                result.step == Step.RECORD_INITIAL_CONSENT
                    || result.step == Step.RECORD_EXECUTOR_CONSENT
            ) {
                for (uint256 i; i < p.phases.length; ++i) {
                    if (
                        p.phases[i].collectionId == result.collectionId
                            && p.phases[i].phaseId == result.phaseId
                    ) {
                        _checkAuthorization(p, p.phases[i], result);
                        break;
                    }
                }
            }
            return result;
        }
        if (owner == p.governanceExecutor) return result;
        result.step = Step.HANDOFF_MANAGER;
        result.actor = p.initialOwner;
        result.target = p.manager;
        result.data =
            abi.encodeCall(StreamMintSetupOwnership.transferOwnership, (p.governanceExecutor));
    }

    function _phase(Plan memory p, Phase memory f) private view returns (NextCall memory result) {
        IStreamMintReads manager = IStreamMintReads(p.manager);
        address[] memory executors = new address[](0);
        bytes32 initialPolicy = manager.previewPhasePolicyHash(
            f.collectionId, f.phaseId, f.config, f.gate, f.counterIds, f.counters, executors
        );
        executors = new address[](1);
        executors[0] = f.executor;
        bytes32 finalPolicy = manager.previewPhasePolicyHash(
            f.collectionId, f.phaseId, f.config, f.gate, f.counterIds, f.counters, executors
        );
        if (initialPolicy == 0 || finalPolicy == 0 || initialPolicy == finalPolicy) {
            revert InvalidSetupPlan();
        }
        (bool exists, IStreamMintManager.MintPhaseConfig memory config) =
            manager.phase(f.collectionId, f.phaseId);
        result.collectionId = f.collectionId;
        result.phaseId = f.phaseId;
        if (!exists) {
            result.policyHash = initialPolicy;
            if (!_consented(p, f, initialPolicy)) {
                return _consent(p, f, result, f.initialConsent, Step.RECORD_INITIAL_CONSENT);
            }
            IStreamArtistMintConsent(p.artistRegistry)
                .requireMintConsent(f.collectionId, f.phaseId, initialPolicy);
            result.step = Step.CONFIGURE_PHASE;
            result.actor = p.initialOwner;
            result.target = p.manager;
            result.data = abi.encodeCall(
                IStreamMintAdmin.configurePhase,
                (f.collectionId, f.phaseId, f.config, f.gate, f.counterIds, f.counters)
            );
            return result;
        }
        // Pause is intentionally excluded from the policy hash; compare it and all config fields.
        bytes32 policy = manager.phasePolicyHash(f.collectionId, f.phaseId);
        if (
            keccak256(abi.encode(config)) != keccak256(abi.encode(f.config))
                || (policy != initialPolicy && policy != finalPolicy)
        ) {
            revert SetupPhaseChanged(f.collectionId, f.phaseId);
        }
        bool admitted = manager.phaseExecutor(f.collectionId, f.phaseId, f.executor);
        if ((policy == finalPolicy) != admitted) {
            revert SetupPhaseChanged(f.collectionId, f.phaseId);
        }
        if (admitted) {
            IStreamArtistMintConsent(p.artistRegistry)
                .requireMintConsent(f.collectionId, f.phaseId, finalPolicy);
            return result;
        }
        result.policyHash = finalPolicy;
        if (!_consented(p, f, finalPolicy)) {
            return _consent(p, f, result, f.executorConsent, Step.RECORD_EXECUTOR_CONSENT);
        }
        IStreamArtistMintConsent(p.artistRegistry)
            .requireMintConsent(f.collectionId, f.phaseId, finalPolicy);
        result.step = Step.ADMIT_EXECUTOR;
        result.actor = p.initialOwner;
        result.target = p.manager;
        result.data = abi.encodeCall(
            IStreamMintAdmin.setPhaseExecutor, (f.collectionId, f.phaseId, f.executor, true)
        );
    }

    function _consented(Plan memory p, Phase memory f, bytes32 policy) private view returns (bool) {
        (bool consented, bytes32 record) = IStreamArtistMintConsent(p.artistRegistry)
            .isPolicyConsented(f.collectionId, f.phaseId, policy);
        return consented && record != 0;
    }

    function _checkAuthorization(Plan memory p, Phase memory f, NextCall memory result)
        private
        view
    {
        StreamArtistOnboardingTypes.Authorization memory a =
            result.step == Step.RECORD_INITIAL_CONSENT ? f.initialConsent : f.executorConsent;
        bytes32 digest = StreamMintSetupArtistDigest(p.artistRegistry)
            .policyConsentDigest(
                StreamArtistOnboardingTypes.PolicyConsent(
                    f.collectionId, f.phaseId, result.policyHash
                ),
                a
            );
        StreamArtistAuthorizationTypes.State memory state = IStreamArtistAuthorizationRevocation(
                p.artistRegistry
            ).artistAuthorizationState(f.artistId, digest, a.nonce);
        if (
            a.nonce != state.nextUnusedNonce || state.nonceConsumed || state.nonceRevoked
                || state.digestRevoked || state.digestObserved
        ) {
            revert SetupAuthorizationUnavailable(state.nextUnusedNonce, a.nonce);
        }
    }

    function _consent(
        Plan memory p,
        Phase memory f,
        NextCall memory result,
        StreamArtistOnboardingTypes.Authorization memory authorization,
        Step step
    ) private view returns (NextCall memory) {
        if (block.timestamp > authorization.time) {
            revert SetupAuthorizationExpired(authorization.time);
        }
        result.step = step;
        result.actor = f.artist;
        result.target = p.artistRegistry;
        result.data = abi.encodeCall(
            IStreamArtistOnboarding.recordPolicyConsent,
            (
                StreamArtistOnboardingTypes.PolicyConsent(
                    f.collectionId, f.phaseId, result.policyHash
                ),
                authorization
            )
        );
        return result;
    }

    function _validate(Plan memory p) private view {
        if (
            p.chainId != block.chainid || p.phases.length == 0 || p.manager.code.length == 0
                || p.manager.codehash != p.managerCodeHash || p.core.code.length == 0
                || p.artistRegistry.code.length == 0
                || p.artistRegistry.codehash != p.artistRegistryCodeHash
                || p.initialOwner == address(0) || p.initialOwner == p.governanceExecutor
                || p.governanceExecutor.code.length == 0
        ) revert InvalidSetupPlan();
        IStreamMintReads manager = IStreamMintReads(p.manager);
        address registry = address(manager.moduleRegistry());
        _selected(p.core, keccak256("MINT_MANAGER"), p.manager);
        _selected(p.core, keccak256("ARTIST_REGISTRY"), p.artistRegistry);
        _selected(p.core, keccak256("MODULE_REGISTRY"), registry);
        if (
            address(manager.core()) != p.core
                || IStreamArtistMintConsent(p.artistRegistry).core() != p.core
                || IStreamArtistMintConsent(p.artistRegistry).mintManager() != p.manager
                || IStreamMintGovernanceRegistry(registry).governanceExecutor()
                    != p.governanceExecutor
        ) revert SetupDependencyChanged();
    }

    function _selected(address core, bytes32 kind, address expected) private view {
        (address target, bytes32 hash,,,,,,,,) = IStreamCorePointers(core).getSatellitePointer(kind);
        if (target != expected || target.code.length == 0 || hash != target.codehash) {
            revert SetupDependencyChanged();
        }
    }
}
