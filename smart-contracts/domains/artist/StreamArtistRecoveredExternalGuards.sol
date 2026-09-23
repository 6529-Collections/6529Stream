// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveryActionTypes as A
} from "../../interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    StreamArtistUnavailabilityTypes as U
} from "../../interfaces/stream/artist/StreamArtistUnavailabilityTypes.sol";
import {
    StreamArtistEntropyUnavailabilityTypes as EU
} from "../../interfaces/stream/artist/IStreamArtistEntropyUnavailability.sol";
import {
    IStreamGovernanceActionFacts as G
} from "../../interfaces/stream/governance/IStreamGovernanceActionFacts.sol";
import {
    GovernanceActionStatus as Status
} from "../../interfaces/stream/governance/StreamGovernanceTypes.sol";
import {
    IStreamArtworkFinalityRecovery as F
} from "../../interfaces/stream/finality/IStreamArtworkFinalityRecovery.sol";
import {
    IStreamFinalityRecoveryGovernanceBinding as FB
} from "../../interfaces/stream/finality/IStreamFinalityRecoveryGovernanceBinding.sol";
import {
    StreamFinalityRecoveryRecord
} from "../../interfaces/stream/finality/StreamFinalityRecoveryTypes.sol";
import {
    IStreamEntropyArtistUnavailability as EUHost
} from "../../interfaces/stream/entropy/IStreamEntropyArtistUnavailability.sol";
import {
    IStreamEntropyFreshRecovery as EHost
} from "../../interfaces/stream/entropy/IStreamEntropyFreshRecovery.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationChronology as Chronology
} from "./StreamArtistRecoveredHydrationChronology.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import { StreamArtistRecoveryHashes as RecoveryHashes } from "./StreamArtistRecoveryHashes.sol";

import "./StreamArtistRecoveredFinalityGuards.sol";
import "./StreamArtistRecoveredEntropyGuards.sol";

/// @notice Exact external guard observations for the first recovered-authority graph.
/// @dev collect receives an authenticated complete provenance and fixed-owner Identity bundle.
/// These observations never install or reset external state and are not new authorizations.
/// Broader Metadata publication/content and entropy-policy histories are not admitted here.
library StreamArtistRecoveredExternalGuards {
    bytes32 internal constant SCHEMA = keccak256("6529STREAM_ARTIST_RECOVERED_EXTERNAL_GUARDS_V1");
    uint256 private constant MAX_RECORD_BYTES = 32_768;

    struct ActionGuard {
        bytes32 associationHash;
        RH.Point origin;
        A.Witness witness;
        G.ActionFacts facts;
    }

    struct FinalityGuard {
        bytes32 findingRecordHash;
        RH.Position origin;
        address core;
        U.Target target;
        bytes32 registryCodeHash;
        address executor;
        bytes32 executorCodeHash;
        G.ActionFacts action;
        bool actionTerminal;
        StreamFinalityRecoveryRecord record;
    }

    struct EntropyEvidence {
        bytes32 findingRecordHash;
        bytes32 intentHash;
        uint64 noticeEndsAt;
    }

    struct EntropyGuard {
        bytes32 findingRecordHash;
        RH.Position origin;
        address core;
        address coordinator;
        bytes32 coordinatorCodeHash;
        bytes32 oldRequestKey;
        bytes32 newRequestKey;
        bool terminal;
        EHost.RecoveryReceipt receipt;
        EntropyEvidence evidence;
    }

    struct Snapshot {
        bytes32 schema;
        bytes32 provenanceCommitment;
        bytes32 artistId;
        ActionGuard[] actions;
        FinalityGuard[] finality;
        EntropyGuard[] entropy;
    }

    error InvalidRecoveredExternalGuard(bytes32 recordHash);
    error RecoveredExternalDependencyChanged(address target);
    error RecoveredExternalReadFailed(address target);

    function collect(RH.Provenance calldata p, IH.Bundle calldata b)
        public
        view
        returns (Snapshot memory s)
    {
        s.schema = SCHEMA;
        s.provenanceCommitment = Provenance.validate(p);
        s.artistId = b.artistId;
        if (
            b.artistId == 0 || p.origins[0].chainId != block.chainid
                || b.actions.length > RH.MAX_REPLAY_ALIASES
                || b.findings.length > RH.MAX_JOURNAL_ENTRIES
        ) {
            revert InvalidRecoveredExternalGuard(b.artistId);
        }
        s.actions = new ActionGuard[](b.actions.length);
        for (uint256 i; i < b.actions.length; ++i) {
            IH.ActionRow memory row = b.actions[i];
            _point(p, row.point);
            if (
                row.association.artistId != b.artistId || row.association.associationHash == 0
                    || row.association.ownerRevision != row.point.ownerRevision
            ) {
                revert InvalidRecoveredExternalGuard(row.association.action.actionId);
            }
            ActionGuard memory a;
            a.associationHash = row.association.associationHash;
            a.origin = row.point;
            a.witness = row.association.action;
            a.facts = _action(a.witness);
            if (row.execution != 0 && a.facts.status != Status.EXECUTED) {
                revert InvalidRecoveredExternalGuard(a.witness.actionId);
            }
            s.actions[i] = a;
        }
        uint256 entropyCount;
        for (uint256 i; i < b.findings.length; ++i) {
            if (b.findings[i].entropyAdmission.target.coordinator != address(0)) ++entropyCount;
        }
        s.finality = new FinalityGuard[](b.findings.length - entropyCount);
        s.entropy = new EntropyGuard[](entropyCount);
        uint256 f;
        uint256 e;
        for (uint256 i; i < b.findings.length; ++i) {
            IH.FindingRow memory row = b.findings[i];
            RH.OriginEnvironment memory origin = _finding(p, b.artistId, row);
            if (row.entropyAdmission.target.coordinator == address(0)) {
                s.finality[f++] = _finality(row, origin);
            } else {
                s.entropy[e++] = _entropy(row, origin);
            }
        }
    }

    function requireCurrent(Snapshot memory s) public view {
        if (
            s.schema != SCHEMA || s.provenanceCommitment == 0 || s.artistId == 0
                || s.actions.length > RH.MAX_REPLAY_ALIASES
                || s.finality.length + s.entropy.length > RH.MAX_JOURNAL_ENTRIES
        ) {
            revert InvalidRecoveredExternalGuard(s.artistId);
        }
        for (uint256 i; i < s.actions.length; ++i) {
            ActionGuard memory a = s.actions[i];
            _same(abi.encode(a.facts), abi.encode(_action(a.witness)), a.witness.actionId);
        }
        for (uint256 i; i < s.finality.length; ++i) {
            FinalityGuard memory f = s.finality[i];
            bytes memory expected = abi.encode(f);
            FinalityGuard memory live = _finalityCurrent(f);
            _same(expected, abi.encode(live), f.findingRecordHash);
        }
        for (uint256 i; i < s.entropy.length; ++i) {
            EntropyGuard memory e = s.entropy[i];
            bytes memory expected = abi.encode(e);
            EntropyGuard memory live = _entropyCurrent(e);
            _same(expected, abi.encode(live), e.findingRecordHash);
        }
    }

    function _action(A.Witness memory w) private view returns (G.ActionFacts memory facts) {
        _pin(w.executor, w.executorCodeHash);
        facts = _facts(w.executor, w.actionId);
        if (
            facts.actionClass != 2 || facts.callHash != w.callsHash
                || facts.notBefore != w.notBefore || facts.expiresAfter != w.expiresAfter
        ) {
            revert InvalidRecoveredExternalGuard(w.actionId);
        }
        // An executed historical action remains admissible after its execution window expired.
    }

    function _finality(IH.FindingRow memory row, RH.OriginEnvironment memory origin)
        private
        view
        returns (FinalityGuard memory f)
    {
        return StreamArtistRecoveredFinalityGuards.collect(row, origin);
    }

    function _finalityCurrent(FinalityGuard memory f) private view returns (FinalityGuard memory) {
        return StreamArtistRecoveredFinalityGuards.requireCurrent(f);
    }

    function _entropy(IH.FindingRow memory row, RH.OriginEnvironment memory origin)
        private
        view
        returns (EntropyGuard memory e)
    {
        return StreamArtistRecoveredEntropyGuards.collect(row, origin);
    }

    function _entropyCurrent(EntropyGuard memory e) private view returns (EntropyGuard memory) {
        return StreamArtistRecoveredEntropyGuards.requireCurrent(e);
    }

    function _finding(RH.Provenance memory p, bytes32 artist, IH.FindingRow memory row)
        private
        view
        returns (RH.OriginEnvironment memory origin)
    {
        _point(p, row.position.point);
        origin = Provenance.environment(p, row.position.point.environmentHash);
        if (
            origin.chainId != block.chainid || row.record.terms.artistId != artist
                || row.record.recordHash == 0 || row.record.terms.collectionId == 0
                || RecoveryHashes.findingRecord(
                        Hashes.Environment(
                            origin.chainId, origin.registry, origin.core, origin.manager
                        ),
                        row.record
                    ) != row.record.recordHash
        ) revert InvalidRecoveredExternalGuard(row.record.recordHash);
        bool found;
        for (uint256 i; i < p.journals[2].length; ++i) {
            RH.JournalEntry memory j = p.journals[2][i];
            if (keccak256(abi.encode(j.position)) != keccak256(abi.encode(row.position))) continue;
            if (
                j.receipt.operation != 23 || j.receipt.artistId != artist
                    || j.receipt.collectionId != row.record.terms.collectionId
                    || j.receipt.recordHash != row.record.recordHash
            ) revert InvalidRecoveredExternalGuard(row.record.recordHash);
            found = true;
        }
        if (!found) revert InvalidRecoveredExternalGuard(row.record.recordHash);
    }

    function _point(RH.Provenance memory p, RH.Point memory point) private pure {
        if (point.ownerIndex != 2) {
            revert RH.InvalidRecoveredHydrationPoint(
                point.environmentHash, point.ownerIndex, point.ownerRevision
            );
        }
        Chronology.validatePoint(p, point);
    }

    function _facts(address executor, bytes32 id) private view returns (G.ActionFacts memory f) {
        if (id == 0) revert InvalidRecoveredExternalGuard(id);
        f = abi.decode(
            _read(executor, abi.encodeCall(G.governanceActionFacts, (id)), 160), (G.ActionFacts)
        );
        if (f.status == Status.NONE || f.callHash == 0) revert InvalidRecoveredExternalGuard(id);
    }

    function _terminal(Status status) private pure returns (bool) {
        return status == Status.CANCELLED || status == Status.EXECUTED || status == Status.EXPIRED
            || status == Status.VETOED;
    }

    function _pin(address target, bytes32 codeHash) private view {
        if (target.code.length == 0 || codeHash == 0 || target.codehash != codeHash) {
            revert RecoveredExternalDependencyChanged(target);
        }
    }

    function _address(address target, bytes memory input) private view returns (address) {
        return abi.decode(_read(target, input, 32), (address));
    }

    function _same(bytes memory expected, bytes memory actual, bytes32 key) private pure {
        if (keccak256(expected) != keccak256(actual)) revert InvalidRecoveredExternalGuard(key);
    }

    function _read(address target, bytes memory input, uint256 exact)
        private
        view
        returns (bytes memory out)
    {
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(input, 32), mload(input), 0, 0)
            size := returndatasize()
        }
        if (!ok || size == 0 || size > MAX_RECORD_BYTES || (exact != 0 && size != exact)) {
            revert RecoveredExternalReadFailed(target);
        }
        out = new bytes(size);
        assembly ("memory-safe") { returndatacopy(add(out, 32), 0, size) }
    }
}
