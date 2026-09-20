// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamStaticArtistLineageSource as I
} from "../../interfaces/stream/metadata/IStreamStaticArtistLineageSource.sol";
import {
    IStreamStaticArtistLineageFacts as F
} from "../../interfaces/stream/artist/IStreamStaticArtistLineageFacts.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamMetadataArtistConfiguration as Configuration
} from "./StreamMetadataArtistConfiguration.sol";
import { StreamMetadataRecoveryRoutes as Routes } from "./StreamMetadataRecoveryRoutes.sol";
import { IStreamCorePointers } from "../../interfaces/stream/core/IStreamCorePointers.sol";
import { StreamArtistStaticCalls as Calls } from "../artist/StreamArtistStaticCalls.sol";

/// @notice Current authority through an explicit, immutable catalogue of complete actual suites.
/// @dev Catalogue membership is not Renderer admission. Every reached suite/selector must also
/// be covered by the selected version's governed STATIC read roster. No dynamic target fallback.
contract StreamStaticArtistLineageSource is I {
    struct Entry {
        address coordinator;
        bytes32 coordinatorHash;
        address finality;
        bytes32 finalityHash;
        address provider;
        bytes32 providerHash;
        bytes32 configurationHash;
        T.SuiteConfiguration suite;
        bytes32[16] runtimes;
    }
    address public immutable core;
    address public immutable router;
    address public immutable originalArtist;
    bytes32 public immutable originalArtistCodeHash;
    uint256 public immutable sourceChainId;
    bytes32 public immutable catalogueHash;
    bytes32 public immutable originalOriginHash;
    Entry[] private _entries;
    mapping(address => uint256) private _indexPlusOne;
    uint256 private constant CAP = 100000;
    error InvalidStaticArtistLineage();

    constructor(address core_, address router_, address[] memory coordinators) {
        if (
            core_.code.length == 0 || router_.code.length == 0 || coordinators.length == 0
                || coordinators.length > 8
        ) _fail();
        core = core_;
        router = router_;
        sourceChainId = block.chainid;
        bytes32 folded = keccak256(
            abi.encode(
                keccak256("6529STREAM_STATIC_ARTIST_LINEAGE_CATALOGUE_V1"),
                block.chainid,
                core_,
                router_
            )
        );
        for (uint256 i; i < coordinators.length; ++i) {
            Entry memory e = _capture(coordinators[i]);
            if (
                e.suite.core != core_ || e.suite.metadata != router_
                    || _indexPlusOne[e.suite.registry] != 0
            ) _fail();
            if (i != 0) _sameDependencies(_entries[0].suite, e.suite);
            _entries.push(e);
            _indexPlusOne[e.suite.registry] = i + 1;
            folded = keccak256(abi.encode(folded, e));
        }
        originalArtist = _entries[0].suite.registry;
        originalArtistCodeHash = _entries[0].runtimes[7];
        Entry memory first = _entries[0];
        RH.OriginEnvironment memory origin;
        origin.chainId = block.chainid;
        origin.registry = first.suite.registry;
        origin.coordinator = first.coordinator;
        origin.archive = first.suite.archive;
        origin.owners = first.suite.owners;
        for (uint256 i; i < 7; ++i) {
            origin.ownerCodeHashes[i] = first.runtimes[i];
        }
        origin.core = core_;
        origin.manager = first.suite.mintManager;
        origin.suiteConfigurationHash = keccak256(abi.encode(first.suite));
        originalOriginHash = RH.originHash(origin);
        catalogueHash = folded;
    }

    function catalogueCount() external view returns (uint256) {
        return _entries.length;
    }

    function catalogueSuite(uint256 index) external view returns (T.SuiteConfiguration memory) {
        return _entries[index].suite;
    }

    function catalogueEntry(uint256 index) external view returns (Entry memory) {
        return _entries[index];
    }

    function currentSuite() external view returns (T.SuiteConfiguration memory suite) {
        if (block.chainid != sourceChainId) _fail();
        Routes.Pointer memory p = _pointer(keccak256("ARTIST_REGISTRY"));
        uint256 plus = _indexPlusOne[p.target];
        if (plus == 0 || p.status != 1 || p.revision == 0) _fail();
        Entry memory current = _entries[plus - 1];
        _pins(current);
        if (p.codeHash != current.runtimes[7]) _fail();
        suite = current.suite;
        Routes.Pointer memory metadata = _pointer(keccak256("METADATA_ROUTER"));
        if (
            metadata.target != router || metadata.codeHash != current.runtimes[12]
                || metadata.status != 1 || metadata.revision == 0
        ) _fail();
        if (_address(router, "core()") != core) _fail();
        if (plus == 1) return suite;
        Entry memory original = _entries[0];
        _pins(original);
        // Immediate predecessor remains isSealed to this exact target even for repeated imports.
        F.Lineage memory b = abi.decode(
            _read(suite.owners[2], abi.encodeCall(F.staticArtistLineage, (bytes32(0))), 480),
            (F.Lineage)
        );
        uint256 priorPlus = _indexPlusOne[b.predecessor];
        if (
            b.bindingCount != 1 || b.predecessorCount != 1 || priorPlus == 0 || priorPlus == plus
                || b.snapshotBlock == 0 || b.importRoot == 0 || b.manifestHash == 0
        ) _fail();
        Entry memory prior = _entries[priorPlus - 1];
        _pins(prior);
        if (b.predecessorCodeHash != prior.runtimes[7]) _fail();
        F.Lineage memory seal = abi.decode(
            _read(prior.suite.owners[2], abi.encodeCall(F.staticArtistLineage, (bytes32(0))), 480),
            (F.Lineage)
        );
        if (
            !seal.isSealed || seal.successor != suite.registry || seal.sealedAt == 0
                || b.snapshotBlock > seal.sealedAt
        ) _fail();
        bytes32 completion;
        for (uint256 i; i < 7; ++i) {
            bytes32 value = abi.decode(
                _read(suite.owners[i], abi.encodeCall(F.authorityHydrationCommitment, ()), 32),
                (bytes32)
            );
            if (value == 0 || (i != 0 && value != completion)) _fail();
            completion = value;
        }
        if (priorPlus != 1) {
            F.Lineage memory imported = abi.decode(
                _read(
                    suite.owners[2],
                    abi.encodeCall(F.staticArtistLineage, (originalOriginHash)),
                    480
                ),
                (F.Lineage)
            );
            if (
                imported.originHash != originalOriginHash || imported.importCommitment != completion
                    || imported.importedAtRevision == 0 || imported.ownerIndex != 2
                    || imported.originProfile != RH.PROFILE
            ) _fail();
        }
    }

    function _capture(address coordinator) private view returns (Entry memory e) {
        if (coordinator.code.length == 0) _fail();
        e.coordinator = coordinator;
        e.coordinatorHash = coordinator.codehash;
        // Ordinary constructor discovery only; serving never invokes the delegated suite codec.
        bytes memory raw = _read(coordinator, abi.encodeWithSignature("suiteConfiguration()"), 544);
        e.suite = abi.decode(raw, (T.SuiteConfiguration));
        if (keccak256(raw) != keccak256(abi.encode(e.suite))) _fail();
        e.finality = _address(coordinator, "finalityRegistry()");
        e.provider = _address(coordinator, "finalityEvidenceProvider()");
        if (e.finality.code.length == 0 || e.provider.code.length == 0) _fail();
        e.finalityHash = e.finality.codehash;
        e.providerHash = e.provider.codehash;
        (e.configurationHash, e.runtimes) =
            Configuration.hashAndRuntime(coordinator, e.suite, e.finality, e.provider);
        if (
            _word(coordinator, "configurationHash()") != e.configurationHash
                || _address(e.suite.registry, "operationCoordinator()") != coordinator
                || _address(e.suite.registry, "core()") != e.suite.core
        ) _fail();
        for (uint256 i; i < 7; ++i) {
            address owner = e.suite.owners[i];
            if (
                _address(owner, "artistRegistry()") != e.suite.registry
                    || _address(owner, "operationCoordinator()") != coordinator
                    || _address(owner, "archiveV2()") != e.suite.archive
                    || _address(owner, "core()") != e.suite.core
                    || _address(owner, "mintManager()") != e.suite.mintManager
                    || uint256(_word(owner, "deploymentChainId()")) != block.chainid
            ) _fail();
        }
    }

    function _pins(Entry memory e) private view {
        if (
            e.coordinator.codehash != e.coordinatorHash || e.finality.codehash != e.finalityHash
                || e.provider.codehash != e.providerHash
                || _word(e.coordinator, "configurationHash()") != e.configurationHash
        ) _fail();
        address[16] memory targets;
        for (uint256 i; i < 7; ++i) {
            targets[i] = e.suite.owners[i];
        }
        targets[7] = e.suite.registry;
        targets[8] = e.suite.archive;
        targets[9] = e.suite.core;
        targets[10] = e.suite.mintManager;
        targets[11] = e.suite.roleRegistry;
        targets[12] = e.suite.metadata;
        targets[13] = e.suite.primaryResolver;
        targets[14] = e.suite.royaltyResolver;
        targets[15] = e.suite.validator;
        for (uint256 i; i < 16; ++i) {
            if (targets[i].code.length == 0 || targets[i].codehash != e.runtimes[i]) _fail();
        }
    }

    function _sameDependencies(T.SuiteConfiguration memory a, T.SuiteConfiguration memory b)
        private
        pure
    {
        if (
            a.core != b.core || a.mintManager != b.mintManager || a.roleRegistry != b.roleRegistry
                || a.metadata != b.metadata || a.primaryResolver != b.primaryResolver
                || a.royaltyResolver != b.royaltyResolver
                || a.primaryRevenueClass != b.primaryRevenueClass || a.validator != b.validator
        ) _fail();
    }

    function _pointer(bytes32 key) private view returns (Routes.Pointer memory) {
        return abi.decode(
            _read(core, abi.encodeCall(IStreamCorePointers.getSatellitePointer, (key)), 320),
            (Routes.Pointer)
        );
    }

    function _address(address target, string memory signature) private view returns (address) {
        return abi.decode(_read(target, abi.encodeWithSignature(signature), 32), (address));
    }

    function _word(address target, string memory signature) private view returns (bytes32) {
        return abi.decode(_read(target, abi.encodeWithSignature(signature), 32), (bytes32));
    }

    function _read(address target, bytes memory data, uint256 length)
        private
        view
        returns (bytes memory)
    {
        return Calls.fixedRead(target, data, length, CAP);
    }

    function _fail() private pure {
        revert InvalidStaticArtistLineage();
    }
}
