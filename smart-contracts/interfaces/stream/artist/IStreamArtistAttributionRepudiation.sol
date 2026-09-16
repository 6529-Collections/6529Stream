// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamArtistAttributionDisputes.sol";
import { StreamArtistAttributionDisputeTypes as AD } from "./IStreamArtistAttributionDisputes.sol";

library StreamArtistRepudiationTypes {
    struct AuthorityHead {
        address principal;
        uint8 authorityClass;
        bytes32 latestTransition;
        bytes32 latestContest;
        bytes32 latestDismissal;
    }

    struct Record {
        bytes32 recordHash;
        AD.Filing terms;
        bytes32 artistId;
        address signer;
        uint8 authorityClass;
        uint256 nonce;
        uint64 stagedAt;
        uint64 executableAt;
        bytes32 bindingHash;
        AuthorityHead authorityHead;
        bytes32 capturedGuardianSet;
        uint64 windowRevision;
    }

    struct Terminal {
        uint8 phase;
        address actor;
        bytes32 reasonHash;
        uint64 recordedAt;
    }

    struct Admission {
        T.Binding binding_;
        AuthorityHead authorityHead;
        bytes32 guardianSet;
        uint64 stagedAt;
        uint64 executableAt;
        uint64 windowRevision;
    }

    struct Mutation {
        bytes32 record;
        bytes32 action;
        bytes32 state;
        bytes32 replayScope;
        bytes32 replayCommitment;
    }

    struct GuardianProof {
        uint256 collectionId;
        bytes32 repudiationRecordHash;
        bytes32 capturedGuardianSet;
        bytes32 currentGuardianSet;
        address vetoer;
        bytes32 reasonHash;
        uint64 vetoedAt;
    }
    error InvalidRepudiation(bytes32 recordHash);
    error RepudiationNotExecutable(bytes32 recordHash);
    error ActiveRepudiation(bytes32 artistId);
}

interface IStreamArtistRepudiationEvents {
    event AttributionRepudiationStaged(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed artistId,
        address indexed signer,
        uint64 bindingGeneration,
        uint8 authorityClass,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        uint256 nonce,
        uint64 stagedAt,
        uint64 executableAt,
        bytes32 repudiationRecordHash
    );
    event AttributionRepudiationVetoed(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        address indexed vetoer,
        bytes32 indexed repudiationRecordHash,
        bytes32 reasonHash
    );
    event AttributionRepudiationCancelled(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        address indexed canceller,
        bytes32 indexed repudiationRecordHash,
        uint8 authorityClass
    );
    event AttributionRepudiationContext(
        uint16 schemaVersion,
        uint256 chainId,
        address registry,
        bytes32 indexed repudiationRecordHash,
        bytes32 bindingHash,
        StreamArtistRepudiationTypes.AuthorityHead authorityHead,
        bytes32 capturedGuardianSet,
        uint64 windowRevision
    );
    event AttributionRepudiationInvalidated(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed repudiationRecordHash,
        bytes32 identityHeadHash,
        bytes32 disputeRecordHash
    );
}

interface IStreamArtistAttributionRepudiation is IStreamArtistRepudiationEvents {
    function revokeAttribution(AD.Filing calldata filing, T.Authorization calldata authorization)
        external
        returns (bytes32);
    function vetoAttributionRepudiation(
        uint256 collectionId,
        bytes32 expectedRepudiation,
        bytes32 reasonHash
    ) external;
    function cancelAttributionRepudiation(uint256 collectionId, bytes32 expectedRepudiation)
        external;
    function executeAttributionRepudiation(uint256 collectionId, bytes32 expectedRepudiation)
        external;
    function pendingRepudiation(uint256 collectionId)
        external
        view
        returns (uint64 bindingGeneration, uint64 executableAt, bytes32 repudiationRecordHash);
    function attributionRepudiationRecord(bytes32 recordHash)
        external
        view
        returns (StreamArtistRepudiationTypes.Record memory);
    function attributionRepudiationTerminal(bytes32 recordHash)
        external
        view
        returns (StreamArtistRepudiationTypes.Terminal memory);
    function activeRepudiationCount(bytes32 artistId) external view returns (uint256);
    function attributionRepudiationDigest(
        AD.Filing calldata filing,
        T.Authorization calldata authorization
    ) external view returns (bytes32);
}

interface IStreamArtistRepudiationOwner {
    function rawPendingRepudiation(uint256 collectionId) external view returns (bytes32);
    function attributionRepudiationRecord(bytes32 recordHash)
        external
        view
        returns (StreamArtistRepudiationTypes.Record memory);
    function attributionRepudiationTerminal(bytes32 recordHash)
        external
        view
        returns (StreamArtistRepudiationTypes.Terminal memory);
    function repudiationCount(bytes32 artistId, bytes32 authorityHeadHash)
        external
        view
        returns (uint256);
    function stageRepudiation(
        T.ActionContext calldata c,
        AD.Filing calldata p,
        StreamArtistRepudiationTypes.Admission calldata admission,
        uint256 nonce
    ) external returns (bytes32);
    function vetoRepudiation(
        T.ActionContext calldata c,
        StreamArtistRepudiationTypes.Record calldata record,
        StreamArtistRepudiationTypes.GuardianProof calldata proof
    ) external;
    function cancelRepudiation(
        T.ActionContext calldata c,
        StreamArtistRepudiationTypes.Record calldata record
    ) external;
    function executeRepudiation(
        T.ActionContext calldata c,
        StreamArtistRepudiationTypes.Record calldata record
    ) external;
}

interface IStreamArtistRepudiationIdentityOwner {
    function consumeRepudiation(
        T.ActionContext calldata c,
        AD.Filing calldata p,
        StreamArtistRepudiationTypes.Admission calldata admission,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32);
    function contestRepudiation(
        T.ActionContext calldata c,
        StreamArtistRepudiationTypes.GuardianProof calldata proof
    ) external returns (bytes32);
    function noteRepudiationCancellation(
        T.ActionContext calldata c,
        StreamArtistRepudiationTypes.Record calldata record
    ) external;
}

interface IStreamArtistRepudiationCoordinator {
    function coordinateRevokeAttribution(
        address actor,
        AD.Filing calldata p,
        T.Authorization calldata a
    ) external returns (bytes32);
    function coordinateVetoAttributionRepudiation(
        address actor,
        uint256 collectionId,
        bytes32 expectedRepudiation,
        bytes32 reasonHash
    ) external;
    function coordinateCancelAttributionRepudiation(
        address actor,
        uint256 collectionId,
        bytes32 expectedRepudiation
    ) external;
    function coordinateExecuteAttributionRepudiation(
        address actor,
        uint256 collectionId,
        bytes32 expectedRepudiation
    ) external;
}
