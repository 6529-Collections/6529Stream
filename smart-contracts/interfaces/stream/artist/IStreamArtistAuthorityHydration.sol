// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamArtistAuthorityCheckpoint.sol";
import "./StreamArtistOnboardingTypes.sol";
import "./StreamArtistCollaboratorTypes.sol";
import "../../../vendor/openzeppelin/IERC165.sol";

library StreamArtistAuthorityHydrationTypes {
    struct Origin {
        bytes32 surface;
        bytes32 scope;
    }

    struct PolicyKey {
        bytes32 phaseId;
        bytes32 policyHash;
    }

    struct Request {
        uint256 bindingIndex;
        bytes32 artistId;
        uint256 collectionId;
        IStreamArtistAuthorityCheckpoint.Checkpoint[7] expectedSource;
        Origin[][7] replayOrigins;
        PolicyKey[] policies;
    }

    struct Query {
        bytes32 artistId;
        uint256 collectionId;
        bytes32 bindingHash;
        PolicyKey[] policies;
        bytes32[] records;
    }

    struct NonceWord {
        uint256 prefix;
        uint256[32] words;
        bool exhausted;
    }

    struct OwnerData {
        bytes typedState;
        Origin[] origins;
        bytes32[] sourceKeys;
        StreamArtistOnboardingTypes.ReplayCell[] cells;
        NonceWord[] nonces;
    }

    struct Identity {
        StreamArtistOnboardingTypes.Identity item;
        bytes document;
        uint256 nextRegistrationNonce;
        uint256 estateActivity;
        uint256 dormancyActivity;
        uint256 findingActivity;
        bytes[] signatures;
    }

    struct Binding {
        StreamArtistOnboardingTypes.Binding item;
        StreamArtistCollaboratorTypes.BindingTerms terms;
    }

    struct Acceptance {
        bytes32 record;
        uint64 acceptedAt;
    }
}

/// @notice Distinct permissionless operation60. No caller-provided fact is an authorization.
interface IStreamArtistAuthorityHydration is IERC165 {
    function hydrateArtistAuthority(StreamArtistAuthorityHydrationTypes.Request calldata request)
        external
        returns (bytes32);
}

interface IStreamArtistAuthorityHydrationCoordinator {
    function coordinateHydrateArtistAuthority(
        address actor,
        StreamArtistAuthorityHydrationTypes.Request calldata request
    ) external returns (bytes32);
    function authorityHydrationSuite()
        external
        view
        returns (StreamArtistOnboardingTypes.SuiteConfiguration memory);
}

interface IStreamArtistAuthorityHydrationOwner {
    function authorityHydrationState(StreamArtistAuthorityHydrationTypes.Query calldata query)
        external
        view
        returns (bytes memory);
    function authorityHydrationCommitment() external view returns (bytes32);
    function applyArtistAuthorityHydration(
        StreamArtistOnboardingTypes.ActionContext calldata context,
        StreamArtistAuthorityHydrationTypes.Query calldata query,
        StreamArtistAuthorityHydrationTypes.OwnerData calldata data,
        bytes32 commitment
    ) external;
}
