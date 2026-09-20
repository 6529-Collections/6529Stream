// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredRecordWitnesses as Witnesses
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredRecordWitnesses.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistMultipleRecordsTypes as MR
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistMultipleRecordsHydration.sol";
import {
    StreamArtistReadinessHydrationTypes as AH24
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Synthetic selector controls, not provenance, attestation authorization or op60 execution.
/// @dev The real collector validates the full source certificate before this family-count gate,
/// then each typed worker joins the original terms and order. These tests cover only the gate.
contract StreamArtistRecoveredRecordWitnessesTest {
    function check(
        T.SuiteConfiguration memory source,
        RH.Provenance memory p,
        AH.Query memory q,
        MR.CollectionWitness[] memory w
    ) external pure returns (MR.CollectionWitness memory) {
        return Witnesses.collect(source, p, q, w);
    }

    function testNoRecordHistoryPreservesEmptyWitnessRequestAndRejectsInventedFamily()
        external
        view
    {
        (
            T.SuiteConfiguration memory s,
            RH.Provenance memory p,
            AH.Query memory q,
            MR.CollectionWitness[] memory w
        ) = _fixture(0, 0);
        MR.CollectionWitness memory out = Witnesses.collect(s, p, q, w);
        assert(out.economics.length == 0 && out.attestations.length == 0);
        w = new MR.CollectionWitness[](1);
        w[0].collectionId = q.collectionId;
        _reject(s, p, q, w);
        w[0].attestations = new AH24.AttestationInput[](1);
        _reject(s, p, q, w);
    }

    function testPureEconomicsAndPureAttestationsRetainExactOrderedWitnessBytes() external pure {
        for (uint256 i; i < 2; ++i) {
            (
                T.SuiteConfiguration memory s,
                RH.Provenance memory p,
                AH.Query memory q,
                MR.CollectionWitness[] memory w
            ) = _fixture(i == 0 ? 2 : 0, i == 1 ? 3 : 0);
            MR.CollectionWitness memory out = Witnesses.collect(s, p, q, w);
            assert(keccak256(abi.encode(out)) == keccak256(abi.encode(w[0])));
        }
    }

    function testMixedWitnessFamiliesArePreservedTogether() external pure {
        (
            T.SuiteConfiguration memory s,
            RH.Provenance memory p,
            AH.Query memory q,
            MR.CollectionWitness[] memory w
        ) = _fixture(2, 3);
        MR.CollectionWitness memory out = Witnesses.collect(s, p, q, w);
        assert(keccak256(abi.encode(out)) == keccak256(abi.encode(w[0])));
        assert(out.economics[0].resolver == s.primaryResolver);
        assert(out.economics[1].resolver == s.royaltyResolver);
        assert(out.attestations[0].nonce == 7 && out.attestations[2].nonce == 9);
    }

    function testMissingOrExtraFamilyWitnessRejectsAfterValidMixedBaseline() external view {
        for (uint256 variant; variant < 4; ++variant) {
            (
                T.SuiteConfiguration memory s,
                RH.Provenance memory p,
                AH.Query memory q,
                MR.CollectionWitness[] memory w
            ) = _fixture(2, 3);
            Witnesses.collect(s, p, q, w);
            if (variant == 0) w[0].economics = new T.EconomicsConsent[](1);
            if (variant == 1) w[0].economics = new T.EconomicsConsent[](3);
            if (variant == 2) w[0].attestations = new AH24.AttestationInput[](2);
            if (variant == 3) w[0].attestations = new AH24.AttestationInput[](4);
            _reject(s, p, q, w);
        }
    }

    function testWrongCollectionDuplicateCollectionAndEmptyCollectionReject() external view {
        (
            T.SuiteConfiguration memory s,
            RH.Provenance memory p,
            AH.Query memory q,
            MR.CollectionWitness[] memory w
        ) = _fixture(0, 2);
        Witnesses.collect(s, p, q, w);
        ++w[0].collectionId;
        _reject(s, p, q, w);
        w[0].collectionId = q.collectionId;
        MR.CollectionWitness[] memory duplicate = new MR.CollectionWitness[](2);
        duplicate[0] = w[0];
        duplicate[1] = w[0];
        _reject(s, p, q, duplicate);
        _reject(s, p, q, new MR.CollectionWitness[](0));
        q.collectionId = 0;
        w[0].collectionId = 0;
        _reject(s, p, q, w);
    }

    function testForeignEconomicsResolverCannotRideAnAttestationRequest() external view {
        (
            T.SuiteConfiguration memory s,
            RH.Provenance memory p,
            AH.Query memory q,
            MR.CollectionWitness[] memory w
        ) = _fixture(2, 3);
        Witnesses.collect(s, p, q, w);
        w[0].economics[1].resolver = address(0xBAD);
        _reject(s, p, q, w);
    }

    function testEachFamilyBoundIsIndependent() external view {
        (
            T.SuiteConfiguration memory s,
            RH.Provenance memory p,
            AH.Query memory q,
            MR.CollectionWitness[] memory w
        ) = _fixture(128, 128);
        Witnesses.collect(s, p, q, w);
        (s, p, q, w) = _fixture(129, 1);
        _reject(s, p, q, w);
        (s, p, q, w) = _fixture(1, 129);
        _reject(s, p, q, w);
    }

    function _reject(
        T.SuiteConfiguration memory s,
        RH.Provenance memory p,
        AH.Query memory q,
        MR.CollectionWitness[] memory w
    ) private view {
        (bool ok, bytes memory reason) =
            address(this).staticcall(abi.encodeCall(this.check, (s, p, q, w)));
        assert(!ok);
        assert(
            keccak256(reason) == keccak256(abi.encodeWithSelector(T.UnsupportedProfile.selector))
        );
    }

    function _fixture(uint256 economics, uint256 attestations)
        private
        pure
        returns (
            T.SuiteConfiguration memory s,
            RH.Provenance memory p,
            AH.Query memory q,
            MR.CollectionWitness[] memory w
        )
    {
        s.primaryResolver = address(0x111);
        s.royaltyResolver = address(0x222);
        q.artistId = keccak256("synthetic artist");
        q.collectionId = 42;
        q.bindingHash = keccak256("synthetic binding");
        // Other operation families are not counted as terms; their own fixed codec
        // accepts or rejects them after the complete source admission boundary.
        p.journals[6] = new RH.JournalEntry[](economics + 2);
        p.journals[6][0].receipt.operation = 14;
        p.journals[6][economics + 1].receipt.operation = 16;
        for (uint256 i; i < economics; ++i) {
            p.journals[6][i + 1].receipt.operation = 15;
        }
        p.journals[4] = new RH.JournalEntry[](attestations);
        for (uint256 i; i < attestations; ++i) {
            p.journals[4][i].receipt.operation = 24;
        }
        if (economics + attestations == 0) return (s, p, q, new MR.CollectionWitness[](0));
        w = new MR.CollectionWitness[](1);
        w[0].collectionId = q.collectionId;
        w[0].economics = new T.EconomicsConsent[](economics);
        w[0].attestations = new AH24.AttestationInput[](attestations);
        for (uint256 i; i < economics; ++i) {
            w[0].economics[i].resolver = i % 2 == 0 ? s.primaryResolver : s.royaltyResolver;
            w[0].economics[i].assignmentHash = bytes32(i + 1);
        }
        for (uint256 i; i < attestations; ++i) {
            w[0].attestations[i].nonce = i + 7;
            w[0].attestations[i].terms.collectionId = q.collectionId;
            w[0].attestations[i].terms.statementURI = "urn:synthetic:selector";
        }
    }
}
