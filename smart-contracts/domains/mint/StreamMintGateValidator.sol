// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../vendor/openzeppelin/IERC165.sol";
import "../../interfaces/stream/mint/IStreamMintGate.sol";
import "../../interfaces/stream/mint/IStreamMintManager.sol";
import "../../interfaces/stream/mint/compatibility/IStreamMintModuleRegistry.sol";
import "../../interfaces/stream/modules/IStreamModuleRegistry.sol";
import "./StreamMintOperationIdentity.sol";
import "../../interfaces/stream/mint/IStreamMintBatchGate.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";

/// @notice Closed-world gate configuration and request validation for StreamMintManager.
/// @dev Linked so complete gate validation does not make the manager undeployable.
library StreamMintGateValidator {
    uint256 private constant GATE_ERC165_PROBE_GAS = 30_000;
    uint256 private constant MAX_GATE_NULLIFIERS = 16;
    bytes32 public constant MINT_GATE_MODULE_TYPE = keccak256("6529STREAM_MINT_GATE_V1");
    bytes32 private constant GGP_MINT_GATE_GAS_LIMIT =
        keccak256("6529STREAM_GGP_MINT_GATE_GAS_LIMIT");
    error MintGateCallFailed(address gate);
    error MintGateInsufficientGas(uint256 available, uint256 required);

    /// @notice Accepts the canonical registry and the historical mint-registry fixture surface.
    function isSupportedRegistry(IERC165 registry) external view returns (bool) {
        return address(registry).code.length != 0 && _supports(registry, type(IERC165).interfaceId)
            && !_supports(registry, 0xffffffff)
            && (_supports(registry, type(IStreamModuleRegistry).interfaceId)
                || _supports(registry, type(IStreamMintModuleRegistry).interfaceId));
    }

    struct GateCall {
        address gate;
        uint32 gasLimit;
        address executor;
        uint256 collectionId;
        bytes32 phaseId;
        address payer;
        address authorizer;
        address[] initialRecipients;
        address[] beneficiaries;
        bytes32 contextHash;
        bytes32 policyHash;
        bytes gateData;
    }

    function validateConfiguration(
        IStreamMintManager.MintGateConfig calldata gateConfig,
        IERC165 moduleRegistry
    ) external view returns (IStreamMintManager.MintGateConfig memory) {
        if (gateConfig.gate == address(0)) {
            if (
                gateConfig.gateConfigHash != bytes32(0) || gateConfig.gateCodehash != bytes32(0)
                    || gateConfig.gateMetadataHash != bytes32(0)
                    || gateConfig.gateSemanticVersion != 0 || gateConfig.gateGasLimit != 0
            ) {
                revert IStreamMintManager.InvalidMintGate(gateConfig.gate);
            }
            return gateConfig;
        }
        if (gateConfig.gateConfigHash == bytes32(0)) {
            revert IStreamMintManager.InvalidMintGate(gateConfig.gate);
        }

        IStreamMintModuleRegistry.MintModuleInfo memory info =
            _requireActiveGateInfo(moduleRegistry, gateConfig.gate);
        bytes32 actualCodehash = gateConfig.gate.codehash;
        if (gateConfig.gateCodehash != bytes32(0) && gateConfig.gateCodehash != actualCodehash) {
            revert IStreamMintManager.MintGateCodehashChanged(
                gateConfig.gate, gateConfig.gateCodehash, actualCodehash
            );
        }
        if (
            gateConfig.gateMetadataHash != bytes32(0)
                && gateConfig.gateMetadataHash != info.metadataHash
        ) {
            revert IStreamMintManager.InvalidMintGate(gateConfig.gate);
        }
        if (
            gateConfig.gateSemanticVersion != 0
                && gateConfig.gateSemanticVersion != info.semanticVersion
        ) {
            revert IStreamMintManager.InvalidMintGate(gateConfig.gate);
        }
        if (gateConfig.gateGasLimit != 0 && gateConfig.gateGasLimit != info.gasLimit) {
            revert IStreamMintManager.InvalidMintGate(gateConfig.gate);
        }

        return IStreamMintManager.MintGateConfig({
            gate: gateConfig.gate,
            gateConfigHash: gateConfig.gateConfigHash,
            gateCodehash: actualCodehash,
            gateMetadataHash: info.metadataHash,
            gateSemanticVersion: info.semanticVersion,
            gateGasLimit: info.gasLimit
        });
    }

    function validateAuthorization(
        IStreamMintManager.MintBatch calldata batch,
        bytes calldata gateData,
        uint256 quantity,
        bytes32 boundPolicyHash,
        IStreamMintManager.MintGateConfig memory gateConfig,
        IERC165 moduleRegistry,
        address executor
    ) external view returns (StreamMintOperationIdentity.MintAuthorization memory) {
        if (batch.authorizationId == bytes32(0)) {
            revert IStreamMintManager.MintAuthorizationRequired(batch.collectionId, batch.phaseId);
        }
        if (gateConfig.gate == address(0)) {
            if (batch.authorizer != address(0)) {
                revert IStreamMintManager.MintInvalidAuthorizerKind(
                    uint8(IStreamMintManager.AuthorizerKind.NONE), batch.authorizer
                );
            }
            return StreamMintOperationIdentity.MintAuthorization({
                authorizationId: batch.authorizationId,
                nullifiers: new bytes32[](0),
                authorizer: address(0),
                authorizerKind: IStreamMintManager.AuthorizerKind.NONE,
                maxQuantity: 0,
                gateHash: bytes32(0)
            });
        }

        _requireGateStillActive(moduleRegistry, gateConfig);
        IStreamMintGate.GateResult memory result =
            _callGate(batch, gateData, boundPolicyHash, gateConfig, executor);
        if (result.nullifiers.length > MAX_GATE_NULLIFIERS) {
            revert IStreamMintManager.MintGateNullifierCountExceeded(
                result.nullifiers.length, MAX_GATE_NULLIFIERS
            );
        }
        _canonicalizeNullifiers(result.nullifiers);
        if (result.maxQuantity != 0 && quantity > result.maxQuantity) {
            revert IStreamMintManager.MintGateQuantityExceeded(quantity, result.maxQuantity);
        }
        if (result.gateHash == bytes32(0)) {
            revert IStreamMintManager.MintGateHashRequired(gateConfig.gate);
        }
        if (result.authorizer != batch.authorizer) {
            revert IStreamMintManager.MintGateAuthorizerMismatch(
                batch.authorizer, result.authorizer
            );
        }
        _requireAuthorizerKind(result.authorizerKind, result.authorizer, executor);
        if (result.authorizationId != batch.authorizationId) {
            revert IStreamMintManager.MintGateAuthorizationMismatch(
                batch.authorizationId, result.authorizationId
            );
        }
        return StreamMintOperationIdentity.MintAuthorization({
            authorizationId: result.authorizationId,
            nullifiers: result.nullifiers,
            authorizer: result.authorizer,
            authorizerKind: IStreamMintManager.AuthorizerKind(result.authorizerKind),
            maxQuantity: result.maxQuantity,
            gateHash: result.gateHash
        });
    }

    function _callGate(
        IStreamMintManager.MintBatch calldata batch,
        bytes calldata gateData,
        bytes32 boundPolicyHash,
        IStreamMintManager.MintGateConfig memory gateConfig,
        address executor
    ) private view returns (IStreamMintGate.GateResult memory) {
        // Every GateCall field is assigned below before any field is read or encoded.
        // slither-disable-next-line uninitialized-local
        GateCall memory gateCall;
        gateCall.gate = gateConfig.gate;
        gateCall.gasLimit = gateConfig.gateGasLimit;
        gateCall.executor = executor;
        gateCall.collectionId = batch.collectionId;
        gateCall.phaseId = batch.phaseId;
        gateCall.payer = batch.payer;
        gateCall.authorizer = batch.authorizer;
        gateCall.initialRecipients = batch.initialRecipients;
        gateCall.beneficiaries = batch.beneficiaries;
        gateCall.contextHash = batch.contextHash;
        gateCall.policyHash = boundPolicyHash;
        gateCall.gateData = gateData;

        bytes memory payload = abi.encodeWithSelector(
            IStreamMintGate.validateMint.selector,
            address(this),
            gateCall.executor,
            gateCall.collectionId,
            gateCall.phaseId,
            gateCall.payer,
            gateCall.authorizer,
            gateCall.initialRecipients,
            gateCall.beneficiaries,
            gateCall.contextHash,
            gateCall.policyHash,
            gateCall.gateData
        );
        if (_supports(IERC165(gateCall.gate), type(IStreamMintBatchGate).interfaceId)) {
            payload = abi.encodeWithSelector(
                IStreamMintBatchGate.validateMintBatch.selector,
                address(this),
                executor,
                batch,
                gateData
            );
        }
        uint256 cap = IStreamGasParameterHost(address(this)).gasParameter(GGP_MINT_GATE_GAS_LIMIT);
        if (gateCall.gasLimit > cap) cap = gateCall.gasLimit;
        bytes memory returndata = _boundedGateCall(gateCall.gate, payload, cap);
        return abi.decode(returndata, (IStreamMintGate.GateResult));
    }

    function _boundedGateCall(address gate, bytes memory payload, uint256 cap)
        private
        view
        returns (bytes memory result)
    {
        uint256 required = cap + (cap + 62) / 63 + 40_000;
        uint256 available = gasleft();
        if (available < required) revert MintGateInsufficientGas(available, required);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, gate, add(payload, 32), mload(payload), 0, 0)
            size := returndatasize()
        }
        if (!ok || size < 256 || size > 2_048) revert MintGateCallFailed(gate);
        result = new bytes(size);
        uint256 outerOffset;
        uint256 nullifierOffset;
        uint256 count;
        uint256 authorizer;
        uint256 kind;
        uint256 quantity;
        assembly ("memory-safe") {
            returndatacopy(add(result, 32), 0, size)
            outerOffset := mload(add(result, 32))
            nullifierOffset := mload(add(result, 96))
            authorizer := mload(add(result, 128))
            kind := mload(add(result, 160))
            quantity := mload(add(result, 192))
            count := mload(add(result, 256))
        }
        if (
            outerOffset != 32 || nullifierOffset != 192 || count > MAX_GATE_NULLIFIERS
                || size != 256 + count * 32 || authorizer > type(uint160).max
                || kind > uint8(IStreamMintManager.AuthorizerKind.CALLER_ADAPTER)
                || quantity > type(uint64).max
        ) {
            revert MintGateCallFailed(gate);
        }
    }

    function _requireAuthorizerKind(uint8 kind, address authorizer, address executor) private pure {
        if (kind > uint8(IStreamMintManager.AuthorizerKind.CALLER_ADAPTER)) {
            revert IStreamMintManager.MintInvalidAuthorizerKind(kind, authorizer);
        }
        IStreamMintManager.AuthorizerKind authorizerKind = IStreamMintManager.AuthorizerKind(kind);
        if (
            (authorizerKind == IStreamMintManager.AuthorizerKind.NONE && authorizer != address(0))
                || (authorizerKind != IStreamMintManager.AuthorizerKind.NONE
                    && authorizer == address(0))
                || (authorizerKind == IStreamMintManager.AuthorizerKind.CALLER_ADAPTER
                    && authorizer != executor)
        ) {
            revert IStreamMintManager.MintInvalidAuthorizerKind(kind, authorizer);
        }
    }

    function _canonicalizeNullifiers(bytes32[] memory nullifiers) private pure {
        for (uint256 i = 0; i < nullifiers.length; i++) {
            bytes32 value = nullifiers[i];
            if (value == bytes32(0)) {
                revert IStreamMintManager.MintGateNullifiersUnsupported(value);
            }
            uint256 j = i;
            while (j != 0 && uint256(nullifiers[j - 1]) > uint256(value)) {
                nullifiers[j] = nullifiers[j - 1];
                j--;
            }
            if (j != 0 && nullifiers[j - 1] == value) {
                revert IStreamMintManager.MintGateNullifiersUnsupported(value);
            }
            nullifiers[j] = value;
        }
    }

    function _requireGateStillActive(
        IERC165 moduleRegistry,
        IStreamMintManager.MintGateConfig memory gateConfig
    ) private view {
        IStreamMintModuleRegistry.MintModuleInfo memory info =
            _requireActiveGateInfo(moduleRegistry, gateConfig.gate);
        bytes32 actualCodehash = gateConfig.gate.codehash;
        if (actualCodehash != gateConfig.gateCodehash || actualCodehash != info.codehash) {
            revert IStreamMintManager.MintGateCodehashChanged(
                gateConfig.gate, gateConfig.gateCodehash, actualCodehash
            );
        }
        if (
            info.metadataHash != gateConfig.gateMetadataHash
                || info.semanticVersion != gateConfig.gateSemanticVersion
                || info.gasLimit != gateConfig.gateGasLimit
        ) {
            revert IStreamMintManager.MintGateNotActive(gateConfig.gate);
        }
    }

    function _requireActiveGateInfo(IERC165 moduleRegistry, address gate)
        private
        view
        returns (IStreamMintModuleRegistry.MintModuleInfo memory info)
    {
        if (_supports(moduleRegistry, type(IStreamModuleRegistry).interfaceId)) {
            return _canonicalGateInfo(IStreamModuleRegistry(address(moduleRegistry)), gate);
        }
        try IStreamMintModuleRegistry(address(moduleRegistry)).moduleInfo(gate) returns (
            IStreamMintModuleRegistry.MintModuleInfo memory moduleInfo
        ) {
            info = moduleInfo;
        } catch {
            revert IStreamMintManager.MintGateNotActive(gate);
        }
        if (
            info.status != IStreamMintModuleRegistry.ModuleStatus.ACTIVE
                || info.interfaceId != type(IStreamMintGate).interfaceId || info.gasLimit == 0
                || gate.code.length == 0 || info.codehash != gate.codehash
                || !_gateAdvertisesInterface(gate)
        ) {
            revert IStreamMintManager.MintGateNotActive(gate);
        }
    }

    function _canonicalGateInfo(IStreamModuleRegistry registry, address gate)
        private
        view
        returns (IStreamMintModuleRegistry.MintModuleInfo memory info)
    {
        StreamModuleRecord memory record = registry.moduleRecord(gate);
        if (
            record.status != ModuleRegistryStatus.ACTIVE
                || record.moduleType != MINT_GATE_MODULE_TYPE
                || record.interfaceId != type(IStreamMintGate).interfaceId
                || record.moduleGasLimit == 0 || record.moduleVersion == bytes32(0)
                || record.moduleManifestHash == bytes32(0) || record.revision == 0
                || gate.code.length == 0 || record.runtimeCodeHash != gate.codehash
                || !_gateAdvertisesInterface(gate)
        ) revert IStreamMintManager.MintGateNotActive(gate);
        // Preserve the existing phase ABI without truncating the canonical bytes32 version.
        // Both full commitments are pinned into the phase's metadata-identity field.
        info = IStreamMintModuleRegistry.MintModuleInfo({
            status: IStreamMintModuleRegistry.ModuleStatus.ACTIVE,
            interfaceId: record.interfaceId,
            semanticVersion: 0,
            codehash: record.runtimeCodeHash,
            metadataHash: keccak256(abi.encode(record.moduleVersion, record.moduleManifestHash)),
            gasLimit: record.moduleGasLimit
        });
    }

    function _supports(IERC165 target, bytes4 interfaceId) private view returns (bool) {
        try target.supportsInterface{ gas: GATE_ERC165_PROBE_GAS }(interfaceId) returns (
            bool supported
        ) {
            return supported;
        } catch {
            return false;
        }
    }

    function _gateAdvertisesInterface(address gate) private view returns (bool) {
        try IERC165(gate).supportsInterface{ gas: GATE_ERC165_PROBE_GAS }(
            type(IStreamMintGate).interfaceId
        ) returns (
            bool supported
        ) {
            return supported;
        } catch {
            return false;
        }
    }
}
