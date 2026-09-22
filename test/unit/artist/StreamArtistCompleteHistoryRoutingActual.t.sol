// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistUnboundPlatformFixture.sol";

/// @notice Original producer and seven-owner Safe routing for previously unsupported all-U history.
/// @dev Inherited Core, coverage and scheduled-governance boundaries remain explicit.
/// These authored regressions require native execution; they do not establish whole-stack gas.
contract StreamArtistCompleteHistoryRoutingActualTest is ArtistUnboundPlatformFixture {
    function testCompleteRoutingImportsUndeclaredAllegationThroughSevenOwnersAndSafe() external {
        bytes32 original = _hpClaim(true);
        require(ingress.platformWorksState(upCollection).declaration.recordHash == 0);
        _rhCandidate(2, "identity_authority.replay.one_way_cutover_latch", 0);
        Successor memory next = _upCutover();
        (RH.Request memory request, Commit.Prepared memory prepared) = _completePrepare(next);
        require(prepared.admission.artists.length == 0, "no invented principal");
        require(prepared.admission.provenance.journals[4].length == 1);
        require(prepared.admission.provenance.journals[4][0].receipt.recordHash == original);
        _upImport(next, request, prepared);
    }

    function testCompleteRoutingLateArchiveFailureRollsBackAndSameSafeCallRetries() external {
        _hpClaim(true);
        _rhCandidate(2, "identity_authority.replay.one_way_cutover_latch", 0);
        Successor memory next = _upCutover();
        (RH.Request memory request, Commit.Prepared memory prepared) = _completePrepare(next);
        bytes memory call_ = abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (request));
        uint256 nonce = artist.nonce();
        bytes32 before_ = _rhDestinationHash(next);
        bytes32 sourceBefore = _completeSourceHash();
        UnboundTestVM(address(avm))
            .expectCall(
                next.coordinator.suiteConfiguration().owners[6],
                abi.encodeWithSelector(HydrationOwner.applyArtistAuthorityHydration.selector),
                2
            );
        uint256 height = block.number;
        vm.roll(uint256(type(uint64).max) + 1);
        (bool ok,) = address(this)
            .call(abi.encodeCall(this.executeTargetSafe, (address(next.registry), call_)));
        require(!ok && artist.nonce() == nonce, "failed operation and Safe nonce rollback");
        require(_rhDestinationHash(next) == before_, "all destination state rolls back");
        require(_completeSourceHash() == sourceBefore, "source remains unchanged");
        vm.roll(height);
        require(this.executeTargetSafe(address(next.registry), call_), "same payload retry");
        require(artist.nonce() == nonce + 1);
        _upAssert(next, prepared, HydrationOwner(next.identity).authorityHydrationCommitment());
    }

    function testCompleteRoutingRepeatedImportRetainsOriginalAndFreshAllegations() external {
        _hpClaim(true);
        _rhCandidate(2, "identity_authority.replay.one_way_cutover_latch", 0);
        Successor memory middle = _upCutover();
        (RH.Request memory request, Commit.Prepared memory first) = _completePrepare(middle);
        bytes32 commitment = _upImport(middle, request, first);
        _upAdopt(middle);
        bytes32 fresh = _hpClaim(true);
        Successor memory last = _upCutover();
        Commit.Prepared memory second;
        (request, second) = _completePrepare(last);
        require(request.expectedSourceImportCommitment == commitment);
        require(second.admission.provenance.eras.length == 2);
        RH.JournalEntry[] memory earlier = first.admission.provenance.journals[4];
        RH.JournalEntry[] memory later = second.admission.provenance.journals[4];
        require(later.length == earlier.length + 1);
        for (uint256 i; i < earlier.length; ++i) {
            require(keccak256(abi.encode(earlier[i])) == keccak256(abi.encode(later[i])));
        }
        require(later[later.length - 1].receipt.recordHash == fresh);
        require(later[later.length - 1].position.nativeIndex == 0);
        _upImport(last, request, second);
    }

    function testCompleteRoutingLeavesOriginalDeclaredUnboundProfileSelected() external {
        _upSource(false);
        Successor memory next = _upCutover();
        (RH.Request memory request, Commit.Prepared memory prepared) = _upPrepare(next);
        _upImport(next, request, prepared);
    }

    function _completePrepare(Successor memory next)
        private
        view
        returns (RH.Request memory request, Commit.Prepared memory prepared)
    {
        request = _upRequest();
        prepared = Prepared.prepare(next.coordinator.suiteConfiguration(), request);
        request.expectedSemanticInventory = Prepared.inventory(prepared);
        uint256 features = uint256(33554432) | RH.HISTORY_PLATFORM;
        if (prepared.admission.provenance.eras.length > 1) features |= RH.REPEATED_IMPORT;
        for (uint8 owner; owner < 7; ++owner) {
            (RH.ExportHeader memory header, Payload.Payload memory payload) =
                Payload.decode(prepared.data[owner].typedState, owner);
            require(header.requiredFeatures == features);
            (bytes32 tag, uint16 version, uint8 encodedOwner,,) =
                abi.decode(payload.semanticState, (bytes32, uint16, uint8, M.State, bytes));
            require(tag == keccak256("6529STREAM_ARTIST_COMPLETE_HISTORY_V1"));
            require(version == 1 && encodedOwner == owner);
        }
    }

    function _completeSourceHash() private view returns (bytes32) {
        T.Snapshot[7] memory states;
        for (uint8 owner; owner < 7; ++owner) {
            states[owner] = Owner(suite.owners[owner]).ownerStateSnapshotV2();
        }
        return keccak256(abi.encode(states, Reconstruction(suite.archive).storedPayloadCount()));
    }
}
