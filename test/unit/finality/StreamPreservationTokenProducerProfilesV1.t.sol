// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPreservationPolicyContentCheckpointV1.t.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Family
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    StreamPreservationPolicyContentCheckpointV2 as FamilyCollection
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyContentCheckpointV2.sol";
import {
    StreamScopedPreservationPolicyContentCheckpointV2 as FamilyScoped
} from "../../../smart-contracts/domains/finality/StreamScopedPreservationPolicyContentCheckpointV2.sol";

/// @dev Genuine checkpoint engine over the existing fixture's explicit producer/Registry boundaries.
/// No actual current-Artist renderer, governed family admission, or end-to-end finality is claimed.
contract StreamPreservationTokenProducerProfilesV1Test is PreservationPolicyContentFixtureV1 {
    function testClosedTokenFamilyIncludesExactlyTwoMarkers() public pure {
        require(Family.isSupported(Family.ORIGINAL_PROFILE));
        require(Family.isSupported(Family.CURRENT_ARTIST_PROFILE));
        require(!Family.isSupported(Family.FAMILY_PROFILE));
        require(!Family.isSupported(keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_V1")));
        require(!Family.isSupported(bytes32(0)));
    }

    function testFuzzClosedFamilyRejectsEveryOtherMarker(bytes32 profile) public pure {
        require(
            Family.isSupported(profile)
                == (profile == Family.ORIGINAL_PROFILE || profile == Family.CURRENT_ARTIST_PROFILE)
        );
    }

    function testV1RetainsOriginalMarkerAndRejectsCurrentArtistProducer() public {
        _preservationFixture(1);
        Capture memory c = _capture(_scope(1), false);
        require(c.host.preservationOutputProfile() == Family.ORIGINAL_PROFILE);
        require(
            c.host.preservationPolicyProfile()
                == keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_V1")
        );
        _familyAdmission(c, 0, Family.CURRENT_ARTIST_PROFILE);
        bytes32 history = _history(c);
        Preservation.Payload[] memory payloads = _payload(c);
        vm.expectRevert(
            abi.encodeWithSelector(PreservationTypes.InvalidPreservationBinding.selector)
        );
        c.host.append(c.id, payloads);
        require(_history(c) == history);
        _familyAdmission(c, 0, Family.ORIGINAL_PROFILE);
        c.host.append(c.id, _payload(c));
        _assertComplete(c);
    }

    function testV2AllScopesRetainActualMixedMarkersAndFixedFamily() public {
        _preservationFixture(1);
        for (uint8 kind; kind < 4; ++kind) {
            Capture memory c = _familyCapture(kind);
            for (uint256 i; i < c.producers.length; ++i) {
                _familyAdmission(
                    c, i, i % 2 == 0 ? Family.CURRENT_ARTIST_PROFILE : Family.ORIGINAL_PROFILE
                );
            }
            c.host.append(c.id, _payload(c));
            Preservation.Plan memory p = c.host.requireCurrentCheckpoint(c.id);
            require(p.preservationProfile == Family.FAMILY_PROFILE && p.nextIndex == p.tokenCount);
            require(c.host.preservationOutputProfile() == Family.FAMILY_PROFILE);
            require(
                c.host.preservationPolicyProfile()
                    == (kind == 0
                            ? Family.COLLECTION_CHECKPOINT_PROFILE
                            : Family.SCOPED_CHECKPOINT_PROFILE)
            );
            require(abi.encode(p).length == 448);
            for (uint256 i; i < p.tokenCount; ++i) {
                Preservation.Output memory row = c.host.outputAt(c.id, i);
                require(
                    row.preservation.profile
                        == (i % 2 == 0 ? Family.CURRENT_ARTIST_PROFILE : Family.ORIGINAL_PROFILE)
                );
                require(row.preservation.producer == address(c.producers[i]));
                require(abi.encode(row).length == 1152);
            }
        }
    }

    function testV2RejectsViewUnknownAndFamilyAsProducer() public {
        _preservationFixture(1);
        Capture memory c = _familyCapture(1);
        bytes32[3] memory refused = [
            keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_V1"),
            keccak256("unregistered third token profile"),
            Family.FAMILY_PROFILE
        ];
        bytes32 history = _history(c);
        for (uint256 i; i < refused.length; ++i) {
            _familyAdmission(c, 0, refused[i]);
            Preservation.Payload[] memory payloads = _payload(c);
            vm.expectRevert(
                abi.encodeWithSelector(PreservationTypes.InvalidPreservationBinding.selector)
            );
            c.host.append(c.id, payloads);
            require(_history(c) == history);
        }
    }

    function testV2CapabilityWithoutExactRegistryAdmissionRejectsAndRetries() public {
        _preservationFixture(1);
        Capture memory c = _familyCapture(1);
        c.producer.setProfile(Family.CURRENT_ARTIST_PROFILE);
        address registry = scopedSelections.selectionAt(c.selection, 0).selection.registry;
        StaticRouteVm(address(vm))
            .mockCall(registry, _familyAdmissionInput(c, 0, Family.CURRENT_ARTIST_PROFILE), hex"");
        bytes32 history = _history(c);
        Preservation.Payload[] memory payloads = _payload(c);
        vm.expectRevert(
            abi.encodeWithSelector(
                PreservationCalls.RendererReadFailed.selector,
                registry,
                bytes4(keccak256("requirePreservation(bytes32,address,bytes32)"))
            )
        );
        c.host.append(c.id, payloads);
        require(_history(c) == history);
        _familyAdmission(c, 0, Family.CURRENT_ARTIST_PROFILE);
        c.host.append(c.id, _payload(c));
        require(c.host.requireCurrentCheckpoint(c.id).nextIndex == 1);
    }

    function testV2RejectsRegistryRelabelingAndKeepsExactRetry() public {
        _preservationFixture(1);
        Capture memory c = _familyCapture(1);
        c.producer.setProfile(Family.CURRENT_ARTIST_PROFILE);
        StaticRouteVm(address(vm))
            .mockCall(
                scopedSelections.selectionAt(c.selection, 0).selection.registry,
                _familyAdmissionInput(c, 0, Family.CURRENT_ARTIST_PROFILE),
                abi.encode(_binding(c, 0), _admission(c, 0))
            );
        bytes32 history = _history(c);
        Preservation.Payload[] memory payloads = _payload(c);
        vm.expectRevert(
            abi.encodeWithSelector(
                Preservation.StaticContentPayload.selector,
                scopedSelections.selectionAt(c.selection, 0).tokenId
            )
        );
        c.host.append(c.id, payloads);
        require(_history(c) == history);
        _familyAdmission(c, 0, Family.CURRENT_ARTIST_PROFILE);
        c.host.append(c.id, _payload(c));
        require(c.host.requireCurrentCheckpoint(c.id).nextIndex == 1);
    }

    function testV2MarkerDriftCannotRewriteHistoricalRows() public {
        _preservationFixture(1);
        Capture memory c = _familyCapture(1);
        _familyAdmission(c, 0, Family.ORIGINAL_PROFILE);
        c.host.append(c.id, _payload(c));
        bytes32 history = _history(c);
        _familyAdmission(c, 0, Family.CURRENT_ARTIST_PROFILE);
        vm.expectRevert(abi.encodeWithSelector(Preservation.StaticContentChanged.selector, c.id));
        c.host.requireCurrentCheckpoint(c.id);
        require(_history(c) == history);
        _familyAdmission(c, 0, Family.ORIGINAL_PROFILE);
        require(c.host.requireCurrentCheckpoint(c.id).nextIndex == 1);
    }

    function testV2ProfileReadIsExactlyOneWord() public {
        _preservationFixture(1);
        Capture memory c = _familyCapture(1);
        StaticRouteVm(address(vm))
            .mockCall(
                address(c.producer), abi.encodeWithSignature("preservationProfile()"), new bytes(31)
            );
        Preservation.Payload[] memory payloads = _payload(c);
        vm.expectRevert(
            abi.encodeWithSelector(
                PreservationCalls.RendererReadFailed.selector,
                address(c.producer),
                bytes4(keccak256("preservationProfile()"))
            )
        );
        c.host.append(c.id, payloads);
        require(c.host.checkpoint(c.id).nextIndex == 0);
    }

    function _familyCapture(uint8 kind) private returns (Capture memory c) {
        c = _capture(_scope(kind), false);
        address source = c.host.entropySourceSet();
        address ready = c.host.terminalReadiness();
        c.host = kind == 0
            ? Preservation(
                address(
                    new FamilyCollection(
                        address(scopedSelections),
                        source,
                        ready,
                        address(executor),
                        _scopedGas("STATIC_CONTENT_READ_GAS", 8000000, 2),
                        _scopedGas("STATIC_CONTENT_RENDER_GAS", 16000000, 2)
                    )
                )
            )
            : Preservation(
                address(
                    new FamilyScoped(
                        address(scopedSelections),
                        source,
                        ready,
                        address(executor),
                        _scopedGas("STATIC_CONTENT_READ_GAS", 8000000, 2),
                        _scopedGas("STATIC_CONTENT_RENDER_GAS", 16000000, 2)
                    )
                )
            );
        c.id = c.host.begin(c.selection, keccak256("fixed token-family candidate"));
    }

    function _familyAdmission(Capture memory c, uint256 i, bytes32 profile) private {
        c.producers[i].setProfile(profile);
        PreservationTypes.Binding memory b = _binding(c, i);
        b.profile = profile;
        StaticRouteVm(address(vm))
            .mockCall(
                scopedSelections.selectionAt(c.selection, i).selection.registry,
                _familyAdmissionInput(c, i, profile),
                abi.encode(b, _admission(c, i))
            );
    }

    function _familyAdmissionInput(Capture memory c, uint256 i, bytes32 profile)
        private
        view
        returns (bytes memory)
    {
        return abi.encodeWithSignature(
            "requirePreservation(bytes32,address,bytes32)",
            scopedSelections.selectionAt(c.selection, i).selection.versionKey,
            address(c.producers[i]),
            profile
        );
    }
}
