// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistHashes.sol";
import "../../interfaces/stream/artist/IStreamArtistSuccessionRecords.sol";

/// @notice Frozen succession record preimages and a bounded canonical public directive schema.
library StreamArtistSuccessionHashes {
    function designationDigest(
        StreamArtistHashes.Environment memory e,
        Succ.Designation memory p,
        T.Authorization memory a
    ) public pure returns (bytes32) {
        return StreamArtistHashes.typed(
            e,
            keccak256(
                abi.encode(
                    bytes32(0x978b9dfcca0968239ea043e735357728a9489fe40067fea6673256206c83de15),
                    p.artistId,
                    p.successor,
                    p.successorKind,
                    p.grantedCapabilities,
                    p.conditionsHash,
                    p.directiveHash,
                    a.nonce,
                    a.time
                )
            )
        );
    }

    function directiveDigest(
        StreamArtistHashes.Environment memory e,
        Succ.Directive memory p,
        T.Authorization memory a
    ) public pure returns (bytes32) {
        return StreamArtistHashes.typed(
            e,
            keccak256(
                abi.encode(
                    bytes32(0xa1f146b360069294c6453e91242bb36bb0245545d57b3c89e1cc73c25e953d31),
                    p.artistId,
                    p.grantedCapabilities,
                    p.forbiddenCapabilities,
                    p.directivePayloadHash,
                    a.nonce,
                    a.time
                )
            )
        );
    }

    function designationRecord(
        StreamArtistHashes.Environment memory e,
        Succ.Designation memory p,
        T.Authorization memory a
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                bytes32(0xe72b08eca38f3231b67e0fa8daba2f1d5daf1953d4b91f8c8e698d14f0ed2b0a),
                e.chainId,
                e.registry,
                p.artistId,
                p.successor,
                p.successorKind,
                p.grantedCapabilities,
                p.conditionsHash,
                p.directiveHash,
                a.nonce,
                a.time
            )
        );
    }

    function directiveRecord(
        StreamArtistHashes.Environment memory e,
        Succ.Directive memory p,
        T.Authorization memory a
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                bytes32(0x993e7562ac3c0f8eddb70e4c49c42ef750a52133056061d419fdbe9ee7236f50),
                e.chainId,
                e.registry,
                p.artistId,
                p.grantedCapabilities,
                p.forbiddenCapabilities,
                p.directivePayloadHash,
                a.nonce,
                a.time
            )
        );
    }

    function publicPayload(uint32 granted, uint32 forbidden, Succ.PublicDocument memory document)
        public
        pure
        returns (bytes memory)
    {
        if ((granted | forbidden) & ~uint32(4095) != 0 || granted & forbidden != 0) {
            revert Succ.InvalidDirective();
        }
        return abi.encodePacked(
            '{"forbiddenCapabilities":',
            _decimal(forbidden),
            ',"grantedCapabilities":',
            _decimal(granted),
            ',"legalInstrumentHash":"',
            _hex(document.legalInstrumentHash),
            '","payoutRoutingIntentHash":"',
            _hex(document.payoutRoutingIntentHash),
            '","schema":"6529STREAM_ESTATE_DIRECTIVE_V1"}'
        );
    }

    function _decimal(uint32 value) private pure returns (bytes memory result) {
        uint32 copy = value;
        uint256 digits = 1;
        while (copy >= 10) {
            ++digits;
            copy /= 10;
        }
        result = new bytes(digits);
        while (digits != 0) {
            result[--digits] = bytes1(uint8(48 + value % 10));
            value /= 10;
        }
    }

    function _hex(bytes32 value) private pure returns (bytes memory result) {
        bytes16 alphabet = "0123456789abcdef";
        result = new bytes(66);
        result[0] = "0";
        result[1] = "x";
        for (uint256 i; i < 32; ++i) {
            result[2 + i * 2] = alphabet[uint8(value[i]) >> 4];
            result[3 + i * 2] = alphabet[uint8(value[i]) & 15];
        }
    }

    function isDesignatedAccount(address account) public view returns (bool) {
        if (account.code.length != 23) return false;
        bytes3 prefix;
        assembly {
            let p := mload(0x40)
            extcodecopy(account, p, 0, 3)
            prefix := mload(p)
        }
        return prefix == hex"ef0100";
    }
}
