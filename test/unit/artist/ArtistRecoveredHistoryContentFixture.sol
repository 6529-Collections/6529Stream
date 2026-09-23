// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistRecoveredSanctionHistoryFixture.sol";
import {
    StreamArtistRecoveredHistoryContentTypes as HC
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHistoryContentTypes.sol";
import {
    StreamArtistRecoveredHistoryContentCodec as HCCodec
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHistoryContentCodec.sol";
import {
    StreamArtistRecoveredHistoryContentFactRows as HCFacts
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHistoryContentFactRows.sol";
import {
    StreamArtistRecoveredContentConsentHydration as ContentH
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredContentConsentHydration.sol";
import {
    IStreamArtistRecoveredConsentHydration as WithConsents
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredConsentHydration.sol";
import {
    IStreamArtistContentAuthority
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentAuthority.sol";
import {
    IStreamArtistContentRecordsOwner as ContentOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentOwner.sol";
import {
    StreamArtistContentTypes as Content
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    IStreamArtistDelegatedConsentOwner as Delegated
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegatedConsentOwner.sol";
import {
    StreamArtistRecoveredIdentityHydrationSource as IdentitySource
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredIdentityHydrationSource.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";

/// @notice Actual original producers/owners, Safe, Archive and complete recovered history.
/// @dev Inherited Core/governance/metadata/coverage and executed Finality remain typed boundaries.
/// No owner semantic state, signature inventory, chronology or import guard is replaced.
abstract contract ArtistRecoveredHistoryContentFixture is ArtistRecoveredSanctionHistoryFixture {
    struct Row {
        uint16 operation;
        bytes32 record;
        Content.Consent content;
        Content.Freeze freeze;
        T.RoyaltyFreeze royalty;
        T.Authorization authorization;
        bytes32 digest;
        bytes32 originalBody;
        uint64 generation;
    }
    Row[] internal contentRows;
    T.RatificationRecord[] internal retained;
    mapping(bytes32 => bytes) internal originalSignatures;

    function _hcGrant(uint64 maximum) internal returns (bytes32 record) {
        Delegate.Grant memory terms = _delegation(
            1,
            Delegate.DISPUTE | Delegate.ROYALTY_FREEZE,
            uint64(block.timestamp),
            uint64(block.timestamp + 365 days),
            maximum
        );
        T.Authorization memory a = T.Authorization(nextNonce, 0, "");
        bytes32 digest = ingress.delegationGrantDigest(terms, a);
        record = _grant(terms);
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(2, "identity_authority.replay.delegation_key", record);
    }

    function _hcDelegatedRoyalty(bytes32 grant, uint256 nonce) internal returns (bytes32 record) {
        Row memory r;
        r.operation = 20;
        r.generation = Binding(suite.owners[0]).binding(1).generation;
        r.royalty = _freezePayload();
        r.authorization = T.Authorization(nonce, uint64(block.timestamp + 1 days), "");
        r.digest = ingress.royaltyFreezeDigest(r.royalty, r.authorization);
        r.authorization.signature = _delegateSignature(r.digest);
        r.record = ingress.authorizeDelegatedRoyaltyFreeze(r.royalty, grant, r.authorization);
        require(
            r.record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_ROYALTY_FREEZE_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(royalty),
                        uint256(1),
                        r.royalty.revenueClass,
                        r.royalty.expectedAssignmentHash,
                        artistId,
                        address(delegateSafe),
                        uint8(2),
                        nonce,
                        uint64(block.timestamp)
                    )
                ),
            "literal delegated original20"
        );
        r.originalBody = keccak256(
            abi.encode(
                Consent(suite.owners[6]).royaltyFreezeRecord(r.royalty, artistId, r.generation)
            )
        );
        bytes32 lane = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"),
                artistId,
                address(delegateSafe)
            )
        );
        _rhCandidate(
            2, "identity_authority.replay.delegated_nonce", keccak256(abi.encode(lane, nonce))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(artistId, r.digest))
        );
        _rhCandidate(
            6,
            "consent_finality.replay.freeze_key",
            keccak256(abi.encode(r.royalty, artistId, r.generation))
        );
        originalSignatures[r.record] = r.authorization.signature;
        contentRows.push(r);
        return r.record;
    }

    function _hcContent(bytes32 candidate, bool direct) internal {
        Row memory item;
        item.generation = Binding(suite.owners[0]).binding(1).generation;
        item.operation = 17;
        item.content = _contentProposal(candidate);
        item.authorization = _authorization(false);
        item.digest = ingress.contentConsentDigest(item.content, item.authorization);
        address actor = address(this);
        if (direct) {
            actor = address(rotationSafe);
            require(
                this.rhExecuteNewSafe(
                    address(ingress),
                    abi.encodeCall(
                        IStreamArtistContentAuthority.recordContentConsent,
                        (item.content, item.authorization)
                    )
                ),
                "actual current Safe direct17"
            );
            item.record =
            ContentOwner(suite.owners[6]).contentConsentAt(item.content, item.generation).recordHash;
        } else {
            item.authorization.signature = _signature(item.digest);
            item.record = ingress.recordContentConsent(item.content, item.authorization);
        }
        require(
            item.record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_CONTENT_CONSENT_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(metadata),
                        address(core),
                        uint256(1),
                        item.content.familyId,
                        item.content.newStateHash,
                        artistId,
                        address(artist),
                        uint8(1),
                        item.authorization.nonce,
                        uint64(block.timestamp)
                    )
                ),
            "literal original17 hash"
        );
        item.originalBody =
            keccak256(abi.encode(ContentOwner(suite.owners[6]).contentConsentRecord(item.record)));
        _rhCandidate(
            6,
            "consent_finality.replay.content_consent_key",
            keccak256(abi.encode(keccak256(abi.encode(item.content, item.generation)), item.record))
        );
        _hcRemember(item, actor);
    }

    function _hcFreeze() internal {
        Row memory item;
        item.generation = Binding(suite.owners[0]).binding(1).generation;
        item.operation = 21;
        item.freeze = _contentFreezeProposal();
        item.authorization = _authorization(false);
        item.digest = ingress.contentFreezeDigest(item.freeze, item.authorization);
        item.authorization.signature = _signature(item.digest);
        item.record = ingress.authorizeArtistContentFreeze(item.freeze, item.authorization);
        require(
            item.record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_CONTENT_FREEZE_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(metadata),
                        address(core),
                        uint256(1),
                        item.freeze.lockClasses,
                        item.freeze.expectedStateHash,
                        artistId,
                        address(artist),
                        uint8(1),
                        item.authorization.nonce,
                        uint64(block.timestamp)
                    )
                ),
            "literal original21 hash"
        );
        item.originalBody =
            keccak256(abi.encode(ContentOwner(suite.owners[6]).contentFreezeRecord(item.record)));
        _rhCandidate(
            6,
            "consent_finality.replay.freeze_key",
            keccak256(abi.encode(keccak256("CONTENT"), uint256(1), item.generation, item.record))
        );
        _hcRemember(item, address(this));
    }

    function _hcRoyalty() internal {
        Row memory item;
        item.generation = Binding(suite.owners[0]).binding(1).generation;
        item.operation = 20;
        item.royalty = _freezePayload();
        item.authorization = _authorization(false);
        item.digest = ingress.royaltyFreezeDigest(item.royalty, item.authorization);
        item.authorization.signature = _signature(item.digest);
        item.record = ingress.authorizeArtistRoyaltyFreeze(item.royalty, item.authorization);
        require(
            item.record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_ROYALTY_FREEZE_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(royalty),
                        uint256(1),
                        item.royalty.revenueClass,
                        item.royalty.expectedAssignmentHash,
                        artistId,
                        address(artist),
                        uint8(1),
                        item.authorization.nonce,
                        uint64(block.timestamp)
                    )
                ),
            "literal original20 hash"
        );
        item.originalBody = keccak256(
            abi.encode(
                Consent(suite.owners[6])
                    .royaltyFreezeRecord(item.royalty, artistId, item.generation)
            )
        );
        _rhCandidate(
            6,
            "consent_finality.replay.freeze_key",
            keccak256(abi.encode(item.royalty, artistId, item.generation))
        );
        _hcRemember(item, address(this));
    }

    function _hcRatify(uint256 salt, bool direct) internal {
        bytes32 content = keccak256(abi.encode("actual original52 content", salt));
        metadata.setContent(content);
        T.Ratification memory terms = T.Ratification(1, address(metadata), content);
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.contentRatificationDigest(terms, a);
        _rhAuthorization(digest, a.nonce);
        uint256 identities = Native(suite.owners[2]).artistNativeReceiptCount();
        uint256 count = Native(suite.owners[6]).artistNativeReceiptCount();
        bytes32 record;
        if (direct) {
            require(
                this.rhExecuteNewSafe(
                    address(ingress),
                    abi.encodeCall(IStreamArtistOnboarding.recordContentRatification, (terms, a))
                ),
                "original Safe52"
            );
            record = Consent(suite.owners[6]).firstReleaseRatification(1).recordHash;
        } else {
            a.signature = _signature(digest);
            record = ingress.recordContentRatification(terms, a);
        }
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_CONTENT_RATIFICATION_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(metadata),
                        address(core),
                        uint256(1),
                        content,
                        artistId,
                        address(artist),
                        uint8(1),
                        a.nonce,
                        uint64(block.timestamp)
                    )
                ),
            "independent original record preimage"
        );
        require(
            Native(suite.owners[2]).artistNativeReceiptCount() == identities
                && Native(suite.owners[6]).artistNativeReceiptCount() == count + 1
                && Native(suite.owners[6]).artistNativeReceiptAt(count).operation == 52
                && Native(suite.owners[6]).artistNativeReceiptAt(count).recordHash == record,
            "one real Consent52, no synthetic Identity52"
        );
        _rhCandidate(
            6, "consent_finality.replay.ratification_key", keccak256(abi.encode(uint256(1), record))
        );
        originalSignatures[record] = a.signature;
        require(
            keccak256(Identity(suite.owners[2]).signatureBundle(record)) == keccak256(a.signature),
            "original52 exact signed or direct-empty evidence"
        );
        retained.push(Consent(suite.owners[6]).ratificationRecord(record));
    }

    function _hcPrepare(Successor memory next)
        internal
        view
        returns (RH.Request memory r, Commit.Prepared memory p)
    {
        r = _rhRequest();
        r.records.authority.collections[0].policies = new AH.PolicyKey[](basePolicies.length);
        for (uint256 i; i < basePolicies.length; ++i) {
            r.records.authority.collections[0].policies[i] =
                AH.PolicyKey(basePolicies[i].phaseId, basePolicies[i].policyHash);
        }
        if (baseEconomicsRecord != 0) {
            r.records.witnesses = new MR.CollectionWitness[](1);
            r.records.witnesses[0].collectionId = 1;
            r.records.witnesses[0].economics = new T.EconomicsConsent[](1);
            r.records.witnesses[0].economics[0] = baseEconomics;
            r.records.witnesses[0].attestations = new Ready.AttestationInput[](0);
        }
        p = Prepared.prepare(next.coordinator.suiteConfiguration(), r, _hcRoyalties());
        r.expectedSemanticInventory = Prepared.inventory(p);
    }

    function _hcArchive(
        Successor memory next,
        RH.Request memory r,
        Commit.Prepared memory p,
        DisputeHistoryVm.Log[] memory logs
    ) internal view {
        bytes32 value = keccak256(
            abi.encode(
                RH.PROFILE,
                uint16(1),
                block.chainid,
                address(next.registry),
                address(next.coordinator),
                p.admission.prior,
                p.admission.sourceCoordinator,
                r,
                p.admission.artists,
                p.admission.collections,
                p.query,
                p.data,
                p.timing,
                p.externalGuards,
                p.admission.before_
            )
        );
        require(
            HydrationOwner(next.identity).authorityHydrationCommitment() == value,
            "independent complete original op60 value"
        );
        bytes memory profile = abi.encode(
            RH.PROFILE,
            uint16(1),
            p.admission.prior,
            p.admission.sourceCoordinator,
            r,
            p.admission.artists,
            p.admission.collections,
            p.query,
            p.data,
            p.timing,
            p.externalGuards
        );
        Evidence.Descriptor memory descriptor = Evidence.describe(profile);
        T.Snapshot[7] memory after_;
        T.SuiteConfiguration memory target = next.coordinator.suiteConfiguration();
        for (uint8 i; i < 7; ++i) {
            after_[i] = OriginalOwner(target.owners[i]).ownerStateSnapshotV2();
        }
        bytes memory expected = abi.encode(
            uint16(1),
            next.coordinator.configurationHash(),
            uint16(60),
            address(rotationSafe),
            value,
            p.admission.before_,
            after_,
            abi.encode(RH.PROFILE, descriptor)
        );
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(next.registry),
                address(next.coordinator),
                uint16(60),
                address(rotationSafe),
                value
            )
        );
        require(
            keccak256(Archive(target.archive).artistEvidenceBytesV2(id, 1)) == keccak256(expected),
            "exact owner snapshots and original evidence carrier"
        );
        require(
            keccak256(
                Evidence.read(
                    target.archive,
                    address(next.registry),
                    address(next.coordinator),
                    value,
                    descriptor
                )
            ) == keccak256(profile),
            "all original profile bytes retained in Archive"
        );
        uint256 seen;
        for (uint256 i; i < logs.length; ++i) {
            DisputeHistoryVm.Log memory item = logs[i];
            if (
                item.emitter != address(next.coordinator) || item.topics.length != 4
                    || item.topics[0]
                        != keccak256(
                            "RecoveredArtistAuthorityHydrated(uint16,address,bytes32,bytes32,bytes32)"
                        )
            ) continue;
            require(
                item.topics[1] == bytes32(uint256(uint160(p.admission.prior)))
                    && item.topics[2] == value && item.topics[3] == r.expectedSemanticInventory
                    && keccak256(item.data) == keccak256(abi.encode(uint16(1), keccak256(profile))),
                "literal original hydration event"
            );
            ++seen;
        }
        require(seen == 1, "one original op60 event after complete Archive append");
    }

    function _hcRemember(Row memory r, address) internal {
        _rhAuthorization(r.digest, r.authorization.nonce);
        originalSignatures[r.record] = r.authorization.signature;
        require(
            keccak256(Identity(suite.owners[2]).signatureBundle(r.record))
                == keccak256(r.authorization.signature),
            "actual original signature"
        );
        contentRows.push(r);
    }

    function _hcRoyalties() internal view returns (T.RoyaltyFreeze[] memory terms) {
        uint256 count;
        for (uint256 i; i < contentRows.length; ++i) {
            if (contentRows[i].operation == 20) ++count;
        }
        terms = new T.RoyaltyFreeze[](count);
        count = 0;
        for (uint256 i; i < contentRows.length; ++i) {
            if (contentRows[i].operation == 20) terms[count++] = contentRows[i].royalty;
        }
    }

    function _hcCall(RH.Request memory r) internal view returns (bytes memory) {
        return abi.encodeCall(
            WithConsents.hydrateRecoveredArtistAuthorityWithConsents, (r, _hcRoyalties())
        );
    }

    function _hcImport(Successor memory next, RH.Request memory r, Commit.Prepared memory p)
        internal
    {
        dv.recordLogs();
        require(this.rhExecuteNewSafe(address(next.registry), _hcCall(r)), "actual complete Safe60");
        _rhImported(next, p, HydrationOwner(next.identity).authorityHydrationCommitment());
        _hcArchive(next, r, p, dv.getRecordedLogs());
        _hcAssert(next.coordinator.suiteConfiguration());
    }

    function _hcBundle(Commit.Prepared memory p) internal view returns (HC.Bundle memory b) {
        (RH.ExportHeader memory h, Payload.Payload memory local) =
            Payload.decode(p.data[6].typedState, 6);
        require(
            (h.requiredFeatures & (32768 | 8192)) == (32768 | 8192),
            "explicit complete history profile"
        );
        b = HCCodec.decode(p.query, local.provenance, local.semanticState);
        require(
            keccak256(local.semanticState)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_RECOVERED_HISTORY_CONTENT_V1"), uint16(1), b
                    )
                ),
            "literal new owner6 codec"
        );
        require(
            ((h.requiredFeatures & 256) != 0)
                == (b.consents.length + b.royalties.length + b.freezes.length != 0),
            "actual content flag"
        );
        require(
            ((h.requiredFeatures & 1024) != 0) == (b.ratifications.length != 0), "actual52 flag"
        );
    }

    function _hcAssert(T.SuiteConfiguration memory target) internal view {
        for (uint256 i; i < contentRows.length; ++i) {
            Row memory r = contentRows[i];
            bytes32 observed;
            if (r.operation == 17) {
                observed = keccak256(
                    abi.encode(ContentOwner(target.owners[6]).contentConsentRecord(r.record))
                );
            } else if (r.operation == 20) {
                observed = keccak256(
                    abi.encode(
                        Consent(target.owners[6])
                            .royaltyFreezeRecord(r.royalty, artistId, r.generation)
                    )
                );
            } else {
                observed = keccak256(
                    abi.encode(ContentOwner(target.owners[6]).contentFreezeRecord(r.record))
                );
            }
            require(observed == r.originalBody, "entire original historical body");
            require(
                keccak256(Identity(target.owners[2]).signatureBundle(r.record))
                    == keccak256(originalSignatures[r.record]),
                "original content signature retained"
            );
            if (r.operation == 17) {
                bytes32 head = r.record;
                for (uint256 j = i + 1; j < contentRows.length; ++j) {
                    if (
                        contentRows[j].operation == 17 && contentRows[j].generation == r.generation
                            && keccak256(abi.encode(contentRows[j].content))
                                == keccak256(abi.encode(r.content))
                    ) head = contentRows[j].record;
                }
                require(
                    ContentOwner(target.owners[6])
                        .contentConsentAt(r.content, r.generation)
                        .recordHash == head,
                    "per-generation exact original17 head"
                );
            } else if (r.operation == 21) {
                for (uint256 k; k < r.freeze.lockClasses.length; ++k) {
                    bytes32 head = r.record;
                    for (uint256 j = i + 1; j < contentRows.length; ++j) {
                        if (
                            contentRows[j].operation == 21
                                && contentRows[j].generation == r.generation
                                && contentRows[j].freeze.metadataContract
                                    == r.freeze.metadataContract
                        ) {
                            for (uint256 z; z < contentRows[j].freeze.lockClasses.length; ++z) {
                                if (contentRows[j].freeze.lockClasses[z] == r.freeze.lockClasses[k])
                                {
                                    head = contentRows[j].record;
                                }
                            }
                        }
                    }
                    require(
                        ContentOwner(target.owners[6])
                        .contentFreezeAt(
                            1, r.generation, r.freeze.metadataContract, r.freeze.lockClasses[k]
                        )
                        .recordHash == head,
                        "per-generation exact original21 head"
                    );
                }
            }
        }
        for (uint256 i; i < retained.length; ++i) {
            require(
                keccak256(
                    abi.encode(Consent(target.owners[6]).ratificationRecord(retained[i].recordHash))
                ) == keccak256(abi.encode(retained[i])),
                "all original three-word52 records"
            );
            require(
                keccak256(Identity(target.owners[2]).signatureBundle(retained[i].recordHash))
                    == keccak256(originalSignatures[retained[i].recordHash]),
                "signed and empty direct52 evidence survive"
            );
        }
        T.RatificationRecord memory expected;
        if (retained.length != 0) expected = retained[retained.length - 1];
        require(
            keccak256(abi.encode(Consent(target.owners[6]).firstReleaseRatification(1)))
                == keccak256(abi.encode(expected)),
            "exact global52 head, never generation-invented"
        );
    }

    function checkHistoryContent(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        external
        view
    {
        HCCodec.decode(q, p, raw);
    }
}
