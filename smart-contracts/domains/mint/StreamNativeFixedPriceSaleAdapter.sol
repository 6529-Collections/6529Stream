// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamNativeSaleCreditHost, StreamNativeSaleCreditReads, IStreamNativeSaleCredits } from "./StreamNativeSaleCreditHost.sol";
import { StreamNativeSurplusHost, StreamNativeSurplus, IStreamNativeSurplus } from "./StreamNativeSurplusHost.sol";
import { StreamNativeImmediateSaleWorker } from "./StreamNativeImmediateSaleWorker.sol";
import "./StreamNativeRefundDelegation.sol";

import "./StreamSaleArtist.sol";
import "./StreamSaleConsent.sol";
import "./StreamNativePriceProgram.sol";
import "./StreamSaleTemplate.sol";
import "./StreamImmediateSaleReveal.sol";
import "../parameters/StreamGasParameterHost.sol";
import "../revenue/StreamSettlementContext.sol";
import "../revenue/StreamPrimarySettlementHash.sol";
import "../revenue/StreamNativeSettlementHash.sol";
import "../revenue/StreamNativeSettlementAdmission.sol";
import "../revenue/StreamNativeSettlementSupport.sol";
import "../../interfaces/stream/revenue/IStreamNativePrimarySaleSettlement.sol";
import "../../interfaces/stream/mint/IStreamNativeFixedPriceSaleAdapter.sol";
import "../../interfaces/stream/mint/IStreamNativePriceProgramDomain.sol";
import "../../interfaces/standards/IERC5267.sol";
import "../../interfaces/stream/artist/IStreamArtistSaleFacts.sol";
import "../../interfaces/stream/mint/IStreamMintReads.sol";
import "../../interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";
import "../../vendor/openzeppelin/Ownable.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../../vendor/openzeppelin/ERC165.sol";

/// @notice Typed native paid mints through the shared official recorder.
/// @dev Sale revenue excludes reveal fees; unused fee allowance is a payer-owned pull credit.
contract StreamNativeFixedPriceSaleAdapter is
    StreamNativeSurplusHost,
    StreamNativeSaleCreditHost,
    IStreamNativeFixedPriceSaleAdapter,
    IStreamNativePricePrograms,
    IStreamNativePriceProgramDomain,
    IERC5267,
    IStreamArtistSaleFacts,
    StreamSettlementContext,
    StreamGasParameterHost,
    StreamNativeRefundDelegation,
    IStreamImmediateSaleReveal,
    Ownable,
    ReentrancyGuard,
    ERC165
{
    // Retain the original public error after its emitting check moved to the fixed worker.
    error SettlementBindingInvalid(address target);

    bytes32 public constant SALE_AUTHORIZATION_TYPEHASH = keccak256(
        "NativeSaleAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 executionNonce,bytes32 nonce,uint64 deadline,bytes32 expectedPrimaryPolicyHash)"
    );
    bytes32 private constant _DOMAIN = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 private constant _CONFIG = keccak256("6529STREAM_NATIVE_FIXED_PRICE_CONFIG_V1");
    bytes32 private constant _CLASS = keccak256("PRIMARY_SALE");
    bytes32 private constant _NONCE = keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1");
    IStreamMintManager public immutable mintManager;
    bytes32 public immutable mintManagerCodeHash;
    address public immutable primarySaleSettlement;
    bytes32 public immutable settlementCodeHash;
    address public immutable platformSigner;
    IStreamArtistAttribution public immutable artistRegistry;
    bytes32 public immutable artistRegistryCodeHash;
    uint256 public nextSaleNonce = 1;
    bool public paused;
    bytes32 private constant _REVEAL_GAS = keccak256("6529STREAM_GGP_REVEAL_ATTEMPT_GAS_LIMIT");
    uint256 public override refundLiability;
    mapping(bytes32 => mapping(address => uint256)) private _refunds;
    mapping(bytes32 => mapping(address => bool)) private _refundAccountSeen;
    bytes32[] private _refundSales;
    address[] private _refundPayers;
    mapping(bytes32 => SaleRecord) private _sales;
    mapping(address => mapping(bytes32 => bool)) public authorizationUsed;
    mapping(bytes32 => mapping(uint256 => bytes32)) public executionIdByNonce;
    mapping(bytes32 => uint8) public executionStatus;
    mapping(bytes32 => PriceProgramRecord) private _pricePrograms;

    constructor(
        IStreamMintManager manager,
        IStreamPrimarySaleSettlement recorder,
        address signer,
        IStreamArtistAttribution artists,
        GasParameterConfig memory revealGas,
        DelegationDeployment memory delegation
    )
        StreamSettlementContext(recorder.revenueResolver(), recorder.moduleRegistry())
        StreamGasParameterHost(IStreamSplitFactory(recorder.revenueResolver().splitFactory())
                .governanceAuthority())
        StreamNativeRefundDelegation(recorder.core(), recorder.moduleRegistry(), delegation)
    {
        if (
            keccak256(bytes(revealGas.name)) != keccak256("REVEAL_ATTEMPT_GAS_LIMIT")
                || revealGas.failureClass != FAILURE_CLASS_FAIL_CLOSED_PRECHECK
        ) revert InvalidNativeSale();
        _registerGasParameter(revealGas);
        if (delegation.registry != address(0)) _registerGasParameter(delegation.gas);
        if (
            !StreamSettlementAdmission.isContract(address(manager)) || signer == address(0)
                || !StreamSettlementAdmission.isContract(address(recorder))
                || !recorder.isStreamPrimarySaleSettlement()
                || !IERC165(address(recorder))
                    .supportsInterface(type(IStreamNativePrimarySaleSettlement).interfaceId)
                || !StreamSaleArtist.supportsAttribution(artists) || artists.core() != core
                || revenueResolver.artistRegistry() != address(artists)
                || !IStreamMintReads(address(manager)).isStreamMintManager()
                || address(IStreamMintReads(address(manager)).core()) != core
                || address(IStreamMintReads(address(manager)).moduleRegistry()) != moduleRegistry
                || recorder.core() != core
        ) revert InvalidNativeSale();
        mintManager = manager;
        mintManagerCodeHash = address(manager).codehash;
        primarySaleSettlement = address(recorder);
        settlementCodeHash = address(recorder).codehash;
        platformSigner = signer;
        artistRegistry = artists;
        artistRegistryCodeHash = address(artists).codehash;
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamNativeSaleCredits).interfaceId || id == type(IStreamNativeSurplus).interfaceId || _refundDelegationSupported(id) || id == type(IStreamImmediateSaleReveal).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId
            || id == type(IStreamNativeFixedPriceSaleAdapter).interfaceId
            || id == type(IStreamNativePricePrograms).interfaceId
            || id == type(IStreamNativePriceProgramDomain).interfaceId
            || id == type(IERC5267).interfaceId || id == type(IStreamArtistSaleFacts).interfaceId
            || id == type(IStreamNativeSaleBinding).interfaceId || super.supportsInterface(id);
    }

    /// @notice Domain for NativeSaleAuthorization and authorizationDigest().
    /// @dev PriceProgramAuthorization uses priceProgramEip712Domain() instead.
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
        bytes memory out = StreamNativeRefundReadEncoding.domain(0);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    /// @inheritdoc IStreamNativePriceProgramDomain
    function priceProgramEip712Domain()
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
        bytes memory out = StreamNativeRefundReadEncoding.domain(1);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    /// @notice Canonical declaration checked against the actual registered module record.
    function streamModuleType() external pure returns (bytes32) {
        return keccak256("NATIVE_PRIMARY_SALE_ADAPTER");
    }

    function streamModuleInterfaceId() external pure returns (bytes4) {
        return type(IStreamNativeSaleBinding).interfaceId;
    }

    /// @inheritdoc IStreamArtistSaleFacts
    function saleConsentFacts(bytes32 id)
        external
        view
        override
        returns (uint256 collectionId, bytes32 saleConfigHash)
    {
        bytes memory out =
            StreamNativeImmediateSaleWorker.read(_sales, _pricePrograms, core, msg.data);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function registerPriceProgram(PriceProgramConfig calldata config)
        external
        override
        onlyOwner
        nonReentrant
        returns (bytes32 id)
    {
        _requireRefundDelegationManifest();
        _requireSaleContext();
        id = StreamNativeImmediateSaleWorker.registerProgram(
            _pricePrograms, _priceProgramContext(), core, moduleRegistry, config, nextSaleNonce
        );
        ++nextSaleNonce;
    }

    function priceProgramIdFor(uint256 collectionId, bytes32 phaseId, uint8 kind, uint256 nonce)
        public
        view
        override
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_V1"),
                block.chainid,
                address(this),
                kind,
                collectionId,
                phaseId,
                nonce
            )
        );
    }

    function priceProgramRecord(bytes32 id)
        external
        view
        override
        returns (PriceProgramRecord memory)
    {
        bytes memory out =
            StreamNativeImmediateSaleWorker.read(_sales, _pricePrograms, core, msg.data);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function closePriceProgram(bytes32 id) external override onlyOwner nonReentrant {
        PriceProgramRecord storage record = _pricePrograms[id];
        if (record.saleNonce == 0 || record.closed) revert NativePriceProgramUnavailable(id);
        record.closed = true;
        emit NativePriceProgramClosed(id, 1, record.mintedQuantity);
    }

    function priceProgramAuthorizationDigest(PriceProgramAuthorization calldata authorization)
        external
        view
        override
        returns (bytes32)
    {
        return StreamNativePriceProgram.authorizationDigest(authorization);
    }

    function previewPriceProgram(PriceProgramExecution calldata e)
        external
        view
        override
        returns (PriceProgramResult memory r)
    {
        (StreamNativeSettlementTypes.NativeSettlementCandidate memory c,) = _preparePriceProgram(e);
        return _priceProgramResult(c);
    }

    function executePriceProgram(PriceProgramExecution calldata e)
        external
        payable
        override
        nonReentrant
        returns (PriceProgramResult memory r)
    {
        (
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c,
            IStreamMintManager.MintBatch memory batch
        ) = _preparePriceProgram(e);
        if (msg.sender != c.sale.payer || msg.sender != c.executor || msg.value < c.sale.amount) {
            revert InvalidNativePriceProgram();
        }
        uint256 original = address(this).balance - msg.value;
        RevealQuote memory reveal = StreamImmediateSaleReveal.quote(core, c.sale.collectionId);
        uint256 revealCap = gasParameter(_REVEAL_GAS);
        uint256 excess =
            StreamImmediateSaleReveal.preflight(reveal, msg.value - c.sale.amount, revealCap);
        PriceProgramRecord storage record = _pricePrograms[e.authorization.saleId];
        authorizationUsed[e.authorization.artist][e.authorization.nonce] = true;
        executionIdByNonce[e.authorization.saleId][e.authorization.executionNonce] =
        c.executionBinding.executionId;
        executionStatus[c.executionBinding.executionId] = 1;
        ++record.mintedQuantity;
        r = _priceProgramResult(c);
        if (c.sale.amount != 0) {
            StreamPrimarySettlementTypes.PrimarySettlementResult memory settled = _settle(c);
            r.settlementKey = settled.settlementKey;
            r.escrowed = settled.escrowed;
            _requireRetained(c, e.authorization.artist);
        }
        (uint256[] memory tokens, bytes32 root, bytes32[] memory ids) =
            mintManager.executeSingleStepMint(batch, "");
        if (
            tokens.length != 1 || tokens[0] == 0 || root != c.operationIdentityCommitment
                || ids.length != 1 || ids[0] != c.operationId
        ) revert NativeMintResultInvalid();
        StreamImmediateSaleReveal.fundAndAttempt(
            core, c.sale.collectionId, tokens[0], reveal, revealCap
        );
        if (c.sale.amount != 0) {
            _requireRetained(c, e.authorization.artist);
        } else {
            _requireSaleContext();
            StreamNativeSettlementAdmission.requireAdmission(moduleRegistry, c);
            _requireConsent(c.sale.settlementId);
            StreamSaleArtist.requireArtist(
                artistRegistry, artistRegistryCodeHash, c.sale.collectionId, e.authorization.artist
            );
        }
        if (address(this).balance != original + excess) revert NativeSettlementFailed();
        _creditRefund(c.sale.settlementId, c.sale.payer, excess);
        r.tokenId = tokens[0];
        executionStatus[c.executionBinding.executionId] = 2;
        StreamNativePriceProgram.emitCompletion(e.authorization.saleId, c, r, record.mintedQuantity);
    }

    /// @inheritdoc IStreamImmediateSaleReveal
    function saleRevealQuote(bytes32 id) external view override returns (RevealQuote memory) {
        bytes memory out =
            StreamNativeImmediateSaleWorker.read(_sales, _pricePrograms, core, msg.data);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function refundableBalance(bytes32 id, address payer) external view override returns (uint256) {
        return _refunds[id][payer];
    }

    function refundAccountCount() external view override returns (uint256) {
        return _refundPayers.length;
    }

    function refundAccountAt(uint256 index) external view override returns (bytes32, address) {
        return (_refundSales[index], _refundPayers[index]);
    }

    /// @dev Claims remain available while paused or after module retirement.
    function claimRefund(bytes32 id, address recipient) external override nonReentrant {
        _claimRefundAccount(id, msg.sender, recipient);
    }

    function claimRefundFor(bytes32 id, address account, DelegationWitness calldata witness)
        external
        override
        nonReentrant
        returns (uint256 amount)
    {
        _requireRefundDelegate(account, witness);
        return _claimRefundAccount(id, account, account);
    }

    function _claimRefundAccount(bytes32 id, address account, address recipient)
        private
        returns (uint256 amount)
    {
        amount = _refunds[id][account];
        if (amount == 0) revert SaleRefundEmpty(id, account);
        if (recipient == address(0) || recipient == address(this)) {
            revert SaleRefundTransferFailed(recipient);
        }
        uint256 beforeBalance = address(this).balance;
        if (beforeBalance < refundLiability) revert SaleRevealAccountingMismatch();
        _refunds[id][account] = 0;
        refundLiability -= amount;
        (bool ok,) = recipient.call{ value: amount }("");
        if (!ok) revert SaleRefundTransferFailed(recipient);
        if (address(this).balance != beforeBalance - amount) revert SaleRevealAccountingMismatch();
        emit SaleRefundClaimed(1, id, account, recipient, amount);
    }

    function _creditRefund(bytes32 id, address payer, uint256 excess) private {
        if (excess == 0) return;
        if (!_refundAccountSeen[id][payer]) {
            _refundAccountSeen[id][payer] = true;
            _refundSales.push(id);
            _refundPayers.push(payer);
        }
        _refunds[id][payer] += excess;
        refundLiability += excess;
        emit SalePaymentExcessCredited(1, id, payer, excess);
    }

    function _preparePriceProgram(PriceProgramExecution calldata e)
        private
        view
        returns (
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c,
            IStreamMintManager.MintBatch memory batch
        )
    {
        _requireSaleContext();
        if (_pricePrograms[e.authorization.saleId].saleNonce == 0) {
            revert NativePriceProgramUnavailable(e.authorization.saleId);
        }
        _requireConsent(e.authorization.saleId);
        if (authorizationUsed[e.authorization.artist][e.authorization.nonce]) {
            revert NativeAuthorizationUsed(e.authorization.artist, e.authorization.nonce);
        }
        if (executionIdByNonce[e.authorization.saleId][e.authorization.executionNonce] != 0) {
            revert NativeExecutionUsed(e.authorization.saleId, e.authorization.executionNonce);
        }
        (c, batch) = StreamNativePriceProgram.prepare(
            _priceProgramContext(), _pricePrograms[e.authorization.saleId], e, paused
        );
        StreamNativeSettlementAdmission.requireAdmission(moduleRegistry, c);
    }

    function _priceProgramResult(StreamNativeSettlementTypes.NativeSettlementCandidate memory c)
        private
        pure
        returns (PriceProgramResult memory r)
    {
        r.revenueOutcome = c.sale.amount == 0 ? 1 : 2;
        r.executionId = c.executionBinding.executionId;
        r.operationRoot = c.operationIdentityCommitment;
        r.operationId = c.operationId;
        r.chargedAmount = c.sale.amount;
    }

    function _priceProgramContext() private view returns (StreamNativePriceProgram.Context memory) {
        return StreamNativePriceProgram.Context(
            mintManager,
            revenueResolver,
            splitFactory,
            factoryCodeHash,
            artistRegistry,
            artistRegistryCodeHash,
            platformSigner
        );
    }

    function registerSale(SaleConfig calldata config)
        external
        override
        onlyOwner
        nonReentrant
        returns (bytes32 saleId)
    {
        _requireRefundDelegationManifest();
        _requireSaleContext();
        saleId = StreamNativeImmediateSaleWorker.registerFixed(
            _sales, _priceProgramContext(), core, moduleRegistry, config, nextSaleNonce
        );
        ++nextSaleNonce;
    }

    function saleIdFor(uint256 collectionId, bytes32 phaseId, uint256 nonce)
        public
        view
        override
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_V1"),
                block.chainid,
                address(this),
                uint8(0),
                collectionId,
                phaseId,
                nonce
            )
        );
    }

    function saleRecord(bytes32 id) external view override returns (SaleRecord memory) {
        bytes memory out =
            StreamNativeImmediateSaleWorker.read(_sales, _pricePrograms, core, msg.data);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function nativeSaleLifecycleBinding(bytes32 id)
        external
        view
        override
        returns (StreamNativeSettlementTypes.SaleLifecycleBinding memory)
    {
        bytes memory out =
            StreamNativeImmediateSaleWorker.read(_sales, _pricePrograms, core, msg.data);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function cancelSale(bytes32 id) external override onlyOwner nonReentrant {
        if (_sales[id].saleNonce == 0 || _sales[id].cancelled) revert NativeSaleUnavailable(id);
        _sales[id].cancelled = true;
        emit NativeSaleCancelled(id, 1);
    }

    function setPaused(bool value) external override onlyOwner nonReentrant {
        paused = value;
        emit NativeSalesPaused(1, value);
    }

    function cancelAuthorization(bytes32 nonce) external override nonReentrant {
        if (authorizationUsed[msg.sender][nonce]) {
            revert NativeAuthorizationUsed(msg.sender, nonce);
        }
        authorizationUsed[msg.sender][nonce] = true;
        emit NativeAuthorizationCancelled(msg.sender, nonce, 1);
    }

    function transferOwnership(address newOwner) public override onlyOwner nonReentrant {
        super.transferOwnership(newOwner);
    }

    function renounceOwnership() public override onlyOwner nonReentrant {
        super.renounceOwnership();
    }

    function authorizationDigest(SaleAuthorization calldata authorization)
        external
        view
        override
        returns (bytes32)
    {
        bytes memory out =
            StreamNativeImmediateSaleWorker.read(_sales, _pricePrograms, core, msg.data);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function previewExecution(SaleExecutionData calldata execution)
        external
        view
        override
        returns (StreamNativeSettlementTypes.NativeSettlementCandidate memory c)
    {
        _requireSaleContext();
        _requireConsent(execution.authorization.saleId);
        bytes memory out = StreamNativeImmediateSaleWorker.preview(
            _priceProgramContext(),
            _sales[execution.authorization.saleId],
            execution,
            paused,
            authorizationUsed[execution.authorization.artist][execution.authorization.nonce],
            executionIdByNonce[execution.authorization
                .saleId][execution.authorization.executionNonce]
        );
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function purchase(SaleExecutionData calldata execution)
        external
        payable
        override
        nonReentrant
        returns (
            StreamPrimarySettlementTypes.PrimarySettlementResult memory result,
            uint256 tokenId
        )
    {
        (
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c,
            IStreamMintManager.MintBatch memory batch
        ) = _candidate(execution);
        if (msg.sender != c.sale.payer || msg.sender != c.executor || msg.value < c.sale.amount) {
            revert InvalidNativeSale();
        }
        uint256 original = address(this).balance - msg.value;
        RevealQuote memory reveal = StreamImmediateSaleReveal.quote(core, c.sale.collectionId);
        uint256 revealCap = gasParameter(_REVEAL_GAS);
        uint256 excess =
            StreamImmediateSaleReveal.preflight(reveal, msg.value - c.sale.amount, revealCap);
        StreamNativeSettlementAdmission.requireAdmission(moduleRegistry, c);
        authorizationUsed[execution.authorization.artist][execution.authorization.nonce] = true;
        executionIdByNonce[execution.authorization.saleId][execution.authorization.executionNonce] =
            c.executionBinding.executionId;
        executionStatus[c.executionBinding.executionId] = 1;
        emit NativeSaleExecution(
            execution.authorization.saleId,
            c.executionBinding.executionId,
            c.operationIdentityCommitment,
            1,
            1,
            0,
            0
        );
        result = _settle(c);
        _requireRetained(c, execution.authorization.artist);
        (uint256[] memory tokens, bytes32 root, bytes32[] memory ids) =
            mintManager.executeSingleStepMint(batch, "");
        if (
            tokens.length != 1 || tokens[0] == 0 || root != c.operationIdentityCommitment
                || ids.length != 1 || ids[0] != c.operationId
        ) revert NativeMintResultInvalid();
        StreamImmediateSaleReveal.fundAndAttempt(
            core, c.sale.collectionId, tokens[0], reveal, revealCap
        );
        _requireRetained(c, execution.authorization.artist);
        if (address(this).balance != original + excess) revert NativeSettlementFailed();
        _creditRefund(c.sale.settlementId, c.sale.payer, excess);
        tokenId = tokens[0];
        executionStatus[c.executionBinding.executionId] = 2;
        emit NativeSaleExecution(
            execution.authorization.saleId,
            c.executionBinding.executionId,
            root,
            1,
            2,
            result.settlementKey,
            tokenId
        );
    }

    function _requireRetained(
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c,
        address artist
    ) private view {
        _requireSaleContext();
        StreamNativeSettlementAdmission.requireAdmission(moduleRegistry, c);
        _requireConsent(c.sale.settlementId);
        StreamSaleArtist.requireArtist(
            artistRegistry, artistRegistryCodeHash, c.sale.collectionId, artist
        );
        StreamNativeSettlementSupport.requireCurrent(
            revenueResolver,
            c.sale.collectionId,
            StreamSaleTemplate.Selection(
                c.rights.profileId,
                c.rights.wallet,
                c.rights.templateId,
                c.rights.assignmentHash,
                c.rights.entriesHash
            )
        );
    }

    function _candidate(SaleExecutionData memory e)
        private
        view
        returns (
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c,
            IStreamMintManager.MintBatch memory batch
        )
    {
        _requireSaleContext();
        _requireConsent(e.authorization.saleId);
        return StreamNativePriceProgram.prepareFixed(
            _priceProgramContext(),
            _sales[e.authorization.saleId],
            e,
            paused,
            authorizationUsed[e.authorization.artist][e.authorization.nonce],
            executionIdByNonce[e.authorization.saleId][e.authorization.executionNonce]
        );
    }

    function _requireConsent(bytes32 id) private view {
        StreamNativeImmediateSaleWorker.requireConsent(
            _sales, _pricePrograms, core, address(artistRegistry), artistRegistryCodeHash, id
        );
    }

    function _rights(uint256 collectionId)
        private
        view
        returns (StreamSaleTemplate.Selection memory)
    {
        return StreamNativeSettlementSupport.rights(revenueResolver, collectionId);
    }

    function _requireSaleContext() private view {
        StreamNativeImmediateSaleWorker.requireContext();
    }

    function _settle(StreamNativeSettlementTypes.NativeSettlementCandidate memory c)
        private
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory)
    {
        return StreamNativePriceProgram.settle(primarySaleSettlement, c);
    }

    function sweepNativeSurplus(uint256 amount, bytes32 reasonHash)
        external override nonReentrant returns (uint256)
    {
        return _sweepNativeSurplus(amount, reasonHash);
    }
    function _nativeSurplusOwed() internal view override returns (uint256) { return refundLiability; }
    function _nativeSaleCreditRead() internal view override returns (bytes memory) {
        return StreamNativeSaleCreditReads.fixedRead(_refunds, _refundSales, _refundPayers, refundLiability, msg.data);
    }
}
