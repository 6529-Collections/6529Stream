// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamMintOperationIdentity.sol";

/// @dev Type-only base preserves the Manager's inherited Solidity type name and has no storage.
abstract contract StreamMintTranscriptTypes {
    struct OperationTranscript {
        uint256 quantity;
        uint256 firstOperationNonce;
        bytes32 currentPolicyHash;
        bytes32 boundPolicyHash;
        bytes32 operationRoot;
        bytes32[] operationIds;
        IStreamMintLedger.CounterConsumption[] consumptions;
        StreamMintOperationIdentity.MintAuthorization authorization;
    }
}
