// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamSaleArtist.sol";
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

/// @notice Fixed typed burn-sale validation/encoding; context comes only from carrier immutables.
library StreamERC20BurnMintSupport {
    struct GateBinding {
        address gate;
        bytes32 codeHash;
        bytes32 configHash;
    }

    struct Context {
        IStreamMintManager mintManager;
        IStreamRevenueResolver revenueResolver;
        IStreamSplitFactory splitFactory;
        IStreamArtistAttribution artistRegistry;
        bytes32 artistRegistryCodeHash;
        address platformSigner;
        uint256 signatureGas;
    }
    bytes32 private constant _CLASS = keccak256("PRIMARY_SALE");
    bytes32 private constant _TICKET_AUTHORIZATION =
        keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1");
    error InvalidUniversalSale();
    error UniversalSaleSignatureInvalid(address signer);
    error UniversalSettlementFailed();
    error InsufficientSettlementCallGas(uint256 cap);

    function candidate(
        Context memory x,
        U.SaleRecord memory record,
        E.Execution memory execution,
        bytes32 digest
    )
        public
        view
        returns (S.ERC20SettlementCandidate memory c, IStreamMintManager.MintBatch memory batch)
    {
        U.SaleExecutionData memory e = execution.sale;
        U.SaleAuthorization memory a = e.authorization;
        StreamSaleArtist.requireArtist(
            x.artistRegistry, x.artistRegistryCodeHash, record.config.collectionId, a.artist
        );
        if (!_validSignature(x.platformSigner, digest, e.platformSignature, x.signatureGas)) {
            revert UniversalSaleSignatureInvalid(x.platformSigner);
        }
        if (!_validSignature(a.artist, digest, e.artistSignature, x.signatureGas)) {
            revert UniversalSaleSignatureInvalid(a.artist);
        }
        StreamSaleTemplate.Selection memory rights = StreamUniversalSaleRights.rights(
            x.revenueResolver, x.splitFactory, record.config.collectionId
        );
        if (
            StreamSaleTemplate.policyHash(x.revenueResolver, record.config.collectionId, rights)
                != record.config.expectedPrimaryPolicyHash
        ) revert InvalidUniversalSale();
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
            record.config.price,
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
        c.saleExecutionHash = keccak256(abi.encode(execution));
        batch = _batch(a, record.config, e.tokenData, digest);
    }

    function _batch(
        U.SaleAuthorization memory a,
        U.SaleConfig memory config,
        bytes memory tokenData,
        bytes32 digest
    ) private pure returns (IStreamMintManager.MintBatch memory b) {
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

    function registrationGate(
        U.SaleConfig memory config,
        IStreamMintManager mintManager,
        address core,
        bytes32 mintManagerCodeHash
    ) public view returns (GateBinding memory pin) {
        IStreamMintManager.MintGateConfig memory g =
            mintManager.phaseGate(config.collectionId, config.phaseId);
        IStreamERC20BurnMintGate gate = IStreamERC20BurnMintGate(g.gate);
        if (
            g.gate == address(0) || g.gate.codehash != g.gateCodehash
                || !gate.supportsInterface(type(IStreamERC20BurnMintGate).interfaceId)
                || gate.core() != core || gate.erc20SaleAdapter() != address(this)
                || gate.erc20SaleCodeHash() != address(this).codehash
        ) revert InvalidUniversalSale();
        B.Program memory p = gate.program(config.collectionId);
        if (
            p.configHash == 0 || p.configHash != g.gateConfigHash
                || p.config.phaseId != config.phaseId
                || p.config.targetCollectionId != config.collectionId
                || p.config.manager != address(mintManager)
                || p.managerCodeHash != mintManagerCodeHash || p.config.prepared
                || p.config.nativeSaleAdapter != address(0) || p.config.startsAt > config.startsAt
                || (p.config.endsAt != 0 && p.config.endsAt < config.endsAt)
        ) {
            revert InvalidUniversalSale();
        }
        (bool exists, IStreamMintManager.MintPhaseConfig memory phase) =
            mintManager.phase(config.collectionId, config.phaseId);
        if (
            !exists || phase.paused || phase.maxBatchQuantity != 1
                || !mintManager.phaseExecutor(config.collectionId, config.phaseId, address(this))
        ) revert InvalidUniversalSale();
        return GateBinding(g.gate, g.gateCodehash, p.configHash);
    }

    function settle(
        address primarySaleSettlement,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
    ) public returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result) {
        bytes memory data = abi.encodeCall(
            IStreamPrimarySaleSettlement.settleERC20PrimarySaleFromAdapter,
            (c.lifecycleBinding.paymentAdapter, c)
        );
        bytes memory response = new bytes(384);
        address target = primarySaleSettlement;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := call(gas(), target, 0, add(data, 32), mload(data), add(response, 32), 384)
            size := returndatasize()
        }
        if (!ok || size != 384) revert UniversalSettlementFailed();
        result = abi.decode(response, (StreamPrimarySettlementTypes.PrimarySettlementResult));
        if (
            result.candidateCommitment
                    != StreamPrimarySettlementHash.candidateCommitment(
                        c.lifecycleBinding.paymentAdapter, primarySaleSettlement, c
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
        ) revert UniversalSettlementFailed();
    }

    function _validSignature(address signer, bytes32 digest, bytes memory signature, uint256 cap)
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
        uint256 available = gasleft();
        if (cap > available || available - cap < (cap + 62) / 63 + 40_000) {
            revert InsufficientSettlementCallGas(cap);
        }
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
}
