// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOwner } from "../../smart-contracts/domains/artist/StreamArtistOwner.sol";
import {
    StreamArtistHydrationGuards as RealGuards
} from "../../smart-contracts/domains/artist/StreamArtistHydrationGuards.sol";
import {
    StreamArtistRecoveredHydrationState as ImportedState
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationState.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

interface MetadataReadCostVm {
    function getNonce(address) external view returns (uint64);
}

/// @dev Actual Owner immutables, original guard/commit and namespace producers/readers.
/// Only this fixture's matching Coordinator may install the explicitly typed source prefix.
contract MetadataRealReadOwner is StreamArtistOwner {
    uint8 private immutable index;

    constructor(T.SuiteConfiguration memory s, address coordinator, uint8 i)
        StreamArtistOwner(
            s.registry, coordinator, s.archive, RH.ownerDomain(i), s.core, s.mintManager
        )
    {
        index = i;
    }

    function installFixturePrefix(
        T.ActionContext calldata c,
        RH.OwnerProvenance calldata p,
        bytes32 completed,
        bool omitPrefix
    ) external {
        _check(c, 60);
        AH.OwnerData memory empty;
        bytes32 delta = RealGuards.applyGuards(
            _replay, empty, artistRegistry, operationCoordinator, archiveV2, domainId, completed
        );
        if (!omitPrefix) {
            ImportedState.installOwnerPrefix(p, index, completed, c.expected.revision + 1);
        }
        _commit(c, keccak256("typed source admission"), completed, delta, bytes32(0));
    }
}

/// @dev Typed Coordinator boundary, NOT an operation60 source-authority implementation.
/// Matches actual storage suite plus immutable configuration/finality/provider getter shapes.
/// Configuration preimage is independently copied from the actual original constructor.
contract MetadataImmutableReadCoordinator {
    T.SuiteConfiguration private suite;
    address private immutable fixture;
    uint256 public immutable deploymentChainId = block.chainid;
    bytes32 public immutable configurationHash;
    address public immutable finalityRegistry;
    address public immutable finalityEvidenceProvider;

    constructor(T.SuiteConfiguration memory s) {
        fixture = msg.sender;
        address[16] memory targets;
        bytes32[16] memory runtimeHashes;
        for (uint256 i; i < 7; ++i) {
            StreamArtistOwner owner = StreamArtistOwner(s.owners[i]);
            require(
                owner.artistRegistry() == s.registry
                    && owner.operationCoordinator() == address(this)
                    && owner.archiveV2() == s.archive && owner.core() == s.core
                    && owner.mintManager() == s.mintManager
                    && owner.deploymentChainId() == block.chainid
                    && owner.domainId() == RH.ownerDomain(uint8(i)),
                "constructor owner binding"
            );
            targets[i] = s.owners[i];
        }
        suite = s;
        targets[7] = s.registry;
        targets[8] = s.archive;
        targets[9] = s.core;
        targets[10] = s.mintManager;
        targets[11] = s.roleRegistry;
        targets[12] = s.metadata;
        targets[13] = s.primaryResolver;
        targets[14] = s.royaltyResolver;
        targets[15] = s.validator;
        for (uint256 i; i < 16; ++i) {
            require(targets[i].code.length != 0 && targets[i] != address(this), "target");
            for (uint256 j; j < i; ++j) {
                require(targets[j] != targets[i], "duplicate target");
            }
            runtimeHashes[i] = targets[i].codehash;
        }
        address finalityRegistry_ = s.archive;
        address provider = s.validator;
        bytes32 providerCodeHash = provider.codehash;
        finalityRegistry = finalityRegistry_;
        finalityEvidenceProvider = provider;
        configurationHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_CONFIGURATION_V1"),
                block.chainid,
                address(this),
                s,
                runtimeHashes,
                finalityRegistry_,
                finalityRegistry_.codehash,
                provider,
                providerCodeHash,
                uint16(1),
                uint16(2),
                uint16(3),
                uint16(4),
                uint16(5),
                uint16(6),
                uint16(7),
                uint16(12),
                uint16(13),
                uint16(14),
                uint16(15),
                uint16(16),
                uint16(17),
                uint16(18),
                uint16(20),
                uint16(21),
                uint16(22),
                uint16(23),
                uint16(24),
                uint16(25),
                uint16(26),
                uint16(27),
                uint16(28),
                uint16(29),
                uint16(30),
                uint16(31),
                uint16(32),
                uint16(33),
                uint16(34),
                uint16(35),
                uint16(36),
                uint16(37),
                uint16(38),
                uint16(39),
                uint16(40),
                uint16(51),
                uint16(52),
                uint16(54),
                uint16(58),
                uint16(65534),
                keccak256("6529STREAM_ARTIST_RECOVERY_PREPARATION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_RECOVERY_GUARDIAN_HISTORY_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_RECOVERY_FIRST_ROTATION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_RECOVERY_HISTORICAL_ROTATION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_GUARDIAN_SUPERSESSION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_GUARDIAN_HEAD_SELECTION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_GUARDIAN_ROOT_APPEAL_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_FIRST_ESTATE_RECOVERY_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_ESTATE_SUCCESSOR_GUARDIAN_RECOVERY_PROFILE_V1")
            )
        );
    }

    function suiteConfiguration() external view returns (T.SuiteConfiguration memory) {
        return suite;
    }

    function installFixturePrefix(
        RH.OriginEnvironment memory original,
        bytes32 completed,
        uint8 omitIndex,
        uint8 wrongIndex
    ) external {
        require(msg.sender == fixture, "fixture producer");
        for (uint8 i; i < 7; ++i) {
            RH.OwnerProvenance memory p;
            p.origins = new RH.OriginEnvironment[](1);
            p.origins[0] = original;
            p.eras = new RH.OwnerEra[](1);
            p.eras[0].originHash = RH.originHash(original);
            p.eras[0].checkpoint.schema = RH.CHECKPOINT;
            p.eras[0].checkpoint.ownerState =
                T.Snapshot(RH.ownerDomain(i), 12, bytes32(uint256(300)), bytes32(uint256(301)));
            MetadataRealReadOwner owner = MetadataRealReadOwner(suite.owners[i]);
            owner.installFixturePrefix(
                T.ActionContext(60, fixture, owner.ownerStateSnapshotV2()),
                p,
                i == wrongIndex ? keccak256("wrong completion") : completed,
                i == omitIndex
            );
        }
    }
}

library MetadataRealOwnerReadDeployment {
    function deploy(address vm_, T.SuiteConfiguration memory s)
        internal
        returns (T.SuiteConfiguration memory, MetadataImmutableReadCoordinator coordinator)
    {
        uint256 nonce = uint256(MetadataReadCostVm(vm_).getNonce(address(this))) + 7;
        require(nonce > 0 && nonce < 128, "fixed test CREATE nonce range");
        address predicted = address(
            uint160(uint256(keccak256(abi.encodePacked(hex"d694", address(this), uint8(nonce)))))
        );
        for (uint8 i; i < 7; ++i) {
            s.owners[i] = address(new MetadataRealReadOwner(s, predicted, i));
        }
        coordinator = new MetadataImmutableReadCoordinator(s);
        require(address(coordinator) == predicted, "actual CREATE/coordinator identity");
        return (s, coordinator);
    }
}
