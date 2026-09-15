// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistGovernanceWitness.sol";
import "./StreamArtistHistoryProof.sol";
import {
    StreamArtistHistoryTypes as H,
    IStreamArtistHistory,
    IStreamArtistHistoryOwner,
    IStreamArtistNativeReceipts
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";

/// @notice Original typed 55/56/57 recipes and deterministic fixed-owner native receipt composition.
library StreamArtistHistoryOperations {
    function sync(T.SuiteConfiguration storage suite) public {
        IStreamArtistHistoryOwner identity = IStreamArtistHistoryOwner(suite.owners[2]);
        // Fixed owner order is canonical within one atomic operation; local creation order is retained.
        for (uint256 i; i < 7; ++i) {
            address source = suite.owners[i];
            uint256 first = identity.artistHistorySourceCursor(source);
            uint256 end = IStreamArtistNativeReceipts(source).artistNativeReceiptCount();
            if (end < first || end - first > 128) revert T.InvalidRecord();
            if (end == first) continue;
            H.Receipt[] memory rows = new H.Receipt[](end - first);
            for (uint256 j; j < rows.length; ++j) {
                rows[j] = IStreamArtistNativeReceipts(source).artistNativeReceiptAt(first + j);
            }
            identity.syncArtistNativeHistory(source, first, rows);
        }
    }

    function requireCurrent(T.SuiteConfiguration storage suite) public view {
        (bool observed,,) = IStreamArtistHistory(suite.owners[2]).artistRegistryCutover();
        (address current,) = StreamArtistHistoryProof.pointer(
            suite.core, StreamArtistHistoryProof.cap(suite.registry)
        );
        if (observed || current != suite.registry) revert T.InvalidBinding();
    }

    function commit(D.CoordinatorContext memory x, address actor, H.Binding memory p) public {
        address source = x.suite.owners[2];
        T.Snapshot memory before_ = IStreamArtistOwner(source).ownerStateSnapshotV2();
        address executor = IStreamArtistIdentityContestOwner(source).artistWindowAuthority();
        if (actor != executor) revert T.Unauthorized(actor);
        H.Context memory current = IStreamArtistHistory(source)
            .artistHistoryImportContext(
                p.predecessorRegistry, p.snapshotBlock, p.importRoot, p.manifestHash
            );
        Contest.GovernanceWitness memory g = StreamArtistGovernanceWitness.readEstateAcceleration(
            executor, p.manifestHash, current.scopeHash, current.oldValueHash, current.newValueHash
        );
        IStreamArtistHistoryOwner(source)
            .applyArtistHistoryImport(T.ActionContext(55, actor, before_), p, g.actionId);
        _archive(
            x, 55, actor, keccak256(abi.encode(p, g.actionId)), before_, abi.encode(p, current, g)
        );
    }

    function verify(
        D.CoordinatorContext memory x,
        address actor,
        uint256 index,
        H.Leaf memory p,
        bytes32[] memory proof
    ) public {
        address source = x.suite.owners[2];
        T.Snapshot memory before_ = IStreamArtistOwner(source).ownerStateSnapshotV2();
        IStreamArtistHistoryOwner(source)
            .applyArtistHistoryLaneVerification(
                T.ActionContext(56, actor, before_), index, p, proof
            );
        _archive(
            x,
            56,
            actor,
            StreamArtistHistoryProof.leaf(_predecessor(source, index), p),
            before_,
            abi.encode(index, p, proof)
        );
    }

    function observe(D.CoordinatorContext memory x, address actor) public {
        address source = x.suite.owners[2];
        T.Snapshot memory before_ = IStreamArtistOwner(source).ownerStateSnapshotV2();
        IStreamArtistHistoryOwner(source)
            .applyArtistRegistryCutover(T.ActionContext(57, actor, before_));
        (bool done, address successor, uint64 at_) =
            IStreamArtistHistory(source).artistRegistryCutover();
        _archive(
            x,
            57,
            actor,
            keccak256(abi.encode(successor, at_)),
            before_,
            abi.encode(done, successor, at_)
        );
    }

    function _predecessor(address source, uint256 index) private view returns (address p) {
        (p,,,) = IStreamArtistHistory(source).importedHistoryBinding(index);
    }

    function _archive(
        D.CoordinatorContext memory x,
        uint16 op,
        address actor,
        bytes32 record,
        T.Snapshot memory before_,
        bytes memory payload
    ) private {
        T.Snapshot[7] memory prior;
        prior[2] = before_;
        T.Snapshot[7] memory after_;
        after_[2] = IStreamArtistOwner(x.suite.owners[2]).ownerStateSnapshotV2();
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                x.suite.registry,
                address(this),
                op,
                actor,
                record
            )
        );
        bytes memory evidence =
            abi.encode(uint16(1), x.configurationHash, op, actor, record, prior, after_, payload);
        (bytes32 hash,, bool added) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(id, 1, evidence);
        if (!added || hash != keccak256(evidence)) revert T.InvalidRecord();
    }
}
