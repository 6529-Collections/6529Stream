// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamArtistOnboardingTypes as A
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamArtistArchiveOriginProof as Proof } from "./StreamArtistArchiveOriginProof.sol";
import "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import "../../interfaces/stream/metadata/IStreamConservationRecordSelection.sol";
import "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistAcceptanceOwner.sol";

/// @notice Current authority and original locked presentation remain separate authenticated facts.
/// @dev No new lock, signature validation, accepted-history mutation or original Finality rewrite.
library StreamArtistArchiveOriginLineage {
    function lineage(
        S.Dependencies memory d,
        uint256 collectionId,
        IStreamMetadataServingFacts.ArtistPresentation memory presented,
        IStreamConservationRecordSelection.Association memory association
    ) public view returns (O.Origin memory current, O.Origin memory original, bytes32 lineageHash) {
        (current,) = Proof.currentOrigin(d);
        IO.pin(d.targets[4], d.codeHashes[4]);
        bytes memory raw = IO.fixedRead(
            d.targets[4],
            abi.encodeCall(IStreamMetadataServingFacts.artistPresentation, (collectionId)),
            384,
            d.readGas
        );
        IO.canonical(d.targets[4], raw, abi.encode(presented));
        if (
            collectionId == 0 || !presented.locked || presented.artistId == 0
                || presented.bindingGeneration == 0 || presented.bindingHash == 0
                || presented.identityRecordHash == 0 || presented.acceptanceRecordHash == 0
                || presented.snapshotHash == 0 || presented.nominatedArtist == address(0)
                || presented.artistId != association.artistId
                || presented.bindingGeneration != association.generation
                || presented.bindingHash != association.bindingHash
                || presented.identityRecordHash != association.identityRecordHash
                || presented.snapshotHash != _snapshotHash(d, collectionId, presented)
        ) revert O.InvalidArchiveOrigin();
        original = Proof.ancestorOrigin(d, presented.registry, presented.registryCodeHash);
        _association(d, collectionId, presented, current);
        if (O.originPinHash(current) != O.originPinHash(original)) {
            _association(d, collectionId, presented, original);
        }
        lineageHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ARCHIVE_PRESENTATION_LINEAGE_V1"),
                d.chainId,
                d.targets[0],
                d.targets[4],
                collectionId,
                presented,
                association,
                O.originPinHash(current),
                O.originPinHash(original)
            )
        );
    }

    function _association(
        S.Dependencies memory d,
        uint256 collectionId,
        IStreamMetadataServingFacts.ArtistPresentation memory p,
        O.Origin memory origin
    ) private view {
        address binding = origin.environment.owners[0];
        address acceptance = origin.environment.owners[3];
        IO.pin(binding, origin.environment.ownerCodeHashes[0]);
        IO.pin(acceptance, origin.environment.ownerCodeHashes[3]);
        bytes memory raw = IO.fixedRead(
            binding,
            abi.encodeCall(
                IStreamArtistBindingOwner.bindingAt, (collectionId, p.bindingGeneration)
            ),
            320,
            d.readGas
        );
        A.Binding memory saved = abi.decode(raw, (A.Binding));
        IO.canonical(binding, raw, abi.encode(saved));
        if (
            !saved.accepted || saved.artistId != p.artistId
                || saved.artistAddress != p.nominatedArtist
                || saved.identityRecordHash != p.identityRecordHash
                || saved.bindingHash != p.bindingHash || saved.generation != p.bindingGeneration
                || IO.word(
                        acceptance,
                        abi.encodeCall(
                            IStreamArtistAcceptanceOwner.acceptanceRecord, (p.bindingHash)
                        ),
                        d.readGas
                    ) != p.acceptanceRecordHash
                || IO.word(
                        acceptance,
                        abi.encodeCall(IStreamArtistAcceptanceOwner.acceptedAt, (p.bindingHash)),
                        d.readGas
                    ) != bytes32(uint256(p.acceptedAt))
        ) revert O.InvalidArchiveOrigin();
    }

    function _snapshotHash(
        S.Dependencies memory d,
        uint256 cid,
        IStreamMetadataServingFacts.ArtistPresentation memory p
    ) private pure returns (bytes32) {
        // Byte-exact original Router producer preimage. The Router, not this satellite,
        // occupies address(this)'s original domain position.
        bytes32[15] memory words;
        words[0] = keccak256("6529STREAM_ROUTER_ARTIST_PRESENTATION_V1");
        words[1] = bytes32(d.chainId);
        words[2] = bytes32(uint256(uint160(d.targets[0])));
        words[3] = bytes32(uint256(uint160(d.targets[4])));
        words[4] = bytes32(cid);
        words[5] = bytes32(uint256(uint160(p.registry)));
        words[6] = p.registryCodeHash;
        words[7] = p.artistId;
        words[8] = bytes32(uint256(p.bindingGeneration));
        words[9] = p.bindingHash;
        words[10] = bytes32(uint256(uint160(p.nominatedArtist)));
        words[11] = p.identityRecordHash;
        words[12] = p.acceptanceRecordHash;
        words[13] = bytes32(uint256(p.acceptedAt));
        words[14] = bytes32(uint256(p.lockedAt));
        return keccak256(abi.encode(words));
    }
}
