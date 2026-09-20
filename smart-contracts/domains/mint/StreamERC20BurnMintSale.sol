// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamSaleArtist.sol";
import "./StreamERC20BurnMintSupport.sol";
import "./StreamERC20BurnMintRuntime.sol";
import "./StreamSaleConsent.sol";
import "./StreamUniversalSaleRights.sol";
import "../../interfaces/stream/artist/IStreamArtistSaleFacts.sol";
import "./StreamSaleTemplate.sol";
import "../revenue/StreamSettlementContext.sol";
import "../revenue/StreamPrimarySettlementHash.sol";
import "../../interfaces/stream/mint/IStreamERC20BurnMintSale.sol";
import "../../interfaces/stream/mint/IStreamERC20BurnMintGate.sol";
import "./StreamImmediateSaleReveal.sol";
import "../parameters/StreamGasParameterHost.sol";
import "../../interfaces/standards/IERC5267.sol";
import "../../interfaces/stream/mint/IStreamMintReads.sol";
import "../../interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";
import "../../vendor/openzeppelin/Ownable.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../../vendor/openzeppelin/ERC165.sol";

/// @notice Original universal authorization and settlement for dedicated same-transaction ERC20 burns.
/// @dev Positive PROFILE, one token, order one and zero native reveal fee/value.
/// The shared payable callback ABI rejects nonzero value before any burn or sale effects.
/// Original authorization, free/native burn routes and Manager/Ledger behavior are retained.
contract StreamERC20BurnMintSale is
    IStreamERC20BurnMintSale,
    IStreamERC20BurnMintContinuation,
    StreamGasParameterHost,
    IStreamERC20SaleExecution,
    IStreamSaleLifecycleBinding,
    IStreamArtistSaleFacts,
    IERC5267,
    StreamSettlementContext,
    Ownable,
    ReentrancyGuard,
    ERC165
{
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
    StreamERC20BurnMintState.State private _state;
    bytes32 private constant REVEAL_GAS = keccak256("6529STREAM_GGP_REVEAL_ATTEMPT_GAS_LIMIT");

    constructor(
        IStreamMintManager manager,
        IStreamPrimarySaleSettlement recorder,
        address signer,
        IStreamArtistAttribution artists,
        address authority,
        GasParameterConfig memory revealGas
    )
        StreamSettlementContext(recorder.revenueResolver(), recorder.moduleRegistry())
        StreamGasParameterHost(authority)
    {
        if (
            authority != splitFactory.governanceAuthority() || revealGas.failureClass != 2
                || _registerGasParameter(revealGas) != REVEAL_GAS
        ) revert InvalidUniversalSale();
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
        ) revert InvalidUniversalSale();
        _state.nextSaleNonce = 1;
        mintManager = manager;
        mintManagerCodeHash = address(manager).codehash;
        primarySaleSettlement = address(recorder);
        settlementCodeHash = address(recorder).codehash;
        platformSigner = signer;
        artistRegistry = artists;
        artistRegistryCodeHash = address(artists).codehash;
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamERC20BurnMintSale).interfaceId
            || id == type(IStreamERC20BurnMintContinuation).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId || id == type(IERC5267).interfaceId
            || id == type(IStreamERC20SaleExecution).interfaceId
            || id == type(IStreamArtistSaleFacts).interfaceId
            || id == type(IStreamSaleLifecycleBinding).interfaceId || super.supportsInterface(id);
    }

    /// @notice Domain for UniversalSaleAuthorization and authorizationDigest().
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
            hex"0f",
            "6529StreamUniversalFixedPriceSaleAdapter",
            "1",
            block.chainid,
            address(this),
            bytes32(0),
            new uint256[](0)
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
        U.SaleRecord storage record = _state.sales[id];
        if (record.saleNonce == 0) revert SaleConsentFactsUnavailable(id);
        return (record.config.collectionId, record.configHash);
    }

    function registerSale(U.SaleConfig calldata config)
        external
        override
        onlyOwner
        nonReentrant
        returns (bytes32 saleId)
    {
        return StreamERC20BurnMintRuntime.registerSale(_state, _context(), config);
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
                uint8(8),
                collectionId,
                phaseId,
                nonce
            )
        );
    }

    function saleRecord(bytes32 id) external view override returns (U.SaleRecord memory) {
        return _state.sales[id];
    }

    function saleLifecycleBinding(bytes32 id)
        external
        view
        override
        returns (StreamPrimarySettlementTypes.SaleLifecycleBinding memory)
    {
        return _state.sales[id].lifecycle;
    }

    function cancelSale(bytes32 id) external override onlyOwner nonReentrant {
        if (_state.sales[id].saleNonce == 0 || _state.sales[id].cancelled) {
            revert UniversalSaleUnavailable(id);
        }
        _state.sales[id].cancelled = true;
        emit UniversalSaleCancelled(id, 1);
    }

    function setPaused(bool value) external override onlyOwner nonReentrant {
        _state.paused = value;
        emit UniversalSalesPaused(1, value);
    }

    function cancelAuthorization(bytes32 nonce) external override nonReentrant {
        if (_state.authorizationUsed[msg.sender][nonce]) {
            revert UniversalAuthorizationUsed(msg.sender, nonce);
        }
        _state.authorizationUsed[msg.sender][nonce] = true;
        emit UniversalAuthorizationCancelled(msg.sender, nonce, 1);
    }

    function transferOwnership(address newOwner) public override onlyOwner nonReentrant {
        super.transferOwnership(newOwner);
    }

    function renounceOwnership() public override onlyOwner nonReentrant {
        super.renounceOwnership();
    }

    function authorizationDigest(U.SaleAuthorization calldata authorization)
        external
        view
        override
        returns (bytes32)
    {
        return _authorizationDigest(authorization);
    }

    function _authorizationDigest(U.SaleAuthorization memory authorization)
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

    /// @notice Simulate with eth_call; only temporary guarded proof storage is written.
    function previewExecution(E.Execution calldata e)
        external
        override
        nonReentrant
        returns (S.ERC20SettlementCandidate memory c)
    {
        return StreamERC20BurnMintRuntime.previewExecution(_state, _context(), e);
    }

    /// @dev The immutable gate invokes this selector by STATICCALL while prospective proof is live.
    function previewBurnExecution(E.Execution calldata e)
        external
        view
        override
        returns (S.ERC20SettlementCandidate memory c)
    {
        if (_state.active.mode != 1 && _state.active.mode != 2) {
            revert BurnMintContinuationUnavailable();
        }
        _requireContinuation(e, _state.active.mode);
        c = StreamERC20BurnMintRuntime.previewBurnExecution(_state, _context(), e);
    }

    /// @dev Preserve the original nonpayable empty revert before the reentrancy guard.
    modifier rejectNativeValue() {
        if (msg.value != 0) revert();
        _;
    }

    function executeERC20PreRevenueSingleStep(
        S.ERC20SettlementCandidate calldata supplied,
        bytes calldata data
    )
        external
        payable
        override
        rejectNativeValue
        nonReentrant
        returns (bytes4 magic, S.PrimarySettlementResult memory result)
    {
        E.Execution memory e = abi.decode(data, (E.Execution));
        if (keccak256(data) != keccak256(abi.encode(e))) revert UniversalCandidateMismatch();
        U.SaleAuthorization memory a = e.sale.authorization;
        if (_state.authorizationUsed[a.artist][a.nonce]) {
            revert UniversalAuthorizationUsed(a.artist, a.nonce);
        }
        if (_state.executionIdByNonce[a.saleId][a.executionNonce] != 0) {
            revert UniversalExecutionUsed(a.saleId, a.executionNonce);
        }
        if (
            msg.sender != _state.sales[a.saleId].config.paymentAdapter
                || supplied.executionBinding.executionId == 0
        ) {
            revert UniversalCandidateMismatch();
        }
        // Original sale replay is reserved before any linked/outbound signature, burn or provider call.
        _state.authorizationUsed[a.artist][a.nonce] = true;
        _state.executionIdByNonce[a.saleId][a.executionNonce] =
        supplied.executionBinding.executionId;
        _state.executionStatus[supplied.executionBinding.executionId] = 1;
        address gate = _state.saleBurnGate[a.saleId].gate;
        _state.active = StreamERC20BurnMintState.Continuation(
            gate,
            keccak256(data),
            supplied.executionBinding.executionId,
            keccak256(abi.encode(supplied)),
            0,
            1,
            true
        );
        result = StreamERC20BurnMintRuntime.execute(_state, _context(), e);
        return (IStreamERC20SaleExecution.executeERC20PreRevenueSingleStep.selector, result);
    }

    function executeBurnMint(E.Execution calldata e)
        external
        override
        returns (E.Result memory out)
    {
        _requireContinuation(e, 2);
        // Consume the only mutable callback before the first linked/outbound operation.
        _state.active.mode = 3;
        return StreamERC20BurnMintRuntime.finish(_state, _context(), e);
    }

    function _requireContinuation(E.Execution calldata e, uint8 mode) private view {
        if (
            _state.active.mode != mode || msg.sender != _state.active.gate
                || msg.sender == address(0)
                || _state.active.executionHash != keccak256(abi.encode(e))
        ) revert BurnMintContinuationUnavailable();
    }

    function nextSaleNonce() external view returns (uint256) {
        return _state.nextSaleNonce;
    }

    function paused() external view returns (bool) {
        return _state.paused;
    }

    function authorizationUsed(address artist, bytes32 nonce) external view returns (bool) {
        return _state.authorizationUsed[artist][nonce];
    }

    function executionIdByNonce(bytes32 id, uint256 nonce) external view returns (bytes32) {
        return _state.executionIdByNonce[id][nonce];
    }

    function executionStatus(bytes32 id) external view returns (uint8) {
        return _state.executionStatus[id];
    }

    function saleBurnGate(bytes32 id)
        external
        view
        returns (address gate, bytes32 codeHash, bytes32 configHash)
    {
        StreamERC20BurnMintSupport.GateBinding storage pin = _state.saleBurnGate[id];
        return (pin.gate, pin.codeHash, pin.configHash);
    }

    function _context() private view returns (StreamERC20BurnMintRuntime.Context memory x) {
        x.mintManager = mintManager;
        x.revenueResolver = revenueResolver;
        x.splitFactory = splitFactory;
        x.artistRegistry = artistRegistry;
        x.assetPolicyRegistry = assetPolicyRegistry;
        x.core = core;
        x.moduleRegistry = moduleRegistry;
        x.primarySaleSettlement = primarySaleSettlement;
        x.platformSigner = platformSigner;
        x.artistRegistryCodeHash = artistRegistryCodeHash;
        x.mintManagerCodeHash = mintManagerCodeHash;
        x.settlementCodeHash = settlementCodeHash;
        x.coreCodeHash = coreCodeHash;
        x.moduleRegistryCodeHash = moduleRegistryCodeHash;
        x.resolverCodeHash = resolverCodeHash;
        x.factoryCodeHash = factoryCodeHash;
        x.assetRegistryCodeHash = assetRegistryCodeHash;
    }
}
