// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityNativeProviderReads as Native
} from "../../../domains/finality/StreamFinalityNativeProviderReads.sol";
import { IStreamFinalityProfileSources as Profiles } from "./IStreamFinalityProfileSources.sol";
import { StreamFinalityScope } from "./StreamArtworkFinalityTypes.sol";
import {
    StreamPolicySnapshotDefinitionsV2 as Definitions
} from "../../../domains/records/StreamPolicySnapshotDefinitionsV2.sol";

/// @notice Separate one-way collection-policy admission for a new original provider deployment.
library StreamCurrentAuthorityDeferredPolicyBindingTypesV2 {
    bytes32 internal constant PROFILE =
        keccak256("6529STREAM_CURRENT_AUTHORITY_DEFERRED_COLLECTION_POLICY_BINDING_V2");
    bytes32 internal constant CONFIGURATION_DOMAIN =
        keccak256("6529STREAM_CURRENT_AUTHORITY_BOUND_COLLECTION_POLICY_CONFIGURATION_V2");
    bytes32 internal constant STATE_DOMAIN =
        keccak256("6529STREAM_CURRENT_AUTHORITY_COLLECTION_POLICY_BOUND_STATE_V2");
    bytes32 internal constant RECEIPT_DOMAIN =
        keccak256("6529STREAM_CURRENT_AUTHORITY_COLLECTION_POLICY_BINDING_RECEIPT_V2");
    uint8 internal constant ACTION_CLASS = 2;

    /// @dev Six static words; all fields are constructor-fixed.
    struct Capability {
        address authority;
        bytes32 authorityCodeHash;
        bytes32 originalHash;
        bytes32 scopedHash;
        bytes32 graphHash;
        bytes32 capabilityHash;
    }

    /// @dev 71 static words / 2272 bytes. Action is committed only after execution validation.
    struct Receipt {
        bytes32 capabilityHash;
        Native.Config policy;
        Profiles.Profile profile;
        address output;
        bytes32 outputCodeHash;
        address sourceSet;
        bytes32 sourceSetCodeHash;
        StreamFinalityScope scope;
        bytes32 inventoryPlan;
        bytes32 sourceFactoryDependenciesHash;
        bytes32 sourceSetDataHash;
        bytes32 bindingHash;
        bytes32 actionId;
    }

    struct Transition {
        bytes32 scopeHash;
        bytes32 oldValueHash;
        bytes32 newValueHash;
    }

    error CollectionPolicyPending();
    error CollectionPolicyAlreadyBound();
    error InvalidCollectionPolicyBinding();
    error CollectionPolicyBindingDependency(address target);
    error CollectionPolicyBindingGovernance();

    function hashCapability(uint256 chainId, address provider, Capability memory c)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                PROFILE,
                chainId,
                provider,
                c.authority,
                c.authorityCodeHash,
                c.originalHash,
                c.scopedHash,
                c.graphHash
            )
        );
    }

    function profileConfigurationHash(
        uint256 chainId,
        address provider,
        bytes32 capability,
        Native.Config memory policy,
        address output,
        bytes32 outputHash
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                CONFIGURATION_DOMAIN, chainId, provider, capability, policy, output, outputHash
            )
        );
    }

    function boundProfile(
        uint256 chainId,
        address provider,
        bytes32 capability,
        Native.Config memory policy,
        address output,
        bytes32 outputHash
    ) internal pure returns (Profiles.Profile memory) {
        return Profiles.Profile(
            Definitions.PROFILE_HASH,
            policy.targets[9],
            policy.codeHashes[9],
            policy.targets[8],
            policy.codeHashes[8],
            policy.targets[10],
            policy.codeHashes[10],
            profileConfigurationHash(chainId, provider, capability, policy, output, outputHash)
        );
    }

    /// @dev Excludes actionId and bindingHash: the scheduled call never commits its own action ID.
    function proposalHash(Receipt memory r) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                STATE_DOMAIN,
                r.capabilityHash,
                r.policy,
                r.profile,
                r.output,
                r.outputCodeHash,
                r.sourceSet,
                r.sourceSetCodeHash,
                r.scope,
                r.inventoryPlan,
                r.sourceFactoryDependenciesHash,
                r.sourceSetDataHash
            )
        );
    }

    function receiptHash(Receipt memory r) internal pure returns (bytes32) {
        return keccak256(abi.encode(RECEIPT_DOMAIN, proposalHash(r), r.actionId));
    }

    function transition(uint256 chainId, address provider, Receipt memory r)
        internal
        pure
        returns (Transition memory t)
    {
        t.scopeHash = keccak256(abi.encode(PROFILE, chainId, provider, r.capabilityHash));
        t.oldValueHash = keccak256(abi.encode(PROFILE, r.capabilityHash, false));
        t.newValueHash = proposalHash(r);
    }
}
