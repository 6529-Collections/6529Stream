// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamNativeCuratedSaleBase } from "./StreamNativeCuratedSaleBase.sol";
import { StreamNativeCuratedSaleReadEncoding } from "./StreamNativeCuratedSaleReadEncoding.sol";
import { StreamNativeCuratedSaleState } from "./StreamNativeCuratedSaleState.sol";
import { StreamNativeCuratedSaleHash } from "./StreamNativeCuratedSaleHash.sol";
import {
    StreamNativeCuratedPrivateAuthorization
} from "./StreamNativeCuratedPrivateAuthorization.sol";
import { StreamPreparedNativeContentHash } from "./StreamPreparedNativeContentHash.sol";
import { StreamPrivateSaleHash } from "./StreamPrivateSaleHash.sol";
import { StreamMintTicketHash } from "./StreamMintTicketHash.sol";
import {
    StreamNativeCuratedSaleTypes as Curated
} from "../../interfaces/stream/mint/StreamNativeCuratedSaleTypes.sol";
import { StreamPrivateSaleTypes } from "../../interfaces/stream/mint/StreamPrivateSaleTypes.sol";
import {
    IStreamPrivateSaleAdapter
} from "../../interfaces/stream/mint/IStreamPrivateSaleAdapter.sol";
import {
    IStreamNativeCuratedPrivateSale
} from "../../interfaces/stream/mint/IStreamNativeCuratedPrivateSale.sol";
import {
    IStreamNativeCuratedSaleBinding
} from "../../interfaces/stream/mint/IStreamNativeCuratedSaleBinding.sol";
import { IStreamMintManager } from "../../interfaces/stream/mint/IStreamMintManager.sol";
import { MerkleProof } from "../../vendor/openzeppelin/MerkleProof.sol";

/// @notice One canonical signed PRIVATE_SALE for an immutable buyer and selected content leaf.
/// @dev Strict original PROFILE policy. Native delegates fund the buyer's purchase and credits;
/// successful final delivery is atomic. The older custody-only private sale remains independent.
contract StreamNativeCuratedPrivateSale is
    StreamNativeCuratedSaleBase,
    IStreamNativeCuratedPrivateSale,
    IStreamNativeCuratedSaleBinding
{
    mapping(bytes32 => Curated.PrivateConfiguration) private _private;
    mapping(uint256 => mapping(address => mapping(uint8 => Curated.CollectionSigner))) private
        _signers;

    error CuratedPrivateConfigurationInvalid();
    error CuratedPrivateSignerUnavailable();
    error CuratedPrivateSelectionMismatch();
    event CuratedCollectionSignerConfigured(
        uint256 indexed collectionId,
        address indexed signer,
        uint8 indexed signerKind,
        bytes32 evidenceHash,
        uint64 revision,
        bool enabled,
        address authority
    );
    event CuratedPrivateTerms(
        bytes32 indexed saleId, bytes32 indexed configHash, Curated.PrivateConfiguration config
    );
    event CuratedPrivateSaleCompleted(
        bytes32 indexed saleId, bytes32 indexed purchaseId, address indexed buyer, uint256 tokenId
    );
    event CuratedPrivateSaleExpired(bytes32 indexed saleId);

    constructor(DeploymentConfig memory deployment) StreamNativeCuratedSaleBase(deployment) { }

    function eip712Domain()
        external
        view
        override
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        bytes memory out = StreamNativeCuratedSaleReadEncoding.privateDomain();
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamNativeCuratedPrivateSale).interfaceId
            || id == type(IStreamNativeCuratedSaleBinding).interfaceId
            || super.supportsInterface(id);
    }

    function configureCollectionSigner(
        uint256 collectionId,
        address signer,
        uint8 kind,
        bytes32 evidenceHash,
        bool enabled
    ) external override onlyOwner nonReentrant {
        _requireCuratedContext();
        if (
            collectionId == 0 || signer == address(0) || (kind != 1 && kind != 2)
                || evidenceHash == 0
        ) revert CuratedPrivateConfigurationInvalid();
        Curated.CollectionSigner storage s = _signers[collectionId][signer][kind];
        s.evidenceHash = evidenceHash;
        s.revision += 1;
        s.enabled = enabled;
        s.authority = msg.sender;
        emit CuratedCollectionSignerConfigured(
            collectionId, signer, kind, evidenceHash, s.revision, enabled, msg.sender
        );
    }

    function collectionSigner(uint256 collectionId, address signer, uint8 kind)
        external
        view
        override
        returns (Curated.CollectionSigner memory)
    {
        return _signers[collectionId][signer][kind];
    }

    function privateConfigurationHash(Curated.PrivateConfiguration calldata config)
        external
        view
        override
        returns (bytes32)
    {
        return StreamNativeCuratedSaleHash.privateConfig(config);
    }

    function privateSaleConfiguration(bytes32 id)
        external
        view
        override
        returns (Curated.PrivateConfiguration memory)
    {
        return _private[id];
    }

    function registerCuratedPrivateSale(
        Curated.PrivateConfiguration calldata config,
        bytes32[] calldata selectedProof
    ) external override onlyOwner nonReentrant returns (bytes32 id) {
        if (
            config.buyer == address(0) || config.buyer == address(this) || config.tokenDataHash == 0
                || config.sale.price == 0 || config.sale.primaryPolicyMode != 0
        ) revert CuratedPrivateConfigurationInvalid();
        _requireSigner(config);
        id = saleIdFor(5, config.sale.collectionId, config.sale.phaseId, _state.nextSaleNonce);
        bytes32 leaf = StreamPreparedNativeContentHash.leaf(
            block.chainid, address(this), id, config.contentId, config.tokenDataHash
        );
        if (!MerkleProof.verify(selectedProof, config.sale.contentManifestRoot, leaf)) {
            revert CuratedPrivateSelectionMismatch();
        }
        bytes32 hash = StreamNativeCuratedSaleHash.privateConfig(config);
        id = _registerCommon(config.sale, 5, hash);
        _private[id] = config;
        emit CuratedPrivateTerms(id, hash, config);
    }

    /// @notice Historical immutable membership; neither expiry nor later signer revocation erases it.
    function curatedSaleAuthorizationBinding(bytes32 id)
        external
        view
        override
        returns (uint256, bytes32, address, uint8, bytes32)
    {
        Curated.PrivateConfiguration storage c = _private[id];
        if (_state.sales[id].status == 0) revert CuratedSaleUnavailable(id);
        return (
            c.sale.collectionId, c.sale.phaseId, c.signer, c.signerKind, _state.sales[id].configHash
        );
    }

    function purchasePrivateContent(
        StreamPrivateSaleTypes.SaleAuthorization calldata authorization,
        IStreamPrivateSaleAdapter.Signature calldata signature,
        Curated.Selection calldata chosen,
        DelegationWitness calldata witness
    ) external payable override nonReentrant returns (Curated.ExecutionRecord memory result) {
        bytes32 id = authorization.saleId;
        Curated.SaleRecord storage sale = _requireSale(id);
        Curated.PrivateConfiguration memory config = _private[id];
        _requireBuyer(config.buyer, witness);
        _requireSigner(config);
        if (
            sale.saleKind != 5 || chosen.recipient != config.buyer
                || chosen.content.contentId != config.contentId
                || chosen.content.tokenDataHash != config.tokenDataHash
        ) revert CuratedPrivateSelectionMismatch();
        bytes32 digest = StreamPrivateSaleHash.digest(
            block.chainid, address(this), StreamPrivateSaleHash.authorizationBody(authorization)
        );
        bytes32 authorizationId = StreamMintTicketHash.authorizationId(digest);
        IStreamMintManager.MintBatch memory batch =
            _batch(id, config.buyer, chosen, authorizationId, signature.authorizer);
        StreamNativeCuratedPrivateAuthorization.Terms memory terms =
            StreamNativeCuratedPrivateAuthorization.Terms(
                id,
                config.sale.collectionId,
                config.sale.phaseId,
                config.buyer,
                config.sale.price,
                config.sale.startsAt,
                config.sale.endsAt,
                StreamPreparedNativeContentHash.leaf(
                    block.chainid, address(this), id, config.contentId, config.tokenDataHash
                ),
                config.sale.mintPolicyHash,
                config.sale.primaryPolicyMode,
                config.sale.expectedPrimaryPolicyHash,
                config.signer,
                config.signerKind
            );
        (bytes32 validatedDigest, bytes32 validatedId) = StreamNativeCuratedPrivateAuthorization.validate(
            StreamNativeCuratedPrivateAuthorization.Context(
                address(mintManager), gasParameter(CURATED_SIGNATURE_GAS)
            ),
            terms,
            authorization,
            signature,
            batch
        );
        if (validatedDigest != digest || validatedId != authorizationId) {
            revert CuratedPrivateConfigurationInvalid();
        }
        _reservePurchaseNonce(id, config.buyer, chosen.purchaseNonce);
        StreamNativeCuratedSaleState.Request memory request = StreamNativeCuratedSaleState.Request(
            id, config.buyer, chosen, 1, digest, authorization, signature, false
        );
        result = _execute(request);
        _requireBuyer(config.buyer, witness);
        _requireSigner(config);
        sale.status = 4;
        emit CuratedPrivateSaleCompleted(
            id, purchaseIdFor(id, config.buyer, chosen.purchaseNonce), config.buyer, result.tokenId
        );
    }

    function expirePrivateSale(bytes32 id) external override nonReentrant {
        Curated.SaleRecord storage sale = _state.sales[id];
        if (sale.saleKind != 5 || sale.status != 1 || block.timestamp <= sale.config.endsAt) {
            revert CuratedSaleUnavailable(id);
        }
        sale.status = 3;
        emit CuratedPrivateSaleExpired(id);
    }

    function _requireSigner(Curated.PrivateConfiguration memory config) private view {
        Curated.CollectionSigner storage s =
            _signers[config.sale.collectionId][config.signer][config.signerKind];
        if (
            config.signer == address(0) || (config.signerKind != 1 && config.signerKind != 2)
                || !s.enabled || s.revision == 0 || s.revision != config.signerRevision
                || s.evidenceHash != config.signerEvidenceHash
                || s.authority != config.signerAuthority || s.authority == address(0)
        ) revert CuratedPrivateSignerUnavailable();
    }
}
