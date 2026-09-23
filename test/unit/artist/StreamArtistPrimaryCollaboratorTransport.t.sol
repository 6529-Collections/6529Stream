// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPrimaryCollaboratorTypes as PC
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

import {
    StreamArtistPrimaryCollaboratorSourceProof as Source
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorSourceProof.sol";
import {
    StreamArtistPrimaryCollaboratorSourceCollection as Collection
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorSourceCollection.sol";
import {
    StreamArtistPrimaryCollaboratorCodec as Codec
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorCodec.sol";
import {
    StreamArtistPrimaryCollaboratorDecode as Decode
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorDecode.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationOwnerPayload.sol";

interface PrimaryTransportVm {
    function etch(address, bytes calldata) external;
}

library PrimaryTransportValues {
    function proof() internal pure returns (PC.Proof memory p) {
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
        p.archive.proposals = new PC.Proposal[](1);
        p.archive.proposals[0].identityOperationPlusOne = 5;
        p.archive.accepted = new PC.AcceptedRow[](1);
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

    function scope() internal pure returns (M.State memory s) {
        s.artists = new AH.Query[](2);
        s.artists[0].artistId = keccak256("Artist");
        s.artists[1].artistId = keccak256("Second Artist");
        s.collections = new AH.Query[](1);
        s.collections[0].artistId = s.artists[0].artistId;
        s.collections[0].collectionId = 17;
        s.collections[0].bindingHash = keccak256("binding");
        s.rows = new bytes[](2);
        s.rows[0] = hex"01aa";
        s.rows[1] = hex"02bbcc";
    }

    function payload() internal pure returns (Payload.Payload memory p) {
        PC.Proof memory x = proof();
        p.provenance = RH.ownerProvenance(x.provenance, 2);
        p.semanticState = hex"fedcba98";
        p.nonces = new RH.NonceInventory[](1);
        p.nonces[0].words = new AH.NonceWord[](1);
        p.nonces[0].words[0].prefix = 13;
        p.nonces[0].words[0].words[0] = 1;
        p.nonces[0].words[0].words[31] = type(uint256).max;
    }

    function result() internal pure returns (Source.Result memory s) {
        s.clocks.clocks.counts = new uint256[](2);
        s.clocks.clocks.counts[0] = 7;
        s.clocks.clocks.counts[1] = 11;
        s.clocks.primary = new PC.PrimaryReceipt[](1);
        s.clocks.primary[0] = PC.PrimaryReceipt(
            17, 2, keccak256("binding"), keccak256("record"), RH.Point(keccak256("era"), 3, 99), 17
        );
        s.clocks.finalPrimary = new bytes32[][](1);
        s.clocks.finalPrimary[0] = new bytes32[](2);
        s.clocks.finalPrimary[0][0] = keccak256("first");
        s.clocks.finalPrimary[0][1] = keccak256("second");
        s.clocks.accepted = new uint32[][](1);
        s.clocks.accepted[0] = new uint32[](1);
        s.clocks.accepted[0][0] = 3;
        PC.Proof memory p = proof();
        s.generations.bindings = p.bindings.bindings;
        s.generations.generations = p.bindings.generations;
        s.generations.catalogues = p.archive.catalogues;
        s.generations.operations = p.archive.operations;
    }
}

/// @dev Explicit typed source boundary: no source authority or actual Archive claim.
contract PrimaryTransportCollection {
    fallback(bytes calldata raw) external returns (bytes memory) {
        require(msg.sig == Collection.encoded.selector, "exact library selector");
        (M.State memory s, RH.Provenance memory p) = abi.decode(raw[4:], (M.State, RH.Provenance));
        require(
            keccak256(abi.encode(s)) == keccak256(abi.encode(PrimaryTransportValues.scope())),
            "complete scope argument"
        );
        PC.Proof memory proof = PrimaryTransportValues.proof();
        require(
            keccak256(abi.encode(p)) == keccak256(abi.encode(proof.provenance)),
            "complete source provenance argument"
        );
        return abi.encode(abi.encode(proof), abi.encode(PrimaryTransportValues.result()));
    }
}

/// @dev Explicit typed codec boundary: real Decode still executes full source equality and return transport.
contract PrimaryTransportCodec {
    fallback(bytes calldata input) external returns (bytes memory) {
        require(msg.sig == Codec.prepareSource.selector, "exact library selector");
        (uint8 owner, AH.Query memory anchor, bytes memory raw) =
            abi.decode(input[4:], (uint8, AH.Query, bytes));
        require(
            owner == 2 && anchor.artistId == keccak256("Artist")
                && keccak256(raw) == keccak256(hex"aabbcc"),
            "exact complete caller arguments"
        );
        return abi.encode(
            abi.encode(PrimaryTransportValues.scope()),
            abi.encode(PrimaryTransportValues.payload()),
            abi.encode(PrimaryTransportValues.proof())
        );
    }
}

/// @notice Real fixed return transport; deliberately typed source/codec boundaries, no whole-flow claim.
contract StreamArtistPrimaryCollaboratorTransportTest {
    PrimaryTransportVm private constant vm =
        PrimaryTransportVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _collection() private returns (bytes memory original) {
        original = address(Collection).code;
        vm.etch(address(Collection), address(new PrimaryTransportCollection()).code);
    }

    function _delegate(address target, bytes memory input) private returns (bytes memory output) {
        (bool ok, bytes memory out) = target.delegatecall(input);
        if (!ok) assembly ("memory-safe") { revert(add(out, 32), mload(out)) }
        return out;
    }

    function testSourceCollectFullTwoTupleEqualsOriginalEncoder() public {
        bytes memory old = _collection();
        PC.Proof memory p = PrimaryTransportValues.proof();
        Source.Result memory r = PrimaryTransportValues.result();
        bytes memory actual = _delegate(
            address(Source),
            abi.encodeWithSelector(
                Source.collect.selector, PrimaryTransportValues.scope(), p.provenance
            )
        );
        require(keccak256(actual) == keccak256(abi.encode(p, r)), "full original two tuple ABI");
        vm.etch(address(Collection), old);
        require(keccak256(address(Collection).code) == keccak256(old), "exact worker restore");
    }

    function testSourceCurrentFullResultAndIndependentAccountMismatchRestore() public {
        bytes memory old = _collection();
        PC.Proof memory p = PrimaryTransportValues.proof();
        M.State memory s = PrimaryTransportValues.scope();
        bytes memory actual = _delegate(
            address(Source), abi.encodeWithSelector(Source.requireCurrent.selector, s, p)
        );
        require(
            keccak256(actual) == keccak256(abi.encode(PrimaryTransportValues.result())),
            "complete original Result ABI"
        );
        p.accounts[0].words[0].words[0] ^= uint256(1) << 22;
        (bool ok, bytes memory error) = address(Source)
            .delegatecall(abi.encodeWithSelector(Source.requireCurrent.selector, s, p));
        require(
            !ok
                && keccak256(error)
                    == keccak256(
                        abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector)
                    ),
            "unused account full mismatch"
        );
        p.accounts[0].words[0].words[0] ^= uint256(1) << 22;
        require(
            keccak256(
                _delegate(
                    address(Source), abi.encodeWithSelector(Source.requireCurrent.selector, s, p)
                )
            ) == keccak256(actual),
            "identical request restore"
        );
        vm.etch(address(Collection), old);
    }

    function testDecodeFullThreeTupleRetainsNonceAndSemanticBytes() public {
        bytes memory oldSource = _collection();
        bytes memory oldCodec = address(Codec).code;
        vm.etch(address(Codec), address(new PrimaryTransportCodec()).code);
        AH.Query memory q;
        q.artistId = keccak256("Artist");
        bytes memory actual = _delegate(
            address(Decode),
            abi.encodeWithSelector(Decode.collect.selector, uint8(2), q, hex"aabbcc")
        );
        bytes memory expected = abi.encode(
            PrimaryTransportValues.scope(),
            PrimaryTransportValues.payload(),
            PrimaryTransportValues.proof()
        );
        require(keccak256(actual) == keccak256(expected), "complete original three tuple ABI");
        vm.etch(address(Codec), oldCodec);
        vm.etch(address(Collection), oldSource);
        require(
            keccak256(address(Codec).code) == keccak256(oldCodec)
                && keccak256(address(Collection).code) == keccak256(oldSource),
            "exact both worker restores"
        );
    }
}
