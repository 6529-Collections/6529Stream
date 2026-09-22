// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Source-only compilation root for the genuine dynamic Scenario artifact. Forge does not discover
// getCode dependencies from strings. Keep these implementation inputs in the current-profile
// request without adding their import graph to the independently selected export host's metadata.
// This file declares no executable/test product and supplies no native artifact or owner evidence.
// The canonical request capture still requires byte-for-byte source equality, all 90 literal
// artifact obligations remain anchored by CallerArtifacts, and the actual Scenario owner plus its
// complete fixture/native/constructor/link closure must be authenticated separately.
import {
    StreamCurrentAuthorityPreservationCallerScenario
} from "../../helpers/StreamCurrentAuthorityPreservationCallerScenario.sol";
