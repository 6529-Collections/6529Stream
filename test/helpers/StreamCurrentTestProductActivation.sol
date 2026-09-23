// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { GenesisBatch } from "../../smart-contracts/interfaces/stream/governance/IStreamGenesisInitializer.sol";

import { StreamGovernanceExecutor } from "../../smart-contracts/domains/governance/StreamGovernanceExecutor.sol";
import { StreamCore } from "../../smart-contracts/core/StreamCore.sol";
import { StreamModuleRegistry } from "../../smart-contracts/domains/modules/StreamModuleRegistry.sol";
import { StreamSystemManifest } from "../../smart-contracts/domains/governance/StreamSystemManifest.sol";
import { StreamMintManager } from "../../smart-contracts/domains/mint/StreamMintManager.sol";
import { StreamMintLedger } from "../../smart-contracts/domains/mint/StreamMintLedger.sol";
import { StreamEntropyCoordinator } from "../../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol";
import { StreamMetadataRouter } from "../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import { StreamRoyaltyResolver } from "../../smart-contracts/domains/revenue/StreamRoyaltyResolver.sol";
import { IStreamArtistMintConsent } from "../../smart-contracts/interfaces/stream/artist/IStreamArtistMintConsent.sol";
import { StreamRevenueResolver } from "../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";
import { StreamRevenueEscrow } from "../../smart-contracts/domains/revenue/StreamRevenueEscrow.sol";
import { StreamFixedPriceSaleAdapter } from "../../smart-contracts/domains/mint/StreamFixedPriceSaleAdapter.sol";
import { StreamEnglishAuctionHouse } from "../../smart-contracts/domains/auctions/StreamEnglishAuctionHouse.sol";
import {
    StreamGovernanceActor
} from "../../smart-contracts/domains/governance/StreamGovernanceActor.sol";
import "../../smart-contracts/interfaces/stream/finality/IStreamArtworkFinalityRegistry.sol";
import "../../smart-contracts/interfaces/stream/governance/IStreamStateExportPublisher.sol";
import "../../script/current/StreamCurrentStackPlan.sol";
import { StreamEntropyLifecyclePlan } from "../../script/current/StreamEntropyLifecyclePlan.sol";
import { StreamGenesisManifestPlan } from "../../script/current/StreamGenesisManifestPlan.sol";
import {
    StreamGovernanceBootstrap
} from "../../smart-contracts/domains/governance/StreamGovernanceBootstrap.sol";
import {
    StreamGovernanceActionPolicy
} from "../../smart-contracts/domains/governance/StreamGovernanceActionPolicy.sol";
import { Strings } from "../../smart-contracts/vendor/openzeppelin/Strings.sol";

interface StreamCurrentTestActivationVm {
    function warp(uint256 timestamp) external;
}

/// @notice Fixed product-activation operations for current test fixtures.
/// @dev Linked library execution retains the fixture as outward caller and payload creator.
/// All identities are explicit typed inputs; fixture storage and virtual hooks stay in the host.
library StreamCurrentTestProductActivation {
    StreamCurrentTestActivationVm private constant vm =
        StreamCurrentTestActivationVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct Context {
        StreamGovernanceExecutor executor;
        StreamGovernanceActor governanceRoot;
        StreamCore core;
        StreamModuleRegistry registry;
        StreamSystemManifest manifest;
        StreamMintManager manager;
        StreamMintLedger ledger;
        StreamEntropyCoordinator entropy;
        address provider;
        StreamMetadataRouter router;
        StreamRoyaltyResolver royalties;
        IStreamArtistMintConsent artists;
        address finality;
        StreamRevenueResolver primaryResolver;
        StreamRevenueEscrow revenueEscrow;
        StreamFixedPriceSaleAdapter sale;
        StreamEnglishAuctionHouse auction;
        bytes32 profile;
        bytes32 deploymentHash;
        bytes32 registryHash;
        bytes32 finalityManifestHash;
        bytes32 primaryRevenueClass;
    }

    function registrations(Context calldata c)
        public
        view
        returns (StreamModuleRegistration[] memory records, GenesisBatch memory registrationBatch)
    {
        StreamModuleRegistration[] memory allRecords = _moduleRecords(c);
        // Foundation, Router and Artist were already admitted and selected in the first phase.
        records = new StreamModuleRegistration[](allRecords.length - 4);
        uint256 nextRecord;
        for (uint256 i = 2; i < allRecords.length; ++i) {
            if (i == 5 || i == 7) continue;
            records[nextRecord++] = allRecords[i];
        }
        require(nextRecord == records.length, "complete remaining product registration");
        registrationBatch.actionClass = 1;
        (GovernanceCall[] memory registrations, bytes[] memory registrationData) =
            StreamCurrentStackPlan.registrationCalls(c.registry, records);
        registrationBatch.calls = new GovernanceCall[](records.length + 2);
        registrationBatch.callDatas = new bytes[](records.length + 2);
        for (uint256 i; i < records.length; ++i) {
            registrationBatch.calls[i] = registrations[i];
            registrationBatch.callDatas[i] = registrationData[i];
        }
        (registrationBatch.calls[records.length], registrationBatch.callDatas[records.length]) =
            StreamEntropyLifecyclePlan.activate(
                c.entropy, address(c.provider), "urn:stream:genesis:entropy-provider"
            );
        bytes memory data = abi.encodeCall(
            c.entropy.configureCollection,
            (1, address(c.provider), keccak256("collection salt"), true, uint64(100))
        );
        registrationBatch.callDatas[records.length + 1] = data;
        registrationBatch.calls[records.length + 1] = _configurationCall(address(c.entropy), data);
    }

    function pointersAndConfiguration(
        Context calldata c,
        StreamModuleRegistration[] calldata records,
        address[] calldata extraProducers
    )
        public
        view
        returns (GenesisBatch memory pointerBatch, GenesisBatch memory configurationBatch)
    {
        configurationBatch.actionClass = 1;
        bytes memory data;
        configurationBatch.calls = new GovernanceCall[](7 + extraProducers.length);
        configurationBatch.callDatas = new bytes[](7 + extraProducers.length);
        data = abi.encodeCall(
            c.router.setCollectionMetadata,
            (
                1,
                "Stream Genesis",
                "Current stack integration",
                "ipfs://image",
                "https://example.invalid/art/"
            )
        );
        configurationBatch.callDatas[0] = data;
        configurationBatch.calls[0] = _configurationCall(address(c.router), data);
        data = abi.encodeCall(
            c.router.setCollectionScript, (1, "document.body.textContent=tokenHash;")
        );
        configurationBatch.callDatas[1] = data;
        configurationBatch.calls[1] = _configurationCall(address(c.router), data);
        data = abi.encodeCall(c.royalties.configureCollectionRoyalty, (1, c.profile, uint16(690)));
        configurationBatch.callDatas[2] = data;
        configurationBatch.calls[2] = _configurationCall(address(c.royalties), data);
        data = abi.encodeCall(
            c.primaryResolver.setPrimaryProfileAssignment,
            (c.primaryRevenueClass, uint8(1), 1, c.profile, bytes32(0))
        );
        configurationBatch.callDatas[3] = data;
        configurationBatch.calls[3] = _configurationCall(address(c.primaryResolver), data);
        (configurationBatch.calls[4], configurationBatch.callDatas[4]) =
            _escrowProducerCall(c, address(c.sale));
        (configurationBatch.calls[5], configurationBatch.callDatas[5]) =
            _escrowProducerCall(c, address(c.auction));
        for (uint256 i; i < extraProducers.length; ++i) {
            (configurationBatch.calls[6 + i], configurationBatch.callDatas[6 + i]) =
                _escrowProducerCall(c, extraProducers[i]);
        }

        data = abi.encodeCall(c.router.initializeOriginalFinalityAnchor, ());
        configurationBatch.callDatas[6 + extraProducers.length] = data;
        configurationBatch.calls[6 + extraProducers.length] =
            _configurationCall(address(c.router), data);

        bytes32[] memory installTypes = new bytes32[](records.length);
        for (uint256 i; i < records.length; ++i) {
            installTypes[i] = _pointerType(records[i].moduleType);
        }
        pointerBatch.actionClass = 3;
        (pointerBatch.calls, pointerBatch.callDatas) =
            StreamCurrentStackPlan.pointerCalls(c.core, c.registry, installTypes, records);
    }

    function admitPolicies(
        Context calldata c,
        GovernanceActionPolicyEntry[] calldata retained,
        uint64 expectedRevision,
        GovernanceActionPolicyEntry[] calldata operating,
        GenesisBatch[] calldata batches
    ) public returns (GovernanceActionPolicyEntry[] memory, uint64) {
        GovernanceActionPolicyEntry[] memory candidates = _actionPolicies(c, operating, batches);
        uint256 count;
        for (uint256 i; i < candidates.length; ++i) {
            bool exists;
            for (uint256 j; j < retained.length; ++j) {
                if (_policyKey(candidates[i]) != _policyKey(retained[j])) continue;
                require(
                    keccak256(abi.encode(candidates[i])) == keccak256(abi.encode(retained[j])),
                    "foundation policy cannot be rewritten"
                );
                exists = true;
                break;
            }
            if (!exists) candidates[count++] = candidates[i];
        }
        GovernanceActionPolicyEntry[] memory additions = new GovernanceActionPolicyEntry[](count);
        for (uint256 i; i < count; ++i) {
            additions[i] = candidates[i];
        }
        (bytes32 candidate, bytes32 catalog, uint256 existingCount, uint64 revision) =
            c.executor.governanceActionPolicyState();
        require(
            revision == expectedRevision && existingCount == retained.length,
            "exact original foundation catalog"
        );
        if (count == 0) return (additions, revision);
        (bytes32 next, bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamGovernanceActionPolicy.extensionTransition(
            address(c.executor), candidate, catalog, existingCount, revision, additions
        );
        GenesisBatch memory batch;
        batch.actionClass = 3;
        batch.calls = new GovernanceCall[](2);
        batch.callDatas = new bytes[](2);
        batch.callDatas[0] = abi.encodeCall(
            c.executor.extendGovernanceActionPolicy, (revision, catalog, next, additions)
        );
        batch.calls[0] = StreamCurrentStackPlan.call(
            address(c.executor), batch.callDatas[0], scope, oldHash, newHash
        );
        (batch.calls[1], batch.callDatas[1]) = _initialPublication(
            c, StreamGenesisManifestPlan.readAggregate(c.manifest).modules, next
        );
        _executeInitialBatch(c, batch);
        (, bytes32 appliedCatalog, uint256 appliedCount, uint64 appliedRevision) =
            c.executor.governanceActionPolicyState();
        require(
            appliedCatalog == next && appliedRevision == revision + 1
                && appliedCount == existingCount + count,
            "exact applied catalog extension"
        );
        return (additions, appliedRevision);
    }

    function initialProductPublication(Context calldata c, bytes32 reason)
        public
        returns (GovernanceCall memory call_, bytes memory data)
    {
        return _initialPublication(c, _initialProductModules(c), reason);
    }

    function publication(
        Context calldata c,
        StreamSystemManifest.ModuleAddresses memory modules,
        bytes32 reason
    ) public returns (GovernanceCall memory call_, bytes memory data) {
        return _initialPublication(c, modules, reason);
    }

    function executeBatch(Context calldata c, GenesisBatch memory batch) public {
        _executeInitialBatch(c, batch);
    }

    function _escrowProducerCall(Context calldata c, address producer)
        private
        view
        returns (GovernanceCall memory call_, bytes memory data)
    {
        (bytes32 scope, bytes32 oldState, bytes32 nextState) =
            c.revenueEscrow.creditProducerTransitionHashes(producer, true);
        data = abi.encodeCall(c.revenueEscrow.setCreditProducer, (producer, true));
        call_ =
            StreamCurrentStackPlan.call(address(c.revenueEscrow), data, scope, oldState, nextState);
    }

    function _moduleRecords(Context calldata c)
        private
        view
        returns (StreamModuleRegistration[] memory records)
    {
        records = new StreamModuleRegistration[](10);
        records[0] = _record(
            c,
            address(c.registry),
            keccak256("MODULE_REGISTRY"),
            type(IStreamModuleRegistry).interfaceId,
            c.registryHash
        );
        records[1] = _record(
            c,
            address(c.manifest),
            0x47fd79d5a6e9b1d75dcedf141a46e2e8f6d95d5a5be2b88f197fa98a1436fec6,
            type(IStreamSystemManifest).interfaceId,
            keccak256("fixture system manifest")
        );
        records[2] = _record(
            c,
            address(c.manager),
            keccak256("MINT_MANAGER"),
            type(IStreamMintManager).interfaceId,
            keccak256("fixture mint manager")
        );
        records[3] = _record(
            c,
            address(c.ledger),
            keccak256("MINT_LEDGER"),
            type(IStreamMintLedger).interfaceId,
            keccak256("fixture mint ledger")
        );
        records[4] = _record(
            c,
            address(c.entropy),
            keccak256("ENTROPY_COORDINATOR"),
            type(IStreamEntropyCoordinator).interfaceId,
            keccak256("fixture entropy module")
        );
        records[5] = _record(
            c,
            address(c.router),
            keccak256("METADATA_ROUTER"),
            type(IStreamMetadataRouter).interfaceId,
            keccak256("fixture metadata module")
        );
        records[6] = _record(
            c,
            address(c.royalties),
            keccak256("REVENUE_RESOLVER"),
            type(IStreamRoyaltyResolver).interfaceId,
            keccak256("fixture royalty module")
        );
        records[7] = _record(
            c,
            address(c.artists),
            keccak256("ARTIST_REGISTRY"),
            type(IStreamArtistMintConsent).interfaceId,
            keccak256("fixture artist module")
        );
        records[8] = _record(
            c,
            address(c.executor),
            keccak256("GOVERNANCE_LAYER"),
            type(IStreamStateExportPublisher).interfaceId,
            keccak256("fixture state export publisher")
        );
        records[9] = _record(
            c,
            address(c.finality),
            keccak256("ARTWORK_FINALITY_REGISTRY"),
            type(IStreamArtworkFinalityRegistry).interfaceId,
            c.finalityManifestHash
        );
    }

    function _pointerType(bytes32 moduleType) private pure returns (bytes32) {
        if (moduleType == 0x47fd79d5a6e9b1d75dcedf141a46e2e8f6d95d5a5be2b88f197fa98a1436fec6) {
            return keccak256("SYSTEM_MANIFEST");
        }
        if (moduleType == keccak256("REVENUE_RESOLVER")) return keccak256("ROYALTY_RESOLVER");
        if (moduleType == keccak256("GOVERNANCE_LAYER")) {
            return keccak256("STATE_EXPORT_PUBLISHER");
        }
        return moduleType;
    }

    function _record(
        Context calldata c,
        address module,
        bytes32 moduleType,
        bytes4 interfaceId,
        bytes32 moduleHash
    ) private view returns (StreamModuleRegistration memory) {
        return StreamModuleRegistration(
            module,
            moduleType,
            keccak256("fixture v1"),
            interfaceId,
            500_000,
            module.codehash,
            c.deploymentHash,
            moduleHash,
            "urn:6529stream:fixture:module"
        );
    }

    function _configurationCall(address target, bytes memory data)
        private
        pure
        returns (GovernanceCall memory)
    {
        return StreamCurrentStackPlan.call(
            target, data, keccak256(abi.encode(target, data)), bytes32(0), keccak256(data)
        );
    }

    function _initialProductModules(Context calldata c)
        private
        view
        returns (StreamSystemManifest.ModuleAddresses memory modules)
    {
        modules = StreamGenesisManifestPlan.readAggregate(c.manifest).modules;
        modules.artistRegistry = address(c.artists);
        modules.artworkFinalityRegistry = address(c.finality);
        modules.revenueResolver = address(c.royalties);
        modules.metadataRouter = address(c.router);
        modules.entropyCoordinator = address(c.entropy);
        modules.mintManager = address(c.manager);
        modules.mintLedger = address(c.ledger);
        modules.streamAdminsOrGovernance = address(c.executor);
        modules.moduleRegistry = address(c.registry);
        modules.stateExportPublisher = address(c.executor);
    }

    function _initialPublication(
        Context calldata c,
        StreamSystemManifest.ModuleAddresses memory modules,
        bytes32 reason
    ) private returns (GovernanceCall memory call_, bytes memory data) {
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(c.manifest);
        (address payload, bytes32 hash) = StreamGenesisManifestPlan.writePayload(
            abi.encodePacked(
                "{\"purpose\":\"current product activation\",\"commitment\":\"",
                Strings.toHexString(uint256(reason), 32),
                "\"}"
            )
        );
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            hash,
            "urn:6529stream:current-stack:products",
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
        return StreamGenesisManifestPlan.publicationCall(c.manifest, payload, update, modules);
    }

    function _executeInitialBatch(Context calldata c, GenesisBatch memory batch) private {
        c.executor.publishGovernanceCallData(batch.callDatas);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            batch.calls, StreamGovernanceBootstrap.governanceCallsHash(batch.calls)
        );
        uint64 ready = uint64(block.timestamp + c.executor.minimumDelay(batch.actionClass));
        bytes memory result = c.governanceRoot
            .execute(
                address(c.executor),
                0,
                abi.encodeCall(
                    c.executor.scheduleGovernanceBatch,
                    (
                        batch.actionClass,
                        batch.calls,
                        scope,
                        oldHash,
                        newHash,
                        ready,
                        ready + 7 days,
                        keccak256("initial product activation"),
                        "urn:6529stream:fixture:product-activation",
                        c.deploymentHash
                    )
                )
            );
        vm.warp(ready);
        c.executor
            .executeGovernanceBatch(abi.decode(result, (bytes32)), batch.calls, batch.callDatas);
    }

    function _actionPolicies(
        Context calldata c,
        GovernanceActionPolicyEntry[] calldata operating,
        GenesisBatch[] calldata batches
    ) private view returns (GovernanceActionPolicyEntry[] memory policies) {
        uint256 capacity = operating.length;
        for (uint256 i; i < batches.length; ++i) {
            capacity += batches[i].calls.length;
        }
        GovernanceActionPolicyEntry[] memory candidates =
            new GovernanceActionPolicyEntry[](capacity);
        uint256 count = operating.length;
        for (uint256 i; i < count; ++i) {
            candidates[i] = operating[i];
        }
        for (uint256 i; i < batches.length; ++i) {
            for (uint256 j; j < batches[i].calls.length; ++j) {
                GovernanceCall memory operation = batches[i].calls[j];
                bytes32 key = keccak256(
                    abi.encode(batches[i].actionClass, operation.target, operation.selector)
                );
                bool duplicate;
                for (uint256 k; k < count; ++k) {
                    if (
                        keccak256(
                                abi.encode(
                                    candidates[k].actionClass,
                                    candidates[k].target,
                                    candidates[k].selector
                                )
                            ) == key
                    ) duplicate = true;
                }
                if (!duplicate) {
                    candidates[count++] = GovernanceActionPolicyEntry(
                        batches[i].actionClass,
                        operation.target,
                        operation.selector,
                        operation.target.codehash,
                        keccak256(abi.encode(c.deploymentHash, operation.target)),
                        1,
                        0,
                        0,
                        bytes32(0)
                    );
                }
            }
        }
        policies = new GovernanceActionPolicyEntry[](count);
        for (uint256 i; i < count; ++i) {
            policies[i] = candidates[i];
        }
        for (uint256 i = 1; i < count; ++i) {
            for (
                uint256 j = i; j > 0 && _policyKey(policies[j - 1]) > _policyKey(policies[j]); --j) {
                (policies[j - 1], policies[j]) = (policies[j], policies[j - 1]);
            }
        }
    }

    function _policyKey(GovernanceActionPolicyEntry memory policy) private pure returns (bytes32) {
        return keccak256(abi.encode(policy.actionClass, policy.target, policy.selector));
    }
}
