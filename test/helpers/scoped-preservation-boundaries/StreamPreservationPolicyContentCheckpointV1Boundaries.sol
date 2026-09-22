// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @dev Explicit mutable producer boundary. It starts with exact genuine live bytes (plus
/// JSON whitespace to distinguish the two outputs), then permits focused currentness controls.
/// It does not implement ADR0054's sanction projection or claim governed analysis/golden admission.
contract PreservationOutputBoundary {
    bytes32 public preservationProfile = keccak256("6529STREAM_PRESERVATION_RENDER_V1");
    address public core;
    address public router;
    address public liveRenderer;
    bytes32 public liveRendererHash;
    address public attribution;
    bytes32 public attributionHash;
    mapping(uint256 => string) private json;
    mapping(uint256 => string) private html;
    bool public fail;

    constructor(address c, address r, address live, address a) {
        core = c;
        router = r;
        liveRenderer = live;
        liveRendererHash = live.codehash;
        attribution = a;
        attributionHash = a.codehash;
    }

    function preservationBinding()
        external
        view
        returns (address, address, address, bytes32, address, bytes32)
    {
        return (core, router, liveRenderer, liveRendererHash, attribution, attributionHash);
    }

    function setBinding(
        address c,
        address r,
        address live,
        bytes32 liveHash,
        address a,
        bytes32 aHash
    ) external {
        core = c;
        router = r;
        liveRenderer = live;
        liveRendererHash = liveHash;
        attribution = a;
        attributionHash = aHash;
    }

    function setProfile(bytes32 profile) external {
        preservationProfile = profile;
    }

    function setFail(bool value) external {
        fail = value;
    }

    function setBytes(uint256 token, string memory j, string memory h) external {
        json[token] = j;
        html[token] = h;
    }

    function preservationTokenJSON(uint256 token) external view returns (string memory) {
        require(!fail, "producer unavailable");
        return json[token];
    }

    function preservationTokenHTML(uint256 token) external view returns (string memory) {
        require(!fail, "producer unavailable");
        return html[token];
    }
}
