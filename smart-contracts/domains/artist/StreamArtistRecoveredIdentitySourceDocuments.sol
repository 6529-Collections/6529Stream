// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";

/// @notice Fixed original Identity source validation stage.
library StreamArtistRecoveredIdentitySourceDocuments {
    function validate(IH.Bundle calldata b) public pure {
        if (keccak256(b.identityDocument) != b.identity.identityRecordHash) {
            revert IH.InvalidRecoveredIdentity(b.artistId);
        }
        _document(b, b.identity.identityRecordHash);
        for (uint256 i; i < b.revisions.length; ++i) {
            _document(b, b.revisions[i].record.previousRecordHash);
            _document(b, b.revisions[i].record.revisedRecordHash);
        }
        bytes32 previous;
        for (uint256 i; i < b.documents.length; ++i) {
            IH.DocumentRow calldata d = b.documents[i];
            if (d.documentHash <= previous || keccak256(d.document) != d.documentHash) {
                revert IH.InvalidRecoveredIdentity(d.documentHash);
            }
            previous = d.documentHash;
            bool used = d.documentHash == b.identity.identityRecordHash;
            for (uint256 j; j < b.revisions.length; ++j) {
                if (
                    d.documentHash == b.revisions[j].record.previousRecordHash
                        || d.documentHash == b.revisions[j].record.revisedRecordHash
                ) used = true;
            }
            if (!used) revert IH.InvalidRecoveredIdentity(d.documentHash);
        }
    }

    function _document(IH.Bundle calldata b, bytes32 key) private pure {
        for (uint256 i; i < b.documents.length; ++i) {
            if (b.documents[i].documentHash == key) return;
        }
        revert IH.InvalidRecoveredIdentity(key);
    }
}
