// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
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
    StreamRenderCriticalDescriptionStages as Description
} from "./StreamRenderCriticalDescriptionStages.sol";
import {
    StreamRenderCriticalRecordStages as Records
} from "./StreamRenderCriticalRecordStages.sol";
import {
    StreamRenderCriticalInterviewStage as Interview
} from "./StreamRenderCriticalInterviewStage.sol";
import { StreamWorkRecordTypes } from "../../interfaces/stream/metadata/StreamWorkRecordTypes.sol";
import {
    StreamConservationRecordTypes
} from "../../interfaces/stream/metadata/StreamConservationRecordTypes.sol";

/// @notice Original common-record validation with retained catalog facts for V2 currentness.
/// @dev No original snapshot/reference read is invoked by these common stages.
library StreamPreservationPolicyRenderCriticalCommonStagesV1 {
    function appendWork(State.State storage s, bytes calldata input) public {
        Description.appendWork(s.records, input);
        (bytes32 id, StreamWorkRecordTypes.Description memory value,) =
            abi.decode(input[4:], (bytes32, StreamWorkRecordTypes.Description, address));
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
        Description.appendRights(s.records, input);
    }

    function appendIntent(State.State storage s, bytes calldata input) public {
        Records.appendIntent(s.records, input);
        (bytes32 id, StreamConservationRecordTypes.Intent memory value,) =
            abi.decode(input[4:], (bytes32, StreamConservationRecordTypes.Intent, address));
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

    function appendIntentWaiver(State.State storage s, bytes calldata input) public {
        Records.appendIntentWaiver(s.records, input);
    }

    function appendInterview(State.State storage s, bytes calldata input) public {
        Interview.appendInterview(s.records, input);
        (bytes32 id, StreamConservationRecordTypes.Interview memory value,) =
            abi.decode(input[4:], (bytes32, StreamConservationRecordTypes.Interview, address));
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
        Interview.appendInterviewWaiver(s.records, id);
    }
}
