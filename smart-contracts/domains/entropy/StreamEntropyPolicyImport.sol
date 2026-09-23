// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamEntropyCoordinator as H } from "./StreamEntropyCoordinator.sol";
import { IStreamCore } from "../../interfaces/stream/core/IStreamCore.sol";
import { IStreamCorePointers } from "../../interfaces/stream/core/IStreamCorePointers.sol";
import {
    IStreamEntropyCoordinator
} from "../../interfaces/stream/entropy/IStreamEntropyCoordinator.sol";
import {
    IStreamEntropyPolicyContinuity as C
} from "../../interfaces/stream/entropy/IStreamEntropyPolicyContinuity.sol";
import {
    IStreamEntropyOriginRelay as O
} from "../../interfaces/stream/entropy/IStreamEntropyOriginRelay.sol";
import {
    IStreamEntropyCollectionPolicy as P
} from "../../interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import {
    IStreamRevealFeeEscrow as F
} from "../../interfaces/stream/entropy/IStreamRevealFeeEscrow.sol";
import { IStreamEntropyProvider } from "../../interfaces/stream/entropy/IStreamEntropyProvider.sol";
import {
    IStreamGovernedParameterAuthority as A
} from "../../interfaces/stream/parameters/IStreamGovernedParameterAuthority.sol";
import {
    IStreamModuleRegistry as M
} from "../../interfaces/stream/modules/IStreamModuleRegistry.sol";
import {
    IStreamMintGovernanceRegistry as G
} from "../../interfaces/stream/mint/IStreamMintGovernanceRegistry.sol";
import { StreamEntropyPolicyImportState as T } from "./StreamEntropyPolicyImportState.sol";
import { StreamEntropyPolicyInventory as I } from "./StreamEntropyPolicyInventory.sol";
import {
    StreamEntropyPolicyImportValidation as V
} from "./StreamEntropyPolicyImportValidation.sol";
import { StreamEntropyCollectionPolicyState as S } from "./StreamEntropyCollectionPolicyState.sol";
import { StreamEntropyCollectionRecovery as B } from "./StreamEntropyCollectionRecovery.sol";
import { StreamEntropyRecoveryPolicies as R } from "./StreamEntropyRecoveryPolicies.sol";
import { StreamEntropyProviderLifecycle as L } from "./StreamEntropyProviderLifecycle.sol";
import { StreamEntropyIncidentParameters as Gas } from "./StreamEntropyIncidentParameters.sol";

/// @notice Fixed one-session import worker; all original storage is passed explicitly by its host.
/// @dev No reset exists: a source mutation invalidating a staged session requires a fresh candidate.
library StreamEntropyPolicyImport {
    bytes32 private constant AUTH_GAS =
        keccak256("6529STREAM_GGP_ENTROPY_RELAY_AUTH_READ_GAS_LIMIT");
    bytes32 private constant ENTROPY = keccak256("ENTROPY_COORDINATOR");
    bytes32 private constant MODULE_TYPE =
        0xb3b3ef20764c647bdeda70b21ab009ff2783106d6995be14389ec6f42ea6dfbb;
    bytes32 private constant SCOPE = keccak256("6529STREAM_ENTROPY_POLICY_IMPORT_SCOPE_V1");
    bytes32 private constant STATE = keccak256("6529STREAM_ENTROPY_POLICY_IMPORT_STATE_V1");
    bytes32 private constant EXPORTS = keccak256("6529STREAM_ENTROPY_POLICY_IMPORT_EXPORTS_V1");
    bytes32 private constant APPEND =
        keccak256("6529STREAM_ENTROPY_POLICY_IMPORT_EXPORT_APPEND_V1");

    struct Pointer {
        address target;
        bytes32 codeHash;
        bool frozen;
        bytes32 moduleType;
        bytes4 interfaceId;
        address registry;
        uint8 status;
        bytes32 moduleManifestHash;
        bytes32 deploymentManifestHash;
        uint64 revision;
    }

    event EntropyPolicyImportBegun(
        uint16 schemaVersion,
        bytes32 indexed importHash,
        address indexed predecessor,
        uint64 nonce,
        bytes32 predecessorCodeHash,
        uint64 pointerRevision,
        uint256 count,
        uint64 serial,
        bytes32 idDigest,
        bytes32 manifestHash,
        bytes32 actionId
    );
    event EntropyPolicyImported(
        uint16 schemaVersion,
        bytes32 indexed importHash,
        uint256 indexed collectionId,
        address indexed policyOrigin,
        uint256 index,
        bytes32 policyOriginCodeHash,
        bytes32 policyHash,
        bytes32 exportDigest
    );
    event EntropyRecoveryPolicyImported(
        uint16 schemaVersion,
        bytes32 indexed importHash,
        bytes32 indexed policyId,
        address indexed policyOrigin,
        bytes32 policyOriginCodeHash,
        bytes32 policyHash
    );
    event EntropyRelayRouteConfirmed(
        uint16 schemaVersion,
        bytes32 indexed importHash,
        uint256 indexed collectionId,
        address indexed policyOrigin,
        bytes32 policyHash
    );
    event EntropyPolicyImportSealed(
        uint16 schemaVersion,
        bytes32 indexed importHash,
        bytes32 exportDigest,
        uint256 count,
        uint256 confirmedRelayCount,
        bytes32 actionId
    );
    event EntropyPolicyImportActivated(
        uint16 schemaVersion, bytes32 indexed importHash, bytes32 actionId
    );

    function write(
        IStreamCore core,
        address authority,
        mapping(uint256 => H.CollectionConfig) storage configs,
        mapping(uint256 => uint32) storage epochs,
        mapping(uint256 => F.CollectionRevealPolicy) storage reveals,
        mapping(uint256 => uint256) storage escrows,
        bytes calldata data
    ) public {
        bytes4 selector = bytes4(data[:4]);
        if (selector == C.beginEntropyPolicyImport.selector) {
            (address predecessor, bytes32 manifest) = abi.decode(data[4:], (address, bytes32));
            _begin(core, authority, predecessor, manifest);
        } else if (selector == C.importNextEntropyPolicy.selector) {
            _next(
                core, authority, configs, epochs, reveals, escrows, abi.decode(data[4:], (uint256))
            );
        } else if (selector == C.confirmEntropyRelayRoute.selector) {
            _confirm(core, authority, abi.decode(data[4:], (uint256)));
        } else if (selector == C.sealEntropyPolicyImport.selector) {
            _seal(core, authority);
        } else if (selector == C.activateEntropyPolicyImport.selector) {
            _activate(core, authority);
        } else {
            revert C.InvalidEntropyPolicyImport();
        }
    }

    /// @dev Three finite transition selectors share one host transport and retain their exact ABI.
    function transitionEncoded(IStreamCore core, address authority, bytes calldata data)
        public
        view
        returns (bytes32, bytes32, bytes32)
    {
        bytes4 selector = bytes4(data[:4]);
        if (selector == C.entropyPolicyImportTransition.selector) {
            (address predecessor, bytes32 manifest) = abi.decode(data[4:], (address, bytes32));
            return transition(core, authority, predecessor, manifest);
        }
        if (selector == C.entropyPolicyImportSealTransition.selector) {
            return sealTransition(core, authority);
        }
        if (selector == C.entropyPolicyImportActivationTransition.selector) {
            return activationTransition(core, authority);
        }
        revert C.InvalidEntropyPolicyImport();
    }

    function transition(IStreamCore core, address authority, address predecessor, bytes32 manifest)
        public
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash)
    {
        C.ImportReceipt memory next = _prepare(core, authority, predecessor, manifest);
        scope = _scope(core, C.beginEntropyPolicyImport.selector);
        oldHash = _state(scope, T.receipt());
        newHash = _state(scope, next);
    }

    function sealTransition(IStreamCore core, address authority)
        public
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash)
    {
        _expect(C.ImportState.STAGING);
        _source(core, authority, false);
        _complete();
        return _phase(core, C.sealEntropyPolicyImport.selector, C.ImportState.SEALED);
    }

    /// @dev Schedulable before Core replacement; execution separately requires the exact next pointer.
    function activationTransition(IStreamCore core, address authority)
        public
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash)
    {
        _expect(C.ImportState.SEALED);
        _identity(core, authority, T.store().receipt.predecessor);
        _header();
        _complete();
        return _phase(core, C.activateEntropyPolicyImport.selector, C.ImportState.ACTIVE);
    }

    function _prepare(IStreamCore core, address authority, address predecessor, bytes32 manifest)
        private
        view
        returns (C.ImportReceipt memory r)
    {
        T.Store storage s = T.store();
        if (s.everUsed || s.receipt.state != C.ImportState.NONE || I.count() != 0) {
            revert C.EntropyPolicyImportNotFresh();
        }
        if (manifest == 0 || predecessor == address(this)) revert C.InvalidEntropyPolicyImport();
        _identity(core, authority, predecessor);
        Pointer memory pointer = _pointer(core, ENTROPY);
        if (
            pointer.target != predecessor || pointer.codeHash != predecessor.codehash
                || pointer.revision == type(uint64).max
        ) {
            revert C.EntropyPolicyImportSourceChanged(predecessor);
        }
        r.state = C.ImportState.STAGING;
        r.nonce = 1;
        r.predecessor = predecessor;
        r.predecessorCodeHash = predecessor.codehash;
        r.pointerRevision = pointer.revision;
        (r.count, r.serial, r.idDigest) = abi.decode(
            _read(predecessor, abi.encodeCall(C.entropyPolicyInventory, ()), 96),
            (uint256, uint64, bytes32)
        );
        if (r.idDigest == 0 || r.serial < r.count) revert C.InvalidEntropyPolicyImport();
        r.manifestHash = manifest;
        r.importHash = keccak256(
            abi.encode(
                T.IMPORT_DOMAIN,
                block.chainid,
                address(this),
                address(this).codehash,
                address(core),
                r.nonce,
                predecessor,
                r.predecessorCodeHash,
                r.pointerRevision,
                r.count,
                r.serial,
                r.idDigest,
                manifest
            )
        );
        r.exportDigest = keccak256(abi.encode(EXPORTS, r.importHash));
    }

    function _begin(IStreamCore core, address authority, address predecessor, bytes32 manifest)
        private
    {
        C.ImportReceipt memory next = _prepare(core, authority, predecessor, manifest);
        bytes32 scope = _scope(core, C.beginEntropyPolicyImport.selector);
        next.beginActionId =
            _action(authority, scope, _state(scope, T.receipt()), _state(scope, next), 1);
        T.store().receipt = next;
        T.store().everUsed = true;
        emit EntropyPolicyImportBegun(
            1,
            next.importHash,
            predecessor,
            next.nonce,
            next.predecessorCodeHash,
            next.pointerRevision,
            next.count,
            next.serial,
            next.idDigest,
            manifest,
            next.beginActionId
        );
    }

    function _next(
        IStreamCore core,
        address authority,
        mapping(uint256 => H.CollectionConfig) storage configs,
        mapping(uint256 => uint32) storage epochs,
        mapping(uint256 => F.CollectionRevealPolicy) storage reveals,
        mapping(uint256 => uint256) storage escrows,
        uint256 index
    ) private {
        _expect(C.ImportState.STAGING);
        _source(core, authority, false);
        C.ImportReceipt storage receipt_ = T.store().receipt;
        if (index != receipt_.nextIndex || index >= receipt_.count) {
            revert C.EntropyPolicyImportIndex(index, receipt_.nextIndex);
        }
        uint256 id = abi.decode(
            _read(receipt_.predecessor, abi.encodeCall(C.entropyPolicyCollectionAt, (index)), 32),
            (uint256)
        );
        bytes memory raw =
            _read(receipt_.predecessor, abi.encodeCall(C.exportEntropyPolicy, (id)), 1184);
        C.PolicyExport memory p = abi.decode(raw, (C.PolicyExport));
        if (
            p.collectionId != id || keccak256(raw) != keccak256(abi.encode(p)) || escrows[id] != 0
                || configs[id].provider != address(0) || S.explicitPolicy(id)
        ) revert C.InvalidEntropyPolicyExport(id);
        V.validatePolicy(block.chainid, address(core), p);
        _pin(p.policyOrigin, p.policyOriginCodeHash);
        if (p.policy.provider != address(0)) {
            _provider(p.policy.provider, p.providerCodeHash, p.providerConfigHash, p.policyOrigin);
        }
        bytes32 recoveryHash;
        if (p.recovery.maxFreshRecoveryAttempts != 0) recoveryHash = _recovery(core, p);
        _install(configs, epochs, reveals, p);
        T.ImportedPolicy storage imported_ = T.store().policies[id];
        imported_.importHash = receipt_.importHash;
        imported_.exportHash = keccak256(abi.encode(p));
        imported_.policyOrigin = p.policyOrigin;
        imported_.policyOriginCodeHash = p.policyOriginCodeHash;
        imported_.policyHash = p.record.policyHash;
        imported_.routeRequired = p.policy.mode != P.Mode.DISABLED
            && !(p.policy.mode == P.Mode.INSTANT
                && p.policy.renderRequirement == P.RenderRequirement.NOT_REQUIRED);
        if (imported_.routeRequired) ++receipt_.requiredRelayCount;
        receipt_.exportDigest = keccak256(
            abi.encode(APPEND, receipt_.exportDigest, index, id, imported_.exportHash, recoveryHash)
        );
        ++receipt_.nextIndex;
        emit EntropyPolicyImported(
            1,
            receipt_.importHash,
            id,
            p.policyOrigin,
            index,
            p.policyOriginCodeHash,
            p.record.policyHash,
            receipt_.exportDigest
        );
    }

    function _install(
        mapping(uint256 => H.CollectionConfig) storage configs,
        mapping(uint256 => uint32) storage epochs,
        mapping(uint256 => F.CollectionRevealPolicy) storage reveals,
        C.PolicyExport memory p
    ) private {
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
            S.Store storage s = S.store();
            s.entries[id] = S.Entry(
                p.record.revision,
                p.record.mode,
                p.record.securityClass,
                p.record.renderRequirement,
                p.record.policyHash,
                p.record.lastActionId,
                p.record.artistConsentRecord
            );
            s.actions[id][p.record.lastActionId] = true;
            s.consents[p.record.artistConsentRecord] = true;
        }
        I.installImported(id, p.policyOrigin, p.policyOriginCodeHash);
    }

    function _recovery(IStreamCore core, C.PolicyExport memory p) private returns (bytes32 hash) {
        bytes32 id = p.recovery.policyId;
        bytes memory raw = _readDynamic(
            T.store().receipt.predecessor, abi.encodeCall(C.exportEntropyRecovery, (id)), 5696
        );
        C.RecoveryExport memory r = abi.decode(raw, (C.RecoveryExport));
        hash = keccak256(abi.encode(r));
        if (hash != keccak256(raw)) revert C.InvalidEntropyRecoveryExport(id);
        V.validateRecovery(block.chainid, address(core), r);
        V.verifyBinding(p, r);
        _pin(r.policyOrigin, r.policyOriginCodeHash);
        if (r.successor != address(0)) _pin(r.successor, r.successorCodeHash);
        for (uint256 i; i < r.policy.steps.length; ++i) {
            address provider = r.policy.steps[i].provider;
            _provider(
                provider, provider.codehash, r.policy.steps[i].providerConfigHash, p.policyOrigin
            );
        }
        T.ImportedRecovery storage prior = T.store().recoveries[id];
        if (prior.exportHash != 0) {
            if (prior.exportHash != hash) revert C.InvalidEntropyRecoveryExport(id);
            return hash;
        }
        R.installImported(
            id, r.policy, r.policyHash, r.revision, r.lastActionId, r.successor, r.successorCodeHash
        );
        prior.exportHash = hash;
        prior.policyOrigin = r.policyOrigin;
        prior.policyOriginCodeHash = r.policyOriginCodeHash;
        emit EntropyRecoveryPolicyImported(
            1,
            T.store().receipt.importHash,
            id,
            r.policyOrigin,
            r.policyOriginCodeHash,
            r.policyHash
        );
    }

    function _confirm(IStreamCore core, address authority, uint256 id) private {
        _expect(C.ImportState.STAGING);
        _source(core, authority, false);
        T.imported(id);
        T.ImportedPolicy storage p = T.store().policies[id];
        if (!p.routeRequired || p.routeConfirmed) revert C.EntropyPolicyRelayUnconfirmed(id);
        _pin(p.policyOrigin, p.policyOriginCodeHash);
        (bytes32 successorHash, bytes32 importHash, bytes32 policyHash) = abi.decode(
            _read(p.policyOrigin, abi.encodeCall(O.entropyRelayAdmission, (id, address(this))), 96),
            (bytes32, bytes32, bytes32)
        );
        if (
            successorHash != address(this).codehash || importHash != p.importHash
                || policyHash != p.policyHash
        ) revert C.EntropyPolicyRelayUnconfirmed(id);
        p.routeConfirmed = true;
        ++T.store().receipt.confirmedRelayCount;
        emit EntropyRelayRouteConfirmed(1, p.importHash, id, p.policyOrigin, p.policyHash);
    }

    function _seal(IStreamCore core, address authority) private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = sealTransition(core, authority);
        bytes32 action = _action(authority, scope, oldHash, newHash, 1);
        C.ImportReceipt storage r = T.store().receipt;
        r.state = C.ImportState.SEALED;
        r.sealActionId = action;
        emit EntropyPolicyImportSealed(
            1, r.importHash, r.exportDigest, r.count, r.confirmedRelayCount, action
        );
    }

    function _activate(IStreamCore core, address authority) private {
        _expect(C.ImportState.SEALED);
        _source(core, authority, true);
        _complete();
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            _phase(core, C.activateEntropyPolicyImport.selector, C.ImportState.ACTIVE);
        bytes32 action = _action(authority, scope, oldHash, newHash, 3);
        C.ImportReceipt storage r = T.store().receipt;
        r.state = C.ImportState.ACTIVE;
        r.activationActionId = action;
        emit EntropyPolicyImportActivated(1, r.importHash, action);
    }

    function _complete() private view {
        C.ImportReceipt storage r = T.store().receipt;
        I.Header memory h = I.header();
        if (
            r.nextIndex != r.count || r.requiredRelayCount != r.confirmedRelayCount
                || h.count != r.count || h.idDigest != r.idDigest
        ) revert C.InvalidEntropyPolicyImport();
    }

    function _expect(C.ImportState state) private view {
        if (T.store().receipt.state != state) {
            revert C.EntropyPolicyImportState(state, T.store().receipt.state);
        }
    }

    function _source(IStreamCore core, address authority, bool activating) private view {
        C.ImportReceipt storage r = T.store().receipt;
        _pin(r.predecessor, r.predecessorCodeHash);
        _identity(core, authority, r.predecessor);
        Pointer memory pointer = _pointer(core, ENTROPY);
        if (activating) {
            if (
                pointer.target != address(this) || pointer.codeHash != address(this).codehash
                    || pointer.revision != r.pointerRevision + 1
            ) revert C.EntropyPolicyImportSourceChanged(r.predecessor);
        } else if (
            pointer.target != r.predecessor || pointer.codeHash != r.predecessorCodeHash
                || pointer.revision != r.pointerRevision
        ) {
            revert C.EntropyPolicyImportSourceChanged(r.predecessor);
        }
        _header();
    }

    function _header() private view {
        C.ImportReceipt storage r = T.store().receipt;
        (uint256 count, uint64 serial, bytes32 digest) = abi.decode(
            _read(r.predecessor, abi.encodeCall(C.entropyPolicyInventory, ()), 96),
            (uint256, uint64, bytes32)
        );
        if (count != r.count || serial != r.serial || digest != r.idDigest) {
            revert C.EntropyPolicyImportSourceChanged(r.predecessor);
        }
    }

    function _identity(IStreamCore core, address authority, address source) private view {
        Pointer memory modules = _pointer(core, keccak256("MODULE_REGISTRY"));
        if (
            abi.decode(
                    _read(modules.target, abi.encodeCall(G.governanceExecutor, ()), 32), (address)
                ) != authority
        ) revert C.EntropyPolicyImportDependency(modules.target);
        if (
            source.code.length == 0
                || abi.decode(_read(source, abi.encodeWithSignature("core()"), 32), (address))
                    != address(core)
                || abi.decode(_read(source, abi.encodeWithSignature("authority()"), 32), (address))
                    != authority
        ) revert C.EntropyPolicyImportDependency(source);
        _eligible(modules.target, source);
        _eligible(modules.target, address(this));
    }

    function _eligible(address registry, address target) private view {
        if (
            abi.decode(
                    _read(
                        registry,
                        abi.encodeCall(
                            M.isModuleEligible,
                            (target, MODULE_TYPE, type(IStreamEntropyCoordinator).interfaceId)
                        ),
                        32
                    ),
                    (uint256)
                ) != 1
        ) revert C.EntropyPolicyImportDependency(target);
    }

    function _pointer(IStreamCore core, bytes32 kind) private view returns (Pointer memory p) {
        p = abi.decode(
            _read(
                address(core), abi.encodeCall(IStreamCorePointers.getSatellitePointer, (kind)), 320
            ),
            (Pointer)
        );
        _pin(p.target, p.codeHash);
        if (p.status != 1 || p.revision == 0) revert C.EntropyPolicyImportDependency(p.target);
    }

    function _provider(address provider, bytes32 codeHash, bytes32 configHash, address origin)
        private
        view
    {
        _pin(provider, codeHash);
        L.requireActive(provider);
        if (
            abi.decode(
                        _read(
                            provider,
                            abi.encodeCall(
                                IStreamEntropyProvider.streamEntropyProviderConfigHash, ()
                            ),
                            32
                        ),
                        (bytes32)
                    ) != configHash
                || abi.decode(
                        _read(provider, abi.encodeWithSignature("coordinator()"), 32), (address)
                    ) != origin
        ) revert C.EntropyPolicyImportDependency(provider);
    }

    function _pin(address target, bytes32 hash) private view {
        if (target.code.length == 0 || hash == 0 || target.codehash != hash) {
            revert C.EntropyPolicyImportDependency(target);
        }
    }

    function _action(address authority, bytes32 scope, bytes32 oldHash, bytes32 newHash, uint8 cls)
        private
        returns (bytes32 action)
    {
        if (msg.sender != authority || authority.codehash != R.authorityCodeHashLocal()) {
            revert C.InvalidEntropyPolicyImport();
        }
        (
            uint256 executing,
            bytes32 id,
            uint256 actualClass,
            bytes32 actualScope,
            bytes32 actualOld,
            bytes32 actualNew
        ) = abi.decode(
            _read(authority, abi.encodeCall(A.currentAction, ()), 192),
            (uint256, bytes32, uint256, bytes32, bytes32, bytes32)
        );
        if (
            executing != 1 || id == 0 || actualClass != cls || actualScope != scope
                || actualOld != oldHash || actualNew != newHash
        ) revert C.InvalidEntropyPolicyImport();
        if (T.store().actions[id]) revert C.EntropyPolicyImportReplay(id);
        T.store().actions[id] = true;
        return id;
    }

    function _scope(IStreamCore core, bytes4 selector) private view returns (bytes32) {
        return keccak256(abi.encode(SCOPE, block.chainid, address(this), address(core), selector));
    }

    function _state(bytes32 scope, C.ImportReceipt memory r) private pure returns (bytes32) {
        // Governance action receipts are excluded, as the new action ID is not yet assigned.
        return keccak256(
            abi.encode(
                STATE,
                scope,
                r.state,
                r.nonce,
                r.importHash,
                r.nextIndex,
                r.exportDigest,
                r.requiredRelayCount,
                r.confirmedRelayCount
            )
        );
    }

    function _phase(IStreamCore core, bytes4 selector, C.ImportState next)
        private
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash)
    {
        scope = _scope(core, selector);
        C.ImportReceipt memory r = T.receipt();
        oldHash = _state(scope, r);
        r.state = next;
        newHash = _state(scope, r);
    }

    function _read(address target, bytes memory data, uint256 size)
        private
        view
        returns (bytes memory result)
    {
        result = _readDynamic(target, data, size);
        if (result.length != size) revert C.EntropyPolicyImportDependency(target);
    }

    function _readDynamic(address target, bytes memory data, uint256 limit)
        private
        view
        returns (bytes memory result)
    {
        result = new bytes(limit);
        uint256 cap = Gas.value(AUTH_GAS);
        uint256 available = gasleft();
        if (available <= 10000 || (available - 10000) / 64 * 63 < cap) {
            revert C.EntropyPolicyImportDependency(target);
        }
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), add(result, 32), limit)
            size := returndatasize()
        }
        if (!ok || size == 0 || size > limit) revert C.EntropyPolicyImportDependency(target);
        assembly ("memory-safe") { mstore(result, size) }
    }
}
