// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/interfaces/stream/revenue/IStreamRevenueRuntimeRegistry.sol";
import "../../smart-contracts/interfaces/stream/revenue/IStreamRevenueRuntimeBinding.sol";
import "../../smart-contracts/interfaces/stream/revenue/IStreamRevenueEscrowRecoveryManifest.sol";
import "../../smart-contracts/interfaces/stream/revenue/IStreamRevenueEscrowRecovery.sol";
import "../../smart-contracts/domains/revenue/StreamRevenueRuntimeBinding.sol";
import "./StreamCurrentStackPlan.sol";
import "../../smart-contracts/interfaces/stream/governance/IStreamGovernanceExecutor.sol";
import "../../smart-contracts/interfaces/stream/governance/IStreamGenesisInitializer.sol";

/// @notice Separately observed runtime admission and escrow recovery stages for the saved-plan caller.
/// @dev Use StreamGovernanceStagePlan for exact publication/scheduling/execution and Safe CALLs.
///      Reobserve after each stage: factory approval, factory opt-in, escrow opt-in are dependent.
library StreamRevenueRuntimePlan {
    error RevenueRuntimeActivationIncomplete();

    function factoryStatus(
        IStreamRevenueRuntimeRegistry registry,
        address factory,
        uint8 status,
        bytes32 reasonHash,
        string memory reasonURI,
        bytes32 incidentManifestHash
    ) internal view returns (GenesisBatch memory) {
        (uint8 cls, bytes32 scope, bytes32 oldHash, bytes32 newHash) = registry.factoryTransitionHashes(
            factory, status, reasonHash, reasonURI, incidentManifestHash
        );
        return _one(
            cls,
            address(registry),
            abi.encodeCall(
                registry.setFactoryStatus,
                (factory, status, reasonHash, reasonURI, incidentManifestHash)
            ),
            scope,
            oldHash,
            newHash
        );
    }

    function runtimeStatus(
        IStreamRevenueRuntimeRegistry registry,
        bytes32 runtime,
        uint8 status,
        bytes32 reasonHash,
        string memory reasonURI,
        bytes32 incidentManifestHash
    ) internal view returns (GenesisBatch memory) {
        (uint8 cls, bytes32 scope, bytes32 oldHash, bytes32 newHash) = registry.runtimeTransitionHashes(
            runtime, status, reasonHash, reasonURI, incidentManifestHash
        );
        return _one(
            cls,
            address(registry),
            abi.encodeCall(
                registry.setRuntimeStatus,
                (runtime, status, reasonHash, reasonURI, incidentManifestHash)
            ),
            scope,
            oldHash,
            newHash
        );
    }

    function bind(IStreamRevenueRuntimeBinding host, address registry)
        internal
        view
        returns (GenesisBatch memory)
    {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            host.revenueRuntimeBindingTransitionHashes(registry);
        return _one(
            1,
            address(host),
            abi.encodeCall(host.initializeRevenueRuntimeRegistry, (registry)),
            scope,
            oldHash,
            newHash
        );
    }

    function requireActivated(address factory, address escrow) internal view {
        (address registry, bytes32 hash) = StreamRevenueRuntimeBinding.factoryBinding(factory);
        if (
            registry == address(0) || hash == 0
                || IStreamRevenueRuntimeBinding(escrow).revenueRuntimeRegistry() != registry
                || IStreamRevenueRuntimeBinding(escrow).revenueRuntimeRegistryCodeHash() != hash
        ) {
            revert RevenueRuntimeActivationIncomplete();
        }
        StreamRevenueRuntimeBinding.requireState(factory, registry, hash, true);
    }

    function recovery(
        IStreamRevenueEscrowRecoveryManifest escrow,
        StreamEscrowRecoveryTypes.EscrowRecoveryRecord memory p
    ) internal view returns (bytes32 id, GenesisBatch memory batch) {
        bytes32 scope;
        bytes32 oldHash;
        bytes32 newHash;
        (id, scope, oldHash, newHash) = escrow.escrowRecoveryTransitionHashes(
            p.creditKey,
            p.successorWallet,
            p.successorProfileId,
            p.successorRuntimeCodeHash,
            p.expectedAmount,
            p.recoveryManifest,
            p.executeAfter,
            p.reasonHash,
            p.reasonURI
        );
        bytes memory data = abi.encodeCall(
            IStreamRevenueEscrowRecovery.scheduleEscrowRecovery,
            (
                p.creditKey,
                p.successorWallet,
                p.successorProfileId,
                p.successorRuntimeCodeHash,
                p.expectedAmount,
                p.recoveryManifest,
                p.executeAfter,
                p.reasonHash,
                p.reasonURI
            )
        );
        batch = _one(4, address(escrow), data, scope, oldHash, newHash);
    }

    function terminal(IStreamRevenueEscrowRecoveryManifest escrow, bytes32 id)
        internal
        view
        returns (GenesisBatch memory)
    {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = escrow.escrowRecoveryTerminalHashes(id);
        return _one(
            2,
            address(escrow),
            abi.encodeCall(escrow.authorizeTerminalEscrowRecovery, (id)),
            scope,
            oldHash,
            newHash
        );
    }

    function cancellation(
        IStreamRevenueEscrowRecoveryManifest escrow,
        bytes32 id,
        bytes32 reasonHash,
        string memory reasonURI
    ) internal view returns (GenesisBatch memory) {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            escrow.escrowRecoveryCancellationHashes(id, reasonHash, reasonURI);
        return _one(
            0,
            address(escrow),
            abi.encodeCall(
                IStreamRevenueEscrowRecovery.cancelEscrowRecovery, (id, reasonHash, reasonURI)
            ),
            scope,
            oldHash,
            newHash
        );
    }

    /// @notice Classifier admissions remain separate isolated Executor self-calls.
    /// @dev Tightening permission is delayed class 1; imposing terminal classification is
    ///      original class 0. The recovery itself still needs class 4 plus separate class 2.
    function classifier(IStreamGovernanceExecutor executor, address target, bytes4 selector)
        internal
        view
        returns (GenesisBatch memory)
    {
        bool terminalSelector = selector
            == IStreamRevenueEscrowRecoveryManifest.authorizeTerminalEscrowRecovery.selector;
        if (
            selector != IStreamRevenueRuntimeRegistry.setFactoryStatus.selector
                && selector != IStreamRevenueRuntimeRegistry.setRuntimeStatus.selector
                && selector != IStreamRevenueEscrowRecovery.cancelEscrowRecovery.selector
                && !terminalSelector
        ) {
            revert RevenueRuntimeActivationIncomplete();
        }
        (bool enabled,, uint64 revision, bytes32 oldHash) = terminalSelector
            ? executor.freezeSelectorConfig(target, selector)
            : executor.tighteningCallConfig(target, selector);
        if (enabled || revision == type(uint64).max || target.code.length == 0) {
            revert RevenueRuntimeActivationIncomplete();
        }
        bytes32 kind = terminalSelector
            ? keccak256("6529STREAM_GOVERNANCE_CONFIG_FREEZE_SELECTOR")
            : keccak256("6529STREAM_GOVERNANCE_CONFIG_TIGHTENING_CALL");
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_CONFIG_SCOPE_V1"),
                block.chainid,
                address(executor),
                kind,
                target,
                selector
            )
        );
        bytes32 next = keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_CONFIG_STATE_V1"),
                block.chainid,
                address(executor),
                kind,
                target,
                selector,
                true,
                target.codehash,
                revision + 1
            )
        );
        bytes memory data = terminalSelector
            ? abi.encodeCall(executor.registerFreezeSelector, (target, selector, true))
            : abi.encodeCall(executor.setTighteningCall, (target, selector, true));
        return _one(terminalSelector ? 0 : 1, address(executor), data, scope, oldHash, next);
    }

    function _one(
        uint8 cls,
        address target,
        bytes memory data,
        bytes32 scope,
        bytes32 oldHash,
        bytes32 newHash
    ) private pure returns (GenesisBatch memory batch) {
        batch.actionClass = cls;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.callDatas[0] = data;
        batch.calls[0] = StreamCurrentStackPlan.call(target, data, scope, oldHash, newHash);
    }
}
