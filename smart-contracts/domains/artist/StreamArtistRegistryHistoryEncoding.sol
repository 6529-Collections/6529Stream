// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamArtistHistory,
    StreamArtistHistoryTypes as H
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";

/// @notice Fixed typed history-read codec. Each original owner call still decodes before return.
library StreamArtistRegistryHistoryEncoding {
    error UnknownHistoryRead();

    function read(address identityOwner, bytes calldata data) public view returns (bytes memory) {
        IStreamArtistHistory owner = IStreamArtistHistory(identityOwner);
        bytes4 selector = bytes4(data[:4]);
        if (selector == IStreamArtistHistory.artistRecordChainHash.selector) {
            (bytes32 id) = abi.decode(data[4:], (bytes32));
            (bytes32 r0) = owner.artistRecordChainHash(id);
            return abi.encode(r0);
        }
        if (selector == IStreamArtistHistory.collectionRecordChainHash.selector) {
            (uint256 id) = abi.decode(data[4:], (uint256));
            (bytes32 r0) = owner.collectionRecordChainHash(id);
            return abi.encode(r0);
        }
        if (selector == IStreamArtistHistory.artistHistoryLane.selector) {
            (uint8 kind, bytes32 id) = abi.decode(data[4:], (uint8, bytes32));
            (bytes32 r0, uint64 r1) = owner.artistHistoryLane(kind, id);
            return abi.encode(r0, r1);
        }
        if (selector == IStreamArtistHistory.artistHistoryRecordAt.selector) {
            (uint8 kind, bytes32 id, uint64 index) = abi.decode(data[4:], (uint8, bytes32, uint64));
            (bytes32 r0, bytes32 r1) = owner.artistHistoryRecordAt(kind, id, index);
            return abi.encode(r0, r1);
        }
        if (selector == IStreamArtistHistory.artistHistoryContinuityCommitment.selector) {
            (bytes32 r0) = owner.artistHistoryContinuityCommitment();
            return abi.encode(r0);
        }
        if (selector == IStreamArtistHistory.importedHistoryBindingCount.selector) {
            (uint256 r0) = owner.importedHistoryBindingCount();
            return abi.encode(r0);
        }
        if (selector == IStreamArtistHistory.importedHistoryBinding.selector) {
            (uint256 index) = abi.decode(data[4:], (uint256));
            (address r0, uint64 r1, bytes32 r2, bytes32 r3) = owner.importedHistoryBinding(index);
            return abi.encode(r0, r1, r2, r3);
        }
        if (selector == IStreamArtistHistory.artistHistoryPredecessorBinding.selector) {
            (address source) = abi.decode(data[4:], (address));
            (bool r0, bytes32 r1, uint256 r2) = owner.artistHistoryPredecessorBinding(source);
            return abi.encode(r0, r1, r2);
        }
        if (selector == IStreamArtistHistory.verifyImportedRecord.selector) {
            (bytes32 root, H.Leaf memory p, bytes32[] memory proof) =
                abi.decode(data[4:], (bytes32, H.Leaf, bytes32[]));
            (bool r0) = owner.verifyImportedRecord(root, p, proof);
            return abi.encode(r0);
        }
        if (selector == IStreamArtistHistory.importedLaneVerified.selector) {
            (uint8 kind, bytes32 id) = abi.decode(data[4:], (uint8, bytes32));
            (bool r0, bytes32 r1, uint64 r2) = owner.importedLaneVerified(kind, id);
            return abi.encode(r0, r1, r2);
        }
        if (selector == IStreamArtistHistory.artistRegistryCutover.selector) {
            (bool r0, address r1, uint64 r2) = owner.artistRegistryCutover();
            return abi.encode(r0, r1, r2);
        }
        if (selector == IStreamArtistHistory.artistHistoryImportContext.selector) {
            (address predecessor, uint64 snapshot, bytes32 root, bytes32 manifest) =
                abi.decode(data[4:], (address, uint64, bytes32, bytes32));
            (H.Context memory r0) =
                owner.artistHistoryImportContext(predecessor, snapshot, root, manifest);
            return abi.encode(r0);
        }
        revert UnknownHistoryRead();
    }
}
