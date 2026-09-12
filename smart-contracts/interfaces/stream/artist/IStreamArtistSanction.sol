// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamArtistSanctionOwner.sol";
import { StreamArtistSanctionRequestTypes as Q } from "./StreamArtistSanctionRequestTypes.sol";
import "../finality/IStreamFinalitySanctionReads.sol";

/// @notice Supported principal sanction ingress; collaborator/delegate/steward transports are separate.
interface IStreamArtistSanction is
    IStreamArtistSanctionEvents,
    IStreamArtistSanctionArchiveFacts,
    IStreamFinalitySanctionReads
{
    function recordArtistSanction(
        Q.Request calldata request,
        T.Authorization calldata authorization
    ) external returns (bytes32);
    function prepareArtistSanction(Q.Request calldata request)
        external
        view
        returns (Q.Prepared memory);
    function sanctionDigest(S.Terms calldata terms, T.Authorization calldata authorization)
        external
        view
        returns (bytes32);
    function sanctionRecord(bytes32 recordHash) external view returns (S.Record memory);
    function sanctionArchiveBytes(bytes32 recordHash) external view returns (bytes memory);
}

interface IStreamArtistSanctionCoordinator {
    function coordinateRecordArtistSanction(
        address actor,
        Q.Request calldata request,
        T.Authorization calldata authorization
    ) external returns (bytes32);
    function prepareArtistSanction(Q.Request calldata request)
        external
        view
        returns (Q.Prepared memory);
}
