// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamEntropyPolicyImport as W
} from "../../../smart-contracts/domains/entropy/StreamEntropyPolicyImport.sol";
import {
    StreamEntropyPolicyImportState as T
} from "../../../smart-contracts/domains/entropy/StreamEntropyPolicyImportState.sol";
import {
    StreamEntropyPolicyExport as X
} from "../../../smart-contracts/domains/entropy/StreamEntropyPolicyExport.sol";
import {
    StreamEntropyPolicyInventory as I
} from "../../../smart-contracts/domains/entropy/StreamEntropyPolicyInventory.sol";
import {
    StreamEntropyCollectionPolicyState as S
} from "../../../smart-contracts/domains/entropy/StreamEntropyCollectionPolicyState.sol";
import {
    StreamEntropyRecoveryPolicies as R
} from "../../../smart-contracts/domains/entropy/StreamEntropyRecoveryPolicies.sol";
import {
    StreamEntropyCollectionRecovery as B
} from "../../../smart-contracts/domains/entropy/StreamEntropyCollectionRecovery.sol";
import {
    StreamEntropyIncidentParameters as Gas
} from "../../../smart-contracts/domains/entropy/StreamEntropyIncidentParameters.sol";
import {
    StreamEntropyProviderLifecycle as L
} from "../../../smart-contracts/domains/entropy/StreamEntropyProviderLifecycle.sol";
import {
    StreamEntropyCoordinator as H
} from "../../../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol";
import {
    StreamEntropyCollectionConfiguration as Config
} from "../../../smart-contracts/domains/entropy/StreamEntropyCollectionConfiguration.sol";
import {
    StreamEntropyPolicyReauthor as Reauthor
} from "../../../smart-contracts/domains/entropy/StreamEntropyPolicyReauthor.sol";
import { IStreamCore } from "../../../smart-contracts/interfaces/stream/core/IStreamCore.sol";
import {
    IStreamEntropyPolicyContinuity as C
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyPolicyContinuity.sol";
import {
    IStreamEntropyCollectionPolicy as P
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import {
    IStreamRevealFeeEscrow as F
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamRevealFeeEscrow.sol";
import {
    IStreamEntropyCoordinator
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCoordinator.sol";
import {
    EntropyProviderState
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyProviderLifecycle.sol";

/// @notice Typed registry and Core pointer seams; neither is the actual governed current-stack host.
contract EntropyImportRegistryFixture {
    address public immutable governanceExecutor;
    mapping(address => bool) public admitted;

    constructor(address authority) {
        governanceExecutor = authority;
    }

    function admit(address target, bool value) external {
        admitted[target] = value;
    }

    function isModuleEligible(address target, bytes32 kind, bytes4 capability)
        external
        view
        returns (bool)
    {
        return admitted[target] && target.code.length != 0
            && kind == 0xb3b3ef20764c647bdeda70b21ab009ff2783106d6995be14389ec6f42ea6dfbb
            && capability == type(IStreamEntropyCoordinator).interfaceId;
    }
}

contract EntropyImportCoreFixture {
    address public selected;
    uint64 public revision = 7;
    address public immutable registry;

    constructor(address registry_) {
        registry = registry_;
    }

    function select(address target, uint64 rev) external {
        selected = target;
        revision = rev;
    }

    function collectionExists(uint256) external pure returns (bool) {
        return true;
    }

    function collectionFreezeStatus(uint256) external pure returns (bool) {
        return false;
    }

    function getSatellitePointer(bytes32 kind)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        address target = kind == keccak256("MODULE_REGISTRY") ? registry : selected;
        return (
            target,
            target.codehash,
            false,
            kind,
            type(IStreamEntropyCoordinator).interfaceId,
            registry,
            1,
            0,
            0,
            kind == keccak256("MODULE_REGISTRY") ? 1 : revision
        );
    }
}

/// @notice Actual import/export/state workers with explicitly seeded original storage.
/// @dev Source setup and route admission are typed seams, not Artist authorization or relay proofs.
contract EntropyPolicyImportHostFixture {
    IStreamCore public immutable core;
    address public immutable authority;
    mapping(uint256 => H.CollectionConfig) public configs;
    mapping(uint256 => uint32) public epochs;
    mapping(uint256 => F.CollectionRevealPolicy) private reveals;
    mapping(uint256 => uint256) private escrows;

    struct Admission {
        bytes32 runtime;
        bytes32 importHash;
        bytes32 policyHash;
    }
    mapping(uint256 => mapping(address => Admission)) private admissions;

    constructor(IStreamCore core_, address authority_) {
        core = core_;
        authority = authority_;
        Gas.initialize(authority_);
        R.initialize(authority_);
        L.initialize(authority_);
    }

    fallback() external {
        W.write(core, authority, configs, epochs, reveals, escrows, msg.data);
    }

    function seedPolicy(C.PolicyExport calldata p) external {
        T.requireOperationalAndMarkUsed();
        uint256 id = p.collectionId;
        configs[id] = H.CollectionConfig(
            p.policy.provider,
            p.policy.publicRequests,
            p.record.frozen,
            p.policy.timeoutBlocks,
            p.providerConfigHash,
            p.providerCodeHash,
            p.policy.collectionSalt
        );
        epochs[id] = p.record.providerEpoch;
        reveals[id] = p.policy.reveal;
        B.installImported(id, p.recovery);
        if (p.profile == C.PolicyProfile.EXPLICIT) {
            S.store().entries[id] = S.Entry(
                p.record.revision,
                p.record.mode,
                p.record.securityClass,
                p.record.renderRequirement,
                p.record.policyHash,
                p.record.lastActionId,
                p.record.artistConsentRecord
            );
        }
        I.recordLocal(id);
    }

    function seedRecovery(C.RecoveryExport calldata r) external {
        T.requireOperationalAndMarkUsed();
        R.installImported(
            r.policyId,
            r.policy,
            r.policyHash,
            r.revision,
            r.lastActionId,
            r.successor,
            r.successorCodeHash
        );
    }

    function markUsed() external {
        T.requireOperationalAndMarkUsed();
    }

    function gasParameterInfo(bytes32 id) external view returns (uint256, uint256, uint8, uint64) {
        return Gas.info(id);
    }

    function gasParameterTransition(bytes32 id, uint256 next)
        external
        view
        returns (bytes32, bytes32, bytes32)
    {
        return Gas.transition(id, next);
    }

    function raiseGasParameter(bytes32 id, uint256 next) external {
        Gas.raise(authority, id, next);
    }

    function operational() external view {
        T.requireOperational();
    }

    function changeFee(uint256 id, uint256 fee) external {
        T.requireOperationalAndMarkUsed();
        reveals[id].revealFeePerTokenWei = fee;
        I.touch(id);
    }

    function configureCollection(
        uint256 id,
        address provider,
        bytes32 salt,
        bool publicRequests,
        uint64 timeout
    ) external {
        T.requireOperationalAndMarkUsed();
        Config.configure(
            core, configs, epochs, reveals, id, provider, salt, publicRequests, timeout
        );
    }

    function configureCollectionRevealPolicy(uint256, uint8, bytes32, uint64, uint256) external {
        T.requireOperationalAndMarkUsed();
        Config.configureReveal(core, configs, reveals, msg.data[4:]);
    }

    function updateRevealFee(uint256 id, uint256 fee) external {
        T.requireOperationalAndMarkUsed();
        Config.updateFee(configs, reveals, id, fee);
    }

    function reauthorProviders(uint256 id, address provider, bytes32 recoveryId, uint16 attempts)
        external
        view
    {
        Reauthor.requireLocalProviders(id, provider, recoveryId, attempts);
    }

    function admitRoute(uint256 id, address target, bytes32 hash, bytes32 policyHash) external {
        admissions[id][target] = Admission(target.codehash, hash, policyHash);
    }

    function entropyRelayAdmission(uint256 id, address target)
        external
        view
        returns (bytes32, bytes32, bytes32)
    {
        Admission storage a = admissions[id][target];
        return (a.runtime, a.importHash, a.policyHash);
    }

    function entropyProviderTransition(
        address provider,
        EntropyProviderState next,
        string calldata reason
    ) external view returns (bytes32, bytes32, bytes32, uint8) {
        return L.transition(provider, next, reason, false);
    }

    function activateEntropyProvider(address provider, string calldata reason) external {
        T.requireOperational();
        L.update(authority, provider, EntropyProviderState.ACTIVE, reason, false);
    }

    function entropyPolicyInventory() external view returns (uint256, uint64, bytes32) {
        I.Header memory h = I.header();
        return (h.count, h.serial, h.idDigest);
    }

    function entropyPolicyCollectionAt(uint256 index) external view returns (uint256) {
        return I.at(index);
    }

    function exportEntropyPolicy(uint256 id) external view returns (C.PolicyExport memory) {
        return X.policy(core, id, configs[id], epochs[id], reveals[id]);
    }

    function exportEntropyRecovery(bytes32 id) external view returns (C.RecoveryExport memory) {
        return X.recovery(id);
    }

    function entropyPolicyImport() external view returns (C.ImportReceipt memory) {
        return T.receipt();
    }

    function importedEntropyPolicy(uint256 id)
        external
        view
        returns (bytes32, bytes32, address, bytes32, bytes32)
    {
        return T.imported(id);
    }

    function entropyPolicyImportReady(
        address predecessor,
        bytes32 hash,
        uint64 revision,
        uint256 count,
        uint64 serial,
        bytes32 digest
    ) external view returns (bool) {
        return T.ready(predecessor, hash, revision, count, serial, digest);
    }

    function entropyPolicyImportTransition(address predecessor, bytes32 manifest)
        external
        view
        returns (bytes32, bytes32, bytes32)
    {
        return W.transition(core, authority, predecessor, manifest);
    }

    function entropyPolicyImportSealTransition() external view returns (bytes32, bytes32, bytes32) {
        return W.sealTransition(core, authority);
    }

    function entropyPolicyImportActivationTransition()
        external
        view
        returns (bytes32, bytes32, bytes32)
    {
        return W.activationTransition(core, authority);
    }
}
