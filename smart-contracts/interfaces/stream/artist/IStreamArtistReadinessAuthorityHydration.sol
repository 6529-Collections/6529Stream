// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamArtistEconomicsAuthorityHydration.sol";
import "./IStreamArtistContentOwner.sol";
import "./IStreamArtistAttestationWriter.sol";

library StreamArtistReadinessHydrationTypes {
    struct AttestationInput {
        StreamArtistOnboardingTypes.Attestation terms;
        uint256 nonce;
    }

    struct Request {
        StreamArtistEconomicsHydrationTypes.Request economics;
        AttestationInput[] attestations;
    }

    struct AttestationRow {
        AttestationInput input;
        StreamArtistOnboardingTypes.AttestationRecord record;
        uint8 authorityClass;
        StreamArtistAttestationTypes.Association association;
        bytes statement;
    }

    struct AttributionBundle {
        bytes32 schema;
        address sourceRegistry;
        uint8 state;
        uint64 generation;
        AttestationRow[] records;
    }

    struct ConsentBundle {
        bytes32 schema;
        bytes economics;
        StreamArtistOnboardingTypes.RatificationRecord[] ratifications;
        IStreamArtistContentRecordsOwner.ConsentRecord[] consents;
    }
}

interface IStreamArtistReadinessAuthorityHydration is IERC165 {
    function hydrateArtistAuthorityWithReadiness(
        StreamArtistReadinessHydrationTypes.Request calldata request
    ) external returns (bytes32);
}

interface IStreamArtistReadinessAuthorityHydrationCoordinator {
    function coordinateHydrateArtistAuthorityWithReadiness(
        address actor,
        StreamArtistReadinessHydrationTypes.Request calldata request
    ) external returns (bytes32);
}

interface IStreamArtistReadinessAttributionOwner {
    function attestationAuthorityClass(bytes32 record) external view returns (uint8);
    function authorityAttestationHydrationState(
        StreamArtistAuthorityHydrationTypes.Query calldata q,
        StreamArtistReadinessHydrationTypes.AttestationInput[] calldata inputs
    ) external view returns (bytes memory);
}

interface IStreamArtistReadinessConsentOwner {
    function authorityReadinessHydrationState(
        StreamArtistAuthorityHydrationTypes.Query calldata q,
        StreamArtistOnboardingTypes.EconomicsConsent[] calldata economics
    ) external view returns (bytes memory);
}
