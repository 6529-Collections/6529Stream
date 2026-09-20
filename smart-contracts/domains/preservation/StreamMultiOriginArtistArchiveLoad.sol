// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamArtistOnboardingTypes as A
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamPreservationInventoryTypes as V
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import "../../interfaces/stream/artist/IStreamArtistSuiteReads.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";

/// @notice Original Archive loading only after the fixed proof worker admits exact membership.
/// @dev This helper is not an origin admission API. Every caller must complete its typed
/// original envelope and semantic-record correspondence before storing an inventory item.
library StreamMultiOriginArtistArchiveLoad {
    function load(S.Dependencies memory d, O.RecordOrigin memory original)
        public
        view
        returns (
            A.SuiteConfiguration memory suite,
            address coordinator,
            bytes32 id,
            bytes memory evidence
        )
    {
        O.Origin memory origin = original.producer;
        RH.OriginEnvironment memory env = origin.environment;
        if (
            original.actor == address(0) || original.occurrence.receipt.recordHash == 0
                || (original.occurrence.receipt.operation != 17
                    && original.occurrence.receipt.operation != 24) || env.chainId != d.chainId
                || env.chainId != block.chainid || env.core != d.targets[0]
                || RH.originHash(env) != original.occurrence.position.point.environmentHash
        ) revert O.InvalidArchiveOrigin();
        IO.pin(env.registry, origin.registryCodeHash);
        IO.pin(env.coordinator, origin.coordinatorCodeHash);
        IO.pin(env.archive, origin.archiveCodeHash);
        coordinator = env.coordinator;
        bytes memory raw = IO.fixedRead(
            coordinator,
            abi.encodeCall(IStreamArtistSuiteReads.suiteConfiguration, ()),
            544,
            d.readGas
        );
        suite = abi.decode(raw, (A.SuiteConfiguration));
        IO.canonical(coordinator, raw, abi.encode(suite));
        if (
            keccak256(raw) != env.suiteConfigurationHash || suite.registry != env.registry
                || suite.archive != env.archive || suite.core != env.core
                || suite.mintManager != env.manager || suite.metadata != d.targets[4]
                || keccak256(abi.encode(suite.owners)) != keccak256(abi.encode(env.owners))
                || IO.addressWord(
                        env.archive,
                        abi.encodeCall(IStreamArtistArchiveV2.artistRegistry, ()),
                        d.readGas
                    ) != env.registry
                || IO.addressWord(
                        env.archive,
                        abi.encodeCall(IStreamArtistArchiveV2.operationCoordinator, ()),
                        d.readGas
                    ) != coordinator
        ) revert V.InvalidInventoryItem();
        for (uint256 i; i < 7; ++i) {
            IO.pin(env.owners[i], env.ownerCodeHashes[i]);
        }
        id = O.evidenceId(original);
        raw = IO.read(
            env.archive,
            abi.encodeCall(IStreamArtistArchiveV2.artistEvidenceBytesV2, (id, 1)),
            65600,
            d.sourceGas
        );
        evidence = abi.decode(raw, (bytes));
        IO.canonical(env.archive, raw, abi.encode(evidence));
    }

    /// @dev Preserve old provenance preimages against the real producer pins, not today's suite.
    function originalDependencies(S.Dependencies memory d, O.Origin memory origin)
        internal
        pure
        returns (S.Dependencies memory)
    {
        d.artistTargets = [
            origin.environment.registry,
            origin.environment.coordinator,
            origin.environment.owners[2],
            origin.environment.owners[4],
            origin.environment.archive
        ];
        d.artistCodeHashes = [
            origin.registryCodeHash,
            origin.coordinatorCodeHash,
            origin.environment.ownerCodeHashes[2],
            origin.environment.ownerCodeHashes[4],
            origin.archiveCodeHash
        ];
        d.artistContentOwner = origin.environment.owners[6];
        d.artistContentOwnerCodeHash = origin.environment.ownerCodeHashes[6];
        return d;
    }

    function provenance(bytes32 originalProvenance, O.RecordOrigin memory original)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(O.PROFILE, originalProvenance, O.recordOriginHash(original)));
    }
}
