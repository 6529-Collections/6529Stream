// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamClearingSaleState.sol";
import "./StreamClearingUnlock.sol";
import "../revenue/StreamNativeSettlementAdmission.sol";

/// @notice Fixed registration worker; the guarded host supplies its storage and original nonce.
/// @dev No independent owner or storage. Linked calls preserve original consumer and caller.
library StreamClearingSaleRegistration {
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
    event ClearingSaleConfigured(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 saleNonce,
        bytes32 priceScheduleHash,
        bytes32 windowPolicyHash,
        IStreamNativeClearingSale.ClearingSaleConfig config
    );

    function register(
        StreamClearingSaleState.State storage state,
        StreamClearingSaleState.Context memory x,
        IStreamNativeClearingSale.ClearingSaleConfig memory config,
        uint256 nonce,
        bytes32 priceCounterId
    ) public returns (bytes32 id) {
        _requireContext(x);
        if (priceCounterId != 0) {
            StreamMintSaleAllowlist.validatePolicy(
                address(x.support.manager), config.collectionId, config.phaseId, priceCounterId
            );
        }
        bytes32 baseline = StreamClearingSaleSupport.validateConfig(x.support, config);
        StreamNativeSettlementTypes.SaleLifecycleBinding memory lifecycle =
            StreamNativeSettlementAdmission.capture(x.registry, address(this));
        id = keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_V1"),
                block.chainid,
                address(this),
                uint8(4),
                config.collectionId,
                config.phaseId,
                nonce
            )
        );
        bytes32 schedule =
            StreamDutchPricing.scheduleHash(config.schedule, block.chainid, address(this), id);
        bytes32 windows = StreamClearingSaleSupport.windowPolicyHash(config);
        bytes32 hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CLEARING_CONFIG_V1"),
                id,
                config,
                schedule,
                windows,
                baseline,
                address(0)
            )
        );
        if (priceCounterId != 0) {
            hash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_NATIVE_ALLOWLIST_CLEARING_CONFIG_V1"),
                    hash,
                    priceCounterId
                )
            );
        }
        IStreamNativeClearingSale.ClearingSaleRecord storage sale = state.sales[id];
        sale.config = config;
        sale.saleNonce = nonce;
        sale.configHash = hash;
        sale.priceScheduleHash = schedule;
        sale.windowPolicyHash = windows;
        sale.expectedPrimaryPolicyHash = baseline;
        sale.lifecycle = lifecycle;
        StreamClearingSaleBook.configure(
            state.financial,
            id,
            config.schedule.startPrice,
            config.schedule.restingPrice,
            config.maxSaleQuantity
        );
        emit SaleConfigured(
            1, id, config.collectionId, config.phaseId, 4, address(0), hash, baseline, 1
        );
        emit ClearingSaleConfigured(1, id, nonce, schedule, windows, config);
    }

    function _requireContext(StreamClearingSaleState.Context memory x) private view {
        StreamSettlementAdmission.requireRegistry(
            x.support.core, x.coreHash, x.registry, x.registryHash
        );
        if (
            address(x.support.resolver).codehash != x.resolverHash
                || address(x.factory).codehash != x.factoryHash
                || address(x.support.manager).codehash != x.managerHash
                || x.recorder.codehash != x.recorderHash
        ) {
            revert IStreamNativeClearingSale.InvalidClearingSale();
        }
        StreamClearingUnlock.requireRecorderNotIncident(x.registry, x.recorder);
    }
}
