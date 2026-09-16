// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistGuardianSupersessionTypes as S
} from "./StreamArtistGuardianSupersessionTypes.sol";

/// @notice Permanent executed adjudication coordinate; zero means no recorded supersession.
interface IStreamArtistGuardianSupersession {
    function guardianRecordSupersession(bytes32 recordHash) external view returns (S.Status memory);
}
