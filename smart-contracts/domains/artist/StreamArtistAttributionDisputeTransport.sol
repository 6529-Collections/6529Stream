// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistDisputeState.sol";
import "./StreamArtistDisputeWithdrawalState.sol";
import "./StreamArtistRepudiationAttributionTransport.sol";

/// @notice Closed original Attribution mutation transport. Only the host consumes replay cells,
/// commits its owner state and appends native receipts; callers cannot supply a commit plan.
library StreamArtistAttributionDisputeTransport {
    enum ReplayKind {
        None,
        Single,
        GovernancePair
    }

    struct Result {
        bytes32 action;
        bytes32 state;
        bytes32 record;
        bytes32 replaySurface;
        bytes32 replayScope;
        bytes32 replayCommitment;
        bytes32 governanceScope;
        bytes32 governanceCommitment;
        ReplayKind replayKind;
        bytes32 artistId;
        uint256 collectionId;
        bool nativeReceipt;
        bytes32 output;
    }

    function applyEncoded(
        AttrState.State storage s,
        StreamArtistHashes.Environment memory e,
        bytes calldata data
    ) public returns (Result memory r) {
        bytes4 selector = bytes4(data[:4]);
        if (selector == IStreamArtistAttributionDisputesOwner.applyDispute.selector) {
            return _dispute(s, e, data);
        }
        if (selector == IStreamArtistAttributionDisputesOwner.applyDisputeResolution.selector) {
            return _resolution(s, data);
        }
        if (selector == IStreamArtistDisputeWithdrawalOwner.applyDisputeWithdrawal.selector) {
            AD.Mutation memory m = StreamArtistDisputeWithdrawalState.applyEncoded(s, e, data);
            (, AD.Filing memory p, AD.Admission memory a,) =
                abi.decode(data[4:], (T.ActionContext, AD.Filing, AD.Admission, uint256));
            r = _disputeResult(m, keccak256("attribution_lifecycle.replay.dispute_withdrawal_key"));
            r.artistId = a.binding_.artistId;
            r.collectionId = p.collectionId;
            r.nativeReceipt = true;
            return r;
        }
        bytes32 surface;
        if (selector == IStreamArtistRepudiationOwner.stageRepudiation.selector) {
            surface = keccak256("attribution_lifecycle.replay.repudiation_key");
        } else if (selector == IStreamArtistRepudiationOwner.vetoRepudiation.selector) {
            surface = keccak256("attribution_lifecycle.replay.repudiation_veto_key");
        } else if (selector == IStreamArtistRepudiationOwner.cancelRepudiation.selector) {
            surface = keccak256("attribution_lifecycle.replay.repudiation_cancellation_key");
        } else if (selector == IStreamArtistRepudiationOwner.executeRepudiation.selector) {
            surface = keccak256("attribution_lifecycle.replay.repudiation_execution_key");
        } else {
            revert T.InvalidRecord();
        }
        RP.Mutation memory m = StreamArtistRepudiationAttributionTransport.applyEncoded(s, e, data);
        r.action = m.action;
        r.state = m.state;
        r.record = m.record;
        r.replaySurface = surface;
        r.replayScope = m.replayScope;
        r.replayCommitment = m.replayCommitment;
        r.replayKind = ReplayKind.Single;
        if (selector == IStreamArtistRepudiationOwner.stageRepudiation.selector) {
            (, AD.Filing memory p, RP.Admission memory a,) =
                abi.decode(data[4:], (T.ActionContext, AD.Filing, RP.Admission, uint256));
            r.artistId = a.binding_.artistId;
            r.collectionId = p.collectionId;
            r.nativeReceipt = true;
            r.output = m.record;
        }
    }

    function _dispute(
        AttrState.State storage s,
        StreamArtistHashes.Environment memory e,
        bytes calldata data
    ) private returns (Result memory r) {
        AD.Mutation memory m = StreamArtistDisputeState.applyEncoded(s, e, data);
        (, AD.Filing memory p, AD.Admission memory a,, Contest.GovernanceWitness memory g) = abi.decode(
            data[4:], (T.ActionContext, AD.Filing, AD.Admission, uint256, Contest.GovernanceWitness)
        );
        bool opening = p.disputeAction == 1;
        if (opening) {
            bytes32 invalidated =
                StreamArtistRepudiationState.invalidateByDispute(p.collectionId, m.record);
            if (invalidated != 0) m.state = keccak256(abi.encode(m.state, invalidated));
        }
        r = _disputeResult(
            m,
            opening
                ? keccak256("attribution_lifecycle.replay.dispute_key")
                : keccak256("attribution_lifecycle.replay.counter_statement_key")
        );
        if (g.actionId != 0) {
            r.replayKind = ReplayKind.GovernancePair;
            r.governanceScope = g.actionId;
            r.governanceCommitment = m.record;
        }
        r.artistId = a.binding_.artistId;
        r.collectionId = p.collectionId;
        r.nativeReceipt = true;
    }

    function _resolution(AttrState.State storage s, bytes calldata data)
        private
        returns (Result memory r)
    {
        AD.Mutation memory m = StreamArtistDisputeState.resolveEncoded(s, data);
        (, AD.ResolutionRequest memory p,, Contest.GovernanceWitness memory g) = abi.decode(
            data[4:], (T.ActionContext, AD.ResolutionRequest, T.Binding, Contest.GovernanceWitness)
        );
        r = _disputeResult(m, keccak256("attribution_lifecycle.replay.dispute_resolution_key"));
        // The original resolution commits no signed record and appends no native receipt.
        r.record = bytes32(0);
        r.replayKind = ReplayKind.GovernancePair;
        r.governanceScope = g.actionId;
        r.governanceCommitment = p.disputeRecordHash;
        r.output = g.actionId;
    }

    function _disputeResult(AD.Mutation memory m, bytes32 surface)
        private
        pure
        returns (Result memory r)
    {
        r.action = m.action;
        r.state = m.state;
        r.record = m.record;
        r.replaySurface = surface;
        r.replayScope = m.replayScope;
        r.replayCommitment = m.replayCommitment;
        r.replayKind = ReplayKind.Single;
        r.output = m.record;
    }
}
