// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamFinalityPreservationPolicyReferenceReadsV1 as Reader
} from "../../../smart-contracts/domains/finality/StreamFinalityPreservationPolicyReferenceReadsV1.sol";
import {
    StreamPreservationPolicyReferenceTypesV1 as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationPolicyReferenceTypesV1.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

interface ReferenceFramesVm {
    function expectRevert(bytes calldata reason) external;
    function warp(uint256 timestamp) external;
}

/// @dev Explicit typed publisher boundary. Every reader call must retain the test host caller.
contract ReferenceFramePublisher {
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
contract StreamPreservationReferenceReadFramesTest {
    ReferenceFramesVm private constant vm =
        ReferenceFramesVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant ORIGINAL = keccak256("6529STREAM_PRESERVATION_RENDER_V1");
    bytes32 private constant FAMILY = keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2");

    struct Fixture {
        ReferenceFramePublisher publisher;
        Reader.Dependencies dependencies;
        StreamFinalityScope scope;
        T.Publication publication;
        T.Receipt receipt;
        bytes32 hash;
        bytes32 family;
    }

    function testBothFamiliesPreserveFullNestedBytesCallerAndCurrentLock() public {
        for (uint256 i; i < 2; ++i) {
            Fixture memory f = _fixture(i != 0, hex"000102ff003355");
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
            if (i == 0) {
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
            abi.encodeWithSelector(Reader.PolicyReferenceDependency.selector, address(f.publisher))
        );
        this.read(f.dependencies, f.scope, f.hash, f.family);
        f.publisher.put(key, valid);
        _assertOriginal(f);
    }

    function testDefinitionBindingSubjectAndReadFailureOrder() public {
        Fixture memory f = _fixture(false, bytes("ordered validation"));
        f.dependencies.codeHashes[0] = bytes32(uint256(1));
        f.scope.tokenId = 1;
        vm.expectRevert(abi.encodeWithSignature("InvalidPreservationReferenceFamily()"));
        this.read(f.dependencies, f.scope, f.hash, bytes32(uint256(1)));
        vm.expectRevert(
            abi.encodeWithSelector(Reader.PolicyReferenceDependency.selector, address(f.publisher))
        );
        this.read(f.dependencies, f.scope, f.hash, f.family);
        f.dependencies.codeHashes[0] = address(f.publisher).codehash;
        vm.expectRevert(abi.encodeWithSelector(Reader.InvalidPolicyReferenceEvidence.selector));
        this.read(f.dependencies, f.scope, f.hash, f.family);
        f.scope.tokenId = 0;
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
        vm.expectRevert(abi.encodeWithSelector(Reader.InvalidPolicyReferenceEvidence.selector));
        this.read(f.dependencies, f.scope, f.hash, f.family);
        (f.publication, f.receipt) = abi.decode(original, (T.Publication, T.Receipt));
        f.publication.observation.environment.packageFiles[0].path = "different full tail";
        _putRecord(f);
        vm.expectRevert(abi.encodeWithSelector(Reader.InvalidPolicyReferenceEvidence.selector));
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

    function testFuzzDynamicTailParity(bool v2, bytes calldata data) public {
        bytes memory bounded = data[:data.length > 2048 ? 2048 : data.length];
        Fixture memory f = _fixture(v2, bounded);
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
        vm.warp(100);
        f.publisher = new ReferenceFramePublisher(address(this));
        f.family = v2 ? FAMILY : ORIGINAL;
        f.scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 7, 0, 0);
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
                abi.encodeWithSignature("preservationPolicyReferenceProfile()"),
                abi.encode(
                    v2
                        ? keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_V2")
                        : keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_V1")
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
            ? bytes32(0x015dc229364e4b3b82225ac96d9010c04d570a173dd011bc0db96e860b8d913a)
            : bytes32(0x387fe93e70bc204ac0685617b90611b3eccebe7f8e9be78fee5f0cce1b495379);
        r.profileHash = v2
            ? bytes32(0xe2263771b4e5178c556bf9e321f57d4a8b3844b9a2e7577f233720f6fc088bda)
            : bytes32(0xfd74f1fb7a6d60a999685ada5840d612042fe0e98e87ae7a145da13f7257d0d3);
        r.canonicalizationHash = v2
            ? bytes32(0xd2a02feba1926199b5a2b1bd736c0cb6d1f08a8024561d59db224a90c294800d)
            : bytes32(0xcc5a1a28dafcc642ebfd3d6510aa9a4aac651a4329f6dc539c4e344b0a882ee4);
        f.receipt.scopeSubject = keccak256(
            abi.encode(
                keccak256("6529STREAM_SUBJECT_COLLECTION_V1"),
                block.chainid,
                address(f.publisher),
                uint256(7)
            )
        );
        f.receipt.observation = r;
        f.hash = keccak256(
            abi.encode(
                v2
                    ? keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_RECORD_V2")
                    : keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_RECORD_V1"),
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
