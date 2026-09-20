// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistCurrentAuthorityTypes as C
} from "../artist/StreamArtistCurrentAuthorityTypes.sol";
import { StreamRenderCriticalSourceTypes as S } from "./StreamRenderCriticalSourceTypes.sol";
import { StreamArtistArchiveOriginTypes as O } from "./StreamArtistArchiveOriginTypes.sol";

/// @notice Additive inventory domains; original record and signing domains are unchanged.
library StreamCurrentAuthorityInventoryTypes {
    bytes32 internal constant INVENTORY_PROFILE =
        keccak256("6529STREAM_CURRENT_AUTHORITY_RENDER_CRITICAL_INVENTORY_V1");
    bytes32 internal constant SCOPED_INVENTORY_PROFILE =
        keccak256("6529STREAM_CURRENT_AUTHORITY_SCOPED_RENDER_CRITICAL_INVENTORY_V1");
    bytes32 internal constant POLICY_INVENTORY_PROFILE =
        keccak256("6529STREAM_CURRENT_AUTHORITY_POLICY_RENDER_CRITICAL_INVENTORY_V2");
    bytes32 internal constant SCOPED_POLICY_INVENTORY_PROFILE =
        keccak256("6529STREAM_CURRENT_AUTHORITY_SCOPED_POLICY_RENDER_CRITICAL_INVENTORY_V2");
    bytes32 internal constant CONTEXT_DOMAIN =
        keccak256("6529STREAM_CURRENT_AUTHORITY_INVENTORY_CONTEXT_V1");

    struct Dependencies {
        address resolver;
        bytes32 resolverCodeHash;
        uint256 resolverGas;
    }

    /// @dev Immutable for each plan, including after later Core selections.
    struct Capture {
        S.Dependencies dependencies;
        C.Selection selection;
    }

    function dependencyHash(
        bytes32 profile,
        S.Dependencies memory anchor,
        O.Dependencies memory origin,
        Dependencies memory authority
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(profile, anchor, origin, authority));
    }

    function contextHash(Capture memory capture, bytes32 typedContextHash, bytes32 lineageHash)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                CONTEXT_DOMAIN,
                capture.selection.selectionHash,
                keccak256(abi.encode(capture.dependencies)),
                typedContextHash,
                lineageHash
            )
        );
    }

    function planId(bytes32 profile, bytes32 dependenciesHash, bytes32 sourceContextHash)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(profile, block.chainid, address(this), dependenciesHash, sourceContextHash)
        );
    }
}
