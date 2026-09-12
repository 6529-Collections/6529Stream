// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamSaleArtist.sol";
import "./StreamLegacySaleConsent.sol";
import "./StreamSaleFunding.sol";
import "./StreamSaleTemplate.sol";

import "../../interfaces/stream/mint/IStreamERC20FixedPriceSaleAdapter.sol";
import "../../interfaces/stream/mint/IStreamMintReads.sol";
import "../../interfaces/stream/revenue/IStreamRevenueResolver.sol";
import "../../interfaces/stream/revenue/IStreamSplitFactory.sol";
import "../../interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../vendor/openzeppelin/ERC165.sol";
import "../../interfaces/standards/IERC20.sol";
import "../revenue/StreamPaymentIntentVerifier.sol";

/// @notice One creator/platform-authorized ERC-20 purchase funds a verified split and mints atomically.
/// @dev The adapter itself pulls allowances. Relayers require payer-signed intent; direct payers
///      remain bounded by signed, immutable sale terms. This bounded profile/template lane is not
///      the universal official settlement/escrow implementation tracked by issue #694.
contract StreamERC20FixedPriceSaleAdapter is
    IStreamERC20FixedPriceSaleAdapter,
    StreamPaymentIntentVerifier,
    ERC165,
    StreamSaleFunding
{
    bytes32 public constant SALE_AUTHORIZATION_TYPEHASH = keccak256(
        "ERC20SaleAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,bytes32 nonce,uint64 deadline,uint64 signerEpoch)"
    );
    bytes32 public constant STREAM_SALE_V1 = keccak256("6529STREAM_SALE_V1");
    bytes32 public constant PRIMARY_POLICY_DOMAIN = keccak256("6529STREAM_PRIMARY_POLICY_V1");
    bytes32 public constant REVENUE_CLASS = keccak256("PRIMARY_SALE");
    bytes32 private constant CONFIG_DOMAIN =
        keccak256("6529STREAM_CURRENT_ERC20_FIXED_PRICE_CONFIG_V1");
    bytes32 private constant NONCE_DOMAIN = keccak256("6529STREAM_ERC20_SALE_NONCE_V1");

    IStreamMintManager public immutable override mintManager;
    IStreamRevenueResolver public immutable override revenueResolver;
    IStreamSplitFactory public immutable override splitFactory;
    IStreamAssetPolicyRegistry public immutable override assetPolicyRegistry;
    IStreamArtistAttribution public immutable override artistRegistry;
    bytes32 public immutable artistRegistryCodeHash;
    address public override platformSigner;
    uint64 public override signerEpoch = 1;
    uint256 public override nextSaleNonce = 1;
    bool public override paused;
    mapping(bytes32 => SaleRecord) private _sales;
    mapping(address => mapping(bytes32 => bool)) public override authorizationUsed;
    mapping(bytes32 => mapping(address => uint256)) public override proceeds;
    mapping(address => uint256) public override totalProceeds;

    constructor(
        IStreamMintManager manager_,
        IStreamRevenueResolver resolver_,
        address platformSigner_,
        IStreamArtistAttribution artists_,
        IStreamRevenueEscrow escrow_
    ) StreamSaleFunding(IStreamSplitFactory(resolver_.splitFactory()), escrow_) {
        if (
            address(manager_).code.length == 0 || address(resolver_).code.length == 0
                || platformSigner_ == address(0) || !resolver_.isStreamRevenueResolver()
                || !StreamSaleArtist.supportsAttribution(artists_)
                || address(IStreamMintReads(address(manager_)).core()) != artists_.core()
                || resolver_.core() != artists_.core()
                || resolver_.artistRegistry() != address(artists_)
        ) {
            revert InvalidSaleConfiguration();
        }
        IStreamSplitFactory factory_ = IStreamSplitFactory(resolver_.splitFactory());
        if (address(factory_).code.length == 0) revert InvalidSaleConfiguration();
        IStreamAssetPolicyRegistry assets_ = factory_.assetPolicyRegistry();
        if (
            address(assets_).code.length == 0 || !assets_.isStreamAssetPolicyRegistry()
                || assets_.ASSET_STATUS_ACTIVE() != 1
        ) revert InvalidSaleConfiguration();
        mintManager = manager_;
        revenueResolver = resolver_;
        splitFactory = factory_;
        assetPolicyRegistry = assets_;
        artistRegistry = artists_;
        artistRegistryCodeHash = address(artists_).codehash;
        platformSigner = platformSigner_;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC165, IERC165)
        returns (bool)
    {
        return interfaceId == type(IStreamERC20FixedPriceSaleAdapter).interfaceId
            || interfaceId == type(IStreamPaymentIntentVerifier).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /// @notice Rotates the platform signer and invalidates outstanding sale signatures by epoch.
    function setPlatformSigner(address signer) external override onlyOwner nonReentrant {
        if (signer == address(0)) revert InvalidSaleConfiguration();
        platformSigner = signer;
        signerEpoch += 1;
        emit PlatformSignerChanged(signer, signerEpoch);
    }

    /// @notice Stops purchases without preventing payer or artist nonce revocation.
    function setPaused(bool value) external override onlyOwner nonReentrant {
        paused = value;
        emit SalesPauseChanged(value);
    }

    function saleIdFor(uint256 collectionId, bytes32 phaseId, uint256 saleNonce)
        public
        view
        override
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                STREAM_SALE_V1,
                block.chainid,
                address(this),
                uint8(0),
                collectionId,
                phaseId,
                saleNonce
            )
        );
    }

    function registerSale(SaleConfig calldata config)
        external
        override
        onlyOwner
        nonReentrant
        returns (bytes32 saleId)
    {
        if (
            config.collectionId == 0 || config.phaseId == bytes32(0)
                || config.revenueClass != REVENUE_CLASS || config.price == 0
                || config.endsAt <= config.startsAt || config.endsAt < block.timestamp
                || config.mintPolicyHash == bytes32(0)
                || config.expectedPrimaryPolicyHash == bytes32(0)
                || IStreamMintReads(address(mintManager))
                        .phasePolicyHash(config.collectionId, config.phaseId)
                    != config.mintPolicyHash
        ) {
            revert InvalidSaleConfiguration();
        }
        _requireActiveAsset(config.asset);
        (bytes32 policy,,) = primaryPolicy(config.collectionId, config.revenueClass);
        if (policy != config.expectedPrimaryPolicyHash) {
            revert PrimaryPolicyMismatch(config.expectedPrimaryPolicyHash, policy);
        }
        uint256 nonce = nextSaleNonce++;
        saleId = saleIdFor(config.collectionId, config.phaseId, nonce);
        bytes32 configHash = keccak256(abi.encode(CONFIG_DOMAIN, saleId, config));
        _sales[saleId] = SaleRecord(config, nonce, configHash, false);
        emit SaleConfigured(saleId, config.collectionId, config.phaseId, nonce, configHash);
    }

    function saleRecord(bytes32 saleId) external view override returns (SaleRecord memory) {
        return _sales[saleId];
    }

    function cancelSale(bytes32 saleId) external override onlyOwner nonReentrant {
        SaleRecord storage record = _sales[saleId];
        if (record.saleNonce == 0 || record.cancelled) revert SaleUnavailable(saleId);
        record.cancelled = true;
        emit SaleCancelled(saleId);
    }

    function cancelAuthorization(bytes32 nonce) external override nonReentrant {
        if (authorizationUsed[msg.sender][nonce]) revert SaleAuthorizationUsed(msg.sender, nonce);
        authorizationUsed[msg.sender][nonce] = true;
        emit SaleAuthorizationCancelled(msg.sender, nonce);
    }

    function primaryPolicy(uint256 collectionId, bytes32 revenueClass)
        public
        view
        override
        returns (bytes32 policyHash, bytes32 profileId, address wallet)
    {
        StreamSaleTemplate.Selection memory selected = _primarySelection(collectionId, revenueClass);
        return (
            StreamSaleTemplate.policyHash(revenueResolver, collectionId, selected),
            selected.profileId,
            selected.wallet
        );
    }

    function _primarySelection(uint256 collectionId, bytes32 revenueClass)
        private
        view
        returns (StreamSaleTemplate.Selection memory selected)
    {
        if (revenueClass != REVENUE_CLASS) revert UnsupportedPrimaryAssignment();
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory assignment =
            revenueResolver.resolvePrimaryAssignment(collectionId, 0, revenueClass);
        if (assignment.assignmentType == 2) {
            return StreamSaleTemplate.preview(revenueResolver, collectionId, assignment);
        }
        if (
            !assignment.exists || assignment.assignmentType != 1 || assignment.scope != 1
                || assignment.scopeId != collectionId || assignment.templateId != bytes32(0)
                || assignment.profileId == bytes32(0) || assignment.assignmentHash == bytes32(0)
        ) {
            revert UnsupportedPrimaryAssignment();
        }
        selected.profileId = assignment.profileId;
        if (!splitFactory.splitWalletExists(selected.profileId)) {
            revert UnsupportedPrimaryAssignment();
        }
        selected.wallet = splitFactory.walletFor(selected.profileId);
        selected.assignmentHash = assignment.assignmentHash;
        _requireFundingWallet(selected.profileId, selected.wallet);
    }

    function authorizationId(address artist, bytes32 nonce) public view override returns (bytes32) {
        return keccak256(abi.encode(NONCE_DOMAIN, block.chainid, address(this), artist, nonce));
    }

    function authorizationDigest(SaleAuthorization calldata authorization)
        public
        view
        override
        returns (bytes32)
    {
        return _typedDigest(keccak256(abi.encode(SALE_AUTHORIZATION_TYPEHASH, authorization)));
    }

    struct Execution {
        SaleConfig config;
        bytes32 digest;
        bytes32 authorizationId;
        bytes32 profileId;
        address wallet;
        bytes32 operationRoot;
        bytes32 operationId;
        bool escrowed;
        StreamSaleTemplate.Selection selected;
    }

    function buy(
        SaleAuthorization calldata authorization,
        bytes calldata tokenData,
        bytes calldata platformSignature,
        bytes calldata artistSignature,
        PaymentIntent calldata intent,
        bytes calldata payerSignature
    ) external override nonReentrant returns (uint256 tokenId, bytes32 operationRoot) {
        Execution memory execution =
            _validate(authorization, tokenData, platformSignature, artistSignature);
        return _executePurchase(authorization, tokenData, intent, payerSignature, execution);
    }

    function _executePurchase(
        SaleAuthorization calldata authorization,
        bytes calldata tokenData,
        PaymentIntent calldata intent,
        bytes calldata payerSignature,
        Execution memory execution
    ) private returns (uint256 tokenId, bytes32 operationRoot) {
        IStreamMintManager.MintBatch memory batch = _mintBatch(authorization, tokenData, execution);
        bytes32[] memory expectedIds;
        (execution.operationRoot, expectedIds) =
            IStreamMintReads(address(mintManager)).previewSingleStepMintOperation(batch, "");
        if (
            execution.operationRoot == bytes32(0) || expectedIds.length != 1
                || expectedIds[0] == bytes32(0)
        ) {
            revert SaleMintResultInvalid();
        }
        execution.operationId = expectedIds[0];
        _authorizePayment(
            PaymentTerms(
                authorization.payer,
                execution.config.asset,
                execution.config.price,
                authorization.saleId,
                execution.config.expectedPrimaryPolicyHash
            ),
            intent,
            payerSignature
        );
        StreamSaleTemplate.materialize(
            revenueResolver, execution.config.collectionId, execution.selected
        );
        authorizationUsed[authorization.artist][authorization.nonce] = true;
        proceeds[execution.profileId][execution.config.asset] += execution.config.price;
        totalProceeds[execution.config.asset] += execution.config.price;
        execution.escrowed = _pay(authorization.payer, execution);
        StreamLegacySaleConsent.requireNone(
            artistRegistry,
            artistRegistryCodeHash,
            execution.config.collectionId,
            authorization.artist
        );
        uint256[] memory tokenIds;
        bytes32[] memory operationIds;
        (tokenIds, operationRoot, operationIds) = mintManager.executeSingleStepMint(batch, "");
        if (
            tokenIds.length != 1 || tokenIds[0] == 0 || operationRoot != execution.operationRoot
                || operationIds.length != 1 || operationIds[0] != execution.operationId
        ) revert SaleMintResultInvalid();
        tokenId = tokenIds[0];
        StreamLegacySaleConsent.requireNone(
            artistRegistry,
            artistRegistryCodeHash,
            execution.config.collectionId,
            authorization.artist
        );
        _emitSale(authorization, execution, tokenId);
        emit SaleRevenueFunded(
            1,
            execution.authorizationId,
            operationRoot,
            execution.profileId,
            execution.wallet,
            execution.config.asset,
            execution.config.price,
            execution.escrowed
        );
    }

    function _validate(
        SaleAuthorization calldata authorization,
        bytes calldata tokenData,
        bytes calldata platformSignature,
        bytes calldata artistSignature
    ) private view returns (Execution memory e) {
        SaleRecord storage record = _sales[authorization.saleId];
        if (
            paused || record.saleNonce == 0 || record.cancelled
                || block.timestamp < record.config.startsAt
                || block.timestamp > record.config.endsAt
        ) revert SaleUnavailable(authorization.saleId);
        if (
            authorization.saleConfigHash != record.configHash || authorization.payer == address(0)
                || authorization.payer == address(this) || authorization.recipient == address(0)
                || authorization.artist == address(0) || authorization.mintCommitment == bytes32(0)
                || authorization.signerEpoch != signerEpoch
                || block.timestamp > authorization.deadline
                || keccak256(tokenData) != authorization.tokenDataHash
        ) revert InvalidSaleAuthorization();
        if (authorizationUsed[authorization.artist][authorization.nonce]) {
            revert SaleAuthorizationUsed(authorization.artist, authorization.nonce);
        }
        e.config = record.config;
        StreamLegacySaleConsent.requireNone(
            artistRegistry, artistRegistryCodeHash, e.config.collectionId, authorization.artist
        );
        e.digest = authorizationDigest(authorization);
        if (!_validSignature(platformSigner, e.digest, platformSignature)) {
            revert InvalidSaleSignature(platformSigner);
        }
        if (!_validSignature(authorization.artist, e.digest, artistSignature)) {
            revert InvalidSaleSignature(authorization.artist);
        }
        _requireActiveAsset(e.config.asset);
        e.selected = _primarySelection(e.config.collectionId, e.config.revenueClass);
        e.profileId = e.selected.profileId;
        e.wallet = e.selected.wallet;
        bytes32 policy =
            StreamSaleTemplate.policyHash(revenueResolver, e.config.collectionId, e.selected);
        if (policy != e.config.expectedPrimaryPolicyHash) {
            revert PrimaryPolicyMismatch(e.config.expectedPrimaryPolicyHash, policy);
        }
        if (authorization.payer == e.wallet) revert InvalidSaleAuthorization();
        e.authorizationId = authorizationId(authorization.artist, authorization.nonce);
    }

    function _mintBatch(SaleAuthorization calldata a, bytes calldata data, Execution memory e)
        private
        pure
        returns (IStreamMintManager.MintBatch memory batch)
    {
        batch.collectionId = e.config.collectionId;
        batch.phaseId = e.config.phaseId;
        batch.payer = a.payer;
        batch.initialRecipients = new address[](1);
        batch.beneficiaries = new address[](1);
        batch.tokenData = new bytes[](1);
        batch.mintCommitments = new bytes32[](1);
        batch.initialRecipients[0] = a.recipient;
        batch.beneficiaries[0] = a.recipient;
        batch.tokenData[0] = data;
        batch.mintCommitments[0] = a.mintCommitment;
        batch.expectedPolicyHash = e.config.mintPolicyHash;
        batch.authorizationId = e.authorizationId;
        batch.contextHash = e.digest;
    }

    function _emitSale(SaleAuthorization calldata a, Execution memory e, uint256 tokenId) private {
        emit ERC20SaleSettled(
            a.saleId,
            e.operationRoot,
            tokenId,
            e.authorizationId,
            e.digest,
            e.profileId,
            e.wallet,
            e.config.asset,
            e.config.price
        );
        emit ERC20SaleParticipants(
            e.authorizationId, a.artist, a.payer, a.recipient, e.config.expectedPrimaryPolicyHash
        );
    }

    function _pay(address payer, Execution memory e) private returns (bool escrowed) {
        escrowed = _fundERC20(
            payer,
            e.config.revenueClass,
            e.profileId,
            e.wallet,
            e.config.asset,
            e.config.price,
            e.selected.templateId != bytes32(0)
        );
        _requireActiveAsset(e.config.asset);
        if (e.selected.templateId != bytes32(0)) {
            StreamSaleTemplate.requireCurrent(revenueResolver, e.config.collectionId, e.selected);
        } else {
            (bytes32 policy,,) = primaryPolicy(e.config.collectionId, e.config.revenueClass);
            if (policy != e.config.expectedPrimaryPolicyHash) {
                revert PrimaryPolicyMismatch(e.config.expectedPrimaryPolicyHash, policy);
            }
        }
    }

    function _requireActiveAsset(address asset) private view {
        _requireFundingAsset(asset);
    }
}
