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
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorCatalogue as Catalogue
} from "./StreamArtistPrimaryCollaboratorCatalogue.sol";
import {
    StreamArtistPrimaryCollaboratorLeaves as Leaves
} from "./StreamArtistPrimaryCollaboratorLeaves.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationGuards as Guards
} from "./StreamArtistRecoveredMultipleGenerationGuards.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistRecoveredPlatformPayload as Payload
} from "./StreamArtistRecoveredPlatformPayload.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";

/// @notice Exact retained original signatures, documents and principal authorization aliases.
/// @dev Canonical whole Identity bundles were authenticated by IdentitySource first. This
/// joins their original bytes to Archive occurrences; it never reauthorizes a historical Safe.
library StreamArtistPrimaryCollaboratorIdentityFacts {
    bytes32 private constant NONCE = keccak256("identity_authority.replay.nonce_allocator");
    bytes32 private constant OBSERVED =
        keccak256("identity_authority.replay.authorization_consumed_digest");

    struct Context {
        bytes[] identities;
        M.State scope;
        PC.BindingInventory bindings;
        PC.Inventory inventory;
        PC.PrimaryReceipt[] primary;
        RH.Provenance provenance;
    }

    function validate(Context calldata x) public view {
        if (x.identities.length != x.scope.artists.length) _invalid();
        for (uint256 a; a < x.identities.length; ++a) {
            IH.Bundle calldata b = Frame.bundle(x.identities[a]);
            if (b.artistId != x.scope.artists[a].artistId) _invalid();
        }
        for (uint256 k; k < x.bindings.bindings.length; ++k) {
            uint256 a = _artist(x.scope, x.scope.collections[k].artistId);
            for (uint256 g; g < x.bindings.bindings[k].bindings.rows.length; ++g) {
                _document(
                    x.identities[a],
                    x.bindings.bindings[k].bindings.rows[g].item.identityRecordHash,
                    bytes(""),
                    false
                );
            }
        }
        validateAuthorizations(x);
    }

    /// @notice Shared original op2/3/6/7 signature and nonce facts after profile-specific joins.
    /// @dev The original validate entry still applies its same-principal document boundary.
    /// Callers of this phase first authenticate canonical Identity bundles and the complete
    /// source catalogue; no current authority or recovery-count predicate is substituted.
    function validateAuthorizations(Context calldata x) public view {
        RH.OwnerProvenance memory p = RH.ownerProvenance(x.provenance, 2);
        for (uint256 i; i < x.inventory.operations.length; ++i) {
            H.OperationEvidence calldata item = x.inventory.operations[i];
            if (
                item.operation != 2 && item.operation != 3 && item.operation != 6
                    && item.operation != 7
            ) {
                continue;
            }
            uint256 era = A.era(p, item.originHash);
            H.Envelope memory e =
                Catalogue.read(p.origins[era], x.inventory.catalogues[era], item.evidence);
            if (e.operation != item.operation) _invalid();
            RH.Point memory point = RH.Point(item.originHash, 2, e.after_[2].revision);
            Clock.validateOwnerPoint(p, 2, point);
            if (e.operation == 6) {
                PC.IdentityAcceptance memory row = Leaves.identity(p.origins[era], e);
                uint256 a = _artist(x.scope, e.value);
                _document(
                    x.identities[a], row.proposal.proposal.identityRecordHash, row.document, true
                );
                _signature(x.identities[a], e.value, row.authorization.signature);
                _authorization(p, e.value, row.authorization.nonce, row.approval.digest, point);
                _aliasAt(
                    p, NONCE, keccak256(abi.encode(bytes32(0), row.allocationNonce)), e.value, point
                );
                _aliasAt(
                    p,
                    keccak256("identity_authority.replay.identity_uniqueness"),
                    e.value,
                    e.value,
                    point
                );
            } else if (e.operation == 7) {
                PC.BindingAcceptance memory row = Leaves.acceptance(p.origins[era], e);
                uint256 a = _artist(x.scope, row.artistId);
                _signature(x.identities[a], e.value, row.authorization.signature);
                _authorization(p, row.artistId, row.authorization.nonce, row.approval.digest, point);
            } else if (e.operation == 2) {
                uint256 k = _primaryCollection(x.provenance, e.value);
                uint256 c = _collection(x.scope, k);
                uint256 generation = _primaryGeneration(x.bindings, c, x.primary, i, e.value);
                PC.PrimaryAcceptance memory row = Leaves.primary(
                    p.origins[era], e, x.bindings.bindings[c].bindings.rows[generation].terms.count
                );
                uint256 a = _artist(x.scope, row.acceptance.binding_.artistId);
                _signature(x.identities[a], e.value, row.acceptance.authorization.signature);
                _authorization(
                    p,
                    row.acceptance.binding_.artistId,
                    row.acceptance.authorization.nonce,
                    row.acceptance.proof.digest,
                    point
                );
            } else {
                Payload.Refusal memory row = Payload.refusal(e.payload);
                uint256 a = _artist(x.scope, row.binding_.artistId);
                _signature(x.identities[a], e.value, row.authorization.signature);
                _authorization(
                    p, row.binding_.artistId, row.authorization.nonce, row.proof.digest, point
                );
            }
        }
    }

    function _primaryCollection(RH.Provenance calldata p, bytes32 record)
        private
        pure
        returns (uint256 cid)
    {
        bool found;
        for (uint256 i; i < p.journals[3].length; ++i) {
            if (p.journals[3][i].receipt.recordHash == record) {
                if (found || p.journals[3][i].receipt.operation != 2) _invalid();
                found = true;
                cid = p.journals[3][i].receipt.collectionId;
            }
        }
        if (!found) _invalid();
    }

    function _primaryGeneration(
        PC.BindingInventory calldata b,
        uint256 k,
        PC.PrimaryReceipt[] calldata primary,
        uint256 index,
        bytes32 record
    ) private pure returns (uint256 generation) {
        bool found;
        for (uint256 i; i < primary.length; ++i) {
            if (primary[i].operationIndex == index) {
                PC.PrimaryReceipt calldata r = primary[i];
                if (
                    found || r.recordHash != record || r.generation == 0
                        || r.generation > b.generations[k].length
                        || r.collectionId != b.bindings[k].bindings.collectionId
                        || r.bindingHash != b.generations[k][r.generation - 1].bindingHash
                ) _invalid();
                found = true;
                generation = r.generation - 1;
            }
        }
        if (!found) _invalid();
    }

    function _authorization(
        RH.OwnerProvenance memory p,
        bytes32 artist,
        uint256 nonce,
        bytes32 digest,
        RH.Point memory point
    ) private pure {
        _aliasAt(p, NONCE, keccak256(abi.encode(artist, nonce)), digest, point);
        RH.Point memory observed =
            Guards.resolved(p, OBSERVED, keccak256(abi.encode(artist, digest)), digest);
        if (
            keccak256(abi.encode(observed)) != keccak256(abi.encode(point))
                && !Clock.beforeOwner(p, 2, observed, point)
        ) _invalid();
        bool[] memory used = new bool[](p.aliases.length);
        Guards.mark(p, used, OBSERVED, keccak256(abi.encode(artist, digest)), digest, observed);
    }

    function _aliasAt(
        RH.OwnerProvenance memory p,
        bytes32 surface,
        bytes32 scope,
        bytes32 value,
        RH.Point memory point
    ) private pure {
        bool[] memory used = new bool[](p.aliases.length);
        Guards.mark(p, used, surface, scope, value, point);
    }

    function _signature(bytes calldata raw, bytes32 record, bytes memory signature) private pure {
        IH.Bundle calldata b = Frame.bundle(raw);
        bool found;
        for (uint256 i; i < b.signatures.length; ++i) {
            if (b.signatures[i].recordHash == record) {
                if (
                    found || signature.length > 4096
                        || keccak256(b.signatures[i].signature) != keccak256(signature)
                ) _invalid();
                found = true;
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
            if (b.documents[i].documentHash == hash) {
                if (
                    found || keccak256(b.documents[i].document) != hash
                        || (exact && keccak256(document) != hash)
                ) _invalid();
                found = true;
            }
        }
        if (!found) _invalid();
    }

    function _artist(M.State calldata s, bytes32 id) private pure returns (uint256) {
        for (uint256 i; i < s.artists.length; ++i) {
            if (s.artists[i].artistId == id) return i;
        }
        _invalid();
        return 0;
    }

    function _collection(M.State calldata s, uint256 id) private pure returns (uint256) {
        for (uint256 i; i < s.collections.length; ++i) {
            if (s.collections[i].collectionId == id) return i;
        }
        _invalid();
        return 0;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
