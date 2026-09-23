// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamBundleArchiveTypes as B
} from "../../interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    IStreamArtistArchiveOriginInventory as Inventory
} from "../../interfaces/stream/preservation/IStreamArtistArchiveOriginInventory.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import {
    StreamPreservationInventoryChains as Chains
} from "./StreamPreservationInventoryChains.sol";
import { StreamBundleArchiveReads as Reads } from "./StreamBundleArchiveReads.sol";

/// @notice Bounded routing from an exact inventory-admitted fact to its original Archive.
/// @dev Inventory membership precedes these reads. No caller-supplied Archive allowlist exists.
library StreamMultiOriginBundleArchiveReads {
    function configuration(
        B.Dependencies memory d,
        O.Dependencies memory o,
        bytes32 inventoryProfile
    ) public view {
        if (o.profile != O.PROFILE || o.originGas < 50000 || o.originGas > type(uint64).max) {
            revert O.InvalidArchiveOrigin();
        }
        IO.pin(o.worker, o.workerCodeHash);
        address inventory = d.targets[2];
        IO.pin(inventory, d.codeHashes[2]);
        bytes memory raw = IO.fixedRead(
            inventory, abi.encodeCall(Inventory.originDependencies, ()), 128, d.readGas
        );
        O.Dependencies memory admitted = abi.decode(raw, (O.Dependencies));
        IO.canonical(inventory, raw, abi.encode(admitted));
        if (
            keccak256(abi.encode(admitted)) != keccak256(abi.encode(o))
                || IO.word(inventory, abi.encodeCall(Inventory.originProfile, ()), d.readGas)
                    != inventoryProfile
        ) {
            revert O.InvalidArchiveOrigin();
        }
    }

    function environment(
        B.Dependencies memory d,
        O.Dependencies memory o,
        bytes32 inventoryProfile,
        bytes32 id
    ) public view returns (bytes32) {
        bytes32 base = Reads.environment(d);
        configuration(d, o, inventoryProfile);
        (bytes32 root, uint256 count) = originSet(d, id);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MULTI_ORIGIN_BUNDLE_ENVIRONMENT_V1"),
                base,
                o,
                inventoryProfile,
                id,
                root,
                count
            )
        );
    }

    /// @notice Recomputes the finite, ordered and deduplicated sealed table from fixed reads.
    function originSet(B.Dependencies memory d, bytes32 id)
        public
        view
        returns (bytes32 root, uint256 count)
    {
        address inventory = d.targets[2];
        count = uint256(IO.word(inventory, abi.encodeCall(Inventory.originCount, (id)), d.readGas));
        if (id == 0 || count == 0 || count > O.MAX_ORIGINS) revert O.ArchiveOriginLimit();
        bytes32[17] memory seen;
        bytes32 chain;
        for (uint256 i; i < count; ++i) {
            O.Origin memory producer = originAt(d, id, i);
            bytes32 identity = RH.originHash(producer.environment);
            for (uint256 j; j < i; ++j) {
                if (seen[j] == identity) revert O.InvalidArchiveOrigin();
            }
            seen[i] = identity;
            chain = O.appendOrigin(chain, i, producer);
        }
        root = O.sealedOriginSetHash(count, chain);
        if (IO.word(inventory, abi.encodeCall(Inventory.originSetHash, (id)), d.readGas) != root) {
            revert O.InvalidArchiveOrigin();
        }
    }

    function originAt(B.Dependencies memory d, bytes32 id, uint256 index)
        public
        view
        returns (O.Origin memory producer)
    {
        address inventory = d.targets[2];
        bytes memory raw = IO.fixedRead(
            inventory, abi.encodeCall(Inventory.originAt, (id, index)), 768, d.readGas
        );
        producer = abi.decode(raw, (O.Origin));
        IO.canonical(inventory, raw, abi.encode(producer));
        if (
            producer.environment.chainId != d.chainId || producer.environment.registry == address(0)
                || producer.environment.coordinator == address(0) || producer.registryCodeHash == 0
                || producer.coordinatorCodeHash == 0 || producer.environment.core != d.targets[0]
                || producer.environment.suiteConfigurationHash == 0
        ) revert O.InvalidArchiveOrigin();
        IO.pin(producer.environment.archive, producer.archiveCodeHash);
    }

    function admit(
        B.Dependencies memory d,
        bytes32 id,
        T.Evidence memory evidence,
        T.Item memory item,
        B.Proof memory proof
    ) public view returns (B.Admission memory admission, bytes32 observation, bytes32 originHash) {
        (d, originHash) = route(d, id, evidence, item);
        (admission, observation) = Reads.admit(d, evidence.artistId, item, proof);
    }

    function current(
        B.Dependencies memory d,
        bytes32 id,
        T.Evidence memory evidence,
        T.Item memory item,
        B.Admission memory admission,
        bytes32 expectedOriginHash
    ) public view returns (bytes32) {
        bytes32 originHash;
        (d, originHash) = route(d, id, evidence, item);
        if (originHash != expectedOriginHash) revert O.InvalidArchiveOrigin();
        return Reads.current(d, evidence.artistId, item, admission);
    }

    function route(
        B.Dependencies memory d,
        bytes32 id,
        T.Evidence memory evidence,
        T.Item memory item
    ) public view returns (B.Dependencies memory, bytes32 originHash) {
        if (item.kind != T.Kind.STATE_BUNDLE) return (d, bytes32(0));
        address inventory = d.targets[2];
        IO.pin(inventory, d.codeHashes[2]);
        bytes memory raw = IO.fixedRead(
            inventory,
            abi.encodeCall(Inventory.artistArchiveOrigin, (id, Chains.itemHash(item))),
            1216,
            d.readGas
        );
        O.RecordOrigin memory fact = abi.decode(raw, (O.RecordOrigin));
        IO.canonical(inventory, raw, abi.encode(fact));
        uint16 operation = fact.occurrence.receipt.operation;
        if (
            id != evidence.planId || fact.role != item.role || fact.role == 0
                || fact.sourceContextHash != evidence.sourceContextHash
                || fact.sourceContextHash == 0
                || fact.occurrence.receipt.artistId != evidence.artistId
                || fact.occurrence.receipt.collectionId != evidence.collectionId
                || fact.occurrence.receipt.recordHash == 0 || fact.semanticRecordHash == 0
                || fact.occurrence.position.point.ownerRevision == 0
                || (operation != 17 && operation != 24)
                || fact.occurrence.position.point.ownerIndex != (operation == 17 ? 6 : 4)
                || fact.occurrence.position.point.environmentHash
                    != RH.originHash(fact.producer.environment)
                || (fact.importCommitment == 0) != (fact.importedAtRevision == 0)
                || fact.actor == address(0) || O.evidenceId(fact) != item.sourceRecord
                || fact.producer.environment.archive != item.source
        ) revert O.InvalidArchiveOrigin();
        uint256 count =
            uint256(IO.word(inventory, abi.encodeCall(Inventory.originCount, (id)), d.readGas));
        if (count == 0 || count > O.MAX_ORIGINS) revert O.ArchiveOriginLimit();
        bytes32 producerHash = O.originPinHash(fact.producer);
        bool found;
        for (uint256 i; i < count; ++i) {
            if (O.originPinHash(originAt(d, id, i)) == producerHash) found = true;
        }
        if (!found) revert O.InvalidArchiveOrigin();
        // The unchanged state reader checks byte correspondence but does not pin this runtime.
        IO.pin(item.source, fact.producer.archiveCodeHash);
        d.targets[5] = item.source;
        d.codeHashes[5] = fact.producer.archiveCodeHash;
        return (d, O.recordOriginHash(fact));
    }
}
