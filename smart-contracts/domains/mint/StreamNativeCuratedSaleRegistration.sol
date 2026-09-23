// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamNativeCuratedSaleState } from "./StreamNativeCuratedSaleState.sol";
import { StreamNativeCuratedSaleSupport } from "./StreamNativeCuratedSaleSupport.sol";
import { StreamNativeCuratedSaleHash } from "./StreamNativeCuratedSaleHash.sol";
import { StreamNativeCuratedClock } from "./StreamNativeCuratedClock.sol";
import { StreamRefundWindowSupport } from "./StreamRefundWindowSupport.sol";
import { StreamSaleTemplate } from "./StreamSaleTemplate.sol";
import { StreamNativeSettlementSupport } from "../revenue/StreamNativeSettlementSupport.sol";
import {
    StreamPreparedNativeSettlementAdmission
} from "../revenue/StreamPreparedNativeSettlementAdmission.sol";
import { IStreamMintManager } from "../../interfaces/stream/mint/IStreamMintManager.sol";
import {
    StreamPreparedNativeContentTypes as Content
} from "../../interfaces/stream/mint/StreamPreparedNativeContentTypes.sol";
import {
    StreamNativeCuratedSaleTypes as Curated
} from "../../interfaces/stream/mint/StreamNativeCuratedSaleTypes.sol";
import { IStreamRevenueResolver } from "../../interfaces/stream/revenue/IStreamRevenueResolver.sol";

/// @notice Fixed linked immutable sale registration; host performs context and manifest admission first.
library StreamNativeCuratedSaleRegistration {
    error CuratedSaleUnavailable(bytes32 saleId);
    error CuratedSaleStopped(bytes32 saleId);
    error CuratedPurchaseInvalid();
    error CuratedAccountingMismatch();
    error CuratedCallbackInvalid();
    error CuratedDeliveryFailed(address recipient);
    event CuratedSaleConfigured(
        bytes32 indexed saleId,
        bytes32 indexed configHash,
        uint8 saleKind,
        uint256 saleNonce,
        Curated.Configuration config
    );

    function register(
        StreamNativeCuratedSaleState.State storage state,
        StreamNativeCuratedSaleSupport.Context memory x,
        Curated.Configuration memory config,
        uint8 kind,
        bytes32 configHash
    ) public returns (bytes32 id) {
        if (configHash == 0 || (kind != 0 && kind != 5)) {
            revert CuratedPurchaseInvalid();
        }
        uint256 nonce = state.nextSaleNonce;
        id = StreamNativeCuratedSaleHash.saleId(kind, config.collectionId, config.phaseId, nonce);
        if (state.sales[id].status != 0) revert CuratedPurchaseInvalid();
        (bool globalPause,, bool collectionStop) =
            StreamNativeCuratedClock.stops(state.clocks, id, config.collectionId);
        if (collectionStop) {
            revert StreamNativeCuratedSaleSupport.SaleAttributionContested(config.collectionId);
        }
        if (globalPause) revert CuratedSaleStopped(id);
        StreamRefundWindowSupport.ArtistAssociation memory artist =
            StreamNativeCuratedSaleSupport.association(x, config.collectionId);
        (IStreamMintManager.MintGateConfig memory gate, Content.Publication memory p) =
            StreamNativeCuratedSaleSupport.publication(x, id, config);
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory assignment =
            x.resolver.resolvePrimaryAssignment(config.collectionId, 0, keccak256("PRIMARY_SALE"));
        if (
            !assignment.exists || assignment.scope != 1 || assignment.scopeId != config.collectionId
                || assignment.assignmentType != 1 || assignment.profileId == 0
                || assignment.templateId != 0 || assignment.assignmentHash == 0
                || assignment.policyHash != 0
                || StreamSaleTemplate.policyHash(
                        x.resolver,
                        config.collectionId,
                        StreamNativeSettlementSupport.rights(x.resolver, config.collectionId)
                    ) != config.expectedPrimaryPolicyHash
        ) revert CuratedPurchaseInvalid();
        Curated.SaleRecord storage s = state.sales[id];
        s.config = config;
        s.saleNonce = nonce;
        s.saleKind = kind;
        s.configHash = configHash;
        s.lifecycle = StreamPreparedNativeSettlementAdmission.capture(x.registry, address(this));
        s.artistId = artist.artistId;
        s.bindingGeneration = artist.generation;
        s.bindingHash = artist.bindingHash;
        s.gate = gate.gate;
        s.gateCodeHash = gate.gateCodehash;
        s.gateConfigHash = gate.gateConfigHash;
        s.manifestHash = p.manifestHash;
        s.contentCounterId = p.counterId;
        s.contentCounterConfigHash =
        x.manager.counterConfig(config.collectionId, config.phaseId, p.counterId).counterConfigHash;
        s.status = 1;
        state.nextSaleNonce = nonce + 1;
        emit CuratedSaleConfigured(id, configHash, kind, nonce, config);
    }
}
