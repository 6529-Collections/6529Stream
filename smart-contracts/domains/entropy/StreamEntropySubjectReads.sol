// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamEntropyCoordinator.sol";
import { StreamEntropyStatus } from "../../interfaces/stream/entropy/IStreamEntropyView.sol";
import "../../interfaces/stream/entropy/IStreamEntropyEpochs.sol";
import "../../interfaces/stream/entropy/IStreamRevealFeeEscrow.sol";

/// @notice Fixed terminal codecs for original stored subject/policy reads. No mutation route.
library StreamEntropySubjectReads {
    function read(
        mapping(uint256 => StreamEntropyCoordinator.CollectionConfig) storage configs,
        mapping(
            uint256 => uint32
        ) storage epochs,
        mapping(bytes32 => StreamEntropyCoordinator.Subject) storage subjects,
        mapping(
            bytes32 => StreamEntropyCoordinator.Request
        ) storage requests,
        mapping(bytes32 => IStreamEntropyEpochs.RequestPolicySnapshot) storage policies,
        mapping(uint256 => IStreamRevealFeeEscrow.CollectionRevealPolicy) storage reveal,
        bytes calldata encoded
    ) public view returns (bytes memory) {
        bytes4 selector = bytes4(encoded[:4]);
        bytes32 id = abi.decode(encoded[4:], (bytes32));
        if (selector == bytes4(keccak256("collectionRevealPolicy(uint256)"))) {
            return abi.encode(reveal[uint256(id)]);
        }
        if (selector == bytes4(keccak256("requestPolicySnapshot(bytes32)"))) {
            return abi.encode(policies[id]);
        }
        if (selector == bytes4(keccak256("scopeEntropy(bytes32)"))) {
            return abi.encode(subjects[id]);
        }
        if (selector == bytes4(keccak256("scopeSeed(bytes32)"))) {
            StreamEntropyCoordinator.Subject storage scope = subjects[id];
            return abi.encode(scope.seed, scope.status == StreamEntropyStatus.FINALIZED);
        }
        StreamEntropyCoordinator.Subject storage subject =
            subjects[keccak256(abi.encode("TOKEN", uint256(id)))];
        if (selector == bytes4(keccak256("tokenSeed(uint256)"))) {
            return abi.encode(subject.seed, subject.status == StreamEntropyStatus.FINALIZED);
        }
        if (selector != bytes4(keccak256("tokenEntropy(uint256)"))) {
            revert StreamEntropyCoordinator.InvalidSubject(id);
        }
        if (subject.requestKey != 0) {
            IStreamEntropyEpochs.RequestPolicySnapshot storage policy = policies[subject.requestKey];
            return abi.encode(
                subject.status,
                subject.seed,
                policy.provider,
                policy.providerEpoch,
                policy.providerConfigHash,
                subject.requestKey,
                requests[subject.requestKey].providerRequestId,
                policy.requestAttempt
            );
        }
        StreamEntropyCoordinator.CollectionConfig storage config = configs[subject.collectionId];
        return abi.encode(
            subject.status,
            subject.seed,
            config.provider,
            epochs[subject.collectionId],
            config.providerConfigHash,
            bytes32(0),
            uint256(0),
            uint16(0)
        );
    }
}
