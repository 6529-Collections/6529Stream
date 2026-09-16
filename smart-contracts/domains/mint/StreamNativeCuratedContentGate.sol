// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamPreparedNativeContentPurchaseGate
} from "../../interfaces/stream/mint/IStreamPreparedNativeContentPurchaseGate.sol";
import {
    IStreamPreparedNativeContentPurchaseSale
} from "../../interfaces/stream/mint/IStreamPreparedNativeContentPurchaseMint.sol";
import {
    StreamPreparedNativeContentPurchaseTypes
} from "../../interfaces/stream/mint/StreamPreparedNativeContentPurchaseTypes.sol";
import {
    IStreamNativeCuratedSaleBinding
} from "../../interfaces/stream/mint/IStreamNativeCuratedSaleBinding.sol";
import { StreamPrivateSaleTypes } from "../../interfaces/stream/mint/StreamPrivateSaleTypes.sol";
import {
    IStreamPrivateSaleAdapter
} from "../../interfaces/stream/mint/IStreamPrivateSaleAdapter.sol";
import {
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import { StreamPrivateSaleSupport } from "./StreamPrivateSaleSupport.sol";
import { StreamPrivateSaleHash } from "./StreamPrivateSaleHash.sol";
import { StreamMintTicketHash } from "./StreamMintTicketHash.sol";
import { StreamPreparedNativeContentHash } from "./StreamPreparedNativeContentHash.sol";
import {
    IStreamPreparedNativeContentMint,
    IStreamPreparedNativeContentSale
} from "../../interfaces/stream/mint/IStreamPreparedNativeContentMint.sol";
import {
    StreamPreparedNativeContentTypes
} from "../../interfaces/stream/mint/StreamPreparedNativeContentTypes.sol";
import {
    StreamPreparedNativeSettlementTypes
} from "../../interfaces/stream/revenue/StreamPreparedNativeSettlementTypes.sol";
import { MerkleProof } from "../../vendor/openzeppelin/MerkleProof.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import { IStreamMintGate } from "../../interfaces/stream/mint/IStreamMintGate.sol";

/// @notice Immutable complete pre-sale manifest, selected by the actual phase and original sale.
/// @dev Publication is a declaration of preview references, not offchain availability evidence.
contract StreamNativeCuratedContentGate is IStreamPreparedNativeContentPurchaseGate {
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
                keccak256("6529STREAM_NATIVE_CONTENT_PURCHASE_GATE_V1"),
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
            || id == type(IStreamPreparedNativeContentPurchaseGate).interfaceId;
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

    function contentPurchaseVersion() external pure override returns (bytes32) {
        return keccak256("6529STREAM_NATIVE_CONTENT_PURCHASE_GATE_V1");
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
                || beneficiaries.length != 1 || beneficiaries[0] == address(0)
                || expectedPolicyHash == 0
        ) revert InvalidCuratedMint();
        StreamPreparedNativeContentPurchaseTypes.GateData memory d =
            abi.decode(gateData, (StreamPreparedNativeContentPurchaseTypes.GateData));
        if (
            keccak256(gateData) != keccak256(abi.encode(d)) || d.intentHash == 0
                || d.authorizationId == 0
        ) revert InvalidCuratedMint();
        StreamPreparedNativeContentTypes.Facts memory content = _content(p, d, contextHash);
        StreamPreparedNativeContentPurchaseTypes.Purchase memory purchase =
            IStreamPreparedNativeContentPurchaseSale(p.house)
                .activePreparedNativeContentPurchase(d.intentHash);
        StreamPreparedNativeSettlementTypes.Intent memory intent = IStreamPreparedNativeContentSale(
                p.house
            ).activePreparedNativeContentIntent(d.intentHash);
        if (
            purchase.saleId != p.saleId || purchase.saleNonce == 0 || purchase.saleConfigHash == 0
                || purchase.buyer != payer || purchase.purchaseNonce == 0
                || purchase.authorizationId != d.authorizationId
                || purchase.authorizer != authorizer
                || purchase.purchaseId
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_SALE_PURCHASE_V1"),
                            p.chainId,
                            p.house,
                            p.saleId,
                            payer,
                            purchase.purchaseNonce
                        )
                    ) || intent.collectionId != p.collectionId || intent.phaseId != p.phaseId
                || intent.saleId != p.saleId || intent.saleNonce != purchase.saleNonce
                || intent.payer != payer || intent.beneficiary != beneficiaries[0]
                || intent.executionNonce != purchase.purchaseNonce || intent.amount == 0
                || intent.contentSelectionHash != content.contentLeaf
                || intent.boundMintPolicyHash != expectedPolicyHash
                || intent.primaryPolicyMode != purchase.primaryPolicyMode
                || intent.mintCommitment == 0
        ) revert InvalidCuratedMint();
        if (intent.authorityMode == 2) {
            StreamPrivateSaleTypes.SaleAuthorization memory empty;
            if (
                authorizer != address(0) || purchase.authorizerKind != 0
                    || d.authorizationId != d.intentHash
                    || keccak256(abi.encode(d.authorization)) != keccak256(abi.encode(empty))
                    || d.signature.authorizer != address(0) || d.signature.kind != 0
                    || d.signature.signature.length != 0
            ) revert InvalidCuratedMint();
        } else if (intent.authorityMode == 1) {
            _private(p, d, purchase, intent, initialRecipients, beneficiaries);
        } else {
            revert InvalidCuratedMint();
        }
        bytes32 admission = keccak256(
            abi.encode(
                keccak256("6529STREAM_PREPARED_NATIVE_CONTENT_PURCHASE_ADMISSION_V1"),
                block.chainid,
                p.house,
                d.intentHash,
                purchase,
                content
            )
        );
        if (IStreamPreparedNativeContentMint(manager).preparedNativeContentAdmission() != admission)
        {
            revert InvalidCuratedMint();
        }
        r.authorizationId = d.authorizationId;
        r.authorizer = purchase.authorizer;
        r.authorizerKind = purchase.authorizerKind;
        r.nullifiers = new bytes32[](0);
        r.maxQuantity = 1;
        r.gateHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CONTENT_PURCHASE_GATE_RESULT_V1"),
                gateConfigHash,
                admission,
                expectedPolicyHash,
                keccak256(gateData)
            )
        );
    }

    function _content(
        StreamPreparedNativeContentTypes.Publication memory p,
        StreamPreparedNativeContentPurchaseTypes.GateData memory d,
        bytes32 contextHash
    ) private view returns (StreamPreparedNativeContentTypes.Facts memory c) {
        bytes32 leaf = StreamPreparedNativeContentHash.leaf(
            p.chainId, p.house, p.saleId, d.selection.contentId, d.selection.tokenDataHash
        );
        if (
            d.selection.tokenDataHash == 0
                || contextHash
                    != StreamPreparedNativeContentHash.context(
                        p.chainId, p.house, p.saleId, d.selection.contentId
                    ) || !MerkleProof.verify(d.selection.proof, p.manifestRoot, leaf)
        ) revert InvalidCuratedMint();
        c = StreamPreparedNativeContentTypes.Facts(
            0,
            address(this),
            address(this).codehash,
            gateConfigHash,
            p.manifestRoot,
            p.manifestHash,
            p.counterId,
            d.selection.contentId,
            d.selection.tokenDataHash,
            leaf,
            contextHash
        );
    }

    /// @dev Manager admission independently checks raw tokenData and commitment array hashes
    /// against its actual batch; IStreamMintGate itself receives only the address arrays.
    function _private(
        StreamPreparedNativeContentTypes.Publication memory p,
        StreamPreparedNativeContentPurchaseTypes.GateData memory d,
        StreamPreparedNativeContentPurchaseTypes.Purchase memory purchase,
        StreamPreparedNativeSettlementTypes.Intent memory intent,
        address[] calldata initialRecipients,
        address[] calldata beneficiaries
    ) private view {
        (uint256 collection, bytes32 phase, address signer, uint8 kind, bytes32 configHash) =
            IStreamNativeCuratedSaleBinding(p.house).curatedSaleAuthorizationBinding(p.saleId);
        StreamPrivateSaleTypes.SaleAuthorization memory a = d.authorization;
        bytes32 digest = StreamPrivateSaleHash.digest(
            p.chainId, p.house, StreamPrivateSaleHash.authorizationBody(a)
        );
        bytes32[] memory commitments = new bytes32[](1);
        commitments[0] = intent.mintCommitment;
        if (
            collection != p.collectionId || phase != p.phaseId
                || configHash != purchase.saleConfigHash || signer == address(0)
                || (kind != 1 && kind != 2) || signer != purchase.authorizer
                || kind != purchase.authorizerKind || d.signature.authorizer != signer
                || d.signature.kind != kind || a.chainId != p.chainId || a.saleAdapter != p.house
                || a.mintManager != p.manager || a.collectionId != p.collectionId
                || a.phaseId != p.phaseId || a.saleId != p.saleId || a.saleKind != 5
                || a.revenueClass != keccak256("PRIMARY_SALE")
                || a.expectedPrimaryPolicyHash != intent.originalPrimaryPolicyHash
                || a.primaryPolicyMode != intent.primaryPolicyMode || a.payer != purchase.buyer
                || a.executor != intent.executor || a.asset != address(0)
                || a.unitPrice != intent.amount || a.quantity != 1
                || a.contentSelectionHash != intent.contentSelectionHash
                || a.policyHash != intent.boundMintPolicyHash || a.nonce == 0
                || a.deadline < block.timestamp || a.finalizeBy != 0
                || a.initialRecipientsHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), initialRecipients
                        )
                    )
                || a.beneficiariesHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), beneficiaries
                        )
                    )
                || a.mintCommitmentsHash
                    != keccak256(
                        abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), commitments)
                    ) || intent.saleAuthorizationDigest != digest
                || d.authorizationId != StreamMintTicketHash.authorizationId(digest)
        ) revert InvalidCuratedMint();
        uint256 cap = IStreamGasParameterHost(p.house)
            .gasParameter(keccak256("6529STREAM_GGP_SALE_ERC1271_GAS_LIMIT"));
        if (
            cap == 0 || cap > type(uint64).max
                || !StreamPrivateSaleSupport.validSignature(
                    signer, kind, digest, d.signature.signature, cap
                )
        ) revert InvalidCuratedMint();
    }
}
