// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistPublicationHydrationFixture.sol";

/// @notice Original seven publication hydration regression bodies; shared setup is inherited unchanged.
contract StreamArtistPublicationAuthorityHydrationTest is ArtistPublicationHydrationFixture {
    function testPublicationHydrationRetainsBothKindsAndFreshSuccessorSafeDomain() external {
        _publicationHistory();
        // Retain a superseded kind8 head as well as the final head.
        (P.Publication memory pub, T.Attestation memory p, bytes memory statement) =
            _publicationTerms(candidateHost, false);
        _recordPublication(pub, p, statement);
        Next memory n = _cutover(true, true);
        RH.Request memory request = _readyRequest();
        require(
            PublicationHydrate(address(n.registry)).hydrateArtistAuthorityWithPublications(request)
                != 0,
            "complete publication profile commits"
        );
        _assertPublications(n);
        for (uint256 j; j < publications.length; ++j) {
            bytes32 record = originalAttestationRecords[publicationIndices[j]];
            P.Evidence memory actual = n.registry.requireRecordPublication(record, publications[j]);
            require(
                actual.attestationRecordHash == record,
                "retained evidence undergoes current validating read"
            );
        }
        T.Authorization memory fresh = T.Authorization(
            IStreamArtistIdentityOwner(n.identity).identity(artistId).nonceHint,
            uint64(block.timestamp),
            ""
        );
        bytes32 oldDigest = ingress.attestationDigest(p, fresh);
        bytes32 newDigest = n.registry.attestationDigest(p, fresh);
        require(oldDigest != newDigest, "successor does not rewrite the original signature domain");
        fresh.signature = _signature(oldDigest);
        bytes32 roots = _allRoots(n.coordinator);
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(
            address(n.registry),
            abi.encodeCall(IStreamArtistOnboarding.recordArtistAttestation, (p, fresh, statement))
        );
        require(
            _allRoots(n.coordinator) == roots, "old-domain signature cannot authorize a new write"
        );
        fresh.signature = _signature(newDigest);
        require(
            this.executeTargetSafe(
                address(n.registry),
                abi.encodeCall(
                    IStreamArtistOnboarding.recordArtistAttestation, (p, fresh, statement)
                )
            ),
            "actual Safe signs fresh successor-domain publication"
        );
        T.SuiteConfiguration memory target = n.coordinator.suiteConfiguration();
        bytes32 latest =
            IStreamArtistAttributionOwner(target.owners[4])
        .attestation(1, p.subjectKind, p.subjectId)
        .recordHash;
        require(
            latest != originalAttestationRecords[publicationIndices[2]],
            "new native record follows imported head"
        );
        require(
            n.registry.requireRecordPublication(latest, pub).attestationRecordHash == latest,
            "fresh record is admitted by unchanged current consumer"
        );
        _assertPublications(n);
    }

    function testPublicationHydrationOldSelectorAndOmittedOriginalInputsRemainClosed() external {
        _publicationHistory();
        Next memory n = _cutover(true, true);
        RH.Request memory p = _readyRequest();
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        ReadyHydrate(address(n.registry)).hydrateArtistAuthorityWithReadiness(p);
        _notHydrated(n);
        RH.AttestationInput[] memory original = p.attestations;
        p.attestations = new RH.AttestationInput[](original.length - 1);
        for (uint256 j; j < p.attestations.length; ++j) {
            p.attestations[j] = original[j];
        }
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        PublicationHydrate(address(n.registry)).hydrateArtistAuthorityWithPublications(p);
        _notHydrated(n);
        p.attestations = original;
        p.attestations[publicationIndices[0]].nonce += 1;
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        PublicationHydrate(address(n.registry)).hydrateArtistAuthorityWithPublications(p);
        _notHydrated(n);
        p.attestations[publicationIndices[0]].nonce -= 1;
        require(
            PublicationHydrate(address(n.registry)).hydrateArtistAuthorityWithPublications(p) != 0,
            "exact complete inputs retry without partial activation"
        );
    }

    function testPublicationHydrationIndependentlyChecksCompleteSavedPublicationGetter() external {
        _publicationHistory();
        Next memory n = _cutover(true, true);
        RH.Request memory p = _readyRequest();
        bytes32 record = originalAttestationRecords[publicationIndices[0]];
        IStreamArtistRecordPublicationOwner.Record memory empty;
        avm.mockCall(
            suite.owners[4],
            abi.encodeCall(IStreamArtistRecordPublicationOwner.publicationAttestation, (record)),
            abi.encode(empty)
        );
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        PublicationHydrate(address(n.registry)).hydrateArtistAuthorityWithPublications(p);
        _notHydrated(n);
        avm.clearMockedCalls();
        require(
            PublicationHydrate(address(n.registry)).hydrateArtistAuthorityWithPublications(p) != 0,
            "original immutable evidence getter restores same complete request"
        );
        _assertPublications(n);
    }

    function testPublicationHydrationRejectsForeignBindingCapabilityAndHostFacts() external {
        _publicationHistory();
        Next memory n = _cutover(true, true);
        RH.Request memory p = _readyRequest();
        AH.Query memory q;
        q.artistId = artistId;
        q.collectionId = 1;
        q.bindingHash = IStreamArtistBindingOwner(suite.owners[0]).binding(1).bindingHash;
        bytes memory original = PublicationExport(suite.owners[4])
            .authorityPublicationHydrationState(q, p.attestations);
        for (uint256 kind; kind < 3; ++kind) {
            PubH.Bundle memory b = StreamArtistPublicationHydration.decode(original);
            uint256 j = publicationIndices[0];
            if (kind == 0) {
                b.records[j].publication.evidence.bindingHash = keccak256("foreign binding");
            } else if (kind == 1) {
                b.records[j].publication.evidence.requiredCapability = 1;
            } else {
                b.records[j].publication.metadataHostCodeHash = 0;
            }
            bytes memory forged =
                abi.encode(b.schema, b.sourceRegistry, b.state, b.generation, b.records);
            avm.mockCall(
                suite.owners[4],
                abi.encodePacked(PublicationExport.authorityPublicationHydrationState.selector),
                abi.encode(forged)
            );
            vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
            PublicationHydrate(address(n.registry)).hydrateArtistAuthorityWithPublications(p);
            _notHydrated(n);
            avm.clearMockedCalls();
        }
        require(
            PublicationHydrate(address(n.registry)).hydrateArtistAuthorityWithPublications(p) != 0,
            "unmodified complete publication profile survives independent checks"
        );
    }

    function testPublicationHydrationHistoricalHostDoesNotBypassCurrentSelection() external {
        _publicationHistory();
        Next memory n = _cutover(true, true);
        RH.Request memory p = _readyRequest();
        // A valid old record remains historical even when the selected candidate host changes.
        ArtistPublicationHostFixture replacement = new ArtistPublicationHostFixture(address(core));
        core.set(keccak256("COLLECTION_METADATA"), address(replacement), false);
        require(
            PublicationHydrate(address(n.registry)).hydrateArtistAuthorityWithPublications(p) != 0,
            "hydrate stored evidence without fabricating current host approval"
        );
        _assertPublications(n);
        bytes32 record = originalAttestationRecords[publicationIndices[0]];
        vm.expectRevert(abi.encodeWithSelector(T.ComponentChanged.selector, address(replacement)));
        n.registry.requireRecordPublication(record, publications[0]);
        core.set(keccak256("COLLECTION_METADATA"), address(candidateHost), false);
        require(
            n.registry.requireRecordPublication(record, publications[0]).attestationRecordHash
                == record,
            "restored current host permits the same independently validated evidence"
        );
    }

    function testPublicationHydrationPreservesActualMetadataPayloadReceiptAndConsumedAuthorization()
        external
    {
        actualSaleRegistryFixture = true;
        setUp();
        _compactSource();
        _economicHistory();
        _recordRatification();
        ArtistCanonicalPublicationFixture f = new ArtistCanonicalPublicationFixture();
        f.deploy(address(core), address(ingress));
        StreamCollectionMetadataV1 host = f.metadata();
        _saleRegister(
            saleModules,
            factory.governanceAuthority(),
            address(host),
            keccak256("COLLECTION_METADATA"),
            type(IStreamCollectionMetadataV1).interfaceId
        );
        core.set(keccak256("COLLECTION_METADATA"), address(host), false);
        bytes memory payload =
            bytes('{"intent":"original publication retained across Artist replacement"}');
        (IStreamPreservationRecords.CollectionRecord memory record, P.Publication memory pub) = f.prepare(
            address(artist),
            keccak256("ARTIST_INTENT"),
            keccak256("STREAM_ARTIST_INTENT_V1"),
            payload,
            "urn:original:published"
        );
        (T.Attestation memory p, bytes memory statement) = _canonicalAttestation(pub, record.uri);
        bytes32 authorization = _recordPublication(pub, p, statement);
        require(
            host.recordArtistCollectionRecordWithPayload(
                address(artist), 1, record, payload, authorization
            ) == pub.candidateRecordHash,
            "actual original Artist and Metadata publication"
        );
        (, IStreamCollectionMetadataV1.RecordReceipt memory beforeReceipt) =
            host.collectionRecord(pub.candidateRecordHash);
        Next memory n = _cutover(true, true);
        require(
            PublicationHydrate(address(n.registry))
                .hydrateArtistAuthorityWithPublications(_readyRequest()) != 0,
            "actual published history hydration"
        );
        _assertPublications(n);
        (
            IStreamPreservationRecords.CollectionRecord memory afterRecord,
            IStreamCollectionMetadataV1.RecordReceipt memory afterReceipt
        ) = host.collectionRecord(pub.candidateRecordHash);
        (, bytes memory afterPayload) = host.recordPayload(pub.candidateRecordHash);
        require(
            keccak256(abi.encode(record)) == keccak256(abi.encode(afterRecord))
                && keccak256(abi.encode(beforeReceipt)) == keccak256(abi.encode(afterReceipt))
                && keccak256(payload) == keccak256(afterPayload)
                && host.consumedArtistAuthorization(authorization),
            "same Metadata owner retains canonical bytes, receipt and one-use state"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionMetadataV1.MetadataAuthorizationConsumed.selector, authorization
            )
        );
        host.recordArtistCollectionRecordWithPayload(
            address(artist), 1, record, payload, authorization
        );
    }

    function testPublicationHydrationArchiveFailureRollsBackAllOwnersAndIdenticalSafeRetry()
        external
    {
        _publicationHistory();
        Next memory n = _cutover(true, true);
        RH.Request memory p = _readyRequest();
        bytes memory call_ =
            abi.encodeCall(PublicationHydrate.hydrateArtistAuthorityWithPublications, (p));
        bytes32 roots = _allRoots(n.coordinator);
        uint256 payloads = n.archive.storedPayloadCount();
        uint256 safeNonce = artist.nonce();
        avm.mockCallRevert(
            address(n.archive),
            abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSignature("Error(string)", "publication hydration archive")
        );
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(n.registry), call_);
        _notHydrated(n);
        require(
            _allRoots(n.coordinator) == roots && n.archive.storedPayloadCount() == payloads
                && artist.nonce() == safeNonce,
            "late Archive restores roots, carriers and Safe transaction nonce"
        );
        avm.clearMockedCalls();
        require(
            this.executeTargetSafe(address(n.registry), call_),
            "byte-identical actual Safe hydration retry"
        );
        _assertPublications(n);
        require(
            n.archive.storedPayloadCount() > payloads,
            "original publication statement and signatures register atomically"
        );
    }
}
