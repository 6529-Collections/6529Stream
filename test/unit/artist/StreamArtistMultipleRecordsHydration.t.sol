// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistMultipleRecordsHydrationFixture.sol";
import "../../../smart-contracts/domains/artist/StreamArtistMultipleRecordsOperations.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistMultipleRecordsHydration.sol";

/// @notice Actual registries, fixed owners, Archive and threshold Safes. Core, governance,
/// candidate host and content state remain named typed fixture boundaries. No current-graph claim.
contract StreamArtistMultipleRecordsHydrationTest is ArtistMultipleRecordsHydrationFixture {
    mapping(uint256 => T.EconomicsConsent[]) private economicInputs;
    mapping(uint256 => RH.AttestationInput[]) private attestationInputs;
    bytes32[] private attestationRecords;

    function _start(bool shared) private {
        directHistory = true;
        _source(shared);
    }

    function _mr() private view returns (MR.Request memory p) {
        p.authority = _request();
        p.witnesses = new MR.CollectionWitness[](2);
        for (uint256 c; c < 2; ++c) {
            p.witnesses[c].collectionId = c + 1;
            p.witnesses[c].economics = economicInputs[c + 1];
            p.witnesses[c].attestations = attestationInputs[c + 1];
        }
    }

    // No pre-call reads or success-only assertions: expected-refusal oracles call this directly.
    function _call(Next memory n, MR.Request memory p) private returns (bytes32) {
        return IStreamArtistMultipleRecordsHydration(address(n.registry))
            .hydrateMultipleArtistAuthorityWithRecords(p);
    }

    function _run(Next memory n, MR.Request memory p) private returns (bytes32 value) {
        bytes32 beforeRoots = _allRoots(n.coordinator);
        vm.recordLogs();
        value = _call(n, p);
        uint256[] memory ids = new uint256[](p.authority.collections.length);
        for (uint256 i; i < ids.length; ++i) {
            ids[i] = p.authority.collections[i].collectionId;
        }
        _historyEvent(
            vm.getRecordedLogs(),
            address(n.coordinator),
            keccak256("MultipleArtistAuthorityHydrated(address,bytes32,bytes32[],uint256[])"),
            bytes32(uint256(uint160(address(ingress)))),
            value,
            abi.encode(p.authority.artistIds, ids)
        );
        _envelope(n, p, value, beforeRoots);
        require(value != 0, "complete record profile");
        T.SuiteConfiguration memory s = n.coordinator.suiteConfiguration();
        for (uint256 i; i < 7; ++i) {
            require(
                HydrationOwner(s.owners[i]).authorityHydrationCommitment() == value,
                "one seven-owner commitment"
            );
        }
    }

    function _envelope(Next memory n, MR.Request memory p, bytes32 value, bytes32 beforeRoots)
        private
        view
    {
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(n.registry),
                address(n.coordinator),
                uint16(60),
                address(this),
                value
            )
        );
        bytes memory encoded = n.archive.artistEvidenceBytesV2(id, 1);
        (
            uint16 schema,
            bytes32 config,
            uint16 op,
            address actor,
            bytes32 record,
            T.Snapshot[7] memory before_,
            T.Snapshot[7] memory after_,
            bytes memory payload
        ) = abi.decode(
            encoded,
            (uint16, bytes32, uint16, address, bytes32, T.Snapshot[7], T.Snapshot[7], bytes)
        );
        require(
            encoded.length <= 24575 && schema == 1 && config == n.coordinator.configurationHash()
                && op == 60 && actor == address(this) && record == value,
            "exact original Archive envelope"
        );
        require(
            keccak256(abi.encode(before_)) == beforeRoots
                && keccak256(abi.encode(after_)) == _allRoots(n.coordinator),
            "before/after all-owner root order"
        );
        (
            bytes32 profile,
            address prior,
            address sourceCoordinator,
            CP.Checkpoint[7] memory headers,
            AH.Query memory q,
            AH.OwnerData[7] memory data
        ) = abi.decode(
            payload, (bytes32, address, address, CP.Checkpoint[7], AH.Query, AH.OwnerData[7])
        );
        require(
            profile == keccak256("6529STREAM_ARTIST_MULTIPLE_LIVING_RECORDS_V1")
                && prior == address(ingress) && sourceCoordinator == address(coordinator)
        );
        require(
            keccak256(abi.encode(headers)) == keccak256(abi.encode(p.authority.expectedSource)),
            "exact source headers"
        );
        AH.Request memory anchor;
        anchor.artistId = q.artistId;
        anchor.collectionId = q.collectionId;
        anchor.policies = q.policies;
        anchor.expectedSource = headers;
        anchor.replayOrigins = p.authority.replayOrigins;
        require(
            value
                == keccak256(
                    abi.encode(
                        profile,
                        block.chainid,
                        address(n.registry),
                        address(n.coordinator),
                        prior,
                        sourceCoordinator,
                        anchor,
                        q,
                        data
                    )
                ),
            "independent original op60 commitment"
        );
        for (uint256 i; i < 7; ++i) {
            require(after_[i].revision == before_[i].revision + 1, "exactly one commit per owner");
            require(
                keccak256(abi.encode(data[i].origins))
                    == keccak256(abi.encode(p.authority.replayOrigins[i])),
                "complete ordered guard inventory"
            );
        }
        (bytes32 payoutTag, MR.PayoutRow[] memory payouts) =
            abi.decode(data[5].typedState, (bytes32, MR.PayoutRow[]));
        require(
            payoutTag == keccak256("6529STREAM_ARTIST_MULTIPLE_RECORDS_PAYOUT_V1")
                && payouts.length == p.authority.artistIds.length
                && keccak256(data[5].typedState) == keccak256(abi.encode(payoutTag, payouts))
        );
        for (uint256 a; a < payouts.length; ++a) {
            require(payouts[a].artistId == p.authority.artistIds[a], "exact artist order");
        }
        (bytes32 consentTag, MR.ConsentRow[] memory consents) =
            abi.decode(data[6].typedState, (bytes32, MR.ConsentRow[]));
        require(
            consentTag == keccak256("6529STREAM_ARTIST_MULTIPLE_RECORDS_CONSENT_V1")
                && consents.length == p.witnesses.length
                && keccak256(data[6].typedState) == keccak256(abi.encode(consentTag, consents))
        );
        for (uint256 c; c < consents.length; ++c) {
            require(
                consents[c].query.collectionId == p.witnesses[c].collectionId
                    && consents[c].query.artistId == p.authority.collections[c].artistId
            );
            require(consents[c].economics.length == p.witnesses[c].economics.length);
            for (uint256 j; j < consents[c].economics.length; ++j) {
                require(
                    keccak256(abi.encode(consents[c].economics[j].terms))
                        == keccak256(abi.encode(p.witnesses[c].economics[j])),
                    "complete economics witnesses"
                );
            }
        }
        (bytes32 attrTag, MR.Attribution memory attrs) =
            abi.decode(data[4].typedState, (bytes32, MR.Attribution));
        require(
            attrTag == keccak256("6529STREAM_ARTIST_MULTIPLE_RECORDS_ATTRIBUTION_V1")
                && attrs.sourceRegistry == address(ingress)
                && keccak256(data[4].typedState) == keccak256(abi.encode(attrTag, attrs))
        );
        require(
            attrs.records.length == Native(suite.owners[4]).artistNativeReceiptCount(),
            "global attribution inventory"
        );
        uint256[] memory counts = new uint256[](p.witnesses.length);
        for (uint256 j; j < attrs.records.length; ++j) {
            PubH.Row memory row = attrs.records[j];
            uint256 c = row.attestation.input.terms.collectionId - 1;
            require(
                row.attestation.record.recordHash
                    == Native(suite.owners[4]).artistNativeReceiptAt(j).recordHash,
                "original global order"
            );
            require(
                keccak256(abi.encode(row.attestation.input))
                    == keccak256(abi.encode(p.witnesses[c].attestations[counts[c]++])),
                "original complete op24 witness"
            );
        }
        for (uint256 c; c < counts.length; ++c) {
            require(counts[c] == p.witnesses[c].attestations.length);
        }
    }

    function _payoutRecord(
        bytes32 id,
        OfficialSafe signer,
        uint256[] memory signingKeys,
        address payee
    ) private returns (bytes32 record) {
        (, bytes32 previous) = ingress.artistPayoutAccount(id);
        T.PayoutDesignation memory p = T.PayoutDesignation(id, payee, previous);
        T.Authorization memory a = T.Authorization(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(id).nonceHint,
            uint64(block.timestamp),
            ""
        );
        _auth(id, ingress.payoutDesignationDigest(p, a), a.nonce);
        require(
            executeSafe(
                signer,
                signingKeys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistOnboarding.recordPayoutDesignation, (p, a)),
                0
            )
        );
        (, record) = ingress.artistPayoutAccount(id);
        _candidate(5, "payout_lifecycle.replay.designation_chain", keccak256(abi.encode(id)));
    }

    function _econ() private returns (T.EconomicsConsent memory p, bytes32 record) {
        (T.AssignmentFact memory fact,) = coordinator.reads().currentAssignments(1);
        p = T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
        T.Authorization memory a = T.Authorization(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint,
            uint64(block.timestamp),
            ""
        );
        _auth(artistId, ingress.economicsConsentDigest(p, a), a.nonce);
        require(
            this.executeTargetSafe(
                address(ingress),
                abi.encodeCall(IStreamArtistOnboarding.recordEconomicsConsent, (p, a))
            )
        );
        economicInputs[1].push(p);
        record = IStreamArtistConsentOwner(suite.owners[6]).economicsRecord(p);
        _candidate(6, "consent_finality.replay.consent_key", keccak256(abi.encode(p)));
    }

    function _attest(T.Attestation memory p, bytes memory statement)
        private
        returns (bytes32 record)
    {
        bytes32 id = p.collectionId == 1 ? artistId : secondId;
        OfficialSafe signer = p.collectionId == 1 ? artist : second;
        uint256[] memory signingKeys = p.collectionId == 1 ? keys : secondKeys;
        T.Authorization memory a = T.Authorization(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(id).nonceHint,
            uint64(block.timestamp),
            ""
        );
        _auth(id, ingress.attestationDigest(p, a), a.nonce);
        require(
            executeSafe(
                signer,
                signingKeys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistOnboarding.recordArtistAttestation, (p, a, statement)),
                0
            )
        );
        record =
        IStreamArtistAttributionOwner(suite.owners[4])
        .attestation(p.collectionId, p.subjectKind, p.subjectId)
        .recordHash;
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
                        id,
                        address(signer),
                        uint8(1),
                        a.nonce,
                        uint64(block.timestamp)
                    )
                ),
            "original op24 complete preimage"
        );
        _candidate(2, "identity_authority.replay.attestation_key", keccak256(abi.encode(record)));
        attestationInputs[p.collectionId].push(RH.AttestationInput(p, a.nonce));
        attestationRecords.push(record);
    }

    function _personhood(uint256 collection) private returns (bytes32) {
        bytes32 id = collection == 1 ? artistId : secondId;
        bytes memory statement = bytes("p");
        T.Attestation memory p = T.Attestation(
            collection,
            10,
            id,
            ingress.operativeIdentityRecord(id),
            keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1"),
            keccak256(statement),
            ""
        );
        return _attest(p, statement);
    }

    function _credential(uint256 collection, bytes32 previous) private returns (bytes32) {
        bytes32 id = collection == 1 ? artistId : secondId;
        C2PA.Credential[] memory empty = new C2PA.Credential[](0);
        bytes memory statement =
            abi.encode(C2PA.Payload(1, id, ingress.operativeIdentityRecord(id), previous, empty));
        return _attest(
            T.Attestation(
                collection,
                10,
                id,
                ingress.operativeIdentityRecord(id),
                keccak256("6529STREAM_ARTIST_C2PA_CREDENTIALS_V1"),
                keccak256(statement),
                ""
            ),
            statement
        );
    }

    function _readyRecords() private returns (bytes32 ratification, bytes32 content) {
        (, bytes32 state) = metadata.currentArtistContentState(1);
        T.Ratification memory p = T.Ratification(1, address(metadata), state);
        T.Authorization memory a = T.Authorization(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint,
            uint64(block.timestamp),
            ""
        );
        _auth(artistId, ingress.contentRatificationDigest(p, a), a.nonce);
        require(
            this.executeTargetSafe(
                address(ingress),
                abi.encodeCall(IStreamArtistOnboarding.recordContentRatification, (p, a))
            )
        );
        ratification =
        IStreamArtistConsentOwner(suite.owners[6]).firstReleaseRatification(1).recordHash;
        _candidate(
            6,
            "consent_finality.replay.ratification_key",
            keccak256(abi.encode(uint256(1), ratification))
        );
        Content.Consent memory cp = _contentProposal(keccak256("records future source"));
        a.nonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        _auth(artistId, ingress.contentConsentDigest(cp, a), a.nonce);
        require(
            this.executeTargetSafe(
                address(ingress),
                abi.encodeCall(IStreamArtistContentAuthority.recordContentConsent, (cp, a))
            )
        );
        content =
        IStreamArtistContentRecordsOwner(suite.owners[6]).contentConsentAt(cp, 1).recordHash;
        _candidate(
            6,
            "consent_finality.replay.content_consent_key",
            keccak256(abi.encode(keccak256(abi.encode(cp, uint64(1))), content))
        );
    }

    function _attestationParity(Next memory n) private view {
        address owner = n.coordinator.suiteConfiguration().owners[4];
        for (uint256 j; j < attestationRecords.length; ++j) {
            bytes32 record = attestationRecords[j];
            T.AttestationRecord memory original =
                IStreamArtistAttributionOwner(suite.owners[4]).attestationRecord(record);
            require(
                keccak256(abi.encode(original))
                    == keccak256(
                        abi.encode(IStreamArtistAttributionOwner(owner).attestationRecord(record))
                    ),
                "full original record"
            );
            require(
                keccak256(
                    IStreamArtistAttributionOwner(owner).statementBytes(original.statementHash)
                )
                == keccak256(
                    IStreamArtistAttributionOwner(suite.owners[4])
                        .statementBytes(original.statementHash)
                ),
                "original statement"
            );
            require(
                keccak256(IStreamArtistIdentityOwner(n.identity).signatureBundle(record))
                    == keccak256(
                        IStreamArtistIdentityOwner(suite.owners[2]).signatureBundle(record)
                    ),
                "original signatures"
            );
        }
    }

    function testSharedArtistPayoutAndSecondCollectionPersonhoodRemainExact() external {
        _start(true);
        bytes32 payout = _payoutRecord(artistId, artist, keys, address(0xbeef));
        _personhood(2);
        Next memory n = _cutover(true);
        _run(n, _mr());
        _attestationParity(n);
        (address payee, bytes32 record) = n.registry.artistPayoutAccount(artistId);
        require(payee == address(0xbeef) && record == payout);
    }

    function testTwoArtistsRetainSeparatePayoutChainsAndNonceTrees() external {
        _start(false);
        bytes32 a = _payoutRecord(artistId, artist, keys, address(artist));
        bytes32 b = _payoutRecord(secondId, second, secondKeys, address(second));
        Next memory n = _cutover(true);
        _run(n, _mr());
        (, bytes32 x) = n.registry.artistPayoutAccount(artistId);
        (, bytes32 y) = n.registry.artistPayoutAccount(secondId);
        require(x == a && y == b);
        require(
            IStreamArtistIdentityOwner(n.identity).identity(artistId).nonceHint
                == IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint
        );
        require(
            IStreamArtistIdentityOwner(n.identity).identity(secondId).nonceHint
                == IStreamArtistIdentityOwner(suite.owners[2]).identity(secondId).nonceHint
        );
    }

    function testEconomicsRetainsPayloadBindingAndConsumedCell() external {
        _start(true);
        _payoutRecord(artistId, artist, keys, address(artist));
        (T.EconomicsConsent memory p, bytes32 record) = _econ();
        Next memory n = _cutover(true);
        MR.Request memory request = _mr();
        _run(n, request);
        address owner = n.coordinator.suiteConfiguration().owners[6];
        require(IStreamArtistConsentOwner(owner).economicsRecord(p) == record);
        require(
            keccak256(
                abi.encode(IStreamArtistEconomicsEvidence(owner).economicsRecordAssociation(record))
            )
            == keccak256(
                abi.encode(
                    IStreamArtistEconomicsEvidence(suite.owners[6])
                        .economicsRecordAssociation(record)
                )
            )
        );
    }

    function testRatificationAndPendingContentAreCarriedWithOriginalHostTerms() external {
        _start(true);
        (bytes32 ratification, bytes32 content) = _readyRecords();
        Next memory n = _cutover(true);
        _run(n, _mr());
        address owner = n.coordinator.suiteConfiguration().owners[6];
        require(
            IStreamArtistConsentOwner(owner).firstReleaseRatification(1).recordHash == ratification
        );
        require(
            keccak256(
                abi.encode(IStreamArtistContentRecordsOwner(owner).contentConsentRecord(content))
            )
            == keccak256(
                abi.encode(
                    IStreamArtistContentRecordsOwner(suite.owners[6]).contentConsentRecord(content)
                )
            )
        );
    }

    function testGlobalCredentialOrderAcrossCollectionsPreservesHeadAndPersonhood() external {
        _start(true);
        bytes32 first = _credential(2, 0);
        bytes32 last = _credential(1, first);
        Next memory n = _cutover(true);
        _run(n, _mr());
        _attestationParity(n);
        address owner = n.coordinator.suiteConfiguration().owners[4];
        require(IStreamArtistC2PAReads(owner).c2paCredentialHead(artistId).recordHash == last);
        require(
            IStreamArtistC2PAReads(owner).c2paCredentialRecord(last).previousRecordHash == first
        );
    }

    function testMissingExtraDuplicateAndWrongNonceAttestationWitnessesFailBeforeWrites() external {
        _start(true);
        _personhood(2);
        Next memory n = _cutover(true);
        MR.Request memory p = _mr();
        RH.AttestationInput[] memory valid = p.witnesses[1].attestations;
        p.witnesses[1].attestations = new RH.AttestationInput[](0);
        avm.expectRevert(T.InvalidRecord.selector);
        _call(n, p);
        _empty(n);
        p.witnesses[1].attestations = new RH.AttestationInput[](2);
        p.witnesses[1].attestations[0] = valid[0];
        p.witnesses[1].attestations[1] = valid[0];
        avm.expectRevert(T.InvalidRecord.selector);
        _call(n, p);
        _empty(n);
        p.witnesses[1].attestations = valid;
        uint256 nonce = valid[0].nonce;
        p.witnesses[1].attestations[0].nonce = nonce + 1;
        avm.expectRevert(T.InvalidRecord.selector);
        _call(n, p);
        _empty(n);
        p.witnesses[1].attestations[0].nonce = nonce;
        _run(n, p);
    }

    function testCrossArtistAndReorderedWitnessRowsCannotReplaceCompletePartition() external {
        _start(false);
        _personhood(1);
        Next memory n = _cutover(true);
        MR.Request memory p = _mr();
        p.witnesses[1].attestations = p.witnesses[0].attestations;
        p.witnesses[0].attestations = new RH.AttestationInput[](0);
        avm.expectRevert(T.InvalidRecord.selector);
        _call(n, p);
        _empty(n);
        p = _mr();
        p.witnesses[0].collectionId = 2;
        avm.expectRevert(T.InvalidRecord.selector);
        _call(n, p);
        _empty(n);
    }

    function testMissingAndForeignEconomicsTermsCannotSelectARecordSubset() external {
        _start(true);
        _payoutRecord(artistId, artist, keys, address(artist));
        _econ();
        Next memory n = _cutover(true);
        MR.Request memory p = _mr();
        p.witnesses[0].economics = new T.EconomicsConsent[](0);
        avm.expectRevert(T.InvalidRecord.selector);
        _call(n, p);
        _empty(n);
        p = _mr();
        p.witnesses[0].economics[0].collectionId = 2;
        avm.expectRevert(T.InvalidRecord.selector);
        _call(n, p);
        _empty(n);
        _run(n, _mr());
    }

    function testChangedSourceHeaderRefusesBeforeAnyImportedMarker() external {
        _start(true);
        _personhood(2);
        Next memory n = _cutover(true);
        MR.Request memory p = _mr();
        CP.Checkpoint memory changed =
            abi.decode(abi.encode(p.authority.expectedSource[4]), (CP.Checkpoint));
        changed.ownerState.stateRoot = keccak256("drift");
        avm.mockCall(
            suite.owners[4], abi.encodeCall(CP.authorityCheckpoint, ()), abi.encode(changed)
        );
        avm.expectRevert(T.InvalidRecord.selector);
        _call(n, p);
        _empty(n);
        avm.clearMockedCalls();
        _run(n, p);
    }

    function testLateArchiveFailureRestoresAllOwnersAndExactSafeRequest() external {
        _start(true);
        _personhood(2);
        Next memory n = _cutover(true);
        MR.Request memory p = _mr();
        bytes memory data = abi.encodeCall(
            IStreamArtistMultipleRecordsHydration.hydrateMultipleArtistAuthorityWithRecords, (p)
        );
        uint256 nonce = artist.nonce();
        bytes32 roots = _allRoots(n.coordinator);
        avm.mockCallRevert(
            address(n.archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSignature("Error(string)", "late records Archive")
        );
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(n.registry), data);
        _empty(n);
        require(artist.nonce() == nonce && _allRoots(n.coordinator) == roots);
        avm.clearMockedCalls();
        require(this.executeTargetSafe(address(n.registry), data));
        _attestationParity(n);
        avm.expectRevert(T.InvalidRecord.selector);
        _call(n, p);
    }

    function testOldMultipleSelectorStillRefusesNewRecordFamilies() external {
        _start(true);
        _personhood(2);
        Next memory n = _cutover(true);
        MH.Request memory oldRequest = _request();
        avm.expectRevert(T.UnsupportedProfile.selector);
        IStreamArtistMultipleAuthorityHydration(address(n.registry))
            .hydrateMultipleArtistAuthority(oldRequest);
        _empty(n);
        _run(n, _mr());
    }

    function testPublicationBothKindsKeepFullSavedEvidenceAndFreshDomain() external {
        actualSaleRegistryFixture = true;
        setUp();
        _start(true);
        ArtistPublicationHostFixture host = new ArtistPublicationHostFixture(address(core));
        _saleRegister(
            saleModules,
            factory.governanceAuthority(),
            address(host),
            keccak256("COLLECTION_METADATA"),
            type(IStreamArtistRecordPublicationHost).interfaceId
        );
        core.set(keccak256("COLLECTION_METADATA"), address(host), false);
        (P.Publication memory pub, T.Attestation memory terms, bytes memory statement) =
            _publicationTerms(host, true);
        _attest(terms, statement);
        (pub, terms, statement) = _publicationTerms(host, false);
        bytes32 last = _attest(terms, statement);
        Next memory n = _cutover(true);
        _run(n, _mr());
        _attestationParity(n);
        require(
            keccak256(
                abi.encode(
                    IStreamArtistRecordPublicationOwner(
                            n.coordinator.suiteConfiguration().owners[4]
                        ).publicationAttestation(last)
                )
            )
            == keccak256(
                abi.encode(
                    IStreamArtistRecordPublicationOwner(suite.owners[4])
                        .publicationAttestation(last)
                )
            )
        );
        require(n.registry.requireRecordPublication(last, pub).attestationRecordHash == last);
        T.Authorization memory a = T.Authorization(
            IStreamArtistIdentityOwner(n.identity).identity(artistId).nonceHint,
            uint64(block.timestamp),
            ""
        );
        require(n.registry.attestationDigest(terms, a) != ingress.attestationDigest(terms, a));
    }

    function testNewProfileStillPreservesGlobalGrantUseBeforeImportingRecords() external {
        _start(true);
        bytes32 grant = _grantFor(artistId, artist, keys, 0, 2);
        _delegatedPolicy(2, artistId, grant, 0);
        _personhood(1);
        Next memory n = _cutover(true);
        _run(n, _mr());
        require(
            n.registry.recordDelegation(savedPolicies[1]) == grant
                && n.registry.delegationRecord(grant).uses == 1
        );
    }

    function testFullReadinessCombinationHasOneAtomicAllOwnerCommit() external {
        _start(true);
        _payoutRecord(artistId, artist, keys, address(artist));
        _econ();
        _readyRecords();
        _personhood(2);
        Next memory n = _cutover(true);
        _run(n, _mr());
        _attestationParity(n);
    }

    function testCredentialHeadOmissionCannotDropNewNamespace() external {
        _start(true);
        _credential(2, 0);
        Next memory n = _cutover(true);
        MR.Request memory p = _mr();
        C2PA.Head memory empty;
        avm.mockCall(
            suite.owners[4],
            abi.encodeCall(IStreamArtistC2PAReads.c2paCredentialHead, (artistId)),
            abi.encode(empty)
        );
        avm.expectRevert(T.InvalidRecord.selector);
        _call(n, p);
        _empty(n);
        avm.clearMockedCalls();
        _run(n, p);
    }

    function testUnsupportedEntropyConfigurationCannotRideAnOp17Receipt() external {
        _start(true);
        (, bytes32 record) = _readyRecords();
        Next memory n = _cutover(true);
        MR.Request memory p = _mr();
        IStreamArtistContentRecordsOwner.ConsentRecord memory r =
            IStreamArtistContentRecordsOwner(suite.owners[6]).contentConsentRecord(record);
        r.terms.familyId = keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1");
        avm.mockCall(
            suite.owners[6],
            abi.encodeCall(IStreamArtistContentRecordsOwner.contentConsentRecord, (record)),
            abi.encode(r)
        );
        avm.expectRevert(T.UnsupportedProfile.selector);
        _call(n, p);
        _empty(n);
        avm.clearMockedCalls();
        _run(n, p);
    }

    function testForeignOriginalRecordDomainCannotMatchTheAuthenticatedReceipt() external {
        _start(true);
        bytes32 record = _personhood(2);
        Next memory n = _cutover(true);
        MR.Request memory p = _mr();
        T.AttestationRecord memory wrong =
            IStreamArtistAttributionOwner(suite.owners[4]).attestationRecord(record);
        RH.AttestationInput memory input = p.witnesses[1].attestations[0];
        wrong.recordHash = StreamArtistHashes.attestationRecordForAuthority(
            StreamArtistHashes.Environment(
                block.chainid, address(n.registry), address(core), address(manager)
            ),
            input.terms,
            artistId,
            wrong.signer,
            1,
            input.nonce,
            wrong.signedAt
        );
        require(wrong.recordHash != record, "different predecessor signing domain");
        avm.mockCall(
            suite.owners[4],
            abi.encodeCall(IStreamArtistAttributionOwner.attestationRecord, (record)),
            abi.encode(wrong)
        );
        avm.expectRevert(T.InvalidRecord.selector);
        _call(n, p);
        _empty(n);
        avm.clearMockedCalls();
        _run(n, p);
    }

    function testCompleteOversizedHistoryKeepsOriginalCarrierAndWholeStateRefusal() external {
        _start(true);
        for (uint256 j; j < 10; ++j) {
            _personhood(2);
        }
        Next memory n = _cutover(true);
        MR.Request memory p = _mr();
        bytes32 roots = _allRoots(n.coordinator);
        avm.expectRevert(T.BoundExceeded.selector);
        _call(n, p);
        _empty(n);
        require(
            _allRoots(n.coordinator) == roots
                && n.archive.artistArchiveMaxEvidenceBytesV2() == 24575,
            "no raised carrier or partial imports"
        );
    }

    function testFreshSuccessorPayoutUsesCarriedHeadAndNewSignatureDomain() external {
        _start(true);
        bytes32 old = _payoutRecord(artistId, artist, keys, address(artist));
        _personhood(2);
        Next memory n = _cutover(true);
        _run(n, _mr());
        T.PayoutDesignation memory p = T.PayoutDesignation(artistId, address(0xbeef), old);
        T.Authorization memory a = T.Authorization(
            IStreamArtistIdentityOwner(n.identity).identity(artistId).nonceHint,
            uint64(block.timestamp),
            ""
        );
        bytes32 oldDigest = ingress.payoutDesignationDigest(p, a);
        bytes32 nextDigest = n.registry.payoutDesignationDigest(p, a);
        require(oldDigest != nextDigest);
        a.signature = _signature(oldDigest);
        bytes32 roots = _allRoots(n.coordinator);
        uint256 nonce = artist.nonce();
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(
            address(n.registry),
            abi.encodeCall(IStreamArtistOnboarding.recordPayoutDesignation, (p, a))
        );
        require(
            _allRoots(n.coordinator) == roots && artist.nonce() == nonce,
            "foreign domain cannot consume next nonce"
        );
        a.signature = _signature(nextDigest);
        require(
            this.executeTargetSafe(
                address(n.registry),
                abi.encodeCall(IStreamArtistOnboarding.recordPayoutDesignation, (p, a))
            )
        );
        (address account, bytes32 next) = n.registry.artistPayoutAccount(artistId);
        require(account == address(0xbeef) && next != old);
        require(
            IStreamArtistPayoutOwner(n.coordinator.suiteConfiguration().owners[5])
            .designationRecord(next)
            .previousDesignationRecordHash == old
        );
        require(
            IStreamArtistPayoutOwner(n.coordinator.suiteConfiguration().owners[5])
            .designationRecord(old)
            .artistId == artistId,
            "original history stays present"
        );
    }

    function testActualMetadataConsumptionAndReceiptRemainInOriginalHost() external {
        actualSaleRegistryFixture = true;
        setUp();
        _start(true);
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
        bytes memory payload = bytes('{"intent":"original consumed publication"}');
        (IStreamPreservationRecords.CollectionRecord memory record, P.Publication memory pub) = f.prepare(
            address(artist),
            keccak256("ARTIST_INTENT"),
            keccak256("STREAM_ARTIST_INTENT_V1"),
            payload,
            "urn:records:intent"
        );
        (T.Attestation memory terms, bytes memory statement) =
            _canonicalAttestation(pub, record.uri);
        bytes32 authorization = _attest(terms, statement);
        require(
            host.recordArtistCollectionRecordWithPayload(
                address(artist), 1, record, payload, authorization
            ) == pub.candidateRecordHash
        );
        (, IStreamCollectionMetadataV1.RecordReceipt memory beforeReceipt) =
            host.collectionRecord(pub.candidateRecordHash);
        Next memory n = _cutover(true);
        _run(n, _mr());
        _attestationParity(n);
        (
            IStreamPreservationRecords.CollectionRecord memory afterRecord,
            IStreamCollectionMetadataV1.RecordReceipt memory afterReceipt
        ) = host.collectionRecord(pub.candidateRecordHash);
        (, bytes memory afterPayload) = host.recordPayload(pub.candidateRecordHash);
        require(
            keccak256(abi.encode(record)) == keccak256(abi.encode(afterRecord))
                && keccak256(abi.encode(beforeReceipt)) == keccak256(abi.encode(afterReceipt))
                && keccak256(payload) == keccak256(afterPayload)
                && host.consumedArtistAuthorization(authorization)
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
}
