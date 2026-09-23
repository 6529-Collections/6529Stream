// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistRecoveredEstateAuthorityActual.t.sol";
import {
    StreamArtistReadinessHydrationTypes as Ready
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    StreamArtistMultipleRecordsTypes as MR
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistMultipleRecordsHydration.sol";
import {
    StreamArtistAttestationTypes as Attest
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttestationWriter.sol";
import {
    StreamArtistPersonhoodTypes as Personhood,
    IStreamArtistPersonhoodEvidence as PersonhoodReads
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPersonhoodEvidence.sol";
import {
    IStreamArtistC2PAReads
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistC2PA.sol";
import {
    IStreamArtistAttributionOwner as Attribution
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    IStreamArtistReadinessAttributionOwner as AttestationClass
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    IStreamArtistAuthenticatedAttestationOwner as Associations
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttestationWriter.sol";

/// @notice Actual original40 -> mature35 -> class3 original24 -> recovered60 source scenarios.
/// @dev Registry, seven owners, Primary Resolver, Archive and Safe are actual; inherited Core and
/// governance facts remain explicit unit boundaries. Native execution/capacity is not claimed.
contract StreamArtistRecoveredEstateAttestationActualTest is
    StreamArtistRecoveredEstateAuthorityActualTest
{
    Ready.AttestationInput[] private eaInputs;
    bytes32[] private eaRecords;
    bytes[] private eaStatements;
    T.Authorization[] private eaAuthorizations;

    function testRecoveredClassThreeAttestationsKeepOriginalAuthorityAndWaiverThroughSafeImport()
        external
    {
        _eaStart(1);
        bytes32 primaryRecord = _eaWrite(false);
        bytes32 waiverRecord = _eaWrite(true);
        address sourceAttribution = suite.owners[4];
        address sourceIdentity = suite.owners[2];
        address[7] memory sourceOwners = suite.owners;
        uint256 retained = eaRecords.length;
        Successor memory next = _eaImport();
        address destinationAttribution = next.coordinator.suiteConfiguration().owners[4];
        _eaCompare(sourceAttribution, destinationAttribution, retained);
        require(
            Attribution(destinationAttribution)
            .attestation(1, 6, eaInputs[0].terms.subjectId)
            .recordHash == primaryRecord,
            "complete original subject head imported"
        );
        require(
            IStreamArtistC2PAReads(destinationAttribution)
                .personhoodAttestation(1, artistId)
                .recordHash == waiverRecord
                && PersonhoodReads(destinationAttribution).personhoodProofSummaryHash(waiverRecord)
                == 0,
            "class3 waiver remains the distinct original personhood choice"
        );
        Personhood.Selection memory selection =
            PersonhoodReads(destinationAttribution).personhoodEvidence(1, artistId);
        require(
            selection.status == Personhood.Status.WAIVER
                && selection.sourceRegistry == address(ingress)
                && selection.nativeRecord.recordHash == waiverRecord,
            "waiver selection keeps ultimate source registry"
        );
        bytes32 sourceBefore = _eaCheckpoints(sourceOwners);
        _ehAdopt(next);
        bytes32 fresh = _eaWrite(false);
        require(fresh != primaryRecord, "fresh B24 has its own original domain and nonce");
        require(
            Native(destinationAttribution).artistNativeReceiptCount() == 1
                && Native(destinationAttribution).artistNativeReceiptAt(0).recordHash == fresh
                && ingress.attestationAuthorityClass(fresh) == 3
                && Attribution(destinationAttribution)
                .attestation(1, 6, eaInputs[0].terms.subjectId)
                .recordHash == fresh
                && IStreamArtistC2PAReads(destinationAttribution)
                .personhoodAttestation(1, artistId)
                .recordHash == waiverRecord,
            "actual local24 extends imported class3 history"
        );
        _eaCompare(sourceAttribution, destinationAttribution, retained);
        require(
            _eaCheckpoints(sourceOwners) == sourceBefore, "fresh B24 leaves all A owners unchanged"
        );
        require(
            IStreamArtistIdentityOwner(sourceIdentity).identity(artistId).authorityClass == 3
                && IStreamArtistEstateOwner(next.identity)
                .currentAuthorityCapabilities(artistId)
                .effectiveCapabilities == 1,
            "import and new24 preserve original estate capability"
        );
    }

    function testRecoveredClassThreeZeroCapabilityStillRejectsOriginalAttestation() external {
        _eaStart(0);
        Successor memory next = _eaImport();
        _ehAdopt(next);
        bytes32 before_ = _eaCheckpoints(suite.owners);
        uint256 safeNonce = artist.nonce();
        vm.expectRevert(
            abi.encodeWithSelector(Estate.EstateCapabilityUnavailable.selector, artistId, uint32(1))
        );
        this.eaRelayedAttestation();
        require(
            _eaCheckpoints(suite.owners) == before_ && artist.nonce() == safeNonce
                && Native(suite.owners[4]).artistNativeReceiptCount() == 0,
            "zero-cap rejection leaves all owners, local history and Safe unchanged"
        );
        require(
            IStreamArtistEstateOwner(next.identity)
            .currentAuthorityCapabilities(artistId)
            .effectiveCapabilities == 0,
            "zero estate rights never become profile permissions"
        );
    }

    function testRecoveredClassThreeRejectsOldDomainAndKeepsPrincipalNonceSpent() external {
        _eaStart(1);
        _eaWrite(false);
        Ready.AttestationInput memory original = eaInputs[0];
        T.Authorization memory authorization = eaAuthorizations[0];
        bytes memory statement = eaStatements[0];
        Successor memory next = _eaImport();
        _ehAdopt(next);
        bytes32 before_ = _eaCheckpoints(suite.owners);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidSignature.selector));
        ingress.recordArtistAttestation(original.terms, authorization, statement);
        require(_eaCheckpoints(suite.owners) == before_, "old-domain24 rejects before mutation");

        authorization.signature =
            _signature(ingress.attestationDigest(original.terms, authorization));
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                address(ingress),
                address(coordinator),
                address(archive),
                suite.owners[2],
                Owner(suite.owners[2]).domainId(),
                keccak256("identity_authority.replay.nonce_allocator"),
                keccak256(abi.encode(artistId, authorization.nonce))
            )
        );
        vm.expectRevert(abi.encodeWithSelector(T.Replay.selector, key));
        ingress.recordArtistAttestation(original.terms, authorization, statement);
        require(
            _eaCheckpoints(suite.owners) == before_, "fresh-domain signature cannot reuse old nonce"
        );
        require(
            Owner(suite.owners[2]).replayCell(key).status == 2,
            "retained principal nonce stays spent"
        );
    }

    function eaRelayedAttestation() external returns (bytes32) {
        require(msg.sender == address(this), "fixture caller");
        (T.Attestation memory terms, bytes memory statement) = _eaTerms(false);
        T.Authorization memory authorization = _authorization(true);
        authorization.signature = _signature(ingress.attestationDigest(terms, authorization));
        return ingress.recordArtistAttestation(terms, authorization, statement);
    }

    function _eaStart(uint32 capabilities) private {
        _ehBaseline(capabilities);
        _adoptRotatedSafe();
        vm.warp(ingress.artistTransitionState(ehRecovery).postWindowEndsAt);
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).authorityClass == 3,
            "genuine original40 plus registered35 retains class3"
        );
    }

    function _eaTerms(bool waiver)
        private
        view
        returns (T.Attestation memory terms, bytes memory statement)
    {
        bytes32 state = waiver
            ? ingress.operativeIdentityRecord(artistId)
            : primary.resolvePrimaryAssignment(1, 0, keccak256("PRIMARY_SALE")).assignmentHash;
        statement = abi.encode("recovered class3 original attestation", waiver, eaInputs.length);
        terms = T.Attestation(
            1,
            waiver ? 10 : 6,
            waiver ? artistId : bytes32(uint256(uint160(address(primary)))),
            state,
            waiver
                ? keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")
                : keccak256("recovered class3 primary statement"),
            keccak256(statement),
            "urn:recovered:class3:attestation"
        );
    }

    function _eaWrite(bool waiver) private returns (bytes32 record) {
        (T.Attestation memory terms, bytes memory statement) = _eaTerms(waiver);
        T.Authorization memory authorization = _authorization(true);
        bytes32 digest = ingress.attestationDigest(terms, authorization);
        authorization.signature = _signature(digest);
        record = _publicationExpected(terms, authorization, 3);
        uint256 before_ = Native(suite.owners[4]).artistNativeReceiptCount();
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistOnboarding.recordArtistAttestation,
                    (terms, authorization, statement)
                ),
                0
            ),
            "real class3 Safe executes original24"
        );
        require(
            Native(suite.owners[4]).artistNativeReceiptCount() == before_ + 1
                && Native(suite.owners[4]).artistNativeReceiptAt(before_).recordHash == record
                && ingress.attestationAuthorityClass(record) == 3
                && Attribution(suite.owners[4]).attestationRecord(record).signer == address(artist),
            "literal original record preimage matches actual class3 producer"
        );
        Attest.Association memory association = ingress.attestationAssociation(record);
        require(
            association.artistId == artistId
                && association.bindingHash == ingress.displayBinding(1).bindingHash
                && association.generation == 1 && association.delegation == 0,
            "actual source subject association is direct class3"
        );
        _ehAuthorization(digest, authorization.nonce);
        _ehCandidate(2, "identity_authority.replay.attestation_key", keccak256(abi.encode(record)));
        eaInputs.push(Ready.AttestationInput(terms, authorization.nonce));
        eaRecords.push(record);
        eaStatements.push(statement);
        eaAuthorizations.push(authorization);
    }

    function _eaImport() private returns (Successor memory next) {
        next = _ehCutover();
        RH.Request memory request = _ehRequest();
        if (eaInputs.length != 0) {
            request.records.witnesses = new MR.CollectionWitness[](1);
            request.records.witnesses[0].collectionId = 1;
            request.records.witnesses[0].attestations =
                new Ready.AttestationInput[](eaInputs.length);
            for (uint256 i; i < eaInputs.length; ++i) {
                request.records.witnesses[0].attestations[i] = eaInputs[i];
            }
        }
        Commit.Prepared memory prepared =
            Prepared.prepare(next.coordinator.suiteConfiguration(), request);
        request.expectedSemanticInventory = Prepared.inventory(prepared);
        for (uint8 i; i < 7; ++i) {
            (RH.ExportHeader memory header,) = Payload.decode(prepared.data[i].typedState, i);
            require(
                ((header.requiredFeatures & RH.ATTESTATIONS) != 0) == (eaInputs.length != 0),
                "actual owner4 journal selects attestation feature on all seven owners"
            );
        }
        require(
            executeSafe(
                artist,
                keys,
                address(next.registry),
                0,
                abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (request)),
                0
            ),
            "actual class3 Safe drives permissionless seven-owner import"
        );
        _ehImported(next, prepared, HydrationOwner(next.identity).authorityHydrationCommitment());
    }

    function _eaCompare(address original, address destination, uint256 count) private view {
        for (uint256 i; i < count; ++i) {
            bytes32 record = eaRecords[i];
            require(
                keccak256(abi.encode(Attribution(original).attestationRecord(record)))
                        == keccak256(abi.encode(Attribution(destination).attestationRecord(record)))
                    && AttestationClass(destination).attestationAuthorityClass(record) == 3
                    && keccak256(abi.encode(Associations(original).attestationAssociation(record)))
                        == keccak256(
                            abi.encode(Associations(destination).attestationAssociation(record))
                        )
                    && keccak256(
                        Attribution(destination).statementBytes(eaInputs[i].terms.statementHash)
                    ) == keccak256(eaStatements[i]),
                "original class3 record/class/subject/statement preserved exactly"
            );
        }
    }

    function _eaCheckpoints(address[7] memory owners) private view returns (bytes32 result) {
        for (uint8 i; i < 7; ++i) {
            result = keccak256(
                abi.encode(
                    result, CP(owners[i]).authorityCheckpoint(), Publications.collect(owners[i], i)
                )
            );
        }
    }
}
