// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistPublicationHydrationFixture.sol";
import {
    StreamArtistRecordPublicationReads
} from "../../../smart-contracts/domains/artist/StreamArtistRecordPublicationReads.sol";
import {
    StreamMetadataArtistSelection
} from "../../../smart-contracts/domains/metadata/StreamMetadataArtistSelection.sol";
import {
    StreamMetadataArtistConfiguration
} from "../../../smart-contracts/domains/metadata/StreamMetadataArtistConfiguration.sol";

interface PublicationJoinVm {
    function cool(address target) external;
}

/// @dev This probe invokes the actual fixed Artist reader, including its original governed cap.
contract ActualPublicationJoinCandidate {
    function read(T.SuiteConfiguration memory s, P.Publication memory p)
        external
        view
        returns (bytes32)
    {
        return StreamArtistRecordPublicationReads.candidate(s, p);
    }
}

/// @notice Actual Artist facade/Coordinator/seven owners/Archive, Metadata/schema/bytes and Safe join.
/// @dev Core pointer administration, governance execution and the distinct Metadata router remain
/// typed fixture boundaries. No Artist permit, checkpoint, hydration marker or candidate is mocked
/// on a positive path. These authored cases require native execution before acceptance is claimed.
contract StreamArtistMetadataPublicationJoinTest is ArtistPublicationHydrationFixture {
    struct Joined {
        ArtistCanonicalPublicationFixture factory_;
        StreamCollectionMetadataV1 host;
        IStreamPreservationRecords.CollectionRecord[2] original;
        P.Publication[2] publication;
        bytes[2] payload;
        bytes32[2] authorization;
        bytes32[2] receipt;
    }

    function _joinedSource() internal returns (Joined memory j) {
        actualSaleRegistryFixture = true;
        setUp();
        _compactSource();
        _economicHistory();
        _recordRatification();
        j.factory_ = new ArtistCanonicalPublicationFixture();
        j.factory_.deploy(address(core), address(ingress));
        j.host = j.factory_.metadata();
        _saleRegister(
            saleModules,
            factory.governanceAuthority(),
            address(j.host),
            keccak256("COLLECTION_METADATA"),
            type(IStreamCollectionMetadataV1).interfaceId
        );
        core.set(keccak256("COLLECTION_METADATA"), address(j.host), false);
        require(
            suite.metadata != address(j.host) && suite.metadata == address(metadata),
            "actual suite router remains distinct from collection records"
        );
        for (uint256 k; k < 2; ++k) {
            j.payload[k] = k == 0
                ? bytes("original actual intent bytes")
                : bytes("original actual statement bytes");
            (j.original[k], j.publication[k]) =
                _terms(j, k, j.payload[k], "https://example.test/join/original");
            (T.Attestation memory p, bytes memory statement) =
                _canonicalAttestation(j.publication[k], j.original[k].uri);
            j.authorization[k] = _recordPublication(j.publication[k], p, statement);
            require(
                j.publication[k].candidateRecordHash
                    == _canonicalRecordHash(j.original[k], j.publication[k]),
                "independent original Metadata domain preimage"
            );
            require(
                this.executeTargetSafe(
                    address(j.host),
                    abi.encodeCall(
                        j.host.recordArtistCollectionRecordWithPayload,
                        (address(artist), 1, j.original[k], j.payload[k], j.authorization[k])
                    )
                ),
                "actual original Safe publishes approved bytes"
            );
            (, IStreamCollectionMetadataV1.RecordReceipt memory receipt) =
                j.host.collectionRecord(j.publication[k].candidateRecordHash);
            j.receipt[k] = keccak256(abi.encode(receipt));
        }
    }

    function _terms(Joined memory j, uint256 kind, bytes memory payload, string memory uri)
        internal
        returns (IStreamPreservationRecords.CollectionRecord memory r, P.Publication memory p)
    {
        return j.factory_
            .prepare(
                address(artist),
                kind == 0 ? keccak256("ARTIST_INTENT") : keccak256("ARTIST_STATEMENT"),
                kind == 0
                    ? keccak256("STREAM_ARTIST_INTENT_V1")
                    : keccak256("STREAM_ARTIST_INTERVIEW_V1"),
                payload,
                uri
            );
    }

    function _hydrateJoin(Next memory n) internal {
        bytes32 completed = PublicationHydrate(address(n.registry))
            .hydrateArtistAuthorityWithPublications(_readyRequest());
        require(completed != 0, "original op60 profile executes");
        T.SuiteConfiguration memory nextSuite = n.coordinator.suiteConfiguration();
        bytes32 ownerCommitment = HydrationOwner(nextSuite.owners[0]).authorityHydrationCommitment();
        require(ownerCommitment != 0, "actual nonzero owner completion");
        for (uint256 k; k < 7; ++k) {
            require(
                HydrationOwner(nextSuite.owners[k]).authorityHydrationCommitment()
                    == ownerCommitment,
                "all seven actual owner commitments match"
            );
        }
        (bool cutover, address target, uint64 observedAt) =
            History(address(ingress)).artistRegistryCutover();
        require(
            cutover && target == address(n.registry) && observedAt != 0, "actual original op57 seal"
        );
        _assertPublications(n);
    }

    function _assertOriginal(Joined memory j) internal view {
        require(
            j.host.artistRegistry() == address(ingress), "original immutable Artist anchor retained"
        );
        for (uint256 k; k < 2; ++k) {
            (
                IStreamPreservationRecords.CollectionRecord memory r,
                IStreamCollectionMetadataV1.RecordReceipt memory receipt
            ) = j.host.collectionRecord(j.publication[k].candidateRecordHash);
            (, bytes memory payload) = j.host.recordPayload(j.publication[k].candidateRecordHash);
            require(
                keccak256(abi.encode(r)) == keccak256(abi.encode(j.original[k]))
                    && keccak256(abi.encode(receipt)) == j.receipt[k]
                    && keccak256(payload) == keccak256(j.payload[k])
                    && j.host.consumedArtistAuthorization(j.authorization[k]),
                "original bytes, receipt and spent authorization survive"
            );
        }
    }

    function _fresh(Next memory n, P.Publication memory pub, string memory uri)
        internal
        view
        returns (
            T.Attestation memory p,
            T.Authorization memory a,
            bytes memory statement,
            bytes32 expected
        )
    {
        (p, statement) = _canonicalAttestation(pub, uri);
        a = T.Authorization(
            IStreamArtistIdentityOwner(n.identity).identity(artistId).nonceHint,
            uint64(block.timestamp),
            ""
        );
        // Independent original op24 preimage, with only the actual active Registry domain changed.
        bytes32[16] memory words;
        words[0] = keccak256("6529STREAM_ARTIST_ATTESTATION_RECORD_V1");
        words[1] = bytes32(block.chainid);
        words[2] = bytes32(uint256(uint160(address(n.registry))));
        words[3] = bytes32(uint256(uint160(address(core))));
        words[4] = bytes32(uint256(1));
        words[5] = bytes32(uint256(p.subjectKind));
        words[6] = p.subjectId;
        words[7] = p.subjectStateHash;
        words[8] = p.schemaId;
        words[9] = p.statementHash;
        words[10] = keccak256(bytes(p.statementURI));
        words[11] = artistId;
        words[12] = bytes32(uint256(uint160(address(artist))));
        words[13] = bytes32(uint256(1));
        words[14] = bytes32(a.nonce);
        words[15] = bytes32(uint256(a.time));
        expected = keccak256(abi.encode(words));
    }

    function _approveFresh(Next memory n, P.Publication memory pub, string memory uri)
        internal
        returns (bytes32 expected)
    {
        (T.Attestation memory p, T.Authorization memory a, bytes memory statement, bytes32 record) =
            _fresh(n, pub, uri);
        a.signature = _signature(n.registry.attestationDigest(p, a));
        require(
            this.executeTargetSafe(
                address(n.registry),
                abi.encodeCall(IStreamArtistOnboarding.recordArtistAttestation, (p, a, statement))
            ),
            "actual Safe signs fresh successor op24"
        );
        expected = record;
        _assertApproval(n, pub, p, expected);
    }

    function _assertApproval(
        Next memory n,
        P.Publication memory pub,
        T.Attestation memory p,
        bytes32 expected
    ) internal view {
        T.SuiteConfiguration memory s = n.coordinator.suiteConfiguration();
        require(
            IStreamArtistAttributionOwner(s.owners[4])
            .attestation(1, p.subjectKind, p.subjectId)
            .recordHash == expected,
            "exact new domain op24 record"
        );
        P.Evidence memory e = n.registry.requireRecordPublication(expected, pub);
        require(
            e.attestationRecordHash == expected && e.signer == address(artist)
                && e.publicationHash == keccak256(abi.encode(pub)) && e.authorityClass == 1,
            "actual current successor validates full fresh evidence"
        );
    }

    function testActualSuccessorPublishesBothFamiliesThroughSameMetadataAndColdCandidate()
        external
    {
        Joined memory j = _joinedSource();
        Next memory n = _cutover(true, true);
        _hydrateJoin(n);
        ActualPublicationJoinCandidate probe = new ActualPublicationJoinCandidate();
        T.SuiteConfiguration memory s = n.coordinator.suiteConfiguration();
        (uint256 cap,,, uint64 revision) = IStreamGasParameterHost(address(n.registry))
            .gasParameterInfo(keccak256("6529STREAM_GGP_ARTIST_RECORD_PUBLICATION_READ_GAS"));
        require(cap == 400000 && revision != 0, "unchanged original Artist candidate budget");
        for (uint256 k; k < 2; ++k) {
            bytes memory payload = k == 0
                ? bytes("fresh successor intent bytes")
                : bytes("fresh successor statement bytes");
            (IStreamPreservationRecords.CollectionRecord memory r, P.Publication memory pub) =
                _terms(j, k, payload, "https://example.test/join/successor");
            _coolJoin(j, n, payload);
            require(
                probe.read(s, pub) == address(j.host).codehash,
                "actual cold Artist candidate callback at original cap"
            );
            bytes32 approval = _approveFresh(n, pub, r.uri);
            vm.recordLogs();
            require(
                this.executeTargetSafe(
                    address(j.host),
                    abi.encodeCall(
                        j.host.recordArtistCollectionRecordWithPayload,
                        (address(artist), 1, r, payload, approval)
                    )
                ),
                "fresh actual same-host publication"
            );
            _assertConsumedEvent(
                vm.getRecordedLogs(), address(j.host), approval, pub.candidateRecordHash
            );
            (
                IStreamPreservationRecords.CollectionRecord memory saved,
                IStreamCollectionMetadataV1.RecordReceipt memory receipt
            ) = j.host.collectionRecord(pub.candidateRecordHash);
            (, bytes memory savedPayload) = j.host.recordPayload(pub.candidateRecordHash);
            require(
                pub.candidateRecordHash == _canonicalRecordHash(r, pub)
                    && keccak256(abi.encode(saved)) == keccak256(abi.encode(r))
                    && keccak256(savedPayload) == keccak256(payload)
                    && receipt.artistAuthorization == approval && receipt.authorizationClass == 1
                    && receipt.recorder == address(artist)
                    && j.host.consumedArtistAuthorization(approval),
                "exact canonical new payload, receipt and consumption"
            );
            _assertOriginal(j);
        }
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionMetadataV1.MetadataAuthorizationConsumed.selector,
                j.authorization[0]
            )
        );
        j.host
            .recordArtistCollectionRecordWithPayload(
                address(artist), 1, j.original[0], j.payload[0], j.authorization[0]
            );
    }

    function testActualSealedHistoryNeedsHydrationAndFreshSuccessorSigningDomain() external {
        Joined memory j = _joinedSource();
        Next memory n = _cutover(true, true);
        (IStreamPreservationRecords.CollectionRecord memory r, P.Publication memory pub) =
            _terms(j, 0, bytes("new domain candidate"), "https://example.test/join/domain");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.MetadataHostNotSelected.selector)
        );
        j.host.requireArtistRecordCandidate(pub);
        _notHydrated(n);
        _hydrateJoin(n);
        (
            T.Attestation memory p,
            T.Authorization memory a,
            bytes memory statement,
            bytes32 expected
        ) = _fresh(n, pub, r.uri);
        bytes32 oldDigest = ingress.attestationDigest(p, a);
        bytes32 freshDigest = n.registry.attestationDigest(p, a);
        require(oldDigest != freshDigest, "Registry domain remains distinct");
        a.signature = _signature(oldDigest);
        uint256 nonce = artist.nonce();
        bytes32 roots = _allRoots(n.coordinator);
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(
            address(n.registry),
            abi.encodeCall(IStreamArtistOnboarding.recordArtistAttestation, (p, a, statement))
        );
        require(
            artist.nonce() == nonce && _allRoots(n.coordinator) == roots,
            "old signature leaves all authority state unchanged"
        );
        a.signature = _signature(freshDigest);
        require(
            this.executeTargetSafe(
                address(n.registry),
                abi.encodeCall(IStreamArtistOnboarding.recordArtistAttestation, (p, a, statement))
            ),
            "same terms with actual successor signature"
        );
        _assertApproval(n, pub, p, expected);
        _assertOriginal(j);
    }

    function testActualSuccessorArchiveFailureAndMetadataSelectionRestorePermitIdenticalSafeRetry()
        external
    {
        Joined memory j = _joinedSource();
        Next memory n = _cutover(true, true);
        _hydrateJoin(n);
        bytes memory payload = bytes("full exact Safe retry payload");
        (IStreamPreservationRecords.CollectionRecord memory r, P.Publication memory pub) =
            _terms(j, 1, payload, "https://example.test/join/retry");
        (
            T.Attestation memory p,
            T.Authorization memory a,
            bytes memory statement,
            bytes32 expected
        ) = _fresh(n, pub, r.uri);
        a.signature = _signature(n.registry.attestationDigest(p, a));
        bytes memory approvalCall =
            abi.encodeCall(IStreamArtistOnboarding.recordArtistAttestation, (p, a, statement));
        uint256 nonce = artist.nonce();
        uint256 carriers = n.archive.storedPayloadCount();
        bytes32 roots = _allRoots(n.coordinator);
        avm.mockCallRevert(
            address(n.archive),
            abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSignature("Error(string)", "injected late Archive failure")
        );
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(n.registry), approvalCall);
        require(
            artist.nonce() == nonce && _allRoots(n.coordinator) == roots
                && n.archive.storedPayloadCount() == carriers,
            "late Archive failure rolls back actual nonce, owner roots and carriers"
        );
        avm.clearMockedCalls();
        require(
            this.executeTargetSafe(address(n.registry), approvalCall),
            "identical signed op24 retries after Archive restoration"
        );
        _assertApproval(n, pub, p, expected);
        bytes memory publicationCall = abi.encodeCall(
            j.host.recordArtistCollectionRecordWithPayload,
            (address(artist), 1, r, payload, expected)
        );
        nonce = artist.nonce();
        core.set(keccak256("COLLECTION_METADATA"), address(metadata), false);
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(j.host), publicationCall);
        require(
            artist.nonce() == nonce && !j.host.consumedArtistAuthorization(expected),
            "failed current selection preserves Safe nonce and fresh permit"
        );
        core.set(keccak256("COLLECTION_METADATA"), address(j.host), false);
        require(
            this.executeTargetSafe(address(j.host), publicationCall),
            "identical Metadata Safe transaction retries after original pointer restoration"
        );
        require(j.host.consumedArtistAuthorization(expected), "fresh permit is spent once");
        _assertOriginal(j);
    }

    function _assertConsumedEvent(
        Vm.Log[] memory logs,
        address host,
        bytes32 approval,
        bytes32 record
    ) internal view {
        uint256 found;
        for (uint256 k; k < logs.length; ++k) {
            Vm.Log memory row = logs[k];
            if (
                row.emitter != host || row.topics.length == 0
                    || row.topics[0]
                        != keccak256(
                            "ArtistRecordAuthorizationConsumed(bytes32,bytes32,address,address)"
                        )
            ) continue;
            ++found;
            require(
                row.topics.length == 4 && row.topics[1] == approval && row.topics[2] == record
                    && row.topics[3] == bytes32(uint256(uint160(address(artist))))
                    && keccak256(row.data) == keccak256(abi.encode(address(artist))),
                "original event identifies exact permit, record, recorder and actual Safe caller"
            );
        }
        require(found == 1, "one actual successful consumption event");
    }

    function _coolJoin(Joined memory j, Next memory n, bytes memory payload) internal {
        PublicationJoinVm cvm = PublicationJoinVm(address(vm));
        T.SuiteConfiguration memory s = n.coordinator.suiteConfiguration();
        (address pointer,) = j.factory_.store().chunk(keccak256(payload));
        address[8] memory readers = [
            address(coordinator),
            address(n.coordinator),
            ingress.registryReadExtension(),
            n.registry.registryReadExtension(),
            coordinator.finalityRegistry(),
            n.coordinator.finalityRegistry(),
            coordinator.finalityEvidenceProvider(),
            n.coordinator.finalityEvidenceProvider()
        ];
        for (uint256 k; k < readers.length; ++k) {
            cvm.cool(readers[k]);
        }
        for (uint256 k; k < 7; ++k) {
            cvm.cool(suite.owners[k]);
            cvm.cool(s.owners[k]);
        }
        cvm.cool(address(ingress));
        cvm.cool(address(n.registry));
        cvm.cool(address(archive));
        cvm.cool(address(n.archive));
        cvm.cool(s.core);
        cvm.cool(s.mintManager);
        cvm.cool(s.roleRegistry);
        cvm.cool(s.metadata);
        cvm.cool(s.primaryResolver);
        cvm.cool(s.royaltyResolver);
        cvm.cool(s.validator);
        cvm.cool(address(saleModules));
        cvm.cool(address(j.host));
        cvm.cool(address(j.factory_.schemas()));
        cvm.cool(address(j.factory_.store()));
        cvm.cool(pointer);
        cvm.cool(address(StreamMetadataArtistSelection));
        cvm.cool(address(StreamMetadataArtistConfiguration));
        cvm.cool(address(StreamRecordDocumentReads));
        cvm.cool(address(StreamMetadataPublicationEncoding));
        cvm.cool(address(StreamCollectionRecordHashes));
        cvm.cool(address(StreamArtistRecordPublicationReads));
    }
}
