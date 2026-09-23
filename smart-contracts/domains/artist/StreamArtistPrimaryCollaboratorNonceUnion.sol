// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistDelegationState as Delegations } from "./StreamArtistDelegationState.sol";
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
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";

/// @notice Principal and account lanes form one exact disjoint original nonce inventory.
/// @dev AccountNonces separately proves every kind3 word/hint from the complete original op6 history.
/// @dev No global checkpoint denominator is replaced with a per-Artist count.
library StreamArtistPrimaryCollaboratorNonceUnion {
    function validateLocal(IH.Bundle calldata b) public pure {
        if (b.nonces.length > RH.MAX_NONCE_INDICES) _invalid();
        for (uint256 i; i < b.nonces.length; ++i) {
            IH.NonceLane calldata n = b.nonces[i];
            if (
                n.key == 0 || !_belongs(b, n.kind, n.key) || n.words.length == 0
                    || n.words.length > RH.MAX_NONCE_PREFIXES
            ) _invalid();
            for (uint256 j; j < i; ++j) {
                if (b.nonces[j].kind == n.kind && b.nonces[j].key == n.key) _invalid();
            }
            for (uint256 j; j < n.words.length; ++j) {
                if (n.words[j].exhausted != n.words[0].exhausted) _invalid();
                for (uint256 k; k < j; ++k) {
                    if (n.words[j].prefix == n.words[k].prefix) _invalid();
                }
            }
        }
    }

    function facts(bytes calldata canonical)
        public
        pure
        returns (
            bytes32 artist,
            address authority,
            uint256 next,
            bytes32 timing,
            IH.NonceLane[] memory lanes
        )
    {
        IH.Bundle calldata b = Frame.bundle(canonical);
        validateLocal(b);
        return (
            b.artistId,
            b.identity.authorityAddress,
            b.nextRegistrationNonce,
            keccak256(abi.encode(b.timing)),
            b.nonces
        );
    }

    function ordered(
        M.State calldata s,
        RH.NonceInventory[] calldata inventory,
        IH.NonceLane[] calldata accounts
    ) public pure returns (IH.NonceLane[] memory all) {
        all = new IH.NonceLane[](inventory.length);
        bool[] memory seen = new bool[](inventory.length);
        uint256 total;
        bytes32 timing;
        address[] memory addresses = new address[](s.artists.length);
        for (uint256 i; i < s.rows.length; ++i) {
            (
                bytes32 artist,
                address authority,
                uint256 next,
                bytes32 current,
                IH.NonceLane[] memory lanes
            ) = facts(s.rows[i]);
            if (
                artist != s.artists[i].artistId || authority == address(0)
                    || next != s.artists.length || (i != 0 && current != timing)
            ) _invalid();
            timing = current;
            addresses[i] = authority;
            for (uint256 j; j < i; ++j) {
                if (addresses[j] == authority) _invalid();
            }
            uint256 previous;
            for (uint256 j; j < lanes.length; ++j) {
                bool found;
                for (uint256 k; k < inventory.length; ++k) {
                    if (
                        lanes[j].kind != inventory[k].index.kind
                            || lanes[j].key != inventory[k].index.key
                    ) continue;
                    if (
                        seen[k] || (j != 0 && k <= previous)
                            || keccak256(abi.encode(lanes[j].words))
                                != keccak256(abi.encode(inventory[k].words))
                    ) _invalid();
                    seen[k] = true;
                    previous = k;
                    all[k] = lanes[j];
                    found = true;
                    ++total;
                }
                if (!found) _invalid();
            }
        }
        uint256 priorAccount;
        for (uint256 i; i < accounts.length; ++i) {
            IH.NonceLane calldata lane = accounts[i];
            if (lane.kind != 3 || lane.key == 0 || uint256(lane.key) > type(uint160).max) {
                _invalid();
            }
            bool found;
            for (uint256 k; k < inventory.length; ++k) {
                if (inventory[k].index.kind != 3 || inventory[k].index.key != lane.key) continue;
                if (
                    seen[k] || (i != 0 && k <= priorAccount)
                        || keccak256(abi.encode(lane.words))
                            != keccak256(abi.encode(inventory[k].words))
                ) _invalid();
                seen[k] = true;
                priorAccount = k;
                all[k] = lane;
                found = true;
                ++total;
            }
            if (!found) _invalid();
        }
        if (total != inventory.length) _invalid();
    }

    function _belongs(IH.Bundle calldata b, uint8 kind, bytes32 key) private pure returns (bool) {
        if (kind == 1) return key == b.artistId;
        if (kind == 2) {
            for (uint256 i; i < b.delegations.length; ++i) {
                if (key == Delegations.lane(b.artistId, b.delegations[i].record.grant.delegate)) {
                    return true;
                }
            }
        }
        if (kind == 4) {
            for (uint256 i; i < b.rotations.length; ++i) {
                if (
                    key
                        == keccak256(
                            abi.encode(
                                keccak256("rotation_acceptance"),
                                b.artistId,
                                b.rotations[i].record.terms.newAddress
                            )
                        )
                ) return true;
            }
            for (uint256 i; i < b.recoveries.length; ++i) {
                if (
                    key
                        == keccak256(
                            abi.encode(
                                keccak256("rotation_acceptance"),
                                b.artistId,
                                b.recoveries[i].record.terms.newAddress
                            )
                        )
                ) return true;
            }
        }
        if (kind == 5) {
            for (uint256 i; i < b.estates.length; ++i) {
                if (
                    key
                        == keccak256(
                            abi.encode(
                                "estate_activation",
                                b.artistId,
                                b.estates[i].request.terms.successor
                            )
                        )
                ) return true;
            }
        }
        return false;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProvenance();
    }
}
