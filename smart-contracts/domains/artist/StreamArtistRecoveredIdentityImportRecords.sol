// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationState as X
} from "./StreamArtistRecoveredIdentityHydrationState.sol";
import { StreamArtistPayloadStore as Payload } from "./StreamArtistPayloadStore.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";

/// @notice Fixed records phase of the original recovered Identity import.
/// @dev The fixed importer passes the complete canonical Bundle after SourceCodec validation.
/// Linked library calls retain the host's 17 declared roots and storage context.
library StreamArtistRecoveredIdentityImportRecords {
    function install(uint256[17] memory roots, bytes calldata canonical) public {
        IH.Bundle calldata b = Frame.bundle(canonical);
        _records(roots, b);
    }

    function _records(uint256[17] memory r, IH.Bundle calldata b) private {
        for (uint256 i; i < b.documents.length; ++i) {
            IH.DocumentRow memory row = b.documents[i];
            bytes memory old = X.identity(r).documents[row.documentHash];
            if (old.length != 0 && keccak256(old) != keccak256(row.document)) {
                revert IH.InvalidRecoveredIdentity(row.documentHash);
            }
            X.identity(r).documents[row.documentHash] = row.document;
            Payload.store(keccak256("ARTIST_IDENTITY_DOCUMENT"), row.document);
        }
        for (uint256 i; i < b.signatures.length; ++i) {
            IH.SignatureRow memory row = b.signatures[i];
            bytes memory old = X.identity(r).signatures[row.recordHash];
            if (old.length != 0 && keccak256(old) != keccak256(row.signature)) {
                revert IH.InvalidRecoveredIdentity(row.recordHash);
            }
            X.identity(r).signatures[row.recordHash] = row.signature;
            Payload.store(keccak256("ARTIST_SIGNATURE_BUNDLE"), row.signature);
        }
        for (uint256 i; i < b.revisions.length; ++i) {
            IH.RevisionRow memory row = b.revisions[i];
            IH.RevisionRow memory zero;
            bytes32 key = row.record.recordHash;
            _empty(
                abi.encode(
                    X.revisions(r).records[key],
                    X.revisions(r).associations[key],
                    X.rewinds(r).statuses[key],
                    X.rewinds(r).revisionRecordContinuations[key]
                ),
                abi.encode(zero.record, zero.association, zero.status, zero.rewindContinuation),
                key
            );
            X.revisions(r).records[key] = row.record;
            X.revisions(r).associations[key] = row.association;
            X.rewinds(r).statuses[key] = row.status;
            X.rewinds(r).revisionRecordContinuations[key] = row.rewindContinuation;
        }
        for (uint256 i; i < b.delegations.length; ++i) {
            IH.DelegationRow memory row = b.delegations[i];
            IH.DelegationRow memory zero;
            _empty(
                abi.encode(
                    X.delegations(r).records[row.recordHash], X.estate(r).grantEpoch[row.recordHash]
                ),
                abi.encode(zero.record, uint64(0)),
                row.recordHash
            );
            bytes32 lane = keccak256(abi.encode(b.artistId, row.record.grant.delegate));
            bytes32 old = X.delegations(r).current[lane];
            if (old != 0 && old != row.current) revert IH.InvalidRecoveredIdentity(lane);
            X.delegations(r).records[row.recordHash] = row.record;
            X.delegations(r).current[lane] = row.current;
            X.estate(r).grantEpoch[row.recordHash] = row.epoch;
        }
        for (uint256 i; i < b.designations.length; ++i) {
            IH.DesignationRow memory row = b.designations[i];
            IH.DesignationRow memory zero;
            bytes32 key = row.record.recordHash;
            _empty(
                abi.encode(X.succession(r).designations[key], X.rewinds(r).statuses[key]),
                abi.encode(zero.record, zero.status),
                key
            );
            X.succession(r).designations[key] = row.record;
            X.rewinds(r).statuses[key] = row.status;
        }
        for (uint256 i; i < b.directives.length; ++i) {
            IH.DirectiveRow memory row = b.directives[i];
            IH.DirectiveRow memory zero;
            bytes32 key = row.record.recordHash;
            _empty(
                abi.encode(X.succession(r).directives[key], X.rewinds(r).statuses[key]),
                abi.encode(zero.record, zero.status),
                key
            );
            if (X.succession(r).payloads[key].length != 0) revert IH.InvalidRecoveredIdentity(key);
            X.succession(r).directives[key] = row.record;
            X.succession(r).payloads[key] = row.payload;
            X.rewinds(r).statuses[key] = row.status;
            Payload.store(keccak256("ARTIST_DIRECTIVE_PAYLOAD"), row.payload);
        }
        for (uint256 i; i < b.sanctionGrants.length; ++i) {
            IH.GrantRow memory row = b.sanctionGrants[i];
            IH.GrantRow memory zero;
            bytes32 key = row.record.recordHash;
            _empty(
                abi.encode(X.sanctions(r).records[key], X.rewinds(r).statuses[key]),
                abi.encode(zero.record, zero.status),
                key
            );
            X.sanctions(r).records[key] = row.record;
            X.rewinds(r).statuses[key] = row.status;
        }
    }

    function _empty(bytes memory old, bytes memory zero, bytes32 key) private pure {
        if (keccak256(old) != keccak256(zero)) revert IH.InvalidRecoveredIdentity(key);
    }
}
