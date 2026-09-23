// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamRenderer as R } from "./IStreamRenderer.sol";
import { IStreamRendererRegistry as V } from "./IStreamRendererRegistry.sol";

/// @notice Separate governed admission for current citation output. Original version evidence is unchanged.
interface IStreamCurrentCitationRegistry {
    struct CurrentRegistration {
        bytes32 versionKey;
        bytes32 profile;
        bytes4 selector;
        address encoding;
        bytes32 encodingRuntimeHash;
        bytes32 analysisDocument;
        bytes32 goldenDocument;
    }

    struct CurrentAnalysis {
        bytes32 analysisProfile;
        bytes32 outputProfile;
        bytes4 selector;
        address renderer;
        bytes32 runtimeHash;
        address encoding;
        bytes32 encodingRuntimeHash;
        bytes32 readSetHash;
        bytes32 originalRegistrationHash;
        bytes32 toolHash;
        bytes32 findingsHash;
        bool passed;
    }

    struct CurrentGoldenVector {
        R.RenderRequest request;
        uint8 mode;
        bytes32 outputHash;
    }

    struct CurrentRecord {
        CurrentRegistration registration;
        bytes32 registrationHash;
        bytes32 readSetHash;
        bytes32 analysisHash;
        bytes32 goldenHash;
        bytes32 actionId;
    }
    error InvalidCurrentCitation();
    error CurrentCitationUnavailable(bytes32 versionKey);
    event CurrentCitationRegistered(
        uint16 schemaVersion,
        bytes32 indexed versionKey,
        address indexed renderer,
        bytes32 indexed actionId,
        bytes32 registrationHash,
        CurrentRegistration registration,
        V.Read[] reads
    );
    function registerCurrentCitation(
        CurrentRegistration calldata registration,
        V.Read[] calldata reads
    ) external;
    function currentCitationTransition(
        CurrentRegistration calldata registration,
        V.Read[] calldata reads
    ) external view returns (bytes32 scope, bytes32 previous, bytes32 next);
    function currentCitationRecord(bytes32 versionKey) external view returns (CurrentRecord memory);
    function currentCitationReads(bytes32 versionKey) external view returns (V.Read[] memory);
    function requireCurrentCitation(bytes32 versionKey)
        external
        view
        returns (address renderer, bytes32 runtimeHash, bytes32 profile, bytes4 selector);
}
