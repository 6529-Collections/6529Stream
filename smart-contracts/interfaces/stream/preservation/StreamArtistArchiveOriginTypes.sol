// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../artist/StreamArtistRecoveredHydrationTypes.sol";
import { StreamRenderCriticalSourceTypes as S } from "./StreamRenderCriticalSourceTypes.sol";

/// @notice Additive original-producer facts; never a new signing or semantic-record domain.
library StreamArtistArchiveOriginTypes {
    bytes32 internal constant PROFILE = keccak256("6529STREAM_ARTIST_ARCHIVE_ORIGIN_V1");
    bytes32 internal constant INVENTORY_PROFILE =
        keccak256("6529STREAM_MULTI_ORIGIN_RENDER_CRITICAL_INVENTORY_V1");
    bytes32 internal constant SCOPED_INVENTORY_PROFILE =
        keccak256("6529STREAM_MULTI_ORIGIN_SCOPED_RENDER_CRITICAL_INVENTORY_V1");
    bytes32 internal constant POLICY_INVENTORY_PROFILE =
        keccak256("6529STREAM_MULTI_ORIGIN_POLICY_RENDER_CRITICAL_INVENTORY_V2");
    bytes32 internal constant SCOPED_POLICY_INVENTORY_PROFILE =
        keccak256("6529STREAM_MULTI_ORIGIN_SCOPED_POLICY_RENDER_CRITICAL_INVENTORY_V2");
    bytes32 internal constant COVERAGE_PROFILE =
        keccak256("6529STREAM_MULTI_ORIGIN_BUNDLE_IMMUTABLE_STOP_AGGREGATE_V1");
    uint256 internal constant MAX_ORIGINS = RH.MAX_ERAS + 1;

    enum Lane {
        NATIVE,
        IMPORTED
    }
    enum ContentRole {
        COLLECTION,
        SCOPED,
        POLICY_COLLECTION,
        POLICY_SCOPED
    }

    /// @dev Only a locator. Typed source reads select operation, owner and expected record.
    struct ReceiptWitness {
        Lane lane;
        uint256 index;
    }

    /// @dev 24 static words. RH.originHash identifies the original environment separately.
    struct Origin {
        RH.OriginEnvironment environment;
        bytes32 registryCodeHash;
        bytes32 coordinatorCodeHash;
        bytes32 archiveCodeHash;
    }

    /// @dev Fixed worker only; late source pins remain in constructor storage, not runtime.
    struct Dependencies {
        address worker;
        bytes32 workerCodeHash;
        uint256 originGas;
        bytes32 profile;
    }

    /// @dev 38 static words. Hash this before hashing the item to avoid a circular preimage.
    struct RecordOrigin {
        Origin producer;
        RH.JournalEntry occurrence;
        bytes32 importCommitment;
        uint64 importedAtRevision;
        address actor;
        bytes32 semanticRecordHash;
        bytes32 role;
        bytes32 sourceContextHash;
    }

    error InvalidArchiveOrigin();
    error ArchiveOriginRead(address target);
    error ArchiveOriginChanged(address target);
    error ArchiveOriginLimit();

    function originPinHash(Origin memory origin) internal pure returns (bytes32) {
        return keccak256(abi.encode(PROFILE, origin));
    }

    function recordOriginHash(RecordOrigin memory origin) internal pure returns (bytes32) {
        return
            keccak256(abi.encode(keccak256("6529STREAM_ARTIST_ARCHIVE_RECORD_ORIGIN_V1"), origin));
    }

    function inventoryDependencyHash(S.Dependencies memory base, Dependencies memory origin)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(INVENTORY_PROFILE, base, origin));
    }

    function inventoryDependencyHash(
        bytes32 profile,
        S.Dependencies memory base,
        Dependencies memory origin
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(profile, base, origin));
    }

    function evidenceId(RecordOrigin memory original) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                original.producer.environment.chainId,
                original.producer.environment.registry,
                original.producer.environment.coordinator,
                original.occurrence.receipt.operation,
                original.actor,
                original.occurrence.receipt.recordHash
            )
        );
    }

    function appendOrigin(bytes32 previous, uint256 index, Origin memory origin)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ARCHIVE_ORIGIN_SET_ITEM_V1"),
                previous,
                index,
                originPinHash(origin)
            )
        );
    }

    function sealedOriginSetHash(uint256 count, bytes32 chain) internal pure returns (bytes32) {
        if (count == 0 || count > MAX_ORIGINS || chain == 0) revert InvalidArchiveOrigin();
        return
            keccak256(
                abi.encode(keccak256("6529STREAM_ARTIST_ARCHIVE_ORIGIN_SET_V1"), count, chain)
            );
    }
}
