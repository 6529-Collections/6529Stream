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
import { StreamArtistCompleteHistoryTypes as CT } from "./StreamArtistCompleteHistoryTypes.sol";
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as Clocks
} from "./StreamArtistPrimaryCollaboratorClocks.sol";
import {
    StreamArtistPrimaryCollaboratorIdentityFacts as Original
} from "./StreamArtistPrimaryCollaboratorIdentityFacts.sol";
import {
    StreamArtistPrimaryCollaboratorLeaves as Leaves
} from "./StreamArtistPrimaryCollaboratorLeaves.sol";
import {
    StreamArtistCompleteHistoryCatalogue as Catalogue
} from "./StreamArtistCompleteHistoryCatalogue.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";
import {
    StreamArtistRecoveredPlatformPayload as Payload
} from "./StreamArtistRecoveredPlatformPayload.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistRecoveredMultipleGenerationGuards as Guards
} from "./StreamArtistRecoveredMultipleGenerationGuards.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";

/// @notice Original registration, retained documents and signatures for every historical Artist.
/// @dev Fixed source stages authenticate canonical whole Identity bundles first. A current
/// collection selector joins only its latest binding; every earlier row keeps its own principal.
library StreamArtistCompleteHistoryIdentityFacts {
    bytes32 private constant NONCE = keccak256("identity_authority.replay.nonce_allocator");

    struct Context {
        bytes[] identities;
        M.State scope;
        CT.Inventory inventory;
        Clocks.Result clocks;
    }

    struct Registration {
        bytes32 artist;
        address account;
        bytes32 documentHash;
        bytes document;
        string uri;
        string displayName;
        uint256 allocation;
        bool knownAllocation;
    }

    function validate(Context calldata x) public view {
        RH.OwnerProvenance memory p = RH.ownerProvenance(x.inventory.provenance, 2);
        _documents(x, p);
        Catalogue.requireCurrent(
            x.inventory.provenance, x.inventory.archive.catalogues, x.inventory.archive.operations
        );
        bool[] memory seen = new bool[](p.journal.length);
        for (uint256 i; i < x.inventory.archive.operations.length; ++i) {
            H.OperationEvidence calldata item = x.inventory.archive.operations[i];
            if (item.operation != 1 && item.operation != 6) continue;
            uint256 era = A.era(p, item.originHash);
            H.Envelope memory e = Catalogue.read(
                p.origins[era], x.inventory.archive.catalogues[era], item.evidence
            );
            if (e.operation != item.operation) _invalid();
            if (e.operation == 1) {
                _proposal(x, p, seen, era, e);
            } else {
                PC.IdentityAcceptance memory row = Leaves.identity(p.origins[era], e);
                _registered(
                    x,
                    p,
                    seen,
                    era,
                    e,
                    Registration(
                        e.value,
                        row.proposal.proposal.account,
                        row.proposal.proposal.identityRecordHash,
                        row.document,
                        row.proposal.proposal.identityRecordURI,
                        row.displayName,
                        row.allocationNonce,
                        true
                    )
                );
            }
        }
        uint256 count;
        bool[] memory principals = new bool[](x.scope.artists.length);
        for (uint256 j; j < p.journal.length; ++j) {
            uint16 op = p.journal[j].receipt.operation;
            if (op != 1 && op != 6) continue;
            if (!seen[j]) _invalid();
            uint256 a = _artist(x.scope, p.journal[j].receipt.artistId);
            if (principals[a]) _invalid();
            principals[a] = true;
            ++count;
        }
        if (count != principals.length) _invalid();
        Original.validateAuthorizations(
            Original.Context(
                x.identities,
                x.scope,
                x.inventory.bindings,
                x.inventory.archive,
                x.clocks.primary,
                x.inventory.provenance
            )
        );
    }

    function _documents(Context calldata x, RH.OwnerProvenance memory p) private pure {
        if (
            x.identities.length == 0 || x.identities.length != x.scope.artists.length
                || x.inventory.bindings.bindings.length != x.scope.collections.length
                || p.eras.length == 0
        ) _invalid();
        for (uint256 a; a < x.identities.length; ++a) {
            IH.Bundle calldata b = Frame.bundle(x.identities[a]);
            if (
                b.artistId == 0 || b.artistId != x.scope.artists[a].artistId
                    || b.nextRegistrationNonce != x.identities.length
                    || (a != 0 && b.artistId <= x.scope.artists[a - 1].artistId)
                    || keccak256(abi.encode(b.sourceSnapshot))
                        != keccak256(abi.encode(p.eras[p.eras.length - 1].checkpoint.ownerState))
            ) _invalid();
        }
        for (uint256 k; k < x.inventory.bindings.bindings.length; ++k) {
            for (uint256 g; g < x.inventory.bindings.bindings[k].bindings.rows.length; ++g) {
                T.Binding calldata row = x.inventory.bindings.bindings[k].bindings.rows[g].item;
                uint256 a = _artist(x.scope, row.artistId);
                _document(x.identities[a], row.identityRecordHash, bytes(""), false);
            }
        }
    }

    function _proposal(
        Context calldata x,
        RH.OwnerProvenance memory p,
        bool[] memory seen,
        uint256 era,
        H.Envelope memory e
    ) private pure {
        (uint256 k, uint256 g) = _binding(x, e.value);
        T.Binding calldata b = x.inventory.bindings.bindings[k].bindings.rows[g].item;
        Payload.Proposal memory data;
        bool corrected = x.inventory.bindings.bindings[k].corrections[g].recordHash != 0;
        uint256 allocation;
        if (corrected) {
            Payload.Correction memory c = Payload.correction(e.payload);
            data = Payload.Proposal(
                c.id, c.proposal, c.document, c.displayName, c.reused, c.roleHash, c.roleRevision
            );
            allocation = c.approval.registrationNonce;
        } else {
            data = Payload.proposal(e.payload);
        }
        if (
            data.id != x.scope.collections[k].collectionId
                || data.proposal.artistAddress != b.artistAddress
                || data.proposal.identityRecordHash != b.identityRecordHash
        ) _invalid();
        _document(
            x.identities[_artist(x.scope, b.artistId)], b.identityRecordHash, data.document, true
        );
        if (data.reused) {
            if (
                data.proposal.artistId != b.artistId || allocation != 0
                    || keccak256(abi.encode(e.before_[2])) != keccak256(abi.encode(e.after_[2]))
            ) _invalid();
            _existing(p, b.artistId, RH.Point(p.eras[era].originHash, 2, e.before_[2].revision));
        } else {
            if (data.proposal.artistId != 0) _invalid();
            _registered(
                x,
                p,
                seen,
                era,
                e,
                Registration(
                    b.artistId,
                    b.artistAddress,
                    b.identityRecordHash,
                    data.document,
                    data.proposal.identityRecordURI,
                    data.displayName,
                    allocation,
                    corrected
                )
            );
        }
    }

    function _registered(
        Context calldata x,
        RH.OwnerProvenance memory p,
        bool[] memory seen,
        uint256 era,
        H.Envelope memory e,
        Registration memory r
    ) private pure {
        if (e.after_[2].revision != e.before_[2].revision + 1) _invalid();
        RH.Point memory point = RH.Point(p.eras[era].originHash, 2, e.after_[2].revision);
        Clock.validateOwnerPoint(p, 2, point);
        uint256 ordinal;
        bool found;
        for (uint256 j; j < p.journal.length; ++j) {
            RH.JournalEntry memory entry = p.journal[j];
            if (entry.receipt.operation != 1 && entry.receipt.operation != 6) continue;
            if (entry.receipt.artistId == r.artist) {
                if (
                    found || seen[j] || entry.receipt.recordHash != r.artist
                        || entry.receipt.collectionId != 0 || entry.receipt.operation != e.operation
                        || keccak256(abi.encode(entry.position.point))
                            != keccak256(abi.encode(point))
                        || (r.knownAllocation && r.allocation != ordinal)
                ) _invalid();
                r.allocation = ordinal;
                seen[j] = true;
                found = true;
            }
            ++ordinal;
        }
        if (!found) _invalid();
        RH.OriginEnvironment memory o = p.origins[era];
        if (
            Hashes.identity(
                    Hashes.Environment(o.chainId, o.registry, o.core, o.manager),
                    r.account,
                    r.documentHash,
                    r.allocation
                ) != r.artist
        ) _invalid();
        IH.Bundle calldata b = Frame.bundle(x.identities[_artist(x.scope, r.artist)]);
        if (
            b.identity.identityRecordHash != r.documentHash
                || keccak256(bytes(b.identity.identityRecordURI)) != keccak256(bytes(r.uri))
                || keccak256(bytes(b.identity.displayName)) != keccak256(bytes(r.displayName))
                || r.document.length == 0 || r.document.length > 8192
                || bytes(r.displayName).length == 0 || bytes(r.displayName).length > 256
                || bytes(r.uri).length > 2048
        ) _invalid();
        _document(x.identities[_artist(x.scope, r.artist)], r.documentHash, r.document, true);
        bool[] memory used = new bool[](p.aliases.length);
        Guards.mark(
            p, used, NONCE, keccak256(abi.encode(bytes32(0), r.allocation)), r.artist, point
        );
    }

    function _existing(RH.OwnerProvenance memory p, bytes32 artist, RH.Point memory before_)
        private
        pure
    {
        bool found;
        for (uint256 j; j < p.journal.length; ++j) {
            RH.JournalEntry memory entry = p.journal[j];
            if (
                entry.receipt.artistId != artist
                    || (entry.receipt.operation != 1 && entry.receipt.operation != 6)
            ) continue;
            if (
                found
                    || (keccak256(abi.encode(entry.position.point))
                            != keccak256(abi.encode(before_))
                        && !Clock.beforeOwner(p, 2, entry.position.point, before_))
            ) _invalid();
            found = true;
        }
        if (!found) _invalid();
    }

    function _binding(Context calldata x, bytes32 hash)
        private
        pure
        returns (uint256 k, uint256 g)
    {
        bool found;
        for (uint256 i; i < x.inventory.bindings.bindings.length; ++i) {
            for (uint256 j; j < x.inventory.bindings.bindings[i].bindings.rows.length; ++j) {
                if (x.inventory.bindings.bindings[i].bindings.rows[j].item.bindingHash != hash) {
                    continue;
                }
                if (found) _invalid();
                found = true;
                k = i;
                g = j;
            }
        }
        if (!found) _invalid();
    }

    function _document(bytes calldata raw, bytes32 hash, bytes memory document, bool exact)
        private
        pure
    {
        IH.Bundle calldata b = Frame.bundle(raw);
        bool found;
        for (uint256 i; i < b.documents.length; ++i) {
            if (b.documents[i].documentHash != hash) continue;
            if (
                found || keccak256(b.documents[i].document) != hash
                    || (exact && keccak256(document) != hash)
            ) _invalid();
            found = true;
        }
        if (!found) _invalid();
    }

    function _artist(M.State calldata s, bytes32 id) private pure returns (uint256) {
        if (id == 0) _invalid();
        for (uint256 i; i < s.artists.length; ++i) {
            if (s.artists[i].artistId == id) return i;
        }
        _invalid();
        return 0;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
