// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistPublicationHydrationTypes as PubH
} from "../../interfaces/stream/artist/IStreamArtistPublicationAuthorityHydration.sol";
import {
    StreamArtistReadinessHydrationTypes as Ready
} from "../../interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import { StreamArtistDelegationState as Delegation } from "./StreamArtistDelegationState.sol";
import {
    StreamArtistRecoveredHydrationChronology as Chronology
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";

import {
    StreamArtistRecoveredIdentitySourceCanonical as Canonical
} from "./StreamArtistRecoveredIdentitySourceCanonical.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";

/// @notice Original op24 fact predicates for one occurrence in a complete aggregate journal.
/// @dev The aggregate caller owns occurrence bijection and semantic row validation. This leaf
/// preserves original Identity aliases, retained signatures and grant chronology. It does not
/// authenticate present authority or conclude total grant uses across other operations.
library StreamArtistRecoveredMultipleGenerationAttestationRows {
    struct IdentityRows {
        bytes32 artistId;
        IH.SignatureRow[] signatures;
        IH.DelegationRow[] delegations;
    }

    struct Scope {
        bytes32 artistId;
        uint256 collectionId;
        bytes32 bindingHash;
    }
    bytes32 private constant NONCE = keccak256("identity_authority.replay.nonce_allocator");
    bytes32 private constant DELEGATE_NONCE =
        keccak256("identity_authority.replay.delegated_nonce");
    bytes32 private constant ATTESTATION = keccak256("identity_authority.replay.attestation_key");
    bytes32 private constant OBSERVED =
        keccak256("identity_authority.replay.authorization_consumed_digest");

    /// @notice Project one complete, canonical original Identity envelope into op24 facts.
    /// @dev Full decode/reencode remains mandatory, including fields not returned here. The
    /// separate fixed frame avoids carrying the full Identity codec through the aggregate loop.
    function identity(bytes calldata canonical, bytes32 artistId)
        public
        pure
        returns (IdentityRows memory result)
    {
        // The existing fixed field groups decode and reencode every original Bundle field.
        // Only after complete equality may the existing typed canonical view project fields.
        bytes memory normalized = Canonical.canonical(canonical, false);
        if (keccak256(canonical) != keccak256(normalized)) _invalid();
        IH.Bundle calldata id = Frame.bundle(canonical);
        if (id.artistId != artistId) _invalid();
        result = IdentityRows(id.artistId, id.signatures, id.delegations);
    }

    function validate(
        IdentityRows memory identity,
        Ready.AttestationRow memory row,
        Scope memory q,
        RH.Provenance memory p,
        RH.JournalEntry memory native_
    ) public pure returns (uint256 grantIndex) {
        if (
            q.artistId == 0 || identity.artistId != q.artistId || q.collectionId == 0
                || q.bindingHash == 0 || native_.receipt.operation != 24
                || native_.receipt.artistId != q.artistId
                || native_.receipt.collectionId != q.collectionId
                || native_.receipt.recordHash != row.record.recordHash
                || native_.position.point.ownerIndex != 4
        ) _invalid();
        Chronology.validatePoint(p, native_.position.point);
        RH.OriginEnvironment memory origin =
            Provenance.environment(p, native_.position.point.environmentHash);
        if (row.record.generation == 0 || row.record.generation > 128) _invalid();
        bytes32 digest = _record(row, q, origin, row.record.generation);
        _signature(identity, row.record.recordHash);
        RH.Point memory admitted;
        grantIndex = type(uint256).max;
        if (row.authorityClass == 2) {
            bytes32 lane = Delegation.lane(q.artistId, row.record.signer);
            admitted =
                _alias(p, DELEGATE_NONCE, keccak256(abi.encode(lane, row.input.nonce)), digest);
            grantIndex = _grant(identity, p, row, admitted);
        } else {
            admitted = _alias(p, NONCE, keccak256(abi.encode(q.artistId, row.input.nonce)), digest);
            RH.Point memory keyed = _alias(
                p, ATTESTATION, keccak256(abi.encode(row.record.recordHash)), row.record.recordHash
            );
            if (Chronology.compare(p, keyed, admitted) != 0) _invalid();
        }
        if (admitted.environmentHash != native_.position.point.environmentHash) _invalid();
        RH.Point memory observed =
            _alias(p, OBSERVED, keccak256(abi.encode(q.artistId, digest)), digest);
        if (
            observed.environmentHash != admitted.environmentHash
                || Chronology.compare(p, observed, admitted) > 0
        ) _invalid();
    }

    function _record(
        Ready.AttestationRow memory row,
        Scope memory q,
        RH.OriginEnvironment memory origin,
        uint64 generation
    ) private pure returns (bytes32 digest) {
        if (
            row.record.recordHash == 0 || row.record.signer == address(0)
                || row.record.signedAt == 0 || row.record.generation != generation
                || row.input.terms.collectionId != q.collectionId
                || row.input.terms.subjectKind == 0 || row.input.terms.subjectKind > 10
                || row.record.subjectStateHash != row.input.terms.subjectStateHash
                || row.record.schemaId != row.input.terms.schemaId
                || row.record.statementHash != row.input.terms.statementHash
                || row.statement.length == 0 || row.statement.length > 8192
                || keccak256(row.statement) != row.record.statementHash
                || bytes(row.input.terms.statementURI).length > 2048
                || (row.authorityClass != 1 && row.authorityClass != 2 && row.authorityClass != 3)
                || ((row.authorityClass == 2) != (row.association.delegation != 0))
        ) _invalid();
        // Original legacy direct callbacks can have an empty association. A delegated record
        // always has the original authenticated artist/binding/generation association.
        if (
            row.association.delegation != 0
                && (row.association.artistId != q.artistId
                    || row.association.bindingHash != q.bindingHash
                    || row.association.generation != generation)
        ) _invalid();
        Hashes.Environment memory e =
            Hashes.Environment(origin.chainId, origin.registry, origin.core, origin.manager);
        if (
            Hashes.attestationRecordForAuthority(
                    e,
                    row.input.terms,
                    q.artistId,
                    row.record.signer,
                    row.authorityClass,
                    row.input.nonce,
                    row.record.signedAt
                ) != row.record.recordHash
        ) _invalid();
        digest = Hashes.attestationDigest(
            e, row.input.terms, T.Authorization(row.input.nonce, row.record.signedAt, "")
        );
    }

    function _signature(IdentityRows memory identity, bytes32 record) private pure {
        bool found;
        for (uint256 i; i < identity.signatures.length; ++i) {
            if (identity.signatures[i].recordHash != record) continue;
            if (found || identity.signatures[i].signature.length > 4096) _invalid();
            found = true;
        }
        // Empty signature bytes are valid retained evidence. Their exact source bytes were
        // checked by IdentityHydrationRecords; they are not permission to call ERC1271 anew.
        if (!found) _invalid();
    }

    function _alias(RH.Provenance memory p, bytes32 surface, bytes32 scope, bytes32 commitment)
        private
        pure
        returns (RH.Point memory point)
    {
        bool found;
        for (uint256 i; i < p.aliases[2].length; ++i) {
            RH.ReplayAlias memory a = p.aliases[2][i];
            if (a.surface != surface || a.scope != scope) continue;
            if (
                a.cell.kind != 1 || a.cell.status != 2 || a.cell.commitment != commitment
                    || a.admittedAt.ownerIndex != 2
                    || a.cell.touchedRevision != a.admittedAt.ownerRevision
                    || (found
                        && keccak256(abi.encode(point)) != keccak256(abi.encode(a.admittedAt)))
            ) _invalid();
            Chronology.validatePoint(p, a.admittedAt);
            point = a.admittedAt;
            found = true;
        }
        if (!found) _invalid();
    }

    function _grant(
        IdentityRows memory identity,
        RH.Provenance memory p,
        Ready.AttestationRow memory row,
        RH.Point memory admitted
    ) private pure returns (uint256 at) {
        for (uint256 i; i < identity.delegations.length; ++i) {
            IH.DelegationRow memory grant = identity.delegations[i];
            if (grant.recordHash != row.association.delegation) continue;
            uint32 capability = row.input.terms.subjectKind == 7 ? D.INTENT : D.ATTEST;
            if (
                grant.record.grant.artistId != identity.artistId
                    || grant.record.grant.delegate != row.record.signer
                    || (grant.record.grant.collectionId != 0
                        && grant.record.grant.collectionId != row.input.terms.collectionId)
                    || (grant.record.grant.capabilities & capability) == 0
                    || !Chronology.before(p, grant.position.point, admitted)
            ) _invalid();
            if (
                grant.record.revoked
                    && !Chronology.before(
                        p,
                        admitted,
                        _revocation(p, identity.artistId, grant.record.revocationRecordHash)
                    )
            ) _invalid();
            for (uint256 j = i + 1; j < identity.delegations.length; ++j) {
                IH.DelegationRow memory next = identity.delegations[j];
                if (
                    next.record.grant.delegate == grant.record.grant.delegate
                        && !Chronology.before(p, admitted, next.position.point)
                ) _invalid();
            }
            // Original admission already checked validity time, epoch and maxUses. Comparing
            // signedAt with grant times, or the saved grant epoch with today's epoch, is wrong.
            return i;
        }
        _invalid();
    }

    function _revocation(RH.Provenance memory p, bytes32 artist, bytes32 record)
        private
        pure
        returns (RH.Point memory point)
    {
        bool found;
        for (uint256 i; i < p.journals[2].length; ++i) {
            RH.JournalEntry memory row = p.journals[2][i];
            if (row.receipt.recordHash != record) continue;
            if (
                found || row.receipt.operation != 27 || row.receipt.artistId != artist
                    || row.receipt.collectionId != 0 || row.position.point.ownerIndex != 2
            ) _invalid();
            point = row.position.point;
            found = true;
        }
        if (!found || record == 0) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
