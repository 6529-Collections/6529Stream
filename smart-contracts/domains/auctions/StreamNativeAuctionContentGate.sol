// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/mint/IStreamNativeAuctionContentGate.sol";
import "../mint/StreamPreparedNativeContentHash.sol";
import "../../interfaces/stream/mint/IStreamPreparedNativeContentMint.sol";
import "../../vendor/openzeppelin/MerkleProof.sol";

/// @notice Immutable complete pre-sale manifest, selected by the actual phase and signed auction.
/// @dev Publication is a declaration of preview references, not offchain availability evidence.
contract StreamNativeAuctionContentGate is IStreamNativeAuctionContentGate {
    StreamPreparedNativeContentTypes.Publication private _publication;
    bytes private _manifest;
    bytes32 public immutable override gateConfigHash;
    uint256 public immutable override itemCount;
    bytes32 public immutable managerCodeHash;
    bytes32 public immutable houseCodeHash;
    error InvalidCuratedPublication();
    error InvalidCuratedMint();
    event CuratedManifestPublished(
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
        ) revert InvalidCuratedPublication();
        bytes32[] memory level = new bytes32[](rows.length);
        for (uint256 n; n < rows.length; ++n) {
            if (
                (n != 0 && rows[n - 1].contentId >= rows[n].contentId) || rows[n].tokenDataHash == 0
                    || bytes(rows[n].previewURI).length == 0
            ) revert InvalidCuratedPublication();
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
                keccak256("6529STREAM_NATIVE_AUCTION_CONTENT_GATE_V1"),
                _publication,
                managerCodeHash,
                houseCodeHash
            )
        );
        emit CuratedManifestPublished(
            saleId, level[0], _publication.manifestHash, rows.length, _manifest
        );
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IStreamMintGate).interfaceId
            || id == type(IStreamNativeAuctionContentGate).interfaceId;
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
                || phaseId != p.phaseId || payer == address(0) || authorizer != address(0)
                || initialRecipients.length != 1 || initialRecipients[0] != p.house
                || beneficiaries.length != 1 || beneficiaries[0] == address(0)
                || expectedPolicyHash == 0
        ) revert InvalidCuratedMint();
        StreamPreparedNativeContentTypes.GateData memory d =
            abi.decode(gateData, (StreamPreparedNativeContentTypes.GateData));
        bytes32 selected = StreamPreparedNativeContentHash.leaf(
            p.chainId, p.house, p.saleId, d.selection.contentId, d.selection.tokenDataHash
        );
        if (
            keccak256(gateData) != keccak256(abi.encode(d)) || d.authorizationId == 0
                || contextHash
                    != StreamPreparedNativeContentHash.context(
                        p.chainId, p.house, p.saleId, d.selection.contentId
                    ) || !MerkleProof.verify(d.selection.proof, p.manifestRoot, selected)
        ) revert InvalidCuratedMint();
        StreamPreparedNativeContentTypes.Facts memory admitted =
            StreamPreparedNativeContentTypes.Facts(
                0,
                address(this),
                address(this).codehash,
                gateConfigHash,
                p.manifestRoot,
                p.manifestHash,
                p.counterId,
                d.selection.contentId,
                d.selection.tokenDataHash,
                selected,
                contextHash
            );
        if (
            IStreamPreparedNativeContentMint(manager).preparedNativeContentAdmission()
                != StreamPreparedNativeContentHash.admissionHash(
                    p.house, d.authorizationId, admitted
                )
        ) revert InvalidCuratedMint();
        r.authorizationId = d.authorizationId;
        r.nullifiers = new bytes32[](0);
        r.maxQuantity = 1;
        r.gateHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_AUCTION_CONTENT_ADMISSION_V1"),
                gateConfigHash,
                selected,
                contextHash,
                expectedPolicyHash,
                keccak256(gateData)
            )
        );
    }
}
