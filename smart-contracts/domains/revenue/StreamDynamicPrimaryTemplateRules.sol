// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamRevenueResolver as R
} from "../../interfaces/stream/revenue/IStreamRevenueResolver.sol";
import {
    IStreamDynamicPrimaryTemplates as D
} from "../../interfaces/stream/revenue/IStreamDynamicPrimaryTemplates.sol";

/// @notice Original template identity/canonicalization with explicitly declared collaborator sources.
library StreamDynamicPrimaryTemplateRules {
    bytes32 internal constant ARTIST = keccak256("COLLECTION_ARTIST");
    bytes32 internal constant POSTER = keccak256("SALE_POSTER");
    bytes32 internal constant ARTIST_LABEL = keccak256("artist");
    error InvalidDynamicPrimaryTemplate();

    function source(D.CollaboratorReference memory ref) internal pure returns (bytes32) {
        if (ref.account == address(0) || ref.shareLabelId == 0) {
            revert InvalidDynamicPrimaryTemplate();
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_COLLABORATOR_SOURCE_V1"),
                ref.account,
                ref.role,
                ref.shareLabelId
            )
        );
    }

    function isDynamic(R.PrimaryTemplateEntry[] memory entries) internal pure returns (bool) {
        bool dynamic_;
        bool primary;
        for (uint256 i; i < entries.length; ++i) {
            if (entries[i].accountSource != 0 && entries[i].accountSource != ARTIST) {
                dynamic_ = true;
            }
            if (
                entries[i].accountSource == ARTIST && entries[i].account == address(0)
                    && entries[i].labelId == ARTIST_LABEL && entries[i].sharePpm != 0
            ) primary = true;
        }
        return dynamic_ && primary;
    }

    function canonicalize(
        R.PrimaryTemplateEntry[] memory entries,
        D.CollaboratorReference[] memory refs
    ) public pure returns (R.PrimaryTemplateEntry[] memory, bytes32) {
        if (entries.length == 0 || entries.length > 64 || refs.length > 32) {
            revert InvalidDynamicPrimaryTemplate();
        }
        bytes32[] memory ids = new bytes32[](refs.length);
        bool[] memory used = new bool[](refs.length);
        for (uint256 i; i < refs.length; ++i) {
            ids[i] = source(refs[i]);
            for (uint256 j; j < i; ++j) {
                if (ids[i] == ids[j]) revert InvalidDynamicPrimaryTemplate();
            }
        }
        for (uint256 i = 1; i < entries.length; ++i) {
            R.PrimaryTemplateEntry memory e = entries[i];
            uint256 j = i;
            while (j != 0 && _less(e, entries[j - 1])) {
                entries[j] = entries[j - 1];
                --j;
            }
            entries[j] = e;
        }
        uint256 total;
        uint256 artistShare;
        uint256 dynamicCount;
        bytes32[8] memory dynamicIds;
        for (uint256 i; i < entries.length; ++i) {
            R.PrimaryTemplateEntry memory e = entries[i];
            if ((e.account == address(0)) == (e.accountSource == 0) || e.sharePpm == 0) {
                revert InvalidDynamicPrimaryTemplate();
            }
            if (
                i != 0 && e.account == entries[i - 1].account
                    && e.accountSource == entries[i - 1].accountSource
                    && e.labelId == entries[i - 1].labelId
            ) {
                revert InvalidDynamicPrimaryTemplate();
            }
            if (e.accountSource == ARTIST) {
                if (e.labelId != ARTIST_LABEL) revert InvalidDynamicPrimaryTemplate();
                artistShare += e.sharePpm;
            } else if (e.accountSource == POSTER || e.accountSource == 0) {
                if (e.labelId == ARTIST_LABEL) revert InvalidDynamicPrimaryTemplate();
                for (uint256 j; j < refs.length; ++j) {
                    if (e.labelId == refs[j].shareLabelId) revert InvalidDynamicPrimaryTemplate();
                }
            } else {
                bool found;
                for (uint256 j; j < ids.length; ++j) {
                    if (e.accountSource == ids[j]) {
                        if (used[j] || e.labelId != refs[j].shareLabelId) {
                            revert InvalidDynamicPrimaryTemplate();
                        }
                        used[j] = true;
                        found = true;
                    }
                }
                if (!found) revert InvalidDynamicPrimaryTemplate();
            }
            if (e.accountSource != 0) {
                bool seen;
                for (uint256 j; j < dynamicCount; ++j) {
                    if (dynamicIds[j] == e.accountSource) seen = true;
                }
                if (!seen) {
                    if (dynamicCount == 8) revert InvalidDynamicPrimaryTemplate();
                    dynamicIds[dynamicCount++] = e.accountSource;
                }
            }
            total += e.sharePpm;
        }
        if (total != 1_000_000 || artistShare == 0 || !isDynamic(entries)) {
            revert InvalidDynamicPrimaryTemplate();
        }
        for (uint256 j; j < used.length; ++j) {
            if (!used[j]) revert InvalidDynamicPrimaryTemplate();
        }
        return (entries, keccak256(abi.encode(entries)));
    }

    function _less(R.PrimaryTemplateEntry memory a, R.PrimaryTemplateEntry memory b)
        private
        pure
        returns (bool)
    {
        if (a.account != b.account) return uint160(a.account) < uint160(b.account);
        if (a.accountSource != b.accountSource) {
            return uint256(a.accountSource) < uint256(b.accountSource);
        }
        if (a.labelId != b.labelId) return uint256(a.labelId) < uint256(b.labelId);
        return a.sharePpm < b.sharePpm;
    }
}
