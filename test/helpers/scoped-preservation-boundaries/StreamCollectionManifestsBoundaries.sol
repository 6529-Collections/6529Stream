// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamArtistAttribution
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttribution.sol";
import {
    IStreamArtistContentRatification
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentRatification.sol";
import {
    IStreamCollectionArtistRegistry
} from "../../../smart-contracts/interfaces/stream/artist/IStreamCollectionArtistRegistry.sol";
import {
    StreamArtistContentTypes as C
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";

contract ManifestArtistBoundary {
    address public core;
    address public router;
    mapping(bytes32 => bytes32) private approvals;
    C.FreezeRecord private frozen;

    constructor(address c) {
        core = c;
    }

    function setRouter(address r) external {
        router = r;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamArtistAttribution).interfaceId
            || id == type(IStreamArtistContentRatification).interfaceId;
    }

    function attribution(uint256)
        external
        pure
        returns (IStreamCollectionArtistRegistry.Attribution memory a)
    {
        a.nominatedArtist = address(0xa11ce);
        a.artist = address(0xa11ce);
    }

    function firstReleaseRatification(uint256) external pure returns (bool, bytes32, bytes32) {
        return (false, 0, 0);
    }

    function approve(uint256 c, bytes32 family, bytes32 state, bytes32 evidence) external {
        approvals[keccak256(abi.encode(c, family, state))] = evidence;
    }

    function contentConsentEvidence(uint256 c, bytes32 family, bytes32 state)
        external
        view
        returns (bytes32)
    {
        require(msg.sender == router, "canonical content caller");
        return approvals[keccak256(abi.encode(c, family, state))];
    }

    function freeze(bytes32 family, bytes32 state) external {
        frozen.recordHash = keccak256("manifest freeze");
        frozen.artistId = keccak256("artist");
        frozen.metadataContract = router;
        frozen.expectedStateHash = state;
        frozen.authorityClass = 1;
        delete frozen.lockClasses;
        frozen.lockClasses.push(family);
    }

    function contentFreezeAuthorization(bytes32) external view returns (C.FreezeRecord memory) {
        return frozen;
    }

    function isContentFreezeAuthorized(uint256, bytes32 family)
        external
        view
        returns (bool, bytes32)
    {
        return
            (frozen.lockClasses.length == 1 && frozen.lockClasses[0] == family, frozen.recordHash);
    }
}
