// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CurrentERC20ConservationFixture.sol";
import "./EntropyTimeTestMocks.sol";
import "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import "../../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol";
import "../../smart-contracts/domains/entropy/StreamEntropyProviderInstant.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistContentHostEvidence.sol";

/// @dev Typed Artist boundary only: inherited mint/sale consent plus exact pre-recorded op17 terms.
/// This does not exercise Artist signatures, owner archives, or the governance timelock.
contract CurrentERC20EntropyArtist is NativeAuctionArtist {
    address private immutable controller;
    mapping(bytes32 => bytes32) private records;

    constructor(address source, address manager_) NativeAuctionArtist(source, manager_) {
        controller = msg.sender;
    }

    function supportsInterface(bytes4 id) public pure override returns (bool) {
        return
            id == type(IStreamArtistContentHostEvidence).interfaceId || super.supportsInterface(id);
    }

    function approveEntropyContent(address host, bytes32 stateHash, bytes32 record) external {
        require(msg.sender == controller && host != address(0) && record != 0, "fixture controller");
        records[
            keccak256(
                abi.encode(
                    uint256(1), host, keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1"), stateHash
                )
            )
        ] = record;
    }

    function gasParameterInfo(bytes32 id) external pure returns (uint256, uint256, uint8, uint64) {
        require(id == keccak256("6529STREAM_GGP_ARTIST_FINALITY_READ_GAS"), "exact Artist budget");
        return (600_000, 100_000, 2, 1);
    }

    function contentConsentEvidenceForHost(
        uint256 id,
        address host,
        bytes32 family,
        bytes32 stateHash
    ) external view returns (bytes32) {
        require(msg.sender == host, "only original content host");
        return records[keccak256(abi.encode(id, host, family, stateHash))];
    }
}

/// @dev Actual Core recipient callback, with controlled acceptance after observing real entropy state.
contract CurrentERC20EntropyReceiver is IERC721Receiver {
    StreamCore private immutable core;
    StreamEntropyCoordinator private immutable coordinator;
    address private immutable controller;
    bytes32 private immutable policyHash;
    StreamEntropyStatus private immutable expectedStatus;
    bool public accepting;
    uint256 public deliveries;

    error EntropyRecipientRejected(bytes32 observedPolicy, uint8 observedStatus, uint256 tokenId);

    constructor(
        StreamCore core_,
        StreamEntropyCoordinator coordinator_,
        bytes32 hash_,
        StreamEntropyStatus status_
    ) {
        core = core_;
        coordinator = coordinator_;
        controller = msg.sender;
        policyHash = hash_;
        expectedStatus = status_;
    }

    function accept() external {
        require(msg.sender == controller, "recipient controller");
        accepting = true;
    }

    function onERC721Received(address, address from, uint256 id, bytes calldata)
        external
        returns (bytes4)
    {
        require(
            msg.sender == address(core) && from == address(0) && id == 1,
            "original Core mint callback"
        );
        IStreamEntropyCollectionPolicy.PolicyRecord memory p =
            coordinator.collectionEntropyPolicy(1);
        require(
            core.ownerOf(id) == address(this) && core.coordinatorAtMint(id) == address(coordinator)
                && core.tokenLifecycle(id) == 2 && p.frozen && p.policyHash == policyHash
                && coordinator.tokenEntropyStatus(id) == expectedStatus
                && coordinator.registeredAtBlock(id) == block.number
                && coordinator.pendingRequestCount() == 0,
            "real policy registration precedes recipient callback"
        );
        ++deliveries;
        if (!accepting) revert EntropyRecipientRejected(p.policyHash, uint8(expectedStatus), id);
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice Actual Core/Manager/Ledger/registry/roles/revenue and the original production Coordinator.
/// @dev Reuses inherited deployment utilities, but selects the real Coordinator FIRST: replacing the
/// base fixture's old entropy mock would fail genuine successor-continuity admission. Artist evidence
/// and governance execution context remain typed fixtures. No production state is etched or stored.
abstract contract CurrentERC20EntropyModesFixture is CurrentERC20ConservationFixture {
    StreamEntropyCoordinator internal actualEntropy;

    function _deployAuctionArtist() internal override returns (NativeAuctionArtist) {
        return new CurrentERC20EntropyArtist(address(core), address(manager));
    }

    function setUp() public virtual override {
        vm.warp(1000);
        payer = vm.addr(PAYER_KEY);
        revenueAuthority = new NativeAuctionAuthority();
        registry = StreamModuleRegistry(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/modules/StreamModuleRegistry.sol:StreamModuleRegistry",
                    abi.encode(
                        IStreamGovernanceExecutor(address(revenueAuthority)),
                        MANIFEST,
                        "urn:prepared:registry"
                    )
                ))
        );
        StreamCore.GasParameterGenesisConfig[] memory gasRows =
            new StreamCore.GasParameterGenesisConfig[](4);
        gasRows[0] = StreamCore.GasParameterGenesisConfig(
            keccak256("6529STREAM_GGP_ROYALTY_RESOLVER_GAS_LIMIT"), 50000, 25000, 1
        );
        gasRows[1] = StreamCore.GasParameterGenesisConfig(
            keccak256("6529STREAM_GGP_ROYALTY_RETURN_GAS_BUFFER"), 2910000, 1460000, 1
        );
        gasRows[2] = StreamCore.GasParameterGenesisConfig(
            keccak256("6529STREAM_GGP_METADATA_ROUTER_GAS_LIMIT"), 500000, 250000, 1
        );
        gasRows[3] = StreamCore.GasParameterGenesisConfig(
            keccak256("6529STREAM_GGP_ENTROPY_REGISTRATION_GAS_LIMIT"), 1_920_000, 120000, 2
        );
        core = StreamCore(
            payable(_artistArtifactCreate(
                    "smart-contracts/core/StreamCore.sol:StreamCore",
                    abi.encode(
                        "Prepared Current",
                        "PPC",
                        address(revenueAuthority),
                        StreamCore.GenesisModuleRegistryConfig(
                            address(registry), address(registry).codehash, MANIFEST, MANIFEST
                        ),
                        gasRows
                    )
                ))
        );
        ledger = StreamMintLedger(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/mint/StreamMintLedger.sol:StreamMintLedger",
                    abi.encode()
                ))
        );
        manager = StreamMintManager(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/mint/StreamMintManager.sol:StreamMintManager",
                    abi.encode(core, ledger, IERC165(address(registry)))
                ))
        );
        ledger.setLedgerWriter(address(manager), true);
        _register(
            address(registry),
            keccak256("MODULE_REGISTRY"),
            type(IStreamModuleRegistry).interfaceId,
            MANIFEST
        );
        _register(
            address(manager),
            keccak256("MINT_MANAGER"),
            type(IStreamMintManager).interfaceId,
            MANIFEST
        );
        _pointer(keccak256("MINT_MANAGER"), address(manager));
        artists = _deployAuctionArtist();
        _register(
            address(artists),
            keccak256("ARTIST_REGISTRY"),
            type(IStreamArtistMintConsent).interfaceId,
            MANIFEST
        );
        _pointer(keccak256("ARTIST_REGISTRY"), address(artists));
        auctionRoles = StreamRoleRegistry(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/governance/StreamRoleRegistry.sol:StreamRoleRegistry",
                    abi.encode(address(revenueAuthority))
                ))
        );
        NativeAuctionAuthority(address(revenueAuthority)).setRoleRegistry(address(auctionRoles));
        actualEntropy = StreamEntropyCoordinator(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/entropy/StreamEntropyCoordinator.sol:StreamEntropyCoordinator",
                    abi.encode(
                        StreamEntropyCoordinator.DeploymentConfig(
                            address(core),
                            address(revenueAuthority),
                            address(auctionRoles),
                            EntropyTimeTestConfigs.parameters(),
                            MANIFEST,
                            "urn:erc20:actual-entropy",
                            MANIFEST
                        )
                    )
                ))
        );
        _register(
            address(actualEntropy),
            keccak256("ENTROPY_COORDINATOR"),
            type(IStreamEntropyCoordinator).interfaceId,
            MANIFEST
        );
        _pointer(keccak256("ENTROPY_COORDINATOR"), address(actualEntropy));
        _collection();
        policy = StreamAssetPolicyRegistry(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol:StreamAssetPolicyRegistry",
                    abi.encode(address(revenueAuthority))
                ))
        );
        IStreamGasParameterHost.GasParameterConfig[3] memory config = _walletGasConfigs();
        config[2].genesisValue = 500000;
        factory = StreamSplitFactory(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/revenue/StreamSplitFactory.sol:StreamSplitFactory",
                    abi.encode(policy, address(revenueAuthority), config)
                ))
        );
        resolver = StreamRevenueResolver(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/revenue/StreamRevenueResolver.sol:StreamRevenueResolver",
                    abi.encode(
                        core,
                        factory,
                        address(revenueAuthority),
                        artists,
                        IStreamGasParameterHost.GasParameterConfig(
                            "ARTIST_BENEFICIARY_READ_GAS", 200000, 50000, 2
                        )
                    )
                ))
        );
        vm.prank(address(revenueAuthority));
        resolver.transferOwnership(address(this));
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] =
            IStreamSplitWallet.SplitEntry(vm.addr(SIGNER_KEY), 1000000, keccak256("artist"));
        (profile, wallet) = factory.createProfile(entries, keccak256("prepared rights"));
        resolver.setPrimaryProfileAssignment(CLASS, 1, 1, profile, 0);
        artists.accept(vm.addr(SIGNER_KEY));
        escrow = StreamRevenueEscrow(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/revenue/StreamRevenueEscrow.sol:StreamRevenueEscrow",
                    abi.encode(
                        factory,
                        address(revenueAuthority),
                        IStreamGasParameterHost.GasParameterConfig(
                            "FLUSH_GAS_FLOOR", 12000000, 12000000, 3
                        )
                    )
                ))
        );
        recorder = StreamPrimarySaleSettlement(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol:StreamPrimarySaleSettlement",
                    abi.encode(resolver, address(registry), escrow)
                ))
        );
        _register(
            address(recorder),
            keccak256("PRIMARY_SALE_SETTLEMENT"),
            type(IStreamPreparedNativePrimarySaleSettlement).interfaceId,
            keccak256("6529STREAM_PREPARED_NATIVE_SETTLEMENT_V1")
        );
        (bytes32 scope, bytes32 oldState, bytes32 newState) =
            escrow.creditProducerTransitionHashes(address(recorder), true);
        _context(scope, oldState, newState, 1);
        vm.prank(address(revenueAuthority));
        escrow.setCreditProducer(address(recorder), true);
        _clearContext();
        manager.bindPreparedNativeRecorder(address(recorder));
        _enableCurrentERC20Floor();
        vm.roll(100);
        require(
            address(core).code.length <= 24576 && address(manager).code.length <= 24576
                && address(recorder).code.length <= 24576
                && address(actualEntropy).code.length <= 24576,
            "reached current production products fit EIP170"
        );
    }
}
