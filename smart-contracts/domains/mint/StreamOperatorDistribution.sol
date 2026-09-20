// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/mint/IStreamOperatorDistribution.sol";
import "../../interfaces/stream/mint/IStreamMintRoyaltyPolicy.sol";
import "../../interfaces/stream/mint/IStreamMintCounterReads.sol";
import "../../interfaces/stream/mint/IStreamMintReads.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../vendor/openzeppelin/ERC165.sol";
import "../../vendor/openzeppelin/IERC721.sol";
import "../../vendor/openzeppelin/IERC721Receiver.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../parameters/StreamGasParameterHost.sol";
import "../auctions/StreamNativeAuctionDelegation.sol";
import "./StreamImmediateSaleReveal.sol";

/// @notice Committed free Manager batches with beneficiary accounting and isolated NFT delivery.
/// @dev No sale, settlement or buyer escrow exists. Phase policy remains the sole mint authority.
contract StreamOperatorDistribution is
    IStreamOperatorDistribution,
    ERC165,
    IERC721Receiver,
    ReentrancyGuard,
    StreamGasParameterHost
{
    bytes32 public constant PROGRAM_DOMAIN =
        keccak256("6529STREAM_OPERATOR_DISTRIBUTION_CONFIG_V1");
    bytes32 public constant SLICE_DOMAIN = keccak256("6529STREAM_OPERATOR_DISTRIBUTION_SLICE_V1");
    bytes32 public constant AUTHORIZATION_DOMAIN =
        keccak256("6529STREAM_OPERATOR_DISTRIBUTION_AUTHORIZATION_V1");
    bytes32 public constant MODULE_TYPE = keccak256("OPERATOR_DISTRIBUTION");
    bytes32 public constant NFT_GAS = keccak256("6529STREAM_GGP_SALE_NFT_DELIVERY_GAS_LIMIT");
    bytes32 public constant REVEAL_GAS = keccak256("6529STREAM_GGP_REVEAL_ATTEMPT_GAS_LIMIT");
    bytes32 public constant DELEGATE_GAS = keccak256("6529STREAM_GGP_DELEGATE_REGISTRY_GAS_LIMIT");
    uint256 public constant MAX_PROOF_DEPTH = 32;

    struct DeploymentConfig {
        address core;
        address manager;
        address moduleRegistry;
        address governanceAuthority;
        address delegateRegistry;
        uint256 delegationUsecase;
        bytes32 baseManifestHash;
    }

    address public immutable core;
    IStreamMintManager public immutable manager;
    address public immutable moduleRegistry;
    bytes32 public immutable coreCodeHash;
    bytes32 public immutable managerCodeHash;
    bytes32 public immutable registryCodeHash;
    address public immutable delegateRegistry;
    bytes32 public immutable delegateRegistryCodeHash;
    uint256 public immutable delegationUsecase;
    bytes32 public immutable baseManifestHash;
    uint256 private immutable _chainId;
    mapping(uint256 => mapping(bytes32 => mapping(uint256 => bool))) public override sliceUsed;
    mapping(uint256 => NftClaim) private _claims;
    bool private _receivingMint;

    constructor(DeploymentConfig memory d) StreamGasParameterHost(d.governanceAuthority) {
        if (
            d.core.code.length == 0 || d.manager.code.length == 0
                || d.moduleRegistry.code.length == 0 || d.governanceAuthority == address(0)
                || d.baseManifestHash == 0
                || !IERC165(d.core).supportsInterface(type(IERC721).interfaceId)
                || _addressRead(d.manager, "core()") != d.core
                || _addressRead(d.manager, "moduleRegistry()") != d.moduleRegistry
                || _addressRead(d.moduleRegistry, "governanceExecutor()") != d.governanceAuthority
        ) revert InvalidDistribution();
        core = d.core;
        manager = IStreamMintManager(d.manager);
        moduleRegistry = d.moduleRegistry;
        coreCodeHash = d.core.codehash;
        managerCodeHash = d.manager.codehash;
        registryCodeHash = d.moduleRegistry.codehash;
        delegateRegistry = d.delegateRegistry;
        delegateRegistryCodeHash = d.delegateRegistry.codehash;
        delegationUsecase = d.delegationUsecase;
        baseManifestHash = d.baseManifestHash;
        _chainId = block.chainid;
        _registerGasParameter(
            GasParameterConfig("SALE_NFT_DELIVERY_GAS_LIMIT", 300_000, 300_000, 2)
        );
        _registerGasParameter(GasParameterConfig("REVEAL_ATTEMPT_GAS_LIMIT", 400_000, 400_000, 2));
        _registerGasParameter(
            GasParameterConfig("DELEGATE_REGISTRY_GAS_LIMIT", 150_000, 150_000, 2)
        );
        StreamNativeAuctionDelegation.validateConfiguration(
            StreamNativeAuctionDelegation.Configuration(
                block.chainid,
                d.core,
                d.delegateRegistry,
                d.delegateRegistry.codehash,
                d.delegationUsecase,
                d.baseManifestHash,
                d.moduleRegistry,
                d.moduleRegistry.codehash
            )
        );
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamOperatorDistribution).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId || super.supportsInterface(id);
    }

    function moduleManifestBytes() external view returns (bytes memory) {
        return StreamNativeAuctionDelegation.manifestBytes(_delegation());
    }

    function programHash(uint256 collectionId, bytes32 phaseId, Program calldata p)
        public
        view
        override
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                PROGRAM_DOMAIN,
                block.chainid,
                address(this),
                core,
                address(manager),
                collectionId,
                phaseId,
                p
            )
        );
    }

    /// @dev Standard ABI encoding; ordered arrays include duplicates and exact artwork bytes.
    function sliceHash(uint256 index, IStreamMintManager.MintBatch calldata b)
        public
        view
        override
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                SLICE_DOMAIN,
                block.chainid,
                address(this),
                core,
                address(manager),
                b.collectionId,
                b.phaseId,
                index,
                b.beneficiaries,
                b.tokenData,
                b.mintCommitments
            )
        );
    }

    function sliceAuthorization(uint256 collectionId, bytes32 phaseId, uint256 index)
        public
        view
        override
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                AUTHORIZATION_DOMAIN,
                block.chainid,
                address(this),
                core,
                address(manager),
                collectionId,
                phaseId,
                index
            )
        );
    }

    function distribute(
        Program calldata p,
        uint256 index,
        bytes32[] calldata proof,
        IStreamMintManager.MintBatch calldata b,
        bytes calldata gateData
    ) external payable override nonReentrant returns (uint256[] memory tokenIds, bytes32 root) {
        if (msg.sender != p.operator) revert DistributionNotOperator(msg.sender);
        _admit(p, index, proof, b);
        IStreamImmediateSaleReveal.RevealQuote memory quote =
            StreamImmediateSaleReveal.quote(core, b.collectionId);
        uint256 fee = quote.policy.revealFeePerTokenWei * b.beneficiaries.length;
        if (msg.value != fee) revert DistributionFeeMismatch(msg.value, fee);
        StreamImmediateSaleReveal.preflight(
            quote, quote.policy.revealFeePerTokenWei, gasParameter(REVEAL_GAS)
        );
        sliceUsed[b.collectionId][b.phaseId][index] = true;
        _receivingMint = p.deliveryMode == DeliveryMode.FAILURE_ISOLATED;
        if (p.prepared) (tokenIds, root,) = manager.executePreparedMint(b, gateData);
        else (tokenIds, root,) = manager.executeSingleStepMint(b, gateData);
        _receivingMint = false;
        if (tokenIds.length != b.beneficiaries.length || root == 0) revert InvalidDistribution();
        _finish(b, tokenIds, quote, p.deliveryMode);
        _emitSlice(b, index, root, tokenIds.length);
    }

    function _emitSlice(
        IStreamMintManager.MintBatch calldata b,
        uint256 index,
        bytes32 root,
        uint256 quantity
    ) private {
        emit DistributionSliceExecuted(
            1, b.collectionId, b.phaseId, index, sliceHash(index, b), root, quantity
        );
    }

    function _finish(
        IStreamMintManager.MintBatch calldata b,
        uint256[] memory tokenIds,
        IStreamImmediateSaleReveal.RevealQuote memory quote,
        DeliveryMode mode
    ) private {
        uint256 revealGas = gasParameter(REVEAL_GAS);
        for (uint256 i; i < tokenIds.length; ++i) {
            StreamImmediateSaleReveal.fundAndAttempt(
                core, b.collectionId, tokenIds[i], quote, revealGas
            );
            if (mode == DeliveryMode.FAILURE_ISOLATED) {
                address beneficiary = b.beneficiaries[i];
                if (!_deliver(tokenIds[i], beneficiary)) {
                    _claims[tokenIds[i]] = NftClaim(b.collectionId, b.phaseId, beneficiary);
                    emit AirdropDeliveryDiverted(
                        1, b.collectionId, b.phaseId, tokenIds[i], beneficiary
                    );
                }
            }
        }
    }

    function nftClaim(uint256 tokenId) external view override returns (NftClaim memory) {
        return _claims[tokenId];
    }

    function claimNft(uint256 tokenId, address receiver)
        external
        override
        nonReentrant
        returns (bool)
    {
        if (_claims[tokenId].beneficiary != msg.sender) {
            revert DistributionClaimUnavailable(tokenId);
        }
        return _claim(tokenId, receiver);
    }

    function claimNftFor(uint256 tokenId, bool walletWide, uint256 index)
        external
        override
        nonReentrant
        returns (bool)
    {
        address beneficiary = _claims[tokenId].beneficiary;
        StreamNativeAuctionDelegation.claimRecipient(
            _delegation(),
            beneficiary,
            msg.sender,
            beneficiary,
            StreamNativeAuctionDelegation.Witness(walletWide, index),
            gasParameter(DELEGATE_GAS)
        );
        return _claim(tokenId, beneficiary);
    }

    function onERC721Received(address operator, address from, uint256, bytes calldata)
        external
        view
        override
        returns (bytes4)
    {
        if (
            msg.sender != core || operator != address(manager) || from != address(0)
                || !_receivingMint
        ) {
            revert InvalidDistribution();
        }
        return IERC721Receiver.onERC721Received.selector;
    }

    function _admit(
        Program calldata p,
        uint256 index,
        bytes32[] calldata proof,
        IStreamMintManager.MintBatch calldata b
    ) private view {
        if (sliceUsed[b.collectionId][b.phaseId][index]) {
            revert DistributionSliceUsed(index);
        }
        if (
            p.operator == address(0) || p.slicesRoot == 0 || p.totalQuantity == 0
                || p.perRecipientCap == 0 || p.perRecipientCap > p.totalQuantity
                || p.supplyCounterId == p.recipientCounterId || b.payer != address(0)
                || b.authorizer != address(0) || b.beneficiaries.length == 0
                || b.beneficiaries.length > 10
                || b.initialRecipients.length != b.beneficiaries.length
                || b.tokenData.length != b.beneficiaries.length
                || b.mintCommitments.length != b.beneficiaries.length
                || proof.length > MAX_PROOF_DEPTH
        ) revert InvalidDistribution();
        _active();
        (bool exists, IStreamMintManager.MintPhaseConfig memory phase) =
            manager.phase(b.collectionId, b.phaseId);
        bytes32 config = programHash(b.collectionId, b.phaseId, p);
        IStreamMintRoyaltyPolicy.Policy memory royalty = IStreamMintRoyaltyPolicy(address(manager))
            .phaseRoyaltyPolicy(b.collectionId, b.phaseId);
        if (royalty.configured) {
            if (!p.prepared || royalty.applicationConfigHash != config) {
                revert DistributionCommitmentMismatch();
            }
            config = IStreamMintRoyaltyPolicy(address(manager))
                .phaseRoyaltyConfigHash(b.collectionId, b.phaseId, royalty);
        }
        if (
            !exists || phase.configHash != config || b.beneficiaries.length > phase.maxBatchQuantity
        ) {
            revert DistributionCommitmentMismatch();
        }
        _counter(b, p.supplyCounterId, IStreamMintManager.CounterKeyMode.CONSTANT, p.totalQuantity);
        _counter(
            b, p.recipientCounterId, IStreamMintManager.CounterKeyMode.RECIPIENT, p.perRecipientCap
        );
        bytes32 leaf = sliceHash(index, b);
        if (
            b.contextHash != leaf
                || b.authorizationId != sliceAuthorization(b.collectionId, b.phaseId, index)
        ) {
            revert DistributionCommitmentMismatch();
        }
        bytes32 node = leaf;
        for (uint256 i; i < proof.length; ++i) {
            node = node < proof[i]
                ? keccak256(abi.encode(node, proof[i]))
                : keccak256(abi.encode(proof[i], node));
        }
        if (node != p.slicesRoot) revert DistributionCommitmentMismatch();
        for (uint256 i; i < b.beneficiaries.length; ++i) {
            address recipient = b.beneficiaries[i];
            if (recipient == address(0) || recipient == address(this)) {
                revert InvalidDistribution();
            }
            address expected = p.deliveryMode == DeliveryMode.DIRECT ? recipient : address(this);
            if (b.initialRecipients[i] != expected) revert DistributionCommitmentMismatch();
        }
    }

    function _counter(
        IStreamMintManager.MintBatch calldata b,
        bytes32 id,
        IStreamMintManager.CounterKeyMode mode,
        uint64 cap
    ) private view {
        IStreamMintManager.MintCounterConfig memory c =
            manager.counterConfig(b.collectionId, b.phaseId, id);
        if (
            !c.enabled || c.keyMode != mode || c.capMode != IStreamMintLedger.CounterCapMode.STATIC
                || c.deltaMode != IStreamMintLedger.CounterDeltaMode.STATIC || c.staticCap != cap
                || c.staticIncrement != 1
        ) {
            revert InvalidDistribution();
        }
        if (mode == IStreamMintManager.CounterKeyMode.CONSTANT) {
            IStreamMintCounterReads.CounterKeyContext memory context;
            context.collectionId = b.collectionId;
            context.phaseId = b.phaseId;
            context.counterId = id;
            context.executor = address(this);
            // Resolve in Manager context: its immutable first-use interpretation may be
            // legacy PHASE even when a broader raw definition was registered afterward.
            bytes32 subject =
                IStreamMintCounterReads(address(manager)).resolveCounter(context).subjectKey;
            bytes32 phaseSubject = keccak256(
                abi.encode(
                    keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1"),
                    block.chainid,
                    address(IStreamMintReads(address(manager)).mintLedger()),
                    mode,
                    b.collectionId,
                    b.phaseId,
                    id
                )
            );
            if (subject != phaseSubject) revert InvalidDistribution();
        }
    }

    function _active() private view {
        if (
            block.chainid != _chainId || core.codehash != coreCodeHash
                || address(manager).codehash != managerCodeHash
                || moduleRegistry.codehash != registryCodeHash
                || !IStreamModuleRegistry(moduleRegistry)
                    .isModuleEligible(
                        address(this), MODULE_TYPE, type(IStreamOperatorDistribution).interfaceId
                    )
        ) {
            revert DistributionNotActive();
        }
        (address selected, bytes32 hash,,,,,,,,) =
            IStreamCorePointers(core).getSatellitePointer(keccak256("MODULE_REGISTRY"));
        if (selected != moduleRegistry || hash != registryCodeHash) revert DistributionNotActive();
        StreamNativeAuctionDelegation.requireManifest(_delegation(), gasParameter(DELEGATE_GAS));
    }

    function _claim(uint256 tokenId, address receiver) private returns (bool) {
        NftClaim memory claim = _claims[tokenId];
        if (claim.beneficiary == address(0) || receiver == address(0) || receiver == address(this))
        {
            revert DistributionClaimUnavailable(tokenId);
        }
        delete _claims[tokenId];
        if (!_deliver(tokenId, receiver)) {
            _claims[tokenId] = claim;
            return false;
        }
        emit AirdropNftClaimCompleted(1, claim.collectionId, tokenId, receiver);
        return true;
    }

    /// @dev No returndata is copied from Core or a receiver; EIP-150 headroom preserves claim bookkeeping.
    function _deliver(uint256 tokenId, address receiver) private returns (bool ok) {
        uint256 cap = gasParameter(NFT_GAS);
        uint256 required = cap + (cap + 62) / 63 + 100_000;
        if (gasleft() < required) revert DistributionInsufficientGas(gasleft(), required);
        if (core.codehash != coreCodeHash) revert DistributionNotActive();
        bytes memory data = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256)", address(this), receiver, tokenId
        );
        address target = core;
        assembly ("memory-safe") { ok := call(cap, target, 0, add(data, 32), mload(data), 0, 0) }
    }

    function _delegation()
        private
        view
        returns (StreamNativeAuctionDelegation.Configuration memory)
    {
        return StreamNativeAuctionDelegation.Configuration(
                _chainId,
                core,
                delegateRegistry,
                delegateRegistryCodeHash,
                delegationUsecase,
                baseManifestHash,
                moduleRegistry,
                registryCodeHash
            );
    }

    function _addressRead(address target, string memory signature) private view returns (address) {
        (bool ok, bytes memory data) = target.staticcall(abi.encodeWithSignature(signature));
        if (!ok || data.length != 32) revert InvalidDistribution();
        return abi.decode(data, (address));
    }
}
