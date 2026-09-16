// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistOnboardingFixture.sol";
import {
    IStreamArtistHistory as History,
    IStreamArtistNativeReceipts as Native,
    StreamArtistHistoryTypes as HT
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";

/// @notice Actual Safe/Artist/Cause/Archive receipts with original typed unit Core/governance.
contract StreamArtistHistoryCauseReceiptsTest is ArtistOnboardingFixture {
    bytes32 private constant CHAIN =
        0x2eac9cfc5ca84fbeed56ef1741255e2ec7e45f48bc5c5ceda94397aa23d2f23e;

    function _cause(uint8 kind) internal view returns (Dismissal.Cause memory cause) {
        cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.causeHash != 0 && cause.facts.kind == kind && cause.facts.artistId == artistId,
            "actual immutable cause identity"
        );
        require(
            cause.causeHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1"),
                        block.chainid,
                        address(ingress),
                        suite.owners[2],
                        cause.facts
                    )
                ),
            "independent original cause preimage"
        );
    }

    function _fold() internal view {
        History h = History(address(ingress));
        (bytes32 expected, uint64 count) = h.artistHistoryLane(1, artistId);
        bytes32 chain;
        for (uint64 i; i < count; ++i) {
            (bytes32 record, bytes32 saved) = h.artistHistoryRecordAt(1, artistId, i);
            chain = keccak256(abi.encode(CHAIN, chain, record));
            require(saved == chain, "every independent prefix");
        }
        require(chain == expected, "exact complete lane fold");
    }

    function testStandingVetoCreatesCauseReceiptWithoutChangingOriginalOwnerRecordTip() external {
        _newRotationSafe(19901);
        bytes32 rotation = _stageRotation(0);
        History h = History(address(ingress));
        (, uint64 count) = h.artistHistoryLane(1, artistId);
        bytes32 collectionTip = h.collectionRecordChainHash(1);
        T.Snapshot memory before_ = IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2();
        uint256 receipts = Native(suite.owners[2]).artistNativeReceiptCount();
        bytes memory data =
            abi.encodeCall(
            IStreamArtistRotation.vetoArtistRotation, (artistId, rotation, bytes32(0))
        );
        require(this.executeTargetSafe(address(ingress), data), "actual current principal veto");
        Dismissal.Cause memory cause = _cause(2);
        require(
            cause.facts.referenceHash == rotation && cause.facts.reasonHash == 0
                && cause.facts.evidenceHash == 0,
            "original zero-reason veto profile"
        );
        HT.Receipt memory row = Native(suite.owners[2]).artistNativeReceiptAt(receipts);
        require(
            row.operation == 31 && row.recordHash == cause.causeHash && row.artistId == artistId
                && row.collectionId == 0
                && Native(suite.owners[2]).artistNativeReceiptCount() == receipts + 1,
            "single artist-only cause creation receipt"
        );
        (bytes32 appended,) = h.artistHistoryRecordAt(1, artistId, count);
        (, uint64 afterCount) = h.artistHistoryLane(1, artistId);
        T.Snapshot memory after_ = IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2();
        require(
            appended == cause.causeHash && afterCount == count + 1
                && h.collectionRecordChainHash(1) == collectionTip,
            "one native cause, unchanged collection"
        );
        require(
            after_.revision == before_.revision + 1
                && after_.recordChainTip == before_.recordChainTip,
            "original zero m.record semantic commit remains exact"
        );
        _fold();
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(ingress), data);
        (, afterCount) = h.artistHistoryLane(1, artistId);
        require(afterCount == count + 1, "replayed veto cannot append");
    }

    function testCompromiseAppendsContestThenDistinctCauseWithOriginalReferences() external {
        _selfGuardian();
        History h = History(address(ingress));
        (, uint64 count) = h.artistHistoryLane(1, artistId);
        uint256 receipts = Native(suite.owners[2]).artistNativeReceiptCount();
        bytes32 collectionTip = h.collectionRecordChainHash(1);
        require(
            this.executeTargetSafe(address(ingress), _contestData(0)), "actual guardian compromise"
        );
        Dismissal.Cause memory cause = _cause(1);
        HT.Receipt memory first = Native(suite.owners[2]).artistNativeReceiptAt(receipts);
        HT.Receipt memory second = Native(suite.owners[2]).artistNativeReceiptAt(receipts + 1);
        require(
            first.operation == 33 && second.operation == 33
                && first.recordHash == cause.facts.referenceHash
                && second.recordHash == cause.causeHash && first.recordHash != second.recordHash
                && Native(suite.owners[2]).artistNativeReceiptCount() == receipts + 2,
            "two distinct immutable records"
        );
        (bytes32 a,) = h.artistHistoryRecordAt(1, artistId, count);
        (bytes32 b,) = h.artistHistoryRecordAt(1, artistId, count + 1);
        (, uint64 afterCount) = h.artistHistoryLane(1, artistId);
        require(
            a == first.recordHash && b == second.recordHash && afterCount == count + 2
                && h.collectionRecordChainHash(1) == collectionTip,
            "deterministic local receipt order"
        );
        require(
            _operationPayload(33, address(artist), first.recordHash).length != 0,
            "unchanged original Archive key"
        );
        _fold();
    }

    function testCompromiseCauseJournalAndLaneRollbackThenExactSafeRetry() external {
        _selfGuardian();
        History h = History(address(ingress));
        bytes32 before_ = h.artistRecordChainHash(artistId);
        bytes32 roots = _roots();
        uint256 receipts = Native(suite.owners[2]).artistNativeReceiptCount();
        uint256 safeNonce = artist.nonce();
        uint256 payloadCount = archive.storedPayloadCount();
        bytes memory data = _contestData(0);
        avm.mockCallRevert(
            address(archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSignature("Error(string)", "cause receipt Archive failure")
        );
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(ingress), data);
        require(
            ingress.currentIdentityContestCause(artistId).causeHash == 0 && _roots() == roots
                && h.artistRecordChainHash(artistId) == before_
                && Native(suite.owners[2]).artistNativeReceiptCount() == receipts
                && artist.nonce() == safeNonce && archive.storedPayloadCount() == payloadCount,
            "whole original transaction rollback"
        );
        avm.clearMockedCalls();
        require(this.executeTargetSafe(address(ingress), data), "byte-identical authority retry");
        _cause(1);
        require(
            Native(suite.owners[2]).artistNativeReceiptCount() == receipts + 2
                && artist.nonce() == safeNonce + 1,
            "one successful pair, no reverted observation folded"
        );
        _fold();
    }
}
