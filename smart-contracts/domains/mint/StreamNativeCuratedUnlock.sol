// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamNativeCuratedSaleSupport } from "./StreamNativeCuratedSaleSupport.sol";
import { StreamNativeCuratedCommitments } from "./StreamNativeCuratedCommitments.sol";
import {
    StreamNativeCuratedSaleTypes as Curated
} from "../../interfaces/stream/mint/StreamNativeCuratedSaleTypes.sol";
import { StreamRefundWindowSupport } from "./StreamRefundWindowSupport.sol";
import { IStreamMintReads } from "../../interfaces/stream/mint/IStreamMintReads.sol";
import { IStreamMintManager } from "../../interfaces/stream/mint/IStreamMintManager.sol";
import { IStreamMintLedger } from "../../interfaces/stream/mint/IStreamMintLedger.sol";
import {
    IStreamCoreCollectionView
} from "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import { IStreamModuleRegistry } from "../../interfaces/stream/modules/IStreamModuleRegistry.sol";

/// @notice Independently verified non-transient reasons for refunding pending content commitments.
/// @dev The host authenticates the stored pending record before calling. Time escape, maturity,
///      credit conversion and claims stay local to the host and never call these providers.
library StreamNativeCuratedUnlock {
    struct Context {
        StreamNativeCuratedSaleSupport.Context support;
        bytes32 coreHash;
        bytes32 managerHash;
        bytes32 registryHash;
    }

    error CuratedUnlockInputInvalid();
    error CuratedUnlockDependencyInvalid(address target);
    error CuratedUnlockReadFailed(address target, bytes4 selector, uint256 size);
    error CuratedUnlockProofInvalid();

    /// @notice Returns zero when the requested fact is absent; a failed read or proof reverts.
    /// @dev Reasons: 1 phase ended; 2 supply/counter exhausted; 3 policy beyond grace;
    ///      4 saved attribution disputed/revoked; 5 referenced module incident-revoked.
    function verifiedReason(
        Context memory x,
        bytes32 saleId,
        Curated.SaleRecord memory sale,
        address buyer,
        bytes32 savedCommitment,
        Curated.Selection memory chosen,
        bytes32 salt,
        uint8 reason
    ) public view returns (bytes32) {
        if (
            saleId == 0 || sale.saleNonce == 0 || sale.config.collectionId == 0
                || sale.config.phaseId == 0 || buyer == address(0) || buyer == address(this)
                || savedCommitment == 0 || sale.configHash == 0 || sale.config.price == 0
                || sale.config.mintPolicyHash == 0
        ) revert CuratedUnlockInputInvalid();
        if (reason == 1) {
            _code(address(x.support.manager), x.managerHash);
            (bool exists, uint64 end) = _phase(address(x.support.manager), sale);
            if (exists && end != 0 && block.timestamp > end) {
                return keccak256("REFUND_PHASE_ENDED");
            }
        } else if (reason == 2) {
            if (_supplyExhausted(x, sale.config.collectionId)) {
                return keccak256("REFUND_SUPPLY_EXHAUSTED");
            }
            if (_counterExhausted(x, saleId, sale, buyer, savedCommitment, chosen, salt)) {
                return keccak256("REFUND_COUNTER_EXHAUSTED");
            }
        } else if (reason == 3) {
            _code(address(x.support.manager), x.managerHash);
            bytes32 current = bytes32(
                _word(
                    address(x.support.manager),
                    abi.encodeCall(
                        IStreamMintReads.phasePolicyHash,
                        (sale.config.collectionId, sale.config.phaseId)
                    )
                )
            );
            if (current != sale.config.mintPolicyHash) {
                bytes memory raw = _read(
                    address(x.support.manager),
                    abi.encodeCall(
                        IStreamMintReads.phasePolicyGrace,
                        (sale.config.collectionId, sale.config.phaseId)
                    ),
                    64
                );
                (bytes32 prior, uint256 until) = abi.decode(raw, (bytes32, uint256));
                if (until > type(uint64).max) {
                    revert CuratedUnlockReadFailed(
                        address(x.support.manager), IStreamMintReads.phasePolicyGrace.selector, 64
                    );
                }
                if (prior != sale.config.mintPolicyHash || block.timestamp > until) {
                    return keccak256("REFUND_MINT_POLICY_UNMATCHABLE");
                }
            }
        } else if (reason == 4) {
            _code(x.support.core, x.coreHash);
            StreamRefundWindowSupport.Context memory c;
            c.core = x.support.core;
            c.artists = x.support.artists;
            c.artistHash = x.support.artistsHash;
            c.artistGas = x.support.artistGas;
            StreamRefundWindowSupport.ArtistAssociation memory a =
                StreamRefundWindowSupport.artistAssociation(c, sale.config.collectionId);
            if (
                (a.state == 4 || a.state == 5) && a.artistId == sale.artistId
                    && a.generation == sale.bindingGeneration && a.bindingHash == sale.bindingHash
            ) {
                return keccak256("REFUND_BOUND_ATTRIBUTION_STOPPED");
            }
        } else if (reason == 5) {
            _code(x.support.registry, x.registryHash);
            if (
                _incident(x.support.registry, address(this))
                    || _incident(x.support.registry, address(x.support.manager))
                    || (sale.gate != address(0) && _incident(x.support.registry, sale.gate))
            ) {
                return keccak256("REFUND_REFERENCED_MODULE_INCIDENT_REVOKED");
            }
        }
        return 0;
    }

    function _supplyExhausted(Context memory x, uint256 collectionId) private view returns (bool) {
        _code(x.support.core, x.coreHash);
        uint256 limited = _word(
            x.support.core,
            abi.encodeCall(IStreamCoreCollectionView.collectionHasMaxSupply, (collectionId))
        );
        if (limited > 1) {
            revert CuratedUnlockReadFailed(
                x.support.core, IStreamCoreCollectionView.collectionHasMaxSupply.selector, 32
            );
        }
        if (limited == 0) return false;
        uint256 minted = _word(
            x.support.core,
            abi.encodeCall(IStreamCoreCollectionView.collectionMintedEver, (collectionId))
        );
        uint256 cap = _word(
            x.support.core,
            abi.encodeCall(IStreamCoreCollectionView.collectionMaxSupply, (collectionId))
        );
        return minted >= cap;
    }

    function _counterExhausted(
        Context memory x,
        bytes32 saleId,
        Curated.SaleRecord memory sale,
        address buyer,
        bytes32 savedCommitment,
        Curated.Selection memory chosen,
        bytes32 salt
    ) private view returns (bool) {
        address manager = address(x.support.manager);
        _code(manager, x.managerHash);
        (bool exists,) = _phase(manager, sale);
        if (!exists) return false;
        bytes32[] memory ids = _counterIds(manager, sale.config.collectionId, sale.config.phaseId);
        bool contentCounter;
        bool policyRead;
        bool originalPolicy;
        for (uint256 n; n < ids.length; ++n) {
            IStreamMintManager.MintCounterConfig memory c = _counter(manager, sale, ids[n]);
            if (
                !c.enabled || c.capMode != IStreamMintLedger.CounterCapMode.STATIC
                    || c.deltaMode != IStreamMintLedger.CounterDeltaMode.STATIC
                    || c.staticIncrement == 0 || c.staticCap == 0 || c.counterConfigHash == 0
            ) continue;
            // A CONSTANT counter is the existing phase/global quantity-cap mechanism.
            // Other wallet/authorizer keys are not inferred from an opaque content commitment.
            if (c.keyMode == IStreamMintManager.CounterKeyMode.CONSTANT) {
                if (!policyRead) {
                    originalPolicy = bytes32(
                        _word(
                            manager,
                            abi.encodeCall(
                                IStreamMintReads.phasePolicyHash,
                                (sale.config.collectionId, sale.config.phaseId)
                            )
                        )
                    ) == sale.config.mintPolicyHash;
                    policyRead = true;
                }
                if (!originalPolicy) continue;
                if (
                    _value(manager, sale, ids[n], c.keyMode, buyer, bytes32(0)) + c.staticIncrement
                        > c.staticCap
                ) return true;
            } else if (
                ids[n] == sale.contentCounterId
                    && c.keyMode == IStreamMintManager.CounterKeyMode.CONTEXT && c.staticCap == 1
                    && c.staticIncrement == 1
                    && c.counterConfigHash == sale.contentCounterConfigHash
            ) {
                contentCounter = true;
            }
        }
        if (!contentCounter) return false;
        (bytes32 leaf, bytes32 contextHash) =
            StreamNativeCuratedSaleSupport.selection(saleId, sale, chosen);
        if (
            StreamNativeCuratedCommitments.commitmentHash(saleId, buyer, leaf, salt)
                != savedCommitment
        ) {
            revert CuratedUnlockProofInvalid();
        }
        return _value(
            manager,
            sale,
            sale.contentCounterId,
            IStreamMintManager.CounterKeyMode.CONTEXT,
            buyer,
            contextHash
        ) >= 1;
    }

    function _phase(address manager, Curated.SaleRecord memory sale)
        private
        view
        returns (bool exists, uint64 end)
    {
        bytes memory raw = _read(
            manager,
            abi.encodeCall(IStreamMintReads.phase, (sale.config.collectionId, sale.config.phaseId)),
            224
        );
        uint256[7] memory w = abi.decode(raw, (uint256[7]));
        if (
            w[0] > 1 || w[1] > 1 || w[2] > type(uint64).max || w[3] > type(uint64).max
                || w[4] > type(uint32).max
        ) {
            revert CuratedUnlockReadFailed(manager, IStreamMintReads.phase.selector, 224);
        }
        return (w[0] == 1, uint64(w[3]));
    }

    function _value(
        address manager,
        Curated.SaleRecord memory sale,
        bytes32 counterId,
        IStreamMintManager.CounterKeyMode mode,
        address buyer,
        bytes32 contextHash
    ) private view returns (uint256) {
        bytes32 subject = bytes32(
            _word(
                manager,
                abi.encodeCall(
                    IStreamMintReads.previewSubjectKey,
                    (
                        mode,
                        sale.config.collectionId,
                        sale.config.phaseId,
                        counterId,
                        buyer,
                        buyer,
                        address(this),
                        address(0),
                        contextHash
                    )
                )
            )
        );
        bytes32 key = bytes32(
            _word(
                manager,
                abi.encodeCall(
                    IStreamMintReads.previewCounterValueKey,
                    (sale.config.collectionId, sale.config.phaseId, counterId, subject)
                )
            )
        );
        uint256 target = _word(manager, abi.encodeCall(IStreamMintReads.mintLedger, ()));
        if (target > type(uint160).max || address(uint160(target)).code.length == 0) {
            revert CuratedUnlockDependencyInvalid(address(uint160(target)));
        }
        uint256 value =
            _word(address(uint160(target)), abi.encodeCall(IStreamMintLedger.counterValue, (key)));
        if (value > type(uint64).max) {
            revert CuratedUnlockReadFailed(
                address(uint160(target)), IStreamMintLedger.counterValue.selector, 32
            );
        }
        return value;
    }

    function _counter(address manager, Curated.SaleRecord memory sale, bytes32 id)
        private
        view
        returns (IStreamMintManager.MintCounterConfig memory c)
    {
        bytes memory raw = _read(
            manager,
            abi.encodeCall(
                IStreamMintReads.counterConfig, (sale.config.collectionId, sale.config.phaseId, id)
            ),
            224
        );
        uint256[7] memory w = abi.decode(raw, (uint256[7]));
        if (
            w[0] > 1 || w[1] > 6 || w[2] > 3 || w[3] > 1 || w[4] > type(uint64).max
                || w[5] > type(uint64).max
        ) revert CuratedUnlockReadFailed(manager, IStreamMintReads.counterConfig.selector, 224);
        c = abi.decode(raw, (IStreamMintManager.MintCounterConfig));
    }

    function _counterIds(address manager, uint256 collection, bytes32 phase)
        private
        view
        returns (bytes32[] memory ids)
    {
        bytes memory data = abi.encodeCall(IStreamMintReads.phaseCounterIds, (collection, phase));
        uint256[18] memory w;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), manager, add(data, 32), mload(data), w, 576)
            size := returndatasize()
        }
        if (!ok || size < 64 || w[0] != 32 || w[1] > 16 || size != 64 + w[1] * 32) {
            revert CuratedUnlockReadFailed(manager, IStreamMintReads.phaseCounterIds.selector, size);
        }
        ids = new bytes32[](w[1]);
        for (uint256 n; n < ids.length; ++n) {
            ids[n] = bytes32(w[n + 2]);
        }
    }

    function _code(address target, bytes32 hash) private view {
        if (target.code.length == 0 || target.codehash != hash) {
            revert CuratedUnlockDependencyInvalid(target);
        }
    }

    function _word(address target, bytes memory data) private view returns (uint256) {
        return abi.decode(_read(target, data, 32), (uint256));
    }

    function _read(address target, bytes memory data, uint256 length)
        private
        view
        returns (bytes memory raw)
    {
        raw = new bytes(length);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), add(raw, 32), length)
            size := returndatasize()
        }
        if (!ok || size != length) revert CuratedUnlockReadFailed(target, bytes4(data), size);
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
            revert CuratedUnlockReadFailed(
                registry, IStreamModuleRegistry.moduleRecord.selector, size
            );
        }
        if (w[1] != 3) return false;
        if (
            w[2] == 0 || w[3] == 0 || w[4] == 0 || w[6] == 0 || w[7] == 0 || w[8] == 0 || w[10] == 0
                || w[10] > block.timestamp || w[11] < w[10] || w[11] > block.timestamp || w[12] == 0
        ) {
            revert CuratedUnlockReadFailed(
                registry, IStreamModuleRegistry.moduleRecord.selector, size
            );
        }
        return true;
    }
}
