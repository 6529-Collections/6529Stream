// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistDelegationHydrationSource.sol";
import "./StreamArtistDelegationState.sol";
import "./StreamArtistSaleHashes.sol";

/// @notice Original-domain history joins. Present grant liveness never reauthorizes a historical consent.
library StreamArtistDelegationHydrationFacts {
    function check(StreamArtistHydrationPrepared.Bundle memory h, AH.Request memory p) public view {
        AH.Binding memory binding =
            StreamArtistDelegationHydrationCodec.binding(h.data[0].typedState);
        DH.Identity memory identity =
            StreamArtistDelegationHydrationCodec.identity(h.data[2].typedState);
        AH.Identity memory original = abi.decode(identity.baseline, (AH.Identity));
        AH.Acceptance memory acceptance = abi.decode(h.data[3].typedState, (AH.Acceptance));
        DH.Consent memory consent =
            StreamArtistDelegationHydrationCodec.consent(h.data[6].typedState);
        if (
            binding.item.artistId != h.q.artistId || binding.item.bindingHash != h.q.bindingHash
                || binding.item.artistAddress != original.item.authorityAddress
                || binding.item.identityRecordHash != original.item.identityRecordHash
                || original.nextRegistrationNonce != 1 || original.item.authorityClass != 1
                || original.item.status != 1
                || acceptance.record
                    != IStreamArtistNativeReceipts(h.source.owners[3])
                    .artistNativeReceiptAt(0)
                    .recordHash || identity.epoch != 0
        ) revert T.InvalidRecord();
        StreamArtistHashes.Environment memory e = StreamArtistHashes.Environment(
            block.chainid, h.prior, h.source.core, h.source.mintManager
        );
        if (
            StreamArtistHashes.identity(
                    e, original.item.authorityAddress, original.item.identityRecordHash, 0
                ) != h.q.artistId
        ) revert T.InvalidRecord();
        _identity(h, identity, original, e);
        _consents(h, identity, original, consent, binding, e);
        _nonces(identity, p.expectedSource[2].nonceIndexCount, h.q.artistId);
    }

    function _identity(
        StreamArtistHydrationPrepared.Bundle memory h,
        DH.Identity memory b,
        AH.Identity memory original,
        StreamArtistHashes.Environment memory e
    ) private view {
        uint256 revisions;
        uint256 grants;
        uint256 revocations;
        bytes32 prior;
        bytes32 document = original.item.identityRecordHash;
        uint256 count = IStreamArtistNativeReceipts(h.source.owners[2]).artistNativeReceiptCount();
        for (uint256 i; i < count; ++i) {
            H.Receipt memory r =
                IStreamArtistNativeReceipts(h.source.owners[2]).artistNativeReceiptAt(i);
            if (r.operation == 25) {
                if (revisions >= b.revisions.length) revert T.InvalidRecord();
                DH.Revision memory row = b.revisions[revisions++];
                if (
                    row.item.recordHash != r.recordHash || row.item.artistId != h.q.artistId
                        || row.item.previousRevisionRecord != prior
                        || row.item.previousRecordHash != document
                        || row.item.revisedRecordHash == document
                        || row.item.signer != original.item.authorityAddress
                        || row.item.authorityClass != 1 || row.item.signedAt == 0
                        || row.document.length == 0
                        || keccak256(row.document) != row.item.revisedRecordHash
                        || bytes(row.item.displayName).length == 0
                        || keccak256(
                                abi.encode(
                                    bytes32(
                                        0x1b7518e9d16da358d15957ec43218eb0b017fbd017e60c75b3126110006034a4
                                    ),
                                    e.chainId,
                                    e.registry,
                                    h.q.artistId,
                                    document,
                                    row.item.revisedRecordHash,
                                    row.item.signer,
                                    uint8(1),
                                    row.item.nonce,
                                    row.item.signedAt
                                )
                            ) != r.recordHash
                ) revert T.InvalidRecord();
                prior = r.recordHash;
                document = row.item.revisedRecordHash;
            } else if (r.operation == 26) {
                if (grants >= b.grants.length) revert T.InvalidRecord();
                DH.Grant memory row = b.grants[grants++];
                D.Grant memory g = row.item.grant;
                if (
                    row.recordHash != r.recordHash
                        || row.item.grantor != original.item.authorityAddress
                        || g.artistId != h.q.artistId || g.delegate == address(0)
                        || g.delegate == row.item.grantor || g.capabilities == 0
                        || (g.capabilities & ~uint32(1143)) != 0 || g.expiresAt <= g.notBefore
                        || row.epoch != b.epoch || (g.maxUses != 0 && row.item.uses > g.maxUses)
                        || row.item.revoked != (row.item.revocationRecordHash != 0)
                        || keccak256(
                                abi.encode(
                                    keccak256("6529STREAM_ARTIST_DELEGATION_RECORD_V1"),
                                    e.chainId,
                                    e.registry,
                                    g.artistId,
                                    g.delegate,
                                    g.collectionId,
                                    g.capabilities,
                                    g.notBefore,
                                    g.expiresAt,
                                    g.maxUses,
                                    g.constraintsHash,
                                    row.item.nonce
                                )
                            ) != row.recordHash
                ) revert T.InvalidRecord();
                bytes32 latest = row.recordHash;
                for (uint256 j = grants; j < b.grants.length; ++j) {
                    if (b.grants[j].item.grant.delegate == g.delegate) {
                        latest = b.grants[j].recordHash;
                    }
                }
                if (row.current != latest) revert T.InvalidRecord();
            } else if (r.operation == 27) {
                uint256 matched;
                // A revocation must follow its actual grant in the original Identity journal.
                for (uint256 j; j < grants; ++j) {
                    if (b.grants[j].item.revocationRecordHash == r.recordHash) ++matched;
                }
                if (matched != 1) revert T.InvalidRecord();
                ++revocations;
            }
        }
        uint256 revoked;
        for (uint256 i; i < b.grants.length; ++i) {
            if (b.grants[i].item.revoked) ++revoked;
        }
        if (revisions != b.revisions.length || grants != b.grants.length || revocations != revoked) revert T.InvalidRecord();
    }

    function _consents(
        StreamArtistHydrationPrepared.Bundle memory h,
        DH.Identity memory identity,
        AH.Identity memory original,
        DH.Consent memory b,
        AH.Binding memory binding,
        StreamArtistHashes.Environment memory e
    ) private view {
        uint256 policies;
        uint256 sales;
        uint256[] memory uses = new uint256[](identity.grants.length);
        uint256 count = IStreamArtistNativeReceipts(h.source.owners[6]).artistNativeReceiptCount();
        if (b.policies.length != h.q.policies.length) revert T.InvalidRecord();
        for (uint256 i; i < count; ++i) {
            H.Receipt memory r =
                IStreamArtistNativeReceipts(h.source.owners[6]).artistNativeReceiptAt(i);
            if (r.operation == 14) {
                if (
                    policies >= b.policies.length || b.policies[policies].recordHash != r.recordHash
                ) revert T.InvalidRecord();
                bytes32 grant = b.policies[policies++].grant;
                if (grant != 0) {
                    ++uses[
                        _grant(
                            identity,
                            grant,
                            h.q.collectionId,
                            D.POLICY_CONSENT,
                            binding.item.consentMode
                        )
                    ];
                }
            } else {
                if (r.operation != 16 || sales >= b.sales.length) revert T.InvalidRecord();
                DH.Sale memory row = b.sales[sales++];
                Sale.Record memory item = row.item;
                if (
                    item.recordHash != r.recordHash || item.artistId != h.q.artistId
                        || item.terms.collectionId != h.q.collectionId
                        || item.terms.saleAdapter == address(0) || item.terms.saleId == 0
                        || item.terms.saleConfigHash == 0 || item.signedAt == 0
                        || item.bindingGeneration != 1 || item.bindingHash != h.q.bindingHash
                        || StreamArtistSaleHashes.record(
                                e,
                                item.terms,
                                item.artistId,
                                item.signer,
                                item.authorityClass,
                                item.nonce,
                                item.signedAt
                            ) != item.recordHash
                ) revert T.InvalidRecord();
                if (row.grant == 0) {
                    if (item.authorityClass != 1 || item.signer != original.item.authorityAddress) {
                        revert T.InvalidRecord();
                    }
                } else {
                    uint256 g = _grant(
                        identity,
                        row.grant,
                        h.q.collectionId,
                        D.SALE_CONSENT,
                        binding.item.consentMode
                    );
                    if (
                        item.authorityClass != 2
                            || item.signer != identity.grants[g].item.grant.delegate
                    ) revert T.InvalidRecord();
                    ++uses[g];
                }
                bytes32 lookup = StreamArtistSaleHashes.lookup(
                    item.terms.collectionId, item.terms.saleId, item.terms.saleConfigHash
                );
                bytes32 latest = item.recordHash;
                for (uint256 j = sales; j < b.sales.length; ++j) {
                    Sale.Record memory next = b.sales[j].item;
                    if (
                        StreamArtistSaleHashes.lookup(
                                next.terms.collectionId,
                                next.terms.saleId,
                                next.terms.saleConfigHash
                            ) == lookup
                    ) latest = next.recordHash;
                }
                if (row.current != latest) revert T.InvalidRecord();
            }
        }
        if (policies != b.policies.length || sales != b.sales.length) revert T.InvalidRecord();
        for (uint256 i; i < uses.length; ++i) {
            if (uses[i] != identity.grants[i].item.uses) revert T.UnsupportedProfile();
        }
    }

    function _grant(
        DH.Identity memory b,
        bytes32 hash,
        uint256 collectionId,
        uint32 capability,
        uint8 mode
    ) private pure returns (uint256) {
        if (mode != 2) revert T.UnsupportedProfile();
        for (uint256 i; i < b.grants.length; ++i) {
            if (b.grants[i].recordHash != hash) continue;
            D.Grant memory g = b.grants[i].item.grant;
            if (
                (g.collectionId != 0 && g.collectionId != collectionId)
                    || (g.capabilities & capability) == 0
            ) revert T.InvalidRecord();
            return i;
        }
        revert T.InvalidRecord();
    }

    function _nonces(DH.Identity memory b, uint256 count, bytes32 artistId) private pure {
        if (count != 1 + b.delegateNonces.length) revert T.InvalidRecord();
        uint256 unique;
        for (uint256 i; i < b.grants.length; ++i) {
            address delegate = b.grants[i].item.grant.delegate;
            uint256 uses;
            bool prior;
            for (uint256 j; j < b.grants.length; ++j) {
                if (b.grants[j].item.grant.delegate != delegate) continue;
                if (j < i) prior = true;
                uses += b.grants[j].item.uses;
            }
            if (prior || uses == 0) continue;
            ++unique;
            bytes32 key = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"), artistId, delegate
                )
            );
            uint256 matches;
            for (uint256 j; j < b.delegateNonces.length; ++j) {
                if (b.delegateNonces[j].key == key) ++matches;
            }
            if (matches != 1) revert T.InvalidRecord();
        }
        if (unique != b.delegateNonces.length) revert T.InvalidRecord();
    }
}
