// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamNativeCuratedSaleState } from "./StreamNativeCuratedSaleState.sol";
import { StreamNativeCuratedSaleSupport } from "./StreamNativeCuratedSaleSupport.sol";
import { StreamNativeCuratedClock } from "./StreamNativeCuratedClock.sol";
import { StreamSettlementAdmission } from "../revenue/StreamSettlementAdmission.sol";
import { StreamSettlementContext } from "../revenue/StreamSettlementContext.sol";
import {
    StreamPreparedNativeSettlementValidation
} from "../revenue/StreamPreparedNativeSettlementValidation.sol";
import {
    IStreamPrimarySaleSettlement
} from "../../interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";
import {
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamNativeCuratedSaleTypes as Curated
} from "../../interfaces/stream/mint/StreamNativeCuratedSaleTypes.sol";

/// @notice Fixed linked reads from the host's immutable deployment graph.
/// @dev The host alone constructs Context. Live GGP values are reread at the original boundaries.
library StreamNativeCuratedSaleRuntime {
    struct Context {
        StreamNativeCuratedSaleSupport.Context base;
        IStreamPrimarySaleSettlement recorder;
        address factory;
        address assets;
        bytes32 coreHash;
        bytes32 registryHash;
        bytes32 resolverHash;
        bytes32 factoryHash;
        bytes32 assetsHash;
        bytes32 managerHash;
        bytes32 recorderHash;
    }

    bytes32 internal constant ARTIST_GAS =
        keccak256("6529STREAM_GGP_SALE_ARTIST_AUTHORITY_GAS_LIMIT");
    bytes32 internal constant REVEAL_GAS = keccak256("6529STREAM_GGP_REVEAL_ATTEMPT_GAS_LIMIT");
    bytes32 internal constant DELIVERY_GAS =
        keccak256("6529STREAM_GGP_SALE_NFT_DELIVERY_GAS_LIMIT");
    error InvalidCuratedDeployment();
    error CuratedSaleUnavailable(bytes32 saleId);
    error CuratedSaleStopped(bytes32 saleId);

    function support(Context memory x)
        internal
        view
        returns (StreamNativeCuratedSaleSupport.Context memory c)
    {
        c = x.base;
        c.artistGas = gasParameter(ARTIST_GAS);
    }

    function requireContext(Context memory x) public view {
        StreamSettlementAdmission.requireRegistry(
            x.base.core, x.coreHash, x.base.registry, x.registryHash
        );
        if (address(x.base.resolver).codehash != x.resolverHash) {
            revert StreamSettlementContext.InvalidSettlementContext(address(x.base.resolver));
        }
        if (x.factory.codehash != x.factoryHash) {
            revert StreamSettlementContext.InvalidSettlementContext(x.factory);
        }
        if (x.assets.codehash != x.assetsHash) {
            revert StreamSettlementContext.InvalidSettlementContext(x.assets);
        }
        if (
            address(x.base.manager).codehash != x.managerHash
                || address(x.recorder).codehash != x.recorderHash
                || address(x.base.artists).codehash != x.base.artistsHash
                || x.base.resolver.artistRegistry() != address(x.base.artists)
        ) revert InvalidCuratedDeployment();
        StreamPreparedNativeSettlementValidation.requireBindings(
            x.base.core,
            x.base.registry,
            address(x.base.manager),
            address(this),
            address(x.recorder),
            x.recorderHash
        );
    }

    function requireSale(
        StreamNativeCuratedSaleState.State storage state,
        Context memory x,
        bytes32 id
    ) public view {
        requireContext(x);
        Curated.SaleRecord storage sale = state.sales[id];
        if (sale.status != 1) revert CuratedSaleUnavailable(id);
        (bool g, bool l, bool c) =
            StreamNativeCuratedClock.stops(state.clocks, id, sale.config.collectionId);
        if (c) {
            revert StreamNativeCuratedSaleSupport.SaleAttributionContested(sale.config.collectionId);
        }
        if (g || l) revert CuratedSaleStopped(id);
        StreamNativeCuratedSaleSupport.retained(support(x), id, sale);
    }

    function gasParameter(bytes32 id) internal view returns (uint256) {
        return IStreamGasParameterHost(address(this)).gasParameter(id);
    }

    function admitGas(uint256 cap) internal view {
        uint256 available = gasleft();
        if (cap > available || available - cap < cap / 63 + (cap % 63 == 0 ? 0 : 1) + 40_000) {
            revert StreamSettlementContext.InsufficientSettlementCallGas(cap);
        }
    }
}
