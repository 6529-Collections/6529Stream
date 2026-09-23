// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationState as X
} from "./StreamArtistRecoveredIdentityHydrationState.sol";
import { StreamArtistNonceAvailability as Nonces } from "./StreamArtistNonceAvailability.sol";
import {
    StreamArtistAuthorityCheckpoint as Checkpoint
} from "./StreamArtistAuthorityCheckpoint.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";

/// @notice Fixed nonces phase of the original recovered Identity import.
/// @dev The fixed importer passes the complete canonical Bundle after SourceCodec validation.
/// Linked library calls retain the host's 17 declared roots and storage context.
library StreamArtistRecoveredMultipleIdentityNonceImport {
    function install(uint256[17] memory roots, IH.NonceLane[] calldata rows) public {
        _nonces(roots, rows);
    }

    function _nonces(uint256[17] memory r, IH.NonceLane[] calldata rows) private {
        for (uint256 i; i < rows.length; ++i) {
            IH.NonceLane memory row = rows[i];
            if (row.kind == 1) {
                _nonce(X.identity(r).nonceAvailability[row.key], row);
            } else if (row.kind == 2) {
                _nonce(X.delegations(r).availability[row.key], row);
                X.delegations(r).hints[row.key] = row.hint;
            } else if (row.kind == 4) {
                _nonce(X.rotations(r).acceptanceNonces[row.key], row);
                X.rotations(r).acceptanceHint[row.key] = row.hint;
            } else if (row.kind == 5) {
                _nonce(X.estate(r).nonceAvailability[row.key], row);
                X.estate(r).nonceHints[row.key] = row.hint;
            } else {
                revert IH.InvalidRecoveredIdentity(row.key);
            }
        }
    }

    function _nonce(Nonces.Index storage s, IH.NonceLane memory row) private {
        if (row.words.length == 0 || row.words.length > RH.MAX_NONCE_PREFIXES || s.exhausted) {
            revert IH.InvalidRecoveredIdentity(row.key);
        }
        for (uint256 i; i < row.words.length; ++i) {
            uint256 prefix = row.words[i].prefix;
            for (uint8 level; level < 32; ++level) {
                uint256 old = s.full[level][prefix];
                if (old != 0 && old != row.words[i].words[level]) {
                    revert IH.InvalidRecoveredIdentity(row.key);
                }
                s.full[level][prefix] = row.words[i].words[level];
                prefix >>= 8;
            }
            if (i != 0 && row.words[i].exhausted != row.words[0].exhausted) {
                revert IH.InvalidRecoveredIdentity(row.key);
            }
            Checkpoint.noteNonce(
                row.kind, row.key, row.words[i].prefix, keccak256(abi.encode(row.words[i]))
            );
        }
        s.exhausted = row.words[0].exhausted;
        (bool available, uint256 hint) = Nonces.firstUnused(s);
        if (available && hint != row.hint) revert IH.InvalidRecoveredIdentity(row.key);
    }
}
