// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamBurnMintGate as B } from "../../interfaces/stream/mint/IStreamBurnMintGate.sol";
import { IStreamMintGate } from "../../interfaces/stream/mint/IStreamMintGate.sol";
import { IStreamMintManager as M } from "../../interfaces/stream/mint/IStreamMintManager.sol";
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
import { StreamImmediateSaleReveal } from "./StreamImmediateSaleReveal.sol";
import {
    IStreamImmediateSaleReveal
} from "../../interfaces/stream/mint/IStreamImmediateSaleReveal.sol";
import {
    IStreamBurnMintNativeSale,
    IStreamBurnMintNativeExecutor,
    N,
    S
} from "../../interfaces/stream/mint/IStreamBurnMintNativeSale.sol";
import {
    StreamNativeSettlementTypes
} from "../../interfaces/stream/revenue/StreamNativeSettlementTypes.sol";

/// @notice Genesis BURN_MINT_GATE: original native burns, same-call evidence and Manager mint.
/// @dev This gate never writes Ledger or calls Core mint hooks. Manager is the sole mint authority.
contract StreamBurnMintGate is
    B,
    IStreamBurnMintNativeExecutor,
    Ownable,
    ReentrancyGuard,
    StreamModuleBase,
    StreamGasParameterHost
{
    struct Configuration {
        address core;
        address registry;
        address governance;
        address operator;
        bytes32 deploymentManifestHash;
        bytes32 moduleManifestHash;
        string moduleManifestURI;
        GasParameterConfig dependencyReadGas;
        GasParameterConfig burnGas;
        GasParameterConfig revealGas;
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
    bytes32 public constant REVEAL_GAS = keccak256("6529STREAM_GGP_REVEAL_ATTEMPT_GAS_LIMIT");
    uint256 public constant MAX_GATE_NULLIFIERS = 16;
    uint256 public constant MAX_SOURCE_COLLECTIONS = 64;
    address public immutable override core;
    address public immutable moduleRegistry;
    bytes32 public immutable coreCodeHash;
    bytes32 public immutable registryCodeHash;
    mapping(uint256 => Program) private _programs;
    ActiveProof private _active;

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
            c.core.code.length == 0 || c.registry.code.length == 0 || c.operator == address(0)
                || c.governance == address(0) || c.deploymentManifestHash == 0
                || c.moduleManifestHash == 0 || bytes(c.moduleManifestURI).length == 0
                || bytes(c.moduleManifestURI).length > 2048
                || c.dependencyReadGas.failureClass != FAILURE_CLASS_FAIL_CLOSED_PRECHECK
                || c.burnGas.failureClass != FAILURE_CLASS_FAIL_CLOSED_PRECHECK
                || c.revealGas.failureClass != FAILURE_CLASS_FAIL_CLOSED_PRECHECK
                || _registerGasParameter(c.dependencyReadGas) != DEPENDENCY_READ_GAS
                || _registerGasParameter(c.burnGas) != BURN_GAS
                || _registerGasParameter(c.revealGas) != REVEAL_GAS
        ) revert InvalidBurnMintConfiguration();
        core = c.core;
        moduleRegistry = c.registry;
        coreCodeHash = c.core.codehash;
        registryCodeHash = c.registry.codehash;
        _transferOwnership(c.operator);
    }

    function streamModuleType() public pure override returns (bytes32) {
        return keccak256("6529STREAM_MINT_GATE_V1");
    }

    function streamModuleVersion() public pure override returns (bytes32) {
        return keccak256("6529stream.burn-mint.v1");
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
        return id == type(B).interfaceId || id == type(IStreamMintGate).interfaceId
            || id == type(IStreamBurnMintNativeExecutor).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId || super.supportsInterface(id);
    }

    /// @notice Initial-only target program; Manager phase subsequently pins this exact config hash.
    function configureProgram(ProgramConfig calldata c)
        external
        override
        onlyOwner
        nonReentrant
        returns (bytes32 hash)
    {
        if (_programs[c.targetCollectionId].configHash != 0) {
            revert BurnMintProgramAlreadyConfigured(c.targetCollectionId);
        }
        if (
            c.manager.code.length == 0 || c.targetCollectionId == 0 || c.phaseId == 0
                || c.sourcesPerMint == 0 || c.sourcesPerMint > MAX_GATE_NULLIFIERS
                || c.sourceCollectionIds.length == 0
                || c.sourceCollectionIds.length > MAX_SOURCE_COLLECTIONS
                || (c.endsAt != 0 && (c.endsAt < c.startsAt || c.endsAt < block.timestamp))
        ) {
            revert InvalidBurnMintConfiguration();
        }
        _dependencies(c.manager, c.manager.codehash);
        if (c.nativeSaleAdapter != address(0)) {
            if (
                c.prepared || c.nativeSaleAdapter.code.length == 0
                    || abi.decode(
                            _read(
                                c.nativeSaleAdapter, abi.encodeWithSignature("mintManager()"), 32
                            ),
                            (address)
                        ) != c.manager
                    || abi.decode(
                            _read(c.nativeSaleAdapter, abi.encodeWithSignature("core()"), 32),
                            (address)
                        ) != core
                    || abi.decode(
                            _read(
                                c.nativeSaleAdapter, abi.encodeWithSignature("moduleRegistry()"), 32
                            ),
                            (address)
                        ) != moduleRegistry
                    || !abi.decode(
                        _read(
                            c.nativeSaleAdapter,
                            abi.encodeCall(
                                IERC165.supportsInterface,
                                (type(IStreamBurnMintNativeSale).interfaceId)
                            ),
                            32
                        ),
                        (bool)
                    )
            ) revert InvalidBurnMintConfiguration();
        }
        if (!_exists(c.targetCollectionId)) revert InvalidBurnMintConfiguration();
        for (uint256 i; i < c.sourceCollectionIds.length; ++i) {
            uint256 id = c.sourceCollectionIds[i];
            if (id == 0 || (i != 0 && id <= c.sourceCollectionIds[i - 1]) || !_exists(id)) {
                revert InvalidBurnMintConfiguration();
            }
        }
        hash = programConfigHash(c);
        _programs[c.targetCollectionId] = Program(
            c,
            hash,
            c.manager.codehash,
            c.nativeSaleAdapter == address(0) ? bytes32(0) : c.nativeSaleAdapter.codehash
        );
        emit BurnMintProgramConfigured(1, c.targetCollectionId, c.manager, c.phaseId, hash, c);
    }

    function programConfigHash(ProgramConfig calldata c) public view override returns (bytes32) {
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

    function program(uint256 targetCollectionId) external view override returns (Program memory) {
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

    function burnAndMint(M.MintBatch calldata batch, uint256[] calldata sources)
        external
        payable
        override
        nonReentrant
        returns (uint256[] memory tokens, bytes32 root, bytes32[] memory ids)
    {
        Program storage p = _requireProgram(batch);
        // Free execution has no payment authority and sends directly to explicit beneficiaries.
        if (
            p.config.nativeSaleAdapter != address(0) || batch.payer != address(0)
                || batch.authorizer != address(0)
        ) revert BurnMintPolicyMismatch();
        for (uint256 i; i < batch.beneficiaries.length; ++i) {
            if (batch.initialRecipients[i] != batch.beneficiaries[i]) {
                revert BurnMintPolicyMismatch();
            }
        }
        IStreamImmediateSaleReveal.RevealQuote memory quote =
            StreamImmediateSaleReveal.quote(core, batch.collectionId);
        uint256 revealCap = _gasParameterValue(REVEAL_GAS);
        uint256 quantity = batch.beneficiaries.length;
        if (msg.value != quote.policy.revealFeePerTokenWei * quantity) {
            revert BurnMintPolicyMismatch();
        }
        StreamImmediateSaleReveal.preflight(quote, quote.policy.revealFeePerTokenWei, revealCap);
        address[] memory owners = _burnAndOpen(p, batch, sources, address(this), msg.sender);
        if (p.config.prepared) {
            (tokens, root, ids) = M(p.config.manager).executePreparedMint(batch, "");
        } else {
            (tokens, root, ids) = M(p.config.manager).executeSingleStepMint(batch, "");
        }
        _complete(p, batch, tokens, root, ids);
        // Remove same-call proof before any reveal-provider callback.
        delete _active;
        for (uint256 i; i < tokens.length; ++i) {
            StreamImmediateSaleReveal.fundAndAttempt(
                core, batch.collectionId, tokens[i], quote, revealCap
            );
        }
        _emitBurnMint(p, root, msg.sender, sources, owners, tokens);
    }

    /// @notice Only the program's immutable native adapter can supply its authenticated original buyer.
    /// @dev The adapter keeps payment and the gate guard spans its one-use purchase callback.
    function executeNativeBurn(
        N.SaleExecutionData calldata e,
        address buyer,
        uint256 suppliedValue,
        uint256[] calldata sources
    )
        external
        override
        nonReentrant
        returns (S.PrimarySettlementResult memory result, uint256 tokenId)
    {
        (M.MintBatch memory batch, address[] memory owners) =
            _openNativeBurn(e, buyer, suppliedValue, sources);
        StreamNativeSettlementTypes.NativeSettlementCandidate memory candidate =
            N(msg.sender).previewExecution(e);
        (result, tokenId) = IStreamBurnMintNativeSale(msg.sender)
            .executeBurnPurchase(e, buyer, suppliedValue, sources);
        uint256[] memory tokens = new uint256[](1);
        tokens[0] = tokenId;
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = candidate.operationId;
        Program storage p = _programs[batch.collectionId];
        _complete(p, batch, tokens, candidate.operationIdentityCommitment, ids);
        if (
            result.operationIdentityCommitment != candidate.operationIdentityCommitment
                || result.settlementKey == 0
        ) revert BurnMintResultInvalid();
        delete _active;
        _emitBurnMint(p, candidate.operationIdentityCommitment, buyer, sources, owners, tokens);
    }

    function _openNativeBurn(
        N.SaleExecutionData calldata e,
        address buyer,
        uint256 suppliedValue,
        uint256[] calldata sources
    ) private returns (M.MintBatch memory batch, address[] memory owners) {
        N.SaleRecord memory sale = N(msg.sender).saleRecord(e.authorization.saleId);
        Program storage p = _programs[sale.config.collectionId];
        if (
            msg.sender != p.config.nativeSaleAdapter || msg.sender.codehash != p.nativeSaleCodeHash
                || buyer == address(0) || buyer != e.authorization.payer
                || buyer != e.authorization.executor
        ) revert BurnMintProofUnavailable();
        bytes32 digest = N(msg.sender).authorizationDigest(e.authorization);
        batch.collectionId = sale.config.collectionId;
        batch.phaseId = sale.config.phaseId;
        batch.payer = buyer;
        batch.initialRecipients = new address[](1);
        batch.initialRecipients[0] = e.authorization.recipient;
        batch.beneficiaries = batch.initialRecipients;
        batch.tokenData = new bytes[](1);
        batch.tokenData[0] = e.tokenData;
        batch.mintCommitments = new bytes32[](1);
        batch.mintCommitments[0] = e.authorization.mintCommitment;
        batch.expectedPolicyHash = sale.config.mintPolicyHash;
        batch.authorizationId =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), digest));
        batch.contextHash = digest;
        _requireProgram(batch);
        owners = _burnAndOpen(p, batch, sources, msg.sender, buyer);
        _active.gateHash =
            keccak256(abi.encode(_active.gateHash, msg.sender, sale.configHash, suppliedValue));
    }

    function _emitBurnMint(
        Program storage p,
        bytes32 root,
        address redeemer,
        uint256[] calldata sources,
        address[] memory owners,
        uint256[] memory tokens
    ) private {
        for (uint256 i; i < sources.length; ++i) {
            emit BurnMintExecuted(
                1,
                sources[i],
                tokens[i / p.config.sourcesPerMint],
                p.config.targetCollectionId,
                burnNullifier(sources[i]),
                redeemer
            );
        }
        emit BurnMintBatchExecuted(
            1, p.config.targetCollectionId, root, redeemer, sources, owners, tokens
        );
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
            revert BurnMintProofUnavailable();
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

    function _requireProgram(M.MintBatch memory batch) private view returns (Program storage p) {
        p = _programs[batch.collectionId];
        if (
            p.configHash == 0 || p.config.phaseId != batch.phaseId
                || block.timestamp < p.config.startsAt
                || (p.config.endsAt != 0 && block.timestamp > p.config.endsAt)
        ) {
            revert BurnMintProgramUnavailable(batch.collectionId);
        }
        uint256 quantity = batch.beneficiaries.length;
        if (
            quantity == 0 || quantity > 10 || batch.initialRecipients.length != quantity
                || batch.tokenData.length != quantity || batch.mintCommitments.length != quantity
                || batch.authorizationId == 0 || batch.expectedPolicyHash == 0
        ) revert BurnMintPolicyMismatch();
        _dependencies(p.config.manager, p.managerCodeHash);
        M.MintGateConfig memory gate =
            M(p.config.manager).phaseGate(batch.collectionId, batch.phaseId);
        if (
            gate.gate != address(this) || gate.gateConfigHash != p.configHash
                || gate.gateCodehash != address(this).codehash
        ) revert BurnMintPolicyMismatch();
    }

    function _burnAndOpen(
        Program storage p,
        M.MintBatch memory batch,
        uint256[] calldata sources,
        address executor,
        address actor
    ) private returns (address[] memory owners) {
        uint256 quantity = batch.beneficiaries.length;
        if (
            sources.length == 0 || sources.length > MAX_GATE_NULLIFIERS
                || sources.length != quantity * p.config.sourcesPerMint
        ) revert BurnMintPolicyMismatch();
        BurnEvidence memory evidence = _validateSources(p, sources, actor);
        _burnSources(sources, evidence);
        _active.manager = p.config.manager;
        _active.requestHash = _requestHash(p.config.manager, executor, batch);
        _active.authorizationId = batch.authorizationId;
        _active.quantity = uint64(quantity);
        _active.nullifiers = evidence.nullifiers;
        _active.gateHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_BURN_MINT_RESULT_V1"),
                block.chainid,
                address(this),
                core,
                p.configHash,
                actor,
                batch,
                sources,
                evidence.owners,
                evidence.collections,
                evidence.serials,
                evidence.nullifiers
            )
        );
        return evidence.owners;
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

    function _validateSources(Program storage p, uint256[] calldata sources, address actor)
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
            if (i != 0 && id <= sources[i - 1]) revert BurnMintTokenInvalid(id);
            (bool exists, uint256 collection, uint256 serial, bool burned) = _identity(id);
            if (!exists || burned || !_allowed(p, collection)) revert BurnMintTokenInvalid(id);
            evidence.collections[i] = collection;
            evidence.serials[i] = serial;
            evidence.owners[i] =
                abi.decode(_read(core, abi.encodeCall(IERC721.ownerOf, (id)), 32), (address));
            address approved =
                abi.decode(_read(core, abi.encodeCall(IERC721.getApproved, (id)), 32), (address));
            if (evidence.owners[i] == address(0)) revert BurnMintTokenInvalid(id);
            if (
                actor != evidence.owners[i] && actor != approved
                    && !_approved(evidence.owners[i], actor)
            ) {
                revert BurnMintAuthorityRequired(id, actor);
            }
            if (approved != address(this) && !_approved(evidence.owners[i], address(this))) {
                revert BurnMintAuthorityRequired(id, address(this));
            }
            evidence.nullifiers[i] = burnNullifier(id);
            if (M(p.config.manager).isNullifierUsed(evidence.nullifiers[i])) {
                revert BurnMintTokenInvalid(id);
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
            if (!ok || size != 0) revert BurnMintExecutionFailed(sources[i]);
            (bool exists, uint256 collection, uint256 serial, bool burned) = _identity(sources[i]);
            if (
                !exists || !burned || collection != evidence.collections[i]
                    || serial != evidence.serials[i]
            ) {
                revert BurnMintTokenInvalid(sources[i]);
            }
        }
    }

    function _complete(
        Program storage p,
        M.MintBatch memory batch,
        uint256[] memory tokens,
        bytes32 root,
        bytes32[] memory ids
    ) private view {
        if (
            root == 0 || tokens.length != batch.beneficiaries.length || ids.length != tokens.length
                || !M(p.config.manager).isOperationRootUsed(root)
                || !M(p.config.manager).isAuthorizationUsed(batch.authorizationId)
        ) {
            revert BurnMintResultInvalid();
        }
        for (uint256 i; i < _active.nullifiers.length; ++i) {
            if (!M(p.config.manager).isNullifierUsed(_active.nullifiers[i])) {
                revert BurnMintResultInvalid();
            }
        }
        for (uint256 i; i < tokens.length; ++i) {
            (bool exists, uint256 collection,, bool burned) = _identity(tokens[i]);
            if (ids[i] == 0 || !exists || burned || collection != batch.collectionId) {
                revert BurnMintResultInvalid();
            }
        }
    }

    function _allowed(Program storage p, uint256 id) private view returns (bool) {
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
            revert BurnMintDependencyInvalid(manager);
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
            revert BurnMintDependencyInvalid(moduleRegistry);
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
        if (selected != manager || hash != managerHash) revert BurnMintDependencyInvalid(manager);
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
        if (!ok || size != expected) revert BurnMintDependencyInvalid(target);
    }

    function _requireGas(uint256 cap) private view {
        uint256 available = gasleft();
        if (cap > available || available - cap < cap / 63 + (cap % 63 == 0 ? 0 : 1) + 30000) {
            revert BurnMintParentGasInsufficient(cap, available);
        }
    }
}
