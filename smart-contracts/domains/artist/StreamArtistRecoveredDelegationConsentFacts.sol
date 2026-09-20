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
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    StreamArtistRecoveredDelegatedConsentHydration as Consent
} from "./StreamArtistRecoveredDelegatedConsentHydration.sol";
import {
    StreamArtistRecoveredHydrationChronology as Chronology
} from "./StreamArtistRecoveredHydrationChronology.sol";
import { StreamArtistDelegationState as Delegation } from "./StreamArtistDelegationState.sol";

/// @notice Complete original grant-use reconciliation across the two fixed semantic owners.
/// @dev The source certificate authenticates the original grant and consent maps. Policy and
/// economics rows do not retain signer/nonce/time preimages, so their original fixed association
/// is not reauthorized against current grant liveness. Sale rows retain the delegate nonce and
/// additionally join its original Identity admission clock. Different owner revisions are never
/// compared; import-era ordering is shared, while within-era authority comes from the producer.
library StreamArtistRecoveredDelegationConsentFacts {
    bytes32 private constant DELEGATE_NONCE =
        keccak256("identity_authority.replay.delegated_nonce");

    function validate(
        IH.Bundle memory identity,
        Consent.Bundle memory consent,
        AH.Query memory q,
        RH.Provenance memory p,
        uint8 mode
    ) public pure {
        if (
            identity.artistId != q.artistId || consent.artistId != q.artistId
                || consent.collectionId != q.collectionId || consent.bindingHash != q.bindingHash
                || (mode != 1 && mode != 2)
        ) _invalid();
        uint256[] memory uses = new uint256[](identity.delegations.length);
        for (uint256 i; i < consent.policies.length; ++i) {
            bytes32 grant = consent.policies[i].grant;
            if (grant == 0) continue;
            if (mode != 2) _invalid();
            ++uses[
                _grant(
                    identity,
                    p,
                    q.collectionId,
                    grant,
                    D.POLICY_CONSENT,
                    consent.policies[i].recordHash
                )
            ];
        }
        for (uint256 i; i < consent.economics.length; ++i) {
            bytes32 grant = consent.economics[i].grant;
            if (grant == 0) continue;
            ++uses[
                _grant(
                    identity,
                    p,
                    q.collectionId,
                    grant,
                    D.ECONOMICS,
                    consent.economics[i].item.recordHash
                )
            ];
        }
        for (uint256 i; i < consent.sales.length; ++i) {
            bytes32 grant = consent.sales[i].grant;
            if (grant == 0) continue;
            if (mode != 2) _invalid();
            uint256 at = _grant(
                identity, p, q.collectionId, grant, D.SALE_CONSENT, consent.sales[i].item.recordHash
            );
            if (
                consent.sales[i].item.authorityClass != 2
                    || consent.sales[i].item.signer
                        != identity.delegations[at].record.grant.delegate
            ) _invalid();
            _saleNonce(
                identity, p, at, consent.sales[i].item.recordHash, consent.sales[i].item.nonce
            );
            ++uses[at];
        }
        // Every grant version is retained, including expired/revoked/old-epoch versions.
        // Uses by another collection or unsupported record family cannot be projected away.
        for (uint256 i; i < uses.length; ++i) {
            if (uses[i] != identity.delegations[i].record.uses) _invalid();
        }
    }

    function _grant(
        IH.Bundle memory identity,
        RH.Provenance memory p,
        uint256 collectionId,
        bytes32 hash,
        uint32 capability,
        bytes32 consentRecord
    ) private pure returns (uint256 at) {
        RH.Point memory consentPoint = _consentPoint(p, consentRecord);
        uint256 useEra = _era(p, consentPoint.environmentHash);
        for (uint256 i; i < identity.delegations.length; ++i) {
            IH.DelegationRow memory row = identity.delegations[i];
            if (row.recordHash != hash) continue;
            D.Grant memory grant = row.record.grant;
            if (
                grant.artistId != identity.artistId
                    || (grant.collectionId != 0 && grant.collectionId != collectionId)
                    || (grant.capabilities & capability) == 0
                    || _era(p, row.position.point.environmentHash) > useEra
            ) _invalid();
            if (row.record.revoked) {
                RH.Point memory revokedAt = _revocationPoint(p, row.record.revocationRecordHash);
                if (_era(p, revokedAt.environmentHash) < useEra) _invalid();
            }
            return i;
        }
        _invalid();
    }

    function _saleNonce(
        IH.Bundle memory identity,
        RH.Provenance memory p,
        uint256 grantIndex,
        bytes32 sale,
        uint256 nonce
    ) private pure {
        IH.DelegationRow memory grant = identity.delegations[grantIndex];
        bytes32 lane = Delegation.lane(identity.artistId, grant.record.grant.delegate);
        bytes32 scope = keccak256(abi.encode(lane, nonce));
        RH.Point memory salePoint = _consentPoint(p, sale);
        RH.Point memory admitted;
        bool found;
        for (uint256 i; i < p.aliases[2].length; ++i) {
            RH.ReplayAlias memory alias_ = p.aliases[2][i];
            if (alias_.surface != DELEGATE_NONCE || alias_.scope != scope) continue;
            if (
                alias_.cell.kind != 1 || alias_.cell.status != 2 || alias_.cell.commitment == 0
                    || alias_.admittedAt.environmentHash != salePoint.environmentHash
                    || (found
                        && keccak256(abi.encode(admitted))
                            != keccak256(abi.encode(alias_.admittedAt)))
            ) _invalid();
            admitted = alias_.admittedAt;
            found = true;
        }
        if (!found || !Chronology.before(p, grant.position.point, admitted)) _invalid();
        if (
            grant.record.revoked
                && !Chronology.before(
                    p, admitted, _revocationPoint(p, grant.record.revocationRecordHash)
                )
        ) {
            _invalid();
        }
        // A later replacement for the same delegate cannot have preceded this use.
        for (uint256 i = grantIndex + 1; i < identity.delegations.length; ++i) {
            IH.DelegationRow memory next = identity.delegations[i];
            if (
                next.record.grant.delegate == grant.record.grant.delegate
                    && !Chronology.before(p, admitted, next.position.point)
            ) _invalid();
        }
    }

    function _consentPoint(RH.Provenance memory p, bytes32 record)
        private
        pure
        returns (RH.Point memory)
    {
        for (uint256 i; i < p.journals[6].length; ++i) {
            if (p.journals[6][i].receipt.recordHash == record) {
                return p.journals[6][i].position.point;
            }
        }
        _invalid();
    }

    function _revocationPoint(RH.Provenance memory p, bytes32 record)
        private
        pure
        returns (RH.Point memory)
    {
        for (uint256 i; i < p.journals[2].length; ++i) {
            if (
                p.journals[2][i].receipt.operation == 27
                    && p.journals[2][i].receipt.recordHash == record
            ) {
                return p.journals[2][i].position.point;
            }
        }
        _invalid();
    }

    function _era(RH.Provenance memory p, bytes32 origin) private pure returns (uint256) {
        for (uint256 i; i < p.eras.length; ++i) {
            if (p.eras[i].originHash == origin) return i;
        }
        _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
