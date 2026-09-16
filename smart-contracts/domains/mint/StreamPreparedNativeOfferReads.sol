// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/mint/IStreamPreparedNativeOfferGate.sol";
import "../../interfaces/stream/mint/IStreamPreparedNativeOfferMint.sol";
import "./StreamPreparedNativeContentHash.sol";
import "./StreamPreparedNativeOfferHash.sol";
import "./StreamMintGateValidator.sol";
import "./StreamNativePrimaryOfferSignatures.sol";
import "../revenue/StreamPreparedNativeSettlementHash.sol";
import "../../vendor/openzeppelin/MerkleProof.sol";

/// @notice Independent original leaf/bytes correspondence and actual phase/counter selection.
library StreamPreparedNativeOfferReads {
    error InvalidPreparedNativeOfferContent();

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
            revert InvalidPreparedNativeOfferContent();
        }
        IStreamMintManager.MintGateConfig memory actual =
            StreamMintGateValidator.validateConfiguration(g, IERC165(registry));
        if (keccak256(abi.encode(actual)) != keccak256(abi.encode(g))) {
            revert InvalidPreparedNativeOfferContent();
        }
        IStreamPreparedNativeOfferGate gate = IStreamPreparedNativeOfferGate(g.gate);
        p = gate.publication();
        if (
            !gate.supportsInterface(type(IStreamPreparedNativeOfferGate).interfaceId)
                || gate.offerPurchaseVersion()
                    != keccak256("6529STREAM_NATIVE_PRIMARY_OFFER_GATE_V1")
                || gate.gateConfigHash() != g.gateConfigHash || p.chainId != block.chainid
                || p.manager != manager || p.house != house || p.collectionId != collection
                || p.phaseId != phase || p.saleId != saleId || p.manifestRoot != root
                || p.manifestHash == 0 || p.counterId == 0 || gate.itemCount() == 0
        ) revert InvalidPreparedNativeOfferContent();
        if (
            g.gateConfigHash
                != keccak256(
                    abi.encode(
                        keccak256("6529STREAM_NATIVE_PRIMARY_OFFER_GATE_V1"),
                        p,
                        manager.codehash,
                        house.codehash
                    )
                )
        ) revert InvalidPreparedNativeOfferContent();
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
        ) revert InvalidPreparedNativeOfferContent();
    }

    function requireManifest(
        IStreamPreparedNativeOfferGate gate,
        StreamPreparedNativeContentTypes.Publication memory p
    ) private view {
        bytes memory raw = gate.manifestBytes();
        StreamPreparedNativeContentTypes.Row[] memory rows =
            abi.decode(raw, (StreamPreparedNativeContentTypes.Row[]));
        if (
            rows.length == 0 || rows.length != gate.itemCount() || keccak256(raw) != p.manifestHash
                || keccak256(abi.encode(rows)) != p.manifestHash
        ) revert InvalidPreparedNativeOfferContent();
        bytes32[] memory level = new bytes32[](rows.length);
        for (uint256 n; n < rows.length; ++n) {
            if (
                (n != 0 && rows[n - 1].contentId >= rows[n].contentId) || rows[n].tokenDataHash == 0
                    || bytes(rows[n].previewURI).length == 0
            ) revert InvalidPreparedNativeOfferContent();
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
        if (level[0] != p.manifestRoot) revert InvalidPreparedNativeOfferContent();
    }

    function requireBatch(
        address registry,
        IStreamMintManager.MintBatch calldata b,
        bytes calldata gateData,
        bytes32 intentHash,
        StreamPreparedNativeSettlementTypes.Intent memory intent
    ) public view returns (StreamPreparedNativeContentTypes.Facts memory c) {
        if (b.tokenData.length != 1 || b.tokenData[0].length > 8192 || intentHash == 0) {
            revert InvalidPreparedNativeOfferContent();
        }
        StreamPreparedNativeOfferTypes.GateData memory d =
            abi.decode(gateData, (StreamPreparedNativeOfferTypes.GateData));
        if (keccak256(gateData) != keccak256(abi.encode(d)) || d.intentHash != intentHash) {
            revert InvalidPreparedNativeOfferContent();
        }
        StreamPreparedNativeOfferTypes.Purchase memory purchase =
            StreamPreparedNativeOfferHash.readPurchase(msg.sender, intentHash, intent);
        StreamPreparedNativeOfferHash.requireAuthorization(b, d, purchase, intent);
        IStreamMintManager.MintGateConfig memory selected =
            IStreamMintManager(address(this)).phaseGate(b.collectionId, b.phaseId);
        if (selected.gate == address(0)) {
            _requireNoGate(selected);
            if (
                d.selection.contentId != 0 || d.selection.tokenDataHash != 0
                    || d.selection.proof.length != 0 || intent.contentSelectionHash != 0
            ) revert InvalidPreparedNativeOfferContent();
            c.tokenDataHash = keccak256(b.tokenData[0]);
            c.contextHash = StreamPreparedNativeSettlementHash.mintContext(
                address(this), msg.sender, intentHash
            );
            if (b.contextHash != c.contextHash) revert InvalidPreparedNativeOfferContent();
            StreamNativePrimaryOfferSignatures.validate(
                address(this), msg.sender, d, purchase, intent
            );
            return c;
        }
        if (d.selection.tokenDataHash != keccak256(b.tokenData[0])) {
            revert InvalidPreparedNativeOfferContent();
        }
        StreamPreparedNativeContentTypes.Publication memory declared =
            IStreamPreparedNativeOfferGate(selected.gate).publication();
        (
            IStreamMintManager.MintGateConfig memory g,
            StreamPreparedNativeContentTypes.Publication memory p
        ) = requirePublication(
            address(this),
            registry,
            msg.sender,
            b.collectionId,
            b.phaseId,
            intent.saleId,
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
            block.chainid, msg.sender, intent.saleId, c.contentId, c.tokenDataHash
        );
        c.contextHash = StreamPreparedNativeContentHash.context(
            block.chainid, msg.sender, intent.saleId, c.contentId
        );
        if (
            b.contextHash != c.contextHash || c.contentLeaf != intent.contentSelectionHash
                || !MerkleProof.verify(d.selection.proof, c.manifestRoot, c.contentLeaf)
        ) revert InvalidPreparedNativeOfferContent();
    }

    function requireActive(
        address registry,
        StreamPreparedNativeSettlementTypes.Facts memory f,
        StreamPreparedNativeSettlementTypes.Intent memory i
    ) public view returns (StreamPreparedNativeContentTypes.Facts memory c) {
        StreamPreparedNativeOfferTypes.Purchase memory purchase =
            StreamPreparedNativeOfferHash.readPurchase(f.saleAdapter, f.intentHash, i);
        c = IStreamPreparedNativeOfferMint(f.mintManager).activePreparedNativeOfferContent();
        bytes32 root = c.operationRoot;
        c.operationRoot = 0;
        bytes32 admission =
            StreamPreparedNativeOfferHash.admissionHash(f.saleAdapter, f.intentHash, purchase, c);
        c.operationRoot = root;
        if (
            IStreamPreparedNativeOfferMint(f.mintManager).preparedNativeOfferAdmission()
                    != admission || root == 0 || root != f.operationRoot
                || c.tokenDataHash != f.tokenDataHash
        ) revert InvalidPreparedNativeOfferContent();
        IStreamMintManager m = IStreamMintManager(f.mintManager);
        IStreamMintManager.MintGateConfig memory selected = m.phaseGate(f.collectionId, f.phaseId);
        IStreamMintLedger ledger = _ledger(f.mintManager);
        if (!ledger.isManagerAuthorizationUsed(f.mintManager, purchase.authorizationId)) {
            revert InvalidPreparedNativeOfferContent();
        }
        if (selected.gate == address(0)) {
            _requireNoGate(selected);
            StreamPreparedNativeContentTypes.Facts memory empty;
            empty.operationRoot = f.operationRoot;
            empty.tokenDataHash = f.tokenDataHash;
            empty.contextHash = StreamPreparedNativeSettlementHash.mintContext(
                f.mintManager, f.saleAdapter, f.intentHash
            );
            if (
                i.contentSelectionHash != 0
                    || keccak256(abi.encode(c)) != keccak256(abi.encode(empty))
            ) revert InvalidPreparedNativeOfferContent();
            return c;
        }
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
            c.gate != g.gate || c.gateCodeHash != g.gateCodehash
                || c.gateConfigHash != g.gateConfigHash || c.manifestHash != p.manifestHash
                || c.counterId != p.counterId || c.contentLeaf != i.contentSelectionHash
                || c.contentLeaf
                    != StreamPreparedNativeContentHash.leaf(
                        block.chainid, f.saleAdapter, i.saleId, c.contentId, f.tokenDataHash
                    )
                || c.contextHash
                    != StreamPreparedNativeContentHash.context(
                        block.chainid, f.saleAdapter, i.saleId, c.contentId
                    )
        ) revert InvalidPreparedNativeOfferContent();
        bytes32 subject = m.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.CONTEXT,
            f.collectionId,
            f.phaseId,
            c.counterId,
            f.payer,
            f.beneficiary,
            f.saleAdapter,
            purchase.authorizer,
            c.contextHash
        );
        bytes32 key = m.previewCounterValueKey(f.collectionId, f.phaseId, c.counterId, subject);
        if (ledger.counterValue(key) != 1) revert InvalidPreparedNativeOfferContent();
    }

    function _requireNoGate(IStreamMintManager.MintGateConfig memory g) private pure {
        IStreamMintManager.MintGateConfig memory empty;
        if (keccak256(abi.encode(g)) != keccak256(abi.encode(empty))) {
            revert InvalidPreparedNativeOfferContent();
        }
    }

    function _ledger(address manager) private view returns (IStreamMintLedger) {
        bytes memory data = abi.encodeWithSignature("mintLedger()");
        bool ok;
        uint256 size;
        uint256 value;
        assembly ("memory-safe") {
            ok := staticcall(gas(), manager, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            value := mload(0)
        }
        if (!ok || size != 32 || value == 0 || value > type(uint160).max) {
            revert InvalidPreparedNativeOfferContent();
        }
        return IStreamMintLedger(address(uint160(value)));
    }
}
