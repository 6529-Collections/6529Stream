// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistDelegationHydrationTypes as DH
} from "../../interfaces/stream/artist/IStreamArtistDelegationAuthorityHydration.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

library StreamArtistDelegationHydrationCodec {
    function tagged(bytes memory raw, bytes32 tag) internal pure returns (bool) {
        bytes32 word;
        if (raw.length < 32) return false;
        assembly ("memory-safe") { word := mload(add(raw, 32)) }
        return word == tag;
    }

    function identity(bytes memory raw) public pure returns (DH.Identity memory p) {
        bytes32 tag;
        (tag, p) = abi.decode(raw, (bytes32, DH.Identity));
        if (tag != DH.IDENTITY || keccak256(raw) != keccak256(abi.encode(tag, p))) {
            revert T.InvalidRecord();
        }
    }

    function binding(bytes memory raw) public pure returns (AH.Binding memory p) {
        bytes32 tag;
        (tag, p) = abi.decode(raw, (bytes32, AH.Binding));
        if (tag != DH.BINDING || keccak256(raw) != keccak256(abi.encode(tag, p))) {
            revert T.InvalidRecord();
        }
    }

    function consent(bytes memory raw) public pure returns (DH.Consent memory p) {
        bytes32 tag;
        (tag, p) = abi.decode(raw, (bytes32, DH.Consent));
        if (tag != DH.CONSENT || keccak256(raw) != keccak256(abi.encode(tag, p))) {
            revert T.InvalidRecord();
        }
    }
}
