// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistDelegationTypes as Delegation
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import "./ArtistRecoveredMultipleFixture.sol";
import {
    StreamArtistMultipleRecordsTypes as MR
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistMultipleRecordsHydration.sol";
import {
    StreamArtistRecoveredMultipleIdentityNonceImport as NonceImport
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleIdentityNonceImport.sol";

import {
    StreamArtistRecoveredMultipleConsentCodec as ConsentAggregate
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleConsentCodec.sol";

contract StreamArtistRecoveredMultipleActualTest is ArtistRecoveredMultipleFixture {
    function testRecoveredMultipleOneArtistTwoCollectionsDirect() external {
        _multiSource(true, false);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _multiPrepare(next);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(r);
        _multiAssert(next, p);
    }

    function testRecoveredMultipleTwoArtistsRetainRepeatedSecondaryHashAndOriginalPositions()
        external
    {
        _multiSource(false, false);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _multiPrepare(next);
        bytes32 secondary =
            ingress.identityRecoveryRecord(multiRecovery[0]).fields.supersededRecordsHash;
        require(
            secondary
                == ingress.identityRecoveryRecord(multiRecovery[1]).fields.supersededRecordsHash,
            "real repeated empty supersession hash"
        );
        uint256 count;
        for (uint256 i; i < p.admission.provenance.journals[2].length; ++i) {
            if (
                p.admission.provenance.journals[2][i].receipt.operation == 35
                    && p.admission.provenance.journals[2][i].receipt.recordHash == secondary
            ) ++count;
        }
        require(count == 2, "both original occurrences retained, never hash-deduplicated");
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(r);
        _multiAssert(next, p);
    }

    function testRecoveredMultipleMixedClassOneClassThreeSafe() external {
        _multiSource(false, true);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _multiPrepare(next);
        (RH.ExportHeader memory h,) = Payload.decode(p.data[2].typedState, 2);
        require(
            (h.requiredFeatures & (RH.CLASS_ONE | RH.CLASS_THREE))
                == (RH.CLASS_ONE | RH.CLASS_THREE),
            "authentic mixed recovered classes"
        );
        uint256 nonce = rotationSafe.nonce();
        require(
            this.rhExecuteNewSafe(
                address(next.registry),
                abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (r))
            ),
            "real threshold Safe aggregate call"
        );
        require(rotationSafe.nonce() == nonce + 1, "one Safe execution");
        _multiAssert(next, p);
    }

    function testRecoveredMultipleRepeatedImportKeepsFullOriginalOwnerCoordinates() external {
        _multiSource(false, false);
        Successor memory first = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _multiPrepare(first);
        Recovered(address(first.registry)).hydrateRecoveredArtistAuthority(r);
        _multiAssert(first, p);
        bytes32 oldIdentity = keccak256(abi.encode(p.admission.provenance.journals[2]));
        _rhAdopt(first);
        Successor memory second = _multiCutover();
        (r, p) = _multiPrepare(second);
        require(
            p.admission.provenance.eras.length == 2
                && keccak256(abi.encode(p.admission.provenance.journals[2])) == oldIdentity,
            "unchanged complete original native coordinates across era"
        );
        Recovered(address(second.registry)).hydrateRecoveredArtistAuthority(r);
        _multiAssert(second, p);
    }

    function testRecoveredMultipleLateArchiveFailureRollsBackAllOwnersAndSafeNonce() external {
        _multiSource(false, true);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _multiPrepare(next);
        bytes32 before_ = _multiDestinationHash(next);
        uint256 nonce = rotationSafe.nonce();
        uint256 originalBlock = block.number;
        bytes memory call_ = abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (r));
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ArtistArchiveBlockNumberOverflow(uint256)", uint256(type(uint64).max) + 1
            )
        );
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(r);
        require(
            _multiDestinationHash(next) == before_,
            "all global roots, imports and catalogs rollback"
        );
        vm.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(address(next.registry), call_);
        require(
            rotationSafe.nonce() == nonce && _multiDestinationHash(next) == before_,
            "Safe rollback includes all principals"
        );
        vm.roll(originalBlock);
        require(this.rhExecuteNewSafe(address(next.registry), call_), "identical aggregate retries");
        _multiAssert(next, p);
    }

    function testRecoveredMultipleRejectsOmittedArtistCollectionAndStaleInventory() external {
        _multiSource(false, false);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _multiPrepare(next);
        bytes32 before_ = _multiDestinationHash(next);
        bytes memory pristine = abi.encode(r);
        r.records.authority.artistIds = new bytes32[](1);
        r.records.authority.artistIds[0] = multiArtists[0];
        _badRequest(next, r);
        r = abi.decode(pristine, (RH.Request));
        r.records.authority.collections = new MH.Collection[](1);
        r.records.authority.collections[0] =
            MH.Collection(multiCollectionArtists[0], 1, new AH.PolicyKey[](0));
        _badRequest(next, r);
        r = abi.decode(pristine, (RH.Request));
        r.records.authority.collections[1] = r.records.authority.collections[0];
        _badRequest(next, r);
        r = abi.decode(pristine, (RH.Request));
        r.expectedSemanticInventory = bytes32(uint256(r.expectedSemanticInventory) ^ 1);
        _badRequest(next, r);
        require(_multiDestinationHash(next) == before_, "rejected partial graphs write no state");
        r = abi.decode(pristine, (RH.Request));
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(r);
        _multiAssert(next, p);
    }

    function testRecoveredMultipleRejectsWitnessFamiliesAndKeepsSingletonBoundary() external {
        _multiSource(true, false);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _multiPrepare(next);
        bytes memory pristine = abi.encode(r);
        r.records.witnesses = new MR.CollectionWitness[](1);
        _badRequest(next, r);
        r = abi.decode(pristine, (RH.Request));
        r.records.authority.collections = new MH.Collection[](1);
        r.records.authority.collections[0] = MH.Collection(artistId, 1, new AH.PolicyKey[](0));
        _badRequest(next, r);
        r = abi.decode(pristine, (RH.Request));
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(r);
        _multiAssert(next, p);
    }

    function testRecoveredMultipleNonceUnionRejectsMissingForeignDuplicateAndModifiedTree()
        external
    {
        _multiSource(false, false);
        Successor memory next = _multiCutover();
        (, Commit.Prepared memory p) = _multiPrepare(next);
        (, Payload.Payload memory payload) = Payload.decode(p.data[2].typedState, 2);
        M.State memory state = Aggregate.decode(2, payload.semanticState, payload.provenance);
        bytes memory pristine = abi.encode(state);
        IH.Bundle memory b = abi.decode(state.rows[0], (IH.Bundle));
        require(b.nonces.length > 0, "real consumed lanes");
        b.nonces = new IH.NonceLane[](0);
        state.rows[0] = abi.encode(b);
        _badUnion(state, payload.nonces);
        state = abi.decode(pristine, (M.State));
        b = abi.decode(state.rows[0], (IH.Bundle));
        b.nonces[0].key = keccak256("foreign lane");
        state.rows[0] = abi.encode(b);
        _badUnion(state, payload.nonces);
        state = abi.decode(pristine, (M.State));
        b = abi.decode(state.rows[0], (IH.Bundle));
        b.nonces[0].words[0].words[7] ^= 1;
        state.rows[0] = abi.encode(b);
        _badUnion(state, payload.nonces);
        state = abi.decode(pristine, (M.State));
        b = abi.decode(state.rows[0], (IH.Bundle));
        b.nonces[0].words[0].exhausted = !b.nonces[0].words[0].exhausted;
        state.rows[0] = abi.encode(b);
        _badUnion(state, payload.nonces);
        state = abi.decode(pristine, (M.State));
        state.rows[1] = state.rows[0];
        _badUnion(state, payload.nonces);
        state = abi.decode(pristine, (M.State));
        b = abi.decode(state.rows[0], (IH.Bundle));
        ++b.nextRegistrationNonce;
        state.rows[0] = abi.encode(b);
        _badUnion(state, payload.nonces);
        state = abi.decode(pristine, (M.State));
        b = abi.decode(state.rows[0], (IH.Bundle));
        b.timing.checkpoint.root = keccak256("different shared timing");
        state.rows[0] = abi.encode(b);
        _badUnion(state, payload.nonces);
        state = abi.decode(pristine, (M.State));
        IH.NonceLane[] memory good = Union.ordered(state, payload.nonces);
        ++good[0].hint;
        (bool ok,) = address(this).call(abi.encodeCall(this.checkNonceImport, (good)));
        require(!ok, "original tree importer rejects false hint");
        state = abi.decode(pristine, (M.State));
        Union.ordered(state, payload.nonces);
    }

    function testRecoveredMultipleRejectsAuthenticUnusedDelegationHistory() external {
        _multiSource(false, false);
        _adoptRotatedSafe();
        vm.warp(ingress.artistTransitionState(multiRecovery[1]).postWindowEndsAt);
        Delegation.Grant memory grant = Delegation.Grant(
            artistId,
            vm.addr(991099),
            uint256(2),
            uint32(2),
            uint64(block.timestamp),
            uint64(block.timestamp + 1 days),
            uint64(3),
            bytes32(0)
        );
        T.Authorization memory a = T.Authorization(nextNonce++, 0, "");
        bytes32 digest = ingress.delegationGrantDigest(grant, a);
        _rhAuthorization(digest, a.nonce);
        a.signature = _signature(digest);
        bytes32 record = ingress.grantArtistDelegation(grant, a);
        _rhCandidate(2, "identity_authority.replay.delegation_key", record);
        require(ingress.delegationRecord(record).uses == 0, "authentic retained unused grant");
        Successor memory next = _multiCutover();
        RH.Request memory r = _multiRequest();
        bytes32 before_ = _multiDestinationHash(next);
        Commit.Prepared memory p = Prepared.prepare(next.coordinator.suiteConfiguration(), r);
        (, Payload.Payload memory payload) = Payload.decode(p.data[2].typedState, 2);
        M.State memory state = ConsentAggregate.decode(2, payload.semanticState, payload.provenance);
        bool checked;
        for (uint256 i; i < state.rows.length; ++i) {
            IH.Bundle memory b = abi.decode(state.rows[i], (IH.Bundle));
            if (b.artistId != artistId) continue;
            (bool ok, bytes memory reason) =
                address(Union).staticcall(abi.encodeWithSelector(Union.validateLocal.selector, b));
            require(
                !ok && bytes4(reason) == RH.InvalidRecoveredHydrationProvenance.selector,
                "old base local profile remains strict for authentic unused grant"
            );
            checked = true;
        }
        require(
            checked && _multiDestinationHash(next) == before_,
            "new profile preparation is read only; old base stays strict"
        );
    }

    function prepareMultiple(T.SuiteConfiguration memory target, RH.Request memory request)
        external
        view
    {
        Prepared.prepare(target, request);
    }

    function checkUnion(M.State memory state, RH.NonceInventory[] memory inventory) external pure {
        Union.ordered(state, inventory);
    }

    function checkNonceImport(IH.NonceLane[] memory rows) external {
        require(msg.sender == address(this), "test-only scratch importer");
        uint256[17] memory roots;
        for (uint256 i; i < 17; ++i) {
            roots[i] = 1000 + i;
        }
        NonceImport.install(roots, rows);
    }

    function _badUnion(M.State memory state, RH.NonceInventory[] memory inventory) private {
        (bool ok,) = address(this).call(abi.encodeCall(this.checkUnion, (state, inventory)));
        require(!ok, "invalid complete nonce union rejected");
    }

    function _badRequest(Successor memory next, RH.Request memory r) private {
        (bool ok,) = address(next.registry)
            .call(abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (r)));
        require(!ok, "incomplete aggregate rejected");
    }
}
