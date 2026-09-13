// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./RecoveryCompanionBoundaryFixture.sol";
import "./MetadataRecoveryServingBoundaries.sol";
import {
    StreamMetadataRouter
} from "../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistContentRatification.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionState.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistContentAuthority.sol";
import {
    StreamArtistContentTypes
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import "../../smart-contracts/domains/finality/StreamArtworkFinalityRegistry.sol";
import "../../smart-contracts/domains/finality/StreamCoreFinalityAdapter.sol";
import "../../smart-contracts/domains/finality/StreamFinalityServingHostAdapter.sol";
import "../../smart-contracts/interfaces/stream/finality/IStreamArtistSanctionArchiveFacts.sol";
import "../../smart-contracts/interfaces/stream/governance/IStreamGovernanceReads.sol";

/// @dev Explicit archive admission boundary; the fixture fixes its predicted CREATE2 Registry.
/// It supplies no real archival proof.
contract ServingArtifactAdmissionBoundary is CompanionDependencyBoundary {
    address private registry;

    function bind(address r) external {
        require(registry == address(0));
        registry = r;
    }

    function finalityRegistry() external view returns (address) {
        return registry;
    }
}

/// @dev Actual raw Router bytes/locks are composed here. Record, content-root and discovery
/// authority remain fixture boundaries; this is not the root-owned authoritative provider.
contract RouterCompositionProviderBoundary {
    address public immutable core;
    address public immutable metadataHost;
    address public immutable router;
    address public immutable entropy;
    StreamFinalityComponentExpectation[] private entries;

    constructor(address c, address m, address r, address e) {
        core = c;
        metadataHost = m;
        router = r;
        entropy = e;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamFinalityServingEvidenceProvider).interfaceId;
    }

    function componentHost(bytes32 kind) external view returns (address) {
        return kind == keccak256("ENTROPY_COORDINATOR") ? entropy : router;
    }

    function scopeEvidenceProvider() external view returns (address) {
        return address(this);
    }

    function collectionMetadataMode(uint256) external pure returns (uint8) {
        return 1;
    }

    function tokenContentRoot(uint256, bytes32) external pure returns (bytes32, uint64, bytes32) {
        return (keccak256("content-root-boundary"), 1, keccak256("root-schema-boundary"));
    }

    function latestCollectionSnapshotHash(uint256) external pure returns (bytes32) {
        return keccak256("snapshot-boundary");
    }

    function collectionRecordTypeLocked(uint256, bytes32) external pure returns (bool) {
        return true;
    }

    function scopeManifest(uint256, bytes32) external pure returns (bool, bytes32) {
        return (false, 0);
    }

    function requireFinalityScopeInputs(StreamFinalityScope calldata, bytes32)
        external
        pure
        returns (StreamFinalityScopeInputs memory a, bytes32, bytes32)
    {
        a = StreamFinalityScopeInputs(
            keccak256("root"),
            keccak256("snapshot"),
            keccak256("reference"),
            keccak256("intent"),
            0,
            keccak256("interview"),
            keccak256("rights"),
            keccak256("description"),
            keccak256("render"),
            keccak256("coverage")
        );
        return (
            a,
            keccak256("manifest-schema-boundary"),
            keccak256("manifest-canonicalization-boundary")
        );
    }

    function setEntries(StreamFinalityComponentExpectation[] calldata a) external {
        delete entries;
        for (uint256 i; i < a.length; ++i) {
            entries.push(a[i]);
        }
    }

    function finalityComponentCount(uint256) external view returns (uint256) {
        return entries.length;
    }

    function finalityDiscoveryHash(uint256) external view returns (bytes32) {
        return keccak256(abi.encode(StreamFinalityDomains.STREAM_FINALITY_COMPONENTS_V1, entries));
    }

    function finalityComponentAt(uint256, uint256 i)
        external
        view
        returns (StreamFinalityComponentExpectation memory)
    {
        return entries[i];
    }

    function finalityComponentFacts(bytes32 kind, StreamFinalityScope calldata scope)
        external
        view
        returns (StreamFinalityHostComponentFacts memory f)
    {
        require(scope.collectionId == 1, "fixture scope");
        IStreamMetadataServingFacts.ServingFacts memory a =
            IStreamMetadataServingFacts(router).collectionServingFacts(1);
        bytes32 h;
        bool locked;
        if (kind == keccak256("METADATA_ROUTER")) {
            IStreamMetadataServingFacts.ServingSource memory s =
                IStreamMetadataServingFacts(router).collectionServingSource(1);
            h = keccak256(
                abi.encode(
                    s.name, s.description, IStreamMetadataServingFacts(router).artistPresentation(1)
                )
            );
            locked = a.displayMetadataLocked && a.artistIdentityLocked;
        } else if (kind == keccak256("MEDIA_MANIFEST")) {
            h = keccak256(abi.encode(a.imageURIHash, a.animationBaseURIHash));
            locked = a.mediaLocked && a.baseURILocked;
        } else if (kind == keccak256("SCRIPT_SOURCE")) {
            h = keccak256(abi.encode(a.scriptHash, a.scriptBytes));
            locked = a.scriptLocked;
        } else if (kind == keccak256("RENDERER")) {
            h = keccak256(abi.encode(a.renderer, a.rendererCodeHash));
            locked = a.renderer.code.length != 0;
        } else if (kind == keccak256("ENTROPY_COORDINATOR")) {
            (bytes32 seed, bool ready) = IStreamEntropyView(entropy).tokenSeed(91);
            h = keccak256(abi.encode(uint256(91), seed));
            locked = ready;
        } else if (kind == keccak256("RENDER_CONTEXT") || kind == keccak256("DEPENDENCY_SOURCE")) {
            (bytes32 p, bytes32 c, bytes32 d) =
                IStreamMetadataRenderingProfile(router).renderingProfile();
            h = keccak256(abi.encode(kind, p, c, d));
            locked = a.dependenciesLocked;
        } else {
            revert("unsupported fixture family");
        }
        return StreamFinalityHostComponentFacts(
            locked, keccak256("composition-version"), keccak256("composition-manifest"), h
        );
    }
}
