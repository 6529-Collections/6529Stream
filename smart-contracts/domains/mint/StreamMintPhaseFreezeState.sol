// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/mint/IStreamMintLedgerPhaseFreeze.sol";
import "../../interfaces/stream/mint/IStreamMintPhaseFreeze.sol";
import "../../interfaces/stream/mint/IStreamMintCounterPolicy.sol";
import "../../interfaces/stream/mint/IStreamMintLedgerImport.sol";
import "../../interfaces/stream/mint/IStreamMintRoyaltyPolicy.sol";
import {
    IStreamMintFreezeManagerBindings
} from "../../interfaces/stream/mint/IStreamMintFreezeManagerBindings.sol";

/// @notice Fixed Ledger worker for immutable phase constraints and monotonic executor rights.
/// @dev All state belongs to the Ledger. Configuration is read from the actual Manager;
/// no caller-provided configuration commitment can authorize a freeze or its inheritance.
library StreamMintPhaseFreezeState {
    struct Identity {
        uint256 collectionId;
        bytes32 phaseId;
    }

    struct Frozen {
        IStreamMintLedgerPhaseFreeze.PhaseFreeze fact;
        address[] executors;
        mapping(address => bool) allowed;
    }

    struct Progress {
        uint256 imported;
        uint256 required;
    }

    struct State {
        mapping(address => mapping(uint256 => mapping(bytes32 => Frozen))) phases;
        mapping(address => Identity[]) inventory;
        mapping(bytes32 => Progress) imports;
    }

    struct Snapshot {
        bytes32 configurationHash;
        bytes32 policyHash;
        bytes32[] counterIds;
        address[] executors;
    }

    event MintLedgerPhaseFrozen(
        uint16 schemaVersion,
        address indexed manager,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        bytes32 policyHash,
        bytes32 configurationHash
    );
    event MintLedgerPhaseFreezeImported(
        bytes32 indexed importRoot,
        address indexed predecessorManager,
        address indexed successorManager,
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 predecessorFrozenPolicyHash,
        bytes32 successorPolicyHash,
        bytes32 configurationHash
    );

    function freeze(
        State storage s,
        address manager,
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 policyHash
    ) external {
        Frozen storage f = s.phases[manager][collectionId][phaseId];
        if (f.fact.configurationHash != 0) {
            revert IStreamMintLedgerPhaseFreeze.MintPhaseFreezeInvalid(
                manager, collectionId, phaseId
            );
        }
        Snapshot memory current = _snapshot(manager, collectionId, phaseId, policyHash);
        _create(s, manager, collectionId, phaseId, current);
        emit MintLedgerPhaseFrozen(
            1, manager, collectionId, phaseId, policyHash, current.configurationHash
        );
    }

    /// @dev Called after registration and definition selection, inside the same atomic write.
    function validateRegistration(
        State storage s,
        address manager,
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 policyHash,
        bytes32[] calldata counterIds
    ) external {
        Frozen storage f = s.phases[manager][collectionId][phaseId];
        if (f.fact.configurationHash == 0) return;
        Snapshot memory current = _snapshot(manager, collectionId, phaseId, policyHash);
        if (
            current.configurationHash != f.fact.configurationHash
                || keccak256(abi.encode(current.counterIds)) != keccak256(abi.encode(counterIds))
        ) {
            revert IStreamMintLedgerPhaseFreeze.MintPhaseFreezePolicyMismatch(
                manager, collectionId, phaseId
            );
        }
        _requireSubset(f, current.executors, manager, collectionId, phaseId);
        _replaceExecutors(f, current.executors);
    }

    function captureImport(
        State storage s,
        bytes32 root,
        address predecessorLedger,
        address predecessorManager
    ) external {
        bytes memory input = abi.encodeCall(
            IERC165.supportsInterface, (type(IStreamMintLedgerPhaseFreeze).interfaceId)
        );
        bytes memory output = _read(predecessorLedger, input, 32);
        if (output.length != 32) revert IStreamMintLedgerImport.MintImportInvalid();
        uint256 supported = abi.decode(output, (uint256));
        if (supported > 1) revert IStreamMintLedgerImport.MintImportInvalid();
        if (supported == 0) return;
        output = _read(
            predecessorLedger,
            abi.encodeCall(IStreamMintLedgerPhaseFreeze.frozenPhaseCount, (predecessorManager)),
            32
        );
        if (output.length != 32) revert IStreamMintLedgerImport.MintImportInvalid();
        uint256 count = abi.decode(output, (uint256));
        if (count != 0 && predecessorLedger != address(this)) {
            revert IStreamMintLedgerPhaseFreeze.MintPhaseFreezeLedgerMismatch(
                predecessorLedger, address(this)
            );
        }
        s.imports[root].required = count;
    }

    /// @dev A not-yet-configured successor inherits constraints first; its first registration
    /// must satisfy them. This permits complete import before Core/Artist successor admission.
    function copyImport(
        State storage s,
        bytes32 root,
        IStreamMintLedgerImport.ImportCommitment memory c,
        uint256 maxCount
    ) external {
        Progress storage progress = s.imports[root];
        uint256 end = progress.imported + maxCount;
        if (end > progress.required) end = progress.required;
        for (uint256 i = progress.imported; i < end; ++i) {
            // Nonempty freeze inventories can only enter through this same original Ledger.
            if (c.predecessorLedger != address(this)) {
                revert IStreamMintLedgerPhaseFreeze.MintPhaseFreezeLedgerMismatch(
                    c.predecessorLedger, address(this)
                );
            }
            Identity memory identity = s.inventory[c.predecessorManager][i];
            _copyPhase(s, root, c, identity);
        }
        progress.imported = end;
    }

    function _copyPhase(
        State storage s,
        bytes32 root,
        IStreamMintLedgerImport.ImportCommitment memory c,
        Identity memory identity
    ) private {
        uint256 collectionId = identity.collectionId;
        bytes32 phaseId = identity.phaseId;
        Frozen storage previous = s.phases[c.predecessorManager][collectionId][phaseId];
        Frozen storage next = s.phases[c.successorManager][collectionId][phaseId];
        Snapshot memory current;
        bytes32 currentPolicy = IStreamMintLedger(address(this))
            .registeredPhasePolicyHash(c.successorManager, collectionId, phaseId);
        if (currentPolicy == 0) {
            current.configurationHash = previous.fact.configurationHash;
            current.executors = previous.executors;
        } else {
            current = _snapshot(c.successorManager, collectionId, phaseId, currentPolicy);
            if (current.configurationHash != previous.fact.configurationHash) {
                revert IStreamMintLedgerPhaseFreeze.MintPhaseFreezePolicyMismatch(
                    c.successorManager, collectionId, phaseId
                );
            }
            _requireSubset(previous, current.executors, c.successorManager, collectionId, phaseId);
        }
        if (next.fact.configurationHash == 0) {
            // Preserve the original first frozen policy as provenance across generations.
            current.policyHash = previous.fact.policyHash;
            _create(s, c.successorManager, collectionId, phaseId, current);
        } else {
            if (next.fact.configurationHash != current.configurationHash) {
                revert IStreamMintLedgerPhaseFreeze.MintPhaseFreezePolicyMismatch(
                    c.successorManager, collectionId, phaseId
                );
            }
            _requireSubset(next, current.executors, c.successorManager, collectionId, phaseId);
            _replaceExecutors(next, current.executors);
        }
        emit MintLedgerPhaseFreezeImported(
            root,
            c.predecessorManager,
            c.successorManager,
            collectionId,
            phaseId,
            previous.fact.policyHash,
            currentPolicy,
            previous.fact.configurationHash
        );
    }

    function _create(
        State storage s,
        address manager,
        uint256 collectionId,
        bytes32 phaseId,
        Snapshot memory current
    ) private {
        Frozen storage f = s.phases[manager][collectionId][phaseId];
        f.fact =
            IStreamMintLedgerPhaseFreeze.PhaseFreeze(current.policyHash, current.configurationHash);
        s.inventory[manager].push(Identity(collectionId, phaseId));
        _replaceExecutors(f, current.executors);
    }

    function _requireSubset(
        Frozen storage previous,
        address[] memory current,
        address manager,
        uint256 collectionId,
        bytes32 phaseId
    ) private view {
        for (uint256 i; i < current.length; ++i) {
            if (!previous.allowed[current[i]]) {
                revert IStreamMintLedgerPhaseFreeze.MintPhaseFreezePolicyMismatch(
                    manager, collectionId, phaseId
                );
            }
        }
    }

    function _replaceExecutors(Frozen storage f, address[] memory current) private {
        for (uint256 i; i < f.executors.length; ++i) {
            delete f.allowed[f.executors[i]];
        }
        delete f.executors;
        for (uint256 i; i < current.length; ++i) {
            f.executors.push(current[i]);
            f.allowed[current[i]] = true;
        }
    }

    function _snapshot(address manager, uint256 collectionId, bytes32 phaseId, bytes32 expected)
        private
        view
        returns (Snapshot memory result)
    {
        if (manager.code.length == 0 || collectionId == 0 || phaseId == 0 || expected == 0) {
            revert IStreamMintLedgerPhaseFreeze.MintPhaseFreezeInvalid(
                manager, collectionId, phaseId
            );
        }
        address boundLedger =
            _address(manager, IStreamMintFreezeManagerBindings.mintLedger.selector);
        address core = _address(manager, IStreamMintFreezeManagerBindings.core.selector);
        address registry =
            _address(manager, IStreamMintFreezeManagerBindings.moduleRegistry.selector);
        if (boundLedger != address(this) || core.code.length == 0 || registry.code.length == 0) {
            revert IStreamMintLedgerPhaseFreeze.MintPhaseFreezeInvalid(
                manager, collectionId, phaseId
            );
        }
        (bool exists, IStreamMintManager.MintPhaseConfig memory config) = abi.decode(
            _exact(manager, abi.encodeCall(IStreamMintManager.phase, (collectionId, phaseId)), 224),
            (bool, IStreamMintManager.MintPhaseConfig)
        );
        result.policyHash = abi.decode(
            _exact(
                manager,
                abi.encodeCall(IStreamMintManager.phasePolicyHash, (collectionId, phaseId)),
                32
            ),
            (bytes32)
        );
        if (!exists || result.policyHash != expected) {
            revert IStreamMintLedgerPhaseFreeze.MintPhaseFreezePolicyMismatch(
                manager, collectionId, phaseId
            );
        }
        config.paused = false;
        (bytes32 royaltyBranch, IStreamMintRoyaltyPolicy.Policy memory royalty) =
            _royalty(manager, collectionId, phaseId, config);
        IStreamMintManager.MintGateConfig memory gate = abi.decode(
            _exact(
                manager, abi.encodeCall(IStreamMintManager.phaseGate, (collectionId, phaseId)), 192
            ),
            (IStreamMintManager.MintGateConfig)
        );
        bytes memory raw = _read(
            manager,
            abi.encodeCall(IStreamMintManager.phaseCounterIds, (collectionId, phaseId)),
            64 + 16 * 32
        );
        _arrayShape(raw, 16);
        result.counterIds = abi.decode(raw, (bytes32[]));
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](result.counterIds.length);
        bool[] memory defined = new bool[](result.counterIds.length);
        IStreamMintCounterPolicy.Definition[] memory definitions =
            new IStreamMintCounterPolicy.Definition[](result.counterIds.length);
        for (uint256 i; i < result.counterIds.length; ++i) {
            bytes32 id = result.counterIds[i];
            counters[i] = abi.decode(
                _exact(
                    manager,
                    abi.encodeCall(IStreamMintManager.counterConfig, (collectionId, phaseId, id)),
                    224
                ),
                (IStreamMintManager.MintCounterConfig)
            );
            (defined[i], definitions[i]) = IStreamMintCounterPolicy(address(this))
                .counterDefinitionForManager(manager, counters[i].counterConfigHash);
            IStreamMintLedger.LedgerCounterPolicy memory registered = IStreamMintLedger(
                    address(this)
                ).registeredCounterPolicy(manager, collectionId, phaseId, id);
            IStreamMintManager.MintCounterConfig memory counter = counters[i];
            if (
                keccak256(abi.encode(registered))
                    != keccak256(
                        abi.encode(
                            counter.enabled,
                            counter.capMode,
                            counter.deltaMode,
                            counter.staticCap,
                            counter.staticIncrement,
                            counter.counterConfigHash
                        )
                    )
            ) {
                revert IStreamMintLedgerPhaseFreeze.MintPhaseFreezePolicyMismatch(
                    manager, collectionId, phaseId
                );
            }
        }
        result.configurationHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_PHASE_FREEZE_CONFIGURATION_V1"),
                block.chainid,
                core,
                registry,
                address(this),
                collectionId,
                phaseId,
                config,
                gate,
                result.counterIds,
                counters,
                defined,
                definitions,
                royaltyBranch,
                royalty.applicationConfigHash,
                royalty
            )
        );
        raw = _read(
            manager,
            abi.encodeCall(IStreamMintPhaseFreeze.phaseExecutors, (collectionId, phaseId)),
            64 + 64 * 32
        );
        _arrayShape(raw, 64);
        result.executors = abi.decode(raw, (address[]));
        for (uint256 i; i < result.executors.length; ++i) {
            if (result.executors[i] == address(0)) {
                revert IStreamMintLedgerImport.MintImportInvalid();
            }
            for (uint256 j; j < i; ++j) {
                if (result.executors[i] == result.executors[j]) {
                    revert IStreamMintLedgerImport.MintImportInvalid();
                }
            }
        }
    }

    /// @dev Only the verified Manager-domain wrapper is normalized. Original economic facts
    /// remain exact, and distinct branch tags prevent a raw config from impersonating a policy.
    function _royalty(
        address manager,
        uint256 collectionId,
        bytes32 phaseId,
        IStreamMintManager.MintPhaseConfig memory config
    ) private view returns (bytes32 branch, IStreamMintRoyaltyPolicy.Policy memory p) {
        p = abi.decode(
            _exact(
                manager,
                abi.encodeCall(
                    IStreamMintRoyaltyPolicy.phaseRoyaltyPolicy, (collectionId, phaseId)
                ),
                224
            ),
            (IStreamMintRoyaltyPolicy.Policy)
        );
        if (!p.configured) {
            return (keccak256("6529STREAM_MINT_PHASE_FREEZE_ROYALTY_UNCONFIGURED_V1"), p);
        }
        bytes32 actual = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_PHASE_ROYALTY_CONFIG_V1"),
                block.chainid,
                manager,
                collectionId,
                phaseId,
                p.applicationConfigHash,
                p.resolver,
                p.resolverRuntimeHash,
                uint8(2),
                p.electionHash,
                p.expectedModeAssignmentHash,
                p.expectedSourceRoyaltyPolicyHash
            )
        );
        if (config.configHash != actual) {
            revert IStreamMintLedgerPhaseFreeze.MintPhaseFreezePolicyMismatch(
                manager, collectionId, phaseId
            );
        }
        config.configHash = p.applicationConfigHash;
        branch = keccak256("6529STREAM_MINT_PHASE_FREEZE_ROYALTY_CONFIGURED_V1");
    }

    function _arrayShape(bytes memory raw, uint256 maximum) private pure {
        uint256 offset;
        uint256 count;
        assembly ("memory-safe") {
            offset := mload(add(raw, 32))
            count := mload(add(raw, 64))
        }
        if (raw.length < 64 || count > maximum || offset != 32 || raw.length != 64 + count * 32) {
            revert IStreamMintLedgerImport.MintImportInvalid();
        }
    }

    function _address(address target, bytes4 selector) private view returns (address) {
        return abi.decode(_exact(target, abi.encodeWithSelector(selector), 32), (address));
    }

    function _exact(address target, bytes memory input, uint256 size)
        private
        view
        returns (bytes memory result)
    {
        result = _read(target, input, size);
        if (result.length != size) revert IStreamMintPhaseFreeze.MintPhaseFreezeReadFailed(target);
    }

    /// @dev Copy bound comes from the original static ABI or the16-counter/64-executor limits.
    function _read(address target, bytes memory input, uint256 maximum)
        private
        view
        returns (bytes memory result)
    {
        result = new bytes(maximum);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(input, 32), mload(input), add(result, 32), maximum)
            size := returndatasize()
        }
        if (!ok || size > maximum) revert IStreamMintPhaseFreeze.MintPhaseFreezeReadFailed(target);
        assembly ("memory-safe") { mstore(result, size) }
    }
}
