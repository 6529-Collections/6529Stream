// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredDelegationConsentFacts as Facts
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredDelegationConsentFacts.sol";
import {
    StreamArtistRecoveredDelegatedConsentHydration as Consent
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredDelegatedConsentHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistDelegationHydrationTypes as DH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegationAuthorityHydration.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistDelegationState as Delegation
} from "../../../smart-contracts/domains/artist/StreamArtistDelegationState.sol";

/// @notice Synthetic vectors for the cross-owner join only. These do not authenticate a source,
/// exercise signatures, or stand in for the separate full actual-owner/Safe recovered scenarios.
contract StreamArtistRecoveredDelegationConsentFactsTest {
    struct Fixture {
        IH.Bundle identity;
        Consent.Bundle consent;
        AH.Query query;
        RH.Provenance provenance;
        uint8 mode;
    }

    function check(Fixture memory f) external pure {
        Facts.validate(f.identity, f.consent, f.query, f.provenance, f.mode);
    }

    function testDelegationFactsRetainRevokedMixedUsesAcrossSeparateOwnerClocks() external pure {
        Fixture memory f = _fixture();
        Facts.validate(f.identity, f.consent, f.query, f.provenance, f.mode);
        assert(f.identity.delegations[0].record.revoked);
        assert(f.provenance.journals[6][2].position.point.ownerRevision == 2);
        assert(f.provenance.aliases[2][0].admittedAt.ownerRevision == 5);
    }

    function testDelegationFactsRejectOmittedOrInventedGrantUse() external view {
        Fixture memory f = _fixture();
        this.check(f);
        f.identity.delegations[0].record.uses = 2;
        _reject(f);
        f.identity.delegations[0].record.uses = 4;
        _reject(f);
    }

    function testDelegationFactsRequireOriginalGrantCapabilityScopeAndMode() external view {
        Fixture memory f = _fixture();
        this.check(f);
        f.mode = 1;
        _reject(f);
        f.mode = 2;
        f.identity.delegations[0].record.grant.capabilities = D.POLICY_CONSENT | D.ECONOMICS;
        _reject(f);
        f.identity.delegations[0].record.grant.capabilities |= D.SALE_CONSENT;
        f.identity.delegations[0].record.grant.collectionId = 8;
        _reject(f);
        f.identity.delegations[0].record.grant.collectionId = 0;
        this.check(f);
    }

    function testDelegationFactsRejectAbsentGrantAndFutureOrigin() external view {
        Fixture memory f = _fixture();
        this.check(f);
        f.consent.policies[0].grant = keccak256("not retained");
        _reject(f);
        f.consent.policies[0].grant = f.identity.delegations[0].recordHash;
        f.identity.delegations[0].position.point.environmentHash = f.provenance.eras[1].originHash;
        _reject(f);
    }

    function testDelegationFactsRejectConsentAfterEarlierEraRevocation() external view {
        Fixture memory f = _fixture();
        this.check(f);
        f.provenance.journals[2][1].position.point = RH.Point(f.provenance.eras[0].originHash, 2, 9);
        _reject(f);
    }

    function testDelegationFactsBindSaleSignerClassAndOriginalDelegateNonce() external view {
        Fixture memory f = _fixture();
        this.check(f);
        f.consent.sales[0].item.signer = address(99);
        _reject(f);
        f.consent.sales[0].item.signer = f.identity.delegations[0].record.grant.delegate;
        f.consent.sales[0].item.authorityClass = 1;
        _reject(f);
        f.consent.sales[0].item.authorityClass = 2;
        ++f.consent.sales[0].item.nonce;
        _reject(f);
    }

    function testDelegationFactsRejectSaleNonceFromWrongEraOrAfterRevocation() external view {
        Fixture memory f = _fixture();
        this.check(f);
        f.provenance.aliases[2][0].admittedAt.environmentHash = f.provenance.eras[0].originHash;
        _reject(f);
        f.provenance.aliases[2][0].admittedAt.environmentHash = f.provenance.eras[1].originHash;
        f.provenance.aliases[2][0].admittedAt.ownerRevision = 9;
        _reject(f);
    }

    function testDelegationFactsRejectUseOfReplacedVersionAtOriginalIdentityPoint() external view {
        Fixture memory f = _fixture();
        this.check(f);
        IH.DelegationRow[] memory rows = new IH.DelegationRow[](2);
        rows[0] = f.identity.delegations[0];
        rows[1] = IH.DelegationRow(
            RH.Position(RH.Point(f.provenance.eras[1].originHash, 2, 4), 0),
            keccak256("later replacement"),
            D.Record(rows[0].record.grant, address(779), 2, 0, false, 0),
            keccak256("later replacement"),
            1
        );
        f.identity.delegations = rows;
        _reject(f);
    }

    function testDelegationFactsAllowHistoricalEconomicsInModeOne() external pure {
        Fixture memory f = _fixture();
        f.consent.policies = new DH.Policy[](0);
        f.consent.sales = new DH.Sale[](0);
        f.identity.delegations[0].record.uses = 1;
        f.mode = 1;
        Facts.validate(f.identity, f.consent, f.query, f.provenance, f.mode);
    }

    function _reject(Fixture memory f) private view {
        (bool ok, bytes memory reason) = address(this).staticcall(abi.encodeCall(this.check, (f)));
        assert(!ok);
        assert(
            keccak256(reason)
                == keccak256(abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector))
        );
    }

    function _fixture() private pure returns (Fixture memory f) {
        f.mode = 2;
        f.query.artistId = keccak256("artist");
        f.query.collectionId = 7;
        f.query.bindingHash = keccak256("binding");
        f.identity.artistId = f.query.artistId;
        f.identity.delegations = new IH.DelegationRow[](1);
        f.provenance.origins = new RH.OriginEnvironment[](2);
        f.provenance.eras = new RH.Era[](2);
        for (uint256 i; i < 2; ++i) {
            RH.OriginEnvironment memory origin;
            origin.chainId = 1;
            origin.registry = address(uint160(100 + i));
            origin.owners[2] = address(uint160(200 + i));
            origin.ownerCodeHashes[2] = keccak256("synthetic owner identity");
            f.provenance.origins[i] = origin;
            f.provenance.eras[i].originHash = RH.originHash(origin);
            f.provenance.eras[i].checkpoints[2].schema = RH.CHECKPOINT;
            f.provenance.eras[i].checkpoints[2].ownerState.domainId = RH.ownerDomain(2);
            f.provenance.eras[i].checkpoints[2].ownerState.revision = i == 0 ? 100 : 10;
        }
        bytes32 first = f.provenance.eras[0].originHash;
        bytes32 second = f.provenance.eras[1].originHash;
        bytes32 grant = keccak256("original grant");
        bytes32 revocation = keccak256("original revocation");
        D.Grant memory terms = D.Grant(
            f.query.artistId,
            address(777),
            7,
            D.POLICY_CONSENT | D.ECONOMICS | D.SALE_CONSENT,
            1,
            1000,
            0,
            0
        );
        f.identity.delegations[0] = IH.DelegationRow(
            RH.Position(RH.Point(first, 2, 3), 0),
            grant,
            D.Record(terms, address(778), 1, 3, true, revocation),
            grant,
            0
        );
        f.provenance.journals[2] = new RH.JournalEntry[](2);
        f.provenance.journals[2][0] = RH.JournalEntry(
            f.identity.delegations[0].position, H.Receipt(26, f.query.artistId, 0, grant)
        );
        f.provenance.journals[2][1] = RH.JournalEntry(
            RH.Position(RH.Point(second, 2, 8), 0), H.Receipt(27, f.query.artistId, 0, revocation)
        );
        f.consent.artistId = f.query.artistId;
        f.consent.collectionId = 7;
        f.consent.bindingHash = f.query.bindingHash;
        f.consent.policies = new DH.Policy[](1);
        f.consent.policies[0] = DH.Policy(bytes32(uint256(11)), grant);
        f.consent.economics = new Consent.Economics[](1);
        f.consent.economics[0].item.recordHash = bytes32(uint256(12));
        f.consent.economics[0].grant = grant;
        f.consent.sales = new DH.Sale[](1);
        f.consent.sales[0].item.recordHash = bytes32(uint256(13));
        f.consent.sales[0].item.signer = terms.delegate;
        f.consent.sales[0].item.authorityClass = 2;
        f.consent.sales[0].item.nonce = 514;
        f.consent.sales[0].grant = grant;
        f.provenance.journals[6] = new RH.JournalEntry[](3);
        for (uint16 i; i < 3; ++i) {
            f.provenance.journals[6][i] = RH.JournalEntry(
                RH.Position(RH.Point(i == 2 ? second : first, 6, i == 2 ? 2 : i + 1), i),
                H.Receipt(14 + i, f.query.artistId, 7, bytes32(uint256(11 + i)))
            );
        }
        f.provenance.aliases[2] = new RH.ReplayAlias[](1);
        f.provenance.aliases[2][0] = RH.ReplayAlias(
            second,
            2,
            keccak256("identity_authority.replay.delegated_nonce"),
            keccak256(abi.encode(Delegation.lane(f.query.artistId, terms.delegate), uint256(514))),
            keccak256("synthetic original nonce key"),
            T.ReplayCell(keccak256("digest"), 5, 1, 2),
            RH.Point(second, 2, 5)
        );
    }
}
