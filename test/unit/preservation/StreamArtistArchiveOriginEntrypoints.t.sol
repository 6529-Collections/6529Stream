// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistArchiveOriginReads as Worker
} from "../../../smart-contracts/domains/preservation/StreamArtistArchiveOriginReads.sol";
import {
    IStreamArtistArchiveOriginReads as Reads
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamArtistArchiveOriginReads.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";

/// @notice The bounded STATICCALL facade must expose ordinary interface ABI selectors.
/// @dev Solidity public-library selectors encode nominal struct names instead of tuple types.
/// The linked implementation libraries remain libraries; this fixed stateless facade is a host.
contract StreamArtistArchiveOriginEntrypointsTest {
    function testEveryPinnedWorkerSelectorMatchesItsTypedCaller() public pure {
        require(Worker.currentOrigin.selector == Reads.currentOrigin.selector, "current");
        require(Worker.lineage.selector == Reads.lineage.selector, "lineage");
        require(Worker.publicationItem.selector == Reads.publicationItem.selector, "publication");
        require(Worker.contentOrigin.selector == Reads.contentOrigin.selector, "content origin");
        require(Worker.contentItem.selector == Reads.contentItem.selector, "collection");
        require(Worker.scopedContentItem.selector == Reads.scopedContentItem.selector, "scoped");
        require(Worker.policyContentItem.selector == Reads.policyContentItem.selector, "policy");
        require(
            Worker.scopedPolicyContentItem.selector == Reads.scopedPolicyContentItem.selector,
            "scoped policy"
        );
    }

    function testTypedStaticCallReachesRealProofValidation() public {
        Worker worker = new Worker();
        S.Dependencies memory d;
        d.chainId = block.chainid == 0 ? 1 : 0;
        (bool ok, bytes memory result) =
            address(worker).staticcall(abi.encodeCall(Reads.currentOrigin, (d)));
        require(
            !ok
                && keccak256(result)
                    == keccak256(abi.encodeWithSelector(O.InvalidArchiveOrigin.selector)),
            "exact real proof error confirms facade dispatch"
        );
    }
}
