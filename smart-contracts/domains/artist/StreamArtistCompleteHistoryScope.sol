// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistMultipleHydrationTypes as MH
} from "../../interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";

/// @notice Complete native membership, with collection selectors describing only current heads.
/// @dev Per-generation ownership is proved by the binding family, never inferred from the head.
/// Every real principal has an original registration; zero is reserved for Platform receipts.
library StreamArtistCompleteHistoryScope {
    function selectors(MH.Request memory request) public pure {
        if (
            request.bindingIndex != 0 || request.artistIds.length > 128
                || request.collections.length == 0 || request.collections.length > 128
        ) _invalid();
        for (uint256 i; i < request.artistIds.length; ++i) {
            if (
                request.artistIds[i] == 0
                    || (i != 0 && request.artistIds[i] <= request.artistIds[i - 1])
            ) _invalid();
        }
        uint256 policies;
        for (uint256 i; i < request.collections.length; ++i) {
            MH.Collection memory c = request.collections[i];
            if (
                c.collectionId == 0
                    || (i != 0 && c.collectionId <= request.collections[i - 1].collectionId)
            ) _invalid();
            policies += c.policies.length;
            if (policies > 128 || (c.artistId == 0 && c.policies.length != 0)) _invalid();
            if (c.artistId != 0) _artist(request.artistIds, c.artistId);
            for (uint256 j; j < c.policies.length; ++j) {
                if (c.policies[j].phaseId == 0 || c.policies[j].policyHash == 0) _invalid();
                for (uint256 k; k < j; ++k) {
                    if (
                        c.policies[k].phaseId == c.policies[j].phaseId
                            && c.policies[k].policyHash == c.policies[j].policyHash
                    ) _invalid();
                }
            }
        }
    }

    function partition(MH.Request memory request, T.Binding[] memory heads, RH.Provenance memory p)
        public
        pure
        returns (M.State memory s)
    {
        selectors(request);
        if (heads.length != request.collections.length) _invalid();
        s.artists = new AH.Query[](request.artistIds.length);
        s.collections = new AH.Query[](heads.length);
        uint256[] memory ac = new uint256[](s.artists.length);
        uint256[] memory cc = new uint256[](s.collections.length);
        uint256[] memory registrations = new uint256[](s.artists.length);
        for (uint256 i; i < s.artists.length; ++i) {
            s.artists[i].artistId = request.artistIds[i];
        }
        for (uint256 i; i < heads.length; ++i) {
            T.Binding memory head = heads[i];
            MH.Collection memory selected = request.collections[i];
            if (head.artistId != selected.artistId) _invalid();
            if (head.artistId == 0) {
                T.Binding memory empty;
                if (keccak256(abi.encode(head)) != keccak256(abi.encode(empty))) _invalid();
            } else if (head.bindingHash == 0 || head.generation == 0) {
                _invalid();
            }
            s.collections[i].artistId = head.artistId;
            s.collections[i].collectionId = selected.collectionId;
            s.collections[i].bindingHash = head.bindingHash;
            s.collections[i].policies = selected.policies;
        }
        for (uint8 owner; owner < 7; ++owner) {
            for (uint256 j; j < p.journals[owner].length; ++j) {
                H.Receipt memory r = p.journals[owner][j].receipt;
                if (!platformOnly(owner, r)) {
                    uint256 a = artist(s, r.artistId);
                    ++ac[a];
                    if (owner == 2 && (r.operation == 1 || r.operation == 6)) {
                        if (r.collectionId != 0 || r.recordHash != r.artistId) _invalid();
                        ++registrations[a];
                    }
                }
                if (r.collectionId != 0) ++cc[collection(s, r.collectionId)];
            }
        }
        for (uint256 i; i < s.artists.length; ++i) {
            if (registrations[i] != 1) _invalid();
            s.artists[i].records = new bytes32[](ac[i]);
            ac[i] = 0;
        }
        for (uint256 i; i < s.collections.length; ++i) {
            if (cc[i] == 0) _invalid();
            s.collections[i].records = new bytes32[](cc[i]);
            cc[i] = 0;
        }
        for (uint8 owner; owner < 7; ++owner) {
            for (uint256 j; j < p.journals[owner].length; ++j) {
                H.Receipt memory r = p.journals[owner][j].receipt;
                if (!platformOnly(owner, r)) {
                    uint256 a = artist(s, r.artistId);
                    s.artists[a].records[ac[a]++] = r.recordHash;
                }
                if (r.collectionId != 0) {
                    uint256 c = collection(s, r.collectionId);
                    s.collections[c].records[cc[c]++] = r.recordHash;
                }
            }
        }
    }

    function platformOnly(uint8 owner, H.Receipt memory r) public pure returns (bool) {
        return owner == 4 && r.artistId == 0 && r.collectionId != 0
            && (r.operation == 8
                || r.operation == 9
                || r.operation == 10
                || r.operation == 11
                || r.operation == 53);
    }

    function artist(M.State memory s, bytes32 id) public pure returns (uint256) {
        if (id == 0) _invalid();
        for (uint256 i; i < s.artists.length; ++i) {
            if (s.artists[i].artistId == id) return i;
        }
        _invalid();
        return 0;
    }

    function collection(M.State memory s, uint256 id) public pure returns (uint256) {
        if (id == 0) _invalid();
        for (uint256 i; i < s.collections.length; ++i) {
            if (s.collections[i].collectionId == id) return i;
        }
        _invalid();
        return 0;
    }

    function _artist(bytes32[] memory ids, bytes32 id) private pure {
        for (uint256 i; i < ids.length; ++i) {
            if (ids[i] == id) return;
        }
        _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
