// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamDutchSaleSupport.sol";
import "../revenue/StreamNativeSettlementAdmission.sol";

/// @notice Linked registration and reads in the guarded Dutch consumer's context.
/// @dev Fixed typed operations only. Mutable library CALL rejects; delegatecall preserves
///      the host's storage, caller and event address without adding another authority.
library StreamNativeDutchSaleWorker {
    struct Binding {
        address core;
        bytes32 coreHash;
        address registry;
        bytes32 registryHash;
        address resolver;
        bytes32 resolverHash;
        address factory;
        bytes32 factoryHash;
        address manager;
        bytes32 managerHash;
        address recorder;
        bytes32 recorderHash;
    }

    event SaleConfigured(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        uint8 saleKind,
        address asset,
        bytes32 saleConfigHash,
        bytes32 expectedPrimaryPolicyHash,
        uint8 primaryPolicyMode
    );
    event DutchSaleConfigured(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 saleNonce,
        bytes32 priceScheduleHash,
        bytes32 primaryAssignmentHash,
        IStreamNativeDutchSale.DutchSaleConfig config
    );
    event DutchAllowlistPricePolicy(
        bytes32 indexed saleId,
        bytes32 indexed counterId,
        uint16 schemaVersion,
        bool declaredFree,
        bytes32 saleConfigHash
    );

    function requireContext(Binding memory b) public view {
        StreamSettlementAdmission.requireRegistry(b.core, b.coreHash, b.registry, b.registryHash);
        if (
            b.resolver.codehash != b.resolverHash || b.factory.codehash != b.factoryHash
                || b.manager.codehash != b.managerHash || b.recorder.codehash != b.recorderHash
        ) revert IStreamNativeDutchSale.InvalidDutchSale();
    }

    function registerSale(
        mapping(bytes32 => IStreamNativeDutchSale.DutchSaleRecord) storage sales,
        mapping(
            bytes32 => bytes32
        ) storage counters,
        StreamDutchSaleSupport.Context memory context,
        address registry,
        IStreamNativeDutchSale.DutchSaleConfig memory config,
        bytes32 counterId,
        uint256 nonce
    ) public returns (bytes32 id) {
        (bytes32 baseline, bytes32 assignment) =
            StreamDutchSaleSupport.validateConfig(context, config);
        if (counterId != 0) {
            StreamMintSaleAllowlist.validatePolicy(
                address(context.manager), config.collectionId, config.phaseId, counterId
            );
        }
        StreamNativeSettlementTypes.SaleLifecycleBinding memory lifecycle =
            StreamNativeSettlementAdmission.capture(registry, address(this));
        // No external dependency reads occur after capture. The guarded host advances
        // the supplied nonce once this record and its original events are stored.
        id = saleIdFor(config.collectionId, config.phaseId, nonce);
        bytes32 schedule =
            StreamDutchPricing.scheduleHash(config.schedule, block.chainid, address(this), id);
        bytes32 hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_DUTCH_CONFIG_V1"),
                id,
                config,
                schedule,
                baseline,
                assignment,
                uint8(0),
                address(0)
            )
        );
        if (counterId != 0) {
            hash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_NATIVE_ALLOWLIST_DUTCH_CONFIG_V1"), hash, counterId
                )
            );
            counters[id] = counterId;
        }
        sales[id] = IStreamNativeDutchSale.DutchSaleRecord(
            config, nonce, hash, schedule, baseline, assignment, lifecycle, 0, false, false
        );
        emit SaleConfigured(
            1, id, config.collectionId, config.phaseId, 3, address(0), hash, baseline, 0
        );
        emit DutchSaleConfigured(1, id, nonce, schedule, assignment, config);
        if (counterId != 0) {
            emit DutchAllowlistPricePolicy(id, counterId, 1, config.declaredFree, hash);
        }
    }

    function saleIdFor(uint256 collectionId, bytes32 phaseId, uint256 nonce)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_V1"),
                block.chainid,
                address(this),
                uint8(3),
                collectionId,
                phaseId,
                nonce
            )
        );
    }

    function encodedSale(
        mapping(bytes32 => IStreamNativeDutchSale.DutchSaleRecord) storage sales,
        bytes32 id
    ) public view returns (bytes memory) {
        return abi.encode(sales[id]);
    }

    function currentPrice(
        mapping(bytes32 => IStreamNativeDutchSale.DutchSaleRecord) storage sales,
        bytes32 id
    ) public view returns (uint256) {
        if (sales[id].saleNonce == 0) {
            revert IStreamNativeDutchSale.DutchSaleUnavailable(id);
        }
        return StreamDutchPricing.price(sales[id].config.schedule, block.timestamp);
    }

    function prepare(
        mapping(bytes32 => IStreamNativeDutchSale.DutchSaleRecord) storage sales,
        mapping(
            bytes32 => bytes32
        ) storage counters,
        StreamDutchSaleSupport.Context memory context,
        IStreamNativeDutchSale.DutchPurchaseData memory data,
        bytes memory resolverData
    )
        public
        view
        returns (
            StreamNativeSettlementTypes.NativeSettlementCandidate memory candidate,
            IStreamMintManager.MintBatch memory batch,
            StreamDutchSaleSupport.Capture memory captured
        )
    {
        bytes32 id = data.authorization.saleId;
        bytes32 counterId = counters[id];
        if (counterId == 0) return StreamDutchSaleSupport.prepare(context, sales[id], data);
        return StreamDutchSaleSupport.prepareAllowlist(
            context, sales[id], data, counterId, resolverData
        );
    }
}
