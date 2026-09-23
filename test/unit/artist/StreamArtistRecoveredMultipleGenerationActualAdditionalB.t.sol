// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistRecoveredMultipleGenerationActualFixture.sol";

contract StreamArtistRecoveredMultipleGenerationActualAdditionalBTest is ArtistRecoveredMultipleGenerationActualFixture {
    function testGenerationAggregateCompleteHeadersAndEconomicsWitnessRestore() external {
        _mgSource(true);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mgPrepare(next);
        bytes memory saved = abi.encode(r);
        for (uint256 i; i < 7; ++i) {
            r = abi.decode(saved, (RH.Request));
            ++r.records.authority.expectedSource[i].ownerState.revision;
            _mgBad(next, r);
        }
        r = abi.decode(saved, (RH.Request));
        r.records.witnesses[0].economics = new T.EconomicsConsent[](1);
        r.records.witnesses[0].economics[0] = mgEconomics[0];
        _mgBad(next, r);
        r = abi.decode(saved, (RH.Request));
        r.records.witnesses[0].economics[1].assignmentHash = keccak256("foreign continuation terms");
        _mgBad(next, r);
        _mgImport(next, abi.decode(saved, (RH.Request)), p, true);
    }

    function testGenerationAggregateAcceptedRefusedWithdrawnThenAcceptedGenerationFour() external {
        _multiSource(true, false);
        leavePending = true;
        _mgCorrect(1);
        L.Termination memory termination = _termination(1);
        T.Authorization memory authorization = _authorization(false);
        bytes32 digest = ingress.bindingRefusalDigest(termination, authorization);
        authorization.signature = _signature(digest);
        bytes32 refused = ingress.refuseArtistBinding(termination, authorization);
        _mcRemember(refused, digest, authorization, false);
        _rhCandidate(
            0,
            "binding_lifecycle.replay.refusal_uniqueness",
            keccak256(abi.encode(uint256(1), uint64(2)))
        );
        _mgRepropose(1);
        termination = _termination(1);
        ingress.withdrawArtistBinding(termination);
        _rhCandidate(
            0,
            "binding_lifecycle.replay.proposal_terminal_transition_key",
            keccak256(abi.encode(uint256(1), uint64(3)))
        );
        _mgRepropose(1);
        _mgAccept(1);
        _maCredential(1, 0, 0, 0, true);
        require(
            Binding(suite.owners[0]).binding(1).generation == 4
                && Lifecycle(suite.owners[0]).bindingTermination(1, 2).kind == 1
                && Lifecycle(suite.owners[0]).bindingTermination(1, 3).kind == 2,
            "original accepted/refusal/withdrawal/final acceptance combination"
        );
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory prepared) = _mgPrepare(next);
        _mgImport(next, r, prepared, true);
    }

    function testGenerationAggregateTwoArtistsKeepIndependentSameDelegateNonce() external {
        _multiSource(false, false);
        _adoptRotatedSafe();
        vm.warp(ingress.artistTransitionState(multiRecovery[1]).postWindowEndsAt);
        uint256[] memory secondKeys = keys;
        artistId = multiCollectionArtists[0];
        artist = OfficialSafe(multiAuthorities[0]);
        keys = new uint256[](2);
        keys[0] = 0xCA1100 + 36001;
        keys[1] = 0xCA2200 + 36001;
        nextNonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        _mgCorrect(1);
        bytes32 first = _mcGrant(1);
        _maCredential(1, 0, first, 77, false);
        artistId = multiCollectionArtists[1];
        artist = OfficialSafe(multiAuthorities[1]);
        keys = secondKeys;
        nextNonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        _mgCorrect(2);
        bytes32 second = _mcGrant(1);
        _maCredential(2, 0, second, 77, false);
        require(first != second, "independent authentic Artist grants");
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory prepared) = _mgPrepare(next);
        _mgImport(next, r, prepared, false);
        for (uint256 k; k < 2; ++k) {
            (bool used,) = next.registry
            .delegatedNonceState(multiCollectionArtists[k], address(delegateSafe), 77);
            require(
                used && next.registry.delegationRecord(mcGrants[k]).uses == 1,
                "full distinct nonce lanes and counters"
            );
        }
    }

}
