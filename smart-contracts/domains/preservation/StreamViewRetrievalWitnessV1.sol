// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamViewRetrievalWitnessV1
} from "../../interfaces/stream/preservation/IStreamViewRetrievalWitnessV1.sol";
import {
    StreamViewRetrievalWitnessTypesV1 as T
} from "../../interfaces/stream/preservation/StreamViewRetrievalWitnessTypesV1.sol";
import {
    StreamBundleArchiveTypes as B
} from "../../interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamExternalArtifactTypes as E
} from "../../interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import { StreamSnapshotManifestBytes as Bytes } from "../records/StreamSnapshotManifestBytes.sol";
import { StreamArchivalSignatures as Signatures } from "./StreamArchivalSignatures.sol";
import { StreamViewRetrievalSourceV1 as Sources } from "./StreamViewRetrievalSourceV1.sol";
import { StreamViewRetrievalArchiveV1 as Archives } from "./StreamViewRetrievalArchiveV1.sol";
import { StreamViewRetrievalCodecV1 as Codec } from "./StreamViewRetrievalCodecV1.sol";

/// @notice Original institutional writer's retained retrieval claim for an actual adopted VIEW.
/// @dev No network access, generic resolver, origin immutability or independent fixity is claimed.
contract StreamViewRetrievalWitnessV1 is IStreamViewRetrievalWitnessV1 {
    T.Configuration private _configuration;
    bytes32 public immutable override configurationHash;
    mapping(bytes32 => Bytes.Manifest) private _payloads;
    mapping(bytes32 => T.Receipt) private _records;
    mapping(bytes32 => bool) public override revoked;
    mapping(bytes32 => bool) public override nonceUsed;
    mapping(bytes32 => bytes32) private _recordScopes;
    mapping(bytes32 => uint64) private _revocationEpochs;
    bool private _entered;

    constructor(T.Configuration memory c) {
        Sources.validate(c);
        _configuration = c;
        configurationHash = keccak256(abi.encode(T.PROFILE, c));
    }
    modifier guarded() {
        if (_entered) revert T.InvalidViewRetrieval();
        _entered = true;
        _;
        _entered = false;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamViewRetrievalWitnessV1).interfaceId;
    }

    function configuration() external view returns (T.Configuration memory) {
        return _configuration;
    }

    function retrievalProfile() external pure returns (bytes32) {
        return T.PROFILE;
    }

    function prepare(T.Request calldata r)
        external
        view
        returns (T.Observation memory o, bytes32 digest)
    {
        (o,) = _prepare(r);
        digest = Codec.digest(_configuration, address(this), o);
    }

    function _prepare(T.Request calldata r)
        private
        view
        returns (T.Observation memory o, address store)
    {
        uint64 adoptedAt;
        (o.source, store, adoptedAt) = Sources.current(_configuration, r.scope);
        B.Admission memory a;
        uint64 receiptAt;
        (o.object, a, o.writer, receiptAt) = Archives.admit(
            _configuration, o.source, r.coverageHash
        );
        o.coverage = a.externalOriginal;
        o.steps = r.steps;
        o.resolvedURI = r.resolvedURI;
        o.observedAt = r.observedAt;
        o.nonce = r.nonce;
        o.deadline = r.deadline;
        if (
            r.observedAt < adoptedAt || r.observedAt < receiptAt || r.observedAt > block.timestamp
                || r.deadline < block.timestamp || block.timestamp > type(uint64).max
        ) revert T.InvalidViewRetrieval();
        Archives.routes(_configuration, o);
    }

    function publish(T.Request calldata request, bytes calldata signature)
        external
        guarded
        returns (bytes32 hash)
    {
        (T.Observation memory o, address store) = _prepare(request);
        bytes32 nonce = keccak256(abi.encode(T.NONCE, o.writer, o.nonce));
        if (nonceUsed[nonce]) revert T.ViewRetrievalNonce(nonce);
        Signatures.requireValid(
            o.writer,
            Codec.digest(_configuration, address(this), o),
            signature,
            _configuration.signatureGas
        );
        // Full original current source and same-pair evidence are repeated after signature authority.
        (T.Observation memory again, address againStore) = _prepare(request);
        if (store != againStore || keccak256(abi.encode(o)) != keccak256(abi.encode(again))) {
            revert T.InvalidViewRetrieval();
        }
        bytes memory payload = abi.encode(o, signature);
        if (payload.length > T.MAX_BYTES) revert T.InvalidViewRetrieval();
        T.Receipt memory receipt;
        receipt.sourceKey = Codec.sourceKey(o.source);
        receipt.observationHash = Codec.digest(_configuration, address(this), o);
        receipt.objectHash = o.coverage.objectHash;
        receipt.coverageHash = o.coverage.coverageHash;
        receipt.writer = o.writer;
        receipt.recordedAt = uint64(block.timestamp);
        receipt.payloadHash = keccak256(payload);
        receipt.payloadBytes = uint32(payload.length);
        hash = keccak256(
            abi.encode(T.RECORD, _configuration.chainId, address(this), configurationHash, receipt)
        );
        if (_records[hash].recordHash != 0) revert T.InvalidViewRetrieval();
        _recordScopes[hash] = _scopeKey(o.source.scope);
        nonceUsed[nonce] = true;
        Bytes.retain(_payloads[hash], store, payload);
        receipt.recordHash = hash;
        _records[hash] = receipt;
        emit ViewRetrievalRecorded(hash, receipt.sourceKey, receipt.writer, receipt);
    }

    function record(bytes32 hash) public view returns (T.Receipt memory r) {
        r = _records[hash];
        if (hash == 0 || r.recordHash != hash) revert T.ViewRetrievalUnknown(hash);
    }

    function encoded(bytes32 hash) public view returns (bytes memory) {
        record(hash);
        return Bytes.read(_payloads[hash]);
    }

    function requireCurrent(bytes32 hash)
        external
        view
        returns (T.Receipt memory r, B.Admission memory a)
    {
        (, r, a) = _current(hash);
    }

    function requireCorrespondence(bytes32 hash)
        external
        view
        returns (T.Source memory source, T.Receipt memory r, B.Admission memory a)
    {
        return _current(hash);
    }

    function _current(bytes32 hash)
        private
        view
        returns (T.Source memory source, T.Receipt memory r, B.Admission memory a)
    {
        r = record(hash);
        if (revoked[hash]) revert T.ViewRetrievalRevoked(hash);
        bytes memory raw = Bytes.read(_payloads[hash]);
        (T.Observation memory o,) = Codec.canonical(raw);
        T.Receipt memory original = abi.decode(abi.encode(r), (T.Receipt));
        original.recordHash = 0;
        if (
            raw.length != r.payloadBytes || keccak256(raw) != r.payloadHash
                || r.sourceKey != Codec.sourceKey(o.source)
                || r.observationHash != Codec.digest(_configuration, address(this), o)
                || r.writer != o.writer || r.objectHash != o.coverage.objectHash
                || r.coverageHash != o.coverage.coverageHash
                || keccak256(
                        abi.encode(
                            T.RECORD,
                            _configuration.chainId,
                            address(this),
                            configurationHash,
                            original
                        )
                    ) != hash
        ) revert T.ViewRetrievalChanged(hash);
        (source,,) = Sources.current(_configuration, o.source.scope);
        if (keccak256(abi.encode(source)) != keccak256(abi.encode(o.source))) {
            revert T.ViewRetrievalChanged(hash);
        }
        E.ObjectIdentity memory object;
        address writer;
        (object, a, writer,) = Archives.admit(_configuration, source, o.coverage.coverageHash);
        if (
            writer != o.writer || keccak256(abi.encode(object)) != keccak256(abi.encode(o.object))
                || keccak256(abi.encode(a.externalOriginal)) != keccak256(abi.encode(o.coverage))
        ) revert T.ViewRetrievalChanged(hash);
        Archives.routes(_configuration, o);
        // Historical signature/deadline authority is retained, never replayed against today's Safe.
    }

    function revocationEpoch(StreamFinalityScope calldata scope) external view returns (uint64) {
        return _revocationEpochs[_scopeKey(scope)];
    }

    function _scopeKey(StreamFinalityScope memory scope) private pure returns (bytes32) {
        if (
            scope.scopeType != StreamFinalityScopeType.VIEW || scope.collectionId == 0
                || scope.tokenId != 0 || scope.scopeId == 0
        ) revert T.InvalidViewRetrieval();
        return
            keccak256(abi.encode(keccak256("6529STREAM_VIEW_RETRIEVAL_REVOCATION_SCOPE_V1"), scope));
    }

    function revoke(bytes32 hash, bytes32 reasonHash) external guarded {
        T.Receipt memory r = record(hash);
        if (msg.sender != r.writer || reasonHash == 0 || revoked[hash]) {
            revert T.InvalidViewRetrieval();
        }
        revoked[hash] = true;
        ++_revocationEpochs[_recordScopes[hash]];
        emit ViewRetrievalRevoked(hash, msg.sender, reasonHash);
    }
}
