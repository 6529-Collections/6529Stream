// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistCompleteHistoryTypes as CT } from "./StreamArtistCompleteHistoryTypes.sol";
import {
    StreamArtistCompleteHistorySource as Source
} from "./StreamArtistCompleteHistorySource.sol";
import {
    StreamArtistCompleteHistoryIdentitySource as Identity
} from "./StreamArtistCompleteHistoryIdentitySource.sol";
import {
    StreamArtistCompleteHistoryWitnesses as Witnesses
} from "./StreamArtistCompleteHistoryWitnesses.sol";
import {
    StreamArtistCompleteHistoryConsentSource as Consents
} from "./StreamArtistCompleteHistoryConsentSource.sol";
import {
    StreamArtistCompleteHistoryConsentValidation as ConsentValidation
} from "./StreamArtistCompleteHistoryConsentValidation.sol";
import {
    StreamArtistCompleteHistoryAttestationSource as Attestations
} from "./StreamArtistCompleteHistoryAttestationSource.sol";
import {
    StreamArtistCompleteHistoryDisputeSource as Disputes
} from "./StreamArtistCompleteHistoryDisputeSource.sol";
import {
    StreamArtistCompleteHistoryDisputeArchive as DisputeArchive
} from "./StreamArtistCompleteHistoryDisputeArchive.sol";
import {
    StreamArtistCompleteHistoryAccounting as Accounting
} from "./StreamArtistCompleteHistoryAccounting.sol";
import {
    StreamArtistCompleteHistorySanctionSource as Sanctions
} from "./StreamArtistCompleteHistorySanctionSource.sol";
import {
    StreamArtistCompleteHistorySanctionCurrent as Current
} from "./StreamArtistCompleteHistorySanctionCurrent.sol";
import {
    StreamArtistCompleteHistoryConservation as Conservation
} from "./StreamArtistCompleteHistoryConservation.sol";
import {
    StreamArtistRecoveredAggregateSanctionIdentityFacts as SanctionIdentity
} from "./StreamArtistRecoveredAggregateSanctionIdentityFacts.sol";
import {
    StreamArtistRecoveredAggregateRatificationRows as Supplements
} from "./StreamArtistRecoveredAggregateRatificationRows.sol";
import {
    StreamArtistAggregateConsentSupplementTypes as Supplement
} from "./StreamArtistAggregateConsentSupplementTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as Clocks
} from "./StreamArtistPrimaryCollaboratorClocks.sol";
import {
    StreamArtistRecoveredHydrationAdmission as Admission
} from "./StreamArtistRecoveredHydrationAdmission.sol";
import {
    StreamArtistRecoveredHydrationGuards as Guards
} from "./StreamArtistRecoveredHydrationGuards.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleDisputeTypes as MD
} from "./StreamArtistRecoveredMultipleDisputeTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredAttestationHydration as Records
} from "./StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Complete family composition after original admission and fixed principal collection.
/// @dev Every family sees the same original provenance. This worker never selects a reduced
/// source graph, fabricates an empty optional family, or treats the latest Artist as historical.
library StreamArtistCompleteHistoryComposition {
    struct Context {
        Admission.Certificate admission;
        CT.Principals principals;
        Witnesses.Plan witnesses;
        uint256 features;
    }

    struct Result {
        CT.Inventory inventory;
        bytes[] bindings;
        bytes[] accepted;
        bytes[] consents;
        bytes[] attribution;
        uint256 features;
    }

    struct Work {
        M.State scope;
        Clocks.Result clocks;
        D.Bundle[] histories;
        bytes[] attestations;
        G.Consents[] consents;
        T.RatificationRecord[][] ratifications;
        H.Inventory sanctions;
        bytes sanctionInventory;
    }

    function collect(Context memory x) public view returns (Result memory result) {
        Work memory w;
        w.scope.artists = x.admission.artists;
        w.scope.collections = x.admission.collections;
        if (x.principals.identities.length != w.scope.artists.length) _invalid();
        (result.inventory, w.clocks) = Source.collect(w.scope, x.admission.provenance);
        if (w.scope.artists.length != 0) {
            Identity.validateCollected(
                w.scope,
                result.inventory,
                w.clocks,
                x.principals.identities,
                Guards.collectNonces(
                    x.admission.source.owners[2],
                    x.admission.provenance
                        .eras[x.admission.provenance.eras.length - 1].checkpoints[2]
                )
            );
        }
        w.histories = Disputes.collect(
            x.admission.source.owners[4],
            w.scope,
            x.admission.provenance,
            result.inventory.bindings,
            result.inventory.archive,
            w.clocks
        );
        DisputeArchive.validate(
            w.histories, RH.ownerProvenance(x.admission.provenance, 4), result.inventory, w.clocks
        );
        Accounting.validate(result.inventory, w.clocks, w.histories);
        w.sanctions = Sanctions.collect(w.scope, result.inventory);
        Current.validate(
            w.sanctions,
            w.histories,
            result.inventory.bindings,
            w.clocks,
            RH.ownerProvenance(x.admission.provenance, 4)
        );
        if (w.sanctions.sanctions.length != 0) {
            SanctionIdentity.validate(
                x.principals.identities, w.scope, w.sanctions, x.admission.provenance
            );
            w.sanctionInventory = abi.encode(w.sanctions);
        }
        result.consents = Consents.collect(
            Consents.Context(
                x.admission.source.owners[6],
                w.scope,
                result.inventory,
                x.witnesses.economics,
                x.witnesses.freezes
            )
        );
        _consents(w, result);
        ConsentValidation.validate(
            w.consents, w.ratifications, w.scope, result.inventory, w.sanctionInventory
        );
        w.attestations = Attestations.collect(
            x.admission.source.owners[4],
            w.scope,
            result.inventory,
            w.clocks,
            x.witnesses.attestations
        );
        Conservation.validate(
            Conservation.Context(
                x.principals.identities,
                w.scope,
                w.consents,
                w.attestations,
                result.inventory,
                w.histories
            )
        );
        _encode(x.features, w, result);
    }

    function _consents(Work memory w, Result memory result) private pure {
        uint256 n = w.scope.collections.length;
        if (result.consents.length != n) _invalid();
        w.consents = new G.Consents[](n);
        w.ratifications = new T.RatificationRecord[][](n);
        for (uint256 k; k < n; ++k) {
            Supplement.Bundle memory row = Supplements.decodeSupplement(result.consents[k]);
            w.consents[k] = row.original;
            w.ratifications[k] = row.ratifications;
            bytes memory expected = k == 0 ? w.sanctionInventory : new bytes(0);
            if (keccak256(row.sanctionInventory) != keccak256(expected)) _invalid();
        }
    }

    function _encode(uint256 features, Work memory w, Result memory result) private pure {
        uint256 n = w.scope.collections.length;
        result.bindings = new bytes[](n);
        result.accepted = new bytes[](n);
        result.attribution = new bytes[](n);
        result.features = features | CT.FEATURE;
        if (w.sanctions.sanctions.length != 0) result.features |= RH.SANCTION_HISTORY;
        for (uint256 k; k < n; ++k) {
            result.bindings[k] = abi.encode(result.inventory.bindings.bindings[k]);
            result.accepted[k] = abi.encode(result.inventory.accepted[k]);
            Records.Bundle memory records = abi.decode(w.attestations[k], (Records.Bundle));
            result.attribution[k] = abi.encode(MD.Attribution(w.histories[k], records));
            if (w.ratifications[k].length != 0) result.features |= RH.RATIFICATIONS;
            if (records.records.length != 0) {
                result.features |= RH.ATTESTATIONS | RH.HISTORY_RECORDS;
            }
            if (
                w.histories[k].disputes.length + w.histories[k].repudiations.length
                        + w.histories[k].resolutions.length != 0
            ) {
                result.features |= RH.DISPUTE_HISTORY;
            }
            if (w.consents[k].rows.original.economics.length != 0) {
                result.features |= RH.DIRECT_ECONOMICS;
            }
            if (w.consents[k].rows.original.sales.length != 0) {
                result.features |= RH.DELEGATED_CONSENT;
            }
            if (
                w.consents[k].rows.consents.length + w.consents[k].rows.royalties.length
                        + w.consents[k].rows.freezes.length != 0
            ) {
                result.features |= RH.CONTENT_CONSENTS | RH.HISTORY_CONTENT;
            }
            if (result.inventory.bindings.generations[k].length != 0) {
                result.features |= RH.BINDING_GENERATIONS;
            }
            for (uint256 g; g < result.inventory.bindings.generations[k].length; ++g) {
                if (result.inventory.bindings.generations[k][g].accepted) {
                    result.features |= RH.ACCEPTED_GENERATIONS;
                }
                if (result.inventory.bindings.bindings[k].corrections[g].recordHash != 0) {
                    result.features |= RH.BINDING_CORRECTIONS;
                }
                if (w.consents[k].bindings[g].consentMode == 2) {
                    result.features |= RH.DELEGATED_CONSENT;
                }
            }
        }
        for (uint256 i; i < result.inventory.archive.operations.length; ++i) {
            uint16 op = result.inventory.archive.operations[i].operation;
            if ((op >= 8 && op <= 11) || op == 53) result.features |= RH.HISTORY_PLATFORM;
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
