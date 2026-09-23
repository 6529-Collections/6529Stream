// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistRecoveredEstateAuthorityActual.t.sol";
import {
    StreamArtistIdentityRevisionTypes as Doc,
    IStreamArtistIdentityRevision
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRevision.sol";
import {
    IStreamArtistBindingOwner as BindingOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistCollaboratorBindingOwner as TermsOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistCollaboratorBindingOwner.sol";
import {
    IStreamArtistBindingTerminationOwner as TerminalOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingTerminationOwner.sol";
import {
    IStreamArtistAcceptanceOwner as AcceptanceOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAcceptanceOwner.sol";

/// @notice Original pending-generation history followed by genuine40/35 and class3 imports.
/// @dev Owners, Registry, Coordinator, Archive and Safe are actual; Core/governance are typed
/// unit boundaries. Authored source assertions do not establish runtime or capacity acceptance.
contract StreamArtistRecoveredEstateBindingGenerationsActualTest is
    StreamArtistRecoveredEstateAuthorityActualTest
{
    uint64 private egGeneration;
    bytes32 private egBindings;
    bytes32 private egAcceptance;
    uint64 private egAcceptedAt;
    bytes32 private egRegistration;
    bytes32[] private egRevisions;
    Doc.Record[] private egRevisionBodies;
    bytes[] private egDocuments;
    bytes[] private egSignatures;

    function testRecoveredEstateReproposalsAndIdentity25SurviveTwoSuccessors() external {
        _egStart(true, 4095);
        _egRevision(bytes("class3 A corrected history documentary revision"));
        T.SuiteConfiguration memory a = suite;
        Successor memory b = _egImport();
        bytes32 aSealed = _egCheckpoints(a.owners);
        _egAssert(b.coordinator.suiteConfiguration(), 4095);
        _ehAdopt(b);
        _egRevision(bytes("class3 B second original domain revision"));
        T.SuiteConfiguration memory middle = suite;
        Successor memory c = _egImport();
        bytes32 bSealed = _egCheckpoints(middle.owners);
        _egAssert(c.coordinator.suiteConfiguration(), 4095);
        _ehAdopt(c);
        require(
            ingress.operativeIdentityRecord(artistId) == keccak256(egDocuments[1])
                && IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).identityRecordHash
                    == egRegistration,
            "current original25 head remains distinct from immutable registration"
        );
        require(
            _egCheckpoints(a.owners) == aSealed && _egCheckpoints(middle.owners) == bSealed,
            "repeated imports and B writes preserve both sealed source checkpoints"
        );
    }

    function testRecoveredEstateReproposalKeepsZeroCapabilityAndOriginalRefusalRules() external {
        _egStart(false, 0);
        Successor memory next = _egImport();
        _egAssert(next.coordinator.suiteConfiguration(), 0);
        _ehAdopt(next);
        bytes32 before_ = _egCheckpoints(suite.owners);
        vm.expectRevert(
            abi.encodeWithSelector(
                Estate.EstateCapabilityUnavailable.selector, artistId, uint32(2048)
            )
        );
        this.ehWriteGuardians();
        require(
            _egCheckpoints(suite.owners) == before_,
            "zero-rights rejection leaves owner state unchanged"
        );
        // The final binding is accepted: old pending termination cannot become available again.
        vm.expectRevert(abi.encodeWithSelector(T.InvalidAttribution.selector, uint256(1)));
        ingress.withdrawArtistBinding(_termination(1));
        require(_egCheckpoints(suite.owners) == before_, "import does not reopen accepted binding");
    }

    function _egStart(bool refused, uint32 capabilities) private {
        if (refused) {
            T.Authorization memory a = _authorization(false);
            bytes32 digest = ingress.bindingRefusalDigest(_termination(1), a);
            a.signature = _signature(digest);
            bytes32 record = ingress.refuseArtistBinding(_termination(1), a);
            require(record != 0, "original signed refusal3");
            _ehAuthorization(digest, a.nonce);
            _ehCandidate(
                0,
                "binding_lifecycle.replay.refusal_uniqueness",
                keccak256(abi.encode(uint256(1), uint64(1)))
            );
            _repropose(1);
            _ehCandidate(
                0,
                "binding_lifecycle.replay.proposal_key",
                keccak256(abi.encode(uint256(1), uint64(2)))
            );
        }
        uint64 withdrawn = BindingOwner(suite.owners[0]).binding(1).generation;
        uint256 beforeNative = Native(suite.owners[0]).artistNativeReceiptCount();
        ingress.withdrawArtistBinding(_termination(1));
        require(
            Native(suite.owners[0]).artistNativeReceiptCount() == beforeNative,
            "original4 has no native receipt"
        );
        _ehCandidate(
            0,
            "binding_lifecycle.replay.proposal_terminal_transition_key",
            keccak256(abi.encode(uint256(1), withdrawn))
        );
        _repropose(1);
        egGeneration = withdrawn + 1;
        _ehCandidate(
            0,
            "binding_lifecycle.replay.proposal_key",
            keccak256(abi.encode(uint256(1), egGeneration))
        );
        _ehCandidate(
            3,
            "acceptance_lifecycle.replay.record_uniqueness",
            keccak256(abi.encode(uint256(1), egGeneration, uint8(1), address(artist)))
        );
        _ehBaseline(capabilities);
        _adoptRotatedSafe();
        vm.warp(ingress.artistTransitionState(ehRecovery).postWindowEndsAt);
        T.Binding memory current = BindingOwner(suite.owners[0]).binding(1);
        require(
            current.accepted && current.generation == egGeneration,
            "actual signed original2 accepted final generation"
        );
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).authorityClass == 3,
            "genuine matured class3 recovery"
        );
        egBindings = _egHistory(suite);
        egAcceptance = AcceptanceOwner(suite.owners[3]).acceptanceRecord(current.bindingHash);
        egAcceptedAt = AcceptanceOwner(suite.owners[3]).acceptedAt(current.bindingHash);
        egRegistration =
        IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).identityRecordHash;
    }

    function _egRevision(bytes memory document) private {
        Doc.Revision memory p = Doc.Revision(
            artistId,
            ingress.operativeIdentityRecord(artistId),
            keccak256(document),
            "urn:recovered:estate:reproposal"
        );
        T.Authorization memory a = _authorization(true);
        bytes32 digest = ingress.identityRevisionDigest(p, a);
        a.signature = _signature(digest);
        bytes32 record = keccak256(
            abi.encode(
                bytes32(0x1b7518e9d16da358d15957ec43218eb0b017fbd017e60c75b3126110006034a4),
                block.chainid,
                address(ingress),
                artistId,
                p.previousRecordHash,
                p.revisedRecordHash,
                address(artist),
                uint8(3),
                a.nonce,
                a.time
            )
        );
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistIdentityRevision.recordIdentityRevision,
                    (p, a, document, "Recovered Estate Artist")
                ),
                0
            ),
            "real class3 Safe records original25"
        );
        Doc.Record memory body = ingress.identityRevisionRecord(record);
        require(
            body.recordHash == record && body.authorityClass == 3
                && body.revisedRecordHash == keccak256(document),
            "independent original25 hash and documentary bytes"
        );
        _ehAuthorization(digest, a.nonce);
        _ehCandidate(
            2,
            "identity_authority.replay.identity_revision_chain",
            keccak256(abi.encode(artistId, body.previousRevisionRecord, p.previousRecordHash))
        );
        egRevisions.push(record);
        egRevisionBodies.push(body);
        egDocuments.push(document);
        egSignatures.push(a.signature);
    }

    function _egImport() private returns (Successor memory next) {
        next = _ehCutover();
        bytes32 before_ = _egCheckpoints(suite.owners);
        RH.Request memory request = _ehRequest();
        Commit.Prepared memory prepared =
            Prepared.prepare(next.coordinator.suiteConfiguration(), request);
        request.expectedSemanticInventory = Prepared.inventory(prepared);
        for (uint8 i; i < 7; ++i) {
            (RH.ExportHeader memory h,) = Payload.decode(prepared.data[i].typedState, i);
            require(
                (h.requiredFeatures & RH.BINDING_GENERATIONS) != 0,
                "all seven owners require original generation transport"
            );
        }
        require(
            executeSafe(
                artist,
                keys,
                address(next.registry),
                0,
                abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (request)),
                0
            ),
            "original Safe selector imports complete generations"
        );
        _ehImported(next, prepared, HydrationOwner(next.identity).authorityHydrationCommitment());
        require(
            _egCheckpoints(suite.owners) == before_, "import preserves exact sealed source state"
        );
    }

    function _egAssert(T.SuiteConfiguration memory target, uint32 capabilities) private view {
        require(
            _egHistory(target) == egBindings,
            "all current and historical bindings, terms and terminals retained"
        );
        bytes32 bindingHash = BindingOwner(target.owners[0]).binding(1).bindingHash;
        require(
            AcceptanceOwner(target.owners[3]).acceptanceRecord(bindingHash) == egAcceptance
                && AcceptanceOwner(target.owners[3]).acceptedAt(bindingHash) == egAcceptedAt,
            "exact sole accepted binding proof"
        );
        require(
            IStreamArtistEstateOwner(target.owners[2])
            .currentAuthorityCapabilities(artistId)
            .effectiveCapabilities == capabilities,
            "estate rights remain exact"
        );
        for (uint256 i; i < egRevisions.length; ++i) {
            require(
                keccak256(
                    abi.encode(
                        IStreamArtistIdentityRevision(target.registry)
                            .identityRevisionRecord(egRevisions[i])
                    )
                ) == keccak256(abi.encode(egRevisionBodies[i])),
                "full original25 retained under its original hash"
            );
            require(
                keccak256(
                    IStreamArtistIdentityRevision(target.registry)
                        .identityDocumentBytes(keccak256(egDocuments[i]))
                ) == keccak256(egDocuments[i]),
                "full original document retained"
            );
            require(
                keccak256(
                        IStreamArtistIdentityOwner(target.owners[2]).signatureBundle(egRevisions[i])
                    ) == keccak256(egSignatures[i])
                    && IStreamArtistIdentityOwner(target.owners[2])
                        .nonceUsed(artistId, egRevisionBodies[i].nonce),
                "original25 signature and spent nonce retained"
            );
        }
    }

    function _egHistory(T.SuiteConfiguration memory target) private view returns (bytes32 value) {
        value = keccak256(abi.encode(BindingOwner(target.owners[0]).binding(1)));
        for (uint64 generation = 1; generation <= egGeneration; ++generation) {
            value = keccak256(
                abi.encode(
                    value,
                    BindingOwner(target.owners[0]).bindingAt(1, generation),
                    TermsOwner(target.owners[0]).bindingTerms(1, generation),
                    TerminalOwner(target.owners[0]).bindingTermination(1, generation)
                )
            );
        }
    }

    function _egCheckpoints(address[7] memory owners) private view returns (bytes32 value) {
        for (uint8 i; i < 7; ++i) {
            value = keccak256(
                abi.encode(
                    value, CP(owners[i]).authorityCheckpoint(), Publications.collect(owners[i], i)
                )
            );
        }
    }
}
