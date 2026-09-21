// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as V
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import {
    StreamArtistOnboardingTypes as A
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecordPublicationTypes as P
} from "../../interfaces/stream/artist/StreamArtistRecordPublicationTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import "../../interfaces/stream/artist/IStreamArtistRecordPublicationOwner.sol";
import "../records/StreamRecordArtistIdentityReads.sol";
import "../artist/StreamArtistHashes.sol";
import "../artist/StreamArtistContentHashes.sol";
import "../../interfaces/stream/artist/IStreamArtistContentOwner.sol";
import "../../interfaces/stream/artist/StreamArtistContentTypes.sol";
import "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedPreservationPolicyContentRootPublicationV1 as PreservationRoot
} from "../../interfaces/stream/metadata/IStreamScopedPreservationPolicyContentRootPublicationV1.sol";
import {
    StreamScopedPreservationPolicyContentRootSchemasV1 as RootSchemas
} from "../finality/StreamScopedPreservationPolicyContentRootSchemasV1.sol";

import {
    StreamScopedPreservationPolicyRenderCriticalTypesV1 as Scoped
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalStateV1 as State
} from "./StreamScopedPreservationPolicyRenderCriticalStateV1.sol";

import {
    StreamScopedPreservationPolicyRenderCriticalRootAuthorizationReadV1 as RootRead
} from "./StreamScopedPreservationPolicyRenderCriticalRootAuthorizationReadV1.sol";

/// @notice Original op17 Archive proof for a current scoped root; no re-signing or live nonce use.
/// @dev Historical aggregate/legacy hashes are untrusted preimage witnesses. Exact original
/// record and signed family hashes authenticate them; present aggregate is never substituted.
library StreamScopedPreservationPolicyRenderCriticalRootAuthorizationV1 {
    // Preserve errors previously inferred from the complete inlined read body.
    error InvalidInventoryItem();
    error InventoryRead(address target);

    struct Envelope {
        uint16 version;
        bytes32 configurationHash;
        uint16 operationId;
        address actor;
        bytes32 record;
        A.Snapshot[7] before_;
        A.Snapshot[7] after_;
        bytes payload;
    }

    struct Loaded {
        A.SuiteConfiguration suite;
        address coordinator;
        bytes32 id;
        bytes evidence;
    }

    struct ContentPayload {
        A.Binding binding;
        StreamArtistContentTypes.Consent terms;
        A.Authorization authorization;
        A.SignerApproval approval;
        bytes32 priorState;
    }

    function appendRootAuthorization(
        State.State storage state,
        bytes32 id,
        address actor,
        uint64 originalObservedAt,
        IStreamScopedContentRootPublication.Aggregate memory originalAggregate,
        bytes32 originalLegacyFamilyHash
    ) public {
        State.stage(state, id, 6);
        V.Item[] memory rows = new V.Item[](1);
        rows[0] = contentItem(
            state.dependencies,
            state.contexts[id],
            actor,
            originalObservedAt,
            originalAggregate,
            originalLegacyFamilyHash
        );
        State.append(state, id, rows, state.contexts[id].rootRecordHash);
        state.plans[id].progress.completedStages = 7;
    }

    function contentItem(
        S.Dependencies memory d,
        Scoped.Context memory c,
        address actor,
        uint64 originalObservedAt,
        IStreamScopedContentRootPublication.Aggregate memory originalAggregate,
        bytes32 originalLegacyFamilyHash
    ) public view returns (V.Item memory result) {
        return RootRead.contentItem(
            d, c, actor, originalObservedAt, originalAggregate, originalLegacyFamilyHash
        );
    }
}
