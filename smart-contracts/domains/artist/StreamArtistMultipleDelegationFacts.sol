// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistMultipleHydrationTypes as MH
} from "../../interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import "./StreamArtistMultipleDelegationCodec.sol";
import "./StreamArtistMultipleHydrationOperations.sol";
import "./StreamArtistSaleHashes.sol";
import {
    StreamArtistDelegationTypes as DG
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";

/// @notice Independent original-domain reconciliation over the complete global journal partition.
library StreamArtistMultipleDelegationFacts {
    function check(
        T.SuiteConfiguration memory s,
        MH.Request memory p,
        MD.Inventory memory v,
        MD.Identities memory identities,
        MD.Collections memory collections
    ) public view {
        StreamArtistHashes.Environment memory e =
            StreamArtistHashes.Environment(block.chainid, s.registry, s.core, s.mintManager);
        uint256[][] memory uses = new uint256[][](identities.rows.length);
        for (uint256 a; a < identities.rows.length; ++a) {
            MD.IdentityRow memory row = identities.rows[a];
            DH.Identity memory state = StreamArtistDelegationHydrationCodec.identity(row.state);
            AH.Identity memory original = abi.decode(state.baseline, (AH.Identity));
            if (
                row.artistId != p.artistIds[a]
                    || original.nextRegistrationNonce != p.artistIds.length
                    || original.item.authorityClass != 1 || original.item.status != 1
                    || state.epoch != 0
            ) revert T.InvalidRecord();
            _identity(v.receipts[2], row, original, e);
            _nonceLanes(row);
            uses[a] = new uint256[](state.grants.length);
        }
        for (uint256 c; c < collections.bindings.length; ++c) {
            AH.Query memory q = v.collections[c];
            AH.Binding memory binding = collections.bindings[c].state;
            uint256 a = StreamArtistMultipleHydrationOperations._artist(p.artistIds, q.artistId);
            DH.Identity memory state =
                StreamArtistDelegationHydrationCodec.identity(identities.rows[a].state);
            AH.Identity memory original = abi.decode(state.baseline, (AH.Identity));
            if (
                binding.item.artistId != q.artistId || binding.item.bindingHash != q.bindingHash
                    || binding.item.artistAddress != original.item.authorityAddress
                    || binding.item.identityRecordHash != original.item.identityRecordHash
            ) revert T.InvalidRecord();
            bool accepted;
            for (uint256 j; j < v.receipts[3].length; ++j) {
                H.Receipt memory r = v.receipts[3][j];
                if (
                    r.collectionId == q.collectionId
                        && r.recordHash == collections.acceptances[c].state.record
                ) accepted = true;
            }
            if (
                !accepted || collections.attributions[c].state != 2
                    || collections.attributions[c].generation != 1
            ) revert T.InvalidRecord();
            _consents(
                v.receipts[6],
                q,
                state,
                original,
                collections.consents[c].state,
                binding.item.consentMode,
                e,
                uses[a]
            );
        }
        for (uint256 a; a < identities.rows.length; ++a) {
            DH.Identity memory state =
                StreamArtistDelegationHydrationCodec.identity(identities.rows[a].state);
            for (uint256 g; g < uses[a].length; ++g) {
                if (uses[a][g] != state.grants[g].item.uses) revert T.UnsupportedProfile();
            }
        }
    }

    function _identity(
        H.Receipt[] memory receipts,
        MD.IdentityRow memory row,
        AH.Identity memory original,
        StreamArtistHashes.Environment memory e
    ) private pure {
        DH.Identity memory b = StreamArtistDelegationHydrationCodec.identity(row.state);
        uint256 revisions;
        uint256 grants;
        uint256 revocations;
        uint256 ordinal;
        bytes32 prior;
        bytes32 document = original.item.identityRecordHash;
        bool registered;
        for (uint256 i; i < receipts.length; ++i) {
            H.Receipt memory r = receipts[i];
            if (r.operation == 1) {
                if (r.artistId == row.artistId) {
                    if (
                        registered
                            || StreamArtistHashes.identity(
                                    e, original.item.authorityAddress, document, ordinal
                                ) != row.artistId
                    ) revert T.InvalidRecord();
                    registered = true;
                }
                ++ordinal;
            }
            if (r.artistId != row.artistId) continue;
            if (r.operation == 25) {
                if (revisions >= b.revisions.length) revert T.InvalidRecord();
                DH.Revision memory revision = b.revisions[revisions++];
                if (
                    revision.item.recordHash != r.recordHash
                        || revision.item.artistId != row.artistId
                        || revision.item.previousRevisionRecord != prior
                        || revision.item.previousRecordHash != document
                        || revision.item.revisedRecordHash == document
                        || revision.item.signer != original.item.authorityAddress
                        || revision.item.authorityClass != 1 || revision.item.signedAt == 0
                        || revision.document.length == 0
                        || keccak256(revision.document) != revision.item.revisedRecordHash
                        || bytes(revision.item.displayName).length == 0
                        || keccak256(
                                abi.encode(
                                    bytes32(
                                        0x1b7518e9d16da358d15957ec43218eb0b017fbd017e60c75b3126110006034a4
                                    ),
                                    e.chainId,
                                    e.registry,
                                    row.artistId,
                                    document,
                                    revision.item.revisedRecordHash,
                                    revision.item.signer,
                                    uint8(1),
                                    revision.item.nonce,
                                    revision.item.signedAt
                                )
                            ) != r.recordHash
                ) revert T.InvalidRecord();
                prior = r.recordHash;
                document = revision.item.revisedRecordHash;
            } else if (r.operation == 26) {
                if (grants >= b.grants.length) revert T.InvalidRecord();
                DH.Grant memory grant = b.grants[grants++];
                DG.Grant memory g = grant.item.grant;
                if (
                    grant.recordHash != r.recordHash
                        || grant.item.grantor != original.item.authorityAddress
                        || g.artistId != row.artistId || g.delegate == address(0)
                        || g.delegate == grant.item.grantor || g.capabilities == 0
                        || (g.capabilities & ~uint32(1143)) != 0 || g.expiresAt <= g.notBefore
                        || grant.epoch != 0 || (g.maxUses != 0 && grant.item.uses > g.maxUses)
                        || grant.item.revoked != (grant.item.revocationRecordHash != 0)
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
                                    grant.item.nonce
                                )
                            ) != grant.recordHash
                ) revert T.InvalidRecord();
                bytes32 current = grant.recordHash;
                for (uint256 j = grants; j < b.grants.length; ++j) {
                    if (b.grants[j].item.grant.delegate == g.delegate) {
                        current = b.grants[j].recordHash;
                    }
                }
                if (grant.current != current) revert T.InvalidRecord();
            } else if (r.operation == 27) {
                uint256 matches;
                for (uint256 j; j < grants; ++j) {
                    if (b.grants[j].item.revocationRecordHash == r.recordHash) ++matches;
                }
                if (matches != 1) revert T.InvalidRecord();
                ++revocations;
            }
        }
        uint256 revoked;
        for (uint256 i; i < b.grants.length; ++i) {
            if (b.grants[i].item.revoked) ++revoked;
        }
        if (
            !registered || ordinal != original.nextRegistrationNonce
                || revisions != b.revisions.length || grants != b.grants.length
                || revocations != revoked
        ) revert T.InvalidRecord();
    }

    function _consents(
        H.Receipt[] memory receipts,
        AH.Query memory q,
        DH.Identity memory identity,
        AH.Identity memory original,
        DH.Consent memory b,
        uint8 mode,
        StreamArtistHashes.Environment memory e,
        uint256[] memory uses
    ) private pure {
        uint256 policies;
        uint256 sales;
        if (b.policies.length != q.policies.length) revert T.InvalidRecord();
        for (uint256 i; i < receipts.length; ++i) {
            H.Receipt memory r = receipts[i];
            if (r.collectionId != q.collectionId) continue;
            if (r.operation == 14) {
                if (
                    policies >= b.policies.length || b.policies[policies].recordHash != r.recordHash
                ) revert T.InvalidRecord();
                bytes32 grant = b.policies[policies++].grant;
                if (grant != 0) {
                    ++uses[_grant(identity, grant, q.collectionId, DG.POLICY_CONSENT, mode)];
                }
            } else {
                if (r.operation != 16 || sales >= b.sales.length) revert T.InvalidRecord();
                DH.Sale memory row = b.sales[sales++];
                Sale.Record memory item = row.item;
                if (
                    item.recordHash != r.recordHash || item.artistId != q.artistId
                        || item.terms.collectionId != q.collectionId
                        || item.terms.saleAdapter == address(0) || item.terms.saleId == 0
                        || item.terms.saleConfigHash == 0 || item.signedAt == 0
                        || item.bindingGeneration != 1 || item.bindingHash != q.bindingHash
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
                    uint256 g = _grant(identity, row.grant, q.collectionId, DG.SALE_CONSENT, mode);
                    if (
                        item.authorityClass != 2
                            || item.signer != identity.grants[g].item.grant.delegate
                    ) revert T.InvalidRecord();
                    ++uses[g];
                }
                bytes32 lookup = StreamArtistSaleHashes.lookup(
                    item.terms.collectionId, item.terms.saleId, item.terms.saleConfigHash
                );
                bytes32 current = item.recordHash;
                for (uint256 j = sales; j < b.sales.length; ++j) {
                    Sale.Record memory next = b.sales[j].item;
                    if (
                        StreamArtistSaleHashes.lookup(
                                next.terms.collectionId,
                                next.terms.saleId,
                                next.terms.saleConfigHash
                            ) == lookup
                    ) current = next.recordHash;
                }
                if (row.current != current) revert T.InvalidRecord();
            }
        }
        if (policies != b.policies.length || sales != b.sales.length) revert T.InvalidRecord();
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
            if (b.grants[i].recordHash == hash) {
                DG.Grant memory g = b.grants[i].item.grant;
                if (
                    (g.collectionId != 0 && g.collectionId != collectionId)
                        || (g.capabilities & capability) == 0
                ) revert T.InvalidRecord();
                return i;
            }
        }
        revert T.InvalidRecord();
    }

    function _nonceLanes(MD.IdentityRow memory row) private pure {
        DH.Identity memory b = StreamArtistDelegationHydrationCodec.identity(row.state);
        uint256 unique;
        for (uint256 i; i < b.grants.length; ++i) {
            address delegate = b.grants[i].item.grant.delegate;
            bool prior;
            uint256 uses;
            for (uint256 j; j < b.grants.length; ++j) {
                if (b.grants[j].item.grant.delegate == delegate) {
                    if (j < i) prior = true;
                    uses += b.grants[j].item.uses;
                }
            }
            if (prior || uses == 0) continue;
            ++unique;
            bytes32 key = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"), row.artistId, delegate
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
