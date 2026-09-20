// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamERC20DutchSaleRuntime.sol";
import "./StreamERC20DutchSaleRead.sol";
import "../../interfaces/stream/revenue/IStreamERC20DutchSaleResolution.sol";
import "../../interfaces/stream/revenue/IStreamERC20DutchFreeExecution.sol";
import "../../interfaces/stream/revenue/IStreamERC20PublicSaleBinding.sol";
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

/// @notice Standard ERC20 Dutch singleton purchases under canonical Sales-v1 authority.
/// @dev No clearing rebates. Native allowance is only the original reveal fee plus executor refund.
contract StreamERC20DutchSale is
    D,
    IStreamERC20SaleExecution,
    IStreamERC20DutchSaleResolution,
    IStreamERC20DutchFreeExecution,
    IStreamERC20PublicSaleBinding,
    IStreamImmediateSaleReveal,
    IStreamArtistSaleFacts,
    IERC5267,
    IStreamImmediateSaleAuthorizationBinding,
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
    StreamERC20DutchSaleState.State private _state;

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
                    .supportsInterface(type(IStreamERC20DutchPrimarySaleSettlement).interfaceId)
                || !IERC165(address(d.recorder))
                    .supportsInterface(
                        type(IStreamERC20PublicDutchPrimarySaleSettlement).interfaceId
                    )
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

    event ImmediateSalePause(
        bytes32 indexed saleId, bool paused, address actor, bytes32 reasonHash
    );
    event ImmediateSaleClosed(bytes32 indexed saleId, uint64 soldQuantity);

    function supportsInterface(bytes4 id) public view override(ERC165, IERC165) returns (bool) {
        return id == type(D).interfaceId || id == type(IStreamERC20SaleExecution).interfaceId
            || id == type(IStreamERC20DutchSaleResolution).interfaceId
            || id == type(IStreamERC20DutchFreeExecution).interfaceId
            || id == type(IStreamERC20PublicSaleBinding).interfaceId
            || id == type(IStreamImmediateSaleAuthorizationBinding).interfaceId
            || id == type(IStreamArtistSaleFacts).interfaceId
            || id == type(IStreamImmediateSaleReveal).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId || id == type(IERC5267).interfaceId
            || super.supportsInterface(id);
    }

    function streamModuleType() external pure returns (bytes32) {
        return keccak256("DUTCH_AUCTION_ADAPTER");
    }

    function streamModuleInterfaceId() external pure returns (bytes4) {
        return type(IStreamERC20SaleExecution).interfaceId;
    }

    function dutchResolutionProfile() external pure override returns (bytes32) {
        return keccak256("6529STREAM_ERC20_STANDARD_DUTCH_V1");
    }

    function saleIdFor(uint256 collection, bytes32 phase, uint256 nonce)
        external
        view
        returns (bytes32)
    {
        return StreamERC20DutchSaleRuntime.saleId(collection, phase, nonce);
    }

    function saleConfigurationHash(D.Configuration calldata c) external view returns (bytes32) {
        return StreamERC20DutchSaleRuntime.configurationHash(c);
    }

    function registerDutchSale(D.Configuration calldata c)
        external
        override
        onlyOwner
        nonReentrant
        returns (bytes32)
    {
        _requireContext();
        _requireActive(c.asset);
        if (
            !StreamSettlementAdmission.isContract(c.paymentAdapter)
                || _read(
                        c.paymentAdapter,
                        abi.encodeWithSignature("primarySaleSettlement()"),
                        gasleft()
                    ) != uint256(uint160(primarySaleSettlement))
                || _read(c.paymentAdapter, abi.encodeWithSignature("core()"), gasleft())
                    != uint256(uint160(core))
                || _read(c.paymentAdapter, abi.encodeWithSignature("moduleRegistry()"), gasleft())
                    != uint256(uint160(moduleRegistry))
                || _read(c.paymentAdapter, abi.encodeWithSignature("revenueResolver()"), gasleft())
                    != uint256(uint160(address(revenueResolver)))
        ) revert S.InvalidImmediateSale();
        return StreamERC20DutchSaleRuntime.register(_state, _context(), c);
    }

    function dutchSaleRecord(bytes32) external view override returns (D.Record calldata) {
        _dutchRead();
    }

    function saleLifecycleBinding(bytes32 id)
        external
        view
        returns (StreamPrimarySettlementTypes.SaleLifecycleBinding memory)
    {
        _record(id);
        return _state.lifecycle[id];
    }

    function publicERC20SaleBinding(bytes32 id)
        external
        view
        override
        returns (uint256, bytes32, bytes32, uint8)
    {
        S.Record storage r = _record(id);
        return (r.config.collectionId, r.config.phaseId, r.configHash, r.config.authorityMode);
    }

    function activePublicERC20Candidate(bytes32 id) external view override returns (bytes32) {
        return
            id != 0 && id == _state.common.activePublicId
                ? _state.common.activePublicCommitment
                : bytes32(0);
    }

    function currentDutchPrice(bytes32 id) external view override returns (uint256) {
        return StreamERC20DutchSaleRuntime.price(_state, id);
    }

    function previewDutchExecution(D.Execution calldata)
        external
        view
        override
        returns (StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata, bytes calldata)
    {
        _dutchRead();
    }

    function resolveERC20DutchExecution(bytes32, bytes32, address, bytes calldata)
        external
        view
        override
        returns (StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata)
    {
        _dutchRead();
    }

    function _dutchRead() private view {
        if (
            msg.sig == D.previewDutchExecution.selector
                || msg.sig == IStreamERC20DutchSaleResolution.resolveERC20DutchExecution.selector
        ) _requireContext();
        (bytes memory encoded, address asset) =
            StreamERC20DutchSaleRead.read(_state, _context(), msg.data);
        if (asset != address(0)) _requireActive(asset);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function executeERC20PreRevenueSingleStep(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata c,
        bytes calldata data
    )
        external
        payable
        override
        nonReentrant
        returns (bytes4, StreamPrimarySettlementTypes.PrimarySettlementResult memory result)
    {
        if (c.sale.amount == 0) revert S.InvalidImmediateSale();
        result = _execute(c, data, false);
        return (IStreamERC20SaleExecution.executeERC20PreRevenueSingleStep.selector, result);
    }

    function executeERC20DutchFreeMint(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata c,
        bytes calldata data
    ) external payable override nonReentrant returns (bytes4, bytes32) {
        if (c.sale.amount != 0) revert S.InvalidImmediateSale();
        _execute(c, data, true);
        return (
            IStreamERC20DutchFreeExecution.executeERC20DutchFreeMint.selector,
            c.executionBinding.executionId
        );
    }

    function _execute(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        bytes calldata data,
        bool free
    ) private returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result) {
        if (msg.sender != c.lifecycleBinding.paymentAdapter) revert S.InvalidImmediateSale();
        _requireContext();
        _requireActive(c.asset);
        StreamNativeImmediateSalesRuntime.Context memory x = _context();
        (S.Purchase memory p, IStreamMintManager.MintBatch memory b) =
            StreamERC20DutchSaleRead.execution(_state, x, c, data, free);
        RevealQuote memory quote = StreamImmediateSaleReveal.quote(core, c.sale.collectionId);
        uint256 cap = gasParameter(_REVEAL);
        uint256 excess = StreamImmediateSaleReveal.preflight(quote, msg.value, cap);
        uint256 original = address(this).balance - msg.value;
        bytes32 id = c.executionBinding.executionId;
        if (_state.common.executionStatus[id] != 0 || _state.common.activePublicId != 0) {
            revert S.ImmediateSaleResultMismatch();
        }
        _state.common.executionNonces[p.saleId][p.payer] = p.executionNonce;
        ++_state.common.sales[p.saleId].soldQuantity;
        S.Receipt memory r = S.Receipt(
            p.saleId,
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
        if (c.executionBinding.authorityMode == 2) {
            _state.common.activePublicId = id;
            _state.common.activePublicCommitment =
                StreamPrimarySettlementHash.candidateCommitment(
                msg.sender, primarySaleSettlement, c
            );
        }
        emit ERC20DutchExecution(p.saleId, id, 1, free ? 1 : 2, r);
        if (!free) result = StreamERC20DutchSaleRuntime.settle(x, c);
        _retained(x, c, p);
        r.tokenId =
            StreamNativeSaleMint.execute(
            mintManager, b, c.operationIdentityCommitment, c.operationId
        );
        StreamImmediateSaleReveal.fundAndAttempt(core, c.sale.collectionId, r.tokenId, quote, cap);
        _retained(x, c, p);
        if (address(this).balance != original + excess) revert SaleRevealAccountingMismatch();
        r.settlementKey = result.settlementKey;
        StreamNativeImmediateSalesRefunds.credit(_state.common, p.saleId, p.executor, excess);
        _state.common.receipts[id] = r;
        _state.common.executionStatus[id] = 2;
        delete _state.common.activePublicId;
        delete _state.common.activePublicCommitment;
        S.Record storage sale = _state.common.sales[p.saleId];
        if (sale.soldQuantity == sale.config.saleSupplyLimit) {
            sale.closed = true;
            emit ImmediateSaleClosed(p.saleId, sale.soldQuantity);
        }
        emit ERC20DutchExecution(p.saleId, id, 2, free ? 1 : 2, r);
    }

    function _retained(
        StreamNativeImmediateSalesRuntime.Context memory x,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        S.Purchase memory p
    ) private view {
        _requireContext();
        _requireActive(c.asset);
        StreamERC20DutchSaleRuntime.retained(_state, x, c, p);
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
        returns (bytes32)
    {
        return StreamPrivateSaleHash.digest(
            block.chainid, address(this), StreamPrivateSaleHash.authorizationBody(a)
        );
    }

    function nextSaleNonce() external view returns (uint256) {
        return _state.common.nextSaleNonce;
    }

    function nextExecutionNonce(bytes32 id, address payer) public view returns (uint256) {
        return _state.common.executionNonces[id][payer] + 1;
    }

    function executionReceipt(bytes32) external view returns (S.Receipt calldata) {
        _dutchRead();
    }

    function executionStatus(bytes32 id) external view returns (uint8) {
        return _state.common.executionStatus[id];
    }

    function saleConsentFacts(bytes32 id) external view override returns (uint256, bytes32) {
        S.Record storage r = _record(id);
        return (r.config.collectionId, r.configHash);
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
    ) external onlyOwner nonReentrant {
        _requireContext();
        StreamNativeImmediateSalesAdministration.configureSigner(
            _state.common, collection, signer, kind, evidence, enabled
        );
    }

    function collectionSigner(uint256 collection, address signer, uint8 kind)
        external
        view
        returns (S.SignerBinding memory, bool)
    {
        StreamNativeImmediateSalesState.Signer storage s =
            _state.common.signers[collection][signer][kind];
        return (s.binding, s.enabled);
    }

    function closeSale(bytes32 id) external onlyOwner nonReentrant {
        StreamNativeImmediateSalesAdministration.close(_state.common, id);
    }

    function setGlobalPause(bool value, bytes32 reason) external nonReentrant {
        _pauseRole(value, reason);
        StreamNativeCuratedClock.setGlobal(_state.common.clocks, value);
        emit ImmediateSalePause(0, value, msg.sender, reason);
    }

    function setSalePause(bytes32 id, bool value, bytes32 reason) external nonReentrant {
        _pauseRole(value, reason);
        StreamNativeCuratedClock.setSale(
            _state.common.clocks, id, _record(id).config.collectionId, value
        );
        emit ImmediateSalePause(id, value, msg.sender, reason);
    }

    function syncCollectionContest(uint256 collection) external nonReentrant {
        _requireContext();
        StreamNativeImmediateSalesAdministration.syncContest(
            _state.common, _context().artist, collection
        );
    }

    function _pauseRole(bool value, bytes32 reason) private view {
        if (reason == 0) revert S.InvalidImmediateSale();
        StreamRefundWindowSupport.requireRole(
            address(roleRegistry),
            roleRegistryCodeHash,
            governanceAuthority,
            value ? keccak256("ROLE_PAUSE_GUARDIAN") : keccak256("ROLE_UNPAUSE")
        );
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
