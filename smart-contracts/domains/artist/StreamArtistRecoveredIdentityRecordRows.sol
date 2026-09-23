// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    IStreamArtistIdentityOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    IStreamArtistIdentityRevisionOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRevision.sol";
import {
    IStreamArtistDelegationOwner
} from "../../interfaces/stream/artist/IStreamArtistDelegationOwner.sol";
import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";

import {
    IStreamArtistIdentityRecoveryOwnerV3
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";

import {
    IStreamArtistSuccessionReads
} from "../../interfaces/stream/artist/IStreamArtistSuccessionRecords.sol";
import {
    IStreamArtistEstateOwner
} from "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";

import {
    IStreamArtistStewardSanctionGrant
} from "../../interfaces/stream/artist/IStreamArtistStewardSanctionGrant.sol";

import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";

/// @notice Original complete Identity rows getter comparisons.
library StreamArtistRecoveredIdentityRecordRows {
    function validate(address owner, IH.Bundle calldata b) public view {
        for (uint256 i; i < b.revisions.length; ++i) {
            IH.RevisionRow calldata r = b.revisions[i];
            if (
                r.record.artistId != b.artistId
                    || keccak256(r.document) != r.record.revisedRecordHash
            ) revert IH.InvalidRecoveredIdentity(r.record.recordHash);
            _same(
                abi.encode(r.record),
                abi.encode(
                    IStreamArtistIdentityRevisionOwner(owner)
                        .identityRevisionRecord(r.record.recordHash)
                ),
                r.record.recordHash
            );
            _same(
                r.document,
                IStreamArtistIdentityOwner(owner).identityDocumentBytes(r.record.revisedRecordHash),
                r.record.recordHash
            );
            _same(
                abi.encode(r.association),
                abi.encode(
                    IStreamArtistRotationReads(owner)
                        .identityRevisionProvisionalAssociation(r.record.recordHash)
                ),
                r.record.recordHash
            );
            _status(owner, W.RecordKind.IDENTITY_REVISION, r.record.recordHash, r.status);
            if (
                r.rewindContinuation
                    != IStreamArtistIdentityRecoveryOwnerV3(owner)
                        .identityRevisionRecoveryContinuationV3(r.record.recordHash)
            ) revert IH.InvalidRecoveredIdentity(r.record.recordHash);
        }
        for (uint256 i; i < b.delegations.length; ++i) {
            IH.DelegationRow calldata r = b.delegations[i];
            if (r.record.grant.artistId != b.artistId) {
                revert IH.InvalidRecoveredIdentity(r.recordHash);
            }
            _same(
                abi.encode(r.record),
                abi.encode(IStreamArtistDelegationOwner(owner).delegationRecord(r.recordHash)),
                r.recordHash
            );
            (, uint64 epoch,) = IStreamArtistEstateOwner(owner).delegationEpochState(r.recordHash);
            if (r.epoch != epoch) revert IH.InvalidRecoveredIdentity(r.recordHash);
        }
        for (uint256 i; i < b.designations.length; ++i) {
            IH.DesignationRow calldata r = b.designations[i];
            if (r.record.terms.artistId != b.artistId) {
                revert IH.InvalidRecoveredIdentity(r.record.recordHash);
            }
            _same(
                abi.encode(r.record),
                abi.encode(
                    IStreamArtistSuccessionReads(owner)
                        .successorDesignationRecord(r.record.recordHash)
                ),
                r.record.recordHash
            );
            _status(owner, W.RecordKind.SUCCESSOR_DESIGNATION, r.record.recordHash, r.status);
        }
        for (uint256 i; i < b.directives.length; ++i) {
            IH.DirectiveRow calldata r = b.directives[i];
            if (r.record.terms.artistId != b.artistId) {
                revert IH.InvalidRecoveredIdentity(r.record.recordHash);
            }
            _same(
                abi.encode(r.record),
                abi.encode(
                    IStreamArtistSuccessionReads(owner).estateDirectiveRecord(r.record.recordHash)
                ),
                r.record.recordHash
            );
            _same(
                r.payload,
                IStreamArtistSuccessionReads(owner).estateDirectivePayload(r.record.recordHash),
                r.record.recordHash
            );
            _status(owner, W.RecordKind.ESTATE_DIRECTIVE, r.record.recordHash, r.status);
        }
        for (uint256 i; i < b.sanctionGrants.length; ++i) {
            IH.GrantRow calldata r = b.sanctionGrants[i];
            if (r.record.terms.artistId != b.artistId) {
                revert IH.InvalidRecoveredIdentity(r.record.recordHash);
            }
            _same(
                abi.encode(r.record),
                abi.encode(
                    IStreamArtistStewardSanctionGrant(owner)
                        .stewardSanctionGrantRecord(r.record.recordHash)
                ),
                r.record.recordHash
            );
            _status(owner, W.RecordKind.STEWARD_SANCTION_GRANT, r.record.recordHash, r.status);
        }
    }

    function _status(address owner, W.RecordKind kind, bytes32 hash, W.StatusV3 calldata status)
        private
        view
    {
        _same(
            abi.encode(status),
            abi.encode(
                IStreamArtistIdentityRecoveryOwnerV3(owner).recoveryRecordStatusV3(kind, hash)
            ),
            hash
        );
    }

    function _same(bytes memory a, bytes memory b, bytes32 key) private pure {
        if (keccak256(a) != keccak256(b)) revert IH.InvalidRecoveredIdentity(key);
    }
}
