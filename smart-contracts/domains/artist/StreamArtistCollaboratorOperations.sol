// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/artist/IStreamArtistCurrentCollaboratorOwner.sol";
import "./StreamArtistAuthorityPolicy.sol";
import "./StreamArtistBindingOperations.sol";
import "./StreamArtistCollaboratorHashes.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorRecordsOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorBindingOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorIdentityOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorAcceptanceOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorAttributionOwner.sol";
import "../../interfaces/stream/governance/IStreamRoleRegistry.sol";

/// @notice Typed collaborator recipes behind the Coordinator's fixed ingress authentication and lock.
library StreamArtistCollaboratorOperations {
    function proposeIdentity(
        D.CoordinatorContext memory x,
        address actor,
        C.IdentityProposal memory p
    ) public returns (bytes32 proposalHash) {
        bytes32 role = keccak256("ROLE_ARTIST_REGISTRY_ADMIN");
        if (!IStreamRoleRegistry(x.suite.roleRegistry).hasRole(role, actor)) {
            revert T.Unauthorized(actor);
        }
        (bytes32 roleHash, uint64 revision) =
            IStreamRoleRegistry(x.suite.roleRegistry).roleMutationState(role);
        T.Snapshot[7] memory before_ = _snapshots(x, 5);
        if (IStreamArtistIdentityOwner(x.suite.owners[2]).activeIdentity(p.account) != bytes32(0)) {
            revert T.AddressAlreadyRegistered(p.account);
        }
        proposalHash = IStreamArtistCollaboratorRecordsOwner(x.suite.owners[1])
            .proposeIdentity(T.ActionContext(5, actor, before_[1]), p);
        _archive(x, 5, actor, proposalHash, before_, abi.encode(p, roleHash, revision));
    }

    function acceptIdentity(
        D.CoordinatorContext memory x,
        address actor,
        address account,
        bytes32 documentHash,
        T.Authorization memory a,
        bytes memory document,
        string memory displayName
    ) public returns (bytes32 artistId) {
        T.Snapshot[7] memory before_ = _snapshots(x, 6);
        C.IdentityProposalState memory proposal = IStreamArtistCollaboratorRecordsOwner(
                x.suite.owners[1]
            ).identityProposal(account, documentHash);
        if (
            proposal.proposalHash == bytes32(0) || proposal.acceptedArtistId != bytes32(0)
                || proposal.proposal.account != account
                || proposal.proposal.identityRecordHash != documentHash
        ) revert T.InvalidRecord();
        IStreamArtistIdentityOwner identity = IStreamArtistIdentityOwner(x.suite.owners[2]);
        if (identity.activeIdentity(account) != bytes32(0)) {
            revert T.AddressAlreadyRegistered(account);
        }
        uint256 allocationNonce = identity.nextRegistrationNonce();
        T.SignerApproval memory proof = _verify(
            x,
            actor,
            account,
            StreamArtistCollaboratorHashes.identityDigest(
                _environment(x), account, documentHash, a
            ),
            a.signature
        );
        artistId = IStreamArtistCollaboratorIdentityOwner(x.suite.owners[2])
            .registerCollaboratorIdentity(
                T.ActionContext(6, actor, before_[2]),
                proposal.proposal,
                a,
                proof,
                document,
                displayName
            );
        if (
            artistId
                != StreamArtistHashes.identity(
                    _environment(x), account, documentHash, allocationNonce
                )
        ) revert T.InvalidRecord();
        IStreamArtistCollaboratorRecordsOwner(x.suite.owners[1])
            .completeIdentity(
                T.ActionContext(6, actor, before_[1]), account, documentHash, artistId
            );
        _archive(
            x,
            6,
            actor,
            artistId,
            before_,
            abi.encode(proposal, a, proof, document, displayName, allocationNonce)
        );
    }

    function acceptRow(
        D.CoordinatorContext memory x,
        address actor,
        C.BindingAcceptance memory p,
        T.Authorization memory a
    ) public returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(x, 7);
        T.Binding memory b = IStreamArtistBindingOwner(x.suite.owners[0]).binding(p.collectionId);
        (uint8 state, uint64 generation) =
            IStreamArtistAttributionOwner(x.suite.owners[4]).attributionState(p.collectionId);
        if (
            b.accepted || state != 1 || generation != b.generation || p.generation != b.generation
                || p.bindingHash != b.bindingHash || b.bindingHash == bytes32(0)
                || !IStreamCoreCollectionView(x.suite.core).collectionExists(p.collectionId)
        ) revert T.InvalidAttribution(p.collectionId);
        IStreamArtistCollaboratorBindingOwner bindingOwner =
            IStreamArtistCollaboratorBindingOwner(x.suite.owners[0]);
        C.BindingTerms memory terms = bindingOwner.bindingTerms(p.collectionId, p.generation);
        bool found;
        for (uint256 i; i < terms.count; ++i) {
            T.CollaboratorRecord memory row =
                bindingOwner.collaboratorTerm(p.collectionId, p.generation, i);
            if (
                row.account == p.account && row.role == p.role && row.shareLabelId == p.shareLabelId
            ) {
                found = true;
                break;
            }
        }
        if (!found) revert T.InvalidRecord();
        IStreamArtistCollaboratorRecordsOwner collaborators =
            IStreamArtistCollaboratorRecordsOwner(x.suite.owners[1]);
        if (
            collaborators.acceptedRow(p.bindingHash, p.account, p.role, p.shareLabelId).artistId
                != bytes32(0)
        ) revert T.InvalidRecord();
        uint32 priorCount = collaborators.acceptedCount(p.bindingHash);
        bytes32 primaryRecord =
            IStreamArtistAcceptanceOwner(x.suite.owners[3]).acceptanceRecord(p.bindingHash);
        IStreamArtistIdentityOwner identity = IStreamArtistIdentityOwner(x.suite.owners[2]);
        bytes32 artistId = identity.activeIdentity(p.account);
        (address signer, uint8 auth, uint8 status,) = identity.authorityState(artistId);
        if (
            artistId == bytes32(0) || signer != p.account
                || !StreamArtistAuthorityPolicy.ordinary(auth, status, false)
        ) {
            revert T.InvalidIdentity(artistId);
        }
        T.SignerApproval memory proof = _verify(
            x,
            actor,
            p.account,
            StreamArtistCollaboratorHashes.acceptanceDigest(_environment(x), p, a),
            a.signature
        );
        record = IStreamArtistCollaboratorIdentityOwner(x.suite.owners[2])
            .consumeCollaboratorAcceptance(
                T.ActionContext(7, actor, before_[2]), p, artistId, a, proof
            );
        bytes32 actual = IStreamArtistCurrentCollaboratorAcceptanceOwner(x.suite.owners[3])
            .recordCollaboratorAcceptanceWithAuthority(
                T.ActionContext(7, actor, before_[3]),
                p,
                artistId,
                a.nonce,
                R.AuthorityFact(artistId, signer, auth, status)
            );
        if (record != actual) revert T.InvalidRecord();
        uint32 count = collaborators.recordRowAcceptance(
            T.ActionContext(7, actor, before_[1]), p, artistId, record
        );
        if (count != priorCount + 1 || count > terms.count) revert T.InvalidRecord();
        bool complete = count == terms.count && primaryRecord != bytes32(0);
        if (complete) {
            bindingOwner.completeCollaboratorBinding(
                T.ActionContext(7, actor, before_[0]), p.collectionId, p.bindingHash, record
            );
            IStreamArtistCurrentCollaboratorAttributionOwner(x.suite.owners[4])
                .completeCollaboratorBindingWithAuthority(
                    T.ActionContext(7, actor, before_[4]),
                    p.collectionId,
                    b,
                    record,
                    p.account,
                    R.AuthorityFact(artistId, signer, auth, status)
                );
        }
        _archive(
            x,
            7,
            actor,
            record,
            before_,
            abi.encode(b, p, artistId, a, proof, terms, priorCount, count, primaryRecord, complete)
        );
    }

    function _verify(
        D.CoordinatorContext memory x,
        address actor,
        address signer,
        bytes32 digest,
        bytes memory signature
    ) private view returns (T.SignerApproval memory) {
        if (actor == address(0) || signer == address(0)) {
            revert T.InvalidSignature();
        }
        bool direct = actor == signer && signature.length == 0;
        if (!direct) {
            (uint256 cap,, uint8 failure, uint64 revision) = IStreamGasParameterHost(
                    x.suite.registry
                ).gasParameterInfo(keccak256("6529STREAM_GGP_ARTIST_ERC1271_VERIFY_GAS"));
            if (
                revision == 0 || failure != 2
                    || !StreamArtistRegistryValidatorBase(x.suite.validator)
                        .validateSignerProof(signer, digest, signature, cap)
            ) revert T.InvalidSignature();
        }
        return T.SignerApproval(signer, digest, direct);
    }

    function _environment(D.CoordinatorContext memory x)
        private
        view
        returns (StreamArtistHashes.Environment memory)
    {
        return StreamArtistHashes.Environment(
            block.chainid, x.suite.registry, x.suite.core, x.suite.mintManager
        );
    }

    function _snapshots(D.CoordinatorContext memory x, uint16 op)
        private
        view
        returns (T.Snapshot[7] memory result)
    {
        uint256 mask = op == 7 ? 0x1f : 0x06;
        for (uint256 i; i < 7; ++i) {
            if ((mask & (1 << i)) != 0) {
                result[i] = IStreamArtistOwner(x.suite.owners[i]).ownerStateSnapshotV2();
            }
        }
    }

    function _archive(
        D.CoordinatorContext memory x,
        uint16 op,
        address actor,
        bytes32 reference_,
        T.Snapshot[7] memory before_,
        bytes memory payload
    ) private {
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                x.suite.registry,
                address(this),
                op,
                actor,
                reference_
            )
        );
        bytes memory evidence = abi.encode(
            uint16(1),
            x.configurationHash,
            op,
            actor,
            reference_,
            before_,
            _snapshots(x, op),
            payload
        );
        (bytes32 hash,, bool appended) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(id, 1, evidence);
        if (!appended || hash != keccak256(evidence)) revert T.InvalidRecord();
    }
}
