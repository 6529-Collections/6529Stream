// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamViewPreservationOutputManifestV1 as I,
    T
} from "../../interfaces/stream/finality/IStreamViewPreservationOutputManifestV1.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as C
} from "../../interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    StreamViewPreservationManifestReadsV1 as Reads
} from "./StreamViewPreservationManifestReadsV1.sol";
import {
    StreamViewPreservationManifestEncodingV1 as Encoding
} from "./StreamViewPreservationManifestEncodingV1.sol";
import {
    StreamViewPreservationOutputSchemasV1 as Definitions
} from "./StreamViewPreservationOutputSchemasV1.sol";
import { StreamViewAdoptionReads as Read } from "../metadata/StreamViewAdoptionReads.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

/// @notice Complete covered VIEW output parts/index. No preparation is current evidence.
/// @dev Full checkpoint and all covered parts remain mandatory on finalization/current reads.
/// Maximum vocabulary is 16384 rows; whole-scope transaction capacity is not implied.
contract StreamViewPreservationOutputManifestV1 is I, IERC165 {
    T.Configuration private _configuration;
    bytes32 public immutable override configurationHash;
    bytes32 public immutable readWorkerCodeHash;
    bytes32 public immutable encodingWorkerCodeHash;
    mapping(bytes32 => T.Part) private _parts;
    mapping(bytes32 => T.Plan) private _plans;
    mapping(bytes32 => mapping(uint256 => bytes32)) private _planParts;
    mapping(bytes32 => bytes32) private _recordPlans;
    bytes32 private constant PART =
        keccak256("6529STREAM_VIEW_PRESERVATION_OUTPUT_PART_VERIFIED_V1");
    bytes32 private constant PLAN =
        keccak256("6529STREAM_VIEW_PRESERVATION_OUTPUT_MANIFEST_PLAN_V1");
    bytes32 private constant CHAIN = keccak256("6529STREAM_VIEW_PRESERVATION_OUTPUT_PART_CHAIN_V1");
    bytes32 private constant RECORD =
        keccak256("6529STREAM_VIEW_PRESERVATION_OUTPUT_MANIFEST_VERIFIED_V1");

    constructor(T.Configuration memory c) {
        Reads.pins(c);
        _configuration = c;
        readWorkerCodeHash = address(Reads).codehash;
        encodingWorkerCodeHash = address(Encoding).codehash;
        Read.pin(address(Reads), readWorkerCodeHash);
        Read.pin(address(Encoding), encodingWorkerCodeHash);
        configurationHash = keccak256(
            abi.encode(
                T.PROFILE,
                block.chainid,
                address(this),
                c,
                address(Reads),
                readWorkerCodeHash,
                address(Encoding),
                encodingWorkerCodeHash
            )
        );
    }

    function configuration() external view returns (T.Configuration memory) {
        return _configuration;
    }

    function outputProfile() external pure returns (bytes32) {
        return T.PROFILE;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(I).interfaceId || id == type(IERC165).interfaceId;
    }

    function preparePart(
        bytes32 checkpointId,
        uint64 first,
        bytes32 artifactHash,
        bytes32 coverageHash,
        bytes32 artistId
    ) external returns (bytes32 key) {
        _fresh();
        T.Header memory h = Reads.header(_configuration, checkpointId);
        if (first % T.PART_ROWS != 0 || first >= h.tokenCount) revert T.ViewManifestOrder(first);
        uint16 count =
            uint16(h.tokenCount - first > T.PART_ROWS ? T.PART_ROWS : h.tokenCount - first);
        C.Output[] memory rows = Reads.rows(_configuration, checkpointId, first, count);
        bytes memory expected = Encoding.part(_configuration, h, first, rows);
        if (expected.length != 672 + uint256(count) * 992) revert T.InvalidViewManifest();
        (T.Carrier memory carrier, bytes memory raw) = Reads.carrier(
            _configuration,
            artifactHash,
            coverageHash,
            artistId,
            Definitions.PART,
            Definitions.PART_CANON,
            expected.length
        );
        if (keccak256(raw) != keccak256(expected)) revert T.InvalidViewManifest();
        T.Part memory p = T.Part(h, carrier, first, count, rows[0].tokenId, rows[count - 1].tokenId);
        key = keccak256(abi.encode(PART, block.chainid, address(this), configurationHash, p));
        if (_parts[key].count == 0) {
            _parts[key] = p;
            emit ViewOutputPartPrepared(key, checkpointId, first, count);
        }
    }

    function beginManifest(
        bytes32 checkpointId,
        bytes32 artifactHash,
        bytes32 coverageHash,
        bytes32 artistId
    ) external returns (bytes32 key) {
        _fresh();
        T.Header memory h = Reads.header(_configuration, checkpointId);
        uint16 count = uint16((uint256(h.tokenCount) + 63) / 64);
        (T.Carrier memory carrier, bytes memory raw) = Reads.carrier(
            _configuration,
            artifactHash,
            coverageHash,
            artistId,
            Definitions.INDEX,
            Definitions.INDEX_CANON,
            672 + uint256(count) * 288
        );
        T.Descriptor[] memory empty = new T.Descriptor[](count);
        bytes memory expected = Encoding.index(_configuration, h, artistId, empty);
        if (expected.length != raw.length || _hash(raw, 0, 672) != _hash(expected, 0, 672)) {
            revert T.InvalidViewManifest();
        }
        key = keccak256(
            abi.encode(PLAN, block.chainid, address(this), configurationHash, h, carrier)
        );
        if (_plans[key].header.tokenCount == 0) {
            T.Plan storage p = _plans[key];
            p.header = h;
            p.carrier = carrier;
            p.partCount = count;
            p.partChain = keccak256(abi.encode(CHAIN, key, h));
            emit ViewOutputManifestStarted(key, checkpointId, count);
        }
    }

    function verifyNextPart(bytes32 key, bytes32 partKey) external returns (bytes32 recordHash) {
        _fresh();
        T.Plan storage p = _knownPlan(key);
        if (p.recordHash != 0 || p.nextPart >= p.partCount) revert T.ViewManifestOrder(p.nextPart);
        T.Header memory current = Reads.header(_configuration, p.header.checkpointId);
        if (keccak256(abi.encode(current)) != keccak256(abi.encode(p.header))) {
            revert T.ViewManifestChanged(key);
        }
        T.Part storage part = _knownPart(partKey);
        if (
            keccak256(abi.encode(part.header)) != keccak256(abi.encode(p.header))
                || part.carrier.artistId != p.carrier.artistId || part.first != p.nextRow
                || part.firstToken <= p.previousToken
        ) revert T.ViewManifestOrder(p.nextPart);
        _partCurrent(partKey, part);
        bytes memory raw = _carrier(p.carrier, Definitions.INDEX, Definitions.INDEX_CANON);
        T.Descriptor memory d = Encoding.descriptor(partKey, part);
        if (_hash(raw, 672 + uint256(p.nextPart) * 288, 288) != keccak256(abi.encode(d))) {
            revert T.ViewManifestOrder(p.nextPart);
        }
        uint16 index = p.nextPart;
        _planParts[key][index] = partKey;
        p.partChain = keccak256(abi.encode(CHAIN, p.partChain, index, d));
        p.nextPart = index + 1;
        p.nextRow += part.count;
        p.previousToken = part.lastToken;
        emit ViewOutputManifestAdvanced(key, index, partKey);
        if (p.nextPart == p.partCount) {
            _current(key, p);
            recordHash = keccak256(
                abi.encode(
                    RECORD, block.chainid, address(this), configurationHash, key, p.partChain
                )
            );
            if (_recordPlans[recordHash] != 0) revert T.ViewManifestChanged(recordHash);
            p.recordHash = recordHash;
            _recordPlans[recordHash] = key;
            emit ViewOutputManifestVerified(recordHash, key);
        }
    }

    function partRecord(bytes32 key) external view returns (T.Part memory) {
        return _knownPart(key);
    }

    function manifestPlan(bytes32 key) external view returns (T.Plan memory) {
        return _knownPlan(key);
    }

    function manifestRecord(bytes32 record) public view returns (T.Plan memory) {
        return _knownRecord(record);
    }

    function manifestPart(bytes32 record, uint256 index)
        external
        view
        returns (T.Descriptor memory)
    {
        T.Plan storage p = _knownRecord(record);
        if (index >= p.partCount) revert T.ViewManifestOrder(index);
        bytes32 key = _planParts[_recordPlans[record]][index];
        return Encoding.descriptor(key, _knownPart(key));
    }

    function requireCurrentManifest(bytes32 record, bytes32 artistId)
        external
        view
        returns (T.Plan memory)
    {
        _fresh();
        T.Plan storage p = _knownRecord(record);
        if (artistId == 0 || artistId != p.carrier.artistId) revert T.InvalidViewManifest();
        _current(_recordPlans[record], p);
        return p;
    }

    function _current(bytes32 key, T.Plan storage p) private view {
        T.Header memory h = Reads.header(_configuration, p.header.checkpointId);
        if (
            keccak256(abi.encode(h)) != keccak256(abi.encode(p.header)) || p.nextPart != p.partCount
                || p.nextRow != h.tokenCount
        ) revert T.ViewManifestChanged(key);
        T.Descriptor[] memory parts = new T.Descriptor[](p.partCount);
        uint64 row;
        uint256 previous;
        bytes32 chain = keccak256(abi.encode(CHAIN, key, h));
        for (uint16 i; i < p.partCount; ++i) {
            bytes32 partKey = _planParts[key][i];
            T.Part storage part = _knownPart(partKey);
            if (
                part.first != row || part.firstToken <= previous
                    || part.carrier.artistId != p.carrier.artistId
                    || keccak256(abi.encode(part.header)) != keccak256(abi.encode(h))
            ) revert T.ViewManifestOrder(i);
            _partCurrent(partKey, part);
            parts[i] = Encoding.descriptor(partKey, part);
            chain = keccak256(abi.encode(CHAIN, chain, i, parts[i]));
            row += part.count;
            previous = part.lastToken;
        }
        if (row != h.tokenCount || previous != p.previousToken || chain != p.partChain) {
            revert T.ViewManifestChanged(key);
        }
        bytes memory raw = _carrier(p.carrier, Definitions.INDEX, Definitions.INDEX_CANON);
        bytes memory expected = Encoding.index(_configuration, h, p.carrier.artistId, parts);
        if (keccak256(raw) != keccak256(expected)) revert T.ViewManifestChanged(key);
    }

    function _partCurrent(bytes32 key, T.Part storage p) private view {
        if (keccak256(abi.encode(PART, block.chainid, address(this), configurationHash, p)) != key)
        {
            revert T.ViewManifestChanged(key);
        }
        _carrier(p.carrier, Definitions.PART, Definitions.PART_CANON);
    }

    function _carrier(T.Carrier memory s, bytes32 schema, bytes32 canon)
        private
        view
        returns (bytes memory raw)
    {
        T.Carrier memory now_;
        (now_, raw) = Reads.carrier(
            _configuration, s.artifactHash, s.coverageHash, s.artistId, schema, canon, s.byteLength
        );
        if (keccak256(abi.encode(now_)) != keccak256(abi.encode(s))) {
            revert T.ViewManifestChanged(s.artifactHash);
        }
    }

    function _fresh() private view {
        Read.pin(address(Reads), readWorkerCodeHash);
        Read.pin(address(Encoding), encodingWorkerCodeHash);
        Reads.pins(_configuration);
        Reads.documents(_configuration);
    }

    function _knownPart(bytes32 key) private view returns (T.Part storage p) {
        p = _parts[key];
        if (key == 0 || p.count == 0) revert T.ViewManifestUnknown(key);
    }

    function _knownPlan(bytes32 key) private view returns (T.Plan storage p) {
        p = _plans[key];
        if (key == 0 || p.header.tokenCount == 0) revert T.ViewManifestUnknown(key);
    }

    function _knownRecord(bytes32 key) private view returns (T.Plan storage p) {
        p = _plans[_recordPlans[key]];
        if (key == 0 || p.recordHash != key) revert T.ViewManifestUnknown(key);
    }

    function _hash(bytes memory raw, uint256 offset, uint256 length)
        private
        pure
        returns (bytes32 result)
    {
        if (offset > raw.length || length > raw.length - offset) {
            revert T.InvalidViewManifest();
        }
        assembly ("memory-safe") { result := keccak256(add(add(raw, 32), offset), length) }
    }
}
