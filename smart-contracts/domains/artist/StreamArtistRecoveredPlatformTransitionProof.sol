// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { StreamArtistOwnerCommit as Commit } from "./StreamArtistOwnerCommit.sol";

/// @notice Original owner4 transition and record-chain preimages at its own independent clock.
library StreamArtistRecoveredPlatformTransitionProof {
    function validate(
        RH.OriginEnvironment memory o,
        RH.OwnerProvenance memory p,
        uint256 era,
        H.Envelope memory e,
        bytes32 action,
        bytes32 state,
        bytes32 replay,
        bytes32 record
    ) public pure returns (RH.Point memory point) {
        T.Snapshot memory a = e.before_[4];
        T.Snapshot memory b = e.after_[4];
        if (
            a.domainId != RH.ownerDomain(4) || b.domainId != a.domainId || a.stateRoot == 0
                || a.recordChainTip == 0 || a.revision < p.eras[era].lowerRevision
                || b.revision != a.revision + 1
                || b.revision > p.eras[era].checkpoint.ownerState.revision || e.actor == address(0)
        ) {
            _invalid();
        }
        Commit.Preimage memory preimage = Commit.Preimage(
            keccak256("6529STREAM_ARTIST_OWNER_STATE_TRANSITION_V2"),
            o.chainId,
            o.registry,
            o.coordinator,
            o.archive,
            o.owners[4],
            RH.ownerDomain(4),
            a.revision,
            b.revision,
            a.stateRoot,
            keccak256(abi.encode(e.operation, e.actor, action)),
            state,
            replay,
            keccak256(abi.encode(record))
        );
        if (b.stateRoot != keccak256(abi.encode(preimage))) _invalid();
        if (record == 0) {
            if (a.recordChainTip != b.recordChainTip) _invalid();
        } else {
            // The original operation60 owner commit has a zero record argument.
            uint64 sequence;
            for (uint256 i; i < p.journal.length; ++i) {
                RH.JournalEntry memory j = p.journal[i];
                if (
                    j.position.point.environmentHash != p.eras[era].originHash
                        || j.position.point.ownerRevision > a.revision
                ) continue;
                uint16 op = j.receipt.operation;
                // Exact nonzero record arguments of the supported original owner4 writers.
                if (op == 8 || op == 9 || op == 10 || op == 53 || op == 47 || op == 61) {
                    ++sequence;
                }
            }
            if (
                b.recordChainTip
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_OWNER_RECORD_TRANSITION_V2"),
                            o.chainId,
                            o.registry,
                            o.coordinator,
                            o.archive,
                            o.owners[4],
                            RH.ownerDomain(4),
                            sequence,
                            sequence + 1,
                            a.recordChainTip,
                            record
                        )
                    )
            ) _invalid();
        }
        point = RH.Point(p.eras[era].originHash, 4, b.revision);
    }

    function replay(RH.OriginEnvironment memory o, uint16 op, bytes32 scope, bytes32 record)
        public
        pure
        returns (bytes32)
    {
        bytes32 surface = op == 10
            ? keccak256("attribution_lifecycle.replay.claim_record_hash_uniqueness")
            : keccak256(abi.encode("PLATFORM_WORKS", op));
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                o.chainId,
                o.registry,
                o.coordinator,
                o.archive,
                o.owners[4],
                RH.ownerDomain(4),
                surface,
                scope
            )
        );
        record; // The original host passes the returned key, not a hash of the cell.
        return key;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
