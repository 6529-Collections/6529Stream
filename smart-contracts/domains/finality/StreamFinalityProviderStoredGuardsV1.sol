// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityNativeProviderReads as Native
} from "./StreamFinalityNativeProviderReads.sol";
import { StreamFinalityRouterEvidence } from "./StreamFinalityRouterEvidence.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import "../../interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @dev Original Router provider guards over constructor-identical immutable configuration.
/// The owning provider never writes this configuration after construction.
library StreamFinalityProviderStoredGuardsV1 {
    error RouterProviderConfiguration();
    error RouterProviderDependency(address target);
    error RouterProviderScope();

    function pins(Native.Config storage c) internal view {
        if (block.chainid != c.chainId) revert RouterProviderConfiguration();
        _pin(c.targets[0], c.codeHashes[0]);
        _pin(c.targets[1], c.codeHashes[1]);
        _pin(c.targets[2], c.codeHashes[2]);
        _pin(c.targets[3], c.codeHashes[3]);
    }

    function scope(Native.Config storage c, StreamFinalityScope memory s) internal view {
        if (
            s.collectionId == 0
                || (s.scopeType == StreamFinalityScopeType.COLLECTION
                        ? s.tokenId != 0 || s.scopeId != 0
                        : s.scopeType == StreamFinalityScopeType.TOKEN
                            ? s.tokenId == 0 || s.scopeId != 0
                            : s.tokenId != 0 || s.scopeId == 0)
        ) revert RouterProviderScope();
        StreamScopeMembershipFacts memory f = abi.decode(
            StreamFinalityRouterEvidence.read(
                c.targets[3],
                abi.encodeWithSignature(
                    "requireScopeMembership((uint8,uint256,uint256,bytes32))", s
                ),
                256,
                c.componentSourceGas
            ),
            (StreamScopeMembershipFacts)
        );
        if (
            f.scopeSubject != StreamMetadataSubjects.scopeSubject(c.chainId, c.targets[0], s)
                || f.membershipHash == 0
        ) revert RouterProviderScope();
    }

    function componentFamily(bytes32 family) internal pure {
        if (!StreamFinalityRouterEvidence.supported(family)) {
            revert StreamFinalityRouterEvidence.RouterEvidenceFamily(family);
        }
    }

    function _pin(address target, bytes32 hash) private view {
        if (target.code.length == 0 || target.codehash != hash) {
            revert RouterProviderDependency(target);
        }
    }
}
