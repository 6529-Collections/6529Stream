// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamArtistRecoveredTimingInventory
} from "../../interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    IStreamArtistIdentityOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityOwner.sol";

import {
    IStreamArtistIdentityRecoveryOwnerV3
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";

import {
    StreamArtistRecoveredIdentityRecordRows as RecordRows
} from "./StreamArtistRecoveredIdentityRecordRows.sol";
import {
    StreamArtistRecoveredIdentityRecordAuthority as RecordAuthority
} from "./StreamArtistRecoveredIdentityRecordAuthority.sol";
import {
    StreamArtistRecoveredIdentityRecordRecovery as RecordRecovery
} from "./StreamArtistRecoveredIdentityRecordRecovery.sol";
import {
    StreamArtistRecoveredIdentityRecordContinuations as RecordContinuations
} from "./StreamArtistRecoveredIdentityRecordContinuations.sol";
import {
    StreamArtistRecoveredIdentityRecordFindings as RecordFindings
} from "./StreamArtistRecoveredIdentityRecordFindings.sol";

/// @notice Independent joins to original typed getters after the fixed raw export.
/// @dev Historical signatures are copied, never revalidated against today's signer readiness.
library StreamArtistRecoveredIdentityHydrationRecords {
    function validate(address owner, IH.Bundle calldata b) public view {
        _same(
            abi.encode(b.identity),
            abi.encode(IStreamArtistIdentityOwner(owner).identity(b.artistId)),
            b.artistId
        );
        if (
            IStreamArtistIdentityOwner(owner).activeIdentity(b.identity.authorityAddress)
                    != b.artistId
                || b.nextRegistrationNonce
                    != IStreamArtistIdentityOwner(owner).nextRegistrationNonce()
                || keccak256(b.identityDocument) != b.identity.identityRecordHash
        ) revert IH.InvalidRecoveredIdentity(b.artistId);
        _same(
            b.identityDocument,
            IStreamArtistIdentityOwner(owner).identityDocumentBytes(b.identity.identityRecordHash),
            b.artistId
        );
        for (uint256 i; i < b.documents.length; ++i) {
            if (keccak256(b.documents[i].document) != b.documents[i].documentHash) {
                revert IH.InvalidRecoveredIdentity(b.documents[i].documentHash);
            }
            _same(
                b.documents[i].document,
                IStreamArtistIdentityOwner(owner)
                    .identityDocumentBytes(b.documents[i].documentHash),
                b.documents[i].documentHash
            );
        }
        for (uint256 i; i < b.signatures.length; ++i) {
            _same(
                b.signatures[i].signature,
                IStreamArtistIdentityOwner(owner).signatureBundle(b.signatures[i].recordHash),
                b.signatures[i].recordHash
            );
        }
        RecordRows.validate(owner, b);
        RecordAuthority.validate(owner, b);
        RecordRecovery.validate(owner, b);
        RecordContinuations.validate(owner, b);
        RecordFindings.validate(owner, b);
        _same(
            abi.encode(b.timing.checkpoint),
            abi.encode(IStreamArtistRecoveredTimingInventory(owner).recoveredTimingCheckpoint()),
            b.artistId
        );
        _same(
            abi.encode(b.heads.inventory),
            abi.encode(
                IStreamArtistIdentityRecoveryOwnerV3(owner).recoveryRewindInventoryV3(b.artistId)
            ),
            b.artistId
        );
        if (
            b.heads.capabilityContinuation
                != IStreamArtistIdentityRecoveryOwnerV3(owner)
                    .latestRecoveryCapabilityContinuationV3(b.artistId)
        ) revert IH.InvalidRecoveredIdentity(b.artistId);
    }

    function _same(bytes memory a, bytes memory b, bytes32 key) private pure {
        if (keccak256(a) != keccak256(b)) revert IH.InvalidRecoveredIdentity(key);
    }
}
