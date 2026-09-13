// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/ScopeMembershipPublicationFixture.sol";

/// @dev Actual publication and membership hosts on the Artist fixture's supplied Core identity.
///      The inherited currentAction/root double remains a governance boundary.
contract ArtistFamilyMembershipPublicationFixture is ScopeMembershipPublicationFixture {
    address private immutable creator = msg.sender;

    function deploy(address core_, address artist_) external returns (address) {
        require(msg.sender == creator && address(metadata) == address(0), "fixture deploy once");
        core = ScopeMetadataCoreBoundary(core_);
        artist = ScopeMetadataArtistBoundary(artist_);
        executor = new ScopeMetadataExecutorBoundary();
        schemas = new StreamSchemaRegistry(address(executor));
        store = StreamSchemaDocumentStore(schemas.chunkStore());
        _register(
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(schemas.RAW_BYTES_DEFINITION())
        );
        _register(
            "STREAM_SCOPE_MEMBERSHIP_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("docs/schemas/finality/scope-membership-v1.schema.json"))
        );
        _register(
            "STREAM_SCOPE_MEMBERSHIP_ABI_V1",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(vm.readFile("docs/schemas/finality/scope-membership-abi-v1.json"))
        );
        StreamCollectionMetadataV1.Configuration memory c;
        c.core = core_;
        c.executor = address(executor);
        c.schemas = address(schemas);
        c.artistRegistry = artist_;
        c.deploymentManifestHash = keccak256("artist family fixture deployment");
        c.manifestHash = keccak256("artist family fixture manifest");
        c.manifestURI = "ipfs://artist-family-membership";
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 150000, 100000, 2
        );
        c.artistReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ARTIST_READ_GAS", 2000000, 1000000, 2
        );
        metadata = new StreamCollectionMetadataV1(c);
        return address(metadata);
    }

    function initialize(uint256[] memory ids) external returns (address) {
        require(
            msg.sender == creator && address(membership) == address(0), "fixture initialize once"
        );
        _admit(SCOPE_RECORD, StreamRecordFamilies.IDENTITY, 384);
        _grant(1, StreamRecordFamilies.IDENTITY, 7, address(this), true);
        inventory = new StreamCollectionTokenInventory(
            address(core),
            address(executor),
            IStreamGasParameterHost.GasParameterConfig(
                "TOKEN_INVENTORY_CORE_READ_GAS", 100000, 50000, 1
            )
        );
        membership = new StreamFinalityScopeMembership(
            address(core),
            address(metadata),
            address(inventory),
            address(executor),
            IStreamGasParameterHost.GasParameterConfig(
                "SCOPE_MEMBERSHIP_READ_GAS", 500000, 50000, 1
            )
        );
        _index(ids, 0, ids.length);
        return address(membership);
    }

    function publish(uint8 family, uint256[] memory ids, string memory uri)
        external
        returns (StreamFinalityScope memory)
    {
        require(msg.sender == creator, "fixture publisher");
        return _seal(family, ids, uri);
    }
}

/// @dev Exact immutable original-provider binding boundary. Actual Router/provider composition is
///      covered separately by the family-membership cohort; this fixture supplies no render facts.
contract ArtistFamilyProviderBoundary {
    address public immutable core;
    bytes32 public immutable coreCodeHash;
    address public immutable metadataHost;
    bytes32 public immutable metadataHostCodeHash;
    address public immutable metadataRouter;
    bytes32 public immutable metadataRouterCodeHash;
    address public immutable scopeMembershipHost;
    bytes32 public immutable scopeMembershipHostCodeHash;

    constructor(address c, address m, address r, address s) {
        core = c;
        coreCodeHash = c.codehash;
        metadataHost = m;
        metadataHostCodeHash = m.codehash;
        metadataRouter = r;
        metadataRouterCodeHash = r.codehash;
        scopeMembershipHost = s;
        scopeMembershipHostCodeHash = s.codehash;
    }
}
