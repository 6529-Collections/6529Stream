// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamFinalityScopedPreservationPolicyReferenceReadsV1 as Reader
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPreservationPolicyReferenceReadsV1.sol";
import {
    StreamScopedPreservationPolicyReferenceTypesV1 as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPreservationPolicyReferenceTypesV1.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

interface ScopedReferenceFramesVm {
    function expectRevert(bytes calldata reason) external;
    function warp(uint256 timestamp) external;
}

/// @dev Explicit typed publisher boundary. Every reader call must retain the test host caller.
contract ScopedReferenceFramePublisher {
    address private immutable expectedCaller;
    mapping(bytes32 => bytes) private replies;

    constructor(address caller) {
        expectedCaller = caller;
    }

    function put(bytes calldata input, bytes calldata output) external {
        replies[keccak256(input)] = output;
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        require(msg.sender == expectedCaller, "reader changed publisher caller");
        return id != 0xffffffff;
    }

    fallback(bytes calldata input) external returns (bytes memory) {
        require(msg.sender == expectedCaller, "reader changed publisher caller");
        bytes memory result = replies[keccak256(input)];
        require(result.length != 0, "missing typed publisher reply");
        return result;
    }
}

/// @notice Actual fixed libraries with explicit typed publisher/Core/Router boundaries.
/// @dev Proves reader transport, predicates and bytes, not publisher admission or full Finality.
contract StreamScopedPreservationReferenceReadFramesTest {
    ScopedReferenceFramesVm private constant vm =
        ScopedReferenceFramesVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant ORIGINAL = keccak256("6529STREAM_PRESERVATION_RENDER_V1");
    bytes32 private constant FAMILY = keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2");

    struct Fixture {
        ScopedReferenceFramePublisher publisher;
        Reader.Dependencies dependencies;
        StreamFinalityScope scope;
        T.Publication publication;
        T.Receipt receipt;
        bytes32 hash;
        bytes32 family;
    }

    function testBothFamiliesPreserveFullNestedBytesCallerAndCurrentLock() public {
        for (uint256 i; i < 6; ++i) {
            Fixture memory f = _fixture(i % 2 != 0, hex"000102ff003355", uint8(i / 2 + 1));
            _assertOriginal(f);
            T.Receipt memory current =
                Reader.requireCurrent(f.dependencies, f.scope, f.hash, 1, f.family);
            require(keccak256(abi.encode(current)) == keccak256(abi.encode(f.receipt)));
            (T.Receipt memory lockedReceipt, R.Lock memory lock) =
                Reader.requireLocked(f.dependencies, f.scope, f.hash, 1, f.family);
            require(keccak256(abi.encode(lockedReceipt)) == keccak256(abi.encode(f.receipt)));
            require(
                lock.recordHash == f.hash && lock.revision == 1
                    && lock.actionId == keccak256("lock") && lock.lockedAt == 90
            );
            if (i % 2 == 0) {
                (T.Publication memory p, T.Receipt memory r) =
                    Reader.original(f.dependencies, f.scope, f.hash, 1);
                require(
                    keccak256(abi.encode(p, r)) == keccak256(abi.encode(f.publication, f.receipt))
                );
            }
        }
    }

    function testCanonicalFailureAndRestoredIdenticalRead() public {
        Fixture memory f = _fixture(true, bytes("canonical dynamic tails"));
        bytes memory key = abi.encodeWithSignature("referenceRecord(bytes32)", f.hash);
        bytes memory valid = abi.encode(f.publication, f.receipt);
        f.publisher.put(key, bytes.concat(valid, hex"00"));
        vm.expectRevert(
            abi.encodeWithSelector(
                Reader.ScopedPreservationPolicyReferenceDependency.selector, address(f.publisher)
            )
        );
        this.read(f.dependencies, f.scope, f.hash, f.family);
        f.publisher.put(key, valid);
        _assertOriginal(f);
    }

    function testDefinitionBindingSubjectAndReadFailureOrder() public {
        Fixture memory f = _fixture(false, bytes("ordered validation"));
        f.dependencies.codeHashes[0] = bytes32(uint256(1));
        f.scope.scopeType = StreamFinalityScopeType.COLLECTION;
        vm.expectRevert(abi.encodeWithSignature("InvalidPreservationReferenceFamily()"));
        this.read(f.dependencies, f.scope, f.hash, bytes32(uint256(1)));
        vm.expectRevert(
            abi.encodeWithSelector(
                Reader.ScopedPreservationPolicyReferenceDependency.selector, address(f.publisher)
            )
        );
        this.read(f.dependencies, f.scope, f.hash, f.family);
        f.dependencies.codeHashes[0] = address(f.publisher).codehash;
        vm.expectRevert(
            abi.encodeWithSelector(Reader.InvalidScopedPreservationPolicyReferenceEvidence.selector)
        );
        this.read(f.dependencies, f.scope, f.hash, f.family);
        f.scope.scopeType = StreamFinalityScopeType.TOKEN;
        f.publisher.put(abi.encodeWithSignature("referenceRecord(bytes32)", f.hash), "");
        vm.expectRevert(
            abi.encodeWithSignature(
                "RouterEvidenceRead(address,bytes4)",
                address(f.publisher),
                bytes4(keccak256("referenceRecord(bytes32)"))
            )
        );
        this.read(f.dependencies, f.scope, f.hash, f.family);
        _putRecord(f);
        _assertOriginal(f);
    }

    function testTupleAndNormalizedHashFailureRestoreWithoutMutatingReceipt() public {
        Fixture memory f = _fixture(true, bytes("complete publication hash"));
        bytes memory original = abi.encode(f.publication, f.receipt);
        f.receipt.observation.revision = 2;
        _putRecord(f);
        vm.expectRevert(
            abi.encodeWithSelector(Reader.InvalidScopedPreservationPolicyReferenceEvidence.selector)
        );
        this.read(f.dependencies, f.scope, f.hash, f.family);
        (f.publication, f.receipt) = abi.decode(original, (T.Publication, T.Receipt));
        f.publication.observation.environment.packageFiles[0].path = "different full tail";
        _putRecord(f);
        vm.expectRevert(
            abi.encodeWithSelector(Reader.InvalidScopedPreservationPolicyReferenceEvidence.selector)
        );
        this.read(f.dependencies, f.scope, f.hash, f.family);
        (f.publication, f.receipt) = abi.decode(original, (T.Publication, T.Receipt));
        _putRecord(f);
        _assertOriginal(f);
        require(keccak256(abi.encode(f.publication, f.receipt)) == keccak256(original));
        require(
            f.receipt.observation.recordHash == f.hash
                && f.receipt.observation.recordChainHash == keccak256("record chain")
        );
    }

    function testScopedShapesAndUnsupportedKindsRefuseBeforeRecordRead() public {
        for (uint8 kind = 1; kind <= 3; ++kind) {
            Fixture memory f = _fixture(true, bytes("exact subject shape"), kind);
            StreamFinalityScope memory valid = f.scope;
            // Independent copies keep the saved lawful scope intact.
            StreamFinalityScope memory bad = abi.decode(abi.encode(valid), (StreamFinalityScope));
            if (kind == 1) bad.tokenId = 0;
            else bad.scopeId = 0;
            vm.expectRevert(abi.encodeWithSignature("InvalidMetadataScope()"));
            this.read(f.dependencies, bad, f.hash, f.family);
            bad = abi.decode(abi.encode(valid), (StreamFinalityScope));
            bad.scopeType = StreamFinalityScopeType.COLLECTION;
            vm.expectRevert(
                abi.encodeWithSelector(
                    Reader.InvalidScopedPreservationPolicyReferenceEvidence.selector
                )
            );
            this.read(f.dependencies, bad, f.hash, f.family);
            bad.scopeType = StreamFinalityScopeType.VIEW;
            vm.expectRevert(
                abi.encodeWithSelector(
                    Reader.InvalidScopedPreservationPolicyReferenceEvidence.selector
                )
            );
            this.read(f.dependencies, bad, f.hash, f.family);
            _assertOriginal(f);
        }
    }

    function testFuzzDynamicTailParity(bool v2, uint8 kind, bytes calldata data) public {
        bytes memory bounded = data[:data.length > 2048 ? 2048 : data.length];
        Fixture memory f = _fixture(v2, bounded, kind % 3 + 1);
        _assertOriginal(f);
    }

    function read(
        Reader.Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 hash,
        bytes32 family
    ) external view returns (T.Publication memory, T.Receipt memory) {
        return Reader.original(d, scope, hash, 1, family);
    }

    function _assertOriginal(Fixture memory f) private view {
        bytes32 beforeHash = keccak256(abi.encode(f.publication, f.receipt));
        (T.Publication memory p, T.Receipt memory r) =
            Reader.original(f.dependencies, f.scope, f.hash, 1, f.family);
        require(keccak256(abi.encode(p, r)) == beforeHash, "complete typed return changed");
        require(
            keccak256(abi.encode(f.publication, f.receipt)) == beforeHash,
            "live caller input changed"
        );
    }

    function _putRecord(Fixture memory f) private {
        f.publisher
            .put(
                abi.encodeWithSignature("referenceRecord(bytes32)", f.hash),
                abi.encode(f.publication, f.receipt)
            );
    }

    function _fixture(bool v2, bytes memory data) private returns (Fixture memory f) {
        return _fixture(v2, data, 1);
    }

    function _fixture(bool v2, bytes memory data, uint8 kind) private returns (Fixture memory f) {
        vm.warp(100);
        f.publisher = new ScopedReferenceFramePublisher(address(this));
        f.family = v2 ? FAMILY : ORIGINAL;
        f.scope = kind == 1
            ? StreamFinalityScope(StreamFinalityScopeType.TOKEN, 7, 19, 0)
            : StreamFinalityScope(StreamFinalityScopeType(kind), 7, 0, keccak256("scoped subject"));
        T.Dependencies memory source;
        for (uint256 i; i < 7; ++i) {
            source.targets[i] = address(f.publisher);
            source.codeHashes[i] = address(f.publisher).codehash;
            if (i < 5) {
                f.dependencies.targets[i] = address(f.publisher);
                f.dependencies.codeHashes[i] = address(f.publisher).codehash;
            }
        }
        source.chainId = block.chainid;
        f.dependencies.chainId = block.chainid;
        f.dependencies.readGas = 100000;
        f.dependencies.sourceGas = 5000000;
        // Canonical interface/dependency replies are explicit typed boundaries.
        f.publisher.put(abi.encodeWithSignature("dependencies()"), abi.encode(source));
        f.publisher
            .put(
                abi.encodeWithSignature("scopedPreservationPolicyReferenceProfile()"),
                abi.encode(
                    v2
                        ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_V2")
                        : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_V1")
                )
            );
        f.publication.scope = f.scope;
        R.Publication memory p;
        p.collectionId = 7;
        p.referenceId = keccak256("reference");
        p.snapshotRecordHash = keccak256("snapshot");
        p.snapshotRevision = 4;
        p.expectedSourcesHash = keccak256("source");
        p.effectiveAt = 80;
        p.reasonHash = keccak256("reason");
        p.manifestURI = "ar://typed-manifest-locator";
        p.captures = new R.Capture[](1);
        p.captures[0].tokenId = 19;
        p.captures[0].animationHTML = data;
        p.captures[0].repeatCaptureSha256 = [sha256(data), sha256(data)];
        p.environment.engineName = "engine";
        p.environment.licenseNote = "all dynamic members remain in the original hash";
        p.environment.packageFiles = new R.PackageFile[](1);
        p.environment.packageFiles[0] =
            R.PackageFile("renderer/runtime", uint64(data.length), sha256(data));
        p.environment.platformPrerequisites = new R.PackageFile[](1);
        p.environment.platformPrerequisites[0] =
            R.PackageFile("platform", 12, keccak256("platform bytes"));
        f.publication.observation = p;
        R.Receipt memory r;
        r.collectionId = 7;
        r.referenceId = p.referenceId;
        r.revision = 1;
        r.payloadHash = keccak256("payload");
        r.payloadBytes = 100;
        r.sourcesHash = p.expectedSourcesHash;
        r.snapshotRecordHash = p.snapshotRecordHash;
        r.snapshotRevision = p.snapshotRevision;
        r.recorder = address(0x1234);
        r.authorizationClass = v2 ? 8 : 3;
        r.grantRevision = 2;
        r.effectiveAt = p.effectiveAt;
        r.recordedAt = 90;
        r.reasonHash = p.reasonHash;
        r.schemaHash = v2
            ? bytes32(0xaa86ba8fd6a4a9d4eecbee301ee99cea49e9efdecf728f4d57d4a6a6cfc88727)
            : bytes32(0x8eb87b0f336b32f20a37fcecf387a627f4fdef957c05354cf2fcf5c41785de63);
        r.profileHash = v2
            ? bytes32(0x19764e02e956ee4855d429fd13fa632392d97454b0807eb7a439686a20da6be5)
            : bytes32(0xb297ef8dc5a22b2f7f2c2be2aa39200f1da5ddfd5e16b87f1f66ba55585015ba);
        r.canonicalizationHash = v2
            ? bytes32(0xd2149a31cf326579ae91ad48f5cbe10d2721a77c0001082a1b2812fef2f25039)
            : bytes32(0xf2b69c19e3ad019ee9ce80e52ecd47a909ea785e1e23d249a14cbdaa474de7b5);
        f.receipt.scopeSubject = kind == 1
            ? keccak256(
                abi.encode(
                    keccak256("6529STREAM_SUBJECT_TOKEN_V1"),
                    block.chainid,
                    address(f.publisher),
                    uint256(19)
                )
            )
            : keccak256(
                abi.encode(
                    keccak256("6529STREAM_SUBJECT_SCOPE_V1"),
                    block.chainid,
                    address(f.publisher),
                    uint256(7),
                    kind,
                    keccak256("scoped subject")
                )
            );
        f.receipt.observation = r;
        f.hash = keccak256(
            abi.encode(
                v2
                    ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_RECORD_V2")
                    : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_RECORD_V1"),
                block.chainid,
                address(f.publisher),
                address(f.publisher),
                address(f.publisher),
                f.publication,
                f.receipt
            )
        );
        f.receipt.observation.recordHash = f.hash;
        f.receipt.observation.recordChainHash = keccak256("record chain");
        _putRecord(f);
        f.publisher
            .put(
                abi.encodeWithSignature(
                    "requireCurrent((uint8,uint256,uint256,bytes32),bytes32,uint64)",
                    f.scope,
                    f.hash,
                    uint64(1)
                ),
                abi.encode(f.receipt)
            );
        f.publisher
            .put(
                abi.encodeWithSignature("referenceLock((uint8,uint256,uint256,bytes32))", f.scope),
                abi.encode(
                    R.Lock({
                        recordHash: f.hash, revision: 1, actionId: keccak256("lock"), lockedAt: 90
                    })
                )
            );
    }
}
