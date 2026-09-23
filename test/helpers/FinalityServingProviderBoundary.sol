// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./MetadataRecoveryServingBoundaries.sol";
import "../../smart-contracts/domains/finality/StreamFinalityServingHostAdapter.sol";

contract FinalityServingProfileHostBoundary is MetadataRecoverySourceBoundary {
    constructor(address c)
        MetadataRecoverySourceBoundary(c, address(StreamMetadataTokenRenderer), "source")
    { }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamMetadataRouter).interfaceId
            || id == type(IStreamMetadataServingFacts).interfaceId;
    }

    function streamModuleType() external pure returns (bytes32) {
        return keccak256("METADATA_ROUTER");
    }

    function streamModuleInterfaceId() external pure returns (bytes4) {
        return type(IStreamMetadataRouter).interfaceId;
    }
}

contract FinalityServingMetadataHostBoundary {
    address public immutable core;

    constructor(address c) {
        core = c;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamCollectionMetadataV1).interfaceId;
    }

    function streamModuleType() external pure returns (bytes32) {
        return keccak256("COLLECTION_METADATA");
    }

    function streamModuleInterfaceId() external pure returns (bytes4) {
        return type(IStreamCollectionMetadataV1).interfaceId;
    }
}

/// @dev Provider authority/record inventory are explicit boundaries. Facts hash actual source bytes.
contract FinalityServingProviderBoundary {
    address public immutable core;
    address public immutable metadataHost;
    address private _componentHost;
    bool public frozen = true;

    constructor(address c, address m, address h) {
        core = c;
        metadataHost = m;
        _componentHost = h;
    }

    function changeHost(address h) external {
        _componentHost = h;
    }

    function setFrozen(bool x) external {
        frozen = x;
    }

    function componentHost(bytes32) external view returns (address) {
        return _componentHost;
    }

    function finalityComponentFacts(bytes32 kind, StreamFinalityScope calldata scope)
        external
        view
        returns (StreamFinalityHostComponentFacts memory)
    {
        require(scope.collectionId == 1, "inventory");
        IStreamMetadataServingFacts.ServingSource memory raw =
            IStreamMetadataServingFacts(_componentHost).collectionServingSource(1);
        return StreamFinalityHostComponentFacts(
            frozen,
            keccak256("version"),
            keccak256("manifest"),
            keccak256(abi.encode(kind, scope, raw))
        );
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamFinalityServingEvidenceProvider).interfaceId;
    }
}
