// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/mint/IStreamERC20OfferGate.sol";
import "./StreamERC20OfferSignatures.sol";
import "./StreamPreparedNativeContentHash.sol";
import "../../vendor/openzeppelin/MerkleProof.sol";

/// @notice Immutable original content publication for the dedicated ERC20 offer mint route.
contract StreamERC20OfferGate is IStreamERC20OfferGate {
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
                keccak256("6529STREAM_ERC20_PRIMARY_OFFER_GATE_V1"),
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
            || id == type(IStreamERC20OfferGate).interfaceId;
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
        return keccak256("6529STREAM_ERC20_PRIMARY_OFFER_GATE_V1");
    }

    /// @dev The ordinary Manager route does not require an official ERC20 settlement receipt.
    function validateMint(
        address,
        address,
        uint256,
        bytes32,
        address,
        address,
        address[] calldata,
        address[] calldata,
        bytes32,
        bytes32,
        bytes calldata
    ) external pure override returns (GateResult memory) {
        revert InvalidOfferMint();
    }

    function validateERC20OfferBatch(
        address manager,
        address house,
        IStreamMintManager.MintBatch calldata batch,
        StreamERC20OfferMintTypes.GateData calldata d
    ) external view override returns (GateResult memory r) {
        StreamPreparedNativeContentTypes.Publication memory p = _publication;
        if (
            block.chainid != p.chainId || msg.sender != p.manager || manager != p.manager
                || manager.codehash != managerCodeHash || house != p.house
                || house.codehash != houseCodeHash || batch.collectionId != p.collectionId
                || batch.phaseId != p.phaseId || d.authorization.saleId != p.saleId
                || batch.tokenData.length != 1 || batch.tokenData[0].length > 8192
                || d.selection.tokenDataHash != keccak256(batch.tokenData[0])
        ) revert InvalidOfferMint();
        (bytes32 sellerDigest, bytes32 offerDigest) =
            StreamERC20OfferSignatures.validate(manager, house, batch, d);
        bytes32 leaf = StreamPreparedNativeContentHash.leaf(
            p.chainId, p.house, p.saleId, d.selection.contentId, d.selection.tokenDataHash
        );
        if (
            d.selection.tokenDataHash == 0 || d.authorization.contentSelectionHash != leaf
                || d.offer.contentSelectionHash != leaf
                || batch.contextHash
                    != StreamPreparedNativeContentHash.context(
                        p.chainId, p.house, p.saleId, d.selection.contentId
                    ) || !MerkleProof.verify(d.selection.proof, p.manifestRoot, leaf)
        ) revert InvalidOfferMint();
        r.authorizationId = batch.authorizationId;
        r.authorizer = d.buyerSignature.authorizer;
        r.authorizerKind = d.buyerSignature.kind;
        r.nullifiers = new bytes32[](0);
        r.maxQuantity = 1;
        r.gateHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ERC20_PRIMARY_OFFER_GATE_RESULT_V1"),
                gateConfigHash,
                sellerDigest,
                offerDigest,
                batch.expectedPolicyHash,
                keccak256(abi.encode(d))
            )
        );
    }
}
