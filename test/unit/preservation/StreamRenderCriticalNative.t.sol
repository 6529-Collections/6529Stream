// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamReferenceSourceExport.t.sol";
import {
    StreamSnapshotSourceReads
} from "../../../smart-contracts/domains/records/StreamSnapshotSourceReads.sol";
import {
    StreamRenderCriticalSourceReads as NativeSources
} from "../../../smart-contracts/domains/preservation/StreamRenderCriticalSourceReads.sol";
import {
    StreamRenderCriticalTokenReads as TokenSources
} from "../../../smart-contracts/domains/preservation/StreamRenderCriticalTokenReads.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as PreservationInventory
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

/// @dev These unused families are explicit boundaries; this cohort tests native bytes only.
contract NativeInventoryOtherFamiliesBoundary {
    address public core;
    address public archiveCoverage;

    constructor(address value) {
        core = value;
        archiveCoverage = address(this);
    }
}

/// @notice Actual Snapshot/Router/Schema/Store/checkpoint/minted inventory/two native policies.
/// @dev Inherited Core, Artist, entropy seed and leaf-archive boundaries remain explicit.
/// No complete eight-input selector, Artist bundle or archival bundle claim follows this cohort.
contract StreamRenderCriticalNativeTest is ReferenceSourceExportTest {
    S.Dependencies private nativeDependencies;
    S.Context private nativeContext;

    function nativeRead(S.Dependencies memory d, S.Context memory c)
        external
        view
        returns (PreservationInventory.Item[] memory)
    {
        return NativeSources.nativeItems(d, c);
    }

    function tokenRead(
        S.Dependencies memory d,
        S.Context memory c,
        uint64 index,
        IStreamOnchainContentCheckpoint.TokenPayload memory p
    ) external view returns (PreservationInventory.Item[] memory) {
        return TokenSources.tokenItems(d, c, index, p);
    }

    function setUp() public override {
        super.setUp();
        _publish(address(this));
        NativeInventoryOtherFamiliesBoundary other =
            new NativeInventoryOtherFamiliesBoundary(address(core));
        nativeDependencies.targets = [
            address(core),
            address(metadata),
            address(schemas),
            address(store),
            address(router),
            address(snapshots),
            address(other),
            address(other),
            address(other),
            address(other),
            address(archive),
            address(other)
        ];
        for (uint256 i; i < 12; ++i) {
            nativeDependencies.codeHashes[i] = nativeDependencies.targets[i].codehash;
        }
        for (uint256 i; i < 5; ++i) {
            nativeDependencies.artistTargets[i] = address(other);
            nativeDependencies.artistCodeHashes[i] = address(other).codehash;
        }
        nativeDependencies.artistContentOwner = address(other);
        nativeDependencies.artistContentOwnerCodeHash = address(other).codehash;
        nativeDependencies.chainId = block.chainid;
        nativeDependencies.readGas = 500000;
        nativeDependencies.sourceGas = 4000000;
        nativeDependencies.selectionGas = 4000000;
        nativeDependencies.snapshotGas = 6000000;
        nativeDependencies.referenceGas = 8000000;
        StreamSnapshotTypes.NativeFacts memory n =
            StreamSnapshotSourceReads.requireCurrent(_dependencies(), 1);
        nativeContext.collectionId = 1;
        nativeContext.subject = n.subject;
        nativeContext.artistId = n.artist.artistId;
        nativeContext.snapshot = snapshots.currentSnapshot(1);
        nativeContext.nativeHash = keccak256(abi.encode(n));
        nativeContext.rootRecordHash = n.contentRootRecordHash;
        nativeContext.checkpointHash = n.leafManifest.checkpointHash;
        nativeContext.tokenInventoryHash = n.checkpoint.inventoryHash;
        nativeContext.tokenCount = n.checkpoint.tokenCount;
    }

    function testActualNativeInventoryKeepsFullBytesAndEveryOriginalCoordinator() public view {
        PreservationInventory.Item[] memory rows = NativeSources.nativeItems(nativeDependencies, nativeContext);
        require(rows.length == 18, "fourteen native roles plus both original policies and runtimes");
        StreamSnapshotTypes.NativeFacts memory n =
            StreamSnapshotSourceReads.requireCurrent(_dependencies(), 1);
        require(
            keccak256(rows[0].digest)
                    == keccak256(abi.encodePacked(keccak256(bytes(n.source.script))))
                && rows[0].byteSize == bytes(n.source.script).length,
            "full original script bytes"
        );
        require(
            rows[6].source == n.serving.renderer
                && rows[6].byteSize == n.serving.renderer.code.length,
            "actual renderer executable"
        );
        require(
            rows[9].sourceRecord == nativeContext.snapshot.recordHash
                && rows[9].byteSize
                    == snapshots.snapshotManifestBytes(nativeContext.snapshot.recordHash).length,
            "full actual snapshot bytes"
        );
        require(
            rows[13].kind == PreservationInventory.Kind.ONCHAIN_OBJECT
                && rows[13].objectHash == n.leafManifest.artifactHash
                && rows[13].originalCoverageHash == n.leafManifest.coverageHash,
            "leaf list is its own archival object"
        );
        require(
            rows[14].source == address(first) && rows[16].source == address(second),
            "ordered original sources are not current pointer only"
        );
        require(
            rows[15].role == rows[17].role && rows[15].sourceIndex == 0
                && rows[17].sourceIndex == 1,
            "separate ordered source occurrences"
        );
    }

    function testActualTokenRowsRetainBurnedEndpointAndRejectSubstitution() public {
        IStreamOnchainContentCheckpoint.TokenPayload memory p = _tokenPayload(2);
        PreservationInventory.Item[] memory before_ =
            TokenSources.tokenItems(nativeDependencies, nativeContext, 1, p);
        require(
            before_.length == 4 && before_[2].kind == PreservationInventory.Kind.ABSENT,
            "actual declared no-image branch"
        );
        require(
            before_[0].byteSize == 2 && before_[3].byteSize == p.animation.length,
            "full data and HTML"
        );
        core.setToken(2, address(0), 3);
        PreservationInventory.Item[] memory burned =
            TokenSources.tokenItems(nativeDependencies, nativeContext, 1, p);
        require(
            keccak256(abi.encode(burned)) == keccak256(abi.encode(before_)),
            "minted-ever burned identity retained"
        );
        p.tokenId = 1;
        (bool ok,) = address(this)
            .staticcall(abi.encodeCall(this.tokenRead, (nativeDependencies, nativeContext, 1, p)));
        require(!ok, "wrong serial cannot replace burned endpoint");
        p = _tokenPayload(2);
        p.animation[0] = 0x7b;
        (ok,) = address(this)
            .staticcall(abi.encodeCall(this.tokenRead, (nativeDependencies, nativeContext, 1, p)));
        require(!ok, "full output mutation rejected");
        p = _tokenPayload(2);
        p.image = hex"00";
        (ok,) = address(this)
            .staticcall(abi.encodeCall(this.tokenRead, (nativeDependencies, nativeContext, 1, p)));
        require(!ok, "nonempty image cannot inherit ABSENT");
    }

    function testCurrentNativePlansAndRuntimePinsFailClosedWithoutChangingOriginals() public {
        PreservationInventory.Item[] memory saved = NativeSources.nativeItems(nativeDependencies, nativeContext);
        S.Context memory changed = nativeContext;
        changed.nativeHash = bytes32(uint256(1));
        (bool ok,) =
            address(this).staticcall(abi.encodeCall(this.nativeRead, (nativeDependencies, changed)));
        require(!ok, "supplied native context is not authority");
        S.Dependencies memory wrong = nativeDependencies;
        wrong.codeHashes[4] = bytes32(uint256(1));
        (ok,) = address(this).staticcall(abi.encodeCall(this.nativeRead, (wrong, nativeContext)));
        require(!ok, "actual Router runtime binding");
        core.setMinted(3);
        (ok,) = address(this)
            .staticcall(abi.encodeCall(this.nativeRead, (nativeDependencies, nativeContext)));
        require(!ok, "new retained member invalidates complete old plan");
        core.setMinted(2);
        require(
            keccak256(abi.encode(NativeSources.nativeItems(nativeDependencies, nativeContext)))
                == keccak256(abi.encode(saved)),
            "exact healthy restoration"
        );
    }

    function testFuzzEveryTokenAnimationByteIsCommitted(uint32 offset, bytes1 mask) public {
        IStreamOnchainContentCheckpoint.TokenPayload memory p = _tokenPayload(1);
        p.animation[uint256(offset) % p.animation.length] ^= mask == 0 ? bytes1(uint8(1)) : mask;
        (bool ok,) = address(this)
            .staticcall(abi.encodeCall(this.tokenRead, (nativeDependencies, nativeContext, 0, p)));
        require(!ok, "actual leaf commits every animation byte");
    }

    function _tokenPayload(uint256 id)
        private
        view
        returns (IStreamOnchainContentCheckpoint.TokenPayload memory p)
    {
        StreamSnapshotTypes.NativeFacts memory n =
            StreamSnapshotSourceReads.requireCurrent(_dependencies(), 1);
        p.tokenId = id;
        p.image = imageBytes;
        p.animation = abi.encodePacked(
            "<html><head></head><body><script>const tokenId=",
            Strings.toString(id),
            ";const tokenHash='",
            Strings.toHexString(uint256(77), 32),
            "';const tokenDataBase64='AP8=';",
            n.source.script,
            "</script></body></html>"
        );
    }
}
