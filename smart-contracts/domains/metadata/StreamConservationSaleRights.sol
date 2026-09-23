// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/IStreamRightsRecordSelection.sol";
import "../../interfaces/stream/metadata/IStreamCollectionRecordReceipts.sol";
import "../../interfaces/stream/metadata/IStreamWorkRecordSelection.sol";
import "../records/StreamRightsRecordDefinitions.sol";
import "./StreamMetadataSubjects.sol";

/// @notice The sale floor's collection RIGHTS input, from its original native record and selector.
/// @dev WORK_DESCRIPTION and finality locks are deliberately separate requirements. This proves
/// only the rights input, never conservation-floor completeness or a legal grant's truth.
library StreamConservationSaleRights {
    struct Dependencies {
        // Core, original Metadata, SchemaRegistry, original byte store, RIGHTS selector.
        address[5] targets;
        bytes32[5] codeHashes;
        uint256 chainId;
        uint256 readGas;
        uint256 selectionGas;
    }

    error InvalidSaleRightsConfiguration();
    error SaleRightsDependency(address dependency);
    error SaleRightsRead(address target, bytes4 selector);
    error SaleRightsSelection(bytes32 recordHash);
    error SaleRightsReceipt(bytes32 recordHash);

    function requireCurrent(Dependencies memory d, uint256 collectionId)
        public
        view
        returns (IStreamRightsRecordSelection.Selection memory selected)
    {
        _bindings(d);
        bytes32 subject = StreamMetadataSubjects.scopeSubject(
            d.chainId,
            d.targets[0],
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, collectionId, 0, 0)
        );
        bytes memory raw = _read(
            d.targets[4],
            abi.encodeCall(IStreamRightsRecordSelection.currentRights, (collectionId, subject)),
            448,
            d.readGas
        );
        selected = abi.decode(raw, (IStreamRightsRecordSelection.Selection));
        if (
            selected.recordHash == 0 || selected.payloadHash == 0 || selected.revision == 0
                || keccak256(raw) != keccak256(abi.encode(selected))
        ) revert SaleRightsSelection(selected.recordHash);
        bytes32 selectionHash = selected.selectionHash;
        selected.selectionHash = 0;
        bytes32 computed = keccak256(
            abi.encode(
                keccak256("6529STREAM_RIGHTS_SELECTION_V1"),
                d.chainId,
                d.targets[4],
                d.targets[0],
                d.targets[1],
                d.targets[2],
                d.targets[3],
                collectionId,
                subject,
                selected
            )
        );
        selected.selectionHash = selectionHash;
        if (selectionHash != computed) revert SaleRightsSelection(selected.recordHash);
        bytes memory current = _read(
            d.targets[4],
            abi.encodeCall(
                IStreamRightsRecordSelection.requireCurrent,
                (collectionId, subject, selected.recordHash, selected.revision)
            ),
            448,
            d.selectionGas
        );
        if (keccak256(raw) != keccak256(current)) revert SaleRightsSelection(selected.recordHash);
        _receipt(d, collectionId, selected);
    }

    function _receipt(
        Dependencies memory d,
        uint256 collectionId,
        IStreamRightsRecordSelection.Selection memory selected
    ) private view {
        bytes memory raw = _read(
            d.targets[1],
            abi.encodeCall(
                IStreamCollectionRecordReceipts.collectionRecordReceipt, (selected.recordHash)
            ),
            288,
            d.readGas
        );
        IStreamCollectionMetadataV1.RecordReceipt memory r =
            abi.decode(raw, (IStreamCollectionMetadataV1.RecordReceipt));
        if (
            keccak256(raw) != keccak256(abi.encode(r)) || r.collectionId != collectionId
                || r.recordIndex != selected.recordIndex || r.recorder != selected.recorder
                || r.authorizationClass != selected.recorderAuthorizationClass
                || r.schemaDefinitionHash != StreamRightsRecordDefinitions.SCHEMA_HASH
                || r.canonicalizationDefinitionHash != StreamRightsRecordDefinitions.CANON_HASH
                || r.recordChainHash == 0 || r.recordedAt == 0
        ) revert SaleRightsReceipt(selected.recordHash);
        bytes memory position = _read(
            d.targets[1],
            abi.encodeCall(
                IStreamCollectionMetadataV1.recordHashAt,
                (collectionId, keccak256("RIGHTS_STATEMENT"), r.recordIndex)
            ),
            32,
            d.readGas
        );
        if (abi.decode(position, (bytes32)) != selected.recordHash) {
            revert SaleRightsReceipt(selected.recordHash);
        }
    }

    function _bindings(Dependencies memory d) private view {
        if (
            block.chainid != d.chainId || d.readGas == 0 || d.selectionGas < d.readGas
                || d.selectionGas > type(uint256).max / 64
        ) revert InvalidSaleRightsConfiguration();
        for (uint256 i; i < 5; ++i) {
            if (d.targets[i].code.length == 0 || d.targets[i].codehash != d.codeHashes[i]) {
                revert SaleRightsDependency(d.targets[i]);
            }
        }
        bytes4[4] memory addressSelectors = [
            IStreamRightsRecordSelection.core.selector,
            IStreamRightsRecordSelection.metadata.selector,
            IStreamRightsRecordSelection.schemaRegistry.selector,
            IStreamRightsRecordSelection.chunkStore.selector
        ];
        // The native RIGHTS and WORK selectors expose the same immutable pin getters.
        bytes4[4] memory hashSelectors = [
            IStreamWorkRecordSelection.coreCodeHash.selector,
            IStreamWorkRecordSelection.metadataCodeHash.selector,
            IStreamWorkRecordSelection.schemaRegistryCodeHash.selector,
            IStreamWorkRecordSelection.chunkStoreCodeHash.selector
        ];
        for (uint256 i; i < 4; ++i) {
            _word(
                d,
                abi.encodeWithSelector(addressSelectors[i]),
                bytes32(uint256(uint160(d.targets[i])))
            );
            _word(d, abi.encodeWithSelector(hashSelectors[i]), d.codeHashes[i]);
        }
        _word(
            d,
            abi.encodeCall(IStreamRightsRecordSelection.deploymentChainId, ()),
            bytes32(d.chainId)
        );
        _word(
            d,
            abi.encodeCall(
                IERC165.supportsInterface, (type(IStreamRightsRecordSelection).interfaceId)
            ),
            bytes32(uint256(1))
        );
        // The exact native selector revalidates selected Core Metadata, source definitions and
        // present association eligibility; historical grants are not reauthorized here.
    }

    function _word(Dependencies memory d, bytes memory input, bytes32 expected) private view {
        if (abi.decode(_read(d.targets[4], input, 32, d.readGas), (bytes32)) != expected) {
            revert SaleRightsDependency(d.targets[4]);
        }
    }

    function _read(address target, bytes memory input, uint256 size, uint256 cap)
        private
        view
        returns (bytes memory raw)
    {
        if (gasleft() <= cap + cap / 63 + 10000) revert SaleRightsRead(target, bytes4(input));
        raw = new bytes(size);
        bool ok;
        uint256 returned;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(raw, 32), size)
            returned := returndatasize()
        }
        if (!ok || returned != size) revert SaleRightsRead(target, bytes4(input));
    }
}
