// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/mint/IStreamPreparedNativeOfferGate.sol";
import "../../interfaces/stream/mint/IStreamPreparedNativeOfferMint.sol";
import "../../interfaces/stream/revenue/IStreamPreparedNativeSaleBinding.sol";
import "./StreamPreparedNativeOfferHash.sol";
import "./StreamPreparedNativeContentHash.sol";
import "./StreamNativePrimaryOfferSignatures.sol";
import "../../vendor/openzeppelin/MerkleProof.sol";
import "../../vendor/openzeppelin/IERC165.sol";

/// @notice Immutable complete pre-sale manifest, selected by the actual phase and original sale.
/// @dev Publication is a declaration of preview references, not offchain availability evidence.
contract StreamNativePrimaryOfferGate is IStreamPreparedNativeOfferGate {
    StreamPreparedNativeContentTypes.Publication private _publication;
    bytes private _manifest;
    bytes32 public immutable override gateConfigHash;
    uint256 public immutable override itemCount;
    bytes32 public immutable managerCodeHash;
    bytes32 public immutable houseCodeHash;
    error InvalidOfferPublication();
    error InvalidOfferMint();
    event OfferManifestPublished(
        bytes32 indexed saleId,
        bytes32 indexed root,
        bytes32 indexed manifestHash,
        uint256 count,
        bytes manifest
    );

    constructor(
        address manager,
        address house,
        bytes32 saleId,
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 counterId,
        StreamPreparedNativeContentTypes.Row[] memory rows
    ) {
        if (
            manager.code.length == 0 || house.code.length == 0 || saleId == 0 || collectionId == 0
                || phaseId == 0 || counterId == 0 || rows.length == 0
        ) revert InvalidOfferPublication();
        bytes32[] memory level = new bytes32[](rows.length);
        for (uint256 n; n < rows.length; ++n) {
            if (
                (n != 0 && rows[n - 1].contentId >= rows[n].contentId) || rows[n].tokenDataHash == 0
                    || bytes(rows[n].previewURI).length == 0
            ) revert InvalidOfferPublication();
            level[n] = StreamPreparedNativeContentHash.leaf(
                block.chainid, house, saleId, rows[n].contentId, rows[n].tokenDataHash
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
        _manifest = abi.encode(rows);
        itemCount = rows.length;
        managerCodeHash = manager.codehash;
        houseCodeHash = house.codehash;
        _publication = StreamPreparedNativeContentTypes.Publication(
            block.chainid,
            manager,
            house,
            saleId,
            collectionId,
            phaseId,
            level[0],
            keccak256(_manifest),
            counterId
        );
        gateConfigHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_PRIMARY_OFFER_GATE_V1"),
                _publication,
                managerCodeHash,
                houseCodeHash
            )
        );
        emit OfferManifestPublished(
            saleId, level[0], _publication.manifestHash, rows.length, _manifest
        );
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IStreamMintGate).interfaceId
            || id == type(IStreamPreparedNativeOfferGate).interfaceId;
    }

    function publication()
        external
        view
        override
        returns (StreamPreparedNativeContentTypes.Publication memory)
    {
        return _publication;
    }

    function manifestBytes() external view override returns (bytes memory) {
        return _manifest;
    }

    function offerPurchaseVersion() external pure override returns (bytes32) {
        return keccak256("6529STREAM_NATIVE_PRIMARY_OFFER_GATE_V1");
    }

    function validateMint(
        address manager,
        address executor,
        uint256 collectionId,
        bytes32 phaseId,
        address payer,
        address authorizer,
        address[] calldata initialRecipients,
        address[] calldata beneficiaries,
        bytes32 contextHash,
        bytes32 expectedPolicyHash,
        bytes calldata gateData
    ) external view override returns (GateResult memory r) {
        StreamPreparedNativeContentTypes.Publication memory p = _publication;
        if (
            block.chainid != p.chainId || msg.sender != p.manager || manager != p.manager
                || manager.codehash != managerCodeHash || executor != p.house
                || executor.codehash != houseCodeHash || collectionId != p.collectionId
                || phaseId != p.phaseId || payer == address(0) || payer == p.house
                || initialRecipients.length != 1 || initialRecipients[0] != p.house
                || beneficiaries.length != 1 || beneficiaries[0] != payer || expectedPolicyHash == 0
        ) revert InvalidOfferMint();
        StreamPreparedNativeOfferTypes.GateData memory d =
            abi.decode(gateData, (StreamPreparedNativeOfferTypes.GateData));
        if (
            keccak256(gateData) != keccak256(abi.encode(d)) || d.intentHash == 0
                || d.authorizationId == 0
        ) revert InvalidOfferMint();
        StreamPreparedNativeSettlementTypes.Intent memory intent =
            _readIntent(p.house, d.intentHash);
        StreamPreparedNativeOfferTypes.Purchase memory purchase =
            StreamPreparedNativeOfferHash.readPurchase(p.house, d.intentHash, intent);
        StreamPreparedNativeContentTypes.Facts memory content =
            _content(p, d.selection, contextHash);
        if (
            purchase.saleId != p.saleId || purchase.buyer != payer
                || purchase.authorizer != authorizer
                || purchase.authorizationId != d.authorizationId
                || intent.collectionId != p.collectionId || intent.phaseId != p.phaseId
                || intent.contentSelectionHash != content.contentLeaf
                || intent.boundMintPolicyHash != expectedPolicyHash || intent.mintCommitment == 0
        ) revert InvalidOfferMint();
        bytes32[] memory commitments = new bytes32[](1);
        commitments[0] = intent.mintCommitment;
        if (
            d.authorization.initialRecipientsHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), initialRecipients
                        )
                    )
                || d.authorization.beneficiariesHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), beneficiaries
                        )
                    )
                || d.authorization.mintCommitmentsHash
                    != keccak256(
                        abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), commitments)
                    )
        ) revert InvalidOfferMint();
        StreamNativePrimaryOfferSignatures.validate(manager, p.house, d, purchase, intent);
        bytes32 admission =
            StreamPreparedNativeOfferHash.admissionHash(p.house, d.intentHash, purchase, content);
        if (IStreamPreparedNativeOfferMint(manager).preparedNativeOfferAdmission() != admission) {
            revert InvalidOfferMint();
        }
        r.authorizationId = purchase.authorizationId;
        r.authorizer = purchase.authorizer;
        r.authorizerKind = purchase.authorizerKind;
        r.nullifiers = new bytes32[](0);
        r.maxQuantity = 1;
        r.gateHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_PRIMARY_OFFER_GATE_RESULT_V1"),
                gateConfigHash,
                admission,
                expectedPolicyHash,
                keccak256(gateData)
            )
        );
    }

    function _content(
        StreamPreparedNativeContentTypes.Publication memory p,
        StreamPreparedNativeContentTypes.Selection memory selected,
        bytes32 contextHash
    ) private view returns (StreamPreparedNativeContentTypes.Facts memory c) {
        bytes32 leaf = StreamPreparedNativeContentHash.leaf(
            p.chainId, p.house, p.saleId, selected.contentId, selected.tokenDataHash
        );
        if (
            selected.tokenDataHash == 0
                || contextHash
                    != StreamPreparedNativeContentHash.context(
                        p.chainId, p.house, p.saleId, selected.contentId
                    ) || !MerkleProof.verify(selected.proof, p.manifestRoot, leaf)
        ) revert InvalidOfferMint();
        c = StreamPreparedNativeContentTypes.Facts(
            0,
            address(this),
            address(this).codehash,
            gateConfigHash,
            p.manifestRoot,
            p.manifestHash,
            p.counterId,
            selected.contentId,
            selected.tokenDataHash,
            leaf,
            contextHash
        );
    }

    function _readIntent(address house, bytes32 hash)
        private
        view
        returns (StreamPreparedNativeSettlementTypes.Intent memory intent)
    {
        bytes memory data = abi.encodeCall(
            IStreamPreparedNativeOfferSale.activePreparedNativeOfferIntent, (hash)
        );
        bytes memory raw = new bytes(576);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), house, add(data, 32), mload(data), add(raw, 32), 576)
            size := returndatasize()
        }
        if (!ok || size != 576) revert InvalidOfferMint();
        intent = abi.decode(raw, (StreamPreparedNativeSettlementTypes.Intent));
        if (
            keccak256(raw) != keccak256(abi.encode(intent))
                || hash
                    != StreamPreparedNativeOfferHash.intentHash(
                        house,
                        IStreamPreparedNativeSaleBinding(house).primarySaleSettlement(),
                        intent
                    )
        ) revert InvalidOfferMint();
    }
}
