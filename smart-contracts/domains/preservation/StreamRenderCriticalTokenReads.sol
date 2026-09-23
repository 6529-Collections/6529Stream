// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import "../records/StreamSnapshotSourceReads.sol";
import "../finality/StreamFinalityDescriptionReads.sol";
import "../finality/StreamFinalityConservationReads.sol";
import "../finality/StreamFinalityReferenceReads.sol";
import "../finality/StreamFinalitySnapshotReads.sol";
import "../finality/StreamFinalityCoordinatorPolicyReads.sol";
import "../finality/StreamOnchainContentBytes.sol";
import "../../interfaces/stream/core/IStreamCoreMint.sol";
import "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import "../../interfaces/stream/finality/IStreamCollectionTokenInventory.sol";
import "../../interfaces/stream/finality/IStreamCollectionTokenInventorySerialLookup.sol";

/// @notice Actual current original inputs and deterministic native bytes, never a supplied set.
import { StreamRenderCriticalSourceReads as Sources } from "./StreamRenderCriticalSourceReads.sol";

/// @notice Exact minted-ever member and historical rendered-byte joins.
library StreamRenderCriticalTokenReads {
    function tokenItems(
        S.Dependencies memory d,
        S.Context memory c,
        uint64 index,
        IStreamOnchainContentCheckpoint.TokenPayload memory supplied
    ) public view returns (T.Item[] memory items) {
        Sources.bindings(d);
        if (index >= c.tokenCount) revert T.InvalidInventoryItem();
        StreamTokenContentLeaf memory leaf = _tokenLeaf(d, c, index, supplied.tokenId);
        uint256 actualId = supplied.tokenId;
        bytes memory json = _bytes(
            d.targets[4],
            abi.encodeCall(
                IStreamMetadataServingFacts.historicalTokenMetadataJSON, (d.targets[0], actualId)
            ),
            65536,
            d.sourceGas
        );
        bytes memory data = _bytes(
            d.targets[0], abi.encodeCall(IStreamCoreMint.tokenData, (actualId)), 16384, d.sourceGas
        );
        if (
            leaf.metadataHash != keccak256(json) || leaf.tokenDataHash != keccak256(data)
                || leaf.contentHash != 0 || supplied.animation.length == 0
                || supplied.animation.length > 40960
                || leaf.animationHash != keccak256(supplied.animation)
                || supplied.image.length > 2048
                || (supplied.image.length == 0
                        ? leaf.imageHash != 0
                        : leaf.imageHash != keccak256(supplied.image))
        ) revert T.InvalidInventoryItem();
        items = new T.Item[](4);
        items[0] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("TOKEN_DATA"),
            d.targets[0],
            c.checkpointHash,
            actualId,
            data
        );
        items[1] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("TOKEN_METADATA_JSON"),
            d.targets[4],
            c.checkpointHash,
            actualId,
            json
        );
        items[2] = supplied.image.length == 0
            ? Items.absent(keccak256("TOKEN_IMAGE"), d.targets[4], c.checkpointHash, actualId)
            : Items.bytesItem(
                T.Kind.NATIVE_BYTES,
                keccak256("TOKEN_IMAGE"),
                d.targets[4],
                c.checkpointHash,
                actualId,
                supplied.image
            );
        items[3] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("TOKEN_ANIMATION_HTML"),
            d.targets[4],
            c.checkpointHash,
            actualId,
            supplied.animation
        );
    }

    function _tokenLeaf(S.Dependencies memory d, S.Context memory c, uint64 index, uint256 actualId)
        private
        view
        returns (StreamTokenContentLeaf memory leaf)
    {
        StreamSnapshotTypes.Dependencies memory sd = Sources.snapshotDependencies(d);
        address checkpoint = sd.targets[6];
        bytes memory raw = IO.fixedRead(
            checkpoint,
            abi.encodeCall(
                IStreamOnchainContentCheckpoint.requireCurrentCheckpoint, (c.checkpointHash)
            ),
            224,
            d.sourceGas
        );
        IStreamOnchainContentCheckpoint.Plan memory plan =
            abi.decode(raw, (IStreamOnchainContentCheckpoint.Plan));
        IO.canonical(checkpoint, raw, abi.encode(plan));
        if (
            plan.collectionId != c.collectionId || plan.tokenCount != c.tokenCount
                || plan.nextIndex != c.tokenCount || plan.inventoryHash != c.tokenInventoryHash
        ) revert T.InventorySourceChanged();
        address inventory = IO.addressWord(
            checkpoint,
            abi.encodeCall(IStreamOnchainContentCheckpoint.tokenInventory, ()),
            d.readGas
        );
        if (
            actualId
                != uint256(
                    IO.word(
                        inventory,
                        abi.encodeCall(
                            IStreamCollectionTokenInventory.collectionTokenAt,
                            (c.collectionId, index)
                        ),
                        d.readGas
                    )
                )
        ) revert T.InvalidInventoryItem();
        _tokenIdentity(d, actualId, c.collectionId, inventory);
        raw = IO.fixedRead(
            checkpoint,
            abi.encodeCall(
                IStreamOnchainContentCheckpoint.checkpointLeaf, (c.checkpointHash, index)
            ),
            192,
            d.readGas
        );
        leaf = abi.decode(raw, (StreamTokenContentLeaf));
        IO.canonical(checkpoint, raw, abi.encode(leaf));
        if (leaf.tokenId != actualId) revert T.InvalidInventoryItem();
    }

    function _tokenIdentity(
        S.Dependencies memory d,
        uint256 actualId,
        uint256 expectedCid,
        address inventory
    ) private view {
        bytes memory raw = IO.fixedRead(
            d.targets[0],
            abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (actualId)),
            128,
            d.readGas
        );
        (bool known, uint256 cid, uint256 serial, bool burned) =
            abi.decode(raw, (bool, uint256, uint256, bool));
        IO.canonical(d.targets[0], raw, abi.encode(known, cid, serial, burned));
        if (
            !known || cid != expectedCid || serial == 0
                || uint256(
                        IO.word(
                            inventory,
                            abi.encodeCall(
                                IStreamCollectionTokenInventorySerialLookup.collectionTokenBySerial,
                                (expectedCid, serial)
                            ),
                            d.readGas
                        )
                    ) != actualId
        ) {
            revert T.InvalidInventoryItem();
        }
    }

    function _bytes(address target, bytes memory input, uint256 maximum, uint256 cap)
        private
        view
        returns (bytes memory value)
    {
        bytes memory raw = IO.read(target, input, maximum + 64, cap);
        value = abi.decode(raw, (bytes));
        IO.canonical(target, raw, abi.encode(value));
        if (value.length > maximum) revert T.InventoryRead(target);
    }
}
