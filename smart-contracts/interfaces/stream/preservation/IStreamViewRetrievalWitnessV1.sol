// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamViewRetrievalWitnessTypesV1 as T } from "./StreamViewRetrievalWitnessTypesV1.sol";
import { StreamFinalityScope } from "../finality/StreamArtworkFinalityTypes.sol";
import { StreamBundleArchiveTypes as B } from "./StreamBundleArchiveTypes.sol";

interface IStreamViewRetrievalWitnessV1 {
    event ViewRetrievalRecorded(
        bytes32 indexed recordHash,
        bytes32 indexed sourceKey,
        address indexed writer,
        T.Receipt receipt
    );
    event ViewRetrievalRevoked(
        bytes32 indexed recordHash, address indexed writer, bytes32 reasonHash
    );
    function configuration() external view returns (T.Configuration memory);
    function configurationHash() external view returns (bytes32);
    function retrievalProfile() external pure returns (bytes32);
    function prepare(T.Request calldata request)
        external
        view
        returns (T.Observation memory observation, bytes32 digest);
    function publish(T.Request calldata request, bytes calldata signature)
        external
        returns (bytes32 recordHash);
    function record(bytes32 recordHash) external view returns (T.Receipt memory);
    function encoded(bytes32 recordHash) external view returns (bytes memory);
    function requireCurrent(bytes32 recordHash)
        external
        view
        returns (T.Receipt memory, B.Admission memory);
    function requireCorrespondence(bytes32 recordHash)
        external
        view
        returns (T.Source memory, T.Receipt memory, B.Admission memory);
    function revoke(bytes32 recordHash, bytes32 reasonHash) external;
    function revoked(bytes32 recordHash) external view returns (bool);
    function revocationEpoch(StreamFinalityScope calldata scope) external view returns (uint64);
    function nonceUsed(bytes32 nonceKey) external view returns (bool);
}
