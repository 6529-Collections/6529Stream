// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistAttributionOwner as Attribution
} from "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    StreamArtistRecoveredBindingGenerations as Generations
} from "./StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistRecoveredPreparationGenerationFacts as Facts
} from "./StreamArtistRecoveredPreparationGenerationFacts.sol";
import {
    StreamArtistRecoveredPreparationTuple as Tuple
} from "./StreamArtistRecoveredPreparationTuple.sol";

import {
    StreamArtistRecoveredAttestationFacts as AttestationFacts
} from "./StreamArtistRecoveredAttestationFacts.sol";

import {
    StreamArtistRecoveredAttestationHydration as Attestations
} from "./StreamArtistRecoveredAttestationHydration.sol";

import {
    StreamArtistRecoveredGenerationConsents as GenerationConsents
} from "./StreamArtistRecoveredGenerationConsents.sol";
import {
    StreamArtistRecoveredGenerationConsentFacts as ConsentFacts
} from "./StreamArtistRecoveredGenerationConsentFacts.sol";
import {
    StreamArtistRecoveredContentConsentHydration as ContentH
} from "./StreamArtistRecoveredContentConsentHydration.sol";

import {
    StreamArtistRecoveredGenerationBaseConsents as GenerationBase
} from "./StreamArtistRecoveredGenerationBaseConsents.sol";
import {
    StreamArtistRecoveredGenerationBaseConsentFacts as BaseFacts
} from "./StreamArtistRecoveredGenerationBaseConsentFacts.sol";

import {
    StreamArtistRecoveredBindingGenerationModes as Modes
} from "./StreamArtistRecoveredBindingGenerationModes.sol";
import {
    StreamArtistRecoveredGenerationDelegatedConsents as Delegated
} from "./StreamArtistRecoveredGenerationDelegatedConsents.sol";
import {
    StreamArtistRecoveredGenerationDelegatedConsentFacts as DelegatedFacts
} from "./StreamArtistRecoveredGenerationDelegatedConsentFacts.sol";

/// @notice Original bounded generation selection and complete source joins before attestations.
library StreamArtistRecoveredPreparationGenerations {
    function collect(
        T.SuiteConfiguration memory source,
        AH.Query memory query,
        RH.Provenance memory provenance,
        bytes memory identity,
        bool hasIdentityDelegations,
        uint256 witnessCount,
        uint256 royaltyFreezeCount
    ) public view returns (bytes memory encoded, uint8 consentMode, bool hasGenerations) {
        T.Binding memory current = Binding(source.owners[0]).binding(query.collectionId);
        consentMode = current.consentMode;
        hasGenerations = current.generation > 1;
        if (!hasGenerations) return (encoded, consentMode, false);
        if (consentMode != 1 && consentMode != 2) {
            revert T.UnsupportedProfile();
        }
        hasIdentityDelegations; // Full inventory is reconciled by contentFactsWithAuthority.
        // The earlier witness collector authenticates exact original15/24 counts. Royalty
        // witnesses must separately match every original20 occurrence, never a projection.
        bool needsWitness = provenance.journals[4].length != 0;
        uint256 royalties;
        for (uint256 i; i < provenance.journals[4].length; ++i) {
            if (provenance.journals[4][i].receipt.operation != 24) revert T.UnsupportedProfile();
        }
        for (uint256 i; i < provenance.journals[6].length; ++i) {
            uint16 op = provenance.journals[6][i].receipt.operation;
            if (op == 15) needsWitness = true;
            if (op == 20) ++royalties;
            if (op != 14 && op != 15 && op != 16 && op != 17 && op != 20 && op != 21) {
                revert T.UnsupportedProfile();
            }
        }
        if (witnessCount != (needsWitness ? 1 : 0) || royaltyFreezeCount != royalties) {
            revert T.UnsupportedProfile();
        }
        Generations.Bundle memory generations =
            Modes.collect(source.owners[0], query, RH.ownerProvenance(provenance, 0));
        encoded = abi.encode(generations);
        if (address(Facts).code.length == 0) assembly ("memory-safe") { revert(0, 0) }
        (bool ok, bytes memory result) = address(Facts)
            .staticcall(
                bytes.concat(
                    Facts.validate.selector,
                    Tuple.four(identity, encoded, abi.encode(query), abi.encode(provenance))
                )
            );
        Tuple.result(ok, result);
        (uint8 state, uint64 generation) =
            Attribution(source.owners[4]).attributionState(query.collectionId);
        if (state != 2 || generation != generations.current.generation) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
    }

    /// @dev Called after both full collectors and before any owner payload/import. Existing
    /// single-tuple framing preserves all original Identity signatures and nonce provenance.
    function attestations(
        bytes memory identity,
        bytes memory rawAttestations,
        AH.Query memory query,
        RH.Provenance memory provenance
    ) public view {
        Attestations.Bundle memory b = abi.decode(rawAttestations, (Attestations.Bundle));
        Attestations.validate(b, query, RH.ownerProvenance(provenance, 4));
        // collect already authenticated every original generation and matched its current
        // generation to this same Attribution source. Revalidate the complete collected
        // attestation bundle here; no caller supplies a generation or partial row projection.
        uint64 generation = b.item.generation;
        if (generation < 2 || generation > 128) revert RH.InvalidRecoveredHydrationProfile();
        if (address(AttestationFacts).code.length == 0) assembly ("memory-safe") { revert(0, 0) }
        (bool ok, bytes memory result) = address(AttestationFacts)
            .staticcall(
                bytes.concat(
                    AttestationFacts.validateGeneration.selector,
                    // uint8 and uint64 have the same canonical ABI word for this checked 2..128 range.
                    Tuple.fourAndMode(
                        identity,
                        abi.encode(b.records),
                        abi.encode(query),
                        abi.encode(provenance),
                        uint8(generation)
                    )
                )
            );
        abi.decode(Tuple.result(ok, result), (uint256[]));
    }

    /// @notice Additive complete grant/mode composition; the old no-grant route is untouched.
    function contentWithAuthority(
        address source,
        AH.Query memory query,
        RH.OwnerProvenance memory provenance,
        T.EconomicsConsent[] memory economics,
        T.RoyaltyFreeze[] memory royalties,
        bytes memory rawGenerations,
        bool hasIdentityDelegations
    ) public view returns (bytes memory) {
        Generations.Bundle memory b = abi.decode(rawGenerations, (Generations.Bundle));
        if (!hasIdentityDelegations && b.current.consentMode == 1) {
            return content(source, query, provenance, economics, royalties, rawGenerations);
        }
        if (
            b.bindingHash != query.bindingHash || b.current.bindingHash != query.bindingHash
                || b.current.generation != b.rows.length || !b.current.accepted
                || (b.current.consentMode != 1 && b.current.consentMode != 2)
        ) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        return Delegated.collect(
            source,
            query,
            provenance,
            economics,
            royalties,
            b.current.generation,
            b.current.consentMode
        );
    }

    function content(
        address source,
        AH.Query memory query,
        RH.OwnerProvenance memory provenance,
        T.EconomicsConsent[] memory economics,
        T.RoyaltyFreeze[] memory royalties,
        bytes memory rawGenerations
    ) public view returns (bytes memory) {
        Generations.Bundle memory b = abi.decode(rawGenerations, (Generations.Bundle));
        // Complete generation validation has already occurred before this fixed collector.
        // The resulting current generation is embedded in the separately validated content rows.
        if (
            b.bindingHash != query.bindingHash || b.current.bindingHash != query.bindingHash
                || b.current.generation != b.rows.length || !b.current.accepted
                || b.current.consentMode != 1
        ) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        bool hasContent;
        for (uint256 i; i < provenance.journal.length; ++i) {
            uint16 op = provenance.journal[i].receipt.operation;
            if (op == 17 || op == 20 || op == 21) hasContent = true;
        }
        if (!hasContent) {
            if (royalties.length != 0) revert RH.InvalidRecoveredHydrationProfile();
            return abi.encode(
                GenerationBase.collect(source, query, provenance, economics, b.current.generation)
            );
        }
        return abi.encode(
            GenerationConsents.collect(
                source, query, provenance, economics, royalties, b.current.generation
            )
        );
    }

    /// @notice Bind the new consent tag to the same fully authenticated generation bundle.
    function contentFactsWithAuthority(
        bytes memory identity,
        bytes memory consent,
        AH.Query memory query,
        RH.Provenance memory provenance,
        bytes memory records,
        bytes memory rawGenerations
    ) public view {
        if (!Delegated.tagged(consent)) {
            contentFacts(identity, consent, query, provenance, records);
            return;
        }
        uint8 mode = Delegated.requireBinding(
            query, RH.ownerProvenance(provenance, 6), consent, rawGenerations
        );
        if (address(DelegatedFacts).code.length == 0) assembly ("memory-safe") { revert(0, 0) }
        (bool ok, bytes memory result) = address(DelegatedFacts)
            .staticcall(
                bytes.concat(
                    DelegatedFacts.validate.selector,
                    Tuple.fourModeAndRows(
                        identity,
                        abi.encode(consent),
                        abi.encode(query),
                        abi.encode(provenance),
                        mode,
                        records
                    )
                )
            );
        Tuple.result(ok, result);
    }

    function contentFacts(
        bytes memory identity,
        bytes memory consent,
        AH.Query memory query,
        RH.Provenance memory provenance,
        bytes memory records
    ) public view {
        ContentH.Bundle memory b = abi.decode(consent, (ContentH.Bundle));
        bool baseOnly = b.consents.length == 0 && b.royalties.length == 0 && b.freezes.length == 0;
        uint64 generation =
            baseOnly ? GenerationBase.generation(b) : GenerationConsents.generation(b);
        if (generation < 2 || generation > 128) revert RH.InvalidRecoveredHydrationProfile();
        address validator = baseOnly ? address(BaseFacts) : address(ConsentFacts);
        bytes4 selector = baseOnly ? BaseFacts.validate.selector : ConsentFacts.validate.selector;
        if (validator.code.length == 0) assembly ("memory-safe") { revert(0, 0) }
        (bool ok, bytes memory result) = validator.staticcall(
            bytes.concat(
                selector,
                Tuple.fourModeAndRows(
                    identity,
                    consent,
                    abi.encode(query),
                    abi.encode(provenance),
                    uint8(generation),
                    records
                )
            )
        );
        Tuple.result(ok, result);
    }

    /// @dev Called only at owner0's semantic step after its original capability and guard checks.
    function encode(
        bytes memory encoded,
        AH.Query memory query,
        RH.OwnerProvenance memory provenance
    ) public pure returns (bytes memory) {
        return Modes.encode(abi.decode(encoded, (Generations.Bundle)), query, provenance);
    }
}
