// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamEntropyPolicyContinuity as C
} from "../../interfaces/stream/entropy/IStreamEntropyPolicyContinuity.sol";
import {
    IStreamEntropyCollectionPolicy as P
} from "../../interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import {
    IStreamEntropyRecoveryPolicies as R
} from "../../interfaces/stream/entropy/IStreamEntropyRecoveryPolicies.sol";
import {
    IStreamRevealFeeEscrow as F
} from "../../interfaces/stream/entropy/IStreamRevealFeeEscrow.sol";

/// @notice Original policy preimages and admitted shapes, without reads or writes to any host.
/// @dev The importing worker authenticates source, live code pins and lifecycle separately.
library StreamEntropyPolicyImportValidation {
    bytes32 private constant FAMILY = keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1");
    bytes32 private constant POLICY = keccak256("6529STREAM_ENTROPY_COLLECTION_POLICY_V2");
    bytes32 private constant RECOVERY = keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_POLICY_V1");
    bytes32 private constant STEPS = keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_STEPS_V1");
    bytes32 private constant REVEAL_OWNER = keccak256("ROLE_ENTROPY_REVEAL_OWNER");
    uint256 private constant MAX_STEPS = 32;

    function validatePolicy(uint256 chainId, address core, C.PolicyExport memory p) public pure {
        if (
            core == address(0) || p.policyOrigin == address(0) || p.policyOriginCodeHash == 0
                || !p.record.configured || p.record.mode != p.policy.mode
                || p.record.securityClass != p.policy.securityClass
                || p.record.renderRequirement != p.policy.renderRequirement
        ) revert C.InvalidEntropyPolicyImport();
        _bindingShape(p);
        bytes32 hash;
        if (p.profile == C.PolicyProfile.LEGACY) {
            if (
                p.record.explicitPolicy || p.record.revision != 0 || p.record.lastActionId != 0
                    || p.record.artistConsentRecord != 0 || p.record.mode != P.Mode.ASYNC
                    || p.record.securityClass != P.SecurityClass.HIGH_ASSURANCE
                    || p.record.renderRequirement != P.RenderRequirement.REQUIRED
            ) revert C.InvalidEntropyPolicyImport();
            _providerShape(p);
            if (p.policy.timeoutBlocks == 0) revert C.InvalidEntropyPolicyImport();
            if (p.policy.reveal.declared) {
                _declaredReveal(p.policy.reveal);
                hash = legacyPolicyHash(chainId, core, p);
            } else {
                _emptyReveal(p.policy.reveal);
                // Preserve the original unavailable legacy H=0, including its content-state hash.
            }
        } else if (p.profile == C.PolicyProfile.EXPLICIT) {
            if (
                !p.record.explicitPolicy || p.record.revision == 0 || p.record.lastActionId == 0
                    || p.record.artistConsentRecord == 0
            ) revert C.InvalidEntropyPolicyImport();
            _explicitShape(p);
            hash = _explicitHash(chainId, core, p);
        } else {
            revert C.InvalidEntropyPolicyImport();
        }
        if (
            p.record.policyHash != hash
                || p.record.contentStateHash != keccak256(abi.encode(FAMILY, hash, p.record.frozen))
        ) revert C.InvalidEntropyPolicyImport();
    }

    function validateRecovery(uint256 chainId, address core, C.RecoveryExport memory r)
        public
        pure
    {
        if (
            core == address(0) || r.policyOrigin == address(0) || r.policyOriginCodeHash == 0
                || r.policyId == 0 || r.policyHash == 0 || r.revision == 0 || r.lastActionId == 0
                || !r.policy.exists || !r.policy.frozen || r.policy.maxFreshRecoveryAttempts == 0
                || r.policy.steps.length < r.policy.maxFreshRecoveryAttempts
                || r.policy.steps.length > MAX_STEPS
                || r.policy.incidentDeclarerRole != keccak256("ROLE_ENTROPY_INCIDENT_DECLARER")
                || r.policy.reasonSchemaHash == 0 || r.policy.policyManifestHash == 0
        ) revert C.InvalidEntropyPolicyImport();
        for (uint256 i; i < r.policy.steps.length; ++i) {
            R.FreshRecoveryStep memory step = r.policy.steps[i];
            if (
                step.provider == address(0) || step.providerEpoch == 0
                    || step.providerConfigHash == 0 || step.notBeforeBlocks == 0
            ) revert C.InvalidEntropyPolicyImport();
        }
        bytes32 hash = keccak256(
            abi.encode(
                RECOVERY,
                chainId,
                r.policyOrigin,
                r.policyId,
                r.policy.maxFreshRecoveryAttempts,
                r.policy.incidentDeclarerRole,
                r.policy.reasonSchemaHash,
                r.policy.policyManifestHash,
                keccak256(abi.encode(STEPS, r.policy.steps))
            )
        );
        if (r.successor == address(0)) {
            if (r.successorCodeHash != 0) revert C.InvalidEntropyPolicyImport();
        } else {
            if (r.successor == r.policyOrigin || r.successorCodeHash == 0) {
                revert C.InvalidEntropyPolicyImport();
            }
            hash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_POLICY_V2"),
                    chainId,
                    r.policyOrigin,
                    core,
                    r.policyId,
                    hash,
                    r.successor,
                    r.successorCodeHash
                )
            );
        }
        if (r.policyHash != hash) revert C.InvalidEntropyPolicyImport();
    }

    /// @notice Matches CollectionRecovery._policy after both exports have been validated.
    /// @dev Only the consumed prefix has strict increasing epochs. A zero binding uses no definition.
    function verifyBinding(C.PolicyExport memory p, C.RecoveryExport memory r) public pure {
        _bindingShape(p);
        uint16 attempts = p.recovery.maxFreshRecoveryAttempts;
        if (attempts == 0) return;
        if (
            r.policyId != p.recovery.policyId || r.policyHash != p.recovery.policyHash
                || r.policyHash == 0 || !r.policy.exists || !r.policy.frozen
                || attempts > r.policy.maxFreshRecoveryAttempts || attempts > r.policy.steps.length
        ) revert C.InvalidEntropyPolicyImport();
        uint32 epoch = p.record.providerEpoch;
        for (uint256 i; i < attempts; ++i) {
            if (r.policy.steps[i].providerEpoch <= epoch) revert C.InvalidEntropyPolicyImport();
            epoch = r.policy.steps[i].providerEpoch;
        }
    }

    function _bindingShape(C.PolicyExport memory p) private pure {
        if (
            p.policy.recoveryPolicyId != p.recovery.policyId
                || p.policy.maxFreshRecoveryAttempts != p.recovery.maxFreshRecoveryAttempts
                || (p.recovery.revision == 0) != (p.recovery.lastActionId == 0)
        ) revert C.InvalidEntropyPolicyImport();
        if (p.recovery.maxFreshRecoveryAttempts == 0) {
            // Removing a former binding retains its historical revision and action.
            if (p.recovery.policyId != 0 || p.recovery.policyHash != 0) {
                revert C.InvalidEntropyPolicyImport();
            }
        } else if (
            p.recovery.policyId == 0 || p.recovery.policyHash == 0 || p.recovery.revision == 0
                || p.recovery.maxFreshRecoveryAttempts > MAX_STEPS
        ) {
            revert C.InvalidEntropyPolicyImport();
        }
    }

    function _providerShape(C.PolicyExport memory p) private pure {
        if (
            p.policy.provider == address(0) || p.providerCodeHash == 0 || p.providerConfigHash == 0
                || p.record.providerEpoch == 0
        ) revert C.InvalidEntropyPolicyImport();
    }

    function _explicitShape(C.PolicyExport memory p) private pure {
        if (p.policy.mode == P.Mode.DISABLED) {
            if (
                p.policy.renderRequirement != P.RenderRequirement.NOT_REQUIRED
                    || p.policy.provider != address(0) || p.providerCodeHash != 0
                    || p.providerConfigHash != 0 || p.policy.collectionSalt != 0
                    || p.policy.publicRequests || p.policy.timeoutBlocks != 0
                    || p.policy.maxFreshRecoveryAttempts != 0
            ) revert C.InvalidEntropyPolicyImport();
            _emptyReveal(p.policy.reveal);
        } else if (p.policy.mode == P.Mode.INSTANT) {
            _providerShape(p);
            if (
                p.policy.securityClass != P.SecurityClass.LOW_SECURITY
                    || p.policy.timeoutBlocks != 0 || p.policy.maxFreshRecoveryAttempts != 0
            ) revert C.InvalidEntropyPolicyImport();
            _emptyReveal(p.policy.reveal);
        } else if (p.policy.mode == P.Mode.ASYNC) {
            _providerShape(p);
            if (p.policy.timeoutBlocks == 0) revert C.InvalidEntropyPolicyImport();
            _declaredReveal(p.policy.reveal);
        } else {
            revert C.InvalidEntropyPolicyImport();
        }
    }

    function _emptyReveal(F.CollectionRevealPolicy memory r) private pure {
        if (
            r.declared || r.requestMode != 0 || r.revealOwnerRole != 0 || r.requestSLOBlocks != 0
                || r.revealFeePerTokenWei != 0
        ) revert C.InvalidEntropyPolicyImport();
    }

    function _declaredReveal(F.CollectionRevealPolicy memory r) private pure {
        if (
            !r.declared || r.requestMode > 1 || r.revealOwnerRole != REVEAL_OWNER
                || r.requestSLOBlocks == 0
        ) revert C.InvalidEntropyPolicyImport();
    }

    function _explicitHash(uint256 chainId, address core, C.PolicyExport memory p)
        private
        pure
        returns (bytes32)
    {
        // Every field is static: concatenating these encodings is the original 22-word abi.encode.
        bytes memory first = abi.encode(
            POLICY,
            chainId,
            p.policyOrigin,
            core,
            p.collectionId,
            p.record.mode,
            p.record.securityClass,
            p.record.renderRequirement,
            p.policy.provider,
            p.providerCodeHash,
            p.providerConfigHash
        );
        return keccak256(
            bytes.concat(
                first,
                abi.encode(
                    p.record.providerEpoch,
                    p.policy.collectionSalt,
                    p.policy.publicRequests,
                    p.policy.timeoutBlocks,
                    p.policy.reveal.declared,
                    p.policy.reveal.requestMode,
                    p.policy.reveal.revealOwnerRole,
                    p.policy.reveal.requestSLOBlocks,
                    p.recovery.policyId,
                    p.recovery.policyHash,
                    p.recovery.maxFreshRecoveryAttempts
                )
            )
        );
    }

    /// @notice Original legacy salt commitment; undeclared reveal exposes no available commitment.
    function legacySaltHash(uint256 chainId, address core, C.PolicyExport memory p)
        internal
        pure
        returns (bytes32)
    {
        if (!p.policy.reveal.declared) return bytes32(0);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_COLLECTION_SALT_V1"),
                chainId,
                p.policyOrigin,
                core,
                p.collectionId,
                p.policy.collectionSalt
            )
        );
    }

    /// @notice Original legacy H for direct-storage exporters; no availability or identity reads.
    function legacyPolicyHash(uint256 chainId, address core, C.PolicyExport memory p)
        internal
        pure
        returns (bytes32)
    {
        if (!p.policy.reveal.declared) return bytes32(0);
        bytes32 salt = legacySaltHash(chainId, core, p);
        bytes32 provider = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_SINGLE_PROVIDER_POLICY_V1"),
                p.policy.provider,
                p.providerCodeHash,
                p.record.providerEpoch,
                p.providerConfigHash,
                salt,
                p.policy.publicRequests,
                p.policy.timeoutBlocks
            )
        );
        bytes32 reveal = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_DECLARED_REVEAL_POLICY_V1"),
                p.policy.reveal.requestMode,
                p.policy.reveal.revealOwnerRole,
                p.policy.reveal.requestSLOBlocks
            )
        );
        if (p.recovery.maxFreshRecoveryAttempts != 0) {
            return keccak256(
                abi.encode(
                    keccak256("6529STREAM_ENTROPY_FINALITY_FRESH_POLICY_V1"),
                    chainId,
                    p.policyOrigin,
                    core,
                    p.collectionId,
                    provider,
                    reveal,
                    p.recovery.policyId,
                    p.recovery.policyHash,
                    p.recovery.maxFreshRecoveryAttempts
                )
            );
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_FINALITY_POLICY_V1"),
                chainId,
                p.policyOrigin,
                core,
                p.collectionId,
                p.record.providerEpoch == 1
                    ? keccak256("6529STREAM_ENTROPY_EPOCH1_NO_FRESH_RECOVERY_V1")
                    : keccak256("6529STREAM_ENTROPY_PREMINT_EPOCHS_NO_FRESH_RECOVERY_V1"),
                provider,
                reveal
            )
        );
    }
}
