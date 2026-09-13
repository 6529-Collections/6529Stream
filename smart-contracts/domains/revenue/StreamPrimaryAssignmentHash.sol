// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamSplitFactory } from "../../interfaces/stream/revenue/IStreamSplitFactory.sol";

/// @notice Stateless canonical hashing in the resolver's compiler-linked context.
library StreamPrimaryAssignmentHash {
    struct Input {
        bytes32 revenueClass;
        uint8 scope;
        uint256 scopeId;
        uint8 assignmentType;
        bytes32 profileId;
        bytes32 templateId;
        bytes32 policyHash;
        bool frozen;
    }

    function hash(
        IStreamSplitFactory factory,
        address assetPolicy,
        bytes32 walletCodeHash,
        Input memory input,
        bytes32 templateEntries,
        bytes32 templateMetadata
    ) public view returns (bytes32) {
        bytes32 profileContext;
        if (input.assignmentType == 1 && input.profileId != bytes32(0)) {
            profileContext = keccak256(
                abi.encode(
                    keccak256("6529STREAM_PRIMARY_ASSIGNMENT_PROFILE_CONTEXT_V1"),
                    factory.walletFor(input.profileId),
                    factory.profileEntriesHash(input.profileId),
                    factory.profileMetadataURIHash(input.profileId)
                )
            );
        }
        bytes32 templateContext;
        if (input.assignmentType == 2 && input.templateId != bytes32(0)) {
            templateContext = keccak256(
                abi.encode(
                    keccak256("6529STREAM_PRIMARY_ASSIGNMENT_TEMPLATE_CONTEXT_V1"),
                    templateEntries,
                    templateMetadata
                )
            );
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_ASSIGNMENT_V1"),
                uint256(block.chainid),
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PRIMARY_ASSIGNMENT_RESOLVER_CONTEXT_V1"),
                        address(this),
                        address(factory),
                        assetPolicy,
                        walletCodeHash
                    )
                ),
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PRIMARY_ASSIGNMENT_SCOPE_CONTEXT_V1"),
                        input.revenueClass,
                        input.scope,
                        input.scopeId,
                        input.assignmentType
                    )
                ),
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PRIMARY_ASSIGNMENT_POINTER_CONTEXT_V1"),
                        input.profileId,
                        profileContext,
                        input.templateId,
                        templateContext
                    )
                ),
                input.policyHash,
                input.frozen
            )
        );
    }
}
