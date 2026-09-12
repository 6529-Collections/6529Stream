// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistCurrentAuthorityFacts.sol";
import "./StreamArtistRecoveryHashes.sol";
import "../../interfaces/stream/artist/IStreamArtistRecoveryApprovalOwner.sol";
import "../../interfaces/stream/finality/IStreamArtistRecoveryIntent.sol";

/// @notice Immutable recovery approvals in the Consent owner's storage and event context.
/// @dev Authority, original-finality and actual intent observations are authenticated by ingress;
///      this callback independently joins them to the permanent record and its one-use replay key.
library StreamArtistRecoveryApprovalState {
    struct OwnerContext {
        StreamArtistHashes.Environment environment;
        address coordinator;
        address archive;
        bytes32 domain;
        uint64 revision;
        uint64 observedAt;
    }

    struct Mutation {
        bytes32 record;
        bytes32 action;
        bytes32 state;
        bytes32 replay;
    }

    struct State {
        mapping(bytes32 => Recovery.ApprovalRecord) records;
        mapping(bytes32 => Approval.Admission) admissions;
        mapping(bytes32 => bytes32) associationRecords;
    }

    struct Input {
        T.Binding binding_;
        Recovery.ApprovalRecord record;
        R.AuthorityFact authority;
        Approval.Admission admission;
    }

    event ArtistRecoveryApprovalRecorded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed recoveryManifestHash,
        address indexed signer,
        bytes32 finalityRecordHash,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 approvalRecordHash
    );

    function recordEncoded(
        State storage state,
        mapping(bytes32 => T.ReplayCell) storage replay,
        OwnerContext memory o,
        bytes calldata callData
    ) public returns (Mutation memory) {
        if (bytes4(callData) != IStreamArtistRecoveryApprovalOwner.recordRecoveryApproval.selector)
        {
            revert Recovery.InvalidRecoveryApproval();
        }
        (
            ,
            T.Binding memory b,
            Recovery.ApprovalRecord memory r,
            R.AuthorityFact memory authority,
            Approval.Admission memory admission
        ) = abi.decode(
            callData[4:],
            (
                T.ActionContext,
                T.Binding,
                Recovery.ApprovalRecord,
                R.AuthorityFact,
                Approval.Admission
            )
        );
        return record(state, replay, o, Input(b, r, authority, admission));
    }

    function record(
        State storage state,
        mapping(bytes32 => T.ReplayCell) storage replay,
        OwnerContext memory o,
        Input memory x
    ) public returns (Mutation memory m) {
        Recovery.ApprovalRecord memory r = x.record;
        StreamArtistCurrentAuthorityFacts.requireAccepted(x.binding_, r.signer, x.authority, false);
        if (
            r.artistId != x.binding_.artistId || r.authorityClass != x.authority.authorityClass
                || r.bindingGeneration != x.binding_.generation || r.bindingGeneration == 0
                || r.bindingHash != x.binding_.bindingHash || r.bindingHash == 0
                || r.signedAt != o.observedAt || r.deadline < o.observedAt
                || r.terms.finalityRegistry == address(0) || r.terms.collectionId == 0
                || r.terms.finalityRecordHash == 0 || r.terms.recoveryManifestHash == 0
                || r.recordHash == 0
                || r.recordHash != StreamArtistRecoveryHashes.approvalRecord(o.environment, r)
                || r.digest
                    != StreamArtistRecoveryHashes.approvalDigest(
                        o.environment, r.terms, r.nonce, r.deadline
                    )
        ) revert Recovery.InvalidRecoveryApproval();
        _admission(r.terms.collectionId, x.admission);
        bytes32 scope = associationKey(r.artistId, r.bindingGeneration, r.bindingHash, r.terms);
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                o.environment.chainId,
                o.environment.registry,
                o.coordinator,
                o.archive,
                address(this),
                o.domain,
                keccak256("consent_finality.replay.recovery_approval_key"),
                scope
            )
        );
        if (replay[key].status != 0) revert T.Replay(key);
        if (state.records[r.recordHash].recordHash != 0 || state.associationRecords[scope] != 0) {
            revert Recovery.InvalidRecoveryApproval();
        }
        replay[key] = T.ReplayCell(r.recordHash, o.revision + 1, 1, 2);
        state.records[r.recordHash] = r;
        state.admissions[r.recordHash] = x.admission;
        state.associationRecords[scope] = r.recordHash;
        m.record = r.recordHash;
        m.action = keccak256(abi.encode(x.binding_, r, x.authority, x.admission));
        m.state = keccak256(abi.encode(scope, r, x.admission));
        m.replay = keccak256(abi.encode(key, r.recordHash));
        _emit(r);
    }

    /// @notice New explicit ADR0039 replay scope; permanent approval preimages are unchanged.
    function associationKey(
        bytes32 artistId,
        uint64 generation,
        bytes32 bindingHash,
        Recovery.ApprovalTerms memory p
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_APPROVAL_KEY_V1"),
                artistId,
                generation,
                bindingHash,
                p
            )
        );
    }

    function recordEncodedRead(State storage state, bytes32 hash)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(state.records[hash], state.admissions[hash]);
    }

    function _admission(uint256 collectionId, Approval.Admission memory a) private pure {
        StreamFinalityScope memory s = a.scope;
        if (
            s.collectionId != collectionId
                || (s.scopeType == StreamFinalityScopeType.COLLECTION
                    && (s.tokenId != 0 || s.scopeId != 0))
                || (s.scopeType == StreamFinalityScopeType.TOKEN
                    && (s.tokenId == 0 || s.scopeId != 0))
                || (uint8(s.scopeType) > 1 && (s.tokenId != 0 || s.scopeId == 0))
                || a.recoveryRegistry == address(0) || a.recoveryRegistryCodeHash == 0
                || a.originalFinalityCodeHash == 0 || a.intent.scopeHash == 0
                || a.intent.oldValueHash == 0 || a.intent.newValueHash == 0
                || a.intent.requestHash == 0
        ) revert Recovery.InvalidRecoveryApproval();
    }

    function _emit(Recovery.ApprovalRecord memory r) private {
        emit ArtistRecoveryApprovalRecorded(
            1,
            r.terms.collectionId,
            r.terms.recoveryManifestHash,
            r.signer,
            r.terms.finalityRecordHash,
            r.authorityClass,
            r.nonce,
            r.signedAt,
            r.recordHash
        );
    }
}
