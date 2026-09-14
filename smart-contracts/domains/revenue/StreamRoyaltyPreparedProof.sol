// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamCorePointers } from "../../interfaces/stream/core/IStreamCorePointers.sol";
import {
    IStreamCoreMint,
    StreamPreparedMintRecord
} from "../../interfaces/stream/core/IStreamCoreMint.sol";
import { IStreamCoreIdentity } from "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import { IStreamModuleRegistry } from "../../interfaces/stream/modules/IStreamModuleRegistry.sol";
import { IStreamMintManager } from "../../interfaces/stream/mint/IStreamMintManager.sol";
import { IStreamMintLedger } from "../../interfaces/stream/mint/IStreamMintLedger.sol";
import { IStreamRoyaltyResolver } from "../../interfaces/stream/revenue/IStreamRoyaltyResolver.sol";

/// @notice Current selected identities and the original active prepared-mint proof.
/// @dev Fixed linked code executes in the actual royalty resolver. This authenticates proof only;
/// mode, phase authorization, Artist consent and snapshot state are the calling worker's duties.
library StreamRoyaltyPreparedProof {
    struct Request {
        address core;
        bytes32 coreRuntimeHash;
        uint256 collectionId;
        uint256 tokenId;
        bytes32 operationRoot;
        bytes32 operationId;
    }

    struct Pointer {
        address target;
        bytes32 runtimeHash;
        bool frozen;
        bytes32 moduleType;
        bytes4 interfaceId;
        address registry;
        uint8 status;
        bytes32 moduleManifest;
        bytes32 deploymentManifest;
        uint64 revision;
    }

    error InvalidRoyaltyPreparedProof();
    error RoyaltyPreparedRead(address target, bytes4 selector);

    /// @dev Repeating this around external economics checks verifies identical current proof.
    function requireCurrent(Request memory r) public view returns (bytes32 proofHash) {
        if (
            r.core.code.length == 0 || r.coreRuntimeHash == 0
                || r.core.codehash != r.coreRuntimeHash || r.collectionId == 0 || r.tokenId == 0
                || r.operationRoot == 0 || r.operationId == 0
        ) revert InvalidRoyaltyPreparedProof();
        Pointer memory registry = _pointer(r.core, keccak256("MODULE_REGISTRY"));
        _shape(
            registry,
            registry.target,
            keccak256("MODULE_REGISTRY"),
            type(IStreamModuleRegistry).interfaceId
        );
        Pointer memory manager = _pointer(r.core, keccak256("MINT_MANAGER"));
        Pointer memory ledger = _pointer(r.core, keccak256("MINT_LEDGER"));
        Pointer memory resolver = _pointer(r.core, keccak256("ROYALTY_RESOLVER"));
        _active(
            registry.target,
            manager,
            keccak256("MINT_MANAGER"),
            type(IStreamMintManager).interfaceId
        );
        _active(
            registry.target, ledger, keccak256("MINT_LEDGER"), type(IStreamMintLedger).interfaceId
        );
        // Core's royalty pointer deliberately selects the REVENUE_RESOLVER module family.
        _active(
            registry.target,
            resolver,
            keccak256("REVENUE_RESOLVER"),
            type(IStreamRoyaltyResolver).interfaceId
        );
        if (
            msg.sender != manager.target || address(this) != resolver.target
                || _address(manager.target, "core()") != r.core
                || _address(manager.target, "moduleRegistry()") != registry.target
                || _address(manager.target, "mintLedger()") != ledger.target
                || !_boolean(
                    ledger.target, abi.encodeCall(IStreamMintLedger.ledgerWriter, (manager.target))
                )
                || !_boolean(
                    ledger.target,
                    abi.encodeCall(
                        IStreamMintLedger.isManagerOperationRootUsed,
                        (manager.target, r.operationRoot)
                    )
                )
        ) revert InvalidRoyaltyPreparedProof();
        StreamPreparedMintRecord memory prepared = abi.decode(
            _read(r.core, abi.encodeCall(IStreamCoreMint.preparedMint, (r.tokenId)), 96),
            (StreamPreparedMintRecord)
        );
        (bool exists, uint256 collectionId, uint256 serial, bool burned) = abi.decode(
            _read(
                r.core,
                abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (r.tokenId)),
                128
            ),
            (bool, uint256, uint256, bool)
        );
        if (
            !prepared.exists || prepared.operationId != r.operationId
                || prepared.collectionId != r.collectionId || !exists || burned
                || collectionId != r.collectionId || serial == 0
                || abi.decode(
                        _read(r.core, abi.encodeWithSignature("pendingPreparedMintTokenId()"), 32),
                        (uint256)
                    ) != r.tokenId
        ) revert InvalidRoyaltyPreparedProof();
        proofHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROYALTY_PREPARED_PROOF_V1"),
                block.chainid,
                address(this),
                msg.sender,
                r,
                registry,
                manager,
                ledger,
                resolver,
                serial
            )
        );
    }

    function _pointer(address core, bytes32 key) private view returns (Pointer memory) {
        return abi.decode(
            _read(core, abi.encodeCall(IStreamCorePointers.getSatellitePointer, (key)), 320),
            (Pointer)
        );
    }

    function _shape(Pointer memory p, address registry, bytes32 moduleType, bytes4 interfaceId)
        private
        view
    {
        if (
            p.target.code.length == 0 || p.runtimeHash == 0 || p.target.codehash != p.runtimeHash
                || p.moduleType != moduleType || p.interfaceId != interfaceId
                || p.registry != registry || p.status != 1 || p.moduleManifest == 0
                || p.deploymentManifest == 0 || p.revision == 0
        ) {
            revert InvalidRoyaltyPreparedProof();
        }
    }

    function _active(address registry, Pointer memory p, bytes32 moduleType, bytes4 interfaceId)
        private
        view
    {
        _shape(p, registry, moduleType, interfaceId);
        if (!_boolean(
                registry,
                abi.encodeCall(
                    IStreamModuleRegistry.isModuleEligible, (p.target, moduleType, interfaceId)
                )
            )) revert InvalidRoyaltyPreparedProof();
        // Match the stored Core commitments to the current canonical record, without allocating URI bytes.
        bytes memory data = abi.encodeCall(IStreamModuleRegistry.moduleRecord, (p.target));
        uint256[14] memory words;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), registry, add(data, 32), mload(data), words, 448)
            size := returndatasize()
        }
        if (
            !ok || size < 448 || words[0] != 32 || words[1] != 1 || bytes32(words[2]) != moduleType
                || words[3] == 0 || words[4] != uint256(uint32(interfaceId)) << 224
                || words[5] > type(uint32).max || bytes32(words[6]) != p.runtimeHash
                || bytes32(words[7]) != p.deploymentManifest
                || bytes32(words[8]) != p.moduleManifest || words[9] != 384 || words[10] == 0
                || words[10] > block.timestamp || words[11] < words[10]
                || words[11] > block.timestamp || words[12] == 0 || words[12] > type(uint64).max
                || words[13] > size - 448 || size - 448 != ((words[13] + 31) / 32) * 32
        ) {
            revert InvalidRoyaltyPreparedProof();
        }
    }

    function _address(address target, string memory signature) private view returns (address) {
        return abi.decode(_read(target, abi.encodeWithSignature(signature), 32), (address));
    }

    function _boolean(address target, bytes memory data) private view returns (bool) {
        return abi.decode(_read(target, data, 32), (bool));
    }

    /// @dev Only exact-code current Core/Registry/Manager/Ledger identities reach these reads.
    function _read(address target, bytes memory data, uint256 width)
        private
        view
        returns (bytes memory raw)
    {
        raw = new bytes(width);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), add(raw, 32), width)
            size := returndatasize()
        }
        if (!ok || size != width) revert RoyaltyPreparedRead(target, bytes4(data));
    }
}
