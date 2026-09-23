// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredAttestationAuthorityActualTest
} from "./StreamArtistRecoveredAttestationAuthorityActual.t.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistBindingLifecycleTypes as L
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistBindingTerminationOwner as Terminal
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingTerminationOwner.sol";
import {
    IStreamArtistAttributionOwner as Attribution
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    IStreamArtistRecoveredHydration as Recovered
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH,
    IStreamArtistAuthorityHydrationOwner as HydrationOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationPrepared as Prepared
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationPrepared.sol";
import {
    StreamArtistRecoveredHydrationCommit as Commit
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationCommit.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredHydrationEvidence as Evidence
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationEvidence.sol";
import {
    StreamArtistRecoveredAttestationHydration as Attestations
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistReadinessHydrationTypes as Ready
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    IStreamArtistArchiveV2 as Archive
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import {
    IStreamArtistC2PAReads as Credentials
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistC2PA.sol";
import {
    StreamArtistPersonhoodDefinitions as Personhood
} from "../../../smart-contracts/domains/artist/StreamArtistPersonhoodDefinitions.sol";

interface GenerationAttestationVm {
    function expectCall(address target, bytes calldata data, uint64 count) external;
}

/// @notice Actual original refusal/withdrawal/reproposal, recovery35, op24 and seven-owner60.
/// @dev Core/governance/subject dependencies retain the inherited typed boundaries. Original
/// Artist owners, Registry, Coordinator, Archive and threshold Safes execute. These authored
/// recipes are not a claim that the current whole graph or maximum transport has been run.
contract StreamArtistRecoveredGenerationAttestationsActualTest is
    StreamArtistRecoveredAttestationAuthorityActualTest
{
    GenerationAttestationVm private constant gvm =
        GenerationAttestationVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    T.Binding[] private originals;
    L.Terminal[] private terminals;
    uint64 internal finalGeneration;

    function testGenerationAttestationsRefusedWithdrawnThirdAndAllOriginalHeads() external {
        _gaBaseline(2);
        _gaRecords();
        T.SuiteConfiguration memory original = suite;
        uint256 count = raRows.length;
        bytes32 sourceBefore = _raSource(original, count);
        Successor memory next = _rhCutover();
        _gaTransfer(next);
        _gaBinding(next.coordinator.suiteConfiguration());
        _raAssert(next.coordinator.suiteConfiguration(), count);
        require(
            _raSource(original, count) == sourceBefore,
            "source documentary bytes and heads unchanged"
        );
    }

    function testGenerationAttestationsSecondImportRetainsOriginalEraAndFreshCredentialDomain()
        external
    {
        _gaBaseline(1);
        _gaRecords();
        Successor memory middle = _rhCutover();
        Commit.Prepared memory first = _gaTransfer(middle);
        _rhAdopt(middle);
        bytes32 previous = Credentials(suite.owners[4]).c2paCredentialHead(artistId).recordHash;
        bytes32 fresh = _raCredential(previous, false);
        require(
            raRows[raRows.length - 1].record.generation == 2,
            "fresh B original24 keeps accepted generation"
        );
        Successor memory last = _rhCutover();
        Commit.Prepared memory second = _gaTransfer(last);
        require(second.admission.provenance.eras.length == 2, "actual original A/B eras");
        require(
            second.admission.provenance.journals[4].length
                == first.admission.provenance.journals[4].length + 1,
            "one exact B occurrence"
        );
        for (uint256 i; i < first.admission.provenance.journals[4].length; ++i) {
            require(
                keccak256(abi.encode(first.admission.provenance.journals[4][i]))
                    == keccak256(abi.encode(second.admission.provenance.journals[4][i])),
                "ultimate A native coordinates unchanged"
            );
        }
        _gaBinding(last.coordinator.suiteConfiguration());
        require(
            Credentials(last.coordinator.suiteConfiguration().owners[4])
            .c2paCredentialHead(artistId)
            .recordHash == fresh,
            "full latest credential chain"
        );
    }

    function testGenerationAttestationsCompleteWitnessNonceCapabilityAndSourceRefusals() external {
        _gaBaseline(2);
        _gaRecords();
        Successor memory next = _rhCutover();
        RH.Request memory request = _raRequest();
        Commit.Prepared memory prepared = _gaPrepared(next, request);
        request.expectedSemanticInventory = Prepared.inventory(prepared);
        bytes32 before_ = _rhDestinationHash(next);
        RH.Request memory bad = abi.decode(abi.encode(request), (RH.Request));
        bad.records.witnesses[0].attestations = new Ready.AttestationInput[](0);
        avm.expectRevert(T.UnsupportedProfile.selector);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(bad);
        bad = abi.decode(abi.encode(request), (RH.Request));
        ++bad.records.witnesses[0].attestations[0].nonce;
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(bad);
        bad = abi.decode(abi.encode(request), (RH.Request));
        bad.expectedCapabilities[4].supportedFeatures &= ~uint256(512);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(bad);
        bad = abi.decode(abi.encode(request), (RH.Request));
        ++bad.records.authority.expectedSource[4].ownerState.revision;
        avm.expectRevert(RH.InvalidRecoveredHydrationProvenance.selector);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(bad);
        require(_rhDestinationHash(next) == before_, "no partial owner/replay changes");
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        _gaBinding(next.coordinator.suiteConfiguration());
        _raAssert(next.coordinator.suiteConfiguration(), raRows.length);
    }

    function testGenerationAttestationsWrongGenerationCannotRelabelOriginalRecordOrHead() external {
        _gaBaseline(1);
        _gaRecords();
        Successor memory next = _rhCutover();
        Commit.Prepared memory prepared = _gaPrepared(next, _raRequest());
        (, Payload.Payload memory payload) = Payload.decode(prepared.data[4].typedState, 4);
        Attestations.Bundle memory b =
            Attestations.decode(prepared.query, payload.provenance, payload.semanticState);
        require(
            b.item.generation == 2 && b.records[0].attestation.record.generation == 2,
            "positive real source first"
        );
        Attestations.Bundle memory bad = abi.decode(abi.encode(b), (Attestations.Bundle));
        bad.records[0].attestation.record.generation = 1;
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        this.gaValidate(bad, prepared.query, payload.provenance);
        bad = abi.decode(abi.encode(b), (Attestations.Bundle));
        bad.records[0].attestation.association.generation = 1;
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        this.gaValidate(bad, prepared.query, payload.provenance);
        bad = abi.decode(abi.encode(b), (Attestations.Bundle));
        bad.item.generation = 1;
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        this.gaValidate(bad, prepared.query, payload.provenance);
        this.gaValidate(b, prepared.query, payload.provenance);
    }

    function testGenerationAttestationsLateArchiveFailureCountsFirstPageAndExactSafeRetry()
        external
    {
        _gaBaseline(1);
        _gaRecords();
        Successor memory next = _rhCutover();
        RH.Request memory request = _raRequest();
        Commit.Prepared memory prepared = _gaPrepared(next, request);
        request.expectedSemanticInventory = Prepared.inventory(prepared);
        bytes32 before_ = _rhDestinationHash(next);
        uint256 nonce = rotationSafe.nonce();
        bytes memory call_ = abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (request));
        bytes memory prefix = _gaFirstPage(next, request, prepared);
        // Exactly two calls to the SAME first page: the failed Safe attempt and successful retry.
        // A premature refusal cannot be masked by the later successful transaction.
        gvm.expectCall(next.coordinator.suiteConfiguration().archive, prefix, 2);
        uint256 height = block.number;
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(address(next.registry), call_);
        require(
            rotationSafe.nonce() == nonce && _rhDestinationHash(next) == before_,
            "late failure restores seven roots and Safe nonce"
        );
        require(
            Credentials(next.coordinator.suiteConfiguration().owners[4])
            .c2paCredentialHead(artistId)
            .recordHash == 0,
            "derived head rolled back"
        );
        vm.roll(height);
        require(
            this.rhExecuteNewSafe(address(next.registry), call_),
            "identical signed Safe arguments retry"
        );
        require(rotationSafe.nonce() == nonce + 1, "one committed Safe execution");
        _gaBinding(next.coordinator.suiteConfiguration());
        _raAssert(next.coordinator.suiteConfiguration(), raRows.length);
    }

    function gaValidate(
        Attestations.Bundle memory b,
        AH.Query memory q,
        RH.OwnerProvenance memory p
    ) external pure {
        Attestations.validate(b, q, p);
    }

    function _gaBaseline(uint8 transitions) internal {
        require(transitions == 1 || transitions == 2);
        for (uint256 i; i < transitions; ++i) {
            T.Binding memory b = Binding(suite.owners[0]).binding(1);
            originals.push(b);
            _rhCandidate(
                0,
                "binding_lifecycle.replay.proposal_key",
                keccak256(abi.encode(uint256(1), b.generation))
            );
            L.Termination memory p = _termination(1);
            if (i == 0) {
                T.Authorization memory a = _authorization(false);
                bytes32 digest = ingress.bindingRefusalDigest(p, a);
                a.signature = _signature(digest);
                ingress.refuseArtistBinding(p, a);
                _rhAuthorization(digest, a.nonce);
                _rhCandidate(
                    0,
                    "binding_lifecycle.replay.refusal_uniqueness",
                    keccak256(abi.encode(uint256(1), b.generation))
                );
            } else {
                ingress.withdrawArtistBinding(p);
                _rhCandidate(
                    0,
                    "binding_lifecycle.replay.proposal_terminal_transition_key",
                    keccak256(abi.encode(uint256(1), b.generation))
                );
            }
            terminals.push(Terminal(suite.owners[0]).bindingTermination(1, b.generation));
            _repropose(1);
        }
        T.Binding memory last = Binding(suite.owners[0]).binding(1);
        finalGeneration = last.generation;
        _rhCandidate(
            0,
            "binding_lifecycle.replay.proposal_key",
            keccak256(abi.encode(uint256(1), finalGeneration))
        );
        _rhCandidate(
            3,
            "acceptance_lifecycle.replay.record_uniqueness",
            keccak256(abi.encode(uint256(1), finalGeneration, uint8(1), address(artist)))
        );
        _raBaseline();
        originals.push(Binding(suite.owners[0]).binding(1));
        terminals.push(Terminal(suite.owners[0]).bindingTermination(1, finalGeneration));
    }

    function _gaRecords() internal {
        _raPrimary(0, 0);
        _raDeployment();
        bytes memory waiver = bytes("explicit original personhood waiver");
        _raRecord(
            _raIdentityTerms(waiver, keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")),
            waiver,
            0,
            0
        );
        bytes32 first = _raCredential(0, false);
        _raCredential(first, true);
        for (uint256 i; i < raRows.length; ++i) {
            require(
                raRows[i].record.generation == finalGeneration,
                "actual original24 captured final accepted generation"
            );
        }
    }

    function _gaPrepared(Successor memory next, RH.Request memory request)
        private
        view
        returns (Commit.Prepared memory p)
    {
        p = Prepared.prepare(next.coordinator.suiteConfiguration(), request);
        for (uint8 i; i < 7; ++i) {
            (RH.ExportHeader memory h,) = Payload.decode(p.data[i].typedState, i);
            require(
                (h.requiredFeatures & uint256(640)) == 640,
                "all seven owners require exact generation+attestation composition"
            );
        }
        require(Prepared.inventory(p) != 0, "complete source certificate");
    }

    function _gaTransfer(Successor memory next) private returns (Commit.Prepared memory p) {
        RH.Request memory request = _raRequest();
        p = _gaPrepared(next, request);
        request.expectedSemanticInventory = Prepared.inventory(p);
        bytes32 value = Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        _rhImported(next, p, value);
        _raAssert(next.coordinator.suiteConfiguration(), raRows.length);
    }

    function _gaBinding(T.SuiteConfiguration memory target) internal view {
        require(
            Binding(target.owners[0]).binding(1).generation == finalGeneration,
            "selected final generation"
        );
        (uint8 state, uint64 generation) = Attribution(target.owners[4]).attributionState(1);
        require(state == 2 && generation == finalGeneration, "matching imported Attribution");
        for (uint256 i; i < originals.length; ++i) {
            require(
                keccak256(abi.encode(Binding(target.owners[0]).bindingAt(1, uint64(i + 1))))
                    == keccak256(abi.encode(originals[i])),
                "every original binding remains exact"
            );
            require(
                keccak256(
                    abi.encode(Terminal(target.owners[0]).bindingTermination(1, uint64(i + 1)))
                ) == keccak256(abi.encode(terminals[i])),
                "every original refusal/withdrawal remains exact"
            );
        }
    }

    function _gaFirstPage(
        Successor memory next,
        RH.Request memory request,
        Commit.Prepared memory p
    ) internal view returns (bytes memory) {
        bytes32 value = keccak256(
            abi.encode(
                RH.PROFILE,
                RH.VERSION,
                block.chainid,
                address(next.registry),
                address(next.coordinator),
                p.admission.prior,
                p.admission.sourceCoordinator,
                request,
                p.admission.artists,
                p.admission.collections,
                p.query,
                p.data,
                p.timing,
                p.externalGuards,
                p.admission.before_
            )
        );
        bytes memory profile = abi.encode(
            RH.PROFILE,
            RH.VERSION,
            p.admission.prior,
            p.admission.sourceCoordinator,
            request,
            p.admission.artists,
            p.admission.collections,
            p.query,
            p.data,
            p.timing,
            p.externalGuards
        );
        Evidence.Descriptor memory descriptor = Evidence.describe(profile);
        bytes32 id = Evidence.pageId(
            address(next.registry), address(next.coordinator), value, descriptor, 0
        );
        return abi.encodePacked(Archive.appendArtistEvidenceV2.selector, id);
    }
}
