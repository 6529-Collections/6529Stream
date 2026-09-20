// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamViewAdoptionState as State } from "./StreamViewAdoptionState.sol";
import { StreamViewAdoptionStateV2 as PolicyState } from "./StreamViewAdoptionStateV2.sol";
import { StreamViewAdoptionRouting as Original } from "./StreamViewAdoptionRouting.sol";
import { StreamViewAdoptionRoutingV2 as Policy } from "./StreamViewAdoptionRoutingV2.sol";
import { StreamViewPolicyTypesV2 as T } from "./StreamViewPolicyTypesV2.sol";
import {
    StreamViewAdoptionTypes as V
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import {
    IStreamViewAdoptionRouter as API
} from "../../interfaces/stream/metadata/IStreamViewAdoptionRouter.sol";
import { IStreamCoreIdentity as Core } from "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import { StreamViewAdoptionReads as Read } from "./StreamViewAdoptionReads.sol";
import {
    StreamMetadataDisplayParameters as Parameters
} from "./StreamMetadataDisplayParameters.sol";

/// @notice Fixed closed dispatcher executed in the original Router, with original full-view cap.
/// @dev Reads its actual compiler-owned head/tag, never a caller-selected target or profile.
library StreamViewAdoptionPolicyTransportV2 {
    function serve(address core, bytes32 originalPin, bytes32 policyPin, bytes calldata input)
        public
        view
        returns (bytes memory)
    {
        bytes4 selector = bytes4(input);
        bool historical;
        if (selector == API.tokenJSONForView.selector || selector == API.tokenHTMLForView.selector) { } else if (
            selector == API.historicalTokenJSONForView.selector
                || selector == API.historicalTokenHTMLForView.selector
        ) {
            historical = true;
        } else {
            revert V.InvalidViewAdoption();
        }
        (uint256 token, bytes32 key) = abi.decode(input[4:], (uint256, bytes32));
        uint256 cap = Parameters.value(Parameters.BUNDLE_READ_GAS);
        (bool exists, uint256 cid,, bool burned) = abi.decode(
            Read.read(core, abi.encodeCall(Core.tokenCollectionIdentity, (token)), 128, cap),
            (bool, uint256, uint256, bool)
        );
        if (
            !exists || (!historical && burned)
                || Read.word(core, abi.encodeCall(Core.tokenLifecycle, (token)), cap)
                    != (burned ? 3 : 2)
        ) revert V.InvalidViewAdoption();
        if (!historical) {
            StreamFinalityScope memory scope =
                StreamFinalityScope(StreamFinalityScopeType.VIEW, cid, 0, key);
            key = State.state().heads[State.subject(core, scope)];
        }
        bytes32 tag = PolicyState.profile(key);
        // Authenticate the saved profile against the exact original outer record domain.
        // This never interprets payload bytes across profiles.
        State.previousRevision(core, key);
        address target = tag == 0 ? address(Original) : address(Policy);
        Read.pin(target, tag == 0 ? originalPin : policyPin);
        bytes memory callData = abi.encodeWithSelector(Original.serveEncoded.selector, input);
        // Both fixed workers expose the same closed transport selector; their downstream
        // decoder/context/record/source domains remain distinct and independently checked.
        return
            Read.bounded(
                target, callData, 262208, Parameters.value(Parameters.FULL_VIEW_GAS), false
            );
    }
}
