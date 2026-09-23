// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamStaticArtistLineageReads as Reads } from "./StreamStaticArtistLineageReads.sol";
import {
    StreamArtistStaticDisplayProjection as Display
} from "../artist/StreamArtistStaticDisplayProjection.sol";
import {
    StreamStaticArtistLineageRendering as Rendering
} from "./StreamStaticArtistLineageRendering.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamStaticArtistLineageSource as Source
} from "../../interfaces/stream/metadata/IStreamStaticArtistLineageSource.sol";
import { StreamMetadataDisplayParameters as Gas } from "./StreamMetadataDisplayParameters.sol";
import { StreamRendererCalls as Calls } from "./StreamRendererCalls.sol";

/// @notice Explicit current-authority AA-DISPLAY profile over an admitted immutable suite catalogue.
/// @dev Legacy companions stay unchanged. Full live sanctions and the separate preservation
/// projection use the same authenticated current suite and all other original display facts.
contract StreamStaticArtistLineageCompanion {
    address public immutable core;
    address public immutable router;
    address public immutable artist;
    bytes32 public immutable artistCodeHash;
    address public immutable originalFinality;
    bytes32 public immutable originalFinalityCodeHash;
    uint256 public immutable sourceChainId;
    address public immutable original;
    bytes32 public immutable originalCodeHash;
    address public immutable lineageSource;
    bytes32 public immutable lineageSourceCodeHash;
    bytes32 public immutable catalogueHash;
    bytes32 private immutable _displayCodeHash;
    bytes32 private immutable _renderingCodeHash;
    error InvalidStaticArtistLineageCompanion();

    constructor(address original_, address source_, address executor) {
        if (
            original_.code.length == 0 || source_.code.length == 0
                || address(Display).code.length == 0 || address(Rendering).code.length == 0
        ) _fail();
        original = original_;
        originalCodeHash = original_.codehash;
        lineageSource = source_;
        lineageSourceCodeHash = source_.codehash;
        _displayCodeHash = address(Display).codehash;
        _renderingCodeHash = address(Rendering).codehash;
        core = _address(original_, "core()");
        router = _address(original_, "router()");
        artist = _address(original_, "artist()");
        artistCodeHash = _word(original_, "artistCodeHash()");
        originalFinality = _address(original_, "originalFinality()");
        originalFinalityCodeHash = _word(original_, "originalFinalityCodeHash()");
        sourceChainId = uint256(_word(original_, "sourceChainId()"));
        catalogueHash = _word(source_, "catalogueHash()");
        if (
            sourceChainId != block.chainid || catalogueHash == 0
                || _address(source_, "core()") != core || _address(source_, "router()") != router
                || _address(source_, "originalArtist()") != artist
                || _word(source_, "originalArtistCodeHash()") != artistCodeHash
                || uint256(_word(source_, "sourceChainId()")) != sourceChainId
        ) _fail();
        Gas.initialize(executor);
    }

    function attributionProfile() external pure returns (bytes32) {
        return keccak256("6529STREAM_STATIC_CURRENT_ARTIST_ATTRIBUTION_V1");
    }

    function preservationAttributionProfile() external pure returns (bytes32) {
        return keccak256("6529STREAM_CURRENT_ARTIST_NON_SANCTION_ATTRIBUTION_V1");
    }

    function displayBinding() external view returns (address, bytes32) {
        return (address(Display), _displayCodeHash);
    }

    function renderingBinding() external view returns (address, bytes32) {
        return (address(Rendering), _renderingCodeHash);
    }

    function attribution(uint256 collectionId, uint256 tokenId)
        external
        view
        returns (bytes memory)
    {
        return _render(collectionId, tokenId, true);
    }

    function preservationAttribution(uint256 collectionId, uint256 tokenId)
        external
        view
        returns (bytes memory)
    {
        return _render(collectionId, tokenId, false);
    }

    function _render(uint256 collectionId, uint256 tokenId, bool includeSanctions)
        private
        view
        returns (bytes memory value)
    {
        Reads.ReadContext memory context = _current();
        Reads.Input memory x = Reads.Input(
            context,
            router,
            sourceChainId,
            core,
            originalFinality,
            originalFinalityCodeHash,
            collectionId,
            tokenId,
            includeSanctions
        );
        if (address(Rendering).codehash != _renderingCodeHash) _fail();
        uint256 cap = Gas.value(Gas.OUTER_GAS);
        uint256 available = gasleft();
        if (available <= 40000) _fail();
        uint256 remaining = (available - 40000) * 63 / 64;
        if (cap > remaining) cap = remaining;
        bytes memory raw = Calls.read(
            address(Rendering),
            abi.encodeWithSignature("render(bytes)", abi.encode(x)),
            Calls.ReadOptions(32832, false),
            cap
        );
        value = abi.decode(raw, (bytes));
        if (value.length > 32768 || keccak256(raw) != keccak256(abi.encode(value))) _fail();
    }

    function _current() private view returns (Reads.ReadContext memory context) {
        if (
            block.chainid != sourceChainId || original.codehash != originalCodeHash
                || lineageSource.codehash != lineageSourceCodeHash
                || address(Display).codehash != _displayCodeHash
        ) _fail();
        bytes memory raw = Calls.read(
            lineageSource,
            abi.encodeCall(Source.currentSuite, ()),
            Calls.ReadOptions(544, true),
            Gas.value(Gas.READ_GAS)
        );
        context.suite = abi.decode(raw, (T.SuiteConfiguration));
        if (keccak256(raw) != keccak256(abi.encode(context.suite))) _fail();
        context.worker = address(Display);
        context.readGas = Gas.value(Gas.READ_GAS);
        context.membershipGas = Gas.value(Gas.MEMBERSHIP_GAS);
    }

    function _word(address target, string memory signature) private view returns (bytes32) {
        return abi.decode(
            Calls.read(
                target, abi.encodeWithSignature(signature), Calls.ReadOptions(32, true), 100000
            ),
            (bytes32)
        );
    }

    function _address(address target, string memory signature) private view returns (address) {
        return abi.decode(
            Calls.read(
                target, abi.encodeWithSignature(signature), Calls.ReadOptions(32, true), 100000
            ),
            (address)
        );
    }

    function _fail() private pure {
        revert InvalidStaticArtistLineageCompanion();
    }
}
