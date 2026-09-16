// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/mint/IStreamERC20OfferGate.sol";
import "./StreamERC20OfferHash.sol";
import "./StreamPreparedNativeContentHash.sol";
import "./StreamMintGateValidator.sol";
import "../../vendor/openzeppelin/MerkleProof.sol";

/// @notice Independent original leaf/bytes correspondence and actual phase/counter selection.
library StreamERC20OfferReads {
    error InvalidERC20OfferContent();

    function requirePublication(
        address manager,
        address registry,
        address house,
        uint256 collection,
        bytes32 phase,
        bytes32 saleId,
        bytes32 root
    )
        public
        view
        returns (
            IStreamMintManager.MintGateConfig memory g,
            StreamPreparedNativeContentTypes.Publication memory p
        )
    {
        IStreamMintManager m = IStreamMintManager(manager);
        g = m.phaseGate(collection, phase);
        if (g.gate == address(0) || g.gate.codehash != g.gateCodehash || root == 0) {
            revert InvalidERC20OfferContent();
        }
        IStreamMintManager.MintGateConfig memory actual =
            StreamMintGateValidator.validateConfiguration(g, IERC165(registry));
        if (keccak256(abi.encode(actual)) != keccak256(abi.encode(g))) {
            revert InvalidERC20OfferContent();
        }
        IStreamERC20OfferGate gate = IStreamERC20OfferGate(g.gate);
        p = gate.publication();
        if (
            !gate.supportsInterface(type(IStreamERC20OfferGate).interfaceId)
                || gate.offerPurchaseVersion()
                    != keccak256("6529STREAM_ERC20_PRIMARY_OFFER_GATE_V1")
                || gate.gateConfigHash() != g.gateConfigHash || p.chainId != block.chainid
                || p.manager != manager || p.house != house || p.collectionId != collection
                || p.phaseId != phase || p.saleId != saleId || p.manifestRoot != root
                || p.manifestHash == 0 || p.counterId == 0 || gate.itemCount() == 0
        ) revert InvalidERC20OfferContent();
        if (
            g.gateConfigHash
                != keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ERC20_PRIMARY_OFFER_GATE_V1"),
                        p,
                        manager.codehash,
                        house.codehash
                    )
                )
        ) revert InvalidERC20OfferContent();
        requireManifest(gate, p);
        (bool exists, IStreamMintManager.MintPhaseConfig memory config) = m.phase(collection, phase);
        IStreamMintManager.MintCounterConfig memory counter =
            m.counterConfig(collection, phase, p.counterId);
        bytes32[] memory ids = m.phaseCounterIds(collection, phase);
        bool found;
        for (uint256 n; n < ids.length; ++n) {
            if (ids[n] == p.counterId) found = true;
        }
        if (
            !exists || config.paused || config.maxBatchQuantity != 1
                || !m.phaseExecutor(collection, phase, house) || !found || !counter.enabled
                || counter.keyMode != IStreamMintManager.CounterKeyMode.CONTEXT
                || counter.capMode != IStreamMintLedger.CounterCapMode.STATIC
                || counter.deltaMode != IStreamMintLedger.CounterDeltaMode.STATIC
                || counter.staticCap != 1 || counter.staticIncrement != 1
                || counter.counterConfigHash == 0
        ) revert InvalidERC20OfferContent();
    }

    function requireManifest(
        IStreamERC20OfferGate gate,
        StreamPreparedNativeContentTypes.Publication memory p
    ) private view {
        bytes memory raw = gate.manifestBytes();
        StreamPreparedNativeContentTypes.Row[] memory rows =
            abi.decode(raw, (StreamPreparedNativeContentTypes.Row[]));
        if (
            rows.length == 0 || rows.length != gate.itemCount() || keccak256(raw) != p.manifestHash
                || keccak256(abi.encode(rows)) != p.manifestHash
        ) revert InvalidERC20OfferContent();
        bytes32[] memory level = new bytes32[](rows.length);
        for (uint256 n; n < rows.length; ++n) {
            if (
                (n != 0 && rows[n - 1].contentId >= rows[n].contentId) || rows[n].tokenDataHash == 0
                    || bytes(rows[n].previewURI).length == 0
            ) revert InvalidERC20OfferContent();
            level[n] = StreamPreparedNativeContentHash.leaf(
                p.chainId, p.house, p.saleId, rows[n].contentId, rows[n].tokenDataHash
            );
        }
        uint256 width = rows.length;
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
        if (level[0] != p.manifestRoot) revert InvalidERC20OfferContent();
    }

    function requireBatch(
        address manager,
        address registry,
        address house,
        IStreamMintManager.MintBatch calldata b,
        StreamERC20OfferMintTypes.GateData memory d
    ) public view returns (StreamPreparedNativeContentTypes.Facts memory c) {
        if (b.tokenData.length != 1 || b.tokenData[0].length > 8192) {
            revert InvalidERC20OfferContent();
        }
        (bytes32 sellerDigest,) = StreamERC20OfferHash.validate(manager, house, b, d);
        IStreamMintManager.MintGateConfig memory selected =
            IStreamMintManager(manager).phaseGate(b.collectionId, b.phaseId);
        if (selected.gate == address(0)) {
            _requireNoGate(selected);
            if (
                d.selection.contentId != 0 || d.selection.tokenDataHash != 0
                    || d.selection.proof.length != 0 || d.authorization.contentSelectionHash != 0
                    || d.offer.contentSelectionHash != 0 || b.contextHash != sellerDigest
            ) revert InvalidERC20OfferContent();
            c.tokenDataHash = keccak256(b.tokenData[0]);
            c.contextHash = sellerDigest;
            return c;
        }
        if (d.selection.tokenDataHash != keccak256(b.tokenData[0])) {
            revert InvalidERC20OfferContent();
        }
        StreamPreparedNativeContentTypes.Publication memory declared =
            IStreamERC20OfferGate(selected.gate).publication();
        (
            IStreamMintManager.MintGateConfig memory g,
            StreamPreparedNativeContentTypes.Publication memory p
        ) = requirePublication(
            manager,
            registry,
            house,
            b.collectionId,
            b.phaseId,
            d.authorization.saleId,
            declared.manifestRoot
        );
        c.gate = g.gate;
        c.gateCodeHash = g.gateCodehash;
        c.gateConfigHash = g.gateConfigHash;
        c.manifestRoot = p.manifestRoot;
        c.manifestHash = p.manifestHash;
        c.counterId = p.counterId;
        c.contentId = d.selection.contentId;
        c.tokenDataHash = d.selection.tokenDataHash;
        c.contentLeaf = StreamPreparedNativeContentHash.leaf(
            block.chainid, house, p.saleId, c.contentId, c.tokenDataHash
        );
        c.contextHash =
            StreamPreparedNativeContentHash.context(block.chainid, house, p.saleId, c.contentId);
        if (
            b.contextHash != c.contextHash || c.contentLeaf != d.authorization.contentSelectionHash
                || c.contentLeaf != d.offer.contentSelectionHash
                || !MerkleProof.verify(d.selection.proof, c.manifestRoot, c.contentLeaf)
        ) revert InvalidERC20OfferContent();
    }

    function _requireNoGate(IStreamMintManager.MintGateConfig memory g) private pure {
        IStreamMintManager.MintGateConfig memory empty;
        if (keccak256(abi.encode(g)) != keccak256(abi.encode(empty))) {
            revert InvalidERC20OfferContent();
        }
    }
}
