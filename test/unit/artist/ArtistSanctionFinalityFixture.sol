// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../../smart-contracts/domains/finality/StreamArtworkFinalityRegistry.sol";
import "../../../smart-contracts/domains/finality/StreamCoreFinalityAdapter.sol";
import "../../../smart-contracts/interfaces/stream/finality/IStreamFinalitySanctionReview.sol";
import "../../../smart-contracts/interfaces/stream/artist/StreamArtistSanctionRequestTypes.sol";
import "../../helpers/FinalityMocks.sol";

interface ArtistSanctionFixtureVm {
    function getNonce(address account) external view returns (uint64);
    function computeCreateAddress(address deployer, uint256 nonce) external pure returns (address);
}

/// @dev Explicit typed producer boundary. These facts are not actual metadata-record/coverage acceptance.
contract ArtistSanctionEvidenceBoundary is MockFinalityMetadata {
    address public immutable core;
    address public immutable metadataHost;
    bytes32 public constant ROOT = keccak256("unit authoritative content root");
    bytes32 public constant REFERENCE = keccak256("unit reference render artifact content bytes");
    StreamFinalityManifestRef private _manifest;
    StreamFinalityScopeInputs private _inputs;

    constructor(address core_, address metadata_, StreamFinalityManifestRef memory manifest_) {
        core = core_;
        metadataHost = metadata_;
        _manifest = manifest_;
        _inputs = StreamFinalityScopeInputs(
            keccak256("root record"),
            keccak256("snapshot record"),
            keccak256("reference record"),
            keccak256("intent record"),
            0,
            keccak256("interview record"),
            keccak256("rights record"),
            keccak256("description record"),
            keccak256("render inventory"),
            keccak256("bundle coverage")
        );
    }

    function requireFinalityScopeInputs(StreamFinalityScope calldata scope, bytes32 manifest)
        external
        view
        returns (StreamFinalityScopeInputs memory, bytes32, bytes32)
    {
        _scope(scope, manifest);
        return (_inputs, _manifest.schemaId, _manifest.canonicalizationHash);
    }

    function requireSanctionReviewFacts(StreamFinalityScope calldata scope, bytes32 manifest)
        external
        view
        returns (IStreamFinalitySanctionReview.ReviewFacts memory r)
    {
        _scope(scope, manifest);
        r.schemaVersion = 1;
        r.profile = 1;
        r.contentRoot = ROOT;
        r.mediaContentHashes = new bytes32[](0);
        r.referenceRenderContentHashes = new bytes32[](1);
        r.referenceRenderContentHashes[0] = REFERENCE;
    }

    function _scope(StreamFinalityScope calldata scope, bytes32 manifest) private view {
        require(
            scope.scopeType == StreamFinalityScopeType.COLLECTION && scope.collectionId == 1
                && scope.tokenId == 0 && scope.scopeId == 0 && manifest == _manifest.contentHash,
            "exact unit scope/manifest"
        );
    }
}

/// @dev Constructor pin boundary only; intentionally offers no successful coverage validation.
contract ArtistSanctionArtifactBoundary {
    address public immutable core;
    address public immutable finalityRegistry;
    address public immutable governanceAuthority;

    constructor(address core_, address finality_, address governance_) {
        core = core_;
        finalityRegistry = finality_;
        governanceAuthority = governance_;
    }
}

contract ArtistSanctionDiscoveryBoundary is MockFinalityDiscovery {
    address public immutable scopeEvidenceProvider;
    StreamFinalityComponentExpectation[] private _entries;

    constructor(address provider) {
        scopeEvidenceProvider = provider;
    }

    function configure(StreamFinalityComponentExpectation[] calldata entries) external {
        require(_entries.length == 0, "once");
        for (uint256 i; i < entries.length; ++i) {
            _entries.push(entries[i]);
        }
    }

    function nonSanctionDiscoveryFacts(StreamFinalityScope calldata scope)
        external
        view
        returns (uint256, bytes32)
    {
        _scope(scope);
        return (
            _entries.length,
            keccak256(abi.encode(keccak256("6529STREAM_FINALITY_COMPONENTS_V1"), _entries))
        );
    }

    function nonSanctionComponentAt(StreamFinalityScope calldata scope, uint256 index)
        external
        view
        returns (StreamFinalityComponentExpectation memory)
    {
        _scope(scope);
        return _entries[index];
    }

    function _scope(StreamFinalityScope calldata scope) private pure {
        require(
            scope.scopeType == StreamFinalityScopeType.COLLECTION && scope.collectionId == 1
                && scope.tokenId == 0 && scope.scopeId == 0,
            "unit scope"
        );
    }
}

/// @notice Actual canonical Finality/adapter with explicit metadata/discovery/artifact boundaries.
/// @dev Sanction recording works before archival; this fixture cannot satisfy finalization coverage.
contract ArtistSanctionFinalityFixture {
    address public immutable root;
    StreamArtworkFinalityRegistry public registry;
    ArtistSanctionEvidenceBoundary public provider;
    ArtistSanctionDiscoveryBoundary public discovery;
    StreamFinalityManifestRef private _manifest;
    StreamFinalityComponentExpectation[] private _entries;

    constructor() {
        root = msg.sender;
    }

    function deploy(address core, address metadata, address artist, address governance)
        external
        returns (address)
    {
        require(msg.sender == root && address(registry) == address(0), "fixture once");
        bytes memory manifest = bytes("{\"fixture\":\"non-sanction immutable candidate\"}");
        _manifest = StreamFinalityManifestRef(
            "urn:sanction-unit",
            keccak256("urn:sanction-unit"),
            keccak256(manifest),
            keccak256("unit manifest schema"),
            keccak256("unit manifest canonicalization")
        );
        provider = new ArtistSanctionEvidenceBoundary(core, metadata, _manifest);
        discovery = new ArtistSanctionDiscoveryBoundary(address(provider));
        StreamCoreFinalityAdapter adapter =
            new StreamCoreFinalityAdapter(core, metadata, address(provider));
        ArtistSanctionFixtureVm cheat =
            ArtistSanctionFixtureVm(address(uint160(uint256(keccak256("hevm cheat code")))));
        address predicted =
            cheat.computeCreateAddress(address(this), cheat.getNonce(address(this)) + 1);
        ArtistSanctionArtifactBoundary artifact =
            new ArtistSanctionArtifactBoundary(core, predicted, governance);
        registry = new StreamArtworkFinalityRegistry(
            core,
            metadata,
            address(adapter),
            artist,
            governance,
            address(discovery),
            IStreamGasParameterHost.GasParameterConfig(
                "FINALITY_COMPONENT_READ_GAS", 500000, 50000, 2
            ),
            StreamFinalityDeploymentConfiguration(
                address(artifact),
                keccak256("unit finality deployment"),
                "urn:unit-finality",
                keccak256("unit finality manifest")
            )
        );
        require(address(registry) == predicted, "actual fixed finality creator/nonce");
        provider.setMetadataMode(1, 1);
        provider.setSnapshotHash(1, keccak256("snapshot"));
        provider.setContentRoot(
            1,
            registry.contentRootScopeSubject(
                StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0)
            ),
            provider.ROOT(),
            1,
            keccak256("root schema")
        );
        registry.stageFinalityManifest(manifest);
        _installComponents();
        return address(registry);
    }

    function request() external view returns (StreamArtistSanctionRequestTypes.Request memory q) {
        q.terms.collectionId = 1;
        q.nonSanctionComponents = _entries;
        q.manifest = _manifest;
        q.statement = "I reviewed the exact content root and reference render of this collection.";
        q.signingToolName = "6529Stream domain test";
        q.signingToolVersion = "1";
    }

    function _installComponents() private {
        bytes32[9] memory kinds = [
            keccak256("COLLECTION_METADATA"),
            keccak256("METADATA_ROUTER"),
            keccak256("RENDERER"),
            keccak256("RENDER_CONTEXT"),
            keccak256("MEDIA_MANIFEST"),
            keccak256("ENTROPY_COORDINATOR"),
            keccak256("SCRIPT_SOURCE"),
            keccak256("DEPENDENCY_SOURCE"),
            keccak256("REFERENCE_RENDER")
        ];
        for (uint256 i; i < kinds.length; ++i) {
            MockFinalityComponent component = new MockFinalityComponent();
            StreamFinalityComponentExpectation memory e = StreamFinalityComponentExpectation(
                kinds[i],
                address(component),
                0x517ea000,
                address(component).codehash,
                bytes32(uint256(1)),
                keccak256(abi.encode("unit manifest", kinds[i])),
                kinds[i]
            );
            component.setCollectionState(
                1,
                StreamFinalityComponentState(
                    true,
                    e.componentType,
                    e.component,
                    e.interfaceId,
                    e.codeHash,
                    e.moduleVersion,
                    e.manifestHash,
                    e.dataHash
                )
            );
            _entries.push(e);
        }
        for (uint256 i = 1; i < _entries.length; ++i) {
            uint256 j = i;
            while (j > 0 && _entries[j].componentType < _entries[j - 1].componentType) {
                StreamFinalityComponentExpectation memory item = _entries[j];
                _entries[j] = _entries[j - 1];
                _entries[j - 1] = item;
                --j;
            }
        }
        discovery.configure(_entries);
    }
}
