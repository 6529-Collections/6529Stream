// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicySnapshotTypesV1 as CSnap
} from "../../../smart-contracts/interfaces/stream/metadata/StreamPreservationPolicySnapshotTypesV1.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as SSnap
} from "../../../smart-contracts/interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    PreservationReferenceFixtureV1
} from "./StreamPreservationPolicyReferencePublicationV1.t.sol";
import {
    ScopedPreservationReferenceFixtureV1
} from "./StreamScopedPreservationPolicyReferencePublicationV1.t.sol";
import {
    StreamPreservationPolicyReferencePublicationV1 as C1
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyReferencePublicationV1.sol";
import {
    StreamPreservationPolicyReferencePublicationV2 as C2
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyReferencePublicationV2.sol";
import {
    StreamScopedPreservationPolicyReferencePublicationV1 as S1
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyReferencePublicationV1.sol";
import {
    StreamScopedPreservationPolicyReferencePublicationV2 as S2
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyReferencePublicationV2.sol";
import {
    StreamPreservationPolicyReferenceTypesV1 as CT
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationPolicyReferenceTypesV1.sol";
import {
    StreamScopedPreservationPolicyReferenceTypesV1 as ST
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPreservationPolicyReferenceTypesV1.sol";
import {
    StreamPreservationPolicyReferenceSampleReadsV1 as CSamples
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyReferenceSampleReadsV1.sol";
import {
    StreamScopedPreservationPolicyReferenceSampleReadsV1 as SSamples
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyReferenceSampleReadsV1.sol";
import {
    StreamPreservationPolicyReferenceSourceReadsV1 as CSources
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyReferenceSourceReadsV1.sol";
import {
    StreamScopedPreservationPolicyReferenceSourceReadsV1 as SSources
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyReferenceSourceReadsV1.sol";
import {
    StreamFinalityPreservationPolicyReferenceReadsV1 as CReads
} from "../../../smart-contracts/domains/finality/StreamFinalityPreservationPolicyReferenceReadsV1.sol";
import {
    StreamFinalityScopedPreservationPolicyReferenceReadsV1 as SReads
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPreservationPolicyReferenceReadsV1.sol";
import {
    StreamPreservationPolicyReferenceFamiliesV2 as F
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyReferenceFamiliesV2.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Profiles
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as Content
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";

/// @notice Shared V2 reference kernels on the existing genuine V1 publication fixture.
/// @dev Explicitly mocked profile/row/admission/receipt boundaries exercise V2 pairing and
/// interpretation; these are not a V2 snapshot-to-reference ceremony or actual renderer proof.
contract StreamPreservationPolicyReferenceFamilyV2Test is PreservationReferenceFixtureV1 {
    function testV2ConstructorPairsOnlyV2SnapshotAndPreservesV1FixedProfile() public {
        _reference();
        CT.Dependencies memory d = referenceHost.dependencies();
        vm.expectRevert(abi.encodeWithSelector(CT.InvalidPolicyReference.selector));
        new C2(d, address(executor), _referenceGas());
        snapshotVm.mockCall(
            address(snapshotHost),
            abi.encodeWithSignature("preservationPolicySnapshotProfile()"),
            abi.encode(keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_V2"))
        );
        C2 host = new C2(d, address(executor), _referenceGas());
        require(
            host.preservationPolicyReferenceProfile() == F.profile(Profiles.FAMILY_PROFILE, false)
        );
        require(host.streamModuleVersion() == F.moduleVersion(Profiles.FAMILY_PROFILE, false));
        require(
            host.streamModuleSchemaHash() == F.definition(Profiles.FAMILY_PROFILE, false).schemaHash
        );
        require(
            referenceHost.preservationPolicyReferenceProfile()
                == F.profile(Profiles.ORIGINAL_PROFILE, false)
        );
        require(host.referenceCount(referenceInput.scope) == 0);
        vm.expectRevert(abi.encodeWithSelector(CT.InvalidPolicyReference.selector));
        new C1(d, address(executor), _referenceGas());
    }

    function testV2SampleAcceptsBothClosedProducerMarkersAndOldEntryRejectsCurrentMarker() public {
        _reference();
        bytes32 hash = _publishReference();
        CT.SourceFacts memory facts = referenceHost.referenceSource(hash);
        CT.Dependencies memory d = referenceHost.dependencies();
        CSnap.Dependencies memory sd = snapshotHost.dependencies();
        CT.Sample memory original = CSamples.requireSample(
            d,
            sd,
            referenceInput.scope,
            facts.snapshotSource,
            0,
            referenceInput.observation.captures[0],
            true,
            Profiles.FAMILY_PROFILE
        );
        require(original.preservation.profile == Profiles.ORIGINAL_PROFILE);
        Content.Output memory row = _currentProducerRow();
        CT.Sample memory current = CSamples.requireSample(
            d,
            sd,
            referenceInput.scope,
            facts.snapshotSource,
            1,
            referenceInput.observation.captures[1],
            true,
            Profiles.FAMILY_PROFILE
        );
        require(current.preservation.profile == Profiles.CURRENT_ARTIST_PROFILE);
        require(
            keccak256(abi.encode(current.preservationAdmission))
                == keccak256(abi.encode(row.preservationAdmission))
        );
        vm.expectRevert(abi.encodeWithSelector(CT.InvalidPolicyReference.selector));
        CSamples.requireSample(
            d,
            sd,
            referenceInput.scope,
            facts.snapshotSource,
            1,
            referenceInput.observation.captures[1],
            true
        );
    }

    function testV2EveryAdmissionWordStillAuthenticatesAndIdenticalRetrySucceeds() public {
        _reference();
        bytes32 hash = _publishReference();
        CT.SourceFacts memory facts = referenceHost.referenceSource(hash);
        CT.Dependencies memory d = referenceHost.dependencies();
        CSnap.Dependencies memory sd = snapshotHost.dependencies();
        Content.Output memory row = _currentProducerRow();
        bytes memory input = abi.encodeWithSignature(
            "requirePreservation(bytes32,address,bytes32)",
            row.preservationAdmission.versionKey,
            row.preservation.producer,
            row.preservation.profile
        );
        bytes memory original = abi.encode(row.preservation, row.preservationAdmission);
        require(original.length == 512);
        for (uint256 i; i < 16; ++i) {
            bytes memory bad = abi.encodePacked(original);
            bad[(i + 1) * 32 - 1] ^= 0x01;
            snapshotVm.mockCall(row.preservationAdmission.registry, input, bad);
            vm.expectRevert();
            CSamples.requireSample(
                d,
                sd,
                referenceInput.scope,
                facts.snapshotSource,
                1,
                referenceInput.observation.captures[1],
                true,
                Profiles.FAMILY_PROFILE
            );
            snapshotVm.mockCall(row.preservationAdmission.registry, input, original);
            require(
                CSamples.requireSample(
                        d,
                        sd,
                        referenceInput.scope,
                        facts.snapshotSource,
                        1,
                        referenceInput.observation.captures[1],
                        true,
                        Profiles.FAMILY_PROFILE
                    ).preservation.profile == Profiles.CURRENT_ARTIST_PROFILE
            );
        }
        snapshotVm.mockCall(
            row.preservationAdmission.registry,
            input,
            abi.encodePacked(original, bytes32(uint256(1)))
        );
        vm.expectRevert();
        CSamples.requireSample(
            d,
            sd,
            referenceInput.scope,
            facts.snapshotSource,
            1,
            referenceInput.observation.captures[1],
            true,
            Profiles.FAMILY_PROFILE
        );
    }

    function testV2RejectsViewAndUnknownProducerMarkers() public {
        _reference();
        bytes32 hash = _publishReference();
        CT.SourceFacts memory facts = referenceHost.referenceSource(hash);
        CT.Dependencies memory d = referenceHost.dependencies();
        CSnap.Dependencies memory sd = snapshotHost.dependencies();
        Content.Output memory row = _currentProducerRow();
        bytes32[2] memory wrong = [
            keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_V1"),
            keccak256("caller-defined producer")
        ];
        for (uint256 i; i < wrong.length; ++i) {
            row.preservation.profile = wrong[i];
            snapshotVm.mockCall(
                address(snapshotContent),
                abi.encodeCall(Content.outputAt, (snapshotCapture.id, uint256(1))),
                abi.encode(row)
            );
            vm.expectRevert(abi.encodeWithSelector(CT.InvalidPolicyReference.selector));
            CSamples.requireSample(
                d,
                sd,
                referenceInput.scope,
                facts.snapshotSource,
                1,
                referenceInput.observation.captures[1],
                true,
                Profiles.FAMILY_PROFILE
            );
        }
    }

    function testV2ReaderAuthenticatesItsRecordDomainAndOldReaderCannotBorrowIt() public {
        _reference();
        bytes32 oldHash = _publishReference();
        (CT.Publication memory p, CT.Receipt memory r) = referenceHost.referenceRecord(oldHash);
        F.Definition memory definition = F.definition(Profiles.FAMILY_PROFILE, false);
        r.observation.schemaHash = definition.schemaHash;
        r.observation.profileHash = definition.profileHash;
        r.observation.canonicalizationHash = definition.canonHash;
        r.observation.recordHash = 0;
        r.observation.recordChainHash = 0;
        bytes32 hash = keccak256(
            abi.encode(
                F.recordDomain(Profiles.FAMILY_PROFILE, false),
                block.chainid,
                address(referenceHost),
                address(core),
                address(metadata),
                p,
                r
            )
        );
        r.observation.recordHash = hash;
        r.observation.recordChainHash = keccak256("typed V2 retained chain boundary");
        snapshotVm.mockCall(
            address(referenceHost),
            abi.encodeWithSignature("preservationPolicyReferenceProfile()"),
            abi.encode(F.profile(Profiles.FAMILY_PROFILE, false))
        );
        snapshotVm.mockCall(
            address(referenceHost),
            abi.encodeWithSignature("referenceRecord(bytes32)", hash),
            abi.encode(p, r)
        );
        snapshotVm.mockCall(
            address(referenceHost),
            abi.encodeWithSelector(
                referenceHost.requireCurrent.selector, referenceInput.scope, hash, uint64(1)
            ),
            abi.encode(r)
        );
        (CT.Publication memory actual, CT.Receipt memory saved) = CReads.original(
            _readerDependencies(), referenceInput.scope, hash, 1, Profiles.FAMILY_PROFILE
        );
        require(keccak256(abi.encode(actual, saved)) == keccak256(abi.encode(p, r)));
        require(
            CReads.requireCurrent(
                    _readerDependencies(), referenceInput.scope, hash, 1, Profiles.FAMILY_PROFILE
                ).observation.recordHash == hash
        );
        vm.expectRevert();
        CReads.original(_readerDependencies(), referenceInput.scope, hash, 1);
        r.observation.schemaHash = keccak256("wrong definition");
        snapshotVm.mockCall(
            address(referenceHost),
            abi.encodeWithSignature("referenceRecord(bytes32)", hash),
            abi.encode(p, r)
        );
        vm.expectRevert();
        CReads.original(
            _readerDependencies(), referenceInput.scope, hash, 1, Profiles.FAMILY_PROFILE
        );
    }

    function testV2SourceHashDomainDiffersAndUnknownFamilyIsRejected() public {
        _reference();
        bytes32 hash = _publishReference();
        CT.SourceFacts memory facts = referenceHost.referenceSource(hash);
        bytes32 old = CSources.sourceHash(referenceHost.dependencies(), facts);
        require(
            old
                == CSources.sourceHash(
                    referenceHost.dependencies(), facts, Profiles.ORIGINAL_PROFILE
                )
        );
        require(
            old != CSources.sourceHash(referenceHost.dependencies(), facts, Profiles.FAMILY_PROFILE)
        );
        vm.expectRevert(abi.encodeWithSelector(F.InvalidPreservationReferenceFamily.selector));
        this.unknownFamily();
    }

    function unknownFamily() external pure {
        F.isV2(keccak256("unknown reference family"));
    }

    function _currentProducerRow() private returns (Content.Output memory row) {
        row = snapshotContent.outputAt(snapshotCapture.id, 1);
        row.preservation.profile = Profiles.CURRENT_ARTIST_PROFILE;
        snapshotVm.mockCall(
            row.preservation.producer,
            abi.encodeWithSignature("preservationProfile()"),
            abi.encode(row.preservation.profile)
        );
        snapshotVm.mockCall(
            address(snapshotContent),
            abi.encodeCall(Content.outputAt, (snapshotCapture.id, uint256(1))),
            abi.encode(row)
        );
        snapshotVm.mockCall(
            row.preservationAdmission.registry,
            abi.encodeWithSignature(
                "requirePreservation(bytes32,address,bytes32)",
                row.preservationAdmission.versionKey,
                row.preservation.producer,
                row.preservation.profile
            ),
            abi.encode(row.preservation, row.preservationAdmission)
        );
    }
}

contract StreamScopedPreservationPolicyReferenceFamilyV2Test is
    ScopedPreservationReferenceFixtureV1
{
    function testV2ConstructorPairsOnlyV2SnapshotAndPreservesV1FixedProfile() public {
        _reference(1, 2);
        ST.Dependencies memory d = referenceHost.dependencies();
        vm.expectRevert(abi.encodeWithSelector(ST.InvalidScopedPolicyReference.selector));
        new S2(d, address(executor), _referenceGas());
        snapshotVm.mockCall(
            address(snapshotHost),
            abi.encodeWithSignature("scopedPreservationPolicySnapshotProfile()"),
            abi.encode(keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V2"))
        );
        S2 host = new S2(d, address(executor), _referenceGas());
        require(
            host.scopedPreservationPolicyReferenceProfile()
                == F.profile(Profiles.FAMILY_PROFILE, true)
        );
        require(host.streamModuleVersion() == F.moduleVersion(Profiles.FAMILY_PROFILE, true));
        require(
            host.streamModuleSchemaHash() == F.definition(Profiles.FAMILY_PROFILE, true).schemaHash
        );
        require(
            referenceHost.scopedPreservationPolicyReferenceProfile()
                == F.profile(Profiles.ORIGINAL_PROFILE, true)
        );
        require(host.referenceCount(referenceInput.scope) == 0);
        vm.expectRevert(abi.encodeWithSelector(ST.InvalidScopedPolicyReference.selector));
        new S1(d, address(executor), _referenceGas());
    }

    function testV2SampleAcceptsBothClosedProducerMarkersAndOldEntryRejectsCurrentMarker() public {
        _reference(1, 2);
        bytes32 hash = _publishReference();
        ST.SourceFacts memory facts = referenceHost.referenceSource(hash);
        ST.Dependencies memory d = referenceHost.dependencies();
        SSnap.Dependencies memory sd = snapshotHost.dependencies();
        ST.Sample memory original = SSamples.requireSample(
            d,
            sd,
            referenceInput.scope,
            facts.snapshotSource,
            0,
            referenceInput.observation.captures[0],
            true,
            Profiles.FAMILY_PROFILE
        );
        require(original.preservation.profile == Profiles.ORIGINAL_PROFILE);
        Content.Output memory row = _currentProducerRow();
        ST.Sample memory current = SSamples.requireSample(
            d,
            sd,
            referenceInput.scope,
            facts.snapshotSource,
            1,
            referenceInput.observation.captures[1],
            true,
            Profiles.FAMILY_PROFILE
        );
        require(current.preservation.profile == Profiles.CURRENT_ARTIST_PROFILE);
        require(
            keccak256(abi.encode(current.preservationAdmission))
                == keccak256(abi.encode(row.preservationAdmission))
        );
        vm.expectRevert(abi.encodeWithSelector(ST.InvalidScopedPolicyReference.selector));
        SSamples.requireSample(
            d,
            sd,
            referenceInput.scope,
            facts.snapshotSource,
            1,
            referenceInput.observation.captures[1],
            true
        );
    }

    function testV2EveryAdmissionWordStillAuthenticatesAndIdenticalRetrySucceeds() public {
        _reference(1, 2);
        bytes32 hash = _publishReference();
        ST.SourceFacts memory facts = referenceHost.referenceSource(hash);
        ST.Dependencies memory d = referenceHost.dependencies();
        SSnap.Dependencies memory sd = snapshotHost.dependencies();
        Content.Output memory row = _currentProducerRow();
        bytes memory input = abi.encodeWithSignature(
            "requirePreservation(bytes32,address,bytes32)",
            row.preservationAdmission.versionKey,
            row.preservation.producer,
            row.preservation.profile
        );
        bytes memory original = abi.encode(row.preservation, row.preservationAdmission);
        require(original.length == 512);
        for (uint256 i; i < 16; ++i) {
            bytes memory bad = abi.encodePacked(original);
            bad[(i + 1) * 32 - 1] ^= 0x01;
            snapshotVm.mockCall(row.preservationAdmission.registry, input, bad);
            vm.expectRevert();
            SSamples.requireSample(
                d,
                sd,
                referenceInput.scope,
                facts.snapshotSource,
                1,
                referenceInput.observation.captures[1],
                true,
                Profiles.FAMILY_PROFILE
            );
            snapshotVm.mockCall(row.preservationAdmission.registry, input, original);
            require(
                SSamples.requireSample(
                        d,
                        sd,
                        referenceInput.scope,
                        facts.snapshotSource,
                        1,
                        referenceInput.observation.captures[1],
                        true,
                        Profiles.FAMILY_PROFILE
                    ).preservation.profile == Profiles.CURRENT_ARTIST_PROFILE
            );
        }
        snapshotVm.mockCall(
            row.preservationAdmission.registry,
            input,
            abi.encodePacked(original, bytes32(uint256(1)))
        );
        vm.expectRevert();
        SSamples.requireSample(
            d,
            sd,
            referenceInput.scope,
            facts.snapshotSource,
            1,
            referenceInput.observation.captures[1],
            true,
            Profiles.FAMILY_PROFILE
        );
    }

    function testV2RejectsViewAndUnknownProducerMarkers() public {
        _reference(1, 2);
        bytes32 hash = _publishReference();
        ST.SourceFacts memory facts = referenceHost.referenceSource(hash);
        ST.Dependencies memory d = referenceHost.dependencies();
        SSnap.Dependencies memory sd = snapshotHost.dependencies();
        Content.Output memory row = _currentProducerRow();
        bytes32[2] memory wrong = [
            keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_V1"),
            keccak256("caller-defined producer")
        ];
        for (uint256 i; i < wrong.length; ++i) {
            row.preservation.profile = wrong[i];
            snapshotVm.mockCall(
                address(snapshotContent),
                abi.encodeCall(Content.outputAt, (snapshotCapture.id, uint256(1))),
                abi.encode(row)
            );
            vm.expectRevert(abi.encodeWithSelector(ST.InvalidScopedPolicyReference.selector));
            SSamples.requireSample(
                d,
                sd,
                referenceInput.scope,
                facts.snapshotSource,
                1,
                referenceInput.observation.captures[1],
                true,
                Profiles.FAMILY_PROFILE
            );
        }
    }

    function testV2ReaderAuthenticatesItsRecordDomainAndOldReaderCannotBorrowIt() public {
        _reference(1, 2);
        bytes32 oldHash = _publishReference();
        (ST.Publication memory p, ST.Receipt memory r) = referenceHost.referenceRecord(oldHash);
        F.Definition memory definition = F.definition(Profiles.FAMILY_PROFILE, true);
        r.observation.schemaHash = definition.schemaHash;
        r.observation.profileHash = definition.profileHash;
        r.observation.canonicalizationHash = definition.canonHash;
        r.observation.recordHash = 0;
        r.observation.recordChainHash = 0;
        bytes32 hash = keccak256(
            abi.encode(
                F.recordDomain(Profiles.FAMILY_PROFILE, true),
                block.chainid,
                address(referenceHost),
                address(core),
                address(metadata),
                p,
                r
            )
        );
        r.observation.recordHash = hash;
        r.observation.recordChainHash = keccak256("typed V2 retained chain boundary");
        snapshotVm.mockCall(
            address(referenceHost),
            abi.encodeWithSignature("scopedPreservationPolicyReferenceProfile()"),
            abi.encode(F.profile(Profiles.FAMILY_PROFILE, true))
        );
        snapshotVm.mockCall(
            address(referenceHost),
            abi.encodeWithSignature("referenceRecord(bytes32)", hash),
            abi.encode(p, r)
        );
        snapshotVm.mockCall(
            address(referenceHost),
            abi.encodeWithSelector(
                referenceHost.requireCurrent.selector, referenceInput.scope, hash, uint64(1)
            ),
            abi.encode(r)
        );
        (ST.Publication memory actual, ST.Receipt memory saved) = SReads.original(
            _readerDependencies(), referenceInput.scope, hash, 1, Profiles.FAMILY_PROFILE
        );
        require(keccak256(abi.encode(actual, saved)) == keccak256(abi.encode(p, r)));
        require(
            SReads.requireCurrent(
                    _readerDependencies(), referenceInput.scope, hash, 1, Profiles.FAMILY_PROFILE
                ).observation.recordHash == hash
        );
        vm.expectRevert();
        SReads.original(_readerDependencies(), referenceInput.scope, hash, 1);
        r.observation.schemaHash = keccak256("wrong definition");
        snapshotVm.mockCall(
            address(referenceHost),
            abi.encodeWithSignature("referenceRecord(bytes32)", hash),
            abi.encode(p, r)
        );
        vm.expectRevert();
        SReads.original(
            _readerDependencies(), referenceInput.scope, hash, 1, Profiles.FAMILY_PROFILE
        );
    }

    function testV2SourceHashDomainDiffersAndUnknownFamilyIsRejected() public {
        _reference(1, 2);
        bytes32 hash = _publishReference();
        ST.SourceFacts memory facts = referenceHost.referenceSource(hash);
        bytes32 old = SSources.sourceHash(referenceHost.dependencies(), facts);
        require(
            old
                == SSources.sourceHash(
                    referenceHost.dependencies(), facts, Profiles.ORIGINAL_PROFILE
                )
        );
        require(
            old != SSources.sourceHash(referenceHost.dependencies(), facts, Profiles.FAMILY_PROFILE)
        );
        vm.expectRevert(abi.encodeWithSelector(F.InvalidPreservationReferenceFamily.selector));
        this.unknownFamily();
    }

    function unknownFamily() external pure {
        F.isV2(keccak256("unknown reference family"));
    }

    function _currentProducerRow() private returns (Content.Output memory row) {
        row = snapshotContent.outputAt(snapshotCapture.id, 1);
        row.preservation.profile = Profiles.CURRENT_ARTIST_PROFILE;
        snapshotVm.mockCall(
            row.preservation.producer,
            abi.encodeWithSignature("preservationProfile()"),
            abi.encode(row.preservation.profile)
        );
        snapshotVm.mockCall(
            address(snapshotContent),
            abi.encodeCall(Content.outputAt, (snapshotCapture.id, uint256(1))),
            abi.encode(row)
        );
        snapshotVm.mockCall(
            row.preservationAdmission.registry,
            abi.encodeWithSignature(
                "requirePreservation(bytes32,address,bytes32)",
                row.preservationAdmission.versionKey,
                row.preservation.producer,
                row.preservation.profile
            ),
            abi.encode(row.preservation, row.preservationAdmission)
        );
    }
}
