// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamRevenueResolver } from "../../interfaces/stream/revenue/IStreamRevenueResolver.sol";

/// @dev Existing resolver storage precedes appended governed-gas state.
abstract contract StreamPrimaryResolverState {
    struct PrimaryTemplate {
        bool exists;
        bytes32 entriesHash;
        bytes32 metadataURIHash;
        IStreamRevenueResolver.PrimaryTemplateEntry[] entries;
    }

    struct PrimaryAssignment {
        bool exists;
        uint8 assignmentType;
        bytes32 profileId;
        bytes32 templateId;
        bytes32 policyHash;
        bool frozen;
    }

    mapping(bytes32 => PrimaryTemplate) internal _templates;
    mapping(bytes32 => PrimaryAssignment) internal _primaryAssignments;
}
