// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativeImmediateSalesRuntime.sol";
import { StreamNativeClaimSalesRuntime } from "./StreamNativeClaimSalesRuntime.sol";
import { StreamNativeClaimSalesState } from "./StreamNativeClaimSalesState.sol";
import {
    IStreamNativeClaimSales as C
} from "../../interfaces/stream/mint/IStreamNativeClaimSales.sol";
import "./StreamNativeImmediateSalesRefunds.sol";
import "./StreamNativeImmediateSalesAdministration.sol";
import "./StreamImmediateSaleReveal.sol";
import "./StreamNativeSaleMint.sol";
import "../revenue/StreamSettlementContext.sol";
import "../parameters/StreamGasParameterHost.sol";
import "../../interfaces/stream/mint/IStreamImmediateSaleAuthorizationBinding.sol";
import "../../interfaces/stream/revenue/IStreamNativePublicSaleBinding.sol";
import "../../vendor/openzeppelin/Ownable.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../../vendor/openzeppelin/ERC165.sol";

/// @notice Canonical zero-price and bounded pay-what-you-want native singleton claims.
/// @dev Zero chosen price mints through Manager without recording a paid settlement.
contract StreamNativeClaimSales is
    C,
    IStreamImmediateSaleAuthorizationBinding,
    IStreamNativePublicSaleBinding,
    StreamSettlementContext,
    StreamGasParameterHost,
    Ownable,
    ReentrancyGuard,
    ERC165
{
    struct DeploymentConfig {
        IStreamMintManager manager;
        IStreamPrimarySaleSettlement recorder;
        IStreamArtistAttribution artists;
        IStreamRoleRegistry roles;
        address authority;
        GasParameterConfig[3] parameters;
    }

    bytes32 private constant _SALE_SIGNATURE = keccak256("6529STREAM_GGP_SALE_ERC1271_GAS_LIMIT");
    bytes32 private constant _ARTIST = keccak256("6529STREAM_GGP_SALE_ARTIST_AUTHORITY_GAS_LIMIT");
    bytes32 private constant _REVEAL = keccak256("6529STREAM_GGP_REVEAL_ATTEMPT_GAS_LIMIT");
    IStreamMintManager public immutable mintManager;
    bytes32 public immutable mintManagerCodeHash;
    address public immutable primarySaleSettlement;
    bytes32 public immutable settlementCodeHash;
    IStreamArtistAttribution public immutable artistRegistry;
    bytes32 public immutable artistRegistryCodeHash;
    IStreamRoleRegistry public immutable roleRegistry;
    bytes32 public immutable roleRegistryCodeHash;
    StreamNativeClaimSalesState.State private _state;

    constructor(DeploymentConfig memory d)
        StreamSettlementContext(d.recorder.revenueResolver(), d.recorder.moduleRegistry())
        StreamGasParameterHost(d.authority)
    {
        if (
            d.authority == address(0) || d.authority != splitFactory.governanceAuthority()
                || !StreamSettlementAdmission.isContract(address(d.manager))
                || !StreamSettlementAdmission.isContract(address(d.recorder))
                || !d.recorder.isStreamPrimarySaleSettlement() || d.recorder.core() != core
                || !IStreamMintReads(address(d.manager)).isStreamMintManager()
                || address(IStreamMintReads(address(d.manager)).core()) != core
                || address(IStreamMintReads(address(d.manager)).moduleRegistry()) != moduleRegistry
                || !StreamSaleArtist.supportsAttribution(d.artists) || d.artists.core() != core
                || revenueResolver.artistRegistry() != address(d.artists)
                || address(d.roles).code.length == 0
                || _read(address(d.roles), abi.encodeWithSignature("owner()"), gasleft())
                    != uint256(uint160(d.authority))
                || !IERC165(address(d.recorder))
                    .supportsInterface(type(IStreamNativePrimarySaleSettlement).interfaceId)
                || !IERC165(address(d.recorder))
                    .supportsInterface(type(IStreamNativePublicPrimarySaleSettlement).interfaceId)
        ) revert S.InvalidImmediateSale();
        bytes32[3] memory names = [
            keccak256("SALE_ERC1271_GAS_LIMIT"),
            keccak256("SALE_ARTIST_AUTHORITY_GAS_LIMIT"),
            keccak256("REVEAL_ATTEMPT_GAS_LIMIT")
        ];
        for (uint256 i; i < 3; ++i) {
            if (
                keccak256(bytes(d.parameters[i].name)) != names[i]
                    || d.parameters[i].failureClass != 2
            ) revert S.InvalidImmediateSale();
            _registerGasParameter(d.parameters[i]);
        }
        mintManager = d.manager;
        mintManagerCodeHash = address(d.manager).codehash;
        primarySaleSettlement = address(d.recorder);
        settlementCodeHash = address(d.recorder).codehash;
        artistRegistry = d.artists;
        artistRegistryCodeHash = address(d.artists).codehash;
        roleRegistry = d.roles;
        roleRegistryCodeHash = address(d.roles).codehash;
        _state.common.nextSaleNonce = 1;
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(C).interfaceId || id == type(IStreamNativeSaleBinding).interfaceId
            || id == type(IStreamNativePublicSaleBinding).interfaceId
            || id == type(IStreamImmediateSaleAuthorizationBinding).interfaceId
            || id == type(IStreamArtistSaleFacts).interfaceId
            || id == type(IStreamImmediateSaleReveal).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId || id == type(IERC5267).interfaceId
            || super.supportsInterface(id);
    }

    function streamModuleType() external pure returns (bytes32) {
        return keccak256("NATIVE_PRIMARY_SALE_ADAPTER");
    }

    function streamModuleInterfaceId() external pure returns (bytes4) {
        return type(IStreamNativeSaleBinding).interfaceId;
    }

    function eip712Domain()
        external
        view
        override
        returns (bytes1, string memory, string memory, uint256, address, bytes32, uint256[] memory)
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

    function authorizationDigest(StreamPrivateSaleTypes.SaleAuthorization calldata a)
        external
        view
        override
        returns (bytes32)
    {
        return StreamPrivateSaleHash.digest(
            block.chainid, address(this), StreamPrivateSaleHash.authorizationBody(a)
        );
    }

    function saleIdFor(uint256 collection, bytes32 phase, uint256 nonce)
        external
        view
        override
        returns (bytes32)
    {
        return StreamNativeClaimSalesRuntime.saleId(collection, phase, nonce);
    }

    function saleConfigurationHash(Configuration calldata config)
        external
        view
        override
        returns (bytes32)
    {
        return StreamNativeClaimSalesRuntime.configurationHash(config);
    }

    function saleRecord(bytes32 id) external view override returns (C.Record memory) {
        return C.Record(_state.common.sales[id], _state.maxUnitPrices[id]);
    }

    function nextSaleNonce() external view override returns (uint256) {
        return _state.common.nextSaleNonce;
    }

    function nextExecutionNonce(bytes32 id, address payer) public view override returns (uint256) {
        return _state.common.executionNonces[id][payer] + 1;
    }

    function executionReceipt(bytes32 id) external view override returns (S.Receipt memory) {
        return _state.common.receipts[id];
    }

    function executionStatus(bytes32 id) external view override returns (uint8) {
        return _state.common.executionStatus[id];
    }

    function saleConsentFacts(bytes32 id) external view override returns (uint256, bytes32) {
        S.Record storage r = _record(id);
        return (r.config.collectionId, r.configHash);
    }

    function nativeSaleLifecycleBinding(bytes32 id)
        external
        view
        returns (StreamNativeSettlementTypes.SaleLifecycleBinding memory)
    {
        return _record(id).lifecycle;
    }

    function publicNativeSaleBinding(bytes32 id)
        external
        view
        override
        returns (uint256, bytes32, bytes32, uint8)
    {
        S.Record storage r = _record(id);
        return (r.config.collectionId, r.config.phaseId, r.configHash, r.config.authorityMode);
    }

    function activePublicNativeCandidate(bytes32 id) external view override returns (bytes32) {
        return id != 0 && id == _state.common.activePublicId
            ? _state.common.activePublicCommitment
            : bytes32(0);
    }

    function immediateSaleAuthorizationBinding(bytes32 id)
        external
        view
        override
        returns (uint256, bytes32, uint8, uint8, bytes32, address, uint8)
    {
        S.Record storage r = _record(id);
        return (
            r.config.collectionId,
            r.config.phaseId,
            r.config.saleKind,
            r.config.authorityMode,
            r.configHash,
            r.config.signer.authorizer,
            r.config.signer.kind
        );
    }

    function configureCollectionSigner(
        uint256 collection,
        address signer,
        uint8 kind,
        bytes32 evidence,
        bool enabled
    ) external override onlyOwner nonReentrant {
        _requireContext();
        StreamNativeImmediateSalesAdministration.configureSigner(
            _state.common, collection, signer, kind, evidence, enabled
        );
    }

    function collectionSigner(uint256 collection, address signer, uint8 kind)
        external
        view
        override
        returns (S.SignerBinding memory, bool)
    {
        StreamNativeImmediateSalesState.Signer storage s =
            _state.common.signers[collection][signer][kind];
        return (s.binding, s.enabled);
    }

    function registerSale(Configuration calldata config)
        external
        override
        onlyOwner
        nonReentrant
        returns (bytes32)
    {
        _requireContext();
        return StreamNativeClaimSalesRuntime.register(_state, _context(), config);
    }

    function closeSale(bytes32 id) external override onlyOwner nonReentrant {
        StreamNativeImmediateSalesAdministration.close(_state.common, id);
    }

    function setGlobalPause(bool value, bytes32 reason) external override nonReentrant {
        StreamNativeClaimSalesRuntime.setGlobalPause(
            _state.common,
            address(roleRegistry),
            roleRegistryCodeHash,
            governanceAuthority,
            value,
            reason
        );
    }

    function setSalePause(bytes32 id, bool value, bytes32 reason) external override nonReentrant {
        StreamNativeClaimSalesRuntime.setSalePause(
            _state.common,
            address(roleRegistry),
            roleRegistryCodeHash,
            governanceAuthority,
            id,
            value,
            reason
        );
    }

    function syncCollectionContest(uint256 collection) external override nonReentrant {
        _requireContext();
        StreamNativeImmediateSalesAdministration.syncContest(
            _state.common, _context().artist, collection
        );
    }

    function previewSignedPurchase(
        Purchase calldata p,
        StreamPrivateSaleTypes.SaleAuthorization calldata a,
        IStreamPrivateSaleAdapter.Signature calldata proof
    )
        external
        view
        override
        returns (StreamNativeSettlementTypes.NativeSettlementCandidate memory c)
    {
        _requireContext();
        (c,) = StreamNativeClaimSalesRuntime.prepare(_state, _context(), p, a, proof, 1);
    }

    function previewPublicPurchase(Purchase calldata p)
        external
        view
        override
        returns (StreamNativeSettlementTypes.NativeSettlementCandidate memory c, bytes32 id)
    {
        _requireContext();
        StreamPrivateSaleTypes.SaleAuthorization memory a;
        IStreamPrivateSaleAdapter.Signature memory proof;
        IStreamMintManager.MintBatch memory b;
        (c, b) = StreamNativeClaimSalesRuntime.prepare(_state, _context(), p, a, proof, 2);
        return (c, b.authorizationId);
    }

    function purchaseSigned(
        Purchase calldata p,
        StreamPrivateSaleTypes.SaleAuthorization calldata a,
        IStreamPrivateSaleAdapter.Signature calldata proof
    ) external payable override nonReentrant returns (S.Receipt memory) {
        return _purchase(p, a, proof, 1);
    }

    function purchasePublic(Purchase calldata p)
        external
        payable
        override
        nonReentrant
        returns (S.Receipt memory)
    {
        StreamPrivateSaleTypes.SaleAuthorization memory a;
        IStreamPrivateSaleAdapter.Signature memory proof;
        return _purchase(p, a, proof, 2);
    }

    function _purchase(
        Purchase memory p,
        StreamPrivateSaleTypes.SaleAuthorization memory a,
        IStreamPrivateSaleAdapter.Signature memory proof,
        uint8 mode
    ) private returns (S.Receipt memory r) {
        if (msg.sender != p.mint.payer || msg.sender != p.mint.executor) {
            revert S.InvalidImmediateSale();
        }
        _requireContext();
        StreamNativeImmediateSalesRuntime.Context memory x = _context();
        (
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c,
            IStreamMintManager.MintBatch memory b
        ) = StreamNativeClaimSalesRuntime.prepare(_state, x, p, a, proof, mode);
        RevealQuote memory quote = StreamImmediateSaleReveal.quote(core, c.sale.collectionId);
        if (msg.value < c.sale.amount || (!quote.policy.declared && msg.value != c.sale.amount)) {
            revert S.ImmediateSaleValueInvalid(msg.value, c.sale.amount);
        }
        uint256 revealCap = gasParameter(_REVEAL);
        uint256 excess =
            StreamImmediateSaleReveal.preflight(quote, msg.value - c.sale.amount, revealCap);
        uint256 original = address(this).balance - msg.value;
        bytes32 id = c.executionBinding.executionId;
        if (_state.common.executionStatus[id] != 0 || _state.common.activePublicId != 0) {
            revert S.ImmediateSaleResultMismatch();
        }
        _state.common.executionNonces[p.mint.saleId][p.mint.payer] = p.mint.executionNonce;
        ++_state.common.sales[p.mint.saleId].soldQuantity;
        r = S.Receipt(
            p.mint.saleId,
            id,
            b.authorizationId,
            c.executionBinding.saleAuthorizationDigest,
            c.operationIdentityCommitment,
            c.operationId,
            0,
            0,
            c.sale.amount,
            quote.policy.revealFeePerTokenWei,
            excess
        );
        _state.common.receipts[id] = r;
        _state.common.executionStatus[id] = 1;
        if (mode == 2 && c.sale.amount != 0) {
            _state.common.activePublicId = id;
            _state.common.activePublicCommitment =
                StreamNativeSettlementHash.candidateCommitment(primarySaleSettlement, c);
        }
        emit ClaimSaleExecution(p.mint.saleId, id, r.operationRoot, 1, r);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory result;
        if (c.sale.amount != 0) {
            result = StreamNativeImmediateSalesRuntime.settle(x, c);
            _retained(x, c);
        }
        r.tokenId = StreamNativeSaleMint.execute(
            mintManager, b, c.operationIdentityCommitment, c.operationId
        );
        StreamImmediateSaleReveal.fundAndAttempt(
            core, c.sale.collectionId, r.tokenId, quote, revealCap
        );
        _retained(x, c);
        if (address(this).balance != original + excess) revert SaleRevealAccountingMismatch();
        r.settlementKey = result.settlementKey;
        StreamNativeImmediateSalesRefunds.credit(_state.common, p.mint.saleId, p.mint.payer, excess);
        _state.common.receipts[id] = r;
        _state.common.executionStatus[id] = 2;
        delete _state.common.activePublicId;
        delete _state.common.activePublicCommitment;
        S.Record storage sale = _state.common.sales[p.mint.saleId];
        if (sale.config.saleSupplyLimit != 0 && sale.soldQuantity == sale.config.saleSupplyLimit) {
            sale.closed = true;
            emit ImmediateSaleClosed(p.mint.saleId, sale.soldQuantity);
        }
        if (c.sale.amount == 0) {
            emit FreeClaimExecuted(p.mint.saleId, id, r.tokenId, r.authorizationId);
        }
        emit ClaimSaleExecution(p.mint.saleId, id, r.operationRoot, 2, r);
    }

    function _retained(
        StreamNativeImmediateSalesRuntime.Context memory x,
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c
    ) private view {
        _requireContext();
        StreamNativeClaimSalesRuntime.retained(_state, x, c);
    }

    function saleRevealQuote(bytes32 id) external view override returns (RevealQuote memory) {
        return StreamImmediateSaleReveal.quote(core, _record(id).config.collectionId);
    }

    function refundLiability() external view override returns (uint256) {
        return _state.common.refundLiability;
    }

    function refundableBalance(bytes32 id, address payer) external view override returns (uint256) {
        return _state.common.refunds[id][payer];
    }

    function refundAccountCount() external view override returns (uint256) {
        return _state.common.refundPayers.length;
    }

    function refundAccountAt(uint256 i) external view override returns (bytes32, address) {
        return (_state.common.refundSales[i], _state.common.refundPayers[i]);
    }

    function claimRefund(bytes32 id, address recipient) external override nonReentrant {
        StreamNativeImmediateSalesRefunds.claim(_state.common, id, recipient);
    }

    function _record(bytes32 id) private view returns (S.Record storage r) {
        r = _state.common.sales[id];
        if (r.saleNonce == 0) revert S.ImmediateSaleUnavailable(id);
    }

    function _context() private view returns (StreamNativeImmediateSalesRuntime.Context memory x) {
        x.artist = StreamNativeCuratedSaleSupport.Context(
            core,
            moduleRegistry,
            mintManager,
            revenueResolver,
            artistRegistry,
            artistRegistryCodeHash,
            gasParameter(_ARTIST)
        );
        x.recorder = primarySaleSettlement;
        x.recorderHash = settlementCodeHash;
        x.managerHash = mintManagerCodeHash;
        x.signatureGas = gasParameter(_SALE_SIGNATURE);
    }

    function transferOwnership(address next) public override onlyOwner nonReentrant {
        super.transferOwnership(next);
    }

    function renounceOwnership() public override onlyOwner nonReentrant {
        super.renounceOwnership();
    }
}
