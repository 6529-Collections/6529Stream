// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamPreparedNativeContentTypes.sol";
import "./IStreamPrivateSaleAdapter.sol";

/// @notice Per-purchase evidence without changing the immutable sale or content identity.
library StreamPreparedNativeContentPurchaseTypes {
    struct Purchase {
        bytes32 saleId;
        uint256 saleNonce;
        bytes32 saleConfigHash;
        bytes32 purchaseId;
        address buyer;
        uint256 purchaseNonce;
        bytes32 authorizationId;
        address authorizer;
        uint8 authorizerKind;
        uint8 primaryPolicyMode;
    }

    struct GateData {
        bytes32 intentHash;
        bytes32 authorizationId;
        StreamPreparedNativeContentTypes.Selection selection;
        StreamPrivateSaleTypes.SaleAuthorization authorization;
        IStreamPrivateSaleAdapter.Signature signature;
    }
}
