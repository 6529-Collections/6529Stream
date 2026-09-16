// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistRepudiationHashes.sol";
import "./StreamArtistDisputeAdmission.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";
import "../../interfaces/stream/artist/IStreamArtistRotationOwner.sol";

/// @notice Current fixed-owner facts. A history-head mismatch permanently voids a staged exit.
library StreamArtistRepudiationFacts {
    function head(T.SuiteConfiguration memory s, bytes32 artistId)
        public
        view
        returns (RP.AuthorityHead memory h, bool live)
    {
        uint8 status;
        (h.principal, h.authorityClass, status,) =
            IStreamArtistIdentityOwner(s.owners[2]).authorityState(artistId);
        live = h.principal != address(0)
            && StreamArtistAuthorityPolicy.ordinary(h.authorityClass, status, false);
        h.latestTransition = IStreamArtistRotationReads(s.owners[2]).lastArtistTransition(artistId);
        h.latestContest =
            IStreamArtistIdentityContestOwner(s.owners[2]).latestIdentityContest(artistId);
        h.latestDismissal = IStreamArtistIdentityDismissalOwner(s.owners[2])
            .latestIdentityContestDismissal(artistId);
    }

    function activeCount(T.SuiteConfiguration memory s, bytes32 artistId)
        public
        view
        returns (uint256)
    {
        (RP.AuthorityHead memory h, bool live) = head(s, artistId);
        if (!live) return 0;
        return IStreamArtistRepudiationOwner(s.owners[4])
            .repudiationCount(artistId, StreamArtistRepudiationHashes.headHash(h));
    }

    function pending(T.SuiteConfiguration memory s, uint256 id)
        public
        view
        returns (uint64, uint64, bytes32)
    {
        bytes32 hash = IStreamArtistRepudiationOwner(s.owners[4]).rawPendingRepudiation(id);
        if (hash == 0) return (0, 0, 0);
        RP.Record memory r =
            IStreamArtistRepudiationOwner(s.owners[4]).attributionRepudiationRecord(hash);
        RP.Terminal memory t =
            IStreamArtistRepudiationOwner(s.owners[4]).attributionRepudiationTerminal(hash);
        (RP.AuthorityHead memory h, bool live) = head(s, r.artistId);
        if (
            r.recordHash != hash || r.terms.collectionId != id || t.phase != 1 || !live
                || StreamArtistRepudiationHashes.headHash(h)
                    != StreamArtistRepudiationHashes.headHash(r.authorityHead)
        ) return (0, 0, 0);
        T.Binding memory b = IStreamArtistBindingOwner(s.owners[0]).binding(id);
        (uint8 state, uint64 generation) =
            IStreamArtistAttributionOwner(s.owners[4]).attributionState(id);
        if (
            b.artistId != r.artistId || b.generation != r.terms.bindingGeneration
                || b.bindingHash != r.bindingHash || generation != b.generation
                || (state != 2 && state != 3)
        ) return (0, 0, 0);
        return (r.terms.bindingGeneration, r.executableAt, hash);
    }

    function requireLive(T.SuiteConfiguration memory s, uint256 id, bytes32 hash, bool capability)
        public
        view
        returns (RP.Record memory r)
    {
        //48/49 retain their original0x14 read mask. The fixed Attribution generation
        //was installed atomically with Binding; current binding bytes are rechecked for50.
        r = IStreamArtistRepudiationOwner(s.owners[4]).attributionRepudiationRecord(hash);
        RP.Terminal memory terminal_ =
            IStreamArtistRepudiationOwner(s.owners[4]).attributionRepudiationTerminal(hash);
        (RP.AuthorityHead memory h, bool live) = head(s, r.artistId);
        (uint8 state, uint64 generation) =
            IStreamArtistAttributionOwner(s.owners[4]).attributionState(id);
        if (
            hash == 0 || r.recordHash != hash || r.terms.collectionId != id
                || IStreamArtistRepudiationOwner(s.owners[4]).rawPendingRepudiation(id) != hash
                || terminal_.phase != 1 || !live || generation != r.terms.bindingGeneration
                || (state != 2 && state != 3)
                || StreamArtistRepudiationHashes.headHash(h)
                    != StreamArtistRepudiationHashes.headHash(r.authorityHead)
        ) revert RP.InvalidRepudiation(hash);
        if (capability) {
            T.Binding memory b = IStreamArtistBindingOwner(s.owners[0]).binding(id);
            if (
                b.artistId != r.artistId || b.generation != r.terms.bindingGeneration
                    || b.bindingHash != r.bindingHash || !b.accepted
            ) revert RP.InvalidRepudiation(hash);
            _capability(s, r.artistId, r.signer, r.authorityClass);
        }
    }

    function stage(T.SuiteConfiguration memory s, AD.Filing memory p)
        public
        view
        returns (RP.Admission memory a)
    {
        StreamArtistRepudiationHashes.validate(p);
        uint8 state;
        (a.binding_, state,) =
            StreamArtistDisputeAdmission.binding(s, p.collectionId, p.bindingGeneration);
        if (!a.binding_.accepted || (state != 2 && state != 3)) revert RP.InvalidRepudiation(0);
        bool live;
        (a.authorityHead, live) = head(s, a.binding_.artistId);
        if (!live) revert T.InvalidIdentity(a.binding_.artistId);
        _capability(
            s, a.binding_.artistId, a.authorityHead.principal, a.authorityHead.authorityClass
        );
        C.BindingTerms memory terms = IStreamArtistCollaboratorBindingOwner(s.owners[0])
            .bindingTerms(p.collectionId, p.bindingGeneration);
        if (
            terms.mode != 0 || terms.threshold != 0
                || terms.capabilityPolicySetHash != StreamArtistHashes.emptyCapabilities()
        ) revert T.UnsupportedProfile();
        (,, bytes32 current) = pending(s, p.collectionId);
        if (current != 0) revert RP.ActiveRepudiation(a.binding_.artistId);
        (uint64 value,, uint64 revision) = IStreamArtistWindows(s.owners[2])
            .artistWindowInfo(keccak256("ARTIST_REPUDIATION_CONTEST_SECONDS"));
        if (
            value < 3 days || revision == 0 || block.timestamp == 0
                || uint256(value) + block.timestamp > type(uint64).max
        ) revert T.InvalidRecord();
        (,,, a.guardianSet) =
            IStreamArtistRotationReads(s.owners[2]).guardianSet(a.binding_.artistId);
        a.stagedAt = uint64(block.timestamp);
        a.executableAt = uint64(block.timestamp + value);
        a.windowRevision = revision;
    }

    function guardianProof(
        T.SuiteConfiguration memory s,
        address actor,
        uint256 id,
        bytes32 hash,
        bytes32 reason
    ) public view returns (RP.GuardianProof memory p) {
        RP.Record memory r = requireLive(s, id, hash, false);
        if (reason == 0 || block.timestamp > type(uint64).max) revert RP.InvalidRepudiation(hash);
        bytes32 current;
        (,,, current) = IStreamArtistRotationReads(s.owners[2]).guardianSet(r.artistId);
        if (
            !_member(s.owners[2], r.artistId, r.capturedGuardianSet, actor)
                && !_member(s.owners[2], r.artistId, current, actor)
        ) revert T.Unauthorized(actor);
        return RP.GuardianProof(
            id, hash, r.capturedGuardianSet, current, actor, reason, uint64(block.timestamp)
        );
    }

    function _member(address owner, bytes32 id, bytes32 hash, address actor)
        private
        view
        returns (bool)
    {
        if (hash == 0) return false;
        R.GuardianRecord memory r = IStreamArtistRotationReads(owner).guardianSetRecord(hash);
        if (r.recordHash != hash || r.terms.artistId != id) revert RP.InvalidRepudiation(hash);
        for (uint256 i; i < r.terms.guardians.length; ++i) {
            if (r.terms.guardians[i] == actor) return true;
        }
        return false;
    }

    function _capability(T.SuiteConfiguration memory s, bytes32 id, address principal, uint8 class_)
        private
        view
    {
        if (class_ == 1) return;
        Estate.AuthorityCapabilities memory a =
            IStreamArtistEstateOwner(s.owners[2]).currentAuthorityCapabilities(id);
        if (
            (class_ != 3 && class_ != 4) || a.authorityAddress != principal
                || a.authorityClass != class_ || a.status != 3
                || (a.effectiveCapabilities & 16) != 16 || a.activationRecordHash == 0
        ) revert Estate.EstateCapabilityUnavailable(id, 16);
    }
}
