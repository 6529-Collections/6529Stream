// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistAttributionDisputeFixture.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDisputeWithdrawal.sol";
import {
    StreamArtistDisputeWithdrawalTypes as W
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDisputeWithdrawal.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReconstruction.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";

contract StreamArtistDisputeWithdrawalTest is ArtistAttributionDisputeFixture {
    function _withdraw(AD.Filing memory p, AD.Standing memory st, T.Authorization memory a)
        private
        returns (bytes32)
    {
        return IStreamArtistDisputeWithdrawal(address(ingress)).withdrawAttributionDispute(p, st, a);
    }

    function _data(AD.Filing memory p, AD.Standing memory st, T.Authorization memory a)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodeCall(IStreamArtistDisputeWithdrawal.withdrawAttributionDispute, (p, st, a));
    }

    function _outcome(bytes32 opening) private view returns (W.Outcome memory) {
        return
            IStreamArtistDisputeWithdrawal(address(ingress)).attributionDisputeWithdrawal(opening);
    }

    function _delegatedOpen(uint64 maxUses)
        private
        returns (bytes32 grant, bytes32 opening, AD.Standing memory st)
    {
        _delegateSetup();
        grant = _grant(_delegation(1, 16, 1000, 2000, maxUses));
        st = _standing();
        st.delegation = grant;
        AD.Filing memory p = _filing(1, keccak256("delegate original opening"));
        T.Authorization memory a = T.Authorization(0, 2000, "");
        a.signature = _delegateSignature(_digest(p, a));
        opening = ingress.openAttributionDispute(p, st, a);
    }

    function _delegateWithdrawal(AD.Filing memory p) private returns (T.Authorization memory a) {
        a = T.Authorization(1, 2000, "");
        a.signature = _delegateSignature(_digest(p, a));
    }

    function testDirectSafeWithdrawalOriginalRecordEventNativeLanesAndArchive() public {
        _accept();
        bytes32 opening = _open(keccak256("direct withdrawal opening"));
        AD.Filing memory p = _filing(2, keccak256("direct withdrawal"));
        uint256 nonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        T.Authorization memory a = T.Authorization(nonce, 0, "");
        bytes32 expected = _record(p, address(artist), 1, nonce, uint64(block.timestamp));
        T.Snapshot memory before_ = IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2();
        uint256 count = IStreamArtistNativeReceipts(suite.owners[4]).artistNativeReceiptCount();
        (bytes32 priorTip, uint64 laneCount) = ingress.artistHistoryLane(2, bytes32(uint256(1)));
        require(
            priorTip != 0
                && ingress.supportsInterface(type(IStreamArtistDisputeWithdrawal).interfaceId),
            "typed capability and existing lane"
        );
        vm.recordLogs();
        require(
            this.executeArtistSafe(_data(p, _standing(), a)), "actual threshold Safe withdrawal"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        W.Outcome memory outcome = _outcome(opening);
        require(
            outcome.recordHash == expected && outcome.restoredState == 2
                && outcome.counterStatementRecordHash == 0,
            "saved terminal outcome"
        );
        AD.Record memory record = ingress.attributionDisputeRecord(expected);
        require(
            record.recordHash == expected && record.terms.disputeAction == 2
                && record.signer == address(artist) && record.disputeRecordHash == opening
                && record.previousRecordHash == opening && record.governanceActionId == 0,
            "original full immutable record"
        );
        bytes memory preimage =
            IStreamArtistReconstruction(address(ingress)).recordPreimageBytes(expected);
        require(
            keccak256(preimage) == expected && preimage.length == 384,
            "original twelve-word canonical preimage in Archive"
        );
        bytes32 topic = keccak256(
            "AttributionDisputeWithdrawn(uint16,uint256,bytes32,address,uint64,uint8,bytes32,bytes32,uint256,uint64,bytes32,bytes32,uint8)"
        );
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == suite.owners[4] && logs[i].topics.length != 0
                    && logs[i].topics[0] == topic
            ) {
                ++found;
                require(
                    logs[i].topics.length == 4 && logs[i].topics[1] == bytes32(uint256(1))
                        && logs[i].topics[2] == opening
                        && logs[i].topics[3] == bytes32(uint256(uint160(address(artist)))),
                    "exact indexed event"
                );
                require(
                    keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                p.bindingGeneration,
                                uint8(1),
                                p.evidenceHash,
                                p.reasonHash,
                                nonce,
                                uint64(block.timestamp),
                                expected,
                                bytes32(0),
                                uint8(2)
                            )
                        ),
                    "independent full event data"
                );
            }
        }
        require(found == 1, "one committed withdrawal event");
        T.Snapshot memory after_ = IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2();
        require(
            after_.revision == before_.revision + 1
                && after_.recordChainTip == before_.recordChainTip,
            "Identity original zero-record commit"
        );
        StreamArtistHistoryTypes.Receipt memory receipt =
            IStreamArtistNativeReceipts(suite.owners[4]).artistNativeReceiptAt(count);
        require(
            receipt.operation == 61 && receipt.recordHash == expected
                && receipt.artistId == artistId && receipt.collectionId == 1,
            "actual native receipt61"
        );
        (bytes32 suffix,) = ingress.artistHistoryRecordAt(2, bytes32(uint256(1)), laneCount);
        require(
            suffix == expected && !_head().open && _head().disputeRecordHash == opening,
            "canonical suffix and unchanged opening history"
        );
        _state(2);
        _deArchive(61, address(artist), expected);
    }

    function testRelayedWithdrawalRetainsLatestCounterAndCannotReplayOrRetargetReopenedDispute()
        public
    {
        _accept();
        bytes32 opening = _open(keccak256("relayed opening"));
        bytes32 counter = _counter(keccak256("retained defense"));
        AD.ResolutionRequest memory resolution = _resolution(1, keccak256("saved arbiter plan"));
        AD.Context memory context = ingress.attributionDisputeResolutionContext(resolution);
        AD.Filing memory p = _filing(2, keccak256("relayed withdrawal"));
        T.Authorization memory a = _signed(p);
        require(
            ingress.attributionDisputeDigest(p, a) == _digest(p, a),
            "unchanged independent EIP712 action2"
        );
        bytes32 record = _withdraw(p, _standing(), a);
        require(
            record == _record(p, address(artist), 1, a.nonce, uint64(block.timestamp))
                && _outcome(opening).counterStatementRecordHash == counter
                && ingress.attributionDisputeRecord(record).previousRecordHash == counter,
            "latest counter retained in terminal record"
        );
        require(
            keccak256(StreamArtistIdentityAuthority(suite.owners[2]).signatureBundle(record))
                == keccak256(a.signature),
            "original signature bytes retained"
        );
        bytes32 roots = _roots();
        bytes memory repeated = _data(p, _standing(), a);
        vm.expectRevert();
        this.disputeRelay(repeated);
        vm.expectRevert();
        this.disputeGoverned(
            abi.encodeCall(
                IStreamArtistAttributionDisputes.resolveAttributionDispute, (resolution)
            ),
            context,
            resolution.reasonHash,
            1
        );
        require(_roots() == roots, "closed dispute cannot repeat or consume saved arbiter plan");
        bytes32 next = _open(keccak256("new independent opening"));
        require(
            next != opening && ingress.attributionDisputeRecord(next).previousRecordHash == opening,
            "later open preserves earlier head"
        );
        // Fresh nonce and valid signature do not retarget the old parent-bound evidence.
        a = _signed(p);
        bytes memory refusal = _data(p, _standing(), a);
        vm.expectRevert();
        this.disputeRelay(refusal);
        require(
            _head().open && _head().disputeRecordHash == next
                && _outcome(opening).recordHash == record,
            "later episode unchanged"
        );
        _deArchive(61, address(this), record);
    }

    function testArbiterOpeningAndWrongActionNeverUseWithdrawal() public {
        _accept();
        AD.Filing memory p = _filing(1, keccak256("arbiter original"));
        AD.Standing memory empty;
        T.Authorization memory blank;
        _govern(
            abi.encodeCall(
                IStreamArtistAttributionDisputes.openAttributionDispute, (p, empty, blank)
            ),
            ingress.attributionDisputeOpeningContext(p),
            p.reasonHash,
            1
        );
        p = _filing(2, keccak256("artist cannot withdraw arbiter"));
        T.Authorization memory a = _signed(p);
        bytes32 roots = _roots();
        bytes memory refusal = _data(p, _standing(), a);
        vm.expectRevert();
        this.disputeRelay(refusal);
        p.disputeAction = 1;
        refusal = _data(p, _standing(), a);
        vm.expectRevert();
        this.disputeRelay(refusal);
        require(
            _roots() == roots && _head().open, "arbiter authority and reserved actions unchanged"
        );
    }

    function testOriginalDelegateCanWithdrawButPrimaryCannotReplaceItsOpening() public {
        _accept();
        (bytes32 grant, bytes32 opening, AD.Standing memory st) = _delegatedOpen(3);
        AD.Filing memory p = _filing(2, keccak256("same delegate withdraws"));
        T.Authorization memory primary = _signed(p);
        bytes32 roots = _roots();
        bytes memory refusal = _data(p, _standing(), primary);
        vm.expectRevert();
        this.disputeRelay(refusal);
        require(_roots() == roots, "current primary is not recorded opener");
        bytes32 record = _withdraw(p, st, _delegateWithdrawal(p));
        require(
            _outcome(opening).recordHash == record
                && ingress.attributionDisputeRecord(record).authorityClass == 2
                && ingress.delegationRecord(grant).uses == 2,
            "same live original grant consumed once"
        );
        _state(2);
    }

    function testRevokedOriginalDelegateCannotWithdrawWithPreviouslySignedAuthorization() public {
        _accept();
        (bytes32 grant, bytes32 opening, AD.Standing memory st) = _delegatedOpen(3);
        AD.Filing memory p = _filing(2, keccak256("revoked withdrawal"));
        T.Authorization memory a = _delegateWithdrawal(p);
        _revoke(grant);
        bytes32 roots = _roots();
        vm.expectRevert();
        this.disputeRelay(_data(p, st, a));
        require(
            _roots() == roots && _outcome(opening).recordHash == 0
                && ingress.delegationRecord(grant).uses == 1,
            "live revocation wins over earlier signature"
        );
        _state(4);
    }

    function testExhaustedOriginalDelegateCannotWithdraw() public {
        _accept();
        (bytes32 grant, bytes32 opening, AD.Standing memory st) = _delegatedOpen(1);
        AD.Filing memory p = _filing(2, keccak256("exhausted withdrawal"));
        bytes32 roots = _roots();
        bytes memory refusal = _data(p, st, _delegateWithdrawal(p));
        vm.expectRevert();
        this.disputeRelay(refusal);
        require(
            _roots() == roots && _outcome(opening).recordHash == 0
                && ingress.delegationRecord(grant).uses == 1,
            "withdrawal retains original usage limit"
        );
    }

    function testExecutedRotationDoesNotTransferOpenerWithdrawalStanding() public {
        _accept();
        bytes32 opening = _open(keccak256("old principal opening"));
        _newRotationSafe(8761);
        bytes32 rotation = _stageRotation(0);
        _executeTimedRotation(rotation);
        _adoptRotatedSafe();
        AD.Filing memory p = _filing(2, keccak256("new principal is not opener"));
        T.Authorization memory a = _signed(p);
        bytes32 roots = _roots();
        bytes memory refusal = _data(p, _standing(), a);
        vm.expectRevert();
        this.disputeRelay(refusal);
        require(
            _roots() == roots && _outcome(opening).recordHash == 0,
            "no historical signer substitution"
        );
        _state(4);
    }

    function testMissingCoverageAndLateArchiveRollbackAllowIdenticalSafeRetry() public {
        _accept();
        bytes32 opening = _open(keccak256("atomic withdrawal opening"));
        AD.Filing memory p = _filing(2, keccak256("atomic withdrawal"));
        uint256 nonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        T.Authorization memory a = T.Authorization(nonce, 0, "");
        bytes memory data = _data(p, _standing(), a);
        bytes32 record = _record(p, address(artist), 1, nonce, uint64(block.timestamp));
        bytes32 roots = _roots();
        uint256 safeNonce = artist.nonce();
        uint256 count = IStreamArtistNativeReceipts(suite.owners[4]).artistNativeReceiptCount();
        (bytes32 tip, uint64 laneCount) = ingress.artistHistoryLane(2, bytes32(uint256(1)));
        avm.mockCallRevert(
            address(estateCoverageProvider),
            abi.encodeCall(
                IStreamCollectionArchivalCoverage.requireCollectionEvidence, (1, p.evidenceHash)
            ),
            abi.encodeWithSelector(DisputeTestFailure.selector)
        );
        vm.expectRevert(bytes("GS013"));
        this.executeArtistSafe(data);
        require(
            _roots() == roots && artist.nonce() == safeNonce && _head().open,
            "coverage failure rolls back whole Safe"
        );
        avm.clearMockedCalls();
        _deMetadata();
        avm.mockCallRevert(
            address(archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(DisputeTestFailure.selector)
        );
        vm.expectRevert(bytes("GS013"));
        this.executeArtistSafe(data);
        require(
            _roots() == roots && artist.nonce() == safeNonce && _outcome(opening).recordHash == 0
                && ingress.attributionDisputeRecord(record).recordHash == 0
                && IStreamArtistNativeReceipts(suite.owners[4]).artistNativeReceiptCount() == count,
            "late Archive restores record outcome nonce and journal"
        );
        (bytes32 afterTip, uint64 afterCount) = ingress.artistHistoryLane(2, bytes32(uint256(1)));
        require(afterTip == tip && afterCount == laneCount, "canonical lane unchanged on rollback");
        avm.clearMockedCalls();
        _deMetadata();
        require(this.executeArtistSafe(data), "exact same Safe calldata retry");
        require(
            artist.nonce() == safeNonce + 1 && _outcome(opening).recordHash == record,
            "only successful attempt commits"
        );
        _deArchive(61, address(artist), record);
    }

    function testContestedIdentityAllowsOnlyOriginalDefensiveWithdrawal() public {
        _accept();
        bytes32 opening = _open(keccak256("defensive withdrawal opening"));
        _selfGuardian();
        require(this.executeArtistSafe(_contestData(0)), "actual compromise contest");
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).status == 4,
            "identity contested"
        );
        AD.Filing memory p = _filing(2, keccak256("defensive withdrawal"));
        bytes32 record = _withdraw(p, _standing(), _signed(p));
        require(
            _outcome(opening).recordHash == record
                && IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).status == 4,
            "withdrawal does not dismiss identity compromise"
        );
        _state(2);
    }

    function testWithdrawalDirectNonceDeadlineAndOwnerAdmissionRemainExact() public {
        _accept();
        bytes32 opening = _open(keccak256("withdrawal admission opening"));
        AD.Filing memory p = _filing(2, keccak256("withdrawal admission"));
        uint256 nonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        T.Authorization memory a = T.Authorization(nonce + 1, 0, "");
        bytes memory data = _data(p, _standing(), a);
        uint256 safeNonce = artist.nonce();
        bytes32 roots = _roots();
        vm.expectRevert(bytes("GS013"));
        this.executeArtistSafe(data);
        require(
            _roots() == roots && artist.nonce() == safeNonce, "wrong direct nonce rolls back Safe"
        );
        a = T.Authorization(nonce, uint64(block.timestamp - 1), "");
        a.signature = _signature(_digest(p, a));
        data = _data(p, _standing(), a);
        vm.expectRevert();
        this.disputeRelay(data);
        T.ActionContext memory c = T.ActionContext(
            61, address(this), IStreamArtistOwner(suite.owners[4]).ownerStateSnapshotV2()
        );
        AD.Admission memory supplied;
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(this)));
        IStreamArtistDisputeWithdrawalOwner(suite.owners[4])
            .applyDisputeWithdrawal(c, p, supplied, nonce);
        require(
            _roots() == roots && _outcome(opening).recordHash == 0,
            "deadline and unauthorized owner calls do not create history"
        );
        a = T.Authorization(nonce, 0, "");
        require(
            this.executeArtistSafe(_data(p, _standing(), a)), "same unused original nonce succeeds"
        );
        _state(2);
    }
}
