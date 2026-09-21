// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredSanctionCatalogue as Catalogue
} from "./StreamArtistRecoveredSanctionCatalogue.sol";
import {
    StreamArtistRecoveredSanctionEvidenceCodec as Codec
} from "./StreamArtistRecoveredSanctionEvidenceCodec.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";

/// @notice Exact original signed op12 authorization joins, without current-authority substitution.
library StreamArtistRecoveredSanctionIdentityFacts {
    bytes32 private constant NONCE = keccak256("identity_authority.replay.nonce_allocator");
    bytes32 private constant OBSERVED =
        keccak256("identity_authority.replay.authorization_consumed_digest");

    function validate(
        bytes32 artistId,
        IH.SignatureRow[] memory signatures,
        IH.NonceLane[] memory nonces,
        H.Inventory memory history,
        RH.Provenance memory p
    ) public view {
        uint256 count;
        for (uint256 i; i < history.operations.length; ++i) {
            H.OperationEvidence memory op = history.operations[i];
            if (op.operation != 12) continue;
            uint256 era = _era(p, op.originHash);
            H.Envelope memory e =
                Catalogue.read(p.origins[era], history.catalogues[era], op.evidence);
            H.SanctionPayload memory s = Codec.sanction(e.payload);
            if (
                s.record.artistId != artistId || count >= history.sanctions.length
                    || history.sanctions[count++].record.recordHash != s.record.recordHash
            ) _invalid();
            RH.Point memory point = RH.Point(op.originHash, 2, e.after_[2].revision);
            Clock.validatePoint(p, point);
            if (
                point.ownerRevision <= p.eras[era].lowerRevisions[2]
                    || e.before_[2].recordChainTip != e.after_[2].recordChainTip
            ) _invalid();
            uint256 matched;
            for (uint256 j; j < signatures.length; ++j) {
                if (signatures[j].recordHash != s.record.recordHash) continue;
                if (
                    signatures[j].signature.length == 0 || signatures[j].signature.length > 4096
                        || keccak256(signatures[j].signature)
                            != keccak256(s.authorization.signature)
                ) _invalid();
                ++matched;
            }
            if (matched != 1) _invalid();
            _nonce(p, point, artistId, s.record.nonce, s.record.digest);
            bool consumed;
            for (uint256 j; j < nonces.length; ++j) {
                if (nonces[j].kind != 1 || nonces[j].key != artistId) continue;
                for (uint256 k; k < nonces[j].words.length; ++k) {
                    if (
                        nonces[j].words[k].prefix == s.record.nonce >> 8
                            && (nonces[j].words[k].words[0] & (uint256(1) << uint8(s.record.nonce)))
                                != 0
                    ) consumed = true;
                }
            }
            if (!consumed) _invalid();
        }
        if (count != history.sanctions.length) _invalid();
        // Original op12 commits Identity authorization with record zero and emits no native row.
        for (uint256 i; i < p.journals[2].length; ++i) {
            if (
                p.journals[2][i].receipt.operation == 12 || p.journals[2][i].receipt.operation == 13
            ) _invalid();
        }
    }

    function _nonce(
        RH.Provenance memory p,
        RH.Point memory point,
        bytes32 artistId,
        uint256 nonce,
        bytes32 digest
    ) private pure {
        bool used;
        bool observed;
        for (uint256 i; i < p.aliases[2].length; ++i) {
            RH.ReplayAlias memory a = p.aliases[2][i];
            if (a.surface == NONCE && a.scope == keccak256(abi.encode(artistId, nonce))) {
                if (
                    a.cell.kind != 1 || a.cell.status != 2 || a.cell.commitment != digest
                        || !D.samePoint(a.admittedAt, point)
                ) _invalid();
                used = true;
            }
            if (a.surface == OBSERVED && a.scope == keccak256(abi.encode(artistId, digest))) {
                if (
                    a.cell.kind != 1 || a.cell.status != 2 || a.cell.commitment != digest
                        || Clock.compare(p, a.admittedAt, point) > 0
                ) _invalid();
                observed = true;
            }
        }
        if (!used || !observed || digest == 0) _invalid();
    }

    function _era(RH.Provenance memory p, bytes32 origin) private pure returns (uint256) {
        for (uint256 i; i < p.eras.length; ++i) {
            if (p.eras[i].originHash == origin) return i;
        }
        _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
