// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistRepudiationState.sol";
import "./StreamArtistDisputeState.sol";

/// @notice Original47–50 owner arguments decoded once after the unchanged host operation check.
library StreamArtistRepudiationAttributionTransport {
    function applyEncoded(
        AttrState.State storage s,
        StreamArtistHashes.Environment memory e,
        bytes calldata data
    ) public returns (RP.Mutation memory m) {
        T.ActionContext memory c = abi.decode(data[4:], (T.ActionContext));
        if (c.operationId == 47) {
            AD.Filing memory p;
            RP.Admission memory admission;
            uint256 nonce;
            (, p, admission, nonce) =
                abi.decode(data[4:], (T.ActionContext, AD.Filing, RP.Admission, uint256));
            return StreamArtistRepudiationState.stage(s, e, c, p, admission, nonce);
        }
        RP.Record memory record;
        if (c.operationId == 48) {
            RP.GuardianProof memory proof;
            (, record, proof) = abi.decode(data[4:], (T.ActionContext, RP.Record, RP.GuardianProof));
            return StreamArtistRepudiationState.veto(c, record, proof);
        }
        (, record) = abi.decode(data[4:], (T.ActionContext, RP.Record));
        if (c.operationId == 49) return StreamArtistRepudiationState.cancel(c, record);
        if (c.operationId != 50) revert T.InvalidOperation(c.operationId);
        m = StreamArtistRepudiationState.execute(s, c, record);
        StreamArtistDisputeState.markRepudiated(
            record.terms.collectionId, record.terms.bindingGeneration
        );
    }
}
