// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistOwner.sol";
import "./StreamArtistCollaboratorHashes.sol";

/// @notice Sole owner of collaborator identity proposals and acceptance-ratified account/identity joins.
/// @dev Full immutable binding terms live in Binding; acceptance records live in Acceptance.
contract StreamArtistCollaboratorLifecycle is StreamArtistOwner {
    mapping(bytes32 => C.IdentityProposalState) private _identityProposals;
    mapping(bytes32 => C.Join) private _joins;
    mapping(bytes32 => uint32) private _acceptedCounts;
    mapping(bytes32 => mapping(address => bool)) private _identityLinks;
    event CollaboratorIdentityProposed(
        uint16 schemaVersion,
        address indexed account,
        bytes32 identityRecordHash,
        string identityRecordURI,
        address proposer,
        bytes32 reasonHash,
        string reasonURI
    );
    constructor(
        address registry_,
        address coordinator_,
        address archive_,
        address core_,
        address manager_
    )
        StreamArtistOwner(
            registry_,
            coordinator_,
            archive_,
            keccak256("domain:collaborator_lifecycle"),
            core_,
            manager_
        )
    { }

    /// @notice Empty-profile bootstrap compatibility sentinel, not the live collection inventory.
    /// @dev Use the facade's generation-scoped collaboratorCount/collaboratorAt reads for actual rows.
    function collaboratorSetHash() external pure returns (bytes32) {
        return StreamArtistHashes.emptyCollaborators();
    }

    /// @notice Empty-profile bootstrap compatibility sentinel; actual rows are generation-scoped.
    function collaboratorCount() external pure returns (uint256) {
        return 0;
    }

    function identityProposal(address account, bytes32 identityRecordHash)
        external
        view
        returns (C.IdentityProposalState memory)
    {
        return _identityProposals[keccak256(abi.encode(account, identityRecordHash))];
    }

    function proposeIdentity(T.ActionContext calldata c, C.IdentityProposal calldata p)
        external
        returns (bytes32 hash)
    {
        _check(c, 5);
        if (
            p.account == address(0) || p.identityRecordHash == bytes32(0)
                || p.reasonHash == bytes32(0)
        ) {
            revert T.InvalidRecord();
        }
        if (bytes(p.identityRecordURI).length > 2048) {
            revert T.BoundExceeded(bytes(p.identityRecordURI).length, 2048);
        }
        if (bytes(p.reasonURI).length > 2048) {
            revert T.BoundExceeded(bytes(p.reasonURI).length, 2048);
        }
        bytes32 scope = keccak256(abi.encode(p.account, p.identityRecordHash));
        hash = StreamArtistCollaboratorHashes.proposalHash(_environment(), p, c.actor);
        bytes32 replay = _consume(
            keccak256("collaborator_lifecycle.replay.collaborator_proposal_key"), scope, hash
        );
        _identityProposals[scope] = C.IdentityProposalState(p, c.actor, hash, bytes32(0));
        _commit(
            c,
            keccak256(abi.encode(p)),
            keccak256(abi.encode(scope, _identityProposals[scope])),
            keccak256(abi.encode(replay, hash)),
            bytes32(0)
        );
        emit CollaboratorIdentityProposed(
            1,
            p.account,
            p.identityRecordHash,
            p.identityRecordURI,
            c.actor,
            p.reasonHash,
            p.reasonURI
        );
    }

    function completeIdentity(
        T.ActionContext calldata c,
        address account,
        bytes32 identityRecordHash,
        bytes32 artistId
    ) external {
        _check(c, 6);
        bytes32 scope = keccak256(abi.encode(account, identityRecordHash));
        C.IdentityProposalState storage item = _identityProposals[scope];
        if (
            item.proposalHash == bytes32(0) || item.acceptedArtistId != bytes32(0)
                || artistId == bytes32(0)
        ) revert T.InvalidRecord();
        item.acceptedArtistId = artistId;
        _commit(
            c,
            keccak256(abi.encode(account, identityRecordHash, artistId)),
            keccak256(abi.encode(scope, item)),
            bytes32(0),
            bytes32(0)
        );
    }

    function recordRowAcceptance(
        T.ActionContext calldata c,
        C.BindingAcceptance calldata p,
        bytes32 artistId,
        bytes32 record
    ) external returns (uint32 count) {
        _check(c, 7);
        bytes32 key =
            StreamArtistCollaboratorHashes.rowKey(p.bindingHash, p.account, p.role, p.shareLabelId);
        if (
            p.bindingHash == bytes32(0) || artistId == bytes32(0) || record == bytes32(0)
                || _joins[key].artistId != bytes32(0)
        ) revert T.InvalidRecord();
        count = _acceptedCounts[p.bindingHash] + 1;
        if (count > 32) revert T.BoundExceeded(count, 32);
        _joins[key] = C.Join(artistId, record);
        _acceptedCounts[p.bindingHash] = count;
        _identityLinks[artistId][p.account] = true;
        _commit(
            c,
            keccak256(abi.encode(p, artistId, record)),
            keccak256(abi.encode(key, _joins[key], count, artistId, p.account, true)),
            bytes32(0),
            bytes32(0)
        );
    }

    function acceptedRow(bytes32 bindingHash, address account, bytes32 role, bytes32 shareLabelId)
        external
        view
        returns (C.Join memory)
    {
        return
            _joins[StreamArtistCollaboratorHashes.rowKey(bindingHash, account, role, shareLabelId)];
    }

    function acceptedCount(bytes32 bindingHash) external view returns (uint32) {
        return _acceptedCounts[bindingHash];
    }

    function identityLinked(bytes32 artistId, address account) external view returns (bool) {
        return _identityLinks[artistId][account];
    }
}
