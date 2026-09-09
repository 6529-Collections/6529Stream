// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/IStreamFixedPriceSaleAdapter.sol";
import "../../interfaces/stream/IStreamMintManager.sol";
import "../../interfaces/stream/IStreamSplitFactory.sol";
import "../../vendor/openzeppelin/ERC165.sol";
import "../../vendor/openzeppelin/Ownable.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "./StreamSaleSignatures.sol";

/// @notice One signed native sale mints one NFT and funds its immutable split wallet atomically.
/// @dev Both creator and platform approve the complete sale. The wallet is funded before
///      Core invokes a recipient callback. Any later failure rolls back payment and replay state.
contract StreamFixedPriceSaleAdapter is
    IStreamFixedPriceSaleAdapter,
    ERC165,
    Ownable,
    ReentrancyGuard
{
    bytes32 public constant SALE_AUTHORIZATION_TYPEHASH = keccak256(
        "SaleAuthorization(uint256 collectionId,bytes32 phaseId,address payer,address recipient,address artist,bytes32 profileId,bytes32 tokenDataHash,bytes32 mintCommitment,bytes32 mintPolicyHash,uint256 price,bytes32 nonce,uint64 deadline,uint64 signerEpoch)"
    );
    bytes32 private constant DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 private constant NONCE_DOMAIN = keccak256("6529STREAM_NATIVE_SALE_NONCE_V1");
    bytes32 private constant NAME_HASH = keccak256("6529StreamFixedPriceSale");
    bytes32 private constant VERSION_HASH = keccak256("1");

    IStreamMintManager public immutable mintManager;
    IStreamSplitFactory public immutable splitFactory;
    address public platformSigner;
    uint64 public signerEpoch = 1;
    bool public paused;
    mapping(address => mapping(bytes32 => bool)) public override authorizationUsed;
    mapping(bytes32 => uint256) public nativeProceeds;
    uint256 public totalNativeProceeds;

    constructor(
        IStreamMintManager mintManager_,
        IStreamSplitFactory splitFactory_,
        address platformSigner_
    ) {
        if (
            address(mintManager_).code.length == 0 || address(splitFactory_).code.length == 0
                || platformSigner_ == address(0)
        ) revert InvalidSaleConfiguration();
        mintManager = mintManager_;
        splitFactory = splitFactory_;
        platformSigner = platformSigner_;
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
            "1",
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

    function buy(
        SaleAuthorization calldata sale,
        bytes calldata tokenData,
        bytes calldata platformSignature,
        bytes calldata artistSignature
    ) external payable override nonReentrant returns (uint256 tokenId, bytes32 operationRoot) {
        if (paused) revert SalesPaused();
        _validateSale(sale, tokenData);
        bytes32 digest = authorizationDigest(sale);
        _requireSignature(platformSigner, digest, platformSignature);
        _requireSignature(sale.artist, digest, artistSignature);
        address wallet = splitFactory.walletFor(sale.profileId);
        if (!splitFactory.splitWalletExists(sale.profileId)) {
            revert InvalidSplitProfile(sale.profileId);
        }

        bytes32 id = authorizationId(sale.artist, sale.nonce);
        IStreamMintManager.MintBatch memory batch = _mintBatch(sale, tokenData, digest, id);
        authorizationUsed[sale.artist][sale.nonce] = true;
        nativeProceeds[sale.profileId] += msg.value;
        totalNativeProceeds += msg.value;
        if (msg.value != 0) {
            (bool deposited,) = payable(wallet).call{ value: msg.value }("");
            if (!deposited) revert SaleDepositFailed(wallet);
        }
        uint256[] memory tokenIds;
        bytes32[] memory operationIds;
        (tokenIds, operationRoot, operationIds) = mintManager.executeSingleStepMint(batch, "");
        if (
            tokenIds.length != 1 || tokenIds[0] == 0 || operationRoot == bytes32(0)
                || operationIds.length != 1 || operationIds[0] == bytes32(0)
        ) revert SaleMintResultInvalid();
        tokenId = tokenIds[0];
        _emitSale(sale, id, digest, tokenId, operationRoot, wallet);
    }

    function _validateSale(SaleAuthorization calldata sale, bytes calldata tokenData) private view {
        if (
            sale.collectionId == 0 || sale.phaseId == bytes32(0) || sale.payer != msg.sender
                || sale.recipient == address(0) || sale.artist == address(0)
                || sale.profileId == bytes32(0) || sale.nonce == bytes32(0)
                || sale.mintPolicyHash == bytes32(0) || sale.mintCommitment == bytes32(0)
                || sale.signerEpoch != signerEpoch || keccak256(tokenData) != sale.tokenDataHash
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
