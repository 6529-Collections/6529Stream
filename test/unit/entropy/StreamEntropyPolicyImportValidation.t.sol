// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamEntropyPolicyImportValidation as Validation
} from "../../../smart-contracts/domains/entropy/StreamEntropyPolicyImportValidation.sol";
import {
    IStreamEntropyPolicyContinuity as C
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyPolicyContinuity.sol";
import {
    IStreamEntropyCollectionPolicy as P
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import {
    IStreamEntropyRecoveryPolicies as R
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyRecoveryPolicies.sol";
import {
    IStreamRevealFeeEscrow as F
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamRevealFeeEscrow.sol";

contract EntropyPolicyImportValidationHarness {
    function validatePolicy(uint256 chainId, address core, C.PolicyExport memory p) external pure {
        Validation.validatePolicy(chainId, core, p);
    }

    function validateRecovery(uint256 chainId, address core, C.RecoveryExport memory r)
        external
        pure
    {
        Validation.validateRecovery(chainId, core, r);
    }

    function verifyBinding(C.PolicyExport memory p, C.RecoveryExport memory r) external pure {
        Validation.verifyBinding(p, r);
    }

    function legacyHashes(uint256 chainId, address core, C.PolicyExport memory p)
        external
        pure
        returns (bytes32, bytes32)
    {
        return (
            Validation.legacyPolicyHash(chainId, core, p),
            Validation.legacySaltHash(chainId, core, p)
        );
    }
}

contract StreamEntropyPolicyImportValidationTest {
    uint256 private constant CHAIN = 31337;
    address private constant CORE = address(0x2002);
    address private constant ORIGIN = address(0x1001);
    bytes32 private constant FAMILY = keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1");
    EntropyPolicyImportValidationHarness private validator;

    function setUp() public {
        validator = new EntropyPolicyImportValidationHarness();
    }

    function testExplicitDisabledAcceptsInitialEpochAndHistoricalBindingRemoval() public view {
        C.PolicyExport memory p = _explicit(P.Mode.DISABLED);
        validator.validatePolicy(CHAIN, CORE, p);
        p.record.providerEpoch = 8;
        p.policy.securityClass = P.SecurityClass.LOW_SECURITY;
        p.record.securityClass = p.policy.securityClass;
        p.recovery.revision = 9;
        p.recovery.lastActionId = keccak256("former binding removal");
        _seal(p);
        validator.validatePolicy(CHAIN, CORE, p);
    }

    function testExplicitInstantAndAsyncAcceptOriginalPreimagesWithoutLiveDependencies()
        public
        view
    {
        validator.validatePolicy(CHAIN, CORE, _explicit(P.Mode.INSTANT));
        C.PolicyExport memory p = _explicit(P.Mode.ASYNC);
        validator.validatePolicy(CHAIN, CORE, p);
        bytes32 hash = p.record.policyHash;
        p.policy.reveal.revealFeePerTokenWei = type(uint256).max;
        validator.validatePolicy(CHAIN, CORE, p);
        require(p.record.policyHash == hash, "operational fee excluded from H");
    }

    function testFirstRegistrationLockDoesNotRequireFreshActionOrArtistReceipt() public view {
        C.PolicyExport memory p = _explicit(P.Mode.ASYNC);
        p.record.frozen = true;
        p.record.contentStateHash = keccak256(abi.encode(FAMILY, p.record.policyHash, true));
        validator.validatePolicy(CHAIN, CORE, p);
        require(p.record.revision == 1, "first lock retains configuration receipt");
    }

    function testExplicitHashBindsOriginChainCoreAndEveryPreimageGroup() public view {
        C.PolicyExport memory p = _explicit(P.Mode.ASYNC);
        _reject(abi.encodeCall(validator.validatePolicy, (CHAIN + 1, CORE, p)));
        _reject(abi.encodeCall(validator.validatePolicy, (CHAIN, address(0x9999), p)));
        p.policyOrigin = address(0x1234);
        _badPolicy(p);
        p = _explicit(P.Mode.ASYNC);
        p.providerConfigHash = keccak256("other configuration");
        _badPolicy(p);
        p = _explicit(P.Mode.ASYNC);
        p.policy.collectionSalt = keccak256("other salt");
        _badPolicy(p);
        p = _explicit(P.Mode.ASYNC);
        p.policy.reveal.requestSLOBlocks += 1;
        _badPolicy(p);
        p = _explicit(P.Mode.ASYNC);
        p.record.contentStateHash = keccak256("other state");
        _badPolicy(p);
    }

    function testExplicitShapeRejectsForgedReceiptsFlagsAndDuplicateFields() public view {
        C.PolicyExport memory p = _explicit(P.Mode.ASYNC);
        p.record.revision = 0;
        _badPolicy(p);
        p = _explicit(P.Mode.ASYNC);
        p.record.lastActionId = 0;
        _badPolicy(p);
        p = _explicit(P.Mode.ASYNC);
        p.record.artistConsentRecord = 0;
        _badPolicy(p);
        p = _explicit(P.Mode.ASYNC);
        p.record.configured = false;
        _badPolicy(p);
        p = _explicit(P.Mode.ASYNC);
        p.record.explicitPolicy = false;
        _badPolicy(p);
        p = _explicit(P.Mode.ASYNC);
        p.record.mode = P.Mode.INSTANT;
        _seal(p);
        _badPolicy(p);
    }

    function testDisabledAndInstantRejectAsyncAndRecoveryShapeEvenWithCorrectHash() public view {
        C.PolicyExport memory p = _explicit(P.Mode.DISABLED);
        p.providerCodeHash = keccak256("forged disabled provider");
        _seal(p);
        _badPolicy(p);
        p = _explicit(P.Mode.INSTANT);
        p.policy.timeoutBlocks = 1;
        _seal(p);
        _badPolicy(p);
        p = _explicit(P.Mode.INSTANT);
        p.policy.reveal.revealFeePerTokenWei = 1;
        _seal(p);
        _badPolicy(p);
        p = _explicit(P.Mode.INSTANT);
        p.policy.securityClass = P.SecurityClass.HIGH_ASSURANCE;
        p.record.securityClass = p.policy.securityClass;
        _seal(p);
        _badPolicy(p);
        p = _explicit(P.Mode.INSTANT);
        _bind(p, _recovery(false), 1);
        _seal(p);
        _badPolicy(p);
    }

    function testLegacyUndeclaredRetainsUnavailableHashAndZeroSaltCommitment() public view {
        C.PolicyExport memory p = _legacy(false);
        validator.validatePolicy(CHAIN, CORE, p);
        (bytes32 hash, bytes32 salt) = validator.legacyHashes(CHAIN, CORE, p);
        require(hash == 0 && salt == 0 && p.record.policyHash == 0, "original unavailable reads");
        require(p.record.contentStateHash == keccak256(abi.encode(FAMILY, bytes32(0), false)));
        p.record.policyHash = keccak256("invented available policy");
        p.record.contentStateHash = keccak256(abi.encode(FAMILY, p.record.policyHash, false));
        _badPolicy(p);
        p = _legacy(false);
        p.policy.reveal.requestSLOBlocks = 1;
        _badPolicy(p);
    }

    function testLegacyDeclaredEpochOneAndLaterEpochUseDifferentOriginalCommitments() public view {
        C.PolicyExport memory p = _legacy(true);
        validator.validatePolicy(CHAIN, CORE, p);
        bytes32 first = p.record.policyHash;
        (bytes32 actual, bytes32 salt) = validator.legacyHashes(CHAIN, CORE, p);
        require(actual == first && salt == _saltOracle(p), "original salt and H");
        p.record.providerEpoch = 4;
        _seal(p);
        require(p.record.policyHash != first, "later-epoch commitment");
        validator.validatePolicy(CHAIN, CORE, p);
        p.policy.reveal.revealFeePerTokenWei = 99;
        validator.validatePolicy(CHAIN, CORE, p);
    }

    function testLegacyRejectsInventedExplicitEvidenceAndNoncanonicalDefaults() public view {
        C.PolicyExport memory p = _legacy(true);
        p.record.artistConsentRecord = keccak256("invented consent");
        _badPolicy(p);
        p = _legacy(true);
        p.record.revision = 1;
        _badPolicy(p);
        p = _legacy(true);
        p.record.lastActionId = keccak256("invented action");
        _badPolicy(p);
        p = _legacy(true);
        p.record.securityClass = P.SecurityClass.LOW_SECURITY;
        p.policy.securityClass = p.record.securityClass;
        _badPolicy(p);
        p = _legacy(true);
        p.record.providerEpoch = 0;
        _seal(p);
        _badPolicy(p);
    }

    function testBindingPreservesDifferentUltimateOriginsAndHistoricalRevision() public view {
        C.RecoveryExport memory r = _recovery(false);
        C.PolicyExport memory p = _explicit(P.Mode.ASYNC);
        p.record.providerEpoch = 4;
        _bind(p, r, 2);
        p.recovery.revision = 17;
        _seal(p);
        validator.validateRecovery(CHAIN, CORE, r);
        validator.validatePolicy(CHAIN, CORE, p);
        validator.verifyBinding(p, r);
        require(p.policyOrigin != r.policyOrigin && p.record.revision == 1);
        p = _legacy(true);
        p.record.providerEpoch = 4;
        _bind(p, r, 2);
        _seal(p);
        validator.validatePolicy(CHAIN, CORE, p);
        validator.verifyBinding(p, r);
    }

    function testBindingChecksOnlyConsumedStrictEpochPrefix() public view {
        C.RecoveryExport memory r = _recovery(false);
        require(r.policy.steps[2].providerEpoch < r.policy.steps[1].providerEpoch);
        validator.validateRecovery(CHAIN, CORE, r);
        C.PolicyExport memory p = _explicit(P.Mode.ASYNC);
        p.record.providerEpoch = 4;
        _bind(p, r, 2);
        _seal(p);
        validator.verifyBinding(p, r);
        p.record.providerEpoch = 5;
        _reject(abi.encodeCall(validator.verifyBinding, (p, r)));
        p.record.providerEpoch = 4;
        r.policy.steps[1].providerEpoch = 5;
        _reject(abi.encodeCall(validator.verifyBinding, (p, r)));
    }

    function testBindingRejectsDefinitionMismatchAndMalformedZeroBinding() public view {
        C.PolicyExport memory p = _explicit(P.Mode.ASYNC);
        C.RecoveryExport memory r = _recovery(false);
        _bind(p, r, 2);
        _seal(p);
        r.policyId = keccak256("wrong definition");
        _reject(abi.encodeCall(validator.verifyBinding, (p, r)));
        p.policy.maxFreshRecoveryAttempts = 1;
        _badPolicy(p);
        p = _explicit(P.Mode.ASYNC);
        p.recovery.policyHash = keccak256("orphan binding hash");
        _seal(p);
        _badPolicy(p);
        p = _explicit(P.Mode.ASYNC);
        p.recovery.revision = 1;
        _badPolicy(p);
    }

    function testRecoveryV1AndV2KeepSavedTargetAndOriginalHashDomains() public view {
        C.RecoveryExport memory r = _recovery(false);
        validator.validateRecovery(CHAIN, CORE, r);
        r = _recovery(true);
        validator.validateRecovery(CHAIN, CORE, r);
        _reject(abi.encodeCall(validator.validateRecovery, (CHAIN + 1, CORE, r)));
        _reject(abi.encodeCall(validator.validateRecovery, (CHAIN, address(0x9999), r)));
        r.successor = address(validator);
        _badRecovery(r);
        // The importing candidate may itself be the ORIGINAL saved target; never retarget it.
        r.policyHash = _recoveryOracle(r);
        validator.validateRecovery(CHAIN, CORE, r);
        r.successor = r.policyOrigin;
        r.policyHash = _recoveryOracle(r);
        _badRecovery(r);
    }

    function testRecoveryRejectsMissingFrozenDefinitionAndNoncanonicalReplacement() public view {
        C.RecoveryExport memory r = _recovery(false);
        r.policy.exists = false;
        _badRecovery(r);
        r = _recovery(false);
        r.policy.frozen = false;
        _badRecovery(r);
        r = _recovery(false);
        r.revision = 0;
        _badRecovery(r);
        r = _recovery(false);
        r.lastActionId = 0;
        _badRecovery(r);
        r = _recovery(false);
        r.successorCodeHash = keccak256("orphan target pin");
        _badRecovery(r);
        r = _recovery(true);
        r.successorCodeHash = 0;
        r.policyHash = _recoveryOracle(r);
        _badRecovery(r);
    }

    function testRecoveryRejectsMalformedFullDefinitionIncludingUnusedSuffix() public view {
        C.RecoveryExport memory r = _recovery(false);
        r.policy.steps[2].provider = address(0);
        r.policyHash = _recoveryOracle(r);
        _badRecovery(r);
        r = _recovery(false);
        r.policy.steps[2].notBeforeBlocks = 0;
        r.policyHash = _recoveryOracle(r);
        _badRecovery(r);
        r = _recovery(false);
        r.policy.maxFreshRecoveryAttempts = 4;
        r.policyHash = _recoveryOracle(r);
        _badRecovery(r);
        r = _recovery(false);
        r.policy.steps = new R.FreshRecoveryStep[](33);
        for (uint256 i; i < r.policy.steps.length; ++i) {
            r.policy.steps[i] =
                R.FreshRecoveryStep(address(0x3003), 5, keccak256("config"), 1, false);
        }
        r.policyHash = _recoveryOracle(r);
        _badRecovery(r);
    }

    function testFuzzPolicyFeeAndFirstLockDoNotRewriteIdentity(uint256 fee, bool frozen)
        public
        view
    {
        C.PolicyExport memory p = _explicit(P.Mode.ASYNC);
        p.policy.reveal.revealFeePerTokenWei = fee;
        p.record.frozen = frozen;
        p.record.contentStateHash = keccak256(abi.encode(FAMILY, p.record.policyHash, frozen));
        validator.validatePolicy(CHAIN, CORE, p);
        p = _legacy(true);
        p.policy.reveal.revealFeePerTokenWei = fee;
        p.record.frozen = frozen;
        p.record.contentStateHash = keccak256(abi.encode(FAMILY, p.record.policyHash, frozen));
        validator.validatePolicy(CHAIN, CORE, p);
    }

    function _explicit(P.Mode mode) private pure returns (C.PolicyExport memory p) {
        p.collectionId = 7;
        p.profile = C.PolicyProfile.EXPLICIT;
        p.policyOrigin = ORIGIN;
        p.policyOriginCodeHash = keccak256("original Coordinator code");
        p.record.configured = true;
        p.record.explicitPolicy = true;
        p.record.revision = 1;
        p.record.lastActionId = keccak256("original configuration action");
        p.record.artistConsentRecord = keccak256("original configuration consent");
        p.policy.mode = mode;
        p.policy.securityClass =
            mode == P.Mode.INSTANT ? P.SecurityClass.LOW_SECURITY : P.SecurityClass.HIGH_ASSURANCE;
        p.policy.renderRequirement = mode == P.Mode.DISABLED
            ? P.RenderRequirement.NOT_REQUIRED
            : P.RenderRequirement.REQUIRED;
        p.record.mode = p.policy.mode;
        p.record.securityClass = p.policy.securityClass;
        p.record.renderRequirement = p.policy.renderRequirement;
        if (mode != P.Mode.DISABLED) {
            p.policy.provider = address(0x3003);
            p.providerCodeHash = keccak256("provider code");
            p.providerConfigHash = keccak256("provider configuration");
            p.record.providerEpoch = 1;
            p.policy.collectionSalt = keccak256("salt");
            p.policy.publicRequests = true;
        }
        if (mode == P.Mode.ASYNC) {
            p.policy.timeoutBlocks = 17;
            p.policy.reveal =
                F.CollectionRevealPolicy(true, 1, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 9, 13);
        }
        _seal(p);
    }

    function _legacy(bool declared) private pure returns (C.PolicyExport memory p) {
        p = _explicit(P.Mode.ASYNC);
        p.profile = C.PolicyProfile.LEGACY;
        p.record.explicitPolicy = false;
        p.record.revision = 0;
        p.record.lastActionId = 0;
        p.record.artistConsentRecord = 0;
        if (!declared) p.policy.reveal = F.CollectionRevealPolicy(false, 0, 0, 0, 0);
        _seal(p);
    }

    function _recovery(bool replacement) private pure returns (C.RecoveryExport memory r) {
        r.policyId = keccak256("saved recovery policy");
        r.policyOrigin = address(0x4004);
        r.policyOriginCodeHash = keccak256("recovery origin code");
        r.revision = 2;
        r.lastActionId = keccak256("freeze recovery action");
        r.policy.exists = true;
        r.policy.frozen = true;
        r.policy.maxFreshRecoveryAttempts = 2;
        r.policy.incidentDeclarerRole = keccak256("ROLE_ENTROPY_INCIDENT_DECLARER");
        r.policy.reasonSchemaHash = keccak256("reason schema");
        r.policy.policyManifestHash = keccak256("manifest");
        r.policy.steps = new R.FreshRecoveryStep[](3);
        r.policy.steps[0] = R.FreshRecoveryStep(address(0x5005), 5, keccak256("step 0"), 10, true);
        r.policy.steps[1] = R.FreshRecoveryStep(address(0x6006), 6, keccak256("step 1"), 1, false);
        r.policy.steps[2] = R.FreshRecoveryStep(address(0x7007), 1, keccak256("step 2"), 2, true);
        if (replacement) {
            r.successor = address(0x8008);
            r.successorCodeHash = keccak256("saved successor code");
        }
        r.policyHash = _recoveryOracle(r);
    }

    function _bind(C.PolicyExport memory p, C.RecoveryExport memory r, uint16 attempts)
        private
        pure
    {
        p.policy.recoveryPolicyId = r.policyId;
        p.policy.maxFreshRecoveryAttempts = attempts;
        p.recovery.policyId = r.policyId;
        p.recovery.policyHash = r.policyHash;
        p.recovery.maxFreshRecoveryAttempts = attempts;
        p.recovery.revision = 1;
        p.recovery.lastActionId = keccak256("original binding action");
    }

    function _seal(C.PolicyExport memory p) private pure {
        p.record.policyHash =
            p.profile == C.PolicyProfile.EXPLICIT ? _explicitOracle(p) : _legacyOracle(p);
        p.record.contentStateHash =
            keccak256(abi.encode(FAMILY, p.record.policyHash, p.record.frozen));
    }

    /// @dev Independent fixed ABI-word oracle, preserving the original 22-field order.
    function _explicitOracle(C.PolicyExport memory p) private pure returns (bytes32) {
        bytes32[22] memory words;
        words[0] = keccak256("6529STREAM_ENTROPY_COLLECTION_POLICY_V2");
        words[1] = bytes32(CHAIN);
        words[2] = bytes32(uint256(uint160(p.policyOrigin)));
        words[3] = bytes32(uint256(uint160(CORE)));
        words[4] = bytes32(p.collectionId);
        words[5] = bytes32(uint256(p.record.mode));
        words[6] = bytes32(uint256(p.record.securityClass));
        words[7] = bytes32(uint256(p.record.renderRequirement));
        words[8] = bytes32(uint256(uint160(p.policy.provider)));
        words[9] = p.providerCodeHash;
        words[10] = p.providerConfigHash;
        words[11] = bytes32(uint256(p.record.providerEpoch));
        words[12] = p.policy.collectionSalt;
        words[13] = bytes32(uint256(p.policy.publicRequests ? 1 : 0));
        words[14] = bytes32(uint256(p.policy.timeoutBlocks));
        words[15] = bytes32(uint256(p.policy.reveal.declared ? 1 : 0));
        words[16] = bytes32(uint256(p.policy.reveal.requestMode));
        words[17] = p.policy.reveal.revealOwnerRole;
        words[18] = bytes32(uint256(p.policy.reveal.requestSLOBlocks));
        words[19] = p.recovery.policyId;
        words[20] = p.recovery.policyHash;
        words[21] = bytes32(uint256(p.recovery.maxFreshRecoveryAttempts));
        return keccak256(abi.encode(words));
    }

    function _saltOracle(C.PolicyExport memory p) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_COLLECTION_SALT_V1"),
                CHAIN,
                p.policyOrigin,
                CORE,
                p.collectionId,
                p.policy.collectionSalt
            )
        );
    }

    function _legacyOracle(C.PolicyExport memory p) private pure returns (bytes32) {
        if (!p.policy.reveal.declared) return bytes32(0);
        bytes32 provider = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_SINGLE_PROVIDER_POLICY_V1"),
                p.policy.provider,
                p.providerCodeHash,
                p.record.providerEpoch,
                p.providerConfigHash,
                _saltOracle(p),
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
                    CHAIN,
                    p.policyOrigin,
                    CORE,
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
                CHAIN,
                p.policyOrigin,
                CORE,
                p.collectionId,
                p.record.providerEpoch == 1
                    ? keccak256("6529STREAM_ENTROPY_EPOCH1_NO_FRESH_RECOVERY_V1")
                    : keccak256("6529STREAM_ENTROPY_PREMINT_EPOCHS_NO_FRESH_RECOVERY_V1"),
                provider,
                reveal
            )
        );
    }

    function _recoveryOracle(C.RecoveryExport memory r) private pure returns (bytes32 hash) {
        hash = keccak256(
            abi.encode(
                bytes32(0x903ca537e686c7d615b886dbd8d81e240e58123e9918bc89ccabb64f2fe9a327),
                CHAIN,
                r.policyOrigin,
                r.policyId,
                r.policy.maxFreshRecoveryAttempts,
                r.policy.incidentDeclarerRole,
                r.policy.reasonSchemaHash,
                r.policy.policyManifestHash,
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_STEPS_V1"), r.policy.steps
                    )
                )
            )
        );
        if (r.successor != address(0)) {
            hash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_POLICY_V2"),
                    CHAIN,
                    r.policyOrigin,
                    CORE,
                    r.policyId,
                    hash,
                    r.successor,
                    r.successorCodeHash
                )
            );
        }
    }

    function _badPolicy(C.PolicyExport memory p) private view {
        _reject(abi.encodeCall(validator.validatePolicy, (CHAIN, CORE, p)));
    }

    function _badRecovery(C.RecoveryExport memory r) private view {
        _reject(abi.encodeCall(validator.validateRecovery, (CHAIN, CORE, r)));
    }

    function _reject(bytes memory data) private view {
        (bool ok, bytes memory result) = address(validator).staticcall(data);
        require(
            !ok
                && keccak256(result)
                    == keccak256(abi.encodeWithSelector(C.InvalidEntropyPolicyImport.selector)),
            "canonical import rejection"
        );
    }
}
