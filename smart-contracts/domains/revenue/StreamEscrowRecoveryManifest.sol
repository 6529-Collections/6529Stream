// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamEscrowRecoveryState as S } from "./StreamEscrowRecoveryState.sol";
import { StreamEscrowRecoveryProof as Proof } from "./StreamEscrowRecoveryProof.sol";
import {
    StreamEscrowRecoveryTypes as R
} from "../../interfaces/stream/revenue/StreamEscrowRecoveryTypes.sol";
import {
    IStreamRevenueEscrowRecoveryManifest as M
} from "../../interfaces/stream/revenue/IStreamRevenueEscrowRecoveryManifest.sol";

/// @notice Retains the exact canonical recovery document and computed affected recipients.
/// @dev Artist notice coverage and cited source events are explicit governance evidence, not
///      fabricated onchain receipt proofs. Actual notice delivery remains an operational duty.
library StreamEscrowRecoveryManifest {
    event EscrowRecoveryManifestPublished(
        uint16 schemaVersion,
        bytes32 indexed contentHash,
        address indexed publisher,
        bytes32 indexed creditKeyHash,
        bytes32 oldEntriesHash,
        bytes32 successorEntriesHash,
        bytes32 affectedAccountsHash,
        uint8 route,
        uint64 publishedAt,
        bytes canonicalDocument
    );

    function publish(
        S.Context memory c,
        M.ManifestDocument calldata supplied,
        R.EscrowRecoveryManifestRef calldata ref
    ) public returns (bytes32 contentHash) {
        M.ManifestDocument memory d = supplied;
        contentHash = keccak256(abi.encode(S.MANIFEST_DOMAIN, block.chainid, address(this), d));
        S.requireReference(ref);
        if (
            ref.contentHash != contentHash || block.timestamp == 0
                || block.timestamp > type(uint64).max
        ) revert S.InvalidEscrowRecoveryManifest();
        S.Manifest storage item = S.state().manifests[contentHash];
        // Publication authenticates the retained content, not a publisher-selected URI.
        // The later governed schedule binds its own complete, independently checked reference.
        if (item.publishedAt != 0) return contentHash;
        (bytes32 oldHash, bytes32 newHash, address[] memory affected) = Proof.validate(c, d);
        _notices(d, affected);
        bytes memory canonical = abi.encode(d);
        // This profile retains its actual bytes, including source-event and collection citations.
        item.canonicalDocument = canonical;
        item.oldEntriesHash = oldHash;
        item.successorEntriesHash = newHash;
        item.affectedAccounts = affected;
        item.publishedAt = uint64(block.timestamp);
        emit EscrowRecoveryManifestPublished(
            1,
            contentHash,
            msg.sender,
            S.keyHash(d.creditKey),
            oldHash,
            newHash,
            keccak256(abi.encode(affected)),
            d.route,
            item.publishedAt,
            canonical
        );
    }

    function encoded(bytes32 contentHash) public view returns (bytes memory, uint64) {
        S.Manifest storage item = S.state().manifests[contentHash];
        return (item.canonicalDocument, item.publishedAt);
    }

    function count(bytes32 contentHash) public view returns (uint256) {
        return S.state().manifests[contentHash].affectedAccounts.length;
    }

    function accountAt(bytes32 contentHash, uint256 index) public view returns (address) {
        address[] storage affected = S.state().manifests[contentHash].affectedAccounts;
        if (index >= affected.length) revert S.InvalidEscrowRecoveryManifest();
        return affected[index];
    }

    function _notices(M.ManifestDocument memory d, address[] memory affected) private view {
        if (d.route != 2) {
            if (
                d.recipientNotices.length != 0 || d.collectionNotices.length != 0
                    || d.sourceCredits.length != 0 || d.coverageStatementHash != 0
            ) revert S.InvalidEscrowRecoveryManifest();
            return;
        }
        if (
            d.coverageStatementHash == 0 || d.recipientNotices.length != affected.length
                || d.collectionNotices.length == 0 || d.sourceCredits.length == 0
        ) revert S.InvalidEscrowRecoveryManifest();
        for (uint256 i; i < affected.length; ++i) {
            M.RecipientNotice memory n = d.recipientNotices[i];
            if (n.account != affected[i]) revert S.InvalidEscrowRecoveryManifest();
            _notice(n.evidenceHash, n.noticedAt);
        }
        bool[] memory represented = new bool[](d.collectionNotices.length);
        for (uint256 i; i < d.collectionNotices.length; ++i) {
            M.CollectionNotice memory n = d.collectionNotices[i];
            if (n.core == address(0) || n.collectionId == 0) {
                revert S.InvalidEscrowRecoveryManifest();
            }
            if (i != 0) {
                M.CollectionNotice memory prior = d.collectionNotices[i - 1];
                if (
                    uint160(prior.core) > uint160(n.core)
                        || (prior.core == n.core && prior.collectionId >= n.collectionId)
                ) {
                    revert S.InvalidEscrowRecoveryManifest();
                }
            }
            if (n.artistBound) {
                if (n.artistAuthority == address(0)) revert S.InvalidEscrowRecoveryManifest();
                _notice(n.evidenceHash, n.noticedAt);
            } else if (n.artistAuthority != address(0) || n.evidenceHash != 0 || n.noticedAt != 0) {
                revert S.InvalidEscrowRecoveryManifest();
            }
        }
        for (uint256 i; i < d.sourceCredits.length; ++i) {
            M.SourceCredit memory source = d.sourceCredits[i];
            if (
                source.producer == address(0) || source.transactionHash == 0
                    || source.blockHash == 0 || source.blockNumber == 0
                    || source.blockNumber >= block.number
                    || source.collectionIndex >= represented.length
            ) revert S.InvalidEscrowRecoveryManifest();
            if (i != 0) {
                M.SourceCredit memory prior = d.sourceCredits[i - 1];
                if (
                    uint256(prior.transactionHash) > uint256(source.transactionHash)
                        || (prior.transactionHash == source.transactionHash
                            && prior.logIndex >= source.logIndex)
                ) {
                    revert S.InvalidEscrowRecoveryManifest();
                }
            }
            represented[source.collectionIndex] = true;
        }
        for (uint256 i; i < represented.length; ++i) {
            if (!represented[i]) revert S.InvalidEscrowRecoveryManifest();
        }
    }

    function _notice(bytes32 evidence, uint64 at) private view {
        if (evidence == 0 || at == 0 || at > block.timestamp) {
            revert S.InvalidEscrowRecoveryManifest();
        }
    }
}
