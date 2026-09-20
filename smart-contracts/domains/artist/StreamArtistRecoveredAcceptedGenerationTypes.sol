// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import { StreamArtistAttributionStateTypes as AS } from "./StreamArtistAttributionStateTypes.sol";

/// @notice Separate accepted-generation codec. Prior pending-only and generation1 bytes stay exact.
library StreamArtistRecoveredAcceptedGenerationTypes {
    bytes32 internal constant BINDING =
        keccak256("6529STREAM_ARTIST_RECOVERED_ACCEPTED_BINDINGS_V1");
    bytes32 internal constant ACCEPTANCE =
        keccak256("6529STREAM_ARTIST_RECOVERED_ACCEPTANCE_HISTORY_V1");
    bytes32 internal constant ATTRIBUTION =
        keccak256("6529STREAM_ARTIST_RECOVERED_REVOKED_ATTRIBUTION_V1");

    struct Generation {
        bytes32 bindingHash;
        uint64 generation;
        bool accepted;
        RH.Point proposal;
    }

    struct Acceptance {
        bytes32 bindingHash;
        uint64 generation;
        bytes32 recordHash;
        uint64 acceptedAt;
    }

    struct AcceptanceBundle {
        bytes32 provenance;
        bytes32 artistId;
        uint256 collectionId;
        bytes32 bindingHash;
        Acceptance[] rows;
    }

    struct Revocation {
        AD.Head head;
        AD.Record opening;
        AD.Resolution resolution;
    }

    struct AttributionBundle {
        bytes32 provenance;
        bytes32 artistId;
        uint256 collectionId;
        bytes32 bindingHash;
        AS.Attribution current;
        Generation[] generations;
        Revocation[] revocations;
    }

    function tagged(bytes memory raw, bytes32 schema) internal pure returns (bool) {
        return raw.length >= 32 && abi.decode(raw, (bytes32)) == schema;
    }

    function era(RH.OwnerProvenance memory p, bytes32 hash) internal pure returns (uint256) {
        for (uint256 i; i < p.eras.length; ++i) {
            if (p.eras[i].originHash == hash) return i;
        }
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
