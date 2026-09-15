// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamArtistUnavailability.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "./StreamArtistIdentityContestTypes.sol";
import "../entropy/IStreamEntropyArtistUnavailability.sol";

library StreamArtistEntropyUnavailabilityTypes {
    bytes32 internal constant PROFILE = keccak256("6529STREAM_ARTIST_ENTROPY_UNAVAILABILITY_V1");

    struct Target {
        address coordinator;
        IStreamEntropyFreshRecovery.RecoveryInput recovery;
        bytes32 intentHash;
        bytes32 unavailableEvidenceHash;
    }

    struct Admission {
        Target target;
        IStreamEntropyArtistUnavailability.Intent intent;
        bytes32 coordinatorCodeHash;
        uint256 activityEpoch;
        bytes32 governanceWitnessHash;
    }

    struct Input {
        Recovery.FindingRequest terms;
        Target target;
        IStreamEntropyArtistUnavailability.Intent intent;
        T.Binding binding_;
        Contest.GovernanceWitness governance;
        bytes32 coordinatorCodeHash;
        bool priorRecoveryTerminal;
    }

    function intentHash(
        address coordinator,
        address core,
        IStreamEntropyArtistUnavailability.Intent memory intent
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_ARTIST_RECOVERY_INTENT_V1"),
                block.chainid,
                coordinator,
                core,
                intent
            )
        );
    }

    function evidenceHash(
        address registry,
        address core,
        Target memory target,
        IStreamEntropyArtistUnavailability.Intent memory intent,
        bytes32 codeHash
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(PROFILE, block.chainid, registry, core, target, intent, codeHash)
        );
    }
}

interface IStreamArtistEntropyUnavailability {
    event ArtistEntropyUnavailabilityContext(
        uint16 schemaVersion,
        uint256 chainId,
        address indexed registry,
        bytes32 indexed findingRecordHash,
        StreamArtistEntropyUnavailabilityTypes.Admission admission
    );

    function recordEntropyUnavailabilityFinding(
        Recovery.FindingRequest calldata request,
        StreamArtistEntropyUnavailabilityTypes.Target calldata target
    ) external returns (bytes32);
    function entropyUnavailabilityFindingContext(
        Recovery.FindingRequest calldata request,
        StreamArtistEntropyUnavailabilityTypes.Target calldata target
    ) external view returns (U.Context memory);
    function entropyUnavailabilityFindingRecord(bytes32 hash)
        external
        view
        returns (
            Recovery.FindingRecord memory,
            StreamArtistEntropyUnavailabilityTypes.Admission memory
        );
    function verifyEntropyRecoveryUnavailability(
        address coordinator,
        IStreamEntropyFreshRecovery.RecoveryInput calldata input,
        bytes32 intentHash,
        bytes32 expectedFinding
    )
        external
        view
        returns (bool valid, bytes32 findingRecordHash, bytes32 artistId, uint64 noticeEndsAt);
}

interface IStreamArtistEntropyUnavailabilityOwner {
    function recordEntropyUnavailability(
        T.ActionContext calldata c,
        StreamArtistEntropyUnavailabilityTypes.Input calldata input
    ) external returns (bytes32);
    function entropyUnavailabilityFindingContext(
        StreamArtistEntropyUnavailabilityTypes.Input calldata input
    ) external view returns (U.Context memory);
    function entropyUnavailabilityFindingRecord(bytes32 hash)
        external
        view
        returns (
            Recovery.FindingRecord memory,
            StreamArtistEntropyUnavailabilityTypes.Admission memory
        );
}

interface IStreamArtistEntropyUnavailabilityCoordinator {
    function coordinateRecordEntropyUnavailabilityFinding(
        address actor,
        Recovery.FindingRequest calldata request,
        StreamArtistEntropyUnavailabilityTypes.Target calldata target
    ) external returns (bytes32);
    function prepareEntropyUnavailabilityFinding(
        Recovery.FindingRequest calldata request,
        StreamArtistEntropyUnavailabilityTypes.Target calldata target
    ) external view returns (U.Context memory);
    function verifyEntropyRecoveryUnavailability(
        address coordinator,
        IStreamEntropyFreshRecovery.RecoveryInput calldata input,
        bytes32 intentHash,
        bytes32 expectedFinding
    ) external view returns (bool, bytes32, bytes32, uint64);
}
