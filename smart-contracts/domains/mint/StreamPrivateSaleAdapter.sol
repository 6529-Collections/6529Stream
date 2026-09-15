// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamNativeSurplusHost, StreamNativeSurplus, IStreamNativeSurplus } from "./StreamNativeSurplusHost.sol";

import "./StreamPrivateSaleSupport.sol";
import "./StreamPrivateSaleAccounting.sol";
import "./StreamPrivateSaleCustody.sol";
import "./StreamPrivateSaleHash.sol";
import "./StreamNativeInventoryPayment.sol";
import { StreamPrivateSaleOfferExecution } from "./StreamPrivateSaleOfferExecution.sol";
import {
    IStreamPrivateSaleDelegatedOffers
} from "../../interfaces/stream/mint/IStreamPrivateSaleDelegatedOffers.sol";
import { StreamPrivateSaleDelegatedClaims } from "./StreamPrivateSaleDelegatedClaims.sol";
import { StreamNativeAuctionDelegation } from "../auctions/StreamNativeAuctionDelegation.sol";
import {
    IStreamPrivateSaleDelegatedClaims
} from "../../interfaces/stream/mint/IStreamPrivateSaleDelegatedClaims.sol";
import "../../interfaces/stream/mint/IStreamPrivateSaleAdapter.sol";
import "../parameters/StreamGasParameterHost.sol";
import "../../vendor/openzeppelin/Ownable.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../../vendor/openzeppelin/ERC165.sol";

/// @notice Buyer-bound native secondary custody sales with full-payload authorizations.
/// @dev The owner explicitly configures each collection's singleton signer set. Royalty credits,
///      consignor proceeds and buyer excess are separate perpetual claims. No primary mint occurs.
contract StreamPrivateSaleAdapter is
    StreamNativeSurplusHost,
    IStreamPrivateSaleAdapter,
    IStreamPrivateSaleDelegatedClaims,
    IStreamPrivateSaleDelegatedOffers,
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
        address delegateRegistry;
        uint256 delegationUsecase;
        bytes32 baseModuleManifestHash;
        GasParameterConfig delegationGas;
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
    address public immutable override delegateRegistry;
    bytes32 public immutable override delegateRegistryCodeHash;
    uint256 public immutable override delegationUsecase;
    bytes32 private immutable _baseModuleManifestHash;
    uint256 private immutable _delegationChainId;
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
    StreamNativeInventoryState.State private _inventory;

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
        if (d.delegateRegistry != address(0)) {
            if (
                keccak256(bytes(d.delegationGas.name)) != keccak256("DELEGATE_REGISTRY_GAS_LIMIT")
                    || d.delegationGas.failureClass != FAILURE_CLASS_FAIL_CLOSED_PRECHECK
            ) revert InvalidPrivateSale();
            StreamNativeAuctionDelegation.validateConfiguration(
                StreamNativeAuctionDelegation.Configuration(
                    block.chainid,
                    d.core,
                    d.delegateRegistry,
                    d.delegateRegistry.codehash,
                    d.delegationUsecase,
                    d.baseModuleManifestHash,
                    d.moduleRegistry,
                    d.moduleRegistry.codehash
                )
            );
            _registerGasParameter(d.delegationGas);
        } else if (
            d.delegationUsecase != 0 || d.baseModuleManifestHash != 0
                || bytes(d.delegationGas.name).length != 0 || d.delegationGas.genesisValue != 0
                || d.delegationGas.floor != 0 || d.delegationGas.failureClass != 0
        ) {
            revert InvalidPrivateSale();
        }
        delegateRegistry = d.delegateRegistry;
        delegateRegistryCodeHash =
            d.delegateRegistry == address(0) ? bytes32(0) : d.delegateRegistry.codehash;
        delegationUsecase = d.delegationUsecase;
        _baseModuleManifestHash = d.baseModuleManifestHash;
        _delegationChainId = block.chainid;
        _transferOwnership(d.configurationOwner);
    }

    function supportsInterface(bytes4 id) public view override(IERC165, ERC165) returns (bool) {
        return id == type(IStreamNativeSurplus).interfaceId || ((id == type(IStreamPrivateSaleDelegatedClaims).interfaceId
                    || id == type(IStreamPrivateSaleDelegatedOffers).interfaceId)
                && delegateRegistry != address(0))
            || id == type(IStreamPrivateSaleAdapter).interfaceId
            || id == type(IStreamNativeInventorySale).interfaceId || super.supportsInterface(id);
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
        _requireDelegationManifest();
        CollectionSigner memory signer = collectionSigner[config.collectionId];
        StreamPrivateSaleSupport.validateConfig(config, signer);
        StreamPrivateSaleSupport.Context memory context = _context();
        uint64 revision = context.requireAdmission(0, 0);
        context.requireToken(config.collectionId, config.tokenId);
        if (context.ownerOf(config.tokenId) != config.consignor) revert CustodyGrantInvalid();
        uint256 nonce = nextSaleNonce++;
        id = saleIdFor(config.saleKind, config.collectionId, nonce);
        StreamPrivateSaleDelegatedClaims.recordSale(
            _sales[id], id, nonce, revision, platformSigner, msg.data
        );
    }

    function saleRecord(bytes32 id)
        external
        view
        override
        returns (uint8, uint256, bytes32, address, bytes32, bytes32, uint8, uint8)
    {
        bytes memory out =
            StreamPrivateSaleDelegatedClaims.read(_sales, _inventory, _context(), msg.data);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function saleDetails(bytes32 id) external view override returns (Sale memory) {
        bytes memory out = StreamNativeInventorySale.encodedPrivateSale(_sales[id]);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function custodySaleLifecycle(bytes32 id) external view override returns (uint64, uint64) {
        bytes memory out =
            StreamPrivateSaleDelegatedClaims.read(_sales, _inventory, _context(), msg.data);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
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
        bytes memory out = StreamPrivateSaleDelegatedClaims.read(
            _sales, _inventory, _context(), msg.data
        );
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
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
        bytes memory out = StreamPrivateSaleDelegatedClaims.read(
            _sales, _inventory, _context(), msg.data
        );
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
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
        _executeOffer(false);
    }

    function acceptDelegatedOffer(
        StreamPrivateSaleTypes.SaleAuthorization calldata,
        Signature calldata,
        StreamPrivateSaleTypes.SaleOffer calldata,
        Signature calldata,
        StreamPrivateSaleTypes.SaleCustodyGrant calldata,
        uint8,
        bytes calldata,
        DelegationWitness calldata
    ) external payable nonReentrant {
        _executeOffer(true);
    }

    function _executeOffer(bool delegated) private {
        StreamPrivateSaleOfferExecution.execute(
            _sales,
            _money,
            digestConsumed,
            _custodySale,
            salePaused,
            StreamPrivateSaleOfferExecution.Runtime(_context(), platformSigner, _delegation()),
            delegated,
            msg.data
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
        if (_inventory.grantSale[digest] != 0) {
            StreamNativeInventorySale.revoke(_inventory, grant, digest);
        }
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
        if (_inventory.inventories[id].saleNonce != 0) {
            StreamNativeInventorySale.close(_inventory, id, true, owner());
            return;
        }
        Sale storage sale = _known(id);
        if ((sale.status != 1 && sale.status != 2) || block.timestamp <= sale.config.deadline) {
            revert PrivateSaleUnavailable(id);
        }
        _close(id, sale, 5, _EXPIRED);
    }

    function cancelSale(bytes32 id) external nonReentrant {
        if (_inventory.inventories[id].saleNonce != 0) {
            StreamNativeInventorySale.close(_inventory, id, false, owner());
            return;
        }
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
        if (_inventory.inventories[id].saleNonce == 0) _known(id);
        _role(keccak256("ROLE_PAUSE_GUARDIAN"));
        if (salePaused[id]) revert PrivateSalePaused(id);
        salePaused[id] = true;
        emit SalePaused(1, id, msg.sender, reason);
    }

    function unpauseSale(bytes32 id, bytes32 reason) external nonReentrant {
        if (_inventory.inventories[id].saleNonce == 0) _known(id);
        _role(keccak256("ROLE_UNPAUSE"));
        if (!salePaused[id]) revert InvalidPrivateSale();
        salePaused[id] = false;
        emit SaleUnpaused(1, id, msg.sender, reason);
    }

    function renounceOwnership() public override onlyOwner nonReentrant {
        super.renounceOwnership();
    }

    function registerInventory(
        IStreamNativeInventorySale.Config calldata config,
        uint256[] calldata tokenIds
    ) external onlyOwner nonReentrant returns (bytes32) {
        if (paused) revert PrivateSalePaused(0);
        _requireDelegationManifest();
        return StreamNativeInventorySale.registerEncoded(
            _inventory, _context(), collectionSigner, platformSigner, nextSaleNonce++, msg.data
        );
    }

    function inventoryDetails(bytes32 id)
        external
        view
        returns (IStreamNativeInventorySale.Inventory memory)
    {
        bytes memory out = StreamNativeInventorySale.encodedRead(_inventory, msg.data);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function inventoryToken(bytes32 id, uint256 tokenId) external view returns (Sale memory) {
        bytes memory out = StreamNativeInventorySale.encodedRead(_inventory, msg.data);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function inventoryBuyerPurchases(bytes32 id, address buyer) external view returns (uint256) {
        return _inventory.purchases[id][buyer];
    }

    function depositInventoryCustody(
        bytes32 id,
        StreamPrivateSaleTypes.SaleCustodyGrant calldata grant,
        uint8 ownerKind,
        bytes calldata signature
    ) external nonReentrant {
        _requireUnpaused(id);
        StreamNativeInventorySale.depositEncoded(
            _inventory, _context(), digestConsumed, gasParameter(_SIGNATURE_GAS), msg.data
        );
    }

    function openInventory(bytes32 id) external nonReentrant {
        _requireUnpaused(id);
        StreamNativeInventorySale.open(_inventory, _context(), id, owner());
    }

    function purchaseInventory(bytes32 id, uint256 tokenId, bytes32 expectedConfigHash)
        external
        payable
        nonReentrant
    {
        _requireUnpaused(id);
        StreamNativeInventoryPayment.purchase(
            _inventory, _money, _context(), id, tokenId, expectedConfigHash
        );
        _requireUnpaused(id);
    }

    function inventoryRoyaltyQuote(bytes32 id, uint256 tokenId)
        external
        view
        returns (address, uint256, bool, bool)
    {
        return StreamNativeInventoryPayment.quote(_inventory, _context(), id, tokenId);
    }

    function claimInventoryNft(bytes32 id, uint256 tokenId, address receiver)
        external
        nonReentrant
        returns (bool)
    {
        return StreamNativeInventorySale.claimEncoded(
            _inventory, _context(), digestRevoked, gasParameter(_NFT_GAS), msg.data
        );
    }

    function retryInventoryNft(bytes32 id, uint256 tokenId) external nonReentrant returns (bool) {
        return StreamNativeInventorySale.claimEncoded(
            _inventory, _context(), digestRevoked, gasParameter(_NFT_GAS), msg.data
        );
    }

    function retryInventoryRoyalty(bytes32 id, address receiver)
        external
        nonReentrant
        returns (bool)
    {
        return StreamNativeInventoryPayment.retryRoyalty(
            _inventory, _money, id, receiver, gasParameter(_ROYALTY_GAS)
        );
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

    function delegationManifest() external view returns (bytes memory) {
        if (delegateRegistry == address(0)) {
            revert StreamNativeAuctionDelegation.DelegationConfigurationInvalid();
        }
        return StreamNativeAuctionDelegation.manifestBytes(_delegation());
    }

    function claimRefundFor(bytes32, address, DelegationWitness calldata)
        external
        nonReentrant
        returns (uint256)
    {
        return _delegatedClaim();
    }

    function claimNftFor(bytes32, address, DelegationWitness calldata)
        external
        nonReentrant
        returns (bool)
    {
        return _delegatedClaim() != 0;
    }

    function claimInventoryNftFor(bytes32, uint256, address, DelegationWitness calldata)
        external
        nonReentrant
        returns (bool)
    {
        return _delegatedClaim() != 0;
    }

    function _delegatedClaim() private returns (uint256) {
        return StreamPrivateSaleDelegatedClaims.claim(
            _money, _sales, _inventory, digestRevoked, _context(), _delegation(), msg.data
        );
    }

    function _requireDelegationManifest() private view {
        if (delegateRegistry != address(0)) {
            StreamNativeAuctionDelegation.requireManifest(
                _delegation(), gasParameter(StreamNativeAuctionDelegation.GAS_PARAMETER)
            );
        }
    }

    function _delegation()
        private
        view
        returns (StreamNativeAuctionDelegation.Configuration memory)
    {
        return StreamNativeAuctionDelegation.Configuration(
                _delegationChainId,
                core,
                delegateRegistry,
                delegateRegistryCodeHash,
                delegationUsecase,
                _baseModuleManifestHash,
                moduleRegistry,
                registryCodeHash
            );
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

    function sweepNativeSurplus(uint256 amount, bytes32 reasonHash)
        external override nonReentrant returns (uint256)
    {
        return _sweepNativeSurplus(amount, reasonHash);
    }
    function _nativeSurplusPrivateRegistry() internal pure override returns (bool) { return true; }
    function _nativeSurplusOwed() internal view override returns (uint256) { return _money.totalLiabilities; }
}
