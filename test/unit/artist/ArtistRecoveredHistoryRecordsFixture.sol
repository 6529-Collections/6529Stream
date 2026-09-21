// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationGuards as Guards
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationGuards.sol";
import "./ArtistRecoveredPlatformFixture.sol";
import {
    StreamArtistRecoveredHistoryRecordTypes as HR
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHistoryRecordTypes.sol";
import {
    StreamArtistRecoveredHistoryRecordParts as HRParts
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHistoryRecordParts.sol";
import {
    StreamArtistRecoveredHistoryRecordValidation as HRValidation
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHistoryRecordValidation.sol";
import {
    StreamArtistRecoveredAttestationHydration as AttestationHistory
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAttestationHydration.sol";
import {
    IStreamArtistC2PAReads as CredentialRead
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistC2PA.sol";
import {
    IStreamArtistPersonhoodEvidence as PersonhoodRead,
    StreamArtistPersonhoodTypes as PersonhoodTypes
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPersonhoodEvidence.sol";
import {
    IStreamCollectionAttestations as Subjects
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionAttestations.sol";
import {
    IStreamGeneralAttestations as General
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamGeneralAttestations.sol";
import {
    StreamGeneralAttestationDefinitions as GeneralDefinitions
} from "../../../smart-contracts/domains/metadata/StreamGeneralAttestationDefinitions.sol";
import {
    StreamOwnerNoticeTypes as Notice
} from "../../../smart-contracts/interfaces/stream/metadata/StreamOwnerNoticeTypes.sol";

import { PersonhoodDocumentFixture } from "./StreamArtistPersonhoodEvidence.t.sol";
import {
    StreamArtistC2PATypes as C2PA,
    IStreamArtistC2PAReads as Credentials
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistC2PA.sol";
import {
    StreamArtistAttestationTypes as Attest
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttestationWriter.sol";
import {
    IStreamArtistAttributionOwner as Attribution
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    IStreamArtistOwner as Owner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistRecoveredHydrationOwner as RecoveredOwner,
    IStreamArtistRecoveredNativeChronology as NativeClock
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    StreamArtistPersonhoodDefinitions as PersonhoodDefinitions
} from "../../../smart-contracts/domains/artist/StreamArtistPersonhoodDefinitions.sol";
import {
    StreamArtistPersonhoodJSON as PersonhoodJSON
} from "../../../smart-contracts/domains/artist/StreamArtistPersonhoodJSON.sol";
import {
    StreamGeneralAttestations
} from "../../../smart-contracts/domains/metadata/StreamGeneralAttestations.sol";
import {
    IStreamSchemaRegistry
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamGasParameterHost
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamModuleRegistration
} from "../../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";
import {
    StreamArtistOnboardingRegistry
} from "../../../smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol";
import {
    StreamArtistHashes as Hashes
} from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";

/// @notice Actual original24, correction/Platform/dispute and seven-owner Safe60 composition.
/// @dev Reuses the original documentary and owner recipes. Core, governance eligibility,
/// source subject and coverage boundaries remain explicitly typed as in those fixtures.
/// Inherited test bodies are separate; this file adds only the named HistoryRecords cohort.
abstract contract ArtistRecoveredHistoryRecordsFixture is ArtistRecoveredPlatformFixture {
    struct Original {
        Ready.AttestationInput input;
        T.AttestationRecord record;
        uint8 authorityClass;
        Attest.Association association;
        bytes statement;
        bytes signature;
        bytes32 digest;
        RH.Position position;
        RH.Point authorizationPoint;
        C2PA.Head credential;
        PersonhoodTypes.Summary summary;
        bytes32 summaryHash;
        address registry;
    }

    Original[] internal raRows;
    PersonhoodDocumentFixture internal raDocuments;
    StreamGeneralAttestations internal raNotary;

    uint64 private raDelegateSignedAt;
    uint256 private constant SECOND_DELEGATE_KEY = 0xD311;

    bytes32 internal constant CREDENTIAL_SCHEMA =
        keccak256("6529STREAM_ARTIST_C2PA_CREDENTIALS_V1");

    constructor() {
        actualSaleRegistryFixture = true;
    }

    uint256 private historyNotaryNonce;
    uint256 private constant HISTORY_NOTARY_KEY = 0x123451;

    function _hrBaseline() internal {
        _baseline();
        _raDocumentary();
    }

    function _hrPrepare(Successor memory next)
        internal
        view
        returns (RH.Request memory r, Commit.Prepared memory p, HR.Bundle memory b)
    {
        r = _rhRequest();
        r.records.authority.collections[0].policies = new AH.PolicyKey[](basePolicies.length);
        for (uint256 i; i < basePolicies.length; ++i) {
            r.records.authority.collections[0].policies[i] =
                AH.PolicyKey(basePolicies[i].phaseId, basePolicies[i].policyHash);
        }
        r.records.witnesses = new MR.CollectionWitness[](1);
        r.records.witnesses[0].collectionId = 1;
        r.records.witnesses[0].economics =
            new T.EconomicsConsent[](baseEconomicsRecord == 0 ? 0 : 1);
        if (baseEconomicsRecord != 0) r.records.witnesses[0].economics[0] = baseEconomics;
        r.records.witnesses[0].attestations = new Ready.AttestationInput[](raRows.length);
        for (uint256 i; i < raRows.length; ++i) {
            r.records.witnesses[0].attestations[i] = raRows[i].input;
        }
        p = Prepared.prepare(next.coordinator.suiteConfiguration(), r, _hcRoyalties());
        r.expectedSemanticInventory = Prepared.inventory(p);
        (RH.ExportHeader memory h, Payload.Payload memory local) =
            Payload.decode(p.data[4].typedState, 4);
        require(
            (h.requiredFeatures & (131072 | 128 | 8192)) == (131072 | 128 | 8192),
            "explicit complete op24 profile"
        );
        b = HRParts.decode(local.semanticState);
        bytes[5] memory members = [
            abi.encode(b.history.original),
            abi.encode(b.history.sanctions),
            abi.encode(b.history.platform),
            abi.encode(b.history.bindings),
            abi.encode(b.attestations)
        ];
        require(
            keccak256(local.semanticState)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_RECOVERED_HISTORY_RECORDS_V1"),
                        uint16(1),
                        members
                    )
                ),
            "literal complete five-member owner4 encoding"
        );
        require(b.attestations.records.length == raRows.length, "every original24 witness");
        for (uint256 i; i < raRows.length; ++i) {
            require(
                keccak256(abi.encode(b.attestations.records[i].attestation.record))
                    == keccak256(abi.encode(raRows[i].record)),
                "original record tuple"
            );
        }
        (, Payload.Payload memory binding) = Payload.decode(p.data[0].typedState, 0);
        require(
            keccak256(binding.semanticState)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_RECOVERED_HISTORY_RECORD_BINDINGS_V1"),
                        uint16(1),
                        b.history.bindings
                    )
                ),
            "literal original binding and complete corrections"
        );
    }

    function _hrImport(
        Successor memory next,
        RH.Request memory r,
        Commit.Prepared memory p,
        HR.Bundle memory b
    ) internal {
        _hcImport(next, r, p);
        _hpAssert(next.coordinator.suiteConfiguration(), b.history);
        _raAssert(next.coordinator.suiteConfiguration(), raRows.length);
    }

    function hrValidate(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        external
        view
    {
        HRValidation.validateEncoded(raw, q, p);
    }

    function _hrBad(Commit.Prepared memory p, HR.Bundle memory b) internal {
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        this.hrValidate(p.query, RH.ownerProvenance(p.admission.provenance, 4), HRParts.encode(b));
    }

    function _hrGood(Commit.Prepared memory p, HR.Bundle memory b) internal view {
        this.hrValidate(p.query, RH.ownerProvenance(p.admission.provenance, 4), HRParts.encode(b));
    }

    function _hrSourceHash() internal view returns (bytes32) {
        T.Snapshot[7] memory rows;
        for (uint8 i; i < 7; ++i) {
            rows[i] = OriginalOwner(suite.owners[i]).ownerStateSnapshotV2();
        }
        return keccak256(abi.encode(rows, Reconstruction(suite.archive).storedPayloadCount()));
    }

    function _hrNotarize(bytes32 supersedes) internal returns (bytes32 hash) {
        Subjects.SubjectKind kind = Subjects.SubjectKind.COLLECTION;
        bool safeIssuer = false;
        Subjects.Subject memory subject = Subjects.Subject(kind, 1, 0, 0);
        General.Notarization memory n;
        n.artistId = artistId;
        n.operativeIdentityRecordHash = ingress.operativeIdentityRecord(artistId);
        Notice.Reference memory ref = Notice.Reference(
            2,
            keccak256("RAW_BYTES"),
            abi.encode(keccak256("synthetic instrument bytes")),
            "ipfs://personhood-fixture"
        );
        n.legalPersonRef = ref;
        n.instrumentRef = ref;
        n.officiatingAuthorityIdentityRef = ref;
        n.verifyingInstitutionIdentityRef = ref;
        General.Request memory r;
        r.attester = safeIssuer ? address(artist) : vm.addr(HISTORY_NOTARY_KEY);
        r.collectionId = 1;
        r.subjectId = raNotary.deriveSubject(subject);
        r.attestationType = keccak256("INSTITUTIONAL_VERIFICATION");
        r.attesterDID = "did:example:fixture-only";
        r.schemaId = GeneralDefinitions.SCHEMA_ID;
        r.canonicalizationId = keccak256("RFC8785_JCS");
        r.statementURI = "urn:personhood:instrument";
        r.payload = raNotary.notarizationPayload(n);
        r.supersedes = supersedes;
        r.effectiveAt = uint64(block.timestamp);
        r.nonce = ++historyNotaryNonce;
        r.deadline = uint64(block.timestamp + 1 days);
        bytes32 digest = raNotary.attestationDigest(r);
        bytes memory signature;
        if (safeIssuer) {
            signature = _signature(digest);
        } else {
            (uint8 v, bytes32 r_, bytes32 s_) = vm.sign(HISTORY_NOTARY_KEY, digest);
            signature = abi.encodePacked(r_, s_, v);
        }
        hash = raNotary.recordIdentityNotarization(subject, r, n, signature);
        (General.Attestation memory a, General.Receipt memory receipt) = raNotary.attestation(hash);
        require(
            receipt.recorder == r.attester && receipt.authorizationDigest == digest
                && receipt.verificationClass == General.VerificationClass.SIGNER_VERIFIED
                && receipt.authorityQualification
                    == General.AuthorityQualification.GENERAL_SIGNER_CLAIM,
            "actual original signer-qualified receipt, not legal truth"
        );
        General.Receipt memory original = abi.decode(abi.encode(receipt), (General.Receipt));
        original.recordIndex = 0;
        original.recordChainHash = 0;
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_GENERAL_ATTESTATION_RECORD_V1"),
                        block.chainid,
                        address(raNotary),
                        a,
                        original
                    )
                ),
            "independent original record preimage"
        );
    }

    function _raPrimaryTerms()
        internal
        view
        returns (T.Attestation memory p, bytes memory statement)
    {
        bytes32 assignment =
            primary.resolvePrimaryAssignment(1, 0, keccak256("PRIMARY_SALE")).assignmentHash;
        statement = abi.encode("original verified assignment", assignment);
        p = T.Attestation(
            1,
            6,
            bytes32(uint256(uint160(address(primary)))),
            assignment,
            keccak256("recovered subject fixture"),
            keccak256(statement),
            "urn:recovered:primary"
        );
    }

    function _raPrimary(bytes32 grant, uint256 nonce) internal returns (bytes32) {
        (T.Attestation memory p, bytes memory statement) = _raPrimaryTerms();
        return _raRecord(p, statement, grant, nonce);
    }

    function _raDeployment() internal returns (bytes32) {
        bytes memory statement = bytes("original deployment facts");
        bytes32 facts = Hashes.deploymentFacts(
            Hashes.Environment(block.chainid, address(ingress), address(core), suite.mintManager),
            1,
            ingress.displayBinding(1)
        );
        T.Attestation memory p = T.Attestation(
            1,
            9,
            bytes32(uint256(uint160(address(core)))),
            facts,
            keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1"),
            keccak256(statement),
            "urn:recovered:deployment"
        );
        return _raRecord(p, statement, 0, 0);
    }

    function _raCredential(bytes32 previous, bool empty) internal returns (bytes32) {
        C2PA.Credential[] memory items = new C2PA.Credential[](empty ? 0 : 1);
        if (!empty) {
            items[0] = C2PA.Credential(1, keccak256("test SPKI"), keccak256("identity key"), 1, 0);
        }
        bytes memory statement = abi.encode(
            C2PA.Payload(1, artistId, ingress.operativeIdentityRecord(artistId), previous, items)
        );
        return _raRecord(_raIdentityTerms(statement, CREDENTIAL_SCHEMA), statement, 0, 0);
    }

    function _raPersonhood(bytes32 record) internal returns (bytes32) {
        PersonhoodTypes.Reference memory ref = PersonhoodTypes.Reference(
            1,
            PersonhoodDefinitions.PROFILE_HASH,
            address(ingress),
            artistId,
            ingress.operativeIdentityRecord(artistId),
            address(raNotary),
            address(raNotary).codehash,
            record
        );
        bytes memory statement = PersonhoodJSON.encode(ref);
        return _raRecord(
            _raIdentityTerms(statement, PersonhoodDefinitions.EVIDENCE_SCHEMA), statement, 0, 0
        );
    }

    function _raIdentityTerms(bytes memory statement, bytes32 schema)
        internal
        view
        returns (T.Attestation memory)
    {
        return T.Attestation(
            1,
            10,
            artistId,
            ingress.operativeIdentityRecord(artistId),
            schema,
            keccak256(statement),
            "urn:recovered:identity-evidence"
        );
    }

    function _raRecord(T.Attestation memory p, bytes memory statement, bytes32 grant, uint256 nonce)
        internal
        returns (bytes32 record)
    {
        T.Authorization memory a = grant == 0
            ? _authorization(true)
            : T.Authorization(
                nonce, raDelegateSignedAt == 0 ? uint64(block.timestamp) : raDelegateSignedAt, ""
            );
        bytes32 digest = ingress.attestationDigest(p, a);
        address signer =
            grant == 0 ? address(artist) : ingress.delegationRecord(grant).grant.delegate;
        if (grant == 0) {
            a.signature = _signature(digest);
        } else if (signer == address(delegateSafe)) {
            a.signature = _delegateSignature(digest);
        } else {
            require(signer == vm.addr(SECOND_DELEGATE_KEY), "explicit second fixture signer");
            (uint8 v, bytes32 r, bytes32 s_) = vm.sign(SECOND_DELEGATE_KEY, digest);
            a.signature = abi.encodePacked(r, s_, v);
        }
        uint8 class_ = grant == 0 ? uint8(1) : uint8(2);
        record = grant == 0
            ? ingress.recordArtistAttestation(p, a, statement)
            : ingress.recordDelegatedArtistAttestation(p, grant, a, statement);
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(core),
                        p.collectionId,
                        p.subjectKind,
                        p.subjectId,
                        p.subjectStateHash,
                        p.schemaId,
                        p.statementHash,
                        keccak256(bytes(p.statementURI)),
                        artistId,
                        signer,
                        class_,
                        a.nonce,
                        a.time
                    )
                ),
            "independent unchanged original24 preimage"
        );
        if (grant == 0) {
            _rhAuthorization(digest, a.nonce);
            _rhCandidate(
                2, "identity_authority.replay.attestation_key", keccak256(abi.encode(record))
            );
        } else {
            bytes32 lane = keccak256(
                abi.encode(keccak256("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"), artistId, signer)
            );
            _rhCandidate(
                2, "identity_authority.replay.delegated_nonce", keccak256(abi.encode(lane, a.nonce))
            );
            _rhCandidate(
                2,
                "identity_authority.replay.authorization_consumed_digest",
                keccak256(abi.encode(artistId, digest))
            );
        }
        Original memory item;
        item.input = Ready.AttestationInput(p, a.nonce);
        item.record = Attribution(suite.owners[4]).attestationRecord(record);
        item.authorityClass = class_;
        item.association = ingress.attestationAssociation(record);
        item.statement = statement;
        item.signature = a.signature;
        item.digest = digest;
        item.registry = address(ingress);
        item.position = _raPosition(4, 24, record);
        item.authorizationPoint = RH.Point(
            RH.originHash(_raOrigin(suite)),
            2,
            Owner(suite.owners[2]).ownerStateSnapshotV2().revision
        );
        item.credential = Credentials(suite.owners[4]).c2paCredentialRecord(record);
        item.summary = PersonhoodRead(suite.owners[4]).personhoodProofSummary(record);
        item.summaryHash = PersonhoodRead(suite.owners[4]).personhoodProofSummaryHash(record);
        require(
            item.association.artistId == artistId
                && item.association.bindingHash == ingress.displayBinding(1).bindingHash
                && item.association.delegation == grant,
            "original binding and delegate association"
        );
        require(
            _operationPayload(24, address(this), record).length != 0,
            "original Archive24 evidence retained"
        );
        if (item.summaryHash != 0) {
            require(
                item.summaryHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_PERSONHOOD_PROOF_SUMMARY_V1"), item.summary
                        )
                    ),
                "literal original summary commitment"
            );
        }
        raRows.push(item);
    }

    function _raAssert(T.SuiteConfiguration memory target, uint256 count) internal view {
        StreamArtistOnboardingRegistry registry = StreamArtistOnboardingRegistry(target.registry);
        (RH.OwnerProvenance memory prefix,,) =
            RecoveredOwner(target.owners[4]).recoveredHydrationImportedPrefix();
        uint256 matched;
        for (uint256 i; i < prefix.journal.length; ++i) {
            if (prefix.journal[i].receipt.operation != 24) continue;
            Original memory item = raRows[matched++];
            require(
                prefix.journal[i].receipt.recordHash == item.record.recordHash
                    && keccak256(abi.encode(prefix.journal[i].position))
                        == keccak256(abi.encode(item.position)),
                "every exact original24 occurrence and ultimate coordinates"
            );
        }
        require(matched == count, "complete flattened original24 prefix");
        for (uint256 i; i < count; ++i) {
            Original memory item = raRows[i];
            bytes32 hash = item.record.recordHash;
            require(
                keccak256(abi.encode(Attribution(target.owners[4]).attestationRecord(hash)))
                    == keccak256(abi.encode(item.record)),
                "original record bytes unchanged"
            );
            require(
                registry.attestationAuthorityClass(hash) == item.authorityClass
                    && keccak256(abi.encode(registry.attestationAssociation(hash)))
                        == keccak256(abi.encode(item.association)),
                "original class and full verified subject association"
            );
            require(
                keccak256(Attribution(target.owners[4]).statementBytes(item.record.statementHash))
                    == keccak256(item.statement),
                "exact original statement bytes"
            );
            require(
                keccak256(Identity(target.owners[2]).signatureBundle(hash))
                    == keccak256(item.signature),
                "original signer bundle not reauthorized"
            );
            bytes32 nonceScope;
            string memory nonceSurface;
            if (item.association.delegation == 0) {
                nonceScope = keccak256(abi.encode(artistId, item.input.nonce));
                nonceSurface = "identity_authority.replay.nonce_allocator";
                T.ReplayCell memory receiptGuard = Owner(target.owners[2])
                    .replayCell(
                        _raKey(
                            target,
                            "identity_authority.replay.attestation_key",
                            keccak256(abi.encode(hash))
                        )
                    );
                require(
                    receiptGuard.commitment == hash && receiptGuard.status != 0,
                    "original direct24 one-way record guard"
                );
            } else {
                bytes32 lane = keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"),
                        artistId,
                        item.record.signer
                    )
                );
                nonceScope = keccak256(abi.encode(lane, item.input.nonce));
                nonceSurface = "identity_authority.replay.delegated_nonce";
                require(
                    Owner(target.owners[2])
                    .replayCell(
                        _raKey(
                            target,
                            "identity_authority.replay.attestation_key",
                            keccak256(abi.encode(hash))
                        )
                    )
                    .status == 0,
                    "delegated24 never invents the direct record guard"
                );
            }
            bytes32 nonceKey = _raKey(target, nonceSurface, nonceScope);
            T.ReplayCell memory nonceCell = Owner(target.owners[2]).replayCell(nonceKey);
            require(
                nonceCell.commitment == item.digest && nonceCell.kind == 1 && nonceCell.status == 2
                    && nonceCell.touchedRevision == item.authorizationPoint.ownerRevision,
                "exact original Identity nonce admission, independent of signedAt"
            );
            require(
                keccak256(
                    abi.encode(
                        RecoveredOwner(target.owners[2]).recoveredHydrationReplayPoint(nonceKey)
                    )
                ) == keccak256(abi.encode(item.authorizationPoint)),
                "Identity clock stays distinct from original Attribution native clock"
            );
            RH.Point memory observedAt = item.authorizationPoint;
            for (uint256 j; j < i; ++j) {
                if (raRows[j].digest == item.digest) {
                    observedAt = raRows[j].authorizationPoint;
                    break;
                }
            }
            bytes32 observation = _raKey(
                target,
                "identity_authority.replay.authorization_consumed_digest",
                keccak256(abi.encode(artistId, item.digest))
            );
            require(
                Owner(target.owners[2]).replayCell(observation).commitment == item.digest
                    && keccak256(
                        abi.encode(
                            RecoveredOwner(target.owners[2])
                                .recoveredHydrationReplayPoint(observation)
                        )
                    ) == keccak256(abi.encode(observedAt)),
                "shared digest observation retains its FIRST genuine admission point"
            );
            require(
                keccak256(abi.encode(Credentials(target.owners[4]).c2paCredentialRecord(hash)))
                    == keccak256(abi.encode(item.credential)),
                "full credential history including explicit withdrawals"
            );
            require(
                PersonhoodRead(target.owners[4]).personhoodProofSummaryHash(hash)
                        == item.summaryHash
                    && keccak256(
                        abi.encode(PersonhoodRead(target.owners[4]).personhoodProofSummary(hash))
                    ) == keccak256(abi.encode(item.summary)),
                "exact sparse original summary tuple"
            );
            bool last = true;
            for (uint256 j = i + 1; j < count; ++j) {
                if (
                    raRows[j].input.terms.subjectKind == item.input.terms.subjectKind
                        && raRows[j].input.terms.subjectId == item.input.terms.subjectId
                ) last = false;
            }
            if (last) {
                require(
                    Attribution(target.owners[4])
                    .attestation(1, item.input.terms.subjectKind, item.input.terms.subjectId)
                    .recordHash == hash,
                    "latest subject map follows original occurrence order"
                );
            }
        }
        bytes32 credential;
        bytes32 personhood;
        for (uint256 i; i < count; ++i) {
            if (raRows[i].credential.recordHash != 0) {
                credential = raRows[i].record.recordHash;
            } else if (raRows[i].input.terms.subjectKind == 10) {
                personhood = raRows[i].record.recordHash;
            }
        }
        require(
            Credentials(target.owners[4]).c2paCredentialHead(artistId).recordHash == credential
                && Credentials(target.owners[4]).personhoodAttestation(1, artistId).recordHash
                    == personhood,
            "separate personhood and credential heads never overwrite each other"
        );
    }

    function _raPosition(uint8 index, uint16 operation, bytes32 record)
        internal
        view
        returns (RH.Position memory)
    {
        uint256 nativeIndex = Native(suite.owners[index]).artistNativeReceiptCount() - 1;
        HT.Receipt memory row = Native(suite.owners[index]).artistNativeReceiptAt(nativeIndex);
        require(
            row.operation == operation && row.recordHash == record && row.artistId == artistId,
            "actual native producer receipt"
        );
        return RH.Position(
            RH.Point(
                RH.originHash(_raOrigin(suite)),
                index,
                NativeClock(suite.owners[index]).artistNativeReceiptRevisionAt(nativeIndex)
            ),
            nativeIndex
        );
    }

    function _raKey(T.SuiteConfiguration memory target, string memory surface, bytes32 scope)
        internal
        view
        returns (bytes32)
    {
        return Guards.replayKey(_raOrigin(target), 2, AH.Origin(keccak256(bytes(surface)), scope));
    }

    function _raOrigin(T.SuiteConfiguration memory target)
        internal
        view
        returns (RH.OriginEnvironment memory e)
    {
        e.chainId = block.chainid;
        e.registry = target.registry;
        e.coordinator = Owner(target.owners[2]).operationCoordinator();
        e.archive = target.archive;
        e.owners = target.owners;
        for (uint8 i; i < 7; ++i) {
            e.ownerCodeHashes[i] = target.owners[i].codehash;
        }
        e.core = target.core;
        e.manager = target.mintManager;
        e.suiteConfigurationHash = keccak256(abi.encode(target));
    }

    function _raDocumentary() internal {
        raDocuments = new PersonhoodDocumentFixture();
        raDocuments.deploy();
        raDocuments.register(
            "STREAM_IDENTITY_NOTARIZATION_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/records/STREAM_IDENTITY_NOTARIZATION_V1.json"))
        );
        raDocuments.register(
            "STREAM_IDENTITY_NOTARIZATION_JSON_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            bytes(vm.readFile("schemas/records/STREAM_IDENTITY_NOTARIZATION_JSON_PROFILE_V1.json"))
        );
        raDocuments.register(
            "RFC8785_JCS",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(vm.readFile("schemas/museum/account-profile/RFC8785_JCS.json"))
        );
        _raRegisterReferenceProfile();
        StreamGeneralAttestations.Configuration memory c;
        c.core = address(core);
        c.schemas = address(raDocuments.schemas());
        c.metadata = address(metadata);
        c.artistRegistry = address(ingress);
        c.artistAttribution = suite.owners[4];
        c.executor = address(raDocuments);
        c.deploymentManifestHash = keccak256("personhood fixture deployment");
        c.manifestURI = "urn:personhood:fixture";
        c.manifestHash = keccak256("personhood fixture manifest");
        c.signatureGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ERC1271_VERIFY_GAS", 150000, 90000, 2
        );
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 2000000, 50000, 2
        );
        raNotary = StreamGeneralAttestations(
            _artistArtifactCreate(
                "smart-contracts/domains/metadata/StreamGeneralAttestations.sol:StreamGeneralAttestations",
                abi.encode(c)
            )
        );
        _raRegisterNotary();
    }

    function _raRegisterReferenceProfile() private {
        bytes memory raw = bytes(
            vm.readFile("schemas/records/STREAM_ARTIST_PERSONHOOD_REFERENCE_JSON_PROFILE_V1.json")
        );
        require(
            raw.length == PersonhoodDefinitions.PROFILE_BYTES
                && keccak256(raw) == PersonhoodDefinitions.PROFILE_HASH,
            "exact pinned profile bytes"
        );
        raDocuments.register(
            "STREAM_ARTIST_PERSONHOOD_REFERENCE_JSON_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            raw
        );
    }

    function _raRegistrationFacts(StreamModuleRegistration memory r, uint8 status, uint64 revision)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                status,
                r.moduleType,
                r.moduleVersion,
                r.interfaceId,
                r.moduleGasLimit,
                r.expectedRuntimeCodeHash,
                r.deploymentManifestHash,
                r.moduleManifestHash,
                keccak256(bytes(r.moduleManifestURI)),
                revision
            )
        );
    }

    function _raRegisterNotary() private {
        // Exact original ModuleRegistry class-1 registration, with the General module's actual version.
        StreamModuleRegistration memory r = StreamModuleRegistration(
            address(raNotary),
            keccak256("GENERAL_ATTESTATIONS"),
            keccak256("6529stream.general-attestations.v2"),
            type(General).interfaceId,
            0,
            address(raNotary).codehash,
            keccak256("personhood fixture deployment"),
            keccak256("personhood fixture manifest"),
            "urn:personhood:fixture"
        );
        (bytes32 chain, uint64 count) = saleModules.registrationChainHash();
        bytes32 record = keccak256(
            abi.encode(
                saleModules.STREAM_MODULE_REGISTRATION_RECORD_V1(),
                r.module,
                r.moduleType,
                r.interfaceId,
                r.moduleVersion,
                r.expectedRuntimeCodeHash,
                r.deploymentManifestHash,
                r.moduleManifestHash
            )
        );
        bytes32 next = keccak256(
            abi.encode(
                saleModules.STREAM_RECORD_CHAIN_V1(),
                block.chainid,
                address(saleModules),
                uint256(0),
                keccak256("MODULE_REGISTRATION"),
                chain,
                record,
                count
            )
        );
        bytes32 scope = keccak256(
            abi.encode(
                saleModules.STREAM_MODULE_REGISTRATION_SCOPE_V1(),
                block.chainid,
                address(saleModules),
                address(raNotary)
            )
        );
        StreamModuleRegistration memory empty;
        bytes32 oldState = keccak256(
            abi.encode(
                saleModules.STREAM_MODULE_REGISTRATION_STATE_V1(),
                scope,
                false,
                _raRegistrationFacts(empty, 0, 0),
                uint256(count),
                chain,
                count,
                address(0)
            )
        );
        bytes32 nextState = keccak256(
            abi.encode(
                saleModules.STREAM_MODULE_REGISTRATION_STATE_V1(),
                scope,
                true,
                _raRegistrationFacts(r, 1, 1),
                uint256(count) + 1,
                next,
                count + 1,
                address(raNotary)
            )
        );
        address authority = factory.governanceAuthority();
        ArtistUnitGovernance(authority)
            .executeModuleContext(
                address(saleModules),
                abi.encodeCall(saleModules.registerModule, (r)),
                1,
                scope,
                oldState,
                nextState
            );
        (bool active, bytes32 action, uint8 cls, bytes32 scope_, bytes32 old_, bytes32 next_) =
            ArtistUnitGovernance(authority).currentAction();
        require(
            !active && action == 0 && cls == 0 && scope_ == 0 && old_ == 0 && next_ == 0,
            "actual module registration context closed without persistent mocks"
        );
    }
}
