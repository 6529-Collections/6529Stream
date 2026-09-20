// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../finality/StreamArtworkFinalityTypes.sol";
import "../finality/StreamScopeMembershipTypes.sol";
import { IStreamStaticMetadataRouter as Static } from "./IStreamStaticMetadataRouter.sol";

/// @notice Exact alternate-view adoption vocabulary. Scope membership and viewId are distinct.
library StreamViewAdoptionTypes {
    bytes32 internal constant PROFILE = keccak256("6529STREAM_STATIC_ADOPTED_VIEW_V1");
    bytes32 internal constant CONTEXT = keccak256("STREAM_ADOPTED_VIEW_CONTEXT_V1");
    uint256 internal constant MAX_PAYLOAD = 40960;

    struct Payload {
        bytes32 contextVersion;
        string name;
        string description;
        string imageURI;
        bytes script;
    }

    struct Input {
        StreamFinalityScope scope;
        bytes32 viewId;
        bytes32 viewRecordHash;
        bytes32 expectedPrevious;
        address rendererRegistry;
        bytes32 rendererVersionKey;
        bytes32 expectedSourceHash;
    }

    /// @dev Only constructor-bound actual provider data may select these dependencies.
    struct Binding {
        address views;
        bytes32 viewsCodeHash;
        address membership;
        bytes32 membershipCodeHash;
        uint32 readGas;
        uint32 sourceGas;
    }

    struct Route {
        address core;
        bytes32 coreCodeHash;
        address router;
        bytes32 routerCodeHash;
        address artist;
        bytes32 artistCodeHash;
        address finality;
        bytes32 finalityCodeHash;
        address provider;
        bytes32 providerCodeHash;
        address metadata;
        bytes32 metadataCodeHash;
        address schemas;
        bytes32 schemasCodeHash;
        address store;
        bytes32 storeCodeHash;
        Binding binding;
    }

    /// @dev All fields are static; original declared payload remains separate and complete.
    struct Source {
        Route route;
        StreamScopeMembershipFacts membership;
        Static.Selection renderer;
        bytes32 schemaHash;
        bytes32 manifestSchemaHash;
        bytes32 canonicalizationHash;
        bytes32 manifestPayloadHash;
        bytes32 viewReceiptHash;
        bytes32 payloadHash;
        uint32 payloadBytes;
        address[5] payloadPointers;
        bytes32[5] payloadChunkHashes;
    }

    struct Aggregate {
        uint64 revision;
        bytes32 transitionChain;
    }

    struct Record {
        Input input;
        Source source;
        bytes32 sourceHash;
        bytes32 recordHash;
        uint64 revision;
        address actor;
        uint8 authorizationClass;
        uint256 grantCollectionId;
        uint64 grantRevision;
        bytes32 artistConsent;
        uint64 adoptedAt;
        Aggregate aggregate;
    }
    error InvalidViewAdoption();
    error ViewAdoptionDependency(address target);
    error ViewAdoptionRead(address target, bytes4 selector);
    error ViewAdoptionGas(uint256 available, uint256 required);
    error ViewAdoptionFrozen(bytes32 subject);
    error ViewAdoptionAuthority(address actor);
    error ViewAdoptionLineage(bytes32 expected, bytes32 actual);
    error UnknownViewAdoption(bytes32 recordHash);
    error ViewAdoptionChunk(address pointer);
}
