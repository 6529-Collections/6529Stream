// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistPlatformTypes as PW } from "./StreamArtistPlatformTypes.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import { StreamArtistBindingCorrectionTypes as BC } from "./IStreamArtistBindingCorrection.sol";

library StreamArtistPlatformCorrectionLineageTypes {
    bytes32 internal constant WITNESS =
        keccak256("6529STREAM_PLATFORM_BINDING_CONTINUATION_WITNESS_V1");
    error InvalidPlatformContinuation(uint256 collectionId);

    struct Status {
        bytes32 originalCorrectionRecord;
        bytes32 latestLineageRecord;
        uint64 generation;
        uint64 count;
        bool effectiveAccepted;
        bytes32 latestAcceptanceRecord;
    }

    struct Pins {
        PW.Declaration declaration;
        uint8 contestState;
        bytes32 contestClaim;
        bytes32 contestRecord;
        PW.Correction correction;
    }

    struct Witness {
        bytes originalCauseData;
        Pins platform;
        Status prior;
    }

    struct Record {
        bytes32 recordHash;
        uint256 collectionId;
        bytes32 declarationHash;
        bytes32 originalCorrectionRecord;
        bytes32 previousLineageRecord;
        bytes32 previousBindingHash;
        uint64 previousGeneration;
        bytes32 bindingHash;
        uint64 generation;
        bytes32 artistId;
        address artist;
        bytes32 approvalHash;
        bytes32 governanceActionId;
        uint64 recordedAt;
    }

    struct Acceptance {
        bytes32 recordHash;
        bytes32 lineageRecord;
        bytes32 acceptanceRecord;
        uint64 acceptedAt;
    }
}

interface IStreamArtistPlatformCorrectionLineage {
    function platformCorrectionStatus(uint256 collectionId)
        external
        view
        returns (StreamArtistPlatformCorrectionLineageTypes.Status memory);
    function platformCorrectionLineage(bytes32 record)
        external
        view
        returns (StreamArtistPlatformCorrectionLineageTypes.Record memory);
    function platformCorrectionAcceptance(bytes32 lineage)
        external
        view
        returns (StreamArtistPlatformCorrectionLineageTypes.Acceptance memory);
    function claimPlatformContinuation(
        T.ActionContext calldata c,
        uint256 collectionId,
        T.Binding calldata binding,
        bytes32 reasonHash,
        string calldata reasonURI,
        BC.Approval calldata approval
    ) external;
}
