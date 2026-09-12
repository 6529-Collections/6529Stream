// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import "../../interfaces/stream/parameters/IStreamGovernedParameterAuthority.sol";
import "./StreamSchemaDocumentStore.sol";

/// @notice Governance-approved schema, canonicalization, catalog and dependency bytes.
/// @dev JSON and ontology meaning are validated by the pinned publication tooling. This host
///      verifies exact retained bytes, immutable identity/lineage and executing governance.
contract StreamSchemaRegistry is IStreamSchemaRegistry {
    uint256 public constant MAX_DOCUMENT_CHUNKS = 64;
    uint256 public constant CHUNK_BYTES = 8192;
    uint256 public constant MAX_DOCUMENT_BYTES = MAX_DOCUMENT_CHUNKS * CHUNK_BYTES;
    bytes32 public constant RAW_BYTES = keccak256("RAW_BYTES");
    string public constant RAW_BYTES_DEFINITION =
        '{"name":"RAW_BYTES","rule":"Do not transform the supplied bytes.","version":1}';
    bytes32 private constant _SCOPE = keccak256("6529STREAM_SCHEMA_DOCUMENT_SCOPE_V1");
    bytes32 private constant _STATE = keccak256("6529STREAM_SCHEMA_DOCUMENT_STATE_V1");
    address public immutable override governanceAuthority;
    bytes32 public immutable governanceAuthorityCodeHash;
    address public immutable override chunkStore;

    struct PayloadPointer {
        address pointer;
        bytes32 family;
        bytes32 hash;
    }
    mapping(bytes32 => DocumentView) private _documents;
    bytes32[] private _ids;
    PayloadPointer[] private _pointers;
    mapping(bytes32 => bool) private _acceptedPointers;

    constructor(address executor) {
        if (
            executor.code.length == 0
                || !IStreamGovernedParameterAuthority(executor).isStreamGovernedParameterAuthority()
        ) {
            revert UnauthorizedDocumentGovernance();
        }
        governanceAuthority = executor;
        governanceAuthorityCodeHash = executor.codehash;
        chunkStore = address(new StreamSchemaDocumentStore());
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IStreamSchemaRegistry).interfaceId || id == 0x01ffc9a7;
    }

    function registerDocument(DocumentSpec calldata specification, bytes32[] calldata chunkHashes)
        external
        override
        returns (bytes32 documentId)
    {
        documentId = keccak256(bytes(specification.name));
        _validateSpecification(specification, documentId);
        if (_documents[documentId].exists) revert DocumentAlreadyRegistered(documentId);
        _validatePayload(specification, chunkHashes);
        bytes32 declaration = keccak256(abi.encode(specification, chunkHashes));
        bytes32 actionId = _governed(
            _scope(documentId),
            _state(false, 0, DocumentStatus.ACTIVE),
            _state(true, declaration, DocumentStatus.ACTIVE)
        );
        DocumentView storage row = _documents[documentId];
        row.exists = true;
        row.declarationHash = declaration;
        row.specification = specification;
        row.chunkHashes = chunkHashes;
        _ids.push(documentId);
        bytes32 family =
            keccak256(abi.encode("STREAM_INTERPRETATION_DOCUMENT_CHUNK_V1", specification.kind));
        for (uint256 i; i < chunkHashes.length; ++i) {
            bytes32 key = keccak256(abi.encode(family, chunkHashes[i]));
            if (_acceptedPointers[key]) continue;
            _acceptedPointers[key] = true;
            (address pointer,) = StreamSchemaDocumentStore(chunkStore).chunk(chunkHashes[i]);
            _pointers.push(PayloadPointer(pointer, family, chunkHashes[i]));
        }
        emit DocumentRegistered(
            1,
            documentId,
            specification.contentHash,
            actionId,
            declaration,
            specification,
            chunkHashes
        );
    }

    function setDocumentStatus(bytes32 documentId, DocumentStatus next) external override {
        DocumentView storage row = _documents[documentId];
        if (!row.exists) revert DocumentUnknown(documentId);
        if (documentId == RAW_BYTES || uint8(next) <= uint8(row.status)) {
            revert InvalidDocumentStatus();
        }
        bytes32 actionId = _governed(
            _scope(documentId),
            _state(true, row.declarationHash, row.status),
            _state(true, row.declarationHash, next)
        );
        DocumentStatus previous = row.status;
        row.status = next;
        emit DocumentStatusChanged(1, documentId, previous, next, actionId);
    }

    function document(bytes32 id) external view override returns (DocumentView memory) {
        return _documents[id];
    }

    function documentBytes(bytes32 id) external view override returns (bytes memory payload) {
        DocumentView storage row = _documents[id];
        if (!row.exists) revert DocumentUnknown(id);
        payload = _assemble(row.chunkHashes, row.specification.totalBytes);
        bytes32 actual = keccak256(payload);
        if (actual != row.specification.contentHash) {
            revert DocumentHashMismatch(row.specification.contentHash, actual);
        }
    }

    function documentCount() external view override returns (uint256) {
        return _ids.length;
    }

    function documentIdAt(uint256 index) external view override returns (bytes32) {
        return _ids[index];
    }

    function payloadPointerCount(uint256 scopeKey) external view override returns (uint256) {
        if (scopeKey != 0) revert InvalidDocumentScope(scopeKey);
        return _pointers.length;
    }

    function payloadPointerAt(uint256 scopeKey, uint256 index)
        external
        view
        override
        returns (address pointer, bytes32 payloadFamily, bytes32 contentHash)
    {
        if (scopeKey != 0) revert InvalidDocumentScope(scopeKey);
        PayloadPointer storage row = _pointers[index];
        return (row.pointer, row.family, row.hash);
    }

    function registrationTransition(
        DocumentSpec calldata specification,
        bytes32[] calldata chunkHashes
    ) external view override returns (bytes32, bytes32, bytes32) {
        bytes32 id = keccak256(bytes(specification.name));
        _validateSpecification(specification, id);
        if (_documents[id].exists) revert DocumentAlreadyRegistered(id);
        _validatePayload(specification, chunkHashes);
        return (
            _scope(id),
            _state(false, 0, DocumentStatus.ACTIVE),
            _state(true, keccak256(abi.encode(specification, chunkHashes)), DocumentStatus.ACTIVE)
        );
    }

    function statusTransition(bytes32 id, DocumentStatus next)
        external
        view
        override
        returns (bytes32, bytes32, bytes32)
    {
        DocumentView storage row = _documents[id];
        if (!row.exists) revert DocumentUnknown(id);
        if (id == RAW_BYTES || uint8(next) <= uint8(row.status)) revert InvalidDocumentStatus();
        return (
            _scope(id),
            _state(true, row.declarationHash, row.status),
            _state(true, row.declarationHash, next)
        );
    }

    function _validateSpecification(DocumentSpec calldata spec, bytes32 id) private view {
        bytes memory name = bytes(spec.name);
        if (
            name.length == 0 || name.length > 128 || spec.contentHash == bytes32(0)
                || bytes(spec.uri).length > 2048 || spec.totalBytes == 0
                || spec.totalBytes > MAX_DOCUMENT_BYTES
        ) {
            revert InvalidDocument();
        }
        for (uint256 i; i < name.length; ++i) {
            bytes1 c = name[i];
            if (!((c >= 0x41 && c <= 0x5a) || (c >= 0x61 && c <= 0x7a) || (c >= 0x30 && c <= 0x39)
                        || c == 0x5f || c == 0x2d || c == 0x2e)) revert InvalidDocument();
        }
        if (id == RAW_BYTES) {
            // The one bootstrap definition has fixed bytes and cannot shadow another kind.
            if (
                spec.kind != DocumentKind.CANONICALIZATION || spec.canonicalizationId != RAW_BYTES
                    || spec.supersedesId != 0
                    || spec.contentHash != keccak256(bytes(RAW_BYTES_DEFINITION))
            ) {
                revert InvalidCanonicalization(spec.canonicalizationId);
            }
        } else {
            DocumentView storage canonical = _documents[spec.canonicalizationId];
            if (
                !canonical.exists || canonical.specification.kind != DocumentKind.CANONICALIZATION
                    || canonical.status != DocumentStatus.ACTIVE
            ) revert InvalidCanonicalization(spec.canonicalizationId);
        }
        if (
            spec.supersedesId != 0
                && (spec.supersedesId == id
                    || !_documents[spec.supersedesId].exists
                    || _documents[spec.supersedesId].specification.kind != spec.kind)
        ) {
            revert InvalidDocumentPredecessor(spec.supersedesId);
        }
    }

    function _validatePayload(DocumentSpec calldata spec, bytes32[] calldata hashes) private view {
        bytes32 actual = keccak256(_assemble(hashes, spec.totalBytes));
        if (actual != spec.contentHash) revert DocumentHashMismatch(spec.contentHash, actual);
    }

    function _assemble(bytes32[] memory hashes, uint256 total)
        private
        view
        returns (bytes memory payload)
    {
        if (
            hashes.length == 0 || hashes.length > MAX_DOCUMENT_CHUNKS || total == 0
                || total > MAX_DOCUMENT_BYTES
        ) revert InvalidDocument();
        payload = new bytes(total);
        uint256 offset;
        for (uint256 i; i < hashes.length; ++i) {
            bytes memory part = StreamSchemaDocumentStore(chunkStore).readChunk(hashes[i]);
            if (
                part.length == 0 || part.length > CHUNK_BYTES
                    || (i + 1 < hashes.length && part.length != CHUNK_BYTES)
                    || offset + part.length > total
            ) revert InvalidDocument();
            // The final word may include allocation padding, never bytes beyond the payload's length.
            assembly ("memory-safe") {
                let length := mload(part)
                let source := add(part, 32)
                let destination := add(add(payload, 32), offset)
                for { let j := 0 } lt(j, length) { j := add(j, 32) } {
                    mstore(add(destination, j), mload(add(source, j)))
                }
            }
            offset += part.length;
        }
        if (offset != total) revert InvalidDocument();
    }

    function _scope(bytes32 id) private view returns (bytes32) {
        return keccak256(abi.encode(_SCOPE, block.chainid, address(this), id));
    }

    function _state(bool exists, bytes32 declaration, DocumentStatus status)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_STATE, exists, declaration, status));
    }

    function _governed(bytes32 scope, bytes32 oldHash, bytes32 newHash)
        private
        view
        returns (bytes32 id)
    {
        if (msg.sender != governanceAuthority || msg.sender.codehash != governanceAuthorityCodeHash)
        {
            revert UnauthorizedDocumentGovernance();
        }
        (
            bool executing,
            bytes32 actionId,
            uint8 actionClass,
            bytes32 actualScope,
            bytes32 actualOld,
            bytes32 actualNew
        ) = IStreamGovernedParameterAuthority(governanceAuthority).currentAction();
        if (
            !executing || actionId == 0 || actionClass != 1 || actualScope != scope
                || actualOld != oldHash || actualNew != newHash
        ) {
            revert UnauthorizedDocumentGovernance();
        }
        return actionId;
    }
}
