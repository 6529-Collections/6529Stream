// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistRecoveredHistoryContentFixture.sol";
import {
    StreamArtistPlatformTypes as PW
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistPlatformTypes.sol";
import {
    IStreamArtistPlatformWorks,
    IStreamArtistPlatformOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPlatformWorks.sol";
import {
    IStreamArtistAttributionClaims,
    IStreamArtistAttributionClaimsOwner,
    StreamArtistAttributionClaimTypes as AC
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionClaims.sol";
import {
    StreamArtistPlatformCorrectionLineageTypes as PL,
    IStreamArtistPlatformCorrectionLineage as Lineage
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPlatformCorrectionLineage.sol";
import {
    StreamArtistRecoveredPlatformTypes as HP
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredPlatformCodec as HPCodec
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPlatformCodec.sol";
import {
    StreamArtistRecoveredPlatformCatalogue as HPCatalogue
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPlatformCatalogue.sol";
import {
    StreamArtistBindingLifecycleTypes as L
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import {
    IStreamArtistAttributionOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    IStreamRecoveredPlatformClaimHead
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPlatformSource.sol";

/// @notice Actual original Platform, correction, recovery, seven owners, Archive and threshold Safe.
/// @dev Core, governance eligibility and coverage are the inherited typed boundaries; the original
/// Store bytes, Platform producers, current action lifetime, owner guards and history are actual.
abstract contract ArtistRecoveredPlatformFixture is ArtistRecoveredHistoryContentFixture {
    bytes32 internal firstPlatformClaim;
    bytes32[] internal platformClaims;
    bytes32[] internal platformContests;
    bytes32[] internal allegations;

    function _beforeInitialBindingProposal() internal virtual override {
        bytes32 statement = keccak256("original Platform declaration before Artist registration");
        bytes32 record = ingress.declarePlatformWorks(1, statement);
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PLATFORM_WORKS_DECLARATION_V1"),
                        block.chainid,
                        address(ingress),
                        address(core),
                        uint256(1),
                        statement,
                        uint64(block.timestamp)
                    )
                ),
            "literal original8 record"
        );
        _hpGuard(8, bytes32(uint256(1)));
        firstPlatformClaim = _hpClaim(false);
        _hpContest(1, firstPlatformClaim, false);
        _hpContest(3, firstPlatformClaim, false);
        _hpContest(3, firstPlatformClaim, true);
        require(
            artistId == 0 && ingress.platformWorksState(1).correction.correctiveGeneration == 0,
            "no Artist association invented before original proposal"
        );
    }

    function _hpEvidence(bytes32 claim, bytes32 narrative) internal returns (bytes32 hash) {
        if (address(documents) == address(0)) documents = new StreamSchemaDocumentStore();
        (hash,) = documents.publishChunk(
            abi.encode(PW.Evidence(1, 1, address(artist), claim, narrative))
        );
        avm.mockCall(
            address(metadata),
            abi.encodeCall(IStreamCollectionMetadataV1.core, ()),
            abi.encode(address(core))
        );
        avm.mockCall(
            address(metadata),
            abi.encodeCall(IStreamCollectionMetadataV1.chunkStore, ()),
            abi.encode(address(documents))
        );
        Archival.CoverageFacts memory facts;
        facts.coverageRecordHash = keccak256(abi.encode("typed collection coverage", hash));
        facts.envelopeHash = keccak256(abi.encode("typed Platform envelope", hash));
        facts.evidenceHash = hash;
        avm.mockCall(
            address(estateCoverageProvider),
            abi.encodeCall(
                IStreamCollectionArchivalCoverage.requireCollectionEvidence, (uint256(1), hash)
            ),
            abi.encode(facts)
        );
    }

    function _hpGuard(uint16 op, bytes32 scope) internal {
        _rhCandidate(4, string(abi.encode("PLATFORM_WORKS", op)), scope);
    }

    function _hpClaim(bool allegation) internal returns (bytes32 record) {
        bytes32 evidence =
            _hpEvidence(0, keccak256(abi.encode("new original claim", ++actionNonce)));
        bytes32 scope = keccak256(abi.encode(uint256(1), address(this), evidence, evidence));
        if (allegation) {
            record = ingress.fileAttributionClaim(1, evidence, evidence, "urn:platform:allegation");
            _rhCandidate(4, "attribution_lifecycle.replay.claim_record_hash_uniqueness", scope);
            allegations.push(record);
        } else {
            record = ingress.filePlatformWorksClaim(1, evidence, evidence, "urn:platform:claim");
            _hpGuard(9, scope);
            platformClaims.push(record);
        }
        require(
            record
                == keccak256(
                    abi.encode(
                        allegation
                            ? keccak256("6529STREAM_ARTIST_ATTRIBUTION_CLAIM_RECORD_V1")
                            : keccak256("6529STREAM_PLATFORM_WORKS_CLAIM_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(core),
                        uint256(1),
                        address(this),
                        evidence,
                        evidence,
                        uint64(block.timestamp)
                    )
                ),
            "literal original claim preimage"
        );
    }

    function _hpContest(uint8 state, bytes32 claim, bool correction)
        internal
        returns (bytes32 record)
    {
        bytes32 evidence = _hpEvidence(
            claim, keccak256(abi.encode("exact Platform adjudication", ++actionNonce))
        );
        PW.Context memory c =
            ingress.platformWorksContext(1, state, claim, evidence, evidence, correction);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        authority.configureContestReads(
            suite.roleRegistry, address(artist), evidence, "urn:platform:resolution"
        );
        uint8 cls = correction ? 2 : 1;
        bytes32 action =
            keccak256(abi.encode("Platform actual action", address(ingress), actionNonce, c));
        bytes memory data = correction
            ? abi.encodeCall(
                IStreamArtistPlatformWorks.approvePlatformWorksCorrection,
                (uint256(1), claim, evidence, evidence)
            )
            : abi.encodeCall(
                IStreamArtistPlatformWorks.setPlatformWorksContest,
                (uint256(1), state, claim, evidence, evidence)
            );
        require(
            executeSafe(
                artist,
                keys,
                address(authority),
                0,
                abi.encodeCall(
                    ArtistUnitGovernance.executeModuleContextWithAction,
                    (
                        action,
                        address(ingress),
                        data,
                        cls,
                        c.scopeHash,
                        c.oldValueHash,
                        c.newValueHash
                    )
                ),
                0
            ),
            "actual Safe governed Platform producer"
        );
        (bool active,,,,,) = authority.currentAction();
        require(!active, "actual context cleared without persistent mock");
        _hpGuard(correction ? 53 : 11, keccak256(abi.encode(uint256(1), action)));
        PW.State memory p = ingress.platformWorksState(1);
        record = correction ? p.correction.recordHash : p.contestRecord;
        if (!correction) platformContests.push(record);
    }

    function _hpPendingTerminal(bool withdrawal) internal {
        T.Binding memory b = Binding(suite.owners[0]).binding(1);
        L.Termination memory terms = _termination(1);
        if (withdrawal) {
            ingress.withdrawArtistBinding(terms);
            _rhCandidate(
                0,
                "binding_lifecycle.replay.proposal_terminal_transition_key",
                keccak256(abi.encode(uint256(1), b.generation))
            );
        } else {
            T.Authorization memory a = _authorization(false);
            bytes32 digest = ingress.bindingRefusalDigest(terms, a);
            a.signature = _signature(digest);
            ingress.refuseArtistBinding(terms, a);
            _rhAuthorization(digest, a.nonce);
            _rhCandidate(
                0,
                "binding_lifecycle.replay.refusal_uniqueness",
                keccak256(abi.encode(uint256(1), b.generation))
            );
        }
        _hpContinue(0, false);
        _rhCandidate(
            3,
            "acceptance_lifecycle.replay.record_uniqueness",
            keccak256(abi.encode(uint256(1), uint64(2), uint8(1), address(artist)))
        );
    }

    function _hpContinue(bytes32 witness, bool acceptNew) internal {
        T.Binding memory previous = Binding(suite.owners[0]).binding(1);
        T.Identity memory identity = Identity(suite.owners[2]).identity(artistId);
        T.BindingProposal memory proposal = _proposal(artistId);
        proposal.identityRecordHash = identity.identityRecordHash;
        proposal.reasonHash =
            keccak256(abi.encode("fresh Platform continuation", previous.generation));
        bytes memory document =
            Identity(suite.owners[2]).identityDocumentBytes(identity.identityRecordHash);
        (BC.Context memory c,) =
            Admission.context(suite, 1, proposal, document, identity.displayName, witness);
        ArtistUnitRoles(suite.roleRegistry).setAdmin(manager.governanceAuthority(), true);
        bytes32 action = _govern(
            abi.encodeCall(
                Correction.proposeArtistBindingAfterRevocation,
                (uint256(1), proposal, document, identity.displayName, witness)
            ),
            AD.Context(c.scopeHash, c.oldValueHash, c.newValueHash, 2, 0),
            proposal.reasonHash,
            2
        );
        _rhCandidate(0, "binding_lifecycle.replay.correction_action", action);
        _rhCandidate(
            0,
            "binding_lifecycle.replay.proposal_key",
            keccak256(abi.encode(uint256(1), previous.generation + 1))
        );
        if (!acceptNew) return;
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.acceptanceDigest(1, a);
        a.signature = _signature(digest);
        _artistCall(abi.encodeCall(IStreamArtistOnboarding.acceptArtistBinding, (uint256(1), a)));
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(
            3,
            "acceptance_lifecycle.replay.record_uniqueness",
            keccak256(abi.encode(uint256(1), previous.generation + 1, uint8(1), address(artist)))
        );
        _saveAcceptance();
    }

    function _hpPrepare(Successor memory next)
        internal
        view
        returns (RH.Request memory r, Commit.Prepared memory p, HP.Bundle memory b)
    {
        (r, p) = _hcPrepare(next);
        (RH.ExportHeader memory h, Payload.Payload memory local) =
            Payload.decode(p.data[4].typedState, 4);
        require((h.requiredFeatures & 65536) != 0, "explicit Platform capability");
        b = HPCodec.decode(p.query, local.provenance, local.semanticState);
        bytes[4] memory parts = [
            abi.encode(b.original),
            abi.encode(b.sanctions),
            abi.encode(b.platform),
            abi.encode(b.bindings)
        ];
        require(
            keccak256(local.semanticState)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_RECOVERED_PLATFORM_HISTORY_V1"),
                        uint16(1),
                        parts
                    )
                ),
            "literal owner4 tag/body"
        );
        uint256 zeroArtist;
        for (uint256 i; i < p.admission.provenance.journals[4].length; ++i) {
            HT.Receipt memory row = p.admission.provenance.journals[4][i].receipt;
            if (!HP.nativeOperation(row.operation)) continue;
            require(row.artistId == 0 && row.collectionId == 1, "original collection-only receipt");
            ++zeroArtist;
            for (uint256 k; k < p.admission.artists[0].records.length; ++k) {
                require(
                    row.recordHash != p.admission.artists[0].records[k],
                    "never synthesise Artist lane association"
                );
            }
        }
        require(zeroArtist == HP.nativeCount(b.platform), "complete original Platform denominator");
    }

    function _hpImport(
        Successor memory next,
        RH.Request memory r,
        Commit.Prepared memory p,
        HP.Bundle memory b
    ) internal {
        _hcImport(next, r, p);
        _hpAssert(next.coordinator.suiteConfiguration(), b);
    }

    function _hpAssert(T.SuiteConfiguration memory target, HP.Bundle memory b) internal view {
        IStreamArtistPlatformOwner owner = IStreamArtistPlatformOwner(target.owners[4]);
        require(
            keccak256(abi.encode(owner.platformWorksState(1)))
                == keccak256(abi.encode(b.platform.state)),
            "original twenty-word PW state"
        );
        for (uint256 i; i < b.platform.claims.length; ++i) {
            require(
                keccak256(
                    abi.encode(
                        owner.platformWorksClaimRecord(b.platform.claims[i].record.recordHash)
                    )
                ) == keccak256(abi.encode(b.platform.claims[i].record)),
                "full original claim"
            );
        }
        for (uint256 i; i < b.platform.contests.length; ++i) {
            require(
                keccak256(
                    abi.encode(
                        owner.platformWorksContestRecord(b.platform.contests[i].record.recordHash)
                    )
                ) == keccak256(abi.encode(b.platform.contests[i].record)),
                "full original contest"
            );
        }
        IStreamArtistAttributionClaimsOwner claims =
            IStreamArtistAttributionClaimsOwner(target.owners[4]);
        for (uint256 i; i < b.platform.allegations.length; ++i) {
            require(
                keccak256(
                    abi.encode(
                        claims.attributionClaimRecord(b.platform.allegations[i].record.recordHash)
                    )
                ) == keccak256(abi.encode(b.platform.allegations[i].record)),
                "full original allegation"
            );
        }
        (uint256 count, bytes32 latest) =
            IStreamRecoveredPlatformClaimHead(target.owners[4]).attributionClaims(1);
        require(
            count == b.platform.state.claimCount + b.platform.allegationCount
                && latest == b.platform.latestDisplayClaim,
            "combined display head"
        );
        Lineage lineage = Lineage(target.owners[4]);
        require(
            keccak256(abi.encode(lineage.platformCorrectionStatus(1)))
                == keccak256(abi.encode(b.platform.status)),
            "full retained sticky status"
        );
        for (uint256 i; i < b.platform.continuations.length; ++i) {
            HP.ContinuationRow memory row = b.platform.continuations[i];
            require(
                keccak256(abi.encode(lineage.platformCorrectionLineage(row.record.recordHash)))
                    == keccak256(abi.encode(row.record)),
                "original continuation body"
            );
            require(
                keccak256(abi.encode(lineage.platformCorrectionAcceptance(row.record.recordHash)))
                    == keccak256(abi.encode(row.acceptance)),
                "original continuation acceptance"
            );
        }
        _assertDisputeImport(target, b.original);
    }

    function platformValidate(
        AH.Query calldata q,
        RH.OwnerProvenance calldata p,
        bytes calldata raw
    ) external view {
        HPCodec.decode(q, p, raw);
    }
}
