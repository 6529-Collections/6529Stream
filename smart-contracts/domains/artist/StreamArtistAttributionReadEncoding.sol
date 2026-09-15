// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistAttributionStateTypes as AttrState
} from "./StreamArtistAttributionStateTypes.sol";

import "./StreamArtistPlatformState.sol";
import {
    StreamArtistAttestationTypes as Attest
} from "../../interfaces/stream/artist/IStreamArtistAttestationWriter.sol";
import "./StreamArtistAttributionClaimState.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionClaims.sol";
import "../../interfaces/stream/artist/IStreamArtistDisplayFacts.sol";
import "./StreamArtistAttributionPolicy.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityRevision.sol";

import "./StreamArtistOwner.sol";
import "./StreamArtistCurrentAuthorityFacts.sol";
import "./StreamArtistRecordPublicationState.sol";
import "../../interfaces/stream/artist/IStreamArtistRecordPublicationOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistSanctionConfirmation.sol";
import {
    StreamArtistBindingLifecycleTypes as L
} from "../../interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Canonical encoded reads over the fixed Attribution owner storage.
library StreamArtistAttributionReadEncoding {
    function _authorityClass(AttrState.State storage s, bytes32 hash) private view returns (uint8) {
        if (hash == 0 || s.records[hash].recordHash != hash) return 0;
        uint8 class_ = s.attestationClasses[hash];
        if (class_ != 0) return class_;
        // Existing publication history has an exact saved class; other old records remain unknown.
        if (s.publications[hash].evidence.attestationRecordHash == hash) {
            return s.publications[hash].evidence.authorityClass;
        }
        return 0;
    }

    function attestationAssociation(AttrState.State storage s, address core_, bytes32 record)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(s.attestationAssociations[record]);
    }

    function platformWorksAdmission(AttrState.State storage s, address core_, uint256 collectionId)
        public
        view
        returns (bytes memory)
    {
        PW.State storage p = s.platform.collections[collectionId];
        return abi.encode(
            PW.Admission(
                p.declaration.recordHash,
                p.contestState,
                p.correction.correctiveGeneration,
                p.correction.accepted
            )
        );
    }

    function platformWorksState(AttrState.State storage s, address core_, uint256 collectionId)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(s.platform.collections[collectionId]);
    }

    function platformWorksClaimRecord(AttrState.State storage s, address core_, bytes32 hash)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(s.platform.claims[hash]);
    }

    function platformWorksContestRecord(AttrState.State storage s, address core_, bytes32 hash)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(s.platform.contests[hash]);
    }

    function attributionClaims(AttrState.State storage s, address core_, uint256 id)
        public
        view
        returns (bytes memory)
    {
        PW.State storage p = s.platform.collections[id];
        uint256 artistClaims = s.attributionClaims.counts[id];
        // Original Platform-only histories predate this additive display pointer.
        if (artistClaims == 0) return abi.encode(p.claimCount, p.latestClaim);
        return abi.encode(p.claimCount + artistClaims, s.latestDisplayClaim[id]);
    }

    function attributionClaimRecord(AttrState.State storage s, address core_, bytes32 hash)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(s.attributionClaims.records[hash]);
    }

    function attestationAuthorityClass(AttrState.State storage s, address core_, bytes32 hash)
        public
        view
        returns (bytes memory)
    {
        if (hash == 0 || s.records[hash].recordHash != hash) return abi.encode(0);
        uint8 class_ = s.attestationClasses[hash];
        if (class_ != 0) return abi.encode(class_);
        // Existing publication history has an exact saved class; other old records remain unknown.
        if (s.publications[hash].evidence.attestationRecordHash == hash) {
            return abi.encode(s.publications[hash].evidence.authorityClass);
        }
        return abi.encode(0);
    }

    function artistAttestationStatus(
        AttrState.State storage s,
        address core_,
        uint256 id,
        uint8 kind,
        bytes32 subjectId,
        bytes32 currentHash
    ) public view returns (bytes memory) {
        T.AttestationRecord storage item =
            s.attestations[keccak256(abi.encode(id, kind, subjectId))];
        if (item.recordHash == 0) return abi.encode(0, 0, 0, 0, 0);
        AttrState.Attribution storage attr = s.attributions[id];
        uint8 status = attr.state == 4
            ? 3
            : attr.generation != item.generation
                || !StreamArtistAttributionPolicy.acceptedOrSanctioned(attr.state)
                || (kind != 8 && item.subjectStateHash != currentHash)
                ? 2
                : 1;
        return abi.encode(
            status,
            item.recordHash,
            item.subjectStateHash,
            _authorityClass(s, item.recordHash),
            item.signedAt
        );
    }

    function deploymentAttestation(AttrState.State storage s, address core_, uint256 id)
        public
        view
        returns (bytes memory)
    {
        T.AttestationRecord storage item = s.attestations[
            keccak256(abi.encode(id, uint8(9), bytes32(uint256(uint160(core_)))))
        ];
        return abi.encode(item.recordHash, _authorityClass(s, item.recordHash), item.signedAt);
    }

    function attributionState(AttrState.State storage s, address core_, uint256 collectionId)
        public
        view
        returns (bytes memory)
    {
        AttrState.Attribution storage a = s.attributions[collectionId];
        return abi.encode(a.state, a.generation);
    }

    function attestation(
        AttrState.State storage s,
        address core_,
        uint256 collectionId,
        uint8 kind,
        bytes32 subjectId
    ) public view returns (bytes memory) {
        return abi.encode(s.attestations[keccak256(abi.encode(collectionId, kind, subjectId))]);
    }

    function attestationRecord(AttrState.State storage s, address core_, bytes32 record)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(s.records[record]);
    }

    function statementBytes(AttrState.State storage s, address core_, bytes32 hash)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(s.statements[hash]);
    }

    function publicationAttestation(AttrState.State storage s, address core_, bytes32 recordHash)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(s.publications[recordHash]);
    }
}
