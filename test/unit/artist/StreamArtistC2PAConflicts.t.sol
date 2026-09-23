// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistAttributionDisputeFixture.sol";
import {
    StreamArtistC2PATypes as C2PA,
    IStreamArtistC2PAReads
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistC2PA.sol";
import {
    StreamC2PAReconciliation
} from "../../../smart-contracts/domains/metadata/StreamC2PAReconciliation.sol";
import {
    IStreamC2PAReconciliation as CR
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamC2PAReconciliation.sol";
import { MetadataExecutorBoundary } from "../../helpers/scoped-preservation-boundaries/StreamCollectionMetadataV1Boundaries.sol";
import {
    IStreamStaticMetadataRouter as SR
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    StreamCollectionManifestTypes as CM
} from "../../../smart-contracts/interfaces/stream/metadata/StreamCollectionManifestTypes.sol";
import {
    IStreamCollectionManifestWriter,
    IStreamMetadataManifestSelection
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionManifestWriter.sol";
import {
    IStreamMetadataServingFacts as C2PAServing
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol";

import {
    IStreamC2PAConflicts as CF
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamC2PAConflicts.sol";

/// @notice Actual Artist op24/op44/op46, original Archive/dual-family evidence and threshold Safe.
/// Core, Router content and governance execution remain inherited explicit typed boundaries.
contract StreamArtistC2PAConflictsTest is ArtistAttributionDisputeFixture {
    bytes32 private constant CREDENTIAL_SCHEMA = keccak256("6529STREAM_ARTIST_C2PA_CREDENTIALS_V1");

    struct C2PAJoin {
        MetadataExecutorBoundary governance;
        StreamSchemaRegistry schemas;
        StreamSchemaDocumentStore store;
        StreamCollectionMetadataV1 host;
        StreamC2PAReconciliation companion;
        CR.Report report;
    }

    function _credential(bytes memory statement) private returns (bytes32) {
        T.Attestation memory p = _terms(statement);
        T.Authorization memory a = _authorization(true);
        _artistCall(
            abi.encodeCall(IStreamArtistOnboarding.recordArtistAttestation, (p, a, statement))
        );
        return IStreamArtistAttributionOwner(suite.owners[4])
        .attestation(1, 10, artistId)
        .recordHash;
    }

    function _payload(bytes32 previous, bool empty) private view returns (bytes memory) {
        C2PA.Credential[] memory credentials = new C2PA.Credential[](empty ? 0 : 1);
        if (!empty) {
            credentials[0] =
                C2PA.Credential(1, keccak256("test SPKI"), keccak256("identity key"), 1, 0);
        }
        return abi.encode(
            C2PA.Payload(
                1, artistId, ingress.operativeIdentityRecord(artistId), previous, credentials
            )
        );
    }

    function _terms(bytes memory statement) private view returns (T.Attestation memory) {
        return T.Attestation(
            1,
            10,
            artistId,
            ingress.operativeIdentityRecord(artistId),
            CREDENTIAL_SCHEMA,
            keccak256(statement),
            "urn:c2pa:credentials"
        );
    }

    function _join() private returns (C2PAJoin memory j) {
        _accept();
        bytes32 credentials = _credential(_payload(0, false));
        j.governance = new MetadataExecutorBoundary();
        j.schemas = new StreamSchemaRegistry(address(j.governance));
        j.store = StreamSchemaDocumentStore(j.schemas.chunkStore());
        _definition(
            j,
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(j.schemas.RAW_BYTES_DEFINITION())
        );
        _definition(
            j,
            "6529STREAM_C2PA_RECONCILIATION_REPORT_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/records/6529STREAM_C2PA_RECONCILIATION_REPORT_V1.json"))
        );
        StreamCollectionMetadataV1.Configuration memory config;
        config.core = address(core);
        config.executor = address(j.governance);
        config.schemas = address(j.schemas);
        config.artistRegistry = address(ingress);
        config.deploymentManifestHash = keccak256("C2PA metadata test deployment");
        config.manifestHash = keccak256("C2PA metadata test module");
        config.manifestURI = "ipfs://c2pa-test";
        config.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 150000, 100000, 2
        );
        config.artistReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ARTIST_READ_GAS", 2000000, 1000000, 2
        );
        j.host = new StreamCollectionMetadataV1(config);
        core.set(keccak256("COLLECTION_METADATA"), address(j.host), false);
        core.set(keccak256("METADATA_ROUTER"), address(metadata), false);
        bytes32 family = keccak256("6529STREAM_RECORD_FAMILY_C2PA_V1");
        (bytes32 scope, bytes32 oldHash, bytes32 nextHash) =
            j.host.recordTypeTransition(keccak256("C2PA_VALIDATION"), family, 0x150);
        j.governance
            .execute(
                address(j.host),
                abi.encodeCall(
                    j.host.admitRecordType, (keccak256("C2PA_VALIDATION"), family, uint16(0x150))
                ),
                scope,
                oldHash,
                nextHash
            );
        _verifier(j, address(artist), 6);
        C2PAServing.ServingSource memory source;
        source.imageURI = "ipfs://actual-committed-media";
        avm.mockCall(
            address(metadata),
            abi.encodeWithSignature("renderingProfile()"),
            abi.encode(
                keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1"),
                keccak256("6529STREAM_METADATA_TOKEN_RENDER_CONTEXT_V1"),
                keccak256("6529STREAM_METADATA_RENDER_NO_EXTERNAL_READS_V1")
            )
        );
        avm.mockCall(
            address(metadata),
            abi.encodeCall(C2PAServing.collectionServingSource, (uint256(1))),
            abi.encode(source)
        );
        CM.MediaManifest memory media;
        media.imageSourceType = CM.PayloadSourceType.IPFS;
        media.imageURI = source.imageURI;
        media.imageHash = keccak256("actual local media");
        media.imageMimeType = "image/png";
        vm.prank(address(metadata));
        bytes32 mediaManifest =
            IStreamCollectionManifestWriter(address(j.host)).storeMediaManifest(1, media);
        CM.Selection memory selected =
            CM.Selection(address(j.host), address(j.host).codehash, mediaManifest);
        avm.mockCall(
            address(metadata),
            abi.encodeCall(
                IStreamMetadataManifestSelection.selectedCollectionManifest, (uint256(1), uint8(3))
            ),
            abi.encode(selected)
        );
        SR.RawSource memory raw;
        raw.chainId = block.chainid;
        raw.configured = true;
        raw.imageURI = source.imageURI;
        raw.mediaManifest = selected;
        avm.mockCall(
            address(metadata), abi.encodeCall(SR.staticRenderSource, (uint256(1))), abi.encode(raw)
        );
        j.companion = new StreamC2PAReconciliation(
            address(core),
            address(j.host),
            address(ingress),
            address(metadata),
            address(artist),
            address(j.governance),
            IStreamGasParameterHost.GasParameterConfig(
                "C2PA_DEPENDENCY_READ_GAS", 1000000, 100000, 2
            )
        );
        CR.Report memory p;
        p.version = 1;
        p.profile = j.companion.PROFILE();
        p.collectionId = 1;
        p.subjectId = StreamMetadataSubjects.scopeSubject(
            block.chainid,
            address(core),
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0)
        );
        p.artistId = artistId;
        p.bindingHash = ingress.displayBinding(1).bindingHash;
        p.generation = 1;
        p.identityRecordHash = ingress.operativeIdentityRecord(artistId);
        p.identityDocumentHash = p.identityRecordHash;
        p.credentialRecordHash = credentials;
        p.publicKeyHistoryHash = keccak256("synthetic verifier key history observation");
        p.credentialEnumerationHash =
        IStreamArtistC2PAReads(suite.owners[4]).c2paCredentialHead(artistId).statementHash;
        p.selectedMediaManifestHash = mediaManifest;
        p.mediaSlot = 1;
        p.mediaHash = media.imageHash;
        p.claimAssetHash = media.imageHash;
        p.manifestHash = keccak256("manifest");
        p.claimHash = keccak256("claim");
        p.claimSignatureHash = keccak256("signature");
        p.signerKind = 1;
        p.signerFingerprint = keccak256("test SPKI");
        p.signerKeyFingerprint = p.signerFingerprint;
        p.keyId = keccak256("identity key");
        p.signedAt = uint64(block.timestamp);
        p.validation = CR.ValidationStatus.VALID;
        p.authorship = CR.AuthorshipStatus.CONSISTENT;
        p.assertsAuthorship = true;
        p.validatorIdentityHash = keccak256("explicit fixture verifier");
        p.softwareVersionHash = keccak256("test-only-observation-1");
        (p.validationReportHash,) =
            j.store.publishChunk(bytes("synthetic selected verifier observation; no crypto claim"));
        (p.trustAnchorsHash,) = j.store.publishChunk(bytes("explicit test trust anchors"));
        p.reportURI = "ipfs://synthetic-c2pa-report";
        j.report = p;
    }

    function _definition(
        C2PAJoin memory j,
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory payload
    ) private {
        (bytes32 hash,) = j.store.publishChunk(payload);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            name, kind, hash, j.schemas.RAW_BYTES(), 0, "", uint32(payload.length)
        );
        (bytes32 s, bytes32 o, bytes32 n) = j.schemas.registrationTransition(spec, chunks);
        j.governance
            .execute(
                address(j.schemas),
                abi.encodeCall(j.schemas.registerDocument, (spec, chunks)),
                s,
                o,
                n
            );
    }

    function _verifier(C2PAJoin memory j, address account, uint8 authClass) private {
        bytes32 family = keccak256("6529STREAM_RECORD_FAMILY_C2PA_V1");
        (bytes32 s, bytes32 o, bytes32 n) =
            j.host.familyWriterTransition(1, family, authClass, account, true);
        j.governance
            .execute(
                address(j.host),
                abi.encodeCall(
                    j.host.setFamilyWriter, (uint256(1), family, authClass, account, true)
                ),
                s,
                o,
                n
            );
    }

    function _publish(C2PAJoin memory j) private returns (bytes32 hash) {
        return _publishClass(j, 6);
    }

    function _publishClass(C2PAJoin memory j, uint8 expectedClass) private returns (bytes32 hash) {
        bytes memory payload = abi.encode(j.report);
        IStreamPreservationRecords.CollectionRecord memory r;
        r.recordType = keccak256("C2PA_VALIDATION");
        r.subjectId = j.report.subjectId;
        r.schemaId = j.companion.SCHEMA();
        r.contentHash = IStreamPreservationRecords.HashRef(
            1, abi.encode(keccak256(payload)), j.schemas.RAW_BYTES()
        );
        r.uri = j.report.reportURI;
        r.effectiveAt = uint64(block.timestamp);
        hash = j.host.deriveCollectionRecordHashFor(address(artist), 1, r);
        require(
            this.executeTargetSafe(
                address(j.host),
                abi.encodeCall(j.host.recordCollectionRecordWithPayload, (uint256(1), r, payload))
            )
        );
        (, IStreamCollectionMetadataV1.RecordReceipt memory receipt) = j.host.collectionRecord(hash);
        require(
            receipt.recorder == address(artist) && receipt.authorizationClass == expectedClass
                && receipt.artistAuthorization == 0,
            "explicit receipt class, not op24 authority"
        );
    }

    function _divergent(C2PAJoin memory j) private returns (bytes32 id) {
        CR.Selection memory prior = j.companion.currentSelection(1, j.report.subjectId);
        j.report.authorship = CR.AuthorshipStatus.DIVERGENT;
        j.report.claimHash = keccak256(abi.encode("new conflict", prior.revision));
        bytes32 record = _publish(j);
        j.companion.adopt(1, j.report.subjectId, record, prior.selectionHash, prior.revision);
        id = j.companion.standingConflict(1, j.report.subjectId).conflictId;
    }

    function _clearAction(C2PAJoin memory j, bytes32 id, bytes memory narrative)
        private
        returns (bytes32)
    {
        _deStore = j.store;
        bytes32 opening = _open(keccak256(abi.encode("C2PA dispute opening", id)));
        j.store.publishChunk(narrative);
        AD.ResolutionRequest memory p = _resolution(1, keccak256(narrative));
        require(p.disputeRecordHash == opening);
        bytes32 action = _resolve(p, 1);
        _deArchive(46, manager.governanceAuthority(), action);
        return action;
    }

    function _assertStanding(C2PAJoin memory j, bytes32 id, uint64 count) private view {
        CF.Standing memory h = j.companion.standingConflict(1, j.report.subjectId);
        require(h.conflictId == id && h.unresolvedCount == count && h.chainHash != 0);
        if (id != 0) {
            CF.Conflict memory c = j.companion.conflictRecord(id);
            require(h.recordHash == c.recordHash && h.selectionHash == c.selectionHash);
            require(j.companion.conflictResolution(id).actionId == 0);
        }
    }

    function testCurrentConflictHasIndependentExactIdentityAndImmutableHistory() public {
        C2PAJoin memory j = _join();
        bytes32 id = _divergent(j);
        CF.Conflict memory c = j.companion.conflictRecord(id);
        bytes32 chain = c.chainHash;
        c.conflictId = 0;
        c.chainHash = 0;
        require(
            id
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_C2PA_STANDING_CONFLICT_V1"),
                        block.chainid,
                        address(j.companion),
                        address(core),
                        address(ingress),
                        c
                    )
                )
        );
        require(
            chain
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_C2PA_CONFLICT_CHAIN_V1"), bytes32(0), id, uint64(1)
                    )
                )
        );
        require(j.companion.conflictAt(1, j.report.subjectId, 1) == id);
        require(j.companion.display(1, j.report.subjectId).current);
        _assertStanding(j, id, 1);
    }

    function testCredentialWithdrawalAndMediaDriftDoNotEraseStandingConflict() public {
        C2PAJoin memory j = _join();
        bytes32 id = _divergent(j);
        _credential(_payload(j.report.credentialRecordHash, true));
        require(!j.companion.display(1, j.report.subjectId).current);
        _assertStanding(j, id, 1);
        SR.RawSource memory changed;
        changed.chainId = block.chainid;
        changed.configured = true;
        avm.mockCall(
            address(metadata),
            abi.encodeCall(SR.staticRenderSource, (uint256(1))),
            abi.encode(changed)
        );
        require(!j.companion.display(1, j.report.subjectId).current);
        _assertStanding(j, id, 1);
    }

    function testReplacedVerifierHeadAndValidSuccessorReportCannotClearConflict() public {
        C2PAJoin memory j = _join();
        bytes32 id = _divergent(j);
        CR.Selection memory prior = j.companion.currentSelection(1, j.report.subjectId);
        j.report.authorship = CR.AuthorshipStatus.CONSISTENT;
        j.report.claimHash = keccak256("later consistent report");
        bytes32 next = _publish(j);
        require(!j.companion.display(1, j.report.subjectId).current);
        _assertStanding(j, id, 1);
        j.companion.adopt(1, j.report.subjectId, next, prior.selectionHash, prior.revision);
        require(j.companion.display(1, j.report.subjectId).current);
        require(
            j.companion.display(1, j.report.subjectId).authorship == CR.AuthorshipStatus.CONSISTENT
        );
        _assertStanding(j, id, 1);
    }

    function testExactOriginalResolutionClearsOnlyItsConflictAndRetainsHistory() public {
        C2PAJoin memory j = _join();
        bytes32 first = _divergent(j);
        bytes32 second = _divergent(j);
        bytes32 action = _clearAction(j, second, j.companion.resolutionNarrative(second));
        bytes32 roots = _roots();
        require(
            this.executeTargetSafe(
                address(j.companion), abi.encodeCall(CF.clearStandingConflict, (second, action))
            )
        );
        require(_roots() == roots, "acknowledgement never mutates Artist authority");
        _assertStanding(j, first, 1);
        require(j.companion.conflictResolution(second).actionId == action);
        require(j.companion.conflictRecord(second).previousConflict == first);
        vm.expectRevert();
        j.companion.clearStandingConflict(first, action);
        _assertStanding(j, first, 1);
        vm.expectRevert();
        j.companion.clearStandingConflict(second, action);
        bytes32 nextAction = _clearAction(j, first, j.companion.resolutionNarrative(first));
        j.companion.clearStandingConflict(first, nextAction);
        _assertStanding(j, 0, 0);
        require(j.companion.standingConflict(1, j.report.subjectId).revision == 2);
        bytes32 third = _divergent(j);
        _assertStanding(j, third, 1);
        vm.expectRevert();
        j.companion.clearStandingConflict(third, nextAction);
    }

    function testUnrelatedResolutionAndOldClosedActionCannotClear() public {
        C2PAJoin memory j = _join();
        bytes32 id = _divergent(j);
        bytes32 unrelated = _clearAction(j, id, bytes("different adjudicated subject"));
        vm.expectRevert();
        j.companion.clearStandingConflict(id, unrelated);
        _assertStanding(j, id, 1);
        bytes32 actual = _clearAction(j, id, j.companion.resolutionNarrative(id));
        // A later pending dispute invalidates that formerly current closed head.
        _open(keccak256("new appeal or dispute"));
        vm.expectRevert();
        j.companion.clearStandingConflict(id, actual);
        _assertStanding(j, id, 1);
    }

    function testWrongGenerationOriginalResolutionReadFailsClosed() public {
        C2PAJoin memory j = _join();
        bytes32 id = _divergent(j);
        bytes32 action = _clearAction(j, id, j.companion.resolutionNarrative(id));
        AD.Resolution memory original = ingress.attributionDisputeResolution(action);
        bytes memory exact = abi.encode(original);
        original.terms.bindingGeneration++;
        avm.mockCall(
            suite.owners[4],
            abi.encodeCall(
                IStreamArtistAttributionDisputesOwner.attributionDisputeResolution, (action)
            ),
            abi.encode(original)
        );
        vm.expectRevert();
        j.companion.clearStandingConflict(id, action);
        _assertStanding(j, id, 1);
        avm.mockCall(
            suite.owners[4],
            abi.encodeCall(
                IStreamArtistAttributionDisputesOwner.attributionDisputeResolution, (action)
            ),
            exact
        );
        j.companion.clearStandingConflict(id, action);
        _assertStanding(j, 0, 0);
    }

    function testLateCoverageFailureRollsBackSafeThenIdenticalClearRetry() public {
        C2PAJoin memory j = _join();
        bytes32 id = _divergent(j);
        bytes32 action = _clearAction(j, id, j.companion.resolutionNarrative(id));
        AD.Resolution memory r = ingress.attributionDisputeResolution(action);
        bytes memory exact =
            abi.encode(estateCoverageProvider.requireCollectionEvidence(1, r.terms.evidenceHash));
        A.CoverageFacts memory bad;
        avm.mockCall(
            address(estateCoverageProvider),
            abi.encodeCall(
                IStreamCollectionArchivalCoverage.requireCollectionEvidence,
                (uint256(1), r.terms.evidenceHash)
            ),
            abi.encode(bad)
        );
        bytes memory data = abi.encodeCall(CF.clearStandingConflict, (id, action));
        uint256 nonce = artist.nonce();
        bytes32 roots = _roots();
        vm.expectRevert();
        this.executeTargetSafe(address(j.companion), data);
        require(artist.nonce() == nonce && _roots() == roots);
        _assertStanding(j, id, 1);
        avm.mockCall(
            address(estateCoverageProvider),
            abi.encodeCall(
                IStreamCollectionArchivalCoverage.requireCollectionEvidence,
                (uint256(1), r.terms.evidenceHash)
            ),
            exact
        );
        require(this.executeTargetSafe(address(j.companion), data));
        require(artist.nonce() == nonce + 1 && _roots() == roots);
        _assertStanding(j, 0, 0);
    }
}
