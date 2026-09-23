// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentAuthorityConfiguration.t.sol";
import {
    IStreamArtistArchiveOriginReads as Worker
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamArtistArchiveOriginReads.sol";
import {
    StreamFinalityConservationReads as Conservation
} from "../../../smart-contracts/domains/finality/StreamFinalityConservationReads.sol";
import "../../../smart-contracts/interfaces/stream/finality/StreamFinalityConservationTypes.sol";
import "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionRecordReceipts.sol";
import "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import "../../../smart-contracts/domains/records/StreamConservationDefinitions.sol";
import "../../../smart-contracts/domains/records/StreamWorkRecordDefinitions.sol";

/// @dev Projection boundary tests use the actual configuration/conservation/lineage-call readers.
/// Stored selection, receipt and fixed worker outputs are explicit fixtures. Actual recovered
/// ancestry, original Archive, sanction signature and Finality graph execution remain separate.
contract StreamCurrentAuthorityPresentationTest is CurrentAuthorityConsumerFixture {
    StreamFinalityScope private scope;
    StreamFinalityScopeInputs private inputs;
    IStreamConservationRecordSelection.Selection private selected;
    IStreamCollectionMetadataV1.RecordReceipt private receipt;
    IStreamMetadataServingFacts.ArtistPresentation private presented;
    O.Origin private current;
    O.Origin private original;
    bytes32 private subject;
    bytes32 private constant ARTIST = keccak256("stable Artist across ancestry");

    function setUp() public override {
        super.setUp();
        vm.warp(100);
        scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 7, 0, 0);
        _selection(scope);
    }

    function _selection(StreamFinalityScope memory actualScope) private {
        subject = StreamMetadataSubjects.scopeSubject(block.chainid, c.targets[0], actualScope);
        selected.association = IStreamConservationRecordSelection.Association(
            ARTIST, keccak256("original binding"), 1, keccak256("immutable registration")
        );
        selected.origin = StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT;
        selected.interviewStatus = StreamConservationRecordTypes.InterviewStatus.WAIVED;
        selected.revision = 1;
        selected.selectedAt = 50;
        selected.submitter = address(0x6529);
        selected.catalogsHash = keccak256("actual catalogue commitment boundary");
        selected.record.kind = IStreamConservationRecordSelection.RecordKind.INTENT;
        selected.record.recordHash = keccak256("selected original intent");
        selected.record.payloadHash = keccak256("exact original payload boundary");
        selected.record.recorder = address(0x6529);
        selected.record.recordedAt = 40;
        selected.record.recordChainHash = keccak256("actual record chain boundary");
        selected.record.publication.attestationRecordHash = keccak256("original publication24");
        selected.record.publication.artistId = ARTIST;
        selected.record.publication.bindingHash = selected.association.bindingHash;
        selected.record.publication.bindingGeneration = 1;
        selected.record.publication.signer = selected.record.recorder;
        selected.record.publication.authorityClass = 1;
        selected.record.publication.requiredCapability = 64;
        selected.record.publication.signedAt = 30;
        selected.record.publication.publicationHash = keccak256("exact publication boundary");
        selected.record.publicationEvidenceHash = keccak256("full saved publication tuple boundary");
        receipt.collectionId = actualScope.collectionId;
        receipt.recorder = selected.record.recorder;
        receipt.authorizationClass = 1;
        receipt.recordedAt = 40;
        receipt.recordChainHash = selected.record.recordChainHash;
        receipt.schemaDefinitionHash = StreamConservationDefinitions.INTENT_SCHEMA_HASH;
        receipt.canonicalizationDefinitionHash = StreamWorkRecordDefinitions.CANON_HASH;
        receipt.artistAuthorization = selected.record.publication.attestationRecordHash;
        selected.record.receiptHash = keccak256(abi.encode(receipt));
        selected.selectionHash = 0;
        selected.selectionHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_SELECTION_V1"),
                c.chainId,
                c.targets[17],
                c.targets[0],
                c.targets[1],
                c.targets[4],
                c.targets[5],
                actualScope.collectionId,
                subject,
                selected
            )
        );
        inputs.intentRecordHash = selected.record.recordHash;
        Conservation.Dependencies memory cd;
        cd.targets = [c.targets[0], c.targets[1], c.targets[4], c.targets[5], c.targets[17]];
        inputs.interviewEvidenceHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_WAIVED_INTERVIEW_V1"),
                c.chainId,
                cd.targets,
                actualScope,
                subject,
                selected,
                StreamConservationDefinitions.INTERVIEW_SCHEMA_ID,
                StreamConservationDefinitions.INTERVIEW_PROFILE_HASH
            )
        );
        _configurationReads();
        FinalityMultiOriginReadTable(c.targets[17])
            .set(
                abi.encodeCall(
                    IStreamConservationRecordSelection.currentConservation,
                    (actualScope.collectionId, subject, selected.origin)
                ),
                abi.encode(selected)
            );
        FinalityMultiOriginReadTable(c.targets[17])
            .set(
                abi.encodeCall(
                    IStreamConservationRecordSelection.requireCurrent,
                    (
                        actualScope.collectionId,
                        subject,
                        selected.origin,
                        selected.record.recordHash,
                        selected.revision
                    )
                ),
                abi.encode(selected)
            );
        table.set(
            abi.encodeCall(
                IStreamCollectionRecordReceipts.collectionRecordReceipt,
                (selected.record.recordHash)
            ),
            abi.encode(receipt)
        );
        table.set(
            abi.encodeCall(
                IStreamCollectionMetadataV1.recordHashAt,
                (actualScope.collectionId, keccak256("ARTIST_INTENT"), uint64(0))
            ),
            abi.encode(selected.record.recordHash)
        );
        table.set(
            abi.encodeWithSignature(
                "consumedArtistAuthorization(bytes32)", receipt.artistAuthorization
            ),
            abi.encode(true)
        );
        IStreamConservationRecordSelection.IntentLock memory unlocked;
        FinalityMultiOriginReadTable(c.targets[17])
            .set(
                abi.encodeCall(
                    IStreamConservationRecordSelection.intentLock,
                    (actualScope.collectionId, subject)
                ),
                abi.encode(unlocked)
            );
        presented.locked = true;
        presented.registry = address(new FinalityMultiOriginReadTable());
        presented.registryCodeHash = presented.registry.codehash;
        presented.artistId = ARTIST;
        presented.bindingGeneration = 1;
        presented.bindingHash = selected.association.bindingHash;
        presented.identityRecordHash = selected.association.identityRecordHash;
        presented.nominatedArtist = address(0x6529);
        presented.acceptanceRecordHash = keccak256("saved acceptance boundary");
        presented.acceptedAt = 10;
        presented.lockedAt = 20;
        presented.snapshotHash = keccak256("worker-authenticated original Router snapshot boundary");
        table.set(
            abi.encodeCall(
                IStreamMetadataServingFacts.artistPresentation, (actualScope.collectionId)
            ),
            abi.encode(presented)
        );
        current.environment.registry = captured.dependencies.artistTargets[0];
        current.registryCodeHash = captured.dependencies.artistCodeHashes[0];
        original.environment.registry = presented.registry;
        original.registryCodeHash = presented.registryCodeHash;
        _worker(actualScope, current, original, keccak256("typed lineage worker boundary"));
    }

    function _configurationReads() private {
        string[4] memory selectors = ["core()", "metadata()", "schemaRegistry()", "chunkStore()"];
        string[4] memory hashSelectors = [
            "coreCodeHash()",
            "metadataCodeHash()",
            "schemaRegistryCodeHash()",
            "chunkStoreCodeHash()"
        ];
        for (uint256 i; i < 4; ++i) {
            FinalityMultiOriginReadTable(c.targets[17])
                .set(abi.encodeWithSignature(selectors[i]), abi.encode(address(table)));
            FinalityMultiOriginReadTable(c.targets[17])
                .set(abi.encodeWithSignature(hashSelectors[i]), abi.encode(address(table).codehash));
        }
        FinalityMultiOriginReadTable(c.targets[17])
            .set(abi.encodeWithSignature("deploymentChainId()"), abi.encode(block.chainid));
        FinalityMultiOriginReadTable(c.targets[17])
            .set(
                abi.encodeCall(
                    IERC165.supportsInterface,
                    (type(IStreamConservationRecordSelection).interfaceId)
                ),
                abi.encode(true)
            );
    }

    function _worker(
        StreamFinalityScope memory actualScope,
        O.Origin memory now_,
        O.Origin memory saved,
        bytes32 lineage
    ) private {
        worker.set(
            abi.encodeCall(
                Worker.lineage,
                (captured.dependencies, actualScope.collectionId, presented, selected.association)
            ),
            abi.encode(now_, saved, lineage)
        );
    }

    function testOriginalPresentationCanDifferFromCurrentArtistAfterAuthenticatedLineage() public {
        require(presented.registry != c.targets[11]);
        require(caHarness.artist(c, D.INVENTORY_PROFILE, scope, inputs) == ARTIST);
    }

    function testStatementMustNameExactCurrentIntentAndInterviewCommitments() public {
        StreamFinalityScopeInputs memory wrong = inputs;
        wrong.intentRecordHash = keccak256("unselected intent");
        _rejectAuthority(
            abi.encodeCall(caHarness.artist, (c, D.INVENTORY_PROFILE, scope, wrong)),
            CurrentPresentation.FinalityPresentationChanged.selector
        );
        wrong = inputs;
        wrong.interviewEvidenceHash = keccak256("different interview assertion");
        _rejectAuthority(
            abi.encodeCall(caHarness.artist, (c, D.INVENTORY_PROFILE, scope, wrong)),
            CurrentPresentation.FinalityPresentationChanged.selector
        );
        require(caHarness.artist(c, D.INVENTORY_PROFILE, scope, inputs) == ARTIST);
    }

    function testCurrentSelectionCannotBeReplacedByRetainedReceiptAlone() public {
        IStreamConservationRecordSelection.Selection memory changed = selected;
        changed.association.bindingHash = keccak256("changed current association");
        FinalityMultiOriginReadTable(c.targets[17])
            .set(
                abi.encodeCall(
                    IStreamConservationRecordSelection.requireCurrent,
                    (
                        scope.collectionId,
                        subject,
                        selected.origin,
                        selected.record.recordHash,
                        selected.revision
                    )
                ),
                abi.encode(changed)
            );
        _rejectAuthority(
            abi.encodeCall(caHarness.artist, (c, D.INVENTORY_PROFILE, scope, inputs)),
            Conservation.ConservationSelection.selector
        );
    }

    function testWorkerResultMustRetainBothExactRegistryPinsAndNonzeroLineage() public {
        O.Origin memory wrong = current;
        wrong.environment.registry = presented.registry;
        _worker(scope, wrong, original, keccak256("lineage"));
        _rejectAuthority(
            abi.encodeCall(caHarness.artist, (c, D.INVENTORY_PROFILE, scope, inputs)),
            CurrentPresentation.FinalityPresentationChanged.selector
        );
        wrong = original;
        wrong.registryCodeHash = keccak256("changed original runtime");
        _worker(scope, current, wrong, keccak256("lineage"));
        _rejectAuthority(
            abi.encodeCall(caHarness.artist, (c, D.INVENTORY_PROFILE, scope, inputs)),
            CurrentPresentation.FinalityPresentationChanged.selector
        );
        _worker(scope, current, original, 0);
        _rejectAuthority(
            abi.encodeCall(caHarness.artist, (c, D.INVENTORY_PROFILE, scope, inputs)),
            O.InvalidArchiveOrigin.selector
        );
    }

    function testMalformedWorkerCannotReturnPartialLineageCertificate() public {
        worker.set(
            abi.encodeCall(
                Worker.lineage,
                (captured.dependencies, scope.collectionId, presented, selected.association)
            ),
            abi.encode(current)
        );
        _rejectAuthority(
            abi.encodeCall(caHarness.artist, (c, D.INVENTORY_PROFILE, scope, inputs)),
            bytes4(keccak256("InventoryRead(address)"))
        );
    }

    function testScopedProjectionUsesActualScopedConservationSubject() public {
        _publishCurrent(D.SCOPED_INVENTORY_PROFILE);
        scope = StreamFinalityScope(StreamFinalityScopeType.TOKEN, 7, 9, 0);
        _selection(scope);
        require(caHarness.artist(c, D.SCOPED_INVENTORY_PROFILE, scope, inputs) == ARTIST);
        scope.tokenId = 10;
        _rejectAuthority(
            abi.encodeCall(caHarness.artist, (c, D.SCOPED_INVENTORY_PROFILE, scope, inputs)),
            Conservation.ConservationRead.selector
        );
    }

    function _rejectAuthority(bytes memory input, bytes4 selector) private {
        (bool ok, bytes memory result) = address(caHarness).call(input);
        require(!ok && result.length >= 4 && bytes4(result) == selector, "exact rejection required");
    }
}
