// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamCollectionMetadataV1.sol";

/// @notice Bounded original record receipt independent of the record's URI length.
/// @dev A consumer supplying the record as a witness must recompute its complete original
///      hash and join this receipt to the actual indexed record history. No authority is added.
interface IStreamCollectionRecordReceipts {
    /// @dev Exactly nine ABI words. Unknown record hashes retain UnknownMetadataRecord behavior.
    function collectionRecordReceipt(bytes32 recordHash)
        external
        view
        returns (IStreamCollectionMetadataV1.RecordReceipt memory);
}
