// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamNativeCuratedSaleTypes as Curated
} from "../../interfaces/stream/mint/StreamNativeCuratedSaleTypes.sol";
import {
    StreamPreparedNativeContentTypes as Content
} from "../../interfaces/stream/mint/StreamPreparedNativeContentTypes.sol";
import {
    IStreamPreparedNativeContentPurchaseGate
} from "../../interfaces/stream/mint/IStreamPreparedNativeContentPurchaseGate.sol";
import { IStreamMintManager } from "../../interfaces/stream/mint/IStreamMintManager.sol";
import { IStreamMintLedger } from "../../interfaces/stream/mint/IStreamMintLedger.sol";
import {
    IStreamArtistAttribution
} from "../../interfaces/stream/artist/IStreamArtistAttribution.sol";
import {
    IStreamArtistPlatformWorks
} from "../../interfaces/stream/artist/IStreamArtistPlatformWorks.sol";
import { IStreamRevenueResolver } from "../../interfaces/stream/revenue/IStreamRevenueResolver.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import { MerkleProof } from "../../vendor/openzeppelin/MerkleProof.sol";
import { StreamMintGateValidator } from "./StreamMintGateValidator.sol";
import { StreamPreparedNativeContentHash } from "./StreamPreparedNativeContentHash.sol";
import { StreamRefundWindowSupport } from "./StreamRefundWindowSupport.sol";
import {
    StreamPreparedNativeSettlementAdmission
} from "../revenue/StreamPreparedNativeSettlementAdmission.sol";

/// @notice Fixed reads for immutable selected-work records and the actual configured mint phase.
library StreamNativeCuratedSaleSupport {
    struct Context {
        address core;
        address registry;
        IStreamMintManager manager;
        IStreamRevenueResolver resolver;
        IStreamArtistAttribution artists;
        bytes32 artistsHash;
        uint256 artistGas;
    }

    error CuratedSaleInvalid();
    error CuratedSelectionInvalid();
    error CuratedAttributionReadFailed();
    error SaleAttributionContested(uint256 collectionId);

    function artistContext(Context memory x)
        private
        pure
        returns (StreamRefundWindowSupport.Context memory c)
    {
        c.core = x.core;
        c.manager = x.manager;
        c.resolver = x.resolver;
        c.artists = x.artists;
        c.artistHash = x.artistsHash;
        c.artistGas = x.artistGas;
    }

    function association(Context memory x, uint256 collection)
        public
        view
        returns (StreamRefundWindowSupport.ArtistAssociation memory a)
    {
        a = StreamRefundWindowSupport.artistAssociation(artistContext(x), collection);
        if (
            a.state != 2 || a.authorityStatus != 1 || a.artistId == 0 || a.generation == 0
                || a.bindingHash == 0
        ) {
            revert CuratedSaleInvalid();
        }
    }

    function retained(Context memory x, bytes32 id, Curated.SaleRecord memory sale) public view {
        if (sale.status != 1 || sale.configHash == 0) revert CuratedSaleInvalid();
        StreamPreparedNativeSettlementAdmission.requireAdmission(x.registry, address(this), id);
        StreamRefundWindowSupport.requireSaleConsent(
            artistContext(x), sale.config.collectionId, id, sale.configHash
        );
        StreamRefundWindowSupport.requireArtistAssociation(
            artistContext(x),
            sale.config.collectionId,
            sale.artistId,
            sale.bindingGeneration,
            sale.bindingHash
        );
        IStreamMintManager.MintGateConfig memory gate =
            x.manager.phaseGate(sale.config.collectionId, sale.config.phaseId);
        if (
            gate.gate != sale.gate || gate.gateCodehash != sale.gateCodeHash
                || gate.gate.codehash != sale.gateCodeHash
                || gate.gateConfigHash != sale.gateConfigHash
        ) revert CuratedSaleInvalid();
        _phase(x, sale.config);
        IStreamMintManager.MintCounterConfig memory counter = x.manager
            .counterConfig(sale.config.collectionId, sale.config.phaseId, sale.contentCounterId);
        if (
            !_contentCounter(counter) || counter.counterConfigHash != sale.contentCounterConfigHash
                || !_containsCounter(x.manager, sale.config, sale.contentCounterId)
        ) revert CuratedSaleInvalid();
    }

    /// @dev Sale clock tolling never bypasses the Manager's independent phase admission.
    /// Recheck after callbacks so a successful mint cannot retain a changed executor or policy.
    function _phase(Context memory x, Curated.Configuration memory config) private view {
        (bool exists, IStreamMintManager.MintPhaseConfig memory phase) =
            x.manager.phase(config.collectionId, config.phaseId);
        if (
            !exists || phase.paused || phase.maxBatchQuantity != 1
                || block.timestamp < phase.startTime
                || (phase.endTime != 0 && block.timestamp > phase.endTime)
                || !x.manager.phaseExecutor(config.collectionId, config.phaseId, address(this))
        ) revert CuratedSaleInvalid();
        bytes32 current = x.manager.phasePolicyHash(config.collectionId, config.phaseId);
        if (current == config.mintPolicyHash) return;
        (bytes32 previous, uint64 graceUntil) =
            x.manager.phasePolicyGrace(config.collectionId, config.phaseId);
        if (previous != config.mintPolicyHash || block.timestamp > graceUntil) {
            revert CuratedSaleInvalid();
        }
    }

    function publication(Context memory x, bytes32 id, Curated.Configuration memory config)
        public
        view
        returns (IStreamMintManager.MintGateConfig memory g, Content.Publication memory p)
    {
        if (
            config.collectionId == 0 || config.phaseId == 0 || config.price == 0
                || config.poster == address(0) || config.poster == address(this)
                || config.startsAt <= block.timestamp || config.endsAt <= config.startsAt
                || config.mintPolicyHash == 0 || config.expectedPrimaryPolicyHash == 0
                || config.primaryPolicyMode > 1 || config.contentManifestRoot == 0
                || x.manager.phasePolicyHash(config.collectionId, config.phaseId)
                    != config.mintPolicyHash
        ) revert CuratedSaleInvalid();
        g = x.manager.phaseGate(config.collectionId, config.phaseId);
        IStreamMintManager.MintGateConfig memory actual =
            StreamMintGateValidator.validateConfiguration(g, IERC165(x.registry));
        if (keccak256(abi.encode(actual)) != keccak256(abi.encode(g))) revert CuratedSaleInvalid();
        IStreamPreparedNativeContentPurchaseGate gate =
            IStreamPreparedNativeContentPurchaseGate(g.gate);
        p = gate.publication();
        if (
            !gate.supportsInterface(type(IStreamPreparedNativeContentPurchaseGate).interfaceId)
                || gate.contentPurchaseVersion()
                    != keccak256("6529STREAM_NATIVE_CONTENT_PURCHASE_GATE_V1")
                || gate.gateConfigHash() != g.gateConfigHash || p.chainId != block.chainid
                || p.manager != address(x.manager) || p.house != address(this) || p.saleId != id
                || p.collectionId != config.collectionId || p.phaseId != config.phaseId
                || p.manifestRoot != config.contentManifestRoot || p.manifestHash == 0
                || p.counterId == 0
                || g.gateConfigHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_NATIVE_CONTENT_PURCHASE_GATE_V1"),
                            p,
                            address(x.manager).codehash,
                            address(this).codehash
                        )
                    )
        ) revert CuratedSaleInvalid();
        _manifest(gate, p);
        (bool exists, IStreamMintManager.MintPhaseConfig memory phase) =
            x.manager.phase(config.collectionId, config.phaseId);
        IStreamMintManager.MintCounterConfig memory counter =
            x.manager.counterConfig(config.collectionId, config.phaseId, p.counterId);
        if (
            !exists || phase.paused || phase.maxBatchQuantity != 1
                || phase.startTime > config.startsAt
                || (phase.endTime != 0 && phase.endTime < config.endsAt)
                || !x.manager.phaseExecutor(config.collectionId, config.phaseId, address(this))
                || !_containsCounter(x.manager, config, p.counterId) || !_contentCounter(counter)
        ) revert CuratedSaleInvalid();
    }

    function _contentCounter(IStreamMintManager.MintCounterConfig memory counter)
        private
        pure
        returns (bool)
    {
        return counter.enabled && counter.keyMode == IStreamMintManager.CounterKeyMode.CONTEXT
            && counter.capMode == IStreamMintLedger.CounterCapMode.STATIC
            && counter.deltaMode == IStreamMintLedger.CounterDeltaMode.STATIC
            && counter.staticCap == 1 && counter.staticIncrement == 1
            && counter.counterConfigHash != 0;
    }

    function _containsCounter(
        IStreamMintManager manager,
        Curated.Configuration memory config,
        bytes32 counterId
    ) private view returns (bool) {
        bytes32[] memory ids = manager.phaseCounterIds(config.collectionId, config.phaseId);
        if (ids.length > 16) revert CuratedSaleInvalid();
        for (uint256 n; n < ids.length; ++n) {
            if (ids[n] == counterId) return true;
        }
        return false;
    }

    function selection(bytes32 id, Curated.SaleRecord memory sale, Curated.Selection memory chosen)
        public
        view
        returns (bytes32 leaf, bytes32 contextHash)
    {
        if (
            chosen.recipient == address(0) || chosen.recipient == address(this)
                || chosen.purchaseNonce == 0 || chosen.mintCommitment == 0
                || chosen.tokenData.length > 8192
                || chosen.content.tokenDataHash != keccak256(chosen.tokenData)
        ) revert CuratedSelectionInvalid();
        leaf = StreamPreparedNativeContentHash.leaf(
            block.chainid, address(this), id, chosen.content.contentId, chosen.content.tokenDataHash
        );
        if (!MerkleProof.verify(chosen.content.proof, sale.config.contentManifestRoot, leaf)) {
            revert CuratedSelectionInvalid();
        }
        contextHash = StreamPreparedNativeContentHash.context(
            block.chainid, address(this), id, chosen.content.contentId
        );
    }

    /// @notice Sync reads are bounded and fail closed; ordinary purchases use only the local stop.
    function contestState(Context memory x, uint256 collection) public view returns (uint8 state) {
        if (
            address(x.artists).codehash != x.artistsHash || x.artistGas == 0
                || x.artistGas > type(uint64).max
        ) {
            revert CuratedAttributionReadFailed();
        }
        uint256 cap = x.artistGas;
        if (gasleft() < cap + (cap + 62) / 63 + 30000) revert CuratedAttributionReadFailed();
        bytes memory data =
            abi.encodeCall(IStreamArtistPlatformWorks.platformWorksContest, (collection));
        address target = address(x.artists);
        uint256[2] memory result;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), result, 64)
            size := returndatasize()
        }
        if (!ok || size != 64 || result[0] > 3) revert CuratedAttributionReadFailed();
        state = uint8(result[0]);
    }

    function _manifest(IStreamPreparedNativeContentPurchaseGate gate, Content.Publication memory p)
        private
        view
    {
        bytes memory raw = gate.manifestBytes();
        Content.Row[] memory rows = abi.decode(raw, (Content.Row[]));
        if (
            rows.length == 0 || rows.length != gate.itemCount() || keccak256(raw) != p.manifestHash
                || keccak256(abi.encode(rows)) != p.manifestHash
        ) revert CuratedSaleInvalid();
        bytes32[] memory level = new bytes32[](rows.length);
        for (uint256 n; n < rows.length; ++n) {
            if (
                (n != 0 && rows[n - 1].contentId >= rows[n].contentId) || rows[n].tokenDataHash == 0
                    || bytes(rows[n].previewURI).length == 0
            ) revert CuratedSaleInvalid();
            level[n] = StreamPreparedNativeContentHash.leaf(
                p.chainId, p.house, p.saleId, rows[n].contentId, rows[n].tokenDataHash
            );
        }
        uint256 width = level.length;
        while (width > 1) {
            uint256 next;
            for (uint256 n; n < width; n += 2) {
                bytes32 a = level[n];
                if (n + 1 == width) {
                    level[next] = a;
                } else {
                    bytes32 b = level[n + 1];
                    level[next] = a < b
                        ? keccak256(abi.encodePacked(a, b))
                        : keccak256(abi.encodePacked(b, a));
                }
                ++next;
            }
            width = next;
        }
        if (level[0] != p.manifestRoot) revert CuratedSaleInvalid();
    }
}
