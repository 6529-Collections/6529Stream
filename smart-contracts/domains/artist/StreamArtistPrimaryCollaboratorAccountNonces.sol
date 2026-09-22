// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
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
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    IStreamArtistCollaboratorIdentityOwner as Identity
} from "../../interfaces/stream/artist/IStreamArtistCollaboratorIdentityOwner.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationGuards as Guards
} from "./StreamArtistRecoveredMultipleGenerationGuards.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";

/// @notice Persistent account-kind3 lanes, distinct from every Artist's original principal lane.
/// @dev Reconstructs every consumed bit from original op6 Archive evidence, including a reused
/// account across different identities/eras. No per-identity reset or nonce renumbering occurs.
library StreamArtistPrimaryCollaboratorAccountNonces {
    bytes32 private constant NONCE =
        keccak256("identity_authority.replay.collaborator_account_nonce");
    bytes32 private constant DIGEST =
        keccak256("identity_authority.replay.collaborator_account_digest");

    struct Use {
        address account;
        uint256 nonce;
        bytes32 digest;
        RH.Point point;
        bool direct;
    }

    function collect(RH.Provenance memory p, PC.Inventory memory inventory)
        public
        view
        returns (IH.NonceLane[] memory lanes)
    {
        RH.OwnerProvenance memory local = RH.ownerProvenance(p, 2);
        address source = p.origins[p.origins.length - 1].owners[2];
        Provenance.validateOwnerSource(local, 2, source);
        Use[] memory uses = _uses(p, inventory);
        uint256 total = local.eras[local.eras.length - 1].checkpoint.nonceIndexCount;
        if (total > RH.MAX_NONCE_INDICES) _invalid();
        lanes = new IH.NonceLane[](total);
        uint256 count;
        for (uint256 i; i < total; ++i) {
            CP.NonceIndex memory index = CP(source).authorityNonceIndexAt(i);
            if (index.kind != 3) continue;
            if (
                index.key == 0 || uint256(index.key) > type(uint160).max || index.prefixCount == 0
                    || index.prefixCount > RH.MAX_NONCE_PREFIXES
            ) _invalid();
            IH.NonceLane memory row;
            row.kind = 3;
            row.key = index.key;
            (, row.hint) = Identity(source)
                .collaboratorRegistrationNonceState(address(uint160(uint256(index.key))), 0);
            row.words = new AH.NonceWord[](index.prefixCount);
            for (uint256 j; j < row.words.length; ++j) {
                (row.words[j].prefix, row.words[j].words, row.words[j].exhausted) =
                    CP(source).authorityNonceWordAt(3, index.key, j);
            }
            lanes[count++] = row;
        }
        assembly ("memory-safe") { mstore(lanes, count) }
        validate(lanes, uses, local);
    }

    function _uses(RH.Provenance memory p, PC.Inventory memory inventory)
        private
        view
        returns (Use[] memory uses)
    {
        uses = new Use[](inventory.operations.length);
        uint256 count;
        for (uint256 i; i < inventory.operations.length; ++i) {
            H.OperationEvidence memory operation = inventory.operations[i];
            if (operation.operation != 6) continue;
            uint256 era = _era(p, operation.originHash);
            H.Envelope memory e =
                Catalogue.read(p.origins[era], inventory.catalogues[era], operation.evidence);
            PC.IdentityAcceptance memory x = Leaves.identity(p.origins[era], e);
            uses[count++] = Use(
                x.proposal.proposal.account,
                x.authorization.nonce,
                x.approval.digest,
                RH.Point(operation.originHash, 2, e.after_[2].revision),
                x.approval.direct
            );
        }
        assembly ("memory-safe") { mstore(uses, count) }
    }

    /// @dev The profile obtains uses only from its complete authenticated original Archive.
    /// It must also validate every principal lane and the full global nonce-index union.
    function validate(IH.NonceLane[] memory lanes, Use[] memory uses, RH.OwnerProvenance memory p)
        public
        pure
    {
        if (lanes.length > RH.MAX_NONCE_INDICES) _invalid();
        bool[] memory aliases = new bool[](p.aliases.length);
        bool[] memory covered = new bool[](uses.length);
        for (uint256 i; i < uses.length; ++i) {
            Use memory u = uses[i];
            if (u.account == address(0) || u.digest == 0) _invalid();
            for (uint256 j; j < i; ++j) {
                if (
                    uses[j].account == u.account
                        && (uses[j].nonce == u.nonce || uses[j].digest == u.digest)
                ) _invalid();
            }
            // The original direct path consumes the lowest unused account nonce. Signed
            // submissions may be sparse, and every later direct use observes that same lane.
            if (u.direct) {
                uint256 next;
                bool advance = true;
                while (advance) {
                    advance = false;
                    for (uint256 j; j < i; ++j) {
                        if (uses[j].account == u.account && uses[j].nonce == next) {
                            ++next;
                            advance = true;
                            break;
                        }
                    }
                }
                if (u.nonce != next) _invalid();
            }
            Guards.mark(
                p, aliases, NONCE, keccak256(abi.encode(u.account, u.nonce)), u.digest, u.point
            );
            Guards.mark(
                p, aliases, DIGEST, keccak256(abi.encode(u.account, u.digest)), u.digest, u.point
            );
        }
        for (uint256 i; i < lanes.length; ++i) {
            IH.NonceLane memory row = lanes[i];
            if (
                row.kind != 3 || row.key == 0 || uint256(row.key) > type(uint160).max
                    || row.words.length == 0 || row.words.length > RH.MAX_NONCE_PREFIXES
            ) _invalid();
            for (uint256 j; j < i; ++j) {
                if (lanes[j].key == row.key) _invalid();
            }
            address account = address(uint160(uint256(row.key)));
            bool found;
            for (uint256 j; j < uses.length; ++j) {
                if (uses[j].account != account) continue;
                if (covered[j]) _invalid();
                covered[j] = true;
                found = true;
                uint256 matches;
                for (uint256 k; k < row.words.length; ++k) {
                    if (row.words[k].prefix == uses[j].nonce >> 8) ++matches;
                }
                if (matches != 1) _invalid();
            }
            if (!found) _invalid();
            _words(row, uses, account);
        }
        for (uint256 i; i < covered.length; ++i) {
            if (!covered[i]) _invalid();
        }
        for (uint256 i; i < aliases.length; ++i) {
            if ((p.aliases[i].surface == NONCE || p.aliases[i].surface == DIGEST) && !aliases[i]) {
                _invalid();
            }
        }
    }

    function _words(IH.NonceLane memory row, Use[] memory uses, address account) private pure {
        for (uint256 i; i < row.words.length; ++i) {
            for (uint256 j; j < i; ++j) {
                if (row.words[j].prefix == row.words[i].prefix) _invalid();
            }
            if (row.words[i].prefix > type(uint248).max || row.words[i].exhausted) _invalid();
            for (uint256 level; level < 32; ++level) {
                uint256 expected;
                uint256 prefix = row.words[i].prefix >> (8 * level);
                if (level == 0) {
                    for (uint256 j; j < uses.length; ++j) {
                        if (uses[j].account == account && uses[j].nonce >> 8 == prefix) {
                            expected |= uint256(1) << (uses[j].nonce & 255);
                        }
                    }
                    if (expected == 0) _invalid();
                } else {
                    for (uint256 j; j < row.words.length; ++j) {
                        uint256 child = row.words[j].prefix >> (8 * (level - 1));
                        if (
                            child >> 8 == prefix
                                && row.words[j].words[level - 1] == type(uint256).max
                        ) {
                            expected |= uint256(1) << (child & 255);
                        }
                    }
                }
                if (row.words[i].words[level] != expected) _invalid();
            }
        }
        uint256 next;
        for (uint256 level = 32; level != 0;) {
            --level;
            uint256 word;
            for (uint256 i; i < row.words.length; ++i) {
                if (row.words[i].prefix >> (8 * level) == next) {
                    word = row.words[i].words[level];
                    break;
                }
            }
            if (word == type(uint256).max) _invalid();
            uint256 bit;
            while ((word & (uint256(1) << bit)) != 0) ++bit;
            next = (next << 8) | bit;
        }
        if (row.hint != next) _invalid();
    }

    function _era(RH.Provenance memory p, bytes32 origin) private pure returns (uint256) {
        for (uint256 i; i < p.eras.length; ++i) {
            if (p.eras[i].originHash == origin) return i;
        }
        _invalid();
        return 0;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
