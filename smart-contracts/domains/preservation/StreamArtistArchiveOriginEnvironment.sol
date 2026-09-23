// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as A
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistIngressBinding
} from "../../interfaces/stream/artist/IStreamArtistIngressBinding.sol";
import {
    IStreamArtistSuiteReads
} from "../../interfaces/stream/artist/IStreamArtistSuiteReads.sol";
import { IStreamArtistArchiveV2 } from "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import {
    IStreamArtistAuthorityHydrationOwner
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamRecordArtistIdentityReads as Identity
} from "../records/StreamRecordArtistIdentityReads.sol";
import {
    StreamMetadataArtistConfiguration as Configuration
} from "../metadata/StreamMetadataArtistConfiguration.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";

/// @notice Fixed configuration and reciprocal-runtime joins for the additive Archive profile.
/// @dev No caller-selected calls, prefix scan or mutable semantic-owner writes.
library StreamArtistArchiveOriginEnvironment {
    struct Context {
        O.Origin origin;
        A.SuiteConfiguration suite;
        bytes32 completion;
    }

    function current(S.Dependencies memory d) public view returns (Context memory c) {
        if (d.chainId != block.chainid) revert O.InvalidArchiveOrigin();
        for (uint256 i; i < 12; ++i) {
            IO.pin(d.targets[i], d.codeHashes[i]);
        }
        for (uint256 i; i < 5; ++i) {
            IO.pin(d.artistTargets[i], d.artistCodeHashes[i]);
        }
        IO.pin(d.artistContentOwner, d.artistContentOwnerCodeHash);
        Identity.Pins memory pins =
            Identity.resolveCurrent(d.targets[1], d.targets[0], d.chainId, d.readGas);
        for (uint256 i; i < 3; ++i) {
            if (
                pins.targets[i] != d.artistTargets[i] || pins.codeHashes[i] != d.artistCodeHashes[i]
            ) revert O.InvalidArchiveOrigin();
        }
        (c.origin, c.suite) = configured(d, pins.targets[0], pins.codeHashes[0]);
        if (
            c.origin.environment.coordinator != pins.targets[1]
                || c.suite.owners[2] != pins.targets[2] || c.suite.owners[4] != d.artistTargets[3]
                || c.suite.archive != d.artistTargets[4]
                || c.suite.owners[6] != d.artistContentOwner
        ) revert O.InvalidArchiveOrigin();
        for (uint256 i; i < 7; ++i) {
            bytes32 actual = IO.word(
                c.suite.owners[i],
                abi.encodeCall(
                    IStreamArtistAuthorityHydrationOwner.authorityHydrationCommitment, ()
                ),
                d.readGas
            );
            if (i != 0 && actual != c.completion) revert O.InvalidArchiveOrigin();
            c.completion = actual;
        }
        address original = IO.addressWord(
            d.targets[1], abi.encodeCall(IStreamArtistOwner.artistRegistry, ()), d.readGas
        );
        if (original != c.suite.registry && c.completion == 0) revert O.InvalidArchiveOrigin();
    }

    /// @dev The registry/runtime is already rooted in current selection or a saved original
    /// certificate. A coherent arbitrary registry alone cannot authorize an origin.
    function configured(S.Dependencies memory d, address registry, bytes32 registryHash)
        public
        view
        returns (O.Origin memory origin, A.SuiteConfiguration memory suite)
    {
        IO.pin(registry, registryHash);
        address coordinator = IO.addressWord(
            registry,
            abi.encodeCall(IStreamArtistIngressBinding.operationCoordinator, ()),
            d.readGas
        );
        if (coordinator.code.length == 0) revert O.InvalidArchiveOrigin();
        suite = Configuration.suite(coordinator, d.readGas);
        if (
            suite.registry != registry || suite.core != d.targets[0]
                || suite.metadata != d.targets[4]
                || IO.word(
                        coordinator,
                        abi.encodeCall(IStreamArtistSuiteReads.deploymentChainId, ()),
                        d.readGas
                    ) != bytes32(d.chainId)
                || IO.addressWord(registry, abi.encodeCall(IStreamArtistOwner.core, ()), d.readGas)
                    != suite.core
                || IO.addressWord(
                        suite.archive,
                        abi.encodeCall(IStreamArtistArchiveV2.artistRegistry, ()),
                        d.readGas
                    ) != registry
                || IO.addressWord(
                        suite.archive,
                        abi.encodeCall(IStreamArtistArchiveV2.operationCoordinator, ()),
                        d.readGas
                    ) != coordinator
        ) revert O.InvalidArchiveOrigin();
        RH.OriginEnvironment memory e;
        e.chainId = d.chainId;
        e.registry = registry;
        e.coordinator = coordinator;
        e.archive = suite.archive;
        e.owners = suite.owners;
        e.core = suite.core;
        e.manager = suite.mintManager;
        e.suiteConfigurationHash = keccak256(abi.encode(suite));
        for (uint8 i; i < 7; ++i) {
            e.ownerCodeHashes[i] = suite.owners[i].codehash;
            _owner(e, i, d.readGas);
        }
        origin = O.Origin(e, registryHash, coordinator.codehash, suite.archive.codehash);
    }

    function imported(
        S.Dependencies memory d,
        Context memory current_,
        RH.OriginEnvironment memory saved
    ) public view returns (O.Origin memory origin) {
        A.SuiteConfiguration memory suite;
        (origin, suite) = configured(d, saved.registry, saved.registry.codehash);
        if (
            saved.registry == current_.suite.registry || saved.chainId != d.chainId
                || keccak256(abi.encode(origin.environment)) != keccak256(abi.encode(saved))
        ) revert O.InvalidArchiveOrigin();
        sameDependencies(suite, current_.suite);
    }

    function sameDependencies(A.SuiteConfiguration memory a, A.SuiteConfiguration memory b)
        internal
        pure
    {
        if (
            a.core != b.core || a.mintManager != b.mintManager || a.roleRegistry != b.roleRegistry
                || a.metadata != b.metadata || a.primaryResolver != b.primaryResolver
                || a.royaltyResolver != b.royaltyResolver
                || a.primaryRevenueClass != b.primaryRevenueClass || a.validator != b.validator
        ) revert O.InvalidArchiveOrigin();
    }

    function _owner(RH.OriginEnvironment memory e, uint8 index, uint256 cap) private view {
        address owner = e.owners[index];
        IO.pin(owner, e.ownerCodeHashes[index]);
        for (uint8 prior; prior < index; ++prior) {
            if (e.owners[prior] == owner) revert O.InvalidArchiveOrigin();
        }
        if (
            IO.addressWord(owner, abi.encodeCall(IStreamArtistOwner.artistRegistry, ()), cap)
                    != e.registry
                || IO.addressWord(
                        owner, abi.encodeCall(IStreamArtistOwner.operationCoordinator, ()), cap
                    ) != e.coordinator
                || IO.addressWord(owner, abi.encodeCall(IStreamArtistOwner.archiveV2, ()), cap)
                    != e.archive
                || IO.addressWord(owner, abi.encodeCall(IStreamArtistOwner.core, ()), cap) != e.core
                || IO.addressWord(owner, abi.encodeCall(IStreamArtistOwner.mintManager, ()), cap)
                    != e.manager
                || IO.word(owner, abi.encodeCall(IStreamArtistOwner.deploymentChainId, ()), cap)
                    != bytes32(e.chainId)
                || IO.word(owner, abi.encodeCall(IStreamArtistOwner.domainId, ()), cap)
                    != RH.ownerDomain(index)
        ) revert O.InvalidArchiveOrigin();
    }
}
