// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    ScopedPreservationReferenceFixtureV1
} from "./StreamScopedPreservationPolicyReferencePublicationV1.t.sol";
import {
    FrozenScopedReferenceSourceFcda as Frozen
} from "../../helpers/ScopedReferenceSourceFrozenFcda.sol";
import {
    StreamScopedPreservationPolicyReferenceSourceReadsV1 as Candidate
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyReferenceSourceReadsV1.sol";
import {
    StreamScopedPreservationReferenceSnapshotWorkerV1 as SnapshotWorker
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationReferenceSnapshotWorkerV1.sol";
import {
    StreamScopedPreservationPolicyReferenceTypesV1 as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPreservationPolicyReferenceTypesV1.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as S
} from "../../../smart-contracts/interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamExternalArtifactTypes as E
} from "../../../smart-contracts/interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Profiles
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    StreamPreservationPolicyReferenceFamiliesV2 as Families
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyReferenceFamiliesV2.sol";
import {
    StreamFinalityRouterEvidence as Reads
} from "../../../smart-contracts/domains/finality/StreamFinalityRouterEvidence.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1 as Snap
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
import {
    IStreamExternalArtifactCoverage as Archive
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamExternalArtifactCoverage.sol";
import { IERC165 } from "../../../smart-contracts/vendor/openzeppelin/IERC165.sol";

interface ScopedReferenceSourceCapacityVm {
    function mockCallRevert(address target, bytes calldata input, bytes calldata result) external;
    function expectCall(address target, bytes calldata input, uint64 count) external;
}

/// @dev Exact typed graph transport only; this is not publication or source admission.
contract ScopedReferenceSourceGraphCaller {
    address private immutable caller;
    mapping(bytes32 => bytes) private values;
    mapping(bytes32 => bool) private configured;

    constructor(address expected) {
        caller = expected;
    }

    function set(bytes calldata input, bytes calldata value) external {
        values[keccak256(input)] = value;
        configured[keccak256(input)] = true;
    }

    fallback(bytes calldata input) external returns (bytes memory) {
        require(msg.sender == caller, "original consuming host");
        if (bytes4(input) == IERC165.supportsInterface.selector) {
            bytes4 id = abi.decode(input[4:], (bytes4));
            return abi.encode(id != bytes4(0xffffffff));
        }
        require(configured[keccak256(input)], "exact configured graph read");
        return values[keccak256(input)];
    }
}

/// @notice Full same-host facts/hash parity with the measured original facade.
/// @dev Uses the existing genuine scoped checkpoint/snapshot/Router root/reference fixture,
/// retaining its typed Core/Artist/producer/Registry/Archive and browser-observation boundaries.
/// No original Artist ceremony, browser run, gas acceptance or deployed capacity is claimed.
/// The graph-only V2 case checks typed profile dispatch, not a fabricated V2 publication.
contract StreamScopedPreservationReferenceSourceCapacityTest is
    ScopedPreservationReferenceFixtureV1
{
    ScopedReferenceSourceCapacityVm private constant sourceVm =
        ScopedReferenceSourceCapacityVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function actual(T.Dependencies memory d, T.Publication memory p, bool current, bytes32 family)
        external
        view
        returns (T.SourceFacts memory)
    {
        return Candidate.requireSource(d, p, current, family);
    }

    function original(T.Dependencies memory d, T.Publication memory p, bool current, bytes32 family)
        external
        view
        returns (T.SourceFacts memory)
    {
        return Frozen.requireSource(d, p, current, family);
    }

    function actualGraph(T.Dependencies memory d, bytes32 family)
        external
        view
        returns (S.Dependencies memory)
    {
        return Candidate.bindings(d, family);
    }

    function originalGraph(T.Dependencies memory d, bytes32 family)
        external
        view
        returns (S.Dependencies memory)
    {
        return Frozen.bindings(d, family);
    }

    function _failure(bytes memory a, bytes memory b, bytes memory expected) private view {
        (bool ok, bytes memory out) = address(this).staticcall(a);
        (bool oldOK, bytes memory oldOut) = address(this).staticcall(b);
        require(!ok && !oldOK, "both original and factored must refuse");
        require(
            keccak256(out) == keccak256(expected) && keccak256(oldOut) == keccak256(expected),
            "identical complete original error bytes"
        );
    }

    function _sourceFailure(T.Publication memory p, bool current, bytes memory expected)
        private
        view
    {
        T.Dependencies memory d = referenceHost.dependencies();
        _failure(
            abi.encodeCall(this.actual, (d, p, current, Profiles.ORIGINAL_PROFILE)),
            abi.encodeCall(this.original, (d, p, current, Profiles.ORIGINAL_PROFILE)),
            expected
        );
    }

    function _parity(bool current) private view returns (bytes32 digest) {
        T.Dependencies memory d = referenceHost.dependencies();
        T.Publication memory p = abi.decode(abi.encode(referenceInput), (T.Publication));
        bytes32 inputBefore = keccak256(abi.encode(d, p));
        T.SourceFacts memory facts =
            Candidate.requireSource(d, p, current, Profiles.ORIGINAL_PROFILE);
        T.SourceFacts memory old = Frozen.requireSource(d, p, current, Profiles.ORIGINAL_PROFILE);
        digest = keccak256(abi.encode(facts));
        require(digest == keccak256(abi.encode(old)), "complete SourceFacts return");
        require(inputBefore == keccak256(abi.encode(d, p)), "input memory unchanged");
        (, S.Receipt memory receipt) = snapshotHost.snapshotRecord(adoptedSnapshot);
        require(
            keccak256(abi.encode(facts.snapshot)) == keccak256(abi.encode(receipt))
                && facts.snapshot.recordHash == adoptedSnapshot && facts.snapshot.manifestHash != 0
                && facts.snapshot.manifestBytes != 0,
            "original receipt not normalized"
        );
        require(
            facts.contentRootRecordHash == adoptedRoot && facts.contentRoot.stateHash != 0,
            "all root results returned to facade"
        );
        require(
            facts.environmentCoverage.coverageHash == p.observation.environment.coverageHash,
            "original environment coverage returned"
        );
        uint256 count = facts.snapshotSource.membership.tokenCount;
        require(facts.samples.length == (count == 1 ? 1 : 2), "complete bounded sample array");
        for (uint256 i; i < facts.samples.length; ++i) {
            require(
                facts.samples[i].membershipIndex == (i == 0 ? 0 : count - 1),
                "original first/last ordinal"
            );
            require(
                facts.samples[i].observation.tokenId == p.observation.captures[i].tokenId,
                "sample memory returned at original position"
            );
        }
        bytes32 expectedHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_SOURCES_V1"),
                d.chainId,
                address(this),
                d.targets,
                d.codeHashes,
                facts
            )
        );
        require(
            Candidate.sourceHash(d, facts) == expectedHash
                && Frozen.sourceHash(d, facts) == expectedHash,
            "unchanged literal source hash and host domain"
        );
        require(
            keccak256(abi.encode(Candidate.archiveDependencies(d)))
                == keccak256(abi.encode(Frozen.archiveDependencies(d))),
            "original archive tuple"
        );
    }

    function testReferenceSourceBoundaryReleaseFullFactsParity() public {
        _reference(1, 2);
        require(_parity(true) == _parity(false), "live corroboration retains original coverage");
    }

    function testReferenceSourceBoundaryExpiredTokenFullFactsParity() public {
        _reference(2, 1);
        _parity(true);
    }

    function testReferenceSourceBoundarySeasonFullFactsParity() public {
        _reference(1, 3);
        _parity(true);
    }

    function testReferenceSnapshotCaptureReturnsOriginalReceiptSourceAndRecordKey() public {
        _reference(1, 2);
        T.Dependencies memory d = referenceHost.dependencies();
        S.Dependencies memory source = snapshotHost.dependencies();
        (S.Publication memory p, S.Receipt memory originalReceipt) =
            snapshotHost.snapshotRecord(adoptedSnapshot);
        bytes32 before_ = keccak256(abi.encode(source, p, originalReceipt));
        S.Source memory expected =
            SnapshotWorker.read(d, source, p, originalReceipt, Profiles.ORIGINAL_PROFILE);
        (S.Receipt memory receipt, S.Source memory facts, bytes32 outputRecord) = SnapshotWorker.capture(
            d, source, referenceInput.scope, adoptedSnapshot, 1, Profiles.ORIGINAL_PROFILE
        );
        require(
            keccak256(abi.encode(receipt)) == keccak256(abi.encode(originalReceipt)),
            "receipt identity intact"
        );
        require(
            keccak256(abi.encode(facts)) == keccak256(abi.encode(expected)),
            "complete original source"
        );
        require(
            outputRecord == p.outputManifestRecord && outputRecord != 0
                && outputRecord != facts.outputs.manifestHash,
            "original output receipt key, not payload hash"
        );
        require(
            before_ == keccak256(abi.encode(source, p, originalReceipt)),
            "public argument memory preserved"
        );
    }

    function testReferenceGraphCallerClosedProfilesAndCanonicalOriginalTuple() public {
        ScopedReferenceSourceGraphCaller boundary =
            new ScopedReferenceSourceGraphCaller(address(this));
        T.Dependencies memory d;
        S.Dependencies memory s;
        for (uint256 i; i < 7; ++i) {
            d.targets[i] = address(boundary);
            d.codeHashes[i] = address(boundary).codehash;
        }
        for (uint256 i; i < 11; ++i) {
            s.targets[i] = address(boundary);
            s.codeHashes[i] = address(boundary).codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 1000000;
        d.sourceGas = 1000000;
        d.snapshotGas = 1000000;
        d.archiveGas = 1000000;
        s.chainId = block.chainid;
        s.readGas = 1000000;
        s.sourceGas = 1000000;
        s.inventoryGas = 1000000;
        boundary.set(abi.encodeWithSignature("core()"), abi.encode(address(boundary)));
        bytes memory input = abi.encodeCall(Snap.dependencies, ());
        boundary.set(input, abi.encode(s));
        for (uint256 i; i < 2; ++i) {
            bytes32 family = i == 0 ? Profiles.ORIGINAL_PROFILE : Profiles.FAMILY_PROFILE;
            boundary.set(
                abi.encodeCall(Snap.scopedPreservationPolicySnapshotProfile, ()),
                abi.encode(
                    i == 0
                        ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V1")
                        : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V2")
                )
            );
            require(
                keccak256(abi.encode(Candidate.bindings(d, family))) == keccak256(abi.encode(s))
                    && keccak256(abi.encode(Frozen.bindings(d, family)))
                        == keccak256(abi.encode(s)),
                "exact graph from original caller"
            );
        }
        bytes32 unknown = keccak256("unrecognized closed family");
        _failure(
            abi.encodeCall(this.actualGraph, (d, unknown)),
            abi.encodeCall(this.originalGraph, (d, unknown)),
            abi.encodeWithSelector(Families.InvalidPreservationReferenceFamily.selector)
        );
        boundary.set(input, new bytes(831));
        _failure(
            abi.encodeCall(this.actualGraph, (d, Profiles.FAMILY_PROFILE)),
            abi.encodeCall(this.originalGraph, (d, Profiles.FAMILY_PROFILE)),
            abi.encodeWithSelector(
                Reads.RouterEvidenceRead.selector, address(boundary), Snap.dependencies.selector
            )
        );
        boundary.set(input, abi.encode(s));
        require(
            keccak256(abi.encode(Candidate.bindings(d, Profiles.FAMILY_PROFILE)))
                == keccak256(abi.encode(s)),
            "exact graph retry after response restoration"
        );
    }

    function testReferenceObservationCountBeforeArchiveAndExactRetry() public {
        _reference(1, 2);
        bytes32 healthy = _parity(false);
        E.Coverage memory saved = Archive(address(externalArchive))
            .coverage(referenceInput.observation.environment.coverageHash);
        bytes memory input = abi.encodeCall(
            Archive.requireCoverage, (saved.coverageHash, saved.artistId, saved.objectHash)
        );
        sourceVm.mockCallRevert(address(externalArchive), input, hex"12345678");
        T.Publication memory bad = abi.decode(abi.encode(referenceInput), (T.Publication));
        bad.observation.captures = new R.Capture[](1);
        _sourceFailure(bad, false, abi.encodeWithSelector(T.InvalidScopedPolicyReference.selector));
        _sourceFailure(
            referenceInput,
            false,
            abi.encodeWithSelector(
                Reads.RouterEvidenceRead.selector,
                address(externalArchive),
                Archive.requireCoverage.selector
            )
        );
        snapshotVm.mockCall(address(externalArchive), input, abi.encode(saved));
        require(_parity(false) == healthy, "restore only failed coverage, identical source inputs");
    }

    function testReferenceObservationRuntimeObjectRefusalAndExactRetry() public {
        _reference(1, 2);
        bytes32 healthy = _parity(true);
        bytes32 object = referenceInput.observation.environment.objectHash;
        E.ObjectIdentity memory saved = Archive(address(externalArchive)).objectIdentity(object);
        E.ObjectIdentity memory bad = abi.decode(abi.encode(saved), (E.ObjectIdentity));
        bad.formatCatalogHash = bytes32(uint256(bad.formatCatalogHash) ^ 1);
        bytes memory input = abi.encodeCall(Archive.objectIdentity, (object));
        snapshotVm.mockCall(address(externalArchive), input, abi.encode(bad));
        _sourceFailure(
            referenceInput, true, abi.encodeWithSelector(T.InvalidScopedPolicyReference.selector)
        );
        snapshotVm.mockCall(address(externalArchive), input, abi.encode(saved));
        require(_parity(true) == healthy, "original runtime identity restored without reseeding");
    }

    function testReferenceObservationLateCaptureChecksFirstSampleThenIdenticalRetry() public {
        _reference(1, 2);
        bytes32 healthy = _parity(true);
        T.Publication memory bad = abi.decode(abi.encode(referenceInput), (T.Publication));
        bad.observation.captures[1].environmentManifestHash =
            keccak256("different capture environment");
        // Two failed comparisons plus the two unchanged retry calls reach the first sample.
        sourceVm.expectCall(
            address(externalArchive),
            abi.encodeCall(Archive.coverage, (referenceInput.observation.captures[0].coverageHash)),
            uint64(4)
        );
        _sourceFailure(bad, true, abi.encodeWithSelector(T.InvalidScopedPolicyReference.selector));
        require(
            _parity(true) == healthy, "same original captures retry after independent-copy refusal"
        );
    }
}
