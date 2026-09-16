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
    /// @dev Original owner read selectors; each branch invokes the unchanged typed encoder.
    function readEncoded(AttrState.State storage s, address core_, bytes calldata data)
        public
        view
        returns (bytes memory)
    {
        bytes4 selector = bytes4(data[:4]);
        if (selector == bytes4(keccak256("attestationAssociation(bytes32)"))) {
            bytes32 record = abi.decode(data[4:], (bytes32));
            return attestationAssociation(s, core_, record);
        }
        if (selector == bytes4(keccak256("platformWorksAdmission(uint256)"))) {
            uint256 collectionId = abi.decode(data[4:], (uint256));
            return platformWorksAdmission(s, core_, collectionId);
        }
        if (selector == bytes4(keccak256("platformWorksState(uint256)"))) {
            uint256 collectionId = abi.decode(data[4:], (uint256));
            return platformWorksState(s, core_, collectionId);
        }
        if (selector == bytes4(keccak256("platformWorksClaimRecord(bytes32)"))) {
            bytes32 hash = abi.decode(data[4:], (bytes32));
            return platformWorksClaimRecord(s, core_, hash);
        }
        if (selector == bytes4(keccak256("platformWorksContestRecord(bytes32)"))) {
            bytes32 hash = abi.decode(data[4:], (bytes32));
            return platformWorksContestRecord(s, core_, hash);
        }
        if (selector == bytes4(keccak256("attributionClaims(uint256)"))) {
            uint256 id = abi.decode(data[4:], (uint256));
            return attributionClaims(s, core_, id);
        }
        if (selector == bytes4(keccak256("attributionClaimRecord(bytes32)"))) {
            bytes32 hash = abi.decode(data[4:], (bytes32));
            return attributionClaimRecord(s, core_, hash);
        }
        if (selector == bytes4(keccak256("attestationAuthorityClass(bytes32)"))) {
            bytes32 hash = abi.decode(data[4:], (bytes32));
            return attestationAuthorityClass(s, core_, hash);
        }
        if (selector == bytes4(keccak256("artistAttestationStatus(uint256,uint8,bytes32,bytes32)")))
        {
            (uint256 id, uint8 kind, bytes32 subjectId, bytes32 currentHash) =
                abi.decode(data[4:], (uint256, uint8, bytes32, bytes32));
            return artistAttestationStatus(s, core_, id, kind, subjectId, currentHash);
        }
        if (selector == bytes4(keccak256("deploymentAttestation(uint256)"))) {
            uint256 id = abi.decode(data[4:], (uint256));
            return deploymentAttestation(s, core_, id);
        }
        if (selector == bytes4(keccak256("attributionState(uint256)"))) {
            uint256 collectionId = abi.decode(data[4:], (uint256));
            return attributionState(s, core_, collectionId);
        }
        if (selector == bytes4(keccak256("attestation(uint256,uint8,bytes32)"))) {
            (uint256 collectionId, uint8 kind, bytes32 subjectId) =
                abi.decode(data[4:], (uint256, uint8, bytes32));
            return attestation(s, core_, collectionId, kind, subjectId);
        }
        if (selector == bytes4(keccak256("attestationRecord(bytes32)"))) {
            bytes32 record = abi.decode(data[4:], (bytes32));
            return attestationRecord(s, core_, record);
        }
        if (selector == bytes4(keccak256("statementBytes(bytes32)"))) {
            bytes32 hash = abi.decode(data[4:], (bytes32));
            return statementBytes(s, core_, hash);
        }
        if (selector == bytes4(keccak256("publicationAttestation(bytes32)"))) {
            bytes32 recordHash = abi.decode(data[4:], (bytes32));
            return publicationAttestation(s, core_, recordHash);
        }
        revert T.InvalidRecord();
    }

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
