// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";
import {
    StreamArtistRecoveredHydrationChronology as Chronology
} from "./StreamArtistRecoveredHydrationChronology.sol";
import { StreamArtistDelegationState as Delegation } from "./StreamArtistDelegationState.sol";

/// @notice Consent-use increments for the complete historical Artist union, not current heads.
/// @dev The enclosing route first authenticates every canonical Identity frame, original map,
/// binding tuple and complete provenance certificate, and validates all Consent/sanction rows.
/// This worker keeps that certificate whole and chooses a principal from each native receipt.
/// It does not reauthorize old signatures or compare a grant's final uses before other families.
library StreamArtistCompleteHistoryConsentUses {
    bytes32 private constant DELEGATE_NONCE =
        keccak256("identity_authority.replay.delegated_nonce");

    struct Context {
        bytes[] identities;
        M.State scope;
        G.Consents[] consents;
        RH.Provenance provenance;
    }

    struct Use {
        bytes32 grant;
        uint32 capability;
        bool sale;
        uint256 nonce;
        address signer;
    }

    function validate(Context calldata x) public pure returns (uint256[][] memory totals) {
        if (
            x.identities.length > 128 || x.identities.length != x.scope.artists.length
                || x.consents.length == 0 || x.consents.length > 128
                || x.consents.length != x.scope.collections.length
        ) _invalid();
        totals = new uint256[][](x.identities.length);
        for (uint256 a; a < x.identities.length; ++a) {
            IH.Bundle calldata identity = Frame.bundle(x.identities[a]);
            if (
                identity.artistId == 0 || identity.artistId != x.scope.artists[a].artistId
                    || (a != 0 && identity.artistId <= x.scope.artists[a - 1].artistId)
            ) _invalid();
            totals[a] = new uint256[](identity.delegations.length);
        }
        _headers(x);
        // Counters are per collection/family, not per current or historical principal.
        uint256[6][] memory counts = new uint256[6][](x.consents.length);
        for (uint256 i; i < x.provenance.journals[6].length; ++i) {
            RH.JournalEntry calldata entry = x.provenance.journals[6][i];
            if (entry.receipt.recordHash == 0 || entry.position.point.ownerIndex != 6) _invalid();
            Chronology.validatePoint(x.provenance, entry.position.point);
            for (uint256 j; j < i; ++j) {
                if (x.provenance.journals[6][j].receipt.recordHash == entry.receipt.recordHash) {
                    _invalid();
                }
            }
            uint256 c = _collection(x.scope, entry.receipt.collectionId);
            uint256 a = _artist(x.scope, entry.receipt.artistId);
            // Original sanctions consume no grants. Their fixed validator owns signature,
            // Archive and zero-native13 mutation proofs; a native13 is never a valid occurrence.
            if (entry.receipt.operation == 12) continue;
            IH.Bundle calldata identity = Frame.bundle(x.identities[a]);
            _signature(identity, entry.receipt.recordHash);
            Use memory use = _row(x.consents[c], entry, counts[c]);
            if (use.grant == 0) continue;
            uint256 at = _grant(identity, x.provenance, entry, use.grant, use.capability);
            if (use.sale) {
                if (use.signer != identity.delegations[at].record.grant.delegate) _invalid();
                _saleNonce(identity, x.provenance, at, entry.position.point, use.nonce);
            }
            ++totals[a][at];
        }
        for (uint256 c; c < x.consents.length; ++c) {
            G.Consents calldata row = x.consents[c];
            if (
                counts[c][0] != row.rows.original.policies.length
                    || counts[c][1] != row.rows.original.economics.length
                    || counts[c][2] != row.rows.original.sales.length
                    || counts[c][3] != row.rows.consents.length
                    || counts[c][4] != row.rows.royalties.length
                    || counts[c][5] != row.rows.freezes.length
            ) _invalid();
        }
    }

    function _headers(Context calldata x) private pure {
        for (uint256 c; c < x.consents.length; ++c) {
            G.Consents calldata row = x.consents[c];
            if (
                x.scope.collections[c].collectionId == 0
                    || row.rows.original.collectionId != x.scope.collections[c].collectionId
                    || row.rows.original.artistId != x.scope.collections[c].artistId
                    || row.rows.original.bindingHash != x.scope.collections[c].bindingHash
                    || (c != 0
                        && x.scope.collections[c].collectionId
                            <= x.scope.collections[c - 1].collectionId)
            ) _invalid();
            if (row.bindings.length == 0) {
                if (x.scope.collections[c].artistId != 0 || x.scope.collections[c].bindingHash != 0)
                {
                    _invalid();
                }
            } else {
                T.Binding calldata head = row.bindings[row.bindings.length - 1];
                if (
                    head.artistId != x.scope.collections[c].artistId
                        || head.bindingHash != x.scope.collections[c].bindingHash
                ) _invalid();
            }
            for (uint256 g; g < row.bindings.length; ++g) {
                T.Binding calldata binding = row.bindings[g];
                _artist(x.scope, binding.artistId);
                if (
                    binding.generation != g + 1 || binding.bindingHash == 0
                        || (binding.consentMode != 1 && binding.consentMode != 2)
                ) _invalid();
            }
            // Current pending/terminal heads are retained exactly; only the actual historical
            // binding which authorized a row must have been accepted.
        }
    }

    function _row(G.Consents calldata row, RH.JournalEntry calldata entry, uint256[6] memory counts)
        private
        pure
        returns (Use memory use)
    {
        bytes32 record = entry.receipt.recordHash;
        bytes32 artist = entry.receipt.artistId;
        uint16 op = entry.receipt.operation;
        if (op == 14) {
            bool found;
            for (uint256 i; i < row.rows.original.policies.length; ++i) {
                if (row.rows.original.policies[i].recordHash != record) continue;
                if (found) _invalid();
                found = true;
                use.grant = row.rows.original.policies[i].grant;
            }
            if (!found || !_historical(row.bindings, artist, use.grant != 0)) _invalid();
            ++counts[0];
            use.capability = D.POLICY_CONSENT;
        } else if (op == 15) {
            uint256 i = counts[1]++;
            if (i >= row.rows.original.economics.length) _invalid();
            if (
                row.rows.original.economics[i].item.recordHash != record
                    || row.rows.original.economics[i].item.terms.collectionId
                        != entry.receipt.collectionId
                    || row.rows.original.economics[i].item.association.artistId != artist
            ) _invalid();
            T.Binding calldata binding = _binding(
                row.bindings,
                row.rows.original.economics[i].item.association.bindingGeneration,
                artist
            );
            if (binding.bindingHash != row.rows.original.economics[i].item.association.bindingHash) _invalid();
            use.grant = row.rows.original.economics[i].grant;
            use.capability = D.ECONOMICS;
        } else if (op == 16) {
            uint256 i = counts[2]++;
            if (i >= row.rows.original.sales.length) _invalid();
            if (
                row.rows.original.sales[i].item.recordHash != record
                    || row.rows.original.sales[i].item.artistId != artist
                    || row.rows.original.sales[i].item.terms.collectionId
                        != entry.receipt.collectionId
            ) _invalid();
            T.Binding calldata binding =
                _binding(row.bindings, row.rows.original.sales[i].item.bindingGeneration, artist);
            if (binding.bindingHash != row.rows.original.sales[i].item.bindingHash) _invalid();
            use.grant = row.rows.original.sales[i].grant;
            if (
                use.grant != 0
                    && (binding.consentMode != 2
                        || row.rows.original.sales[i].item.authorityClass != 2)
            ) _invalid();
            use.capability = D.SALE_CONSENT;
            use.sale = true;
            use.nonce = row.rows.original.sales[i].item.nonce;
            use.signer = row.rows.original.sales[i].item.signer;
        } else if (op == 17) {
            uint256 i = counts[3]++;
            if (i >= row.rows.consents.length) _invalid();
            if (
                row.rows.consents[i].recordHash != record || row.rows.consents[i].artistId != artist
                    || row.rows.consents[i].terms.collectionId != entry.receipt.collectionId
                    || (row.rows.consents[i].authorityClass != 1
                        && row.rows.consents[i].authorityClass != 3)
            ) _invalid();
            _binding(row.bindings, row.rows.consents[i].bindingGeneration, artist);
        } else if (op == 20) {
            uint256 i = counts[4]++;
            if (i >= row.rows.royalties.length) _invalid();
            if (
                row.rows.royalties[i].item.recordHash != record
                    || row.rows.royalties[i].item.artistId != artist
                    || row.rows.royalties[i].terms.collectionId != entry.receipt.collectionId
            ) _invalid();
            _binding(row.bindings, row.rows.royalties[i].item.bindingGeneration, artist);
            use.grant = row.rows.royalties[i].grant;
            use.capability = D.ROYALTY_FREEZE;
        } else if (op == 21) {
            uint256 i = counts[5]++;
            if (i >= row.rows.freezes.length) _invalid();
            if (
                row.rows.freezes[i].recordHash != record || row.rows.freezes[i].artistId != artist
                    || (row.rows.freezes[i].authorityClass != 1
                        && row.rows.freezes[i].authorityClass != 3)
            ) _invalid();
            _binding(row.bindings, row.rows.freezes[i].bindingGeneration, artist);
        } else if (op == 52) {
            // Its three-field original record has no saved generation or delegation. The
            // enclosing validator authenticates that row and its exact native occurrence.
            if (!_historical(row.bindings, artist, false)) _invalid();
        } else {
            _invalid();
        }
    }

    function _binding(T.Binding[] calldata rows, uint64 generation, bytes32 artist)
        private
        pure
        returns (T.Binding calldata row)
    {
        if (generation == 0 || generation > rows.length) _invalid();
        row = rows[generation - 1];
        if (row.generation != generation || row.artistId != artist || !row.accepted) _invalid();
    }

    function _historical(T.Binding[] calldata rows, bytes32 artist, bool modeTwo)
        private
        pure
        returns (bool)
    {
        for (uint256 i; i < rows.length; ++i) {
            if (
                rows[i].artistId == artist && rows[i].accepted
                    && (!modeTwo || rows[i].consentMode == 2)
            ) return true;
        }
        return false;
    }

    function _signature(IH.Bundle calldata identity, bytes32 record) private pure {
        bool found;
        for (uint256 i; i < identity.signatures.length; ++i) {
            if (identity.signatures[i].recordHash != record) continue;
            if (found || identity.signatures[i].signature.length > 4096) _invalid();
            found = true;
        }
        // Empty direct/Safe evidence is meaningful. Exact source bytes and original nonce
        // inventories, not current ERC1271 behavior, authenticate the saved authorization.
        if (!found) _invalid();
    }

    function _grant(
        IH.Bundle calldata identity,
        RH.Provenance calldata p,
        RH.JournalEntry calldata entry,
        bytes32 hash,
        uint32 capability
    ) private pure returns (uint256 at) {
        uint256 useEra = _era(p, entry.position.point.environmentHash);
        bool found;
        for (uint256 i; i < identity.delegations.length; ++i) {
            IH.DelegationRow calldata row = identity.delegations[i];
            if (row.recordHash != hash) continue;
            if (found) _invalid();
            found = true;
            at = i;
            D.Grant calldata grant = row.record.grant;
            if (
                grant.artistId != identity.artistId || grant.delegate == address(0)
                    || (grant.collectionId != 0 && grant.collectionId != entry.receipt.collectionId)
                    || (grant.capabilities & capability) == 0 || row.position.point.ownerIndex != 2
                    || _era(p, row.position.point.environmentHash) > useEra
            ) _invalid();
            Chronology.validatePoint(p, row.position.point);
            if (
                row.record.revoked
                    && _era(
                            p,
                            _revocation(p, identity.artistId, row.record.revocationRecordHash)
                            .environmentHash
                        ) < useEra
            ) _invalid();
            for (uint256 j = i + 1; j < identity.delegations.length; ++j) {
                IH.DelegationRow calldata next = identity.delegations[j];
                if (
                    next.record.grant.delegate == grant.delegate
                        && _era(p, next.position.point.environmentHash) < useEra
                ) _invalid();
            }
        }
        // Same-era owner2 and owner6 revisions are incomparable. The authenticated original
        // writer supplies cross-owner order, live epoch, validity and consumption facts.
        if (!found) _invalid();
    }

    function _saleNonce(
        IH.Bundle calldata identity,
        RH.Provenance calldata p,
        uint256 grantIndex,
        RH.Point calldata salePoint,
        uint256 nonce
    ) private pure {
        IH.DelegationRow calldata grant = identity.delegations[grantIndex];
        bytes32 scope = keccak256(
            abi.encode(Delegation.lane(identity.artistId, grant.record.grant.delegate), nonce)
        );
        RH.Point memory admitted;
        bool found;
        for (uint256 i; i < p.aliases[2].length; ++i) {
            RH.ReplayAlias calldata alias_ = p.aliases[2][i];
            if (alias_.surface != DELEGATE_NONCE || alias_.scope != scope) continue;
            if (
                alias_.ownerIndex != 2 || alias_.admittedAt.ownerIndex != 2 || alias_.cell.kind != 1
                    || alias_.cell.status != 2 || alias_.cell.commitment == 0
                    || alias_.admittedAt.environmentHash != salePoint.environmentHash
                    || (found
                        && keccak256(abi.encode(admitted))
                            != keccak256(abi.encode(alias_.admittedAt)))
            ) _invalid();
            admitted = alias_.admittedAt;
            found = true;
        }
        if (!found || !Chronology.before(p, grant.position.point, admitted)) _invalid();
        if (
            grant.record.revoked
                && !Chronology.before(
                    p,
                    admitted,
                    _revocation(p, identity.artistId, grant.record.revocationRecordHash)
                )
        ) _invalid();
        for (uint256 i = grantIndex + 1; i < identity.delegations.length; ++i) {
            if (
                identity.delegations[i].record.grant.delegate == grant.record.grant.delegate
                    && !Chronology.before(p, admitted, identity.delegations[i].position.point)
            ) _invalid();
        }
        // Sale's saved timestamp is observation time, not the authorization deadline. Its
        // original digest is the authenticated nonce cell; no new digest preimage is invented.
    }

    function _revocation(RH.Provenance calldata p, bytes32 artist, bytes32 record)
        private
        pure
        returns (RH.Point memory point)
    {
        bool found;
        if (record == 0) _invalid();
        for (uint256 i; i < p.journals[2].length; ++i) {
            RH.JournalEntry calldata entry = p.journals[2][i];
            if (entry.receipt.recordHash != record) continue;
            if (
                found || entry.receipt.operation != 27 || entry.receipt.artistId != artist
                    || entry.receipt.collectionId != 0 || entry.position.point.ownerIndex != 2
            ) _invalid();
            Chronology.validatePoint(p, entry.position.point);
            point = entry.position.point;
            found = true;
        }
        if (!found) _invalid();
    }

    function _artist(M.State calldata scope, bytes32 artist) private pure returns (uint256) {
        if (artist == 0) _invalid();
        for (uint256 i; i < scope.artists.length; ++i) {
            if (scope.artists[i].artistId == artist) return i;
        }
        _invalid();
    }

    function _collection(M.State calldata scope, uint256 collection)
        private
        pure
        returns (uint256)
    {
        for (uint256 i; i < scope.collections.length; ++i) {
            if (scope.collections[i].collectionId == collection) return i;
        }
        _invalid();
    }

    function _era(RH.Provenance calldata p, bytes32 origin) private pure returns (uint256) {
        for (uint256 i; i < p.eras.length; ++i) {
            if (p.eras[i].originHash == origin) return i;
        }
        _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
