// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Current independently validated facts an artist reviews before recording a sanction.
/// @dev The permanent sanction subject excludes the sanction record/signature and the mutable
///      artifact-validation cache. This result is a candidate read, not an executed finality record.
struct StreamArtistSanctionPreparation {
    bytes32 sanctionSubjectHash;
    bytes32 coreFactsHash;
    bytes32 nonSanctionComponentsHash;
    bytes32 scopeInputsHash;
}
