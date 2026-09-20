// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredExternalGuards as External
} from "./StreamArtistRecoveredExternalGuards.sol";
import {
    StreamArtistRecoveredPayloadHydration as Publications
} from "./StreamArtistRecoveredPayloadHydration.sol";

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredPayoutTypes as P
} from "../../interfaces/stream/artist/StreamArtistRecoveredPayoutTypes.sol";
import {
    IStreamArtistRecoveredHydrationOwner as Owner
} from "../../interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    IStreamArtistRecoveredTimingInventory
} from "../../interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";
import {
    StreamArtistRecoveredHydrationAdmission as Admission
} from "./StreamArtistRecoveredHydrationAdmission.sol";
import {
    StreamArtistRecoveredHydrationCommit as Commit
} from "./StreamArtistRecoveredHydrationCommit.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredHydrationGuards as Guards
} from "./StreamArtistRecoveredHydrationGuards.sol";
import {
    StreamArtistRecoveredHydrationCodec as Codec
} from "./StreamArtistRecoveredHydrationCodec.sol";
import {
    StreamArtistRecoveredIdentityHydrationSource as Identity
} from "./StreamArtistRecoveredIdentityHydrationSource.sol";
import {
    StreamArtistRecoveredPayoutHydration as Payout
} from "./StreamArtistRecoveredPayoutHydration.sol";
import {
    StreamArtistRecoveredEconomicsHydration as Economics
} from "./StreamArtistRecoveredEconomicsHydration.sol";
import {
    StreamArtistRecoveredDelegatedConsentHydration as Delegated
} from "./StreamArtistRecoveredDelegatedConsentHydration.sol";
import {
    StreamArtistRecoveredDelegationConsentFacts as DelegationFacts
} from "./StreamArtistRecoveredDelegationConsentFacts.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";

/// @notice Complete seven-owner certificate for the admitted recovered-authority graphs.
/// @dev One recovered class1/class3 subject and one accepted generation-one binding without collaborators.
/// Fixed typed exporters reject unsupported histories; every native occurrence, replay cell and
/// nonce tree must be accounted for. No request witness can replace original producer state.
library StreamArtistRecoveredHydrationPrepared {
    function collect(T.SuiteConfiguration memory destination, RH.Request memory request)
        public
        view
        returns (Commit.Prepared memory prepared)
    {
        prepared = prepare(destination, request);
        if (
            request.expectedSemanticInventory == 0
                || request.expectedSemanticInventory != inventory(prepared)
        ) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
    }

    /// @notice Read-only certificate construction so callers can compute the expected inventory.
    /// @dev Performs the same complete source checks. The mutation route always calls collect,
    /// which additionally requires the caller's exact nonzero expected inventory.
    function prepare(T.SuiteConfiguration memory destination, RH.Request memory request)
        public
        view
        returns (Commit.Prepared memory prepared)
    {
        if (
            request.records.authority.artistIds.length != 1
                || request.records.authority.collections.length != 1
        ) revert T.UnsupportedProfile();
        prepared.admission = Admission.collect(destination, request);
        Admission.Certificate memory c = prepared.admission;
        prepared.query = c.collections[0];
        if (prepared.query.artistId != c.artists[0].artistId) revert T.InvalidRecord();
        // Identity retains signatures for the entire original artist lane, including secondary
        // occurrences. Collection owners read their exact typed selectors from the same query.
        prepared.query.records = c.artists[0].records;
        T.EconomicsConsent[] memory economics = _economics(c, request);
        IH.Bundle memory identity = Identity.collect(
            c.source.owners[2], prepared.query, RH.ownerProvenance(c.provenance, 2)
        );
        P.Bundle memory payout =
            Payout.collect(c.source.owners[5], prepared.query.artistId, c.provenance);
        prepared.externalGuards = External.collect(c.provenance, identity);
        prepared.timing = identity.timing.checkpoint;
        if (
            keccak256(abi.encode(prepared.timing))
                != keccak256(
                    abi.encode(
                        IStreamArtistRecoveredTimingInventory(c.source.owners[2])
                            .recoveredTimingCheckpoint()
                    )
                )
        ) revert RH.InvalidRecoveredHydrationProvenance();
        uint256 features = requiredFeatures(identity, payout, c.provenance.eras.length);
        if (economics.length != 0) features |= RH.DIRECT_ECONOMICS;
        uint8 consentMode =
            Binding(c.source.owners[0]).binding(prepared.query.collectionId).consentMode;
        bool hasDelegation = _delegation(identity, c.provenance, consentMode);
        Delegated.Bundle memory delegated;
        if (hasDelegation) {
            features |= RH.DELEGATED_CONSENT;
            delegated = Delegated.collect(
                c.source.owners[6], prepared.query, RH.ownerProvenance(c.provenance, 6), economics
            );
            DelegationFacts.validate(identity, delegated, prepared.query, c.provenance, consentMode);
        }
        for (uint8 i; i < 7; ++i) {
            _capabilities(
                c.source.owners[i],
                destination.owners[i],
                i,
                features,
                request.expectedCapabilities[i]
            );
            Payload.Payload memory payload;
            payload.provenance = RH.ownerProvenance(c.provenance, i);
            payload.publications = Publications.collect(c.source.owners[i], i);
            (prepared.data[i], payload.nonces) =
                Guards.collect(c.provenance, i, request.records.authority.replayOrigins[i]);
            if (i == 2) {
                _nonces(identity, payload.nonces);
                payload.semanticState = Identity.encode(identity, payload.provenance);
            } else if (i == 5) {
                // The joined validator binds original Identity35/nonce admission and retained
                // Payout continuations; an owner-local export alone is insufficient here.
                payload.semanticState = Payout.encode(payout, c.provenance);
            } else if (i == 6 && hasDelegation) {
                payload.semanticState =
                    Delegated.encode(delegated, prepared.query, payload.provenance);
            } else if (i == 6 && economics.length != 0) {
                payload.semanticState = Economics.encode(
                    Economics.collect(
                        c.source.owners[i], prepared.query, payload.provenance, economics
                    ),
                    prepared.query,
                    payload.provenance
                );
            } else {
                payload.semanticState = Owner(c.source.owners[i])
                    .recoveredAuthorityHydrationState(prepared.query, payload.provenance);
            }
            prepared.data[i].typedState = Payload.encode(i, _header(i, features, payload), payload);
        }
    }

    /// @dev Actual source history and immutable binding mode select the complete extension.
    /// Grants remain relevant even when expired, revoked, unused or invalidated by recovery.
    function _delegation(IH.Bundle memory identity, RH.Provenance memory p, uint8 mode)
        private
        pure
        returns (bool)
    {
        if (identity.delegations.length != 0 || mode == 2) return true;
        for (uint256 i; i < p.journals[6].length; ++i) {
            if (p.journals[6][i].receipt.operation == 16) return true;
        }
        return false;
    }

    /// @dev Native history selects the extension. Witnesses supply exact retained terms,
    /// never authority or a projection of a larger source. No live assignment is rechecked.
    function _economics(Admission.Certificate memory c, RH.Request memory request)
        private
        pure
        returns (T.EconomicsConsent[] memory terms)
    {
        uint256 count;
        for (uint256 i; i < c.provenance.journals[6].length; ++i) {
            if (c.provenance.journals[6][i].receipt.operation == 15) ++count;
        }
        if (count == 0) {
            if (request.records.witnesses.length != 0) revert T.UnsupportedProfile();
            return new T.EconomicsConsent[](0);
        }
        if (
            count > 128 || request.records.witnesses.length != 1
                || request.records.witnesses[0].collectionId != c.collections[0].collectionId
                || request.records.witnesses[0].economics.length != count
                || request.records.witnesses[0].attestations.length != 0
        ) revert T.UnsupportedProfile();
        terms = request.records.witnesses[0].economics;
        for (uint256 i; i < terms.length; ++i) {
            if (
                terms[i].resolver != c.source.primaryResolver
                    && terms[i].resolver != c.source.royaltyResolver
            ) revert T.UnsupportedProfile();
        }
    }

    /// @notice Canonical inventory identifier, independent of the caller's expected value.
    /// @dev Includes complete typed payloads, nonce words, source guards and the timing checkpoint.
    function inventory(Commit.Prepared memory p) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERED_SEMANTIC_INVENTORY_V1"),
                RH.VERSION,
                RH.provenanceHash(p.admission.provenance),
                p.query,
                p.data,
                p.timing,
                p.externalGuards
            )
        );
    }

    function requiredFeatures(IH.Bundle memory identity, P.Bundle memory payout, uint256 eras)
        public
        pure
        returns (uint256 features)
    {
        features = _class(identity.identity.authorityClass);
        for (uint256 i; i < identity.recoveries.length; ++i) {
            features |= _class(identity.recoveries[i].record.fields.vestedAuthorityClass);
        }
        for (uint256 i; i < identity.actions.length; ++i) {
            if (identity.actions[i].evidenceV2.manifestHash != 0) features |= RH.ADJUDICATION_V2;
            if (identity.actions[i].evidenceV3.manifestHash != 0) features |= RH.REWINDS_V3;
        }
        if (
            identity.revisionContinuations.length != 0 || identity.standingContinuations.length != 0
                || identity.capabilityContinuations.length != 0 || payout.continuations.length != 0
        ) {
            features |= RH.REWINDS_V3;
        }
        if (eras > 1) features |= RH.REPEATED_IMPORT;
        if (eras == 0 || eras > RH.MAX_ERAS) revert RH.InvalidRecoveredHydrationProfile();
    }

    function _class(uint8 authorityClass) private pure returns (uint256) {
        if (authorityClass == 1) return RH.CLASS_ONE;
        if (authorityClass == 3) return RH.CLASS_THREE;
        revert T.UnsupportedProfile();
    }

    function _capabilities(
        address source,
        address destination,
        uint8 i,
        uint256 features,
        RH.Capability memory expected
    ) private view {
        RH.Capability memory actual = Owner(source).recoveredAuthorityHydrationCapability();
        if (keccak256(abi.encode(actual)) != keccak256(abi.encode(expected))) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        Codec.requireCapability(actual, i, features);
        Codec.requireCapability(
            Owner(destination).recoveredAuthorityHydrationCapability(), i, features
        );
    }

    function _nonces(IH.Bundle memory b, RH.NonceInventory[] memory nonces) private pure {
        if (b.nonces.length != nonces.length) revert RH.InvalidRecoveredHydrationProvenance();
        for (uint256 i; i < nonces.length; ++i) {
            if (
                b.nonces[i].kind != nonces[i].index.kind || b.nonces[i].key != nonces[i].index.key
                    || keccak256(abi.encode(b.nonces[i].words))
                        != keccak256(abi.encode(nonces[i].words))
            ) {
                revert RH.InvalidRecoveredHydrationProvenance();
            }
        }
    }

    function _header(uint8 i, uint256 features, Payload.Payload memory p)
        private
        pure
        returns (RH.ExportHeader memory h)
    {
        RH.OwnerEra memory last = p.provenance.eras[p.provenance.eras.length - 1];
        h = RH.ExportHeader(
            RH.PROFILE,
            RH.VERSION,
            i,
            last.originHash,
            last.priorImportCommitment,
            keccak256(p.semanticState),
            RH.ownerProvenanceHash(p.provenance, i),
            RH.aliasesHash(i, p.provenance.aliases),
            features,
            p.provenance.journal.length,
            p.provenance.aliases.length,
            p.provenance.eras.length
        );
    }
}
