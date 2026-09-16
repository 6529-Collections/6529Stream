// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../metadata/StreamConservationSelectionFixture.sol";
import {
    StreamReferenceModeCurated
} from "../../../smart-contracts/domains/preservation/StreamReferenceModeCurated.sol";
import {
    StreamReferenceModeTypes as Mode
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceModeTypes.sol";
import {
    StreamReferenceRenderTypes as Ref
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamReferenceModeDefinitions as Def
} from "../../../smart-contracts/domains/records/StreamReferenceModeDefinitions.sol";
import {
    StreamCollectionAttestations
} from "../../../smart-contracts/domains/metadata/StreamCollectionAttestations.sol";
import {
    IStreamCollectionAttestations as Independent
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionAttestations.sol";
import {
    StreamReferenceModeInventory
} from "../../../smart-contracts/domains/preservation/StreamReferenceModeInventory.sol";
import {
    StreamPreservationInventoryChains
} from "../../../smart-contracts/domains/preservation/StreamPreservationInventoryChains.sol";
import {
    StreamRenderCriticalSourceTypes as Critical
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as Inventory
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    IStreamReferenceModePublication as ModeHost
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamReferenceModePublication.sol";
import {
    StreamExternalArtifactTypes as E
} from "../../../smart-contracts/interfaces/stream/preservation/StreamExternalArtifactTypes.sol";

contract CuratedModeSourceProbe {
    bytes private _evidence;
    Mode.Dependencies private _bindings;

    function observe(bytes calldata canonicalPair, Mode.Dependencies memory b) external {
        _evidence = canonicalPair;
        _bindings = b;
    }

    function referenceModeEvidence(bytes32)
        external
        view
        returns (Mode.Evidence memory, Mode.Facts memory)
    {
        bytes memory raw = _evidence;
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }

    function modeDependencies() external view returns (Mode.Dependencies memory) {
        return _bindings;
    }

    function inventory(Critical.Dependencies memory d, Critical.Context memory c)
        external
        view
        returns (Inventory.Item[] memory rows)
    {
        (, rows) = StreamReferenceModeInventory.stage(d, c, 1);
    }

    function validate(
        Ref.Dependencies memory d,
        Mode.Dependencies memory bindings,
        Ref.Publication memory p,
        Ref.SourceFacts memory source,
        Mode.Curated memory witness,
        bytes32 context
    ) external view returns (bytes32, bytes32) {
        return StreamReferenceModeCurated.requireEvidence(d, bindings, p, source, witness, context);
    }
}

/// @notice Actual Metadata intent publication/selection and original EIP712/ERC1271 condition records.
/// @dev Original Artist op24 and Core are the named typed boundaries inherited from the fixture.
/// This is the curated-source proof, not a whole native snapshot/browser/finality deployment.
contract StreamReferenceModeCuratedTest is ConservationSelectionFixture {
    StreamCollectionAttestations private independent;
    CuratedModeSourceProbe private probe;
    Mode.Curated private witness;
    Mode.Dependencies private bindings;
    Ref.Dependencies private deps;
    Ref.Publication private publication;
    Ref.SourceFacts private facts;
    uint256 private constant EXAMINER_KEY = 0x617161;
    bytes32 private constant CONTEXT =
        keccak256("exact fixture capture/source/environment context");

    function _setupCurated() private {
        _prepare();
        _bound();
        _registerDocument(
            "STREAM_SOLIDITY_ABI_V1",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(Def.CANON_DOCUMENT),
            schemas.RAW_BYTES()
        );
        _registerDocument(
            "STREAM_REFERENCE_CURATED_CONDITION_ABI_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(Def.CONDITION_DOCUMENT),
            schemas.RAW_BYTES()
        );
        _registerDocument(
            "STREAM_REFERENCE_SIGNIFICANT_PROPERTIES_ABI_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(Def.PROPERTIES_DOCUMENT),
            schemas.RAW_BYTES()
        );
        _registerDocument(
            "STREAM_REFERENCE_MODE_ABI_V2",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(Def.DECODE_DOCUMENT),
            schemas.RAW_BYTES()
        );
        StreamCollectionAttestations.Configuration memory c;
        c.core = address(core);
        c.schemas = address(schemas);
        c.executor = address(executor);
        c.deploymentManifestHash = keccak256("condition fixture deployment");
        c.manifestHash = keccak256("condition fixture manifest");
        c.manifestURI = "ipfs://condition-fixture";
        c.signatureGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ERC1271_VERIFY_GAS", 400000, 90000, 2
        );
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 500000, 50000, 2
        );
        independent = new StreamCollectionAttestations(c);
        probe = new CuratedModeSourceProbe();
        witness.intent = _intent();
        witness.properties
            .push(
                Mode.Property(
                    keccak256("color"), "Color", "Preserve the artist's saturated red field"
                )
            );
        witness.properties
            .push(Mode.Property(keccak256("timing"), "Timing", "Preserve one still frame"));
        witness.intent.significantProperties = StreamConservationRecordTypes.Reference(
            1,
            Def.CANON_ID,
            abi.encode(keccak256(abi.encode(witness.properties))),
            "ipfs://complete-properties"
        );
        (bytes32 original,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(witness.intent),
            1
        );
        IStreamConservationRecordSelection.Selection memory picked = selection.adoptIntent(
            1, subject, original, 0, 0, _intentWitness(original, witness.intent)
        );
        witness.intentRecordHash = original;
        witness.intentRevision = 1;
        witness.condition.contextHash = CONTEXT;
        witness.condition.intentRecordHash = original;
        witness.condition.intentSelectionHash = picked.selectionHash;
        witness.condition.propertiesHash = keccak256(abi.encode(witness.properties));
        witness.condition.examiner = vm.addr(EXAMINER_KEY);
        witness.condition.examinerName = "Named test examiner";
        witness.condition.institution = _ref("ipfs://attributed-test-institution");
        witness.condition.credentials = _ref("ipfs://attributed-test-credential");
        witness.condition.examinedAt = uint64(block.timestamp);
        witness.condition.assessments
            .push(
                Mode.Assessment(
                    witness.properties[0].id, true, "Test examination preserves red field"
                )
            );
        witness.condition.assessments
            .push(
                Mode.Assessment(
                    witness.properties[1].id, true, "Test examination retains still frame"
                )
            );
        deps.targets[0] = address(core);
        deps.targets[1] = address(metadata);
        deps.targets[2] = address(schemas);
        deps.targets[3] = address(store);
        deps.chainId = block.chainid;
        deps.readGas = 500000;
        deps.sourceGas = 3000000;
        deps.snapshotGas = 10000000;
        bindings = Mode.Dependencies(
            address(independent),
            address(independent).codehash,
            address(selection),
            address(selection).codehash
        );
        publication.collectionId = 1;
        publication.effectiveAt = uint64(block.timestamp);
        publication.captures = new Ref.Capture[](1);
        publication.captures[0].capturedAt = uint64(block.timestamp);
        facts.subject = subject;
        facts.artistId = ARTIST_ID;
    }

    function _request(uint256 nonce)
        private
        view
        returns (Independent.Subject memory s, Independent.IndependentRecord memory r)
    {
        s = Independent.Subject(Independent.SubjectKind.COLLECTION, 1, 0, 0);
        r.attestor = witness.condition.examiner;
        r.scopeKey = 1;
        r.subjectId = independent.deriveSubject(s);
        r.recordType = keccak256("INDEPENDENT_CONDITION");
        require(r.subjectId == subject);
        r.schemaId = Def.CONDITION_ID;
        r.algorithmId = 1;
        r.payload = abi.encode(witness.condition);
        r.digest = abi.encode(keccak256(r.payload));
        r.canonicalizationId = Def.CANON_ID;
        r.uri = "ipfs://signed-examination";
        r.effectiveAt = uint64(block.timestamp);
        r.nonce = nonce;
        r.deadline = uint64(block.timestamp + 1000);
    }

    function _signAndRecord(uint256 nonce) private {
        (Independent.Subject memory s, Independent.IndependentRecord memory r) = _request(nonce);
        bytes32 digest = independent.independentRecordDigest(r);
        (uint8 v, bytes32 rs, bytes32 ss) = vm.sign(EXAMINER_KEY, digest);
        witness.conditionRecordHash =
            independent.recordIndependentPreservation(s, r, abi.encodePacked(rs, ss, v));
    }

    function _validate(Mode.Curated memory w) private view returns (bytes32, bytes32) {
        return probe.validate(deps, bindings, publication, facts, w, CONTEXT);
    }

    function testActualSignedConditionAndSelectedOriginalIntentIncludesFirstIndexZero() public {
        _setupCurated();
        _signAndRecord(1);
        (, Independent.Receipt memory receipt) =
            independent.collectionRecord(witness.conditionRecordHash);
        require(receipt.recordIndex == 0);
        (bytes32 selected, bytes32 originalReceipt) = _validate(witness);
        require(
            selected == witness.condition.intentSelectionHash
                && originalReceipt == keccak256(abi.encode(receipt))
        );
    }

    function testCuratedInventoryRetainsBothSignedReferencesAndOmissionChangesCommitment() public {
        _setupCurated();
        _signAndRecord(1);
        (bytes32 selected, bytes32 receiptHash) = _validate(witness);
        _registerDocument(
            "STREAM_REFERENCE_MODE_ABI_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(Def.SCHEMA_DOCUMENT),
            schemas.RAW_BYTES()
        );
        _registerDocument(
            "STREAM_REFERENCE_MODE_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            bytes(Def.PROFILE_DOCUMENT),
            schemas.RAW_BYTES()
        );

        // Only the mode-publication observation is a typed boundary here. The condition,
        // signed references, original receipt/payload/signature and definitions are actual.
        Mode.Evidence memory evidence;
        evidence.mode = Mode.Mode.CURATED_EQUIVALENCE;
        evidence.curated = witness;
        evidence.repeats = new Mode.Repeat[](1);
        Mode.Facts memory mode;
        mode.mode = evidence.mode;
        mode.evidenceHash = keccak256(abi.encode(evidence));
        mode.conditionRecordHash = witness.conditionRecordHash;
        mode.conditionReceiptHash = receiptHash;
        mode.intentSelectionHash = selected;
        mode.repeats = new E.Coverage[](1);
        Critical.Dependencies memory d;
        d.targets[2] = address(schemas);
        d.targets[3] = address(store);
        d.targets[6] = address(probe);
        d.targets[9] = address(selection);
        d.codeHashes[2] = address(schemas).codehash;
        d.codeHashes[3] = address(store).codehash;
        d.codeHashes[9] = address(selection).codehash;
        d.readGas = 1000000;
        d.sourceGas = 3000000;
        d.referenceGas = 3000000;
        Critical.Context memory c;
        c.referenceRender.recordHash = keccak256("typed original mode reference");
        c.conservation.selectionHash = selected;
        c.conservation.record.recordHash = witness.intentRecordHash;
        probe.observe(abi.encode(evidence, mode), bindings);
        Inventory.Item[] memory rows = probe.inventory(d, c);
        require(rows.length == 15);
        for (uint256 i; i < 2; ++i) {
            Inventory.Item memory row = rows[12 + i];
            StreamConservationRecordTypes.Reference memory ref =
                i == 0 ? witness.condition.institution : witness.condition.credentials;
            require(row.kind == Inventory.Kind.EXTERNAL_REFERENCE);
            require(
                row.source == address(independent)
                    && row.sourceRecord == witness.conditionRecordHash
            );
            require(
                row.algorithm == ref.algorithm && row.canonicalizationId == ref.canonicalizationId
            );
            require(
                keccak256(row.digest) == keccak256(ref.digest)
                    && keccak256(bytes(row.uri)) == keccak256(bytes(ref.uri))
            );
            require(
                row.role
                    == (i == 0
                            ? keccak256("CURATED_EXAMINER_INSTITUTION")
                            : keccak256("CURATED_EXAMINER_CREDENTIALS"))
            );
            require(row.byteSize == 0 && row.originalCoverageHash == 0);
        }
        bytes32 key = keccak256("REFERENCE");
        Inventory.Segment memory complete =
            StreamPreservationInventoryChains.segment(key, mode.evidenceHash, rows);
        Inventory.Item[] memory omitted = new Inventory.Item[](13);
        for (uint256 i; i < 12; ++i) {
            omitted[i] = rows[i];
        }
        omitted[12] = rows[14];
        Inventory.Segment memory missing =
            StreamPreservationInventoryChains.segment(key, mode.evidenceHash, omitted);
        require(
            complete.itemCount == 15 && missing.itemCount == 13
                && complete.firstLink != missing.firstLink
        );
        rows[13].digest = abi.encode(keccak256("substituted credential"));
        Inventory.Segment memory substituted =
            StreamPreservationInventoryChains.segment(key, mode.evidenceHash, rows);
        require(
            substituted.itemCount == complete.itemCount
                && substituted.firstLink != complete.firstLink
        );
    }

    function testCompletePropertiesOrderEveryFieldAndContextAreRequired() public {
        _setupCurated();
        _signAndRecord(1);
        Mode.Curated memory w = witness;
        w.properties = new Mode.Property[](1);
        w.properties[0] = witness.properties[0];
        vm.expectRevert();
        _validate(w);
        w = witness;
        w.condition.assessments[1].propertyId = witness.properties[0].id;
        vm.expectRevert();
        _validate(w);
        w = witness;
        w.condition.contextHash = keccak256("other source");
        vm.expectRevert();
        _validate(w);
        w = witness;
        w.condition.examinerName = "same wallet, invented examiner name";
        vm.expectRevert();
        _validate(w);
    }

    function testNegativeAssessmentAndMissingCredentialCannotBeSuccess() public {
        _setupCurated();
        witness.condition.assessments[0].conforms = false;
        _signAndRecord(1);
        vm.expectRevert();
        _validate(witness);
        witness.condition.assessments[0].conforms = true;
        delete witness.condition.credentials;
        _signAndRecord(2);
        vm.expectRevert();
        _validate(witness);
    }

    function testOperatorDirectAssertionCannotReplaceVerifiedSignature() public {
        _setupCurated();
        (Independent.Subject memory s, Independent.IndependentRecord memory r) = _request(1);
        vm.prank(r.attestor);
        witness.conditionRecordHash = independent.recordIndependentPreservation(s, r, bytes(""));
        vm.expectRevert();
        _validate(witness);
    }

    function testActualThresholdSafeSignedConditionRetainsOriginalAuthorityAfterNonceChange()
        public
    {
        _setupCurated();
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x191;
        keys[1] = 0x192;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 192);
        witness.condition.examiner = address(account);
        (Independent.Subject memory s, Independent.IndependentRecord memory r) = _request(7);
        bytes32 digest = independent.independentRecordDigest(r);
        bytes memory signature =
            safeThresholdSignature(keys, safeMessageDigest(account, abi.encode(digest)));
        witness.conditionRecordHash = independent.recordIndependentPreservation(s, r, signature);
        (bytes32 selected,) = _validate(witness);
        require(selected != 0 && account.nonce() == 0);
        require(
            executeSafe(
                account,
                keys,
                address(independent),
                0,
                abi.encodeCall(independent.revokeIndependentAttestorNonce, (uint256(99))),
                0
            )
        );
        (bytes32 retained,) = _validate(witness);
        require(retained == selected && account.nonce() == 1);
    }
}
