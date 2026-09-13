// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../smart-contracts/domains/metadata/StreamMetadataFinalityServing.sol";
import "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCoordinator.sol";

contract MetadataRecoveryCoreBoundary {
    mapping(bytes32 => StreamMetadataRecoveryRoutes.Pointer) private pointers;
    uint8 public lifecycle = 2;

    function setPointer(bytes32 key, StreamMetadataRecoveryRoutes.Pointer calldata p) external {
        pointers[key] = p;
    }

    function getSatellitePointer(bytes32 key)
        external
        view
        returns (StreamMetadataRecoveryRoutes.Pointer memory)
    {
        return pointers[key];
    }

    function tokenCollectionIdentity(uint256 id)
        external
        view
        returns (bool, uint256, uint256, bool)
    {
        return (id == 9, 1, 9, lifecycle == 3);
    }

    function tokenLifecycle(uint256) external view returns (uint8) {
        return lifecycle;
    }

    function tokenData(uint256) external pure returns (bytes memory) {
        return hex"1234";
    }

    function setLifecycle(uint8 x) external {
        lifecycle = x;
    }
}

contract MetadataRecoveryRegistryBoundary {
    bool public eligible = true;

    function setEligible(bool x) external {
        eligible = x;
    }

    function isModuleEligible(address, bytes32, bytes4) external view returns (bool) {
        return eligible;
    }
}

contract MetadataRecoveryArtistBoundary {
    address public core;
    address public finalityRegistry;
    bytes32 public finalityRegistryCodeHash;

    constructor(address c) {
        core = c;
    }

    function bind(address f) external {
        finalityRegistry = f;
        finalityRegistryCodeHash = f.codehash;
    }
}

contract MetadataRecoveryOwnerBoundary {
    address public core;
    address public governanceAuthority;

    constructor(address c, address e) {
        core = c;
        governanceAuthority = e;
    }
}

contract MetadataRecoveryOriginalBoundary {
    address public coreReads;
    address public sanctionReads;
    address public governanceAuthority;
    uint256 public count;

    constructor(address c, address a, address e) {
        coreReads = c;
        sanctionReads = a;
        governanceAuthority = e;
    }

    function setCount(uint256 x) external {
        count = x;
    }

    function finalityComponentCountForScope(StreamFinalityScope calldata)
        external
        view
        returns (uint256)
    {
        return count;
    }

    function finalityComponentCount(uint256) external view returns (uint256) {
        return count;
    }

    function streamModuleType() external pure returns (bytes32) {
        return keccak256("ARTWORK_FINALITY_REGISTRY");
    }

    function streamModuleInterfaceId() external pure returns (bytes4) {
        return type(IStreamArtworkFinalityRegistry).interfaceId;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamArtworkFinalityRegistry).interfaceId;
    }
}

contract MetadataRecoveryCompanionBoundary {
    address public core;
    address public governanceAuthority;
    address public originalFinalityRegistry;
    address public artistEvidence;
    address public ownerEvidence;
    mapping(bytes32 => StreamMetadataRecoveryRoutes.Route) private routes;
    uint8 public fault;

    constructor(address c, address e, address o, address a, address w) {
        core = c;
        governanceAuthority = e;
        originalFinalityRegistry = o;
        artistEvidence = a;
        ownerEvidence = w;
    }

    function setFault(uint8 x) external {
        fault = x;
    }

    function setOriginal(address x) external {
        originalFinalityRegistry = x;
    }

    function setRoute(bytes32 kind, address module, bytes32 recoveryId) external {
        routes[kind] = StreamMetadataRecoveryRoutes.Route(
            true,
            module,
            keccak256(abi.encode(kind, module, recoveryId)),
            keccak256("original"),
            recoveryId
        );
    }

    function clearRoute(bytes32 kind) external {
        delete routes[kind];
    }

    function resolvedFinalityRoute(bytes32 kind, StreamFinalityScope calldata scope)
        external
        view
        returns (StreamMetadataRecoveryRoutes.Route memory r)
    {
        require(
            scope.collectionId == 1
                && ((scope.scopeType == StreamFinalityScopeType.TOKEN && scope.tokenId == 9)
                    || (scope.scopeType == StreamFinalityScopeType.COLLECTION
                        && scope.tokenId == 0)),
            "scope"
        );
        if (fault == 1) assembly ("memory-safe") { return(0, 159) }
        r = routes[kind];
        if (fault == 2) r.pinned = false;
    }

    function finalityRecoveryRouteStatus(bytes32 kind, StreamFinalityScope calldata)
        external
        view
        returns (bool, bool, bytes32, bytes32)
    {
        StreamMetadataRecoveryRoutes.Route memory r = routes[kind];
        return (
            r.pinned,
            r.pinned && fault != 3,
            fault == 4 ? bytes32(uint256(1)) : r.hash,
            fault == 5 ? bytes32(uint256(1)) : r.recoveryId
        );
    }

    function streamModuleType() external pure returns (bytes32) {
        return keccak256("STREAM_ARTWORK_FINALITY_RECOVERY");
    }

    function streamModuleInterfaceId() external pure returns (bytes4) {
        return type(IStreamArtworkFinalityRecovery).interfaceId;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamArtworkFinalityRecovery).interfaceId;
    }
}

contract MetadataRecoveryAdapterBoundary {
    address public immutable core;
    address public immutable host;
    bytes32 public immutable componentType;
    bytes32 public immutable hostCodeHash;
    bytes32 public immutable coreCodeHash;

    constructor(address c, address h, bytes32 kind) {
        core = c;
        host = h;
        componentType = kind;
        hostCodeHash = h.codehash;
        coreCodeHash = c.codehash;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamFinalityHostAdapter).interfaceId;
    }
}

contract MetadataRecoverySourceBoundary {
    address public immutable core;
    address public renderer;
    string public label;
    uint8 public sourceFault;

    function setSourceFault(uint8 x) external {
        sourceFault = x;
    }
    string public script = "return 1;";

    constructor(address c, address r, string memory n) {
        core = c;
        renderer = r;
        label = n;
    }

    function setRenderer(address r) external {
        renderer = r;
    }

    function renderingProfile() external view returns (bytes32 a, bytes32 b, bytes32 d) {
        (a, b, d) = StreamMetadataRenderTypes.profile();
        if (sourceFault == 3) b = bytes32(uint256(1));
        if (sourceFault == 4) d = bytes32(uint256(1));
    }

    function setScript(string calldata x) external {
        script = x;
    }

    function collectionServingSource(uint256)
        external
        view
        returns (IStreamMetadataServingFacts.ServingSource memory)
    {
        return IStreamMetadataServingFacts.ServingSource(
            label,
            "description",
            string(abi.encodePacked("ipfs://", label)),
            "https://example/",
            script
        );
    }

    function collectionServingFacts(uint256)
        external
        view
        returns (IStreamMetadataServingFacts.ServingFacts memory f)
    {
        if (sourceFault == 1) assembly ("memory-safe") { return(0, 511) }
        if (sourceFault == 2) assembly ("memory-safe") { return(0, 513) }
        f.presentationProfile = keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1");
        f.configured = true;
        f.mode = keccak256("ONCHAIN");
        f.renderer = renderer;
        f.rendererCodeHash = renderer.codehash;
        f.scriptHash = keccak256(bytes(script));
        f.scriptBytes = uint32(bytes(script).length);
        f.imageURIHash = keccak256(abi.encodePacked("ipfs://", label));
        f.animationBaseURIHash = keccak256("https://example/");
        f.scriptLocked = true;
        f.mediaLocked = true;
        f.baseURILocked = true;
        f.dependenciesLocked = true;
        f.artistIdentityLocked = true;
        f.displayMetadataLocked = true;
        f.coreFrozen = true;
    }

    function artistPresentation(uint256)
        external
        pure
        returns (IStreamMetadataServingFacts.ArtistPresentation memory a)
    {
        a.locked = true;
        a.registry = address(1);
        a.registryCodeHash = bytes32(uint256(1));
        a.artistId = bytes32(uint256(2));
        a.bindingGeneration = 3;
        a.bindingHash = bytes32(uint256(4));
        a.nominatedArtist = address(5);
        a.identityRecordHash = bytes32(uint256(6));
        a.acceptanceRecordHash = bytes32(uint256(7));
        a.snapshotHash = bytes32(uint256(8));
    }

    function tokenSeed(uint256) external pure returns (bytes32, bool) {
        return (keccak256("saved-seed"), true);
    }
}

contract MetadataRecoveryRendererBoundary {
    function renderingProfile() external pure returns (bytes32, bytes32, bytes32) {
        return StreamMetadataRenderTypes.profile();
    }

    function renderForFinality(bool asURI, bytes calldata input)
        external
        pure
        returns (string memory)
    {
        (
            StreamMetadataRenderTypes.Token memory t,
            IStreamMetadataServingFacts.ServingSource memory m,
            bytes memory artist
        ) = abi.decode(
            input,
            (StreamMetadataRenderTypes.Token, IStreamMetadataServingFacts.ServingSource, bytes)
        );
        return string(
            abi.encodePacked(
                asURI ? "URI-RECOVERED:" : "RECOVERED:",
                m.name,
                ":",
                m.imageURI,
                ":",
                m.script,
                ":",
                t.tokenData,
                ":",
                artist
            )
        );
    }
}

contract MetadataRecoveryServingHarness {
    mapping(uint256 => IStreamMetadataServingFacts.ArtistPresentation) private presentations;
    mapping(uint256 => StreamMetadataRecoveryRoutes.OriginalAnchor) private anchors;
    bytes32 public immutable artistCodeHash;

    constructor(address a) {
        artistCodeHash = a.codehash;
    }

    function token(address c, address a, bool burned, bool uri)
        external
        view
        returns (bool, string memory)
    {
        return StreamMetadataFinalityServing.token(
            presentations,
            anchors,
            StreamMetadataRecoveryRoutes.Environment(c, a, artistCodeHash),
            9,
            burned,
            uri
        );
    }

    function collection(address c, address a) external view returns (bool, string memory) {
        return StreamMetadataFinalityServing.collection(
            presentations,
            anchors,
            StreamMetadataRecoveryRoutes.Environment(c, a, artistCodeHash),
            1
        );
    }
}
