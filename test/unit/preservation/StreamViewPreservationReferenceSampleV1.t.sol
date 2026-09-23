// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ViewPreservationCheckpointFixtureV1.sol";
import {
    StreamViewPreservationReferenceTypesV1 as Ref
} from "../../../smart-contracts/interfaces/stream/preservation/StreamViewPreservationReferenceTypesV1.sol";
import {
    StreamReferenceRenderTypes as RR
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamViewPreservationSnapshotTypesV1 as SS
} from "../../../smart-contracts/interfaces/stream/metadata/StreamViewPreservationSnapshotTypesV1.sol";
import {
    StreamExternalArtifactTypes as EA
} from "../../../smart-contracts/interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import {
    StreamReferenceRenderDefinitions as Def
} from "../../../smart-contracts/domains/records/StreamReferenceRenderDefinitions.sol";
import {
    StreamViewPreservationReferenceSampleReadsV1 as Samples
} from "../../../smart-contracts/domains/preservation/StreamViewPreservationReferenceSampleReadsV1.sol";
import {
    IStreamViewPreservationContentCheckpointV1 as CP
} from "../../../smart-contracts/interfaces/stream/finality/IStreamViewPreservationContentCheckpointV1.sol";

interface ViewReferenceSampleVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
}

contract ViewReferenceSampleProbe {
    function sample(
        Ref.Dependencies memory d,
        SS.Dependencies memory graph,
        SS.Source memory source,
        uint64 ordinal,
        RR.Capture memory capture,
        bool current
    ) external view returns (Ref.Sample memory) {
        return Samples.requireSample(d, graph, source, ordinal, capture, current);
    }
}

/// @notice Actual checkpoint/producer/State/Store/Renderer. Snapshot Source is supplied at the
/// worker boundary after actual checkpoint currentSource; Archive/currentPair is explicit typed
/// data. This does not prove snapshot/root/reference publication or the original op17 ceremony.
contract StreamViewPreservationReferenceSampleV1Test is ViewPreservationCheckpointFixtureV1 {
    ViewReferenceSampleProbe private referenceProbe;
    PolicyViewWire private archive;
    Ref.Dependencies private d;
    SS.Dependencies private graph;
    SS.Source private source;
    RR.Capture private capture;
    EA.Coverage private coverage;
    EA.CurrentPair private pair;
    bytes32 private checkpointId;

    function _sampleInit(bool burned) private {
        _build(1, burned ? 11 : 0);
        checkpointId = checkpointHost.begin(scope, keccak256("reference sample"));
        _append(checkpointId, 11, burned);
        checkpointHost.seal(checkpointId);
        source.scope = scope;
        source.membership = membership;
        source.adoption = checkpointHost.currentSource(scope);
        source.outputs.header.checkpointId = checkpointId;
        source.artist.artistId = keccak256("typed archive Artist");
        archive = new PolicyViewWire();
        referenceProbe = new ViewReferenceSampleProbe();
        d.targets[0] = address(core);
        d.targets[4] = address(records);
        d.targets[6] = address(archive);
        d.codeHashes[0] = address(core).codehash;
        d.codeHashes[4] = address(records).codehash;
        d.codeHashes[6] = address(archive).codehash;
        d.chainId = block.chainid;
        d.readGas = 1000000;
        d.sourceGas = 16000000;
        d.snapshotGas = 16000000;
        d.archiveGas = 1000000;
        graph.targets[6] = address(checkpointHost);
        graph.codeHashes[6] = address(checkpointHost).codehash;
        string memory html;
        if (burned) (, html) = serving.historicalPreservationViewHTML(adopted, 11);
        else (, html) = serving.preservationViewHTML(scope, 11);
        CT.Output memory row = checkpointHost.outputAt(checkpointId, 0);
        capture.tokenId = 11;
        capture.collectionSerial = 7;
        capture.metadataJSONHash = row.jsonHash;
        capture.htmlHash = row.htmlHash;
        capture.htmlBytes = row.htmlBytes;
        capture.animationHTML = bytes(html);
        capture.objectHash = keccak256("PNG object");
        capture.coverageHash = keccak256("dual coverage");
        capture.sourceSha256 = sha256(bytes(html));
        capture.repeatCaptureSha256 =
            [keccak256("repeated PNG SHA256"), keccak256("repeated PNG SHA256")];
        capture.capturedAt = 100;
        coverage = EA.Coverage(
            capture.coverageHash,
            capture.objectHash,
            source.artist.artistId,
            keccak256("PNG content"),
            capture.repeatCaptureSha256[0],
            keccak256("Arweave root"),
            200,
            keccak256("family1"),
            keccak256("family2"),
            keccak256("receipt1"),
            keccak256("receipt2"),
            keccak256("fixity1"),
            keccak256("fixity2"),
            keccak256("checkpoint"),
            keccak256("archive profile")
        );
        pair = EA.CurrentPair(
            coverage.objectHash,
            coverage.artistId,
            coverage.contentHash,
            coverage.sha256Digest,
            coverage.arweaveDataRoot,
            coverage.byteSize,
            coverage.firstFamilyRecordHash,
            coverage.secondFamilyRecordHash,
            coverage.firstReceiptHash,
            coverage.secondReceiptHash,
            coverage.firstFixityHash,
            coverage.secondFixityHash,
            coverage.checkpointHash,
            coverage.profileHash
        );
        _archive();
    }

    function _archive() private {
        _answer(
            archive, "coverage(bytes32)", abi.encode(coverage.coverageHash), abi.encode(coverage)
        );
        _answer(
            archive,
            "requireCoverage(bytes32,bytes32,bytes32)",
            abi.encode(coverage.coverageHash, coverage.artistId, coverage.objectHash),
            abi.encode(coverage)
        );
        _answer(
            archive,
            "currentReceiptPair(bytes32,bytes32,bytes32,bytes32)",
            abi.encode(
                coverage.firstReceiptHash,
                coverage.secondReceiptHash,
                coverage.artistId,
                coverage.objectHash
            ),
            abi.encode(pair)
        );
        _answer(
            archive,
            "objectIdentity(bytes32)",
            abi.encode(coverage.objectHash),
            abi.encode(
                EA.ObjectIdentity(
                    coverage.artistId,
                    Def.PNG_SCHEMA_ID,
                    keccak256("RAW_BYTES"),
                    coverage.contentHash,
                    coverage.sha256Digest,
                    coverage.arweaveDataRoot,
                    coverage.byteSize,
                    keccak256("IANA:image/png"),
                    Def.FORMAT_CATALOG_ID,
                    Def.FORMAT_CATALOG_HASH
                )
            )
        );
    }

    function _read(RR.Capture memory c, bool current) private view returns (Ref.Sample memory) {
        return referenceProbe.sample(d, graph, source, 0, c, current);
    }

    function testActualTerminalOutputAndLiteralSampleCommitment() public {
        _sampleInit(false);
        Ref.Sample memory got = _read(capture, true);
        CT.Output memory expected = checkpointHost.outputAt(checkpointId, 0);
        require(
            keccak256(abi.encode(got)) == keccak256(abi.encode(uint64(0), expected, coverage)),
            "literal sample"
        );
        require(
            got.output.entropy.terminal && !got.output.entropy.finalized
                && got.output.entropy.status == 1 && got.output.entropy.seed == 0,
            "terminal is not finalized"
        );
        require(
            keccak256(abi.encode(_read(capture, false))) == keccak256(abi.encode(got)),
            "recorded and fresh same receipt"
        );
    }

    function testBurnedUsesHistoricalOutputAndOriginalPermanentIdentity() public {
        _sampleInit(true);
        Ref.Sample memory got = _read(capture, true);
        require(
            got.output.tokenId == 11 && got.output.collectionSerial == 7 && got.output.burned
                && got.output.lifecycle == 3 && got.output.servingKind == 2,
            "burned facts"
        );
        vm.expectRevert(abi.encodeWithSelector(V.InvalidViewAdoption.selector));
        serving.preservationViewHTML(scope, 11);
        (, string memory html) = serving.historicalPreservationViewHTML(adopted, 11);
        require(keccak256(bytes(html)) == got.output.htmlHash, "historical exact");
    }

    function testIdentityOrdinalAndSerialCannotBeSubstituted() public {
        _sampleInit(false);
        RR.Capture memory c = capture;
        c.tokenId = 12;
        vm.expectRevert(abi.encodeWithSelector(Ref.InvalidViewPreservationReference.selector));
        _read(c, true);
        c = capture;
        c.collectionSerial = 8;
        vm.expectRevert(abi.encodeWithSelector(Ref.InvalidViewPreservationReference.selector));
        _read(c, true);
        vm.expectRevert(abi.encodeWithSelector(Ref.InvalidViewPreservationReference.selector));
        referenceProbe.sample(d, graph, source, 1, capture, true);
        _read(capture, true);
    }

    function testFreshOutputDriftRejectsSavedCheckpointThenRestores() public {
        _sampleInit(false);
        _preserved(11, bytes('{"state":"changed non-sanction fact"}'));
        vm.expectRevert(abi.encodeWithSelector(Ref.InvalidViewPreservationReference.selector));
        _read(capture, true);
        _preserved(11, bytes('{"state":"typed_live"}'));
        _read(capture, true);
    }

    function testCapturedHTMLRepeatDigestAndTimeAreIndependent() public {
        _sampleInit(false);
        RR.Capture memory c = capture;
        c.animationHTML = bytes("different HTML");
        vm.expectRevert(abi.encodeWithSelector(Ref.InvalidViewPreservationReference.selector));
        _read(c, true);
        c = capture;
        c.repeatCaptureSha256[1] = bytes32(uint256(8));
        vm.expectRevert(abi.encodeWithSelector(Ref.InvalidViewPreservationReference.selector));
        _read(c, true);
        c = capture;
        c.sourceSha256 = bytes32(uint256(9));
        vm.expectRevert(abi.encodeWithSelector(Ref.InvalidViewPreservationReference.selector));
        _read(c, true);
        c = capture;
        c.capturedAt = uint64(block.timestamp + 1);
        vm.expectRevert(abi.encodeWithSelector(Ref.InvalidViewPreservationReference.selector));
        _read(c, true);
        _read(capture, true);
    }

    function testCurrentArchivePairCannotBecomeHistoricalShortcut() public {
        _sampleInit(false);
        bytes32 saved = pair.firstFixityHash;
        pair.firstFixityHash = 0;
        _archive();
        vm.expectRevert(abi.encodeWithSelector(RR.InvalidReferenceRender.selector));
        _read(capture, true);
        _read(capture, false);
        pair.firstFixityHash = saved;
        _archive();
        _read(capture, true);
    }

    function testWholeCheckpointRowAndActualCorePinsAreCompared() public {
        _sampleInit(false);
        CT.Output memory row = checkpointHost.outputAt(checkpointId, 0);
        row.entropy.policyHash = bytes32(uint256(71));
        ViewReferenceSampleVm(address(vm))
            .mockCall(
                address(checkpointHost),
                abi.encodeCall(CP.outputAt, (checkpointId, uint256(0))),
                abi.encode(row)
            );
        vm.expectRevert(abi.encodeWithSelector(Ref.InvalidViewPreservationReference.selector));
        _read(capture, true);
        ViewReferenceSampleVm(address(vm)).clearMockedCalls();
        _read(capture, true);
        Ref.Dependencies memory foreign = d;
        foreign.codeHashes[0] = bytes32(uint256(7));
        vm.expectRevert(abi.encodeWithSelector(Ref.InvalidViewPreservationReference.selector));
        referenceProbe.sample(foreign, graph, source, 0, capture, true);
        _read(capture, true);
    }
}
