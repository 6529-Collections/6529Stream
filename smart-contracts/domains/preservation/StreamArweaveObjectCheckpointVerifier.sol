// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/preservation/IStreamExternalArtifactCheckpointVerifier.sol";
import "../parameters/StreamGasParameterHost.sol";
import "./StreamArweaveObjectInclusion.sol";
import "./StreamArchivalSignatures.sol";

/// @notice External-object native roots included under a pinned named-network checkpoint quorum.
/// @dev No bulk payload is stored or flat file digest recomputed here. Quorum honesty anchors
///      tx-ID/root association and network membership; this is not Arweave consensus verification.
contract StreamArweaveObjectCheckpointVerifier is
    StreamGasParameterHost,
    IStreamExternalArtifactCheckpointVerifier
{
    bytes32 public constant override profileHash =
        keccak256("6529STREAM_ARWEAVE_EXTERNAL_OBJECT_QUORUM_V1");
    bytes32 public constant override networkId = keccak256("ARWEAVE_MAINNET");
    bytes32 private constant _TYPEHASH = keccak256(
        "StreamArweaveCheckpoint(bytes32 networkId,bytes blockHash,uint64 blockHeight,bytes32 transactionRoot,uint256 blockDataSize,bytes32 transactionId,bytes32 dataRoot,uint64 dataSize,uint256 transactionStart,uint256 transactionEnd,uint64 observedAt,bytes32 configurationHash)"
    );
    bytes32 private constant _SIGNATURE_GAS =
        keccak256("6529STREAM_GGP_ARCHIVAL_ERC1271_VERIFY_GAS");
    bytes32 public immutable override configurationHash;
    uint8 public immutable override quorum;
    A.Observer[] private _observers;
    mapping(address => bool) private _observer;
    mapping(bytes32 => E.NativeRecord) private _records;

    constructor(
        address executor,
        A.Observer[] memory observerSet,
        uint8 required,
        GasParameterConfig memory signatureGas
    ) StreamGasParameterHost(executor) {
        if (
            executor == address(0) || required < 2 || observerSet.length < required
                || observerSet.length > 8
                || keccak256(bytes(signatureGas.name)) != keccak256("ARCHIVAL_ERC1271_VERIFY_GAS")
                || signatureGas.floor < 90000 || signatureGas.failureClass != 2
        ) {
            revert A.InvalidArchivalConfiguration();
        }
        _registerGasParameter(signatureGas);
        address prior;
        for (uint256 i; i < observerSet.length; ++i) {
            A.Observer memory item = observerSet[i];
            if (item.account <= prior || item.organizationId == bytes32(0)) {
                revert A.InvalidArchivalConfiguration();
            }
            for (uint256 j; j < i; ++j) {
                if (observerSet[j].organizationId == item.organizationId) {
                    revert A.InvalidArchivalConfiguration();
                }
            }
            _observers.push(item);
            _observer[item.account] = true;
            prior = item.account;
        }
        quorum = required;
        configurationHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_EXTERNAL_OBJECT_OBSERVER_CONFIGURATION_V1"),
                block.chainid,
                address(this),
                networkId,
                profileHash,
                executor,
                observerSet,
                required
            )
        );
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamExternalArtifactCheckpointVerifier).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId;
    }

    function observers() external view override returns (A.Observer[] memory) {
        return _observers;
    }

    function checkpointDigest(A.Checkpoint calldata c) public view override returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream External Arweave Checkpoints"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
        bytes32 body = keccak256(
            abi.encode(
                _TYPEHASH,
                c.networkId,
                keccak256(c.blockHash),
                c.blockHeight,
                c.transactionRoot,
                c.blockDataSize,
                c.transactionId,
                c.dataRoot,
                c.dataSize,
                c.transactionStart,
                c.transactionEnd,
                c.observedAt,
                c.configurationHash
            )
        );
        return keccak256(abi.encodePacked(hex"1901", domain, body));
    }

    function recordCheckpoint(
        A.Checkpoint calldata c,
        bytes calldata transactionPath,
        bytes calldata firstDataPath,
        bytes calldata lastDataPath,
        A.ObserverProof[] calldata certificate
    ) external override returns (bytes32 recordHash) {
        if (
            c.networkId != networkId || c.configurationHash != configurationHash
                || c.blockHash.length != 48 || keccak256(c.blockHash) == keccak256(new bytes(48))
                || c.blockHeight == 0 || c.transactionId == bytes32(0)
                || c.transactionRoot == bytes32(0) || c.observedAt == 0
                || c.observedAt > block.timestamp || block.timestamp > type(uint64).max
                || certificate.length < quorum || certificate.length > _observers.length
        ) revert A.InvalidCheckpoint();
        bytes32 digest = checkpointDigest(c);
        _requireCertificate(certificate, digest);
        (bytes32 firstDigest, bytes32 lastDigest) =
            StreamArweaveObjectInclusion.verify(c, transactionPath, firstDataPath, lastDataPath);
        bytes32[3] memory pathHashes;
        pathHashes[0] = keccak256(transactionPath);
        pathHashes[1] = keccak256(firstDataPath);
        pathHashes[2] = keccak256(lastDataPath);
        recordHash = _recordHash(c, firstDigest, lastDigest, pathHashes);
        E.NativeRecord storage item = _records[recordHash];
        if (item.recordHash != bytes32(0)) revert A.ArchivalRecordExists(recordHash);
        item.recordHash = recordHash;
        item.checkpoint = c;
        item.firstChunkDigest = firstDigest;
        item.lastChunkDigest = lastDigest;
        item.transactionPath = transactionPath;
        item.firstDataPath = firstDataPath;
        item.lastDataPath = lastDataPath;
        for (uint256 i; i < certificate.length; ++i) {
            item.certificate.push(certificate[i]);
        }
        item.recordedAt = uint64(block.timestamp);
        _emitCheckpoint(recordHash, digest);
    }

    function _emitCheckpoint(bytes32 hash, bytes32 digest) private {
        E.NativeRecord storage item = _records[hash];
        emit ExternalObjectCheckpointRecorded(
            1,
            hash,
            item.checkpoint.transactionId,
            configurationHash,
            digest,
            item.checkpoint.dataRoot,
            item.checkpoint.dataSize,
            item.recordedAt
        );
    }

    function _recordHash(
        A.Checkpoint calldata c,
        bytes32 first,
        bytes32 last,
        bytes32[3] memory paths
    ) private view returns (bytes32) {
        // A fixed three-word array has the same ABI head as the three individual hashes.
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_EXTERNAL_OBJECT_CHECKPOINT_RECORD_V1"),
                block.chainid,
                address(this),
                c,
                first,
                last,
                paths
            )
        );
    }

    function _requireCertificate(A.ObserverProof[] calldata certificate, bytes32 digest)
        private
        view
    {
        address prior;
        uint256 cap = _gasParameterValue(_SIGNATURE_GAS);
        for (uint256 i; i < certificate.length; ++i) {
            A.ObserverProof calldata proof = certificate[i];
            if (proof.account <= prior || !_observer[proof.account]) revert A.InvalidCheckpoint();
            StreamArchivalSignatures.requireValid(proof.account, digest, proof.signature, cap);
            prior = proof.account;
        }
    }

    function checkpointFacts(bytes32 hash) external view override returns (E.NativeFacts memory) {
        E.NativeRecord storage item = _records[hash];
        if (item.recordHash == bytes32(0)) revert A.ArchivalRecordUnavailable(hash);
        A.Checkpoint storage c = item.checkpoint;
        return E.NativeFacts(
            item.recordHash,
            c.networkId,
            c.transactionId,
            c.dataRoot,
            c.dataSize,
            c.configurationHash,
            item.firstChunkDigest,
            item.lastChunkDigest
        );
    }

    function checkpointRecord(bytes32 hash) external view override returns (E.NativeRecord memory) {
        return _records[hash];
    }
}
