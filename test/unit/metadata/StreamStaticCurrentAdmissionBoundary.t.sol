// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/StaticMetadataRoutingFixture.sol";
import {
    StreamRendererCalls
} from "../../../smart-contracts/domains/metadata/StreamRendererCalls.sol";

/// @notice Regression checks for the explicit typed boundary used by current codec/source tests.
/// @dev This does not establish real Registry governance, retained analysis or golden admission.
contract StreamStaticCurrentAdmissionBoundaryTest is StaticMetadataRoutingFixture {
    function testTypedBoundaryDefaultsToMissingCurrentAdmissionWhileHistoricalEntryWorks() public {
        _activate();
        _mint();
        require(!versions.currentCitationBoundaryEnabled(), "construction is not current opt-in");
        string memory old = router.historicalFullTokenMetadataJSON(address(core), 91);
        require(bytes(old).length != 0 && !_has(old, '"citation"'), "original historical profile");
        _expectCurrentRefusal();
        require(!versions.currentCitationBoundaryEnabled(), "failed read cannot opt in");
    }

    function testTypedBoundaryRejectsForeignProfileSelectorAndRuntimeWithoutOptIn() public {
        vm.expectRevert(
            abi.encodeWithSelector(TypedCitationRegistry.InvalidCurrentCitation.selector)
        );
        versions.optInCurrentCitationBoundary(
            keccak256("foreign profile"),
            TypedCitationRenderer.renderCurrent.selector,
            address(renderer).codehash
        );
        vm.expectRevert(
            abi.encodeWithSelector(TypedCitationRegistry.InvalidCurrentCitation.selector)
        );
        versions.optInCurrentCitationBoundary(
            keccak256("6529STREAM_CURRENT_BASE_CITATION_V1"),
            StreamRendererV1.renderView.selector,
            address(renderer).codehash
        );
        vm.expectRevert(
            abi.encodeWithSelector(TypedCitationRegistry.InvalidCurrentCitation.selector)
        );
        versions.optInCurrentCitationBoundary(
            keccak256("6529STREAM_CURRENT_BASE_CITATION_V1"),
            TypedCitationRenderer.renderCurrent.selector,
            bytes32(uint256(1))
        );
        require(
            !versions.currentCitationBoundaryEnabled(),
            "all malformed declarations remain unadmitted"
        );
        _activate();
        _mint();
        _expectCurrentRefusal();
    }

    function testExplicitTypedOptInPinsCurrentRouteAndPreservesHistoricalBytes() public {
        _activate();
        _mint();
        bytes32 old = keccak256(bytes(router.historicalFullTokenMetadataJSON(address(core), 91)));
        _optInCurrentCitationAdmissionBoundary();
        (address target, bytes32 runtime, bytes32 profile, bytes4 selector) =
            versions.requireCurrentCitation(versions.key());
        require(
            target == address(renderer) && runtime == address(renderer).codehash
                && profile == keccak256("6529STREAM_CURRENT_BASE_CITATION_V1")
                && selector == TypedCitationRenderer.renderCurrent.selector,
            "exact declared typed route"
        );
        string memory json = router.tokenJSON(91);
        require(
            _has(
                json,
                string.concat(
                    '"citation":"eip155:',
                    Strings.toString(block.chainid),
                    "/erc721:",
                    Strings.toHexString(uint256(uint160(address(core))), 20),
                    '/91"'
                )
            ),
            "literal current global-token citation"
        );
        require(
            keccak256(bytes(router.historicalFullTokenMetadataJSON(address(core), 91))) == old,
            "typed current opt-in cannot rewrite original historical bytes"
        );
        (address encoding,) = renderer.encodingBinding();
        bytes memory code = encoding.code;
        bytes32 key = versions.key();
        vm.etch(encoding, hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(TypedCitationRegistry.CurrentCitationUnavailable.selector, key)
        );
        versions.requireCurrentCitation(key);
        vm.etch(encoding, code);
        require(
            keccak256(bytes(router.tokenJSON(91))) == keccak256(bytes(json)),
            "exact restored runtime route"
        );
    }

    function _expectCurrentRefusal() private {
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRendererCalls.RendererReadFailed.selector,
                address(versions),
                TypedCitationRegistry.requireCurrentCitation.selector
            )
        );
        router.tokenJSON(91);
    }
}
