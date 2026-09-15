// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import { StreamArtistContentTypes as Content } from "./StreamArtistContentTypes.sol";

/// @notice Typed protocol-only identity callbacks for the two content authorization families.
interface IStreamArtistContentIdentityOwner {
    function consumeContentConsent(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Content.Consent calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32);

    function consumeContentFreeze(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Content.Freeze calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32);
}

/// @notice Permanent content facts are owned only by ConsentFinalityLifecycle.
interface IStreamArtistContentRecordsOwner {
    struct ConsentRecord {
        bytes32 recordHash;
        bytes32 artistId;
        uint64 bindingGeneration;
        Content.Consent terms;
        uint8 authorityClass;
    }

    function recordContentConsent(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Content.Consent calldata p,
        address signer,
        uint256 nonce
    ) external returns (bytes32);

    function authorizeContentFreeze(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Content.Freeze calldata p,
        address signer,
        uint256 nonce
    ) external returns (bytes32);

    function contentConsentRecord(bytes32 recordHash) external view returns (ConsentRecord memory);
    function contentConsentAt(Content.Consent calldata p, uint64 generation)
        external
        view
        returns (ConsentRecord memory);
    function contentFreezeRecord(bytes32 recordHash)
        external
        view
        returns (Content.FreezeRecord memory);
    function contentFreezeAt(
        uint256 collectionId,
        uint64 generation,
        address metadata,
        bytes32 lockClass
    ) external view returns (Content.FreezeRecord memory);
}

interface IStreamArtistContentCoordinator {
    function coordinateRecordContentConsent(
        address actor,
        Content.Consent calldata p,
        T.Authorization calldata a
    ) external returns (bytes32);
    function coordinateAuthorizeArtistContentFreeze(
        address actor,
        Content.Freeze calldata p,
        T.Authorization calldata a
    ) external returns (bytes32);
}
