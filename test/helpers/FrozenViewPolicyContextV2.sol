// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamViewPolicyTypesV2 as T
} from "../../smart-contracts/domains/metadata/StreamViewPolicyTypesV2.sol";
import {
    StreamEntropyPolicyConsumerTypes as P
} from "../../smart-contracts/interfaces/stream/entropy/StreamEntropyPolicyConsumerTypes.sol";
import { Strings } from "../../smart-contracts/vendor/openzeppelin/Strings.sol";

/// @notice Exact structured entropy fields. This formatter never fabricates readiness or seed.
/// @dev Internal to the admitted STATIC renderer; input is its authenticated original-token facts.
library FrozenViewPolicyContextV2 {
    function encode(T.Entropy memory e) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '{"kind":"',
                e.explicitPolicy ? "EXPLICIT_POLICY_V2" : "LEGACY_FINALIZED_V1",
                '","coordinator":"',
                Strings.toHexString(uint256(uint160(e.coordinator)), 20),
                '","coordinatorCodeHash":"',
                Strings.toHexString(uint256(e.coordinatorCodeHash), 32),
                '","policyHash":"',
                Strings.toHexString(uint256(e.policyHash), 32),
                '","status":',
                Strings.toString(e.status),
                ',"seed":"',
                Strings.toHexString(uint256(e.seed), 32),
                '","finalized":',
                e.finalized ? "true" : "false",
                ',"terminal":',
                e.terminal ? "true" : "false",
                ',"policy":',
                e.explicitPolicy ? _policy(e.policy) : "null",
                "}"
            )
        );
    }

    function _policy(P.Policy memory p) private pure returns (string memory) {
        bytes memory first = abi.encodePacked(
            '{"configured":',
            p.configured ? "true" : "false",
            ',"explicitPolicy":',
            p.explicitPolicy ? "true" : "false",
            ',"frozen":',
            p.frozen ? "true" : "false",
            ',"mode":',
            Strings.toString(p.mode),
            ',"securityClass":',
            Strings.toString(p.securityClass),
            ',"renderRequirement":',
            Strings.toString(p.renderRequirement),
            ',"revision":"',
            Strings.toString(p.revision),
            '","providerEpoch":"',
            Strings.toString(p.providerEpoch)
        );
        return string(
            abi.encodePacked(
                first,
                '","policyHash":"',
                Strings.toHexString(uint256(p.policyHash), 32),
                '","contentStateHash":"',
                Strings.toHexString(uint256(p.contentStateHash), 32),
                '","lastActionId":"',
                Strings.toHexString(uint256(p.lastActionId), 32),
                '","artistConsentRecord":"',
                Strings.toHexString(uint256(p.artistConsentRecord), 32),
                '"}'
            )
        );
    }
}
