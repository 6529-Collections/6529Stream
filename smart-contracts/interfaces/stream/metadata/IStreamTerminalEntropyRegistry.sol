// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamCurrentCitationRegistry as C } from "./IStreamCurrentCitationRegistry.sol";
import { IStreamRendererRegistry as V } from "./IStreamRendererRegistry.sol";

/// @notice Separate immutable evidence for explicit entropy-independent terminal rendering.
interface IStreamTerminalEntropyRegistry {
    struct TerminalAnalysis {
        C.CurrentAnalysis bindings;
        bool entropyIndependent;
    }
    error InvalidTerminalEntropyAdmission();
    error TerminalEntropyProfileUnavailable(bytes32 versionKey);
    event TerminalEntropyProfileRegistered(
        uint16 schemaVersion,
        bytes32 indexed versionKey,
        address indexed renderer,
        bytes32 indexed actionId,
        bytes32 registrationHash,
        C.CurrentRegistration registration,
        V.Read[] reads
    );
    function registerTerminalEntropy(
        C.CurrentRegistration calldata registration,
        V.Read[] calldata reads
    ) external;
    function terminalEntropyTransition(
        C.CurrentRegistration calldata registration,
        V.Read[] calldata reads
    ) external view returns (bytes32 scope, bytes32 previous, bytes32 next);
    function terminalEntropyRecord(bytes32 versionKey)
        external
        view
        returns (C.CurrentRecord memory);
    function terminalEntropyReads(bytes32 versionKey) external view returns (V.Read[] memory);
    function requireTerminalEntropy(bytes32 versionKey)
        external
        view
        returns (address renderer, bytes32 runtimeHash, bytes32 profile, bytes4 selector);
}
