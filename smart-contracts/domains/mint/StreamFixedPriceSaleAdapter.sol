// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamSaleArtist.sol";
import "./StreamLegacySaleConsent.sol";
import "./StreamSaleFunding.sol";
import "./StreamSaleTemplate.sol";
import "../../interfaces/stream/mint/IStreamMintReads.sol";

import "../../interfaces/stream/mint/IStreamFixedPriceSaleAdapter.sol";
import "../../interfaces/stream/mint/IStreamMintManager.sol";
import "../../interfaces/stream/revenue/IStreamSplitFactory.sol";
import "../../interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../vendor/openzeppelin/ERC165.sol";
import "../../vendor/openzeppelin/Ownable.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "./StreamSaleSignatures.sol";

/// @notice One signed native sale mints one NFT and funds its immutable split wallet atomically.
/// @dev Both creator and platform approve the complete V2 sale and current primary policy.
///      Before the mint callback, revenue is either in the verified wallet or exactly owed in
///      escrow. Any later failure rolls back funding, replay state and the mint.
contract StreamFixedPriceSaleAdapter is
    IStreamFixedPriceSaleAdapter,
    ERC165,
    Ownable,
    ReentrancyGuard,
    StreamSaleFunding
{
    bytes32 public constant SALE_AUTHORIZATION_TYPEHASH = keccak256(
        "SaleAuthorization(uint256 collectionId,bytes32 phaseId,address payer,address recipient,address artist,bytes32 profileId,bytes32 expectedPrimaryPolicyHash,bytes32 tokenDataHash,bytes32 mintCommitment,bytes32 mintPolicyHash,uint256 price,bytes32 nonce,uint64 deadline,uint64 signerEpoch)"
    );
    bytes32 private constant DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 private constant NONCE_DOMAIN = keccak256("6529STREAM_NATIVE_SALE_NONCE_V1");
    bytes32 private constant NAME_HASH = keccak256("6529StreamFixedPriceSale");
    bytes32 private constant VERSION_HASH = keccak256("2");
    bytes32 public constant REVENUE_CLASS = keccak256("PRIMARY_SALE");
    bytes32 public constant PRIMARY_POLICY_DOMAIN = keccak256("6529STREAM_PRIMARY_POLICY_V1");

    IStreamMintManager public immutable mintManager;
    IStreamSplitFactory public immutable splitFactory;
    IStreamRevenueResolver public immutable override revenueResolver;
    IStreamArtistAttribution public immutable artistRegistry;
    bytes32 public immutable artistRegistryCodeHash;
    address public platformSigner;
    uint64 public signerEpoch = 1;
    bool public paused;
    mapping(address => mapping(bytes32 => bool)) public override authorizationUsed;
    mapping(bytes32 => uint256) public nativeProceeds;
    uint256 public totalNativeProceeds;

    constructor(
        IStreamMintManager mintManager_,
        IStreamRevenueResolver resolver_,
        address platformSigner_,
        IStreamArtistAttribution artistRegistry_,
        IStreamRevenueEscrow escrow_
    ) StreamSaleFunding(IStreamSplitFactory(resolver_.splitFactory()), escrow_) {
        IStreamSplitFactory splitFactory_ = IStreamSplitFactory(resolver_.splitFactory());
        if (
            address(mintManager_).code.length == 0 || address(splitFactory_).code.length == 0
                || platformSigner_ == address(0) || !resolver_.isStreamRevenueResolver()
        ) revert InvalidSaleConfiguration();
        if (!StreamSaleArtist.supportsAttribution(artistRegistry_)) {
            revert InvalidSaleConfiguration();
        }
        (bool bound, bytes memory coreData) =
            address(mintManager_).staticcall(abi.encodeWithSignature("core()"));
        if (
            !bound || coreData.length != 32
                || abi.decode(coreData, (address)) != artistRegistry_.core()
                || resolver_.core() != artistRegistry_.core()
                || resolver_.artistRegistry() != address(artistRegistry_)
        ) {
            revert InvalidSaleConfiguration();
        }
        mintManager = mintManager_;
        splitFactory = splitFactory_;
        revenueResolver = resolver_;
        platformSigner = platformSigner_;
        artistRegistry = artistRegistry_;
        artistRegistryCodeHash = address(artistRegistry_).codehash;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC165, IERC165)
        returns (bool)
    {
        return interfaceId == type(IStreamFixedPriceSaleAdapter).interfaceId
            || super.supportsInterface(interfaceId);
    }

    function setPlatformSigner(address signer) external onlyOwner nonReentrant {
        if (signer == address(0)) revert InvalidSaleConfiguration();
        platformSigner = signer;
        signerEpoch += 1;
        emit SalePlatformSignerChanged(signer, signerEpoch);
    }

    function setPaused(bool paused_) external onlyOwner nonReentrant {
        paused = paused_;
        emit SalesPauseChanged(paused_);
    }

    /// @notice An artist can invalidate an outstanding nonce without disclosing the authorization.
    function cancelAuthorization(bytes32 nonce) external override nonReentrant {
        if (nonce == bytes32(0)) revert InvalidSaleAuthorization();
        if (authorizationUsed[msg.sender][nonce]) revert SaleAlreadyConsumed(msg.sender, nonce);
        authorizationUsed[msg.sender][nonce] = true;
        emit SaleAuthorizationCancelled(msg.sender, nonce);
    }

    function authorizationId(address artist, bytes32 nonce) public view override returns (bytes32) {
        return keccak256(abi.encode(NONCE_DOMAIN, block.chainid, address(this), artist, nonce));
    }

    function domainSeparator() public view returns (bytes32) {
        return keccak256(
            abi.encode(DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, block.chainid, address(this))
        );
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
            "6529StreamFixedPriceSale",
            "2",
            block.chainid,
            address(this),
            bytes32(0),
            new uint256[](0)
        );
    }

    function authorizationDigest(SaleAuthorization calldata sale)
        public
        view
        override
        returns (bytes32)
    {
        bytes32 structHash = keccak256(abi.encode(SALE_AUTHORIZATION_TYPEHASH, sale));
        return keccak256(abi.encodePacked(hex"1901", domainSeparator(), structHash));
    }

    struct Execution {
        bytes32 id;
        bytes32 digest;
        address wallet;
        bytes32 previewRoot;
        bytes32 operationId;
        bool escrowed;
        StreamSaleTemplate.Selection selected;
    }

    function primaryPolicy(uint256 collectionId)
        public
        view
        override
        returns (bytes32 policyHash, bytes32 profileId, address wallet)
    {
        StreamSaleTemplate.Selection memory selected = _primarySelection(collectionId);
        return (
            StreamSaleTemplate.policyHash(revenueResolver, collectionId, selected),
            selected.profileId,
            selected.wallet
        );
    }

    function _primarySelection(uint256 collectionId)
        private
        view
        returns (StreamSaleTemplate.Selection memory selected)
    {
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a =
            revenueResolver.resolvePrimaryAssignment(collectionId, 0, REVENUE_CLASS);
        if (a.assignmentType == 2) {
            return StreamSaleTemplate.preview(revenueResolver, collectionId, a);
        }
        if (
            !a.exists || a.assignmentType != 1 || a.scope != 1 || a.scopeId != collectionId
                || a.templateId != bytes32(0) || a.profileId == bytes32(0)
                || a.assignmentHash == bytes32(0)
        ) {
            revert NativePrimaryAssignmentUnsupported();
        }
        selected.profileId = a.profileId;
        selected.wallet = splitFactory.walletFor(a.profileId);
        selected.assignmentHash = a.assignmentHash;
        _requireFundingWallet(selected.profileId, selected.wallet);
    }

    function _requirePrimaryPolicy(SaleAuthorization calldata sale)
        private
        view
        returns (StreamSaleTemplate.Selection memory selected)
    {
        selected = _primarySelection(sale.collectionId);
        if (selected.profileId != sale.profileId) revert InvalidSplitProfile(sale.profileId);
        bytes32 policy = StreamSaleTemplate.policyHash(revenueResolver, sale.collectionId, selected);
        if (policy != sale.expectedPrimaryPolicyHash) {
            revert NativePrimaryPolicyMismatch(sale.expectedPrimaryPolicyHash, policy);
        }
    }

    function buy(
        SaleAuthorization calldata sale,
        bytes calldata tokenData,
        bytes calldata platformSignature,
        bytes calldata artistSignature
    ) external payable override nonReentrant returns (uint256 tokenId, bytes32 operationRoot) {
        if (paused) revert SalesPaused();
        _validateSale(sale, tokenData);
        StreamLegacySaleConsent.requireNone(
            artistRegistry, artistRegistryCodeHash, sale.collectionId, sale.artist
        );
        Execution memory e;
        e.digest = authorizationDigest(sale);
        _requireSignature(platformSigner, e.digest, platformSignature);
        _requireSignature(sale.artist, e.digest, artistSignature);
        e.selected = _requirePrimaryPolicy(sale);
        e.wallet = e.selected.wallet;
        e.id = authorizationId(sale.artist, sale.nonce);
        IStreamMintManager.MintBatch memory batch = _mintBatch(sale, tokenData, e.digest, e.id);
        bytes32[] memory ids;
        (e.previewRoot, ids) =
            IStreamMintReads(address(mintManager)).previewSingleStepMintOperation(batch, "");
        if (e.previewRoot == bytes32(0) || ids.length != 1 || ids[0] == bytes32(0)) {
            revert SaleMintResultInvalid();
        }
        e.operationId = ids[0];
        return _executeSale(sale, batch, e);
    }

    function _executeSale(
        SaleAuthorization calldata sale,
        IStreamMintManager.MintBatch memory batch,
        Execution memory e
    ) private returns (uint256 tokenId, bytes32 operationRoot) {
        StreamSaleTemplate.materialize(revenueResolver, sale.collectionId, e.selected);
        authorizationUsed[sale.artist][sale.nonce] = true;
        nativeProceeds[sale.profileId] += msg.value;
        totalNativeProceeds += msg.value;
        e.escrowed = _fundNative(
            REVENUE_CLASS, sale.profileId, e.wallet, msg.value, e.selected.templateId != bytes32(0)
        );
        if (e.selected.templateId == bytes32(0)) _requirePrimaryPolicy(sale);
        else StreamSaleTemplate.requireCurrent(revenueResolver, sale.collectionId, e.selected);
        StreamLegacySaleConsent.requireNone(
            artistRegistry, artistRegistryCodeHash, sale.collectionId, sale.artist
        );
        uint256[] memory tokenIds;
        bytes32[] memory operationIds;
        (tokenIds, operationRoot, operationIds) = mintManager.executeSingleStepMint(batch, "");
        if (
            tokenIds.length != 1 || tokenIds[0] == 0 || operationRoot != e.previewRoot
                || operationIds.length != 1 || operationIds[0] != e.operationId
        ) revert SaleMintResultInvalid();
        tokenId = tokenIds[0];
        StreamLegacySaleConsent.requireNone(
            artistRegistry, artistRegistryCodeHash, sale.collectionId, sale.artist
        );
        _emitSale(sale, e.id, e.digest, tokenId, operationRoot, e.wallet);
        emit SaleRevenueFunded(
            1, e.id, operationRoot, sale.profileId, e.wallet, address(0), msg.value, e.escrowed
        );
    }

    function _validateSale(SaleAuthorization calldata sale, bytes calldata tokenData) private view {
        if (
            sale.collectionId == 0 || sale.phaseId == bytes32(0) || sale.payer != msg.sender
                || sale.recipient == address(0) || sale.artist == address(0)
                || sale.profileId == bytes32(0) || sale.expectedPrimaryPolicyHash == bytes32(0)
                || sale.nonce == bytes32(0) || sale.mintPolicyHash == bytes32(0)
                || sale.mintCommitment == bytes32(0) || sale.signerEpoch != signerEpoch
                || keccak256(tokenData) != sale.tokenDataHash
        ) revert InvalidSaleAuthorization();
        if (block.timestamp > sale.deadline) revert SaleExpired(sale.deadline);
        if (msg.value != sale.price) revert IncorrectSaleValue(sale.price, msg.value);
        if (authorizationUsed[sale.artist][sale.nonce]) {
            revert SaleAlreadyConsumed(sale.artist, sale.nonce);
        }
    }

    function _mintBatch(
        SaleAuthorization calldata sale,
        bytes calldata tokenData,
        bytes32 digest,
        bytes32 id
    ) private pure returns (IStreamMintManager.MintBatch memory batch) {
        batch.collectionId = sale.collectionId;
        batch.phaseId = sale.phaseId;
        batch.payer = sale.payer;
        batch.initialRecipients = new address[](1);
        batch.beneficiaries = new address[](1);
        batch.tokenData = new bytes[](1);
        batch.mintCommitments = new bytes32[](1);
        batch.initialRecipients[0] = sale.recipient;
        batch.beneficiaries[0] = sale.recipient;
        batch.tokenData[0] = tokenData;
        batch.mintCommitments[0] = sale.mintCommitment;
        batch.expectedPolicyHash = sale.mintPolicyHash;
        batch.authorizationId = id;
        batch.contextHash = digest;
    }

    function _emitSale(
        SaleAuthorization calldata sale,
        bytes32 id,
        bytes32 digest,
        uint256 tokenId,
        bytes32 operationRoot,
        address wallet
    ) private {
        emit NativeSaleSettled(
            id, operationRoot, tokenId, digest, sale.profileId, wallet, sale.price
        );
        emit SaleParticipants(id, sale.collectionId, sale.artist, sale.payer, sale.recipient);
    }

    function _requireSignature(address signer, bytes32 digest, bytes calldata signature)
        private
        view
    {
        if (!StreamSaleSignatures.isValid(signer, digest, signature)) {
            revert InvalidSaleSignature(signer);
        }
    }
}
