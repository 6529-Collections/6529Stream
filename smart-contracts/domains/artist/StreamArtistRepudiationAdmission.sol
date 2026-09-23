// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistRepudiationFacts.sol";
import {
    IStreamRepudiationSuite
} from "../../interfaces/stream/artist/IStreamRepudiationSuite.sol";

/// @notice Fixed owner-side rechecks of the actual Attribution terminal and current Identity head.
library StreamArtistRepudiationAdmission {
    function suite(address registry, address coordinator)
        public
        view
        returns (T.SuiteConfiguration memory s)
    {
        s = IStreamRepudiationSuite(coordinator).suiteConfiguration();
        if (s.registry != registry || s.owners[2] != address(this)) revert T.InvalidBinding();
    }

    function veto(
        T.SuiteConfiguration memory s,
        T.ActionContext memory c,
        RP.GuardianProof memory p
    ) public view returns (RP.Record memory r, bytes32 guardianSet) {
        r = _terminal(s, c, p.repudiationRecordHash, 2);
        if (
            c.operationId != 48 || p.collectionId != r.terms.collectionId || p.vetoer != c.actor
                || p.reasonHash == 0 || p.vetoedAt != block.timestamp
                || p.capturedGuardianSet != r.capturedGuardianSet
        ) revert RP.InvalidRepudiation(r.recordHash);
        RP.Terminal memory t =
            IStreamArtistRepudiationOwner(s.owners[4]).attributionRepudiationTerminal(r.recordHash);
        bytes32 current;
        (,,, current) = IStreamArtistRotationReads(s.owners[2]).guardianSet(r.artistId);
        if (t.reasonHash != p.reasonHash || current != p.currentGuardianSet) {
            revert RP.InvalidRepudiation(r.recordHash);
        }
        if (_member(s.owners[2], r.artistId, p.capturedGuardianSet, c.actor)) {
            guardianSet = p.capturedGuardianSet;
        } else if (_member(s.owners[2], r.artistId, current, c.actor)) {
            guardianSet = current;
        } else {
            revert T.Unauthorized(c.actor);
        }
    }

    function cancellation(
        T.SuiteConfiguration memory s,
        T.ActionContext memory c,
        RP.Record memory expected
    ) public view {
        RP.Record memory r = _terminal(s, c, expected.recordHash, 3);
        if (
            c.operationId != 49 || r.signer != c.actor
                || keccak256(abi.encode(r)) != keccak256(abi.encode(expected))
        ) revert T.Unauthorized(c.actor);
    }

    function _terminal(
        T.SuiteConfiguration memory s,
        T.ActionContext memory c,
        bytes32 hash,
        uint8 phase
    ) private view returns (RP.Record memory r) {
        r = IStreamArtistRepudiationOwner(s.owners[4]).attributionRepudiationRecord(hash);
        RP.Terminal memory t =
            IStreamArtistRepudiationOwner(s.owners[4]).attributionRepudiationTerminal(hash);
        (RP.AuthorityHead memory h, bool live) = StreamArtistRepudiationFacts.head(s, r.artistId);
        (uint8 state, uint64 generation) =
            IStreamArtistAttributionOwner(s.owners[4]).attributionState(r.terms.collectionId);
        if (
            hash == 0 || r.recordHash != hash || t.phase != phase || t.actor != c.actor
                || t.recordedAt != block.timestamp || !live
                || StreamArtistRepudiationHashes.headHash(h)
                    != StreamArtistRepudiationHashes.headHash(r.authorityHead)
                || generation != r.terms.bindingGeneration || (state != 2 && state != 3)
        ) revert RP.InvalidRepudiation(hash);
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
}
