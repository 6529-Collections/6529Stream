// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../finality/StreamCurrentAuthorityConfiguration.t.sol";
import {
    StreamCurrentAuthorityPreservationPolicyBundleArchiveCoverageV1 as CollectionCoverage
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityPreservationPolicyBundleArchiveCoverageV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyBundleArchiveCoverageV1 as ScopedCoverage
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPreservationPolicyBundleArchiveCoverageV1.sol";
import {
    StreamCurrentAuthorityBundleArchiveCoverage as PriorCollectionCoverage
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityBundleArchiveCoverage.sol";
import {
    StreamCurrentAuthorityScopedBundleArchiveCoverage as PriorScopedCoverage
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedBundleArchiveCoverage.sol";
import {
    IStreamCurrentAuthorityPreservationPolicyRenderCriticalInventoryV1 as CollectionInventory
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamCurrentAuthorityPreservationPolicyRenderCriticalInventoryV1.sol";
import {
    IStreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1 as ScopedInventory
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1.sol";
import {
    IStreamCurrentAuthorityInventory as CapturedInventory
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamCurrentAuthorityInventory.sol";
import {
    IStreamArtistArchiveOriginInventory as OriginInventory
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamArtistArchiveOriginInventory.sol";
import {
    IStreamCurrentAuthorityBundleArchiveCoverage as CurrentCoverage
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamCurrentAuthorityBundleArchiveCoverage.sol";
import {
    IStreamBundleArchiveCoverage as BaseCoverage
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamBundleArchiveCoverage.sol";
import {
    IStreamScopedBundleArchiveCoverage as BaseScopedCoverage
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamScopedBundleArchiveCoverage.sol";
import {
    IStreamScopedPreservationPolicyBundleArchiveCoverageV1 as StandardScopedCoverage
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamScopedPreservationPolicyBundleArchiveCoverageV1.sol";
import {
    IStreamScopedPreservationPolicyRenderCriticalInventoryV1 as OldScopedWriter
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamScopedPreservationPolicyRenderCriticalInventoryV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalTypesV1 as Scoped
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamScopedPreservationPolicyBundleArchiveTypesV1 as ScopedBundle
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPreservationPolicyBundleArchiveTypesV1.sol";
import {
    StreamPreservationInventoryChains as Chains
} from "../../../smart-contracts/domains/preservation/StreamPreservationInventoryChains.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamMetadataSubjects
} from "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import { MultiOriginCoverageArchiveBoundary } from "./StreamMultiOriginBundleArchiveCoverage.t.sol";

/// @dev Real coverage/selection/environment/readers and genuine STOP byte containers over typed
/// source tables. This tests the consumer boundary, not a real preservation publication, Artist
/// migration, admission ceremony or full producer graph. Artificial table/code mutations are
/// negatives; they do not imply mutable production inventory facts or STOP runtimes.
contract StreamCurrentAuthorityPreservationPolicyBundleArchiveCoverageV1Test is
    CurrentAuthorityConsumerFixture
{
    CollectionCoverage private coverage;
    T.Evidence private evidence;
    T.Item private item;
    T.Segment private segment;
    bytes32 private originRoot;
    uint256 private originCount;

    function setUp() public override {
        super.setUp();
        _profile(false);
        coverage = new CollectionCoverage(bd, od, ad);
        evidence.planId = PLAN;
        evidence.artistId = keccak256("artist");
        evidence.collectionId = 1;
        evidence.scopeSubject = keccak256("collection subject");
        evidence.sourceContextHash = keccak256("preservation captured context");
        evidence.tokenCount = 1;
        evidence.tokenInventoryHash = keccak256("complete token inventory");
        evidence.segmentCount = 1;
        evidence.itemCount = 1;
        item.kind = T.Kind.ABSENT;
        item.role = keccak256("absent source field");
        item.source = c.targets[0];
        item.sourceRecord = keccak256("original absent source");
        _segment();
        _epoch(1);
        O.Origin[] memory origins = new O.Origin[](1);
        origins[0] = captured.selection.origin;
        _origins(origins);
        _seal(captured.selection.selectionHash);
    }

    function _profile(bool scoped) private {
        bytes32 profile = scoped
            ? D.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE
            : D.PRESERVATION_POLICY_INVENTORY_PROFILE;
        _publishCurrent(profile);
        _support(address(inventory), type(OriginInventory).interfaceId);
        _support(address(inventory), type(CapturedInventory).interfaceId);
        _support(
            address(inventory),
            scoped ? type(ScopedInventory).interfaceId : type(CollectionInventory).interfaceId
        );
        inventory.set(
            abi.encodeWithSignature(
                scoped
                    ? "scopedPreservationPolicyInventoryProfile()"
                    : "preservationPolicyInventoryProfile()"
            ),
            abi.encode(profile)
        );
    }

    function _segment() private {
        T.Item[] memory rows = new T.Item[](1);
        rows[0] = item;
        segment = Chains.segment(keccak256("segment"), keccak256("witness"), rows);
        evidence.segmentChainHash = Chains.append(0, 0, segment);
        inventory.set(
            abi.encodeWithSignature("inventorySegment(bytes32,uint64)", PLAN, uint64(0)),
            abi.encode(segment)
        );
    }

    function _origins(O.Origin[] memory origins) private {
        bytes32 chain;
        for (uint256 i; i < origins.length; ++i) {
            chain = O.appendOrigin(chain, i, origins[i]);
            inventory.set(
                abi.encodeWithSignature("originAt(bytes32,uint256)", PLAN, i),
                abi.encode(origins[i])
            );
        }
        originCount = origins.length;
        originRoot = O.sealedOriginSetHash(originCount, chain);
        inventory.set(
            abi.encodeWithSignature("originCount(bytes32)", PLAN), abi.encode(originCount)
        );
        inventory.set(
            abi.encodeWithSignature("originSetHash(bytes32)", PLAN), abi.encode(originRoot)
        );
    }

    function _seal(bytes32 selectionHash) private {
        evidence.renderCriticalEvidenceHash = 0;
        evidence.renderCriticalEvidenceHash = keccak256(
            abi.encode(
                D.PRESERVATION_POLICY_INVENTORY_PROFILE,
                block.chainid,
                address(inventory),
                c.inventoryDependencyHash,
                selectionHash,
                evidence,
                originRoot,
                originCount
            )
        );
        inventory.set(
            abi.encodeWithSignature("inventoryEvidence(bytes32)", PLAN), abi.encode(evidence)
        );
    }

    function _epoch(uint64 value) private {
        table.set(
            abi.encodeWithSignature("currentArtifactEnvironment()"),
            abi.encode(keccak256("artifact"), value)
        );
        table.set(
            abi.encodeWithSignature("currentExternalArtifactEnvironment()"),
            abi.encode(keccak256("external"), uint64(1))
        );
    }

    function _complete() private returns (T.BundleEvidence memory) {
        coverage.beginCoverage(PLAN);
        coverage.coverNext(PLAN, item, 0, B.Proof(0, 0, 0));
        return coverage.requireCoverage(PLAN, evidence.renderCriticalEvidenceHash);
    }

    function _fails(address target, bytes memory input) private {
        (bool accepted,) = target.call(input);
        require(!accepted, "preservation coverage must reject wrong boundary");
    }

    function _stateItem()
        private
        returns (MultiOriginCoverageArchiveBoundary archive, O.RecordOrigin memory fact)
    {
        archive = new MultiOriginCoverageArchiveBoundary();
        fact.producer = abi.decode(abi.encode(captured.selection.origin), (O.Origin));
        fact.producer.environment.archive = address(archive);
        fact.producer.archiveCodeHash = address(archive).codehash;
        fact.occurrence.receipt.operation = 17;
        fact.occurrence.receipt.artistId = evidence.artistId;
        fact.occurrence.receipt.collectionId = 1;
        fact.occurrence.receipt.recordHash = keccak256("original op17 consent");
        fact.occurrence.position.point.ownerIndex = 6;
        fact.occurrence.position.point.ownerRevision = 1;
        fact.occurrence.position.point.environmentHash = RH.originHash(fact.producer.environment);
        fact.actor = address(this);
        fact.importCommitment = keccak256("completed imported origin");
        fact.importedAtRevision = 1;
        fact.semanticRecordHash = keccak256("exact original semantic record");
        fact.role = keccak256("ORIGINAL_PRESERVATION_POLICY_CONTENT_ROOT_AUTHORIZATION_V1");
        fact.sourceContextHash = evidence.sourceContextHash;
        bytes memory payload = abi.encode("exact original archival bytes", uint16(17));
        bytes32 id = O.evidenceId(fact);
        archive.save(id, payload);
        item.kind = T.Kind.STATE_BUNDLE;
        item.role = fact.role;
        item.source = address(archive);
        item.sourceRecord = id;
        item.sourceIndex = 1;
        item.algorithm = 1;
        item.canonicalizationId = keccak256("RAW_BYTES");
        item.digest = abi.encodePacked(keccak256(payload));
        item.byteSize = uint64(payload.length);
        item.provenanceHash = O.recordOriginHash(fact);
        _segment();
        O.Origin[] memory origins = new O.Origin[](2);
        origins[0] = captured.selection.origin;
        origins[1] = fact.producer;
        _origins(origins);
        _fact(fact);
        _seal(captured.selection.selectionHash);
    }

    function _fact(O.RecordOrigin memory fact) private {
        inventory.set(
            abi.encodeWithSignature(
                "artistArchiveOrigin(bytes32,bytes32)", PLAN, Chains.itemHash(item)
            ),
            abi.encode(fact)
        );
    }

    function testFixedProfilesExposeReadCapabilitiesAndPreserveOriginalArchivePin() public {
        require(coverage.INVENTORY_PROFILE() == D.PRESERVATION_POLICY_INVENTORY_PROFILE);
        require(
            coverage.PROFILE()
                == CurrentEnvironment.coverageProfile(D.PRESERVATION_POLICY_INVENTORY_PROFILE)
        );
        require(coverage.preservationPolicyBundleArchiveProfile() == coverage.PROFILE());
        require(coverage.supportsInterface(type(BaseCoverage).interfaceId));
        require(coverage.supportsInterface(type(CurrentCoverage).interfaceId));
        require(coverage.supportsInterface(0x01ffc9a7) && !coverage.supportsInterface(0xffffffff));
        require(!coverage.supportsInterface(type(CollectionInventory).interfaceId));
        require(coverage.dependencies().targets[5] == sd.artistTargets[4]);
        require(
            coverage.dependencyHash()
                == keccak256(
                    abi.encode(
                        coverage.PROFILE(), D.PRESERVATION_POLICY_INVENTORY_PROFILE, bd, od, ad
                    )
                )
        );
        require(_complete().bundleCoverageHash != 0);
    }

    function testMissingOrMalformedCapabilitiesAndWrongProfileCannotBegin() public {
        bytes4[4] memory required = [
            bytes4(0x01ffc9a7),
            type(CollectionInventory).interfaceId,
            type(OriginInventory).interfaceId,
            type(CapturedInventory).interfaceId
        ];
        for (uint256 i; i < required.length; ++i) {
            inventory.set(
                abi.encodeCall(IERC165.supportsInterface, (required[i])), abi.encode(false)
            );
            _fails(address(coverage), abi.encodeCall(coverage.beginCoverage, (PLAN)));
            inventory.set(
                abi.encodeCall(IERC165.supportsInterface, (required[i])), abi.encode(true)
            );
        }
        inventory.set(
            abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))), abi.encode(true)
        );
        _fails(address(coverage), abi.encodeCall(coverage.beginCoverage, (PLAN)));
        inventory.set(
            abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))), abi.encode(false)
        );
        inventory.set(
            abi.encodeWithSignature("preservationPolicyInventoryProfile()"),
            abi.encode(D.POLICY_INVENTORY_PROFILE)
        );
        _fails(address(coverage), abi.encodeCall(coverage.beginCoverage, (PLAN)));
        require(coverage.progress(PLAN).itemCount == 0);
    }

    function testOldCoverageConstructorsStillRefusePreservationProfiles() public {
        bool accepted;
        try new PriorCollectionCoverage(bd, od, ad, D.PRESERVATION_POLICY_INVENTORY_PROFILE) {
            accepted = true;
        } catch { }
        require(!accepted);
        try new PriorScopedCoverage(bd, od, ad, D.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE) {
            accepted = true;
        } catch { }
        require(!accepted);
    }

    function testSealRequiresExactCurrentCaptureAndFullDependencyHash() public {
        _seal(keccak256("wrong capture"));
        _fails(address(coverage), abi.encodeCall(coverage.beginCoverage, (PLAN)));
        _seal(captured.selection.selectionHash);
        inventory.set(
            abi.encodeWithSignature("dependencyHash()"), abi.encode(keccak256("base-only hash"))
        );
        _fails(address(coverage), abi.encodeCall(coverage.beginCoverage, (PLAN)));
        _profile(false);
        require(_complete().bundleCoverageHash != 0);
    }

    function testLaterAuthorityExpiresCurrentPathsButKeepsHistoricalCoverage() public {
        T.BundleEvidence memory saved = _complete();
        _select(address(new FinalityMultiOriginReadTable()));
        require(
            keccak256(abi.encode(coverage.bundleEvidence(PLAN))) == keccak256(abi.encode(saved))
        );
        _fails(
            address(coverage),
            abi.encodeCall(coverage.requireCoverage, (PLAN, evidence.renderCriticalEvidenceHash))
        );
        _fails(address(coverage), abi.encodeCall(coverage.beginRefresh, (PLAN)));
        _fails(address(coverage), abi.encodeCall(coverage.requireFullCurrentCoverage, (PLAN)));
    }

    function testOriginalArchiveRoutingJoinsCertifiedBytesAndOriginHash() public {
        (MultiOriginCoverageArchiveBoundary archive, O.RecordOrigin memory fact) = _stateItem();
        require(address(archive) != coverage.dependencies().targets[5]);
        T.BundleEvidence memory saved = _complete();
        require(coverage.admittedOriginHash(PLAN, 0) == O.recordOriginHash(fact));
        require(
            coverage.requireFullCurrentCoverage(PLAN).bundleCoverageHash == saved.bundleCoverageHash
        );
        _epoch(2);
        _fails(
            address(coverage),
            abi.encodeCall(coverage.requireCoverage, (PLAN, evidence.renderCriticalEvidenceHash))
        );
        bytes32 refreshId = coverage.beginRefresh(PLAN);
        coverage.refreshNext(PLAN, 0);
        require(coverage.refresh(refreshId).complete);
        require(
            coverage.requireCoverage(PLAN, evidence.renderCriticalEvidenceHash).bundleCoverageHash
                == saved.bundleCoverageHash
        );
    }

    function testWrongCapsuleCannotAdvanceAndExactRetrySucceeds() public {
        (, O.RecordOrigin memory fact) = _stateItem();
        coverage.beginCoverage(PLAN);
        O.RecordOrigin memory wrong = abi.decode(abi.encode(fact), (O.RecordOrigin));
        wrong.sourceContextHash = keccak256("unrelated capture");
        _fact(wrong);
        _fails(
            address(coverage),
            abi.encodeCall(coverage.coverNext, (PLAN, item, bytes32(0), B.Proof(0, 0, 0)))
        );
        require(coverage.progress(PLAN).itemCount == 0);
        _fact(fact);
        coverage.coverNext(PLAN, item, 0, B.Proof(0, 0, 0));
        require(
            coverage.requireCoverage(PLAN, evidence.renderCriticalEvidenceHash).bundleCoverageHash
                != 0
        );
    }

    function testFullDiagnosticAndRefreshRecheckCapsuleAndStopBytes() public {
        (MultiOriginCoverageArchiveBoundary archive, O.RecordOrigin memory fact) = _stateItem();
        T.BundleEvidence memory saved = _complete();
        fact.semanticRecordHash = keccak256("artificial changed certificate");
        _fact(fact);
        _fails(address(coverage), abi.encodeCall(coverage.requireFullCurrentCoverage, (PLAN)));
        _epoch(2);
        coverage.beginRefresh(PLAN);
        _fails(address(coverage), abi.encodeCall(coverage.refreshNext, (PLAN, uint64(0))));
        fact.semanticRecordHash = keccak256("exact original semantic record");
        _fact(fact);
        vm.etch(archive.pointer(item.sourceRecord), hex"00");
        _fails(address(coverage), abi.encodeCall(coverage.requireFullCurrentCoverage, (PLAN)));
        _fails(address(coverage), abi.encodeCall(coverage.refreshNext, (PLAN, uint64(0))));
        require(coverage.bundleEvidence(PLAN).bundleCoverageHash == saved.bundleCoverageHash);
    }

    function testUnknownOrReorderedOriginSetCannotReuseCoverage() public {
        _stateItem();
        _complete();
        inventory.set(
            abi.encodeWithSignature("originSetHash(bytes32)", PLAN),
            abi.encode(keccak256("reordered origins"))
        );
        _fails(
            address(coverage),
            abi.encodeCall(coverage.requireCoverage, (PLAN, evidence.renderCriticalEvidenceHash))
        );
        _fails(address(coverage), abi.encodeCall(coverage.beginRefresh, (PLAN)));
    }

    function testScopedPreservationUsesExactTypedScopeAndDistinctDomains() public {
        _profile(true);
        ScopedCoverage scoped = new ScopedCoverage(bd, od, ad);
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 42, 0);
        evidence.scopeSubject =
            StreamMetadataSubjects.scopeSubject(block.chainid, bd.targets[0], scope);
        evidence.renderCriticalEvidenceHash = 0;
        Scoped.Evidence memory full = Scoped.Evidence(scope, evidence);
        full.inventory.renderCriticalEvidenceHash = keccak256(
            abi.encode(
                D.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE,
                block.chainid,
                address(inventory),
                c.inventoryDependencyHash,
                captured.selection.selectionHash,
                full,
                originRoot,
                originCount
            )
        );
        inventory.set(abi.encodeWithSignature("inventoryEvidence(bytes32)", PLAN), abi.encode(full));
        require(scoped.PROFILE() != coverage.PROFILE());
        require(
            scoped.PROFILE()
                == CurrentEnvironment.coverageProfile(
                    D.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE
                )
        );
        require(scoped.supportsInterface(type(BaseScopedCoverage).interfaceId));
        require(scoped.supportsInterface(type(StandardScopedCoverage).interfaceId));
        require(scoped.supportsInterface(type(CurrentCoverage).interfaceId));
        require(!scoped.supportsInterface(type(OldScopedWriter).interfaceId));
        require(!scoped.supportsInterface(0xffffffff));
        scoped.beginCoverage(PLAN);
        scoped.coverNext(PLAN, item, 0, B.Proof(0, 0, 0));
        ScopedBundle.BundleEvidence memory saved =
            scoped.requireCoverage(scope, PLAN, full.inventory.renderCriticalEvidenceHash);
        require(saved.coverage.bundleCoverageHash != 0);
        StreamFinalityScope memory wrong = abi.decode(abi.encode(scope), (StreamFinalityScope));
        wrong.tokenId += 1;
        _fails(
            address(scoped),
            abi.encodeCall(
                scoped.requireCoverage, (wrong, PLAN, full.inventory.renderCriticalEvidenceHash)
            )
        );
        _select(address(new FinalityMultiOriginReadTable()));
        require(
            scoped.bundleEvidence(PLAN).coverage.bundleCoverageHash
                == saved.coverage.bundleCoverageHash
        );
        _fails(address(scoped), abi.encodeCall(scoped.requireFullCurrentCoverage, (PLAN)));
        _fails(address(scoped), abi.encodeCall(scoped.beginRefresh, (PLAN)));
    }
}
