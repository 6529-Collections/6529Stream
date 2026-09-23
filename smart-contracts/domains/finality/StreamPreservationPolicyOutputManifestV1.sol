// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyOutputManifestBase as Base
} from "./StreamPreservationPolicyOutputManifestBase.sol";
import {
    StreamPreservationPolicyOutputSchemasV1 as Definitions
} from "./StreamPreservationPolicyOutputSchemasV1.sol";

/// @notice Complete exact covered output manifest for the fixed original token interpretation.
contract StreamPreservationPolicyOutputManifestV1 is Base {
    bytes32 public constant SCHEMA_ID = Definitions.SCHEMA;
    bytes32 public constant CANONICALIZATION_ID = Definitions.CANON;

    constructor(
        address core_,
        address checkpoint_,
        address coverage_,
        address executor,
        GasParameterConfig memory readGas
    ) Base(core_, checkpoint_, coverage_, executor, readGas, false) { }
}
