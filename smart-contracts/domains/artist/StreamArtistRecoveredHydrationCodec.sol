// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

/// @notice Canonical, owner-specific recovered transport. No fallback into an older state codec.
/// @dev Each fixed owner additionally decodes payload as its exact typed bundle and verifies
/// canonical re-encoding and semantic inventory. This outer codec is not an authority proof.
library StreamArtistRecoveredHydrationCodec {
    function isState(bytes memory raw, uint8 ownerIndex) internal pure returns (bool) {
        bytes32 tag;
        if (raw.length >= 32) assembly ("memory-safe") { tag := mload(add(raw, 32)) }
        return tag == RH.ownerTag(ownerIndex);
    }

    function encode(uint8 ownerIndex, RH.Envelope memory envelope)
        internal
        pure
        returns (bytes memory)
    {
        _header(ownerIndex, envelope.header);
        return abi.encode(RH.ownerTag(ownerIndex), RH.VERSION, envelope);
    }

    function decode(bytes memory raw, uint8 ownerIndex)
        internal
        pure
        returns (RH.Envelope memory envelope)
    {
        bytes32 tag;
        uint16 version;
        (tag, version, envelope) = abi.decode(raw, (bytes32, uint16, RH.Envelope));
        if (
            tag != RH.ownerTag(ownerIndex) || version != RH.VERSION
                || keccak256(raw) != keccak256(abi.encode(tag, version, envelope))
        ) revert RH.InvalidRecoveredHydrationProfile();
        _header(ownerIndex, envelope.header);
    }

    function requireCapability(RH.Capability memory c, uint8 ownerIndex, uint256 requiredFeatures)
        internal
        pure
    {
        if (
            c.profile != RH.PROFILE || c.version != RH.VERSION || c.ownerIndex != ownerIndex
                || c.ownerDomain != RH.ownerDomain(ownerIndex)
                || c.checkpointSchema != RH.CHECKPOINT || c.stateSchema != RH.ownerTag(ownerIndex)
                || (requiredFeatures & ~RH.KNOWN_FEATURES) != 0
                || (requiredFeatures & c.supportedFeatures) != requiredFeatures
        ) revert RH.InvalidRecoveredHydrationProfile();
    }

    function _header(uint8 ownerIndex, RH.ExportHeader memory h) private pure {
        if (
            h.profile != RH.PROFILE || h.version != RH.VERSION || h.ownerIndex != ownerIndex
                || h.sourceOrigin == 0 || h.semanticInventory == 0 || h.provenanceCommitment == 0
                || h.replayAliasesCommitment == 0 || h.eraCount == 0
                || (h.eraCount == 1 && h.priorImportCommitment != 0)
                || (h.eraCount > 1 && h.priorImportCommitment == 0)
        ) revert RH.InvalidRecoveredHydrationProfile();
    }
}
