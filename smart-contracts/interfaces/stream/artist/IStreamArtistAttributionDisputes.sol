// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "./StreamArtistIdentityContestTypes.sol";

library StreamArtistAttributionDisputeTypes {
    struct Filing {
        uint256 collectionId;
        uint64 bindingGeneration;
        uint8 disputeAction;
        bytes32 evidenceHash;
        bytes32 reasonHash;
    }

    // Current authority of the bound/earlier identity, or an exact accepted collaborator row.
    struct Standing {
        bytes32 artistId;
        uint64 bindingGeneration;
        uint32 collaboratorIndex;
        bytes32 delegation;
    }

    struct Evidence {
        uint16 schemaVersion;
        uint256 collectionId;
        uint64 bindingGeneration;
        bytes32 bindingHash;
        bytes32 disputeRecordHash;
        bytes32 narrativeHash;
    }

    struct ResolutionRequest {
        uint256 collectionId;
        uint64 bindingGeneration;
        bytes32 disputeRecordHash;
        uint8 resolution;
        bytes32 evidenceHash;
        bytes32 reasonHash;
        bytes32 counterStatementRecordHash;
    }

    struct Head {
        bytes32 disputeRecordHash;
        bytes32 counterStatementRecordHash;
        bytes32 resolutionActionId;
        uint8 restoreState;
        uint8 revocationReason;
        bool open;
        bool reopened;
    }

    struct Record {
        bytes32 recordHash;
        Filing terms;
        address signer;
        uint8 authorityClass;
        uint256 nonce;
        uint64 recordedAt;
        bytes32 artistId;
        bytes32 bindingHash;
        bytes32 disputeRecordHash;
        bytes32 previousRecordHash;
        Standing standing;
        bytes32 governanceActionId;
    }

    struct Resolution {
        ResolutionRequest terms;
        bytes32 actionId;
        address actor;
        address proposer;
        uint8 actionClass;
        uint8 restoredState;
        uint64 resolvedAt;
        bytes32 previousResolutionActionId;
        bytes32 witnessHash;
    }

    struct Admission {
        T.Binding binding_;
        Standing standing;
        address signer;
        uint8 authorityClass;
        uint64 recordedAt;
        bytes32 digest;
    }

    struct Context {
        bytes32 scopeHash;
        bytes32 oldValueHash;
        bytes32 newValueHash;
        uint8 requiredClass;
        uint8 restoredState;
    }

    struct Mutation {
        bytes32 record;
        bytes32 action;
        bytes32 state;
        bytes32 replayScope;
        bytes32 replayCommitment;
    }
    error InvalidAttributionDispute(uint256 collectionId);
    error DisputeStandingUnavailable(bytes32 artistId);
    error InvalidDisputeEvidence(bytes32 evidenceHash);
    error DisputeGovernanceRequired();
}

interface IStreamArtistAttributionDisputeEvents {
    event AttributionDisputeOpened(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        address indexed opener,
        uint64 bindingGeneration,
        uint8 openerAuthorityClass,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        uint256 nonce,
        uint64 openedAt,
        bytes32 disputeRecordHash
    );
    event AttributionCounterStatementRecorded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed disputeRecordHash,
        address indexed signer,
        uint64 bindingGeneration,
        uint8 authorityClass,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        uint256 nonce,
        uint64 recordedAt,
        bytes32 counterStatementRecordHash
    );
    event AttributionDisputeResolved(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed disputeRecordHash,
        uint8 resolution,
        uint8 restoredState,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        bytes32 counterStatementRecordHash,
        bytes32 governanceActionId
    );
    event AttributionDisputeRecordContext(
        uint16 schemaVersion,
        uint256 chainId,
        address registry,
        bytes32 indexed recordHash,
        uint8 disputeAction,
        bytes32 artistId,
        bytes32 bindingHash,
        bytes32 disputeRecordHash,
        bytes32 previousRecordHash,
        bytes32 authorityArtistId,
        bytes32 delegation,
        bytes32 governanceActionId
    );
}

interface IStreamArtistAttributionDisputes is IStreamArtistAttributionDisputeEvents {
    function openAttributionDispute(
        StreamArtistAttributionDisputeTypes.Filing calldata p,
        StreamArtistAttributionDisputeTypes.Standing calldata standing,
        T.Authorization calldata a
    ) external returns (bytes32);
    function recordCounterStatement(
        StreamArtistAttributionDisputeTypes.Filing calldata p,
        StreamArtistAttributionDisputeTypes.Standing calldata standing,
        T.Authorization calldata a
    ) external returns (bytes32);
    function resolveAttributionDispute(
        StreamArtistAttributionDisputeTypes.ResolutionRequest calldata p
    ) external returns (bytes32);
    function attributionDispute(uint256 id, uint64 generation)
        external
        view
        returns (StreamArtistAttributionDisputeTypes.Head memory);
    function attributionDisputeRecord(bytes32 record)
        external
        view
        returns (StreamArtistAttributionDisputeTypes.Record memory);
    function attributionDisputeResolution(bytes32 action)
        external
        view
        returns (StreamArtistAttributionDisputeTypes.Resolution memory);
    function attributionDisputeDigest(
        StreamArtistAttributionDisputeTypes.Filing calldata p,
        T.Authorization calldata a
    ) external view returns (bytes32);
    function attributionDisputeOpeningContext(StreamArtistAttributionDisputeTypes.Filing calldata p)
        external
        view
        returns (StreamArtistAttributionDisputeTypes.Context memory);
    function attributionDisputeResolutionContext(
        StreamArtistAttributionDisputeTypes.ResolutionRequest calldata p
    ) external view returns (StreamArtistAttributionDisputeTypes.Context memory);
}

interface IStreamArtistAttributionDisputesOwner {
    function applyDispute(
        T.ActionContext calldata c,
        StreamArtistAttributionDisputeTypes.Filing calldata p,
        StreamArtistAttributionDisputeTypes.Admission calldata admission,
        uint256 nonce,
        Contest.GovernanceWitness calldata g
    ) external returns (bytes32);
    function applyDisputeResolution(
        T.ActionContext calldata c,
        StreamArtistAttributionDisputeTypes.ResolutionRequest calldata p,
        T.Binding calldata b,
        Contest.GovernanceWitness calldata g
    ) external returns (bytes32);
    function attributionDispute(uint256 id, uint64 generation)
        external
        view
        returns (StreamArtistAttributionDisputeTypes.Head memory);
    function attributionDisputeRecord(bytes32 record)
        external
        view
        returns (StreamArtistAttributionDisputeTypes.Record memory);
    function attributionDisputeResolution(bytes32 action)
        external
        view
        returns (StreamArtistAttributionDisputeTypes.Resolution memory);
}

interface IStreamArtistDisputeIdentityOwner {
    function consumeAttributionDispute(
        T.ActionContext calldata c,
        StreamArtistAttributionDisputeTypes.Filing calldata p,
        T.Binding calldata authorityBinding,
        StreamArtistAttributionDisputeTypes.Standing calldata standing,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32);
}

interface IStreamArtistAttributionDisputesCoordinator {
    function coordinateOpenAttributionDispute(
        address actor,
        StreamArtistAttributionDisputeTypes.Filing calldata p,
        StreamArtistAttributionDisputeTypes.Standing calldata standing,
        T.Authorization calldata a
    ) external returns (bytes32);
    function coordinateRecordCounterStatement(
        address actor,
        StreamArtistAttributionDisputeTypes.Filing calldata p,
        StreamArtistAttributionDisputeTypes.Standing calldata standing,
        T.Authorization calldata a
    ) external returns (bytes32);
    function coordinateResolveAttributionDispute(
        address actor,
        StreamArtistAttributionDisputeTypes.ResolutionRequest calldata p
    ) external returns (bytes32);
}
