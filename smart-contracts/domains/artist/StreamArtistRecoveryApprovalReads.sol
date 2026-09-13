// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistRecoveryOriginalReads.sol";
import "./StreamArtistRecoveryAdmission.sol";
import "./StreamArtistRecoveryApprovalState.sol";
import "./StreamArtistRecoveryApprovalScopes.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorBindingOwner.sol";

/// @notice Fresh approval admission and historical verification have distinct authority predicates.
library StreamArtistRecoveryApprovalReads {
    error RecoveryApprovalAssociationUnsupported();

    struct Prepared {
        T.Binding binding_;
        R.AuthorityFact authority;
        Approval.Admission admission;
        bytes32 originalObservationHash;
    }

    function prepare(
        T.SuiteConfiguration memory suite,
        StreamArtistRecoveryOriginalReads.Pins memory pins,
        Approval.Request memory request
    ) public view returns (Prepared memory p) {
        if (request.terms.finalityRegistry != pins.finalityRegistry) revert Recovery.InvalidRecoveryApproval();
        StreamArtistRecoveryOriginalReads.Observation memory original =
            StreamArtistRecoveryOriginalReads.observe(suite, pins, request.terms.finalityRecordHash);
        if (request.terms.collectionId != original.scope.collectionId) {
            revert Recovery.InvalidRecoveryApproval();
        }
        StreamArtistRecoveryApprovalScopes.requireFresh(
            suite.core, original.scope, request.scope, pins.readGas
        );
        p.binding_ =
            StreamArtistRecoveryAdmission.binding(suite, request.terms.collectionId, pins.readGas);
        if (
            p.binding_.artistId != original.sanction.artistId
                || p.binding_.generation != original.sanction.bindingGeneration
                || p.binding_.bindingHash != original.sanction.bindingHash
        ) revert RecoveryApprovalAssociationUnsupported();
        C.BindingTerms memory terms = IStreamArtistCollaboratorBindingOwner(suite.owners[0])
            .bindingTerms(request.terms.collectionId, p.binding_.generation);
        if (
            terms.count != 0
                || terms.capabilityPolicySetHash != StreamArtistHashes.emptyCapabilities()
        ) revert T.UnsupportedProfile();
        p.authority =
            StreamArtistCurrentAuthorityFacts.read(suite.owners[2], p.binding_.artistId, false);
        StreamArtistCurrentAuthorityFacts.requireAccepted(
            p.binding_, p.authority.authorityAddress, p.authority, false
        );
        p.admission = Approval.Admission(
            request.scope,
            request.recoveryRegistry,
            request.recoveryRegistry.codehash,
            pins.finalityCodeHash,
            StreamArtistRecoveryAdmission.approvalIntent(
                suite, pins.finalityRegistry, request, pins.readGas
            )
        );
        p.originalObservationHash = keccak256(abi.encode(original));
    }

    /// @notice Verifies saved consent under the original executed association, not current readiness.
    /// @dev Actual adjudicated supersession and corrective-association adoption remain unsupported.
    function verify(
        T.SuiteConfiguration memory suite,
        StreamArtistRecoveryOriginalReads.Pins memory pins,
        uint256 collectionId,
        bytes32 originalHash,
        bytes32 manifestHash
    ) public view returns (bool valid, bytes32 hash, address signer, uint8 authorityClass) {
        if (collectionId == 0 || originalHash == 0 || manifestHash == 0) {
            return (false, 0, address(0), 0);
        }
        StreamArtistRecoveryOriginalReads.Observation memory o =
            StreamArtistRecoveryOriginalReads.observe(suite, pins, originalHash);
        if (o.scope.collectionId != collectionId) return (false, 0, address(0), 0);
        Recovery.ApprovalTerms memory terms =
            Recovery.ApprovalTerms(pins.finalityRegistry, collectionId, originalHash, manifestHash);
        IStreamArtistRecoveryApprovalOwner owner =
            IStreamArtistRecoveryApprovalOwner(suite.owners[6]);
        hash = owner.recoveryApprovalForAssociation(
            o.sanction.artistId, o.sanction.bindingGeneration, o.sanction.bindingHash, terms
        );
        if (hash == 0) return (false, 0, address(0), 0);
        (Recovery.ApprovalRecord memory r, Approval.Admission memory a) =
            owner.recoveryApprovalRecord(hash);
        if (
            r.recordHash != hash || r.artistId != o.sanction.artistId
                || r.bindingGeneration != o.sanction.bindingGeneration
                || r.bindingHash != o.sanction.bindingHash
                || keccak256(abi.encode(r.terms)) != keccak256(abi.encode(terms))
                || !StreamArtistRecoveryApprovalScopes.supported(o.scope, a.scope)
                || a.originalFinalityCodeHash != pins.finalityCodeHash
                || _recordHash(suite, r) != hash
        ) revert Recovery.InvalidRecoveryApproval();
        return (true, hash, r.signer, r.authorityClass);
    }

    function _recordHash(T.SuiteConfiguration memory suite, Recovery.ApprovalRecord memory r)
        private
        view
        returns (bytes32)
    {
        return StreamArtistRecoveryHashes.approvalRecord(
            StreamArtistHashes.Environment(
                block.chainid, suite.registry, suite.core, suite.mintManager
            ),
            r
        );
    }
}
