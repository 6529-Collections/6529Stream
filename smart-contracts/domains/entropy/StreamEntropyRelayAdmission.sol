// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamCore } from "../../interfaces/stream/core/IStreamCore.sol";
import { IStreamCorePointers } from "../../interfaces/stream/core/IStreamCorePointers.sol";
import {
    IStreamEntropyCoordinator
} from "../../interfaces/stream/entropy/IStreamEntropyCoordinator.sol";
import {
    IStreamEntropyOriginRelay as R
} from "../../interfaces/stream/entropy/IStreamEntropyOriginRelay.sol";
import {
    IStreamEntropyPolicyContinuity as C
} from "../../interfaces/stream/entropy/IStreamEntropyPolicyContinuity.sol";
import {
    IStreamEntropyCollectionPolicy as P
} from "../../interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import { IStreamModuleRegistry } from "../../interfaces/stream/modules/IStreamModuleRegistry.sol";
import {
    IStreamMintGovernanceRegistry
} from "../../interfaces/stream/mint/IStreamMintGovernanceRegistry.sol";
import {
    StreamEntropyRelayState as S,
    StreamEntropyRelayReads as Read
} from "./StreamEntropyRelayState.sol";
import { StreamEntropyRecoveryPolicies } from "./StreamEntropyRecoveryPolicies.sol";
import { StreamEntropyProviderLifecycle } from "./StreamEntropyProviderLifecycle.sol";

/// @notice Governed permanent origin admission; snapshots never depend on later operational fees.
library StreamEntropyRelayAdmission {
    bytes32 private constant SCOPE = keccak256("6529STREAM_ENTROPY_RELAY_ADMISSION_SCOPE_V1");
    bytes32 private constant STATE = keccak256("6529STREAM_ENTROPY_RELAY_ADMISSION_STATE_V1");
    bytes32 private constant IMPORT = keccak256("6529STREAM_ENTROPY_POLICY_IMPORT_V1");

    struct Prepared {
        C.PolicyExport policy;
        C.RecoveryExport recovery;
        bytes32 exportHash;
        bytes32 scope;
        bytes32 oldHash;
        bytes32 newHash;
    }

    event EntropyRelayAdmitted(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        address indexed successor,
        bytes32 indexed importHash,
        bytes32 successorCodeHash,
        bytes32 policyHash,
        bytes32 actionId
    );

    function admissionTransition(
        IStreamCore core,
        address authority,
        uint256 collectionId,
        address successor,
        bytes32 importHash
    ) public view returns (bytes32 scope, bytes32 oldHash, bytes32 newHash) {
        Prepared memory p = _prepare(core, authority, collectionId, successor, importHash);
        return (p.scope, p.oldHash, p.newHash);
    }

    function admit(
        IStreamCore core,
        address authority,
        uint256 collectionId,
        address successor,
        bytes32 importHash
    ) public {
        Prepared memory p = _prepare(core, authority, collectionId, successor, importHash);
        bytes32 action =
            StreamEntropyRecoveryPolicies.requireAction(authority, p.scope, p.oldHash, p.newHash);
        bytes32 replayKey = keccak256(abi.encode(p.scope, action));
        if (S.store().actions[replayKey]) revert R.EntropyRelayAdmissionReplay(action);
        S.store().actions[replayKey] = true;
        S.Admission storage a = S.store().admissions[collectionId][successor];
        a.successorCodeHash = successor.codehash;
        a.importHash = importHash;
        a.policyHash = p.policy.record.policyHash;
        a.exportHash = p.exportHash;
        a.policy = p.policy;
        a.recovery = p.recovery;
        emit EntropyRelayAdmitted(
            1, collectionId, successor, importHash, successor.codehash, a.policyHash, action
        );
    }

    function _prepare(
        IStreamCore core,
        address authority,
        uint256 id,
        address successor,
        bytes32 importHash
    ) private view returns (Prepared memory p) {
        if (successor == address(this) || successor.code.length == 0 || importHash == 0) revert R.InvalidEntropyRelay();
        if (S.store().admissions[id][successor].importHash != 0) {
            revert R.EntropyRelayAdmissionConflict(id, successor);
        }
        _candidate(core, authority, successor);
        C.ImportReceipt memory receipt = abi.decode(
            Read.read(successor, abi.encodeCall(C.entropyPolicyImport, ()), 544), (C.ImportReceipt)
        );
        if (
            (receipt.state != C.ImportState.STAGING && receipt.state != C.ImportState.SEALED)
                || receipt.importHash != importHash || receipt.nonce == 0
                || receipt.manifestHash == 0 || receipt.beginActionId == 0 || receipt.nextIndex == 0
                || receipt.nextIndex > receipt.count
        ) revert R.InvalidEntropyRelay();
        bytes32 expected = keccak256(
            abi.encode(
                IMPORT,
                block.chainid,
                successor,
                successor.codehash,
                address(core),
                receipt.nonce,
                receipt.predecessor,
                receipt.predecessorCodeHash,
                receipt.pointerRevision,
                receipt.count,
                receipt.serial,
                receipt.idDigest,
                receipt.manifestHash
            )
        );
        if (expected != importHash) revert R.InvalidEntropyRelay();
        (address source, bytes32 pin, uint8 status, uint64 revision) =
            _pointer(core, keccak256("ENTROPY_COORDINATOR"));
        if (
            source != receipt.predecessor || pin != receipt.predecessorCodeHash
                || source.codehash != pin || source.code.length == 0 || status == 0
                || revision != receipt.pointerRevision
        ) revert R.EntropyRelayDependency(source);
        (uint256 count, uint64 serial, bytes32 digest) = abi.decode(
            Read.read(source, abi.encodeCall(C.entropyPolicyInventory, ()), 96),
            (uint256, uint64, bytes32)
        );
        if (count != receipt.count || serial != receipt.serial || digest != receipt.idDigest) {
            revert R.EntropyRelayDependency(source);
        }
        p.policy = abi.decode(
            Read.read(source, abi.encodeCall(C.exportEntropyPolicy, (id)), 1184), (C.PolicyExport)
        );
        p.exportHash = keccak256(abi.encode(p.policy));
        (
            bytes32 actualImport,
            bytes32 actualExport,
            address origin,
            bytes32 originPin,
            bytes32 hash
        ) = abi.decode(
            Read.read(successor, abi.encodeCall(C.importedEntropyPolicy, (id)), 160),
            (bytes32, bytes32, address, bytes32, bytes32)
        );
        if (
            actualImport != importHash || actualExport != p.exportHash || origin != address(this)
                || originPin != address(this).codehash || hash != p.policy.record.policyHash
                || p.policy.collectionId != id || !p.policy.record.configured
                || p.policy.policyOrigin != address(this)
                || p.policy.policyOriginCodeHash != originPin
                || p.policy.policy.mode == P.Mode.DISABLED
                || (p.policy.policy.mode == P.Mode.INSTANT
                    && p.policy.policy.renderRequirement == P.RenderRequirement.NOT_REQUIRED)
        ) revert R.InvalidEntropyRelay();
        // A descendant can only extend an origin route already admitted to its immediate source.
        if (source != address(this)) {
            S.Admission storage predecessor = S.store().admissions[id][source];
            if (
                predecessor.successorCodeHash != pin || predecessor.policyHash != hash
                    || predecessor.importHash == 0
            ) revert R.InvalidEntropyRelay();
        }
        _provider(p.policy.policy.provider, p.policy.providerCodeHash, p.policy.providerConfigHash);
        if (p.policy.recovery.policyId != 0) {
            bytes memory raw = Read.bounded(
                source, abi.encodeCall(C.exportEntropyRecovery, (p.policy.recovery.policyId)), 5696
            );
            p.recovery = abi.decode(raw, (C.RecoveryExport));
            if (
                keccak256(raw) != keccak256(abi.encode(p.recovery))
                    || p.recovery.policyId != p.policy.recovery.policyId
                    || p.recovery.policyHash != p.policy.recovery.policyHash
                    || p.recovery.policyOrigin != address(this)
                    || p.recovery.policyOriginCodeHash != address(this).codehash
                    || !p.recovery.policy.exists || !p.recovery.policy.frozen
                    || p.policy.recovery.maxFreshRecoveryAttempts == 0
                    || p.recovery.policy.maxFreshRecoveryAttempts == 0
                    || p.policy.recovery.policyHash == 0 || p.recovery.policy.steps.length > 32
                    || p.recovery.policy.steps.length < p.recovery.policy.maxFreshRecoveryAttempts
                    || p.policy.recovery.maxFreshRecoveryAttempts
                        > p.recovery.policy.maxFreshRecoveryAttempts
            ) revert R.InvalidEntropyRelay();
            for (uint256 i; i < p.policy.recovery.maxFreshRecoveryAttempts; ++i) {
                address provider = p.recovery.policy.steps[i].provider;
                _provider(
                    provider,
                    StreamEntropyProviderLifecycle.record(provider).runtimeCodeHash,
                    p.recovery.policy.steps[i].providerConfigHash
                );
            }
        } else if (
            p.policy.recovery.maxFreshRecoveryAttempts != 0 || p.policy.recovery.policyHash != 0
        ) {
            revert R.InvalidEntropyRelay();
        }
        p.scope = keccak256(
            abi.encode(
                SCOPE,
                block.chainid,
                address(this),
                address(core),
                id,
                successor,
                R.admitEntropyRelay.selector
            )
        );
        p.oldHash =
            keccak256(abi.encode(STATE, p.scope, bytes32(0), bytes32(0), bytes32(0), bytes32(0)));
        p.newHash = keccak256(
            abi.encode(STATE, p.scope, successor.codehash, importHash, hash, p.exportHash)
        );
    }

    function _candidate(IStreamCore core, address authority, address successor) private view {
        if (
            abi.decode(Read.read(successor, abi.encodeWithSignature("core()"), 32), (address))
                    != address(core)
                || abi.decode(
                        Read.read(successor, abi.encodeWithSignature("authority()"), 32), (address)
                    ) != authority
        ) revert R.EntropyRelayDependency(successor);
        (address modules, bytes32 pin, uint8 status, uint64 revision) =
            _pointer(core, keccak256("MODULE_REGISTRY"));
        if (modules.code.length == 0 || modules.codehash != pin || status != 1 || revision == 0) {
            revert R.EntropyRelayDependency(modules);
        }
        if (
            abi.decode(
                        Read.read(
                            modules,
                            abi.encodeCall(IStreamMintGovernanceRegistry.governanceExecutor, ()),
                            32
                        ),
                        (address)
                    ) != authority
                || abi.decode(
                        Read.read(
                            modules,
                            abi.encodeCall(
                                IStreamModuleRegistry.isModuleEligible,
                                (
                                    successor,
                                    keccak256("ENTROPY_COORDINATOR"),
                                    type(IStreamEntropyCoordinator).interfaceId
                                )
                            ),
                            32
                        ),
                        (uint256)
                    ) != 1
        ) revert R.EntropyRelayDependency(modules);
    }

    function _pointer(IStreamCore core, bytes32 role)
        private
        view
        returns (address target, bytes32 pin, uint8 status, uint64 revision)
    {
        (target, pin,,,,, status,,, revision) = abi.decode(
            Read.read(
                address(core), abi.encodeCall(IStreamCorePointers.getSatellitePointer, (role)), 320
            ),
            (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
        );
    }

    function _provider(address provider, bytes32 pin, bytes32 config) private view {
        StreamEntropyProviderLifecycle.requireActive(provider);
        if (
            provider.codehash != pin || pin == 0 || config == 0
                || abi.decode(
                        Read.read(provider, abi.encodeWithSignature("coordinator()"), 32), (address)
                    ) != address(this)
                || abi.decode(
                        Read.read(
                            provider,
                            abi.encodeWithSignature("streamEntropyProviderConfigHash()"),
                            32
                        ),
                        (bytes32)
                    ) != config
        ) revert R.EntropyRelayDependency(provider);
    }
}
