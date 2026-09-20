// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFullV1Candidate.sol";
import "./StreamNativeCommerceGovernancePlan.sol";
import "./StreamGovernanceCatalogStagePlan.sol";
import "./StreamEntropyLifecyclePlan.sol";
import { IStreamModule } from "../../smart-contracts/interfaces/stream/modules/IStreamModule.sol";
import {
    IStreamERC20PrimarySettlementAdapter
} from "../../smart-contracts/interfaces/stream/revenue/IStreamERC20PrimarySettlementAdapter.sol";

/// @notice Observed-state activation intents for the retained original 37-role construction.
/// @dev No scheduling, schema invention, role grants, pointer replacement or readiness claim.
/// Save each returned batch with StreamGovernanceStagePlan before proposing it through the root.
library StreamFullV1ActivationPlan {
    struct Context {
        StreamFullV1Candidate.Foundation foundation;
        StreamFullV1Candidate.Configuration configuration;
        StreamFullV1Candidate.Products products;
        bytes32 inventoryHash;
    }

    struct Manifest {
        bytes32 hash;
        string uri;
    }

    struct RegistrationInputs {
        uint32 gateGas;
        uint32 readGas;
        uint32 commerceGas;
        uint32 providerGas;
        Manifest fixedSale;
        Manifest dutch;
        Manifest privateSale;
        Manifest erc20;
    }

    struct Publication {
        address payload;
        StreamSystemManifestUpdate update;
    }

    function validate(Context memory x) internal view {
        StreamFullV1Candidate.requireUnchanged(
            x.foundation, x.configuration, x.products, x.inventoryHash
        );
        require(
            x.foundation.ledger.owner() == address(x.foundation.executor), "actual Ledger owner"
        );
        (bool ok, bytes memory raw) = address(x.foundation.executor)
            .staticcall(abi.encodeCall(IStreamGovernanceExecutor.systemManifestBootstrapState, ()));
        require(ok, "bootstrap read");
        StreamGovernanceManifest.BootstrapStateView memory b =
            abi.decode(raw, (StreamGovernanceManifest.BootstrapStateView));
        require(
            b.bound && b.isSealed && b.systemManifestSatellite == address(x.foundation.manifest),
            "original sealed manifest"
        );
    }

    /// @notice 21 genuine ERC165 rows; ordinary construction companions get no invented kinds.
    /// @dev Gas inputs are explicit proposed budgets, not measured launch defaults.
    function registrations(Context memory x, RegistrationInputs memory input)
        internal
        view
        returns (StreamModuleRegistration[] memory rows)
    {
        validate(x);
        require(
            input.gateGas != 0 && input.readGas != 0 && input.commerceGas != 0
                && input.providerGas != 0,
            "explicit read budgets"
        );
        rows = new StreamModuleRegistration[](21);
        uint256 n;
        n = _copy(
            rows,
            n,
            StreamFullV1GenesisProducts.registrations(
                x.configuration.independent, x.products.independent, input.gateGas, input.readGas
            )
        );
        n = _copy(
            rows,
            n,
            StreamFullV1RecordProducts.registrations(
                x.configuration.records, x.products.records, input.readGas
            )
        );
        n = _copy(
            rows,
            n,
            StreamFullV1StaticRendererPlan.registrations(
                x.configuration.rendering, x.products.rendering, input.readGas
            )
        );
        StreamModuleRegistration[] memory pair =
            StreamNativeCommerceDeployment.registrations(x.products.commerce.native);
        pair[0].moduleGasLimit = input.commerceGas;
        pair[1].moduleGasLimit = input.commerceGas;
        n = _copy(rows, n, pair);
        StreamFullV1CommerceProducts.Products memory p = x.products.commerce;
        bytes32 deployment = x.configuration.commerce.deploymentHash;
        bytes32 universal = keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1");
        if (p.fixedSale.refundDelegationConfiguration().registry != address(0)) {
            require(
                input.fixedSale.hash == p.fixedSale.refundDelegationManifestHash(),
                "fixed delegation manifest"
            );
        }
        if (p.dutch.refundDelegationConfiguration().registry != address(0)) {
            require(
                input.dutch.hash == p.dutch.refundDelegationManifestHash(),
                "Dutch delegation manifest"
            );
        }
        if (p.privateSale.delegateRegistry() != address(0)) {
            require(
                input.privateSale.hash == keccak256(p.privateSale.delegationManifest()),
                "private delegation manifest"
            );
        }
        rows[n++] = _row(
            address(p.fixedSale),
            p.fixedSale.streamModuleType(),
            universal,
            p.fixedSale.streamModuleInterfaceId(),
            input.commerceGas,
            deployment,
            input.fixedSale
        );
        rows[n++] = _row(
            address(p.dutch),
            p.dutch.streamModuleType(),
            universal,
            p.dutch.streamModuleInterfaceId(),
            input.commerceGas,
            deployment,
            input.dutch
        );
        rows[n++] = _row(
            address(p.privateSale),
            p.privateSale.streamModuleType(),
            p.privateSale.streamModuleVersion(),
            p.privateSale.streamModuleInterfaceId(),
            input.commerceGas,
            deployment,
            input.privateSale
        );
        rows[n++] = _module(IStreamModule(address(p.burn)), input.gateGas);
        rows[n++] = _row(
            address(p.erc20),
            keccak256("ERC20_PRIMARY_SETTLEMENT_ADAPTER"),
            universal,
            type(IStreamERC20PrimarySettlementAdapter).interfaceId,
            input.commerceGas,
            deployment,
            input.erc20
        );
        n = _copy(
            rows,
            n,
            StreamFullV1ContinuityProducts.registrations(
                x.configuration.continuity, x.products.continuity
            )
        );
        rows[n++] = _module(IStreamModule(address(x.products.vrf)), input.providerGas);
        rows[n++] = _module(IStreamModule(address(x.products.arrng)), input.providerGas);
        assert(n == rows.length);
    }

    /// @notice Preserve exact ACTIVE rows; a different version, budget, manifest or status rejects.
    function pendingRegistrations(Context memory x, RegistrationInputs memory input)
        internal
        view
        returns (StreamModuleRegistration[] memory pending)
    {
        StreamModuleRegistration[] memory all = registrations(x, input);
        uint256 n;
        for (uint256 i; i < all.length; ++i) {
            StreamModuleRecord memory actual = x.foundation.registry.moduleRecord(all[i].module);
            if (actual.status == ModuleRegistryStatus.UNKNOWN) all[n++] = all[i];
            else _requireRecord(actual, all[i]);
        }
        pending = new StreamModuleRegistration[](n);
        for (uint256 i; i < n; ++i) {
            pending[i] = all[i];
        }
    }

    /// @notice Bound the next registration chunk; rebuild only after observing its predecessor.
    function registrationBatch(
        Context memory x,
        RegistrationInputs memory input,
        uint256 maxRows,
        Publication memory publication
    ) internal view returns (GenesisBatch memory batch) {
        StreamModuleRegistration[] memory pending = pendingRegistrations(x, input);
        require(
            maxRows > 0 && maxRows <= 21 && pending.length > 0, "nonempty bounded registrations"
        );
        uint256 count = pending.length < maxRows ? pending.length : maxRows;
        StreamModuleRegistration[] memory next = new StreamModuleRegistration[](count);
        for (uint256 i; i < count; ++i) {
            next[i] = pending[i];
        }
        batch.actionClass = 1;
        (batch.calls, batch.callDatas) =
            StreamCurrentStackPlan.registrationCalls(x.foundation.registry, next);
        return withManifestTail(x, batch, publication);
    }

    function requireRegistered(Context memory x, RegistrationInputs memory input) internal view {
        require(pendingRegistrations(x, input).length == 0, "candidate module admission incomplete");
    }

    /// @dev Museum supplies canonical specs and ordered chunk hashes after publishing exact
    /// bytes to the original store. This helper neither creates nor blesses a definition.
    function schemaDocument(
        Context memory x,
        IStreamSchemaRegistry.DocumentSpec memory spec,
        bytes32[] memory chunks
    ) internal view returns (GenesisBatch memory) {
        validate(x);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            x.foundation.schemas.registrationTransition(spec, chunks);
        bytes memory data = abi.encodeCall(x.foundation.schemas.registerDocument, (spec, chunks));
        return _single(
            1,
            StreamCurrentStackPlan.call(
                address(x.foundation.schemas), data, scope, oldHash, newHash
            ),
            data
        );
    }

    /// @dev C supplies actual retained analysis/read inventory and reviewed goldens. A constructed
    /// renderer and a prospective manifest hash do not satisfy this target-side transition.
    function staticAdmission(
        Context memory x,
        V.Registration memory registration,
        V.Read[] memory reads
    ) internal view returns (GenesisBatch memory) {
        validate(x);
        (GovernanceCall memory operation, bytes memory data) = StreamFullV1StaticRendererPlan.admission(
            x.configuration.rendering, x.products.rendering, registration, reads
        );
        return _single(1, operation, data);
    }

    function familyWriter(
        Context memory x,
        uint256 collectionId,
        bytes32 family,
        uint8 authClass,
        address writer,
        bool enabled
    ) internal view returns (GenesisBatch memory) {
        validate(x);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = x.foundation.metadata
            .familyWriterTransition(collectionId, family, authClass, writer, enabled);
        bytes memory data = abi.encodeCall(
            x.foundation.metadata.setFamilyWriter,
            (collectionId, family, authClass, writer, enabled)
        );
        return _single(
            1,
            StreamCurrentStackPlan.call(
                address(x.foundation.metadata), data, scope, oldHash, newHash
            ),
            data
        );
    }

    /// @dev Record type/family/class masks are supplied reviewed inputs, never inferred from a schema name.
    function recordType(Context memory x, bytes32 typeId, bytes32 family, uint16 mask)
        internal
        view
        returns (GenesisBatch memory)
    {
        validate(x);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            x.foundation.metadata.recordTypeTransition(typeId, family, mask);
        bytes memory data =
            abi.encodeCall(x.foundation.metadata.admitRecordType, (typeId, family, mask));
        return _single(
            1,
            StreamCurrentStackPlan.call(
                address(x.foundation.metadata), data, scope, oldHash, newHash
            ),
            data
        );
    }

    /// @notice Same-class publication of supplied bytes against the current manifest revision.
    /// @dev Only non-pointer intents from this helper use this path; modules remain unchanged.
    function withManifestTail(
        Context memory x,
        GenesisBatch memory intent,
        Publication memory publication
    ) internal view returns (GenesisBatch memory batch) {
        validate(x);
        require(
            intent.calls.length > 0 && intent.calls.length == intent.callDatas.length,
            "nonempty intent"
        );
        require(
            publication.payload.code.length != 0 && publication.update.manifestHash != 0,
            "retained publication"
        );
        batch.actionClass = intent.actionClass;
        batch.calls = new GovernanceCall[](intent.calls.length + 1);
        batch.callDatas = new bytes[](intent.calls.length + 1);
        for (uint256 i; i < intent.calls.length; ++i) {
            // Pointer changes need their original predicted module-address transition planner.
            require(
                intent.calls[i].target != address(x.foundation.core)
                    && intent.calls[i].target != address(x.foundation.executor)
                    && intent.calls[i].target != address(x.foundation.manifest),
                "use original pointer or isolated self-call planner"
            );
            batch.calls[i] = intent.calls[i];
            batch.callDatas[i] = intent.callDatas[i];
        }
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(x.foundation.manifest);
        (batch.calls[intent.calls.length], batch.callDatas[intent.calls.length]) =
            StreamGenesisManifestPlan.publicationCall(
                x.foundation.manifest, publication.payload, publication.update, current.modules
            );
    }

    function recorderCredit(Context memory x) internal view returns (GenesisBatch memory batch) {
        validate(x);
        _active(
            x,
            address(x.products.commerce.native.recorder),
            keccak256("PRIMARY_SALE_SETTLEMENT"),
            type(IStreamPreparedNativePrimarySaleSettlement).interfaceId
        );
        address recorder = address(x.products.commerce.native.recorder);
        (bool enabled,,) = x.foundation.escrow.creditProducer(recorder);
        require(!enabled, "credit producer already enabled");
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            x.foundation.escrow.creditProducerTransitionHashes(recorder, true);
        bytes memory data = abi.encodeCall(x.foundation.escrow.setCreditProducer, (recorder, true));
        return _single(
            1,
            StreamCurrentStackPlan.call(
                address(x.foundation.escrow), data, scope, oldHash, newHash
            ),
            data
        );
    }

    function custodyBinding(Context memory x) internal view returns (GenesisBatch memory) {
        validate(x);
        return StreamNativeCommerceGovernancePlan.custodyBinding(x.products.commerce.native);
    }

    /// @dev Primary and reserve bind separately, after the original recorder admission and credit.
    function managerBinding(Context memory x, bool reserve)
        internal
        view
        returns (GenesisBatch memory)
    {
        validate(x);
        if (!reserve) {
            return StreamNativeCommerceGovernancePlan.managerBinding(x.products.commerce.native);
        }
        _active(
            x,
            address(x.products.continuity.manager),
            keccak256("MINT_MANAGER"),
            type(IStreamMintManager).interfaceId
        );
        // The primary planner authenticates recorder/escrow state but also requires an unbound primary.
        // The common original admission library supplies the same recorder check for this reserve.
        StreamPreparedNativeSettlementAdmission.captureRecorder(
            address(x.foundation.registry), address(x.products.commerce.native.recorder)
        );
        (bool enabled, bytes32 hash,) =
            x.foundation.escrow.creditProducer(address(x.products.commerce.native.recorder));
        require(
            enabled && hash == address(x.products.commerce.native.recorder).codehash,
            "original escrow credit"
        );
        (address bound,,,) = x.products.continuity.manager.preparedNativeRecorder();
        require(
            bound == address(0)
                && x.products.continuity.manager.owner() == address(x.foundation.executor),
            "unbound reserve owned by Executor"
        );
        bytes memory data = abi.encodeCall(
            x.products.continuity.manager.bindPreparedNativeRecorder,
            (address(x.products.commerce.native.recorder))
        );
        return _ordinary(address(x.products.continuity.manager), data);
    }

    function reserveWriter(Context memory x) internal view returns (GenesisBatch memory) {
        validate(x);
        address backup = address(x.products.continuity.manager);
        _active(x, backup, keccak256("MINT_MANAGER"), type(IStreamMintManager).interfaceId);
        require(
            !x.foundation.ledger.ledgerWriter(backup)
                && x.foundation.ledger.ledgerWriterRetiredAt(backup) == 0,
            "fresh reserve writer"
        );
        bytes memory data = abi.encodeCall(x.foundation.ledger.setLedgerWriter, (backup, true));
        return _ordinary(address(x.foundation.ledger), data);
    }

    /// @notice Classifier must remain an isolated class1 Executor self-call, without a tail.
    function retirementClassifier(Context memory x) internal view returns (GenesisBatch memory) {
        validate(x);
        (GovernanceCall memory operation, bytes memory data) = StreamMintFallbackPlan.retirementClassificationCall(
            StreamFullV1ContinuityProducts.mintConfiguration(
                x.configuration.continuity, x.products.continuity
            )
        );
        return _single(1, operation, data);
    }

    /// @dev Each provider retirement selector needs its own isolated classifier action as well
    /// as its exact class0 catalog row. Classification itself does not retire a provider.
    function providerClassifier(Context memory x, bool reserve, bool revoke)
        internal
        view
        returns (GenesisBatch memory)
    {
        validate(x);
        address coordinator =
            reserve ? address(x.products.continuity.entropy) : address(x.foundation.entropy);
        bytes4 selector = revoke
            ? IStreamEntropyProviderLifecycle.revokeEntropyProvider.selector
            : IStreamEntropyProviderLifecycle.deprecateEntropyProvider.selector;
        return StreamEntropyLifecyclePlan.admitTightening(
            IStreamGovernanceExecutor(address(x.foundation.executor)), coordinator, selector
        );
    }

    /// @notice Each original provider is activated only on its own Coordinator, after registration.
    function providerActivation(Context memory x, uint8 providerIndex, string memory reason)
        internal
        view
        returns (GenesisBatch memory)
    {
        validate(x);
        (StreamEntropyCoordinator coordinator, address provider) = providerPair(x, providerIndex);
        _active(
            x, provider, keccak256("ENTROPY_PROVIDER"), type(IStreamEntropyProvider).interfaceId
        );
        _active(
            x,
            address(coordinator),
            keccak256("ENTROPY_COORDINATOR"),
            type(IStreamEntropyCoordinator).interfaceId
        );
        (GovernanceCall memory operation, bytes memory data) = StreamEntropyLifecyclePlan.activate(
            IStreamEntropyProviderLifecycle(address(coordinator)), provider, reason
        );
        return _single(1, operation, data);
    }

    function providerPair(Context memory x, uint8 index)
        internal
        pure
        returns (StreamEntropyCoordinator, address)
    {
        require(index < 3, "original provider index");
        if (index == 2) {
            return (x.products.continuity.entropy, address(x.products.continuity.provider));
        }
        return
            (x.foundation.entropy, index == 0 ? address(x.products.vrf) : address(x.products.arrng));
    }

    function collectionConfiguration(
        Context memory x,
        uint8 providerIndex,
        StreamEntropyFallbackPlan.Collection memory row
    ) internal view returns (GenesisBatch memory) {
        validate(x);
        (StreamEntropyCoordinator coordinator, address provider) = providerPair(x, providerIndex);
        require(row.id != 0 && row.provider == provider, "exact original collection provider");
        require(
            x.foundation.core.collectionExists(row.id)
                && !x.foundation.core.collectionFreezeStatus(row.id),
            "existing mutable collection"
        );
        (,, bool locked,,,,) = coordinator.collectionEntropyConfig(row.id);
        require(!locked, "collection entropy locked");
        _active(
            x, provider, keccak256("ENTROPY_PROVIDER"), type(IStreamEntropyProvider).interfaceId
        );
        _active(
            x,
            address(coordinator),
            keccak256("ENTROPY_COORDINATOR"),
            type(IStreamEntropyCoordinator).interfaceId
        );
        // Target-side lifecycle getter rejects inactive/provider-runtime drift before planning.
        IStreamEntropyProviderLifecycle.ProviderRecord memory record =
            coordinator.entropyProviderRecord(provider);
        require(
            record.state == EntropyProviderState.ACTIVE
                && record.runtimeCodeHash == provider.codehash,
            "activate provider first"
        );
        (GovernanceCall memory operation, bytes memory data) =
            StreamEntropyFallbackPlan.configureCollection(coordinator, row);
        return _single(1, operation, data);
    }

    function revealConfiguration(
        Context memory x,
        uint8 providerIndex,
        StreamEntropyFallbackPlan.Collection memory row,
        address administrator
    ) internal view returns (StreamGovernanceStagePlan.NextCall memory) {
        validate(x);
        (StreamEntropyCoordinator coordinator, address provider) = providerPair(x, providerIndex);
        require(row.provider == provider && row.id != 0, "exact reveal collection provider");
        (address actual, bool publicRequests, bool locked, uint64 timeout,,, bytes32 salt) =
            coordinator.collectionEntropyConfig(row.id);
        require(
            actual == provider && publicRequests == row.publicRequests
                && timeout == row.timeoutBlocks && salt == row.salt && !locked,
            "observe collection configuration first"
        );
        require(
            row.requestMode <= 1 && row.revealOwnerRole == keccak256("ROLE_ENTROPY_REVEAL_OWNER")
                && row.requestSLOBlocks != 0,
            "original reveal policy fields"
        );
        return StreamEntropyFallbackPlan.revealConfiguration(coordinator, row, administrator);
    }

    function _active(Context memory x, address target, bytes32 kind, bytes4 interfaceId)
        private
        view
    {
        require(
            x.foundation.registry.isModuleEligible(target, kind, interfaceId),
            "original ACTIVE registration"
        );
    }

    function _ordinary(address target, bytes memory data)
        private
        pure
        returns (GenesisBatch memory)
    {
        return _single(
            1,
            StreamCurrentStackPlan.call(
                target, data, keccak256(abi.encode(target, data)), 0, keccak256(data)
            ),
            data
        );
    }

    function _single(uint8 cls, GovernanceCall memory operation, bytes memory data)
        private
        pure
        returns (GenesisBatch memory batch)
    {
        batch.actionClass = cls;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.calls[0] = operation;
        batch.callDatas[0] = data;
    }

    function _copy(
        StreamModuleRegistration[] memory dst,
        uint256 offset,
        StreamModuleRegistration[] memory src
    ) private pure returns (uint256) {
        for (uint256 i; i < src.length; ++i) {
            dst[offset++] = src[i];
        }
        return offset;
    }

    function _module(IStreamModule host, uint32 gasLimit)
        private
        view
        returns (StreamModuleRegistration memory)
    {
        (string memory uri, bytes32 hash) = host.streamModuleManifest();
        return _row(
            address(host),
            host.streamModuleType(),
            host.streamModuleVersion(),
            host.streamModuleInterfaceId(),
            gasLimit,
            host.streamModuleDeploymentManifestHash(),
            Manifest(hash, uri)
        );
    }

    function _row(
        address target,
        bytes32 kind,
        bytes32 version,
        bytes4 interfaceId,
        uint32 gasLimit,
        bytes32 deployment,
        Manifest memory manifest
    ) private view returns (StreamModuleRegistration memory) {
        require(
            manifest.hash != 0 && bytes(manifest.uri).length != 0
                && bytes(manifest.uri).length <= 2048,
            "explicit module manifest"
        );
        return StreamModuleRegistration(
            target,
            kind,
            version,
            interfaceId,
            gasLimit,
            target.codehash,
            deployment,
            manifest.hash,
            manifest.uri
        );
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
            "conflicting candidate registration"
        );
    }
}
