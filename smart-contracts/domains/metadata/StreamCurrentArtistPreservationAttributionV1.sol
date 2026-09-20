// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamPreservationAttributionV1 as P
} from "../../interfaces/stream/metadata/IStreamPreservationAttributionV1.sol";
import {
    IStreamStaticC2PAAttribution as C2PA
} from "../../interfaces/stream/metadata/IStreamStaticC2PAAttribution.sol";
import {
    StreamStaticArtistLineageCompanion as Lineage
} from "./StreamStaticArtistLineageCompanion.sol";
import { StreamMetadataDisplayParameters as Gas } from "./StreamMetadataDisplayParameters.sol";
import { StreamRendererCalls as Calls } from "./StreamRendererCalls.sol";

/// @notice Explicit current-Artist non-sanction projection with original live/C2PA pins.
/// @dev This profile does not reinterpret the original immutable-A preservation profile.
contract StreamCurrentArtistPreservationAttributionV1 is P {
    address public immutable override core;
    address public immutable override router;
    address public immutable override liveAttribution;
    bytes32 public immutable override liveAttributionCodeHash;
    address public immutable originalAttribution;
    bytes32 public immutable originalAttributionCodeHash;
    address public immutable artist;
    bytes32 public immutable artistCodeHash;
    address public immutable originalFinality;
    bytes32 public immutable originalFinalityCodeHash;
    uint256 public immutable sourceChainId;
    address public immutable lineageSource;
    bytes32 public immutable lineageSourceCodeHash;
    bytes32 public immutable catalogueHash;
    address public immutable reconciliation;
    bytes32 public immutable reconciliationCodeHash;
    error InvalidPreservationAttribution();

    constructor(address original_, address live_, address executor) {
        if (original_.code.length == 0 || live_.code.length == 0) {
            revert InvalidPreservationAttribution();
        }
        originalAttribution = original_;
        originalAttributionCodeHash = original_.codehash;
        liveAttribution = live_;
        liveAttributionCodeHash = live_.codehash;
        core = _address(original_, "core()");
        router = _address(original_, "router()");
        artist = _address(original_, "artist()");
        artistCodeHash = _word(original_, "artistCodeHash()");
        originalFinality = _address(original_, "originalFinality()");
        originalFinalityCodeHash = _word(original_, "originalFinalityCodeHash()");
        sourceChainId = uint256(_word(original_, "sourceChainId()"));
        if (
            _word(original_, "attributionProfile()")
                != keccak256("6529STREAM_STATIC_CURRENT_ARTIST_ATTRIBUTION_V1")
        ) revert InvalidPreservationAttribution();
        lineageSource = _address(original_, "lineageSource()");
        lineageSourceCodeHash = _word(original_, "lineageSourceCodeHash()");
        catalogueHash = _word(original_, "catalogueHash()");
        if (
            lineageSource.code.length == 0 || lineageSource.codehash != lineageSourceCodeHash
                || catalogueHash == 0
        ) revert InvalidPreservationAttribution();
        if (
            core.code.length == 0 || router.code.length == 0 || artist.code.length == 0
                || artist.codehash != artistCodeHash || originalFinality.code.length == 0
                || originalFinality.codehash != originalFinalityCodeHash
                || sourceChainId != block.chainid || _address(live_, "core()") != core
                || _address(live_, "router()") != router
        ) {
            revert InvalidPreservationAttribution();
        }
        address reconciliation_;
        bytes32 reconciliationHash_;
        // The only additional source shape is the existing fixed optional C2PA wrapper.
        if (live_ != original_) {
            if (
                _address(live_, "original()") != original_
                    || _word(live_, "originalCodeHash()") != original_.codehash
                    || uint256(_word(live_, "sourceChainId()")) != sourceChainId
                    || !abi.decode(
                        Calls.read(
                            live_,
                            abi.encodeWithSignature(
                                "supportsInterface(bytes4)", type(C2PA).interfaceId
                            ),
                            Calls.ReadOptions(32, true),
                            100000
                        ),
                        (bool)
                    )
            ) {
                revert InvalidPreservationAttribution();
            }
            reconciliation_ = _address(live_, "reconciliation()");
            reconciliationHash_ = _word(live_, "reconciliationCodeHash()");
            if (reconciliation_.code.length == 0 || reconciliation_.codehash != reconciliationHash_)
            {
                revert InvalidPreservationAttribution();
            }
        }
        reconciliation = reconciliation_;
        reconciliationCodeHash = reconciliationHash_;
        Gas.initialize(executor);
    }

    function preservationAttributionProfile() external pure returns (bytes32) {
        return keccak256("6529STREAM_CURRENT_ARTIST_NON_SANCTION_ATTRIBUTION_V1");
    }

    function preservationAttribution(uint256 collectionId, uint256 tokenId)
        external
        view
        returns (bytes memory)
    {
        if (
            block.chainid != sourceChainId
                || (reconciliation != address(0)
                    && reconciliation.codehash != reconciliationCodeHash)
                || originalAttribution.codehash != originalAttributionCodeHash
                || liveAttribution.codehash != liveAttributionCodeHash
                || lineageSource.codehash != lineageSourceCodeHash
        ) revert InvalidPreservationAttribution();
        // Strict original-scope projection through the authenticated current-suite companion.
        // The wrapper's original C2PA chain/reconciliation pins remain mandatory above.
        uint256 cap = Gas.value(Gas.OUTER_GAS);
        uint256 available = gasleft();
        if (available <= 40000) revert InvalidPreservationAttribution();
        uint256 remaining = (available - 40000) * 63 / 64;
        if (cap > remaining) cap = remaining;
        bytes memory raw = Calls.read(
            originalAttribution,
            abi.encodeCall(Lineage.preservationAttribution, (collectionId, tokenId)),
            Calls.ReadOptions(32832, false),
            cap
        );
        bytes memory value = abi.decode(raw, (bytes));
        if (value.length > 32768 || keccak256(raw) != keccak256(abi.encode(value))) {
            revert InvalidPreservationAttribution();
        }
        return value;
    }

    function _word(address target, string memory signature) private view returns (bytes32) {
        return abi.decode(
            Calls.read(
                target, abi.encodeWithSignature(signature), Calls.ReadOptions(32, true), 100000
            ),
            (bytes32)
        );
    }

    function _address(address target, string memory signature) private view returns (address a) {
        bytes32 value = _word(target, signature);
        if (uint256(value) >> 160 != 0) revert InvalidPreservationAttribution();
        return address(uint160(uint256(value)));
    }
}
