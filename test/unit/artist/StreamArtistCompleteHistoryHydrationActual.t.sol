// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistCompleteHistoryHydrationFixture.sol";

/// @notice Actual guarded seven-owner operation60 after genuine55/56/57 and native source producers.
/// @dev Authored integration regressions for pending shared-route activation. Native execution
/// and gas acceptance remain pending; inherited Core/governance boundaries are unchanged.
contract StreamArtistCompleteHistoryHydrationActualTest is ArtistCompleteHistoryHydrationFixture {
    function testCompleteHistoryActualImportsPendingNewArtistUnboundAndOriginalRepudiation()
        external
    {
        CompleteRun memory run = _chRun();
        bytes32 source = _chSourceHash();
        uint256 nonce = artist.nonce();
        _chImport(run);
        require(
            artist.nonce() == nonce + 1 && _chSourceHash() == source,
            "one original Safe call source unchanged"
        );
    }

    function testCompleteHistoryActualLateArchiveRollsBackAllOwnersAndIdenticalSafeRetry()
        external
    {
        CompleteRun memory run = _chRun();
        bytes memory call_ =
            abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (run.request));
        bytes32 exactRequest = keccak256(call_);
        bytes32 before_ = _chDestinationHash(run);
        bytes32 source = _chSourceHash();
        uint256 nonce = artist.nonce();
        uint256 originalBlock = block.number;
        // This exact first page belongs to the saved operation60 commitment. Three reaches
        // prove direct failure, Safe failure and identical successful retry all enter Archive.
        chVm.expectCall(address(run.next.archive), _chFirstPage(run), 3);
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ArtistArchiveBlockNumberOverflow(uint256)", uint256(type(uint64).max) + 1
            )
        );
        Recovered(address(run.next.registry)).hydrateRecoveredArtistAuthority(run.request);
        require(
            _chDestinationHash(run) == before_,
            "late direct failure restores every owner and artifact"
        );
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(run.next.registry), call_);
        require(
            artist.nonce() == nonce && _chDestinationHash(run) == before_
                && _chSourceHash() == source,
            "Safe nonce and complete PC MD U state restore"
        );
        vm.roll(originalBlock);
        require(
            keccak256(call_) == exactRequest
                && this.executeTargetSafe(address(run.next.registry), call_),
            "byte-identical Safe retry"
        );
        require(
            artist.nonce() == nonce + 1 && _chSourceHash() == source,
            "only successful import consumes nonce"
        );
        _chAssert(run);
    }

    function testCompleteHistoryActualSourceCheckpointMismatchRejectsAndOriginalRequestRetries()
        external
    {
        CompleteRun memory run = _chRun();
        bytes32 before_ = _chDestinationHash(run);
        bytes32 request = keccak256(abi.encode(run.request));
        ++run.request.records.authority.expectedSource[1].ownerState.revision;
        avm.expectRevert(RH.InvalidRecoveredHydrationProvenance.selector);
        Recovered(address(run.next.registry)).hydrateRecoveredArtistAuthority(run.request);
        require(
            _chDestinationHash(run) == before_,
            "mismatched complete source certificate cannot partially import"
        );
        --run.request.records.authority.expectedSource[1].ownerState.revision;
        require(keccak256(abi.encode(run.request)) == request, "exact source request restored");
        _chImport(run);
    }

    function testCompleteHistoryActualCurrentRecheckRejectsCanonicalInventedCurrentState()
        external
    {
        CompleteRun memory run = _chRun();
        require(CHCurrent.recheck(run.prepared), "actual full source before writes");
        bytes memory saved = run.prepared.data[4].typedState;
        (RH.ExportHeader memory header, Payload.Payload memory payload) = Payload.decode(saved, 4);
        (M.State memory scope, bytes memory inventory) =
            CHCodec.decodeAuxiliary(4, payload.semanticState, payload.provenance);
        CHMD.Attribution memory changed = abi.decode(scope.rows[1], (CHMD.Attribution));
        require(changed.history.current.state == 1, "actual new B remains pending");
        changed.history.current.state = 2;
        changed.records.item.state = 2;
        scope.rows[1] = abi.encode(changed);
        payload.semanticState = CHCodec.encode(4, scope, payload.provenance, inventory);
        header.semanticInventory = keccak256(payload.semanticState);
        run.prepared.data[4].typedState = Payload.encode(4, header, payload);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHCurrent.recheck(run.prepared);
        run.prepared.data[4].typedState = saved;
        require(CHCurrent.recheck(run.prepared), "restored exact seven-owner recheck");
        _chImport(run);
    }
}
