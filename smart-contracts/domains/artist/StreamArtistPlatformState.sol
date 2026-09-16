// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/artist/IStreamArtistPlatformWorks.sol";

/// @notice Attribution-owned append-only declaration and adjudication history. No peer-owner calls.
library StreamArtistPlatformState {
    struct Store {
        mapping(uint256 => PW.State) collections;
        mapping(bytes32 => PW.Claim) claims;
        mapping(bytes32 => PW.Contest) contests;
        mapping(bytes32 => bool) claimSubjects;
        mapping(bytes32 => bool) actions;
    }
    event PlatformWorksDeclared(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 declarationHash,
        bytes32 statementHash,
        address actor,
        uint64 declaredAt
    );
    event PlatformWorksClaimFiled(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        address indexed claimant,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        string reasonURI,
        uint64 filedAt,
        bytes32 claimRecordHash
    );
    event PlatformWorksContestChanged(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint8 indexed contestState,
        bytes32 claimRecordHash,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        bytes32 governanceActionId
    );
    event PlatformWorksCorrectionApproved(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed claimRecordHash,
        bytes32 sustainedContestRecordHash,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        uint64 approvedAt,
        bytes32 correctionRecordHash,
        bytes32 governanceActionId
    );

    function declare(
        Store storage s,
        address registry,
        address core,
        address actor,
        uint256 id,
        bytes32 statement
    ) public returns (bytes32 hash) {
        PW.State storage p = s.collections[id];
        if (id == 0 || statement == 0 || p.declaration.recordHash != 0) revert PW.InvalidPlatformWorks(id);
        uint64 now_ = _time();
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_PLATFORM_WORKS_DECLARATION_V1"),
                block.chainid,
                registry,
                core,
                id,
                statement,
                now_
            )
        );
        p.declaration = PW.Declaration(hash, statement, actor, now_);
        emit PlatformWorksDeclared(1, id, hash, statement, actor, now_);
    }

    function claim(
        Store storage s,
        address registry,
        address core,
        address actor,
        uint256 id,
        bytes32 evidence,
        bytes32 reason,
        string memory uri,
        address author
    ) public returns (bytes32 hash) {
        PW.State storage p = s.collections[id];
        bytes32 key = keccak256(abi.encode(id, actor, evidence, reason));
        if (
            p.declaration.recordHash == 0 || evidence == 0 || reason == 0
                || bytes(uri).length > 4096 || s.claimSubjects[key]
        ) revert PW.InvalidPlatformWorks(id);
        uint64 now_ = _time();
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_PLATFORM_WORKS_CLAIM_RECORD_V1"),
                block.chainid,
                registry,
                core,
                id,
                actor,
                evidence,
                reason,
                now_
            )
        );
        s.claimSubjects[key] = true;
        s.claims[hash] = PW.Claim(id, actor, author, evidence, reason, now_, hash);
        ++p.claimCount;
        p.latestClaim = hash;
        emit PlatformWorksClaimFiled(1, id, actor, evidence, reason, uri, now_, hash);
    }

    function contest(
        Store storage s,
        uint256 id,
        uint8 state,
        bytes32 claim_,
        bytes32 evidence,
        bytes32 reason,
        bytes32 actionId,
        address author
    ) public returns (bytes32 hash) {
        PW.State storage p = s.collections[id];
        PW.Claim storage c = s.claims[claim_];
        if (
            p.declaration.recordHash == 0 || c.collectionId != id || c.recordHash == 0
                || evidence == 0 || reason == 0 || actionId == 0
                || s.actions[keccak256(abi.encode(id, actionId))]
                || (state == 1
                        ? (p.contestState != 0 && p.contestState != 2)
                        : ((state != 2 && state != 3)
                            || p.contestState != 1
                            || p.contestClaim != claim_))
        ) revert PW.InvalidPlatformWorks(id);
        PW.Contest memory r =
            PW.Contest(
            id, author, state, claim_, evidence, reason, actionId, p.contestRecord, _time(), 0
        );
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_PLATFORM_WORKS_CONTEST_TRANSITION_V1"),
                block.chainid,
                address(this),
                r
            )
        );
        r.recordHash = hash;
        s.contests[hash] = r;
        s.actions[keccak256(abi.encode(id, actionId))] = true;
        p.contestState = state;
        p.contestClaim = claim_;
        p.contestRecord = hash;
        emit PlatformWorksContestChanged(1, id, state, claim_, evidence, reason, actionId);
    }

    function correct(
        Store storage s,
        address registry,
        address core,
        uint256 id,
        bytes32 claim_,
        bytes32 evidence,
        bytes32 reason,
        bytes32 actionId
    ) public returns (bytes32 hash) {
        PW.State storage p = s.collections[id];
        if (
            p.contestState != 3 || p.contestClaim != claim_ || p.correction.recordHash != 0
                || s.contests[p.contestRecord].adjudicatedArtist == address(0) || evidence == 0
                || reason == 0 || actionId == 0 || s.actions[keccak256(abi.encode(id, actionId))]
        ) revert PW.InvalidPlatformWorks(id);
        uint64 now_ = _time();
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_PLATFORM_WORKS_CORRECTION_RECORD_V1"),
                block.chainid,
                registry,
                core,
                id,
                p.contestRecord,
                claim_,
                evidence,
                reason,
                actionId,
                now_
            )
        );
        p.correction = PW.Correction(
            id,
            s.contests[p.contestRecord].adjudicatedArtist,
            claim_,
            p.contestRecord,
            evidence,
            reason,
            actionId,
            now_,
            0,
            false,
            hash
        );
        s.actions[keccak256(abi.encode(id, actionId))] = true;
        emit PlatformWorksCorrectionApproved(
            1, id, claim_, p.contestRecord, evidence, reason, now_, hash, actionId
        );
    }

    function consumeBinding(Store storage s, uint256 id, T.Binding memory b) public {
        PW.State storage p = s.collections[id];
        if (p.declaration.recordHash == 0) return;
        if (
            p.contestState != 3 || p.correction.recordHash == 0
                || p.correction.correctiveGeneration != 0
                || b.artistAddress != p.correction.proposedArtist || b.generation == 0
                || b.consentMode != 1
        ) revert PW.InvalidPlatformWorks(id);
        p.correction.correctiveGeneration = b.generation;
    }

    function acceptBinding(Store storage s, uint256 id, uint64 generation) public {
        PW.State storage p = s.collections[id];
        if (p.declaration.recordHash == 0) return;
        if (p.correction.correctiveGeneration != generation || p.correction.accepted) {
            revert PW.InvalidPlatformWorks(id);
        }
        p.correction.accepted = true;
    }

    function _time() private view returns (uint64) {
        if (block.timestamp > type(uint64).max) revert T.InvalidRecord();
        return uint64(block.timestamp);
    }
}
