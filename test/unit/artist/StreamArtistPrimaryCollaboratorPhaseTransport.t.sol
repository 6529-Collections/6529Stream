// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { PrimaryTransportValues } from "./StreamArtistPrimaryCollaboratorTransport.t.sol";
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorAttributionProof as Proof
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorAttributionProof.sol";
import {
    StreamArtistPrimaryCollaboratorAttributionPrelude as Prelude
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorAttributionPrelude.sol";
import {
    StreamArtistPrimaryCollaboratorAttributionFinish as Finish
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorAttributionFinish.sol";
import {
    StreamArtistPrimaryCollaboratorFamilyComposition as Family
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorFamilyComposition.sol";
import {
    StreamArtistPrimaryCollaboratorFamilyCollection as Collection
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorFamilyCollection.sol";
import {
    StreamArtistPrimaryCollaboratorFamilyFinish as FamilyFinish
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorFamilyFinish.sol";
import {
    StreamArtistPrimaryCollaboratorFamilyValidation as FamilyValidation
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorFamilyValidation.sol";
import {
    StreamArtistPrimaryCollaboratorEncoding as Encoding
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorEncoding.sol";
import {
    StreamArtistPrimaryCollaboratorComposition as Composition
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorComposition.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredAttestationHydration as Records
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistPrimaryCollaboratorCompositionSource as CompositionSource
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorCompositionSource.sol";

interface PrimaryPhaseVm {
    function etch(address, bytes calldata) external;
}

library PrimaryPhaseValues {
    function emptySanctions() internal pure returns (bytes memory) {
        H.Inventory memory empty;
        return abi.encode(empty);
    }

    function arguments() internal pure returns (bytes memory) {
        PC.Proof memory p = PrimaryTransportValues.proof();
        return abi.encode(PrimaryTransportValues.scope(), RH.ownerProvenance(p.provenance, 4), p);
    }

    function result() internal pure returns (Proof.Result memory r) {
        r.histories = new A.AttributionBundle[](1);
        r.histories[0].artistId = keccak256("Artist");
        r.histories[0].collectionId = 17;
        r.histories[0].bindingHash = keccak256("binding");
        r.all = new Records.Bundle[](1);
        r.all[0].artistId = keccak256("Artist");
        r.all[0].collectionId = 17;
    }

    function family()
        internal
        pure
        returns (Family.Context memory c, Collection.Result memory rows)
    {
        c.source.scope = PrimaryTransportValues.scope();
        c.source.features = 1;
        c.proof = PrimaryTransportValues.proof();
        c.observed = PrimaryTransportValues.result();
        c.source.identities = new bytes[](1);
        c.source.identities[0] = hex"aabb00ff";
        c.source.provenance = c.proof.provenance;
        c.history = new A.AttributionBundle[](1);
        c.history[0].artistId = keccak256("Artist");
        c.history[0].collectionId = 17;
        rows.ratifications = new T.RatificationRecord[][](1);
        rows.ratifications[0] = new T.RatificationRecord[](0);
        rows.consents = new G.Consents[](1);
        rows.attestations = new bytes[](1);
        Records.Bundle memory b;
        b.artistId = keccak256("Artist");
        b.collectionId = 17;
        rows.attestations[0] = abi.encode(b);
    }
}

contract PrimaryPhasePreludeBoundary {
    fallback(bytes calldata raw) external returns (bytes memory) {
        require(msg.sig == Prelude.prepare.selector, "exact prelude selector");
        bytes memory args = abi.decode(raw[4:], (bytes));
        require(
            keccak256(args) == keccak256(PrimaryPhaseValues.arguments()), "entire original args"
        );
        return abi.encode(bytes("authenticated prelude marker"));
    }
}

contract PrimaryPhaseFinishBoundary {
    fallback(bytes calldata raw) external returns (bytes memory) {
        require(msg.sig == Finish.finish.selector, "exact finish selector");
        (bytes memory args, bytes memory prepared) = abi.decode(raw[4:], (bytes, bytes));
        require(
            keccak256(args) == keccak256(PrimaryPhaseValues.arguments())
                && keccak256(prepared) == keccak256(bytes("authenticated prelude marker")),
            "prelude before finish and entire args"
        );
        return abi.encode(abi.encode(PrimaryPhaseValues.result()));
    }
}

contract PrimaryFamilyValidationBoundary {
    fallback(bytes calldata raw) external returns (bytes memory) {
        require(msg.sig == FamilyValidation.validate.selector, "exact family validator selector");
        (
            FamilyValidation.Context memory c,
            H.Inventory memory sanctions,
            T.RatificationRecord[][] memory ratifications
        ) = abi.decode(raw[4:], (FamilyValidation.Context, H.Inventory, T.RatificationRecord[][]));
        (Family.Context memory family, Collection.Result memory rows) = PrimaryPhaseValues.family();
        FamilyValidation.Context memory expected = FamilyValidation.Context(
            family.source.identities,
            family.source.scope,
            family.proof.bindings,
            family.proof.archive,
            family.observed.clocks.primary,
            family.source.provenance,
            family.observed.generations,
            rows.consents,
            rows.attestations
        );
        require(
            keccak256(abi.encode(c)) == keccak256(abi.encode(expected)),
            "all nine original validation fields"
        );
        require(
            keccak256(abi.encode(sanctions)) == keccak256(PrimaryPhaseValues.emptySanctions()),
            "complete empty sanction argument"
        );
        require(
            keccak256(abi.encode(ratifications)) == keccak256(abi.encode(rows.ratifications)),
            "complete collected ratification matrix"
        );
        return bytes("");
    }
}

contract PrimaryPhaseRefusalBoundary {
    error ForcedPhaseRefusal(uint256 marker);

    fallback() external {
        revert ForcedPhaseRefusal(6529);
    }
}

contract PrimaryCompositionSourceBoundary {
    fallback(bytes calldata raw) external returns (bytes memory) {
        require(msg.sig == CompositionSource.prepare.selector, "exact source selector");
        bytes memory input = abi.decode(raw[4:], (bytes));
        (Family.Context memory c,) = PrimaryPhaseValues.family();
        require(
            keccak256(input) == keccak256(abi.encode(c.source)),
            "canonical complete Composition context"
        );
        H.Inventory memory empty;
        return abi.encode(abi.encode(c, empty));
    }
}

contract PrimaryFamilyCollectionBoundary {
    fallback(bytes calldata raw) external returns (bytes memory) {
        require(msg.sig == Collection.collect.selector, "exact collection selector");
        (bytes memory input, bytes memory history) = abi.decode(raw[4:], (bytes, bytes));
        (Family.Context memory c, Collection.Result memory rows) = PrimaryPhaseValues.family();
        require(keccak256(input) == keccak256(abi.encode(c)), "canonical complete Family context");
        require(
            keccak256(history) == keccak256(PrimaryPhaseValues.emptySanctions()),
            "full collection sanction carrier"
        );
        return abi.encode(abi.encode(rows));
    }
}

contract PrimaryFamilyFinishBoundary {
    fallback(bytes calldata raw) external returns (bytes memory) {
        require(msg.sig == FamilyFinish.finish.selector, "exact family finish selector");
        (bytes memory input, bytes memory observed, bytes memory history) =
            abi.decode(raw[4:], (bytes, bytes, bytes));
        (Family.Context memory c, Collection.Result memory rows) = PrimaryPhaseValues.family();
        require(
            keccak256(input) == keccak256(abi.encode(c))
                && keccak256(observed) == keccak256(abi.encode(rows)),
            "complete families and ordered rows"
        );
        require(
            keccak256(history) == keccak256(PrimaryPhaseValues.emptySanctions()),
            "full final sanction carrier"
        );
        Composition.Result memory r;
        r.features = 911;
        r.inventory = abi.encode(c.proof);
        r.accounts = c.proof.accounts;
        return abi.encode(abi.encode(r));
    }
}

/// @notice Actual fixed orchestration/encoding, explicit typed phase/validation boundaries.
/// These cases prove original full argument/return bytes and order, not source admission or full Safe import.
contract StreamArtistPrimaryCollaboratorPhaseTransportTest {
    PrimaryPhaseVm private constant vm =
        PrimaryPhaseVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _run(address target, bytes memory input) private returns (bytes memory output) {
        (bool ok, bytes memory raw) = target.delegatecall(input);
        if (!ok) assembly ("memory-safe") { revert(add(raw, 32), mload(raw)) }
        return raw;
    }

    function testAttributionValidatedReturnAndVoidRunBothOrderedPhases() public {
        bytes memory oldA = address(Prelude).code;
        bytes memory oldB = address(Finish).code;
        vm.etch(address(Prelude), address(new PrimaryPhasePreludeBoundary()).code);
        vm.etch(address(Finish), address(new PrimaryPhaseFinishBoundary()).code);
        bytes memory args = PrimaryPhaseValues.arguments();
        bytes memory actual = _run(address(Proof), bytes.concat(Proof.validate.selector, args));
        require(
            keccak256(actual) == keccak256(abi.encode(PrimaryPhaseValues.result())),
            "full result ABI"
        );
        require(
            _run(address(Proof), bytes.concat(Proof.requireValid.selector, args)).length == 0,
            "original void ABI after same phases"
        );
        bytes memory healthy = address(Prelude).code;
        vm.etch(address(Prelude), address(new PrimaryPhaseRefusalBoundary()).code);
        (bool ok, bytes memory reason) =
            address(Proof).delegatecall(bytes.concat(Proof.requireValid.selector, args));
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            PrimaryPhaseRefusalBoundary.ForcedPhaseRefusal.selector, 6529
                        )
                    ),
            "void entry must execute original prelude"
        );
        vm.etch(address(Prelude), healthy);
        require(
            _run(address(Proof), bytes.concat(Proof.requireValid.selector, args)).length == 0,
            "identical void request restores"
        );
        vm.etch(address(Prelude), oldA);
        vm.etch(address(Finish), oldB);
    }

    function testAttributionEncodedArgumentsRetainEntireProofAndRestoreFailure() public {
        bytes memory oldA = address(Prelude).code;
        bytes memory oldB = address(Finish).code;
        vm.etch(address(Prelude), address(new PrimaryPhasePreludeBoundary()).code);
        vm.etch(address(Finish), address(new PrimaryPhaseFinishBoundary()).code);
        PC.Proof memory p = PrimaryTransportValues.proof();
        M.State memory s = PrimaryTransportValues.scope();
        RH.OwnerProvenance memory local = RH.ownerProvenance(p.provenance, 4);
        bytes memory raw = Proof.encoded(s, local, abi.encode(p));
        require(
            keccak256(raw) == keccak256(abi.encode(PrimaryPhaseValues.result())),
            "full encoded result"
        );
        p.accounts[0].words[0].words[0] ^= 8;
        (bool ok, bytes memory error) = address(Proof)
            .delegatecall(abi.encodeWithSelector(Proof.encoded.selector, s, local, abi.encode(p)));
        require(
            !ok
                && keccak256(error)
                    == keccak256(abi.encodeWithSignature("Error(string)", "entire original args")),
            "unconsumed account mutation reaches complete input check"
        );
        p.accounts[0].words[0].words[0] ^= 8;
        require(
            keccak256(Proof.encoded(s, local, abi.encode(p))) == keccak256(raw), "exact restore"
        );
        vm.etch(address(Prelude), oldA);
        vm.etch(address(Finish), oldB);
    }

    function testFamilyFinishUsesOriginalEncodingContextAndAllResultFields() public {
        bytes memory old = address(FamilyValidation).code;
        vm.etch(address(FamilyValidation), address(new PrimaryFamilyValidationBoundary()).code);
        (Family.Context memory c, Collection.Result memory rows) = PrimaryPhaseValues.family();
        Encoding.Context memory expected = Encoding.Context(
            1,
            c.source.features,
            c.proof,
            c.proof.accepted,
            rows.consents,
            rows.attestations,
            c.history
        );
        Composition.Result memory full = Encoding.encode(expected);
        bytes memory actual = FamilyFinish.finish(
            abi.encode(c), abi.encode(rows), PrimaryPhaseValues.emptySanctions()
        );
        require(
            keccak256(actual) == keccak256(abi.encode(full)),
            "manual context offsets vs original typed encoder"
        );
        require(
            full.features == (1 | PC.FEATURE | RH.BINDING_GENERATIONS)
                && keccak256(full.inventory) == keccak256(abi.encode(c.proof)),
            "literal base features and complete proof"
        );
        require(
            full.accounts[0].words[0].words[0] == uint256(1) << 19
                && keccak256(full.generations)
                    == keccak256(abi.encode(c.proof.bindings.generations)),
            "nonce and generation outputs retained"
        );
        require(
            keccak256(full.consents[0]) == keccak256(abi.encode(rows.consents[0]))
                && keccak256(full.accepted[0]) == keccak256(abi.encode(c.proof.accepted[0])),
            "full original family row bytes"
        );
        bytes memory healthy = address(FamilyValidation).code;
        vm.etch(address(FamilyValidation), address(new PrimaryPhaseRefusalBoundary()).code);
        (bool ok, bytes memory reason) = address(FamilyFinish)
            .delegatecall(
                abi.encodeWithSelector(
                    FamilyFinish.finish.selector,
                    abi.encode(c),
                    abi.encode(rows),
                    PrimaryPhaseValues.emptySanctions()
                )
            );
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            PrimaryPhaseRefusalBoundary.ForcedPhaseRefusal.selector, 6529
                        )
                    ),
            "must execute complete original conservation"
        );
        vm.etch(address(FamilyValidation), healthy);
        require(
            keccak256(
                FamilyFinish.finish(
                    abi.encode(c), abi.encode(rows), PrimaryPhaseValues.emptySanctions()
                )
            ) == keccak256(actual),
            "identical final phase request restores"
        );
        vm.etch(address(FamilyValidation), old);
        require(
            keccak256(address(FamilyValidation).code) == keccak256(old),
            "restore exact validation worker"
        );
    }

    function _word(bytes memory raw, uint256 at) private pure returns (uint256 value) {
        require(at + 32 <= raw.length, "test bound");
        assembly ("memory-safe") { value := mload(add(add(raw, 32), at)) }
    }

    function _dirty(bytes memory raw, uint256 at) private pure returns (bytes memory bad) {
        bad = bytes.concat(raw);
        uint256 value = _word(bad, at) | (uint256(1) << 160);
        assembly ("memory-safe") { mstore(add(add(bad, 32), at), value) }
    }

    function _padded(bytes memory raw) private pure returns (bytes memory padded) {
        padded = new bytes(raw.length + 32);
        assembly ("memory-safe") { mstore(add(padded, 32), 64) }
        for (uint256 i = 32; i < raw.length; ++i) {
            padded[i + 32] = raw[i];
        }
    }

    function testOriginalCompleteContextDomainRejectsUnusedDirtyAddressesAndAcceptsPadding()
        public
    {
        bytes memory oldSource = address(CompositionSource).code;
        bytes memory oldCollection = address(Collection).code;
        bytes memory oldFinish = address(FamilyFinish).code;
        vm.etch(address(CompositionSource), address(new PrimaryCompositionSourceBoundary()).code);
        vm.etch(address(Collection), address(new PrimaryFamilyCollectionBoundary()).code);
        vm.etch(address(FamilyFinish), address(new PrimaryFamilyFinishBoundary()).code);
        (Family.Context memory c,) = PrimaryPhaseValues.family();
        bytes memory composition = abi.encode(c.source);
        bytes memory family = abi.encode(c);
        bytes memory a =
            _run(address(Composition), bytes.concat(Composition.collect.selector, composition));
        bytes memory b = _run(address(Family), bytes.concat(bytes4(0x4373612c), family));
        require(keccak256(a) == keccak256(b), "same complete typed final result");
        (bool ok, bytes memory error) = address(Composition)
            .delegatecall(bytes.concat(Composition.collect.selector, _dirty(composition, 32)));
        require(
            !ok && error.length == 0,
            "original ABI decoder rejects unused registry width before typed source"
        );
        uint256 sourceAt = 32 + _word(family, 32);
        (ok, error) = address(Family)
            .delegatecall(bytes.concat(bytes4(0x4373612c), _dirty(family, sourceAt)));
        require(
            !ok && error.length == 0,
            "original ABI decoder rejects unused nested registry width before typed phases"
        );
        require(
            keccak256(
                _run(
                    address(Composition),
                    bytes.concat(Composition.collect.selector, _padded(composition))
                )
            ) == keccak256(a),
            "typed-valid padded Composition canonicalizes"
        );
        require(
            keccak256(_run(address(Family), bytes.concat(bytes4(0x4373612c), _padded(family))))
                == keccak256(b),
            "typed-valid padded Family canonicalizes"
        );
        vm.etch(address(CompositionSource), oldSource);
        vm.etch(address(Collection), oldCollection);
        vm.etch(address(FamilyFinish), oldFinish);
    }
}
