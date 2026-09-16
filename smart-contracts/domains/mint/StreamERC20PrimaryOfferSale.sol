// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamERC20PrimaryOfferRuntime.sol";
import "./StreamERC20PrimaryOfferReadEncoding.sol";
import "./StreamERC20PrimaryOfferRevocation.sol";
import "./StreamERC20PrimaryOfferDelegation.sol";
import "./StreamNativeCuratedSaleSupport.sol";
import "./StreamImmediateSaleReveal.sol";
import "../revenue/StreamSettlementContext.sol";
import "../parameters/StreamGasParameterHost.sol";
import "../../interfaces/stream/mint/IStreamERC20PrimaryOfferSale.sol";
import "../../interfaces/stream/mint/IStreamMintReads.sol";
import "../../interfaces/stream/artist/IStreamArtistSaleFacts.sol";
import "../../interfaces/stream/governance/IStreamRoleRegistry.sol";
import "../../vendor/openzeppelin/Ownable.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../../vendor/openzeppelin/ERC165.sol";

/// @notice Atomic ERC20 primary OFFER_SALE through contract20's original nonpayable payer boundary.
/// @dev Full buyer offers do not authorize token pulls. Nonpayer executors supply the buyer's own
/// PaymentIntent to contract20. This profile accepts only a zero declared native reveal fee.
contract StreamERC20PrimaryOfferSale is
    IStreamERC20PrimaryOfferSale,
    IStreamERC20SaleExecution,
    IStreamSaleLifecycleBinding,
    IStreamERC20OfferSale,
    IStreamArtistSaleFacts,
    StreamSettlementContext,
    StreamGasParameterHost,
    StreamERC20PrimaryOfferDelegation,
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
        IStreamNativeRefundDelegatedClaims.DelegationDeployment delegation;
    }

    bytes32 private constant SIGNATURE_GAS = keccak256("6529STREAM_GGP_SALE_ERC1271_GAS_LIMIT");
    bytes32 private constant ARTIST_GAS =
        keccak256("6529STREAM_GGP_SALE_ARTIST_AUTHORITY_GAS_LIMIT");
    bytes32 private constant REVEAL_GAS = keccak256("6529STREAM_GGP_REVEAL_ATTEMPT_GAS_LIMIT");
    IStreamMintManager public immutable mintManager;
    IStreamPrimarySaleSettlement public immutable primarySaleSettlement;
    IStreamArtistAttribution public immutable artistRegistry;
    IStreamRoleRegistry public immutable roleRegistry;
    bytes32 public immutable mintManagerCodeHash;
    bytes32 public immutable settlementCodeHash;
    bytes32 public immutable artistRegistryCodeHash;
    bytes32 public immutable roleRegistryCodeHash;
    StreamERC20PrimaryOfferState.State private _state;
    mapping(bytes32 => bool) public override digestConsumed;
    mapping(bytes32 => bool) public override digestRevoked;

    error InvalidERC20PrimaryOfferDeployment();
    error InvalidERC20PrimaryOffer();
    error ERC20PrimaryOfferDigestConsumed(bytes32 digest);
    error ERC20PrimaryOfferNativeFeeUnsupported(uint256 requiredWei);
    event PrimaryOfferConfigured(
        bytes32 indexed saleId,
        bytes32 indexed configHash,
        uint256 saleNonce,
        Offer.Configuration configuration
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
    event PrimaryOfferExecution(bytes32 indexed executionId, Offer.ExecutionRecord execution);
    event PrimaryOfferCancelled(bytes32 indexed saleId);
    event PrimaryOfferExpired(bytes32 indexed saleId);
    event AdapterPaused(uint16 schemaVersion, address indexed guardian, bytes32 reasonHash);
    event AdapterUnpaused(uint16 schemaVersion, address indexed unpauser, bytes32 reasonHash);
    event SalePaused(
        uint16 schemaVersion, bytes32 indexed saleId, address indexed guardian, bytes32 reasonHash
    );
    event SaleUnpaused(
        uint16 schemaVersion, bytes32 indexed saleId, address indexed unpauser, bytes32 reasonHash
    );
    event CollectionSaleStopSynced(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        address indexed actor,
        uint8 observedContestState,
        bool stopped
    );

    constructor(DeploymentConfig memory d)
        StreamSettlementContext(d.recorder.revenueResolver(), d.recorder.moduleRegistry())
        StreamGasParameterHost(d.authority)
        StreamERC20PrimaryOfferDelegation(
            d.recorder.core(), d.recorder.moduleRegistry(), d.delegation
        )
    {
        if (
            d.authority == address(0) || d.authority != splitFactory.governanceAuthority()
                || !StreamSettlementAdmission.isContract(address(d.manager))
                || !StreamSettlementAdmission.isContract(address(d.recorder))
                || !StreamSettlementAdmission.isContract(address(d.artists))
                || address(d.roles).code.length == 0 || !d.recorder.isStreamPrimarySaleSettlement()
                || d.recorder.core() != core
                || !IStreamMintReads(address(d.manager)).isStreamMintManager()
                || address(IStreamMintReads(address(d.manager)).core()) != core
                || address(IStreamMintReads(address(d.manager)).moduleRegistry()) != moduleRegistry
                || d.artists.core() != core
                || revenueResolver.artistRegistry() != address(d.artists)
                || _read(address(d.roles), abi.encodeWithSignature("owner()"), gasleft())
                    != uint256(uint160(d.authority))
        ) revert InvalidERC20PrimaryOfferDeployment();
        bytes32[3] memory names = [
            keccak256("SALE_ERC1271_GAS_LIMIT"),
            keccak256("SALE_ARTIST_AUTHORITY_GAS_LIMIT"),
            keccak256("REVEAL_ATTEMPT_GAS_LIMIT")
        ];
        for (uint256 n; n < 3; ++n) {
            if (
                keccak256(bytes(d.parameters[n].name)) != names[n]
                    || d.parameters[n].failureClass != 2
            ) revert InvalidERC20PrimaryOfferDeployment();
            _registerGasParameter(d.parameters[n]);
        }
        if (d.delegation.registry != address(0)) _registerGasParameter(d.delegation.gas);
        mintManager = d.manager;
        primarySaleSettlement = d.recorder;
        artistRegistry = d.artists;
        roleRegistry = d.roles;
        mintManagerCodeHash = address(d.manager).codehash;
        settlementCodeHash = address(d.recorder).codehash;
        artistRegistryCodeHash = address(d.artists).codehash;
        roleRegistryCodeHash = address(d.roles).codehash;
        _state.nextSaleNonce = 1;
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamERC20PrimaryOfferSale).interfaceId
            || id == type(IStreamERC20SaleExecution).interfaceId
            || id == type(IStreamSaleLifecycleBinding).interfaceId
            || id == type(IStreamERC20OfferSale).interfaceId
            || id == type(IStreamArtistSaleFacts).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId || id == type(IERC5267).interfaceId
            || super.supportsInterface(id);
    }

    function streamModuleType() external pure returns (bytes32) {
        return keccak256("FIXED_PRICE_SALE_ADAPTER");
    }

    function streamModuleVersion() external pure returns (bytes32) {
        return keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1");
    }

    function streamModuleInterfaceId() external pure returns (bytes4) {
        return type(IStreamERC20SaleExecution).interfaceId;
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

    function offerDelegationConfiguration()
        public
        view
        override(StreamERC20PrimaryOfferDelegation, IStreamERC20OfferSale)
        returns (IStreamNativeRefundDelegatedClaims.DelegationConfiguration memory)
    {
        return super.offerDelegationConfiguration();
    }

    function nextSaleNonce() external view returns (uint256) {
        return _state.nextSaleNonce;
    }

    function saleIdFor(uint256 collectionId, bytes32 phaseId, uint256 nonce)
        external
        view
        returns (bytes32)
    {
        return StreamERC20PrimaryOfferSupport.saleId(collectionId, phaseId, nonce);
    }

    function nextExecutionNonce(bytes32 id, address buyer) external view returns (uint256) {
        return _state.executionNonces[id][buyer] + 1;
    }

    function saleRecord(bytes32 id) external view returns (Offer.SaleRecord memory) {
        bytes memory out = StreamERC20PrimaryOfferReadEncoding.read(_state, msg.sig, id);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function executionRecord(bytes32 id) external view returns (Offer.ExecutionRecord memory) {
        bytes memory out = StreamERC20PrimaryOfferReadEncoding.read(_state, msg.sig, id);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function paused() external view returns (bool) {
        return _state.paused;
    }

    function salePaused(bytes32 id) external view returns (bool) {
        return _state.salePaused[id];
    }

    function collectionStopped(uint256 collection) external view returns (bool) {
        return _state.collectionStopped[collection];
    }

    function saleLifecycleBinding(bytes32 id)
        external
        view
        override
        returns (StreamPrimarySettlementTypes.SaleLifecycleBinding memory)
    {
        bytes memory out = StreamERC20PrimaryOfferReadEncoding.read(_state, msg.sig, id);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function saleConsentFacts(bytes32 id) external view override returns (uint256, bytes32) {
        if (_state.sales[id].status == 0) revert SaleConsentFactsUnavailable(id);
        return (_state.sales[id].config.collectionId, _state.sales[id].configHash);
    }

    function primaryOfferAuthorizationBinding(bytes32 id)
        external
        view
        override
        returns (uint256, bytes32, address, uint8, bytes32)
    {
        Offer.SaleRecord storage s = _state.sales[id];
        if (s.status == 0) revert InvalidERC20PrimaryOffer();
        return (
            s.config.collectionId,
            s.config.phaseId,
            s.config.signer,
            s.config.signerKind,
            s.configHash
        );
    }

    function primaryOfferConfiguration(bytes32 id)
        external
        view
        override
        returns (Offer.Configuration memory)
    {
        bytes memory out = StreamERC20PrimaryOfferReadEncoding.read(_state, msg.sig, id);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    /// @notice Exact immutable recorder metadata, retained through every terminal sale status.
    function primaryOfferSettlementBinding(bytes32 id)
        external
        view
        override
        returns (uint256, address, bytes32)
    {
        Offer.SaleRecord storage s = _state.sales[id];
        if (s.status == 0) revert InvalidERC20PrimaryOffer();
        return (s.saleNonce, s.config.poster, s.configHash);
    }

    function primaryOfferConfigurationHash(Offer.Configuration calldata c)
        external
        view
        override
        returns (bytes32)
    {
        return StreamERC20PrimaryOfferSupport.configurationHash(c);
    }

    function collectionSigner(uint256 collection, address signer, uint8 kind)
        external
        view
        returns (Offer.CollectionSigner memory)
    {
        return _state.signers[collection][signer][kind];
    }

    function configureCollectionSigner(
        uint256 collection,
        address signer,
        uint8 kind,
        bytes32 evidence,
        bool enabled
    ) external onlyOwner nonReentrant {
        _requireSaleContext();
        if (collection == 0 || signer == address(0) || (kind != 1 && kind != 2) || evidence == 0) {
            revert InvalidERC20PrimaryOffer();
        }
        Offer.CollectionSigner storage s = _state.signers[collection][signer][kind];
        s.evidenceHash = evidence;
        s.revision += 1;
        s.enabled = enabled;
        s.authority = msg.sender;
        emit PrimaryOfferCollectionSigner(
            collection, signer, kind, evidence, s.revision, enabled, msg.sender
        );
    }

    function registerPrimaryOffer(Offer.Configuration calldata c, bytes32[] calldata proof)
        external
        override
        onlyOwner
        nonReentrant
        returns (bytes32 id)
    {
        return StreamERC20PrimaryOfferRuntime.register(_state, _runtime(), c, proof);
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

    function previewExecution(Offer.Acceptance calldata q)
        external
        view
        override
        returns (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c)
    {
        bytes32 digest = authorizationDigest(q.authorization);
        if (digestConsumed[digest]) revert ERC20PrimaryOfferDigestConsumed(digest);
        c = StreamERC20PrimaryOfferRuntime.preview(_state, _runtime(), q);
    }

    function executeERC20PreRevenueSingleStep(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata candidate_,
        bytes calldata data
    )
        external
        override
        nonReentrant
        returns (bytes4 magic, StreamPrimarySettlementTypes.PrimarySettlementResult memory result)
    {
        Offer.Acceptance memory q = abi.decode(data, (Offer.Acceptance));
        if (keccak256(data) != keccak256(abi.encode(q))) revert InvalidERC20PrimaryOffer();
        bytes32 id = q.authorization.saleId;
        bytes32 sellerDigest = StreamPrivateSaleHash.digest(
            block.chainid, address(this), StreamPrivateSaleHash.authorizationBody(q.authorization)
        );
        if (digestConsumed[sellerDigest]) revert ERC20PrimaryOfferDigestConsumed(sellerDigest);
        // This store precedes every linked call, signature read and other outbound interaction.
        digestConsumed[sellerDigest] = true;
        emit SaleAuthorizationConsumed(1, id, sellerDigest, q.sellerProof.authorizer);
        if (msg.sender != _state.sales[id].config.paymentAdapter) {
            revert InvalidERC20PrimaryOffer();
        }
        result = StreamERC20PrimaryOfferRuntime.execute(_state, _runtime(), candidate_, data);
        return (IStreamERC20SaleExecution.executeERC20PreRevenueSingleStep.selector, result);
    }

    function revokeAuthorization(
        StreamPrivateSaleTypes.SaleAuthorization calldata a,
        IStreamPrivateSaleAdapter.Signature calldata proof
    ) external override nonReentrant {
        bytes32 digest = authorizationDigest(a);
        if (digestConsumed[digest]) revert ERC20PrimaryOfferDigestConsumed(digest);
        digestConsumed[digest] = true;
        StreamERC20PrimaryOfferRevocation.validate(
            _state.sales[a.saleId].status != 0,
            address(mintManager),
            _state.sales[a.saleId].config,
            a,
            proof,
            digest,
            gasParameter(SIGNATURE_GAS)
        );
        digestRevoked[digest] = true;
        emit SaleAuthorizationRevoked(1, a.saleId, digest, proof.authorizer);
    }

    function cancelPrimaryOffer(bytes32 id) external onlyOwner nonReentrant {
        if (_state.sales[id].status != 1) revert InvalidERC20PrimaryOffer();
        _state.sales[id].status = 2;
        emit PrimaryOfferCancelled(id);
    }

    function expirePrimaryOffer(bytes32 id) external nonReentrant {
        if (_state.sales[id].status != 1 || block.timestamp <= _state.sales[id].config.endsAt) {
            revert InvalidERC20PrimaryOffer();
        }
        _state.sales[id].status = 3;
        emit PrimaryOfferExpired(id);
    }

    function setPaused(bool value, bytes32 reason) external nonReentrant {
        _pauseRole(value, reason);
        _state.paused = value;
        if (value) emit AdapterPaused(1, msg.sender, reason);
        else emit AdapterUnpaused(1, msg.sender, reason);
    }

    function setSalePaused(bytes32 id, bool value, bytes32 reason) external nonReentrant {
        _pauseRole(value, reason);
        if (_state.sales[id].status == 0) revert InvalidERC20PrimaryOffer();
        _state.salePaused[id] = value;
        if (value) emit SalePaused(1, id, msg.sender, reason);
        else emit SaleUnpaused(1, id, msg.sender, reason);
    }

    function syncCollectionContest(uint256 collection) external nonReentrant {
        StreamNativeCuratedSaleSupport.Context memory x = StreamNativeCuratedSaleSupport.Context(
            core,
            moduleRegistry,
            mintManager,
            revenueResolver,
            artistRegistry,
            artistRegistryCodeHash,
            gasParameter(ARTIST_GAS)
        );
        uint8 contest = StreamNativeCuratedSaleSupport.contestState(x, collection);
        bool stopped = contest == 1 || contest == 3;
        _state.collectionStopped[collection] = stopped;
        emit CollectionSaleStopSynced(1, collection, msg.sender, contest, stopped);
    }

    function transferOwnership(address nextOwner) public override onlyOwner nonReentrant {
        super.transferOwnership(nextOwner);
    }

    function renounceOwnership() public override onlyOwner nonReentrant {
        super.renounceOwnership();
    }

    function _support() private view returns (StreamERC20PrimaryOfferSupport.Context memory) {
        return StreamERC20PrimaryOfferSupport.Context(
            core,
            moduleRegistry,
            mintManager,
            revenueResolver,
            splitFactory,
            artistRegistry,
            artistRegistryCodeHash,
            gasParameter(ARTIST_GAS)
        );
    }

    function _runtime() private view returns (StreamERC20PrimaryOfferRuntime.Context memory x) {
        x.base = _support();
        x.recorder = address(primarySaleSettlement);
        x.assets = address(assetPolicyRegistry);
        x.coreHash = coreCodeHash;
        x.registryHash = moduleRegistryCodeHash;
        x.resolverHash = resolverCodeHash;
        x.factoryHash = factoryCodeHash;
        x.assetsHash = assetRegistryCodeHash;
        x.managerHash = mintManagerCodeHash;
        x.recorderHash = settlementCodeHash;
    }

    function _requireSaleContext() private view {
        _requireContext();
        if (
            address(mintManager).codehash != mintManagerCodeHash
                || address(primarySaleSettlement).codehash != settlementCodeHash
                || address(artistRegistry).codehash != artistRegistryCodeHash
                || revenueResolver.artistRegistry() != address(artistRegistry)
        ) revert InvalidERC20PrimaryOfferDeployment();
    }

    function _pauseRole(bool value, bytes32 reason) private view {
        if (reason == 0) revert InvalidERC20PrimaryOffer();
        StreamRefundWindowSupport.requireRole(
            address(roleRegistry),
            roleRegistryCodeHash,
            governanceAuthority,
            value ? keccak256("ROLE_PAUSE_GUARDIAN") : keccak256("ROLE_UNPAUSE")
        );
    }
}
