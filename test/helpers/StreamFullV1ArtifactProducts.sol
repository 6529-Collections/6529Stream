// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../script/current/StreamFullV1Candidate.sol";

interface StreamFullV1ArtifactVm {
    function getCode(string calldata artifact) external returns (bytes memory);
}

/// @notice Test-only construction of the original full-v1 products from authenticated artifacts.
/// @dev Internal stages retain the original fixture caller, constructor arguments, CREATE order,
/// validations and ownership handoffs. Genuine Forge artifacts must be source/native authenticated
/// and linked before execution. This helper neither substitutes runtimes nor deploys a proxy.
library StreamFullV1ArtifactProducts {
    // Mirrors StreamFullV1GenesisProducts.deploy at the retained source anchor.
    function deployGenesis(StreamFullV1GenesisProducts.Configuration memory c)
        internal
        returns (StreamFullV1GenesisProducts.Products memory p)
    {
        _genesisDependencies(c);
        p.chainId = block.chainid;
        p.configurationHash = keccak256(abi.encode(c));
        p.claims = StreamClaimRouter(
            payable(_create(
                    "smart-contracts/domains/revenue/StreamClaimRouter.sol:StreamClaimRouter",
                    abi.encode()
                ))
        );
        p.tickets = StreamMintTicketGate(
            payable(_create(
                    "smart-contracts/domains/mint/StreamMintTicketGate.sol:StreamMintTicketGate",
                    abi.encode(c.executor, c.ticketSigner, c.ticketSignerKind)
                ))
        );
        p.delegates = StreamDelegateRegistryGate(
            payable(_create(
                    "smart-contracts/domains/mint/StreamDelegateRegistryGate.sol:StreamDelegateRegistryGate",
                    abi.encode(c.core, c.delegateRegistry, c.delegationUsecase, c.executor)
                ))
        );
        p.owners = StreamOwnerRecords(
            payable(_create(
                    "smart-contracts/domains/metadata/StreamOwnerRecords.sol:StreamOwnerRecords",
                    abi.encode(
                        StreamOwnerRecords.Configuration(
                            c.core,
                            c.schemas,
                            c.executor,
                            c.deploymentHash,
                            c.owner.uri,
                            c.owner.hash,
                            c.signatureGas,
                            c.dependencyReadGas
                        )
                    )
                ))
        );
        p.attestations = StreamCollectionAttestations(
            payable(_create(
                    "smart-contracts/domains/metadata/StreamCollectionAttestations.sol:StreamCollectionAttestations",
                    abi.encode(
                        StreamCollectionAttestations.Configuration(
                            c.core,
                            c.schemas,
                            c.executor,
                            c.deploymentHash,
                            c.attestation.uri,
                            c.attestation.hash,
                            c.signatureGas,
                            c.dependencyReadGas
                        )
                    )
                ))
        );
        p.views = StreamCollectionViews(
            payable(_create(
                    "smart-contracts/domains/metadata/StreamCollectionViews.sol:StreamCollectionViews",
                    abi.encode(
                        StreamCollectionViews.Configuration(
                            c.core,
                            c.metadata,
                            c.executor,
                            c.deploymentHash,
                            c.views.uri,
                            c.views.hash,
                            c.dependencyReadGas
                        )
                    )
                ))
        );
        address[6] memory hosts = StreamFullV1GenesisProducts.addresses(p);
        for (uint256 i; i < hosts.length; ++i) {
            p.codeHashes[i] = hosts[i].codehash;
        }
        StreamFullV1GenesisProducts.validate(c, p);
    }

    // Mirrors StreamFullV1GenesisProducts._dependencies at the retained source anchor.
    function _genesisDependencies(StreamFullV1GenesisProducts.Configuration memory c) private view {
        if (
            c.core.code.length == 0 || c.executor.code.length == 0 || c.metadata.code.length == 0
                || c.schemas.code.length == 0 || c.delegateRegistry.code.length == 0
                || c.delegationUsecase == 0 || c.ticketSigner == address(0)
                || (c.ticketSignerKind != 1 && c.ticketSignerKind != 2) || c.deploymentHash == 0
                || c.ticket.hash == 0 || bytes(c.ticket.uri).length == 0
                || bytes(c.delegateManifestURI).length == 0 || c.owner.hash == 0
                || c.attestation.hash == 0 || c.views.hash == 0
        ) {
            revert StreamFullV1GenesisProducts.InvalidGenesisProductDependencies();
        }
        StreamCollectionMetadataV1 metadata = StreamCollectionMetadataV1(c.metadata);
        if (
            metadata.core() != c.core || metadata.schemaRegistry() != c.schemas
                || metadata.governanceAuthority() != c.executor
        ) {
            revert StreamFullV1GenesisProducts.InvalidGenesisProductDependencies();
        }
    }

    // Mirrors StreamFullV1CommerceProducts.deploy at the retained source anchor.
    function deployCommerce(StreamFullV1CommerceProducts.Configuration memory c)
        internal
        returns (StreamFullV1CommerceProducts.Products memory p)
    {
        _commerceConfiguration(c);
        p.configurationHash = keccak256(abi.encode(c));
        // The original pair planner injects its new recorder into its memory argument.
        // Preserve the reviewed zero-recorder configuration instead of aliasing it.
        StreamNativeEnglishAuction.DeploymentConfig memory auction =
            abi.decode(abi.encode(c.auction), (StreamNativeEnglishAuction.DeploymentConfig));
        p.native = _deployNativeCommerce(
            c.resolver, c.registry, c.escrow, auction, c.deploymentHash, c.commerceManifestHash
        );
        p.fixedSale = StreamNativeFixedPriceSaleAdapter(
            payable(_create(
                    "smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol:StreamNativeFixedPriceSaleAdapter",
                    abi.encode(
                        c.auction.manager,
                        p.native.recorder,
                        c.auction.platform,
                        c.auction.artists,
                        c.fixedRevealGas,
                        c.fixedDelegation
                    )
                ))
        );
        p.fixedSale.transferOwnership(c.auction.authority);
        StreamNativeDutchSale.DeploymentConfig memory dutch =
            abi.decode(abi.encode(c.dutch), (StreamNativeDutchSale.DeploymentConfig));
        dutch.recorder = p.native.recorder;
        p.dutch = StreamNativeDutchSale(
            payable(_create(
                    "smart-contracts/domains/mint/StreamNativeDutchSale.sol:StreamNativeDutchSale",
                    abi.encode(dutch)
                ))
        );
        p.privateSale = StreamPrivateSaleAdapter(
            payable(_create(
                    "smart-contracts/domains/mint/StreamPrivateSaleAdapter.sol:StreamPrivateSaleAdapter",
                    abi.encode(c.privateSale)
                ))
        );
        p.burn = StreamBurnMintGate(
            payable(_create(
                    "smart-contracts/domains/mint/StreamBurnMintGate.sol:StreamBurnMintGate",
                    abi.encode(c.burn)
                ))
        );
        p.erc20 = StreamERC20PrimarySettlementAdapter(
            payable(_create(
                    "smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol:StreamERC20PrimarySettlementAdapter",
                    abi.encode(p.native.recorder, c.permit2, c.permit2CodeHash)
                ))
        );
        address[5] memory hosts = StreamFullV1CommerceProducts.addresses(p);
        for (uint256 i; i < hosts.length; ++i) {
            p.codeHashes[i] = hosts[i].codehash;
        }
        StreamFullV1CommerceProducts.validate(c, p);
    }

    // Mirrors StreamFullV1CommerceProducts._configuration at the retained source anchor.
    function _commerceConfiguration(StreamFullV1CommerceProducts.Configuration memory c)
        private
        view
    {
        address core = c.resolver.core();
        address authority = c.auction.authority;
        require(
            core.code.length != 0 && authority.code.length != 0
                && address(c.registry.governanceExecutor()) == authority
                && address(c.auction.roles)
                    == address(StreamGovernanceExecutor(payable(authority)).roleRegistry())
                && address(StreamMintManager(address(c.auction.manager)).core()) == core
                && c.auction.artists.core() == core && address(c.auction.recorder) == address(0)
                && address(c.dutch.recorder) == address(0),
            "original graph and unbound recorder inputs"
        );
        require(
            address(c.dutch.manager) == address(c.auction.manager)
                && c.dutch.platform == c.auction.platform
                && address(c.dutch.artists) == address(c.auction.artists)
                && address(c.dutch.entropy) == address(c.auction.entropy)
                && address(c.dutch.roles) == address(c.auction.roles)
                && c.dutch.authority == authority,
            "Dutch current graph"
        );
        require(
            c.privateSale.core == core && c.privateSale.moduleRegistry == address(c.registry)
                && c.privateSale.platformSigner == c.auction.platform
                && c.privateSale.configurationOwner == authority
                && c.privateSale.governanceAuthority == authority
                && c.privateSale.roleRegistry == address(c.auction.roles),
            "private custody current graph"
        );
        require(
            c.burn.core == core && c.burn.registry == address(c.registry)
                && c.burn.governance == authority && c.burn.operator == authority
                && c.burn.deploymentManifestHash == c.deploymentHash,
            "burn current graph"
        );
    }

    // Mirrors StreamNativeCommerceDeployment.deploy at the retained source anchor.
    function _deployNativeCommerce(
        IStreamRevenueResolver resolver,
        StreamModuleRegistry registry,
        IStreamRevenueEscrow escrow,
        StreamNativeEnglishAuction.DeploymentConfig memory config,
        bytes32 deploymentManifestHash,
        bytes32 moduleManifestHash
    ) private returns (StreamNativeCommerceDeployment.Products memory products) {
        if (
            address(config.recorder) != address(0) || deploymentManifestHash == bytes32(0)
                || moduleManifestHash == bytes32(0)
        ) revert StreamNativeCommerceDeployment.InvalidNativeCommerceDeployment();
        (address bound,,,) =
            IStreamPreparedNativeMint(address(config.manager)).preparedNativeRecorder();
        if (bound != address(0)) {
            revert StreamNativeCommerceDeployment.InvalidNativeCommerceDeployment();
        }
        StreamPrimarySaleSettlement recorder = StreamPrimarySaleSettlement(
            payable(_create(
                    "smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol:StreamPrimarySaleSettlement",
                    abi.encode(resolver, address(registry), escrow)
                ))
        );
        config.recorder = recorder;
        StreamNativeEnglishAuction house = StreamNativeEnglishAuction(
            payable(_create(
                    "smart-contracts/domains/auctions/StreamNativeEnglishAuction.sol:StreamNativeEnglishAuction",
                    abi.encode(config)
                ))
        );
        products = StreamNativeCommerceDeployment.Products(
            block.chainid,
            recorder,
            house,
            address(recorder).codehash,
            address(house).codehash,
            deploymentManifestHash,
            moduleManifestHash,
            config.delegateRegistry == address(0)
                ? moduleManifestHash
                : keccak256(house.delegationManifest())
        );
        StreamNativeCommerceDeployment.validate(products);
    }

    // Mirrors StreamFullV1RecordProducts.deploy at the retained source anchor.
    function deployRecords(StreamFullV1RecordProducts.Configuration memory c)
        internal
        returns (StreamFullV1RecordProducts.Products memory p)
    {
        address[7] memory dependencies = _recordDependencies(c);
        p.chainId = block.chainid;
        p.configurationHash = keccak256(abi.encode(c));
        for (uint256 i; i < dependencies.length; ++i) {
            p.dependencyCodeHashes[i] = dependencies[i].codehash;
        }
        p.preservation = StreamPreservationRecordsV1(
            payable(_create(
                    "smart-contracts/domains/preservation/StreamPreservationRecordsV1.sol:StreamPreservationRecordsV1",
                    abi.encode(
                        StreamPreservationRecordsV1.Configuration(
                            c.core,
                            c.metadata,
                            c.executor,
                            c.deploymentHash,
                            c.preservation.uri,
                            c.preservation.hash,
                            c.dependencyReadGas
                        )
                    )
                ))
        );
        p.general = StreamGeneralAttestations(
            payable(_create(
                    "smart-contracts/domains/metadata/StreamGeneralAttestations.sol:StreamGeneralAttestations",
                    abi.encode(
                        StreamGeneralAttestations.Configuration(
                            c.core,
                            c.schemas,
                            c.metadata,
                            c.artistRegistry,
                            c.artistAttribution,
                            c.executor,
                            c.deploymentHash,
                            c.general.uri,
                            c.general.hash,
                            c.signatureGas,
                            c.dependencyReadGas
                        )
                    )
                ))
        );
        p.preservationCodeHash = address(p.preservation).codehash;
        p.generalCodeHash = address(p.general).codehash;
        StreamFullV1RecordProducts.validate(c, p);
    }

    // Mirrors StreamFullV1RecordProducts._dependencies at the retained source anchor.
    function _recordDependencies(StreamFullV1RecordProducts.Configuration memory c)
        private
        view
        returns (address[7] memory d)
    {
        if (c.deploymentHash == 0 || c.preservation.hash == 0 || c.general.hash == 0) {
            revert StreamFullV1RecordProducts.InvalidRecordComposition();
        }
        d = [
            c.core,
            c.executor,
            c.metadata,
            c.schemas,
            address(0),
            c.artistRegistry,
            c.artistAttribution
        ];
        for (uint256 i; i < d.length; ++i) {
            if (i != 4 && d[i].code.length == 0) {
                revert StreamFullV1RecordProducts.RecordCompositionChanged(d[i]);
            }
        }
        StreamCollectionMetadataV1 metadata = StreamCollectionMetadataV1(c.metadata);
        if (
            metadata.core() != c.core || metadata.schemaRegistry() != c.schemas
                || metadata.governanceAuthority() != c.executor
                || IStreamSchemaRegistry(c.schemas).governanceAuthority() != c.executor
        ) {
            revert StreamFullV1RecordProducts.InvalidRecordComposition();
        }
        d[4] = IStreamSchemaRegistry(c.schemas).chunkStore();
        if (d[4].code.length == 0 || metadata.chunkStore() != d[4]) {
            revert StreamFullV1RecordProducts.InvalidRecordComposition();
        }
        // Includes the original Registry -> Coordinator -> owners[4] reciprocal bindings.
        StreamGeneralArtistEvidence.requireBinding(
            StreamGeneralArtistEvidence.Configuration(
                c.core,
                c.artistRegistry,
                c.artistAttribution,
                c.artistRegistry.codehash,
                c.artistAttribution.codehash,
                c.dependencyReadGas.genesisValue
            )
        );
    }

    // Mirrors StreamFullV1ContinuityProducts.deploy at the retained source anchor.
    function deployContinuity(StreamFullV1ContinuityProducts.Configuration memory c)
        internal
        returns (StreamFullV1ContinuityProducts.Products memory p)
    {
        address[8] memory dependencies = _continuityDependencies(c);
        p.chainId = block.chainid;
        p.configurationHash = keccak256(abi.encode(c));
        for (uint256 i; i < dependencies.length; ++i) {
            p.dependencyCodeHashes[i] = dependencies[i].codehash;
        }
        p.walletImplementation = c.factory.splitWalletImplementation();
        p.walletImplementationCodeHash = c.factory.splitWalletImplementationCodeHash();
        p.entropy = StreamEntropyCoordinator(
            payable(_create(
                    "smart-contracts/domains/entropy/StreamEntropyCoordinator.sol:StreamEntropyCoordinator",
                    abi.encode(
                        StreamEntropyFallbackPlan.deploymentConfig(
                            c.entropy,
                            c.entropyTimes,
                            c.deploymentHash,
                            c.entropyBackup.uri,
                            c.entropyBackup.hash
                        )
                    )
                ))
        );
        StreamEntropyProviderVRF.Config memory provider =
            abi.decode(abi.encode(c.backupVRF), (StreamEntropyProviderVRF.Config));
        provider.coordinator = address(p.entropy);
        p.provider = StreamEntropyProviderVRF(
            payable(_create(
                    "smart-contracts/domains/entropy/StreamEntropyProviderVRF.sol:StreamEntropyProviderVRF",
                    abi.encode(provider, c.deploymentHash, c.provider.uri, c.provider.hash)
                ))
        );
        p.manager = StreamMintManagerFallback(
            payable(_create(
                    "smart-contracts/domains/mint/StreamMintManagerFallback.sol:StreamMintManagerFallback",
                    abi.encode(c.core, c.ledger, IERC165(address(c.registry)))
                ))
        );
        p.manager.transferOwnership(address(c.executor));
        p.managerCodeHash = address(p.manager).codehash;
        p.entropyCodeHash = address(p.entropy).codehash;
        p.providerCodeHash = address(p.provider).codehash;
        StreamFullV1ContinuityProducts.validate(c, p);
    }

    // Mirrors StreamFullV1ContinuityProducts._dependencies at the retained source anchor.
    function _continuityDependencies(StreamFullV1ContinuityProducts.Configuration memory c)
        private
        view
        returns (address[8] memory d)
    {
        d = [
            address(c.core),
            address(c.executor),
            address(c.registry),
            address(c.ledger),
            address(c.manager),
            address(c.factory),
            address(c.entropy),
            c.recorder
        ];
        for (uint256 i; i < d.length; ++i) {
            require(d[i].code.length != 0, "original continuity dependency");
        }
        if (
            c.deploymentHash == 0 || c.mintVersion == 0 || c.mint.hash == 0
                || c.entropyBackup.hash == 0 || c.provider.hash == 0 || c.moduleGas == 0
                || c.backupVRF.coordinator != address(0)
                || c.backupVRF.authority != address(c.executor)
                || c.factory.governanceAuthority() != address(c.executor)
                || c.entropy.authority() != address(c.executor)
                || address(c.entropy.core()) != address(c.core)
                || address(c.entropy.roleRegistry()) != address(c.executor.roleRegistry())
        ) revert StreamFullV1ContinuityProducts.InvalidContinuityComposition();
    }

    // Mirrors StreamFullV1Candidate.deployProviders at the retained source anchor.
    function deployProviders(
        StreamFullV1Candidate.Foundation memory f,
        StreamFullV1Candidate.ProviderConfiguration memory c
    ) internal returns (StreamEntropyProviderVRF vrf, StreamEntropyProviderARRNG arrng) {
        require(
            c.vrf.coordinator == address(f.entropy) && c.arrng.coordinator == address(f.entropy)
                && c.vrf.authority == address(f.executor)
                && c.arrng.authority == address(f.executor),
            "primary providers on original foundation"
        );
        vrf = StreamEntropyProviderVRF(
            payable(_create(
                    "smart-contracts/domains/entropy/StreamEntropyProviderVRF.sol:StreamEntropyProviderVRF",
                    abi.encode(c.vrf, c.deploymentHash, c.vrfManifestURI, c.vrfManifestHash)
                ))
        );
        arrng = StreamEntropyProviderARRNG(
            payable(_create(
                    "smart-contracts/domains/entropy/StreamEntropyProviderARRNG.sol:StreamEntropyProviderARRNG",
                    abi.encode(c.arrng, c.deploymentHash, c.arrngManifestURI, c.arrngManifestHash)
                ))
        );
    }

    // Mirrors StreamFullV1StaticRendererPlan.deployRenderer at the retained source anchor.
    function deployRenderer(StreamFullV1StaticRendererPlan.Configuration memory c)
        internal
        returns (StreamFullV1StaticRendererPlan.Products memory p)
    {
        _rendererDependencies(c);
        p.configurationHash = keccak256(abi.encode(c));
        p.attribution = StreamStaticAttributionCompanion(
            payable(_create(
                    "smart-contracts/domains/metadata/StreamStaticAttributionCompanion.sol:StreamStaticAttributionCompanion",
                    abi.encode(c.core, c.router, c.artist, c.finality, c.executor)
                ))
        );
        p.renderer = StreamRendererV1(
            payable(_create(
                    "smart-contracts/domains/metadata/StreamRendererV1.sol:StreamRendererV1",
                    abi.encode(
                        StreamRendererV1.Deployment(
                            StreamRendererV1.Sources(
                                c.core,
                                c.router,
                                c.metadata,
                                c.entropy,
                                c.dependencyRegistry,
                                address(p.attribution)
                            ),
                            c.executor,
                            c.readGas,
                            c.attributionGas,
                            c.rendererManifest
                        )
                    )
                ))
        );
        p.attributionCodeHash = address(p.attribution).codehash;
        p.rendererCodeHash = address(p.renderer).codehash;
    }

    // Mirrors StreamFullV1StaticRendererPlan.deployRegistry at the retained source anchor.
    function deployRendererRegistry(
        StreamFullV1StaticRendererPlan.Configuration memory c,
        StreamFullV1StaticRendererPlan.Products memory p,
        V.Target[] memory targets
    ) internal returns (StreamFullV1StaticRendererPlan.Products memory) {
        _checkRenderer(c, p);
        if (address(p.versions) != address(0)) {
            revert StreamFullV1StaticRendererPlan.InvalidStaticComposition();
        }
        _requiredRendererTargets(c, p, targets);
        p.versions = StreamRendererRegistryModule(
            payable(_create(
                    "smart-contracts/domains/metadata/StreamRendererRegistryModule.sol:StreamRendererRegistryModule",
                    abi.encode(
                        StreamRendererRegistryModule.Deployment(
                            c.executor,
                            c.schemas,
                            targets,
                            c.readGas,
                            c.goldenGas,
                            c.deploymentHash,
                            c.registryManifestURI,
                            c.registryManifestHash
                        )
                    )
                ))
        );
        p.registryCodeHash = address(p.versions).codehash;
        return p;
    }

    // Mirrors StreamFullV1StaticRendererPlan._renderer at the retained source anchor.
    function _checkRenderer(
        StreamFullV1StaticRendererPlan.Configuration memory c,
        StreamFullV1StaticRendererPlan.Products memory p
    ) private view {
        _rendererDependencies(c);
        if (
            p.configurationHash != keccak256(abi.encode(c))
                || address(p.attribution).code.length == 0
                || address(p.attribution).codehash != p.attributionCodeHash
                || address(p.renderer).code.length == 0
                || address(p.renderer).codehash != p.rendererCodeHash
                || p.attribution.core() != c.core || p.attribution.router() != c.router
                || p.attribution.artist() != c.artist
                || p.attribution.originalFinality() != c.finality
                || p.attribution.artistCodeHash() != c.artist.codehash
                || p.attribution.originalFinalityCodeHash() != c.finality.codehash
                || p.renderer.governanceAuthority() != c.executor
        ) {
            revert StreamFullV1StaticRendererPlan.InvalidStaticComposition();
        }
        (StreamRendererV1.Sources memory actual, bytes32[6] memory hashes) =
            p.renderer.sourceBindings();
        if (
            actual.core != c.core || actual.router != c.router || actual.metadata != c.metadata
                || actual.entropy != c.entropy || actual.dependencyRegistry != c.dependencyRegistry
                || actual.attribution != address(p.attribution)
        ) revert StreamFullV1StaticRendererPlan.InvalidStaticComposition();
        address[6] memory sources = [
            actual.core,
            actual.router,
            actual.metadata,
            actual.entropy,
            actual.dependencyRegistry,
            actual.attribution
        ];
        for (uint256 i; i < sources.length; ++i) {
            if (sources[i].codehash != hashes[i]) {
                revert StreamFullV1StaticRendererPlan.InvalidStaticComposition();
            }
        }
    }

    // Mirrors StreamFullV1StaticRendererPlan._dependencies at the retained source anchor.
    function _rendererDependencies(StreamFullV1StaticRendererPlan.Configuration memory c)
        private
        view
    {
        if (
            c.core.code.length == 0 || c.executor.code.length == 0 || c.router.code.length == 0
                || c.metadata.code.length == 0 || c.schemas.code.length == 0
                || c.entropy.code.length == 0 || c.artist.code.length == 0
                || c.finality.code.length == 0 || c.deploymentHash == 0
                || c.registryManifestHash == 0 || bytes(c.registryManifestURI).length == 0
                || (c.dependencyRegistry != address(0) && c.dependencyRegistry.code.length == 0)
        ) {
            revert StreamFullV1StaticRendererPlan.InvalidStaticComposition();
        }
        StreamCollectionMetadataV1 metadata = StreamCollectionMetadataV1(c.metadata);
        StreamMetadataRouter router = StreamMetadataRouter(c.router);
        if (
            metadata.core() != c.core || metadata.schemaRegistry() != c.schemas
                || metadata.artistRegistry() != c.artist
                || metadata.governanceAuthority() != c.executor || address(router.core()) != c.core
                || router.governanceAuthority() != c.executor
                || S(c.schemas).governanceAuthority() != c.executor
                || IStreamArtistAttribution(c.artist).core() != c.core
                || IStreamFinalityScopeEvidence(c.finality).core() != c.core
                || IStreamGasParameterHost(c.finality).governanceAuthority() != c.executor
                || address(StreamEntropyCoordinator(payable(c.entropy)).core()) != c.core
                || StreamEntropyCoordinator(payable(c.entropy)).authority() != c.executor
        ) {
            revert StreamFullV1StaticRendererPlan.InvalidStaticComposition();
        }
    }

    // Mirrors StreamFullV1StaticRendererPlan._requiredTargets at the retained source anchor.
    function _requiredRendererTargets(
        StreamFullV1StaticRendererPlan.Configuration memory c,
        StreamFullV1StaticRendererPlan.Products memory p,
        V.Target[] memory targets
    ) private view {
        _rendererTarget(targets, c.core, keccak256("CORE"));
        _rendererTarget(targets, c.metadata, keccak256("COLLECTION_METADATA"));
        _rendererTarget(targets, c.router, keccak256("METADATA_COMPANION"));
        _rendererTarget(targets, c.entropy, keccak256("ENTROPY_COORDINATOR"));
        _rendererTarget(targets, address(p.attribution), keccak256("METADATA_COMPANION"));
        (address encoding, bytes32 codeHash) = p.renderer.encodingBinding();
        if (encoding.codehash != codeHash) {
            revert StreamFullV1StaticRendererPlan.InvalidStaticComposition();
        }
        _rendererTarget(targets, encoding, keccak256("METADATA_COMPANION"));
        if (c.dependencyRegistry != address(0)) {
            _rendererTarget(targets, c.dependencyRegistry, keccak256("DEPENDENCY_REGISTRY"));
        }
    }

    // Mirrors StreamFullV1StaticRendererPlan._target at the retained source anchor.
    function _rendererTarget(V.Target[] memory targets, address target, bytes32 role) private view {
        for (uint256 i; i < targets.length; ++i) {
            if (
                targets[i].target == target && targets[i].codeHash == target.codehash
                    && targets[i].role == role
            ) return;
        }
        revert StreamFullV1StaticRendererPlan.MissingStaticReadTarget(target);
    }

    /// @dev Same zero-value CREATE and raw constructor-revert propagation as ArtistArtifactCreate.
    function _create(string memory artifact, bytes memory arguments)
        private
        returns (address deployed)
    {
        StreamFullV1ArtifactVm artifactVm =
            StreamFullV1ArtifactVm(address(uint160(uint256(keccak256("hevm cheat code")))));
        bytes memory creation = artifactVm.getCode(artifact);
        require(creation.length != 0, "missing production creation artifact");
        bytes memory init = bytes.concat(creation, arguments);
        assembly ("memory-safe") {
            deployed := create(0, add(init, 32), mload(init))
            if iszero(deployed) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
        }
    }
}
