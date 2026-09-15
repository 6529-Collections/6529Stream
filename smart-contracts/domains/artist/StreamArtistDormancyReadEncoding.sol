// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistDormancyState.sol";
import "./StreamArtistEstateReads.sol";
import "../../interfaces/stream/core/IStreamCoreBurn.sol";

/// @notice Fixed Identity-local reads of actual dormant notices, closures and authority origins.
library StreamArtistDormancyReadEncoding {
    function state(
        StreamArtistDormancyState.State storage s,
        StreamArtistIdentityState.State storage identity,
        bytes32 id
    ) public view returns (bytes memory) {
        bytes32 notice = s.latestNotice[id];
        uint64 end = s.phases[notice] == 1 ? s.notices[notice].noticeEndsAt : 0;
        return abi.encode(
            identity.identities[id].status, end, s.terminals[s.activation[id]].appointmentBlock
        );
    }

    function notice(StreamArtistDormancyState.State storage s, bytes32 id)
        public
        view
        returns (bytes memory)
    {
        bytes32 n = s.latestNotice[id];
        return abi.encode(n, s.phases[n], s.terminalForNotice[n]);
    }

    function record(StreamArtistDormancyState.State storage s, bytes32 n)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(s.notices[n], s.phases[n], s.terminals[s.terminalForNotice[n]]);
    }

    function initiation(
        StreamArtistDormancyState.State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistEstateState.State storage estate,
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Dorm.Initiation memory p
    ) public view returns (bytes memory) {
        return abi.encode(
            StreamArtistDormancyState.initiationContext(
                s, identity, rotations, estate, resolutions, e, p
            )
        );
    }

    function completion(
        StreamArtistDormancyState.State storage s,
        StreamArtistStewardSanctionState.State storage grants,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistEstateState.State storage estate,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Dorm.Completion memory p,
        bool evidence
    ) public view returns (bytes memory) {
        (Dorm.Context memory context, Dorm.Plan memory plan) = StreamArtistDormancyState.completionContext(
            s, grants, identity, rotations, estate, succession, resolutions, e, p
        );
        if (evidence) return abi.encode(StreamArtistDormancyState.completionEvidence(p, plan));
        return abi.encode(context, plan);
    }

    function authority(
        StreamArtistDormancyState.State storage s,
        StreamArtistEstateState.State storage estate,
        StreamArtistIdentityState.State storage identity,
        bytes32 id
    ) public view returns (bytes memory) {
        T.Identity storage principal = identity.identities[id];
        if (principal.authorityClass == 1 && principal.status == 2) {
            bytes32 n = s.latestNotice[id];
            if (
                s.phases[n] != 1 || s.notices[n].incumbent != principal.authorityAddress
                    || identity.activeIdentity[principal.authorityAddress] != id
            ) revert T.InvalidIdentity(id);
            return abi.encode(
                Estate.AuthorityCapabilities(principal.authorityAddress, 1, 2, 4095, bytes32(0))
            );
        }
        bytes32 origin = s.activation[id];
        if (origin == 0 || principal.authorityClass == 1) {
            return abi.encode(StreamArtistEstateReads.authority(estate, identity, id));
        }
        Dorm.Terminal storage t = s.terminals[origin];
        Dorm.Notice storage n = s.notices[t.noticeHash];
        if (
            t.recordHash != origin || n.terms.artistId != id || s.phases[t.noticeHash] != 3
                || s.terminalForNotice[t.noticeHash] != origin
                || (principal.authorityClass != 3 && principal.authorityClass != 4)
                || principal.authorityClass != t.plan.authorityClass
                || (principal.status != 3 && principal.status != 4)
                || identity.activeIdentity[principal.authorityAddress] != id
        ) revert T.InvalidIdentity(id);
        return abi.encode(
            Estate.AuthorityCapabilities(
                principal.authorityAddress,
                principal.authorityClass,
                principal.status,
                t.plan.capabilities,
                origin
            )
        );
    }

    function requireStewardCollection(
        StreamArtistDormancyState.State storage s,
        StreamArtistIdentityState.State storage identity,
        address core,
        bytes32 id,
        uint8 scopeType,
        uint256 collectionId,
        uint256 tokenId,
        bytes32 scopeId
    ) public view {
        T.Identity storage principal = identity.identities[id];
        if (principal.authorityClass != 4) return;
        bytes32 activation = s.activation[id];
        Dorm.Terminal storage terminal = s.terminals[activation];
        if (
            activation == 0 || terminal.recordHash != activation
                || terminal.plan.authorityClass != 4 || terminal.appointmentBlock == 0
                || s.phases[terminal.noticeHash] != 3
                || s.terminalForNotice[terminal.noticeHash] != activation
                || s.notices[terminal.noticeHash].terms.artistId != id || principal.status != 3
                || identity.activeIdentity[principal.authorityAddress] != id || scopeType != 0
                || collectionId == 0 || tokenId != 0 || scopeId != 0
                || !IStreamCoreBurn(core).collectionBurnsBlocked(collectionId)
        ) revert T.InvalidIdentity(id);
        uint64 boundary = IStreamCoreBurn(core).collectionBurnsBlockedAtBlock(collectionId);
        if (boundary == 0 || boundary > terminal.appointmentBlock) revert T.InvalidIdentity(id);
    }

    function standing(StreamArtistDormancyState.State storage s, bytes32 hash)
        public
        view
        returns (bytes memory)
    {
        Dorm.Terminal storage t = s.terminals[hash];
        Dorm.Notice storage n = s.notices[t.noticeHash];
        if (
            hash == 0 || t.recordHash != hash || s.phases[t.noticeHash] != 3
                || s.terminalForNotice[t.noticeHash] != hash || n.terms.artistId == 0
                || s.transitions[hash].recordHash != hash
        ) revert R.InvalidRotation(hash);
        return abi.encode(n.incumbent, t.plan.guardian, t.plan.standingTail);
    }

    function resolution(StreamArtistDormancyState.State storage s, bytes32 id, bytes32 cause)
        public
        view
        returns (bytes memory)
    {
        bytes32 n = s.causeNotice[cause];
        if (n != 0 && (s.notices[n].recordHash != n || s.notices[n].terms.artistId != id)) {
            revert Dorm.InvalidDormancy(id);
        }
        return abi.encode(n, s.phases[n], s.terminalForNotice[n]);
    }
}
