// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamReferenceRenderTypes as R } from "./StreamReferenceRenderTypes.sol";
import { StreamReferenceModeTypes as M } from "./StreamReferenceModeTypes.sol";
import { IERC165 } from "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Immutable byte preparation only. No source observation or writer authority is accepted here.
interface IStreamReferenceModePayloadPreparation is IERC165 {
    struct PublicationDescriptor {
        bytes32 publicationHash;
        uint32 publicationBytes;
        bytes32 environmentId;
        bytes32 environmentHash;
        uint32 environmentBytes;
    }

    event ReferenceModePublicationPrepared(
        uint16 schemaVersion, bytes32 indexed preparationId, PublicationDescriptor descriptor
    );
    event ReferenceModePayloadPrepared(
        uint16 schemaVersion,
        bytes32 indexed preparationId,
        bytes32 indexed publicationPreparationId,
        bytes32 payloadHash,
        uint32 payloadBytes
    );

    /// @dev Requires the exact typed Environment to have been prepared and all canonical ABI
    /// publication chunks preuploaded. Idempotent intact reads emit no new event.
    function prepareModePublication(R.Publication calldata publication) external returns (bytes32);

    /// @dev Uses the immutable publication and its authenticated Environment. Receipt fields
    /// normalized by the original payload encoder are normalized identically here. The eventual
    /// writer derives the expected identity from fresh original source/evidence/authority facts.
    function prepareModePayload(
        bytes32 publicationPreparationId,
        R.Receipt calldata receipt,
        R.SourceFacts calldata source,
        M.Evidence calldata evidence,
        M.Facts calldata facts
    ) external returns (bytes32);

    function preparedModePublication(bytes32 preparationId)
        external
        view
        returns (PublicationDescriptor memory descriptor, bytes memory canonical);
    function preparedModePayload(bytes32 preparationId)
        external
        view
        returns (bytes memory canonical);
}
