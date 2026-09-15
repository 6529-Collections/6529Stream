// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Exact root8b7b5822 fixed-consumer/interface bodies, with local fixture names.
// No full reference-publication or external-archive test contract is imported here.

import "./PreservationNativeDependencies.sol";
import {
    StreamSnapshotSourceReads
} from "../../../smart-contracts/domains/records/StreamSnapshotSourceReads.sol";
import "../../../smart-contracts/domains/preservation/StreamExternalArtifactCoverage.sol";
import "../../../smart-contracts/domains/preservation/StreamArweaveObjectCheckpointVerifier.sol";
import "../../../smart-contracts/domains/governance/StreamRoleRegistry.sol";
import "../../helpers/OfficialSafeFixture.sol";
import {
    StreamReferenceRenderPublication
} from "../../../smart-contracts/domains/preservation/StreamReferenceRenderPublication.sol";
import {
    StreamReferenceRenderTypes
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamReferenceRendererCatalog
} from "../../../smart-contracts/domains/records/StreamReferenceRendererCatalog.sol";
import {
    StreamReferenceEnvironmentJson
} from "../../../smart-contracts/domains/records/StreamReferenceEnvironmentJson.sol";
import {
    StreamReferenceRenderDefinitions
} from "../../../smart-contracts/domains/records/StreamReferenceRenderDefinitions.sol";

import {
    StreamFinalityReferenceReads
} from "../../../smart-contracts/domains/finality/StreamFinalityReferenceReads.sol";
import {
    StreamFinalityReferenceEvidence
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityReferenceTypes.sol";

contract PreservationReferenceConsumer {
    StreamFinalityReferenceReads.Dependencies private fixedDependencies;

    constructor(StreamFinalityReferenceReads.Dependencies memory d) {
        fixedDependencies = d;
    }

    function read(StreamFinalityScope calldata scope, bytes32 hash, uint64 revision, bool locked)
        external
        view
        returns (StreamFinalityReferenceEvidence memory)
    {
        return locked
            ? StreamFinalityReferenceReads.requireLocked(fixedDependencies, scope, hash, revision)
            : StreamFinalityReferenceReads.requireCurrent(fixedDependencies, scope, hash, revision);
    }
}

import {
    StreamReferenceRenderSourceReads
} from "../../../smart-contracts/domains/preservation/StreamReferenceRenderSourceReads.sol";

interface PreservationReferenceVm {
    function toString(bytes calldata) external pure returns (string memory);
    function parseJsonString(string calldata, string calldata) external pure returns (string memory);
    function parseJsonUint(string calldata, string calldata) external pure returns (uint256);
}
