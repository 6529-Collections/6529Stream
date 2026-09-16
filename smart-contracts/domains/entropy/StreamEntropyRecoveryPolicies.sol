// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamEntropyRecoveryPolicies as R
} from "../../interfaces/stream/entropy/IStreamEntropyRecoveryPolicies.sol";
import {
    IStreamGovernedParameterAuthority as A
} from "../../interfaces/stream/parameters/IStreamGovernedParameterAuthority.sol";
import { StreamEntropyProviderLifecycle } from "./StreamEntropyProviderLifecycle.sol";

/// @notice Fixed policy worker; data and replay protection live in the calling coordinator.
library StreamEntropyRecoveryPolicies {
    bytes32 private constant SLOT = keccak256("6529STREAM_ENTROPY_RECOVERY_POLICIES_STORAGE_V1");
    bytes32 private constant SCOPE = keccak256("6529STREAM_ENTROPY_RECOVERY_POLICY_SCOPE_V1");
    bytes32 private constant STATE = keccak256("6529STREAM_ENTROPY_RECOVERY_POLICY_STATE_V1");
    bytes32 private constant POLICY =
        0x903ca537e686c7d615b886dbd8d81e240e58123e9918bc89ccabb64f2fe9a327;
    bytes32 private constant STEPS =
        0x8a9c948a061bd07713c5f797237b5d213f2f7cd133ea20f9e7a51af3fb204b9e;
    bytes32 private constant DECLARER = keccak256("ROLE_ENTROPY_INCIDENT_DECLARER");
    uint256 internal constant MAX_STEPS = 32;

    struct Entry {
        R.FreshRecoveryPolicy policy;
        bytes32 policyHash;
        uint64 revision;
        bytes32 lastActionId;
    }

    struct Store {
        mapping(bytes32 => Entry) entries;
        mapping(bytes32 => mapping(bytes32 => bool)) consumed;
        bytes32 authorityCodeHash;
    }
    event FreshRecoveryPolicyConfigured(
        uint16 schemaVersion,
        bytes32 indexed policyId,
        bytes32 indexed policyHash,
        uint16 maxFreshRecoveryAttempts,
        bytes32 incidentDeclarerRole,
        bytes32 policyManifestHash
    );
    event FreshRecoveryPolicyFrozen(
        uint16 schemaVersion, bytes32 indexed policyId, bytes32 indexed policyHash
    );
    event FreshRecoveryPolicyDefinition(
        uint16 schemaVersion,
        bytes32 indexed policyId,
        bytes32 indexed policyHash,
        bytes32 reasonSchemaHash,
        R.FreshRecoveryStep[] steps
    );
    event FreshRecoveryPolicyAction(
        uint16 schemaVersion, bytes32 indexed policyId, bytes32 indexed actionId, uint64 revision
    );

    function store() private pure returns (Store storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function initialize(address authority) internal {
        store().authorityCodeHash = authority.codehash;
    }

    function record(bytes32 id)
        public
        view
        returns (R.FreshRecoveryPolicy memory, bytes32, uint64, bytes32)
    {
        Entry storage e = store().entries[id];
        return (e.policy, e.policyHash, e.revision, e.lastActionId);
    }

    function transition(bytes32 id, bytes32 proposedHash, bool freezing)
        public
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash)
    {
        Entry storage e = store().entries[id];
        if (e.policy.frozen) revert R.FreshRecoveryPolicyIsFrozen(id);
        if (
            id == 0 || proposedHash == 0 || e.revision == type(uint64).max
                || (freezing && (!e.policy.exists || proposedHash != e.policyHash))
        ) {
            revert R.InvalidFreshRecoveryPolicy(id);
        }
        scope = keccak256(
            abi.encode(
                SCOPE,
                block.chainid,
                address(this),
                id,
                freezing
                    ? R.freezeFreshRecoveryPolicy.selector
                    : R.configureFreshRecoveryPolicy.selector
            )
        );
        oldHash = keccak256(
            abi.encode(STATE, scope, e.policy.exists, e.policy.frozen, e.policyHash, e.revision)
        );
        newHash = keccak256(abi.encode(STATE, scope, true, freezing, proposedHash, e.revision + 1));
    }

    /// @notice Decode the original configure selector arguments in the fixed worker.
    function configureCall(address authority, bytes calldata data) public {
        (
            bytes32 id,
            uint16 attempts,
            bytes32 role,
            bytes32 reasonSchemaHash,
            bytes32 manifestHash,
            R.FreshRecoveryStep[] memory steps
        ) = abi.decode(data, (bytes32, uint16, bytes32, bytes32, bytes32, R.FreshRecoveryStep[]));
        configure(
            authority,
            id,
            R.FreshRecoveryPolicy(
                true, false, attempts, role, reasonSchemaHash, manifestHash, steps
            )
        );
    }

    function configure(address authority, bytes32 id, R.FreshRecoveryPolicy memory p) public {
        if (
            p.maxFreshRecoveryAttempts == 0 || p.steps.length < p.maxFreshRecoveryAttempts
                || p.steps.length > MAX_STEPS || p.incidentDeclarerRole != DECLARER
                || p.reasonSchemaHash == 0 || p.policyManifestHash == 0
        ) revert R.InvalidFreshRecoveryPolicy(id);
        for (uint256 i; i < p.steps.length; ++i) {
            R.FreshRecoveryStep memory step = p.steps[i];
            if (
                step.providerEpoch == 0 || step.providerConfigHash == 0 || step.notBeforeBlocks == 0
            ) {
                revert R.InvalidFreshRecoveryPolicy(id);
            }
            StreamEntropyProviderLifecycle.requireActive(step.provider);
        }
        bytes32 hash = keccak256(
            abi.encode(
                POLICY,
                block.chainid,
                address(this),
                id,
                p.maxFreshRecoveryAttempts,
                p.incidentDeclarerRole,
                p.reasonSchemaHash,
                p.policyManifestHash,
                keccak256(abi.encode(STEPS, p.steps))
            )
        );
        bytes32 actionId = _authorize(authority, id, hash, false);
        Entry storage e = store().entries[id];
        // Flags are host-owned; a caller cannot supply a pre-frozen policy.
        p.exists = true;
        p.frozen = false;
        e.policy = p;
        e.policyHash = hash;
        ++e.revision;
        e.lastActionId = actionId;
        emit FreshRecoveryPolicyConfigured(
            1, id, hash, p.maxFreshRecoveryAttempts, p.incidentDeclarerRole, p.policyManifestHash
        );
        emit FreshRecoveryPolicyDefinition(1, id, hash, p.reasonSchemaHash, p.steps);
        emit FreshRecoveryPolicyAction(1, id, actionId, e.revision);
    }

    function freeze(address authority, bytes32 id) public {
        Entry storage e = store().entries[id];
        bytes32 actionId = _authorize(authority, id, e.policyHash, true);
        e.policy.frozen = true;
        ++e.revision;
        e.lastActionId = actionId;
        emit FreshRecoveryPolicyFrozen(1, id, e.policyHash);
        emit FreshRecoveryPolicyAction(1, id, actionId, e.revision);
    }

    function _authorize(address authority, bytes32 id, bytes32 hash, bool freezing)
        private
        returns (bytes32 actionId)
    {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = transition(id, hash, freezing);
        actionId = requireAction(authority, scope, oldHash, newHash);
        Store storage s = store();
        if (s.consumed[id][actionId]) revert R.FreshRecoveryPolicyReplay(id, actionId);
        s.consumed[id][actionId] = true;
    }

    /// @notice Exact ordinary call context for this fixed coordinator's policy workers.
    function requireAction(address authority, bytes32 scope, bytes32 oldHash, bytes32 newHash)
        public
        view
        returns (bytes32 actionId)
    {
        if (
            msg.sender != authority || authority.code.length == 0
                || authority.codehash != store().authorityCodeHash
        ) {
            revert R.FreshRecoveryPolicyUnauthorized(msg.sender);
        }
        bytes memory input = abi.encodeCall(A.currentAction, ());
        bytes memory result = new bytes(192);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), authority, add(input, 32), mload(input), add(result, 32), 192)
            size := returndatasize()
        }
        if (!ok || size != 192) revert R.FreshRecoveryPolicyInvalidContext();
        (
            uint256 executing,
            bytes32 currentId,
            uint256 cls,
            bytes32 actualScope,
            bytes32 actualOld,
            bytes32 actualNew
        ) = abi.decode(result, (uint256, bytes32, uint256, bytes32, bytes32, bytes32));
        if (
            executing != 1 || currentId == 0 || cls != 1 || actualScope != scope
                || actualOld != oldHash || actualNew != newHash
        ) {
            revert R.FreshRecoveryPolicyInvalidContext();
        }
        actionId = currentId;
    }
}
