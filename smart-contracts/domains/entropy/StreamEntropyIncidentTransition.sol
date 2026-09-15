// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamEntropyCoordinator as C } from "./StreamEntropyCoordinator.sol";
import { StreamEntropyIncidentEvidence } from "./StreamEntropyIncidentEvidence.sol";
import { IStreamEntropyEpochs } from "../../interfaces/stream/entropy/IStreamEntropyEpochs.sol";
import {
    IStreamEntropyIncidents
} from "../../interfaces/stream/entropy/IStreamEntropyIncidents.sol";
import { StreamEntropyStatus } from "../../interfaces/stream/entropy/IStreamEntropyView.sol";

/// @notice Fixed incident validation/event worker; original coordinator retains authority and terminal mutation.
library StreamEntropyIncidentTransition {
    event EntropyRequestFailed(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint256 indexed tokenId,
        address indexed provider,
        bytes32 requestKey,
        uint32 providerEpoch,
        uint16 requestAttempt,
        string reasonURI,
        bytes32 evidenceHash
    );
    event EntropyScopeRequestFailed(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed scopeId,
        address indexed provider,
        bytes32 requestKey,
        uint32 providerEpoch,
        uint16 requestAttempt,
        string reasonURI,
        bytes32 evidenceHash
    );

    function record(
        C.Subject storage subject,
        C.Request storage request,
        IStreamEntropyEpochs.RequestPolicySnapshot storage policy,
        bytes32 subjectKey,
        uint256 tokenId,
        bytes32 scopeId,
        bool revoked,
        C.CollectionConfig storage config,
        uint256 liveTimeout,
        uint256 probeGas,
        string memory reasonURI,
        bytes32 evidenceHash
    ) public {
        bytes32 key = subject.requestKey;
        if (subject.status != StreamEntropyStatus.REQUESTED) {
            revert C.InvalidStatus(subject.status);
        }
        if (
            key == 0 || subject.seed != 0 || request.subjectKey != subjectKey
                || request.tokenId != tokenId || request.scopeId != scopeId
                || request.provider != policy.provider || policy.inputsHash != subject.inputsHash
                || request.rawRandomness != 0
        ) revert IStreamEntropyIncidents.IncidentRequestMismatch();
        if (!revoked) {
            if (block.number <= request.requestedAtBlock) revert C.RequestNotExpired();
            if (config.provider == address(0)) revert C.InvalidCollection(subject.collectionId);
            uint256 timeout =
                liveTimeout > config.timeoutBlocks ? liveTimeout : config.timeoutBlocks;
            if (block.number - request.requestedAtBlock <= timeout) revert C.RequestNotExpired();
        }
        StreamEntropyIncidentEvidence.record(
            key,
            request.provider,
            policy.providerCodeHash,
            request.providerRequestId,
            probeGas,
            reasonURI,
            evidenceHash
        );
    }

    function emitFailure(
        C.Subject storage subject,
        C.Request storage request,
        IStreamEntropyEpochs.RequestPolicySnapshot storage policy,
        uint256 tokenId,
        bytes32 scopeId,
        string memory reasonURI,
        bytes32 evidenceHash
    ) public {
        bytes32 key = subject.requestKey;

        if (tokenId != 0) {
            emit EntropyRequestFailed(
                1,
                subject.collectionId,
                tokenId,
                request.provider,
                key,
                policy.providerEpoch,
                policy.requestAttempt,
                reasonURI,
                evidenceHash
            );
        } else {
            emit EntropyScopeRequestFailed(
                1,
                subject.collectionId,
                scopeId,
                request.provider,
                key,
                policy.providerEpoch,
                policy.requestAttempt,
                reasonURI,
                evidenceHash
            );
        }
    }
}
