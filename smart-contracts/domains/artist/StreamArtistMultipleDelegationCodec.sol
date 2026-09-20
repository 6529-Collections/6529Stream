// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistDelegationHydrationCodec.sol";
import {
    StreamArtistMultipleDelegationHydrationTypes as MD
} from "../../interfaces/stream/artist/StreamArtistMultipleDelegationHydrationTypes.sol";

library StreamArtistMultipleDelegationCodec {
    function identity(bytes memory raw) public pure returns (MD.Identities memory p) {
        bytes32 tag;
        (tag, p) = abi.decode(raw, (bytes32, MD.Identities));
        if (tag != MD.IDENTITY || keccak256(raw) != keccak256(abi.encode(tag, p))) {
            revert T.InvalidRecord();
        }
    }

    function bindings(bytes memory raw) public pure returns (MD.BindingRow[] memory p) {
        bytes32 tag;
        (tag, p) = abi.decode(raw, (bytes32, MD.BindingRow[]));
        if (tag != MD.BINDING || keccak256(raw) != keccak256(abi.encode(tag, p))) {
            revert T.InvalidRecord();
        }
    }

    function acceptances(bytes memory raw) public pure returns (MD.AcceptanceRow[] memory p) {
        bytes32 tag;
        (tag, p) = abi.decode(raw, (bytes32, MD.AcceptanceRow[]));
        if (tag != MD.ACCEPTANCE || keccak256(raw) != keccak256(abi.encode(tag, p))) {
            revert T.InvalidRecord();
        }
    }

    function attributions(bytes memory raw) public pure returns (MD.AttributionRow[] memory p) {
        bytes32 tag;
        (tag, p) = abi.decode(raw, (bytes32, MD.AttributionRow[]));
        if (tag != MD.ATTRIBUTION || keccak256(raw) != keccak256(abi.encode(tag, p))) {
            revert T.InvalidRecord();
        }
    }

    function consents(bytes memory raw) public pure returns (MD.ConsentRow[] memory p) {
        bytes32 tag;
        (tag, p) = abi.decode(raw, (bytes32, MD.ConsentRow[]));
        if (tag != MD.CONSENT || keccak256(raw) != keccak256(abi.encode(tag, p))) {
            revert T.InvalidRecord();
        }
    }
}
