// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeEnglishAuctionSupport.sol";
import "../../interfaces/stream/core/IStreamCoreCollectionView.sol";

/// @notice Exact pinned non-transient reasons for the original deferred auction mint.
/// @dev Failed reads and transient callbacks are never positive refund evidence.
library StreamNativeEnglishAuctionUnlock {
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
        IStreamNativeEnglishAuction.Auction memory a,
        uint8 reason
    ) public view returns (bytes32) {
        IStreamNativeEnglishAuction.Configuration memory c = a.config;
        IStreamMintReads manager = IStreamMintReads(address(x.support.manager));
        if (reason == 1) {
            code(address(manager), x.managerHash);
            (bool exists, IStreamMintManager.MintPhaseConfig memory phase) =
                manager.phase(c.collectionId, c.phaseId);
            if (exists && phase.endTime != 0 && block.timestamp > phase.endTime) {
                return keccak256("NATIVE_AUCTION_PHASE_ENDED");
            }
        } else if (reason == 2) {
            code(x.support.core, x.coreHash);
            IStreamCoreCollectionView core = IStreamCoreCollectionView(x.support.core);
            if (
                core.collectionHasMaxSupply(c.collectionId)
                    && core.collectionMintedEver(c.collectionId)
                        >= core.collectionMaxSupply(c.collectionId)
            ) return keccak256("NATIVE_AUCTION_SUPPLY_EXHAUSTED");
            code(address(manager), x.managerHash);
            if (counterExhausted(x, a)) return keccak256("NATIVE_AUCTION_COUNTER_EXHAUSTED");
        } else if (reason == 3) {
            code(address(manager), x.managerHash);
            if (manager.phasePolicyHash(c.collectionId, c.phaseId) != c.mintPolicyHash) {
                (bytes32 prior, uint64 until) = manager.phasePolicyGrace(c.collectionId, c.phaseId);
                if (prior != c.mintPolicyHash || block.timestamp > until) {
                    return keccak256("NATIVE_AUCTION_MINT_POLICY_UNMATCHABLE");
                }
            }
        } else if (reason == 4) {
            StreamRefundWindowSupport.ArtistAssociation memory actual =
                StreamRefundWindowSupport.artistAssociation(x.support, c.collectionId);
            if (
                (actual.state == 4 || actual.state == 5) && actual.artistId == a.artistId
                    && actual.generation == a.bindingGeneration
                    && actual.bindingHash == a.bindingHash
            ) return keccak256("NATIVE_AUCTION_BOUND_ATTRIBUTION_STOPPED");
        } else if (reason == 5) {
            code(x.registry, x.registryHash);
            if (incident(x.registry, address(this)) || incident(x.registry, x.recorder)) {
                return keccak256("NATIVE_AUCTION_REFERENCED_MODULE_INCIDENT_REVOKED");
            }
        }
    }

    function counterExhausted(Context memory x, IStreamNativeEnglishAuction.Auction memory a)
        private
        view
        returns (bool)
    {
        IStreamMintReads manager = IStreamMintReads(address(x.support.manager));
        IStreamNativeEnglishAuction.Configuration memory c = a.config;
        StreamPreparedNativeSettlementTypes.Intent memory i =
            StreamNativeEnglishAuctionSupport.intent(a);
        bytes32 intentHash =
            StreamPreparedNativeSettlementHash.intentHash(address(this), x.recorder, i);
        bytes32 context = StreamPreparedNativeSettlementHash.mintContext(
            address(manager), address(this), intentHash
        );
        bytes32[] memory ids = manager.phaseCounterIds(c.collectionId, c.phaseId);
        for (uint256 j; j < ids.length; ++j) {
            IStreamMintManager.MintCounterConfig memory counter =
                manager.counterConfig(c.collectionId, c.phaseId, ids[j]);
            if (
                !counter.enabled || counter.capMode != IStreamMintLedger.CounterCapMode.STATIC
                    || counter.deltaMode != IStreamMintLedger.CounterDeltaMode.STATIC
                    || counter.staticIncrement == 0
            ) continue;
            // Initial profile has no gate. Never infer a gate-derived authorizer from failure.
            if (
                counter.keyMode == IStreamMintManager.CounterKeyMode.AUTHORIZER
                    && manager.phaseGate(c.collectionId, c.phaseId).gate != address(0)
            ) continue;
            bytes32 subject = manager.previewSubjectKey(
                counter.keyMode,
                c.collectionId,
                c.phaseId,
                ids[j],
                a.winner.payer,
                a.winner.deliverTo,
                address(this),
                address(0),
                context
            );
            bytes32 key = manager.previewCounterValueKey(c.collectionId, c.phaseId, ids[j], subject);
            if (
                uint256(manager.mintLedger().counterValue(key)) + counter.staticIncrement
                    > counter.staticCap
            ) return true;
        }
        return false;
    }

    function code(address target, bytes32 expected) private view {
        if (target.codehash != expected || !StreamSettlementAdmission.isContract(target)) {
            revert IStreamNativeEnglishAuction.InvalidNativeAuction();
        }
    }

    // Literal existing RefundUnlock module-record shape with auction-local errors/domains.
    function incident(address registry, address module) private view returns (bool) {
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
        ) revert IStreamNativeEnglishAuction.InvalidNativeAuction();
        if (w[1] != 3) return false;
        if (
            w[2] == 0 || w[3] == 0 || w[4] == 0 || w[6] == 0 || w[7] == 0 || w[8] == 0 || w[10] == 0
                || w[10] > block.timestamp || w[11] < w[10] || w[11] > block.timestamp || w[12] == 0
        ) revert IStreamNativeEnglishAuction.InvalidNativeAuction();
        return true;
    }
}
