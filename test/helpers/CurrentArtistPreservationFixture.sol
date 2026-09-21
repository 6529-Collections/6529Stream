// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StaticMetadataRoutingFixture.sol";
import {
    StreamSchemaDocumentStore as Store
} from "../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import {
    IStreamSchemaRegistry as Docs
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";

interface CurrentPreservationArtifactVm {
    function getCode(string calldata artifactPath) external view returns (bytes memory);
    function getNonce(address account) external view returns (uint64);
    function computeCreateAddress(address deployer, uint256 nonce) external pure returns (address);
}

/// @dev Genuine linked compiler artifacts are verified by the isolated native runner before EVM.
/// Each deployment retains zero-value CREATE, this test's caller/address context and nonce order.
abstract contract CurrentArtistPreservationCreate {
    CurrentPreservationArtifactVm private constant artifactVm =
        CurrentPreservationArtifactVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _preservationInit(string memory artifact, bytes memory args)
        internal
        view
        returns (bytes memory)
    {
        return bytes.concat(artifactVm.getCode(artifact), args);
    }

    function _preservationCreate(bytes memory init) internal returns (address deployed) {
        require(init.length <= 49152, "original initcode cap");
        uint64 nonce = artifactVm.getNonce(address(this));
        address expected = artifactVm.computeCreateAddress(address(this), nonce);
        assembly ("memory-safe") {
            deployed := create(0, add(init, 32), mload(init))
            if iszero(deployed) {
                let failure := mload(0x40)
                returndatacopy(failure, 0, returndatasize())
                revert(failure, returndatasize())
            }
        }
        require(
            deployed == expected && artifactVm.getNonce(address(this)) == nonce + 1,
            "original CREATE address and nonce"
        );
        require(
            deployed.code.length != 0 && deployed.code.length <= 24576, "original deployed code cap"
        );
    }

    function _preservationDeploy(string memory artifact, bytes memory args)
        internal
        returns (address)
    {
        return _preservationCreate(_preservationInit(artifact, args));
    }

    /// @dev Outer self-call makes expectRevert target constructor failure, not a getCode cheatcode.
    function deployPreservationForRefusal(bytes calldata init) external returns (address) {
        require(msg.sender == address(this), "test self only");
        return _preservationCreate(init);
    }
}

/// @dev Exact original STATIC setup sequence with only artifact CREATE replacing inline new.
/// The original shared fixture and every original post-deployment helper remain unchanged.
abstract contract CurrentArtistPreservationFixture is
    StaticMetadataRoutingFixture,
    CurrentArtistPreservationCreate
{
    function setUp() public virtual override {
        core = StaticRouteCore(
            _preservationDeploy(
                "test/helpers/StaticMetadataRoutingFixture.sol:StaticRouteCore", abi.encode()
            )
        );
        entropy = StaticRouteEntropy(
            _preservationDeploy(
                "test/helpers/StaticMetadataRoutingFixture.sol:StaticRouteEntropy", abi.encode()
            )
        );
        core.setEntropy(address(entropy));
        executor = MetadataExecutorBoundary(
            _preservationDeploy(
                "test/unit/metadata/StreamCollectionMetadataV1.t.sol:MetadataExecutorBoundary",
                abi.encode()
            )
        );
        artist = ManifestArtistBoundary(
            _preservationDeploy(
                "test/unit/metadata/StreamCollectionManifests.t.sol:ManifestArtistBoundary",
                abi.encode(address(core))
            )
        );
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(artist));
        router = StreamMetadataRouter(
            _preservationDeploy(
                "smart-contracts/domains/metadata/StreamMetadataRouter.sol:StreamMetadataRouter",
                abi.encode(
                    address(core),
                    address(executor),
                    keccak256("deployment"),
                    "ipfs://router",
                    keccak256("manifest"),
                    IStreamArtistAttribution(address(artist))
                )
            )
        );
        artist.setRouter(address(router));
        core.setPointer(keccak256("METADATA_ROUTER"), address(router));
        schemas = StreamSchemaRegistry(
            _preservationDeploy(
                "smart-contracts/domains/metadata/StreamSchemaRegistry.sol:StreamSchemaRegistry",
                abi.encode(address(executor))
            )
        );
        StreamCollectionMetadataV1.Configuration memory mc;
        mc.core = address(core);
        mc.executor = address(executor);
        mc.schemas = address(schemas);
        mc.artistRegistry = address(artist);
        mc.deploymentManifestHash = keccak256("deployment");
        mc.manifestHash = keccak256("metadata");
        mc.manifestURI = "ipfs://metadata";
        mc.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 2000000, 100000, 2
        );
        mc.artistReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ARTIST_READ_GAS", 2000000, 1000000, 2
        );
        metadata = StreamCollectionMetadataV1(
            _preservationDeploy(
                "smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol:StreamCollectionMetadataV1",
                abi.encode(mc)
            )
        );
        core.setPointer(keccak256("COLLECTION_METADATA"), address(metadata));
        _admin(
            abi.encodeCall(
                router.setCollectionMetadata, (1, "Static work", "Exact source", "ipfs://image", "")
            )
        );
        _admin(
            abi.encodeCall(router.setCollectionScript, (1, "document.body.textContent = tokenId;"))
        );
        attribution = StaticRouteAttribution(
            _preservationDeploy(
                "test/helpers/StaticMetadataRoutingFixture.sol:StaticRouteAttribution",
                abi.encode(address(core), address(router))
            )
        );
        StreamRendererV1.Deployment memory d;
        d.executor = address(executor);
        d.sources = StreamRendererV1.Sources(
            address(core),
            address(router),
            address(metadata),
            address(entropy),
            address(0),
            address(attribution)
        );
        d.readGas = mc.dependencyReadGas;
        d.attributionGas = IStreamGasParameterHost.GasParameterConfig(
            "STATIC_ATTRIBUTION_GAS", 8000000, 8000000, 1
        );
        d.manifest = R.RendererManifest(
            keccak256("6529STREAM_RENDERER_V1"),
            keccak256("6529STREAM_STATIC_RENDERER_V1"),
            keccak256("STREAM_CONTEXT_V1"),
            keccak256("STATIC"),
            keccak256("schema"),
            "ipfs://schema",
            "ipfs://renderer",
            keccak256("manifest"),
            16777216,
            16777216,
            false
        );
        renderer = StreamRendererV1(
            _preservationDeploy(
                "smart-contracts/domains/metadata/StreamRendererV1.sol:StreamRendererV1",
                abi.encode(d)
            )
        );
        versions = StaticRouteVersions(
            _preservationDeploy(
                "test/helpers/StaticMetadataRoutingFixture.sol:StaticRouteVersions",
                abi.encode(address(executor), address(schemas), address(renderer))
            )
        );
        modules = StaticRouteModules(
            _preservationDeploy(
                "test/helpers/StaticMetadataRoutingFixture.sol:StaticRouteModules",
                abi.encode(address(metadata), address(versions))
            )
        );
        core.setPointer(keccak256("MODULE_REGISTRY"), address(modules));
        _grant(address(this), 8);
    }
}

/// @dev Exact prior test _doc body in a fixed library; DELEGATECALL keeps the test-host sender.
library CurrentArtistPreservationDocuments {
    function publish(
        StreamSchemaRegistry schemas,
        MetadataExecutorBoundary executor,
        string memory name,
        Docs.DocumentKind kind,
        bytes memory payload
    ) public returns (bytes32) {
        Store store = Store(schemas.chunkStore());
        (bytes32 hash,) = store.publishChunk(payload);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        Docs.DocumentSpec memory spec =
            Docs.DocumentSpec(name, kind, hash, schemas.RAW_BYTES(), 0, "", uint32(payload.length));
        (bytes32 s, bytes32 before_, bytes32 after_) = schemas.registrationTransition(spec, chunks);
        return abi.decode(
            executor.execute(
                address(schemas),
                abi.encodeCall(schemas.registerDocument, (spec, chunks)),
                s,
                before_,
                after_
            ),
            (bytes32)
        );
    }
}
