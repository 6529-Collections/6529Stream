// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistConsentReadEncoding as Encoding
} from "../../../smart-contracts/domains/artist/StreamArtistConsentReadEncoding.sol";
import {
    StreamArtistSanctionTypes as S
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSanctionTypes.sol";

/// @dev Typed storage and literal original getter; actual owner construction is covered separately.
contract ConsentStaticSanctionEncodingHarness {
    mapping(bytes32 => bytes32) private _latest;
    mapping(bytes32 => S.Record) private _records;

    function seed(bytes32 association, bytes32 hash, S.Record calldata record) external {
        _latest[association] = hash;
        _records[hash] = record;
    }

    function original(bytes32 association) external view returns (bytes32, S.Record memory) {
        bytes32 hash = _latest[association];
        return (hash, _records[hash]);
    }

    function factored(bytes32 association) external view returns (bytes32, S.Record memory) {
        bytes memory result = Encoding.staticSanction(_latest, _records, association);
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
    }
}

contract StreamArtistRecoveredMultipleGenerationConsentCapacityTest {
    function _record(uint256 value) private pure returns (S.Record memory r) {
        r.recordHash = keccak256(abi.encode("stored hash", value));
        r.artistId = keccak256(abi.encode("Artist", value));
        r.signer = address(uint160(value));
        r.authorityClass = uint8(value);
        r.terms = S.Terms(
            uint8(value >> 8),
            value,
            value ^ 0x1234,
            keccak256(abi.encode("scope", value)),
            keccak256(abi.encode("subject", value)),
            keccak256(abi.encode("statement", value))
        );
        r.nonce = value ^ 0x5678;
        r.signedAt = uint64(value);
        r.deadline = uint64(value >> 64);
        r.bindingGeneration = uint64(value >> 128);
        r.bindingHash = keccak256(abi.encode("binding", value));
        r.digest = keccak256(abi.encode("digest", value));
    }

    function _same(ConsentStaticSanctionEncodingHarness h, bytes32 key)
        private
        view
        returns (bytes memory result)
    {
        (bool oldOK, bytes memory oldResult) =
            address(h).staticcall(abi.encodeWithSelector(h.original.selector, key));
        (bool newOK, bytes memory newResult) =
            address(h).staticcall(abi.encodeWithSelector(h.factored.selector, key));
        require(oldOK && newOK && keccak256(oldResult) == keccak256(newResult), "exact ABI bytes");
        return newResult;
    }

    function testStaticSanctionEmptyAssociationReturnsOriginalZeroTuple() external {
        ConsentStaticSanctionEncodingHarness h = new ConsentStaticSanctionEncodingHarness();
        S.Record memory empty;
        require(
            keccak256(_same(h, bytes32(uint256(4)))) == keccak256(abi.encode(bytes32(0), empty)),
            "zero tuple"
        );
    }

    function testStaticSanctionEveryStoredFieldAndReturnOrderArePreserved() external {
        ConsentStaticSanctionEncodingHarness h = new ConsentStaticSanctionEncodingHarness();
        S.Record memory r = _record(type(uint256).max - 900);
        bytes32 key = keccak256("association");
        bytes32 hash = keccak256("lookup hash differs from record member");
        h.seed(key, hash, r);
        require(keccak256(_same(h, key)) == keccak256(abi.encode(hash, r)), "full tuple");
    }

    function testStaticSanctionNoNewPresenceOrCurrentBindingAdmission() external {
        ConsentStaticSanctionEncodingHarness h = new ConsentStaticSanctionEncodingHarness();
        S.Record memory r = _record(44);
        r.recordHash = 0;
        r.bindingGeneration = 0;
        r.signer = address(0);
        bytes32 key = keccak256("historical association");
        bytes32 hash = keccak256("nonempty original index");
        h.seed(key, hash, r);
        require(keccak256(_same(h, key)) == keccak256(abi.encode(hash, r)), "static lookup only");
    }

    function testStaticSanctionZeroKeyAndUnrelatedAssociationStayIndependent() external {
        ConsentStaticSanctionEncodingHarness h = new ConsentStaticSanctionEncodingHarness();
        S.Record memory first = _record(11);
        S.Record memory second = _record(22);
        h.seed(bytes32(0), bytes32(0), first);
        h.seed(bytes32(uint256(7)), bytes32(uint256(8)), second);
        bytes32 beforeHash = keccak256(_same(h, bytes32(uint256(7))));
        require(
            keccak256(_same(h, bytes32(uint256(9)))) == keccak256(abi.encode(bytes32(0), first)),
            "original zero-slot read"
        );
        require(
            keccak256(_same(h, bytes32(uint256(7)))) == beforeHash, "read leaves state unchanged"
        );
    }

    function testFuzzStaticSanctionLiteralOriginalReturnParity(uint256 value, bytes32 key)
        external
    {
        ConsentStaticSanctionEncodingHarness h = new ConsentStaticSanctionEncodingHarness();
        S.Record memory r = _record(value);
        bytes32 hash = keccak256(abi.encode(value, key));
        h.seed(key, hash, r);
        bytes32 expected = keccak256(abi.encode(hash, r));
        require(keccak256(_same(h, key)) == expected, "fuzz tuple");
        require(keccak256(_same(h, key)) == expected, "repeat unchanged");
    }
}
