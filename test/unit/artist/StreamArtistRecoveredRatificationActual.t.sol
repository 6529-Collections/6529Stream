// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredDelegationAuthorityActualTest
} from "./StreamArtistRecoveredDelegationAuthorityActual.t.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistOnboarding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistOnboarding.sol";
import {
    IStreamArtistConsentOwner as Consent
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistConsentOwner.sol";
import {
    IStreamArtistDelegatedConsentOwner as Delegated
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegatedConsentOwner.sol";
import {
    IStreamArtistIdentityOwner as Identity
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    IStreamArtistNativeReceipts as Native
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistArchiveV2 as Archive
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH,
    IStreamArtistAuthorityHydrationOwner as HydrationOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    IStreamArtistRecoveredHydration as Recovered
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    StreamArtistRecoveredHydrationPrepared as Prepared
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationPrepared.sol";
import {
    StreamArtistRecoveredHydrationCommit as Commit
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationCommit.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredHydrationEvidence as Evidence
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationEvidence.sol";
import {
    StreamArtistRecoveredRatificationHydration as Codec
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredRatificationHydration.sol";
import {
    StreamArtistRecoveredContentConsentHydration as OldCodec
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredContentConsentHydration.sol";

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistPublicationHydrationTypes as PH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPublicationAuthorityHydration.sol";
import {
    StreamArtistRecoveredIdentityHydrationSource as IdentitySource
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredIdentityHydrationSource.sol";
import {
    StreamArtistRecoveredRatificationStage as RatificationStage
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredRatificationStage.sol";

import {
    StreamArtistRecoveredAuthorityActualTest
} from "./StreamArtistRecoveredAuthorityActual.t.sol";

interface RatificationVm {
    function expectCall(address, bytes calldata, uint64) external;
    function mockCall(address, bytes calldata, bytes calldata) external;
}

/// @notice Actual original Artist52, matured living recovery, grant records, Safes and seven-owner60.
/// @dev Core, governance scheduling and Metadata content are inherited typed boundaries. No
/// producer record/storage is fabricated. These authored cases are not full-current/native evidence.
contract StreamArtistRecoveredRatificationActualTest is
    StreamArtistRecoveredDelegationAuthorityActualTest
{
    RatificationVm private constant rv =
        RatificationVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    T.RatificationRecord[] private retained;

    function testRatificationMixedGrantHistoryUsesExplicitCodecAndExactOriginalHeads() external {
        _baseline();
        _ratify(101, true);
        _ratify(102, false);
        Successor memory next = _rhCutover();
        (RH.Request memory request, Commit.Prepared memory p) = _prepare(next);
        (RH.ExportHeader memory h, Payload.Payload memory payload) =
            Payload.decode(p.data[6].typedState, 6);
        (Codec.Bundle memory b, uint64 generation, uint8 mode) =
            Codec.decode(p.query, payload.provenance, payload.semanticState);
        require(
            generation == 1 && mode == 2 && b.ratifications.length == 2,
            "original current generation/mode and full52 inventory"
        );
        require(
            (h.requiredFeatures & 1024) != 0 && (h.requiredFeatures & 256) == 0,
            "52 capability is distinct from absent content writes"
        );
        require(
            keccak256(payload.semanticState)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_RECOVERED_RATIFICATION_CONSENTS_V1"),
                        uint16(1),
                        uint64(1),
                        uint8(2),
                        b
                    )
                ),
            "independent literal new codec"
        );
        for (uint8 i; i < 7; ++i) {
            (RH.ExportHeader memory ownerHeader,) = Payload.decode(p.data[i].typedState, i);
            require(
                ownerHeader.requiredFeatures == h.requiredFeatures,
                "all seven explicit capabilities"
            );
        }
        _import(next, request, p);
        _assert(next.coordinator.suiteConfiguration());
    }

    function testRatificationRepeatedImportRetainsAAndBRecordsThenFreshCDomain() external {
        _baseline();
        _ratify(201, false);
        T.SuiteConfiguration memory original = suite;
        Successor memory middle = _rhCutover();
        (RH.Request memory request, Commit.Prepared memory first) = _prepare(middle);
        _import(middle, request, first);
        _rhAdopt(middle);
        _ratify(202, true);
        Successor memory last = _rhCutover();
        Commit.Prepared memory second;
        (request, second) = _prepare(last);
        _import(last, request, second);
        require(second.admission.provenance.eras.length == 2, "two original environments");
        for (uint8 owner; owner < 7; ++owner) {
            for (uint256 j; j < first.admission.provenance.journals[owner].length; ++j) {
                require(
                    keccak256(abi.encode(first.admission.provenance.journals[owner][j]))
                        == keccak256(abi.encode(second.admission.provenance.journals[owner][j])),
                    "original journal prefix immutable"
                );
            }
        }
        _assert(last.coordinator.suiteConfiguration());
        require(
            Consent(original.owners[6]).firstReleaseRatification(1).recordHash
                == retained[0].recordHash,
            "A head unchanged"
        );
        _rhAdopt(last);
        _ratify(203, false);
        _assert(suite);
    }

    function testRatificationCapabilityAndSourceCheckpointFailureHaveNoPartialImport() external {
        _baseline();
        _ratify(301, false);
        Successor memory next = _rhCutover();
        (RH.Request memory request, Commit.Prepared memory p) = _prepare(next);
        bytes32 before_ = _rhDestinationHash(next);
        request.expectedCapabilities[6].supportedFeatures &= ~uint256(1024);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        request.expectedCapabilities[6].supportedFeatures |= 1024;
        ++request.records.authority.expectedSource[6].ownerState.revision;
        avm.expectRevert(RH.InvalidRecoveredHydrationProvenance.selector);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        --request.records.authority.expectedSource[6].ownerState.revision;
        require(_rhDestinationHash(next) == before_, "all owner roots unchanged");
        _import(next, request, p);
        _assert(next.coordinator.suiteConfiguration());
    }

    function testRatificationCodecRejectsMissingDuplicateReorderedAndForeignOriginalRows()
        external
    {
        _baseline();
        _ratify(401, false);
        _ratify(402, true);
        Successor memory next = _rhCutover();
        (, Commit.Prepared memory p) = _prepare(next);
        (, Payload.Payload memory payload) = Payload.decode(p.data[6].typedState, 6);
        (Codec.Bundle memory original, uint64 generation, uint8 mode) =
            Codec.decode(p.query, payload.provenance, payload.semanticState);
        for (uint8 mutation; mutation < 4; ++mutation) {
            Codec.Bundle memory b = abi.decode(abi.encode(original), (Codec.Bundle));
            if (mutation == 0) b.ratifications = new T.RatificationRecord[](0);
            if (mutation == 1) b.ratifications[1] = b.ratifications[0];
            if (mutation == 2) {
                T.RatificationRecord memory first = b.ratifications[0];
                b.ratifications[0] = b.ratifications[1];
                b.ratifications[1] = first;
            }
            if (mutation == 3) b.ratifications[0].recordHash = keccak256("foreign52");
            (bool ok,) = address(this)
                .staticcall(
                    abi.encodeCall(
                        this.decodeRatified,
                        (
                            p.query,
                            payload.provenance,
                            abi.encode(
                                keccak256("6529STREAM_ARTIST_RECOVERED_RATIFICATION_CONSENTS_V1"),
                                uint16(1),
                                generation,
                                mode,
                                b
                            )
                        )
                    )
                );
            require(!ok, "invalid complete52 envelope refused");
        }
        (bool oldAccepted,) = address(this)
            .staticcall(
                abi.encodeCall(this.decodeOld, (p.query, payload.provenance, payload.semanticState))
            );
        require(!oldAccepted, "oldcodec cannot silently reinterpret52");
    }

    function testRatificationCurrentHeadAndDelegateAssociationMustMatchActualSource() external {
        _baseline();
        _ratify(501, false);
        _ratify(502, true);
        Successor memory next = _rhCutover();
        RH.Request memory request = _dcRequest();
        rv.mockCall(
            suite.owners[6],
            abi.encodeCall(Consent.firstReleaseRatification, (uint256(1))),
            abi.encode(retained[0])
        );
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Prepared.prepare(next.coordinator.suiteConfiguration(), request);
        rv.mockCall(
            suite.owners[6],
            abi.encodeCall(Consent.firstReleaseRatification, (uint256(1))),
            abi.encode(retained[1])
        );
        rv.mockCall(
            suite.owners[6],
            abi.encodeCall(Delegated.recordDelegation, (retained[0].recordHash)),
            abi.encode(bytes32(uint256(9)))
        );
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Prepared.prepare(next.coordinator.suiteConfiguration(), request);
        rv.mockCall(
            suite.owners[6],
            abi.encodeCall(Delegated.recordDelegation, (retained[0].recordHash)),
            abi.encode(bytes32(0))
        );
        Commit.Prepared memory p = Prepared.prepare(next.coordinator.suiteConfiguration(), request);
        request.expectedSemanticInventory = Prepared.inventory(p);
        _import(next, request, p);
    }

    function testRatificationLateArchiveFailureRollsBackEveryHeadThenSameSafeRequestRetries()
        external
    {
        _baseline();
        _ratify(601, true);
        Successor memory next = _rhCutover();
        (RH.Request memory request, Commit.Prepared memory p) = _prepare(next);
        bytes memory call_ = abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (request));
        rv.expectCall(
            next.coordinator.suiteConfiguration().archive, _firstPage(next, request, p), 2
        );
        bytes32 before_ = _rhDestinationHash(next);
        uint256 nonce = rotationSafe.nonce();
        uint256 height = block.number;
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(address(next.registry), call_);
        require(
            rotationSafe.nonce() == nonce && _rhDestinationHash(next) == before_,
            "seven owners plus Safe rollback"
        );
        require(
            Consent(next.coordinator.suiteConfiguration().owners[6])
                .firstReleaseRatification(1)
                .recordHash == 0
                && Consent(next.coordinator.suiteConfiguration().owners[6])
                .ratificationRecord(retained[0].recordHash)
                .recordHash == 0,
            "new current and historical52 maps rollback"
        );
        vm.roll(height);
        require(this.rhExecuteNewSafe(address(next.registry), call_), "identical Safe retry");
        require(rotationSafe.nonce() == nonce + 1, "exactly one committed Safe execution");
        _assert(next.coordinator.suiteConfiguration());
    }

    function testRatificationFreshSuccessorRejectsOldDomainThenSameNonceCurrentDomainWorks()
        external
    {
        _baseline();
        _ratify(701, false);
        Successor memory next = _rhCutover();
        (RH.Request memory request, Commit.Prepared memory p) = _prepare(next);
        _import(next, request, p);
        address previous = address(ingress);
        _rhAdopt(next);
        metadata.setContent(keccak256("new successor content"));
        T.Ratification memory terms =
            T.Ratification(1, address(metadata), keccak256("new successor content"));
        T.Authorization memory a = _authorization(false);
        bytes32 before_ = _rhDestinationHash(next);
        a.signature = _signature(ingressAt(previous).contentRatificationDigest(terms, a));
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordContentRatification(terms, a);
        require(_rhDestinationHash(next) == before_, "foreign signature consumes no original state");
        a.signature = _signature(ingress.contentRatificationDigest(terms, a));
        bytes32 record = ingress.recordContentRatification(terms, a);
        require(
            Consent(suite.owners[6]).firstReleaseRatification(1).recordHash == record,
            "same nonce fresh domain admitted"
        );
    }

    function testRatificationFullFactsRequireExactlyOneOriginalSignatureRow() external {
        _baseline();
        _ratify(801, true); // The saved empty signature is still one authenticated row.
        Successor memory next = _rhCutover();
        (, Commit.Prepared memory p) = _prepare(next);
        (, Payload.Payload memory ip) = Payload.decode(p.data[2].typedState, 2);
        (, Payload.Payload memory cp) = Payload.decode(p.data[6].typedState, 6);
        IH.Bundle memory identity = IdentitySource.decode(ip.semanticState, ip.provenance);
        bytes memory records = abi.encode(new PH.Row[](0));
        RatificationStage.facts(
            abi.encode(identity), cp.semanticState, p.query, p.admission.provenance, 2, records
        );
        uint256 index = type(uint256).max;
        for (uint256 i; i < identity.signatures.length; ++i) {
            if (identity.signatures[i].recordHash == retained[0].recordHash) index = i;
        }
        require(
            index != type(uint256).max && identity.signatures[index].signature.length == 0,
            "actual empty Safe signature is present"
        );
        IH.SignatureRow[] memory original = identity.signatures;
        identity.signatures = new IH.SignatureRow[](original.length - 1);
        for (uint256 i; i < original.length - 1; ++i) {
            identity.signatures[i] = original[i < index ? i : i + 1];
        }
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        RatificationStage.facts(
            abi.encode(identity), cp.semanticState, p.query, p.admission.provenance, 2, records
        );
        identity.signatures = new IH.SignatureRow[](original.length + 1);
        for (uint256 i; i < original.length; ++i) {
            identity.signatures[i] = original[i];
        }
        identity.signatures[original.length] = original[index];
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        RatificationStage.facts(
            abi.encode(identity), cp.semanticState, p.query, p.admission.provenance, 2, records
        );
        identity.signatures = original;
        RatificationStage.facts(
            abi.encode(identity), cp.semanticState, p.query, p.admission.provenance, 2, records
        );
    }

    function testNoRatificationHistoryRetainsOriginalDelegatedBytesAndCapability() external {
        _baseline();
        Successor memory next = _rhCutover();
        RH.Request memory request = _dcRequest();
        Commit.Prepared memory p = Prepared.prepare(next.coordinator.suiteConfiguration(), request);
        (RH.ExportHeader memory h, Payload.Payload memory payload) =
            Payload.decode(p.data[6].typedState, 6);
        require(
            (h.requiredFeatures & 1024) == 0
                && abi.decode(payload.semanticState, (bytes32))
                    == keccak256("6529STREAM_ARTIST_RECOVERED_DELEGATED_CONSENTS_V1"),
            "zero52 original profile stays selected"
        );
        request.expectedSemanticInventory = Prepared.inventory(p);
        _import(next, request, p);
        _dcAssert(next.coordinator.suiteConfiguration());
    }

    function decodeRatified(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        external
        pure
    {
        Codec.decode(q, p, raw);
    }

    function decodeOld(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        external
        pure
    {
        OldCodec.decode(q, p, raw);
    }

    function ingressAt(address x) private pure returns (RatificationDigestReader) {
        return RatificationDigestReader(x);
    }

    function _baseline() private {
        _dcBaseline();
    }

    function _ratify(uint256 salt, bool direct) private {
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
        retained.push(Consent(suite.owners[6]).ratificationRecord(record));
    }

    function _prepare(Successor memory next)
        private
        view
        returns (RH.Request memory request, Commit.Prepared memory p)
    {
        request = _dcRequest();
        p = Prepared.prepare(next.coordinator.suiteConfiguration(), request);
        request.expectedSemanticInventory = Prepared.inventory(p);
    }

    function _import(Successor memory next, RH.Request memory request, Commit.Prepared memory p)
        private
    {
        require(
            this.rhExecuteNewSafe(
                address(next.registry),
                abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (request))
            ),
            "original Safe60"
        );
        _rhImported(next, p, HydrationOwner(next.identity).authorityHydrationCommitment());
    }

    function _assert(T.SuiteConfiguration memory target) private view {
        _dcAssert(target);
        for (uint256 i; i < retained.length; ++i) {
            require(
                keccak256(
                    abi.encode(Consent(target.owners[6]).ratificationRecord(retained[i].recordHash))
                ) == keccak256(abi.encode(retained[i])),
                "every exact original52 map row"
            );
        }
        require(
            keccak256(abi.encode(Consent(target.owners[6]).firstReleaseRatification(1)))
                == keccak256(abi.encode(retained[retained.length - 1])),
            "exact operative52 head"
        );
    }

    function _firstPage(Successor memory next, RH.Request memory request, Commit.Prepared memory p)
        private
        view
        returns (bytes memory)
    {
        bytes32 value = keccak256(
            abi.encode(
                RH.PROFILE,
                RH.VERSION,
                block.chainid,
                address(next.registry),
                address(next.coordinator),
                p.admission.prior,
                p.admission.sourceCoordinator,
                request,
                p.admission.artists,
                p.admission.collections,
                p.query,
                p.data,
                p.timing,
                p.externalGuards,
                p.admission.before_
            )
        );
        bytes memory profile = abi.encode(
            RH.PROFILE,
            RH.VERSION,
            p.admission.prior,
            p.admission.sourceCoordinator,
            request,
            p.admission.artists,
            p.admission.collections,
            p.query,
            p.data,
            p.timing,
            p.externalGuards
        );
        Evidence.Descriptor memory descriptor = Evidence.describe(profile);
        bytes32 id = Evidence.pageId(
            address(next.registry), address(next.coordinator), value, descriptor, 0
        );
        return abi.encodePacked(Archive.appendArtistEvidenceV2.selector, id);
    }
}

interface RatificationDigestReader {
    function contentRatificationDigest(T.Ratification calldata, T.Authorization calldata)
        external
        view
        returns (bytes32);
}

/// @notice Original mode1/no-grant ratification profile uses the same complete recovered import.
contract StreamArtistRecoveredRatificationDirectActualTest is
    StreamArtistRecoveredAuthorityActualTest
{
    function testRatificationDirectModeOneKeepsNoGrantAndNoContentFeatures() external {
        _rhBaseline();
        _adoptRotatedSafe();
        uint64 end = ingress.artistTransitionState(rhRecovery).postWindowEndsAt;
        if (block.timestamp < end) vm.warp(end);
        bytes32 content = keccak256("actual direct original52 content");
        metadata.setContent(content);
        T.Ratification memory terms = T.Ratification(1, address(metadata), content);
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.contentRatificationDigest(terms, a);
        _rhAuthorization(digest, a.nonce);
        a.signature = _signature(digest);
        bytes32 record = ingress.recordContentRatification(terms, a);
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
            "literal original signed mode1 record"
        );
        _rhCandidate(
            6, "consent_finality.replay.ratification_key", keccak256(abi.encode(uint256(1), record))
        );
        T.RatificationRecord memory original = Consent(suite.owners[6]).ratificationRecord(record);
        Successor memory next = _rhCutover();
        RH.Request memory request = _rhRequest();
        Commit.Prepared memory prepared =
            Prepared.prepare(next.coordinator.suiteConfiguration(), request);
        (RH.ExportHeader memory header, Payload.Payload memory payload) =
            Payload.decode(prepared.data[6].typedState, 6);
        (Codec.Bundle memory bundle, uint64 generation, uint8 mode) =
            Codec.decode(prepared.query, payload.provenance, payload.semanticState);
        require(
            mode == 1 && generation == 1 && bundle.ratifications.length == 1,
            "exact direct mode/generation"
        );
        require(
            (header.requiredFeatures & 1024) != 0
                && (header.requiredFeatures & (64 | 256 | 512)) == 0,
            "no invented delegation/content/generation capability"
        );
        request.expectedSemanticInventory = Prepared.inventory(prepared);
        require(
            this.rhExecuteNewSafe(
                address(next.registry),
                abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (request))
            ),
            "actual direct Safe60"
        );
        _rhImported(next, prepared, HydrationOwner(next.identity).authorityHydrationCommitment());
        address destination = next.coordinator.suiteConfiguration().owners[6];
        require(
            keccak256(abi.encode(Consent(destination).ratificationRecord(record)))
                == keccak256(abi.encode(original)),
            "original direct historical row"
        );
        require(
            keccak256(abi.encode(Consent(destination).firstReleaseRatification(1)))
                == keccak256(abi.encode(original)),
            "original direct current head"
        );
    }
}
