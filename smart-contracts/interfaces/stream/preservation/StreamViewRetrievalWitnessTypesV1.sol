// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamFinalityScope } from "../finality/StreamArtworkFinalityTypes.sol";
import { StreamExternalArtifactTypes as E } from "./StreamExternalArtifactTypes.sol";

/// @notice Attributed retrieval observations, never a generic network resolver or URI digest.
library StreamViewRetrievalWitnessTypesV1 {
    bytes32 internal constant PROFILE = keccak256("6529STREAM_VIEW_ATTRIBUTED_RETRIEVAL_V1");
    bytes32 internal constant OBSERVATION = keccak256("6529STREAM_VIEW_RETRIEVAL_OBSERVATION_V1");
    bytes32 internal constant SOURCE = keccak256("6529STREAM_VIEW_RETRIEVAL_SOURCE_V1");
    bytes32 internal constant RECORD = keccak256("6529STREAM_VIEW_RETRIEVAL_RECORD_V1");
    bytes32 internal constant NONCE = keccak256("6529STREAM_VIEW_RETRIEVAL_NONCE_V1");
    bytes32 internal constant ROLE = keccak256("VIEW_ATTRIBUTED_RETRIEVAL_IMAGE");
    uint256 internal constant MAX_BYTES = 524288;

    struct Configuration {
        address core;
        bytes32 coreCodeHash;
        address router;
        bytes32 routerCodeHash;
        address checkpoint;
        bytes32 checkpointCodeHash;
        address archive;
        bytes32 archiveCodeHash;
        uint256 chainId;
        uint32 readGas;
        uint32 sourceGas;
        uint32 archiveGas;
        uint32 signatureGas;
    }

    struct Source {
        StreamFinalityScope scope;
        address core;
        address router;
        bytes32 adoptionRecord;
        bytes32 adoptionSourceHash;
        address declaration;
        bytes32 declarationRecord;
        bytes32 payloadHash;
        bytes32 checkpointContextHash;
        string requestedURI;
    }

    /// @dev kind1 is observed HTTP redirect; kind2 attributed byte-identical mirror;
    /// kind3 attributed Arweave manifest path interpretation, with full admitted manifest bytes.
    struct Step {
        uint8 kind;
        string fromURI;
        string toURI;
        uint16 status;
        bytes32 manifestObject;
        bytes32 manifestCoverage;
        bytes manifestBytes;
    }

    struct Request {
        StreamFinalityScope scope;
        bytes32 coverageHash;
        Step[] steps;
        string resolvedURI;
        uint64 observedAt;
        uint256 nonce;
        uint64 deadline;
    }

    struct Observation {
        Source source;
        E.ObjectIdentity object;
        E.Coverage coverage;
        Step[] steps;
        string resolvedURI;
        address writer;
        uint64 observedAt;
        uint256 nonce;
        uint64 deadline;
    }

    struct Receipt {
        bytes32 recordHash;
        bytes32 sourceKey;
        bytes32 observationHash;
        bytes32 objectHash;
        bytes32 coverageHash;
        address writer;
        uint64 recordedAt;
        bytes32 payloadHash;
        uint32 payloadBytes;
    }
    error InvalidViewRetrieval();
    error ViewRetrievalDependency(address target);
    error ViewRetrievalChanged(bytes32 record);
    error ViewRetrievalNonce(bytes32 key);
    error ViewRetrievalUnknown(bytes32 record);
    error ViewRetrievalRevoked(bytes32 record);
}
