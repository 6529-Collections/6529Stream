// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistPrimaryCollaboratorFixture.sol";
import {
    StreamArtistCompleteHistoryAdmission as CHRAdmission
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryAdmission.sol";
import {
    StreamArtistRecoveredHydrationAdmission as CHRCertificate
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationAdmission.sol";
import {
    StreamArtistCompleteHistoryPreparationPrincipals as CHRPrincipals
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryPreparationPrincipals.sol";
import {
    StreamArtistCompleteHistoryComposition as CHRComposition
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryComposition.sol";
import {
    StreamArtistCompleteHistoryWitnesses as CHRWitnesses
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryWitnesses.sol";
import {
    StreamArtistCompleteHistoryTypes as CHRTypes
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryTypes.sol";
import {
    StreamArtistRecoveredMultipleDisputeTypes as CHRDisputes
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleDisputeTypes.sol";
import {
    StreamArtistAttributionDisputeTypes as CHRFiling
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    StreamArtistRepudiationTypes as CHRRepudiation
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as CHRFrame
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredIdentitySourceFrame.sol";

/// @notice A real original PC op60 precedes new original producers and a second governed cutover.
/// @dev Runtime validation is pending the combined native cohort. Core and scheduled governance
/// are inherited unit boundaries; imported state, provenance, signatures and receipts are real.
contract StreamArtistCompleteHistoryRepeatedCompositionActualTest is
    ArtistPrimaryCollaboratorFixture
{
    struct Repeated {
        T.SuiteConfiguration original;
        T.SuiteConfiguration destination;
        RH.Provenance first;
        PC.Proof firstProof;
        RH.Request request;
        CHRCertificate.Certificate certificate;
        uint64[7] importedAt;
        bytes32 firstValue;
        bytes32 firstSemantics;
        bytes32 originalFacts;
        bytes32 oldBinding;
        bytes32 latest;
        bytes32 repudiation;
        bytes32 repudiationSignature;
    }

    function testCompleteRepeatedCompositionActualPCImportThenNewBPendingKeepsBothEras() external {
        Repeated memory x = _repeatedSource();
        (CHRPrincipals.Result memory principals, CHRComposition.Result memory result) = _compose(x);
        _assertProvenance(x, result);
        _assertPrincipals(x, principals, result);
        _assertFamilies(x, result);
        require(
            _sourceFacts(x.original) == x.originalFacts
                && _pcSemantics(x.original) == x.firstSemantics
                && _pcSemantics(suite) == x.firstSemantics,
            "sealed first source and every imported original keyed record remain exact"
        );
        require(
            (result.features & (CHRTypes.FEATURE | RH.REPEATED_IMPORT | RH.BINDING_CORRECTIONS))
                    == (CHRTypes.FEATURE | RH.REPEATED_IMPORT | RH.BINDING_CORRECTIONS)
                && (result.features & ~CHRTypes.ALLOWED) == 0,
            "complete semantic features include actual repeated import and correction"
        );
        for (uint8 i; i < 7; ++i) {
            require(
                HydrationOwner(x.destination.owners[i]).authorityHydrationCommitment() == 0
                    && Native(x.destination.owners[i]).artistNativeReceiptCount() == 0,
                "second cutover and source composition never claim a CT import"
            );
        }
    }

    function testCompleteRepeatedCompositionActualRejectsOmittedImportedAccountReplayAlias()
        external
    {
        Repeated memory x = _repeatedSource();
        // The omitted witness names the real sparse nonce used before the first import.
        // Keep all other preimages and the authentic expected source checkpoint untouched.
        bytes32 surface = keccak256("identity_authority.replay.collaborator_account_nonce");
        bytes32 scope = keccak256(abi.encode(pcProposal.account, uint256(300)));
        AH.Origin[] memory original = x.request.records.authority.replayOrigins[2];
        AH.Origin[] memory omitted = new AH.Origin[](original.length - 1);
        uint256 cursor;
        bool found;
        for (uint256 i; i < original.length; ++i) {
            if (original[i].surface == surface && original[i].scope == scope) {
                require(!found, "one actual imported sparse account key");
                found = true;
            } else {
                require(cursor < omitted.length, "actual imported alias must be present");
                omitted[cursor++] = original[i];
            }
        }
        require(found && cursor == omitted.length, "removed only original account replay alias");
        x.request.records.authority.replayOrigins[2] = omitted;
        avm.expectRevert(RH.InvalidRecoveredHydrationProvenance.selector);
        CHRAdmission.collect(x.destination, x.request);
        x.request.records.authority.replayOrigins[2] = original;
        CHRCertificate.Certificate memory restored = CHRAdmission.collect(x.destination, x.request);
        require(
            RH.provenanceHash(restored.provenance) == RH.provenanceHash(x.certificate.provenance),
            "restored exact original preimages reproduce both authentic eras"
        );
        (, CHRComposition.Result memory result) = _compose(x);
        require(
            keccak256(abi.encode(result.inventory.accounts))
                == keccak256(abi.encode(x.firstProof.accounts)),
            "the full composition retains the original account nonce lane"
        );
    }

    function _repeatedSource() private returns (Repeated memory x) {
        _pcSource(0);
        require(
            address(artist) == address(rotationSafe)
                && IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).authorityAddress
                    == address(rotationSafe),
            "original PC source really recovered A to the rotation Safe"
        );
        x.original = suite;
        x.oldBinding = Binding(suite.owners[0]).binding(2).bindingHash;
        Successor memory middle = _multiCutover();
        (RH.Request memory request, Commit.Prepared memory first) = _pcPrepare(middle);
        _pcImport(middle, request, first);
        x.first = first.admission.provenance;
        (x.firstProof,) = _pcProof(first, 0);
        x.firstValue = HydrationOwner(middle.identity).authorityHydrationCommitment();
        x.firstSemantics = _pcSemantics(suite);
        x.originalFacts = _sourceFacts(suite);
        for (uint8 i; i < 7; ++i) {
            (,, x.importedAt[i]) = RecoveredOwner(middle.coordinator.suiteConfiguration().owners[i])
                .recoveredHydrationImportedPrefix();
        }
        _rhAdopt(middle);
        require(
            address(artist) == address(rotationSafe)
                && IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).authorityAddress
                    == address(artist),
            "successor signing uses the original recovered authority"
        );
        (x.repudiation, x.repudiationSignature) = _repudiate();
        x.latest = _newPrincipalCorrection(x.repudiation);
        multiCollectionArtists[1] = x.latest;
        multiArtists.push(x.latest);
        for (uint256 i; i < multiArtists.length; ++i) {
            for (uint256 j; j < i; ++j) {
                if (multiArtists[i] < multiArtists[j]) {
                    (multiArtists[i], multiArtists[j]) = (multiArtists[j], multiArtists[i]);
                }
            }
        }
        Successor memory last = _multiCutover();
        x.destination = last.coordinator.suiteConfiguration();
        x.request = _multiRequest();
        x.certificate = CHRAdmission.collect(x.destination, x.request);
    }

    function _repudiate() private returns (bytes32 record, bytes32 signatureHash) {
        T.Binding memory previous = Binding(suite.owners[0]).binding(2);
        require(previous.accepted && previous.generation == 1, "real imported accepted generation");
        CHRFiling.Filing memory filing = CHRFiling.Filing(
            2, previous.generation, 4, 0, keccak256("successor original signed repudiation")
        );
        T.Authorization memory authorization = T.Authorization(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint,
            uint64(block.timestamp + 1 days),
            ""
        );
        bytes32 digest = ingress.attributionRepudiationDigest(filing, authorization);
        authorization.signature = _signature(digest);
        uint256 identityCount = Native(suite.owners[2]).artistNativeReceiptCount();
        record = ingress.revokeAttribution(filing, authorization);
        _rhAuthorization(digest, authorization.nonce);
        _rhCandidate(4, "attribution_lifecycle.replay.repudiation_key", record);
        CHRRepudiation.Record memory actual = ingress.attributionRepudiationRecord(record);
        signatureHash = keccak256(authorization.signature);
        require(
            actual.artistId == artistId && actual.signer == address(artist)
                && actual.bindingHash == previous.bindingHash && actual.nonce == authorization.nonce
                && authorization.signature.length != 0
                && keccak256(IStreamArtistIdentityOwner(suite.owners[2]).signatureBundle(record))
                    == signatureHash
                && Native(suite.owners[2]).artistNativeReceiptCount() == identityCount,
            "original47 stores real signature and nonce without an Identity native receipt"
        );
        vm.warp(actual.executableAt);
        ingress.executeAttributionRepudiation(2, record);
        _rhCandidate(4, "attribution_lifecycle.replay.repudiation_execution_key", record);
        require(
            ingress.attributionRepudiationTerminal(record).phase == 4
                && Native(suite.owners[4]).artistNativeReceiptCount() == 1
                && Native(suite.owners[2]).artistNativeReceiptCount() == identityCount,
            "actual50 terminal creates no fabricated native occurrence"
        );
    }

    function _newPrincipalCorrection(bytes32 repudiation) private returns (bytes32 latest) {
        bytes memory document = bytes("repeated complete history new B identity");
        T.BindingProposal memory proposal = _proposal(bytes32(0));
        proposal.artistAddress = address(0xB0B);
        proposal.identityRecordHash = keccak256(document);
        proposal.identityRecordURI = "urn:complete:repeated:new-b";
        proposal.reasonHash = keccak256("successor original new B correction");
        uint256 allocation = IStreamArtistIdentityOwner(suite.owners[2]).nextRegistrationNonce();
        require(allocation == 2, "first import retained the real global allocator");
        (PCBC.Context memory context, PCBC.Approval memory proposed) = PCCorrectionAdmission.context(
            suite, 2, proposal, document, "Successor correction B", repudiation
        );
        require(
            proposed.cause == 3 && proposed.causeRecord == repudiation, "actual executed cause3"
        );
        address authority = manager.governanceAuthority();
        ArtistUnitRoles(suite.roleRegistry).setAdmin(authority, true);
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        ArtistUnitGovernance(authority)
            .configureContestReads(
                suite.roleRegistry,
                address(artist),
                proposal.reasonHash,
                "urn:complete:repeated:correction"
            );
        bytes32 action = keccak256(abi.encode("successor real new B correction", context));
        ArtistUnitGovernance(authority)
            .executeModuleContextWithAction(
                action,
                address(ingress),
                abi.encodeCall(
                    PCCorrection.proposeArtistBindingAfterRevocation,
                    (uint256(2), proposal, document, "Successor correction B", repudiation)
                ),
                2,
                context.scopeHash,
                context.oldValueHash,
                context.newValueHash
            );
        _rhCandidate(0, "binding_lifecycle.replay.correction_action", action);
        _rhCandidate(
            0, "binding_lifecycle.replay.proposal_key", keccak256(abi.encode(uint256(2), uint64(2)))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(abi.encode(bytes32(0), allocation))
        );
        T.Binding memory head = Binding(suite.owners[0]).binding(2);
        latest = head.artistId;
        require(
            latest == proposed.proposedArtistId && latest != artistId && latest != collaboratorId
                && head.generation == 2 && !head.accepted,
            "authentic newly registered B is the pending latest head"
        );
    }

    function _compose(Repeated memory x)
        private
        view
        returns (CHRPrincipals.Result memory principals, CHRComposition.Result memory result)
    {
        principals = CHRPrincipals.collect(x.certificate);
        M.State memory scope;
        scope.artists = x.certificate.artists;
        scope.collections = x.certificate.collections;
        CHRWitnesses.Plan memory witnesses = CHRWitnesses.collect(
            x.certificate.source,
            x.certificate.provenance,
            scope,
            x.request.records.witnesses,
            new T.RoyaltyFreeze[](0)
        );
        result = CHRComposition.collect(
            CHRComposition.Context(
                x.certificate, principals.principals, witnesses, principals.features
            )
        );
    }

    function _assertProvenance(Repeated memory x, CHRComposition.Result memory result)
        private
        view
    {
        RH.Provenance memory p = result.inventory.provenance;
        require(
            x.first.eras.length == 1 && p.eras.length == 2
                && p.origins[0].registry == x.original.registry
                && p.origins[1].registry == address(ingress)
                && p.origins[0].registry != p.origins[1].registry
                && p.eras[1].priorImportCommitment == x.firstValue
                && x.request.expectedSourceImportCommitment == x.firstValue
                && keccak256(abi.encode(p.eras[0])) == keccak256(abi.encode(x.first.eras[0])),
            "real first import supplies the exact retained era and second import boundary"
        );
        for (uint8 owner; owner < 7; ++owner) {
            uint256 added = owner == 0 || owner == 2 || owner == 4 ? 1 : 0;
            require(
                p.eras[1].nativeCounts[owner] == added
                    && p.eras[1].lowerRevisions[owner] == x.importedAt[owner]
                    && p.journals[owner].length == x.first.journals[owner].length + added,
                "only genuine successor producer receipts extend the imported era"
            );
            for (uint256 i; i < x.first.journals[owner].length; ++i) {
                require(
                    keccak256(abi.encode(p.journals[owner][i]))
                        == keccak256(abi.encode(x.first.journals[owner][i])),
                    "every original receipt, native index and original point survives"
                );
            }
            if (added != 0) {
                RH.JournalEntry memory fresh = p.journals[owner][p.journals[owner].length - 1];
                require(
                    fresh.position.nativeIndex == 0
                        && fresh.position.point.environmentHash == p.eras[1].originHash
                        && fresh.receipt.operation == (owner == 4 ? 47 : 1),
                    "fresh occurrence has actual successor domain and original local index"
                );
            }
        }
        _assertRecoveryPoint(x);
        for (uint256 i; i < x.firstProof.archive.operations.length; ++i) {
            require(
                keccak256(abi.encode(result.inventory.archive.operations[i]))
                    == keccak256(abi.encode(x.firstProof.archive.operations[i])),
                "original Archive occurrence and pointer prefix remain exact"
            );
        }
        require(
            result.inventory.archive.operations.length
                == x.firstProof.archive.operations.length + 3,
            "only original successor47, terminal50 and corrective1 extend the family catalogue"
        );
        uint256 at = x.firstProof.archive.operations.length;
        require(
            result.inventory.archive.operations[at].operation == 47
                && result.inventory.archive.operations[at + 1].operation == 50
                && result.inventory.archive.operations[at + 2].operation == 1,
            "actual Archive operations retain producer order"
        );
    }

    function _assertRecoveryPoint(Repeated memory x) private view {
        bool found;
        bytes32 kind = keccak256("identity_authority.hydration.guardian_vesting");
        RH.Point memory imported =
            RecoveredOwner(suite.owners[2]).recoveredHydrationAuxiliaryPoint(kind, rhRecovery);
        RH.Point memory originalPoint =
            RecoveredOwner(x.original.owners[2]).recoveredHydrationAuxiliaryPoint(kind, rhRecovery);
        require(
            keccak256(abi.encode(imported)) == keccak256(abi.encode(originalPoint))
                && _rhRecoveryFacts(suite.owners[2]) == _rhRecoveryFacts(x.original.owners[2]),
            "original recovery and vesting artifact point survive real import and fresh producers"
        );
        for (uint256 i; i < x.first.journals[2].length; ++i) {
            RH.JournalEntry memory original = x.first.journals[2][i];
            if (original.receipt.operation != 35 || original.receipt.recordHash != rhRecovery) {
                continue;
            }
            require(!found, "one genuine primary recovery occurrence");
            found = true;
            require(
                keccak256(abi.encode(imported)) == keccak256(abi.encode(original.position.point)),
                "vesting artifact keeps the first native point, never the import revision"
            );
        }
        require(found, "actual first-era primary recovery exists");
    }

    function _assertPrincipals(
        Repeated memory x,
        CHRPrincipals.Result memory principals,
        CHRComposition.Result memory result
    ) private view {
        require(
            x.certificate.artists.length == 3 && principals.principals.identities.length == 3
                && x.certificate.collections[0].artistId == artistId
                && x.certificate.collections[1].artistId == x.latest,
            "former A, collaborator and new B coexist beside actual current collection heads"
        );
        bool former;
        bool collaborator;
        bool latest;
        bool signedRepudiation;
        for (uint256 i; i < principals.principals.identities.length; ++i) {
            (bytes32 id, uint256 recoveries, bool hasSignature) = this.repeatedPrincipalFacts(
                principals.principals.identities[i], x.repudiation, x.repudiationSignature
            );
            require(
                id == x.certificate.artists[i].artistId,
                "every canonical principal shares the authentic global allocator"
            );
            if (id == artistId) {
                former = true;
                require(recoveries != 0, "original A recovery retained");
                signedRepudiation = hasSignature;
            } else if (id == collaboratorId) {
                collaborator = true;
                require(
                    recoveries == 0 && !hasSignature, "ordinary collaborator stays zero recovery"
                );
            } else if (id == x.latest) {
                latest = true;
                require(recoveries == 0 && !hasSignature, "new pending B has no invented recovery");
            }
        }
        require(
            former && collaborator && latest && signedRepudiation,
            "complete principal and signature union"
        );
        require(
            x.firstProof.accounts.length != 0
                && keccak256(abi.encode(result.inventory.accounts))
                    == keccak256(abi.encode(x.firstProof.accounts)),
            "first-era sparse account lane survives the second composition exactly"
        );
        (bool used, uint256 hint) =
            ingress.collaboratorRegistrationNonceState(pcProposal.account, 300);
        require(used && hint == 0, "actual account nonce300 stays consumed with original zero hint");
    }

    function repeatedPrincipalFacts(bytes calldata raw, bytes32 record, bytes32 signatureHash)
        external
        pure
        returns (bytes32 id, uint256 recoveries, bool hasSignature)
    {
        IH.Bundle calldata identity = CHRFrame.bundle(raw);
        require(identity.nextRegistrationNonce == 3, "authentic shared next registration nonce");
        id = identity.artistId;
        recoveries = identity.recoveries.length;
        for (uint256 i; i < identity.signatures.length; ++i) {
            if (identity.signatures[i].recordHash != record) continue;
            require(!hasSignature, "one actual signed47 body");
            hasSignature = true;
            require(
                keccak256(identity.signatures[i].signature) == signatureHash,
                "real successor47 signature stays with former A"
            );
        }
    }

    function _assertFamilies(Repeated memory x, CHRComposition.Result memory result) private pure {
        require(
            result.inventory.bindings.bindings[1].bindings.rows.length == 2
                && result.inventory.bindings.bindings[1].bindings.rows[0].item.bindingHash
                    == x.oldBinding
                && result.inventory.bindings.bindings[1].bindings.rows[0].item.accepted
                && result.inventory.bindings.bindings[1].bindings.current.artistId == x.latest
                && !result.inventory.bindings.bindings[1].bindings.current.accepted
                && result.inventory.bindings.bindings[1].corrections[1].approval.cause == 3
                && result.inventory.bindings.bindings[1].corrections[1].approval.causeRecord
                    == x.repudiation
                && result.inventory.bindings.bindings[1].corrections[1].approval.registrationNonce
                    == 2,
            "accepted former generation and exact executed cause retain the new pending principal"
        );
        require(
            keccak256(abi.encode(result.inventory.archive.accepted))
                    == keccak256(abi.encode(x.firstProof.archive.accepted))
                && result.inventory.accepted[1].rows.length == 2
                && keccak256(abi.encode(result.inventory.accepted[1].rows[0]))
                    == keccak256(abi.encode(x.firstProof.accepted[1].rows[0]))
                && result.inventory.accepted[1].rows[1].recordHash == 0,
            "original collaborator and primary accepts survive without inventing new B acceptance"
        );
        CHRDisputes.Attribution memory attribution =
            abi.decode(result.attribution[1], (CHRDisputes.Attribution));
        require(
            attribution.history.repudiations.length == 1
                && attribution.history.repudiations[0].record.recordHash == x.repudiation
                && attribution.history.repudiations[0].terminal.phase == 4
                && attribution.history.repudiations[0].point.environmentHash
                    == result.inventory.provenance.eras[1].originHash
                && attribution.history.repudiations[0].terminalPoint.environmentHash
                    == result.inventory.provenance.eras[1].originHash
                && attribution.history.current.state == 1 && attribution.history.pending == 0,
            "actual signed47 and executed50 coexist with latest pending attribution"
        );
    }

    function _sourceFacts(T.SuiteConfiguration memory source) private view returns (bytes32 hash) {
        for (uint8 i; i < 7; ++i) {
            hash = keccak256(
                abi.encode(
                    hash,
                    Owner(source.owners[i]).ownerStateSnapshotV2(),
                    CP(source.owners[i]).authorityCheckpoint(),
                    Native(source.owners[i]).artistNativeReceiptCount()
                )
            );
        }
    }
}
