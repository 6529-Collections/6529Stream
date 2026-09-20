// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistOnboardingFixture.sol";

/// @notice Focused exact original Artist/Safe oracles for the held admission/codec proposal.
/// @dev Actual Artist, Safe, Archive, Manager/Resolver and selected Metadata producers;
/// original fixture Core/governance/finality/subject host boundaries remain explicit.
/// This source has not been compiled or executed. It does not bypass deployment limits.
contract StreamArtistAdmissionCodecSafeTest is ArtistOnboardingFixture {
    function testActualPublicationSafeSignerRelayerExactBytesRecordAndEvents() public {
        ArtistCanonicalPublicationFixture f = _canonicalPublicationHost();
        StreamCollectionMetadataV1 host = f.metadata();
        bytes memory payload = bytes('{"statement":"The artist reviewed these exact bytes."}');
        (IStreamPreservationRecords.CollectionRecord memory r, P.Publication memory pub) = f.prepare(
            address(artist),
            keccak256("ARTIST_INTENT"),
            keccak256("STREAM_ARTIST_INTENT_V1"),
            payload,
            "ipfs://actual-intent"
        );
        require(
            pub.candidateRecordHash == _canonicalRecordHash(r, pub),
            "independent generic14 preimage"
        );
        (T.Attestation memory p, bytes memory statement) = _canonicalAttestation(pub, r.uri);
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.attestationDigest(p, a));
        bytes32 authorization = ingress.recordArtistAttestation(p, a, statement);
        require(authorization == _publicationExpected(p, a, 1), "independent artist16 preimage");
        vm.recordLogs();
        require(
            host.recordArtistCollectionRecordWithPayload(
                address(artist), 1, r, payload, authorization
            ) == pub.candidateRecordHash,
            "actual two-sided publication"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 recordEvents;
        uint256 authorizationEvents;
        (bytes32 chain, uint64 count) = host.recordChainHash(1, r.recordType);
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(host) || logs[i].topics.length == 0) continue;
            if (
                logs[i].topics[0]
                    == keccak256(
                        "ArtistRecordAuthorizationConsumed(bytes32,bytes32,address,address)"
                    )
            ) {
                ++authorizationEvents;
                require(
                    logs[i].topics.length == 4 && logs[i].topics[1] == authorization
                        && logs[i].topics[2] == pub.candidateRecordHash
                        && logs[i].topics[3] == bytes32(uint256(uint160(address(artist))))
                        && keccak256(logs[i].data) == keccak256(abi.encode(address(this))),
                    "exact signer and separate relayer event"
                );
            }
            if (
                logs[i].topics[0]
                    == keccak256(
                        "CollectionRecordRecorded(uint256,bytes32,bytes32,(bytes32,bytes32,(uint16,bytes,bytes32),string,bytes32,bytes32,(uint16,bytes,bytes32),uint64),bytes32,bytes32,address,bytes32,uint16)"
                    )
            ) {
                ++recordEvents;
                require(
                    logs[i].topics.length == 4 && logs[i].topics[1] == bytes32(uint256(1))
                        && logs[i].topics[2] == r.recordType && logs[i].topics[3] == r.subjectId
                        && keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(
                                    r,
                                    pub.candidateRecordHash,
                                    chain,
                                    address(artist),
                                    bytes32(uint256(1)),
                                    uint16(1)
                                )
                            ),
                    "exact generic record event"
                );
            }
        }
        require(
            recordEvents == 1 && authorizationEvents == 1 && count == 1,
            "one accepted record and consumed proof"
        );
        (
            IStreamPreservationRecords.CollectionRecord memory saved,
            IStreamCollectionMetadataV1.RecordReceipt memory receipt
        ) = host.collectionRecord(pub.candidateRecordHash);
        require(
            keccak256(abi.encode(saved)) == keccak256(abi.encode(r))
                && receipt.recorder == address(artist)
                && receipt.artistAuthorization == authorization && receipt.authorizationClass == 1,
            "exact tuple and ARTIST family provenance"
        );
        (address pointer, bytes memory body) = host.recordPayload(pub.candidateRecordHash);
        require(
            keccak256(body) == keccak256(payload) && pointer.code.length == payload.length + 1
                && host.consumedArtistAuthorization(authorization),
            "actual indexed byte coverage"
        );
        this.executePublicationSafe(
            address(host),
            abi.encodeCall(IStreamCollectionMetadataV1.collectionRecord, (pub.candidateRecordHash))
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionMetadataV1.MetadataAuthorizationConsumed.selector, authorization
            )
        );
        host.recordArtistCollectionRecordWithPayload(address(artist), 1, r, payload, authorization);
    }

    function testPublicationActualSafeExactRecordEventArchiveAndCurrentRead() public {
        ArtistPublicationHostFixture host = _publicationHost();
        (P.Publication memory pub, T.Attestation memory p, bytes memory statement) =
            _publicationTerms(host, true);
        T.Authorization memory a = _authorization(true);
        bytes32 expected = _publicationExpected(p, a, 1);
        vm.recordLogs();
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistOnboarding.recordArtistAttestation, (p, a, statement)),
                0
            ),
            "actual op24 Safe CALL"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != suite.owners[4] || logs[i].topics.length == 0
                    || logs[i].topics[0]
                        != keccak256(
                            "ArtistAttestationRecorded(uint16,uint256,uint8,address,bytes32,bytes32,bytes32,bytes32,bytes32,uint8,uint256,uint64,bytes32)"
                        )
            ) continue;
            ++count;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == bytes32(uint256(1))
                    && logs[i].topics[2] == bytes32(uint256(7))
                    && logs[i].topics[3] == bytes32(uint256(uint160(address(artist))))
                    && keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                p.subjectId,
                                p.subjectStateHash,
                                p.schemaId,
                                p.statementHash,
                                pub.uriHash,
                                uint8(1),
                                a.nonce,
                                a.time,
                                expected
                            )
                        ),
                "exact op24 event"
            );
        }
        require(count == 1, "one original normative event");
        P.Evidence memory evidence = ingress.requireRecordPublication(expected, pub);
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        require(
            evidence.attestationRecordHash == expected && evidence.artistId == artistId
                && evidence.bindingHash == b.bindingHash
                && evidence.bindingGeneration == b.generation && evidence.signer == address(artist)
                && evidence.authorityClass == 1 && evidence.requiredCapability == 64
                && evidence.signedAt == a.time
                && evidence.publicationHash == keccak256(abi.encode(pub)),
            "all nine exact current evidence fields"
        );
        IStreamArtistRecordPublicationOwner.Record memory saved =
            IStreamArtistRecordPublicationOwner(suite.owners[4]).publicationAttestation(expected);
        require(
            saved.metadataHostCodeHash == address(host).codehash
                && keccak256(abi.encode(saved.publication)) == evidence.publicationHash,
            "immutable owner evidence"
        );
        (
            T.Binding memory archived,
            T.Attestation memory ap,
            T.Authorization memory submitted,
            bytes memory actualStatement,
            T.SignerApproval memory proof,
            T.Authorization memory effective,
            R.AuthorityFact memory authority,
            P.Publication memory captured,
            bytes32 codeHash
        ) = abi.decode(
            _operationPayload(24, address(artist), expected),
            (
                T.Binding,
                T.Attestation,
                T.Authorization,
                bytes,
                T.SignerApproval,
                T.Authorization,
                R.AuthorityFact,
                P.Publication,
                bytes32
            )
        );
        require(
            archived.bindingHash == b.bindingHash && ap.statementHash == p.statementHash
                && submitted.nonce == a.nonce && effective.time == a.time && proof.direct
                && authority.authorityAddress == address(artist)
                && keccak256(actualStatement) == p.statementHash
                && keccak256(abi.encode(captured)) == evidence.publicationHash
                && codeHash == saved.metadataHostCodeHash,
            "archive binds exact original and current owner facts"
        );
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistRecordPublication.requireRecordPublication, (expected, pub)
                ),
                0
            ),
            "Safe validating read CALL"
        );
        require(
            ingress.supportsInterface(type(IStreamArtistRecordPublication).interfaceId),
            "typed interface advertised"
        );

        bytes memory readData = abi.encodeCall(
            IStreamArtistRecordPublication.requireRecordPublication, (expected, pub)
        );
        (bool readOk, bytes memory returned) = address(ingress).staticcall(readData);
        require(
            readOk && returned.length == 288
                && keccak256(returned) == keccak256(abi.encode(evidence)),
            "all nine static return words preserved through fixed reader"
        );
        require(
            executeSafe(
                artist,
                keys,
                suite.owners[4],
                0,
                abi.encodeCall(
                    IStreamArtistRecordPublicationOwner.publicationAttestation, (expected)
                ),
                0
            ),
            "actual Safe historical owner read"
        );
        address reader = ingress.registryReadExtension();
        uint256 safeNonce = artist.nonce();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executePublicationSafe(reader, readData);
        require(artist.nonce() == safeNonce, "fixed child onlyHost rejects direct Safe");
        T.ActionContext memory context = T.ActionContext(
            24, address(artist), IStreamArtistOwner(suite.owners[4]).ownerStateSnapshotV2()
        );
        bytes memory callback = abi.encodeCall(
            IStreamArtistRecordPublicationOwner.recordPublicationAttestation,
            (context, b, p, authority, a.nonce, a.time, statement, codeHash)
        );
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executePublicationSafe(suite.owners[4], callback);
        require(
            _roots() == roots && artist.nonce() == safeNonce,
            "protocol callback rejects actual Safe atomically"
        );
    }

    function testPublicationMalformedHostAndLateArchiveRollbackSameProofRetry() public {
        ArtistPublicationHostFixture host = _publicationHost();
        (P.Publication memory pub, T.Attestation memory p, bytes memory statement) =
            _publicationTerms(host, false);
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.attestationDigest(p, a));
        bytes32 expected = _publicationExpected(p, a, 1);
        bytes32 roots = _roots();
        uint256 hint = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        for (uint256 mode = 1; mode <= 4; ++mode) {
            host.setMode(mode);
            vm.expectRevert(
                abi.encodeWithSelector(
                    StreamArtistRecordPublicationReads.PublicationReadFailed.selector,
                    address(host),
                    IStreamArtistRecordPublicationHost.requireArtistRecordCandidate.selector
                )
            );
            ingress.recordArtistAttestation(p, a, statement);
            require(_roots() == roots, "malformed/OOG provider no writes");
        }
        host.setMode(0);
        avm.mockCallRevert(
            address(archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(T.InvalidRecord.selector)
        );
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        ingress.recordArtistAttestation(p, a, statement);
        require(
            _roots() == roots
                && IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint == hint
                && IStreamArtistRecordPublicationOwner(suite.owners[4])
                    .publicationAttestation(expected).evidence.attestationRecordHash == 0,
            "late Archive rolls nonce and appended publication evidence back"
        );
        avm.clearMockedCalls();
        require(
            ingress.recordArtistAttestation(p, a, statement) == expected,
            "same signed authorization healthy retry"
        );
        require(
            ingress.requireRecordPublication(expected, pub).requiredCapability == 1,
            "current interview evidence"
        );
        roots = _roots();
        avm.expectPartialRevert(T.Replay.selector);
        ingress.recordArtistAttestation(p, a, statement);
        require(_roots() == roots, "exact original authorization replay rejected");
    }

    function testIdentityAttestationLegacyCallbackRejectsPersonhoodAndNewCallbackRejectsSafe()
        public
    {
        _accept();
        T.Binding memory b = coordinator.reads().acceptedBinding(1);
        bytes memory statement = bytes("old callback cannot reintroduce stale facts");
        T.Attestation memory p = T.Attestation(
            1,
            10,
            artistId,
            b.identityRecordHash,
            keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1"),
            keccak256(statement),
            "urn:waiver"
        );
        T.ActionContext memory c = T.ActionContext(
            24, address(artist), IStreamArtistOwner(suite.owners[4]).ownerStateSnapshotV2()
        );
        vm.prank(address(coordinator));
        avm.expectRevert(T.UnsupportedProfile.selector);
        IStreamArtistAttributionOwner(suite.owners[4])
            .recordAttestation(c, b, p, address(artist), 1, 1000, statement);
        bytes memory callback = abi.encodeCall(
            IStreamArtistIdentityAttestationOwner.recordIdentityAttestation,
            (c, b, p, b.identityRecordHash, address(artist), uint256(1), uint64(1000), statement)
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(suite.owners[4], callback);
    }

    function testSafeDirectAcceptanceAndOwnerEoaDoesNotInheritAuthority() public {
        T.Authorization memory a = _authorization(false);
        vm.prank(safeVm.addr(keys[0]));
        vm.expectRevert();
        ingress.acceptArtistBinding(1, a);
        executeSafe(
            artist,
            keys,
            address(ingress),
            0,
            abi.encodeCall(IStreamArtistOnboarding.acceptArtistBinding, (1, a)),
            0
        );
        require(ingress.acceptedArtist(1) == address(artist), "direct Safe accepted");
    }

    function testBindingRefusalSafeSignatureCanonicalRecordAndEvents() public {
        L.Termination memory p = _termination(1);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.bindingRefusalDigest(p, a));
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_BINDING_REFUSAL_RECORD_V1"),
                block.chainid,
                address(ingress),
                suite.core,
                uint256(1),
                p.generation,
                p.bindingHash,
                artistId,
                address(artist),
                uint8(1),
                p.reasonHash,
                a.nonce,
                uint64(1000)
            )
        );
        vm.recordLogs();
        require(ingress.refuseArtistBinding(p, a) == expected, "canonical refusal record");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool contextFound;
        bool stateFound;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != suite.owners[4]) continue;
            if (
                logs[i].topics[0]
                    == keccak256(
                        "ArtistBindingTerminationContext(uint16,uint256,uint64,bytes32,bytes32,bytes32,address,uint256,uint64)"
                    )
            ) {
                require(
                    logs[i].topics[1] == bytes32(uint256(1))
                        && logs[i].topics[2] == bytes32(uint256(1))
                        && logs[i].topics[3] == expected,
                    "refusal context topics"
                );
                (
                    uint16 schema,
                    bytes32 bh,
                    bytes32 id,
                    address signer,
                    uint256 nonce,
                    uint64 observed
                ) = abi.decode(logs[i].data, (uint16, bytes32, bytes32, address, uint256, uint64));
                require(
                    schema == 1 && bh == p.bindingHash && id == artistId
                        && signer == address(artist) && nonce == a.nonce && observed == 1000
                        && observed != a.time,
                    "exact refusal context"
                );
                contextFound = true;
            }
            if (
                logs[i].topics[0]
                    == keccak256(
                        "ArtistAttributionStateChanged(uint16,uint256,uint8,uint64,uint8,address,uint8,bytes32,bytes32,string)"
                    )
            ) {
                (
                    uint16 schema,
                    uint64 generation,
                    uint8 old,
                    address actor,
                    uint8 auth,
                    bytes32 record,
                    bytes32 reason,
                    string memory uri
                ) = abi.decode(
                    logs[i].data, (uint16, uint64, uint8, address, uint8, bytes32, bytes32, string)
                );
                require(
                    schema == 1 && generation == 1 && old == 1 && actor == address(this)
                        && auth == 1 && record == expected && reason == p.reasonHash
                        && keccak256(bytes(uri)) == keccak256(bytes(p.reasonURI)),
                    "state event record"
                );
                stateFound = true;
            }
        }
        require(contextFound && stateFound, "both events");
        require(ingress.bindingTermination(1, 1).recordHash == expected, "historical refusal");
        bytes32 before_ = _roots();
        vm.expectRevert(abi.encodeWithSelector(T.InvalidAttribution.selector, uint256(1)));
        ingress.refuseArtistBinding(p, a);
        require(before_ == _roots(), "refusal replay rollback");
        T.Snapshot memory identityBefore =
            IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2();
        _repropose(1);
        require(
            keccak256(abi.encode(identityBefore))
                == keccak256(
                    abi.encode(IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2())
                ),
            "reproposal reuses identity read-only"
        );
        require(
            IStreamArtistBindingOwner(suite.owners[0]).binding(1).generation == 2
                && ingress.bindingTermination(1, 1).recordHash == expected,
            "generation history"
        );
    }

    function testSaleConsentActualNativeSafeExactDigestRecordEventAndReplay() public {
        Sale.Consent memory p = _saleFixture(1);
        require(ingress.saleConsentScope(1) == 1, "immutable REQUIRED election");
        vm.expectRevert(
            abi.encodeWithSelector(
                Sale.SaleConsentUnavailable.selector, 1, p.saleId, p.saleConfigHash
            )
        );
        _requireSale(p);
        T.Authorization memory a = _saleAuthorization(p);
        bytes32 digest = StreamArtistHashes.typed(
            StreamArtistHashes.Environment(
                block.chainid, address(ingress), address(core), address(manager)
            ),
            keccak256(
                abi.encode(
                    bytes32(0x5a0d2fee9c2248ad2b0735d54beb28b1decdd1adeb65c63c4016da70ec399045),
                    address(core),
                    p.saleAdapter,
                    uint256(1),
                    p.saleId,
                    p.saleConfigHash,
                    a.nonce,
                    a.time
                )
            )
        );
        require(digest == ingress.saleConsentDigest(p, a), "exact permanent digest");
        vm.warp(1017);
        vm.recordLogs();
        bytes32 record = ingress.recordSaleConsent(p, a);
        bytes32 expected = keccak256(
            abi.encode(
                bytes32(0xf30702786801bdda286e4555272eb70024e76bd156af98fab2513886e5bdcfd1),
                block.chainid,
                address(ingress),
                p.saleAdapter,
                address(core),
                uint256(1),
                p.saleId,
                p.saleConfigHash,
                artistId,
                address(artist),
                uint8(1),
                a.nonce,
                uint64(1017)
            )
        );
        require(record == expected, "observed record time distinct from deadline");
        Sale.Record memory saved = ingress.saleConsentRecord(record);
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        require(
            saved.bindingGeneration == b.generation && saved.bindingHash == b.bindingHash
                && saved.artistId == artistId && saved.recordHash == expected,
            "canonical record plus actual applicability"
        );
        uint256 found;
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == suite.owners[6]
                    && logs[i].topics[0]
                        == keccak256(
                            "ArtistSaleConsentRecorded(uint16,uint256,bytes32,address,bytes32,uint8,uint256,uint64,bytes32)"
                        )
            ) {
                require(
                    logs[i].topics[1] == bytes32(uint256(1))
                        && logs[i].topics[2] == p.saleConfigHash
                        && logs[i].topics[3] == bytes32(uint256(uint160(address(artist))))
                        && keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(
                                    uint16(1), p.saleId, uint8(1), a.nonce, uint64(1017), record
                                )
                            ),
                    "exact owner event"
                );
                ++found;
            }
        }
        require(found == 1, "one canonical event");
        (bool exists, bytes32 observed) = ingress.isSaleConsented(1, p.saleId, p.saleConfigHash);
        require(exists && observed == record, "stored evidence");
        _requireSale(p);
        bytes32 roots = _roots();
        avm.expectPartialRevert(T.Replay.selector);
        ingress.recordSaleConsent(p, a);
        require(_roots() == roots, "principal replay atomic");
        T.Authorization memory fresh = _saleAuthorization(p);
        bytes32 replayKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                address(ingress),
                address(coordinator),
                address(archive),
                suite.owners[6],
                keccak256("domain:consent_finality"),
                keccak256("consent_finality.replay.sale_consent_key"),
                keccak256(abi.encode(p, b.generation, b.bindingHash))
            )
        );
        vm.expectRevert(abi.encodeWithSelector(T.Replay.selector, replayKey));
        ingress.recordSaleConsent(p, fresh);
        require(
            _roots() == roots,
            "same-generation consent key and new principal authorization rollback"
        );
    }

    function testPolicyReplayWrongDomainAndMissingSafeOwnerRollback() public {
        _accept();
        T.PolicyConsent memory p = T.PolicyConsent(1, PHASE, POLICY);
        T.Authorization memory a = _authorization(false);
        a.signature = safeThresholdSignature(keys, ingress.policyConsentDigest(p, a));
        bytes32 before_ = _roots();
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordPolicyConsent(p, a);
        require(before_ == _roots(), "wrong domain rollback");
        uint256[] memory one = new uint256[](1);
        one[0] = keys[0];
        a.signature = safeThresholdSignature(
            one, safeMessageDigest(artist, abi.encode(ingress.policyConsentDigest(p, a)))
        );
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordPolicyConsent(p, a);
        require(before_ == _roots(), "threshold rollback");
        a.signature = _signature(ingress.policyConsentDigest(p, a));
        ingress.recordPolicyConsent(p, a);
        before_ = _roots();
        avm.expectPartialRevert(T.Replay.selector);
        ingress.recordPolicyConsent(p, a);
        require(before_ == _roots(), "replay rollback");
    }

    function testSafeProspectiveEconomicsUsesActualCandidateAndSharedReplay() public {
        _accept();
        _payout();
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory installed =
            primary.resolvePrimaryAssignment(1, 0, PRIMARY);
        T.EconomicsConsent memory p =
            T.EconomicsConsent(1, address(primary), PRIMARY, 1, 1, installed.assignmentHash);
        T.FixedEconomicsCandidate memory candidate =
            T.FixedEconomicsCandidate(installed.profileId, bytes32(0), 0, false);
        _prospectiveConsent(p, candidate);
        bytes32 record = IStreamArtistConsentOwner(suite.owners[6]).economicsRecord(p);
        require(record != bytes32(0), "prospective owner record");
        // Both ingresses admit this exact active fixed candidate; they must consume
        // the same owner replay key, without any resolver mutation between calls.
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
        bytes32 before_ = _roots();
        avm.expectPartialRevert(T.Replay.selector);
        ingress.recordEconomicsConsent(p, a);
        require(
            _roots() == before_
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "shared consent key late rollback"
        );
        require(
            IStreamArtistConsentOwner(suite.owners[6]).economicsRecord(p) == record,
            "record unchanged"
        );
    }

    function testQueuedDirectSafePayoutAndAttestationObserveInclusionTime() public {
        _directTimeExercise(true);
    }

    function testSafeDefensiveFreezeHasExactRecordAndNoMintFloorDependency() public {
        _accept();
        // No payout, economics, policy, content or attestation records. An explicitly
        // failing primary read proves the defensive route never consults that provider.
        avm.mockCallRevert(
            address(primary),
            abi.encodePacked(IStreamRevenueResolver.resolvePrimaryAssignment.selector),
            abi.encodeWithSelector(T.InvalidRecord.selector)
        );
        T.RoyaltyFreeze memory p = _freezePayload();
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.royaltyFreezeDigest(p, a));
        vm.recordLogs();
        bytes32 record = ingress.authorizeArtistRoyaltyFreeze(p, a);
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ROYALTY_FREEZE_RECORD_V1"),
                block.chainid,
                address(ingress),
                p.resolver,
                p.collectionId,
                p.revenueClass,
                p.expectedAssignmentHash,
                artistId,
                address(artist),
                uint8(1),
                a.nonce,
                uint64(block.timestamp)
            )
        );
        require(
            record == expected && ingress.isRoyaltyFreezeAuthorized(1, p.expectedAssignmentHash),
            "exact freeze record and read"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool found;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != suite.owners[6]) continue;
            require(
                logs[i].topics[0]
                        == keccak256(
                            "ArtistRoyaltyFreezeAuthorized(uint16,uint256,bytes32,address,uint8,uint256,uint64,bytes32)"
                        ) && logs[i].topics[1] == bytes32(uint256(1))
                    && logs[i].topics[2] == p.expectedAssignmentHash
                    && logs[i].topics[3] == bytes32(uint256(uint160(address(artist)))),
                "exact freeze event"
            );
            (uint16 schema, uint8 authority, uint256 nonce, uint64 time, bytes32 emitted) =
                abi.decode(logs[i].data, (uint16, uint8, uint256, uint64, bytes32));
            require(
                schema == 1 && authority == 1 && nonce == a.nonce && time == block.timestamp
                    && emitted == record,
                "freeze event payload"
            );
            found = true;
        }
        require(found && _closed(_mintCall()), "freeze right independent of mint eligibility");
        IStreamRoyaltyResolver.RoyaltyConfig memory prior = royalty.collectionRoyalty(1);
        royalty.applyArtistRoyaltyFreeze(1, p.expectedAssignmentHash);
        IStreamRoyaltyResolver.RoyaltyConfig memory after_ = royalty.collectionRoyalty(1);
        require(
            after_.frozen && prior.wallet == after_.wallet && prior.profileId == after_.profileId
                && prior.royaltyBps == after_.royaltyBps,
            "only frozen bit changes"
        );
    }

    function testContentRecordCanonicalEventArchiveAndDirectSafeRead() public {
        _accept();
        Content.Consent memory p = _contentProposal(keccak256("new content"));
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.contentConsentDigest(p, a));
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_CONTENT_CONSENT_RECORD_V1"),
                block.chainid,
                address(ingress),
                address(metadata),
                address(core),
                uint256(1),
                p.familyId,
                p.newStateHash,
                artistId,
                address(artist),
                uint8(1),
                a.nonce,
                uint64(block.timestamp)
            )
        );
        vm.recordLogs();
        bytes32 record = ingress.recordContentConsent(p, a);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool eventSeen;
        bool contextSeen;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != suite.owners[6]) continue;
            if (
                logs[i].topics[0]
                    == keccak256(
                        "ArtistContentConsentRecorded(uint16,uint256,bytes32,address,bytes32,uint8,uint256,uint64,bytes32)"
                    )
            ) {
                require(
                    logs[i].topics[1] == bytes32(uint256(1)) && logs[i].topics[2] == p.familyId
                        && logs[i].topics[3] == bytes32(uint256(uint160(address(artist)))),
                    "exact event identity"
                );
                require(
                    keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                p.newStateHash,
                                uint8(1),
                                a.nonce,
                                uint64(block.timestamp),
                                expected
                            )
                        ),
                    "exact observed event preimage"
                );
                eventSeen = true;
            }
            if (
                logs[i].topics[0]
                    == keccak256("ArtistContentRecordContext(uint16,bytes32,address,bytes32)")
            ) {
                require(
                    logs[i].topics[1] == record
                        && keccak256(logs[i].data)
                            == keccak256(abi.encode(uint16(1), address(metadata), artistId)),
                    "reconstruction context"
                );
                contextSeen = true;
            }
        }
        require(
            record == expected && eventSeen && contextSeen, "canonical content record and events"
        );
        (
            ,
            Content.Consent memory archived,
            T.Authorization memory authorization,
            T.SignerApproval memory proof,
        ) = abi.decode(
            _operationPayload(17, address(this), record),
            (T.Binding, Content.Consent, T.Authorization, T.SignerApproval, bytes32)
        );
        require(
            archived.newStateHash == p.newStateHash && authorization.time == a.time
                && proof.signer == address(artist),
            "original signed proof archive"
        );
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistContentAuthority.contentConsentDigest, (p, a)),
                0
            ),
            "Safe digest read"
        );
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistContentAuthority.requireContentConsent,
                    (uint256(1), p.familyId, p.newStateHash)
                ),
                0
            ),
            "Safe canonical require read"
        );
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistContentAuthority.contentConsentEvidence,
                    (uint256(1), p.familyId, p.newStateHash)
                ),
                0
            ),
            "Safe validating evidence read"
        );
    }

    function testContentLateArchiveFailureRollsBackBothOwnersAndLookupPointers() public {
        _accept();
        Content.Consent memory p = _contentProposal(keccak256("late rollback"));
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.contentConsentDigest(p, a));
        bytes32 before_ = _roots();
        bytes memory failure = abi.encodeWithSignature("Error(string)", "content archive failed");
        avm.mockCallRevert(
            address(archive),
            abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            failure
        );
        vm.expectRevert(failure);
        ingress.recordContentConsent(p, a);
        require(
            _roots() == before_
                && !ingress.artistAuthorizationState(artistId, bytes32(0), a.nonce).nonceConsumed,
            "content nonce and both roots restored"
        );
        avm.clearMockedCalls();
        bytes32 record = ingress.recordContentConsent(p, a);
        require(
            ingress.contentConsentEvidence(1, p.familyId, p.newStateHash) == record,
            "exact retry succeeds"
        );
        Content.Freeze memory freeze = _contentFreezeProposal();
        a = _authorization(false);
        a.signature = _signature(ingress.contentFreezeDigest(freeze, a));
        before_ = _roots();
        avm.mockCallRevert(
            address(archive),
            abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            failure
        );
        vm.expectRevert(failure);
        ingress.authorizeArtistContentFreeze(freeze, a);
        require(_roots() == before_, "freeze rollback preserves both owners");
        avm.clearMockedCalls();
        (bool valid,) = ingress.isContentFreezeAuthorized(1, keccak256("SCRIPT"));
        require(!valid, "failed freeze leaves no lookup record");
        ingress.authorizeArtistContentFreeze(freeze, a);
    }

    function testCodecOriginalPublicationExactSafeCalldataSurvivesLateArchiveFailure() public {
        ArtistPublicationHostFixture host = _publicationHost();
        (P.Publication memory pub, T.Attestation memory p, bytes memory statement) =
            _publicationTerms(host, false);
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.attestationDigest(p, a));
        bytes32 expected = _publicationExpected(p, a, 1);
        bytes memory data = abi.encodeCall(IStreamArtistOnboarding.recordArtistAttestation, (p, a, statement));
        bytes32 before_ = _roots();
        uint256 beforeNonce = artist.nonce();
        uint256 hint = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        avm.mockCallRevert(address(archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(T.InvalidRecord.selector));
        vm.expectRevert(bytes("GS013"));
        this.executeArtistSafe(data);
        require(_roots() == before_ && artist.nonce() == beforeNonce
            && IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint == hint
            && IStreamArtistRecordPublicationOwner(suite.owners[4]).publicationAttestation(expected).evidence.attestationRecordHash == 0,
            "Archive restores Safe, original nonce, both owners and saved evidence");
        avm.clearMockedCalls();
        require(this.executeArtistSafe(data), "identical Safe calldata retry");
        require(artist.nonce() == beforeNonce + 1
            && IStreamArtistRecordPublicationOwner(suite.owners[4]).publicationAttestation(expected).evidence.attestationRecordHash == expected,
            "one original publication record");
        require(ingress.requireRecordPublication(expected, pub).requiredCapability == 1,
            "unchanged current publication admission");
        before_ = _roots(); beforeNonce = artist.nonce();
        vm.expectRevert(bytes("GS013"));
        this.executeArtistSafe(data);
        require(_roots() == before_ && artist.nonce() == beforeNonce, "identical signed payload cannot replay");
    }
}
