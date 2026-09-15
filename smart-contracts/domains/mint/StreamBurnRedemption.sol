// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamBurnRedemption as R } from "../../interfaces/stream/mint/IStreamBurnRedemption.sol";
import { IStreamCoreIdentity } from "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import { IStreamCoreBurn } from "../../interfaces/stream/core/IStreamCoreBurn.sol";
import { IStreamCorePointers } from "../../interfaces/stream/core/IStreamCorePointers.sol";
import {
    IStreamCoreCollectionView
} from "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import {
    IStreamModuleRegistry,
    StreamModuleRecord,
    ModuleRegistryStatus
} from "../../interfaces/stream/modules/IStreamModuleRegistry.sol";
import {
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import { IERC721 } from "../../vendor/openzeppelin/IERC721.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import { Ownable } from "../../vendor/openzeppelin/Ownable.sol";
import { ReentrancyGuard } from "../../vendor/openzeppelin/ReentrancyGuard.sol";
import { StreamModuleBase } from "../modules/StreamModuleBase.sol";
import { StreamGasParameterHost } from "../parameters/StreamGasParameterHost.sol";

/// @notice Burns native Stream tokens for an append-only offchain fulfillment record.
/// @dev The operator configures terms and reports fulfillment. Neither action certifies
///      physical delivery. No token, payment, mint, or refund custody exists in this host.
contract StreamBurnRedemption is
    R,
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
    }

    bytes32 public constant DEPENDENCY_READ_GAS =
        keccak256("6529STREAM_GGP_BURN_DEPENDENCY_READ_GAS");
    bytes32 public constant BURN_GAS = keccak256("6529STREAM_GGP_BURN_EXECUTION_GAS");
    address public immutable override core;
    address public immutable moduleRegistry;
    bytes32 public immutable coreCodeHash;
    bytes32 public immutable registryCodeHash;
    uint256 public nextSaleNonce = 1;
    mapping(bytes32 => Program) private _programs;
    mapping(bytes32 => Redemption) private _redemptions;
    mapping(bytes32 => Fulfillment[]) private _updates;
    mapping(bytes32 => bytes32[]) private _programRedemptions;

    constructor(Configuration memory c)
        StreamModuleBase(
            keccak256("6529STREAM_BURN_REDEMPTION_SCHEMA_V1"),
            address(0),
            c.deploymentManifestHash,
            c.moduleManifestURI,
            c.moduleManifestHash
        )
        StreamGasParameterHost(c.governance)
    {
        if (
            c.core.code.length == 0 || c.registry.code.length == 0 || c.governance == address(0)
                || c.operator == address(0) || c.deploymentManifestHash == 0
                || c.moduleManifestHash == 0 || bytes(c.moduleManifestURI).length == 0
                || bytes(c.moduleManifestURI).length > 2048
                || c.dependencyReadGas.failureClass != FAILURE_CLASS_FAIL_CLOSED_PRECHECK
                || c.burnGas.failureClass != FAILURE_CLASS_FAIL_CLOSED_PRECHECK
                || _registerGasParameter(c.dependencyReadGas) != DEPENDENCY_READ_GAS
                || _registerGasParameter(c.burnGas) != BURN_GAS
        ) revert InvalidRedemptionConfiguration();
        _validURI(c.moduleManifestURI);
        core = c.core;
        moduleRegistry = c.registry;
        coreCodeHash = c.core.codehash;
        registryCodeHash = c.registry.codehash;
        _transferOwnership(c.operator);
    }

    function streamModuleType() public pure override returns (bytes32) {
        return keccak256("BURN_REDEMPTION_ADAPTER");
    }

    function streamModuleVersion() public pure override returns (bytes32) {
        return keccak256("6529stream.burn-redemption.v1");
    }

    function streamModuleInterfaceId() public pure override returns (bytes4) {
        return type(R).interfaceId;
    }

    function supportsInterface(bytes4 id)
        public
        view
        override(StreamModuleBase, IERC165)
        returns (bool)
    {
        return id == type(R).interfaceId || id == type(IStreamGasParameterHost).interfaceId
            || super.supportsInterface(id);
    }

    function registerProgram(ProgramConfig calldata c)
        external
        override
        onlyOwner
        nonReentrant
        returns (bytes32 id)
    {
        if (
            c.collectionId == 0 || c.termsHash == 0 || c.startTime < block.timestamp
                || c.endTime <= c.startTime || block.timestamp == 0
                || block.timestamp > type(uint64).max
        ) {
            revert InvalidRedemptionProgram();
        }
        uint64 revision = _admission(0, 0);
        if (!abi.decode(
                _read(
                    core,
                    abi.encodeCall(IStreamCoreCollectionView.collectionExists, (c.collectionId)),
                    32
                ),
                (bool)
            )) {
            revert InvalidRedemptionProgram();
        }
        uint256 nonce = nextSaleNonce++;
        id = keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_V1"),
                block.chainid,
                address(this),
                uint8(9),
                c.collectionId,
                bytes32(0),
                nonce
            )
        );
        // Kind9 has no mint phase, price, asset or primary-settlement policy. Their canonical
        // zero values are explicit in both the commitment and the common SaleConfigured event.
        bytes32 hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_BURN_REDEMPTION_CONFIG_V1"),
                block.chainid,
                address(this),
                core,
                id,
                nonce,
                uint8(9),
                c,
                bytes32(0),
                address(0),
                uint256(0),
                bytes32(0),
                uint8(0),
                bytes32(0)
            )
        );
        _programs[id] = Program(c, hash, nonce, uint64(block.timestamp), revision, false);
        emit SaleConfigured(1, id, c.collectionId, 0, 9, address(0), hash, 0, 0);
        emit RedemptionTermsRecorded(1, id, c.termsHash, c.startTime, c.endTime, nonce, msg.sender);
    }

    function cancelProgram(bytes32 id) external override onlyOwner nonReentrant {
        Program storage p = _knownProgram(id);
        if (p.cancelled) revert RedemptionProgramClosed(id);
        p.cancelled = true;
        emit RedemptionProgramCancelled(1, id);
    }

    function program(bytes32 id) external view override returns (Program memory) {
        return _knownProgram(id);
    }

    function redeem(
        bytes32 id,
        uint256 tokenId,
        bytes32 terms,
        bytes32 referenceHash,
        string calldata uri
    ) external override nonReentrant returns (bytes32 redemptionId) {
        Program storage p = _knownProgram(id);
        if (
            p.cancelled || block.timestamp < p.config.startTime
                || block.timestamp > p.config.endTime
        ) {
            revert RedemptionProgramClosed(id);
        }
        if (terms != p.config.termsHash || referenceHash == 0) revert RedemptionTermsMismatch();
        _validURI(uri);
        _admission(p.createdAt, p.registryRevision);
        if (block.timestamp > type(uint64).max) revert InvalidRedemptionProgram();
        (bool exists, uint256 collectionId, uint256 serial, bool burned) = _identity(tokenId);
        if (!exists || burned || collectionId != p.config.collectionId) {
            revert RedemptionTokenInvalid(tokenId);
        }
        address tokenOwner =
            abi.decode(_read(core, abi.encodeCall(IERC721.ownerOf, (tokenId)), 32), (address));
        address approved =
            abi.decode(_read(core, abi.encodeCall(IERC721.getApproved, (tokenId)), 32), (address));
        if (tokenOwner == address(0)) revert RedemptionTokenInvalid(tokenId);
        if (
            msg.sender != tokenOwner && msg.sender != approved
                && !_approvedForAll(tokenOwner, msg.sender)
        ) {
            revert RedemptionAuthorityRequired(tokenId);
        }
        // This executor needs its own approval even when the caller is an approved operator.
        if (approved != address(this) && !_approvedForAll(tokenOwner, address(this))) {
            revert RedemptionAuthorityRequired(tokenId);
        }
        redemptionId = redemptionIdFor(tokenId);
        if (_redemptions[redemptionId].redeemer != address(0)) {
            revert RedemptionTokenInvalid(tokenId);
        }
        _redemptions[redemptionId] = Redemption(
            id,
            tokenId,
            collectionId,
            serial,
            msg.sender,
            tokenOwner,
            terms,
            referenceHash,
            uri,
            uint64(block.timestamp)
        );
        _programRedemptions[id].push(redemptionId);
        uint256 cap = _gasParameterValue(BURN_GAS);
        _requireGas(cap);
        bytes memory input = abi.encodeCall(IStreamCoreBurn.burn, (tokenId));
        address target = core;
        bool ok;
        assembly ("memory-safe") { ok := call(cap, target, 0, add(input, 32), mload(input), 0, 0) }
        if (!ok) revert RedemptionBurnFailed(tokenId);
        (bool afterExists, uint256 afterCollection, uint256 afterSerial, bool afterBurn) =
            _identity(tokenId);
        if (!afterExists || !afterBurn || afterCollection != collectionId || afterSerial != serial)
        {
            revert RedemptionTokenInvalid(tokenId);
        }
        emit RedemptionRecorded(
            1, redemptionId, tokenId, collectionId, msg.sender, referenceHash, uri
        );
        emit RedemptionContextRecorded(1, redemptionId, id, _redemptions[redemptionId]);
    }

    function redemptionIdFor(uint256 tokenId) public view override returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_REDEMPTION_V1"), block.chainid, address(this), core, tokenId
            )
        );
    }

    function redemption(bytes32 id) external view override returns (Redemption memory) {
        return _knownRedemption(id);
    }

    function recordFulfillment(bytes32 id, bytes32 referenceHash, string calldata uri)
        external
        override
        onlyOwner
        nonReentrant
        returns (bytes32 hash)
    {
        Redemption storage r = _knownRedemption(id);
        Program storage p = _programs[r.saleId];
        _validURI(uri);
        _admission(p.createdAt, p.registryRevision);
        if (referenceHash == 0 || block.timestamp > type(uint64).max) {
            revert InvalidRedemptionProgram();
        }
        Fulfillment[] storage updates = _updates[id];
        bytes32 previous = updates.length == 0 ? bytes32(0) : updates[updates.length - 1].updateHash;
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_REDEMPTION_FULFILLMENT_V1"),
                block.chainid,
                address(this),
                id,
                updates.length,
                previous,
                referenceHash,
                keccak256(bytes(uri)),
                msg.sender,
                uint64(block.timestamp)
            )
        );
        updates.push(
            Fulfillment(referenceHash, uri, previous, hash, msg.sender, uint64(block.timestamp))
        );
        emit RedemptionFulfilled(1, id, referenceHash, uri);
        emit RedemptionFulfillmentContext(1, id, updates.length - 1, updates[updates.length - 1]);
    }

    function fulfillmentCount(bytes32 id) external view override returns (uint256) {
        return _updates[id].length;
    }

    function fulfillmentAt(bytes32 id, uint256 i)
        external
        view
        override
        returns (Fulfillment memory)
    {
        if (i >= _updates[id].length) revert RedemptionIndexOutOfBounds();
        return _updates[id][i];
    }

    function redemptionCount(bytes32 id) external view override returns (uint256) {
        return _programRedemptions[id].length;
    }

    function redemptionAt(bytes32 id, uint256 i) external view override returns (bytes32) {
        if (i >= _programRedemptions[id].length) revert RedemptionIndexOutOfBounds();
        return _programRedemptions[id][i];
    }

    function _validURI(string memory uri) private pure {
        bytes memory raw = bytes(uri);
        if (raw.length > 2048) revert InvalidRedemptionProgram();
        if (raw.length == 0) return; // A hash-only private reference has no public URI.
        bool scheme = (raw.length > 8 && keccak256(_prefix(raw, 8)) == keccak256("https://"))
            || (raw.length > 7 && keccak256(_prefix(raw, 7)) == keccak256("ipfs://"))
            || (raw.length > 5 && keccak256(_prefix(raw, 5)) == keccak256("ar://"));
        if (!scheme) revert InvalidRedemptionProgram();
        for (uint256 i; i < raw.length; ++i) {
            if (uint8(raw[i]) <= 32 || uint8(raw[i]) >= 127) revert InvalidRedemptionProgram();
        }
    }

    function _prefix(bytes memory value, uint256 size) private pure returns (bytes memory result) {
        result = new bytes(size);
        for (uint256 i; i < size; ++i) {
            result[i] = value[i];
        }
    }

    function _knownProgram(bytes32 id) private view returns (Program storage p) {
        p = _programs[id];
        if (p.saleNonce == 0) revert InvalidRedemptionProgram();
    }

    function _knownRedemption(bytes32 id) private view returns (Redemption storage r) {
        r = _redemptions[id];
        if (r.redeemer == address(0)) revert UnknownRedemption(id);
    }

    function _approvedForAll(address owner_, address operator) private view returns (bool) {
        return abi.decode(
            _read(core, abi.encodeCall(IERC721.isApprovedForAll, (owner_, operator)), 32), (bool)
        );
    }

    function _identity(uint256 tokenId) private view returns (bool, uint256, uint256, bool) {
        _code(core, coreCodeHash);
        return abi.decode(
            _read(
                core, abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (tokenId)), 128
            ),
            (bool, uint256, uint256, bool)
        );
    }

    function _admission(uint64 createdAt, uint64 revision) private view returns (uint64) {
        _code(core, coreCodeHash);
        _code(moduleRegistry, registryCodeHash);
        bytes memory ptr = _read(
            core,
            abi.encodeCall(IStreamCorePointers.getSatellitePointer, (keccak256("MODULE_REGISTRY"))),
            320
        );
        (address selected, bytes32 hash,,,,,,,,) = abi.decode(
            ptr, (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
        );
        if (selected != moduleRegistry || hash != registryCodeHash) {
            revert RedemptionModuleNotAdmitted();
        }
        // Registry URI is bounded to its canonical2048-byte ceiling. Check the complete ABI,
        // including dynamic offsets and padding, rather than trusting a partial struct prefix.
        bytes memory raw = _readVariable(
            moduleRegistry,
            abi.encodeCall(IStreamModuleRegistry.moduleRecord, (address(this))),
            2496
        );
        StreamModuleRecord memory m = abi.decode(raw, (StreamModuleRecord));
        if (
            keccak256(raw) != keccak256(abi.encode(m))
                || (m.status != ModuleRegistryStatus.ACTIVE
                    && m.status != ModuleRegistryStatus.DEPRECATED)
                || m.moduleType != streamModuleType() || m.moduleVersion != streamModuleVersion()
                || m.interfaceId != type(R).interfaceId
                || m.runtimeCodeHash != address(this).codehash
                || m.deploymentManifestHash != streamModuleDeploymentManifestHash()
                || m.moduleManifestHash == 0 || m.registeredAt == 0
                || m.registeredAt > block.timestamp || m.statusUpdatedAt < m.registeredAt
                || m.statusUpdatedAt > block.timestamp || m.revision == 0
        ) revert RedemptionModuleNotAdmitted();
        (, bytes32 manifestHash) = streamModuleManifest();
        if (m.moduleManifestHash != manifestHash) revert RedemptionModuleNotAdmitted();
        if (createdAt == 0) {
            if (revision != 0 || m.status != ModuleRegistryStatus.ACTIVE) {
                revert RedemptionModuleNotAdmitted();
            }
        } else if (
            createdAt < m.registeredAt || createdAt > block.timestamp || revision == 0
                || revision > m.revision
                || (m.status == ModuleRegistryStatus.DEPRECATED
                    && (createdAt >= m.statusUpdatedAt || revision >= m.revision))
        ) {
            revert RedemptionModuleNotAdmitted();
        }
        return m.revision;
    }

    function _code(address target, bytes32 hash) private view {
        if (target.code.length == 0 || target.codehash != hash) {
            revert RedemptionDependencyChanged(target);
        }
    }

    function _requireGas(uint256 cap) private view {
        uint256 available = gasleft();
        if (
            available < 40000 || available - 40000 < cap
                || available - 40000 - cap < cap / 63 + (cap % 63 == 0 ? 0 : 1)
        ) {
            revert RedemptionReadFailed(core);
        }
    }

    function _read(address target, bytes memory input, uint256 size)
        private
        view
        returns (bytes memory data)
    {
        data = _readVariable(target, input, size);
        if (data.length != size) revert RedemptionReadFailed(target);
    }

    function _readVariable(address target, bytes memory input, uint256 maximum)
        private
        view
        returns (bytes memory data)
    {
        uint256 cap = _gasParameterValue(DEPENDENCY_READ_GAS);
        _requireGas(cap);
        data = new bytes(maximum);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(data, 32), maximum)
            size := returndatasize()
        }
        if (!ok || size > maximum) revert RedemptionReadFailed(target);
        assembly ("memory-safe") { mstore(data, size) }
    }
}
