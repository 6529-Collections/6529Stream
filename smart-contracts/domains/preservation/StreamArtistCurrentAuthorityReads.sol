// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistCurrentAuthorityTypes as C
} from "../../interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamArtistOnboardingTypes as A
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamRecordArtistIdentityReads as Identity
} from "../records/StreamRecordArtistIdentityReads.sol";
import {
    StreamArtistArchiveOriginEnvironment as Environment
} from "./StreamArtistArchiveOriginEnvironment.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistAuthorityHydrationOwner
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import { IStreamCorePointers } from "../../interfaces/stream/core/IStreamCorePointers.sol";
import {
    IStreamFinalityCurrentAuthority
} from "../../interfaces/stream/finality/IStreamFinalityCurrentAuthority.sol";
import {
    IStreamFinalityDeploymentBindings
} from "../../interfaces/stream/finality/IStreamFinalityDeploymentBindings.sol";
import {
    IStreamFinalityScopeEvidence
} from "../../interfaces/stream/finality/IStreamFinalityScopeEvidence.sol";
import {
    IStreamFinalityEvidenceProvider
} from "../../interfaces/stream/finality/IStreamFinalityEvidenceProvider.sol";
import {
    IStreamFinalityArtifactCoverage
} from "../../interfaces/stream/preservation/IStreamFinalityArtifactCoverage.sol";
import {
    IStreamMetadataServingFacts
} from "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    IStreamArtistBindingOwner
} from "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistAcceptanceOwner
} from "../../interfaces/stream/artist/IStreamArtistAcceptanceOwner.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

/// @notice Original deployment and live authority joins, with no dynamic Finality callback.
library StreamArtistCurrentAuthorityReads {
    function selection(C.Anchors memory a) public view returns (C.Selection memory result) {
        if (a.chainId != block.chainid) revert C.InvalidCurrentAuthority();
        for (uint256 i; i < 5; ++i) {
            IO.pin(a.targets[i], a.codeHashes[i]);
        }
        _selected(a, keccak256("COLLECTION_METADATA"), a.targets[1], a.codeHashes[1]);
        _selected(a, keccak256("METADATA_ROUTER"), a.targets[2], a.codeHashes[2]);
        if (
            IO.addressWord(
                        a.targets[1],
                        abi.encodeCall(IStreamArtistOwner.artistRegistry, ()),
                        a.readGas
                    ) != a.targets[3]
                || IO.word(
                        a.targets[1], abi.encodeWithSignature("artistRegistryCodeHash()"), a.readGas
                    ) != a.codeHashes[3]
                || IO.addressWord(
                        a.targets[1], abi.encodeCall(IStreamArtistOwner.core, ()), a.readGas
                    ) != a.targets[0]
        ) {
            revert C.InvalidCurrentAuthority();
        }
        // Existing resolver proves original Metadata ancestry, all imported-era certificates
        // and complete current seven-owner authority before returning the selected registry.
        Identity.Pins memory pins =
            Identity.resolveCurrent(a.targets[1], a.targets[0], a.chainId, a.readGas);
        S.Dependencies memory d = _frame(a);
        A.SuiteConfiguration memory current;
        (result.origin, current) = Environment.configured(d, pins.targets[0], pins.codeHashes[0]);
        (, A.SuiteConfiguration memory original) =
            Environment.configured(d, a.targets[3], a.codeHashes[3]);
        Environment.sameDependencies(current, original);
        if (
            result.origin.environment.coordinator != pins.targets[1]
                || result.origin.coordinatorCodeHash != pins.codeHashes[1]
                || current.owners[2] != pins.targets[2]
                || result.origin.environment.ownerCodeHashes[2] != pins.codeHashes[2]
        ) revert C.InvalidCurrentAuthority();
        for (uint256 i; i < 7; ++i) {
            bytes32 completion = IO.word(
                current.owners[i],
                abi.encodeCall(
                    IStreamArtistAuthorityHydrationOwner.authorityHydrationCommitment, ()
                ),
                a.readGas
            );
            if (i != 0 && completion != result.completion) revert C.InvalidCurrentAuthority();
            result.completion = completion;
        }
        if (current.registry != a.targets[3] && result.completion == 0) {
            revert C.InvalidCurrentAuthority();
        }
        result.selectionHash = C.hashSelection(a, result.origin, result.completion);
    }

    function route(C.Anchors memory a, uint256 collectionId)
        public
        view
        returns (C.Route memory r)
    {
        C.Selection memory selected = selection(a);
        address finality = a.finalityRegistry;
        IO.pin(finality, finality.codehash);
        _selected(a, keccak256("ARTWORK_FINALITY_REGISTRY"), finality, finality.codehash);
        _interface(finality, type(IStreamFinalityCurrentAuthority).interfaceId, a.readGas);
        if (
            IO.word(
                        finality,
                        abi.encodeCall(IStreamFinalityCurrentAuthority.currentAuthorityProfile, ()),
                        a.readGas
                    ) != C.PROFILE
                || IO.addressWord(
                        finality,
                        abi.encodeCall(
                            IStreamFinalityCurrentAuthority.currentAuthorityResolver, ()
                        ),
                        a.readGas
                    ) != address(this)
                || IO.word(
                        finality,
                        abi.encodeCall(
                            IStreamFinalityCurrentAuthority.currentAuthorityResolverCodeHash, ()
                        ),
                        a.readGas
                    ) != address(this).codehash
                || IO.addressWord(
                        finality,
                        abi.encodeCall(IStreamFinalityDeploymentBindings.coreReads, ()),
                        a.readGas
                    ) != a.targets[0]
                || IO.addressWord(
                        finality,
                        abi.encodeCall(IStreamFinalityDeploymentBindings.metadataReads, ()),
                        a.readGas
                    ) != a.targets[1]
                || IO.addressWord(
                        finality,
                        abi.encodeCall(IStreamFinalityDeploymentBindings.sanctionReads, ()),
                        a.readGas
                    ) != a.targets[3]
                || IO.addressWord(
                        finality,
                        abi.encodeCall(IStreamFinalityDeploymentBindings.scopeEvidenceProvider, ()),
                        a.readGas
                    ) != a.targets[4]
                || IO.word(
                        finality,
                        abi.encodeCall(
                            IStreamFinalityDeploymentBindings.scopeEvidenceProviderCodeHash, ()
                        ),
                        a.readGas
                    ) != a.codeHashes[4]
                || IO.addressWord(
                        a.targets[4],
                        abi.encodeCall(IStreamFinalityScopeEvidence.core, ()),
                        a.readGas
                    ) != a.targets[0]
                || IO.addressWord(
                        a.targets[4],
                        abi.encodeCall(IStreamFinalityEvidenceProvider.metadataHost, ()),
                        a.readGas
                    ) != a.targets[1]
        ) revert C.InvalidCurrentAuthority();
        address artifact = IO.addressWord(
            finality,
            abi.encodeCall(IStreamFinalityDeploymentBindings.artifactCoverage, ()),
            a.readGas
        );
        if (
            IO.addressWord(
                        artifact,
                        abi.encodeCall(IStreamFinalityArtifactCoverage.core, ()),
                        a.readGas
                    ) != a.targets[0]
                || IO.addressWord(
                        artifact,
                        abi.encodeCall(IStreamFinalityArtifactCoverage.finalityRegistry, ()),
                        a.readGas
                    ) != finality
        ) revert C.InvalidCurrentAuthority();
        bytes memory raw = IO.fixedRead(
            a.targets[2],
            abi.encodeWithSignature("originalFinalityAnchor(uint256)", collectionId),
            64,
            a.readGas
        );
        (address anchor, bytes32 anchorHash) = abi.decode(raw, (address, bytes32));
        IO.canonical(a.targets[2], raw, abi.encode(anchor, anchorHash));
        if (anchor != finality || anchorHash != finality.codehash) {
            revert C.InvalidCurrentAuthority();
        }
        raw = IO.fixedRead(
            a.targets[2],
            abi.encodeCall(IStreamMetadataServingFacts.artistPresentation, (collectionId)),
            384,
            a.readGas
        );
        IStreamMetadataServingFacts.ArtistPresentation memory p =
            abi.decode(raw, (IStreamMetadataServingFacts.ArtistPresentation));
        IO.canonical(a.targets[2], raw, abi.encode(p));
        if (
            collectionId == 0 || !p.locked || p.registry != a.targets[3]
                || p.registryCodeHash != a.codeHashes[3] || p.artistId == 0
                || p.bindingGeneration == 0 || p.bindingHash == 0 || p.identityRecordHash == 0
                || p.acceptanceRecordHash == 0 || p.nominatedArtist == address(0)
                || p.snapshotHash != _snapshotHash(a, collectionId, p)
        ) revert C.InvalidCurrentAuthority();
        (O.Origin memory original,) =
            Environment.configured(_frame(a), a.targets[3], a.codeHashes[3]);
        _association(a, collectionId, p, original);
        if (O.originPinHash(original) != O.originPinHash(selected.origin)) {
            _association(a, collectionId, p, selected.origin);
        }
        r = C.Route(
            finality,
            finality.codehash,
            a.targets[4],
            a.codeHashes[4],
            selected.origin.environment.registry,
            selected.origin.registryCodeHash,
            selected.origin.environment.coordinator,
            selected.origin.coordinatorCodeHash,
            selected.selectionHash,
            p.snapshotHash
        );
    }

    function _frame(C.Anchors memory a) private pure returns (S.Dependencies memory d) {
        // Only configured() consumes this frame; it never claims a complete inventory environment.
        d.targets[0] = a.targets[0];
        d.targets[1] = a.targets[1];
        d.targets[4] = a.targets[2];
        d.codeHashes[0] = a.codeHashes[0];
        d.codeHashes[1] = a.codeHashes[1];
        d.codeHashes[4] = a.codeHashes[2];
        d.chainId = a.chainId;
        d.readGas = a.readGas;
    }

    function _selected(C.Anchors memory a, bytes32 key, address expected, bytes32 hash)
        private
        view
    {
        bytes memory raw = IO.fixedRead(
            a.targets[0],
            abi.encodeCall(IStreamCorePointers.getSatellitePointer, (key)),
            320,
            a.readGas
        );
        uint256 word;
        bytes32 actualHash;
        assembly ("memory-safe") {
            word := mload(add(raw, 32))
            actualHash := mload(add(raw, 64))
        }
        if (word > type(uint160).max || address(uint160(word)) != expected || actualHash != hash) {
            revert C.InvalidCurrentAuthority();
        }
        IO.pin(expected, hash);
    }

    function _interface(address target, bytes4 id, uint256 cap) private view {
        if (
            IO.word(target, abi.encodeCall(IERC165.supportsInterface, (bytes4(0x01ffc9a7))), cap)
                    != bytes32(uint256(1))
                || IO.word(target, abi.encodeCall(IERC165.supportsInterface, (id)), cap)
                    != bytes32(uint256(1))
                || IO.word(
                        target, abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))), cap
                    ) != 0
        ) revert C.InvalidCurrentAuthority();
    }

    function _association(
        C.Anchors memory a,
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
            a.readGas
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
                        a.readGas
                    ) != p.acceptanceRecordHash
                || IO.word(
                        acceptance,
                        abi.encodeCall(IStreamArtistAcceptanceOwner.acceptedAt, (p.bindingHash)),
                        a.readGas
                    ) != bytes32(uint256(p.acceptedAt))
        ) revert C.InvalidCurrentAuthority();
    }

    function _snapshotHash(
        C.Anchors memory a,
        uint256 cid,
        IStreamMetadataServingFacts.ArtistPresentation memory p
    ) private pure returns (bytes32) {
        bytes32[15] memory words;
        words[0] = keccak256("6529STREAM_ROUTER_ARTIST_PRESENTATION_V1");
        words[1] = bytes32(a.chainId);
        words[2] = bytes32(uint256(uint160(a.targets[0])));
        words[3] = bytes32(uint256(uint160(a.targets[2])));
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
