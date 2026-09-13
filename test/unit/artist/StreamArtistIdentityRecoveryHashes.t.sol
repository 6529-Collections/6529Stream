// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistIdentityRecoveryHashes as H
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityRecoveryHashes.sol";
import {
    StreamArtistIdentityRecoveryTypes as Recovery
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityRecoveryTypes.sol";

contract StreamArtistIdentityRecoveryHashesTest {
    function _fields() private pure returns (Recovery.RecordFields memory) {
        return Recovery.RecordFields(
            bytes32(uint256(0x22)),
            address(0x33),
            address(0x44),
            1,
            bytes32(uint256(0x55)),
            bytes32(uint256(0x66)),
            bytes32(uint256(0x77)),
            bytes32(uint256(0x88)),
            0x01020304
        );
    }

    function testLiteralPrimaryTwelveWords() public pure {
        require(
            H.record(31337, address(0x11), _fields())
                == 0x98f34c20d4fbcd7f2ce71dc71e89594dce2c1c408186ba820221a4400d8a0789
        );
    }

    function testLiteralSupersessionDynamicAbi() public pure {
        bytes32[] memory records = new bytes32[](2);
        records[0] = bytes32(uint256(1));
        records[1] = bytes32(uint256(0x123));
        require(
            H.supersession(records)
                == 0xe02ab7a028756ba35ac3c485faa6c36c4a316087efdea6fa360dc39918ad6cc3
        );
    }

    function testEmptyListIsSharedContentButPrimariesRemainDistinct() public pure {
        bytes32 empty = H.supersession(new bytes32[](0));
        require(empty == 0x273a8a33fd441297e67ff984921de6f3c18a253af20f4d18fbf9ba110a0d15f3);
        Recovery.RecordFields memory fields = _fields();
        fields.supersededRecordsHash = empty;
        bytes32 first = H.record(31337, address(0x11), fields);
        fields.artistId = bytes32(uint256(0x23));
        require(H.record(31337, address(0x11), fields) != first);
        fields.artistId = bytes32(uint256(0x22));
        fields.governanceActionId = bytes32(uint256(0x89));
        require(H.record(31337, address(0x11), fields) != first);
    }

    function hashList(bytes32[] memory records) external pure returns (bytes32) {
        return H.supersession(records);
    }

    function _reject(bytes32[] memory records) private view {
        (bool ok, bytes memory error) =
            address(this).staticcall(abi.encodeCall(this.hashList, (records)));
        require(
            !ok
                && keccak256(error)
                    == keccak256(abi.encodeWithSelector(H.InvalidSupersessionList.selector))
        );
    }

    function testZeroDuplicateAndDescendingListsRejectExactly() public view {
        bytes32[] memory records = new bytes32[](1);
        _reject(records);
        records = new bytes32[](2);
        records[0] = bytes32(uint256(7));
        records[1] = bytes32(uint256(7));
        _reject(records);
        records[1] = bytes32(uint256(6));
        _reject(records);
    }

    function testFuzzPrimaryMatchesIndependentWords(
        uint256 chain,
        address registry,
        Recovery.RecordFields memory f
    ) public pure {
        bytes32[12] memory words;
        words[0] = 0x459749364fd07c3a8f1998b82d893d33ef0942c30d94666b42dac1e37ba5feff;
        words[1] = bytes32(chain);
        words[2] = bytes32(uint256(uint160(registry)));
        words[3] = f.artistId;
        words[4] = bytes32(uint256(uint160(f.oldAddress)));
        words[5] = bytes32(uint256(uint160(f.newAddress)));
        words[6] = bytes32(uint256(f.vestedAuthorityClass));
        words[7] = f.evidenceHash;
        words[8] = f.reasonHash;
        words[9] = f.supersededRecordsHash;
        words[10] = f.governanceActionId;
        words[11] = bytes32(uint256(f.recoveredAt));
        require(H.record(chain, registry, f) == keccak256(abi.encode(words)));
    }

    function testFuzzSortedListMatchesIndependentHeadAndTail(uint128 first, uint128 distance)
        public
        pure
    {
        bytes32[] memory records = new bytes32[](2);
        records[0] = bytes32(uint256(first) + 1);
        records[1] = bytes32(uint256(first) + uint256(distance) + 2);
        bytes32[5] memory words;
        words[0] = 0x0c8573762967a1af597f2a7afc4b655a87b3e22d2b11fbab6cf13c6f7b1396ae;
        words[1] = bytes32(uint256(64));
        words[2] = bytes32(uint256(2));
        words[3] = records[0];
        words[4] = records[1];
        require(H.supersession(records) == keccak256(abi.encode(words)));
    }
}
