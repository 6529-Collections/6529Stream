// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistOwner.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Sole owner of operative payout designations; signing addresses are never payout fallbacks.
contract StreamArtistPayoutLifecycle is StreamArtistOwner {
    mapping(bytes32 => T.Payout) private _payouts;
    mapping(bytes32 => T.PayoutDesignation) private _records;
    event ArtistPayoutDesignationRecorded(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed payoutAccount,
        address indexed signer,
        bytes32 previousDesignationRecordHash,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 designationRecordHash
    );
    constructor(
        address registry_,
        address coordinator_,
        address archive_,
        address core_,
        address manager_
    )
        StreamArtistOwner(
            registry_, coordinator_, archive_, keccak256("domain:payout_lifecycle"), core_, manager_
        )
    { }

    function artistPayoutAccount(bytes32 artistId) external view returns (address, bytes32) {
        T.Payout storage p = _payouts[artistId];
        return (p.account, p.recordHash);
    }

    function designationRecord(bytes32 record) external view returns (T.PayoutDesignation memory) {
        return _records[record];
    }

    function recordDesignation(
        T.ActionContext calldata c,
        T.PayoutDesignation calldata p,
        address signer,
        uint256 nonce,
        uint64 signedAt
    ) external returns (bytes32 record) {
        _check(c, 18);
        T.Payout storage current = _payouts[p.artistId];
        if (
            p.artistId == bytes32(0) || p.payoutAccount == address(0) || signer == address(0)
                || current.recordHash != p.previousDesignationRecordHash
                || current.account == p.payoutAccount
        ) {
            revert T.InvalidRecord();
        }
        record = StreamArtistHashes.payoutRecord(_environment(), p, signer, nonce, signedAt);
        bytes32 key = _replayKey(
            keccak256("payout_lifecycle.replay.designation_chain"),
            keccak256(abi.encode(p.artistId))
        );
        bytes32 prior = current.recordHash;
        _payouts[p.artistId] = T.Payout(p.payoutAccount, record);
        _records[record] = p;
        _replay[key] = T.ReplayCell(record, _revision + 1, 3, 1);
        _commit(
            c,
            keccak256(abi.encode(p, signer, nonce, signedAt)),
            keccak256(abi.encode(p.artistId, p.payoutAccount, record)),
            keccak256(abi.encode(key, prior, record)),
            record
        );
        emit ArtistPayoutDesignationRecorded(
            1, p.artistId, p.payoutAccount, signer, prior, 1, nonce, signedAt, record
        );
    }
}
