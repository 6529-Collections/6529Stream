// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamBurnMintGate as B } from "../../interfaces/stream/mint/IStreamBurnMintGate.sol";
import { IStreamMintGate } from "../../interfaces/stream/mint/IStreamMintGate.sol";
import { IStreamMintManager as M } from "../../interfaces/stream/mint/IStreamMintManager.sol";
import {
    IStreamERC20BurnMintGate,
    IStreamERC20BurnMintContinuation
} from "../../interfaces/stream/mint/IStreamERC20BurnMintGate.sol";
import {
    IStreamERC20BurnMintSale
} from "../../interfaces/stream/mint/IStreamERC20BurnMintSale.sol";
import {
    StreamERC20BurnMintTypes as E,
    U,
    S
} from "../../interfaces/stream/mint/StreamERC20BurnMintTypes.sol";
import {
    IStreamERC20SaleExecution
} from "../../interfaces/stream/revenue/IStreamERC20SaleExecution.sol";
import { IStreamModuleRegistry } from "../../interfaces/stream/modules/IStreamModuleRegistry.sol";
import { IStreamCoreIdentity } from "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import { IStreamCoreBurn } from "../../interfaces/stream/core/IStreamCoreBurn.sol";
import { IStreamCorePointers } from "../../interfaces/stream/core/IStreamCorePointers.sol";
import {
    IStreamCoreCollectionView
} from "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import { IERC721 } from "../../vendor/openzeppelin/IERC721.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import { Ownable } from "../../vendor/openzeppelin/Ownable.sol";
import { ReentrancyGuard } from "../../vendor/openzeppelin/ReentrancyGuard.sol";
import { StreamModuleBase } from "../modules/StreamModuleBase.sol";
import { StreamGasParameterHost } from "../parameters/StreamGasParameterHost.sol";
import {
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import { StreamPrimarySettlementHash } from "../revenue/StreamPrimarySettlementHash.sol";

/// @notice Dedicated positive ERC20 burn/mint gate. It has no free or native purchase entry.
/// @dev Preview proof exists only around a fixed-target STATICCALL. Real proof surrounds burns,
///      the immutable carrier continuation, and unchanged Manager/Ledger consumption atomically.
contract StreamERC20BurnMintGate is
    IStreamERC20BurnMintGate,
    Ownable,
    ReentrancyGuard,
    StreamModuleBase,
    StreamGasParameterHost
{
    struct Configuration {
        address core;
        address registry;
        address erc20SaleAdapter;
        address governance;
        address operator;
        bytes32 deploymentManifestHash;
        bytes32 moduleManifestHash;
        string moduleManifestURI;
        GasParameterConfig dependencyReadGas;
        GasParameterConfig burnGas;
    }

    struct ActiveProof {
        address manager;
        bytes32 requestHash;
        bytes32 authorizationId;
        bytes32 gateHash;
        uint64 quantity;
        bytes32[] nullifiers;
    }

    struct BurnEvidence {
        address[] owners;
        uint256[] collections;
        uint256[] serials;
        bytes32[] nullifiers;
    }

    bytes32 public constant BURN_MINT_GATE = keccak256("BURN_MINT_GATE");
    bytes32 public constant STREAM_BURN_NULLIFIER_V1 = keccak256("6529STREAM_BURN_NULLIFIER_V1");
    bytes32 public constant DEPENDENCY_READ_GAS =
        keccak256("6529STREAM_GGP_BURN_DEPENDENCY_READ_GAS");
    bytes32 public constant BURN_GAS = keccak256("6529STREAM_GGP_BURN_EXECUTION_GAS");
    uint256 public constant MAX_GATE_NULLIFIERS = 16;
    uint256 public constant MAX_SOURCE_COLLECTIONS = 64;
    address public immutable override core;
    address public immutable moduleRegistry;
    bytes32 public immutable coreCodeHash;
    bytes32 public immutable registryCodeHash;
    address public immutable override erc20SaleAdapter;
    bytes32 public immutable override erc20SaleCodeHash;
    mapping(uint256 => B.Program) private _programs;
    ActiveProof private _active;

    event BurnMintProgramConfigured(
        uint16 schemaVersion,
        uint256 indexed targetCollectionId,
        address indexed manager,
        bytes32 indexed phaseId,
        bytes32 configHash,
        B.ProgramConfig config
    );
    event BurnMintExecuted(
        uint16 schemaVersion,
        uint256 indexed sourceTokenId,
        uint256 indexed mintedTokenId,
        uint256 indexed targetCollectionId,
        bytes32 burnNullifier,
        address redeemer
    );
    event BurnMintBatchExecuted(
        uint16 schemaVersion,
        uint256 indexed targetCollectionId,
        bytes32 indexed operationRoot,
        address indexed burnCaller,
        uint256[] sourceTokenIds,
        address[] sourceOwners,
        uint256[] mintedTokenIds
    );

    constructor(Configuration memory c)
        StreamModuleBase(
            keccak256("6529STREAM_BURN_MINT_SCHEMA_V1"),
            address(0),
            c.deploymentManifestHash,
            c.moduleManifestURI,
            c.moduleManifestHash
        )
        StreamGasParameterHost(c.governance)
    {
        if (
            c.core.code.length == 0 || c.registry.code.length == 0
                || c.erc20SaleAdapter.code.length == 0 || c.operator == address(0)
                || c.governance == address(0) || c.deploymentManifestHash == 0
                || c.moduleManifestHash == 0 || bytes(c.moduleManifestURI).length == 0
                || bytes(c.moduleManifestURI).length > 2048
                || c.dependencyReadGas.failureClass != FAILURE_CLASS_FAIL_CLOSED_PRECHECK
                || c.burnGas.failureClass != FAILURE_CLASS_FAIL_CLOSED_PRECHECK
                || _registerGasParameter(c.dependencyReadGas) != DEPENDENCY_READ_GAS
                || _registerGasParameter(c.burnGas) != BURN_GAS
        ) revert B.InvalidBurnMintConfiguration();
        core = c.core;
        moduleRegistry = c.registry;
        coreCodeHash = c.core.codehash;
        registryCodeHash = c.registry.codehash;
        erc20SaleAdapter = c.erc20SaleAdapter;
        erc20SaleCodeHash = c.erc20SaleAdapter.codehash;
        _transferOwnership(c.operator);
    }

    function streamModuleType() public pure override returns (bytes32) {
        return keccak256("6529STREAM_MINT_GATE_V1");
    }

    function streamModuleVersion() public pure override returns (bytes32) {
        return keccak256("6529stream.erc20-burn-mint.v1");
    }

    function streamModuleInterfaceId() public pure override returns (bytes4) {
        return type(IStreamMintGate).interfaceId;
    }

    function supportsInterface(bytes4 id)
        public
        view
        override(StreamModuleBase, IERC165)
        returns (bool)
    {
        return id == type(IStreamERC20BurnMintGate).interfaceId
            || id == type(IStreamMintGate).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId || super.supportsInterface(id);
    }

    /// @notice Original program encoding, with the carrier identity pinned by this gate's runtime.
    function configureProgram(B.ProgramConfig calldata c)
        external
        override
        onlyOwner
        nonReentrant
        returns (bytes32 hash)
    {
        if (_programs[c.targetCollectionId].configHash != 0) {
            revert B.BurnMintProgramAlreadyConfigured(c.targetCollectionId);
        }
        if (
            c.manager.code.length == 0 || c.targetCollectionId == 0 || c.phaseId == 0
                || c.sourcesPerMint == 0 || c.sourcesPerMint > MAX_GATE_NULLIFIERS
                || c.sourceCollectionIds.length == 0
                || c.sourceCollectionIds.length > MAX_SOURCE_COLLECTIONS
                || c.nativeSaleAdapter != address(0) || c.prepared
                || (c.endsAt != 0 && (c.endsAt < c.startsAt || c.endsAt < block.timestamp))
        ) {
            revert B.InvalidBurnMintConfiguration();
        }
        _dependencies(c.manager, c.manager.codehash);
        _carrier(c.manager);
        if (!_exists(c.targetCollectionId)) revert B.InvalidBurnMintConfiguration();
        for (uint256 i; i < c.sourceCollectionIds.length; ++i) {
            uint256 id = c.sourceCollectionIds[i];
            if (id == 0 || (i != 0 && id <= c.sourceCollectionIds[i - 1]) || !_exists(id)) {
                revert B.InvalidBurnMintConfiguration();
            }
        }
        hash = programConfigHash(c);
        _programs[c.targetCollectionId] = B.Program(c, hash, c.manager.codehash, bytes32(0));
        emit BurnMintProgramConfigured(1, c.targetCollectionId, c.manager, c.phaseId, hash, c);
    }

    function programConfigHash(B.ProgramConfig calldata c) public view override returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_BURN_MINT_CONFIG_V1"),
                block.chainid,
                address(this),
                core,
                moduleRegistry,
                c
            )
        );
    }

    function program(uint256 targetCollectionId) external view override returns (B.Program memory) {
        return _programs[targetCollectionId];
    }

    function allowedSourceCollections(uint256 targetCollectionId)
        external
        view
        override
        returns (uint256[] memory)
    {
        return _programs[targetCollectionId].config.sourceCollectionIds;
    }

    function burnNullifier(uint256 sourceTokenId) public view override returns (bytes32) {
        return keccak256(
            abi.encode(
                STREAM_BURN_NULLIFIER_V1, uint256(block.chainid), core, uint256(sourceTokenId)
            )
        );
    }

    function previewERC20Burn(M.MintBatch calldata batch, E.Execution calldata e)
        external
        override
        nonReentrant
        returns (S.ERC20SettlementCandidate memory candidate)
    {
        B.Program storage p = _requireProgram(batch, e);
        BurnEvidence memory evidence =
            _validateSources(p, e.sourceTokenIds, e.sale.authorization.executor);
        _open(p, batch, e, evidence);
        // Solidity's view interface emits STATICCALL. Its entire descendant call tree is read-only.
        candidate = IStreamERC20BurnMintContinuation(erc20SaleAdapter).previewBurnExecution(e);
        _validateCandidate(p, batch, e, candidate);
        delete _active;
    }

    function executeERC20Burn(M.MintBatch calldata batch, E.Execution calldata e)
        external
        override
        nonReentrant
        returns (E.Result memory result)
    {
        B.Program storage p = _requireProgram(batch, e);
        BurnEvidence memory evidence =
            _validateSources(p, e.sourceTokenIds, e.sale.authorization.executor);
        _burnSources(e.sourceTokenIds, evidence);
        _open(p, batch, e, evidence);
        S.ERC20SettlementCandidate memory candidate =
            IStreamERC20BurnMintContinuation(erc20SaleAdapter).previewBurnExecution(e);
        _validateCandidate(p, batch, e, candidate);
        result = IStreamERC20BurnMintContinuation(erc20SaleAdapter).executeBurnMint(e);
        _complete(p, batch, candidate, result);
        delete _active;
        uint256[] memory tokens = new uint256[](1);
        tokens[0] = result.tokenId;
        for (uint256 i; i < e.sourceTokenIds.length; ++i) {
            emit BurnMintExecuted(
                1,
                e.sourceTokenIds[i],
                result.tokenId,
                batch.collectionId,
                evidence.nullifiers[i],
                e.sale.authorization.executor
            );
        }
        emit BurnMintBatchExecuted(
            1,
            batch.collectionId,
            result.operationRoot,
            e.sale.authorization.executor,
            e.sourceTokenIds,
            evidence.owners,
            tokens
        );
    }

    function _requireProgram(M.MintBatch calldata batch, E.Execution calldata e)
        private
        view
        returns (B.Program storage p)
    {
        if (msg.sender != erc20SaleAdapter || msg.sender.codehash != erc20SaleCodeHash) {
            revert B.BurnMintProofUnavailable();
        }
        p = _programs[batch.collectionId];
        if (
            p.configHash == 0 || p.config.phaseId != batch.phaseId
                || block.timestamp < p.config.startsAt
                || (p.config.endsAt != 0 && block.timestamp > p.config.endsAt)
        ) {
            revert B.BurnMintProgramUnavailable(batch.collectionId);
        }
        if (
            batch.beneficiaries.length != 1 || batch.initialRecipients.length != 1
                || batch.tokenData.length != 1 || batch.mintCommitments.length != 1
                || batch.authorizationId == 0 || batch.expectedPolicyHash == 0
                || batch.authorizer != address(0) || batch.resolverData.length != 0
                || e.sourceTokenIds.length == 0 || e.sourceTokenIds.length > MAX_GATE_NULLIFIERS
                || e.sourceTokenIds.length != p.config.sourcesPerMint
        ) {
            revert B.BurnMintPolicyMismatch();
        }
        _dependencies(p.config.manager, p.managerCodeHash);
        _carrier(p.config.manager);
        _eligible(
            address(this), keccak256("6529STREAM_MINT_GATE_V1"), type(IStreamMintGate).interfaceId
        );
        _eligible(
            erc20SaleAdapter,
            keccak256("FIXED_PRICE_SALE_ADAPTER"),
            type(IStreamERC20SaleExecution).interfaceId
        );
        M.MintGateConfig memory gate = abi.decode(
            _read(
                p.config.manager,
                abi.encodeCall(M.phaseGate, (batch.collectionId, batch.phaseId)),
                192
            ),
            (M.MintGateConfig)
        );
        if (
            gate.gate != address(this) || gate.gateConfigHash != p.configHash
                || gate.gateCodehash != address(this).codehash
        ) revert B.BurnMintPolicyMismatch();
        U.SaleRecord memory sale = _sale(e.sale.authorization.saleId);
        U.SaleAuthorization calldata a = e.sale.authorization;
        bytes32 digest = abi.decode(
            _read(
                erc20SaleAdapter,
                abi.encodeCall(IStreamERC20BurnMintSale.authorizationDigest, (a)),
                32
            ),
            (bytes32)
        );
        if (
            sale.saleNonce == 0 || sale.cancelled || sale.config.asset == address(0)
                || sale.config.price == 0 || sale.config.collectionId != batch.collectionId
                || sale.config.phaseId != batch.phaseId
                || sale.config.mintPolicyHash != batch.expectedPolicyHash
                || a.saleConfigHash != sale.configHash || block.timestamp < sale.config.startsAt
                || block.timestamp > sale.config.endsAt || a.payer == address(0)
                || a.executor == address(0) || a.recipient == address(0) || a.mintCommitment == 0
                || a.tokenDataHash != keccak256(e.sale.tokenData) || batch.payer != a.payer
                || batch.initialRecipients[0] != a.recipient
                || batch.beneficiaries[0] != a.recipient
                || batch.mintCommitments[0] != a.mintCommitment
                || keccak256(batch.tokenData[0]) != a.tokenDataHash || batch.contextHash != digest
                || batch.authorizationId
                    != keccak256(
                        abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), digest)
                    )
        ) {
            revert B.BurnMintPolicyMismatch();
        }
    }

    function _sale(bytes32 id) private view returns (U.SaleRecord memory) {
        return abi.decode(
            _read(erc20SaleAdapter, abi.encodeCall(IStreamERC20BurnMintSale.saleRecord, (id)), 512),
            (U.SaleRecord)
        );
    }

    function _open(
        B.Program storage p,
        M.MintBatch calldata batch,
        E.Execution calldata e,
        BurnEvidence memory evidence
    ) private {
        _active.manager = p.config.manager;
        _active.requestHash = _requestHash(p.config.manager, erc20SaleAdapter, batch);
        _active.authorizationId = batch.authorizationId;
        _active.quantity = 1;
        _active.nullifiers = evidence.nullifiers;
        // Prospective and real proof use the same original owner/collection/serial facts.
        // The burned flag is deliberately not part of this canonical preimage.
        _active.gateHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_BURN_MINT_RESULT_V1"),
                block.chainid,
                address(this),
                core,
                p.configHash,
                e.sale.authorization.executor,
                batch,
                e.sourceTokenIds,
                evidence.owners,
                evidence.collections,
                evidence.serials,
                evidence.nullifiers
            )
        );
    }

    function _validateCandidate(
        B.Program storage p,
        M.MintBatch calldata batch,
        E.Execution calldata e,
        S.ERC20SettlementCandidate memory c
    ) private view {
        U.SaleRecord memory sale = _sale(e.sale.authorization.saleId);
        if (
            c.saleAdapter != erc20SaleAdapter || c.mintManager != p.config.manager
                || c.executor != e.sale.authorization.executor || c.sale.payer != batch.payer
                || c.sale.beneficiary != batch.beneficiaries[0]
                || c.sale.collectionId != batch.collectionId
                || c.sale.settlementId != e.sale.authorization.saleId
                || c.sale.saleNonce != sale.saleNonce || c.sale.tokenId != 0
                || c.sale.policyMode != 0 || c.sale.poster != address(0)
                || c.sale.revenueClass != keccak256("PRIMARY_SALE")
                || c.sale.amount != sale.config.price || c.asset != sale.config.asset
                || c.sale.expectedPrimaryPolicyHash != sale.config.expectedPrimaryPolicyHash
                || c.orchestrationOrder != 1 || c.operationIdentityCommitment == 0
                || c.operationId == 0 || c.boundPolicyHash != batch.expectedPolicyHash
                || c.currentPolicyHash == 0
                || c.executionBinding.saleAuthorizationDigest != batch.contextHash
                || c.executionBinding.executionNonce != e.sale.authorization.executionNonce
                || c.executionBinding.authorityMode != 1
                || keccak256(abi.encode(c.lifecycleBinding))
                    != keccak256(abi.encode(sale.lifecycle)) || c.rights.profileId == 0
                || c.rights.wallet == address(0) || c.rights.templateId != 0
                || c.executionBinding.executionId != StreamPrimarySettlementHash.executionId(c)
                || c.saleExecutionHash != keccak256(abi.encode(e))
        ) revert B.BurnMintResultInvalid();
    }

    function _complete(
        B.Program storage p,
        M.MintBatch calldata batch,
        S.ERC20SettlementCandidate memory c,
        E.Result memory result
    ) private view {
        address recorder = abi.decode(
            _read(erc20SaleAdapter, abi.encodeWithSignature("primarySaleSettlement()"), 32),
            (address)
        );
        S.PrimarySettlementResult memory r = result.settlement;
        if (
            result.operationRoot != c.operationIdentityCommitment
                || result.operationId != c.operationId
                || r.candidateCommitment
                    != StreamPrimarySettlementHash.candidateCommitment(
                        c.lifecycleBinding.paymentAdapter, recorder, c
                    )
                || r.settlementKey
                    != StreamPrimarySettlementHash.settlementKey(
                        recorder, erc20SaleAdapter, c.executionBinding.executionId
                    ) || r.profileId != c.rights.profileId || r.wallet != c.rights.wallet
                || r.asset != c.asset || r.amount != c.sale.amount || r.executor != c.executor
                || r.executionId != c.executionBinding.executionId
                || r.operationIdentityCommitment != c.operationIdentityCommitment
                || r.currentPolicyHash != c.currentPolicyHash
                || r.boundPolicyHash != c.boundPolicyHash
                || !M(p.config.manager).isOperationRootUsed(result.operationRoot)
                || !M(p.config.manager).isAuthorizationUsed(batch.authorizationId)
        ) revert B.BurnMintResultInvalid();
        for (uint256 i; i < _active.nullifiers.length; ++i) {
            if (!M(p.config.manager).isNullifierUsed(_active.nullifiers[i])) {
                revert B.BurnMintResultInvalid();
            }
        }
        (bool exists, uint256 collection,, bool burned) = _identity(result.tokenId);
        if (!exists || burned || collection != batch.collectionId) {
            revert B.BurnMintResultInvalid();
        }
        _dependencies(p.config.manager, p.managerCodeHash);
        _carrier(p.config.manager);
        _eligible(
            address(this), keccak256("6529STREAM_MINT_GATE_V1"), type(IStreamMintGate).interfaceId
        );
        _eligible(
            erc20SaleAdapter,
            keccak256("FIXED_PRICE_SALE_ADAPTER"),
            type(IStreamERC20SaleExecution).interfaceId
        );
    }

    function _carrier(address manager) private view {
        if (
            erc20SaleAdapter.codehash != erc20SaleCodeHash
                || abi.decode(
                        _read(erc20SaleAdapter, abi.encodeWithSignature("mintManager()"), 32),
                        (address)
                    ) != manager
                || abi.decode(
                        _read(erc20SaleAdapter, abi.encodeWithSignature("core()"), 32), (address)
                    ) != core
                || abi.decode(
                        _read(erc20SaleAdapter, abi.encodeWithSignature("moduleRegistry()"), 32),
                        (address)
                    ) != moduleRegistry
                || !abi.decode(
                    _read(
                        erc20SaleAdapter,
                        abi.encodeCall(
                            IERC165.supportsInterface, (type(IStreamERC20BurnMintSale).interfaceId)
                        ),
                        32
                    ),
                    (bool)
                )
        ) {
            revert B.BurnMintDependencyInvalid(erc20SaleAdapter);
        }
    }

    function _eligible(address module, bytes32 moduleType, bytes4 interfaceId) private view {
        if (!abi.decode(
                _read(
                    moduleRegistry,
                    abi.encodeCall(
                        IStreamModuleRegistry.isModuleEligible, (module, moduleType, interfaceId)
                    ),
                    32
                ),
                (bool)
            )) revert B.BurnMintDependencyInvalid(module);
    }

    function validateMint(
        address manager,
        address executor,
        uint256 collectionId,
        bytes32 phaseId,
        address payer,
        address authorizer,
        address[] memory initialRecipients,
        address[] memory beneficiaries,
        bytes32 contextHash,
        bytes32 expectedPolicyHash,
        bytes memory gateData
    ) public view override returns (GateResult memory result) {
        if (
            msg.sender != manager || manager != _active.manager || _active.gateHash == 0
                || gateData.length != 0
                || _active.requestHash
                    != keccak256(
                        abi.encode(
                            manager,
                            executor,
                            collectionId,
                            phaseId,
                            payer,
                            authorizer,
                            initialRecipients,
                            beneficiaries,
                            contextHash,
                            expectedPolicyHash
                        )
                    )
        ) {
            revert B.BurnMintProofUnavailable();
        }
        result = GateResult(
            _active.authorizationId,
            _active.nullifiers,
            address(0),
            0,
            _active.quantity,
            _active.gateHash
        );
    }

    function _requestHash(address manager, address executor, M.MintBatch memory batch)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                manager,
                executor,
                batch.collectionId,
                batch.phaseId,
                batch.payer,
                batch.authorizer,
                batch.initialRecipients,
                batch.beneficiaries,
                batch.contextHash,
                batch.expectedPolicyHash
            )
        );
    }

    function _validateSources(B.Program storage p, uint256[] calldata sources, address actor)
        private
        view
        returns (BurnEvidence memory evidence)
    {
        evidence.owners = new address[](sources.length);
        evidence.collections = new uint256[](sources.length);
        evidence.serials = new uint256[](sources.length);
        evidence.nullifiers = new bytes32[](sources.length);
        // Validate all roles and original identities before the first mutation.
        for (uint256 i; i < sources.length; ++i) {
            uint256 id = sources[i];
            if (i != 0 && id <= sources[i - 1]) revert B.BurnMintTokenInvalid(id);
            (bool exists, uint256 collection, uint256 serial, bool burned) = _identity(id);
            if (!exists || burned || !_allowed(p, collection)) revert B.BurnMintTokenInvalid(id);
            evidence.collections[i] = collection;
            evidence.serials[i] = serial;
            evidence.owners[i] =
                abi.decode(_read(core, abi.encodeCall(IERC721.ownerOf, (id)), 32), (address));
            address approved =
                abi.decode(_read(core, abi.encodeCall(IERC721.getApproved, (id)), 32), (address));
            if (evidence.owners[i] == address(0)) revert B.BurnMintTokenInvalid(id);
            if (
                actor != evidence.owners[i] && actor != approved
                    && !_approved(evidence.owners[i], actor)
            ) {
                revert B.BurnMintAuthorityRequired(id, actor);
            }
            if (approved != address(this) && !_approved(evidence.owners[i], address(this))) {
                revert B.BurnMintAuthorityRequired(id, address(this));
            }
            evidence.nullifiers[i] = burnNullifier(id);
            if (M(p.config.manager).isNullifierUsed(evidence.nullifiers[i])) {
                revert B.BurnMintTokenInvalid(id);
            }
        }
    }

    function _burnSources(uint256[] calldata sources, BurnEvidence memory evidence) private {
        for (uint256 i; i < sources.length; ++i) {
            bytes memory data = abi.encodeCall(IStreamCoreBurn.burn, (sources[i]));
            uint256 cap = _gasParameterValue(BURN_GAS);
            _requireGas(cap);
            address target = core;
            bool ok;
            uint256 size;
            assembly ("memory-safe") {
                ok := call(cap, target, 0, add(data, 32), mload(data), 0, 0)
                size := returndatasize()
            }
            if (!ok || size != 0) revert B.BurnMintExecutionFailed(sources[i]);
            (bool exists, uint256 collection, uint256 serial, bool burned) = _identity(sources[i]);
            if (
                !exists || !burned || collection != evidence.collections[i]
                    || serial != evidence.serials[i]
            ) {
                revert B.BurnMintTokenInvalid(sources[i]);
            }
        }
    }

    function _allowed(B.Program storage p, uint256 id) private view returns (bool) {
        for (uint256 i; i < p.config.sourceCollectionIds.length; ++i) {
            if (p.config.sourceCollectionIds[i] == id) return true;
        }
        return false;
    }

    function _exists(uint256 id) private view returns (bool) {
        return abi.decode(
            _read(core, abi.encodeCall(IStreamCoreCollectionView.collectionExists, (id)), 32),
            (bool)
        );
    }

    function _identity(uint256 id) private view returns (bool, uint256, uint256, bool) {
        return abi.decode(
            _read(core, abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (id)), 128),
            (bool, uint256, uint256, bool)
        );
    }

    function _approved(address holder, address actor) private view returns (bool) {
        return abi.decode(
            _read(core, abi.encodeCall(IERC721.isApprovedForAll, (holder, actor)), 32), (bool)
        );
    }

    function _dependencies(address manager, bytes32 managerHash) private view {
        if (
            core.codehash != coreCodeHash || moduleRegistry.codehash != registryCodeHash
                || manager.codehash != managerHash
                || abi.decode(_read(manager, abi.encodeWithSignature("core()"), 32), (address))
                    != core
                || abi.decode(
                        _read(manager, abi.encodeWithSignature("moduleRegistry()"), 32), (address)
                    ) != moduleRegistry
        ) {
            revert B.BurnMintDependencyInvalid(manager);
        }
        (address selected, bytes32 hash,,,,,,,,) = abi.decode(
            _read(
                core,
                abi.encodeCall(
                    IStreamCorePointers.getSatellitePointer, (keccak256("MODULE_REGISTRY"))
                ),
                320
            ),
            (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
        );
        if (selected != moduleRegistry || hash != registryCodeHash) {
            revert B.BurnMintDependencyInvalid(moduleRegistry);
        }
        (selected, hash,,,,,,,,) = abi.decode(
            _read(
                core,
                abi.encodeCall(
                    IStreamCorePointers.getSatellitePointer, (keccak256("MINT_MANAGER"))
                ),
                320
            ),
            (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
        );
        if (selected != manager || hash != managerHash) {
            revert B.BurnMintDependencyInvalid(manager);
        }
    }

    function _read(address target, bytes memory data, uint256 expected)
        private
        view
        returns (bytes memory output)
    {
        uint256 cap = _gasParameterValue(DEPENDENCY_READ_GAS);
        _requireGas(cap);
        output = new bytes(expected);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), add(output, 32), expected)
            size := returndatasize()
        }
        if (!ok || size != expected) revert B.BurnMintDependencyInvalid(target);
    }

    function _requireGas(uint256 cap) private view {
        uint256 available = gasleft();
        if (cap > available || available - cap < cap / 63 + (cap % 63 == 0 ? 0 : 1) + 30000) {
            revert B.BurnMintParentGasInsufficient(cap, available);
        }
    }
}
