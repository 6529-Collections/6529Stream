// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamPreservationPolicyReferenceRecordsV1 as Records } from
    "../../../smart-contracts/domains/preservation/StreamPreservationPolicyReferenceRecordsV1.sol";
import { StreamPreservationPolicyReferenceSourceReadsV1 as Sources } from
    "../../../smart-contracts/domains/preservation/StreamPreservationPolicyReferenceSourceReadsV1.sol";
import { StreamPreservationPolicyReferenceFamiliesV2 as F } from
    "../../../smart-contracts/domains/preservation/StreamPreservationPolicyReferenceFamiliesV2.sol";
import { StreamPreservationPolicyReferenceTypesV1 as T } from
    "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationPolicyReferenceTypesV1.sol";
import { StreamReferenceRenderTypes as R } from
    "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import { StreamPreservationTokenProducerProfilesV1 as Profiles } from
    "../../../smart-contracts/interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import { StreamSnapshotManifestBytes as Bytes } from
    "../../../smart-contracts/domains/records/StreamSnapshotManifestBytes.sol";
import { StreamSchemaDocumentStore } from
    "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";

/// @dev Uses genuine immutable manifest chunks. The baseline methods retain the original
/// ea4cf6b source bodies as differential oracles, without invoking the new reader helper.
contract PreservationReferenceRecordCapacityProbe {
    StreamSchemaDocumentStore private immutable _store = new StreamSchemaDocumentStore();
    Bytes.Manifest private _original;
    Bytes.Manifest private _payload;
    T.Receipt private _receipt;

    function setPayload(bytes memory raw) external {
        delete _payload;
        _retain(_payload, raw);
    }

    function setOriginal(bytes memory raw, T.Receipt memory receipt) external {
        delete _original;
        _retain(_original, raw);
        _receipt = receipt;
    }

    function corruptPayloadHash() external { _payload.contentHash = bytes32(uint256(1)); }

    function stateHash() external view returns (bytes32) {
        return keccak256(abi.encode(_original, _payload, _receipt));
    }

    function sourceFor(bytes32 family) external view returns (bytes memory) {
        return Records.source(_payload, family);
    }

    function originalProfileSource() external view returns (bytes memory) {
        return Records.source(_payload);
    }

    function recordBytes() external view returns (bytes memory) {
        return Records.recordBytes(_original, _receipt);
    }

    function current(bytes32 family) external view {
        T.Dependencies memory d;
        Records.requireCurrent(_original, _payload, _receipt, d, family);
    }

    function baselineCurrent(bytes32 family) external view {
        T.Dependencies memory d;
        Records.definitions(d, family);
        T.SourceFacts memory f = Sources.requireSource(d, _publication(), true, family);
        if (
            Sources.sourceHash(d, f, family) != _receipt.observation.sourcesHash
                || Bytes.requireIntact(_payload) != _receipt.observation.payloadHash
        ) revert T.InvalidPolicyReference();
    }

    function baselineRecordBytes() external view returns (bytes memory) {
        return abi.encode(_publication(), _receipt);
    }

    function baselineSource(bytes32 family) external view returns (bytes memory) {
        bytes memory raw = Bytes.read(_payload);
        (
            bytes32 domain,
            uint256 chain,
            address host,
            T.Publication memory p,
            T.Receipt memory r,
            T.SourceFacts memory f,
            bytes memory environment
        ) = abi.decode(
            raw, (bytes32, uint256, address, T.Publication, T.Receipt, T.SourceFacts, bytes)
        );
        if (
            domain != F.payloadDomain(family, false)
                || keccak256(raw)
                    != keccak256(abi.encode(domain, chain, host, p, r, f, environment))
        ) revert T.InvalidPolicyReference();
        return abi.encode(f);
    }

    function _publication() private view returns (T.Publication memory p) {
        bytes memory raw = Bytes.read(_original);
        p = abi.decode(raw, (T.Publication));
        if (keccak256(raw) != keccak256(abi.encode(p))) revert T.InvalidPolicyReference();
    }

    function _retain(Bytes.Manifest storage manifest, bytes memory raw) private {
        for (uint256 offset; offset < raw.length; offset += 8192) {
            uint256 size = raw.length - offset;
            if (size > 8192) size = 8192;
            bytes memory chunk = new bytes(size);
            for (uint256 i; i < size; ++i) chunk[i] = raw[offset + i];
            _store.publishChunk(chunk);
        }
        Bytes.retain(manifest, address(_store), raw);
    }
}

contract StreamPreservationPolicyReferenceRecordReadsCapacityTest {
    function testOriginalFamilySourceMatchesExactBaselineAcrossChunks() public {
        _sourceRoundTrip(Profiles.ORIGINAL_PROFILE);
    }

    function testFamilyV2SourceMatchesExactBaselineAcrossChunks() public {
        _sourceRoundTrip(Profiles.FAMILY_PROFILE);
    }

    function testSourceManifestValidationPrecedesInvalidFamily() public {
        PreservationReferenceRecordCapacityProbe h = new PreservationReferenceRecordCapacityProbe();
        _sourceFailure(h, bytes32(uint256(7)), Bytes.InvalidSnapshotManifest.selector);
        (bytes memory raw,) = _payload(Profiles.ORIGINAL_PROFILE, address(h));
        h.setPayload(raw);
        h.corruptPayloadHash();
        _sourceFailure(h, bytes32(uint256(7)), Bytes.InvalidSnapshotManifest.selector);
    }

    function testIntactSourceInvalidFamilyAndWrongDomainRetainErrors() public {
        PreservationReferenceRecordCapacityProbe h = new PreservationReferenceRecordCapacityProbe();
        (bytes memory raw,) = _payload(Profiles.ORIGINAL_PROFILE, address(h));
        h.setPayload(raw);
        _sourceFailure(h, bytes32(uint256(7)), F.InvalidPreservationReferenceFamily.selector);
        _sourceFailure(h, Profiles.FAMILY_PROFILE, T.InvalidPolicyReference.selector);
    }

    function testNoncanonicalAndTruncatedSourceRetainExactRevertBytes() public {
        PreservationReferenceRecordCapacityProbe h = new PreservationReferenceRecordCapacityProbe();
        (bytes memory raw,) = _payload(Profiles.ORIGINAL_PROFILE, address(h));
        h.setPayload(bytes.concat(raw, hex"00"));
        _sourceFailure(h, Profiles.ORIGINAL_PROFILE, T.InvalidPolicyReference.selector);
        h.setPayload(hex"123456");
        _sameFailure(h, abi.encodeCall(h.sourceFor, (Profiles.ORIGINAL_PROFILE)),
            abi.encodeCall(h.baselineSource, (Profiles.ORIGINAL_PROFILE)));
    }

    function testRecordBytesPreservePublicationAndReceiptExactly() public {
        PreservationReferenceRecordCapacityProbe h = new PreservationReferenceRecordCapacityProbe();
        (T.Publication memory p, T.Receipt memory r,) = _facts();
        h.setOriginal(abi.encode(p), r);
        bytes32 before = h.stateHash();
        bytes memory result = h.recordBytes();
        require(keccak256(result) == keccak256(abi.encode(p, r)), "exact original record bytes");
        require(keccak256(result) == keccak256(h.baselineRecordBytes()), "baseline record parity");
        require(before == h.stateHash(), "read mutated manifest or receipt");
    }

    function testRecordBytesRejectNoncanonicalPublicationExactly() public {
        PreservationReferenceRecordCapacityProbe h = new PreservationReferenceRecordCapacityProbe();
        (T.Publication memory p, T.Receipt memory r,) = _facts();
        h.setOriginal(bytes.concat(abi.encode(p), hex"00"), r);
        bytes memory reason = _sameFailure(h, abi.encodeCall(h.recordBytes, ()),
            abi.encodeCall(h.baselineRecordBytes, ()));
        require(bytes4(reason) == T.InvalidPolicyReference.selector, "original canonical error");
    }

    function testCurrentDefinitionsStillFailBeforeReadingMissingManifests() public {
        PreservationReferenceRecordCapacityProbe h = new PreservationReferenceRecordCapacityProbe();
        bytes memory reason = _sameFailure(h, abi.encodeCall(h.current, (bytes32(uint256(7)))),
            abi.encodeCall(h.baselineCurrent, (bytes32(uint256(7)))));
        require(bytes4(reason) == F.InvalidPreservationReferenceFamily.selector, "definitions before manifests");
        _sameFailure(h, abi.encodeCall(h.current, (Profiles.ORIGINAL_PROFILE)),
            abi.encodeCall(h.baselineCurrent, (Profiles.ORIGINAL_PROFILE)));
    }

    function _sourceRoundTrip(bytes32 family) private {
        PreservationReferenceRecordCapacityProbe h = new PreservationReferenceRecordCapacityProbe();
        (bytes memory raw, bytes memory expected) = _payload(family, address(h));
        require(raw.length > 8192, "exercise original chunk boundary");
        h.setPayload(raw);
        bytes32 before = h.stateHash();
        bytes memory result = h.sourceFor(family);
        require(keccak256(result) == keccak256(expected), "every source field retained");
        require(keccak256(result) == keccak256(h.baselineSource(family)), "baseline source parity");
        if (family == Profiles.ORIGINAL_PROFILE) {
            require(keccak256(h.originalProfileSource()) == keccak256(result), "original overload unchanged");
        }
        require(h.stateHash() == before, "source read mutated storage");
    }

    function _sourceFailure(PreservationReferenceRecordCapacityProbe h, bytes32 family, bytes4 error_) private view {
        bytes memory reason = _sameFailure(h, abi.encodeCall(h.sourceFor, (family)),
            abi.encodeCall(h.baselineSource, (family)));
        require(bytes4(reason) == error_, "original source error selector");
    }

    function _sameFailure(PreservationReferenceRecordCapacityProbe h, bytes memory candidate, bytes memory baseline)
        private view returns (bytes memory reason)
    {
        (bool ok, bytes memory actual) = address(h).staticcall(candidate);
        (bool oldOk, bytes memory expected) = address(h).staticcall(baseline);
        require(!ok && !oldOk && keccak256(actual) == keccak256(expected), "exact revert parity");
        return actual;
    }

    function _payload(bytes32 family, address host) private view returns (bytes memory raw, bytes memory expected) {
        (T.Publication memory p, T.Receipt memory r, T.SourceFacts memory f) = _facts();
        bytes memory environment = new bytes(9000);
        for (uint256 i; i < environment.length; ++i) environment[i] = bytes1(uint8(i));
        raw = abi.encode(F.payloadDomain(family, false), block.chainid, host, p, r, f, environment);
        expected = abi.encode(f);
    }

    function _facts() private view returns (T.Publication memory p, T.Receipt memory r, T.SourceFacts memory f) {
        p.scope.collectionId = type(uint256).max - 1;
        p.observation.collectionId = p.scope.collectionId;
        p.observation.referenceId = keccak256("literal reference");
        p.observation.captures = new R.Capture[](2);
        p.observation.captures[0].tokenId = type(uint256).max;
        p.observation.captures[0].animationHTML = hex"000102ff";
        p.observation.captures[1].tokenId = type(uint256).max - 3;
        p.observation.captures[1].animationHTML = bytes("<svg>exact</svg>");
        p.observation.environment.engineName = "original engine";
        p.observation.environment.packageFiles = new R.PackageFile[](1);
        p.observation.environment.packageFiles[0] = R.PackageFile("bin/engine", type(uint64).max, keccak256("engine"));
        p.observation.environment.platformPrerequisites = new R.PackageFile[](0);
        p.observation.manifestURI = "ipfs://literal-publication";
        r.scopeSubject = keccak256("receipt subject");
        r.observation.recorder = address(this);
        r.observation.recordHash = keccak256("retained record");
        r.observation.payloadBytes = type(uint32).max;
        r.observation.recordedAt = type(uint64).max;
        f.scopeSubject = keccak256("source subject");
        f.snapshot.revision = type(uint64).max;
        f.snapshotSource.scope.collectionId = type(uint256).max - 9;
        f.contentRootRecordHash = keccak256("content root");
        f.samples = new T.Sample[](2);
        for (uint256 i; i < 2; ++i) {
            f.samples[i].membershipIndex = type(uint64).max - uint64(i);
            f.samples[i].observation.tokenId = type(uint256).max - i;
            f.samples[i].observation.collectionSerial = type(uint256).max - i - 2;
            f.samples[i].observation.originalCoordinator = address(this);
            f.samples[i].preservation.producer = address(uint160(0x100 + i));
            f.samples[i].preservation.profile = keccak256(abi.encode("profile", i));
            f.samples[i].preservationAdmission.registry = address(uint160(0x200 + i));
            f.samples[i].preservationAdmission.goldenHash = keccak256(abi.encode("golden", i));
        }
    }
}
