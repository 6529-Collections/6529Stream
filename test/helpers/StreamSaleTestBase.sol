// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../StreamCorePermanentTarget.t.sol";
import "../../smart-contracts/domains/mint/StreamMintManager.sol";
import "../../smart-contracts/domains/mint/StreamMintLedger.sol";
import "../../smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol";
import "../../smart-contracts/domains/revenue/StreamSplitFactory.sol";
import "../../smart-contracts/domains/artist/StreamCollectionArtistRegistry.sol";

/// @dev Actual Core, manager, ledger and splits; governance and entropy are boundary fixtures.
abstract contract StreamSaleTestBase is CharacterizationTestBase {
    uint256 internal constant PLATFORM_KEY = 0xA11CE;
    uint256 internal constant ARTIST_KEY = 0xB0B;
    bytes32 internal constant MANAGER_POINTER =
        0x136326f089f522351128a5fb79275bd12b2d84fe5bb50d5e46c9f5508d6df7e2;
    bytes32 internal constant ENTROPY_POINTER =
        0xb3b3ef20764c647bdeda70b21ab009ff2783106d6995be14389ec6f42ea6dfbb;

    PermanentTargetCoreHarness internal core;
    PermanentTargetGovernanceExecutor internal governance;
    PermanentTargetModuleRegistry internal registry;
    PermanentTargetEntropyCoordinator internal entropy;
    StreamMintManager internal manager;
    StreamMintLedger internal ledger;
    StreamSplitFactory internal factory;
    StreamCollectionArtistRegistry internal artistRegistry;
    bytes32 internal profile;
    address internal wallet;
    address internal artist;
    address internal platform;
    address internal protocol = address(0xFEE);
    bytes internal tokenData = bytes("ipfs://artist-token");

    function _setUpSaleFixture() internal {
        vm.deal(address(this), 100 ether);
        artist = vm.addr(ARTIST_KEY);
        platform = vm.addr(PLATFORM_KEY);
        governance = new PermanentTargetGovernanceExecutor();
        registry = new PermanentTargetModuleRegistry();
        _deployCore();
        entropy = new PermanentTargetEntropyCoordinator();
        ledger = new StreamMintLedger();
        manager = new StreamMintManager(core, ledger, IERC165(address(registry)));
        ledger.setLedgerWriter(address(manager), true);
        _install(MANAGER_POINTER, address(manager), type(IStreamMintManager).interfaceId);
        _install(ENTROPY_POINTER, address(entropy), type(IStreamEntropyCoordinator).interfaceId);
        _createCollection();
        _bindFixtureArtist(artist);
        factory = new StreamSplitFactory(new StreamAssetPolicyRegistry());
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](2);
        entries[0] = IStreamSplitWallet.SplitEntry(artist, 900_000, keccak256("artist"));
        entries[1] = IStreamSplitWallet.SplitEntry(protocol, 100_000, keccak256("protocol"));
        (profile, wallet) = factory.createProfile(entries, keccak256("profile-metadata"));
    }

    function _bindFixtureArtist(address nominee) internal {
        artistRegistry = new StreamCollectionArtistRegistry(
            address(core),
            address(this),
            keccak256("deploy"),
            "urn:test:artist",
            keccak256("artist module")
        );
        artistRegistry.nominateArtist(1, nominee, keccak256("artist identity"));
        bytes32 nomination = artistRegistry.attribution(1).nominationHash;
        vm.prank(nominee);
        artistRegistry.acceptArtist(1, nomination, 0, uint64(block.timestamp + 1 days), "");
        _install(
            keccak256("ARTIST_REGISTRY"),
            address(artistRegistry),
            type(IStreamCollectionArtistRegistry).interfaceId
        );
    }

    function _configureSalePhase(bytes32 phaseId, address executor) internal {
        bytes32[] memory counters = new bytes32[](1);
        counters[0] = keccak256("supply");
        IStreamMintManager.MintCounterConfig[] memory configs =
            new IStreamMintManager.MintCounterConfig[](1);
        configs[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            10,
            1,
            keccak256("counter")
        );
        IStreamMintManager.MintGateConfig memory gate;
        manager.configurePhase(
            1,
            phaseId,
            IStreamMintManager.MintPhaseConfig(
                false, 0, 0, 1, keccak256("phase"), keccak256("metadata")
            ),
            gate,
            counters,
            configs
        );
        manager.setPhaseExecutor(1, phaseId, executor, true);
    }

    function _deployCore() internal {
        StreamCore.GasParameterGenesisConfig[] memory gas =
            new StreamCore.GasParameterGenesisConfig[](4);
        gas[0] = StreamCore.GasParameterGenesisConfig(
            keccak256("6529STREAM_GGP_ROYALTY_RESOLVER_GAS_LIMIT"), 50_000, 25_000, 1
        );
        gas[1] = StreamCore.GasParameterGenesisConfig(
            keccak256("6529STREAM_GGP_ROYALTY_RETURN_GAS_BUFFER"), 2_910_000, 1_460_000, 1
        );
        gas[2] = StreamCore.GasParameterGenesisConfig(
            keccak256("6529STREAM_GGP_METADATA_ROUTER_GAS_LIMIT"), 500_000, 250_000, 1
        );
        gas[3] = StreamCore.GasParameterGenesisConfig(
            keccak256("6529STREAM_GGP_ENTROPY_REGISTRATION_GAS_LIMIT"), 120_000, 120_000, 2
        );
        core = new PermanentTargetCoreHarness(
            "Stream",
            "STREAM",
            address(governance),
            StreamCore.GenesisModuleRegistryConfig(
                address(registry),
                address(registry).codehash,
                keccak256("registry"),
                keccak256("deploy")
            ),
            gas
        );
    }

    function _install(bytes32 pointerType, address target, bytes4 interfaceId) internal {
        registry.setRecord(
            target, pointerType, interfaceId, keccak256("module"), keccak256("deploy")
        );
        StreamCorePointerState memory previous = core.pointerState(pointerType);
        StreamCorePointerState memory candidate = StreamCorePointerState(
            target,
            target.codehash,
            false,
            pointerType,
            interfaceId,
            address(registry),
            1,
            keccak256("module"),
            keccak256("deploy"),
            previous.revision + 1
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            core.pointerTransitionHashes(pointerType, previous, candidate);
        governance.setAction(3, scope, oldHash, newHash);
        governance.execute(
            address(core), abi.encodeCall(core.updateSatellitePointer, (pointerType, target))
        );
    }

    function _createCollection() internal {
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x3a882a22dad9915c9193738f63216234155080ed4c4fc9bfae446e90f1df6e16),
                block.chainid,
                address(core),
                uint256(1)
            )
        );
        bytes32 domain = 0x854c83f82b7677e58c61a2482a7a430a8318d765d99a95d3fbce5c84be6cc2b5;
        bytes32 oldHash =
            keccak256(abi.encode(domain, scope, false, uint8(0), uint8(0), false, uint256(0)));
        bytes32 newHash =
            keccak256(abi.encode(domain, scope, true, uint8(0), uint8(0), true, uint256(10)));
        governance.setAction(1, scope, oldHash, newHash);
        governance.execute(
            address(core),
            abi.encodeCall(core.createCollection, (uint8(0), true, uint256(10), uint8(0)))
        );
    }
}
