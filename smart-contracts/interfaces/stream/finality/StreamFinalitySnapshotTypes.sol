// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

struct StreamFinalitySnapshotEvidence {
    bytes32 inputHash;
    bytes32 recordHash;
    bytes32 manifestHash;
    bytes32 sourceHash;
    bytes32 inventoryPlan;
    bytes32 schemaHash;
    bytes32 profileHash;
    bytes32 canonicalizationHash;
    uint64 revision;
    uint32 manifestBytes;
    address publisher;
    uint8 snapshotAuthorizationClass;
    uint64 snapshotGrantRevision;
    uint8 displayAuthorizationClass;
    uint64 displayGrantRevision;
    bool locked;
    bytes32 lockEvidenceHash;
}
