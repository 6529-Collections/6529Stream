// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Canonical read-only shape of the additive collection policy producer.
/// @dev The producer's permanent interfaces and V1 finality tuple are unchanged.
library StreamEntropyPolicyConsumerTypes {
    bytes4 internal constant CAPABILITY = 0x4583f7e1;
    bytes4 internal constant STATIC_CAPABILITY = 0x40016975;
    bytes32 internal constant FAMILY =
        0x0d9d63287ae079e8c4867d6a82952c694dccd17190f625997cfcf8dccbe9bcb2;

    struct Policy {
        bool configured;
        bool explicitPolicy;
        bool frozen;
        uint8 mode;
        uint8 securityClass;
        uint8 renderRequirement;
        uint64 revision;
        uint32 providerEpoch;
        bytes32 policyHash;
        bytes32 contentStateHash;
        bytes32 lastActionId;
        bytes32 artistConsentRecord;
    }

    struct Terminal {
        address coordinator;
        bytes32 coordinatorCodeHash;
        uint8 status;
        Policy policy;
    }
}

interface IStreamEntropyPolicyConsumerRead {
    function collectionEntropyPolicy(uint256 collectionId)
        external
        view
        returns (StreamEntropyPolicyConsumerTypes.Policy memory);
}

/// @dev Read-only ABI mirror of IStreamEntropyTerminalFacts; all twelve policy words are retained.
interface IStreamEntropyPolicyStaticRead {
    function staticTerminalEntropyFacts(uint256 tokenId)
        external
        view
        returns (
            uint256 collectionId,
            StreamEntropyPolicyConsumerTypes.Policy memory policy,
            uint8 status,
            bytes32 seed,
            bytes32 requestKey
        );
}
