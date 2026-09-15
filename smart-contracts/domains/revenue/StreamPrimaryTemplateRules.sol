// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamRevenueResolver as R
} from "../../interfaces/stream/revenue/IStreamRevenueResolver.sol";

/// @notice Immutable template grammar and canonicalization in a fixed compiler-linked boundary.
/// @dev No authority, payout resolution, storage mutation or caller-selected delegate exists here.
library StreamPrimaryTemplateRules {
    uint16 private constant MAX_TEMPLATE_ENTRIES = 64;
    uint16 private constant MAX_DYNAMIC_ACCOUNT_SOURCES = 8;
    uint32 private constant SHARE_DENOMINATOR_PPM = 1_000_000;
    bytes32 private constant ACCOUNT_SOURCE_SALE_POSTER = keccak256("SALE_POSTER");
    bytes32 private constant ACCOUNT_SOURCE_COLLECTION_ARTIST = keccak256("COLLECTION_ARTIST");
    bytes32 private constant ARTIST_LABEL = keccak256("artist");

    error InvalidPrimaryTemplateEntry(uint256 index);
    error InvalidPrimaryTemplateTotal(uint256 totalShare);
    error UnsupportedAccountSource(bytes32 accountSource);
    error UnsupportedArtistPrimaryTemplate(bytes32 templateId);

    /// @dev Existing initial facts use 500000; prospective positive-share facts use 1.
    function artistShare(
        R.PrimaryTemplateEntry[] memory entries,
        bytes32 templateId,
        uint32 minimum
    ) public pure returns (uint32 share) {
        for (uint256 i; i < entries.length; ++i) {
            R.PrimaryTemplateEntry memory entry = entries[i];
            if (
                entry.accountSource == ACCOUNT_SOURCE_COLLECTION_ARTIST
                    && entry.account == address(0) && entry.labelId == ARTIST_LABEL
            ) {
                share += entry.sharePpm;
            } else if (
                entry.account == address(0) || entry.accountSource != bytes32(0)
                    || entry.labelId == ARTIST_LABEL
            ) {
                revert UnsupportedArtistPrimaryTemplate(templateId);
            }
        }
        if (share < minimum) revert UnsupportedArtistPrimaryTemplate(templateId);
    }

    function canonicalize(R.PrimaryTemplateEntry[] calldata entries)
        public
        pure
        returns (R.PrimaryTemplateEntry[] memory canonicalEntries, bytes32 entriesHash)
    {
        uint256 length = entries.length;
        if (length == 0 || length > MAX_TEMPLATE_ENTRIES) {
            revert InvalidPrimaryTemplateEntry(length);
        }
        canonicalEntries = new R.PrimaryTemplateEntry[](length);
        for (uint256 i = 0; i < length; i++) {
            canonicalEntries[i] = entries[i];
        }
        _sortTemplateEntries(canonicalEntries);

        uint256 totalShare = 0;
        uint256 dynamicSourceCount = 0;
        bytes32[MAX_DYNAMIC_ACCOUNT_SOURCES] memory dynamicSources;
        for (uint256 i = 0; i < length; i++) {
            R.PrimaryTemplateEntry memory entry = canonicalEntries[i];
            bool hasAccount = entry.account != address(0);
            bool hasSource = entry.accountSource != bytes32(0);
            if (hasAccount == hasSource || entry.sharePpm == 0) {
                revert InvalidPrimaryTemplateEntry(i);
            }
            if (i != 0 && _sameTemplateIdentity(canonicalEntries[i - 1], entry)) {
                revert InvalidPrimaryTemplateEntry(i);
            }
            if (hasSource) {
                if (
                    entry.accountSource != ACCOUNT_SOURCE_SALE_POSTER
                        && entry.accountSource != ACCOUNT_SOURCE_COLLECTION_ARTIST
                ) {
                    revert UnsupportedAccountSource(entry.accountSource);
                }
                if (
                    entry.accountSource == ACCOUNT_SOURCE_COLLECTION_ARTIST
                        && entry.labelId != ARTIST_LABEL
                ) {
                    revert InvalidPrimaryTemplateEntry(i);
                }
                bool seen = false;
                for (uint256 j = 0; j < dynamicSourceCount; j++) {
                    if (dynamicSources[j] == entry.accountSource) {
                        seen = true;
                        break;
                    }
                }
                if (!seen) {
                    if (dynamicSourceCount == MAX_DYNAMIC_ACCOUNT_SOURCES) {
                        revert InvalidPrimaryTemplateEntry(i);
                    }
                    dynamicSources[dynamicSourceCount] = entry.accountSource;
                    dynamicSourceCount++;
                }
            }
            totalShare += entry.sharePpm;
        }
        if (totalShare != SHARE_DENOMINATOR_PPM) {
            revert InvalidPrimaryTemplateTotal(totalShare);
        }
        entriesHash = keccak256(abi.encode(canonicalEntries));
    }

    function _sortTemplateEntries(R.PrimaryTemplateEntry[] memory entries) private pure {
        for (uint256 i = 1; i < entries.length; i++) {
            R.PrimaryTemplateEntry memory current = entries[i];
            uint256 j = i;
            while (j > 0 && _templateEntryLess(current, entries[j - 1])) {
                entries[j] = entries[j - 1];
                j--;
            }
            entries[j] = current;
        }
    }

    function _templateEntryLess(
        R.PrimaryTemplateEntry memory left,
        R.PrimaryTemplateEntry memory right
    ) private pure returns (bool) {
        if (left.account != right.account) {
            return uint160(left.account) < uint160(right.account);
        }
        if (left.accountSource != right.accountSource) {
            return uint256(left.accountSource) < uint256(right.accountSource);
        }
        if (left.labelId != right.labelId) {
            return uint256(left.labelId) < uint256(right.labelId);
        }
        return left.sharePpm < right.sharePpm;
    }

    function _sameTemplateIdentity(
        R.PrimaryTemplateEntry memory left,
        R.PrimaryTemplateEntry memory right
    ) private pure returns (bool) {
        return left.account == right.account && left.accountSource == right.accountSource
            && left.labelId == right.labelId;
    }
}
