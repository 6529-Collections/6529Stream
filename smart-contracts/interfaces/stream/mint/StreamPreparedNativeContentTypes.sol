// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../revenue/StreamPreparedNativeSettlementTypes.sol";

/// @notice Original curated publication and the independently derived active content evidence.
library StreamPreparedNativeContentTypes {
    struct Row {
        bytes32 contentId;
        bytes32 tokenDataHash;
        string previewURI;
    }

    struct Publication {
        uint256 chainId;
        address manager;
        address house;
        bytes32 saleId;
        uint256 collectionId;
        bytes32 phaseId;
        bytes32 manifestRoot;
        bytes32 manifestHash;
        bytes32 counterId;
    }

    struct Selection {
        bytes32 contentId;
        bytes32 tokenDataHash;
        bytes32[] proof;
    }

    struct GateData {
        bytes32 authorizationId;
        Selection selection;
    }

    /// @dev Parent Facts retains the actual bytes hash; this tuple never replaces it with a leaf.
    struct Facts {
        bytes32 operationRoot;
        address gate;
        bytes32 gateCodeHash;
        bytes32 gateConfigHash;
        bytes32 manifestRoot;
        bytes32 manifestHash;
        bytes32 counterId;
        bytes32 contentId;
        bytes32 tokenDataHash;
        bytes32 contentLeaf;
        bytes32 contextHash;
    }
}
