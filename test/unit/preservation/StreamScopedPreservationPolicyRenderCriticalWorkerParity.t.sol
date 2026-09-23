// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    ScopedPreservationReferenceFixtureV1
} from "./StreamScopedPreservationPolicyReferencePublicationV1.t.sol";
import {
    FrozenScopedRenderCriticalSourcesEa4 as FrozenSources
} from "../../helpers/ScopedRenderCriticalFrozenSourcesEa4.sol";
import {
    FrozenScopedRenderCriticalTokensEa4 as FrozenTokens
} from "../../helpers/ScopedRenderCriticalFrozenTokensEa4.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalSourceReadsV1 as Sources
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalSourceReadsV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalTokenReadsV1 as Tokens
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalTokenReadsV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalTypesV1 as C
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamRenderCriticalSourceTypes as D
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as I
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamScopedPreservationPolicyReferenceTypesV1 as Ref
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPreservationPolicyReferenceTypesV1.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as Content
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamStaticMetadataRouter as Router
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    IStreamRenderer as Renderer
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamCoreIdentity as Core
} from "../../../smart-contracts/interfaces/stream/core/IStreamCoreIdentity.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @dev Explicit finite source-read boundary. Every successful answer requires the
/// comparison host as caller, so the nested linked worker cannot substitute itself.
contract ScopedRenderCriticalCurrentCallerBoundary {
    address private immutable caller;
    mapping(bytes32 => bytes) private answers;
    mapping(bytes32 => bool) private known;

    constructor(address expectedCaller) {
        caller = expectedCaller;
    }

    function set(bytes calldata input, bytes calldata output) external {
        bytes32 key = keccak256(input);
        known[key] = true;
        answers[key] = output;
    }

    fallback(bytes calldata input) external returns (bytes memory) {
        require(msg.sender == caller, "original caller");
        bytes32 key = keccak256(input);
        require(known[key], "unconfigured boundary read");
        return answers[key];
    }
}

/// @notice Original EA4 bodies and fixed linked workers run from the same host.
/// @dev Positive token cases use the existing genuine scoped factory/checkpoint/output/
/// snapshot/reference publications with their explicitly typed Core/Artist/admission
/// boundaries. Current-context cases cover only early guards and bounded caller-sensitive
/// reads; they do not claim full WORK/conservation admission or all-stage inventory.
/// The frozen Token.Original is a distinct nominal type; comparisons use complete ABI
/// encodings, not field projections. No writes, permissions or gas caps are relaxed.
contract StreamScopedPreservationPolicyRenderCriticalWorkerParityTest is
    ScopedPreservationReferenceFixtureV1
{
    D.Dependencies internal inventoryD;
    C.Context internal inventoryC;
    Ref.SourceFacts internal inventoryF;

    function _inventory(uint8 terminalStatus, uint8 scopeKind) internal {
        _reference(terminalStatus, scopeKind);
        _publishReference();
        _inventoryContext();
    }

    function _inventoryContext() internal {
        inventoryD.targets = [
            address(core),
            address(metadata),
            address(schemas),
            address(snapshotStore),
            address(router),
            address(snapshotHost),
            address(referenceHost),
            address(artist),
            address(artist),
            address(artist),
            address(snapshotCoverage),
            address(externalArchive)
        ];
        for (uint256 i; i < 12; ++i) {
            inventoryD.codeHashes[i] = inventoryD.targets[i].codehash;
        }
        for (uint256 i; i < 5; ++i) {
            inventoryD.artistTargets[i] = address(artist);
            inventoryD.artistCodeHashes[i] = address(artist).codehash;
        }
        inventoryD.artistContentOwner = address(artist);
        inventoryD.artistContentOwnerCodeHash = address(artist).codehash;
        inventoryD.chainId = block.chainid;
        inventoryD.readGas = 2000000;
        inventoryD.sourceGas = 16000000;
        inventoryD.selectionGas = 16000000;
        inventoryD.snapshotGas = 256000000;
        inventoryD.referenceGas = 512000000;
        Ref.Receipt memory r = referenceHost.currentReference(publication.scope);
        inventoryF = referenceHost.referenceSource(r.observation.recordHash);
        inventoryC.scope = publication.scope;
        inventoryC.subject = inventoryF.scopeSubject;
        inventoryC.artistId = inventoryF.snapshotSource.artist.artistId;
        inventoryC.snapshot = inventoryF.snapshot;
        inventoryC.snapshotSource = inventoryF.snapshotSource;
        inventoryC.referenceRender = r;
        inventoryC.nativeHash = keccak256(abi.encode(inventoryF.snapshotSource));
        inventoryC.rootRecordHash = inventoryF.contentRootRecordHash;
        inventoryC.tokenInventoryHash = inventoryF.snapshotSource.membership.membershipHash;
        inventoryC.checkpointHash = inventoryF.snapshotSource.outputs.checkpointHash;
        inventoryC.outputManifestRecord = publication.outputManifestRecord;
        inventoryC.selectionId = inventoryF.snapshotSource.content.selectionId;
        inventoryC.selectionHash = inventoryF.snapshotSource.content.selectionHash;
        inventoryC.tokenCount = uint64(inventoryF.snapshotSource.membership.tokenCount);
    }

    function actualSourceAt(uint64 index) external view returns (uint256, Tokens.Original memory) {
        return Tokens.sourceAt(inventoryD, inventoryC, index);
    }

    function frozenSourceAt(uint64 index)
        external
        view
        returns (uint256, FrozenTokens.Original memory)
    {
        return FrozenTokens.sourceAt(inventoryD, inventoryC, index);
    }

    function actualCurrent(D.Dependencies memory d, StreamFinalityScope memory scope)
        external
        view
        returns (C.Context memory)
    {
        return Sources.current(d, scope);
    }

    function frozenCurrent(D.Dependencies memory d, StreamFinalityScope memory scope)
        external
        view
        returns (C.Context memory)
    {
        return FrozenSources.current(d, scope);
    }

    function _sameFailure(bytes memory actualInput, bytes memory frozenInput, bytes memory expected)
        internal
        view
    {
        (bool actualOK, bytes memory actual) = address(this).staticcall(actualInput);
        (bool frozenOK, bytes memory frozen) = address(this).staticcall(frozenInput);
        require(!actualOK && !frozenOK, "both refuse");
        require(keccak256(actual) == keccak256(expected), "exact current error");
        require(keccak256(frozen) == keccak256(expected), "exact original error");
    }

    function _sourceFailure(uint64 index, bytes memory expected) internal view {
        _sameFailure(
            abi.encodeCall(this.actualSourceAt, (index)),
            abi.encodeCall(this.frozenSourceAt, (index)),
            expected
        );
    }

    function _currentFailure(
        D.Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes memory expected
    ) internal view {
        _sameFailure(
            abi.encodeCall(this.actualCurrent, (d, scope)),
            abi.encodeCall(this.frozenCurrent, (d, scope)),
            expected
        );
    }

    function _digest(I.Item memory row, bytes memory original) internal pure {
        require(row.byteSize == original.length, "complete byte count");
        require(
            keccak256(row.digest) == keccak256(abi.encodePacked(keccak256(original))),
            "literal bytes digest"
        );
    }

    function _parity(uint64 index) internal view returns (bytes32 fingerprint) {
        bytes32 contextBefore = keccak256(abi.encode(inventoryD, inventoryC));
        (uint256 token, Tokens.Original memory current) =
            Tokens.sourceAt(inventoryD, inventoryC, index);
        (uint256 oldToken, FrozenTokens.Original memory original) =
            FrozenTokens.sourceAt(inventoryD, inventoryC, index);
        require(token == oldToken && token == 91 + index, "authoritative ordinal");
        require(
            keccak256(abi.encode(current)) == keccak256(abi.encode(original)),
            "complete Original including all returned memory"
        );
        Content.Payload memory payload = _payload(snapshotCapture)[index];
        I.Item[] memory rows = Tokens.tokenItems(inventoryD, inventoryC, index, payload);
        I.Item[] memory oldRows = FrozenTokens.tokenItems(inventoryD, inventoryC, index, payload);
        require(
            rows.length == 12 && keccak256(abi.encode(rows)) == keccak256(abi.encode(oldRows)),
            "all twelve original rows in order"
        );
        (bool exists, uint256 cid, uint256 serial, bool burned) =
            Core(address(core)).tokenCollectionIdentity(token);
        require(exists && serial != 0, "original Core identity");
        require(
            keccak256(current.identity)
                == keccak256(abi.encode(token, cid, serial, burned, uint8(burned ? 3 : 2), index)),
            "serial and lifecycle are original Core facts"
        );
        _digest(rows[4], current.identity);
        _digest(rows[5], current.entropy);
        _digest(rows[6], abi.encode(current.selection));
        _digest(rows[7], abi.encode(current.output));
        _digest(rows[8], current.config);
        _digest(rows[9], current.source);
        Router.ConfigRecord memory config = abi.decode(current.config, (Router.ConfigRecord));
        require(
            config.recordHash == current.selection.configRecordHash && config.recordHash != 0,
            "hash scratch mutation does not escape through original config bytes"
        );
        require(
            current.entropy.length == 320 && current.readiness.code.length != 0,
            "all original entropy and readiness returned"
        );
        if (current.output.entropy.terminal) {
            require(
                current.terminalAdmission.length == 608 && !current.output.entropy.finalized,
                "full terminal admission returned"
            );
            _digest(rows[11], current.terminalAdmission);
        } else {
            require(
                current.output.entropy.finalized && current.terminalAdmission.length == 0
                    && rows[11].kind == I.Kind.ABSENT,
                "finalized branch has no terminal admission"
            );
        }
        require(
            contextBefore == keccak256(abi.encode(inventoryD, inventoryC)), "input context retained"
        );
        fingerprint = keccak256(abi.encode(token, current, rows));
    }

    function testRenderCriticalWorkerReleaseTerminalAndFinalizedOriginalParity() public {
        _inventory(1, 2);
        require(inventoryC.tokenCount == 2, "both branches required");
        _parity(0);
        _parity(1);
    }

    function testRenderCriticalWorkerExpiredTokenOriginalParity() public {
        _inventory(2, 1);
        _parity(0);
        (, Tokens.Original memory o) = Tokens.sourceAt(inventoryD, inventoryC, 0);
        require(
            o.output.entropy.status == 2 && o.output.entropy.mode == 2 && o.output.entropy.terminal
                && !o.output.entropy.finalized && o.output.entropy.seed == 0,
            "expired original is never manufactured finalization"
        );
    }

    function testRenderCriticalWorkerSeasonOriginalParity() public {
        _inventory(1, 3);
        require(inventoryC.tokenCount == 2, "whole season");
        _parity(0);
        _parity(1);
    }

    function testRenderCriticalWorkerLateSourceRefusalAndIdenticalRetry() public {
        _inventory(1, 2);
        bytes32 before_ = _parity(1);
        (, Tokens.Original memory o) = Tokens.sourceAt(inventoryD, inventoryC, 1);
        (Router.RawSource memory source, Renderer.MetadataConfig memory cfg) =
            abi.decode(o.source, (Router.RawSource, Renderer.MetadataConfig));
        source.chainId += 1;
        bytes memory input = abi.encodeCall(
            Router.staticRenderSourceForConfig,
            (inventoryC.scope.collectionId, o.selection.configRecordHash)
        );
        snapshotVm.mockCall(address(router), input, abi.encode(source, cfg));
        _sourceFailure(1, abi.encodeWithSelector(I.InvalidInventoryItem.selector));
        snapshotVm.mockCall(address(router), input, o.source);
        require(_parity(1) == before_, "repair only original producer bytes; exact retry");
    }

    function testRenderCriticalWorkerMalformedOutputAndAdmissionRefusalsRestore() public {
        _inventory(1, 2);
        bytes32 before_ = _parity(1);
        Content.Output memory original = snapshotContent.outputAt(snapshotCapture.id, 1);
        bytes memory input = abi.encodeCall(Content.outputAt, (snapshotCapture.id, uint256(1)));
        bytes memory originalBytes = abi.encode(original);
        require(originalBytes.length == 1152, "fixed original output shape");
        snapshotVm.mockCall(address(snapshotContent), input, new bytes(1151));
        _sourceFailure(
            1, abi.encodeWithSelector(I.InventoryRead.selector, address(snapshotContent))
        );
        snapshotVm.mockCall(address(snapshotContent), input, bytes.concat(originalBytes, hex"00"));
        _sourceFailure(
            1, abi.encodeWithSelector(I.InventoryRead.selector, address(snapshotContent))
        );
        Content.Output memory bad = abi.decode(originalBytes, (Content.Output));
        bad.preservationAdmission.registrationHash = 0;
        snapshotVm.mockCall(address(snapshotContent), input, abi.encode(bad));
        _sourceFailure(1, abi.encodeWithSelector(I.InventorySourceChanged.selector));
        snapshotVm.mockCall(address(snapshotContent), input, originalBytes);
        require(_parity(1) == before_, "same context and payload after exact original restoration");
    }

    function testRenderCriticalWorkerCoreIdentityRefusalAndUnchangedRetry() public {
        _inventory(1, 2);
        bytes32 before_ = _parity(1);
        (bool exists, uint256 cid, uint256 serial, bool burned) =
            Core(address(core)).tokenCollectionIdentity(92);
        bytes memory input = abi.encodeCall(Core.tokenCollectionIdentity, (uint256(92)));
        snapshotVm.mockCall(address(core), input, abi.encode(exists, cid, uint256(0), burned));
        _sourceFailure(1, abi.encodeWithSelector(I.InvalidInventoryItem.selector));
        snapshotVm.mockCall(address(core), input, abi.encode(exists, cid, serial, burned));
        require(_parity(1) == before_, "original serial restored without reseeding context");
    }

    function _currentBoundary()
        internal
        returns (
            D.Dependencies memory d,
            ScopedRenderCriticalCurrentCallerBoundary referenceBoundary,
            ScopedRenderCriticalCurrentCallerBoundary coverage,
            ScopedRenderCriticalCurrentCallerBoundary archive
        )
    {
        ScopedRenderCriticalCurrentCallerBoundary base =
            new ScopedRenderCriticalCurrentCallerBoundary(address(this));
        referenceBoundary = new ScopedRenderCriticalCurrentCallerBoundary(address(this));
        coverage = new ScopedRenderCriticalCurrentCallerBoundary(address(this));
        archive = new ScopedRenderCriticalCurrentCallerBoundary(address(this));
        for (uint256 i; i < 12; ++i) {
            d.targets[i] = address(base);
        }
        d.targets[6] = address(referenceBoundary);
        d.targets[10] = address(coverage);
        d.targets[11] = address(archive);
        for (uint256 i; i < 12; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        for (uint256 i; i < 5; ++i) {
            d.artistTargets[i] = address(base);
            d.artistCodeHashes[i] = address(base).codehash;
        }
        d.artistContentOwner = address(base);
        d.artistContentOwnerCodeHash = address(base).codehash;
        d.chainId = block.chainid;
        d.readGas = 1000000;
        d.sourceGas = 1000000;
        d.selectionGas = 1000000;
        d.snapshotGas = 1000000;
        d.referenceGas = 1000000;
        referenceBoundary.set(
            abi.encodeWithSignature("archiveCoverage()"), abi.encode(address(archive))
        );
        coverage.set(abi.encodeWithSignature("core()"), abi.encode(address(base)));
        archive.set(abi.encodeWithSignature("core()"), abi.encode(address(base)));
    }

    function testRenderCriticalCurrentScopeChainGasAndRuntimeGuardsMatchFrozen() public {
        (D.Dependencies memory d,,,) = _currentBoundary();
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        _currentFailure(d, scope, abi.encodeWithSelector(I.InventorySourceChanged.selector));
        scope.scopeType = StreamFinalityScopeType.TOKEN;
        scope.tokenId = 91;
        D.Dependencies memory bad = abi.decode(abi.encode(d), (D.Dependencies));
        bad.chainId += 1;
        _currentFailure(bad, scope, abi.encodeWithSelector(I.InventorySourceChanged.selector));
        bad = abi.decode(abi.encode(d), (D.Dependencies));
        bad.readGas = 49999;
        _currentFailure(bad, scope, abi.encodeWithSelector(I.InventorySourceChanged.selector));
        bad = abi.decode(abi.encode(d), (D.Dependencies));
        bad.codeHashes[4] = keccak256("wrong original Router runtime");
        _currentFailure(bad, scope, abi.encodeWithSelector(I.InventoryRead.selector, d.targets[4]));
        _currentFailure(d, scope, abi.encodeWithSelector(I.InventoryRead.selector, d.targets[6]));
    }

    function testRenderCriticalCurrentCallerSensitiveShortCircuitAndMalformedDependencyParity()
        public
    {
        (
            D.Dependencies memory d,
            ScopedRenderCriticalCurrentCallerBoundary referenceBoundary,
            ScopedRenderCriticalCurrentCallerBoundary coverage,
            ScopedRenderCriticalCurrentCallerBoundary archive
        ) = _currentBoundary();
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 91, 0);
        // Correct three answers reach the deliberately unavailable dependencies read.
        _currentFailure(
            d, scope, abi.encodeWithSelector(I.InventoryRead.selector, address(referenceBoundary))
        );
        referenceBoundary.set(abi.encodeWithSignature("archiveCoverage()"), abi.encode(address(0)));
        _currentFailure(d, scope, abi.encodeWithSelector(I.InventorySourceChanged.selector));
        referenceBoundary.set(
            abi.encodeWithSignature("archiveCoverage()"), abi.encode(address(archive))
        );
        coverage.set(abi.encodeWithSignature("core()"), abi.encode(address(0)));
        _currentFailure(d, scope, abi.encodeWithSelector(I.InventorySourceChanged.selector));
        coverage.set(abi.encodeWithSignature("core()"), abi.encode(d.targets[0]));
        archive.set(abi.encodeWithSignature("core()"), abi.encode(address(0)));
        _currentFailure(d, scope, abi.encodeWithSelector(I.InventorySourceChanged.selector));
        archive.set(abi.encodeWithSignature("core()"), abi.encode(d.targets[0]));
        referenceBoundary.set(abi.encodeWithSignature("dependencies()"), new bytes(607));
        _currentFailure(
            d, scope, abi.encodeWithSelector(I.InventoryRead.selector, address(referenceBoundary))
        );
        referenceBoundary.set(abi.encodeWithSignature("dependencies()"), new bytes(609));
        _currentFailure(
            d, scope, abi.encodeWithSelector(I.InventoryRead.selector, address(referenceBoundary))
        );
        Ref.Dependencies memory original;
        original.chainId = d.chainId;
        uint256[7] memory roles = [uint256(0), 1, 2, 3, 4, 5, 11];
        for (uint256 i; i < 7; ++i) {
            original.targets[i] = d.targets[roles[i]];
            original.codeHashes[i] = d.codeHashes[roles[i]];
        }
        // A canonical but foreign chain reaches the explicit semantic join.
        original.chainId += 1;
        bytes memory foreign = abi.encode(original);
        require(foreign.length == 608, "original dependencies shape");
        referenceBoundary.set(abi.encodeWithSignature("dependencies()"), foreign);
        _currentFailure(d, scope, abi.encodeWithSelector(I.InventorySourceChanged.selector));
    }
}
