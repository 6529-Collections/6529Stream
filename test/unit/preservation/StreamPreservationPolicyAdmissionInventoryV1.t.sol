// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamPreservationPolicyAdmissionInventoryV1 as AdmissionItems
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyAdmissionInventoryV1.sol";
import {
    StreamRenderCriticalSourceTypes as D
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    IStreamStaticSelectionCheckpoint as S
} from "../../../smart-contracts/interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as C
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    StreamPreservationPolicyOutputTypesV1 as P
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationPolicyOutputTypesV1.sol";
import {
    IStreamPreservationRegistryV1 as R
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamPreservationRegistryV1.sol";
import {
    IStreamRendererRegistry as V
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamSchemaDocumentFacts as F
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import {
    IStreamSchemaRegistry
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";

interface PreservationAdmissionInventoryVm {
    function etch(address target, bytes calldata code) external;
}

/// @dev Explicit read boundary permits malformed canonical returns and stable-runtime state drift.
contract PreservationAdmissionReadBoundary {
    mapping(bytes32 => bytes) private responses;

    function set(bytes calldata input, bytes calldata output) external {
        responses[keccak256(input)] = output;
    }

    fallback() external {
        bytes memory value = responses[keccak256(msg.data)];
        require(value.length != 0, "unconfigured original read");
        assembly ("memory-safe") { return(add(value, 32), mload(value)) }
    }
}

contract PreservationAdmissionInventoryProbe {
    function item(
        D.Dependencies calldata d,
        S.TokenSelection calldata s,
        C.Output calldata o,
        uint64 i
    ) external view returns (T.Item memory, uint64) {
        return AdmissionItems.item(d, s, o, i);
    }

    function itemForPlan(
        D.Dependencies calldata d,
        C.Plan calldata p,
        S.TokenSelection calldata s,
        C.Output calldata o,
        uint64 i
    ) external view returns (T.Item memory, uint64) {
        return AdmissionItems.itemForPlan(d, p, s, o, i);
    }
}

/// @notice Exercises the real inventory worker against explicit producer/Registry/document boundaries.
/// @dev The host's checkpoint authority and actual governed admission are composed-test obligations.
contract StreamPreservationPolicyAdmissionInventoryV1Test {
    PreservationAdmissionInventoryVm private constant vm =
        PreservationAdmissionInventoryVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    PreservationAdmissionInventoryProbe private probe;
    PreservationAdmissionReadBoundary private registry;
    PreservationAdmissionReadBoundary private producer;
    PreservationAdmissionReadBoundary private schemas;
    PreservationAdmissionReadBoundary private store;
    D.Dependencies private deps;
    S.TokenSelection private selected;
    C.Output private output;
    R.PreservationRecord private record;
    V.Target[] private targets;
    V.Read[] private declared;
    bytes32 private key;
    address private rosterOnlyTarget;
    uint256 private rosterOnlyIndex;

    function setUp() public {
        probe = new PreservationAdmissionInventoryProbe();
        registry = new PreservationAdmissionReadBoundary();
        producer = new PreservationAdmissionReadBoundary();
        schemas = new PreservationAdmissionReadBoundary();
        store = new PreservationAdmissionReadBoundary();
        deps.chainId = block.chainid;
        deps.readGas = 100000;
        deps.sourceGas = 150000;
        deps.targets[0] = address(new PreservationAdmissionReadBoundary());
        deps.targets[2] = address(schemas);
        deps.targets[3] = address(store);
        deps.targets[4] = address(new PreservationAdmissionReadBoundary());
        for (uint256 i; i < deps.targets.length; ++i) {
            deps.codeHashes[i] = deps.targets[i].codehash;
        }
        output.preservation = P.Binding(
            address(producer),
            address(producer).codehash,
            keccak256("6529STREAM_PRESERVATION_RENDER_V1"),
            deps.targets[0],
            deps.targets[4],
            address(new PreservationAdmissionReadBoundary()),
            bytes32(0),
            address(new PreservationAdmissionReadBoundary()),
            bytes32(0)
        );
        output.preservation.liveRendererCodeHash = output.preservation.liveRenderer.codehash;
        output.preservation.attributionCodeHash = output.preservation.attribution.codehash;
        output.leaf.tokenId = 91;
        selected.tokenId = 91;
        selected.sources[0] = deps.targets[0];
        selected.sources[1] = deps.targets[4];
        selected.sourceCodeHashes[0] = deps.codeHashes[0];
        selected.sourceCodeHashes[1] = deps.codeHashes[4];
        selected.selection.renderer = output.preservation.liveRenderer;
        selected.selection.rendererCodeHash = output.preservation.liveRendererCodeHash;
        selected.selection.registry = address(registry);
        selected.selection.registryCodeHash = address(registry).codehash;
        selected.selection.versionKey = keccak256("actual selected version");
        selected.selection.registrationHash = keccak256("original full renderer registration");
        producer.set(
            abi.encodeWithSignature("preservationProfile()"),
            abi.encode(output.preservation.profile)
        );
        producer.set(
            abi.encodeWithSignature("preservationBinding()"),
            abi.encode(
                output.preservation.core,
                output.preservation.metadataRouter,
                output.preservation.liveRenderer,
                output.preservation.liveRendererCodeHash,
                output.preservation.attribution,
                output.preservation.attributionCodeHash
            )
        );
        rosterOnlyTarget = address(new PreservationAdmissionReadBoundary());
        address[6] memory addresses = [
            deps.targets[0],
            deps.targets[4],
            address(producer),
            output.preservation.liveRenderer,
            output.preservation.attribution,
            rosterOnlyTarget
        ];
        for (uint256 i; i < addresses.length; ++i) {
            for (uint256 j = i + 1; j < addresses.length; ++j) {
                if (addresses[j] < addresses[i]) {
                    (addresses[i], addresses[j]) = (addresses[j], addresses[i]);
                }
            }
            targets.push(
                V.Target({
                    target: addresses[i],
                    codeHash: addresses[i].codehash,
                    role: keccak256(abi.encode("original target role", i))
                })
            );
            if (addresses[i] == rosterOnlyTarget) rosterOnlyIndex = i;
            declared.push(V.Read(uint16(i), bytes4(keccak256("sourceFact()")), 32, true));
        }
        registry.set(abi.encodeWithSignature("schemaRegistry()"), abi.encode(address(schemas)));
        registry.set(
            abi.encodeWithSignature("schemaRegistryCodeHash()"),
            abi.encode(address(schemas).codehash)
        );
        registry.set(abi.encodeWithSignature("deploymentChainId()"), abi.encode(block.chainid));
        record.registration.versionKey = selected.selection.versionKey;
        record.registration.binding =
            abi.decode(abi.encode(output.preservation), (R.ProducerBinding));
        record.registration.schemaDocument = keccak256("preservation schema document");
        record.registration.analysisDocument = keccak256("preservation analysis document");
        record.registration.goldenDocument = keccak256("preservation golden document");
        record.analysisHash = keccak256("exact independent analysis bytes");
        record.goldenHash = keccak256("exact preservation golden bytes");
        record.actionId = keccak256("original governed registration action");
        key = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRESERVATION_KEY_V1"),
                selected.selection.versionKey,
                address(producer),
                output.preservation.profile
            )
        );
        _documents();
        _commitRoster();
    }

    function testV2FullPlanRetainsEveryOriginalProducerRow() public {
        C.Plan memory p = _familyPlan();
        for (uint64 i; i < 16; ++i) {
            (T.Item memory row, uint64 count) = probe.itemForPlan(deps, p, selected, output, i);
            require(count == 16 && keccak256(abi.encode(row)) == keccak256(abi.encode(_item(i))));
        }
    }

    function testV2CurrentArtistProducerRequiresSameCompleteAdmissionAndRoster() public {
        _producerProfile(keccak256("6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1"));
        C.Plan memory p = _familyPlan();
        for (uint64 i; i < 16; ++i) {
            (T.Item memory row, uint64 count) = probe.itemForPlan(deps, p, selected, output, i);
            require(count == 16 && row.byteSize != 0 && row.digest.length == 32);
            if (i == 0) _digest(row, abi.encode(output.preservation));
        }
        _fails(0); // The legacy entrypoint still rejects this distinct producer.
    }

    function testV2RejectsViewAndUnknownProducerDespiteMatchingRegistryBoundary() public {
        _producerProfile(keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_V1"));
        C.Plan memory p = _familyPlan();
        _familyFails(p);
        _producerProfile(keccak256("unregistered family marker"));
        _familyFails(p);
    }

    function testV2RejectsIncompletePlanAndWrongSelectionRow() public {
        C.Plan memory p = _familyPlan();
        p.nextIndex = 0;
        _familyFails(p);
        p.nextIndex = 1;
        p.preservationProfile = keccak256("6529STREAM_PRESERVATION_RENDER_V1");
        _familyFails(p);
        p.preservationProfile = keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2");
        output.selectionRowHash = keccak256("different authenticated selection");
        _familyFails(p);
    }

    function _familyPlan() private returns (C.Plan memory p) {
        p.preservationProfile = keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2");
        p.tokenCount = 1;
        p.nextIndex = 1;
        p.contentRoot = keccak256("saved complete content");
        p.outputRoot = keccak256("saved complete output");
        output.selectionRowHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_STATIC_SELECTION_ROW_V1"),
                deps.chainId,
                deps.targets[0],
                deps.targets[4],
                selected
            )
        );
    }

    function _producerProfile(bytes32 profile) private {
        output.preservation.profile = profile;
        record.registration.binding.profile = profile;
        key = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRESERVATION_KEY_V1"),
                selected.selection.versionKey,
                address(producer),
                profile
            )
        );
        producer.set(abi.encodeWithSignature("preservationProfile()"), abi.encode(profile));
        _commitRoster();
    }

    function _familyFails(C.Plan memory p) private view {
        (bool ok,) = address(probe)
            .staticcall(abi.encodeCall(probe.itemForPlan, (deps, p, selected, output, uint64(0))));
        require(!ok, "family does not bypass complete admission");
    }

    function _documents() private {
        _document(record.registration.schemaDocument, bytes("exact schema bytes"));
        _document(record.registration.analysisDocument, bytes("exact independent analysis bytes"));
        _document(record.registration.goldenDocument, bytes("exact preservation golden bytes"));
    }

    function _document(bytes32 id, bytes memory bytes_) private {
        F.DocumentFacts memory f;
        f.exists = true;
        f.status = IStreamSchemaRegistry.DocumentStatus.ACTIVE;
        f.contentHash = keccak256(bytes_);
        f.totalBytes = uint32(bytes_.length);
        f.chunkCount = 1;
        schemas.set(abi.encodeCall(F.documentFacts, (id)), abi.encode(f));
        schemas.set(abi.encodeCall(F.documentChunkHashAt, (id, 0)), abi.encode(keccak256(bytes_)));
        store.set(
            abi.encodeWithSignature("readChunk(bytes32)", keccak256(bytes_)), abi.encode(bytes_)
        );
    }

    function _commitRoster() private {
        bytes32 targetsHash = keccak256(abi.encode(targets));
        record.readSetHash = keccak256(
            abi.encode(keccak256("6529STREAM_RENDERER_READ_SET_V1"), targetsHash, declared)
        );
        record.registrationHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRESERVATION_REGISTRATION_V1"),
                block.chainid,
                address(registry),
                address(schemas),
                address(schemas).codehash,
                targetsHash,
                selected.selection.registrationHash,
                record.registration,
                declared
            )
        );
        output.preservationAdmission = P.Admission(
            address(registry),
            address(registry).codehash,
            selected.selection.versionKey,
            record.registrationHash,
            record.readSetHash,
            record.analysisHash,
            record.goldenHash
        );
        registry.set(abi.encodeWithSignature("targetSetHash()"), abi.encode(targetsHash));
        registry.set(abi.encodeCall(V.targetCount, ()), abi.encode(targets.length));
        for (uint256 i; i < targets.length; ++i) {
            registry.set(abi.encodeCall(V.targetAt, (i)), abi.encode(targets[i]));
        }
        registry.set(abi.encodeCall(R.preservationReads, (key)), abi.encode(declared));
        _publishRecord();
    }

    function _publishRecord() private {
        registry.set(abi.encodeCall(R.preservationRecord, (key)), abi.encode(record));
        registry.set(
            _admissionInput(), abi.encode(output.preservation, output.preservationAdmission)
        );
    }

    function _admissionInput() private view returns (bytes memory) {
        return abi.encodeCall(
            R.requirePreservation,
            (
                selected.selection.versionKey,
                output.preservation.producer,
                output.preservation.profile
            )
        );
    }

    function _item(uint64 i) private view returns (T.Item memory item) {
        uint64 count;
        (item, count) = probe.item(deps, selected, output, i);
        require(count == 16, "all six declared targets remain mandatory");
    }

    function _fails(uint64 i) private view {
        (bool ok,) =
            address(probe).staticcall(abi.encodeCall(probe.item, (deps, selected, output, i)));
        require(!ok, "altered source cannot produce a successful inventory row");
    }

    function _digest(T.Item memory item, bytes memory bytes_) private pure {
        require(
            item.byteSize == bytes_.length && item.algorithm == 1
                && keccak256(item.digest) == keccak256(abi.encodePacked(keccak256(bytes_))),
            "exact full bytes"
        );
    }

    function testAllSixteenOrderedRowsRetainBindingsDocumentsAndEveryRuntime() public view {
        _digest(_item(0), abi.encode(output.preservation));
        _digest(_item(1), abi.encode(output.preservationAdmission));
        _digest(_item(2), abi.encode(record));
        _digest(_item(3), abi.encode(declared));
        _digest(_item(4), abi.encode(targets));
        require(
            _item(5).source == address(producer)
                && _item(6).source == output.preservation.attribution,
            "producer and companion runtime roles"
        );
        bytes32[3] memory ids = [
            record.registration.schemaDocument,
            record.registration.analysisDocument,
            record.registration.goldenDocument
        ];
        for (uint64 i; i < 3; ++i) {
            T.Item memory document = _item(7 + i);
            require(
                document.kind == T.Kind.REGISTERED_DOCUMENT && document.catalogId == ids[i]
                    && document.provenanceHash != 0,
                "all admitted interpretation documents"
            );
        }
        for (uint64 i; i < targets.length; ++i) {
            T.Item memory runtime = _item(10 + i);
            require(
                runtime.kind == T.Kind.CONTRACT_RUNTIME && runtime.source == targets[i].target
                    && runtime.role == targets[i].role && runtime.sourceRecord == key
                    && runtime.sourceIndex == i
                    && runtime.provenanceHash
                        == keccak256(abi.encode(address(registry), key, targets[i])),
                "full original roster and exact provenance"
            );
            _digest(runtime, targets[i].target.code);
        }
        _fails(16);
    }

    function testEverySavedAdmissionWordMustMatchCurrentGovernedReturn() public {
        bytes memory canonical = abi.encode(output.preservationAdmission);
        for (uint256 i; i < 7; ++i) {
            bytes memory changed = bytes.concat(canonical);
            assembly ("memory-safe") {
                let p := add(add(changed, 32), mul(i, 32))
                mstore(p, xor(mload(p), 1))
            }
            output.preservationAdmission = abi.decode(changed, (P.Admission));
            _fails(0);
        }
        output.preservationAdmission = abi.decode(canonical, (P.Admission));
        _item(0);
    }

    function testRegistrationAndReadSetHashesCannotBeSelfAsserted() public {
        record.registrationHash = keccak256("substituted declaration");
        output.preservationAdmission.registrationHash = record.registrationHash;
        _publishRecord();
        _fails(2);
        _commitRoster();
        record.readSetHash = keccak256("substituted source reads");
        output.preservationAdmission.readSetHash = record.readSetHash;
        _publishRecord();
        _fails(3);
        _commitRoster();
        _item(3);
    }

    function testEveryRegistrationWordAndOriginalActionRemainRequired() public {
        bytes memory canonical = abi.encode(record);
        for (uint256 i; i < 18; ++i) {
            bytes memory changed = bytes.concat(canonical);
            assembly ("memory-safe") {
                let p := add(add(changed, 32), mul(i, 32))
                mstore(p, xor(mload(p), 1))
            }
            registry.set(abi.encodeCall(R.preservationRecord, (key)), changed);
            if (i == 17) {
                // A nonzero action identifier is provenance, not re-derived authorization.
                registry.set(
                    abi.encodeCall(R.preservationRecord, (key)),
                    abi.encode(
                        record.registration,
                        record.registrationHash,
                        record.readSetHash,
                        record.analysisHash,
                        record.goldenHash,
                        bytes32(0)
                    )
                );
            }
            _fails(2);
        }
        _publishRecord();
        _item(2);
    }

    function testIncompleteOrReorderedTargetRosterAndBadCountFailClosed() public {
        registry.set(abi.encodeCall(V.targetCount, ()), abi.encode(uint256(0)));
        _fails(4);
        registry.set(abi.encodeCall(V.targetCount, ()), abi.encode(uint256(65)));
        _fails(4);
        registry.set(abi.encodeCall(V.targetCount, ()), abi.encode(uint256(5)));
        _fails(4);
        _commitRoster();
        registry.set(abi.encodeCall(V.targetAt, (1)), abi.encode(targets[0]));
        _fails(4);
        _commitRoster();
        registry.set(abi.encodeCall(V.targetAt, (0)), abi.encode(targets[1]));
        _fails(4);
        _commitRoster();
        _item(4);
    }

    function testUnreferencedTargetRuntimeStillInvalidatesCompleteInventory() public {
        // Remove its read from an otherwise valid new admitted declaration; keep target roster full.
        for (uint256 i = rosterOnlyIndex; i + 1 < declared.length; ++i) {
            declared[i] = declared[i + 1];
        }
        declared.pop();
        _commitRoster();
        address target = rosterOnlyTarget;
        bytes memory prior = target.code;
        vm.etch(target, hex"60006000f3");
        _fails(0);
        vm.etch(target, prior);
        _item(15);
    }

    function testReadOrderingSelectorIndexAndBoundsAreValidatedBeforeHashAcceptance() public {
        V.Read memory original = declared[1];
        declared[1] = declared[0];
        _commitRoster();
        _fails(3);
        declared[1] = original;
        declared[1].selector = bytes4(0);
        _commitRoster();
        _fails(3);
        declared[1] = original;
        declared[1].targetIndex = uint16(targets.length);
        _commitRoster();
        _fails(3);
        declared[1] = original;
        declared[1].maxReturnBytes = 0;
        _commitRoster();
        _fails(3);
        declared[1].maxReturnBytes = 16777217;
        _commitRoster();
        _fails(3);
        declared[1].maxReturnBytes = 31;
        _commitRoster();
        _fails(3);
        declared[1] = original;
        _commitRoster();
        _item(3);
    }

    function testMissingReadOrWrongTargetHashCannotReuseAdmission() public {
        declared.pop();
        registry.set(abi.encodeCall(R.preservationReads, (key)), abi.encode(declared));
        _fails(3);
        _commitRoster();
        _item(3);
        registry.set(abi.encodeWithSignature("targetSetHash()"), abi.encode(bytes32(uint256(1))));
        _fails(4);
    }

    function testOriginalRendererRegistrationCannotBeSubstituted() public {
        selected.selection.registrationHash = keccak256("different original full renderer");
        _fails(0);
    }

    function testCanonicalFixedReturnsRejectShortAndTrailingWords() public {
        registry.set(_admissionInput(), abi.encode(output.preservation));
        _fails(0);
        registry.set(
            _admissionInput(),
            bytes.concat(abi.encode(output.preservation, output.preservationAdmission), bytes32(0))
        );
        _fails(0);
        _publishRecord();
        registry.set(
            abi.encodeCall(R.preservationRecord, (key)),
            bytes.concat(abi.encode(record), bytes32(0))
        );
        _fails(2);
        _publishRecord();
        _item(2);
    }

    function testAnalysisAndGoldenDocumentBytesMustMatchAdmittedHashes() public {
        _document(record.registration.analysisDocument, bytes("other coherent document"));
        _fails(8);
        _documents();
        _item(8);
        _document(record.registration.goldenDocument, bytes("other coherent vectors"));
        _fails(9);
        _documents();
        _item(9);
    }

    function testRegisteredSchemaRequiresCompleteOriginalActiveDocumentAndChunks() public {
        F.DocumentFacts memory missing;
        schemas.set(
            abi.encodeCall(F.documentFacts, (record.registration.schemaDocument)),
            abi.encode(missing)
        );
        _fails(7);
        _documents();
        _item(7);
        store.set(
            abi.encodeWithSignature("readChunk(bytes32)", keccak256("exact schema bytes")),
            abi.encode(bytes("wrong bytes"))
        );
        _fails(7);
        _documents();
        _item(7);
    }

    function testRuntimeDriftAndProducerBindingFailureAllowExactRestore() public {
        address[5] memory pinned = [
            address(producer),
            output.preservation.attribution,
            output.preservation.liveRenderer,
            deps.targets[0],
            deps.targets[4]
        ];
        for (uint256 i; i < pinned.length; ++i) {
            bytes memory prior = pinned[i].code;
            vm.etch(pinned[i], hex"60006000f3");
            _fails(0);
            vm.etch(pinned[i], prior);
            _item(0);
        }
        producer.set(
            abi.encodeWithSignature("preservationProfile()"), abi.encode(keccak256("other profile"))
        );
        _fails(0);
    }

    function testSchemaHostChainCoreRouterAndTokenCoordinatesAreExact() public {
        registry.set(abi.encodeWithSignature("deploymentChainId()"), abi.encode(block.chainid + 1));
        _fails(0);
        registry.set(abi.encodeWithSignature("deploymentChainId()"), abi.encode(block.chainid));
        registry.set(abi.encodeWithSignature("schemaRegistry()"), abi.encode(address(store)));
        _fails(0);
        registry.set(abi.encodeWithSignature("schemaRegistry()"), abi.encode(address(schemas)));
        selected.tokenId = 92;
        _fails(0);
        selected.tokenId = 91;
        deps.chainId += 1;
        _fails(0);
        deps.chainId -= 1;
        address prior = deps.targets[0];
        deps.targets[0] = address(store);
        _fails(0);
        deps.targets[0] = prior;
        prior = deps.targets[4];
        deps.targets[4] = address(store);
        _fails(0);
        deps.targets[4] = prior;
        _item(0);
    }
}
