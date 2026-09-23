// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCanonicalNativeSalesDeployment.sol";
import "./StreamCurrentStackPlan.sol";
import "./StreamGovernanceStagePlan.sol";
import "../../smart-contracts/domains/mint/StreamMintManager.sol";
import "../../smart-contracts/domains/revenue/StreamPreparedNativeSettlementAdmission.sol";

interface CanonicalNativeSalesOwner {
    function owner() external view returns (address);
}

/// @notice Observed-state setup for three canonical native companion products.
/// @dev Keeps the original 37 roles intact. Plans grant no authority. Artist consent, catalog
/// admission and target validation remain authoritative. Journal exact plans before scheduling.
library StreamCanonicalNativeSalesActivationPlan {
    struct Context {
        StreamCanonicalNativeSalesDeployment.Configuration configuration;
        StreamCanonicalNativeSalesDeployment.Products products;
    }

    struct Phase {
        uint256 collectionId;
        bytes32 phaseId;
        IStreamMintManager.MintPhaseConfig config;
        bytes32[] counterIds;
        IStreamMintManager.MintCounterConfig[] counterConfigs;
    }

    struct OwnerCall {
        StreamGovernanceStagePlan.NextCall call;
        bytes32 observedStateHash;
        bytes32 resultingPolicyHash;
    }

    function pendingRegistrations(Context memory x)
        internal
        view
        returns (StreamModuleRegistration[] memory pending)
    {
        StreamModuleRegistration[] memory rows =
            StreamCanonicalNativeSalesDeployment.registrations(x.configuration, x.products);
        uint256 count;
        for (uint256 i; i < rows.length; ++i) {
            StreamModuleRecord memory actual = _registry(x).moduleRecord(rows[i].module);
            if (actual.status == ModuleRegistryStatus.UNKNOWN) rows[count++] = rows[i];
            else _requireRecord(actual, rows[i]);
        }
        pending = new StreamModuleRegistration[](count);
        for (uint256 i; i < count; ++i) {
            pending[i] = rows[i];
        }
    }

    function registrationBatch(Context memory x) internal view returns (GenesisBatch memory batch) {
        StreamModuleRegistration[] memory rows = pendingRegistrations(x);
        require(rows.length != 0, "companions already registered");
        batch.actionClass = 1;
        (batch.calls, batch.callDatas) =
            StreamCurrentStackPlan.registrationCalls(_registry(x), rows);
    }

    function requireRegistered(Context memory x) internal view {
        require(pendingRegistrations(x).length == 0, "companion registration incomplete");
    }

    /// @notice Enable only the reused Recorder, after its original prepared-settlement admission.
    /// @dev Register that existing Recorder through its original construction plan first.
    function recorderCredit(Context memory x) internal view returns (GenesisBatch memory) {
        _recorderRegistered(x);
        StreamRevenueEscrow escrow = _escrow(x);
        address recorder = address(x.configuration.immediate.recorder);
        (bool enabled,,) = escrow.creditProducer(recorder);
        require(!enabled, "Recorder credit already enabled");
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            escrow.creditProducerTransitionHashes(recorder, true);
        bytes memory data = abi.encodeCall(escrow.setCreditProducer, (recorder, true));
        return _single(
            StreamCurrentStackPlan.call(address(escrow), data, scope, oldHash, newHash), data
        );
    }

    /// @dev This establishes admission/credit only, not floor, royalty, entropy or mint readiness.
    /// Canonical immediate products do not need Manager's prepared Recorder/custody-house binding.
    function requireSettlementReady(Context memory x) internal view {
        requireRegistered(x);
        _recorderRegistered(x);
        (bool enabled, bytes32 hash,) =
            _escrow(x).creditProducer(address(x.configuration.immediate.recorder));
        require(
            enabled && hash == address(x.configuration.immediate.recorder).codehash,
            "Recorder escrow credit missing"
        );
    }

    /// @notice Preview the exact initial policy before obtaining Artist consent and owner execution.
    function configurePhase(Context memory x, Phase memory p)
        internal
        view
        returns (OwnerCall memory)
    {
        requireRegistered(x);
        StreamMintManager manager = _manager(x);
        _activeManager(x);
        (bool exists,) = manager.phase(p.collectionId, p.phaseId);
        require(!exists && p.collectionId != 0 && p.phaseId != 0, "fresh identified phase");
        require(!manager.phaseFrozen(p.collectionId, p.phaseId), "new mutable phase");
        require(!p.config.paused && p.config.maxBatchQuantity == 1, "ungated singleton phase");
        require(
            p.counterIds.length != 0 && p.counterIds.length <= 16
                && p.counterIds.length == p.counterConfigs.length,
            "explicit bounded counters"
        );
        IStreamMintManager.MintGateConfig memory gate;
        bytes32 policy = manager.previewPhasePolicyHash(
            p.collectionId,
            p.phaseId,
            p.config,
            gate,
            p.counterIds,
            p.counterConfigs,
            new address[](0)
        );
        bytes memory data = abi.encodeCall(
            manager.configurePhase,
            (p.collectionId, p.phaseId, p.config, gate, p.counterIds, p.counterConfigs)
        );
        return _owner(address(manager), data, _phaseState(x, p.collectionId, p.phaseId), policy);
    }

    /// @notice Add one admitted companion; each mutation needs consent for its resulting policy.
    /// @dev Observe execution before planning the next companion. Do not reuse an earlier policy.
    function phaseExecutor(Context memory x, uint8 index, uint256 collection, bytes32 phase)
        internal
        view
        returns (OwnerCall memory)
    {
        requireRegistered(x);
        _activeManager(x);
        StreamMintManager manager = _manager(x);
        address target = _product(x, index);
        (bool exists, IStreamMintManager.MintPhaseConfig memory config) =
            manager.phase(collection, phase);
        require(exists && !config.paused && config.maxBatchQuantity == 1, "mutable singleton phase");
        require(
            manager.phaseGate(collection, phase).gate == address(0), "canonical phase is ungated"
        );
        require(
            !manager.phaseFrozen(collection, phase)
                && !manager.phaseExecutor(collection, phase, target),
            "fresh phase executor"
        );
        address[] memory prior = manager.phaseExecutors(collection, phase);
        address[] memory next = new address[](prior.length + 1);
        for (uint256 i; i < prior.length; ++i) {
            next[i] = prior[i];
        }
        next[prior.length] = target;
        bytes32[] memory ids = manager.phaseCounterIds(collection, phase);
        IStreamMintManager.MintCounterConfig[] memory counters =
            _counters(manager, collection, phase, ids);
        bytes32 policy = manager.previewPhasePolicyHash(
            collection, phase, config, manager.phaseGate(collection, phase), ids, counters, next
        );
        bytes memory data =
            abi.encodeCall(manager.setPhaseExecutor, (collection, phase, target, true));
        return _owner(address(manager), data, _phaseState(x, collection, phase), policy);
    }

    function configureSigner(
        Context memory x,
        uint8 index,
        uint256 collection,
        address signer,
        uint8 kind,
        bytes32 evidence,
        bool enabled
    ) internal view returns (OwnerCall memory) {
        requireRegistered(x);
        require(
            collection != 0 && signer != address(0) && (kind == 1 || kind == 2) && evidence != 0,
            "explicit collection signer"
        );
        address target = _product(x, index);
        (IStreamNativeImmediateSales.SignerBinding memory binding, bool active) =
            IStreamNativeImmediateSales(target).collectionSigner(collection, signer, kind);
        bytes memory data = abi.encodeCall(
            IStreamNativeImmediateSales.configureCollectionSigner,
            (collection, signer, kind, evidence, enabled)
        );
        return _owner(target, data, keccak256(abi.encode(binding, active)), 0);
    }

    function registerImmediate(
        Context memory x,
        IStreamNativeImmediateSales.Configuration memory config
    ) internal view returns (OwnerCall memory) {
        return _registration(
            x, 0, config, abi.encodeCall(IStreamNativeImmediateSales.registerSale, (config))
        );
    }

    function registerClaim(Context memory x, IStreamNativeClaimSales.Configuration memory config)
        internal
        view
        returns (OwnerCall memory)
    {
        return _registration(
            x, 1, config.sale, abi.encodeCall(IStreamNativeClaimSales.registerSale, (config))
        );
    }

    function registerDutch(Context memory x, IStreamNativeDutchSales.Configuration memory config)
        internal
        view
        returns (OwnerCall memory)
    {
        return _registration(
            x, 2, config.sale, abi.encodeCall(IStreamNativeDutchSales.registerSale, (config))
        );
    }

    /// @notice Rebuild only to compare a saved owner intent, never to replace scheduled calldata.
    /// @dev Call immediately before submission/execution; ordinary owner methods do not enforce
    /// these offchain snapshots onchain. Artist consent and product checks execute at the target.
    function validateOwnerCall(Context memory x, OwnerCall memory saved) internal view {
        require(saved.call.value == 0 && saved.call.data.length >= 4, "zero-value owner call");
        bytes4 selector = bytes4(saved.call.data);
        bytes memory args = _arguments(saved.call.data);
        OwnerCall memory current;
        if (saved.call.target == address(_manager(x))) {
            if (selector == StreamMintManager.configurePhase.selector) {
                (
                    uint256 collection,
                    bytes32 phase,
                    IStreamMintManager.MintPhaseConfig memory config,
                    IStreamMintManager.MintGateConfig memory gate,
                    bytes32[] memory ids,
                    IStreamMintManager.MintCounterConfig[] memory counters
                ) = abi.decode(
                    args,
                    (
                        uint256,
                        bytes32,
                        IStreamMintManager.MintPhaseConfig,
                        IStreamMintManager.MintGateConfig,
                        bytes32[],
                        IStreamMintManager.MintCounterConfig[]
                    )
                );
                require(gate.gate == address(0), "ungated owner call");
                current = configurePhase(x, Phase(collection, phase, config, ids, counters));
            } else {
                require(
                    selector == StreamMintManager.setPhaseExecutor.selector,
                    "supported Manager call"
                );
                (uint256 collection, bytes32 phase, address product, bool allowed) =
                    abi.decode(args, (uint256, bytes32, address, bool));
                require(allowed, "additive executor call");
                current = phaseExecutor(x, _index(x, product), collection, phase);
            }
        } else {
            uint8 index = _index(x, saved.call.target);
            if (selector == IStreamNativeImmediateSales.configureCollectionSigner.selector) {
                (uint256 collection, address signer, uint8 kind, bytes32 evidence, bool enabled) =
                    abi.decode(args, (uint256, address, uint8, bytes32, bool));
                current = configureSigner(x, index, collection, signer, kind, evidence, enabled);
            } else if (index == 0 && selector == IStreamNativeImmediateSales.registerSale.selector)
            {
                current = registerImmediate(
                    x, abi.decode(args, (IStreamNativeImmediateSales.Configuration))
                );
            } else if (index == 1 && selector == IStreamNativeClaimSales.registerSale.selector) {
                current =
                    registerClaim(x, abi.decode(args, (IStreamNativeClaimSales.Configuration)));
            } else {
                require(
                    index == 2 && selector == IStreamNativeDutchSales.registerSale.selector,
                    "supported companion call"
                );
                current =
                    registerDutch(x, abi.decode(args, (IStreamNativeDutchSales.Configuration)));
            }
        }
        require(
            keccak256(abi.encode(current)) == keccak256(abi.encode(saved)),
            "owner plan state changed"
        );
    }

    /// @notice Wrap an actual Executor-owned call for its existing class1 policy route.
    /// @dev A Safe-owned target executes OwnerCall.call directly through that Safe instead.
    function governed(Context memory x, OwnerCall memory saved)
        internal
        view
        returns (GenesisBatch memory)
    {
        validateOwnerCall(x, saved);
        require(saved.call.caller == x.configuration.immediate.authority, "owner is not Executor");
        bytes memory data = saved.call.data;
        return _single(
            StreamCurrentStackPlan.call(
                saved.call.target,
                data,
                keccak256(abi.encode(saved.call.target, data)),
                0,
                keccak256(data)
            ),
            data
        );
    }

    /// @notice Ten exact optional catalog intents. No operating authority is automatically granted.
    function policies(Context memory x)
        internal
        view
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        StreamCanonicalNativeSalesDeployment.validate(x.configuration, x.products);
        rows = new GovernanceActionPolicyEntry[](10);
        rows[0] = _policy(x, address(_registry(x)), StreamModuleRegistry.registerModule.selector);
        rows[1] = _policy(x, address(_escrow(x)), StreamRevenueEscrow.setCreditProducer.selector);
        rows[2] = _policy(x, address(_manager(x)), StreamMintManager.configurePhase.selector);
        rows[3] = _policy(x, address(_manager(x)), StreamMintManager.setPhaseExecutor.selector);
        for (uint8 i; i < 3; ++i) {
            rows[4 + 2 * i] = _policy(
                x, _product(x, i), IStreamNativeImmediateSales.configureCollectionSigner.selector
            );
            rows[5 + 2 * i] = _policy(
                x,
                _product(x, i),
                i == 0
                    ? IStreamNativeImmediateSales.registerSale.selector
                    : i == 1
                        ? IStreamNativeClaimSales.registerSale.selector
                        : IStreamNativeDutchSales.registerSale.selector
            );
        }
        for (uint256 i = 1; i < rows.length; ++i) {
            for (uint256 j = i; j > 0 && _key(rows[j - 1]) > _key(rows[j]); --j) {
                (rows[j - 1], rows[j]) = (rows[j], rows[j - 1]);
            }
        }
    }

    /// @dev knownEntries comes from verified retained catalog history; the actual Executor is
    /// authoritative. Existing compatible entries retain their original profile commitments.
    function catalogAdditions(Context memory x, GovernanceActionPolicyEntry[] memory knownEntries)
        internal
        view
        returns (GovernanceActionPolicyEntry[] memory additions)
    {
        GovernanceActionPolicyEntry[] memory wanted = policies(x);
        uint256 count;
        for (uint256 i; i < wanted.length; ++i) {
            bool found;
            for (uint256 j; j < knownEntries.length; ++j) {
                GovernanceActionPolicyEntry memory prior = knownEntries[j];
                if (_key(prior) != _key(wanted[i])) continue;
                require(
                    !found && prior.targetCodeHash == wanted[i].targetCodeHash
                        && prior.targetProfileHash != 0 && prior.callType == 1
                        && prior.valuePolicy == 0 && prior.valueLimit == 0
                        && prior.valueSemanticsHash == 0,
                    "conflicting catalog entry"
                );
                found = true;
            }
            if (!found) wanted[count++] = wanted[i];
        }
        additions = new GovernanceActionPolicyEntry[](count);
        for (uint256 i; i < count; ++i) {
            additions[i] = wanted[i];
        }
    }

    function _registration(
        Context memory x,
        uint8 index,
        IStreamNativeImmediateSales.Configuration memory config,
        bytes memory data
    ) private view returns (OwnerCall memory) {
        requireSettlementReady(x);
        _activeManager(x);
        StreamMintManager manager = _manager(x);
        address target = _product(x, index);
        (bool exists, IStreamMintManager.MintPhaseConfig memory phase) =
            manager.phase(config.collectionId, config.phaseId);
        require(
            exists && !phase.paused && phase.maxBatchQuantity == 1
                && manager.phaseGate(config.collectionId, config.phaseId).gate == address(0)
                && manager.phaseExecutor(config.collectionId, config.phaseId, target),
            "active companion phase"
        );
        require(
            config.mintPolicyHash != 0
                && config.mintPolicyHash
                    == manager.phasePolicyHash(config.collectionId, config.phaseId),
            "observe final phase policy"
        );
        (IStreamNativeImmediateSales.SignerBinding memory signer, bool enabled) = IStreamNativeImmediateSales(
                target
            ).collectionSigner(config.collectionId, config.signer.authorizer, config.signer.kind);
        if (config.authorityMode == 1) {
            require(
                enabled && keccak256(abi.encode(config.signer)) == keccak256(abi.encode(signer)),
                "observe installed signer"
            );
        } else {
            require(
                config.authorityMode == 2
                    && keccak256(abi.encode(config.signer))
                        == keccak256(
                            abi.encode(
                                IStreamNativeImmediateSales.SignerBinding(
                                    address(0), 0, 0, 0, address(0)
                                )
                            )
                        ),
                "public sale has no signer"
            );
        }
        uint256 nonce = StreamNativeImmediateSales(payable(target)).nextSaleNonce();
        bytes32 stateHash = keccak256(
            abi.encode(_phaseState(x, config.collectionId, config.phaseId), signer, enabled, nonce)
        );
        return _owner(target, data, stateHash, config.mintPolicyHash);
    }

    function _phaseState(Context memory x, uint256 collection, bytes32 phase)
        private
        view
        returns (bytes32)
    {
        StreamMintManager manager = _manager(x);
        (bool exists, IStreamMintManager.MintPhaseConfig memory config) =
            manager.phase(collection, phase);
        bytes32[] memory ids = manager.phaseCounterIds(collection, phase);
        return keccak256(
            abi.encode(
                exists,
                config,
                manager.phaseGate(collection, phase),
                ids,
                _counters(manager, collection, phase, ids),
                manager.phaseExecutors(collection, phase),
                manager.phasePolicyHash(collection, phase),
                manager.phaseFrozen(collection, phase)
            )
        );
    }

    function _activeManager(Context memory x) private view {
        StreamMintManager manager = _manager(x);
        (address selected,,,,,,,,,) = IStreamCorePointers(address(manager.core()))
            .getSatellitePointer(keccak256("MINT_MANAGER"));
        require(selected == address(manager), "selected actual Manager");
        require(manager.mintLedger().ledgerWriter(address(manager)), "actual Ledger writer");
    }

    function _counters(
        StreamMintManager manager,
        uint256 collection,
        bytes32 phase,
        bytes32[] memory ids
    ) private view returns (IStreamMintManager.MintCounterConfig[] memory rows) {
        rows = new IStreamMintManager.MintCounterConfig[](ids.length);
        for (uint256 i; i < ids.length; ++i) {
            rows[i] = manager.counterConfig(collection, phase, ids[i]);
        }
    }

    function _recorderRegistered(Context memory x) private view {
        StreamCanonicalNativeSalesDeployment.validate(x.configuration, x.products);
        StreamPreparedNativeSettlementAdmission.captureRecorder(
            address(_registry(x)), address(x.configuration.immediate.recorder)
        );
    }

    function _manager(Context memory x) private pure returns (StreamMintManager) {
        return StreamMintManager(address(x.configuration.immediate.manager));
    }

    function _registry(Context memory x) private view returns (StreamModuleRegistry) {
        return StreamModuleRegistry(payable(x.configuration.immediate.recorder.moduleRegistry()));
    }

    function _escrow(Context memory x) private view returns (StreamRevenueEscrow) {
        return
            StreamRevenueEscrow(
                payable(address(x.configuration.immediate.recorder.revenueEscrow()))
            );
    }

    function _product(Context memory x, uint8 index) private pure returns (address) {
        require(index < 3, "companion index");
        return StreamCanonicalNativeSalesDeployment.addresses(x.products)[index];
    }

    function _index(Context memory x, address target) private pure returns (uint8) {
        for (uint8 i; i < 3; ++i) {
            if (_product(x, i) == target) return i;
        }
        revert("unknown companion");
    }

    function _owner(address target, bytes memory data, bytes32 stateHash, bytes32 policy)
        private
        view
        returns (OwnerCall memory)
    {
        return OwnerCall(
            StreamGovernanceStagePlan.NextCall(
                CanonicalNativeSalesOwner(target).owner(), target, 0, data
            ),
            stateHash,
            policy
        );
    }

    function _single(GovernanceCall memory operation, bytes memory data)
        private
        pure
        returns (GenesisBatch memory batch)
    {
        batch.actionClass = 1;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.calls[0] = operation;
        batch.callDatas[0] = data;
    }

    function _policy(Context memory x, address target, bytes4 selector)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            1,
            target,
            selector,
            target.codehash,
            keccak256(abi.encode(x.configuration.deploymentHash, target)),
            1,
            0,
            0,
            0
        );
    }

    function _key(GovernanceActionPolicyEntry memory row) private pure returns (bytes32) {
        return keccak256(abi.encode(row.actionClass, row.target, row.selector));
    }

    function _arguments(bytes memory data) private pure returns (bytes memory args) {
        args = new bytes(data.length - 4);
        for (uint256 i; i < args.length; ++i) {
            args[i] = data[i + 4];
        }
    }

    function _requireRecord(StreamModuleRecord memory r, StreamModuleRegistration memory e)
        private
        pure
    {
        require(
            r.status == ModuleRegistryStatus.ACTIVE && r.moduleType == e.moduleType
                && r.moduleVersion == e.moduleVersion && r.interfaceId == e.interfaceId
                && r.moduleGasLimit == e.moduleGasLimit
                && r.runtimeCodeHash == e.expectedRuntimeCodeHash
                && r.deploymentManifestHash == e.deploymentManifestHash
                && r.moduleManifestHash == e.moduleManifestHash
                && keccak256(bytes(r.moduleManifestURI)) == keccak256(bytes(e.moduleManifestURI))
                && r.revision != 0,
            "conflicting companion registration"
        );
    }
}
