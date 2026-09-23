// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamSaleArtist.sol";
import "./StreamUniversalAllowlistPrice.sol";
import "./StreamUniversalAllowlistPriceRead.sol";
import "./StreamUniversalSaleExecution.sol";
import "../parameters/StreamGasParameterHost.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import "./StreamSaleConsent.sol";
import "./StreamUniversalSaleRights.sol";
import "../../interfaces/stream/artist/IStreamArtistSaleFacts.sol";
import "./StreamSaleTemplate.sol";
import "../revenue/StreamSettlementContext.sol";
import "../revenue/StreamPrimarySettlementHash.sol";
import {IStreamUniversalFixedPriceSaleAdapter as F} from "../../interfaces/stream/mint/IStreamUniversalFixedPriceSaleAdapter.sol";
import "../../interfaces/standards/IERC5267.sol";
import "../../interfaces/stream/mint/IStreamMintReads.sol";
import "../../interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";
import "../../vendor/openzeppelin/Ownable.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../../vendor/openzeppelin/ERC165.sol";

/// @notice Repeatable signed sale programs consumed through the sole universal payer boundary.
/// @dev This consumer accepts only fixed collection PROFILE rights and single-step one-token
///      minting. ERC20 price and native reveal allowance are separate; only the executor
///      owns excess native credit. It never pulls tokens or records official revenue totals.
contract StreamUniversalAllowlistPriceSale is
    IStreamUniversalAllowlistPriceSale,
    StreamGasParameterHost,
    IStreamImmediateSaleReveal,
    IStreamERC20SaleExecution,
    IStreamSaleLifecycleBinding,
    IStreamArtistSaleFacts,
    IERC5267,
    StreamSettlementContext,
    Ownable,
    ReentrancyGuard,
    ERC165
{
    // Preserve decoding of the original admission errors from the fixed linked worker.
    error SaleLifecycleMismatch(address saleAdapter, bytes32 saleId);
    error SaleLifecycleReadFailed(address saleAdapter);
    error SaleLifecycleReadMalformed(address saleAdapter, uint256 length);
    error SettlementModuleNotAdmitted(address module);
    error SettlementModuleReadFailed(address module);
    error SettlementModuleReadMalformed(address module, uint256 length);

    bytes32 public constant REVEAL_ATTEMPT_GAS_LIMIT = keccak256("6529STREAM_GGP_REVEAL_ATTEMPT_GAS_LIMIT");
    bytes32 public constant SALE_AUTHORIZATION_TYPEHASH = keccak256(
        "UniversalSaleAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 executionNonce,bytes32 nonce,uint64 deadline)"
    );
    bytes32 private constant _DOMAIN = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 private constant _CONFIG = keccak256("6529STREAM_UNIVERSAL_FIXED_PRICE_CONFIG_V1");
    bytes32 private constant _CLASS = keccak256("PRIMARY_SALE");
    bytes32 private constant _TICKET_AUTHORIZATION =
        keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1");
    IStreamMintManager public immutable mintManager;
    bytes32 public immutable mintManagerCodeHash;
    address public immutable primarySaleSettlement;
    bytes32 public immutable settlementCodeHash;
    address public immutable platformSigner;
    IStreamArtistAttribution public immutable artistRegistry;
    bytes32 public immutable artistRegistryCodeHash;
    uint256 public nextSaleNonce = 1;
    bool public paused;
    mapping(bytes32 => F.SaleRecord) private _sales;
    mapping(address => mapping(bytes32 => bool)) public authorizationUsed;
    mapping(bytes32 => mapping(uint256 => bytes32)) public executionIdByNonce;
    mapping(bytes32 => uint8) public executionStatus;
    // This carrier owns its compiler-declared storage; no legacy storage is aliased.
    mapping(bytes32 => AllowlistPricePolicy) private _allowlistPricePolicies;
    // New carrier state only. Existing Universal storage is not changed or inherited.
    uint256 public override refundLiability;
    mapping(bytes32 => mapping(address => uint256)) private _refunds;
    mapping(bytes32 => mapping(address => bool)) private _refundSeen;
    bytes32[] private _refundSales;
    address[] private _refundExecutors;

    constructor(
        IStreamMintManager manager,
        IStreamPrimarySaleSettlement recorder,
        address signer,
        IStreamArtistAttribution artists,
        GasParameterConfig memory revealGas
    ) StreamSettlementContext(recorder.revenueResolver(), recorder.moduleRegistry())
      StreamGasParameterHost(IStreamSplitFactory(recorder.revenueResolver().splitFactory()).governanceAuthority()) {
        if (keccak256(bytes(revealGas.name)) != keccak256("REVEAL_ATTEMPT_GAS_LIMIT") || revealGas.floor < 100_000 || revealGas.failureClass != FAILURE_CLASS_FAIL_CLOSED_PRECHECK) revert GasParameterInvalidConfig(REVEAL_ATTEMPT_GAS_LIMIT);
        _registerGasParameter(revealGas);
        if (
            !StreamSettlementAdmission.isContract(address(manager)) || signer == address(0)
                || !StreamSettlementAdmission.isContract(address(recorder))
                || !recorder.isStreamPrimarySaleSettlement()
                || !StreamSaleArtist.supportsAttribution(artists) || artists.core() != core
                || revenueResolver.artistRegistry() != address(artists)
                || !IStreamMintReads(address(manager)).isStreamMintManager()
                || address(IStreamMintReads(address(manager)).core()) != core
                || address(IStreamMintReads(address(manager)).moduleRegistry()) != moduleRegistry
                || recorder.core() != core
        ) revert F.InvalidUniversalSale();
        mintManager = manager;
        mintManagerCodeHash = address(manager).codehash;
        primarySaleSettlement = address(recorder);
        settlementCodeHash = address(recorder).codehash;
        platformSigner = signer;
        artistRegistry = artists;
        artistRegistryCodeHash = address(artists).codehash;
    }


    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamImmediateSaleReveal).interfaceId
            || id == type(IStreamUniversalAllowlistPriceSale).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId
            || id == type(IERC5267).interfaceId
            || id == type(IStreamERC20SaleExecution).interfaceId
            || id == type(IStreamArtistSaleFacts).interfaceId
            || id == type(IStreamSaleLifecycleBinding).interfaceId || super.supportsInterface(id);
    }

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
        return (
            hex"0f", "6529StreamUniversalFixedPriceSaleAdapter", "1", block.chainid,
            address(this), bytes32(0), new uint256[](0)
        );
    }

    function streamModuleType() external pure returns (bytes32) {
        return keccak256("FIXED_PRICE_SALE_ADAPTER");
    }

    function streamModuleInterfaceId() external pure returns (bytes4) {
        return type(IStreamERC20SaleExecution).interfaceId;
    }

    function saleConsentFacts(bytes32 id)
        external
        view
        override
        returns (uint256 collectionId, bytes32 saleConfigHash)
    {
        F.SaleRecord storage record = _sales[id];
        if (record.saleNonce == 0) revert SaleConsentFactsUnavailable(id);
        return (record.config.collectionId, record.configHash);
    }

    function registerAllowlistSale(F.SaleConfig calldata config, AllowlistPricePolicy calldata policy)
        external override onlyOwner nonReentrant returns (bytes32 saleId)
    {
        StreamPrimarySettlementTypes.SaleLifecycleBinding memory binding = StreamUniversalAllowlistPriceRead.registration(config,policy);
        uint256 nonce = nextSaleNonce++;
        saleId = saleIdFor(config.collectionId, config.phaseId, nonce);
        bytes32 hash = keccak256(abi.encode(keccak256("6529STREAM_UNIVERSAL_ALLOWLIST_CONFIG_V1"),keccak256(abi.encode(_CONFIG,saleId,config)),policy));
        _allowlistPricePolicies[saleId] = policy;
        _sales[saleId] = F.SaleRecord(config,nonce,hash,binding,false);
        emit UniversalSaleConfigured(saleId,config.collectionId,config.phaseId,1,nonce,hash,config.paymentAdapter);
        emit UniversalAllowlistPriceConfigured(saleId,1,policy.priceCounterId,policy.allowFree);
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

    function saleRecord(bytes32 id) external view override returns (F.SaleRecord memory) {
        return _sales[id];
    }

    function saleLifecycleBinding(bytes32 id)
        external
        view
        override
        returns (StreamPrimarySettlementTypes.SaleLifecycleBinding memory)
    {
        return _sales[id].lifecycle;
    }

    function cancelSale(bytes32 id) external override onlyOwner nonReentrant {
        if (_sales[id].saleNonce == 0 || _sales[id].cancelled) revert F.UniversalSaleUnavailable(id);
        _sales[id].cancelled = true;
        emit UniversalSaleCancelled(id, 1);
    }

    function setPaused(bool value) external override onlyOwner nonReentrant {
        paused = value;
        emit UniversalSalesPaused(1, value);
    }

    function cancelAuthorization(bytes32 nonce) external override nonReentrant {
        if (authorizationUsed[msg.sender][nonce]) {
            revert F.UniversalAuthorizationUsed(msg.sender, nonce);
        }
        authorizationUsed[msg.sender][nonce] = true;
        emit UniversalAuthorizationCancelled(msg.sender, nonce, 1);
    }

    function transferOwnership(address newOwner) public override onlyOwner nonReentrant {
        super.transferOwnership(newOwner);
    }

    function renounceOwnership() public override onlyOwner nonReentrant {
        super.renounceOwnership();
    }

    function authorizationDigest(F.SaleAuthorization calldata authorization)
        external
        view
        override
        returns (bytes32)
    {
        return _authorizationDigest(authorization);
    }

    function _authorizationDigest(F.SaleAuthorization memory authorization)
        private
        view
        returns (bytes32)
    {
        bytes32 domain = keccak256(
            abi.encode(
                _DOMAIN,
                keccak256("6529StreamUniversalFixedPriceSaleAdapter"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
        return keccak256(
            abi.encodePacked(
                hex"1901", domain, keccak256(abi.encode(SALE_AUTHORIZATION_TYPEHASH, authorization))
            )
        );
    }

    function allowlistPricePolicy(bytes32 id) external view override returns (AllowlistPricePolicy memory) {
        return _allowlistPricePolicies[id];
    }

    function previewAllowlistExecution(F.SaleExecutionData calldata, bytes calldata)
        external view override returns (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory, bytes memory)
    {
        bytes memory result = StreamUniversalAllowlistPriceRead.previewEncoded(_sales,_allowlistPricePolicies,authorizationUsed,executionIdByNonce,msg.data);
        assembly ("memory-safe") { return(add(result,32),mload(result)) }
    }

    function allowlistRevealQuote(bytes32 id) external view override returns (IStreamImmediateSaleReveal.RevealQuote memory) {
        _requireSaleContext();
        if (_allowlistPricePolicies[id].priceCounterId == 0) revert InvalidUniversalPriceProfile();
        return StreamUniversalAllowlistPrice.quote(core, _sales[id].config.collectionId);
    }

    function executeAllowlistFreeMint(F.SaleExecutionData calldata e, bytes calldata resolverData)
        external payable override nonReentrant returns (uint256 tokenId, bytes32 operationRoot, bytes32 executionId)
    {
        (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c, IStreamMintManager.MintBatch memory batch) = _candidate(e,resolverData);
        if (msg.sender != c.executor || c.sale.amount != 0) revert InvalidUniversalPriceProfile();
        StreamUniversalSaleExecution.requireAdmission(moduleRegistry,c.lifecycleBinding.paymentAdapter,c);
        uint256 originalNativeBalance = address(this).balance - msg.value;
        if (originalNativeBalance < refundLiability) revert SaleRevealAccountingMismatch();
        IStreamImmediateSaleReveal.RevealQuote memory reveal = StreamImmediateSaleReveal.quote(core,c.sale.collectionId);
        uint256 cap = _gasParameterValue(REVEAL_ATTEMPT_GAS_LIMIT);
        uint256 excess = StreamImmediateSaleReveal.preflight(reveal,msg.value,cap);
        authorizationUsed[e.authorization.artist][e.authorization.nonce] = true;
        executionIdByNonce[e.authorization.saleId][e.authorization.executionNonce] = c.executionBinding.executionId;
        executionStatus[c.executionBinding.executionId] = 1;
        emit UniversalSaleExecution(e.authorization.saleId,c.executionBinding.executionId,c.operationIdentityCommitment,1,1,0,0);
        _requireAllowlistRetained(c,e,resolverData);
        (uint256[] memory tokens, bytes32 root, bytes32[] memory ids) = mintManager.executeSingleStepMint(batch, "");
        if (tokens.length != 1 || tokens[0] == 0 || root != c.operationIdentityCommitment || ids.length != 1 || ids[0] != c.operationId) revert F.UniversalMintResultInvalid();
        StreamImmediateSaleReveal.fundAndAttempt(core,c.sale.collectionId,tokens[0],reveal,cap);
        _requireAllowlistRetained(c,e,resolverData);
        if (address(this).balance != originalNativeBalance + excess) revert SaleRevealAccountingMismatch();
        _creditRevealExcess(e.authorization.saleId,c.executor,excess);
        executionStatus[c.executionBinding.executionId] = 2;
        emit UniversalSaleExecution(e.authorization.saleId,c.executionBinding.executionId,root,1,2,0,tokens[0]);
        emit UniversalAllowlistFreeMint(e.authorization.saleId,c.executionBinding.executionId,root,1,c.operationId,tokens[0],c.sale.payer,c.sale.beneficiary);
        return (tokens[0],root,c.executionBinding.executionId);
    }

    function executeERC20PreRevenueSingleStep(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata candidate,
        bytes calldata data
    )
        external
        payable
        override
        nonReentrant
        returns (bytes4 magic, StreamPrimarySettlementTypes.PrimarySettlementResult memory result)
    {
        (F.SaleExecutionData memory e,uint256 selectedAmount,bytes memory resolverData) = StreamUniversalAllowlistPrice.decode(data);
        (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,IStreamMintManager.MintBatch memory batch) = _candidate(e,resolverData);
        if (selectedAmount == 0 || selectedAmount != c.sale.amount) revert InvalidUniversalPriceProfile();
        if (
            msg.sender != c.lifecycleBinding.paymentAdapter
                || keccak256(abi.encode(c)) != keccak256(abi.encode(candidate))
        ) revert F.UniversalCandidateMismatch();
        StreamUniversalSaleExecution.requireAdmission(moduleRegistry, msg.sender, c);
        uint256 originalNativeBalance = address(this).balance - msg.value;
        if (originalNativeBalance < refundLiability) revert SaleRevealAccountingMismatch();
        IStreamImmediateSaleReveal.RevealQuote memory reveal = StreamImmediateSaleReveal.quote(core,c.sale.collectionId);
        uint256 revealCap = _gasParameterValue(REVEAL_ATTEMPT_GAS_LIMIT);
        uint256 excess = StreamImmediateSaleReveal.preflight(reveal,msg.value,revealCap);
        authorizationUsed[e.authorization.artist][e.authorization.nonce] = true;
        executionIdByNonce[e.authorization.saleId][e.authorization.executionNonce] =
        c.executionBinding.executionId;
        executionStatus[c.executionBinding.executionId] = 1;
        emit UniversalSaleExecution(
            e.authorization.saleId,
            c.executionBinding.executionId,
            c.operationIdentityCommitment,
            1,
            1,
            0,
            0
        );
        result = _settle(c);
        // retained() performs context, consent, admission, Artist, rights, phase and leaf checks.
        _requireAllowlistRetained(c,e,resolverData);
        (uint256[] memory tokens, bytes32 root, bytes32[] memory ids) =
            mintManager.executeSingleStepMint(batch, "");
        if (
            tokens.length != 1 || tokens[0] == 0 || root != c.operationIdentityCommitment
                || ids.length != 1 || ids[0] != c.operationId
        ) revert F.UniversalMintResultInvalid();
        StreamImmediateSaleReveal.fundAndAttempt(core,c.sale.collectionId,tokens[0],reveal,revealCap);
        _requireAllowlistRetained(c,e,resolverData);
        _requireConsent(e.authorization.saleId);
        if (address(this).balance != originalNativeBalance + excess) revert SaleRevealAccountingMismatch();
        _creditRevealExcess(e.authorization.saleId,c.executor,excess);
        executionStatus[c.executionBinding.executionId] = 2;
        emit UniversalSaleExecution(
            e.authorization.saleId,
            c.executionBinding.executionId,
            root,
            1,
            2,
            result.settlementKey,
            tokens[0]
        );
        return (IStreamERC20SaleExecution.executeERC20PreRevenueSingleStep.selector, result);
    }

    function saleRevealQuote(bytes32 id) external view override returns (RevealQuote memory) {
        F.SaleRecord storage record = _sales[id];
        if (record.saleNonce == 0) revert F.UniversalSaleUnavailable(id);
        _requireSaleContext();
        return StreamImmediateSaleReveal.quote(core, record.config.collectionId);
    }

    function refundableBalance(bytes32 id, address executor) external view override returns (uint256) {
        return _refunds[id][executor];
    }

    function refundAccountCount() external view override returns (uint256) {
        return _refundSales.length;
    }

    function refundAccountAt(uint256 index)
        external view override returns (bytes32 id, address executor)
    {
        return (_refundSales[index], _refundExecutors[index]);
    }

    function claimRefund(bytes32 id, address recipient) external override nonReentrant {
        uint256 amount = _refunds[id][msg.sender];
        if (amount == 0) revert SaleRefundEmpty(id, msg.sender);
        if (recipient == address(0) || recipient == address(this)) {
            revert SaleRefundTransferFailed(recipient);
        }
        uint256 beforeBalance = address(this).balance;
        if (beforeBalance < refundLiability) revert SaleRevealAccountingMismatch();
        _refunds[id][msg.sender] = 0;
        refundLiability -= amount;
        (bool ok,) = recipient.call{value: amount}("");
        if (!ok) revert SaleRefundTransferFailed(recipient);
        if (address(this).balance != beforeBalance - amount) revert SaleRevealAccountingMismatch();
        emit SaleRefundClaimed(1, id, msg.sender, recipient, amount);
    }

    function _creditRevealExcess(bytes32 id, address executor, uint256 amount) private {
        if (amount == 0) return;
        if (!_refundSeen[id][executor]) {
            _refundSeen[id][executor] = true;
            _refundSales.push(id);
            _refundExecutors.push(executor);
        }
        _refunds[id][executor] += amount;
        refundLiability += amount;
        emit SalePaymentExcessCredited(1, id, executor, amount);
    }

    function _candidate(F.SaleExecutionData memory e,bytes memory resolverData) private view returns (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,IStreamMintManager.MintBatch memory batch) {
        return StreamUniversalAllowlistPriceRead.candidate(_sales,_allowlistPricePolicies,authorizationUsed,executionIdByNonce,e,resolverData);
    }
    function _requireAllowlistRetained(StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,F.SaleExecutionData memory e,bytes memory resolverData) private view {
        StreamUniversalAllowlistPriceRead.retained(_sales,_allowlistPricePolicies,c,e,resolverData);
    }

    function _requireConsent(bytes32 id) private view {
        F.SaleRecord storage record = _sales[id];
        if (record.saleNonce == 0) revert F.UniversalSaleUnavailable(id);
        StreamSaleConsent.requireConsent(
            core,
            address(artistRegistry),
            artistRegistryCodeHash,
            record.config.collectionId,
            id,
            record.configHash
        );
    }



    function _requireSaleContext() private view {
        _requireContext();
        if (primarySaleSettlement.codehash != settlementCodeHash) {
            revert InvalidSettlementContext(primarySaleSettlement);
        }
        if (address(mintManager).codehash != mintManagerCodeHash) {
            revert InvalidSettlementContext(address(mintManager));
        }
    }

    function _settle(StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c)
        private
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result)
    {
        bytes memory data = abi.encodeCall(
            IStreamPrimarySaleSettlement.settleERC20PrimarySaleFromAdapter, (msg.sender, c)
        );
        bytes memory response = new bytes(384);
        address target = primarySaleSettlement;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := call(gas(), target, 0, add(data, 32), mload(data), add(response, 32), 384)
            size := returndatasize()
        }
        if (!ok || size != 384) revert F.UniversalSettlementFailed();
        result = abi.decode(response, (StreamPrimarySettlementTypes.PrimarySettlementResult));
        if (
            result.candidateCommitment
                    != StreamPrimarySettlementHash.candidateCommitment(
                        msg.sender, primarySaleSettlement, c
                    )
                || result.settlementKey
                    != StreamPrimarySettlementHash.settlementKey(
                        primarySaleSettlement, address(this), c.executionBinding.executionId
                    ) || result.profileId != c.rights.profileId || result.wallet != c.rights.wallet
                || result.asset != c.asset || result.amount != c.sale.amount
                || result.executor != c.executor
                || result.executionId != c.executionBinding.executionId
                || result.operationIdentityCommitment != c.operationIdentityCommitment
                || result.currentPolicyHash != c.currentPolicyHash
                || result.boundPolicyHash != c.boundPolicyHash
        ) revert F.UniversalSettlementFailed();
    }
}
