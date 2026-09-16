// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/artist/StreamArtistCollaboratorHashes.sol";

/// @notice The same reference vectors execute against the retained old IR helper and both new profiles.
contract StreamArtistCollaboratorBindingHashTest {
    function testBindingLiteralEmptyAndPopulatedVectors() public pure {
        StreamArtistHashes.Environment memory e =
            StreamArtistHashes.Environment(1, address(0x111), address(0x222), address(0x333));
        T.Binding memory b;
        b.artistId = bytes32(uint256(0x44));
        b.artistAddress = address(0x555);
        b.identityRecordHash = bytes32(uint256(0x66));
        b.generation = 3;
        b.consentMode = 1;
        b.saleConsentScope = 1;
        b.registryImmutabilityElection = 1;
        T.CollaboratorRecord[] memory rows = new T.CollaboratorRecord[](0);
        require(
            StreamArtistCollaboratorHashes.binding(e, 7, b, rows)
                == 0x78efdfdc5926871cf1b3554b527f25f473c13f6c6b0333dddf6da88b9666826c,
            "empty literal"
        );
        rows = new T.CollaboratorRecord[](2);
        rows[0] = T.CollaboratorRecord(address(0x444), keccak256("composer"), keccak256("fee"));
        rows[1] = T.CollaboratorRecord(address(0x555), keccak256("visual"), keccak256("credit"));
        require(
            StreamArtistCollaboratorHashes.binding(e, 7, b, rows)
                == 0xf7fc7212408f53bffc72929ac81afe62ec8c072948d883cc28b7102bcfd72e82,
            "populated literal"
        );
        require(
            StreamArtistCollaboratorHashes.binding(e, 7, b, rows) == _flat(e, 7, b, rows),
            "flat literal"
        );
    }

    function testBindingExcludesMutableBookkeepingAndManager() public pure {
        StreamArtistHashes.Environment memory e =
            StreamArtistHashes.Environment(1, address(1), address(2), address(3));
        T.Binding memory b;
        b.artistId = bytes32(uint256(4));
        b.artistAddress = address(5);
        b.identityRecordHash = bytes32(uint256(6));
        b.generation = 7;
        T.CollaboratorRecord[] memory rows = new T.CollaboratorRecord[](0);
        bytes32 before_ = StreamArtistCollaboratorHashes.binding(e, 8, b, rows);
        b.bindingHash = keccak256("stored hash");
        b.accepted = true;
        b.proposer = address(9);
        e.manager = address(10);
        require(
            StreamArtistCollaboratorHashes.binding(e, 8, b, rows) == before_, "bookkeeping leaked"
        );
        e.core = address(11);
        require(StreamArtistCollaboratorHashes.binding(e, 8, b, rows) != before_, "Core omitted");
    }

    function testFuzzBindingExactFlattenedPreimage(bytes32 seed, uint8 count) public pure {
        StreamArtistHashes.Environment memory e;
        e.chainId = uint256(seed);
        e.registry = address(uint160(uint256(keccak256(abi.encode(seed, "registry")))));
        e.core = address(uint160(uint256(keccak256(abi.encode(seed, "core")))));
        e.manager = address(uint160(uint256(keccak256(abi.encode(seed, "manager")))));
        T.Binding memory b;
        b.artistId = keccak256(abi.encode(seed, "artist"));
        b.artistAddress = address(uint160(uint256(keccak256(abi.encode(seed, "address")))));
        b.identityRecordHash = keccak256(abi.encode(seed, "document"));
        b.generation = uint64(uint256(seed));
        b.consentMode = uint8(uint256(seed) >> 64);
        b.saleConsentScope = uint8(uint256(seed) >> 72);
        b.registryImmutabilityElection = uint8(uint256(seed) >> 80);
        T.CollaboratorRecord[] memory rows = new T.CollaboratorRecord[](uint256(count) % 9);
        for (uint256 i; i < rows.length; ++i) {
            rows[i] = T.CollaboratorRecord(
                address(uint160(uint256(keccak256(abi.encode(seed, i, "account"))))),
                keccak256(abi.encode(seed, i, "role")),
                keccak256(abi.encode(seed, i, "label"))
            );
        }
        uint256 collectionId = uint256(keccak256(abi.encode(seed, "collection")));
        require(
            StreamArtistCollaboratorHashes.binding(e, collectionId, b, rows)
                == _flat(e, collectionId, b, rows),
            "sixteen-word preimage"
        );
    }

    function _flat(
        StreamArtistHashes.Environment memory e,
        uint256 collectionId,
        T.Binding memory b,
        T.CollaboratorRecord[] memory rows
    ) private pure returns (bytes32) {
        // Independent array ABI: domain, offset, length, then the three static words per row.
        bytes memory rowBytes = abi.encode(
            keccak256("6529STREAM_ARTIST_COLLABORATOR_SET_V1"), uint256(64), rows.length
        );
        for (uint256 i; i < rows.length; ++i) {
            rowBytes = bytes.concat(
                rowBytes, abi.encode(rows[i].account, rows[i].role, rows[i].shareLabelId)
            );
        }
        bytes32 capabilities = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1"), uint256(64), uint256(0)
            )
        );
        bytes memory first =
            abi.encode(keccak256("6529STREAM_ARTIST_BINDING_V1"), e.chainId, e.registry, e.core);
        bytes memory second = abi.encode(collectionId, b.generation, b.artistId, b.artistAddress);
        bytes memory third = abi.encode(
            b.identityRecordHash, b.consentMode, b.saleConsentScope, b.registryImmutabilityElection
        );
        bytes memory last = abi.encode(uint8(0), uint32(0), keccak256(rowBytes), capabilities);
        return keccak256(bytes.concat(first, second, third, last));
    }
}
