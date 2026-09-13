// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArchivalTypes as A } from "./StreamArchivalTypes.sol";
import { StreamExternalArtifactTypes as E } from "./StreamExternalArtifactTypes.sol";

interface IStreamExternalArtifactCoverage {
    event ExternalObjectRecorded(bytes32 indexed objectHash, E.ObjectIdentity objectIdentity);
    event ExternalFamilyRecorded(
        bytes32 indexed familyHash, bytes32 indexed actionId, string name, A.Family family
    );
    event ExternalFamilyStatus(
        bytes32 indexed familyHash, bytes32 indexed actionId, uint8 status, uint64 revision
    );
    event ExternalReceiptRecorded(
        bytes32 indexed receiptHash, bytes32 indexed objectHash, E.Receipt receipt
    );
    event ExternalFixityRecorded(
        bytes32 indexed fixityHash, bytes32 indexed receiptHash, E.Fixity fixity
    );
    event ExternalCoverageRecorded(
        bytes32 indexed coverageHash, bytes32 indexed objectHash, E.Coverage coverage
    );

    function supportsInterface(bytes4 id) external view returns (bool);
    function core() external view returns (address);
    function roleRegistry() external view returns (address);
    function checkpointVerifier() external view returns (address);
    function profileHash() external view returns (bytes32);
    function recordObject(E.ObjectIdentity calldata objectIdentity) external returns (bytes32);
    function objectIdentity(bytes32 objectHash) external view returns (E.ObjectIdentity memory);
    function familyRegistrationContext(string calldata name, A.Family calldata family)
        external
        view
        returns (bytes32 hash, bytes32 scope, bytes32 oldHash, bytes32 newHash);
    function admitFamily(string calldata name, A.Family calldata family) external returns (bytes32);
    function familyStatusContext(bytes32 hash, uint8 status)
        external
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash);
    function setFamilyStatus(bytes32 hash, uint8 status) external;
    function family(bytes32 hash)
        external
        view
        returns (A.Family memory, uint8 status, uint64 revision);
    function possessionHash(E.Receipt calldata receipt) external view returns (bytes32);
    function receiptDigest(E.Receipt calldata receipt) external view returns (bytes32);
    function recordReceipt(
        E.Receipt calldata receipt,
        bytes calldata identifier,
        bytes calldata signature
    ) external returns (bytes32);
    function receipt(bytes32 hash)
        external
        view
        returns (E.Receipt memory, bytes memory identifier, bytes memory signature);
    function fixityDigest(E.Fixity calldata fixity) external view returns (bytes32);
    function recordFixity(E.Fixity calldata fixity, bytes calldata signature)
        external
        returns (bytes32);
    function fixity(bytes32 hash) external view returns (E.Fixity memory, bytes memory signature);
    function latestFixity(bytes32 receiptHash) external view returns (bytes32);
    function recordCoverage(bytes32 firstReceipt, bytes32 secondReceipt) external returns (bytes32);
    function coverage(bytes32 hash) external view returns (E.Coverage memory);
    function requireCoverage(bytes32 hash, bytes32 artistId, bytes32 objectHash)
        external
        view
        returns (E.Coverage memory);
    function nonceUsed(bytes32 key) external view returns (bool);
}
