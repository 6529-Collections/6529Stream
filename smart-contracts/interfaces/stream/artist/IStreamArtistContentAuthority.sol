// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import { StreamArtistContentTypes as C } from "./StreamArtistContentTypes.sol";

/// @notice Artist permission for exact content changes and defensive one-way freezes.
/// @dev A narrow capability; declaring it does not advertise the complete 57-operation registry.
interface IStreamArtistContentAuthority {
    function recordContentConsent(C.Consent calldata p, T.Authorization calldata a)
        external
        returns (bytes32);

    function authorizeArtistContentFreeze(C.Freeze calldata p, T.Authorization calldata a)
        external
        returns (bytes32);

    function contentConsentDigest(C.Consent calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32);

    function contentFreezeDigest(C.Freeze calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32);

    function requireContentConsent(uint256 collectionId, bytes32 familyId, bytes32 newStateHash)
        external
        view;

    /// @notice Performs all requireContentConsent validation and returns the exact record for one applied write.
    /// @dev The admitted host separately consumes each record once before changing actual state.
    function contentConsentEvidence(uint256 collectionId, bytes32 familyId, bytes32 newStateHash)
        external
        view
        returns (bytes32 recordHash);

    function isContentFreezeAuthorized(uint256 collectionId, bytes32 lockClass)
        external
        view
        returns (bool authorized, bytes32 freezeRecordHash);

    /// @notice Historical authorization terms; current applicability comes from isContentFreezeAuthorized.
    function contentFreezeAuthorization(bytes32 recordHash)
        external
        view
        returns (C.FreezeRecord memory);
}
