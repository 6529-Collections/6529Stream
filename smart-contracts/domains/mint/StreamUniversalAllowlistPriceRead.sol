// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamUniversalAllowlistPrice.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import "./StreamUniversalSaleRights.sol";
import "./StreamSaleArtist.sol";
import "./StreamSaleConsent.sol";
import "../revenue/StreamPrimarySettlementHash.sol";
import "../revenue/StreamSettlementAdmission.sol";
import "../../interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";
import "../../interfaces/stream/mint/IStreamMintReads.sol";
import "../../interfaces/stream/revenue/IStreamPrimarySettlementBindings.sol";
import "../../interfaces/stream/artist/IStreamArtistSaleFacts.sol";

interface IStreamUniversalAllowlistPriceHost is IStreamPrimarySettlementBindings {
    function coreCodeHash() external view returns(bytes32);
    function moduleRegistryCodeHash() external view returns(bytes32);
    function resolverCodeHash() external view returns(bytes32);
    function factoryCodeHash() external view returns(bytes32);
    function assetRegistryCodeHash() external view returns(bytes32);
    function mintManager() external view returns(IStreamMintManager);
    function mintManagerCodeHash() external view returns(bytes32);
    function primarySaleSettlement() external view returns(address);
    function settlementCodeHash() external view returns(bytes32);
    function platformSigner() external view returns(address);
    function artistRegistry() external view returns(IStreamArtistAttribution);
    function artistRegistryCodeHash() external view returns(bytes32);
    function paused() external view returns(bool);
}

/// @notice View-only admission for the dedicated same-leaf carrier. Typed storage references only.
library StreamUniversalAllowlistPriceRead {
    bytes32 private constant _DOMAIN=keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant SALE_AUTHORIZATION_TYPEHASH=keccak256("UniversalSaleAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 executionNonce,bytes32 nonce,uint64 deadline)");
    bytes32 private constant _CLASS=keccak256("PRIMARY_SALE");
    bytes32 private constant _TICKET_AUTHORIZATION=keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1");
    error InvalidSettlementContext(address target);
    error InsufficientSettlementCallGas(uint256 requiredCap);
    error SettlementReadFailed(address target,bytes4 selector);
    error SettlementAssetNotActive(address asset);
    struct Context { address core; address moduleRegistry; IStreamRevenueResolver revenueResolver; IStreamSplitFactory splitFactory; IStreamAssetPolicyRegistry assetPolicyRegistry; IStreamMintManager mintManager; address primarySaleSettlement; address platformSigner; IStreamArtistAttribution artistRegistry; bytes32 artistRegistryCodeHash; }
    function context() internal view returns(Context memory x) {
        IStreamUniversalAllowlistPriceHost h=IStreamUniversalAllowlistPriceHost(address(this));
        x=Context(h.core(),h.moduleRegistry(),h.revenueResolver(),h.splitFactory(),h.assetPolicyRegistry(),h.mintManager(),h.primarySaleSettlement(),h.platformSigner(),h.artistRegistry(),h.artistRegistryCodeHash());
    }
    function requireContext(Context memory x) internal view {
        IStreamUniversalAllowlistPriceHost h=IStreamUniversalAllowlistPriceHost(address(this));
        StreamSettlementAdmission.requireRegistry(x.core,h.coreCodeHash(),x.moduleRegistry,h.moduleRegistryCodeHash());
        if(address(x.revenueResolver).codehash!=h.resolverCodeHash())revert InvalidSettlementContext(address(x.revenueResolver));
        if(address(x.splitFactory).codehash!=h.factoryCodeHash())revert InvalidSettlementContext(address(x.splitFactory));
        if(address(x.assetPolicyRegistry).codehash!=h.assetRegistryCodeHash())revert InvalidSettlementContext(address(x.assetPolicyRegistry));
        if(x.primarySaleSettlement.codehash!=h.settlementCodeHash())revert InvalidSettlementContext(x.primarySaleSettlement);
        if(address(x.mintManager).codehash!=h.mintManagerCodeHash())revert InvalidSettlementContext(address(x.mintManager));
    }
    function previewEncoded(mapping(bytes32 => IStreamUniversalFixedPriceSaleAdapter.SaleRecord) storage sales, mapping(bytes32 => IStreamUniversalAllowlistPriceSale.AllowlistPricePolicy) storage policies, mapping(address => mapping(bytes32 => bool)) storage used, mapping(bytes32 => mapping(uint256 => bytes32)) storage executions,bytes calldata raw) public view returns(bytes memory) {
        (IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,bytes memory proof)=abi.decode(raw[4:],(IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData,bytes));
        (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,)=candidate(sales,policies,used,executions,e,proof);
        StreamUniversalAllowlistPrice.quote(context().core,c.sale.collectionId);
        IStreamGasParameterHost(address(this)).gasParameter(keccak256("6529STREAM_GGP_REVEAL_ATTEMPT_GAS_LIMIT"));
        return abi.encode(c,StreamUniversalAllowlistPrice.encode(e,c.sale.amount,proof));
    }
    function candidate(mapping(bytes32 => IStreamUniversalFixedPriceSaleAdapter.SaleRecord) storage sales, mapping(bytes32 => IStreamUniversalAllowlistPriceSale.AllowlistPricePolicy) storage policies, mapping(address => mapping(bytes32 => bool)) storage used, mapping(bytes32 => mapping(uint256 => bytes32)) storage executions, IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e, bytes memory resolverData)
        public
        view
        returns (
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
            IStreamMintManager.MintBatch memory batch
        )
    {
        Context memory x=context(); requireContext(x);
        IStreamUniversalFixedPriceSaleAdapter.SaleAuthorization memory a = e.authorization;
        IStreamUniversalFixedPriceSaleAdapter.SaleRecord storage record = sales[a.saleId];
        if (policies[a.saleId].priceCounterId == 0) revert IStreamUniversalAllowlistPriceSale.InvalidUniversalPriceProfile();
        if (
            IStreamUniversalAllowlistPriceHost(address(this)).paused() || record.saleNonce == 0 || record.cancelled
                || block.timestamp < record.config.startsAt
                || block.timestamp > record.config.endsAt
        ) revert IStreamUniversalFixedPriceSaleAdapter.UniversalSaleUnavailable(a.saleId);
        requireConsent(sales,x,a.saleId);
        if (
            a.saleConfigHash != record.configHash || a.payer == address(0)
                || a.executor == address(0) || a.recipient == address(0) || a.artist == address(0)
                || a.mintCommitment == 0 || a.executionNonce == 0
                || a.tokenDataHash != keccak256(e.tokenData) || block.timestamp > a.deadline
        ) revert IStreamUniversalFixedPriceSaleAdapter.InvalidUniversalSale();
        if (used[a.artist][a.nonce]) {
            revert IStreamUniversalFixedPriceSaleAdapter.UniversalAuthorizationUsed(a.artist, a.nonce);
        }
        if (executions[a.saleId][a.executionNonce] != 0) {
            revert IStreamUniversalFixedPriceSaleAdapter.UniversalExecutionUsed(a.saleId, a.executionNonce);
        }
        bytes32 digest = _authorizationDigest(a);
        StreamSaleArtist.requireArtist(
            x.artistRegistry, x.artistRegistryCodeHash, record.config.collectionId, a.artist
        );
        if (!_validSignature(x,x.platformSigner, digest, e.platformSignature)) {
            revert IStreamUniversalFixedPriceSaleAdapter.UniversalSaleSignatureInvalid(x.platformSigner);
        }
        if (!_validSignature(x,a.artist, digest, e.artistSignature)) {
            revert IStreamUniversalFixedPriceSaleAdapter.UniversalSaleSignatureInvalid(a.artist);
        }
        _requireActive(x,record.config.asset);
        StreamSaleTemplate.Selection memory rights = rights(x,record.config.collectionId);
        if (
            StreamSaleTemplate.policyHash(x.revenueResolver, record.config.collectionId, rights)
                != record.config.expectedPrimaryPolicyHash
        ) revert IStreamUniversalFixedPriceSaleAdapter.InvalidUniversalSale();
        uint256 amount = StreamUniversalAllowlistPrice.price(address(x.mintManager),record.config,policies[a.saleId],a,resolverData);
        c.saleAdapter = address(this);
        c.executor = a.executor;
        c.sale = StreamPrimarySettlementTypes.PrimarySale(
            a.saleId,
            _CLASS,
            0,
            record.config.collectionId,
            0,
            record.saleNonce,
            a.payer,
            address(0),
            a.recipient,
            amount,
            record.config.expectedPrimaryPolicyHash
        );
        c.lifecycleBinding = record.lifecycle;
        c.executionBinding =
            StreamPrimarySettlementTypes.SaleExecutionBinding(0, a.executionNonce, 1, digest);
        c.asset = record.config.asset;
        c.orchestrationOrder = 1;
        c.mintManager = address(x.mintManager);
        c.currentPolicyHash = IStreamMintReads(address(x.mintManager))
            .phasePolicyHash(record.config.collectionId, record.config.phaseId);
        c.boundPolicyHash = record.config.mintPolicyHash;
        c.rights = StreamPrimarySettlementTypes.PrimaryRights(
            rights.profileId,
            rights.wallet,
            rights.templateId,
            rights.assignmentHash,
            rights.entriesHash
        );
        c.saleExecutionHash = keccak256(StreamUniversalAllowlistPrice.encode(e,amount,resolverData));
        batch = _batch(a, record.config, e.tokenData, digest);
        batch.resolverData = resolverData;
        bytes32[] memory ids;
        (c.operationIdentityCommitment, ids) =
            IStreamMintReads(address(x.mintManager)).previewSingleStepMintOperation(batch, "");
        if (c.operationIdentityCommitment == 0 || ids.length != 1 || ids[0] == 0) {
            revert IStreamUniversalFixedPriceSaleAdapter.UniversalMintResultInvalid();
        }
        c.operationId = ids[0];
        c.executionBinding.executionId = StreamPrimarySettlementHash.executionId(c);
    }
    function _authorizationDigest(IStreamUniversalFixedPriceSaleAdapter.SaleAuthorization memory authorization)
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
    function _batch(
        IStreamUniversalFixedPriceSaleAdapter.SaleAuthorization memory a,
        IStreamUniversalFixedPriceSaleAdapter.SaleConfig memory config,
        bytes memory tokenData,
        bytes32 digest
    ) private view returns (IStreamMintManager.MintBatch memory b) {
        b.collectionId = config.collectionId;
        b.phaseId = config.phaseId;
        b.payer = a.payer;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = a.recipient;
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = a.recipient;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = tokenData;
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = a.mintCommitment;
        b.expectedPolicyHash = config.mintPolicyHash;
        b.authorizationId = keccak256(abi.encode(_TICKET_AUTHORIZATION, digest));
        b.contextHash = digest;
    }
    function requireConsent(mapping(bytes32 => IStreamUniversalFixedPriceSaleAdapter.SaleRecord) storage sales,Context memory x,bytes32 id) internal view {
        IStreamUniversalFixedPriceSaleAdapter.SaleRecord storage record = sales[id];
        if (record.saleNonce == 0) revert IStreamUniversalFixedPriceSaleAdapter.UniversalSaleUnavailable(id);
        StreamSaleConsent.requireConsent(
            x.core,
            address(x.artistRegistry),
            x.artistRegistryCodeHash,
            record.config.collectionId,
            id,
            record.configHash
        );
    }
    function rights(Context memory x,uint256 collectionId)
        internal
        view
        returns (StreamSaleTemplate.Selection memory)
    {
        return StreamUniversalSaleRights.rights(x.revenueResolver, x.splitFactory, collectionId);
    }
    function retained(mapping(bytes32 => IStreamUniversalFixedPriceSaleAdapter.SaleRecord) storage sales, mapping(bytes32 => IStreamUniversalAllowlistPriceSale.AllowlistPricePolicy) storage policies,StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c, IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e, bytes memory resolverData) public view {
        Context memory x=context();requireContext(x);
        requireConsent(sales,x,e.authorization.saleId);
        StreamSettlementAdmission.requireAdmission(x.moduleRegistry,c.lifecycleBinding.paymentAdapter,c);
        StreamSaleArtist.requireArtist(x.artistRegistry,x.artistRegistryCodeHash,c.sale.collectionId,e.authorization.artist);
        if (keccak256(abi.encode(rights(x,c.sale.collectionId))) != keccak256(abi.encode(c.rights)) || IStreamMintReads(address(x.mintManager)).phasePolicyHash(c.sale.collectionId,sales[e.authorization.saleId].config.phaseId) != c.currentPolicyHash || StreamUniversalAllowlistPrice.price(address(x.mintManager),sales[e.authorization.saleId].config,policies[e.authorization.saleId],e.authorization,resolverData) != c.sale.amount) revert IStreamUniversalFixedPriceSaleAdapter.UniversalCandidateMismatch();
    }
    function registration(IStreamUniversalFixedPriceSaleAdapter.SaleConfig memory config,IStreamUniversalAllowlistPriceSale.AllowlistPricePolicy memory policy) public view returns(StreamPrimarySettlementTypes.SaleLifecycleBinding memory binding) {
        if(policy.priceCounterId==0)revert IStreamUniversalAllowlistPriceSale.InvalidUniversalPriceProfile();
        Context memory x=context();requireContext(x);
        if (
            config.collectionId == 0 || config.phaseId == 0 || config.price == 0
                || config.endsAt <= config.startsAt || config.endsAt < block.timestamp
                || config.mintPolicyHash == 0 || config.expectedPrimaryPolicyHash == 0
                || IStreamMintReads(address(x.mintManager))
                        .phasePolicyHash(config.collectionId, config.phaseId)
                    != config.mintPolicyHash
        ) revert IStreamUniversalFixedPriceSaleAdapter.InvalidUniversalSale();
        _requireActive(x,config.asset);
        StreamSaleTemplate.Selection memory rights = rights(x,config.collectionId);
        if (
            StreamSaleTemplate.policyHash(x.revenueResolver, config.collectionId, rights)
                != config.expectedPrimaryPolicyHash
        ) revert IStreamUniversalFixedPriceSaleAdapter.InvalidUniversalSale();
        binding =
            StreamSettlementAdmission.capture(x.moduleRegistry, address(this), config.paymentAdapter);
        if (
            _read(
                        config.paymentAdapter,
                        abi.encodeWithSignature("primarySaleSettlement()"),
                        gasleft()
                    ) != uint256(uint160(x.primarySaleSettlement))
                || _read(config.paymentAdapter, abi.encodeWithSignature("core()"), gasleft())
                    != uint256(uint160(x.core))
        ) revert IStreamUniversalFixedPriceSaleAdapter.InvalidUniversalSale();
        if (policy.priceCounterId != 0) {
            IStreamGasParameterHost(address(this)).gasParameter(keccak256("6529STREAM_GGP_REVEAL_ATTEMPT_GAS_LIMIT"));
            StreamMintSaleAllowlist.validatePolicy(address(x.mintManager), config.collectionId, config.phaseId, policy.priceCounterId);
            StreamUniversalAllowlistPrice.quote(x.core, config.collectionId);
        }
    }
    function _gas(Context memory x,bytes32 id) private view returns(uint256 cap) {
        cap=_read(address(x.splitFactory),abi.encodeCall(IStreamGasParameterHost.gasParameter,(id)),gasleft());
        if(cap==0 || cap>type(uint64).max)revert InvalidSettlementContext(address(x.splitFactory));
    }
    function _admitGas(uint256 cap) private view {
        uint256 available = gasleft();
        if (cap > available || available - cap < cap / 63 + (cap % 63 == 0 ? 0 : 1) + 40_000) {
            revert InsufficientSettlementCallGas(cap);
        }
    }
    function _read(address target, bytes memory data, uint256 cap)
        private
        view
        returns (uint256 word)
    {
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        if (!ok || size != 32) revert SettlementReadFailed(target, bytes4(data));
    }
    function _validSignature(Context memory x,address signer, bytes32 digest, bytes memory signature)
        private
        view
        returns (bool)
    {
        if (signer == address(0)) return false;
        if (signer.code.length == 0 || !StreamSettlementAdmission.isContract(signer)) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            if (signature.length == 65) {
                assembly ("memory-safe") {
                    r := mload(add(signature, 32))
                    s := mload(add(signature, 64))
                    v := byte(0, mload(add(signature, 96)))
                }
            } else if (signature.length == 64) {
                bytes32 vs;
                assembly ("memory-safe") {
                    r := mload(add(signature, 32))
                    vs := mload(add(signature, 64))
                }
                s = vs & bytes32(type(uint256).max >> 1);
                v = uint8(uint256(vs) >> 255) + 27;
            }
            if (
                uint256(s) <= 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0
                    && (v == 27 || v == 28) && ecrecover(digest, v, r, s) == signer
            ) return true;
            if (signer.code.length == 0) return false;
        }
        bytes memory data = abi.encodeWithSelector(bytes4(0x1626ba7e), digest, signature);
        uint256 cap = _gas(x,keccak256("6529STREAM_GGP_ERC_1271_GAS_LIMIT"));
        _admitGas(cap);
        bool ok;
        uint256 size;
        uint256 word;
        assembly ("memory-safe") {
            ok := staticcall(cap, signer, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        return ok && size == 32 && word == uint256(uint32(0x1626ba7e)) << 224;
    }
    function _requireActive(Context memory x,address asset) private view {
        uint256 cap=_gas(x,keccak256("6529STREAM_GGP_ASSET_POLICY_GAS_LIMIT"));_admitGas(cap);
        if(!StreamSettlementAdmission.isContract(asset) || _read(address(x.assetPolicyRegistry),abi.encodeCall(IStreamAssetPolicyRegistry.assetStatus,(asset)),cap)!=1)revert SettlementAssetNotActive(asset);
    }
}
