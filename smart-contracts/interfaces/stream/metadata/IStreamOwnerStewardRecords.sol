// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamOwnerRecords.sol";
import "./StreamOwnerNoticeTypes.sol";

/// @notice Authenticated, notice-only steward designations in the original owner dossier.
/// @dev A designation never grants signing, writing, transfer or veto authority.
interface IStreamOwnerStewardRecords {
    error TypedOwnerRecordRequired();
    error InvalidOwnerNoticeRecord();
    error OwnerNoticeDefinitionUnavailable(bytes32 documentId);
    error StewardPredecessorChanged(bytes32 expected, bytes32 supplied);

    event OwnerStewardDesignated(
        uint256 indexed tokenId,
        address indexed owner,
        bytes32 indexed recordHash,
        bytes32 predecessor,
        uint16 schemaVersion
    );

    function recordStewardDesignation(
        uint256 tokenId,
        IStreamOwnerRecords.OwnerRecord calldata record,
        StreamOwnerNoticeTypes.Designation calldata designation
    ) external;

    /// @dev Uses the unchanged StreamOwnerRecord EIP-712 payload, domain and unordered nonce.
    function recordStewardDesignationFor(
        uint256 tokenId,
        IStreamOwnerRecords.OwnerRecord calldata record,
        address owner,
        uint256 nonce,
        uint64 deadline,
        bytes calldata signature,
        StreamOwnerNoticeTypes.Designation calldata designation
    ) external;

    /// @notice Permanent latest designation authored by the named owner for this token.
    function stewardDesignationFor(uint256 tokenId, address owner)
        external
        view
        returns (bytes32 recordHash);

    /// @notice Current custody and that owner's latest designation; burns have no current owner.
    function currentStewardDesignation(uint256 tokenId)
        external
        view
        returns (address owner, bytes32 recordHash);
}
