// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyOutputManifestBase as Base
} from "./StreamPreservationPolicyOutputManifestBase.sol";
import {
    StreamPreservationPolicyOutputSchemasV2 as Definitions
} from "./StreamPreservationPolicyOutputSchemasV2.sol";

/// @notice Complete exact covered output manifest for the fixed closed token family interpretation.
contract StreamPreservationPolicyOutputManifestV2 is Base {
    bytes32 public constant SCHEMA_ID = Definitions.SCHEMA;
    bytes32 public constant CANONICALIZATION_ID = Definitions.CANON;

    constructor(
        address core_,
        address checkpoint_,
        address coverage_,
        address executor,
        GasParameterConfig memory readGas
    ) Base(core_, checkpoint_, coverage_, executor, readGas, true) { }
}
