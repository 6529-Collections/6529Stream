// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPrivateSaleSupport.sol";
import "./StreamPrivateSaleAccounting.sol";
import "./StreamPrivateSaleCustody.sol";
import "./StreamPrivateSaleHash.sol";
import "../../interfaces/stream/mint/IStreamPrivateSaleAdapter.sol";
import "../parameters/StreamGasParameterHost.sol";
import "../../vendor/openzeppelin/Ownable.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../../vendor/openzeppelin/ERC165.sol";

/// @notice Buyer-bound native secondary custody sales with full-payload authorizations.
/// @dev The owner explicitly configures each collection's singleton signer set. Royalty credits,
///      consignor proceeds and buyer excess are separate perpetual claims. No primary mint occurs.
contract StreamPrivateSaleAdapter is
    IStreamPrivateSaleAdapter,
    StreamGasParameterHost,
    Ownable,
    ReentrancyGuard,
    ERC165
{
    using StreamPrivateSaleSupport for StreamPrivateSaleSupport.Context;

    struct DeploymentConfig {
        address core;
        address moduleRegistry;
        address platformSigner;
        address configurationOwner;
        address governanceAuthority;
        address roleRegistry;
        GasParameterConfig[3] parameters;
    }

    bytes32 private constant _SIGNATURE_GAS = keccak256("6529STREAM_GGP_SALE_ERC1271_GAS_LIMIT");
    bytes32 private constant _NFT_GAS = keccak256("6529STREAM_GGP_SALE_NFT_DELIVERY_GAS_LIMIT");
    bytes32 private constant _ROYALTY_GAS =
        keccak256("6529STREAM_GGP_SALE_ROYALTY_DELIVERY_GAS_LIMIT");
    bytes32 private constant _REVOKED = keccak256("CUSTODY_GRANT_REVOKED");
    bytes32 private constant _EXPIRED = keccak256("PRIVATE_SALE_EXPIRED");
    bytes32 private constant _CANCELLED = keccak256("PRIVATE_SALE_CANCELLED");
    address public immutable override core;
    address public immutable moduleRegistry;
    address public immutable platformSigner;
    bytes32 public immutable coreCodeHash;
    bytes32 public immutable registryCodeHash;
    address public immutable roleRegistry;
    bytes32 public immutable roleRegistryCodeHash;
    bool public paused;
    mapping(bytes32 => bool) public salePaused;
    uint256 public nextSaleNonce = 1;
    StreamPrivateSaleAccounting.State private _money;
    mapping(uint256 => CollectionSigner) public collectionSigner;
    mapping(bytes32 => Sale) private _sales;
    mapping(bytes32 => bool) public digestConsumed;
    mapping(bytes32 => bool) public digestRevoked;
    // Association only; full grant presentation still authenticates every revocation.
    mapping(bytes32 => bytes32) private _custodySale;

    constructor(DeploymentConfig memory d) StreamGasParameterHost(d.governanceAuthority) {
        if (
            !StreamSettlementAdmission.isContract(d.core)
                || !StreamSettlementAdmission.isContract(d.moduleRegistry)
                || d.platformSigner == address(0) || d.configurationOwner == address(0)
                || d.governanceAuthority == address(0)
                || !StreamSettlementAdmission.isContract(d.roleRegistry)
                || StreamPrivateSaleSupport.readWord(
                        d.moduleRegistry, abi.encodeWithSignature("governanceExecutor()")
                    ) != uint256(uint160(d.governanceAuthority))
                || StreamPrivateSaleSupport.readWord(
                        d.governanceAuthority, abi.encodeWithSignature("roleRegistry()")
                    ) != uint256(uint160(d.roleRegistry))
                || StreamPrivateSaleSupport.readWord(
                        d.roleRegistry, abi.encodeWithSignature("owner()")
                    ) != uint256(uint160(d.governanceAuthority))
                || !StreamPrivateSaleSupport.interfaceSupported(d.core, type(IERC721).interfaceId)
                || !StreamPrivateSaleSupport.interfaceSupported(d.core, type(IERC2981).interfaceId)
        ) {
            revert InvalidPrivateSale();
        }
        core = d.core;
        moduleRegistry = d.moduleRegistry;
        platformSigner = d.platformSigner;
        coreCodeHash = d.core.codehash;
        registryCodeHash = d.moduleRegistry.codehash;
        roleRegistry = d.roleRegistry;
        roleRegistryCodeHash = d.roleRegistry.codehash;
        StreamSettlementAdmission.requireRegistry(
            d.core, coreCodeHash, d.moduleRegistry, registryCodeHash
        );
        if (
            keccak256(bytes(d.parameters[0].name)) != keccak256("SALE_ERC1271_GAS_LIMIT")
                || keccak256(bytes(d.parameters[1].name))
                    != keccak256("SALE_NFT_DELIVERY_GAS_LIMIT")
                || keccak256(bytes(d.parameters[2].name))
                    != keccak256("SALE_ROYALTY_DELIVERY_GAS_LIMIT")
        ) {
            revert InvalidPrivateSale();
        }
        for (uint256 i; i < 3; ++i) {
            if (d.parameters[i].failureClass != FAILURE_CLASS_FAIL_CLOSED_PRECHECK) {
                revert InvalidPrivateSale();
            }
            _registerGasParameter(d.parameters[i]);
        }
        if (gasParameter(_ROYALTY_GAS) < 2300) revert InvalidPrivateSale();
        _transferOwnership(d.configurationOwner);
    }

    function supportsInterface(bytes4 id) public view override(IERC165, ERC165) returns (bool) {
        return id == type(IStreamPrivateSaleAdapter).interfaceId || super.supportsInterface(id);
    }

    function streamModuleType() external pure override returns (bytes32) {
        return keccak256("PRIVATE_SALE_ADAPTER");
    }

    function streamModuleInterfaceId() external pure override returns (bytes4) {
        return type(IStreamPrivateSaleAdapter).interfaceId;
    }

    function streamModuleVersion() external pure returns (bytes32) {
        return keccak256("6529STREAM_NATIVE_CONSIGNMENT_V1");
    }

    function configureCollectionSigner(uint256 collectionId, bytes32 evidenceHash, bool enabled)
        external
        onlyOwner
        nonReentrant
    {
        if (collectionId == 0 || evidenceHash == 0) revert InvalidPrivateSale();
        _context().requireAdmission(0, 0);
        CollectionSigner storage signer = collectionSigner[collectionId];
        ++signer.revision;
        signer.evidenceHash = evidenceHash;
        signer.enabled = enabled;
        signer.authority = msg.sender;
        emit CollectionSaleSignerConfigured(
            1, collectionId, platformSigner, evidenceHash, signer.revision, enabled, msg.sender
        );
    }

    function saleIdFor(uint8 kind, uint256 collectionId, uint256 nonce)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_V1"),
                block.chainid,
                address(this),
                kind,
                collectionId,
                bytes32(0),
                nonce
            )
        );
    }

    function registerSale(SaleConfig calldata config)
        external
        onlyOwner
        nonReentrant
        returns (bytes32 id)
    {
        CollectionSigner memory signer = collectionSigner[config.collectionId];
        StreamPrivateSaleSupport.validateConfig(config, signer);
        StreamPrivateSaleSupport.Context memory context = _context();
        uint64 revision = context.requireAdmission(0, 0);
        context.requireToken(config.collectionId, config.tokenId);
        if (context.ownerOf(config.tokenId) != config.consignor) revert CustodyGrantInvalid();
        uint256 nonce = nextSaleNonce++;
        id = saleIdFor(config.saleKind, config.collectionId, nonce);
        Sale storage sale = _sales[id];
        sale.config = config;
        sale.configHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CONSIGNMENT_CONFIG_V1"),
                block.chainid,
                address(this),
                nonce,
                platformSigner,
                config
            )
        );
        sale.saleNonce = nonce;
        sale.createdAt = uint64(block.timestamp);
        sale.registryRevision = revision;
        sale.status = 1;
        emit SaleConfigured(
            1, id, config.collectionId, 0, config.saleKind, address(0), sale.configHash, 0, 0
        );
    }

    function saleRecord(bytes32 id)
        external
        view
        override
        returns (uint8, uint256, bytes32, address, bytes32, bytes32, uint8, uint8)
    {
        Sale storage sale = _sales[id];
        return (
            sale.config.saleKind,
            sale.config.collectionId,
            0,
            address(0),
            sale.configHash,
            sale.config.expectedPrimaryPolicyHash,
            0,
            sale.status
        );
    }

    function saleDetails(bytes32 id) external view override returns (Sale memory) {
        return _sales[id];
    }

    function custodySaleLifecycle(bytes32 id) external view override returns (uint64, uint64) {
        return (_sales[id].createdAt, _sales[id].registryRevision);
    }

    function royaltyQuote(bytes32 id)
        external
        view
        override
        returns (
            address receiver,
            uint256 amount,
            bool secondaryConsignment,
            bool externalRoyaltiesDisclosureOnly
        )
    {
        Sale storage sale = _known(id);
        if (sale.status == 3) return (sale.royaltyReceiver, sale.royaltyAmount, true, true);
        (receiver, amount) = _context().royalty(sale.config.tokenId, sale.config.price);
        return (receiver, amount, true, true);
    }

    function authorizationDigest(StreamPrivateSaleTypes.SaleAuthorization calldata a)
        public
        view
        returns (bytes32)
    {
        return _digest(StreamPrivateSaleHash.authorizationBody(a));
    }

    function offerDigest(StreamPrivateSaleTypes.SaleOffer calldata offer)
        public
        view
        returns (bytes32)
    {
        return _digest(StreamPrivateSaleHash.offerBody(offer));
    }

    function custodyGrantDigest(StreamPrivateSaleTypes.SaleCustodyGrant calldata grant)
        public
        view
        returns (bytes32)
    {
        return _digest(StreamPrivateSaleHash.custodyGrantBody(grant));
    }

    function eip712Domain()
        external
        view
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
        return (
            0x0f,
            "6529Stream Sales",
            "1",
            block.chainid,
            address(this),
            bytes32(0),
            new uint256[](0)
        );
    }

    function depositCustody(
        bytes32 id,
        StreamPrivateSaleTypes.SaleCustodyGrant calldata grant,
        uint8 ownerKind,
        bytes calldata signature
    ) external nonReentrant {
        Sale storage sale = _known(id);
        _requireUnpaused(id);
        if (sale.config.saleKind != 5 || sale.status != 1 || block.timestamp > sale.config.deadline)
        {
            revert PrivateSaleUnavailable(id);
        }
        _admit(sale);
        _enterCustody(id, sale, grant, ownerKind, signature, gasParameter(_SIGNATURE_GAS));
        _admit(sale);
    }

    function purchasePrivate(
        StreamPrivateSaleTypes.SaleAuthorization calldata a,
        Signature calldata proof
    ) external payable nonReentrant {
        Sale storage sale = _known(a.saleId);
        if (sale.config.saleKind != 5 || sale.status != 2) {
            revert PrivateSaleUnavailable(a.saleId);
        }
        _purchaseAdmission(a.saleId, sale);
        uint256 signatureGas = gasParameter(_SIGNATURE_GAS);
        bytes32 digest = StreamPrivateSaleSupport.authorizationProof(
            sale.config, a, proof, platformSigner, signatureGas
        );
        _consume(a.saleId, digest, proof.authorizer);
        _settle(a.saleId, sale, digest);
        emit PrivateSaleExecuted(
            1, a.saleId, sale.config.buyer, sale.config.tokenId, sale.config.price, address(0)
        );
    }

    function acceptOffer(
        StreamPrivateSaleTypes.SaleAuthorization calldata a,
        Signature calldata authorization,
        StreamPrivateSaleTypes.SaleOffer calldata offer,
        Signature calldata buyerProof,
        StreamPrivateSaleTypes.SaleCustodyGrant calldata grant,
        uint8 ownerKind,
        bytes calldata ownerSignature
    ) external payable nonReentrant {
        Sale storage sale = _known(a.saleId);
        if (sale.config.saleKind != 6 || sale.status != 1) {
            revert PrivateSaleUnavailable(a.saleId);
        }
        _purchaseAdmission(a.saleId, sale);
        uint256 signatureGas = gasParameter(_SIGNATURE_GAS);
        bytes32 authDigest = StreamPrivateSaleSupport.authorizationProof(
            sale.config, a, authorization, platformSigner, signatureGas
        );
        bytes32 buyerDigest =
            StreamPrivateSaleSupport.offerProof(sale.config, core, offer, buyerProof, signatureGas);
        _consume(a.saleId, authDigest, authorization.authorizer);
        _consume(a.saleId, buyerDigest, buyerProof.authorizer);
        _enterCustody(a.saleId, sale, grant, ownerKind, ownerSignature, signatureGas);
        _settle(a.saleId, sale, authDigest);
        emit OfferAccepted(
            1, a.saleId, sale.config.buyer, buyerDigest, sale.config.price, address(0)
        );
    }

    function revokeOffer(
        StreamPrivateSaleTypes.SaleOffer calldata offer,
        uint8 kind,
        bytes calldata signature
    ) external nonReentrant {
        if (
            offer.chainId != block.chainid || offer.saleAdapter != address(this)
                || offer.core != core || offer.buyer == address(0)
        ) revert InvalidPrivateSale();
        bytes32 digest = offerDigest(offer);
        StreamPrivateSaleSupport.directOrSignature(
            offer.buyer,
            kind,
            _digest(
                StreamPrivateSaleHash.offerRevocationBody(block.chainid, address(this), digest)
            ),
            signature,
            gasParameter(_SIGNATURE_GAS)
        );
        if (digestConsumed[digest]) revert PrivateSaleDigestConsumed(digest);
        digestConsumed[digest] = true;
        digestRevoked[digest] = true;
        emit SaleOfferRevoked(1, digest, offer.buyer);
    }

    function revokeAuthorization(
        StreamPrivateSaleTypes.SaleAuthorization calldata a,
        Signature calldata proof
    ) external nonReentrant {
        Sale storage sale = _known(a.saleId);
        StreamPrivateSaleSupport.authorizationFields(sale.config, a);
        if (proof.authorizer != platformSigner) {
            revert PrivateSaleAuthorityInvalid(proof.authorizer);
        }
        bytes32 digest = authorizationDigest(a);
        StreamPrivateSaleSupport.directOrSignature(
            proof.authorizer,
            proof.kind,
            _digest(
                StreamPrivateSaleHash.authorizationRevocationBody(
                    block.chainid, address(this), proof.authorizer, digest
                )
            ),
            proof.signature,
            gasParameter(_SIGNATURE_GAS)
        );
        if (digestConsumed[digest]) revert PrivateSaleDigestConsumed(digest);
        digestConsumed[digest] = true;
        digestRevoked[digest] = true;
        emit SaleAuthorizationRevoked(1, a.saleId, digest, proof.authorizer);
    }

    function revokeCustodyGrant(
        StreamPrivateSaleTypes.SaleCustodyGrant calldata grant,
        uint8 kind,
        bytes calldata signature
    ) external nonReentrant {
        _grantDomain(grant);
        bytes32 digest = custodyGrantDigest(grant);
        StreamPrivateSaleSupport.directOrSignature(
            grant.owner,
            kind,
            _digest(
                StreamPrivateSaleHash.custodyGrantRevocationBody(
                    block.chainid, address(this), grant.owner, digest
                )
            ),
            signature,
            gasParameter(_SIGNATURE_GAS)
        );
        bytes32 id = _custodySale[digest];
        if (id != 0) {
            Sale storage sale = _sales[id];
            if (sale.status == 3) revert PrivateSaleUnavailable(id);
            if (
                sale.custodyGrantDigest != digest || grant.owner != sale.config.consignor
                    || grant.tokenId != sale.config.tokenId || grant.saleRef != _saleRef(id, sale)
            ) {
                revert CustodyGrantInvalid();
            }
            if (sale.status == 2) _close(id, sale, 4, _REVOKED);
        }
        if (digestRevoked[digest]) revert PrivateSaleDigestConsumed(digest);
        digestConsumed[digest] = true;
        digestRevoked[digest] = true;
        emit SaleCustodyGrantRevoked(1, digest, grant.owner);
    }

    function expireSale(bytes32 id) external nonReentrant {
        Sale storage sale = _known(id);
        if ((sale.status != 1 && sale.status != 2) || block.timestamp <= sale.config.deadline) {
            revert PrivateSaleUnavailable(id);
        }
        _close(id, sale, 5, _EXPIRED);
    }

    function cancelSale(bytes32 id) external nonReentrant {
        Sale storage sale = _known(id);
        if (msg.sender != owner() && msg.sender != sale.config.consignor) {
            revert PrivateSaleAuthorityInvalid(msg.sender);
        }
        if (sale.status != 1 && sale.status != 2) revert PrivateSaleUnavailable(id);
        _close(id, sale, 4, _CANCELLED);
    }

    function refundableBalance(bytes32 id, address account) public view override returns (uint256) {
        Credits storage credit = _money.credits[id][account];
        return credit.excess + credit.consignorProceeds + credit.royalty;
    }

    function creditBreakdown(bytes32 id, address account)
        external
        view
        override
        returns (Credits memory)
    {
        return _money.credits[id][account];
    }

    function totalLiabilities() external view returns (uint256) {
        return _money.totalLiabilities;
    }

    function claimRefund(bytes32 id, address to) external override nonReentrant {
        StreamPrivateSaleAccounting.claim(_money, id, to);
    }

    function retryRoyalty(bytes32 id) external nonReentrant returns (bool) {
        return StreamPrivateSaleAccounting.retryRoyalty(
            _money, _known(id), id, gasParameter(_ROYALTY_GAS)
        );
    }

    function claimNft(bytes32 id, address receiver) external nonReentrant returns (bool) {
        Sale storage sale = _known(id);
        address beneficiary = _claimBeneficiary(sale);
        if (msg.sender != beneficiary || receiver == address(0)) {
            revert PrivateSaleClaimUnavailable();
        }
        return _deliverClaim(id, sale, receiver);
    }

    function retryNft(bytes32 id) external nonReentrant returns (bool) {
        Sale storage sale = _known(id);
        return _deliverClaim(id, sale, _claimBeneficiary(sale));
    }

    function transferOwnership(address next) public override onlyOwner nonReentrant {
        super.transferOwnership(next);
    }

    function pauseAdapter(bytes32 reason) external nonReentrant {
        _role(keccak256("ROLE_PAUSE_GUARDIAN"));
        if (paused) revert PrivateSalePaused(0);
        paused = true;
        emit AdapterPaused(1, msg.sender, reason);
    }

    function unpauseAdapter(bytes32 reason) external nonReentrant {
        _role(keccak256("ROLE_UNPAUSE"));
        if (!paused) revert InvalidPrivateSale();
        paused = false;
        emit AdapterUnpaused(1, msg.sender, reason);
    }

    function pauseSale(bytes32 id, bytes32 reason) external nonReentrant {
        _known(id);
        _role(keccak256("ROLE_PAUSE_GUARDIAN"));
        if (salePaused[id]) revert PrivateSalePaused(id);
        salePaused[id] = true;
        emit SalePaused(1, id, msg.sender, reason);
    }

    function unpauseSale(bytes32 id, bytes32 reason) external nonReentrant {
        _known(id);
        _role(keccak256("ROLE_UNPAUSE"));
        if (!salePaused[id]) revert InvalidPrivateSale();
        salePaused[id] = false;
        emit SaleUnpaused(1, id, msg.sender, reason);
    }

    function renounceOwnership() public override onlyOwner nonReentrant {
        super.renounceOwnership();
    }

    function _enterCustody(
        bytes32 id,
        Sale storage sale,
        StreamPrivateSaleTypes.SaleCustodyGrant calldata grant,
        uint8 kind,
        bytes calldata signature,
        uint256 cap
    ) private {
        StreamPrivateSaleCustody.enter(
            _context(), sale, digestConsumed, _custodySale, id, grant, kind, signature, cap
        );
    }

    function _settle(bytes32 id, Sale storage sale, bytes32 digest) private {
        StreamPrivateSaleSupport.Context memory context = _context();
        uint256 royaltyGas = gasParameter(_ROYALTY_GAS);
        uint256 nftGas = gasParameter(_NFT_GAS);
        StreamPrivateSaleSupport.requireGas(royaltyGas);
        StreamPrivateSaleSupport.requireGas(nftGas);
        _admit(sale);
        context.requireToken(sale.config.collectionId, sale.config.tokenId);
        if (context.ownerOf(sale.config.tokenId) != address(this)) revert CustodyGrantInvalid();
        uint256 oldSurplus = address(this).balance - msg.value - _money.totalLiabilities;
        sale.status = 3;
        sale.authorizationDigest = digest;
        sale.nftClaim = 1;
        StreamPrivateSaleAccounting.settleRoyalty(_money, context, sale, id, royaltyGas);
        _admit(sale);
        bool deliveredNft = context.deliverNft(sale.config.tokenId, sale.config.buyer, nftGas);
        if (deliveredNft) sale.nftClaim = 0;
        emit PrivateSaleNftDelivery(1, id, sale.config.tokenId, sale.config.buyer, deliveredNft);
        _admit(sale);
        if (address(this).balance != _money.totalLiabilities + oldSurplus) {
            revert PrivateSaleBalanceMismatch();
        }
        emit ConsignmentSettled(
            1,
            id,
            sale.config.tokenId,
            sale.config.buyer,
            sale.config.price,
            sale.royaltyAmount,
            sale.royaltyReceiver,
            sale.config.consignor
        );
    }

    function _purchaseAdmission(bytes32 id, Sale storage sale) private view {
        _requireUnpaused(id);
        if (msg.sender != sale.config.buyer) revert PrivateSaleNotBuyer(msg.sender);
        if (block.timestamp < sale.config.startTime || block.timestamp > sale.config.deadline) {
            revert PrivateSaleUnavailable(id);
        }
        if (msg.value < sale.config.price) {
            revert PrivateSalePaymentTooSmall(sale.config.price, msg.value);
        }
        if (address(this).balance - msg.value < _money.totalLiabilities) {
            revert PrivateSaleBalanceMismatch();
        }
        _admit(sale);
    }

    function _admit(Sale storage sale) private view {
        _requireUnpaused(saleIdFor(sale.config.saleKind, sale.config.collectionId, sale.saleNonce));
        _context().requireAdmission(sale.createdAt, sale.registryRevision);
    }

    function _requireUnpaused(bytes32 id) private view {
        if (paused || salePaused[id]) revert PrivateSalePaused(id);
    }

    function _role(bytes32 role) private view {
        StreamPrivateSaleSupport.requireRole(
            roleRegistry, roleRegistryCodeHash, governanceAuthority, role
        );
    }

    function _consume(bytes32 id, bytes32 digest, address authorizer) private {
        if (digestConsumed[digest]) revert PrivateSaleDigestConsumed(digest);
        digestConsumed[digest] = true;
        emit SaleAuthorizationConsumed(1, id, digest, authorizer);
    }

    function _grantDomain(StreamPrivateSaleTypes.SaleCustodyGrant calldata grant) private view {
        if (
            grant.chainId != block.chainid || grant.saleAdapter != address(this)
                || grant.core != core || grant.owner == address(0) || grant.tokenId == 0
                || grant.saleRef == 0
        ) {
            revert CustodyGrantInvalid();
        }
    }

    function _saleRef(bytes32 id, Sale storage sale) private view returns (bytes32) {
        return sale.config.saleKind == 6 ? sale.config.offerDigest : id;
    }

    function _close(bytes32 id, Sale storage sale, uint8 status, bytes32 reason) private {
        if (sale.status == 2) sale.nftClaim = 2;
        uint8 previousStatus = sale.status;
        sale.status = status;
        emit SaleStatusChanged(1, id, previousStatus, status, reason);
    }

    function _claimBeneficiary(Sale storage sale) private view returns (address) {
        if (sale.nftClaim == 1) return sale.config.buyer;
        if (sale.nftClaim == 2) return sale.config.consignor;
        revert PrivateSaleClaimUnavailable();
    }

    function _deliverClaim(bytes32 id, Sale storage sale, address receiver)
        private
        returns (bool ok)
    {
        return StreamPrivateSaleCustody.deliverClaim(
            _context(), sale, digestRevoked, id, receiver, gasParameter(_NFT_GAS)
        );
    }

    function _known(bytes32 id) private view returns (Sale storage sale) {
        sale = _sales[id];
        if (sale.saleNonce == 0) revert PrivateSaleUnavailable(id);
    }

    function _digest(bytes32 body) private view returns (bytes32) {
        return StreamPrivateSaleHash.digest(block.chainid, address(this), body);
    }

    function _context() private view returns (StreamPrivateSaleSupport.Context memory) {
        return
            StreamPrivateSaleSupport.Context(core, moduleRegistry, coreCodeHash, registryCodeHash);
    }
}
