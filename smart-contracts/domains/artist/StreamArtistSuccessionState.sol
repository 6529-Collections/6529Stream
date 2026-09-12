// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistIdentityState.sol";
import "./StreamArtistRotationState.sol";
import "./StreamArtistSuccessionHashes.sol";

/// @notice Identity-owned succession records; linked code owns no independent authority.
library StreamArtistSuccessionState {
    struct State {
        mapping(bytes32 => Succ.DesignationRecord) designations;
        mapping(bytes32 => Succ.DirectiveRecord) directives;
        mapping(bytes32 => bytes) payloads;
        mapping(bytes32 => bytes32) stableDesignation;
        mapping(bytes32 => bytes32) candidateDesignation;
        mapping(bytes32 => bytes32) stableDirective;
        mapping(bytes32 => bytes32) candidateDirective;
    }
    event ArtistSuccessorDesignated(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed successor,
        uint8 successorKind,
        uint32 grantedCapabilities,
        bytes32 conditionsHash,
        bytes32 directiveHash,
        uint256 nonce,
        uint64 signedAt,
        bytes32 designationRecordHash
    );
    event ArtistEstateDirectiveRecorded(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        uint32 grantedCapabilities,
        uint32 forbiddenCapabilities,
        bytes32 directivePayloadHash,
        uint256 nonce,
        uint64 signedAt,
        bytes32 directiveRecordHash
    );

    function operativeDesignation(
        State storage s,
        StreamArtistRotationState.State storage rotations,
        bytes32 artistId
    ) public view returns (bytes32) {
        bytes32 base = s.stableDesignation[artistId];
        bytes32 candidate = s.candidateDesignation[artistId];
        if (
            candidate != bytes32(0)
                && StreamArtistRotationState.eligible(
                    rotations, artistId, s.designations[candidate].provisional
                )
                && (base == bytes32(0)
                    || s.designations[candidate].nonce > s.designations[base].nonce)
        ) {
            return candidate;
        }
        return base;
    }

    function operativeDirective(
        State storage s,
        StreamArtistRotationState.State storage rotations,
        bytes32 artistId
    ) public view returns (bytes32) {
        bytes32 base = s.stableDirective[artistId];
        bytes32 candidate = s.candidateDirective[artistId];
        if (
            candidate != bytes32(0)
                && StreamArtistRotationState.eligible(
                    rotations, artistId, s.directives[candidate].provisional
                )
                && (base == bytes32(0) || s.directives[candidate].nonce > s.directives[base].nonce)
        ) {
            return candidate;
        }
        return base;
    }

    function successor(
        State storage s,
        StreamArtistRotationState.State storage rotations,
        bytes32 artistId
    ) public view returns (address account, bytes32 record) {
        record = operativeDesignation(s, rotations, artistId);
        account = s.designations[record].terms.successor;
    }

    function requireAllowed(
        State storage s,
        StreamArtistRotationState.State storage rotations,
        bytes32 artistId,
        uint32 capabilities
    ) public view {
        bytes32 record = operativeDirective(s, rotations, artistId);
        if (s.directives[record].terms.forbiddenCapabilities & capabilities != 0) {
            revert Succ.ForbiddenCapability(artistId, capabilities, record);
        }
    }

    function designate(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        Succ.Designation memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        bool ownKey = p.successor.code.length == 0
            || StreamArtistSuccessionHashes.isDesignatedAccount(p.successor);
        if (
            p.successor == address(0) || (p.successorKind != 1 && p.successorKind != 2)
                || (p.successorKind == 1) != ownKey || p.grantedCapabilities & ~uint32(4095) != 0
        ) {
            revert Succ.InvalidSuccessor();
        }
        if (
            p.directiveHash != bytes32(0)
                && (s.directives[p.directiveHash].recordHash == bytes32(0)
                    || s.directives[p.directiveHash].terms.artistId != p.artistId)
        ) revert Succ.InvalidDirective();
        _time(a, proof);
        bytes32 record = StreamArtistSuccessionHashes.designationRecord(o.environment, p, a);
        if (s.designations[record].recordHash != bytes32(0)) revert T.InvalidRecord();
        m = StreamArtistIdentityState.authorize(
            identity,
            replay,
            o,
            c,
            p.artistId,
            a,
            proof,
            StreamArtistSuccessionHashes.designationDigest(o.environment, p, a),
            record,
            identity.identities[p.artistId].authorityAddress
        );
        bytes32 base = operativeDesignation(s, rotations, p.artistId);
        R.ProvisionalAssociation memory association_ =
            StreamArtistRotationState.association(rotations, p.artistId);
        Succ.DesignationRecord memory item =
            Succ.DesignationRecord(record, p, proof.signer, 1, a.nonce, a.time, association_);
        s.designations[record] = item;
        if (association_.transitionRecordHash == bytes32(0)) {
            s.stableDesignation[p.artistId] =
                base == bytes32(0) || a.nonce > s.designations[base].nonce ? record : base;
            delete s.candidateDesignation[p.artistId];
        } else {
            s.stableDesignation[p.artistId] = base;
            bytes32 candidate = s.candidateDesignation[p.artistId];
            if (
                candidate == bytes32(0)
                    || s.designations[candidate].provisional.transitionRecordHash
                        != association_.transitionRecordHash
                    || a.nonce > s.designations[candidate].nonce
            ) s.candidateDesignation[p.artistId] = record;
        }
        bytes32 key =
            _consume(replay, o, keccak256("identity_authority.replay.succession_chain"), record);
        m.record = record;
        m.action = keccak256(abi.encode(p, a, proof));
        m.state = keccak256(
            abi.encode(
                m.state,
                base,
                item,
                s.stableDesignation[p.artistId],
                s.candidateDesignation[p.artistId]
            )
        );
        m.replay = keccak256(abi.encode(m.replay, key, record));
        emit ArtistSuccessorDesignated(
            1,
            p.artistId,
            p.successor,
            p.successorKind,
            p.grantedCapabilities,
            p.conditionsHash,
            p.directiveHash,
            a.nonce,
            a.time,
            record
        );
    }

    function directive(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        Succ.Directive memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof,
        Succ.PublicDocument memory document
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        _time(a, proof);
        bytes memory payload = StreamArtistSuccessionHashes.publicPayload(
            p.grantedCapabilities, p.forbiddenCapabilities, document
        );
        if (payload.length > 8192) revert T.BoundExceeded(payload.length, 8192);
        if (keccak256(payload) != p.directivePayloadHash) revert Succ.InvalidDirective();
        bytes32 record = StreamArtistSuccessionHashes.directiveRecord(o.environment, p, a);
        if (s.directives[record].recordHash != bytes32(0)) revert T.InvalidRecord();
        m = StreamArtistIdentityState.authorize(
            identity,
            replay,
            o,
            c,
            p.artistId,
            a,
            proof,
            StreamArtistSuccessionHashes.directiveDigest(o.environment, p, a),
            record,
            identity.identities[p.artistId].authorityAddress
        );
        bytes32 base = operativeDirective(s, rotations, p.artistId);
        R.ProvisionalAssociation memory association_ =
            StreamArtistRotationState.association(rotations, p.artistId);
        Succ.DirectiveRecord memory item =
            Succ.DirectiveRecord(record, p, proof.signer, 1, a.nonce, a.time, association_);
        s.directives[record] = item;
        s.payloads[record] = payload;
        if (association_.transitionRecordHash == bytes32(0)) {
            s.stableDirective[p.artistId] =
                base == bytes32(0) || a.nonce > s.directives[base].nonce ? record : base;
            delete s.candidateDirective[p.artistId];
        } else {
            s.stableDirective[p.artistId] = base;
            bytes32 candidate = s.candidateDirective[p.artistId];
            if (
                candidate == bytes32(0)
                    || s.directives[candidate].provisional.transitionRecordHash
                        != association_.transitionRecordHash
                    || a.nonce > s.directives[candidate].nonce
            ) s.candidateDirective[p.artistId] = record;
        }
        bytes32 key =
            _consume(replay, o, keccak256("identity_authority.replay.directive_chain"), record);
        m.record = record;
        m.action = keccak256(abi.encode(p, a, proof, document));
        m.state = keccak256(
            abi.encode(
                m.state,
                base,
                item,
                s.stableDirective[p.artistId],
                s.candidateDirective[p.artistId],
                keccak256(payload)
            )
        );
        m.replay = keccak256(abi.encode(m.replay, key, record));
        emit ArtistEstateDirectiveRecorded(
            1,
            p.artistId,
            p.grantedCapabilities,
            p.forbiddenCapabilities,
            p.directivePayloadHash,
            a.nonce,
            a.time,
            record
        );
    }

    function _time(T.Authorization memory a, T.SignerApproval memory proof) private view {
        if (a.time == 0 || a.time > block.timestamp || (proof.direct && a.time != block.timestamp)) revert T.InvalidTimestamp(a.time);
    }

    function _consume(
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes32 surface,
        bytes32 record
    ) private returns (bytes32 key) {
        key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                o.environment.chainId,
                o.environment.registry,
                o.coordinator,
                o.archive,
                address(this),
                o.domain,
                surface,
                keccak256(abi.encode(record))
            )
        );
        if (replay[key].status != 0) revert T.Replay(key);
        replay[key] = T.ReplayCell(record, o.revision + 1, 1, 2);
    }
}
