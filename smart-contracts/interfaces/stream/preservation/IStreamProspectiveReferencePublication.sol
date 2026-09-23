// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../../vendor/openzeppelin/IERC165.sol";
import { StreamProspectiveReferenceTypes as P } from "./StreamProspectiveReferenceTypes.sol";

/// @notice Separate pre-sale simulation evidence. Does not implement an artwork finality component.
interface IStreamProspectiveReferencePublication is IERC165 {
    event ProspectiveReferencePublished(
        uint16 schemaVersion,
        bytes32 indexed recordHash,
        uint256 indexed collectionId,
        bytes32 indexed referenceId,
        P.Receipt receipt,
        string manifestURI
    );
    function core() external view returns (address);
    function conservationFloor() external view returns (address);
    function dependencies() external view returns (P.Dependencies memory);
    function currentSource(uint256 collectionId) external view returns (P.Source memory, bytes32);
    function simulationHTML(uint256 collectionId, P.Vector calldata vector)
        external
        view
        returns (bytes memory);
    function previewProspectiveReference(P.Publication calldata publication, address recorder)
        external
        view
        returns (bytes32 sourceHash, bytes memory canonical);
    function publishProspectiveReference(P.Publication calldata publication)
        external
        returns (bytes32);
    function currentProspectiveReference(uint256 collectionId)
        external
        view
        returns (P.Receipt memory);
    function requireProspectiveCollectionReference(
        uint256 collectionId,
        bytes32 subject,
        bytes32 membershipHash
    ) external view returns (bytes32 evidenceHash);
    function prospectiveRecord(bytes32 hash)
        external
        view
        returns (P.Publication memory, P.Receipt memory);
    function prospectivePayload(bytes32 hash) external view returns (bytes memory);
    function prospectiveCount(uint256 collectionId) external view returns (uint256);
    function prospectiveAt(uint256 collectionId, uint256 index) external view returns (bytes32);
}
