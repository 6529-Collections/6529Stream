// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationState as X
} from "./StreamArtistRecoveredIdentityHydrationState.sol";
import {
    StreamArtistEntropyUnavailabilityStore as Entropy
} from "./StreamArtistEntropyUnavailabilityStore.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";

/// @notice Original estate, notice and finding phase at the end of the fixed authority import.
/// @dev The fixed importer passes the complete canonical Bundle after SourceCodec validation.
/// Linked library calls retain the host's 17 declared roots and storage context.
library StreamArtistRecoveredIdentityImportEstate {
    function install(uint256[17] memory roots, bytes calldata canonical) public {
        IH.Bundle calldata b = Frame.bundle(canonical);
        _estate(roots, b);
    }

    function _estate(uint256[17] memory r, IH.Bundle calldata b) private {
        for (uint256 i; i < b.estates.length; ++i) {
            IH.EstateRow memory row = b.estates[i];
            IH.EstateRow memory zero;
            bytes32 key = row.request.recordHash;
            _empty(
                abi.encode(
                    X.estate(r).requests[key],
                    X.estate(r).phases[key],
                    X.estate(r).executions[key],
                    X.estate(r).transitions[key]
                ),
                abi.encode(zero.request, uint8(0), zero.execution, zero.transition),
                key
            );
            X.estate(r).requests[key] = row.request;
            X.estate(r).phases[key] = row.phase;
            X.estate(r).executions[key] = row.execution;
            X.estate(r).transitions[key] = row.transition;
        }
        for (uint256 i; i < b.notices.length; ++i) {
            IH.NoticeRow memory row = b.notices[i];
            IH.NoticeRow memory zero;
            bytes32 key = row.notice.recordHash;
            _empty(
                abi.encode(
                    X.dormancy(r).notices[key],
                    X.dormancy(r).phases[key],
                    X.dormancy(r).terminalForNotice[key]
                ),
                abi.encode(zero.notice, uint8(0), bytes32(0)),
                key
            );
            X.dormancy(r).notices[key] = row.notice;
            X.dormancy(r).phases[key] = row.phase;
            if (row.terminal.recordHash != 0) {
                bytes32 terminal = row.terminal.recordHash;
                _empty(
                    abi.encode(
                        X.dormancy(r).terminals[terminal], X.dormancy(r).transitions[terminal]
                    ),
                    abi.encode(zero.terminal, zero.transition),
                    terminal
                );
                X.dormancy(r).terminalForNotice[key] = terminal;
                X.dormancy(r).terminals[terminal] = row.terminal;
                X.dormancy(r).transitions[terminal] = row.transition;
            }
        }
        for (uint256 i; i < b.findings.length; ++i) {
            IH.FindingRow memory row = b.findings[i];
            IH.FindingRow memory zero;
            bytes32 key = row.record.recordHash;
            _empty(
                abi.encode(
                    X.findings(r).records[key],
                    X.findings(r).admissions[key],
                    Entropy.state().admissions[key],
                    Entropy.state().origins[key]
                ),
                abi.encode(zero.record, zero.admission, zero.entropyAdmission, address(0)),
                key
            );
            bytes32 scope = keccak256(abi.encode(b.artistId, row.record.terms.collectionId));
            bytes32 old = X.findings(r).latest[scope];
            if (old != 0 && old != row.latestForCollection) {
                revert IH.InvalidRecoveredIdentity(scope);
            }
            X.findings(r).records[key] = row.record;
            X.findings(r).admissions[key] = row.admission;
            X.findings(r).latest[scope] = row.latestForCollection;
            Entropy.state().admissions[key] = row.entropyAdmission;
            Entropy.state().origins[key] = row.entropyOrigin;
        }
    }

    function _empty(bytes memory old, bytes memory zero, bytes32 key) private pure {
        if (keccak256(old) != keccak256(zero)) revert IH.InvalidRecoveredIdentity(key);
    }
}
