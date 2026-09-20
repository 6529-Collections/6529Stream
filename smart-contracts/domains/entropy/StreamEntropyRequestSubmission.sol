// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/entropy/IStreamInstantEntropyProviderIdentity.sol";

import "./StreamEntropyCoordinator.sol";
import "./StreamEntropyRequestPlan.sol";
import "./StreamEntropyInstantProviderReads.sol";
import "./StreamEntropyCoordinatorReads.sol";
import "./StreamEntropyContinuity.sol";

/// @notice Fixed submission worker with explicit original storage references; custody stays in the host.
library StreamEntropyRequestSubmission {
    event EntropyRequested(
        bytes32 indexed requestKey,
        uint256 indexed tokenId,
        bytes32 indexed scopeId,
        address provider,
        uint256 providerRequestId
    );
    event InstantEntropyProduced(
        uint16 schemaVersion,
        bytes32 indexed requestKey,
        uint256 indexed providerRequestId,
        bytes32 rawRandomness,
        bytes32 provenanceHash,
        IStreamInstantEntropyProviderIdentity.InstantMode mode,
        bytes32 assumptionsHash
    );

    struct Input {
        bytes32 subjectKey;
        uint256 tokenId;
        bytes32 scopeId;
        StreamEntropyRequestPlan.Plan plan;
    }

    function submit(
        IStreamCore core,
        StreamEntropyCoordinator.Subject storage subject,
        mapping(bytes32 => StreamEntropyCoordinator.Request) storage requests,
        mapping(bytes32 => IStreamEntropyEpochs.RequestPolicySnapshot) storage policies,
        mapping(address => mapping(uint256 => bytes32)) storage providerKeys,
        Input memory input
    ) public returns (uint256 providerRequestId) {
        StreamEntropyRequestPlan.Plan memory p = input.plan;
        address provider = p.policy.provider;
        subject.requestKey = p.key;
        subject.status = StreamEntropyStatus.REQUESTED;
        requests[p.key] = StreamEntropyCoordinator.Request(
            input.subjectKey, input.tokenId, input.scopeId, provider, uint64(block.number), 0, 0
        );
        policies[p.key] = p.policy;
        StreamEntropyContinuity.admit(subject.collectionId, p.key);
        if (p.instant) {
            providerRequestId = uint256(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_INSTANT_PROVIDER_REQUEST_V1"),
                        p.key,
                        p.policy.requestAttempt,
                        provider,
                        p.policy.providerEpoch,
                        p.policy.providerConfigHash
                    )
                )
            );
            _bind(requests[p.key], providerKeys, p.key, provider, providerRequestId);
            // Both directions and the complete request exist before any provider read below.
            (IStreamInstantEntropyProviderIdentity.InstantMode mode, bytes32 assumptions) =
                StreamEntropyInstantProviderReads.profile(provider);
            (bytes32 raw, bytes32 provenance) =
                StreamEntropyInstantProviderReads.entropy(provider, p.key, p.context);
            emit EntropyRequested(p.key, input.tokenId, input.scopeId, provider, providerRequestId);
            requests[p.key].rawRandomness = raw;
            subject.seed = StreamEntropyCoordinatorReads.deriveSeed(
                core, p.key, requests[p.key], subject, policies[p.key], raw
            );
            subject.status = StreamEntropyStatus.FINALIZED;
            StreamEntropyContinuity.close(p.key);
            emit InstantEntropyProduced(
                1, p.key, providerRequestId, raw, provenance, mode, assumptions
            );
        } else {
            providerRequestId =
                IStreamEntropyProvider(provider).requestEntropy{ value: p.fee }(p.key, p.context);
            _bind(requests[p.key], providerKeys, p.key, provider, providerRequestId);
            emit EntropyRequested(p.key, input.tokenId, input.scopeId, provider, providerRequestId);
        }
    }

    function _bind(
        StreamEntropyCoordinator.Request storage request,
        mapping(address => mapping(uint256 => bytes32)) storage providerKeys,
        bytes32 key,
        address provider,
        uint256 id
    ) private {
        if (providerKeys[provider][id] != 0) {
            revert StreamEntropyCoordinator.ProviderRequestCollision(provider, id);
        }
        providerKeys[provider][id] = key;
        request.providerRequestId = id;
    }
}
