// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamArtistSaleFacts
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistSaleFacts.sol";

/// @dev Immutable sale-facts boundary registered in the actual ModuleRegistry. No sale/payment claim.
contract RecoveredDelegationSaleFacts {
    address public immutable core;
    bytes32 public constant ID = keccak256("recovered delegated sale");
    bytes32 public constant CONFIG = keccak256("recovered delegated immutable sale terms");

    constructor(address core_) {
        core = core_;
    }

    function streamModuleType() external pure returns (bytes32) {
        return keccak256("RECOVERED_DELEGATION_SALE_FACTS");
    }

    function streamModuleInterfaceId() external pure returns (bytes4) {
        return type(IStreamArtistSaleFacts).interfaceId;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamArtistSaleFacts).interfaceId || id == 0x01ffc9a7;
    }

    function saleConsentFacts(bytes32 id) external pure returns (uint256, bytes32) {
        require(id == ID);
        return (1, CONFIG);
    }
}
