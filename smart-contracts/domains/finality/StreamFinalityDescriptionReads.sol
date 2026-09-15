// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/finality/StreamFinalityDescriptionTypes.sol";
import "../../interfaces/stream/metadata/IStreamWorkRecordSelection.sol";
import "../../interfaces/stream/metadata/IStreamRightsRecordSelection.sol";
import "../../interfaces/stream/metadata/IStreamCollectionRecordReceipts.sol";
import "../metadata/StreamMetadataSubjects.sol";
import "../records/StreamWorkRecordDefinitions.sol";
import "../records/StreamRightsRecordDefinitions.sol";

/// @notice Joins current WORK and RIGHTS heads to their actual original metadata receipts.
/// @dev The consuming provider supplies constructor-fixed dependencies, including predicted late
///      selector addresses and exact expected runtime hashes. No caller-selected dependency graph,
///      mutable binding phase, collection-to-token inheritance or complete finality claim is added.
library StreamFinalityDescriptionReads {
    struct Dependencies {
        // Core, generic metadata, schemas, byte store, WORK selector, RIGHTS selector.
        address[6] targets;
        bytes32[6] codeHashes;
        uint256 chainId;
        uint256 readGas;
        uint256 selectionGas;
    }

    error DescriptionConfiguration();
    error DescriptionDependency(address target);
    error DescriptionRead(address target, bytes4 selector);
    error DescriptionSelection(address target, bytes32 recordHash);
    error DescriptionReceipt(bytes32 recordHash);

    function requireCurrent(Dependencies memory d, StreamFinalityScope memory scope)
        public
        view
        returns (StreamFinalityDescriptionEvidence memory e)
    {
        _bindings(d);
        e.scopeSubject = StreamMetadataSubjects.scopeSubject(d.chainId, d.targets[0], scope);
        IStreamWorkRecordSelection.Selection memory work =
            _work(d, scope.collectionId, e.scopeSubject);
        IStreamRightsRecordSelection.Selection memory rights =
            _rights(d, scope.collectionId, e.scopeSubject);
        e.workDescriptionRecordHash = work.recordHash;
        e.rightsStatementRecordHash = rights.recordHash;
        e.workPayloadHash = work.payloadHash;
        e.rightsPayloadHash = rights.payloadHash;
        e.workSelectionHash = work.selectionHash;
        e.rightsSelectionHash = rights.selectionHash;
        e.workRevision = work.revision;
        e.rightsRevision = rights.revision;
    }

    function _work(Dependencies memory d, uint256 cid, bytes32 subject)
        private
        view
        returns (IStreamWorkRecordSelection.Selection memory selected)
    {
        bytes memory raw = _read(
            d.targets[4],
            abi.encodeCall(IStreamWorkRecordSelection.currentWork, (cid, subject)),
            1056,
            d.readGas
        );
        selected = abi.decode(raw, (IStreamWorkRecordSelection.Selection));
        if (
            selected.recordHash == 0 || selected.payloadHash == 0 || selected.revision == 0
                || keccak256(raw) != keccak256(abi.encode(selected))
        ) revert DescriptionSelection(d.targets[4], selected.recordHash);
        bytes32 retained = selected.selectionHash;
        selected.selectionHash = 0;
        bytes32 computed = keccak256(
            abi.encode(
                keccak256("6529STREAM_WORK_SELECTION_V1"),
                d.chainId,
                d.targets[4],
                d.targets[0],
                d.targets[1],
                d.targets[2],
                d.targets[3],
                cid,
                subject,
                selected
            )
        );
        selected.selectionHash = retained;
        if (retained != computed) revert DescriptionSelection(d.targets[4], selected.recordHash);
        bytes memory current = _read(
            d.targets[4],
            abi.encodeCall(
                IStreamWorkRecordSelection.requireCurrent,
                (cid, subject, selected.recordHash, selected.revision)
            ),
            1056,
            d.selectionGas
        );
        if (keccak256(current) != keccak256(raw)) {
            revert DescriptionSelection(d.targets[4], selected.recordHash);
        }
        IStreamCollectionMetadataV1.RecordReceipt memory receipt = _receipt(d, selected.recordHash);
        if (
            receipt.collectionId != cid || receipt.recordIndex != selected.recordIndex
                || receipt.recorder != selected.recorder
                || receipt.authorizationClass != selected.recorderAuthorizationClass
                || receipt.recordChainHash != selected.recordChainHash
                || receipt.schemaDefinitionHash != StreamWorkRecordDefinitions.SCHEMA_HASH
                || receipt.canonicalizationDefinitionHash != StreamWorkRecordDefinitions.CANON_HASH
                || receipt.artistAuthorization != selected.artistPublication.attestationRecordHash
        ) revert DescriptionReceipt(selected.recordHash);
    }

    function _rights(Dependencies memory d, uint256 cid, bytes32 subject)
        private
        view
        returns (IStreamRightsRecordSelection.Selection memory selected)
    {
        bytes memory raw = _read(
            d.targets[5],
            abi.encodeCall(IStreamRightsRecordSelection.currentRights, (cid, subject)),
            448,
            d.readGas
        );
        selected = abi.decode(raw, (IStreamRightsRecordSelection.Selection));
        if (
            selected.recordHash == 0 || selected.payloadHash == 0 || selected.revision == 0
                || keccak256(raw) != keccak256(abi.encode(selected))
        ) revert DescriptionSelection(d.targets[5], selected.recordHash);
        bytes32 retained = selected.selectionHash;
        selected.selectionHash = 0;
        bytes32 computed = keccak256(
            abi.encode(
                keccak256("6529STREAM_RIGHTS_SELECTION_V1"),
                d.chainId,
                d.targets[5],
                d.targets[0],
                d.targets[1],
                d.targets[2],
                d.targets[3],
                cid,
                subject,
                selected
            )
        );
        selected.selectionHash = retained;
        if (retained != computed) revert DescriptionSelection(d.targets[5], selected.recordHash);
        bytes memory current = _read(
            d.targets[5],
            abi.encodeCall(
                IStreamRightsRecordSelection.requireCurrent,
                (cid, subject, selected.recordHash, selected.revision)
            ),
            448,
            d.selectionGas
        );
        if (keccak256(current) != keccak256(raw)) {
            revert DescriptionSelection(d.targets[5], selected.recordHash);
        }
        IStreamCollectionMetadataV1.RecordReceipt memory receipt = _receipt(d, selected.recordHash);
        if (
            receipt.collectionId != cid || receipt.recordIndex != selected.recordIndex
                || receipt.recorder != selected.recorder
                || receipt.authorizationClass != selected.recorderAuthorizationClass
                || receipt.schemaDefinitionHash != StreamRightsRecordDefinitions.SCHEMA_HASH
                || receipt.canonicalizationDefinitionHash
                    != StreamRightsRecordDefinitions.CANON_HASH
        ) revert DescriptionReceipt(selected.recordHash);
    }

    function _receipt(Dependencies memory d, bytes32 hash)
        private
        view
        returns (IStreamCollectionMetadataV1.RecordReceipt memory r)
    {
        bytes memory raw = _read(
            d.targets[1],
            abi.encodeCall(IStreamCollectionRecordReceipts.collectionRecordReceipt, (hash)),
            288,
            d.readGas
        );
        r = abi.decode(raw, (IStreamCollectionMetadataV1.RecordReceipt));
        if (keccak256(raw) != keccak256(abi.encode(r))) revert DescriptionReceipt(hash);
    }

    function _bindings(Dependencies memory d) private view {
        if (
            block.chainid != d.chainId || d.readGas == 0 || d.selectionGas < d.readGas
                || d.selectionGas > type(uint256).max / 64
        ) {
            revert DescriptionConfiguration();
        }
        for (uint256 i; i < 6; ++i) {
            if (d.targets[i].code.length == 0 || d.targets[i].codehash != d.codeHashes[i]) {
                revert DescriptionDependency(d.targets[i]);
            }
        }
        bytes4[4] memory addressSelectors = [
            IStreamWorkRecordSelection.core.selector,
            IStreamWorkRecordSelection.metadata.selector,
            IStreamWorkRecordSelection.schemaRegistry.selector,
            IStreamWorkRecordSelection.chunkStore.selector
        ];
        bytes4[4] memory hashSelectors = [
            IStreamWorkRecordSelection.coreCodeHash.selector,
            IStreamWorkRecordSelection.metadataCodeHash.selector,
            IStreamWorkRecordSelection.schemaRegistryCodeHash.selector,
            IStreamWorkRecordSelection.chunkStoreCodeHash.selector
        ];
        for (uint256 i = 4; i < 6; ++i) {
            for (uint256 j; j < 4; ++j) {
                _word(
                    d,
                    i,
                    abi.encodeWithSelector(addressSelectors[j]),
                    bytes32(uint256(uint160(d.targets[j])))
                );
                _word(d, i, abi.encodeWithSelector(hashSelectors[j]), d.codeHashes[j]);
            }
            _word(
                d,
                i,
                abi.encodeCall(IStreamWorkRecordSelection.deploymentChainId, ()),
                bytes32(d.chainId)
            );
            _word(
                d,
                i,
                abi.encodeCall(
                    IERC165.supportsInterface,
                    (i == 4
                            ? type(IStreamWorkRecordSelection).interfaceId
                            : type(IStreamRightsRecordSelection).interfaceId)
                ),
                bytes32(uint256(1))
            );
        }
        // requireCurrent on each original selector verifies its reciprocal metadata/artist graph,
        // selected Core host and complete active definition bytes. Do not replay the old grants.
    }

    function _word(Dependencies memory d, uint256 target, bytes memory input, bytes32 expected)
        private
        view
    {
        if (abi.decode(_read(d.targets[target], input, 32, d.readGas), (bytes32)) != expected) {
            revert DescriptionDependency(d.targets[target]);
        }
    }

    function _read(address target, bytes memory input, uint256 size, uint256 cap)
        private
        view
        returns (bytes memory out)
    {
        out = new bytes(size);
        if (gasleft() <= cap + cap / 63 + 10000) revert DescriptionRead(target, bytes4(input));
        bool ok;
        uint256 returned;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(out, 32), size)
            returned := returndatasize()
        }
        if (!ok || returned != size) revert DescriptionRead(target, bytes4(input));
    }
}
