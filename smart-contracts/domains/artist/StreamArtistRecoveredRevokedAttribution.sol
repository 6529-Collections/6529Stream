// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveredPlatformImport as PlatformHistory } from "./StreamArtistRecoveredPlatformImport.sol";
import {
    StreamArtistRecoveredSanctionAttributionImport as SanctionHistory
} from "./StreamArtistRecoveredSanctionAttributionImport.sol";
import { StreamArtistRecoveredDisputeHistoryImport as DisputeHistory } from "./StreamArtistRecoveredDisputeHistoryImport.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredRevokedAttributionValidation as V
} from "./StreamArtistRecoveredRevokedAttributionValidation.sol";
import {
    StreamArtistRecoveredAcceptedBindingValidation as BindingValidation
} from "./StreamArtistRecoveredAcceptedBindingValidation.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    IStreamArtistAttributionDisputesOwner as Disputes,
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    IStreamArtistAttributionOwner as Attribution
} from "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    IStreamArtistPlatformOwner as Platform
} from "../../interfaces/stream/artist/IStreamArtistPlatformWorks.sol";
import {
    StreamArtistPlatformTypes as PW
} from "../../interfaces/stream/artist/StreamArtistPlatformTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistBindingLifecycleTypes as L
} from "../../interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import { StreamArtistAttributionStateTypes as AS } from "./StreamArtistAttributionStateTypes.sol";
import { StreamArtistDisputeState as State } from "./StreamArtistDisputeState.sol";
import {
    StreamArtistRecoveredHydrationProvenance as P
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";

/// @notice Original governed dispute maps imported only under the original Attribution op60 guard.
library StreamArtistRecoveredRevokedAttribution {
    function collect(
        address source,
        AH.Query memory q,
        RH.Provenance memory p,
        CB.Bundle memory bindings
    ) public view returns (A.AttributionBundle memory b) {
        RH.OwnerProvenance memory local = RH.ownerProvenance(p, 4);
        P.validateOwnerSource(local, 4, source);
        b.provenance = RH.ownerProvenanceHash(local, 4);
        b.artistId = q.artistId;
        b.collectionId = q.collectionId;
        b.bindingHash = q.bindingHash;
        (b.current.state, b.current.generation) =
            Attribution(source).attributionState(q.collectionId);
        b.generations = BindingValidation.validate(bindings, q, RH.ownerProvenance(p, 0));
        PW.State memory emptyPlatform;
        if (
            keccak256(abi.encode(Platform(source).platformWorksState(q.collectionId)))
                != keccak256(abi.encode(emptyPlatform))
        ) _invalid();
        uint256 n;
        for (uint256 i; i + 1 < b.generations.length; ++i) {
            if (b.generations[i].accepted) ++n;
        }
        b.revocations = new A.Revocation[](n);
        n = 0;
        for (uint256 i; i < b.generations.length; ++i) {
            AD.Head memory head = Disputes(source).attributionDispute(q.collectionId, uint64(i + 1));
            if (i + 1 == b.generations.length || !b.generations[i].accepted) {
                AD.Head memory empty;
                if (keccak256(abi.encode(head)) != keccak256(abi.encode(empty))) _invalid();
                continue;
            }
            AD.Record memory opening =
                Disputes(source).attributionDisputeRecord(head.disputeRecordHash);
            AD.Resolution memory resolution =
                Disputes(source).attributionDisputeResolution(head.resolutionActionId);
            b.revocations[n++] = A.Revocation(head, opening, resolution);
            if (
                keccak256(bindings.corrections[i + 1].approval.causeData)
                    != keccak256(
                        abi.encode(bindings.bindings.rows[i].terminal, head, opening, resolution)
                    )
            ) _invalid();
        }
        V.validate(b, q, local);
    }

    function encode(A.AttributionBundle memory b, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        pure
        returns (bytes memory)
    {
        V.validate(b, q, p);
        return abi.encode(A.ATTRIBUTION, RH.VERSION, b);
    }

    function decode(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        public
        pure
        returns (A.AttributionBundle memory b)
    {
        bytes32 tag;
        uint16 version;
        (tag, version, b) = abi.decode(raw, (bytes32, uint16, A.AttributionBundle));
        if (
            tag != A.ATTRIBUTION || version != RH.VERSION
                || keccak256(raw) != keccak256(abi.encode(tag, version, b))
        ) _invalid();
        V.validate(b, q, p);
    }

    function importIfSelected(AS.State storage s, AH.Query memory q, bytes memory outer)
        public
        returns (bool)
    {
        (RH.ExportHeader memory h, Payload.Payload memory p) = Payload.decode(outer, 4);
        if ((h.requiredFeatures & RH.HISTORY_PLATFORM) != 0)
            return PlatformHistory.importIfSelected(s, q, outer);
        if ((h.requiredFeatures & RH.SANCTION_HISTORY) != 0) {
            return SanctionHistory.importIfSelected(s, q, outer);
        }
        if ((h.requiredFeatures & RH.DISPUTE_HISTORY) != 0) return DisputeHistory.importIfSelected(s, q, outer);
        if ((h.requiredFeatures & RH.ACCEPTED_GENERATIONS) == 0) return false;
        if (p.nonces.length != 0) _invalid();
        A.AttributionBundle memory b = decode(q, p.provenance, p.semanticState);
        if (
            s.attributions[q.collectionId].state != 0
                || s.attributions[q.collectionId].generation != 0
        ) {
            _invalid();
        }
        State.Store storage d = State.store();
        AD.Head memory emptyHead;
        AD.Record memory emptyRecord;
        AD.Resolution memory emptyResolution;
        for (uint256 i; i < b.generations.length; ++i) {
            if (
                keccak256(abi.encode(d.heads[State.key(q.collectionId, uint64(i + 1))]))
                    != keccak256(abi.encode(emptyHead))
            ) _invalid();
        }
        for (uint256 i; i < b.revocations.length; ++i) {
            A.Revocation memory r = b.revocations[i];
            bytes32 evidence = keccak256(
                abi.encode(
                    q.collectionId, r.opening.terms.bindingGeneration, r.opening.terms.evidenceHash
                )
            );
            if (
                keccak256(abi.encode(d.records[r.opening.recordHash]))
                        != keccak256(abi.encode(emptyRecord))
                    || keccak256(abi.encode(d.resolutions[r.resolution.actionId]))
                        != keccak256(abi.encode(emptyResolution)) || d.evidenceSeen[evidence]
            ) _invalid();
        }
        s.attributions[q.collectionId] = b.current;
        for (uint256 i; i < b.revocations.length; ++i) {
            A.Revocation memory r = b.revocations[i];
            d.heads[State.key(q.collectionId, r.opening.terms.bindingGeneration)] = r.head;
            d.records[r.opening.recordHash] = r.opening;
            d.resolutions[r.resolution.actionId] = r.resolution;
            d.evidenceSeen[
                keccak256(
                    abi.encode(
                        q.collectionId,
                        r.opening.terms.bindingGeneration,
                        r.opening.terms.evidenceHash
                    )
                )
            ] = true;
        }
        return true;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
