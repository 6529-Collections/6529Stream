// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistIdentityRecoveryHashes as H } from "./StreamArtistIdentityRecoveryHashes.sol";
import {
    StreamArtistIdentityRecoveryTypes as R
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryTypes.sol";

/// @notice The operation35 two-record receipt mechanism. Admission and replay remain owner duties.
/// @dev The sole reusable-content exception is the second receipt of this same typed recovery.
library StreamArtistIdentityRecoveryReceipts {
    bytes32 internal constant PRIMARY =
        0x459749364fd07c3a8f1998b82d893d33ef0942c30d94666b42dac1e37ba5feff;
    bytes32 internal constant SECONDARY =
        0x0c8573762967a1af597f2a7afc4b655a87b3e22d2b11fbab6cf13c6f7b1396ae;
    bytes32 internal constant IDENTITY =
        0x6579e41542b1bfc6684ea87b09373c4f4690857bd046eb4faf0f92a42bc88adb;

    struct State {
        mapping(bytes32 => mapping(bytes32 => bytes32)) receipts;
        mapping(bytes32 => bytes32) secondaryOccurrences;
    }

    struct Environment {
        uint256 chainId;
        address registry;
        address coordinator;
        address archive;
        address owner;
        bytes32 domain;
        uint64 revision;
        uint64 sequence;
        bytes32 tip;
        address actor;
    }

    struct Pair {
        bytes32 primaryHash;
        bytes32 secondaryHash;
        bytes32 primaryCommitment;
        bytes32 secondaryCommitment;
        bytes32 occurrenceKey;
        bytes32 recordDelta;
        uint64 nextSequence;
        bytes32 nextTip;
    }

    // Static tuples retain the packet's exact thirteen, eleven and twenty ABI words.
    struct ReceiptPreimage {
        bytes32 tag;
        uint16 version;
        uint256 chainId;
        address registry;
        address coordinator;
        address archive;
        address owner;
        bytes32 domain;
        uint64 revision;
        uint64 sequence;
        address actor;
        bytes32 recordDomain;
        bytes32 semanticHash;
    }

    struct ChainPreimage {
        bytes32 tag;
        uint256 chainId;
        address registry;
        address coordinator;
        address archive;
        address owner;
        bytes32 domain;
        uint64 previousSequence;
        uint64 nextSequence;
        bytes32 previousTip;
        bytes32 commitment;
    }

    struct DeltaPreimage {
        bytes32 tag;
        uint16 version;
        uint256 chainId;
        address registry;
        address coordinator;
        address archive;
        address owner;
        bytes32 domain;
        uint64 revision;
        uint64 previousSequence;
        uint64 nextSequence;
        bytes32 previousTip;
        uint8 count;
        bytes32 primaryDomain;
        bytes32 primaryHash;
        bytes32 primaryCommitment;
        bytes32 secondaryDomain;
        bytes32 secondaryHash;
        bytes32 secondaryCommitment;
        bytes32 nextTip;
    }

    error InvalidRecoveryReceipt();
    error DuplicateRecoveryReceipt(bytes32 coordinate);

    /// @dev e is built from the actual owner's immutable bindings and checked prior cursor.
    ///      The caller must already have authenticated fields, action and acceptance nonce.
    function append(
        State storage s,
        Environment memory e,
        R.RecordFields memory fields,
        bytes32[] memory sortedRecords
    ) public returns (Pair memory p) {
        if (
            e.owner != address(this) || e.domain != IDENTITY || e.actor == address(0)
                || e.registry == address(0) || e.coordinator == address(0)
                || e.archive == address(0) || e.tip == bytes32(0)
        ) revert InvalidRecoveryReceipt();
        p.nextSequence = e.sequence + 2;
        uint64 nextRevision = e.revision + 1;
        p.secondaryHash = H.supersession(sortedRecords);
        if (fields.supersededRecordsHash != p.secondaryHash) revert InvalidRecoveryReceipt();
        p.primaryHash = H.record(e.chainId, e.registry, fields);
        if (p.primaryHash == bytes32(0) || p.secondaryHash == bytes32(0)) {
            revert InvalidRecoveryReceipt();
        }
        p.occurrenceKey = occurrenceKey(p.primaryHash, p.secondaryHash);
        p.primaryCommitment = _receipt(e, nextRevision, e.sequence + 1, PRIMARY, p.primaryHash);
        p.secondaryCommitment =
            _receipt(e, nextRevision, p.nextSequence, SECONDARY, p.secondaryHash);
        if (p.primaryCommitment == bytes32(0) || p.secondaryCommitment == bytes32(0)) {
            revert InvalidRecoveryReceipt();
        }
        bytes32 firstTip = _chain(e, e.sequence, e.sequence + 1, e.tip, p.primaryCommitment);
        p.nextTip = _chain(e, e.sequence + 1, p.nextSequence, firstTip, p.secondaryCommitment);
        p.recordDelta = _delta(e, nextRevision, p);

        if (s.receipts[PRIMARY][p.primaryHash] != bytes32(0)) {
            revert DuplicateRecoveryReceipt(p.primaryHash);
        }
        s.receipts[PRIMARY][p.primaryHash] = p.primaryCommitment;
        if (s.secondaryOccurrences[p.occurrenceKey] != bytes32(0)) {
            revert DuplicateRecoveryReceipt(p.occurrenceKey);
        }
        s.secondaryOccurrences[p.occurrenceKey] = p.secondaryCommitment;
    }

    function occurrenceKey(bytes32 primaryHash, bytes32 secondaryHash)
        public
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                bytes32(0x05c1b33dc3307a69a2b02b1fdcc96323c6c2dcb072805ca38ec6462ded34ce09),
                uint16(2),
                primaryHash,
                SECONDARY,
                secondaryHash
            )
        );
    }

    function _receipt(
        Environment memory e,
        uint64 revision,
        uint64 sequence,
        bytes32 domain,
        bytes32 semantic
    ) private pure returns (bytes32) {
        ReceiptPreimage memory v;
        v.tag = 0x2524f38d4b0732cdfa0810161b89161cfa6da3e7cc1b6cab90fd8b71fbfbd861;
        v.version = 2;
        v.chainId = e.chainId;
        v.registry = e.registry;
        v.coordinator = e.coordinator;
        v.archive = e.archive;
        v.owner = e.owner;
        v.domain = e.domain;
        v.revision = revision;
        v.sequence = sequence;
        v.actor = e.actor;
        v.recordDomain = domain;
        v.semanticHash = semantic;
        return keccak256(abi.encode(v));
    }

    function _chain(
        Environment memory e,
        uint64 beforeSequence,
        uint64 afterSequence,
        bytes32 tip,
        bytes32 commitment
    ) private pure returns (bytes32) {
        ChainPreimage memory v;
        v.tag = 0xee9923a60ff96c9c573fe0297f13dd797f0879da0f711079e7e3e5981fb8ab29;
        v.chainId = e.chainId;
        v.registry = e.registry;
        v.coordinator = e.coordinator;
        v.archive = e.archive;
        v.owner = e.owner;
        v.domain = e.domain;
        v.previousSequence = beforeSequence;
        v.nextSequence = afterSequence;
        v.previousTip = tip;
        v.commitment = commitment;
        return keccak256(abi.encode(v));
    }

    function _delta(Environment memory e, uint64 revision, Pair memory p)
        private
        pure
        returns (bytes32)
    {
        DeltaPreimage memory v;
        v.tag = 0x8ffc87ac7a69cf11f845f37d440821760d42d49ad78aa90d3b437aca24cdba4e;
        v.version = 2;
        v.chainId = e.chainId;
        v.registry = e.registry;
        v.coordinator = e.coordinator;
        v.archive = e.archive;
        v.owner = e.owner;
        v.domain = e.domain;
        v.revision = revision;
        v.previousSequence = e.sequence;
        v.nextSequence = p.nextSequence;
        v.previousTip = e.tip;
        v.count = 2;
        v.primaryDomain = PRIMARY;
        v.primaryHash = p.primaryHash;
        v.primaryCommitment = p.primaryCommitment;
        v.secondaryDomain = SECONDARY;
        v.secondaryHash = p.secondaryHash;
        v.secondaryCommitment = p.secondaryCommitment;
        v.nextTip = p.nextTip;
        return keccak256(abi.encode(v));
    }
}
