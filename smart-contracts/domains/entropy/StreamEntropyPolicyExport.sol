// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamEntropyCoordinator as H } from "./StreamEntropyCoordinator.sol";
import { IStreamCore } from "../../interfaces/stream/core/IStreamCore.sol";
import {
    IStreamEntropyPolicyContinuity as C
} from "../../interfaces/stream/entropy/IStreamEntropyPolicyContinuity.sol";
import {
    IStreamEntropyCollectionPolicy as P
} from "../../interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import {
    IStreamRevealFeeEscrow as F
} from "../../interfaces/stream/entropy/IStreamRevealFeeEscrow.sol";
import { StreamEntropyCollectionPolicyState as S } from "./StreamEntropyCollectionPolicyState.sol";
import { StreamEntropyCollectionRecovery as B } from "./StreamEntropyCollectionRecovery.sol";
import { StreamEntropyRecoveryPolicies as R } from "./StreamEntropyRecoveryPolicies.sol";
import { StreamEntropyPolicyInventory as I } from "./StreamEntropyPolicyInventory.sol";
import { StreamEntropyPolicyImportState as T } from "./StreamEntropyPolicyImportState.sol";
import {
    StreamEntropyPolicyImportValidation as V
} from "./StreamEntropyPolicyImportValidation.sol";

/// @notice Direct local STATIC-safe exports; no external or linked-library call is made.
library StreamEntropyPolicyExport {
    function policy(
        IStreamCore core,
        uint256 id,
        H.CollectionConfig storage config,
        uint32 epoch,
        F.CollectionRevealPolicy storage reveal
    ) internal view returns (C.PolicyExport memory p) {
        T.Store storage imports = T.store();
        if (
            imports.receipt.state == C.ImportState.STAGING
                || imports.receipt.state == C.ImportState.SEALED
        ) T.imported(id);
        p.collectionId = id;
        (p.policyOrigin, p.policyOriginCodeHash) = I.origin(id);
        S.Entry storage entry = S.store().entries[id];
        bool explicit_ = entry.revision != 0;
        p.profile = explicit_ ? C.PolicyProfile.EXPLICIT : C.PolicyProfile.LEGACY;
        p.policy.mode = explicit_ ? entry.mode : P.Mode.ASYNC;
        p.policy.securityClass = explicit_ ? entry.securityClass : P.SecurityClass.HIGH_ASSURANCE;
        p.policy.renderRequirement =
            explicit_ ? entry.renderRequirement : P.RenderRequirement.REQUIRED;
        p.policy.provider = config.provider;
        p.policy.collectionSalt = config.collectionSalt;
        p.policy.publicRequests = config.publicRequests;
        p.policy.timeoutBlocks = config.timeoutBlocks;
        p.policy.reveal = reveal;
        p.recovery = B.recordLocal(id);
        p.policy.maxFreshRecoveryAttempts = p.recovery.maxFreshRecoveryAttempts;
        p.policy.recoveryPolicyId = p.recovery.policyId;
        p.providerCodeHash = config.providerCodeHash;
        p.providerConfigHash = config.providerConfigHash;
        p.record.configured = explicit_ || config.provider != address(0);
        p.record.explicitPolicy = explicit_;
        p.record.frozen = config.locked;
        p.record.mode = p.policy.mode;
        p.record.securityClass = p.policy.securityClass;
        p.record.renderRequirement = p.policy.renderRequirement;
        p.record.revision = entry.revision;
        p.record.providerEpoch = epoch;
        p.record.policyHash =
            explicit_ ? entry.policyHash : V.legacyPolicyHash(block.chainid, address(core), p);
        p.record.contentStateHash = S.contentState(p.record.policyHash, config.locked);
        p.record.lastActionId = entry.lastActionId;
        p.record.artistConsentRecord = entry.artistConsentRecord;
    }

    function recovery(bytes32 id) internal view returns (C.RecoveryExport memory r) {
        r.policyId = id;
        (r.policy, r.policyHash, r.revision, r.lastActionId) = R.recordLocal(id);
        if (!r.policy.exists) revert C.InvalidEntropyRecoveryExport(id);
        (r.successor, r.successorCodeHash) = R.replacementLocal(id);
        T.ImportedRecovery storage imported_ = T.store().recoveries[id];
        if (imported_.exportHash != 0) {
            r.policyOrigin = imported_.policyOrigin;
            r.policyOriginCodeHash = imported_.policyOriginCodeHash;
        } else {
            r.policyOrigin = address(this);
            r.policyOriginCodeHash = address(this).codehash;
        }
    }
}
