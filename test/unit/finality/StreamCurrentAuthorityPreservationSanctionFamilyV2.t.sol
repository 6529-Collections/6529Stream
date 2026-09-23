// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityPreservationPolicySanctionReviewV1 as CollectionReview
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityPreservationPolicySanctionReviewV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicySanctionReviewV1 as ScopedReview
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityScopedPreservationPolicySanctionReviewV1.sol";
import {
    StreamCurrentAuthorityPresentation as Presentation
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityPresentation.sol";
import {
    StreamFinalityNativeProviderReads as Native
} from "../../../smart-contracts/domains/finality/StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityScopedPreservationPolicyProviderReadsV1 as Scoped
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPreservationPolicyProviderReadsV1.sol";
import {
    StreamFinalityPreservationPolicyInputManifestTypesV1 as CollectionManifest
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityPreservationPolicyInputManifestTypesV1.sol";
import {
    StreamFinalityScopedPreservationPolicyInputManifestTypesV1 as ScopedManifest
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityScopedPreservationPolicyInputManifestTypesV1.sol";
import {
    StreamFinalityPreservationPolicyReferenceReadsV1 as CollectionReads
} from "../../../smart-contracts/domains/finality/StreamFinalityPreservationPolicyReferenceReadsV1.sol";
import {
    StreamFinalityScopedPreservationPolicyReferenceReadsV1 as ScopedReads
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPreservationPolicyReferenceReadsV1.sol";
import {
    StreamPreservationPolicyReferenceTypesV1 as Reference
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationPolicyReferenceTypesV1.sol";
import {
    StreamReferenceRenderTypes as Render
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamPreservationPolicyReferenceFamiliesV2 as Families
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyReferenceFamiliesV2.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Profiles
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    StreamCurrentAuthorityInventoryTypes as Inventory
} from "../../../smart-contracts/interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamMetadataSubjects as Subjects
} from "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import {
    StreamExternalArtifactTypes as External
} from "../../../smart-contracts/interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import {
    StreamReferenceRenderDefinitions as Definitions
} from "../../../smart-contracts/domains/records/StreamReferenceRenderDefinitions.sol";
import {
    IStreamFinalitySanctionReview as Review
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalitySanctionReview.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamFinalityScopeInputs
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityEvidenceTypes.sol";

interface SanctionFamilyVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
    function expectRevert(bytes calldata data) external;
    function warp(uint256 timestamp) external;
}

/// @dev Explicit typed read boundary, not a real publisher, archive, or Artist registry.
contract SanctionFamilyReadBoundary {
    mapping(bytes32 => bytes) private replies;

    function put(bytes calldata input, bytes calldata output) external {
        replies[keccak256(input)] = output;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id != 0xffffffff;
    }

    fallback(bytes calldata input) external returns (bytes memory output) {
        output = replies[keccak256(input)];
        require(output.length != 0, "unconfigured typed read");
    }
}

/// @notice Real sanction review + original-reference readers, with synthetic published records.
/// @dev The exact Presentation.artist call is mocked. Source admission, current ancestry,
/// reference publication, archival coverage, and the full Finality ceremony are not proved here.
/// The boundary supplies canonical dependencies/receipts; actual reader profile, definition,
/// record-domain, head equality and PNG identity/repeat checks execute without reader mocks.
contract StreamCurrentAuthorityPreservationSanctionFamilyV2Test {
    SanctionFamilyVm private constant vm =
        SanctionFamilyVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant ARTIST = keccak256("synthetic admitted artist boundary");
    bytes32 private constant ROOT = keccak256("synthetic admitted content root boundary");

    struct Fixture {
        SanctionFamilyReadBoundary boundary;
        Native.Config config;
        StreamFinalityScope scope;
        StreamFinalityScopeInputs inputs;
        Reference.Publication publication;
        Reference.Receipt receipt;
        External.ObjectIdentity png;
    }

    function testCollectionV2ReviewReturnsExactOriginalPngAndLegacyReaderStaysStrict() public {
        Fixture memory f = _fixture(StreamFinalityScopeType.COLLECTION);
        _assertReviewed(f);
        CollectionReads.Dependencies memory d = _collectionDependencies(f);
        vm.expectRevert(
            abi.encodeWithSelector(CollectionReads.InvalidPolicyReferenceEvidence.selector)
        );
        CollectionReads.original(d, f.scope, f.receipt.observation.recordHash, 1);
    }

    function testTokenReleaseSeasonV2ReviewsReturnTheirExactOriginalPng() public {
        for (uint8 kind = 1; kind <= 3; ++kind) {
            Fixture memory f = _fixture(StreamFinalityScopeType(kind));
            _assertReviewed(f);
            ScopedReads.Dependencies memory d = _scopedDependencies(f);
            vm.expectRevert(
                abi.encodeWithSelector(
                    ScopedReads.InvalidScopedPreservationPolicyReferenceEvidence.selector
                )
            );
            ScopedReads.original(d, f.scope, f.receipt.observation.recordHash, 1);
        }
    }

    function testBothWorkersRejectV1HostProfileAndIdenticalV2RetrySucceeds() public {
        for (uint8 kind; kind < 2; ++kind) {
            Fixture memory f = _fixture(StreamFinalityScopeType(kind));
            _profile(f, Profiles.ORIGINAL_PROFILE);
            _expectReferenceFailure(f);
            _profile(f, Profiles.FAMILY_PROFILE);
            _assertReviewed(f);
        }
    }

    function testBothWorkersRejectV1DefinitionReceiptUnderV2Host() public {
        for (uint8 kind; kind < 2; ++kind) {
            Fixture memory f = _fixture(StreamFinalityScopeType(kind));
            Families.Definition memory old =
                Families.definition(Profiles.ORIGINAL_PROFILE, kind != 0);
            f.receipt.observation.schemaHash = old.schemaHash;
            f.receipt.observation.profileHash = old.profileHash;
            f.receipt.observation.canonicalizationHash = old.canonHash;
            _sealReceipt(f, Profiles.FAMILY_PROFILE);
            _writeRecords(f);
            _expectReferenceFailure(f);
        }
    }

    function testBothWorkersRejectOriginalRecordDomainWithV2Definitions() public {
        for (uint8 kind; kind < 2; ++kind) {
            Fixture memory f = _fixture(StreamFinalityScopeType(kind));
            _sealReceipt(f, Profiles.ORIGINAL_PROFILE);
            _writeRecords(f);
            _expectReferenceFailure(f);
        }
    }

    function testBothWorkersRejectCrossedCollectionScopedDefinitionFamilies() public {
        for (uint8 kind; kind < 2; ++kind) {
            Fixture memory f = _fixture(StreamFinalityScopeType(kind));
            Families.Definition memory crossed =
                Families.definition(Profiles.FAMILY_PROFILE, kind == 0);
            f.receipt.observation.schemaHash = crossed.schemaHash;
            f.receipt.observation.profileHash = crossed.profileHash;
            f.receipt.observation.canonicalizationHash = crossed.canonHash;
            _sealReceipt(f, Profiles.FAMILY_PROFILE);
            _writeRecords(f);
            _expectReferenceFailure(f);
        }
    }

    function testBothWorkersStillRejectUnequalRepeatedPngBytes() public {
        for (uint8 kind; kind < 2; ++kind) {
            Fixture memory f = _fixture(StreamFinalityScopeType(kind));
            f.publication.observation.captures[0].repeatCaptureSha256[1] ^= bytes32(uint256(1));
            _sealReceipt(f, Profiles.FAMILY_PROFILE);
            _writeRecords(f);
            bytes4 error_ = kind == 0
                ? CollectionReview.NativeReviewSource.selector
                : ScopedReview.NativeReviewSource.selector;
            vm.expectRevert(abi.encodeWithSelector(error_));
            this.review(f);
        }
    }

    function testBothWorkersStillRejectOriginalReceiptDifferentFromCurrentHead() public {
        for (uint8 kind; kind < 2; ++kind) {
            Fixture memory f = _fixture(StreamFinalityScopeType(kind));
            Reference.Receipt memory head = abi.decode(abi.encode(f.receipt), (Reference.Receipt));
            head.observation.recordChainHash = keccak256("different saved head");
            f.boundary
                .put(
                    abi.encodeWithSignature(
                        "currentReference((uint8,uint256,uint256,bytes32))", f.scope
                    ),
                    abi.encode(head)
                );
            bytes4 error_ = kind == 0
                ? CollectionReview.NativeReviewSource.selector
                : ScopedReview.NativeReviewSource.selector;
            vm.expectRevert(abi.encodeWithSelector(error_));
            this.review(f);
        }
    }

    function review(Fixture memory f) external view returns (Review.ReviewFacts memory) {
        require(msg.sender == address(this), "test self call");
        if (f.scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            CollectionManifest.Statement memory statement;
            statement.scope = f.scope;
            statement.contentRoot = ROOT;
            statement.inputs = f.inputs;
            statement.referenceRenderManifestHash = f.receipt.observation.payloadHash;
            statement.entropy.referenceProfileHash = f.receipt.observation.profileHash;
            return CollectionReview.review(f.config, statement);
        }
        ScopedManifest.Statement memory scoped;
        scoped.scope = f.scope;
        scoped.contentRoot = ROOT;
        scoped.inputs = f.inputs;
        scoped.referenceRenderManifestHash = f.receipt.observation.payloadHash;
        return ScopedReview.review(abi.decode(abi.encode(f.config), (Scoped.Config)), scoped);
    }

    function _assertReviewed(Fixture memory f) private view {
        Review.ReviewFacts memory result = this.review(f);
        require(result.schemaVersion == 1 && result.profile == 1 && result.contentRoot == ROOT);
        require(
            result.mediaContentHashes.length == 0 && result.referenceRenderContentHashes.length == 1
        );
        require(result.referenceRenderContentHashes[0] == f.png.contentHash);
    }

    function _expectReferenceFailure(Fixture memory f) private {
        bytes4 error_ = f.scope.scopeType == StreamFinalityScopeType.COLLECTION
            ? CollectionReads.InvalidPolicyReferenceEvidence.selector
            : ScopedReads.InvalidScopedPreservationPolicyReferenceEvidence.selector;
        vm.expectRevert(abi.encodeWithSelector(error_));
        this.review(f);
    }

    function _fixture(StreamFinalityScopeType kind) private returns (Fixture memory f) {
        vm.warp(100);
        f.boundary = new SanctionFamilyReadBoundary();
        for (uint256 i; i < 22; ++i) {
            f.config.targets[i] = address(f.boundary);
            f.config.codeHashes[i] = address(f.boundary).codehash;
        }
        f.config.chainId = block.chainid;
        f.config.readGas = 500000;
        f.config.sourceGas = 4000000;
        f.config.componentSourceGas = 2000000;
        f.config.inventoryDependencyHash = keccak256("synthetic captured dependency boundary");
        f.scope =
            StreamFinalityScope(kind, 1, kind == StreamFinalityScopeType.TOKEN ? 7 : 0, bytes32(0));
        if (kind == StreamFinalityScopeType.RELEASE || kind == StreamFinalityScopeType.SEASON) {
            f.scope.scopeId = keccak256(abi.encode(kind));
        }
        Reference.Dependencies memory d;
        for (uint256 i; i < 7; ++i) {
            d.targets[i] = address(f.boundary);
            d.codeHashes[i] = address(f.boundary).codehash;
        }
        d.chainId = block.chainid;
        d.readGas = f.config.readGas;
        d.sourceGas = f.config.sourceGas;
        d.snapshotGas = f.config.sourceGas;
        d.archiveGas = f.config.sourceGas;
        f.boundary.put(abi.encodeWithSignature("dependencies()"), abi.encode(d));
        _profile(f, Profiles.FAMILY_PROFILE);
        f.png = External.ObjectIdentity(
            ARTIST,
            Definitions.PNG_SCHEMA_ID,
            keccak256("RAW_BYTES"),
            keccak256("synthetic PNG content"),
            sha256("synthetic PNG content"),
            keccak256("synthetic native data root"),
            21,
            keccak256("IANA:image/png"),
            Definitions.FORMAT_CATALOG_ID,
            Definitions.FORMAT_CATALOG_HASH
        );
        bytes32 object = keccak256(
            abi.encode(
                keccak256("6529STREAM_EXTERNAL_OBJECT_V1"),
                block.chainid,
                address(f.boundary),
                address(f.boundary),
                f.png
            )
        );
        f.boundary
            .put(abi.encodeWithSignature("objectIdentity(bytes32)", object), abi.encode(f.png));
        f.publication.scope = f.scope;
        Render.Publication memory p = f.publication.observation;
        p.collectionId = 1;
        p.referenceId = keccak256("synthetic reference");
        p.snapshotRecordHash = keccak256("synthetic snapshot");
        p.snapshotRevision = 1;
        p.expectedSourcesHash = keccak256("synthetic admitted sources");
        p.effectiveAt = 100;
        p.reasonHash = keccak256("synthetic reason");
        p.captures = new Render.Capture[](1);
        p.captures[0].objectHash = object;
        p.captures[0].coverageHash = keccak256("synthetic coverage boundary");
        p.captures[0].repeatCaptureSha256 = [f.png.sha256Digest, f.png.sha256Digest];
        f.publication.observation = p;
        f.receipt.scopeSubject = Subjects.scopeSubject(block.chainid, address(f.boundary), f.scope);
        Render.Receipt memory r;
        r.collectionId = 1;
        r.referenceId = p.referenceId;
        r.revision = 1;
        r.payloadHash = keccak256("synthetic retained reference bytes");
        r.payloadBytes = 34;
        r.sourcesHash = p.expectedSourcesHash;
        r.snapshotRecordHash = p.snapshotRecordHash;
        r.snapshotRevision = 1;
        r.recorder = address(this);
        r.authorizationClass = 3;
        r.grantRevision = 1;
        r.effectiveAt = 100;
        r.recordedAt = 100;
        r.reasonHash = p.reasonHash;
        Families.Definition memory definition = Families.definition(
            Profiles.FAMILY_PROFILE, kind != StreamFinalityScopeType.COLLECTION
        );
        r.schemaHash = definition.schemaHash;
        r.profileHash = definition.profileHash;
        r.canonicalizationHash = definition.canonHash;
        f.receipt.observation = r;
        _sealReceipt(f, Profiles.FAMILY_PROFILE);
        _writeRecords(f);
    }

    function _profile(Fixture memory f, bytes32 family) private {
        bool scoped = f.scope.scopeType != StreamFinalityScopeType.COLLECTION;
        f.boundary
            .put(
                scoped
                    ? abi.encodeWithSignature("scopedPreservationPolicyReferenceProfile()")
                    : abi.encodeWithSignature("preservationPolicyReferenceProfile()"),
                abi.encode(Families.profile(family, scoped))
            );
    }

    function _sealReceipt(Fixture memory f, bytes32 family) private view {
        f.receipt.observation.recordHash = 0;
        f.receipt.observation.recordChainHash = 0;
        f.receipt.observation.recordHash = keccak256(
            abi.encode(
                Families.recordDomain(
                    family, f.scope.scopeType != StreamFinalityScopeType.COLLECTION
                ),
                block.chainid,
                f.config.targets[9],
                f.config.targets[0],
                f.config.targets[1],
                f.publication,
                f.receipt
            )
        );
        f.receipt.observation.recordChainHash = keccak256("synthetic immutable chain boundary");
        f.inputs.referenceRenderRecordHash = f.receipt.observation.recordHash;
        f.inputs.snapshotRecordHash = f.receipt.observation.snapshotRecordHash;
    }

    function _writeRecords(Fixture memory f) private {
        // Collection and scoped wrappers have the same exact nominally distinct ABI tuples.
        f.boundary
            .put(
                abi.encodeWithSignature(
                    "referenceRecord(bytes32)", f.receipt.observation.recordHash
                ),
                abi.encode(f.publication, f.receipt)
            );
        f.boundary
            .put(
                abi.encodeWithSignature(
                    "currentReference((uint8,uint256,uint256,bytes32))", f.scope
                ),
                abi.encode(f.receipt)
            );
        vm.mockCall(
            address(Presentation),
            abi.encodeWithSelector(
                Presentation.artist.selector,
                f.config.targets,
                f.config.codeHashes,
                f.config.chainId,
                f.config.readGas,
                f.config.inventoryDependencyHash,
                f.scope.scopeType == StreamFinalityScopeType.COLLECTION
                    ? Inventory.PRESERVATION_POLICY_INVENTORY_PROFILE
                    : Inventory.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE,
                f.scope,
                f.inputs
            ),
            abi.encode(ARTIST)
        );
    }

    function _collectionDependencies(Fixture memory f)
        private
        pure
        returns (CollectionReads.Dependencies memory d)
    {
        uint256[5] memory indexes = [uint256(0), 1, 2, 8, 9];
        for (uint256 i; i < 5; ++i) {
            d.targets[i] = f.config.targets[indexes[i]];
            d.codeHashes[i] = f.config.codeHashes[indexes[i]];
        }
        d.chainId = f.config.chainId;
        d.readGas = f.config.readGas;
        d.sourceGas = f.config.sourceGas;
    }

    function _scopedDependencies(Fixture memory f)
        private
        pure
        returns (ScopedReads.Dependencies memory)
    {
        return abi.decode(abi.encode(_collectionDependencies(f)), (ScopedReads.Dependencies));
    }
}
