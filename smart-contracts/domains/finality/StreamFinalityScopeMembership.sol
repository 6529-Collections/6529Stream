// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamScopeMembershipReads.sol";
import "../../interfaces/stream/finality/IStreamCollectionTokenInventory.sol";
import "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import "../parameters/StreamGasParameterHost.sol";

/// @notice Immutable published scope subsets, authenticated against Metadata and actual Core inventory.
/// @dev Incremental indexing creates no artist sanction, view-content approval or finality readiness.
contract StreamFinalityScopeMembership is IStreamFinalityScopeMembership, StreamGasParameterHost {
    bytes32 public constant DEPENDENCY_READ_GAS =
        keccak256("6529STREAM_GGP_SCOPE_MEMBERSHIP_READ_GAS");
    address public immutable override core;
    address public immutable override metadataHost;
    address public immutable override tokenInventory;
    address public immutable schemaRegistry;
    address public immutable chunkStore;
    uint256 public immutable deploymentChainId;
    bytes32[5] private _codeHashes;

    struct ScopeState {
        StreamFinalityScope scope;
        Publication publication;
        StreamScopeMembershipManifest manifest;
        uint256 nextPart;
        bool complete;
        address[] pointers;
        bytes32[] pointerCodeHashes;
        uint256[] tokens;
    }
    mapping(bytes32 => ScopeState) private _scopes;

    constructor(
        address core_,
        address metadataHost_,
        address inventory_,
        address executor,
        GasParameterConfig memory readGas
    ) StreamGasParameterHost(executor) {
        if (
            _registerGasParameter(readGas) != DEPENDENCY_READ_GAS
                || readGas.failureClass != FAILURE_CLASS_FORWARDING_CAP || readGas.floor < 50000
                || readGas.genesisValue > type(uint256).max / 64 || core_.code.length == 0
                || metadataHost_.code.length == 0 || inventory_.code.length == 0
        ) revert InvalidScopeMembershipConfiguration();
        core = core_;
        metadataHost = metadataHost_;
        tokenInventory = inventory_;
        deploymentChainId = block.chainid;
        uint256 cap = readGas.genesisValue;
        if (
            _address(metadataHost_, abi.encodeCall(IStreamCollectionMetadataV1.core, ()), cap)
                    != core_
                || _address(
                        inventory_, abi.encodeCall(IStreamCollectionTokenInventory.core, ()), cap
                    ) != core_
        ) revert InvalidScopeMembershipConfiguration();
        schemaRegistry = _address(
            metadataHost_, abi.encodeCall(IStreamCollectionMetadataV1.schemaRegistry, ()), cap
        );
        chunkStore = _address(
            metadataHost_, abi.encodeCall(IStreamCollectionMetadataV1.chunkStore, ()), cap
        );
        if (
            _address(schemaRegistry, abi.encodeCall(IStreamSchemaRegistry.chunkStore, ()), cap)
                != chunkStore
        ) {
            revert InvalidScopeMembershipConfiguration();
        }
        // Adopt the original hosts' immutable baselines, never merely today's matching getters.
        if (
            _word(metadataHost_, abi.encodeWithSignature("coreCodeHash()"), cap) != core_.codehash
                || _word(metadataHost_, abi.encodeWithSignature("schemaRegistryCodeHash()"), cap)
                    != schemaRegistry.codehash
                || _word(metadataHost_, abi.encodeWithSignature("chunkStoreCodeHash()"), cap)
                    != chunkStore.codehash
                || _word(inventory_, abi.encodeWithSignature("coreCodeHash()"), cap)
                    != core_.codehash
                || uint256(_word(inventory_, abi.encodeWithSignature("deploymentChainId()"), cap))
                    != block.chainid
        ) revert InvalidScopeMembershipConfiguration();
        _supports(core_, 0x80ac58cd, cap);
        _supports(metadataHost_, type(IStreamCollectionMetadataV1).interfaceId, cap);
        _supports(inventory_, type(IStreamCollectionTokenInventory).interfaceId, cap);
        for (uint256 i; i < 5; ++i) {
            _codeHashes[i] = _target(i).codehash;
        }
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId
            || id == type(IStreamFinalityScopeMembership).interfaceId
            || id == type(IStreamFinalityRecoveryScopeEvidence).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId;
    }

    function beginScopeMembership(bytes32 recordHash)
        external
        override
        returns (StreamFinalityScope memory scope)
    {
        _pins();
        (StreamScopeMembershipManifest memory m, Publication memory publication) =
            StreamScopeMembershipReads.publication(_inputs(), recordHash);
        _collection(m.collectionId);
        scope = StreamFinalityScope(
            StreamFinalityScopeType(m.scopeType),
            m.collectionId,
            0,
            StreamScopeMembershipEncoding.scopeId(
                deploymentChainId, core, m.collectionId, m.scopeType, recordHash
            )
        );
        ScopeState storage s = _scopes[scope.scopeId];
        if (s.publication.recordHash != 0) return scope;
        s.scope = scope;
        s.publication = publication;
        s.manifest = m;
        uint256 cap = _gasParameterValue(DEPENDENCY_READ_GAS);
        for (uint256 i; i < m.chunkHashes.length; ++i) {
            (address pointer, uint256 length) =
                StreamScopeMembershipReads.chunkPointer(chunkStore, m.chunkHashes[i], cap);
            if (length != _partLength(m.tokenCount, i)) revert ScopeMembershipPartInvalid(i);
            s.pointers.push(pointer);
            s.pointerCodeHashes.push(pointer.codehash);
        }
        emit ScopeMembershipAdmitted(
            scope.scopeId,
            m.collectionId,
            m.scopeType,
            recordHash,
            publication.manifestHash,
            m.tokenListHash,
            m.tokenCount,
            publication.receipt.recorder,
            publication.receipt.authorizationClass
        );
    }

    function continueScopeMembership(StreamFinalityScope calldata scope, uint256 maximumParts)
        external
        override
    {
        _pins();
        ScopeState storage s = _stored(scope);
        if (s.complete || maximumParts == 0 || maximumParts > 64) {
            revert ScopeMembershipProgressInvalid();
        }
        _sourcePins(s);
        uint256 end = s.nextPart + maximumParts;
        if (end > s.pointers.length) end = s.pointers.length;
        for (uint256 i = s.nextPart; i < end; ++i) {
            bytes memory payload = _part(s, i);
            for (uint256 at; at < payload.length; at += 32) {
                uint256 tokenId;
                assembly ("memory-safe") { tokenId := mload(add(add(payload, 32), at)) }
                if (s.tokens.length != 0 && tokenId <= s.tokens[s.tokens.length - 1]) {
                    revert ScopeMembershipTokenInvalid(tokenId);
                }
                (bool valid, uint256 serial) = _token(scope.collectionId, tokenId);
                if (
                    !valid
                        || abi.decode(
                                _read(
                                    tokenInventory,
                                    abi.encodeCall(
                                        IStreamCollectionTokenInventory.collectionTokenAt,
                                        (scope.collectionId, serial - 1)
                                    ),
                                    32
                                ),
                                (uint256)
                            ) != tokenId
                ) revert ScopeMembershipTokenInvalid(tokenId);
                s.tokens.push(tokenId);
            }
        }
        s.nextPart = end;
        emit ScopeMembershipProgressed(scope.scopeId, end, s.tokens.length);
        if (end == s.pointers.length) {
            if (
                s.tokens.length != s.manifest.tokenCount
                    || _wholeHash(s) != s.manifest.tokenListHash
            ) {
                revert ScopeMembershipProgressInvalid();
            }
            s.complete = true;
            StreamScopeMembershipFacts memory f = _scopedFacts(s);
            emit ScopeMembershipSealed(scope.scopeId, f.membershipHash, s.tokens.length);
        }
    }

    function scopeMembershipProgress(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (Progress memory p)
    {
        ScopeState storage s = _stored(scope);
        return Progress(
            true, s.complete, s.tokens.length, s.manifest.tokenCount, s.nextPart, s.pointers.length
        );
    }

    function scopeMembershipPublication(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (Publication memory)
    {
        return _stored(scope).publication;
    }

    function requireScopeMembership(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (StreamScopeMembershipFacts memory)
    {
        return _facts(scope);
    }

    function requireRecoveryScope(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (bytes32 subject, bytes32 manifestHash)
    {
        StreamScopeMembershipFacts memory f = _facts(scope);
        return (f.scopeSubject, f.scopeManifestHash);
    }

    function scopeTokenAt(StreamFinalityScope calldata scope, uint256 index)
        external
        view
        override
        returns (uint256)
    {
        StreamScopeMembershipFacts memory f = _facts(scope);
        if (index >= f.tokenCount) revert ScopeMembershipIndexOutOfBounds(index);
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            return abi.decode(
                _read(
                    tokenInventory,
                    abi.encodeCall(
                        IStreamCollectionTokenInventory.collectionTokenAt,
                        (scope.collectionId, index)
                    ),
                    32
                ),
                (uint256)
            );
        }
        if (scope.scopeType == StreamFinalityScopeType.TOKEN) return scope.tokenId;
        return _scopes[scope.scopeId].tokens[index];
    }

    function scopeCoversToken(StreamFinalityScope calldata scope, uint256 tokenId)
        external
        view
        override
        returns (bool)
    {
        StreamScopeMembershipFacts memory f = _facts(scope);
        (bool valid,) = _token(scope.collectionId, tokenId);
        if (!valid) return false;
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) return true;
        if (scope.scopeType == StreamFinalityScopeType.TOKEN) return scope.tokenId == tokenId;
        ScopeState storage s = _scopes[scope.scopeId];
        uint256 low;
        uint256 high = f.tokenCount;
        while (low < high) {
            uint256 mid = low + (high - low) / 2;
            if (s.tokens[mid] < tokenId) low = mid + 1;
            else high = mid;
        }
        return low < f.tokenCount && s.tokens[low] == tokenId;
    }

    function _facts(StreamFinalityScope memory scope)
        private
        view
        returns (StreamScopeMembershipFacts memory f)
    {
        _pins();
        f.scopeSubject = StreamMetadataSubjects.scopeSubject(deploymentChainId, core, scope);
        _collection(scope.collectionId);
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            (f.inventoryCount, f.inventoryPrefixHash) = abi.decode(
                _read(
                    tokenInventory,
                    abi.encodeCall(
                        IStreamCollectionTokenInventory.requireCompleteCollection,
                        (scope.collectionId)
                    ),
                    64
                ),
                (uint256, bytes32)
            );
            f.tokenCount = f.inventoryCount;
        } else if (scope.scopeType == StreamFinalityScopeType.TOKEN) {
            (bool valid,) = _token(scope.collectionId, scope.tokenId);
            if (!valid) revert ScopeMembershipTokenInvalid(scope.tokenId);
            f.tokenCount = 1;
            f.tokenListHash = keccak256(abi.encode(scope.tokenId));
        } else {
            ScopeState storage s = _stored(scope);
            if (!s.complete) revert ScopeMembershipIncomplete(scope.scopeId);
            _sourcePins(s);
            return _scopedFacts(s);
        }
        f.membershipHash = StreamScopeMembershipEncoding.membershipHash(
            deploymentChainId, core, metadataHost, tokenInventory, scope, f
        );
    }

    function _scopedFacts(ScopeState storage s)
        private
        view
        returns (StreamScopeMembershipFacts memory f)
    {
        f.scopeSubject = StreamMetadataSubjects.scopeSubject(deploymentChainId, core, s.scope);
        f.scopeManifestHash = s.publication.manifestHash;
        f.sourceRecordHash = s.publication.recordHash;
        f.tokenCount = s.manifest.tokenCount;
        f.tokenListHash = s.manifest.tokenListHash;
        f.membershipHash = StreamScopeMembershipEncoding.membershipHash(
            deploymentChainId, core, metadataHost, tokenInventory, s.scope, f
        );
    }

    function _stored(StreamFinalityScope memory scope) private view returns (ScopeState storage s) {
        s = _scopes[scope.scopeId];
        if (
            s.publication.recordHash == 0
                || keccak256(abi.encode(scope)) != keccak256(abi.encode(s.scope))
        ) {
            revert ScopeMembershipUnknown(scope.scopeId);
        }
    }

    function _sourcePins(ScopeState storage s) private view {
        address pointer = s.publication.payloadPointer;
        if (pointer.code.length == 0 || pointer.codehash != s.publication.payloadCodeHash) {
            revert ScopeMembershipDependencyChanged(pointer);
        }
        for (uint256 i; i < s.pointers.length; ++i) {
            pointer = s.pointers[i];
            if (pointer.code.length == 0 || pointer.codehash != s.pointerCodeHashes[i]) {
                revert ScopeMembershipDependencyChanged(pointer);
            }
        }
    }

    function _wholeHash(ScopeState storage s) private view returns (bytes32) {
        // Reconstruct retained native bytes, avoiding a cold SLOAD for every stored member at seal.
        bytes memory whole = new bytes(s.manifest.tokenCount * 32);
        uint256 offset;
        for (uint256 i; i < s.pointers.length; ++i) {
            bytes memory payload = _part(s, i);
            for (uint256 at; at < payload.length; at += 32) {
                assembly ("memory-safe") {
                    mstore(add(add(whole, 32), add(offset, at)), mload(add(add(payload, 32), at)))
                }
            }
            offset += payload.length;
        }
        if (offset != whole.length) revert ScopeMembershipProgressInvalid();
        return keccak256(whole);
    }

    function _part(ScopeState storage s, uint256 index) private view returns (bytes memory) {
        return StreamScopeMembershipReads.part(
            chunkStore,
            s.manifest.chunkHashes[index],
            s.pointers[index],
            s.pointerCodeHashes[index],
            _partLength(s.manifest.tokenCount, index),
            _gasParameterValue(DEPENDENCY_READ_GAS)
        );
    }

    function _partLength(uint256 tokenCount, uint256 index) private pure returns (uint256) {
        uint256 remaining = tokenCount * 32 - index * 8192;
        return remaining > 8192 ? 8192 : remaining;
    }

    function _collection(uint256 collectionId) private view {
        if (
            collectionId == 0
                || abi.decode(
                        _read(
                            core,
                            abi.encodeCall(
                                IStreamCoreCollectionView.collectionExists, (collectionId)
                            ),
                            32
                        ),
                        (uint256)
                    ) != 1
        ) {
            revert ScopeMembershipTokenInvalid(0);
        }
    }

    function _token(uint256 collectionId, uint256 tokenId)
        private
        view
        returns (bool valid, uint256 serial)
    {
        (uint256 exists, uint256 actualCollection, uint256 actualSerial, uint256 burned) = abi.decode(
            _read(
                core, abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (tokenId)), 128
            ),
            (uint256, uint256, uint256, uint256)
        );
        uint256 lifecycle = abi.decode(
            _read(core, abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (tokenId)), 32),
            (uint256)
        );
        if (exists > 1 || burned > 1 || lifecycle > 3) revert ScopeMembershipTokenInvalid(tokenId);
        valid = tokenId != 0 && exists == 1 && actualCollection == collectionId && actualSerial != 0
            && ((lifecycle == 2 && burned == 0) || (lifecycle == 3 && burned == 1));
        serial = actualSerial;
    }

    function _inputs() private view returns (StreamScopeMembershipReads.Inputs memory) {
        return StreamScopeMembershipReads.Inputs(
            deploymentChainId,
            core,
            metadataHost,
            schemaRegistry,
            chunkStore,
            _gasParameterValue(DEPENDENCY_READ_GAS)
        );
    }

    function _read(address target, bytes memory input, uint256 length)
        private
        view
        returns (bytes memory)
    {
        return StreamScopeMembershipReads.read(
            target, input, length, _gasParameterValue(DEPENDENCY_READ_GAS), true
        );
    }

    function _address(address target, bytes memory input, uint256 cap)
        private
        view
        returns (address value)
    {
        value = abi.decode(StreamScopeMembershipReads.read(target, input, 32, cap, true), (address));
        if (value.code.length == 0) revert InvalidScopeMembershipConfiguration();
    }

    function _word(address target, bytes memory input, uint256 cap) private view returns (bytes32) {
        return abi.decode(StreamScopeMembershipReads.read(target, input, 32, cap, true), (bytes32));
    }

    function _supports(address target, bytes4 id, uint256 cap) private view {
        if (
            abi.decode(
                        StreamScopeMembershipReads.read(
                            target, abi.encodeCall(IERC165.supportsInterface, (id)), 32, cap, true
                        ),
                        (uint256)
                    ) != 1
                || abi.decode(
                        StreamScopeMembershipReads.read(
                            target,
                            abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)),
                            32,
                            cap,
                            true
                        ),
                        (uint256)
                    ) != 1
                || abi.decode(
                        StreamScopeMembershipReads.read(
                            target,
                            abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))),
                            32,
                            cap,
                            true
                        ),
                        (uint256)
                    ) != 0
        ) revert InvalidScopeMembershipConfiguration();
    }

    function _pins() private view {
        if (block.chainid != deploymentChainId) {
            revert ScopeMembershipDependencyChanged(address(0));
        }
        for (uint256 i; i < 5; ++i) {
            address target = _target(i);
            if (target.code.length == 0 || target.codehash != _codeHashes[i]) {
                revert ScopeMembershipDependencyChanged(target);
            }
        }
    }

    function _target(uint256 index) private view returns (address) {
        if (index == 0) return core;
        if (index == 1) return metadataHost;
        if (index == 2) return tokenInventory;
        if (index == 3) return schemaRegistry;
        return chunkStore;
    }
}
