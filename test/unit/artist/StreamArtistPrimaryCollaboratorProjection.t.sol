// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPrimaryCollaboratorSourceProof as Source
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorSourceProof.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as Clocks
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorClocks.sol";
import {
    StreamArtistPrimaryCollaboratorSourceResultClocks as ClockProjection
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorSourceResultClocks.sol";
import {
    StreamArtistPrimaryCollaboratorEnvelopeProjection as Envelope
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorEnvelopeProjection.sol";
import {
    StreamArtistPrimaryCollaboratorAttributionRows as Rows
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorAttributionRows.sol";
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

interface PrimaryProjectionVm {
    function expectRevert() external;
    function expectRevert(bytes calldata) external;
}

/// @notice Actual fixed projections with independently assembled canonical typed values.
/// These cases do not authenticate source admission or replace full producer/currentness tests.
contract StreamArtistPrimaryCollaboratorProjectionTest {
    PrimaryProjectionVm private constant vm =
        PrimaryProjectionVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _clocks() private pure returns (Source.Result memory s) {
        s.clocks.clocks.counts = new uint256[](2);
        s.clocks.clocks.counts[0] = 7;
        s.clocks.clocks.counts[1] = 11;
        s.clocks.primary = new PC.PrimaryReceipt[](1);
        s.clocks.primary[0] = PC.PrimaryReceipt(
            15, 2, keccak256("binding"), keccak256("record"), RH.Point(keccak256("era"), 3, 99), 17
        );
        s.clocks.finalPrimary = new bytes32[][](1);
        s.clocks.finalPrimary[0] = new bytes32[](2);
        s.clocks.finalPrimary[0][0] = keccak256("first");
        s.clocks.finalPrimary[0][1] = keccak256("second");
        s.clocks.accepted = new uint32[][](1);
        s.clocks.accepted[0] = new uint32[](2);
        s.clocks.accepted[0][0] = 3;
        s.clocks.accepted[0][1] = 5;
        s.generations.generations = new A.Generation[][](1);
        s.generations.generations[0] = new A.Generation[](1);
        s.generations.generations[0][0] = A.Generation(
            keccak256("other complete generation"), 7, true, RH.Point(keccak256("other era"), 0, 51)
        );
    }

    function testAllClockArraysAndOriginalCoordinatesRemainExact() public pure {
        Source.Result memory s = _clocks();
        Clocks.Result memory r = ClockProjection.decode(abi.encode(s));
        require(
            keccak256(abi.encode(r)) == keccak256(abi.encode(s.clocks)), "complete clocks tuple"
        );
        require(
            r.clocks.counts[0] == 7 && r.clocks.counts[1] == 11 && r.primary[0].operationIndex == 17
                && r.primary[0].point.ownerRevision == 99,
            "literal original coordinates"
        );
        require(
            r.finalPrimary[0][0] == keccak256("first")
                && r.finalPrimary[0][1] == keccak256("second") && r.accepted[0][0] == 3
                && r.accepted[0][1] == 5,
            "ordered rows"
        );
        s.generations.generations[0][0].generation++;
        require(
            keccak256(abi.encode(ClockProjection.decode(abi.encode(s))))
                == keccak256(abi.encode(r)),
            "separate full inventory does not rewrite clocks projection"
        );
    }

    function clocks(bytes calldata raw) external pure {
        ClockProjection.decode(raw);
    }

    function testClockOuterBoundsRejectAndOriginalBytesRestore() public {
        bytes memory raw = abi.encode(_clocks());
        bytes memory malformed = bytes.concat(raw);
        assembly ("memory-safe") { mstore(add(malformed, 32), 64) }
        vm.expectRevert();
        this.clocks(malformed);
        vm.expectRevert();
        this.clocks(hex"00");
        this.clocks(raw);
    }

    function testOriginalPayloadProvenanceProjectionRetainsFullOwnerRows() public pure {
        Payload.Payload memory p;
        p.provenance.origins = new RH.OriginEnvironment[](1);
        p.provenance.origins[0].chainId = 6529;
        p.provenance.origins[0].owners[6] = address(0x1234);
        p.provenance.eras = new RH.OwnerEra[](1);
        p.provenance.eras[0].nativeCount = 17;
        p.nonces = new RH.NonceInventory[](1);
        p.nonces[0].words = new AH.NonceWord[](1);
        p.nonces[0].words[0].prefix = 31;
        p.nonces[0].words[0].words[31] = type(uint256).max;
        p.semanticState = hex"00aabbff";
        RH.OwnerProvenance memory actual = Envelope.provenance(abi.encode(p));
        require(
            keccak256(abi.encode(actual)) == keccak256(abi.encode(p.provenance)),
            "every original owner field"
        );
        require(
            actual.origins[0].chainId == 6529 && actual.origins[0].owners[6] == address(0x1234)
                && actual.eras[0].nativeCount == 17,
            "literal owner fields"
        );
    }

    function rows(M.State calldata s) external pure {
        Rows.project(s);
    }

    function testCanonicalAttributionHistoryAndRecordBytesStayDistinct() public pure {
        M.State memory s;
        s.rows = new bytes[](2);
        G.Attribution memory a;
        a.history.artistId = keccak256("artist1");
        a.history.collectionId = 17;
        a.history.bindingHash = keccak256("binding1");
        s.rows[0] = abi.encode(a);
        G.Attribution memory b;
        b.history.artistId = keccak256("artist2");
        b.history.collectionId = 23;
        b.history.bindingHash = keccak256("binding2");
        s.rows[1] = abi.encode(b);
        Rows.Result memory r = Rows.project(s);
        require(
            r.histories.length == 2 && r.rows.length == 2 && r.histories[0].collectionId == 17
                && r.histories[1].collectionId == 23,
            "ordered complete histories"
        );
        require(
            keccak256(abi.encode(r.histories[0])) == keccak256(abi.encode(a.history))
                && keccak256(r.rows[0]) == keccak256(abi.encode(a.records)),
            "exact first full fields"
        );
        require(
            keccak256(abi.encode(r.histories[1])) == keccak256(abi.encode(b.history))
                && keccak256(r.rows[1]) == keccak256(abi.encode(b.records)),
            "exact second full fields"
        );
    }

    function testAttributionTrailingBytesRejectExactErrorThenRestore() public {
        M.State memory s;
        s.rows = new bytes[](1);
        G.Attribution memory a;
        a.history.collectionId = 17;
        bytes memory canonical = abi.encode(a);
        s.rows[0] = bytes.concat(canonical, bytes32(0));
        vm.expectRevert(abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector));
        this.rows(s);
        s.rows[0] = canonical;
        this.rows(s);
    }
}
