// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamWorkSelectionFixture.sol";
import "../../helpers/RecordSelectionLockFixture.sol";

contract StreamWorkRecordSelectionLockTest is WorkSelectionFixture, RecordSelectionLockFixture {
    function _sealWork(bytes32 record)
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

    function testWorkSealSafePreservesOriginalAndBlocksBothWriters() public ready {
        _bound(1, BINDING, 2);
        StreamWorkRecordTypes.Description memory d = _artistDescription();
        bytes32 first = _curatorPublish(d);
        IStreamWorkRecordSelection.Selection memory original =
            selection.selectCurrent(1, subject, first, 0, 0, _witness(first, d));
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x653801;
        keys[1] = 0x653802;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 181);
        executor.setRoot(address(account));
        executor.setProposer(address(account));
        _sealGraph(address(core), address(executor));
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            selection.selectionLockTransition(1, subject, first, 1);
        bytes32 actionId = _sealWitness(address(executor), 2, 2, scope, oldHash, newHash);
        vm.recordLogs();
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
            "actual threshold Safe invokes terminal-bound selector seal"
        );
        IStreamRecordSelectionLock.SelectionLock memory saved = selection.selectionLock(1, subject);
        require(
            saved.locked && saved.recordHash == first && saved.revision == 1
                && saved.selectionHash == original.selectionHash
                && saved.executor == address(executor) && saved.actionId == actionId
                && saved.governanceRoot == address(account) && saved.scopeHash == scope
                && saved.oldValueHash == oldHash && saved.newValueHash == newHash,
            "original selection and distinct terminal seal authority"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 events;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(selection)) {
                ++events;
                require(
                    logs[i].topics.length == 4 && logs[i].topics[1] == bytes32(uint256(1))
                        && logs[i].topics[2] == subject && logs[i].topics[3] == first
                        && keccak256(logs[i].data) == keccak256(abi.encode(saved)),
                    "complete seal event"
                );
            }
        }
        require(events == 1, "one selector seal event");
        bytes32 lockHash = saved.lockHash;
        saved.lockHash = 0;
        require(
            lockHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_RECORD_SELECTION_LOCK_RECORD_V1"),
                        block.chainid,
                        address(selection),
                        address(core),
                        address(metadata),
                        keccak256("WORK_DESCRIPTION"),
                        uint256(1),
                        subject,
                        saved
                    )
                ),
            "independent full seal commitment"
        );
        _sealClear();
        d.predecessor = first;
        d.full.title = "Later dossier";
        bytes32 later = _curatorPublish(d);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRecordSelectionLock.RecordSelectionLocked.selector, uint256(1), subject
            )
        );
        selection.selectCurrent(1, subject, later, first, 1, _witness(later, d));
        StreamWorkRecordTypes.Description memory artistWork = _artistDescription();
        artistWork.predecessor = first;
        (bytes32 artistRecord,) = _artistPublish(artistWork);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRecordSelectionLock.RecordSelectionLocked.selector, uint256(1), subject
            )
        );
        selection.adoptArtistRecord(
            1, subject, artistRecord, first, 1, _witness(artistRecord, artistWork)
        );
        _grant(1, StreamRecordFamilies.CURATOR, 3, address(this), false);
        require(
            selection.requireCurrent(1, subject, first, 1).selectionHash == original.selectionHash
                && selection.selectionLock(1, subject).lockHash == lockHash,
            "revoked selector grant cannot unseal"
        );
        executor.setRoot(address(0x8877));
        vm.etch(address(metadata), hex"00");
        require(
            selection.selectionLock(1, subject).lockHash == lockHash
                && keccak256(abi.encode(selection.currentWork(1, subject)))
                    == keccak256(abi.encode(original)),
            "seal and original raw history survive current dependency outage"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRecordSelectionLock.RecordSelectionLocked.selector, uint256(1), subject
            )
        );
        selection.lockSelection(1, subject, first, 1);
    }

    function testWorkSealRejectsStaleUnauthorizedAndWrongGovernanceThenRetries() public ready {
        StreamWorkRecordTypes.Description memory d = _named();
        bytes32 first = _curatorPublish(d);
        selection.selectCurrent(1, subject, first, 0, 0, _witness(first, d));
        address registry = _sealGraph(address(core), address(executor));
        for (uint256 i; i < 2; ++i) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamRecordSelectionLock.RecordSelectionLockConflict.selector,
                    uint256(1),
                    subject
                )
            );
            selection.selectionLockTransition(
                1, subject, i == 0 ? bytes32(uint256(123)) : first, i == 0 ? 1 : 2
            );
        }
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            selection.selectionLockTransition(1, subject, first, 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRecordSelectionLock.RecordSelectionLockAuthorityRequired.selector
            )
        );
        selection.lockSelection(1, subject, first, 1);
        for (uint256 i; i < 3; ++i) {
            _sealWitness(
                address(executor),
                i == 0 ? 1 : 2,
                i == 1 ? 1 : 2,
                scope,
                i == 2 ? bytes32(uint256(456)) : oldHash,
                newHash
            );
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
            require(
                !selection.selectionLock(1, subject).locked,
                "failed terminal witness has no lock write"
            );
        }
        _sealPointer(address(core), registry, address(executor), 2);
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
        _sealClear();
        require(_sealWork(first).locked, "same exact original seals after failed witnesses");
    }

    function testWorkSealIsLocalAndGenericDossiersStayAppendable() public ready {
        StreamWorkRecordTypes.Description memory d = _named();
        bytes32 first = _curatorPublish(d);
        selection.selectCurrent(1, subject, first, 0, 0, _witness(first, d));
        _sealWork(first);
        bytes32 oldSubject = subject;
        core.setToken(1, address(this), 2);
        subject = metadata.registerTokenSubject(1);
        d = _named();
        bytes32 tokenRecord = _curatorPublish(d);
        selection.selectCurrent(1, subject, tokenRecord, 0, 0, _witness(tokenRecord, d));
        require(
            !selection.selectionLock(1, subject).locked
                && selection.currentWork(1, subject).recordHash == tokenRecord
                && selection.selectionLock(1, oldSubject).recordHash == first
                && !selection.selectionLock(2, oldSubject).locked,
            "one subject seal cannot lock other selected keys"
        );
    }
}
