// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamPrivateSaleTypes as A
} from "../../interfaces/stream/mint/StreamPrivateSaleTypes.sol";
import {
    IStreamPrivateSaleAdapter as P
} from "../../interfaces/stream/mint/IStreamPrivateSaleAdapter.sol";
import {
    IStreamNativeImmediateSales as S
} from "../../interfaces/stream/mint/IStreamNativeImmediateSales.sol";
import { StreamPrivateSaleHash } from "./StreamPrivateSaleHash.sol";
import { StreamPrivateSaleSupport } from "./StreamPrivateSaleSupport.sol";

/// @notice Fixed original Sales-v1 payload and explicit-account signature verification.
/// @dev The linked host constructs expected from its bound sale and actual mint request, after
/// validating configured signer membership. Only the signer's nonce and deadline are open fields.
/// Price-kind constraints remain with the host; this worker grants no independent mint authority.
library StreamCanonicalSaleAuthorization {
    function verify(
        address boundAuthorizer,
        uint8 boundKind,
        A.SaleAuthorization memory expected,
        A.SaleAuthorization memory actual,
        P.Signature memory proof,
        uint256 gasCap
    ) public view returns (bytes32 digest) {
        if (proof.authorizer != boundAuthorizer || proof.kind != boundKind) {
            revert S.ImmediateSaleSignerUnavailable(proof.authorizer, proof.kind);
        }
        if (actual.nonce == 0 || actual.deadline < block.timestamp) {
            revert S.InvalidImmediateSale();
        }
        expected.nonce = actual.nonce;
        expected.deadline = actual.deadline;
        bytes32 body = StreamPrivateSaleHash.authorizationBody(actual);
        if (StreamPrivateSaleHash.authorizationBody(expected) != body) {
            revert S.InvalidImmediateSale();
        }
        digest = StreamPrivateSaleHash.digest(block.chainid, address(this), body);
        if (!StreamPrivateSaleSupport.validSignature(
                proof.authorizer, proof.kind, digest, proof.signature, gasCap
            )) revert S.ImmediateSaleSignatureInvalid(proof.authorizer);
    }
}
