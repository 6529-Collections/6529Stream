// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamRightsRecordSelection.t.sol";
import "../../helpers/RecordSelectionLockFixture.sol";

contract StreamRightsRecordSelectionLockTest is
    StreamRightsRecordSelectionTest,
    RecordSelectionLockFixture
{
    function _sealRights(bytes32 record)
        private
        returns (IStreamRecordSelectionLock.SelectionLock memory)
    {
        _sealGraph(address(core), address(executor));
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            selection.selectionLockTransition(1, subject, record, 1);
        _sealWitness(address(executor), 2, 2, scope, oldHash, newHash);
        executor.execute(
            address(selection),
            abi.encodeCall(selection.lockSelection, (1, subject, record, 1)),
            scope,
            oldHash,
            newHash
        );
        _sealClear();
        return selection.selectionLock(1, subject);
    }

    function testRightsSealSafeBlocksBothWitnessRoutesAndSurvivesRevocation() public {
        _prepare();
        StreamRightsRecordTypes.Statement memory s = _statement();
        bytes32 first = _published(s);
        IStreamRightsRecordSelection.Selection memory original =
            selection.selectCurrent(1, subject, first, 0, 0, s);
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x653811;
        keys[1] = 0x653812;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 182);
        executor.setRoot(address(account));
        executor.setProposer(address(account));
        _sealGraph(address(core), address(executor));
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            selection.selectionLockTransition(1, subject, first, 1);
        bytes32 actionId = _sealWitness(address(executor), 2, 2, scope, oldHash, newHash);
        require(
            executeSafe(
                account,
                keys,
                address(executor),
                0,
                abi.encodeCall(
                    executor.execute,
                    (
                        address(selection),
                        abi.encodeCall(selection.lockSelection, (1, subject, first, 1)),
                        scope,
                        oldHash,
                        newHash
                    )
                ),
                0
            ),
            "actual threshold Safe invokes terminal rights seal"
        );
        _sealClear();
        IStreamRecordSelectionLock.SelectionLock memory saved = selection.selectionLock(1, subject);
        require(
            saved.locked && saved.recordHash == first
                && saved.selectionHash == original.selectionHash && saved.revision == 1
                && saved.actionId == actionId && saved.governanceRoot == address(account)
                && saved.executorCodeHash == address(executor).codehash && saved.lockHash != 0,
            "sealed original and root action are distinct authority facts"
        );
        s.predecessor = first;
        s.grants.print.status = StreamRightsRecordTypes.Status.DENIED;
        bytes32 later = _published(s);
        (IStreamPreservationRecords.CollectionRecord memory raw,) = metadata.collectionRecord(later);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRecordSelectionLock.RecordSelectionLocked.selector, uint256(1), subject
            )
        );
        selection.selectCurrent(1, subject, later, first, 1, s);
        IStreamRightsRecordWitnessSelection.Witness memory w =
            IStreamRightsRecordWitnessSelection.Witness(raw, s);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRecordSelectionLock.RecordSelectionLocked.selector, uint256(1), subject
            )
        );
        selection.selectCurrentWithRecord(1, subject, later, first, 1, w);
        _grant(1, StreamRecordFamilies.RIGHTS, 7, address(this), false);
        require(
            selection.requireCurrent(1, subject, first, 1).selectionHash == original.selectionHash,
            "original selection remains current after selecting grant revoked"
        );
        executor.setRoot(address(0x8878));
        vm.etch(address(metadata), hex"00");
        require(
            keccak256(abi.encode(selection.selectionLock(1, subject)))
                    == keccak256(abi.encode(saved))
                && keccak256(abi.encode(selection.rightsSelectionAt(1, subject, 1)))
                    == keccak256(abi.encode(original)),
            "immutable seal and raw history survive governance and dependency changes"
        );
    }

    function testRightsSealRejectsWrongGraphRootAndStaleHeadWithoutWrites() public {
        _prepare();
        StreamRightsRecordTypes.Statement memory s = _statement();
        bytes32 first = _published(s);
        selection.selectCurrent(1, subject, first, 0, 0, s);
        address registry = _sealGraph(address(core), address(executor));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRecordSelectionLock.RecordSelectionLockConflict.selector, uint256(1), subject
            )
        );
        selection.selectionLockTransition(1, subject, first, 2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRecordSelectionLock.RecordSelectionLockAuthorityRequired.selector
            )
        );
        selection.lockSelection(1, subject, first, 1);
        sealVm.mockCall(
            address(executor), abi.encodeWithSignature("owner()"), abi.encode(address(0x9898))
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRecordSelectionLock.RecordSelectionLockAuthorityRequired.selector
            )
        );
        selection.selectionLockTransition(1, subject, first, 1);
        _sealPointer(address(core), registry, address(executor), 1);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            selection.selectionLockTransition(1, subject, first, 1);
        executor.setRoot(address(0x9988));
        _sealPointer(address(core), registry, address(executor), 1);
        _sealWitness(address(executor), 2, 2, scope, oldHash, newHash);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRecordSelectionLock.RecordSelectionLockAuthorityRequired.selector
            )
        );
        executor.execute(
            address(selection),
            abi.encodeCall(selection.lockSelection, (1, subject, first, 1)),
            scope,
            oldHash,
            newHash
        );
        address wrong = address(new RecordSelectionModuleBoundary(address(0x9999)));
        _sealPointer(address(core), wrong, address(executor), 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRecordSelectionLock.RecordSelectionLockDependencyChanged.selector, wrong
            )
        );
        selection.selectionLockTransition(1, subject, first, 1);
        _sealClear();
        require(
            !selection.selectionLock(1, subject).locked
                && selection.currentRights(1, subject).recordHash == first,
            "all failed governance/graph reads leave original state unsealed"
        );
        require(_sealRights(first).locked, "same head can retry with current complete context");
    }

    function testRightsSealKeyIsolationKeepsOtherSubjectsMutable() public {
        _prepare();
        StreamRightsRecordTypes.Statement memory s = _statement();
        bytes32 first = _published(s);
        selection.selectCurrent(1, subject, first, 0, 0, s);
        _sealRights(first);
        bytes32 originalSubject = subject;
        core.setToken(1, address(this), 2);
        subject = metadata.registerTokenSubject(1);
        s = _statement();
        bytes32 tokenRecord = _published(s);
        selection.selectCurrent(1, subject, tokenRecord, 0, 0, s);
        require(
            !selection.selectionLock(1, subject).locked
                && selection.currentRights(1, subject).recordHash == tokenRecord
                && selection.selectionLock(1, originalSubject).recordHash == first
                && !selection.selectionLock(2, originalSubject).locked,
            "seal covers only original collection/subject key"
        );
    }
}
