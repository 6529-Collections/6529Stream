// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

library StreamArtistStewardCapabilityTypes {
    struct Grant {
        bytes32 artistId;
        bytes32 expectedAppointmentHash;
        address expectedSteward;
        bytes32 expectedDirectiveHash;
        bytes32 expectedGrantHead;
        uint32 expectedCapabilities;
        uint32 addedCapabilities;
        bytes32 reasonHash;
        string reasonURI;
    }

    struct Context {
        bytes32 scopeHash;
        bytes32 oldValueHash;
        bytes32 newValueHash;
    }

    struct Witness {
        bytes32 actionId;
        address proposer;
        address executionCaller;
        uint64 notBefore;
        uint64 expiresAfter;
        bytes32 guardianCommitment;
        bytes32 selectorConfigHash;
        uint64 selectorRevision;
        bytes32 actionManifestHash;
        Context context;
    }

    struct Record {
        bytes32 recordHash;
        Grant terms;
        Witness witness;
        address executor;
        uint32 effectiveCapabilities;
        uint64 recordedAt;
    }
    error InvalidStewardCapabilityGrant(bytes32 artistId);
    error InvalidStewardGrantGovernance();
}

interface IStreamArtistStewardCapabilities {
    event StewardCapabilitiesGranted(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 indexed appointmentHash,
        bytes32 indexed recordHash,
        address steward,
        uint32 addedCapabilities,
        uint32 effectiveCapabilities,
        bytes32 actionId,
        bytes32 previousGrantHash
    );
    function grantStewardCapabilities(StreamArtistStewardCapabilityTypes.Grant calldata terms)
        external
        returns (bytes32);
    function stewardCapabilityGrantContext(StreamArtistStewardCapabilityTypes.Grant calldata terms)
        external
        view
        returns (StreamArtistStewardCapabilityTypes.Context memory);
    function stewardCapabilityGrantRecord(bytes32 record)
        external
        view
        returns (StreamArtistStewardCapabilityTypes.Record memory);
    function stewardCapabilityGrantState(bytes32 appointment)
        external
        view
        returns (bytes32 head, uint32 addedCapabilities);
}

interface IStreamArtistStewardCapabilitiesOwner {
    function grantStewardCapabilities(
        T.ActionContext calldata context,
        StreamArtistStewardCapabilityTypes.Grant calldata terms,
        StreamArtistStewardCapabilityTypes.Witness calldata witness
    ) external returns (bytes32);
    function stewardCapabilityGrantContext(StreamArtistStewardCapabilityTypes.Grant calldata terms)
        external
        view
        returns (StreamArtistStewardCapabilityTypes.Context memory);
    function stewardCapabilityGrantRecord(bytes32 record)
        external
        view
        returns (StreamArtistStewardCapabilityTypes.Record memory);
    function stewardCapabilityGrantState(bytes32 appointment)
        external
        view
        returns (bytes32 head, uint32 addedCapabilities);
}

interface IStreamArtistStewardCapabilitiesCoordinator {
    function coordinateGrantStewardCapabilities(
        address actor,
        StreamArtistStewardCapabilityTypes.Grant calldata terms
    ) external returns (bytes32);
}
