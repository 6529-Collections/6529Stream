// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistRecoveredMultipleAttestationFixture.sol";
import {
    StreamArtistHashes as Hashes
} from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";
import {
    StreamArtistReadinessHydrationTypes as Ready
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    StreamArtistRecoveredAttestationHydration as AttestationBundle
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistRecoveredMultipleAttestationClocks as Clocks
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleAttestationClocks.sol";
import {
    StreamArtistRecoveredMultipleAttestationConservation as Conservation
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleAttestationConservation.sol";
import {
    StreamArtistRecoveredMultipleAttestationValidation as Validation
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleAttestationValidation.sol";
import {
    StreamArtistC2PATypes as C2PA,
    IStreamArtistC2PAReads as Credentials
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistC2PA.sol";
import {
    IStreamArtistPersonhoodEvidence as Personhood
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPersonhoodEvidence.sol";
import {
    IStreamArtistAuthenticatedAttestationOwner as Associations
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttestationWriter.sol";
import {
    IStreamArtistReadinessAttributionOwner as Classes
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    IStreamArtistRecordPublicationOwner as AttestationPublications
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecordPublicationOwner.sol";
import {
    StreamArtistRecoveredMultipleAttestationQueries as Queries
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleAttestationQueries.sol";

interface AggregateAttestationVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
}

/// @notice Actual original owners/Archive and Safe calls; inherited Core/governance remain explicit unit boundaries.
/// @dev No checkpoint, provenance, source record or imported semantic state is fabricated in happy paths.
contract StreamArtistRecoveredMultipleAttestationActualTest is
    ArtistRecoveredMultipleAttestationFixture
{
    struct Saved {
        Ready.AttestationInput input;
        bytes32 record;
        bytes statement;
        T.Authorization authorization;
        uint8 authorityClass;
    }
    Saved[] internal maRows;
    bytes32 internal constant CREDENTIAL_SCHEMA =
        keccak256("6529STREAM_ARTIST_C2PA_CREDENTIALS_V1");

    function _multiEstateCapabilities() internal pure override returns (uint32) {
        return 2305;
    }

    function testMultipleAttestationsJoinEveryConsentFamilyAndGlobalCredentialChain() external {
        _mcSource();
        require(
            ingress.delegationRecord(mcGrants[0]).uses == 7
                && ingress.delegationRecord(mcGrants[0]).revoked,
            "original global grant exhausted then revoked"
        );
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _maPrepare(next);
        bytes32 original = _maSemantics(suite);
        ConsentHydration(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(r, _maRoyalties());
        _maAssert(next, p);
        require(_maSemantics(suite) == original, "all source maps remain unchanged");
    }

    function testMultipleAttestationsDirectOriginalSafeAndDistinctPersonhoodHead() external {
        _mcSource(false);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _maPrepare(next);
        uint256 n = rotationSafe.nonce();
        require(
            this.rhExecuteNewSafe(
                address(next.registry),
                abi.encodeCall(
                    ConsentHydration.hydrateRecoveredArtistAuthorityWithConsents,
                    (r, _maRoyalties())
                )
            ),
            "actual Safe aggregate import"
        );
        require(rotationSafe.nonce() == n + 1, "one Safe nonce");
        _maAssert(next, p);
        require(
            Credentials(next.coordinator.suiteConfiguration().owners[4])
            .c2paCredentialHead(artistId)
            .recordHash == maRows[2].record,
            "third credential crosses collections"
        );
        require(
            Credentials(next.coordinator.suiteConfiguration().owners[4])
            .personhoodAttestation(2, artistId)
            .recordHash == maRows[3].record,
            "waiver does not replace credentials"
        );
    }

    function testMultipleAttestationsClassThreeAndEmptyFirstCollectionThroughSafe() external {
        _multiSource(false, true);
        _adoptRotatedSafe();
        vm.warp(ingress.artistTransitionState(multiRecovery[1]).postWindowEndsAt);
        _maCredential(2, 0, 0, 0, true);
        require(maRows[0].authorityClass == 3, "original recovered class3 producer");
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _maPrepare(next);
        require(
            this.rhExecuteNewSafe(
                address(next.registry),
                abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (r))
            ),
            "class3 aggregate Safe"
        );
        _maAssert(next, p);
    }

    function testMultipleAttestationsLateArchiveFailureRollsBackEveryHeadAndAllOwners() external {
        _mcSource();
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _maPrepare(next);
        bytes32 before_ = _maHash(next);
        uint256 nonce = rotationSafe.nonce();
        uint256 originalBlock = block.number;
        bytes memory call_ = abi.encodeCall(
            ConsentHydration.hydrateRecoveredArtistAuthorityWithConsents, (r, _maRoyalties())
        );
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ArtistArchiveBlockNumberOverflow(uint256)", uint256(type(uint64).max) + 1
            )
        );
        ConsentHydration(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(r, _maRoyalties());
        require(
            _maHash(next) == before_,
            "all original maps, heads, publications, grants, nonces and activation rollback"
        );
        vm.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(address(next.registry), call_);
        require(rotationSafe.nonce() == nonce && _maHash(next) == before_, "Safe rollback");
        vm.roll(originalBlock);
        require(this.rhExecuteNewSafe(address(next.registry), call_), "identical retry");
        _maAssert(next, p);
    }

    function testMultipleAttestationsCannotResetGrantUsePerCollectionOrFamily() external {
        _mcSource();
        Successor memory next = _multiCutover();
        (, Commit.Prepared memory p) = _maPrepare(next);
        (, Payload.Payload memory ip) = Payload.decode(p.data[2].typedState, 2);
        M.State memory ids = ConsentCodec.decode(2, ip.semanticState, ip.provenance);
        (, Payload.Payload memory cp) = Payload.decode(p.data[6].typedState, 6);
        M.State memory cs = ConsentCodec.decode(6, cp.semanticState, cp.provenance);
        (, Payload.Payload memory bp) = Payload.decode(p.data[0].typedState, 0);
        M.State memory bs = ConsentCodec.decode(0, bp.semanticState, bp.provenance);
        (, Payload.Payload memory ap) = Payload.decode(p.data[4].typedState, 4);
        M.State memory ats = ConsentCodec.decode(4, ap.semanticState, ap.provenance);
        ContentH.Bundle[] memory consents = new ContentH.Bundle[](cs.rows.length);
        for (uint256 i; i < consents.length; ++i) {
            consents[i] = abi.decode(cs.rows[i], (ContentH.Bundle));
        }
        Conservation.validate(ids.rows, ids, consents, bs.rows, ats.rows, p.admission.provenance);
        bytes memory saved = ids.rows[0];
        for (uint256 expected = 5; expected <= 8; ++expected) {
            if (expected == 7) continue;
            IH.Bundle memory id = abi.decode(saved, (IH.Bundle));
            id.delegations[0].record.uses = expected;
            ids.rows[0] = abi.encode(id);
            (bool ok,) = address(Conservation)
                .staticcall(
                    abi.encodeWithSelector(
                        Conservation.validate.selector,
                        ids.rows,
                        ids,
                        consents,
                        bs.rows,
                        ats.rows,
                        p.admission.provenance
                    )
                );
            require(!ok, "consent-only or duplicated op24 totals refuse");
        }
        ids.rows[0] = saved;
        Conservation.validate(ids.rows, ids, consents, bs.rows, ats.rows, p.admission.provenance);
    }

    function testMultipleAttestationsCompleteHeaderWitnessAndSourceHeadRefuseAndRestore() external {
        _mcSource();
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _maPrepare(next);
        bytes memory saved = abi.encode(r);
        bytes32 before_ = _maHash(next);
        for (uint256 i; i < 7; ++i) {
            r = abi.decode(saved, (RH.Request));
            ++r.records.authority.expectedSource[i].ownerState.revision;
            _maBadRequest(next, r);
        }
        r = abi.decode(saved, (RH.Request));
        r.records.witnesses[1].attestations = new Ready.AttestationInput[](0);
        _maBadRequest(next, r);
        r = abi.decode(saved, (RH.Request));
        ++r.records.witnesses[0].attestations[0].nonce;
        _maBadRequest(next, r);
        r = abi.decode(saved, (RH.Request));
        C2PA.Head memory original = Credentials(suite.owners[4]).c2paCredentialHead(artistId);
        C2PA.Head memory wrong;
        AggregateAttestationVm(address(vm))
            .mockCall(
                suite.owners[4],
                abi.encodeCall(Credentials.c2paCredentialHead, (artistId)),
                abi.encode(wrong)
            );
        _maBadRequest(next, r);
        AggregateAttestationVm(address(vm))
            .mockCall(
                suite.owners[4],
                abi.encodeCall(Credentials.c2paCredentialHead, (artistId)),
                abi.encode(original)
            );
        require(_maHash(next) == before_, "rejected preparation never imports");
        ConsentHydration(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(r, _maRoyalties());
        _maAssert(next, p);
    }

    function testMultipleAttestationsArchiveClocksRejectReassignedAcceptanceAndNativeOverlap()
        external
    {
        _mcSource();
        Successor memory next = _multiCutover();
        (, Commit.Prepared memory p) = _maPrepare(next);
        (, Payload.Payload memory ap) = Payload.decode(p.data[4].typedState, 4);
        (M.State memory scope, bytes memory raw) =
            ConsentCodec.decodeAuxiliary(4, ap.semanticState, ap.provenance);
        Clocks.Inventory memory inventory = Clocks.decode(raw);
        RH.Point[] memory points = Clocks.validateLocal(scope, ap.provenance, inventory);
        require(
            points.length == 2 && points[0].ownerRevision < points[1].ownerRevision,
            "authentic own owner4 acceptance clocks"
        );
        RH.OwnerProvenance memory changed =
            abi.decode(abi.encode(ap.provenance), (RH.OwnerProvenance));
        changed.journal[0].position.point = points[0];
        (bool ok,) = address(Clocks)
            .staticcall(
                abi.encodeWithSelector(Clocks.validateLocal.selector, scope, changed, inventory)
            );
        require(!ok, "native record cannot occupy original non-native acceptance point");
        bytes32 saved = scope.collections[1].bindingHash;
        scope.collections[1].bindingHash = scope.collections[0].bindingHash;
        (ok,) = address(Clocks)
            .staticcall(
                abi.encodeWithSelector(
                    Clocks.validateLocal.selector, scope, ap.provenance, inventory
                )
            );
        require(!ok, "collection cannot borrow another accepted binding");
        scope.collections[1].bindingHash = saved;
        Clocks.validateLocal(scope, ap.provenance, inventory);
    }

    function testMultipleAttestationsRepeatedImportAndFreshCrossCollectionCredentialKeepOrigins()
        external
    {
        _mcSource();
        Successor memory first = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _maPrepare(first);
        ConsentHydration(address(first.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(r, _maRoyalties());
        _maAssert(first, p);
        RH.JournalEntry[] memory original = p.admission.provenance.journals[4];
        T.SuiteConfiguration memory source = suite;
        bytes32 previous =
            Credentials(first.coordinator.suiteConfiguration().owners[4])
        .c2paCredentialHead(artistId)
        .recordHash;
        _rhAdopt(first);
        bytes32 fresh = _maCredential(2, previous, 0, 0, false);
        require(
            Credentials(suite.owners[4]).c2paCredentialRecord(fresh).sourceRegistry
                == address(ingress),
            "actual new B record uses B domain"
        );
        // The appended witness belongs to B, so compare the frozen A portion directly.
        require(
            Attribution(source.owners[4]).attestationRecord(fresh).recordHash == 0,
            "original A remains untouched"
        );
        Successor memory second = _multiCutover();
        (r, p) = _maPrepare(second);
        require(
            p.admission.provenance.eras.length == 2
                && p.admission.provenance.journals[4].length == original.length + 1,
            "complete original and new native histories"
        );
        for (uint256 i; i < original.length; ++i) {
            require(
                keccak256(abi.encode(p.admission.provenance.journals[4][i]))
                    == keccak256(abi.encode(original[i])),
                "every original local point survives"
            );
        }
        ConsentHydration(address(second.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(r, _maRoyalties());
        _maAssert(second, p);
    }

    function testMultipleAttestationsTwoArtistsShareDelegateAndNonceWithoutSharingLane() external {
        _multiSource(false, false);
        _adoptRotatedSafe();
        vm.warp(ingress.artistTransitionState(multiRecovery[1]).postWindowEndsAt);
        uint256[] memory secondKeys = keys;
        artistId = multiCollectionArtists[0];
        artist = OfficialSafe(multiAuthorities[0]);
        // Exact keys of the inherited first recovery Safe at salt36001, never a new deployment.
        keys = new uint256[](2);
        keys[0] = 0xCA1100 + 36001;
        keys[1] = 0xCA2200 + 36001;
        nextNonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        bytes32 firstGrant = _mcGrant(1);
        _maCredential(1, 0, firstGrant, 77, false);
        artistId = multiCollectionArtists[1];
        artist = OfficialSafe(multiAuthorities[1]);
        keys = secondKeys;
        nextNonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        bytes32 secondGrant = _mcGrant(1);
        _maCredential(2, 0, secondGrant, 77, false);
        require(
            firstGrant != secondGrant && maRows[0].record != maRows[1].record,
            "original Artist domains remain distinct"
        );
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory prepared) = _maPrepare(next);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(r);
        _maAssert(next, prepared);
        for (uint256 k; k < 2; ++k) {
            (bool consumed,) = next.registry
                .delegatedNonceState(multiCollectionArtists[k], address(delegateSafe), 77);
            require(consumed, "same original numeric nonce survives in each distinct lane");
            require(
                next.registry.delegationRecord(mcGrants[k]).uses == 1,
                "no cross-Artist grant counter merge"
            );
        }
    }

    function testMultipleAttestationQueriesPreserveCompleteAdmissionAndOriginalOrder() external {
        _mcSource();
        Successor memory next = _multiCutover();
        (, Commit.Prepared memory p) = _maPrepare(next);
        M.State memory full;
        full.artists = p.admission.artists;
        full.collections = p.admission.collections;
        full.rows = new bytes[](1);
        full.rows[0] = hex"123456";
        bytes32 original = keccak256(abi.encode(full));
        RH.OwnerProvenance memory provenance = RH.ownerProvenance(p.admission.provenance, 4);
        M.State memory projected = Queries.project(full, provenance);
        require(
            keccak256(abi.encode(full)) == original,
            "projection leaves every admitted record and policy intact"
        );
        uint256[] memory cursor = new uint256[](full.collections.length);
        for (uint256 i; i < provenance.journal.length; ++i) {
            uint256 k = provenance.journal[i].receipt.collectionId - 1;
            require(
                projected.collections[k].records[cursor[k]++]
                    == provenance.journal[i].receipt.recordHash,
                "original owner4 occurrence order"
            );
        }
        for (uint256 k; k < cursor.length; ++k) {
            require(
                projected.collections[k].records.length == cursor[k]
                    && full.collections[k].records.length > cursor[k],
                "owner4 excludes binding, acceptance and consent occurrences"
            );
        }
        require(
            keccak256(abi.encode(projected.artists)) == keccak256(abi.encode(full.artists)),
            "complete Artist anchor records retained"
        );
        projected.artists[0].records[0] = bytes32(uint256(1));
        projected.collections[0].policies[0].policyHash = bytes32(uint256(2));
        projected.rows[0][0] = bytes1(0xff);
        require(
            keccak256(abi.encode(full)) == original,
            "returned records, policies and opaque rows never alias admission"
        );
        RH.JournalEntry memory saved = provenance.journal[1];
        provenance.journal[1] = provenance.journal[0];
        (bool ok,) = address(Queries)
            .staticcall(abi.encodeWithSelector(Queries.project.selector, full, provenance));
        require(!ok, "duplicate original occurrence refuses");
        provenance.journal[1] = saved;
        provenance.journal[0].receipt.artistId = keccak256("foreign Artist");
        (ok,) = address(Queries)
            .staticcall(abi.encodeWithSelector(Queries.project.selector, full, provenance));
        require(!ok, "unselected original Artist refuses");
    }

    function _maShared(bytes32 grant) internal override {
        bytes32 first = _maCredential(1, 0, grant, 4, grant == 0);
        bytes32 second = _maCredential(2, first, grant, 5, false);
        _maCredential(1, second, 0, 0, false);
        bytes memory statement = abi.encode("original aggregate personhood waiver", artistId);
        T.Attestation memory terms = T.Attestation(
            2,
            10,
            artistId,
            ingress.operativeIdentityRecord(artistId),
            keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1"),
            keccak256(statement),
            "urn:aggregate:waiver"
        );
        _maWrite(terms, statement, 0, 0, false);
        statement = bytes("original aggregate deployment statement");
        terms = T.Attestation(
            1,
            9,
            bytes32(uint256(uint160(address(core)))),
            Hashes.deploymentFacts(
                Hashes.Environment(
                    block.chainid, address(ingress), address(core), address(manager)
                ),
                1,
                ingress.displayBinding(1)
            ),
            keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1"),
            keccak256(statement),
            "urn:aggregate:deployment"
        );
        _maWrite(terms, statement, 0, 0, false);
    }

    function _maCredential(
        uint256 collection,
        bytes32 previous,
        bytes32 grant,
        uint256 nonce,
        bool safe
    ) internal returns (bytes32) {
        C2PA.Credential[] memory items = new C2PA.Credential[](1);
        items[0] = C2PA.Credential(1, keccak256("aggregate SPKI"), keccak256("aggregate key"), 1, 0);
        bytes memory statement = abi.encode(
            C2PA.Payload(1, artistId, ingress.operativeIdentityRecord(artistId), previous, items)
        );
        T.Attestation memory terms = T.Attestation(
            collection,
            10,
            artistId,
            ingress.operativeIdentityRecord(artistId),
            CREDENTIAL_SCHEMA,
            keccak256(statement),
            "urn:aggregate:credential"
        );
        return _maWrite(terms, statement, grant, nonce, safe);
    }

    function _maWrite(
        T.Attestation memory terms,
        bytes memory statement,
        bytes32 grant,
        uint256 nonce,
        bool safe
    ) internal returns (bytes32 record) {
        T.Authorization memory a = grant == 0
            ? _authorization(true)
            : T.Authorization(nonce, uint64(block.timestamp), "");
        bytes32 digest = ingress.attestationDigest(terms, a);
        address signer = grant == 0 ? address(artist) : address(delegateSafe);
        uint8 class_ = grant == 0
            ? IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).authorityClass
            : 2;
        record = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"),
                block.chainid,
                address(ingress),
                address(core),
                terms.collectionId,
                terms.subjectKind,
                terms.subjectId,
                terms.subjectStateHash,
                terms.schemaId,
                terms.statementHash,
                keccak256(bytes(terms.statementURI)),
                artistId,
                signer,
                class_,
                a.nonce,
                a.time
            )
        );
        if (safe) {
            require(grant == 0, "direct original Safe fixture");
            require(
                executeSafe(
                    artist,
                    keys,
                    address(ingress),
                    0,
                    abi.encodeCall(
                        IStreamArtistOnboarding.recordArtistAttestation, (terms, a, statement)
                    ),
                    0
                ),
                "original op24 Safe"
            );
        } else {
            a.signature = grant == 0 ? _signature(digest) : _delegateSignature(digest);
            bytes32 actual = grant == 0
                ? ingress.recordArtistAttestation(terms, a, statement)
                : ingress.recordDelegatedArtistAttestation(terms, grant, a, statement);
            require(actual == record, "literal original24 domain/preimage");
        }
        require(
            Attribution(suite.owners[4]).attestationRecord(record).recordHash == record,
            "actual native record"
        );
        _mcRemember(record, digest, a, grant != 0);
        if (grant == 0) {
            _rhCandidate(
                2, "identity_authority.replay.attestation_key", keccak256(abi.encode(record))
            );
        }
        maRows.push(Saved(Ready.AttestationInput(terms, a.nonce), record, statement, a, class_));
    }

    function _maRoyalties() internal view returns (T.RoyaltyFreeze[] memory out) {
        if (mcRoyaltyRecord == 0) return new T.RoyaltyFreeze[](0);
        return _mcRoyalties();
    }

    function _maPrepare(Successor memory next)
        internal
        view
        returns (RH.Request memory r, Commit.Prepared memory p)
    {
        r = _multiRequest();
        if (mcPolicies.length != 0) {
            for (uint256 i; i < 2; ++i) {
                AH.PolicyKey[] memory policy = new AH.PolicyKey[](2);
                policy[0] = AH.PolicyKey(PHASE, multiPolicies[i]);
                policy[1] = AH.PolicyKey(mcPolicies[i].phaseId, mcPolicies[i].policyHash);
                r.records.authority.collections[i].policies = policy;
            }
        }
        uint256[2] memory count;
        for (uint256 i; i < maRows.length; ++i) {
            ++count[maRows[i].input.terms.collectionId - 1];
        }
        uint256 witnesses =
            (count[0] != 0 || mcEconomicsRecord != 0 ? 1 : 0) + (count[1] != 0 ? 1 : 0);
        r.records.witnesses = new MR.CollectionWitness[](witnesses);
        uint256 at;
        for (uint256 k; k < 2; ++k) {
            if (count[k] == 0 && (k != 0 || mcEconomicsRecord == 0)) continue;
            MR.CollectionWitness memory w;
            w.collectionId = k + 1;
            w.economics = new T.EconomicsConsent[](k == 0 && mcEconomicsRecord != 0 ? 1 : 0);
            if (w.economics.length != 0) w.economics[0] = mcEconomics;
            w.attestations = new Ready.AttestationInput[](count[k]);
            uint256 cursor;
            for (uint256 i; i < maRows.length; ++i) {
                if (maRows[i].input.terms.collectionId == k + 1) {
                    w.attestations[cursor++] = maRows[i].input;
                }
            }
            r.records.witnesses[at++] = w;
        }
        p = Prepared.prepare(next.coordinator.suiteConfiguration(), r, _maRoyalties());
        r.expectedSemanticInventory = Prepared.inventory(p);
        for (uint8 i; i < 7; ++i) {
            (RH.ExportHeader memory h, Payload.Payload memory local) =
                Payload.decode(p.data[i].typedState, i);
            require(
                (h.requiredFeatures & (RH.MULTIPLE_ATTESTATIONS | RH.ATTESTATIONS))
                    == (RH.MULTIPLE_ATTESTATIONS | RH.ATTESTATIONS),
                "all seven explicit new profile"
            );
            (M.State memory scope, bytes memory auxiliary) =
                ConsentCodec.decodeAuxiliary(i, local.semanticState, local.provenance);
            require(
                keccak256(local.semanticState)
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_RECOVERED_MULTIPLE_ATTESTATIONS_V1"),
                            uint16(1),
                            i,
                            scope,
                            auxiliary
                        )
                    ),
                "literal full tagged owner envelope"
            );
            require(
                i == 4 ? auxiliary.length != 0 : auxiliary.length == 0, "one owner4 Archive carrier"
            );
        }
    }

    function _maAssert(Successor memory next, Commit.Prepared memory p) internal view {
        if (mcPolicies.length != 0) _mcAssert(next, p);
        else _multiAssert(next, p);
        require(
            _maSemantics(next.coordinator.suiteConfiguration()) == _maSemantics(suite),
            "every original record, statement, association, publication, summary and independent head"
        );
        for (uint256 i; i < maRows.length; ++i) {
            if (maRows[i].authorityClass != 2) continue;
            bytes32 id =
                Associations(suite.owners[4]).attestationAssociation(maRows[i].record).artistId;
            address signer = Attribution(suite.owners[4]).attestationRecord(maRows[i].record).signer;
            (bool used,) = next.registry.delegatedNonceState(id, signer, maRows[i].input.nonce);
            require(
                used,
                "each original op24 delegated nonce including 4/5 and independent 77 lanes survives"
            );
        }
        for (uint256 i; i < maRows.length; ++i) {
            require(
                Classes(next.coordinator.suiteConfiguration().owners[4])
                    .attestationAuthorityClass(maRows[i].record) == maRows[i].authorityClass,
                "original authority class"
            );
        }
    }

    function _maSemantics(T.SuiteConfiguration memory s) internal view returns (bytes32 h) {
        for (uint256 i; i < maRows.length; ++i) {
            bytes32 record = maRows[i].record;
            T.Attestation memory terms = maRows[i].input.terms;
            h = keccak256(
                abi.encode(
                    h,
                    Attribution(s.owners[4]).attestationRecord(record),
                    Classes(s.owners[4]).attestationAuthorityClass(record),
                    Associations(s.owners[4]).attestationAssociation(record),
                    Attribution(s.owners[4]).statementBytes(terms.statementHash),
                    AttestationPublications(s.owners[4]).publicationAttestation(record),
                    Credentials(s.owners[4]).c2paCredentialRecord(record),
                    Personhood(s.owners[4]).personhoodProofSummary(record),
                    Personhood(s.owners[4]).personhoodProofSummaryHash(record),
                    Attribution(s.owners[4])
                        .attestation(terms.collectionId, terms.subjectKind, terms.subjectId)
                )
            );
        }
        for (uint256 a; a < multiArtists.length; ++a) {
            h = keccak256(
                abi.encode(h, Credentials(s.owners[4]).c2paCredentialHead(multiArtists[a]))
            );
        }
        for (uint256 k; k < 2; ++k) {
            h = keccak256(
                abi.encode(
                    h,
                    Credentials(s.owners[4]).personhoodAttestation(k + 1, multiCollectionArtists[k])
                )
            );
        }
    }

    function _maHash(Successor memory next) internal view returns (bytes32 h) {
        h = keccak256(
            abi.encode(_mcHash(next), _maSemantics(next.coordinator.suiteConfiguration()))
        );
        for (uint256 i; i < maRows.length; ++i) {
            if (maRows[i].authorityClass != 2) continue;
            bytes32 id =
                Associations(suite.owners[4]).attestationAssociation(maRows[i].record).artistId;
            address signer = Attribution(suite.owners[4]).attestationRecord(maRows[i].record).signer;
            (bool used, uint256 hint) =
                next.registry.delegatedNonceState(id, signer, maRows[i].input.nonce);
            h = keccak256(abi.encode(h, id, signer, maRows[i].input.nonce, used, hint));
        }
    }

    function _maBadRequest(Successor memory next, RH.Request memory r) internal {
        (bool ok,) = address(next.registry)
            .call(
                abi.encodeCall(
                    ConsentHydration.hydrateRecoveredArtistAuthorityWithConsents,
                    (r, _maRoyalties())
                )
            );
        require(!ok, "incomplete source refuses");
    }
}
