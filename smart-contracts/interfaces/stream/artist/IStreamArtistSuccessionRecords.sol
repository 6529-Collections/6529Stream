// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import { StreamArtistSuccessionTypes as Succ } from "./StreamArtistSuccessionTypes.sol";

/// @notice Current-artist records and operative defensive designee, without successor activation.
interface IStreamArtistSuccessionReads {
    function successorDesignation(bytes32 artistId)
        external
        view
        returns (address, uint8, uint32, bytes32, bytes32, uint256);
    function operativeSuccessorRecord(bytes32 artistId) external view returns (bytes32);
    function operativeEstateDirective(bytes32 artistId) external view returns (bytes32);
    function successorDesignationRecord(bytes32 record)
        external
        view
        returns (Succ.DesignationRecord memory);
    function estateDirectiveRecord(bytes32 record)
        external
        view
        returns (Succ.DirectiveRecord memory);
    function estateDirectivePayload(bytes32 record) external view returns (bytes memory);
}

interface IStreamArtistSuccessionRecords is IStreamArtistSuccessionReads {
    function recordSuccessorDesignation(Succ.Designation calldata p, T.Authorization calldata a)
        external
        returns (bytes32);
    function recordEstateDirective(
        Succ.Directive calldata p,
        T.Authorization calldata a,
        Succ.PublicDocument calldata document
    ) external returns (bytes32);
    function successorDesignationDigest(Succ.Designation calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32);
    function estateDirectiveDigest(Succ.Directive calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32);
    /// @notice Exact generated public JCS schema bytes; not a validator for arbitrary JSON.
    function previewEstateDirectivePayload(
        uint32 granted,
        uint32 forbidden,
        Succ.PublicDocument calldata document
    ) external view returns (bytes memory);
}

interface IStreamArtistSuccessionOwner is IStreamArtistSuccessionReads {
    function recordSuccessorDesignation(
        T.ActionContext calldata c,
        Succ.Designation calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32);
    function recordEstateDirective(
        T.ActionContext calldata c,
        Succ.Directive calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof,
        Succ.PublicDocument calldata document
    ) external returns (bytes32);
}

interface IStreamArtistSuccessionCoordinator {
    function coordinateRecordSuccessorDesignation(
        address actor,
        Succ.Designation calldata p,
        T.Authorization calldata a
    ) external returns (bytes32);
    function coordinateRecordEstateDirective(
        address actor,
        Succ.Directive calldata p,
        T.Authorization calldata a,
        Succ.PublicDocument calldata document
    ) external returns (bytes32);
}
