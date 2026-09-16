// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistAttributionStateTypes.sol";

/// @notice Original8/9/10/11/53 argument decoders and fixed state writers, with no authority change.
library StreamArtistAttributionPlatformTransport {
    struct Result {
        bytes32 record;
        bytes32 scope;
        bytes32 action;
        bytes32 primary;
        uint256 id;
    }

    function applyEncoded(
        StreamArtistAttributionStateTypes.State storage s,
        StreamArtistHashes.Environment memory e,
        bytes calldata data
    ) public returns (Result memory m) {
        T.ActionContext memory c = abi.decode(data[4:], (T.ActionContext));
        if (c.operationId == 8) {
            uint256 id;
            bytes32 statement;
            (, id, statement) = abi.decode(data[4:], (T.ActionContext, uint256, bytes32));
            if (s.attributions[id].generation != 0 || s.attributions[id].state != 0) {
                revert PW.InvalidPlatformWorks(id);
            }
            m.id = id;
            m.record = StreamArtistPlatformState.declare(
                s.platform, e.registry, e.core, c.actor, id, statement
            );
            m.scope = bytes32(id);
            m.primary = m.record;
        } else if (c.operationId == 9 || c.operationId == 10) {
            uint256 id;
            bytes32 evidence;
            bytes32 reason;
            string memory uri;
            address proposed;
            (, id, evidence, reason, uri, proposed) =
                abi.decode(data[4:], (T.ActionContext, uint256, bytes32, bytes32, string, address));
            m.id = id;
            m.record = c.operationId == 9
                ? StreamArtistPlatformState.claim(
                    s.platform, e.registry, e.core, c.actor, id, evidence, reason, uri, proposed
                )
                : StreamArtistAttributionClaimState.file(
                    s.attributionClaims,
                    e.registry,
                    e.core,
                    c.actor,
                    id,
                    evidence,
                    reason,
                    uri,
                    proposed
                );
            s.latestDisplayClaim[id] = m.record;
            m.scope = keccak256(abi.encode(id, c.actor, evidence, reason));
            m.primary = m.record;
            if (c.operationId == 10) {
                m.action = keccak256(abi.encode(id, c.actor, evidence, reason, uri, proposed));
            }
        } else if (c.operationId == 11) {
            uint256 id;
            uint8 state;
            bytes32 claim;
            bytes32 evidence;
            bytes32 reason;
            bytes32 action;
            address adjudicated;
            (, id, state, claim, evidence, reason, action, adjudicated) = abi.decode(
                data[4:],
                (T.ActionContext, uint256, uint8, bytes32, bytes32, bytes32, bytes32, address)
            );
            m.id = id;
            m.record = StreamArtistPlatformState.contest(
                s.platform, id, state, claim, evidence, reason, action, adjudicated
            );
            m.scope = keccak256(abi.encode(id, action));
        } else if (c.operationId == 53) {
            uint256 id;
            bytes32 claim;
            bytes32 evidence;
            bytes32 reason;
            bytes32 action;
            (, id, claim, evidence, reason, action) =
                abi.decode(data[4:], (T.ActionContext, uint256, bytes32, bytes32, bytes32, bytes32));
            m.id = id;
            m.record = StreamArtistPlatformState.correct(
                s.platform, e.registry, e.core, id, claim, evidence, reason, action
            );
            m.scope = keccak256(abi.encode(id, action));
            m.primary = m.record;
        } else {
            revert T.InvalidRecord();
        }
        if (c.operationId != 10) m.action = m.record;
    }
}
