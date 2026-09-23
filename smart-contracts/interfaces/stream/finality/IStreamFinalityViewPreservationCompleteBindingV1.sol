// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityViewPreservationBindingTypesV1 as Basic
} from "./StreamFinalityViewPreservationBindingTypesV1.sol";
import {
    IStreamViewPreservationFinalitySourcesV1 as Sources
} from "./IStreamViewPreservationFinalitySourcesV1.sol";
import { StreamViewAdoptionTypes as Declaration } from "../metadata/StreamViewAdoptionTypes.sol";

/// @notice Optional complete source selection at the one original class2 binding action.
/// @dev Either this path or the basic path permanently consumes the same unbound state.
interface IStreamFinalityViewPreservationCompleteBindingV1 {
    event ViewPreservationCompleteBound(
        bytes32 indexed completeRecordHash,
        bytes32 indexed basicRecordHash,
        bytes32 indexed actionId,
        bytes32 fullProposalHash
    );

    function completeViewPreservationBindingProfile() external pure returns (bytes32);
    function completeViewPreservationBindingTransition(
        Basic.Configuration calldata configuration,
        Declaration.Binding calldata declaration,
        Sources.Selection calldata selection
    ) external view returns (Basic.Transition memory);
    function bindCompleteViewPreservation(
        Basic.Configuration calldata configuration,
        Declaration.Binding calldata declaration,
        Sources.Selection calldata selection
    ) external returns (bytes32 completeRecordHash);
}
