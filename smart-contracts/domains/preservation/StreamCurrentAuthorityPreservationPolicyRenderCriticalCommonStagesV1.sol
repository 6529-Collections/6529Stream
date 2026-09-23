// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import { StreamMultiOriginInventoryState as Origins } from "./StreamMultiOriginInventoryState.sol";
import {
    StreamRenderCriticalDescriptionStages as PreviousDescription
} from "./StreamRenderCriticalDescriptionStages.sol";
import {
    StreamRenderCriticalInterviewStage as PreviousInterview
} from "./StreamRenderCriticalInterviewStage.sol";

import {
    StreamPreservationPolicyRenderCriticalStateV1 as State
} from "./StreamPreservationPolicyRenderCriticalStateV1.sol";
import {
    StreamPreservationTypedReferences as References
} from "./StreamPreservationTypedReferences.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamMultiOriginDescriptionStages as Description
} from "./StreamMultiOriginDescriptionStages.sol";
import { StreamMultiOriginRecordStages as Records } from "./StreamMultiOriginRecordStages.sol";
import {
    StreamMultiOriginInterviewStage as Interview
} from "./StreamMultiOriginInterviewStage.sol";
import { StreamWorkRecordTypes } from "../../interfaces/stream/metadata/StreamWorkRecordTypes.sol";
import {
    StreamConservationRecordTypes
} from "../../interfaces/stream/metadata/StreamConservationRecordTypes.sol";

/// @notice Original common-record validation with retained catalog facts for preservation currentness.
/// @dev No original snapshot/reference read is invoked by these common stages.
library StreamCurrentAuthorityPreservationPolicyRenderCriticalCommonStagesV1 {
    function appendWork(State.State storage s, Origins.State storage origins, bytes calldata input)
        public
    {
        Description.appendWork(s.records, origins, input);
        (bytes32 id, StreamWorkRecordTypes.Description memory value,,) = abi.decode(
            input[4:], (bytes32, StreamWorkRecordTypes.Description, address, O.ReceiptWitness)
        );
        S.Context storage c = s.records.contexts[id];
        State.pinDocuments(
            s,
            id,
            References.work(
                s.records.dependencies.targets[1],
                c.descriptions.workDescriptionRecordHash,
                c.descriptions.workPayloadHash,
                value
            )
        );
    }

    function appendRights(State.State storage s, bytes calldata input) public {
        PreviousDescription.appendRights(s.records, input);
    }

    function appendIntent(
        State.State storage s,
        Origins.State storage origins,
        bytes calldata input
    ) public {
        Records.appendIntent(s.records, origins, input);
        (bytes32 id, StreamConservationRecordTypes.Intent memory value,,) = abi.decode(
            input[4:], (bytes32, StreamConservationRecordTypes.Intent, address, O.ReceiptWitness)
        );
        S.Context storage c = s.records.contexts[id];
        State.pinDocuments(
            s,
            id,
            References.intent(
                s.records.dependencies.targets[1],
                c.conservation.record.recordHash,
                c.conservation.record.payloadHash,
                value
            )
        );
    }

    function appendIntentWaiver(
        State.State storage s,
        Origins.State storage origins,
        bytes calldata input
    ) public {
        Records.appendIntentWaiver(s.records, origins, input);
    }

    function appendInterview(
        State.State storage s,
        Origins.State storage origins,
        bytes calldata input
    ) public {
        Interview.appendInterview(s.records, origins, input);
        (bytes32 id, StreamConservationRecordTypes.Interview memory value,,) = abi.decode(
            input[4:], (bytes32, StreamConservationRecordTypes.Interview, address, O.ReceiptWitness)
        );
        S.Context storage c = s.records.contexts[id];
        State.pinDocuments(
            s,
            id,
            References.interview(
                s.records.dependencies.targets[1],
                c.conservation.interview.recordHash,
                c.conservation.interview.payloadHash,
                value
            )
        );
    }

    function appendInterviewWaiver(State.State storage s, bytes32 id) public {
        PreviousInterview.appendInterviewWaiver(s.records, id);
    }
}
