// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { ScopedBundleArchiveFixture } from "./ScopedBundleArchiveFixture.sol";
import { OfficialSafe } from "./OfficialSafeFixture.sol";
import {
    StreamViewRetrievalWitnessV1 as Witness
} from "../../smart-contracts/domains/preservation/StreamViewRetrievalWitnessV1.sol";
import {
    StreamViewRetrievalWitnessTypesV1 as T
} from "../../smart-contracts/interfaces/stream/preservation/StreamViewRetrievalWitnessTypesV1.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as C
} from "../../smart-contracts/interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    IStreamViewPreservationContentCheckpointV1 as CP
} from "../../smart-contracts/interfaces/stream/finality/IStreamViewPreservationContentCheckpointV1.sol";
import {
    StreamViewAdoptionTypes as V
} from "../../smart-contracts/interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamSchemaDocumentStore as Store
} from "../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import {
    StreamViewPayloadBytes as PayloadBytes
} from "../../smart-contracts/domains/metadata/StreamViewPayloadBytes.sol";
import {
    StreamBundleArchiveTypes as B
} from "../../smart-contracts/interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamExternalArtifactTypes as E
} from "../../smart-contracts/interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import {
    StreamArchivalTypes as A
} from "../../smart-contracts/interfaces/stream/preservation/StreamArchivalTypes.sol";

interface RetrievalVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function expectRevert() external;
    function expectRevert(bytes calldata) external;
    function chainId(uint256) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

/// @dev Explicit selected Router and full-current checkpoint boundary. No Artist/op17 claim.
contract RetrievalRouterBoundary {
    address public immutable core;

    constructor(address c) {
        core = c;
    }
}

contract RetrievalCheckpointBoundary {
    C.Configuration private _configuration;
    C.Source private _source;

    constructor(C.Configuration memory c) {
        _configuration = c;
    }

    function configuration() external view returns (C.Configuration memory) {
        return _configuration;
    }

    function checkpointProfile() external pure returns (bytes32) {
        return C.PROFILE;
    }

    function supportsInterface(bytes4 i) external pure returns (bool) {
        return i == type(CP).interfaceId || i == 0x01ffc9a7;
    }

    function set(C.Source memory s) external {
        _source = s;
    }

    function currentSource(StreamFinalityScope memory scope)
        external
        view
        returns (C.Source memory)
    {
        require(
            keccak256(abi.encode(scope)) == keccak256(abi.encode(_source.adoption.input.scope)),
            "typed complete scope"
        );
        return _source;
    }
}

abstract contract ViewRetrievalWitnessFixture is ScopedBundleArchiveFixture {
    RetrievalVm internal constant rv =
        RetrievalVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    Witness internal witness;
    Store internal store;
    RetrievalRouterBoundary internal router;
    RetrievalCheckpointBoundary internal checkpoint;
    T.Configuration internal configuration;
    C.Source internal selected;
    StreamFinalityScope internal scope;
    bytes32 internal firstReceipt;
    bytes32 internal secondReceipt;
    bytes32 internal completeCoverage;
    string internal constant ORIGIN =
        "https://origin.example.invalid/assets/image.png?version=%2F#literal";
    string internal constant MIRROR = "https://mirror.example.invalid/exact-observed-bytes";
    string internal constant AR = "ar://ElP9Xu-yoWLv6x6Vy7JtbNUKYXxruXflEH6kwLA1QL0";

    function _setUpRetrieval() internal {
        _setupArchive();
        object.canonicalizationId = keccak256("RAW_BYTES");
        objectHash = host.recordObject(object);
        (firstReceipt, secondReceipt, completeCoverage) = _covered();
        store = new Store();
        router = new RetrievalRouterBoundary(address(core));
        C.Configuration memory c;
        c.core = address(core);
        c.coreCodeHash = address(core).codehash;
        c.router = address(router);
        c.routerCodeHash = address(router).codehash;
        c.chainId = block.chainid;
        c.readGas = 300000;
        c.servingGas = 2000000;
        checkpoint = new RetrievalCheckpointBoundary(c);
        scope = StreamFinalityScope(StreamFinalityScopeType.VIEW, 7, 0, bytes32(uint256(17)));
        selected.adoption.input.scope = scope;
        selected.adoption.input.viewRecordHash = keccak256("actual declaration boundary");
        selected.adoption.recordHash = keccak256("actual adopted record boundary");
        selected.adoption.sourceHash = keccak256("complete current source boundary");
        selected.adoption.adoptedAt = uint64(block.timestamp);
        selected.adoption.source.route.core = address(core);
        selected.adoption.source.route.coreCodeHash = address(core).codehash;
        selected.adoption.source.route.router = address(router);
        selected.adoption.source.route.routerCodeHash = address(router).codehash;
        selected.adoption.source.route.store = address(store);
        selected.adoption.source.route.storeCodeHash = address(store).codehash;
        selected.adoption.source.route.binding.views = address(checkpoint);
        selected.adoption.source.route.binding.viewsCodeHash = address(checkpoint).codehash;
        selected.contextHash = keccak256("complete checkpoint source/policy/admission boundary");
        _setURI(ORIGIN);
        configuration = T.Configuration(
            address(core),
            address(core).codehash,
            address(router),
            address(router).codehash,
            address(checkpoint),
            address(checkpoint).codehash,
            address(host),
            address(host).codehash,
            block.chainid,
            300000,
            2000000,
            2000000,
            400000
        );
        witness = new Witness(configuration);
    }

    function _setURI(string memory uri) internal {
        V.Payload memory p = V.Payload(
            keccak256("STREAM_ADOPTED_POLICY_VIEW_CONTEXT_V2"),
            "actual stored view",
            "typed upstream authority",
            uri,
            bytes("complete script bytes")
        );
        bytes memory raw = abi.encode(p);
        _upload(raw);
        V.Source memory s = selected.adoption.source;
        // Fresh payload capture clears all unused immutable carrier slots.
        for (uint256 i; i < 5; ++i) {
            s.payloadPointers[i] = address(0);
            s.payloadChunkHashes[i] = 0;
        }
        PayloadBytes.capture(address(store), raw, s);
        selected.adoption.source = s;
        checkpoint.set(selected);
    }

    function _upload(bytes memory raw) internal {
        for (uint256 at; at < raw.length; at += 8192) {
            uint256 n = raw.length - at;
            if (n > 8192) n = 8192;
            bytes memory part = new bytes(n);
            for (uint256 j; j < n; ++j) {
                part[j] = raw[at + j];
            }
            store.publishChunk(part);
        }
    }

    function _request(uint256 nonce) internal view returns (T.Request memory r) {
        r.scope = scope;
        r.coverageHash = completeCoverage;
        r.observedAt = uint64(block.timestamp);
        r.deadline = uint64(block.timestamp + 1 days);
        r.nonce = nonce;
        r.steps = new T.Step[](2);
        r.steps[0].kind = 1;
        r.steps[0].fromURI = ORIGIN;
        r.steps[0].toURI = "https://origin.example.invalid/final";
        r.steps[0].status = 307;
        r.steps[1].kind = 2;
        r.steps[1].fromURI = r.steps[0].toURI;
        r.steps[1].toURI = MIRROR;
        r.resolvedURI = MIRROR;
    }

    function _prepared(T.Request memory r)
        internal
        returns (T.Observation memory o, bytes memory sig)
    {
        bytes32 digest;
        (o, digest) = witness.prepare(r);
        sig = _sign(SECOND_AGENT, digest);
        _upload(abi.encode(o, sig));
    }

    function _publish(T.Request memory r) internal returns (bytes32 h) {
        (, bytes memory sig) = _prepared(r);
        h = witness.publish(r, sig);
    }

    function _manifest(bytes memory raw)
        internal
        returns (bytes32 manifestObject, bytes32 manifestCoverage)
    {
        E.ObjectIdentity memory finalObject = object;
        bytes32 finalHash = objectHash;
        bytes32 finalTx = transactionId;
        bytes32 finalCheckpoint = checkpointHash;
        object.contentHash = keccak256(raw);
        object.sha256Digest = sha256(raw);
        object.byteSize = uint64(raw.length);
        object.arweaveDataRoot = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(sha256(raw))), sha256(abi.encode(uint256(raw.length)))
            )
        );
        object.formatId = keccak256("complete attributed arweave manifest JSON bytes");
        objectHash = host.recordObject(object);
        manifestObject = objectHash;
        A.Checkpoint memory c = _checkpointTerms();
        c.transactionId = 0x0101010101010101010101010101010101010101010101010101010101010101;
        transactionId = c.transactionId;
        bytes memory dataPath = abi.encode(sha256(raw), uint256(raw.length));
        checkpointHash = verifier.recordCheckpoint(
            c, abi.encode(c.dataRoot, uint256(c.dataSize)), dataPath, dataPath, _certificate(c)
        );
        bytes32 first = _recordReceipt(true, 101);
        bytes32 second = _recordReceipt(false, 101);
        _recordFixity(first, 1, false);
        _recordFixity(second, 1, false);
        manifestCoverage = host.recordCoverage(first, second);
        object = finalObject;
        objectHash = finalHash;
        transactionId = finalTx;
        checkpointHash = finalCheckpoint;
    }

    function _key(uint256 nonce) internal returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_RETRIEVAL_NONCE_V1"), safeVm.addr(SECOND_AGENT), nonce
            )
        );
    }

    function _currentHash(bytes32 h) internal view returns (bytes32) {
        (T.Receipt memory r, B.Admission memory a) = witness.requireCurrent(h);
        return keccak256(abi.encode(r, a));
    }

    function _refusesCurrent(bytes32 h) internal {
        (bool ok,) = address(witness).staticcall(abi.encodeCall(witness.requireCurrent, (h)));
        require(!ok, "stale witness accepted");
    }
}
