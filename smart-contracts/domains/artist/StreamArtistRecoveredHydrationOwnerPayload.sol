// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistExtendedHydrationFeatures as XF
} from "../../interfaces/stream/artist/StreamArtistExtendedHydrationFeatures.sol";
import {
    StreamArtistRecoveredPayloadHydration as Publications
} from "./StreamArtistRecoveredPayloadHydration.sol";

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    StreamArtistRecoveredHydrationCodec as Codec
} from "./StreamArtistRecoveredHydrationCodec.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";

/// @notice Canonical operation60 payload for one fixed semantic owner.
/// @dev The Coordinator authenticates the complete source before guarded destination apply.
/// Decoding makes no external call and does not infer authority from nonce words or rolling roots.
/// The fixed owner additionally decodes semanticState as its exact admitted typed state.
library StreamArtistRecoveredHydrationOwnerPayload {
    bytes32 internal constant SCHEMA = keccak256("6529STREAM_ARTIST_RECOVERED_OWNER_PAYLOAD_V1");

    struct Payload {
        RH.OwnerProvenance provenance;
        RH.NonceInventory[] nonces;
        bytes semanticState;
        Publications.Row[] publications;
    }

    function encode(uint8 ownerIndex, RH.ExportHeader memory header, Payload memory payload)
        public
        pure
        returns (bytes memory)
    {
        validate(ownerIndex, header, payload);
        return
            Codec.encode(ownerIndex, RH.Envelope(header, abi.encode(SCHEMA, RH.VERSION, payload)));
    }

    function decode(bytes memory raw, uint8 ownerIndex)
        public
        pure
        returns (RH.ExportHeader memory header, Payload memory payload)
    {
        RH.Envelope memory envelope = Codec.decode(raw, ownerIndex);
        bytes32 schema;
        uint16 version;
        (schema, version, payload) = abi.decode(envelope.payload, (bytes32, uint16, Payload));
        if (
            schema != SCHEMA || version != RH.VERSION
                || keccak256(envelope.payload) != keccak256(abi.encode(schema, version, payload))
        ) revert RH.InvalidRecoveredHydrationProfile();
        header = envelope.header;
        validate(ownerIndex, header, payload);
    }

    /// @notice Exact full validation with only the fields consumed by destination apply returned.
    /// @dev The original decoder and all nonce/semantic/catalog checks run before projection.
    function decodeForApply(bytes memory raw, uint8 ownerIndex)
        public
        pure
        returns (RH.OwnerProvenance memory provenance, Publications.Row[] memory publications)
    {
        (, Payload memory payload) = decode(raw, ownerIndex);
        return (payload.provenance, payload.publications);
    }

    /// @notice Pure consistency check of this owner slice, header, typed-state hash and nonce shape.
    /// @dev semanticRecordCount counts ALL original native occurrences in this owner's journal,
    /// including primary/secondary35 rows. Auxiliary records are committed inside semanticState;
    /// this native count must not be represented as a count of all semantic or auxiliary records.
    function validate(uint8 ownerIndex, RH.ExportHeader memory header, Payload memory payload)
        public
        pure
        returns (bytes32)
    {
        bytes32 provenanceCommitment = Provenance.validateOwner(payload.provenance, ownerIndex);
        uint256 last = payload.provenance.eras.length - 1;
        RH.OwnerEra memory era = payload.provenance.eras[last];
        if (
            header.profile != RH.PROFILE || header.version != RH.VERSION
                || header.ownerIndex != ownerIndex || header.sourceOrigin != era.originHash
                || header.priorImportCommitment != era.priorImportCommitment
                || header.provenanceCommitment != provenanceCommitment
                || header.replayAliasesCommitment
                    != RH.aliasesHash(ownerIndex, payload.provenance.aliases)
                || header.replayAliasCount != payload.provenance.aliases.length
                || header.eraCount != payload.provenance.eras.length
                || header.semanticRecordCount != payload.provenance.journal.length
                || payload.semanticState.length == 0
                || header.semanticInventory != keccak256(payload.semanticState)
                || (header.requiredFeatures & ~XF.KNOWN_FEATURES) != 0
                || (last != 0 && (header.requiredFeatures & RH.REPEATED_IMPORT) == 0)
        ) revert RH.InvalidRecoveredHydrationProfile();
        validateNonceShape(era.checkpoint, payload.nonces);
        Publications.validateShape(ownerIndex, payload.publications);
        return keccak256(abi.encode(SCHEMA, RH.VERSION, ownerIndex, header, payload));
    }

    /// @notice Optional source-phase check against actual fixed-owner nonce getters.
    /// @dev Guard collection already performs this check. Destination decode never calls it.
    function validateSourceNonces(uint8 ownerIndex, Payload memory payload)
        public
        view
        returns (bytes32)
    {
        if (ownerIndex >= 7 || payload.provenance.eras.length == 0) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        uint256 last = payload.provenance.eras.length - 1;
        if (payload.provenance.origins.length != last + 1) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        address source = payload.provenance.origins[last].owners[ownerIndex];
        Provenance.validateOwnerSource(payload.provenance, ownerIndex, source);
        validateNonceShape(payload.provenance.eras[last].checkpoint, payload.nonces);
        return Provenance.validateNonces(
            source, payload.provenance.eras[last].checkpoint, payload.nonces
        );
    }

    /// @dev Shape is necessary but not sufficient evidence for an original nonce tree. Arrays have
    /// exactly32 typed leaf/ancestor words; actual source getters authenticate every unchanged word.
    /// Each index denotes one tree, so its exhaustion flag is identical at every indexed prefix.
    function validateNonceShape(CP.Checkpoint memory expected, RH.NonceInventory[] memory nonces)
        public
        pure
    {
        if (
            expected.schema != RH.CHECKPOINT || nonces.length > RH.MAX_NONCE_INDICES
                || nonces.length != expected.nonceIndexCount
        ) revert RH.InvalidRecoveredHydrationProvenance();
        for (uint256 i; i < nonces.length; ++i) {
            CP.NonceIndex memory index = nonces[i].index;
            if (
                index.kind == 0 || index.kind > 5 || index.key == 0 || index.prefixCount == 0
                    || index.prefixCount > RH.MAX_NONCE_PREFIXES
                    || index.prefixCount != nonces[i].words.length
            ) revert RH.InvalidRecoveredHydrationProvenance();
            for (uint256 prior; prior < i; ++prior) {
                if (nonces[prior].index.kind == index.kind && nonces[prior].index.key == index.key)
                {
                    revert RH.InvalidRecoveredHydrationProvenance();
                }
            }
            for (uint256 j; j < nonces[i].words.length; ++j) {
                if (nonces[i].words[j].exhausted != nonces[i].words[0].exhausted) {
                    revert RH.InvalidRecoveredHydrationProvenance();
                }
                for (uint256 prior; prior < j; ++prior) {
                    if (nonces[i].words[prior].prefix == nonces[i].words[j].prefix) {
                        revert RH.InvalidRecoveredHydrationProvenance();
                    }
                }
            }
        }
    }
}
