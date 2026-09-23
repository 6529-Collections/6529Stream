// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../vendor/openzeppelin/IERC165.sol";
import "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import "../../interfaces/stream/core/IStreamCoreEnumeration.sol";
import "../../interfaces/stream/finality/IStreamCollectionTokenInventory.sol";
import "../../interfaces/stream/finality/IStreamCollectionTokenInventorySerialLookup.sol";
import "../parameters/StreamGasParameterHost.sol";

/// @notice Permissionless, serial-checked collection membership for content-root production.
/// @dev Incident aborts leave consumed allocation gaps; burning retains completed identity.
///      Ordinals count completed mints. A bounded Core scan authenticates gaps before indexing.
contract StreamCollectionTokenInventory is
    IStreamCollectionTokenInventory,
    IStreamCollectionTokenInventorySerialLookup,
    StreamGasParameterHost,
    IERC165
{
    address public immutable override core;
    bytes32 public immutable coreCodeHash;
    uint256 public immutable deploymentChainId;
    uint256 public constant MAX_INDEX_BATCH = 256;
    bytes32 public constant CORE_READ_GAS =
        keccak256("6529STREAM_GGP_TOKEN_INVENTORY_CORE_READ_GAS");
    bytes32 public constant INVENTORY_DOMAIN = keccak256("6529STREAM_TOKEN_INVENTORY_V1");
    bytes32 public constant APPEND_DOMAIN = keccak256("6529STREAM_TOKEN_INVENTORY_APPEND_V1");

    mapping(uint256 => uint256[]) private _tokens;
    mapping(uint256 => bytes32) private _prefixHashes;
    mapping(uint256 => mapping(uint256 => uint256)) private _tokensBySerial;
    mapping(uint256 => uint256) private _lastIndexedSerial;
    mapping(uint256 => uint256) private _scanThrough;

    error InventoryScanPrepared(uint256 tokenId);

    constructor(address core_, address executor, GasParameterConfig memory coreReadGas)
        StreamGasParameterHost(executor)
    {
        if (
            core_.code.length == 0 || _registerGasParameter(coreReadGas) != CORE_READ_GAS
                || coreReadGas.failureClass != FAILURE_CLASS_FORWARDING_CAP
        ) revert InvalidInventoryConfiguration();
        core = core_;
        coreCodeHash = core_.codehash;
        deploymentChainId = block.chainid;
        if (
            abi.decode(
                    _read(abi.encodeCall(IERC165.supportsInterface, (bytes4(0x80ac58cd))), 32),
                    (uint256)
                ) != 1
        ) revert InvalidInventoryConfiguration();
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId
            || id == type(IStreamCollectionTokenInventory).interfaceId
            || id == type(IStreamCollectionTokenInventorySerialLookup).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId;
    }

    /// @inheritdoc IStreamCollectionTokenInventory
    function appendCollectionTokens(uint256 collectionId, uint256[] calldata tokenIds)
        external
        override
    {
        _requireCore();
        _requireCollection(collectionId);
        uint256 size = tokenIds.length;
        if (size == 0 || size > MAX_INDEX_BATCH) revert InventoryBatchSize(size);
        uint256[] storage tokens = _tokens[collectionId];
        uint256 serial = _lastIndexedSerial[collectionId];
        uint256 previousTokenId = _scanThrough[collectionId];
        bytes32 prefix = _prefix(collectionId, tokens.length);
        for (uint256 i; i < size; ++i) {
            uint256 tokenId = tokenIds[i];
            ++serial;
            if (tokenId <= previousTokenId) revert InventoryTokenMismatch(tokenId, serial);
            _requireCompletedToken(collectionId, tokenId, serial);
            prefix = keccak256(abi.encode(APPEND_DOMAIN, prefix, serial, tokenId));
            tokens.push(tokenId);
            _tokensBySerial[collectionId][serial] = tokenId;
            emit CollectionTokenIndexed(collectionId, tokenId, serial, prefix);
            previousTokenId = tokenId;
        }
        _prefixHashes[collectionId] = prefix;
        _lastIndexedSerial[collectionId] = serial;
        _scanThrough[collectionId] = previousTokenId;
    }

    /// @notice Scan up to 1..256 allocated global IDs and index every completed target mint.
    /// @dev Starts after the retained cursor and stops at Core's allocation frontier. Unknown
    ///      IDs below that frontier are consumed abort gaps. Other collections may be skipped;
    ///      a prepared target token reverts the whole batch because it could still complete.
    ///      Call repeatedly for sparse collections. Appends and cursor progress are atomic.
    function scanCollectionTokens(uint256 collectionId, uint256 maxScan)
        external
        returns (uint256 scannedThrough, uint256 indexedCount, bytes32 prefixHash)
    {
        _requireCore();
        _requireCollection(collectionId);
        if (maxScan == 0 || maxScan > MAX_INDEX_BATCH) revert InventoryBatchSize(maxScan);
        uint256 frontier = abi.decode(
            _read(abi.encodeCall(IStreamCoreEnumeration.lastAllocatedTokenId, ()), 32), (uint256)
        );
        scannedThrough = _scanThrough[collectionId];
        uint256 serial = _lastIndexedSerial[collectionId];
        uint256[] storage tokens = _tokens[collectionId];
        prefixHash = _prefix(collectionId, tokens.length);
        for (uint256 i; i < maxScan && scannedThrough < frontier; ++i) {
            ++scannedThrough;
            (uint256 actualCollection, uint256 actualSerial, uint256 lifecycle) =
                _identity(scannedThrough, serial + 1);
            if (actualCollection != collectionId) continue;
            if (lifecycle == 1) revert InventoryScanPrepared(scannedThrough);
            if (actualSerial <= serial) {
                revert InventoryTokenMismatch(scannedThrough, serial + 1);
            }
            serial = actualSerial;
            prefixHash = keccak256(abi.encode(APPEND_DOMAIN, prefixHash, serial, scannedThrough));
            tokens.push(scannedThrough);
            _tokensBySerial[collectionId][serial] = scannedThrough;
            emit CollectionTokenIndexed(collectionId, scannedThrough, serial, prefixHash);
        }
        _scanThrough[collectionId] = scannedThrough;
        _lastIndexedSerial[collectionId] = serial;
        _prefixHashes[collectionId] = prefixHash;
        indexedCount = tokens.length;
    }

    /// @notice Highest global ID verified to contain no unindexed completed target mint.
    function collectionScanThrough(uint256 collectionId) external view returns (uint256 tokenId) {
        return _scanThrough[collectionId];
    }

    /// @inheritdoc IStreamCollectionTokenInventorySerialLookup
    function collectionTokenBySerial(uint256 collectionId, uint256 collectionSerial)
        external
        view
        override
        returns (uint256 tokenId)
    {
        return _tokensBySerial[collectionId][collectionSerial];
    }

    /// @inheritdoc IStreamCollectionTokenInventory
    function collectionInventoryState(uint256 collectionId)
        external
        view
        override
        returns (uint256 indexedCount, bytes32 prefixHash)
    {
        indexedCount = _tokens[collectionId].length;
        prefixHash = _prefix(collectionId, indexedCount);
    }

    /// @inheritdoc IStreamCollectionTokenInventory
    function collectionTokenAt(uint256 collectionId, uint256 index)
        external
        view
        override
        returns (uint256 tokenId)
    {
        if (index >= _tokens[collectionId].length) {
            revert InventoryIndexOutOfBounds(collectionId, index);
        }
        return _tokens[collectionId][index];
    }

    /// @inheritdoc IStreamCollectionTokenInventory
    function requireCompleteCollection(uint256 collectionId)
        external
        view
        override
        returns (uint256 tokenCount, bytes32 prefixHash)
    {
        _requireCore();
        _requireCollection(collectionId);
        tokenCount = _tokens[collectionId].length;
        uint256 mintedCount = abi.decode(
            _read(
                abi.encodeCall(IStreamCoreCollectionView.collectionMintedEver, (collectionId)), 32
            ),
            (uint256)
        );
        if (tokenCount != mintedCount) {
            revert InventoryIncomplete(collectionId, tokenCount, mintedCount);
        }
        prefixHash = _prefix(collectionId, tokenCount);
    }

    function _prefix(uint256 collectionId, uint256 count) private view returns (bytes32) {
        return count == 0
            ? keccak256(
                abi.encode(INVENTORY_DOMAIN, deploymentChainId, address(this), core, collectionId)
            )
            : _prefixHashes[collectionId];
    }

    function _requireCore() private view {
        if (core.codehash != coreCodeHash || block.chainid != deploymentChainId) {
            revert InventoryCoreChanged();
        }
    }

    function _requireCollection(uint256 collectionId) private view {
        if (
            collectionId == 0
                || abi.decode(
                        _read(
                            abi.encodeCall(
                                IStreamCoreCollectionView.collectionExists, (collectionId)
                            ),
                            32
                        ),
                        (uint256)
                    ) != 1
        ) revert InventoryCollectionUnknown(collectionId);
    }

    function _requireCompletedToken(uint256 collectionId, uint256 tokenId, uint256 serial)
        private
        view
    {
        (uint256 actualCollection, uint256 actualSerial, uint256 lifecycle) =
            _identity(tokenId, serial);
        if (actualCollection != collectionId || actualSerial != serial || lifecycle < 2) {
            revert InventoryTokenMismatch(tokenId, serial);
        }
    }

    /// @dev Validate the complete Core identity/lifecycle tuple before accepting or skipping it.
    function _identity(uint256 tokenId, uint256 expectedSerial)
        private
        view
        returns (uint256 actualCollection, uint256 actualSerial, uint256 lifecycle)
    {
        uint256 exists;
        uint256 burned;
        (exists, actualCollection, actualSerial, burned) = abi.decode(
            _read(abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (tokenId)), 128),
            (uint256, uint256, uint256, uint256)
        );
        lifecycle = abi.decode(
            _read(abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (tokenId)), 32), (uint256)
        );
        if (
            exists == 0 && actualCollection == 0 && actualSerial == 0 && burned == 0
                && lifecycle == 0
        ) {
            return (0, 0, 0);
        }
        if (
            exists != 1 || actualCollection == 0 || actualSerial == 0
                || !(((lifecycle == 1 || lifecycle == 2) && burned == 0)
                    || (lifecycle == 3 && burned == 1))
        ) revert InventoryTokenMismatch(tokenId, expectedSerial);
    }

    /// @dev Fixed-size output prevents an unexpected dependency from allocating arbitrary memory.
    function _read(bytes memory input, uint256 exactSize)
        private
        view
        returns (bytes memory output)
    {
        output = new bytes(exactSize);
        address target = core;
        uint256 cap = _gasParameterValue(CORE_READ_GAS);
        bool ok;
        uint256 returned;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(output, 32), exactSize)
            returned := returndatasize()
        }
        if (!ok || returned != exactSize) revert InventoryCoreReadFailed(bytes4(input));
    }
}
