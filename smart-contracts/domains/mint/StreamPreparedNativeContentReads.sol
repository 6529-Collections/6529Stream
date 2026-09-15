// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/mint/IStreamNativeAuctionContentGate.sol";
import "../../interfaces/stream/mint/IStreamPreparedNativeContentMint.sol";
import "./StreamPreparedNativeContentHash.sol";
import "./StreamMintGateValidator.sol";
import "../../vendor/openzeppelin/MerkleProof.sol";

/// @notice Independent original leaf/bytes correspondence and actual phase/counter selection.
library StreamPreparedNativeContentReads {
    error InvalidPreparedNativeContent();

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
            revert InvalidPreparedNativeContent();
        }
        IStreamMintManager.MintGateConfig memory actual =
            StreamMintGateValidator.validateConfiguration(g, IERC165(registry));
        if (keccak256(abi.encode(actual)) != keccak256(abi.encode(g))) {
            revert InvalidPreparedNativeContent();
        }
        IStreamNativeAuctionContentGate gate = IStreamNativeAuctionContentGate(g.gate);
        p = gate.publication();
        if (
            !gate.supportsInterface(type(IStreamNativeAuctionContentGate).interfaceId)
                || gate.gateConfigHash() != g.gateConfigHash || p.chainId != block.chainid
                || p.manager != manager || p.house != house || p.collectionId != collection
                || p.phaseId != phase || p.saleId != saleId || p.manifestRoot != root
                || p.manifestHash == 0 || p.counterId == 0 || gate.itemCount() == 0
        ) revert InvalidPreparedNativeContent();
        if (
            g.gateConfigHash
                != keccak256(
                    abi.encode(
                        keccak256("6529STREAM_NATIVE_AUCTION_CONTENT_GATE_V1"),
                        p,
                        manager.codehash,
                        house.codehash
                    )
                )
        ) revert InvalidPreparedNativeContent();
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
        ) revert InvalidPreparedNativeContent();
    }

    function requireManifest(
        IStreamNativeAuctionContentGate gate,
        StreamPreparedNativeContentTypes.Publication memory p
    ) private view {
        bytes memory raw = gate.manifestBytes();
        StreamPreparedNativeContentTypes.Row[] memory rows =
            abi.decode(raw, (StreamPreparedNativeContentTypes.Row[]));
        if (
            rows.length == 0 || rows.length != gate.itemCount() || keccak256(raw) != p.manifestHash
                || keccak256(abi.encode(rows)) != p.manifestHash
        ) revert InvalidPreparedNativeContent();
        bytes32[] memory level = new bytes32[](rows.length);
        for (uint256 n; n < rows.length; ++n) {
            if (
                (n != 0 && rows[n - 1].contentId >= rows[n].contentId) || rows[n].tokenDataHash == 0
                    || bytes(rows[n].previewURI).length == 0
            ) revert InvalidPreparedNativeContent();
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
        if (level[0] != p.manifestRoot) revert InvalidPreparedNativeContent();
    }

    function requireBatch(
        address registry,
        IStreamMintManager.MintBatch calldata b,
        bytes calldata gateData,
        bytes32 intentHash,
        bytes32 saleId
    ) public view returns (StreamPreparedNativeContentTypes.Facts memory c) {
        if (
            b.tokenData.length != 1 || b.tokenData[0].length > 8192
                || b.authorizationId != intentHash || intentHash == 0 || b.authorizer != address(0)
        ) revert InvalidPreparedNativeContent();
        StreamPreparedNativeContentTypes.GateData memory d =
            abi.decode(gateData, (StreamPreparedNativeContentTypes.GateData));
        if (
            keccak256(gateData) != keccak256(abi.encode(d)) || d.authorizationId != intentHash
                || d.selection.tokenDataHash != keccak256(b.tokenData[0])
        ) revert InvalidPreparedNativeContent();
        IStreamMintManager.MintGateConfig memory selected =
            IStreamMintManager(address(this)).phaseGate(b.collectionId, b.phaseId);
        StreamPreparedNativeContentTypes.Publication memory declared =
            IStreamNativeAuctionContentGate(selected.gate).publication();
        (
            IStreamMintManager.MintGateConfig memory g,
            StreamPreparedNativeContentTypes.Publication memory p
        ) = requirePublication(
            address(this),
            registry,
            msg.sender,
            b.collectionId,
            b.phaseId,
            saleId,
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
            block.chainid, msg.sender, saleId, c.contentId, c.tokenDataHash
        );
        c.contextHash =
            StreamPreparedNativeContentHash.context(block.chainid, msg.sender, saleId, c.contentId);
        if (
            b.contextHash != c.contextHash
                || !MerkleProof.verify(d.selection.proof, c.manifestRoot, c.contentLeaf)
        ) revert InvalidPreparedNativeContent();
    }

    function requireActive(
        address registry,
        StreamPreparedNativeSettlementTypes.Facts memory f,
        StreamPreparedNativeSettlementTypes.Intent memory i
    ) public view returns (StreamPreparedNativeContentTypes.Facts memory c) {
        c = IStreamPreparedNativeContentMint(f.mintManager).activePreparedNativeContent();
        (
            IStreamMintManager.MintGateConfig memory g,
            StreamPreparedNativeContentTypes.Publication memory p
        ) = requirePublication(
            f.mintManager,
            registry,
            f.saleAdapter,
            f.collectionId,
            f.phaseId,
            i.saleId,
            c.manifestRoot
        );
        if (
            c.operationRoot != f.operationRoot || c.operationRoot == 0 || c.gate != g.gate
                || c.gateCodeHash != g.gateCodehash || c.gateConfigHash != g.gateConfigHash
                || c.manifestHash != p.manifestHash || c.counterId != p.counterId
                || c.tokenDataHash != f.tokenDataHash || c.contentLeaf != i.contentSelectionHash
                || c.contentLeaf
                    != StreamPreparedNativeContentHash.leaf(
                        block.chainid, f.saleAdapter, i.saleId, c.contentId, f.tokenDataHash
                    )
                || c.contextHash
                    != StreamPreparedNativeContentHash.context(
                        block.chainid, f.saleAdapter, i.saleId, c.contentId
                    )
        ) revert InvalidPreparedNativeContent();
        IStreamMintManager m = IStreamMintManager(f.mintManager);
        bytes32 subject = m.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.CONTEXT,
            f.collectionId,
            f.phaseId,
            c.counterId,
            f.payer,
            f.beneficiary,
            f.saleAdapter,
            address(0),
            c.contextHash
        );
        bytes32 key = m.previewCounterValueKey(f.collectionId, f.phaseId, c.counterId, subject);
        (bool ok, bytes memory raw) =
            f.mintManager.staticcall(abi.encodeWithSignature("mintLedger()"));
        if (!ok || raw.length != 32) revert InvalidPreparedNativeContent();
        if (IStreamMintLedger(abi.decode(raw, (address))).counterValue(key) != 1) {
            revert InvalidPreparedNativeContent();
        }
    }
}
