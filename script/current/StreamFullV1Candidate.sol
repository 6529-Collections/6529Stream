// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFullV1GenesisProducts.sol";
import "./StreamFullV1RecordProducts.sol";
import "./StreamFullV1StaticRendererPlan.sol";
import "./StreamFullV1CommerceProducts.sol";
import "./StreamFullV1ContinuityProducts.sol";
import {
    StreamArtistOnboardingRegistry
} from "../../smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol";
import {
    StreamRoyaltyResolver
} from "../../smart-contracts/domains/revenue/StreamRoyaltyResolver.sol";
import {
    StreamRevenueResolver
} from "../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";
import { StreamRevenueEscrow } from "../../smart-contracts/domains/revenue/StreamRevenueEscrow.sol";
import {
    StreamAssetPolicyRegistry
} from "../../smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol";
import {
    StreamSchemaRegistry
} from "../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";
import {
    IGeneralArtistSuite
} from "../../smart-contracts/domains/metadata/StreamGeneralArtistEvidence.sol";
import {
    StreamGeneralAttestationPayloads
} from "../../smart-contracts/domains/metadata/StreamGeneralAttestationPayloads.sol";
import {
    StreamSnapshotManifestBytes
} from "../../smart-contracts/domains/records/StreamSnapshotManifestBytes.sol";
import {
    IStreamGeneralAttestationPayloadChunks
} from "../../smart-contracts/interfaces/stream/metadata/IStreamGeneralAttestationPayloadChunks.sol";
import {
    StreamArtworkFinalityRegistry
} from "../../smart-contracts/domains/finality/StreamArtworkFinalityRegistry.sol";
import {
    StreamCoreFinalityAdapter
} from "../../smart-contracts/domains/finality/StreamCoreFinalityAdapter.sol";
import {
    StreamEntropyProviderARRNG
} from "../../smart-contracts/domains/entropy/StreamEntropyProviderARRNG.sol";

/// @notice A strict 37-role construction inventory over the original current products.
/// @dev Source assembly, not a frozen release profile or operational readiness attestation.
/// Roles with several physical products retain mandatory companions explicitly. Runtime
/// observations must still be authenticated against the final native compiler artifacts.
library StreamFullV1Candidate {
    struct Foundation {
        StreamCore core;
        StreamGovernanceExecutor executor;
        StreamModuleRegistry registry;
        StreamRevenueResolver revenue;
        StreamRoyaltyResolver royalties;
        StreamSplitFactory factory;
        StreamRevenueEscrow escrow;
        StreamAssetPolicyRegistry assets;
        StreamMintManager manager;
        StreamMintLedger ledger;
        StreamArtistOnboardingRegistry artists;
        StreamMetadataRouter router;
        StreamCollectionMetadataV1 metadata;
        StreamSchemaRegistry schemas;
        StreamEntropyCoordinator entropy;
        StreamArtworkFinalityRegistry finality;
        StreamSystemManifest manifest;
        StreamCoreFinalityAdapter coreFinality;
    }

    struct Configuration {
        StreamFullV1GenesisProducts.Configuration independent;
        StreamFullV1RecordProducts.Configuration records;
        StreamFullV1StaticRendererPlan.Configuration rendering;
        StreamFullV1CommerceProducts.Configuration commerce;
        StreamFullV1ContinuityProducts.Configuration continuity;
    }

    struct Products {
        StreamFullV1GenesisProducts.Products independent;
        StreamFullV1RecordProducts.Products records;
        StreamFullV1StaticRendererPlan.Products rendering;
        StreamFullV1CommerceProducts.Products commerce;
        StreamFullV1ContinuityProducts.Products continuity;
        StreamEntropyProviderVRF vrf;
        StreamEntropyProviderARRNG arrng;
    }

    struct ProviderConfiguration {
        StreamEntropyProviderVRF.Config vrf;
        StreamEntropyProviderARRNG.Config arrng;
        bytes32 deploymentHash;
        string vrfManifestURI;
        bytes32 vrfManifestHash;
        string arrngManifestURI;
        bytes32 arrngManifestHash;
    }

    struct Support {
        bytes32 key;
        address target;
        bytes32 runtimeHash;
        uint256 runtimeBytes;
    }

    struct Inventory {
        uint16 schemaVersion;
        uint256 chainId;
        bytes32 deploymentHash;
        bytes32 constructionHash;
        address[37] roles;
        bytes32[37] runtimeHashes;
        uint256[37] runtimeBytes;
        Support[] support;
    }

    /// @dev Real provider adapters, both attached to the primary. The backup's separate
    /// provider is constructed by StreamFullV1ContinuityProducts, never reused here.
    function deployProviders(Foundation memory f, ProviderConfiguration memory c)
        internal
        returns (StreamEntropyProviderVRF vrf, StreamEntropyProviderARRNG arrng)
    {
        require(
            c.vrf.coordinator == address(f.entropy) && c.arrng.coordinator == address(f.entropy)
                && c.vrf.authority == address(f.executor)
                && c.arrng.authority == address(f.executor),
            "primary providers on original foundation"
        );
        vrf = new StreamEntropyProviderVRF(
            c.vrf, c.deploymentHash, c.vrfManifestURI, c.vrfManifestHash
        );
        arrng = new StreamEntropyProviderARRNG(
            c.arrng, c.deploymentHash, c.arrngManifestURI, c.arrngManifestHash
        );
    }

    /// @notice Capture only when every original role and mandatory direct companion exists.
    /// No zero placeholders, predicted addresses, alias labels or unused wallet templates.
    function capture(Foundation memory f, Configuration memory c, Products memory p)
        internal
        view
        returns (Inventory memory inventory)
    {
        _foundation(f);
        _configuration(f, c, p);
        StreamFullV1GenesisProducts.validate(c.independent, p.independent);
        StreamFullV1RecordProducts.validate(c.records, p.records);
        StreamFullV1StaticRendererPlan.validate(c.rendering, p.rendering);
        StreamFullV1CommerceProducts.validate(c.commerce, p.commerce);
        StreamFullV1ContinuityProducts.validate(c.continuity, p.continuity);
        _providers(f, p, c.independent.deploymentHash);
        require(
            p.records.general.streamModuleVersion()
                    == keccak256("6529stream.general-attestations.v2")
                && p.records.general
                    .supportsInterface(type(IStreamGeneralAttestationPayloadChunks).interfaceId)
                && p.records.general.MAX_RECORD_PAYLOAD_BYTES() == 24576
                && p.records.preservation.MAX_RECORD_PAYLOAD_BYTES() == 24576
                && f.metadata.MAX_RECORD_PAYLOAD_BYTES() == 24576,
            "full-byte original record products"
        );
        inventory.schemaVersion = 1;
        inventory.chainId = block.chainid;
        inventory.deploymentHash = c.independent.deploymentHash;
        inventory.constructionHash = keccak256(abi.encode(f, c, p));
        inventory.roles = [
            address(f.core),
            address(f.executor),
            address(f.registry),
            address(f.revenue),
            address(f.factory),
            p.continuity.walletImplementation,
            address(f.escrow),
            address(f.assets),
            address(p.commerce.native.recorder),
            address(p.independent.claims),
            address(f.manager),
            address(f.ledger),
            address(p.independent.tickets),
            address(p.commerce.fixedSale),
            address(p.commerce.native.house),
            address(p.commerce.dutch),
            address(p.commerce.privateSale),
            address(p.commerce.burn),
            address(p.independent.delegates),
            address(p.commerce.erc20),
            address(f.artists),
            address(f.router),
            address(p.rendering.renderer),
            address(f.metadata),
            address(f.schemas),
            address(p.independent.owners),
            address(p.records.preservation),
            address(p.independent.attestations),
            address(p.independent.views),
            address(f.entropy),
            address(p.vrf),
            address(p.arrng),
            address(f.finality),
            address(p.continuity.entropy),
            address(p.continuity.manager),
            address(f.manifest),
            address(f.coreFinality)
        ];
        for (uint256 i; i < 37; ++i) {
            address target = inventory.roles[i];
            require(target.code.length != 0, "missing full37 original role");
            for (uint256 j; j < i; ++j) {
                require(target != inventory.roles[j], "distinct full37 role products");
            }
            inventory.runtimeHashes[i] = target.codehash;
            inventory.runtimeBytes[i] = target.code.length;
        }
        inventory.support = _support(f, p);
    }

    function inventoryHash(Inventory memory inventory) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(keccak256("6529STREAM_FULL37_CONSTRUCTION_INVENTORY_V1"), inventory)
        );
    }

    /// @notice Compare a retained exact construction inventory with current original products.
    function requireUnchanged(
        Foundation memory f,
        Configuration memory c,
        Products memory p,
        bytes32 expectedInventoryHash
    ) internal view {
        require(
            inventoryHash(capture(f, c, p)) == expectedInventoryHash, "full37 inventory changed"
        );
    }

    /// @notice Deployment size is a separate gate and may fail on a captured source candidate.
    /// This is runtime-size checking only, not initcode, transitive library or whole-graph proof.
    function requireRuntimeSizes(Inventory memory inventory) internal pure {
        for (uint256 i; i < 37; ++i) {
            require(
                inventory.runtimeBytes[i] != 0 && inventory.runtimeBytes[i] <= 24576,
                "role runtime exceeds EIP170"
            );
        }
        for (uint256 i; i < inventory.support.length; ++i) {
            require(
                inventory.support[i].runtimeBytes != 0
                    && inventory.support[i].runtimeBytes <= 24576,
                "support runtime exceeds EIP170"
            );
        }
    }

    function _foundation(Foundation memory f) private view {
        require(
            f.executor.genesisInitialized()
                && address(f.registry.governanceExecutor()) == address(f.executor)
                && f.ledger.owner() == address(f.executor)
                && f.manager.owner() == address(f.executor),
            "completed original foundation and Manager handoff"
        );
        require(
            address(f.manager.core()) == address(f.core)
                && address(f.manager.mintLedger()) == address(f.ledger)
                && address(f.manager.moduleRegistry()) == address(f.registry),
            "primary mint foundation"
        );
        StreamCorePointerState memory selected =
            StreamCurrentStackPlan.readPointer(f.core, keccak256("MODULE_REGISTRY"));
        require(
            selected.target == address(f.registry)
                && selected.codeHash == address(f.registry).codehash,
            "canonical module registry"
        );
        require(
            f.revenue.core() == address(f.core)
                && address(f.revenue.splitFactory()) == address(f.factory)
                && address(f.royalties.boundCore()) == address(f.core)
                && address(f.royalties.splitFactory()) == address(f.factory)
                && address(f.factory.assetPolicyRegistry()) == address(f.assets)
                && address(f.escrow.splitFactory()) == address(f.factory),
            "one economic foundation"
        );
        require(
            f.revenue.artistRegistry() == address(f.artists)
                && address(f.royalties.artistRegistry()) == address(f.artists)
                && f.revenue.governanceAuthority() == address(f.executor)
                && f.royalties.governanceAuthority() == address(f.executor)
                && f.assets.governanceAuthority() == address(f.executor)
                && f.escrow.governanceAuthority() == address(f.executor)
                && f.manifest.governanceExecutor() == address(f.executor),
            "original economics Artist and governance bindings"
        );
        require(
            f.metadata.core() == address(f.core)
                && f.metadata.schemaRegistry() == address(f.schemas)
                && f.metadata.chunkStore() == f.schemas.chunkStore()
                && f.manifest.core() == address(f.core) && f.finality.core() == address(f.core)
                && address(f.finality.coreFinalityAdapter()) == address(f.coreFinality)
                && f.coreFinality.core() == address(f.core)
                && f.coreFinality.collectionMetadata() == address(f.metadata),
            "original metadata and finality foundation"
        );
    }

    function _configuration(Foundation memory f, Configuration memory c, Products memory p)
        private
        pure
    {
        address core = address(f.core);
        address executor = address(f.executor);
        bytes32 deploymentHash = c.independent.deploymentHash;
        require(
            c.independent.core == core && c.independent.executor == executor
                && c.independent.metadata == address(f.metadata)
                && c.independent.schemas == address(f.schemas),
            "independent product foundation"
        );
        require(
            c.records.core == core && c.records.executor == executor
                && c.records.metadata == address(f.metadata)
                && c.records.schemas == address(f.schemas)
                && c.records.artistRegistry == address(f.artists)
                && c.records.deploymentHash == deploymentHash,
            "record product foundation"
        );
        require(
            c.rendering.core == core && c.rendering.executor == executor
                && c.rendering.router == address(f.router)
                && c.rendering.metadata == address(f.metadata)
                && c.rendering.schemas == address(f.schemas)
                && c.rendering.entropy == address(f.entropy)
                && c.rendering.artist == address(f.artists)
                && c.rendering.finality == address(f.finality)
                && c.rendering.deploymentHash == deploymentHash,
            "renderer foundation"
        );
        require(
            address(c.commerce.resolver) == address(f.revenue)
                && address(c.commerce.registry) == address(f.registry)
                && address(c.commerce.escrow) == address(f.escrow)
                && address(c.commerce.auction.manager) == address(f.manager)
                && address(c.commerce.auction.artists) == address(f.artists)
                && address(c.commerce.auction.entropy) == address(f.entropy)
                && c.commerce.auction.authority == executor
                && c.commerce.deploymentHash == deploymentHash,
            "commerce foundation"
        );
        require(
            address(c.continuity.core) == core && address(c.continuity.executor) == executor
                && address(c.continuity.registry) == address(f.registry)
                && address(c.continuity.ledger) == address(f.ledger)
                && address(c.continuity.manager) == address(f.manager)
                && address(c.continuity.factory) == address(f.factory)
                && address(c.continuity.entropy) == address(f.entropy)
                && c.continuity.recorder == address(p.commerce.native.recorder)
                && c.continuity.deploymentHash == deploymentHash,
            "continuity foundation"
        );
    }

    function _providers(Foundation memory f, Products memory p, bytes32 deploymentHash)
        private
        view
    {
        require(
            address(p.vrf).code.length != 0 && address(p.arrng).code.length != 0
                && p.vrf.coordinator() == address(f.entropy)
                && p.arrng.coordinator() == address(f.entropy)
                && p.vrf.authority() == address(f.executor)
                && p.arrng.governanceAuthority() == address(f.executor)
                && p.vrf.streamModuleDeploymentManifestHash() == deploymentHash
                && p.arrng.streamModuleDeploymentManifestHash() == deploymentHash
                && address(p.continuity.provider) != address(p.vrf)
                && address(p.continuity.provider) != address(p.arrng),
            "actual primary adapters and distinct backup adapter"
        );
    }

    function _support(Foundation memory f, Products memory p)
        private
        view
        returns (Support[] memory out)
    {
        address coordinator = f.artists.operationCoordinator();
        StreamArtistOnboardingTypes.SuiteConfiguration memory suite =
            IGeneralArtistSuite(coordinator).suiteConfiguration();
        require(
            suite.core == address(f.core) && suite.registry == address(f.artists)
                && suite.mintManager == address(f.manager)
                && suite.roleRegistry == address(f.executor.roleRegistry()),
            "original modular Artist suite"
        );
        out = new Support[](25);
        out[0] = _row("ROLE_REGISTRY", address(f.executor.roleRegistry()));
        out[1] = _row("ROYALTY_RESOLVER", address(f.royalties));
        out[2] = _row("ARTIST_COORDINATOR", coordinator);
        out[3] = _row("ARTIST_ARCHIVE", suite.archive);
        out[4] = _row("ARTIST_VALIDATOR", suite.validator);
        for (uint256 i; i < 7; ++i) {
            out[5 + i] = _row(keccak256(abi.encode("ARTIST_OWNER", i)), suite.owners[i]);
        }
        out[12] = _row("SCHEMA_DOCUMENT_STORE", f.schemas.chunkStore());
        out[13] = _row("STATIC_ATTRIBUTION", address(p.rendering.attribution));
        out[14] = _row("RENDERER_REGISTRY", address(p.rendering.versions));
        out[15] = _row("GENERAL_ATTESTATIONS", address(p.records.general));
        out[16] = _row("BACKUP_ENTROPY_PROVIDER", address(p.continuity.provider));
        out[17] = _row("FINALITY_CORE_READS", address(f.finality.coreReads()));
        out[18] = _row("FINALITY_METADATA_READS", address(f.finality.metadataReads()));
        out[19] = _row("FINALITY_SCOPE_EVIDENCE", f.finality.scopeEvidenceProvider());
        out[20] = _row("FINALITY_ARTIFACT_COVERAGE", f.finality.artifactCoverage());
        out[21] = _row("FINALITY_SANCTION_READS", address(f.finality.sanctionReads()));
        out[22] = _row("FINALITY_DISCOVERY", f.finality.finalityDiscovery());
        out[23] = _row("GENERAL_PAYLOAD_LIBRARY", address(StreamGeneralAttestationPayloads));
        out[24] = _row("SNAPSHOT_BYTES_LIBRARY", address(StreamSnapshotManifestBytes));
    }

    function _row(bytes32 key, address target) private view returns (Support memory) {
        require(target.code.length != 0, "missing actual direct support");
        return Support(key, target, target.codehash, target.code.length);
    }
}
