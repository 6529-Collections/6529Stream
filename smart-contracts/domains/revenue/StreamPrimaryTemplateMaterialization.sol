// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamRevenueResolver } from "../../interfaces/stream/revenue/IStreamRevenueResolver.sol";
import { IStreamSplitWallet } from "../../interfaces/stream/revenue/IStreamSplitWallet.sol";
import {
    IStreamArtistBeneficiaryFacts
} from "../../interfaces/stream/artist/IStreamArtistBeneficiaryFacts.sol";

/// @notice Existing concrete-profile body at a fixed compiler-linked boundary.
/// @dev Host supplies only its pinned registry/live cap and original sale context.
library StreamPrimaryTemplateMaterialization {
    bytes32 private constant ACCOUNT_SOURCE_COLLECTION_ARTIST = keccak256("COLLECTION_ARTIST");
    bytes32 private constant ACCOUNT_SOURCE_SALE_POSTER = keccak256("SALE_POSTER");
    bytes32 private constant _MATERIALIZED_PROFILE_METADATA_DOMAIN =
        keccak256("6529STREAM_MATERIALIZED_PRIMARY_PROFILE_METADATA_V1");

    struct Context {
        address artistRegistry;
        uint256 cap;
        uint256 collectionId;
        address salePoster;
        bytes32 artistId;
        address payout;
        bytes32 designation;
    }
    error MissingArtistMaterializationContext();
    error UnsupportedAccountSource(bytes32 source);
    error InvalidMaterializedAccount(bytes32 source);
    error InsufficientArtistBeneficiaryGas(uint256 cap, uint256 available);
    error UnresolvableArtistBeneficiary(uint256 collectionId);

    function legacy(
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries,
        bytes32 templateId,
        Context memory context
    )
        public
        view
        returns (
            IStreamSplitWallet.SplitEntry[] memory concreteEntries,
            bytes32 entriesHash,
            bytes32 metadataURIHash,
            Context memory
        )
    {
        // Resolve once; all entries in this materialization share the same current witness.
        for (uint256 i; i < entries.length; ++i) {
            if (entries[i].accountSource == ACCOUNT_SOURCE_COLLECTION_ARTIST) {
                if (context.collectionId == 0) revert MissingArtistMaterializationContext();
                (context.artistId, context.payout, context.designation) =
                    _artistBeneficiary(context.collectionId, context.artistRegistry, context.cap);
                break;
            }
        }
        concreteEntries = new IStreamSplitWallet.SplitEntry[](entries.length);
        for (uint256 i; i < entries.length; ++i) {
            IStreamRevenueResolver.PrimaryTemplateEntry memory entry = entries[i];
            address account = entry.account;
            if (account == address(0)) {
                if (entry.accountSource == ACCOUNT_SOURCE_COLLECTION_ARTIST) {
                    account = context.payout;
                } else if (entry.accountSource == ACCOUNT_SOURCE_SALE_POSTER) {
                    account = context.salePoster;
                } else {
                    revert UnsupportedAccountSource(entry.accountSource);
                }
                if (account == address(0)) revert InvalidMaterializedAccount(entry.accountSource);
            }
            concreteEntries[i] =
                IStreamSplitWallet.SplitEntry(account, entry.sharePpm, entry.labelId);
        }
        concreteEntries = _canonicalizeConcreteEntries(concreteEntries);
        entriesHash = keccak256(abi.encode(concreteEntries));
        metadataURIHash = keccak256(
            abi.encode(
                _MATERIALIZED_PROFILE_METADATA_DOMAIN,
                uint256(block.chainid),
                address(this),
                templateId,
                entriesHash
            )
        );
        return (concreteEntries, entriesHash, metadataURIHash, context);
    }

    function canonical(IStreamSplitWallet.SplitEntry[] memory entries)
        public
        pure
        returns (IStreamSplitWallet.SplitEntry[] memory)
    {
        return _canonicalizeConcreteEntries(entries);
    }

    function _artistBeneficiary(uint256 collectionId, address artistRegistry, uint256 cap)
        private
        view
        returns (bytes32 artistId, address payout, bytes32 designation)
    {
        bytes memory input = abi.encodeCall(
            IStreamArtistBeneficiaryFacts.collectionArtistBeneficiary, (collectionId)
        );
        // Covers EIP-150 plus cold-account/call setup; never silently underforward the live cap.
        uint256 available = gasleft();
        if (cap > type(uint64).max || available < cap + (cap + 62) / 63 + 12_000) {
            revert InsufficientArtistBeneficiaryGas(cap, available);
        }
        bool ok;
        uint256 size;
        uint256 payoutWord;
        address target = artistRegistry;
        assembly ("memory-safe") {
            let output := mload(0x40)
            ok := staticcall(cap, target, add(input, 32), mload(input), output, 96)
            size := returndatasize()
            artistId := mload(output)
            payoutWord := mload(add(output, 32))
            designation := mload(add(output, 64))
        }
        if (
            !ok || size != 96 || artistId == bytes32(0) || designation == bytes32(0)
                || payoutWord == 0 || payoutWord > type(uint160).max
        ) {
            revert UnresolvableArtistBeneficiary(collectionId);
        }
        // The exact ABI-word check above rejects every nonzero upper address bit.
        // forge-lint: disable-next-line(unsafe-typecast)
        payout = address(uint160(payoutWord));
    }

    function _canonicalizeConcreteEntries(IStreamSplitWallet.SplitEntry[] memory entries)
        private
        pure
        returns (IStreamSplitWallet.SplitEntry[] memory canonicalEntries)
    {
        _sortSplitEntries(entries);
        uint256 uniqueCount = 0;
        for (uint256 i = 0; i < entries.length; i++) {
            if (
                i == 0 || entries[i].account != entries[i - 1].account
                    || entries[i].labelId != entries[i - 1].labelId
            ) {
                uniqueCount++;
            }
        }
        canonicalEntries = new IStreamSplitWallet.SplitEntry[](uniqueCount);
        uint256 cursor = 0;
        for (uint256 i = 0; i < entries.length; i++) {
            if (
                i == 0 || entries[i].account != entries[i - 1].account
                    || entries[i].labelId != entries[i - 1].labelId
            ) {
                if (i != 0) {
                    cursor++;
                }
                canonicalEntries[cursor] = entries[i];
            } else {
                canonicalEntries[cursor].sharePpm += entries[i].sharePpm;
            }
        }
    }

    function _sortSplitEntries(IStreamSplitWallet.SplitEntry[] memory entries) private pure {
        for (uint256 i = 1; i < entries.length; i++) {
            IStreamSplitWallet.SplitEntry memory current = entries[i];
            uint256 j = i;
            while (j > 0 && _splitEntryLess(current, entries[j - 1])) {
                entries[j] = entries[j - 1];
                j--;
            }
            entries[j] = current;
        }
    }

    function _splitEntryLess(
        IStreamSplitWallet.SplitEntry memory left,
        IStreamSplitWallet.SplitEntry memory right
    ) private pure returns (bool) {
        if (left.account != right.account) {
            return uint160(left.account) < uint160(right.account);
        }
        if (left.labelId != right.labelId) {
            return uint256(left.labelId) < uint256(right.labelId);
        }
        return left.sharePpm < right.sharePpm;
    }
}
