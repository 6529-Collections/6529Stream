// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPrimaryCollaboratorTypes as G
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorProofCanonical as Canonical
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorProofCanonical.sol";
import {
    StreamArtistPrimaryCollaboratorProofDecode as Validation
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorProofDecode.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredBindingGenerations as OriginalBinding
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredPlatformTypes as P
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

interface PrimaryProofVm {
    function expectRevert() external;
    function expectRevert(bytes calldata) external;
}

/// @notice Actual canonical workers; these typed bytes are codec fixtures, not source-authorized histories.
contract StreamArtistPrimaryCollaboratorProofCodecTest {
    PrimaryProofVm private constant vm =
        PrimaryProofVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _fixture() private pure returns (G.Proof memory p) {
        p.provenance.origins = new RH.OriginEnvironment[](1);
        p.provenance.origins[0].chainId = 6529;
        p.provenance.eras = new RH.Era[](1);
        p.provenance.eras[0].originHash = keccak256("complete era");
        p.bindings.bindings = new CB.Bundle[](1);
        p.bindings.bindings[0].bindings.artistId = keccak256("Artist");
        p.bindings.bindings[0].bindings.collectionId = 17;
        p.bindings.bindings[0].bindings.current.artistAddress = address(0x1234);
        p.bindings.bindings[0].bindings.current.accepted = true;
        p.bindings.bindings[0].bindings.rows = new OriginalBinding.Row[](1);
        p.bindings.bindings[0].bindings.rows[0].item.generation = 2;
        p.bindings.generations = new A.Generation[][](1);
        p.bindings.generations[0] = new A.Generation[](1);
        p.bindings.generations[0][0] =
            A.Generation(keccak256("binding"), 2, true, RH.Point(keccak256("era"), 0, 12));
        p.bindings.collaborators = new T.CollaboratorRecord[][][](1);
        p.bindings.collaborators[0] = new T.CollaboratorRecord[][](1);
        p.bindings.collaborators[0][0] = new T.CollaboratorRecord[](1);
        p.bindings.collaborators[0][0][0].account = address(0xBEEF);
        p.archive.catalogues = new P.Catalogue[](1);
        p.archive.catalogues[0].rowsHash = keccak256("complete catalogue");
        p.archive.operations = new H.OperationEvidence[](1);
        p.archive.operations[0].operation = 7;
        p.archive.proposals = new G.Proposal[](1);
        p.archive.proposals[0].identityOperationPlusOne = 5;
        p.archive.accepted = new G.AcceptedRow[](1);
        p.archive.accepted[0].operationIndex = 3;
        p.accepted = new A.AcceptanceBundle[](1);
        p.accepted[0].rows = new A.Acceptance[](1);
        p.accepted[0].rows[0] =
            A.Acceptance(keccak256("accepted binding"), 1, keccak256("original op2"), 137);
        p.accounts = new IH.NonceLane[](1);
        p.accounts[0].kind = 3;
        p.accounts[0].key = keccak256("global account");
        p.accounts[0].words = new AH.NonceWord[](1);
        p.accounts[0].words[0].prefix = 7;
        p.accounts[0].words[0].words[0] = uint256(1) << 19;
    }

    function _check(G.Proof memory p) private view {
        bytes memory raw = abi.encode(p);
        require(
            keccak256(Canonical.canonical(raw)) == keccak256(raw), "complete original tuple bytes"
        );
        Validation.requireValid(Validation.Context(2, raw, RH.ownerProvenance(p.provenance, 2)));
    }

    function checked(bytes calldata raw, RH.OwnerProvenance calldata local) external pure {
        Validation.requireValid(Validation.Context(2, raw, local));
    }

    function oldDecoder(bytes calldata raw) external pure returns (bytes memory) {
        G.Proof memory p = abi.decode(raw, (G.Proof));
        return abi.encode(p);
    }

    function testCompleteCanonicalProofMatchesOriginalTypedDecoder() public view {
        G.Proof memory p = _fixture();
        bytes memory raw = abi.encode(p);
        require(
            keccak256(this.oldDecoder(raw)) == keccak256(Canonical.canonical(raw)),
            "old whole typed decoder parity"
        );
        _check(p);
    }

    function testEveryOriginalTopLevelAndBindingFieldSurvives() public view {
        G.Proof memory p = _fixture();
        _check(p);
        p.provenance.origins[0].chainId++;
        _check(p);
        p.bindings.bindings[0].bindings.current.accepted = false;
        _check(p);
        p.bindings.generations[0][0].proposal.ownerRevision++;
        _check(p);
        p.bindings.collaborators[0][0][0].account = address(0xF00D);
        _check(p);
        p.archive.accepted[0].operationIndex++;
        _check(p);
        p.accepted[0].rows[0].acceptedAt++;
        _check(p);
        p.accounts[0].words[0].words[0] ^= uint256(1) << 100;
        _check(p);
    }

    function testTrailingBytesAndLocalProvenanceMismatchRejectThenRestore() public {
        G.Proof memory p = _fixture();
        bytes memory raw = abi.encode(p);
        RH.OwnerProvenance memory local = RH.ownerProvenance(p.provenance, 2);
        vm.expectRevert(abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector));
        this.checked(bytes.concat(raw, bytes32(0)), local);
        local.origins[0].chainId++;
        vm.expectRevert(abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector));
        this.checked(raw, local);
        local.origins[0].chainId--;
        this.checked(raw, local);
    }

    function _word(bytes memory raw, uint256 at) private pure returns (uint256 v) {
        require(at + 32 <= raw.length, "test offset");
        assembly ("memory-safe") { v := mload(add(add(raw, 32), at)) }
    }

    function _put(bytes memory raw, uint256 at, uint256 v) private pure {
        require(at + 32 <= raw.length, "test offset");
        assembly ("memory-safe") { mstore(add(add(raw, 32), at), v) }
    }

    function testNoncanonicalOuterOffsetRejectsDespiteOriginalDecoderAcceptance() public {
        G.Proof memory p = _fixture();
        bytes memory raw = abi.encode(p);
        bytes memory changed = new bytes(raw.length + 32);
        _put(changed, 0, 64);
        for (uint256 i = 32; i < raw.length; i++) {
            changed[i + 32] = raw[i];
        }
        require(
            keccak256(this.oldDecoder(changed)) == keccak256(raw),
            "original decoder control accepts padding"
        );
        vm.expectRevert(abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector));
        this.checked(changed, RH.ownerProvenance(p.provenance, 2));
        _check(p);
    }

    function testMalformedUnusedNestedBoolRejectsBeforeLocalProjection() public {
        G.Proof memory p = _fixture();
        bytes memory raw = abi.encode(p);
        uint256 binding = 32 + _word(raw, 64);
        uint256 generations = binding + _word(raw, binding + 32);
        uint256 inner = generations + 32 + _word(raw, generations + 32);
        uint256 accepted = inner + 32 + 64;
        require(_word(raw, accepted) == 1, "literal nested accepted bool");
        _put(raw, accepted, 2);
        vm.expectRevert();
        this.checked(raw, RH.ownerProvenance(p.provenance, 2));
        _put(raw, accepted, 1);
        this.checked(raw, RH.ownerProvenance(p.provenance, 2));
    }

    function testMalformedUnselectedAccountWidthRejectsBeforeLocalProjection() public {
        G.Proof memory p = _fixture();
        bytes memory raw = abi.encode(p);
        uint256 accounts = 32 + _word(raw, 160);
        uint256 row = accounts + 32 + _word(raw, accounts + 32);
        require(_word(raw, row) == 3, "literal account kind");
        _put(raw, row, 259);
        vm.expectRevert();
        this.checked(raw, RH.ownerProvenance(p.provenance, 2));
        _put(raw, row, 3);
        this.checked(raw, RH.ownerProvenance(p.provenance, 2));
    }

    function testFuzzCompleteNonceWordAndGenerationCopies(uint256 bits, uint64 generation)
        public
        view
    {
        G.Proof memory p = _fixture();
        p.accounts[0].words[0].words[0] = bits;
        p.bindings.generations[0][0].generation = generation;
        _check(p);
    }
}
