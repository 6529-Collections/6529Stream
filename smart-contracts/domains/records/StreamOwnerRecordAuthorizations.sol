// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/IStreamOwnerRecords.sol";
import "../metadata/StreamOwnerRecordHash.sol";
import "../metadata/StreamOwnerRecordSignatures.sol";

/// @notice Original owner EIP712 and nonce preparation under the host's shared guard.
/// @dev Delegatecall preserves the original verifier address and submitter; append failure rolls back nonce use.
library StreamOwnerRecordAuthorizations {
    struct SignedInput {
        uint256 tokenId;
        IStreamOwnerRecords.OwnerRecord record;
        address owner;
        uint256 nonce;
        uint64 deadline;
        bytes signature;
        uint256 signatureGas;
    }
    event OwnerRecordNonceRevoked(
        address indexed owner, uint256 indexed nonce, bool relayed, uint16 schemaVersion
    );

    function digest(
        uint256 tokenId,
        IStreamOwnerRecords.OwnerRecord calldata r,
        address owner,
        uint256 nonce,
        uint64 deadline
    ) public view returns (bytes32) {
        return StreamOwnerRecordHash.record(tokenId, r, owner, nonce, deadline);
    }

    function revocation(address owner, uint256 nonce, uint64 deadline)
        public
        view
        returns (bytes32)
    {
        return StreamOwnerRecordHash.revocation(owner, nonce, deadline);
    }

    function prepare(
        mapping(address => mapping(uint256 => bool)) storage used,
        SignedInput calldata i
    ) public returns (IStreamOwnerRecords.Receipt memory receipt, bytes memory bundle) {
        _fresh(used, i.owner, i.nonce);
        _deadline(i.deadline);
        receipt.owner = i.owner;
        receipt.relayed = true;
        receipt.nonce = i.nonce;
        receipt.deadline = i.deadline;
        receipt.authorizationDigest =
            StreamOwnerRecordHash.record(i.tokenId, i.record, i.owner, i.nonce, i.deadline);
        receipt.signatureScheme = StreamOwnerRecordSignatures.verify(
            i.owner, receipt.authorizationDigest, i.signature, i.signatureGas
        );
        bundle = abi.encode(
            StreamOwnerRecordHash.domain(),
            StreamOwnerRecordHash.words(i.tokenId, i.record, i.owner, i.nonce, i.deadline),
            i.signature
        );
        used[i.owner][i.nonce] = true;
    }

    function revoke(
        mapping(address => mapping(uint256 => bool)) storage used,
        address owner,
        uint256 nonce,
        bool relayed
    ) public {
        _fresh(used, owner, nonce);
        used[owner][nonce] = true;
        emit OwnerRecordNonceRevoked(owner, nonce, relayed, 1);
    }

    function revokeFor(
        mapping(address => mapping(uint256 => bool)) storage used,
        address owner,
        uint256 nonce,
        uint64 deadline,
        bytes calldata signature,
        uint256 cap
    ) public {
        _fresh(used, owner, nonce);
        _deadline(deadline);
        StreamOwnerRecordSignatures.verify(
            owner, StreamOwnerRecordHash.revocation(owner, nonce, deadline), signature, cap
        );
        revoke(used, owner, nonce, true);
    }

    function _fresh(
        mapping(address => mapping(uint256 => bool)) storage used,
        address owner,
        uint256 nonce
    ) private view {
        if (owner == address(0)) {
            revert IStreamOwnerRecords.InvalidOwnerRecordSignature(owner);
        }
        if (used[owner][nonce]) revert IStreamOwnerRecords.OwnerRecordNonceUsed(owner, nonce);
    }

    function _deadline(uint64 deadline) private view {
        if (deadline < block.timestamp) {
            revert IStreamOwnerRecords.OwnerRecordDeadlineExpired(deadline);
        }
    }
}
