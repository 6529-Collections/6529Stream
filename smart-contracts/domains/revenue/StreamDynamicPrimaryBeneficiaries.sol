// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamDynamicPrimaryTemplateRules as Rules
} from "./StreamDynamicPrimaryTemplateRules.sol";
import {
    IStreamRevenueResolver as R
} from "../../interfaces/stream/revenue/IStreamRevenueResolver.sol";
import {
    IStreamDynamicPrimaryTemplates as D
} from "../../interfaces/stream/revenue/IStreamDynamicPrimaryTemplates.sol";
import { IStreamSplitWallet } from "../../interfaces/stream/revenue/IStreamSplitWallet.sol";
import {
    IStreamArtistBeneficiaryFacts
} from "../../interfaces/stream/artist/IStreamArtistBeneficiaryFacts.sol";
import {
    IStreamArtistAttribution
} from "../../interfaces/stream/artist/IStreamArtistAttribution.sol";
import {
    IStreamArtistAttributionState
} from "../../interfaces/stream/artist/IStreamArtistAttributionState.sol";
import {
    IStreamArtistCollaboratorLifecycle
} from "../../interfaces/stream/artist/IStreamArtistCollaboratorLifecycle.sol";
import {
    StreamArtistCollaboratorTypes as C
} from "../../interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";

/// @notice Fixed, bounded typed reads from the Resolver's pinned Artist facade.
/// @dev No caller-supplied beneficiary row, identity, generation or payout is authoritative.
library StreamDynamicPrimaryBeneficiaries {
    struct Context {
        address artist;
        uint256 collectionId;
        uint256 cap;
    }

    struct Witness {
        bytes32 artistId;
        address payout;
        bytes32 designation;
        uint64 generation;
        bytes32 bindingHash;
        address authority;
        C.Row[] rows;
        address[] payouts;
        bytes32[] designations;
    }
    error InvalidDynamicPrimaryBeneficiary();
    error DynamicPrimaryReadFailed(address target, bytes4 selector);
    error InsufficientDynamicPrimaryReadGas(uint256 required, uint256 available);

    function facts(R.PrimaryTemplateEntry[] memory entries, Context memory x)
        public
        view
        returns (uint32 artistShare, bytes32 witnessHash, Witness memory w)
    {
        if (x.collectionId == 0 || !Rules.isDynamic(entries)) {
            revert InvalidDynamicPrimaryBeneficiary();
        }
        bytes memory state = _read(
            x,
            abi.encodeCall(IStreamArtistAttributionState.collectionArtistState, (x.collectionId)),
            160
        );
        uint8 status;
        uint8 attribution;
        (attribution, w.generation, w.artistId, status, w.bindingHash) =
            abi.decode(state, (uint8, uint64, bytes32, uint8, bytes32));
        if (
            (attribution != 2 && attribution != 3) || w.generation == 0 || w.artistId == 0
                || w.bindingHash == 0
                || keccak256(state)
                    != keccak256(
                        abi.encode(attribution, w.generation, w.artistId, status, w.bindingHash)
                    )
        ) {
            revert InvalidDynamicPrimaryBeneficiary();
        }
        bytes memory raw = _read(
            x,
            abi.encodeCall(
                IStreamArtistBeneficiaryFacts.collectionArtistBeneficiary, (x.collectionId)
            ),
            96
        );
        bytes32 artistId;
        (artistId, w.payout, w.designation) = abi.decode(raw, (bytes32, address, bytes32));
        if (
            artistId != w.artistId || w.payout == address(0) || w.designation == 0
                || keccak256(raw) != keccak256(abi.encode(artistId, w.payout, w.designation))
        ) revert InvalidDynamicPrimaryBeneficiary();
        raw = _read(
            x, abi.encodeCall(IStreamArtistAttribution.acceptedArtist, (x.collectionId)), 32
        );
        w.authority = abi.decode(raw, (address));
        if (w.authority == address(0) || keccak256(raw) != keccak256(abi.encode(w.authority))) {
            revert InvalidDynamicPrimaryBeneficiary();
        }
        uint256 count = abi.decode(
            _read(
                x,
                abi.encodeCall(
                    IStreamArtistCollaboratorLifecycle.collaboratorCount,
                    (x.collectionId, w.generation)
                ),
                32
            ),
            (uint256)
        );
        if (count > 32) revert InvalidDynamicPrimaryBeneficiary();
        w.rows = new C.Row[](count);
        w.payouts = new address[](count);
        w.designations = new bytes32[](count);
        bytes32[] memory sources = new bytes32[](count);
        for (uint256 i; i < count; ++i) {
            raw = _read(
                x,
                abi.encodeCall(
                    IStreamArtistCollaboratorLifecycle.collaboratorAt,
                    (x.collectionId, w.generation, i)
                ),
                192
            );
            C.Row memory row = abi.decode(raw, (C.Row));
            if (
                !row.accepted || row.account == address(0) || row.collaboratorArtistId == 0
                    || row.acceptanceRecordHash == 0 || keccak256(raw) != keccak256(abi.encode(row))
            ) revert InvalidDynamicPrimaryBeneficiary();
            if (
                i != 0
                    && (uint160(row.account) < uint160(w.rows[i - 1].account)
                        || (row.account == w.rows[i - 1].account
                            && uint256(row.role) <= uint256(w.rows[i - 1].role)))
            ) revert InvalidDynamicPrimaryBeneficiary();
            w.rows[i] = row;
            if (row.shareLabelId != 0) {
                sources[i] =
                    Rules.source(D.CollaboratorReference(row.account, row.role, row.shareLabelId));
                raw = _read(
                    x,
                    abi.encodeCall(
                        IStreamArtistCollaboratorLifecycle.collaboratorPayoutAccount,
                        (row.collaboratorArtistId, row.account)
                    ),
                    64
                );
                (w.payouts[i], w.designations[i]) = abi.decode(raw, (address, bytes32));
                if (
                    w.payouts[i] == address(0) || w.designations[i] == 0
                        || keccak256(raw) != keccak256(abi.encode(w.payouts[i], w.designations[i]))
                ) revert InvalidDynamicPrimaryBeneficiary();
            }
        }
        bool[] memory paid = new bool[](count);
        uint256 primaryShare;
        for (uint256 i; i < entries.length; ++i) {
            R.PrimaryTemplateEntry memory e = entries[i];
            if (e.accountSource == Rules.ARTIST) {
                if (e.account != address(0) || e.labelId != Rules.ARTIST_LABEL || e.sharePpm == 0) {
                    revert InvalidDynamicPrimaryBeneficiary();
                }
                primaryShare += e.sharePpm;
                artistShare += e.sharePpm;
            } else if (e.accountSource == Rules.POSTER || e.accountSource == 0) {
                if (e.labelId == Rules.ARTIST_LABEL) revert InvalidDynamicPrimaryBeneficiary();
                for (uint256 j; j < count; ++j) {
                    if (w.rows[j].shareLabelId != 0 && e.labelId == w.rows[j].shareLabelId) {
                        revert InvalidDynamicPrimaryBeneficiary();
                    }
                }
            } else {
                bool matched;
                for (uint256 j; j < count; ++j) {
                    if (sources[j] != 0 && e.accountSource == sources[j]) {
                        if (
                            paid[j] || e.account != address(0)
                                || e.labelId != w.rows[j].shareLabelId || e.sharePpm == 0
                        ) revert InvalidDynamicPrimaryBeneficiary();
                        matched = true;
                        paid[j] = true;
                        if (e.labelId == Rules.ARTIST_LABEL) artistShare += e.sharePpm;
                    }
                }
                if (!matched) revert InvalidDynamicPrimaryBeneficiary();
            }
        }
        if (primaryShare == 0 || artistShare > 1_000_000) {
            revert InvalidDynamicPrimaryBeneficiary();
        }
        for (uint256 i; i < count; ++i) {
            if (sources[i] != 0 && !paid[i]) revert InvalidDynamicPrimaryBeneficiary();
        }
        if (
            keccak256(
                    _read(
                        x,
                        abi.encodeCall(
                            IStreamArtistAttributionState.collectionArtistState, (x.collectionId)
                        ),
                        160
                    )
                ) != keccak256(state)
        ) revert InvalidDynamicPrimaryBeneficiary();
        witnessHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_DYNAMIC_PRIMARY_BENEFICIARIES_V1"),
                block.chainid,
                address(this),
                x.collectionId,
                w
            )
        );
    }

    function concrete(R.PrimaryTemplateEntry[] memory entries, Context memory x, address poster)
        public
        view
        returns (
            IStreamSplitWallet.SplitEntry[] memory result,
            bytes32 witnessHash,
            Witness memory w
        )
    {
        (, witnessHash, w) = facts(entries, x);
        result = new IStreamSplitWallet.SplitEntry[](entries.length);
        for (uint256 i; i < entries.length; ++i) {
            R.PrimaryTemplateEntry memory e = entries[i];
            address account = e.account;
            if (e.accountSource == Rules.ARTIST) {
                account = w.payout;
            } else if (e.accountSource == Rules.POSTER) {
                if (poster == address(0) || poster == w.authority) {
                    revert InvalidDynamicPrimaryBeneficiary();
                }
                account = poster;
            } else if (e.accountSource != 0) {
                for (uint256 j; j < w.rows.length; ++j) {
                    C.Row memory row = w.rows[j];
                    if (
                        row.shareLabelId != 0
                            && e.accountSource
                                == Rules.source(
                                    D.CollaboratorReference(row.account, row.role, row.shareLabelId)
                                )
                    ) account = w.payouts[j];
                }
            }
            if (account == address(0)) revert InvalidDynamicPrimaryBeneficiary();
            result[i] = IStreamSplitWallet.SplitEntry(account, e.sharePpm, e.labelId);
        }
    }

    function _read(Context memory x, bytes memory input, uint256 width)
        private
        view
        returns (bytes memory raw)
    {
        uint256 cap = x.cap;
        uint256 available = gasleft();
        if (cap == 0 || cap > type(uint64).max || available < cap + (cap + 62) / 63 + 12_000) {
            revert InsufficientDynamicPrimaryReadGas(cap, available);
        }
        raw = new bytes(width);
        address target = x.artist;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(raw, 32), width)
            size := returndatasize()
        }
        if (!ok || size != width) revert DynamicPrimaryReadFailed(target, bytes4(input));
    }
}
