// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityPreservationCallerBootstrap
} from "../../helpers/StreamCurrentAuthorityPreservationCallerBootstrap.sol";

interface PreservationCallerExportVm {
    function envOr(string calldata key, string calldata defaultValue)
        external
        view
        returns (string memory value);
    function envOr(string calldata key, bool defaultValue) external view returns (bool value);
    function skip(bool condition) external;
}

/// @notice Opt-in outer TEST entrypoint for the genuine caller preparation export.
/// @dev Set STREAM_CALLER_PREPARATION_PREFIX to a fresh ./artifacts/native-assembly/<label>.
/// Bootstrap validates that prefix and reads exactly <prefix>.admitted-prestate.abi. There is no
/// setUp or intermediary deployment: the inherited internal call preserves this recorder and the
/// original msg.sender, including Bootstrap's validation-before-recording order.
/// An ordinary suite skips when envOr returns empty (unset, unreadable or empty configuration).
/// An actual export campaign
/// must select testExportPreparationFromAdmittedFile and require exactly one passed test and zero
/// skipped/failed tests, independently authenticated output files and a successful outer result.
/// Files can survive a later revert, so a completion marker alone never proves success. This
/// adapter does not prove dynamic getCode library linking/predeployment: the native TEST context,
/// linked Scenario artifact and complete admitted library prestate must be verified separately.
/// Set STREAM_CALLER_CAPTURE_PRESTATE=true only for candidate baseline capture in this exact
/// compiled host/case/context. That branch does not prepare the protocol or produce an export.
/// External orchestration must bind the exact mode, its distinct marker and outer success; a
/// passed baseline case cannot be counted as export. Independently admit actual native libraries
/// and complete baseline closure before copying candidate bytes to the admitted input path.
contract StreamCurrentAuthorityPreservationCallerExportTest is
    StreamCurrentAuthorityPreservationCallerBootstrap
{
    PreservationCallerExportVm private constant exportVm =
        PreservationCallerExportVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testExportPreparationFromAdmittedFile() public {
        string memory prefix = exportVm.envOr("STREAM_CALLER_PREPARATION_PREFIX", string(""));
        if (bytes(prefix).length == 0) {
            exportVm.skip(true);
            return;
        }
        if (exportVm.envOr("STREAM_CALLER_CAPTURE_PRESTATE", false)) {
            BaselineCut memory baseline = capturePrestateFile(prefix);
            require(
                baseline.recorder == address(this) && baseline.caller == msg.sender
                    && baseline.origin == tx.origin
                    && baseline.recorderCodeHash == address(this).codehash,
                "baseline outer caller preserved"
            );
            return;
        }
        Cut memory cut = exportPreparationFile(prefix);
        require(cut.recorder == address(this) && cut.caller == msg.sender, "outer caller preserved");
    }
}
