// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamViewAdoptionTypes as V
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import "../../interfaces/stream/finality/IStreamViewSourceBinding.sol";
import {
    IStreamViewAdoptionRouter as ViewRouter
} from "../../interfaces/stream/metadata/IStreamViewAdoptionRouter.sol";
import { StreamViewPayloadBytes as ViewBytes } from "../metadata/StreamViewPayloadBytes.sol";
import "../../interfaces/stream/finality/IStreamFinalityDeploymentBindings.sol";
import "../../interfaces/stream/finality/IStreamFinalityEvidenceProvider.sol";
import "../../interfaces/stream/finality/IStreamFinalityScopeMembership.sol";
import "../../interfaces/stream/artist/IStreamArtistFinalityBinding.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/metadata/IStreamCollectionViews.sol";
import "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import "../../interfaces/stream/modules/IStreamModuleRegistry.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";

import { StreamViewAdoptionReads as Read } from "../metadata/StreamViewAdoptionReads.sol";
import {
    StreamViewAdoptionDocuments as Documents
} from "../metadata/StreamViewAdoptionDocuments.sol";
import { StreamMetadataSubjects as Subjects } from "../metadata/StreamMetadataSubjects.sol";
import {
    IStreamCoreCollectionView as Collection
} from "../../interfaces/stream/core/IStreamCoreCollectionView.sol";

/// @notice Fixed current-source interpreter for the original adopted VIEW V1 profile.
/// @dev The consuming host pins this complete configuration. No supplied projection becomes
/// finality authority. Historical carrier authentication is separate from current eligibility;
/// current reads deliberately do not reuse mutation-only freeze or writer predicates.
library StreamFinalityViewSourceReads {
    struct Dependencies {
        // Core, original Router, Artist, original Finality, provider, generic Metadata, authority.
        address[7] targets;
        bytes32[7] codeHashes;
        uint256 chainId;
        uint32 readGas;
        V.Binding binding;
    }

    function validateDependencies(Dependencies memory d) public view {
        _pins(d);
        _route(d);
    }

    /// @notice Authenticate the immutable original carrier and preimages only.
    /// @dev This does not assert live selected source, current head, finality or rendering readiness.
    function retained(Dependencies memory d, bytes32 key) public view returns (V.Record memory r) {
        if (d.chainId != block.chainid || d.readGas < 50000 || key == 0) {
            revert V.InvalidViewAdoption();
        }
        Read.pin(d.targets[0], d.codeHashes[0]);
        Read.pin(d.targets[1], d.codeHashes[1]);
        return _record(d, key);
    }

    function requireCurrent(Dependencies memory d, StreamFinalityScope memory scope)
        public
        view
        returns (V.Record memory r)
    {
        _pins(d);
        if (scope.scopeType != StreamFinalityScopeType.VIEW) revert V.InvalidViewAdoption();
        bytes32 subject = Subjects.scopeSubject(d.chainId, d.targets[0], scope);
        bytes32 key = bytes32(
            Read.word(d.targets[1], abi.encodeCall(ViewRouter.viewAdoptionHead, (scope)), d.readGas)
        );
        r = _record(d, key);
        if (keccak256(abi.encode(r.input.scope)) != keccak256(abi.encode(scope))) {
            revert V.InvalidViewAdoption();
        }
        V.Route memory route = _route(d);
        if (keccak256(abi.encode(route)) != keccak256(abi.encode(r.source.route))) {
            revert V.InvalidViewAdoption();
        }
        if (
            Read.word(
                    d.targets[0],
                    abi.encodeCall(Collection.collectionExists, (scope.collectionId)),
                    d.readGas
                ) != 1
        ) revert V.InvalidViewAdoption();
        V.Source memory current = Documents.load(route, r.input, d.targets[6]);
        bytes memory raw = Read.read(
            route.binding.membership,
            abi.encodeCall(IStreamFinalityScopeMembership.requireScopeMembership, (scope)),
            256,
            route.binding.sourceGas
        );
        current.membership = abi.decode(raw, (StreamScopeMembershipFacts));
        if (
            keccak256(raw) != keccak256(abi.encode(current.membership))
                || current.membership.scopeSubject != subject
                || keccak256(abi.encode(current)) != keccak256(abi.encode(r.source))
        ) revert V.InvalidViewAdoption();
        // Whole-source equality covers exact immutable payload pointers/hashes/length, original
        // declaration receipt/schema bytes, governed renderer/version/read set and all members.
        // No collection freeze prerequisite: a VIEW may finalize within an open collection.
    }

    function _record(Dependencies memory d, bytes32 key) private view returns (V.Record memory r) {
        bytes memory raw = Read.recordBytes(d.targets[1], key, d.readGas);
        r = abi.decode(raw, (V.Record));
        if (
            keccak256(raw) != keccak256(abi.encode(r)) || r.recordHash != key || r.revision == 0
                || r.actor == address(0) || (r.authorizationClass != 7 && r.authorizationClass != 8)
                || (r.grantCollectionId != 0 && r.grantCollectionId != r.input.scope.collectionId)
                || r.grantRevision == 0 || r.artistConsent == 0 || r.adoptedAt == 0
                || r.adoptedAt > block.timestamp || r.aggregate.revision == 0
                || r.aggregate.transitionChain == 0
                || r.input.scope.scopeType != StreamFinalityScopeType.VIEW || r.input.viewId == 0
                || r.input.viewRecordHash == 0 || r.input.rendererVersionKey == 0
                || r.source.route.core != d.targets[0]
                || r.source.route.coreCodeHash != d.codeHashes[0]
                || r.source.route.router != d.targets[1]
                || r.source.route.routerCodeHash != d.codeHashes[1]
                || r.source.renderer.contextVersion != V.CONTEXT
        ) revert V.InvalidViewAdoption();
        bytes32 subject = Subjects.scopeSubject(d.chainId, d.targets[0], r.input.scope);
        StreamScopeMembershipFacts memory m = r.source.membership;
        if (
            m.scopeSubject != subject || m.scopeManifestHash == 0 || m.sourceRecordHash == 0
                || m.tokenListHash == 0 || m.membershipHash == 0 || m.inventoryCount != 0
                || m.inventoryPrefixHash != 0
        ) revert V.InvalidViewAdoption();
        bytes32 sourceHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_ADOPTION_SOURCE_V1"),
                d.chainId,
                d.targets[1],
                r.input.scope,
                r.input.viewId,
                r.input.viewRecordHash,
                r.source
            )
        );
        if (sourceHash != r.sourceHash || sourceHash != r.input.expectedSourceHash) {
            revert V.InvalidViewAdoption();
        }
        r.recordHash = 0;
        bytes32 original = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_ADOPTION_RECORD_V1"),
                d.chainId,
                d.targets[1],
                d.targets[0],
                r
            )
        );
        r.recordHash = key;
        if (original != key) revert V.InvalidViewAdoption();
    }

    function _pins(Dependencies memory d) private view {
        if (
            d.chainId != block.chainid || d.readGas < 50000 || d.binding.readGas < 50000
                || d.binding.sourceGas < d.binding.readGas
        ) revert V.InvalidViewAdoption();
        for (uint256 i; i < 7; ++i) {
            Read.pin(d.targets[i], d.codeHashes[i]);
        }
        Read.pin(d.binding.views, d.binding.viewsCodeHash);
        Read.pin(d.binding.membership, d.binding.membershipCodeHash);
    }

    function _route(Dependencies memory d) private view returns (V.Route memory r) {
        address core = d.targets[0];
        address artist = d.targets[2];
        address authority = d.targets[6];
        (address selectedArtist, bytes32 selectedArtistHash) =
            Read.selected(core, keccak256("ARTIST_REGISTRY"), d.readGas);
        if (selectedArtist != artist || selectedArtistHash != d.codeHashes[2]) {
            revert V.InvalidViewAdoption();
        }
        r.core = core;
        r.coreCodeHash = core.codehash;
        r.router = d.targets[1];
        r.routerCodeHash = d.targets[1].codehash;
        r.artist = artist;
        r.artistCodeHash = artist.codehash;
        (r.finality, r.finalityCodeHash) =
            Read.selected(core, keccak256("ARTWORK_FINALITY_REGISTRY"), 100000);
        if (
            Read.addr(
                        artist,
                        abi.encodeCall(IStreamArtistFinalityBinding.finalityRegistry, ()),
                        100000
                    ) != r.finality
                || bytes32(
                        Read.word(
                            artist,
                            abi.encodeCall(
                                IStreamArtistFinalityBinding.finalityRegistryCodeHash, ()
                            ),
                            100000
                        )
                    ) != r.finalityCodeHash
        ) {
            revert V.ViewAdoptionDependency(artist);
        }
        uint256 cap = Read.word(
            r.finality,
            abi.encodeCall(
                IStreamGasParameterHost.gasParameter,
                (keccak256("6529STREAM_GGP_FINALITY_COMPONENT_READ_GAS"))
            ),
            100000
        );
        if (cap < 50000 || cap > type(uint32).max) revert V.InvalidViewAdoption();
        (address router, bytes32 routerHash) =
            Read.selected(core, keccak256("METADATA_ROUTER"), cap);
        if (
            router != d.targets[1] || routerHash != d.targets[1].codehash
                || Read.addr(
                        r.finality,
                        abi.encodeCall(IStreamFinalityDeploymentBindings.coreReads, ()),
                        cap
                    ) != core
                || Read.addr(
                        r.finality,
                        abi.encodeCall(IStreamFinalityDeploymentBindings.sanctionReads, ()),
                        cap
                    ) != artist
        ) {
            revert V.InvalidViewAdoption();
        }
        r.provider = Read.addr(
            r.finality,
            abi.encodeCall(IStreamFinalityDeploymentBindings.scopeEvidenceProvider, ()),
            cap
        );
        r.providerCodeHash = bytes32(
            Read.word(
                r.finality,
                abi.encodeCall(IStreamFinalityDeploymentBindings.scopeEvidenceProviderCodeHash, ()),
                cap
            )
        );
        Read.pin(r.provider, r.providerCodeHash);
        if (
            Read.word(
                    r.provider,
                    abi.encodeCall(
                        IERC165.supportsInterface, (type(IStreamViewSourceBinding).interfaceId)
                    ),
                    cap
                ) != 1
        ) {
            revert V.ViewAdoptionDependency(r.provider);
        }
        bytes memory raw = Read.read(
            r.provider, abi.encodeCall(IStreamViewSourceBinding.viewSourceBinding, ()), 192, cap
        );
        r.binding = abi.decode(raw, (V.Binding));
        if (
            keccak256(raw) != keccak256(abi.encode(r.binding)) || r.binding.readGas < 50000
                || r.binding.sourceGas < r.binding.readGas
        ) {
            revert V.InvalidViewAdoption();
        }
        Read.pin(r.binding.views, r.binding.viewsCodeHash);
        Read.pin(r.binding.membership, r.binding.membershipCodeHash);
        (r.metadata, r.metadataCodeHash) =
            Read.selected(core, keccak256("COLLECTION_METADATA"), cap);
        if (
            Read.addr(
                        r.finality,
                        abi.encodeCall(IStreamFinalityDeploymentBindings.metadataReads, ()),
                        cap
                    ) != r.metadata
                || Read.addr(
                        r.provider,
                        abi.encodeCall(IStreamFinalityEvidenceProvider.metadataHost, ()),
                        cap
                    ) != r.metadata
                || Read.addr(
                        r.metadata,
                        abi.encodeCall(IStreamGasParameterHost.governanceAuthority, ()),
                        cap
                    ) != authority
        ) {
            revert V.ViewAdoptionDependency(r.metadata);
        }
        r.schemas = Read.addr(
            r.metadata, abi.encodeCall(IStreamCollectionMetadataV1.schemaRegistry, ()), cap
        );
        r.schemasCodeHash = r.schemas.codehash;
        r.store = Read.addr(r.metadata, abi.encodeWithSignature("chunkStore()"), cap);
        r.storeCodeHash = r.store.codehash;
        Read.pin(r.schemas, r.schemasCodeHash);
        Read.pin(r.store, r.storeCodeHash);
        if (
            Read.addr(r.binding.views, abi.encodeCall(IStreamCollectionViews.core, ()), cap) != core
                || Read.addr(
                        r.binding.views,
                        abi.encodeCall(IStreamCollectionViews.metadataHost, ()),
                        cap
                    ) != r.metadata
                || Read.addr(
                        r.binding.views,
                        abi.encodeCall(IStreamCollectionViews.schemaRegistry, ()),
                        cap
                    ) != r.schemas
                || Read.addr(
                        r.binding.views, abi.encodeCall(IStreamCollectionViews.chunkStore, ()), cap
                    ) != r.store
                || Read.addr(
                        r.binding.membership,
                        abi.encodeCall(IStreamFinalityScopeMembership.core, ()),
                        cap
                    ) != core
                || Read.addr(
                        r.binding.membership,
                        abi.encodeCall(IStreamFinalityScopeMembership.metadataHost, ()),
                        cap
                    ) != r.metadata
        ) {
            revert V.InvalidViewAdoption();
        }
        (address modules,) = Read.selected(core, keccak256("MODULE_REGISTRY"), cap);
        Read.eligible(
            modules,
            r.metadata,
            keccak256("COLLECTION_METADATA"),
            type(IStreamCollectionMetadataV1).interfaceId,
            cap
        );
        Read.eligible(
            modules,
            r.binding.views,
            keccak256("COLLECTION_VIEWS"),
            type(IStreamCollectionViews).interfaceId,
            cap
        );

        if (
            r.finality != d.targets[3] || r.finalityCodeHash != d.codeHashes[3]
                || r.provider != d.targets[4] || r.providerCodeHash != d.codeHashes[4]
                || r.metadata != d.targets[5] || r.metadataCodeHash != d.codeHashes[5]
                || keccak256(abi.encode(r.binding)) != keccak256(abi.encode(d.binding))
        ) revert V.InvalidViewAdoption();
    }
}
