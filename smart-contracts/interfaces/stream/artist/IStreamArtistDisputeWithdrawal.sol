// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamArtistAttributionDisputes.sol";
import { StreamArtistAttributionDisputeTypes as AD } from "./IStreamArtistAttributionDisputes.sol";

library StreamArtistDisputeWithdrawalTypes {
    struct Outcome {
        bytes32 recordHash;
        bytes32 counterStatementRecordHash;
        uint8 restoredState;
    }
}

/// @notice Additive operation61; original OPEN remains action1 only.
interface IStreamArtistDisputeWithdrawal {
    event AttributionDisputeWithdrawn(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed disputeRecordHash,
        address indexed signer,
        uint64 bindingGeneration,
        uint8 authorityClass,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        uint256 nonce,
        uint64 recordedAt,
        bytes32 withdrawalRecordHash,
        bytes32 counterStatementRecordHash,
        uint8 restoredState
    );
    function withdrawAttributionDispute(
        AD.Filing calldata p,
        AD.Standing calldata standing,
        T.Authorization calldata a
    ) external returns (bytes32);
    function attributionDisputeWithdrawal(bytes32 opening)
        external
        view
        returns (StreamArtistDisputeWithdrawalTypes.Outcome memory);
}

interface IStreamArtistDisputeWithdrawalCoordinator {
    function coordinateWithdrawAttributionDispute(
        address actor,
        AD.Filing calldata p,
        AD.Standing calldata standing,
        T.Authorization calldata a
    ) external returns (bytes32);
}

interface IStreamArtistDisputeWithdrawalOwner {
    function applyDisputeWithdrawal(
        T.ActionContext calldata c,
        AD.Filing calldata p,
        AD.Admission calldata admission,
        uint256 nonce
    ) external returns (bytes32);
    function attributionDisputeWithdrawal(bytes32 opening)
        external
        view
        returns (StreamArtistDisputeWithdrawalTypes.Outcome memory);
}
