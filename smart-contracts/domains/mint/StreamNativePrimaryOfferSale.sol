// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeCuratedSaleBase.sol";
import "./StreamNativePrimaryOfferSupport.sol";
import "./StreamNativePrimaryOfferAuthorization.sol";
import "./StreamNativePrimaryOfferAdmission.sol";
import "./StreamNativePrimaryOfferExecution.sol";
import "./StreamNativePrimaryOfferSettlement.sol";
import "../../interfaces/stream/mint/IStreamNativePrimaryOfferSale.sol";
import "../../interfaces/stream/mint/IStreamPreparedNativeOfferMint.sol";
import { StreamNativeAuctionDelegation as D } from "../auctions/StreamNativeAuctionDelegation.sol";

/// @notice Buyer-initiated native primary mint offer, with independent seller and buyer replay loci.
/// @dev The signed executor supplies msg.value, including the reveal allowance. Delivery and
/// excess credits belong to the immutable buyer. Every failed mint or delivery rolls back both loci.
contract StreamNativePrimaryOfferSale is
    StreamNativeCuratedSaleBase,
    IStreamNativePrimaryOfferSale
{
    mapping(bytes32 => StreamNativePrimaryOfferTypes.Configuration) private _offers;
    mapping(uint256 => mapping(address => mapping(uint8 => Curated.CollectionSigner))) private
        _signers;
    mapping(bytes32 => bool) public override digestConsumed;
    mapping(bytes32 => bool) public override digestRevoked;
    bytes32 private _activeOfferDigest;

    error InvalidPrimaryOffer();
    error PrimaryOfferDigestConsumed(bytes32 digest);
    error PrimaryOfferSignerUnavailable();
    event PrimaryOfferConfigured(
        bytes32 indexed saleId,
        bytes32 indexed configHash,
        StreamNativePrimaryOfferTypes.Configuration configuration
    );
    event PrimaryOfferCollectionSigner(
        uint256 indexed collectionId,
        address indexed signer,
        uint8 kind,
        bytes32 evidenceHash,
        uint64 revision,
        bool enabled,
        address authority
    );
    event SaleAuthorizationConsumed(
        uint16 schemaVersion, bytes32 indexed saleId, bytes32 indexed digest, address authorizer
    );
    event SaleAuthorizationRevoked(
        uint16 schemaVersion, bytes32 indexed saleId, bytes32 indexed digest, address authorizer
    );
    event OfferAccepted(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed buyer,
        bytes32 offerDigest,
        uint256 price,
        address asset
    );
    event PrimaryOfferExpired(bytes32 indexed saleId);

    constructor(DeploymentConfig memory d) StreamNativeCuratedSaleBase(d) { }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamNativePrimaryOfferSale).interfaceId
            || id == type(IStreamPreparedNativeOfferSale).interfaceId || super.supportsInterface(id);
    }

    function eip712Domain()
        external
        view
        override
        returns (bytes1, string memory, string memory, uint256, address, bytes32, uint256[] memory)
    {
        bytes memory out = StreamNativeCuratedSaleReadEncoding.privateDomain();
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function configureCollectionSigner(
        uint256 collection,
        address signer,
        uint8 kind,
        bytes32 evidence,
        bool enabled
    ) external onlyOwner nonReentrant {
        _requireCuratedContext();
        if (collection == 0 || signer == address(0) || (kind != 1 && kind != 2) || evidence == 0) {
            revert InvalidPrimaryOffer();
        }
        Curated.CollectionSigner storage s = _signers[collection][signer][kind];
        s.evidenceHash = evidence;
        s.revision += 1;
        s.enabled = enabled;
        s.authority = msg.sender;
        emit PrimaryOfferCollectionSigner(
            collection, signer, kind, evidence, s.revision, enabled, msg.sender
        );
    }

    function collectionSigner(uint256 collection, address signer, uint8 kind)
        external
        view
        returns (Curated.CollectionSigner memory)
    {
        return _signers[collection][signer][kind];
    }

    function primaryOfferConfigurationHash(StreamNativePrimaryOfferTypes.Configuration calldata c)
        external
        view
        override
        returns (bytes32)
    {
        return StreamNativePrimaryOfferSupport.configurationHash(c);
    }

    function primaryOfferConfiguration(bytes32 id)
        external
        view
        override
        returns (StreamNativePrimaryOfferTypes.Configuration memory)
    {
        return _offers[id];
    }

    function registerPrimaryOffer(
        StreamNativePrimaryOfferTypes.Configuration calldata c,
        bytes32[] calldata proof
    ) external override onlyOwner nonReentrant returns (bytes32 id) {
        _requireCuratedContext();
        _requireRefundDelegationManifest();
        StreamNativePrimaryOfferAdmission.requireSigner(_signers, c);
        id = StreamNativePrimaryOfferSupport.register(_state, _support(), c, proof);
        _offers[id] = c;
        emit PrimaryOfferConfigured(id, _state.sales[id].configHash, c);
    }

    /// @notice Immutable historical evidence; live signer disablement never erases membership.
    function primaryOfferAuthorizationBinding(bytes32 id)
        external
        view
        override
        returns (uint256, bytes32, address, uint8, bytes32)
    {
        StreamNativePrimaryOfferTypes.Configuration storage c = _offers[id];
        if (_state.sales[id].status == 0) revert InvalidPrimaryOffer();
        return (
            c.sale.collectionId, c.sale.phaseId, c.signer, c.signerKind, _state.sales[id].configHash
        );
    }

    function authorizationDigest(StreamPrivateSaleTypes.SaleAuthorization calldata a)
        public
        view
        returns (bytes32)
    {
        return StreamPrivateSaleHash.digest(
            block.chainid, address(this), StreamPrivateSaleHash.authorizationBody(a)
        );
    }

    function offerDigest(StreamPrivateSaleTypes.SaleOffer calldata o)
        public
        view
        returns (bytes32)
    {
        return StreamPrivateSaleHash.digest(
            block.chainid, address(this), StreamPrivateSaleHash.offerBody(o)
        );
    }

    function acceptPrimaryOffer(StreamNativePrimaryOfferTypes.Acceptance calldata q)
        external
        payable
        override
        nonReentrant
        returns (Curated.ExecutionRecord memory result)
    {
        bytes32 id = q.authorization.saleId;
        StreamNativePrimaryOfferTypes.Configuration memory c = _offers[id];
        // Hashing and this append-only write precede every linked call, signature check and
        // provider read. Invalid presentations revert the write and its event atomically.
        bytes32 sellerDigest = authorizationDigest(q.authorization);
        _consume(id, sellerDigest, q.sellerProof.authorizer);
        bytes32 buyerDigest = StreamNativePrimaryOfferAdmission.validate(
            _state, _signers, _runtime(), c, q, sellerDigest
        );
        _reservePurchaseNonce(id, c.buyer, q.selection.purchaseNonce);
        _activeOfferDigest = buyerDigest;
        result = StreamNativePrimaryOfferExecution.execute(
            _state, _runtime(), q, buyerDigest, sellerDigest
        );
        StreamNativePrimaryOfferAdmission.requireSigner(_signers, c);
        StreamNativePrimaryOfferAdmission.requireDelegations(c.buyer, q);
        _state.sales[id].status = 4;
        delete _activeOfferDigest;
        emit OfferAccepted(1, id, c.buyer, buyerDigest, c.sale.price, address(0));
    }

    function revokeAuthorization(
        StreamPrivateSaleTypes.SaleAuthorization calldata a,
        IStreamPrivateSaleAdapter.Signature calldata proof
    ) external override nonReentrant {
        StreamNativePrimaryOfferTypes.Configuration storage c = _offers[a.saleId];
        bytes32 digest = authorizationDigest(a);
        if (digestConsumed[digest]) revert PrimaryOfferDigestConsumed(digest);
        digestConsumed[digest] = true;
        StreamNativePrimaryOfferAdmission.revoke(
            _state.sales[a.saleId].status != 0, address(mintManager), c, a, proof, digest
        );
        digestRevoked[digest] = true;
        emit SaleAuthorizationRevoked(1, a.saleId, digest, proof.authorizer);
    }

    function expirePrimaryOffer(bytes32 id) external nonReentrant {
        Curated.SaleRecord storage s = _state.sales[id];
        if (s.saleKind != 6 || s.status != 1 || block.timestamp <= s.config.endsAt) {
            revert InvalidPrimaryOffer();
        }
        s.status = 3;
        emit PrimaryOfferExpired(id);
    }

    function activePreparedNativeOfferIntent(bytes32 hash)
        external
        view
        returns (Prepared.Intent memory)
    {
        if (hash == 0 || hash != _state.active.intentHash) revert InvalidPrimaryOffer();
        return _state.active.intent;
    }

    function activePreparedNativeOfferPurchase(bytes32 hash)
        external
        view
        returns (StreamPreparedNativeOfferTypes.Purchase memory)
    {
        if (hash == 0 || hash != _state.active.intentHash || _activeOfferDigest == 0) {
            revert InvalidPrimaryOffer();
        }
        PurchaseTypes.Purchase storage p = _state.active.purchase;
        return StreamPreparedNativeOfferTypes.Purchase(
            p.saleId,
            p.saleNonce,
            p.saleConfigHash,
            p.purchaseId,
            p.buyer,
            p.purchaseNonce,
            p.authorizationId,
            p.authorizer,
            p.authorizerKind,
            p.primaryPolicyMode,
            _activeOfferDigest
        );
    }

    function onPreparedNativeOfferMint(Prepared.Facts calldata facts)
        external
        returns (bytes4, Primary.PrimarySettlementResult memory)
    {
        bytes memory out = StreamNativePrimaryOfferSettlement.callback(_state, _runtime(), facts);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function _consume(bytes32 id, bytes32 digest, address signer) private {
        if (digestConsumed[digest]) revert PrimaryOfferDigestConsumed(digest);
        digestConsumed[digest] = true;
        emit SaleAuthorizationConsumed(1, id, digest, signer);
    }
}
