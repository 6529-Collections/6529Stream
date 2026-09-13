// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ScopeMembershipPublicationFixture.sol";
import "../../smart-contracts/domains/finality/StreamFinalityRouterEvidenceProvider.sol";
import "../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionState.sol";

/// @dev This immutable original-registry read boundary does not record or execute finality.
contract RouterMembershipOriginalBoundary {
    address public immutable coreReads;
    address public immutable metadataReads;
    address public immutable scopeEvidenceProvider;
    bytes32 public immutable scopeEvidenceProviderCodeHash;

    constructor(address c, address m, address p) {
        coreReads = c;
        metadataReads = m;
        scopeEvidenceProvider = p;
        scopeEvidenceProviderCodeHash = p.codehash;
    }
}

/// @dev Artist evidence is an explicit boundary; Router owns its real one-time snapshot and anchor.
contract RouterMembershipArtistBoundary {
    address public immutable core;
    address public finalityRegistry;
    bytes32 public finalityRegistryCodeHash;

    constructor(address c) {
        core = c;
    }

    function bind(address f) external {
        require(finalityRegistry == address(0));
        finalityRegistry = f;
        finalityRegistryCodeHash = f.codehash;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamArtistAttribution).interfaceId
            || id == type(IStreamArtistContentRatification).interfaceId
            || id == type(IStreamArtistAttributionState).interfaceId;
    }

    function attribution(uint256 cid)
        external
        pure
        returns (IStreamCollectionArtistRegistry.Attribution memory a)
    {
        require(cid == 1 || cid == 2);
        a.artist = address(0xa11ce);
        a.nominatedArtist = address(0xa11ce);
        a.nominationHash = keccak256("scope artist binding");
        a.nominationRevision = 1;
        a.identityHash = keccak256("scope artist identity");
        a.acceptanceHash = keccak256("scope artist acceptance");
        a.acceptedAt = 1000;
    }

    function collectionArtistState(uint256 cid)
        external
        pure
        returns (uint8, uint64, bytes32, uint8, bytes32)
    {
        require(cid == 1 || cid == 2);
        return (2, 1, keccak256("scope artist"), 1, keccak256("scope artist binding"));
    }
}

abstract contract RouterScopeMembershipFixture is ScopeMembershipPublicationFixture {
    StreamMetadataRouter internal scopeRouter;
    StreamFinalityRouterEvidenceProvider internal realProvider;
    RouterMembershipOriginalBoundary internal originalBoundary;
    RouterMembershipArtistBoundary internal routerArtist;

    function _routerMembership(bool lock) internal {
        routerArtist = new RouterMembershipArtistBoundary(address(core));
        scopeRouter = new StreamMetadataRouter(
            address(core),
            address(this),
            keccak256("scope Router deployment"),
            "ipfs://scope-router",
            keccak256("scope Router manifest"),
            IStreamArtistAttribution(address(routerArtist))
        );
        realProvider = new StreamFinalityRouterEvidenceProvider(
            address(core),
            address(metadata),
            address(scopeRouter),
            address(membership),
            500000,
            2000000
        );
        originalBoundary = new RouterMembershipOriginalBoundary(
            address(core), address(metadata), address(realProvider)
        );
        routerArtist.bind(address(originalBoundary));
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(routerArtist));
        core.setPointer(keccak256("ARTWORK_FINALITY_REGISTRY"), address(originalBoundary));
        if (lock) scopeRouter.lockArtistIdentity(1);
    }

    function _anchorSlot(uint256 cid) internal pure returns (bytes32) {
        return keccak256(abi.encode(cid, uint256(12)));
    }
}
