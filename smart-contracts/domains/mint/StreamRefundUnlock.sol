// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamRefundWindowSupport.sol";
import "../../interfaces/stream/core/IStreamCoreCollectionView.sol";

/// @notice Typed permanent-failure facts, separate from the unconditional time escape.
/// @dev Each branch reads only its required pinned dependency. Failed reads are not unlock facts.
library StreamRefundUnlock {
    struct Context {
        StreamRefundWindowSupport.Context support;
        address registry;
        bytes32 registryHash;
        bytes32 coreHash;
        bytes32 managerHash;
        address recorder;
    }

    function reasonHash(
        Context memory x,
        IStreamNativeRefundWindowSale.RefundSaleRecord memory sale,
        IStreamNativeRefundWindowSale.RefundPurchaseRecord memory p,
        uint8 reasonCode
    ) public view returns (bytes32 hash) {
        if (reasonCode == 1) {
            _manager(x);
            (bool exists, IStreamMintManager.MintPhaseConfig memory phase) = IStreamMintReads(
                    address(x.support.manager)
                ).phase(sale.config.collectionId, sale.config.phaseId);
            if (exists && phase.endTime != 0 && block.timestamp > phase.endTime) {
                return keccak256("REFUND_PHASE_ENDED");
            }
        } else if (reasonCode == 2) {
            _code(x.support.core, x.coreHash);
            IStreamCoreCollectionView core = IStreamCoreCollectionView(x.support.core);
            if (
                core.collectionHasMaxSupply(sale.config.collectionId)
                    && core.collectionMintedEver(sale.config.collectionId)
                        >= core.collectionMaxSupply(sale.config.collectionId)
            ) {
                return keccak256("REFUND_SUPPLY_EXHAUSTED");
            }
            _manager(x);
            if (_counterExhausted(x.support.manager, sale.config, p)) {
                return keccak256("REFUND_COUNTER_EXHAUSTED");
            }
        } else if (reasonCode == 3) {
            _manager(x);
            IStreamMintReads manager = IStreamMintReads(address(x.support.manager));
            bytes32 bound = sale.config.mintPolicyHash;
            if (manager.phasePolicyHash(sale.config.collectionId, sale.config.phaseId) != bound) {
                (bytes32 prior, uint64 until) =
                    manager.phasePolicyGrace(sale.config.collectionId, sale.config.phaseId);
                if (prior != bound || block.timestamp > until) {
                    return keccak256("REFUND_MINT_POLICY_UNMATCHABLE");
                }
            }
        } else if (reasonCode == 4) {
            StreamRefundWindowSupport.ArtistAssociation memory a =
                StreamRefundWindowSupport.artistAssociation(x.support, sale.config.collectionId);
            if (
                (a.state == 4 || a.state == 5) && a.artistId == p.artistId
                    && a.generation == p.bindingGeneration && a.bindingHash == p.bindingHash
            ) {
                return keccak256("REFUND_BOUND_ATTRIBUTION_STOPPED");
            }
        } else if (reasonCode == 5) {
            _code(x.registry, x.registryHash);
            if (
                _incident(x.registry, address(this)) || _incident(x.registry, x.recorder)
                    || (p.referencedGate != address(0) && _incident(x.registry, p.referencedGate))
            ) {
                return keccak256("REFUND_REFERENCED_MODULE_INCIDENT_REVOKED");
            }
        }
    }

    function _manager(Context memory x) private view {
        _code(address(x.support.manager), x.managerHash);
    }

    function _code(address target, bytes32 expected) private view {
        if (target.codehash != expected || !StreamSettlementAdmission.isContract(target)) {
            revert IStreamNativeRefundWindowSale.RefundDependencyInvalid(target);
        }
    }

    function _counterExhausted(
        IStreamMintManager target,
        IStreamNativeRefundWindowSale.RefundSaleConfig memory c,
        IStreamNativeRefundWindowSale.RefundPurchaseRecord memory p
    ) private view returns (bool) {
        IStreamMintReads manager = IStreamMintReads(address(target));
        bytes32[] memory ids = manager.phaseCounterIds(c.collectionId, c.phaseId);
        for (uint256 i; i < ids.length; ++i) {
            IStreamMintManager.MintCounterConfig memory counter =
                manager.counterConfig(c.collectionId, c.phaseId, ids[i]);
            if (
                !counter.enabled || counter.capMode != IStreamMintLedger.CounterCapMode.STATIC
                    || counter.deltaMode != IStreamMintLedger.CounterDeltaMode.STATIC
                    || counter.staticIncrement == 0
            ) continue;
            // Gate-derived authorizers and resolver increments cannot be inferred from a failed callback.
            if (
                counter.keyMode == IStreamMintManager.CounterKeyMode.AUTHORIZER
                    && manager.phaseGate(c.collectionId, c.phaseId).gate != address(0)
            ) continue;
            bytes32 subject = _subject(manager, c, p, ids[i], counter.keyMode);
            bytes32 key = manager.previewCounterValueKey(c.collectionId, c.phaseId, ids[i], subject);
            if (
                uint256(manager.mintLedger().counterValue(key)) + counter.staticIncrement
                    > counter.staticCap
            ) return true;
        }
        return false;
    }

    function _subject(
        IStreamMintReads manager,
        IStreamNativeRefundWindowSale.RefundSaleConfig memory c,
        IStreamNativeRefundWindowSale.RefundPurchaseRecord memory p,
        bytes32 counterId,
        IStreamMintManager.CounterKeyMode mode
    ) private view returns (bytes32) {
        return manager.previewSubjectKey(
            mode,
            c.collectionId,
            c.phaseId,
            counterId,
            p.authorization.payer,
            p.authorization.recipient,
            address(this),
            address(0),
            p.authorizationDigest
        );
    }

    function _incident(address registry, address module) private view returns (bool) {
        bytes memory data = abi.encodeCall(IStreamModuleRegistry.moduleRecord, (module));
        uint256[14] memory w;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), registry, add(data, 32), mload(data), w, 448)
            size := returndatasize()
        }
        if (
            !ok || size < 448 || w[0] != 32 || w[1] > 3 || w[5] > type(uint32).max || w[9] != 384
                || w[10] > type(uint64).max || w[11] > type(uint64).max || w[12] > type(uint64).max
                || w[13] > size - 448 || size - 448 != ((w[13] + 31) / 32) * 32
                || uint224(w[4]) != 0
        ) {
            revert IStreamNativeRefundWindowSale.RefundDependencyReadMalformed(registry, size);
        }
        if (w[1] != 3) return false;
        if (
            w[2] == 0 || w[3] == 0 || w[4] == 0 || w[6] == 0 || w[7] == 0 || w[8] == 0 || w[10] == 0
                || w[10] > block.timestamp || w[11] < w[10] || w[11] > block.timestamp || w[12] == 0
        ) {
            revert IStreamNativeRefundWindowSale.RefundDependencyReadMalformed(registry, size);
        }
        return true;
    }
}
