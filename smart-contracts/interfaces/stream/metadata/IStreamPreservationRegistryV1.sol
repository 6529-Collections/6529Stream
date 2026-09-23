// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamRendererRegistry as V } from "./IStreamRendererRegistry.sol";
import { StreamFinalityScope } from "../finality/StreamArtworkFinalityTypes.sol";

/// @notice Independent immutable admission of explicit preservation output; never live tokenURI.
interface IStreamPreservationRegistryV1 {
    struct ProducerBinding {
        address producer;
        bytes32 producerCodeHash;
        bytes32 profile;
        address core;
        address router;
        address liveRenderer;
        bytes32 liveRendererCodeHash;
        address attribution;
        bytes32 attributionCodeHash;
    }
    struct Admission {
        address registry;
        bytes32 registryCodeHash;
        bytes32 versionKey;
        bytes32 registrationHash;
        bytes32 readSetHash;
        bytes32 analysisHash;
        bytes32 goldenHash;
    }
    struct PreservationRegistration {
        bytes32 versionKey;
        ProducerBinding binding;
        bytes32 schemaDocument;
        bytes32 analysisDocument;
        bytes32 goldenDocument;
    }
    struct PreservationRecord {
        PreservationRegistration registration;
        bytes32 registrationHash;
        bytes32 readSetHash;
        bytes32 analysisHash;
        bytes32 goldenHash;
        bytes32 actionId;
    }
    struct PreservationAnalysis {
        bytes32 analysisProfile;
        ProducerBinding binding;
        bytes32 originalRegistrationHash;
        bytes32 schemaHash;
        bytes32 readSetHash;
        bytes32 toolHash;
        bytes32 findingsHash;
        bool passed;
    }
    struct PreservationGoldenVector {
        StreamFinalityScope scope;
        uint256 tokenId;
        bytes32 adoptionRecord;
        uint8 mode;
        bytes32 outputHash;
    }
    error InvalidPreservationAdmission();
    error PreservationUnavailable(bytes32 key);
    event PreservationRegistered(uint16 schemaVersion,bytes32 indexed key,address indexed producer,
        bytes32 indexed actionId,bytes32 registrationHash,PreservationRegistration registration,V.Read[] reads);
    function registerPreservation(PreservationRegistration calldata registration,V.Read[] calldata reads) external;
    function preservationTransition(PreservationRegistration calldata registration,V.Read[] calldata reads)
        external view returns(bytes32 scope,bytes32 previous,bytes32 next);
    function preservationKey(bytes32 versionKey,address producer,bytes32 profile) external pure returns(bytes32);
    function preservationRecord(bytes32 key) external view returns(PreservationRecord memory);
    function preservationReads(bytes32 key) external view returns(V.Read[] memory);
    /// @dev Exact 512 bytes. VIEW callers also join preservationViewBinding(adoptionRecord).
    /// Every output retains its own Admission, including its actual registry and version key.
    function requirePreservation(bytes32 versionKey,address producer,bytes32 profile)
        external view returns(ProducerBinding memory,Admission memory);
}
